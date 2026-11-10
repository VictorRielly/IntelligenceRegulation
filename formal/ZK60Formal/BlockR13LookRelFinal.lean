/-
D63 lane L49 (2026-11-10), sub-agent `look`, round 2, part 5: **lane L36's `hhr` at R13, PROVED** (the `hhr` premise
of `block_knowledge_help_r13_rung` / `_shield`), by lane L47's `BlockLookRelFinal.lean`.

* **`relsR_of`**: the helper relations domain by domain (`RelsR`) from the hosts' vanishing LogUp entries
  (`Dzc.xcDzcR`, `Qkv.xcZc`, `Szc.xcSzcR`, `Fzc.xcFzcR`), `SC_LZC`'s and `SC_TAB`'s relations, at canonical `α`, `β`;
* **`hhrR_gen`**: on every accepting outcome whose helper-layer start claims hold (`Help.HGdR`, at `dtR … xc pwc`
  for ANY batch entries `xc` that agree with the hosts' past their named clauses: `hxD`, `hxQ`, `hxK`, `hxS`, `hxF`),
  the committed `H` planes are helpers satisfying every relation and the sum of `HelperRel` for `AlkR13`, `TR13`,
  `mlkR13`, given the verifier fact `hls : P.logupSumClaim = logupSumR13 c` (finding L49-LOOK-1);
* **`hhrR_rung`**, **`hhrR_shield`**: the same in the exact form of the statements' `hhr`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookRelCore
import ZK60Formal.BlockR13LookRelSzc
import ZK60Formal.BlockR13StmtHelp

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.LookRel

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.Join.W16 (aPl piB hPl)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Dom segLn)
open ZK60.Layout
open ZK60.Circuit (gP GF)

/-! ## The relations from the hosts -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The helper relations at R13, domain by domain, from the hosts' vanishing LogUp entries.** -/
theorem relsR_of {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (hc : LookCfg c ls) (hr : RelCfg c ls) (P : BlockParams)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2)
    (hα : bga.2.2.Canon) (hβ : bga.1.Canon)
    (hLz : ∀ b, Help.cLzcR U c P D gL bga b = 0)
    (hDz : ∀ j, j < 17 → ∀ b, Dzc.xcDzcR U G P D Pb Lay B bga (13 + j) b = 0)
    (hQ : ∀ j, j < 7 → ∀ b, Qkv.xcZc U c P D .Q 47 2 bga (4 + j) b = 0)
    (hK : ∀ j, j < 7 → ∀ b, Qkv.xcZc U c P D .Kv 61 3 bga (4 + j) b = 0)
    (hS : ∀ j, j < 8 + ls → ∀ b, Szc.xcSzcR U G P D B bga (5 + j) b = 0)
    (hF : ∀ κ, 3 ≤ κ → κ < 11 → ∀ b, Fzc.xcFzcR U G P D B bga κ b = 0)
    (hT : ∀ k b, R13T.cTabR U c P D exp act nG bga k b = 0) :
    RelsR U G P D Pb Lay B exp act nG bga where
  pr d j hj b := by
    cases d
    · exact pr_L U P D hc gL bga hα hLz j hj b
    · exact relD_pairR U G P D Pb Lay B hc hr bga hα b j hj (hDz j hj b)
    · exact relQ_pairR U P D hc hr bga hα b j hj (hQ j hj b)
    · exact relK_pairR U P D hc hr bga hα b j hj (hK j hj b)
    · exact relS_pairR U G P D B hc hr bga hα b j hj (hS j (by change j < 6 + ls at hj; omega) b)
    · exact relF_pairR U G P D B hc hr bga hα b j hj (hF (4 + j) (by omega) (by change j < 7 at hj; omega) b)
  sg s b := by
    cases s
    · exact relS_singleR U G P D B hc hr bga hα b (hS (6 + ls) (by omega) b)
    · have h := hS (7 + ls) (by omega) b
      rw [show 5 + (7 + ls) = 12 + ls by omega] at h
      exact relExpR U G P D B hc bga hα hX hβ b h
    · exact relActR U hU G P D B hc bga hα hβ b (hF 3 le_rfl (by norm_num) b)
  tb k b := relTabR U c P D bga exp act nG k b (hT k b)

end Rels

/-! ## Lane L36's `hhr` at R13 -/

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Lane L36's `hhr` at R13, generic in the configuration**: from `AccT` and the helper layer's start claims
`Help.HGdR` at `dtR … xc pwc`, for batch entries `xc` that are the hosts' past their named clauses. -/
theorem hhrR_gen (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (hsl : 0 < P.geom.slots.length) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (hc : LookCfg c ls) (hr : RelCfg c ls) (hcS : ShOkR c.sh P) (hpr : 0 < c.sh.perRow ∧ c.sh.perRow < gP)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = logupSumR13 c) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K) (rE QE : Cm → ℕ) (rA rH : ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (gL : (Fin 14 → Bool) → GF)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen c k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen c k) → Bool) → K)
    (hxD : ∀ cu rt bga κ b, 13 ≤ κ → xc 14 cu rt bga κ b
      = Dzc.xcDzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) Pb Lay B bga κ b)
    (hxQ : ∀ cu rt bga κ b, 4 ≤ κ → xc 15 cu rt bga κ b
      = Qkv.xcZc U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) .Q 47 2 bga κ b)
    (hxK : ∀ cu rt bga κ b, 4 ≤ κ → xc 16 cu rt bga κ b
      = Qkv.xcZc U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) .Kv 61 3 bga κ b)
    (hxS : ∀ cu rt bga κ b, 5 ≤ κ → xc 17 cu rt bga κ b
      = Szc.xcSzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) B bga κ b)
    (hxF : ∀ cu rt bga κ b, 3 ≤ κ → xc 18 cu rt bga κ b
      = Fzc.xcFzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) B bga κ b)
    (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G' bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 rA rH rE QE XE (DefR13.progR13 c ioIn ioOut) pubs))
      (Link.csXof U tag L (Link.le64_of_le20 hL20) 16 256 24448 rA rH csE) (Link.msRung U tag hL20) A G' bga rs acc →
      Help.HGdR U c P (algShapeR c P hcS)
        (dtR G Pb Lay B P hcS
          (fun cu rt => xtR U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) ls) hpr xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) gL Pb.exp Pb.act S.nG
        (cutsOf key domain hs hL A G') (rootsOf (A.run G').2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U c P Pb Lay B G (dofAR tag hL20 P hlc 16 256 24448 rA rH rE QE XE
            (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G').1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TR13 Pb.exp Pb.act S.nG j))
        (mlkR13 U c P (dofAR tag hL20 P hlc 16 256 24448 rA rH rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
          (cutsOf key domain hs hL A G').1) (bga.2.2.toK U) Hh := by
  intro G' bga rs acc hT hG
  obtain ⟨hα, hβ⟩ := bga_canon_R U key domain hs hL P hsl _ pubs hdef hdrLen _ _ _ A G' bga rs acc hT
  obtain ⟨hHost, ⟨hLz, -⟩, ⟨hTab, -⟩, hzs⟩ := hG
  have hx : ∀ k, k ∈ algHosts → ∀ κ (hκ : κ < segLn (ZK60.Exec.Slot.R13.draws c.sh k) .mu
      - segLn (ZK60.Exec.Slot.R13.draws c.sh k) .zeta), r13Count k ≤ κ →
      ∀ b : Fin (tauLen c k) → Bool, xc k (cutsOf key domain hs hL A G') (rootsOf (A.run G').2) bga κ b = 0 := by
    intro k hk κ hκ hrk b
    have e := (hHost k hk).1 ⟨κ, hκ⟩ b
    have e2 : (dtR G Pb Lay B P hcS
        (fun cu rt => xtR U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt) ls) hpr xc pwc).cl k
          (cutsOf key domain hs hL A G') (rootsOf (A.run G').2) bga ⟨κ, hκ⟩ b
        = xc k (cutsOf key domain hs hL A G') (rootsOf (A.run G').2) bga κ b := by
      show (if κ < r13Count k then _ else _) = _
      rw [ite_eq_right (by omega)]
    rw [e2] at e
    exact e
  have hD : ∀ j, j < 17 → ∀ b, Dzc.xcDzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) Pb Lay B bga (13 + j) b = 0 := by
    intro j hj b
    rw [← hxD _ _ _ _ _ (by omega)]
    exact hx 14 (by decide) (13 + j) (by have := hr.bD; omega) (by show 13 ≤ 13 + j; omega) b
  have hQ : ∀ j, j < 7 → ∀ b, Qkv.xcZc U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) .Q 47 2 bga (4 + j) b = 0 := by
    intro j hj b
    exact (hxQ _ _ _ (4 + j) b (by omega)).symm.trans
      (hx 15 (by decide) (4 + j) (by have := hr.bQ; omega) (by show 4 ≤ 4 + j; omega) b)
  have hK : ∀ j, j < 7 → ∀ b, Qkv.xcZc U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) .Kv 61 3 bga (4 + j) b = 0 := by
    intro j hj b
    exact (hxK _ _ _ (4 + j) b (by omega)).symm.trans
      (hx 16 (by decide) (4 + j) (by have := hr.bK; omega) (by show 4 ≤ 4 + j; omega) b)
  have hS : ∀ j, j < 8 + ls → ∀ b, Szc.xcSzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) B bga (5 + j) b = 0 := by
    intro j hj b
    rw [← hxS _ _ _ _ _ (by omega)]
    exact hx 17 (by decide) (5 + j) (by have := hr.bS; omega) (by show 5 ≤ 5 + j; omega) b
  have hF : ∀ κ, 3 ≤ κ → κ < 11 → ∀ b, Fzc.xcFzcR U G P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) B bga κ b = 0 := by
    intro κ h1 h2 b
    rw [← hxF _ _ _ _ _ h1]
    exact hx 18 (by decide) κ (by have := hr.bF; omega) (by show 3 ≤ κ; exact h1) b
  have hcl0 := hT.2.1.2.2
  rw [hls] at hcl0
  have hcl : Link.claimSem U ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE (cutsOf key domain hs hL A G')
      (rootsOf (A.run G').2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)).Q .h) ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
      (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)).X .h) (logupSumR13 c) = 0 := by
    have e : Link.claimSem U ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE (cutsOf key domain hs hL A G')
        (rootsOf (A.run G').2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
        (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)).Q .h) ((dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
        (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)).X .h) (logupSumR13 c)
        = Link.csXof U tag L (Link.le64_of_le20 hL20) 16 256 24448 rA rH csE (cutsOf key domain hs hL A G')
          (rootsOf (A.run G').2) .h (logupSumR13 c) :=
      claimSem_cast14 U rH 256 P.logCols hlc
        (Link.xHof tag L (Link.le64_of_le20 hL20) 16 256 24448 rH (cutsOf key domain hs hL A G')
          (rootsOf (A.run G').2)) _
    exact e.trans (hcl0.trans (Fp2.toK_zero U))
  have hfun : aPl U P (dofAR tag hL20 P hlc 16 256 24448 rA rH rE QE XE (absOfC (chainEncB key domain hs L hL)) A
      (cutsOf key domain hs hL A G').1)
      = aPl U P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE (cutsOf key domain hs hL A G')
          (rootsOf (A.run G').2)) := by
    funext off log b
    exact dofAR_aPl U key domain hs hL tag hL20 P hlc 16 256 24448 rA rH rE QE XE A G' off log b
  refine hhr_of_relsR U hU G hc P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE (cutsOf key domain hs hL A G')
    (rootsOf (A.run G').2)) (show P.logCols = 14 from hlc) Pb Lay B Pb.exp Pb.act S.nG bga
    (relsR_of U hU G hc hr P _ (dXof_base_r13 tag hL20 P hlc rA rH rE QE XE (cutsOf key domain hs hL A G')
      (rootsOf (A.run G').2)) Pb Lay B gL Pb.exp Pb.act S.nG bga hα hβ hLz hD hQ hK hS hF hTab)
    hcl hzs _ (fun l => ?_) _ (fun j => ?_)
  · rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩
    · cases s <;> (simp only [AlkR13, sgTupR, lkAtR, lkTupR, expTupR, actTupR]; rw [hfun])
    · simp only [AlkR13, lkAtR, lkTupR]
      rw [hfun]
    · simp only [AlkR13, lkAtR, lkTupR]
      rw [hfun]
  · simp only [mlkR13, R13T.multTabR]
    rw [hfun]

/-- **Lane L36's `hhr` at the R13 rung**, in the exact form of `block_knowledge_help_r13_rung`'s premise, with
`Alk := AlkR13 … (dofAR …)`, `T := TR13 Pb.exp Pb.act S.nG`, `mlk := mlkR13 … (dofAR …)`, for batch entries `xc` that
are the hosts' past their named clauses (`hxD` … `hxF`), given the verifier fact `hls`. -/
theorem hhrR_rung {S : ZK60.Block.BlockShape} (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
      (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = logupSumR13 DefR13.cfgRungR13) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen DefR13.cfgRungR13 k) → Bool) → K)
    (hxD : ∀ cu rt bga κ b, 13 ≤ κ → xc 14 cu rt bga κ b
      = Dzc.xcDzcR U geoRung P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B bga κ b)
    (hxQ : ∀ cu rt bga κ b, 4 ≤ κ → xc 15 cu rt bga κ b
      = Qkv.xcZc U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) .Q 47 2 bga κ b)
    (hxK : ∀ cu rt bga κ b, 4 ≤ κ → xc 16 cu rt bga κ b
      = Qkv.xcZc U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) .Kv 61 3 bga κ b)
    (hxS : ∀ cu rt bga κ b, 5 ≤ κ → xc 17 cu rt bga κ b
      = Szc.xcSzcR U geoRung P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) B bga κ b)
    (hxF : ∀ cu rt bga κ b, 3 ≤ κ → xc 18 cu rt bga κ b
      = Fzc.xcFzcR U geoRung P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) B bga κ b)
    (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
        (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      Help.HGdR U DefR13.cfgRungR13 P (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
        (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
          (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
          perRow_rung xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) (Pub.gateLS DefR13.cfgRungR13.sh)
        Pb.exp Pb.act S.nG (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U DefR13.cfgRungR13 P Pb Lay B geoRung (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TR13 Pb.exp Pb.act S.nG j))
        (mlkR13 U DefR13.cfgRungR13 P (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh :=
  hhrR_gen U hU key domain hs hL hL20 P tag (by rw [hP.hsl]; decide) geoRung lookCfg_rung relCfg_rung
    (shOk_rung P hP.hdr) perRow_rung ioIn ioOut _ hdef hlc hls hdrLen csE rE QE 437 248 XE Pb Lay B
    (Pub.gateLS DefR13.cfgRungR13.sh) xc pwc hxD hxQ hxK hxS hxF A

/-- **Lane L36's `hhr` at a layer `Ly` of the Shieldstral T128 R13 block**, in the exact form of
`block_knowledge_help_r13_shield`'s premise. -/
theorem hhrR_shield (Ly : ZK60.RunShape.Shield.ShieldLayer) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ)
    (hP : Link.IsShieldR13 P tag rowsOf) (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly))
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
      (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG))
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = logupSumR13 (DefR13.cfgShieldR13 Ly)) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen (DefR13.cfgShieldR13 Ly) k) → Bool) → K)
    (hxD : ∀ cu rt bga κ b, 13 ≤ κ → xc 14 cu rt bga κ b
      = Dzc.xcDzcR U (geoShield Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B bga κ b)
    (hxQ : ∀ cu rt bga κ b, 4 ≤ κ → xc 15 cu rt bga κ b
      = Qkv.xcZc U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) .Q 47 2
        bga κ b)
    (hxK : ∀ cu rt bga κ b, 4 ≤ κ → xc 16 cu rt bga κ b
      = Qkv.xcZc U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) .Kv 61 3
        bga κ b)
    (hxS : ∀ cu rt bga κ b, 5 ≤ κ → xc 17 cu rt bga κ b
      = Szc.xcSzcR U (geoShield Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) B bga κ b)
    (hxF : ∀ cu rt bga κ b, 3 ≤ κ → xc 18 cu rt bga κ b
      = Fzc.xcFzcR U (geoShield Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) B bga κ b)
    (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
        (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG)))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      Help.HGdR U (DefR13.cfgShieldR13 Ly) P (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
        (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
          (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
          (perRow_shield Ly) xc pwc)
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt)
        (Pub.gateLS (DefR13.cfgShieldR13 Ly).sh) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U (DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly) (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE
            QE XE (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (TR13 Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG j))
        (mlkR13 U (DefR13.cfgShieldR13 Ly) P (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh :=
  hhrR_gen U hU key domain hs hL hL20 P tag (by rw [hP.hsl]; decide) (geoShield Ly) (lookCfg_shield Ly)
    (relCfg_shield Ly) (shOk_shield Ly P hP.hdr) (perRow_shield Ly) ioIn ioOut _ hdef hlc hls hdrLen csE rE QE 4577
    4390 XE Pb Lay B (Pub.gateLS (DefR13.cfgShieldR13 Ly).sh) xc pwc hxD hxQ hxK hxS hxF A

end Final

end ZK60.Exec.Block.Join.R13H.LookRel
