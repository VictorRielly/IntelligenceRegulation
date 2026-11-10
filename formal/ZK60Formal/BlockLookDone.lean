/-
D63 lane L47 (2026-11-10), part 10: **the W16R2 rung block's knowledge statement with every block-level premise
gone** (deliverable 3).

`block_knowledge_look_w16r2_rung` is `block_knowledge_look_w16r2_rung_hhr` (BlockLookFinal.lean) with LogUp's helper
relations `hhr` PROVED (`hhr_w16`, BlockLookRelFinal.lean). Over lane L44's `block_knowledge_host_w16r2_rung_pubs`,
these premises are gone: `HGd`, `spH`, `hdgH`, `hformH`, `hgdH` (L44's helper layer, with `SC_TAB`'s `spT`, `hTdeg`,
`hTform` now proved), `gL`, `hgate`, `hones` (the lookup side's public tables `restW16`), `rest`, `fams`, `hF`, `hW`,
`h24`, `Alk`, `T`, `mlk`, `hN`, `he`, `hTtab`, `hcov`, `hhr`.

What it takes, by kind:
* run-level (as L31 / L41 / L44): `U`, `hU`, `hK2`, `key`, `domain`, `hs`, `hL`, `hL64`, `hL20`, `hdrLen`, `hdrSq`,
  `hh`, `hq`, `csE`, `rE`, `QE`, `XE`, `hcsE`, `q`, `A`, `hA`, `εend`, `hEnd`;
* the verifier IS the code's W16R2 rung verifier: `hP : IsRungW16`, `hdef` (its `define` is the rung's program at the
  public tables `pubsW16 B (restW16 Pb S.nG)`), `hlc`, `hep`, and four facts the profile structure does not pin
  (findings L44-K1, L47-1): the slot kinds `hk3`, `hk19`, `hk20` and the LogUp sum claim `hls`;
* public data and its validity: `Pb`, `Lay`, `B`, `hS : RungS S`, `hLay : LayW16 Lay`, `hnG : 0 < S.nG`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookFinal
import ZK60Formal.BlockLookRelFinal

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **The W16R2 rung block's knowledge statement with every block-level premise gone**: for every prover `A` making at
most `q` queries, the probability that the block verifier accepts (with the header's squeeze count `hdrSq`) while the
planes extracted from the committed matrix break the block's equations is at most the approved target `εsTarget q`
plus the endpoint term `εend`. Left: run-level premises, the verifier's identity with the code's (CHECKED), public
data and its validity. -/
theorem block_knowledge_look_w16r2_rung [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L)
    -- the verifier: the code's W16R2 rung verifier
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG)))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone) (hls : P.logupSumClaim = DefW16.logupSumW16 DefW16.cfgRungW16)
    -- run-level
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
    -- public-data validity
    (hS : RungS S) (hLay : LayW16 Lay) (hnG : 0 < S.nG) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_look_w16r2_rung_hhr U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc
    hep hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hS hLay hnG hk3 hk19 hk20
    (hhr_w16 U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut (pubsW16 Pb Lay B (restW16 Pb S.nG)) hdef hlc hls
      hdrLen csE rE QE XE Pb Lay B A)

end ZK60.Exec.Block.Join.W16.Look
