/-
D63 lane L68c, part 3f (`HonestShieldZK.lean`):
final **`O.zk`** assembly for Shieldstral T128 R13 combining `HonestShieldZKVis`, `HonestShieldZKCount`,
`HonestShieldZKProg`, `HonestShieldZKView`, and `HonestShieldZKBase` under Sol's `T = 2^20` conservative
reserve (`shdRunErrRes`), `.dep` `colDigest`, and explicit named `NativeOsRngIndist` transfer, together
with D76 `ZeroKnowledgeL` / `SemanticHidingL` / `ProductionReadyL` and `RunShieldOpenShell` compatibility bridges.

What this file defines and proves (standard Lean foundations `propext`, `Classical.choice`, `Quot.sound` only):
1. **Whole-run ZK program witnesses (`ShdZKCountWitness`, `ShdZKProgWitness`)**:
   - `ShdZKCountWitness`: bundles `PProg` run agreement, `PtLE shdP_zkPts`, `DepAbsorbed`, `QLE shdP_zkQueries`,
     `DepIn ShdRunDepSet`, `2^512 ∣ |Coins|`, `ShdRunVisSpec`, `PProg.KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes`,
     per-kind freshness, pairwise collision/dep-hit bounds, and conditional hidden-leaf salt freshness.
   - `ShdZKProgWitness`: extends `ShdZKCountWitness` with the concrete 84-PCS / 28-segment two-level view
     factorization at `(shdP_L1Spec, shdP_L2Spec)` (`HonestShieldZKVis.shdP_full_twoLevel_hHV`).
2. **Ideal-coin `O.zk`, D76 `ZeroKnowledgeL`, and `SemanticHidingL` (`shdRunErrRes` → `εzkTarget`)**:
   - **`shdP_O_zk_ideal_of_hHV`**, **`shdP_O_zk_ideal`**: proves `ZeroKnowledge (classifyModelP R) (classifyProtocolP ...) shdRunErrRes`.
   - **`shdP_O_zk_ideal_UP`**: lifts to `classifyProtocolUP ... e` (`zkUP_of_zkP`).
   - **`shdP_zkL_target_ideal`**, **`shdP_semL_target_ideal`**: proves D76 `ZeroKnowledgeL ... (classifyLeakP R) εzkTarget`
     and `SemanticHidingL ... (classifyLeakP R) (fun q => εzkTarget q 1)` via `shdRunErrRes_hzk`.
   - **`shdP_zkL_exec_target_ideal`**, **`shdP_semL_exec_target_ideal`**: exact specializations to the
     production `classifyProtocolUExecP` at `shdP_runV` and radius `e = 768` (matching `RunShieldOpenShell`).
3. **Real OS-RNG transfer via explicit named `NativeOsRngIndist`**:
   - `nativeOsRngIndist_UP_of_P`: transports `NativeOsRngIndist` from `classifyProtocolP` to `classifyProtocolUP ... e`.
   - **`shdP_O_zk_nativeOsRng`**, **`shdP_zkL_nativeOsRng`**: proves `ZeroKnowledge` and `ZeroKnowledgeL` on
     `runPMapCoins expand P` at `fun q R' => shdRunErrRes q R' + εrng q R'`.
   - **`shdP_zkL_target_nativeOsRng`**, **`shdP_semL_target_nativeOsRng`**, **`shdP_zkL_exec_target_nativeOsRng`**,
     **`shdP_semL_exec_target_nativeOsRng`**: proves D76 `ZeroKnowledgeL` and `SemanticHidingL` at `εzkTarget` on
     the real OS-RNG protocol whenever `εrng q R' ≤ q * 2^-129 + R' * 2^-121` on `q, R' ≤ 2^64`
     (`shdRunErrRes_add_rng_le_target`).
4. **`RunShieldOpenShell` & `ProductionReadyL` compatibility bridges**:
   - **`shdP_classifyOpenP_shell_zk`** and **`shdP_classifyOpenP_shell_zk_nativeOsRng`**: plug directly into
     `RunShieldOpenShell.shdP_classifyOpenP_shell` (which is parametric in `εzk`).
   - **`shdP_productionReadyL_of_stmt1_and_zkRes`** and **`shdP_productionReadyL_of_stmt1_and_nativeOsRng`**:
     assemble the full approved `ProductionReadyL ... εcTarget εsTarget εsTarget εzkTarget` on the exact
     `sshC_productionReadyL_epP_openShell` protocol `classifyProtocolUExecP ... 768`.
   - `shdP_productionReadyL_replace_zk` and `zeroKnowledge_mono`: monotonicity & ZK-field replacement bridges
     (note: `RunShieldOpenShell.sshC_productionReadyL_epP_openShell` still specializes its `hzk` parameter to the
     undercounted `refErr RunK.kinds` per finding `L68b-4/5`, whereas `shdRunErrRes` strictly dominates
     `refErr RunK.kinds` and directly meets `εzkTarget` via `shdRunErrRes_hzk`).
-/
import ZK60Formal.HonestShieldZKVis
import ZK60Formal.HonestShieldZKCount
import ZK60Formal.RunShapeGateL

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.ZKW16 ZK60.ZKCount ZK60.ZKHonest ZK60.ProtocolClassify
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifyArithP classifySpecP)
open ZK60.RunShape.Shield (shieldS0 ShieldRun)
open ZK60.ProtocolClassify.RunShapeP (classifyProtocolP classifyProtocolUP classifyProtocolUExecP
  clsStmtOfP zkUP_of_zkP classifyLeakP classifyUP_leaksAtMost)
open ZK60.D76 (zeroKnowledgeL_of_zeroKnowledge zeroKnowledgeL_of_zeroKnowledge_le zeroKnowledgeL_mono
  semanticHidingL_of_zeroKnowledgeL productionReadyL_of_parts)
open ZK60.Circuit (gP GF)
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV)
open ZK60.Exec.Block (BlockParams)

/-! ## 1. Whole-run Shieldstral ZK program witnesses (`ShdZKCountWitness`, `ShdZKProgWitness`) -/

section Witnesses

open Classical in
/-- **Whole-run Shieldstral `PProg` visibility and counting witness** at `shdRunErrRes` (`T = 2^20`, `.dep` `colDigest`),
parametric in the honest-verifier indistinguishability proof `hHV`. -/
structure ShdZKCountWitness {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) where
  prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)
  hprog : ∀ H (x : {x // (classifyModelP R).admissible x}) c,
    (prog x c).run H = (classifyProtocolP R Lq V P Cin h64 hr base).prove H () x.1 c
  hk : ∀ x c, (prog x c).PtLE shdP_zkPts
  habs : ∀ x c, DepAbsorbed (prog x c)
  hq : ∀ x c, (prog x c).QLE shdP_zkQueries
  hdep : ∀ x c, (prog x c).DepIn (ShdRunDepSet Lq tag key domain shape)
  h512 : 2 ^ 512 ∣ Fintype.card Coins
  visSpec : ShdRunVisSpec Lq hL20 prog P.refused
  hkCount : ∀ x c, (prog x c).KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes
  kOf : {x // (classifyModelP R).admissible x} → (QB Lq → Dig) → Fin shdP_zkResPts → ShdQKind
  hkind : ∀ x H (s : Coins × (Fin shdP_zkResPts → Dig)) i,
    shdQKind tag key (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) = kOf x H i
  hcntT : ∀ x H, (univ.filter (fun i => kOf x H i = .tr)).card ≤ shdP_zkResT
  hcntL : ∀ x H, (univ.filter (fun i => kOf x H i = .leaf)).card ≤ shdP_zkLeaves
  hcntN : ∀ x H, (univ.filter (fun i => kOf x H i = .node)).card ≤ shdP_zkNodes
  hcntD : ∀ x H, (univ.filter (fun i => kOf x H i = .dep)).card = 0
  hfreshT : ∀ x H i, kOf x H i = .tr → ∀ z,
    2 ^ 256 * (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = z)).card
      ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
  hfreshL : ∀ x H i, kOf x H i = .leaf → ∀ z,
    2 ^ 256 * (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = z)).card
      ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
  hfreshN : ∀ x H i, kOf x H i = .node → ∀ z,
    2 ^ 512 * (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = z)).card
      ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
  hpairs : ∀ x H (i j : Fin shdP_zkResPts), i ≠ j →
    2 ^ 256 * (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
        = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 j)).card
      ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
  hdeps : ∀ x H (i : Fin shdP_zkResPts),
    2 ^ 256 * (univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
        ∈ ShdRunDepSet Lq tag key domain shape)).card
      ≤ Fintype.card (Coins × (Fin shdP_zkResPts → Dig))
  hleaf_hid : ∀ x H v, ¬ visSpec.G v → ∀ c i, ¬ visSpec.vis v i →
    shdQKind tag key (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i) = .leaf
  hhid_card : ∀ v, ¬ visSpec.G v →
    (univ.filter (fun i : Fin shdP_zkResPts => ¬ visSpec.vis v i)).card ≤ shdP_zkLeaves
  hcond_hid : ∀ x H v, ¬ visSpec.G v → ∀ i, ¬ visSpec.vis v i → ∀ o z,
    2 ^ 256 * (univ.filter (fun c : Coins =>
      PProg.outOf (prog x c) v = o ∧ PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i = z)).card
      ≤ (univ.filter (fun c : Coins => PProg.outOf (prog x c) v = o)).card

/-- **Complete Shieldstral T128 R13 ZK witness**: extends `ShdZKCountWitness` with the concrete
84-PCS / 28-segment two-level view decomposition at `(shdP_L1Spec, shdP_L2Spec)`, discharging `hHV`
automatically via `HonestShieldZKVis.shdP_full_twoLevel_hHV`. -/
structure ShdZKProgWitness {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) extends
    ShdZKCountWitness R Lq hL20 tag key domain shape V P Cin h64 hr base where
  π : Coins → ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec
  hπ : (PMF.uniformOfFintype Coins).map π
    = PMF.uniformOfFintype (ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec)
  ks : ℕ → (v : Fin shdP_zkResPts → Dig) → ¬ visSpec.G v → ShdL1OpenK
  qs : ℕ → (v : Fin shdP_zkResPts → Dig) → ¬ visSpec.G v → (Fin 28 → ℕ)
  hc : ℕ → (v : Fin shdP_zkResPts → Dig) → ¬ visSpec.G v → ShdHostCoeffs shdP_K
  D1 : (verdict : ℕ) → (v : Fin shdP_zkResPts → Dig) → (hg : ¬ visSpec.G v) →
    ShdL1Data GF shdP_K (AdmAt R verdict) shdP_L1Spec (ks verdict v hg)
  D2 : (verdict : ℕ) → (v : Fin shdP_zkResPts → Dig) → (hg : ¬ visSpec.G v) → (s : Fin 28) →
    ShdSegL2Data GF shdP_K (AdmAt R verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (ks verdict v hg))
      (D1 verdict v hg).view (shdSegKind s) (shdSegHosts (hc verdict v hg) s) shdP_U (7 : GF)
      (shdP_L2Spec s) (qs verdict v hg s)
  Rc : (verdict : ℕ) → (v : Fin shdP_zkResPts → Dig) → (hg : ¬ visSpec.G v) →
    ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (ks verdict v hg) (qs verdict v hg) → ClsStmt Hdr × ClsReceipt
  hout : ∀ (verdict : ℕ) (y : AdmAt R verdict) (c : Coins) (v : Fin shdP_zkResPts → Dig) (hg : ¬ visSpec.G v),
    PProg.outOf (prog y.1 c) v =
      Rc verdict v hg ((D1 verdict v hg).view y (π c).1, fun s => (D2 verdict v hg s).view y (π c).1 ((π c).2 s))

end Witnesses

/-! ## 2. Ideal-coin `O.zk`, D76 `ZeroKnowledgeL`, and `SemanticHidingL` (`shdRunErrRes` → `εzkTarget`) -/

section IdealZK

/-- Generic monotonicity of `ZeroKnowledge` in its error function. -/
theorem zeroKnowledge_mono {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    {M : IntModel} {P : Protocol Q D Coins M} {ε₁ ε₂ : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge M P ε₁) (hle : ∀ q R, ε₁ q R ≤ ε₂ q R) :
    ZeroKnowledge M P ε₂ := by
  obtain ⟨S, hS⟩ := h
  exact ⟨S, fun W q R Dist hD =>
    ⟨(hS W q R Dist hD).1.trans (add_le_add le_rfl (hle q R)),
     (hS W q R Dist hD).2.trans (add_le_add le_rfl (hle q R))⟩⟩

open Classical in
/-- **Core ideal-coin `O.zk` theorem at `shdRunErrRes`** given `ShdZKCountWitness` and an explicit `hHV` proof:
discharges every rate, weight, visibility, collision, and hidden-leaf obligation of `shdP_zk_of_prog_res`. -/
theorem shdP_O_zk_ideal_of_hHV {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt)
    (W : ShdZKCountWitness R Lq hL20 tag key domain shape V P Cin h64 hr base)
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 →
      ∀ v : Fin shdP_zkResPts → Dig, ¬ W.visSpec.G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (W.prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (W.prog x' c) v)) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) shdRunErrRes :=
  shdP_zk_of_prog_res R Lq hL20 tag key domain shape V P Cin h64 hr base
    W.prog W.hprog W.hk W.habs W.hq W.hdep
    W.visSpec.vis W.visSpec.vp W.visSpec.hvis
    W.visSpec.G W.visSpec.hvisG W.visSpec.hrefG
    hHV
    (shdKf Coins tag key) (shdKUf Coins tag key)
    (shdKm Coins) (shdKUm Coins) (shdWp Coins) (shdWpa Coins) (shdKc Coins)
    (shdKm_ge Coins tag key) (shdKUm_ge Coins tag key)
    (fun x c => shd_hwb_of_kCount Coins (W.hkCount x c))
    (fun x c => shd_hwba_of_kCount Coins (W.hkCount x c))
    (fun x H z => hKw_of_shdQKind W.h512 tag key
      (fun s : Coins × (Fin shdP_zkResPts → Dig) => PProg.ptsOf (shdP_zkPad Lq hL20) (W.prog x s.1) H s.2)
      (W.kOf x H) (W.hkind x H) (W.hcntT x H) (W.hcntL x H) (W.hcntN x H) (W.hcntD x H)
      (W.hfreshT x H) (W.hfreshL x H) (W.hfreshN x H) z)
    (fun x H => hKc_of_shdPairs W.h512 (ShdRunDepSet Lq tag key domain shape)
      (fun s : Coins × (Fin shdP_zkResPts → Dig) => PProg.ptsOf (shdP_zkPad Lq hL20) (W.prog x s.1) H s.2)
      (W.hpairs x H) (W.hdeps x H))
    (shdKG Coins tag key)
    (fun x H v hg Zs Wt hWt => hUw_of_hiddenLeaves W.h512 tag key
      (W.visSpec.vis v)
      (fun c => PProg.ptsOf (shdP_zkPad Lq hL20) (W.prog x c) H v)
      (fun c => PProg.outOf (W.prog x c) v)
      (W.hleaf_hid x H v hg) (W.hhid_card v hg)
      (fun i hni o z => by convert W.hcond_hid x H v hg i hni o z)
      Zs Wt hWt)
    (shd_hrδp Coins W.h512) (shd_hrωp Coins W.h512) (shd_hrεc Coins W.h512)
    (shd_hrδh Coins W.h512) (shd_hrωh Coins W.h512)

/-- **MAIN IDEAL-COIN `O.zk` THEOREM AT `shdRunErrRes`**:
assembles `HonestShieldZKVis` (84-PCS / 28-segment two-level `hHV` + visibility), `HonestShieldZKCount`
(exact 112-tree / 28-segment `shdRunErrRes` accounting + zero-rounding-loss rates), `HonestShieldZKProg`,
`HonestShieldZKView`, and `HonestShieldZKBase` into `ZeroKnowledge ... shdRunErrRes`. -/
theorem shdP_O_zk_ideal {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt)
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) shdRunErrRes :=
  shdP_O_zk_ideal_of_hHV R Lq hL20 tag key domain shape V P Cin h64 hr base W.toShdZKCountWitness
    (shdP_full_twoLevel_hHV R Lq shdP_zkResPts W.prog W.visSpec.G
      W.π W.hπ W.ks W.qs W.hc W.D1 W.D2 W.Rc W.hout)

/-- Lift ideal-coin `O.zk` (`shdRunErrRes`) to the radius-`e` protocol `classifyProtocolUP`. -/
theorem shdP_O_zk_ideal_UP {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) (e : ℕ)
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) shdRunErrRes :=
  zkUP_of_zkP R Lq V P Cin h64 hr base e (shdP_O_zk_ideal R Lq hL20 tag key domain shape V P Cin h64 hr base W)

/-- **D76-approved `ZeroKnowledgeL` at `εzkTarget` (ideal coins)** via `shdRunErrRes_hzk`. -/
theorem shdP_zkL_target_ideal {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) (e : ℕ)
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base) :
    ZeroKnowledgeL (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e)
      (classifyLeakP R) εzkTarget :=
  zeroKnowledgeL_of_zeroKnowledge_le
    (M := classifyModelP R) (P := classifyProtocolUP R Lq V P Cin h64 hr base e)
    (classifyLeakP R) classifyUP_leaksAtMost
    (shdP_O_zk_ideal_UP R Lq hL20 tag key domain shape V P Cin h64 hr base e W)
    shdRunErrRes_hzk

/-- **D76-approved `SemanticHidingL` at `fun q => εzkTarget q 1` (ideal coins)**. -/
theorem shdP_semL_target_ideal {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) (e : ℕ)
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base) :
    SemanticHidingL (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e)
      (classifyLeakP R) (fun q => εzkTarget q 1) :=
  semanticHidingL_of_zeroKnowledgeL
    (M := classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) (classifyLeakP R)
    (shdP_zkL_target_ideal R Lq hL20 tag key domain shape V P Cin h64 hr base e W)

/-- **D76 `ZeroKnowledgeL` at `εzkTarget` on the exact `RunShieldOpenShell` protocol (`classifyProtocolUExecP ... 768`)**. -/
theorem shdP_zkL_exec_target_ideal {Hdr Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (epBase : Coins → EpxSalt 6)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ZeroKnowledgeL (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εzkTarget :=
  shdP_zkL_target_ideal Rp Lq hL20 tag key domain shape
    (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
      check0 paths digest bndCheck)
    P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
    (shdP_honestIn (Hdr := Hdr) tag epBase).base 768 W

/-- **D76 `SemanticHidingL` at `fun q => εzkTarget q 1` on the exact `RunShieldOpenShell` protocol**. -/
theorem shdP_semL_exec_target_ideal {Hdr Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (epBase : Coins → EpxSalt 6)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    SemanticHidingL (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) (fun q => εzkTarget q 1) :=
  shdP_semL_target_ideal Rp Lq hL20 tag key domain shape
    (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
      check0 paths digest bndCheck)
    P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
    (shdP_honestIn (Hdr := Hdr) tag epBase).base 768 W

end IdealZK

/-! ## 3. Real OS-RNG transfer via explicit named `NativeOsRngIndist` -/

section RealOsRngZK

/-- `NativeOsRngIndist` transfers identically from `classifyProtocolP` to `classifyProtocolUP` (neither `realProb`
reads `opensIn`). -/
theorem nativeOsRngIndist_UP_of_P {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng) :
    NativeOsRngIndist (classifyProtocolUP R Lq V P Cin h64 hr base e) expand εrng :=
  hRng

/-- **REAL OS-RNG `O.zk` THEOREM**: transfers ideal-coin `shdRunErrRes` zero knowledge to a 256-bit OS-RNG seed
expanded via `expand : Dig → IdealCoins` under the explicit named hypothesis `NativeOsRngIndist`. -/
theorem shdP_O_zk_nativeOsRng {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base)
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng) :
    ZeroKnowledge (classifyModelP R)
      (classifyProtocolP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)))
      (fun q R' => shdRunErrRes q R' + εrng q R') :=
  shdP_nativeOsRng_classifyP_zk R Lq V P Cin h64 hr base expand hRng
    (shdP_O_zk_ideal R Lq hL20 tag key domain shape V P Cin h64 hr base W)

/-- **Real OS-RNG D76 `ZeroKnowledgeL` at `shdRunErrRes + εrng`** on `classifyProtocolUP`. -/
theorem shdP_zkL_nativeOsRng {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base)
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng) :
    ZeroKnowledgeL (classifyModelP R)
      (classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
      (classifyLeakP R) (fun q R' => shdRunErrRes q R' + εrng q R') :=
  shdP_nativeOsRng_classifyUP_zkL R Lq V P Cin h64 hr base e (classifyLeakP R) expand
    (nativeOsRngIndist_UP_of_P R Lq V P Cin h64 hr base e expand hRng)
    (zeroKnowledgeL_of_zeroKnowledge
      (M := classifyModelP R) (P := classifyProtocolUP R Lq V P Cin h64 hr base e)
      (classifyLeakP R) classifyUP_leaksAtMost
      (shdP_O_zk_ideal_UP R Lq hL20 tag key domain shape V P Cin h64 hr base e W))

/-- **Real OS-RNG D76 `ZeroKnowledgeL` at `εzkTarget`**: combines `shdRunErrRes_half_cap_85` with any
OS-RNG seed expansion advantage `εrng q R' ≤ q * 2^-129 + R' * 2^-121` on `q, R' ≤ 2^64`. -/
theorem shdP_zkL_target_nativeOsRng {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base)
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng)
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :
    ZeroKnowledgeL (classifyModelP R)
      (classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
      (classifyLeakP R) εzkTarget :=
  zeroKnowledgeL_mono
    (M := classifyModelP R)
    (P := classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
    (classifyLeakP R)
    (shdP_zkL_nativeOsRng R Lq hL20 tag key domain shape V P Cin h64 hr base e expand W hRng)
    (shdRunErrRes_add_rng_le_target hεrng)

/-- **Real OS-RNG D76 `SemanticHidingL` at `fun q => εzkTarget q 1`**. -/
theorem shdP_semL_target_nativeOsRng {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness R Lq hL20 tag key domain shape V P Cin h64 hr base)
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng)
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :
    SemanticHidingL (classifyModelP R)
      (classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
      (classifyLeakP R) (fun q => εzkTarget q 1) :=
  semanticHidingL_of_zeroKnowledgeL
    (M := classifyModelP R)
    (classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
    (classifyLeakP R)
    (shdP_zkL_target_nativeOsRng R Lq hL20 tag key domain shape V P Cin h64 hr base e expand W hRng hεrng)

/-- **Real OS-RNG D76 `ZeroKnowledgeL` at `εzkTarget` on the exact `RunShieldOpenShell` protocol
(`classifyProtocolUExecP ... 768`)**. -/
theorem shdP_zkL_exec_target_nativeOsRng {Hdr IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) IdealCoins) (epBase : IdealCoins → EpxSalt 6)
    (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (hRng : NativeOsRngIndist
      (classifyProtocolP Rp Lq
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      expand εrng)
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :
    ZeroKnowledgeL (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768)
      (classifyLeakP Rp) εzkTarget :=
  shdP_zkL_target_nativeOsRng Rp Lq hL20 tag key domain shape
    (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
      check0 paths digest bndCheck)
    P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
    (shdP_honestIn (Hdr := Hdr) tag epBase).base 768 expand W hRng hεrng

/-- **Real OS-RNG D76 `SemanticHidingL` at `fun q => εzkTarget q 1` on the exact `RunShieldOpenShell` protocol**. -/
theorem shdP_semL_exec_target_nativeOsRng {Hdr IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) IdealCoins) (epBase : IdealCoins → EpxSalt 6)
    (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (hRng : NativeOsRngIndist
      (classifyProtocolP Rp Lq
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      expand εrng)
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :
    SemanticHidingL (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768)
      (classifyLeakP Rp) (fun q => εzkTarget q 1) :=
  shdP_semL_target_nativeOsRng Rp Lq hL20 tag key domain shape
    (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
      check0 paths digest bndCheck)
    P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
    (shdP_honestIn (Hdr := Hdr) tag epBase).base 768 expand W hRng hεrng

end RealOsRngZK

/-! ## 4. `RunShieldOpenShell` & `ProductionReadyL` compatibility bridges -/

section OpenShellBridges

/-- **Direct plug-in into `RunShieldOpenShell.shdP_classifyOpenP_shell` (ideal coins, `εzk := shdRunErrRes`)**:
discharges `O.zk` completely inside the parametric `ClassifyOpenP` shell. -/
theorem shdP_classifyOpenP_shell_zk {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (epBase : Coins → EpxSalt 6)
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Coins shdP_K)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid)
    (houtPub : Rp.out.Valid)
    (hpol : preA P.hdr = .ok () ∧ preB P.hdr = .ok ())
    (hparts : List.Forall₂
      (SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base))
      (P.parts 26)
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck).parts)
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires shdP_U G c)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ZK60.ProtocolClassify.RunShapeP.ClassifyOpenP Rp Lq
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site shdP_kOf shdP_δOf shdRunErrRes :=
  shdP_classifyOpenP_shell tag Lq hL20 key domain hw preA preB Rp hR
    embDigest embFold bInRow wDigest bOutRow Pk check0 paths digest bndCheck
    P epBase site hweights hinPub houtPub hpol hparts hk hδ hcover
    (shdP_O_zk_ideal Rp Lq hL20 tag key domain shape _ P _ _ _ _ W)

/-- **Direct plug-in into `RunShieldOpenShell.shdP_classifyOpenP_shell` (real OS-RNG via `NativeOsRngIndist`)**:
discharges `O.zk` on `runPMapCoins expand P` at `fun q R' => shdRunErrRes q R' + εrng q R'`. -/
theorem shdP_classifyOpenP_shell_zk_nativeOsRng {Hdr IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) IdealCoins) (epBase : IdealCoins → EpxSalt 6)
    (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Dig shdP_K)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid)
    (houtPub : Rp.out.Valid)
    (hpol : preA P.hdr = .ok () ∧ preB P.hdr = .ok ())
    (hparts : List.Forall₂
      (SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base))
      ((runPMapCoins expand P).parts 26)
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck).parts)
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G s,
      honestSegs
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        (runPMapCoins expand P) (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag (fun seed => epBase (expand seed))).base s))
        ((classifySpecP Rp x).getD 0) x s = .error ()
        → ∃ i, (site x i).fires shdP_U G s)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (hRng : NativeOsRngIndist
      (classifyProtocolP Rp Lq
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      expand εrng) :
    ZK60.ProtocolClassify.RunShapeP.ClassifyOpenP Rp Lq
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag (fun s => epBase (expand s))) shdP_U site shdP_kOf shdP_δOf
      (fun q R' => shdRunErrRes q R' + εrng q R') :=
  shdP_classifyOpenP_shell tag Lq hL20 key domain hw preA preB Rp hR
    embDigest embFold bInRow wDigest bOutRow Pk check0 paths digest bndCheck
    (runPMapCoins expand P) (fun s => epBase (expand s)) site
    hweights hinPub houtPub hpol hparts hk hδ hcover
    (shdP_O_zk_nativeOsRng Rp Lq hL20 tag key domain shape _ P _ _ _ _ expand W hRng)

/-- Replace the `zk` and `semantic` fields of any `ProductionReadyL` with a new `ZeroKnowledgeL` proof. -/
theorem shdP_productionReadyL_replace_zk {Q D Coins : Type} [Fintype Q] [DecidableEq Q]
    [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M} {L : Type} (Λ : M.Input → L)
    {εc : ℝ≥0∞} {εs εb : ℕ → ℝ≥0∞} {εzk₁ εzk₂ : ℕ → ℕ → ℝ≥0∞}
    (hPR : ProductionReadyL M A P Λ εc εs εb εzk₁) (hzk : ZeroKnowledgeL M P Λ εzk₂) :
    ProductionReadyL M A P Λ εc εs εb εzk₂ :=
  productionReadyL_of_parts Λ hPR.circuit hPR.complete hPR.sound hPR.binding hzk

/-- **Full D76 `ProductionReadyL` assembly on the exact `RunShieldOpenShell` protocol (`classifyProtocolUExecP ... 768`)**
from Statement 1 (`CircuitIff`, `Complete`, `KnowledgeSound`, `Binding`) + `ShdZKProgWitness` (`shdRunErrRes → εzkTarget`,
bypassing the hardcoded `refErr RunK.kinds` parameter of `sshC_productionReadyL_epP_openShell`). -/
theorem shdP_productionReadyL_of_stmt1_and_zkRes {Hdr Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (epBase : Coins → EpxSalt 6)
    (hC : CircuitIff (classifyModelP Rp) (classifyArithP Rp))
    (hc : Complete (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768) εcTarget)
    (hs : KnowledgeSound (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768) εsTarget)
    (hb : Binding (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768) εsTarget)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  { circuit := hC, complete := hc, sound := hs, binding := hb,
    zk := shdP_zkL_exec_target_ideal tag Lq hL20 key domain shape hw preA preB Rp embDigest embFold bInRow
      wDigest bOutRow Pk check0 paths digest bndCheck P epBase W,
    semantic := shdP_semL_exec_target_ideal tag Lq hL20 key domain shape hw preA preB Rp embDigest embFold bInRow
      wDigest bOutRow Pk check0 paths digest bndCheck P epBase W }

/-- **Full D76 `ProductionReadyL` assembly transferred to real OS-RNG (`runPMapCoins expand P`)**
via explicit named `NativeOsRngIndist` at `εzkTarget`. -/
theorem shdP_productionReadyL_of_stmt1_and_nativeOsRng {Hdr IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain shape : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) IdealCoins) (epBase : IdealCoins → EpxSalt 6)
    (expand : Dig → IdealCoins) {εrng : ℕ → ℕ → ℝ≥0∞}
    (hC : CircuitIff (classifyModelP Rp) (classifyArithP Rp))
    (hc : Complete (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768) εcTarget)
    (hs : KnowledgeSound (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768) εsTarget)
    (hb : Binding (classifyModelP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768) εsTarget)
    (W : ShdZKProgWitness Rp Lq hL20 tag key domain shape
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (hRng : NativeOsRngIndist
      (classifyProtocolP Rp Lq
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      expand εrng)
    (hεrng : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 →
      εrng q R' ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 129 + (R' : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 121) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
        (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
        (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (runPMapCoins expand P) (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag (fun s => epBase (expand s))).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  { circuit := hC, complete := hc, sound := hs, binding := hb,
    zk := shdP_zkL_exec_target_nativeOsRng tag Lq hL20 key domain shape hw preA preB Rp embDigest embFold bInRow
      wDigest bOutRow Pk check0 paths digest bndCheck P epBase expand W hRng hεrng,
    semantic := shdP_semL_exec_target_nativeOsRng tag Lq hL20 key domain shape hw preA preB Rp embDigest embFold bInRow
      wDigest bOutRow Pk check0 paths digest bndCheck P epBase expand W hRng hεrng }

end OpenShellBridges

end ZK60.HonestShield
