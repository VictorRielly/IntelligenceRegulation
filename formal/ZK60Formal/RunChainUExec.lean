/-
D63 lane L30 (2026-11-09), part 5: **the instance with BOTH changes**: the input commitment opening at the
unique-decoding radius (L26's `classifyProtocolU`) AND the two stage verifiers in executable Lean (L29's
`classifyRunV`, the run verifier of `classifyProtocolExec`).

L26's instance and this lane's gates are stated for ANY run verifier `V : RunV Hdr`; L29's `classifyProtocolExec` is
L18's `classifyProtocol` at `V := classifyRunV …`. So the instance the final assembly needs is one instantiation:

* **`classifyProtocolUExec`**: `classifyProtocolU` at `V := classifyRunV L preA preB start inc incG blk outc outcG`;
* `classifyProtocolUExec_verify`, `classifyProtocolUExec_verify_iff`: its verifier IS `classifyProtocolExec`'s (so
  L29's `classifyProtocolExec_verify_iff` unfolds its acceptance into the run's steps);
  `classifyProtocolUExec_prove`: its honest prover is `classifyProtocolExec`'s;
  `classifyProtocolUExec_opensIn`: its input opening is `OpensU` at radius `e`;
* **`classifyUExec_productionReady_run_w16r2`**, **`classifyUExec_productionReady_run_r13`**: this lane's two gates at
  that instance. Their statements are `RunChainUGate.lean`'s with `V` replaced (written by
  `results/zk60_lean_l30_20261109/l30_mk_exec.py`); their proofs are the generic gates applied at `classifyRunV …`.

Nothing is switched: `classifyProtocol`, `classifyProtocolExec` and `classifyProtocolU` are unchanged, and Victor has
not ruled on finding L24-1. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StageVerifyExec
import ZK60Formal.RunChainUGate

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## The instance -/

section Instance

/-- **THE `Protocol` INSTANCE of the classify run with BOTH changes** (D63 lane L30): the input opening at radius `e`
(L26's `classifyProtocolU`, finding L24-1's proposed fix) at the run verifier with the executable stages (L29's
`classifyRunV`). -/
noncomputable def classifyProtocolUExec (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV)
    (incG : Hdr → StageGeom) (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) : Protocol (QB Lq) Dig Coins (classifyModel S R) :=
  classifyProtocolU S R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Cin h64 hr base e

variable (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ) (preA preB : Hdr → Except String Unit)
  (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
  (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
  (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ)

/-- **The same verifier as `classifyProtocolExec`** (L29's, on L18's instance): the two instances differ only in
`opensIn`. -/
theorem classifyProtocolUExec_verify (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G () s rc
      = (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).verify G () s rc :=
  rfl

/-- So its acceptance is `classifyProtocolExec`'s, which L29's `classifyProtocolExec_verify_iff` unfolds into the
run's steps (the pre-header checks, `L + 2` segments, stage IN-C's decode and verify, the blocks in order, stage
OUT-C's decode and verify). -/
theorem classifyProtocolUExec_verify_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G () s rc
        = true
      ↔ (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).verify G () s rc
        = true :=
  Iff.rfl

/-- **The same honest prover as `classifyProtocolExec`.** -/
theorem classifyProtocolUExec_prove (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).prove G () x c
      = (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).prove G () x c :=
  rfl

/-- **Its input opening is the opening at radius `e`.** -/
theorem classifyProtocolUExec_opensIn (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).opensIn G s x r
      ↔ Cin.OpensU Lq h64 hr e G s x r :=
  Iff.rfl

end Instance

/-! ## The gates at the instance with both changes -/

section Gates

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at W16R2 at the instance with both changes** (D63 lane L30): `classifyU_productionReady_run_w16r2` at
`V := classifyRunV …`, the run verifier with L29's executable stages. The premises are the same, read at
`classifyProtocolUExec`. -/
theorem classifyUExec_productionReady_run_w16r2 (R : ClassifyRunPublic S) (Lq : ℕ)
    (Lb : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 5 924) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 113)
    (hR₀ : KR₀.SqForm 80 (80 * 351)) (hR₁ : KR₁.SqForm 80 (80 * 351)) (hH₀ : KH₀.SqForm 80 (80 * 351))
    (hH₁ : KH₁.SqForm 80 (80 * 351)) (eL : ℕ) (heL : eL ≤ 35153256) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F κ μ Cl 15) (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ 15) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 15)))
    (hUc : CutReads (Exec.Block.absOfC RCx.C) Ux) (hXc : CutReads (Exec.Block.absOfC RCx.C) Xx)
    (pr : ℕ) (hp1 : pr ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ pr) (hF : Fintype.card F = pr ^ 2)
    (hw0 : T.w0 ≤ 2 ^ 61) (hβLR : T.βLR = (1 + (pr : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0))
    (hTe : T.e = 8052) (hTQ : T.nQ = 280) (hβJ : T.βJ = 1)
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hlink : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0
        ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA))
            (Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA))
        ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0
        ∧ subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_run_w16r2 R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG)
    P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 tr
    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB
    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin
    hdblk hdout pos hplane mk ops hE hops hcan hlink hdzero hzk

/-- **THE GATE at R13, the media app's profile, at the instance with both changes** (D63 lane L30):
`classifyU_productionReady_run_r13` at `V := classifyRunV …`, the run verifier with L29's executable stages. The
premises are the same, read at `classifyProtocolUExec`. -/
theorem classifyUExec_productionReady_run_r13 (R : ClassifyRunPublic S) (Lq : ℕ)
    (Lb : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 7 (7 * 370)) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 110) (hB : KB.PowForm 1 126)
    (hR₀ : KR₀.SqForm 80 (80 * 451)) (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451))
    (hH₁ : KH₁.SqForm 80 (80 * 451)) (eL : ℕ) (heL : eL ≤ 2 ^ 26) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F κ μ Cl 16) (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ 16) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 16)))
    (hUc : CutReads (Exec.Block.absOfC RCx.C) Ux) (hXc : CutReads (Exec.Block.absOfC RCx.C) Xx)
    (pr : ℕ) (hp1 : pr ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ pr) (hF : Fintype.card F = pr ^ 2)
    (hw0 : T.w0 ≤ 2 ^ 61) (hβLR : T.βLR = (1 + (pr : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0))
    (hTe : T.e = 24448) (hTQ : T.nQ = 256) (hβJ : T.βJ = 1)
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hlink : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0
        ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA))
            (Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA))
        ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0
        ∧ subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr
          hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_run_r13 R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG)
    P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 tr
    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB
    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin
    hdblk hdout pos hplane mk ops hE hops hcan hlink hdzero hzk

end Gates

end ZK60.ProtocolClassify
