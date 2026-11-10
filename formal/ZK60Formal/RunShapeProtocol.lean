/-
D63 lane L40 (2026-11-10), part 3: **the protocol layer of the per-block-shape run** (`RunShape.lean`): the classify
run's `Protocol` instances at `classifyModelP`, the run's extraction predicates with block `k` read AT ITS OWN SHAPE,
the run link to the model, completeness, binding, zero knowledge's transfer, the open obligations, and the joint gate.

Where L18's, L24's and L26's proofs used that all blocks share one shape, and what replaces it (the rest re-indexes `S`
by the block):
* the run link: `runSat_of_blocks` / `runOn_of_blocks` (AssembleClassify.lean) chain the blocks' `BlockOn` through
  L2's one-shape `RunSat`; here `runSatP_of_blocks` / `runOnP_of_blocks` chain block `k`'s `BlockOn` AT ITS OWN SHAPE
  (`BlockOn R.blks[k].pub`, L18's own predicate at that block's shape) into `RunSatP`;
* the model: `classify_run_link` / `classify_inner_of_stages` (StageRunExtract.lean) conclude L2's `classifySat`; here
  `classify_run_linkP` / `classify_inner_of_stagesP` conclude `classifySatP`, and `iopExtract_of_jointP` gives
  `IOPExtract (classifyModelP R) (classifyArithP R)`;
* `CircuitIff`: `classifyRunP_circuitIff` (RunShape.lean) instead of L2's `classifyRun_circuitIff`;
* completeness reads the model only through `admissible` (canonical ids, `admissible_canonP`) and the honest verdict
  `classifySpecP`; the proof is L18's.
Nothing else in these layers reads a block's shape: the verifier `classifyVerifyE V`, the opening `opensIn`, the
honest prover's skeleton `runProve`, the commitment and the leakage's `T`, `d`, `L` are the run's, shared by every
block (`S` below is the run's CARRIER, of which only `T` and `d` are read).

The instances (`classifyProtocolP`, `classifyProtocolUP`) are L18's and L26's with the model replaced: the same
statement, receipt, salt, leakage fields, `ypub`, `opensIn` / `opensOut`, THE SAME verifier term; the honest prover
publishes `classifySpecP`'s verdict.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `clsLeakP`, **`classifyProtocolP`**, **`classifyProtocolUP`**, `verify_true_iffP`, `verifyUP_eq`, `prove_unservedP`,
  `leak_servedP`, `opensIn_iffP`, `clsStmtOfP`, `prove_servedP`, `proveUP_eq`;
* `InOkP`, `BlocksOkP`, `OutOkP`, `EpOkP`, `JointOkP`, `JointExtractP`, `RunOnP`, **`runSatP_of_blocks`**,
  `runOnP_of_blocks`, `classify_run_linkP`, `classify_inner_of_stagesP`, **`iopExtract_of_jointP`**,
  `jointExtractP_of_kinds`;
* `admissible_canonP`, `classifyP_complete`, `classifyP_complete_sites`, **`classifyP_complete_target`**,
  `completeUP_of_completeP`, `zkUP_of_zkP`, `classifyUP_binding_target`, `classifyP_binding_target`;
* `ClassifyOpenP` (L18's `ClassifyOpen` without O11, which the joint gates never read, and with O1 per block),
  `ClassifyOpenP.valid`;
* **`classifyP_productionReady_joint`**, **`classifyUP_productionReady_joint`**,
  **`classifyUP_productionReady_joint_target`**: L24's and L26's joint gates at the per-block-shape model.
-/
import ZK60Formal.RunShape
import ZK60Formal.ProtocolClassifyU

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify.RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Complete ZK60.RunShape
open ZK60.Circuit (gP GF obind_eq_some)
open ZK60.Block (BlockShape BlockPublic BlockSat i16 i16_eq_of_cast)
open ZK60.Out (OutCSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## The instances -/

open Classical in
/-- The per-block-shape run's leakage of an input: L18's fields (`T`, `d`, the block count, the served bit). The
blocks' shapes are public data of the model, the same for every input. -/
noncomputable def clsLeakP (R : ClassifyRunPublicP S) (x : S.Tok → ℕ) : ClsLeak :=
  ⟨S.T, S.d, R.blks.length, decide ((classifyModelP R).admissible x)⟩

/-- **THE `Protocol` INSTANCE of the classify run, one shape per block** (L18's `classifyProtocol` at the model
`classifyModelP R`): the same statement, receipt, salt, `ypub`, openings and verifier; the honest prover's verdict is
`classifySpecP`'s. -/
noncomputable def classifyProtocolP (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) : Protocol (QB Lq) Dig Coins (classifyModelP R) where
  Stmt := ClsStmt Hdr
  Receipt := ClsReceipt
  Salt := Salt
  Leak := ClsLeak
  leak := clsLeakP R
  ypub s := s.verdict
  opensIn G s x r := ZK60.Exec.opensIn (M := classifyModelP R) Cin h64 hr G s x r
  opensOut G s y r := ZK60.Exec.opensUnit G s y r
  prove G _ x c := runProve V P (classifyModelP R).admissible (liftH G) (honestRoot Cin Lq h64 hr G x (base c))
    ((classifySpecP R x).getD 0) x c
  verify G _ s rc := okB (classifyVerifyE V (liftH G) s rc)

/-- **THE `Protocol` INSTANCE with the input opening at radius `e`, one shape per block** (L26's `classifyProtocolU`
at the model `classifyModelP R`). -/
noncomputable def classifyProtocolUP (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) : Protocol (QB Lq) Dig Coins (classifyModelP R) where
  Stmt := ClsStmt Hdr
  Receipt := ClsReceipt
  Salt := Salt
  Leak := ClsLeak
  leak := clsLeakP R
  ypub s := s.verdict
  opensIn G s x r := Cin.OpensU Lq h64 hr e G s x r
  opensOut G s y r := ZK60.Exec.opensUnit G s y r
  prove G _ x c := runProve V P (classifyModelP R).admissible (liftH G) (honestRoot Cin Lq h64 hr G x (base c))
    ((classifySpecP R x).getD 0) x c
  verify G _ s rc := okB (classifyVerifyE V (liftH G) s rc)

section Instance

variable (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
  (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)

/-- **The instance's verdict is `verify_classify_run_with`'s structure** (`classifyVerifyE V`), the same term as L18's. -/
theorem verify_true_iffP (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolP R Lq V P Cin h64 hr base).verify G () s rc = true
      ↔ classifyVerifyE V (liftH G) s rc = .ok () := by
  show okB (classifyVerifyE V (liftH G) s rc) = true ↔ _
  rw [okB_eq_true]
  exact ⟨fun ⟨u, h⟩ => by cases u; exact h, fun h => ⟨(), h⟩⟩

/-- **The same verifier at every radius.** -/
theorem verifyUP_eq (e : ℕ) (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUP R Lq V P Cin h64 hr base e).verify G () s rc
      = (classifyProtocolP R Lq V P Cin h64 hr base).verify G () s rc :=
  rfl

/-- **The same verifier as L18's and L26's instances** at any one-shape run data (the verifier never reads the model). -/
theorem verifyP_eq_old (R0 : ClassifyRunPublic S) (e : ℕ) (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUP R Lq V P Cin h64 hr base e).verify G () s rc
      = (classifyProtocolU S R0 Lq V P Cin h64 hr base e).verify G () s rc :=
  rfl

/-- **D65(2): an unserved input's output is the ONE constant refusal.** -/
theorem prove_unservedP (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) (hx : ¬ (classifyModelP R).admissible x) :
    (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x c = (P.refused, []) := by
  show runProve V P (classifyModelP R).admissible (liftH G) _ _ x c = _
  unfold runProve
  rw [ite_eq_right hx]

/-- The leakage carries the served bit. -/
theorem leak_servedP (x : S.Tok → ℕ) :
    ((classifyProtocolP R Lq V P Cin h64 hr base).leak x).served = true ↔ (classifyModelP R).admissible x := by
  show (clsLeakP R x).served = true ↔ _
  classical
  simp [clsLeakP]

/-- `opensIn` is L10's opening, by definition. -/
theorem opensIn_iffP (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocolP R Lq V P Cin h64 hr base).opensIn G s x r
      ↔ opensIn (M := classifyModelP R) Cin h64 hr G s x r :=
  Iff.rfl

/-- **The instance's honest statement**: the registered header, the honest input root, the per-block model's verdict. -/
noncomputable def clsStmtOfP (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) : ClsStmt Hdr :=
  honestStmt P.hdr (honestRoot Cin Lq h64 hr G x (base c)) ((classifySpecP R x).getD 0)

/-- **A served input's output** is the honest statement and the parts' honest segments, whenever no part refuses. -/
theorem prove_servedP (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) (hx : (classifyModelP R).admissible x)
    (r : List (List UInt8) × Carry × Tr)
    (hr' : honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (base c)) ((classifySpecP R x).getD 0) x c = .ok r) :
    (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x c = (clsStmtOfP R Lq P Cin h64 hr base G x c, r.1) := by
  show runProve V P (classifyModelP R).admissible (liftH G) _ _ x c = _
  unfold runProve
  rw [ite_eq_left hx, hr']
  rfl

/-- **The same honest prover at every radius.** -/
theorem proveUP_eq (e : ℕ) (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) :
    (classifyProtocolUP R Lq V P Cin h64 hr base e).prove G () x c
      = (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x c :=
  rfl

/-- **`Complete` transfers** to the radius-`e` instance (L26's `completeU_of_complete`). -/
theorem completeUP_of_completeP [Fintype Coins] [Nonempty Coins] (e : ℕ) {εc : ℝ≥0∞}
    (h : Complete (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) εc) :
    Complete (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) εc := by
  intro W x hx
  refine le_trans (h W x hx) ?_
  unfold prHC
  refine MeasureTheory.measure_mono ?_
  rintro ⟨H, c⟩ ⟨h1, h2, ⟨r, h3⟩, h4⟩
  exact ⟨h1, h2, ⟨r, Cin.opensU_of_opens Lq h64 hr e H _ x r h3⟩, h4⟩

/-- **`ZeroKnowledge` transfers** to the radius-`e` instance (neither world reads `opensIn`; L26's `zkU_of_zk`). -/
theorem zkUP_of_zkP [Fintype Coins] [Nonempty Coins] [Inhabited Coins] (e : ℕ) {εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) εzk) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) εzk := by
  obtain ⟨Sim, hS⟩ := h
  exact ⟨Simulator.mk (State := Sim.State) (SCoins := Sim.SCoins) (fin := Sim.fin) (ne := Sim.ne) (inh := Sim.inh)
    Sim.init Sim.step, fun W q R' Dist hD => hS W q R' Dist hD⟩

/-- **`Binding` at the approved target for the radius-`e` instance** (L26's `binding_classifierU_target`). -/
theorem classifyUP_binding_target (e : ℕ) (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN : Cin.N ≤ 2 ^ 20)
    (hdi : Cin.depth ≤ 64) :
    Binding (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) εsTarget := by
  have : Subsingleton (classifyModelP R).HidOut := inferInstanceAs (Subsingleton Unit)
  exact binding_classifierU_target (classifyProtocolUP R Lq V P Cin h64 hr base e) Cin h64 hr e he
    (fun _ _ _ _ => Iff.rfl) hN hdi

/-- **`Binding` at the approved target for the all-columns instance** (L10's `binding_classifier_target`). -/
theorem classifyP_binding_target (hdi : Cin.depth ≤ 64) :
    Binding (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) εsTarget := by
  have : Subsingleton (classifyModelP R).HidOut := inferInstanceAs (Subsingleton Unit)
  exact binding_classifier_target (classifyProtocolP R Lq V P Cin h64 hr base) Cin h64 hr
    (fun G s x r => opensIn_iffP R Lq V P Cin h64 hr base G s x r) hdi

end Instance

/-! ## The run's extraction, block `k` at its own shape -/

/-- Stage IN-C's conclusion on the extracted data (L18's `InOk`; it reads the run data's stage IN-C only). -/
def InOkP (R : ClassifyRunPublicP S) {Salt : Type} (e : RunExt S Salt) : Prop :=
  InSat R.inp e.tokW (e.planes 0) ∧ ∀ t, e.epW t = e.tokW t

/-- **The blocks' conclusions, block `k` AT ITS OWN SHAPE**: L18's `BlockOn` at block `k`'s public data (so at
`R.blks[k].cal.over S`) on the run's boundary planes `B_k`, `B_{k+1}`. -/
def BlocksOkP (R : ClassifyRunPublicP S) {Salt : Type} (e : RunExt S Salt) : Prop :=
  ∀ (k : ℕ) (hk : k < R.blks.length), BlockOn R.blks[k].pub (e.planes k) (e.planes (k + 1))

/-- Stage OUT-C's conclusion for the statement's verdict `b` (L18's `OutOk`). -/
def OutOkP (R : ClassifyRunPublicP S) {Salt : Type} (b : ℕ) (e : RunExt S Salt) : Prop :=
  b ≤ 1 ∧ OutCSat R.out e.xC b ∧ ∀ i, e.xC i = e.planes R.blks.length (R.row, i)

/-- The input endpoint opens to the extracted words read canonically (L18's `EpOk`). -/
def EpOkP {Lq : ℕ} {Coins : Type} {R : ClassifyRunPublicP S} (P : Protocol (QB Lq) Dig Coins (classifyModelP R))
    (G : QB Lq → Dig) (s : P.Stmt) (e : RunExt S P.Salt) : Prop :=
  P.opensIn G s (fun t => canonWord (e.epW t)) e.r

/-- **Every part's conclusion on the extracted data** (L24's `JointOk`). -/
def JointOkP {Lq : ℕ} {Coins : Type} (R : ClassifyRunPublicP S) (P : Protocol (QB Lq) Dig Coins (classifyModelP R))
    (G : QB Lq → Dig) (s : P.Stmt) (e : RunExt S P.Salt) : Prop :=
  InOkP R e ∧ BlocksOkP R e ∧ OutOkP R (P.ypub s) e ∧ EpOkP P G s e

/-- **The run's extraction premise as ONE event** (L24's `JointExtract`). -/
def JointExtractP {Lq : ℕ} {Coins : Type} (R : ClassifyRunPublicP S)
    (P : Protocol (QB Lq) Dig Coins (classifyModelP R)) (εs : ℕ → ℝ≥0∞) : Prop :=
  ∃ E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt,
    ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ JointOkP R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εs q

/-- The blocks' part on the extracted boundary planes, one shape per block (L12's `RunOn` with `RunSatP`). -/
def RunOnP (bs : List (RunBlock S)) (Bin Bout : S.Pos → GF) : Prop :=
  ∃ x y : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ (∀ p, Bin p = (x p : GF)) ∧
    (∀ p, Bout p = (y p : GF)) ∧ RunSatP bs x y

/-- **The blocks' conclusions, each at its own shape, chain into the run's constraint system** (L18's
`runSat_of_blocks` with a shape per block): the int16 preimage of a plane is unique (`i16_eq_of_cast`), so block
`k`'s output preimage IS block `k + 1`'s input preimage, whatever the two blocks' shapes. -/
theorem runSatP_of_blocks : ∀ (bs : List (RunBlock S)) (X : ℕ → S.Pos → GF) (x0 : S.Pos → ℤ),
    (∀ p, i16 (x0 p)) → (∀ p, X 0 p = (x0 p : GF)) →
    (∀ (k : ℕ) (hk : k < bs.length), BlockOn bs[k].pub (X k) (X (k + 1))) →
    ∃ y : S.Pos → ℤ, (∀ p, i16 (y p)) ∧ (∀ p, X bs.length p = (y p : GF)) ∧ RunSatP bs x0 y
  | [], X, x0, hx0, hX0, _ => ⟨x0, hx0, hX0, rfl⟩
  | b :: bs, X, x0, hx0, hX0, hb => by
    have h0 := hb 0 (by simp)
    rw [List.getElem_cons_zero] at h0
    obtain ⟨x, x', hx, hx', hX, hX', w, hw⟩ := h0
    have hxx : x = x0 := funext fun p => i16_eq_of_cast (hx p) (hx0 p) (by rw [← hX p, hX0 p])
    subst hxx
    obtain ⟨y, hy, hXy, hr⟩ := runSatP_of_blocks bs (fun k => X (k + 1)) x' hx' hX' (fun k hk => by
      have h := hb (k + 1) (by simp only [List.length_cons]; omega)
      rw [List.getElem_cons_succ] at h
      exact h)
    refine ⟨y, hy, fun p => by simpa using hXy p, ?_⟩
    simp only [RunSatP]
    exact ⟨x', hx', ⟨w, hw⟩, hr⟩

/-- **`RunOnP` from the per-block conclusions at their own shapes.** -/
theorem runOnP_of_blocks (bs : List (RunBlock S)) (X : ℕ → S.Pos → GF) (hpos : 0 < bs.length)
    (hb : ∀ (k : ℕ) (hk : k < bs.length), BlockOn bs[k].pub (X k) (X (k + 1))) : RunOnP bs (X 0) (X bs.length) := by
  obtain ⟨x, _, hx, _, hX, _, _⟩ := hb 0 hpos
  obtain ⟨y, hy, hXy, hr⟩ := runSatP_of_blocks bs X x hx hX hb
  exact ⟨x, y, hx, hy, hX, hXy, hr⟩

/-- **The classifier run's links, one shape per block** (L12's `classify_run_link` with `RunOnP`): stage IN-C's
relation, the blocks' on the extracted boundary planes, stage OUT-C's with OUTC-00's identity and SIC_IO's endpoint
identity give `classifySatP` on the canonical endpoint words. -/
theorem classify_run_linkP {Dg : Type} (R : ClassifyRunPublicP S) (F : RunFrame Dg S) (tokW epW : S.Tok → GF)
    (xC : Fin S.d → GF) (b : ℕ) (hb : b ≤ 1) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOnP R.blks (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutCSat R.out xC b)
    (hio : ∀ i, xC i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t) :
    classifySatP R (fun t => canonWord (epW t)) b := by
  obtain ⟨x, y, hx, hy, hX, hY, hr⟩ := hrun
  have e1 : (fun t => ((canonWord (epW t) : ℕ) : GF)) = tokW := funext fun t => by rw [canonWord_cast, hep]
  have e2 : (fun p => ((x p : ℤ) : GF)) = F.ext F.rootIn := funext fun p => by rw [← hX, F.link_in]
  have e3 : (fun i => ((y (R.row, i) : ℤ) : GF)) = xC := funext fun i => by rw [hio, F.link_out, hY]
  exact ⟨fun t => canonWord_lt _, hb, x, y, hx, hy, (congrArg₂ (InSat R.inp) e1 e2).mpr hin, hr,
    (congrArg (fun f => OutCSat R.out f b) e3).mpr hout⟩

/-- **The endpoints, one shape per block** (L12's `classify_inner_of_stages`): the inner predicate of `IOPExtract`
for `classifyModelP R` / `classifyArithP R`. -/
theorem classify_inner_of_stagesP {Q D Coins' Dg : Type} (R : ClassifyRunPublicP S)
    (P : Protocol Q D Coins' (classifyModelP R)) (H : Q → D) (s : P.Stmt) (F : RunFrame Dg S) (tokW epW : S.Tok → GF)
    (xC : Fin S.d → GF) (b : ℕ) (hb : b ≤ 1) (r r' : P.Salt) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOnP R.blks (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutCSat R.out xC b)
    (hio : ∀ i, xC i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t)
    (hopen : P.opensIn H s (fun t => canonWord (epW t)) r) (hpub : P.ypub s = b)
    (hopenOut : P.opensOut H s () r') :
    (classifyArithP R).Satisfies () (fun t => canonWord (epW t)) b ()
      ∧ P.opensIn H s (fun t => canonWord (epW t)) r
      ∧ P.ypub s = (classifyModelP R).publicPart b
      ∧ P.opensOut H s ((classifyModelP R).hiddenPart b) r' :=
  ⟨classify_run_linkP R F tokW epW xC b hb hin hrun hout hio hep, hopen, hpub, hopenOut⟩

/-- **`IOPExtract` for the per-block-shape model from the joint extraction premise** (L24's `iopExtract_of_joint`). -/
theorem iopExtract_of_jointP {Lq : ℕ} {Coins' : Type} (R : ClassifyRunPublicP S)
    (P : Protocol (QB Lq) Dig Coins' (classifyModelP R)) (hopenOut : ∀ G s y r, P.opensOut G s y r)
    (hpos : 0 < R.blks.length) {εs : ℕ → ℝ≥0∞} (hX : JointExtractP R P εs) :
    IOPExtract (classifyModelP R) (classifyArithP R) P εs := by
  obtain ⟨E, hE⟩ := hX
  refine ⟨fun lg s pf => ((fun t => canonWord ((E lg s pf).epW t)), P.ypub s, (), (E lg s pf).r, (E lg s pf).r'),
    fun W q A hA => ?_⟩
  have hW : W = () := rfl
  subst hW
  refine le_trans (ZK60.ProtocolClassify.prH_mono (B := fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ JointOkP R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ?_) (hE q A hA)
  intro G hG
  obtain ⟨hver, hbad⟩ := hG
  refine ⟨hver, fun hall => ?_⟩
  obtain ⟨hin, hblk, hout, hep⟩ := hall
  obtain ⟨hInSat, hepw⟩ := hin
  obtain ⟨hb1, hOut, hio⟩ := hout
  exact hbad (classify_inner_of_stagesP R P G (A.runLog G).1.1
    (boundaryFrame (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes R.blks.length)
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).tokW (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).epW
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC (P.ypub (A.runLog G).1.1) hb1
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r'
    hInSat (runOnP_of_blocks R.blks (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes hpos hblk)
    hOut hio hepw hep rfl (hopenOut _ _ _ _))

/-- **The joint extraction from ONE list of kinds shared by all parts** (L24's `jointExtract_of_kinds`). -/
theorem jointExtractP_of_kinds {Lq : ℕ} {Coins' : Type} (R : ClassifyRunPublicP S)
    (P : Protocol (QB Lq) Dig Coins' (classifyModelP R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (Ks : List (FirstKind Lq (P.Stmt × P.Receipt)))
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOkP R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
        Ex A G ∨ ∃ K ∈ Ks, K.Ev A G) :
    JointExtractP R P (εKinds Ks εx) :=
  ⟨E, fun q A hA => ext_of_kinds_min Ks
    (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ JointOkP R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
    Ex εx hEx (fun A G hG => hcover A G hG.1 hG.2) q A hA⟩

/-! ## Completeness (L18's proof at the per-block model) -/

/-- **An admissible item's ids are canonical words** (`< p`). -/
theorem admissible_canonP (R : ClassifyRunPublicP S) (hR : R.inp.Valid) (x : S.Tok → ℕ)
    (hx : (classifyModelP R).admissible x) : ∀ t, x t < gP := by
  obtain ⟨b, hb⟩ := hx
  unfold classifySpecP at hb
  obtain ⟨y, hy, -⟩ := obind_eq_some.mp hb
  exact fun t => lt_gP_of_V hR ((inSpec_some hy).1 t)

section Complete

variable [Fintype Coins] [Nonempty Coins]

/-- **`Complete` for the per-block-shape classify run** (L18's `classify_complete`, the same premises at
`classifyModelP R`). -/
theorem classifyP_complete (R : ClassifyRunPublicP S) (hR : R.inp.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModelP R).admissible liftH
      (clsStmtOfP R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    {ι : Type} [Fintype ι] (Ref : ι → (S.Tok → ℕ) → (QB Lq → Dig) → Coins → Prop) (ε : ι → ℝ≥0∞)
    (hrefuse : ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ Ref i x G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c
        = .ok r)
    (hε : ∀ x, (classifyModelP R).admissible x → ∀ i, prHC (fun G c => Ref i x G c) ≤ ε i) :
    Complete (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base) (∑ i, ε i) := by
  refine complete_of_checks _ (fun i _ x G c => ¬ Ref i x G c) ε ?_ ?_
  · intro W x hx G c hall
    obtain ⟨⟨bs, crf, tf⟩, hseg⟩ := hrefuse x hx G c hall
    have hprove := prove_servedP R Lq V P Cin h64 hr hon.base G x c hx _ hseg
    have hW : W = () := rfl
    subst hW
    rw [hprove]
    refine ⟨?_, rfl, ?_, ⟨hon.base c, trivial⟩⟩
    · rw [verify_true_iffP]
      unfold classifyVerifyE
      simp only [ex_bind_ok_iff, countOk_eq_ok]
      have hlen : bs.length = V.L + 2 := by
        rw [proveSegs_length _ _ _ _ _ (P.parts V.L) carry0 _ bs crf tf hseg, RunP.parts_length]
      have hrun := runSegs_of_proveSegs (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr hon.base)
        G x c _ hx (P.parts V.L) V.parts hparts carry0 _ bs crf tf hseg
      exact ⟨(), hpreA, (), hlen, (), hpreB, (crf, tf), hrun, trivial⟩
    · exact honestIn_opens Cin hon Lq h64 hr G _ x c (hokC x (admissible_canonP R hR x hx)) hN (hroot _)
  · intro W x hx i
    simpa only [not_not] using hε x hx i

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **`Complete` with the sites' own bounds** (L18's `classify_complete_sites`). -/
theorem classifyP_complete_sites (R : ClassifyRunPublicP S) (hR : R.inp.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModelP R).admissible liftH
      (clsStmtOfP R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (hkOf : ∀ x i, (site x i).k ≤ kOf i)
    (δOf : ι → ℝ≥0∞) (hδOf : ∀ x i, (site x i).δ ≤ δOf i)
    (hrefuse : ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c
        = .ok r) :
    Complete (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base)
      (∑ i, (((kOf i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + δOf i)) := by
  refine classifyP_complete R hR Lq V P Cin h64 hr hon hokC hN hroot hpreA hpreB hparts
    (fun i x G c => (site x i).fires U G c) _ hrefuse (fun x _ i => ?_)
  refine ((site x i).prob_le U hbij).trans (add_le_add ?_ (hδOf x i))
  exact ENNReal.div_le_div_right (by exact_mod_cast Nat.mul_le_mul_right _ (hkOf x i)) _

/-- **`Complete` at the approved target `εcTarget = 2^-40`** (L18's `classify_complete_target`). -/
theorem classifyP_complete_target (R : ClassifyRunPublicP S) (hR : R.inp.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModelP R).admissible liftH
      (clsStmtOfP R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (hkOf : ∀ x i, (site x i).k ≤ kOf i) (δOf : ι → ℝ≥0∞) (hδOf : ∀ x i, (site x i).δ ≤ δOf i)
    (hkT : ∑ i, kOf i ≤ 2 ^ 85) (hδT : ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41)
    (hrefuse : ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c
        = .ok r) :
    Complete (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base) εcTarget :=
  Assembly.complete_mono (classifyP_complete_sites R hR Lq V P Cin h64 hr hon hokC hN hroot hpreA hpreB hparts U hbij
    site kOf hkOf δOf hδOf hrefuse) (refusal_total_le_target kOf δOf hkT hδT)

end Complete

/-! ## The open obligations, and the joint gates -/

section Gate

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **The per-block-shape classify run's OPEN obligations**: L18's `ClassifyOpen` at `classifyModelP R`, with O1 per
block and without O11 (the joint gates below take the run's extraction as ONE premise instead, as L24's and L26's
joint gates do, which never read `ClassifyOpen`'s O11). -/
structure ClassifyOpenP (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (U : K) {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (εzk : ℕ → ℕ → ℝ≥0∞) : Prop where
  /-- O1 (the run): the width in the geometry's class. -/
  width : S.d ≤ 4096
  /-- O1 (per block): every block's OWN shape in the code's class (`BlockShape.Valid`; at the app, PROVED by
  `RunShapeShield.shield_shapes_valid`). -/
  shapes : ∀ b ∈ R.blks, (b.cal.over S).Valid
  /-- O2: every block's public data in its classes (`BlockPublic.Valid`). -/
  weights : ∀ b ∈ R.blks, b.pub.Valid
  /-- O3: stage IN-C's public data. -/
  inPub : R.inp.Valid
  /-- O4: stage OUT-C's public data. -/
  outPub : R.out.Valid
  /-- O5: the run has blocks, and the verifier's block count is the model's. -/
  blocks : 0 < R.blks.length ∧ V.L = R.blks.length
  /-- O6: the input endpoint commitment's geometry. -/
  commit : (∀ x, (∀ t, x t < gP) → Cin.ok x) ∧ Cin.N ≤ 2 ^ Cin.depth ∧ (∀ s, Cin.root s = s.inRoot) ∧ Cin.depth ≤ 64
  /-- O7: the verifier's own pre-header policy accepts the registered header. -/
  policy : V.preA P.hdr = .ok () ∧ V.preB P.hdr = .ok ()
  /-- O8: every part's completeness contract, the honest statement carrying the per-block model's verdict. -/
  parts : List.Forall₂ (SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr hon.base))
    (P.parts V.L) V.parts
  /-- O9: the honest prover refuses only at a listed site. -/
  refuse : ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
    ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c = .ok r
  /-- O10: the sites' counts within the completeness budget. -/
  counts : (∀ x i, (site x i).k ≤ kOf i) ∧ (∀ x i, (site x i).δ ≤ δOf i) ∧ ∑ i, kOf i ≤ 2 ^ 85
    ∧ ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41
  /-- O12: zero knowledge of the classify run as ONE receipt, at the per-block model. -/
  zk : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base) εzk

omit [DecidableEq K] in
/-- The run data's validity from the open obligations. -/
theorem ClassifyOpenP.valid {R : ClassifyRunPublicP S} {Lq : ℕ} {V : RunV Hdr} {P : RunP Hdr (S.Tok → ℕ) Coins}
    {Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt} {h64 : 64 ≤ Lq} {hr : 8 * Cin.R ≤ Lq} {hon : HonestIn Coins Cin}
    {U : K} {ι : Type} [Fintype ι] {site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K} {kOf : ι → ℕ} {δOf : ι → ℝ≥0∞}
    {εzk : ℕ → ℕ → ℝ≥0∞} (O : ClassifyOpenP R Lq V P Cin h64 hr hon U site kOf δOf εzk) : R.Valid :=
  ⟨O.width, O.inPub, fun b hb => ⟨O.shapes b hb, O.weights b hb⟩, O.outPub⟩

/-- **THE GATE through the joint extraction, all-columns opening, one shape per block** (L24's
`classify_productionReady_joint` at `classifyModelP R`): every open obligation and the joint extraction premise. -/
theorem classifyP_productionReady_joint (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    {εzk : ℕ → ℕ → ℝ≥0∞} (O : ClassifyOpenP R Lq V P Cin h64 hr hon U site kOf δOf εzk) {εs : ℕ → ℝ≥0∞}
    (hJ : JointExtractP R (classifyProtocolP R Lq V P Cin h64 hr hon.base) εs) :
    ProductionReady (classifyModelP R) (classifyArithP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base)
      εcTarget εs εsTarget εzk := by
  obtain ⟨hokC, hN, hroot, hdep⟩ := O.commit
  exact productionReady_of (classifyRunP_circuitIff R O.valid)
    (iopExtract_of_jointP R _ (fun _ _ _ _ => trivial) O.blocks.1 hJ)
    (classifyP_complete_target R O.inPub Lq V P Cin h64 hr hon hokC hN hroot O.policy.1 O.policy.2 O.parts U hbij site
      kOf O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse)
    (classifyP_binding_target R Lq V P Cin h64 hr hon.base hdep)
    O.zk

/-- **THE GATE at the radius-`e` instance through the joint extraction, one shape per block** (L26's
`classifyU_productionReady_joint` at `classifyModelP R`). -/
theorem classifyUP_productionReady_joint (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    {εzk : ℕ → ℕ → ℝ≥0∞} (O : ClassifyOpenP R Lq V P Cin h64 hr hon U site kOf δOf εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20) {εs : ℕ → ℝ≥0∞}
    (hJ : JointExtractP R (classifyProtocolUP R Lq V P Cin h64 hr hon.base e) εs) :
    ProductionReady (classifyModelP R) (classifyArithP R) (classifyProtocolUP R Lq V P Cin h64 hr hon.base e)
      εcTarget εs εsTarget εzk := by
  obtain ⟨hokC, hN, hroot, hdep⟩ := O.commit
  exact productionReady_of (classifyRunP_circuitIff R O.valid)
    (iopExtract_of_jointP R _ (fun _ _ _ _ => trivial) O.blocks.1 hJ)
    (completeUP_of_completeP R Lq V P Cin h64 hr hon.base e
      (classifyP_complete_target R O.inPub Lq V P Cin h64 hr hon hokC hN hroot O.policy.1 O.policy.2 O.parts U hbij
        site kOf O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse))
    (classifyUP_binding_target R Lq V P Cin h64 hr hon.base e he hN20 hdep)
    (zkUP_of_zkP R Lq V P Cin h64 hr hon.base e O.zk)

/-- **THE GATE at the radius-`e` instance at the approved targets, from ONE list of kinds, one shape per block**
(L26's `classifyU_productionReady_joint_target`). -/
theorem classifyUP_productionReady_joint_target (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εzk : ℕ → ℕ → ℝ≥0∞} (O : ClassifyOpenP R Lq V P Cin h64 hr hon U site kOf δOf εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (L : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUP R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOkP R (classifyProtocolUP R Lq V P Cin h64 hr hon.base e) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G)
    (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModelP R) (classifyArithP R) (classifyProtocolUP R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  productionReady_mono
    (classifyUP_productionReady_joint R Lq V P Cin h64 hr hon U hbij site kOf δOf O e he hN20
      (jointExtractP_of_kinds R (classifyProtocolUP R Lq V P Cin h64 hr hon.base e) E (L.map Prod.fst) Ex εx hEx
        hcover))
    le_rfl (joint_le_target L εx cx hℓ hlin hx hbud) (fun _ => le_rfl) hzk

end Gate

end ZK60.ProtocolClassify.RunShapeP
