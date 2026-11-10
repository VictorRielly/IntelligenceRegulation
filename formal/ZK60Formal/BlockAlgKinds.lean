/-
D63 lane L36 (2026-11-09), part 2: **the slot kinds' algebra on an outcome** (generic in the block shape): what each
certified slot polynomial of L23 (`SlotPolyW16.lean`) is at a draw vector, and why the layers above the hosts vanish
once the hosts' start claims hold.

* `mleAt_one`, `mleAt_castCube`, `mleAt_rowOnly`, `mleAt_lin2`: the multilinear extension of the constant `1` is `1`;
  of a function read through a relabelling of the cube; of a function of the first block of coordinates only (the
  second block's `eq` sums to `1`: `SC_SZC`'s hosted `SC_RS` term reads the row coordinates only); linearity;
* `append_cast_ite`: a claim point made of two blocks, read coordinate by coordinate;
* `segAt`, **`hostAt_Gd`**, **`hostAt_dg`**, **`hostAt_Φ`**: L23's host polynomial on its draw vector: its start claim
  is `hostGd`, its degree `m + 2`, and at a vector `x` it is `hostPhi` at the segments' entries (`ζ` and `μ_pad` only
  where the slot pads);
* **`hostPhi_of_sums`**: a host's identity is its named sum minus its hosted slots' named sums (the form in which
  L13's `*_eval` and `host_cubeSum` give it);
* **`priv_van`**, **`part_van`**, **`rs_van`**, **`cross_van`**: a private slot's polynomial at its drawn point
  vanishes once its host's hosted difference at that point is `0` (the host's start claim), for the four ways a W16R2
  private slot's claim point is made: its own draws (in any order), an earlier slot's coordinates then its own
  (`SC_KMM`, `SC_VMM`, `SC_UMM`), `SC_RS` (its row point, then `λ`), and the drawing slot's layer of finding L23-2;
* `part_pointwise`: the drawing slot's start claim gives the hosted identity at every cube point.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyW16Seg

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

open Finset
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum segMap hostKeyOf hostKeyNP)

section Kinds

variable {F : Type} [Field F]

/-! ## Multilinear extensions -/

/-- The multilinear extension of the constant `1` is `1` (the `eq` weights of a point sum to `1`). -/
theorem mleAt_one {n : ℕ} (s : Fin n → F) : mleAt (fun _ : Fin n → Bool => (1 : F)) s = 1 := by
  induction n with
  | zero =>
    unfold mleAt
    rw [Fintype.sum_unique]
    simp [eqPoly]
  | succ n ih =>
    rw [← Fin.cons_self_tail s, mleAt_cons, ih]
    ring

/-- A function read through a relabelling of the cube's coordinates. -/
theorem mleAt_castCube {n n' : ℕ} (e : n = n') (f : (Fin n → Bool) → F) (y : Fin n' → F) :
    mleAt (fun z : Fin n' → Bool => f (fun t => z (Fin.cast e t))) y = mleAt f (fun t => y (Fin.cast e t)) := by
  subst e
  rfl

/-- **A function of the first block of coordinates only**: its extension at `(p, s)` is its extension at `p`,
whatever `s` (`SC_SZC`'s hosted `SC_RS` term reads the row coordinates of `Dom::S` only). -/
theorem mleAt_rowOnly {a b : ℕ} (f : (Fin a → Bool) → F) (p : Fin a → F) (s : Fin b → F) :
    mleAt (fun z : Fin (a + b) → Bool => f (fun i => z (Fin.castAdd b i))) (Fin.append p s) = mleAt f p := by
  rw [mleAt_append]
  unfold mle2 mleAt
  refine Finset.sum_congr rfl fun z _ => ?_
  have hz : ∀ j : Fin b → Bool, (fun i => Fin.append z j (Fin.castAdd b i)) = z :=
    fun j => funext fun i => Fin.append_left z j i
  have h1 := mleAt_one (F := F) s
  unfold mleAt at h1
  calc ∑ j : Fin b → Bool, eqPoly p (fun i => bit (z i)) * eqPoly s (fun i => bit (j i))
          * f (fun i => Fin.append z j (Fin.castAdd b i))
      = eqPoly p (fun i => bit (z i)) * f z * ∑ j : Fin b → Bool, eqPoly s (fun i => bit (j i)) * 1 := by
        rw [Finset.mul_sum]
        refine Finset.sum_congr rfl fun j _ => ?_
        rw [hz j]
        ring
    _ = eqPoly p (fun i => bit (z i)) * f z := by rw [h1, mul_one]

/-- Linearity, in the form `SC_RS`'s `λ`-batched pair uses. -/
theorem mleAt_lin2 {n : ℕ} (A B : (Fin n → Bool) → F) (sc lam : F) (p : Fin n → F) :
    mleAt (fun r => sc * (A r + lam * B r)) p = sc * (mleAt A p + lam * mleAt B p) := by
  unfold mleAt
  rw [Finset.mul_sum, ← Finset.sum_add_distrib, Finset.mul_sum]
  exact Finset.sum_congr rfl fun r _ => by ring

omit [Field F] in
/-- **A claim point made of two blocks, read coordinate by coordinate**: the first `a` coordinates from `r`, the rest
from `x`. -/
theorem append_cast_ite {n a D : ℕ} (e : n = a + D) (r : Fin a → F) (x : Fin D → F) (R X : ℕ → F)
    (hR : ∀ i : Fin a, r i = R i) (hX : ∀ i : Fin D, x i = X i) (t : Fin n) :
    Fin.append r x (Fin.cast e t) = if (t : ℕ) < a then R t else X ((t : ℕ) - a) := by
  subst e
  induction t using Fin.addCases with
  | left i => simp [hR]
  | right i => simp [hX]

/-! ## A host on its draw vector -/

/-- The entry at position `i` of segment `g` of a draw vector (`0` past its end). -/
def segAt (l : List (Seg × ℕ)) {D : ℕ} (x : Fin D → F) (g : Seg) (i : ℕ) : F :=
  if h : segOff l g + i < D then x ⟨segOff l g + i, h⟩ else 0

theorem segAt_mk (l : List (Seg × ℕ)) {D : ℕ} (x : Fin D → F) (g : Seg) (i : ℕ) (h : segOff l g + i < D) :
    x ⟨segOff l g + i, h⟩ = segAt l x g i := by
  unfold segAt
  simp only [h, ↓reduceDIte]

variable [Fintype F] [DecidableEq F]

/-- **A host's start claim on its draw vector is `hostGd`** (whether or not it pads). -/
theorem hostAt_Gd (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D) (hnd : (l.map Prod.fst).Nodup) (nc n m : ℕ)
    (hn : segLn l .tau = n) (hmu : segLn l .mu = nc + segLn l .zeta) (hnu : segLn l .nu = 2)
    (hp : segLn l .zeta ≤ 1) (hm0 : segLn l .zeta = 0 → m = 0) (hmF : m < Fintype.card F)
    (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (P : Fin 2 → Fin n → F) :
    (SlotPoly.hostAt l D hD hnd nc n m hn hmu hnu hp hm0 hmF c w h M P).Gd = hostGd c w (fun _ => 1) h M P := by
  unfold SlotPoly.hostAt
  by_cases hp1 : segLn l .zeta = 1
  · simp only [hp1, ↓reduceDIte]
    rfl
  · simp only [hp1, ↓reduceDIte]
    rfl

/-- **A host's degree on its draw vector is `m + 2`**. -/
theorem hostAt_dg (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D) (hnd : (l.map Prod.fst).Nodup) (nc n m : ℕ)
    (hn : segLn l .tau = n) (hmu : segLn l .mu = nc + segLn l .zeta) (hnu : segLn l .nu = 2)
    (hp : segLn l .zeta ≤ 1) (hm0 : segLn l .zeta = 0 → m = 0) (hmF : m < Fintype.card F)
    (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (P : Fin 2 → Fin n → F) :
    (SlotPoly.hostAt l D hD hnd nc n m hn hmu hnu hp hm0 hmF c w h M P).dg = m + 2 := by
  unfold SlotPoly.hostAt
  by_cases hp1 : segLn l .zeta = 1
  · simp only [hp1, ↓reduceDIte]
    rfl
  · simp only [hp1, ↓reduceDIte]
    rfl

/-- **A host's polynomial at a draw vector**: `hostPhi` at the segments' entries; `ζ` and `μ_pad` (the entry of `μ`
after its `nc` batch weights) only where the slot pads. -/
theorem hostAt_Φ (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D) (hnd : (l.map Prod.fst).Nodup) (nc n m : ℕ)
    (hn : segLn l .tau = n) (hmu : segLn l .mu = nc + segLn l .zeta) (hnu : segLn l .nu = 2)
    (hp : segLn l .zeta ≤ 1) (hm0 : segLn l .zeta = 0 → m = 0) (hmF : m < Fintype.card F)
    (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (P : Fin 2 → Fin n → F) (x : Fin D → F) :
    (SlotPoly.hostAt l D hD hnd nc n m hn hmu hnu hp hm0 hmF c w h M P).Φ x
      = hostPhi c w (fun _ => 1) h M P
          ((if segLn l .zeta = 1 then segAt l x .zeta 0 else 0, if segLn l .zeta = 1 then segAt l x .mu nc else 0),
            fun k : Fin nc => segAt l x .mu k)
          (fun t : Fin n => segAt l x .tau t) (fun v : Fin 2 => segAt l x .nu v) := by
  unfold SlotPoly.hostAt
  by_cases hp1 : segLn l .zeta = 1
  · simp only [hp1, ↓reduceDIte, ↓reduceIte]
    show hostPhi c w (fun _ => 1) h M P _ _ _ = _
    simp only [segMap, hostKeyOf, hostKeyNP, segAt_mk l x]
  · simp only [hp1, ↓reduceDIte, ↓reduceIte]
    show hostPhi c w (fun _ => 1) h M P _ _ _ = _
    simp only [segMap, hostKeyOf, hostKeyNP, segAt_mk l x]

omit [Fintype F] [DecidableEq F] in
/-- **A host's identity from named sums**: with the host's unmasked sum `Z̃(τ) + Σ_i ν_i·h̃_i(p_i)` (L13's host form,
`host_cubeSum`) and its hosted slots' weighted sums `Σ_i ν_i·M̃_i(p_i)`, the host's identity is their difference. -/
theorem hostPhi_of_sums {n m : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (ω : (F × F) × (ι → F)) (τ : Fin n → F) (ν : Fin 2 → F) (Sh Sm : F)
    (hH : Sh = mleAt (batched c w ω) τ + ∑ i, ν i * mleAt (h i) (P i))
    (hM : Sm = ∑ i, ν i * mleAt (M i) (P i)) :
    hostPhi c w (fun _ => 1) h M P ω τ ν = Sh - Sm := by
  rw [hostPhi_eq, hH, hM]
  simp only [one_mul, mul_sub, Finset.sum_sub_distrib]
  ring

end Kinds

section Links

variable {F : Type} [Field F]

/-! ## The layers above the hosts -/

/-- **A private slot whose claim point is read off its own draws**: its polynomial at the drawn point vanishes once
its host's hosted difference at that point is `0`. -/
theorem priv_van {n D : ℕ} (h M : (Fin n → Bool) → F) (ip : Fin n → Fin D) (hip : Function.Injective ip)
    (p : Fin n → F) (x : Fin D → F) (hp : p = fun t => x (ip t))
    (hG : mleAt (fun b => (fun _ : Fin n → Bool => (1 : F)) b * h b) p = mleAt M p) :
    (SlotPoly.priv h M ip hip).Φ x = 0 := by
  subst hp
  have e : (fun b => (fun _ : Fin n → Bool => (1 : F)) b * h b) = h := funext fun b => one_mul _
  rw [e] at hG
  show privPhi h M (fun i => x (ip i)) = 0
  unfold privPhi
  rw [hG, sub_self]

/-- **A private slot whose claim point starts with an earlier slot's coordinates `r`** (`SC_KMM`, `SC_VMM`,
`SC_UMM`): likewise, with the host's cube split as `a + D`. -/
theorem part_van {n a D : ℕ} (e : n = a + D) (h M : (Fin n → Bool) → F) (r : Fin a → F) (p : Fin n → F)
    (x : Fin D → F) (hp : p = fun t => Fin.append r x (Fin.cast e t))
    (hG : mleAt (fun b => (fun _ : Fin n → Bool => (1 : F)) b * h b) p = mleAt M p) :
    (SlotPoly.partWhole (fun z : Fin (a + D) → Bool => h (fun t => z (Fin.cast e t)) - M (fun t => z (Fin.cast e t)))
      r).Φ x = 0 := by
  subst hp
  have e1 : (fun b => (fun _ : Fin n → Bool => (1 : F)) b * h b) = h := funext fun b => one_mul _
  rw [e1] at hG
  show mleAt (fun z : Fin (a + D) → Bool => h (fun t => z (Fin.cast e t)) - M (fun t => z (Fin.cast e t)))
    (Fin.append r x) = 0
  rw [← mleAt_sub (fun z : Fin (a + D) → Bool => h (fun t => z (Fin.cast e t)))
    (fun z : Fin (a + D) → Bool => M (fun t => z (Fin.cast e t))), mleAt_castCube e h, mleAt_castCube e M]
  exact sub_eq_zero.mpr hG

/-- **The drawing slot's start claim gives the hosted identity at every cube point** (finding L23-2's layer: its
claim is the difference vanishing on the split cube). -/
theorem part_pointwise {n a D : ℕ} (e : n = a + D) (h M : (Fin n → Bool) → F)
    (hG : ∀ z : Fin (a + D) → Bool, h (fun t => z (Fin.cast e t)) - M (fun t => z (Fin.cast e t)) = 0)
    (b : Fin n → Bool) : h b = M b := by
  subst e
  exact sub_eq_zero.mp (hG b)

/-- **The drawing slot's layer** vanishes once the later slot's partial claim holds at the drawn `r` (L23's
`crossPhi_van` on `crossFirst`). -/
theorem cross_van {a b c : ℕ} (Dd : (Fin (a + b) → Bool) → F) (hb : b ≤ c) (x : Fin (a + c) → F) (r : Fin a → F)
    (hr : r = fun i => x (Fin.castLE (Nat.le_add_right a c) i)) (hG : privPartGd Dd r) :
    (SlotPoly.crossFirst Dd hb).Φ x = 0 := by
  subst hr
  exact crossPhi_van Dd _ _ x hG

/-- **`SC_RS`**: its `λ`-batched row claim at its drawn point and `λ` vanishes once `SC_SZC`'s hosted difference for
it is `0`. `SC_SZC` hosts it on `Dom::S`'s cube (`n = a + b`, rows then columns) with the term
`sc·(A + λ·B)` of the row coordinates (`sc = 2^b`, the code's `per_row`), at the point `(p, s)`. -/
theorem rs_van {n a b : ℕ} (e : n = a + b) (A B : (Fin a → Bool) → F) (sc lam : F) (hsc : sc ≠ 0)
    (p : Fin a → F) (s : Fin b → F) (P0 : Fin n → F) (hP : P0 = fun t => Fin.append p s (Fin.cast e t))
    (x : Fin (a + 1) → F) (hx : (fun i : Fin a => x (Fin.castSucc i)) = p) (hl : x (Fin.last a) = lam)
    (hG : mleAt (fun z : Fin n → Bool => (fun _ : Fin n → Bool => (1 : F)) z
        * (sc * (A (fun i => z (Fin.cast e.symm (Fin.castAdd b i)))
          + lam * B (fun i => z (Fin.cast e.symm (Fin.castAdd b i)))))) P0
      = mleAt (fun _ : Fin n → Bool => (0 : F)) P0) :
    (SlotPoly.rsLast A B).Φ x = 0 := by
  subst hP
  subst e
  have h0 : mleAt (fun _ : Fin (a + b) → Bool => (0 : F)) (fun t => Fin.append p s (Fin.cast rfl t)) = 0 := by
    simp [mleAt]
  rw [h0] at hG
  have h3 : mleAt (fun z : Fin (a + b) → Bool => sc * (A (fun i => z (Fin.castAdd b i))
      + lam * B (fun i => z (Fin.castAdd b i)))) (Fin.append p s) = sc * (mleAt A p + lam * mleAt B p) :=
    (mleAt_rowOnly (fun r : Fin a → Bool => sc * (A r + lam * B r)) p s).trans (mleAt_lin2 A B sc lam p)
  have hf : (fun z : Fin (a + b) → Bool => sc * (A (fun i => z (Fin.castAdd b i))
        + lam * B (fun i => z (Fin.castAdd b i))))
      = fun z : Fin (a + b) → Bool => (fun _ : Fin (a + b) → Bool => (1 : F)) z
        * (sc * (A (fun i => z (Fin.cast rfl (Fin.castAdd b i)))
          + lam * B (fun i => z (Fin.cast rfl (Fin.castAdd b i))))) := by
    funext z
    simp only [one_mul, Fin.cast_eq_self]
  have h4 : mleAt (fun z : Fin (a + b) → Bool => sc * (A (fun i => z (Fin.castAdd b i))
      + lam * B (fun i => z (Fin.castAdd b i)))) (Fin.append p s) = 0 := by
    rw [hf]
    exact hG
  have h5 : sc * (mleAt A p + lam * mleAt B p) = 0 := h3.symm.trans h4
  have h2 : mleAt A p + lam * mleAt B p = 0 := (mul_eq_zero.mp h5).resolve_left hsc
  show rsPhi A B (x (Fin.last a)) (fun i => x (Fin.castSucc i)) = 0
  rw [hl, hx]
  exact h2

end Links

end ZK60.Sound.SlotW16
