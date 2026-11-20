/-
D63 lane L67b (2026-11-17): **concrete stage lookup squeeze predicates (`stgLkIn` / `shd_ΛI`, `stgLkOut` / `shd_ΛO`),
escape bounds (`shdP_eI = 2^19`, `shdP_eO = 2^16`), `shd_hLuStg` (`.Rbr` + arithmetic bounds), and pure-algebra bridge
lemmas (`stgLkIn_of_inLogUp`, `not_stgLkIn_nil_of_not_inGood`, `stgLkOut_nil`, `stgLkOut_two`) for `L63`'s `hLI_stg`,
`hLO_stg`, `hdinS`, and `hdoutS`**.

Protocol subtlety & design:
1. **Stage OUT-C (`m = 2`, `[γ, α]`, `lkStByte`, `shdP_eO = 2^16`):** all looked byte values (`limb`, `dLookB`) and
   multiplicities (`mult`) are committed in `A_out` before round 0 (`γ`), and `γ` shifts lookups and table identically
   (`+ γ · TAG_U8`). Thus `lkStByte` (`[]` and `[_]` equal `AllBytes`; `[(_, γ), (_, α)]` equals `∃ H, ByteLogUp`)
   satisfies `.Rbr` with `53,759 ≤ 65,536 = 2^16` escapes and makes `τ = []` (`hdoutS`) and `τ.length = 2` (`hLO_stg`)
   definitional.
2. **Stage IN-C (`mIn = 15`, `[β, γ, α] ++ r_emb[0..11]`, `clearedFull` + `szSt`, `shdP_eI = 2^19`):** unlike block
   LogUp, `(β, γ, α)` are drawn BEFORE `r_emb` and `H_in` is committed AFTER round 14 (`stage_in_c.rs`). Using the
   division-free full cleared polynomial `clearedFull` wrapped in `Exec.szSt (incClearedPoly (Dof v))`:
   * `.Rbr` (`stgLkIn_rbr`) holds in 4 lines from `Exec.szSt_escape` because `incClearedPoly` has uniform individual
     degree `≤ 2 · (128 + V) ≤ 262,400 ≤ 2^19` across all 15 challenges (`15 · 2^19 = 7,864,320 ≤ 3 · 2^26`);
   * `stgLkIn_of_inLogUp` (`hLI_stg`) holds by a division-free ring identity even at bad `m j = 0` poles;
   * `not_stgLkIn_nil_of_not_inGood` (`hdinS`) reuses `StageX.in_lookup_sound` + a 1-slice pole union bound.
3. **Polymorphic + concrete interface:** `stgLkIn_rbr` and `stgLkOut_rbr` are proved for arbitrary view-to-data
   extractors `Dof` and `(limbOf, plOf, multOf)` AND specialized to `shd_ΛI` / `shd_ΛO` (`shd_hLuStg`), giving `L63`
   zero-friction composition regardless of how `XO` (`B_in`) is presented.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBlkPinsHd
import ZK60Formal.RunStgShieldIOLink
import ZK60Formal.StageOutCWhole
import ZK60Formal.StageInExtractSlots
import ZK60Formal.RelW16HostDeg

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV (IncPub OutcPub incLay outcLay incA_TOK incA_MULT ocC_LIMB ocC_X ocC_MULT tagEmb tagU8)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. Escape bounds & generic `stgLkSqV_rbr` wrapper -/

/-- Stage IN-C per-round lookup escape bound: `2^19 = 524,288` (`15 · 2^19 = 7,864,320 ≤ 3 · 2^26`). -/
def shdP_eI : ℕ := 2 ^ 19

/-- Stage OUT-C per-round lookup escape bound: `2^16 = 65,536` (`53,759 ≤ 2^16 ≤ 2^26`). -/
def shdP_eO : ℕ := 2 ^ 16

theorem stgLkSqV_rbr {K : Type} [Field K] [Algebra GF K] {L : ℕ}
    (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (h : ∀ v τ mg, τ.length < m → ¬ Λ v τ → EscapesWithin (fun c => Λ v (τ ++ [(mg, c)])) e) :
    (stgLkSqV m hdrLen e absOf Λ).Rbr :=
  fun Lg hdr τ mg hlt hns => h (stgVw absOf Lg hdr) τ mg hlt hns

/-- Base-projected stage plane at `(off, log)` from the matrix extracted at view position `i` (`stgIOX` + `planeZ` +
`piB`). -/
noncomputable def stgPlB {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (lc h Q e rows i off log : ℕ)
    (v : StgVw Lq) (b : Fin log → Bool) : GF :=
  Exec.Block.Join.W16.piB K
    (Exec.Block.Join.planeZ U lc rows Q (stgIOX tag h64 lc h Q e rows i v)
      ⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ b)

/-! ## 2. Stage OUT-C (`m = 2`, `[γ, α]`, `lkStByte`, `stgLkOut`, `shd_ΛO`) -/

section StageOutLu

/-- Generic 2-round `[γ, α]` byte-LogUp state (no `β`). -/
def lkStByte {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
    {ι π : Type} [Fintype ι] [Fintype π]
    (a : ι → GF) (p1 p2 : π → GF) (mult : Fin 256 → K) (tagVal : K)
    (τ : List (List UInt8 × K)) : Prop :=
  match τ with
  | [] => AllBytes a p1 p2
  | [_] => AllBytes a p1 p2
  | [(_, γ), (_, α)] =>
      ∃ H, ByteLogUp (algebraMap GF K) a p1 p2 mult (fun g => g * tagVal) (γ, α) H
  | _ => True

theorem lkStByte_nil {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
    {ι π : Type} [Fintype ι] [Fintype π]
    (a : ι → GF) (p1 p2 : π → GF) (mult : Fin 256 → K) (tagVal : K) :
    lkStByte a p1 p2 mult tagVal [] ↔ AllBytes a p1 p2 :=
  Iff.rfl

theorem lkStByte_two {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
    {ι π : Type} [Fintype ι] [Fintype π]
    (U : K) (a : ι → GF) (p1 p2 : π → GF) (mult : Fin 256 → K) (tagVal : K)
    (ch : List Fp2) (hl : ch.length = 2) :
    lkStByte a p1 p2 mult tagVal (ch.map (fun c => ([], c.toK U)))
      ↔ ∃ H, ByteLogUp (algebraMap GF K) a p1 p2 mult (fun g => g * tagVal)
          ((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U) H := by
  rcases ch with _ | ⟨c0, _ | ⟨c1, _ | _⟩⟩ <;> simp at hl
  rfl

theorem lkStByte_escape {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
    {ι π : Type} [Fintype ι] [Fintype π]
    (a : ι → GF) (p1 p2 : π → GF) (mult : Fin 256 → K) (tagVal : K) {e : ℕ}
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : (Fintype.card ι + 2 * Fintype.card π) + 2 * 256 - 1 ≤ e) :
    ∀ τ mg, τ.length < 2 → ¬ lkStByte a p1 p2 mult tagVal τ →
      EscapesWithin (fun c => lkStByte a p1 p2 mult tagVal (τ ++ [(mg, c)])) e := by
  classical
  intro τ mg hlt hns
  rcases τ with _ | ⟨⟨m0, γ⟩, _ | ⟨_, _⟩⟩
  · refine ⟨∅, Nat.zero_le _, fun c hc => ?_⟩
    exact absurd hc hns
  · have hall : ¬ AllBytes a p1 p2 := hns
    have hnot : ∃ l : ι ⊕ (π ⊕ π),
        ∀ j, byteTab (γ * tagVal) j ≠ byteLook (algebraMap GF K) a p1 p2 (γ * tagVal) l := by
      unfold AllBytes at hall
      push Not at hall
      by_cases ha : ∀ i, IsByte (a i)
      · obtain ⟨k, hk⟩ := hall ha
        by_cases h1 : IsByte (p1 k)
        · refine ⟨.inr (.inr k), fun j hj => hk h1 ⟨j, byteLook_hit (algebraMap GF K) hj⟩⟩
        · exact ⟨.inr (.inl k), fun j hj => h1 ⟨j, byteLook_hit (algebraMap GF K) hj⟩⟩
      · push Not at ha
        obtain ⟨i, hi⟩ := ha
        exact ⟨.inl i, fun j hj => hi ⟨j, byteLook_hit (algebraMap GF K) hj⟩⟩
    obtain ⟨l, hl⟩ := hnot
    have hcard : Fintype.card (ι ⊕ (π ⊕ π)) < ringChar K := by
      rw [Fintype.card_sum, Fintype.card_sum]
      omega
    have hne := logup_ne_of_not_mem
      (byteLook (algebraMap GF K) a p1 p2 (γ * tagVal)) (byteTab (γ * tagVal)) mult hcard (i := l) hl
    have hbd := card_helperRel_le'
      (byteLook (algebraMap GF K) a p1 p2 (γ * tagVal)) (byteTab (γ * tagVal)) mult hne
    have him : (Finset.univ.image (byteTab (γ * tagVal))).card ≤ 256 :=
      Finset.card_image_le.trans (by simp)
    refine ⟨Finset.univ.filter (fun α =>
        ∃ H, HelperRel (byteLook (algebraMap GF K) a p1 p2 (γ * tagVal)) (byteTab (γ * tagVal)) mult α H),
      by omega, fun c hc => ?_⟩
    simp only [Finset.mem_filter, Finset.mem_univ, true_and]
    exact hc
  · simp at hlt

/-- Polymorphic stage OUT-C lookup predicate over any view-to-planes extractor `(limbOf, plOf, multOf)`. -/
def stgLkOut {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K)
    (v : StgVw Lq) (τ : List (List UInt8 × K)) : Prop :=
  lkStByte (limbOf v)
    (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx1 kc.1) kc.2)
    (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx2 kc.1) kc.2)
    (multOf v) (algebraMap GF K (tagU8 : GF)) τ

theorem stgLkOut_nil {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K) (v : StgVw Lq) :
    stgLkOut limbOf plOf multOf v []
      ↔ AllBytes (limbOf v)
          (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx1 kc.1) kc.2)
          (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx2 kc.1) kc.2) :=
  Iff.rfl

theorem stgLkOut_two {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (U : K) (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K) (v : StgVw Lq) (ch : List Fp2) (hl : ch.length = 2) :
    stgLkOut limbOf plOf multOf v (ch.map (fun c => ([], c.toK U)))
      ↔ ∃ H, ByteLogUp (algebraMap GF K) (limbOf v)
          (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx1 kc.1) kc.2)
          (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx2 kc.1) kc.2)
          (multOf v) (fun g => g * algebraMap GF K (tagU8 : GF))
          ((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U) H :=
  lkStByte_two U _ _ _ _ _ ch hl

/-- **`.Rbr` FOR STAGE OUT-C** at `shdP_eO = 2^16`, polymorphic in `(limbOf, plOf, multOf)`. -/
theorem stgLkOut_rbr {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8))
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K) :
    (stgLkSqV 2 hdrLen shdP_eO absOf (stgLkOut limbOf plOf multOf)).Rbr := by
  have hc1 : Fintype.card (Fin 12 → Bool) = 4096 := by simp
  have hc2 : Fintype.card (Fin 6 × (Fin 12 → Bool)) = 24576 := by simp
  have hN : Fintype.card (Fin 12 → Bool) + 2 * Fintype.card (Fin 6 × (Fin 12 → Bool)) < ringChar K := by
    rw [hc1, hc2, ZK60.Exec.ringChar_eq_gP]
    unfold gP
    norm_num
  have he : (Fintype.card (Fin 12 → Bool) + 2 * Fintype.card (Fin 6 × (Fin 12 → Bool))) + 2 * 256 - 1 ≤ shdP_eO := by
    rw [hc1, hc2]
    unfold shdP_eO
    norm_num
  exact stgLkSqV_rbr 2 hdrLen shdP_eO absOf _ (fun v τ mg hlt hns =>
    lkStByte_escape (limbOf v) _ _ (multOf v) _ hN he τ mg hlt hns)

/-- Concrete OUT-C plane readers on `A_out` (`rA = 76`, `ogStage`) at header index `iA`. -/
noncomputable def shdOutcLimb {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (iA : ℕ) (v : StgVw Lq) :
    (Fin 12 → Bool) → GF :=
  stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff ocC_LIMB) 12 v

noncomputable def shdOutcPl {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (iA : ℕ) (v : StgVw Lq)
    (p : Fin 12) : (Fin 12 → Bool) → GF :=
  stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff (ocC_X + p.val)) 12 v

noncomputable def shdOutcMult {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (iA : ℕ) (v : StgVw Lq) (j : Fin 256) : K :=
  algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA
    ((outcLay O 14).aOff ocC_MULT) 12 v (msbBits 12 j.val))

/-- Concrete `ΛO` at `A_out` view position `iA` (verdict-independent). -/
noncomputable def shd_ΛO {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (iA : ℕ) :
    StgVw Lq → List (List UInt8 × K) → Prop :=
  stgLkOut (shdOutcLimb U tag h64 O iA) (shdOutcPl U tag h64 O iA) (shdOutcMult U tag h64 O iA)

end StageOutLu

/-! ## 3. Stage IN-C (`m = 15`, `[β, γ, α] ++ r_emb`, `clearedFull`, `incClearedPoly`, `stgLkIn`, `shd_ΛI`) -/

section StageInLu

/-- Division-free cleared LogUp numerator over all singles `ι` and all table positions `κ` (no pairs). -/
def clearedFull {K : Type} [CommRing K] {ι κ : Type} [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (A : ι → K) (T m : κ → K) (α : K) : K :=
  (∑ i : ι, (∏ i' ∈ Finset.univ.erase i, (α - A i')) * (∏ j : κ, (α - T j)))
    - (∑ j : κ, m j * ((∏ i : ι, (α - A i)) * (∏ j' ∈ Finset.univ.erase j, (α - T j'))))

/-- Core division-free ring identity: if `H.single i · (α − A i) = 1` and `H.table j · (α − T j) = m j`, then
`clearedFull A T m α = (∑ H.single − ∑ H.table) · (∏ (α − A i) · ∏ (α − T j))` (holds at every pole!). -/
theorem clearedFull_eq_sum_mul {K : Type} [CommRing K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (A : ι → K) (T m : κ → K) (α : K)
    (hs_fn : ι → K) (ht_fn : κ → K)
    (hs : ∀ i, hs_fn i * (α - A i) = 1)
    (ht : ∀ j, ht_fn j * (α - T j) = m j) :
    clearedFull A T m α
      = ((∑ i : ι, hs_fn i) - (∑ j : κ, ht_fn j))
        * ((∏ i : ι, (α - A i)) * (∏ j : κ, (α - T j))) := by
  set PA : K := ∏ i : ι, (α - A i)
  set PT : K := ∏ j : κ, (α - T j)
  have h1 : ∀ i : ι,
      (∏ i' ∈ Finset.univ.erase i, (α - A i')) * PT = hs_fn i * (PA * PT) := by
    intro i
    have hPA : (α - A i) * (∏ i' ∈ Finset.univ.erase i, (α - A i')) = PA :=
      Finset.mul_prod_erase Finset.univ (fun i' => α - A i') (Finset.mem_univ i)
    calc (∏ i' ∈ Finset.univ.erase i, (α - A i')) * PT
        = 1 * (∏ i' ∈ Finset.univ.erase i, (α - A i')) * PT := by ring
      _ = (hs_fn i * (α - A i)) * (∏ i' ∈ Finset.univ.erase i, (α - A i')) * PT := by rw [hs i]
      _ = hs_fn i * ((α - A i) * (∏ i' ∈ Finset.univ.erase i, (α - A i'))) * PT := by ring
      _ = hs_fn i * (PA * PT) := by rw [hPA]; ring
  have h2 : ∀ j : κ,
      m j * (PA * (∏ j' ∈ Finset.univ.erase j, (α - T j'))) = ht_fn j * (PA * PT) := by
    intro j
    have hPT : (α - T j) * (∏ j' ∈ Finset.univ.erase j, (α - T j')) = PT :=
      Finset.mul_prod_erase Finset.univ (fun j' => α - T j') (Finset.mem_univ j)
    calc m j * (PA * (∏ j' ∈ Finset.univ.erase j, (α - T j')))
        = PA * ((ht_fn j * (α - T j)) * (∏ j' ∈ Finset.univ.erase j, (α - T j'))) := by rw [ht j]; ring
      _ = PA * (ht_fn j * ((α - T j) * (∏ j' ∈ Finset.univ.erase j, (α - T j')))) := by ring
      _ = ht_fn j * (PA * PT) := by rw [hPT]; ring
  unfold clearedFull
  change (∑ i : ι, (∏ i' ∈ Finset.univ.erase i, (α - A i')) * PT)
    - (∑ j : κ, m j * (PA * (∏ j' ∈ Finset.univ.erase j, (α - T j'))))
    = ((∑ i : ι, hs_fn i) - (∑ j : κ, ht_fn j)) * (PA * PT)
  simp only [h1, h2, ← Finset.sum_mul, sub_mul]

/-- Forward bridge (`HelperRel → clearedFull = 0`), valid everywhere including bad poles. -/
theorem clearedFull_eq_zero_of_helperRel {K : Type} [Field K] [DecidableEq K]
    {ι κ : Type} [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    {A : ι → K} {T m : κ → K} {α : K} {H : Helpers ι Empty κ K}
    (h : HelperRel (Sum.elim A (Sum.elim Empty.elim Empty.elim)) T m α H) :
    clearedFull A T m α = 0 := by
  obtain ⟨hs, _, ht, hsum⟩ := h
  have hsum' : (∑ i : ι, H.single i) - (∑ j : κ, H.table j) = 0 := by
    simpa using hsum
  rw [clearedFull_eq_sum_mul A T m α H.single H.table hs ht, hsum', zero_mul]

/-- Converse off the poles (`clearedFull = 0 → ∃ H, HelperRel`). -/
theorem helperRel_of_clearedFull_eq_zero {K : Type} [Field K] [DecidableEq K]
    {ι κ : Type} [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    {A : ι → K} {T m : κ → K} {α : K}
    (hc : clearedFull A T m α = 0)
    (hA : ∀ i, α - A i ≠ 0) (hT : ∀ j, α - T j ≠ 0) :
    ∃ H : Helpers ι Empty κ K,
      HelperRel (Sum.elim A (Sum.elim Empty.elim Empty.elim)) T m α H := by
  let H : Helpers ι Empty κ K :=
    ⟨fun i => (α - A i)⁻¹, Empty.elim, fun j => m j * (α - T j)⁻¹⟩
  have hs : ∀ i, H.single i * (α - A i) = 1 := fun i => inv_mul_cancel₀ (hA i)
  have ht : ∀ j, H.table j * (α - T j) = m j := fun j => by
    show m j * (α - T j)⁻¹ * (α - T j) = m j
    rw [mul_assoc, inv_mul_cancel₀ (hT j), mul_one]
  have hprod : (∏ i : ι, (α - A i)) * (∏ j : κ, (α - T j)) ≠ 0 :=
    mul_ne_zero (Finset.prod_ne_zero_iff.mpr fun i _ => hA i)
      (Finset.prod_ne_zero_iff.mpr fun j _ => hT j)
  have hid := clearedFull_eq_sum_mul A T m α H.single H.table hs ht
  rw [hc] at hid
  have hsum : (∑ i : ι, H.single i) - (∑ j : κ, H.table j) = 0 :=
    (mul_eq_zero.mp hid.symm).resolve_right hprod
  refine ⟨H, hs, fun e => e.elim, ht, ?_⟩
  simpa using hsum

/-- Stage IN-C's 15-challenge cleared LogUp polynomial (`y 0 = β, y 1 = γ, y 2 = α, y (3 + c) = r_emb c`). -/
noncomputable def incClearedPoly {K : Type} [Field K] [Algebra GF K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (D : InData GF ι κ 12) (y : Fin 15 → K) : K :=
  let φ := algebraMap GF K
  let r : Fin 12 → K := fun c => y ⟨3 + c.val, by omega⟩
  clearedFull
    (fun t => fold (y 0) (y 1) (qTup φ D r t))
    (fun j => fold (y 0) (y 1) (tTup φ D r j))
    (fun j => φ (D.m j))
    (y 2)

private theorem indDeg_finsetProd {K : Type} [Field K] {α : Type} [DecidableEq α] {N d : ℕ}
    (s : Finset α) {f : α → (Fin N → K) → K} (hf : ∀ a ∈ s, IndDegLE d (f a)) :
    IndDegLE (s.card * d) (fun x => ∏ a ∈ s, f a x) := by
  induction s using Finset.induction_on with
  | empty =>
    simpa using (IndDegLE.const (n := N) (d := 0) (1 : K))
  | @insert a s hna ih =>
    have h1 : IndDegLE d (f a) := hf a (Finset.mem_insert_self a s)
    have h2 : IndDegLE (s.card * d) (fun x => ∏ b ∈ s, f b x) :=
      ih (fun b hb => hf b (Finset.mem_insert_of_mem hb))
    have hm := IndDegLE.mul h1 h2
    rw [Finset.card_insert_of_notMem hna, show (s.card + 1) * d = d + s.card * d by ring]
    simpa only [Finset.prod_insert hna] using hm

private theorem incFactor_indDeg {K : Type} [Field K] (c0 ctag cz : K) (P : (Fin 12 → Bool) → K) :
    IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) ⟨c0, ctag, mleAt P (fun c : Fin 12 => y ⟨3 + c.val, by omega⟩), cz⟩) := by
  let σ : Fin 12 → Fin 15 := fun c => ⟨3 + c.val, by omega⟩
  have hσ : Function.Injective σ := fun a b h => Fin.ext (by
    have hv := congrArg Fin.val h
    dsimp [σ] at hv
    omega)
  have hmle : IndDegLE 1 (fun y : Fin 15 → K => mleAt P (fun c => y (σ c))) :=
    ZK60.Sound.SlotW16.indDeg_sel (indDegLE_mleAt P) σ hσ
  have hy0 : IndDegLE 1 (fun y : Fin 15 → K => y 0) := ZK60.Sound.SlotW16.indDeg_coord 0
  have hy1 : IndDegLE 1 (fun y : Fin 15 → K => y 1) := ZK60.Sound.SlotW16.indDeg_coord 1
  have hy2 : IndDegLE 2 (fun y : Fin 15 → K => y 2) := IndDegLE.mono (ZK60.Sound.SlotW16.indDeg_coord 2) (by norm_num)
  have ht0 : IndDegLE 2 (fun _ : Fin 15 → K => c0) := IndDegLE.const c0
  have ht1 : IndDegLE 2 (fun y : Fin 15 → K => y 1 * ctag) :=
    IndDegLE.mono (IndDegLE.mul hy1 (IndDegLE.const (d := 0) ctag)) (by norm_num)
  have ht2 : IndDegLE 2 (fun y : Fin 15 → K => y 0 * mleAt P (fun c => y (σ c))) :=
    IndDegLE.mul hy0 hmle
  have ht3 : IndDegLE 2 (fun y : Fin 15 → K => y 0 ^ 2 * cz) := by
    have hp2 : IndDegLE 2 (fun y : Fin 15 → K => y 0 ^ 2) := by
      simpa using ZK60.Sound.SlotW16.indDeg_pow hy0 2
    simpa using IndDegLE.mul hp2 (IndDegLE.const (d := 0) cz)
  have hfold : IndDegLE 2 (fun y : Fin 15 → K =>
      fold (y 0) (y 1) ⟨c0, ctag, mleAt P (fun c => y (σ c)), cz⟩) := by
    unfold Sound.fold
    exact IndDegLE.add (IndDegLE.add (IndDegLE.add ht0 ht1) ht2) ht3
  exact IndDegLE.sub hy2 hfold

/-- **`incClearedPoly D` has individual degree `≤ 2 · (|ι| + |κ|)` in every one of the 15 challenges.** -/
theorem incClearedPoly_indDeg {K : Type} [Field K] [Algebra GF K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (D : InData GF ι κ 12) :
    IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (incClearedPoly (K := K) D) := by
  let φ := algebraMap GF K
  have hfA : ∀ t : ι, IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) t)) :=
    fun t => incFactor_indDeg (φ (D.tok t)) (φ D.tag) (φ (D.cq t)) (fun b => φ (D.X t b))
  have hfT : ∀ j : κ, IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j)) :=
    fun j => incFactor_indDeg (φ (D.vid j)) (φ D.tag) (φ (D.ctl j)) (fun b => φ (D.E j b))
  have hs1 : IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (fun y : Fin 15 → K =>
      ∑ i : ι, (∏ i' ∈ Finset.univ.erase i,
          (y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) i')))
        * (∏ j : κ, (y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j)))) := by
    refine ZK60.Sound.SlotW16.indDeg_sum (fun i => ?_)
    have hpA := indDeg_finsetProd (Finset.univ.erase i) (fun i' _ => hfA i')
    have hpT := indDeg_finsetProd (Finset.univ : Finset κ) (fun j _ => hfT j)
    refine IndDegLE.mono (IndDegLE.mul hpA hpT) ?_
    have hcA : (Finset.univ.erase i).card ≤ Fintype.card ι := (Finset.card_erase_le).trans (by simp)
    have hcT : (Finset.univ : Finset κ).card = Fintype.card κ := Finset.card_univ
    omega
  have hs2 : IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (fun y : Fin 15 → K =>
      ∑ j : κ, φ (D.m j) *
        ((∏ i : ι, (y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) i)))
          * (∏ j' ∈ Finset.univ.erase j,
              (y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j'))))) := by
    refine ZK60.Sound.SlotW16.indDeg_sum (fun j => IndDegLE.cmul (φ (D.m j)) ?_)
    have hpA := indDeg_finsetProd (Finset.univ : Finset ι) (fun i _ => hfA i)
    have hpT := indDeg_finsetProd (Finset.univ.erase j) (fun j' _ => hfT j')
    refine IndDegLE.mono (IndDegLE.mul hpA hpT) ?_
    have hcA : (Finset.univ : Finset ι).card = Fintype.card ι := Finset.card_univ
    have hcT : (Finset.univ.erase j).card ≤ Fintype.card κ := (Finset.card_erase_le).trans (by simp)
    omega
  unfold incClearedPoly clearedFull
  exact IndDegLE.sub hs1 hs2

private theorem inA_fold_eq {K : Type} [Field K] [Algebra GF K] {V : ℕ}
    (D : InData GF shieldS0.Tok (Fin V) 12) (β γ : K) (r : Fin 12 → K) :
    (fun l => fold β γ (inA (algebraMap GF K) D r l))
      = Sum.elim (fun t => fold β γ (qTup (algebraMap GF K) D r t)) (Sum.elim Empty.elim Empty.elim) := by
  funext l
  rcases l with t | e | e
  · rfl
  · exact e.elim
  · exact e.elim

/-- Polymorphic stage IN-C lookup predicate `szSt (incClearedPoly (Dof v))` over any view-to-`InData` map `Dof`. -/
noncomputable def stgLkIn {K : Type} [Field K] [Algebra GF K] {Lq V : ℕ}
    (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12)
    (v : StgVw Lq) (τ : List (List UInt8 × K)) : Prop :=
  Exec.szSt (incClearedPoly (K := K) (Dof v)) τ

/-- **`.Rbr` FOR STAGE IN-C** at `shdP_eI = 2^19`, polymorphic in `Dof` whenever `V ≤ 2^17`. -/
theorem stgLkIn_rbr {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq V : ℕ}
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12) (hV : V ≤ 2 ^ 17) :
    (stgLkSqV 15 hdrLen shdP_eI absOf (stgLkIn (K := K) Dof)).Rbr := by
  refine stgLkSqV_rbr 15 hdrLen shdP_eI absOf _ (fun v τ mg hlt hns => ?_)
  have hdeg : IndDegLE shdP_eI (incClearedPoly (K := K) (Dof v)) := by
    refine IndDegLE.mono (incClearedPoly_indDeg (Dof v)) ?_
    have hc1 : Fintype.card shieldS0.Tok = 128 := Fintype.card_fin 128
    have hc2 : Fintype.card (Fin V) = V := Fintype.card_fin V
    rw [hc1, hc2]
    unfold shdP_eI
    omega
  exact Exec.szSt_escape _ hdeg τ mg hlt hns

/-- **BRIDGE 1 (`hLI_stg`):** `∃ H, InLogUp` at `ch` (`ch.length = 15`) implies `stgLkIn Dof v (ch.map ...)`. -/
theorem stgLkIn_of_inLogUp {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq V : ℕ}
    (U : K) (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12) (v : StgVw Lq)
    (ch : List Fp2) (hl : ch.length = 15)
    (hlu : ∃ H, InLogUp (algebraMap GF K) (Dof v)
      ((((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U), (ch.getD 2 Fp2.zero).toK U),
        fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) H) :
    stgLkIn (K := K) Dof v (ch.map (fun c => ([], c.toK U))) := by
  unfold stgLkIn
  have hmap : ch.map (fun c => (([] : List UInt8), c.toK U))
      = (ch.map (fun c => c.toK U)).map (fun c => ([], c)) := by
    rw [List.map_map]; rfl
  rw [hmap, Exec.szSt_full_map _ [] (ch.map (fun c => c.toK U)) (by rw [List.length_map, hl])]
  have hget : ∀ i : ℕ, i < 15 → (ch.map (fun c => c.toK U)).getD i 0 = (ch.getD i Fp2.zero).toK U := by
    intro i hi
    have hi' : i < ch.length := by omega
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hi']
    rfl
  obtain ⟨H, hH⟩ := hlu
  unfold InLogUp at hH
  rw [inA_fold_eq] at hH
  unfold incClearedPoly
  have h0 : (ch.map (fun c => c.toK U)).getD (0 : Fin 15).val 0 = (ch.getD 0 Fp2.zero).toK U := hget 0 (by omega)
  have h1 : (ch.map (fun c => c.toK U)).getD (1 : Fin 15).val 0 = (ch.getD 1 Fp2.zero).toK U := hget 1 (by omega)
  have h2 : (ch.map (fun c => c.toK U)).getD (2 : Fin 15).val 0 = (ch.getD 2 Fp2.zero).toK U := hget 2 (by omega)
  have hr : (fun c : Fin 12 => (ch.map (fun x => x.toK U)).getD (3 + c.val) 0)
      = (fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) :=
    funext fun c => hget (3 + c.val) (by omega)
  dsimp only
  rw [h0, h1, h2, hr]
  exact clearedFull_eq_zero_of_helperRel hH

/-- **BRIDGE 2 (`hdinS`):** if `V ≤ 2^17`, `D.vid` is injective, and `¬ InGood (Dof v)`, then `¬ stgLkIn Dof v []`. -/
theorem not_stgLkIn_nil_of_not_inGood {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq V : ℕ}
    (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12) (v : StgVw Lq)
    (hV : V ≤ 2 ^ 17) (hvid : Function.Injective (Dof v).vid) (hbad : ¬ InGood (Dof v)) :
    ¬ stgLkIn (K := K) Dof v [] := by
  classical
  set D := Dof v
  let φ := algebraMap GF K
  intro hall
  rw [stgLkIn, Exec.szSt_nil] at hall
  let yOf : InChal K 12 → Fin 15 → K := fun ω i =>
    if i.val = 0 then ω.1.1.1
    else if i.val = 1 then ω.1.1.2
    else if i.val = 2 then ω.1.2
    else ω.2 ⟨i.val - 3, by omega⟩
  have hy_eval : ∀ ω : InChal K 12,
      clearedFull
        (fun t => fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t))
        (fun j => fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j))
        (fun j => φ (D.m j)) ω.1.2 = 0 := by
    intro ω
    have h := hall (yOf ω)
    unfold incClearedPoly at h
    have hr : (fun c : Fin 12 => yOf ω ⟨3 + c.val, by omega⟩) = ω.2 := by
      funext c
      dsimp [yOf]
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
      exact congrArg ω.2 (Fin.ext (by dsimp; omega))
    have h0 : yOf ω 0 = ω.1.1.1 := rfl
    have h1 : yOf ω 1 = ω.1.1.2 := rfl
    have h2 : yOf ω 2 = ω.1.2 := rfl
    dsimp only at h
    rw [h0, h1, h2, hr] at h
    exact h
  let Ep : InChal K 12 → Prop := fun ω =>
    (∃ t : shieldS0.Tok, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t) = 0)
      ∨ (∃ j : Fin V, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j) = 0)
  let El : InChal K 12 → Prop := fun ω => (∃ H, InLogUp φ D ω H) ∧ ¬ InGood D
  have hcover : ∀ ω : InChal K 12, True → Ep ω ∨ El ω := by
    intro ω _
    by_cases hp : Ep ω
    · exact Or.inl hp
    · refine Or.inr ⟨?_, hbad⟩
      have hA : ∀ t : shieldS0.Tok, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t) ≠ 0 :=
        fun t ht => hp (Or.inl ⟨t, ht⟩)
      have hT : ∀ j : Fin V, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j) ≠ 0 :=
        fun j hj => hp (Or.inr ⟨j, hj⟩)
      obtain ⟨H, hH⟩ := helperRel_of_clearedFull_eq_zero (hy_eval ω) hA hT
      refine ⟨H, ?_⟩
      unfold InLogUp
      rw [inA_fold_eq]
      exact hH
  have hcTok : Fintype.card shieldS0.Tok = 128 := Fintype.card_fin 128
  have hcFin : Fintype.card (Fin V) = V := Fintype.card_fin V
  have hEp : pr Ep ≤ ((128 + V : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le_right _ (fun r => pr_prod_le _ (fun bg => ?_))
    let A0 : shieldS0.Tok → K := fun t => fold bg.1 bg.2 (qTup φ D r t)
    let T0 : Fin V → K := fun j => fold bg.1 bg.2 (tTup φ D r j)
    refine prob_le_of_card_filter _ (128 + V) ?_
    have hsub : Finset.univ.filter (fun α : K => Ep ((bg, α), r))
        ⊆ Finset.univ.image A0 ∪ Finset.univ.image T0 := by
      intro α hα
      simp only [Finset.mem_filter, Finset.mem_univ, true_and, Ep] at hα
      rcases hα with ⟨t, ht⟩ | ⟨j, hj⟩
      · exact Finset.mem_union_left _ (Finset.mem_image.mpr ⟨t, Finset.mem_univ t, (sub_eq_zero.mp ht).symm⟩)
      · exact Finset.mem_union_right _ (Finset.mem_image.mpr ⟨j, Finset.mem_univ j, (sub_eq_zero.mp hj).symm⟩)
    have hc1 : (Finset.univ.image A0).card ≤ 128 :=
      Finset.card_image_le.trans (by rw [Finset.card_univ, hcTok])
    have hc2 : (Finset.univ.image T0).card ≤ V :=
      Finset.card_image_le.trans (by rw [Finset.card_univ, hcFin])
    exact (Finset.card_le_card hsub).trans ((Finset.card_union_le _ _).trans (Nat.add_le_add hc1 hc2))
  have hN : Fintype.card shieldS0.Tok < ringChar K := by
    rw [hcTok, ZK60.Exec.ringChar_eq_gP]
    unfold gP
    norm_num
  have hEl : pr El ≤ (((128 + 4 * V - 1) + 128 * 12 : ℕ) : ℝ≥0∞) / Fintype.card K := by
    have h := in_lookup_sound φ D hvid hN
    rwa [hcTok, hcFin] at h
  have h1 : (1 : ℝ≥0∞) = pr (fun _ : InChal K 12 => True) := by
    unfold pr
    rw [PMF.toOuterMeasure_apply_fintype]
    have hi : ∀ ω : InChal K 12,
        {x : InChal K 12 | True}.indicator (PMF.uniformOfFintype (InChal K 12)) ω
          = (Fintype.card (InChal K 12) : ℝ≥0∞)⁻¹ := fun _ => by simp
    simp only [hi, Finset.sum_const, Finset.card_univ, nsmul_eq_mul]
    exact (ENNReal.mul_inv_cancel (by exact_mod_cast Fintype.card_ne_zero) (ENNReal.natCast_ne_top _)).symm
  have hle : (1 : ℝ≥0∞)
      ≤ (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    calc (1 : ℝ≥0∞) = pr (fun _ : InChal K 12 => True) := h1
      _ ≤ pr (fun ω => Ep ω ∨ El ω) := pr_mono hcover
      _ ≤ pr Ep + pr El := pr_or_le Ep El
      _ ≤ ((128 + V : ℕ) : ℝ≥0∞) / Fintype.card K
          + (((128 + 4 * V - 1) + 128 * 12 : ℕ) : ℝ≥0∞) / Fintype.card K := add_le_add hEp hEl
      _ = (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K := by
          rw [ENNReal.div_add_div_same, ← Nat.cast_add]
  have hK : ((128 + V) + ((128 + 4 * V - 1) + 128 * 12)) < Fintype.card K := by
    have hgf : Fintype.card GF ≤ Fintype.card K :=
      Fintype.card_le_of_injective _ (algebraMap GF K).injective
    have hgP : Fintype.card GF = gP := ZMod.card gP
    unfold gP at hgP
    omega
  have hlt1 : (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K < 1 := by
    have hK0 : (Fintype.card K : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
    rw [ENNReal.div_lt_iff (Or.inl hK0) (Or.inl (ENNReal.natCast_ne_top _)), one_mul]
    exact_mod_cast hK
  exact not_lt_of_ge hle hlt1

/-- Concrete IN-C `InData` reader from `A_in` (`rA = 41`, `ogStage` at `iA`) and `B_in` (`rB = 38`, R13 at `iB`). -/
noncomputable def shdIncData {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq) :
    InData GF shieldS0.Tok (Fin P.V) 12 :=
  inDataOf P 12 (tagEmb : GF)
    (fun t => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
      ((incLay I 14).aOff incA_TOK) 12 v (msbBits 12 t.val))
    (fun t c => stgPlB U tag h64 14 16 256 24448 38 iB 0 19 v
      (Fin.append (msbBits 7 t.val) c))
    Epad
    (fun j => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
      ((incLay I 14).aOff incA_MULT) 17 v (msbBits 17 j.val))

/-- Concrete `ΛI` at `B_in` view position `iB` (`pf.off 0 + 2`) and `A_in` view position `iA` (`pf.off 0 + 5`). -/
noncomputable def shd_ΛI {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) :
    StgVw Lq → List (List UInt8 × K) → Prop :=
  stgLkIn (K := K) (shdIncData U tag h64 P I Epad iB iA)

end StageInLu

/-! ## 4. Combined `hLuStg` theorems (polymorphic `stg_hLuStg` and concrete `shd_hLuStg`) -/

/-- **POLYMORPHIC `hLuStg`** for any `Dof` (`V ≤ 2^17`) and `(limbOf, plOf, multOf)`. -/
theorem stg_hLuStg {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq V : ℕ}
    (hdrIn hdrOut : ℕ) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12) (hV : V ≤ 2 ^ 17)
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K) :
    (stgLkSqV 15 hdrIn shdP_eI absOf (stgLkIn (K := K) Dof)).Rbr
      ∧ shdP_eI ≤ 2 ^ 26 ∧ 15 * shdP_eI ≤ 3 * 2 ^ 26
      ∧ (stgLkSqV 2 hdrOut shdP_eO absOf (stgLkOut limbOf plOf multOf)).Rbr
      ∧ shdP_eO ≤ 2 ^ 26 :=
  ⟨stgLkIn_rbr hdrIn absOf Dof hV, by unfold shdP_eI; norm_num, by unfold shdP_eI; norm_num,
   stgLkOut_rbr hdrOut absOf limbOf plOf multOf, by unfold shdP_eO; norm_num⟩

/-- **CONCRETE SHIELDSTRAL `hLuStg`** at `shd_ΛI` (`shdP_eI = 2^19`) and `shd_ΛO` (`shdP_eO = 2^16`). -/
theorem shd_hLuStg {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (absOf : QB Lq → Option (List UInt8))
    (P : InPublic shieldS0) (hV : P.V ≤ 2 ^ 17) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (O : OutcPub)
    (iB hdrIn hdrOut : ℕ) :
    (stgLkSqV 15 hdrIn shdP_eI absOf (shd_ΛI (K := K) U tag h64 P I Epad iB hdrIn)).Rbr
      ∧ shdP_eI ≤ 2 ^ 26 ∧ 15 * shdP_eI ≤ 3 * 2 ^ 26
      ∧ (stgLkSqV 2 hdrOut shdP_eO absOf (shd_ΛO U tag h64 O hdrOut)).Rbr
      ∧ shdP_eO ≤ 2 ^ 26 :=
  stg_hLuStg hdrIn hdrOut absOf _ hV _ _ _


-- REVIEW APPENDIX (reviewer-generated)
#print axioms ZK60.ProtocolClassify.shdP_eI
#print axioms ZK60.ProtocolClassify.shdP_eO
#print axioms ZK60.ProtocolClassify.stgLkSqV_rbr
#print axioms ZK60.ProtocolClassify.stgPlB
#print axioms ZK60.ProtocolClassify.lkStByte
#print axioms ZK60.ProtocolClassify.lkStByte_nil
#print axioms ZK60.ProtocolClassify.lkStByte_two
#print axioms ZK60.ProtocolClassify.lkStByte_escape
#print axioms ZK60.ProtocolClassify.stgLkOut
#print axioms ZK60.ProtocolClassify.stgLkOut_nil
#print axioms ZK60.ProtocolClassify.stgLkOut_two
#print axioms ZK60.ProtocolClassify.stgLkOut_rbr
#print axioms ZK60.ProtocolClassify.shdOutcLimb
#print axioms ZK60.ProtocolClassify.shdOutcPl
#print axioms ZK60.ProtocolClassify.shdOutcMult
#print axioms ZK60.ProtocolClassify.shd_ΛO
#print axioms ZK60.ProtocolClassify.clearedFull
#print axioms ZK60.ProtocolClassify.clearedFull_eq_sum_mul
#print axioms ZK60.ProtocolClassify.clearedFull_eq_zero_of_helperRel
#print axioms ZK60.ProtocolClassify.helperRel_of_clearedFull_eq_zero
#print axioms ZK60.ProtocolClassify.incClearedPoly
#print axioms ZK60.ProtocolClassify.indDeg_finsetProd
#print axioms ZK60.ProtocolClassify.incFactor_indDeg
#print axioms ZK60.ProtocolClassify.incClearedPoly_indDeg
#print axioms ZK60.ProtocolClassify.inA_fold_eq
#print axioms ZK60.ProtocolClassify.stgLkIn
#print axioms ZK60.ProtocolClassify.stgLkIn_rbr
#print axioms ZK60.ProtocolClassify.stgLkIn_of_inLogUp
#print axioms ZK60.ProtocolClassify.not_stgLkIn_nil_of_not_inGood
#print axioms ZK60.ProtocolClassify.shdIncData
#print axioms ZK60.ProtocolClassify.shd_ΛI
#print axioms ZK60.ProtocolClassify.stg_hLuStg
#print axioms ZK60.ProtocolClassify.shd_hLuStg

end ZK60.ProtocolClassify
