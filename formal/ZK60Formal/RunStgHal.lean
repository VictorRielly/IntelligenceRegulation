/-
D63 lane L53 (2026-11-10), part 4: **the top theorem's six stage alive premises at the lists** (deliverable 2,
assembled; L50's `ra_hal_*` at the two stage parts).

With the kinds data `D = rkData … (rxPs base …) …` and the stage parts' lists of `RunStgList.lean` (`StgLists (base 0)
…`, `StgLists (base (Lb + 1)) …`), on an accepted run of the classify schedule:

* `stg_D_lists`: the kinds data's stage parts carry those lists;
* **`stg_hal_sl`**: `hsl_stg`'s conclusion (both stages' slots alive at the end of the run's transcript), from each
  stage's terminal identities at its readings (`StgTermAt`), the lists' schedules having the stages' draws and slot
  shapes (`StgSame`) and hosting (`hhost`);
* **`stg_hal_r0`**: `hR0_stg`'s conclusion (both stages' define draws alive), from `StgDefAt`;
* **`stg_hal_nil`**: `hR1_stg`'s, `hH0_stg`'s and `hH1_stg`'s conclusions: the stages list nothing there;
* **`stg_hal_lu`**: `hLU_stg`'s conclusion (both stages' head LogUp runs alive), from `StgLkAt`.

The stage readings are the run's (`stg_inc_rd`, `stg_outc_rd`): the stages at parts `0` and `Lb + 1` of L34's schedule,
their contracts L39's `RtInc`, `RtOutc`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgRun

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

/-! ## The kinds data's stage parts -/

section DLists

variable {K : Type} [Field K] [Algebra GF K]

/-- **The kinds data's stage parts carry the stage lists**: part `0` `base 0`'s, part `Lb + 1` `base (Lb + 1)`'s. -/
theorem stg_D_lists (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) (D : RtKData K Lq)
    (hDe : D = rkData U tag Lq h64 key domain hs hL pf (rxPs base Lb din dblk dout) acc lsc eL)
    (slsI slsO : List (SlotX K Lq)) (defsI defsO : List (SqX K Lq)) (lkI lkO : SqX K Lq)
    (hb0 : StgLists (base 0) slsI defsI lkI) (hbL : StgLists (base (Lb + 1)) slsO defsO lkO) :
    (D.sls 0 = slsI ∧ D.r0 0 = defsI ∧ D.r1 0 = [] ∧ D.h0 0 = [] ∧ D.h1 0 = [] ∧ D.lu 0 = [lkI])
      ∧ (D.sls (Lb + 1) = slsO ∧ D.r0 (Lb + 1) = defsO ∧ D.r1 (Lb + 1) = [] ∧ D.h0 (Lb + 1) = []
        ∧ D.h1 (Lb + 1) = [] ∧ D.lu (Lb + 1) = [lkO]) := by
  subst hDe
  obtain ⟨a1, a2, a3, a4, a5, a6⟩ := stg_rxPs_0 base Lb din dblk dout
  obtain ⟨b1, b2, b3, b4, b5, b6⟩ := stg_rxPs_out base Lb din dblk dout
  exact ⟨⟨a1.trans hb0.hsls, a2.trans hb0.hr0, a3.trans hb0.hr1, a4.trans hb0.hh0, a5.trans hb0.hh1,
    a6.trans hb0.hlu⟩, ⟨b1.trans hbL.hsls, b2.trans hbL.hr0, b3.trans hbL.hr1, b4.trans hbL.hh0,
    b5.trans hbL.hh1, b6.trans hbL.hlu⟩⟩

end DLists

/-! ## The six conclusions at the stage parts -/

section Hal

variable {K : Type} [Field K] [Algebra GF K] (U : K)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **The run's two stage readings** on an accepted run of the classify schedule: stage IN-C at part `0` (header
`off 0 + 5`, `m = mIn`), stage OUT-C at part `Lb + 1` (header `off (Lb + 1) + 2`, `m = 2`). -/
theorem stg_rds
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (mIn : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ()) :
    (∃ hdr core ch rs, StgRd key domain Lq (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G (R.tr G (s, segs)) hdr core ch rs)
      ∧ ∃ hdr core ch rs, StgRd key domain Lq (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2)
        OutcV.bga G (R.tr G (s, segs)) hdr core ch rs := by
  have h0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by
    rw [hσ]
    exact rx_get0 (V := classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) _ _ _
  have h1 : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]
    exact rx_getOut (V := classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) _ _ _
  obtain ⟨hdr, core, ch, rs, hrd⟩ := stg_inc_rd R hv G s segs hE 0 pin inc incG cx0 h0 (Iin.hgeo s.hdr)
    (Iin.hgt s.hdr) (fun cx k hk => (Iin.hgeomL s.hdr cx k hk).1)
  obtain ⟨hdr', core', ch', rs', hrd'⟩ := stg_outc_rd R hv G s segs hE (Lb + 1) pout outc outcG h1
    (Oout.hgeo s.hdr s.verdict) (Oout.hgt s.hdr s.verdict) (fun k hk => (Oout.hgeomL s.hdr s.verdict k hk).1)
  rw [hmIn s.hdr] at hrd
  exact ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩

/-- **`hsl_stg`'s conclusion at the lists**: both stage parts' slots alive at the end of the run's transcript. -/
theorem stg_hal_sl (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (hL64 : Lq < 2 ^ 64) (hU : U ^ 2 = algebraMap GF K 7) (hL81 : 81 ≤ Lq)
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (mIn : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8))
    (P0in P0out : Block.BlockParams) (hostIn hostOut : ℕ → List (ℕ × ℕ))
    (FI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0in k) → K) → K)
    (FO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0out k) → K) → K)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hhIn : ∀ hd cx k hist dr df, ((inc hd).bp cx).define k hist dr = .ok df →
      df.hosted = (hostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhOut : ∀ hd v k hist dr df, (outc hd v).bp.define k hist dr = .ok df →
      df.hosted = (hostOut k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (D : RtKData K Lq)
    (hS0 : D.sls 0 = stgSchedX P0in mIn (R.pf.off 0 + 5) hostIn absOf FI)
    (hS1 : D.sls (Lb + 1) = stgSchedX P0out 2 (R.pf.off (Lb + 1) + 2) hostOut absOf FO)
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hTI : StgTermAt U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf FI G lg (R.tr G (s, segs)))
    (hTO : StgTermAt U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga
      absOf FO G lg (R.tr G (s, segs))) :
    allSt W1 (slotSubs U (slotsAt (D.sls 0) lg)) (R.tr G (s, segs))
      ∧ allSt W1 (slotSubs U (slotsAt (D.sls (Lb + 1)) lg)) (R.tr G (s, segs)) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hS0, hS1]
  refine ⟨?_, ?_⟩
  · exact stg_sl_rd U hU key domain hs hL hL64 hL81 P0in _ mIn _ hostIn absOf FI _ G lg _ hdr core ch rs hrd
      (hPin s.hdr _) (fun k hk => Iin.hgeomL s.hdr _ k hk) (Iin.hgt s.hdr) (hhIn s.hdr _) hTI
  · exact stg_sl_rd U hU key domain hs hL hL64 hL81 P0out _ 2 _ hostOut absOf FO _ G lg _ hdr' core' ch' rs' hrd'
      (hPout s.hdr s.verdict) (fun k hk => Oout.hgeomL s.hdr s.verdict k hk) (Oout.hgt s.hdr s.verdict)
      (hhOut s.hdr s.verdict) hTO

/-- **`hR0_stg`'s conclusion at the lists**: both stage parts' define draws alive at the end of the run's
transcript. -/
theorem stg_hal_r0
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (mIn : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8))
    (P0in P0out : Block.BlockParams)
    (ΦI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (D : RtKData K Lq)
    (hR0 : D.r0 0 = stgDefs P0in mIn (R.pf.off 0 + 5) absOf ΦI dgI)
    (hR1 : D.r0 (Lb + 1) = stgDefs P0out 2 (R.pf.off (Lb + 1) + 2) absOf ΦO dgO)
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hDI : StgDefAt U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf ΦI G lg (R.tr G (s, segs)))
    (hDO : StgDefAt U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga
      absOf ΦO G lg (R.tr G (s, segs))) :
    (∀ sx ∈ D.r0 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
      ∧ (∀ sx ∈ D.r0 (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hR0, hR1]
  refine ⟨?_, ?_⟩
  · exact stg_def_rd U key domain P0in _ mIn _ absOf ΦI dgI _ G lg _ hdr core ch rs hrd (hPin s.hdr _)
      (fun k hk => (Iin.hgeomL s.hdr _ k hk).1) (Iin.hgt s.hdr) hDI
  · exact stg_def_rd U key domain P0out _ 2 _ absOf ΦO dgO _ G lg _ hdr' core' ch' rs' hrd' (hPout s.hdr s.verdict)
      (fun k hk => (Oout.hgeomL s.hdr s.verdict k hk).1) (Oout.hgt s.hdr s.verdict) hDO

/-- **`hLU_stg`'s conclusion at the lists**: both stage parts' head LogUp runs alive at the end of the run's
transcript. -/
theorem stg_hal_lu
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (mIn : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8)) (eI eO : ℕ)
    (ΛI ΛO : (ℕ → List (QB Lq × Dig)) → List (List UInt8 × K) → Prop) (D : RtKData K Lq)
    (hL0 : D.lu 0 = [stgLkSq mIn (R.pf.off 0 + 5) eI absOf ΛI])
    (hL1 : D.lu (Lb + 1) = [stgLkSq 2 (R.pf.off (Lb + 1) + 2) eO absOf ΛO])
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hLI : StgLkAt U key domain (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf ΛI G lg (R.tr G (s, segs)))
    (hLO : StgLkAt U key domain (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga absOf ΛO G lg
      (R.tr G (s, segs))) :
    (∀ sx ∈ D.lu 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
      ∧ (∀ sx ∈ D.lu (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hL0, hL1]
  refine ⟨fun sx hsx => ?_, fun sx hsx => ?_⟩
  · rw [List.mem_singleton] at hsx
    subst hsx
    exact stg_lk_rd U key domain _ mIn _ eI absOf ΛI _ G lg _ hdr core ch rs hrd hLI
  · rw [List.mem_singleton] at hsx
    subst hsx
    exact stg_lk_rd U key domain _ 2 _ eO absOf ΛO _ G lg _ hdr' core' ch' rs' hrd' hLO

end Hal

/-- **`hR1_stg`'s, `hH0_stg`'s and `hH1_stg`'s conclusions**: the stage parts list nothing in those kinds. -/
theorem stg_hal_nil {K : Type} [Field K] [Algebra GF K] (U : K) {Lq : ℕ} (sxs : ℕ → List (SqX K Lq)) (Lb : ℕ)
    (h0 : sxs 0 = []) (h1 : sxs (Lb + 1) = []) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) :
    (∀ sx ∈ sxs 0, subSt W1 (sqSub U sx lg) τ) ∧ (∀ sx ∈ sxs (Lb + 1), subSt W1 (sqSub U sx lg) τ) := by
  rw [h0, h1]
  exact ⟨fun _ h => absurd h List.not_mem_nil, fun _ h => absurd h List.not_mem_nil⟩

end ZK60.ProtocolClassify
