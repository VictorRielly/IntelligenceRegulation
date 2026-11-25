/-
D63 lane L69, Milestone A Part 2b (`HonestShieldZKFixedOps.lean`):
1. **Finding `L69-1` closure (`shdP_blkSegP_zkGuarded`, `shdP_honestRunP_zk`,
   `shdP_honest_productionReadyL_hooks_zk`)**:
   adds the prover-side `checkOpeningExec H shdP_bndOpenGeom 14` guard on internal boundaries
   `B_0..25` (matching the Rust prover, `TE`, `B_26`, and all `A`/`H` openings so `PcsStdData.hab`
   and `PcsStdData.hp` hold on every non-refused `v`), transferring `hsegIn`, `hsegBlk`, `hsegOut`,
   `hcover`, and concrete verifier hooks (`shdPreA`, `shdPreB`, `shdCheck0`, `shdDigest`, `ShieldRunReg`)
   directly into `HonestShieldTop.shdP_openShell_res`.
2. **Compositional fixed-schedule `PProg` engine (`TrChainState`, `TrChainStep`, `RawPtSpec`,
   `SliceSpec`, `SliceSpec.andThen`, `SliceSpec.finish`)**:
   Hoare-triple slice composition discharging `PtLen`, `QLE`, `DepStrict`, `DepIn`, `KCount`,
   exact per-kind counts (`hcntT/L/N`), `htr_order`, `hleaf_inj`, `hnode_inj`, and all `ptAt`
   contracts automatically across arbitrary sequential composition, finishing directly into
   `ShdScheduleMatch`.
3. **Atomic fixed-schedule combinators**:
   `fitBytes`, `trAbsorbFixed`, `merkleTreeProg_res_getRoot`, `merkleTreeProg_res_indep`,
   `merkleTreeSliceSpec`, `shdP_hdrPProgF` + `hdrSliceSpec`, `trAbsorbSliceSpec`,
   `trSqueezeSliceSpec`, `trChallengeFp2SliceSpec`, `trChallengeFp2VecSliceSpec`,
   `trSqueezeVecSliceSpec`, `posTagSliceSpec`, `absorbRootSliceSpec`, `scProveFixedProg`,
   `slotProveFixedProg`, `zkBMaskFixedProg`, and `openingAuditFixedProg`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldHooks
import ZK60Formal.HonestShieldZKFixedLib

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun ZK60.ZKHonest
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP classifyArithP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec Segment SegGeom
  labA labH labM labRows labLogCols labPbSlot labPbScalar labPbTerm)
open ZK60.Circuit (gP GF)

/-! ## 1. Finding `L69-1` Closure (`shdP_blkSegP_zkGuarded` & `shdP_honestRunP_zk`) -/

section L69_1Closure

private theorem except_cases' {ε α : Type} (x : Except ε α) :
    (∃ e, x = .error e) ∨ (∃ a, x = .ok a) := by
  cases x with
  | error e => exact Or.inl ⟨e, rfl⟩
  | ok a => exact Or.inr ⟨a, rfl⟩

/-- Whenever `checkOpeningExec H shdP_bndOpenGeom 14 cl t = .ok ()`, the pure boundary check
`shdP_bndCheckPure cl` also returns `.ok ()`. -/
theorem shdP_checkOpeningExec_implies_bndCheckPure (H : HIn → Dig)
    (cl : List Exec.Block.ZClaim) (t : Tr)
    (hok : checkOpeningExec H shdP_bndOpenGeom 14 cl t = .ok ()) :
    shdP_bndCheckPure cl = .ok () := by
  unfold checkOpeningExec shdP_bndOpenGeom at hok
  unfold shdP_bndCheckPure
  dsimp only at hok ⊢
  rcases except_cases' (auditClaims cl (2 ^ 14) 38 [32, 33, 34, 35] none 36) with ⟨e1, ha⟩ | ⟨u, ha⟩
  · rw [ha] at hok; cases hok
  · cases u
    simp only [ha, Bind.bind, Except.bind] at hok ⊢
    rcases except_cases' (openingGroupsAt cl 14) with ⟨e2, hg⟩ | ⟨gs, hg⟩
    · rw [hg] at hok; cases hok
    · simp only [hg] at hok ⊢
      by_cases hne : gs.length ≠ 2
      · rw [ite_eq_left hne] at hok
        simp only [throw, throwThe, MonadExceptOf.throw] at hok
        cases hok
      · rw [ite_eq_right hne]
        rfl

/-- **ZK-guarded block segment prover (`L69-1` fix)**: identical to `shdP_blkSegP_guarded` except
that the prover additionally enforces `checkOpeningExec H shdP_bndOpenGeom 14` on incoming boundary
claims `B_k` (`k < 26`), matching the Rust prover, `TE`, `B_26`, and all `A`/`H` openings so
`openingAuditOk = true` holds on every non-refused boundary opening. -/
noncomputable def shdP_blkSegP_zkGuarded {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) : SegP St X Coins where
  run H s x c bnd start cr t :=
    (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN
      (fun _ _ cl t0 => checkOpeningExec H shdP_bndOpenGeom 14 cl t0) bndOpen Ly Pb W k).run
      H s x c bnd start cr t

private theorem shdP_blkSegP_zkGuarded_run_eq {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (shdP_blkSegP_zkGuarded tag Pk sgeom check paths digest bRows bLogN bndOpen Ly Pb W k).run
      H s x c bnd start cr t
      = (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN
          (fun _ _ cl t0 => checkOpeningExec H shdP_bndOpenGeom 14 cl t0) bndOpen Ly Pb W k).run
          H s x c bnd start cr t := by
  dsimp only [shdP_blkSegP_zkGuarded]

/-- Whenever `shdP_blkSegP_zkGuarded` succeeds, `shdP_blkSegP_guarded` with pure `shdP_bndCheckPure`
returns the exact same result. -/
theorem shdP_blkSegP_zkGuarded_implies_pure {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
    (res : (Dig → List UInt8) × Carry × Tr)
    (hrun : (shdP_blkSegP_zkGuarded tag Pk sgeom check paths digest bRows bLogN bndOpen Ly Pb W k).run
      H s x c bnd start cr t = .ok res) :
    (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN
      (fun _ _ cl _ => shdP_bndCheckPure cl) bndOpen Ly Pb W k).run
      H s x c bnd start cr t = .ok res := by
  dsimp only [shdP_blkSegP_zkGuarded] at hrun
  unfold shdP_blkSegP_guarded at hrun ⊢
  dsimp only at hrun ⊢
  unfold blockFrame d12aBlockProf at hrun ⊢
  dsimp only at hrun ⊢
  by_cases hbad : blkAlphaBad Ly Pb
      (bgaOf H (Pk k) (rootOf H tag 16 (W H s x c k).coreT.TA)
        (rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) (W H s x c k).coreT.M))
        (Exec.Block.absorbRoot H
          ((t.absorbU64 H labRunStage (UInt64.ofNat (k + 1))).absorb H labRunBlock (digest s k).toList)
          labB (rootOf H tag 16 (W H s x c k).TB_next) (bRows (k + 1)) (bLogN (k + 1)))) = true
  · rw [ite_eq_left hbad] at hrun; cases hrun
  · rw [ite_eq_right hbad] at hrun ⊢
    unfold shdP_blkSegP at hrun ⊢
    dsimp only [blockFrame, d12aBlockProf] at hrun ⊢
    by_cases hown : decide (cr.root = rootOf H tag 16 (W H s x c k).TB_prev
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 (W H s x c k).TB_prev.rows (toZClaim cl)) = true
    · rw [ite_eq_left hown] at hrun ⊢
      cases hcp : coreProve H (Pk k) _ _ with
      | error e => rw [hcp] at hrun; cases hrun
      | ok R =>
        rw [hcp] at hrun; dsimp only at hrun ⊢
        cases hbc : checkOpeningExec H shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp) R.t7 with
        | error e => rw [hbc] at hrun; cases hrun
        | ok u =>
          cases u
          rw [hbc] at hrun; dsimp only at hrun ⊢
          rw [shdP_checkOpeningExec_implies_bndCheckPure H _ _ hbc]
          dsimp only
          exact hrun
    · rw [ite_eq_right hown] at hrun; cases hrun

/-- Total ZK-guarded block segment prover family (`ℕ → SegP`), matching `shdP_blkSegP_run`. -/
noncomputable def shdP_blkSegP_run_zk {Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (k : ℕ) : SegP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins :=
  if hk : k < 26 then
    shdP_blkSegP_zkGuarded tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
      (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38)
      (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
      (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf) k
  else
    ⟨fun _ _ _ _ _ _ _ _ => .error ()⟩

/-- **Unified concrete ZK-guarded honest Shieldstral T128 R13 prover (`RunP`)**:
identical to `shdP_honestRunP` on `hdr`, `inC`, `outC`, and `refused`, with `blk` upgraded to
`shdP_blkSegP_run_zk` so boundaries `B_0..25` check `openingChallenges` on the prover side (`L69-1`). -/
noncomputable def shdP_honestRunP_zk {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    RunP Hdr (shieldS0.Tok → ℕ) Coins where
  hdr := hdr
  inC := inSegP _ (shdP_incP tag Rp embDigest bInRow
    (fun H _ x c => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (incRndOf c)))
  blk := shdP_blkSegP_run_zk tag ioIn ioOut checkOpening Rp hR hweights hinPub
    (fun b hb => (hweights b hb).act0) check0 digest incRndOf blkRndOf
  outC := outSegP _ (shdP_outcP tag Rp wDigest bOutRow
    (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
      (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf) outcRndOf))
  refused := refused

private theorem proveSegs_congr {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps₁ ps₂ : List (SegP St X Coins)) (cr : Carry) (t : Tr),
      List.Forall₂ (fun p₁ p₂ => ∀ bnd' st' cr' t', p₁.run H s x c bnd' st' cr' t' = p₂.run H s x c bnd' st' cr' t') ps₁ ps₂ →
      proveSegs H s x c bnd ps₁ cr t = proveSegs H s x c bnd ps₂ cr t
  | [], [], _, _, _ => rfl
  | [], _ :: _, _, _, h => absurd h (by simp)
  | _ :: _, [], _, _, h => absurd h (by simp)
  | p₁ :: ps₁, p₂ :: ps₂, cr, t, h => by
    obtain ⟨h1, h2⟩ := List.forall₂_cons.mp h
    unfold proveSegs
    rw [h1 bnd (Exec.Block.posTag H t) cr t]
    cases p₂.run H s x c bnd (Exec.Block.posTag H t) cr t with
    | error e => rfl
    | ok r =>
      dsimp only [Bind.bind, Except.bind]
      rw [proveSegs_congr H s x c bnd ps₁ ps₂ r.2.1 r.2.2 h2]

private theorem forall₂_append {α β : Type} {R : α → β → Prop} :
    ∀ {l₁ l₂ : List α} {r₁ r₂ : List β},
      List.Forall₂ R l₁ r₁ → List.Forall₂ R l₂ r₂ → List.Forall₂ R (l₁ ++ l₂) (r₁ ++ r₂)
  | [], _, [], _, _, h2 => h2
  | _ :: _, _, _ :: _, _, .cons h1 ht1, h2 => .cons h1 (forall₂_append ht1 h2)

private theorem forall₂_map_range {α β : Type} {R : α → β → Prop} (f : ℕ → α) (g : ℕ → β) :
    ∀ (n : ℕ), (∀ k, k < n → R (f k) (g k)) →
      List.Forall₂ R ((List.range n).map f) ((List.range n).map g)
  | 0, _ => List.Forall₂.nil
  | n + 1, h => by
    rw [List.range_succ, List.map_append, List.map_append, List.map_singleton, List.map_singleton]
    exact forall₂_append (forall₂_map_range f g n (fun k hk => h k (Nat.lt_succ_of_lt hk)))
      (List.Forall₂.cons (h n (Nat.lt_succ_self n)) List.Forall₂.nil)

private theorem clsStmtOfP_eq_of_hdr {S : Block.BlockShape} {Hdr Salt Coins : Type}
    (R : ClassifyRunPublicP S) (Lq : ℕ) (P₁ P₂ : RunP Hdr (S.Tok → ℕ) Coins)
    (hhdr : P₁.hdr = P₂.hdr) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) :
    clsStmtOfP R Lq P₁ Cin h64 hr base = clsStmtOfP R Lq P₂ Cin h64 hr base := by
  funext G x c; unfold clsStmtOfP; rw [hhdr]

/-- **`hsegIn` for `shdP_honestRunP_zk`**. -/
theorem shdP_honestRunP_zk_hsegIn {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheckV : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    let P := shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf
    SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.inC
      (inSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheckV).inC) :=
  shdP_inc_segComplete_of_adm tag Lq hL20 Rp hinPub hV131072 embDigest bInRow epBase incRndOf
    (clsStmtOfP Rp Lq
      (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (fun _ _ _ _ => rfl)

/-- **`hsegBlk` for `shdP_honestRunP_zk`** against the verifier with pure `shdP_bndCheckPure`. -/
theorem shdP_honestRunP_zk_hsegBlk {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq
        (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9) :
    let P := shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf
    ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest
          (fun _ _ cl _ => shdP_bndCheckPure cl)).blk k) := by
  intro P k hk
  let P_pure : RunP Hdr (shieldS0.Tok → ℕ) Coins :=
    { hdr := hdr
      inC := P.inC
      blk := shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) check0 digest (fun _ _ cl _ => shdP_bndCheckPure cl)
        incRndOf blkRndOf
      outC := P.outC
      refused := refused }
  have hst : clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base
    = clsStmtOfP Rp Lq P_pure (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base :=
    clsStmtOfP_eq_of_hdr Rp Lq P P_pure rfl (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base
  have hCheck0' : ∀ k', k' < 26 → ∀ G x' c', (classifyModelP Rp).admissible x' →
      check0 (clsStmtOfP Rp Lq P_pure (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x' c') k' = .ok () := by
    intro k' hk' G' x' c' hx'
    rw [← hst]
    exact hCheck0 k' hk' G' x' c' hx'
  have hc0 := shdP_blk_segComplete_runV_valid tag Lq hL20 key Rp hR hw preA preB check0 digest
    (fun _ _ cl _ => shdP_bndCheckPure cl) ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
    hweights hinPub houtPub incRndOf blkRndOf P_pure epBase (fun _ _ => rfl) hCheck0' hgrpA hgrpH
    (fun _ _ _ cl _ h => shdP_blk_hgrpB_of_pure cl h) k hk
  rw [hst]
  intro g x c bnd cr t enc cr' t' hx hrun
  refine hc0 g x c bnd cr t enc cr' t' hx ?_
  have hrun' : (shdP_blkSegP_run_zk tag ioIn ioOut checkOpening Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) check0 digest incRndOf blkRndOf k).run
      (liftH g) (clsStmtOfP Rp Lq P_pure (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base g x c)
      x c bnd (Exec.Block.posTag (liftH g) t) cr t = .ok (enc, cr', t') := hrun
  unfold shdP_blkSegP_run_zk at hrun'
  rw [dite_eq_left hk] at hrun'
  change (shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) check0 digest (fun _ _ cl _ => shdP_bndCheckPure cl)
      incRndOf blkRndOf k).run
      (liftH g) (clsStmtOfP Rp Lq P_pure (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base g x c)
      x c bnd (Exec.Block.posTag (liftH g) t) cr t = .ok (enc, cr', t')
  unfold shdP_blkSegP_run
  rw [dite_eq_left hk]
  exact shdP_blkSegP_zkGuarded_implies_pure tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
    (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
    (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38)
    (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
    (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) incRndOf blkRndOf)
    k (liftH g)
    (clsStmtOfP Rp Lq P_pure (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base g x c)
    x c bnd (Exec.Block.posTag (liftH g) t) cr t (enc, cr', t') hrun'

/-- **`hsegOut` for `shdP_honestRunP_zk`**. -/
theorem shdP_honestRunP_zk_hsegOut {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheckV : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    let P := shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf
    SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.outC
      (outSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheckV).outC) :=
  shdP_outc_segComplete_of_adm tag Lq Rp houtPub wDigest bOutRow
    (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf)
    outcRndOf
    (clsStmtOfP Rp Lq
      (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (fun _ _ _ _ => rfl)
    (fun _ x c hx => by
      unfold shdP_bndTableLast_total
      rw [dite_eq_left hx]
      exact shdP_bndTableAt_last_outcSpec Rp hR hweights hinPub houtPub (incRndOf c) (blkRndOf c) x hx)

/-- **`O.refuse` (`hcover`) for `shdP_honestRunP_zk`**: at any fixed oracle `G`, `shdP_honestRunP_zk`
runs identically to `shdP_honestRunP` with `bndCheck := fun _ _ cl t => checkOpeningExec (liftH G)
shdP_bndOpenGeom 14 cl t`, discharged directly by `shdP_refuse_hcover_at`. -/
theorem shdP_honestRunP_zk_hcover {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheckV : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e') :
    let P := shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest epBase incRndOf blkRndOf outcRndOf
    let W := shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf
    ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheckV)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error () →
      ∃ i, (shdP_runSite tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow blkDig epBase W x i).fires shdP_U G c := by
  intro P W x hx G c herr
  let bcG : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit :=
    fun _ _ cl t => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t
  let P_eq := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
    embDigest bInRow wDigest bOutRow check0 digest bcG epBase incRndOf blkRndOf outcRndOf
  have hsegEq :
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheckV)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c
      = honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bcG)
        P_eq (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c := by
    unfold honestSegs RunP.parts
    have hVstart : (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheckV).start
      = (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bcG).start := by
      dsimp only [shdP_runV, classifyRunV]
    have hPhdr : P.hdr = P_eq.hdr := by dsimp only [P, P_eq, shdP_honestRunP_zk, shdP_honestRunP]
    have hPinC : P.inC = P_eq.inC := by dsimp only [P, P_eq, shdP_honestRunP_zk, shdP_honestRunP]
    have hPoutC : P.outC = P_eq.outC := by dsimp only [P, P_eq, shdP_honestRunP_zk, shdP_honestRunP]
    rw [hVstart, hPhdr, hPinC, hPoutC]
    refine proveSegs_congr (liftH G) _ x c _ _ _ carry0 _ ?_
    refine List.Forall₂.cons (fun _ _ _ _ => rfl) ?_
    refine forall₂_append (forall₂_map_range P.blk P_eq.blk 26 fun k hk => ?_)
      (List.Forall₂.cons (fun _ _ _ _ => rfl) List.Forall₂.nil)
    intro bnd' st' cr' t'
    dsimp only [P, P_eq, shdP_honestRunP_zk, shdP_honestRunP]
    unfold shdP_blkSegP_run_zk shdP_blkSegP_run
    rw [dite_eq_left hk, dite_eq_left hk]
    exact shdP_blkSegP_zkGuarded_run_eq tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
      (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38)
      (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
      (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) incRndOf blkRndOf)
      k (liftH G) _ x c bnd' st' cr' t'
  rw [hsegEq] at herr
  exact shdP_refuse_hcover_at tag Lq hL20 key Rp hR hV131072 hinPub hw preA preB check0 paths digest G bcG
    ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hB0 hBk hB26 blkDig epBase P_eq hdig W
    (fun x' hx' => shdP_honestRun_proverMatch tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
      checkOpening embDigest bInRow wDigest bOutRow check0 digest bcG blkDig hdig
      epBase incRndOf blkRndOf outcRndOf x' hx')
    (hchkA G) (hchkH G) (fun _ _ _ _ e _ he => ⟨e, he⟩)
    (fun x' hx' c' t R hR_inc => by
      rw [shdP_honestRunWitness_incTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x' hx' (liftH G) c'] at hR_inc
      rw [shdP_honestRunWitness_TB0 (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x' hx' c']
      exact (shdP_inc_arith (Hdr := Hdr) (liftH G) tag Rp hinPub hV131072 embDigest bInRow x' hx'
        (epBase c') (incRndOf c') t R hR_inc).2)
    (fun x' hx' c' k hk t R hR_blk => by
      have hblk := shdP_honestRunWitness_blkTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x' hx' c' k hk
      rw [hblk] at hR_blk
      rw [shdP_honestRunWitness_TB (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x' hx' c' (k + 1) (by omega)]
      exact shdP_blk_outClaims_true_uncond (liftH G) tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x' hx' k hk)
        (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c') (blkRndOf c') x' hx' ⟨k, Nat.lt_succ_of_lt hk⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c') (blkRndOf c') x' hx' ⟨k + 1, Nat.succ_lt_succ hk⟩)
        (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c') (blkRndOf c') x' hx' ⟨k + 1, Nat.succ_lt_succ hk⟩).rows_len
        (blkRndOf c' ⟨k, hk⟩) t R hR_blk)
    x hx c herr

/-- **Top-level `ProductionReadyL` theorem for `shdP_honestRunP_zk` with concrete verifier hooks
(`shdPreA`, `shdPreB`, `shdCheck0`, `shdDigest`, `ShieldRunReg`)**: discharges all completeness,
soundness, binding, refusal-cover, and hook obligations; takes ONLY `W_zk : ShdZKProgWitness` on
`shdP_honestRunP_zk` (closed in `HonestShieldZKProgInst.lean`). -/
theorem shdP_honest_productionReadyL_hooks_zk {Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig)
    (policy : ShdPolicy) (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) (hfloor : policy.minWholeRunBits ≤ wholeRunBits)
    (Rp : ClassifyRunPublicP shieldS0) (hReg : ShieldRunReg Rp)
    (refused : ClsStmt (ShdHdr Lq))
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (W_zk : ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain w.shape
      (shdP_runV tag key shdP_runDomain shdHdrW (shdPreA policy reg) (shdPreB regBlkDig) Rp
        reg.embDigest (embFoldL Rp.inp) 32 reg.wDigest 34
        (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp)
        (shdCheck0 regBlkDig) shdP_segPaths shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl))
      (shdP_honestRunP_zk tag Rp hReg.1 hweights hinPub houtPub
        (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
        (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
        (shdCheck0 regBlkDig) shdDigest
        epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin (ShdHdr Lq) tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := ShdHdr Lq) tag epBase).base) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 (shdPreA policy reg) (shdPreB regBlkDig)
        (clsStart shdP_runDomain key shdHdrW)
        (fun _ => shdP_incV tag Rp reg.embDigest (embFoldL Rp.inp) 32)
        (fun _ => rcIncGeom (shdP_incV tag Rp reg.embDigest (embFoldL Rp.inp) 32) 28)
        (d12aBlockProf (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom (ShdHdr Lq) (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp))
          (vdChk (shdCheck0 regBlkDig)) shdP_segPaths shdDigest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl _ => shdP_bndCheckPure cl) (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp reg.wDigest 34 v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp reg.wDigest 34 0) 28)
        (shdP_honestRunP_zk tag Rp hReg.1 hweights hinPub houtPub
          (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
          (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
          (shdCheck0 regBlkDig) shdDigest
          epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin (ShdHdr Lq) tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := ShdHdr Lq) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  shdP_openShell_res tag Lq hL20 hL64 key Rp hReg.1 shdHdrW (fun hd => hd.wFit)
    (shdPreA policy reg) (shdPreB regBlkDig) (shdCheck0 regBlkDig) shdP_segPaths shdDigest
    (fun _ _ cl _ => shdP_bndCheckPure cl) 34 32 (checkField shdP_blkOpenGeom)
    reg.embDigest 32 reg.wDigest 34
    (shdP_honestRunP_zk tag Rp hReg.1 hweights hinPub houtPub
      (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
      (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
      (shdCheck0 regBlkDig) shdDigest epBase incRndOf blkRndOf outcRndOf)
    epBase
    (shdP_runSite tag Lq hL20 key Rp hReg.1 hReg.2 shdHdrW (shdHonestHdr reg regBlkDig w hwFit wholeRunBits)
      34 32 (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 (shdBlkDigFn regBlkDig) epBase
      (shdP_honestRunWitness (Hdr := ShdHdr Lq) tag Rp hReg.1 hweights hinPub houtPub 34 32
        (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 epBase incRndOf blkRndOf outcRndOf))
    hReg.2 hweights hinPub houtPub
    ⟨shdPreA_honest policy reg regBlkDig w hwFit wholeRunBits hfloor,
     shdPreB_honest reg regBlkDig w hwFit wholeRunBits⟩
    (shdP_honestRunP_zk_hsegIn tag Lq hL20 key Rp hReg.1 shdHdrW (shdPreA policy reg) (shdPreB regBlkDig)
      (shdCheck0 regBlkDig) shdP_segPaths shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl) 34 32
      (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
      (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused hReg.2 hweights hinPub houtPub
      epBase incRndOf blkRndOf outcRndOf)
    (shdP_honestRunP_zk_hsegBlk tag Lq hL20 key Rp hReg.1 shdHdrW (shdPreA policy reg) (shdPreB regBlkDig)
      (shdCheck0 regBlkDig) shdDigest 34 32 (checkField shdP_blkOpenGeom)
      reg.embDigest 32 reg.wDigest 34 (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused
      hweights hinPub houtPub epBase incRndOf blkRndOf outcRndOf
      (fun k hk _ _ _ _ => shdCheck0_honest reg regBlkDig w hwFit wholeRunBits _ _ k hk)
      shdP_blk_hgrpA_of_checkOpeningExec shdP_blk_hgrpH_of_checkOpeningExec)
    (shdP_honestRunP_zk_hsegOut tag Lq hL20 key Rp hReg.1 shdHdrW (shdPreA policy reg) (shdPreB regBlkDig)
      (shdCheck0 regBlkDig) shdP_segPaths shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl) 34 32
      (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
      (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused hweights hinPub houtPub
      epBase incRndOf blkRndOf outcRndOf)
    (shdP_refuse_hk tag Lq hL20 key Rp hReg.1 hReg.2 shdHdrW (shdHonestHdr reg regBlkDig w hwFit wholeRunBits)
      34 32 (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 (shdBlkDigFn regBlkDig) epBase
      (shdP_honestRunWitness (Hdr := ShdHdr Lq) tag Rp hReg.1 hweights hinPub houtPub 34 32
        (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 epBase incRndOf blkRndOf outcRndOf))
    (shdP_refuse_hδ tag Lq hL20 key Rp hReg.1 hReg.2 shdHdrW (shdHonestHdr reg regBlkDig w hwFit wholeRunBits)
      34 32 (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 (shdBlkDigFn regBlkDig) epBase
      (shdP_honestRunWitness (Hdr := ShdHdr Lq) tag Rp hReg.1 hweights hinPub houtPub 34 32
        (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34 epBase incRndOf blkRndOf outcRndOf))
    (shdP_honestRunP_zk_hcover tag Lq hL20 key Rp hReg.1 hReg.2 hweights hinPub houtPub shdHdrW
      (shdPreA policy reg) (shdPreB regBlkDig) (shdCheck0 regBlkDig) shdP_segPaths shdDigest
      (fun _ _ cl _ => shdP_bndCheckPure cl) 34 32 (checkField shdP_blkOpenGeom)
      reg.embDigest 32 reg.wDigest 34 (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩)
      (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused (shdBlkDigFn regBlkDig)
      (shdDigest_honest reg regBlkDig w hwFit wholeRunBits) epBase incRndOf blkRndOf outcRndOf
      (fun _ _ _ e h => ⟨e, h⟩) (fun _ _ _ e h => ⟨e, h⟩))
    (shdP_O_zk_ideal Rp Lq hL20 tag key shdP_runDomain w.shape _ _ _ _ _ _ W_zk)

end L69_1Closure

/-! ## 2. Safe Fixed-1-Point Absorb (`fitBytes`, `trAbsorbFixed`) & Merkle `.res` Independence -/

section FixedPrimitives

theorem absorbMsg_length_eq (st : Dig) (label data : List UInt8) :
    (absorbMsg st label data).length = 48 + label.length + data.length := by
  simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]; omega

/-- Clamps `data` to `[]` if `48 + label.length + data.length > Lq`, guaranteeing that
`trAbsorbFixed` ALWAYS emits exactly one `.pt` query (`PtLen 1`) without requiring callers to thread
length proofs inside nested `PProg` closures; equals `data` verbatim whenever it fits `Lq`. -/
def fitBytes (Lq : ℕ) (label data : List UInt8) : List UInt8 :=
  if 48 + label.length + data.length ≤ Lq then data else []

theorem fitBytes_fit (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (st : Dig) (label data : List UInt8)
    (hlab : label.length ≤ 64) :
    (absorbMsg st label (fitBytes Lq label data)).length ≤ Lq := by
  rw [absorbMsg_length_eq]
  unfold fitBytes
  by_cases h : 48 + label.length + data.length ≤ Lq
  · rw [ite_eq_left h]; exact h
  · rw [ite_eq_right h, List.length_nil]; omega

theorem fitBytes_eq (Lq : ℕ) (label data : List UInt8)
    (h : 48 + label.length + data.length ≤ Lq) :
    fitBytes Lq label data = data := by
  unfold fitBytes; exact ite_eq_left h

/-- Fixed-1-point keyed transcript absorb (`PtLen 1`, `QLE 1`, `DepStrict`, `KCount 1 0 0` unconditionally
for ANY `t : Tr`) for any label of length `≤ 64` and any `data`. Matches `t.absorb (liftH G) label data`
verbatim whenever `t.key = key` and `48 + label.length + data.length ≤ Lq`. -/
def trAbsorbKeyed (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr) (label : List UInt8)
    (hlab : label.length ≤ 64) (data : List UInt8) : PProg (QB Lq) Dig Tr :=
  .pt (key, ⟨absorbMsg t.state label (fitBytes Lq label data), fitBytes_fit Lq hL20 t.state label data hlab⟩)
    fun dg => .ret { t with state := dg, key := key }

theorem trAbsorbKeyed_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (label : List UInt8) (hlab : label.length ≤ 64) (data : List UInt8)
    (hfit : 48 + label.length + data.length ≤ Lq) (G : QB Lq → Dig) :
    (trAbsorbKeyed Lq hL20 key t label hlab data).run G = t.absorb (liftH G) label data := by
  unfold trAbsorbKeyed Tr.absorb liftH
  dsimp only [PProg.run]
  have hfit' : (absorbMsg t.state label data).length ≤ Lq := by rw [absorbMsg_length_eq]; exact hfit
  rw [dite_eq_left hfit']
  rcases t with ⟨st, ctr, k⟩
  dsimp only at htKey ⊢
  subst htKey
  congr 1
  congr 1
  refine Prod.ext rfl (Subtype.ext ?_)
  change absorbMsg st label (fitBytes Lq label data) = absorbMsg st label data
  rw [fitBytes_eq Lq label data hfit]

theorem trAbsorbKeyed_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (data : List UInt8) :
    (trAbsorbKeyed Lq hL20 key t label hlab data).PtLen 1 :=
  ⟨0, rfl, fun _ => rfl⟩

theorem trAbsorbKeyed_purePt (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (data : List UInt8) :
    PurePt (trAbsorbKeyed Lq hL20 key t label hlab data) 1 :=
  PurePt.pt _ _ (fun _ => PurePt.ret _)

theorem trAbsorbKeyed_ptAt (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (data : List UInt8)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trAbsorbKeyed Lq hL20 key t label hlab data).ptAt H v i i
      = some (key, ⟨absorbMsg t.state label (fitBytes Lq label data),
          fitBytes_fit Lq hL20 t.state label data hlab⟩) := by
  simp [trAbsorbKeyed, PProg.ptAt]

theorem trAbsorbKeyed_res (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (data : List UInt8)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trAbsorbKeyed Lq hL20 key t label hlab data).res H v i = { t with state := v i, key := key } := rfl

theorem trAbsorbKeyed_kCount (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (t : Tr) (label : List UInt8)
    (hlab : label.length ≤ 64) (data : List UInt8) :
    (trAbsorbKeyed Lq hL20 key t label hlab data).KCount tag key 1 0 0 := by
  unfold trAbsorbKeyed PProg.KCount
  rw [shdQKind_key hsep _ (fitBytes_fit Lq hL20 t.state label data hlab)]
  exact ⟨Nat.zero_lt_one, fun _ => trivial⟩

/-- Fixed-1-point keyed `Fp2`-vector absorb (`trAbsorbKeyed` on `vals.flatMap Fp2.toBytes`). -/
def trAbsorbFp2Keyed (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr) (label : List UInt8)
    (hlab : label.length ≤ 64) (vals : List Fp2) : PProg (QB Lq) Dig Tr :=
  trAbsorbKeyed Lq hL20 key t label hlab (vals.flatMap Fp2.toBytes)

theorem trAbsorbFp2Keyed_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (label : List UInt8) (hlab : label.length ≤ 64) (vals : List Fp2)
    (hfit : 48 + label.length + vals.length * 16 ≤ Lq) (G : QB Lq → Dig) :
    (trAbsorbFp2Keyed Lq hL20 key t label hlab vals).run G = t.absorbFp2 (liftH G) label vals := by
  unfold trAbsorbFp2Keyed Tr.absorbFp2
  refine trAbsorbKeyed_run Lq hL20 key t htKey label hlab _ ?_ G
  have hlen : (vals.flatMap Fp2.toBytes).length = vals.length * 16 := encFp2s_length vals
  omega

theorem trAbsorbFp2Keyed_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (vals : List Fp2) :
    (trAbsorbFp2Keyed Lq hL20 key t label hlab vals).PtLen 1 :=
  trAbsorbKeyed_ptLen Lq hL20 key t label hlab _

theorem trAbsorbFp2Keyed_res (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (vals : List Fp2)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trAbsorbFp2Keyed Lq hL20 key t label hlab vals).res H v i = { t with state := v i, key := key } := rfl

/-- Fixed-1-point keyed transcript squeeze (`KCount 1 0 0` unconditionally for ANY `t : Tr`). -/
def trSqueezeKeyed (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) : PProg (QB Lq) Dig (Dig × Tr) :=
  .pt (key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact h47⟩)
    fun dg => .ret (dg, { t with state := dg, counter := t.counter + 1, key := key })

theorem trSqueezeKeyed_run (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig) :
    (trSqueezeKeyed Lq h47 key t).run G = t.squeeze (liftH G) := by
  unfold trSqueezeKeyed Tr.squeeze liftH
  dsimp only [PProg.run]
  have hlen : (squeezeMsg t.state t.counter).length ≤ Lq := by rw [squeezeMsg_length]; exact h47
  rw [dite_eq_left hlen]
  rcases t with ⟨st, ctr, k⟩
  dsimp only at htKey ⊢
  subst htKey
  rfl

theorem trSqueezeKeyed_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) :
    (trSqueezeKeyed Lq h47 key t).PtLen 1 := ⟨0, rfl, fun _ => rfl⟩

private theorem tr_absorb_key (H : HIn → Dig) (t : Tr) (label data : List UInt8) :
    (t.absorb H label data).key = t.key := rfl

private theorem tr_absorbFp2_key (H : HIn → Dig) (t : Tr) (label : List UInt8) (vals : List Fp2) :
    (t.absorbFp2 H label vals).key = t.key := rfl

private theorem tr_challengeFp2_key (H : HIn → Dig) (t : Tr) :
    (t.challengeFp2 H).2.key = t.key := rfl

private theorem tr_challengeFp2Vec_key (H : HIn → Dig) :
    ∀ (n : ℕ) (t : Tr), (t.challengeFp2Vec H n).2.key = t.key
  | 0, _ => rfl
  | n + 1, t => (tr_challengeFp2Vec_key H n (t.challengeFp2 H).2).trans (tr_challengeFp2_key H t)

private theorem tr_foldl_absorbFp2_key (H : HIn → Dig) (label : List UInt8) :
    ∀ (vecs : List (List Fp2)) (t : Tr), (vecs.foldl (fun acc v => acc.absorbFp2 H label v) t).key = t.key
  | [], _ => rfl
  | _ :: rest, t => (tr_foldl_absorbFp2_key H label rest _).trans (tr_absorbFp2_key H t label _)

private theorem scProve_key (H : HIn → Dig) :
    ∀ (n : ℕ) (p : WProver n) (t : Tr), (scProve H n p t).2.key = t.key
  | 0, _, _ => rfl
  | n + 1, p, t => by
    dsimp only [scProve]
    exact (scProve_key H n _ _).trans ((tr_challengeFp2_key H _).trans (tr_absorbFp2_key H t scLabel p.1))

private theorem chalVec_add_fixed (H : HIn → Dig) :
    ∀ (a b : ℕ) (t : Tr),
      t.challengeFp2Vec H (a + b) =
        ((t.challengeFp2Vec H a).1 ++ ((t.challengeFp2Vec H a).2.challengeFp2Vec H b).1,
         ((t.challengeFp2Vec H a).2.challengeFp2Vec H b).2)
  | 0, _, _ => by rw [Nat.zero_add]; rfl
  | a + 1, b, t => by
    rw [Nat.succ_add]
    change ((t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H (a + b)).1,
            ((t.challengeFp2 H).2.challengeFp2Vec H (a + b)).2) = _
    rw [chalVec_add_fixed H a b (t.challengeFp2 H).2]
    rfl

theorem trSqueezeKeyed_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) :
    PurePt (trSqueezeKeyed Lq h47 key t) 1 := PurePt.pt _ _ (fun _ => PurePt.ret _)

theorem trSqueezeKeyed_ptAt (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trSqueezeKeyed Lq h47 key t).ptAt H v i i
      = some (key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact h47⟩) := by
  simp [trSqueezeKeyed, PProg.ptAt]

theorem trSqueezeKeyed_kCount (Lq : ℕ) (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (t : Tr) :
    (trSqueezeKeyed Lq h47 key t).KCount tag key 1 0 0 := by
  unfold trSqueezeKeyed PProg.KCount
  rw [shdQKind_key hsep _ (by rw [squeezeMsg_length]; exact h47)]
  exact ⟨Nat.zero_lt_one, fun _ => trivial⟩

/-- Keyed `Fp2` challenge draw (`1` `.squeeze`, unconditional `KCount 1 0 0`). -/
def trChallengeFp2Keyed (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) : PProg (QB Lq) Dig (Fp2 × Tr) :=
  (trSqueezeKeyed Lq h47 key t).andThen fun r => .ret (challengeFp2Of r.1, r.2)

theorem trChallengeFp2Keyed_run (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig) :
    (trChallengeFp2Keyed Lq h47 key t).run G = t.challengeFp2 (liftH G) := by
  unfold trChallengeFp2Keyed Tr.challengeFp2
  rw [PProg.run_andThen, trSqueezeKeyed_run Lq h47 key t htKey G]; rfl

/-- Keyed `n`-element `Dig` squeeze vector (`n` `.squeeze`s, unconditional `KCount n 0 0`). -/
def trSqueezeVecKeyed (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) : ℕ → Tr → PProg (QB Lq) Dig (List Dig × Tr)
  | 0, t => .ret ([], t)
  | n + 1, t =>
    (trSqueezeKeyed Lq h47 key t).andThen fun r =>
      (trSqueezeVecKeyed Lq h47 key n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2)

theorem trSqueezeVecKeyed_run (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr), t.key = key →
      (trSqueezeVecKeyed Lq h47 key n t).run G = (sqDs (liftH G) t n, runOps (liftH G) t (List.replicate n Op.squeeze))
  | 0, _, _ => rfl
  | n + 1, t, htKey => by
    unfold trSqueezeVecKeyed
    rw [PProg.run_andThen, trSqueezeKeyed_run Lq h47 key t htKey G, PProg.run_andThen]
    have hkey' : (t.squeeze (liftH G)).2.key = key := htKey
    rw [trSqueezeVecKeyed_run Lq h47 key G n _ hkey', sqDs_succ, List.replicate_succ, runOps]; rfl

/-- Keyed `n`-element `Fp2` challenge vector (`n` `.squeeze`s, unconditional `KCount n 0 0`). -/
def trChallengeFp2VecKeyed (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) : ℕ → Tr → PProg (QB Lq) Dig (List Fp2 × Tr)
  | 0, t => .ret ([], t)
  | n + 1, t =>
    (trChallengeFp2Keyed Lq h47 key t).andThen fun r =>
      (trChallengeFp2VecKeyed Lq h47 key n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2)

theorem trChallengeFp2VecKeyed_run (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr), t.key = key →
      (trChallengeFp2VecKeyed Lq h47 key n t).run G = t.challengeFp2Vec (liftH G) n
  | 0, _, _ => rfl
  | n + 1, t, htKey => by
    unfold trChallengeFp2VecKeyed
    rw [PProg.run_andThen, trChallengeFp2Keyed_run Lq h47 key t htKey G, PProg.run_andThen]
    have hkey' : (t.challengeFp2 (liftH G)).2.key = key := htKey
    rw [trChallengeFp2VecKeyed_run Lq h47 key G n _ hkey']; rfl

/-- Keyed `Exec.Block.posTag` (`2` `.squeeze`s, unconditional `KCount 2 0 0`). -/
def posTagKeyed (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) : PProg (QB Lq) Dig Dig :=
  (trChallengeFp2Keyed Lq h47 key t).andThen fun a =>
    (trChallengeFp2Keyed Lq h47 key a.2).andThen fun b =>
      .ret ⟨a.1.toBytes ++ b.1.toBytes, by simp [Exec.Block.fp2_toBytes_length]⟩

theorem posTagKeyed_run (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig) :
    (posTagKeyed Lq h47 key t).run G = Exec.Block.posTag (liftH G) t := by
  unfold posTagKeyed Exec.Block.posTag
  rw [PProg.run_andThen, trChallengeFp2Keyed_run Lq h47 key t htKey G, PProg.run_andThen]
  dsimp only [PProg.run]
  apply Subtype.ext
  have ht2 : (Tr.challengeFp2 (liftH G) t).2.key = key := htKey
  rw [trChallengeFp2Keyed_run Lq h47 key (Tr.challengeFp2 (liftH G) t).2 ht2 G]

/-- Pure value-driven `MerkleLevels` built directly from `v` starting at `base` (zero dependence on
oracle `H`, columns `colOf`, or leaf salts `saltOf`). -/
def levelsOfV (v : ℕ → Dig) : (d : ℕ) → ℕ → MerkleLevels d
  | 0, base => .root (v base)
  | d + 1, base => .layer (fun j => v (base + j.val)) (levelsOfV v d (base + 2 ^ (d + 1)))

theorem levelsOfV_getRoot (v : ℕ → Dig) :
    ∀ (d base : ℕ), (levelsOfV v d base).getRoot = v (base + 2 ^ d + (2 ^ d - 1) - 1)
  | 0, base => by simp [levelsOfV, MerkleLevels.getRoot]
  | d + 1, base => by
    simp only [levelsOfV, MerkleLevels.getRoot]
    rw [levelsOfV_getRoot v d (base + 2 ^ (d + 1))]
    have h1 : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    congr 1; omega

theorem buildLevelsProg_res_eq (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (d base : ℕ),
      (buildLevelsProg Lq h64 tag d (fun j : Fin (2 ^ d) => v (base + j.val))).res H v (base + 2 ^ d)
        = levelsOfV v d base
  | 0, base => by simp [buildLevelsProg, levelsOfV, PProg.res]
  | d + 1, base => by
    unfold buildLevelsProg
    let lo : Fin (2 ^ d) → Dig := fun i => v (base + 2 * i.val)
    let hi : Fin (2 ^ d) → Dig := fun i => v (base + (2 * i.val + 1))
    rw [PProg.res_andThen H v _ _ (2 ^ d) (base + 2 ^ (d + 1)) (nodeLayerAux_ptLen Lq h64 tag (2 ^ d) lo hi)]
    have hres : (nodeLayerAux Lq h64 tag (2 ^ d) lo hi).res H v (base + 2 ^ (d + 1))
        = (fun i : Fin (2 ^ d) => v ((base + 2 ^ (d + 1)) + i.val)) := by
      funext i; exact nodeLayerAux_res Lq h64 tag H v (2 ^ d) lo hi (base + 2 ^ (d + 1)) i
    rw [hres, PProg.res_andThen H v _ _ (2 ^ d - 1) (base + 2 ^ (d + 1) + 2 ^ d) (buildLevelsProg_ptLen Lq h64 tag d _)]
    simp only [PProg.res, levelsOfV]
    congr 1
    exact buildLevelsProg_res_eq Lq h64 tag H v d (base + 2 ^ (d + 1))

/-- **`merkleTreeProg.res` depends ONLY on `v` and `base`** (completely independent of `colOf`,
`saltOf`, and `H`), immediately proving that unopened leaf salts never affect any `MerkleLevels` or
root inside `PProg.outOf`! -/
theorem merkleTreeProg_res_eq (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).res H v base = levelsOfV v d base := by
  unfold merkleTreeProg
  rw [PProg.res_andThen H v _ _ (2 ^ d) base (leafLayerAux_ptLen Lq h64 tag (2 ^ d) colOf hcol saltOf)]
  have hres : (leafLayerAux Lq h64 tag (2 ^ d) colOf hcol saltOf).res H v base
      = (fun j : Fin (2 ^ d) => v (base + j.val)) := by
    funext j; exact leafLayerAux_res Lq h64 tag H v (2 ^ d) colOf hcol saltOf base j
  rw [hres]
  exact buildLevelsProg_res_eq Lq h64 tag H v d base

theorem merkleTreeProg_res_getRoot (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    ((merkleTreeProg Lq h64 tag d colOf hcol saltOf).res H v base).getRoot
      = v (base + 2 ^ d + (2 ^ d - 1) - 1) := by
  rw [merkleTreeProg_res_eq, levelsOfV_getRoot]

end FixedPrimitives

/-! ## 3. Compositional Fixed-Schedule Engine (`TrChainState`, `RawPtSpec`, `SliceSpec`) -/

section SliceEngine

/-- Static transcript-chain state at point index `base`:
- `hasTip`: whether any `.tr` point has been emitted `< base` (`false` before header `abLabExp`),
- `trTip`: index of the main transcript's current `.state = v trTip` (`< base` when `hasTip = true`),
- `afterPosTag`: `true` immediately after a 2-squeeze `posTag` (so `.tr` points in `(trTip, base)` are
  all `.squeeze`, allowing the next `.absorb` at `base` to read `v trTip` while preserving `htr_order`). -/
structure TrChainState (base : ℕ) where
  hasTip : Bool
  trTip : ℕ
  htip_lt : hasTip = true → trTip < base
  afterPosTag : Bool
  hpos : afterPosTag = true → hasTip = true

def TrChainState.cast {n m : ℕ} (h : n = m) (st : TrChainState n) : TrChainState m :=
  ⟨st.hasTip, st.trTip, fun ht => h ▸ st.htip_lt ht, st.afterPosTag, st.hpos⟩

theorem TrChainState.ext {n : ℕ} {a b : TrChainState n}
    (h1 : a.hasTip = b.hasTip) (h2 : a.trTip = b.trTip) (h3 : a.afterPosTag = b.afterPosTag) : a = b := by
  cases a; cases b; cases h1; cases h2; cases h3; rfl

theorem trChainState_heq {n m : ℕ} (h : n = m) {a : TrChainState n} {b : TrChainState m}
    (h1 : a.hasTip = b.hasTip) (h2 : a.trTip = b.trTip) (h3 : a.afterPosTag = b.afterPosTag) :
    a.cast h = b :=
  TrChainState.ext h1 h2 h3

/-- Monotonicity invariant linking `st₁` at `b₁` to `st₂` at `b₂` (`b₁ ≤ b₂`). -/
def TrChainStep {b₁ b₂ : ℕ} (st₁ : TrChainState b₁) (st₂ : TrChainState b₂) : Prop :=
  st₁.hasTip = true →
    st₂.hasTip = true ∧ st₁.trTip ≤ st₂.trTip ∧
      (st₁.afterPosTag = true → b₁ ≤ st₂.trTip ∨ (st₂.afterPosTag = true ∧ st₁.trTip = st₂.trTip))

theorem trChainStep_refl {b : ℕ} (st : TrChainState b) : TrChainStep st st :=
  fun h => ⟨h, le_rfl, fun hp => Or.inr ⟨hp, rfl⟩⟩

theorem trChainStep_trans {b₁ b₂ b₃ : ℕ} (hb : b₁ ≤ b₂)
    {st₁ : TrChainState b₁} {st₂ : TrChainState b₂} {st₃ : TrChainState b₃}
    (h12 : TrChainStep st₁ st₂) (h23 : TrChainStep st₂ st₃) : TrChainStep st₁ st₃ := by
  intro ht1
  obtain ⟨ht2, hle12, hp12⟩ := h12 ht1
  obtain ⟨ht3, hle23, hp23⟩ := h23 ht2
  refine ⟨ht3, le_trans hle12 hle23, fun hp1 => ?_⟩
  rcases hp12 hp1 with hge | ⟨hp2, heq12⟩
  · exact Or.inl (le_trans hge hle23)
  · rcases hp23 hp2 with hge2 | ⟨hp3, heq23⟩
    · exact Or.inl (le_trans hb hge2)
    · exact Or.inr ⟨hp3, heq12.trans heq23⟩

/-- Index-free static point descriptor used inside compositional slices before lifting to `Fin shdP_zkResPts`. -/
inductive RawPtSpec where
  | leaf (id : ShdLeafId)
  | node (L R : ℕ)
  | squeeze (m : ℕ)
  | absorb (m : ℕ)
  | absorbExp (m : ℕ)

def RawPtSpec.kind : RawPtSpec → ShdQKind
  | .leaf _ => .leaf
  | .node _ _ => .node
  | .squeeze _ => .tr
  | .absorb _ => .tr
  | .absorbExp _ => .tr

def RawPtSpec.isTr : RawPtSpec → Bool
  | .squeeze _ => true
  | .absorb _ => true
  | .absorbExp _ => true
  | _ => false

def RawPtSpec.isSqueeze : RawPtSpec → Bool
  | .squeeze _ => true
  | _ => false

def RawPtSpec.isAbsorb : RawPtSpec → Bool
  | .absorb _ => true
  | .absorbExp _ => true
  | _ => false

def RawPtSpec.trM : RawPtSpec → ℕ
  | .squeeze m => m
  | .absorb m => m
  | .absorbExp m => m
  | _ => 0

def RawPtSpec.trKind : RawPtSpec → ShdTrKind
  | .squeeze _ => .squeeze
  | .absorb _ => .absorb
  | .absorbExp _ => .absorb
  | _ => .pad

/-- Pointwise match of a single `PProg` point query `q` against `RawPtSpec` at `(tag, key, domain, shape, c, v)`. -/
def RawPtMatch (Lq : ℕ) (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (c : ShdCoins) (v : ℕ → Dig) (q : QB Lq) : RawPtSpec → Prop
  | .leaf id =>
      ∃ (cd : Dig) (hl : (cd.toList ++ (shdLeafSalt c id).toList).length ≤ Lq),
        q = (tag.leaf, ⟨cd.toList ++ (shdLeafSalt c id).toList, hl⟩)
  | .node L R =>
      ∃ (hn : ((v L).toList ++ (v R).toList).length ≤ Lq),
        q = (tag.node, ⟨(v L).toList ++ (v R).toList, hn⟩)
  | .squeeze m =>
      ∃ (ctr : UInt64) (hs : (squeezeMsg (v m) ctr).length ≤ Lq),
        q = (key, ⟨squeezeMsg (v m) ctr, hs⟩)
  | .absorb m =>
      ∃ (label data : List UInt8) (ha : (absorbMsg (v m) label data).length ≤ Lq),
        label ≠ abLabShape ∧ label.length < 2 ^ 64 ∧ q = (key, ⟨absorbMsg (v m) label data, ha⟩)
  | .absorbExp m =>
      ∃ (st : Dig) (label data : List UInt8) (ha : (absorbMsg st label data).length ≤ Lq),
        label ≠ abLabShape ∧ label.length < 2 ^ 64
        ∧ q = (key, ⟨absorbMsg st label data, ha⟩)
        ∧ qLastDig q = v m
        ∧ q ∉ ShdRunDepSet Lq tag key domain shape

/-- **Compositional Hoare-triple schedule contract (`SliceSpec`)** for a `PProg` `p` occupying point
indices `[base, base + len)` with static schedule `sched : ℕ → RawPtSpec`. -/
structure SliceSpec {α : Type} (Lq : ℕ) (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (c : ShdCoins) (p : PProg (QB Lq) Dig α)
    (base len nQ nTrK nT nL nN : ℕ)
    (stIn : TrChainState base) (stOut : TrChainState (base + len))
    (trees : ShdTreeId → Prop) (sched : ℕ → RawPtSpec)
    (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop)
    (post : (QB Lq → Dig) → (ℕ → Dig) → α → Prop) : Prop where
  hptLen : p.PtLen len
  hqLE : p.QLE nQ
  hdepStrict : DepStrict p
  hdepIn : p.DepIn (ShdRunDepSet Lq tag key domain shape)
  hkCount : p.KCount tag key nTrK nL nN
  hstep : TrChainStep stIn stOut
  hcntT : ((Finset.range len).filter (fun k => (sched (base + k)).kind = .tr)).card ≤ nT
  hcntL : ((Finset.range len).filter (fun k => (sched (base + k)).kind = .leaf)).card ≤ nL
  hcntN : ((Finset.range len).filter (fun k => (sched (base + k)).kind = .node)).card ≤ nN
  hleaf_tree : ∀ j id, base ≤ j → j < base + len → sched j = .leaf id → trees id.1
  hleaf_inj : ∀ i j id₁ id₂, base ≤ i → i < base + len → base ≤ j → j < base + len →
    sched i = .leaf id₁ → sched j = .leaf id₂ → i ≠ j → id₁ ≠ id₂
  hnode_bounds : ∀ j L R, base ≤ j → j < base + len → sched j = .node L R →
    base ≤ L ∧ L < R ∧ R < j
  hnode_inj : ∀ i j L₁ R₁ L₂ R₂, base ≤ i → i < base + len → base ≤ j → j < base + len →
    sched i = .node L₁ R₁ → sched j = .node L₂ R₂ → i ≠ j → L₁ ≠ L₂
  htr_lt : ∀ j, base ≤ j → j < base + len → (sched j).isTr = true → (sched j).trM < j
  htr_entry : ∀ j, base ≤ j → j < base + len → (sched j).isTr = true →
    stIn.hasTip = true →
    if stIn.afterPosTag = false then stIn.trTip ≤ (sched j).trM
    else (stIn.trTip ≤ (sched j).trM ∧ (sched j).isAbsorb = true) ∨ base ≤ (sched j).trM
  htr_exit : ∀ i, base ≤ i → i < base + len → (sched i).isTr = true →
    stOut.hasTip = true ∧
    (if stOut.afterPosTag = false then i ≤ stOut.trTip
     else i ≤ stOut.trTip ∨ (sched i).isSqueeze = true)
  htr_internal : ∀ i j, base ≤ i → i < j → j < base + len →
    (sched i).isTr = true → (sched j).isTr = true →
    i ≤ (sched j).trM ∨ ((sched i).isSqueeze = true ∧ (sched j).isAbsorb = true)
  hpt_match : ∀ H v j, pre H v → base ≤ j → j < base + len →
    ∃ q, p.ptAt H v base j = some q ∧ RawPtMatch Lq tag key domain shape c v q (sched j)
  hpost : ∀ H v, pre H v → post H v (p.res H v base)

private theorem card_filter_range_add (a b : ℕ) (P : ℕ → Prop) [DecidablePred P] :
    ((Finset.range (a + b)).filter P).card
      = ((Finset.range a).filter P).card + ((Finset.range b).filter (fun k => P (a + k))).card := by
  have hsplit : Finset.range (a + b) = Finset.range a ∪ (Finset.range b).image (a + ·) := by
    ext x
    simp only [Finset.mem_range, Finset.mem_union, Finset.mem_image]
    constructor
    · intro hx
      by_cases hxa : x < a
      · exact Or.inl hxa
      · exact Or.inr ⟨x - a, by omega, by omega⟩
    · rintro (h | ⟨k, hk, rfl⟩) <;> omega
  have hdisj : Disjoint ((Finset.range a).filter P) (((Finset.range b).image (a + ·)).filter P) := by
    rw [Finset.disjoint_left]
    intro x hx1 hx2
    have h1 : x < a := Finset.mem_range.mp (Finset.mem_filter.mp hx1).1
    obtain ⟨k, _, rfl⟩ := Finset.mem_image.mp (Finset.mem_filter.mp hx2).1
    omega
  rw [hsplit, Finset.filter_union, Finset.card_union_of_disjoint hdisj]
  congr 1
  have himg : ((Finset.range b).image (a + ·)).filter P = ((Finset.range b).filter (fun k => P (a + k))).image (a + ·) := by
    ext x
    simp only [Finset.mem_filter, Finset.mem_image]
    constructor
    · rintro ⟨⟨k, hk, rfl⟩, hP⟩; exact ⟨k, ⟨hk, hP⟩, rfl⟩
    · rintro ⟨k, ⟨hk, hP⟩, rfl⟩; exact ⟨⟨k, hk, rfl⟩, hP⟩
  rw [himg, Finset.card_image_of_injective _ (fun _ _ h => by omega)]

/-- Splice two schedules across the boundary `mid`. -/
def spliceSched (mid : ℕ) (s₁ s₂ : ℕ → RawPtSpec) (j : ℕ) : RawPtSpec :=
  if j < mid then s₁ j else s₂ j

/-- **Compositional `andThen` theorem for `SliceSpec`**: chains two slices `(base, len₁)` and
`(base + len₁, len₂)`, composing EVERY budget, transcript-order, leaf-injectivity, node-injectivity,
and Hoare postcondition obligation in O(1)! -/
theorem SliceSpec.andThen {α β : Type} {Lq : ℕ} {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {c : ShdCoins} {p : PProg (QB Lq) Dig α} {f : α → PProg (QB Lq) Dig β}
    {base len₁ len₂ nQ₁ nQ₂ nTrK₁ nTrK₂ nT₁ nT₂ nL₁ nL₂ nN₁ nN₂ : ℕ}
    {st₀ : TrChainState base} {st₁ : TrChainState (base + len₁)} {st₂ : TrChainState (base + len₁ + len₂)}
    {trees₁ trees₂ : ShdTreeId → Prop} {sched₁ sched₂ : ℕ → RawPtSpec}
    {pre : (QB Lq → Dig) → (ℕ → Dig) → Prop}
    {mid : (QB Lq → Dig) → (ℕ → Dig) → α → Prop}
    {post : (QB Lq → Dig) → (ℕ → Dig) → β → Prop}
    (h1 : SliceSpec Lq tag key domain shape c p base len₁ nQ₁ nTrK₁ nT₁ nL₁ nN₁ st₀ st₁ trees₁ sched₁ pre mid)
    (h2 : ∀ a, SliceSpec Lq tag key domain shape c (f a) (base + len₁) len₂ nQ₂ nTrK₂ nT₂ nL₂ nN₂ st₁ st₂ trees₂ sched₂
      (fun H v => mid H v a) post)
    (hdisj : ∀ t, trees₁ t → ¬ trees₂ t) :
    SliceSpec Lq tag key domain shape c (p.andThen f) base (len₁ + len₂)
      (nQ₁ + nQ₂) (nTrK₁ + nTrK₂) (nT₁ + nT₂) (nL₁ + nL₂) (nN₁ + nN₂)
      st₀ (st₂.cast (Nat.add_assoc base len₁ len₂))
      (fun t => trees₁ t ∨ trees₂ t) (spliceSched (base + len₁) sched₁ sched₂) pre post := by
  let a₀ : α := p.res (fun _ => zeroDig) (fun _ => zeroDig) base
  have h2₀ := h2 a₀
  have hcnt : ∀ (kd : ShdQKind) (m₁ m₂ : ℕ),
      ((Finset.range len₁).filter (fun k => (sched₁ (base + k)).kind = kd)).card ≤ m₁ →
      ((Finset.range len₂).filter (fun k => (sched₂ (base + len₁ + k)).kind = kd)).card ≤ m₂ →
      ((Finset.range (len₁ + len₂)).filter (fun k => (spliceSched (base + len₁) sched₁ sched₂ (base + k)).kind = kd)).card
        ≤ m₁ + m₂ := by
    intro kd m₁ m₂ hm₁ hm₂
    rw [card_filter_range_add len₁ len₂]
    have hL : (Finset.range len₁).filter (fun k => (spliceSched (base + len₁) sched₁ sched₂ (base + k)).kind = kd)
        = (Finset.range len₁).filter (fun k => (sched₁ (base + k)).kind = kd) := by
      refine Finset.filter_congr fun k hk => ?_
      have hlt : base + k < base + len₁ := by have := Finset.mem_range.mp hk; omega
      simp only [spliceSched, ite_eq_left hlt]
    have hR : (Finset.range len₂).filter (fun k => (spliceSched (base + len₁) sched₁ sched₂ (base + (len₁ + k))).kind = kd)
        = (Finset.range len₂).filter (fun k => (sched₂ (base + len₁ + k)).kind = kd) := by
      refine Finset.filter_congr fun k _ => ?_
      have hge : ¬ base + (len₁ + k) < base + len₁ := by omega
      simp only [spliceSched, ite_eq_right hge, Nat.add_assoc]
    rw [hL, hR]; exact Nat.add_le_add hm₁ hm₂
  refine
    { hptLen := h1.hptLen.andThen (fun a => (h2 a).hptLen)
      hqLE := qLE_andThen p f h1.hqLE (fun a => (h2 a).hqLE)
      hdepStrict := h1.hdepStrict.andThen (fun a => (h2 a).hdepStrict)
      hdepIn := depIn_andThen p f h1.hdepIn (fun a => (h2 a).hdepIn)
      hkCount := h1.hkCount.andThen (fun a => (h2 a).hkCount)
      hstep := trChainStep_trans (Nat.le_add_right base len₁) h1.hstep h2₀.hstep
      hcntT := hcnt .tr nT₁ nT₂ h1.hcntT h2₀.hcntT
      hcntL := hcnt .leaf nL₁ nL₂ h1.hcntL h2₀.hcntL
      hcntN := hcnt .node nN₁ nN₂ h1.hcntN h2₀.hcntN
      hleaf_tree := fun j id hlo hhi hsp => by
        unfold spliceSched at hsp
        by_cases hlt : j < base + len₁
        · rw [ite_eq_left hlt] at hsp; exact Or.inl (h1.hleaf_tree j id hlo hlt hsp)
        · rw [ite_eq_right hlt] at hsp; exact Or.inr (h2₀.hleaf_tree j id (by omega) (by omega) hsp)
      hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
        unfold spliceSched at hsi hsj
        by_cases hi : i < base + len₁ <;> by_cases hj : j < base + len₁
        · rw [ite_eq_left hi] at hsi; rw [ite_eq_left hj] at hsj
          exact h1.hleaf_inj i j id₁ id₂ hi1 hi hj1 hj hsi hsj hij
        · rw [ite_eq_left hi] at hsi; rw [ite_eq_right hj] at hsj
          intro heq
          have ht1 := h1.hleaf_tree i id₁ hi1 hi hsi
          have ht2 := h2₀.hleaf_tree j id₂ (by omega) (by omega) hsj
          rw [← heq] at ht2
          exact hdisj id₁.1 ht1 ht2
        · rw [ite_eq_right hi] at hsi; rw [ite_eq_left hj] at hsj
          intro heq
          have ht1 := h2₀.hleaf_tree i id₁ (by omega) (by omega) hsi
          have ht2 := h1.hleaf_tree j id₂ hj1 hj hsj
          rw [heq] at ht1
          exact hdisj id₂.1 ht2 ht1
        · rw [ite_eq_right hi] at hsi; rw [ite_eq_right hj] at hsj
          exact h2₀.hleaf_inj i j id₁ id₂ (by omega) (by omega) (by omega) (by omega) hsi hsj hij
      hnode_bounds := fun j L R hlo hhi hsp => by
        unfold spliceSched at hsp
        by_cases hlt : j < base + len₁
        · rw [ite_eq_left hlt] at hsp; exact h1.hnode_bounds j L R hlo hlt hsp
        · rw [ite_eq_right hlt] at hsp
          obtain ⟨h1', h2', h3'⟩ := h2₀.hnode_bounds j L R (by omega) (by omega) hsp
          exact ⟨by omega, h2', h3'⟩
      hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
        unfold spliceSched at hsi hsj
        by_cases hi : i < base + len₁ <;> by_cases hj : j < base + len₁
        · rw [ite_eq_left hi] at hsi; rw [ite_eq_left hj] at hsj
          exact h1.hnode_inj i j L₁ R₁ L₂ R₂ hi1 hi hj1 hj hsi hsj hij
        · rw [ite_eq_left hi] at hsi; rw [ite_eq_right hj] at hsj
          have hb1 := h1.hnode_bounds i L₁ R₁ hi1 hi hsi
          have hb2 := h2₀.hnode_bounds j L₂ R₂ (by omega) (by omega) hsj
          omega
        · rw [ite_eq_right hi] at hsi; rw [ite_eq_left hj] at hsj
          have hb1 := h2₀.hnode_bounds i L₁ R₁ (by omega) (by omega) hsi
          have hb2 := h1.hnode_bounds j L₂ R₂ hj1 hj hsj
          omega
        · rw [ite_eq_right hi] at hsi; rw [ite_eq_right hj] at hsj
          exact h2₀.hnode_inj i j L₁ R₁ L₂ R₂ (by omega) (by omega) (by omega) (by omega) hsi hsj hij
      htr_lt := fun j hlo hhi htr => by
        unfold spliceSched at htr ⊢
        by_cases hlt : j < base + len₁
        · rw [ite_eq_left hlt] at htr ⊢; exact h1.htr_lt j hlo hlt htr
        · rw [ite_eq_right hlt] at htr ⊢; exact h2₀.htr_lt j (by omega) (by omega) htr
      htr_entry := fun j hlo hhi htr ht0 => by
        unfold spliceSched at htr ⊢
        by_cases hlt : j < base + len₁
        · rw [ite_eq_left hlt] at htr ⊢; exact h1.htr_entry j hlo hlt htr ht0
        · rw [ite_eq_right hlt] at htr ⊢
          obtain ⟨ht1, hle01, hp01⟩ := h1.hstep ht0
          have he2 := h2₀.htr_entry j (by omega) (by omega) htr ht1
          cases hap0 : st₀.afterPosTag with
          | false =>
            simp only [↓reduceIte]
            cases hap1 : st₁.afterPosTag with
            | false => rw [hap1] at he2; simp only [↓reduceIte] at he2; exact le_trans hle01 he2
            | true =>
              rw [hap1] at he2; simp only [Bool.true_eq_false, ↓reduceIte] at he2
              rcases he2 with ⟨hle, _⟩ | hge
              · exact le_trans hle01 hle
              · have := st₀.htip_lt ht0; omega
          | true =>
            simp only [Bool.true_eq_false, ↓reduceIte]
            rcases hp01 hap0 with hge | ⟨hap1, heq01⟩
            · cases hap1 : st₁.afterPosTag with
              | false => rw [hap1] at he2; simp only [↓reduceIte] at he2; exact Or.inr (le_trans hge he2)
              | true =>
                rw [hap1] at he2; simp only [Bool.true_eq_false, ↓reduceIte] at he2
                rcases he2 with ⟨hle, _⟩ | hge2
                · exact Or.inr (le_trans hge hle)
                · exact Or.inr (by omega)
            · rw [hap1] at he2; simp only [Bool.true_eq_false, ↓reduceIte] at he2
              rcases he2 with ⟨hle, habs⟩ | hge2
              · exact Or.inl ⟨by omega, habs⟩
              · exact Or.inr (by omega)
      htr_exit := fun i hlo hhi htr => by
        unfold spliceSched at htr ⊢
        by_cases hlt : i < base + len₁
        · rw [ite_eq_left hlt] at htr ⊢
          obtain ⟨ht1, hex1⟩ := h1.htr_exit i hlo hlt htr
          obtain ⟨ht2, hle12, hp12⟩ := h2₀.hstep ht1
          refine ⟨ht2, ?_⟩
          cases hap1 : st₁.afterPosTag with
          | false =>
            rw [hap1] at hex1; simp only [↓reduceIte] at hex1
            cases hap2 : st₂.afterPosTag with
            | false => simp only [TrChainState.cast, hap2, ↓reduceIte]; exact le_trans hex1 hle12
            | true => simp only [TrChainState.cast, hap2, Bool.true_eq_false, ↓reduceIte]; exact Or.inl (le_trans hex1 hle12)
          | true =>
            rw [hap1] at hex1; simp only [Bool.true_eq_false, ↓reduceIte] at hex1
            rcases hp12 hap1 with hge | ⟨hap2, heq12⟩
            · cases hap2' : st₂.afterPosTag with
              | false => simp only [TrChainState.cast, hap2', ↓reduceIte]; omega
              | true => simp only [TrChainState.cast, hap2', Bool.true_eq_false, ↓reduceIte]; exact Or.inl (by omega)
            · simp only [TrChainState.cast, hap2, Bool.true_eq_false, ↓reduceIte]
              rcases hex1 with hle | hsq
              · exact Or.inl (by omega)
              · exact Or.inr hsq
        · rw [ite_eq_right hlt] at htr ⊢
          exact h2₀.htr_exit i (by omega) (by omega) htr
      htr_internal := fun i j hi1 hij hj2 htri htrj => by
        unfold spliceSched at htri htrj ⊢
        by_cases hi : i < base + len₁ <;> by_cases hj : j < base + len₁
        · rw [ite_eq_left hi] at htri ⊢; rw [ite_eq_left hj] at htrj ⊢
          exact h1.htr_internal i j hi1 hij hj htri htrj
        · rw [ite_eq_left hi] at htri ⊢; rw [ite_eq_right hj] at htrj ⊢
          obtain ⟨ht1, hex1⟩ := h1.htr_exit i hi1 hi htri
          have he2 := h2₀.htr_entry j (by omega) (by omega) htrj ht1
          cases hap1 : st₁.afterPosTag with
          | false =>
            rw [hap1] at hex1 he2; simp only [↓reduceIte] at hex1 he2
            exact Or.inl (le_trans hex1 he2)
          | true =>
            rw [hap1] at hex1 he2; simp only [Bool.true_eq_false, ↓reduceIte] at hex1 he2
            rcases he2 with ⟨hle, habs⟩ | hge
            · rcases hex1 with hle1 | hsq
              · exact Or.inl (le_trans hle1 hle)
              · exact Or.inr ⟨hsq, habs⟩
            · exact Or.inl (by omega)
        · omega
        · rw [ite_eq_right hi] at htri ⊢; rw [ite_eq_right hj] at htrj ⊢
          exact h2₀.htr_internal i j (by omega) hij (by omega) htri htrj
      hpt_match := fun H v j hpre hlo hhi => by
        unfold spliceSched
        by_cases hlt : j < base + len₁
        · rw [ite_eq_left hlt, PProg.ptAt_andThen_left H v p f len₁ base j h1.hptLen hlt]
          exact h1.hpt_match H v j hpre hlo hlt
        · rw [ite_eq_right hlt, PProg.ptAt_andThen_right H v p f len₁ base j h1.hptLen (by omega)]
          exact (h2 (p.res H v base)).hpt_match H v j (h1.hpost H v hpre) (by omega) (by omega)
      hpost := fun H v hpre => by
        rw [PProg.res_andThen H v p f len₁ base h1.hptLen]
        exact (h2 (p.res H v base)).hpost H v (h1.hpost H v hpre) }

/-- Convert a full `[0, shdP_zkPts)` `RawPtSpec` schedule into `Fin shdP_zkResPts → ShdPtSpec Lq`,
padding indices `[shdP_zkPts, shdP_zkResPts)` with `.tr .pad (i - 1) qHeadDig`. -/
def finishSched (Lq : ℕ) (sched : ℕ → RawPtSpec)
    (hnode : ∀ j L R, j < shdP_zkPts → sched j = .node L R → L < R ∧ R < j)
    (htr : ∀ j, j < shdP_zkPts → (sched j).isTr = true → (sched j).trM < j)
    (i : Fin shdP_zkResPts) : ShdPtSpec Lq :=
  if hi : i.val < shdP_zkPts then
    match hs : sched i.val with
    | .leaf id => .leaf id
    | .node L R =>
      have hb := hnode i.val L R hi hs
      have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
      .node ⟨L, by omega⟩ ⟨R, by omega⟩ (Fin.ne_of_val_ne (by dsimp only; omega))
    | .squeeze m =>
      have hm := htr i.val hi (by rw [hs]; rfl)
      have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
      .tr .squeeze ⟨m, by rw [hs] at hm; dsimp only [RawPtSpec.trM] at hm; omega⟩ qHeadDig
    | .absorb m =>
      have hm := htr i.val hi (by rw [hs]; rfl)
      have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
      .tr .absorb ⟨m, by rw [hs] at hm; dsimp only [RawPtSpec.trM] at hm; omega⟩ qHeadDig
    | .absorbExp m =>
      have hm := htr i.val hi (by rw [hs]; rfl)
      have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
      .tr .absorb ⟨m, by rw [hs] at hm; dsimp only [RawPtSpec.trM] at hm; omega⟩ qLastDig
  else
    .tr .pad ⟨i.val - 1, by have := i.isLt; omega⟩ qHeadDig

private theorem finishSched_of_leaf {Lq : ℕ} {sched : ℕ → RawPtSpec} {hnode htr} {i : Fin shdP_zkResPts}
    (hi : i.val < shdP_zkPts) {id : ShdLeafId} (hs : sched i.val = .leaf id) :
    finishSched Lq sched hnode htr i = .leaf id := by
  unfold finishSched; rw [dite_eq_left hi]; split <;> simp_all

private theorem finishSched_of_node {Lq : ℕ} {sched : ℕ → RawPtSpec} {hnode htr} {i : Fin shdP_zkResPts}
    (hi : i.val < shdP_zkPts) {L R : ℕ} (hs : sched i.val = .node L R) :
    ∃ hL hR hne, finishSched Lq sched hnode htr i = .node ⟨L, hL⟩ ⟨R, hR⟩ hne := by
  have hb := hnode i.val L R hi hs
  have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
  have hL : L < shdP_zkResPts := by omega
  have hR : R < shdP_zkResPts := by omega
  refine ⟨hL, hR, Fin.ne_of_val_ne (by dsimp only; omega), ?_⟩
  unfold finishSched; rw [dite_eq_left hi]
  split <;> rename_i heq <;> rw [hs] at heq <;> cases heq
  rfl

private theorem finishSched_of_squeeze {Lq : ℕ} {sched : ℕ → RawPtSpec} {hnode htr} {i : Fin shdP_zkResPts}
    (hi : i.val < shdP_zkPts) {m : ℕ} (hs : sched i.val = .squeeze m) :
    ∃ hm, finishSched Lq sched hnode htr i = .tr .squeeze ⟨m, hm⟩ qHeadDig := by
  have hm0 := htr i.val hi (by rw [hs]; rfl)
  rw [hs] at hm0; dsimp only [RawPtSpec.trM] at hm0
  have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
  refine ⟨by omega, ?_⟩
  unfold finishSched; rw [dite_eq_left hi]
  split <;> rename_i heq <;> rw [hs] at heq <;> cases heq
  rfl

private theorem finishSched_of_absorb {Lq : ℕ} {sched : ℕ → RawPtSpec} {hnode htr} {i : Fin shdP_zkResPts}
    (hi : i.val < shdP_zkPts) {m : ℕ} (hs : sched i.val = .absorb m) :
    ∃ hm, finishSched Lq sched hnode htr i = .tr .absorb ⟨m, hm⟩ qHeadDig := by
  have hm0 := htr i.val hi (by rw [hs]; rfl)
  rw [hs] at hm0; dsimp only [RawPtSpec.trM] at hm0
  have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
  refine ⟨by omega, ?_⟩
  unfold finishSched; rw [dite_eq_left hi]
  split <;> rename_i heq <;> rw [hs] at heq <;> cases heq
  rfl

private theorem finishSched_of_absorbExp {Lq : ℕ} {sched : ℕ → RawPtSpec} {hnode htr} {i : Fin shdP_zkResPts}
    (hi : i.val < shdP_zkPts) {m : ℕ} (hs : sched i.val = .absorbExp m) :
    ∃ hm, finishSched Lq sched hnode htr i = .tr .absorb ⟨m, hm⟩ qLastDig := by
  have hm0 := htr i.val hi (by rw [hs]; rfl)
  rw [hs] at hm0; dsimp only [RawPtSpec.trM] at hm0
  have hRes := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
  refine ⟨by omega, ?_⟩
  unfold finishSched; rw [dite_eq_left hi]
  split <;> rename_i heq <;> rw [hs] at heq <;> cases heq
  rfl

/-- **Master `SliceSpec → ShdScheduleMatch` finisher (`SliceSpec.finish`)**:
lifts a complete `[0, shdP_zkPts)` `SliceSpec` family into `ShdScheduleMatch`, discharging ALL 11
fields of `ShdScheduleMatch` in one theorem! -/
theorem SliceSpec.finish {X Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {prog : X → ShdCoins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)}
    {st₀ : TrChainState 0} {stEnd : TrChainState (0 + shdP_zkPts)}
    {trees : ShdTreeId → Prop} {sched : ℕ → RawPtSpec}
    (x₀ : X) (c₀ : ShdCoins)
    (hSlice : ∀ x c, SliceSpec Lq tag key domain shape c (prog x c) 0 shdP_zkPts
      shdP_zkQueries shdP_zkResT shdP_zkTrPts shdP_zkLeaves shdP_zkNodes
      st₀ stEnd trees sched (fun _ _ => True) (fun _ _ _ => True)) :
    let h₀ := hSlice x₀ c₀
    ShdScheduleMatch Lq hL20 tag key domain shape prog
      (finishSched Lq sched
        (fun j L R hj hs => let hb := h₀.hnode_bounds j L R (Nat.zero_le _) (by omega) hs; ⟨hb.2.1, hb.2.2⟩)
        (fun j hj htr => h₀.htr_lt j (Nat.zero_le _) (by omega) htr)) := by
  intro h₀
  set hnodeB : ∀ j L R, j < shdP_zkPts → sched j = .node L R → L < R ∧ R < j :=
    fun j L R hj hs => let hb := h₀.hnode_bounds j L R (Nat.zero_le _) (by omega) hs; ⟨hb.2.1, hb.2.2⟩
  set htrB : ∀ j, j < shdP_zkPts → (sched j).isTr = true → (sched j).trM < j :=
    fun j hj htr => h₀.htr_lt j (Nat.zero_le _) (by omega) htr
  set fsched := finishSched Lq sched hnodeB htrB
  have hf_leaf : ∀ {i : Fin shdP_zkResPts} {id}, i.val < shdP_zkPts → sched i.val = .leaf id →
      fsched i = .leaf id := fun hi hs => finishSched_of_leaf hi hs
  have hf_node : ∀ {i : Fin shdP_zkResPts} {L R}, i.val < shdP_zkPts → sched i.val = .node L R →
      ∃ hL hR hne, fsched i = .node ⟨L, hL⟩ ⟨R, hR⟩ hne := fun hi hs => finishSched_of_node hi hs
  have hf_sq : ∀ {i : Fin shdP_zkResPts} {m}, i.val < shdP_zkPts → sched i.val = .squeeze m →
      ∃ hm, fsched i = .tr .squeeze ⟨m, hm⟩ qHeadDig := fun hi hs => finishSched_of_squeeze hi hs
  have hf_abs : ∀ {i : Fin shdP_zkResPts} {m}, i.val < shdP_zkPts → sched i.val = .absorb m →
      ∃ hm, fsched i = .tr .absorb ⟨m, hm⟩ qHeadDig := fun hi hs => finishSched_of_absorb hi hs
  have hf_absE : ∀ {i : Fin shdP_zkResPts} {m}, i.val < shdP_zkPts → sched i.val = .absorbExp m →
      ∃ hm, fsched i = .tr .absorb ⟨m, hm⟩ qLastDig := fun hi hs => finishSched_of_absorbExp hi hs
  have hResLe : shdP_zkPts ≤ shdP_zkResPts := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1
  have hPtsPos : 0 < shdP_zkPts := by rw [shdP_zkProg_counts.2.2.2.2.2.2.1]; norm_num
  have hkind_lt : ∀ (i : Fin shdP_zkResPts), i.val < shdP_zkPts → (fsched i).kind = (sched i.val).kind := by
    intro i hi
    cases hs : sched i.val with
    | leaf id => rw [hf_leaf hi hs]; rfl
    | node L R => obtain ⟨_, _, _, heq⟩ := hf_node hi hs; rw [heq]; rfl
    | squeeze m => obtain ⟨_, heq⟩ := hf_sq hi hs; rw [heq]; rfl
    | absorb m => obtain ⟨_, heq⟩ := hf_abs hi hs; rw [heq]; rfl
    | absorbExp m => obtain ⟨_, heq⟩ := hf_absE hi hs; rw [heq]; rfl
  have hkind_ge : ∀ (i : Fin shdP_zkResPts), ¬ i.val < shdP_zkPts → (fsched i).kind = .tr := by
    intro i hi
    unfold fsched finishSched; rw [dite_eq_right hi]; rfl
  -- Helper: cardinality of filtered `Fin shdP_zkResPts` restricted to `< shdP_zkPts`
  have hcard_lt : ∀ (kd : ShdQKind),
      (univ.filter (fun i : Fin shdP_zkResPts => i.val < shdP_zkPts ∧ (fsched i).kind = kd)).card
        = ((Finset.range shdP_zkPts).filter (fun k => (sched (0 + k)).kind = kd)).card := by
    intro kd
    refine Finset.card_bij (fun i _ => i.val) ?_ ?_ ?_
    · intro i hi
      obtain ⟨hlt, hk⟩ := (mem_filter.mp hi).2
      rw [hkind_lt i hlt] at hk
      exact mem_filter.mpr ⟨Finset.mem_range.mpr hlt, by simpa using hk⟩
    · intro i₁ _ i₂ _ heq; exact Fin.ext heq
    · intro k hk
      obtain ⟨hlt, hk'⟩ := mem_filter.mp hk
      have hlt' : k < shdP_zkPts := Finset.mem_range.mp hlt
      refine ⟨⟨k, lt_of_lt_of_le hlt' hResLe⟩, mem_filter.mpr ⟨mem_univ _, hlt', ?_⟩, rfl⟩
      rw [hkind_lt _ hlt']; simpa using hk'
  -- Helper for `ptsOf` on `i < shdP_zkPts` vs `i ≥ shdP_zkPts`
  have hpts_lt : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) (i : Fin shdP_zkResPts),
      i.val < shdP_zkPts →
      RawPtMatch Lq tag key domain shape s.1 (extend s.2)
        (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) (sched i.val) := by
    intro x H s i hi
    obtain ⟨q, hpt, hmat⟩ := (hSlice x s.1).hpt_match H (extend s.2) i.val trivial (Nat.zero_le _) (by omega)
    unfold PProg.ptsOf
    rw [hpt]; exact hmat
  have hpts_ge : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) (i : Fin shdP_zkResPts),
      ¬ i.val < shdP_zkPts →
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
        = shdP_zkPad Lq hL20 i.val (s.2 ⟨i.val - 1, by have := i.isLt; omega⟩) := by
    intro x H s i hi
    have hnone : (prog x s.1).ptAt H (extend s.2) 0 i.val = none := by
      cases hp : (prog x s.1).ptAt H (extend s.2) 0 i.val with
      | none => rfl
      | some q =>
        have hlt := PProg.ptAt_some_lt H (extend s.2) (prog x s.1) shdP_zkPts 0 i.val q
          (hSlice x s.1).hptLen.toPtLE hp
        omega
    unfold PProg.ptsOf
    rw [hnone, Option.getD_none, ite_eq_right (by omega : i.val ≠ 0)]
    unfold extend
    rw [dite_eq_left (by have := i.isLt; omega : i.val - 1 < shdP_zkResPts)]
  have hext_eq : ∀ (v : Fin shdP_zkResPts → Dig) (m : ℕ) (hm : m < shdP_zkResPts),
      extend v m = v ⟨m, hm⟩ := fun v m hm => dite_eq_left hm
  refine
    { hcntT := by
        have hsub : univ.filter (fun i : Fin shdP_zkResPts => (fsched i).kind = .tr)
            ⊆ univ.filter (fun i : Fin shdP_zkResPts => i.val < shdP_zkPts ∧ (fsched i).kind = .tr)
              ∪ univ.filter (fun i : Fin shdP_zkResPts => ¬ i.val < shdP_zkPts) := by
          intro i hi
          by_cases hlt : i.val < shdP_zkPts
          · exact mem_union_left _ (mem_filter.mpr ⟨mem_univ _, hlt, (mem_filter.mp hi).2⟩)
          · exact mem_union_right _ (mem_filter.mpr ⟨mem_univ _, hlt⟩)
        have hgeCard : (univ.filter (fun i : Fin shdP_zkResPts => ¬ i.val < shdP_zkPts)).card
            = shdP_zkResPts - shdP_zkPts := by
          rw [← Finset.card_range (shdP_zkResPts - shdP_zkPts)]
          refine Finset.card_bij (fun (i : Fin shdP_zkResPts) _ => i.val - shdP_zkPts) ?_ ?_ ?_
          · intro i hi
            have hge := (mem_filter.mp hi).2; have hlt := i.isLt
            exact Finset.mem_range.mpr (by omega)
          · intro i₁ hi₁ i₂ hi₂ heq
            have h1 := (mem_filter.mp hi₁).2; have h2 := (mem_filter.mp hi₂).2
            exact Fin.ext (by omega)
          · intro k hk
            have hk' := Finset.mem_range.mp hk
            refine ⟨⟨shdP_zkPts + k, by omega⟩, mem_filter.mpr ⟨mem_univ _, by dsimp only; omega⟩, by dsimp only; omega⟩
        have hle := (Finset.card_le_card hsub).trans (Finset.card_union_le _ _)
        rw [hcard_lt .tr, hgeCard] at hle
        have h1 := h₀.hcntT
        have hnums := shdP_zkProg_counts
        have hResT : shdP_zkResT = 1048576 := by unfold shdP_zkResT; norm_num
        omega
      hcntL := by
        have hsub : univ.filter (fun i : Fin shdP_zkResPts => (fsched i).kind = .leaf)
            ⊆ univ.filter (fun i : Fin shdP_zkResPts => i.val < shdP_zkPts ∧ (fsched i).kind = .leaf) := by
          intro i hi
          have hk := (mem_filter.mp hi).2
          by_cases hlt : i.val < shdP_zkPts
          · exact mem_filter.mpr ⟨mem_univ _, hlt, hk⟩
          · rw [hkind_ge i hlt] at hk; cases hk
        exact ((Finset.card_le_card hsub).trans (le_of_eq (hcard_lt .leaf))).trans h₀.hcntL
      hcntN := by
        have hsub : univ.filter (fun i : Fin shdP_zkResPts => (fsched i).kind = .node)
            ⊆ univ.filter (fun i : Fin shdP_zkResPts => i.val < shdP_zkPts ∧ (fsched i).kind = .node) := by
          intro i hi
          have hk := (mem_filter.mp hi).2
          by_cases hlt : i.val < shdP_zkPts
          · exact mem_filter.mpr ⟨mem_univ _, hlt, hk⟩
          · rw [hkind_ge i hlt] at hk; cases hk
        exact ((Finset.card_le_card hsub).trans (le_of_eq (hcard_lt .node))).trans h₀.hcntN
      hleaf_inj := fun i j id₁ id₂ hsi hsj hij => by
        by_cases hi : i.val < shdP_zkPts <;> by_cases hj : j.val < shdP_zkPts
        · cases h1 : sched i.val with
          | leaf id₁' =>
            rw [hf_leaf hi h1] at hsi; cases hsi
            cases h2 : sched j.val with
            | leaf id₂' =>
              rw [hf_leaf hj h2] at hsj; cases hsj
              exact h₀.hleaf_inj i.val j.val id₁ id₂ (Nat.zero_le _) (by omega) (Nat.zero_le _) (by omega)
                h1 h2 (Fin.val_ne_of_ne hij)
            | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hj h2; rw [heq] at hsj; cases hsj
            | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hj h2; rw [heq] at hsj; cases hsj
            | absorb _ => obtain ⟨_, heq⟩ := hf_abs hj h2; rw [heq] at hsj; cases hsj
            | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hj h2; rw [heq] at hsj; cases hsj
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi h1; rw [heq] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi h1; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi h1; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi h1; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsj; rw [dite_eq_right hj] at hsj; cases hsj
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      hnode_inj := fun i j L₁ R₁ h₁ L₂ R₂ h₂ hsi hsj hij => by
        by_cases hi : i.val < shdP_zkPts <;> by_cases hj : j.val < shdP_zkPts
        · cases h1' : sched i.val with
          | node L₁' R₁' =>
            obtain ⟨_, _, _, heq1⟩ := hf_node hi h1'; rw [heq1] at hsi; cases hsi
            cases h2' : sched j.val with
            | node L₂' R₂' =>
              obtain ⟨_, _, _, heq2⟩ := hf_node hj h2'; rw [heq2] at hsj; cases hsj
              exact Fin.ne_of_val_ne (h₀.hnode_inj i.val j.val _ _ _ _ (Nat.zero_le _) (by omega)
                (Nat.zero_le _) (by omega) h1' h2' (Fin.val_ne_of_ne hij))
            | leaf _ => rw [hf_leaf hj h2'] at hsj; cases hsj
            | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hj h2'; rw [heq] at hsj; cases hsj
            | absorb _ => obtain ⟨_, heq⟩ := hf_abs hj h2'; rw [heq] at hsj; cases hsj
            | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hj h2'; rw [heq] at hsj; cases hsj
          | leaf _ => rw [hf_leaf hi h1'] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi h1'; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi h1'; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi h1'; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsj; rw [dite_eq_right hj] at hsj; cases hsj
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      htr_order := fun i j tk₁ m₁ ext₁ tk₂ m₂ ext₂ hij hsi hsj => by
        by_cases hj : j.val < shdP_zkPts
        · have hi : i.val < shdP_zkPts := lt_trans hij hj
          cases h1' : sched i.val with
          | leaf _ => rw [hf_leaf hi h1'] at hsi; cases hsi
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi h1'; rw [heq] at hsi; cases hsi
          | squeeze m₁' =>
            obtain ⟨_, heq1⟩ := hf_sq hi h1'; rw [heq1] at hsi; cases hsi
            cases h2' : sched j.val with
            | leaf _ => rw [hf_leaf hj h2'] at hsj; cases hsj
            | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hj h2'; rw [heq] at hsj; cases hsj
            | squeeze m₂' =>
              obtain ⟨_, heq2⟩ := hf_sq hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨_, hf⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
            | absorb _ =>
              obtain ⟨_, heq2⟩ := hf_abs hj h2'; rw [heq2] at hsj; cases hsj
              exact Or.inr (Or.inr ⟨rfl, rfl⟩)
            | absorbExp _ =>
              obtain ⟨_, heq2⟩ := hf_absE hj h2'; rw [heq2] at hsj; cases hsj
              exact Or.inr (Or.inr ⟨rfl, rfl⟩)
          | absorb m₁' =>
            obtain ⟨_, heq1⟩ := hf_abs hi h1'; rw [heq1] at hsi; cases hsi
            cases h2' : sched j.val with
            | leaf _ => rw [hf_leaf hj h2'] at hsj; cases hsj
            | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hj h2'; rw [heq] at hsj; cases hsj
            | squeeze m₂' =>
              obtain ⟨_, heq2⟩ := hf_sq hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
            | absorb m₂' =>
              obtain ⟨_, heq2⟩ := hf_abs hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
            | absorbExp m₂' =>
              obtain ⟨_, heq2⟩ := hf_absE hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
          | absorbExp m₁' =>
            obtain ⟨_, heq1⟩ := hf_absE hi h1'; rw [heq1] at hsi; cases hsi
            cases h2' : sched j.val with
            | leaf _ => rw [hf_leaf hj h2'] at hsj; cases hsj
            | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hj h2'; rw [heq] at hsj; cases hsj
            | squeeze m₂' =>
              obtain ⟨_, heq2⟩ := hf_sq hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
            | absorb m₂' =>
              obtain ⟨_, heq2⟩ := hf_abs hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
            | absorbExp m₂' =>
              obtain ⟨_, heq2⟩ := hf_absE hj h2'; rw [heq2] at hsj; cases hsj
              have hi' := h₀.htr_internal i.val j.val (Nat.zero_le _) hij (by omega)
                (by rw [h1']; rfl) (by rw [h2']; rfl)
              rw [h1', h2'] at hi'
              rcases hi' with hle | ⟨hf, _⟩
              · exact Or.inr (Or.inl hle)
              · cases hf
        · unfold fsched finishSched at hsj; rw [dite_eq_right hj] at hsj; cases hsj; exact Or.inl rfl
      hleaf_pt := fun x H s i id hsi => by
        by_cases hi : i.val < shdP_zkPts
        · cases hs : sched i.val with
          | leaf id' =>
            rw [hf_leaf hi hs] at hsi; cases hsi
            have hm := hpts_lt x H s i hi; rw [hs] at hm; exact hm
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi hs; rw [heq] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi hs; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi hs; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi hs; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      hnode_pt := fun x H s i L R hLR hsi => by
        by_cases hi : i.val < shdP_zkPts
        · cases hs : sched i.val with
          | node L' R' =>
            obtain ⟨hL', hR', _, heq⟩ := hf_node hi hs; rw [heq] at hsi; cases hsi
            have hm := hpts_lt x H s i hi; rw [hs] at hm
            obtain ⟨hn, hq⟩ := hm
            generalize heL : extend s.2 L' = dL at hn hq
            generalize heR : extend s.2 R' = dR at hn hq
            rw [hext_eq s.2 L' hL'] at heL; rw [hext_eq s.2 R' hR'] at heR
            subst heL heR
            exact ⟨hn, hq⟩
          | leaf _ => rw [hf_leaf hi hs] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi hs; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi hs; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi hs; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      hsqueeze_pt := fun x H s i m ext hsi => by
        by_cases hi : i.val < shdP_zkPts
        · cases hs : sched i.val with
          | squeeze m' =>
            obtain ⟨hm', heq⟩ := hf_sq hi hs; rw [heq] at hsi; cases hsi
            have hm := hpts_lt x H s i hi; rw [hs] at hm
            obtain ⟨ctr, hs', hq⟩ := hm
            generalize heM : extend s.2 m' = dM at hs' hq
            rw [hext_eq s.2 m' hm'] at heM; subst heM
            exact ⟨ctr, hs', hq, by rw [hq, qHeadDig_squeeze]⟩
          | leaf _ => rw [hf_leaf hi hs] at hsi; cases hsi
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi hs; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi hs; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi hs; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      habsorb_pt := fun x H i m ext hsi => by
        by_cases hi : i.val < shdP_zkPts
        · cases hs : sched i.val with
          | leaf _ => rw [hf_leaf hi hs] at hsi; cases hsi
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi hs; rw [heq] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi hs; rw [heq] at hsi; cases hsi
          | absorb m' =>
            obtain ⟨hm', heq⟩ := hf_abs hi hs; rw [heq] at hsi; cases hsi
            refine ⟨fun s => ?_, Or.inl fun s => ?_⟩
            · have hm := hpts_lt x H s i hi; rw [hs] at hm
              obtain ⟨lab, dat, ha, hne, hlt, hq⟩ := hm
              generalize heM : extend s.2 m' = dM at ha hq
              rw [hext_eq s.2 m' hm'] at heM; subst heM
              exact ⟨s.2 ⟨m', hm'⟩, lab, dat, ha, hne, hlt, hq, by rw [hq, qHeadDig_absorb]⟩
            · have hm := hpts_lt x H s i hi; rw [hs] at hm
              obtain ⟨lab, dat, ha, hne, hlt, hq⟩ := hm
              generalize heM : extend s.2 m' = dM at ha hq
              rw [hext_eq s.2 m' hm'] at heM; subst heM
              exact ⟨lab, dat, ha, hne, hlt, hq⟩
          | absorbExp m' =>
            obtain ⟨hm', heq⟩ := hf_absE hi hs; rw [heq] at hsi; cases hsi
            refine ⟨fun s => ?_, Or.inr fun s => ?_⟩
            · have hm := hpts_lt x H s i hi; rw [hs] at hm
              obtain ⟨st, lab, dat, ha, hne, hlt, hq, hlast, _⟩ := hm
              rw [hext_eq s.2 m' hm'] at hlast
              exact ⟨st, lab, dat, ha, hne, hlt, hq, hlast⟩
            · have hm := hpts_lt x H s i hi; rw [hs] at hm
              obtain ⟨_, _, _, _, _, _, _, _, hnot⟩ := hm
              exact hnot
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
      hpad_pt := fun x H s i m ext hsi => by
        by_cases hi : i.val < shdP_zkPts
        · cases hs : sched i.val with
          | leaf _ => rw [hf_leaf hi hs] at hsi; cases hsi
          | node _ _ => obtain ⟨_, _, _, heq⟩ := hf_node hi hs; rw [heq] at hsi; cases hsi
          | squeeze _ => obtain ⟨_, heq⟩ := hf_sq hi hs; rw [heq] at hsi; cases hsi
          | absorb _ => obtain ⟨_, heq⟩ := hf_abs hi hs; rw [heq] at hsi; cases hsi
          | absorbExp _ => obtain ⟨_, heq⟩ := hf_absE hi hs; rw [heq] at hsi; cases hsi
        · unfold fsched finishSched at hsi; rw [dite_eq_right hi] at hsi; cases hsi
          have hq := hpts_ge x H s i hi
          exact ⟨hq, by rw [hq, qHeadDig_zkPad]⟩ }

end SliceEngine

/-! ## 4. Atomic Fixed-Schedule Combinators & `SliceSpec` Discharges -/

section AtomicSlices

private theorem run_ret {Q R α : Type} (G : Q → R) (a : α) : (PProg.ret a).run G = a := rfl

/-- Pure return slice (`0` queries, preserves `TrChainState`, works with any schedule `sched`). -/
theorem retSliceSpec {α : Type} {Lq : ℕ} {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {c : ShdCoins} (a : α) (base : ℕ) (st : TrChainState base)
    (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop)
    (post : (QB Lq → Dig) → (ℕ → Dig) → α → Prop)
    (hpost : ∀ H v, pre H v → post H v a)
    (sched : ℕ → RawPtSpec := fun _ => .absorb 0) :
    SliceSpec Lq tag key domain shape c (.ret a) base 0 0 0 0 0 0 st st
      (fun _ => False) sched pre post where
  hptLen := rfl
  hqLE := trivial
  hdepStrict := DepStrict.ret a
  hdepIn := trivial
  hkCount := trivial
  hstep := trChainStep_refl st
  hcntT := by simp
  hcntL := by simp
  hcntN := by simp
  hleaf_tree := fun _ _ h1 h2 _ => by omega
  hleaf_inj := fun _ _ _ _ h1 h2 => by omega
  hnode_bounds := fun _ _ _ h1 h2 => by omega
  hnode_inj := fun _ _ _ _ _ _ h1 h2 => by omega
  htr_lt := fun _ h1 h2 => by omega
  htr_entry := fun _ h1 h2 => by omega
  htr_exit := fun _ h1 h2 => by omega
  htr_internal := fun _ _ h1 h2 h3 => by omega
  hpt_match := fun _ _ _ _ h1 h2 => by omega
  hpost := hpost

/-- **Merkle tree slice (`merkleTreeProg`)** for tree `tid : ShdTreeId` of depth `d = shdTreeDepthOf tid`
(`2^d` `.leaf`s + `2^d - 1` `.node`s, `0` `.tr`s; leaves `TrChainState` unchanged). -/
def merkleTreeSched (tid : ShdTreeId) (base : ℕ) (j : ℕ) : RawPtSpec :=
  let d := shdTreeDepthOf tid
  if hlt : j - base < 2 ^ d then .leaf ⟨tid, ⟨j - base, hlt⟩⟩
  else
    let p := merkleChildOff d (j - base - 2 ^ d)
    .node (base + p.1) (base + p.2)

theorem merkleTreeSliceSpec {Lq : ℕ} (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (tid : ShdTreeId) (base : ℕ) (st : TrChainState base)
    (colOf : Fin (2 ^ shdTreeDepthOf tid) → List UInt8)
    (hcol : ∀ j, (colOf j).length ≤ Lq)
    (h8 : ∀ j, (colOf j).length % 8 = 0)
    (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop) :
    let d := shdTreeDepthOf tid
    let len := 2 ^ d + (2 ^ d - 1)
    let stOut : TrChainState (base + len) := ⟨st.hasTip, st.trTip,
      fun h => by have := st.htip_lt h; have : 1 ≤ 2 ^ d := Nat.one_le_two_pow; omega,
      st.afterPosTag, st.hpos⟩
    SliceSpec Lq tag key domain shape c
      (merkleTreeProg Lq h64 tag d colOf hcol (fun j => shdLeafSalt c ⟨tid, j⟩))
      base len (2 ^ d + 2 ^ d + (2 ^ d - 1)) 0 0 (2 ^ d) (2 ^ d - 1)
      st stOut (fun t => t = tid) (merkleTreeSched tid base) pre
      (fun _ v tr => tr = levelsOfV v d base ∧ tr.getRoot = v (base + len - 1)) := by
  intro d len stOut
  have h1d : 1 ≤ 2 ^ d := Nat.one_le_two_pow
  refine
    { hptLen := merkleTreeProg_ptLen Lq h64 tag d colOf hcol _
      hqLE := merkleTreeProg_qLE Lq h64 tag d colOf hcol _
      hdepStrict := merkleTreeProg_depStrict Lq h64 tag d colOf hcol _
      hdepIn := merkleTreeProg_depIn_run Lq h64 tag key domain shape d colOf hcol h8 _
      hkCount := by
        simpa [merkleTreeProg] using (leafLayerAux_kCount Lq h64 hsep (2 ^ d) colOf hcol h8
          (fun j => shdLeafSalt c ⟨tid, j⟩)).andThen (fun lv => buildLevelsProg_kCount Lq h64 hsep d lv)
      hstep := fun h => ⟨h, le_rfl, fun hp => Or.inr ⟨hp, rfl⟩⟩
      hcntT := by
        have hemp : (Finset.range len).filter (fun k => (merkleTreeSched tid base (base + k)).kind = .tr) = ∅ := by
          refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
          unfold merkleTreeSched at hk; dsimp only at hk
          split_ifs at hk <;> cases hk
        rw [hemp, Finset.card_empty]
      hcntL := by
        have hsub : (Finset.range len).filter (fun k => (merkleTreeSched tid base (base + k)).kind = .leaf)
            ⊆ Finset.range (2 ^ d) := by
          intro k hk
          have heq := (mem_filter.mp hk).2
          unfold merkleTreeSched at heq; dsimp only at heq
          by_cases hlt : base + k - base < 2 ^ d
          · exact Finset.mem_range.mpr (by omega)
          · rw [dite_eq_right hlt] at heq; cases heq
        exact (Finset.card_le_card hsub).trans (by rw [Finset.card_range])
      hcntN := by
        have hsub : (Finset.range len).filter (fun k => (merkleTreeSched tid base (base + k)).kind = .node)
            ⊆ (Finset.range (2 ^ d - 1)).image (2 ^ d + ·) := by
          intro k hk
          have hmem := Finset.mem_range.mp (mem_filter.mp hk).1
          have heq := (mem_filter.mp hk).2
          unfold merkleTreeSched at heq; dsimp only at heq
          by_cases hlt : base + k - base < 2 ^ d
          · rw [dite_eq_left hlt] at heq; cases heq
          · exact Finset.mem_image.mpr ⟨k - 2 ^ d, Finset.mem_range.mpr (by omega), by omega⟩
        exact (Finset.card_le_card hsub).trans ((Finset.card_image_le).trans (by rw [Finset.card_range]))
      hleaf_tree := fun j id hlo hhi hs => by
        unfold merkleTreeSched at hs; dsimp only at hs
        by_cases hlt : j - base < 2 ^ d
        · rw [dite_eq_left hlt] at hs; cases hs; rfl
        · rw [dite_eq_right hlt] at hs; cases hs
      hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
        unfold merkleTreeSched at hsi hsj; dsimp only at hsi hsj
        by_cases hi : i - base < 2 ^ d <;> by_cases hj : j - base < 2 ^ d
        · rw [dite_eq_left hi] at hsi; rw [dite_eq_left hj] at hsj
          cases hsi; cases hsj
          intro heq
          have hval : i - base = j - base := congrArg (fun x : ShdLeafId => x.2.val) heq
          omega
        · rw [dite_eq_right hj] at hsj; cases hsj
        · rw [dite_eq_right hi] at hsi; cases hsi
        · rw [dite_eq_right hi] at hsi; cases hsi
      hnode_bounds := fun j L R hlo hhi hs => by
        unfold merkleTreeSched at hs; dsimp only at hs
        dsimp only [len, d] at hhi
        by_cases hlt : j - base < 2 ^ shdTreeDepthOf tid
        · rw [dite_eq_left hlt] at hs; cases hs
        · rw [dite_eq_right hlt] at hs; cases hs
          have hm := merkleChildOff_lt (shdTreeDepthOf tid) (j - base - 2 ^ (shdTreeDepthOf tid)) (by omega)
          exact ⟨Nat.le_add_right _ _, by omega, by omega⟩
      hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
        unfold merkleTreeSched at hsi hsj; dsimp only at hsi hsj
        dsimp only [len, d] at hi2 hj2
        by_cases hi : i - base < 2 ^ shdTreeDepthOf tid <;> by_cases hj : j - base < 2 ^ shdTreeDepthOf tid
        · rw [dite_eq_left hi] at hsi; cases hsi
        · rw [dite_eq_left hi] at hsi; cases hsi
        · rw [dite_eq_left hj] at hsj; cases hsj
        · rw [dite_eq_right hi] at hsi; rw [dite_eq_right hj] at hsj
          cases hsi; cases hsj
          intro heq
          have hf := merkleChildOff_fst_inj (shdTreeDepthOf tid)
            (i - base - 2 ^ (shdTreeDepthOf tid)) (j - base - 2 ^ (shdTreeDepthOf tid))
            (by omega) (by omega) (by omega)
          omega
      htr_lt := fun j _ _ htr => by
        unfold merkleTreeSched at htr; dsimp only at htr; split_ifs at htr <;> cases htr
      htr_entry := fun j _ _ htr => by
        unfold merkleTreeSched at htr; dsimp only at htr; split_ifs at htr <;> cases htr
      htr_exit := fun i _ _ htr => by
        unfold merkleTreeSched at htr; dsimp only at htr; split_ifs at htr <;> cases htr
      htr_internal := fun i _ _ _ _ htr => by
        unfold merkleTreeSched at htr; dsimp only at htr; split_ifs at htr <;> cases htr
      hpt_match := fun H v j _ hlo hhi => by
        unfold merkleTreeSched; dsimp only
        by_cases hlt : j - base < 2 ^ d
        · rw [dite_eq_left hlt]
          have hpt := merkleTreeProg_ptAt_leaf Lq h64 tag d colOf hcol (fun r => shdLeafSalt c ⟨tid, r⟩)
            H v base ⟨j - base, hlt⟩
          rw [show base + (j - base) = j by omega] at hpt
          exact ⟨_, hpt, H (tag.col, ⟨colOf ⟨j - base, hlt⟩, hcol _⟩), by rw [digPair_length]; exact h64, rfl⟩
        · rw [dite_eq_right hlt]
          have hpt := merkleTreeProg_ptAt_node Lq h64 tag d colOf hcol (fun r => shdLeafSalt c ⟨tid, r⟩)
            H v base (j - base - 2 ^ d) (by omega)
          rw [show base + 2 ^ d + (j - base - 2 ^ d) = j by omega] at hpt
          exact ⟨_, hpt, by rw [digPair_length]; exact h64, rfl⟩
      hpost := fun H v _ =>
        ⟨merkleTreeProg_res_eq Lq h64 tag d colOf hcol _ H v base,
         by rw [merkleTreeProg_res_getRoot, show base + 2 ^ d + (2 ^ d - 1) - 1 = base + len - 1 by omega]⟩ }

/-- Helper: relax `pre`/`post`/`trees` and rewrite arithmetic counts on `SliceSpec`. -/
theorem SliceSpec.congr {α : Type} {Lq : ℕ} {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {c : ShdCoins} {p : PProg (QB Lq) Dig α}
    {base len len' nQ nQ' nTrK nTrK' nT nT' nL nL' nN nN' : ℕ}
    {stIn : TrChainState base} {stOut : TrChainState (base + len)} {stOut' : TrChainState (base + len')}
    {trees trees' : ShdTreeId → Prop} {sched : ℕ → RawPtSpec}
    {pre pre' : (QB Lq → Dig) → (ℕ → Dig) → Prop}
    {post post' : (QB Lq → Dig) → (ℕ → Dig) → α → Prop}
    (h : SliceSpec Lq tag key domain shape c p base len nQ nTrK nT nL nN stIn stOut trees sched pre post)
    (hlen : len = len') (hnQ : nQ ≤ nQ') (hnTrK : nTrK ≤ nTrK') (hnT : nT ≤ nT') (hnL : nL ≤ nL') (hnN : nN ≤ nN')
    (hst : stOut.cast (congrArg (base + ·) hlen) = stOut')
    (htrees : ∀ t, trees t → trees' t)
    (hpre : ∀ H v, pre' H v → pre H v)
    (hpost : ∀ H v a, pre' H v → post H v a → post' H v a) :
    SliceSpec Lq tag key domain shape c p base len' nQ' nTrK' nT' nL' nN' stIn stOut' trees' sched pre' post' := by
  subst hlen
  have hst' : stOut = stOut' := by
    refine TrChainState.ext ?_ ?_ ?_
    · exact congrArg TrChainState.hasTip hst
    · exact congrArg TrChainState.trTip hst
    · exact congrArg TrChainState.afterPosTag hst
  subst hst'
  exact
    { hptLen := h.hptLen
      hqLE := qLE_mono p h.hqLE hnQ
      hdepStrict := h.hdepStrict
      hdepIn := h.hdepIn
      hkCount := h.hkCount.mono hnTrK hnL hnN
      hstep := h.hstep
      hcntT := le_trans h.hcntT hnT
      hcntL := le_trans h.hcntL hnL
      hcntN := le_trans h.hcntN hnN
      hleaf_tree := fun j id h1 h2 hs => htrees _ (h.hleaf_tree j id h1 h2 hs)
      hleaf_inj := h.hleaf_inj
      hnode_bounds := h.hnode_bounds
      hnode_inj := h.hnode_inj
      htr_lt := h.htr_lt
      htr_entry := h.htr_entry
      htr_exit := h.htr_exit
      htr_internal := h.htr_internal
      hpt_match := fun H v j hp h1 h2 => h.hpt_match H v j (hpre H v hp) h1 h2
      hpost := fun H v hp => hpost H v _ hp (h.hpost H v (hpre H v hp)) }

/-- **One-step top-down `andThen + congr` combinator (`SliceSpec.seq`)**: chains `h1` with a continuation
`h2` directly on the goal with zero metavariable duplication and pure `hasTip`/`trTip`/`afterPosTag` state matching! -/
theorem SliceSpec.seq {α β : Type} {Lq : ℕ} {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {c : ShdCoins} {p : PProg (QB Lq) Dig α} {f : α → PProg (QB Lq) Dig β}
    {base len₁ len₂ len nQ₁ nQ₂ nQ nTrK₁ nTrK₂ nTrK nT₁ nT₂ nT nL₁ nL₂ nL nN₁ nN₂ nN : ℕ}
    {st₀ : TrChainState base} {st₁ : TrChainState (base + len₁)} {st₂ : TrChainState (base + len₁ + len₂)}
    {stOut : TrChainState (base + len)}
    {trees₁ trees₂ trees : ShdTreeId → Prop} {sched₁ sched₂ : ℕ → RawPtSpec}
    {pre pre' : (QB Lq → Dig) → (ℕ → Dig) → Prop}
    {mid : (QB Lq → Dig) → (ℕ → Dig) → α → Prop}
    {post post' : (QB Lq → Dig) → (ℕ → Dig) → β → Prop}
    (h1 : SliceSpec Lq tag key domain shape c p base len₁ nQ₁ nTrK₁ nT₁ nL₁ nN₁ st₀ st₁ trees₁ sched₁ pre mid)
    (h2 : ∀ a, SliceSpec Lq tag key domain shape c (f a) (base + len₁) len₂ nQ₂ nTrK₂ nT₂ nL₂ nN₂ st₁ st₂ trees₂ sched₂
      (fun H v => mid H v a) post)
    (hdisj : ∀ t, trees₁ t → ¬ trees₂ t)
    (hlen : len₁ + len₂ = len) (hnQ : nQ₁ + nQ₂ ≤ nQ) (hnTrK : nTrK₁ + nTrK₂ ≤ nTrK)
    (hnT : nT₁ + nT₂ ≤ nT) (hnL : nL₁ + nL₂ ≤ nL) (hnN : nN₁ + nN₂ ≤ nN)
    (hst : st₂.hasTip = stOut.hasTip ∧ st₂.trTip = stOut.trTip ∧ st₂.afterPosTag = stOut.afterPosTag)
    (htrees : ∀ t, trees₁ t ∨ trees₂ t → trees t)
    (hpre : ∀ H v, pre' H v → pre H v)
    (hpost : ∀ H v b, pre' H v → post H v b → post' H v b) :
    SliceSpec Lq tag key domain shape c (p.andThen f) base len nQ nTrK nT nL nN st₀ stOut trees
      (spliceSched (base + len₁) sched₁ sched₂) pre' post' :=
  (h1.andThen h2 hdisj).congr hlen hnQ hnTrK hnT hnL hnN
    (TrChainState.ext hst.1 hst.2.1 hst.2.2) htrees hpre hpost

/-- Standard "chain tip at `base + n - 1`" state (`n ≥ 1`, `afterPosTag = false`). -/
def trChainTip (base n : ℕ) (hn : 0 < n) : TrChainState (base + n) :=
  ⟨true, base + n - 1, fun _ => by omega, false, fun h => by cases h⟩

/-- Advance `TrChainState` by `n` steps keeping `st` unchanged when `n = 0` or moving tip to `base + n - 1`. -/
def trChainAfterVec (base : ℕ) (st : TrChainState base) (n : ℕ) : TrChainState (base + n) :=
  if hn : n = 0 then ⟨st.hasTip, st.trTip, fun h => by have := st.htip_lt h; omega, st.afterPosTag, st.hpos⟩
  else trChainTip base n (Nat.pos_of_ne_zero hn)

/-- **Single fixed-1-point absorb slice (`trAbsorbKeyed`)**: unconditional `KCount 1 0 0` for any `t`,
advances `trTip := base`, clears `afterPosTag`. -/
theorem trAbsorbSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (t : Tr)
    (label : List UInt8) (hlab64 : label.length ≤ 64) (hlabNe : label ≠ abLabShape)
    (data : List UInt8) (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) :
    SliceSpec Lq tag key domain shape c
      (trAbsorbKeyed Lq hL20 key t label hlab64 data)
      base 1 1 1 1 0 0 st (trChainTip base 1 Nat.zero_lt_one) (fun _ => False) (fun _ => .absorb st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v t' => t'.key = key ∧ t'.state = v base) := by
  have hlt64 : label.length < 2 ^ 64 := lt_of_le_of_lt hlab64 (by norm_num)
  refine
    { hptLen := trAbsorbKeyed_ptLen Lq hL20 key t label hlab64 data
      hqLE := (trAbsorbKeyed_purePt Lq hL20 key t label hlab64 data).2.1
      hdepStrict := (trAbsorbKeyed_purePt Lq hL20 key t label hlab64 data).2.2.1
      hdepIn := (trAbsorbKeyed_purePt Lq hL20 key t label hlab64 data).2.2.2 _
      hkCount := trAbsorbKeyed_kCount Lq hL20 hsep t label hlab64 data
      hstep := fun _ => ⟨rfl, by dsimp only [trChainTip]; have := st.htip_lt htip; omega,
        fun _ => Or.inl (by dsimp only [trChainTip]; omega)⟩
      hcntT := by simp [RawPtSpec.kind]
      hcntL := by simp [RawPtSpec.kind]
      hcntN := by simp [RawPtSpec.kind]
      hleaf_tree := fun _ _ _ _ h => by cases h
      hleaf_inj := fun _ _ _ _ _ _ _ _ h => by cases h
      hnode_bounds := fun _ _ _ _ _ h => by cases h
      hnode_inj := fun _ _ _ _ _ _ _ _ _ _ h => by cases h
      htr_lt := fun j h1 h2 _ => by have := st.htip_lt htip; dsimp only [RawPtSpec.trM]; omega
      htr_entry := fun j h1 h2 _ _ => by
        cases st.afterPosTag with
        | false => exact le_rfl
        | true => exact Or.inl ⟨le_rfl, rfl⟩
      htr_exit := fun i h1 h2 _ => ⟨rfl, by simp only [trChainTip, ↓reduceIte]; omega⟩
      htr_internal := fun i j h1 hij h2 => by omega
      hpt_match := fun H v j hpre h1 h2 => by
        have hjb : j = base := by omega
        subst hjb
        refine ⟨_, trAbsorbKeyed_ptAt Lq hL20 key t label hlab64 data H v j, ?_⟩
        refine ⟨label, fitBytes Lq label data, by rw [← hpre]; exact fitBytes_fit Lq hL20 t.state label data hlab64,
          hlabNe, hlt64, ?_⟩
        exact Prod.ext rfl (Subtype.ext (congrArg (fun d => absorbMsg d label (fitBytes Lq label data)) hpre))
      hpost := fun H v _ => ⟨rfl, rfl⟩ }

/-- **Single fixed-1-point squeeze slice (`trSqueezeKeyed`)**: unconditional `KCount 1 0 0` for any `t`,
requires `st.afterPosTag = false`, advances `trTip := base`. -/
theorem trSqueezeSliceSpec {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (trSqueezeKeyed Lq h47 key t)
      base 1 1 1 1 0 0 st (trChainTip base 1 Nat.zero_lt_one) (fun _ => False) (fun _ => .squeeze st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = v base ∧ r.2.key = key ∧ r.2.state = v base) := by
  refine
    { hptLen := trSqueezeKeyed_ptLen Lq h47 key t
      hqLE := (trSqueezeKeyed_purePt Lq h47 key t).2.1
      hdepStrict := (trSqueezeKeyed_purePt Lq h47 key t).2.2.1
      hdepIn := (trSqueezeKeyed_purePt Lq h47 key t).2.2.2 _
      hkCount := trSqueezeKeyed_kCount Lq h47 hsep t
      hstep := fun _ => ⟨rfl, by dsimp only [trChainTip]; have := st.htip_lt htip; omega,
        fun hp => by rw [hnoPos] at hp; cases hp⟩
      hcntT := by simp [RawPtSpec.kind]
      hcntL := by simp [RawPtSpec.kind]
      hcntN := by simp [RawPtSpec.kind]
      hleaf_tree := fun _ _ _ _ h => by cases h
      hleaf_inj := fun _ _ _ _ _ _ _ _ h => by cases h
      hnode_bounds := fun _ _ _ _ _ h => by cases h
      hnode_inj := fun _ _ _ _ _ _ _ _ _ _ h => by cases h
      htr_lt := fun j h1 h2 _ => by have := st.htip_lt htip; dsimp only [RawPtSpec.trM]; omega
      htr_entry := fun j h1 h2 _ _ => by rw [hnoPos]; exact le_rfl
      htr_exit := fun i h1 h2 _ => ⟨rfl, by simp only [trChainTip, ↓reduceIte]; omega⟩
      htr_internal := fun i j h1 hij h2 => by omega
      hpt_match := fun H v j hpre h1 h2 => by
        have hjb : j = base := by omega
        subst hjb
        refine ⟨_, trSqueezeKeyed_ptAt Lq h47 key t H v j, t.counter, by rw [squeezeMsg_length]; exact h47, ?_⟩
        exact Prod.ext rfl (Subtype.ext (by rw [hpre]))
      hpost := fun H v _ => ⟨rfl, rfl, rfl⟩ }

/-- **`trChallengeFp2Keyed` slice (`1` `.squeeze`)**. -/
theorem trChallengeFp2SliceSpec {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (trChallengeFp2Keyed Lq h47 key t)
      base 1 1 1 1 0 0 st (trChainTip base 1 Nat.zero_lt_one) (fun _ => False)
      (spliceSched (base + 1) (fun _ => .squeeze st.trTip) (fun _ => .absorb 0))
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = challengeFp2Of (v base) ∧ r.2.key = key ∧ r.2.state = v base) :=
  ((trSqueezeSliceSpec h47 hsep domain shape c t base st htip hnoPos).andThen
    (fun r => retSliceSpec (challengeFp2Of r.1, r.2) (base + 1) (trChainTip base 1 Nat.zero_lt_one)
      (fun _ v => r.1 = v base ∧ r.2.key = key ∧ r.2.state = v base)
      (fun _ v res => res.1 = challengeFp2Of (v base) ∧ res.2.key = key ∧ res.2.state = v base)
      (fun _ _ hr => ⟨congrArg challengeFp2Of hr.1, hr.2.1, hr.2.2⟩))
    (fun _ hf => False.elim hf)).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
    (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ h => h) (fun _ _ _ _ h => h)

/-- Schedule for `n` consecutive squeezes starting at `base` from `st.trTip`. -/
def squeezeVecSched (base tip : ℕ) (j : ℕ) : RawPtSpec :=
  if j = base then .squeeze tip else .squeeze (j - 1)

/-- **`trSqueezeVecKeyed` slice (`n` `.squeeze`s)**: `res` returns `[v base, ..., v (base+n-1)]`! -/
theorem trSqueezeVecSliceSpec {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins) :
    ∀ (n : ℕ) (t : Tr) (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false),
    SliceSpec Lq tag key domain shape c
      (trSqueezeVecKeyed Lq h47 key n t)
      base n n n n 0 0 st (trChainAfterVec base st n) (fun _ => False) (squeezeVecSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = (List.range n).map (fun k => v (base + k))
        ∧ r.2.state = v (trChainAfterVec base st n).trTip)
  | 0, t, base, st, htip, hnoPos =>
    (retSliceSpec ([], t) base st
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = [] ∧ r.2.state = v st.trTip)
      (fun _ _ hp => ⟨rfl, hp⟩) (squeezeVecSched base st.trTip)).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec])
      (fun _ h => h) (fun _ _ h => h)
      (fun _ _ r _ hr => ⟨hr.1, by simp only [trChainAfterVec, ↓reduceDIte]; exact hr.2⟩)
  | n + 1, t, base, st, htip, hnoPos => by
    let st1 := trChainTip base 1 Nat.zero_lt_one
    have h1 := trSqueezeSliceSpec h47 hsep domain shape c t base st htip hnoPos
    have h2 : ∀ r : Dig × Tr,
        SliceSpec Lq tag key domain shape c
          ((trSqueezeVecKeyed Lq h47 key n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2))
          (base + 1) n n n n 0 0 st1 (trChainAfterVec (base + 1) st1 n) (fun _ => False)
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0))
          (fun _ v => r.1 = v base ∧ r.2.key = key ∧ r.2.state = v base)
          (fun _ v res => res.1 = (List.range (n + 1)).map (fun k => v (base + k))
            ∧ res.2.state = v (trChainTip base (n + 1) (Nat.succ_pos n)).trTip) := by
      intro r
      have ih := trSqueezeVecSliceSpec h47 hsep domain shape c n r.2 (base + 1) st1 rfl rfl
      have htipEq : (trChainAfterVec (base + 1) st1 n).trTip = base + n := by
        unfold trChainAfterVec trChainTip st1
        by_cases hn : n = 0
        · rw [dite_eq_left hn]; dsimp only [trChainTip]; omega
        · rw [dite_eq_right hn]; dsimp only [trChainTip]; omega
      have hcomb := ih.andThen
        (fun rs => retSliceSpec (r.1 :: rs.1, rs.2) (base + 1 + n) (trChainAfterVec (base + 1) st1 n)
          (fun _ v => rs.1 = (List.range n).map (fun k => v (base + 1 + k))
            ∧ rs.2.state = v (trChainAfterVec (base + 1) st1 n).trTip)
          (fun _ v res => res.1 = r.1 :: (List.range n).map (fun k => v (base + 1 + k))
            ∧ res.2.state = v (base + n))
          (fun _ v hrs => ⟨congrArg (r.1 :: ·) hrs.1, by rw [← htipEq]; exact hrs.2⟩))
        (fun _ hf => False.elim hf)
      exact hcomb.congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        (TrChainState.ext rfl rfl rfl)
        (fun _ h => by rcases h with h | h <;> exact h)
        (fun _ _ hp => hp.2.2)
        (fun _ v res hp hrs => by
          refine ⟨?_, ?_⟩
          · rw [hrs.1, hp.1, List.range_succ_eq_map, List.map_cons, List.map_map]
            exact congrArg (v base :: ·) (List.map_congr_left fun k _ => by
              show v (base + 1 + k) = v (base + (k + 1)); congr 1; omega)
          · exact hrs.2)
    have hcomp : SliceSpec Lq tag key domain shape c
        (trSqueezeVecKeyed Lq h47 key (n + 1) t)
        base (n + 1) (n + 1) (n + 1) (n + 1) 0 0 st (trChainAfterVec base st (n + 1)) (fun _ => False)
        (spliceSched (base + 1) (fun _ => .squeeze st.trTip)
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0)))
        (fun _ v => t.state = v st.trTip)
        (fun _ v r => r.1 = (List.range (n + 1)).map (fun k => v (base + k))
          ∧ r.2.state = v (trChainAfterVec base st (n + 1)).trTip) :=
      h1.seq h2 (fun _ hf => False.elim hf)
        (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        ⟨by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn],
         by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn] <;> omega,
         by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn]⟩
        (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
        (fun _ _ res _ hr => ⟨hr.1, by simp only [trChainAfterVec, Nat.succ_ne_zero, ↓reduceDIte]; exact hr.2⟩)
    -- Replace spliced schedule by clean `squeezeVecSched base st.trTip` (identical on `[base, base + n + 1)`)
    have hEqSched : ∀ j, base ≤ j → j < base + (n + 1) →
        spliceSched (base + 1) (fun _ => .squeeze st.trTip)
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0)) j
          = squeezeVecSched base st.trTip j := by
      intro j h1' h2'
      unfold spliceSched squeezeVecSched
      by_cases hjb : j = base
      · subst hjb; rw [ite_eq_left (Nat.lt_succ_self j), ite_eq_left rfl]
      · rw [ite_eq_right (by omega : ¬ j < base + 1), ite_eq_left (by omega : j < base + 1 + n),
          ite_eq_right hjb]
        by_cases hj1 : j = base + 1
        · subst hj1; rw [ite_eq_left rfl]; simp
        · rw [ite_eq_right hj1]
    refine
      { hptLen := hcomp.hptLen
        hqLE := hcomp.hqLE
        hdepStrict := hcomp.hdepStrict
        hdepIn := hcomp.hdepIn
        hkCount := hcomp.hkCount
        hstep := hcomp.hstep
        hcntT := by
          have hle := Finset.card_filter_le (Finset.range (n + 1)) (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .tr)
          rwa [Finset.card_range] at hle
        hcntL := by
          have hemp : (Finset.range (n + 1)).filter (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .leaf) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold squeezeVecSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hcntN := by
          have hemp : (Finset.range (n + 1)).filter (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .node) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold squeezeVecSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hleaf_tree := fun j _ h1' h2' hs => by rw [← hEqSched j h1' h2'] at hs; exact hcomp.hleaf_tree j _ h1' h2' hs
        hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hleaf_inj i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij
        hnode_bounds := fun j L R h1' h2' hs => by
          rw [← hEqSched j h1' h2'] at hs; exact hcomp.hnode_bounds j L R h1' h2' hs
        hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hnode_inj i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij
        htr_lt := fun j h1' h2' htr => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_lt j h1' h2' htr
        htr_entry := fun j h1' h2' htr ht => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_entry j h1' h2' htr ht
        htr_exit := fun i h1' h2' htr => by
          rw [← hEqSched i h1' h2'] at htr ⊢; exact hcomp.htr_exit i h1' h2' htr
        htr_internal := fun i j hi1 hij hj2 hti htj => by
          rw [← hEqSched i hi1 (by omega)] at hti ⊢; rw [← hEqSched j (by omega) hj2] at htj ⊢
          exact hcomp.htr_internal i j hi1 hij hj2 hti htj
        hpt_match := fun H v j hp h1' h2' => by
          rw [← hEqSched j h1' h2']; exact hcomp.hpt_match H v j hp h1' h2'
        hpost := hcomp.hpost }

/-- **`trChallengeFp2VecKeyed` slice (`n` `.squeeze`s)**: `res` returns `[(challengeFp2Of (v (base+k))) | k < n]`! -/
theorem trChallengeFp2VecSliceSpec {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins) :
    ∀ (n : ℕ) (t : Tr) (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false),
    SliceSpec Lq tag key domain shape c
      (trChallengeFp2VecKeyed Lq h47 key n t)
      base n n n n 0 0 st (trChainAfterVec base st n) (fun _ => False) (squeezeVecSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = (List.range n).map (fun k => challengeFp2Of (v (base + k)))
        ∧ r.2.state = v (trChainAfterVec base st n).trTip)
  | 0, t, base, st, htip, hnoPos =>
    (retSliceSpec ([], t) base st
      (fun _ v => t.state = v st.trTip)
      (fun _ v r => r.1 = [] ∧ r.2.state = v st.trTip)
      (fun _ _ hp => ⟨rfl, hp⟩) (squeezeVecSched base st.trTip)).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec])
      (fun _ h => h) (fun _ _ h => h)
      (fun _ _ r _ hr => ⟨hr.1, by simp only [trChainAfterVec, ↓reduceDIte]; exact hr.2⟩)
  | n + 1, t, base, st, htip, hnoPos => by
    let st1 := trChainTip base 1 Nat.zero_lt_one
    have h1 := trChallengeFp2SliceSpec h47 hsep domain shape c t base st htip hnoPos
    have h2 : ∀ r : Fp2 × Tr,
        SliceSpec Lq tag key domain shape c
          ((trChallengeFp2VecKeyed Lq h47 key n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2))
          (base + 1) n n n n 0 0 st1 (trChainAfterVec (base + 1) st1 n) (fun _ => False)
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0))
          (fun _ v => r.1 = challengeFp2Of (v base) ∧ r.2.key = key ∧ r.2.state = v base)
          (fun _ v res => res.1 = (List.range (n + 1)).map (fun k => challengeFp2Of (v (base + k)))
            ∧ res.2.state = v (trChainTip base (n + 1) (Nat.succ_pos n)).trTip) := by
      intro r
      have ih := trChallengeFp2VecSliceSpec h47 hsep domain shape c n r.2 (base + 1) st1 rfl rfl
      have htipEq : (trChainAfterVec (base + 1) st1 n).trTip = base + n := by
        unfold trChainAfterVec trChainTip st1
        by_cases hn : n = 0
        · rw [dite_eq_left hn]; dsimp only [trChainTip]; omega
        · rw [dite_eq_right hn]; dsimp only [trChainTip]; omega
      have hcomb := ih.andThen
        (fun rs => retSliceSpec (r.1 :: rs.1, rs.2) (base + 1 + n) (trChainAfterVec (base + 1) st1 n)
          (fun _ v => rs.1 = (List.range n).map (fun k => challengeFp2Of (v (base + 1 + k)))
            ∧ rs.2.state = v (trChainAfterVec (base + 1) st1 n).trTip)
          (fun _ v res => res.1 = r.1 :: (List.range n).map (fun k => challengeFp2Of (v (base + 1 + k)))
            ∧ res.2.state = v (base + n))
          (fun _ v hrs => ⟨congrArg (r.1 :: ·) hrs.1, by rw [← htipEq]; exact hrs.2⟩))
        (fun _ hf => False.elim hf)
      exact hcomb.congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        (TrChainState.ext rfl rfl rfl)
        (fun _ h => by rcases h with h | h <;> exact h)
        (fun _ _ hp => hp.2.2)
        (fun _ v res hp hrs => by
          refine ⟨?_, ?_⟩
          · rw [hrs.1, hp.1, List.range_succ_eq_map, List.map_cons, List.map_map]
            exact congrArg (challengeFp2Of (v base) :: ·) (List.map_congr_left fun k _ => by
              show challengeFp2Of (v (base + 1 + k)) = challengeFp2Of (v (base + (k + 1))); congr 2; omega)
          · exact hrs.2)
    have hcomp : SliceSpec Lq tag key domain shape c
        (trChallengeFp2VecKeyed Lq h47 key (n + 1) t)
        base (n + 1) (n + 1) (n + 1) (n + 1) 0 0 st (trChainAfterVec base st (n + 1)) (fun _ => False)
        (spliceSched (base + 1) (spliceSched (base + 1) (fun _ => .squeeze st.trTip) (fun _ => .absorb 0))
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0)))
        (fun _ v => t.state = v st.trTip)
        (fun _ v r => r.1 = (List.range (n + 1)).map (fun k => challengeFp2Of (v (base + k)))
          ∧ r.2.state = v (trChainAfterVec base st (n + 1)).trTip) :=
      h1.seq h2 (fun _ hf => False.elim hf)
        (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        ⟨by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn],
         by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn] <;> omega,
         by unfold st1 trChainAfterVec trChainTip; by_cases hn : n = 0 <;> simp [hn]⟩
        (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
        (fun _ _ res _ hr => ⟨hr.1, by simp only [trChainAfterVec, Nat.succ_ne_zero, ↓reduceDIte]; exact hr.2⟩)
    have hEqSched : ∀ j, base ≤ j → j < base + (n + 1) →
        spliceSched (base + 1) (spliceSched (base + 1) (fun _ => .squeeze st.trTip) (fun _ => .absorb 0))
          (spliceSched (base + 1 + n) (squeezeVecSched (base + 1) base) (fun _ => .absorb 0)) j
          = squeezeVecSched base st.trTip j := by
      intro j h1' h2'
      unfold spliceSched squeezeVecSched
      by_cases hjb : j = base
      · subst hjb; rw [ite_eq_left (Nat.lt_succ_self j), ite_eq_left (Nat.lt_succ_self j), ite_eq_left rfl]
      · rw [ite_eq_right (by omega : ¬ j < base + 1), ite_eq_left (by omega : j < base + 1 + n),
          ite_eq_right hjb]
        by_cases hj1 : j = base + 1
        · subst hj1; rw [ite_eq_left rfl]; simp
        · rw [ite_eq_right hj1]
    refine
      { hptLen := hcomp.hptLen
        hqLE := hcomp.hqLE
        hdepStrict := hcomp.hdepStrict
        hdepIn := hcomp.hdepIn
        hkCount := hcomp.hkCount
        hstep := hcomp.hstep
        hcntT := by
          have hle := Finset.card_filter_le (Finset.range (n + 1)) (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .tr)
          rwa [Finset.card_range] at hle
        hcntL := by
          have hemp : (Finset.range (n + 1)).filter (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .leaf) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold squeezeVecSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hcntN := by
          have hemp : (Finset.range (n + 1)).filter (fun k => (squeezeVecSched base st.trTip (base + k)).kind = .node) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold squeezeVecSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hleaf_tree := fun j _ h1' h2' hs => by rw [← hEqSched j h1' h2'] at hs; exact hcomp.hleaf_tree j _ h1' h2' hs
        hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hleaf_inj i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij
        hnode_bounds := fun j L R h1' h2' hs => by
          rw [← hEqSched j h1' h2'] at hs; exact hcomp.hnode_bounds j L R h1' h2' hs
        hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hnode_inj i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij
        htr_lt := fun j h1' h2' htr => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_lt j h1' h2' htr
        htr_entry := fun j h1' h2' htr ht => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_entry j h1' h2' htr ht
        htr_exit := fun i h1' h2' htr => by
          rw [← hEqSched i h1' h2'] at htr ⊢; exact hcomp.htr_exit i h1' h2' htr
        htr_internal := fun i j hi1 hij hj2 hti htj => by
          rw [← hEqSched i hi1 (by omega)] at hti ⊢; rw [← hEqSched j (by omega) hj2] at htj ⊢
          exact hcomp.htr_internal i j hi1 hij hj2 hti htj
        hpt_match := fun H v j hp h1' h2' => by
          rw [← hEqSched j h1' h2']; exact hcomp.hpt_match H v j hp h1' h2'
        hpost := hcomp.hpost }

/-- **`posTagKeyed` slice (`2` `.squeeze`s, ZERO `sorry`)**: preserves `trTip` and sets `afterPosTag := true`,
leaving the main transcript `t` untouched! -/
theorem posTagSliceSpec {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    let stOut : TrChainState (base + 2) := ⟨true, st.trTip, fun _ => by have := st.htip_lt htip; omega, true, fun _ => rfl⟩
    let sched : ℕ → RawPtSpec := fun j => if j = base then .squeeze st.trTip else .squeeze base
    SliceSpec Lq tag key domain shape c
      (posTagKeyed Lq h47 key t)
      base 2 2 2 2 0 0 st stOut (fun _ => False) sched
      (fun _ v => t.state = v st.trTip)
      (fun _ v dg => dg = ⟨(challengeFp2Of (v base)).toBytes ++ (challengeFp2Of (v (base + 1))).toBytes,
        by simp [Exec.Block.fp2_toBytes_length]⟩) := by
  intro stOut sched
  let st1 := trChainTip base 1 Nat.zero_lt_one
  have h1 := trChallengeFp2SliceSpec h47 hsep domain shape c t base st htip hnoPos
  have h2 : ∀ a : Fp2 × Tr,
      SliceSpec Lq tag key domain shape c
        ((trChallengeFp2Keyed Lq h47 key a.2).andThen fun b =>
          .ret (⟨a.1.toBytes ++ b.1.toBytes, by simp [Exec.Block.fp2_toBytes_length]⟩ : Dig))
        (base + 1) 1 1 1 1 0 0 st1 (trChainTip (base + 1) 1 Nat.zero_lt_one)
        (fun _ => False) (spliceSched (base + 2) (spliceSched (base + 2) (fun _ => .squeeze base) (fun _ => .absorb 0)) (fun _ => .absorb 0))
        (fun _ v => a.1 = challengeFp2Of (v base) ∧ a.2.key = key ∧ a.2.state = v base)
        (fun _ v dg => dg = (⟨(challengeFp2Of (v base)).toBytes ++ (challengeFp2Of (v (base + 1))).toBytes,
          by simp [Exec.Block.fp2_toBytes_length]⟩ : Dig)) := by
    intro a
    have hch := trChallengeFp2SliceSpec h47 hsep domain shape c a.2 (base + 1) st1 rfl rfl
    exact (hch.andThen
      (fun b => retSliceSpec (⟨a.1.toBytes ++ b.1.toBytes, by simp [Exec.Block.fp2_toBytes_length]⟩ : Dig)
        (base + 1 + 1) (trChainTip (base + 1) 1 Nat.zero_lt_one)
        (fun _ v => b.1 = challengeFp2Of (v (base + 1)) ∧ b.2.key = key ∧ b.2.state = v (base + 1))
        (fun _ v dg => dg = (⟨a.1.toBytes ++ (challengeFp2Of (v (base + 1))).toBytes,
          by simp [Exec.Block.fp2_toBytes_length]⟩ : Dig))
        (fun _ v hb => by apply Subtype.ext; simp [hb.1]))
      (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      (TrChainState.ext rfl rfl rfl)
      (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2.2)
      (fun _ v dg hp hdg => by rw [hdg]; apply Subtype.ext; simp [hp.1])
  have hcomb := h1.andThen h2 (fun _ hf => False.elim hf)
  refine
    { hptLen := hcomb.hptLen
      hqLE := hcomb.hqLE
      hdepStrict := hcomb.hdepStrict
      hdepIn := hcomb.hdepIn
      hkCount := hcomb.hkCount
      hstep := fun _ => ⟨rfl, le_rfl, fun hp => by rw [hnoPos] at hp; cases hp⟩
      hcntT := by
        have hle := Finset.card_filter_le (Finset.range 2) (fun k => (sched (base + k)).kind = .tr)
        rwa [Finset.card_range] at hle
      hcntL := by
        have hemp : (Finset.range 2).filter (fun k => (sched (base + k)).kind = .leaf) = ∅ := by
          refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
          dsimp only [sched] at hk; split_ifs at hk <;> cases hk
        rw [hemp, Finset.card_empty]
      hcntN := by
        have hemp : (Finset.range 2).filter (fun k => (sched (base + k)).kind = .node) = ∅ := by
          refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
          dsimp only [sched] at hk; split_ifs at hk <;> cases hk
        rw [hemp, Finset.card_empty]
      hleaf_tree := fun j _ _ _ hs => by dsimp only [sched] at hs; split_ifs at hs <;> cases hs
      hleaf_inj := fun i _ _ _ _ _ _ _ hs => by dsimp only [sched] at hs; split_ifs at hs <;> cases hs
      hnode_bounds := fun j _ _ _ _ hs => by dsimp only [sched] at hs; split_ifs at hs <;> cases hs
      hnode_inj := fun i _ _ _ _ _ _ _ _ _ hs => by dsimp only [sched] at hs; split_ifs at hs <;> cases hs
      htr_lt := fun j h1' h2' _ => by
        dsimp only [sched]
        by_cases hjb : j = base
        · rw [ite_eq_left hjb]; have := st.htip_lt htip; dsimp only [RawPtSpec.trM]; omega
        · rw [ite_eq_right hjb]; dsimp only [RawPtSpec.trM]; omega
      htr_entry := fun j h1' h2' _ _ => by
        rw [hnoPos]; simp only [↓reduceIte]; dsimp only [sched]
        by_cases hjb : j = base
        · rw [ite_eq_left hjb]; exact le_rfl
        · rw [ite_eq_right hjb]; have := st.htip_lt htip; dsimp only [RawPtSpec.trM]; omega
      htr_exit := fun i _ _ _ => ⟨rfl, Or.inr (by dsimp only [sched]; split_ifs <;> rfl)⟩
      htr_internal := fun i j h1' hij h2' _ _ => by
        have hi : i = base := by omega
        have hj : j = base + 1 := by omega
        subst hi hj; dsimp only [sched]
        rw [ite_eq_right (by omega : i + 1 ≠ i)]; exact Or.inl le_rfl
      hpt_match := fun H v j hp h1' h2' => by
        obtain ⟨q, hpt, hmat⟩ := hcomb.hpt_match H v j hp h1' h2'
        refine ⟨q, hpt, ?_⟩
        unfold spliceSched at hmat
        by_cases hjb : j = base
        · subst hjb
          rw [ite_eq_left (Nat.lt_succ_self j), ite_eq_left (Nat.lt_succ_self j)] at hmat
          dsimp only [sched]; rw [ite_eq_left rfl]; exact hmat
        · rw [ite_eq_right (by omega : ¬ j < base + 1), ite_eq_left (by omega : j < base + 2),
            ite_eq_left (by omega : j < base + 2)] at hmat
          dsimp only [sched]; rw [ite_eq_right hjb]; exact hmat
      hpost := hcomb.hpost }

/-- **Keyed `absorbRoot` (`3` `.absorb`s: `label`, `labRows`, `labLogCols`)**. -/
def absorbRootKeyed (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (root : Dig) (rows logCols : ℕ) : PProg (QB Lq) Dig Tr :=
  (trAbsorbKeyed Lq hL20 key t label hlab root.toList).andThen fun t1 =>
  (trAbsorbKeyed Lq hL20 key t1 labRows (by decide) (le64 (UInt64.ofNat rows))).andThen fun t2 =>
  trAbsorbKeyed Lq hL20 key t2 labLogCols (by decide) (le64 (UInt64.ofNat logCols))

theorem absorbRootKeyed_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr) (htKey : t.key = key)
    (label : List UInt8) (hlab : label.length ≤ 64) (root : Dig) (rows logCols : ℕ) (G : QB Lq → Dig) :
    (absorbRootKeyed Lq hL20 key t label hlab root rows logCols).run G =
      Exec.Block.absorbRoot (liftH G) t label root rows logCols := by
  unfold absorbRootKeyed Exec.Block.absorbRoot Tr.absorbU64
  have hlenR : labRows.length = 4 := by decide
  have hlenC : labLogCols.length = 8 := by decide
  have ht1 : (t.absorb (liftH G) label root.toList).key = key := htKey
  have ht2 : ((t.absorb (liftH G) label root.toList).absorb (liftH G) labRows (le64 (UInt64.ofNat rows))).key = key := htKey
  rw [PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key t htKey label hlab root.toList
      (by rw [List.Vector.toList_length]; omega) G,
    PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key (t.absorb (liftH G) label root.toList) ht1 labRows (by decide) _
      (by rw [le64_length]; omega) G,
    trAbsorbKeyed_run Lq hL20 key _ ht2 labLogCols (by decide) _
      (by rw [le64_length]; omega) G]

/-- Static 3-point schedule of `absorbRootKeyed` starting at `base` from incoming tip `tip`. -/
def absorbRootSched (base tip : ℕ) : ℕ → RawPtSpec :=
  spliceSched (base + 1) (fun _ => .absorb tip)
    (spliceSched (base + 2) (fun _ => .absorb base) (fun _ => .absorb (base + 1)))

theorem absorbRootSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins) (t : Tr)
    (label : List UInt8) (hlab64 : label.length ≤ 64) (hlabNe : label ≠ abLabShape)
    (root : Dig) (rows logCols : ℕ) (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) :
    SliceSpec Lq tag key domain shape c
      (absorbRootKeyed Lq hL20 key t label hlab64 root rows logCols)
      base 3 3 3 3 0 0 st (trChainTip base 3 (by norm_num)) (fun _ => False) (absorbRootSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v t' => t'.key = key ∧ t'.state = v (base + 2)) := by
  unfold absorbRootSched
  let st1 := trChainTip base 1 Nat.zero_lt_one
  have h1 := trAbsorbSliceSpec hL20 hsep domain shape c t label hlab64 hlabNe root.toList base st htip
  have h23 : ∀ t1 : Tr,
      SliceSpec Lq tag key domain shape c
        ((trAbsorbKeyed Lq hL20 key t1 labRows (by decide) (le64 (UInt64.ofNat rows))).andThen fun t2 =>
          trAbsorbKeyed Lq hL20 key t2 labLogCols (by decide) (le64 (UInt64.ofNat logCols)))
        (base + 1) 2 2 2 2 0 0 st1 ((trChainTip base 3 (by norm_num)).cast (by omega))
        (fun _ => False) (spliceSched (base + 2) (fun _ => .absorb base) (fun _ => .absorb (base + 1)))
        (fun _ v => t1.key = key ∧ t1.state = v base)
        (fun _ v t' => t'.key = key ∧ t'.state = v (base + 2)) := by
    intro t1
    have h2 := trAbsorbSliceSpec hL20 hsep domain shape c t1 labRows (by decide) (by decide)
      (le64 (UInt64.ofNat rows)) (base + 1) st1 rfl
    have h3 : ∀ t2 : Tr, SliceSpec Lq tag key domain shape c
        (trAbsorbKeyed Lq hL20 key t2 labLogCols (by decide) (le64 (UInt64.ofNat logCols)))
        (base + 1 + 1) 1 1 1 1 0 0 (trChainTip (base + 1) 1 Nat.zero_lt_one)
        (trChainTip (base + 1 + 1) 1 Nat.zero_lt_one) (fun _ => False) (fun _ => .absorb (base + 1))
        (fun _ v => t2.key = key ∧ t2.state = v (base + 1))
        (fun _ v t' => t'.key = key ∧ t'.state = v (base + 2)) := fun t2 =>
      (trAbsorbSliceSpec hL20 hsep domain shape c t2 labLogCols (by decide) (by decide)
        (le64 (UInt64.ofNat logCols)) (base + 1 + 1) (trChainTip (base + 1) 1 Nat.zero_lt_one) rfl).congr
        rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2)
        (fun _ _ t' _ ht' => ⟨ht'.1, by simpa [Nat.add_assoc] using ht'.2⟩)
    exact (h2.andThen h3 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      (TrChainState.ext rfl rfl rfl)
      (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ ht => ht)
  exact (h1.andThen h23 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    (TrChainState.ext rfl rfl rfl)
    (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ ht => ht)

/-- **Fixed-schedule run header `PProg` (`shdP_hdrPProgF`)**:
identical to `shdP_hdrPProg`, using `trAbsorbKeyed` for the 6 tail absorbs so `PtLen 7`, `QLE 9`,
`DepStrict`, `DepIn ShdRunDepSet`, and `KCount 9 0 0` all hold unconditionally! -/
def shdP_hdrPProgF (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) : PProg (QB Lq) Dig Tr :=
  have hdom : (startMsg shdP_runDomain).length ≤ Lq := shdP_runDomain_start_le hL20
  have hsh : ∀ d₀ : Dig, (absorbMsg d₀ abLabShape w.shape).length ≤ Lq := fun d₀ => by
    rw [absorbMsg_length_eq]
    have : abLabShape.length = 9 := by decide
    omega
  have hexp : ∀ d₁ : Dig, (absorbMsg d₁ abLabExp (abExpMsg w.inDig inRoot)).length ≤ Lq := fun d₁ => by
    rw [absorbMsg_length_eq, abExpMsg_length]
    have : abLabExp.length = 11 := by decide
    omega
  .dep (key, ⟨startMsg shdP_runDomain, hdom⟩) fun d₀ =>
    .dep (key, ⟨absorbMsg d₀ abLabShape w.shape, hsh d₀⟩) fun d₁ =>
      .pt (key, ⟨absorbMsg d₁ abLabExp (abExpMsg w.inDig inRoot), hexp d₁⟩) fun d₂ =>
        (trAbsorbKeyed Lq hL20 key ⟨d₂, 0, key⟩ abLabPub (by decide) w.pubSt.toList).andThen fun t3 =>
        (trAbsorbKeyed Lq hL20 key t3 abLabPar (by decide) w.params).andThen fun t4 =>
        (trAbsorbKeyed Lq hL20 key t4 abLabCal (by decide) w.calib.toList).andThen fun t5 =>
        (trAbsorbKeyed Lq hL20 key t5 abLabSch (by decide) w.sched.toList).andThen fun t6 =>
        (trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
        trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk

theorem shdP_hdrPProgF_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) (G : QB Lq → Dig) :
    (shdP_hdrPProgF Lq hL20 key (hw hdr) hfit inRoot verdict).run G =
      clsStart shdP_runDomain key hw (liftH G) (honestStmt hdr inRoot verdict) := by
  unfold shdP_hdrPProgF clsStart clsHdrOf clsHdrOps honestStmt Tr.newKeyed
  dsimp only [PProg.run]
  have hlp : abLabPub.length = 16 := by decide
  have hlpa : abLabPar.length = 10 := by decide
  have hlc : abLabCal.length = 11 := by decide
  have hls : abLabSch.length = 8 := by decide
  have hlv : abLabVer.length = 16 := by decide
  have hlch : abLabChk.length = 14 := by decide
  rw [PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key _ rfl abLabPub (by decide) _
        (by rw [List.Vector.toList_length]; omega) G,
      PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key _ rfl abLabPar (by decide) _
        (by omega) G,
      PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key _ rfl abLabCal (by decide) _
        (by rw [List.Vector.toList_length]; omega) G,
      PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key _ rfl abLabSch (by decide) _
        (by rw [List.Vector.toList_length]; omega) G,
      PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key _ rfl abLabVer (by decide) _
        (by simp only [List.length_singleton]; omega) G,
      trAbsorbKeyed_run Lq hL20 key _ rfl abLabChk (by decide) _
        (by omega) G]
  have hlift : ∀ (k : Option Dig) (m : List UInt8) (hm : m.length ≤ Lq), G (k, ⟨m, hm⟩) = liftH G ⟨k, m⟩ :=
    fun k m hm => (liftH_eq G k m hm).symm
  simp only [hlift, runOps, Tr.absorb]

/-- Schedule for `shdP_hdrPProgF` starting at `base = 4095` right after `TE` (`inRoot = v 4094`). -/
def hdrSched (base inRootIdx : ℕ) (j : ℕ) : RawPtSpec :=
  if j = base then .absorbExp inRootIdx else .absorb (j - 1)

/-- **Header slice (`shdP_hdrPProgF`)**: `7` `.pt`s (`1` `absorbExp` + `6` `absorb`), `9` `QLE`, `9` `nTrK`,
starts from `st.hasTip = false` (after `TE`) and establishes `trChainTip base 7` (`trTip = base + 6`)! -/
theorem hdrSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (c : ShdCoins)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) (base inRootIdx : ℕ) (hrootLt : inRootIdx < base)
    (st : TrChainState base) (hnoTip : st.hasTip = false) :
    SliceSpec Lq tag key shdP_runDomain w.shape c
      (shdP_hdrPProgF Lq hL20 key w hfit inRoot verdict)
      base 7 9 9 7 0 0 st (trChainTip base 7 (by norm_num)) (fun _ => False) (hdrSched base inRootIdx)
      (fun _ v => inRoot = v inRootIdx)
      (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
  -- Build the 6-absorb tail slice starting at `base + 1`
  let st1 := trChainTip base 1 Nat.zero_lt_one
  let tailOf : Dig → PProg (QB Lq) Dig Tr := fun d₂ =>
    (trAbsorbKeyed Lq hL20 key ⟨d₂, 0, key⟩ abLabPub (by decide) w.pubSt.toList).andThen fun t3 =>
    (trAbsorbKeyed Lq hL20 key t3 abLabPar (by decide) w.params).andThen fun t4 =>
    (trAbsorbKeyed Lq hL20 key t4 abLabCal (by decide) w.calib.toList).andThen fun t5 =>
    (trAbsorbKeyed Lq hL20 key t5 abLabSch (by decide) w.sched.toList).andThen fun t6 =>
    (trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
    trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk
  have htail : ∀ d₂,
      SliceSpec Lq tag key shdP_runDomain w.shape c (tailOf d₂)
        (base + 1) 6 6 6 6 0 0 st1 (trChainTip (base + 1) 6 (by norm_num)) (fun _ => False)
        (fun j => .absorb (j - 1))
        (fun _ v => d₂ = v base)
        (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
    intro d₂
    have ha1 := trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c ⟨d₂, 0, key⟩ abLabPub (by decide) (by decide)
      w.pubSt.toList (base + 1) st1 rfl
    have ha2 : ∀ t3, SliceSpec Lq tag key shdP_runDomain w.shape c
        ((trAbsorbKeyed Lq hL20 key t3 abLabPar (by decide) w.params).andThen fun t4 =>
         (trAbsorbKeyed Lq hL20 key t4 abLabCal (by decide) w.calib.toList).andThen fun t5 =>
         (trAbsorbKeyed Lq hL20 key t5 abLabSch (by decide) w.sched.toList).andThen fun t6 =>
         (trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
         trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk)
        (base + 2) 5 5 5 5 0 0 (trChainTip (base + 1) 1 Nat.zero_lt_one)
        (trChainTip (base + 2) 5 (by norm_num)) (fun _ => False)
        (spliceSched (base + 3) (fun _ => .absorb (base + 1))
          (spliceSched (base + 4) (fun _ => .absorb (base + 2))
            (spliceSched (base + 5) (fun _ => .absorb (base + 3))
              (spliceSched (base + 6) (fun _ => .absorb (base + 4)) (fun _ => .absorb (base + 5))))))
        (fun _ v => t3.key = key ∧ t3.state = v (base + 1))
        (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
      intro t3
      have s2 := trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c t3 abLabPar (by decide) (by decide)
        w.params (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) rfl
      have s3 : ∀ t4, SliceSpec Lq tag key shdP_runDomain w.shape c
          ((trAbsorbKeyed Lq hL20 key t4 abLabCal (by decide) w.calib.toList).andThen fun t5 =>
           (trAbsorbKeyed Lq hL20 key t5 abLabSch (by decide) w.sched.toList).andThen fun t6 =>
           (trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
           trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk)
          (base + 3) 4 4 4 4 0 0 (trChainTip (base + 2) 1 Nat.zero_lt_one)
          (trChainTip (base + 3) 4 (by norm_num)) (fun _ => False)
          (spliceSched (base + 4) (fun _ => .absorb (base + 2))
            (spliceSched (base + 5) (fun _ => .absorb (base + 3))
              (spliceSched (base + 6) (fun _ => .absorb (base + 4)) (fun _ => .absorb (base + 5)))))
          (fun _ v => t4.key = key ∧ t4.state = v (base + 2))
          (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
        intro t4
        have c3 := trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c t4 abLabCal (by decide) (by decide)
          w.calib.toList (base + 3) (trChainTip (base + 2) 1 Nat.zero_lt_one) rfl
        have c4 : ∀ t5, SliceSpec Lq tag key shdP_runDomain w.shape c
            ((trAbsorbKeyed Lq hL20 key t5 abLabSch (by decide) w.sched.toList).andThen fun t6 =>
             (trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
             trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk)
            (base + 4) 3 3 3 3 0 0 (trChainTip (base + 3) 1 Nat.zero_lt_one)
            (trChainTip (base + 4) 3 (by norm_num)) (fun _ => False)
            (spliceSched (base + 5) (fun _ => .absorb (base + 3))
              (spliceSched (base + 6) (fun _ => .absorb (base + 4)) (fun _ => .absorb (base + 5))))
            (fun _ v => t5.key = key ∧ t5.state = v (base + 3))
            (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
          intro t5
          have d4 := trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c t5 abLabSch (by decide) (by decide)
            w.sched.toList (base + 4) (trChainTip (base + 3) 1 Nat.zero_lt_one) rfl
          have d5 : ∀ t6, SliceSpec Lq tag key shdP_runDomain w.shape c
              ((trAbsorbKeyed Lq hL20 key t6 abLabVer (by decide) [UInt8.ofNat verdict]).andThen fun t7 =>
               trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk)
              (base + 5) 2 2 2 2 0 0 (trChainTip (base + 4) 1 Nat.zero_lt_one)
              (trChainTip (base + 5) 2 (by norm_num)) (fun _ => False)
              (spliceSched (base + 6) (fun _ => .absorb (base + 4)) (fun _ => .absorb (base + 5)))
              (fun _ v => t6.key = key ∧ t6.state = v (base + 4))
              (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := by
            intro t6
            have e5 := trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c t6 abLabVer (by decide) (by decide)
              [UInt8.ofNat verdict] (base + 5) (trChainTip (base + 4) 1 Nat.zero_lt_one) rfl
            have e6 : ∀ t7, SliceSpec Lq tag key shdP_runDomain w.shape c
                (trAbsorbKeyed Lq hL20 key t7 abLabChk (by decide) w.chunk)
                (base + 5 + 1) 1 1 1 1 0 0 (trChainTip (base + 5) 1 Nat.zero_lt_one)
                (trChainTip (base + 5 + 1) 1 Nat.zero_lt_one) (fun _ => False) (fun _ => .absorb (base + 5))
                (fun _ v => t7.key = key ∧ t7.state = v (base + 5))
                (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) := fun t7 =>
              (trAbsorbSliceSpec hL20 hsep shdP_runDomain w.shape c t7 abLabChk (by decide) (by decide)
                w.chunk (base + 5 + 1) (trChainTip (base + 5) 1 Nat.zero_lt_one) rfl).congr
                rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2)
                (fun _ _ t' _ ht => ⟨ht.1, by simpa [Nat.add_assoc] using ht.2⟩)
            exact (e5.andThen e6 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
              (TrChainState.ext rfl rfl rfl) (fun _ h => by rcases h with h | h <;> exact h)
              (fun _ _ hp => hp.2) (fun _ _ _ _ ht => ht)
          exact (d4.andThen d5 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
            (TrChainState.ext rfl rfl rfl) (fun _ h => by rcases h with h | h <;> exact h)
            (fun _ _ hp => hp.2) (fun _ _ _ _ ht => ht)
        exact (c3.andThen c4 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
          (TrChainState.ext rfl rfl rfl) (fun _ h => by rcases h with h | h <;> exact h)
          (fun _ _ hp => hp.2) (fun _ _ _ _ ht => ht)
      exact (s2.andThen s3 (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        (TrChainState.ext rfl rfl rfl) (fun _ h => by rcases h with h | h <;> exact h)
        (fun _ _ hp => hp.2) (fun _ _ _ _ ht => ht)
    have hcomp : SliceSpec Lq tag key shdP_runDomain w.shape c (tailOf d₂)
        (base + 1) 6 6 6 6 0 0 st1 (trChainTip (base + 1) 6 (by norm_num)) (fun _ => False)
        (spliceSched (base + 1 + 1) (fun _ => RawPtSpec.absorb st1.trTip)
          (spliceSched (base + 3) (fun _ => RawPtSpec.absorb (base + 1))
            (spliceSched (base + 4) (fun _ => RawPtSpec.absorb (base + 2))
              (spliceSched (base + 5) (fun _ => RawPtSpec.absorb (base + 3))
                (spliceSched (base + 6) (fun _ => RawPtSpec.absorb (base + 4))
                  (fun _ => RawPtSpec.absorb (base + 5)))))))
        (fun _ v => d₂ = v base)
        (fun _ v t' => t'.key = key ∧ t'.state = v (base + 6)) :=
      ha1.seq ha2 (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h)
        (fun _ _ hp => hp) (fun _ _ _ _ ht => ht)
    refine
      { hptLen := hcomp.hptLen
        hqLE := hcomp.hqLE
        hdepStrict := hcomp.hdepStrict
        hdepIn := hcomp.hdepIn
        hkCount := hcomp.hkCount
        hstep := hcomp.hstep
        hcntT := by
          have hle := Finset.card_filter_le (Finset.range 6) (fun k => (RawPtSpec.absorb (base + 1 + k - 1)).kind = .tr)
          rwa [Finset.card_range] at hle
        hcntL := by simp [RawPtSpec.kind]
        hcntN := by simp [RawPtSpec.kind]
        hleaf_tree := fun _ _ _ _ h => by cases h
        hleaf_inj := fun _ _ _ _ _ _ _ _ h => by cases h
        hnode_bounds := fun _ _ _ _ _ h => by cases h
        hnode_inj := fun _ _ _ _ _ _ _ _ _ _ h => by cases h
        htr_lt := fun j h1 h2 _ => by dsimp only [RawPtSpec.trM]; omega
        htr_entry := fun j h1 h2 _ _ => by simp only [st1, trChainTip, RawPtSpec.trM, ↓reduceIte]; omega
        htr_exit := fun i h1 h2 _ => ⟨rfl, by simp only [trChainTip, ↓reduceIte]; omega⟩
        htr_internal := fun i j hi1 hij hj2 _ _ => Or.inl (by dsimp only [RawPtSpec.trM]; omega)
        hpt_match := fun H v j hp h1' h2' => by
          obtain ⟨q, hpt, hmat⟩ := hcomp.hpt_match H v j hp h1' h2'
          refine ⟨q, hpt, ?_⟩
          have hEq : spliceSched (base + 1 + 1) (fun _ => RawPtSpec.absorb st1.trTip)
              (spliceSched (base + 3) (fun _ => RawPtSpec.absorb (base + 1))
                (spliceSched (base + 4) (fun _ => RawPtSpec.absorb (base + 2))
                  (spliceSched (base + 5) (fun _ => RawPtSpec.absorb (base + 3))
                    (spliceSched (base + 6) (fun _ => RawPtSpec.absorb (base + 4))
                      (fun _ => RawPtSpec.absorb (base + 5)))))) j
              = RawPtSpec.absorb (j - 1) := by
            unfold spliceSched st1 trChainTip
            have hk : j = base + 1 ∨ j = base + 2 ∨ j = base + 3 ∨ j = base + 4 ∨ j = base + 5 ∨ j = base + 6 := by omega
            rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
            · rw [ite_eq_left (by omega)]
            · rw [ite_eq_right (by omega), ite_eq_left (by omega)]; congr 1; omega
            · rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]; congr 1; omega
            · rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]; congr 1; omega
            · rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]; congr 1; omega
            · rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]; congr 1; omega
          rwa [hEq] at hmat
        hpost := hcomp.hpost }
  -- Now wrap the 2 `.dep`s + `.pt abLabExp` around `tailOf`
  refine
    { hptLen := fun _ _ => ⟨6, rfl, fun d₂ => (htail d₂).hptLen⟩
      hqLE := ⟨by omega, fun _ => ⟨by omega, fun _ => ⟨by omega, fun d₂ => (htail d₂).hqLE⟩⟩⟩
      hdepStrict := DepStrict.dep2Pt _ _ _ _ fun d₂ => (htail d₂).hdepStrict
      hdepIn := ⟨Or.inl ⟨rfl, rfl⟩, fun d₀ => ⟨Or.inr (Or.inl ⟨rfl, d₀, rfl⟩), fun _ d₂ => (htail d₂).hdepIn⟩⟩
      hkCount := by
        unfold shdP_hdrPProgF PProg.KCount
        rw [shdQKind_key hsep]
        refine ⟨by omega, fun d₀ => ?_⟩
        unfold PProg.KCount
        rw [shdQKind_key hsep]
        refine ⟨by omega, fun d₁ => ?_⟩
        unfold PProg.KCount
        rw [shdQKind_key hsep]
        exact ⟨by omega, fun d₂ => (htail d₂).hkCount⟩
      hstep := fun ht => by rw [hnoTip] at ht; cases ht
      hcntT := by
        have hle := Finset.card_filter_le (Finset.range 7) (fun k => (hdrSched base inRootIdx (base + k)).kind = .tr)
        rwa [Finset.card_range] at hle
      hcntL := by
        have hemp : (Finset.range 7).filter (fun k => (hdrSched base inRootIdx (base + k)).kind = .leaf) = ∅ := by
          refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
          unfold hdrSched at hk; split_ifs at hk <;> cases hk
        rw [hemp, Finset.card_empty]
      hcntN := by
        have hemp : (Finset.range 7).filter (fun k => (hdrSched base inRootIdx (base + k)).kind = .node) = ∅ := by
          refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
          unfold hdrSched at hk; split_ifs at hk <;> cases hk
        rw [hemp, Finset.card_empty]
      hleaf_tree := fun j _ _ _ hs => by unfold hdrSched at hs; split_ifs at hs <;> cases hs
      hleaf_inj := fun i _ _ _ _ _ _ _ hs => by unfold hdrSched at hs; split_ifs at hs <;> cases hs
      hnode_bounds := fun j _ _ _ _ hs => by unfold hdrSched at hs; split_ifs at hs <;> cases hs
      hnode_inj := fun i _ _ _ _ _ _ _ _ _ hs => by unfold hdrSched at hs; split_ifs at hs <;> cases hs
      htr_lt := fun j h1 h2 _ => by
        unfold hdrSched
        by_cases hjb : j = base
        · rw [ite_eq_left hjb]; dsimp only [RawPtSpec.trM]; omega
        · rw [ite_eq_right hjb]; dsimp only [RawPtSpec.trM]; omega
      htr_entry := fun _ _ _ _ ht => by rw [hnoTip] at ht; cases ht
      htr_exit := fun i h1 h2 _ => ⟨rfl, by simp only [trChainTip, ↓reduceIte]; omega⟩
      htr_internal := fun i j hi1 hij hj2 _ _ => by
        have hne : j ≠ base := by omega
        unfold hdrSched; rw [ite_eq_right hne]; exact Or.inl (by dsimp only [RawPtSpec.trM]; omega)
      hpt_match := fun H v j hpre h1 h2 => by
        unfold shdP_hdrPProgF
        dsimp only [PProg.ptAt]
        by_cases hjb : j = base
        · subst hjb
          rw [ite_eq_left rfl]
          unfold hdrSched; rw [ite_eq_left rfl]
          refine ⟨_, rfl, _, abLabExp, abExpMsg w.inDig inRoot, _, by decide, by decide, rfl, ?_, ?_⟩
          · rw [qLastDig_abLabExp, hpre]
          · exact abLabExp_notMem_depSet hsep w.shape _ w.inDig inRoot _
        · rw [ite_eq_right hjb]
          unfold hdrSched; rw [ite_eq_right hjb]
          exact (htail (v base)).hpt_match H v j rfl (by omega) (by omega)
      hpost := fun H v _ => by
        unfold shdP_hdrPProgF
        dsimp only [PProg.res]
        exact (htail (v base)).hpost H v rfl }

/-- **Fixed-schedule `scProve` (`2 * n` `.pt`s: alternating `scLabel` absorb + squeeze)**:
when `active = true`, executes `scProve` on `WProver`; when `active = false`, emits dummy empty-bytes
`scLabel` absorbs + squeezes advancing the transcript in exact lockstep! -/
def scProveFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) :
    (n : ℕ) → Bool → WProver n → Tr → PProg (QB Lq) Dig (List (List Fp2) × List Fp2 × Tr)
  | 0, _, _, t => .ret ([], [], t)
  | n + 1, active, p, t =>
    let msg := if active then p.1 else []
    (trAbsorbFp2Keyed Lq hL20 key t scLabel (by decide) msg).andThen fun t1 =>
      (trChallengeFp2Keyed Lq (by omega) key t1).andThen fun rt =>
        (scProveFixedProg Lq hL20 key n active (p.2 rt.1) rt.2).andThen fun rest =>
          .ret (msg :: rest.1, rt.1 :: rest.2.1, rest.2.2)

theorem scProveFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (p : WProver n) (t : Tr), t.key = key →
      (∀ r_list, r_list ∈ (scProve (liftH G) n p t).1 → 48 + scLabel.length + r_list.length * 16 ≤ Lq) →
      let res := (scProveFixedProg Lq hL20 key n true p t).run G
      res.1 = (scProve (liftH G) n p t).1
        ∧ res.2.1 = (scChal (liftH G) (scProve (liftH G) n p t).1 t).1
        ∧ res.2.2 = (scProve (liftH G) n p t).2
  | 0, _, _, _, _ => ⟨rfl, rfl, rfl⟩
  | n + 1, p, t, htKey, hfit => by
    unfold scProveFixedProg
    simp only [↓reduceIte]
    have hr0 : 48 + scLabel.length + p.1.length * 16 ≤ Lq := hfit p.1 (by simp [scProve])
    rw [PProg.run_andThen,
      trAbsorbFp2Keyed_run Lq hL20 key t htKey scLabel (by decide) p.1 hr0 G,
      PProg.run_andThen,
      trChallengeFp2Keyed_run Lq (by omega) key (t.absorbFp2 (liftH G) scLabel p.1)
        (by rw [tr_absorbFp2_key, htKey]) G,
      PProg.run_andThen]
    have ih := scProveFixedProg_run Lq hL20 key G n
      (p.2 ((t.absorbFp2 (liftH G) scLabel p.1).challengeFp2 (liftH G)).1)
      ((t.absorbFp2 (liftH G) scLabel p.1).challengeFp2 (liftH G)).2
      (by rw [tr_challengeFp2_key, tr_absorbFp2_key, htKey])
      (fun r hr => hfit r (by simp only [scProve, List.mem_cons]; exact Or.inr hr))
    dsimp only at ih
    obtain ⟨h1, h2, h3⟩ := ih
    dsimp only [PProg.run, scProve, scChal]
    rw [h1, h2, h3]
    exact ⟨rfl, rfl, rfl⟩

/-- Alternating absorb/squeeze schedule for `scProveFixedProg` (`2 * n` points starting at `base`). -/
def scFixedSched (base tip : ℕ) (j : ℕ) : RawPtSpec :=
  if (j - base) % 2 = 0 then
    if j = base then .absorb tip else .absorb (j - 1)
  else .squeeze (j - 1)

theorem scProveFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins) :
    ∀ (n : ℕ) (active : Bool) (p : WProver n) (t : Tr) (base : ℕ)
      (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false),
    SliceSpec Lq tag key domain shape c
      (scProveFixedProg Lq hL20 key n active p t)
      base (2 * n) (2 * n) (2 * n) (2 * n) 0 0 st (trChainAfterVec base st (2 * n))
      (fun _ => False) (scFixedSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.1 = (List.range n).map (fun k => challengeFp2Of (v (base + 2 * k + 1)))
        ∧ res.2.2.state = v (trChainAfterVec base st (2 * n)).trTip)
  | 0, active, p, t, base, st, htip, hnoPos =>
    (retSliceSpec ([], [], t) base st
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.1 = [] ∧ res.2.2.state = v st.trTip)
      (fun _ _ hp => ⟨rfl, hp⟩) (scFixedSched base st.trTip)).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec])
      (fun _ h => h) (fun _ _ h => h)
      (fun _ _ _ _ hr => ⟨hr.1, by simp only [trChainAfterVec, ↓reduceDIte]; exact hr.2⟩)
  | n + 1, active, p, t, base, st, htip, hnoPos => by
    let msg := if active then p.1 else []
    let st1 := trChainTip base 1 Nat.zero_lt_one
    have h1 := trAbsorbSliceSpec hL20 hsep domain shape c t scLabel (by decide) (by decide)
      (msg.flatMap Fp2.toBytes) base st htip
    have h23 : ∀ t1 : Tr,
        SliceSpec Lq tag key domain shape c
          ((trChallengeFp2Keyed Lq (by omega) key t1).andThen fun rt =>
            (scProveFixedProg Lq hL20 key n active (p.2 rt.1) rt.2).andThen fun rest =>
              .ret (msg :: rest.1, rt.1 :: rest.2.1, rest.2.2))
          (base + 1) (1 + 2 * n) (1 + 2 * n) (1 + 2 * n) (1 + 2 * n) 0 0 st1
          ((trChainTip base (2 * (n + 1)) (by omega)).cast (by omega))
          (fun _ => False)
          (spliceSched (base + 2) (spliceSched (base + 2) (fun _ => .squeeze base) (fun _ => .absorb 0))
            (spliceSched (base + 2 + 2 * n) (scFixedSched (base + 2) (base + 1)) (fun _ => .absorb 0)))
          (fun _ v => t1.key = key ∧ t1.state = v base)
          (fun _ v res => res.2.1 = (List.range (n + 1)).map (fun k => challengeFp2Of (v (base + 2 * k + 1)))
            ∧ res.2.2.state = v (trChainTip base (2 * (n + 1)) (by omega)).trTip) := by
      intro t1
      have hch := trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c t1 (base + 1) st1 rfl rfl
      have hrest : ∀ rt : Fp2 × Tr,
          SliceSpec Lq tag key domain shape c
            ((scProveFixedProg Lq hL20 key n active (p.2 rt.1) rt.2).andThen fun rest =>
              .ret (msg :: rest.1, rt.1 :: rest.2.1, rest.2.2))
            (base + 2) (2 * n) (2 * n) (2 * n) (2 * n) 0 0 (trChainTip (base + 1) 1 Nat.zero_lt_one)
            (trChainAfterVec (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) (2 * n))
            (fun _ => False)
            (spliceSched (base + 2 + 2 * n) (scFixedSched (base + 2) (base + 1)) (fun _ => .absorb 0))
            (fun _ v => rt.1 = challengeFp2Of (v (base + 1)) ∧ rt.2.key = key ∧ rt.2.state = v (base + 1))
            (fun _ v res => res.2.1 = (List.range (n + 1)).map (fun k => challengeFp2Of (v (base + 2 * k + 1)))
              ∧ res.2.2.state = v (trChainTip base (2 * (n + 1)) (by omega)).trTip) := by
        intro rt
        have ih := scProveFixedSliceSpec hL20 hsep domain shape c n active (p.2 rt.1) rt.2
          (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) rfl rfl
        have htipEq : (trChainAfterVec (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) (2 * n)).trTip = base + 2 * n + 1 := by
          unfold trChainAfterVec trChainTip
          by_cases hn : 2 * n = 0
          · rw [dite_eq_left hn]; dsimp only [trChainTip]; omega
          · rw [dite_eq_right hn]; dsimp only [trChainTip]; omega
        exact (ih.andThen
          (fun rest => retSliceSpec (msg :: rest.1, rt.1 :: rest.2.1, rest.2.2) (base + 2 + 2 * n)
            (trChainAfterVec (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) (2 * n))
            (fun _ v => rest.2.1 = (List.range n).map (fun k => challengeFp2Of (v (base + 2 + 2 * k + 1)))
              ∧ rest.2.2.state = v (trChainAfterVec (base + 2) (trChainTip (base + 1) 1 Nat.zero_lt_one) (2 * n)).trTip)
            (fun _ v res => res.2.1 = rt.1 :: (List.range n).map (fun k => challengeFp2Of (v (base + 2 + 2 * k + 1)))
              ∧ res.2.2.state = v (base + 2 * n + 1))
            (fun _ v hres => ⟨congrArg (rt.1 :: ·) hres.1, by rw [← htipEq]; exact hres.2⟩))
          (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
          (TrChainState.ext rfl rfl rfl)
          (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2.2)
          (fun _ v res hp hres => by
            refine ⟨?_, ?_⟩
            · rw [hres.1, hp.1, List.range_succ_eq_map, List.map_cons, List.map_map]
              exact congrArg (challengeFp2Of (v (base + 1)) :: ·) (List.map_congr_left fun k _ => by
                show challengeFp2Of (v (base + 2 + 2 * k + 1)) = challengeFp2Of (v (base + 2 * (k + 1) + 1))
                congr 2; omega)
            · exact hres.2)
      exact (hch.andThen hrest (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        (by
          apply TrChainState.ext
          · unfold trChainAfterVec trChainTip TrChainState.cast; by_cases hn : 2 * n = 0 <;> simp [hn]
          · unfold trChainAfterVec trChainTip TrChainState.cast; by_cases hn : 2 * n = 0 <;> simp [hn] <;> omega
          · unfold trChainAfterVec trChainTip TrChainState.cast; by_cases hn : 2 * n = 0 <;> simp [hn])
        (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
    have hcomp : SliceSpec Lq tag key domain shape c
        (scProveFixedProg Lq hL20 key (n + 1) active p t)
        base (2 * (n + 1)) (2 * (n + 1)) (2 * (n + 1)) (2 * (n + 1)) 0 0 st
        (trChainAfterVec base st (2 * (n + 1))) (fun _ => False)
        (spliceSched (base + 1) (fun _ => .absorb st.trTip)
          (spliceSched (base + 2) (spliceSched (base + 2) (fun _ => .squeeze base) (fun _ => .absorb 0))
            (spliceSched (base + 2 + 2 * n) (scFixedSched (base + 2) (base + 1)) (fun _ => .absorb 0))))
        (fun _ v => t.state = v st.trTip)
        (fun _ v res => res.2.1 = (List.range (n + 1)).map (fun k => challengeFp2Of (v (base + 2 * k + 1)))
          ∧ res.2.2.state = v (trChainAfterVec base st (2 * (n + 1))).trTip) :=
      h1.seq h23 (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        ⟨by unfold trChainAfterVec trChainTip TrChainState.cast; rw [dite_eq_right (by omega : 2 * (n + 1) ≠ 0)],
         by unfold trChainAfterVec trChainTip TrChainState.cast; rw [dite_eq_right (by omega : 2 * (n + 1) ≠ 0)],
         by unfold trChainAfterVec trChainTip TrChainState.cast; rw [dite_eq_right (by omega : 2 * (n + 1) ≠ 0)]⟩
        (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
        (fun _ _ _ _ hr => ⟨hr.1, by simp only [trChainAfterVec, show 2 * (n + 1) ≠ 0 by omega, ↓reduceDIte]; exact hr.2⟩)
    have hEqSched : ∀ j, base ≤ j → j < base + 2 * (n + 1) →
        spliceSched (base + 1) (fun _ => .absorb st.trTip)
          (spliceSched (base + 2) (spliceSched (base + 2) (fun _ => .squeeze base) (fun _ => .absorb 0))
            (spliceSched (base + 2 + 2 * n) (scFixedSched (base + 2) (base + 1)) (fun _ => .absorb 0))) j
          = scFixedSched base st.trTip j := by
      intro j h1' h2'
      unfold spliceSched scFixedSched
      by_cases hjb : j = base
      · subst hjb; rw [ite_eq_left (Nat.lt_succ_self j)]; simp
      · by_cases hj1 : j = base + 1
        · subst hj1
          rw [ite_eq_right (by omega : ¬ base + 1 < base + 1), ite_eq_left (by omega : base + 1 < base + 2),
            ite_eq_left (by omega : base + 1 < base + 2)]
          have hm : (base + 1 - base) % 2 ≠ 0 := by omega
          rw [ite_eq_right hm]; simp
        · rw [ite_eq_right (by omega : ¬ j < base + 1), ite_eq_right (by omega : ¬ j < base + 2),
            ite_eq_left (by omega : j < base + 2 + 2 * n)]
          have hmod : (j - (base + 2)) % 2 = (j - base) % 2 := by omega
          rw [hmod]
          by_cases hev : (j - base) % 2 = 0
          · rw [ite_eq_left hev, ite_eq_left hev, ite_eq_right hjb]
            by_cases hj2 : j = base + 2
            · subst hj2; rw [ite_eq_left rfl]; simp
            · rw [ite_eq_right hj2]
          · rw [ite_eq_right hev, ite_eq_right hev]
    refine
      { hptLen := hcomp.hptLen
        hqLE := hcomp.hqLE
        hdepStrict := hcomp.hdepStrict
        hdepIn := hcomp.hdepIn
        hkCount := hcomp.hkCount
        hstep := hcomp.hstep
        hcntT := by
          have hle := Finset.card_filter_le (Finset.range (2 * (n + 1))) (fun k => (scFixedSched base st.trTip (base + k)).kind = .tr)
          rwa [Finset.card_range] at hle
        hcntL := by
          have hemp : (Finset.range (2 * (n + 1))).filter (fun k => (scFixedSched base st.trTip (base + k)).kind = .leaf) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold scFixedSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hcntN := by
          have hemp : (Finset.range (2 * (n + 1))).filter (fun k => (scFixedSched base st.trTip (base + k)).kind = .node) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun k _ hk => ?_
            unfold scFixedSched at hk; split_ifs at hk <;> cases hk
          rw [hemp, Finset.card_empty]
        hleaf_tree := fun j _ h1' h2' hs => by rw [← hEqSched j h1' h2'] at hs; exact hcomp.hleaf_tree j _ h1' h2' hs
        hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hleaf_inj i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij
        hnode_bounds := fun j L R h1' h2' hs => by
          rw [← hEqSched j h1' h2'] at hs; exact hcomp.hnode_bounds j L R h1' h2' hs
        hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hnode_inj i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij
        htr_lt := fun j h1' h2' htr => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_lt j h1' h2' htr
        htr_entry := fun j h1' h2' htr ht => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_entry j h1' h2' htr ht
        htr_exit := fun i h1' h2' htr => by
          rw [← hEqSched i h1' h2'] at htr ⊢; exact hcomp.htr_exit i h1' h2' htr
        htr_internal := fun i j hi1 hij hj2 hti htj => by
          rw [← hEqSched i hi1 (by omega)] at hti ⊢; rw [← hEqSched j (by omega) hj2] at htj ⊢
          exact hcomp.htr_internal i j hi1 hij hj2 hti htj
        hpt_match := fun H v j hp h1' h2' => by
          rw [← hEqSched j h1' h2']; exact hcomp.hpt_match H v j hp h1' h2'
        hpost := hcomp.hpost }

/-- **Fixed-length `nGroups` `pcsVecLabel` absorbs** (`nGroups` `.absorb`s, padding missing vectors with `[]`). -/
def trAbsorbVecsFixed (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) :
    ℕ → List (List Fp2) → Tr → PProg (QB Lq) Dig Tr
  | 0, _, t => .ret t
  | k + 1, vs, t =>
    (trAbsorbFp2Keyed Lq hL20 key t pcsVecLabel (by decide) (vs.headD [])).andThen fun t1 =>
      trAbsorbVecsFixed Lq hL20 key k vs.tail t1

theorem trAbsorbVecsFixed_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (k : ℕ) (vs : List (List Fp2)) (t : Tr), vs.length = k → t.key = key →
      (∀ v ∈ vs, 48 + pcsVecLabel.length + v.length * 16 ≤ Lq) →
      (trAbsorbVecsFixed Lq hL20 key k vs t).run G = absorbVecs (liftH G) vs t
  | 0, [], _, _, _, _ => rfl
  | 0, _ :: _, _, hlen, _, _ => by simp at hlen
  | k + 1, [], _, hlen, _, _ => by simp at hlen
  | k + 1, v :: vs, t, hlen, htKey, hfit => by
    unfold trAbsorbVecsFixed absorbVecs
    rw [PProg.run_andThen, List.headD_cons, List.tail_cons,
      trAbsorbFp2Keyed_run Lq hL20 key t htKey pcsVecLabel (by decide) v (hfit v List.mem_cons_self) G]
    exact trAbsorbVecsFixed_run Lq hL20 key G k vs _ (Nat.succ.inj hlen) htKey
      (fun u hu => hfit u (List.mem_cons_of_mem _ hu))

/-- Schedule for `k` consecutive absorbs starting at `base` from `st.trTip`. -/
def absorbVecSched (base tip : ℕ) (j : ℕ) : RawPtSpec :=
  if j = base then .absorb tip else .absorb (j - 1)

theorem trAbsorbVecsFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins) :
    ∀ (k : ℕ) (vs : List (List Fp2)) (t : Tr) (base : ℕ)
      (st : TrChainState base) (htip : st.hasTip = true),
    SliceSpec Lq tag key domain shape c
      (trAbsorbVecsFixed Lq hL20 key k vs t)
      base k k k k 0 0 st (trChainAfterVec base st k) (fun _ => False) (absorbVecSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v t' => t'.state = v (trChainAfterVec base st k).trTip)
  | 0, vs, t, base, st, htip =>
    (retSliceSpec t base st (fun _ v => t.state = v st.trTip) (fun _ v t' => t'.state = v st.trTip)
      (fun _ _ hp => hp) (absorbVecSched base st.trTip)).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec]) (fun _ h => h) (fun _ _ h => h)
      (fun _ _ _ _ hr => by simp only [trChainAfterVec, ↓reduceDIte]; exact hr)
  | k + 1, vs, t, base, st, htip => by
    let st1 := trChainTip base 1 Nat.zero_lt_one
    have h1 := trAbsorbSliceSpec hL20 hsep domain shape c t pcsVecLabel (by decide) (by decide)
      ((vs.headD []).flatMap Fp2.toBytes) base st htip
    have h2 : ∀ t1 : Tr,
        SliceSpec Lq tag key domain shape c
          (trAbsorbVecsFixed Lq hL20 key k vs.tail t1)
          (base + 1) k k k k 0 0 st1 (trChainAfterVec (base + 1) st1 k) (fun _ => False)
          (absorbVecSched (base + 1) base)
          (fun _ v => t1.key = key ∧ t1.state = v base)
          (fun _ v t' => t'.state = v (trChainAfterVec (base + 1) st1 k).trTip) := fun t1 =>
      (trAbsorbVecsFixedSliceSpec hL20 hsep domain shape c k vs.tail t1 (base + 1) st1 rfl).congr
        rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
    have hcomp : SliceSpec Lq tag key domain shape c
        (trAbsorbVecsFixed Lq hL20 key (k + 1) vs t)
        base (k + 1) (k + 1) (k + 1) (k + 1) 0 0 st (trChainAfterVec base st (k + 1)) (fun _ => False)
        (spliceSched (base + 1) (fun _ => .absorb st.trTip) (absorbVecSched (base + 1) base))
        (fun _ v => t.state = v st.trTip)
        (fun _ v t' => t'.state = v (trChainAfterVec base st (k + 1)).trTip) :=
      h1.seq h2 (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
        ⟨by unfold st1 trChainAfterVec trChainTip; by_cases hk : k = 0 <;> simp [hk],
         by unfold st1 trChainAfterVec trChainTip; by_cases hk : k = 0 <;> simp [hk] <;> omega,
         by unfold st1 trChainAfterVec trChainTip; by_cases hk : k = 0 <;> simp [hk]⟩
        (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
        (fun _ _ t' _ ht' => by
          unfold st1 trChainAfterVec trChainTip at ht'
          unfold trChainAfterVec trChainTip
          rw [dite_eq_right (Nat.succ_ne_zero k)]
          by_cases hk : k = 0
          · subst hk; rw [dite_eq_left rfl] at ht'; simpa using ht'
          · rw [dite_eq_right hk] at ht'; dsimp only at ht' ⊢; rwa [show base + 1 + k - 1 = base + (k + 1) - 1 by omega] at ht')
    have hEqSched : ∀ j, base ≤ j → j < base + (k + 1) →
        spliceSched (base + 1) (fun _ => .absorb st.trTip) (absorbVecSched (base + 1) base) j
          = absorbVecSched base st.trTip j := by
      intro j h1' h2'
      unfold spliceSched absorbVecSched
      by_cases hjb : j = base
      · subst hjb; rw [ite_eq_left (Nat.lt_succ_self j), ite_eq_left rfl]
      · rw [ite_eq_right (by omega : ¬ j < base + 1), ite_eq_right hjb]
        by_cases hj1 : j = base + 1
        · subst hj1; rw [ite_eq_left rfl]; simp
        · rw [ite_eq_right hj1]
    refine
      { hptLen := hcomp.hptLen
        hqLE := hcomp.hqLE
        hdepStrict := hcomp.hdepStrict
        hdepIn := hcomp.hdepIn
        hkCount := hcomp.hkCount
        hstep := hcomp.hstep
        hcntT := by
          have hle := Finset.card_filter_le (Finset.range (k + 1)) (fun r => (absorbVecSched base st.trTip (base + r)).kind = .tr)
          rwa [Finset.card_range] at hle
        hcntL := by
          have hemp : (Finset.range (k + 1)).filter (fun r => (absorbVecSched base st.trTip (base + r)).kind = .leaf) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun r _ hr => ?_
            unfold absorbVecSched at hr; split_ifs at hr <;> cases hr
          rw [hemp, Finset.card_empty]
        hcntN := by
          have hemp : (Finset.range (k + 1)).filter (fun r => (absorbVecSched base st.trTip (base + r)).kind = .node) = ∅ := by
            refine Finset.filter_eq_empty_iff.mpr fun r _ hr => ?_
            unfold absorbVecSched at hr; split_ifs at hr <;> cases hr
          rw [hemp, Finset.card_empty]
        hleaf_tree := fun j _ h1' h2' hs => by rw [← hEqSched j h1' h2'] at hs; exact hcomp.hleaf_tree j _ h1' h2' hs
        hleaf_inj := fun i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hleaf_inj i j id₁ id₂ hi1 hi2 hj1 hj2 hsi hsj hij
        hnode_bounds := fun j L R h1' h2' hs => by
          rw [← hEqSched j h1' h2'] at hs; exact hcomp.hnode_bounds j L R h1' h2' hs
        hnode_inj := fun i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij => by
          rw [← hEqSched i hi1 hi2] at hsi; rw [← hEqSched j hj1 hj2] at hsj
          exact hcomp.hnode_inj i j L₁ R₁ L₂ R₂ hi1 hi2 hj1 hj2 hsi hsj hij
        htr_lt := fun j h1' h2' htr => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_lt j h1' h2' htr
        htr_entry := fun j h1' h2' htr ht => by
          rw [← hEqSched j h1' h2'] at htr ⊢; exact hcomp.htr_entry j h1' h2' htr ht
        htr_exit := fun i h1' h2' htr => by
          rw [← hEqSched i h1' h2'] at htr ⊢; exact hcomp.htr_exit i h1' h2' htr
        htr_internal := fun i j hi1 hij hj2 hti htj => by
          rw [← hEqSched i hi1 (by omega)] at hti ⊢; rw [← hEqSched j (by omega) hj2] at htj ⊢
          exact hcomp.htr_internal i j hi1 hij hj2 hti htj
        hpt_match := fun H v j hp h1' h2' => by
          rw [← hEqSched j h1' h2']; exact hcomp.hpt_match H v j hp h1' h2'
        hpost := hcomp.hpost }

/-- Dummy zero-word `WProver m` used on inactive/refused branches of `slotProveFixedProg`. -/
def dummyWP : (m : ℕ) → WProver m
  | 0 => PUnit.unit
  | m + 1 => ([], fun _ => dummyWP m)

/-- **Fixed-schedule `slotProve` (`P.draws s + 4 + 2 * (slotN P s)` `.pt`s)**:
always emits the exact static schedule (`draws` squeezes, `labPbSlot`, `c` squeeze, `labPbScalar`,
`scProveFixedProg (slotN P s)`, `labPbTerm`), threading `active : Bool` and returning
`Option (SlotProof × SlotRec × Acc) × Tr` (matching `slotProve` verbatim when `active = true`). -/
def slotProveFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc) (t : Tr) :
    PProg (QB Lq) Dig (Option (SlotProof × SlotRec × Acc) × Tr) :=
  (trChallengeFp2VecKeyed Lq (by omega) key (P.draws s) t).andThen fun dr =>
    (trAbsorbKeyed Lq hL20 key dr.2 labPbSlot (by decide) (le64 (UInt64.ofNat s))).andThen fun t2 =>
      (trChallengeFp2Keyed Lq (by omega) key t2).andThen fun ct =>
        let defRes := if active then P.define s hist dr.1 else .error "inactive"
        let cOk := active && !ct.1.isZero
        let (scActive, scalar, strat) := match defRes with
          | .ok df =>
            if cOk then (true, D.scalar s hist acc df ct.1, D.strat s hist acc df ct.1)
            else (false, Fp2.zero, D.strat s hist acc df ct.1)
          | .error _ => (false, Fp2.zero, dummyWP (slotN P s))
        (trAbsorbFp2Keyed Lq hL20 key ct.2 labPbScalar (by decide) [scalar]).andThen fun t4 =>
          (scProveFixedProg Lq hL20 key (slotN P s) scActive strat t4).andThen fun scr =>
            let (outOpt, terms) := match defRes with
              | .error _ => (none, [])
              | .ok df =>
                if !cOk then (none, [])
                else
                  let rhoFull := scr.2.1
                  let rho := rhoFull.take (Exec.Block.slotShape P s).1
                  let es := rhoFull.drop (Exec.Block.slotShape P s).1
                  if es.any (fun x => x.isZero || decide (x = Fp2.one)) then (none, [])
                  else
                    let tms := D.terms s hist acc df ct.1 rhoFull
                    match Exec.Block.slotDefChecks P s acc df with
                    | .error _ => (none, tms)
                    | .ok _ =>
                      match Exec.Block.hostedSum acc.scalars scalar df.hosted with
                      | .error _ => (none, tms)
                      | .ok claimed =>
                        match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho tms df.tabs 0 with
                        | .error _ => (none, tms)
                        | .ok vals =>
                          let fin := scFinalExec scr.1 rhoFull claimed
                          let sp : SlotProof := ⟨scalar, scr.1, tms⟩
                          let rec_ : SlotRec := ⟨dr.1, ct.1, scalar, claimed, rho, es, tms, fin⟩
                          let acc' := Exec.Block.slotAcc P s acc df ct.1 scalar
                            ((fin.sub (df.poly vals)).mul ct.1.inv) rhoFull tms
                          (some (sp, rec_, acc'), tms)
            (trAbsorbFp2Keyed Lq hL20 key scr.2.2 labPbTerm (by decide) terms).andThen fun t6 =>
              .ret (outOpt, t6)

/-- **Fixed-schedule `zkBMask` (`2 * S + 69` `.pt`s)**:
always emits `1` squeeze (`θ`), `1` absorb (`maskQLabel`), `2*S+2` squeezes (`rs`), `1` absorb
(`maskProxLabel`), `64` squeezes (`sq`), building `MaskOpening` from cached `MerkleLevels 12`. -/
noncomputable def zkBMaskFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    PProg (QB Lq) Dig (Exec.Block.MaskOpening × Tr) :=
  let fs' := fs.map toMF
  (trChallengeFp2Keyed Lq (by omega) key t).andThen fun th =>
    let qw := if active then polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S fs' (th.1.toK U)) else []
    (trAbsorbFp2Keyed Lq hL20 key th.2 maskQLabel (by decide) qw).andThen fun t1 =>
      (trChallengeFp2VecKeyed Lq (by omega) key (2 * S + 2) t1).andThen fun rs =>
        let pw := if active then polyWords U hbij (pPoly U M S rs.1) else []
        (trAbsorbFp2Keyed Lq hL20 key rs.2 maskProxLabel (by decide) pw).andThen fun t2 =>
          (trSqueezeVecKeyed Lq (by omega) key ((mQ + 3) / 4) t2).andThen fun sq =>
            let cols := (idxOf mDom mQ sq.1).map (fun j =>
              ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
            .ret (⟨qw, pw, cols⟩, sq.2)

/-- **Fixed-schedule deduplicated `openingAudit + bOpen` (`nClaims + rows + nGroups + 1 + (nQ + 3) / 4` `.pt`s)**:
draws `nClaims` `λ`-squeezes + `rows` `proxRho`-squeezes ONCE, checks pure `hdrOk` + `openingAuditOk`,
then ALWAYS emits `nGroups` `pcsVecLabel` absorbs + `1` `pcsProxLabel` absorb + `(nQ + 3) / 4` squeezes,
returning `Option Exec.Block.OpeningZk × Tr`! -/
def groupRhosAux (rows : ℕ) :
    List (List Fp2 × List (List Fp2 × Fp2)) → List Fp2 → List (List Fp2)
  | [], _ => []
  | grp :: rest, rem =>
    let k := grp.2.length
    (groupComb rows grp.2 (rem.take k)).1 :: groupRhosAux rows rest (rem.drop k)

def openingHdrOk (g : OpenGeom) (logCols : ℕ) (cl : List Exec.Block.ZClaim) : Bool :=
  match auditClaims cl (2 ^ logCols) g.rows g.siteRows g.sumRows g.prox with
  | .error _ => false
  | .ok () =>
    match openingGroupsAt cl logCols with
    | .error _ => false
    | .ok og => decide (og.length = g.groups)

def tokenEpHdrOk (cl : List Exec.Block.ZClaim) (data n : ℕ) : Bool :=
  match cl with
  | [c] =>
    match c.parts with
    | [p0, p1, p2] =>
      decide (Exec.StageV.partRows p0 n = (0, data)
        ∧ Exec.StageV.partRows p1 n = (data, data + 1)
        ∧ Exec.StageV.partRows p2 n = (data + 1, data + 2)
        ∧ c.parts.all (fun p => !p.coef.isZero) = true)
    | _ => false
  | _ => false

def openingAuditFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active : Bool) (hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PProg (QB Lq) Dig (Option Exec.Block.OpeningZk × Tr) :=
  let gs := pGroups prm T (cl.map toZClaim)
  let preOk := active && hdrOk && decide ((gs.map (fun x => x.2.length)).sum = nClaims) && decide (gs.length = nGroups)
  (trChallengeFp2VecKeyed Lq (by omega) key nClaims t).andThen fun lams =>
    (trChallengeFp2VecKeyed Lq (by omega) key rows lams.2).andThen fun proxR =>
      let auditPass := preOk && openingAuditOk lams.1 proxR.1 g.rows g.prox
      let vecs := if auditPass then (groupRhosAux rows gs lams.1).map (fun rho => combVec (prm.n + prm.qPad) rho T.rows) else []
      let prox := if auditPass then combVec (prm.n + prm.qPad) proxR.1 T.rows else []
      (trAbsorbVecsFixed Lq hL20 key nGroups vecs proxR.2).andThen fun t1 =>
        (trAbsorbFp2Keyed Lq hL20 key t1 pcsProxLabel (by decide) prox).andThen fun t2 =>
          (trSqueezeVecKeyed Lq (by omega) key ((prm.nQ + 3) / 4) t2).andThen fun sq =>
            let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
            .ret (if auditPass then some ⟨vecs, prox, cols⟩ else none, sq.2)

/-! ### 4a. `slotProveFixedProg` & `slotsProveFixedProg` (`.run` + `SliceSpec`) -/

def slotFixedLen (P : BlockParams) (s : ℕ) : ℕ :=
  P.draws s + 4 + 2 * slotN P s

def slotFixedSched (P : BlockParams) (s base tip : ℕ) : ℕ → RawPtSpec :=
  let k0 := P.draws s
  let k4 := 2 * slotN P s
  let b1 := base + k0
  let b2 := b1 + 1
  let b3 := b2 + 1
  let b4 := b3 + 1
  let b5 := b4 + k4
  spliceSched b1 (squeezeVecSched base tip)
    (spliceSched b2 (fun _ => .absorb (if k0 = 0 then tip else b1 - 1))
      (spliceSched b3 (spliceSched b3 (fun _ => .squeeze b1) (fun _ => .absorb 0))
        (spliceSched b4 (fun _ => .absorb b2)
          (spliceSched b5 (scFixedSched b4 b3)
            (spliceSched (b5 + 1) (fun _ => .absorb (if k4 = 0 then b3 else b5 - 1)) (fun _ => .absorb 0))))))

theorem slotProveFixedProg_run_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (G : QB Lq → Dig) :
    ((slotProveFixedProg Lq hL20 key P D s false hist acc t).run G).1 = none := by
  unfold slotProveFixedProg
  simp only [Bool.false_eq_true, ↓reduceIte, PProg.run_andThen, run_ret]

theorem slotProve_key (H : HIn → Dig) (P : BlockParams) (D : SlotData P) (s : ℕ)
    (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof) (rec_ : SlotRec) (acc' : Acc) (t' : Tr)
    (h : slotProve H P D s hist acc t = .ok (sp, rec_, acc', t')) :
    t'.key = t.key := by
  unfold slotProve at h
  split at h
  · cases h
  · split_ifs at h
    all_goals try cases h
    split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · simp only [Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨_, _, _, rfl⟩ := h
          exact (tr_absorbFp2_key H _ _ _).trans
            ((scProve_key H _ _ _).trans
              ((tr_absorbFp2_key H _ _ _).trans
                ((tr_challengeFp2_key H _).trans
                  ((tr_absorb_key H _ _ _).trans (tr_challengeFp2Vec_key H _ t)))))

theorem slotsProve_key (H : HIn → Dig) (P : BlockParams) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      slotsProve H P D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      t'.key = t.key
  | 0, _, _, _, _, _, _, _, _, h => by
    unfold slotsProve at h; simp only [Except.ok.injEq, Prod.mk.injEq] at h
    exact congrArg Tr.key h.2.2.2.symm
  | m + 1, recs, s, acc, t, sps, recs', acc', t', h => by
    unfold slotsProve at h
    cases h1 : slotProve H P D s (Exec.Block.histOf b g a recs) acc t with
    | error e => rw [h1] at h; cases h
    | ok v1 =>
      rcases v1 with ⟨sp, rec_, acc1, t1⟩
      rw [h1] at h; dsimp only at h
      cases h2 : slotsProve H P D b g a m (recs ++ [rec_]) (s + 1) acc1 t1 with
      | error e => rw [h2] at h; cases h
      | ok v2 =>
        rcases v2 with ⟨sps2, recs2, acc2, t2⟩
        rw [h2] at h; simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨_, _, _, rfl⟩ := h
        exact (slotsProve_key H P D b g a m (recs ++ [rec_]) (s + 1) acc1 t1 sps2 recs2 acc2 t2 h2).trans
          (slotProve_key H P D s (Exec.Block.histOf b g a recs) acc t sp rec_ acc1 t1 h1)

theorem slotProveFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig)
    (hfitSc : ∀ df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
        (D.strat s hist acc df (slotC (liftH G) P s t))
        (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + labPbTerm.length + (slotSP (liftH G) P D s hist acc t df).terms.length * 16 ≤ Lq) :
    let res := (slotProveFixedProg Lq hL20 key P D s true hist acc t).run G
    match slotProve (liftH G) P D s hist acc t with
    | .ok (sp, r, acc', t') => res = (some (sp, r, acc'), t')
    | .error () => res.1 = none := by
  dsimp only
  generalize hres : (slotProveFixedProg Lq hL20 key P D s true hist acc t).run G = res
  unfold slotProveFixedProg at hres
  rw [PProg.run_andThen, trChallengeFp2VecKeyed_run Lq (by omega) key G (P.draws s) t htKey,
    PProg.run_andThen,
    trAbsorbKeyed_run Lq hL20 key (t.challengeFp2Vec (liftH G) (P.draws s)).2
      (by rw [tr_challengeFp2Vec_key, htKey]) labPbSlot (by decide) (le64 (UInt64.ofNat s))
      (by rw [le64_length]; simp [labPbSlot]; omega) G,
    PProg.run_andThen,
    trChallengeFp2Keyed_run Lq (by omega) key _
      (by rw [tr_absorb_key, tr_challengeFp2Vec_key, htKey]) G] at hres
  simp only [↓reduceIte, Bool.true_and] at hres
  unfold slotProve
  cases hdf : P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 with
  | error e =>
    rw [hdf] at hres
    simp only [PProg.run_andThen, run_ret] at hres
    rw [← hres]
  | ok df =>
    rw [hdf] at hres
    have hSlotT2 : (t.challengeFp2Vec (liftH G) (P.draws s)).2.absorb (liftH G) labPbSlot (le64 (UInt64.ofNat s))
        = slotT2 (liftH G) P s t := rfl
    have hSlotC : ((slotT2 (liftH G) P s t).challengeFp2 (liftH G)).1
        = slotC (liftH G) P s t := rfl
    rw [hSlotT2, hSlotC] at hres
    cases hc0 : (slotC (liftH G) P s t).isZero with
    | true =>
      rw [hc0] at hres
      simp only [Bool.not_true, Bool.not_false, Bool.false_eq_true, ↓reduceIte,
        PProg.run_andThen, run_ret] at hres
      simp only [↓reduceIte, ← hres]
    | false =>
      rw [hc0] at hres
      simp only [Bool.not_false, ↓reduceIte] at hres
      simp only [Bool.false_eq_true, ↓reduceIte]
      have hT4 : (((slotT2 (liftH G) P s t).challengeFp2 (liftH G)).2.absorbFp2 (liftH G) labPbScalar
          [D.scalar s hist acc df (slotC (liftH G) P s t)])
          = slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)) := rfl
      rw [PProg.run_andThen,
        trAbsorbFp2Keyed_run Lq hL20 key ((slotT2 (liftH G) P s t).challengeFp2 (liftH G)).2
          (by rw [tr_challengeFp2_key, ← hSlotT2, tr_absorb_key, tr_challengeFp2Vec_key, htKey])
          labPbScalar (by decide)
          [D.scalar s hist acc df (slotC (liftH G) P s t)] (by simp [labPbScalar]; omega) G,
        hT4, PProg.run_andThen] at hres
      have hsc := scProveFixedProg_run Lq hL20 key G (slotN P s)
        (D.strat s hist acc df (slotC (liftH G) P s t))
        (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))
        (by rw [← hT4, tr_absorbFp2_key, tr_challengeFp2_key, ← hSlotT2, tr_absorb_key, tr_challengeFp2Vec_key, htKey])
        (hfitSc df hdf)
      dsimp only at hsc
      obtain ⟨hsc1, hsc2, hsc3⟩ := hsc
      have hRho : (scProveFixedProg Lq hL20 key (slotN P s) true
          (D.strat s hist acc df (slotC (liftH G) P s t))
          (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).run G |>.2.1
          = slotRho (liftH G) P D s hist acc t df := hsc2
      rw [hRho] at hres
      cases hes : ((slotRho (liftH G) P D s hist acc t df).drop (Exec.Block.slotShape P s).1).any
          (fun x => x.isZero || decide (x = Fp2.one)) with
      | true =>
        rw [hes] at hres
        simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte, PProg.run_andThen, run_ret] at hres
        simp only [↓reduceIte, ← hres]
      | false =>
        rw [hes] at hres
        simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte] at hres
        simp only [Bool.false_eq_true, ↓reduceIte]
        have hSpSc : D.scalar s hist acc df (slotC (liftH G) P s t)
            = (slotSP (liftH G) P D s hist acc t df).scalar := rfl
        have hSpTm : D.terms s hist acc df (slotC (liftH G) P s t) (slotRho (liftH G) P D s hist acc t df)
            = (slotSP (liftH G) P D s hist acc t df).terms := rfl
        rw [hSpSc, hSpTm] at hres
        cases hchk : Exec.Block.slotDefChecks P s acc df with
        | error e =>
          rw [hchk] at hres
          simp only [PProg.run_andThen, run_ret] at hres
          rw [← hres]
        | ok u =>
          cases u
          rw [hchk] at hres
          dsimp only at hres ⊢
          cases hhost : Exec.Block.hostedSum acc.scalars (slotSP (liftH G) P D s hist acc t df).scalar df.hosted with
          | error e =>
            rw [hhost] at hres
            simp only [PProg.run_andThen, run_ret] at hres
            rw [← hres]
          | ok claimed =>
            rw [hhost] at hres
            dsimp only at hres ⊢
            cases htab : Exec.Block.tabVals
                (Exec.Block.oneMinusProd ((slotRho (liftH G) P D s hist acc t df).drop (Exec.Block.slotShape P s).1))
                ((slotRho (liftH G) P D s hist acc t df).take (Exec.Block.slotShape P s).1)
                (slotSP (liftH G) P D s hist acc t df).terms df.tabs 0 with
            | error e =>
              rw [htab] at hres
              simp only [PProg.run_andThen, run_ret] at hres
              rw [← hres]
            | ok vals =>
              rw [htab] at hres
              dsimp only at hres ⊢
              have htKey3 : ((scProveFixedProg Lq hL20 key (slotN P s) true
                  (D.strat s hist acc df (slotC (liftH G) P s t))
                  (slotT4 (liftH G) P s t (slotSP (liftH G) P D s hist acc t df).scalar)).run G).2.2.key = key := by
                rw [← hSpSc, hsc3, scProve_key, ← hT4, tr_absorbFp2_key, tr_challengeFp2_key, ← hSlotT2,
                  tr_absorb_key, tr_challengeFp2Vec_key, htKey]
              have hSpRd : (scProve (liftH G) (slotN P s) (D.strat s hist acc df (slotC (liftH G) P s t))
                  (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).1
                  = (slotSP (liftH G) P D s hist acc t df).rounds := rfl
              have hSpMk : (⟨(slotSP (liftH G) P D s hist acc t df).scalar,
                  (slotSP (liftH G) P D s hist acc t df).rounds,
                  (slotSP (liftH G) P D s hist acc t df).terms⟩ : SlotProof)
                  = slotSP (liftH G) P D s hist acc t df := rfl
              rw [PProg.run_andThen,
                trAbsorbFp2Keyed_run Lq hL20 key _ htKey3 labPbTerm (by decide) _ (hfitTerms df hdf hchk) G,
                run_ret, ← hSpSc, hsc1, hsc3, hSpRd, hSpSc, hSpMk] at hres
              exact hres.symm

theorem slotProveFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (slotProveFixedProg Lq hL20 key P D s active hist acc t)
      base (slotFixedLen P s) (slotFixedLen P s) (slotFixedLen P s) (slotFixedLen P s) 0 0
      st (trChainTip base (slotFixedLen P s) (by unfold slotFixedLen; omega))
      (fun _ => False) (slotFixedSched P s base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.key = key ∧ res.2.state = v (base + slotFixedLen P s - 1)) := by
  let k0 := P.draws s
  let k4 := 2 * slotN P s
  let b1 := base + k0
  let b2 := b1 + 1
  let b3 := b2 + 1
  let b4 := b3 + 1
  let b5 := b4 + k4
  let st1 := trChainAfterVec base st k0
  let st2 := trChainTip b1 1 Nat.zero_lt_one
  let st3 := trChainTip b2 1 Nat.zero_lt_one
  let st4 := trChainTip b3 1 Nat.zero_lt_one
  let st5 := trChainAfterVec b4 st4 k4
  let st6 := trChainTip b5 1 Nat.zero_lt_one
  have htip1 : st1.hasTip = true := by
    unfold st1 trChainAfterVec; split_ifs <;> [exact htip; rfl]
  have hnoPos1 : st1.afterPosTag = false := by
    unfold st1 trChainAfterVec; split_ifs <;> [exact hnoPos; rfl]
  have hst1Tip : st1.trTip = if k0 = 0 then st.trTip else b1 - 1 := by
    unfold st1 trChainAfterVec trChainTip b1; split_ifs <;> rfl
  have hst5Tip : st5.trTip = if k4 = 0 then b3 else b5 - 1 := by
    unfold st5 st4 trChainAfterVec trChainTip b5; split_ifs <;> simp
  have htip5 : st5.hasTip = true := by unfold st5 trChainAfterVec; split_ifs <;> rfl
  have hstep6 : ∀ (outOpt : Option (SlotProof × SlotRec × Acc)) (terms : List Fp2) (t5 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbFp2Keyed Lq hL20 key t5 labPbTerm (by decide) terms).andThen fun t6 => .ret (outOpt, t6))
        b5 1 1 1 1 0 0 st5 st6 (fun _ => False)
        (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0))
        (fun _ v => t5.state = v st5.trTip)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) := fun outOpt terms t5 =>
    (trAbsorbSliceSpec hL20 hsep domain shape c t5 labPbTerm (by decide) (by decide)
      (terms.flatMap Fp2.toBytes) b5 st5 htip5).seq
      (fun t6 => retSliceSpec (outOpt, t6) (b5 + 1) st6
        (fun _ v => t6.key = key ∧ t6.state = v b5)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) (fun _ _ hp => hp))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep5 : ∀ (scActive : Bool) (strat : WProver (slotN P s)) (t4 : Tr)
      (mkOut : List (List Fp2) × List Fp2 × Tr → Option (SlotProof × SlotRec × Acc) × List Fp2),
      SliceSpec Lq tag key domain shape c
        ((scProveFixedProg Lq hL20 key (slotN P s) scActive strat t4).andThen fun scr =>
          let (outOpt, terms) := mkOut scr
          (trAbsorbFp2Keyed Lq hL20 key scr.2.2 labPbTerm (by decide) terms).andThen fun t6 => .ret (outOpt, t6))
        b4 (k4 + 1) (k4 + 1) (k4 + 1) (k4 + 1) 0 0 st4 st6 (fun _ => False)
        (spliceSched b5 (scFixedSched b4 b3)
          (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0)))
        (fun _ v => t4.state = v b3)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) := fun scActive strat t4 mkOut =>
    (scProveFixedSliceSpec hL20 hsep domain shape c (slotN P s) scActive strat t4 b4 st4 rfl rfl).seq
      (fun scr => (hstep6 (mkOut scr).1 (mkOut scr).2 scr.2.2).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by unfold k4; omega) (by unfold k4; omega) (by unfold k4; omega)
      (by unfold k4; omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
      (fun _ _ _ _ hr => hr)
  have hstep4 : ∀ (scalar : Fp2) (scActive : Bool) (strat : WProver (slotN P s)) (t3 : Tr)
      (mkOut : List (List Fp2) × List Fp2 × Tr → Option (SlotProof × SlotRec × Acc) × List Fp2),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbFp2Keyed Lq hL20 key t3 labPbScalar (by decide) [scalar]).andThen fun t4 =>
          (scProveFixedProg Lq hL20 key (slotN P s) scActive strat t4).andThen fun scr =>
            let (outOpt, terms) := mkOut scr
            (trAbsorbFp2Keyed Lq hL20 key scr.2.2 labPbTerm (by decide) terms).andThen fun t6 => .ret (outOpt, t6))
        b3 (1 + (k4 + 1)) (1 + (k4 + 1)) (1 + (k4 + 1)) (1 + (k4 + 1)) 0 0 st3 (st6.cast (by unfold b5 b4 k4; omega)) (fun _ => False)
        (spliceSched b4 (fun _ => .absorb b2)
          (spliceSched b5 (scFixedSched b4 b3)
            (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0))))
        (fun _ v => t3.state = v b2)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) := fun scalar scActive strat t3 mkOut =>
    (trAbsorbSliceSpec hL20 hsep domain shape c t3 labPbScalar (by decide) (by decide)
      ([scalar].flatMap Fp2.toBytes) b3 st3 rfl).seq
      (fun t4 => (hstep5 scActive strat t4 mkOut).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep3 : ∀ (dr : List Fp2 × Tr) (t2 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trChallengeFp2Keyed Lq (by omega) key t2).andThen fun ct =>
          let defRes := if active then P.define s hist dr.1 else .error "inactive"
          let cOk := active && !ct.1.isZero
          let (scActive, scalar, strat) := match defRes with
            | .ok df =>
              if cOk then (true, D.scalar s hist acc df ct.1, D.strat s hist acc df ct.1)
              else (false, Fp2.zero, D.strat s hist acc df ct.1)
            | .error _ => (false, Fp2.zero, dummyWP (slotN P s))
          (trAbsorbFp2Keyed Lq hL20 key ct.2 labPbScalar (by decide) [scalar]).andThen fun t4 =>
            (scProveFixedProg Lq hL20 key (slotN P s) scActive strat t4).andThen fun scr =>
              let (outOpt, terms) := match defRes with
                | .error _ => (none, [])
                | .ok df =>
                  if !cOk then (none, [])
                  else
                    let rhoFull := scr.2.1
                    let rho := rhoFull.take (Exec.Block.slotShape P s).1
                    let es := rhoFull.drop (Exec.Block.slotShape P s).1
                    if es.any (fun x => x.isZero || decide (x = Fp2.one)) then (none, [])
                    else
                      let tms := D.terms s hist acc df ct.1 rhoFull
                      match Exec.Block.slotDefChecks P s acc df with
                      | .error _ => (none, tms)
                      | .ok _ =>
                        match Exec.Block.hostedSum acc.scalars scalar df.hosted with
                        | .error _ => (none, tms)
                        | .ok claimed =>
                          match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho tms df.tabs 0 with
                          | .error _ => (none, tms)
                          | .ok vals =>
                            let fin := scFinalExec scr.1 rhoFull claimed
                            let sp : SlotProof := ⟨scalar, scr.1, tms⟩
                            let rec_ : SlotRec := ⟨dr.1, ct.1, scalar, claimed, rho, es, tms, fin⟩
                            let acc' := Exec.Block.slotAcc P s acc df ct.1 scalar
                              ((fin.sub (df.poly vals)).mul ct.1.inv) rhoFull tms
                            (some (sp, rec_, acc'), tms)
              (trAbsorbFp2Keyed Lq hL20 key scr.2.2 labPbTerm (by decide) terms).andThen fun t6 =>
                .ret (outOpt, t6))
        b2 (1 + (1 + (k4 + 1))) (1 + (1 + (k4 + 1))) (1 + (1 + (k4 + 1))) (1 + (1 + (k4 + 1))) 0 0 st2 (st6.cast (by unfold b5 b4 b3 k4; omega))
        (fun _ => False)
        (spliceSched b3 (spliceSched b3 (fun _ => .squeeze b1) (fun _ => .absorb 0))
          (spliceSched b4 (fun _ => .absorb b2)
            (spliceSched b5 (scFixedSched b4 b3)
              (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0)))))
        (fun _ v => t2.state = v b1)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) := fun dr t2 =>
    (trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c t2 b2 st2 rfl rfl).seq
      (fun ct => by
        dsimp only
        cases (if active then P.define s hist dr.1 else .error "inactive") with
        | error _ =>
          exact (hstep4 Fp2.zero false (dummyWP (slotN P s)) ct.2 (fun _ => (none, []))).congr
            rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2.2) (fun _ _ _ _ hr => hr)
        | ok df =>
          dsimp only
          by_cases hcOk : (active && !ct.1.isZero) = true
          · rw [ite_eq_left hcOk]; dsimp only
            exact (hstep4 _ true _ ct.2 _).congr
              rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2.2) (fun _ _ _ _ hr => hr)
          · rw [ite_eq_right hcOk]; dsimp only
            exact (hstep4 Fp2.zero false _ ct.2 _).congr
              rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h) (fun _ _ hp => hp.2.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep2 : ∀ (dr : List Fp2 × Tr),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbKeyed Lq hL20 key dr.2 labPbSlot (by decide) (le64 (UInt64.ofNat s))).andThen fun t2 =>
          (trChallengeFp2Keyed Lq (by omega) key t2).andThen fun ct =>
            let defRes := if active then P.define s hist dr.1 else .error "inactive"
            let cOk := active && !ct.1.isZero
            let (scActive, scalar, strat) := match defRes with
              | .ok df =>
                if cOk then (true, D.scalar s hist acc df ct.1, D.strat s hist acc df ct.1)
                else (false, Fp2.zero, D.strat s hist acc df ct.1)
              | .error _ => (false, Fp2.zero, dummyWP (slotN P s))
            (trAbsorbFp2Keyed Lq hL20 key ct.2 labPbScalar (by decide) [scalar]).andThen fun t4 =>
              (scProveFixedProg Lq hL20 key (slotN P s) scActive strat t4).andThen fun scr =>
                let (outOpt, terms) := match defRes with
                  | .error _ => (none, [])
                  | .ok df =>
                    if !cOk then (none, [])
                    else
                      let rhoFull := scr.2.1
                      let rho := rhoFull.take (Exec.Block.slotShape P s).1
                      let es := rhoFull.drop (Exec.Block.slotShape P s).1
                      if es.any (fun x => x.isZero || decide (x = Fp2.one)) then (none, [])
                      else
                        let tms := D.terms s hist acc df ct.1 rhoFull
                        match Exec.Block.slotDefChecks P s acc df with
                        | .error _ => (none, tms)
                        | .ok _ =>
                          match Exec.Block.hostedSum acc.scalars scalar df.hosted with
                          | .error _ => (none, tms)
                          | .ok claimed =>
                            match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho tms df.tabs 0 with
                            | .error _ => (none, tms)
                            | .ok vals =>
                              let fin := scFinalExec scr.1 rhoFull claimed
                              let sp : SlotProof := ⟨scalar, scr.1, tms⟩
                              let rec_ : SlotRec := ⟨dr.1, ct.1, scalar, claimed, rho, es, tms, fin⟩
                              let acc' := Exec.Block.slotAcc P s acc df ct.1 scalar
                                ((fin.sub (df.poly vals)).mul ct.1.inv) rhoFull tms
                              (some (sp, rec_, acc'), tms)
                (trAbsorbFp2Keyed Lq hL20 key scr.2.2 labPbTerm (by decide) terms).andThen fun t6 =>
                  .ret (outOpt, t6))
        b1 (1 + (1 + (1 + (k4 + 1)))) (1 + (1 + (1 + (k4 + 1)))) (1 + (1 + (1 + (k4 + 1)))) (1 + (1 + (1 + (k4 + 1)))) 0 0 st1 (st6.cast (by unfold b5 b4 b3 b2 k4; omega))
        (fun _ => False)
        (spliceSched b2 (fun _ => .absorb st1.trTip)
          (spliceSched b3 (spliceSched b3 (fun _ => .squeeze b1) (fun _ => .absorb 0))
            (spliceSched b4 (fun _ => .absorb b2)
              (spliceSched b5 (scFixedSched b4 b3)
                (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0))))))
        (fun _ v => dr.2.state = v st1.trTip)
        (fun _ v res => res.2.key = key ∧ res.2.state = v b5) := fun dr =>
    (trAbsorbSliceSpec hL20 hsep domain shape c dr.2 labPbSlot (by decide) (by decide)
      (le64 (UInt64.ofNat s)) b1 st1 htip1).seq
      (fun t2 => (hstep3 dr t2).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hcomb : SliceSpec Lq tag key domain shape c
      (slotProveFixedProg Lq hL20 key P D s active hist acc t)
      base (slotFixedLen P s) (slotFixedLen P s) (slotFixedLen P s) (slotFixedLen P s) 0 0
      st (trChainTip base (slotFixedLen P s) (by unfold slotFixedLen; omega))
      (fun _ => False)
      (spliceSched b1 (squeezeVecSched base st.trTip)
        (spliceSched b2 (fun _ => .absorb st1.trTip)
          (spliceSched b3 (spliceSched b3 (fun _ => .squeeze b1) (fun _ => .absorb 0))
            (spliceSched b4 (fun _ => .absorb b2)
              (spliceSched b5 (scFixedSched b4 b3)
                (spliceSched (b5 + 1) (fun _ => .absorb st5.trTip) (fun _ => .absorb 0)))))))
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.key = key ∧ res.2.state = v (base + slotFixedLen P s - 1)) :=
    (trChallengeFp2VecSliceSpec (Lq := Lq) (by omega) hsep domain shape c k0 t base st htip hnoPos).seq
      (fun dr => (hstep2 dr).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf)
      (by unfold slotFixedLen k0 k4; omega) (by unfold slotFixedLen k0 k4; omega)
      (by unfold slotFixedLen k0 k4; omega) (by unfold slotFixedLen k0 k4; omega)
      (by omega) (by omega)
      ⟨rfl, by dsimp only [TrChainState.cast, trChainTip, st6, b5, b4, b3, b2, b1, k0, k4, slotFixedLen]; omega, rfl⟩
      (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
      (fun _ _ res _ hr => ⟨hr.1, by
        have heq : b5 = base + slotFixedLen P s - 1 := by unfold slotFixedLen b5 b4 b3 b2 b1 k0 k4; omega
        rw [← heq]; exact hr.2⟩)
  simpa only [slotFixedSched, hst1Tip, hst5Tip, k0, k4, b1, b2, b3, b4, b5] using hcomb

/-- **Fixed-schedule `slotsProve` (`m` slots starting at `s`)**. -/
def slotsProveFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) :
    ℕ → Bool → List SlotRec → ℕ → Acc → Tr →
      PProg (QB Lq) Dig (Option (List SlotProof × List SlotRec × Acc) × Tr)
  | 0, active, recs, _, acc, t => .ret (if active then some ([], recs, acc) else none, t)
  | m + 1, active, recs, s, acc, t =>
    (slotProveFixedProg Lq hL20 key P D s active (Exec.Block.histOf b g a recs) acc t).andThen fun r =>
      match r.1 with
      | none =>
        (slotsProveFixedProg Lq hL20 key P D b g a m false recs (s + 1) acc r.2).andThen fun rest =>
          .ret (none, rest.2)
      | some (sp, rec_, acc') =>
        (slotsProveFixedProg Lq hL20 key P D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2).andThen fun rest =>
          match rest.1 with
          | none => .ret (none, rest.2)
          | some (sps, recs', acc'') => .ret (some (sp :: sps, recs', acc''), rest.2)

def slotsFixedLen (P : BlockParams) : ℕ → ℕ → ℕ
  | _, 0 => 0
  | s, m + 1 => slotFixedLen P s + slotsFixedLen P (s + 1) m

def slotsFixedSched (P : BlockParams) : ℕ → ℕ → ℕ → ℕ → (ℕ → RawPtSpec)
  | _, 0, _, _ => fun _ => .absorb 0
  | s, m + 1, base, tip =>
    let len1 := slotFixedLen P s
    spliceSched (base + len1) (slotFixedSched P s base tip)
      (spliceSched (base + len1 + slotsFixedLen P (s + 1) m)
        (slotsFixedSched P (s + 1) m (base + len1) (base + len1 - 1))
        (fun _ => .absorb 0))

theorem slotsProveFixedProg_run_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      ((slotsProveFixedProg Lq hL20 key P D b g a m false recs s acc t).run G).1 = none
  | 0, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t => by
    unfold slotsProveFixedProg
    rw [PProg.run_andThen, slotProveFixedProg_run_inactive Lq hL20 key P D s _ acc t G]
    dsimp only; rw [PProg.run_andThen, run_ret]

theorem slotsProveFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
        (D.strat s hist acc df (slotC (liftH G) P s t))
        (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + labPbTerm.length + (slotSP (liftH G) P D s hist acc t df).terms.length * 16 ≤ Lq) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr), t.key = key →
      let res := (slotsProveFixedProg Lq hL20 key P D b g a m true recs s acc t).run G
      match slotsProve (liftH G) P D b g a m recs s acc t with
      | .ok (sps, recs', acc', t') => res = (some (sps, recs', acc'), t')
      | .error () => res.1 = none
  | 0, _, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t, htKey => by
    dsimp only
    unfold slotsProveFixedProg slotsProve
    rw [PProg.run_andThen]
    have h1 := slotProveFixedProg_run Lq hL20 key P D s (Exec.Block.histOf b g a recs) acc t htKey G
      (hfitSc s _ acc t) (hfitTerms s _ acc t)
    dsimp only at h1
    cases hsp : slotProve (liftH G) P D s (Exec.Block.histOf b g a recs) acc t with
    | error u =>
      cases u; rw [hsp] at h1; rw [h1]; dsimp only
      rw [PProg.run_andThen, run_ret]
    | ok v1 =>
      rcases v1 with ⟨sp, rec_, acc', t'⟩
      rw [hsp] at h1; rw [h1]; dsimp only
      rw [PProg.run_andThen]
      have ht'Key : t'.key = key :=
        (slotProve_key (liftH G) P D s (Exec.Block.histOf b g a recs) acc t sp rec_ acc' t' hsp).trans htKey
      have h2 := slotsProveFixedProg_run Lq hL20 key P D b g a G hfitSc hfitTerms m (recs ++ [rec_]) (s + 1) acc' t' ht'Key
      dsimp only at h2
      cases hrest : slotsProve (liftH G) P D b g a m (recs ++ [rec_]) (s + 1) acc' t' with
      | error u =>
        cases u; rw [hrest] at h2; rw [h2]; dsimp only; rw [run_ret]
      | ok v2 =>
        rcases v2 with ⟨sps, recs', acc'', t''⟩
        rw [hrest] at h2; rw [h2]; dsimp only; rw [run_ret]

theorem slotsProveFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
      (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false),
    SliceSpec Lq tag key domain shape c
      (slotsProveFixedProg Lq hL20 key P D b g a m active recs s acc t)
      base (slotsFixedLen P s m) (slotsFixedLen P s m) (slotsFixedLen P s m) (slotsFixedLen P s m) 0 0
      st (trChainAfterVec base st (slotsFixedLen P s m))
      (fun _ => False) (slotsFixedSched P s m base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (trChainAfterVec base st (slotsFixedLen P s m)).trTip)
  | 0, active, recs, s, acc, t, base, st, _, _ =>
    (retSliceSpec (if active then some ([], recs, acc) else none, t) base st
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v st.trTip) (fun _ _ hp => hp) (slotsFixedSched P s 0 base st.trTip)).congr
      rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec, slotsFixedLen])
      (fun _ h => h) (fun _ _ hp => hp)
      (fun _ _ _ _ hr => by simp only [trChainAfterVec, slotsFixedLen, ↓reduceDIte]; exact hr)
  | m + 1, active, recs, s, acc, t, base, st, htip, hnoPos => by
    let len1 := slotFixedLen P s
    let len2 := slotsFixedLen P (s + 1) m
    let st1 := trChainTip base len1 (by unfold len1 slotFixedLen; omega)
    have h1 := slotProveFixedSliceSpec hL20 hsep domain shape c P D s active (Exec.Block.histOf b g a recs) acc t base st htip hnoPos
    have h2 : ∀ r : Option (SlotProof × SlotRec × Acc) × Tr,
        SliceSpec Lq tag key domain shape c
          (match r.1 with
          | none =>
            (slotsProveFixedProg Lq hL20 key P D b g a m false recs (s + 1) acc r.2).andThen fun rest =>
              .ret (none, rest.2)
          | some (sp, rec_, acc') =>
            (slotsProveFixedProg Lq hL20 key P D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2).andThen fun rest =>
              match rest.1 with
              | none => .ret (none, rest.2)
              | some (sps, recs', acc'') => .ret (some (sp :: sps, recs', acc''), rest.2))
          (base + len1) len2 len2 len2 len2 0 0 st1 (trChainAfterVec (base + len1) st1 len2)
          (fun _ => False)
          (spliceSched (base + len1 + len2) (slotsFixedSched P (s + 1) m (base + len1) (base + len1 - 1)) (fun _ => .absorb 0))
          (fun _ v => r.2.key = key ∧ r.2.state = v (base + len1 - 1))
          (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) := by
      intro r
      cases hr : r.1 with
      | none =>
        have ih := slotsProveFixedSliceSpec hL20 hsep domain shape c P D b g a m false recs (s + 1) acc r.2 (base + len1) st1 rfl rfl
        exact ih.seq (fun rest => retSliceSpec (none, rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
          (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
          (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp))
          (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
          ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr' => hr')
      | some v1 =>
        rcases v1 with ⟨sp, rec_, acc'⟩
        have ih := slotsProveFixedSliceSpec hL20 hsep domain shape c P D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2 (base + len1) st1 rfl rfl
        exact ih.seq (fun rest =>
          match hrest : rest.1 with
          | none => retSliceSpec (none, rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
              (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
              (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp)
          | some (sps, recs', acc'') => retSliceSpec (some (sp :: sps, recs', acc''), rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
              (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
              (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp))
          (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
          ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr' => hr')
    have hlenAdd : slotsFixedLen P s (m + 1) = len1 + len2 := rfl
    have hlenPos : slotsFixedLen P s (m + 1) ≠ 0 := by
      rw [hlenAdd]; unfold len1 slotFixedLen; omega
    have htipEq : (trChainAfterVec (base + len1) st1 len2).trTip = (trChainAfterVec base st (slotsFixedLen P s (m + 1))).trTip := by
      unfold trChainAfterVec trChainTip st1
      rw [dite_eq_right hlenPos]
      by_cases h0 : len2 = 0
      · rw [dite_eq_left h0]; simp only [hlenAdd, h0, Nat.add_zero]; rfl
      · rw [dite_eq_right h0]; dsimp only; rw [hlenAdd]; omega
    exact h1.seq h2 (fun _ hf => False.elim hf)
      rfl (by rw [hlenAdd]) (by rw [hlenAdd]) (by rw [hlenAdd]) (by omega) (by omega)
      ⟨by unfold trChainAfterVec trChainTip st1; rw [dite_eq_right hlenPos]; split_ifs <;> rfl,
       htipEq,
       by unfold trChainAfterVec trChainTip st1; rw [dite_eq_right hlenPos]; split_ifs <;> rfl⟩
      (fun _ h => by rcases h with h | h <;> exact h)
      (fun _ _ hp => hp)
      (fun _ _ res _ hr => by rwa [← htipEq])

/-! ### 4b. `zkBMaskFixedProg` (`.run` + `SliceSpec`) -/

def zkBMaskFixedLen (S : ℕ) : ℕ :=
  2 * S + 69

def zkBMaskFixedSched (S base tip : ℕ) : ℕ → RawPtSpec :=
  let b1 := base + 1
  let b2 := b1 + 1
  let b3 := b2 + (2 * S + 2)
  let b4 := b3 + 1
  spliceSched b1 (spliceSched b1 (fun _ => .squeeze tip) (fun _ => .absorb 0))
    (spliceSched b2 (fun _ => .absorb base)
      (spliceSched b3 (squeezeVecSched b2 b1)
        (spliceSched b4 (fun _ => .absorb (b3 - 1))
          (spliceSched (b4 + 64) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))))

theorem zkBMaskFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr)
    (htKey : t.key = key) (G : QB Lq → Dig)
    (hfitQ : 48 + maskQLabel.length + (polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF)
        ((t.challengeFp2 (liftH G)).1.toK U))).length * 16 ≤ Lq)
    (hfitP : 48 + maskProxLabel.length + (polyWords U hbij (pPoly U M S
        ((((t.challengeFp2 (liftH G)).2.absorbFp2 (liftH G) maskQLabel
          (polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF)
            ((t.challengeFp2 (liftH G)).1.toK U)))).challengeFp2Vec (liftH G) (2 * S + 2)).1))).length * 16 ≤ Lq)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ 12), tree.path j hj = pathOf (liftH G) tag 12 (mTab S (cosetPt (rootFp 12)) M) j) :
    (zkBMaskFixedProg Lq hL20 key U hbij true M S tree fs t).run G
      = bMask (liftH G) tag U hbij M S fs t := by
  have hrun : (zkBMaskFixedProg Lq hL20 key U hbij true M S tree fs t).run G
      = (zkBMaskProg Lq (by omega) U hbij M S tree fs t).run G := by
    have hL : (zkBMaskFixedProg Lq hL20 key U hbij true M S tree fs t).run G =
        let th := t.challengeFp2 (liftH G)
        let qw := polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF) (th.1.toK U))
        let t1 := th.2.absorbFp2 (liftH G) maskQLabel qw
        let rs := t1.challengeFp2Vec (liftH G) (2 * S + 2)
        let pw := polyWords U hbij (pPoly U M S rs.1)
        let t2 := rs.2.absorbFp2 (liftH G) maskProxLabel pw
        let sq := (sqDs (liftH G) t2 ((mQ + 3) / 4), runOps (liftH G) t2 (List.replicate ((mQ + 3) / 4) Op.squeeze))
        let cols := (idxOf mDom mQ sq.1).map (fun j =>
          ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
        (⟨qw, pw, cols⟩, sq.2) := by
      unfold zkBMaskFixedProg
      simp only [↓reduceIte]
      rw [PProg.run_andThen, trChallengeFp2Keyed_run Lq (by omega) key t htKey G,
        PProg.run_andThen, trAbsorbFp2Keyed_run Lq hL20 key (t.challengeFp2 (liftH G)).2
          (by rw [tr_challengeFp2_key, htKey]) maskQLabel (by decide) _ hfitQ G,
        PProg.run_andThen, trChallengeFp2VecKeyed_run Lq (by omega) key G (2 * S + 2) _
          (by rw [tr_absorbFp2_key, tr_challengeFp2_key, htKey]),
        PProg.run_andThen, trAbsorbFp2Keyed_run Lq hL20 key _
          (by rw [tr_challengeFp2Vec_key, tr_absorbFp2_key, tr_challengeFp2_key, htKey]) maskProxLabel (by decide) _ hfitP G,
        PProg.run_andThen, trSqueezeVecKeyed_run Lq (by omega) key G ((mQ + 3) / 4) _
          (by rw [tr_absorbFp2_key, tr_challengeFp2Vec_key, tr_absorbFp2_key, tr_challengeFp2_key, htKey]),
        run_ret]
    have hR : (zkBMaskProg Lq (by omega) U hbij M S tree fs t).run G =
        let th := t.challengeFp2 (liftH G)
        let qw := polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF) (th.1.toK U))
        let t1 := th.2.absorbFp2 (liftH G) maskQLabel qw
        let rs := t1.challengeFp2Vec (liftH G) (2 * S + 2)
        let pw := polyWords U hbij (pPoly U M S rs.1)
        let t2 := rs.2.absorbFp2 (liftH G) maskProxLabel pw
        let sq := (sqDs (liftH G) t2 ((mQ + 3) / 4), runOps (liftH G) t2 (List.replicate ((mQ + 3) / 4) Op.squeeze))
        let cols := (idxOf mDom mQ sq.1).map (fun j =>
          ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
        (⟨qw, pw, cols⟩, sq.2) := by
      unfold zkBMaskProg
      dsimp only
      rw [PProg.run_andThen, trChallengeFp2Prog_run Lq (by omega) t G,
        PProg.run_andThen, trAbsorbFp2Prog_run Lq _ maskQLabel _ G,
        PProg.run_andThen, trChallengeFp2VecProg_run Lq (by omega) G (2 * S + 2) _,
        PProg.run_andThen, trAbsorbFp2Prog_run Lq _ maskProxLabel _ G,
        PProg.run_andThen, trSqueezeVecProg_run Lq (by omega) G ((mQ + 3) / 4) _,
        run_ret]
    exact hL.trans hR.symm
  rw [hrun]
  exact zkBMaskProg_run Lq (by omega) tag U hbij M S tree fs t G htree

theorem zkBMaskFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (zkBMaskFixedProg Lq hL20 key U hbij active M S tree fs t)
      base (zkBMaskFixedLen S) (zkBMaskFixedLen S) (zkBMaskFixedLen S) (zkBMaskFixedLen S) 0 0
      st (trChainTip base (zkBMaskFixedLen S) (by unfold zkBMaskFixedLen; omega))
      (fun _ => False) (zkBMaskFixedSched S base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + zkBMaskFixedLen S - 1)) := by
  let b1 := base + 1
  let b2 := b1 + 1
  let b3 := b2 + (2 * S + 2)
  let b4 := b3 + 1
  let st1 := trChainTip base 1 Nat.zero_lt_one
  let st2 := trChainTip b1 1 Nat.zero_lt_one
  let st3 := trChainTip b2 (2 * S + 2) (by omega)
  let st4 := trChainTip b3 1 Nat.zero_lt_one
  let st5 := trChainTip b4 64 (by norm_num)
  have hmQ64 : (mQ + 3) / 4 = 64 := by decide
  have hstep5 : ∀ (qw pw : List Fp2) (t2 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trSqueezeVecKeyed Lq (by omega) key ((mQ + 3) / 4) t2).andThen fun sq =>
          let cols := (idxOf mDom mQ sq.1).map (fun j =>
            ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
          .ret ((⟨qw, pw, cols⟩ : Exec.Block.MaskOpening), sq.2))
        b4 64 64 64 64 0 0 st4 st5 (fun _ => False)
        (spliceSched (b4 + 64) (squeezeVecSched b4 b3) (fun _ => .absorb 0))
        (fun _ v => t2.state = v b3)
        (fun _ v res => res.2.state = v (b4 + 64 - 1)) := fun qw pw t2 =>
    let hsq := (trSqueezeVecSliceSpec (Lq := Lq) (by omega) hsep domain shape c ((mQ + 3) / 4) t2 b4 st4 rfl rfl).congr
      hmQ64 (by rw [hmQ64]) (by rw [hmQ64]) (by rw [hmQ64]) le_rfl le_rfl
      (by
        apply TrChainState.ext <;>
          simp only [trChainAfterVec, trChainTip, TrChainState.cast, st5, hmQ64,
            show (64 : ℕ) ≠ 0 by decide, ↓reduceDIte])
      (fun _ h => h) (fun _ _ hp => hp)
      (fun _ _ r _ hr => by
        refine ⟨hr.1, ?_⟩
        unfold trChainAfterVec trChainTip at hr; rw [dite_eq_right (by rw [hmQ64]; omega)] at hr
        simpa [hmQ64] using hr.2)
    hsq.seq (fun sq => retSliceSpec ((⟨qw, pw, (idxOf mDom mQ sq.1).map (fun j =>
        ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))⟩ : Exec.Block.MaskOpening), sq.2) (b4 + 64) st5
      (fun _ v => sq.1 = (List.range ((mQ + 3) / 4)).map (fun k => v (b4 + k)) ∧ sq.2.state = v (b4 + 64 - 1))
      (fun _ v res => res.2.state = v (b4 + 64 - 1)) (fun _ _ hp => hp.2))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep4 : ∀ (qw pw : List Fp2) (t3 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbFp2Keyed Lq hL20 key t3 maskProxLabel (by decide) pw).andThen fun t2 =>
          (trSqueezeVecKeyed Lq (by omega) key ((mQ + 3) / 4) t2).andThen fun sq =>
            let cols := (idxOf mDom mQ sq.1).map (fun j =>
              ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
            .ret ((⟨qw, pw, cols⟩ : Exec.Block.MaskOpening), sq.2))
        b3 (1 + 64) (1 + 64) (1 + 64) (1 + 64) 0 0 st3 (st5.cast (by unfold b4; omega)) (fun _ => False)
        (spliceSched b4 (fun _ => .absorb (b3 - 1))
          (spliceSched (b4 + 64) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))
        (fun _ v => t3.state = v (b3 - 1))
        (fun _ v res => res.2.state = v (b4 + 64 - 1)) := fun qw pw t3 =>
    (trAbsorbSliceSpec hL20 hsep domain shape c t3 maskProxLabel (by decide) (by decide)
      (pw.flatMap Fp2.toBytes) b3 st3 rfl).seq
      (fun t2 => (hstep5 qw pw t2).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h)
      (fun _ _ hp => by simpa only [st3, trChainTip, b3, b2] using hp) (fun _ _ _ _ hr => hr)
  have hstep3 : ∀ (qw : List Fp2) (t1 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trChallengeFp2VecKeyed Lq (by omega) key (2 * S + 2) t1).andThen fun rs =>
          let pw := if active then polyWords U hbij (pPoly U M S rs.1) else []
          (trAbsorbFp2Keyed Lq hL20 key rs.2 maskProxLabel (by decide) pw).andThen fun t2 =>
            (trSqueezeVecKeyed Lq (by omega) key ((mQ + 3) / 4) t2).andThen fun sq =>
              let cols := (idxOf mDom mQ sq.1).map (fun j =>
                ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
              .ret ((⟨qw, pw, cols⟩ : Exec.Block.MaskOpening), sq.2))
        b2 (2 * S + 2 + (1 + 64)) (2 * S + 2 + (1 + 64)) (2 * S + 2 + (1 + 64)) (2 * S + 2 + (1 + 64)) 0 0 st2 (st5.cast (by unfold b4 b3; omega))
        (fun _ => False)
        (spliceSched b3 (squeezeVecSched b2 b1)
          (spliceSched b4 (fun _ => .absorb (b3 - 1))
            (spliceSched (b4 + 64) (squeezeVecSched b4 b3) (fun _ => .absorb 0))))
        (fun _ v => t1.state = v b1)
        (fun _ v res => res.2.state = v (b4 + 64 - 1)) := fun qw t1 =>
    let hch := (trChallengeFp2VecSliceSpec (Lq := Lq) (by omega) hsep domain shape c (2 * S + 2) t1 b2 st2 rfl rfl).congr
      rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by apply TrChainState.ext <;> simp [TrChainState.cast, trChainAfterVec, st3, show 2 * S + 2 ≠ 0 by omega])
      (fun _ h => h) (fun _ _ hp => hp) (fun _ _ r _ hr => by
        unfold trChainAfterVec at hr; rw [dite_eq_right (by omega)] at hr; exact hr)
    hch.seq
      (fun rs => (hstep4 qw (if active then polyWords U hbij (pPoly U M S rs.1) else []) rs.2).congr
        rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ h => h)
        (fun _ _ (hp : _ ∧ rs.2.state = _) => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep2 : ∀ (th : Fp2 × Tr),
      SliceSpec Lq tag key domain shape c
        (let qw := if active then polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF) (th.1.toK U)) else []
         (trAbsorbFp2Keyed Lq hL20 key th.2 maskQLabel (by decide) qw).andThen fun t1 =>
           (trChallengeFp2VecKeyed Lq (by omega) key (2 * S + 2) t1).andThen fun rs =>
             let pw := if active then polyWords U hbij (pPoly U M S rs.1) else []
             (trAbsorbFp2Keyed Lq hL20 key rs.2 maskProxLabel (by decide) pw).andThen fun t2 =>
               (trSqueezeVecKeyed Lq (by omega) key ((mQ + 3) / 4) t2).andThen fun sq =>
                 let cols := (idxOf mDom mQ sq.1).map (fun j =>
                   ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
                 .ret ((⟨qw, pw, cols⟩ : Exec.Block.MaskOpening), sq.2))
        b1 (1 + (2 * S + 2 + (1 + 64))) (1 + (2 * S + 2 + (1 + 64))) (1 + (2 * S + 2 + (1 + 64))) (1 + (2 * S + 2 + (1 + 64)))
        0 0 st1 (st5.cast (by unfold b4 b3 b2; omega)) (fun _ => False)
        (spliceSched b2 (fun _ => .absorb base)
          (spliceSched b3 (squeezeVecSched b2 b1)
            (spliceSched b4 (fun _ => .absorb (b3 - 1))
              (spliceSched (b4 + 64) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))))
        (fun _ v => th.2.state = v base)
        (fun _ v res => res.2.state = v (b4 + 64 - 1)) := fun th =>
    (trAbsorbSliceSpec hL20 hsep domain shape c th.2 maskQLabel (by decide) (by decide)
      ((if active then polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF) (th.1.toK U)) else []).flatMap Fp2.toBytes)
      b1 st1 rfl).seq
      (fun t1 => (hstep3 _ t1).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  unfold zkBMaskFixedProg zkBMaskFixedSched
  dsimp only
  exact (trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c t base st htip hnoPos).seq
    (fun th => (hstep2 th).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
      (fun _ h => h) (fun _ _ hp => hp.2.2) (fun _ _ _ _ hr => hr))
    (fun _ hf => False.elim hf)
    (by unfold zkBMaskFixedLen; omega) (by unfold zkBMaskFixedLen; omega)
    (by unfold zkBMaskFixedLen; omega) (by unfold zkBMaskFixedLen; omega)
    (by omega) (by omega)
    ⟨rfl, by dsimp only [TrChainState.cast, trChainTip, st5, b4, b3, b2, b1, zkBMaskFixedLen]; omega, rfl⟩
    (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
    (fun _ _ res _ hr => by
      have heq : b4 + 64 - 1 = base + zkBMaskFixedLen S - 1 := by unfold zkBMaskFixedLen b4 b3 b2 b1; omega
      rwa [← heq])

/-! ### 4c. `openingAuditFixedProg` (`.run` + `SliceSpec`) -/

theorem groupRhosAux_eq_zkRhosAux (H : HIn → Dig) (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
      let n := (gs.map (fun x => x.2.length)).sum
      let lams := t.challengeFp2Vec H n
      let proxR := lams.2.challengeFp2Vec H rows
      groupRhosAux rows gs lams.1 ++ [proxR.1] = (zkRhosAux H rows gs t).1
        ∧ proxR.2 = (zkRhosAux H rows gs t).2.2
  | [], t => by simp [groupRhosAux, zkRhosAux, Tr.challengeFp2Vec]
  | grp :: rest, t => by
    simp only [List.map_cons, List.sum_cons, zkRhosAux]
    have hadd := chalVec_add_fixed H grp.2.length (rest.map (fun x => x.2.length)).sum t
    have hlen : (t.challengeFp2Vec H grp.2.length).1.length = grp.2.length := chalVec_length H grp.2.length t
    have ih := groupRhosAux_eq_zkRhosAux H rows rest (t.challengeFp2Vec H grp.2.length).2
    dsimp only at ih
    rw [hadd]
    dsimp only
    unfold groupRhosAux
    dsimp only
    rw [List.take_left' hlen, List.drop_left' hlen, List.cons_append, ih.1]
    exact ⟨rfl, ih.2⟩

theorem groupRhosAux_length (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (rem : List Fp2),
      (groupRhosAux rows gs rem).length = gs.length
  | [], _ => rfl
  | _ :: rest, rem => by simp [groupRhosAux, groupRhosAux_length rows rest]

def openingAuditFixedLen (nClaims rows nGroups nQ : ℕ) : ℕ :=
  nClaims + rows + nGroups + 1 + (nQ + 3) / 4

def openingAuditFixedSched (nClaims rows nGroups nQ base tip : ℕ) : ℕ → RawPtSpec :=
  let b1 := base + nClaims
  let b2 := b1 + rows
  let b3 := b2 + nGroups
  let b4 := b3 + 1
  let ksq := (nQ + 3) / 4
  let tip1 := if nClaims = 0 then tip else b1 - 1
  let tip2 := if rows = 0 then tip1 else b2 - 1
  let tip3 := if nGroups = 0 then tip2 else b3 - 1
  spliceSched b1 (squeezeVecSched base tip)
    (spliceSched b2 (squeezeVecSched b1 tip1)
      (spliceSched b3 (absorbVecSched b2 tip2)
        (spliceSched b4 (fun _ => .absorb tip3)
          (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))))

theorem openingAuditFixedProg_run_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig) :
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree false hdrOk cl t).run G).1 = none := by
  unfold openingAuditFixedProg
  simp only [Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]

theorem openingAuditFixedProg_run_core (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (g : OpenGeom) (T : Table) (hrows : rows = T.rows.length) (hgr : g.rows = rows)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hsum : ((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)).sum = nClaims)
    (hglen : (pGroups prm T (cl.map toZClaim)).length = nGroups)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    let res := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree true true cl t).run G
    if openingAuditOk (t.challengeFp2Vec (liftH G) nClaims).1
        ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 g.rows g.prox = true then
      res = (some (bOpen (liftH G) tag prm depth T cl t).1, (bOpen (liftH G) tag prm depth T cl t).2)
    else res.1 = none := by
  dsimp only
  unfold openingAuditFixedProg
  simp only [Bool.true_and, decide_eq_true hsum, decide_eq_true hglen]
  rw [PProg.run_andThen, trChallengeFp2VecKeyed_run Lq (by omega) key G nClaims t htKey,
    PProg.run_andThen, trChallengeFp2VecKeyed_run Lq (by omega) key G rows
      (t.challengeFp2Vec (liftH G) nClaims).2 (by rw [tr_challengeFp2Vec_key, htKey])]
  cases haud : openingAuditOk (t.challengeFp2Vec (liftH G) nClaims).1
      ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 g.rows g.prox with
  | false =>
    simp only [Bool.false_eq_true, ↓reduceIte]
    rw [PProg.run_andThen, PProg.run_andThen, PProg.run_andThen, run_ret]
  | true =>
    simp only [↓reduceIte]
    let gs := pGroups prm T (cl.map toZClaim)
    have hgrEq := groupRhosAux_eq_zkRhosAux (liftH G) rows gs t
    dsimp only at hgrEq
    rw [hsum] at hgrEq
    have hvecsLen : ((groupRhosAux rows gs (t.challengeFp2Vec (liftH G) nClaims).1).map
        (fun rho => combVec (prm.n + prm.qPad) rho T.rows)).length = nGroups := by
      rw [List.length_map, groupRhosAux_length, hglen]
    have hfitVecs : ∀ v ∈ (groupRhosAux rows gs (t.challengeFp2Vec (liftH G) nClaims).1).map
        (fun rho => combVec (prm.n + prm.qPad) rho T.rows), 48 + pcsVecLabel.length + v.length * 16 ≤ Lq := by
      intro v hv
      obtain ⟨rho, _, rfl⟩ := List.mem_map.mp hv
      have hcl : (combVec (prm.n + prm.qPad) rho T.rows).length = prm.n + prm.qPad := by
        unfold combVec; simp
      rwa [hcl]
    have hfitProx : 48 + pcsProxLabel.length +
        (combVec (prm.n + prm.qPad) ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 T.rows).length * 16 ≤ Lq := by
      have hcl : (combVec (prm.n + prm.qPad)
          ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 T.rows).length = prm.n + prm.qPad := by
        unfold combVec; simp
      rwa [hcl]
    rw [PProg.run_andThen, trAbsorbVecsFixed_run Lq hL20 key G nGroups _ _ hvecsLen
        (by rw [tr_challengeFp2Vec_key, tr_challengeFp2Vec_key, htKey]) hfitVecs,
      PProg.run_andThen, trAbsorbFp2Keyed_run Lq hL20 key _
        (by unfold absorbVecs; rw [tr_foldl_absorbFp2_key, tr_challengeFp2Vec_key, tr_challengeFp2Vec_key, htKey])
        pcsProxLabel (by decide) _ hfitProx G,
      PProg.run_andThen, trSqueezeVecKeyed_run Lq (by omega) key G ((prm.nQ + 3) / 4) _
        (by rw [tr_absorbFp2_key]; unfold absorbVecs; rw [tr_foldl_absorbFp2_key, tr_challengeFp2Vec_key, tr_challengeFp2Vec_key, htKey]),
      run_ret]
    have htail := pcsOpenTailProg_run Lq (by omega) tag prm depth hnn hnQ T tree cl t G htree
    unfold pcsOpenTailProg at htail
    dsimp only at htail
    rw [PProg.run_andThen, trAbsorbVecsProg_run, PProg.run_andThen, trAbsorbFp2Prog_run,
      PProg.run_andThen, trSqueezeVecProg_run, run_ret] at htail
    have hpRhos1 : (pRhos (liftH G) prm T (cl.map toZClaim) t).1
        = groupRhosAux rows gs (t.challengeFp2Vec (liftH G) nClaims).1
          ++ [((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1] := by
      unfold pRhos; rw [← hrows]; exact hgrEq.1.symm
    have hpRhos2 : (pRhos (liftH G) prm T (cl.map toZClaim) t).2.2
        = ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).2 := by
      unfold pRhos; rw [← hrows]; exact hgrEq.2.symm
    have hallVecs : (pRhos (liftH G) prm T (cl.map toZClaim) t).1.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)
        = (groupRhosAux rows gs (t.challengeFp2Vec (liftH G) nClaims).1).map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)
          ++ [combVec (prm.n + prm.qPad) ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 T.rows] := by
      rw [hpRhos1, List.map_append, List.map_singleton]
    have htake : ((pRhos (liftH G) prm T (cl.map toZClaim) t).1.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)).take gs.length
        = (groupRhosAux rows gs (t.challengeFp2Vec (liftH G) nClaims).1).map (fun rho => combVec (prm.n + prm.qPad) rho T.rows) := by
      rw [hallVecs]; exact List.take_left' (by rw [List.length_map, groupRhosAux_length])
    have hgetD : ((pRhos (liftH G) prm T (cl.map toZClaim) t).1.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)).getD gs.length []
        = combVec (prm.n + prm.qPad) ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 T.rows := by
      rw [hallVecs, List.getD_eq_getElem?_getD,
        List.getElem?_append_right (by rw [List.length_map, groupRhosAux_length])]
      simp [List.length_map, groupRhosAux_length]
    rw [htake, hgetD, hpRhos2] at htail
    rw [← htail]

theorem openingAuditFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (g : OpenGeom) (T : Table) (hrows : rows = T.rows.length) (hgr : g.rows = rows) (hgg : g.groups = nGroups)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hsumOk : ∀ og, auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox = .ok () →
      openingGroupsAt cl prm.logCols = .ok og → og.length = g.groups → (og.map Prod.snd).sum = nClaims)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    let res := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree true
      (openingHdrOk g prm.logCols cl) cl t).run G
    match checkOpeningExec (liftH G) g prm.logCols cl t with
    | .ok () => res = (some (bOpen (liftH G) tag prm depth T cl t).1, (bOpen (liftH G) tag prm depth T cl t).2)
    | .error _ => res.1 = none := by
  dsimp only
  unfold checkOpeningExec openingHdrOk
  cases haud : auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox with
  | error e =>
    dsimp only [Bind.bind, Except.bind]
    unfold openingAuditFixedProg
    simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
  | ok u =>
    cases u
    cases hog : openingGroupsAt cl prm.logCols with
    | error e =>
      dsimp only [Bind.bind, Except.bind]
      unfold openingAuditFixedProg
      simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
    | ok og =>
      dsimp only [Bind.bind, Except.bind]
      by_cases hgl : og.length ≠ g.groups
      · rw [ite_eq_left hgl, decide_eq_false (fun h => hgl h)]
        unfold openingAuditFixedProg
        simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte,
          throw, throwThe, MonadExceptOf.throw]
      · have hgle : og.length = g.groups := not_not.mp hgl
        rw [ite_eq_right hgl, decide_eq_true hgle]
        have hcounts : og.map Prod.snd = (pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length) :=
          openingGroupsAt_counts_eq_groupZclaims cl T.rows.length prm.logCols og
            (auditClaims_parts_nonempty cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox haud) hog
        have hsum : ((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)).sum = nClaims := by
          rw [← hcounts]; exact hsumOk og haud hog hgle
        have hglen : (pGroups prm T (cl.map toZClaim)).length = nGroups := by
          have h1 := congrArg List.length hcounts
          simp only [List.length_map] at h1
          omega
        have hcore := openingAuditFixedProg_run_core Lq hL20 tag key prm depth nClaims rows nGroups hnn hnQ
          g T hrows hgr tree cl t htKey G hfit hfitP hsum hglen htree
        dsimp only at hcore
        have hchIff := openingChallenges_ok_iff (liftH G) (og.map Prod.snd) g.rows g.prox t
        rw [hcounts, hsum] at hchIff
        cases hch : Exec.Block.openingChallenges (liftH G) (og.map Prod.snd) g.rows g.prox t with
        | ok u' =>
          cases u'
          have hch' : Exec.Block.openingChallenges (liftH G) ((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)) g.rows g.prox t = .ok () := by
            rw [← hcounts]; exact hch
          have hok : openingAuditOk (t.challengeFp2Vec (liftH G) nClaims).1
              ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 g.rows g.prox = true := by
            rw [← hgr]; exact hchIff.mp hch'
          rw [ite_eq_left hok] at hcore; exact hcore
        | error e =>
          have hbad : openingAuditOk (t.challengeFp2Vec (liftH G) nClaims).1
              ((t.challengeFp2Vec (liftH G) nClaims).2.challengeFp2Vec (liftH G) rows).1 g.rows g.prox ≠ true := by
            intro ht; rw [← hgr] at ht
            have h1 := hchIff.mpr ht
            rw [← hcounts, hch] at h1; cases h1
          rw [ite_eq_right hbad] at hcore; exact hcore

theorem openingAuditFixedProg_run_ep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (data n : ℕ) (g : OpenGeom) (hgr : g.rows = data + Exec.StageV.epMaskRows) (hgp : g.prox = data + 2)
    (T : Table) (hrows : data + Exec.StageV.epMaskRows = T.rows.length)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    let res := (openingAuditFixedProg Lq hL20 key prm depth 1 (data + Exec.StageV.epMaskRows) 1 g T tree true
      (tokenEpHdrOk cl data n) cl t).run G
    match Exec.StageV.checkTokenEp (liftH G) cl data n t with
    | .ok () => res = (some (bOpen (liftH G) tag prm depth T cl t).1, (bOpen (liftH G) tag prm depth T cl t).2)
    | .error _ => res.1 = none := by
  dsimp only
  unfold Exec.StageV.checkTokenEp tokenEpHdrOk
  cases cl with
  | nil =>
    unfold openingAuditFixedProg
    simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
  | cons c cs =>
    cases cs with
    | cons _ _ =>
      unfold openingAuditFixedProg
      simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
    | nil =>
      cases hp : c.parts with
      | nil =>
        dsimp only; rw [hp]
        unfold openingAuditFixedProg
        simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
      | cons p0 ps1 =>
        cases ps1 with
        | nil =>
          dsimp only; rw [hp]
          unfold openingAuditFixedProg
          simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
        | cons p1 ps2 =>
          cases ps2 with
          | nil =>
            dsimp only; rw [hp]
            unfold openingAuditFixedProg
            simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
          | cons p2 ps3 =>
            cases ps3 with
            | cons _ _ =>
              dsimp only; rw [hp]
              unfold openingAuditFixedProg
              simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]
            | nil =>
              by_cases hcnd : Exec.StageV.partRows p0 n = (0, data)
                  ∧ Exec.StageV.partRows p1 n = (data, data + 1)
                  ∧ Exec.StageV.partRows p2 n = (data + 1, data + 2)
                  ∧ (p0 :: p1 :: p2 :: []).all (fun p => !p.coef.isZero) = true
              · dsimp only
                rw [hp]
                dsimp only
                rw [ite_eq_left hcnd, decide_eq_true hcnd]
                have hpg : (pGroups prm T ([c].map toZClaim)).length = 1
                    ∧ ((pGroups prm T ([c].map toZClaim)).map (fun x => x.2.length)).sum = 1 := by
                  unfold pGroups groupZclaims groupStep keyIdx
                  simp [List.map, toZClaim, hp]
                have hcore := openingAuditFixedProg_run_core Lq hL20 tag key prm depth 1
                  (data + Exec.StageV.epMaskRows) 1 hnn hnQ g T hrows hgr tree [c] t htKey G hfit hfitP hpg.2 hpg.1 htree
                dsimp only at hcore
                have hchIff := openingChallenges_ok_iff (liftH G) [1] (data + Exec.StageV.epMaskRows) (data + 2) t
                simp only [List.sum_cons, List.sum_nil, Nat.add_zero] at hchIff
                cases hch : Exec.Block.openingChallenges (liftH G) [1] (data + Exec.StageV.epMaskRows) (data + 2) t with
                | ok u' =>
                  cases u'
                  have hok : openingAuditOk (t.challengeFp2Vec (liftH G) 1).1
                      ((t.challengeFp2Vec (liftH G) 1).2.challengeFp2Vec (liftH G) (data + Exec.StageV.epMaskRows)).1 g.rows g.prox = true := by
                    rw [hgr, hgp]; exact hchIff.mp hch
                  rw [ite_eq_left hok] at hcore; exact hcore
                | error e =>
                  have hbad : openingAuditOk (t.challengeFp2Vec (liftH G) 1).1
                      ((t.challengeFp2Vec (liftH G) 1).2.challengeFp2Vec (liftH G) (data + Exec.StageV.epMaskRows)).1 g.rows g.prox ≠ true := by
                    intro ht; rw [hgr, hgp] at ht
                    have := hchIff.mpr ht; rw [hch] at this; cases this
                  rw [ite_eq_right hbad] at hcore; exact hcore
              · dsimp only
                rw [hp]
                dsimp only
                rw [ite_eq_right hcnd, decide_eq_false hcnd]
                unfold openingAuditFixedProg
                simp only [Bool.and_false, Bool.false_and, PProg.run_andThen, run_ret, Bool.false_eq_true, ↓reduceIte]

theorem openingAuditFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active : Bool) (hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t)
      base (openingAuditFixedLen nClaims rows nGroups prm.nQ) (openingAuditFixedLen nClaims rows nGroups prm.nQ)
      (openingAuditFixedLen nClaims rows nGroups prm.nQ) (openingAuditFixedLen nClaims rows nGroups prm.nQ) 0 0
      st (trChainTip base (openingAuditFixedLen nClaims rows nGroups prm.nQ) (by unfold openingAuditFixedLen; omega))
      (fun _ => False) (openingAuditFixedSched nClaims rows nGroups prm.nQ base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + openingAuditFixedLen nClaims rows nGroups prm.nQ - 1)) := by
  let b1 := base + nClaims
  let b2 := b1 + rows
  let b3 := b2 + nGroups
  let b4 := b3 + 1
  let ksq := (prm.nQ + 3) / 4
  let st1 := trChainAfterVec base st nClaims
  let st2 := trChainAfterVec b1 st1 rows
  let st3 := trChainAfterVec b2 st2 nGroups
  let st4 := trChainTip b3 1 Nat.zero_lt_one
  let st5 := trChainAfterVec b4 st4 ksq
  have htip1 : st1.hasTip = true := by unfold st1 trChainAfterVec; split_ifs <;> [exact htip; rfl]
  have hnoPos1 : st1.afterPosTag = false := by unfold st1 trChainAfterVec; split_ifs <;> [exact hnoPos; rfl]
  have htip2 : st2.hasTip = true := by unfold st2 trChainAfterVec; split_ifs <;> [exact htip1; rfl]
  have htip3 : st3.hasTip = true := by unfold st3 trChainAfterVec; split_ifs <;> [exact htip2; rfl]
  have hst1Tip : st1.trTip = if nClaims = 0 then st.trTip else b1 - 1 := by
    unfold st1 trChainAfterVec trChainTip b1; split_ifs <;> rfl
  have hst2Tip : st2.trTip = if rows = 0 then st1.trTip else b2 - 1 := by
    unfold st2 trChainAfterVec trChainTip b2; split_ifs <;> rfl
  have hst3Tip : st3.trTip = if nGroups = 0 then st2.trTip else b3 - 1 := by
    unfold st3 trChainAfterVec trChainTip b3; split_ifs <;> rfl
  have hst5Tip : st5.trTip = base + openingAuditFixedLen nClaims rows nGroups prm.nQ - 1 := by
    simp only [st5, trChainAfterVec, trChainTip, st4, openingAuditFixedLen, b4, b3, b2, b1, ksq]
    split_ifs <;> (dsimp only; omega)
  have hstep5 : ∀ (auditPass : Bool) (vecs : List (List Fp2)) (prox : List Fp2) (t2 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trSqueezeVecKeyed Lq (by omega) key ksq t2).andThen fun sq =>
          let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
          .ret (if auditPass then some (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk) else none, sq.2))
        b4 ksq ksq ksq ksq 0 0 st4 st5 (fun _ => False)
        (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0))
        (fun _ v => t2.state = v b3)
        (fun _ v res => res.2.state = v st5.trTip) := fun auditPass vecs prox t2 =>
    (trSqueezeVecSliceSpec (Lq := Lq) (by omega) hsep domain shape c ksq t2 b4 st4 rfl rfl).seq
      (fun sq => retSliceSpec
        (if auditPass then some (⟨vecs, prox, (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))⟩ : Exec.Block.OpeningZk) else none, sq.2)
        (b4 + ksq) st5
        (fun _ v => sq.1 = (List.range ksq).map (fun k => v (b4 + k)) ∧ sq.2.state = v st5.trTip)
        (fun _ v res => res.2.state = v st5.trTip) (fun _ _ hp => hp.2))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep4 : ∀ (auditPass : Bool) (vecs : List (List Fp2)) (prox : List Fp2) (t1 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbFp2Keyed Lq hL20 key t1 pcsProxLabel (by decide) prox).andThen fun t2 =>
          (trSqueezeVecKeyed Lq (by omega) key ksq t2).andThen fun sq =>
            let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
            .ret (if auditPass then some (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk) else none, sq.2))
        b3 (1 + ksq) (1 + ksq) (1 + ksq) (1 + ksq) 0 0 st3 (st5.cast (by unfold b4; omega)) (fun _ => False)
        (spliceSched b4 (fun _ => .absorb st3.trTip)
          (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))
        (fun _ v => t1.state = v st3.trTip)
        (fun _ v res => res.2.state = v st5.trTip) := fun auditPass vecs prox t1 =>
    (trAbsorbSliceSpec hL20 hsep domain shape c t1 pcsProxLabel (by decide) (by decide)
      (prox.flatMap Fp2.toBytes) b3 st3 htip3).seq
      (fun t2 => (hstep5 auditPass vecs prox t2).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hstep3 : ∀ (auditPass : Bool) (vecs : List (List Fp2)) (prox : List Fp2) (t0 : Tr),
      SliceSpec Lq tag key domain shape c
        ((trAbsorbVecsFixed Lq hL20 key nGroups vecs t0).andThen fun t1 =>
          (trAbsorbFp2Keyed Lq hL20 key t1 pcsProxLabel (by decide) prox).andThen fun t2 =>
            (trSqueezeVecKeyed Lq (by omega) key ksq t2).andThen fun sq =>
              let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
              .ret (if auditPass then some (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk) else none, sq.2))
        b2 (nGroups + (1 + ksq)) (nGroups + (1 + ksq)) (nGroups + (1 + ksq)) (nGroups + (1 + ksq)) 0 0 st2 (st5.cast (by unfold b4 b3; omega))
        (fun _ => False)
        (spliceSched b3 (absorbVecSched b2 st2.trTip)
          (spliceSched b4 (fun _ => .absorb st3.trTip)
            (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0))))
        (fun _ v => t0.state = v st2.trTip)
        (fun _ v res => res.2.state = v st5.trTip) := fun auditPass vecs prox t0 =>
    (trAbsorbVecsFixedSliceSpec hL20 hsep domain shape c nGroups vecs t0 b2 st2 htip2).seq
      (fun t1 => hstep4 auditPass vecs prox t1)
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  let gs := pGroups prm T (cl.map toZClaim)
  let preOk := active && hdrOk && decide ((gs.map (fun x => x.2.length)).sum = nClaims) && decide (gs.length = nGroups)
  have hstep2 : ∀ (lams : List Fp2 × Tr),
      SliceSpec Lq tag key domain shape c
        ((trChallengeFp2VecKeyed Lq (by omega) key rows lams.2).andThen fun proxR =>
          let auditPass := preOk && openingAuditOk lams.1 proxR.1 g.rows g.prox
          let vecs := if auditPass then (groupRhosAux rows gs lams.1).map (fun rho => combVec (prm.n + prm.qPad) rho T.rows) else []
          let prox := if auditPass then combVec (prm.n + prm.qPad) proxR.1 T.rows else []
          (trAbsorbVecsFixed Lq hL20 key nGroups vecs proxR.2).andThen fun t1 =>
            (trAbsorbFp2Keyed Lq hL20 key t1 pcsProxLabel (by decide) prox).andThen fun t2 =>
              (trSqueezeVecKeyed Lq (by omega) key ksq t2).andThen fun sq =>
                let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
                .ret (if auditPass then some (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk) else none, sq.2))
        b1 (rows + (nGroups + (1 + ksq))) (rows + (nGroups + (1 + ksq)))
        (rows + (nGroups + (1 + ksq))) (rows + (nGroups + (1 + ksq))) 0 0 st1 (st5.cast (by unfold b4 b3 b2; omega))
        (fun _ => False)
        (spliceSched b2 (squeezeVecSched b1 st1.trTip)
          (spliceSched b3 (absorbVecSched b2 st2.trTip)
            (spliceSched b4 (fun _ => .absorb st3.trTip)
              (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0)))))
        (fun _ v => lams.2.state = v st1.trTip)
        (fun _ v res => res.2.state = v st5.trTip) := fun lams =>
    (trChallengeFp2VecSliceSpec (Lq := Lq) (by omega) hsep domain shape c rows lams.2 b1 st1 htip1 hnoPos1).seq
      (fun proxR => (hstep3 _ _ _ proxR.2).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf) (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      ⟨rfl, rfl, rfl⟩ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hcomb : SliceSpec Lq tag key domain shape c
      (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t)
      base (openingAuditFixedLen nClaims rows nGroups prm.nQ) (openingAuditFixedLen nClaims rows nGroups prm.nQ)
      (openingAuditFixedLen nClaims rows nGroups prm.nQ) (openingAuditFixedLen nClaims rows nGroups prm.nQ) 0 0
      st (trChainTip base (openingAuditFixedLen nClaims rows nGroups prm.nQ) (by unfold openingAuditFixedLen; omega))
      (fun _ => False)
      (spliceSched b1 (squeezeVecSched base st.trTip)
        (spliceSched b2 (squeezeVecSched b1 st1.trTip)
          (spliceSched b3 (absorbVecSched b2 st2.trTip)
            (spliceSched b4 (fun _ => .absorb st3.trTip)
              (spliceSched (b4 + ksq) (squeezeVecSched b4 b3) (fun _ => .absorb 0))))))
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + openingAuditFixedLen nClaims rows nGroups prm.nQ - 1)) :=
    (trChallengeFp2VecSliceSpec (Lq := Lq) (by omega) hsep domain shape c nClaims t base st htip hnoPos).seq
      (fun lams => (hstep2 lams).congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl
        (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr))
      (fun _ hf => False.elim hf)
      (by unfold openingAuditFixedLen ksq; omega) (by unfold openingAuditFixedLen ksq; omega)
      (by unfold openingAuditFixedLen ksq; omega) (by unfold openingAuditFixedLen ksq; omega)
      (by omega) (by omega)
      ⟨by unfold st5 trChainAfterVec st4 trChainTip; split_ifs <;> rfl,
       by dsimp only [trChainTip]; exact hst5Tip,
       by unfold st5 trChainAfterVec st4 trChainTip; split_ifs <;> rfl⟩
      (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp)
      (fun _ _ res _ hr => by rwa [hst5Tip] at hr)
  simpa only [openingAuditFixedSched, hst1Tip, hst2Tip, hst3Tip, b1, b2, b3, b4, ksq] using hcomb

end AtomicSlices

end ZK60.HonestShield
