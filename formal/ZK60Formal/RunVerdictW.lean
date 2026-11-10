/-
D63 lane L55 (2026-11-10), part 1: **the stages' verifier readers `Win`, `Wout` off the code's run header: the top
theorem's `hW`** (findings L45-1, L50 §5; the brief's deliverable 1), and finding L55-1 (the code's verdict refusal).

The app's top theorem (`eb_productionReadyL_epP_codeT`, RunEpBTopT.lean) asks, on every accepted run, that its two
readers, read off the run's transcript, are the statement's stage verifiers:
`Win (τ.take (off 0 + pin.pre)) = inc s.hdr` and `Wout (τ.take (off (Lb + 1) + pout.pre)) = outc s.hdr s.verdict`.
At the real stages (L34 / L39's `rcIncAt`, `rcOutcAt`, RunCoverStage.lean) `inc` is the constant family
`fun _ => incVAt …` and `outc` reads only the verdict, `fun _ v => outcVAt … (rcVerdict O v) …`.

* IN-C: `Win := vdWin Vi` (constant); `hW`'s first half is `inc`'s constancy (`rfl` at the real family).
* OUT-C: the code's header absorbs the verdict as its seventh absorb, ONE byte
  (`tr.absorb(b"classify-verdict", &[self.verdict])`, classify.rs:1288; L51's `clsHdrOps`, whose eight absorbs L51
  CHECKED against a real receipt). `Wout := vdWout F` reads that byte at header position `6` (`vdByte`: exactly a
  one-byte absorb, else `0`) and returns `F` of it. The byte is the verdict when the verdict is below `256`
  (`vdByte_eq`).
* **Finding L55-1**: the code refuses a verdict above `1` when it builds the statement
  (`ClassifyRunStatement::new_chunk`, classify.rs:1018-1019, "classifier run: the verdict is one bit"; the verifier's
  door builds every statement through it, classify_cli.rs:902, and the type is built only there, classify.rs:897).
  The Lean run verifier `classifyVerifyE` has no such refusal: `preA`, `preB` read only the header, and the statement's
  verdict is a `ℕ`. Without it no reader meets `hW`: the header absorbs only `v mod 256` (`vd_hdr_wrap`) while the
  stage verifiers at `v` and `v + 256` differ (`vd_outc_ne`). The repair is Lean only: the code's refusal as the
  first block's statement check (`vdChk`), which equals the existing check on every statement the code can build
  (`vdChk_eq`), so the accepted inputs are the code's [ARGUED: the code refuses before any segment, the model at
  block `0`'s step, and the app has `26 ≥ 1` blocks].
* **`vd_hW`**: the top theorem's `hW` in its exact form, PROVED at the code's header (`hRn`) for the real readers,
  from the verdict check (`hchk`, met by `vdChk`: `vdChk_le`) and `0 < Lb`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAbsHdr
import ZK60Formal.RunCoverPAlive
import ZK60Formal.RunCoverStage

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.RunShape
open ZK60.Circuit (gP GF)

/-! ## The readers -/

/-- **The verdict byte the code's header absorbs at position `6`** (`classify-verdict`, one byte), as a number; `0`
when position `6` is not a one-byte absorb. -/
def vdByte (τ : List (TItem × Dig)) : ℕ :=
  match Block.absAt τ 6 with
  | some [b] => b.toNat
  | _ => 0

/-- **Stage IN-C's reader** (`Win`): the constant verifier (the real family `fun _ => incVAt …` is constant). -/
def vdWin (Vi : IncV) (_τ : List (TItem × Dig)) : IncV := Vi

/-- **Stage OUT-C's reader** (`Wout`): the per-verdict verifier `F` at the header's verdict byte. -/
def vdWout (F : ℕ → OutcV) (τ : List (TItem × Dig)) : OutcV := F (vdByte τ)

/-- **The byte is the verdict** when the verdict is below `256`. -/
theorem vdByte_eq (τ : List (TItem × Dig)) (v : ℕ) (h : Block.absAt τ 6 = some [UInt8.ofNat v]) (hv : v < 256) :
    vdByte τ = v := by
  unfold vdByte
  rw [h]
  show (UInt8.ofNat v).toNat = v
  rw [UInt8.toNat_ofNat']
  exact Nat.mod_eq_of_lt (lt_of_lt_of_eq hv (by norm_num))

/-! ## The code's verdict refusal (finding L55-1) -/

/-- **The code's verdict refusal as a statement check** (finding L55-1): `ClassifyRunStatement::new_chunk` refuses a
verdict above `1` (classify.rs:1018-1019) before any segment is read; here it stands in front of block `k`'s existing
statement check `check0`, with the code's message. -/
def vdChk {Hdr : Type} (check0 : ClsStmt Hdr → ℕ → Except String Unit) (s : ClsStmt Hdr) (k : ℕ) :
    Except String Unit :=
  if s.verdict ≤ 1 then check0 s k else .error "classifier run: the verdict is one bit"

/-- On every statement the code can build (verdict `0` or `1`), `vdChk` IS the existing check. -/
theorem vdChk_eq {Hdr : Type} (check0 : ClsStmt Hdr → ℕ → Except String Unit) (s : ClsStmt Hdr) (k : ℕ)
    (hv : s.verdict ≤ 1) : vdChk check0 s k = check0 s k := by
  unfold vdChk
  exact ite_eq_left_iff.mpr (fun h => absurd hv h)

/-- **`vdChk` passes only a verdict of at most `1`** (the premise `hchk` of `vd_hW`, met). -/
theorem vdChk_le {Hdr : Type} (check0 : ClsStmt Hdr → ℕ → Except String Unit) :
    ∀ s : ClsStmt Hdr, vdChk check0 s 0 = .ok () → s.verdict ≤ 1 := by
  intro s h
  unfold vdChk at h
  split at h
  · assumption
  · cases h

/-- **An accepted run passed block `0`'s statement check** (when the run has a block). -/
theorem vd_check0_of_accept {Hdr : Type} (V : RunV Hdr) (H : HIn → Dig) (s : ClsStmt Hdr)
    (segs : List (List UInt8)) (hE : classifyVerifyE V H s segs = .ok ()) (hL : 0 < V.L) :
    V.blk.check s 0 = .ok () := by
  obtain ⟨-, -, -, cr₁, cr₂, cr₃, t₁, t₂, t₃, -, hseg, -⟩ := (classifyVerifyE_ok_iff V H s segs).mp hE
  obtain ⟨n, hn⟩ : ∃ n, V.L = n + 1 := ⟨V.L - 1, by omega⟩
  rw [hn, List.range_succ_eq_map, List.map_cons] at hseg
  generalize ((segs.drop 1).take (n + 1)) = bs at hseg
  cases bs with
  | nil => simp only [SegsOk] at hseg
  | cons b bs =>
    obtain ⟨c, τ, hst, -⟩ := hseg
    exact ((blockSeg_step_ok_iff H s _ b cr₁ t₁ c τ V.blk 0).mp hst).1

/-- **Without the refusal the header cannot tell `v` from `v + 256`**: the code's header absorbs the verdict as one
byte (`UInt8.ofNat v`), so its eight operations are the same at both verdicts (finding L55-1). -/
theorem vd_hdr_wrap (w : ClsHdrW) (r : Dig) (v : ℕ) : clsHdrOps w r (v + 256) = clsHdrOps w r v := by
  have hb : UInt8.ofNat (v + 256) = UInt8.ofNat v := by
    apply UInt8.toNat_inj.mp
    rw [UInt8.toNat_ofNat', UInt8.toNat_ofNat', show (2 : ℕ) ^ 8 = 256 by norm_num]
    omega
  unfold clsHdrOps
  rw [hb]

/-- **…while stage OUT-C's verifiers at the two verdicts differ** (they carry the verdict in their public data): no
reader of the header is both (finding L55-1). -/
theorem vd_outc_ne (tag : MTag) (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx lr blr q bq v : ℕ) :
    outcVAt tag (rcVerdict O (v + 256)) geo blk bd idx lr blr q bq
      ≠ outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq := by
  intro h
  have h2 := congrArg (fun V : OutcV => V.pub.verdict) h
  change v + 256 = v at h2
  omega

/-! ## `hW` at the code's header -/

section W

variable {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type} {Lq : ℕ}

/-- **THE TOP THEOREM'S `hW`, PROVED AT THE CODE'S HEADER** (findings L45-1, L50; L51's `ab_verdictAbs`). On every
accepted run of a run whose header is the code's (`hRn`), stage IN-C's reader is the constant verifier (`hinc`: the real
family is constant) and stage OUT-C's reader `vdWout F`, reading the verdict byte at header position `6`, is the
statement's OUT-C verifier (`houtc`: the real family reads only the verdict), given the code's verdict refusal (`hchk`,
met by `vdChk`) and a block (`0 < Lb`; the app has `26`). The statement is the top theorem's `hW` with
`Win := vdWin Vi`, `Wout := vdWout F`, at any block profile `blk`. -/
theorem vd_hW (Rp : ClassifyRunPublicP S) (Lb : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) (key : Option Dig) (domain : List UInt8)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG blk outc outcG) key domain Lq)
    (hw : Hdr → ClsHdrW) (hRn : ∀ s, RtRun.hdr Rn s = clsHdrOf hw s)
    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi) (houtc : ∀ hd v, outc hd v = F v)
    (hchk : ∀ s : ClsStmt Hdr, blk.check s 0 = .ok () → s.verdict ≤ 1) (hLb : 0 < Lb) (pin pout : RtPart) :
    ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (RunShapeP.classifyProtocolUExecP Rp Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify
        G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      vdWin Vi ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take ((RtRun.pf Rn).off 0 + pin.pre))
          = inc (A.run G).1.hdr
        ∧ vdWout F ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take
            ((RtRun.pf Rn).off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict := by
  intro A G hacc
  have hE := RunShapeP.rc_uexecP_E Rp Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e G _ _ hacc
  rw [OC.runLog_fst] at hE
  refine ⟨(hinc _).symm, ?_⟩
  have hv1 : (A.run G).1.verdict ≤ 1 := hchk _ (vd_check0_of_accept _ _ _ _ hE hLb)
  have h8 := ab_off0 hw Rn hRn G (A.run G).1 (A.run G).2 hE
  rw [RtProf.off_zero] at h8
  have hle : (RtRun.pf Rn).hdrLen ≤ (RtRun.pf Rn).off (Lb + 1) := Nat.le_add_right _ _
  have h6 : 6 < (RtRun.pf Rn).off (Lb + 1) + pout.pre := by omega
  have habs : Block.absAt ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take
      ((RtRun.pf Rn).off (Lb + 1) + pout.pre)) 6 = some [UInt8.ofNat (A.run G).1.verdict] :=
    ab_verdictAbs hw Rn hRn G (A.run G).1 (A.run G).2 hE _ h6
  unfold vdWout
  rw [vdByte_eq _ _ habs (by omega)]
  exact (houtc _ _).symm

end W

end ZK60.ProtocolClassify
