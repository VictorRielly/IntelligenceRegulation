/-
D63 lane L49, sub-agent `help`: a probe (not a library module) that the helper layer's premises fit the lane's
`block_knowledge_join_r13_rung` (BlockR13StmtJoin.lean): `HGd := HGdR …`, `spH := spHR …`, `hdgH`, `hformH`, `hgdH`
discharged, `hformH` from the statement's own `hform`. The lane's assembly can copy the argument list.
-/
import ZK60Formal.BlockR13LookHelpR13
import ZK60Formal.BlockR13StmtJoin

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.HelpProbe

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.R13H.Help
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

theorem block_knowledge_help_r13_rung_probe {S : ZK60.Block.BlockShape} [Fintype K] [DecidableEq K] (U : K)
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
    -- the helper layer's verifier and public-data premises
    (gL : (Fin 14 → Bool) → GF)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (hrest19 : ∀ hist dr i, pubs 19 hist dr i = R13T.restR13 Pb.exp Pb.act S.nG 19 hist dr i)
    (hrest20 : ∀ hist dr, pubs 20 hist dr 0 = R13T.restR13 Pb.exp Pb.act S.nG 20 hist dr 0)
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
      HGdR U DefR13.cfgRungR13 P (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
        (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
          (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
          perRow_rung xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) gL Pb.exp Pb.act S.nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
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
  block_knowledge_join_r13_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hep
    hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B hW13 h24 q A hA εend hEnd hLay xc pwc hform
    (HGdR U DefR13.cfgRungR13 P (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
      (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
        (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
        perRow_rung xc pwc)
      (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) gL Pb.exp Pb.act S.nG)
    (spHR U (card_K_gt K) DefR13.cfgRungR13 P (helpProf_rung P hP.hdr hP.hsl)
      (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
      (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
        (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
        perRow_rung xc pwc)
      (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) gL Pb.exp Pb.act S.nG)
    (helperR_dg_r13 U (card_K_gt K) DefR13.cfgRungR13 P (helpProf_rung P hP.hdr hP.hsl) (shOk_rung P hP.hdr) _ _ gL
      Pb.exp Pb.act S.nG)
    (fun G bga rs acc hT => helperR_formAt_r13 U (card_K_gt K) DefR13.cfgRungR13 P (helpProf_rung P hP.hdr hP.hsl)
      (shOk_rung P hP.hdr) _ (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) gL Pb.exp Pb.act
      S.nG hU helpCfg_rung ioIn ioOut pubs (by show 0 < P.logCols; rw [hlc]; norm_num) hk3 hk19 hk20 hgate hrest19
      hrest20 _ _ bga rs (hform G bga rs acc hT))
    (fun G bga rs acc _ hG => hgdR_of_r13 U (card_K_gt K) DefR13.cfgRungR13 P (helpProf_rung P hP.hdr hP.hsl)
      (shOk_rung P hP.hdr) _ _ gL Pb.exp Pb.act S.nG _ _ bga rs hG)
    Alk T mlk hN he hTtab hcov hhr

end ZK60.Exec.Block.Join.R13H.HelpProbe
