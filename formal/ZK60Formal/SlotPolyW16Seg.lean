/-
D63 lane L23 (2026-11-07), part 12: **the private slots' certified polynomials on their draw vectors** (the parse for
the private kinds, beside `SlotPolyW16Draw.SlotPoly.hostAt` for the hosts).

L11's `draws` and `claimPoint`: `SC_SS`, `SC_SSM`, `SC_QMM`, `SC_SCORE`, `SC_WO`, `SC_GMM`, `SC_DMM` publish their whole
draw vector, in draw order, as their claim point; `SC_KMM`, `SC_VMM`, `SC_UMM` draw only the last block of theirs (the
first is an earlier slot's); `SC_RS` draws its point then `λ`; `SC_QMM` and `SC_GMM` carry the extra layers of finding
L23-2 on their first segment and a block of their second.

* `SlotPoly.privWhole`: a private slot whose claim point is its whole draw vector;
* `SlotPoly.partWhole`: a private slot whose own coordinates are its whole draw vector, after an earlier slot's `r`;
* `rs_last_inj`, `SlotPoly.rsLast`: `SC_RS` with its point first and `λ` last;
* `append_castLE_shift`, `SlotPoly.crossFirst`: the drawing slot's layer on its first `a` coordinates and the first `b`
  of the next `c` (`b ≤ c`: at W16R2 `lkvw ≤ lq` and `lf = lf`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyW16Draw

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

namespace SlotPoly

variable {F : Type} [Field F]

/-- **A private slot whose claim point is its whole draw vector** (`SC_SS`, `SC_SSM`, `SC_QMM`, `SC_SCORE`, `SC_WO`,
`SC_GMM`, `SC_DMM`). -/
def privWhole {D : ℕ} (gh M : (Fin D → Bool) → F) : SlotPoly F D := priv gh M id Function.injective_id

/-- **A private slot whose own coordinates are its whole draw vector, after an earlier slot's `r`** (`SC_KMM`, `SC_VMM`
after `SC_QMM`'s `r_q`; `SC_UMM` after `SC_GMM`'s `r_tf`). -/
def partWhole {a D : ℕ} (Dd : (Fin (a + D) → Bool) → F) (r : Fin a → F) : SlotPoly F D :=
  part Dd r id Function.injective_id

theorem rs_last_inj (n : ℕ) : Function.Injective (Sum.elim (fun _ : Unit => Fin.last n) (Fin.castSucc : Fin n → Fin (n + 1))) :=
  sum_elim_inj _ _ (fun _ _ _ => rfl) (Fin.castSucc_injective n) (fun _ i h => (Fin.castSucc_lt_last i).ne' h)

/-- **`SC_RS`** with its point `p_ht` first and `λ` last (L11's `draws`: `[(p_ht, n), (λ, 1)]`). -/
def rsLast {n : ℕ} (A B : (Fin n → Bool) → F) : SlotPoly F (n + 1) :=
  rs A B (Fin.last n) Fin.castSucc (Fin.castSucc_injective n) (rs_last_inj n)

/-- The first `a` coordinates, then `b` of the next `c` from their start, are the first `a + b` coordinates. -/
theorem append_castLE_shift {a b c : ℕ} (hb : b ≤ c) :
    Fin.append (Fin.castLE (Nat.le_add_right a c)) (fun j : Fin b => (⟨a + j, by omega⟩ : Fin (a + c)))
      = Fin.castLE (Nat.add_le_add_left hb a) := by
  funext x
  induction x using Fin.addCases with
  | left i => ext; simp
  | right j => ext; simp

/-- **The drawing slot's layer** (finding L23-2) on a draw vector `[(r, a), (s, c)]`: `r` and the first `b ≤ c`
coordinates of `s` (`SC_QMM`: `r_q` and `r_j`'s first `lkvw`; `SC_GMM`: `r_tf` and `r_j`). -/
def crossFirst {a b c : ℕ} (Dd : (Fin (a + b) → Bool) → F) (hb : b ≤ c) : SlotPoly F (a + c) :=
  cross Dd (Fin.castLE (Nat.le_add_right a c)) (fun j : Fin b => (⟨a + j, by omega⟩ : Fin (a + c)))
    (by rw [append_castLE_shift hb]; exact Fin.castLE_injective _)

end SlotPoly

end ZK60.Sound.SlotW16
