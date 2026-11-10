/-
D63 lane L49 (2026-11-10), sub-agent `look`: **R13's LogUp sum claim against the code** (`protocol::logup_sum_claim`
at the R13 rung, `R13_RUNG_H24`), by value.

Run (through the zk60 resource guard):
  lake -d formal env lean --run formal/ZK60Formal/BlockR13LookSumCheck.lean <corpus> [neg]

The corpus is lane L47's R13 export (`lean_l47_export_the_r13_lookup_side`, fork D: L44's R13 rung receipt, proved by
the production `prove_core` and accepted by `verify_core`; `results/zk60_lean_l47_20261110/l47_r13_short.txt`, and the
full corpus outside the repository, sha256 in `l47_export_sha256.txt`; their `SUMCLAIM` and `PART` lines are the same).
Its `SUMCLAIM n v` line gives the claim's part count and value, its `PART j offset log_size coef point` lines every part
in order (`coef` as two words, `point` empty `-`).

What it checks, with the Lean definition only: `logupSumR13 cfgRungR13` (BlockR13LookLk.lean) has the corpus's part
count, value, and every part's offset, log size, coefficient words and point, in order; the corpus is the R13 rung's;
the corpus's parts number `2·|hDoms|` (54 `H` planes at the rung).
With the argument `neg` it then runs the negative controls: single changes to the corpus (a part's offset, log size,
coefficient, point; a missing part; two parts swapped; the value; the header) and to the Lean side (the claim with
the table helpers' signs `+1`, with `H_U`'s sign `−1`, with the imaginary halves' coefficient `sign` instead of
`sign·u`, with the log size of `Dom::Q`'s helpers set to `14`); each must be caught. Not imported by the library root
(it defines `main`).
-/
import ZK60Formal.BlockR13LookLk

namespace ZK60.Exec.L49Look

open ZK60.Exec ZK60.Exec.Block

/-! ## Parsing -/

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

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

structure Corp where
  name : String := ""
  sumN : ℕ := 0
  sumVal : Fp2 := Fp2.zero
  parts : Array (ℕ × ℕ × Fp2 × List Fp2) := #[]
  bad : List String := []

def Corp.err (c : Corp) (l : String) : Corp := { c with bad := c.bad ++ [s!"{l.take 160}"] }

/-- Only the header and the sum claim are read (the other lines are lane L47's table checks). -/
def parseLine (c : Corp) (l : String) : Corp :=
  let ws := (l.splitOn " ").filter (· ≠ "")
  match ws with
  | ["L47", nm, _, _] => { c with name := nm }
  | ["SUMCLAIM", n, v] =>
    match n.toNat?, pF2 v with
    | some k, some x => { c with sumN := k, sumVal := x }
    | _, _ => c.err l
  | ["PART", j, off, lg, cf, pt] =>
    match j.toNat?, off.toNat?, lg.toNat?, pF2 cf, pF2s pt with
    | some ji, some o, some g, some x, some p =>
      if ji = c.parts.size then { c with parts := c.parts.push (o, g, x, p) } else c.err l
    | _, _, _, _, _ => c.err l
  | _ => c

/-! ## The checks -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]

def St.check (s : St) (b : Bool) (msg : String) : St :=
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 40 then s.msgs.push s!"{msg.take 300}" else s.msgs }

/-- **The comparison**: the corpus's sum claim against a Lean claim `lc` (part by part). -/
def checkAll (c : Corp) (lc : Block.ZClaim) : St := Id.run do
  let mut st : St := {}
  st := st.check c.bad.isEmpty s!"unparsed lines: {c.bad}"
  st := st.check (c.name == "R13_RUNG_H24") s!"corpus {c.name} is not the R13 rung's"
  st := st.check (2 * (DefR13.hDoms DefR13.cfgRungR13).length == lc.parts.length)
    s!"Lean parts {lc.parts.length} vs 2·|H planes| {2 * (DefR13.hDoms DefR13.cfgRungR13).length}"
  st := st.check (c.sumN == lc.parts.length ∧ c.parts.size == lc.parts.length)
    s!"parts: code {c.sumN} / {c.parts.size}, Lean {lc.parts.length}"
  st := st.check (c.sumVal == lc.value) s!"value: code {w2 c.sumVal}, Lean {w2 lc.value}"
  for (p, j) in lc.parts.zipIdx do
    let q := c.parts.getD j (0, 0, Fp2.zero, [Fp2.zero])
    st := st.check (q.1 == p.offset ∧ q.2.1 == p.logSize ∧ q.2.2.1 == p.coef ∧ q.2.2.2 == p.point)
      s!"part {j}: code {q.1}:{q.2.1}:{w2 q.2.2.1}:{w2s q.2.2.2} | Lean {p.offset}:{p.logSize}:{w2 p.coef}:{w2s p.point}"
  return st

/-! ## The negative controls -/

/-- The Lean claim with one change to its rule (a wrong transcription). -/
def lcMut (k : ℕ) : Block.ZClaim :=
  let c := DefR13.cfgRungR13
  ⟨(List.range (DefR13.hDoms c).length).flatMap (fun hp =>
      let tab := decide (DefR13.fh c 8 ≤ hp) && decide (hp < DefR13.fh c 8 + 3)
      let sign := if k = 0 then Fp2.one
        else if k = 1 then (if tab || hp == DefR13.fh c 10 then Fp2.one.neg else Fp2.one)
        else (if tab then Fp2.one.neg else Fp2.one)
      let d := (DefR13.hDoms c).getD hp .Tab
      let ls := if k = 3 ∧ d = .Q then 14 else c.sh.logs d
      let im := if k = 2 then sign else sign.mul fp2U
      [⟨(DefR13.hOff c hp).1, ls, sign, []⟩, ⟨(DefR13.hOff c hp).2, ls, im, []⟩]), Fp2.zero⟩

def setPart (c : Corp) (j : ℕ) (f : ℕ × ℕ × Fp2 × List Fp2 → ℕ × ℕ × Fp2 × List Fp2) : Corp :=
  { c with parts := c.parts.modify j f }

/-- The corpus with two parts swapped. -/
def swap (c : Corp) (a b : ℕ) : Corp :=
  let pa := c.parts.getD a (0, 0, Fp2.zero, [])
  let pb := c.parts.getD b (0, 0, Fp2.zero, [])
  { c with parts := (c.parts.set! a pb).set! b pa }

/-- Single changes; the second component is the Lean claim to compare with. -/
def muts (c : Corp) : List (String × Corp × Block.ZClaim) :=
  let lc := ZK60.Exec.Block.Join.R13H.Look.logupSumR13 DefR13.cfgRungR13
  [("a part's offset (part 37 + 16384)", setPart c 37 (fun q => (q.1 + 16384, q.2)), lc),
   ("a part's log size (part 40: 14)", setPart c 40 (fun q => (q.1, 14, q.2.2)), lc),
   ("a table helper's sign (part 100: +1)", setPart c 100 (fun q => (q.1, q.2.1, Fp2.one, q.2.2.2)), lc),
   ("an imaginary half's coefficient (part 7: 1)", setPart c 7 (fun q => (q.1, q.2.1, Fp2.one, q.2.2.2)), lc),
   ("a part's point (part 3: one coordinate)", setPart c 3 (fun q => (q.1, q.2.1, q.2.2.1, [Fp2.one])), lc),
   ("a missing part (the last)", { c with parts := c.parts.pop, sumN := c.sumN - 1 }, lc),
   ("two parts swapped (64, 66)", swap c 64 66, lc),
   ("the value (1)", { c with sumVal := Fp2.one }, lc),
   ("the header (the W16R2 rung's)", { c with name := "W16R2_RUNG_H24" }, lc),
   ("Lean: the table helpers' sign +1", c, lcMut 0),
   ("Lean: H_U's sign -1", c, lcMut 1),
   ("Lean: the imaginary halves' coefficient sign (not sign·u)", c, lcMut 2),
   ("Lean: Dom::Q's helpers at log size 14", c, lcMut 3)]

def report (st : St) : IO Unit := do
  for m in st.msgs do
    IO.println s!"  FAIL {m}"

end ZK60.Exec.L49Look

open ZK60.Exec.L49Look in
def main (args : List String) : IO UInt32 := do
  let path := args.headD ""
  let txt ← IO.FS.readFile path
  let c := (txt.splitOn "\n").foldl parseLine {}
  let lc := ZK60.Exec.Block.Join.R13H.Look.logupSumR13 ZK60.Exec.Block.DefR13.cfgRungR13
  IO.println s!"corpus {path}: {c.name}, SUMCLAIM {c.sumN} parts, {c.parts.size} PART lines; Lean {lc.parts.length} parts"
  let st := checkAll c lc
  IO.println s!"checks: {st.ok} passed, {st.fail} failed"
  report st
  let mut rc : UInt32 := if st.fail = 0 then 0 else 1
  if args.contains "neg" then
    let ms := muts c
    let mut caught := 0
    for (nm, c', lc') in ms do
      let st' := checkAll c' lc'
      if st'.fail > 0 then
        caught := caught + 1
        IO.println s!"negative control CAUGHT ({st'.fail} failed): {nm}"
      else
        IO.println s!"negative control MISSED: {nm}"
    IO.println s!"negative controls: {caught} of {ms.length} caught"
    if caught ≠ ms.length then rc := 1
  return rc
