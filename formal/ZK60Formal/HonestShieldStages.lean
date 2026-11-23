/-
D63 lane L68c, part 1 (`HonestShieldStages.lean`):
Shieldstral T128 R13 stage IN-C and stage OUT-C completeness (`StageInOK`, `StageOutOK`, `SegComplete`)
wired directly to `shdP_incV` / `rcIncGeom` and `shdP_outcV` / `rcOutcGeom` (`RunShieldOpenShell.lean` /
`RunStgShieldClTopEF.lean`).

Resolves three L25/L29/L32 integration traps cleanly with ZERO edits to upstream files:
1. Bounded slot-degree loop lemmas (`stSlotsLoop_of_prove_bd`, `slotsLoop_of_prove_bd` from `HonestShieldCore.lean`)
   discharged by `rc_incBounds` / `rc_outcBounds` (eliminating L25/L29's vacuous `∀ s, 1 ≤ slotD P s`).
2. Transcript-indexed `StageInP` / `StageOutP` provers (`shdP_incP`, `shdP_outcP`) compatible with
   L32's `incDataAt` / `shdP_outcDataAt` (finding L32-1).
3. Repaired `own` predicate in `shdP_outcDataAt` checking BOTH `cr.root = rootOf H tag 16 C.TB` AND
   `∀ cl ∈ cr.pending, ClaimTrue shdP_U (2^14) 14 C.TB.rows (toZClaim cl)` (finding L25-1).

All heavy codec/verifier proofs are proved over abstract `V : IncV` / `V : ℕ → OutcV` (matching
`HonestRunStageIn.lean`) so kernel reduction never unfolds `clog2 131072` / `tauTable` / `embFoldL`,
and then instantiated to `shdVi` / `shdVo` via explicit numeric lemmas (`shdP_incLay_nums`, `shdP_outcLay_nums`).

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldCore
import ZK60Formal.RunStgShieldEmbFold

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (Core SlotProof Column OpeningZk MaskOpening Dim Geom BlockParams Hist SlotRec Acc
  slotsLoop slotStep histOf absorbRoot pathsDepth labA labH labM posTag
  CoreCanon CoreShape HidingCanon HidingShape MaskCanon SlotCanon Cm
  encCore encHiding encMask encSlot encColumn encFp2s encOpt)

/-! ## 1. Helper: `checkTokenEp` implies a single input-endpoint claim -/

theorem checkTokenEp_singleton (H : HIn → Dig) (cl : List Exec.Block.ZClaim) (data n : ℕ) (t : Tr)
    (h : checkTokenEp H cl data n t = .ok ()) : ∃ c, cl = [c] := by
  cases cl with
  | nil => simp [checkTokenEp] at h
  | cons c rest =>
    cases rest with
    | nil => exact ⟨c, rfl⟩
    | cons _ _ => simp [checkTokenEp] at h

/-! ## 2. Abstract-verifier bounded completeness (zero kernel unfolding of concrete stage tables) -/

section AbstractStages

/-- Bounded `incVerify_of_tables` for an abstract stage IN-C verifier `V : IncV` at Shieldstral dimensions
(`lt = 12, lr = 2, q = 256, epLogN = 8, elr = 3, eq = 256, ns = 4, aRows = 41, hRows = 76, epRows = 6`). -/
private theorem incVerify_of_tables_abs (H : HIn → Dig) (tag : MTag) (V : IncV)
    (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .a root cl o t = pcsAt tag 12 2 256 H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .h root cl o t = pcsAt tag 12 2 256 H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t = pcsAt tag 8 3 256 H' root 6 cl o t)
    (hlt : V.pub.lt = 12) (hep : V.pub.epLogN = 8) (hns : V.lay.ns = 4) (hbLog : V.geo.bLogN = 14)
    (hdB : V.blk.path = 14) (hdE : V.ed.path = 11)
    (haR : V.lay.aRows = 41) (hhR : V.lay.hRows = 76)
    (C : IncTables V) (t : Tr) (R : IncRun)
    (h : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 C t) t = .ok R)
    (hslots : StSlotsSum H (V.bp (incCtx V.pub R.ch)) (incElog V.pub 14) shdP_U (C.slot R.ch)
      Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3)
    (hMh : MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) C.M 4)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
        = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
            (mA shdP_U C.M 4) i)
    (hrA : 41 = C.TA.rows.length)
    (hcA : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 C.TA.rows (toZClaim c))
    (hrH : 76 = (C.TH R.ch).rows.length)
    (hcH : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue shdP_U (2 ^ 12) 12 (C.TH R.ch).rows (toZClaim c))
    (hrE : 6 = C.TE.rows.length)
    (hcE : ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) C.TE)
    (htE : ∀ c ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 C.TE.rows (toZClaim c)) :
    V.verify H (rootOf H tag 11 C.TE) R.seg t = .ok ((R.acc.claims.out, C.bRoot), R.t8) := by
  let D := incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 C t
  obtain ⟨-, hch, ht3, hs, hfs, hcA', hcH', hcE', hbr, haR', hmR, hhR', hmo, hao, hho, hcl, ht8⟩ :=
    incProve_ok H V D t R h
  have hdeg : ∀ j, j < 4 → 1 ≤ slotD (V.bp (incCtx V.pub R.ch)) (0 + j)
      ∧ slotD (V.bp (incCtx V.pub R.ch)) (0 + j) < gP := by
    intro j hj
    rw [Nat.zero_add]
    obtain ⟨h1, h4, -⟩ := rc_incBounds V (incCtx V.pub R.ch) j hj
    exact ⟨h1, lt_of_le_of_lt h4 (by norm_num [gP])⟩
  have hloop : stSlotsLoop H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 R.seg.core.slots {} R.t3 = .ok (R.recs, R.acc, R.t4) := by
    have hslots' : StSlotsSum H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) shdP_U (C.slot R.ch)
        Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3 := by rwa [hbLog]
    dsimp only [D, incDataAt] at hs
    generalize hm : V.lay.ns = m at hs
    have hm4 : 4 = m := hns.symm.trans hm
    rw [hm4] at hdeg hslots'
    exact stSlotsLoop_of_prove_bd H (V.bp (incCtx V.pub R.ch)) shdP_U shdP_hU
      (incElog V.pub V.geo.bLogN) (C.slot R.ch) Fp2.zero Fp2.zero Fp2.zero m [] 0 {} R.t3
      R.seg.core.slots R.recs R.acc R.t4 hdeg hslots' hs
  have hchO : incChOf H V C.bRoot (rootOf H tag (V.pub.lt + 2) C.TA)
      (rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M)) t = R.ch := hch.symm
  have haR0 := haR'
  have hmR0 := hmR
  have hhR0 := hhR'
  dsimp only [D, incDataAt] at haR' hmR hhR' hmo hao hho hcl ht8
  have hmo' : (R.seg.core.maskOpen, R.t5) = bMask H tag shdP_U shdP_hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4 := hmo
  have hao' : (R.seg.core.aOpen, R.t6) = bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5 := by
    rw [hlt] at hao; exact hao
  have hho' : (R.seg.core.hOpen, R.t7) = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 := by
    rw [hchO, hlt] at hho; exact hho
  have hcl' : R.seg.closes = [(bOpen H tag ⟨8, 8, 256, 256⟩ 11 C.TE R.acc.claims.inp R.t7).1] := by
    rw [hep] at hcl; exact hcl
  have ht8' : R.t8 = (bOpen H tag ⟨8, 8, 256, 256⟩ 11 C.TE R.acc.claims.inp R.t7).2 := by
    rw [hep] at ht8; exact ht8
  have haR14 : R.seg.core.aRoot = rootOf H tag 14 C.TA := by rw [hlt] at haR'; exact haR'
  have hhR14 : R.seg.core.hRoot = rootOf H tag 14 (C.TH R.ch) := by rw [hlt] at hhR'; exact hhR'
  have hm1 : R.seg.core.maskOpen = (bMask H tag shdP_U shdP_hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo'
  have hm2 : R.t5 = (bMask H tag shdP_U shdP_hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4).2 :=
    congrArg Prod.snd hmo'
  have ha1 : R.seg.core.aOpen = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5).1 :=
    congrArg Prod.fst hao'
  have ha2 : R.t6 = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5).2 :=
    congrArg Prod.snd hao'
  have hh1 : R.seg.core.hOpen = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).1 := congrArg Prod.fst hho'
  have hh2 : R.t7 = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).2 := congrArg Prod.snd hho'
  have hnn : (⟨12, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 14 := by norm_num [PcsPrm.nn]
  have hnnE : (⟨8, 8, 256, 256⟩ : PcsPrm).nn = 2 ^ 11 := by norm_num [PcsPrm.nn]
  refine (incVerify_ok_iff H V (rootOf H tag 11 C.TE) R.seg t R.acc.claims.out C.bRoot R.t8).mpr
    ⟨by rw [hcl']; rfl, ?_, ?_, ?_, ?_, hbr, R.recs, R.acc, R.t4, R.t5, R.t6, R.t7,
      ?_, hfs, ?_, hcA', ?_, hcH', ?_, hcE', ?_, rfl⟩
  · rw [ha1, hdB]; exact bOpen_pathsDepth H tag "stage IN-C A" ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) C.TA _ _ 0
  · rw [hh1, hdB]; exact bOpen_pathsDepth H tag "stage IN-C H" ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) _ _ _ 0
  · rw [hm1]; exact bMask_pathsDepth H tag shdP_U shdP_hbij "M" C.M 4 _ _ 0
  · rw [hcl', hdE]; exact bOpen_pathsDepth H tag "input token endpoint" ⟨8, 8, 256, 256⟩ 11 hnnE (by norm_num) C.TE _ _ 0
  · have e1 : V.headCh H R.seg.core (V.frame H C.bRoot t) = incCh H V D t := by
      simp only [IncV.headCh, IncV.headT, incCh, haR0, hmR0]; rfl
    have e2 : V.slotT H R.seg.core (V.frame H C.bRoot t) = R.t3 := by
      rw [IncV.slotT, e1, hhR0, hch]; exact ht3.symm
    show stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H R.seg.core (V.frame H C.bRoot t)).1)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 R.seg.core.slots {} (V.slotT H R.seg.core (V.frame H C.bRoot t))
        = .ok (R.recs, R.acc, R.t4)
    rw [e1, e2, ← hch]
    exact hloop
  · rw [hVm, hmR, hm1, hm2]
    exact maskField_of_prove H tag shdP_U shdP_hbij shdP_hU C.M 4 hMh _ hMt _
  · rw [haR14, ha1, ha2, hVa, haR, hrA]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 12 2 256 (by norm_num) (by norm_num) C.TA hcA _ htA _
  · rw [hhR14, hh1, hh2, hVh, hhR, hrH]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 12 2 256 (by norm_num) (by norm_num) (C.TH R.ch) hcH _ htH _
  · rw [hcl', ht8', hVe, hrE]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 8 3 256 (by norm_num) (by norm_num) C.TE hcE _ htE _

open Classical in
/-- Repaired `outcDataAt` for an abstract `V : OutcV`: checks BOTH `cr.root = rootOf H tag 16 C.TB` AND
`ClaimTrue` on every pending carry claim (resolving L25-1 cleanly without firing on the honest carry). -/
noncomputable def outcDataAt_abs (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr) :
    OutcData V where
  aRoot := rootOf H tag 14 C.TA
  maskRoot := rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)
  hRoot := fun ch => rootOf H tag 14 (C.TH ch)
  slot := C.slot
  mOpen := bMask H tag shdP_U shdP_hbij C.M 8
  aOpen := bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA
  hOpen := bOpen H tag ⟨12, 4, 256, 256⟩ 14
    (C.TH (outcChOf H V (rootOf H tag 14 C.TA) (rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)) t))
  bOpen := bOpen H tag ⟨14, 4, 256, 256⟩ 16 C.TB
  own cr := decide (cr.root = rootOf H tag 16 C.TB
    ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 C.TB.rows (toZClaim cl))

open Classical in
/-- Bounded `outcVerify_of_tables` for an abstract `V : OutcV` at Shieldstral dimensions. -/
private theorem outcVerify_of_tables_abs (H : HIn → Dig) (tag : MTag) (V : OutcV)
    (hVm : V.maskVerify = maskField tag 8)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .a root cl o t = pcsAt tag 12 2 256 H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .h root cl o t = pcsAt tag 12 2 256 H' root V.lay.hRows cl o t)
    (hVb : ∀ (H' : HIn → Dig) root cl o t, V.bVerify H' root cl o t = pcsAt tag 14 2 256 H' root 38 cl o t)
    (hns : V.lay.ns = 8) (hdB : V.blk.path = 14) (hdBD : V.bd.path = 16)
    (haR : V.lay.aRows = 76) (hhR : V.lay.hRows = 38)
    (C : OutcTables V) (cr : Carry) (t : Tr) (R : OutcRun)
    (h : outcProve H V (outcDataAt_abs tag H V C t) cr t = .ok R)
    (hslots : SlotsSum H V.bp shdP_U C.slot
      (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3)
    (hMh : MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) C.M 8)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
        = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
            (mA shdP_U C.M 8) i)
    (hrA : 76 = C.TA.rows.length)
    (hcA : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 C.TA.rows (toZClaim c))
    (hrH : 38 = (C.TH R.ch).rows.length)
    (hcH : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue shdP_U (2 ^ 12) 12 (C.TH R.ch).rows (toZClaim c))
    (hrB : 38 = C.TB.rows.length)
    (hcB : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) C.TB)
    (htB_inp : ∀ c ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 C.TB.rows (toZClaim c)) :
    V.verify H cr.root cr.pending R.seg t = .ok R.t8 := by
  let D := outcDataAt_abs tag H V C t
  obtain ⟨hown, -, hch, ht3, hs, hfs, hout, hcA', hcH', hcB', hbr, haR', hmR, hhR', hmo, hao, hho, hcl, ht8⟩ :=
    outcProve_ok H V D cr t R h
  have haR0 := haR'
  have hmR0 := hmR
  have hhR0 := hhR'
  dsimp only [D, outcDataAt_abs] at hown hs haR' hmR hhR' hmo hao hho hcl ht8
  have hown' : cr.root = rootOf H tag 16 C.TB
      ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 C.TB.rows (toZClaim cl) :=
    of_decide_eq_true hown
  have hroot := hown'.1
  have htB : ∀ c ∈ cr.pending ++ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 C.TB.rows (toZClaim c) := by
    intro c hc
    rcases List.mem_append.mp hc with h1 | h2
    · exact hown'.2 c h1
    · exact htB_inp c h2
  have hdeg : ∀ j, j < 8 → 1 ≤ slotD V.bp (0 + j) ∧ slotD V.bp (0 + j) < gP := by
    intro j hj
    rw [Nat.zero_add]
    obtain ⟨h1, h5, -⟩ := rc_outcBounds V j hj
    exact ⟨h1, lt_of_le_of_lt h5 (by norm_num [gP])⟩
  have hloop : slotsLoop H V.bp (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2
      [] 0 R.seg.core.slots {} R.t3 = .ok (R.recs, R.acc, R.t4) := by
    generalize hm : V.lay.ns = m at hs
    have hm8 : 8 = m := hns.symm.trans hm
    rw [hm8] at hdeg hslots
    exact slotsLoop_of_prove_bd H V.bp shdP_U shdP_hU C.slot
      (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 m [] 0 {} R.t3
      R.seg.core.slots R.recs R.acc R.t4 hdeg hslots hs
  have hchO : outcChOf H V (rootOf H tag 14 C.TA)
      (rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)) t = R.ch := hch.symm
  have hmo' : (R.seg.core.maskOpen, R.t5) = bMask H tag shdP_U shdP_hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4 := hmo
  have hao' : (R.seg.core.aOpen, R.t6) = bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5 := hao
  have hho' : (R.seg.core.hOpen, R.t7) = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 := by
    rw [hchO] at hho; exact hho
  have hcl' : R.seg.closes = [(bOpen H tag ⟨14, 4, 256, 256⟩ 16 C.TB (cr.pending ++ R.acc.claims.inp) R.t7).1] := hcl
  have ht8' : R.t8 = (bOpen H tag ⟨14, 4, 256, 256⟩ 16 C.TB (cr.pending ++ R.acc.claims.inp) R.t7).2 := ht8
  have hm1 : R.seg.core.maskOpen = (bMask H tag shdP_U shdP_hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo'
  have hm2 : R.t5 = (bMask H tag shdP_U shdP_hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4).2 :=
    congrArg Prod.snd hmo'
  have ha1 : R.seg.core.aOpen = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5).1 :=
    congrArg Prod.fst hao'
  have ha2 : R.t6 = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA R.acc.claims.a R.t5).2 :=
    congrArg Prod.snd hao'
  have hh1 : R.seg.core.hOpen = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).1 := congrArg Prod.fst hho'
  have hh2 : R.t7 = (bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).2 := congrArg Prod.snd hho'
  have hnn : (⟨12, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 14 := by norm_num [PcsPrm.nn]
  have hnnB : (⟨14, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 16 := by norm_num [PcsPrm.nn]
  refine (outcVerify_ok_iff H V cr.root cr.pending R.seg t R.t8).mpr
    ⟨by rw [hcl']; rfl, hbr, ?_, ?_, ?_, ?_, R.ch, R.recs, R.acc, R.t4, R.t5, R.t6, R.t7,
      ?_, hfs, ?_, hout, hcA', ?_, hcH', ?_, hcB', ?_⟩
  · rw [ha1, hdB]; exact bOpen_pathsDepth H tag "stage OUT-C A" ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) C.TA _ _ 0
  · rw [hh1, hdB]; exact bOpen_pathsDepth H tag "stage OUT-C H" ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) _ _ _ 0
  · rw [hm1]; exact bMask_pathsDepth H tag shdP_U shdP_hbij "M" C.M 8 _ _ 0
  · rw [hcl', hdBD]; exact bOpen_pathsDepth H tag "B_out" ⟨14, 4, 256, 256⟩ 16 hnnB (by norm_num) C.TB _ _ 0
  · have e1 : ((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
        R.seg.core.maskRoot.toList).challengeFp2Vec H 2 = outcCh H V D t := by
      simp only [outcCh, haR0, hmR0]
    show (match slotsLoop H V.bp (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows
        V.bp.logCols).absorb H labM R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).1
        (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).2.1
        (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).2.2 [] 0 R.seg.core.slots {}
        (absorbRoot H (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).2 labH R.seg.core.hRoot V.bp.hRows V.bp.logCols) with
      | .ok r => (.ok ((((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1, r) : Except String _)
      | .error e => .error e) = .ok (R.ch, R.recs, R.acc, R.t4)
    rw [e1, hhR0, hch, ← ht3]
    rw [hch] at hloop
    rw [hloop]
  · rw [hVm, hmR, hm1, hm2]
    exact maskField_of_prove H tag shdP_U shdP_hbij shdP_hU C.M 8 hMh _ hMt _
  · rw [haR', ha1, ha2, hVa, haR, hrA]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 12 2 256 (by norm_num) (by norm_num) C.TA hcA _ htA _
  · rw [hhR', hh1, hh2, hVh, hhR, hrH]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 12 2 256 (by norm_num) (by norm_num) (C.TH R.ch) hcH _ htH _
  · rw [hroot, hcl', ht8', hVb, hrB]
    exact pcsAt_of_prove H tag shdP_U shdP_hU 14 2 256 (by norm_num) (by norm_num) C.TB hcB _ htB _

/-- Abstract-`V` `StageInOK` proof (keeps `V : IncV` opaque during `CoreShape`/`CloseOk`/`decodeStage_enc`). -/
private theorem inc_stageInOK_abs {Hdr Coins Γ : Type} (tag : MTag) (V : IncV)
    (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .a root cl o t = pcsAt tag 12 2 256 H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' .h root cl o t = pcsAt tag 12 2 256 H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t = pcsAt tag 8 3 256 H' root 6 cl o t)
    (hlt : V.pub.lt = 12) (hep : V.pub.epLogN = 8) (hns : V.lay.ns = 4) (hbLog : V.geo.bLogN = 14)
    (hmR : V.lay.mRows = 2 * 4 + 4) (hblk : V.blk = shdP_stgDim) (hed : V.ed = shdP_epDim)
    (haR : V.lay.aRows = 41) (hhR : V.lay.hRows = 76) (heR : V.geo.epRows = 6)
    (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V)
    (hEpRoot : ∀ g x c, adm x → rootOf (hOf g) tag 11 (C (hOf g) (stOf g x c) x c).TE = (stOf g x c).inRoot)
    (hArith : ∀ g x c t R, adm x →
      incProve (hOf g) V (incDataAt (hOf g) tag shdP_U shdP_hbij V 2 3 256 256
          (C (hOf g) (stOf g x c) x c) t) t = .ok R →
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, ((ct.slot R.ch).scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ (ct.slot R.ch).terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TE.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TE.cols j).length = ct.TE.rows.length)
      ∧ StSlotsSum (hOf g) (V.bp (incCtx V.pub R.ch)) (incElog V.pub 14) shdP_U (ct.slot R.ch)
          Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 4
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
                (mA shdP_U ct.M 4) i)
      ∧ 41 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 76 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 6 = ct.TE.rows.length
      ∧ ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) ct.TE
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 ct.TE.rows (toZClaim cl))) :
    StageInOK adm hOf stOf (incStageV (fun _ : Hdr => V) (fun _ => rcIncGeom V 28))
      { prove := fun H s x c t =>
          match incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
          | .error _ => .error ()
          | .ok R => .ok (R.seg, (R.acc.claims.out, (C H s x c).bRoot), R.t8)
        encode := fun _ bnd start seg e => encStage (rcIncGeom V 28) bnd start seg e } := by
  intro g x c bnd t seg pr t' hx hrun
  let G := rcIncGeom V 28
  let ct := C (hOf g) (stOf g x c) x c
  let D := incDataAt (hOf g) tag shdP_U shdP_hbij V 2 3 256 256 ct t
  cases hR : incProve (hOf g) V D t with
  | error _ =>
    change (match incProve (hOf g) V D t with | Except.error _ => Except.error () | Except.ok R => _) = _ at hrun
    rw [hR] at hrun; cases hrun
  | ok R =>
    change (match incProve (hOf g) V D t with | Except.error _ => Except.error () | Except.ok R => _) = _ at hrun
    rw [hR] at hrun
    simp only [Except.ok.injEq] at hrun
    cases hrun
    obtain ⟨hSc, hTm, hcanA, hcanH, hcanE, hlenA, hlenH, hlenE,
      hslots, hMh, hMt, hrA, hcA, htA, hrH, hcH, htH, hrE, hcE, htE⟩ := hArith g x c t R hx hR
    obtain ⟨-, hch, -, hs, -, hcA', hcH', hcE', hbr, -, -, -, hmo, hao, hho, hcl, -⟩ :=
      incProve_ok (hOf g) V D t R hR
    have hchO : incChOf (hOf g) V ct.bRoot (rootOf (hOf g) tag (V.pub.lt + 2) ct.TA)
        (rootOf (hOf g) tag 12 (mTab 4 (cosetPt (rootFp 12)) ct.M)) t = R.ch := hch.symm
    dsimp only [D, incDataAt] at hs hmo hao hho hcl
    have hm1 : R.seg.core.maskOpen = (bMask (hOf g) tag shdP_U shdP_hbij ct.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
      congrArg Prod.fst hmo
    have ha1 : R.seg.core.aOpen = (bOpen (hOf g) tag ⟨12, 4, 256, 256⟩ 14 ct.TA R.acc.claims.a R.t5).1 := by
      rw [hlt] at hao; exact congrArg Prod.fst hao
    have hh1 : R.seg.core.hOpen = (bOpen (hOf g) tag ⟨12, 4, 256, 256⟩ 14 (ct.TH R.ch)
        (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).1 := by
      rw [hchO, hlt] at hho; exact congrArg Prod.fst hho
    have hcl' : R.seg.closes = [(bOpen (hOf g) tag ⟨8, 8, 256, 256⟩ 11 ct.TE R.acc.claims.inp R.t7).1] := by
      rw [hep] at hcl; exact hcl
    have hnn : (⟨12, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 14 := by norm_num [PcsPrm.nn]
    have hnnE : (⟨8, 8, 256, 256⟩ : PcsPrm).nn = 2 ^ 11 := by norm_num [PcsPrm.nn]
    have hslots' : StSlotsSum (hOf g) (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) shdP_U (ct.slot R.ch)
        Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3 := by
      rwa [hbLog]
    have ⟨hslLen, hslCan, hslSh⟩ :
        R.seg.core.slots.length = V.lay.ns
          ∧ (∀ p ∈ R.seg.core.slots, SlotCanon p)
          ∧ (∀ (i : ℕ) (p : SlotProof) (s' : ℕ × ℕ × ℕ) (t' : ℕ),
              R.seg.core.slots[i]? = some p → (V.bp (incCtx V.pub R.ch)).geom.slots[0 + i]? = some s' →
              (V.bp (incCtx V.pub R.ch)).geom.terms[0 + i]? = some t' →
              p.rounds.length = s'.1 + s'.2.1 ∧ (∀ r ∈ p.rounds, r.length = s'.2.2 + 1) ∧ p.terms.length = t') := by
      have hsl' := hslots'
      generalize hm : V.lay.ns = m at hs ⊢
      have hm4 : 4 = m := hns.symm.trans hm
      rw [hm4] at hsl'
      exact stSlotsProve_shape_canon (hOf g) (V.bp (incCtx V.pub R.ch))
        (incElog V.pub V.geo.bLogN) shdP_U (ct.slot R.ch) Fp2.zero Fp2.zero Fp2.zero hSc hTm
        m [] 0 {} R.t3 R.seg.core.slots R.recs R.acc R.t4 hsl' hs
    have hcan : CoreCanon R.seg.core := by
      refine ⟨hslCan, ?_, ?_, ?_⟩
      · rw [hm1]; exact bMask_canon (hOf g) tag shdP_U shdP_hbij ct.M 4 _ _
      · rw [ha1]; exact bOpen_canon (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) ct.TA hcanA _ _
      · rw [hh1]; exact bOpen_canon (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) (ct.TH R.ch) hcanH _ _
    have hmSh := bMask_shape (hOf g) tag shdP_U shdP_hbij ct.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4
    have haSh := bOpen_shape (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) ct.TA hlenA R.acc.claims.a R.t5
    have hhSh := bOpen_shape (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) (ct.TH R.ch) hlenH
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6
    have heSh := bOpen_shape (hOf g) tag ⟨8, 8, 256, 256⟩ 11 hnnE (by norm_num) ct.TE hlenE R.acc.claims.inp R.t7
    have hlogN : V.lay.logN = 12 := hlt
    have hgA : (groupZclaims (R.acc.claims.a.map toZClaim) ct.TA.rows.length 12).length = incAGroups := by
      have hcA12 : checkOpeningExec (hOf g) ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩
          12 R.acc.claims.a R.t5 = .ok () := by
        unfold IncV.checkOpening at hcA'; rw [hlogN] at hcA'; exact hcA'
      exact groupZclaims_length_of_checkOpeningExec (hOf g) _ 12 ct.TA.rows.length R.acc.claims.a R.t5 hcA12
    have hgH : (groupZclaims ((R.acc.claims.h ++ [V.lay.logupSumClaim]).map toZClaim) (ct.TH R.ch).rows.length 12).length
        = incHGroups := by
      have hcH12 : checkOpeningExec (hOf g) ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩
          12 (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 = .ok () := by
        unfold IncV.checkOpening at hcH'; rw [hlogN] at hcH'; exact hcH'
      exact groupZclaims_length_of_checkOpeningExec (hOf g) _ 12 (ct.TH R.ch).rows.length _ R.t6 hcH12
    have hgE : (groupZclaims (R.acc.claims.inp.map toZClaim) ct.TE.rows.length 8).length = 1 := by
      obtain ⟨c0, hc0⟩ := checkTokenEp_singleton (hOf g) R.acc.claims.inp V.geo.epDataRows V.pub.epN R.t7 hcE'
      rw [hc0]; exact groupZclaims_length_singleton c0 ct.TE.rows.length 8
    have hsh : CoreShape G.g R.seg.core := by
      refine ⟨hslLen.trans (List.length_map _).symm, fun i p s t' hp hs' ht' =>
          hslSh i p s t' hp (by rw [Nat.zero_add]; exact hs') (by rw [Nat.zero_add]; exact ht'),
        ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
      · rw [hm1]; exact hmSh.1
      · rw [hm1]; exact hmSh.2.1
      · rw [hm1]; exact hmSh.2.2.1
      · rw [hm1]; intro col hcol
        obtain ⟨h1, h2, h3⟩ := hmSh.2.2.2 col hcol
        exact ⟨h1, h2.trans hmR.symm, h3⟩
      · intro o ho
        simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
        rcases ho with rfl | rfl
        · rw [ha1]; dsimp only [G, rcIncGeom, IncV.geom]; rw [hblk]; dsimp only [shdP_stgDim]
          exact ⟨haSh.2.2.1, haSh.2.1, haSh.2.2.2.1, fun col hcol => ⟨(haSh.2.2.2.2 col hcol).1, (haSh.2.2.2.2 col hcol).2.2⟩⟩
        · rw [hh1]; dsimp only [G, rcIncGeom, IncV.geom]; rw [hblk]; dsimp only [shdP_stgDim]
          exact ⟨hhSh.2.2.1, hhSh.2.1, hhSh.2.2.2.1, fun col hcol => ⟨(hhSh.2.2.2.2 col hcol).1, (hhSh.2.2.2.2 col hcol).2.2⟩⟩
      · rw [ha1, haSh.1, hgA]; rfl
      · rw [hh1, hhSh.1, hgH]; rfl
      · intro col hcol; rw [ha1] at hcol
        exact (haSh.2.2.2.2 col hcol).2.1.trans (hrA.symm.trans haR.symm)
      · intro col hcol; rw [hh1] at hcol
        exact (hhSh.2.2.2.2 col hcol).2.1.trans (hrH.symm.trans hhR.symm)
    have hclose : List.Forall₂ CloseOk G.closes R.seg.closes := by
      rw [hcl']
      refine List.Forall₂.cons ⟨?_, ?_, by change V.ed.encCols ≤ 2 ^ 64; rw [hed]; norm_num [shdP_epDim]⟩ List.Forall₂.nil
      · exact bOpen_canon (hOf g) tag ⟨8, 8, 256, 256⟩ 11 hnnE (by norm_num) ct.TE hcanE _ _
      · change HidingShape V.ed 1 V.geo.epRows _; rw [hed, heR]
        refine ⟨heSh.1.trans hgE, heSh.2.1, heSh.2.2.1, heSh.2.2.2.1, fun col hcol => ?_⟩
        obtain ⟨hj, hclen, hcp⟩ := heSh.2.2.2.2 col hcol
        exact ⟨hj, hclen.trans hrE.symm, hcp⟩
    have hbr_eq : R.seg.bRoot.isSome = G.hasB := by rw [hbr]; rfl
    have hdomBlk : G.g.blk.encCols ≤ 2 ^ 64 := by change V.blk.encCols ≤ 2 ^ 64; rw [hblk]; norm_num [shdP_stgDim]
    have hmd : G.g.maskDom ≤ 2 ^ 64 := by change 4096 ≤ 2 ^ 64; norm_num
    refine ⟨?_, ?_⟩
    · exact decodeStage_enc G (rc_incGeom_gt V) hmd hdomBlk rfl bnd (posTag (hOf g) t) R.seg (posTag (hOf g) R.t8)
        hcan hsh hbr_eq hclose (encStage_length G (rc_incGeom_gt V) rfl _ _ _ _ hsh hbr_eq hclose)
    · change V.verify (hOf g) (stOf g x c).inRoot R.seg t = .ok ((R.acc.claims.out, ct.bRoot), R.t8)
      rw [← hEpRoot g x c hx]
      exact incVerify_of_tables_abs (hOf g) tag V hVm hVa hVh hVe hlt hep hns hbLog
        (by rw [hblk]; rfl) (by rw [hed]; rfl) haR hhR ct t R hR
        hslots hMh hMt hrA hcA htA hrH hcH htH hrE hcE htE

/-- Abstract-`V` `StageOutOK` proof (keeps `V : ℕ → OutcV` opaque during `CoreShape`/`CloseOk`/`decodeStage_enc`). -/
private theorem outc_stageOutOK_abs {Hdr Coins Γ : Type} (tag : MTag) (V : ℕ → OutcV)
    (hgeom : ∀ v, (V v).geom = (V 0).geom)
    (hVm : ∀ v, (V v).maskVerify = maskField tag 8)
    (hVa : ∀ v (H' : HIn → Dig) root cl o t, (V v).pcsVerify H' .a root cl o t = pcsAt tag 12 2 256 H' root (V v).lay.aRows cl o t)
    (hVh : ∀ v (H' : HIn → Dig) root cl o t, (V v).pcsVerify H' .h root cl o t = pcsAt tag 12 2 256 H' root (V v).lay.hRows cl o t)
    (hVb : ∀ v (H' : HIn → Dig) root cl o t, (V v).bVerify H' root cl o t = pcsAt tag 14 2 256 H' root 38 cl o t)
    (hns : ∀ v, (V v).lay.ns = 8) (hmR : ∀ v, (V v).lay.mRows = 2 * 8 + 4)
    (hlt : ∀ v, (V v).pub.lt = 12) (hblk : ∀ v, (V v).blk = shdP_stgDim) (hbd : ∀ v, (V v).bd = Exec.Block.R13.blkDim)
    (haR : ∀ v, (V v).lay.aRows = 76) (hhR : ∀ v, (V v).lay.hRows = 38)
    (hbLog : ∀ v, (V v).geo.bLogN = 14) (hbS : ∀ v, (V v).geo.bSites = 2) (hbR : ∀ v, (V v).geo.bRows = 38)
    (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (V s.verdict))
    (hArith : ∀ g x c cr t R, adm x →
      outcProve (hOf g) (V (stOf g x c).verdict)
        (outcDataAt_abs tag (hOf g) (V (stOf g x c).verdict) (C (hOf g) (stOf g x c) x c) t) cr t = .ok R →
      let v := (stOf g x c).verdict
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, (ct.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ ct.slot.terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TB.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TB.cols j).length = ct.TB.rows.length)
      ∧ SlotsSum (hOf g) (V v).bp shdP_U ct.slot
          (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 8
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
                (mA shdP_U ct.M 8) i)
      ∧ 76 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 38 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(V v).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 38 = ct.TB.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) ct.TB
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 ct.TB.rows (toZClaim cl))) :
    StageOutOK adm hOf stOf (outcStageV (fun (_ : Hdr) v => V v) (fun _ => rcOutcGeom (V 0) 28))
      { prove := fun H s x c cr t =>
          match outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t with
          | .error _ => .error ()
          | .ok R => .ok (R.seg, R.t8)
        encode := fun _ bnd start seg e => encStage (rcOutcGeom (V 0) 28) bnd start seg e } := by
  intro g x c bnd cr t seg t' hx hrun
  let v := (stOf g x c).verdict
  let G := rcOutcGeom (V 0) 28
  let ct := C (hOf g) (stOf g x c) x c
  let D := outcDataAt_abs tag (hOf g) (V v) ct t
  cases hR : outcProve (hOf g) (V v) D cr t with
  | error _ =>
    change (match outcProve (hOf g) (V v) D cr t with | Except.error _ => Except.error () | Except.ok R => _) = _ at hrun
    rw [hR] at hrun; cases hrun
  | ok R =>
    change (match outcProve (hOf g) (V v) D cr t with | Except.error _ => Except.error () | Except.ok R => _) = _ at hrun
    rw [hR] at hrun
    simp only [Except.ok.injEq] at hrun
    cases hrun
    obtain ⟨hSc, hTm, hcanA, hcanH, hcanB, hlenA, hlenH, hlenB,
      hslots, hMh, hMt, hrA, hcA, htA, hrH, hcH, htH, hrB, hcB, htB_inp⟩ := hArith g x c cr t R hx hR
    obtain ⟨-, -, hch, -, hs, -, -, hcA', hcH', hcB', hbr, -, -, -, hmo, hao, hho, hcl, -⟩ :=
      outcProve_ok (hOf g) (V v) D cr t R hR
    have hchO : outcChOf (hOf g) (V v) (rootOf (hOf g) tag 14 ct.TA)
        (rootOf (hOf g) tag 12 (mTab 8 (cosetPt (rootFp 12)) ct.M)) t = R.ch := hch.symm
    dsimp only [D, outcDataAt_abs] at hs hmo hao hho hcl
    have hm1 : R.seg.core.maskOpen = (bMask (hOf g) tag shdP_U shdP_hbij ct.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
      congrArg Prod.fst hmo
    have ha1 : R.seg.core.aOpen = (bOpen (hOf g) tag ⟨12, 4, 256, 256⟩ 14 ct.TA R.acc.claims.a R.t5).1 :=
      congrArg Prod.fst hao
    have hh1 : R.seg.core.hOpen = (bOpen (hOf g) tag ⟨12, 4, 256, 256⟩ 14 (ct.TH R.ch)
        (R.acc.claims.h ++ [(V v).lay.logupSumClaim]) R.t6).1 := by
      rw [hchO] at hho; exact congrArg Prod.fst hho
    have hcl' : R.seg.closes = [(bOpen (hOf g) tag ⟨14, 4, 256, 256⟩ 16 ct.TB (cr.pending ++ R.acc.claims.inp) R.t7).1] := hcl
    have hnn : (⟨12, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 14 := by norm_num [PcsPrm.nn]
    have hnnB : (⟨14, 4, 256, 256⟩ : PcsPrm).nn = 2 ^ 16 := by norm_num [PcsPrm.nn]
    have ⟨hslLen, hslCan, hslSh⟩ :
        R.seg.core.slots.length = (V v).lay.ns
          ∧ (∀ p ∈ R.seg.core.slots, SlotCanon p)
          ∧ (∀ (i : ℕ) (p : SlotProof) (s' : ℕ × ℕ × ℕ) (t' : ℕ),
              R.seg.core.slots[i]? = some p → (V v).bp.geom.slots[0 + i]? = some s' →
              (V v).bp.geom.terms[0 + i]? = some t' →
              p.rounds.length = s'.1 + s'.2.1 ∧ (∀ r ∈ p.rounds, r.length = s'.2.2 + 1) ∧ p.terms.length = t') := by
      have hsl' := hslots
      generalize hm : (V v).lay.ns = m at hs ⊢
      have hm8 : 8 = m := (hns v).symm.trans hm
      rw [hm8] at hsl'
      exact slotsProve_shape_canon (hOf g) (V v).bp shdP_U ct.slot
        (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 hSc hTm
        m [] 0 {} R.t3 R.seg.core.slots R.recs R.acc R.t4 hsl' hs
    have hcan : CoreCanon R.seg.core := by
      refine ⟨hslCan, ?_, ?_, ?_⟩
      · rw [hm1]; exact bMask_canon (hOf g) tag shdP_U shdP_hbij ct.M 8 _ _
      · rw [ha1]; exact bOpen_canon (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) ct.TA hcanA _ _
      · rw [hh1]; exact bOpen_canon (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) (ct.TH R.ch) hcanH _ _
    have hmSh := bMask_shape (hOf g) tag shdP_U shdP_hbij ct.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4
    have haSh := bOpen_shape (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) ct.TA hlenA R.acc.claims.a R.t5
    have hhSh := bOpen_shape (hOf g) tag ⟨12, 4, 256, 256⟩ 14 hnn (by norm_num) (ct.TH R.ch) hlenH
      (R.acc.claims.h ++ [(V v).lay.logupSumClaim]) R.t6
    have hbSh := bOpen_shape (hOf g) tag ⟨14, 4, 256, 256⟩ 16 hnnB (by norm_num) ct.TB hlenB
      (cr.pending ++ R.acc.claims.inp) R.t7
    have hlogN : (V v).lay.logN = 12 := hlt v
    have hgA : (groupZclaims (R.acc.claims.a.map toZClaim) ct.TA.rows.length 12).length = outcAGroups := by
      have hcA12 : checkOpeningExec (hOf g) ⟨(V v).lay.aRows, (V v).lay.aSiteRows, none, (V v).lay.aProx, outcAGroups⟩
          12 R.acc.claims.a R.t5 = .ok () := by
        unfold OutcV.checkOpening at hcA'; rw [hlogN] at hcA'; exact hcA'
      exact groupZclaims_length_of_checkOpeningExec (hOf g) _ 12 ct.TA.rows.length R.acc.claims.a R.t5 hcA12
    have hgH : (groupZclaims ((R.acc.claims.h ++ [(V v).lay.logupSumClaim]).map toZClaim) (ct.TH R.ch).rows.length 12).length
        = outcHGroups := by
      have hcH12 : checkOpeningExec (hOf g) ⟨(V v).lay.hRows, (V v).lay.hSiteRows, some (V v).lay.hURows, (V v).lay.hProx, outcHGroups⟩
          12 (R.acc.claims.h ++ [(V v).lay.logupSumClaim]) R.t6 = .ok () := by
        unfold OutcV.checkOpening at hcH'; rw [hlogN] at hcH'; exact hcH'
      exact groupZclaims_length_of_checkOpeningExec (hOf g) _ 12 (ct.TH R.ch).rows.length _ R.t6 hcH12
    have hgB : (groupZclaims ((cr.pending ++ R.acc.claims.inp).map toZClaim) ct.TB.rows.length 14).length = 2 := by
      unfold OutcV.bCheck at hcB'
      rw [hbLog v, hbS v] at hcB'
      exact groupZclaims_length_of_checkOpeningExec (hOf g) _ 14 ct.TB.rows.length _ R.t7 hcB'
    have hsh : CoreShape G.g R.seg.core := by
      change CoreShape (V 0).geom R.seg.core
      rw [← hgeom v]
      refine ⟨hslLen.trans (List.length_map _).symm, fun i p s t' hp hs' ht' =>
          hslSh i p s t' hp (by rw [Nat.zero_add]; exact hs') (by rw [Nat.zero_add]; exact ht'),
        ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
      · rw [hm1]; exact hmSh.1
      · rw [hm1]; exact hmSh.2.1
      · rw [hm1]; exact hmSh.2.2.1
      · rw [hm1]; intro col hcol
        obtain ⟨h1, h2, h3⟩ := hmSh.2.2.2 col hcol
        exact ⟨h1, h2.trans (hmR v).symm, h3⟩
      · intro o ho
        simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
        rcases ho with rfl | rfl
        · rw [ha1]; dsimp only [OutcV.geom]; rw [hblk v]; dsimp only [shdP_stgDim]
          exact ⟨haSh.2.2.1, haSh.2.1, haSh.2.2.2.1, fun col hcol => ⟨(haSh.2.2.2.2 col hcol).1, (haSh.2.2.2.2 col hcol).2.2⟩⟩
        · rw [hh1]; dsimp only [OutcV.geom]; rw [hblk v]; dsimp only [shdP_stgDim]
          exact ⟨hhSh.2.2.1, hhSh.2.1, hhSh.2.2.2.1, fun col hcol => ⟨(hhSh.2.2.2.2 col hcol).1, (hhSh.2.2.2.2 col hcol).2.2⟩⟩
      · rw [ha1, haSh.1, hgA]; rfl
      · rw [hh1, hhSh.1, hgH]; rfl
      · intro col hcol; rw [ha1] at hcol
        exact (haSh.2.2.2.2 col hcol).2.1.trans (hrA.symm.trans (haR v).symm)
      · intro col hcol; rw [hh1] at hcol
        exact (hhSh.2.2.2.2 col hcol).2.1.trans (hrH.symm.trans (hhR v).symm)
    have hclose : List.Forall₂ CloseOk G.closes R.seg.closes := by
      rw [hcl']
      refine List.Forall₂.cons ⟨?_, ?_, by change (V 0).bd.encCols ≤ 2 ^ 64; rw [hbd 0]; norm_num [Exec.Block.R13.blkDim]⟩ List.Forall₂.nil
      · exact bOpen_canon (hOf g) tag ⟨14, 4, 256, 256⟩ 16 hnnB (by norm_num) ct.TB hcanB _ _
      · change HidingShape (V 0).bd (V 0).geo.bSites (V 0).geo.bRows _; rw [hbd 0, hbS 0, hbR 0]
        refine ⟨hbSh.1.trans hgB, hbSh.2.1, hbSh.2.2.1, hbSh.2.2.2.1, fun col hcol => ?_⟩
        obtain ⟨hj, hclen, hcp⟩ := hbSh.2.2.2.2 col hcol
        exact ⟨hj, hclen.trans hrB.symm, hcp⟩
    have hbr_eq : R.seg.bRoot.isSome = G.hasB := by rw [hbr]; rfl
    have hdomBlk : G.g.blk.encCols ≤ 2 ^ 64 := by change (V 0).blk.encCols ≤ 2 ^ 64; rw [hblk 0]; norm_num [shdP_stgDim]
    have hmd : G.g.maskDom ≤ 2 ^ 64 := by change 4096 ≤ 2 ^ 64; norm_num
    refine ⟨?_, ?_⟩
    · exact decodeStage_enc G (rc_outcGeom_gt (V 0)) hmd hdomBlk rfl bnd (posTag (hOf g) t) R.seg (posTag (hOf g) R.t8)
        hcan hsh hbr_eq hclose (encStage_length G (rc_outcGeom_gt (V 0)) rfl _ _ _ _ hsh hbr_eq hclose)
    · exact outcVerify_of_tables_abs (hOf g) tag (V v) (hVm v) (hVa v) (hVh v) (hVb v) (hns v)
        (by rw [hblk v]; rfl) (by rw [hbd v]; rfl) (haR v) (hhR v) ct cr t R hR
        hslots hMh hMt hrA hcA htA hrH hcH htH hrB hcB htB_inp

/-- Abstract transcript-indexed `StageInP` for any `V : IncV`. -/
noncomputable def incP_abs {Hdr Coins : Type} (tag : MTag) (V : IncV)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V) :
    StageInP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins
      (incStageV (fun _ : Hdr => V) (fun _ => rcIncGeom V 28)) where
  prove H s x c t :=
    match incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
    | .error _ => .error ()
    | .ok R => .ok (R.seg, (R.acc.claims.out, (C H s x c).bRoot), R.t8)
  encode _ bnd start seg e := encStage (rcIncGeom V 28) bnd start seg e

/-- Abstract transcript-indexed `StageOutP` for any `V : ℕ → OutcV`. -/
noncomputable def outcP_abs {Hdr Coins : Type} (tag : MTag) (V : ℕ → OutcV)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (V s.verdict)) :
    StageOutP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins
      (outcStageV (fun (_ : Hdr) v => V v) (fun _ => rcOutcGeom (V 0) 28)) where
  prove H s x c cr t :=
    match outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t with
    | .error _ => .error ()
    | .ok R => .ok (R.seg, R.t8)
  encode _ bnd start seg e := encStage (rcOutcGeom (V 0) 28) bnd start seg e

/-- Generic `incVAt` / `outcVAt` field accessors (never unfold concrete `shdP_incPub` / `clog2 131072`). -/
private theorem incVAt_maskVerify (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ) :
    (incVAt tag pub geo blk ed lr elr q eq).maskVerify = maskField tag 4 := rfl

private theorem incVAt_pcsVerify_a (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ)
    (hlt : pub.lt = 12) (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (incVAt tag pub geo blk ed lr elr q eq).pcsVerify H' .a root cl o t
      = pcsAt tag 12 lr q H' root (incVAt tag pub geo blk ed lr elr q eq).lay.aRows cl o t := by
  show pcsAt tag pub.lt lr q H' root (incLay pub geo.bLogN).aRows cl o t = _
  rw [hlt]; rfl

private theorem incVAt_pcsVerify_h (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ)
    (hlt : pub.lt = 12) (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (incVAt tag pub geo blk ed lr elr q eq).pcsVerify H' .h root cl o t
      = pcsAt tag 12 lr q H' root (incVAt tag pub geo blk ed lr elr q eq).lay.hRows cl o t := by
  show pcsAt tag pub.lt lr q H' root (incLay pub geo.bLogN).hRows cl o t = _
  rw [hlt]; rfl

private theorem incVAt_epVerify (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ)
    (hep : pub.epLogN = 8) (heR : geo.epRows = 6)
    (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (incVAt tag pub geo blk ed lr elr q eq).epVerify H' root cl o t
      = pcsAt tag 8 elr eq H' root 6 cl o t := by
  show pcsAt tag pub.epLogN elr eq H' root geo.epRows cl o t = _
  rw [hep, heR]

private theorem incVAt_lay_ns (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ) :
    (incVAt tag pub geo blk ed lr elr q eq).lay.ns = 4 := rfl

private theorem incVAt_lay_mRows (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ) :
    (incVAt tag pub geo blk ed lr elr q eq).lay.mRows = 2 * 4 + 4 := rfl

private theorem outcVAt_maskVerify (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ) :
    (outcVAt tag pub geo blk bd si lr blr q bq).maskVerify = maskField tag 8 := rfl

private theorem outcVAt_pcsVerify_a (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ)
    (hlt : pub.lt = 12) (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (outcVAt tag pub geo blk bd si lr blr q bq).pcsVerify H' .a root cl o t
      = pcsAt tag 12 lr q H' root (outcVAt tag pub geo blk bd si lr blr q bq).lay.aRows cl o t := by
  show pcsAt tag pub.lt lr q H' root (outcLay pub geo.bLogN).aRows cl o t = _
  rw [hlt]; rfl

private theorem outcVAt_pcsVerify_h (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ)
    (hlt : pub.lt = 12) (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (outcVAt tag pub geo blk bd si lr blr q bq).pcsVerify H' .h root cl o t
      = pcsAt tag 12 lr q H' root (outcVAt tag pub geo blk bd si lr blr q bq).lay.hRows cl o t := by
  show pcsAt tag pub.lt lr q H' root (outcLay pub geo.bLogN).hRows cl o t = _
  rw [hlt]; rfl

private theorem outcVAt_bVerify (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ)
    (hbLog : geo.bLogN = 14) (hbR : geo.bRows = 38)
    (H' : HIn → Dig) (root : Dig) (cl : List Exec.Block.ZClaim) (o : Exec.Block.OpeningZk) (t : Tr) :
    (outcVAt tag pub geo blk bd si lr blr q bq).bVerify H' root cl o t
      = pcsAt tag 14 blr bq H' root 38 cl o t := by
  show pcsAt tag geo.bLogN blr bq H' root geo.bRows cl o t = _
  rw [hbLog, hbR]

private theorem outcVAt_lay_ns (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ) :
    (outcVAt tag pub geo blk bd si lr blr q bq).lay.ns = 8 := rfl

private theorem outcVAt_lay_mRows (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (si lr blr q bq : ℕ) :
    (outcVAt tag pub geo blk bd si lr blr q bq).lay.mRows = 2 * 8 + 4 := rfl

end AbstractStages

/-! ## 3. Concrete Shieldstral stage IN-C & OUT-C provers & `SegComplete` for `O.parts` -/

section ShieldStages

variable {Hdr Coins : Type}
  (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
  (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)

/-- Concrete Shieldstral stage IN-C verifier (`embFold := embFoldL Rp.inp`). -/
abbrev shdVi : IncV := shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow

/-- Concrete Shieldstral stage IN-C segment geometry (`28` segments, index `0`). -/
abbrev shdGi : StageGeom := rcIncGeom (shdVi tag Rp embDigest bInRow) 28

/-- Concrete Shieldstral stage OUT-C verifier at verdict `v`. -/
abbrev shdVo (v : ℕ) : OutcV := shdP_outcV tag Rp wDigest bOutRow v

/-- Concrete Shieldstral stage OUT-C segment geometry (`28` segments, index `27`). -/
abbrev shdGo : StageGeom := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28

private theorem shdVi_aRows : (shdVi tag Rp embDigest bInRow).lay.aRows = 41 :=
  (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).1

private theorem shdVi_hRows : (shdVi tag Rp embDigest bInRow).lay.hRows = 76 :=
  (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.1

private theorem shdVi_ns : (shdVi tag Rp embDigest bInRow).lay.ns = 4 :=
  incVAt_lay_ns tag (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim 2 3 256 256

private theorem shdVi_mRows : (shdVi tag Rp embDigest bInRow).lay.mRows = 2 * 4 + 4 :=
  incVAt_lay_mRows tag (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim 2 3 256 256

private theorem shdVo_aRows (v : ℕ) : (shdVo tag Rp wDigest bOutRow v).lay.aRows = 76 := by
  change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aRows = 76
  rw [rc_outcLay_verdict]
  exact (shdP_outcLay_nums Rp wDigest).1

private theorem shdVo_hRows (v : ℕ) : (shdVo tag Rp wDigest bOutRow v).lay.hRows = 38 := by
  change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hRows = 38
  rw [rc_outcLay_verdict]
  exact (shdP_outcLay_nums Rp wDigest).2.1

private theorem shdVo_ns (v : ℕ) : (shdVo tag Rp wDigest bOutRow v).lay.ns = 8 :=
  outcVAt_lay_ns tag (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256

private theorem shdVo_mRows (v : ℕ) : (shdVo tag Rp wDigest bOutRow v).lay.mRows = 2 * 8 + 4 :=
  outcVAt_lay_mRows tag (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256

private theorem shdVo_geom_eq (v : ℕ) :
    (shdVo tag Rp wDigest bOutRow v).geom = (shdVo tag Rp wDigest bOutRow 0).geom :=
  (rc_outcV_geom tag (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim
    27 2 2 256 256 v).trans
    (rc_outcV_geom tag (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim
      27 2 2 256 256 0).symm

/-- Repaired `outcDataAt` for `shdVo v` (L25-1 `own` predicate). -/
noncomputable abbrev shdP_outcDataAt (H : HIn → Dig) (v : ℕ) (C : OutcTables (shdVo tag Rp wDigest bOutRow v))
    (t : Tr) : OutcData (shdVo tag Rp wDigest bOutRow v) :=
  outcDataAt_abs tag H (shdVo tag Rp wDigest bOutRow v) C t

/-- **Bounded `incVerify_of_tables` at `shdVi`**: discharges all path depths, slot degrees (`rc_incBounds`),
`M`, `A`, `H`, and input token endpoint opening verifications. -/
theorem shdP_incVerify_of_tables (H : HIn → Dig) (C : IncTables (shdVi tag Rp embDigest bInRow))
    (t : Tr) (R : IncRun)
    (h : incProve H (shdVi tag Rp embDigest bInRow)
      (incDataAt H tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 C t) t = .ok R)
    (hslots : StSlotsSum H ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub R.ch))
      (incElog (shdVi tag Rp embDigest bInRow).pub 14) shdP_U (C.slot R.ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3)
    (hMh : MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) C.M 4)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
        = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
            (mA shdP_U C.M 4) i)
    (hrA : 41 = C.TA.rows.length)
    (hcA : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 C.TA.rows (toZClaim c))
    (hrH : 76 = (C.TH R.ch).rows.length)
    (hcH : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim],
      ClaimTrue shdP_U (2 ^ 12) 12 (C.TH R.ch).rows (toZClaim c))
    (hrE : 6 = C.TE.rows.length)
    (hcE : ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) C.TE)
    (htE : ∀ c ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 C.TE.rows (toZClaim c)) :
    (shdVi tag Rp embDigest bInRow).verify H (rootOf H tag 11 C.TE) R.seg t = .ok ((R.acc.claims.out, C.bRoot), R.t8) :=
  incVerify_of_tables_abs H tag (shdVi tag Rp embDigest bInRow)
    (incVAt_maskVerify tag _ _ _ _ _ _ _ _)
    (incVAt_pcsVerify_a tag _ _ _ _ _ _ _ _ rfl)
    (incVAt_pcsVerify_h tag _ _ _ _ _ _ _ _ rfl)
    (incVAt_epVerify tag _ _ _ _ _ _ _ _ rfl rfl)
    rfl rfl (shdVi_ns tag Rp embDigest bInRow) rfl rfl rfl
    (shdVi_aRows tag Rp embDigest bInRow) (shdVi_hRows tag Rp embDigest bInRow)
    C t R h hslots hMh hMt hrA hcA htA hrH hcH htH hrE hcE htE

/-- **Bounded `outcVerify_of_tables` at `shdVo v`**: discharges all path depths, slot degrees (`rc_outcBounds`),
`M`, `A`, `H`, and `B_out` opening verifications (with `cr.pending`'s `ClaimTrue` discharged by `shdP_outcDataAt.own`). -/
theorem shdP_outcVerify_of_tables (H : HIn → Dig) (v : ℕ) (C : OutcTables (shdVo tag Rp wDigest bOutRow v))
    (cr : Carry) (t : Tr) (R : OutcRun)
    (h : outcProve H (shdVo tag Rp wDigest bOutRow v)
      (shdP_outcDataAt tag Rp wDigest bOutRow H v C t) cr t = .ok R)
    (hslots : SlotsSum H (shdVo tag Rp wDigest bOutRow v).bp shdP_U C.slot
      (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3)
    (hMh : MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) C.M 8)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
        = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
            (mA shdP_U C.M 8) i)
    (hrA : 76 = C.TA.rows.length)
    (hcA : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 C.TA.rows (toZClaim c))
    (hrH : 38 = (C.TH R.ch).rows.length)
    (hcH : ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim],
      ClaimTrue shdP_U (2 ^ 12) 12 (C.TH R.ch).rows (toZClaim c))
    (hrB : 38 = C.TB.rows.length)
    (hcB : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) C.TB)
    (htB_inp : ∀ c ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 C.TB.rows (toZClaim c)) :
    (shdVo tag Rp wDigest bOutRow v).verify H cr.root cr.pending R.seg t = .ok R.t8 :=
  outcVerify_of_tables_abs H tag (shdVo tag Rp wDigest bOutRow v)
    (outcVAt_maskVerify tag _ _ _ _ _ _ _ _ _)
    (outcVAt_pcsVerify_a tag _ _ _ _ _ _ _ _ _ rfl)
    (outcVAt_pcsVerify_h tag _ _ _ _ _ _ _ _ _ rfl)
    (outcVAt_bVerify tag _ _ _ _ _ _ _ _ _ rfl rfl)
    (shdVo_ns tag Rp wDigest bOutRow v) rfl rfl
    (shdVo_aRows tag Rp wDigest bOutRow v) (shdVo_hRows tag Rp wDigest bOutRow v)
    C cr t R h hslots hMh hMt hrA hcA htA hrH hcH htH hrB hcB htB_inp

/-- Transcript-indexed `StageInP` from honest `IncTables` (resolves L32-1). -/
noncomputable abbrev shdP_incP
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow)) :
    StageInP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins
      (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow)) :=
  incP_abs tag (shdVi tag Rp embDigest bInRow) C

/-- Transcript-indexed `StageOutP` from honest `OutcTables` (resolves L32-1 + L25-1). -/
noncomputable abbrev shdP_outcP
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins →
      OutcTables (shdVo tag Rp wDigest bOutRow s.verdict)) :
    StageOutP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins
      (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => shdGo tag Rp wDigest bOutRow)) :=
  outcP_abs tag (shdVo tag Rp wDigest bOutRow) C

/-- **Stage IN-C `StageInOK`** (full codec + verifier completeness) from honest `IncTables` arithmetic contracts. -/
theorem shdP_inc_stageInOK {Γ : Type} (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow))
    (hEpRoot : ∀ g x c, adm x → rootOf (hOf g) tag 11 (C (hOf g) (stOf g x c) x c).TE = (stOf g x c).inRoot)
    (hArith : ∀ g x c t R, adm x →
      incProve (hOf g) (shdVi tag Rp embDigest bInRow)
        (incDataAt (hOf g) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256
          (C (hOf g) (stOf g x c) x c) t) t = .ok R →
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, ((ct.slot R.ch).scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ (ct.slot R.ch).terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TE.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TE.cols j).length = ct.TE.rows.length)
      ∧ StSlotsSum (hOf g) ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub R.ch))
          (incElog (shdVi tag Rp embDigest bInRow).pub 14) shdP_U (ct.slot R.ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 4
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
                (mA shdP_U ct.M 4) i)
      ∧ 41 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 76 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 6 = ct.TE.rows.length
      ∧ ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) ct.TE
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 ct.TE.rows (toZClaim cl))) :
    StageInOK adm hOf stOf
      (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))
      (shdP_incP tag Rp embDigest bInRow C) :=
  inc_stageInOK_abs tag (shdVi tag Rp embDigest bInRow)
    (incVAt_maskVerify tag _ _ _ _ _ _ _ _)
    (incVAt_pcsVerify_a tag _ _ _ _ _ _ _ _ rfl)
    (incVAt_pcsVerify_h tag _ _ _ _ _ _ _ _ rfl)
    (incVAt_epVerify tag _ _ _ _ _ _ _ _ rfl rfl)
    rfl rfl (shdVi_ns tag Rp embDigest bInRow) rfl
    (shdVi_mRows tag Rp embDigest bInRow) rfl rfl
    (shdVi_aRows tag Rp embDigest bInRow) (shdVi_hRows tag Rp embDigest bInRow) rfl
    adm hOf stOf C hEpRoot hArith

/-- **Stage IN-C `SegComplete` for `O.parts` / `sshC_productionReadyL_epP_openShell`**. -/
theorem shdP_inc_segComplete {Γ : Type} (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow))
    (hEpRoot : ∀ g x c, adm x → rootOf (hOf g) tag 11 (C (hOf g) (stOf g x c) x c).TE = (stOf g x c).inRoot)
    (hArith : ∀ g x c t R, adm x →
      incProve (hOf g) (shdVi tag Rp embDigest bInRow)
        (incDataAt (hOf g) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256
          (C (hOf g) (stOf g x c) x c) t) t = .ok R →
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, ((ct.slot R.ch).scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ (ct.slot R.ch).terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TE.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TE.cols j).length = ct.TE.rows.length)
      ∧ StSlotsSum (hOf g) ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub R.ch))
          (incElog (shdVi tag Rp embDigest bInRow).pub 14) shdP_U (ct.slot R.ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 4
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
                (mA shdP_U ct.M 4) i)
      ∧ 41 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 76 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 6 = ct.TE.rows.length
      ∧ ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) ct.TE
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 ct.TE.rows (toZClaim cl))) :
    SegComplete adm hOf stOf
      (inSegP _ (shdP_incP tag Rp embDigest bInRow C))
      (inSeg (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))) :=
  inSeg_complete adm hOf stOf _ _ (shdP_inc_stageInOK tag Rp embDigest bInRow adm hOf stOf C hEpRoot hArith)

/-- **Stage OUT-C `StageOutOK`** (full codec + verifier completeness) from honest `OutcTables` arithmetic contracts. -/
theorem shdP_outc_stageOutOK {Γ : Type} (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins →
      OutcTables (shdVo tag Rp wDigest bOutRow s.verdict))
    (hArith : ∀ g x c cr t R, adm x →
      outcProve (hOf g) (shdVo tag Rp wDigest bOutRow (stOf g x c).verdict)
        (shdP_outcDataAt tag Rp wDigest bOutRow (hOf g) (stOf g x c).verdict (C (hOf g) (stOf g x c) x c) t) cr t = .ok R →
      let v := (stOf g x c).verdict
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, (ct.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ ct.slot.terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TB.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TB.cols j).length = ct.TB.rows.length)
      ∧ SlotsSum (hOf g) (shdVo tag Rp wDigest bOutRow v).bp shdP_U ct.slot
          (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 8
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
                (mA shdP_U ct.M 8) i)
      ∧ 76 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 38 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 38 = ct.TB.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) ct.TB
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 ct.TB.rows (toZClaim cl))) :
    StageOutOK adm hOf stOf
      (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => shdGo tag Rp wDigest bOutRow))
      (shdP_outcP tag Rp wDigest bOutRow C) :=
  outc_stageOutOK_abs tag (shdVo tag Rp wDigest bOutRow)
    (shdVo_geom_eq tag Rp wDigest bOutRow)
    (fun _ => outcVAt_maskVerify tag _ _ _ _ _ _ _ _ _)
    (fun _ => outcVAt_pcsVerify_a tag _ _ _ _ _ _ _ _ _ rfl)
    (fun _ => outcVAt_pcsVerify_h tag _ _ _ _ _ _ _ _ _ rfl)
    (fun _ => outcVAt_bVerify tag _ _ _ _ _ _ _ _ _ rfl rfl)
    (shdVo_ns tag Rp wDigest bOutRow) (shdVo_mRows tag Rp wDigest bOutRow)
    (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)
    (shdVo_aRows tag Rp wDigest bOutRow) (shdVo_hRows tag Rp wDigest bOutRow)
    (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)
    adm hOf stOf C hArith

/-- **Stage OUT-C `SegComplete` for `O.parts` / `sshC_productionReadyL_epP_openShell`**. -/
theorem shdP_outc_segComplete {Γ : Type} (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins →
      OutcTables (shdVo tag Rp wDigest bOutRow s.verdict))
    (hArith : ∀ g x c cr t R, adm x →
      outcProve (hOf g) (shdVo tag Rp wDigest bOutRow (stOf g x c).verdict)
        (shdP_outcDataAt tag Rp wDigest bOutRow (hOf g) (stOf g x c).verdict (C (hOf g) (stOf g x c) x c) t) cr t = .ok R →
      let v := (stOf g x c).verdict
      let ct := C (hOf g) (stOf g x c) x c
      (∀ s hist acc df ch0, (ct.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ ct.slot.terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TB.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TB.cols j).length = ct.TB.rows.length)
      ∧ SlotsSum (hOf g) (shdVo tag Rp wDigest bOutRow v).bp shdP_U ct.slot
          (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 8
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
                (mA shdP_U ct.M 8) i)
      ∧ 76 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 38 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 38 = ct.TB.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) ct.TB
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 ct.TB.rows (toZClaim cl))) :
    SegComplete adm hOf stOf
      (outSegP _ (shdP_outcP tag Rp wDigest bOutRow C))
      (outSeg (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => shdGo tag Rp wDigest bOutRow))) :=
  outSeg_complete adm hOf stOf _ _ (shdP_outc_stageOutOK tag Rp wDigest bOutRow adm hOf stOf C hArith)

end ShieldStages

end ZK60.HonestShield
