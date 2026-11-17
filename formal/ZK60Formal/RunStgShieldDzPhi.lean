/-
D63 lane L63 (2026-11-17), part 33: **INC-00's define polynomial at the bits of a word past the tokens is the input
endpoint's claim there** (`hdzW`, second half), and **a non-vanishing define polynomial at slot `0` is stage doom**.

INC-00 is `eq·(end − supp_T·tok)` (`incDefIO_ok`). Its define polynomial (`stgΦBC`: the cube sum of the slot's table
side, the degree gate met by lane L65's `stgSpT_eval_and_deg`) at the draws `y0` = the bits of a word `x0` (msb first)
is the sum over the cube of `eq(y0, ρ)·sel(e)·(end − supp·tok)`, whose only non-zero term is the cube point `x*` of
`x0`'s bits with extension bit `0`; with `T ≤ x0`, `supp(x0) = 0`, so the value is `end(x*)`: the input endpoint's
claim at `x*`.

* `eqPoly_bits`, `xg_bitv`: helpers;
* **`ssh_inc0_Φ_bool`**: `stgΦBC … 0 (stgWords y0) = csIO v .inp (claim at x*)`;
* **`ssh_doomAtV_of_def0`**: at every reading, a define polynomial at slot `0` that does not vanish everywhere (over
  the reading's view and head challenges) is the first disjunct of `StgDoomAtV`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDzBits

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV
open ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Help

variable {K : Type} [Field K]

/-- `eq` of two points of bits is the indicator of their agreement. -/
theorem eqPoly_bits (m : ℕ) (f g : ℕ → Bool) (pf px : ℕ → K) (hf : ∀ a, a < m → pf a = bit (f a))
    (hg : ∀ a, a < m → px a = bit (g a)) :
    eqPoly (fun a : Fin m => pf a) (fun a : Fin m => px a) = if ∀ a, a < m → f a = g a then 1 else 0 := by
  have e1 : (fun a : Fin m => pf a) = fun a : Fin m => (bit (f a) : K) := funext fun a => hf a.val a.isLt
  have e2 : (fun a : Fin m => px a) = fun a : Fin m => (bit (g a) : K) := funext fun a => hg a.val a.isLt
  rw [e1, e2, eqPoly_bit (fun a : Fin m => f a) (fun a : Fin m => g a)]
  by_cases h : ∀ a, a < m → f a = g a
  · rw [ite_eq_left (funext fun a : Fin m => h a.val a.isLt), ite_eq_left h]
  · rw [ite_eq_right h, ite_eq_right (fun hb => h fun a ha => congrFun hb ⟨a, ha⟩)]

theorem xg_bitv {N : ℕ} (b : Fin N → Bool) (q : ℕ) (hq : q < N) :
    Block.xg (fun i => (bit (b i) : K)) q = bit (b ⟨q, hq⟩) := by
  unfold Block.xg
  rw [dite_eq_left hq]

end Help

section Phi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **INC-00'S DEFINE POLYNOMIAL AT THE BITS OF A WORD PAST THE TOKENS IS THE INPUT ENDPOINT'S CLAIM AT THAT WORD'S
CUBE POINT** (main bits `x0`'s, extension bit `0`). -/
theorem ssh_inc0_Φ_bool (hU : U ^ 2 = algebraMap GF K 7) (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch))) (lc h Q eC rA rH iA iH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L) (hlc : Vi.pub.lt ≤ lc)
    (hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIO)
    (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords) (x0 : ℕ) (hT : Vi.pub.tokens ≤ x0)
    (hx0 : x0 < Vi.pub.inEpWords) :
    stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
        (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) (Fp2.zero, Fp2.zero, Fp2.zero) [] 0
        (stgWords U hbij (fun a : Fin (P0.draws 0) => (bit (mb (clog2 Vi.pub.inEpWords) x0 a) : K)))
      = csIO v .inp (Block.buildClaim (atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 0))
          ⟨.inp, [(0, Fp2.one)], clog2 Vi.pub.inEpWords, rhoC 0 (clog2 Vi.pub.inEpWords), Vi.geo.epDataRows, 0⟩
          (Block.claimPoint ⟨.inp, [(0, Fp2.one)], clog2 Vi.pub.inEpWords, rhoC 0 (clog2 Vi.pub.inEpWords),
              Vi.geo.epDataRows, 0⟩
            ((stgWords U hbij (fun i : Fin (stgN P0 0) =>
              (bit (decide (i.val < clog2 Vi.pub.inEpWords) && mb (clog2 Vi.pub.inEpWords) x0 i) : K))).take
              (clog2 Vi.pub.inEpWords)))
          (Block.oneMinusProd ((stgWords U hbij (fun i : Fin (stgN P0 0) =>
              (bit (decide (i.val < clog2 Vi.pub.inEpWords) && mb (clog2 Vi.pub.inEpWords) x0 i) : K))).drop
              (clog2 Vi.pub.inEpWords)))
          (Block.maskCoef ((stgWords U hbij (fun i : Fin (stgN P0 0) =>
              (bit (decide (i.val < clog2 Vi.pub.inEpWords) && mb (clog2 Vi.pub.inEpWords) x0 i) : K))).drop
              (clog2 Vi.pub.inEpWords)) 0) Fp2.zero) := by
  -- the slot's data
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set P := Vi.bp (incCtx I ch) with hPdef
  set lw := clog2 I.inEpWords with hlw
  set L0 := incLay I G.bLogN with hL0
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  set y0 : Fin (P0.draws 0) → K := fun a => bit (mb lw x0 a) with hy0
  set w := stgWords U hbij y0 with hw
  set bs : Fin (stgN P0 0) → Bool := fun i => decide (i.val < lw) && mb lw x0 i with hbs
  have hdraws : P0.draws 0 = lw := by rw [hP.1]; rfl
  have hN : stgN P0 0 = lw + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have hwl : w.length = lw := by rw [hw, stgWords_length, hdraws]
  let restTabs : List Block.Tab :=
    [.pub (supp I.tokens I.inEpWords),
     .priv ⟨.a, [(L0.aOff incA_TOK, Fp2.one)], L0.aLog.getD incA_TOK 0,
       fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw,
       L0.aMaskBase + 2 * (L0.prefixA 0 + 0), 0⟩,
     .priv ⟨.inp, [(0, Fp2.one)], lw, rhoC 0 lw, G.epDataRows, 0⟩]
  let tabs : List Block.Tab := .eq (w.take lw) 0 :: restTabs
  let poly : List Fp2 → Fp2 := fun vals => (vg vals 0).mul ((vg vals 3).sub ((vg vals 1).mul (vg vals 2)))
  have hdefP : P.define 0 ⟨Fp2.zero, Fp2.zero, Fp2.zero, []⟩ w = .ok ⟨tabs, poly, []⟩ := incDefIO_ok I G w
  have hdefA : (atLog P (incElog I G.bLogN 0)).define 0
      ⟨(Fp2.zero, Fp2.zero, Fp2.zero).1, (Fp2.zero, Fp2.zero, Fp2.zero).2.1, (Fp2.zero, Fp2.zero, Fp2.zero).2.2,
        ([] ++ [w]).take 0⟩ (([] ++ [w]).getD 0 []) = .ok ⟨tabs, poly, []⟩ := incDefIO_ok I G w
  have hok : ∀ t ∈ tabs, TabPrivOK (IncPrivIO0 I) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · intro p hp; cases hp
    rcases List.mem_cons.mp ht with rfl | ht
    · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht
    · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht
    · exact tabPrivOK_inc_io0 I _
    · exact absurd ht List.not_mem_nil
  have hcanT : ∀ t ∈ tabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact fun a ha => stgWords_canon U hbij y0 a (List.mem_of_mem_take ha)
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  let polyK : (ℕ → K) → K := fun g => g 0 * (g 3 - g 1 * g 2)
  have hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0) := by
    intro vals hv
    show ((vg vals 0).mul ((vg vals 3).sub ((vg vals 1).mul (vg vals 2)))).toK U = _
    rw [Fp2.toK_mul U hU, Fp2.toK_sub U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _),
        Fp2.toK_mul U hU, vg_toK_map, vg_toK_map, vg_toK_map, vg_toK_map]
  have hpDeg : ∀ g : ℕ → (Fin (stgN P0 0) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE 3 (fun x => polyK (fun idx => g idx x)) := by
    intro g hg
    have hsub : IndDegLE 2 (fun x => g 3 x - g 1 x * g 2 x) :=
      IndDegLE.sub (IndDegLE.mono (hg 3) (by norm_num)) (IndDegLE.mul (hg 1) (hg 2))
    simpa using IndDegLE.mul (hg 0) hsub
  obtain ⟨heqSp, hdeg⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 (atLog P (incElog I G.bLogN 0)) hP
    lc h Q eC rA rH iA iH (IncPrivIO0 I) csIO v hlc hIO0 (Fp2.zero, Fp2.zero, Fp2.zero) ([] ++ [w]) 0 lw 1 3 rfl
    tabs poly [] hdefA hok hcanT polyK hpK hpDeg
  -- tabsFit
  have hsuppl : (supp I.tokens I.inEpWords).length = I.inEpWords := by simp [supp]
  have hfit : tabsFit lw tabs := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · show 0 + (w.take lw).length ≤ lw
      rw [List.length_take]; omega
    rcases List.mem_cons.mp ht with rfl | ht
    · show (supp I.tokens I.inEpWords).length = 2 ^ lw
      rw [hsuppl, hlw, hpow]
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    · exact absurd ht List.not_mem_nil
  -- unfold the define polynomial
  have hsp : stgSpTC U hbij P0 P (incElog I G.bLogN) cs (Fp2.zero, Fp2.zero, Fp2.zero) ([] ++ [w]) 0
      = stgSpT U hbij P0 (atLog P (incElog I G.bLogN 0)) cs (Fp2.zero, Fp2.zero, Fp2.zero) ([] ++ [w]) 0 := rfl
  have hkind : P.kind 0 = .standalone := rfl
  unfold stgΦBC
  rw [hdefP]
  dsimp only
  rw [hsp, ite_eq_left ⟨hdeg, fun _ hm => absurd hm List.not_mem_nil⟩, hkind]
  dsimp only
  rw [heqSp]
  simp only [ite_eq_left hfit]
  unfold cubeSum
  -- the eq table at a cube point is the indicator of x0's point
  have hg0 : ∀ b : Fin (stgN P0 0) → Bool,
      stgTabK U hbij (atLog P (incElog I G.bLogN 0)) cs lw 1 (fun i => (bit (b i) : K)) (.eq (w.take lw) 0)
        = if b = bs then 1 else 0 := by
    intro b
    have hlen : (w.take lw).length = lw := by rw [List.length_take]; omega
    show (if 0 + (w.take lw).length ≤ lw then Block.selK lw 1 (fun i => (bit (b i) : K)) *
        eqPoly (fun a : Fin (w.take lw).length => (((w.take lw).getD a Fp2.zero).toK U))
          (fun a : Fin (w.take lw).length => Block.xrK lw (fun i => (bit (b i) : K)) (0 + a)) else 0) = _
    rw [ite_eq_left (by omega)]
    have hsel : Block.selK lw 1 (fun i => (bit (b i) : K)) = 1 - bit (b ⟨lw, by omega⟩) := by
      unfold Block.selK Block.yeK
      rw [Finset.prod_range_one, Nat.add_zero, xg_bitv b lw (by omega)]
    rw [hsel, eqPoly_bits _ (fun a => mb lw x0 a) (fun a => if h : a < stgN P0 0 then b ⟨a, h⟩ else false)
      (fun a => ((w.take lw).getD a Fp2.zero).toK U) (fun a => Block.xrK lw (fun i => (bit (b i) : K)) (0 + a))
      (fun a ha => by
        rw [List.getD_eq_getElem?_getD, List.getElem?_take, ite_eq_left (by omega), ← List.getD_eq_getElem?_getD]
        rw [hw, stgWords_getD_toK U hbij y0 a (by omega)])
      (fun a ha => by
        unfold Block.xrK
        rw [zero_add, ite_eq_left (by omega), xg_bitv b a (by omega), dite_eq_left (by omega)])]
    by_cases hb : b = bs
    · subst hb
      have hl : (bs ⟨lw, by omega⟩) = false := by simp [hbs]
      rw [hl, ite_eq_left, ite_eq_left rfl]
      · simp [bit]
      · intro a ha
        rw [dite_eq_left (by omega)]
        simp [hbs, show a < lw by omega]
    · rw [ite_eq_right hb]
      by_cases ha : ∀ a, a < (w.take lw).length → mb lw x0 a = (if h : a < stgN P0 0 then b ⟨a, h⟩ else false)
      · have hl : b ⟨lw, by omega⟩ = true := by
          by_contra hl
          apply hb
          funext i
          by_cases hi : i.val < lw
          · have := ha i.val (by omega)
            rw [dite_eq_left i.isLt] at this
            simp [hbs, hi, ← this]
          · have hil : i = ⟨lw, by omega⟩ := Fin.ext (by have h1 : i.val < lw + 1 := lt_of_lt_of_eq i.isLt hN; show i.val = lw; omega)
            rw [hil]
            simp only [hbs, lt_irrefl, decide_false, Bool.false_and]
            simpa using hl
        rw [hl]
        simp [bit]
      · rw [ite_eq_right ha, mul_zero]
  -- the support table at x0's point is zero
  have hg1 : stgTabK U hbij (atLog P (incElog I G.bLogN 0)) cs lw 1 (fun i => (bit (bs i) : K))
      (.pub (supp I.tokens I.inEpWords)) = 0 := by
    show (if (supp I.tokens I.inEpWords).length = 2 ^ lw then Block.selK lw 1 (fun i => (bit (bs i) : K)) *
        mleAt (fun b' : Fin lw → Bool => ((supp I.tokens I.inEpWords).getD (msbIndex lw b') Fp2.zero).toK U)
          (fun a : Fin lw => Block.xrK lw (fun i => (bit (bs i) : K)) a) else 0) = 0
    have hx : (fun a : Fin lw => Block.xrK lw (fun i => (bit (bs i) : K)) a)
        = fun a => bit (msbBits lw x0 a) := by
      funext a
      unfold Block.xrK
      rw [ite_eq_left a.isLt, xg_bitv bs a (by omega)]
      simp [hbs, a.isLt, mb_eq_msbBits]
    have hx0w : x0 < 2 ^ lw := by rw [hlw, hpow]; exact hx0
    rw [hx, mleAt_bit, msbIndex_msbBits lw x0 hx0w]
    have hz : (supp I.tokens I.inEpWords).getD x0 Fp2.zero = Fp2.zero := by
      simp [supp, List.getD_eq_getElem?_getD, hx0, Nat.not_lt.mpr hT]
    rw [hz, Fp2.toK_zero]
    split_ifs <;> simp
  rw [Finset.sum_eq_single bs]
  · simp only [polyK, tabs, restTabs, List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [hg0, ite_eq_left rfl, hg1]
    simp only [zero_mul, sub_zero, one_mul]
    rfl
  · intro b _ hb
    simp only [polyK, tabs, restTabs, List.map_cons, List.map_nil, List.getD_cons_zero]
    rw [hg0, ite_eq_right hb, zero_mul]
  · intro hm; exact absurd (Finset.mem_univ _) hm

end Phi

end ZK60.ProtocolClassify
