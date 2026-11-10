/-
D63 lane L41 (2026-11-10), part 10: **a zero-check's batch, split into its entries** (generic; for the hosts with LogUp
helpers and a pad term: `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`).

L13's builders write a host's batched relation as `logupSem` (LogUp's helper relations, each with its own `μ`), the
pad term `padSem` (`μ_pad·Σ_j ζ^j·(1 − supp)·plane_j`) and `gate·Σ_k μ_k·clause_k`. Lane L36's host polynomial reads
the same batch as `batched c w ω = Σ_κ μ_κ·c_κ + μ_pad·Σ_j ζ^j·w_j` over tables `c`, `w`. This file splits the code's
forms into entry lists:

* `wsum mu k xs = Σ_i mu (k + i)·xs_i`; **`wsum_eq_sum`**: as a sum over `Fin xs.length`;
* `lkRels`: LogUp's helper relations in order (`h·d₁·d₂ − d₁ − d₂`, an odd last `h·d − 1`);
  **`logupSem_eq_wsum`**: `logupSem = wsum μ k lkRels`;
* `padPls`: the pad term's planes in order, each `(1 − supp)·plane`; **`padSem_eq_wsum`**: `padSem = μ_pad·wsum ζ^· j
  padPls` (for standard constants).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotW16BuildSlots

set_option autoImplicit false

namespace ZK60.Exec.Block.Join

open ZK60.Exec.Slot.Build (Cst LkD denV logupSem padSem)
open Finset

section Batch

variable {R : Type} [CommRing R]

/-- **A weighted sum of a list from weight `k` on**: `Σ_i mu (k + i)·xs_i`. -/
def wsum (mu : ℕ → R) : ℕ → List R → R
  | _, [] => 0
  | k, x :: xs => mu k * x + wsum mu (k + 1) xs

theorem wsum_append (mu : ℕ → R) : ∀ (k : ℕ) (xs ys : List R),
    wsum mu k (xs ++ ys) = wsum mu k xs + wsum mu (k + xs.length) ys
  | k, [], ys => by simp [wsum]
  | k, x :: xs, ys => by
    simp only [List.cons_append, wsum, List.length_cons]
    rw [wsum_append mu (k + 1) xs ys, show k + 1 + xs.length = k + (xs.length + 1) by omega]
    ring

/-- **A weighted sum as a sum over the list's positions.** -/
theorem wsum_eq_sum (mu : ℕ → R) : ∀ (k : ℕ) (xs : List R),
    wsum mu k xs = ∑ i : Fin xs.length, mu (k + i) * xs.getD i 0
  | k, [] => by simp [wsum]
  | k, x :: xs => by
    rw [wsum, wsum_eq_sum mu (k + 1) xs, List.length_cons, Fin.sum_univ_succ]
    simp only [Fin.val_zero, add_zero, List.getD_cons_zero, Fin.val_succ, List.getD_cons_succ]
    congr 1
    refine Finset.sum_congr rfl (fun i _ => ?_)
    rw [show k + 1 + (i : ℕ) = k + ((i : ℕ) + 1) by omega]

/-- **LogUp's helper relations in order**: per pair `h·d₁·d₂ − d₁ − d₂`, an odd last `h·d − 1` (`h` the helper at
table `h0 + k`). -/
def lkRels (c : Cst R) (v : List R) (h0 : ℕ) : ℕ → List (LkD R) → List R
  | _, [] => []
  | k, [l] => [c.one * (v.getD (h0 + k) 0 * denV v l) + c.negOne]
  | k, l₁ :: l₂ :: ls => (c.one * (v.getD (h0 + k) 0 * (denV v l₁ * denV v l₂)) + c.negOne * denV v l₁
      + c.negOne * denV v l₂) :: lkRels c v h0 (k + 1) ls

/-- **`logupSem` is the weighted sum of LogUp's helper relations.** -/
theorem logupSem_eq_wsum (c : Cst R) (v : List R) (h0 : ℕ) (mu : ℕ → R) :
    ∀ (k : ℕ) (lks : List (LkD R)), logupSem c v h0 mu k lks = wsum mu k (lkRels c v h0 k lks)
  | _, [] => rfl
  | k, [l] => by simp [logupSem, lkRels, wsum]
  | k, l₁ :: l₂ :: ls => by
    rw [logupSem, lkRels, wsum, logupSem_eq_wsum c v h0 mu (k + 1) ls]

/-- The number of LogUp helpers: one per pair, one for an odd last lookup. -/
theorem lkRels_length (c : Cst R) (v : List R) (h0 : ℕ) :
    ∀ (k : ℕ) (lks : List (LkD R)), (lkRels c v h0 k lks).length = (lks.length + 1) / 2
  | _, [] => by simp [lkRels]
  | _, [_] => by simp [lkRels]
  | k, _ :: _ :: ls => by
    rw [lkRels, List.length_cons, lkRels_length c v h0 (k + 1) ls]
    simp only [List.length_cons]
    omega

/-- **The pad term's planes in order**: per group `(supp, planes)` each plane times `1 − supp`. -/
def padPls (v : List R) : List (ℕ × List ℕ) → List R
  | [] => []
  | (s, ps) :: gs => ps.map (fun p => (1 - v.getD s 0) * v.getD p 0) ++ padPls v gs

theorem zipIdx_wsum (zp : ℕ → R) (f : ℕ → R) (j0 : ℕ) : ∀ (n : ℕ) (ps : List ℕ),
    ((ps.zipIdx n).map fun q => zp (j0 + q.2) * f q.1).sum = wsum zp (j0 + n) (ps.map f)
  | n, [] => by simp [wsum]
  | n, p :: ps => by
    rw [List.zipIdx_cons, List.map_cons, List.sum_cons, zipIdx_wsum zp f j0 (n + 1) ps, List.map_cons, wsum,
      show j0 + (n + 1) = j0 + n + 1 by omega]

theorem wsum_mul (zp : ℕ → R) (a : R) : ∀ (k : ℕ) (xs : List R), wsum zp k (xs.map (a * ·)) = a * wsum zp k xs
  | _, [] => by simp [wsum]
  | k, x :: xs => by
    rw [List.map_cons, wsum, wsum, wsum_mul zp a (k + 1) xs]
    ring

theorem padGroup_wsum (c : Cst R) (hc : c.Std) (v : List R) (zp : ℕ → R) (s j : ℕ) (ps : List ℕ) :
    (c.one + c.negOne * v.getD s 0) * (c.zero + (ps.zipIdx.map fun q => zp (j + q.2) * v.getD q.1 0).sum)
      = wsum zp j (ps.map (fun p => (1 - v.getD s 0) * v.getD p 0)) := by
  rw [hc.one, hc.negOne, hc.zero, zero_add, zipIdx_wsum zp (fun p => v.getD p 0) j 0 ps, Nat.add_zero]
  have e : ps.map (fun p => (1 - v.getD s 0) * v.getD p 0) = (ps.map (fun p => v.getD p 0)).map ((1 - v.getD s 0) * ·) := by
    rw [List.map_map]
    rfl
  rw [e, wsum_mul]
  ring

/-- **`padSem` is `μ_pad` times the weighted sum of the pad planes** (standard constants). -/
theorem padSem_eq_wsum (c : Cst R) (hc : c.Std) (v : List R) (mu : R) (zp : ℕ → R) :
    ∀ (j : ℕ) (gs : List (ℕ × List ℕ)), padSem c v mu zp j gs = mu * wsum zp j (padPls v gs)
  | _, [] => by simp [padSem, padPls, wsum]
  | j, (s, ps) :: gs => by
    rw [padSem, padSem_eq_wsum c hc v mu zp (j + ps.length) gs, padPls, wsum_append, List.length_map,
      padGroup_wsum c hc v zp s j ps]
    ring

end Batch

end ZK60.Exec.Block.Join
