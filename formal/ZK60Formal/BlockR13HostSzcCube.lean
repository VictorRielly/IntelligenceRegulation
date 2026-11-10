/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 6: **`SC_SZC`'s cube sum, and `SC_RS`'s row differences and
`SC_SCORE`'s contraction in the planes**, generic in the configuration `c` and the softmax limb count `ls`.

* **`szcR_cube`**: `SC_SZC`'s cube sum is `Z̃(τ) + ν₀·2^lt·(S̃UM(p_ht) + λ) + ν₁·h̃₁(P₁)`, the batch `Z` the named
  relations (`r13Cl 17`) and `xcSzcR`, `h₁ = r13Gh 17 1`;
* `append_splitHt`, `xS_app`: `Dom::S`'s point from a row of `Dom::Ht` and a key token;
* **`rsA_algR`**, **`rsB_algR`**: `SC_RS`'s row differences `SUM − Σ_j mask·E`, `1 − Σ_j ZSEL`, embedded;
* **`mm171_algR`**: `SC_SCORE`'s contraction `Σ_c QR·KR` at a point of `Dom::S` made of its four blocks, embedded.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcVals

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Sound
open ZK60.Sound.SlotW16 (rs_host_cubeSum)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB aPl_alg cstK cstS_map sum_append eqT_eval)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (hostTerms gV)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## Small facts -/

section Small

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)

theorem msbIndex_castB {m n : ℕ} (h : m = n) (b : Fin m → Bool) : msbIndex n (castB h b) = msbIndex m b := by
  subst h
  rfl

include G in
/-- `Dom::S` is a row of `Dom::Ht` and a key token. -/
theorem hS_split : c.sh.logs .S = c.sh.logs .Ht + c.sh.lt := by
  rw [G.logS, G.logHt]
  show nH c + (c.sh.lt + c.sh.lt) = nH c + c.sh.lt + c.sh.lt
  omega

include G in
theorem lS_pos : 0 < c.sh.logs .S := by
  have := G.lt_pos
  rw [G.logS]
  show 0 < nH c + (c.sh.lt + c.sh.lt)
  omega

include G in
theorem lH_pos : 0 < c.sh.logs .Ht := by
  have := G.lt_pos
  rw [G.logHt]
  show 0 < nH c + c.sh.lt
  omega

end Small

/-! ## `SC_SZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include hX hrl in
/-- **`SC_SZC`'s cube sum** (`n = lS`): `Z̃(τ) + ν₀·2^lt·(S̃UM(p_ht) + λ) + ν₁·h̃₁(P₁)`, the batch `Z` the named
relations and `xcSzcR`, for any claim sites of the numbering. -/
theorem szcR_cube (hLay : LayR Lay) (hS : PrecR c S) (hls : ls ≤ 2) (hfp : c.p.fp ≤ 15) (hsc : c.p.score ≤ 24)
    (hlk : (DefR13.lookups c .S).length = 13 + 2 * ls) (aB hB ioIn ioOut ak hk n e : ℕ) (hn : n = c.sh.logs .S)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hmask : ∀ b : Fin (nS c) → Bool,
      ((pub 0).getD (msbIndex (nS c) b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS c b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((irSzcR c ls).map (Sym.eval hist 17 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabs17R c ls)).map (TabS.eval (Sym.eval hist 17 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = mleAt (fun b : Fin (c.sh.logs .S) → Bool => ∑ κ ∈ Finset.range (13 + ls),
          (((drsR 17 (c.sh.logs .S) (13 + ls)).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
          * (if κ < 5 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 κ (.s (xS G b)))
            else xcSzcR U G P D B (hist.beta, hist.gamma, hist.alpha) κ b))
        (W16.Szc.ptv U (Sym.eval hist 17 dr) 17 0 (c.sh.logs .S))
      + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * ((2 : K) ^ c.sh.lt * (mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r)
            (W16.Szc.ptv U (Sym.eval hist 17 dr) 4 0 (c.sh.logs .Ht))
          + (Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U))
      + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin (c.sh.logs .S) → Bool => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))))
          (W16.Szc.ptv U (Sym.eval hist 17 dr) 8 0 (c.sh.logs .S)) := by
  subst hn
  have hS' := hS_split G
  have hHS := hHS_logs G
  have hmk : ∀ b : Fin (c.sh.logs .S) → Bool,
      ((pub 0).getD (msbIndex (c.sh.logs .S) b) Fp2.zero).toK U = algebraMap GF K (B.mask (xS G b)) := by
    intro b
    rw [← msbIndex_castB G.logS b]
    exact hmask _
  rw [cubeSum_split]
  have hrow : ∀ b : Fin (c.sh.logs .S) → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (W16.Szc.ptv U (Sym.eval hist 17 dr) 17 0 (c.sh.logs .S)) (fun i => bit (b i))
          * ∑ κ ∈ Finset.range (13 + ls),
            (((drsR 17 (c.sh.logs .S) (13 + ls)).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
            * (if κ < 5 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 κ (.s (xS G b)))
              else xcSzcR U G P D B (hist.beta, hist.gamma, hist.alpha) κ b)
        + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (eqPoly (W16.Szc.ptv U (Sym.eval hist 17 dr) 4 0 (c.sh.logs .Ht)) (fun i => bit (hdB _ b i))
            * (aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b)
              + (Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U))
        + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (eqPoly (W16.Szc.ptv U (Sym.eval hist 17 dr) 8 0 (c.sh.logs .S)) (fun i => bit (b i))
            * algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b)))) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt _ e b) = _
      rw [hf, szcR_vals U c ls P D hrl (lS_pos G) (lH_pos G) hHS aB hB ioIn ioOut ak hk e b _ pub, hmk b]
      refine (szcR_point U G P D hX Pb B hLay hS hls hfp hsc hlk hist dr _ _ _ b).trans ?_
      rw [drsR_ptv U, drsR_ptv U, drsR_ptv U]
    · show f (bpt _ e b y) = 0
      rw [hf]
      unfold tabs17R irSzcR
      simp only [List.cons_append, List.nil_append, DefW16.numTabs, List.map_cons, eqT_eval]
      rw [r13SzcIr_map, r13SzcIr_map, cstS_map, r13SzcIr_eval _ (cstW_map_std U)]
      simp only [hostTerms, List.getD_cons_zero, List.getD_cons_succ, tabK_eq_off U P D _ e b y hy, zero_mul,
        mul_zero, add_zero]
  simp only [hrow]
  rw [Finset.sum_add_distrib, Finset.sum_add_distrib]
  have hB2 : ∑ b : Fin (c.sh.logs .S) → Bool,
        (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (eqPoly (W16.Szc.ptv U (Sym.eval hist 17 dr) 4 0 (c.sh.logs .Ht)) (fun i => bit (hdB _ b i))
            * (aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b)
              + (Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U))
      = (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * ((2 : K) ^ c.sh.lt * (mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r)
            (W16.Szc.ptv U (Sym.eval hist 17 dr) 4 0 (c.sh.logs .Ht))
          + (Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U)) := by
    rw [← Finset.mul_sum]
    congr 1
    rw [sum_bool_cast hS', sum_append]
    simp only [hdB_castB_append]
    have h2 := rs_host_cubeSum (b := c.sh.lt) (W16.Szc.ptv U (Sym.eval hist 17 dr) 4 0 (c.sh.logs .Ht))
      (fun _ => (1 : K)) (fun r => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r)
      ((Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U)
    simp only [one_mul] at h2
    rw [h2, W16.Szc.mleAt_add_c]
  have hC : ∑ b : Fin (c.sh.logs .S) → Bool,
        (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (eqPoly (W16.Szc.ptv U (Sym.eval hist 17 dr) 8 0 (c.sh.logs .S)) (fun i => bit (b i))
            * algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))))
      = (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin (c.sh.logs .S) → Bool => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))))
          (W16.Szc.ptv U (Sym.eval hist 17 dr) 8 0 (c.sh.logs .S)) := by
    rw [← Finset.mul_sum]
    rfl
  rw [hB2, hC]
  rfl

end Cube

/-! ## `SC_RS`'s row differences and `SC_SCORE`'s contraction, in the planes -/

section Rows

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

omit [Field K] [Algebra GF K] in
/-- `Dom::Ht`'s bit vector from its blocks. -/
theorem append_splitHt (y : Fin (nHt c) → Bool) :
    Fin.append (Fin.append (splitHt c y).1.1 (splitHt c y).1.2) (splitHt c y).2 = y := by
  funext i
  refine Fin.addCases (m := nH c) (n := c.sh.lt) (fun i4 => ?_) (fun i5 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (m := c.sh.lkv) (n := c.sh.lh - c.sh.lkv) (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

omit [Field K] [Algebra GF K] in
/-- **`Dom::S`'s point from a row of `Dom::Ht` and a key token.** -/
theorem xS_app (r : Fin (c.sh.logs .Ht) → Bool) (j : Fin c.sh.lt → Bool) :
    xS G (castB (hS_split G).symm (Fin.append r j))
      = ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j) := by
  have hH : c.sh.logs .Ht = c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.lt := G.logHt
  have hnH : nH c = c.sh.lkv + (c.sh.lh - c.sh.lkv) := rfl
  refine Prod.ext (Prod.ext ?_ ?_) (Prod.ext ?_ ?_)
  · funext i
    have hi := i.isLt
    simp only [xS, splitS, splitHt, castB]
    rw [appendV, dite_eq_left (by simp; omega)]
    exact congrArg r (Fin.ext (by simp))
  · funext i
    have hi := i.isLt
    simp only [xS, splitS, splitHt, castB]
    rw [appendV, dite_eq_left (by simp; omega)]
    exact congrArg r (Fin.ext (by simp))
  · funext i
    have hi := i.isLt
    simp only [xS, splitS, splitHt, castB]
    rw [appendV, dite_eq_left (by simp; omega)]
    exact congrArg r (Fin.ext (by simp))
  · funext i
    have hi := i.isLt
    simp only [xS, splitS, castB]
    rw [appendV, dite_eq_right (by simp; omega)]
    congr 1
    ext
    simp
    omega

include hX in
/-- A `Dom::Ht` plane at a row of `Dom::Ht` is the table's entry. -/
theorem alg_plHt_row (off : ℕ) (r : Fin (c.sh.logs .Ht) → Bool) :
    algebraMap GF K (plH U c P D off (splitHt c (castB G.logHt r))) = aPl U P D off (c.sh.logs .Ht) r := by
  unfold plH
  rw [append_splitHt, aPl_alg U P D hX, aPl_castB]

include hX in
/-- **`SC_RS`'s first row difference, embedded**: `SUM − Σ_j mask·E` (the gates are `1`). -/
theorem rsA_algR (hLay : LayR Lay) (r : Fin (c.sh.logs .Ht) → Bool) :
    algebraMap GF K (r13RsA Pb Lay B (xtR U c P D ls) (encHtR G r))
      = aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r - ∑ j : Fin c.sh.lt → Bool,
          algebraMap GF K (B.mask (xS G (castB (hS_split G).symm (Fin.append r j))))
            * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)) := by
  have e1 : r13RsA Pb Lay B (xtR U c P D ls) (encHtR G r)
      = B.gHt (splitHt c (castB G.logHt r)) * plH U c P D (offR c 5) (splitHt c (castB G.logHt r))
        - ∑ j : Fin c.sh.lt → Bool, B.gS ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j)
          * (B.mask ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j)
            * plS U c P D (offR c 80) ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j)) := rfl
  rw [e1, gHt_oneR B hLay, one_mul, map_sub, alg_plHt_row U G P D hX, map_sum]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [gS_oneR B hLay, one_mul, ← xS_app G r j, map_mul, alg_plS_R U G P D hX]

include hX in
/-- **`SC_RS`'s second row difference, embedded**: `1 − Σ_j ZSEL`. -/
theorem rsB_algR (hLay : LayR Lay) (r : Fin (c.sh.logs .Ht) → Bool) :
    algebraMap GF K (r13RsB Pb Lay B (xtR U c P D ls) (encHtR G r))
      = 1 - ∑ j : Fin c.sh.lt → Bool,
          aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)) := by
  have e1 : r13RsB Pb Lay B (xtR U c P D ls) (encHtR G r)
      = B.gHt (splitHt c (castB G.logHt r))
        - ∑ j : Fin c.sh.lt → Bool, B.gS ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j)
          * plS U c P D (offR c 79) ((splitHt c (castB G.logHt r)).1, (splitHt c (castB G.logHt r)).2, j) := rfl
  rw [e1, gHt_oneR B hLay, map_sub, map_one, map_sum]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [gS_oneR B hLay, one_mul, ← xS_app G r j, alg_plS_R U G P D hX]

omit [Field K] [Algebra GF K] in
/-- `Dom::S`'s point at a bit vector of its four blocks. -/
theorem xS_blocks (g : CgR c) (jj : CjR c) (t t' : CtR c) :
    xS G (castB G.logS.symm (Fin.append (Fin.append g jj) (Fin.append t t'))) = ((g, jj), t, t') := by
  unfold xS
  rw [castB_castB]
  exact splitS_append c ((g, jj), t, t')

include hX in
/-- **`SC_SCORE`'s contraction, embedded**, at a point of `Dom::S` made of its four blocks. -/
theorem mm171_algR (g : CgR c) (jj : CjR c) (t t' : CtR c) :
    algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 17 1
        (.s (xS G (castB G.logS.symm (Fin.append (Fin.append g jj) (Fin.append t t'))))))
      = ∑ d : CdR c, aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) (castB G.logQ.symm (Fin.append t (Fin.append (Fin.append g jj) d)))
          * aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) (castB G.logK.symm (Fin.append t' (Fin.append g d))) := by
  rw [xS_blocks G g jj t t']
  have e1 : r13Mm Pb Lay B (xtR U c P D ls) 17 1 (.s ((g, jj), t, t'))
      = ∑ d : CdR c, plQ U c P D (offR c 52) (t, ((g, jj), d)) * plK U c P D (offR c 71) (t', (g, d)) := rfl
  rw [e1, map_sum]
  refine Finset.sum_congr rfl (fun d _ => ?_)
  unfold plQ plK
  dsimp only
  rw [map_mul, aPl_alg U P D hX, aPl_alg U P D hX, aPl_castB, aPl_castB]

end Rows

end ZK60.Exec.Block.Join.R13H.Szc
