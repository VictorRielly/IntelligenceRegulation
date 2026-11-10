/-
D63 lane L34 (2026-11-09), part 6 (the first premise of the endpoint only): **the closing opening's two windows are at
steps' ends on the run's transcript** (the gate's `hwin`, L30 §5.4).

Every part of the run ends with a closing opening `X` (stage IN-C: the input token endpoint; a block: the previous
boundary; stage OUT-C: `B_out`). Its two windows are at the profile's positions `off i + oX` (before its batching run)
and `off i + oBX` (after the batching run and the group vectors). On an output of the profile's shape both are steps'
ends under the wide parse, and both lie on the transcript (`rtTr_winX`).

At part `0` this is the premise `hwin` of `classifyU_productionReady_run_r13_token` for a column test whose windows are
the input endpoint opening's (`rt_hwin`): acceptance gives the shape (`RtRun.acceptU`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrVerify

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Block (BlockShape)

/-- The related entry of a `Forall₂` at a position. -/
theorem rt_forall₂_get {α β : Type} {R : α → β → Prop} {l₁ : List α} {l₂ : List β} (h : List.Forall₂ R l₁ l₂) :
    ∀ (i : ℕ) (a : α), l₁[i]? = some a → ∃ b, l₂[i]? = some b ∧ R a b := by
  induction h with
  | nil =>
    intro i a h
    simp at h
  | cons hab _ ih =>
    intro i a h
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at h
      subst h
      exact ⟨_, List.getElem?_cons_zero, hab⟩
    | succ i =>
      obtain ⟨b, hb, hr⟩ := ih i a (by simpa using h)
      exact ⟨b, by simpa using hb, hr⟩

/-! ## An opening's steps cut at its second window -/

/-- An opening's steps before its second window: the batching run and the group vectors. -/
def rtPcsA (w : ℕ) (o : Block.OpeningZk) : List Stp := .sq w :: vecStps o.groupVecs

/-- An opening's steps from its second window: `"pcs-prox"` and the index run. -/
def rtPcsB (m : ℕ) (o : Block.OpeningZk) : List Stp :=
  [.ab Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes), .sq m]

theorem rt_pcsStps_split (w m : ℕ) (o : Block.OpeningZk) : pcsStps w m o = rtPcsA w o ++ rtPcsB m o := by
  simp [pcsStps, pcsPre, rtPcsA, rtPcsB]

theorem rt_pcsA_length (w : ℕ) (o : Block.OpeningZk) : (stpsOps (rtPcsA w o)).length = w + o.groupVecs.length := by
  rw [rtPcsA, stpsOps_cons, List.length_append, stpsOps_vecStps_length]
  simp [Stp.ops]

/-- A part's steps before its closing opening: the single phase, `M`, `A`, `H`. -/
def rtPartPreX (p : RtPart) (d : RtData) : List Stp :=
  opsStps d.pre ++ (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO ++ pcsStps p.wH p.mH d.hO))

theorem rtPartStps_splitX (p : RtPart) (d : RtData) :
    rtPartStps p d = rtPartPreX p d ++ pcsStps p.wX p.mX d.xO := by
  simp only [rtPartStps, rtPartPreX, List.append_assoc]

/-- **The closing opening's first window is at the profile's position** `oX` in the part. -/
theorem rtPartPreX_length (Lq : ℕ) (p : RtPart) (d : RtData) (h : RtPartOk Lq p d) :
    (stpsOps (rtPartPreX p d)).length = p.oX := by
  obtain ⟨h1, -, h3, h4, -, -⟩ := h
  simp only [rtPartPreX, stpsOps_append, List.length_append, stpsOps_opsStps, stpsOps_mStps_length,
    stpsOps_pcsStps_length, h1, h3, h4, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
  omega

/-! ## The windows on the run's transcript -/

section Win

variable (key : Option Dig) (domain : List UInt8) (Lq : ℕ) {α : Type} (pf : RtProf)
  (rd : α → List Op × List RtData)

/-- **Part `i`'s closing opening has its two windows at steps' ends on the run's transcript**, at the profile's
positions `off i + oX` and `off i + oBX`, on every output of the profile's shape; and the second window lies on the
transcript. -/
theorem rtTr_winX (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (i : ℕ)
    (hi : i < pf.parts.length) :
    tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + (pf.part i).oX)) = some 0
      ∧ pf.off i + (pf.part i).oBX ≤ (rtTr key domain Lq pf rd G o).length
      ∧ tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + (pf.part i).oBX)) = some 0 := by
  have hp : pf.parts[i]? = some (pf.part i) := by
    have e : pf.part i = pf.parts[i] := by
      unfold RtProf.part
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some]
    rw [e]
    exact List.getElem?_eq_getElem hi
  obtain ⟨d, hd, hok⟩ := rt_forall₂_get h.2.2.2 i _ hp
  have hX := rtPartPreX_length Lq _ d hok
  have hgX : d.xO.groupVecs.length = (pf.part i).gX := hok.2.2.2.2.1
  have h1 := rtTr_part key domain Lq pf rd hv G o h i _ d hp hd (rtPartPreX (pf.part i) d)
    (pcsStps (pf.part i).wX (pf.part i).mX d.xO) (rtPartStps_splitX _ d)
  have h2 := rtTr_part key domain Lq pf rd hv G o h i _ d hp hd
    (rtPartPreX (pf.part i) d ++ rtPcsA (pf.part i).wX d.xO) (rtPcsB (pf.part i).mX d.xO)
    (by rw [rtPartStps_splitX, rt_pcsStps_split, List.append_assoc])
  have hB : (stpsOps (rtPartPreX (pf.part i) d ++ rtPcsA (pf.part i).wX d.xO)).length = (pf.part i).oBX := by
    rw [stpsOps_append, List.length_append, hX, rt_pcsA_length, hgX]
    rfl
  have hlen : ((rtTr key domain Lq pf rd G o).take (pf.off i + (stpsOps (rtPartPreX (pf.part i) d
      ++ rtPcsA (pf.part i).wX d.xO)).length)).length = pf.off i + (pf.part i).oBX := by
    rw [h2.1, Block.opTrace_length, stpsOps_append, List.length_append, (rtPre_facts Lq pf (rd o) h i).2.1, hB]
  rw [hX] at h1
  rw [hB] at h2 hlen
  rw [List.length_take] at hlen
  exact ⟨h1.2.2.1, by omega, h2.2.2.1⟩

end Win

/-! ## The gate's `hwin` -/

section HWin

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ} {S : BlockShape}
  {Salt Coins : Type}

/-- **The gate's `hwin` for a column test at the input endpoint opening's windows** (L30 §5.4). The input endpoint is
stage IN-C's closing opening, part `0` of the run. For windows `aA`, `aB` at its profile positions, on every accepted
run both are steps' ends under the wide parse (`rtRC2`'s widths) and `aB` lies on the run's transcript: the premise
`hwin` of `classifyU_productionReady_run_r13_token` at `RCx := rtRC2 …`, `tr := rtTr …` (its hypothesis that no
extraction failure happened is not used). -/
theorem rt_hwin (R : RtRun V key domain Lq) (hv : (RtRun.pf R).Valid) (Rp : ClassifyRunPublic S)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) (aA aB : ℕ)
    (hA : aA = (RtRun.pf R).off 0 + ((RtRun.pf R).part 0).oX)
    (hB : aB = (RtRun.pf R).off 0 + ((RtRun.pf R).part 0).oBX)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hacc : (classifyProtocolU S Rp Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true) :
    tRem (rtW (RtRun.pf R).sqs) ((rtTr key domain Lq (RtRun.pf R) (RtRun.rd R) G (A.run G)).take aA) = some 0
      ∧ aB ≤ (rtTr key domain Lq (RtRun.pf R) (RtRun.rd R) G (A.run G)).length
      ∧ tRem (rtW (RtRun.pf R).sqs) ((rtTr key domain Lq (RtRun.pf R) (RtRun.rd R) G (A.run G)).take aB) = some 0 := by
  have hgood : RtGood Lq (RtRun.pf R) (RtRun.rd R (A.run G)) := by
    rw [← OC.runLog_fst G A]
    exact (R.acceptU Rp P Cin h64 hr base e G (A.runLog G).1.1 (A.runLog G).1.2 hacc).1
  have h0 : 0 < (RtRun.pf R).parts.length := by
    rw [RtRun.parts_length R]
    omega
  rw [hA, hB]
  exact rtTr_winX key domain Lq (RtRun.pf R) (RtRun.rd R) hv G (A.run G) hgood 0 h0

/-- The input endpoint opening's windows are after the run header (the gate's `hwA`, `hwB` through `rtRCx_hw`). -/
theorem rt_hwin_hdr (pf : RtProf) : pf.hdrLen ≤ pf.off 0 + (pf.part 0).oX ∧ pf.hdrLen ≤ pf.off 0 + (pf.part 0).oBX := by
  rw [pf.off_zero]
  exact ⟨Nat.le_add_right _ _, Nat.le_add_right _ _⟩

end HWin

end ZK60.ProtocolClassify
