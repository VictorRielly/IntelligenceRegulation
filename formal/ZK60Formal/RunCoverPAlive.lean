/-
D63 lane L43 (2026-11-10), part 7a: **the cover with "some part" at the run model with ONE SHAPE PER BLOCK** (finding
L40-1: the app's Shieldstral model has 26 distinct block calibrations, so only L40's per-block-shape gates apply).

* **`rc_cover3_someP`**: L39's `rc_cover3_some` at L40's per-block-shape model (`ClassifyRunPublicP`, `BlockOn
  R.blks[k].pub`, `InOkP`, `BlocksOkP`, `OutOkP`): L40's `cover3_of_runParts_ordP` with `hdin`, `hdblk`, `hdout` asking
  a doomed entrant in SOME part (`RcSome`); its conclusion is the same, the premise `h3` of L40's gate.
* L39's `rc_some_of_part` (shape-free) shows the per-part form implies the some-part form: the new premises are
  weaker.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunShapeGate
import ZK60Formal.RunCoverAlive

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify.RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

section Cover

variable {S : BlockShape} {Lq : ℕ} {Coins : Type}

/-- **THE COVER WITH "SOME PART", ONE SHAPE PER BLOCK** (L39's `rc_cover3_some` at L40's model): on an accepted
receipt outside the extraction failure `Ex`, the kinds of `Ks` alive in order (`halive`), and if stage IN-C's
conclusion, block `k`'s `BlockOn` at its own shape, or stage OUT-C's conclusion fails, a sub-protocol of SOME part
entered its window doomed. Then an accepted receipt on which one of the three conclusions fails lies in `Ex` or in the
event of one of the kinds: the premise `h3` of L40's gate. -/
theorem rc_cover3_someP (R : ClassifyRunPublicP S) (P : Protocol (QB Lq) Dig Coins (classifyModelP R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (tr : (QB Lq → Dig) → P.Stmt × P.Receipt → List (TItem × Dig))
    (Ks : List (KindRun tr)) (hnp : ∀ K ∈ Ks, K.np = R.blks.length + 2)
    (Ls : List (FirstKind Lq (P.Stmt × P.Receipt))) (hsub : ∀ K ∈ Ks, K.toFirstKind ∈ Ls)
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop)
    (halive : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      AliveOrd Ks (R.blks.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ InOkP R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      RcSome Ks (R.blks.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.blks.length),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ BlockOn R.blks[k].pub ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      RcSome Ks (R.blks.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ OutOkP R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      RcSome Ks (R.blks.length + 2) (A.runLog G).2 (tr G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOkP R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOkP R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOkP R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) →
        Ex A G ∨ ∃ K ∈ Ls, K.Ev A G := by
  intro A G hv hbad
  by_cases hx : Ex A G
  · exact Or.inl hx
  · right
    have hev : RcSome Ks (R.blks.length + 2) (A.runLog G).2 (tr G (A.run G)) → ∃ K' ∈ Ls, K'.Ev A G := by
      rintro ⟨K, hK, i, hi, hc⟩
      exact kindEv_of_dm_ord Ks (R.blks.length + 2) hnp Ls hsub A G (halive A G hv hx) ⟨K, hK, i, hi, hc⟩
    by_cases hin : InOkP R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
    · by_cases hblk : BlocksOkP R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      · have hout : ¬ OutOkP R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) :=
          fun h => hbad ⟨hin, hblk, h⟩
        exact hev (hdout A G hv hx hout)
      · unfold BlocksOkP at hblk
        simp only [not_forall] at hblk
        obtain ⟨k, hk, hk'⟩ := hblk
        exact hev (hdblk A G k hk hv hx hk')
    · exact hev (hdin A G hv hx hin)

end Cover

section Accept

open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV)

variable {S : BlockShape} {Hdr Salt Coins : Type} {Lq : ℕ}

/-- **An accepted receipt of the per-block-shape production instance is accepted by the run verifier**
(`classifyProtocolUExecP`'s verdict is `okB` of `classifyVerifyE`). -/
theorem rc_uexecP_E (R : ClassifyRunPublicP S) (Lb : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt)
    (h : (classifyProtocolUExecP R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G () s rc
      = true) :
    classifyVerifyE (classifyRunV Lb preA preB start inc incG blk outc outcG) (liftH G) s rc = .ok () := by
  have h' : okB (classifyVerifyE (classifyRunV Lb preA preB start inc incG blk outc outcG) (liftH G) s rc) = true := h
  obtain ⟨u, hu⟩ := (okB_eq_true _).mp h'
  cases u
  exact hu

/-- **An accepted output has the run profile's shape** (`RtRun.accept`), read at the prover's output `A.run G`. -/
theorem rc_good_of_uexecP (R : ClassifyRunPublicP S) (Lq Lb : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) {key : Option Dig} {domain : List UInt8}
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG blk outc outcG) key domain Lq)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (h : (classifyProtocolUExecP R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G ()
      (A.runLog G).1.1 (A.runLog G).1.2 = true) :
    RtGood Lq (RtRun.pf Rn) ((RtRun.rd Rn) (A.run G)) := by
  have hE := rc_uexecP_E R Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e G _ _ h
  have hg := (Rn.accept (liftH G) _ _ hE).1
  rw [OC.runLog_fst] at hg
  exact hg

end Accept

end ZK60.ProtocolClassify.RunShapeP
