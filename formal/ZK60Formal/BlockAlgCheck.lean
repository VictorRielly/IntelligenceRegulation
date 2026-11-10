/-
D63 lane L36 (2026-11-09): the agreement check of the block algebra's shape facts and lookup counts
(`BlockAlgShapes.lean`) against the code's registered shapes.

Run (through the zk60 resource guard; `results/zk60_lean_l36_20261109/check_l36.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/BlockAlgCheck.lean \
    results/zk60_lean_l17_20261107/shape_corpus.txt

L17's shape corpus is committed: the registered shapes' own constructors (`SHAPE`: the axis and domain logs, the pads,
the helper counts; `LOOKUPS`: the lookups per cube position of each LogUp domain), for the W16R2 rung, the R13 rung
and the Shieldstral T128 R13 block (and the W16R2 Shieldstral twin, not read here).

With the SAME definitions the theorems use (`shRungW16`, `shRungR13`, `shShieldR13`; `perW16Rung`, `perR13Rung`,
`perR13Shield`; `lkCount`; the numbers `algShapeW16Rung`, `algShapeR13Rung`, `algShapeR13Shield` pass to
`algShapeStd`), it checks per profile: the nine domain logs; the helper counts; the lookups per position of the six
LogUp domains; that each domain's helpers pair its lookups (`helpers = ⌈lookups / 2⌉`); the block's lookup count
recomputed from the corpus against `lkCount` and against the theorem's figure; and the algebra's numbers (`lt`, `lh`,
`lq`, `lf`, `Dom::Ht`'s log, `Dom::S`'s column log).

It prints the checks per kind and `BlockAlgCheck: N checks, F failed`, and exits nonzero on any failure. Not imported
by the library root (it defines `main`).
-/
import ZK60Formal.BlockAlgShapes

namespace ZK60.Exec.L36Check

open ZK60.Exec
open ZK60.Exec.Slot.W16R2 (ShapeW Dom)

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

/-- The value of the first `k=value` word. -/
def eqOf (w : List String) (k : String) : String :=
  match w.find? (fun x => x.startsWith (k ++ "=")) with
  | some x => (x.splitOn "=").getD 1 ""
  | none => ""

def natOf (s : String) : ℕ := s.toNat?.getD 0

def natsOf (s : String) : List ℕ := if s = "-" ∨ s = "" then [] else (s.splitOn ",").map natOf

def wordsOf (ls : Array String) : List (List String) :=
  (ls.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))

/-- The records after the `PROFILE name` line, up to the next `PROFILE`. -/
def profOf : List (List String) → String → List (List String)
  | [], _ => []
  | w :: rest, nm =>
    if w.headD "" = "PROFILE" ∧ w.getD 1 "" = nm then rest.takeWhile (fun x => x.headD "" ≠ "PROFILE")
    else profOf rest nm

def recOf (lines : List (List String)) (k : String) : List String := (lines.find? (fun w => w.headD "" = k)).getD []

/-- The lookups per position of a domain, from a `LOOKUPS L:2,D:34,…` record. -/
def lkOf (w : List String) (d : String) : ℕ :=
  match ((w.getD 1 "").splitOn ",").find? (fun x => x.startsWith (d ++ ":")) with
  | some x => natOf ((x.splitOn ":").getD 1 "")
  | none => 0

/-- The nine domains in `ALL_DOMS` order. -/
def doms : List Dom := [.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab]

/-- The six LogUp domains with the corpus's names. -/
def lkDoms : List (Dom × String) := [(.L, "L"), (.D, "D"), (.Q, "Q"), (.Kv, "Kv"), (.S, "S"), (.F, "F")]

def checkProf (s : St) (nm prof : String) (sh : ShapeW) (per : Dom → ℕ) (total : ℕ) (nums : List ℕ)
    (lines : List (List String)) : St := Id.run do
  let recs := profOf lines prof
  let shp := recOf recs "SHAPE"
  let lk := recOf recs "LOOKUPS"
  let mut s := s
  s := s.check "PROFILE" (shp ≠ [] && lk ≠ []) s!"{nm}: the profile {prof} is in the corpus"
  let logs := natsOf (eqOf shp "logs")
  let helpers := natsOf (eqOf shp "helpers")
  s := s.check "LOGS" (logs == doms.map sh.logs) s!"{nm}: logs {logs} against {doms.map sh.logs}"
  s := s.check "HELPERS" (helpers == doms.map sh.helpers) s!"{nm}: helpers {helpers} against {doms.map sh.helpers}"
  for (d, dn) in lkDoms do
    s := s.check "LOOKUPS" (lkOf lk dn == per d) s!"{nm}: lookups of {dn}: {lkOf lk dn} against {per d}"
    s := s.check "PAIRING" (sh.helpers d == (lkOf lk dn + 1) / 2)
      s!"{nm}: helpers of {dn}: {sh.helpers d} against half of {lkOf lk dn} lookups, rounded up"
  let cnt := (lkDoms.map fun p => 2 ^ logs.getD p.1.idx 0 * lkOf lk p.2).sum
  s := s.check "COUNT" (cnt == Block.lkCount sh per) s!"{nm}: the corpus's count {cnt} against {Block.lkCount sh per}"
  s := s.check "COUNT" (cnt == total) s!"{nm}: the corpus's count {cnt} against the theorem's {total}"
  let g := fun k => natOf (eqOf shp k)
  let alg := [g "lt", g "lh", g "lq", g "lf", logs.getD 1 0, logs.getD 6 0 - logs.getD 1 0]
  s := s.check "ALG-NUMBERS" (alg == nums) s!"{nm}: lt, lh, lq, lf, log Ht, log S - log Ht: {alg} against {nums}"
  return s

def main (args : List String) : IO UInt32 := do
  let psh := args.headD "results/zk60_lean_l17_20261107/shape_corpus.txt"
  let lsh := wordsOf (← IO.FS.lines psh)
  let mut s : St := {}
  s := checkProf s "W16R2 rung" "hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2"
    ZK60.Exec.Slot.W16R2.shRungW16 Block.perW16Rung 1015808 [5, 4, 10, 10, 9, 5] lsh
  s := checkProf s "R13 rung" "hashline-zk-mr1/private-block-rung-lh-t32-dev/2"
    ZK60.Exec.Slot.R13.shRungR13 Block.perR13Rung 2015232 [5, 4, 10, 10, 9, 5] lsh
  s := checkProf s "Shieldstral T128 R13" "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2"
    ZK60.Exec.Slot.R13.shShieldR13 Block.perR13Shield 64258048 [7, 5, 12, 14, 12, 7] lsh
  s := s.check "BOUND" (decide (35153256 < Block.lkCount ZK60.Exec.Slot.R13.shShieldR13 Block.perR13Shield))
    "the Shieldstral T128 R13 count exceeds 35,153,256 (finding L36-1)"
  s := s.check "BOUND" (decide (Block.lkCount ZK60.Exec.Slot.R13.shShieldR13 Block.perR13Shield ≤ 2 ^ 26))
    "the Shieldstral T128 R13 count is within 2^26"
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"BlockAlgCheck: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)

end ZK60.Exec.L36Check

def main (args : List String) : IO UInt32 := ZK60.Exec.L36Check.main args
