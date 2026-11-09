/-
D63 Lean lane L29 (2026-11-07), part 7: **`ClassifyOpen`'s field O8 for the classify run with the executable stages**,
in exactly the form `AssembleClassify.lean` names, and the protocol it is about.

With L18's run verifier at the executable stages (`classifyRunV`: stage IN-C's `incStageV`, the D12a block profile
`d12aBlockProf`, stage OUT-C's `outcStageV`) and the honest run's parts (L25's `honestRunP` of this lane's `incP`,
L25's `d12aBlockSegP`, this lane's `outcP`), O8 (`List.Forall₂ (SegComplete …) (P.parts V.L) V.parts`) holds from the
COMPONENT contracts alone: stage IN-C's `IncOK`, each block's `D12aBlockOK` (L25), stage OUT-C's `OutcOK`. The stage
verifiers are no longer parameters: what O8 still asks is, per part, each slot's arithmetic along the honest run, the
completeness of `M`'s test and of the openings (lane L10's executable functions), and the honest segments' canonical
words and counted shapes.

Every premise is an explicit hypothesis; only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StageVerifyExecComplete

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60 ZK60.ProtocolClassify ZK60.HonestClassify ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams SegGeom Segment)

variable {Hdr Coins : Type} {S : ZK60.Block.BlockShape} {Salt : Type}

/-- **O8 for the classify run with the executable stages**, in EXACTLY `ClassifyOpen.parts`' form: at the run verifier
`classifyRunV` (the executable IN-C and OUT-C, the D12a blocks) and the honest run whose parts are this lane's stage
provers and L25's block provers, every part's `SegComplete` holds from `IncOK`, each block's `D12aBlockOK` and
`OutcOK`. -/
theorem classify_parts_exec {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (R : ClassifyRunPublic S) (Lq : ℕ) (L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV)
    (outcG : Hdr → StageGeom) (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (Din : (HIn → Dig) → (s : ClsStmt Hdr) → (S.Tok → ℕ) → Coins → IncData (inc s.hdr))
    (pblk : D12aBlockP (ClsStmt Hdr) (S.Tok → ℕ) Coins Pk)
    (Dout : (HIn → Dig) → (s : ClsStmt Hdr) → (S.Tok → ℕ) → Coins → OutcData (outc s.hdr s.verdict))
    (hPin : P.inC = inSegP (incStageV inc incG) (incP inc incG Din))
    (hPblk : P.blk = d12aBlockSegP Pk sgeom check paths digest bRows bLogN bndCheck bndOpen pblk)
    (hPout : P.outC = outSegP (outcStageV outc outcG) (outcP outc outcG Dout))
    (hinc : IncOK U (classifyModel S R).admissible liftH
      (clsStmtOf R Lq P Cin h64 hr base) inc incG Din)
    (hblk : ∀ k, k < L → D12aBlockOK Pk sgeom check paths digest bRows bLogN bndCheck bndOpen U
      (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) pblk k)
    (houtc : OutcOK U (classifyModel S R).admissible liftH
      (clsStmtOf R Lq P Cin h64 hr base) outc outcG Dout) :
    List.Forall₂ (SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base))
      (P.parts L)
      (classifyRunV L preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)
        outc outcG).parts :=
  classify_parts_d12a U hU R Lq
    (classifyRunV L preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)
      outc outcG) P Cin h64 hr base Pk sgeom check paths digest bRows bLogN bndCheck bndOpen rfl
    (incP inc incG Din) pblk (outcP outc outcG Dout) hPin hPblk hPout
    (inc_stageInOK U hU _ _ _ inc incG Din hinc) hblk (outc_stageOutOK U hU _ _ _ outc outcG Dout houtc)

end ZK60.Exec.StageV
