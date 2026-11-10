/-
D63 lane L41 (2026-11-10), part 5: **the value list a slot program hands its IR, at the cube points** (generic).

The slot polynomial `polyS` (lane L35) evaluates the slot's IR on the list of its tables' extensions. At a cube point
with the zero extension (`cpt`) this file reads that list entry by entry, for the table kinds the W16R2 program uses:

* `eqPoly_len`: `eq` over two index types of the same length;
* **`tabK_eqFull_cpt`**: an `eq` table whose point has the slot's main length, at `cpt b`, is `eq(point, b)`;
* **`tabK_eqHead_cpt`**: an `eq` table on the first `L` main variables is `eq(point, b[..L])`;
* **`tabK_rho_cpt`**: a private table whose coordinates are its first `log ≤ n` main variables, in order, reads its
  plane at `b[..log]`;
* `TabS.eval` of the program's table builders, unfolded (`pa_eval`, `rhoC_eval`);
* `sum_bool_cast`, `castB`: a sum over the bit vectors of two equal lengths.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinCube
import ZK60Formal.BlockDefineW16

set_option autoImplicit false

namespace ZK60.Exec.Block.Join

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Circuit (gP GF)
open Finset

section Len

variable {K : Type} [Field K]

/-- `eq` over two index types of the same length. -/
theorem eqPoly_len {m n : ℕ} (h : m = n) (f g : ℕ → K) :
    eqPoly (fun a : Fin m => f a) (fun a : Fin m => g a) = eqPoly (fun a : Fin n => f a) (fun a : Fin n => g a) := by
  subst h
  rfl

/-- A bit vector read through an equality of lengths. -/
def castB {m n : ℕ} (h : m = n) (b : Fin m → Bool) : Fin n → Bool := fun i => b (Fin.cast h.symm i)

/-- **A sum over bit vectors of two equal lengths.** -/
theorem sum_bool_cast {M : Type} [AddCommMonoid M] {n m : ℕ} (h : n = m) (F : (Fin n → Bool) → M) :
    ∑ b : Fin n → Bool, F b = ∑ b : Fin m → Bool, F (castB h.symm b) := by
  subst h
  rfl

theorem castB_rfl {n : ℕ} (b : Fin n → Bool) : castB rfl b = b := rfl

theorem castB_castB {m n : ℕ} (h : m = n) (h' : n = m) (b : Fin m → Bool) : castB h' (castB h b) = b := by
  subst h
  rfl

/-- Main variable `a < n` of the cube point. -/
theorem xrK_cpt_fin (n e : ℕ) (b : Fin n → Bool) (a : Fin n) : xrK n (cpt (K := K) n e b) (a : ℕ) = bit (b a) := by
  rw [xrK_cpt, dite_eq_left a.isLt]

end Len

section Tabs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **An `eq` table over all the main variables, at the zero extension.** -/
theorem tabK_eqFull_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (point : List Fp2)
    (hlen : point.length = n) :
    tabK U P D n e (cpt n e b) (.eq point 0)
      = eqPoly (fun a : Fin n => (point.getD a Fp2.zero).toK U) (fun a => bit (b a)) := by
  rw [tabK_eq_cpt]
  rw [eqPoly_len hlen (fun a => (point.getD a Fp2.zero).toK U) (fun a => xrK n (cpt (K := K) n e b) (0 + a))]
  congr 1
  funext a
  rw [Nat.zero_add, xrK_cpt_fin]

/-- **An `eq` table over the first `L` main variables, at the zero extension.** -/
theorem tabK_eqHead_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (point : List Fp2) (L : ℕ)
    (hlen : point.length = L) (hL : L ≤ n) :
    tabK U P D n e (cpt n e b) (.eq point 0)
      = eqPoly (fun a : Fin L => (point.getD a Fp2.zero).toK U) (fun a => bit (b ⟨a, by omega⟩)) := by
  rw [tabK_eq_cpt]
  rw [eqPoly_len hlen (fun a => (point.getD a Fp2.zero).toK U) (fun a => xrK n (cpt (K := K) n e b) (0 + a))]
  congr 1
  funext a
  rw [Nat.zero_add, xrK_cpt, dite_eq_left (by omega)]

/-- The main variables `0 … log − 1` as a private table's coordinates. -/
theorem rhoAll_eq (m : ℕ) : rhoAll m = (List.range' 0 m).map Coord.rho := by
  unfold rhoAll
  rw [List.range_eq_range']

/-- **A private table whose coordinates are its first `log` main variables reads its plane at `b[..log]`.** -/
theorem tabK_rho_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (p : Priv)
    (hsl : p.slices ≠ []) (hlog : 0 < p.log) (hrl : 0 < rowLog P p.cm) (hco : p.coords = rhoAll p.log)
    (hle : p.log ≤ n) :
    tabK U P D n e (cpt n e b) (.priv p)
      = planeZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p (fun a => b ⟨a, by omega⟩) := by
  rw [tabK_priv_cpt U P D n e b p hsl hlog hrl]
  have e1 : (fun a : Fin p.log => ptK U (xrK n (cpt (K := K) n e b)) p.coords a)
      = fun a : Fin p.log => bit (b ⟨a, by omega⟩) := by
    funext a
    rw [hco, ptK_rhoAll, ite_eq_left a.isLt, xrK_cpt, dite_eq_left (by omega)]
  rw [e1, mleAt_bit]

end Tabs

/-! ## The program's table builders, evaluated -/

section Eval

theorem rhoC_eval (ev : Sym → Fp2) (a m : ℕ) :
    (DefW16.rhoC a m).map (CoordS.eval ev) = (List.range' a (m - a)).map Coord.rho := by
  unfold DefW16.rhoC
  rw [List.map_map]
  rfl

/-- **An `A` slice on its own coordinates, evaluated.** -/
theorem aTab_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off log ext m : ℕ) :
    TabS.eval ev pub (.priv ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, ext⟩)
      = .priv ⟨.a, [(off, Fp2.one)], log, rhoAll log, m, ext⟩ := by
  show Tab.priv ⟨.a, [(off, if false then fp2U else Fp2.one)], log, (DefW16.rhoC 0 log).map (CoordS.eval ev), m,
    ext⟩ = _
  rw [rhoC_eval, Nat.sub_zero, ← rhoAll_eq]
  rfl

end Eval

end ZK60.Exec.Block.Join
