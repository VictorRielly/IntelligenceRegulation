/-
D63 Lean lane L32 (2026-11-09), part 2: **`check_opening`'s refusals, covered** (ClassifyOpen's field O9, item (c) of
lane L29's list).

`protocol::check_opening` (L10's executable `checkOpeningExec`, the `checkOpening` field of every block and stage) is:
the schedule audit (`audit_claims`), the first-occurrence grouping (`opening_groups_at`), the exact group count, then
the challenge refusals on a clone of the transcript (`check_opening_challenges`). Here:
* `bumpKey_sum`, `grpStep`, `grp_fold_sum`, **`openingGroupsAt_sum`**: the groups' member counts add up to the number
  of claims, whatever the grouping (so the opening's site family is indexed by the SCHEDULE's claim count, not by the
  challenges);
* `checkOpeningExec_ok_of`, **`checkOpeningExec_refuses`**: `check_opening` refuses only when the audit refuses, the
  grouping refuses, the group count is not the declared one, or `check_opening_challenges` refuses;
* **`checkOpening_cover`**: at the transcript a prefix program leaves, a refusal of `check_opening` on a commitment
  with `n` claims is: the audit's refusal, the grouping's refusal, a wrong group count, a geometry with no proximity
  pair (four named events: the last three are deterministic facts of the registered schedule; the audit's
  challenge-dependent refusals are finding L32-4), or ONE OF THE OPENING'S `n + 2` SITES FIRES (`openSite`: `δ = 0`,
  `p + n + 1` bad values in all).

With `HonestRunProg.lean` (the transcript after `M`'s opening and after `A`'s opening as programs) this is the cover
of the `check_opening` disjuncts that lane L29's `core_refuse_cover`, `inc_refuse_cover` and `outc_refuse_cover` leave
as named events.
-/
import ZK60Formal.HonestRunCount

set_option autoImplicit false

namespace ZK60.HonestRun

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify ZK60.HonestOracle ZK60.HonestOpen
open ZK60.Circuit (gP GF)

/-! ## The groups' member counts add up to the claims -/

section Groups

theorem bumpKey_sum (key : List Fp2 × ℕ × ℕ) : ∀ gs : List ((List Fp2 × ℕ × ℕ) × ℕ),
    ((bumpKey key gs).map (·.2)).sum = (gs.map (·.2)).sum + 1
  | [] => by simp [bumpKey]
  | (k, c) :: rest => by
    have e : bumpKey key ((k, c) :: rest)
        = if k = key then (k, c + 1) :: rest else (k, c) :: bumpKey key rest := rfl
    rw [e]
    by_cases h : k = key
    · rw [ite_eq_left h]
      simp only [List.map_cons, List.sum_cons]
      omega
    · rw [ite_eq_right h]
      simp only [List.map_cons, List.sum_cons, bumpKey_sum key rest]
      omega

/-- One claim's step of `opening_groups_at`. -/
def grpStep (logN : ℕ) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (c : Block.ZClaim) :
    Except String (List ((List Fp2 × ℕ × ℕ) × ℕ)) :=
  let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
  if c.parts.any (fun p => partKeyAt p logN ≠ key) then
    throw "private block: claim parts with different column weights"
  else pure (bumpKey key gs)

theorem openingGroupsAt_eq (claims : List Block.ZClaim) (logN : ℕ) :
    openingGroupsAt claims logN = claims.foldlM (grpStep logN) [] := rfl

theorem grpStep_ok (logN : ℕ) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (c : Block.ZClaim)
    (gs' : List ((List Fp2 × ℕ × ℕ) × ℕ)) (h : grpStep logN gs c = .ok gs') :
    (gs'.map (·.2)).sum = (gs.map (·.2)).sum + 1 := by
  have e : grpStep logN gs c
      = if c.parts.any (fun p => partKeyAt p logN ≠ partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN) = true
        then .error "private block: claim parts with different column weights"
        else .ok (bumpKey (partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN) gs) := rfl
  rw [e] at h
  by_cases hc : c.parts.any (fun p => partKeyAt p logN ≠ partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN) = true
  · rw [ite_eq_left hc] at h
    cases h
  · rw [ite_eq_right hc] at h
    cases h
    exact bumpKey_sum _ gs

theorem grp_fold_sum (logN : ℕ) : ∀ (claims : List Block.ZClaim) (gs groups : List ((List Fp2 × ℕ × ℕ) × ℕ)),
    claims.foldlM (grpStep logN) gs = .ok groups → (groups.map (·.2)).sum = (gs.map (·.2)).sum + claims.length
  | [], gs, groups, h => by
    have h' : (Except.ok gs : Except String (List ((List Fp2 × ℕ × ℕ) × ℕ))) = .ok groups := h
    cases h'
    rw [List.length_nil, Nat.add_zero]
  | c :: cs, gs, groups, h => by
    have e1 : (c :: cs).foldlM (grpStep logN) gs
        = grpStep logN gs c >>= fun gs1 => cs.foldlM (grpStep logN) gs1 := rfl
    rw [e1] at h
    cases hg : grpStep logN gs c with
    | error e0 =>
      rw [hg] at h
      have h' : (Except.error e0 : Except String (List ((List Fp2 × ℕ × ℕ) × ℕ))) = .ok groups := h
      cases h'
    | ok gs1 =>
      rw [hg] at h
      have h' : cs.foldlM (grpStep logN) gs1 = .ok groups := h
      rw [grp_fold_sum logN cs gs1 groups h', grpStep_ok logN gs c gs1 hg, List.length_cons]
      omega

/-- **The groups' member counts add up to the number of claims**, whatever the grouping. -/
theorem openingGroupsAt_sum (claims : List Block.ZClaim) (logN : ℕ) (groups : List ((List Fp2 × ℕ × ℕ) × ℕ))
    (h : openingGroupsAt claims logN = .ok groups) : (groups.map (·.2)).sum = claims.length := by
  have h1 := grp_fold_sum logN claims [] groups h
  rw [h1, List.map_nil, List.sum_nil, Nat.zero_add]

end Groups

/-! ## `check_opening` refuses only at a listed place -/

section Check

variable (H : HIn → Dig)

theorem ok_bind {ε α β : Type} (a : α) (f : α → Except ε β) : (Except.ok a >>= f) = f a := rfl

/-- With the audit and the grouping passed and the declared group count, `check_opening` is its challenge
refusals. -/
theorem checkOpeningExec_ok_of (g : OpenGeom) (logN : ℕ) (claims : List Block.ZClaim) (t : Tr)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ))
    (ha : auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox = .ok ())
    (hgr : openingGroupsAt claims logN = .ok groups) (hlen : groups.length = g.groups) :
    checkOpeningExec H g logN claims t = Block.openingChallenges H (groups.map (·.2)) g.rows g.prox t := by
  unfold checkOpeningExec
  rw [ha, hgr, ok_bind, ok_bind]
  split_ifs with hc
  · exact absurd hlen hc
  · rfl

/-- **`check_opening` refuses only when** the schedule audit refuses, the grouping refuses, the group count is not
the declared one, or `check_opening_challenges` refuses on the groups' member counts. -/
theorem checkOpeningExec_refuses (g : OpenGeom) (logN : ℕ) (claims : List Block.ZClaim) (t : Tr) (e : String)
    (h : checkOpeningExec H g logN claims t = .error e) :
    (∃ e', auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox = .error e')
      ∨ (∃ e', openingGroupsAt claims logN = .error e')
      ∨ ∃ groups, openingGroupsAt claims logN = .ok groups
          ∧ (groups.length ≠ g.groups
            ∨ Block.openingChallenges H (groups.map (·.2)) g.rows g.prox t = .error e) := by
  cases ha : auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox with
  | error e1 => exact Or.inl ⟨e1, rfl⟩
  | ok u =>
    cases hgr : openingGroupsAt claims logN with
    | error e2 => exact Or.inr (Or.inl ⟨e2, rfl⟩)
    | ok groups =>
      refine Or.inr (Or.inr ⟨groups, rfl, ?_⟩)
      by_cases hlen : groups.length = g.groups
      · right
        rw [checkOpeningExec_ok_of H g logN claims t groups ha hgr hlen] at h
        exact h
      · exact Or.inl hlen

end Check

/-! ## The cover -/

section Cover

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} {Coins : Type} [Fintype Coins] [Nonempty Coins]
  {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`check_opening`'s refusals are covered**: if `check_opening` refuses on a commitment with `n` claims at the
transcript the prefix program leaves, then the schedule audit refused, or the grouping refused, or the group count is
not the declared one, or the geometry has no proximity pair, or one of the opening's `n + 2` sites fires
(`openSite`: every `δ = 0`, `p + n + 1` bad values in all). -/
theorem checkOpening_cover (g : OpenGeom) (logN n : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (claims : List Block.ZClaim) (hcl : claims.length = n) (e : String)
    (h : checkOpeningExec (liftH G) g logN claims ((pre c).final (liftH G) (t0 c)).1 = .error e) :
    (∃ e', auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox = .error e')
      ∨ (∃ e', openingGroupsAt claims logN = .error e')
      ∨ (∃ groups, openingGroupsAt claims logN = .ok groups ∧ groups.length ≠ g.groups)
      ∨ g.rows ≤ g.prox + 1
      ∨ ∃ i, (openSite Lq hLq U n g.prox pre t0 hs hn i).fires U G c := by
  rcases checkOpeningExec_refuses (liftH G) g logN claims _ e h with h1 | h2 | ⟨groups, hgr, h3 | h4⟩
  · exact Or.inl h1
  · exact Or.inr (Or.inl h2)
  · exact Or.inr (Or.inr (Or.inl ⟨groups, hgr, h3⟩))
  · have hsum : (groups.map (·.2)).sum = n := (openingGroupsAt_sum claims logN groups hgr).trans hcl
    rcases openSite_cover Lq hLq U hU (groups.map (·.2)) n hsum g.rows g.prox pre t0 hs hn G c e h4 with h5 | h6
    · exact Or.inr (Or.inr (Or.inr (Or.inl h5)))
    · exact Or.inr (Or.inr (Or.inr (Or.inr h6)))

end Cover

end ZK60.HonestRun
