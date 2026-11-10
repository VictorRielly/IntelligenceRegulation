/-
D63 lane L44 (2026-11-10), part 11: **`SC_LZC` in the helper layer at the W16R2 rung** (deliverable 3).

* `tabs3`, **`slot3_eq`**: the program's slot `3` at the rung, by evaluation (the `eq` table, the two limb planes, the
  limb helper `H` plane `0`, the support gate of `Dom::L`; L13's `lzcIr` with the limbs' LogUp pair and the pad group);
* **`lzc_vals`**: its value list at a cube point with the zero extension;
* `valsL`, `lksLK`, **`cLzc`** (the limb helper relation, LogUp's pair relation at weight `1`, read without the
  draws), **`wLzc`** (the two pad planes `(1 − supp_L)·limb`);
* **`lzc_cube`**: its cube sum is `Σ_b eq(τ, b)·(cLzc(b) + μ_pad·Σ_j ζ^j·wLzc_j(b))`;
* **`spLzc`**: L23's `SlotPoly.lzc` over these tables (degree `4`); **`lzc_formAt`**: its standalone named identity
  `FormAt` at slot `3`, for a verifier whose slot `3` is standalone and whose slot-`3` public table is the support
  gate `gL` of `Dom::L` (public data).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLkBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Lk

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly lzcPhi lzcPhiR)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (lzcIr lzcIr_eval LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (lzcIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open Finset

/-! ## The slot -/

/-- `SC_LZC`'s plane map to its tables: `limb ↦ 1`, `limbm ↦ 2`. -/
def shapedL (q : ℕ) : ℕ := if q = 6 then 1 else 2

/-- The draws `0 … n − 1` of slot `s`, as expressions. -/
def drL (s n : ℕ) : List Sym := (List.range n).map (Sym.dr s)

/-- `SC_LZC`'s tables at the rung: `eq(τ)`, `A` planes `limb`, `limbm`, `H` plane `0`, `supp(L)`. -/
def tabs3 : List TabS :=
  [.eq (drL 3 14) 0, .priv ⟨.a, [(98304, false)], 14, DefW16.rhoC 0 14, 138, 0⟩,
    .priv ⟨.a, [(114688, false)], 14, DefW16.rhoC 0 14, 140, 0⟩,
    .priv ⟨.h, [(0, false), (16384, true)], 14, DefW16.rhoC 0 14, 108, 0⟩, .pub 0]

/-- `SC_LZC`'s IR at the rung. -/
def ir3 : ZK60.Exec.Slot.Ir Sym :=
  lzcIr DefW16.cstS 0 3 (DefW16.lksS DefW16.cfgRungW16 shapedL .L) (.dr 3 14) (fun j => Sym.pow (.dr 3 15) j)
    [(4, [1, 2])]

/-- **The program's slot `3` at the rung**, by evaluation. -/
theorem slot3_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 3 SlotS.empty = ⟨tabs3, ir3, [], [.dr 3 15]⟩ :=
  rfl

/-- The limb lookups read the planes at table positions `1` and `2`. -/
theorem lksL_pos : ∀ l ∈ DefW16.lksS DefW16.cfgRungW16 shapedL .L, ∀ t ∈ l.terms, t.2 = 1 ∨ t.2 = 2 := by
  decide

theorem lksL_length : (DefW16.lksS DefW16.cfgRungW16 shapedL .L).length = 2 := by
  decide

/-- Mapping a lookup list keeps its terms' positions. -/
theorem lkd_map_pos {α β : Type} (f : α → β) (lks : List (LkD α)) (Pr : ℕ → Prop)
    (h : ∀ l ∈ lks, ∀ t ∈ l.terms, Pr t.2) : ∀ l ∈ lks.map (ZK60.Exec.Slot.Build.LkD.map f), ∀ t ∈ l.terms, Pr t.2 := by
  intro l hl t ht
  obtain ⟨l0, hl0, rfl⟩ := List.mem_map.mp hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.mem_map] at ht
  obtain ⟨t0, ht0, rfl⟩ := ht
  exact h l0 hl0 t0 ht0

/-! ## The value list -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem drL_getD (ev : Sym → Fp2) (s n : ℕ) (a : Fin n) :
    ((drL s n).map ev).getD a Fp2.zero = ev (Sym.dr s a) := by
  unfold drL
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range a.isLt]
  rfl

theorem drL_length (ev : Sym → Fp2) (s n : ℕ) : ((drL s n).map ev).length = n := by
  simp [drL]

/-- **`SC_LZC`'s value list at a cube point with the zero extension** (`n = 14`). -/
theorem lzc_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 14)
    (b : Fin n → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (tabs3.map (TabS.eval ev pub)).map (tabK U P D n e (cpt n e b))
      = [eqPoly (fun a : Fin n => (((drL 3 14).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         aPl U P D 98304 14 (castB hn b), aPl U P D 114688 14 (castB hn b), hPl U P D 0 16384 14 (castB hn b),
         ((pub 0).getD (msbIndex n b) Fp2.zero).toK U] := by
  have hlen : ((drL 3 14).map ev).length = n := by rw [drL_length, hn]
  simp only [tabs3, List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D n e b _ hlen, tabK_pa_cpt U P D hrl n e b 14 (by norm_num) hn,
    tabK_pa_cpt U P D hrl n e b 14 (by norm_num) hn, tabK_ph_cpt U P D hrl n e b 14 (by norm_num) hn,
    tabK_pub_cpt]

/-- **`SC_LZC`'s IR read in the field.** -/
theorem lzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((ir3.map (Sym.eval hist 3 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (logupSem (cstK U) v 3 (fun _ => (cstK U).one) 0
          (((DefW16.lksS DefW16.cfgRungW16 shapedL .L).map
            (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 3 dr))).map (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
        + padSem (cstK U) v ((Sym.eval hist 3 dr (.dr 3 14)).toK U)
          (fun j => (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U) 0 [(4, [1, 2])]) := by
  unfold ir3
  rw [lzcIr_map, lzcIr_map, cstS_map, lzcIr_eval _ (cstW_map_std U)]
  rfl

/-- `SC_LZC`'s value list without the draws: the `eq` entry `0`, the limb planes, the helper, the support gate. -/
noncomputable def valsL (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) :
    List K :=
  [0, aPl U P D 98304 14 b, aPl U P D 114688 14 b, hPl U P D 0 16384 14 b, algebraMap GF K (gL b)]

/-- The limb lookups' words read at `α`, `γ` of `bga = (β, γ, α)`. -/
noncomputable def lksLK (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  ((DefW16.lksS DefW16.cfgRungW16 shapedL .L).map
    (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 3 []))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_LZC`'s helper relation** at a cube point: LogUp's pair relation `h·d₁·d₂ − d₁ − d₂` of the two limb
lookups (weight `1`, L13-2). -/
noncomputable def cLzc (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (bga : Fp2 × Fp2 × Fp2)
    (b : Fin 14 → Bool) : K :=
  logupSem (cstK U) (valsL U P D gL b) 3 (fun _ => (cstK U).one) 0 (lksLK U bga)

/-- **`SC_LZC`'s pad planes**: `(1 − supp_L)·limb`, `(1 − supp_L)·limbm`. -/
noncomputable def wLzc (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (j : Fin 2)
    (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gL b)) * (if (j : ℕ) = 0 then aPl U P D 98304 14 b else aPl U P D 114688 14 b)

end Vals

/-! ## The cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`SC_LZC`'s cube sum**: `Σ_b eq(τ, b)·(cLzc(b) + μ_pad·Σ_j ζ^j·wLzc_j(b))`, with `τ` its first fourteen draws,
`μ_pad` draw `14`, `ζ` draw `15`. -/
theorem lzc_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (gL : (Fin 14 → Bool) → GF)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hgate : ∀ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir3.map (Sym.eval hist 3 dr)).map (Fp2.toK U))
      ((tabs3.map (TabS.eval (Sym.eval hist 3 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (cLzc U P D gL (hist.beta, hist.gamma, hist.alpha) b
        + (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzc U P D gL j b) := by
  subst hn
  -- the lookups read only `α`, `γ`
  have hlks : ((DefW16.lksS DefW16.cfgRungW16 shapedL .L).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 3 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)) = lksLK U (hist.beta, hist.gamma, hist.alpha) := by
    unfold lksLK
    rw [lksS_eval DefW16.cfgRungW16 shapedL .L hist (histOf hist.beta hist.gamma hist.alpha []) 3 3 dr [] rfl rfl]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, lzc_irEval, lzc_vals U P D hrl 14 e rfl b (Sym.eval hist 3 dr) pub, castB_rfl, hlks]
    have hL : logupSem (cstK U) [eqPoly (fun a : Fin 14 => (((drL 3 14).map (Sym.eval hist 3 dr)).getD a Fp2.zero).toK U)
          (fun a => bit (b a)), aPl U P D 98304 14 b, aPl U P D 114688 14 b, hPl U P D 0 16384 14 b,
          ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] 3 (fun _ => (cstK U).one) 0
          (lksLK U (hist.beta, hist.gamma, hist.alpha))
        = cLzc U P D gL (hist.beta, hist.gamma, hist.alpha) b := by
      -- the relation reads only the limb planes and the helper (positions `1`, `2`, `3`), where the two lists agree
      unfold cLzc
      rw [logupSem_eq_wsum, logupSem_eq_wsum]
      congr 1
    have hP : padSem (cstK U) [eqPoly (fun a : Fin 14 => (((drL 3 14).map (Sym.eval hist 3 dr)).getD a Fp2.zero).toK U)
          (fun a => bit (b a)), aPl U P D 98304 14 b, aPl U P D 114688 14 b, hPl U P D 0 16384 14 b,
          ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] ((Sym.eval hist 3 dr (.dr 3 14)).toK U)
          (fun j => (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U) 0 [(4, [1, 2])]
        = (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzc U P D gL j b := by
      rw [padSem_eq_wsum _ (cstW_map_std U)]
      simp only [padPls, List.map_cons, List.map_nil, List.append_nil, wsum, List.getD_cons_zero,
        List.getD_cons_succ, Fin.sum_univ_two, wLzc, Fin.val_zero, Fin.val_one, Fin.isValue, one_ne_zero, ↓reduceIte, add_zero, Nat.zero_add]
      rw [hgate b]
      have h14 : Sym.eval hist 3 dr (.dr 3 14) = dr.getD 14 Fp2.zero := by simp [Sym.eval, drawAt]
      have hz : ∀ j, (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U = ((dr.getD 15 Fp2.zero).toK U) ^ j := by
        intro j
        rw [show Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j) = zpowW (dr.getD 15 Fp2.zero) j by simp [Sym.eval, drawAt],
          toK_zpowW U hU]
      rw [h14, hz 0, hz 1]
    simp only [List.getD_cons_zero]
    rw [hL, hP]
    congr 1
  · show f (bpt 14 e b y) = 0
    rw [hf, lzc_irEval]
    simp only [tabs3, List.map_cons, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end Cube

/-! ## The certified polynomial and its named identity -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)

/-- A draw vector of `SC_LZC` from `τ`, `μ_pad`, `ζ`. -/
def secL (ζ μp : K) (τ : Fin 14 → K) : Fin 16 → K :=
  fun i => if h : (i : ℕ) < 14 then τ ⟨i, h⟩ else if (i : ℕ) = 14 then μp else ζ

include hcard in
/-- **`SC_LZC`'s certified polynomial** (L23's `SlotPoly.lzc`; draws `τ` 0–13, `μ_pad` 14, `ζ` 15): its start claim
is that the limb helper relation and the two pad planes vanish on the cube. -/
noncomputable def spLzc (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) : SlotPoly K (P.draws 3) :=
  SlotPoly.cast (by rw [hdr]; decide)
    (SlotPoly.lzc (n := 14) (m := 2) (D := 16) (cLzc U P D gL (h.beta, h.gamma, h.alpha)) (wLzc U P D gL)
      (fun x => x 15) (fun x => x 14) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 15) (ZK60.Sound.SlotW16.indDeg_coord 14) (Fin.castLE_injective (by norm_num : 14 ≤ 16)) (by omega)
      (fun ζ μp τ _ => ⟨secL ζ μp τ, rfl, funext fun i => by simp [secL]⟩))

theorem spLzc_dg (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) : (spLzc U hcard P hdr D gL h).dg = 4 := rfl

theorem spLzc_Gd (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) :
    (spLzc U hcard P hdr D gL h).Gd = ((∀ b, cLzc U P D gL (h.beta, h.gamma, h.alpha) b = 0)
      ∧ ∀ j b, wLzc U P D gL j b = 0) := rfl

include hcard in
/-- **`SC_LZC`'s standalone named identity** at slot `3`, for a verifier whose slot `3` is standalone (the code's
`SLOT_KINDS`) and whose slot-`3` public table is the support gate `gL` of `Dom::L`. -/
theorem lzc_formAt (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws)
    (hsl : P.geom.slots = W16R2.rungSlots) (ioIn ioOut : ℕ) (pubs : PubTabs) (D : CmData K P)
    (hrl : 0 < rowLog P .a) (hkind : P.kind 3 = SlotKind.standalone) (gL : (Fin 14 → Bool) → GF)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 3 hist x = (spLzc U hcard P hdr D gL hist).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs) Φ bga rs 3 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  have hs3 : slotShape P 3 = (14, 1, 4) := by
    simp only [slotShape, hsl]
    decide
  unfold spSum
  rw [lzc_cube U hU P D hrl gL (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws
    (pubs 3 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws) (hgate _ _) (slotShape P 3).1 (slotShape P 3).2.1
    (by rw [hs3]) _ (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 3 r hr x]; simp only [slot3_eq])]
  rfl

end Poly

end ZK60.Exec.Block.Join.W16.Lk
