/-
D63 lane L47 (2026-11-10), part 3: **the W16R2 rung block's statement at the lookup side's concrete objects**
(deliverable 3, first step): lane L44's `block_knowledge_host_w16r2_rung_helper` at

* the public tables `pubsW16 B (restW16 Pb S.nG)` (`PubW16` by `pubW16_of`; `SC_LZC`'s and `SC_ZS`'s tables `hgate`,
  `hones` PROVED from `restW16`);
* the families `famsW` (`FamsOK`, `W16Widths` PROVED from `RungS`), `h24` from `RungS`;
* `SC_TAB`'s polynomial `spT := spTabW` (`hTdeg` PROVED: degree `24`);
* the lookup side `Alk := AlkW`, `T := TW`, `mlk := mlkW` over the data the `A` cut fixes (`dofA`), with `hN`, `he`,
  `hTtab` PROVED;

so that, of the block-level premises, only `SC_TAB`'s named identity (`hTform`), the cover (`hcov`) and LogUp's helper
relations (`hhr`) are left here, each in the form a later file of this lane proves.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **The W16R2 rung block's statement with the lookup side's objects concrete**: every premise of L44's
`block_knowledge_host_w16r2_rung_helper` about the public tables, the families, `SC_TAB`'s degree, `Alk`, `T`, `mlk`,
`hN`, `he`, `hTtab` discharged; left: `hTform` (`SC_TAB`'s named identity), `hcov`, `hhr`, and the slot kinds `hk3`,
`hk20` and the ACT groups `hnG` (verifier and public-data facts). -/
theorem block_knowledge_look_w16r2_rung_of [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG)))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data facts
    (hS : RungS S) (hLay : LayW16 Lay) (hnG : 0 < S.nG)
    -- verifier facts: the slot kinds of `SC_LZC` and `SC_ZS` (layout.rs `SLOT_KINDS`)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk20 : P.kind 20 = SlotKind.standalone)
    -- left: `SC_TAB`'s named identity, the cover, LogUp's helper relations
    (hTform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG))))
      (Link.csRungW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      FormAt U P (polyS U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG)))
        (fun k h => (Lk.spXW U (card_K_gt K) P hP.hdr
          (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gateLW
          (fun cu rt bga => spTabW U (card_K_gt K) P hP.hdr (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)
            Pb S.nG bga) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs 19)
    (hcov : ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, AlkW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
        (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG))))
      (Link.csRungW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      Lk.HGdW U P (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78)
        (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78
          (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
          (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
          (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gateLW
        (fun cu rt bga => spTabW U (card_K_gt K) P hP.hdr (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)
          Pb S.nG bga) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel
        (fun l => fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
            (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (TW (K := K) Pb S.nG j))
        (mlkW U P (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
          (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_host_w16r2_rung_helper U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut
    (pubsW16 Pb Lay B (restW16 Pb S.nG)) hdef hlc hep hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B famsW famsW_ok
    (w16Widths_famsW hS) hS.h24 q A hA εend hEnd hS hLay (pubW16_of Pb Lay B U hU _) gateLW
    (fun cu rt bga => spTabW U (card_K_gt K) P hP.hdr (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)
      Pb S.nG bga)
    (fun cu rt bga => by rw [spTabW_dg]; norm_num) hTform hk3 hk20
    (fun hist dr b => by
      rw [pubsW16_rest Pb S.nG Lay B 3 (Or.inl rfl)]
      exact rest3_getD U Pb S.nG hist dr b)
    (fun hist dr b => by
      rw [pubsW16_rest Pb S.nG Lay B 20 (Or.inr (Or.inr rfl))]
      exact rest20_getD U Pb S.nG hist dr b)
    (AlkW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)) (TW Pb S.nG)
    (mlkW U P (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A))
    hN_w16 (he_w16 _) (hTtab_w16 Pb hnG) hcov hhr

end ZK60.Exec.Block.Join.W16.Look
