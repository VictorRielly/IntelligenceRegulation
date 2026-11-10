/-
D63 lane L49 (2026-11-10), part 7: **the R13 block's knowledge statement with every block-level premise gone**, at the
R13 rung (`block_knowledge_r13_rung`) and at every layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block,
at the layer's own program, shape and calibration (`block_knowledge_r13_shield`). The R13 counterpart of lane L47's
`block_knowledge_look_w16r2_rung`.

Over `BlockR13StmtHosts.lean`'s statements, LogUp's helper relations `hhr` are PROVED (sub-agent `look`, round 2:
`hhrR_rung`, `hhrR_shield`), the batch's entries `xcR` tied to the hosts' by definition. Over lane L35/L36's
`block_knowledge_define_alg_r13_lk` and `block_knowledge_define_alg_r13_shield_lk26`, these premises are gone: `prog`,
`hprog`, `hsA`, `hsH`, `pubs`, `h24`, `hW13`, `xtE`, `sh`, `dt`, `hform`, `enc`, `encHt`, `hspec`, `hTok`, `hHd`, `HGd`,
`spH`, `hdgH`, `hformH`, `hgdH`, `Alk`, `T`, `mlk`, `hN`, `he`, `hTtab`, `hcov`, `hhr`.

What it takes, by kind:
* run-level (as L31 / L35 / L36): `U`, `hU`, `hK2`, `key`, `domain`, `hs`, `hL`, `hL64`, `hL20`, `hdrLen`, `hdrSq`,
  `hh`, `hq`, `csE`, `rE`, `QE`, `XE`, `hcsE`, `q`, `A`, `hA`, `εend`, `hEnd`;
* the verifier IS the code's R13 verifier: `hP : IsRungR13` / `IsShieldR13`, `hdef` (its `define` is R13's program at
  the public tables `pubsR13L`, CHECKED by value at the rung), `hlc`, `hep`, and four facts the profile structure does
  not pin: the slot kinds `hk3`, `hk19`, `hk20` and the LogUp sum claim `hls` (findings L44-K1, L47-1, L49-LOOK-1);
* public data and its validity: `Pb`, `Lay`, `B`, `hLay : LayR Lay`; at the rung also `hS : RungS S` and `hnG`; at
  Shieldstral the shape is the layer's own (`shieldShape Ly`) and nothing else is assumed of it.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13StmtHosts
import ZK60Formal.BlockR13LookRelFinal

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The R13 rung block's knowledge statement with every block-level premise gone**: for every prover `A` making at
most `q` queries, the probability that the block verifier accepts (with the header's squeeze count `hdrSq`) while the
planes extracted from the committed matrix break the block's equations is at most the approved target `εsTarget q`
plus the endpoint term `εend`. Left: run-level premises, the verifier's identity with the code's (`hk3`, `hk19`,
`hk20`, `hls`: CHECKED), public data and its validity (`hS`, `hLay`, `hnG`). -/
theorem block_knowledge_r13_rung {S : ZK60.Block.BlockShape} [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L)
    -- the verifier: the code's R13 rung verifier
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
      (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone) (hls : P.logupSumClaim = Look.logupSumR13 DefR13.cfgRungR13)
    -- run-level
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
    -- public-data validity
    (hS : W16.RungS S) (hLay : LayR Lay) (hnG : 0 < S.nG) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X (Lay.dPos p))
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_hosts_r13_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc hep
    hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hS hLay hnG
    (LookRel.hhrR_rung U hU key domain hs hL hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc hls hdrLen csE rE QE
      XE (xcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B)
      (pwcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B)
      (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl)
      (fun _ _ _ _ _ _ => rfl) A)

/-- **One layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block: the knowledge statement with every
block-level premise gone**, at the layer's own program, shape and calibration (lane L40). Left: run-level premises,
the verifier's identity with the code's (`hk3`, `hk19`, `hk20`, `hls`), the layout facts `hLay`. -/
theorem block_knowledge_r13_shield [Fintype K] [DecidableEq K] (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.Shield.shieldExport) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L)
    -- the verifier: the code's Shieldstral T128 R13 verifier at this layer
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
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
    (hls : P.logupSumClaim = Look.logupSumR13 (DefR13.cfgShieldR13 Ly))
    -- run-level
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
    -- public-data validity
    (hLay : LayR Lay) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X (Lay.dPos p))
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE
            XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).toW16 (ZK60.RunShape.Shield.shieldShape Ly))))
      ≤ εsTarget q + εend :=
  block_knowledge_hosts_r13_shield Ly hLy U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef
    hlc hep hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hLay
    (LookRel.hhrR_shield Ly U hU key domain hs hL hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc hls hdrLen csE rE
      QE XE (xcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B)
      (pwcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B)
      (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ => rfl)
      (fun _ _ _ _ _ _ => rfl) A)

end ZK60.Exec.Block.Join.R13H
