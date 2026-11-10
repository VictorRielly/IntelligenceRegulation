/-
D63 lane L30 (2026-11-09), part 6: **the gates at the two registered token-words endpoints** (`w16r2TokenCommit`,
`R13.r13TokenCommit`, the media app's), where the input commitment's code is fixed.

`RunChainUGate.lean`'s gates take any input plane commitment and keep the link between the BASE-field extracted
matrix and the column test's chain event as one premise (`hlink`). At a registered endpoint:
* the radius (`2e + n + Q = N` exactly: `e = 8052` at W16R2, `e = 24,448` at R13) and the token-words plane are facts;
* the test's code is the registered code with scalars extended to the test's field (`rowFormK14`), and the step from
  the base field to the extension field is a theorem (`BindingUCode.lean`, finding L26-3). So `hlink` splits into
  three deterministic premises: `hwin` (the test's two windows at steps' ends on the run's transcript), `hread` (the
  test's matrix and openable set at its window are the run extractor's openings, embedded) and `hBal` (the test's
  second half alive at the end; `xB_subSt_of_opB` gives it from the endpoint opening's own `opB`).

The statements are `RunChainUGate.lean`'s with those replacements (written by
`results/zk60_lean_l30_20261109/l30_mk_token.py`); the proofs are the generic gates applied at the registered
commitment. Nothing is switched. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainUGate

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## The gate at W16R2's token-words endpoint -/

section TokenW16R2

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 280 → GF)
  (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (tagc : MTag)

-- W16R2's token-words endpoint commitment of the classify statement (L10's `w16r2TokenCommit`).
local notation "CinW" =>
  w16r2TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc

/-- **THE GATE at W16R2 at the registered token-words endpoint** (D63 lane L30):
`classifyU_productionReady_run_w16r2` at `Cin := w16r2TokenCommit …` and the radius `e = 8052`. The radius
and plane premises are facts of the registered commitment. The column test's code is the registered code
with scalars extended to the test's field (`hTenc`), so the link `hlink` is `xlink_of_read`: it splits
into `hwin` (the test's windows at steps' ends), `hread` (the test's matrix and openable set at its
window are the run extractor's, embedded) and `hBal` (the test's second half alive at the end). -/
theorem classifyU_productionReady_run_w16r2_token (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)
    (hr : 8 * (CinW).R ≤ Lq) (hon : HonestIn Coins (CinW)) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P (CinW) h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 5 924) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 113)
    (hR₀ : KR₀.SqForm 80 (80 * 351)) (hR₁ : KR₁.SqForm 80 (80 * 351)) (hH₀ : KH₀.SqForm 80 (80 * 351))
    (hH₁ : KH₁.SqForm 80 (80 * 351)) (eL : ℕ) (heL : eL ≤ 35153256) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F (Fin Rr) (Fin (2 ^ 14 + 280)) Cl 15)
    (hTenc : T.enc = encLin (Q := 280) (fun j => algebraMap GF F (w16r2Pts j)) (rowFormK14 F))
    (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ 15) → F)
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
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (mk : (CinW).SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin (2 ^ 15) → Option (MerkleOpening Dig Dig (ColR Rr)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => ((CinW).decodeIn (ops lg s) 8052).1 ((CinW).place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld ((CinW).decodeIn (ops lg s) 8052).1 ((CinW).decodeIn (ops lg s) 8052).2 ((CinW).exSalt (ops lg s))
          ((CinW).exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB (CinW).tag Lq (CinW).R h64 hr).Opens G (CinW).depth ((CinW).root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hwin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0 ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0)
    (hread : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA) = exX (ops (A.runLog G).2 (A.runLog G).1.1)
        ∧ Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA)
          = fun i j => algebraMap GF F (exU (ops (A.runLog G).2 (A.runLog G).1.1) i j))
    (hBal : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → ((CinW).decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) 8052).1 ((CinW).place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P (CinW) h64 hr hon.base 8052)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_run_w16r2 R Lq V P (CinW) h64 hr hon U hbij site kOf δOf E O 8052
    (by show 2 * 8052 + (2 ^ 14 + 280) ≤ 2 ^ 15; norm_num)
    (by show 2 ^ 15 ≤ 2 ^ 20; norm_num) tr
    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB
    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin
    hdblk hdout pos (fun _ => rfl) mk ops hE hops hcan
    (fun A G hv hx hnc => xlink_of_read w16r2Pts w16r2Form (rowFormK14 F) (rowFormK14_ext_w16r2 F) T hTenc
      8052 hTe RCx.W Ux Xx (A.runLog G).2 (tr G (A.run G)) (ops (A.runLog G).2 (A.runLog G).1.1)
      (hread A G hv hx).1 (hread A G hv hx).2 (hwin A G hv hx).1 (hwin A G hv hx).2.1
      (hwin A G hv hx).2.2 (hBal A G hv hx) hnc)
    hdzero hzk

end TokenW16R2

/-! ## The gate at R13's token-words endpoint, the media app's -/

section TokenR13

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
  (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tagc : MTag)

-- R13's token-words endpoint commitment of the classify statement (L17's `r13TokenCommit`).
local notation "CinR" =>
  R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc

/-- **THE GATE at R13, the media app's profile, at the registered token-words endpoint** (D63 lane L30):
`classifyU_productionReady_run_r13` at `Cin := R13.r13TokenCommit …` and the radius `e = 24,448`. The
radius and plane premises are facts of the registered commitment. The column test's code is the
registered code with scalars extended to the test's field (`hTenc`), so the link `hlink` is
`xlink_of_read`: it splits into `hwin`, `hread` and `hBal`. The run verifier `V` is any; at
`V := classifyRunV …` the instance is `classifyProtocolUExec` (`RunChainUExec.lean`). -/
theorem classifyU_productionReady_run_r13_token (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)
    (hr : 8 * (CinR).R ≤ Lq) (hon : HonestIn Coins (CinR)) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P (CinR) h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 7 (7 * 370)) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 110) (hB : KB.PowForm 1 126)
    (hR₀ : KR₀.SqForm 80 (80 * 451)) (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451))
    (hH₁ : KH₁.SqForm 80 (80 * 451)) (eL : ℕ) (heL : eL ≤ 2 ^ 26) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F (Fin Rr) (Fin (2 ^ 14 + 256)) Cl 16)
    (hTenc : T.enc = encLin (Q := 256) (fun j => algebraMap GF F (R13.r13Pts j)) (rowFormK14 F))
    (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ 16) → F)
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
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (mk : (CinR).SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin (2 ^ 16) → Option (MerkleOpening Dig Dig (ColR Rr)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => ((CinR).decodeIn (ops lg s) 24448).1 ((CinR).place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld ((CinR).decodeIn (ops lg s) 24448).1 ((CinR).decodeIn (ops lg s) 24448).2 ((CinR).exSalt (ops lg s))
          ((CinR).exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB (CinR).tag Lq (CinR).R h64 hr).Opens G (CinR).depth ((CinR).root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hwin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0 ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0)
    (hread : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA) = exX (ops (A.runLog G).2 (A.runLog G).1.1)
        ∧ Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA)
          = fun i j => algebraMap GF F (exU (ops (A.runLog G).2 (A.runLog G).1.1) i j))
    (hBal : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → ((CinR).decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) 24448).1 ((CinR).place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P (CinR) h64 hr hon.base 24448)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_run_r13 R Lq V P (CinR) h64 hr hon U hbij site kOf δOf E O 24448
    (by show 2 * 24448 + (2 ^ 14 + 256) ≤ 2 ^ 16; norm_num)
    (by show 2 ^ 16 ≤ 2 ^ 20; norm_num) tr
    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB
    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin
    hdblk hdout pos (fun _ => rfl) mk ops hE hops hcan
    (fun A G hv hx hnc => xlink_of_read R13.r13Pts R13.r13Form (rowFormK14 F) (rowFormK14_ext_r13 F) T hTenc
      24448 hTe RCx.W Ux Xx (A.runLog G).2 (tr G (A.run G)) (ops (A.runLog G).2 (A.runLog G).1.1)
      (hread A G hv hx).1 (hread A G hv hx).2 (hwin A G hv hx).1 (hwin A G hv hx).2.1
      (hwin A G hv hx).2.2 (hBal A G hv hx) hnc)
    hdzero hzk

end TokenR13

end ZK60.ProtocolClassify
