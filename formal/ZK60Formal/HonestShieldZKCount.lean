/-
D63 lane L68c, part 3e (`HonestShieldZKCount.lean`):
exact whole-run query, tree, leaf, internal-node, transcript, collision, and hidden-leaf accounting
across all 28 segments (`IN-C`, 26× `Blk`, `OUT-C`) and 112 Merkle trees matching Sol's conservative
`T = 2^20` reserve budget (`HonestShieldZKBase.shdRunErrRes`).

What this file defines and proves (standard Lean foundations `propext`, `Classical.choice`, `Quot.sound` only):
1. **Exact 28-segment & 112-tree accounting (`sum_fin28_piecewise`, `shdP_treeDepth`, `shdP_seg*`,
   `shdP_wholeRun_accounting`)**:
   - Sums over `Fin 28` and `Fin 112` proved in O(1) kernel work (zero concrete 26-block unrolling):
     `112` trees, `L = 5,359,616` salted leaves, `N = 5,359,504` internal nodes, `283,821` main transcript
     `.pt`s + `58` deduped `posTag` `.pt`s = `283,879` transcript `.pt`s, `283,881 ≤ 2^20 = T` total `.tr`-kind
     queries (including the 2 public header `.dep`s), `11,002,999 ≤ 11,767,696 = shdP_zkResPts`, and
     `16,362,617 = shdP_zkQueries`.
2. **Combinatorial freshness, hidden-leaf, collision, and weighted-budget theorems**:
   - `card_dig_eq` (`Fintype.card Dig = 2 ^ 256`), `dvd_512_of_equiv_dig2`, `dvd_512_shdViewCoins`.
   - `exposed2_card` (`2^-512` hit bound for two distinct exposed `v`-coordinates, i.e. Merkle internal nodes).
   - `freshSalt_card`, `uniform_fiber_of_pmf`, `cond_freshSalt_of_indep` (`2^-256` hit bound from uniform salt).
   - `coll_pair_causal_exposed_card`, `coll_pair_diff_exposed_card`, `coll_pair_salt_card`,
     `coll_pair_disjoint_kind_card` (pair-collision bounds for `hKc`).
   - Compositional `PProg.KCount` (`mono`, `andThen`, `toWB`, `merkleTreeProg_kCount`,
     `trAbsorbProg_kCount`, `trSqueezeProg_kCount`, `trChallengeFp2Prog_kCount`, `trSqueezeVecProg_kCount`).
3. **Zero-rounding-loss `shdKf`/`shdKUf` weights and exact `shdRunErrRes` rate discharges**:
   - `shdKf`, `shdKUf`, `shdKm`, `shdKUm`, `shdWp`, `shdWpa`, `shdKc`, with `shdKm_ge`, `shdKUm_ge`, `shdKG`,
     `hKw_of_shdQKind`, `hKc_of_shdPairs`, `hUw_of_hiddenLeaves` (exact `Fintype.card Coins` cancellation),
     `shd_hwb_of_kCount`, `shd_hwba_of_kCount`, and all five ENNReal rate inequalities
     `shd_hrδp`, `shd_hrωp`, `shd_hrεc`, `shd_hrδh`, `shd_hrωh`.
   - `shdRunErrRes_half_cap_85` and `shdRunErrRes_add_rng_le_target`: proves `shdRunErrRes q R ≤ q*2^-129 + R*2^-121`
     for all `R ≤ 2^85`, leaving a full half of `εzkTarget` for `NativeOsRngIndist` transfer.
-/
import ZK60Formal.HonestShieldZKVis

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.ZKW16 ZK60.ZKCount ZK60.ZKLinks ZK60.ZKHonest ZK60.HonestClassify ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

/-! ## 1. Exact 28-segment and 112-tree accounting (O(1) kernel work, zero block unrolling) -/

section WholeRunAccounting

/-- O(1)-kernel sum of a piecewise-constant function over `Fin 28` (`0 ↦ a`, `1..26 ↦ c`, `27 ↦ b`). -/
theorem sum_fin28_piecewise (a b c : ℕ) :
    (∑ s : Fin 28, if s.val = 0 then a else if s.val = 27 then b else c) = a + 26 * c + b := by
  let z0 : Fin 28 := ⟨0, by norm_num⟩
  let z27 : Fin 28 := ⟨27, by norm_num⟩
  have hmem27 : z27 ∈ Finset.univ.erase z0 :=
    Finset.mem_erase.mpr ⟨Fin.ne_of_val_ne (by norm_num), Finset.mem_univ _⟩
  have hsplit1 : (∑ s : Fin 28, if s.val = 0 then a else if s.val = 27 then b else c)
      = a + ∑ s ∈ Finset.univ.erase z0, (if s.val = 0 then a else if s.val = 27 then b else c) := by
    rw [← Finset.add_sum_erase Finset.univ _ (Finset.mem_univ z0)]
    dsimp only [z0]
    rw [ite_eq_left rfl]
  have hsplit2 : ∑ s ∈ Finset.univ.erase z0, (if s.val = 0 then a else if s.val = 27 then b else c)
      = b + ∑ _s ∈ (Finset.univ.erase z0).erase z27, c := by
    rw [← Finset.add_sum_erase (Finset.univ.erase z0) _ hmem27]
    have hb : (if z27.val = 0 then a else if z27.val = 27 then b else c) = b := by
      dsimp only [z27]
      rw [ite_eq_right (by norm_num : (27 : ℕ) ≠ 0), ite_eq_left rfl]
    rw [hb]
    refine congrArg (b + ·) (Finset.sum_congr rfl fun s hs => ?_)
    have h27 : s.val ≠ 27 := fun h => (Finset.mem_erase.mp hs).1 (Fin.ext h)
    have h0 : s.val ≠ 0 := fun h => (Finset.mem_erase.mp (Finset.mem_erase.mp hs).2).1 (Fin.ext h)
    rw [ite_eq_right h0, ite_eq_right h27]
  have hcard : ((Finset.univ.erase z0).erase z27).card = 26 := by
    rw [Finset.card_erase_of_mem hmem27, Finset.card_erase_of_mem (Finset.mem_univ z0),
      Finset.card_univ, Fintype.card_fin]
  rw [hsplit1, hsplit2, Finset.sum_const, smul_eq_mul, hcard]
  omega

/-- Per-segment Merkle tree count (`IN-C`: 5, each `Blk_k`: 4, `OUT-C`: 3). -/
def shdP_segTrees (s : Fin 28) : ℕ :=
  if s.val = 0 then 5 else if s.val = 27 then 3 else 4

/-- Per-segment salted-leaf count (`IN-C`: `2^11 + 2*2^14 + 2^12 + 2^16 = 104,448`,
each `Blk_k`: `3*2^16 + 2^12 = 200,704`, `OUT-C`: `2*2^14 + 2^12 = 36,864`). -/
def shdP_segLeaves (s : Fin 28) : ℕ :=
  if s.val = 0 then 104448 else if s.val = 27 then 36864 else 200704

/-- Per-segment internal-node count (`leaves - trees`: `IN-C`: `104,443`, `Blk_k`: `200,700`, `OUT-C`: `36,861`). -/
def shdP_segNodes (s : Fin 28) : ℕ :=
  if s.val = 0 then 104443 else if s.val = 27 then 36861 else 200700

/-- Per-segment main transcript `.pt` count (`IN-C`: `605`, each `Blk_k`: `10,862`, `OUT-C`: `797`). -/
def shdP_segMainTrPts (s : Fin 28) : ℕ :=
  if s.val = 0 then 605 else if s.val = 27 then 797 else 10862

/-- Per-tree Merkle depth across all 112 trees (`0 ↦ 11`, `1..4 ↦ 14`, `5..83 ↦ 16`, `84..111 ↦ 12`). -/
def shdP_treeDepth (t : Fin 112) : ℕ :=
  if t.val < 1 then 11
  else if t.val < 5 then 14
  else if t.val < 84 then 16
  else 12

private theorem sum_range_const_piecewise (f : ℕ → ℕ) (a b c d : ℕ)
    (h1 : ∀ i, i < 1 → f i = a)
    (h2 : ∀ i, 1 ≤ i → i < 5 → f i = b)
    (h3 : ∀ i, 5 ≤ i → i < 84 → f i = c)
    (h4 : ∀ i, 84 ≤ i → i < 112 → f i = d) :
    ∑ i ∈ Finset.range 112, f i = 1 * a + 4 * b + 79 * c + 28 * d := by
  have hs1 : ∑ i ∈ Finset.range 112, f i = ∑ i ∈ Finset.range 84, f i + ∑ i ∈ Finset.range 28, f (84 + i) :=
    Finset.sum_range_add f 84 28
  have hs2 : ∑ i ∈ Finset.range 84, f i = ∑ i ∈ Finset.range 5, f i + ∑ i ∈ Finset.range 79, f (5 + i) :=
    Finset.sum_range_add f 5 79
  have hs3 : ∑ i ∈ Finset.range 5, f i = ∑ i ∈ Finset.range 1, f i + ∑ i ∈ Finset.range 4, f (1 + i) :=
    Finset.sum_range_add f 1 4
  have hc1 : ∑ i ∈ Finset.range 1, f i = 1 * a := by
    rw [Finset.sum_congr rfl fun i hi => h1 i (Finset.mem_range.mp hi), Finset.sum_const, Finset.card_range, smul_eq_mul]
  have hc2 : ∑ i ∈ Finset.range 4, f (1 + i) = 4 * b := by
    rw [Finset.sum_congr rfl fun i hi => h2 (1 + i) (by omega) (by have := Finset.mem_range.mp hi; omega),
      Finset.sum_const, Finset.card_range, smul_eq_mul]
  have hc3 : ∑ i ∈ Finset.range 79, f (5 + i) = 79 * c := by
    rw [Finset.sum_congr rfl fun i hi => h3 (5 + i) (by omega) (by have := Finset.mem_range.mp hi; omega),
      Finset.sum_const, Finset.card_range, smul_eq_mul]
  have hc4 : ∑ i ∈ Finset.range 28, f (84 + i) = 28 * d := by
    rw [Finset.sum_congr rfl fun i hi => h4 (84 + i) (by omega) (by have := Finset.mem_range.mp hi; omega),
      Finset.sum_const, Finset.card_range, smul_eq_mul]
  rw [hs1, hs2, hs3, hc1, hc2, hc3, hc4]

/-- Exact 112-tree leaf sum `∑_{t : Fin 112} 2 ^ depth(t) = shdP_zkLeaves = 5,359,616`. -/
theorem sum_fin112_leaves : ∑ t : Fin 112, 2 ^ shdP_treeDepth t = shdP_zkLeaves := by
  let g : ℕ → ℕ := fun i =>
    2 ^ (if i < 1 then 11 else if i < 5 then 14 else if i < 84 then 16 else 12)
  have heq : ∑ t : Fin 112, 2 ^ shdP_treeDepth t = ∑ i ∈ Finset.range 112, g i :=
    Fin.sum_univ_eq_sum_range g 112
  rw [heq, sum_range_const_piecewise g (2 ^ 11) (2 ^ 14) (2 ^ 16) (2 ^ 12)
    (fun i hi => by dsimp only [g]; rw [ite_eq_left hi])
    (fun i h1 h2 => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_left h2])
    (fun i h1 h2 => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_right (by omega : ¬ i < 5), ite_eq_left h2])
    (fun i h1 _ => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_right (by omega : ¬ i < 5),
      ite_eq_right (by omega : ¬ i < 84)])]
  rw [shdP_zkProg_counts.2.1]; norm_num

/-- Exact 112-tree internal-node sum `∑_{t : Fin 112} (2 ^ depth(t) - 1) = shdP_zkNodes = 5,359,504`. -/
theorem sum_fin112_nodes : ∑ t : Fin 112, (2 ^ shdP_treeDepth t - 1) = shdP_zkNodes := by
  let g : ℕ → ℕ := fun i =>
    2 ^ (if i < 1 then 11 else if i < 5 then 14 else if i < 84 then 16 else 12) - 1
  have heq : ∑ t : Fin 112, (2 ^ shdP_treeDepth t - 1) = ∑ i ∈ Finset.range 112, g i :=
    Fin.sum_univ_eq_sum_range g 112
  rw [heq, sum_range_const_piecewise g (2 ^ 11 - 1) (2 ^ 14 - 1) (2 ^ 16 - 1) (2 ^ 12 - 1)
    (fun i hi => by dsimp only [g]; rw [ite_eq_left hi])
    (fun i h1 h2 => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_left h2])
    (fun i h1 h2 => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_right (by omega : ¬ i < 5), ite_eq_left h2])
    (fun i h1 _ => by dsimp only [g]; rw [ite_eq_right (by omega : ¬ i < 1), ite_eq_right (by omega : ¬ i < 5),
      ite_eq_right (by omega : ¬ i < 84)])]
  rw [shdP_zkProg_counts.2.2.1]; norm_num

/-- **Exact whole-run 28-segment & 112-tree accounting theorem**:
verifies every per-segment sum against `shdP_zkProg_counts` and Sol's `T = 2^20` conservative reserve
(including both public header `.dep` queries inside `T`). -/
theorem shdP_wholeRun_accounting :
    (∑ s : Fin 28, shdP_segTrees s = shdP_zkTrees_total)
    ∧ (∑ s : Fin 28, shdP_segLeaves s = shdP_zkLeaves)
    ∧ (∑ s : Fin 28, shdP_segNodes s = shdP_zkNodes)
    ∧ (7 + ∑ s : Fin 28, shdP_segMainTrPts s = shdP_zkMainTrPts)
    ∧ (∑ _b : Fin 29, (2 : ℕ) = shdP_zkPosTagPts)
    ∧ (2 + shdP_zkTrPts = 283881)
    ∧ (2 + shdP_zkTrPts ≤ shdP_zkResT)
    ∧ (shdP_zkResT + shdP_zkLeaves + shdP_zkNodes = 11767696)
    ∧ (shdP_zkLeaves + shdP_zkNodes + shdP_zkTrPts ≤ shdP_zkResPts) := by
  obtain ⟨hT0, hL0, hN0, hM0, hP0, hTr0, -, -, -, hRes0, -, -, -⟩ := shdP_zkProg_counts
  have hResT : shdP_zkResT = 1048576 := by unfold shdP_zkResT; norm_num
  have hT := sum_fin28_piecewise 5 3 4
  have hL := sum_fin28_piecewise 104448 36864 200704
  have hN := sum_fin28_piecewise 104443 36861 200700
  have hM := sum_fin28_piecewise 605 797 10862
  have hP : ∑ _b : Fin 29, (2 : ℕ) = 58 := by simp
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · change (∑ s : Fin 28, if s.val = 0 then 5 else if s.val = 27 then 3 else 4) = shdP_zkTrees_total
    rw [hT, hT0]
  · change (∑ s : Fin 28, if s.val = 0 then 104448 else if s.val = 27 then 36864 else 200704) = shdP_zkLeaves
    rw [hL, hL0]
  · change (∑ s : Fin 28, if s.val = 0 then 104443 else if s.val = 27 then 36861 else 200700) = shdP_zkNodes
    rw [hN, hN0]
  · change 7 + (∑ s : Fin 28, if s.val = 0 then 605 else if s.val = 27 then 797 else 10862) = shdP_zkMainTrPts
    rw [hM, hM0]
  · rw [hP, hP0]
  · rw [hTr0]
  · rw [hTr0, hResT]; norm_num
  · rw [hResT, hL0, hN0]
  · rw [hL0, hN0, hTr0, hRes0]; norm_num

end WholeRunAccounting

/-! ## 2. Combinatorial freshness, hidden-leaf, pair-collision, and `KCount → WB` theorems -/

section CombinatorialCounting

/-- Exact digest cardinality `|Dig| = 2^256`. -/
theorem card_dig_eq : Fintype.card Dig = 2 ^ 256 := by
  rw [ZK60.Exec.card_dig, Fintype.card_prod, Fintype.card_fin, ← pow_add]

/-- Any coin space factoring off two independent `Dig` salt coordinates has `2^512 ∣ |Coins|`. -/
theorem dvd_512_of_equiv_dig2 {Coins Rest : Type} [Fintype Coins] [Fintype Rest]
    (e : Coins ≃ Rest × Dig × Dig) : 2 ^ 512 ∣ Fintype.card Coins := by
  rw [Fintype.card_congr e, Fintype.card_prod, Fintype.card_prod, card_dig_eq]
  refine ⟨Fintype.card Rest, ?_⟩
  rw [← pow_add, Nat.mul_comm]

/-- Parametric `2^512` divisibility for any two-level `ShdViewCoins` whose `TE` salt space is divisible by `2^512`. -/
theorem dvd_512_shdViewCoins_gen (F K : Type) [Fintype F] [Fintype K] (L1 : ShdL1Spec) (L2 : ShdL2Spec)
    (hsalt : 2 ^ 512 ∣ Fintype.card L1.te.Salt) :
    2 ^ 512 ∣ Fintype.card (ShdViewCoins F K L1 L2) := by
  have hte : 2 ^ 512 ∣ Fintype.card (PcsStdCoins F L1.te) := by
    rw [Fintype.card_prod]
    exact dvd_mul_of_dvd_right hsalt _
  have hl1 : 2 ^ 512 ∣ Fintype.card (ShdL1Coins F L1) := by
    rw [Fintype.card_prod]
    exact dvd_mul_of_dvd_left hte _
  rw [Fintype.card_prod]
  exact dvd_mul_of_dvd_left hl1 _

/-- The concrete two-level Shieldstral view-coin space satisfies `2^512 ∣ |ShdViewCoins|`. -/
theorem dvd_512_shdViewCoins :
    2 ^ 512 ∣ Fintype.card (ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec) := by
  refine dvd_512_shdViewCoins_gen GF shdP_K shdP_L1Spec shdP_L2Spec ?_
  have he : shdP_L1Spec.te.Salt ≃ (Fin (2 ^ 11) → Dig) :=
    { toFun := id, invFun := id, left_inv := fun _ => rfl, right_inv := fun _ => rfl }
  rw [Fintype.card_congr he, Fintype.card_fun, Fintype.card_fin, card_dig_eq, ← pow_mul]
  exact pow_dvd_pow 2 (show 512 ≤ 256 * 2 ^ 11 by norm_num)

/-- **512-bit freshness (`exposed2_card`)**: a point exposing two DISTINCT `v`-coordinates `(v j₁, v j₂)`
(such as every bottom-up Merkle internal node) equals a given query `z` for at most `|C × D^k| / |D|^2` pairs. -/
theorem exposed2_card {C D Q : Type} [Fintype C] [Fintype D] [DecidableEq Q] {k : ℕ}
    (P : C × (Fin k → D) → Q) (j₁ j₂ : Fin k) (hj : j₁ ≠ j₂) (g₁ g₂ : Q → D)
    (hg₁ : ∀ s, g₁ (P s) = s.2 j₁) (hg₂ : ∀ s, g₂ (P s) = s.2 j₂) (z : Q) :
    (Fintype.card D * Fintype.card D) * (univ.filter (fun s : C × (Fin k → D) => P s = z)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  have hfib1 : ∀ s ∈ univ.filter (fun s : C × (Fin k → D) => P s = z), s.2 j₁ = g₁ z := by
    intro s hs; rw [← hg₁ s, (mem_filter.mp hs).2]
  have hfib2 : ∀ s ∈ univ.filter (fun s : C × (Fin k → D) => P s = z), s.2 j₂ = g₂ z := by
    intro s hs; rw [← hg₂ s, (mem_filter.mp hs).2]
  have hcard : (((univ : Finset (D × D)) ×ˢ univ.filter (fun s : C × (Fin k → D) => P s = z)).card)
      ≤ (univ : Finset (C × (Fin k → D))).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : (D × D) × (C × (Fin k → D)) => (p.2.1, Function.update (Function.update p.2.2 j₁ p.1.1) j₂ p.1.2))
      (fun _ _ => mem_univ _) ?_
    intro p hp p' hp' heq
    have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
    have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
    have h1 : p.2.1 = p'.2.1 := (Prod.mk.inj heq).1
    have h2 : Function.update (Function.update p.2.2 j₁ p.1.1) j₂ p.1.2
        = Function.update (Function.update p'.2.2 j₁ p'.1.1) j₂ p'.1.2 := (Prod.mk.inj heq).2
    have hd2 : p.1.2 = p'.1.2 := by
      have h := congrFun h2 j₂
      rwa [Function.update_self, Function.update_self] at h
    have hd1 : p.1.1 = p'.1.1 := by
      have h := congrFun h2 j₁
      rwa [Function.update_of_ne hj, Function.update_of_ne hj, Function.update_self, Function.update_self] at h
    have hv : p.2.2 = p'.2.2 := by
      funext i
      by_cases hi2 : i = j₂
      · rw [hi2, hfib2 p.2 hp2, hfib2 p'.2 hp2']
      · by_cases hi1 : i = j₁
        · rw [hi1, hfib1 p.2 hp2, hfib1 p'.2 hp2']
        · have h := congrFun h2 i
          rwa [Function.update_of_ne hi2, Function.update_of_ne hi2,
            Function.update_of_ne hi1, Function.update_of_ne hi1] at h
    exact Prod.ext (Prod.ext hd1 hd2) (Prod.ext h1 hv)
  rw [Finset.card_product, Finset.card_univ, Fintype.card_prod, Finset.card_univ] at hcard
  exact hcard

/-- Exact fiber size of a uniform coin coordinate `salt : C → D` whose pushforward is uniform. -/
theorem uniform_fiber_of_pmf {C D : Type} [Fintype C] [Nonempty C] [Fintype D] [Nonempty D] [DecidableEq D]
    (salt : C → D) (hpmf : (PMF.uniformOfFintype C).map salt = PMF.uniformOfFintype D) (d : D) :
    Fintype.card D * (univ.filter (fun c : C => salt c = d)).card = Fintype.card C := by
  have heval := congrArg (fun μ : PMF D => μ d) hpmf
  have hlhs : ((PMF.uniformOfFintype C).map salt) d
      = ((univ.filter (fun c : C => salt c = d)).card : ℝ≥0∞) * (Fintype.card C : ℝ≥0∞)⁻¹ := by
    rw [PMF.map_apply, tsum_fintype]
    trans ∑ a ∈ univ.filter (fun c : C => salt c = d), (Fintype.card C : ℝ≥0∞)⁻¹
    · rw [Finset.sum_filter]
      refine Finset.sum_congr rfl fun a _ => ?_
      by_cases h : salt a = d
      · rw [ite_eq_left h.symm, ite_eq_left h, PMF.uniformOfFintype_apply]
      · rw [ite_eq_right (fun h' => h h'.symm), ite_eq_right h]
    · rw [Finset.sum_const, nsmul_eq_mul]
  rw [hlhs, PMF.uniformOfFintype_apply] at heval
  have hC0 : (Fintype.card C : ℝ≥0∞) ≠ 0 := Nat.cast_ne_zero.mpr (Nat.pos_iff_ne_zero.mp Fintype.card_pos)
  have hD0 : (Fintype.card D : ℝ≥0∞) ≠ 0 := Nat.cast_ne_zero.mpr (Nat.pos_iff_ne_zero.mp Fintype.card_pos)
  have hmul : ((Fintype.card D * (univ.filter (fun c : C => salt c = d)).card : ℕ) : ℝ≥0∞)
      = (Fintype.card C : ℝ≥0∞) := by
    calc ((Fintype.card D * (univ.filter (fun c : C => salt c = d)).card : ℕ) : ℝ≥0∞)
        = (Fintype.card D : ℝ≥0∞) * (((univ.filter (fun c : C => salt c = d)).card : ℝ≥0∞)
            * (Fintype.card C : ℝ≥0∞)⁻¹) * (Fintype.card C : ℝ≥0∞) := by
          rw [Nat.cast_mul]
          calc (Fintype.card D : ℝ≥0∞) * ((univ.filter (fun c : C => salt c = d)).card : ℝ≥0∞)
              = (Fintype.card D : ℝ≥0∞) * ((univ.filter (fun c : C => salt c = d)).card : ℝ≥0∞)
                  * ((Fintype.card C : ℝ≥0∞)⁻¹ * (Fintype.card C : ℝ≥0∞)) := by
                rw [ENNReal.inv_mul_cancel hC0 (ENNReal.natCast_ne_top _), mul_one]
            _ = _ := by ring
      _ = (Fintype.card D : ℝ≥0∞) * (Fintype.card D : ℝ≥0∞)⁻¹ * (Fintype.card C : ℝ≥0∞) := by rw [heval]
      _ = (Fintype.card C : ℝ≥0∞) := by
          rw [ENNReal.mul_inv_cancel hD0 (ENNReal.natCast_ne_top _), one_mul]
  exact_mod_cast hmul

/-- **256-bit freshness from a uniform salt coordinate (`freshSalt_card`)**: any point exposing a uniform
salt `salt : C → D` hits a fixed query `z` for at most `|C × D^k| / |D|` coin-value pairs. -/
theorem freshSalt_card {C D Q : Type} [Fintype C] [Fintype D] [DecidableEq D] [DecidableEq Q] {k : ℕ}
    (P : C × (Fin k → D) → Q) (salt : C → D) (g : Q → D) (hg : ∀ s, g (P s) = salt s.1)
    (hsalt : ∀ d : D, Fintype.card D * (univ.filter (fun c : C => salt c = d)).card ≤ Fintype.card C) (z : Q) :
    Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => P s = z)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  have hsub : univ.filter (fun s : C × (Fin k → D) => P s = z)
      ⊆ (univ.filter (fun c : C => salt c = g z)) ×ˢ (univ : Finset (Fin k → D)) := by
    intro s hs
    refine Finset.mem_product.mpr ⟨Finset.mem_filter.mpr ⟨mem_univ _, ?_⟩, mem_univ _⟩
    rw [← hg s, (mem_filter.mp hs).2]
  calc Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => P s = z)).card
      ≤ Fintype.card D * ((univ.filter (fun c : C => salt c = g z)) ×ˢ (univ : Finset (Fin k → D))).card :=
        Nat.mul_le_mul_left _ (Finset.card_le_card hsub)
    _ = (Fintype.card D * (univ.filter (fun c : C => salt c = g z)).card) * Fintype.card (Fin k → D) := by
        rw [Finset.card_product, Finset.card_univ, Nat.mul_assoc]
    _ ≤ Fintype.card C * Fintype.card (Fin k → D) := Nat.mul_le_mul_right _ (hsalt (g z))
    _ = Fintype.card (C × (Fin k → D)) := (Fintype.card_prod _ _).symm

open Classical in
/-- **Conditional 256-bit freshness of an unopened leaf salt (`cond_freshSalt_of_indep`)**:
if `Coins ≃ Rest × D` where the output `out` depends only on `Rest` and point `pts` exposes the `D` coordinate,
then conditioned on any fixed output `o`, `pts c = z` holds for at most `1/|D|` of the coins yielding `o`. -/
theorem cond_freshSalt_of_indep {Coins Rest D Q Out : Type} [Fintype Coins] [Fintype Rest] [Fintype D]
    [DecidableEq Q]
    (e : Coins ≃ Rest × D) (out : Coins → Out) (outR : Rest → Out) (hout : ∀ c, out c = outR (e c).1)
    (pts : Coins → Q) (g : Q → D) (hg : ∀ c, g (pts c) = (e c).2) (o : Out) (z : Q) :
    Fintype.card D * (univ.filter (fun c : Coins => out c = o ∧ pts c = z)).card
      ≤ (univ.filter (fun c : Coins => out c = o)).card := by
  have hcard : ((univ : Finset D) ×ˢ univ.filter (fun c : Coins => out c = o ∧ pts c = z)).card
      ≤ (univ.filter (fun c : Coins => out c = o)).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : D × Coins => e.symm ((e p.2).1, p.1))
      (fun p hp => ?_) ?_
    · have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
      have ho : out p.2 = o := (Finset.mem_filter.mp hp2).2.1
      refine Finset.mem_coe.mpr (Finset.mem_filter.mpr ⟨mem_univ _, ?_⟩)
      rw [hout, e.apply_symm_apply]
      rwa [hout] at ho
    · intro p hp p' hp' heq
      have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
      have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
      have hpair : ((e p.2).1, p.1) = ((e p'.2).1, p'.1) := e.symm.injective heq
      have hr : (e p.2).1 = (e p'.2).1 := (Prod.mk.inj hpair).1
      have hd : p.1 = p'.1 := (Prod.mk.inj hpair).2
      have hs : (e p.2).2 = (e p'.2).2 := by
        rw [← hg p.2, ← hg p'.2, (Finset.mem_filter.mp hp2).2.2, (Finset.mem_filter.mp hp2').2.2]
      have hc : p.2 = p'.2 := e.injective (Prod.ext hr hs)
      exact Prod.ext hd hc
  rwa [Finset.card_product, Finset.card_univ] at hcard

/-! ### Pair-collision counting lemmas for `hKc` -/

/-- **Causal exposed pair collision (`2^-256`)**: if `pts` is causal and `pts s j` exposes `v m` with `i ≤ m`,
then `pts s i = pts s j` holds for at most `1/|D|` of `(c, v)`. -/
theorem coll_pair_causal_exposed_card {C D Q : Type} [Fintype C] [Fintype D] [DecidableEq Q] {k : ℕ}
    (pts : C → (Fin k → D) → Fin k → Q) (hcausal : ∀ c, Causal (pts c))
    {i j m : Fin k} (him : i.val ≤ m.val) (g : Q → D) (hg : ∀ c v, g (pts c v j) = v m) :
    Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => pts s.1 s.2 i = pts s.1 s.2 j)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  have hcard : ((univ : Finset D) ×ˢ univ.filter (fun s : C × (Fin k → D) => pts s.1 s.2 i = pts s.1 s.2 j)).card
      ≤ (univ : Finset (C × (Fin k → D))).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : D × (C × (Fin k → D)) => (p.2.1, Function.update p.2.2 m p.1))
      (fun _ _ => mem_univ _) ?_
    intro p hp p' hp' heq
    have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
    have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
    have hc : p.2.1 = p'.2.1 := (Prod.mk.inj heq).1
    have hu : Function.update p.2.2 m p.1 = Function.update p'.2.2 m p'.1 := (Prod.mk.inj heq).2
    have hd : p.1 = p'.1 := by
      have h := congrFun hu m; rwa [Function.update_self, Function.update_self] at h
    have hne : ∀ r : Fin k, r ≠ m → p.2.2 r = p'.2.2 r := by
      intro r hr; have h := congrFun hu r; rwa [Function.update_of_ne hr, Function.update_of_ne hr] at h
    have hpt_i : pts p.2.1 p.2.2 i = pts p'.2.1 p'.2.2 i := by
      rw [hc]
      refine hcausal p'.2.1 p.2.2 p'.2.2 i fun r hr => hne r fun hrm => ?_
      have hr' : r.val < i.val := hr
      have : r.val = m.val := congrArg Fin.val hrm; omega
    have hm : p.2.2 m = p'.2.2 m := by
      rw [← hg p.2.1 p.2.2, ← (Finset.mem_filter.mp hp2).2, hpt_i, (Finset.mem_filter.mp hp2').2, hg p'.2.1 p'.2.2]
    have hv : p.2.2 = p'.2.2 := by
      funext r
      by_cases hr : r = m
      · rw [hr, hm]
      · exact hne r hr
    exact Prod.ext hd (Prod.ext hc hv)
  rwa [Finset.card_product, Finset.card_univ, Finset.card_univ] at hcard

/-- **Distinct-coordinate exposed pair collision (`2^-256`)**: if `pts s i` exposes `v m₁` and `pts s j` exposes
`v m₂` with `m₁ ≠ m₂` (e.g. two Merkle internal nodes with distinct left-child offsets), then `pts s i = pts s j`
holds for at most `1/|D|` of `(c, v)`. -/
theorem coll_pair_diff_exposed_card {C D Q : Type} [Fintype C] [Fintype D] [DecidableEq Q] {k : ℕ}
    (pts : C × (Fin k → D) → Fin k → Q) {i j m₁ m₂ : Fin k} (hm : m₁ ≠ m₂)
    (g : Q → D) (hg₁ : ∀ s, g (pts s i) = s.2 m₁) (hg₂ : ∀ s, g (pts s j) = s.2 m₂) :
    Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => pts s i = pts s j)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  have hcard : ((univ : Finset D) ×ˢ univ.filter (fun s : C × (Fin k → D) => pts s i = pts s j)).card
      ≤ (univ : Finset (C × (Fin k → D))).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : D × (C × (Fin k → D)) => (p.2.1, Function.update p.2.2 m₂ p.1))
      (fun _ _ => mem_univ _) ?_
    intro p hp p' hp' heq
    have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
    have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
    have hc : p.2.1 = p'.2.1 := (Prod.mk.inj heq).1
    have hu : Function.update p.2.2 m₂ p.1 = Function.update p'.2.2 m₂ p'.1 := (Prod.mk.inj heq).2
    have hd : p.1 = p'.1 := by
      have h := congrFun hu m₂; rwa [Function.update_self, Function.update_self] at h
    have hne : ∀ r : Fin k, r ≠ m₂ → p.2.2 r = p'.2.2 r := by
      intro r hr; have h := congrFun hu r; rwa [Function.update_of_ne hr, Function.update_of_ne hr] at h
    have hm1 : p.2.2 m₁ = p'.2.2 m₁ := hne m₁ hm
    have hm2 : p.2.2 m₂ = p'.2.2 m₂ := by
      have h1 : p.2.2 m₁ = p.2.2 m₂ := by rw [← hg₁ p.2, ← hg₂ p.2, (Finset.mem_filter.mp hp2).2]
      have h2 : p'.2.2 m₁ = p'.2.2 m₂ := by rw [← hg₁ p'.2, ← hg₂ p'.2, (Finset.mem_filter.mp hp2').2]
      rw [← h1, ← h2, hm1]
    have hv : p.2.2 = p'.2.2 := by
      funext r
      by_cases hr : r = m₂
      · rw [hr, hm2]
      · exact hne r hr
    exact Prod.ext hd (Prod.ext hc hv)
  rwa [Finset.card_product, Finset.card_univ, Finset.card_univ] at hcard

/-- **Independent-salt pair collision (`2^-256`)**: if two distinct salted leaves expose two independent
uniform coin coordinates `(e c).2.1` and `(e c).2.2` under `e : C ≃ Rest × D × D`, they collide for at most
`1/|D|` of `(c, v)`. -/
theorem coll_pair_salt_card {C Rest D Q : Type} [Fintype C] [Fintype Rest] [Fintype D] [DecidableEq Q] {k : ℕ}
    (e : C ≃ Rest × D × D) (pts : C × (Fin k → D) → Fin k → Q) {i j : Fin k}
    (g : Q → D) (hg₁ : ∀ s, g (pts s i) = (e s.1).2.1) (hg₂ : ∀ s, g (pts s j) = (e s.1).2.2) :
    Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => pts s i = pts s j)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  have hcard : ((univ : Finset D) ×ˢ univ.filter (fun s : C × (Fin k → D) => pts s i = pts s j)).card
      ≤ (univ : Finset (C × (Fin k → D))).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : D × (C × (Fin k → D)) => (e.symm ((e p.2.1).1, (e p.2.1).2.1, p.1), p.2.2))
      (fun _ _ => mem_univ _) ?_
    intro p hp p' hp' heq
    have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
    have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
    have hv : p.2.2 = p'.2.2 := (Prod.mk.inj heq).2
    have hpair : ((e p.2.1).1, (e p.2.1).2.1, p.1) = ((e p'.2.1).1, (e p'.2.1).2.1, p'.1) :=
      e.symm.injective (Prod.mk.inj heq).1
    have hr : (e p.2.1).1 = (e p'.2.1).1 := (Prod.mk.inj hpair).1
    have hs1 : (e p.2.1).2.1 = (e p'.2.1).2.1 := (Prod.mk.inj (Prod.mk.inj hpair).2).1
    have hd : p.1 = p'.1 := (Prod.mk.inj (Prod.mk.inj hpair).2).2
    have hs2 : (e p.2.1).2.2 = (e p'.2.1).2.2 := by
      have h1 : (e p.2.1).2.1 = (e p.2.1).2.2 := by rw [← hg₁ p.2, ← hg₂ p.2, (Finset.mem_filter.mp hp2).2]
      have h2 : (e p'.2.1).2.1 = (e p'.2.1).2.2 := by rw [← hg₁ p'.2, ← hg₂ p'.2, (Finset.mem_filter.mp hp2').2]
      rw [← h1, ← h2, hs1]
    have hc : p.2.1 = p'.2.1 := e.injective (Prod.ext hr (Prod.ext hs1 hs2))
    exact Prod.ext hd (Prod.ext hc hv)
  rwa [Finset.card_product, Finset.card_univ, Finset.card_univ] at hcard

/-- Points of distinct `ShdQKind` never collide (`0` collisions). -/
theorem coll_pair_disjoint_kind_card {Ω : Type} [Fintype Ω] {Lq k : ℕ} (tag : MTag) (key : Option Dig)
    (pts : Ω → Fin k → QB Lq) {i j : Fin k}
    (hne : ∀ s, shdQKind tag key (pts s i) ≠ shdQKind tag key (pts s j)) :
    (univ.filter (fun s : Ω => pts s i = pts s j)).card = 0 := by
  refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ heq => ?_)
  exact hne s (congrArg (shdQKind tag key) heq)

/-! ### Compositional per-kind query counter (`PProg.KCount`) → weighted budget (`WB`) -/

end CombinatorialCounting

end ZK60.HonestShield

namespace ZK60.ZKHonest

open Finset ZK60 ZK60.Exec ZK60.ZKCount ZK60.HonestShield

/-- Compositional per-kind query budget `(nT, nL, nN)` on a `PProg`: counts `.tr`, `.leaf`, and `.node` queries
on every path while charging `.dep` (`colDigest`) queries `0`. -/
def PProg.KCount {Lq : ℕ} {α : Type} (tag : MTag) (key : Option Dig) :
    PProg (QB Lq) Dig α → ℕ → ℕ → ℕ → Prop
  | .ret _, _, _, _ => True
  | .dep z k, nT, nL, nN =>
    match shdQKind tag key z with
    | .tr   => 0 < nT ∧ ∀ d, PProg.KCount tag key (k d) (nT - 1) nL nN
    | .leaf => 0 < nL ∧ ∀ d, PProg.KCount tag key (k d) nT (nL - 1) nN
    | .node => 0 < nN ∧ ∀ d, PProg.KCount tag key (k d) nT nL (nN - 1)
    | .dep  => ∀ d, PProg.KCount tag key (k d) nT nL nN
  | .pt z k, nT, nL, nN =>
    match shdQKind tag key z with
    | .tr   => 0 < nT ∧ ∀ d, PProg.KCount tag key (k d) (nT - 1) nL nN
    | .leaf => 0 < nL ∧ ∀ d, PProg.KCount tag key (k d) nT (nL - 1) nN
    | .node => 0 < nN ∧ ∀ d, PProg.KCount tag key (k d) nT nL (nN - 1)
    | .dep  => ∀ d, PProg.KCount tag key (k d) nT nL nN

theorem PProg.KCount.mono {Lq : ℕ} {α : Type} {tag : MTag} {key : Option Dig} :
    ∀ {p : PProg (QB Lq) Dig α} {aT aL aN bT bL bN : ℕ},
      p.KCount tag key aT aL aN → aT ≤ bT → aL ≤ bL → aN ≤ bN → p.KCount tag key bT bL bN
  | .ret _, _, _, _, _, _, _, _, _, _, _ => trivial
  | .dep z k, aT, aL, aN, bT, bL, bN, hp, hT, hL, hN => by
    unfold PProg.KCount at hp ⊢
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · exact ⟨lt_of_lt_of_le hp.1 hT, fun d => PProg.KCount.mono (hp.2 d) (by omega) hL hN⟩
    · exact ⟨lt_of_lt_of_le hp.1 hL, fun d => PProg.KCount.mono (hp.2 d) hT (by omega) hN⟩
    · exact ⟨lt_of_lt_of_le hp.1 hN, fun d => PProg.KCount.mono (hp.2 d) hT hL (by omega)⟩
    · exact fun d => PProg.KCount.mono (hp d) hT hL hN
  | .pt z k, aT, aL, aN, bT, bL, bN, hp, hT, hL, hN => by
    unfold PProg.KCount at hp ⊢
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · exact ⟨lt_of_lt_of_le hp.1 hT, fun d => PProg.KCount.mono (hp.2 d) (by omega) hL hN⟩
    · exact ⟨lt_of_lt_of_le hp.1 hL, fun d => PProg.KCount.mono (hp.2 d) hT (by omega) hN⟩
    · exact ⟨lt_of_lt_of_le hp.1 hN, fun d => PProg.KCount.mono (hp.2 d) hT hL (by omega)⟩
    · exact fun d => PProg.KCount.mono (hp d) hT hL hN

theorem PProg.KCount.andThen {Lq : ℕ} {α β : Type} {tag : MTag} {key : Option Dig} :
    ∀ {p : PProg (QB Lq) Dig α} {f : α → PProg (QB Lq) Dig β} {aT aL aN bT bL bN : ℕ},
      p.KCount tag key aT aL aN → (∀ a, (f a).KCount tag key bT bL bN) →
      (p.andThen f).KCount tag key (aT + bT) (aL + bL) (aN + bN)
  | .ret a, f, aT, aL, aN, bT, bL, bN, _, hf =>
    (hf a).mono (Nat.le_add_left bT aT) (Nat.le_add_left bL aL) (Nat.le_add_left bN aN)
  | .dep z k, f, aT, aL, aN, bT, bL, bN, hp, hf => by
    unfold PProg.andThen
    unfold PProg.KCount at hp ⊢
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono (by have := hp.1; omega) le_rfl le_rfl⟩
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono le_rfl (by have := hp.1; omega) le_rfl⟩
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono le_rfl le_rfl (by have := hp.1; omega)⟩
    · exact fun d => (hp d).andThen hf
  | .pt z k, f, aT, aL, aN, bT, bL, bN, hp, hf => by
    unfold PProg.andThen
    unfold PProg.KCount at hp ⊢
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono (by have := hp.1; omega) le_rfl le_rfl⟩
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono le_rfl (by have := hp.1; omega) le_rfl⟩
    · exact ⟨by have := hp.1; omega, fun d =>
        ((hp.2 d).andThen hf).mono le_rfl le_rfl (by have := hp.1; omega)⟩
    · exact fun d => (hp d).andThen hf

theorem PProg.KCount.andThen_ret {Lq : ℕ} {α β : Type} {tag : MTag} {key : Option Dig}
    {p : PProg (QB Lq) Dig α} {g : α → β} {nT nL nN : ℕ}
    (hp : p.KCount tag key nT nL nN) :
    (p.andThen fun a => .ret (g a)).KCount tag key nT nL nN :=
  (hp.andThen (f := fun a => .ret (g a)) (bT := 0) (bL := 0) (bN := 0) fun _ => trivial).mono
    (Nat.add_zero nT).le (Nat.add_zero nL).le (Nat.add_zero nN).le

/-- **Convert `PProg.KCount` directly to `ZKCount.WB`**: any weight function respecting the 4-way
`shdQKind` partition (`0` on `.dep`) satisfies `WB wt p.oc (nT * wT + nL * wL + nN * wN)`. -/
theorem PProg.KCount.toWB {Lq : ℕ} {α : Type} {tag : MTag} {key : Option Dig}
    {wt : QB Lq → ℕ} {wT wL wN : ℕ}
    (hT : ∀ z, shdQKind tag key z = .tr → wt z ≤ wT)
    (hL : ∀ z, shdQKind tag key z = .leaf → wt z ≤ wL)
    (hN : ∀ z, shdQKind tag key z = .node → wt z ≤ wN)
    (hD : ∀ z, shdQKind tag key z = .dep → wt z = 0) :
    ∀ {p : PProg (QB Lq) Dig α} {nT nL nN : ℕ},
      p.KCount tag key nT nL nN → WB wt p.oc (nT * wT + nL * wL + nN * wN)
  | .ret _, _, _, _, _ => trivial
  | .dep z k, nT, nL, nN, hp => by
    unfold PProg.KCount at hp
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · have hw := hT z hk
      have heq : nT * wT = (nT - 1) * wT + wT := by
        have : nT = (nT - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hL z hk
      have heq : nL * wL = (nL - 1) * wL + wL := by
        have : nL = (nL - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hN z hk
      have heq : nN * wN = (nN - 1) * wN + wN := by
        have : nN = (nN - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hD z hk
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp d)).mono (by omega)⟩
  | .pt z k, nT, nL, nN, hp => by
    unfold PProg.KCount at hp
    cases hk : shdQKind tag key z <;> rw [hk] at hp
    · have hw := hT z hk
      have heq : nT * wT = (nT - 1) * wT + wT := by
        have : nT = (nT - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hL z hk
      have heq : nL * wL = (nL - 1) * wL + wL := by
        have : nL = (nL - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hN z hk
      have heq : nN * wN = (nN - 1) * wN + wN := by
        have : nN = (nN - 1) + 1 := by have := hp.1; omega
        conv_lhs => rw [this, Nat.add_mul, Nat.one_mul]
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp.2 d)).mono (by omega)⟩
    · have hw := hD z hk
      exact ⟨by omega, fun d => (PProg.KCount.toWB hT hL hN hD (hp d)).mono (by omega)⟩

end ZK60.ZKHonest

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.ZKW16 ZK60.ZKCount ZK60.ZKLinks ZK60.ZKHonest ZK60.HonestClassify ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

section CombinatorialCounting

/-- Exact `KCount` for `leafLayerAux`: `0` `.tr`, `n` `.leaf`, `0` `.node` (every `colDigest` `.dep` weighs `0`). -/
theorem leafLayerAux_kCount (Lq : ℕ) (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq),
      (∀ j, (colOf j).length % 8 = 0) → ∀ (saltOf : Fin n → Dig),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).KCount tag key 0 n 0
  | 0, _, _, _, _ => trivial
  | n + 1, colOf, hcol, h8, saltOf => by
    unfold leafLayerAux PProg.KCount
    rw [shdQKind_col hsep (colOf 0) (hcol 0) (h8 0)]
    intro cd
    unfold PProg.KCount
    rw [shdQKind_leaf tag key cd (saltOf 0) (by rw [digPair_length]; exact h64)]
    refine ⟨Nat.zero_lt_succ n, fun leaf => ?_⟩
    have ih := leafLayerAux_kCount Lq h64 hsep n (fun j => colOf j.succ) (fun j => hcol j.succ)
      (fun j => h8 j.succ) (fun j => saltOf j.succ)
    exact ih.andThen_ret (β := Fin (n + 1) → Dig) (g := fun rest => Fin.cons leaf rest)

/-- Exact `KCount` for `nodeLayerAux`: `0` `.tr`, `0` `.leaf`, `m` `.node`. -/
theorem nodeLayerAux_kCount (Lq : ℕ) (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig),
      (nodeLayerAux Lq h64 tag m leftOf rightOf).KCount tag key 0 0 m
  | 0, _, _ => trivial
  | m + 1, leftOf, rightOf => by
    unfold nodeLayerAux PProg.KCount
    rw [shdQKind_node hsep (leftOf 0) (rightOf 0) (by rw [digPair_length]; exact h64)]
    refine ⟨Nat.zero_lt_succ m, fun nd => ?_⟩
    have ih := nodeLayerAux_kCount Lq h64 hsep m (fun i => leftOf i.succ) (fun i => rightOf i.succ)
    exact ih.andThen_ret (β := Fin (m + 1) → Dig) (g := fun rest => Fin.cons nd rest)

/-- Exact `KCount` for `buildLevelsProg`: `0` `.tr`, `0` `.leaf`, `2^d - 1` `.node`. -/
theorem buildLevelsProg_kCount (Lq : ℕ) (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) :
    ∀ (d : ℕ) (lv : Fin (2 ^ d) → Dig),
      (buildLevelsProg Lq h64 tag d lv).KCount tag key 0 0 (2 ^ d - 1)
  | 0, _ => trivial
  | d + 1, lv => by
    unfold buildLevelsProg
    have h1 : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    exact ((nodeLayerAux_kCount Lq h64 hsep (2 ^ d) _ _).andThen fun parent =>
      (buildLevelsProg_kCount Lq h64 hsep d parent).andThen_ret (g := fun up => MerkleLevels.layer lv up)).mono
        (bT := 0) (bL := 0) (bN := 2 ^ (d + 1) - 1) le_rfl le_rfl (by omega)

/-- **Exact `KCount` for `merkleTreeProg`**: `0` `.tr`, `2^d` `.leaf`, `2^d - 1` `.node` (all `2^d` `.dep` `colDigest`
queries weigh `0`). -/
theorem merkleTreeProg_kCount (Lq : ℕ) (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (d : ℕ) (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
    (h8 : ∀ j, (colOf j).length % 8 = 0) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).KCount tag key 0 (2 ^ d) (2 ^ d - 1) :=
  ((leafLayerAux_kCount Lq h64 hsep (2 ^ d) colOf hcol h8 saltOf).andThen
    (buildLevelsProg_kCount Lq h64 hsep d)).mono (by omega) (by omega) (by omega)

/-- Exact `KCount` for `trAbsorbProg` (`1` `.tr` query when `t.key = key`). -/
theorem trAbsorbProg_kCount (Lq : ℕ) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (t : Tr) (ht : t.key = key) (label data : List UInt8) :
    (trAbsorbProg Lq t label data).KCount tag key 1 0 0 := by
  unfold trAbsorbProg
  by_cases hlen : (absorbMsg t.state label data).length ≤ Lq
  · rw [dite_eq_left hlen]
    unfold PProg.KCount
    rw [ht, shdQKind_key hsep _ hlen]
    exact ⟨Nat.zero_lt_one, fun _ => trivial⟩
  · rw [dite_eq_right hlen]; trivial

/-- Exact `KCount` for `trSqueezeProg` (`1` `.tr` query when `t.key = key`). -/
theorem trSqueezeProg_kCount (Lq : ℕ) (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (t : Tr) (ht : t.key = key) :
    (trSqueezeProg Lq h47 t).KCount tag key 1 0 0 := by
  unfold trSqueezeProg PProg.KCount
  rw [ht, shdQKind_key hsep _ (by rw [squeezeMsg_length]; exact h47)]
  exact ⟨Nat.zero_lt_one, fun _ => trivial⟩

/-- Exact `KCount` for `trChallengeFp2Prog` (`1` `.tr` query when `t.key = key`). -/
theorem trChallengeFp2Prog_kCount (Lq : ℕ) (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (t : Tr) (ht : t.key = key) :
    (trChallengeFp2Prog Lq h47 t).KCount tag key 1 0 0 :=
  (trSqueezeProg_kCount Lq h47 hsep t ht).andThen_ret

/-- Exact `KCount` for `trSqueezeVecProg` (`n` `.tr` queries when `t.key = key`). -/
theorem trSqueezeVecProg_kCount (Lq : ℕ) (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) :
    ∀ (n : ℕ) (t : Tr), t.key = key → (trSqueezeVecProg Lq h47 n t).KCount tag key n 0 0
  | 0, _, _ => trivial
  | n + 1, t, ht => by
    change (PProg.pt (t.key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact h47⟩) fun dg =>
      (trSqueezeVecProg Lq h47 n { t with state := dg, counter := t.counter + 1 }).andThen fun rs =>
        .ret (dg :: rs.1, rs.2)).KCount tag key (n + 1) 0 0
    unfold PProg.KCount
    rw [ht, shdQKind_key hsep _ (by rw [squeezeMsg_length]; exact h47)]
    refine ⟨Nat.zero_lt_succ n, fun dg => ?_⟩
    have ih := trSqueezeVecProg_kCount Lq h47 hsep n { state := dg, counter := t.counter + 1, key := key } rfl
    exact ih.andThen_ret (g := fun rs => (dg :: rs.1, rs.2))

end CombinatorialCounting

/-! ## 3. Zero-rounding-loss `shdKf`/`shdKUf` weights, `shdRunErrRes` rate discharges, and half-budget cap -/

section ShdRunErrResRates

/-- Exact coin-space factors `|Coins| / 2^512` and `|Coins| / 2^256` (exact under `2^512 ∣ |Coins|`). -/
def shdM512 (Coins : Type) [Fintype Coins] : ℕ := Fintype.card Coins / 2 ^ 512
def shdM256 (Coins : Type) [Fintype Coins] : ℕ := 2 ^ 256 * shdM512 Coins
def shdNV : ℕ := Fintype.card (Fin shdP_zkResPts → Dig)

theorem shdM512_mul (Coins : Type) [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    2 ^ 512 * shdM512 Coins = Fintype.card Coins :=
  Nat.mul_div_cancel' h512

theorem shdM256_mul (Coins : Type) [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    2 ^ 256 * shdM256 Coins = Fintype.card Coins := by
  unfold shdM256
  calc 2 ^ 256 * (2 ^ 256 * shdM512 Coins)
      = 2 ^ 512 * shdM512 Coins := by rw [← Nat.mul_assoc, ← pow_add]
    _ = Fintype.card Coins := shdM512_mul Coins h512

theorem shdM512_pos (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    0 < shdM512 Coins := by
  have hpos : 0 < Fintype.card Coins := Fintype.card_pos
  rw [← shdM512_mul Coins h512] at hpos
  exact Nat.pos_of_mul_pos_left hpos

theorem shdM256_pos (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    0 < shdM256 Coins :=
  Nat.mul_pos (Nat.two_pow_pos 256) (shdM512_pos Coins h512)

theorem shdNV_pos : 0 < shdNV := Fintype.card_pos

/-- Per-query before-request hit weight `shdKf` matching `shdRunErrRes` (`0` on `.dep` `colDigest`). -/
def shdKf (Coins : Type) [Fintype Coins] {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) : ℕ :=
  match shdQKind tag key z with
  | .tr   => shdP_zkResT * shdM256 Coins * shdNV
  | .leaf => shdP_zkLeaves * shdM256 Coins * shdNV
  | .node => shdP_zkNodes * shdM512 Coins * shdNV
  | .dep  => 0

/-- Per-query after-request hit weight `shdKUf` matching `shdRunErrRes` (`0` on `.dep` `colDigest`). -/
def shdKUf (Coins : Type) [Fintype Coins] {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) : ℕ :=
  match shdQKind tag key z with
  | .tr   => shdP_zkResT * shdM256 Coins
  | .leaf => shdP_zkLeaves * shdM256 Coins
  | .node => shdP_zkNodes * shdM512 Coins
  | .dep  => 0

/-- Exact worst-case per-query weights, prover-query weighted budgets, and collision budget for `shdRunErrRes`. -/
def shdKm (Coins : Type) [Fintype Coins] : ℕ :=
  (shdP_zkResT + shdP_zkLeaves) * shdM256 Coins * shdNV + shdP_zkNodes * shdM512 Coins * shdNV

def shdKUm (Coins : Type) [Fintype Coins] : ℕ :=
  (shdP_zkResT + shdP_zkLeaves) * shdM256 Coins + shdP_zkNodes * shdM512 Coins

def shdWp (Coins : Type) [Fintype Coins] : ℕ :=
  (shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves) * shdM256 Coins * shdNV
    + (shdP_zkNodes * shdP_zkNodes) * shdM512 Coins * shdNV

def shdWpa (Coins : Type) [Fintype Coins] : ℕ :=
  (shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves) * shdM256 Coins
    + (shdP_zkNodes * shdP_zkNodes) * shdM512 Coins

def shdKc (Coins : Type) [Fintype Coins] : ℕ :=
  (shdP_zkResPts * shdP_zkResPts) * shdM256 Coins * shdNV

theorem shdKm_ge (Coins : Type) [Fintype Coins] {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) :
    shdKf Coins tag key z ≤ shdKm Coins := by
  unfold shdKf shdKm
  cases shdQKind tag key z <;> dsimp only
  · have h : shdP_zkResT * shdM256 Coins * shdNV ≤ (shdP_zkResT + shdP_zkLeaves) * shdM256 Coins * shdNV :=
      Nat.mul_le_mul_right _ (Nat.mul_le_mul_right _ (Nat.le_add_right _ _))
    exact h.trans (Nat.le_add_right _ _)
  · have h : shdP_zkLeaves * shdM256 Coins * shdNV ≤ (shdP_zkResT + shdP_zkLeaves) * shdM256 Coins * shdNV :=
      Nat.mul_le_mul_right _ (Nat.mul_le_mul_right _ (Nat.le_add_left _ _))
    exact h.trans (Nat.le_add_right _ _)
  · exact Nat.le_add_left _ _
  · exact Nat.zero_le _

theorem shdKUm_ge (Coins : Type) [Fintype Coins] {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) :
    shdKUf Coins tag key z ≤ shdKUm Coins := by
  unfold shdKUf shdKUm
  cases shdQKind tag key z <;> dsimp only
  · exact (Nat.mul_le_mul_right _ (Nat.le_add_right _ _)).trans (Nat.le_add_right _ _)
  · exact (Nat.mul_le_mul_right _ (Nat.le_add_left _ _)).trans (Nat.le_add_right _ _)
  · exact Nat.le_add_left _ _
  · exact Nat.zero_le _

theorem shdKG (Coins : Type) [Fintype Coins] {Lq : ℕ} (tag : MTag) (key : Option Dig) (z : QB Lq) :
    shdKf Coins tag key z ≤ Fintype.card (Fin shdP_zkResPts → Dig) * shdKUf Coins tag key z := by
  unfold shdKf shdKUf shdNV
  cases shdQKind tag key z <;> dsimp only <;> exact le_of_eq (by ring)

/-- Discharge `hwb` for `shdKf` directly from `PProg.KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes`. -/
theorem shd_hwb_of_kCount (Coins : Type) [Fintype Coins] {Lq : ℕ} {α : Type} {tag : MTag} {key : Option Dig}
    {p : PProg (QB Lq) Dig α} (hkc : p.KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes) :
    WB (shdKf Coins tag key) p.oc (shdWp Coins) := by
  have hwb := hkc.toWB (wt := shdKf Coins tag key)
    (wT := shdP_zkResT * shdM256 Coins * shdNV)
    (wL := shdP_zkLeaves * shdM256 Coins * shdNV)
    (wN := shdP_zkNodes * shdM512 Coins * shdNV)
    (fun z hz => by simp [shdKf, hz])
    (fun z hz => by simp [shdKf, hz])
    (fun z hz => by simp [shdKf, hz])
    (fun z hz => by simp [shdKf, hz])
  exact hwb.mono (le_of_eq (by unfold shdWp; ring))

/-- Discharge `hwba` for `shdKUf` directly from `PProg.KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes`. -/
theorem shd_hwba_of_kCount (Coins : Type) [Fintype Coins] {Lq : ℕ} {α : Type} {tag : MTag} {key : Option Dig}
    {p : PProg (QB Lq) Dig α} (hkc : p.KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes) :
    WB (shdKUf Coins tag key) p.oc (shdWpa Coins) := by
  have hwb := hkc.toWB (wt := shdKUf Coins tag key)
    (wT := shdP_zkResT * shdM256 Coins)
    (wL := shdP_zkLeaves * shdM256 Coins)
    (wN := shdP_zkNodes * shdM512 Coins)
    (fun z hz => by simp [shdKUf, hz])
    (fun z hz => by simp [shdKUf, hz])
    (fun z hz => by simp [shdKUf, hz])
    (fun z hz => by simp [shdKUf, hz])
  exact hwb.mono (le_of_eq (by unfold shdWpa; ring))

open Classical in
/-- **Exact `hKw` discharge from per-kind point counts and per-point freshness** (`2^-256` on `.tr`/`.leaf`,
`2^-512` on `.node`, `0` `.dep` points). -/
theorem hKw_of_shdQKind {Coins : Type} [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins)
    {Lq : ℕ} (tag : MTag) (key : Option Dig)
    (pts : Coins × (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → QB Lq)
    (kOf : Fin shdP_zkResPts → ShdQKind)
    (hkind : ∀ s i, shdQKind tag key (pts s i) = kOf i)
    (hcntT : (univ.filter (fun i => kOf i = .tr)).card ≤ shdP_zkResT)
    (hcntL : (univ.filter (fun i => kOf i = .leaf)).card ≤ shdP_zkLeaves)
    (hcntN : (univ.filter (fun i => kOf i = .node)).card ≤ shdP_zkNodes)
    (hcntD : (univ.filter (fun i => kOf i = .dep)).card = 0)
    (hfreshT : ∀ i, kOf i = .tr → ∀ z,
      2 ^ 256 * (univ.filter (fun s => pts s i = z)).card ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig)))
    (hfreshL : ∀ i, kOf i = .leaf → ∀ z,
      2 ^ 256 * (univ.filter (fun s => pts s i = z)).card ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig)))
    (hfreshN : ∀ i, kOf i = .node → ∀ z,
      2 ^ 512 * (univ.filter (fun s => pts s i = z)).card ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig)))
    (z : QB Lq) :
    (univ.filter (fun s => ∃ i, pts s i = z)).card ≤ shdKf Coins tag key z := by
  have hprod256 : Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) = 2 ^ 256 * (shdM256 Coins * shdNV) := by
    rw [Fintype.card_prod, ← shdM256_mul Coins h512, shdNV, Nat.mul_assoc]
  have hprod512 : Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) = 2 ^ 512 * (shdM512 Coins * shdNV) := by
    rw [Fintype.card_prod, ← shdM512_mul Coins h512, shdNV, Nat.mul_assoc]
  let κ : ShdQKind → ℕ := fun
    | .tr   => shdM256 Coins * shdNV
    | .leaf => shdM256 Coins * shdNV
    | .node => shdM512 Coins * shdNV
    | .dep  => 0
  have hκ : ∀ i, (univ.filter (fun s => pts s i = z)).card ≤ κ (kOf i) := by
    intro i
    cases hk : kOf i
    · have h1 : 2 ^ 256 * (univ.filter (fun s => pts s i = z)).card ≤ 2 ^ 256 * (shdM256 Coins * shdNV) := by
        rw [← hprod256]; exact hfreshT i hk z
      exact Nat.le_of_mul_le_mul_left h1 (pow_pos Nat.zero_lt_two 256)
    · have h1 : 2 ^ 256 * (univ.filter (fun s => pts s i = z)).card ≤ 2 ^ 256 * (shdM256 Coins * shdNV) := by
        rw [← hprod256]; exact hfreshL i hk z
      exact Nat.le_of_mul_le_mul_left h1 (pow_pos Nat.zero_lt_two 256)
    · have h1 : 2 ^ 512 * (univ.filter (fun s => pts s i = z)).card ≤ 2 ^ 512 * (shdM512 Coins * shdNV) := by
        rw [← hprod512]; exact hfreshN i hk z
      exact Nat.le_of_mul_le_mul_left h1 (pow_pos Nat.zero_lt_two 512)
    · have hmem : i ∈ univ.filter (fun j => kOf j = .dep) := Finset.mem_filter.mpr ⟨mem_univ _, hk⟩
      have hpos : 0 < (univ.filter (fun j => kOf j = .dep)).card := Finset.card_pos.mpr ⟨i, hmem⟩
      omega
  have hhit := ZKHonest.hit_card_by_label pts (shdQKind tag key) kOf hkind z κ hκ
  refine hhit.trans ?_
  unfold shdKf
  cases shdQKind tag key z <;> dsimp only [κ]
  · rw [Nat.mul_assoc]; exact Nat.mul_le_mul_right _ hcntT
  · rw [Nat.mul_assoc]; exact Nat.mul_le_mul_right _ hcntL
  · rw [Nat.mul_assoc]; exact Nat.mul_le_mul_right _ hcntN
  · rw [hcntD, Nat.zero_mul]

open Classical in
/-- **Exact `hKc` discharge from pairwise `2^-256` collision bounds and per-point `2^-256` dep-hit bounds**. -/
theorem hKc_of_shdPairs {Coins : Type} [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins)
    {Lq : ℕ} (Dep : Set (QB Lq))
    (pts : Coins × (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → QB Lq)
    (hpairs : ∀ i j : Fin shdP_zkResPts, i ≠ j →
      2 ^ 256 * (univ.filter (fun s => pts s i = pts s j)).card ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig)))
    (hdeps : ∀ i : Fin shdP_zkResPts,
      2 ^ 256 * (univ.filter (fun s => pts s i ∈ Dep)).card ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))) :
    (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      ¬ Function.Injective (pts s) ∨ ∃ i, pts s i ∈ Dep)).card ≤ shdKc Coins := by
  have hprod256 : Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) = 2 ^ 256 * (shdM256 Coins * shdNV) := by
    rw [Fintype.card_prod, ← shdM256_mul Coins h512, shdNV, Nat.mul_assoc]
  let offDiag : Finset (Fin shdP_zkResPts × Fin shdP_zkResPts) :=
    univ.filter (fun p => p.1 ≠ p.2)
  let diag : Finset (Fin shdP_zkResPts × Fin shdP_zkResPts) :=
    univ.filter (fun p => p.1 = p.2)
  have hdisj : Disjoint offDiag diag := by
    refine Finset.disjoint_filter.mpr fun _ _ hne heq => hne heq
  have hunion : offDiag ∪ diag = (univ : Finset (Fin shdP_zkResPts × Fin shdP_zkResPts)) := by
    ext p
    simp only [offDiag, diag, Finset.mem_union, Finset.mem_filter, Finset.mem_univ, true_and]
    exact iff_true_intro (or_comm.mp (Classical.em (p.1 = p.2)))
  have hdiag_card : diag.card = shdP_zkResPts := by
    have hbij : diag = (univ : Finset (Fin shdP_zkResPts)).image (fun i => (i, i)) := by
      ext ⟨a, b⟩
      simp only [diag, Finset.mem_filter, Finset.mem_univ, true_and, Finset.mem_image, Prod.mk.injEq]
      exact ⟨fun h => ⟨a, rfl, h⟩, fun ⟨i, h1, h2⟩ => h1.symm.trans h2⟩
    rw [hbij, Finset.card_image_of_injective _ (fun a b h => (Prod.mk.inj h).1), Finset.card_univ, Fintype.card_fin]
  have hoff_sum : offDiag.card + shdP_zkResPts = shdP_zkResPts * shdP_zkResPts := by
    calc offDiag.card + shdP_zkResPts
        = offDiag.card + diag.card := by rw [hdiag_card]
      _ = (offDiag ∪ diag).card := (Finset.card_union_of_disjoint hdisj).symm
      _ = shdP_zkResPts * shdP_zkResPts := by rw [hunion, Finset.card_univ, Fintype.card_prod, Fintype.card_fin]
  have hsub : univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
        ¬ Function.Injective (pts s) ∨ ∃ i, pts s i ∈ Dep)
      ⊆ offDiag.biUnion (fun p => univ.filter (fun s => pts s p.1 = pts s p.2))
        ∪ (univ : Finset (Fin shdP_zkResPts)).biUnion (fun i => univ.filter (fun s => pts s i ∈ Dep)) := by
    intro s hs
    simp only [Finset.mem_filter, Finset.mem_univ, true_and] at hs
    simp only [Finset.mem_union, Finset.mem_biUnion, offDiag, Finset.mem_filter, Finset.mem_univ, true_and]
    rcases hs with hni | ⟨i, hi⟩
    · by_contra hno
      apply hni
      intro i j hij
      by_contra hne
      exact hno (Or.inl ⟨(i, j), hne, hij⟩)
    · exact Or.inr ⟨i, hi⟩
  have hpair_le : ∀ p ∈ offDiag,
      (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) => pts s p.1 = pts s p.2)).card
        ≤ shdM256 Coins * shdNV := by
    intro p hp
    have hpne : p.1 ≠ p.2 := by
      simp only [offDiag, Finset.mem_filter, Finset.mem_univ, true_and] at hp
      exact hp
    exact Nat.le_of_mul_le_mul_left (by rw [← hprod256]; exact hpairs p.1 p.2 hpne) (Nat.two_pow_pos 256)
  have hdep_le : ∀ i : Fin shdP_zkResPts,
      (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) => pts s i ∈ Dep)).card
        ≤ shdM256 Coins * shdNV := fun i =>
    Nat.le_of_mul_le_mul_left (by rw [← hprod256]; exact hdeps i) (Nat.two_pow_pos 256)
  calc (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
          ¬ Function.Injective (pts s) ∨ ∃ i, pts s i ∈ Dep)).card
      ≤ (offDiag.biUnion (fun p => univ.filter (fun s => pts s p.1 = pts s p.2))).card
          + ((univ : Finset (Fin shdP_zkResPts)).biUnion (fun i => univ.filter (fun s => pts s i ∈ Dep))).card :=
        (Finset.card_le_card hsub).trans (Finset.card_union_le _ _)
    _ ≤ (∑ p ∈ offDiag, (univ.filter (fun s => pts s p.1 = pts s p.2)).card)
          + (∑ i : Fin shdP_zkResPts, (univ.filter (fun s => pts s i ∈ Dep)).card) :=
        Nat.add_le_add Finset.card_biUnion_le Finset.card_biUnion_le
    _ ≤ (∑ _p ∈ offDiag, shdM256 Coins * shdNV)
          + (∑ _i : Fin shdP_zkResPts, shdM256 Coins * shdNV) :=
        Nat.add_le_add (Finset.sum_le_sum hpair_le) (Finset.sum_le_sum fun i _ => hdep_le i)
    _ = (offDiag.card + shdP_zkResPts) * (shdM256 Coins * shdNV) := by
        rw [Finset.sum_const, Finset.sum_const, Finset.card_univ, Fintype.card_fin,
          smul_eq_mul, smul_eq_mul, ← Nat.add_mul]
    _ = shdKc Coins := by
        rw [hoff_sum]; unfold shdKc; ring

open Classical in
private theorem hUw_of_hiddenLeaves_gen {M : ℕ} {Coins Out : Type} [Fintype Coins] [Nonempty Coins]
    (h512 : 2 ^ 512 ∣ Fintype.card Coins)
    {Lq : ℕ} (tag : MTag) (key : Option Dig)
    (vis : Fin M → Prop)
    (pts : Coins → Fin M → QB Lq)
    (out : Coins → Out)
    (hleaf : ∀ c i, ¬ vis i → shdQKind tag key (pts c i) = .leaf)
    (hhid_card : (univ.filter (fun i : Fin M => ¬ vis i)).card ≤ shdP_zkLeaves)
    (hcond : ∀ i, ¬ vis i → ∀ o z,
      2 ^ 256 * (univ.filter (fun c : Coins => out c = o ∧ pts c i = z)).card
        ≤ (univ.filter (fun c : Coins => out c = o)).card)
    (Zs : Out → Finset (QB Lq)) (Wt : ℕ)
    (hWt : ∀ o, ∑ z ∈ Zs o, shdKUf Coins tag key z ≤ Wt) :
    (univ.filter (fun c : Coins => ∃ i, ¬ vis i ∧ pts c i ∈ Zs (out c))).card ≤ Wt := by
  let S : Finset Coins := univ.filter (fun c => ∃ i, ¬ vis i ∧ pts c i ∈ Zs (out c))
  let hid : Finset (Fin M) := univ.filter (fun i => ¬ vis i)
  let Os : Finset Out := (univ : Finset Coins).image out
  have hS_fib : S.card = ∑ o ∈ Os, (S.filter (fun c => out c = o)).card :=
    Finset.card_eq_sum_card_fiberwise fun c _ => Finset.mem_image_of_mem out (mem_univ c)
  have hU_fib : Fintype.card Coins = ∑ o ∈ Os, (univ.filter (fun c : Coins => out c = o)).card := by
    rw [← Finset.card_univ]
    exact Finset.card_eq_sum_card_fiberwise fun c _ => Finset.mem_image_of_mem out (mem_univ c)
  have hfib_le : ∀ o ∈ Os,
      Fintype.card Coins * (S.filter (fun c => out c = o)).card
        ≤ Wt * (univ.filter (fun c : Coins => out c = o)).card := by
    intro o _
    let Zleaf : Finset (QB Lq) := (Zs o).filter (fun z => shdQKind tag key z = .leaf)
    have hsub : S.filter (fun c => out c = o)
        ⊆ hid.biUnion (fun i => Zleaf.biUnion (fun z => univ.filter (fun c => out c = o ∧ pts c i = z))) := by
      intro c hc
      have hcS : c ∈ S := (Finset.mem_filter.mp hc).1
      have hco : out c = o := (Finset.mem_filter.mp hc).2
      obtain ⟨i, hni, hmem⟩ := (Finset.mem_filter.mp hcS).2
      refine Finset.mem_biUnion.mpr ⟨i, Finset.mem_filter.mpr ⟨mem_univ _, hni⟩,
        Finset.mem_biUnion.mpr ⟨pts c i, Finset.mem_filter.mpr ⟨by rwa [← hco], hleaf c i hni⟩,
          Finset.mem_filter.mpr ⟨mem_univ _, hco, rfl⟩⟩⟩
    have hcard_o : (S.filter (fun c => out c = o)).card
        ≤ ∑ i ∈ hid, ∑ z ∈ Zleaf, (univ.filter (fun c : Coins => out c = o ∧ pts c i = z)).card := by
      calc (S.filter (fun c => out c = o)).card
          ≤ (hid.biUnion (fun i => Zleaf.biUnion (fun z => univ.filter (fun c => out c = o ∧ pts c i = z)))).card :=
            Finset.card_le_card hsub
        _ ≤ ∑ i ∈ hid, (Zleaf.biUnion (fun z => univ.filter (fun c => out c = o ∧ pts c i = z))).card :=
            Finset.card_biUnion_le
        _ ≤ ∑ i ∈ hid, ∑ z ∈ Zleaf, (univ.filter (fun c => out c = o ∧ pts c i = z)).card :=
            Finset.sum_le_sum fun _ _ => Finset.card_biUnion_le
    have h256 : 2 ^ 256 * (S.filter (fun c => out c = o)).card
        ≤ shdP_zkLeaves * (Zleaf.card * (univ.filter (fun c : Coins => out c = o)).card) := by
      calc 2 ^ 256 * (S.filter (fun c => out c = o)).card
          ≤ 2 ^ 256 * ∑ i ∈ hid, ∑ z ∈ Zleaf, (univ.filter (fun c : Coins => out c = o ∧ pts c i = z)).card :=
            Nat.mul_le_mul_left _ hcard_o
        _ = ∑ i ∈ hid, ∑ z ∈ Zleaf, 2 ^ 256 * (univ.filter (fun c : Coins => out c = o ∧ pts c i = z)).card := by
            rw [Finset.mul_sum]; refine Finset.sum_congr rfl fun _ _ => Finset.mul_sum _ _ _
        _ ≤ ∑ _i ∈ hid, ∑ _z ∈ Zleaf, (univ.filter (fun c : Coins => out c = o)).card := by
            refine Finset.sum_le_sum fun i hi => Finset.sum_le_sum fun z _ =>
              hcond i (Finset.mem_filter.mp hi).2 o z
        _ = hid.card * (Zleaf.card * (univ.filter (fun c : Coins => out c = o)).card) := by
            simp only [Finset.sum_const, smul_eq_mul]
        _ ≤ shdP_zkLeaves * (Zleaf.card * (univ.filter (fun c : Coins => out c = o)).card) :=
            Nat.mul_le_mul_right _ hhid_card
    have hZsum : Zleaf.card * (shdP_zkLeaves * shdM256 Coins) ≤ Wt := by
      have h1 : Zleaf.card * (shdP_zkLeaves * shdM256 Coins) = ∑ z ∈ Zleaf, shdKUf Coins tag key z := by
        have hconst : ∑ z ∈ Zleaf, shdKUf Coins tag key z = ∑ _z ∈ Zleaf, shdP_zkLeaves * shdM256 Coins :=
          Finset.sum_congr rfl fun z hz => by
            unfold shdKUf; rw [(Finset.mem_filter.mp hz).2]
        rw [hconst, Finset.sum_const, smul_eq_mul]
      rw [h1]
      exact (Finset.sum_le_sum_of_subset (Finset.filter_subset _ _)).trans (hWt o)
    calc Fintype.card Coins * (S.filter (fun c => out c = o)).card
        = shdM256 Coins * (2 ^ 256 * (S.filter (fun c => out c = o)).card) := by
          rw [← shdM256_mul Coins h512]; ring
      _ ≤ shdM256 Coins * (shdP_zkLeaves * (Zleaf.card * (univ.filter (fun c : Coins => out c = o)).card)) :=
          Nat.mul_le_mul_left _ h256
      _ = (Zleaf.card * (shdP_zkLeaves * shdM256 Coins)) * (univ.filter (fun c : Coins => out c = o)).card := by ring
      _ ≤ Wt * (univ.filter (fun c : Coins => out c = o)).card := Nat.mul_le_mul_right _ hZsum
  have htotal : Fintype.card Coins * S.card ≤ Fintype.card Coins * Wt := by
    calc Fintype.card Coins * S.card
        = ∑ o ∈ Os, Fintype.card Coins * (S.filter (fun c => out c = o)).card := by
          rw [hS_fib, Finset.mul_sum]
      _ ≤ ∑ o ∈ Os, Wt * (univ.filter (fun c : Coins => out c = o)).card := Finset.sum_le_sum hfib_le
      _ = Wt * Fintype.card Coins := by rw [← Finset.mul_sum, hU_fib]
      _ = Fintype.card Coins * Wt := Nat.mul_comm _ _
  exact Nat.le_of_mul_le_mul_left htotal Fintype.card_pos

open Classical in
/-- **Zero-rounding-loss `hUw` discharge from unopened-leaf conditional salt freshness**:
cancels `Fintype.card Coins = 2^256 * shdM256 Coins` exactly with zero division rounding. -/
theorem hUw_of_hiddenLeaves {Coins Out : Type} [Fintype Coins] [Nonempty Coins]
    (h512 : 2 ^ 512 ∣ Fintype.card Coins)
    {Lq : ℕ} (tag : MTag) (key : Option Dig)
    (vis : Fin shdP_zkResPts → Prop)
    (pts : Coins → Fin shdP_zkResPts → QB Lq)
    (out : Coins → Out)
    (hleaf : ∀ c i, ¬ vis i → shdQKind tag key (pts c i) = .leaf)
    (hhid_card : (univ.filter (fun i : Fin shdP_zkResPts => ¬ vis i)).card ≤ shdP_zkLeaves)
    (hcond : ∀ i, ¬ vis i → ∀ o z,
      2 ^ 256 * (univ.filter (fun c : Coins => out c = o ∧ pts c i = z)).card
        ≤ (univ.filter (fun c : Coins => out c = o)).card)
    (Zs : Out → Finset (QB Lq)) (Wt : ℕ)
    (hWt : ∀ o, ∑ z ∈ Zs o, shdKUf Coins tag key z ≤ Wt) :
    (univ.filter (fun c : Coins => ∃ i, ¬ vis i ∧ pts c i ∈ Zs (out c))).card ≤ Wt :=
  hUw_of_hiddenLeaves_gen h512 tag key vis pts out hleaf hhid_card hcond Zs Wt hWt

/-! ### Exact ENNReal rate discharges for `shdRunErrRes` -/

private theorem ennreal_mul_div_two_pow {a m k : ℕ} (hm : 0 < m) :
    ((a * m : ℕ) : ℝ≥0∞) / ((2 ^ k * m : ℕ) : ℝ≥0∞) = (a : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k := by
  have hm0 : (m : ℝ≥0∞) ≠ 0 := Nat.cast_ne_zero.mpr (Nat.pos_iff_ne_zero.mp hm)
  rw [Nat.cast_mul, Nat.cast_mul, ENNReal.mul_div_mul_right _ _ hm0 (ENNReal.natCast_ne_top m),
    div_eq_mul_inv, Nat.cast_pow, Nat.cast_ofNat, ENNReal.inv_pow]

private theorem shd_card_prod256 (Coins : Type) [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) = 2 ^ 256 * (shdM256 Coins * shdNV) := by
  rw [Fintype.card_prod, ← shdM256_mul Coins h512, shdNV, Nat.mul_assoc]

private theorem shd_card_prod512 (Coins : Type) [Fintype Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) = 2 ^ 512 * (shdM512 Coins * shdNV) := by
  rw [Fintype.card_prod, ← shdM512_mul Coins h512, shdNV, Nat.mul_assoc]

private theorem shd_num_T : shdP_zkResT = 1048576 := by unfold shdP_zkResT; norm_num
private theorem shd_num_L : shdP_zkLeaves = 5359616 := shdP_zkProg_counts.2.1
private theorem shd_num_N : shdP_zkNodes = 5359504 := shdP_zkProg_counts.2.2.1

/-- Exact before-request rate `shdKm / |Coins × V| ≤ shdRunRes_δp`. -/
theorem shd_hrδp (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    (shdKm Coins : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_δp := by
  have h1 : (((shdP_zkResT + shdP_zkLeaves) * (shdM256 Coins * shdNV) : ℕ) : ℝ≥0∞)
      / Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
      = ((shdP_zkResT + shdP_zkLeaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    rw [shd_card_prod256 Coins h512, ennreal_mul_div_two_pow (Nat.mul_pos (shdM256_pos Coins h512) shdNV_pos)]
  have h2 : ((shdP_zkNodes * (shdM512 Coins * shdNV) : ℕ) : ℝ≥0∞)
      / Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
      = (shdP_zkNodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 := by
    rw [shd_card_prod512 Coins h512, ennreal_mul_div_two_pow (Nat.mul_pos (shdM512_pos Coins h512) shdNV_pos)]
  unfold shdKm shdRunRes_δp
  rw [Nat.cast_add, ENNReal.add_div, Nat.mul_assoc, Nat.mul_assoc, h1, h2, shd_num_T, shd_num_L, shd_num_N,
    Nat.cast_ofNat]

/-- Exact before-request prover-query weight rate `shdWp / |Coins × V| ≤ shdRunRes_ωp`. -/
theorem shd_hrωp (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    (shdWp Coins : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_ωp := by
  have h1 : (((shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves) * (shdM256 Coins * shdNV) : ℕ) : ℝ≥0∞)
      / Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
      = ((shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    rw [shd_card_prod256 Coins h512, ennreal_mul_div_two_pow (Nat.mul_pos (shdM256_pos Coins h512) shdNV_pos)]
  have h2 : (((shdP_zkNodes * shdP_zkNodes) * (shdM512 Coins * shdNV) : ℕ) : ℝ≥0∞)
      / Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
      = ((shdP_zkNodes * shdP_zkNodes : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 := by
    rw [shd_card_prod512 Coins h512, ennreal_mul_div_two_pow (Nat.mul_pos (shdM512_pos Coins h512) shdNV_pos)]
  unfold shdWp shdRunRes_ωp
  rw [Nat.cast_add, ENNReal.add_div,
    Nat.mul_assoc (shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves),
    Nat.mul_assoc (shdP_zkNodes * shdP_zkNodes), h1, h2, shd_num_T, shd_num_L, shd_num_N]

/-- Exact collision / dep-hit rate `shdKc / |Coins × V| ≤ shdRunRes_εc`. -/
theorem shd_hrεc (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    (shdKc Coins : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_εc := by
  have hP : shdP_zkResPts = 11767696 := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.1
  unfold shdKc shdRunRes_εc
  rw [Nat.mul_assoc (shdP_zkResPts * shdP_zkResPts), shd_card_prod256 Coins h512,
    ennreal_mul_div_two_pow (Nat.mul_pos (shdM256_pos Coins h512) shdNV_pos), hP]

/-- Exact after-request rate `(2 * shdKUm) / |Coins| ≤ shdRunRes_δh`. -/
theorem shd_hrδh (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    ((2 * shdKUm Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ shdRunRes_δh := by
  have h1 : (((shdP_zkResT + shdP_zkLeaves) * shdM256 Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = ((shdP_zkResT + shdP_zkLeaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    rw [← shdM256_mul Coins h512, ennreal_mul_div_two_pow (shdM256_pos Coins h512)]
  have h2 : ((shdP_zkNodes * shdM512 Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = (shdP_zkNodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 := by
    rw [← shdM512_mul Coins h512, ennreal_mul_div_two_pow (shdM512_pos Coins h512)]
  have hdiv : ((shdKUm Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins = shdRunRes_δp := by
    unfold shdKUm shdRunRes_δp
    rw [Nat.cast_add, ENNReal.add_div, h1, h2, shd_num_T, shd_num_L, shd_num_N, Nat.cast_ofNat]
  calc ((2 * shdKUm Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = 2 * (((shdKUm Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins) := by
        rw [Nat.cast_mul, Nat.cast_ofNat, div_eq_mul_inv, div_eq_mul_inv, mul_assoc]
    _ = 2 * shdRunRes_δp := by rw [hdiv]
    _ ≤ 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRunRes_δp) := mul_le_mul_right le_add_self _

/-- Exact after-request prover-query weight rate `(2 * shdWpa) / |Coins| ≤ shdRunRes_ωh`. -/
theorem shd_hrωh (Coins : Type) [Fintype Coins] [Nonempty Coins] (h512 : 2 ^ 512 ∣ Fintype.card Coins) :
    ((2 * shdWpa Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ shdRunRes_ωh := by
  have h1 : (((shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves) * shdM256 Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = ((shdP_zkResT * shdP_zkResT + shdP_zkLeaves * shdP_zkLeaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    rw [← shdM256_mul Coins h512, ennreal_mul_div_two_pow (shdM256_pos Coins h512)]
  have h2 : (((shdP_zkNodes * shdP_zkNodes) * shdM512 Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = ((shdP_zkNodes * shdP_zkNodes : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 := by
    rw [← shdM512_mul Coins h512, ennreal_mul_div_two_pow (shdM512_pos Coins h512)]
  have hdiv : ((shdWpa Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins = shdRunRes_ωp := by
    unfold shdWpa shdRunRes_ωp
    rw [Nat.cast_add, ENNReal.add_div, h1, h2, shd_num_T, shd_num_L, shd_num_N]
  calc ((2 * shdWpa Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins
      = 2 * (((shdWpa Coins : ℕ) : ℝ≥0∞) / Fintype.card Coins) := by
        rw [Nat.cast_mul, Nat.cast_ofNat, div_eq_mul_inv, div_eq_mul_inv, mul_assoc]
    _ = 2 * shdRunRes_ωp := by rw [hdiv]
    _ ≤ 2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRunRes_ωp) := mul_le_mul_right le_add_self _

/-! ### Half-target cap (`R ≤ 2^85`) for real OS-RNG (`NativeOsRngIndist`) budget composition -/

private theorem nat_mul_inv_pow_le_cnt {n a k : ℕ} (hn : n ≤ 2 ^ a) (hk : a ≤ k) :
    (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k ≤ (2⁻¹ : ℝ≥0∞) ^ (k - a) := by
  have he : k = a + (k - a) := by omega
  calc (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k
      ≤ ((2 ^ a : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by
        rw [← he]; exact mul_le_mul_left (Nat.cast_le.mpr hn) _
    _ = (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by norm_cast
    _ = (2⁻¹ : ℝ≥0∞) ^ (k - a) := two_pow_mul_inv_pow a (k - a)

/-- **Half-target Shieldstral T128 R13 ZK budget (`R ≤ 2^85`)**:
`shdRunErrRes q R ≤ q * 2^-129 + R * 2^-121` for all `R ≤ 2^85`, reserving a full half of `εzkTarget`
for real OS-RNG transfer via `NativeOsRngIndist`. -/
theorem shdRunErrRes_half_cap_85 (q R : ℕ) (hR : R ≤ 2 ^ 85) :
    shdRunErrRes q R ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121 := by
  have hδp : shdRunRes_δp ≤ (2⁻¹ : ℝ≥0∞) ^ 233 := by
    have h1 : ((1048576 + 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
        ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
      mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
    have h2 : (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
      calc (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
          ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 23) := nat_mul_inv_pow_le_cnt (a := 23) (by norm_num) (by norm_num)
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
        _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
    calc shdRunRes_δp
        ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
      _ = (((2 ^ 23 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 23) := nat_mul_inv_pow_le_cnt (a := 23) (by norm_num) (by norm_num)
  have hωp : shdRunRes_ωp ≤ (2⁻¹ : ℝ≥0∞) ^ 211 := by
    have h1 : ((1048576 * 1048576 + 5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
        ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
      mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
    have h2 : ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
      calc ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
          ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 46) := nat_mul_inv_pow_le_cnt (a := 46) (by norm_num) (by norm_num)
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
        _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
    calc shdRunRes_ωp
        ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
      _ = (((2 ^ 45 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 45) := nat_mul_inv_pow_le_cnt (a := 45) (by norm_num) (by norm_num)
  have hL : (5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 233 :=
    nat_mul_inv_pow_le_cnt (a := 23) (by norm_num) (by norm_num)
  have hL2 : ((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 211 :=
    nat_mul_inv_pow_le_cnt (a := 45) (by norm_num) (by norm_num)
  have hδsum : shdRunRes_δp + shdRunRes_δh ≤ (2⁻¹ : ℝ≥0∞) ^ 230 := by
    have heq : shdRunRes_δp + shdRunRes_δh = 3 * shdRunRes_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256) := by
      unfold shdRunRes_δh; ring
    rw [heq]
    calc 3 * shdRunRes_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256)
        ≤ 3 * (2⁻¹ : ℝ≥0∞) ^ 233 + 2 * (2⁻¹ : ℝ≥0∞) ^ 233 :=
          add_le_add (mul_le_mul_right hδp _) (mul_le_mul_right hL _)
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
          add_le_add (mul_le_mul_right hωp _) (mul_le_mul_right hL2 _)
      _ = 5 * (2⁻¹ : ℝ≥0∞) ^ 211 := by ring
      _ ≤ (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + 208) := by
          have h58 : (5 : ℝ≥0∞) ≤ (2 : ℝ≥0∞) ^ 3 := by norm_num
          simpa using mul_le_mul_left h58 ((2⁻¹ : ℝ≥0∞) ^ 211)
      _ = (2⁻¹ : ℝ≥0∞) ^ 208 := two_pow_mul_inv_pow 3 208
  have hε : shdRunRes_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 209 :=
    nat_mul_inv_pow_le_cnt (a := 47) (by norm_num) (by norm_num)
  have hR' : (R : ℝ≥0∞) ≤ 2 ^ 85 := by exact_mod_cast hR
  have h2r : (2 : ℝ≥0∞) * 2 ^ 85 = 2 ^ 86 := by ring
  have hA : (R : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh)) ≤ (2⁻¹ : ℝ≥0∞) ^ 129 := by
    calc (R : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh))
        ≤ 2 ^ 85 * (2 * (shdRunRes_δp + shdRunRes_δh)) := mul_le_mul_left hR' _
      _ = 2 ^ 86 * (shdRunRes_δp + shdRunRes_δh) := by rw [← h2r]; ring
      _ ≤ 2 ^ 86 * (2⁻¹ : ℝ≥0∞) ^ (86 + 144) := by simpa using mul_le_mul_right hδsum ((2 : ℝ≥0∞) ^ 86)
      _ = (2⁻¹ : ℝ≥0∞) ^ 144 := two_pow_mul_inv_pow 86 144
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 129 := inv_pow_le_inv_pow (by norm_num)
  have hB : 2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 121 := by
    have h1 : 2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := by
      calc 2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh))
          ≤ 2 * (2 ^ 85 * (shdRunRes_ωp + shdRunRes_ωh)) := by gcongr
        _ = 2 ^ 86 * (shdRunRes_ωp + shdRunRes_ωh) := by rw [← h2r]; ring
        _ ≤ 2 ^ 86 * (2⁻¹ : ℝ≥0∞) ^ (86 + 122) := by simpa using mul_le_mul_right hωsum ((2 : ℝ≥0∞) ^ 86)
        _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 86 122
    have h2 : 4 * shdRunRes_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := by
      calc 4 * shdRunRes_εc
          ≤ (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 207) := by
            simpa [show (4 : ℝ≥0∞) = (2 : ℝ≥0∞) ^ 2 by norm_num] using mul_le_mul_right hε (4 : ℝ≥0∞)
        _ = (2⁻¹ : ℝ≥0∞) ^ 207 := two_pow_mul_inv_pow 2 207
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := inv_pow_le_inv_pow (by norm_num)
    calc 2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc
        ≤ (2⁻¹ : ℝ≥0∞) ^ 122 + (2⁻¹ : ℝ≥0∞) ^ 122 := add_le_add h1 h2
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 121) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 121 := two_pow_mul_inv_pow 1 121
  unfold shdRunErrRes
  calc ∑ j ∈ range R, wStep shdRunRes_δp shdRunRes_ωp shdRunRes_δh shdRunRes_ωh shdRunRes_εc q R j
      ≤ ∑ _j ∈ range R, ((q : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh))
          + (2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc)) := by
        refine Finset.sum_le_sum fun j hj => ?_
        have hjR : (j : ℝ≥0∞) ≤ R := by exact_mod_cast (Finset.mem_range.mp hj).le
        unfold wStep
        calc 2 * ((q : ℝ≥0∞) * shdRunRes_δp + (j : ℝ≥0∞) * shdRunRes_ωp) + 4 * shdRunRes_εc
              + 2 * ((q : ℝ≥0∞) * shdRunRes_δh + (R : ℝ≥0∞) * shdRunRes_ωh)
            ≤ 2 * ((q : ℝ≥0∞) * shdRunRes_δp + (R : ℝ≥0∞) * shdRunRes_ωp) + 4 * shdRunRes_εc
              + 2 * ((q : ℝ≥0∞) * shdRunRes_δh + (R : ℝ≥0∞) * shdRunRes_ωh) := by gcongr
          _ = (q : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh))
              + (2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc) := by ring
    _ = (R : ℝ≥0∞) * ((q : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh))
          + (2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc)) := by
        rw [Finset.sum_const, Finset.card_range, nsmul_eq_mul]
    _ = (q : ℝ≥0∞) * ((R : ℝ≥0∞) * (2 * (shdRunRes_δp + shdRunRes_δh)))
          + (R : ℝ≥0∞) * (2 * ((R : ℝ≥0∞) * (shdRunRes_ωp + shdRunRes_ωh)) + 4 * shdRunRes_εc) := by ring
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121 :=
        add_le_add (mul_le_mul_right hA _) (mul_le_mul_right hB _)

/-- **Budget combination for `NativeOsRngIndist` at `εzkTarget`**:
if the real OS-RNG seed expansion advantage satisfies `εrng q R' ≤ q * 2^-129 + R' * 2^-121` on `q, R' ≤ 2^64`,
then `shdRunErrRes q R' + εrng q R' ≤ εzkTarget q R'`. -/
theorem shdRunErrRes_add_rng_le_target {εrng : ℕ → ℕ → ℝ≥0∞}
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121)
    (q R' : ℕ) (hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) :
    shdRunErrRes q R' + εrng q R' ≤ εzkTarget q R' := by
  have hhalf : shdRunErrRes q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121 :=
    shdRunErrRes_half_cap_85 q R' (le_trans hR' (by norm_num))
  have h128 : (2⁻¹ : ℝ≥0∞) ^ 129 + (2⁻¹ : ℝ≥0∞) ^ 129 = (2⁻¹ : ℝ≥0∞) ^ 128 := by
    calc (2⁻¹ : ℝ≥0∞) ^ 129 + (2⁻¹ : ℝ≥0∞) ^ 129
        = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 128) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 128 := two_pow_mul_inv_pow 1 128
  have h120 : (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 = (2⁻¹ : ℝ≥0∞) ^ 120 := by
    calc (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121
        = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120
  calc shdRunErrRes q R' + εrng q R'
      ≤ ((q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121)
          + ((q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :=
        add_le_add hhalf (hεrng q R' hq hR')
    _ = (q : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 129 + (2⁻¹ : ℝ≥0∞) ^ 129)
          + (R' : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121) := by ring
    _ = εzkTarget q R' := by rw [h128, h120]; rfl

end ShdRunErrResRates

end ZK60.HonestShield
