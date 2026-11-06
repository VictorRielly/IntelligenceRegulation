/-
D63, step L2, the LogUp helper layout, and the slack it shows (optimization candidate C1 of the findings document).

A domain's helper planes are `⌈n/2⌉` pair-or-single helpers for its `n` range lookups (`shape::helpers`,
shape.rs:2563-2565, `argument::helper_sum`, argument.rs:1749-1765) PLUS one single helper for each functional-table
query on it: the exp tuple on `Dom::S` and the ACT tuple on `Dom::F` (shape.rs:2573-2578, `ihx` and `fact` at
argument_accuracy.rs:631 and :528). At W16R2 8B both domains have an ODD number of range lookups (7 each,
census.log "lookups per position"), so each carries a half-used single helper beside the functional single helper:
five planes where four would do.

What the proofs use of a helper is only `pair_helper_iff`: off the poles, a pair relation forces the helper to be
`1/(α − a) + 1/(α − b)` WHATEVER tables `a` and `b` are looked up in (both are folded tuples, `fold β γ`, each linear
in the committed planes, so the relation keeps degree 3). And L3's `logup_block_bound` (SoundLogUpBlock.lean) holds
for ANY split of the lookups into singles `ι` and pairs `π`: its bound depends on the split only through
`N = |ι| + 2|π|` (`helper_split_count`). Pairing the functional query with the half-used range single therefore
leaves `N`, the soundness bound and every lookup unchanged, and removes one helper plane on `Dom::F` (128 rows of
`Fp2`) and one on `Dom::S` (32 rows): `w16r2_helper_planes`.
-/
import ZK60Formal.SoundLogUpBlock

namespace ZK60.Circuit

/-- A pair relation forces its helper, for any two looked-up values (from any tables). -/
theorem pair_helper_iff {F : Type} [Field F] {α a b h : F} (ha : α ≠ a) (hb : α ≠ b) :
    h * ((α - a) * (α - b)) = (α - a) + (α - b) ↔ h = (α - a)⁻¹ + (α - b)⁻¹ := by
  have ha' : α - a ≠ 0 := sub_ne_zero.mpr ha
  have hb' : α - b ≠ 0 := sub_ne_zero.mpr hb
  constructor
  · intro h1
    field_simp
    linear_combination h1
  · rintro rfl
    field_simp
    ring

/-- The number of lookups of a split into `ι` singles and `π` pairs, the only way the split enters
`logup_block_bound`. -/
theorem helper_split_count (ι π : Type) [Fintype ι] [Fintype π] :
    Fintype.card (ι ⊕ (π ⊕ π)) = Fintype.card ι + 2 * Fintype.card π := by
  rw [Fintype.card_sum, Fintype.card_sum]; ring

/-- Helper planes of a domain: today's layout (range lookups paired, functional queries single) and the paired
layout (functional queries join the pairs). -/
def planesToday (nRange nFunc : ℕ) : ℕ := (nRange + 1) / 2 + nFunc
def planesPaired (nRange nFunc : ℕ) : ℕ := (nRange + nFunc + 1) / 2

/-- W16R2 8B T128: `Dom::F` (7 range lookups, the ACT query) and `Dom::S` (7, the exp query) each lose one plane;
`Dom::D` (19, none) and `Dom::Q`, `Dom::Kv` (6, none) do not change. -/
theorem w16r2_helper_planes :
    planesToday 7 1 = 5 ∧ planesPaired 7 1 = 4 ∧ planesToday 19 0 = planesPaired 19 0 ∧
      planesToday 6 0 = planesPaired 6 0 := by
  decide

end ZK60.Circuit
