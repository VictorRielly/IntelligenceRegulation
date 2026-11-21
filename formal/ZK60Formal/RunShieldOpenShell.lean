/-
D63 lane L68b (2026-11-20): **heterogeneous `ClassifyOpenP` shell for Shieldstral T128 R13
(`RunShieldOpenShell.lean`)**, wired directly onto `sshC_productionReadyL_epP_blkEF` (`RunStgShieldClTopEF.lean`,
where all 4 stage premises and `hEmb` have already been discharged).

What this file proves (only at most `propext`, `Classical.choice`, `Quot.sound`):
1. **Heterogeneous `ClassifyRunPublicP` ZK bridge (`ZK60.ZKHonest`)**: ports `ZKHonestRun.lean:225–365` from uniform
   `ClassifyRunPublic S` to per-block-shape `ClassifyRunPublicP S` (`classifyInputInhabitedP`, `classifyP_adm_standin`,
   `classifyP_standin_verdict`, `classifyP_zk_of_model`, `classifyP_zk_refErr`, `classifyP_zk_of_prog_model`,
   `classifyP_zk_of_prog_refErr`, `classifyP_zk_cap110`, `classifyUP_zk_cap110`), PLUS the concrete 28-segment
   Shieldstral T128 R13 ZK budget `shdRunErr` (`colDigest` unprogrammed `.dep`, Merkle `nodeHash` visible, exact
   28-segment counts `mT = 79`, `qpT = 283822`, `leaves = 5359616`, `nodes = 5359504`, `pts = 11002940`), proved
   within `εzkTarget q R` for every `R ≤ 2^86` (`shdRunErr_cap_86`, `shdRunErr_hzk` — 22 bits above `2^64`).
   Note: `shdRunErr` is used by neither top below (`sshC_productionReadyL_epP_openShell` and `_okPre` still take
   `hzk` at `refErr RunK.kinds`, matching `blkEF`).
2. **Heterogeneous `O.parts` & `O.refuse` bridges (`ZK60.Exec.StageV`)**: `classifyP_parts_of_segs` (splits `O.parts`
   into per-part `SegComplete` premises for transcript-aware `P : RunP`, bypassing L32-1's transcript-free
   `incP`/`outcP`/`D12aBlockP.core`) and `classifyP_refuse_of_cover`.
3. **Concrete Shieldstral T128 R13 `ClassifyOpenP` shell (`ZK60.ProtocolClassify`)**:
   - `shdP_cin_commit`: discharges `O.commit` outright on `shdP_cin Hdr tag` (`N = 2^11`, `depth = 11 ≤ 64`,
     `root = ClsStmt.inRoot`, `ok x = ∀ t, x t < gP`) without unfolding `epForm` / `epPts`.
   - `shdP_siteCount`, `shdP_SiteIdx`, `shdP_kOf`, `shdP_δOf`, `shdP_emptySite`, `shdP_counts_of_inc`, `shdP_counts`,
     `shdP_refusal_total_le`: discharges the `∑ kOf ≤ 2^85` and `∑ δOf ≤ 2^-41` global sum bounds of `O.counts` (and
     completeness refusal total `≤ εcTarget`) via `HonestRun.shield_k_le_inc` at Shieldstral T128 R13's
     `(M, cap, kEmb) = (2^17, 2^20, 12)`.
   - `shdP_classifyOpenP_shell`: constructs `O : ClassifyOpenP` at ANY `εzk`, `embFold`, and `P : RunP`, discharging
     O1 (`O.width`), O5 (`O.shapes`), O6 (`O.blocks`), `O.commit`, and O10's two global sum bounds (`∑ kOf ≤ 2^85`,
     `∑ δOf ≤ 2^-41`).
   - `sshC_productionReadyL_epP_openShell` (and `sshC_productionReadyL_epP_openShell_okPre` at `preA = preB = .ok ()`):
     applies `sshC_productionReadyL_epP_blkEF` directly to `shdP_classifyOpenP_shell`, `classifyP_parts_of_segs`, and
     `shdP_zeroRunExt`. This splits `O : ClassifyOpenP` (discharging O1, O5, O6, `O.commit`, and O10's two sums, and
     removing `E0b`, `ι`, `kOf`, `δOf`) while O2 (`hweights`), O3 (`hinPub`), O4 (`houtPub`), O7 (`hpol`, discharged
     in `_okPre`), O8 (`hsegIn`, `hsegBlk`, `hsegOut`), O9 (`hcover`), O10 per-site (`hk`, `hδ` — fixing the 7 site
     families and `δ = 0`), and O12 (`hzk`, still at `refErr RunK.kinds`) reappear as explicit premises of the same
     strength alongside the setting hypotheses (`hL20`, `hL64`, `hR`, `hhdrFit`, `hV131072`).

Status of `L68b` findings for downstream `L68c`:
- `L68b-1`/`L68b-2`: fixed by ruling L63-9 (`RunShieldBlkInst.lean` updated to `mRows := 50` and `.host` on slots
  `{2, 14, 15, 16, 17, 18}`).
- `L68b-3`: the unbounded slot-degree quantifier in L25/L29/L32/L39 was repaired by ruling L63-10
  (`RunStgShieldSlotDeg.lean`), while L32-1 (transcript-free `incP`/`outcP`/`D12aBlockP.core`) stays un-repaired
  upstream; `classifyP_parts_of_segs` takes transcript-aware `P : RunP` directly.
- `L68b-4`/`L68b-5`: `blkEF` and both tops below still carry `hzk` at `refErr RunK.kinds`, which undercounts the
  28-segment run (`mT = 79 > 32`, `chain = 283820 > 57344`, `leaves = 5359616 > 3784704`) and puts `colDigest` in
  `hUw`; `shdRunErr` (`shdRunErr_cap_86` proved below) is NOT used by either top yet and awaits L68c's concrete `O.zk`
  obligations.
-/
import ZK60Formal.RunStgShieldClTopEF
import ZK60Formal.RunShapeShieldOpen
import ZK60Formal.HonestRunCount
import ZK60Formal.ZKHonestRun
import ZK60Formal.StageVerifyExecAssemble

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

/-! ## 1. Heterogeneous `ClassifyRunPublicP` zero-knowledge bridge & concrete 28-segment `shdRunErr` budget -/

namespace ZK60.ZKHonest

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKCount ZK60.ZKHybrid ZK60.Exec ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.RunShape ZK60.ProtocolClassify.RunShapeP

section ClassifyP

variable {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}

/-- The per-block-shape classify model's inputs are inhabited (needed by `standin`). -/
instance classifyInputInhabitedP (R : ClassifyRunPublicP S) : Inhabited (classifyModelP R).Input :=
  ⟨fun _ => 0⟩

/-- **Stand-in admissibility for `ClassifyRunPublicP`**: the served bit is in `ClsLeak` (`leak_servedP`), and `standin`
preserves leakage (`standin_spec`). -/
theorem classifyP_adm_standin (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (x : (classifyModelP R).Input) :
    (classifyModelP R).admissible (standin (classifyProtocolP R Lq V P Cin h64 hr base) ()
        ((classifyModelP R).publicPart ((classifyModelP R).forward () x),
          (classifyProtocolP R Lq V P Cin h64 hr base).leak x))
      ↔ (classifyModelP R).admissible x := by
  have hspec := standin_spec (classifyProtocolP R Lq V P Cin h64 hr base) () x
  have hl := (Prod.mk.inj hspec).2
  have e1 := leak_servedP R Lq V P Cin h64 hr base
    (standin (classifyProtocolP R Lq V P Cin h64 hr base) ()
      ((classifyModelP R).publicPart ((classifyModelP R).forward () x),
        (classifyProtocolP R Lq V P Cin h64 hr base).leak x))
  have e2 := leak_servedP R Lq V P Cin h64 hr base x
  have hl' : ((classifyProtocolP R Lq V P Cin h64 hr base).leak
      (standin (classifyProtocolP R Lq V P Cin h64 hr base) ()
        ((classifyModelP R).publicPart ((classifyModelP R).forward () x),
          (classifyProtocolP R Lq V P Cin h64 hr base).leak x))).served
      = ((classifyProtocolP R Lq V P Cin h64 hr base).leak x).served := congrArg ClsLeak.served hl
  exact ⟨fun h1 => e2.mp (hl'.symm.trans (e1.mpr h1)), fun h2 => e1.mp (hl'.trans (e2.mpr h2))⟩

/-- **Stand-in verdict equality for `ClassifyRunPublicP`**. -/
theorem classifyP_standin_verdict (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (x : (classifyModelP R).Input) :
    (classifySpecP R (standin (classifyProtocolP R Lq V P Cin h64 hr base) ()
        ((classifyModelP R).publicPart ((classifyModelP R).forward () x),
          (classifyProtocolP R Lq V P Cin h64 hr base).leak x))).getD 0
      = (classifySpecP R x).getD 0 :=
  (Prod.mk.inj (standin_spec (classifyProtocolP R Lq V P Cin h64 hr base) () x)).1

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

open Classical in
/-- **Zero knowledge of the per-block-shape classify run as ONE receipt** (`ClassifyOpenP.zk`, heterogeneous port of
`ZKHonestRun.classify_zk_of_model`). Discharges class-(B) refusals via `prove_unservedP` and stand-in preservation via
`classifyP_adm_standin` + `classifyP_standin_verdict`. -/
theorem classifyP_zk_of_model (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (pOC : (S.Tok → ℕ) → Coins → OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (qp : ℕ)
    (hrun : ∀ G x c, (pOC x c).run G = (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x c)
    (hbd : ∀ x c, (pOC x c).Bounded qp)
    (FM : FSModel (QB Lq) Dig {x // (classifyModelP R).admissible x} Coins (ClsStmt Hdr × ClsReceipt))
    (hP : ∀ G (x : {x // (classifyModelP R).admissible x}) c,
      (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x.1 c = FM.prove G x c)
    (G : (Fin FM.k → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ FM.vis v i)
    (hrefG : ∀ x c v, G v → FM.out x c v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 → ∀ v : Fin FM.k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
          = (PMF.uniformOfFintype Coins).map (fun c => FM.out x' c v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ) (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (pOC x c) Wp) (hwba : ∀ x c, WB KUf (pOC x c) Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin FM.k → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin FM.k → Dig), ¬ G v →
      ∀ (Z : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Z o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Z (FM.out x c v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ ωh) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base)
      (fun q R' => ∑ j ∈ range R', wStep δp ωp δh ωh εc q R' j) :=
  zk_of_refModel (P := classifyProtocolP R Lq V P Cin h64 hr base) (fun _ => pOC) qp (fun _ => hrun) (fun _ => hbd)
    (fun _ => (classifyModelP R).admissible) (fun _ => (P.refused, []))
    (fun _ H x c hx => prove_unservedP R Lq V P Cin h64 hr base H x c hx)
    (fun _ x => classifyP_adm_standin R Lq V P Cin h64 hr base x)
    (fun _ => FM) (fun _ => hP) (fun _ => G) (fun _ => hvisG) (fun _ => hrefG)
    (fun _ x x' hx' v hg => hHV x x'
      ((classifyP_standin_verdict R Lq V P Cin h64 hr base x.1).symm.trans
        (congrArg (fun y => (classifySpecP R y).getD 0) hx'.symm)) v hg)
    (fun _ => Kf) (fun _ => KUf) (fun _ => Km) (fun _ => KUm) (fun _ => Wp) (fun _ => Wpa) (fun _ => Kc)
    (fun _ => hKm) (fun _ => hKUm) (fun _ => hwb) (fun _ => hwba) (fun _ => hKw) (fun _ => hKc) (fun _ => hKG)
    (fun _ => hUw) δp ωp δh ωh εc (fun _ => hrδp) (fun _ => hrωp) (fun _ => hrεc) (fun _ => hrδh) (fun _ => hrωh)

open Classical in
/-- **`classifyP_zk_of_model` specialized to `refErr Z`**. -/
theorem classifyP_zk_refErr (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (Z : ZKKinds)
    (pOC : (S.Tok → ℕ) → Coins → OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (qp : ℕ)
    (hrun : ∀ G x c, (pOC x c).run G = (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x c)
    (hbd : ∀ x c, (pOC x c).Bounded qp)
    (FM : FSModel (QB Lq) Dig {x // (classifyModelP R).admissible x} Coins (ClsStmt Hdr × ClsReceipt))
    (hP : ∀ G (x : {x // (classifyModelP R).admissible x}) c,
      (classifyProtocolP R Lq V P Cin h64 hr base).prove G () x.1 c = FM.prove G x c)
    (G : (Fin FM.k → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ FM.vis v i)
    (hrefG : ∀ x c v, G v → FM.out x c v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 → ∀ v : Fin FM.k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
          = (PMF.uniformOfFintype Coins).map (fun c => FM.out x' c v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ) (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (pOC x c) Wp) (hwba : ∀ x c, WB KUf (pOC x c) Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin FM.k → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin FM.k → Dig), ¬ G v →
      ∀ (Zs : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Zs o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Zs (FM.out x c v))).card ≤ Wt)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ Z.δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ Z.ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ Z.εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ 2 * (Z.δh + Z.δp))
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ 2 * (Z.ωh + Z.ωp)) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) (refErr Z) :=
  classifyP_zk_of_model R Lq V P Cin h64 hr base pOC qp hrun hbd FM hP G hvisG hrefG hHV
    Kf KUf Km KUm Wp Wpa Kc hKm hKUm hwb hwba hKw hKc hKG hUw
    Z.δp Z.ωp (2 * (Z.δh + Z.δp)) (2 * (Z.ωh + Z.ωp)) Z.εc hrδp hrωp hrεc hrδh hrωh

open Classical in
/-- **Program-based `O.zk` at general rates `(δp, ωp, δh, ωh, εc)` for `ClassifyRunPublicP`** (`zk_of_prog`
specialized to `classifyProtocolP`; supports both `refErr Z` and `shdRunErr` directly). -/
theorem classifyP_zk_of_prog_model (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hprog : ∀ H (x : {x // (classifyModelP R).admissible x}) c,
      (prog x c).run H = (classifyProtocolP R Lq V P Cin h64 hr base).prove H () x.1 c)
    (k : ℕ) (hk : ∀ x c, (prog x c).PtLE k)
    (hres : ∀ x c (H' : QB Lq → Dig) (v : ℕ → Dig),
      (prog x c).res H' v 0 = (prog x c).res (fun _ => (default : Dig)) v 0)
    (qp : ℕ) (hq : ∀ x c, (prog x c).QLE qp)
    (pad : ℕ → Dig → QB Lq)
    (dep : {x // (classifyModelP R).admissible x} → Coins → Set (QB Lq))
    (hdep : ∀ x c, (prog x c).DepIn (dep x c))
    (vis : (Fin k → Dig) → Fin k → Prop)
    (vp : ClsStmt Hdr × ClsReceipt → (QB Lq → Dig) → (Fin k → Dig) → Fin k → QB Lq)
    (hvis : ∀ x c H v i, vis v i →
      PProg.ptsOf pad (prog x c) H v i = vp (PProg.outOf (prog x c) v) H v i)
    (G : (Fin k → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ vis v i)
    (hrefG : ∀ x c v, G v → PProg.outOf (prog x c) v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 → ∀ v : Fin k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x' c) v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ)
    (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (prog x c).oc Wp) (hwba : ∀ x c, WB KUf (prog x c).oc Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (univ.filter (fun s : Coins × (Fin k → Dig) =>
      ∃ i, PProg.ptsOf pad (prog x s.1) H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (univ.filter (fun s : Coins × (Fin k → Dig) =>
      ¬ Function.Injective (PProg.ptsOf pad (prog x s.1) H s.2)
        ∨ ∃ i, PProg.ptsOf pad (prog x s.1) H s.2 i ∈ dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin k → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin k → Dig), ¬ G v →
      ∀ (Zs : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Zs o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ vis v i
        ∧ PProg.ptsOf pad (prog x c) H v i ∈ Zs (PProg.outOf (prog x c) v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ ωh) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base)
      (fun q R' => ∑ j ∈ range R', wStep δp ωp δh ωh εc q R' j) :=
  zk_of_prog (P := classifyProtocolP R Lq V P Cin h64 hr base)
    (fun _ => (classifyModelP R).admissible) (fun _ => (P.refused, []))
    (fun _ H x c hx => prove_unservedP R Lq V P Cin h64 hr base H x c hx)
    (fun _ x => classifyP_adm_standin R Lq V P Cin h64 hr base x)
    (fun _ => prog) (fun _ => hprog) (fun _ => k) (fun _ => hk) (fun _ => hres) qp (fun _ => hq)
    (fun _ => pad) (fun _ => dep) (fun _ => hdep) (fun _ => vis) (fun _ => vp) (fun _ => hvis)
    (fun _ => G) (fun _ => hvisG) (fun _ => hrefG)
    (fun _ x x' hx' v hg => hHV x x'
      ((classifyP_standin_verdict R Lq V P Cin h64 hr base x.1).symm.trans
        (congrArg (fun y => (classifySpecP R y).getD 0) hx'.symm)) v hg)
    (fun _ => Kf) (fun _ => KUf) (fun _ => Km) (fun _ => KUm) (fun _ => Wp) (fun _ => Wpa) (fun _ => Kc)
    (fun _ => hKm) (fun _ => hKUm) (fun _ => hwb) (fun _ => hwba) (fun _ => hKw) (fun _ => hKc) (fun _ => hKG)
    (fun _ => hUw) δp ωp δh ωh εc
    (fun _ => hrδp) (fun _ => hrωp) (fun _ => hrεc) (fun _ => hrδh) (fun _ => hrωh)

open Classical in
/-- **Program-based `O.zk` at `refErr Z` for `ClassifyRunPublicP`**. -/
theorem classifyP_zk_of_prog_refErr (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (Z : ZKKinds)
    (prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hprog : ∀ H (x : {x // (classifyModelP R).admissible x}) c,
      (prog x c).run H = (classifyProtocolP R Lq V P Cin h64 hr base).prove H () x.1 c)
    (k : ℕ) (hk : ∀ x c, (prog x c).PtLE k)
    (hres : ∀ x c (H' : QB Lq → Dig) (v : ℕ → Dig),
      (prog x c).res H' v 0 = (prog x c).res (fun _ => (default : Dig)) v 0)
    (qp : ℕ) (hq : ∀ x c, (prog x c).QLE qp)
    (pad : ℕ → Dig → QB Lq)
    (dep : {x // (classifyModelP R).admissible x} → Coins → Set (QB Lq))
    (hdep : ∀ x c, (prog x c).DepIn (dep x c))
    (vis : (Fin k → Dig) → Fin k → Prop)
    (vp : ClsStmt Hdr × ClsReceipt → (QB Lq → Dig) → (Fin k → Dig) → Fin k → QB Lq)
    (hvis : ∀ x c H v i, vis v i →
      PProg.ptsOf pad (prog x c) H v i = vp (PProg.outOf (prog x c) v) H v i)
    (G : (Fin k → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ vis v i)
    (hrefG : ∀ x c v, G v → PProg.outOf (prog x c) v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 → ∀ v : Fin k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x' c) v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ)
    (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (prog x c).oc Wp) (hwba : ∀ x c, WB KUf (prog x c).oc Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (univ.filter (fun s : Coins × (Fin k → Dig) =>
      ∃ i, PProg.ptsOf pad (prog x s.1) H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (univ.filter (fun s : Coins × (Fin k → Dig) =>
      ¬ Function.Injective (PProg.ptsOf pad (prog x s.1) H s.2)
        ∨ ∃ i, PProg.ptsOf pad (prog x s.1) H s.2 i ∈ dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin k → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin k → Dig), ¬ G v →
      ∀ (Zs : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Zs o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ vis v i
        ∧ PProg.ptsOf pad (prog x c) H v i ∈ Zs (PProg.outOf (prog x c) v))).card ≤ Wt)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ Z.δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ Z.ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin k → Dig)) ≤ Z.εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ 2 * (Z.δh + Z.δp))
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ 2 * (Z.ωh + Z.ωp)) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) (refErr Z) :=
  classifyP_zk_of_prog_model R Lq V P Cin h64 hr base prog hprog k hk hres qp hq pad dep hdep vis vp hvis G hvisG hrefG
    hHV Kf KUf Km KUm Wp Wpa Kc hKm hKUm hwb hwba hKw hKc hKG hUw
    Z.δp Z.ωp (2 * (Z.δh + Z.δp)) (2 * (Z.ωh + Z.ωp)) Z.εc hrδp hrωp hrεc hrδh hrωh

/-- **Heterogeneous port of `classify_zk_cap110`**. -/
theorem classifyP_zk_cap110 (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (hzk : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) (refErr RunK.kinds)) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base)
        (fun q R' => min (refErr RunK.kinds q R') 1)
      ∧ ∀ q R', (R' ≤ 2 ^ 110 ∨ 2 ^ 120 ≤ R') → min (refErr RunK.kinds q R') 1 ≤ εzkTarget q R' := by
  refine ⟨zeroKnowledge_min_one hzk, fun q R' hR => ?_⟩
  rcases hR with hR | hR
  · exact (min_le_left _ _).trans (runK_ref_cap_110 q R' hR)
  · exact (min_le_right _ _).trans (one_le_target_of_large q R' hR)

/-- **Heterogeneous port of `classifyU_zk_cap110`** (via `zkUP_of_zkP`). -/
theorem classifyUP_zk_cap110 (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ)
    (hzk : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) (refErr RunK.kinds)) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e)
        (fun q R' => min (refErr RunK.kinds q R') 1)
      ∧ ∀ q R', (R' ≤ 2 ^ 110 ∨ 2 ^ 120 ≤ R') → min (refErr RunK.kinds q R') 1 ≤ εzkTarget q R' :=
  ⟨zkUP_of_zkP R Lq V P Cin h64 hr base e (classifyP_zk_cap110 R Lq V P Cin h64 hr base hzk).1,
    (classifyP_zk_cap110 R Lq V P Cin h64 hr base hzk).2⟩

end ClassifyP

/-! ### Exact 28-segment Shieldstral T128 R13 ZK budget (`colDigest` as `.dep`, `nodeHash` visible) -/

section ShdRunBudget

/-- Per-query before-request rate for the actual 28-segment Shieldstral T128 R13 run (`mT = 79`,
`leaves = 5,359,616` at `2^-256` from fresh leaf salts, `nodes = 5,359,504` at `2^-512`). -/
noncomputable def shdRun_δp : ℝ≥0∞ :=
  ((79 + 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- Per-query after-request rate (`2 * (leaves * 2^-256 + shdRun_δp)`, unopened salted leaves only; `colDigest` is
`.dep` and Merkle `nodeHash` is visible). -/
noncomputable def shdRun_δh : ℝ≥0∞ :=
  2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRun_δp)

/-- Per-receipt prover-query weight before request (`qpT = 283,822`, `mT = 79`, `leaves = 5,359,616`,
`nodes = 5,359,504`). -/
noncomputable def shdRun_ωp : ℝ≥0∞ :=
  ((283822 * 79 + 5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
    + ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- Per-receipt prover-query weight after request (`2 * (leaves^2 * 2^-256 + shdRun_ωp)`). -/
noncomputable def shdRun_ωh : ℝ≥0∞ :=
  2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + shdRun_ωp)

/-- Point-collision / dep-hit rate (`pts = 283,820 + 5,359,616 + 5,359,504 = 11,002,940`). -/
noncomputable def shdRun_εc : ℝ≥0∞ :=
  ((11002940 * 11002940 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- Total refusing-prover ZK error function at the actual 28-segment Shieldstral T128 R13 counts. -/
noncomputable def shdRunErr (q R : ℕ) : ℝ≥0∞ :=
  ∑ j ∈ range R, wStep shdRun_δp shdRun_ωp shdRun_δh shdRun_ωh shdRun_εc q R j

private theorem nat_mul_inv_pow_le {n a k : ℕ} (hn : n ≤ 2 ^ a) (hk : a ≤ k) :
    (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k ≤ (2⁻¹ : ℝ≥0∞) ^ (k - a) := by
  have he : k = a + (k - a) := by omega
  calc (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ k
      ≤ ((2 ^ a : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by
        rw [← he]; exact mul_le_mul_left (Nat.cast_le.mpr hn) _
    _ = (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ (a + (k - a)) := by norm_cast
    _ = (2⁻¹ : ℝ≥0∞) ^ (k - a) := two_pow_mul_inv_pow a (k - a)

private theorem shdRun_δp_le : shdRun_δp ≤ (2⁻¹ : ℝ≥0∞) ^ 233 := by
  have h1 : ((79 + 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
      ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
    mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
  have h2 : (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    calc (5359504 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
        ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 23) := nat_mul_inv_pow_le (a := 23) (by norm_num) (by norm_num)
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
      _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
  calc shdRun_δp
      ≤ ((2 ^ 23 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
    _ = (((2 ^ 23 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 23) := nat_mul_inv_pow_le (a := 23) (by norm_num) (by norm_num)

private theorem shdRun_ωp_le : shdRun_ωp ≤ (2⁻¹ : ℝ≥0∞) ^ 211 := by
  have h1 : ((283822 * 79 + 5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
      ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
    mul_le_mul_left (Nat.cast_le.mpr (by norm_num)) _
  have h2 : ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    calc ((5359504 * 5359504 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
        ≤ (2⁻¹ : ℝ≥0∞) ^ (512 - 46) := nat_mul_inv_pow_le (a := 46) (by norm_num) (by norm_num)
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
      _ = (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by ring
  calc shdRun_ωp
      ≤ ((2 ^ 45 - 1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (1 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := add_le_add h1 h2
    _ = (((2 ^ 45 - 1 + 1 : ℕ) : ℝ≥0∞)) * (2⁻¹ : ℝ≥0∞) ^ 256 := by push_cast; ring
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 45) := nat_mul_inv_pow_le (a := 45) (by norm_num) (by norm_num)

/-- **Exact 28-segment Shieldstral T128 R13 ZK budget up to `R ≤ 2^86`** (`22` bits above `ProductionReadyL`'s
`2^64` cap, without polynomial-pad conditional entropy assumptions). -/
theorem shdRunErr_cap_86 (q R : ℕ) (hR : R ≤ 2 ^ 86) : shdRunErr q R ≤ εzkTarget q R := by
  have hL : (5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 233 :=
    nat_mul_inv_pow_le (a := 23) (by norm_num) (by norm_num)
  have hL2 : ((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 ≤ (2⁻¹ : ℝ≥0∞) ^ 211 :=
    nat_mul_inv_pow_le (a := 45) (by norm_num) (by norm_num)
  have hδsum : shdRun_δp + shdRun_δh ≤ (2⁻¹ : ℝ≥0∞) ^ 230 := by
    have heq : shdRun_δp + shdRun_δh = 3 * shdRun_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256) := by
      unfold shdRun_δh; ring
    rw [heq]
    calc 3 * shdRun_δp + 2 * ((5359616 : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256)
        ≤ 3 * (2⁻¹ : ℝ≥0∞) ^ 233 + 2 * (2⁻¹ : ℝ≥0∞) ^ 233 :=
          add_le_add (mul_le_mul_right shdRun_δp_le _) (mul_le_mul_right hL _)
      _ = 5 * (2⁻¹ : ℝ≥0∞) ^ 233 := by ring
      _ ≤ (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + 230) := by
          have h58 : (5 : ℝ≥0∞) ≤ (2 : ℝ≥0∞) ^ 3 := by norm_num
          simpa using mul_le_mul_left h58 ((2⁻¹ : ℝ≥0∞) ^ 233)
      _ = (2⁻¹ : ℝ≥0∞) ^ 230 := two_pow_mul_inv_pow 3 230
  have hωsum : shdRun_ωp + shdRun_ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 208 := by
    have heq : shdRun_ωp + shdRun_ωh = 3 * shdRun_ωp + 2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256) := by
      unfold shdRun_ωh; ring
    rw [heq]
    calc 3 * shdRun_ωp + 2 * (((5359616 * 5359616 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256)
        ≤ 3 * (2⁻¹ : ℝ≥0∞) ^ 211 + 2 * (2⁻¹ : ℝ≥0∞) ^ 211 :=
          add_le_add (mul_le_mul_right shdRun_ωp_le _) (mul_le_mul_right hL2 _)
      _ = 5 * (2⁻¹ : ℝ≥0∞) ^ 211 := by ring
      _ ≤ (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + 208) := by
          have h58 : (5 : ℝ≥0∞) ≤ (2 : ℝ≥0∞) ^ 3 := by norm_num
          simpa using mul_le_mul_left h58 ((2⁻¹ : ℝ≥0∞) ^ 211)
      _ = (2⁻¹ : ℝ≥0∞) ^ 208 := two_pow_mul_inv_pow 3 208
  have hε : shdRun_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 209 :=
    nat_mul_inv_pow_le (a := 47) (by norm_num) (by norm_num)
  refine wBudget_le q R 86 hR _ _ _ _ _ ?_ ?_
  · calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRun_δp + shdRun_δh)
        ≤ 2 ^ 87 * (2⁻¹ : ℝ≥0∞) ^ (87 + 143) := by simpa using mul_le_mul_right hδsum ((2 : ℝ≥0∞) ^ 87)
      _ = (2⁻¹ : ℝ≥0∞) ^ 143 := two_pow_mul_inv_pow 87 143
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := inv_pow_le_inv_pow (by norm_num)
  · have h1 : (2 : ℝ≥0∞) ^ (86 + 1) * (shdRun_ωp + shdRun_ωh) ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRun_ωp + shdRun_ωh)
          ≤ 2 ^ 87 * (2⁻¹ : ℝ≥0∞) ^ (87 + 121) := by simpa using mul_le_mul_right hωsum ((2 : ℝ≥0∞) ^ 87)
        _ = (2⁻¹ : ℝ≥0∞) ^ 121 := two_pow_mul_inv_pow 87 121
    have h2 : 4 * shdRun_εc ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc 4 * shdRun_εc
          ≤ (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 207) := by
            simpa [show (4 : ℝ≥0∞) = (2 : ℝ≥0∞) ^ 2 by norm_num] using mul_le_mul_right hε (4 : ℝ≥0∞)
        _ = (2⁻¹ : ℝ≥0∞) ^ 207 := two_pow_mul_inv_pow 2 207
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 := inv_pow_le_inv_pow (by norm_num)
    calc (2 : ℝ≥0∞) ^ (86 + 1) * (shdRun_ωp + shdRun_ωh) + 4 * shdRun_εc
        ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 := add_le_add h1 h2
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120

/-- Numeric `hzk` discharge for `shdRunErr` at `ProductionReadyL`'s `q, R' ≤ 2^64` range. -/
theorem shdRunErr_hzk (q R' : ℕ) (_hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) :
    shdRunErr q R' ≤ εzkTarget q R' :=
  shdRunErr_cap_86 q R' (hR'.trans (by norm_num))

end ShdRunBudget

end ZK60.ZKHonest

/-! ## 2. Non-vacuous heterogeneous `O.parts` and `O.refuse` bridges -/

namespace ZK60.Exec.StageV

open ZK60 ZK60.ProtocolClassify ZK60.HonestClassify ZK60.TokenRun ZK60.RunShape ZK60.ProtocolClassify.RunShapeP
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams SegGeom Segment)

variable {Hdr Coins : Type} {S : ZK60.Block.BlockShape} {Salt : Type}

/-- **Non-vacuous `O.parts` decomposition for `ClassifyRunPublicP`**: splits
`List.Forall₂ (SegComplete ...) (P.parts V.L) V.parts` cleanly into stage IN-C, `V.L` blocks, and stage OUT-C
without invoking L25/L29's vacuous unbounded-degree `IncOK`/`D12aBlockOK`/`OutcOK`. -/
theorem classifyP_parts_of_segs (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (hin : SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr base) P.inC (inSeg V.inC))
    (hblk : ∀ k, k < V.L →
      SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr base) (P.blk k) (blockSeg V.blk k))
    (hout : SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr base) P.outC (outSeg V.outC)) :
    List.Forall₂ (SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr base))
      (P.parts V.L) V.parts :=
  parts_complete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr base) V P hin hblk hout

/-- **Heterogeneous port of `HonestClassifyRun.classify_refuse_of_cover`** (`ClassifyOpenP.refuse` from site cover). -/
theorem classifyP_refuse_of_cover [Fintype Coins] [Nonempty Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    {ι : Type} (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (hcover : ∀ x, (classifyModelP R).admissible x → ∀ G c,
      honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires U G c) :
    ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c
        = .ok r := by
  intro x hx G c hno
  cases hs : honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c with
  | ok r => exact ⟨r, rfl⟩
  | error e =>
    cases e
    obtain ⟨i, hi⟩ := hcover x hx G c hs
    cases hno i hi

end ZK60.Exec.StageV

/-! ## 3. Concrete Shieldstral T128 R13 `ClassifyOpenP` shell (`O.commit`, `O.counts`, `openShell`) -/

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Segment SegGeom)
open ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape.Shield (shieldS0 ShieldRun)

section OpenShell

/-- **Concrete `O.commit` discharge on `shdP_cin Hdr tag`** (`N = 2^11`, `depth = 11 ≤ 64`, `root = ClsStmt.inRoot`,
`ok x = ∀ t, x t < gP`), without unfolding `epForm` or `epPts`. -/
theorem shdP_cin_commit (Hdr : Type) (tag : MTag) :
    (∀ x : shieldS0.Tok → ℕ, (∀ t, x t < gP) → (shdP_cin Hdr tag).ok x)
      ∧ (shdP_cin Hdr tag).N ≤ 2 ^ (shdP_cin Hdr tag).depth
      ∧ (∀ s : ClsStmt Hdr, (shdP_cin Hdr tag).root s = s.inRoot)
      ∧ (shdP_cin Hdr tag).depth ≤ 64 :=
  ⟨fun _ hx => hx, le_rfl, fun _ => rfl, by change 11 ≤ 64; omega⟩

/-- **Concrete Shieldstral T128 R13 refusal-site count envelope** (`HonestRun.shield_k_le_inc` at `kEmb = 12`):
`0`: dependent proximity pairs (`84 ≤ 2^7`), `1`: zero opening draws (`5,385 ≤ 2^20`), `2`: CFS `c = 0` (`610 ≤ 2^12`),
`3`: degenerate extension `e ∈ {0, 1}` (`662 ≤ 2^12`), `4`: `define` zero draws (`447 ≤ 2^12`),
`5`: LogUp `α` + stage IN-C's `12 + 1` `r_emb` draws (`14 ≤ 2^7 + 13`), `6`: D66(3) dictionaries (`0 ≤ 2^5`). -/
def shdP_siteCount : Fin 7 → ℕ
  | 0 => 2 ^ 7
  | 1 => 2 ^ 20
  | 2 => 2 ^ 12
  | 3 => 2 ^ 12
  | 4 => 2 ^ 12
  | 5 => 2 ^ 7 + (12 + 1)
  | 6 => 2 ^ 5

/-- Concrete site index type `SiteIdx shdP_siteCount` for Shieldstral T128 R13. -/
abbrev shdP_SiteIdx : Type := ZK60.HonestClassify.SiteIdx shdP_siteCount

/-- Bad-value cap per site at Shieldstral T128 R13 (`M = 2^17 = 131072`, `cap = 2^20`). -/
def shdP_kOf (i : shdP_SiteIdx) : ℕ :=
  ZK60.HonestClassify.kPer gP (2 ^ 17) (2 ^ 20) i.1

/-- Freshness failure cap `0` per site (transcript-program sites). -/
def shdP_δOf (_ : shdP_SiteIdx) : ℝ≥0∞ := 0

/-- Dummy non-firing site (`k = 0`, `δ = 0`) to pad unused indices in `shdP_SiteIdx`. -/
noncomputable def shdP_emptySite (Lq : ℕ) {Coins : Type} [Fintype Coins] [Nonempty Coins] :
    Site (QB Lq) Coins shdP_K where
  β := Unit
  G _ := OC.ret ((none, ⟨[], Nat.zero_le Lq⟩), ())
  bad _ := ∅
  k := 0
  hk _ := by simp
  δ := 0
  hfresh := by
    simp [prHC, OC.queries, OC.runLog]

theorem shdP_emptySite_not_fires (Lq : ℕ) {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (G : QB Lq → Dig) (c : Coins) :
    ¬ (shdP_emptySite Lq (Coins := Coins)).fires shdP_U G c := by
  simp [Site.fires, shdP_emptySite]

/-- **Parameterized `O.counts` discharge** via `HonestRun.shield_k_le_inc` + `HonestClassify.classify_counts`. -/
theorem shdP_counts_of_inc {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (count : Fin 7 → ℕ) (M cap kEmb : ℕ)
    (h0 : count 0 ≤ 2 ^ 7) (h1 : count 1 ≤ 2 ^ 20) (h2 : count 2 ≤ 2 ^ 12)
    (h3 : count 3 ≤ 2 ^ 12) (h4 : count 4 ≤ 2 ^ 12) (hkEmb : kEmb ≤ 12)
    (h5 : count 5 ≤ 2 ^ 7 + (kEmb + 1)) (h6 : count 6 ≤ 2 ^ 5) (hM : M ≤ 2 ^ 17) (hcap : cap ≤ 2 ^ 20)
    (site : (shieldS0.Tok → ℕ) → ZK60.HonestClassify.SiteIdx count → Site (QB Lq) Coins shdP_K)
    (hk : ∀ x i, (site x i).k ≤ ZK60.HonestClassify.kPer gP M cap i.1)
    (hδ : ∀ x i, (site x i).δ = 0) :
    (∀ x i, (site x i).k ≤ ZK60.HonestClassify.kPer gP M cap i.1)
      ∧ (∀ x i, (site x i).δ ≤ (fun _ => (0 : ℝ≥0∞)) i)
      ∧ ∑ i : ZK60.HonestClassify.SiteIdx count, ZK60.HonestClassify.kPer gP M cap i.1 ≤ 2 ^ 85
      ∧ ∑ _i : ZK60.HonestClassify.SiteIdx count, (0 : ℝ≥0∞) ≤ (2⁻¹ : ℝ≥0∞) ^ 41 :=
  ZK60.HonestClassify.classify_counts site (fun i => ZK60.HonestClassify.kPer gP M cap i.1) hk hδ
    (ZK60.HonestRun.shield_k_le_inc count M cap kEmb h0 h1 h2 h3 h4 hkEmb h5 h6 hM hcap)

/-- **Concrete Shieldstral T128 R13 `O.counts` discharge** at `(shdP_SiteIdx, shdP_kOf, shdP_δOf)`. -/
theorem shdP_counts {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Coins shdP_K)
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0) :
    (∀ x i, (site x i).k ≤ shdP_kOf i)
      ∧ (∀ x i, (site x i).δ ≤ shdP_δOf i)
      ∧ ∑ i : shdP_SiteIdx, shdP_kOf i ≤ 2 ^ 85
      ∧ ∑ i : shdP_SiteIdx, shdP_δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41 :=
  ZK60.HonestClassify.classify_counts site shdP_kOf hk hδ
    (ZK60.HonestRun.shield_k_le_inc shdP_siteCount (2 ^ 17) (2 ^ 20) 12
      le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl)

/-- **Concrete Shieldstral T128 R13 completeness refusal sum `≤ εcTarget = 2^-40`** (`shield_refusal_total_le_inc`). -/
theorem shdP_refusal_total_le :
    ∑ i : shdP_SiteIdx, (((shdP_kOf i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + shdP_δOf i) ≤ εcTarget :=
  ZK60.HonestRun.shield_refusal_total_le_inc shdP_siteCount (2 ^ 17) (2 ^ 20) 12
    le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl le_rfl

/-- **Non-vacuous `ClassifyOpenP` shell for Shieldstral T128 R13** (parametric in `εzk`, `embFold`, `Pk`, and
`P : RunP`): discharges `width`, `shapes`, `blocks`, `commit`, and `counts`'s global sum bounds, and reduces `refuse`
to `hcover`. -/
theorem shdP_classifyOpenP_shell {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (epBase : Coins → EpxSalt 6)
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Coins shdP_K)
    {εzk : ℕ → ℕ → ℝ≥0∞}
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
    (hzk : ZeroKnowledge (classifyModelP Rp)
      (classifyProtocolP Rp Lq
        (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
          check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      εzk) :
    ClassifyOpenP Rp Lq
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
        check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site shdP_kOf shdP_δOf εzk :=
  shield_classifyOpenP Rp hR Lq
    (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow Pk
      check0 paths digest bndCheck)
    P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn tag epBase)
    shdP_U site shdP_kOf shdP_δOf hweights hinPub houtPub rfl (shdP_cin_commit Hdr tag) hpol hparts
    (classifyP_refuse_of_cover Rp Lq _ P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site hcover)
    (shdP_counts site hk hδ) hzk

/-- Zero `EpxSalt 6` default (used only to inhabit the unused extractor base `E0b` of `sshC_productionReadyL_epP_blkEF`). -/
def shdP_zeroSalt : EpxSalt 6 where
  msgs _ _ := 0
  pads _ _ := 0
  salts _ := default
  paths _ := []

/-- Zero `RunExt shieldS0 (EpxSalt 6)` default for `E0b` (`epxE`/`epxBndE`/`epxIOE` overwrite every field read by
soundness/extraction). -/
def shdP_zeroRunExt : RunExt shieldS0 (EpxSalt 6) where
  planes _ _ := 0
  tokW _ := 0
  epW _ := 0
  xC _ := 0
  r := shdP_zeroSalt
  r' := shdP_zeroSalt

/-- **JOINED SHIELDSTRAL T128 R13 TOP THEOREM WITH `ClassifyOpenP` SHELL SPLIT (`L68b`)**:
chains `shdP_classifyOpenP_shell`, `classifyP_parts_of_segs`, and `shdP_zeroRunExt` directly into
`sshC_productionReadyL_epP_blkEF`. Splits `O : ClassifyOpenP`: discharges O1 (`O.width`), O5 (`O.shapes`),
O6 (`O.blocks`), `O.commit`, and O10's two global sum bounds (`∑ kOf ≤ 2^85`, `∑ δOf ≤ 2^-41`), and removes `E0b`,
`ι`, `kOf`, `δOf`; while O2 (`hweights`), O3 (`hinPub`), O4 (`houtPub`), O7 (`hpol`), O8 (`hsegIn`, `hsegBlk`,
`hsegOut`), O9 (`hcover`), O10 per-site (`hk`, `hδ`, fixing the 7 site families and `δ = 0`), and O12 (`hzk`, still at
`refErr RunK.kinds`, NOT `shdRunErr`) reappear as explicit premises of the same strength, preserving the exact
approved `ProductionReadyL` conclusion on `classifyModelP Rp`.
(Takes arbitrary transcript-aware `P : RunP` and per-part `SegComplete` proofs rather than L32-1's transcript-free
`incP`/`outcP`/`D12aBlockP.core`.) -/
theorem sshC_productionReadyL_epP_openShell {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (epBase : Coins → EpxSalt 6)
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Coins shdP_K)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid)
    (houtPub : Rp.out.Valid)
    (hpol : preA P.hdr = .ok () ∧ preB P.hdr = .ok ())
    (hsegIn : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.inC
      (inSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).inC))
    (hsegBlk : ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).blk k))
    (hsegOut : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.outC
      (outSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).outC))
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires shdP_U G c)
    (hzk : ZeroKnowledge (classifyModelP Rp)
      (classifyProtocolP Rp Lq
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      (ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds)) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow) 28)
        (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) paths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_blkEF
    (Hdr := Hdr) (Coins := Coins) (tag := tag) (Lq := Lq) (hL20 := hL20) (hL64 := hL64)
    (key := key) (Rp := Rp) (hR := hR) (hw := hw) (hhdrFit := hhdrFit)
    (preA := preA) (preB := preB) (check0 := check0) (paths := paths) (digest := digest) (bndCheck := bndCheck)
    (ioIn := ioIn) (ioOut := ioOut) (checkOpening := checkOpening)
    (embDigest := embDigest) (bInRow := bInRow) (wDigest := wDigest) (bOutRow := bOutRow)
    (P := P) (epBase := epBase) (site := site) (kOf := shdP_kOf) (δOf := shdP_δOf)
    (O := shdP_classifyOpenP_shell tag Lq hL20 key shdP_runDomain hw preA preB Rp hR
      embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      check0 paths digest bndCheck P epBase site hweights hinPub houtPub hpol
      (classifyP_parts_of_segs Rp Lq
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base hsegIn hsegBlk hsegOut)
      hk hδ hcover hzk)
    (E0b := fun _ _ _ => shdP_zeroRunExt)
    (hV131072 := hV131072)

/-- Corollary of `sshC_productionReadyL_epP_openShell` with `preA := fun _ => .ok ()` and `preB := fun _ => .ok ()`,
discharging `hpol` by `⟨rfl, rfl⟩`. -/
theorem sshC_productionReadyL_epP_openShell_okPre {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (epBase : Coins → EpxSalt 6)
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → Site (QB Lq) Coins shdP_K)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid)
    (houtPub : Rp.out.Valid)
    (hsegIn : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.inC
      (inSeg (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest (embFoldL Rp.inp)
        bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).inC))
    (hsegBlk : ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest (embFoldL Rp.inp)
          bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).blk k))
    (hsegOut : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.outC
      (outSeg (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest (embFoldL Rp.inp)
        bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).outC))
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest (embFoldL Rp.inp)
          bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires shdP_U G c)
    (hzk : ZeroKnowledge (classifyModelP Rp)
      (classifyProtocolP Rp Lq
        (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest (embFoldL Rp.inp)
          bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      (ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds)) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 (fun _ => .ok ()) (fun _ => .ok ()) (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow) 28)
        (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) paths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_openShell tag Lq hL20 hL64 key Rp hR hw hhdrFit
    (fun _ => .ok ()) (fun _ => .ok ()) check0 paths digest bndCheck ioIn ioOut checkOpening
    embDigest bInRow wDigest bOutRow P epBase site hV131072
    hweights hinPub houtPub ⟨rfl, rfl⟩ hsegIn hsegBlk hsegOut hk hδ hcover hzk

end OpenShell

end ZK60.ProtocolClassify
