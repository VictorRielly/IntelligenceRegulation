/-
D63 Lean lane L32 (2026-11-09), part 2: **`check_opening`'s challenge refusals as transcript-program sites** (finding
L25-2's and L18-3's refusals: a zero group member coefficient, and the proximity pair dependent over the base field).

The code (`hashline/src/private_block/protocol.rs` `check_opening_challenges` :312-323, read 2026-11-09; nothing there
is changed; L9's mirror is `Block.openingChallenges`): on a CLONE of the transcript before an opening, it draws the
members' coefficients group by group (refusing at the first zero) and then the `rows` proximity coefficients, and
refuses when the pair at `(prox, prox + 1)` has a zero determinant over the base field. Every draw is one
`challenge_fp2`, so the draws are the transcript's next squeezes in order: draw `j` is the squeeze after the first `j`.

What is here:
* `drawAt`: the `j`-th challenge squeezed from a transcript; `chalVec_add_tr`, `drawAt_add`: the draws of consecutive
  `challenge_fp2_vec` calls are the draws of one;
* **`openingChallenges_refuses`**: `check_opening_challenges` refuses ONLY when the geometry has no pair (a
  deterministic fact), or one of the first `Σ counts` draws is zero, or the pair of draws at `Σ counts + prox`,
  `Σ counts + prox + 1` has determinant zero;
* `lineBad`, `lineBad_card`, **`det_zero_line`**: a canonical pair `(a, b)` with `a ≠ 0` and determinant zero has `b`
  on the base-field line through `a`: at most `p` values (the `2^-64` per opening of finding L18-3);
* `drawZero_fires`: L29's `drawZeroSite` at draw `j` fires exactly when draw `j` is zero (`k = 1`, `δ = 0`);
  **`depPairSite`**, **`depPairSite_fires`**: the dependent pair as L18's `Site`, `k = p`, `δ = 0` PROVED, firing
  exactly when draw `j + 1` is on the line through draw `j`;
* **`openingChallenges_cover`**: whenever `check_opening_challenges` refuses at the transcript a prefix program
  leaves, the geometry has no pair or one of `Σ counts + 2` sites fires (`Σ counts + 1` with one bad value, one with
  at most `p`).

Every premise is an explicit hypothesis. The schedule audit's own refusals (`audit_claims`: a zero terminal mask
coefficient, a claim's pair weights dependent) are functions of the slots' challenges; they are not built as sites
here (they stay named events of `check_opening`, finding L32-4).
-/
import ZK60Formal.HonestOracleProg

set_option autoImplicit false

namespace ZK60.HonestOpen

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify ZK60.HonestOracle
open ZK60.Circuit (gP GF)

/-! ## The transcript's draws -/

section Draws

variable (H : HIn → Dig)

/-- **The `j`-th challenge squeezed from a transcript** (`challenge_fp2` after `j` earlier ones). -/
def drawAt (t : Tr) (j : ℕ) : Fp2 := ((t.challengeFp2Vec H j).2.challengeFp2 H).1

theorem chalVec_add_tr : ∀ (a b : ℕ) (t : Tr),
    (t.challengeFp2Vec H (a + b)).2 = ((t.challengeFp2Vec H a).2.challengeFp2Vec H b).2
  | 0, b, t => by
    rw [Nat.zero_add]
    rfl
  | a + 1, b, t => by
    rw [Nat.add_right_comm]
    exact chalVec_add_tr a b (t.challengeFp2 H).2

/-- The draws after `a` draws are the later draws of the same transcript. -/
theorem drawAt_add (a j : ℕ) (t : Tr) : drawAt H t (a + j) = drawAt H (t.challengeFp2Vec H a).2 j := by
  unfold drawAt
  rw [chalVec_add_tr]

/-- Entry `j` of `challenge_fp2_vec(n)` is draw `j` (lane L29's `challengeFp2Vec_getD`). -/
theorem chalVec_getD_drawAt (n j : ℕ) (t : Tr) (hj : j < n) :
    (t.challengeFp2Vec H n).1.getD j Fp2.zero = drawAt H t j :=
  challengeFp2Vec_getD H n j t hj

theorem drawAt_canon (t : Tr) (j : ℕ) : (drawAt H t j).Canon := canon_challengeFp2Of _

/-- **One group's member draws** (`groupDraws`): on success the transcript after `n` draws; a refusal is a zero draw
among the `n`. -/
theorem groupDraws_spec : ∀ (n : ℕ) (t : Tr),
    (∀ t', Block.groupDraws H n t = .ok t' → t' = (t.challengeFp2Vec H n).2)
      ∧ ∀ e, Block.groupDraws H n t = .error e → ∃ j, j < n ∧ (drawAt H t j).isZero = true
  | 0, t => by
    refine ⟨fun t' h => ?_, fun e h => ?_⟩
    · have h' : (Except.ok t : Except String Tr) = .ok t' := h
      cases h'
      rfl
    · have h' : (Except.ok t : Except String Tr) = .error e := h
      cases h'
  | n + 1, t => by
    obtain ⟨ih1, ih2⟩ := groupDraws_spec n (t.challengeFp2 H).2
    have e1 : Block.groupDraws H (n + 1) t
        = if (t.challengeFp2 H).1.isZero then .error "zero group member coefficient; discard attempt"
          else Block.groupDraws H n (t.challengeFp2 H).2 := rfl
    by_cases hz : (t.challengeFp2 H).1.isZero = true
    · refine ⟨fun t' h => ?_, fun _ _ => ⟨0, Nat.succ_pos n, hz⟩⟩
      rw [e1, ite_eq_left hz] at h
      cases h
    · refine ⟨fun t' h => ?_, fun e h => ?_⟩
      · rw [e1, ite_eq_right hz] at h
        exact ih1 t' h
      · rw [e1, ite_eq_right hz] at h
        obtain ⟨j, hj, hjz⟩ := ih2 e h
        exact ⟨j + 1, Nat.succ_lt_succ hj, hjz⟩

/-- **The groups' member draws** (the fold of `check_opening_challenges`): on success the transcript after `Σ counts`
draws; a refusal is a zero draw among them. -/
theorem foldDraws_spec : ∀ (counts : List ℕ) (t : Tr),
    (∀ t', counts.foldlM (fun t c => Block.groupDraws H c t) t = .ok t' → t' = (t.challengeFp2Vec H counts.sum).2)
      ∧ ∀ e, counts.foldlM (fun t c => Block.groupDraws H c t) t = .error e →
        ∃ j, j < counts.sum ∧ (drawAt H t j).isZero = true
  | [], t => by
    refine ⟨fun t' h => ?_, fun e h => ?_⟩
    · have h' : (Except.ok t : Except String Tr) = .ok t' := h
      cases h'
      rfl
    · have h' : (Except.ok t : Except String Tr) = .error e := h
      cases h'
  | c :: cs, t => by
    obtain ⟨g1, g2⟩ := groupDraws_spec H c t
    have e1 : (c :: cs).foldlM (fun t c => Block.groupDraws H c t) t
        = Block.groupDraws H c t >>= fun t1 => cs.foldlM (fun t c => Block.groupDraws H c t) t1 := rfl
    cases hg : Block.groupDraws H c t with
    | error e0 =>
      refine ⟨fun t' h => ?_, fun _ _ => ?_⟩
      · rw [e1, hg] at h
        have h' : (Except.error e0 : Except String Tr) = .ok t' := h
        cases h'
      · obtain ⟨j, hj, hjz⟩ := g2 e0 hg
        exact ⟨j, by rw [List.sum_cons]; omega, hjz⟩
    | ok t1 =>
      have ht1 := g1 t1 hg
      obtain ⟨ih1, ih2⟩ := foldDraws_spec cs t1
      refine ⟨fun t' h => ?_, fun e h => ?_⟩
      · rw [e1, hg] at h
        have h' : cs.foldlM (fun t c => Block.groupDraws H c t) t1 = .ok t' := h
        rw [ih1 t' h', ht1, List.sum_cons, chalVec_add_tr]
      · rw [e1, hg] at h
        have h' : cs.foldlM (fun t c => Block.groupDraws H c t) t1 = .error e := h
        obtain ⟨j, hj, hjz⟩ := ih2 e h'
        refine ⟨c + j, by rw [List.sum_cons]; omega, ?_⟩
        rw [drawAt_add, ← ht1]
        exact hjz

/-- `check_opening_challenges` as one bind (the `do` block of `Block.openingChallenges`). -/
theorem openingChallenges_eq (counts : List ℕ) (rows prox : ℕ) (t : Tr) :
    Block.openingChallenges H counts rows prox t
      = (counts.foldlM (fun t c => Block.groupDraws H c t) t >>= fun t1 =>
          if prox + 1 ≥ rows ∨ (Block.det ((t1.challengeFp2Vec H rows).1.getD prox Fp2.zero)
              ((t1.challengeFp2Vec H rows).1.getD (prox + 1) Fp2.zero)).v = 0
          then .error "dependent proximity mask coefficients; discard attempt" else .ok ()) := rfl

/-- **`check_opening_challenges` refuses only at a listed place**: the geometry has no proximity pair below `rows`
(deterministic), or one of the `Σ counts` member draws is zero, or the pair of draws at `Σ counts + prox` and
`Σ counts + prox + 1` has determinant zero. -/
theorem openingChallenges_refuses (counts : List ℕ) (rows prox : ℕ) (t : Tr) (e : String)
    (h : Block.openingChallenges H counts rows prox t = .error e) :
    rows ≤ prox + 1 ∨ (∃ j, j < counts.sum ∧ (drawAt H t j).isZero = true)
      ∨ (Block.det (drawAt H t (counts.sum + prox)) (drawAt H t (counts.sum + prox + 1))).v = 0 := by
  rw [openingChallenges_eq] at h
  obtain ⟨f1, f2⟩ := foldDraws_spec H counts t
  cases hf : counts.foldlM (fun t c => Block.groupDraws H c t) t with
  | error e0 => exact Or.inr (Or.inl (f2 e0 hf))
  | ok t1 =>
    have ht1 := f1 t1 hf
    rw [hf] at h
    by_cases hr : rows ≤ prox + 1
    · exact Or.inl hr
    · refine Or.inr (Or.inr ?_)
      have h' : (if prox + 1 ≥ rows ∨ (Block.det ((t1.challengeFp2Vec H rows).1.getD prox Fp2.zero)
            ((t1.challengeFp2Vec H rows).1.getD (prox + 1) Fp2.zero)).v = 0
          then (.error "dependent proximity mask coefficients; discard attempt" : Except String Unit) else .ok ())
          = .error e := h
      by_cases hd : (Block.det ((t1.challengeFp2Vec H rows).1.getD prox Fp2.zero)
          ((t1.challengeFp2Vec H rows).1.getD (prox + 1) Fp2.zero)).v = 0
      · rw [chalVec_getD_drawAt H rows prox t1 (by omega), chalVec_getD_drawAt H rows (prox + 1) t1 (by omega), ht1,
          ← drawAt_add, ← drawAt_add] at hd
        exact hd
      · have hcond : ¬ (prox + 1 ≥ rows ∨ (Block.det ((t1.challengeFp2Vec H rows).1.getD prox Fp2.zero)
            ((t1.challengeFp2Vec H rows).1.getD (prox + 1) Fp2.zero)).v = 0) := by
          rintro (hc | hc)
          · exact hr hc
          · exact hd hc
        rw [ite_eq_right hcond] at h'
        cases h'

end Draws

/-! ## A determinant zero over the base field: at most `p` values -/

section Line

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **The base-field line through a value**: `{l·a : l ∈ GF}`, the values `b` with `det(a, b) = 0` when `a ≠ 0`. -/
noncomputable def lineBad (a : Fp2) : Finset K := Finset.univ.image (fun l : GF => algebraMap GF K l * a.toK U)

theorem lineBad_card (a : Fp2) : (lineBad U a).card ≤ gP := by
  unfold lineBad
  refine Finset.card_image_le.trans (le_of_eq ?_)
  rw [Finset.card_univ, ZMod.card]

omit [DecidableEq K] in
theorem toK_eq (a : Fp2) : a.toK U = algebraMap GF K a.c0.toGF + U * algebraMap GF K a.c1.toGF := rfl

/-- **A canonical pair with determinant zero is dependent over the base field**: with `a ≠ 0`, `b` is `l·a` for a
base-field `l` (`protocol.rs` `determinant`: `a.c0·b.c1 − a.c1·b.c0`). -/
theorem det_zero_line (a b : Fp2) (ha : a.Canon) (hna : a.isZero = false) (hd : (Block.det a b).v = 0) :
    b.toK U ∈ lineBad U a := by
  have hd' : a.c0.toGF * b.c1.toGF = a.c1.toGF * b.c0.toGF := by
    have hc : (Block.det a b).Canon := Fp.sub_canon _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _)
    have h0 := (Fp.toGF_zero_iff _ hc).mpr hd
    unfold Block.det at h0
    rw [Fp.toGF_sub _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul] at h0
    exact sub_eq_zero.mp h0
  have key : ∀ l : GF, l * a.c0.toGF = b.c0.toGF → l * a.c1.toGF = b.c1.toGF →
      algebraMap GF K l * a.toK U = b.toK U := by
    intro l e0 e1
    rw [toK_eq U b, toK_eq U a, ← e0, ← e1]
    simp only [map_mul]
    ring
  unfold lineBad
  rw [Finset.mem_image]
  by_cases h0 : a.c0.toGF = 0
  · have h1 : a.c1.toGF ≠ 0 := by
      intro h1
      have e0 := (Fp.toGF_zero_iff _ ha.1).mp h0
      have e1 := (Fp.toGF_zero_iff _ ha.2).mp h1
      have ht : a.isZero = true := by simp [Fp2.isZero, e0, e1]
      rw [ht] at hna
      cases hna
    have hb0 : b.c0.toGF = 0 := by
      rw [h0, zero_mul] at hd'
      exact (mul_eq_zero.mp hd'.symm).resolve_left h1
    refine ⟨b.c1.toGF / a.c1.toGF, Finset.mem_univ _, key _ ?_ ((div_eq_iff h1).mp rfl).symm⟩
    rw [h0, hb0, mul_zero]
  · refine ⟨b.c0.toGF / a.c0.toGF, Finset.mem_univ _, key _ ((div_eq_iff h0).mp rfl).symm ?_⟩
    rw [div_mul_eq_mul_div, div_eq_iff h0, mul_comm b.c0.toGF, mul_comm b.c1.toGF]
    exact hd'.symm

end Line

/-! ## The sites -/

section Sites

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} {Coins : Type} [Fintype Coins] [Nonempty Coins]
  {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **The dependent proximity pair as L18's `Site`**: after a prefix `pre` and `j + 1` draws, the next draw lies on
the base-field line through draw `j`: at most `p` bad values, `δ = 0` PROVED. -/
noncomputable def depPairSite (j : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (drawProg (j + 1) (pre c)) (t0 c)) :
    Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => drawProg (j + 1) (pre c)) t0 (fun b => lineBad U (b.2.getD j Fp2.zero)) gP
    (fun _ => lineBad_card U _) (fun c => sep_drawProg _ (j + 1) (pre c) (hs c)) hn

theorem depPairSite_k (j : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (drawProg (j + 1) (pre c)) (t0 c)) :
    (depPairSite Lq hLq U j pre t0 hs hn).k = gP ∧ (depPairSite Lq hLq U j pre t0 hs hn).δ = 0 := ⟨rfl, rfl⟩

/-- **The pair's site fires exactly when draw `j + 1` is on the line through draw `j`**, at the transcript the prefix
leaves. -/
theorem depPairSite_fires (j : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (drawProg (j + 1) (pre c)) (t0 c)) (G : QB Lq → Dig) (c : Coins) :
    (depPairSite Lq hLq U j pre t0 hs hn).fires U G c
      ↔ (drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 (j + 1)).toK U
          ∈ lineBad U (drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 j) := by
  unfold depPairSite
  rw [tprogSite_fires, final_drawProg]
  have e : (((pre c).final (liftH G) (t0 c)).1.challengeFp2Vec (liftH G) (j + 1)).1.getD j Fp2.zero
      = drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 j :=
    chalVec_getD_drawAt (liftH G) (j + 1) j _ (by omega)
  show (drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 (j + 1)).toK U
      ∈ lineBad U ((((pre c).final (liftH G) (t0 c)).1.challengeFp2Vec (liftH G) (j + 1)).1.getD j Fp2.zero) ↔ _
  rw [e]

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
omit [DecidableEq K] in
/-- **L29's zero-draw site at draw `j` fires exactly when draw `j` is zero**, at the transcript the prefix leaves. -/
theorem drawZero_fires (j : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (drawProg j (pre c)) (t0 c))
    (G : QB Lq → Dig) (c : Coins) :
    (drawZeroSite Lq hLq j pre t0 hs hn (K := K)).fires U G c
      ↔ (drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 j).isZero = true := by
  unfold drawZeroSite
  rw [tprogSite_fires, final_drawProg, Finset.mem_singleton]
  exact (isZero_iff_toK U hU _ (canon_challengeFp2Of _)).symm

include hU in
/-- **`check_opening_challenges`' refusals are covered by sites**: if it refuses at the transcript the prefix program
leaves, then the geometry has no proximity pair (deterministic), or the zero-draw site of one of the `Σ counts` member
draws fires, or the zero-draw site of the pair's first draw fires, or the pair's site fires: `Σ counts + 1` sites of
one bad value and one of at most `p`, each with `δ = 0`. -/
theorem openingChallenges_cover (counts : List ℕ) (rows prox : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (e : String)
    (h : Block.openingChallenges (liftH G) counts rows prox ((pre c).final (liftH G) (t0 c)).1 = .error e) :
    rows ≤ prox + 1
      ∨ (∃ j, j < counts.sum ∧ (drawZeroSite Lq hLq j pre t0 hs (hn j) (K := K)).fires U G c)
      ∨ (drawZeroSite Lq hLq (counts.sum + prox) pre t0 hs (hn (counts.sum + prox)) (K := K)).fires U G c
      ∨ (depPairSite Lq hLq U (counts.sum + prox) pre t0 hs (hn (counts.sum + prox + 1))).fires U G c := by
  rcases openingChallenges_refuses (liftH G) counts rows prox _ e h with h1 | ⟨j, hj, hjz⟩ | hd
  · exact Or.inl h1
  · exact Or.inr (Or.inl ⟨j, hj, (drawZero_fires Lq hLq U hU j pre t0 hs (hn j) G c).mpr hjz⟩)
  · by_cases hz : (drawAt (liftH G) ((pre c).final (liftH G) (t0 c)).1 (counts.sum + prox)).isZero = true
    · exact Or.inr (Or.inr (Or.inl ((drawZero_fires Lq hLq U hU _ pre t0 hs (hn _) G c).mpr hz)))
    · refine Or.inr (Or.inr (Or.inr ((depPairSite_fires Lq hLq U _ pre t0 hs (hn _) G c).mpr ?_)))
      exact det_zero_line U _ _ (drawAt_canon (liftH G) _ _) (ff_of_not hz) hd

end Sites

end ZK60.HonestOpen
