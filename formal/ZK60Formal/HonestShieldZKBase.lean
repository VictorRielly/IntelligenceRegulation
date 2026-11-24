/-
D63 lane L68c, part 3b (`HonestShieldZKBase.lean`):
1. **Conservative Shieldstral T128 R13 ZK budget with Sol's `23:41:55Z` framing/audit reserve (`T = 2^20`)**:
   `shdRunErrRes` (`T = 2^20`, `L = 5,359,616`, `N = 5,359,504`, `pts = 11,767,696`), **`shdRunErrRes_cap_86`**,
   and **`shdRunErrRes_hzk`** (numeric dominance proof `shdRunErrRes q R ≤ εzkTarget q R` for all `R ≤ 2^86`,
   22 bits above `ProductionReadyL`'s `2^64` cap, superseding `RunShieldOpenShell.shdRunErr`).
2. **Stage IN-C & Stage OUT-C slot hand-off lemmas (`inc_hhosted`, `outc_hhosted`)**:
   exact stage analogues of `ZKHonestView.w16_hhosted` plugging straight into `ZKHonestView.honest_block_view_law_eq`.
3. **2-level coupled-boundary view-law combinator (`twoLevel_law_eq`)**:
   reusable PMF composition lemma for Stage IN-C + 26 Blocks + Stage OUT-C where Level 1 draws all 84 PCS opening
   views independently (including `EpxSalt` and all 27 boundaries `B_0..B_26`), and Level 2 draws all 28 segments'
   slot + `M` views conditionally given Level 1's joint opening view `X₁` (resolving cross-segment boundary coupling!).

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.RunShieldOpenShell
import ZK60Formal.ZKHonestView
import ZK60Formal.ZKLinksRun

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKCount ZK60.ZKHybrid ZK60.ZKLinks ZK60.ZKHonest
open ZK60.Exec.Slot.W16R2 (Kind)

/-! ## 1. Conservative Shieldstral T128 R13 ZK budget with `T = 2^20` reserve (Sol `23:41:55Z`) -/

section ShdRunReserve

private theorem nat_mul_inv_pow_le' {n a k : ℕ} (hn : n ≤ 2 ^ a) (hk : a ≤ k) :
    (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k ≤ (2⁻¹ : ℝ≥0∞) ^ (k - a) := by
  have he : k = a + (k - a) := by omega
  calc (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k
      ≤ ((2 ^ a : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by
        rw [← he]; exact mul_le_mul_left (Nat.cast_le.mpr hn) _
    _ = (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by norm_cast
    _ = (2⁻¹ : ℝ≥0∞) ^ (k - a) := two_pow_mul_inv_pow a (k - a)

/-- Per-query before-request rate with Sol's `T = 2^20` reserve (`T = 1,048,576`, `L = 5,359,616`, `N = 5,359,504`). -/
noncomputable def shdRunRes_δp : ℝ≥0∞ :=
  ((1048576 + 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- Per-query after-request rate (`2 * (L * 2^-256 + shdRunRes_δp)`). -/
noncomputable def shdRunRes_δh : ℝ≥0∞ :=
  2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRunRes_δp)

/-- Per-receipt prover-query weight before request (`T^2 + L^2` at `2^-256` + `N^2` at `2^-512`). -/
noncomputable def shdRunRes_ωp : ℝ≥0∞ :=
  ((1048576 * 1048576 + 5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
    + ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- Per-receipt prover-query weight after request (`2 * (L^2 * 2^-256 + shdRunRes_ωp)`). -/
noncomputable def shdRunRes_ωh : ℝ≥0∞ :=
  2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRunRes_ωp)

/-- Point-collision / dep-hit rate (`pts = T + L + N = 1,048,576 + 5,359,616 + 5,359,504 = 11,767,696`). -/
noncomputable def shdRunRes_εc : ℝ≥0∞ :=
  ((11767696 * 11767696 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- Conservative Shieldstral T128 R13 refusing-prover ZK error function (`T = 2^20` reserve). -/
noncomputable def shdRunErrRes (q R : ℕ) : ℝ≥0∞ :=
  ∑ j ∈ range R, wStep shdRunRes_δp shdRunRes_ωp shdRunRes_δh shdRunRes_ωh shdRunRes_εc q R j

private theorem shdRunRes_δp_le : shdRunRes_δp ≤ (2⁻¹ : ℝ≥0∞) ^ 233 := by
  have h1 : ((1048576 + 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
      ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
    mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
  have h2 : (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    calc (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
        ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 23) := nat_mul_inv_pow_le' (a := 23) (by norm_num) (by norm_num)
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
      _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
  calc shdRunRes_δp
      ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
    _ = (((2 ^ 23 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 23) := nat_mul_inv_pow_le' (a := 23) (by norm_num) (by norm_num)

private theorem shdRunRes_ωp_le : shdRunRes_ωp ≤ (2⁻¹ : ℝ≥0∞) ^ 211 := by
  have h1 : ((1048576 * 1048576 + 5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
      ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
    mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
  have h2 : ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    calc ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
        ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 46) := nat_mul_inv_pow_le' (a := 46) (by norm_num) (by norm_num)
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
      _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
  calc shdRunRes_ωp
      ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
    _ = (((2 ^ 45 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 45) := nat_mul_inv_pow_le' (a := 45) (by norm_num) (by norm_num)

/-- **Conservative Shieldstral T128 R13 ZK budget (`T = 2^20` reserve) meets `εzkTarget` up to `R ≤ 2^86`**
(22 bits above `ProductionReadyL`'s `2^64` cap). -/
theorem shdRunErrRes_cap_86 (q R : ℕ) (hR : R ≤ 2 ^ 86) : shdRunErrRes q R ≤ εzkTarget q R := by
  have hL : (5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 233 :=
    nat_mul_inv_pow_le' (a := 23) (by norm_num) (by norm_num)
  have hL2 : ((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 211 :=
    nat_mul_inv_pow_le' (a := 45) (by norm_num) (by norm_num)
  have hδsum : shdRunRes_δp + shdRunRes_δh ≤ (2⁻¹ : ℝ≥0∞) ^ 230 := by
    have heq : shdRunRes_δp + shdRunRes_δh = 3 * shdRunRes_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256) := by
      unfold shdRunRes_δh; ring
    rw [heq]
    calc 3 * shdRunRes_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256)
        ≤ 3 * (2⁻¹ : ℝ≥0∞) ^ 233 + 2 * (2⁻¹ : ℝ≥0∞) ^ 233 :=
          add_le_add (mul_le_mul_right shdRunRes_δp_le _) (mul_le_mul_right hL _)
      _ = 5 * (2⁻¹ : ℝ≥0∞) ^ 233 := by ring
      _ ≤ (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + 230) := by
          have h58 : (5 : ℝ≥0∞) ≤ (2 : ℝ≥0∞) ^ 3 := by norm_num
          simpa using mul_le_mul_left h58 ((2⁻¹ : ℝ≥0∞) ^ 233)
      _ = (2⁻¹ : ℝ≥0∞) ^ 230 := two_pow_mul_inv_pow 3 230
  have hωsum : shdRunRes_ωp + shdRunRes_ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 208 := by
    have heq : shdRunRes_ωp + shdRunRes_ωh
        = 3 * shdRunRes_ωp + 2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256) := by
      unfold shdRunRes_ωh; ring
    rw [heq]
    calc 3 * shdRunRes_ωp + 2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256)
        ≤ 3 * (2⁻¹ : ℝ≥0∞) ^ 211 + 2 * (2⁻¹ : ℝ≥0∞) ^ 211 :=
          add_le_add (mul_le_mul_right shdRunRes_ωp_le _) (mul_le_mul_right hL2 _)
      _ = 5 * (2⁻¹ : ℝ≥0∞) ^ 211 := by ring
      _ ≤ (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + 208) := by
          have h58 : (5 : ℝ≥0∞) ≤ (2 : ℝ≥0∞) ^ 3 := by norm_num
          simpa using mul_le_mul_left h58 ((2⁻¹ : ℝ≥0∞) ^ 211)
      _ = (2⁻¹ : ℝ≥0∞) ^ 208 := two_pow_mul_inv_pow 3 208
  have hε : shdRunRes_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 209 :=
    nat_mul_inv_pow_le' (a := 47) (by norm_num) (by norm_num)
  refine wBudget_le q R 86 hR _ _ _ _ _ ?_ ?_
  · calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRunRes_δp + shdRunRes_δh)
        ≤ 2 ^ 87 * (2⁻¹ : ℝ≥0∞) ^ (87 + 143) := by simpa using mul_le_mul_right hδsum ((2 : ℝ≥0∞) ^ 87)
      _ = (2⁻¹ : ℝ≥0∞) ^ 143 := two_pow_mul_inv_pow 87 143
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := inv_pow_le_inv_pow (by norm_num)
  · have h1 : (2 : ℝ≥0∞) ^ (86 + 1) * (shdRunRes_ωp + shdRunRes_ωh) ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRunRes_ωp + shdRunRes_ωh)
          ≤ 2 ^ 87 * (2⁻¹ : ℝ≥0∞) ^ (87 + 121) := by simpa using mul_le_mul_right hωsum ((2 : ℝ≥0∞) ^ 87)
        _ = (2⁻¹ : ℝ≥0∞) ^ 121 := two_pow_mul_inv_pow 87 121
    have h2 : 4 * shdRunRes_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc 4 * shdRunRes_εc
          ≤ (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 207) := by
            simpa [show (4 : ℝ≥0∞) = (2 : ℝ≥0∞) ^ 2 by norm_num] using mul_le_mul_right hε (4 : ℝ≥0∞)
        _ = (2⁻¹ : ℝ≥0∞) ^ 207 := two_pow_mul_inv_pow 2 207
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 := inv_pow_le_inv_pow (by norm_num)
    calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRunRes_ωp + shdRunRes_ωh) + 4 * shdRunRes_εc
        ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 := add_le_add h1 h2
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120

/-- Numeric `hzk` discharge for `shdRunErrRes` at `ProductionReadyL`'s `q, R' ≤ 2^64` range. -/
theorem shdRunErrRes_hzk (q R' : ℕ) (_hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) :
    shdRunErrRes q R' ≤ εzkTarget q R' :=
  shdRunErrRes_cap_86 q R' (le_trans hR' (by norm_num))

end ShdRunReserve

/-! ## 2. Stage IN-C & Stage OUT-C slot hand-off lemmas (`inc_hhosted`, `outc_hhosted`) -/

section StageHandoffs

/-- Stage IN-C slot kinds (`4` standalone slots). -/
def incKind : Fin 4 → Kind := fun _ => .standalone

/-- Stage IN-C host lists (empty: no hosted slots). -/
def incHosts {K : Type} : Fin 4 → List (Fin 4 × K) := fun _ => []

/-- Stage IN-C hand-off (`hhosted` for `honest_block_view_law_eq`, vacuously true). -/
theorem inc_hhosted {K : Type} :
    ∀ s : Fin 4, incKind s = .host → ∀ p ∈ incHosts (K := K) s, maskedOfKind (incKind p.1) = true := by
  intro s hs; cases hs

/-- Stage OUT-C slot kinds (`8` slots: `.priv` at `{1, 3}`, `.host` at `{2, 4}`, `.standalone` at `{0, 5, 6, 7}`). -/
def outcKind : Fin 8 → Kind
  | ⟨1, _⟩ | ⟨3, _⟩ => .priv
  | ⟨2, _⟩ | ⟨4, _⟩ => .host
  | _ => .standalone

/-- Stage OUT-C host lists (`2 ↦ [(1, ν₂)]`, `4 ↦ [(3, ν₄)]`). -/
def outcHosts {K : Type} (ν₂ ν₄ : K) : Fin 8 → List (Fin 8 × K)
  | ⟨2, _⟩ => [(⟨1, by norm_num⟩, ν₂)]
  | ⟨4, _⟩ => [(⟨3, by norm_num⟩, ν₄)]
  | _ => []

/-- Stage OUT-C hand-off (`hhosted` for `honest_block_view_law_eq`): every hosted slot is `.priv`, hence masked. -/
theorem outc_hhosted {K : Type} (ν₂ ν₄ : K) :
    ∀ s : Fin 8, outcKind s = .host → ∀ p ∈ outcHosts ν₂ ν₄ s, maskedOfKind (outcKind p.1) = true := by
  intro s hs p hp
  fin_cases s <;> simp only [outcKind, outcHosts, List.mem_singleton, List.not_mem_nil] at hs hp
  · subst hp; rfl
  · subst hp; rfl

end StageHandoffs

/-! ## 3. Two-level coupled-boundary view-law combinator (`twoLevel_law_eq`) -/

section TwoLevelLaw

/-- **Two-level view-law composition for coupled cross-segment boundaries**:
- Level 1 (`Ω₁`, e.g. all 84 PCS openings `EpxSalt`, `B_0..26`, `A_0..27`, `H_0..27`): the joint opening view
  `X₁ e ω₁` has the same distribution for `e` and `e'`.
- Level 2 (`Ω₂`, e.g. all 28 segments' slot + `M` coins): for EVERY fixed Level-1 opening view `x₁`, the
  conditional Level-2 view `X₂ e x₁ ω₂` has the same distribution for `e` and `e'`.
Then the joint pair `(X₁ e ω₁, X₂ e (X₁ e ω₁) ω₂)` has the same distribution for `e` and `e'`! -/
theorem twoLevel_law_eq {E Ω₁ Ω₂ V₁ V₂ : Type} [Fintype Ω₁] [Nonempty Ω₁] [Fintype Ω₂] [Nonempty Ω₂]
    (X₁ : E → Ω₁ → V₁) (X₂ : E → V₁ → Ω₂ → V₂) (e e' : E)
    (h1 : (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ e'))
    (h2 : ∀ x₁ : V₁, (PMF.uniformOfFintype Ω₂).map (X₂ e x₁) = (PMF.uniformOfFintype Ω₂).map (X₂ e' x₁)) :
    (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ e p.1, X₂ e (X₁ e p.1) p.2))
      = (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ e' p.1, X₂ e' (X₁ e' p.1) p.2)) := by
  have hL : ∀ d : E,
      (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ d p.1, X₂ d (X₁ d p.1) p.2))
        = ((PMF.uniformOfFintype Ω₁).map (X₁ d)).bind (fun x₁ =>
            ((PMF.uniformOfFintype Ω₂).map (X₂ d x₁)).map (fun x₂ => (x₁, x₂))) := by
    intro d
    rw [ZK60.Hiding.map_pair_eq_bind (X₁ d) (fun x₁ ω₂ => (x₁, X₂ d x₁ ω₂))]
    congr 1; funext x₁
    rw [PMF.map_comp]; rfl
  rw [hL e, hL e', h1]
  congr 1; funext x₁
  rw [h2 x₁]

end TwoLevelLaw

end ZK60.HonestShield
