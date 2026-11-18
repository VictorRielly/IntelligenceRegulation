/-
D63 lane L63 (2026-11-18), part 67: **SIC_ZS's zero sum `Σ u = 0` at a reading** (item 4b, step 1, the second of
`ShdIncSumAt`'s two facts).

* **`ssh_defAll`**: `ssh_defAtVC`'s vanishing at EVERY slot of the stage, not only the drawing ones (the same proof:
  the slot's start state, `StgTrueAtC`, `M`'s functionals), stated at `τ`'s view;
* `incDefZS_ok`: INC-03's `define` (tables `[ones, H u]`, polynomial `t0·t1`);
* `stgΦBC_sa_evalT`: a standalone define polynomial with no `eq` table is its table side's cube sum (lane L65's
  `stgSpT_eval_and_deg`; `stgΦBC_sa_eval` without the `eq` table);
* `cube_sel_split`: a cube sum over `n` main variables and one extension variable whose summand vanishes at the
  extension bit `1` is the sum over the main cube at `(b, 0)`;
* **`shd_zs_of_phi`**: at the registered stage IN-C, slot `3`'s define polynomial `0` is `Σ u = 0` of the `H_in`
  plane `u` (`shdIncHd`'s third helper);
* **`shd_hLI_of_rd`**: `shd_hLI_of_sum` with the sum facts required only at the readings.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncSum

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.RunShape (ClassifyRunPublicP)

/-! ## 1. The define polynomial vanishes at every slot -/

section All

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **`ssh_defAtVC` AT EVERY SLOT** (the drawing ones and the others), at `τ`'s view: the same hypotheses. -/
theorem ssh_defAll (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (Rv : StgVw L → ℕ → ℕ → K) (msv : StgVw L → List (ℕ × List Fp2) → K) (Wd : ℕ)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhost2 : ∀ k, ∀ x ∈ hostOf k, hostOf x.1 = [])
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k < 64
      ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ Wd)
    (hlin : ∀ v, Block.MLin U (msv v) (Rv v) Wd)
    (nl : ℕ) (hnl : nl ≤ hdrLen + (7 + m))
    (hlP : VwLoc nl Pv) (hlE : VwLoc nl elogv) (hlC : VwLoc nl csv) (hlR : VwLoc nl Rv) (hlM : VwLoc nl msv)
    (hslot : StgSlotStartAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) G Lg τ)
    (htrue : StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ)
    (hmH : (∀ k, hostOf k = []) ∨ StgHostTrueAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
      ∀ k, k < P0.geom.slots.length → ∃ r, rs[k]? = some r ∧ r.draws.length = P0.draws k ∧
        stgΦBC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch)
          ((rs.take k).map Block.SlotRec.draws) k r.draws = 0 := by
  intro hdr core ch rs hrd k hkP0
  obtain ⟨-, -, hcan, hsh, ⟨acc, t', hacc⟩, -⟩ := id hrd
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  obtain ⟨hlen, hall, hdraw, hseen, hscal⟩ :=
    ssh_rd_facts key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) (hd ch) acc t' hacc
  have hkc : k < core.slots.length := by rw [hslen, ← (hP ch).2]; exact hkP0
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkc⟩
  obtain ⟨r, hr⟩ : ∃ r, rs[k]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  refine ⟨r, hr, by rw [(hdraw k r hr).2, (hP ch).1], ?_⟩
  -- every window of the stage is a prefix of `τ` at a position at least `nl`
  have hwinS : ∀ j q', core.slots[j]? = some q' → ∀ {β : Type} (f : StgVw L → β), VwLoc nl f →
      f (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take j)
            ++ Block.slotPreOps (Pof ch) j q'))) = f (stgVw absOf Lg τ) := by
    intro j q' hq' β f hf
    obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) j q' hq'
    rw [← h1]
    exact vw_take absOf Lg nl _ (by unfold stgDefPos; omega) f hf τ
  -- the schedule the reader reads, and `M`'s functionals
  obtain ⟨hPv, -, -, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  rw [hwinS k q hq Pv hlP] at hPv
  rw [hwinS k q hq msv hlM] at hMt
  refine ssh_ΦB_zeroC U hbij hU P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) core (bgaOf ch) rs acc hcan hlen hall hostOf
    (hhost ch) hhost2 (msv (stgVw absOf Lg τ)) (Rv (stgVw absOf Lg τ)) Wd (hlin _) hMt ?_ ?_ k r hr
  · rcases hmH with h0 | h0
    · exact Or.inl h0
    · refine Or.inr ?_
      have h3 := h0 hdr core ch rs hrd acc t' hacc k q hq
      rwa [hwinS k q hq msv hlM] at h3
  · intro j r' hr' hg
    have hj : j < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr').1
    obtain ⟨q', hq'⟩ : ∃ q', core.slots[j]? = some q' := ⟨_, List.getElem?_eq_getElem hj⟩
    have hjP0 : j < P0.geom.slots.length := by rw [(hP ch).2, ← hslen]; exact hj
    obtain ⟨hN0, hN64, hNW⟩ := hN j hjP0
    have hd0 : 1 ≤ (Block.slotShape P0 j).2.2 := by
      rw [stg_slotShape (hP ch)]
      exact hd ch j (by rw [← hslen]; exact hj)
    obtain ⟨tj, htj⟩ : ∃ tj, tj = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take j)
          ++ Block.slotPreOps (Pof ch) j q') := ⟨_, rfl⟩
    have hW : ∀ {β : Type} (f : StgVw L → β), VwLoc nl f → f (stgVw absOf Lg tj) = f (stgVw absOf Lg τ) := by
      intro β f hf
      rw [htj]
      exact hwinS j q' hq' f hf
    have hst := hslot hdr core ch rs hrd j q' hq'
    rw [← htj] at hst
    have hseen' := hseen j q' hq'
    rw [← htj] at hseen'
    have hclj : stgClaim hostOf j (StageFS.seenOfS ch rs j) = r'.claimed := by
      obtain ⟨dfj, hdfj, -, hhsj, hscj, -⟩ := hall j q' r' hq' hr'
      refine stgClaim_seenOfS hostOf ch rs j r' hr' hscal ?_
      rw [hscj, ← hhost ch j _ r'.draws dfj hdfj]
      exact hhsj
    have hstm : ((stgSlotV P0 m hdrLen hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) j).at Lg).stmt tj
        = (stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j), r'.claimed) := by
      show (match StageFS.tSeenS P0 hdrLen m j tj with
        | some (sn, _) => (stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j sn, stgClaim hostOf j sn)
        | none => (fun _ => 0, Fp2.zero)) = _
      rw [stg_tSeenS (hP ch), hseen']
      simp only
      rw [hclj]
    have h0 : scSt U (Block.slotShape P0 j).2.2 (stgN P0 j)
        ((stgSlotV P0 m hdrLen hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) j).at Lg).stmt tj [] := hst
    unfold scSt at h0
    rw [hstm] at h0
    have hF : stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j)
        = fun x => stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x := by
      funext x
      show stgPolyT U hbij (StageV.atLog (Pv (stgVw absOf Lg tj) ch) (elogv (stgVw absOf Lg tj) j))
          (csv (stgVw absOf Lg tj)) j (Block.seenOf (bgaOf ch) rs j) x
          + (((Block.seenOf (bgaOf ch) rs j).2.getD j ([], Fp2.zero, [])).2.1).toK U
            * maskPoly (Rv (stgVw absOf Lg tj)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x = _
      rw [hW Pv hlP, hW elogv hlE, hW csv hlC, hW Rv hlR, hPv, Block.seenOf_c (bgaOf ch) rs j r' hr']
      congr 1
      refine stgPolyT_congr U hbij (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg τ) j)) _ j _ _ ?_ ?_ x
      · rw [Block.histSeen_seenOf, histSeen_stgSnD, ← List.map_take]
        rfl
      · rw [Block.drSeen_seenOf (bgaOf ch) rs j r' hr', drSeen_stgSnD, List.getD_eq_getElem?_getD,
          List.getElem?_map, hr']
        rfl
    rw [hF] at h0
    have hdegF : IndDegLE (Block.slotShape P0 j).2.2 (fun x =>
        stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) :=
      IndDegLE.add_smul hg (maskPoly_indDeg _ j _ _ hd0) _
    have hsw : Block.swk (Pof ch) j = Cfs.sumWeights (stgN P0 j) (Block.slotShape P0 j).2.2 := by
      unfold Block.swk stgN
      rw [stg_slotShape (hP ch)]
    rcases h0 with h | h
    · exact absurd hdegF h
    · have h' : r'.claimed.toK U = cubeSum (fun x =>
          stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
            + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) := h
      rw [h', cubeSum_add_smul, hsw, maskPoly_cubeSum U hU hbij _ Wd j (stgN P0 j) _ hN0 hN64 hNW]

end All

/-! ## 2. INC-03 and its define polynomial -/

section ZS

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **INC-03's `define`**: tables `[ones, H u]`, polynomial `t0·t1`. -/
theorem incDefZS_ok (I : IncPub) (G : IncGeo) :
    let L := incLay I G.bLogN
    incDefZS I G = .ok ⟨[
      .pub (List.replicate (2 ^ L.hLog.getD incH_U 0) Fp2.one),
      .priv ⟨.h, [((L.hOff incH_U).1, Fp2.one), ((L.hOff incH_U).2, Block.fp2U)],
        L.hLog.getD incH_U 0, rhoC 0 (L.hLog.getD incH_U 0), L.hMaskBase + 2 * (L.prefixH 3 + 0), 0⟩
    ], (fun v => (vg v 0).mul (vg v 1)), []⟩ := by
  intro L; unfold incDefZS; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 3 incH_U _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 3 _ [] _ rfl rfl rfl

open Classical in
/-- **A STANDALONE DEFINE POLYNOMIAL WITH NO `eq` TABLE IS ITS TABLE SIDE'S CUBE SUM.** -/
theorem stgΦBC_sa_evalT {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg : ℕ)
    (hIOd : StgCsIODeg U hbij (elog k) pOk csIO)
    (hhd : hd.length = k)
    (hkind : P.kind k = .standalone) (hsh : Block.slotShape P k = (n, e, sdeg))
    (w : List Fp2) (tabs : List Block.Tab) (poly : List Fp2 → Fp2)
    (hdef : P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ w = .ok ⟨tabs, poly, []⟩)
    (hok : ∀ t ∈ tabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ tabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyK : (ℕ → K) → K)
    (hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDeg : ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyK (fun idx => g idx x))) :
    stgΦBC U hbij P0 P elog (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd k w
      = if tabsFit n tabs then
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx =>
            (tabs.map (stgTabK U hbij (StageV.atLog P (elog k))
              (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD idx 0))
        else 0 := by
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have htake : (hd ++ [w]).take k = hd := by
    rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
  have hgetD : (hd ++ [w]).getD k [] = w := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
    simp [hhd]
  have hdef' : (StageV.atLog P (elog k)).define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [w]).take k⟩
      ((hd ++ [w]).getD k []) = .ok ⟨tabs, poly, []⟩ := by
    rw [htake, hgetD]; exact hdef
  obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 (StageV.atLog P (elog k)) hP
    lc h Q eC rA rH iA iH pOk csIO v hlc hIOd bga (hd ++ [w]) k n e sdeg hsh _ _ _ hdef' hok hcan
    polyK hpK hpDeg
  have hsp : stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) k
      = stgSpT U hbij P0 (StageV.atLog P (elog k)) cs bga (hd ++ [w]) k := rfl
  have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) k)
      ∧ ∀ hk ∈ ([] : List (ℕ × Fp2)), IndDegLE (Block.slotShape P0 hk.1).2.2
          (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) hk.1) :=
    ⟨hdegSp, fun _ hm => absurd hm List.not_mem_nil⟩
  unfold stgΦBC
  rw [hdef]
  dsimp only
  rw [ite_eq_left hguard, hkind]
  dsimp only
  rw [hsp, heqSp]
  by_cases hfit : tabsFit n tabs
  · simp only [hfit, ↓reduceIte]
    rfl
  · simp only [hfit, ↓reduceIte]
    unfold cubeSum; simp

omit [Algebra GF K] in
/-- `sel = 0` at an extension bit `1`. -/
theorem selK_ext1 {N : ℕ} (n : ℕ) (hN : N = n + 1) (w : Fin N → Bool) (hw : w ⟨n, by omega⟩ = true) :
    Block.selK n 1 (fun i : Fin N => (bit (w i) : K)) = 0 := by
  unfold Block.selK Block.yeK Block.xg
  rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
  dsimp only
  rw [hw]
  simp [bit]

omit [Algebra GF K] in
/-- **A cube sum whose summand vanishes at the extension bit `1` is the main cube's sum at `(b, 0)`.** -/
theorem cube_sel_split {N : ℕ} (n : ℕ) (hN : N = n + 1) (F : (Fin N → K) → K)
    (h1 : ∀ w : Fin N → Bool, w ⟨n, by omega⟩ = true → F (fun i => bit (w i)) = 0) :
    cubeSum F = ∑ b : Fin n → Bool, F (fun i => bit (cptS n b i)) := by
  subst hN
  unfold cubeSum
  rw [Block.Join.W16.sum_append (a := n) (b := 1)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hcpt : Fin.append t (fun _ : Fin 1 => false) = cptS n t := by
    funext i
    refine Fin.addCases (fun a => ?_) (fun a => ?_) i
    · rw [Fin.append_left]
      unfold cptS
      rw [dite_eq_left (show (Fin.castAdd 1 a).val < n from a.isLt)]
      rfl
    · rw [Fin.append_right]
      unfold cptS
      rw [dite_eq_right (show ¬ (Fin.natAdd n a).val < n by simp)]
  rw [Finset.sum_eq_single (fun _ : Fin 1 => false)]
  · rw [hcpt]
  · intro c _ hc
    have hc0 : c 0 = true := by
      by_contra h0
      apply hc
      funext j
      have hj : j = 0 := Subsingleton.elim _ _
      rw [hj]
      simpa using h0
    refine h1 (Fin.append t c) ?_
    have e : (⟨n, by omega⟩ : Fin (n + 1)) = Fin.natAdd n (0 : Fin 1) := rfl
    rw [e, Fin.append_right]
    exact hc0
  · intro hn; exact absurd (Finset.mem_univ _) hn

end ZS

section ZSi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **SIC_ZS: SLOT `3`'S DEFINE POLYNOMIAL `0` IS `Σ u = 0`** at the registered stage IN-C (the `H_in` plane `u` of
`shdIncHd`, at the claims' semantics' view `v`). -/
theorem shd_zs_of_phi (hU : U ^ 2 = algebraMap GF K 7) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) (cx : IncCtx) (elog : ℕ → ℕ) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (v : StgVw Lq) (bga : Fp2 × Fp2 × Fp2)
    (hd : List (List Fp2)) (hhd : hd.length = 3) (w : List Fp2)
    (hΦ : stgΦBC U hbij (shdP_P0in tag Rp embDigest embFold bInRow)
      ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) elog
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO v) bga hd 3 w = 0) :
    ∑ j, (shdIncHd U tag h64 (shdP_incV tag Rp embDigest embFold bInRow).pub ogStage.lc ogStage.h ogStage.Q
      ogStage.e rH iH v).2.2 j = 0 := by
  set I := shdP_incPub Rp embDigest embFold with hI
  set Gg := shdP_incGeo bInRow with hGg
  have hP : StgSame (shdP_P0in tag Rp embDigest embFold bInRow) ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) :=
    shdP_hPin (Hdr := Unit) tag Rp embDigest embFold bInRow () cx
  have hsh : Block.slotShape ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) 3 = (12, 1, 2) := by
    rw [← stg_slotShape hP]
    unfold Block.slotShape
    rw [shdP_P0in_slots tag Rp embDigest embFold bInRow]
    rfl
  have hN : stgN (shdP_P0in tag Rp embDigest embFold bInRow) 3 = 12 + 1 := by
    unfold stgN; rw [stg_slotShape hP, hsh]
  have hlt : (incLay I 14).hLog.getD incH_U 0 = 12 := rfl
  have hdef := incDefZS_ok I Gg
  have hdef' : ((shdP_incV tag Rp embDigest embFold bInRow).bp cx).define 3 ⟨bga.1, bga.2.1, bga.2.2, hd⟩ w
      = .ok ⟨[.pub (List.replicate (2 ^ (incLay I 14).hLog.getD incH_U 0) Fp2.one),
        .priv ⟨.h, [(((incLay I 14).hOff incH_U).1, Fp2.one), (((incLay I 14).hOff incH_U).2, Block.fp2U)],
          (incLay I 14).hLog.getD incH_U 0, rhoC 0 ((incLay I 14).hLog.getD incH_U 0),
          (incLay I 14).hMaskBase + 2 * ((incLay I 14).prefixH 3 + 0), 0⟩],
        (fun v => (vg v 0).mul (vg v 1)), []⟩ := hdef
  have hIOd : StgCsIODeg U hbij (elog 3) (fun _ => False) csIO := by
    intro _ _ _ _ _ _ _ _ _ hp
    exact hp.elim
  have hev := stgΦBC_sa_evalT U hbij hU tag h64 (shdP_P0in tag Rp embDigest embFold bInRow)
    ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) elog hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    (fun _ => False) csIO v (by show 12 ≤ 12; exact le_rfl) bga hd 3 12 1 2 hIOd hhd rfl hsh w _ _ hdef'
    (fun t ht => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · exact tabPrivOK_pub _ _
      · exact tabPrivOK_h_rho _ _ _ _ _)
    (fun t ht pt s he => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl <;> cases he)
    (fun f => f 0 * f 1)
    (fun vals _ => by
      show ((vg vals 0).mul (vg vals 1)).toK U = _
      rw [Fp2.toK_mul U hU, vg_toK_map, vg_toK_map])
    (fun g hg => IndDegLE.mul (hg 0) (hg 1))
  have hfit : tabsFit 12 [.pub (List.replicate (2 ^ (incLay I 14).hLog.getD incH_U 0) Fp2.one),
      .priv ⟨.h, [(((incLay I 14).hOff incH_U).1, Fp2.one), (((incLay I 14).hOff incH_U).2, Block.fp2U)],
        (incLay I 14).hLog.getD incH_U 0, rhoC 0 ((incLay I 14).hLog.getD incH_U 0),
        (incLay I 14).hMaskBase + 2 * ((incLay I 14).prefixH 3 + 0), 0⟩] := by
    intro t ht
    simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · show (List.replicate (2 ^ (incLay I 14).hLog.getD incH_U 0) Fp2.one).length = 2 ^ 12
      rw [List.length_replicate, hlt]
    · trivial
  rw [ite_eq_left hfit] at hev
  rw [hev] at hΦ
  simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ] at hΦ
  have hNlt : 12 < stgN (shdP_P0in tag Rp embDigest embFold bInRow) 3 := by rw [hN]; omega
  rw [cube_sel_split 12 hN _ (fun w hw => by
    have hz : stgTabK U hbij (StageV.atLog ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) (elog 3))
        (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO v) 12 1
        (fun i => (bit (w i) : K)) (.pub (List.replicate (2 ^ (incLay I 14).hLog.getD incH_U 0) Fp2.one)) = 0 := by
      unfold stgTabK stgTabW
      dsimp only
      rw [ite_eq_left (by rw [List.length_replicate, hlt]), selK_ext1 12 hN w hw, zero_mul]
    rw [hz, zero_mul])] at hΦ
  rw [← hΦ]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  have hrep : (List.replicate (2 ^ (incLay I 14).hLog.getD incH_U 0) Fp2.one).getD (msbIndex 12 b) Fp2.zero
      = Fp2.one := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, hlt]
    simp only [show msbIndex 12 b < 2 ^ 12 from msbIndex_lt 12 b, ↓reduceIte, Option.getD_some]
  rw [stgTabK_pub_cptS U hbij _ _ 12 b hN _ (by rw [List.length_replicate, hlt]), hrep, Fp2.toK_one, one_mul]
  symm
  refine (stgTabK_priv_cptS U hbij hU _ _ rH ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH v) (by decide) 12 b hN _ (by intro _; rfl)
    (by exact List.cons_ne_nil _ _) (by show 0 < 12; omega) (by simp [rhoC, hlt])
    (by exact shdN_lc tag Rp embDigest embFold bInRow cx)
    (by intro c hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
  rw [privZ_eq_planeZ U _ _ _ _ 12 b hNlt _
    [(((incLay I 14).hOff incH_U).1, Fp2.one), (((incLay I 14).hOff incH_U).2, Block.fp2U)] .h rfl hlt rfl]
  rfl

end ZSi

end ZK60.ProtocolClassify
