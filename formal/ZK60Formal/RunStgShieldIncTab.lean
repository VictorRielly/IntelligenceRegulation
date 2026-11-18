/-
D63 lane L63 (2026-11-18), part 58: **a slot's tables at the cube point `(b, 0)`** (item 4b, step 4 of
HANDOFF_20261118_2.md, the generic half).

At the point `(b, 0)` (`cptS`), where `sel = 1` and every mask coefficient is `0`:
* **`stgTabK_pub_cptS`**: a public table is its entry at `b`'s index;
* `claimK_privSpecs_sel`, **`claimSem_build_sel`**: a private table's claim is its functional WITHOUT the mask parts
  (`privZ`) at its claim point (L41's `tabK_priv_sel`, restated at a free matrix `X`);
* **`stgTabK_priv_cptS`**: so a private table on a commitment whose claims are `claimSem` on `X` is `privZ` there;
* `ptK_rhoC_cptS`, **`privZ_rho_cptS`**: on a table of the main variables `0 … log − 1` it is the plane at `b`;
* `privZ_mleF`: at any point, the claim functional is the plane's multilinear extension (L41's `privZ_mle` at a
  free matrix, through a `CmData` whose row log is `lc`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncEval

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Tab

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **A public table at `(b, 0)` is its entry at `b`'s index.** -/
theorem stgTabK_pub_cptS (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (n : ℕ)
    (b : Fin n → Bool) (hN : N = n + 1) (pv : List Fp2) (hl : pv.length = 2 ^ n) :
    stgTabK U hbij P cs n 1 (fun i : Fin N => (bit (cptS n b i) : K)) (.pub pv)
      = (pv.getD (msbIndex n b) Fp2.zero).toK U := by
  unfold stgTabK stgTabW
  dsimp only
  rw [ite_eq_left hl, selK_cptS n b hN, one_mul]
  have e : (fun a : Fin n => Block.xrK n (fun i : Fin N => (bit (cptS n b i) : K)) a.val)
      = fun a => (bit (b a) : K) := by
    funext a
    exact xrK_cptS n b a.val a.isLt (by omega)
  rw [e, mleAt_bit]

omit [Algebra GF K] in
/-- `build_claim`'s parts at `sel = 1` and mask coefficient `0`: the data parts alone. -/
theorem claimK_privSpecs_sel [Algebra GF K] (P : Block.BlockParams) (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K)
    {N : ℕ} (n e : ℕ) (x : Fin N → K) (p : Block.Priv) (hsl : p.slices ≠ [])
    (hsel : Block.selK n e x = 1) (hcm : Block.cmK n e x p.extRound = 0) (pt : ℕ → K) :
    Block.claimK lc R Q X ((Block.privSpecs U P n e p).map (Block.specPart pt x))
      = Block.Join.privZ U lc R Q X p pt := by
  obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
  have hspecs : Block.privSpecs (N := N) U P n e p = Block.dataSpec U n e p.log sc0
      :: (rest.map (Block.dataSpec U n e p.log)
      ++ [Block.maskSpec n e (p.maskRow * 2 ^ Block.rowLog P p.cm + Block.privC0 P p)
            (min p.log (Block.rowLog P p.cm)) (p.log - min p.log (Block.rowLog P p.cm)) p.extRound (Fp2.one.toK U),
          Block.maskSpec n e ((p.maskRow + 1) * 2 ^ Block.rowLog P p.cm + Block.privC0 P p)
            (min p.log (Block.rowLog P p.cm)) (p.log - min p.log (Block.rowLog P p.cm)) p.extRound
            (Block.fp2U.toK U)]) := by
    unfold Block.privSpecs
    rw [hs]
    rfl
  rw [hspecs, Block.claimK_specs]
  unfold Block.Join.privZ
  rw [hs]
  simp only [List.map_cons, Block.claimK]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  congr 1
  · rw [List.map_append, List.sum_cons, List.sum_cons, List.sum_append]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.map_map]
    simp only [Block.dataSpec, Block.maskSpec, hsel, hcm, mul_one, zero_mul, add_zero, Nat.zero_add]
    congr 1
    refine congrArg List.sum (List.map_congr_left (fun sc _ => ?_))
    simp only [Function.comp_apply, Block.dataSpec, hsel, mul_one, Nat.zero_add]
  · refine Finset.sum_congr rfl (fun t _ => ?_)
    simp only [Block.dataSpec, Nat.zero_add]

/-- **A private table's claim at `sel = 1` and mask coefficient `0` is its data functional at its claim point.** -/
theorem claimSem_build_sel (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams) (R lc Q : ℕ)
    (X : Fin R → Fin (2 ^ lc + Q) → K) (hlc : 0 < lc) {N : ℕ} (n e : ℕ) (x : Fin N → K) (hN : N = n + e)
    (p : Block.Priv) (hsl : p.slices ≠ []) (hlog : 0 < p.log) (hlen : p.coords.length = p.log)
    (hrl : 0 < Block.rowLog P p.cm) (hcan : ∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon)
    (hsel : Block.selK n e x = 1) (hcm : Block.cmK n e x p.extRound = 0) (v : Fp2) :
    claimSem U R lc Q X (Block.buildClaim P p (Block.claimPoint p ((stgWords U hbij x).take n))
        (Block.oneMinusProd ((stgWords U hbij x).drop n)) (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) v)
      = Block.Join.privZ U lc R Q X p (Block.ptK U (Block.xrK n x) p.coords) := by
  set rho := (stgWords U hbij x).take n with hrho_def
  set es := (stgWords U hbij x).drop n with hes_def
  have hrho : rho.length = n := by rw [hrho_def, List.length_take, stgWords_length]; omega
  have hes : es.length = e := by rw [hes_def, List.length_drop, stgWords_length]; omega
  have hNl : (rho ++ es).length ≤ N := by rw [List.length_append, hrho, hes, hN]
  have hrc : ∀ a ∈ rho, a.Canon := fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_take ha)
  have hec : ∀ a ∈ es, a.Canon := fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_drop ha)
  have hx : (Block.xOf U (rho ++ es) : Fin N → K) = x := xOf_take_drop_stgWords U hbij n x
  obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
  have hpl : (Block.claimPoint p rho).length = p.log := by
    unfold Block.claimPoint
    rw [List.length_map, hlen]
  have hpc : ∀ a ∈ Block.claimPoint p rho, a.Canon := by
    intro a ha
    unfold Block.claimPoint at ha
    obtain ⟨c, hc, rfl⟩ := List.mem_map.mp ha
    cases c with
    | rho j => exact Fp2.canon_getD hrc j
    | flip j => exact Fp2.canon_sub _ _ Fp2.canon_one (Fp2.canon_getD hrc j)
    | fixed w => exact hcan _ hc w rfl
  have hparts := Block.buildClaim_parts P p (Block.claimPoint p rho) (Block.oneMinusProd es)
    (Block.maskCoef es p.extRound) v
  have hz : (Block.buildClaim P p (Block.claimPoint p rho) (Block.oneMinusProd es) (Block.maskCoef es p.extRound)
      v).parts
        = (⟨sc0.1, p.log, sc0.2.mul (Block.oneMinusProd es), Block.claimPoint p rho⟩ : Block.ZPart)
          :: (rest.map (fun sc => (⟨sc.1, p.log, sc.2.mul (Block.oneMinusProd es), Block.claimPoint p rho⟩ : Block.ZPart))
            ++ [⟨p.maskRow * 2 ^ Block.rowLog P p.cm + Block.privC0 P p, min p.log (Block.rowLog P p.cm),
                  (Block.maskCoef es p.extRound).mul Fp2.one,
                  (Block.claimPoint p rho).drop (p.log - min p.log (Block.rowLog P p.cm))⟩,
                ⟨(p.maskRow + 1) * 2 ^ Block.rowLog P p.cm + Block.privC0 P p, min p.log (Block.rowLog P p.cm),
                  (Block.maskCoef es p.extRound).mul Block.fp2U,
                  (Block.claimPoint p rho).drop (p.log - min p.log (Block.rowLog P p.cm))⟩]) := by
    rw [hparts, hs]
    rfl
  have hokp : ∀ q ∈ (Block.buildClaim P p (Block.claimPoint p rho) (Block.oneMinusProd es)
      (Block.maskCoef es p.extRound) v).parts, Block.PartOK q := by
    intro q hq
    rw [hparts] at hq
    have hdrop : ((Block.claimPoint p rho).drop (p.log - min p.log (Block.rowLog P p.cm))).length
        = min p.log (Block.rowLog P p.cm) := by
      rw [List.length_drop, hpl]
      omega
    have hdc : ∀ a ∈ (Block.claimPoint p rho).drop (p.log - min p.log (Block.rowLog P p.cm)), a.Canon :=
      fun a ha => hpc a (List.mem_of_mem_drop ha)
    rcases List.mem_append.mp hq with hq | hq
    · obtain ⟨sc, -, rfl⟩ := List.mem_map.mp hq
      exact ⟨hlog, hpl, hpc, Fp2.canon_mul _ _⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
      rcases hq with rfl | rfl
      · exact ⟨lt_min hlog hrl, hdrop, hdc, Fp2.canon_mul _ _⟩
      · exact ⟨lt_min hlog hrl, hdrop, hdc, Fp2.canon_mul _ _⟩
  have hxr : ∀ j, Block.xrK n (Block.xOf U (rho ++ es) : Fin N → K) j = (rho.getD j Fp2.zero).toK U :=
    fun j => Block.xrK_xOf U n rho es hrho hNl j
  have hsel' := Block.toK_oneMinusProd U hU n e rho es hrho hes hNl hec
  have hcm' := Block.toK_maskCoef U hU n e rho es hrho hes hNl hec p.extRound
  rw [hx] at hxr hsel' hcm'
  rw [Block.claimSem_parts U hU _ _ _ _ hlc _ _ _ hz hokp,
    Block.buildClaim_partsK U hU P n e p (Block.claimPoint p rho) (Block.oneMinusProd es) (Block.maskCoef es p.extRound)
      v x (fun a => Block.claimPoint_getD_toK U p rho hrc _ hxr a) hsel' hcm']
  exact claimK_privSpecs_sel U P lc R Q X n e x p hsl hsel hcm _

/-- **A private table at `(b, 0)` on a commitment whose claims are `claimSem` on `X` is `privZ` at its point.** -/
theorem stgTabK_priv_cptS (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams)
    (cs : Block.Cm → Block.ZClaim → K) (R lc Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (hlc : 0 < lc)
    {N : ℕ} (n : ℕ) (b : Fin n → Bool) (hN : N = n + 1) (p : Block.Priv)
    (hcs : ∀ z, cs p.cm z = claimSem U R lc Q X z)
    (hsl : p.slices ≠ []) (hlog : 0 < p.log) (hlen : p.coords.length = p.log) (hrl : 0 < Block.rowLog P p.cm)
    (hcan : ∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon) :
    stgTabK U hbij P cs n 1 (fun i : Fin N => (bit (cptS n b i) : K)) (.priv p)
      = Block.Join.privZ U lc R Q X p (Block.ptK U (Block.xrK n (fun i : Fin N => (bit (cptS n b i) : K))) p.coords) := by
  unfold stgTabK stgTabW
  dsimp only
  rw [hcs]
  exact claimSem_build_sel U hbij hU P R lc Q X hlc n 1 _ hN p hsl hlog hlen hrl hcan (selK_cptS n b hN)
    (cmK_cptS n b hN _) Fp2.zero

/-- The coordinates `rho lo … rho (hi − 1)` read at a reader `xr`. -/
theorem ptK_rhoC (xr : ℕ → K) (lo hi q : ℕ) (hq : q < hi - lo) :
    Block.ptK U xr (rhoC lo hi) q = xr (lo + q) := by
  unfold Block.ptK rhoC
  rw [List.getElem?_map, List.getElem?_range' hq]
  simp [Block.coordK]

/-- The coordinates `rho lo … rho (hi − 1)`, then the fixed words `r`, read at a reader `xr`. -/
theorem ptK_rhoC_fixed (xr : ℕ → K) (lo hi : ℕ) (r : List Fp2) (q : ℕ) (hq : hi - lo ≤ q) :
    Block.ptK U xr (rhoC lo hi ++ fixedC r) q = ((r.getD (q - (hi - lo)) Fp2.zero).toK U) := by
  unfold Block.ptK rhoC fixedC
  have hl : ((List.range' lo (hi - lo)).map Block.Coord.rho).length = hi - lo := by simp
  rw [List.getElem?_append_right (by omega), hl, List.getElem?_map]
  rw [List.getD_eq_getElem?_getD]
  cases h : r[q - (hi - lo)]? with
  | none => simp [Fp2.toK_zero]
  | some w => rfl

/-- **On a table of the main variables `0 … log − 1`, the data functional at `(b, 0)` is the plane at `b`.** -/
theorem privZ_rho_cptS (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) {N : ℕ} (n : ℕ) (b : Fin n → Bool)
    (hN : n < N) (p : Block.Priv) (hc : p.coords = rhoC 0 p.log) (hlog : p.log ≤ n) :
    Block.Join.privZ U lc R Q X p (Block.ptK U (Block.xrK n (fun i : Fin N => (bit (cptS n b i) : K))) p.coords)
      = Block.Join.planeZ U lc R Q X p (fun a => b ⟨a.val, by omega⟩) := by
  unfold Block.Join.planeZ
  refine Block.Join.privZ_congr U _ _ _ _ p _ _ (fun a ha => ?_)
  rw [hc, ptK_rhoC U _ 0 p.log a (by omega), Nat.zero_add, xrK_cptS n b a (by omega) hN, dite_eq_left ha]

/-- **At any point the data functional is the plane's multilinear extension** (at a free matrix). -/
theorem privZ_mleF (P : Block.BlockParams) (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (hlc : 0 < lc)
    (p : Block.Priv) (hsl : p.slices ≠ []) (hlog : 0 < p.log) (z : ℕ → K) :
    Block.Join.privZ U lc R Q X p z
      = mleAt (Block.Join.planeZ U lc R Q X p) (fun a : Fin p.log => z a) := by
  let P' : Block.BlockParams := { P with logCols := lc }
  let D : Block.CmData K P' := ⟨fun _ => R, fun _ => Q, fun cm => match cm with
    | .a => X
    | .h => fun _ _ => 0
    | .inp => fun _ _ => 0
    | .out => fun _ _ => 0⟩
  exact Block.Join.privZ_mle U P' D { p with cm := .a } hsl hlog hlc z

end Tab

end ZK60.ProtocolClassify
