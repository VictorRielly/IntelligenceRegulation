-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Mutual.lean: correlated agreement on lines and its mutual form, in unique decoding (2 e < d).

e is the radius, and d is a lower bound on the distance (`MinDist`, Code/Agree.lean). A set of
positions is large if it omits at most e positions. A_ca is the least bound for correlated agreement
(`CAOn`), ε |E| the least bound for its mutual form (`MCAOn`), and ε_m is ε for m rows.

As everywhere in Code/, an error is a count, here of values θ, and a statement "the error is at most
A / |E|" reads "at most A values". The numbers A_ca and ε |E| themselves do not occur; a statement
about them is written as a statement about all their upper bounds. For instance "A_ca = ε |E|" reads
"A bounds the one if and only if it bounds the other".

The letters (d) and (e), in brackets, continue the list in Code/Derived.lean.

 * At one radius: A_ca ≤ ε |E| ≤ max (A_ca, e) (Left inequality: `Code.MCAOn.caOn`; Right
   inequality: `Code.CAOn.mcaOn`). So for A ≥ e the two have the same bounds
   (`Code.mcaOn_iff_caOn_of_le`).
 * (d) First half, ε_m ≤ m ε_1 (`Code.MCAOn.rows`). Second half, a bound A ≥ e + 1 for one row holds
   for every number of rows (`Code.CAOn.of_one_row`, `Code.MCAOn.of_one_row`).
 * Subcodes inherit a bound A ≥ max (e, 1): `Code.CAOn.subcode`, `Code.MCAOn.subcode`.
 * Monomial maps: `Code.minDist_monomial`, `Code.mcaOn_monomial`, `Code.mca_monomial`,
   `Code.caOn_monomial`.

That at most one word of the code is close to a word is `Code.MinDist.decode_unique` in
Code/Third.lean.

Notation:
  E: a field;
  ι: a finite type, the set of positions (Code/Agree.lean's head);
  D: a subspace of the space of words ι → E (Code/Agree.lean's head);
  R: a type; an interleaved word f : R → ι → E has its rows indexed by R (`Close`, Code/Third.lean);
  θ: an element of E, the coefficient of f₁ in f₀ + θ f₁.

Limits: (e) That the two errors are equal and that both are at least (e + 1) / |E| is not proved in
this library. Nothing on list sizes: no statement of this file speaks of lists (bounds on lists:
Cb/Gen/JohnsonList.lean).

The sources of the mathematics: for the two inequalities of the first item and the equality in (e),
Lemma 4.10 of Arnon, Chiesa, Fenzi and Yogev (WHIR) and its later forms;
for (d), Theorem 3.1 of Diamond and Gruen (ePrint 2024/1351); for the pair of words in (e), Remark
1.1 of Ben-Sasson, Carmon, Ishai, Kopparty and Saraf (Proximity gaps for Reed-Solomon codes) and
Remark 2.3 of Diamond and Posen (ePrint 2023/630). Nothing is assumed beyond the hypotheses of
the statements: all is proved from the definitions.
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Third

namespace Code

open Finset Prob

variable {E ι : Type} [Field E] [Fintype ι]

/-! ## The two notions, for a fixed set of rows -/

/-- The value θ is bad for the pair f₀, f₁ of interleaved words: there is a set S of all but at most
e positions on which every row of f₀ + θ f₁ agrees with a word of the code, while not all rows of f₀
and f₁ do. -/
def BadAt {R : Type*} (D : Submodule E (ι → E)) (e : ℕ) (f₀ f₁ : R → ι → E) (θ : E) : Prop :=
  ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S)
    ∧ ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)

/-- Mutual correlated agreement for interleaved words with rows indexed by R: for every pair, the
number of bad values (`BadAt`) is at most `bad`. ε_m |E| denotes the least such number, for a set R
of m rows. -/
def MCAOn [Finite E] (R : Type*) (D : Submodule E (ι → E)) (e bad : ℕ) : Prop :=
  ∀ f₀ f₁ : R → ι → E, cnt (BadAt D e f₀ f₁) ≤ bad

/-- Correlated agreement for interleaved words with rows indexed by R: if f₀ and f₁ together are not
close to the interleaved code, then f₀ + θ f₁ is close to it for at most A values θ. A_ca denotes
the least such number. -/
def CAOn [Finite E] (R : Type*) (D : Submodule E (ι → E)) (e A : ℕ) : Prop :=
  ∀ f₀ f₁ : R → ι → E,
    ¬ Close D e (Sum.elim f₀ f₁) → cnt (fun θ : E => Close D e (fun a => f₀ a + θ • f₁ a)) ≤ A

/-- The notion of Code/Agree.lean asks one bound for every finite set of rows. -/
theorem mca_iff_forall_mcaOn [Finite E] {D : Submodule E (ι → E)} {e bad : ℕ} :
    MCA D e bad ↔ ∀ (R : Type) [Finite R], MCAOn R D e bad := Iff.rfl

theorem MCAOn.mono [Finite E] {R : Type*} {D : Submodule E (ι → E)} {e bad bad' : ℕ}
    (h : MCAOn R D e bad) (hb : bad ≤ bad') :
    MCAOn R D e bad' := fun f₀ f₁ => (h f₀ f₁).trans hb

theorem CAOn.mono [Finite E] {R : Type*} {D : Submodule E (ι → E)} {e A A' : ℕ}
    (h : CAOn R D e A) (hb : A ≤ A') :
    CAOn R D e A' := fun f₀ f₁ hfar => (h f₀ f₁ hfar).trans hb

/-- For a bad value the point of the line is close. -/
theorem BadAt.close {R : Type*} {D : Submodule E (ι → E)} {e : ℕ} {f₀ f₁ : R → ι → E}
    {θ : E} (h : BadAt D e f₀ f₁ θ) :
    Close D e (fun a => f₀ a + θ • f₁ a) := by
  obtain ⟨S, hS, hl, -⟩ := h
  exact ⟨S, hS, hl⟩

omit [Fintype ι] in
/-- Agreement with a subcode is agreement with the code. -/
theorem agreeOn_mono {D' D : Submodule E (ι → E)} (h : D' ≤ D) (S : Finset ι) :
    agreeOn D' S ≤ agreeOn D S :=
  fun _ ⟨u, hu, hfu⟩ => ⟨u, h hu, hfu⟩

/-- An interleaved word that is close to a subcode is close to the code. -/
theorem Close.mono_code {R : Type*} {D' D : Submodule E (ι → E)} {e : ℕ} {f : R → ι → E}
    (h : Close D' e f) (hD : D' ≤ D) :
    Close D e f := by
  obtain ⟨S, hS, hf⟩ := h
  exact ⟨S, hS, fun a => agreeOn_mono hD S (hf a)⟩

/-! ## Correlated agreement and its mutual form at one radius -/

section LemmaI6

variable {R : Type*} {D : Submodule E (ι → E)} {d e A : ℕ}

/-- Left inequality. A bound for the mutual form is a bound for correlated agreement. No condition
on the distance is needed. -/
theorem MCAOn.caOn [Finite E] (h : MCAOn R D e A) : CAOn R D e A := by
  intro f₀ f₁ hfar
  refine (cnt_mono ?_).trans (h f₀ f₁)
  rintro θ ⟨S, hS, hl⟩
  exact ⟨S, hS, hl, fun hb => hfar (close_sumElim_iff.mpr ⟨S, hS, hb.1, hb.2⟩)⟩

/-- Let D have minimum distance at least d (`hd`) and 2 e < d. A pair that is close to the
interleaved code has at most e bad values. The field may be infinite. -/
theorem card_bad_le_of_close (hd : MinDist D d) (h2 : 2 * e < d) {f₀ f₁ : R → ι → E}
    (hc : Close D e (Sum.elim f₀ f₁)) (Y : Finset E) (hY : ∀ θ ∈ Y, BadAt D e f₀ f₁ θ) :
    Y.card ≤ e := by
  classical
  obtain ⟨g, S₀, hg, hS₀, hfg⟩ := hc.exists_table
  have hag : ∀ j ∈ S₀, ∀ a, f₀ a j = g (Sum.inl a) j ∧ f₁ a j = g (Sum.inr a) j :=
    fun j hj a => ⟨hfg j hj (Sum.inl a), hfg j hj (Sum.inr a)⟩
  have hW : (univ.filter (WrongAt f₀ f₁ (fun a => g (Sum.inl a)) (fun a => g (Sum.inr a)))).card ≤
      e := by
    have hsub : univ.filter (WrongAt f₀ f₁ (fun a => g (Sum.inl a)) (fun a => g (Sum.inr a))) ⊆
        S₀ᶜ :=
      fun j hj => mem_compl.mpr fun hjS => (mem_filter.mp hj).2 (hag j hjS)
    have h1 := card_le_card hsub
    rw [card_compl] at h1
    omega
  refine (card_bad_le_card_wrong (fun a => hg _) (fun a => hg _) (fun j => by simp)
    (fun θ S hS hl =>
      meet_of_agree hd (by omega : e + e < d) (fun a => hg _) (fun a => hg _) hS₀ hag hS hl)
    Y hY).trans hW

/-- Right inequality. Let D have minimum distance at least d (`hd`) and 2 e < d. If A bounds
correlated agreement, then max (A, e) bounds the mutual form. -/
theorem CAOn.mcaOn [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (h : CAOn R D e A) :
    MCAOn R D e (max A e) := by
  intro f₀ f₁
  by_cases hc : Close D e (Sum.elim f₀ f₁)
  · exact (cnt_le_of_forall_finset fun Y hY => card_bad_le_of_close hd h2 hc Y hY).trans
      (le_max_right _ _)
  · exact ((cnt_mono fun θ hθ => hθ.close).trans (h f₀ f₁ hc)).trans (le_max_left _ _)

/-- Under `hd`, `h2` (minimum distance at least d, 2 e < d). For a bound A ≥ e: A bounds correlated
agreement if and only if it bounds the mutual form. -/
theorem mcaOn_iff_caOn_of_le [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (hA : e ≤ A) :
    MCAOn R D e A ↔ CAOn R D e A :=
  ⟨MCAOn.caOn, fun h => by
    have h1 := h.mcaOn hd h2
    rwa [max_eq_left hA] at h1⟩

end LemmaI6

/-! ## From one row to many (item (d)) -/

section Rows

variable {D : Submodule E (ι → E)} {d e A : ℕ}

/-- First half: ε_m ≤ m ε_1. A value that is bad for interleaved words is bad for one of the pairs
of rows. -/
theorem MCAOn.rows [Finite E] {R : Type} [Finite R] {bad : ℕ} (h : MCAOn Unit D e bad) :
    MCAOn R D e (Nat.card R * bad) := by
  intro f₀ f₁
  cases nonempty_fintype R
  cases nonempty_fintype E
  rw [Nat.card_eq_fintype_card]
  refine (cnt_mono ?_).trans
    (cnt_exists_le_mul
      (fun (a : R) (θ : E) => BadAt D e (fun _ : Unit => f₀ a) (fun _ : Unit => f₁ a) θ) bad
      (fun a => h _ _))
  rintro θ ⟨S, hS, hl, hn⟩
  by_contra hno
  refine hn ⟨fun a => ?_, fun a => ?_⟩
  · by_contra hx
    exact hno ⟨a, S, hS, fun _ => hl a, fun hb => hx (hb.1 ())⟩
  · by_contra hx
    exact hno ⟨a, S, hS, fun _ => hl a, fun hb => hx (hb.2 ())⟩

/-- Second half, for correlated agreement. Let D have minimum distance at least d (`hd`), 2 e < d
and A ≥ e + 1. If A bounds correlated agreement for single words, then it does for interleaved words
with any set of rows, finite or not. -/
theorem CAOn.of_one_row [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (h : CAOn Unit D e A) (R : Type*) :
    CAOn R D e A := by
  classical
  intro f₀ f₁ hfar
  refine cnt_le_of_forall_finset fun Y hY => ?_
  by_contra hcon
  apply hfar
  -- Each pair of rows is close to a pair of words of the code.
  have hrow : ∀ a, Close D e (Sum.elim (fun _ : Unit => f₀ a) (fun _ : Unit => f₁ a)) := by
    intro a
    by_contra hfa
    have h1 := h _ _ hfa
    have h3 : Y.card ≤ cnt (fun θ : E => Close D e (fun _ : Unit => f₀ a + θ • f₁ a)) :=
      card_le_cnt Y fun θ hθ => by
        obtain ⟨S, hS, hl⟩ := hY θ hθ
        exact ⟨S, hS, fun _ => hl a⟩
    omega
  choose g S₀ hg hS₀ hfg using fun a => (hrow a).exists_table
  -- On a large set S on which f₀ + θ f₁ is on the code, it is the point at θ of these words' line.
  have hmeet : ∀ (θ : E) (S : Finset ι), Fintype.card ι ≤ S.card + e →
      (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) →
      ∀ j ∈ S, MeetAt f₀ f₁ (fun a => g a (Sum.inl ())) (fun a => g a (Sum.inr ())) θ j := by
    intro θ S hS hl j hj a
    exact meet_of_agree (R := Unit) hd (by omega : e + e < d) (f₀ := fun _ => f₀ a)
      (f₁ := fun _ => f₁ a) (g₀ := fun _ => g a (Sum.inl ())) (g₁ := fun _ => g a (Sum.inr ()))
      (fun _ => hg a _) (fun _ => hg a _) (hS₀ a)
      (fun i hi _ => ⟨hfg a i hi (Sum.inl ()), hfg a i hi (Sum.inr ())⟩) hS (fun _ => hl a) j hj ()
  have hW := card_wrong_le
    (W := univ.filter (WrongAt f₀ f₁ (fun a => g a (Sum.inl ())) (fun a => g a (Sum.inr ()))))
    (fun j hj => (mem_filter.mp hj).2) (by omega : e + 2 ≤ Y.card) (fun θ hθ => by
      obtain ⟨S, hS, hl⟩ := hY θ hθ
      exact ⟨S, hS, hmeet θ S hS hl⟩)
  exact close_of_wrong (fun a => hg a _) (fun a => hg a _)
    (fun j hj => mem_filter.mpr ⟨mem_univ j, hj⟩) hW

/-- Second half. Let D have minimum distance at least d (`hd`), 2 e < d and A ≥ e + 1. If single
words have at most A bad values, then so have interleaved words with any number of rows. -/
theorem MCAOn.of_one_row [Finite E] (hd : MinDist D d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (h : MCAOn Unit D e A) : MCA D e A :=
  fun R _ => (mcaOn_iff_caOn_of_le hd h2 (by omega)).mpr (h.caOn.of_one_row hd h2 hA R)

end Rows

/-! ## Subcodes -/

section Subcodes

variable {R : Type*} {D D' : Submodule E (ι → E)} {d e A : ℕ}

/-- Subcodes, for correlated agreement. Let 2 e < d for the code D, and let A ≥ 1 bound correlated
agreement for D. Then A bounds it for every subcode D'. -/
theorem CAOn.subcode [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (hD : D' ≤ D)
    (hA : 1 ≤ A) (h : CAOn R D e A) :
    CAOn R D' e A := by
  classical
  intro f₀ f₁ hfar
  refine cnt_le_of_forall_finset fun Y hY => ?_
  by_contra hcon
  apply hfar
  have hcl : Close D e (Sum.elim f₀ f₁) := by
    by_contra hfa
    have h1 := h f₀ f₁ hfa
    have h3 : Y.card ≤ cnt (fun θ : E => Close D e (fun a => f₀ a + θ • f₁ a)) :=
      card_le_cnt Y fun θ hθ => (hY θ hθ).mono_code hD
    omega
  obtain ⟨g, S₀, hg, hS₀, hfg⟩ := hcl.exists_table
  obtain ⟨x₁, hx₁, x₂, hx₂, hne⟩ := one_lt_card.mp (by omega : 1 < Y.card)
  -- For the values in Y the point of the line through the words of D is in D'.
  have hin : ∀ θ ∈ Y, ∀ a, g (Sum.inl a) + θ • g (Sum.inr a) ∈ D' := by
    intro θ hθ a
    obtain ⟨S, hS, hl⟩ := hY θ hθ
    obtain ⟨c, hc, hfc⟩ := mem_agreeOn.mp (hl a)
    have hST := card_inter_large hS₀ hS
    have hcg : c = g (Sum.inl a) + θ • g (Sum.inr a) := by
      refine hd.eq_of_agree (hD hc) (D.add_mem (hg _) (D.smul_mem _ (hg _))) (S := S₀ ∩ S)
        (by omega) fun i hi => ?_
      have e₀ : f₀ a i = g (Sum.inl a) i := hfg i (mem_inter.mp hi).1 (Sum.inl a)
      have e₁ : f₁ a i = g (Sum.inr a) i := hfg i (mem_inter.mp hi).1 (Sum.inr a)
      rw [← hfc i (mem_inter.mp hi).2]
      simp only [Pi.add_apply, Pi.smul_apply, smul_eq_mul]
      rw [e₀, e₁]
    rw [← hcg]
    exact hc
  have hx : x₂ - x₁ ≠ 0 := sub_ne_zero.mpr hne.symm
  have hg₁ : ∀ a, g (Sum.inr a) ∈ D' := by
    intro a
    have h1 : g (Sum.inr a) = (x₂ - x₁)⁻¹ •
        ((g (Sum.inl a) + x₂ • g (Sum.inr a)) - (g (Sum.inl a) + x₁ • g (Sum.inr a))) := by
      rw [add_sub_add_left_eq_sub, ← sub_smul, smul_smul, inv_mul_cancel₀ hx, one_smul]
    rw [h1]
    exact D'.smul_mem _ (D'.sub_mem (hin x₂ hx₂ a) (hin x₁ hx₁ a))
  have hg₀ : ∀ a, g (Sum.inl a) ∈ D' := by
    intro a
    have h1 : g (Sum.inl a) = (g (Sum.inl a) + x₁ • g (Sum.inr a)) - x₁ • g (Sum.inr a) := by
      rw [add_sub_cancel_right]
    rw [h1]
    exact D'.sub_mem (hin x₁ hx₁ a) (D'.smul_mem _ (hg₁ a))
  refine ⟨S₀, hS₀, fun a => ⟨g a, ?_, fun j hj => hfg j hj a⟩⟩
  cases a with
  | inl a => exact hg₀ a
  | inr a => exact hg₁ a

/-- Subcodes, for the mutual form. Let 2 e < d for the code D. A bound A ≥ max (e, 1) for D is a
bound for every subcode. -/
theorem MCAOn.subcode [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (hD : D' ≤ D) (hA : e ≤ A)
    (hA1 : 1 ≤ A) (h : MCAOn R D e A) : MCAOn R D' e A :=
  (mcaOn_iff_caOn_of_le (hd.anti hD) h2 hA).mpr (h.caOn.subcode hd h2 hD hA1)

/-- Subcodes, within unique decoding. Let 2 e < d for the code D, and let single words have at most
A ≥ e + 1 bad values for D. Then for every subcode of D, interleaved words with any number of rows
have at most A bad values. -/
theorem MCAOn.subcode_of_one_row [Finite E] (hd : MinDist D d) (h2 : 2 * e < d) (hD : D' ≤ D)
    (hA : e + 1 ≤ A) (h : MCAOn Unit D e A) : MCA D' e A :=
  (h.subcode hd h2 hD (by omega) (by omega)).of_one_row (hd.anti hD) h2 hA

end Subcodes

/-! ## Monomial maps -/

section Monomial

variable {ι' : Type} [Fintype ι']

omit [Fintype ι] [Fintype ι'] in
/-- A monomial map: the positions are renamed by the bijection τ, and the symbol at the position I
is multiplied by η_I ≠ 0. It sends the word w to (η_I w[τ(I)])_I. -/
def monomialMap (τ : ι' ≃ ι) (η : ι' → E) (hη : ∀ I, η I ≠ 0) : (ι → E) ≃ₗ[E] (ι' → E) where
  toFun w := fun I => η I * w (τ I)
  invFun v := fun j => (η (τ.symm j))⁻¹ * v (τ.symm j)
  map_add' v w := by
    funext I
    simp only [Pi.add_apply, mul_add]
  map_smul' c w := by
    funext I
    simp only [Pi.smul_apply, smul_eq_mul, RingHom.id_apply, mul_left_comm]
  left_inv w := by
    funext j
    simp only [Equiv.apply_symm_apply]
    rw [inv_mul_cancel_left₀ (hη _)]
  right_inv v := by
    funext I
    simp only [Equiv.symm_apply_apply]
    rw [mul_inv_cancel_left₀ (hη _)]

variable (τ : ι' ≃ ι) (η : ι' → E) (hη : ∀ I, η I ≠ 0)

omit [Fintype ι] [Fintype ι'] in
theorem monomialMap_apply (w : ι → E) (I : ι') : monomialMap τ η hη w I = η I * w (τ I) := rfl

/-- The image of a code under a monomial map. -/
abbrev monomialImage (D : Submodule E (ι → E)) : Submodule E (ι' → E) :=
  D.map (monomialMap τ η hη : (ι → E) →ₗ[E] (ι' → E))

omit [Fintype ι] [Fintype ι'] in
/-- The image of w agrees with the image of the code on S if and only if w agrees with the code on
τ(S). -/
theorem monomialMap_mem_agreeOn (D : Submodule E (ι → E)) (S : Finset ι') (w : ι → E) :
    monomialMap τ η hη w ∈ agreeOn (monomialImage τ η hη D) S ↔
    w ∈ agreeOn D (S.map τ.toEmbedding) := by
  constructor
  · rintro ⟨_, ⟨u, hu, rfl⟩, hwu⟩
    refine ⟨u, hu, fun j hj => ?_⟩
    obtain ⟨I, hI, rfl⟩ := mem_map.mp hj
    exact mul_left_cancel₀ (hη I) (hwu I hI)
  · rintro ⟨u, hu, hwu⟩
    refine ⟨monomialMap τ η hη u, ⟨u, hu, rfl⟩, fun I hI => ?_⟩
    rw [monomialMap_apply, monomialMap_apply, hwu (τ I) (mem_map.mpr ⟨I, hI, rfl⟩)]

/-- Sets of positions on the two sides correspond to each other, with their sizes. -/
theorem exists_large_iff (e : ℕ) (Q : Finset ι → Prop) :
    (∃ S' : Finset ι', Fintype.card ι' ≤ S'.card + e ∧ Q (S'.map τ.toEmbedding)) ↔
      ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ Q S := by
  constructor
  · rintro ⟨S', hS', hQ⟩
    exact ⟨S'.map τ.toEmbedding, by rw [card_map, ← Fintype.card_congr τ]; exact hS', hQ⟩
  · rintro ⟨S, hS, hQ⟩
    have hmap : (S.map τ.symm.toEmbedding).map τ.toEmbedding = S := by
      ext j
      simp
    exact ⟨S.map τ.symm.toEmbedding,
      by rw [card_map, Fintype.card_congr τ]; exact hS,
      by rw [hmap]; exact hQ⟩

/-- A monomial map keeps closeness to the interleaved code. -/
theorem close_monomial {R : Type*} (D : Submodule E (ι → E)) (e : ℕ) (f : R → ι → E) :
    Close (monomialImage τ η hη D) e (fun a => monomialMap τ η hη (f a)) ↔ Close D e f := by
  unfold Close
  simp only [monomialMap_mem_agreeOn]
  exact exists_large_iff τ e fun S => ∀ a, f a ∈ agreeOn D S

/-- A monomial map keeps the bad values. -/
theorem badAt_monomial {R : Type*} (D : Submodule E (ι → E)) (e : ℕ) (f₀ f₁ : R → ι → E) (θ : E) :
    BadAt (monomialImage τ η hη D) e (fun a => monomialMap τ η hη (f₀ a))
      (fun a => monomialMap τ η hη (f₁ a)) θ ↔
      BadAt D e f₀ f₁ θ := by
  unfold BadAt
  simp only [← map_smul, ← map_add, monomialMap_mem_agreeOn]
  exact exists_large_iff τ e fun S => (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S)
    ∧ ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)

/-- Distance. A monomial map keeps the distance. -/
theorem minDist_monomial (D : Submodule E (ι → E)) (d : ℕ) :
    MinDist (monomialImage τ η hη D) d ↔ MinDist D d := by
  have hcnt : ∀ u : ι → E, cnt (fun I => monomialMap τ η hη u I ≠ 0) = cnt (fun j => u j ≠ 0) := by
    intro u
    rw [← cnt_equiv τ (fun j => u j ≠ 0)]
    exact cnt_congr fun I => by rw [monomialMap_apply]; exact mul_ne_zero_iff_left (hη I)
  constructor
  · intro h u hu hne
    rw [← hcnt u]
    exact h _ ⟨u, hu, rfl⟩ fun h0 => hne ((monomialMap τ η hη).map_eq_zero_iff.mp h0)
  · rintro h _ ⟨u, hu, rfl⟩ hne
    have h1 := h u hu fun h0 => hne (by rw [h0]; exact map_zero _)
    rw [← hcnt u] at h1
    exact h1

/-- A monomial map keeps mutual correlated agreement, for a fixed set of rows. -/
theorem mcaOn_monomial [Finite E] {R : Type*} (D : Submodule E (ι → E)) (e bad : ℕ) :
    MCAOn R (monomialImage τ η hη D) e bad ↔ MCAOn R D e bad := by
  constructor
  · intro h f₀ f₁
    rw [← cnt_congr (badAt_monomial τ η hη D e f₀ f₁)]
    exact h _ _
  · intro h f₀ f₁
    have h1 :=
      h (fun a => (monomialMap τ η hη).symm (f₀ a)) (fun a => (monomialMap τ η hη).symm (f₁ a))
    rw [← cnt_congr (badAt_monomial τ η hη D e _ _)] at h1
    simpa only [LinearEquiv.apply_symm_apply] using h1

/-- Monomial maps: a code and its image under a monomial map have the same error of mutual
correlated agreement. -/
theorem mca_monomial [Finite E] (D : Submodule E (ι → E)) (e bad : ℕ) :
    MCA (monomialImage τ η hη D) e bad ↔ MCA D e bad :=
  ⟨fun h R _ => (mcaOn_monomial τ η hη D e bad).mp (h R),
    fun h R _ => (mcaOn_monomial τ η hη D e bad).mpr (h R)⟩

/-- A monomial map keeps correlated agreement, for a fixed set of rows. -/
theorem caOn_monomial [Finite E] {R : Type*} (D : Submodule E (ι → E)) (e A : ℕ) :
    CAOn R (monomialImage τ η hη D) e A ↔ CAOn R D e A := by
  have hsum : ∀ f₀ f₁ : R → ι → E,
      (Sum.elim (fun a => monomialMap τ η hη (f₀ a)) (fun a => monomialMap τ η hη (f₁ a))) =
        fun a => monomialMap τ η hη (Sum.elim f₀ f₁ a) := by
    intro f₀ f₁
    funext a
    cases a <;> rfl
  have hline : ∀ (f₀ f₁ : R → ι → E) (θ : E),
      Close (monomialImage τ η hη D) e
        (fun a => monomialMap τ η hη (f₀ a) + θ • monomialMap τ η hη (f₁ a)) ↔
      Close D e (fun a => f₀ a + θ • f₁ a) := by
    intro f₀ f₁ θ
    simp only [← map_smul, ← map_add]
    exact close_monomial τ η hη D e _
  have key : ∀ f₀ f₁ : R → ι → E,
      (¬ Close (monomialImage τ η hη D) e
          (Sum.elim (fun a => monomialMap τ η hη (f₀ a)) (fun a => monomialMap τ η hη (f₁ a))) →
        cnt (fun θ : E =>
            Close (monomialImage τ η hη D) e
              (fun a => monomialMap τ η hη (f₀ a) + θ • monomialMap τ η hη (f₁ a))) ≤ A) ↔
      (¬ Close D e (Sum.elim f₀ f₁) →
        cnt (fun θ : E => Close D e (fun a => f₀ a + θ • f₁ a)) ≤ A) := by
    intro f₀ f₁
    rw [hsum, close_monomial, cnt_congr (hline f₀ f₁)]
  constructor
  · intro h f₀ f₁
    exact (key f₀ f₁).mp (h _ _)
  · intro h f₀ f₁
    have h1 := (key _ _).mpr
      (h (fun a => (monomialMap τ η hη).symm (f₀ a)) (fun a => (monomialMap τ η hη).symm (f₁ a)))
    simpa only [LinearEquiv.apply_symm_apply] using h1

end Monomial

end Code
