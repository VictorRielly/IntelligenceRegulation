/-
D63 lane L69, Milestone A Part 1b (`HonestShieldZKSaltSplit.lean`):
uniform 112-tree leaf-salt indexing (`ShdTreeId`, `ShdLeafId`), exact salt reader (`shdLeafSalt`)
and single-salt updater (`shdCoinsSetLeaf`) on `ShdCoins`, and the three generic combinatorial
theorems discharging ALL 5,359,616 leaf obligations across all 112 trees in `ShdZKCountWitness`:
1. `freshLeafSalt_card` (`hfreshL`: `2^-256` freshness for every leaf `id : ShdLeafId`),
2. `coll_pair_twoLeafSalts_card` (`hpairs` for every pair of distinct leaves `id₁ ≠ id₂`),
3. `cond_freshLeafSalt_card` (`hcond_hid`: conditional `2^-256` freshness for every unopened leaf
   whenever `out` is invariant under `shdCoinsSetLeaf c id d`),
plus non-salt invariance lemmas showing `shdCoinsSetLeaf` leaves every polynomial/mask/pad coin
and every other leaf salt completely untouched.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKCoins

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## 1. Lightweight `Fin`-indexed updater and 112-tree index (`ShdTreeId`, `ShdLeafId`) -/

private def updFin {n : ℕ} {α : Type} (f : Fin n → α) (j : Fin n) (a : α) : Fin n → α :=
  fun i => if i = j then a else f i

private theorem updFin_self {n : ℕ} {α : Type} (f : Fin n → α) (j : Fin n) (a : α) :
    updFin f j a j = a := by
  unfold updFin; rw [ite_eq_left rfl]

private theorem updFin_ne {n : ℕ} {α : Type} (f : Fin n → α) {i j : Fin n} (hne : i ≠ j) (a : α) :
    updFin f j a i = f i := by
  unfold updFin; rw [ite_eq_right hne]

private theorem updFin_eq_self {n : ℕ} {α : Type} (f : Fin n → α) (j : Fin n) :
    updFin f j (f j) = f := by
  funext i; unfold updFin
  by_cases h : i = j
  · subst h; rw [ite_eq_left rfl]
  · rw [ite_eq_right h]

private theorem updFin_idem {n : ℕ} {α : Type} (f : Fin n → α) (j : Fin n) (a₁ a₂ : α) :
    updFin (updFin f j a₁) j a₂ = updFin f j a₂ := by
  funext i; unfold updFin
  by_cases h : i = j
  · rw [ite_eq_left h, ite_eq_left h]
  · rw [ite_eq_right h, ite_eq_right h, ite_eq_right h]

/-- Uniform index over all `112` Merkle trees in a 28-segment Shieldstral T128 R13 run:
`1` input endpoint (`TE`), `27` boundaries (`B_0..26`), `28` `A` trees, `28` `H` trees, `28` `M` trees. -/
inductive ShdTreeId where
  | te
  | bnd (k : Fin 27)
  | a (s : Fin 28)
  | h (s : Fin 28)
  | m (s : Fin 28)
  deriving DecidableEq

/-- Depth of segment `s`'s `A` and `H` Merkle trees (`14` for stages IN-C/OUT-C, `16` for 26 R13 blocks). -/
def shdAHDepth (s : Fin 28) : ℕ :=
  if s.val = 0 then 14 else if s.val = 27 then 14 else 16

/-- Depth of Merkle tree `t : ShdTreeId` (`11`, `16`, `14/16`, `14/16`, `12`). -/
def shdTreeDepthOf : ShdTreeId → ℕ
  | .te => 11
  | .bnd _ => 16
  | .a s => shdAHDepth s
  | .h s => shdAHDepth s
  | .m _ => 12

/-- Global leaf index `(t, j)` across all `5,359,616` leaves of all `112` Merkle trees. -/
abbrev ShdLeafId : Type := Σ t : ShdTreeId, Fin (2 ^ shdTreeDepthOf t)

theorem shdL1_ah_A_salt_eq (s : Fin 28) :
    (shdP_L1Spec.ah s).A.Salt = (Fin (2 ^ shdAHDepth s) → Dig) := by
  dsimp only [shdP_L1Spec, shdAHDepth]
  by_cases h0 : s.val = 0
  · rw [ite_eq_left h0, ite_eq_left h0]; rfl
  · rw [ite_eq_right h0, ite_eq_right h0]
    by_cases h27 : s.val = 27
    · rw [ite_eq_left h27, ite_eq_left h27]; rfl
    · rw [ite_eq_right h27, ite_eq_right h27]; rfl

theorem shdL1_ah_H_salt_eq (s : Fin 28) :
    (shdP_L1Spec.ah s).H.Salt = (Fin (2 ^ shdAHDepth s) → Dig) := by
  dsimp only [shdP_L1Spec, shdAHDepth]
  by_cases h0 : s.val = 0
  · rw [ite_eq_left h0, ite_eq_left h0]; rfl
  · rw [ite_eq_right h0, ite_eq_right h0]
    by_cases h27 : s.val = 27
    · rw [ite_eq_left h27, ite_eq_left h27]; rfl
    · rw [ite_eq_right h27, ite_eq_right h27]; rfl

/-- Definitional cast equivalence for segment `s`'s `A`-tree salt vector. -/
def shdAHCastA (s : Fin 28) : (shdP_L1Spec.ah s).A.Salt ≃ (Fin (2 ^ shdAHDepth s) → Dig) :=
  Equiv.cast (shdL1_ah_A_salt_eq s)

/-- Definitional cast equivalence for segment `s`'s `H`-tree salt vector. -/
def shdAHCastH (s : Fin 28) : (shdP_L1Spec.ah s).H.Salt ≃ (Fin (2 ^ shdAHDepth s) → Dig) :=
  Equiv.cast (shdL1_ah_H_salt_eq s)

/-! ## 2. Global salt reader (`shdLeafSalt`) and single-salt updater (`shdCoinsSetLeaf`) -/

/-- Read the unique uniform leaf salt of `(t, j) : ShdLeafId` from `c : ShdCoins`. -/
def shdLeafSalt (c : ShdCoins) : ShdLeafId → Dig
  | ⟨.te, j⟩ => c.1.1.2 j
  | ⟨.bnd k, j⟩ => (c.1.2.1 k).2 j
  | ⟨.a s, j⟩ => shdAHCastA s (c.1.2.2 s).2.1 j
  | ⟨.h s, j⟩ => shdAHCastH s (c.1.2.2 s).2.2 j
  | ⟨.m s, j⟩ => (c.2 s).2 j

/-- Overwrite ONLY leaf salt `id : ShdLeafId` in `c : ShdCoins` with `d : Dig`, leaving every
polynomial/mask/pad coin and every other leaf salt untouched. -/
def shdCoinsSetLeaf (c : ShdCoins) (id : ShdLeafId) (d : Dig) : ShdCoins :=
  match id with
  | ⟨.te, j⟩ =>
      (((c.1.1.1, updFin c.1.1.2 j d), c.1.2.1, c.1.2.2), c.2)
  | ⟨.bnd k, j⟩ =>
      ((c.1.1,
        fun k' =>
          if hk : k = k' then
            hk ▸ ((c.1.2.1 k).1, updFin (c.1.2.1 k).2 j d)
          else c.1.2.1 k',
        c.1.2.2), c.2)
  | ⟨.a s, j⟩ =>
      ((c.1.1, c.1.2.1,
        fun s' =>
          if hs : s = s' then
            hs ▸ ((c.1.2.2 s).1, ((shdAHCastA s).symm (updFin (shdAHCastA s (c.1.2.2 s).2.1) j d), (c.1.2.2 s).2.2))
          else c.1.2.2 s'), c.2)
  | ⟨.h s, j⟩ =>
      ((c.1.1, c.1.2.1,
        fun s' =>
          if hs : s = s' then
            hs ▸ ((c.1.2.2 s).1, ((c.1.2.2 s).2.1, (shdAHCastH s).symm (updFin (shdAHCastH s (c.1.2.2 s).2.2) j d)))
          else c.1.2.2 s'), c.2)
  | ⟨.m s, j⟩ =>
      (c.1,
        fun s' =>
          if hs : s = s' then
            hs ▸ ((c.2 s).1, updFin (c.2 s).2 j d)
          else c.2 s')

theorem shdLeafSalt_setLeaf_self (c : ShdCoins) (id : ShdLeafId) (d : Dig) :
    shdLeafSalt (shdCoinsSetLeaf c id d) id = d := by
  rcases id with ⟨t, j⟩
  cases t with
  | te => exact updFin_self c.1.1.2 j d
  | bnd k =>
    change (if hk : k = k then hk ▸ ((c.1.2.1 k).1, updFin (c.1.2.1 k).2 j d) else c.1.2.1 k).2 j = d
    rw [dite_eq_left rfl]; exact updFin_self _ j d
  | a s =>
    change shdAHCastA s (if hs : s = s then
      hs ▸ ((c.1.2.2 s).1, ((shdAHCastA s).symm (updFin (shdAHCastA s (c.1.2.2 s).2.1) j d), (c.1.2.2 s).2.2))
      else c.1.2.2 s).2.1 j = d
    rw [dite_eq_left rfl, Equiv.apply_symm_apply]; exact updFin_self _ j d
  | h s =>
    change shdAHCastH s (if hs : s = s then
      hs ▸ ((c.1.2.2 s).1, ((c.1.2.2 s).2.1, (shdAHCastH s).symm (updFin (shdAHCastH s (c.1.2.2 s).2.2) j d)))
      else c.1.2.2 s).2.2 j = d
    rw [dite_eq_left rfl, Equiv.apply_symm_apply]; exact updFin_self _ j d
  | m s =>
    change (if hs : s = s then hs ▸ ((c.2 s).1, updFin (c.2 s).2 j d) else c.2 s).2 j = d
    rw [dite_eq_left rfl]; exact updFin_self _ j d

theorem shdLeafSalt_setLeaf_ne (c : ShdCoins) {id₁ id₂ : ShdLeafId} (hne : id₁ ≠ id₂) (d : Dig) :
    shdLeafSalt (shdCoinsSetLeaf c id₂ d) id₁ = shdLeafSalt c id₁ := by
  rcases id₁ with ⟨t₁, j₁⟩
  rcases id₂ with ⟨t₂, j₂⟩
  cases t₁ <;> cases t₂
  · have hj : j₁ ≠ j₂ := fun h => hne (by subst h; rfl)
    exact updFin_ne c.1.1.2 hj d
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rename_i k₁ k₂
    change (if hk : k₂ = k₁ then hk ▸ ((c.1.2.1 k₂).1, updFin (c.1.2.1 k₂).2 j₂ d) else c.1.2.1 k₁).2 j₁ = (c.1.2.1 k₁).2 j₁
    by_cases hk : k₂ = k₁
    · subst hk
      have hj : j₁ ≠ j₂ := fun h => hne (by subst h; rfl)
      rw [dite_eq_left rfl]; exact updFin_ne _ hj d
    · rw [dite_eq_right hk]
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rename_i s₁ s₂
    change shdAHCastA s₁ (if hs : s₂ = s₁ then
      hs ▸ ((c.1.2.2 s₂).1, ((shdAHCastA s₂).symm (updFin (shdAHCastA s₂ (c.1.2.2 s₂).2.1) j₂ d), (c.1.2.2 s₂).2.2))
      else c.1.2.2 s₁).2.1 j₁ = shdAHCastA s₁ (c.1.2.2 s₁).2.1 j₁
    by_cases hs : s₂ = s₁
    · subst hs
      have hj : j₁ ≠ j₂ := fun h => hne (by subst h; rfl)
      rw [dite_eq_left rfl, Equiv.apply_symm_apply]; exact updFin_ne _ hj d
    · rw [dite_eq_right hs]
  · rename_i s₁ s₂
    change shdAHCastA s₁ (if hs : s₂ = s₁ then
      hs ▸ ((c.1.2.2 s₂).1, ((c.1.2.2 s₂).2.1, (shdAHCastH s₂).symm (updFin (shdAHCastH s₂ (c.1.2.2 s₂).2.2) j₂ d)))
      else c.1.2.2 s₁).2.1 j₁ = shdAHCastA s₁ (c.1.2.2 s₁).2.1 j₁
    by_cases hs : s₂ = s₁
    · subst hs; rw [dite_eq_left rfl]
    · rw [dite_eq_right hs]
  · rfl
  · rfl
  · rfl
  · rename_i s₁ s₂
    change shdAHCastH s₁ (if hs : s₂ = s₁ then
      hs ▸ ((c.1.2.2 s₂).1, ((shdAHCastA s₂).symm (updFin (shdAHCastA s₂ (c.1.2.2 s₂).2.1) j₂ d), (c.1.2.2 s₂).2.2))
      else c.1.2.2 s₁).2.2 j₁ = shdAHCastH s₁ (c.1.2.2 s₁).2.2 j₁
    by_cases hs : s₂ = s₁
    · subst hs; rw [dite_eq_left rfl]
    · rw [dite_eq_right hs]
  · rename_i s₁ s₂
    change shdAHCastH s₁ (if hs : s₂ = s₁ then
      hs ▸ ((c.1.2.2 s₂).1, ((c.1.2.2 s₂).2.1, (shdAHCastH s₂).symm (updFin (shdAHCastH s₂ (c.1.2.2 s₂).2.2) j₂ d)))
      else c.1.2.2 s₁).2.2 j₁ = shdAHCastH s₁ (c.1.2.2 s₁).2.2 j₁
    by_cases hs : s₂ = s₁
    · subst hs
      have hj : j₁ ≠ j₂ := fun h => hne (by subst h; rfl)
      rw [dite_eq_left rfl, Equiv.apply_symm_apply]; exact updFin_ne _ hj d
    · rw [dite_eq_right hs]
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rename_i s₁ s₂
    change (if hs : s₂ = s₁ then hs ▸ ((c.2 s₂).1, updFin (c.2 s₂).2 j₂ d) else c.2 s₁).2 j₁ = (c.2 s₁).2 j₁
    by_cases hs : s₂ = s₁
    · subst hs
      have hj : j₁ ≠ j₂ := fun h => hne (by subst h; rfl)
      rw [dite_eq_left rfl]; exact updFin_ne _ hj d
    · rw [dite_eq_right hs]

theorem shdCoinsSetLeaf_self (c : ShdCoins) (id : ShdLeafId) :
    shdCoinsSetLeaf c id (shdLeafSalt c id) = c := by
  rcases c with ⟨⟨⟨te1, te2⟩, bnd, ah⟩, l2⟩
  rcases id with ⟨t, j⟩
  cases t with
  | te =>
    refine Prod.ext (Prod.ext (Prod.ext rfl ?_) rfl) rfl
    exact updFin_eq_self te2 j
  | bnd k =>
    refine Prod.ext (Prod.ext rfl (Prod.ext ?_ rfl)) rfl
    funext k'
    change (if hk : k = k' then hk ▸ ((bnd k).1, updFin (bnd k).2 j ((bnd k).2 j)) else bnd k') = bnd k'
    by_cases hk : k = k'
    · subst hk; rw [dite_eq_left rfl]; exact Prod.ext rfl (updFin_eq_self (bnd k).2 j)
    · rw [dite_eq_right hk]
  | a s =>
    refine Prod.ext (Prod.ext rfl (Prod.ext rfl ?_)) rfl
    funext s'
    change (if hs : s = s' then
      hs ▸ ((ah s).1, ((shdAHCastA s).symm (updFin (shdAHCastA s (ah s).2.1) j (shdAHCastA s (ah s).2.1 j)), (ah s).2.2))
      else ah s') = ah s'
    by_cases hs : s = s'
    · subst hs; rw [dite_eq_left rfl]
      refine Prod.ext rfl (Prod.ext ?_ rfl)
      have h : updFin (shdAHCastA s (ah s).2.1) j (shdAHCastA s (ah s).2.1 j) = shdAHCastA s (ah s).2.1 :=
        updFin_eq_self (shdAHCastA s (ah s).2.1) j
      rw [h, Equiv.symm_apply_apply]
    · rw [dite_eq_right hs]
  | h s =>
    refine Prod.ext (Prod.ext rfl (Prod.ext rfl ?_)) rfl
    funext s'
    change (if hs : s = s' then
      hs ▸ ((ah s).1, ((ah s).2.1, (shdAHCastH s).symm (updFin (shdAHCastH s (ah s).2.2) j (shdAHCastH s (ah s).2.2 j))))
      else ah s') = ah s'
    by_cases hs : s = s'
    · subst hs; rw [dite_eq_left rfl]
      refine Prod.ext rfl (Prod.ext rfl ?_)
      have h : updFin (shdAHCastH s (ah s).2.2) j (shdAHCastH s (ah s).2.2 j) = shdAHCastH s (ah s).2.2 :=
        updFin_eq_self (shdAHCastH s (ah s).2.2) j
      rw [h, Equiv.symm_apply_apply]
    · rw [dite_eq_right hs]
  | m s =>
    refine Prod.ext rfl ?_
    funext s'
    change (if hs : s = s' then hs ▸ ((l2 s).1, updFin (l2 s).2 j ((l2 s).2 j)) else l2 s') = l2 s'
    by_cases hs : s = s'
    · subst hs; rw [dite_eq_left rfl]; exact Prod.ext rfl (updFin_eq_self (l2 s).2 j)
    · rw [dite_eq_right hs]

theorem shdCoinsSetLeaf_idem (c : ShdCoins) (id : ShdLeafId) (d₁ d₂ : Dig) :
    shdCoinsSetLeaf (shdCoinsSetLeaf c id d₁) id d₂ = shdCoinsSetLeaf c id d₂ := by
  rcases c with ⟨⟨⟨te1, te2⟩, bnd, ah⟩, l2⟩
  rcases id with ⟨t, j⟩
  cases t with
  | te =>
    refine Prod.ext (Prod.ext (Prod.ext rfl ?_) rfl) rfl
    exact updFin_idem te2 j d₁ d₂
  | bnd k =>
    refine Prod.ext (Prod.ext rfl (Prod.ext ?_ rfl)) rfl
    funext k'
    dsimp only [shdCoinsSetLeaf]
    by_cases hk : k = k'
    · subst hk
      rw [dite_eq_left rfl, dite_eq_left rfl, dite_eq_left rfl]
      exact Prod.ext rfl (updFin_idem (bnd k).2 j d₁ d₂)
    · rw [dite_eq_right hk, dite_eq_right hk, dite_eq_right hk]
  | a s =>
    refine Prod.ext (Prod.ext rfl (Prod.ext rfl ?_)) rfl
    funext s'
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s = s'
    · subst hs
      rw [dite_eq_left rfl, dite_eq_left rfl, dite_eq_left rfl, Equiv.apply_symm_apply]
      refine Prod.ext rfl (Prod.ext ?_ rfl)
      exact congrArg (shdAHCastA s).symm (updFin_idem (shdAHCastA s (ah s).2.1) j d₁ d₂)
    · rw [dite_eq_right hs, dite_eq_right hs, dite_eq_right hs]
  | h s =>
    refine Prod.ext (Prod.ext rfl (Prod.ext rfl ?_)) rfl
    funext s'
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s = s'
    · subst hs
      rw [dite_eq_left rfl, dite_eq_left rfl, dite_eq_left rfl, Equiv.apply_symm_apply]
      refine Prod.ext rfl (Prod.ext rfl ?_)
      exact congrArg (shdAHCastH s).symm (updFin_idem (shdAHCastH s (ah s).2.2) j d₁ d₂)
    · rw [dite_eq_right hs, dite_eq_right hs, dite_eq_right hs]
  | m s =>
    refine Prod.ext rfl ?_
    funext s'
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s = s'
    · subst hs
      rw [dite_eq_left rfl, dite_eq_left rfl, dite_eq_left rfl]
      exact Prod.ext rfl (updFin_idem (l2 s).2 j d₁ d₂)
    · rw [dite_eq_right hs, dite_eq_right hs, dite_eq_right hs]

/-! ## 3. Non-salt invariance under `shdCoinsSetLeaf` -/

theorem shdCoinsSetLeaf_te_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) :
    (shdCoinsSetLeaf c id d).1.1.1 = c.1.1.1 := by
  rcases id with ⟨t, j⟩; cases t <;> rfl

theorem shdCoinsSetLeaf_bnd_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) (k : Fin 27) :
    ((shdCoinsSetLeaf c id d).1.2.1 k).1 = (c.1.2.1 k).1 := by
  rcases id with ⟨t, j⟩
  cases t with
  | bnd k₀ =>
    dsimp only [shdCoinsSetLeaf]
    by_cases hk : k₀ = k
    · subst hk; rw [dite_eq_left rfl]
    · rw [dite_eq_right hk]
  | _ => rfl

theorem shdCoinsSetLeaf_ah_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) (s : Fin 28) :
    ((shdCoinsSetLeaf c id d).1.2.2 s).1 = (c.1.2.2 s).1 := by
  rcases id with ⟨t, j⟩
  cases t with
  | a s₀ =>
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s₀ = s
    · subst hs; rw [dite_eq_left rfl]
    · rw [dite_eq_right hs]
  | h s₀ =>
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s₀ = s
    · subst hs; rw [dite_eq_left rfl]
    · rw [dite_eq_right hs]
  | _ => rfl

theorem shdCoinsSetLeaf_l2_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) (s : Fin 28) :
    ((shdCoinsSetLeaf c id d).2 s).1 = (c.2 s).1 := by
  rcases id with ⟨t, j⟩
  cases t with
  | m s₀ =>
    dsimp only [shdCoinsSetLeaf]
    by_cases hs : s₀ = s
    · subst hs; rw [dite_eq_left rfl]
    · rw [dite_eq_right hs]
  | _ => rfl

/-! ## 4. Generic coordinate-splitting bounds (avoiding deep `ShdCoins` unfolding in `Finset`) -/

section AbstractCoordBounds

open Classical in
private theorem freshCoord_card {C Id Q : Type} [Fintype C] [DecidableEq Q] {k : ℕ}
    (rd : C → Id → Dig) (upd : C → Id → Dig → C)
    (hrd_self : ∀ c id d, rd (upd c id d) id = d)
    (hupd_self : ∀ c id, upd c id (rd c id) = c)
    (hupd_idem : ∀ c id d₁ d₂, upd (upd c id d₁) id d₂ = upd c id d₂)
    (P : C × (Fin k → Dig) → Q) (id : Id) (g : Q → Dig)
    (hg : ∀ s, g (P s) = rd s.1 id) (z : Q) :
    2 ^ 256 * (univ.filter (fun s : C × (Fin k → Dig) => P s = z)).card
      ≤ Fintype.card (C × (Fin k → Dig)) := by
  let f : Dig × {s : C × (Fin k → Dig) // P s = z} → C × (Fin k → Dig) :=
    fun p => (upd p.2.1.1 id p.1, p.2.1.2)
  have hf : Function.Injective f := by
    intro p p' heq
    have hc : upd p.2.1.1 id p.1 = upd p'.2.1.1 id p'.1 := (Prod.mk.inj heq).1
    have hv : p.2.1.2 = p'.2.1.2 := (Prod.mk.inj heq).2
    have hd : p.1 = p'.1 := by
      have h := congrArg (fun c => rd c id) hc
      rwa [hrd_self, hrd_self] at h
    have hs1 : rd p.2.1.1 id = g z := by rw [← hg p.2.1, p.2.2]
    have hs2 : rd p'.2.1.1 id = g z := by rw [← hg p'.2.1, p'.2.2]
    have hc' : p.2.1.1 = p'.2.1.1 := by
      calc p.2.1.1 = upd p.2.1.1 id (rd p.2.1.1 id) := (hupd_self p.2.1.1 id).symm
        _ = upd (upd p.2.1.1 id p.1) id (g z) := by rw [hs1, hupd_idem]
        _ = upd (upd p'.2.1.1 id p'.1) id (g z) := by rw [hc]
        _ = upd p'.2.1.1 id (rd p'.2.1.1 id) := by rw [hupd_idem, hs2]
        _ = p'.2.1.1 := hupd_self p'.2.1.1 id
    exact Prod.ext hd (Subtype.ext (Prod.ext hc' hv))
  have hle := Fintype.card_le_of_injective f hf
  rw [Fintype.card_prod, card_dig_eq, Fintype.card_subtype] at hle
  simpa [Finset.filter_congr_decidable] using hle

open Classical in
private theorem coll_pair_twoCoords_card {C Id Q : Type} [Fintype C] [DecidableEq Q] {k : ℕ}
    (rd : C → Id → Dig) (upd : C → Id → Dig → C)
    (hrd_self : ∀ c id d, rd (upd c id d) id = d)
    (hrd_ne : ∀ c {id₁ id₂}, id₁ ≠ id₂ → ∀ d, rd (upd c id₂ d) id₁ = rd c id₁)
    (hupd_self : ∀ c id, upd c id (rd c id) = c)
    (hupd_idem : ∀ c id d₁ d₂, upd (upd c id d₁) id d₂ = upd c id d₂)
    (pts : C × (Fin k → Dig) → Fin k → Q) {i j : Fin k} {id₁ id₂ : Id} (hne : id₁ ≠ id₂)
    (g : Q → Dig) (hg₁ : ∀ s, g (pts s i) = rd s.1 id₁) (hg₂ : ∀ s, g (pts s j) = rd s.1 id₂) :
    2 ^ 256 * (univ.filter (fun s : C × (Fin k → Dig) => pts s i = pts s j)).card
      ≤ Fintype.card (C × (Fin k → Dig)) := by
  let f : Dig × {s : C × (Fin k → Dig) // pts s i = pts s j} → C × (Fin k → Dig) :=
    fun p => (upd p.2.1.1 id₂ p.1, p.2.1.2)
  have hf : Function.Injective f := by
    intro p p' heq
    have hc : upd p.2.1.1 id₂ p.1 = upd p'.2.1.1 id₂ p'.1 := (Prod.mk.inj heq).1
    have hv : p.2.1.2 = p'.2.1.2 := (Prod.mk.inj heq).2
    have hd : p.1 = p'.1 := by
      have h := congrArg (fun c => rd c id₂) hc
      rwa [hrd_self, hrd_self] at h
    have hs1 : rd p.2.1.1 id₁ = rd p'.2.1.1 id₁ := by
      have h := congrArg (fun c => rd c id₁) hc
      rwa [hrd_ne _ hne, hrd_ne _ hne] at h
    have hs2p : rd p.2.1.1 id₂ = rd p.2.1.1 id₁ := by rw [← hg₂ p.2.1, ← hg₁ p.2.1, p.2.2]
    have hs2p' : rd p'.2.1.1 id₂ = rd p'.2.1.1 id₁ := by rw [← hg₂ p'.2.1, ← hg₁ p'.2.1, p'.2.2]
    have hc' : p.2.1.1 = p'.2.1.1 := by
      calc p.2.1.1 = upd p.2.1.1 id₂ (rd p.2.1.1 id₂) := (hupd_self p.2.1.1 id₂).symm
        _ = upd (upd p.2.1.1 id₂ p.1) id₂ (rd p.2.1.1 id₁) := by rw [hs2p, hupd_idem]
        _ = upd (upd p'.2.1.1 id₂ p'.1) id₂ (rd p'.2.1.1 id₁) := by rw [hc, hs1]
        _ = upd p'.2.1.1 id₂ (rd p'.2.1.1 id₂) := by rw [hupd_idem, hs2p']
        _ = p'.2.1.1 := hupd_self p'.2.1.1 id₂
    exact Prod.ext hd (Subtype.ext (Prod.ext hc' hv))
  have hle := Fintype.card_le_of_injective f hf
  rw [Fintype.card_prod, card_dig_eq, Fintype.card_subtype] at hle
  simpa [Finset.filter_congr_decidable] using hle

open Classical in
private theorem cond_freshCoord_card {C Id Q Out : Type} [Fintype C] [DecidableEq Q]
    (rd : C → Id → Dig) (upd : C → Id → Dig → C)
    (hrd_self : ∀ c id d, rd (upd c id d) id = d)
    (hupd_self : ∀ c id, upd c id (rd c id) = c)
    (hupd_idem : ∀ c id d₁ d₂, upd (upd c id d₁) id d₂ = upd c id d₂)
    (id : Id) (out : C → Out) (hout : ∀ c d, out (upd c id d) = out c)
    (pts : C → Q) (g : Q → Dig) (hg : ∀ c, g (pts c) = rd c id) (o : Out) (z : Q) :
    2 ^ 256 * (univ.filter (fun c : C => out c = o ∧ pts c = z)).card
      ≤ (univ.filter (fun c : C => out c = o)).card := by
  let f : Dig × {c : C // out c = o ∧ pts c = z} → {c : C // out c = o} :=
    fun p => ⟨upd p.2.1 id p.1, by rw [hout]; exact p.2.2.1⟩
  have hf : Function.Injective f := by
    intro p p' heq
    have hc : upd p.2.1 id p.1 = upd p'.2.1 id p'.1 := congrArg Subtype.val heq
    have hd : p.1 = p'.1 := by
      have h := congrArg (fun c => rd c id) hc
      rwa [hrd_self, hrd_self] at h
    have hs1 : rd p.2.1 id = g z := by rw [← hg p.2.1, p.2.2.2]
    have hs2 : rd p'.2.1 id = g z := by rw [← hg p'.2.1, p'.2.2.2]
    have hc' : p.2.1 = p'.2.1 := by
      calc p.2.1 = upd p.2.1 id (rd p.2.1 id) := (hupd_self p.2.1 id).symm
        _ = upd (upd p.2.1 id p.1) id (g z) := by rw [hs1, hupd_idem]
        _ = upd (upd p'.2.1 id p'.1) id (g z) := by rw [hc]
        _ = upd p'.2.1 id (rd p'.2.1 id) := by rw [hupd_idem, hs2]
        _ = p'.2.1 := hupd_self p'.2.1 id
    exact Prod.ext hd (Subtype.ext hc')
  have hle := Fintype.card_le_of_injective f hf
  rw [Fintype.card_prod, card_dig_eq, Fintype.card_subtype, Fintype.card_subtype] at hle
  simpa [Finset.filter_congr_decidable] using hle

end AbstractCoordBounds

/-! ## 5. Specialized 112-tree leaf freshness, collision, and hidden-leaf bounds on `ShdCoins` -/

open Classical in
/-- **256-bit leaf freshness (`hfreshL`) for any leaf `id : ShdLeafId` across all 112 trees**. -/
theorem freshLeafSalt_card {Q : Type} [DecidableEq Q] {k : ℕ}
    (P : ShdCoins × (Fin k → Dig) → Q) (id : ShdLeafId) (g : Q → Dig)
    (hg : ∀ s, g (P s) = shdLeafSalt s.1 id) (z : Q) :
    2 ^ 256 * (univ.filter (fun s : ShdCoins × (Fin k → Dig) => P s = z)).card
      ≤ Fintype.card (ShdCoins × (Fin k → Dig)) :=
  freshCoord_card shdLeafSalt shdCoinsSetLeaf shdLeafSalt_setLeaf_self shdCoinsSetLeaf_self
    shdCoinsSetLeaf_idem P id g hg z

open Classical in
/-- **256-bit leaf-leaf collision bound (`hpairs`) for any two distinct leaves `id₁ ≠ id₂` across all 112 trees**. -/
theorem coll_pair_twoLeafSalts_card {Q : Type} [DecidableEq Q] {k : ℕ}
    (pts : ShdCoins × (Fin k → Dig) → Fin k → Q) {i j : Fin k} {id₁ id₂ : ShdLeafId} (hne : id₁ ≠ id₂)
    (g : Q → Dig) (hg₁ : ∀ s, g (pts s i) = shdLeafSalt s.1 id₁) (hg₂ : ∀ s, g (pts s j) = shdLeafSalt s.1 id₂) :
    2 ^ 256 * (univ.filter (fun s : ShdCoins × (Fin k → Dig) => pts s i = pts s j)).card
      ≤ Fintype.card (ShdCoins × (Fin k → Dig)) :=
  coll_pair_twoCoords_card shdLeafSalt shdCoinsSetLeaf shdLeafSalt_setLeaf_self
    (fun c {_ _} h d => shdLeafSalt_setLeaf_ne c h d) shdCoinsSetLeaf_self shdCoinsSetLeaf_idem
    pts hne g hg₁ hg₂

open Classical in
/-- **Conditional 256-bit freshness (`hcond_hid`) for any unopened leaf `id : ShdLeafId`**. -/
theorem cond_freshLeafSalt_card {Q Out : Type} [DecidableEq Q]
    (id : ShdLeafId) (out : ShdCoins → Out) (hout : ∀ c d, out (shdCoinsSetLeaf c id d) = out c)
    (pts : ShdCoins → Q) (g : Q → Dig) (hg : ∀ c, g (pts c) = shdLeafSalt c id) (o : Out) (z : Q) :
    2 ^ 256 * (univ.filter (fun c : ShdCoins => out c = o ∧ pts c = z)).card
      ≤ (univ.filter (fun c : ShdCoins => out c = o)).card :=
  cond_freshCoord_card shdLeafSalt shdCoinsSetLeaf shdLeafSalt_setLeaf_self shdCoinsSetLeaf_self
    shdCoinsSetLeaf_idem id out hout pts g hg o z

end ZK60.HonestShield
