/-
D63, Lean lane L12 (2026-11-07): **stage OUT-C, the L3 part** (ASSEMBLY §4.2 item e, L1L2 findings §16): from the stage
verifier's accepted checks to `OutCSat` (CircuitOut.lean), the classifier's final norm, margin and verdict.

The code (stage_out_c.rs:283-429): after `A_out` and `M` the challenges `γ, α` are drawn (`g_u8 = γ·TAG_U8`), then
`H_out`, then the slots
* OUTC-00 IO-in: `x = B_out` at the public verdict row (a zero-check over `d_pad`);
* OUTC-01 SS (private, `Σ_{i<d} x_i²`) hosted by OUTC-02 TZC (`dsq = D²`, `D = l3(limbs)`, `2D = a1 + a2`, a pad,
  and the host term `u0·(dsq + a1 − ceps)`);
* OUTC-03 PD (private, the MARGIN `Σ_{i<d} y_i·w_Δ(i)`) hosted by OUTC-04 LZC (the limb plane's byte lookups, its pad,
  and the host term `σ·g(z)·limb(z) + u0(z)·(b + c)`, `g(z) = 256^(z − 32)` on the margin limbs);
* OUTC-05 DZC (the norm's division clauses `c0`, `c1`, the input limbs `c2`, six pair helpers, the pad), OUTC-06 TAB
  (the byte table's helper and pad), OUTC-07 ZS (the zero-sum row), and the `H` opening's value-0 LogUp sum.

What is proved:
* **`byte_logup_sound`**: for looked values fixed before `γ, α` (all in `A_out`), over uniform `(γ, α)`, the
  probability that SOME helpers pass every relation of the byte LogUp (singles `h·(α − a − g) = 1`, pairs
  `h·(α − a − g)(α − b − g) = (α − a − g) + (α − b − g)`, the table `h_j·(α − j − g) = m_j`, the sum claim) while some
  looked value is not a byte is at most `(N + 2·256 − 1)/|K|`, `N` the lookups. The family tag is the same for every
  lookup and every table entry, so `γ` only shifts `α` (`logup_helpers_bound` at every `γ`);
* **`outC_sat_of_clauses`**: the stage's clauses at the logical positions (TZC's three and its hosted sum, LZC's
  hosted margin, DZC's three per channel) with the byte facts give `OutCSat` — the final norm `FNormRel` and the
  verdict identity `VerdictRel` on `Σ_i y_i·w_Δ(i)`;
* `lzc_host_sum`: LZC's host term summed over the whole limb plane is `σ·δ + (b + c)`, `δ = Σ_k 256^k·limb(32 + k)`;
* `isByte_inRange`: a table byte is `InRange 8`.

Modelling boundary: the clauses are the zero-check and host slots' conclusions (`zc_pad_sound`, `host_sound`,
`StageExtractCore.lean`), the private slots' sums their sumchecks' (`sumcheck_sound`), the sum claim the `H` opening's
(lane L10), and the IO-in identity is the boundary link (`StageRunExtract.lean`).
-/
import ZK60Formal.StageExtractCore
import ZK60Formal.CircuitOut

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## The byte LogUp -/

section Bytes

variable {B K : Type} [Field B] [Field K]
variable {ι π : Type}

/-- A table byte: `x = j` for some `j < 256`. -/
def IsByte (x : B) : Prop := ∃ j : Fin 256, x = ((j : ℕ) : B)

/-- The byte lookups as the code makes them: singles `a i` (LZC's limb plane), pairs `(p1 k, p2 k)` (DZC's six pair
helpers, lookups `2k, 2k + 1`), each shifted by the family tag `g = γ·TAG_U8` (`resolve`, stage_out_c.rs:273-275). -/
def byteLook (φ : B →+* K) (a : ι → B) (p1 p2 : π → B) (g : K) : ι ⊕ (π ⊕ π) → K
  | .inl i => φ (a i) + g
  | .inr (.inl k) => φ (p1 k) + g
  | .inr (.inr k) => φ (p2 k) + g

/-- The byte table `tv(j) = j + g` on the 256 live rows (SOC_TAB, stage_out_c.rs:412). -/
def byteTab (g : K) : Fin 256 → K := fun j => ((j : ℕ) : K) + g

/-- Every looked value is a byte. -/
def AllBytes (a : ι → B) (p1 p2 : π → B) : Prop :=
  (∀ i, IsByte (a i)) ∧ ∀ k, IsByte (p1 k) ∧ IsByte (p2 k)

/-- The shifted lookup of `x` hits the table only at a byte. -/
theorem byteLook_hit (φ : B →+* K) {x : B} {g : K} {j : Fin 256} (h : byteTab g j = φ x + g) :
    x = ((j : ℕ) : B) := by
  unfold byteTab at h
  have h' : φ (((j : ℕ) : B)) = φ x := by
    rw [map_natCast]
    exact add_right_cancel h
  exact (φ.injective h').symm

/-- The byte LogUp's relations at `ω = (γ, α)`, for helpers `H` chosen after them. -/
def ByteLogUp [Fintype ι] [Fintype π] [DecidableEq K] (φ : B →+* K) (a : ι → B) (p1 p2 : π → B)
    (mult : Fin 256 → K) (g : K → K) (ω : K × K) (H : Helpers ι π (Fin 256) K) : Prop :=
  HelperRel (byteLook φ a p1 p2 (g ω.1)) (byteTab (g ω.1)) mult ω.2 H

/-- **The byte LogUp, sound.** For looked values fixed before `γ, α`, fewer lookups than the characteristic and any
family-tag map `g`: over uniform `(γ, α)`, SOME helpers pass every relation while a looked value is not a byte with
probability at most `(N + 2·256 − 1)/|K|`, `N = |ι| + 2|π|` the lookups. -/
theorem byte_logup_sound [Fintype K] [DecidableEq K] [Fintype ι] [Fintype π] (φ : B →+* K) (a : ι → B) (p1 p2 : π → B) (mult : Fin 256 → K) (g : K → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) :
    pr (fun ω : K × K => (∃ H, ByteLogUp φ a p1 p2 mult g ω H) ∧ ¬ AllBytes a p1 p2)
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * 256 - 1 : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  refine pr_prod_le _ (fun γ => ?_)
  by_cases hall : AllBytes a p1 p2
  · exact pr_le_of_not _ (fun α hα => hα.2 hall) _
  · -- some looked value is not a byte: the identity fails, and LogUp's challenge bound applies
    have hnot : ∃ l : ι ⊕ (π ⊕ π), ∀ j, byteTab (g γ) j ≠ byteLook φ a p1 p2 (g γ) l := by
      unfold AllBytes at hall
      push Not at hall
      by_cases ha : ∀ i, IsByte (a i)
      · obtain ⟨k, hk⟩ := hall ha
        by_cases h1 : IsByte (p1 k)
        · refine ⟨.inr (.inr k), fun j hj => hk h1 ⟨j, byteLook_hit φ hj⟩⟩
        · exact ⟨.inr (.inl k), fun j hj => h1 ⟨j, byteLook_hit φ hj⟩⟩
      · push Not at ha
        obtain ⟨i, hi⟩ := ha
        exact ⟨.inl i, fun j hj => hi ⟨j, byteLook_hit φ hj⟩⟩
    obtain ⟨l, hl⟩ := hnot
    have hcard : Fintype.card (ι ⊕ (π ⊕ π)) < ringChar K := by
      rw [Fintype.card_sum, Fintype.card_sum]
      omega
    have hne := logup_ne_of_not_mem (byteLook φ a p1 p2 (g γ)) (byteTab (g γ)) mult hcard (i := l) hl
    refine (pr_mono (E' := fun α => ∃ H, HelperRel (byteLook φ a p1 p2 (g γ)) (byteTab (g γ)) mult α H)
      (fun α hα => hα.1)).trans ((logup_helpers_bound _ _ _ hne).trans (ENNReal.div_le_div_right ?_ _))
    have him : (univ.image (byteTab (g γ))).card ≤ 256 := card_image_le.trans (by simp)
    exact_mod_cast (show Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image (byteTab (g γ))).card - 1
      ≤ Fintype.card ι + 2 * Fintype.card π + 2 * 256 - 1 by omega)

/-- **The byte LogUp, both phases** (stage OUT and OUT-C): the helpers `h ω` chosen after `(γ, α)`, then the slots'
challenges `ω₂`. If the slots (LZC, DZC, VZC, TAB, ZS and the `H` sum claim) accept helpers that fail the byte LogUp's
relations with probability at most `ε₂`, the stage accepts while a looked value is not a byte with probability at most
`(N + 2·256 − 1)/|K| + ε₂`. -/
theorem byte_stage_sound [Fintype K] [DecidableEq K] [Fintype ι] [Fintype π] (φ : B →+* K) (a : ι → B) (p1 p2 : π → B) (mult : Fin 256 → K) (g : K → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) {Ω₂ : Type} [Fintype Ω₂] [Nonempty Ω₂]
    (acc : K × K → Helpers ι π (Fin 256) K → Ω₂ → Prop) (h : K × K → Helpers ι π (Fin 256) K) {ε₂ : ℝ≥0∞}
    (hslots : ∀ ω H, ¬ ByteLogUp φ a p1 p2 mult g ω H → pr (fun b => acc ω H b) ≤ ε₂) :
    pr (fun ω : (K × K) × Ω₂ => acc ω.1 (h ω.1) ω.2 ∧ ¬ AllBytes a p1 p2)
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * 256 - 1 : ℕ) : ℝ≥0∞) / Fintype.card K + ε₂ :=
  two_phase_sound (ByteLogUp φ a p1 p2 mult g) (AllBytes a p1 p2) acc h (byte_logup_sound φ a p1 p2 mult g hN)
    hslots

/-- A table byte of the base field `GF` is `InRange 8`. -/
theorem isByte_inRange {x : ZK60.Circuit.GF} (h : IsByte x) : ZK60.Circuit.InRange 8 x := by
  obtain ⟨j, rfl⟩ := h
  exact ⟨(j : ℕ), by positivity, lt_of_lt_of_le (Nat.cast_lt.mpr j.isLt) (by norm_num),
    (Int.cast_natCast (j : ℕ)).symm⟩

end Bytes

/-! ## The clauses at the logical positions, and `OutCSat` -/

section Clauses

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out

/-- `k` byte limbs recomposed, `Σ_j 2^(8j)·b_j` (`lb` in DZC, the margin limbs' `δ`). -/
def limbSum {k : ℕ} (v : Fin k → GF) : GF := ∑ j : Fin k, (2 : GF) ^ (8 * (j : ℕ)) * v j

/-- The isqrt's three byte limbs recomposed (`l3`, TZC, stage_out_c.rs:328). -/
def l3 (v : Fin 3 → GF) : GF := v 0 + 2 ^ 8 * v 1 + 2 ^ 16 * v 2

/-- **The final norm's clauses at the logical positions** (stage OUT and OUT-C share them: stage_out.rs:366-455,
stage_out_c.rs:312-334, 371-405), for the stage's own `x` (the `x` plane at the live channels `i < d`), with the
norm constants `ceps`, `cn`, `g0`, `tn`:
* TZC (To entry 0): `dsq − D² = 0`, `D − l3(dl) = 0`, `2D − l3(al) − l3(bl) = 0`, and its HOSTED sum
  `dsq + l3(al) − ceps = Σ_{i<d} x_i²` (the private slot SS);
* DZC at every live channel: `c0` (the division), `c1` (the slack), `c2` (the input word's two limbs);
* the byte LogUp's conclusion: the nine isqrt limbs, `xl0`, `xl1`, `y + 127`, `−y + 127`, every `ρ` and `σ` limb. -/
structure FNormClauses {n : ℕ} (ceps cn g0 : ℤ) (tn : ℕ) (x : Fin n → GF) where
  D : GF
  Dsq : GF
  dl : Fin 3 → GF
  al : Fin 3 → GF
  bl : Fin 3 → GF
  xl0 : Fin n → GF
  xl1 : Fin n → GF
  y : Fin n → GF
  rho : Fin n → Fin 4 → GF
  sig : Fin n → Fin 4 → GF
  tzc_sq : Dsq - D * D = 0
  tzc_d : D - l3 dl = 0
  tzc_a : 2 * D - l3 al - l3 bl = 0
  host_ss : Dsq + l3 al - (ceps : GF) = ∑ i, x i * x i
  c0 : ∀ i, x i * ((2 * g0 * cn : ℤ) : GF) + D * 2 ^ tn - D * 2 ^ (tn + 1) * y i - limbSum (rho i) = 0
  c1 : ∀ i, limbSum (sig i) + limbSum (rho i) + 1 - D * 2 ^ (tn + 1) = 0
  c2 : ∀ i, x i + 32768 - xl0 i - 2 ^ 8 * xl1 i = 0
  b_dl : ∀ j, InRange 8 (dl j)
  b_al : ∀ j, InRange 8 (al j)
  b_bl : ∀ j, InRange 8 (bl j)
  b_xl0 : ∀ i, InRange 8 (xl0 i)
  b_xl1 : ∀ i, InRange 8 (xl1 i)
  b_yp : ∀ i, InRange 8 (y i + 127)
  b_ym : ∀ i, InRange 8 (-y i + 127)
  b_rho : ∀ i j, InRange 8 (rho i j)
  b_sig : ∀ i j, InRange 8 (sig i j)

theorem l3_inRange {v : Fin 3 → GF} (h : ∀ j, InRange 8 (v j)) : InRange 24 (l3 v) :=
  (threeBytes_iff (l3 v)).mp ⟨v 0, v 1, v 2, rfl, h 0, h 1, h 2⟩

theorem limbSum_byteLimbs {k : ℕ} {v : Fin k → GF} (h : ∀ j, InRange 8 (v j)) : ByteLimbs k (limbSum v) :=
  ⟨v, rfl, h⟩

/-- **The final norm's clauses give `FNormRel`** (CircuitOut.lean): the isqrt relation on the hosted sum of squares
with its three 24-bit facts, and per channel the input word's limbs, the division with its two four-byte remainders,
and the symmetric int8 word. -/
theorem fnormRel_of_clauses {n : ℕ} {ceps cn g0 : ℤ} {tn : ℕ} {x : Fin n → GF} (C : FNormClauses ceps cn g0 tn x) :
    FNormRel ceps cn g0 tn x C.D C.y := by
  refine ⟨⟨C.Dsq, l3 C.al, l3 C.bl, ⟨?_, ?_, ?_⟩, ?_, l3_inRange C.b_al, l3_inRange C.b_bl⟩,
    fun i => ⟨?_, ⟨limbSum (C.rho i), limbSum (C.sig i), ⟨?_, ?_⟩, limbSum_byteLimbs (C.b_rho i),
      limbSum_byteLimbs (C.b_sig i)⟩, ⟨C.b_yp i, C.b_ym i⟩⟩⟩
  · exact C.tzc_sq
  · exact C.tzc_a
  · linear_combination C.host_ss
  · have hd : C.D = l3 C.dl := sub_eq_zero.mp C.tzc_d
    rw [hd]
    exact l3_inRange C.b_dl
  · -- the input word's two byte limbs (`c2`): a 16-bit fact, i.e. two byte limbs
    have h16 : InRange (8 + 8) (x i + 32768) :=
      (limbs_iff 8 8 _).mp ⟨C.xl0 i, C.xl1 i, by linear_combination C.c2 i, C.b_xl0 i, C.b_xl1 i⟩
    exact (byteLimbs_iff 2 _).mpr h16
  · -- the division clause `c0`
    have h := C.c0 i
    push_cast at h
    linear_combination h
  · -- the slack clause `c1`
    linear_combination C.c1 i

/-- **Stage OUT-C's clauses at the logical positions**, for the stage's own `x` and the published verdict `b`: the
final norm's (`FNormClauses`), and LZC's HOSTED margin (stage_out_c.rs:363-368): `σ·δ + (b + c) = Σ_{i<d} y_i·w_Δ(i)`
(the private slot PD), `δ` the margin limbs recomposed (`lzc_host_sum`), the margin limbs bytes. -/
structure OutCClauses {n : ℕ} (P : OutCPublic n) (b : ℕ) (x : Fin n → GF) extends
    FNormClauses P.ceps P.cn P.g0 P.tn x where
  ml : Fin P.limbs → GF
  host_pd : sigOf b * limbSum ml + ((b : GF) + (P.c : GF)) = ∑ i, y i * (P.wΔ i : GF)
  b_ml : ∀ j, InRange 8 (ml j)

/-- **Stage OUT-C's clauses give `OutCSat`**: the final norm relation on `x` with the isqrt `D` and the words `y`,
and the verdict identity on the margin `Σ_i y_i·w_Δ(i)`. -/
theorem outC_sat_of_clauses {n : ℕ} (P : OutCPublic n) (b : ℕ) (x : Fin n → GF) (C : OutCClauses P b x) :
    OutCSat P x b :=
  ⟨C.D, C.y, fnormRel_of_clauses C.toFNormClauses,
    ⟨limbSum C.ml, limbSum_byteLimbs C.b_ml, by linear_combination -C.host_pd⟩⟩

/-- **LZC's host term over the whole limb plane** (stage_out_c.rs:356-366): with `g(z) = σ·2^(8k)` at the margin limb
entries `mpos k` (`32 + k`), `0` elsewhere, and `u0` the indicator of entry `z0`, the cube sum of
`g(z)·limb(z) + u0(z)·(b + c)` is `σ·δ + (b + c)`, `δ = Σ_k 2^(8k)·limb(32 + k)`. -/
theorem lzc_host_sum {Lo : Type} [Fintype Lo] [DecidableEq Lo] {L : ℕ} (mpos : Fin L → Lo)
    (hm : Function.Injective mpos) (z0 : Lo) (σ kc : GF) (g u0 limb : Lo → GF)
    (hg : ∀ j, g (mpos j) = σ * (2 : GF) ^ (8 * (j : ℕ))) (hg0 : ∀ z, z ∉ Set.range mpos → g z = 0)
    (hu : ∀ z, u0 z = if z = z0 then 1 else 0) :
    ∑ z, (g z * limb z + u0 z * kc) = σ * limbSum (fun j => limb (mpos j)) + kc := by
  rw [Finset.sum_add_distrib]
  have h1 : ∑ z, g z * limb z = ∑ j, g (mpos j) * limb (mpos j) :=
    cube_sum_of_pad mpos hm (fun z => g z * limb z) (fun z hz => by rw [hg0 z hz, zero_mul])
  have h2 : ∑ z, u0 z * kc = kc := by
    simp only [hu, ite_mul, one_mul, zero_mul, Finset.sum_ite_eq', Finset.mem_univ, ite_true]
  rw [h1, h2]
  unfold limbSum
  rw [Finset.mul_sum]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [hg]
  ring

end Clauses

end ZK60.StageX
