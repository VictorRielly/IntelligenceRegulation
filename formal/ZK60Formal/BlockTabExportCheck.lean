/-
D63 lane L47 (2026-11-10), fork D: **the lookup side's public tables at the W16R2 rung against the code, by VALUE**
(finding L44-E2: lane L44's `BlockHelperExportCheck` compared the public tables' lengths only), with the verifier facts
the lookup side's statement takes: the slot kinds of `SC_LZC`, `SC_TAB`, `SC_ZS` (`hk3`, `hk19`, `hk20`) and `H`'s LogUp
sum claim (`P.logupSumClaim = DefW16.logupSumW16 DefW16.cfgRungW16`).

Run (through the zk60 resource guard; `results/zk60_lean_l47_20261110/exp_check.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/BlockTabExportCheck.lean <corpus> [neg]

The corpus is written by the test-only `ops/zkp-mvp/gpu-metal/hashline/src/lean_l47_export_tests.rs` on a REAL W16R2
rung block receipt (the production `prove_core` with `w16r2_tests`' seeded recipe, accepted by `verify_core`): the
transcript's `β, γ, α`; the fixture's exp table and scaled ACT tables; `SLOT_KINDS`; `protocol::logup_sum_claim`; and,
for slots 3, 19, 20, every public table the production `define` built: its length, two fingerprints `Σ_i v_i·ρ^i` at
fixed public points, its first and last 64 entries, and (FULL corpus) every entry. A corpus is compared only with the
export it came from (it is reproducible: the harness is seeded).

What it checks, with the Lean definitions only:
* every public table of slots 3, 19, 20 against `Tab.restE exp act nG s hist [] i` (BlockTabBase.lean), at the corpus's
  `β`, `γ` and the corpus's exp / ACT tables and group count: its length; every entry (FULL corpus); both fingerprints,
  computed here in the code's word arithmetic (`Fp2.mul`, `Fp2.add`); the first and last 64 entries;
* the slot programs' table counts of slots 3, 19, 20 (`DefW16.progW16 cfgRungW16`) against `define`'s;
* the code's slot kinds of slots 3, 19, 20 are `standalone`;
* `protocol::logup_sum_claim` against `DefW16.logupSumW16 cfgRungW16`: every part's offset, log size, coefficient (as
  words) and point, and the value.
With the argument `neg` it then runs the negative controls: single changes, to the code's tables (an entry of one
table per group: `SC_LZC`'s gate, the bytes, exp, ACT and a range column, two of `SC_TAB`'s gates, `SC_ZS`'s ones; a
fingerprint; a head entry), to the public data (an exp value, an ACT word, the group count, `β`), to a slot kind, to a
slot's table count and to the sum claim (a part's offset, a part's coefficient, the value); each must be caught. Not
imported by the library root (it defines `main`).
-/
import ZK60Formal.BlockTabBase

namespace ZK60.Exec.L47

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16 ZK60.Exec.Block.Join.W16.Tab

/-! ## Parsing -/

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def parseCsvInt (s : String) : Option (List ℤ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toInt?

def f2 (a b : ℕ) : Fp2 := ⟨⟨UInt64.ofNat a⟩, ⟨UInt64.ofNat b⟩⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

/-- A word as the corpus writes it: `c0,c1`. -/
def w2 (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

def w2s (l : List Fp2) : String := if l.isEmpty then "-" else ",".intercalate (l.map w2)

/-- **The fingerprint `Σ_i v_i·ρ^i`** in the code's word arithmetic (Horner from the last entry, as the export). -/
def fprint (v : List Fp2) (ρ : Fp2) : Fp2 := v.foldr (fun x acc => Fp2.add (Fp2.mul acc ρ) x) Fp2.zero

def kindStr : SlotKind → String
  | .priv => "private"
  | .standalone => "standalone"
  | .host => "host"

/-! ## The corpus -/

structure PubRec where
  s : ℕ
  i : ℕ
  n : ℕ
  fp1 : Fp2
  fp2 : Fp2
  head : List Fp2
  tail : List Fp2

structure Corp where
  name : String := ""
  nSlots : ℕ := 0
  logCols : ℕ := 0
  rho1 : Fp2 := Fp2.zero
  rho2 : Fp2 := Fp2.zero
  beta : Fp2 := Fp2.zero
  gamma : Fp2 := Fp2.zero
  alpha : Fp2 := Fp2.zero
  expLen : ℕ := 0
  exp : Array ℤ := #[]
  ng : ℕ := 0
  act : Array (Array ℤ) := #[]
  kinds : Array String := #[]
  sumN : ℕ := 0
  sumVal : Fp2 := Fp2.zero
  parts : Array (ℕ × ℕ × Fp2 × List Fp2) := #[]
  slots : List (ℕ × ℕ × ℕ) := []
  pubs : Array PubRec := #[]
  full : Array (ℕ × ℕ × Array Fp2) := #[]
  done : Option (ℕ × ℕ) := none
  bad : List String := []

def Corp.err (c : Corp) (l : String) : Corp := { c with bad := c.bad ++ [s!"{l.take 160}"] }

/-- The words between two markers of a `PUB` line. -/
def between (ws : List String) (a b : String) : List String :=
  ((ws.dropWhile (· != a)).drop 1).takeWhile (· != b)

def parseLine (c : Corp) (l : String) : Corp :=
  let ws := (l.splitOn " ").filter (· ≠ "")
  match ws with
  | ["L47", nm, ns, lc] =>
    match ns.toNat?, lc.toNat? with
    | some a, some b => { c with name := nm, nSlots := a, logCols := b }
    | _, _ => c.err l
  | ["RHO", a, b] =>
    match pF2 a, pF2 b with
    | some x, some y => { c with rho1 := x, rho2 := y }
    | _, _ => c.err l
  | ["LOGUP", a, b, g] =>
    match pF2 a, pF2 b, pF2 g with
    | some x, some y, some z => { c with beta := x, gamma := y, alpha := z }
    | _, _, _ => c.err l
  | ["EXP", n, vs] =>
    match n.toNat?, parseCsvInt vs with
    | some k, some v => { c with expLen := k, exp := v.toArray }
    | _, _ => c.err l
  | ["NG", n] =>
    match n.toNat? with
    | some k => { c with ng := k }
    | none => c.err l
  | ["ACT", g, n, vs] =>
    match g.toNat?, n.toNat?, parseCsvInt vs with
    | some gi, some k, some v =>
      if gi = c.act.size ∧ k = v.length then { c with act := c.act.push v.toArray } else c.err l
    | _, _, _ => c.err l
  | ["KINDS", n, ks] =>
    match n.toNat? with
    | some k => if (ks.splitOn ",").length = k then { c with kinds := (ks.splitOn ",").toArray } else c.err l
    | none => c.err l
  | ["SUMCLAIM", n, v] =>
    match n.toNat?, pF2 v with
    | some k, some x => { c with sumN := k, sumVal := x }
    | _, _ => c.err l
  | ["PART", j, off, lg, cf, pt] =>
    match j.toNat?, off.toNat?, lg.toNat?, pF2 cf, pF2s pt with
    | some ji, some o, some g, some x, some p =>
      if ji = c.parts.size then { c with parts := c.parts.push (o, g, x, p) } else c.err l
    | _, _, _, _, _ => c.err l
  | ["SLOT", s, nt, np] =>
    match s.toNat?, nt.toNat?, np.toNat? with
    | some a, some b, some d => { c with slots := c.slots ++ [(a, b, d)] }
    | _, _, _ => c.err l
  | "PUB" :: s :: i :: n :: "FP" :: a :: b :: _ =>
    match s.toNat?, i.toNat?, n.toNat?, pF2 a, pF2 b, pF2s ((between ws "HEAD" "TAIL").headD ""),
        pF2s ((between ws "TAIL" "").headD "") with
    | some si, some ii, some k, some x, some y, some h, some t =>
      { c with pubs := c.pubs.push ⟨si, ii, k, x, y, h, t⟩ }
    | _, _, _, _, _, _, _ => c.err l
  | ["FULL", s, i, n, vs] =>
    match s.toNat?, i.toNat?, n.toNat?, pF2s vs with
    | some si, some ii, some k, some v =>
      if v.length = k then { c with full := c.full.push (si, ii, v.toArray) } else c.err l
    | _, _, _, _ => c.err l
  | ["DONE", a, b] =>
    match a.toNat?, b.toNat? with
    | some x, some y => { c with done := some (x, y) }
    | _, _ => c.err l
  | [] => c
  | _ => c.err l

/-! ## The Lean side -/

/-- The exp table of the corpus as a function (`0` out of range). -/
def expF (c : Corp) : ℤ → ℤ := fun i => if 0 ≤ i ∧ i < 256 then c.exp.getD i.toNat 0 else 0

/-- The scaled ACT tables of the corpus as a function (`0` out of range). -/
def actF (c : Corp) : ℕ → ℤ → ℤ := fun g i => if 0 ≤ i ∧ i < 4096 then (c.act.getD g #[]).getD i.toNat 0 else 0

def histC (c : Corp) : Hist := ⟨c.beta, c.gamma, c.alpha, []⟩

/-- The lookup side's public tables, slot and index. -/
def tabKeys : List (ℕ × ℕ) := [(3, 0)] ++ (List.range 27).map (fun i => (19, i)) ++ [(20, 0)]

/-- **The Lean tables**: `restE` at the corpus's public data and challenges, with their two fingerprints. -/
structure LTab where
  key : ℕ × ℕ
  vals : Array Fp2
  fp1 : Fp2
  fp2 : Fp2

def leanTabs (c : Corp) : List LTab :=
  tabKeys.map fun k =>
    let v := restE (expF c) (actF c) c.ng k.1 (histC c) [] k.2
    ⟨k, v.toArray, fprint v c.rho1, fprint v c.rho2⟩

/-! ## The checks -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 400}" else s.msgs }

/-- The first index where two word arrays differ, if any. -/
def firstDiff (a b : Array Fp2) : Option ℕ :=
  if a.size ≠ b.size then some (min a.size b.size)
  else (List.range a.size).find? fun i => a.getD i Fp2.zero != b.getD i Fp2.zero

def checkAll (c : Corp) (lt : List LTab) : St := Id.run do
  let mut st : St := {}
  st := st.check "parse" c.bad.isEmpty s!"unparsed lines: {c.bad}"
  -- the header
  st := st.check "header" (c.nSlots == W16R2.rungSlots.length) s!"slots {c.nSlots}"
  st := st.check "header" (c.logCols == cfgRungW16.logCols) s!"log_cols {c.logCols}"
  -- the public data
  st := st.check "data" (256 ≤ c.expLen ∧ c.exp.size = 256) s!"exp {c.expLen} {c.exp.size}"
  st := st.check "data" (1 ≤ c.ng ∧ c.ng ≤ 4 ∧ c.act.size = c.ng) s!"groups {c.ng}, tables {c.act.size}"
  st := st.check "data" (c.act.all fun t => t.size = 4096) "every ACT table has 4096 words"
  -- the slot kinds (`hk3`, `hk19`, `hk20`)
  st := st.check "kinds" (c.kinds.size == c.nSlots) s!"kinds {c.kinds.size}"
  for s in [3, 19, 20] do
    st := st.check "kinds" (c.kinds.getD s "" == kindStr .standalone) s!"slot {s}: code {c.kinds.getD s ""}"
  -- the LogUp sum claim (`hls`)
  let lc := logupSumW16 cfgRungW16
  st := st.check "sumclaim" (c.sumN == lc.parts.length ∧ c.parts.size == lc.parts.length)
    s!"parts {c.sumN} / {c.parts.size} vs Lean {lc.parts.length}"
  st := st.check "sumclaim" (c.sumVal == lc.value) s!"value {w2 c.sumVal} vs Lean {w2 lc.value}"
  for (p, j) in lc.parts.zipIdx do
    let q := c.parts.getD j (0, 0, Fp2.zero, [Fp2.zero])
    st := st.check "sumclaim" (q.1 == p.offset ∧ q.2.1 == p.logSize ∧ q.2.2.1 == p.coef ∧ q.2.2.2 == p.point)
      s!"part {j}: code {q.1}:{q.2.1}:{w2 q.2.2.1}:{w2s q.2.2.2} | Lean {p.offset}:{p.logSize}:{w2 p.coef}:{w2s p.point}"
  -- the slot programs' table counts
  for s in [3, 19, 20] do
    let sl := (progW16 cfgRungW16 0 0).getD s SlotS.empty
    let np := (sl.tabs.filter fun t => match t with | .pub _ => true | _ => false).length
    let code := (c.slots.find? fun q => q.1 == s).getD (0, 0, 0)
    st := st.check "slots" (code.2.1 == sl.tabs.length ∧ code.2.2 == np)
      s!"slot {s}: code {code.2.1} tables / {code.2.2} public, Lean {sl.tabs.length} / {np}"
  -- the public tables
  st := st.check "tables" (c.pubs.size == tabKeys.length) s!"public tables {c.pubs.size} vs {tabKeys.length}"
  for t in lt do
    match c.pubs.find? (fun r => r.s == t.key.1 ∧ r.i == t.key.2) with
    | none => st := st.check "tables" false s!"slot {t.key.1} table {t.key.2}: not in the corpus"
    | some r =>
      let tag := s!"slot {t.key.1} table {t.key.2}"
      st := st.check "length" (r.n == t.vals.size) s!"{tag}: code {r.n}, Lean {t.vals.size}"
      st := st.check "fingerprint" (r.fp1 == t.fp1) s!"{tag}: rho1 code {w2 r.fp1}, Lean {w2 t.fp1}"
      st := st.check "fingerprint" (r.fp2 == t.fp2) s!"{tag}: rho2 code {w2 r.fp2}, Lean {w2 t.fp2}"
      let e := min 64 t.vals.size
      st := st.check "ends" (r.head == (t.vals.toList.take e)) s!"{tag}: head"
      st := st.check "ends" (r.tail == (t.vals.toList.drop (t.vals.size - e))) s!"{tag}: tail"
    match c.full.find? (fun r => r.1 == t.key.1 ∧ r.2.1 == t.key.2) with
    | none => pure ()
    | some r =>
      match firstDiff r.2.2 t.vals with
      | none => st := st.check "entries" true ""
      | some i =>
        st := st.check "entries" false
          s!"slot {t.key.1} table {t.key.2}: first difference at {i}: code {w2 (r.2.2.getD i Fp2.zero)}, Lean {w2 (t.vals.getD i Fp2.zero)}"
  st := st.check "done" (c.done == some (tabKeys.length, tabKeys.length * 2 ^ 14)) s!"done {c.done}"
  return st

/-! ## The negative controls -/

def setFull (c : Corp) (s i idx : ℕ) : Corp :=
  { c with full := c.full.map fun r =>
      if r.1 == s ∧ r.2.1 == i then (r.1, r.2.1, r.2.2.modify idx (fun x => Fp2.add x Fp2.one)) else r }

def setPub (c : Corp) (s i : ℕ) (f : PubRec → PubRec) : Corp :=
  { c with pubs := c.pubs.map fun r => if r.s == s ∧ r.i == i then f r else r }

/-- Entry `k` of a word list plus one. -/
def bumpAt (l : List Fp2) (k : ℕ) : List Fp2 := l.zipIdx.map fun q => if q.2 = k then Fp2.add q.1 Fp2.one else q.1

def bumpHead (r : PubRec) : PubRec := { r with head := bumpAt r.head 3 }

/-- Single changes; `true` when the change touches the Lean side's inputs (the tables are recomputed). -/
def muts (c : Corp) : List (String × Bool × Corp) :=
  let full := !c.full.isEmpty
  let tabMut (s i : ℕ) : Corp :=
    if full then setFull c s i 1000 else setPub c s i fun r => { r with fp1 := Fp2.add r.fp1 Fp2.one }
  [("SC_LZC's gate, one entry", false, tabMut 3 0),
   ("SC_TAB's bytes column, one entry", false, tabMut 19 0),
   ("SC_TAB's exp column, one entry", false, tabMut 19 1),
   ("SC_TAB's ACT column, one entry", false, tabMut 19 2),
   ("SC_TAB's range column 5, one entry", false, tabMut 19 5),
   ("SC_TAB's supp(Tab) gate, one entry", false, tabMut 19 17),
   ("SC_TAB's narrow gate 2, one entry", false, tabMut 19 20),
   ("SC_ZS's ones, one entry", false, tabMut 20 0),
   ("a fingerprint (rho2) of the range column 9", false, setPub c 19 9 fun r => { r with fp2 := Fp2.add r.fp2 Fp2.one }),
   ("a head entry of the ACT gate", false, setPub c 19 18 bumpHead),
   ("an exp value (exp[5] + 1)", true, { c with exp := c.exp.modify 5 (· + 1) }),
   ("an ACT word (group 0, gate 7, + 1)", true, { c with act := c.act.modify 0 fun t => t.modify 7 (· + 1) }),
   ("the group count (− 1)", true, { c with ng := c.ng - 1 }),
   ("beta (+ 1)", true, { c with beta := Fp2.add c.beta Fp2.one }),
   ("slot 19's kind (host)", false, { c with kinds := c.kinds.set! 19 "host" }),
   ("slot 3's table count", false, { c with slots := c.slots.map fun q => if q.1 == 3 then (q.1, q.2.1 + 1, q.2.2) else q }),
   ("a sum-claim part's offset (part 7)", false,
     { c with parts := c.parts.modify 7 fun q => (q.1 + 16384, q.2) }),
   ("a sum-claim part's coefficient (part 60)", false,
     { c with parts := c.parts.modify 60 fun q => (q.1, q.2.1, Fp2.add q.2.2.1 Fp2.one, q.2.2.2) }),
   ("the sum claim's value", false, { c with sumVal := Fp2.one })]

def report (st : St) : IO Unit := do
  for (k, n) in st.kinds do
    IO.println s!"  {k}: {n}"
  for m in st.msgs do
    IO.println s!"  FAIL {m}"

end ZK60.Exec.L47

open ZK60.Exec.L47 in
def main (args : List String) : IO UInt32 := do
  let path := args.headD ""
  let txt ← IO.FS.readFile path
  let c := (txt.splitOn "\n").foldl parseLine {}
  IO.println s!"corpus {path}: {c.name}, {c.pubs.size} public tables, {c.full.size} in full, {c.parts.size} sum-claim parts"
  let lt := leanTabs c
  let st := checkAll c lt
  IO.println s!"checks: {st.ok} passed, {st.fail} failed"
  report st
  let mut rc : UInt32 := if st.fail = 0 then 0 else 1
  if args.contains "neg" then
    let ms := muts c
    let mut caught := 0
    for (nm, recompute, c') in ms do
      let st' := checkAll c' (if recompute then leanTabs c' else lt)
      if st'.fail > 0 then
        caught := caught + 1
        IO.println s!"negative control CAUGHT ({st'.fail} failed): {nm}"
      else
        IO.println s!"negative control MISSED: {nm}"
    IO.println s!"negative controls: {caught} of {ms.length} caught"
    if caught ≠ ms.length then rc := 1
  return rc
