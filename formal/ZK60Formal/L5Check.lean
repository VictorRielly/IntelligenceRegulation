/-
D63 step L5: the agreement check of the executable foundation against the Rust code and the official BLAKE3 vectors.

Run (through the zk60 resource guard; `results/zk60_lean_l5_20261106/check_l5.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/L5Check.lean results/zk60_lean_l5_20261106/corpus.txt

It recomputes, with the Lean definitions of `ExecField.lean`, `ExecBlake3.lean`, `ExecTranscript.lean` and
`ExecMerkle.lean` (the SAME definitions the theorems are about), every value of
* the official BLAKE3 test vectors (`L5Vectors.lean`): 35 inputs × 3 modes × 131 bytes of extended output;
* the corpus `zkp-core/tests/lean_l5_export.rs` writes from the Rust code: field operations and encodings, BLAKE3 in the
  three modes (with the hash-tag keys of two profiles), transcript runs (the state after every absorb and squeeze, and
  every challenge), Merkle trees, paths and column checks (honest and tampered: the Lean verdict must equal the Rust
  verdict), and whole tagged PCS openings accepted by `verify_zk_tagged`, whose verifier transcript is replayed (its
  column indices and final state) and whose every opened column is re-verified;
and also checks each field result against the field arithmetic of `Nat` mod `p` directly. It prints the checks per
kind and `N checks, F failed`, and exits nonzero on any failure. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.ExecMerkle
import ZK60Formal.L5Vectors

namespace ZK60.Exec.L5

/-! ## Parsing -/

def hexDigit (c : Char) : Option ℕ :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hexPairs : List Char → Option (List UInt8)
  | [] => some []
  | [_] => none
  | a :: b :: rest => do
    let x ← hexDigit a
    let y ← hexDigit b
    let r ← hexPairs rest
    pure (UInt8.ofNat (16 * x + y) :: r)

def parseHex (s : String) : Option (List UInt8) := if s = "-" ∨ s = "" then some [] else hexPairs s.toList

def parseDig (s : String) : Option Dig := parseHex s >>= digOf?

def parseOptDig (s : String) : Option (Option Dig) := if s = "-" then some none else (parseDig s).map some

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def parseDigCsv (s : String) : Option (List Dig) := if s = "-" then some [] else (s.splitOn ",").mapM parseDig

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def f2 (a b : ℕ) : Fp2 := ⟨fpOf a, fpOf b⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

/-- `gen:<seed>:<len>` (the Rust `gen_bytes`). -/
def genBytes (seed len : ℕ) : List UInt8 :=
  (List.range len).map fun i =>
    ((UInt64.ofNat i * 0x9E3779B97F4A7C15 + UInt64.ofNat seed * 0xD1B54A32D192ED03) >>> 56).toUInt8

/-- `fgen:<n>` (the Rust `gen_fp2`, the A14 test's vectors). -/
def genFp2 (n : ℕ) : List Fp2 :=
  (List.range n).map fun i => ⟨Fp.new (UInt64.ofNat i * 0x9e3779b97f4a7c15), Fp.new (UInt64.ofNat i ^^^ 0xdeadbeef)⟩

def dataSpec (s : String) : Option (List UInt8) :=
  match s.splitOn ":" with
  | ["h", hx] => parseHex hx
  | ["gen", seed, len] => do pure (genBytes (← seed.toNat?) (← len.toNat?))
  | _ => none

def fp2Spec (s : String) : Option (List Fp2) :=
  match s.splitOn ":" with
  | ["fgen", n] => n.toNat?.map genFp2
  | ["v", csv] => parseCsvNat csv >>= pairUp
  | _ => none

def ba (l : List UInt8) : ByteArray := ⟨l.toArray⟩

/-! ## Reference arithmetic (`Nat` mod `p`) -/

def gp : ℕ := 18446744069414584321

def powMod (a e m : ℕ) : ℕ :=
  if h : e = 0 then 1 % m
  else
    let r := powMod (a * a % m) (e / 2) m
    if e % 2 = 1 then a * r % m else r
termination_by e
decreasing_by omega

def f2eq (x : Fp2) (r0 r1 : ℕ) : Bool := x.c0.v.toNat == r0 && x.c1.v.toNat == r1

def checkFP (op : String) (a : List ℕ) : Option Bool :=
  match op, a with
  | "add", [a, b, r] => some ((Fp.add (fpOf a) (fpOf b)).v.toNat == r && r == (a + b) % gp)
  | "sub", [a, b, r] => some ((Fp.sub (fpOf a) (fpOf b)).v.toNat == r && r == (a + gp - b) % gp)
  | "mul", [a, b, r] => some ((Fp.mul (fpOf a) (fpOf b)).v.toNat == r && r == a * b % gp)
  | "neg", [a, r] => some ((Fp.neg (fpOf a)).v.toNat == r && r == (gp - a) % gp)
  | "inv", [a, r] => some ((Fp.inv (fpOf a)).v.toNat == r && a * r % gp == 1)
  | "pow", [a, e, r] => some ((Fp.pow (fpOf a) (UInt64.ofNat e)).v.toNat == r && r == powMod a e gp)
  | "new", [w, r] => some ((Fp.new (UInt64.ofNat w)).v.toNat == r && r == w % gp)
  | "u128", [hi, lo, r] =>
    let x := hi * 2 ^ 64 + lo
    some ((Fp.fromU128 x).v.toNat == r && r == x % gp)
  | _, _ => none

def checkF2 (op : String) (a : List ℕ) : Option Bool :=
  match op, a with
  | "add", [a0, a1, b0, b1, r0, r1] =>
    some (f2eq (Fp2.add (f2 a0 a1) (f2 b0 b1)) r0 r1 && r0 == (a0 + b0) % gp && r1 == (a1 + b1) % gp)
  | "sub", [a0, a1, b0, b1, r0, r1] =>
    some (f2eq (Fp2.sub (f2 a0 a1) (f2 b0 b1)) r0 r1 && r0 == (a0 + gp - b0) % gp && r1 == (a1 + gp - b1) % gp)
  | "mul", [a0, a1, b0, b1, r0, r1] =>
    some (f2eq (Fp2.mul (f2 a0 a1) (f2 b0 b1)) r0 r1 && r0 == (a0 * b0 + 7 * (a1 * b1)) % gp
      && r1 == (a0 * b1 + a1 * b0) % gp)
  | "neg", [a0, a1, r0, r1] =>
    some (f2eq (Fp2.neg (f2 a0 a1)) r0 r1 && r0 == (gp - a0) % gp && r1 == (gp - a1) % gp)
  | "mulbase", [a0, a1, b, r0, r1] =>
    some (f2eq (Fp2.mulBase (f2 a0 a1) (fpOf b)) r0 r1 && r0 == a0 * b % gp && r1 == a1 * b % gp)
  | "inv", [a0, a1, r0, r1] =>
    some (f2eq (Fp2.inv (f2 a0 a1)) r0 r1 && (r0 * a0 + 7 * (r1 * a1)) % gp == 1 && (r0 * a1 + r1 * a0) % gp == 0)
  | _, _ => none

/-! ## The checker's state -/

structure PcsBlock where
  name : String
  domain : List UInt8
  root : Dig
  rows : ℕ
  nn : ℕ
  q : ℕ
  groups : List (List Fp2) := []
  prox : List Fp2 := []
  cols : List (ℕ × List Fp × Dig × List Dig) := []

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []
  tr : Option Tr := none
  tags : List (String × (Option Dig × MTag)) := []
  levels : List (List Dig) := []
  pcs : Option PcsBlock := none

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 30 then s.msgs.push s!"[{kind}] {msg}" else s.msgs }

def St.bad (s : St) (line : String) : St := s.check "PARSE" false line

def St.tag (s : St) (name : String) : Option (Option Dig × MTag) := (s.tags.find? (·.1 = name)).map (·.2)

def H : HIn → Dig := blake3H

def ascii' (s : String) : List UInt8 := ascii s

/-- The path of position `i` from built levels (`MerkleTree::path`). -/
def pathOf : List (List Dig) → ℕ → List Dig
  | [], _ => []
  | [_], _ => []
  | lv :: rest, i => lv.getD (i ^^^ 1) zeroDig :: pathOf rest (i / 2)

/-- The PCS verifier's transcript, replayed (`verify_zk_tagged` after `new_tagged(domain, key)` and
`absorb("root", root)`): per group `challenge_fp2_vec(1)` (one claim), `challenge_fp2_vec(rows)`, the group vectors
and the proximity vector absorbed, then `challenge_indices(Q, enc_cols)`. -/
def pcsReplay (tkey : Option Dig) (b : PcsBlock) : Option (List ℕ × Tr) :=
  let t := (Tr.newKeyed H b.domain tkey).absorb H (ascii' "root") b.root.toList
  let t := b.groups.foldl (fun t _ => (t.challengeFp2Vec H 1).2) t
  let t := (t.challengeFp2Vec H b.rows).2
  let t := b.groups.foldl (fun t g => t.absorbFp2 H (ascii' "pcs-vec") g) t
  let t := t.absorbFp2 H (ascii' "pcs-prox") b.prox
  t.challengeIndices H b.q b.nn

def stepTr (s : St) (line : String) (f : Tr → Option (Bool × Tr)) : St :=
  match s.tr with
  | none => s.bad line
  | some t =>
    match f t with
    | none => s.bad line
    | some (b, t') => { s.check "TRANSCRIPT" b line with tr := some t' }

/-- The two profiles the corpus tags, the four context strings of ruling T-1 and the eight keys `hashtag.rs` pins
(`the_four_keys_of_each_tagged_profile_are_pinned`). -/
def profiles : List (String × String) :=
  [("rungg", "hashline-zk-mr1/private-block-rung-g-t24-dev/1"), ("m125", "hashline-zk-mr1/private-block-m125/1")]

def contexts : List String :=
  ["hashline-zk-mr1 2026-09-20 fiat-shamir transcript", "hashline-zk-mr1 2026-09-20 pcs column digest",
    "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf", "hashline-zk-mr1 2026-09-20 pcs merkle inner node"]

def pins : List (String × List String) :=
  [("rungg", ["51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe",
      "2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c",
      "fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032",
      "8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc"]),
   ("m125", ["125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c",
      "d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135",
      "1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83",
      "798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b"])]

/-- A tag's four keys against Lean's own `derive_key` of the profile string and against the pins. -/
def tagChecks (s : St) (name : String) (keys : List (Option Dig)) : St :=
  match profiles.find? (·.1 = name), pins.find? (·.1 = name) with
  | some (_, prof), some (_, pin) =>
    let derived := contexts.map fun c => digOf? (Blake3.deriveKey (ba (ascii' c)) (ba (ascii' prof)) 32).toList
    let s := s.check "TAG-KEYS-DERIVED" (keys == derived) s!"{name}: the four keys are derive_key(context, profile)"
    s.check "TAG-KEYS-PINNED" (keys == pin.map parseDig) s!"{name}: the four keys are hashtag.rs's pins"
  | _, _ => s.check "TAG-KEYS-LEGACY" (keys == [none, none, none, none]) s!"{name}: the legacy rule has no key"

def step (s : St) (line : String) : St :=
  let w := (line.splitOn " ").filter (· ≠ "")
  match w with
  | "FP" :: op :: rest =>
    match rest.mapM String.toNat? >>= checkFP op with
    | some r => s.check "FP" r line
    | none => s.bad line
  | "F2" :: op :: rest =>
    match rest.mapM String.toNat? >>= checkF2 op with
    | some r => s.check "FP2" r line
    | none => s.bad line
  | ["BY", "fp", v, hx] =>
    match v.toNat?, parseHex hx with
    | some v, some b => s.check "BYTES" ((fpOf v).toBytes == b) line
    | _, _ => s.bad line
  | ["BY", "fp2", c0, c1, hx] =>
    match c0.toNat?, c1.toNat?, parseHex hx with
    | some c0, some c1, some b => s.check "BYTES" ((f2 c0 c1).toBytes == b) line
    | _, _, _ => s.bad line
  | ["BY", "fp2from", hx, c0, c1] =>
    match c0.toNat?, c1.toNat?, parseHex hx with
    | some c0, some c1, some b => s.check "BYTES" (Fp2.fromBytes b == f2 c0 c1) line
    | _, _, _ => s.bad line
  | ["B3", mode, k, spec, out] =>
    match parseHex k, dataSpec spec, parseHex out with
    | some k, some d, some o =>
      let r := match mode with
        | "hash" => (Blake3.hash (ba d) 32).toList == o && (H ⟨none, d⟩).toList == o
        | "keyed" => (Blake3.keyedHash (ba k) (ba d) 32).toList == o
            && (match digOf? k with | some kd => (H ⟨some kd, d⟩).toList == o | none => false)
        | "derive" => (Blake3.deriveKey (ba k) (ba d) 32).toList == o
        | _ => false
      s.check "BLAKE3" r line
    | _, _, _ => s.bad line
  | ["TR", "new", dom] =>
    match parseHex dom with
    | some d => { s.check "TRSTART" (decodeLink (startMsg d) == none) line with tr := some (Tr.new H d) }
    | none => s.bad line
  | ["TR", "tagged", dom, key] =>
    match parseHex dom, parseDig key with
    | some d, some k =>
      { s.check "TRSTART" (decodeLink (startMsg d) == none) line with tr := some (Tr.newTagged H d k) }
    | _, _ => s.bad line
  | ["TS", st] => stepTr s line fun t => (parseDig st).map fun st => (t.state == st, t)
  | ["TA", label, spec, st] => stepTr s line fun t => do
      let l ← parseHex label
      let d ← dataSpec spec
      let st ← parseDig st
      let t := t.absorb H l d
      pure (t.state == st, t)
  | ["TU", label, v, st] => stepTr s line fun t => do
      let l ← parseHex label
      let v ← v.toNat?
      let st ← parseDig st
      let t := t.absorbU64 H l (UInt64.ofNat v)
      pure (t.state == st, t)
  | ["TF", label, csv, st] => stepTr s line fun t => do
      let l ← parseHex label
      let v ← parseCsvNat csv
      let st ← parseDig st
      let t := t.absorbFp H l (v.map fpOf)
      pure (t.state == st, t)
  | ["TF2", label, spec, st] => stepTr s line fun t => do
      let l ← parseHex label
      let v ← fp2Spec spec
      let st ← parseDig st
      let t := t.absorbFp2 H l v
      pure (t.state == st, t)
  | ["TCF", r, st] => stepTr s line fun t => do
      let r ← r.toNat?
      let st ← parseDig st
      let (x, t) := t.challengeFp H
      pure (x.v.toNat == r && t.state == st, t)
  | ["TCF2", r0, r1, st] => stepTr s line fun t => do
      let r0 ← r0.toNat?
      let r1 ← r1.toNat?
      let st ← parseDig st
      let (x, t) := t.challengeFp2 H
      pure (f2eq x r0 r1 && t.state == st, t)
  | ["TCV", n, csv, st] => stepTr s line fun t => do
      let n ← n.toNat?
      let v ← parseCsvNat csv >>= pairUp
      let st ← parseDig st
      let (x, t) := t.challengeFp2Vec H n
      pure (x == v && t.state == st, t)
  | ["TCI", n, bound, csv, st] => stepTr s line fun t => do
      let n ← n.toNat?
      let bound ← bound.toNat?
      let v ← parseCsvNat csv
      let st ← parseDig st
      let (x, t) ← t.challengeIndices H n bound
      pure (x == v && t.state == st, t)
  | ["MTAG", name, tk, ck, lk, nk] =>
    match parseOptDig tk, parseOptDig ck, parseOptDig lk, parseOptDig nk with
    | some tk, some ck, some lk, some nk =>
      { tagChecks s name [tk, ck, lk, nk] with tags := (name, (tk, ⟨ck, lk, nk⟩)) :: s.tags }
    | _, _, _, _ => s.bad line
  | ["MB", name, n, root] =>
    match s.tag name, n.toNat?, parseDig root with
    | some (_, tg), some n, some r =>
      let leaves := (List.range n).map fun i => H ⟨none, le64 (UInt64.ofNat i)⟩
      let lv := buildLevels H tg 64 leaves
      { s.check "MERKLE-TREE" ((lv.getLast?.bind List.head?) == some r) line with levels := lv }
    | _, _, _ => s.bad line
  | ["MP", name, root, j, leaf, path, e] =>
    match s.tag name, parseDig root, j.toNat?, parseDig leaf, parseDigCsv path, e.toNat? with
    | some (_, tg), some r, some j, some lf, some p, some e =>
      let s := s.check "MERKLE-PATH" (verifyPath H tg r j lf p == (e == 1)) line
      if e = 1 ∧ (s.levels.getLast?.bind List.head?) = some r ∧ p.length + 1 = s.levels.length then
        s.check "MERKLE-HONEST-PATH" (pathOf s.levels j == p) line
      else s
    | _, _, _, _, _, _ => s.bad line
  | ["MLEAF", name, a, b, out] =>
    match s.tag name, parseDig a, parseDig b, parseDig out with
    | some (_, tg), some a, some b, some o => s.check "MERKLE-LEAF" (saltLeaf H tg a b == o) line
    | _, _, _, _ => s.bad line
  | ["MNODE", name, a, b, out] =>
    match s.tag name, parseDig a, parseDig b, parseDig out with
    | some (_, tg), some a, some b, some o => s.check "MERKLE-NODE" (hashPair H tg a b == o) line
    | _, _, _, _ => s.bad line
  | ["MCOL", name, csv, out] =>
    match s.tag name, parseCsvNat csv, parseDig out with
    | some (_, tg), some c, some o => s.check "MERKLE-COLUMN" (colDigest H tg (c.map fpOf) == o) line
    | _, _, _ => s.bad line
  | ["MK", name, depth, rows, root, j, csv, salt, path, e] =>
    match s.tag name, depth.toNat?, rows.toNat?, parseDig root, j.toNat?, parseCsvNat csv, parseDig salt,
        parseDigCsv path, e.toNat? with
    | some (_, tg), some dp, some rw, some r, some j, some c, some sl, some p, some e =>
      s.check "MERKLE-OPENING" (verifyColumn H tg dp rw r j (c.map fpOf) sl p == (e == 1)) line
    | _, _, _, _, _, _, _, _, _ => s.bad line
  | ["PCS", name, dom, root, rows, nn, q, _] =>
    match parseHex dom, parseDig root, rows.toNat?, nn.toNat?, q.toNat? with
    | some d, some r, some rw, some nn, some q =>
      { s with pcs := some { name := name, domain := d, root := r, rows := rw, nn := nn, q := q } }
    | _, _, _, _, _ => s.bad line
  | ["PCSG", csv] =>
    match s.pcs, parseCsvNat csv >>= pairUp with
    | some b, some g => { s with pcs := some { b with groups := b.groups ++ [g] } }
    | _, _ => s.bad line
  | ["PCSP", csv] =>
    match s.pcs, parseCsvNat csv >>= pairUp with
    | some b, some g => { s with pcs := some { b with prox := g } }
    | _, _ => s.bad line
  | ["PCSC", j, csv, salt, path] =>
    match s.pcs, j.toNat?, parseCsvNat csv, parseDig salt, parseDigCsv path with
    | some b, some j, some c, some sl, some p =>
      { s with pcs := some { b with cols := b.cols ++ [(j, c.map fpOf, sl, p)] } }
    | _, _, _, _, _ => s.bad line
  | ["PCSEND", st] =>
    match s.pcs, parseDig st with
    | some b, some st =>
      match s.tag b.name with
      | none => s.bad line
      | some (tkey, tg) =>
        match pcsReplay tkey b with
        | none => s.bad line
        | some (idx, t) =>
          let depth := Nat.log2 b.nn
          let s := s.check "PCS-INDICES" (idx == b.cols.map (·.1)) s!"{b.name}: column indices"
          let s := s.check "PCS-STATE" (t.state == st) s!"{b.name}: the verifier's final transcript state"
          let s := b.cols.foldl (fun s c =>
            s.check "PCS-COLUMN" (verifyColumn H tg depth b.rows b.root c.1 c.2.1 c.2.2.1 c.2.2.2)
              s!"{b.name}: column {c.1}") s
          { s with pcs := none }
    | _, _ => s.bad line
  | _ => s.bad line

/-! ## The official BLAKE3 vectors -/

def vectorChecks (s : St) : St :=
  let key := ba (ascii' Blake3Vectors.key)
  let ctx := ba (ascii' Blake3Vectors.context)
  Blake3Vectors.cases.foldl (fun s c =>
    let (len, h, k, d) := c
    let inp := ba ((List.range len).map fun i => UInt8.ofNat (i % 251))
    let s := s.check "BLAKE3-VECTOR" (some (Blake3.hash inp 131).toList == parseHex h) s!"hash, length {len}"
    let s := s.check "BLAKE3-VECTOR" (some (Blake3.keyedHash key inp 131).toList == parseHex k) s!"keyed_hash, length {len}"
    s.check "BLAKE3-VECTOR" (some (Blake3.deriveKey ctx inp 131).toList == parseHex d) s!"derive_key, length {len}") s

end ZK60.Exec.L5

open ZK60.Exec ZK60.Exec.L5 in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l5_20261106/corpus.txt"
  let lines ← IO.FS.lines path
  let s : St := {}
  let s := s.check "ASCII" (ascii "squeeze" == squeezeTag) "b\"squeeze\""
  let s := s.check "ASCII" (ascii "hashline-v1/" == startTag) "b\"hashline-v1/\""
  let s := s.check "ASCII" (ascii "hashline-zk-mr1/private-block-rung-g-t24-dev/1" == rungGDomain) "RUNG_G"
  let s := vectorChecks s
  let s := lines.foldl (fun s l => if l.startsWith "#" || l.all Char.isWhitespace then s else step s l) s
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"L5Check: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)
