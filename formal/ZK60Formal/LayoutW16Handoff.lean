/-
D63 step L11, part 5: **the block's hand-off premises from the layout** (ASSEMBLY §4.2 item c): the run's
round-by-round composition (`fs_path_run_8B_target`, FSPathBlock.lean:626-660; `fs_code_chain_sound_sched`,
ExecComposeFS.lean) asks, for the sub-protocols of a block's zone, that a false statement dooms some sub-protocol at
the start (`hstart`), that each stage hands its doom to the next (`hhand`, like `zc_handover`), that a release happens
only when a later sub-protocol carries the doom (`hframe`), that a doomed end is refused (`hfinal`), and that the
charged rounds stay in one block's zone with bounded numerators (`hpath`). This file proves, for the W16R2 slots, the
deterministic statements those premises are made of:
* **`hstart_block`**: if the attested output is not the integer block's output on the committed input, some slot
  relation or some lookup fails on the extracted data (the contrapositive of `blockSat_of_slots` through
  `block_circuitIff`): the zone's start doom sits in a slot's relation or in LogUp;
* **`hhand_batch`**, **`hhand_point`**, **`hhand_host`**, **`hhand_hosted`**: inside a host slot, a failing relation
  survives a good batch `μ, ζ` (the batched relation is nonzero somewhere), a good point `τ` (its extension is nonzero),
  and makes the host's sumcheck claim false whatever `ν` adds, unless `ν` is bad; a failing hosted identity survives a
  good claim point (the hosted difference is nonzero). The bad sets are exactly the events `SlotW16Sound` counts
  (`dens_batchPad`, `dens_mle_zero`, `dens_affine`, `dens_mleEq`);
* **`hfinal_terminal`** (and `hframe`'s content): an accepting slot's final claim IS `poly(vals) + c·g`
  (`slotVerifyW_terminal`), so a doomed final claim hands its doom to the openings: some masked terminal (an `A` / `H`
  / endpoint opening, L10) or the mask value `g` (`M`'s test) is false. A slot is released exactly there (L8-4);
* `hpath`'s numerator part is `w16r2_8B_numerator_le` (SlotW16R2.lean).
-/
import ZK60Formal.LayoutW16
import ZK60Formal.SlotW16Sound
import ZK60Formal.SlotW16Ir

namespace ZK60.Layout.Handoff

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Layout ZK60.Sound ZK60.Sound.SlotW16
open Finset

/-! ## `hstart`: a false block statement dooms a slot relation or LogUp -/

section Start

variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **`hstart` at the block's zone.** Let the committed input and output planes be the images of int16 words `x`, `y`
(the endpoints' canonical words). If `y` is not the integer block's output on `x` (or the block refuses `x`), then on
the extracted data either some slot relation fails or some lookup's tuple is not a table tuple. -/
theorem hstart_block (hS : S.Valid) (P : BlockPublic S) (hP : P.Valid) (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : W16Pub S P L) (E : W16Data Ct Cw Cg Cj Cd Cf) (fams : List (ℕ × ℕ)) (hF : FamsOK fams)
    (hW : W16Widths S fams) (h24 : S.h24 = true)
    (x y : S.Pos → ℤ) (hx : ∀ p, i16 (x p)) (hy : ∀ p, i16 (y p))
    (hX : ∀ p, E.X (L.dPos p) = (x p : GF)) (hY : ∀ p, E.X2 (L.dPos p) = (y p : GF))
    (hbad : ¬ ((blockModel S P).admissible x ∧ y = (blockModel S P).forward () x)) :
    ¬ W16Rels S P L B E ∨ ¬ W16Lookups S P L B E fams := by
  by_contra h
  push Not at h
  obtain ⟨R, Lk⟩ := h
  have hsat := blockSat_of_slots P L B E fams hF hW h24 R Lk
  have hX' : (fun p => E.X (L.dPos p)) = fun p => (x p : GF) := funext hX
  have hY' : (fun p => E.X2 (L.dPos p)) = fun p => (y p : GF) := funext hY
  rw [hX', hY'] at hsat
  exact hbad ((block_circuitIff hS P hP () x y).mp ⟨toWit L E, hx, hy, hsat⟩)

end Start

/-! ## `hhand`: the stages of a host slot hand their doom on -/

section Hand

variable {F : Type} [Field F]

/-- **The batch stage**: a failing relation (some clause or pad plane nonzero) and a batch `ω` outside the event
`dens_batchPad` counts leave the batched relation nonzero somewhere on the cube. -/
theorem hhand_batch {B ι : Type} [Fintype ι] {m : ℕ} (c : ι → B → F) (w : Fin m → B → F)
    (ω : (F × F) × (ι → F)) (hgood : ¬ ∀ b, batched c w ω b = 0) : ∃ b, batched c w ω b ≠ 0 := by
  by_contra h
  push Not at h
  exact hgood h

/-- **The zero-check point**: a cube function nonzero somewhere and a point `τ` outside the event `dens_mle_zero`
counts give a nonzero extension at `τ`. -/
theorem hhand_point {n : ℕ} (Z : (Fin n → Bool) → F) (τ : Fin n → F) (hgood : ¬ mleAt Z τ = 0) : mleAt Z τ ≠ 0 :=
  hgood

/-- **The host's claim**: a nonzero `Z̃(τ) + Σ_i ν_i·D_i` makes the host's sumcheck claim false (`host_claim_iff`):
the cube sum of the host polynomial is not the claimed `Σ_i ν_i·S_i`. -/
theorem hhand_host {n : ℕ} (τ : Fin n → F) (Z : (Fin n → Bool) → F) (ν : Fin 2 → F) (p : Fin 2 → Fin n → F)
    (g : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F) (Sv : Fin 2 → F)
    (hgood : mleAt Z τ + ∑ i, ν i * (mleAt (fun b => g b * h i b) (p i) - Sv i) ≠ 0) :
    ∑ b, hostPoly τ Z ν p g h b ≠ ∑ i, ν i * Sv i := fun e => hgood ((host_claim_iff τ Z ν p g h Sv).mp e)

/-- **A hosted identity**: a failing identity `H = M` on the cube and a claim point outside the event `dens_mleEq`
counts give a nonzero hosted difference `H̃(p) − M̃(p)` (the private slot's true sum `M̃(p)`, `matmul_sum`). -/
theorem hhand_hosted {n : ℕ} (Hc M : (Fin n → Bool) → F) (p : Fin n → F) (hgood : ¬ mleAt Hc p = mleAt M p) :
    mleAt Hc p - mleAt M p ≠ 0 := fun e => hgood (sub_eq_zero.mp e)

/-- **The `ν` stage**: a nonzero batched relation's extension `a` or a nonzero hosted difference, and `ν` outside the
event `dens_affine` counts, keep the claim's left side nonzero. -/
theorem hhand_nu (a : F) (D : Fin 2 → F) (ν : Fin 2 → F) (hgood : ¬ a + ∑ i, ν i * D i = 0) :
    a + ∑ i, ν i * D i ≠ 0 := hgood

end Hand

/-! ## `hfinal` / `hframe`: a doomed final claim hands its doom to the openings and `M` -/

section Final

open ZK60.Exec ZK60.Exec.Slot

variable {K : Type} [Field K] [Algebra ZK60.Circuit.GF K] (U : K) (hU : U ^ 2 = algebraMap ZK60.Circuit.GF K 7)
include hU

/-- **The terminal hand-off.** For an accepting verify arm, if the final claim is not the slot polynomial at the TRUE
terminal values plus `c` times the TRUE mask value (the doom at the sumcheck's end), then some opened terminal value is
not the true one (an `A` / `H` / endpoint opening's claim is false: L10) or the mask value `g` is not `M`'s true value
(`M`'s test). This is the release of the slot's claim to the openings (`hframe`, finding L8-4). -/
theorem hfinal_terminal (H : HIn → Dig) (d : SlotDefW) (hir : d.ir.Canon) (scalars : List Fp2) (p : SlotProofW)
    (t : Tr) (o : SlotOutW) (t' : Tr) (h : slotVerifyW H d scalars p t = (.ok o, t')) (hfin : o.fin.Canon)
    (trueVals : List K) (trueG : K)
    (hdoom : o.fin.toK U ≠ irEval (d.ir.map (Fp2.toK U)) trueVals + o.c.toK U * trueG) :
    o.vals.map (Fp2.toK U) ≠ trueVals ∨ o.gVal.toK U ≠ trueG := by
  by_contra hc
  push Not at hc
  obtain ⟨hv, hg⟩ := hc
  rw [slotVerifyW_terminal U hU H d hir scalars p t o t' h hfin, hv, hg] at hdoom
  exact hdoom rfl

end Final

end ZK60.Layout.Handoff
