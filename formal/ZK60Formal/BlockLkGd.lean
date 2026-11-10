/-
D63 lane L44 (2026-11-10), part 12: **the helper layer at the W16R2 rung assembled** (deliverable 3: lane L36's
`spH`, `hdgH`, `hformH`, `HGd`, `hgdH`).

* `spZs`: `SC_ZS`'s certified polynomial (L23's `SlotPoly.zs` on the zero-sum row `H_U`);
* `spXk`, `spXW`: **the helper layer's polynomials off the hosts**: `SC_LZC` (`spLzc`), `SC_TAB` (a family `spT` read
  at `(β, γ, α)`), `SC_ZS` (`spZs`);
* **`HGdW`**: what the helper layer's start claims say, read at `(β, γ, α)` only: every host's batch (its named clauses
  AND its LogUp, exp and ACT entries, `xc`) and pad planes vanish on its cube; `SC_LZC`'s limb relation and pad
  planes vanish; `SC_TAB`'s start claim; the zero-sum row sums to `0`;
* **`hgd_of`** (`hgdH`): the helper layer's start claims give `HGdW`;
* **`helper_dg`** (`hdgH`), **`helper_formAt`** (`hformH`): from the hosts' named identities (deliverable 1),
  `lzc_formAt`, `zs_formAt`, and `SC_TAB`'s (a named premise).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLkLzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Lk

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF)
open Finset

section Sched

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}

/-- **`SC_ZS`'s certified polynomial** (no draws): its start claim is that the zero-sum row `H_U` sums to `0`. -/
noncomputable def spZs (U : K) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P) :
    SlotPoly K (P.draws 20) :=
  SlotPoly.cast (by rw [hdr]; decide) (SlotPoly.zs (fun b : Fin 14 → Bool => hPl U P D 1736704 1753088 14 b))

/-- **The helper layer's polynomials off the hosts.** -/
noncomputable def spXk (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws)
    (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (spT : Fp2 × Fp2 × Fp2 → SlotPoly K (P.draws 19)) :
    (k : ℕ) → Hist → SlotPoly K (P.draws k)
  | 3, h => spLzc U hcard P hdr D gL h
  | 19, h => spT (h.beta, h.gamma, h.alpha)
  | 20, _ => spZs U P hdr D
  | k, _ => SlotPoly.triv (P.draws k)

/-- The same on the extraction's cuts and roots. -/
noncomputable def spXW (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws)
    (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF)
    (spT : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → SlotPoly K (P.draws 19)) :
    Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  fun cu rt k h => spXk U hcard P hdr (Dof cu rt) gL (spT cu rt) k h

/-- **What the helper layer's start claims say** (read at `bga = (β, γ, α)` only). -/
def HGdW (U : K) (P : BlockParams) (sh : AlgShape P) (dt : AlgData K L sh) (Dof : Cuts3 L → RootsO → CmData K P)
    (gL : (Fin 14 → Bool) → GF) (spT : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → SlotPoly K (P.draws 19))
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) : Prop :=
  (∀ k ∈ algHosts, (∀ κ b, dt.cl k cu rt bga κ b = 0) ∧ ∀ j b, dt.pw k cu rt j b = 0)
  ∧ ((∀ b, cLzc U P (Dof cu rt) gL bga b = 0) ∧ ∀ j b, wLzc U P (Dof cu rt) gL j b = 0)
  ∧ (spT cu rt bga).Gd
  ∧ ∑ b : Fin 14 → Bool, hPl U P (Dof cu rt) 1736704 1753088 14 b = 0

variable (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws)
  (sh : AlgShape P) (dt : AlgData K L sh) (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF)
  (spT : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → SlotPoly K (P.draws 19))

/-- **`hgdH`**: the helper layer's start claims give `HGdW`. -/
theorem hgd_of (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hG : SchedGd (w16r2DH P (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT)) 0) cu rt bga rs) :
    HGdW U P sh dt Dof gL spT cu rt bga := by
  have hR : SchedGd (w16r2DR P (algSp U sh dt hcard) 0) cu rt bga rs := by
    intro k hk
    by_cases hh : k ∈ algHosts
    · show (algSp U sh dt hcard 0 cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Gd
      rw [← spHW_host U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt k _ hh]
      exact hG k hk
    · rcases relKs0_rest k hk hh with rfl | rfl | rfl <;> exact trivial
  refine ⟨fun k hk => ⟨(host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).1,
    (host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).2.1⟩, ?_, ?_, ?_⟩
  · have h3 := hG 3 (show (3 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt 3 _).Gd at h3
    rw [spHW_rest U sh dt hcard _ cu rt 3 _ (by decide)] at h3
    exact h3
  · have h19 := hG 19 (show (19 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt 19 _).Gd at h19
    rw [spHW_rest U sh dt hcard _ cu rt 19 _ (by decide)] at h19
    exact h19
  · have h20 := hG 20 (show (20 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt 20
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20))).Gd at h20
    rw [spHW_rest U sh dt hcard _ cu rt 20 _ (by decide)] at h20
    exact h20

/-- **`hdgH`**: every helper-layer polynomial has degree at most `80` (`SC_LZC` `4`, `SC_ZS` `0`, `SC_TAB` as given). -/
theorem helper_dg (hT : ∀ cu rt bga, (spT cu rt bga).dg ≤ 80) :
    ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt k h).dg ≤ 80 :=
  spHW_dg U sh dt hcard _ (fun cu rt k h hk => by
    rcases hk with rfl | rfl | rfl
    · show (spLzc U hcard P hdr (Dof cu rt) gL h).dg ≤ 80
      rw [spLzc_dg]
      norm_num
    · exact hT cu rt _
    · show (spZs U P hdr (Dof cu rt)).dg ≤ 80
      exact Nat.zero_le 80)

/-- **`hformH`** on an outcome: the helper layer's named identities, from the hosts' (deliverable 1), `SC_LZC`'s and
`SC_ZS`'s (proved here, on the public-data facts `hgate`, `hones` and the slot kinds) and `SC_TAB`'s (`hT`). -/
theorem helper_formAt (hU : U ^ 2 = algebraMap GF K 7) (hsl : P.geom.slots = W16R2.rungSlots) (ioIn ioOut : ℕ)
    (pubs : PubTabs) (hrl : 0 < rowLog P .a)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (hones : ∀ hist dr (b : Fin 14 → Bool), ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P (polyS U P (Dof cu rt) (progW16 cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k)
    (hT : FormAt U P (polyS U P (Dof cu rt) (progW16 cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (spXW U hcard P hdr Dof gL spT cu rt k h).Φ) bga rs 19) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P (polyS U P (Dof cu rt) (progW16 cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (spHW U sh dt hcard (spXW U hcard P hdr Dof gL spT) cu rt k h).Φ) bga rs k :=
  spHW_formAt U sh dt hcard _ _ cu rt bga rs hhost (fun k hk => by
    rcases hk with rfl | rfl | rfl
    · exact lzc_formAt U hcard hU P hdr hsl ioIn ioOut pubs (Dof cu rt) hrl hk3 gL hgate _ (fun _ _ => rfl) bga rs
    · exact hT
    · exact zs_formAt U P hsl ioIn ioOut pubs (Dof cu rt) hrl hk20 hones _ (fun _ _ => rfl) bga rs)

end Sched

end ZK60.Exec.Block.Join.W16.Lk
