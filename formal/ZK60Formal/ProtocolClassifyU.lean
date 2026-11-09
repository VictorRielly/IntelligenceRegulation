/-
D63 lane L26 (2026-11-07), part 3: **`classifyProtocolU`, the classify run's `Protocol` instance with the input
opening at the unique-decoding radius** (finding L24-1's fix, BESIDE L18's `classifyProtocol`, which is unchanged).

`classifyProtocolU … e` is L18's `classifyProtocol` with ONE field changed: `opensIn` is `Cin.OpensU … e` (the value is
admissible and all but at most `e` of the `N` columns verify against the statement's input root) instead of L10's
`PlaneCommit.Opens` (all `N` columns verify). The statement, the receipt, the salt, the leakage, `ypub`, `opensOut`
(`opensUnit`, the classifier's hidden output is `Unit`), the honest prover and THE verifier are the same terms
(`verifyU_iff`, `proveU_eq`).

What is proved:
* `opensInU_iff`, `opensIn_U_of`, `verifyU_iff`, `proveU_eq`: the instance's parts;
* **`completeU_of_complete`**: `Complete` transfers from `classifyProtocol` (the honest opening opens every column, so
  it opens at every radius, `opensU_of_opens`), with the same `εc`;
* **`zkU_of_zk`**: `ZeroKnowledge` transfers (it never reads `opensIn`), with the same simulator and `εzk`;
* **`classifyU_binding_target`**: `Binding` at the approved target `εsTarget` for every `q` (`binding_classifierU_target`,
  `2e + n + Q ≤ N`, `N ≤ 2^20`, depth `≤ 64`); `classifyU_binding_w16r2` (`e = 8052`) and `classifyU_binding_r13`
  (`e = 24,448`) at the token-words endpoints;
* **`classifyU_productionReady_joint`**, **`classifyU_productionReady_joint_target`**: L24's joint gate at
  `classifyProtocolU`: every `ClassifyOpen` field but O11 (its extraction bounds are not used, so any, e.g. the
  trivial bound `1`, will do) and the run's ONE joint extraction for `classifyProtocolU`;
* `jointCover_of_parts`: the joint cover from a cover of stage IN-C, the blocks and stage OUT-C, and a cover of the
  endpoint that may assume stage IN-C's conclusion.

Every premise is an explicit hypothesis. `Statements.lean`, L18's instance and every existing theorem are unchanged.
-/
import ZK60Formal.BindingU
import ZK60Formal.RunExtractClassify

set_option autoImplicit false
-- As in L18's `ProtocolClassifyComplete.lean` and L24's `RunExtractClassify.lean`.
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-- **THE `Protocol` INSTANCE of the classify run with the input opening at radius `e`** (D63 lane L26; L24-1's fix):
L18's `classifyProtocol` with `opensIn := Cin.OpensU … e`, every other field the same term. -/
noncomputable def classifyProtocolU (S : BlockShape) (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) : Protocol (QB Lq) Dig Coins (classifyModel S R) where
  Stmt := ClsStmt Hdr
  Receipt := ClsReceipt
  Salt := Salt
  Leak := ClsLeak
  leak := clsLeak S R
  ypub s := s.verdict
  opensIn G s x r := Cin.OpensU Lq h64 hr e G s x r
  opensOut G s y r := ZK60.Exec.opensUnit G s y r
  prove G _ x c := runProve V P (classifyModel S R).admissible (liftH G) (honestRoot Cin Lq h64 hr G x (base c))
    ((classifySpec R x).getD 0) x c
  verify G _ s rc := okB (classifyVerifyE V (liftH G) s rc)

section Instance

variable (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
  (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
  (e : ℕ)

/-- `opensIn` is the opening at radius `e`, by definition. -/
theorem opensInU_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocolU S R Lq V P Cin h64 hr base e).opensIn G s x r ↔ Cin.OpensU Lq h64 hr e G s x r :=
  Iff.rfl

/-- **L18's opening is an opening of `classifyProtocolU`** (at every radius): a full opening opens all but `e`
columns. -/
theorem opensIn_U_of (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt)
    (h : (classifyProtocol S R Lq V P Cin h64 hr base).opensIn G s x r) :
    (classifyProtocolU S R Lq V P Cin h64 hr base e).opensIn G s x r :=
  Cin.opensU_of_opens Lq h64 hr e G s x r h

/-- **The same verifier**: `classifyProtocolU`'s verdict is `verify_classify_run_with`'s. -/
theorem verifyU_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () s rc = true
      ↔ classifyVerifyE V (liftH G) s rc = .ok () :=
  verify_true_iff R Lq V P Cin h64 hr base G s rc

/-- **The same honest prover.** -/
theorem proveU_eq (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) :
    (classifyProtocolU S R Lq V P Cin h64 hr base e).prove G () x c
      = (classifyProtocol S R Lq V P Cin h64 hr base).prove G () x c :=
  rfl

/-- **`Complete` transfers** from L18's instance with the same `εc`: the events differ only in `∃ r, opensIn`, and
L18's opening is one at radius `e` (`opensIn_U_of`). -/
theorem completeU_of_complete [Fintype Coins] [Nonempty Coins] {εc : ℝ≥0∞}
    (h : Complete (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) εc) :
    Complete (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e) εc := by
  intro W x hx
  refine le_trans (h W x hx) ?_
  unfold prHC
  refine MeasureTheory.measure_mono ?_
  rintro ⟨H, c⟩ ⟨h1, h2, ⟨r, h3⟩, h4⟩
  exact ⟨h1, h2, ⟨r, Cin.opensU_of_opens Lq h64 hr e H _ x r h3⟩, h4⟩

/-- **`ZeroKnowledge` transfers** from L18's instance with the same simulator and `εzk`: neither world reads
`opensIn`. -/
theorem zkU_of_zk [Fintype Coins] [Nonempty Coins] [Inhabited Coins] {εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) εzk) :
    ZeroKnowledge (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e) εzk := by
  obtain ⟨Sim, hS⟩ := h
  exact ⟨Simulator.mk (State := Sim.State) (SCoins := Sim.SCoins) (fin := Sim.fin) (ne := Sim.ne) (inh := Sim.inh)
    Sim.init Sim.step, fun W q R' Dist hD => hS W q R' Dist hD⟩

end Instance

section Bind

variable (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)

/-- **`Binding` at the approved target for `classifyProtocolU`** (D63 lane L26), for every `q`: the input opening at
radius `e` with `2e + n + Q ≤ N`, `N ≤ 2^20`, depth `≤ 64` (`binding_classifierU_target`), the output half vacuous. -/
theorem classifyU_binding_target (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N)
    (hN : Cin.N ≤ 2 ^ 20) (hdi : Cin.depth ≤ 64) :
    Binding (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e) εsTarget := by
  have : Subsingleton (classifyModel S R).HidOut := inferInstanceAs (Subsingleton Unit)
  exact binding_classifierU_target (classifyProtocolU S R Lq V P Cin h64 hr base e) Cin h64 hr e he
    (fun _ _ _ _ => Iff.rfl) hN hdi

/-- **`Binding` at the target at W16R2's token-words endpoint** (`w16r2TokenCommit`, radius `e = 8052`). -/
theorem classifyU_binding_w16r2 (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
    (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (tag : MTag) (h64 : 64 ≤ Lq)
    (hr : 8 * (w16r2TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
      tag).R ≤ Lq) (base : Coins → Salt) :
    Binding (classifyModel S R) (classifyProtocolU S R Lq V P
      (w16r2TokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tag) h64 hr base 8052)
      εsTarget :=
  classifyU_binding_target R Lq V P _ h64 hr base 8052 (by show 2 * 8052 + (2 ^ 14 + 280) ≤ 2 ^ 15; norm_num)
    (by show 2 ^ 15 ≤ 2 ^ 20; norm_num) (by show 15 ≤ 64; norm_num)

/-- **`Binding` at the target at R13's token-words endpoint** (`r13TokenCommit`, the media app's, radius
`e = 24,448`). -/
theorem classifyU_binding_r13 (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
    (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tag : MTag) (h64 : 64 ≤ Lq)
    (hr : 8 * (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
      tag).R ≤ Lq) (base : Coins → Salt) :
    Binding (classifyModel S R) (classifyProtocolU S R Lq V P
      (R13.r13TokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tag) h64 hr base 24448)
      εsTarget :=
  classifyU_binding_target R Lq V P _ h64 hr base 24448 (by show 2 * 24448 + (2 ^ 14 + 256) ≤ 2 ^ 16; norm_num)
    (by show 2 ^ 16 ≤ 2 ^ 20; norm_num) (by show 16 ≤ 64; norm_num)

end Bind

/-! ## The joint cover from the parts' covers -/

section Cover

variable {Lq : ℕ} {Coins' : Type}

/-- **The joint cover from the parts' covers**: if accepted while stage IN-C's, the blocks' or stage OUT-C's
conclusion fails lies in `Z`, and accepted with stage IN-C's conclusion while the endpoint's fails lies in `Z`, then
accepted while the joint conclusion fails lies in `Z`. -/
theorem jointCover_of_parts (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins' (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (Z : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop)
    (h3 : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) → Z A G)
    (hep : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Z A G) :
    ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Z A G := by
  intro A G hv hj
  by_cases h : InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      ∧ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
  · exact hep A G hv h.1 (fun he => hj ⟨h.1, h.2.1, h.2.2, he⟩)
  · exact h3 A G hv h

end Cover

/-! ## The gate at `classifyProtocolU`, through the joint extraction -/

section JointGateU

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at `classifyProtocolU` through the joint extraction** (D63 lane L26; L24's
`classify_productionReady_joint` at the fixed instance): every `ClassifyOpen` field but O11 (from `O`, whatever its
extraction bounds: they are not used), the input opening's radius (`2e + n + Q ≤ N`, `N ≤ 2^20`) and the joint
extraction premise for `classifyProtocolU` at `εs`: `ProductionReady … (classifyProtocolU …) εcTarget εs εsTarget εzk`.
`CircuitIff` (L2), `Complete` (L18's, transferred), `Binding` (this lane, at the target), `ZeroKnowledge` (O12,
transferred), `KnowledgeSound` and `SemanticHiding` (the assembly) are discharged. -/
theorem classifyU_productionReady_joint (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20) {εs : ℕ → ℝ≥0∞}
    (hJ : JointExtract R (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) εs) :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εs εsTarget εzk := by
  have hR : R.Valid := ⟨O.inPub, O.weights, O.outPub⟩
  obtain ⟨hokC, hN, hroot, hdep⟩ := O.commit
  exact productionReady_of (classifyRun_circuitIff O.shape R hR)
    (iopExtract_of_joint R _ (fun _ _ _ _ => trivial) O.blocks.1 hJ)
    (completeU_of_complete R Lq V P Cin h64 hr hon.base e
      (classify_complete_target R hR Lq V P Cin h64 hr hon hokC hN hroot O.policy.1 O.policy.2 O.parts U hbij site kOf
        O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse))
    (classifyU_binding_target R Lq V P Cin h64 hr hon.base e he hN20 hdep)
    (zkU_of_zk R Lq V P Cin h64 hr hon.base e O.zk)

/-- **THE GATE at `classifyProtocolU` at the approved targets, from ONE list of kinds** (D63 lane L26; L24's
`classify_productionReady_joint_target` at the fixed instance): every `ClassifyOpen` field but O11, the radius, the
shared kinds with their constants and the ONE cover for `classifyProtocolU`, the constants totalling `≤ 2^26` and the
zero-knowledge bound within `εzkTarget`: `ProductionReady … (classifyProtocolU …) εcTarget εsTarget εsTarget
εzkTarget`. -/
theorem classifyU_productionReady_joint_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (L : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOk R (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G)
    (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  productionReady_mono
    (classifyU_productionReady_joint R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20
      (jointExtract_of_kinds R (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) E (L.map Prod.fst) Ex εx hEx
        hcover))
    le_rfl (joint_le_target L εx cx hℓ hlin hx hbud) (fun _ => le_rfl) hzk

end JointGateU

end ZK60.ProtocolClassify
