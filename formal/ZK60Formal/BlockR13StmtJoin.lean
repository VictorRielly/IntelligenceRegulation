/-
D63 lane L49 (2026-11-10), part 3: **the R13 block statements with the extraction, the algebra data, the encodings and
`R13Spec` discharged, at R13's own slot program** (the R13 counterpart of lane L41's `block_knowledge_join_w16r2_rung`),
at the R13 rung and at every layer `L ∈ shieldExport` of the app's Shieldstral T128 R13 block (at the layer's own
shape `shieldShape L`, lane L40).

* **`block_knowledge_join_r13_rung`**: L35's `block_knowledge_define_alg_r13_lk` at `prog := progR13 cfgRungR13`
  (`hprog`, `hsA`, `hsH` PROVED), with `xtE := xtR` (the extracted planes, DEFINED from the committed `A` matrix),
  `sh := algShapeR` (the rung's draw schedule, `shOk_rung`), `dt := dtR`, `enc := encR`, `encHt := encHtR`, `hspec`
  PROVED (`hspecR`), `hTok`, `hHd` from `LayR`;
* **`block_knowledge_join_r13_shield`**: L35's `block_knowledge_define_alg_r13_shield_lk26` (finding L36-1: the bound
  `2^26`) the same way, at every layer of the export, at the layer's own shape: `R13Windows` PROVED for it.

Left by name: the hosts' named identities `hform` (with the batch's other entries `xc` and the pad planes `pwc`, for
the host lanes), the helper layer (`HGd`, `spH`, `hdgH`, `hformH`, `hgdH`) and the lookup side (`Alk`, `T`, `mlk`,
`hN`, `he`, `hTtab`, `hcov`, `hhr`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13StmtBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The R13 rung block's knowledge statement at its own program, with the extraction, the algebra data, the
encodings and `R13Spec` discharged.** -/
theorem block_knowledge_join_r13_rung {S : ZK60.Block.BlockShape} [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (hW13 : ZK60.Layout.R13.R13Windows S 2) (h24 : S.h24 = true)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    (hLay : LayR Lay)
    -- the batch's entries past the named clauses and the pad planes; the hosts' named identities
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
          (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
            (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
            perRow_rung xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, R13Query Pb Lay B (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X (Lay.dPos p))
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_define_alg_r13_lk U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP
    (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs hdef
    (progR13_rung_okP P hP.hsl (by rw [hlc]; norm_num) hep ioIn ioOut)
    (progR13_rung_sums ioIn ioOut).1 (progR13_rung_sums ioIn ioOut).2 hlc hdrLen hdrSq hh hq csE rE QE XE hcsE
    Pb Lay B hW13 h24
    (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
    q A hA εend hEnd
    (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
    (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
      (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
      perRow_rung xc pwc)
    hform (encR geoRung) (encHtR geoRung)
    (hspecR geoRung Pb Lay B P (shOk_rung P hP.hdr)
      (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
      perRow_rung xc pwc)
    hLay.tok hLay.hd HGd spH hdgH hformH hgdH Alk T mlk hN he hTtab hcov hhr

/-- **One layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block: the knowledge statement at the layer's
own program and own shape** (`shieldShape Ly`, the layer's calibration), with the extraction, the algebra data, the
encodings and `R13Spec` discharged; `R13Windows` PROVED for the layer's shape. -/
theorem block_knowledge_join_r13_shield [Fintype K] [DecidableEq K] (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.Shield.shieldExport) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly))
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    (hLay : LayR Lay)
    -- the batch's entries past the named clauses and the pad planes; the hosts' named identities
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
        (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
          (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
            (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
            (perRow_shield Ly) xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
        (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act
      (ZK60.RunShape.Shield.shieldShape Ly).nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, R13Query Pb Lay B (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE
        QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X (Lay.dPos p))
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE
            XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).toW16 (ZK60.RunShape.Shield.shieldShape Ly))))
      ≤ εsTarget q + εend :=
  block_knowledge_define_alg_r13_shield_lk26 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP
    (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs hdef
    (progR13_shield_okP Ly hLy P hP.hsl (by rw [hlc]; norm_num) hep ioIn ioOut)
    (progR13_shield_sums ioIn ioOut Ly hLy).1 (progR13_shield_sums ioIn ioOut Ly hLy).2 hlc hdrLen hdrSq hh hq csE rE
    QE XE hcsE Pb Lay B (shieldWindows Ly hLy) rfl
    (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
    q A hA εend hEnd
    (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
    (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
      (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
      (perRow_shield Ly) xc pwc)
    hform (encR (geoShield Ly)) (encHtR (geoShield Ly))
    (hspecR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
      (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
      (perRow_shield Ly) xc pwc)
    hLay.tok hLay.hd HGd spH hdgH hformH hgdH Alk T mlk hN he hTtab hcov hhr

end ZK60.Exec.Block.Join.R13H
