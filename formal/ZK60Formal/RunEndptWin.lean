/-
D63 lane L51 (2026-11-10), part 2: **the input endpoint test's windows on the run's transcript** (the top theorem's
`hwin`, L46 §5, L48 §5).

The app's top theorem (`og_productionReadyL_epP_exec_blk`) asks, of the endpoint column test `T`, that its two windows
`T.aA` (the first half: the batching squeezes) and `T.aB` (the second half: `"pcs-prox"` and the index squeezes) are at
steps' ends of the run's wide parse, and that the transcript reaches `T.aB` (`hwin`). The test is the input endpoint's
opening, which stage IN-C runs last (part `0`'s closing opening `X`, stage_in_c.rs:457-460). Its windows on the run's
transcript are part `0`'s `off 0 + oX` and `off 0 + oBX` (L34's profile: `oX`, `oBX`).

* **`ep_win_part`**: on an accepted run, for EVERY part `i`, the closing opening's two windows `off i + oX`,
  `off i + oBX` are at steps' ends of the run's wide parse and inside the transcript;
* **`ep_hwin`**: `hwin` in its exact form for any acceptance that implies the run verifier's; **`ep_hwin_top`**: the
  top theorem's `hwin` at its own acceptance (`classifyProtocolUExecP … .verify`), for a test whose windows are part
  `0`'s (`hTaA`, `hTaB`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoStageX
import ZK60Formal.RunCoverPAlive

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

section Win

variable (key : Option Dig) (domain : List UInt8) (Lq : ℕ) {α : Type} (pf : RtProf)
  (rd : α → List Op × List RtData)

/-- The steps of a part up to its closing opening's batching run (`A`'s and `H`'s openings included). -/
def epPreX (p : RtPart) (d : RtData) : List Stp :=
  opsStps d.pre ++ (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO ++ pcsStps p.wH p.mH d.hO))

/-- The steps of a part up to its closing opening's `"pcs-prox"` (the batching run and the group vectors included). -/
def epPreBX (p : RtPart) (d : RtData) : List Stp :=
  opsStps d.pre ++ (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO
    ++ (pcsStps p.wH p.mH d.hO ++ (Stp.sq p.wX :: vecStps d.xO.groupVecs))))

theorem epPreX_split (p : RtPart) (d : RtData) : rtPartStps p d = epPreX p d ++ pcsStps p.wX p.mX d.xO := by
  simp only [rtPartStps, epPreX, List.append_assoc]

theorem epPreBX_split (p : RtPart) (d : RtData) :
    rtPartStps p d = epPreBX p d
      ++ [Stp.ab Block.labPcsProx (d.xO.proxVec.flatMap Fp2.toBytes), Stp.sq p.mX] := by
  simp only [rtPartStps, epPreBX, pcsStps, pcsPre, List.append_assoc, List.cons_append, List.nil_append]

theorem epPreX_len (p : RtPart) (d : RtData) (hpd : RtPartOk Lq p d) : (stpsOps (epPreX p d)).length = p.oX := by
  obtain ⟨h1, -, hA, hH, -, -⟩ := hpd
  rw [epPreX, stpsOps_append, stpsOps_append, stpsOps_append, List.length_append, List.length_append,
    List.length_append, stpsOps_opsStps, stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length, h1, hA,
    hH]
  simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
  omega

theorem epPreBX_len (p : RtPart) (d : RtData) (hpd : RtPartOk Lq p d) :
    (stpsOps (epPreBX p d)).length = p.oBX := by
  obtain ⟨h1, -, hA, hH, hX, -⟩ := hpd
  rw [epPreBX, stpsOps_append, stpsOps_append, stpsOps_append, stpsOps_append, stpsOps_cons, List.length_append,
    List.length_append, List.length_append, List.length_append, List.length_append, stpsOps_opsStps,
    stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length, stpsOps_vecStps_length, h1, hA, hH, hX]
  simp only [Stp.ops, List.length_replicate, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
  omega

/-- **A PART'S CLOSING OPENING'S TWO WINDOWS ON THE RUN'S TRANSCRIPT**: on an output of the profile's shape, for every
part `i`, the run's wide parse is at a step's end at `off i + oX` (the batching run) and at `off i + oBX`
(`"pcs-prox"`, then the index squeezes), and the transcript reaches `off i + oBX`. -/
theorem ep_win_part (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (i : ℕ)
    (hi : i < pf.parts.length) :
    tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + (pf.part i).oX)) = some 0
      ∧ pf.off i + (pf.part i).oBX ≤ (rtTr key domain Lq pf rd G o).length
      ∧ tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + (pf.part i).oBX)) = some 0 := by
  have hlen := h.2.2.2.length_eq
  have hid : i < (rd o).2.length := hlen ▸ hi
  have hp : pf.parts[i]? = some (pf.part i) := by
    rw [List.getElem?_eq_getElem hi]
    unfold RtProf.part
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some]
  have hd : (rd o).2[i]? = some ((rd o).2[i]'hid) := List.getElem?_eq_getElem hid
  have hpd : RtPartOk Lq (pf.part i) ((rd o).2[i]'hid) := rk_forall₂_getElem? h.2.2.2 i _ _ hp hd
  obtain ⟨tkA, -, tremA, -, -⟩ := rtTr_part key domain Lq pf rd hv G o h i (pf.part i) _ hp hd
    (epPreX (pf.part i) ((rd o).2[i]'hid)) (pcsStps (pf.part i).wX (pf.part i).mX ((rd o).2[i]'hid).xO)
    (epPreX_split _ _)
  obtain ⟨tkB, -, tremB, -, -⟩ := rtTr_part key domain Lq pf rd hv G o h i (pf.part i) _ hp hd
    (epPreBX (pf.part i) ((rd o).2[i]'hid)) _ (epPreBX_split _ _)
  have hlB := rh_take_len key domain Lq pf rd G o h i _ tkB
  rw [epPreX_len Lq _ _ hpd] at tremA
  rw [epPreBX_len Lq _ _ hpd] at tremB hlB
  refine ⟨tremA, ?_, tremB⟩
  rw [List.length_take] at hlB
  have h2 := Nat.min_le_right (pf.off i + (pf.part i).oBX) (rtTr key domain Lq pf rd G o).length
  rw [hlB] at h2
  exact h2

variable {Hdr : Type} {V : RunV Hdr}

/-- The same on an accepted run of a run schedule `R`. -/
theorem ep_win_run (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (hi : i < R.pf.parts.length) :
    tRem (rtW R.pf.sqs) ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oX)) = some 0
      ∧ R.pf.off i + (R.pf.part i).oBX ≤ (R.tr G (s, segs)).length
      ∧ tRem (rtW R.pf.sqs) ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oBX)) = some 0 :=
  ep_win_part key domain Lq R.pf R.rd hv G (s, segs) (R.accept (liftH G) s segs hE).1 i hi

end Win

/-! ## The top theorem's `hwin` -/

section HWin

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **THE TOP THEOREM'S `hwin`** (its exact form: the run's wide parse `rtRC2 …`, the transcript `rtTr …` at the
adversary's output), for any acceptance predicate that implies the run verifier's, when the test's windows are part
`0`'s closing opening's (`hTaA`, `hTaB`: the input endpoint's opening, run last by stage IN-C). -/
theorem ep_hwin (R : RtRun V key domain Lq) (hL64 : Lq < 2 ^ 64) (hv : R.pf.Valid) (aA aB : ℕ)
    (hTaA : aA = R.pf.off 0 + (R.pf.part 0).oX) (hTaB : aB = R.pf.off 0 + (R.pf.part 0).oBX)
    (Acc : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (Ev : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop)
    (hacc : ∀ A G, Acc A G → classifyVerifyE V (liftH G) (A.run G).1 (A.run G).2 = .ok ()) :
    ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig), Acc A G → ¬ Ev A G →
      tRem (rtRC2 key domain hs Lq hL R.pf R.rd hL64 hv).W ((rtTr key domain Lq R.pf R.rd G (A.run G)).take aA) = some 0
        ∧ aB ≤ (rtTr key domain Lq R.pf R.rd G (A.run G)).length
        ∧ tRem (rtRC2 key domain hs Lq hL R.pf R.rd hL64 hv).W ((rtTr key domain Lq R.pf R.rd G (A.run G)).take aB)
          = some 0 := by
  intro A G hA _
  have h0 : 0 < R.pf.parts.length := by rw [RtRun.parts_length]; omega
  have hw := ep_win_run key domain Lq R hv G (A.run G).1 (A.run G).2 (hacc A G hA) 0 h0
  subst hTaA
  subst hTaB
  exact hw

open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV) in
open ZK60.Block (BlockShape) in
/-- **`hwin` AT THE TOP THEOREM'S ACCEPTANCE** (`classifyProtocolUExecP … .verify G () (A.runLog G).1.1 … = true`), for
any extraction event: the drop-in for `og_productionReadyL_epP_exec_blk`'s premise `hwin`, given that the test's
windows are part `0`'s closing opening's. -/
theorem ep_hwin_top {S : BlockShape} {Salt Coins : Type} (Rp : ZK60.RunShape.ClassifyRunPublicP S) (Lb : ℕ)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV)
    (incG : Hdr → StageGeom) (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG blk outc outcG) key domain Lq) (hL64 : Lq < 2 ^ 64)
    (hv : Rn.pf.Valid) (aA aB : ℕ) (hTaA : aA = Rn.pf.off 0 + (Rn.pf.part 0).oX)
    (hTaB : aB = Rn.pf.off 0 + (Rn.pf.part 0).oBX)
    (Ev : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) :
    ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (RunShapeP.classifyProtocolUExecP Rp Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G ()
        (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ev A G →
      tRem (rtRC2 key domain hs Lq hL Rn.pf Rn.rd hL64 hv).W ((rtTr key domain Lq Rn.pf Rn.rd G (A.run G)).take aA)
          = some 0
        ∧ aB ≤ (rtTr key domain Lq Rn.pf Rn.rd G (A.run G)).length
        ∧ tRem (rtRC2 key domain hs Lq hL Rn.pf Rn.rd hL64 hv).W ((rtTr key domain Lq Rn.pf Rn.rd G (A.run G)).take aB)
          = some 0 :=
  ep_hwin hs hL Rn hL64 hv aA aB hTaA hTaB _ Ev (fun A G h => by
    have h' := RunShapeP.rc_uexecP_E Rp Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e G _ _ h
    rw [OC.runLog_fst] at h'
    exact h')

end HWin

end ZK60.ProtocolClassify
