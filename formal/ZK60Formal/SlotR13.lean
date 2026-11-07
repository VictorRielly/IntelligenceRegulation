/-
D63 Lean lane L17 (2026-11-07): **the R13 slot list**, beside L11's W16R2 one (`SlotW16R2.lean`).

R13 and W16R2 run the SAME 23 slots in the same transcript order, with the same kinds, hosts, cubes, extension rounds
and degree table (`SLOT_KINDS`, `HOSTS`, `Shape::slots`, `BASE_DEGREE`, `INDICATOR_SLOT_DOMAIN`: shape.rs:619-627,
2660-2714; no R13/W16 branch). So L11's `sched`, `kindOf`, `hostsOf`, `claimPoint`, `eqPoints`, `hostedCoefs`,
`slotVerifyW` and the per-slot soundness lemmas of `SlotW16Sound.lean` are R13's as stated. What differs is the
batching vectors the six R13 zero-checks draw (argument_accuracy.rs:48-444 against its `*_w16` arms): R13 keeps the
word decompositions W16 drops, so
* `SC_DZC`: `μ` has `13 + helpers(D) + pad` entries (W16: `6 + …`: the seven word clauses);
* `SC_QZC`, `SC_KVZC`: `4 + helpers + pad` (W16: `1 + …`: the three word clauses);
* `SC_SZC`: `5 + helpers(S) + 1 + pad` (W16: `4 + …`: the quotient `c4 = p − Σ PL`);
* `SC_FZC`: `4 + helpers(F) + pad` (W16: `2 + …`: `U`'s and the product word's decompositions);
* `SC_TAB`: `3 + pad` (W16: `3 + n_range + pad`: no range sub-planes);
and the helper counts (inside `μ`) follow R13's byte-lookup list (two lookups per helper). Every other slot's draws are
the shared `argument.rs` code (`W16R2.draws`).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `draws_other`: outside the six slots, R13's draws ARE W16R2's;
* `slotNum_eq`, **`blockNum_eq_w16r2`**: a batching vector's length does not enter L3's small numerators (a batch costs
  `1`), so the R13 block's numerator sum is W16R2's at the same shape facts, for every pad charge;
* `shShieldR13`, `blockFix_shieldR13`, **`r13_shield_numerator_le`**: at the registered Shieldstral T128 R13 shape (its
  facts recorded by the shape corpus and checked by `CheckR13Slots`) F44's premise holds: at most `2^16`.
-/
import ZK60Formal.SlotW16R2

namespace ZK60.Exec.Slot.R13

open ZK60.Exec.Slot.W16R2 (ShapeW Seg padOn scDZC scQZC scKVZC scSZC scFZC scTAB sched segNum segFix zetaLen
  claimLen nSlots)

/-- **The draws of R13 slot `s`'s `define`, in order** (`p` the slot's `pad_on`). -/
def draws (sh : ShapeW) (s : ℕ) : List (Seg × ℕ) :=
  let p : ℕ := if padOn sh s then 1 else 0
  if s = scDZC then [(.mu, 13 + sh.helpers .D + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .D)]
  else if s = scQZC then [(.mu, 4 + sh.helpers .Q + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .Q)]
  else if s = scKVZC then [(.mu, 4 + sh.helpers .Kv + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .Kv)]
  else if s = scSZC then [(.tau, sh.logs .S), (.mu, 5 + sh.helpers .S + 1 + p), (.nu, 2), (.zeta, p)]
  else if s = scFZC then [(.mu, 4 + sh.helpers .F + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .F)]
  else if s = scTAB then [(.tau, sh.logs .Tab), (.mu, 3 + p), (.zeta, p)]
  else W16R2.draws sh s

/-- How many squeezes R13 slot `s`'s `define` makes. -/
def drawLen (sh : ShapeW) (s : ℕ) : ℕ := ((draws sh s).map Prod.snd).sum

/-- **Outside the six R13 zero-checks, R13's draws are W16R2's** (the shared `argument.rs` code). -/
theorem draws_other (sh : ShapeW) (s : ℕ) (h1 : s ≠ scDZC) (h2 : s ≠ scQZC) (h3 : s ≠ scKVZC) (h4 : s ≠ scSZC)
    (h5 : s ≠ scFZC) (h6 : s ≠ scTAB) : draws sh s = W16R2.draws sh s := by
  simp only [draws, h1, h2, h3, h4, h5, h6, ↓reduceIte]

/-- R13's slot numerator (L11's `slotNum` with R13's draws). -/
def slotNum (sh : ShapeW) (pp : ℕ) (s : ℕ) : ℕ :=
  let sc := sched sh s
  (sc.1 + sc.2.1) * sc.2.2 + ((draws sh s).map (segNum pp)).sum + claimLen sh s

def blockNum (sh : ShapeW) (pp : ℕ) : ℕ := ((List.range nSlots).map (slotNum sh pp)).sum

/-- **A batching vector's length is not a numerator**: each slot's R13 draws cost what its W16R2 draws cost. -/
theorem draws_num (sh : ShapeW) (pp s : ℕ) :
    ((draws sh s).map (segNum pp)).sum = ((W16R2.draws sh s).map (segNum pp)).sum := by
  by_cases h1 : s = scDZC
  · subst h1
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  by_cases h2 : s = scQZC
  · subst h2
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  by_cases h3 : s = scKVZC
  · subst h3
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  by_cases h4 : s = scSZC
  · subst h4
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  by_cases h5 : s = scFZC
  · subst h5
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  by_cases h6 : s = scTAB
  · subst h6
    simp [draws, W16R2.draws, segNum, segFix, zetaLen]
  rw [draws_other sh s h1 h2 h3 h4 h5 h6]

/-- Each slot's R13 numerator is its W16R2 numerator. -/
theorem slotNum_eq (sh : ShapeW) (pp s : ℕ) : slotNum sh pp s = W16R2.slotNum sh pp s := by
  simp only [slotNum, W16R2.slotNum, draws_num]

/-- **The R13 block's numerator sum is W16R2's** at the same shape facts. -/
theorem blockNum_eq_w16r2 (sh : ShapeW) (pp : ℕ) : blockNum sh pp = W16R2.blockNum sh pp := by
  unfold blockNum W16R2.blockNum
  exact congrArg List.sum (List.map_congr_left fun s _ => slotNum_eq sh pp s)


/-! ## The R13 shapes' facts -/

/-- **The registered Shieldstral T128 R13 shape** (`hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2`;
the shape corpus's `SHAPE` line): the W16R2 Shieldstral twin's axis and domain logs and pads (`shShield`), R13's helper
counts (two byte lookups per helper: `D` 34, `Q` 14, `Kv` 14, `S` 15, `F` 14 lookups per position) and no range
sub-plane. -/
def shShieldR13 : ShapeW where
  lt := 7
  lh := 5
  ldh := 7
  ld := 12
  lf := 14
  lq := 12
  lkvw := 10
  lkv := 3
  padRule := true
  nRange := 0
  perRow := 128
  logs d := match d with
    | .T => 7 | .Ht => 12 | .L => 14 | .D => 19 | .Q => 19 | .Kv => 17 | .S => 19 | .F => 21 | .Tab => 14
  pads d := match d with
    | .L | .D | .F | .Tab => true
    | _ => false
  helpers d := match d with
    | .L => 1 | .D => 17 | .Q => 7 | .Kv => 7 | .S => 8 | .F => 7
    | _ => 0
  zeroRule d := match d with
    | .L | .D | .F | .Tab => true
    | _ => false

/-- **The R13 development rung's shape facts** (`hashline-zk-mr1/private-block-rung-lh-t32-dev/2`; the slots corpus's
`SHAPE` line, which `CheckR13Slots` parses). -/
def shRungR13 : ShapeW where
  lt := 5
  lh := 4
  ldh := 6
  ld := 9
  lf := 10
  lq := 10
  lkvw := 9
  lkv := 3
  padRule := true
  nRange := 0
  perRow := 32
  logs d := match d with
    | .T => 5 | .Ht => 9 | .L => 14 | .D => 14 | .Q => 15 | .Kv => 14 | .S => 14 | .F => 15 | .Tab => 14
  pads d := match d with
    | .L | .D | .F | .Tab => true
    | _ => false
  helpers d := match d with
    | .L => 1 | .D => 17 | .Q => 7 | .Kv => 7 | .S => 9 | .F => 7
    | _ => 0
  zeroRule d := match d with
    | .L | .D | .F | .Tab => true
    | _ => false

/-- The rung's draws by the formula are the ones the export counted on the code's transcript (`ExecBlockR13.lean`'s
`R13.rungDrawList`). -/
theorem rungDraws_eq : (List.range nSlots).map (drawLen shRungR13)
    = [5, 5, 13, 16, 10, 15, 9, 9, 14, 15, 14, 15, 10, 14, 48, 28, 27, 31, 30, 19, 0, 14, 14] := by
  decide

/-- The Shieldstral block's draws by the formula (`ExecBlockR13.lean`'s `R13.shieldDrawList`). -/
theorem shieldDraws_eq : (List.range nSlots).map (drawLen shShieldR13)
    = [7, 7, 15, 16, 13, 19, 10, 10, 19, 19, 19, 21, 14, 19, 53, 32, 30, 35, 36, 19, 0, 19, 19] := by
  decide

/-- The Shieldstral block's schedule by `Shape::slots`' formula (`ExecBlockR13.lean`'s `R13.shieldSlots`). -/
theorem shieldSched_eq : (List.range nSlots).map (sched shShieldR13)
    = [(19, 1, 4), (19, 1, 4), (7, 1, 3), (14, 1, 4), (19, 1, 3), (12, 1, 2), (12, 1, 2), (12, 1, 2), (10, 2, 3),
      (10, 2, 3), (12, 1, 2), (12, 1, 2), (12, 1, 2), (14, 1, 2), (19, 1, 5), (19, 1, 4), (17, 1, 4), (19, 1, 4),
      (21, 1, 5), (14, 1, 3), (14, 1, 2), (19, 1, 2), (19, 1, 2)] := by
  decide

theorem blockFix_shieldR13 : W16R2.blockFix shShieldR13 = 1539 := by decide

theorem zetaTotal_shieldR13 : W16R2.zetaTotal shShieldR13 = 4 := by decide

/-- **F44 at the Shieldstral T128 R13 shape**: for every pad charge `pp ≤ 64`, the 23 slots' small numerators sum to
`1,539 + 4·pp ≤ 2^16` (`BlockZone8B`'s premise), as at its W16R2 twin. -/
theorem r13_shield_numerator_le (pp : ℕ) (hpp : pp ≤ 64) : blockNum shShieldR13 pp ≤ 2 ^ 16 := by
  rw [blockNum_eq_w16r2, W16R2.blockNum_eq, blockFix_shieldR13, zetaTotal_shieldR13]
  omega

end ZK60.Exec.Slot.R13
