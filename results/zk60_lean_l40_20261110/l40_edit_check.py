#!/usr/bin/env python3
"""D63 lane L40 (2026-11-10): a one-off source edit of formal/ZK60Formal/RunShapeCheck.lean (kept for the record): the
negative control compares EVERY stage with the Rust words (not only the block's output, which the fixture's small
synthetic weights leave unchanged under most single changes), with stronger single changes.

usage: python3 -I l40_edit_check.py <RunShapeCheck.lean>
"""
import sys

p = sys.argv[1]
s = open(p).read()
s = s.replace("""  { gA := fun i => gam.getD i.val 0 + (if m == .gamma && i.val == 0 then 1 else 0)""",
              """  { gA := fun i => gam.getD i.val 0 + (if m == .gamma && i.val == 0 then 50 else 0)""")
s = s.replace("""      + (if m == .wq && i.val == 0 && qIdx c.1.val c.2.1 c.2.2.val == 0 then 7 else 0)""",
              """      + (if m == .wq && qIdx c.1.val c.2.1 c.2.2.val == 0 then 100 else 0)""")
s = s.replace("""(if m == .exp && i == 1 then 3 else 0)""", """(if m == .exp && i == 0 then 50 else 0)""")
s = s.replace("""      + (if m == .act && g == 0 && w == 2048 then 5 else 0)""", """      + (if m == .act && g == 0 then 1000 else 0)""")
mut_old = """/-- The changes of the negative control. -/
inductive Mut where
  | none | wq | sq | cnA | input | exp | act | gamma
  deriving BEq, Repr
"""
assert mut_old in s
s = s.replace(mut_old, "")
anchor = """/-- A query-width column `(head, (top bit, index))` as the dense layout's index `h·4 + i` (the RoPE pair is"""
assert anchor in s
s = s.replace(anchor, mut_old + """
/-- The shape with a negative control's change (`sq − 3`, `cn_a · 2`); the dimensions are `mkShape`'s. -/
def mutShape (h24 : Bool) (p : Prec) (m : Mut) : BlockShape :=
  { mkShape h24 p with sq := (if m == .sq then p.q - 3 else p.q), cnA := (if m == .cnA then 400 else 200) }

""" + anchor, 1)
start = s.index("""  let P := mkPub S F silu .none
  let x := mkInput S F .none
  site r s!"{stack} input = trace x" 512""")
end_ = s.index("""  -- the WHOLE approved block (`blockSpecC = blockSpec`, PROVED) and the one-block per-shape run""")
staged = s[start:end_]
s = s[:start] + """  stageSites r F O R silu stack h24 p .none true
  progress t0 s!"{stack}: every stage compared"
  let P := mkPub S F silu .none
  let x := mkInput S F .none
  let fin32 := fun (i : Nat) => (⟨i % 32, Nat.mod_lt _ (by norm_num)⟩ : Fin 32)
  let fin16 := fun (i : Nat) => (⟨i % 16, Nat.mod_lt _ (by norm_num)⟩ : Fin 16)
""" + s[end_:]
staged = staged.replace("""  progress t0 s!"{stack}: every stage compared"
""", "")
staged = staged.replace("""  -- the independent oracle's words
  for (ok, n, f) in""", """  -- the independent oracle's words
  if oracle then
   for (ok, n, f) in""")
staged = staged.replace("""    site r s!"{stack} {ok} = oracle" n fun i => (get O ok).getD i 1 == f i""",
                        """     site r s!"{stack} {ok} = oracle" n fun i => (get O ok).getD i 1 == f i""")
staged = staged.replace("  let P := mkPub S F silu .none\n  let x := mkInput S F .none\n",
                        "  let P := mkPub S F silu m\n  let x := mkInput S F m\n")
staged_fn = '''/-- **Every stage of the block, with the twin's pieces, against the Rust witness builder's words** (and the
independent oracle's, when `oracle`), at the fixture's shape and data with the change `m` (`.none`: the positive check;
any other: one run of the negative control, which must fail somewhere). -/
def stageSites (r : IO.Ref Tally) (F O R : Tbl) (silu : Array (Array Int)) (stack : String) (h24 : Bool) (p : Prec)
    (m : Mut) (oracle : Bool) : IO Unit := do
  let g := fun (k : String) => get R s!"{stack}/{k}"
  let S := mutShape h24 p m
''' + staged + "\n"
hdr = """/-! ## The check of one stack -/
"""
assert hdr in s
s = s.replace(hdr, hdr + "\n" + staged_fn)
neg_start = s.index("""  -- the negative control: each single change must change the block's output (or refuse)""")
neg_end = s.index("""/-- **Stage OUT-C on every row""")
s = s[:neg_start] + """  -- the negative control: each single change must make some stage differ from the Rust words (or refuse)
  for m in [Mut.wq, .sq, .cnA, .input, .exp, .act, .gamma] do
    let r' ← IO.mkRef ({} : Tally)
    stageSites r' F O R silu stack h24 p m false
    let bad := (← r'.get).fails
    let caught := bad > 0
    let line := s!"{stack} negative control {repr m}: {if caught then "caught" else "NOT CAUGHT"} ({bad} entries differ)"
    r.modify fun t => { t with lines := t.lines.push line }
    if !caught then r.modify fun t => { t with fails := t.fails + 1 }
    progress t0 s!"{stack}: negative control {repr m} done"

""" + s[neg_end:]
open(p, "w").write(s)
print("edited")
