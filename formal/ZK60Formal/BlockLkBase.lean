/-
D63 lane L44 (2026-11-10), part 10: **the helper layer at the W16R2 rung, first part** (deliverable 3: lane L36's
premises `spH`, `hdgH`, `hformH`).

* `formAt_congr`: lane L36's `FormAt` at slot `k` reads its polynomial family at `k` only;
* `spHW`: **the helper layer's certified polynomials**: at the six hosts the relation layer's (`algSp … 0`), at the
  other slots of `w16r2RelKs 0` (`SC_LZC` 3, `SC_TAB` 19, `SC_ZS` 20) a family `spX`;
  **`spHW_dg`** (`hdgH` from `algSp_dg` and `spX`'s degrees), **`spHW_formAt`** (`hformH` from the hosts' named
  identities, deliverable 1, and `spX`'s at `3`, `19`, `20`);
* `SC_ZS`: `slot20_eq` (the program's slot `20` at the rung, by evaluation: the all-ones public table and the
  zero-sum row `H_U`, rows `106`, `107` of `H`), **`zs_cube`** (its cube sum is `Σ_b ones(b)·H_U(b)`) and
  **`zs_formAt`** (its standalone named identity: a polynomial whose value is `Σ_b H_U(b)` meets `FormAt` at `20`, for
  a verifier whose slot `20` is standalone and whose public table is the all-ones table).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Lk

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (zsIr zsIr_eval)
open ZK60.Exec.Slot.Compose (zsIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open Finset

/-! ## A named identity reads its polynomial at its own slot -/

section Congr

variable {K : Type} [Field K] [Algebra GF K] (U : K) {P : BlockParams}

/-- **`FormAt` at `k` reads the polynomial family at `k` only.** -/
theorem formAt_congr (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (Φ Φ' : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ)
    (he : ∀ hist x, Φ' k hist x = Φ k hist x) (h : FormAt U P Poly Φ bga rs k) : FormAt U P Poly Φ' bga rs k := by
  intro r df hr hdf
  rw [he]
  exact h r df hr hdf

end Congr

/-! ## The helper layer -/

section Layer

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) {L : ℕ} {P : BlockParams}
  (sh : AlgShape P) (dt : AlgData K L sh) (hcard : 78 < Fintype.card K)

/-- **The helper layer's certified polynomials**: at the six hosts the relation layer's, elsewhere `spX`. -/
noncomputable def spHW (spX : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) :
    Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  fun cu rt k h => if k ∈ algHosts then algSp U sh dt hcard 0 cu rt k h else spX cu rt k h

theorem spHW_host (spX : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) (cu : Cuts3 L) (rt : RootsO)
    (k : ℕ) (h : Hist) (hk : k ∈ algHosts) : spHW U sh dt hcard spX cu rt k h = algSp U sh dt hcard 0 cu rt k h := by
  unfold spHW
  rw [ite_eq_left hk]

theorem spHW_rest (spX : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) (cu : Cuts3 L) (rt : RootsO)
    (k : ℕ) (h : Hist) (hk : k ∉ algHosts) : spHW U sh dt hcard spX cu rt k h = spX cu rt k h := by
  unfold spHW
  rw [ite_eq_right hk]

/-- The helper layer's slots that are not hosts: `SC_LZC`, `SC_TAB`, `SC_ZS`. -/
theorem relKs0_rest (k : ℕ) (hk : k ∈ w16r2RelKs 0) (hh : k ∉ algHosts) : k = 3 ∨ k = 19 ∨ k = 20 := by
  simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk
  simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hh
  omega

/-- **`hdgH`**: every helper-layer polynomial has degree at most `80`. -/
theorem spHW_dg (spX : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hX : ∀ cu rt k h, (k = 3 ∨ k = 19 ∨ k = 20) → (spX cu rt k h).dg ≤ 80) :
    ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spHW U sh dt hcard spX cu rt k h).dg ≤ 80 := by
  intro cu rt k h hk
  by_cases hh : k ∈ algHosts
  · rw [spHW_host U sh dt hcard spX cu rt k h hh]
    exact algSp_dg U sh dt hcard 0 (by norm_num) cu rt k h hk
  · rw [spHW_rest U sh dt hcard spX cu rt k h hh]
    exact hX cu rt k h (relKs0_rest k hk hh)

/-- **`hformH`**: the helper layer's named identities, from the hosts' (deliverable 1) and `spX`'s at `3`, `19`,
`20`. -/
theorem spHW_formAt (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (spX : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) (cu : Cuts3 L) (rt : RootsO)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P Poly (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k)
    (hX : ∀ k, (k = 3 ∨ k = 19 ∨ k = 20) → FormAt U P Poly (fun k h => (spX cu rt k h).Φ) bga rs k) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P Poly (fun k h => (spHW U sh dt hcard spX cu rt k h).Φ) bga rs k := by
  intro k hk
  by_cases hh : k ∈ algHosts
  · exact formAt_congr U Poly _ _ bga rs k
      (fun hist x => by show (spHW U sh dt hcard spX cu rt k hist).Φ x = _; rw [spHW_host U sh dt hcard spX cu rt k hist hh])
      (hhost k hh)
  · exact formAt_congr U Poly _ _ bga rs k
      (fun hist x => by show (spHW U sh dt hcard spX cu rt k hist).Φ x = _; rw [spHW_rest U sh dt hcard spX cu rt k hist hh])
      (hX k (relKs0_rest k hk hh))

end Layer

/-! ## `SC_ZS` -/

/-- `SC_ZS`'s zero-sum row `H_U` at the rung is `H` plane `fh 10 = 45`, rows `106` and `107`. -/
theorem fhU_eq : hOff cfgRungW16 (fh cfgRungW16 10) = (1736704, 1753088) := by decide +kernel

/-- **`SC_ZS` at the rung** (`argument.rs` `SC_ZS`): the all-ones public table on `Dom::Tab` and `H_U`, `ones·u`. -/
theorem slot20_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 20 SlotS.empty
    = ⟨[.pub 0, .priv ⟨.h, [(1736704, false), (1753088, true)], 14, DefW16.rhoC 0 14, 198, 0⟩],
        zsIr DefW16.cstS 0 1, [], []⟩ := rfl

section Zs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_ZS`'s cube sum** (`n = 14`): `Σ_b ones(b)·H_U(b)`; off the zero extension the public table is `0`. -/
theorem zs_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U))
      (([TabS.pub 0, TabS.priv ⟨.h, [(1736704, false), (1753088, true)], 14, DefW16.rhoC 0 14, 198, 0⟩].map
        (TabS.eval (Sym.eval hist 20 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U
      * hPl U P D 1736704 1753088 14 b := by
  subst hn
  have hir : ∀ v : List K, irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * v.getD 1 0 := by
    intro v
    rw [zsIr_map, zsIr_map, cstS_map, zsIr_eval _ (cstW_map_std U)]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, pubT_eval, hTab_eval, List.getD_cons_zero, List.getD_cons_succ]
    rw [tabK_pub_cpt, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  · show f (bpt 14 e b y) = 0
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, pubT_eval, List.getD_cons_zero]
    rw [tabK_pub_off U P D 14 e b y hy, zero_mul]

/-- **`SC_ZS`'s standalone named identity**: a polynomial family whose value at slot `20` is `Σ_b H_U(b)` meets
`FormAt` there, for a verifier whose slot `20` is standalone (the code's `SLOT_KINDS`) and whose slot-`20` public
table is the all-ones table (`argument.rs` `SC_ZS`). -/
theorem zs_formAt (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) (ioIn ioOut : ℕ) (pubs : PubTabs)
    (D : CmData K P) (hrl : 0 < rowLog P .a) (hkind : P.kind 20 = SlotKind.standalone)
    (hones : ∀ hist dr (b : Fin 14 → Bool), ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 20 hist x = ∑ b : Fin 14 → Bool, hPl U P D 1736704 1753088 14 b)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs) Φ bga rs 20 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  have hs20 : slotShape P 20 = (14, 1, 2) := by
    simp only [slotShape, hsl]
    decide
  unfold spSum
  rw [zs_cube U P D hrl (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws
    (pubs 20 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws) (slotShape P 20).1 (slotShape P 20).2.1
    (by rw [hs20]) _ (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 20 r hr x]; simp only [slot20_eq])]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [hones, one_mul]

end Zs

end ZK60.Exec.Block.Join.W16.Lk
