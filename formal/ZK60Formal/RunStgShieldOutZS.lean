/-
D63 lane L63 (2026-11-19), L63 leg 13, part 86: **OUTC-07 ZS's zero sum `Σ u = 0` from its define polynomial**
(step 1 of HANDOFF_20261119_2.md, the generic half; the OUT-C twin of RunStgShieldIncZS.lean, whose define polynomial
`sshΦO` is `stgΦB`, not `stgΦBC`).

* **`ssh_defAllB`**: `ssh_defAll`'s vanishing at EVERY slot for the real `stgΦB` / `stgFR` / `StgTrueAt` (the same
  proof as `ssh_defAtV`, without the drawing restriction);
* **`ssh_hDO_all`**: `ssh_hDO` at every slot of stage OUT-C (part `i`), at `τ`'s view;
* `stgΦB_sa_evalT`: a standalone `stgΦB` with no `eq` table is its table side's cube sum (`stgΦBC_sa_evalT`'s twin);
* **`shd_zsO_of_phi`**: at an OUT-C schedule `Vo` with `lt = 12`, slot `7`'s define polynomial `0` is `Σ u = 0` of
  the `H_out` plane `u` (`shdOutcHd`'s fourth helper).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutSum
import ZK60Formal.RunStgShieldIncZS

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. The real define polynomial vanishes at every slot -/

section AllB

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **`ssh_defAtV` AT EVERY SLOT** (the drawing ones and the others), at `τ`'s view: the same hypotheses. -/
theorem ssh_defAllB (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
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
    (hlP : VwLoc nl Pv) (hlC : VwLoc nl csv) (hlR : VwLoc nl Rv) (hlM : VwLoc nl msv)
    (hslot : StgSlotStartAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) G Lg τ)
    (htrue : StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ)
    (hmH : (∀ k, hostOf k = []) ∨ StgHostTrueAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
      ∀ k, k < P0.geom.slots.length → ∃ r, rs[k]? = some r ∧ r.draws.length = P0.draws k ∧
        stgΦB U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch)
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
  obtain ⟨hPv, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  rw [hwinS k q hq Pv hlP] at hPv
  rw [hwinS k q hq msv hlM] at hMt
  refine ssh_ΦB_zero U hbij hU P0 (Pof ch) (csv (stgVw absOf Lg τ)) core (bgaOf ch) rs acc hcan hlen hall hostOf
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
    have hstm : ((stgSlotV P0 m hdrLen hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) j).at Lg).stmt tj
        = (stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j), r'.claimed) := by
      show (match StageFS.tSeenS P0 hdrLen m j tj with
        | some (sn, _) => (stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j sn, stgClaim hostOf j sn)
        | none => (fun _ => 0, Fp2.zero)) = _
      rw [stg_tSeenS (hP ch), hseen']
      simp only
      rw [hclj]
    have h0 : scSt U (Block.slotShape P0 j).2.2 (stgN P0 j)
        ((stgSlotV P0 m hdrLen hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) j).at Lg).stmt tj [] := hst
    unfold scSt at h0
    rw [hstm] at h0
    have hF : stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j)
        = fun x => stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x := by
      funext x
      show stgPolyT U hbij (Pv (stgVw absOf Lg tj) ch) (csv (stgVw absOf Lg tj)) j (Block.seenOf (bgaOf ch) rs j) x
          + (((Block.seenOf (bgaOf ch) rs j).2.getD j ([], Fp2.zero, [])).2.1).toK U
            * maskPoly (Rv (stgVw absOf Lg tj)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x = _
      rw [hW Pv hlP, hW csv hlC, hW Rv hlR, hPv, Block.seenOf_c (bgaOf ch) rs j r' hr']
      congr 1
      refine stgPolyT_congr U hbij (Pof ch) _ j _ _ ?_ ?_ x
      · rw [Block.histSeen_seenOf, histSeen_stgSnD, ← List.map_take]
        rfl
      · rw [Block.drSeen_seenOf (bgaOf ch) rs j r' hr', drSeen_stgSnD, List.getD_eq_getElem?_getD,
          List.getElem?_map, hr']
        rfl
    rw [hF] at h0
    have hdegF : IndDegLE (Block.slotShape P0 j).2.2 (fun x =>
        stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) :=
      IndDegLE.add_smul hg (maskPoly_indDeg _ j _ _ hd0) _
    have hsw : Block.swk (Pof ch) j = Cfs.sumWeights (stgN P0 j) (Block.slotShape P0 j).2.2 := by
      unfold Block.swk stgN
      rw [stg_slotShape (hP ch)]
    rcases h0 with h | h
    · exact absurd hdegF h
    · have h' : r'.claimed.toK U = cubeSum (fun x =>
          stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
            + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) := h
      rw [h', cubeSum_add_smul, hsw, maskPoly_cubeSum U hU hbij _ Wd j (stgN P0 j) _ hN0 hN64 hNW]

end AllB

section DOall

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
  (tag : MTag) (h64 : 64 ≤ Lq)

/-- **`ssh_hDO` AT EVERY SLOT** of stage OUT-C (part `i`), at `τ`'s view. -/
theorem ssh_hDO_all (hU : U ^ 2 = algebraMap GF K 7) (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n)
    (Pof : List Fp2 → Block.BlockParams) (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH S : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (stgHostOut P0 k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64)
    (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hS : D.sls i = stgSchedV P0 2 hdrLen (stgHostOut P0) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstO U hbij tag h64 P0 (vdWout F) n0 hdrLen lc h Q e rA rH S csIO))
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (htrue : StgTrueAt U key domain Pof 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun v _ => ((vdWout F) (v.2.take n0)).bp)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) (stgMsv U tag h64 S (hdrLen + 3)) G lg τ)
    (hhf : StgHostTrueAt U key domain Pof 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgMsv U tag h64 S (hdrLen + 3)) G lg τ) :
    ∀ hdr core ch rs, StgRd key domain Lq Pof 2 hdrLen OutcV.bga G τ hdr core ch rs →
      ∀ k, k < P0.geom.slots.length → ∃ r, rs[k]? = some r ∧ r.draws.length = P0.draws k ∧
        stgΦB U hbij P0 (Pof ch)
          (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
          (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k r.draws = 0 := by
  have hslot := ssh_slotStart key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin P0 Pof 2 hdrLen
    OutcV.bga (stgHostOut P0) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgFstO U hbij tag h64 P0 (vdWout F) n0 hdrLen lc h Q e rA rH S csIO) G lg τ hP hgt hS hns
  exact ssh_defAllB U hbij hU key domain P0 Pof 2 hdrLen _ (stgHostOut P0) _ _ _ (stgRv U tag h64 S (hdrLen + 3))
    (stgMsv U tag h64 S (hdrLen + 3)) 512 G lg τ hP hgt hd hhost (ssh_hostOut2 P0)
    (fun k hk => ⟨(hN k hk).1, hN64 k hk, (hN k hk).2⟩) (stgMsv_mlin U tag h64 S (hdrLen + 3))
    (hdrLen + (7 + 2)) le_rfl (vwLoc_vdWout F n0 _ (by omega))
    (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) _ (by omega) (by omega) csIO hIOl)
    (vwLoc_stgRv U tag h64 S (hdrLen + 3) _ (by omega)) (vwLoc_stgMsv U tag h64 S (hdrLen + 3) _ (by omega))
    hslot htrue (Or.inr hhf)

end DOall

/-! ## 2. A standalone `stgΦB` with no `eq` table -/

section EvalT

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **A STANDALONE `stgΦB` WITH NO `eq` TABLE IS ITS TABLE SIDE'S CUBE SUM.** -/
theorem stgΦB_sa_evalT {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg : ℕ)
    (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
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
    stgΦB U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd k w
      = if tabsFit n tabs then
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx =>
            (tabs.map (stgTabK U hbij P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD idx 0))
        else 0 := by
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have htake : (hd ++ [w]).take k = hd := by
    rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
  have hgetD : (hd ++ [w]).getD k [] = w := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
    simp [hhd]
  have hdef' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [w]).take k⟩
      ((hd ++ [w]).getD k []) = .ok ⟨tabs, poly, []⟩ := by
    rw [htake, hgetD]; exact hdef
  obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 P hP
    lc h Q eC rA rH iA iH pOk csIO v hlc hIOd bga (hd ++ [w]) k n e sdeg hsh _ _ _ hdef' hok hcan
    polyK hpK hpDeg
  have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [w]) k)
      ∧ ∀ hk ∈ ([] : List (ℕ × Fp2)), IndDegLE (Block.slotShape P0 hk.1).2.2
          (stgSpT U hbij P0 P cs bga (hd ++ [w]) hk.1) :=
    ⟨hdegSp, fun _ hm => absurd hm List.not_mem_nil⟩
  unfold stgΦB
  rw [hdef]
  dsimp only
  rw [ite_eq_left hguard, hkind]
  dsimp only
  rw [heqSp]
  by_cases hfit : tabsFit n tabs
  · simp only [hfit, ↓reduceIte]
    rfl
  · simp only [hfit, ↓reduceIte]
    unfold cubeSum; simp

end EvalT

/-! ## 3. OUTC-07 ZS: slot `7`'s define polynomial `0` is `Σ u = 0` -/

section ZSo

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **OUTC-07 ZS: SLOT `7`'S DEFINE POLYNOMIAL `0` IS `Σ u = 0`** at an OUT-C schedule `Vo` with `lt = 12` (the
`H_out` plane `u` of `shdOutcHd` at `O`, `outcLay Vo.pub 14 = outcLay O 14`, at the claims' semantics' view `v`). -/
theorem shd_zsO_of_phi (hU : U ^ 2 = algebraMap GF K 7) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (O : OutcPub) (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14)
    (hlt : Vo.pub.lt = 12) (hlc : 0 < Vo.bp.logCols) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (v : StgVw Lq) (bga : Fp2 × Fp2 × Fp2)
    (hd : List (List Fp2)) (hhd : hd.length = 7) (w : List Fp2)
    (hΦ : stgΦB U hbij P0 Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO v) bga hd 7 w = 0) :
    ∑ j, (shdOutcHd U tag h64 O rH iH v).2.2.2 j = 0 := by
  set Lo := outcLay Vo.pub Vo.geo.bLogN with hLo
  have hsh : Block.slotShape Vo.bp 7 = (12, 1, 2) := by
    show (Vo.pub.lt, 1, 2) = _
    rw [hlt]
  have hN : stgN P0 7 = 12 + 1 := by
    unfold stgN; rw [stg_slotShape hP, hsh]
  have hlog : Lo.hLog.getD ocH_U 0 = 12 := by
    show Vo.pub.lt = 12
    exact hlt
  have hdef := outcDefZS_ok Vo.pub Vo.geo
  have hdef' : Vo.bp.define 7 ⟨bga.1, bga.2.1, bga.2.2, hd⟩ w
      = .ok ⟨[.pub (List.replicate (2 ^ Lo.hLog.getD ocH_U 0) Fp2.one),
        .priv ⟨.h, [((Lo.hOff ocH_U).1, Fp2.one), ((Lo.hOff ocH_U).2, Block.fp2U)],
          Lo.hLog.getD ocH_U 0, rhoC 0 (Lo.hLog.getD ocH_U 0), Lo.hMaskBase + 2 * (Lo.prefixH 7 + 0), 0⟩],
        zsPoly, []⟩ := hdef
  have hIOd : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO := by
    intro _ _ _ _ _ _ _ _ _ hp
    exact hp.elim
  have hev := stgΦB_sa_evalT U hbij hU tag h64 P0 Vo.bp hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    (fun _ => False) csIO v (by show Vo.pub.lt ≤ 12; omega) bga hd 7 12 1 2 hIOd hhd rfl hsh w _ _ hdef'
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
  have hfit : tabsFit 12 [.pub (List.replicate (2 ^ Lo.hLog.getD ocH_U 0) Fp2.one),
      .priv ⟨.h, [((Lo.hOff ocH_U).1, Fp2.one), ((Lo.hOff ocH_U).2, Block.fp2U)],
        Lo.hLog.getD ocH_U 0, rhoC 0 (Lo.hLog.getD ocH_U 0), Lo.hMaskBase + 2 * (Lo.prefixH 7 + 0), 0⟩] := by
    intro t ht
    simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · show (List.replicate (2 ^ Lo.hLog.getD ocH_U 0) Fp2.one).length = 2 ^ 12
      rw [List.length_replicate, hlog]
    · trivial
  rw [ite_eq_left hfit] at hev
  rw [hev] at hΦ
  simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ] at hΦ
  have hNlt : 12 < stgN P0 7 := by rw [hN]; omega
  rw [cube_sel_split 12 hN _ (fun w hw => by
    have hz : stgTabK U hbij Vo.bp
        (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO v) 12 1
        (fun i => (bit (w i) : K)) (.pub (List.replicate (2 ^ Lo.hLog.getD ocH_U 0) Fp2.one)) = 0 := by
      unfold stgTabK stgTabW
      dsimp only
      rw [ite_eq_left (by rw [List.length_replicate, hlog]), selK_ext1 12 hN w hw, zero_mul]
    rw [hz, zero_mul])] at hΦ
  rw [← hΦ]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  have hrep : (List.replicate (2 ^ Lo.hLog.getD ocH_U 0) Fp2.one).getD (msbIndex 12 b) Fp2.zero
      = Fp2.one := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, hlog]
    simp only [show msbIndex 12 b < 2 ^ 12 from msbIndex_lt 12 b, ↓reduceIte, Option.getD_some]
  rw [stgTabK_pub_cptS U hbij _ _ 12 b hN _ (by rw [List.length_replicate, hlog]), hrep, Fp2.toK_one, one_mul]
  symm
  refine (stgTabK_priv_cptS U hbij hU _ _ rH ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH v) (by decide) 12 b hN _ (by intro _; rfl)
    (by exact List.cons_ne_nil _ _) (by show 0 < Lo.hLog.getD ocH_U 0; omega) (by simp [rhoC])
    (by exact hlc)
    (by intro c hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
  rw [privZ_eq_planeZ U _ _ _ _ 12 b hNlt _
    [(((outcLay O 14).hOff ocH_U).1, Fp2.one), (((outcLay O 14).hOff ocH_U).2, Block.fp2U)] .h
    (by show [((Lo.hOff ocH_U).1, Fp2.one), ((Lo.hOff ocH_U).2, Block.fp2U)] = _; rw [hLo, hGb, hOL]) hlog rfl]
  rfl

end ZSo

end ZK60.ProtocolClassify
