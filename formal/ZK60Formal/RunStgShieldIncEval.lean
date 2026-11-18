/-
D63 lane L63 (2026-11-18), part 55: **a standalone define polynomial at one draw, its cube sum at a Boolean `eq`
point, and the clauses isolated from the batching** (item 4b, step 2 and 3 of HANDOFF_20261118_2.md, generic).

* **`stgΦBC_sa_eval`**: at a draw `y` where `define` succeeds with an `eq` table first and no hosted slot, the define
  polynomial `stgΦBC` of a standalone slot is the cube sum of its table side (the step of lane L65's
  `offZero_standalone_draw` at one `y`, kept explicit);
* `bitEq`, **`cube_eqDraw_single`**: when the `eq` table's point is the bits `b` of the main variables (one extension
  variable), the cube sum of `eq · F` is `F` at the cube point `(b, 0)`, `cptS n b`;
* `cptS` facts: `selK = 1`, `cmK = 0`, the main variables are `b`'s bits;
* **`clauses5_of_combo`**, **`clauses3_of_combo`**: a batched value `μ0·L + μ1·B + μ2·T + μ3·(A + ζ·C)` (resp.
  `μ0·R + μ1·(A + ζ·C)`) that vanishes for all nonzero `μ`, `ζ` has every clause zero (`2 ≠ 0`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncCube
import ZK60Formal.RunStgShieldIncRun

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. The define polynomial of a standalone slot at one draw -/

section Eval

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **A STANDALONE DEFINE POLYNOMIAL AT ONE DRAW IS ITS TABLE SIDE'S CUBE SUM.** -/
theorem stgΦBC_sa_eval {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg m : ℕ)
    (hIOd : StgCsIODeg U hbij (elog k) pOk csIO)
    (hhd : hd.length = k) (hm : m ≤ P0.draws k) (hmn : m ≤ n)
    (hkind : P.kind k = .standalone) (hsh : Block.slotShape P k = (n, e, sdeg))
    (restTabs : List Block.Tab) (poly : List Fp2 → Fp2) (y : Fin (P0.draws k) → K)
    (hdef : P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly, []⟩)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyK : (ℕ → K) → K)
    (hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDeg : ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyK (fun idx => g idx x))) :
    stgΦBC U hbij P0 P elog (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd k (stgWords U hbij y)
      = if tabsFit n restTabs then
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx => match idx with
            | 0 => eqDrawK m n e hm y x
            | j + 1 => (restTabs.map (stgTabK U hbij (StageV.atLog P (elog k))
                (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD j 0))
        else 0 := by
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have htake : (hd ++ [stgWords U hbij y]).take k = hd := by
    rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
  have hgetD : (hd ++ [stgWords U hbij y]).getD k [] = stgWords U hbij y := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
    simp [hhd]
  have hdef' : (StageV.atLog P (elog k)).define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [stgWords U hbij y]).take k⟩
      ((hd ++ [stgWords U hbij y]).getD k [])
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly, []⟩ := by
    rw [htake, hgetD]; exact hdef
  have hok' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), TabPrivOK pOk t := by
    intro t ht; rcases List.mem_cons.mp ht with rfl | ht
    · intro p hp; cases hp
    · exact hok t ht
  have hcan' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he; rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact fun a ha => stgWords_canon U hbij y a (List.mem_of_mem_take ha)
    · exact hcan t ht pt s he
  obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 (StageV.atLog P (elog k)) hP
    lc h Q eC rA rH iA iH pOk csIO v hlc hIOd bga (hd ++ [stgWords U hbij y]) k n e sdeg hsh _ _ _ hdef' hok' hcan'
    polyK hpK hpDeg
  have hsp : stgSpTC U hbij P0 P elog cs bga (hd ++ [stgWords U hbij y]) k
      = stgSpT U hbij P0 (StageV.atLog P (elog k)) cs bga (hd ++ [stgWords U hbij y]) k := rfl
  have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpTC U hbij P0 P elog cs bga (hd ++ [stgWords U hbij y]) k)
      ∧ ∀ hk ∈ ([] : List (ℕ × Fp2)), IndDegLE (Block.slotShape P0 hk.1).2.2
          (stgSpTC U hbij P0 P elog cs bga (hd ++ [stgWords U hbij y]) hk.1) :=
    ⟨hdegSp, fun _ hm => absurd hm List.not_mem_nil⟩
  unfold stgΦBC
  rw [hdef]
  dsimp only
  rw [ite_eq_left hguard, hkind]
  dsimp only
  rw [hsp, heqSp]
  have hfit_iff : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) ↔ tabsFit n restTabs := by
    constructor
    · exact fun hf t ht => hf t (List.mem_cons_of_mem _ ht)
    · intro hf t ht
      rcases List.mem_cons.mp ht with rfl | ht
      · show 0 + ((stgWords U hbij y).take m).length ≤ n
        rw [List.length_take, stgWords_length]; omega
      · exact hf t ht
  by_cases hfit : tabsFit n restTabs
  · have hfit' : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := hfit_iff.mpr hfit
    simp only [hfit, hfit', ↓reduceIte]
    congr 1; funext x; congr 1; funext idx
    cases idx with
    | zero => exact stgTabK_eq_draw U hbij (StageV.atLog P (elog k)) cs m n e hm hmn y x
    | succ j => rfl
  · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
    simp only [hfit, hfit', ↓reduceIte]
    unfold cubeSum; simp

end Eval

/-! ## 2. The cube sum of `eq · F` at a Boolean `eq` point -/

section Cube

variable {K : Type} [Field K]

/-- The `eq` factor of two bits. -/
theorem bitEq (p q : Bool) :
    ((bit p : K) * bit q + (1 - bit p) * (1 - bit q)) = if p = q then 1 else 0 := by
  cases p <;> cases q <;> simp [bit]

/-- **The cube point `(b, 0)`** on `n` main variables and the extension variables after them. -/
def cptS {N : ℕ} (n : ℕ) (b : Fin n → Bool) : Fin N → Bool := fun i => if h : i.val < n then b ⟨i.val, h⟩ else false

theorem xg_cptS {N : ℕ} (n : ℕ) (b : Fin n → Bool) (a : ℕ) (ha : a < n) (hN : n < N) :
    Block.xg (fun i : Fin N => (bit (cptS n b i) : K)) a = bit (b ⟨a, ha⟩) := by
  unfold Block.xg cptS
  rw [dite_eq_left (by omega)]
  simp only [dite_eq_left ha]

theorem xrK_cptS {N : ℕ} (n : ℕ) (b : Fin n → Bool) (a : ℕ) (ha : a < n) (hN : n < N) :
    Block.xrK n (fun i : Fin N => (bit (cptS n b i) : K)) a = bit (b ⟨a, ha⟩) := by
  unfold Block.xrK
  rw [ite_eq_left ha, xg_cptS n b a ha hN]

theorem selK_cptS {N : ℕ} (n : ℕ) (b : Fin n → Bool) (hN : N = n + 1) :
    Block.selK n 1 (fun i : Fin N => (bit (cptS n b i) : K)) = 1 := by
  unfold Block.selK Block.yeK Block.xg
  rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
  simp [cptS, bit]

theorem cmK_cptS {N : ℕ} (n : ℕ) (b : Fin n → Bool) (hN : N = n + 1) (r : ℕ) :
    Block.cmK n 1 (fun i : Fin N => (bit (cptS n b i) : K)) r = 0 := by
  unfold Block.cmK Block.yeK Block.xg
  by_cases hr : n + r < N
  · rw [dite_eq_left hr]
    have hr0 : r = 0 := by omega
    subst hr0
    simp [cptS, bit]
  · rw [dite_eq_right hr, zero_mul]

/-- **THE CUBE SUM OF `eq(y, ·) · F` AT A BOOLEAN `eq` POINT IS `F` AT `(b, 0)`.** -/
theorem cube_eqDraw_single {M N : ℕ} (n : ℕ) (hm : n ≤ M) (hN : N = n + 1) (y : Fin M → K) (b : Fin n → Bool)
    (hy : ∀ a (ha : a < n), y ⟨a, by omega⟩ = bit (b ⟨a, ha⟩)) (F : (Fin N → K) → K) :
    cubeSum (fun x : Fin N → K => eqDrawK n n 1 hm y x * F x)
      = F (fun i => bit (cptS n b i)) := by
  unfold cubeSum
  rw [Finset.sum_eq_single (cptS n b)]
  · have he : eqDrawK n n 1 hm y (fun i : Fin N => (bit (cptS n b i) : K)) = 1 := by
      unfold eqDrawK
      rw [selK_cptS n b hN, one_mul]
      refine Finset.prod_eq_one (fun a _ => ?_)
      rw [hy a.val a.isLt, xrK_cptS n b a.val a.isLt (by omega), bitEq, ite_eq_left rfl]
    dsimp only
    rw [he, one_mul]
  · intro w _ hw
    have hz : eqDrawK n n 1 hm y (fun i : Fin N => (bit (w i) : K)) = 0 := by
      unfold eqDrawK
      by_cases hext : w ⟨n, by omega⟩ = true
      · have hs : Block.selK n 1 (fun i : Fin N => (bit (w i) : K)) = 0 := by
          unfold Block.selK Block.yeK Block.xg
          rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
          dsimp only
          rw [hext]
          simp [bit]
        rw [hs, zero_mul]
      · obtain ⟨a, ha⟩ : ∃ a : Fin n, w ⟨a.val, by omega⟩ ≠ b a := by
          by_contra hc
          push Not at hc
          apply hw
          funext i
          unfold cptS
          by_cases hi : i.val < n
          · rw [dite_eq_left hi]
            exact hc ⟨i.val, hi⟩
          · rw [dite_eq_right hi]
            have hin : i = ⟨n, by omega⟩ := Fin.ext (by show i.val = n; have := i.isLt; omega)
            rw [hin]
            simpa using hext
        refine mul_eq_zero_of_right _ (Finset.prod_eq_zero (Finset.mem_univ a) ?_)
        have hx : Block.xrK n (fun i : Fin N => (bit (w i) : K)) a.val = bit (w ⟨a.val, by omega⟩) := by
          unfold Block.xrK Block.xg
          rw [ite_eq_left a.isLt, dite_eq_left (by omega)]
        rw [hy a.val a.isLt, hx, bitEq, ite_eq_right (fun he => ha he.symm)]
    dsimp only
    rw [hz, zero_mul]
  · intro hn; exact absurd (Finset.mem_univ _) hn

end Cube

/-! ## 3. The clauses of a batched zero-check, isolated -/

section Iso

variable {K : Type} [Field K]

/-- **SIC_QZC's batching**: four clauses and the two pad planes vanish when every batched value vanishes. -/
theorem clauses5_of_combo (h2 : (2 : K) ≠ 0) (L B T A C : K)
    (h : ∀ μ0 μ1 μ2 μ3 ζ : K, μ0 ≠ 0 → μ1 ≠ 0 → μ2 ≠ 0 → μ3 ≠ 0 → ζ ≠ 0 →
      μ0 * L + μ1 * B + μ2 * T + μ3 * (A + ζ * C) = 0) :
    L = 0 ∧ B = 0 ∧ T = 0 ∧ A = 0 ∧ C = 0 := by
  have e1 := h 1 1 1 1 1 one_ne_zero one_ne_zero one_ne_zero one_ne_zero one_ne_zero
  have e2 := h 2 1 1 1 1 h2 one_ne_zero one_ne_zero one_ne_zero one_ne_zero
  have e3 := h 1 2 1 1 1 one_ne_zero h2 one_ne_zero one_ne_zero one_ne_zero
  have e4 := h 1 1 2 1 1 one_ne_zero one_ne_zero h2 one_ne_zero one_ne_zero
  have e5 := h 1 1 1 1 2 one_ne_zero one_ne_zero one_ne_zero one_ne_zero h2
  have hL : L = 0 := by linear_combination e2 - e1
  have hB : B = 0 := by linear_combination e3 - e1
  have hT : T = 0 := by linear_combination e4 - e1
  have hC : C = 0 := by linear_combination e5 - e1
  refine ⟨hL, hB, hT, ?_, hC⟩
  linear_combination e1 - hL - hB - hT - hC

/-- **SIC_TZC's batching**: the relation and the two pad planes vanish when every batched value vanishes. -/
theorem clauses3_of_combo (h2 : (2 : K) ≠ 0) (R A C : K)
    (h : ∀ μ0 μ1 ζ : K, μ0 ≠ 0 → μ1 ≠ 0 → ζ ≠ 0 → μ0 * R + μ1 * (A + ζ * C) = 0) :
    R = 0 ∧ A = 0 ∧ C = 0 := by
  have e1 := h 1 1 1 one_ne_zero one_ne_zero one_ne_zero
  have e2 := h 2 1 1 h2 one_ne_zero one_ne_zero
  have e5 := h 1 1 2 one_ne_zero one_ne_zero h2
  have hR : R = 0 := by linear_combination e2 - e1
  have hC : C = 0 := by linear_combination e5 - e1
  refine ⟨hR, ?_, hC⟩
  linear_combination e1 - hR - hC

end Iso

end ZK60.ProtocolClassify
