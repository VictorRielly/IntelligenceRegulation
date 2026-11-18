/-
D63 lane L63 (2026-11-18), part 72: **INC-00's define polynomial at the bits of a TOKEN position is the input endpoint's
entry minus `A_TOK`'s** (`hdinX`, split (a) of HANDOFF_20261118_4.md section 5, the algebraic half).

INC-00 is `eq·(end − supp_T·tok)` (`incDefIO_ok`). At the draws `y0` = the bits of a word `x0 < T` (msb first) the
define polynomial's only non-zero cube term is `x0`'s point with extension bit `0`, where `supp_T = 1`: the value is
`end(x*) − tok(x*)`; `end(x*)` is the input endpoint matrix's entry of `x0` (`ssh_endClaim_bool`) and `tok(x*)` the
`A_in` token plane at `msbBits 12 x0` (the table's point is four fixed zero coordinates, then `x0`'s eight bits).

* `ptK_fixZ_rho`, `privZ_slog`: helpers;
* **`ssh_inc0_Φ_tok`**: `stgΦBC … 0 (stgWords y0) = XI v (x0 / 2^8) (x0 mod 2^8) − A_TOK(msbBits 12 x0)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncBT
import ZK60Formal.RunStgShieldIOPin

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Help

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A claim point of `m` fixed zero coordinates, then `rho 0 … rho (n − 1)`, read at a reader `xr`. -/
theorem ptK_fixZ_rho (xr : ℕ → K) (m n a : ℕ) (ha : a < m + n) :
    Block.ptK U xr (fixedC (List.replicate m Fp2.zero) ++ rhoC 0 n) a = if a < m then 0 else xr (a - m) := by
  unfold Block.ptK fixedC rhoC
  by_cases hm : a < m
  · rw [ite_eq_left hm, List.getElem?_append_left (by simp; omega)]
    simp [hm, Block.coordK, Fp2.toK_zero]
  · rw [ite_eq_right hm, List.getElem?_append_right (by simp; omega)]
    have hl : (List.map Block.Coord.fixed (List.replicate m Fp2.zero)).length = m := by simp
    rw [hl, List.getElem?_map, List.getElem?_range' (by omega)]
    simp [Block.coordK]

/-- The data functional reads a table's slices and size only. -/
theorem privZ_slog (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (p p' : Block.Priv)
    (hs : p.slices = p'.slices) (hl : p.log = p'.log) (z : ℕ → K) :
    Block.Join.privZ U lc R Q X p z = Block.Join.privZ U lc R Q X p' z := by
  unfold Block.Join.privZ
  rw [hs, hl]

end Help

section Phi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **INC-00'S DEFINE POLYNOMIAL AT THE BITS OF A TOKEN POSITION**: the input endpoint matrix's entry of the word minus
the `A_in` token plane at the position's twelve bits (stage IN-C at `tiLog = 12`, `lw = 8`). -/
theorem ssh_inc0_Φ_tok (hU : U ^ 2 = algebraMap GF K 7) (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch))) (lc h Q eC rA rH iA iH : ℕ)
    (Rr rO lcO QO : ℕ) (XI : StgVw L → Fin Rr → Fin (2 ^ 8 + 256) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) (v : StgVw L) (hlc : Vi.pub.lt ≤ lc) (hlc0 : 0 < lc)
    (hrl : 0 < (Vi.bp (incCtx Vi.pub ch)).logCols)
    (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hti : Vi.pub.tiLog = 12) (hlw8 : clog2 Vi.pub.inEpWords = 8)
    (x0 : ℕ) (hT : x0 < Vi.pub.tokens) (hx0 : x0 < Vi.pub.inEpWords) (hR : x0 / 2 ^ 8 < Rr) :
    stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
        (stgCsv U tag h64 lc h Q eC rA rH iA iH (stgCsIOm U Rr 8 256 rO lcO QO XI XO) v)
        (Fp2.zero, Fp2.zero, Fp2.zero) [] 0
        (stgWords U hbij (fun a : Fin (P0.draws 0) => (bit (mb (clog2 Vi.pub.inEpWords) x0 a) : K)))
      = XI v ⟨x0 / 2 ^ 8, hR⟩ ⟨x0 % 2 ^ 8, by have := Nat.mod_lt x0 (Nat.two_pow_pos 8); omega⟩
        - stgPlK U tag h64 lc h Q eC rA iA ((incLay Vi.pub Vi.geo.bLogN).aOff incA_TOK) 12 v (msbBits 12 x0) := by
  -- the slot's data
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set P := Vi.bp (incCtx I ch) with hPdef
  set lw := clog2 I.inEpWords with hlw
  set L0 := incLay I G.bLogN with hL0
  set csIO := stgCsIOm U Rr 8 256 rO lcO QO XI XO with hcsIO
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  set y0 : Fin (P0.draws 0) → K := fun a => bit (mb lw x0 a) with hy0
  set w := stgWords U hbij y0 with hw
  set bs : Fin (stgN P0 0) → Bool := fun i => decide (i.val < lw) && mb lw x0 i with hbs
  have hIO0 : StgCsIODeg U hbij I.epLogN (IncPrivIO0 I) csIO :=
    ssh_hIO0m U hbij hU Vi Rr 8 256 rO lcO QO XI XO (by rw [hep])
  have hdraws : P0.draws 0 = lw := by rw [hP.1]; rfl
  have hN : stgN P0 0 = lw + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have hwl : w.length = lw := by rw [hw, stgWords_length, hdraws]
  have hlw8' : lw = 8 := hlw8
  have hx0w : x0 < 2 ^ lw := by rw [hlw, hpow]; exact hx0
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
  -- the point's readers
  have hxr : ∀ a, a < lw → Block.xrK lw (fun i => (bit (bs i) : K)) a = bit (mb lw x0 a) := by
    intro a ha
    unfold Block.xrK
    rw [ite_eq_left ha, xg_bitv _ a (by omega)]
    simp [hbs, ha]
  have hsel : Block.selK lw 1 (fun i => (bit (bs i) : K)) = 1 := by
    unfold Block.selK Block.yeK
    rw [Finset.prod_range_one, Nat.add_zero, xg_bitv _ lw (by omega)]
    simp [bit, hbs]
  have hcm : Block.cmK lw 1 (fun i => (bit (bs i) : K)) 0 = 0 := by
    unfold Block.cmK Block.yeK
    rw [Nat.add_zero, xg_bitv _ lw (by omega)]
    simp [bit, hbs]
  -- the support table at x0's point is one
  have hg1 : stgTabK U hbij (atLog P (incElog I G.bLogN 0)) cs lw 1 (fun i => (bit (bs i) : K))
      (.pub (supp I.tokens I.inEpWords)) = 1 := by
    show (if (supp I.tokens I.inEpWords).length = 2 ^ lw then Block.selK lw 1 (fun i => (bit (bs i) : K)) *
        mleAt (fun b' : Fin lw → Bool => ((supp I.tokens I.inEpWords).getD (msbIndex lw b') Fp2.zero).toK U)
          (fun a : Fin lw => Block.xrK lw (fun i => (bit (bs i) : K)) a) else 0) = 1
    have hx : (fun a : Fin lw => Block.xrK lw (fun i => (bit (bs i) : K)) a)
        = fun a => bit (msbBits lw x0 a) := by
      funext a
      rw [hxr a a.isLt, mb_eq_msbBits]
    rw [hx, mleAt_bit, msbIndex_msbBits lw x0 hx0w]
    have hz : (supp I.tokens I.inEpWords).getD x0 Fp2.zero = Fp2.one := by
      simp [supp, List.getD_eq_getElem?_getD, hx0, hT]
    rw [hz, Fp2.toK_one, ite_eq_left (by rw [hsuppl, hlw, hpow]), hsel, one_mul]
  -- the endpoint table at x0's point is the matrix entry
  have hep' : (atLog P (incElog I G.bLogN 0)).endpointLogN = 8 := by
    show incElog I G.bLogN 0 = 8
    unfold incElog; rw [ite_eq_left rfl, hep]
  have hg3 : stgTabK U hbij (atLog P (incElog I G.bLogN 0)) cs lw 1 (fun i => (bit (bs i) : K))
      (.priv ⟨.inp, [(0, Fp2.one)], lw, rhoC 0 lw, G.epDataRows, 0⟩)
      = XI v ⟨x0 / 2 ^ 8, hR⟩ ⟨x0 % 2 ^ 8, by have := Nat.mod_lt x0 (Nat.two_pow_pos 8); omega⟩ :=
    ssh_endClaim_bool U hbij hU _ 8 hep' Rr 256 (XI v) lw 1 hN _ lw G.epDataRows x0 rfl (by omega) (by omega)
      hx0w hR hxr hsel hcm
  -- the token table at x0's point is the `A_in` token plane at `msbBits 12 x0`
  have hlwle : lw ≤ I.tiLog := by omega
  have hbs' : (fun i : Fin (stgN P0 0) => (bit (bs i) : K))
      = fun i => (bit (cptS lw (fun a : Fin lw => mb lw x0 a) i) : K) := by
    funext i
    by_cases hi : i.val < lw
    · simp [hbs, cptS, hi]
    · simp [hbs, cptS, hi]
  have hg2 : stgTabK U hbij (atLog P (incElog I G.bLogN 0)) cs lw 1 (fun i => (bit (bs i) : K))
      (.priv ⟨.a, [(L0.aOff incA_TOK, Fp2.one)], L0.aLog.getD incA_TOK 0,
        fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw, L0.aMaskBase + 2 * (L0.prefixA 0 + 0), 0⟩)
      = stgPlK U tag h64 lc h Q eC rA iA (L0.aOff incA_TOK) 12 v (msbBits 12 x0) := by
    rw [hbs']
    refine (stgTabK_priv_cptS U hbij hU (atLog P (incElog I G.bLogN 0)) cs rA lc Q
      (stgIOX tag h64 lc h Q eC rA iA v) hlc0 lw _ hN _ (fun _ => rfl) (List.cons_ne_nil _ _)
      (by show 0 < I.tiLog; omega)
      (by show (fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw).length = I.tiLog
          simp [rhoC, fixedC]; omega)
      (by exact hrl)
      (by
        intro c hc w' hw'
        rcases List.mem_append.mp hc with hc | hc
        · simp only [fixedC, List.mem_map, List.mem_replicate] at hc
          obtain ⟨a, ⟨-, rfl⟩, rfl⟩ := hc
          have he := Block.Coord.fixed.inj hw'
          subst he
          exact Fp2.canon_zero
        · simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw')).trans ?_
    refine (privZ_slog U lc rA Q _ _ ⟨.a, [(L0.aOff incA_TOK, Fp2.one)], 12, [], 0, 0⟩ (by rfl)
      (by show I.tiLog = 12; exact hti) _).trans ?_
    rw [privZ_mleF U (atLog P (incElog I G.bLogN 0)) lc rA Q _ hlc0 _ (List.cons_ne_nil _ _) (by norm_num)]
    have hz : (fun a : Fin 12 => Block.ptK U (Block.xrK lw (fun i : Fin (stgN P0 0) =>
          (bit (cptS lw (fun a : Fin lw => mb lw x0 a) i) : K)))
          (fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw) a.val)
        = fun a => (bit (msbBits 12 x0 a) : K) := by
      funext a
      have ha := a.isLt
      rw [ptK_fixZ_rho U _ (I.tiLog - lw) lw a.val (by omega)]
      by_cases ham : a.val < I.tiLog - lw
      · rw [ite_eq_left ham]
        have hb : msbBits 12 x0 a = false := by
          unfold msbBits
          have hd : x0 / 2 ^ (12 - 1 - a.val) = 0 :=
            Nat.div_eq_of_lt (lt_of_lt_of_le hx0w (Nat.pow_le_pow_right (by norm_num) (by omega)))
          rw [hd]
          simp
        rw [hb]
        simp [bit]
      · rw [ite_eq_right ham, xrK_cptS lw _ (a.val - (I.tiLog - lw)) (by omega) (by omega)]
        show (bit (mb lw x0 (a.val - (I.tiLog - lw))) : K) = bit (msbBits 12 x0 a)
        unfold mb msbBits
        have he : lw - 1 - (a.val - (I.tiLog - lw)) = 12 - 1 - a.val := by omega
        rw [he]
    show mleAt _ (fun a : Fin 12 => _) = _
    rw [hz, mleAt_bit]
    rfl
  rw [Finset.sum_eq_single bs]
  · simp only [polyK, tabs, restTabs, List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [hg0, ite_eq_left rfl, hg1, hg2, hg3, one_mul, one_mul]
  · intro b _ hb
    simp only [polyK, tabs, restTabs, List.map_cons, List.map_nil, List.getD_cons_zero]
    rw [hg0, ite_eq_right hb, zero_mul]
  · intro hm; exact absurd (Finset.mem_univ _) hm

end Phi

end ZK60.ProtocolClassify
