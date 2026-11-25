/-
D63 lane L69, Milestone B (`HonestShieldHooks.lean`):
models the Rust verifier's real header policy (`preA`, `preB`), per-block statement check
(`check0`), and block-digest projection (`digest`) for the R13 Shieldstral classifier run
(`classify_run.rs:74-80, 338-374`, `classify.rs:1109-1117`, `run.rs:250-263`), proves
non-trivial refusal theorems on mismatched headers/blocks, eliminates the standalone
`hV131072` premise via `ShieldRunReg`, and discharges `hpol`, `hdig`, and `hCheck0` through
`HonestShieldTop.shdP_honest_productionReadyL`.

### Scope & Honesty Notes
1. `shdPreA`, `shdPreB`, `shdCheck0`, and `shdDigest` formalize the concrete deterministic
   header/table/block-digest policy checks of `verify_classify_run_with` and
   `stage_block_is_the_statements`; `bndCheck` stays `shdP_bndCheckPure` because L63's
   `d12aBlockProf.bndCheck` signature takes no oracle `H` (`cbBndOpen` still checks `pcsVerify`).
2. `W_zk : ShdZKProgWitness` remains the single open premise here (closed separately in
   Milestone A). Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`).
-/
import ZK60Formal.HonestShieldTop

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Exec.StageCheck ZK60.Sound
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP ZK60.RunShape ZK60.RunShape.Shield
open ZK60.HonestRun ZK60.HonestOpen

/-! ## 1. Concrete Shieldstral verifier policy, registered tables, and header structure -/

/-- Verifier policy parameters (D27 whole-run security floor, e.g. `95` bits in production). -/
structure ShdPolicy where
  minWholeRunBits : ℕ

/-- Verifier's pinned registered tables and model identity (`N-r13-1`, `classify.rs:1109-1117`). -/
structure ShdRegTables where
  modelId : Dig
  profileSha : Dig
  isDerived : Bool
  embDigest : Dig
  wDigest : Dig
  bos : ℕ

/-- Concrete classifier run header checked by `verify_classify_run_with`:
carries the transcript header words `w : ClsHdrW` (bounded to fit the hash-input length `Lq`,
making `hhdrFit` non-vacuous and proved by `hd.wFit`) alongside the D27/N-r13-1/R13 metadata
fields verified by `preA`, `preB`, and `check0`. -/
structure ShdHdr (Lq : ℕ) where
  w : ClsHdrW
  wFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq
  wholeRunBits : ℕ
  nBlocks : ℕ
  tierOk : Bool
  nttOk : Bool
  modelId : Dig
  profileSha : Dig
  isDerived : Bool
  embDigest : Dig
  wDigest : Dig
  bos : ℕ
  blkDigests : Fin 26 → Dig

/-- Header-word projection `hw : ShdHdr Lq → ClsHdrW`. -/
def shdHdrW {Lq : ℕ} (h : ShdHdr Lq) : ClsHdrW := h.w

/-- Concrete `preA` (`verify_classify_run_with`, `classify_run.rs:340-350`, `classify.rs:1109-1117`):
checks tier, NTT table fit, D27 whole-run floor, block count `= 26`, and N-r13-1 table binding
(`modelId`, `profileSha`, `isDerived`, `embDigest`, `wDigest`, `bos`). -/
def shdPreA {Lq : ℕ} (policy : ShdPolicy) (reg : ShdRegTables) (h : ShdHdr Lq) : Except String Unit :=
  if h.tierOk ≠ true then .error "classifier run: invalid tier"
  else if h.nttOk ≠ true then .error "classifier run: shape does not fit NTT tables"
  else if h.wholeRunBits < policy.minWholeRunBits then
    .error "classifier run: whole-run floor below D27 policy minimum"
  else if h.nBlocks ≠ 26 then .error "classifier run: expected 26 blocks"
  else if h.modelId ≠ reg.modelId ∨ h.profileSha ≠ reg.profileSha ∨ h.isDerived ≠ reg.isDerived then
    .error "classifier run: tables bound to another trained statement (N-r13-1)"
  else if h.embDigest ≠ reg.embDigest ∨ h.wDigest ≠ reg.wDigest ∨ h.bos ≠ reg.bos then
    .error "classifier run: tables do not match statement digests/BOS (N-r13-1)"
  else .ok ()

/-- Concrete `preB` (`classify_run.rs:366-374`, R13 pre-header block-digest check across all 26 blocks). -/
def shdPreB {Lq : ℕ} (regBlkDig : Fin 26 → Dig) (h : ShdHdr Lq) : Except String Unit :=
  if ∀ k : Fin 26, h.blkDigests k = regBlkDig k then .ok ()
  else .error "classifier run: block digest mismatch in pre-header check (CS-6)"

/-- Concrete per-block statement check `check0` (`stage_block_is_the_statements`, `classify_run.rs:74-80`):
verifies `k < 26` and that statement header's block digest at `k` matches the registered export block `k`
(weight-class validity CS-1/CS-4 is enforced by `hweights : ∀ b ∈ Rp.blks, b.pub.Valid`). -/
def shdCheck0 {Lq : ℕ} (regBlkDig : Fin 26 → Dig) (s : ClsStmt (ShdHdr Lq)) (k : ℕ) : Except String Unit :=
  if hk : k < 26 then
    if s.hdr.blkDigests ⟨k, hk⟩ = regBlkDig ⟨k, hk⟩ then .ok ()
    else .error "classifier run: block digest mismatch (CS-6)"
  else .error "classifier run: block index out of range"

/-- Concrete block-digest projection `digest : ClsStmt (ShdHdr Lq) → ℕ → Dig`. -/
def shdDigest {Lq : ℕ} (s : ClsStmt (ShdHdr Lq)) (k : ℕ) : Dig :=
  if hk : k < 26 then s.hdr.blkDigests ⟨k, hk⟩ else zeroDig

/-- Registered block-digest function extended by `zeroDig` outside `0..25`. -/
def shdBlkDigFn (regBlkDig : Fin 26 → Dig) (k : ℕ) : Dig :=
  if hk : k < 26 then regBlkDig ⟨k, hk⟩ else zeroDig

/-- Honest header constructed from the verifier's policy, registered tables, registered block digests,
and transcript header words `w` fitting `Lq`. -/
def shdHonestHdr {Lq : ℕ} (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig) (w : ClsHdrW)
    (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) : ShdHdr Lq where
  w := w
  wFit := hwFit
  wholeRunBits := wholeRunBits
  nBlocks := 26
  tierOk := true
  nttOk := true
  modelId := reg.modelId
  profileSha := reg.profileSha
  isDerived := reg.isDerived
  embDigest := reg.embDigest
  wDigest := reg.wDigest
  bos := reg.bos
  blkDigests := regBlkDig

/-! ## 2. Tightened registered-profile predicate eliminating standalone `hV131072` -/

/-- Tightened registered Shieldstral R13 run predicate: combines `ShieldRun Rp` (all 26 layer
calibrations match `shieldExport`) with the registered vocabulary size `Rp.inp.V = 131072`
(as constructed by `StageX.Valid.shieldIn`, `StageCheckValid.lean:97`). -/
def ShieldRunReg (Rp : ClassifyRunPublicP shieldS0) : Prop :=
  ShieldRun Rp ∧ Rp.inp.V = 131072

theorem shieldRunReg_of_shieldIn (q : List ℕ) (n : ℕ) (emb : ℕ → Fin 3072 → ℤ)
    (bs : List (RunBlock shieldS0)) (hbs : bs.map RunBlock.cal = shieldExport.map shieldCal)
    (out : Out.OutCPublic shieldS0.d) (row : Fin 128) :
    ShieldRunReg (⟨StageX.Valid.shieldIn shieldS0 q n emb, bs, out, row⟩ : ClassifyRunPublicP shieldS0) :=
  ⟨hbs, rfl⟩

/-! ## 3. Honest-path discharge lemmas & non-trivial negative controls -/

theorem shdPreA_honest {Lq : ℕ} (policy : ShdPolicy) (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) (hfloor : policy.minWholeRunBits ≤ wholeRunBits) :
    shdPreA policy reg (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) = .ok () := by
  have hlt : ¬ wholeRunBits < policy.minWholeRunBits := Nat.not_lt.mpr hfloor
  simp [shdPreA, shdHonestHdr, hlt]

theorem shdPreB_honest {Lq : ℕ} (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) :
    shdPreB regBlkDig (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) = .ok () := by
  simp [shdPreB, shdHonestHdr]

theorem shdCheck0_honest {Lq : ℕ} (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) (r : Dig) (v : ℕ) (k : ℕ) (hk : k < 26) :
    shdCheck0 regBlkDig (honestStmt (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) r v) k = .ok () := by
  simp [shdCheck0, honestStmt, shdHonestHdr, hk]

theorem shdDigest_honest {Lq : ℕ} (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) (r : Dig) (v : ℕ) (k : ℕ) (hk : k < 26) :
    shdDigest (honestStmt (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) r v) k = shdBlkDigFn regBlkDig k := by
  simp [shdDigest, shdBlkDigFn, honestStmt, shdHonestHdr, hk]

/-- Non-triviality control 1: `shdPreA` refuses a header below the D27 whole-run security floor. -/
theorem shdPreA_refuses_low_floor {Lq : ℕ} (policy : ShdPolicy) (reg : ShdRegTables) (h : ShdHdr Lq)
    (htier : h.tierOk = true) (hntt : h.nttOk = true) (hlow : h.wholeRunBits < policy.minWholeRunBits) :
    ∃ msg, shdPreA policy reg h = .error msg :=
  ⟨"classifier run: whole-run floor below D27 policy minimum", by simp [shdPreA, htier, hntt, hlow]⟩

/-- Non-triviality control 2: `shdPreA` refuses a header whose embedding digest disagrees with `reg`. -/
theorem shdPreA_refuses_bad_embDigest {Lq : ℕ} (policy : ShdPolicy) (reg : ShdRegTables) (h : ShdHdr Lq)
    (htier : h.tierOk = true) (hntt : h.nttOk = true) (hfloor : policy.minWholeRunBits ≤ h.wholeRunBits)
    (hnb : h.nBlocks = 26) (hmid : h.modelId = reg.modelId) (hps : h.profileSha = reg.profileSha)
    (hder : h.isDerived = reg.isDerived) (hemb : h.embDigest ≠ reg.embDigest) :
    ∃ msg, shdPreA policy reg h = .error msg := by
  have hlt : ¬ h.wholeRunBits < policy.minWholeRunBits := Nat.not_lt.mpr hfloor
  exact ⟨"classifier run: tables do not match statement digests/BOS (N-r13-1)",
    by simp [shdPreA, htier, hntt, hlt, hnb, hmid, hps, hder, hemb]⟩

/-- Non-triviality control 3: `shdPreB` refuses a header with any mismatched block digest. -/
theorem shdPreB_refuses_bad_block {Lq : ℕ} (regBlkDig : Fin 26 → Dig) (h : ShdHdr Lq)
    (k : Fin 26) (hne : h.blkDigests k ≠ regBlkDig k) :
    ∃ msg, shdPreB regBlkDig h = .error msg := by
  have hnot : ¬ (∀ j : Fin 26, h.blkDigests j = regBlkDig j) := fun hall => hne (hall k)
  exact ⟨"classifier run: block digest mismatch in pre-header check (CS-6)", by simp [shdPreB, hnot]⟩

/-- Non-triviality control 4: `shdCheck0` refuses a statement whose block `k` digest disagrees with `regBlkDig`. -/
theorem shdCheck0_refuses_bad_block {Lq : ℕ} (regBlkDig : Fin 26 → Dig) (s : ClsStmt (ShdHdr Lq))
    (k : ℕ) (hk : k < 26) (hne : s.hdr.blkDigests ⟨k, hk⟩ ≠ regBlkDig ⟨k, hk⟩) :
    ∃ msg, shdCheck0 regBlkDig s k = .error msg :=
  ⟨"classifier run: block digest mismatch (CS-6)", by simp [shdCheck0, hk, hne]⟩

/-! ## 4. Top-level concrete-hook `ProductionReadyL` corollary -/

/-- **Concrete-verifier-hooks `ProductionReadyL` corollary (`L69`, pure ROM)**:
instantiates `HonestShieldTop.shdP_honest_productionReadyL` with the concrete non-trivial
header-policy checks `shdPreA policy reg`, `shdPreB regBlkDig`, per-block statement check
`shdCheck0 regBlkDig`, and block-digest projection `shdDigest`, discharging `hhdrFit`, `hpol`,
`hdig`, `hCheck0`, `hV131072` (from `ShieldRunReg`), and all eight block/opening-check hypotheses.
The single remaining structured premise is `W_zk : ShdZKProgWitness`. -/
theorem shdP_honest_productionReadyL_hooks {Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
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
      (shdP_honestRunP tag Rp hReg.1 hweights hinPub houtPub
        (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
        (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
        (shdCheck0 regBlkDig) shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl)
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
        (shdP_honestRunP tag Rp hReg.1 hweights hinPub houtPub
          (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
          (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
          (shdCheck0 regBlkDig) shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl)
          epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin (ShdHdr Lq) tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := ShdHdr Lq) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  shdP_honest_productionReadyL tag Lq hL20 hL64 key w.shape Rp hReg.1 shdHdrW (fun hd => hd.wFit)
    (shdPreA policy reg) (shdPreB regBlkDig) (shdCheck0 regBlkDig) shdDigest
    (fun _ _ cl _ => shdP_bndCheckPure cl) 34 32 (checkField shdP_blkOpenGeom)
    reg.embDigest 32 reg.wDigest 34
    (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩)
    (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused (shdBlkDigFn regBlkDig)
    (shdDigest_honest reg regBlkDig w hwFit wholeRunBits)
    hReg.2 hweights hinPub houtPub
    ⟨shdPreA_honest policy reg regBlkDig w hwFit wholeRunBits hfloor,
     shdPreB_honest reg regBlkDig w hwFit wholeRunBits⟩
    epBase incRndOf blkRndOf outcRndOf
    (fun k hk _ _ _ _ => shdCheck0_honest reg regBlkDig w hwFit wholeRunBits _ _ k hk)
    shdP_blk_hgrpA_of_checkOpeningExec
    shdP_blk_hgrpH_of_checkOpeningExec
    (fun _ _ _ cl _ h => shdP_blk_hgrpB_of_pure cl h)
    (fun _ _ _ e h => ⟨e, h⟩)
    (fun _ _ _ e h => ⟨e, h⟩)
    (fun G _ _ cl t e _ herr => shdP_bndCheckPure_err_implies_checkOpeningExec (liftH G) cl t e herr)
    W_zk

end ZK60.HonestShield
