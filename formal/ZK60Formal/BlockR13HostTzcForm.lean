/-
D63 lane L49 (2026-11-10), sub-agent `tzc`, part 2: **R13's `SC_TZC` named identity (`FormAt`) at host `2`**, generic
in the configuration: lane L36's `hform` for host `2` at the R13 rung and at every layer of the app's Shieldstral T128
R13 block (lane L41's `formAt_tzc` at R13, in the shape of lane L44's `formAt_fzc`).

* `xcTzcR`: the batch's entries past `SC_TZC`'s six named clauses (there are none; `0` for the lane's dispatch);
* **`formAt_tzcR`**: for every algebra data `dt` whose host-`2` tables are R13's relation tables of the extracted
  planes (`r13Cl 2`, `r13Gh 2`, `r13Mm 2` of `xtR` through `encR`), on every outcome whose verified slots are hosts
  exactly when their definitions host slots, `SC_TZC`'s certified polynomial at the drawn challenges IS its unmasked
  residual `Σ Poly₂ − (ν₀·Σ Poly₀ + ν₁·Σ Poly₁)`, for any configuration with `GeoR`, `ShOkR`, `ProfR` and `TzcCfg`
  (proved at the R13 rung and at every Shieldstral layer: `tzcCfg_rung`, `tzcCfg_shield`). No pad planes: `mpadR 2 = 0`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostTzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Tzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched segAt segAt_mk)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (formAt_two)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-- **The batch's entries past `SC_TZC`'s six named clauses**: `SC_TZC` batches exactly its six clauses (`μ_6`, where
`Dom::T` pads, is the pad term's weight, not a batch entry; at R13 `Dom::T` does not pad), so there are none; `0`, for
the lane's dispatch of the algebra data's other entries. -/
def xcTzcR {K : Type} [Field K] (c : W16Cfg) (_bga : Fp2 × Fp2 × Fp2) (_κ : ℕ) (_b : Fin (tauLen c 2) → Bool) : K :=
  0

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **Lane L36's `FormAt` at host `2` (`SC_TZC`) at R13, generic in the configuration**: on every outcome whose
verified slots are hosts exactly when their definitions host slots, `SC_TZC`'s certified polynomial at the drawn
challenges IS its unmasked residual `Σ Poly₂ − (ν₀·Σ Poly₀ + ν₁·Σ Poly₁)`, for every algebra data whose host-`2`
tables are R13's relation tables of the extracted planes. -/
theorem formAt_tzcR (U : K) (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : TzcCfg c)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR c S) (_hW : ZK60.Layout.R13.R13Windows S ls) (hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 2 cu rt bga κ b = if (κ : ℕ) < r13Count 2
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 2 (clIx 2 κ) (encR G 2 b)) else xcTzcR c bga κ b)
    (hgh : ∀ i b, dt.gh 2 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 2 i (encR G 2 b)))
    (hmm : ∀ i b, dt.mm 2 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 2 i (encR G 2 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 2 := by
  have hk2 : (2 : ℕ) ∈ algHosts := by decide
  obtain ⟨ak2, hk2', hsl2⟩ := progR13_slot c ioIn ioOut 2 (by norm_num)
  obtain ⟨ak0, hk0', hsl0⟩ := progR13_slot c ioIn ioOut 0 (by norm_num)
  obtain ⟨ak1, hk1', hsl1⟩ := progR13_slot c ioIn ioOut 1 (by norm_num)
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D (algShapeR c P hc) dt cu rt bga rs 2 hk2
    0 1 (.dr 2 (c.sh.lt + 6)) (.dr 2 (c.sh.lt + 7)) ?_ ?_ ?_ (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  · exact congrArg SlotS.hosted (hsl2.trans (congrArg (DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c)
      ioIn ioOut ak2 hk2') hcfg.raw2))
  · exact congrArg SlotS.hosted (hsl0.trans (congrArg (DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c)
      ioIn ioOut ak0 hk0') hcfg.raw0))
  · exact congrArg SlotS.hosted (hsl1.trans (congrArg (DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c)
      ioIn ioOut ak1 hk1') hcfg.raw1))
  -- the identity at an outcome
  have hlen : 2 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r0, hr0⟩ : ∃ r0, rs[0]? = some r0 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r1, hr1⟩ : ∃ r1, rs[1]? = some r1 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  -- the slots' cubes
  have hs2 : (slotShape P 2).1 = c.sh.lt := by
    rw [hpf.slots 2 (by norm_num)]
    exact G.logT
  have hs0 : (slotShape P 0).1 = nD c := by
    rw [hpf.slots 0 (by norm_num)]
    exact G.logD
  have hs1 : (slotShape P 1).1 = nD c := by
    rw [hpf.slots 1 (by norm_num)]
    exact G.logD
  -- the three slots' cube sums
  have hsp2 := tzcR_cube U Pb Lay B P D hX hrl G.lt_pos hcfg.cepsLo hcfg.cepsHi hLay hS ls (DefR13.aDataRows c)
    (DefR13.hDataRows c) ioIn ioOut ak2 hk2' (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) r.draws
    (pubs 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) r.draws) (slotShape P 2).1 (slotShape P 2).2.1 hs2
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 2 (seenOf bga rs 2))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 2 r hr x, hsl2, hcfg.raw2]; rfl)
  have hsp0 := ssR_cube U B P D hX hrl G.lt_pos (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak0 hk0'
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) 0 8 r0.draws (pubs 0 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) r0.draws)
    (fun t w => hpub.ssGate 0 (Or.inl rfl) _ _ t w) (slotShape P 0).1 (slotShape P 0).2.1 hs0
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 0 (seenOf bga rs 0))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 0 r0 hr0 x, hsl0, hcfg.raw0]; rfl)
  have hsp1 := ssR_cube U B P D hX hrl G.lt_pos (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak1 hk1'
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) 1 26 r1.draws
    (pubs 1 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) r1.draws)
    (fun t w => hpub.ssGate 1 (Or.inr rfl) _ _ t w) (slotShape P 1).1 (slotShape P 1).2.1 hs1
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 1 (seenOf bga rs 1))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 1 r1 hr1 x, hsl1, hcfg.raw1]; rfl)
  -- slot `2`'s draw layout
  have hdl : (algShapeR c P hc).dl 2 = [(.tau, c.sh.lt), (.mu, 6), (.nu, 2), (.zeta, 0)] := hcfg.dl2
  have hoT : segOff ((algShapeR c P hc).dl 2) .tau = 0 := by
    rw [hdl]
    rfl
  have hoM : segOff ((algShapeR c P hc).dl 2) .mu = c.sh.lt := by
    rw [hdl]
    rfl
  have hoN : segOff ((algShapeR c P hc).dl 2) .nu = c.sh.lt + 6 := by
    rw [hdl]
    rfl
  have hsS : segSum ((algShapeR c P hc).dl 2) = c.sh.lt + 8 := by
    rw [hdl]
    simp [segSum]
  have hlM : segLn ((algShapeR c P hc).dl 2) .mu - segLn ((algShapeR c P hc).dl 2) .zeta = 6 := by
    rw [hdl]
    rfl
  have hpw0 : ∀ g : Fin ((algShapeR c P hc).mpad 2) → K, ∑ j, g j = 0 := fun g => Fin.sum_univ_zero g
  have hseg : ∀ (g : Seg) (i : ℕ), segOff ((algShapeR c P hc).dl 2) g + i < c.sh.lt + 8 →
      segAt ((algShapeR c P hc).dl 2) (fun j => (fun q : Fin (P.draws 2) => (r.draws.getD q.val Fp2.zero).toK U)
        (Fin.cast ((algShapeR c P hc).hsum 2 hk2) j)) g i
        = (r.draws.getD (segOff ((algShapeR c P hc).dl 2) g + i) Fp2.zero).toK U := by
    intro g i h
    exact (segAt_mk ((algShapeR c P hc).dl 2) _ g i (by rw [hsS]; exact h)).symm
  have hκ : ∀ (bga' : Fp2 × Fp2 × Fp2) (b : Fin (segLn ((algShapeR c P hc).dl 2) .tau) → Bool)
      (κ : Fin (segLn ((algShapeR c P hc).dl 2) .mu - segLn ((algShapeR c P hc).dl 2) .zeta)),
      segAt ((algShapeR c P hc).dl 2) (fun j => (fun q : Fin (P.draws 2) => (r.draws.getD q.val Fp2.zero).toK U)
        (Fin.cast ((algShapeR c P hc).hsum 2 hk2) j)) .mu κ * dt.cl 2 cu rt bga' κ b
        = (r.draws.getD (c.sh.lt + κ) Fp2.zero).toK U
          * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 2 κ (.t b)) := by
    intro bga' b κ
    have hκ6 : (κ : ℕ) < 6 := by
      have := κ.isLt
      omega
    rw [hseg .mu κ (by rw [hoM]; omega), hoM, hcl, ite_eq_left (show (κ : ℕ) < r13Count 2 from hκ6)]
    rfl
  rw [hostSp_Φ]
  unfold hostPhi
  unfold spSum
  rw [hsp2, hsp0, hsp1]
  refine congrArg₂ (fun x y : K => x - y) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ b (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · -- `τ`
      have ha : (a : ℕ) < c.sh.lt := a.isLt
      refine (hseg .tau a ?_).trans ?_
      · rw [hoT]
        omega
      · rw [hoT, Nat.zero_add]
    · -- the batched clauses
      unfold batched
      rw [hpw0, mul_zero, add_zero, Finset.sum_congr rfl (fun κ _ => hκ _ b κ),
        Fin.sum_univ_eq_sum_range (fun κ => (r.draws.getD (c.sh.lt + κ) Fp2.zero).toK U
          * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 2 κ (.t b))) _, hlM]
    · -- `ν`
      have hi : (i : ℕ) < 2 := i.isLt
      refine (hseg .nu i ?_).trans ?_
      · rw [hoN]
        omega
      · rw [hoN]
    · -- the hosted points
      fin_cases i <;> rfl
    · -- the hosted terms
      rw [algH_gh U (algShapeR c P hc) dt 2 cu rt _ i (fun h => absurd h.1 (by decide))]
      exact hgh i b
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeR c P hc) dt 2 cu rt i
        = fun t => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 2 i (.t t)) := fun i => by
      rw [algM_mm (algShapeR c P hc) dt 2 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeR c P hc) 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 0
        = fun a : Fin c.sh.lt => (r0.draws.getD a Fp2.zero).toK U := by
      funext a
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 0 a r0 (by norm_num) hr0
    have hp1 : algPt U (algShapeR c P hc) 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 1
        = fun a : Fin c.sh.lt => (r1.draws.getD a Fp2.zero).toK U := by
      funext a
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 1 a r1 (by norm_num) hr1
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · refine (hseg .nu 0 (by rw [hoN]; omega)).trans ?_
      rw [hoN, eval_dr_self, Nat.add_zero]
    · refine (hseg .nu 1 (by rw [hoN]; omega)).trans ?_
      rw [hoN, eval_dr_self, show c.sh.lt + 6 + 1 = c.sh.lt + 7 by omega]

end Form

end ZK60.Exec.Block.Join.R13H.Tzc
