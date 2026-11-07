/-
D63 lane L18 (2026-11-07), part 4: **the assembly of the media app's classify run into the approved gate**
`ProductionReady (classifyModel S R) (classifyArith S R) P εc εs εb εzk` (Statements.lean, unchanged), via
`productionReady_of` (Assembly.lean), with the remaining obligations as ONE structure of named premises
(`ClassifyOpen`), each of the precise shape the component lane must deliver.

Discharged here (PROVED):
* `CircuitIff`: `classifyRun_circuitIff` (L2), from the shape's and the run data's validity;
* `Binding` at the proposed target `εsTarget`: lane L10's `binding_classifier_target` (the input endpoint is a plane
  commitment, depth `≤ 64`; the classifier's hidden output is `Unit`);
* `Complete` at `εcTarget = 2^-40`: `classify_complete_target` (this lane), from the parts' completeness contracts,
  the refusal sites and their counts;
* the IOP extraction's LINK part: `iopExtract_of_runExtract` turns the run's extraction premise (one extractor; the
  stage IN-C, blocks, stage OUT-C and endpoint conclusions on ONE extracted plane per boundary) into `IOPExtract`,
  through L12's `classify_inner_of_stages` and this file's `runOn_of_blocks` (the blocks' per-block conclusions,
  chained through the boundary planes, are `RunOn`);
* `KnowledgeSound` and `SemanticHiding` from the assembly's generic lemmas (`productionReady_of`).

What is proved:
* `BlockOn`, **`runSat_of_blocks`**, **`runOn_of_blocks`**: block `k`'s conclusion on the extracted planes of boundaries
  `k` and `k + 1` (the shape lane L16 must deliver, per block) chains into the run's `RunOn`;
* `boundaryFrame`: one extracted plane per boundary index is a `RunFrame` (B_in is block 0's input, B_L stage OUT-C's);
* `RunExt`, `InOk`, `BlocksOk`, `OutOk`, `EpOk`, `RunExtract`: the run's extraction premise;
* `prH_or_le`, **`iopExtract_of_runExtract`**: `RunExtract … εin εblk εout εep → IOPExtract … (εin + εblk + εout + εep)`;
* `ClassifyOpen`: the open obligations, each a named field;
* **`classify_productionReady`**: `ClassifyOpen … → ProductionReady (classifyModel S R) (classifyArith S R) P εcTarget
  (εin + εblk + εout + εep) εsTarget εzk`;
* `extract_split_le_target`, **`classify_productionReady_target`**: with the extraction's parts within the target's
  halves and the zero-knowledge premise in the hybrid form of `zeroKnowledge_target_of_hybrid`, the gate at the
  approved targets `(εcTarget, εsTarget, εsTarget, εzkTarget)` (`productionReady_mono`);
* `shield_inp_valid`: stage IN-C's half of `R.Valid` for the registered Shieldstral category policies (L15's
  `shield_in_valid`).

Every premise is an explicit hypothesis (a field of `ClassifyOpen` or an argument); no `sorry`, axiom or
`native_decide`.
-/
import ZK60Formal.ProtocolClassifyComplete
import ZK60Formal.ProtocolClassifyFS
import ZK60Formal.StageRunExtract
import ZK60Formal.StageCheckValid
import ZK60Formal.ZKHybrid

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat RunSat i16 i16_eq_of_cast)

variable {S : BlockShape}

/-! ## The blocks' conclusions, chained through the boundary planes -/

/-- **Block `k`'s conclusion on the extracted boundary planes** (the shape lane L16 delivers per block, W16R2; lane L17
at R13): the planes `Xin` (boundary `k`) and `Xout` (boundary `k + 1`) are images of int16 planes on which block `k`'s
constraint system `BlockSat` holds. -/
def BlockOn (P : BlockPublic S) (Xin Xout : S.Pos → GF) : Prop :=
  ∃ x x' : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (x' p)) ∧ (∀ p, Xin p = (x p : GF)) ∧ (∀ p, Xout p = (x' p : GF))
    ∧ ∃ w, BlockSat P (fun p => (x p : GF)) (fun p => (x' p : GF)) w

/-- **The blocks' conclusions chain into the run's constraint system**: from an int16 preimage of boundary `0`'s plane
and every block's `BlockOn` on boundaries `k` and `k + 1`, `RunSat` holds from that preimage to an int16 preimage of the
last boundary's plane (the int16 preimage of a plane is unique, `i16_eq_of_cast`). -/
theorem runSat_of_blocks : ∀ (Ps : List (BlockPublic S)) (X : ℕ → S.Pos → GF) (x0 : S.Pos → ℤ),
    (∀ p, i16 (x0 p)) → (∀ p, X 0 p = (x0 p : GF)) →
    (∀ (k : ℕ) (hk : k < Ps.length), BlockOn Ps[k] (X k) (X (k + 1))) →
    ∃ y : S.Pos → ℤ, (∀ p, i16 (y p)) ∧ (∀ p, X Ps.length p = (y p : GF)) ∧ RunSat Ps x0 y
  | [], X, x0, hx0, hX0, _ => ⟨x0, hx0, hX0, rfl⟩
  | P :: Ps, X, x0, hx0, hX0, hb => by
    have h0 := hb 0 (by simp)
    rw [List.getElem_cons_zero] at h0
    obtain ⟨x, x', hx, hx', hX, hX', w, hw⟩ := h0
    have hxx : x = x0 := funext fun p => i16_eq_of_cast (hx p) (hx0 p) (by rw [← hX p, hX0 p])
    subst hxx
    obtain ⟨y, hy, hXy, hr⟩ := runSat_of_blocks Ps (fun k => X (k + 1)) x' hx' hX' (fun k hk => by
      have h := hb (k + 1) (by simp only [List.length_cons]; omega)
      rw [List.getElem_cons_succ] at h
      exact h)
    refine ⟨y, hy, fun p => by simpa using hXy p, ?_⟩
    simp only [RunSat]
    exact ⟨x', hx', ⟨w, hw⟩, hr⟩

/-- **`RunOn` from the per-block conclusions** (L12's hypothesis of `classify_run_link`, now from the blocks' own). -/
theorem runOn_of_blocks (Ps : List (BlockPublic S)) (X : ℕ → S.Pos → GF) (hpos : 0 < Ps.length)
    (hb : ∀ (k : ℕ) (hk : k < Ps.length), BlockOn Ps[k] (X k) (X (k + 1))) : RunOn Ps (X 0) (X Ps.length) := by
  obtain ⟨x, _, hx, _, hX, _, _⟩ := hb 0 hpos
  obtain ⟨y, hy, hXy, hr⟩ := runSat_of_blocks Ps X x hx hX hb
  exact ⟨x, y, hx, hy, hX, hXy, hr⟩

/-- **One extracted plane per boundary index** as L12's `RunFrame`: `B_in` (boundary `0`) is what stage IN-C commits
and block `0` opens (classify_run.rs:300, :333), `B_L` what the last block outputs and stage OUT-C opens (:379). -/
def boundaryFrame (planes : ℕ → S.Pos → GF) (L : ℕ) : RunFrame ℕ S :=
  ⟨planes, 0, 0, L, L, rfl, rfl⟩

/-! ## The run's extraction premise, and `IOPExtract` from it -/

/-- **What the run's extractor returns**: one plane per boundary (`B_0 = B_in`, …, `B_L = B_out`), stage IN-C's
`A_TOK` words and the input endpoint's extracted words at the support, stage OUT-C's `x`, and the opening data. -/
structure RunExt (S : BlockShape) (Salt : Type) where
  planes : ℕ → S.Pos → GF
  tokW : S.Tok → GF
  epW : S.Tok → GF
  xC : Fin S.d → GF
  r : Salt
  r' : Salt

/-- Stage IN-C's conclusion (L12's `inc_stage_sound` with SIC_IO's `in_endpoint_words`). -/
def InOk (R : ClassifyRunPublic S) {Salt : Type} (e : RunExt S Salt) : Prop :=
  InSat R.inp e.tokW (e.planes 0) ∧ ∀ t, e.epW t = e.tokW t

/-- The blocks' conclusions (lane L16 per block, W16R2; lane L17 at R13), on the boundary planes. -/
def BlocksOk (R : ClassifyRunPublic S) {Salt : Type} (e : RunExt S Salt) : Prop :=
  ∀ (k : ℕ) (hk : k < R.Ps.length), BlockOn R.Ps[k] (e.planes k) (e.planes (k + 1))

/-- Stage OUT-C's conclusion (L15's `outc_stage_sound` with OUTC-00's identity) for the statement's verdict `b`. -/
def OutOk (R : ClassifyRunPublic S) {Salt : Type} (b : ℕ) (e : RunExt S Salt) : Prop :=
  b ≤ 1 ∧ OutCSat R.out e.xC b ∧ ∀ i, e.xC i = e.planes R.Ps.length (R.row, i)

/-- The input endpoint opens to the extracted words read canonically (lane L10's opening knowledge, L10-6). -/
def EpOk {Lq : ℕ} {Coins : Type} {R : ClassifyRunPublic S} (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (G : QB Lq → Dig) (s : P.Stmt) (e : RunExt S P.Salt) : Prop :=
  P.opensIn G s (fun t => canonWord (e.epW t)) e.r

/-- **The run's extraction premise** (the knowledge version, composed over the run): ONE extractor reading the
prover's hash log, the statement and the receipt; a prover making at most `q` queries gets the receipt accepted while
stage IN-C's, the blocks', stage OUT-C's (for the statement's verdict) or the endpoint's conclusion fails on the
extracted data with probability at most `εin q`, `εblk q`, `εout q`, `εep q`. -/
def RunExtract {Lq : ℕ} {Coins : Type} (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (εin εblk εout εep : ℕ → ℝ≥0∞) : Prop :=
  ∃ E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt,
    ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εin q
      ∧ prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εblk q
      ∧ prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εout q
      ∧ prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εep q

/-- The union bound for `prH`. -/
theorem prH_or_le {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] (A B : (Q → D) → Prop) :
    prH (fun H => A H ∨ B H) ≤ prH A + prH B := by
  unfold prH
  exact MeasureTheory.measure_union_le {H | A H} {H | B H}

theorem prH_mono {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] {A B : (Q → D) → Prop}
    (h : ∀ H, A H → B H) : prH A ≤ prH B := by
  unfold prH
  exact MeasureTheory.measure_mono (fun H hH => h H hH)

/-- **`IOPExtract` for the classify run from the run's extraction premise.** The `IOPExtract` extractor reads the input
as the endpoint's extracted words (canonically), the output as the statement's verdict, the witness `()`, and the
opening data; when all four part conclusions hold, L12's `classify_inner_of_stages` (with `runOn_of_blocks` and the
boundary frame) gives the inner predicate; so the failure is at most the sum of the four parts'. -/
theorem iopExtract_of_runExtract {Lq : ℕ} {Coins : Type} (R : ClassifyRunPublic S)
    (P : Protocol (QB Lq) Dig Coins (classifyModel S R)) (hopenOut : ∀ G s y r, P.opensOut G s y r)
    (hpos : 0 < R.Ps.length) {εin εblk εout εep : ℕ → ℝ≥0∞} (hX : RunExtract R P εin εblk εout εep) :
    IOPExtract (classifyModel S R) (classifyArith S R) P (fun q => εin q + εblk q + εout q + εep q) := by
  obtain ⟨E, hE⟩ := hX
  refine ⟨fun lg s pf => ((fun t => canonWord ((E lg s pf).epW t)), P.ypub s, (), (E lg s pf).r, (E lg s pf).r'),
    fun W q A hA => ?_⟩
  obtain ⟨h1, h2, h3, h4⟩ := hE q A hA
  have hW : W = () := rfl
  subst hW
  refine le_trans (prH_mono (B := fun G =>
      ((P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
        ∨ (P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)))
      ∨ ((P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
        ∨ (P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)))) ?_) ?_
  · intro G hG
    obtain ⟨hver, hbad⟩ := hG
    by_contra hall
    simp only [not_or, not_and, not_not] at hall
    obtain ⟨⟨hin, hblk⟩, hout, hep⟩ := hall
    obtain ⟨hInSat, hepw⟩ := hin hver
    obtain ⟨hb1, hOut, hio⟩ := hout hver
    exact hbad (classify_inner_of_stages R P G (A.runLog G).1.1
      (boundaryFrame (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes R.Ps.length)
      (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).tokW (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).epW
      (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC (P.ypub (A.runLog G).1.1) hb1
      (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r'
      hInSat (runOn_of_blocks R.Ps (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes hpos (hblk hver))
      hOut hio hepw (hep hver) rfl (hopenOut _ _ _ _))
  · refine ((prH_or_le _ _).trans (add_le_add (prH_or_le _ _) (prH_or_le _ _))).trans ?_
    calc _ ≤ (εin q + εblk q) + (εout q + εep q) := add_le_add (add_le_add h1 h2) (add_le_add h3 h4)
      _ = εin q + εblk q + εout q + εep q := by ring

/-! ## The open obligations, and the gate -/

variable {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **The classify run's OPEN obligations**, each a named premise of the precise shape the component lane must deliver
(the remaining gap of D63 for the media app's classify run, as a checkable list; the doc's table gives each field's
lane and status). The instance's data (`R`, the verifier's and the provers' parts with the block profile, the input
commitment, the refusal sites) are the theorem's arguments. -/
structure ClassifyOpen (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (U : K) {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (εin εblk εout εep : ℕ → ℝ≥0∞) (εzk : ℕ → ℕ → ℝ≥0∞) : Prop where
  /-- O1: the registered shape's constants (`BlockShape.Valid`, finite checks; L9 §6). -/
  shape : S.Valid
  /-- O2: every block's public weights in their classes (`BlockPublic.Valid`; the weights are not in the repository,
  D62). -/
  weights : ∀ B ∈ R.Ps, B.Valid
  /-- O3: stage IN-C's public data (`InPublic.Valid`; L15's `shield_in_valid` for the registered policies). -/
  inPub : R.inp.Valid
  /-- O4: stage OUT-C's public data (`OutCPublic.Valid`; L15's `shield_outc_valid` at `d = 3072`). -/
  outPub : R.out.Valid
  /-- O5: the run has blocks, and the verifier's block count is the model's. -/
  blocks : 0 < R.Ps.length ∧ V.L = R.Ps.length
  /-- O6: the input endpoint commitment's geometry: canonical words are its values, `N ≤ 2^depth`, the root is the
  statement's `inRoot`, depth `≤ 64` (for W16R2's `w16r2TokenCommit`: by definition, `2^15`, depth 15). -/
  commit : (∀ x, (∀ t, x t < gP) → Cin.ok x) ∧ Cin.N ≤ 2 ^ Cin.depth ∧ (∀ s, Cin.root s = s.inRoot) ∧ Cin.depth ≤ 64
  /-- O7: the verifier's own pre-header policy accepts the registered header (rulings, tier, the D27 floor, the NTT
  tables, the tables' binding, R13's per-block stage shapes). -/
  policy : V.preA P.hdr = .ok () ∧ V.preB P.hdr = .ok ()
  /-- O8: **every part's completeness contract** (stage IN-C, each block of the block profile, stage OUT-C): the Lean
  honest prover's segment is accepted by the part's verifier, deterministically. -/
  parts : List.Forall₂ (SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr hon.base))
    (P.parts V.L) V.parts
  /-- O9: **the honest prover refuses only at a listed site** (the sites: `c = 0`, `e ∈ {0,1}`, `ν = 0`, batching
  zeros, LogUp's `α`, IN-C's and OUT-C's `α`, D66(3)'s dictionary, the openings' zero and dependent coefficients). -/
  refuse : ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
    ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c = .ok r
  /-- O10: the sites' counts within the completeness budget: `Σ k ≤ 2^85`, `Σ δ ≤ 2^-41` (the freshness of each
  honest squeeze point), uniformly in the input. -/
  counts : (∀ x i, (site x i).k ≤ kOf i) ∧ (∀ x i, (site x i).δ ≤ δOf i) ∧ ∑ i, kOf i ≤ 2 ^ 85
    ∧ ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41
  /-- O11: **the run's extraction** (the knowledge version composed over the run, on the code's chain): one extractor,
  with the stage IN-C (L12/L15, under Fiat–Shamir), blocks (L16, L17 at R13: the joint, path-wise bound of D66(4)),
  stage OUT-C (L15, under Fiat–Shamir) and endpoint (L10-6) failure bounds. -/
  extract : RunExtract R (classifyProtocol S R Lq V P Cin h64 hr hon.base) εin εblk εout εep
  /-- O12: **zero knowledge** of the run's protocol (L14 for one block; the run's simulator and its hybrid step). -/
  zk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base) εzk

/-- **THE ASSEMBLY of the media app's classify run** (D63, lane L18): with the open obligations `ClassifyOpen` as
premises, the approved gate holds for the classify run's `Protocol` instance:
`ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol …) εcTarget (εin + εblk + εout + εep)
εsTarget εzk`. `CircuitIff` (L2), `Binding` (L10, at the target), `Complete` (this lane, at the target), the
extraction's link (L12 and this lane), `KnowledgeSound` and `SemanticHiding` (the assembly) are discharged. -/
theorem classify_productionReady (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) {ι : Type} [Fintype ι]
    (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf εin εblk εout εep εzk) :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget (fun q => εin q + εblk q + εout q + εep q) εsTarget εzk := by
  have hR : R.Valid := ⟨O.inPub, O.weights, O.outPub⟩
  obtain ⟨hokC, hN, hroot, hdep⟩ := O.commit
  haveI : Subsingleton (classifyModel S R).HidOut := inferInstanceAs (Subsingleton Unit)
  refine productionReady_of (classifyRun_circuitIff O.shape R hR)
    (iopExtract_of_runExtract R _ (fun _ _ _ _ => trivial) O.blocks.1 O.extract)
    (classify_complete_target R hR Lq V P Cin h64 hr hon hokC hN hroot O.policy.1 O.policy.2 O.parts U hbij site kOf
      O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse)
    (binding_classifier_target (classifyProtocol S R Lq V P Cin h64 hr hon.base) Cin h64 hr
      (fun G s x r => opensIn_iff R Lq V P Cin h64 hr hon.base G s x r) hdep)
    O.zk

/-! ## The numeric totals against the approved targets -/

/-- **The extraction's parts within the target**: if stage IN-C's, stage OUT-C's and the endpoint's failures together
stay within `q·2^-101 + 2^-101` and the blocks' (the joint, path-wise bound) within `q·2^-101 + 2^-101`, the sum is
within the approved `εsTarget q = q·2^-100 + 2^-100`. -/
theorem extract_split_le_target (εin εblk εout εep : ℕ → ℝ≥0∞)
    (hst : ∀ q, εin q + εout q + εep q ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101)
    (hblk : ∀ q, εblk q ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101) (q : ℕ) :
    εin q + εblk q + εout q + εep q ≤ εsTarget q := by
  have h2 : (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 = (2⁻¹ : ℝ≥0∞) ^ 100 := by
    rw [← two_mul, pow_succ]
    calc (2 : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 100 * 2⁻¹) = (2⁻¹ : ℝ≥0∞) ^ 100 * (2 * 2⁻¹) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 100 := by rw [ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, mul_one]
  calc εin q + εblk q + εout q + εep q = (εin q + εout q + εep q) + εblk q := by ring
    _ ≤ ((q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101)
        + ((q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101) := add_le_add (hst q) (hblk q)
    _ = (q : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101) + ((2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101) := by
        ring
    _ = εsTarget q := by rw [h2, εsTarget]

/-- **The gate at the approved targets** `(εcTarget, εsTarget, εsTarget, εzkTarget)` for the classify run: the open
obligations, with the extraction's parts within the target's halves (`extract_split_le_target`) and the zero-knowledge
obligation supplied in `zeroKnowledge_target_of_hybrid`'s form (a programming simulator whose one-receipt hybrid step
costs at most `εhv + q·δ`, `εhv ≤ 2^-120`, `δ ≤ 2^-248`), via `productionReady_mono`. -/
theorem classify_productionReady_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf εin εblk εout εep εzk)
    (hst : ∀ q, εin q + εout q + εep q ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101)
    (hblk : ∀ q, εblk q ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget :=
  productionReady_mono (classify_productionReady R Lq V P Cin h64 hr hon U hbij site kOf δOf O) le_rfl
    (extract_split_le_target εin εblk εout εep hst hblk) (fun _ => le_rfl) hzk

/-- **Zero knowledge at the target from the hybrid step** (the form lane L14 and the run's composition deliver):
`zeroKnowledge_target_of_hybrid` for the classify run's protocol. -/
theorem classify_zk_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    {SC : Type} [Fintype SC] [Nonempty SC] [Inhabited SC]
    (PS : ZKHybrid.ProgSim (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) SC)
    (εhv δ : ℝ≥0∞) (hhv : εhv ≤ (2⁻¹ : ℝ≥0∞) ^ 120) (hδ : δ ≤ (2⁻¹ : ℝ≥0∞) ^ 248)
    (hstep : ∀ (W : Unit) (q R' : ℕ)
      (Dist : OC (QB Lq ⊕ (S.Tok → ℕ)) (Dig ⊕ (ClsStmt Hdr × ClsReceipt)) Bool), Dist.Within q R' → ∀ j < R',
        ZKHybrid.hybProb PS W (q + R') Dist j ≤ ZKHybrid.hybProb PS W (q + R') Dist (j + 1) + (εhv + (q : ℝ≥0∞) * δ)
        ∧ ZKHybrid.hybProb PS W (q + R') Dist (j + 1) ≤ ZKHybrid.hybProb PS W (q + R') Dist j + (εhv + (q : ℝ≥0∞) * δ)) :
    ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) εzkTarget :=
  ZKHybrid.zeroKnowledge_target_of_hybrid PS εhv δ hhv hδ hstep

/-- **Stage IN-C's half of `R.Valid` for the registered Shieldstral category policies** (L15's `shield_in_valid`):
for the policy's template around a content of any length and any int16 embedding. -/
theorem shield_inp_valid (q : List ℕ) (hq : q = Valid.qSexual ∨ q = Valid.qViolence ∨ q = Valid.qHate) (n : ℕ)
    (emb : ℕ → S.Wid → ℤ) (hemb : ∀ v i, i16 (emb v i)) (R : ClassifyRunPublic S) (hR : R.inp = Valid.shieldIn S q n emb) :
    R.inp.Valid := by
  rw [hR]
  exact Valid.shield_in_valid S q hq n emb hemb

end ZK60.ProtocolClassify
