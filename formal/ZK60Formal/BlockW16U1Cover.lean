/-
Covering module for two facts of the independent read of the installed-profile single-block step
(`results/zk60_claude_review_20261116/W16U1_READ_20261126.md`, points M2 and M3; co-coordinator,
2026-11-26). It adds nothing to `BlockW16U1Done.lean` and changes no file of that family.

1. `cov_layR_c0`: `LayR` at the U1 configuration `c0` for the bit-cube layout `shdP_bitLay Ly`.
   The header of `BlockW16U1Done.lean` cites `RunShieldBlkInst.shdP_bitLay_layR` for the premise
   `hLay` of `block_knowledge_w16r2_shieldU1`. That lemma is stated at `cfgShieldR13 Ly` and does not
   type-check at `c0`. Its four field proofs carry over; the fifth field (`flip`) is by `rfl`.

2. `covParamsW16`, `cov_isShieldW16`, `cov_block_knowledge_w16r2_shieldU1`: a `BlockParams` record
   that satisfies `Link.IsShieldW16` and every other verifier-identity premise of
   `block_knowledge_w16r2_shieldU1` (`hdef`, `hlc`, `hep`, `hk3`, `hk19`, `hk20`, `hls`), with that
   theorem applied to it and to `cov_layR_c0`. So the premises of the single-block statement are
   jointly satisfiable for every layer of `export_u1`, and the structure `Link.IsShieldW16` has an
   instance in the tree: the statement is not vacuous.

What this file is NOT. The record is a satisfiability witness, modelled field by field on
`RunShieldBlkInst.shdP_blkParams` (the R13 record). The fields that neither `Link.IsShieldW16` nor
the theorem's premises fix (`aPath`, `hPath`, `maskPath`, `endpointLogN`, the mask row count in
`geom`, the row count of the endpoint commitments in `covRowsW16`, `preChecks`) are placeholders:
none is claimed here to be the value the Rust verifier uses for `W16R2_SHIELD_T128_H24`. Fixing the
code's own record, and everything else at the run level, is item (6) of the port list; this file
does not start it. The run-level premises of the theorem (`hcsE`, `hEnd` and the rest) stay premises.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`).
-/
import ZK60Formal.BlockW16U1Done
import ZK60Formal.RunShieldBlkInst

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Cover

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
open ZK60.ProtocolClassify (shdP_bitLay shdP_w16Pub shdP_slotKind shdP_bitLay_layR)
open scoped ENNReal

/-- `LayR` at the U1 configuration `c0` for the bit-cube layout: the four field proofs of
`shdP_bitLay_layR` (stated at `cfgShieldR13 Ly`), and `flip` by `rfl`. -/
theorem cov_layR_c0 (Ly : ShieldLayer) :
    LayR (S := shieldShape Ly) (c := c0) (shdP_bitLay Ly) :=
  { tok := (shdP_bitLay_layR Ly).tok, hd := (shdP_bitLay_layR Ly).hd, slot := (shdP_bitLay_layR Ly).slot,
    grp := (shdP_bitLay_layR Ly).grp, flip := fun _ _ => rfl }

/-- Row counts of the witness record: `A` 2,504 and `H` 2,606 (fixed by `Link.IsShieldW16`); the
endpoint commitments' 38 is a placeholder taken from `shdP_rowsOf`. -/
def covRowsW16 : Cm → ℕ
  | .a => 2504
  | .h => 2606
  | _ => 38

/-- A `BlockParams` record satisfying every verifier-identity premise of
`block_knowledge_w16r2_shieldU1` for layer `Ly` (a satisfiability witness; see the file header for
which fields are placeholders). -/
def covParamsW16 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : ZK60.Block.BlockPublic (shieldShape Ly)) : BlockParams where
  geom := ZK60.Exec.Block.R13.geom ZK60.Exec.Block.W16R2.shieldSlots ZK60.Exec.Block.W16R2.shieldTerms 50 36 2504 9 2606
  logCols := 14
  endpointLogN := 14
  aRows := 2504
  hRows := 2606
  aPath := 15
  hPath := 15
  maskPath := 12
  preChecks := .ok ()
  kind := shdP_slotKind
  name s := toString s
  draws := ZK60.Exec.Block.W16R2.shieldDraws
  define := defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut)
    (Tab.pubsU1 Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG)
  nFunctionals := 34
  logupSumClaim := DefW16.logupSumW16 (cfgU1 Ly.cnA Ly.cnM)
  maskVerify := maskField tag 23
  checkOpening := checkOpening
  pcsVerify := pcsField tag covRowsW16

/-- The witness record is a W16R2 Shieldstral (`export_u1`) block verifier in the sense of
`Link.IsShieldW16`: all ten fields by `rfl`. -/
theorem cov_isShieldW16 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : ZK60.Block.BlockPublic (shieldShape Ly)) :
    Link.IsShieldW16 (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) tag covRowsW16 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- `block_knowledge_w16r2_shieldU1` at the witness record, the bit-cube layout and its public data:
the verifier-identity premises (`hP`, `hdef`, `hlc`, `hep`, `hk3`, `hk19`, `hk20`, `hls`) and the
layout premise (`hLay`) are discharged here; the run-level premises stay. The conclusion is that
theorem's, word for word, at `P := covParamsW16 tag ioIn ioOut checkOpening Ly Pb` and
`Lay := shdP_bitLay Ly`. -/
theorem cov_block_knowledge_w16r2_shieldU1 [Fintype K] [DecidableEq K]
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L)
    -- run-level
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) →
      Fin (2 ^ rowLog (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) cm) (QE cm)
        (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc,
      BlockAcc key domain (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend) :
    prH (fun G : QB L → Dig => ∃ bga rs acc,
        BlockAcc key domain (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtU1 U (covParamsW16 tag ioIn ioOut checkOpening Ly Pb)
            (dXof tag hL20 (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) rfl 15 280 8052 2504 2606 rE QE XE
              (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))).X ((shdP_bitLay Ly).dPos p))
          (fun p => (xtU1 U (covParamsW16 tag ioIn ioOut checkOpening Ly Pb)
            (dXof tag hL20 (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) rfl 15 280 8052 2504 2606 rE QE XE
              (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))).X2 ((shdP_bitLay Ly).dPos p))
          (toWit (shdP_bitLay Ly) (xtU1 U (covParamsW16 tag ioIn ioOut checkOpening Ly Pb)
            (dXof tag hL20 (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) rfl 15 280 8052 2504 2606 rE QE XE
              (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_w16r2_shieldU1 Ly hLy U hU hK2 key domain hs hL hL64 hL20
    (covParamsW16 tag ioIn ioOut checkOpening Ly Pb) tag covRowsW16 (cov_isShieldW16 tag ioIn ioOut checkOpening Ly Pb)
    Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) ioIn ioOut rfl rfl (by show 0 < 14; norm_num)
    (by show shdP_slotKind 3 = _; decide) (by show shdP_slotKind 19 = _; decide)
    (by show shdP_slotKind 20 = _; decide) rfl hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd
    (cov_layR_c0 Ly)

end ZK60.Exec.Block.Join.W16U1.Cover
