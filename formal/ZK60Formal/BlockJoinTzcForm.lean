/-
D63 lane L41 (2026-11-10), part 7: **`SC_TZC`'s named identity (`FormAt`) at the W16R2 rung**, lane L36's `hform` for
host `2`.

* `hist2`: the history slot `2` reads;
* **`formAt_tzc`**: for every algebra data `dt` whose `SC_TZC` tables are `W16Rels`' relation tables of the extracted
  planes (`relCl 2`, `relGh 2`, `relMm 2`, embedded), on every outcome whose verified slots passed `run_slot`'s
  checks, `SC_TZC`'s certified polynomial at the drawn challenges IS its unmasked residual (`Σ Poly_2` minus
  `ν_0·Σ Poly_0 + ν_1·Σ Poly_1`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinTzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)
variable {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- The rung's slot shapes `(main, extension, degree)` of slots `0`, `1`, `2`. -/
theorem slotShape_rung (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) :
    slotShape P 0 = (14, 1, 4) ∧ slotShape P 1 = (14, 1, 4) ∧ slotShape P 2 = (5, 1, 3) := by
  simp only [slotShape, hsl]
  decide

/-- The draw of slot `s` at position `a`, read at slot `k` from the history and the slot's draws. -/
theorem eval_dr (hist : Hist) (k : ℕ) (dr : List Fp2) (s a : ℕ) :
    Sym.eval hist k dr (.dr s a) = drawAt hist k dr s a := rfl

theorem dr5_getD (ev : Sym → Fp2) (s : ℕ) (a : Fin 5) :
    ((dr5 s).map ev).getD a Fp2.zero = ev (.dr s a) := by
  fin_cases a <;> rfl

include hcard in
/-- **`SC_TZC`'s named identity at the rung.** -/
theorem formAt_tzc (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (progW16 cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hTok : Function.Surjective Lay.tok.emb) (hc : S.ceps = 1)
    (hgD : ∀ s, s = 0 ∨ s = 1 → ∀ hist dr (t : CtW) (c : CwW),
      ((pubs s hist dr 0).getD (msbIndex 14 (Fin.append t c)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, c)))
    (mpad : ℕ → ℕ) (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) (dt : AlgData K L (algShapeW16Rung P hdr mpad hm0 hm78))
    (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 6) (t : CtW), dt.cl 2 cu rt bga κ t
      = algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 (κ : ℕ) (.t t)))
    (hgh : ∀ (i : Fin 2) (t : CtW), dt.gh 2 cu rt i t = algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 i (.t t)))
    (hmm : ∀ (i : Fin 2) (t : CtW), dt.mm 2 cu rt i t = algebraMap GF K (relMm Pb Lay B (xtW U P D) 2 i (.t t)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpad hm0 hm78) dt hcard 0 cu rt k h).Φ) bga rs 2 := by
  obtain ⟨hs0, hs1, hs2⟩ := slotShape_rung P hsl
  set prog := progW16 cfgRungW16 ioIn ioOut with hprog
  refine formAt_host_of U (algShapeW16Rung P hdr mpad hm0 hm78) dt hcard _ cu rt bga rs 2 (by decide) (fun r df hr hdf => ?_)
  have hlen : 2 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r0, hr0⟩ : ∃ r0, rs[0]? = some r0 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r1, hr1⟩ : ∃ r1, rs[1]? = some r1 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  -- the definitions of slots 0, 1, 2
  have hdf2 : defineS prog pubs 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) r.draws = .ok df := hdef ▸ hdf
  obtain ⟨-, hdfe⟩ := defineS_ok hdf2
  have hkind2 := (hslots 2 r hr)
  obtain ⟨df2', hdf2', hk2⟩ := hkind2
  rw [hdf] at hdf2'
  cases hdf2'
  have hhost : df.hosted = [(0, Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 2 r.draws (.dr 2 11)),
      (1, Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 2 r.draws (.dr 2 12))] := by
    rw [hdfe, slot2_eq]
    rfl
  have hnot : ∀ j rj, j = 0 ∨ j = 1 → rs[j]? = some rj → P.kind j ≠ SlotKind.host := by
    intro j rj hj hrj hk
    obtain ⟨dfj, hdfj, hkj⟩ := hslots j rj hrj
    have hdfj' : defineS prog pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws = .ok dfj := hdef ▸ hdfj
    obtain ⟨-, hdfje⟩ := defineS_ok hdfj'
    have hemp : dfj.hosted = [] := by
      rcases hj with rfl | rfl
      · rw [hdfje, slot0_eq]
        rfl
      · rw [hdfje, slot1_eq]
        rfl
    exact hkj.mp hk hemp
  refine ⟨hk2.mpr (by rw [hhost]; simp), fun hk' hmem => ?_, ?_⟩
  · rw [hhost] at hmem
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
    rcases hmem with rfl | rfl
    · exact hnot 0 r0 (Or.inl rfl) hr0
    · exact hnot 1 r1 (Or.inr rfl) hr1
  · -- the identity
    set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 2) with hhist
    set ev := Sym.eval hist 2 r.draws with hev
    have hmuK : ∀ j : ℕ, j < 6 → ((muTzc.map ev).map (Fp2.toK U)).getD j 0 = (r.draws.getD (5 + j) Fp2.zero).toK U := by
      intro j hj
      interval_cases j <;> rfl
    have hdrK : ∀ s a : ℕ, a < 5 → ((dr5 s).map ev).getD a Fp2.zero = drawAt hist 2 r.draws s a := by
      intro s a ha
      interval_cases a <;> rfl
    -- slot 2's cube sum
    have hsp2 := tzc_cube U P D hX hrl Pb Lay B hTok hc (slotShape P 2).1 (slotShape P 2).2.1 (by rw [hs2]) hist
      r.draws (pubs 2 hist r.draws) (polyS U P D prog pubs 2 (seenOf bga rs 2))
      (fun x => by rw [polyS_seenOf U P D prog pubs bga rs 2 r hr x, hprog, slot2_eq]; rfl)
    -- slots 0 and 1
    have hsp0 := ss_cube U P D hX hrl Pb Lay B (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) 0 131072 90 r0.draws
      (pubs 0 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) r0.draws) (hgD 0 (Or.inl rfl) _ _)
      (slotShape P 0).1 (slotShape P 0).2.1 (by rw [hs0]) (polyS U P D prog pubs 0 (seenOf bga rs 0))
      (fun x => by rw [polyS_seenOf U P D prog pubs bga rs 0 r0 hr0 x, hprog, slot0_eq]; rfl)
    have hsp1 := ss_cube U P D hX hrl Pb Lay B (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) 1 278528 92 r1.draws
      (pubs 1 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) r1.draws) (hgD 1 (Or.inr rfl) _ _)
      (slotShape P 1).1 (slotShape P 1).2.1 (by rw [hs1]) (polyS U P D prog pubs 1 (seenOf bga rs 1))
      (fun x => by rw [polyS_seenOf U P D prog pubs bga rs 1 r1 hr1 x, hprog, slot1_eq]; rfl)
    rw [hostSp_Φ]
    unfold hostPhi
    rw [hhost]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
    unfold spSum
    rw [hsp2, hsp0, hsp1]
    congr 1
    · -- the host's sum
      refine Finset.sum_congr rfl (fun t _ => ?_)
      refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
      · have ha : (a : ℕ) < 5 := a.isLt
        show segAt ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) (fun j => (fun i : Fin (P.draws 2) => (r.draws.getD i.val Fp2.zero).toK U)
            (Fin.cast ((algShapeW16Rung P hdr mpad hm0 hm78).hsum 2 (by decide)) j)) .tau a = _
        unfold segAt
        rw [dite_eq_left (by show 0 + (a : ℕ) < 13; omega), hdrK 2 a ha]
        simp only [Fin.val_cast, drawAt, ite_true]
        rw [show segOff ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .tau = 0 from rfl, Nat.zero_add]
      · unfold batched
        have hz : segLn ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .zeta = 0 := rfl
        simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
        refine Finset.sum_congr rfl (fun κ _ => ?_)
        have hκ : (κ : ℕ) < 6 := κ.isLt
        rw [hcl (hist.beta, hist.gamma, hist.alpha) κ t, hmuK κ hκ]
        congr 1
        unfold segAt
        rw [dite_eq_left (by show 5 + (κ : ℕ) < 13; omega)]
        rfl
      · fin_cases i
        · show segAt ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) _ .nu 0 = ((nuTzc.map ev).map (Fp2.toK U)).getD 0 0
          unfold segAt
          rw [dite_eq_left (by show 11 + 0 < 13; omega)]
          rfl
        · show segAt ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) _ .nu 1 = ((nuTzc.map ev).map (Fp2.toK U)).getD 1 0
          unfold segAt
          rw [dite_eq_left (by show 11 + 1 < 13; omega)]
          rfl
      · have hj : (j : ℕ) < 5 := j.isLt
        fin_cases i
        · show algPt U (algShapeW16Rung P hdr mpad hm0 hm78) 2 hist 0 j = (((dr5 0).map ev).getD j Fp2.zero).toK U
          rw [hdrK 0 j hj]
          rfl
        · show algPt U (algShapeW16Rung P hdr mpad hm0 hm78) 2 hist 1 j = (((dr5 1).map ev).getD j Fp2.zero).toK U
          rw [hdrK 1 j hj]
          rfl
      · rw [algH_gh U (algShapeW16Rung P hdr mpad hm0 hm78) dt 2 cu rt hist i (fun h => absurd h.1 (by decide))]
        exact hgh i t
    · -- the hosted sums
      rw [Fin.sum_univ_two]
      have hM : ∀ i : Fin 2, algM (algShapeW16Rung P hdr mpad hm0 hm78) dt 2 cu rt i = fun t => algebraMap GF K (relMm Pb Lay B (xtW U P D) 2 i (.t t)) :=
        fun i => by
          rw [algM_mm (algShapeW16Rung P hdr mpad hm0 hm78) dt 2 cu rt i (fun h => absurd h.1 (by decide))]
          exact funext (hmm i)
      rw [hM 0, hM 1]
      have hp0 : algPt U (algShapeW16Rung P hdr mpad hm0 hm78) 2 hist 0 = fun a : Fin 5 =>
          (((dr5 0).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) 0 r0.draws)).getD a Fp2.zero).toK U := by
        funext a
        have ha : (a : ℕ) < 5 := a.isLt
        show algDrawAt U hist 0 a = _
        rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 0 a r0 (by decide) hr0]
        have : ((dr5 0).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) 0 r0.draws)).getD a Fp2.zero
            = r0.draws.getD a Fp2.zero := by
          interval_cases (a : ℕ) <;> rfl
        rw [this]
      have hp1 : algPt U (algShapeW16Rung P hdr mpad hm0 hm78) 2 hist 1 = fun a : Fin 5 =>
          (((dr5 1).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) 1 r1.draws)).getD a Fp2.zero).toK U := by
        funext a
        have ha : (a : ℕ) < 5 := a.isLt
        show algDrawAt U hist 1 a = _
        rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 1 a r1 (by decide) hr1]
        have : ((dr5 1).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) 1 r1.draws)).getD a Fp2.zero
            = r1.draws.getD a Fp2.zero := by
          interval_cases (a : ℕ) <;> rfl
        rw [this]
      rw [hp0, hp1]
      congr 1

end Form

end ZK60.Exec.Block.Join.W16
