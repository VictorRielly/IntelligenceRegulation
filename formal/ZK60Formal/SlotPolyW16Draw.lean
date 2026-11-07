/-
D63 lane L23 (2026-11-07), part 6: **the parse of a W16R2 slot's draw vector** (L11's `draws` / `splitDraws`):
where each segment (`τ`, `μ`, `ν`, `ζ`, `λ`, `μ_pad`, the claim points' coordinates) sits in the vector, that distinct
segments occupy disjoint coordinates, and the certified host polynomial on those coordinates for every W16R2 host at
every shape.

* `segOff`, `segLn`, `segSum`, `segOff_le`, **`segOff_disj`**: a segment's offset and length in a draw list; with
  distinct segment kinds (every W16R2 host at every shape, `w16r2_host_layout`) two segments' coordinates never meet;
* `splitDraws_segOf`: L11's `segOf (splitDraws l xs)` is the vector's `[segOff, segOff + segLn)` slice;
* `segMap`, **`segMap_inj`**: coordinates named by `(segment, position)`, injective;
* `hostKey`, `hostKey_inj`, **`SlotPoly.hostAt`**: a host's `μ` (batch entries, then `μ_pad` where the slot pads), `τ`,
  `ν`, `ζ` on its draw vector, certified (`hostPhiR_deg`, `hostPhiR_nonzero`) from the layout alone;
* `w16r2_host_layout`: the six W16R2 hosts' draws (at EVERY shape) have distinct kinds, `ν` of length `2`, at most one
  `ζ`, and `μ_pad` inside `μ`;
* `shRungW16`, **`rungDraws_eq_w16`**, **`rungSched_eq_w16`**: the W16R2 development rung's shape facts (R13's rung
  `shRungR13` with W16R2's helper counts and range sub-planes), whose draws and schedule by L11's formulas are the ones
  the export counted on the code's transcript (`W16R2.rungDrawList`, `rungSlots`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyW16
import ZK60Formal.SlotR13

set_option autoImplicit false

namespace ZK60.Exec.Slot.W16R2

/-! ## Segments of a draw list -/

/-- A segment's offset in a draw list (the first segment of its kind). -/
def segOff : List (Seg × ℕ) → Seg → ℕ
  | [], _ => 0
  | (g', k) :: l, g => if g' = g then 0 else k + segOff l g

/-- A segment's length (`0` when absent). -/
def segLn : List (Seg × ℕ) → Seg → ℕ
  | [], _ => 0
  | (g', k) :: l, g => if g' = g then k else segLn l g

/-- The draw list's total length. -/
def segSum (l : List (Seg × ℕ)) : ℕ := (l.map Prod.snd).sum

theorem segSum_cons (g : Seg) (k : ℕ) (l : List (Seg × ℕ)) : segSum ((g, k) :: l) = k + segSum l := by
  simp [segSum]

theorem drawLen_eq_segSum (sh : ShapeW) (s : ℕ) : drawLen sh s = segSum (draws sh s) := rfl

theorem segOff_le : ∀ (l : List (Seg × ℕ)) (g : Seg), segOff l g + segLn l g ≤ segSum l
  | [], _ => by simp [segOff, segLn, segSum]
  | (g', k) :: l, g => by
    rw [segSum_cons]
    simp only [segOff, segLn]
    split_ifs
    · omega
    · have := segOff_le l g
      omega

/-- **Distinct segments occupy disjoint coordinates.** -/
theorem segOff_disj : ∀ (l : List (Seg × ℕ)), (l.map Prod.fst).Nodup → ∀ (g1 g2 : Seg), g1 ≠ g2 → ∀ (i j : ℕ),
    i < segLn l g1 → j < segLn l g2 → segOff l g1 + i ≠ segOff l g2 + j
  | [], _, _, _, _, _, _, hi, _ => by simp [segLn] at hi
  | (g', k) :: l, hnd, g1, g2, h12, i, j, hi, hj => by
    simp only [List.map_cons, List.nodup_cons] at hnd
    simp only [segOff, segLn] at hi hj ⊢
    by_cases h1 : g' = g1
    · subst h1
      rw [ite_eq_left rfl] at hi ⊢
      rw [ite_eq_right h12] at hj ⊢
      omega
    · by_cases h2 : g' = g2
      · subst h2
        rw [ite_eq_left rfl] at hj ⊢
        rw [ite_eq_right h1] at hi ⊢
        omega
      · rw [ite_eq_right h1] at hi ⊢
        rw [ite_eq_right h2] at hj ⊢
        have := segOff_disj l hnd.2 g1 g2 h12 i j hi hj
        omega

/-- A segment's length is the segment `splitDraws` hands `segOf`, for a vector of the list's length. -/
theorem splitDraws_segOf : ∀ (l : List (Seg × ℕ)) (xs : List ZK60.Exec.Fp2), (l.map Prod.fst).Nodup →
    xs.length = segSum l → ∀ g, segOf g (splitDraws l xs) = (xs.drop (segOff l g)).take (segLn l g)
  | [], xs, _, _, g => by simp [segOf, splitDraws, segOff, segLn]
  | (g', k) :: l, xs, hnd, hlen, g => by
    rw [segSum_cons] at hlen
    simp only [List.map_cons, List.nodup_cons] at hnd
    by_cases h : g' = g
    · subst h
      simp [splitDraws, segOf, segOff, segLn]
    · have ih := splitDraws_segOf l (xs.drop k) hnd.2 (by simp; omega) g
      unfold segOf at ih
      simp only [splitDraws, segOf, segOff, segLn, ite_eq_right h]
      rw [List.find?_cons_of_neg (p := fun q : Seg × List ZK60.Exec.Fp2 => q.1 == g) (a := (g', xs.take k))
        (by simpa using h), ih, List.drop_drop]

/-! ## Coordinates named by segment -/

/-- **Coordinates named by `(segment, position)`** in a draw vector of the list's length. -/
def segMap {ι : Type} (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D) (κ : ι → Seg × ℕ)
    (hκ : ∀ i, (κ i).2 < segLn l (κ i).1) (i : ι) : Fin D :=
  ⟨segOff l (κ i).1 + (κ i).2, by have := segOff_le l (κ i).1; have := hκ i; omega⟩

theorem segMap_inj {ι : Type} (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D) (κ : ι → Seg × ℕ)
    (hκ : ∀ i, (κ i).2 < segLn l (κ i).1) (hnd : (l.map Prod.fst).Nodup) (hinj : Function.Injective κ) :
    Function.Injective (segMap l D hD κ hκ) := by
  intro i i' h
  have hv : segOff l (κ i).1 + (κ i).2 = segOff l (κ i').1 + (κ i').2 := congrArg Fin.val h
  apply hinj
  by_cases hg : (κ i).1 = (κ i').1
  · rw [hg] at hv
    exact Prod.ext hg (by omega)
  · exact absurd hv (segOff_disj l hnd _ _ hg _ _ (hκ i) (hκ i'))

/-! ## A host's coordinates -/

/-- **A host's draws named**: `μ`'s batch entries `μ_k`, `τ_i`, `ν_i`, and (where it pads) `ζ` and `μ_pad`, the last
entry of `μ`. -/
def hostKeyOf (nc n : ℕ) : (Fin nc ⊕ Fin n ⊕ Fin 2 ⊕ Bool) → Seg × ℕ
  | .inl k => (.mu, k)
  | .inr (.inl i) => (.tau, i)
  | .inr (.inr (.inl i)) => (.nu, i)
  | .inr (.inr (.inr false)) => (.zeta, 0)
  | .inr (.inr (.inr true)) => (.mu, nc)

theorem hostKeyOf_inj (nc n : ℕ) : Function.Injective (hostKeyOf nc n) := by
  intro a b h
  rcases a with k | i | i | _ | _ <;> rcases b with k' | i' | i' | _ | _ <;>
    simp only [hostKeyOf, Prod.mk.injEq, reduceCtorEq, false_and, true_and, Fin.val_inj] at h <;>
    first
    | (subst h; rfl)
    | rfl
    | (exfalso; have := k.isLt; omega)
    | (exfalso; have := k'.isLt; omega)

/-- The named draws without the pad pair (a host that does not pad). -/
def hostKeyNP (nc n : ℕ) : (Fin nc ⊕ Fin n ⊕ Fin 2) → Seg × ℕ := fun i => hostKeyOf nc n (match i with
  | .inl k => .inl k
  | .inr (.inl t) => .inr (.inl t)
  | .inr (.inr v) => .inr (.inr (.inl v)))

theorem hostKeyNP_inj (nc n : ℕ) : Function.Injective (hostKeyNP nc n) := by
  intro a b h
  have := hostKeyOf_inj nc n h
  rcases a with k | i | i <;> rcases b with k' | i' | i' <;> simp_all

/-! ## The six W16R2 hosts' layouts, at every shape -/

/-- **The six W16R2 hosts' draws**, at every shape: distinct segment kinds, `ν` of length `2`, at most one `ζ`, and `μ`
holds the pad weight where the slot pads. -/
theorem w16r2_host_layout (sh : ShapeW) (s : ℕ)
    (hs : s = scTZC ∨ s = scDZC ∨ s = scQZC ∨ s = scKVZC ∨ s = scSZC ∨ s = scFZC) :
    ((draws sh s).map Prod.fst).Nodup ∧ segLn (draws sh s) .nu = 2 ∧ segLn (draws sh s) .zeta ≤ 1
      ∧ segLn (draws sh s) .zeta ≤ segLn (draws sh s) .mu := by
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl <;>
  · refine ⟨?_, ?_, ?_, ?_⟩
    all_goals simp [draws, segLn]
    all_goals (try split_ifs)
    all_goals omega

/-! ## The W16R2 development rung's shape -/

/-- **The W16R2 development rung's shape facts** (`hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2`): the R13 rung's
axis and domain logs and pads (`SlotR13.shRungR13`, the same block geometry), W16R2's helper counts (one LogUp helper per
two looked-up tuples: `L` 1, `D` 10, `Q` 3, `Kv` 3, `S` 5, `F` 4) and its `14` range sub-planes. -/
def shRungW16 : ShapeW := { ZK60.Exec.Slot.R13.shRungR13 with
  nRange := 14
  helpers := fun d => match d with
    | .L => 1 | .D => 10 | .Q => 3 | .Kv => 3 | .S => 5 | .F => 4
    | _ => 0 }

/-- **The rung's draws by L11's formula are the ones the export counted on the code's transcript**
(`ExecBlockFS.lean`'s `W16R2.rungDrawList`). -/
theorem rungDraws_eq_w16 : (List.range nSlots).map (drawLen shRungW16) = ZK60.Exec.Block.W16R2.rungDrawList := by
  decide

/-- **The rung's schedule by `Shape::slots`' formula is the recorded one** (`W16R2.rungSlots`). -/
theorem rungSched_eq_w16 : (List.range nSlots).map (sched shRungW16) = ZK60.Exec.Block.W16R2.rungSlots := by
  decide

/-- Slot by slot: `rungDraws k = drawLen shRungW16 k` for every `k < 23` (and `0` beyond). -/
theorem rungDraws_drawLen (k : ℕ) (hk : k < nSlots) : ZK60.Exec.Block.W16R2.rungDraws k = drawLen shRungW16 k := by
  have h := congrArg (fun l => l.getD k 0) rungDraws_eq_w16
  rw [ZK60.Exec.Block.W16R2.rungDraws, ← h, List.getD_eq_getElem?_getD, List.getElem?_map,
    List.getElem?_range hk]
  rfl

end ZK60.Exec.Slot.W16R2

namespace ZK60.Sound.SlotW16

open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum segMap segMap_inj hostKeyOf hostKeyOf_inj hostKeyNP hostKeyNP_inj)

namespace SlotPoly

variable {F : Type} [Field F]

/-- **A host's certified polynomial on its draw vector** (any draw list with distinct kinds, `ν` of length `2`, at most
one `ζ`, `μ` of length `nc + p`): `μ_k` the first `nc` entries of `μ`, `μ_pad` its last where it pads, `ζ` the `ζ`
segment, `τ` and `ν` their segments; certified from the layout alone (`hostPhiR_deg`, `hostPhiR_nonzero`). -/
def hostAt [Fintype F] [DecidableEq F] (l : List (Seg × ℕ)) (D : ℕ) (hD : segSum l = D)
    (hnd : (l.map Prod.fst).Nodup) (nc n m : ℕ) (hn : segLn l .tau = n) (hmu : segLn l .mu = nc + segLn l .zeta)
    (hnu : segLn l .nu = 2) (hp : segLn l .zeta ≤ 1) (hm0 : segLn l .zeta = 0 → m = 0) (hmF : m < Fintype.card F)
    (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (P : Fin 2 → Fin n → F) : SlotPoly F D :=
  have hκ : ∀ i, (hostKeyNP nc n i).2 < segLn l (hostKeyNP nc n i).1 := by
    intro i
    rcases i with k | t | v
    · show (k : ℕ) < segLn l .mu
      have := k.isLt
      omega
    · show (t : ℕ) < segLn l .tau
      have := t.isLt
      omega
    · show (v : ℕ) < segLn l .nu
      have := v.isLt
      omega
  let σ := segMap l D hD (hostKeyNP nc n) hκ
  have hσ : Function.Injective σ := segMap_inj l D hD _ hκ hnd (hostKeyNP_inj nc n)
  let iμ : Fin nc → Fin D := fun k => σ (.inl k)
  let iτ : Fin n → Fin D := fun t => σ (.inr (.inl t))
  let iν : Fin 2 → Fin D := fun v => σ (.inr (.inr v))
  if hp1 : segLn l .zeta = 1 then
    have hκf : ∀ i, (hostKeyOf nc n i).2 < segLn l (hostKeyOf nc n i).1 := by
      intro i
      rcases i with k | t | v | b
      · show (k : ℕ) < segLn l .mu
        have := k.isLt
        omega
      · show (t : ℕ) < segLn l .tau
        have := t.isLt
        omega
      · show (v : ℕ) < segLn l .nu
        have := v.isLt
        omega
      · cases b
        · show 0 < segLn l .zeta
          omega
        · show nc < segLn l .mu
          omega
    let σf := segMap l D hD (hostKeyOf nc n) hκf
    have hσf : Function.Injective σf := segMap_inj l D hD _ hκf hnd (hostKeyOf_inj nc n)
    host c w h M P (fun x => x (σf (.inr (.inr (.inr false))))) (fun x => x (σf (.inr (.inr (.inr true))))) iμ iτ iν
      (indDeg_coord _) (indDeg_coord _) (fun a b hab => by
        have := hσ hab
        simpa using this) hmF
      (fun ω τ ν _ => by
        obtain ⟨x, hx⟩ := exists_assign σf hσf
          (Sum.elim ω.2 (Sum.elim τ (Sum.elim ν (fun b => if b then ω.1.2 else ω.1.1))))
        refine ⟨x, ?_, ?_, ?_, ?_⟩
        · have h1 := hx (.inr (.inr (.inr false)))
          have h2 := hx (.inr (.inr (.inr true)))
          simp only [Sum.elim_inr] at h1 h2
          simp at h1 h2
          rw [h1, h2]
        · funext k
          have := hx (.inl k)
          simpa [iμ, σ, σf, segMap, hostKeyNP, hostKeyOf] using this
        · funext t
          have := hx (.inr (.inl t))
          simpa [iτ, σ, σf, segMap, hostKeyNP, hostKeyOf] using this
        · funext v
          have := hx (.inr (.inr (.inl v)))
          simpa [iν, σ, σf, segMap, hostKeyNP, hostKeyOf] using this)
  else
    have hp0 : segLn l .zeta = 0 := by omega
    host c w h M P (fun _ => 0) (fun _ => 0) iμ iτ iν (indDeg_const0 1 0) (indDeg_const0 1 0)
      (fun a b hab => by
        have := hσ hab
        simpa using this) hmF
      (fun ω τ ν hω => by
        have hω0 : ω.1 = (0, 0) := by
          rcases hω with hm | hω
          · have := hm0 hp0
            omega
          · exact hω
        obtain ⟨x, hx⟩ := exists_assign σ hσ (Sum.elim ω.2 (Sum.elim τ ν))
        refine ⟨x, by rw [hω0], ?_, ?_, ?_⟩
        · funext k
          exact hx (.inl k)
        · funext t
          exact hx (.inr (.inl t))
        · funext v
          exact hx (.inr (.inr v)))

end SlotPoly

end ZK60.Sound.SlotW16
