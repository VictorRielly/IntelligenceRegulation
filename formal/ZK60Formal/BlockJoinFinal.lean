/-
D63 lane L41 (2026-11-10), part 9: **the W16R2 rung block's knowledge statement with the extraction, the algebra data,
the encodings, `hspec` and `SC_TZC`'s named identity discharged** (on lane L35's
`block_knowledge_define_alg_w16r2_rung`, which carries lanes L31, L35 and L36's chain).

* **`dXof_base`**: every entry of the rung's committed `A` matrix (`dXof`) is a base value (`xAof_base_w16`);
* **`block_knowledge_join_w16r2_rung`**: `Pr[BlockAcc ∧ header ∧ ¬BlockSat(xtW)] ≤ εsTarget q + εend` with
  `xtE := xtW` (the extracted planes, DEFINED from the committed `A` matrix), `sh := algShapeW16Rung` (the rung's draw
  schedule), `dt := dtW` (the relation tables), `enc := encW`, `encHt := encHtW`, `hspec` PROVED (`hspecW`) and the
  hosts' named identity `hform` PROVED for `SC_TZC` (`formAt_tzc`); left by name: `hformRest` (the five other hosts),
  the pad planes and the batch's LogUp entries (`mpad`, `xc`, `pwc`), the public-data facts `RungS`, `hTok`, `hHd`
  and the gate tables `hgD`, and lane L36's helper layer and lookup premises.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinTzcForm
import ZK60Formal.BlockJoinDt
import ZK60Formal.BlockDefineAlg

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **The rung's committed `A` matrix is base-valued** (finding L41-1, at `(15, 280, 8052)`). -/
theorem dXof_base (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K) (cu : Cuts3 L)
    (rt : RootsO) :
    ∀ i t, (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt).X .a i t ∈ baseR K := by
  intro i t
  obtain ⟨g, hg⟩ := xAof_base_w16 (K := K) tag L (Link.le64_of_le20 hL20) 320 cu rt i (colCast P hlc 280 t)
  exact ⟨g, hg.symm⟩

/-- **The W16R2 rung block's knowledge statement with the extraction, the algebra data, the encodings, `hspec` and
`SC_TZC`'s named identity discharged.** -/
theorem block_knowledge_join_w16r2_rung [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : W16Widths S fams) (h24 : S.h24 = true)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data facts: the shape's constants, the axes that do not pad, the support gate of `Dom::D`
    (hS : RungS S) (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    (hgD : ∀ s, s = 0 ∨ s = 1 → ∀ hist dr (t : CtW) (c : CwW),
      ((pubs s hist dr 0).getD (msbIndex 14 (Fin.append t c)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, c)))
    -- the pad planes and the batch's entries past the named clauses (LogUp's helper relations)
    (mpad : ℕ → ℕ) (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpad k) →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    -- the other five hosts' named identities
    (hformRest : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15
      280 8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ [14, 15, 16, 17, 18], FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeW16Rung P hP.hdr mpad hm0 hm78)
          (dtW Pb Lay B P hP.hdr mpad hm0 hm78
            (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)) xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend := by
  have hrl : 0 < rowLog P .a := by show 0 < P.logCols; rw [hlc]; norm_num
  exact block_knowledge_define_alg_w16r2_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut pubs hdef
    hlc hep hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B fams hF hW h24
    (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)) q A hA εend hEnd
    (algShapeW16Rung P hP.hdr mpad hm0 hm78)
    (dtW Pb Lay B P hP.hdr mpad hm0 hm78
      (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)) xc pwc)
    (fun G bga rs acc hT k hk => by
      by_cases h2 : k = 2
      · subst h2
        exact formAt_tzc U (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef
          (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (dXof_base tag hL20 P hlc rE QE XE _ _) hrl hTok hS.ceps hgD mpad hm0 hm78 _ _ _
          (fun bga κ t => by
            show (if (κ : ℕ) < relCount 2 then _ else _) = _
            rw [ite_eq_left (by have := κ.isLt; show (κ : ℕ) < 6; omega)]
            rfl)
          (fun _ _ => rfl) (fun _ _ => rfl) bga rs
          (fun j r hr => by
            obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
              rs acc hT j r hr
            exact ⟨df, hdf, hkind⟩)
      · exact hformRest G bga rs acc hT k (by
          simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
          simp only [List.mem_cons, List.not_mem_nil, or_false]
          omega))
    encW encHtW (hspecW Pb Lay B P hP.hdr mpad hm0 hm78 _ xc pwc) hTok hHd HGd spH hdgH hformH hgdH Alk T mlk hN he
    hTtab hcov hhr

end Final

end ZK60.Exec.Block.Join.W16
