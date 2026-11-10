/-
D63 lane L31 (2026-11-09): the agreement check of the concrete block profiles (`BlockInstProf.lean`) against REAL
receipts.

Run (through the zk60 resource guard; `results/zk60_lean_l31_20261109/check_l31.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/BlockInstCheck.lean \
    results/zk60_lean_l9_20261107/corpus.txt results/zk60_lean_l17_20261107/block_corpus.txt \
    results/zk60_lean_l17_20261107/shape_corpus.txt

The corpora are committed: L9's (the W16R2 development rung's block, proved by the production `prove_core` and accepted
by the production `verify_core`), L17's block corpus (the R13 development rung's block, the same way), and L17's shape
corpus (the registered shapes' own constructors: counts, schedules, helper counts).

With the SAME definitions the theorems use (`Link.numsW16Rung`, `numsR13Rung`, `numsR13Shield`; the commitment
schedules `aCnt…`, `hCnt…`; `shapeSqW`; the schedules of L9 / L17), it checks, at each rung receipt:
the rows of `A` and `H`, the group counts, the mask specs, the functional count; the index squeezes `⌈Q/4⌉`; the claims
per opening (the sum of the receipt's group member counts) and the number of groups; `H`'s groups against the `H`
schedule slot by slot (a slot's `H` claims share its point, so they are one group; the LogUp sum claim is the last);
each slot's terminal count as its `A`, `H` and endpoint tables; the schedule and the draws; the squeeze counter at
`M`'s window (`hdrSq + 3 + shapeSq`) against the receipt's counter after the last slot; and the final squeeze counter
of the whole run (`OProf.hsq`'s expression) against the receipt's end counter.
At the Shieldstral T128 R13 shape (no receipt of it is in the repository) and at the R13 rung, from the shape corpus:
the rows, groups, mask specs, functionals and opened columns; the schedule and the terminal counts; and the `H`
schedule as the shape's helper counts give it (`L`, `D`, `Q`, `Kv`, `S + 1`, `F + 1`, `3 + n_range`, `1`), with its
total the shape's `H` plane count.

It prints the checks per kind and `BlockInstCheck: N checks, F failed`, and exits nonzero on any failure. Not imported
by the library root (it defines `main`).
-/
import ZK60Formal.BlockInstProf

namespace ZK60.Exec.L31Check

open ZK60.Exec

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
  else { s with fail := s.fail + 1, msgs := s.msgs.push s!"[{kind}] {msg}" }

/-- The word after the first occurrence of the key `k`. -/
def kvOf : List String → String → String
  | a :: b :: rest, k => if a = k then b else kvOf (b :: rest) k
  | _, _ => ""

/-- The value of the first `k=value` word. -/
def eqOf (w : List String) (k : String) : String :=
  match w.find? (fun x => x.startsWith (k ++ "=")) with
  | some x => (x.splitOn "=").getD 1 ""
  | none => ""

def natOf (s : String) : ℕ := s.toNat?.getD 0

def natsOf (s : String) : List ℕ := if s = "-" ∨ s = "" then [] else (s.splitOn ",").map natOf

def recOf (lines : List (List String)) (k : String) : List String := (lines.find? (fun w => w.headD "" = k)).getD []

def recsOf (lines : List (List String)) (k : String) : List (List String) := lines.filter (fun w => w.headD "" = k)

def wordsOf (ls : Array String) : List (List String) :=
  (ls.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))

/-- The endpoint tables: one at `SC_IO_IN` (slot 21) and one at `SC_IO_OUT` (slot 22). -/
def ioCnt (k : ℕ) : ℕ := if k = 21 ∨ k = 22 then 1 else 0

/-- `PCS <name> counts …`: the group member counts of one opening. -/
def pcsCounts (lines : List (List String)) (nm : String) : List ℕ :=
  natsOf (kvOf (((recsOf lines "PCS").find? (fun w => w.getD 1 "" = nm)).getD []) "counts")

/-- **One rung receipt against its profile.** -/
def checkBlock (s0 : St) (nm : String) (nums : Link.ProfNums) (drawList : List ℕ) (slots : List (ℕ × ℕ × ℕ))
    (aC hC : List ℕ) (lines : List (List String)) : St := Id.run do
  let mut s := s0
  let sh := recOf lines "SHAPE"
  let g (k : String) : ℕ := natOf (kvOf sh k)
  s := s.check "ROWS" (g "a_rows" == nums.rA && g "h_rows" == nums.rH)
    s!"{nm}: rows {g "a_rows"} / {g "h_rows"} against {nums.rA} / {nums.rH}"
  s := s.check "GROUPS" (g "a_groups" == nums.aGroups && g "h_groups" == nums.hGroups) s!"{nm}: groups"
  s := s.check "MASK-SPECS" (g "mask_specs" == nums.S) s!"{nm}: mask specs {g "mask_specs"}"
  s := s.check "FUNCTIONALS" (natOf ((recOf lines "FUNCTIONALS").getD 1 "") == nums.nFun) s!"{nm}: functionals"
  s := s.check "INDEX-SQUEEZES" (g "q" == nums.Q && (nums.Q + 3) / 4 == nums.mI) s!"{nm}: Q {g "q"}, mI {nums.mI}"
  let ca := pcsCounts lines "A"
  let ch := pcsCounts lines "H"
  s := s.check "CLAIMS-A" (ca.sum == nums.nA && ca.length == nums.aGroups) s!"{nm}: A claims {ca.sum} in {ca.length}"
  s := s.check "CLAIMS-H" (ch.sum == nums.nH && ch.length == nums.hGroups) s!"{nm}: H claims {ch.sum} in {ch.length}"
  s := s.check "H-SCHEDULE" (ch == hC.filter (· ≠ 0) ++ [1]) s!"{nm}: H groups {ch}"
  let rows := recsOf lines "SLOTSHAPE"
  s := s.check "SLOT-COUNT" (rows.length == 23 && g "n_slots" == 23) s!"{nm}: {rows.length} slots"
  s := s.check "SCHEDULE" (rows.map (fun w => (natOf (w.getD 2 ""), natOf (w.getD 3 ""), natOf (w.getD 4 ""))) == slots)
    s!"{nm}: the slot schedule"
  for w in rows do
    let k := natOf (w.getD 1 "")
    s := s.check "TERMS" (aC.getD k 0 + hC.getD k 0 + ioCnt k == natOf (w.getD 5 ""))
      s!"{nm}: slot {k}: {aC.getD k 0} + {hC.getD k 0} + {ioCnt k} against {w.getD 5 ""}"
  let srecs := recsOf lines "SLOT"
  s := s.check "DRAWS" (srecs.map (fun w => (natsOf (kvOf w "draws")).length / 2) == drawList) s!"{nm}: the draw counts"
  let c0 := natOf ((recOf lines "START").getD 2 "")
  let draws (k : ℕ) : ℕ := drawList.getD k 0
  let cM := c0 + 3 + Link.shapeSqW draws 0 slots
  let lastCtr := natOf ((srecs.getLast?.getD []).getLast?.getD "")
  s := s.check "COUNTER-M" (lastCtr == cM) s!"{nm}: the counter after the slots {lastCtr} against {cM}"
  let cEnd := cM + (2 * nums.S + 67) + (nums.nA + nums.rA) + nums.mI + (nums.nH + nums.rH) + nums.mI
  let endCtr := natOf ((recOf lines "END").getD 2 "")
  s := s.check "COUNTER-END" (endCtr == cEnd) s!"{nm}: the end counter {endCtr} against {cEnd}"
  return s

/-- The lines of one profile of the shape corpus. -/
def profLines (lines : List (List String)) (name : String) : List (List String) :=
  ((lines.dropWhile (fun w => !(w.headD "" = "PROFILE" && w.getD 1 "" = name))).drop 1).takeWhile
    (fun w => w.headD "" ≠ "PROFILE")

def parseSched (s : String) : List (ℕ × ℕ × ℕ) :=
  (s.splitOn ",").map fun x =>
    match x.splitOn ":" with
    | [a, b, c] => (natOf a, natOf b, natOf c)
    | _ => (0, 0, 0)

/-- The `H` schedule the shape's helper counts give: `Dom::L` at `SC_LZC` (slot 3), `D`, `Q`, `Kv` at their
zero-checks (14, 15, 16), `S` with the exp helper (17), `F` with the ACT helper (18), the three table helpers and the
range tables at `SC_TAB` (19), the zero-sum row at `SC_ZS` (20). -/
def hFromHelpers (helpers : List ℕ) (nRange : ℕ) : List ℕ :=
  [0, 0, 0, helpers.getD 2 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, helpers.getD 3 0, helpers.getD 4 0, helpers.getD 5 0,
    helpers.getD 6 0 + 1, helpers.getD 7 0 + 1, 3 + nRange, 1, 0, 0]

/-- **One registered shape against its profile.** -/
def checkShape (s0 : St) (nm : String) (prof : String) (nums : Link.ProfNums) (slots : List (ℕ × ℕ × ℕ))
    (terms hC : List ℕ) (lines : List (List String)) : St := Id.run do
  let mut s := s0
  let pl := profLines lines prof
  let cn := recOf pl "COUNTS"
  let g (k : String) : ℕ := natOf (kvOf cn k)
  s := s.check "SHAPE-COUNTS" (g "a_rows" == nums.rA && g "h_rows" == nums.rH && g "a_groups" == nums.aGroups
    && g "h_groups" == nums.hGroups && g "functionals" == nums.nFun && g "mask_specs" == nums.S && g "q" == nums.Q)
    s!"{nm}: rows {g "a_rows"} / {g "h_rows"}, groups, functionals, mask specs, Q"
  s := s.check "SHAPE-SCHEDULE" (parseSched ((recOf pl "SCHED").getD 1 "") == slots) s!"{nm}: the slot schedule"
  s := s.check "SHAPE-TERMS" (natsOf ((recOf pl "TERMSDECL").getD 1 "") == terms) s!"{nm}: the terminal counts"
  let shp := recOf pl "SHAPE"
  let hh := hFromHelpers (natsOf (eqOf shp "helpers")) (natOf (eqOf shp "n_range"))
  s := s.check "SHAPE-H-SCHEDULE" (hh == hC) s!"{nm}: the H schedule from the helper counts {hh}"
  s := s.check "SHAPE-H-PLANES" (hC.sum == g "h_planes") s!"{nm}: H planes {g "h_planes"} against {hC.sum}"
  return s

def main (args : List String) : IO UInt32 := do
  let p16 := args.headD "results/zk60_lean_l9_20261107/corpus.txt"
  let p13 := args.getD 1 "results/zk60_lean_l17_20261107/block_corpus.txt"
  let psh := args.getD 2 "results/zk60_lean_l17_20261107/shape_corpus.txt"
  let l16 := wordsOf (← IO.FS.lines p16)
  let l13 := wordsOf (← IO.FS.lines p13)
  let lsh := wordsOf (← IO.FS.lines psh)
  let mut s : St := {}
  s := checkBlock s "W16R2 rung" Link.numsW16Rung Block.W16R2.rungDrawList Block.W16R2.rungSlots Link.aCntW16Rung
    Link.hCntW16Rung l16
  s := checkBlock s "R13 rung" Link.numsR13Rung Block.R13.rungDrawList Block.R13.rungSlots Link.aCntR13Rung
    Link.hCntR13Rung l13
  s := checkShape s "R13 rung shape" "hashline-zk-mr1/private-block-rung-lh-t32-dev/2" Link.numsR13Rung
    Block.R13.rungSlots Block.R13.rungTerms Link.hCntR13Rung lsh
  s := checkShape s "Shieldstral T128 R13 shape" "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2"
    Link.numsR13Shield Block.R13.shieldSlots Block.R13.shieldTerms Link.hCntR13Shield lsh
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"BlockInstCheck: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)

end ZK60.Exec.L31Check

def main (args : List String) : IO UInt32 := ZK60.Exec.L31Check.main args
