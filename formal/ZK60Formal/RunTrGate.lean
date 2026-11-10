/-
D63 lane L34 (2026-11-09), part 7: **the gate at R13 on the run's transcript, with every premise still left named**
(L30 §5.7 item 7).

L30's `classifyU_productionReady_run_r13_token` takes the run's transcript `tr`, the nine kinds on it with their
forms, the column test's parse, and the covers' premises. Here it is applied at:
* `tr := rtTr …` at a run schedule `Rn : RtRun V key domain Lq` (`RunTrVerify.lean`; at `V := classifyRunV …` the
  schedule is `rtRunClassify`, `RunTrStages.lean`, and the protocol object is `classifyProtocolUExec`);
* the nine kinds `rtKsl … rtKLU` of a kinds data `D` (`RunTrKinds.lean`), in the order `rtKo` (the openings' second
  halves, `M`, the openings' first halves, the slots, the relation draws, the host draws, LogUp);
* the column test's parse `rtRC2` (the wide parse).

So the premises `tr`, `Ksl … KLU`, `hℓ`, `hnp`, `hsl … hLU`, `heL`, `Ko`, `hKo`, `RCx`, `htrx`, `hℓx`, `hwA`, `hwB` of
the gate are DISCHARGED (from the schedule `Rn`, its profile's validity `hv`, the kinds data's validity `hD`, and the
test's windows after the header). What is left is exactly the statement's remaining hypotheses, by name:
* `O` (`ClassifyOpen`'s O1–O10, O12), `hzk`;
* the Merkle work `tag`, `C`, `coreOf`, `Vx`, `nx`, `rx`, `nrx`;
* the covers `halive` (in the order `rtKo`), `hdin`, `hdblk`, `hdout`;
* the endpoint `T` (with `hTenc`, `hTe`, `hTQ`, `hβJ`, `pr`, …), `Ux`, `Xx`, `hUc`, `hXc`, `mk`, `ops`, `hE`, `hops`,
  `hcan`, `hwin` (`RunTrWin.lean`'s `rt_hwin` proves it at the input endpoint opening's windows), `hread`, `hBal`,
  `hdzero`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrKinds
import ZK60Formal.RunTrVerify
import ZK60Formal.RunChainUToken

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

section GateR13

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
  (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tagc : MTag)

-- R13's token-words endpoint commitment of the classify statement (L17's `r13TokenCommit`).
local notation "CinR" =>
  R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc

/-- **THE GATE at R13 on the run's transcript** (D63 lane L34): L30's `classifyU_productionReady_run_r13_token` with the
run's transcript `rtTr` of a run schedule `Rn`, the nine kinds `rtKsl … rtKLU` of a kinds data `D` in the order `rtKo`,
and the column test parsed by the wide parse `rtRC2`. The gate's premises about the transcript, the kinds, their forms
and the parses are discharged; the hypotheses below are what is left. -/
theorem rt_productionReady_r13 (Rp : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)
    (hr : 8 * (CinR).R ≤ Lq) (hon : HonestIn Coins (CinR)) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64) (Rn : RtRun V key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen Rp Lq V P (CinR) h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl] [DecidableEq Cl]
    (T : XTest F (Fin Rr) (Fin (2 ^ 14 + 256)) Cl 16)
    (hTenc : T.enc = encLin (Q := 256) (fun j => algebraMap GF F (R13.r13Pts j)) (rowFormK14 F))
    (hTaA : (RtRun.pf Rn).hdrLen ≤ T.aA) (hTaB : (RtRun.pf Rn).hdrLen ≤ T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ 16) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 16)))
    (hUc : CutReads (Exec.Block.absOfC (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).C) Ux)
    (hXc : CutReads (Exec.Block.absOfC (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).C) Xx)
    (pr : ℕ) (hp1 : pr ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ pr) (hF : Fintype.card F = pr ^ 2)
    (hw0 : T.w0 ≤ 2 ^ 61) (hβLR : T.βLR = (1 + (pr : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0))
    (hTe : T.e = 24448) (hTQ : T.nQ = 256) (hβJ : T.βJ = 1)
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      AliveOrd (rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD) (Rp.Ps.length + 2)
        (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ InOk Rp (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD,
        ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.Ps.length),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ BlockOn Rp.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD,
        ∃ c ∈ K'.cs (k + 1) (A.runLog G).2,
          EntD K'.RC.W c (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ OutOk Rp ((classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD,
        ∃ c ∈ K'.cs (Rp.Ps.length + 1) (A.runLog G).2,
          EntD K'.RC.W c (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
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
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      tRem (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W
          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA) = some 0
        ∧ T.aB ≤ (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).length
        ∧ tRem (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W
          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aB) = some 0)
    (hread : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      Xx (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)
          = exX (ops (A.runLog G).2 (A.runLog G).1.1)
        ∧ Ux (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)
          = fun i j => algebraMap GF F (exU (ops (A.runLog G).2 (A.runLog G).1.1) i j))
    (hBal : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      subSt (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W
        (T.cB (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W Ux Xx (A.runLog G).2)
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → ((CinR).decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) 24448).1 ((CinR).place k) i = 0)
        → ∃ K' ∈ rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD,
          K'.Dm (Rp.Ps.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S Rp) (classifyArith S Rp) (classifyProtocolU S Rp Lq V P (CinR) h64 hr hon.base 24448)
      εcTarget εsTarget εsTarget εzkTarget :=
  have hf := rtK_forms key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD
  have hch := rtK_chain key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD
  have hnpL : (RtRun.pf Rn).parts.length = Rp.Ps.length + 2 :=
    (RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) O.blocks.2)
  classifyU_productionReady_run_r13_token Rr dR hpos place msg msg_place pad salt path tagc Rp Lq V P h64 hr hon
    U hbij site kOf δOf E O (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn))
    (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKLU key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (fun K' hK' => (hch K' hK').1) (fun K' hK' => (hch K' hK').2.trans hnpL) hf.1 hf.2.1 hf.2.2.1 hf.2.2.2.1
    hf.2.2.2.2.1 hf.2.2.2.2.2.1 hf.2.2.2.2.2.2.1 hf.2.2.2.2.2.2.2.1 D.eL hD.heL hf.2.2.2.2.2.2.2.2
    (rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtKo_mem key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD)
    (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv)
    (rtRC2_chain key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv)
    (rtRC2_ℓ key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).le T hTenc
    (rtRCx_hw key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv T.aA hTaA)
    (rtRCx_hw key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv T.aB hTaB) Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR
    hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin hdblk hdout mk ops hE hops hcan hwin hread hBal
    hdzero hzk

end GateR13

end ZK60.ProtocolClassify
