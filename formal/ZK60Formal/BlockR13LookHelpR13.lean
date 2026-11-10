/-
D63 lane L49 (2026-11-10), sub-agent `help`, part 3: **the helper layer at the lane's algebra shape**
`sh := algShapeR c P hc` (the lane's foundation `BlockR13HostBase.lean`), for any algebra data `dt`.

* `helpProf_of`: the verifier's `HelpProf` from the foundation's profile `ProfR c.sh P` and `HelpCfg c`;
* **`hgdR_of_r13`** (`hgdH`), **`helperR_dg_r13`** (`hdgH`), **`helperR_formAt_r13`** (`hformH`): `BlockR13LookHelp`'s
  theorems at `sh := algShapeR c P hc`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookHelp
import ZK60Formal.BlockR13HostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Help

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)

/-- **The helper slots' verifier facts from the profile**: `ProfR c.sh P` and the configuration's `HelpCfg c` give
`HelpProf P`. -/
theorem helpProf_of (c : W16Cfg) (P : BlockParams) (hpf : ProfR c.sh P) (hcfg : HelpCfg c) : HelpProf P :=
  ⟨(hpf.draws 3 (by norm_num)).trans hcfg.dl3, (hpf.draws 19 (by norm_num)).trans hcfg.dl19,
    (hpf.draws 20 (by norm_num)).trans hcfg.dl20, (hpf.slots 3 (by norm_num)).trans hcfg.sc3,
    (hpf.slots 19 (by norm_num)).trans hcfg.sc19, (hpf.slots 20 (by norm_num)).trans hcfg.sc20⟩

section Shape

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}
variable (U : K) (hcard : 78 < Fintype.card K) (c : W16Cfg) (P : BlockParams) (hpr : HelpProf P)
  (hc : ShOkR c.sh P) (dt : AlgData K L (algShapeR c P hc)) (Dof : Cuts3 L → RootsO → CmData K P)
  (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)

/-- `hgdH` at `sh := algShapeR c P hc`. -/
theorem hgdR_of_r13 (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hG : SchedGd (w16r2DH P (spHR U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG) 0) cu rt bga rs) :
    HGdR U c P (algShapeR c P hc) dt Dof gL exp act nG cu rt bga :=
  hgdR_of U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG cu rt bga rs hG

/-- `hdgH` at `sh := algShapeR c P hc`. -/
theorem helperR_dg_r13 : ∀ cu rt k h, k ∈ w16r2RelKs 0 →
    (spHR U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG cu rt k h).dg ≤ 80 :=
  helperR_dg U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG

/-- `hformH` at `sh := algShapeR c P hc`. -/
theorem helperR_formAt_r13 (hU : U ^ 2 = algebraMap GF K 7) (hcfg : HelpCfg c) (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hrl : 0 < rowLog P .a)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (hrest19 : ∀ hist dr i, pubs 19 hist dr i = R13T.restR13 exp act nG 19 hist dr i)
    (hrest20 : ∀ hist dr, pubs 20 hist dr 0 = R13T.restR13 exp act nG 20 hist dr 0)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P (polyS U P (Dof cu rt) (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs k) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P (polyS U P (Dof cu rt) (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (spHR U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG cu rt k h).Φ) bga rs k :=
  helperR_formAt U hcard c P hpr (algShapeR c P hc) dt Dof gL exp act nG hU hcfg ioIn ioOut pubs hrl hk3 hk19 hk20
    hgate hrest19 hrest20 cu rt bga rs hhost

end Shape

end ZK60.Exec.Block.Join.R13H.Help
