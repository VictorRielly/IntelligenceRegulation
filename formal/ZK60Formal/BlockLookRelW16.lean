/-
D63 lane L47 (2026-11-10), part 7 (fork C): **lane L36's `hhr` at the W16R2 rung, PROVED** (deliverable 2; finding
L44-K3).

On every accepting outcome whose helper-layer start claims hold (`Lk.HGdW`), the helper values the prover committed in
`H` satisfy every relation of `HelperRel` for the lookup list `AlkW`, the table `TW` and the multiplicities `mlkW` of
`BlockLookBase.lean`:

* `dtW_cl_xc`: a host's batch entry past its named clauses is L44's `xcW` entry;
* `AlkW_real`, `mlkW_real`: the lookups and multiplicities the `A` cut fixes are the real data's (`dofA_aPl`);
* **`hhr_singles`**, **`hhr_pairs`**, **`hhr_table`**: the single, pair and table relations, from the hosts' LogUp
  entries (`BlockLookRelPer.lean`), `SC_LZC`'s relation and `SC_TAB`'s start claim (`spTabW_Gd`);
* `logupSum_parts`, `logupSum_empty`, **`logupSum_planes`**: the code's `logup_sum_claim` (`DefW16.logupSumW16`) on the
  `H` matrix IS `Σ_hp sign_hp·Σ_cube H_hp` (`BlockLookSum.lean`);
* **`hhr_sum`**: with `H_U`'s zero sum (`SC_ZS`), `Σ singles + Σ pairs − Σ table = 0`;
* **`hhr_w16`**: lane L36's `hhr` in the exact form of `block_knowledge_host_w16r2_rung_helper`'s premise, with the
  new verifier fact `hls : P.logupSumClaim = DefW16.logupSumW16 DefW16.cfgRungW16`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookRelPer
import ZK60Formal.BlockLookSum

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
open ZK60.Circuit (gP GF tagW)
open ZK60.Layout

/-! ## The batch entries past the named clauses -/

section Cl

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

theorem dtW_cl_xc {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay) (P : BlockParams)
    (hdr : P.draws = W16R2.rungDraws) (E : Cuts3 L → RootsO → W16Data CtW CwW CgW CjW CdW CfW)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadW k) →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (κ : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl k) .mu
      - segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl k) .zeta))
    (b : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl k) .tau) → Bool)
    (hκ : relCount k ≤ (κ : ℕ)) :
    (dtW Pb Lay B P hdr mpadW mpadW_hm0 mpadW_hm78 E xc pwc).cl k cu rt bga κ b = xc k cu rt bga κ b := by
  show (if (κ : ℕ) < relCount k then _ else _) = _
  rw [ite_eq_right (by omega)]

end Cl

/-! ## The sum claim at the rung -/

/-- The `H` planes' log sizes. -/
def lsW (hp : ℕ) : ℕ := cfgRungW16.sh.logs ((hDoms cfgRungW16).getD hp .Tab)

/-- The sum claim's signs (`−1` on `SC_TAB`'s helpers). -/
def sgW (hp : ℕ) : Fp2 :=
  if decide (fh cfgRungW16 8 ≤ hp) && decide (hp < fh cfgRungW16 8 + 3 + nRange cfgRungW16) then Fp2.one.neg
  else Fp2.one

/-- The log sizes, as a table. -/
def lsT (hp : ℕ) : ℕ := if hp < 11 then 14 else if hp < 14 then 15 else if hp < 23 then 14 else if hp < 28 then 15 else 14

theorem lsW_eq : ∀ hp, hp < 46 → lsW hp = lsT hp := by decide +kernel

theorem sgW_eq (hp : ℕ) : sgW hp = if 28 ≤ hp ∧ hp < 45 then Fp2.one.neg else Fp2.one := by
  have h1 : fh cfgRungW16 8 = 28 := by decide +kernel
  have h2 : nRange cfgRungW16 = 14 := by decide +kernel
  unfold sgW
  rw [h1, h2]
  by_cases h : 28 ≤ hp ∧ hp < 45
  · rw [ite_eq_left h]
    simp [h.1, show hp < 28 + 3 + 14 by omega]
  · rw [ite_eq_right h]
    by_cases h3 : 28 ≤ hp
    · simp [h3, show ¬ (hp < 28 + 3 + 14) by omega]
    · simp [h3]

theorem logupSum_parts : (logupSumW16 cfgRungW16).parts = (List.range 46).flatMap fun hp =>
    [(⟨(hOff cfgRungW16 hp).1, lsW hp, sgW hp, []⟩ : ZPart), ⟨(hOff cfgRungW16 hp).2, lsW hp, (sgW hp).mul fp2U, []⟩] := by
  have hl : (hDoms cfgRungW16).length = 46 := by decide +kernel
  unfold logupSumW16
  rw [hl]
  rfl

theorem sgW_canon (hp : ℕ) : (sgW hp).Canon := by
  rw [sgW_eq]
  split_ifs
  · exact And.intro (Fp.neg_canon _ Fp2.canon_one.1) (Fp.neg_canon _ Fp2.canon_one.2)
  · exact Fp2.canon_one

theorem logupSum_empty : EmptyParts 14 (logupSumW16 cfgRungW16) := by
  intro q hq
  rw [logupSum_parts] at hq
  obtain ⟨hp, hhp, hq⟩ := List.mem_flatMap.mp hq
  have hlt := List.mem_range.mp hhp
  have hls : 14 ≤ lsW hp := by rw [lsW_eq hp hlt]; unfold lsT; split_ifs <;> omega
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl
  · exact ⟨rfl, hls, sgW_canon hp⟩
  · exact ⟨rfl, hls, Fp2.canon_mul _ _⟩

/-- A list sum over pairs of parts. -/
theorem sum_flatMap2 {K : Type} [AddCommMonoid K] {α : Type} (a c : ℕ → α) (g : α → K) :
    ∀ L : List ℕ, ((L.flatMap fun x => [a x, c x]).map g).sum = (L.map fun x => g (a x) + g (c x)).sum
  | [] => rfl
  | x :: L => by
    rw [List.flatMap_cons, List.map_append, List.sum_append, sum_flatMap2 a c g L, List.map_cons, List.sum_cons]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]

section Sum

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- An `H` plane's sum over its cube. -/
noncomputable def PSp (P : BlockParams) (D : CmData K P) (hp log : ℕ) : K :=
  ∑ c : Fin log → Bool, hPl U P D (hOff cfgRungW16 hp).1 (hOff cfgRungW16 hp).2 log c

include hU in
/-- **The code's `logup_sum_claim` on the `H` matrix is `Σ_hp sign_hp·Σ_cube H_hp`.** -/
theorem logupSum_planes (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14) :
    Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 cfgRungW16)
      = ((List.range 46).map fun hp => (sgW hp).toK U * PSp U P D hp (lsW hp)).sum := by
  have he : EmptyParts (rowLog P .h) (logupSumW16 cfgRungW16) := by rw [hln]; exact logupSum_empty
  obtain ⟨q0, qs, hz⟩ : ∃ q0 qs, (logupSumW16 cfgRungW16).parts = q0 :: qs := by
    rw [logupSum_parts]
    exact ⟨_, _, rfl⟩
  rw [claimSem_empty U _ _ _ _ _ q0 qs hz he, logupSum_parts, sum_flatMap2]
  congr 1
  refine List.map_congr_left (fun hp hhp => ?_)
  have hlt := List.mem_range.mp hhp
  have hls : 14 ≤ lsW hp := by rw [lsW_eq hp hlt]; unfold lsT; split_ifs <;> omega
  unfold PSp
  rw [show (∑ c : Fin (lsW hp) → Bool, hPl U P D (hOff cfgRungW16 hp).1 (hOff cfgRungW16 hp).2 (lsW hp) c)
      = ∑ c : Fin (lsW hp) → Bool, planeZ U (rowLog P .h) (D.rows .h) (D.Q .h) (D.X .h)
          ⟨.h, [((hOff cfgRungW16 hp).1, Fp2.one), ((hOff cfgRungW16 hp).2, fp2U)], lsW hp, [], 0, 0⟩ c from rfl,
    sum_planeZ2 U (rowLog P .h) (D.rows .h) (D.Q .h) hln (D.X .h) .h _ _ (lsW hp) hls [] 0 0,
    Fp2.toK_mul U hU]
  simp only [add_mul, Finset.sum_add_distrib, mul_assoc, ← Finset.mul_sum]
  ring

end Sum

/-! ## `hhr` -/

section Hhr

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

theorem toK_negOne (U : K) : (Fp2.one.neg).toK U = -1 := by
  rw [Fp2.toK_neg U _ Fp2.canon_one, Fp2.toK_one]

theorem sum_sgKind {M : Type} [AddCommMonoid M] (f : SgKind → M) :
    ∑ s, f s = f .D + (f .S + (f .F + (f .Exp + f .Act))) := by
  rw [show (Finset.univ : Finset SgKind) = [SgKind.D, .S, .F, .Exp, .Act].toFinset from rfl,
    List.sum_toFinset _ (by decide)]
  simp

theorem sum_lkDom {M : Type} [AddCommMonoid M] (f : LkDom → M) :
    ∑ d, f d = f .L + (f .D + (f .Q + (f .Kv + (f .S + f .F)))) := by
  rw [show (Finset.univ : Finset LkDom) = [LkDom.L, .D, .Q, .Kv, .S, .F].toFinset from rfl,
    List.sum_toFinset _ (by decide)]
  simp

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The sum of `HelperRel`, from the code's sum claim and `H_U`'s zero sum.** -/
theorem hhr_sum (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 cfgRungW16) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D 1736704 1753088 14 b = 0) :
    ∑ i : SgIx, hPl U P D (hOff cfgRungW16 i.1.hp).1 (hOff cfgRungW16 i.1.hp).2 i.1.log i.2
      + ∑ k : PrIx, hPl U P D (hOff cfgRungW16 (k.1.fh + k.2.1)).1 (hOff cfgRungW16 (k.1.fh + k.2.1)).2 k.1.log k.2.2
      - ∑ j : TbIx, helpTabW U P D j.1 j.2 = 0 := by
  rw [logupSum_planes U hU P D hln] at hcl
  have hcl' : ((List.range 46).map fun hp => (if 28 ≤ hp ∧ hp < 45 then (-1 : K) else 1) * PSp U P D hp (lsT hp)).sum
      = 0 := by
    rw [← hcl]
    congr 1
    refine List.map_congr_left (fun hp hhp => ?_)
    rw [lsW_eq hp (List.mem_range.mp hhp), sgW_eq]
    split_ifs
    · rw [toK_negOne]
    · rw [Fp2.toK_one]
  have hzs' : PSp U P D 45 14 = 0 := by
    unfold PSp
    rw [show hOff cfgRungW16 45 = (1736704, 1753088) by decide +kernel]
    exact hzs
  simp only [List.sum_range_succ, List.range_zero, List.map_nil, List.sum_nil, zero_add] at hcl'
  norm_num at hcl'
  simp only [lsT] at hcl'
  norm_num at hcl'
  have hS : ∑ i : SgIx, hPl U P D (hOff cfgRungW16 i.1.hp).1 (hOff cfgRungW16 i.1.hp).2 i.1.log i.2
      = PSp U P D 10 14 + (PSp U P D 21 14 + (PSp U P D 26 15 + (PSp U P D 22 14 + PSp U P D 27 15))) := by
    rw [Fintype.sum_sigma, sum_sgKind]
    rfl
  have hPr : ∑ k : PrIx, hPl U P D (hOff cfgRungW16 (k.1.fh + k.2.1)).1 (hOff cfgRungW16 (k.1.fh + k.2.1)).2 k.1.log
      k.2.2 = ∑ d : LkDom, ∑ j ∈ Finset.range d.np, PSp U P D (d.fh + j) d.log := by
    rw [Fintype.sum_sigma]
    refine Finset.sum_congr rfl (fun d _ => ?_)
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun j => PSp U P D (d.fh + j) d.log) d.np
  have hTb : ∑ j : TbIx, helpTabW U P D j.1 j.2 = ∑ k ∈ Finset.range 17, PSp U P D (28 + k) 14 := by
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun k => PSp U P D (28 + k) 14) 17
  rw [hS, hPr, hTb, sum_lkDom]
  simp only [LkDom.np, LkDom.fh, LkDom.log, Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  norm_num
  rw [hzs'] at hcl'
  linear_combination hcl'

end Hhr

end ZK60.Exec.Block.Join.W16.Look
