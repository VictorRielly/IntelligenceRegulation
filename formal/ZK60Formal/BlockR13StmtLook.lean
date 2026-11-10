/-
D63 lane L49 (2026-11-10), part 5: **the R13 block statements with the lookup side's objects concrete** (the R13
counterpart of lane L47's `block_knowledge_look_w16r2_rung_of`), at the R13 rung and at every layer `Ly ∈
shieldExport` of the app's Shieldstral T128 R13 block (at the layer's own shape `shieldShape Ly`).

Over `BlockR13StmtHelp.lean`'s statements, from sub-agent `look` (`BlockR13Look*.lean`):
* `Alk := AlkR13` (the code's byte lookups, top-bit pins, exp and ACT tuples, read off the data the `A` cut fixes,
  `dofAR`, finding L47-2), `T := TR13` (the bytes, exp and ACT columns), `mlk := mlkR13`;
* `hN`, `he` PROVED (`hN_rung`, `he_rung`: 2,064,384 lookups, at most 2,162,688 ≤ 35,153,256; `hN_shield`, `he_shield`:
  66,879,488 lookups, at most 66,977,792 ≤ 2^26, finding L47-4's estimate PROVED);
* `hTtab` PROVED (`hTtab_r13` given `0 < S.nG` at the rung; `hTtab_shield` with no premise: every layer has 3 or 4
  ACT groups);
* `hcov` PROVED (`hcov_rung`, `hcov_shield`: every logical query of the extracted planes is an entry of `AlkR13`);
* at the rung, `R13Windows S 2` and `S.h24` from the rung's precision `RungS` (`windows_rung`).

Left: the hosts' named identities `hform` (with `xc`, `pwc`), the slot kinds `hk3`, `hk19`, `hk20`, and LogUp's
helper relations `hhr`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13StmtHelp
import ZK60Formal.BlockR13LookCov

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Help
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

/-- **At the R13 rung's precision, the shifts sit in R13's limb windows with three softmax limbs** (`RungS`: the rung's
precision is the W16R2 rung's, `wrho = 17`). -/
theorem windows_rung {S : ZK60.Block.BlockShape} (hS : W16.RungS S) : ZK60.Layout.R13.R13Windows S 2 := by
  obtain ⟨-, -, -, -, hq, hk, hv, hss, hpv, hao, hg, hup, hpr, hdn, hfp, hw, -⟩ := hS
  exact ⟨by omega, by omega, by omega, by omega, by omega, by omega, by omega, by omega, by omega, by omega,
    by omega, by omega, hpr⟩

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The R13 rung block's knowledge statement with the lookup side's objects concrete**: left of the block-level
premises, the hosts' named identities and LogUp's helper relations. -/
theorem block_knowledge_look_r13_rung {S : ZK60.Block.BlockShape} [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
      (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data validity: the rung's precision, the layout, an ACT group
    (hS : W16.RungS S) (hLay : LayR Lay) (hnG : 0 < S.nG)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
        (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
          (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
            (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
            perRow_rung xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
        (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGdR U DefR13.cfgRungR13 P (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
        (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
          (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
          perRow_rung xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) (Pub.gateLS DefR13.cfgRungR13.sh)
        Pb.exp Pb.act S.nG (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel
        (fun l => fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U DefR13.cfgRungR13 P Pb Lay B geoRung (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (TR13 (K := K) Pb.exp Pb.act S.nG j))
        (mlkR13 U DefR13.cfgRungR13 P (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X (Lay.dPos p))
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_help_r13_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc hep
    hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE (windows_rung hS) hS.h24 q A hA εend hEnd hLay xc pwc hform
    (AlkR13 U DefR13.cfgRungR13 P Pb Lay B geoRung (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
      (absOfC (chainEncB key domain hs L hL)) A))
    (TR13 Pb.exp Pb.act S.nG)
    (mlkR13 U DefR13.cfgRungR13 P (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
      (absOfC (chainEncB key domain hs L hL)) A))
    hN_rung (he_rung _) (hTtab_r13 Pb hnG)
    (hcov_rung U key domain hs hL tag hL20 P hlc rE QE XE Pb Lay B hS A) hhr

/-- **One layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block with the lookup side's objects concrete**:
left of the block-level premises, the hosts' named identities and LogUp's helper relations. -/
theorem block_knowledge_look_r13_shield [Fintype K] [DecidableEq K] (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.Shield.shieldExport) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly))
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
      (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    (hLay : LayR Lay)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
        (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG)))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P ((polyXof U tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
        (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
          (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG))
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
          (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
            (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
            (perRow_shield Ly) xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
        (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG)))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGdR U (DefR13.cfgShieldR13 Ly) P (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
        (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
          (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
          (perRow_shield Ly) xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt)
        (Pub.gateLS (DefR13.cfgShieldR13 Ly).sh) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel
        (fun l => fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U (DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly) (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE
            QE XE (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U)
          (TR13 (K := K) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG j))
        (mlkR13 U (DefR13.cfgShieldR13 Ly) P (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X (Lay.dPos p))
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE
            XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).toW16 (ZK60.RunShape.Shield.shieldShape Ly))))
      ≤ εsTarget q + εend :=
  block_knowledge_help_r13_shield Ly hLy U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef
    hlc hep hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hLay xc pwc hform
    (AlkR13 U (DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly) (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
      (absOfC (chainEncB key domain hs L hL)) A))
    (TR13 Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG)
    (mlkR13 U (DefR13.cfgShieldR13 Ly) P (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
      (absOfC (chainEncB key domain hs L hL)) A))
    (hN_shield Ly) (he_shield Ly _) (hTtab_shield Ly hLy Pb)
    (hcov_shield Ly U key domain hs hL tag hL20 P hlc rE QE XE Pb Lay B A) hhr

end ZK60.Exec.Block.Join.R13H
