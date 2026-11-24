/-
D63 lane L68c, part 3d (`HonestShieldZKVis.lean`):
full-run simulator visibility, PCS/M hiding mask-rank & algebraic independence discharges,
key-separated `.dep` `colDigest` collision avoidance, and exact bottom-up Merkle tree `PProg`
point-anatomy visibility across all 28 segments (`IN-C`, 26× `Blk`, `OUT-C`), 27 internal
boundaries (`B_0..26`), and the input endpoint (`TE`).

What this file defines and proves (standard Lean foundations `propext`, `Classical.choice`, `Quot.sound` only):
1. **Concrete 84-PCS & 28-segment geometry (`shdP_L1Spec`, `shdP_L2Spec`)**:
   - Exact row counts and hiding mask ranks across all 84 PCS tables (`2*1 + 2 = 4` on `TE`,
     `2*2 + 2 = 6` on all 27 boundaries `B_0..26`, full mask/prox/U ranks on every `A`/`H` table,
     and `8 * rows ≤ 2^20` everywhere).
   - Coset pad-surjectivity (`shdP_coset_zn_ne_zero`, `shdP_coset_points_injective`, `shdP_coset_padSurj`),
     claim-site pair independence (`shdP_sitePair_linInd`), proximity-pair independence (`shdP_proxPair_linInd`,
     `shdP_proxPair_linInd_of_fp2Det`), zero-sum row independence & generator (`shdP_zsPair_linInd`,
     `shdP_zsGen`, `shdP_zsGen_add`, `shdP_zsGen_surj`).
   - Exact 28-segment Level-2 slot shapes, degree bounds (`1 ≤ d ≤ 5 < ringChar shdP_K`),
     mask-length bounds (`L_s + 256 ≤ 512`), `M`-table public domain & pad-reachability facts
     (`shdP_M_pub_facts`), and concrete two-level `hHV` specialization (`shdP_full_twoLevel_hHV`).
2. **Key separation (`KeySep`), 4-way query partition (`ShdQKind`, `shdQKind`), and `.dep` collision avoidance**:
   - Classifies every query in `QB Lq` into `.tr | .leaf | .node | .dep`, sending every `colDigest`
     query under `KeySep` to `.dep` (weight `0`).
   - Proves exact byte-level injectivity/extraction for `absorbMsg`, `squeezeMsg`, `digPair`, and `shdP_zkPad`,
     and deterministic disjointness from `ShdRunDepSet` for `saltLeaf`, `nodeHash`, `squeezeMsg`,
     `abLabExp`, and any `absorbMsg` with distinct label and domain-separated length.
3. **Exact `PProg` point-index anatomy & Merkle tree visibility (`PProg.PtLen`, `merkleTreeProg_ptAt_*`,
   `ShdRunVisSpec`)**:
   - Proves exact `ptAt` / `res` decomposition under `PProg.andThen` for fixed-length programs.
   - Proves that every leaf of `merkleTreeProg` is `(tag.leaf, H colQ ‖ salt)` (reconstructible from
     `(receipt, H)` iff opened) and every internal node `k < 2^d - 1` is `(tag.node, v (i₀ + L) ‖ v (i₀ + R))`
     with `L < R < 2^d + k` and injective `L` (always visible from `v` alone when `¬ G v`).
   - Packages `ShdRunVisSpec` discharging `hvisG`, `hvis`, `hrefG` cleanly for `shdP_zk_of_prog_res`.
-/
import ZK60Formal.HonestShieldZKView
import ZK60Formal.HonestShieldZKProg
import ZK60Formal.HonestShieldAuditDet

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Hiding ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest
open ZK60.HonestClassify ZK60.HonestOpen ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (Kind kindOf nSlots)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)

/-! ## 1. Concrete 84-PCS & 28-segment hiding geometry, mask ranks, and algebraic discharges -/

section ConcreteGeometry

/-- Input token endpoint PCS table specification (`TE`: `n = 256`, `Q = 256`, `2` data rows, `1` site pair,
`2` prox rows; `6` total rows, `2^11 = 2048` columns). -/
def shdP_teSpec : PcsTableSpec where
  n := 2 ^ 8
  Q := 256
  Dat := Fin 2
  Γ := Fin 1
  Salt := Fin (2 ^ 11) → Dig

/-- Internal boundary PCS table specification (`B_0..26`: `n = 16384`, `Q = 256`, `32` data rows, `2` site pairs,
`2` prox rows; `38` total rows, `2^16 = 65536` columns). -/
def shdP_bndSpec : PcsTableSpec where
  n := 2 ^ 14
  Q := 256
  Dat := Fin 32
  Γ := Fin 2
  Salt := Fin (2 ^ 16) → Dig

/-- Stage IN-C `A` table specification (`41` rows = `33` data + `2*3` site mask + `2` prox, `2^14` cols). -/
def shdP_incASpec : PcsTableSpec where
  n := 2 ^ 12
  Q := 256
  Dat := Fin 33
  Γ := Fin 3
  Salt := Fin (2 ^ 14) → Dig

/-- Stage IN-C `H` table specification (`76` rows = `66` data + `2` zero-sum `U` + `2*3` site mask + `2` prox). -/
def shdP_incHSpec : PcsTableSpec where
  n := 2 ^ 12
  Q := 256
  Dat := Fin 66
  Γ := Fin 3
  Salt := Fin (2 ^ 14) → Dig

/-- R13 block `A` table specification (`4577` rows = `4283` data + `2*146` site mask + `2` prox, `2^16` cols). -/
def shdP_blkASpec : PcsTableSpec where
  n := 2 ^ 14
  Q := 256
  Dat := Fin 4283
  Γ := Fin 146
  Salt := Fin (2 ^ 16) → Dig

/-- R13 block `H` table specification (`4390` rows = `4280` data + `2` zero-sum `U` + `2*53` site mask + `2` prox). -/
def shdP_blkHSpec : PcsTableSpec where
  n := 2 ^ 14
  Q := 256
  Dat := Fin 4280
  Γ := Fin 53
  Salt := Fin (2 ^ 16) → Dig

/-- Stage OUT-C `A` table specification (`76` rows = `16` data + `2*29` site mask + `2` prox, `2^14` cols). -/
def shdP_outcASpec : PcsTableSpec where
  n := 2 ^ 12
  Q := 256
  Dat := Fin 16
  Γ := Fin 29
  Salt := Fin (2 ^ 14) → Dig

/-- Stage OUT-C `H` table specification (`38` rows = `16` data + `2` zero-sum `U` + `2*9` site mask + `2` prox). -/
def shdP_outcHSpec : PcsTableSpec where
  n := 2 ^ 12
  Q := 256
  Dat := Fin 16
  Γ := Fin 9
  Salt := Fin (2 ^ 14) → Dig

/-- Complete 84-PCS-table Level-1 specification for Shieldstral T128 R13 (`TE` + `27` boundaries + `28` `(A, H)` pairs). -/
def shdP_L1Spec : ShdL1Spec where
  te := shdP_teSpec
  bnd := fun _ => shdP_bndSpec
  ah := fun s =>
    if s.val = 0 then ⟨shdP_incASpec, shdP_incHSpec⟩
    else if s.val = 27 then ⟨shdP_outcASpec, shdP_outcHSpec⟩
    else ⟨shdP_blkASpec, shdP_blkHSpec⟩

/-- Total base-field rows and hiding mask-row rank of a standard PCS table (`TE`, `B_k`, `A_s`). -/
def PcsTableSpec.stdRows (T : PcsTableSpec) : ℕ := Fintype.card T.Dat + 2 * Fintype.card T.Γ + 2
def PcsTableSpec.maskRank (T : PcsTableSpec) : ℕ := 2 * Fintype.card T.Γ + 2

/-- Total base-field rows and hiding mask-row rank (including the 2 zero-sum `U` rows) of an `H` PCS table. -/
def PcsTableSpec.hRows (T : PcsTableSpec) : ℕ := Fintype.card T.Dat + 2 + 2 * Fintype.card T.Γ + 2
def PcsTableSpec.hMaskRank (T : PcsTableSpec) : ℕ := 2 + 2 * Fintype.card T.Γ + 2

/-- **Exact row counts, hiding mask ranks, and column-byte fit (`8 * rows ≤ 2^20`) across all 84 PCS tables**
(`2*sites + 2` on `TE` and all 27 boundaries `B_0..26`; full mask/prox/U rows on every segment's `A` and `H`). -/
theorem shdP_L1_rowCounts_and_maskRanks :
    (shdP_L1Spec.te.stdRows = 6 ∧ shdP_L1Spec.te.maskRank = 4 ∧ 8 * shdP_L1Spec.te.stdRows ≤ 2 ^ 20)
    ∧ (∀ k : Fin 27, (shdP_L1Spec.bnd k).stdRows = 38 ∧ (shdP_L1Spec.bnd k).maskRank = 6
        ∧ 8 * (shdP_L1Spec.bnd k).stdRows ≤ 2 ^ 20)
    ∧ (∀ s : Fin 28,
        if s.val = 0 then
          (shdP_L1Spec.ah s).A.stdRows = 41 ∧ (shdP_L1Spec.ah s).A.maskRank = 8
            ∧ (shdP_L1Spec.ah s).H.hRows = 76 ∧ (shdP_L1Spec.ah s).H.hMaskRank = 10
        else if s.val = 27 then
          (shdP_L1Spec.ah s).A.stdRows = 76 ∧ (shdP_L1Spec.ah s).A.maskRank = 60
            ∧ (shdP_L1Spec.ah s).H.hRows = 38 ∧ (shdP_L1Spec.ah s).H.hMaskRank = 22
        else
          (shdP_L1Spec.ah s).A.stdRows = 4577 ∧ (shdP_L1Spec.ah s).A.maskRank = 294
            ∧ (shdP_L1Spec.ah s).H.hRows = 4390 ∧ (shdP_L1Spec.ah s).H.hMaskRank = 110)
    ∧ (∀ s : Fin 28, 8 * (shdP_L1Spec.ah s).A.stdRows ≤ 2 ^ 20 ∧ 8 * (shdP_L1Spec.ah s).H.hRows ≤ 2 ^ 20) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · dsimp only [shdP_L1Spec, shdP_teSpec, PcsTableSpec.stdRows, PcsTableSpec.maskRank]
    simp only [Fintype.card_fin]
    norm_num
  · intro _
    dsimp only [shdP_L1Spec, shdP_bndSpec, PcsTableSpec.stdRows, PcsTableSpec.maskRank]
    simp only [Fintype.card_fin]
    norm_num
  · intro s
    by_cases h0 : s.val = 0
    · simp only [ite_eq_left h0, shdP_L1Spec, shdP_incASpec, shdP_incHSpec,
        PcsTableSpec.stdRows, PcsTableSpec.maskRank, PcsTableSpec.hRows, PcsTableSpec.hMaskRank,
        Fintype.card_fin]
      norm_num
    · by_cases h27 : s.val = 27
      · simp only [ite_eq_right h0, ite_eq_left h27, shdP_L1Spec, shdP_outcASpec, shdP_outcHSpec,
          PcsTableSpec.stdRows, PcsTableSpec.maskRank, PcsTableSpec.hRows, PcsTableSpec.hMaskRank,
          Fintype.card_fin]
        norm_num
      · simp only [ite_eq_right h0, ite_eq_right h27, shdP_L1Spec, shdP_blkASpec, shdP_blkHSpec,
          PcsTableSpec.stdRows, PcsTableSpec.maskRank, PcsTableSpec.hRows, PcsTableSpec.hMaskRank,
          Fintype.card_fin]
        norm_num
  · intro s
    by_cases h0 : s.val = 0
    · simp only [shdP_L1Spec, ite_eq_left h0, shdP_incASpec, shdP_incHSpec,
        PcsTableSpec.stdRows, PcsTableSpec.hRows, Fintype.card_fin]
      norm_num
    · by_cases h27 : s.val = 27
      · simp only [shdP_L1Spec, ite_eq_right h0, ite_eq_left h27, shdP_outcASpec, shdP_outcHSpec,
          PcsTableSpec.stdRows, PcsTableSpec.hRows, Fintype.card_fin]
        norm_num
      · simp only [shdP_L1Spec, ite_eq_right h0, ite_eq_right h27, shdP_blkASpec, shdP_blkHSpec,
          PcsTableSpec.stdRows, PcsTableSpec.hRows, Fintype.card_fin]
        norm_num

/-! ### PCS algebraic hiding discharges (`coset`, `pair`, `prox`, `U` zero-sum generator) -/

/-- Every Shieldstral PCS coset point (`7 * ω_{k+lr}^j`, `k + lr ≤ 31`) lies outside the `2^k`-th roots of unity. -/
theorem shdP_coset_zn_ne_zero {k lr : ℕ} (hkl : k + lr ≤ 31) (j : ℕ) :
    ((7 : GF) * (rootFp (k + lr)).toGF ^ j) ^ (2 ^ k) - 1 ≠ 0 := by
  have hdvd : 2 ^ k ∣ 2 ^ (k + lr) := ⟨2 ^ lr, by rw [pow_add]⟩
  have hroot := rootFp_isPrimitiveRoot (k := k + lr) (by omega)
  exact Hiding.coset_zn_ne_zero hdvd (7 : GF) (rootFp (k + lr)).toGF hroot.pow_eq_one
    (Exec.seven_pow_two_pow_ne_one hkl) j

/-- Every Shieldstral PCS coset domain `j ↦ 7 * ω_{k+lr}^j` (`k + lr ≤ 31`) is injective on `Fin (2^(k+lr))`. -/
theorem shdP_coset_points_injective {k lr : ℕ} (hkl : k + lr ≤ 31) :
    Function.Injective (fun j : Fin (2 ^ (k + lr)) => (7 : GF) * (rootFp (k + lr)).toGF ^ (j : ℕ)) :=
  Hiding.coset_points_injective (7 : GF) (rootFp (k + lr)).toGF Exec.seven_ne_zero_GF
    (rootFp_isPrimitiveRoot (k := k + lr) (by omega))

/-- **PCS pad-block surjectivity (`hE`) on any Shieldstral coset (`(8,3)`, `(12,2)`, `(14,2)`)**:
at most `Q = 256` distinct opened columns yield a surjective pad block onto `Fin kOpen → GF`. -/
theorem shdP_coset_padSurj {k lr Q kOpen : ℕ} (hkl : k + lr ≤ 31) (hkQ : kOpen ≤ Q)
    (idx : Fin kOpen → Fin (2 ^ (k + lr))) (hidx : Function.Injective idx)
    (E : Matrix (Fin kOpen) (Fin (2 ^ k) ⊕ Fin Q) GF)
    (hEpad : ∀ j l,
      let x := (7 : GF) * (rootFp (k + lr)).toGF ^ (idx j : ℕ)
      E j (Sum.inr l) = (x ^ (2 ^ k) - 1) * x ^ (l : ℕ)) :
    Function.Surjective (fun p : Fin Q → GF => fun j => ∑ l, E j (Sum.inr l) * p l) :=
  ZKLinks.padSurj_of_points hkQ
    (fun j => (7 : GF) * (rootFp (k + lr)).toGF ^ (idx j : ℕ))
    (fun j => ((7 : GF) * (rootFp (k + lr)).toGF ^ (idx j : ℕ)) ^ (2 ^ k) - 1)
    ((shdP_coset_points_injective hkl).comp hidx)
    (fun j => shdP_coset_zn_ne_zero hkl (idx j : ℕ))
    E hEpad

/-- **Claim-site mask pair independence (`hab`)**: any nonzero terminal mask coefficient `c : shdP_K`
yields `GF`-linearly independent pair `(c, c * shdP_U)`. -/
theorem shdP_sitePair_linInd {c : shdP_K} (hc : c ≠ 0) :
    LinearIndependent GF ![c, c * shdP_U] :=
  Hiding.pair_coeffs_independent hc shdP_U_not_mem_range

/-- **Zero-sum `U` pair independence (`hsH`)**: `(1, shdP_U)` is `GF`-linearly independent. -/
theorem shdP_zsPair_linInd : LinearIndependent GF ![(1 : shdP_K), shdP_U] := by
  simpa using shdP_sitePair_linInd (c := (1 : shdP_K)) one_ne_zero

/-- **Proximity-pair independence (`hp`)** from base-field determinant non-vanishing. -/
theorem shdP_proxPair_linInd {a₀ a₁ b₀ b₁ : GF} (hdet : a₀ * b₁ - a₁ * b₀ ≠ 0) :
    LinearIndependent GF
      ![algebraMap GF shdP_K a₀ + algebraMap GF shdP_K a₁ * shdP_U,
        algebraMap GF shdP_K b₀ + algebraMap GF shdP_K b₁ * shdP_U] :=
  Hiding.independent_of_det_ne_zero shdP_U_not_mem_range a₀ a₁ b₀ b₁ hdet

/-- **Proximity-pair independence directly from `Exec.Block.det a b` non-vanishing** (as audited by
`openingChallenges` / `auditClaims`). -/
theorem shdP_proxPair_linInd_of_fp2Det (a b : Fp2) (hdet : (Exec.Block.det a b).v ≠ 0) :
    LinearIndependent GF ![a.toK shdP_U, b.toK shdP_U] := by
  have hcan : (Exec.Block.det a b).Canon :=
    Fp.sub_canon _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _)
  have hgf : (Exec.Block.det a b).toGF ≠ 0 := by
    intro h0
    exact hdet ((Fp.toGF_zero_iff _ hcan).mp h0)
  have hdet' : a.c0.toGF * b.c1.toGF - a.c1.toGF * b.c0.toGF ≠ 0 := by
    unfold Exec.Block.det at hgf
    rwa [Fp.toGF_sub _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul] at hgf
  have ha : a.toK shdP_U = algebraMap GF shdP_K a.c0.toGF + algebraMap GF shdP_K a.c1.toGF * shdP_U := by
    unfold Fp2.toK Hiding.fp2; dsimp only; rw [mul_comm shdP_U]
  have hb : b.toK shdP_U = algebraMap GF shdP_K b.c0.toGF + algebraMap GF shdP_K b.c1.toGF * shdP_U := by
    unfold Fp2.toK Hiding.fp2; dsimp only; rw [mul_comm shdP_U]
  rw [ha, hb]
  exact shdP_proxPair_linInd hdet'

/-- **Zero-sum row generator (`Z` for `PcsAHData` on any `H` table of size `n > 0`)**:
overwrites coordinate `0` with minus the sum of coordinates `1..n-1`. -/
def shdP_zsGen {n : ℕ} (u : Fin n → GF) : Fin n → GF :=
  fun i => if i.val = 0 then -(∑ j : Fin n, if j.val = 0 then (0 : GF) else u j) else u i

theorem shdP_zsGen_add {n : ℕ} (u v : Fin n → GF) :
    shdP_zsGen (u + v) = shdP_zsGen u + shdP_zsGen v := by
  funext i
  simp only [shdP_zsGen, Pi.add_apply]
  by_cases hi : i.val = 0
  · rw [ite_eq_left hi, ite_eq_left hi, ite_eq_left hi]
    have hsum : (∑ j : Fin n, if j.val = 0 then (0 : GF) else u j + v j)
        = (∑ j : Fin n, if j.val = 0 then (0 : GF) else u j)
          + (∑ j : Fin n, if j.val = 0 then (0 : GF) else v j) := by
      rw [← Finset.sum_add_distrib]
      refine Finset.sum_congr rfl fun j _ => ?_
      by_cases hj : j.val = 0
      · rw [ite_eq_left hj, ite_eq_left hj, ite_eq_left hj, add_zero]
      · rw [ite_eq_right hj, ite_eq_right hj, ite_eq_right hj]
    rw [hsum, neg_add]
  · rw [ite_eq_right hi, ite_eq_right hi, ite_eq_right hi]

theorem shdP_zsGen_sum_zero {n : ℕ} (hn : 0 < n) (u : Fin n → GF) :
    ∑ i : Fin n, shdP_zsGen u i = 0 := by
  let z0 : Fin n := ⟨0, hn⟩
  have hsplit : ∑ i : Fin n, shdP_zsGen u i
      = shdP_zsGen u z0 + ∑ i ∈ Finset.univ.erase z0, shdP_zsGen u i :=
    (Finset.add_sum_erase Finset.univ (shdP_zsGen u) (Finset.mem_univ z0)).symm
  rw [hsplit]
  have hz0 : shdP_zsGen u z0 = -(∑ j : Fin n, if j.val = 0 then (0 : GF) else u j) := by
    dsimp only [shdP_zsGen, z0]
    exact ite_eq_left rfl
  have hrest : ∑ i ∈ Finset.univ.erase z0, shdP_zsGen u i
      = ∑ j : Fin n, if j.val = 0 then (0 : GF) else u j := by
    have hsum2 : (∑ j : Fin n, if j.val = 0 then (0 : GF) else u j)
        = (if z0.val = 0 then (0 : GF) else u z0)
          + ∑ j ∈ Finset.univ.erase z0, (if j.val = 0 then (0 : GF) else u j) :=
      (Finset.add_sum_erase Finset.univ _ (Finset.mem_univ z0)).symm
    rw [hsum2, show (if z0.val = 0 then (0 : GF) else u z0) = 0 from ite_eq_left rfl, zero_add]
    refine Finset.sum_congr rfl fun j hj => ?_
    have hne : j.val ≠ 0 := fun hv => (Finset.mem_erase.mp hj).1 (Fin.ext hv)
    simp only [shdP_zsGen, ite_eq_right hne]
  rw [hz0, hrest, neg_add_cancel]

theorem shdP_zsGen_surj {n : ℕ} (hn : 0 < n) (u : Fin n → GF) (hu : ∑ i : Fin n, u i = 0) :
    ∃ u' : Fin n → GF, shdP_zsGen u' = u := by
  refine ⟨u, ?_⟩
  let z0 : Fin n := ⟨0, hn⟩
  funext i
  by_cases hi : i.val = 0
  · have hiz : i = z0 := Fin.ext hi
    rw [hiz]
    dsimp only [shdP_zsGen, z0]
    rw [ite_eq_left rfl]
    have hsum1 : ∑ j : Fin n, u j = u z0 + ∑ j ∈ Finset.univ.erase z0, u j :=
      (Finset.add_sum_erase Finset.univ u (Finset.mem_univ z0)).symm
    have hsum2 : (∑ j : Fin n, if j.val = 0 then (0 : GF) else u j)
        = ∑ j ∈ Finset.univ.erase z0, u j := by
      have hs := (Finset.add_sum_erase Finset.univ (fun j : Fin n => if j.val = 0 then (0 : GF) else u j)
        (Finset.mem_univ z0)).symm
      rw [hs, show (if z0.val = 0 then (0 : GF) else u z0) = 0 from ite_eq_left rfl, zero_add]
      refine Finset.sum_congr rfl fun j hj => ?_
      have hne : j.val ≠ 0 := fun hv => (Finset.mem_erase.mp hj).1 (Fin.ext hv)
      rw [ite_eq_right hne]
    rw [hsum2]
    linear_combination -hu + hsum1
  · simp only [shdP_zsGen, ite_eq_right hi]

/-! ### Concrete 28-segment Level-2 specification (`shdP_L2Spec`) and `M`-table hiding -/

/-- Exact Stage IN-C 4-slot shapes `(main, ext, deg)` at `tPad = 128, epLogN = 8, lt = 12, v = 131072`. -/
def shdP_incSlots : List (ℕ × ℕ × ℕ) :=
  [(8, 1, 3), (12, 1, 4), (17, 1, 4), (12, 1, 2)]

/-- Segment slot shape `(main, ext, deg)` for every segment `s : Fin 28` and slot `t : Fin (shdSegNS s)`. -/
def shdP_segSlotShape (s : Fin 28) (t : Fin (shdSegNS s)) : ℕ × ℕ × ℕ :=
  if s.val = 0 then shdP_incSlots.getD t.val (0, 0, 0)
  else if s.val = 27 then Exec.StageFS.outcSlotsR1.getD t.val (0, 0, 0)
  else Exec.Block.R13.shieldSlots.getD t.val (0, 0, 0)

/-- Concrete 28-segment Level-2 specification (`mm = 512`, `Q = 256`, `r = shdSegNS s`, `MSalt = Fin 4096 → Dig`,
`n t = main + ext - 1`, `d t = deg`). -/
def shdP_L2Spec : ShdL2Spec := fun s =>
  { n := fun t => (shdP_segSlotShape s t).1 + (shdP_segSlotShape s t).2.1 - 1
    d := fun t => (shdP_segSlotShape s t).2.2
    mm := 512
    r := shdSegNS s
    Q := 256
    MSalt := Fin (2 ^ 12) → Dig }

/-- CFS mask coefficient length `L_s = (main + ext) * deg + 2` for slot `t` of segment `s`. -/
def shdP_slotMaskLen (s : Fin 28) (t : Fin (shdSegNS s)) : ℕ :=
  ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t + 2

private theorem shdP_incSlots_bounds : ∀ k : Fin 4,
    let sh := shdP_incSlots.getD k.val (0, 0, 0)
    1 ≤ sh.2.2 ∧ sh.2.2 ≤ 5 ∧ 1 ≤ sh.1 + sh.2.1 ∧ (sh.1 + sh.2.1) * sh.2.2 + 2 + 256 ≤ 512 := by
  decide

private theorem shdP_outcSlots_bounds : ∀ k : Fin 8,
    let sh := Exec.StageFS.outcSlotsR1.getD k.val (0, 0, 0)
    1 ≤ sh.2.2 ∧ sh.2.2 ≤ 5 ∧ 1 ≤ sh.1 + sh.2.1 ∧ (sh.1 + sh.2.1) * sh.2.2 + 2 + 256 ≤ 512 := by
  decide

private theorem shdP_blkSlots_bounds : ∀ k : Fin nSlots,
    let sh := Exec.Block.R13.shieldSlots.getD k.val (0, 0, 0)
    1 ≤ sh.2.2 ∧ sh.2.2 ≤ 5 ∧ 1 ≤ sh.1 + sh.2.1 ∧ (sh.1 + sh.2.1) * sh.2.2 + 2 + 256 ≤ 512 := by
  decide

/-- **Uniform 28-segment Level-2 slot degree & mask-length bounds**:
every slot across IN-C, all 26 R13 blocks, and OUT-C has `1 ≤ d ≤ 5 < ringChar shdP_K` and
`L_s + 256 ≤ 512` (so `mPadPos` fits cleanly inside `G_512` without overlapping any mask coefficient). -/
theorem shdP_L2_slot_bounds (s : Fin 28) (t : Fin (shdSegNS s)) :
    1 ≤ (shdP_L2Spec s).d t
    ∧ (shdP_L2Spec s).d t ≤ 5
    ∧ (shdP_L2Spec s).d t < ringChar shdP_K
    ∧ shdP_slotMaskLen s t + 256 ≤ 512 := by
  have hbound :
      1 ≤ (shdP_segSlotShape s t).2.2
      ∧ (shdP_segSlotShape s t).2.2 ≤ 5
      ∧ 1 ≤ (shdP_segSlotShape s t).1 + (shdP_segSlotShape s t).2.1
      ∧ ((shdP_segSlotShape s t).1 + (shdP_segSlotShape s t).2.1) * (shdP_segSlotShape s t).2.2 + 2 + 256 ≤ 512 := by
    by_cases h0 : s.val = 0
    · have hns : shdSegNS s = 4 := by unfold shdSegNS; exact ite_eq_left h0
      have ht : t.val < 4 := hns ▸ t.isLt
      simpa only [shdP_segSlotShape, ite_eq_left h0] using shdP_incSlots_bounds ⟨t.val, ht⟩
    · by_cases h27 : s.val = 27
      · have hns : shdSegNS s = 8 := by unfold shdSegNS; rw [ite_eq_right h0]; exact ite_eq_left h27
        have ht : t.val < 8 := hns ▸ t.isLt
        simpa only [shdP_segSlotShape, ite_eq_right h0, ite_eq_left h27] using shdP_outcSlots_bounds ⟨t.val, ht⟩
      · have hns : shdSegNS s = nSlots := by unfold shdSegNS; rw [ite_eq_right h0]; exact ite_eq_right h27
        have ht : t.val < nSlots := hns ▸ t.isLt
        simpa only [shdP_segSlotShape, ite_eq_right h0, ite_eq_right h27] using shdP_blkSlots_bounds ⟨t.val, ht⟩
  rcases hbound with ⟨hd1, hd5, hme, hpad⟩
  have hltgP : (shdP_L2Spec s).d t < gP := lt_of_le_of_lt hd5 (by norm_num [gP])
  have hlen : shdP_slotMaskLen s t =
      ((shdP_segSlotShape s t).1 + (shdP_segSlotShape s t).2.1) * (shdP_segSlotShape s t).2.2 + 2 := by
    unfold shdP_slotMaskLen shdP_L2Spec
    dsimp only
    rw [Nat.sub_add_cancel hme]
  exact ⟨hd1, hd5, shdP_lt_ringChar hltgP, by rw [hlen]; exact hpad⟩

/-- **Exact `M`-table row counts across all 28 segments (`12`, `50`, `20`) and column-byte fit (`8 * rows ≤ 2^20`)**. -/
theorem shdP_L2_mRowCounts (s : Fin 28) :
    (if s.val = 0 then 2 * (shdP_L2Spec s).r + 4 = 12
      else if s.val = 27 then 2 * (shdP_L2Spec s).r + 4 = 20
      else 2 * (shdP_L2Spec s).r + 4 = 50)
    ∧ 8 * (2 * (shdP_L2Spec s).r + 4) ≤ 2 ^ 20 := by
  by_cases h0 : s.val = 0
  · simp only [shdP_L2Spec, shdSegNS, ite_eq_left h0]; norm_num
  · by_cases h27 : s.val = 27
    · simp only [shdP_L2Spec, shdSegNS, ite_eq_right h0, ite_eq_left h27]; norm_num
    · simp only [shdP_L2Spec, shdSegNS, ite_eq_right h0, ite_eq_right h27, nSlots]; norm_num

/-- **All public domain & pad-reachability hypotheses for every Shieldstral `M` table (`mm = 512`, `N = 4096`,
`Q = 256`, `G_512 = ⟨ω_9⟩`, coset `7 · ⟨ω_12⟩`)**: directly discharges `hm`, `hmF`, `hy`, `hsum`, `hpad`
in `ShdSegL2Data` for all 28 segments. -/
theorem shdP_M_pub_facts :
    let y : Fin 512 → GF := fun i => (rootFp 9).toGF ^ (i : ℕ)
    let X : Fin 4096 → GF := fun j => (7 : GF) * (rootFp 12).toGF ^ (j : ℕ)
    (0 < (512 : ℕ))
    ∧ ((512 : GF) ≠ 0)
    ∧ Function.Injective y
    ∧ (∀ j < 2 * 512, ∑ i : Fin 512, y i ^ j = if j = 0 ∨ j = 512 then (512 : GF) else 0)
    ∧ Function.Injective X
    ∧ (∀ (j : Fin 4096) (i : Fin 512), X j ≠ y i)
    ∧ (∀ {L qOpen : ℕ} (hLQ : L + 256 ≤ 512) (_hq : qOpen ≤ 256)
        (smp : Fin qOpen → Fin 4096) (v : Fin 512 → GF),
        ∃ g : Fin 256 → GF,
          ∀ t : Fin qOpen,
            (Lagrange.interpolate Finset.univ y (v - Hiding.placePads (Hiding.mPadPos hLQ) g)).eval (X (smp t)) = 0) := by
  dsimp only
  have hω9 : IsPrimitiveRoot (rootFp 9).toGF 512 := by
    simpa only [show (2 : ℕ) ^ 9 = 512 by norm_num] using rootFp_isPrimitiveRoot (k := 9) (by norm_num)
  have hω12 : IsPrimitiveRoot (rootFp 12).toGF 4096 := by
    simpa only [show (2 : ℕ) ^ 12 = 4096 by norm_num] using rootFp_isPrimitiveRoot (k := 12) (by norm_num)
  have h512 : (512 : GF) ≠ 0 := by
    intro h0
    have hdvd : gP ∣ 512 := (ZMod.natCast_eq_zero_iff 512 gP).mp h0
    have hle : gP ≤ 512 := Nat.le_of_dvd (by norm_num) hdvd
    norm_num [gP] at hle
  have hy : Function.Injective (fun i : Fin 512 => (rootFp 9).toGF ^ (i : ℕ)) := fun a b hab =>
    Fin.ext (hω9.pow_inj a.isLt b.isLt hab)
  have hsum : ∀ j < 2 * 512, ∑ i : Fin 512, ((rootFp 9).toGF ^ (i : ℕ)) ^ j
      = if j = 0 ∨ j = 512 then (512 : GF) else 0 :=
    fun j hj => Hiding.rootsOfUnity_powSum hω9 j hj
  have hX : Function.Injective (fun j : Fin 4096 => (7 : GF) * (rootFp 12).toGF ^ (j : ℕ)) :=
    Hiding.coset_points_injective (7 : GF) (rootFp 12).toGF Exec.seven_ne_zero_GF hω12
  have hXy : ∀ (j : Fin 4096) (i : Fin 512),
      (7 : GF) * (rootFp 12).toGF ^ (j : ℕ) ≠ (rootFp 9).toGF ^ (i : ℕ) := by
    intro j i
    have hpow : ((rootFp 9).toGF ^ (i : ℕ)) ^ 512 = 1 := by
      rw [← pow_mul, mul_comm, pow_mul, hω9.pow_eq_one, one_pow]
    exact Hiding.coset_ne_root (m := 512) (N := 4096) (by norm_num) (7 : GF) (rootFp 12).toGF
      hω12.pow_eq_one (by simpa only [show (2 : ℕ) ^ 12 = 4096 by norm_num] using
        Exec.seven_pow_two_pow_ne_one (k := 12) (by norm_num)) _ hpow j.val
  refine ⟨by norm_num, h512, hy, hsum, hX, hXy, ?_⟩
  intro L qOpen hLQ hq smp v
  exact Hiding.mPad_reach _ hy (Hiding.mPadPos hLQ) (Hiding.mPadPos_injective hLQ)
    _ hX hXy smp (Hiding.card_image_le_of_le smp hq) v

/-- **Concrete Shieldstral T128 R13 full-run two-level `hHV` specialization** at `(shdP_L1Spec, shdP_L2Spec)`. -/
theorem shdP_full_twoLevel_hHV {S : ZK60.Block.BlockShape} {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (R : ClassifyRunPublicP S) (Lq k : ℕ)
    (prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (G : (Fin k → Dig) → Prop)
    (π : Coins → ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec)
    (hπ : (PMF.uniformOfFintype Coins).map π = PMF.uniformOfFintype (ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec))
    (ks : ℕ → (v : Fin k → Dig) → ¬ G v → ShdL1OpenK)
    (qs : ℕ → (v : Fin k → Dig) → ¬ G v → (Fin 28 → ℕ))
    (hc : ℕ → (v : Fin k → Dig) → ¬ G v → ShdHostCoeffs shdP_K)
    (D1 : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) →
      ShdL1Data GF shdP_K (AdmAt R verdict) shdP_L1Spec (ks verdict v hg))
    (D2 : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) → (s : Fin 28) →
      ShdSegL2Data GF shdP_K (AdmAt R verdict) (ShdL1Coins GF shdP_L1Spec)
        (ShdL1View GF shdP_K shdP_L1Spec (ks verdict v hg))
        (D1 verdict v hg).view (shdSegKind s) (shdSegHosts (hc verdict v hg) s) shdP_U (7 : GF)
        (shdP_L2Spec s) (qs verdict v hg s))
    (Rc : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) →
      ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (ks verdict v hg) (qs verdict v hg) → ClsStmt Hdr × ClsReceipt)
    (hout : ∀ (verdict : ℕ) (y : AdmAt R verdict) (c : Coins) (v : Fin k → Dig) (hg : ¬ G v),
      PProg.outOf (prog y.1 c) v =
        Rc verdict v hg ((D1 verdict v hg).view y (π c).1, fun s => (D2 verdict v hg s).view y (π c).1 ((π c).2 s))) :
    ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 →
      ∀ v : Fin k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x' c) v) :=
  shdP_twoLevel_hHV R Lq k prog G shdP_L1Spec shdP_L2Spec π hπ ks qs hc D1 D2 Rc hout

end ConcreteGeometry

/-! ## 2. Key separation, 4-way query partition, byte-level extraction, and `.dep` collision avoidance -/

section KeySepAndDepAvoidance

/-- **D19 T-1 domain-key separation** among the Merkle column/leaf/node keys and the Fiat–Shamir transcript key. -/
structure KeySep (tag : MTag) (key : Option Dig) : Prop where
  col_ne_leaf : tag.col ≠ tag.leaf
  col_ne_node : tag.col ≠ tag.node
  leaf_ne_node : tag.leaf ≠ tag.node
  col_ne_key : tag.col ≠ key
  leaf_ne_key : tag.leaf ≠ key
  node_ne_key : tag.node ≠ key

/-- 4-way query classification matching Sol's `shdRunErrRes` budget (`T`, `L`, `N`, and zero-weight `.dep` `colDigest`). -/
inductive ShdQKind where
  | tr
  | leaf
  | node
  | dep
  deriving DecidableEq

/-- Classify any oracle query `z : QB Lq` into `.tr`, `.leaf`, `.node`, or `.dep`:
- 49-byte queries (`shdP_zkPad`) and `key`-tagged transcript queries map to `.tr`;
- 64-byte `tag.leaf` queries map to `.leaf`;
- 64-byte `tag.node` queries map to `.node`;
- all remaining queries (in particular every `tag.col` `colDigest` query under `KeySep`) map to `.dep`. -/
def shdQKind {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) : ShdQKind :=
  if z.2.1.length = 49 then .tr
  else if z.1 = tag.leaf ∧ z.2.1.length = 64 then .leaf
  else if z.1 = tag.node ∧ z.2.1.length = 64 then .node
  else if z.1 = key then .tr
  else .dep

theorem shdQKind_zkPad (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig) (idx : ℕ) (prev : Dig) :
    shdQKind tag key (shdP_zkPad Lq hL20 idx prev) = .tr := by
  unfold shdQKind shdP_zkPad; dsimp only
  exact ite_eq_left (shdP_zkPadMsg_length idx prev)

theorem shdQKind_leaf {Lq : ℕ} (tag : MTag) (key : Option Dig) (x s : Dig)
    (hl : (x.toList ++ s.toList).length ≤ Lq) :
    shdQKind tag key (tag.leaf, ⟨x.toList ++ s.toList, hl⟩) = .leaf := by
  unfold shdQKind; dsimp only
  have h64 : (x.toList ++ s.toList).length = 64 := digPair_length x s
  rw [ite_eq_right (by omega), ite_eq_left ⟨rfl, h64⟩]

theorem shdQKind_node {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (a b : Dig) (hn : (a.toList ++ b.toList).length ≤ Lq) :
    shdQKind tag key (tag.node, ⟨a.toList ++ b.toList, hn⟩) = .node := by
  unfold shdQKind; dsimp only
  have h64 : (a.toList ++ b.toList).length = 64 := digPair_length a b
  have hnl : ¬ (tag.node = tag.leaf ∧ (a.toList ++ b.toList).length = 64) :=
    fun h => hsep.leaf_ne_node h.1.symm
  rw [ite_eq_right (by omega), ite_eq_right hnl, ite_eq_left ⟨rfl, h64⟩]

theorem shdQKind_key {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (bs : List UInt8) (hbs : bs.length ≤ Lq) :
    shdQKind tag key (key, ⟨bs, hbs⟩) = .tr := by
  unfold shdQKind; dsimp only
  by_cases h49 : bs.length = 49
  · exact ite_eq_left h49
  · have hkl : ¬ (key = tag.leaf ∧ bs.length = 64) := fun h => hsep.leaf_ne_key h.1.symm
    have hkn : ¬ (key = tag.node ∧ bs.length = 64) := fun h => hsep.node_ne_key h.1.symm
    rw [ite_eq_right h49, ite_eq_right hkl, ite_eq_right hkn, ite_eq_left rfl]

theorem shdQKind_col {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (bs : List UInt8) (hbs : bs.length ≤ Lq) (h8 : bs.length % 8 = 0) :
    shdQKind tag key (tag.col, ⟨bs, hbs⟩) = .dep := by
  unfold shdQKind; dsimp only
  have h49 : bs.length ≠ 49 := by omega
  have hcl : ¬ (tag.col = tag.leaf ∧ bs.length = 64) := fun h => hsep.col_ne_leaf h.1
  have hcn : ¬ (tag.col = tag.node ∧ bs.length = 64) := fun h => hsep.col_ne_node h.1
  rw [ite_eq_right h49, ite_eq_right hcl, ite_eq_right hcn, ite_eq_right hsep.col_ne_key]

/-! ### Byte-level prefix/suffix extractors and `.dep` collision avoidance -/

private def mkDig32 (l : List UInt8) (h : l.length = 32) : Dig := ⟨l, h⟩

/-- Extract the first 32 bytes of a query message as a `Dig` (returns `zeroDig` if shorter than 32 bytes). -/
def qHeadDig {Lq : ℕ} (z : QB Lq) : Dig :=
  if h : 32 ≤ z.2.1.length then
    mkDig32 (z.2.1.take 32) (by rw [List.length_take]; omega)
  else zeroDig

/-- Extract bytes `32..63` of a query message as a `Dig` (returns `zeroDig` if shorter than 64 bytes). -/
def qTailDig {Lq : ℕ} (z : QB Lq) : Dig :=
  if h : 64 ≤ z.2.1.length then
    mkDig32 ((z.2.1.drop 32).take 32) (by rw [List.length_take, List.length_drop]; omega)
  else zeroDig

theorem qHeadDig_digPair {Lq : ℕ} (k : Option Dig) (a b : Dig) (hl : (a.toList ++ b.toList).length ≤ Lq) :
    qHeadDig (k, ⟨a.toList ++ b.toList, hl⟩) = a := by
  have h64 : 32 ≤ (a.toList ++ b.toList).length := by rw [digPair_length]; omega
  unfold qHeadDig; dsimp only
  rw [dite_eq_left h64]
  exact Subtype.ext (List.take_left' (List.Vector.toList_length a))

theorem qTailDig_digPair {Lq : ℕ} (k : Option Dig) (a b : Dig) (hl : (a.toList ++ b.toList).length ≤ Lq) :
    qTailDig (k, ⟨a.toList ++ b.toList, hl⟩) = b := by
  have h64 : 64 ≤ (a.toList ++ b.toList).length := by rw [digPair_length]
  unfold qTailDig; dsimp only
  rw [dite_eq_left h64]
  apply Subtype.ext
  change ((a.toList ++ b.toList).drop 32).take 32 = b.toList
  rw [List.drop_left' (List.Vector.toList_length a),
    List.take_of_length_le (le_of_eq (List.Vector.toList_length b))]

theorem qHeadDig_absorb {Lq : ℕ} (k : Option Dig) (st : Dig) (label data : List UInt8)
    (hl : (absorbMsg st label data).length ≤ Lq) :
    qHeadDig (k, ⟨absorbMsg st label data, hl⟩) = st := by
  have h32 : 32 ≤ (absorbMsg st label data).length := by
    simp only [absorbMsg, List.length_append, List.Vector.toList_length]; omega
  unfold qHeadDig; dsimp only
  rw [dite_eq_left h32]
  apply Subtype.ext
  change (absorbMsg st label data).take 32 = st.toList
  rw [absorbMsg, List.take_left' (List.Vector.toList_length st)]

theorem qHeadDig_squeeze {Lq : ℕ} (k : Option Dig) (st : Dig) (ctr : UInt64)
    (hl : (squeezeMsg st ctr).length ≤ Lq) :
    qHeadDig (k, ⟨squeezeMsg st ctr, hl⟩) = st := by
  have h32 : 32 ≤ (squeezeMsg st ctr).length := by rw [squeezeMsg_length]; omega
  unfold qHeadDig; dsimp only
  rw [dite_eq_left h32]
  apply Subtype.ext
  change (squeezeMsg st ctr).take 32 = st.toList
  rw [squeezeMsg, List.take_left' (List.Vector.toList_length st)]

theorem qHeadDig_zkPad (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig) :
    qHeadDig (shdP_zkPad Lq hL20 idx prev) = prev := by
  have h32 : 32 ≤ (shdP_zkPadMsg idx prev).length := by rw [shdP_zkPadMsg_length]; omega
  unfold qHeadDig shdP_zkPad; dsimp only
  rw [dite_eq_left h32]
  apply Subtype.ext
  change (shdP_zkPadMsg idx prev).take 32 = prev.toList
  rw [shdP_zkPadMsg, List.take_left' (List.Vector.toList_length prev)]

/-- **Exact byte-level injectivity of `absorbMsg`** on labels of length `< 2^64`. -/
theorem absorbMsg_injective_parts {st₁ st₂ : Dig} {lab₁ lab₂ data₁ data₂ : List UInt8}
    (hl₁ : lab₁.length < 2 ^ 64) (hl₂ : lab₂.length < 2 ^ 64)
    (h : absorbMsg st₁ lab₁ data₁ = absorbMsg st₂ lab₂ data₂) :
    st₁ = st₂ ∧ lab₁ = lab₂ ∧ data₁ = data₂ := by
  have hst : st₁ = st₂ := by
    have ht := congrArg (List.take 32) h
    rw [absorbMsg, absorbMsg, List.take_left' (List.Vector.toList_length st₁),
      List.take_left' (List.Vector.toList_length st₂)] at ht
    exact Subtype.ext ht
  have hrem1 : le64 (UInt64.ofNat lab₁.length) ++ (lab₁ ++ (le64 (UInt64.ofNat data₁.length) ++ data₁))
      = le64 (UInt64.ofNat lab₂.length) ++ (lab₂ ++ (le64 (UInt64.ofNat data₂.length) ++ data₂)) := by
    have hd := congrArg (List.drop 32) h
    rw [absorbMsg, absorbMsg, List.drop_left' (List.Vector.toList_length st₁),
      List.drop_left' (List.Vector.toList_length st₂)] at hd
    exact hd
  have hlenEq : lab₁.length = lab₂.length := by
    have ht := congrArg (List.take 8) hrem1
    rw [List.take_left' (le64_length (UInt64.ofNat lab₁.length)),
      List.take_left' (le64_length (UInt64.ofNat lab₂.length))] at ht
    have h64 : UInt64.ofNat lab₁.length = UInt64.ofNat lab₂.length := by
      rw [← ofLE64_le64 (UInt64.ofNat lab₁.length), ht, ofLE64_le64]
    have hn := congrArg UInt64.toNat h64
    simp only [UInt64.toNat_ofNat', Nat.mod_eq_of_lt hl₁, Nat.mod_eq_of_lt hl₂] at hn
    exact hn
  have hrem2 : lab₁ ++ (le64 (UInt64.ofNat data₁.length) ++ data₁)
      = lab₂ ++ (le64 (UInt64.ofNat data₂.length) ++ data₂) := by
    have hd := congrArg (List.drop 8) hrem1
    rwa [List.drop_left' (le64_length (UInt64.ofNat lab₁.length)),
      List.drop_left' (le64_length (UInt64.ofNat lab₂.length))] at hd
  have hlab : lab₁ = lab₂ := by
    have ht := congrArg (List.take lab₁.length) hrem2
    rw [List.take_left' rfl, hlenEq, List.take_left' rfl] at ht
    exact ht
  have hdata : data₁ = data₂ := by
    have hd1 := congrArg (List.drop lab₁.length) hrem2
    rw [List.drop_left' rfl, hlenEq, List.drop_left' rfl] at hd1
    have hd2 := congrArg (List.drop 8) hd1
    rwa [List.drop_left' (le64_length (UInt64.ofNat data₁.length)),
      List.drop_left' (le64_length (UInt64.ofNat data₂.length))] at hd2
  exact ⟨hst, hlab, hdata⟩

/-- Any `tag.leaf` salted-leaf query is deterministically outside `ShdRunDepSet` under `KeySep`. -/
theorem leaf_notMem_depSet {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (domain shape : List UInt8) (x s : Dig) (hl : (x.toList ++ s.toList).length ≤ Lq) :
    (tag.leaf, ⟨x.toList ++ s.toList, hl⟩) ∉ ShdRunDepSet Lq tag key domain shape := by
  rintro (⟨hk, _⟩ | ⟨hk, _, _⟩ | ⟨hc, _⟩)
  · exact hsep.leaf_ne_key hk
  · exact hsep.leaf_ne_key hk
  · exact hsep.col_ne_leaf hc.symm

/-- Any `tag.node` internal-node query is deterministically outside `ShdRunDepSet` under `KeySep`. -/
theorem node_notMem_depSet {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (domain shape : List UInt8) (a b : Dig) (hn : (a.toList ++ b.toList).length ≤ Lq) :
    (tag.node, ⟨a.toList ++ b.toList, hn⟩) ∉ ShdRunDepSet Lq tag key domain shape := by
  rintro (⟨hk, _⟩ | ⟨hk, _, _⟩ | ⟨hc, _⟩)
  · exact hsep.node_ne_key hk
  · exact hsep.node_ne_key hk
  · exact hsep.col_ne_node hc.symm

/-- Any 47-byte `squeezeMsg` query is deterministically outside `ShdRunDepSet` under `KeySep` when `domain.length ≠ 35`. -/
theorem squeeze_notMem_depSet {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (domain shape : List UInt8) (hdom : domain.length ≠ 35) (st : Dig) (ctr : UInt64)
    (hs : (squeezeMsg st ctr).length ≤ Lq) :
    (key, ⟨squeezeMsg st ctr, hs⟩) ∉ ShdRunDepSet Lq tag key domain shape := by
  rintro (⟨_, hst⟩ | ⟨_, d, habs⟩ | ⟨hc, _⟩)
  · have hlen : (squeezeMsg st ctr).length = (startMsg domain).length := congrArg List.length hst
    have htag : startTag.length = 12 := rfl
    rw [squeezeMsg_length, startMsg, List.length_append, htag] at hlen
    omega
  · have hlen : (squeezeMsg st ctr).length = (absorbMsg d abLabShape shape).length := congrArg List.length habs
    rw [squeezeMsg_length] at hlen
    have habs_len : (absorbMsg d abLabShape shape).length = 48 + abLabShape.length + shape.length := by
      simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]; omega
    rw [habs_len] at hlen
    omega
  · exact hsep.col_ne_key hc.symm

/-- Any `absorbMsg` query with `label ≠ abLabShape` (`label.length < 2^64`) and total length differing from
`12 + domain.length` is deterministically outside `ShdRunDepSet` under `KeySep`. -/
theorem absorb_notMem_depSet_of_len {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (domain shape : List UInt8) (st : Dig) (label data : List UInt8)
    (hlab_ne : label ≠ abLabShape) (hlab_lt : label.length < 2 ^ 64)
    (hlen_ne : 48 + label.length + data.length ≠ 12 + domain.length)
    (ha : (absorbMsg st label data).length ≤ Lq) :
    (key, ⟨absorbMsg st label data, ha⟩) ∉ ShdRunDepSet Lq tag key domain shape := by
  rintro (⟨_, hst⟩ | ⟨_, d, habs⟩ | ⟨hc, _⟩)
  · have hlen := congrArg List.length hst
    have htag : startTag.length = 12 := rfl
    have habs_len : (absorbMsg st label data).length = 48 + label.length + data.length := by
      simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]; omega
    rw [habs_len, startMsg, List.length_append, htag] at hlen
    exact hlen_ne hlen
  · have hshape_lt : abLabShape.length < 2 ^ 64 := by decide
    exact hlab_ne (absorbMsg_injective_parts hlab_lt hshape_lt habs).2.1
  · exact hsep.col_ne_key hc.symm

/-- Shieldstral's `"expected-IO"` absorb (`123` bytes vs `shdP_runDomain`'s `86`-byte `startMsg`) is
deterministically outside `ShdRunDepSet` under `KeySep`. -/
theorem abLabExp_notMem_depSet {Lq : ℕ} {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (shape : List UInt8) (d₁ inDig inRoot : Dig)
    (ha : (absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)).length ≤ Lq) :
    (key, ⟨absorbMsg d₁ abLabExp (abExpMsg inDig inRoot), ha⟩)
      ∉ ShdRunDepSet Lq tag key shdP_runDomain shape := by
  refine absorb_notMem_depSet_of_len hsep shdP_runDomain shape d₁ abLabExp (abExpMsg inDig inRoot)
    (by decide) (by decide) ?_ ha
  have hexp := abExpMsg_length inDig inRoot
  have hl1 : abLabExp.length = 11 := by decide
  have hl2 : shdP_runDomain.length = 73 := by decide
  omega

end KeySepAndDepAvoidance

end ZK60.HonestShield

/-! ## 3. Exact `PProg` point-index anatomy, Merkle tree visibility, and `ShdRunVisSpec` -/

namespace ZK60.ZKHonest

section PProgPtLen

variable {Q D α β : Type}

/-- Exact `.pt` query count on every execution path of a `PProg`. -/
def PProg.PtLen : PProg Q D α → ℕ → Prop
  | .ret _, n => n = 0
  | .dep _ k, n => ∀ d, PProg.PtLen (k d) n
  | .pt _ k, n => ∃ m, n = m + 1 ∧ ∀ d, PProg.PtLen (k d) m

theorem PProg.PtLen.toPtLE : ∀ {p : PProg Q D α} {n : ℕ}, p.PtLen n → p.PtLE n
  | .ret _, _, _ => trivial
  | .dep _ _, _, hp => fun d => (hp d).toPtLE
  | .pt _ _, _, ⟨m, rfl, hk⟩ => ⟨Nat.zero_lt_succ m, fun d => by simpa using (hk d).toPtLE⟩

theorem PProg.PtLen.andThen : ∀ {p : PProg Q D α} {f : α → PProg Q D β} {m n : ℕ},
    p.PtLen m → (∀ a, (f a).PtLen n) → (p.andThen f).PtLen (m + n)
  | .ret a, f, m, n, hm, hf => by have hm0 : m = 0 := hm; rw [hm0, Nat.zero_add]; exact hf a
  | .dep _ _, f, _, _, hp, hf => fun d => (hp d).andThen hf
  | .pt _ _, f, _, n, ⟨m', rfl, hk⟩, hf =>
    ⟨m' + n, by omega, fun d => (hk d).andThen hf⟩

theorem PProg.res_andThen (H : Q → D) (v : ℕ → D) :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) (m i : ℕ), p.PtLen m →
      (p.andThen f).res H v i = (f (p.res H v i)).res H v (i + m)
  | .ret a, f, m, i, hm => by have hm0 : m = 0 := hm; rw [hm0, Nat.add_zero]; rfl
  | .dep z k, f, m, i, hp => PProg.res_andThen H v (k (H z)) f m i (hp (H z))
  | .pt _ k, f, _, i, ⟨m', rfl, hk⟩ => by
    show ((k (v i)).andThen f).res H v (i + 1) = (f ((k (v i)).res H v (i + 1))).res H v (i + (m' + 1))
    rw [PProg.res_andThen H v (k (v i)) f m' (i + 1) (hk (v i)), show i + 1 + m' = i + (m' + 1) by omega]

theorem PProg.ptAt_andThen_left (H : Q → D) (v : ℕ → D) :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) (m i j : ℕ), p.PtLen m → j < i + m →
      (p.andThen f).ptAt H v i j = p.ptAt H v i j
  | .ret a, f, m, i, j, hm, hj => by
    have hm0 : m = 0 := hm
    exact PProg.ptAt_lt H v (f a) i j (by omega)
  | .dep z k, f, m, i, j, hp, hj => PProg.ptAt_andThen_left H v (k (H z)) f m i j (hp (H z)) hj
  | .pt z k, f, _, i, j, ⟨m', rfl, hk⟩, hj => by
    show (if j = i then some z else ((k (v i)).andThen f).ptAt H v (i + 1) j)
      = (if j = i then some z else (k (v i)).ptAt H v (i + 1) j)
    by_cases hji : j = i
    · rw [ite_eq_left hji, ite_eq_left hji]
    · rw [ite_eq_right hji, ite_eq_right hji]
      exact PProg.ptAt_andThen_left H v (k (v i)) f m' (i + 1) j (hk (v i)) (by omega)

theorem PProg.ptAt_andThen_right (H : Q → D) (v : ℕ → D) :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) (m i j : ℕ), p.PtLen m → i + m ≤ j →
      (p.andThen f).ptAt H v i j = (f (p.res H v i)).ptAt H v (i + m) j
  | .ret a, f, m, i, j, hm, _ => by have hm0 : m = 0 := hm; rw [hm0, Nat.add_zero]; rfl
  | .dep z k, f, m, i, j, hp, hj => PProg.ptAt_andThen_right H v (k (H z)) f m i j (hp (H z)) hj
  | .pt z k, f, _, i, j, ⟨m', rfl, hk⟩, hj => by
    have hne : j ≠ i := by omega
    show (if j = i then some z else ((k (v i)).andThen f).ptAt H v (i + 1) j)
      = (f ((k (v i)).res H v (i + 1))).ptAt H v (i + (m' + 1)) j
    rw [ite_eq_right hne, PProg.ptAt_andThen_right H v (k (v i)) f m' (i + 1) j (hk (v i)) (by omega),
      show i + 1 + m' = i + (m' + 1) by omega]

end PProgPtLen

end ZK60.ZKHonest

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Hiding ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest
open ZK60.HonestClassify ZK60.HonestOpen ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (Kind kindOf nSlots)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)

section PProgAnatomyAndVis

/-! ### Exact leaf and internal-node point anatomy of `merkleTreeProg` -/

theorem leafLayerAux_ptLen (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin n → Dig),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).PtLen n
  | 0, _, _, _ => rfl
  | n + 1, colOf, hcol, saltOf => fun _ =>
    ⟨n, rfl, fun ld => by
      have h := (leafLayerAux_ptLen Lq h64 tag n (fun j => colOf j.succ) (fun j => hcol j.succ)
        (fun j => saltOf j.succ)).andThen (f := fun rest => .ret (Fin.cons ld rest : Fin (n + 1) → Dig)) (n := 0) (fun _ => rfl)
      simpa using h⟩

theorem leafLayerAux_res (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin n → Dig)
      (i : ℕ) (j : Fin n),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).res H v i j = v (i + j.val)
  | 0, _, _, _, _, j => by have hf : False := Nat.not_lt_zero j.val j.isLt; cases hf
  | n + 1, colOf, hcol, saltOf, i, j => by
    unfold leafLayerAux
    change ((leafLayerAux Lq h64 tag n _ _ _).andThen fun rest =>
      .ret (Fin.cons (v i) rest : Fin (n + 1) → Dig)).res H v (i + 1) j = v (i + j.val)
    rw [PProg.res_andThen H v _ _ n (i + 1) (leafLayerAux_ptLen Lq h64 tag n _ _ _)]
    refine Fin.cases ?_ (fun k => ?_) j
    · simp only [PProg.res, Fin.cons_zero, Fin.val_zero, Nat.add_zero]
    · simp only [PProg.res, Fin.cons_succ, Fin.val_succ]
      rw [leafLayerAux_res Lq h64 tag H v n _ _ _ (i + 1) k, show i + 1 + k.val = i + (k.val + 1) by omega]

theorem leafLayerAux_ptAt (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin n → Dig)
      (i : ℕ) (j : Fin n),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).ptAt H v i (i + j.val) =
        some (tag.leaf, ⟨(H (tag.col, ⟨colOf j, hcol j⟩)).toList ++ (saltOf j).toList,
          by rw [digPair_length]; exact h64⟩)
  | 0, _, _, _, _, j => by have hf : False := Nat.not_lt_zero j.val j.isLt; cases hf
  | n + 1, colOf, hcol, saltOf, i, j => by
    unfold leafLayerAux
    change (if i + j.val = i then
        some (tag.leaf, ⟨(H (tag.col, ⟨colOf 0, hcol 0⟩)).toList ++ (saltOf 0).toList, _⟩)
      else ((leafLayerAux Lq h64 tag n (fun r => colOf r.succ) (fun r => hcol r.succ) (fun r => saltOf r.succ)).andThen
        fun rest => .ret (Fin.cons (v i) rest : Fin (n + 1) → Dig)).ptAt H v (i + 1) (i + j.val)) = _
    refine Fin.cases ?_ (fun k => ?_) j
    · simp only [Fin.val_zero, Nat.add_zero, ↓reduceIte]
    · have hne : i + k.succ.val ≠ i := by simp only [Fin.val_succ]; omega
      rw [ite_eq_right hne,
        PProg.ptAt_andThen_left H v _ _ n (i + 1) (i + k.succ.val)
          (leafLayerAux_ptLen Lq h64 tag n _ _ _) (by simp only [Fin.val_succ]; have := k.isLt; omega),
        show i + k.succ.val = (i + 1) + k.val by simp only [Fin.val_succ]; omega]
      exact leafLayerAux_ptAt Lq h64 tag H v n _ _ _ (i + 1) k

theorem nodeLayerAux_ptLen (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig), (nodeLayerAux Lq h64 tag m leftOf rightOf).PtLen m
  | 0, _, _ => rfl
  | m + 1, leftOf, rightOf =>
    ⟨m, rfl, fun nd => by
      have h := (nodeLayerAux_ptLen Lq h64 tag m (fun i => leftOf i.succ)
        (fun i => rightOf i.succ)).andThen (f := fun rest => .ret (Fin.cons nd rest : Fin (m + 1) → Dig)) (n := 0) (fun _ => rfl)
      simpa using h⟩

theorem nodeLayerAux_res (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig) (i : ℕ) (j : Fin m),
      (nodeLayerAux Lq h64 tag m leftOf rightOf).res H v i j = v (i + j.val)
  | 0, _, _, _, j => by have hf : False := Nat.not_lt_zero j.val j.isLt; cases hf
  | m + 1, leftOf, rightOf, i, j => by
    unfold nodeLayerAux
    change ((nodeLayerAux Lq h64 tag m _ _).andThen fun rest =>
      .ret (Fin.cons (v i) rest : Fin (m + 1) → Dig)).res H v (i + 1) j = v (i + j.val)
    rw [PProg.res_andThen H v _ _ m (i + 1) (nodeLayerAux_ptLen Lq h64 tag m _ _)]
    refine Fin.cases ?_ (fun k => ?_) j
    · simp only [PProg.res, Fin.cons_zero, Fin.val_zero, Nat.add_zero]
    · simp only [PProg.res, Fin.cons_succ, Fin.val_succ]
      rw [nodeLayerAux_res Lq h64 tag H v m _ _ (i + 1) k, show i + 1 + k.val = i + (k.val + 1) by omega]

theorem nodeLayerAux_ptAt (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig) (i : ℕ) (j : Fin m),
      (nodeLayerAux Lq h64 tag m leftOf rightOf).ptAt H v i (i + j.val) =
        some (tag.node, ⟨(leftOf j).toList ++ (rightOf j).toList, by rw [digPair_length]; exact h64⟩)
  | 0, _, _, _, j => by have hf : False := Nat.not_lt_zero j.val j.isLt; cases hf
  | m + 1, leftOf, rightOf, i, j => by
    unfold nodeLayerAux
    change (if i + j.val = i then
        some (tag.node, ⟨(leftOf 0).toList ++ (rightOf 0).toList, _⟩)
      else ((nodeLayerAux Lq h64 tag m (fun r => leftOf r.succ) (fun r => rightOf r.succ)).andThen
        fun rest => .ret (Fin.cons (v i) rest : Fin (m + 1) → Dig)).ptAt H v (i + 1) (i + j.val)) = _
    refine Fin.cases ?_ (fun k => ?_) j
    · simp only [Fin.val_zero, Nat.add_zero, ↓reduceIte]
    · have hne : i + k.succ.val ≠ i := by simp only [Fin.val_succ]; omega
      rw [ite_eq_right hne,
        PProg.ptAt_andThen_left H v _ _ m (i + 1) (i + k.succ.val)
          (nodeLayerAux_ptLen Lq h64 tag m _ _) (by simp only [Fin.val_succ]; have := k.isLt; omega),
        show i + k.succ.val = (i + 1) + k.val by simp only [Fin.val_succ]; omega]
      exact nodeLayerAux_ptAt Lq h64 tag H v m _ _ (i + 1) k

theorem buildLevelsProg_ptLen (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (d : ℕ) (lv : Fin (2 ^ d) → Dig), (buildLevelsProg Lq h64 tag d lv).PtLen (2 ^ d - 1)
  | 0, _ => rfl
  | d + 1, lv => by
    unfold buildLevelsProg
    have h1 : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) - 1 = 2 ^ d + (2 ^ d - 1 + 0) := by
      have : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
      omega
    rw [hpow]
    exact (nodeLayerAux_ptLen Lq h64 tag (2 ^ d) _ _).andThen fun parent =>
      (buildLevelsProg_ptLen Lq h64 tag d parent).andThen fun _ => rfl

/-- Exact pair of child point-index offsets `(L, R)` relative to tree start `i₀` for internal node `k < 2^d - 1`
in a depth-`d` bottom-up Merkle tree (`merkleTreeProg`). -/
def merkleChildOff : ℕ → ℕ → ℕ × ℕ
  | 0, _ => (0, 0)
  | d + 1, k =>
    if k < 2 ^ d then (2 * k, 2 * k + 1)
    else
      let p := merkleChildOff d (k - 2 ^ d)
      (2 ^ (d + 1) + p.1, 2 ^ (d + 1) + p.2)

/-- Every internal node `k < 2^d - 1` hashes two strictly earlier distinct indices `L < R < 2^d + k`. -/
theorem merkleChildOff_lt : ∀ (d k : ℕ), k < 2 ^ d - 1 →
    (merkleChildOff d k).1 < (merkleChildOff d k).2 ∧ (merkleChildOff d k).2 < 2 ^ d + k
  | 0, k, hk => by omega
  | d + 1, k, hk => by
    have h1 : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    unfold merkleChildOff
    by_cases hlt : k < 2 ^ d
    · rw [ite_eq_left hlt]; omega
    · rw [ite_eq_right hlt]
      dsimp only
      have ih := merkleChildOff_lt d (k - 2 ^ d) (by omega)
      exact ⟨by omega, by omega⟩

/-- Distinct internal nodes in a depth-`d` tree have distinct left-child offsets (hence distinct child pairs). -/
theorem merkleChildOff_fst_inj : ∀ (d k₁ k₂ : ℕ), k₁ < 2 ^ d - 1 → k₂ < 2 ^ d - 1 →
    (merkleChildOff d k₁).1 = (merkleChildOff d k₂).1 → k₁ = k₂
  | 0, k₁, _, hk₁, _, _ => by omega
  | d + 1, k₁, k₂, hk₁, hk₂, heq => by
    have h1d : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    unfold merkleChildOff at heq
    by_cases h1 : k₁ < 2 ^ d
    · rw [ite_eq_left h1] at heq
      by_cases h2 : k₂ < 2 ^ d
      · rw [ite_eq_left h2] at heq; omega
      · rw [ite_eq_right h2] at heq; dsimp only at heq; omega
    · rw [ite_eq_right h1] at heq
      by_cases h2 : k₂ < 2 ^ d
      · rw [ite_eq_left h2] at heq; dsimp only at heq; omega
      · rw [ite_eq_right h2] at heq; dsimp only at heq
        have hsub := merkleChildOff_fst_inj d (k₁ - 2 ^ d) (k₂ - 2 ^ d) (by omega) (by omega) (by omega)
        omega

/-- **Exact internal-node query of `buildLevelsProg`**: every internal node `k < 2^d - 1` depends ONLY on `v`
at indices `base + L` and `base + R` (`L < R < 2^d + k`), with zero dependence on `(x, c, H)`. -/
theorem buildLevelsProg_ptAt (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (d base k : ℕ), k < 2 ^ d - 1 →
      (buildLevelsProg Lq h64 tag d (fun j : Fin (2 ^ d) => v (base + j.val))).ptAt H v
        (base + 2 ^ d) (base + 2 ^ d + k) =
        let p := merkleChildOff d k
        some (tag.node, ⟨(v (base + p.1)).toList ++ (v (base + p.2)).toList, by rw [digPair_length]; exact h64⟩)
  | 0, _, k, hk => by omega
  | d + 1, base, k, hk => by
    have h1d : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    conv_lhs => unfold buildLevelsProg
    conv_rhs => unfold merkleChildOff
    dsimp only
    by_cases hlt : k < 2 ^ d
    · rw [ite_eq_left hlt]; dsimp only
      rw [PProg.ptAt_andThen_left H v _ _ (2 ^ d) (base + 2 ^ (d + 1)) (base + 2 ^ (d + 1) + k)
        (nodeLayerAux_ptLen Lq h64 tag (2 ^ d) _ _) (by omega)]
      exact nodeLayerAux_ptAt Lq h64 tag H v (2 ^ d)
        (fun i : Fin (2 ^ d) => v (base + 2 * i.val))
        (fun i : Fin (2 ^ d) => v (base + (2 * i.val + 1)))
        (base + 2 ^ (d + 1)) ⟨k, hlt⟩
    · rw [ite_eq_right hlt]; dsimp only
      rw [PProg.ptAt_andThen_right H v _ _ (2 ^ d) (base + 2 ^ (d + 1)) (base + 2 ^ (d + 1) + k)
        (nodeLayerAux_ptLen Lq h64 tag (2 ^ d) _ _) (by omega)]
      have hres : (nodeLayerAux Lq h64 tag (2 ^ d)
          (fun i : Fin (2 ^ d) => v (base + 2 * i.val))
          (fun i : Fin (2 ^ d) => v (base + (2 * i.val + 1)))).res H v (base + 2 ^ (d + 1))
          = (fun i : Fin (2 ^ d) => v ((base + 2 ^ (d + 1)) + i.val)) := by
        funext i
        exact nodeLayerAux_res Lq h64 tag H v (2 ^ d) _ _ (base + 2 ^ (d + 1)) i
      rw [hres,
        PProg.ptAt_andThen_left H v _ _ (2 ^ d - 1) (base + 2 ^ (d + 1) + 2 ^ d) (base + 2 ^ (d + 1) + k)
          (buildLevelsProg_ptLen Lq h64 tag d _) (by omega),
        show base + 2 ^ (d + 1) + k = (base + 2 ^ (d + 1)) + 2 ^ d + (k - 2 ^ d) by omega]
      have ih := buildLevelsProg_ptAt Lq h64 tag H v d (base + 2 ^ (d + 1)) (k - 2 ^ d) (by omega)
      dsimp only at ih
      simpa only [Nat.add_assoc] using ih

theorem merkleTreeProg_ptLen (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).PtLen (2 ^ d + (2 ^ d - 1)) :=
  (leafLayerAux_ptLen Lq h64 tag (2 ^ d) colOf hcol saltOf).andThen
    (buildLevelsProg_ptLen Lq h64 tag d)

/-- **Exact leaf point of `merkleTreeProg`**: at index `i₀ + j` (`j < 2^d`), the query is
`(tag.leaf, H (tag.col, colOf j) ‖ saltOf j)` — visible from `(receipt, H)` whenever column `j` is opened. -/
theorem merkleTreeProg_ptAt_leaf (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i₀ : ℕ) (j : Fin (2 ^ d)) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).ptAt H v i₀ (i₀ + j.val) =
      some (tag.leaf, ⟨(H (tag.col, ⟨colOf j, hcol j⟩)).toList ++ (saltOf j).toList,
        by rw [digPair_length]; exact h64⟩) := by
  unfold merkleTreeProg
  rw [PProg.ptAt_andThen_left H v _ _ (2 ^ d) i₀ (i₀ + j.val)
    (leafLayerAux_ptLen Lq h64 tag (2 ^ d) colOf hcol saltOf) (by have := j.isLt; omega)]
  exact leafLayerAux_ptAt Lq h64 tag H v (2 ^ d) colOf hcol saltOf i₀ j

/-- **Exact internal-node point of `merkleTreeProg`**: at index `i₀ + 2^d + k` (`k < 2^d - 1`), the query is
`(tag.node, v (i₀ + L) ‖ v (i₀ + R))` — ALWAYS visible from `v` alone (`¬ G v`), with `L < R < 2^d + k`. -/
theorem merkleTreeProg_ptAt_node (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i₀ k : ℕ) (hk : k < 2 ^ d - 1) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).ptAt H v i₀ (i₀ + 2 ^ d + k) =
      let p := merkleChildOff d k
      some (tag.node, ⟨(v (i₀ + p.1)).toList ++ (v (i₀ + p.2)).toList, by rw [digPair_length]; exact h64⟩) := by
  unfold merkleTreeProg
  rw [PProg.ptAt_andThen_right H v _ _ (2 ^ d) i₀ (i₀ + 2 ^ d + k)
    (leafLayerAux_ptLen Lq h64 tag (2 ^ d) colOf hcol saltOf) (by omega)]
  have hres : (leafLayerAux Lq h64 tag (2 ^ d) colOf hcol saltOf).res H v i₀
      = fun j : Fin (2 ^ d) => v (i₀ + j.val) := by
    funext j
    exact leafLayerAux_res Lq h64 tag H v (2 ^ d) colOf hcol saltOf i₀ j
  rw [hres]
  exact buildLevelsProg_ptAt Lq h64 tag H v d i₀ k hk

/-! ### Full-run simulator visibility package (`ShdRunVisSpec`) -/

/-- **Full-run simulator visibility specification** for a Shieldstral `PProg` at `k = shdP_zkResPts`:
splits every non-refused (`¬ G v`) point index `i` into:
- visible internal Merkle nodes (reconstructed from `v` alone via `merkleTreeProg_ptAt_node`),
- visible transcript / pad points (reconstructed from `(receipt, H, v)`),
- opened Merkle leaves (reconstructed from `(receipt, H)` via `merkleTreeProg_ptAt_leaf`),
leaving ONLY unopened Merkle leaves hidden when `¬ G v`. On refused `G v`, every point is hidden and the
output is the fixed refusal pair `(refused, [])`. -/
structure ShdRunVisSpec {X Coins Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (prog : X → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (refused : ClsStmt Hdr) where
  G : (Fin shdP_zkResPts → Dig) → Prop
  isVisibleAt : (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → Prop
  vp : ClsStmt Hdr × ClsReceipt → (QB Lq → Dig) → (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → QB Lq
  hvis_ok : ∀ x c H v i, ¬ G v → isVisibleAt v i →
    PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i = vp (PProg.outOf (prog x c) v) H v i
  href : ∀ x c v, G v → PProg.outOf (prog x c) v = (refused, [])

/-- Effective visibility predicate `¬ G v ∧ isVisibleAt v i` satisfying `hvisG`, `hvis`, `hrefG`. -/
def ShdRunVisSpec.vis {X Coins Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {prog : X → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)} {refused : ClsStmt Hdr}
    (V : ShdRunVisSpec Lq hL20 prog refused) (v : Fin shdP_zkResPts → Dig) (i : Fin shdP_zkResPts) : Prop :=
  ¬ V.G v ∧ V.isVisibleAt v i

theorem ShdRunVisSpec.hvisG {X Coins Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {prog : X → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)} {refused : ClsStmt Hdr}
    (V : ShdRunVisSpec Lq hL20 prog refused) :
    ∀ v i, V.G v → ¬ V.vis v i :=
  fun _ _ hg hv => hv.1 hg

theorem ShdRunVisSpec.hvis {X Coins Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {prog : X → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)} {refused : ClsStmt Hdr}
    (V : ShdRunVisSpec Lq hL20 prog refused) :
    ∀ x c H v i, V.vis v i →
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i = V.vp (PProg.outOf (prog x c) v) H v i :=
  fun x c H v i hv => V.hvis_ok x c H v i hv.1 hv.2

theorem ShdRunVisSpec.hrefG {X Coins Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {prog : X → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)} {refused : ClsStmt Hdr}
    (V : ShdRunVisSpec Lq hL20 prog refused) :
    ∀ x c v, V.G v → PProg.outOf (prog x c) v = (refused, []) :=
  V.href

end PProgAnatomyAndVis

end ZK60.HonestShield
