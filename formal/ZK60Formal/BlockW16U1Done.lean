/-
D63 W16R2 Shieldstral port, Item (5f) (`BlockW16U1Done.lean`):
**the W16R2 Shieldstral (`export_u1`, `W16R2_SHIELD_T128_H24`, `PROFILE_SHA = 9464388091d8095f...`)
single-block knowledge statement with EVERY block-level premise discharged**, for every one of the
26 layers `Ly ∈ shieldExportU1` (the `export_u1` Shieldstral counterpart of L47's
`BlockLookDone.block_knowledge_look_w16r2_rung` and L49's `BlockR13StmtDone.block_knowledge_r13_shield`).

What `block_knowledge_w16r2_shieldU1` discharges completely inside Lean:
* `RunShapeShieldU1`: all 26 layers of `export_u1` (`shieldExportU1`), A29 uniformity, derived
  `W16Widths`, `FamsOK` (`famsLogUpW16U1`, `nRange = 13`), `BlockShape.Valid`;
* `BlockInstW16Shield`: rate-1/2 W16R2 Shieldstral schedule `(15, 280, 8052)`, `aRows = 2504`,
  `hRows = 2606`, `426` draws, `1159` non-dummy claims, LogUp budget `54,255,600 ≤ 2^26` (`BlockAlgLk26`);
* `BlockDefineW16Shield`: `DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM)` well-formedness (`111` A sites,
  `45` H sites, `2280` / `2516` data rows) across all 26 layers;
* `BlockW16U1Host*` + `BlockW16U1Hosts`: all six hosts' named identities (`SC_TZC`, `SC_DZC`,
  `SC_QZC`, `SC_KVZC`, `SC_SZC` with 1-limb `sr`/`sg` at `wrho = 16`, `SC_FZC`);
* `BlockW16U1TabBase` + `BlockW16U1TabForm` + `BlockW16U1Help`: concrete public tables `pubsU1`,
  `SC_LZC` (`gateLU1`), `SC_TAB` (`16` tables, `9` gates, `20` pad planes, `32` draws, deg `22`),
  `SC_ZS` (`H_U = 43`), and helper layer `HGdU1` / `spHU1`;
* `BlockW16U1LookBase` + `BlockW16U1LookCov` + `BlockW16U1LookRel`: LogUp index sets (`N = 34,897,920 < gP`,
  `N + 2·|TbIx| = 35,422,208 ≤ 2^26`), `CodeTable` soundness (`hTtab_shieldU1`), full `W16Query`
  coverage (`hcov_shieldU1`), and all 44-plane `HelperRel` relations (`hhr_shieldU1`).

What remains (exactly mirroring `BlockLookDone.block_knowledge_look_w16r2_rung`):
* run-level premises (`U, hU, hK2, key, domain, hs, hL, hL64, hL20, hdrLen, hdrSq, hh, hq, csE, rE, QE, XE, hcsE, q, A, hA, εend, hEnd`);
* the verifier IS the code's W16R2 Shieldstral block verifier for layer `Ly` (`hP : Link.IsShieldW16`,
  `hdef` at `DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM)` and `pubsU1`, `hlc`, `hep`, `hk3`, `hk19`, `hk20`, `hls`);
* public block data and layout validity (`Pb`, `Lay`, `B`, `hLay : LayR Lay`; note `LayR` is
  non-vacuous via `RunShieldBlkInst.shdP_bitLay_layR Ly` on the identical axis types `CtU1..CfU1`).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1LookCov
import ZK60Formal.BlockW16U1LookRel

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H (LayR)
open ZK60.Exec.Block.DefW16
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.RunShape.ShieldU1 (shieldExportU1)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The W16R2 Shieldstral (`export_u1`) single-block knowledge statement with every block-level
premise discharged**: for every layer `Ly ∈ shieldExportU1` and every prover `A` making at most `q`
oracle queries, the probability that the block verifier accepts (with header squeeze count `hdrSq`)
while the planes extracted from the committed `A` matrix break `ZK60.Block.BlockSat Pb` is at most
`εsTarget q + εend`. -/
theorem block_knowledge_w16r2_shieldU1 [Fintype K] [DecidableEq K]
    (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1)
    (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L)
    -- the verifier: the code's W16R2 Shieldstral (`export_u1`) block verifier for layer `Ly`
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) CtU1 CwU1 CgU1 CjU1 CdU1 CfU1)
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut)
      (Tab.pubsU1 Pb Lay B (shieldShape Ly).nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hls : P.logupSumClaim = DefW16.logupSumW16 (cfgU1 Ly.cnA Ly.cnM))
    -- run-level
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data layout validity
    (hLay : LayR Lay) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend := by
  let Dof : Cuts3 L → RootsO → CmData K P :=
    fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt
  let pubs : PubTabs := Tab.pubsU1 Pb Lay B (shieldShape Ly).nG
  let dt : AlgData K L (algShapeU1 P hP.hdr) :=
    dtU1 Pb Lay B P hP.hdr (fun cu rt => xtU1 U P (Dof cu rt))
      (xcU1 U P Dof Pb Lay B) (pwcU1 U P Dof Pb Lay B)
  have hhosts := formAt_hosts_shieldU1 Ly hLy U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc
    hdrLen csE rE QE XE Pb Lay B A hLay (Tab.pubR_of_u1 U hU Pb Lay B (shieldShape Ly).nG)
  exact block_knowledge_join_w16r2_shieldU1 Ly hLy U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut pubs
    hdef hlc hep hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B hLay q A hA εend hEnd
    (xcU1 U P Dof Pb Lay B) (pwcU1 U P Dof Pb Lay B)
    hhosts
    (Help.HGdU1 U P (algShapeU1 P hP.hdr) dt Dof Pb (shieldShape Ly).nG)
    (Help.spHU1 U (card_K_gt K) P hP.hdr (algShapeU1 P hP.hdr) dt Dof Pb (shieldShape Ly).nG)
    (Help.helperU1_dg U (card_K_gt K) P hP.hdr (algShapeU1 P hP.hdr) dt Dof Pb (shieldShape Ly).nG)
    (fun G bga rs acc hT => Help.helperU1_formAt_pubs U (card_K_gt K) P hP.hdr (algShapeU1 P hP.hdr) dt Dof Pb
      (shieldShape Ly).nG hU hP.hsl Ly.cnA Ly.cnM ioIn ioOut Lay B (by show 0 < P.logCols; rw [hlc]; norm_num)
      hk3 hk19 hk20 _ _ bga rs (hhosts G bga rs acc hT))
    (fun G bga rs acc _ hG => Help.hgdU1_of U (card_K_gt K) P hP.hdr (algShapeU1 P hP.hdr) dt Dof Pb
      (shieldShape Ly).nG _ _ bga rs hG)
    (Look.AlkU1 U P Pb Lay B (Look.dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A))
    (Look.TU1 (K := K) Pb (shieldShape Ly).nG)
    (Look.mlkU1 U P (Look.dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A))
    Look.hN_u1
    (Look.he_u1 _)
    (Look.hTtab_shieldU1 Ly hLy Pb)
    (Look.hcov_shieldU1 Ly hLy U key domain hs hL tag hL20 P hlc rE QE XE Pb Lay B A)
    (Look.hhr_shieldU1 Ly U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hls hdrLen csE
      rE QE XE Pb Lay B A)

end ZK60.Exec.Block.Join.W16U1
