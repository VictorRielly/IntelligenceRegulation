/-
D63 step L6: the agreement check of the executable sumcheck verifier, its zero-knowledge pieces and the multilinear
helpers against the Rust code.

Run (through the zk60 resource guard; `results/zk60_lean_l6_20261106/check_l6.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/L6Check.lean results/zk60_lean_l6_20261106/corpus.txt

It recomputes, with the Lean definitions of `ExecMle.lean`, `ExecSumcheck.lean` and `ExecCfs.lean` (the SAME
definitions the theorems are about), every record that `zkp-core/tests/lean_l6_export.rs` writes from the Rust code:
`interpolate_eval`, `eq_point`, both eq tables, both multilinear evaluations, the CFS weights, totals, values and
round messages, masked terminals, extension rounds, and whole sumcheck runs (`prove` then `verify`: plain, masked,
masked with the extension round; honest and tampered), each verdict with the refusal's message bytes and the verifier
transcript's state after the call. It also checks, with Lean's own values and independently of the recorded ones:
`interpolate_eval` at a node is the node's value; each `eq_table_msb` entry is `eq_point` at the index's bits; the
mask's rounds chain (`round(0)` sums to `total`, `round(j+1)` sums to `round(j)` at `ρ_j`, the last ends at `g(ρ)`);
the terminal identities of the runs (`poly(finals)`, `+ c·g(ρ)`, the extension's masked terminals); each prover final
is the table's `eval_mle_ext` at the challenges; each claimed sum is the cube sum (`+ c·G`); each masked round is the
unmasked one plus `c·round(j)`, the extension round `extension_round + c·round(n)`. It prints the checks per kind and
`N checks, F failed`, and exits nonzero on any failure. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.ExecSumcheck
import ZK60Formal.ExecCfs

namespace ZK60.Exec.L6

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

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def f2 (a b : ℕ) : Fp2 := ⟨fpOf a, fpOf b⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def pFps (s : String) : Option (List Fp) := (parseCsvNat s).map (·.map fpOf)

/-! ## The named round polynomials (`lean_l6_export.rs`'s `poly_eval`) -/

def polyOf : String → Option (List Fp2 → Fp2)
  | "prod" => some fun v => v.foldl (fun a x => a.mul x) Fp2.one
  | "zc" => some fun v => (v.getD 0 Fp2.zero).mul (((v.getD 1 Fp2.zero).mul (v.getD 2 Fp2.zero)).sub (v.getD 3 Fp2.zero))
  | _ => none

/-! ## The checker's state -/

structure Mask where
  nv : ℕ
  deg : ℕ
  coeffs : List Fp2

structure Run where
  tables : List (List Fp2) := []
  mask : Option Mask := none
  tr : Option Tr := none
  claimed : Fp2 := Fp2.zero
  deg : ℕ := 0
  nr : ℕ := 0
  c : Fp2 := Fp2.zero
  rounds : List (List Fp2) := []
  fin : Fp2 := Fp2.zero
  chs : List Fp2 := []
  finals : List Fp2 := []

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []
  cfs : Option Mask := none
  rho : List Fp2 := []
  run : Run := {}

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 30 then s.msgs.push s!"[{kind}] {msg.take 150}" else s.msgs }

def St.bad (s : St) (line : String) : St := s.check "PARSE" false line

def H : HIn → Dig := blake3H

/-- The point `(b_0, …, b_{n−1})` of the bits of `idx`, the most significant first (`eq_table_msb`'s order). -/
def bitsPoint (n idx : ℕ) : List Fp2 :=
  (List.range n).map fun j => if idx / 2 ^ (n - 1 - j) % 2 = 1 then Fp2.one else Fp2.zero

/-- `g(ρ)` straight from its definition `a_0 + a'·Π ρ_j + Σ_j Σ_e a_{j,e}·ρ_j^e`, for the cross-check. -/
def cfsDirect (m : Mask) (rho : List Fp2) : Fp2 :=
  let c := m.coeffs
  let prod := rho.foldl (fun a r => a.mul r) Fp2.one
  let rest := (List.range rho.length).foldl (fun acc j =>
    (List.range m.deg).foldl (fun acc e =>
      acc.add ((c.getD (2 + j * m.deg + e) Fp2.zero).mul
        ((List.range (e + 1)).foldl (fun p _ => p.mul (rho.getD j Fp2.zero)) Fp2.one))) acc) Fp2.zero
  ((c.getD 0 Fp2.zero).add ((c.getD 1 Fp2.zero).mul prod)).add rest

def roundOf (m : Mask) (j : ℕ) (prev : List Fp2) : Option (List Fp2) := Cfs.round m.nv m.deg m.coeffs j prev

def sumIE (s : List Fp2) : Fp2 := (s.getD 0 Fp2.zero).add (s.getD 1 Fp2.zero)

def cubeSumOf (p : List Fp2 → Fp2) (tables : List (List Fp2)) : Fp2 :=
  (List.range ((tables.headD []).length)).foldl (fun a i => a.add (p (tables.map (·.getD i Fp2.zero)))) Fp2.zero

def maskEval (m : Mask) (rho : List Fp2) : Option Fp2 := Cfs.eval m.nv m.deg m.coeffs rho

def step (s : St) (line : String) : St :=
  let w := (line.splitOn " ").filter (· ≠ "")
  match w with
  | ["IE", vs, x, out] =>
    match pF2s vs, pF2 x, pF2 out with
    | some vs, some x, some out =>
      let r := interpolateEval vs x
      let s := s.check "INTERPOLATE" (r == out) line
      if x.c1.v = 0 ∧ x.c0.v.toNat < vs.length then
        s.check "INTERPOLATE-NODE" (r == vs.getD x.c0.v.toNat Fp2.zero) line
      else s
    | _, _, _ => s.bad line
  | ["EQP", r, t, out] =>
    match pF2s r, pF2s t, pF2 out with
    | some r, some t, some out => s.check "EQ-POINT" (eqPoint r t == some out) line
    | _, _, _ => s.bad line
  | ["EQT", r, lsb, msb] =>
    match pF2s r, pF2s lsb, pF2s msb with
    | some r, some lsb, some msb =>
      let s := s.check "EQ-TABLE" (eqTable r == lsb) line
      let mt := eqTableMsb r
      let s := s.check "EQ-TABLE-MSB" (mt == msb) line
      (List.range (2 ^ r.length)).foldl (fun s idx =>
        s.check "EQ-TABLE-MSB-POINT" (mt.getD idx Fp2.zero == eqPointBody r (bitsPoint r.length idx))
          s!"{line.take 60} entry {idx}") s
    | _, _, _ => s.bad line
  | ["MLX", v, r, out] =>
    match pF2s v, pF2s r, pF2 out with
    | some v, some r, some out => s.check "MLE-EXT" (evalMleExt v r == some out) line
    | _, _, _ => s.bad line
  | ["MLB", v, r, out] =>
    match pFps v, pF2s r, pF2 out with
    | some v, some r, some out => s.check "MLE-BASE" (evalMleBase v r == some out) line
    | _, _, _ => s.bad line
  | ["CFSW", nv, d, wts] =>
    match nv.toNat?, d.toNat?, pF2s wts with
    | some nv, some d, some wts => s.check "CFS-SUM-WEIGHTS" (Cfs.sumWeights nv d == wts) line
    | _, _, _ => s.bad line
  | ["CFSE", d, rho, wts] =>
    match d.toNat?, pF2s rho, pF2s wts with
    | some d, some rho, some wts => s.check "CFS-EVAL-WEIGHTS" (Cfs.evalWeights rho d == wts) line
    | _, _, _ => s.bad line
  | ["CFSM", nv, d, cs, tot] =>
    match nv.toNat?, d.toNat?, pF2s cs, pF2 tot with
    | some nv, some d, some cs, some tot =>
      let s := s.check "CFS-LEN" (cs.length == Cfs.len nv d) line
      { s.check "CFS-TOTAL" (Cfs.total nv d cs == tot) line with cfs := some ⟨nv, d, cs⟩ }
    | _, _, _, _ => s.bad line
  | ["CFSV", rho, ev] =>
    match s.cfs, pF2s rho, pF2 ev with
    | some m, some rho, some ev =>
      let s := s.check "CFS-EVAL" (maskEval m rho == some ev) line
      let s := s.check "CFS-EVAL-DIRECT" (maskEval m rho == some (cfsDirect m rho)) line
      { s with rho := rho }
    | _, _, _ => s.bad line
  | ["CFSR", j, prev, rd] =>
    match s.cfs, j.toNat?, pF2s prev, pF2s rd with
    | some m, some j, some prev, some rd =>
      let mine := roundOf m j prev
      let s := s.check "CFS-ROUND" (mine == some rd) line
      let mr := mine.getD []
      -- the chain, with Lean's own rounds: round 0 sums to the total, round j to round j−1 at ρ_{j−1}
      let s :=
        if j = 0 then s.check "CFS-CHAIN" (sumIE mr == Cfs.total m.nv m.deg m.coeffs) line
        else
          match roundOf m (j - 1) (prev.take (j - 1)) with
          | some pr => s.check "CFS-CHAIN" (sumIE mr == interpolateEval pr (prev.getD (j - 1) Fp2.zero)) line
          | none => s.bad line
      if j + 1 = m.nv ∧ s.rho.take j = prev ∧ s.rho.length = m.nv then
        s.check "CFS-TERMINAL" (some (interpolateEval mr (s.rho.getD j Fp2.zero)) == maskEval m s.rho) line
      else s
    | _, _, _, _ => s.bad line
  | ["MT", fin, ext, rho, out] =>
    match pF2 fin, pF2 ext, pF2 rho, pF2 out with
    | some fin, some ext, some rho, some out => s.check "MASKED-TERMINAL" (Cfs.maskedTerminal fin ext rho == out) line
    | _, _, _, _ => s.bad line
  | ["EXR", p, d, fins, exts, out] =>
    match polyOf p, d.toNat?, pF2s fins, pF2s exts, pF2s out with
    | some p, some d, some fins, some exts, some out =>
      s.check "EXTENSION-ROUND" (Cfs.extensionRound fins exts d p == some out) line
    | _, _, _, _, _ => s.bad line
  | ["SCNEW"] => { s with run := {} }
  | ["SCTAB", t] =>
    match pF2s t with
    | some t => { s with run := { s.run with tables := s.run.tables ++ [t] } }
    | none => s.bad line
  | ["SCMASK", nv, d, cs] =>
    match nv.toNat?, d.toNat?, pF2s cs with
    | some nv, some d, some cs => { s with run := { s.run with mask := some ⟨nv, d, cs⟩ } }
    | _, _, _ => s.bad line
  | ["SC", _, dom, key, d, nr, cl] =>
    match parseHex dom, parseOptDig key, d.toNat?, nr.toNat?, pF2 cl with
    | some dom, some key, some d, some nr, some cl =>
      let s := s.check "TRSTART" (decodeLink (startMsg dom) == none) line
      { s with run := { s.run with tr := some (Tr.newKeyed H dom key), claimed := cl, deg := d, nr := nr, rounds := [] } }
    | _, _, _, _, _ => s.bad line
  | ["SCPRE", c] =>
    match s.run.tr, pF2 c with
    | some t, some c =>
      let (x, t') := t.challengeFp2 H
      { s.check "SC-PRE-CHALLENGE" (x == c) line with run := { s.run with tr := some t', c := x } }
    | _, _ => s.bad line
  | ["SCR", rd] =>
    match pF2s rd with
    | some rd => { s with run := { s.run with rounds := s.run.rounds ++ [rd] } }
    | none => s.bad line
  | "SCEND" :: rest =>
    match s.run.tr with
    | none => s.bad line
    | some t =>
      let (res, t') := scVerify H s.run.claimed s.run.deg s.run.nr s.run.rounds t
      match rest, res with
      | ["ok", fin, chs, st], .ok (fin', chs') =>
        match pF2 fin, pF2s chs, parseDig st with
        | some fin, some chs, some st =>
          { s.check "SC-VERDICT" (fin' == fin && chs' == chs && t'.state == st) line with
            run := { s.run with fin := fin', chs := chs' } }
        | _, _, _ => s.bad line
      | ["err", msg, st], .error e =>
        match parseHex msg, parseDig st with
        | some msg, some st => s.check "SC-VERDICT" (ascii e.msg == msg && t'.state == st) line
        | _, _ => s.bad line
      | _, _ => s.check "SC-VERDICT" false s!"{line.take 100} (Lean's verdict differs)"
  | ["SCFIN", p, fins, e] =>
    match polyOf p, pF2s fins, e.toNat? with
    | some p, some fins, some e =>
      { s.check "SC-TERMINAL" ((p fins == s.run.fin) == (e == 1)) line with run := { s.run with finals := fins } }
    | _, _, _ => s.bad line
  | ["SCSUM", p] =>
    match polyOf p with
    | some p => s.check "SC-CLAIM" (s.run.claimed == cubeSumOf p s.run.tables) line
    | none => s.bad line
  | ["SCMLE", k] =>
    match k.toNat? with
    | some k =>
      let t := s.run.tables.getD k []
      s.check "SC-FINAL-MLE" (evalMleExt t (s.run.chs.take (Nat.log2 t.length)) == some (s.run.finals.getD k Fp2.zero))
        s!"{line} table {k}"
    | none => s.bad line
  | ["SCUNM", j, u] =>
    match s.run.mask, j.toNat?, pF2s u with
    | some m, some j, some u =>
      match roundOf m j (s.run.chs.take j) with
      | some g => s.check "SC-MASKED-ROUND" (s.run.rounds.getD j [] == Cfs.maskRound u g s.run.c) line
      | none => s.bad line
    | _, _, _ => s.bad line
  | ["SCMFIN", p, fins, e] =>
    match s.run.mask, polyOf p, pF2s fins, e.toNat? with
    | some m, some p, some fins, some e =>
      match maskEval m s.run.chs with
      | some g =>
        { s.check "SC-MASKED-TERMINAL" ((((p fins).add (s.run.c.mul g)) == s.run.fin) == (e == 1)) line with
          run := { s.run with finals := fins } }
      | none => s.bad line
    | _, _, _, _ => s.bad line
  | ["SCMSUM", p] =>
    match s.run.mask, polyOf p with
    | some m, some p =>
      s.check "SC-MASKED-CLAIM"
        (s.run.claimed == (cubeSumOf p s.run.tables).add (s.run.c.mul (Cfs.total m.nv m.deg m.coeffs))) line
    | _, _ => s.bad line
  | ["SCEXT", p, fins, exts] =>
    match s.run.mask, polyOf p, pF2s fins, pF2s exts with
    | some m, some p, some fins, some exts =>
      let n := s.run.nr - 1
      match Cfs.extensionRound fins exts s.run.deg p, roundOf m n (s.run.chs.take n) with
      | some sk, some g =>
        { s.check "SC-EXTENSION-ROUND" (s.run.rounds.getD n [] == Cfs.maskRound sk g s.run.c) line with
          run := { s.run with finals := fins } }
      | _, _ => s.bad line
    | _, _, _, _ => s.bad line
  | ["SCXTERM", p, tau, fins, exts, e] =>
    match s.run.mask, polyOf p, pF2s tau, pF2s fins, pF2s exts, e.toNat? with
    | some m, some p, some tau, some fins, some exts, some e =>
      let n := s.run.chs.length - 1
      let rk := s.run.chs.getD n Fp2.zero
      let eqExt := (Fp2.one.sub rk).mul (eqPointBody tau (s.run.chs.take n))
      let mts := (List.range 3).map fun t =>
        Cfs.maskedTerminal (fins.getD (t + 1) Fp2.zero) (exts.getD (t + 1) Fp2.zero) rk
      match maskEval m s.run.chs with
      | some g =>
        let want := (p (eqExt :: mts)).add (s.run.c.mul g)
        { s.check "SC-EXTENDED-TERMINAL" ((want == s.run.fin) == (e == 1)) line with
          run := { s.run with finals := fins } }
      | none => s.bad line
    | _, _, _, _, _, _ => s.bad line
  | _ => s.bad line

end ZK60.Exec.L6

open ZK60.Exec ZK60.Exec.L6 in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l6_20261106/corpus.txt"
  let lines ← IO.FS.lines path
  let s : St := {}
  let s := s.check "ASCII" (ascii "sc-round" == scLabel) "b\"sc-round\""
  let s := lines.foldl (fun s l => if l.startsWith "#" || l.all Char.isWhitespace then s else step s l) s
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"L6Check: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)
