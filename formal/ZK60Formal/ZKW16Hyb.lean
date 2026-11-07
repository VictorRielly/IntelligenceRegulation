/-
D63 step L14 (Statement 2, zero knowledge), part 5: the stand-in hybrid's step `hstep` from ONE receipt's step.

`ZKHybrid.zeroKnowledge_of_hybrid` (and `ZKW16Block.zeroKnowledge_of_hybrid_R`) leave the hypothesis `hstep`: hybrid
`j` (the first `j` requests simulated, the rest honest) against hybrid `j + 1`, for every distinguisher. For the
stand-in simulator (`ZKW16Block.standinSim`) this file reduces `hstep` to a statement about ONE receipt in a context:
`OneStep`, the form `ZKW16Step.fs_step` proves (`oneStep_of_fsModel`).

* **Re-indexing the coins** (`runPos`, `runIdx`, `hyb_runPos`, `card_coord`, `reindex_count`, `hybProb_reindex`): in
  `hybProb` the coins are indexed by POSITION (a hash query uses none); request number `m` sits at a random position.
  Since each position is read at most once, the hybrid's probability is the same when request number `m` reads the coin
  of INDEX `m` (a coordinate-by-coordinate argument over the run, `card_coord`: an event that reads coordinate `p` only
  through its first argument splits along it).
* **The context of request `j`** (`pre`, `post`, `trunc`, `runIdx_post`, `runIdx_split`, `runIdx_split_succ`):
  with the other indices fixed, hybrid `j`'s run is `A₁` (everything before request `j`: the distinguisher's queries and
  the stand-in provers of requests `0 … j-1`, a query-bounded computation, `pre_bounded`), then request `j`'s receipt,
  then `A₂` (the honest provers of the later requests and the rest; truncated at its budget so that every branch is
  bounded, which changes no reachable run). Hybrid `j + 1` is the same context with request `j` answered by the
  stand-in.
* **`hstep_of_oneStep`**: averaging over the other indices (`splitAt`, `prob_le_of_forall_fst`) turns a one-receipt
  bound `ε q₁ q₂` into hybrid `j` versus `j + 1` within `ε (q + j·qp) (q + R·qp)`, both ways, `qp` the prover's
  queries per receipt. With `zeroKnowledge_of_hybrid_R` this gives `ZeroKnowledge` (`zeroKnowledge_of_oneStep`).

The prover is assumed to be a query-bounded oracle computation (`pOC`, `hrun`, `hbd`), as the honest prover is.
Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ZKW16Block

namespace ZK60.ZKW16

open scoped ENNReal
open Finset
open ZK60.ZKHybrid

/-! ## Generic facts -/

/-- **One coordinate splits off.** If an event reads coordinate `p` of the coins only through its first argument, its
diagonal count times `|C|` is the sum over that argument's values. -/
theorem card_coord {C : Type} [Fintype C] {n : ℕ} (p : Fin n) (G : C → (Fin n → C) → Prop)
    [∀ a, DecidablePred (G a)] [DecidablePred (fun c : Fin n → C => G (c p) c)]
    (hG : ∀ a (c : Fin n → C) b, G a (Function.update c p b) ↔ G a c) :
    (univ.filter (fun c : Fin n → C => G (c p) c)).card * Fintype.card C
      = ∑ a : C, (univ.filter (fun c : Fin n → C => G a c)).card := by
  classical
  have hfib : ∀ a b b', (univ.filter (fun c : Fin n → C => c p = b ∧ G a c)).card
      = (univ.filter (fun c : Fin n → C => c p = b' ∧ G a c)).card := by
    intro a b b'
    refine card_nbij' (fun c => Function.update c p b') (fun c => Function.update c p b) ?_ ?_ ?_ ?_
    · intro c hc
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hc ⊢
      exact ⟨Function.update_self p b' c, (hG a c b').mpr hc.2⟩
    · intro c hc
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hc ⊢
      exact ⟨Function.update_self p b c, (hG a c b).mpr hc.2⟩
    · intro c hc
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hc
      show Function.update (Function.update c p b') p b = c
      rw [Function.update_idem, ← hc.1, Function.update_eq_self]
    · intro c hc
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hc
      show Function.update (Function.update c p b) p b' = c
      rw [Function.update_idem, ← hc.1, Function.update_eq_self]
  have hmaps : ∀ s : Finset (Fin n → C), (s : Set (Fin n → C)).MapsTo (fun c => c p) (univ : Finset C) :=
    fun _ _ _ => mem_coe.mpr (mem_univ _)
  have hsplit : ∀ a, (univ.filter (fun c : Fin n → C => G a c)).card
      = Fintype.card C * (univ.filter (fun c : Fin n → C => c p = a ∧ G a c)).card := by
    intro a
    rw [card_eq_sum_card_fiberwise (s := univ.filter (fun c : Fin n → C => G a c)) (hmaps _)]
    calc ∑ b ∈ (univ : Finset C), ((univ.filter (fun c : Fin n → C => G a c)).filter (fun c => c p = b)).card
        = ∑ _b : C, (univ.filter (fun c : Fin n → C => c p = a ∧ G a c)).card := by
          refine sum_congr rfl (fun b _ => ?_)
          rw [← hfib a b a]
          congr 1
          ext c
          simp only [mem_filter, mem_univ, true_and]
          exact and_comm
      _ = Fintype.card C * (univ.filter (fun c : Fin n → C => c p = a ∧ G a c)).card := by
          rw [sum_const, card_univ, smul_eq_mul]
  have hdiag : (univ.filter (fun c : Fin n → C => G (c p) c)).card
      = ∑ a : C, (univ.filter (fun c : Fin n → C => c p = a ∧ G a c)).card := by
    rw [card_eq_sum_card_fiberwise (s := univ.filter (fun c : Fin n → C => G (c p) c)) (hmaps _)]
    refine sum_congr rfl (fun a _ => ?_)
    congr 1
    ext c
    simp only [mem_filter, mem_univ, true_and]
    constructor
    · rintro ⟨h1, h2⟩
      refine ⟨h2, ?_⟩
      rw [← h2]
      exact h1
    · rintro ⟨h1, h2⟩
      refine ⟨?_, h1⟩
      rw [h1]
      exact h2
  rw [hdiag, sum_mul]
  refine sum_congr rfl (fun a _ => ?_)
  rw [hsplit a, mul_comm]

/-- **A fibrewise bound is a bound on average** (the first factor drawn first). -/
theorem prob_le_of_forall_fst {X Y : Type} [Fintype X] [Nonempty X] [Fintype Y] [Nonempty Y]
    (E₁ E₂ : Y → X → Prop) (ε : ℝ≥0∞)
    (h : ∀ y, (PMF.uniformOfFintype X).toOuterMeasure {x | E₁ y x}
      ≤ (PMF.uniformOfFintype X).toOuterMeasure {x | E₂ y x} + ε) :
    (PMF.uniformOfFintype (Y × X)).toOuterMeasure {p | E₁ p.1 p.2}
      ≤ (PMF.uniformOfFintype (Y × X)).toOuterMeasure {p | E₂ p.1 p.2} + ε := by
  have e : ∀ E : Y → X → Prop, (PMF.uniformOfFintype (Y × X)).toOuterMeasure {p | E p.1 p.2}
      = ∑' y, (PMF.uniformOfFintype Y) y * (PMF.uniformOfFintype X).toOuterMeasure {x | E y x} := by
    intro E
    rw [Hiding.uniform_prod_eq_bind, PMF.toOuterMeasure_bind_apply]
    congr 1
    funext y
    rw [PMF.toOuterMeasure_map_apply]
    rfl
  rw [e E₁, e E₂]
  calc ∑' y, (PMF.uniformOfFintype Y) y * (PMF.uniformOfFintype X).toOuterMeasure {x | E₁ y x}
      ≤ ∑' y, (PMF.uniformOfFintype Y) y * ((PMF.uniformOfFintype X).toOuterMeasure {x | E₂ y x} + ε) :=
        ENNReal.tsum_le_tsum (fun y => mul_le_mul_right (h y) _)
    _ = ∑' y, (PMF.uniformOfFintype Y) y * (PMF.uniformOfFintype X).toOuterMeasure {x | E₂ y x}
          + ∑' y, (PMF.uniformOfFintype Y) y * ε := by
        rw [← ENNReal.tsum_add]
        congr 1
        funext y
        ring
    _ = ∑' y, (PMF.uniformOfFintype Y) y * (PMF.uniformOfFintype X).toOuterMeasure {x | E₂ y x} + ε := by
        rw [ENNReal.tsum_mul_right, PMF.tsum_coe, one_mul]

/-- Splitting coordinate `j` off a coin vector: the other coordinates (coordinate `j` reset to `c₀`) first. -/
def splitAt {A C : Type} {n : ℕ} (j : Fin n) (c₀ : C) :
    A × (Fin n → C) ≃ {d : Fin n → C // d j = c₀} × (A × C) where
  toFun p := (⟨Function.update p.2 j c₀, Function.update_self j c₀ p.2⟩, (p.1, p.2 j))
  invFun p := (p.2.1, Function.update p.1.1 j p.2.2)
  left_inv := by
    rintro ⟨a, d⟩
    simp [Function.update_idem, Function.update_eq_self]
  right_inv := by
    rintro ⟨⟨d, hd⟩, a, c⟩
    refine Prod.ext (Subtype.ext ?_) (Prod.ext rfl ?_)
    · show Function.update (Function.update d j c) j c₀ = d
      rw [Function.update_idem, ← hd, Function.update_eq_self]
    · show Function.update d j c j = c
      exact Function.update_self j c d

/-- `extend` below the length reads the vector. -/
theorem extend_lt {R : Type} [Inhabited R] {n : ℕ} (c : Fin n → R) {i : ℕ} (h : i < n) :
    extend c i = c ⟨i, h⟩ := by
  unfold extend
  exact dite_eq_left h

/-- `extend` of an updated vector, away from the update. -/
theorem extend_update_ne {R : Type} [Inhabited R] {n : ℕ} (c : Fin n → R) (p : Fin n) (b : R) (i : ℕ)
    (h : i ≠ p.val) : extend (Function.update c p b) i = extend c i := by
  unfold extend
  split_ifs with hi
  · exact Function.update_of_ne (fun e => h (congrArg Fin.val e)) _ _
  · rfl

/-- `extend` of an updated vector is the updated `extend`. -/
theorem extend_update {R : Type} [Inhabited R] {n : ℕ} (r : Fin n → R) {j : ℕ} (hj : j < n) (c : R) :
    extend (Function.update r ⟨j, hj⟩ c) = Function.update (extend r) j c := by
  funext i
  by_cases hi : i = j
  · subst hi
    rw [Function.update_self, extend_lt _ hj, Function.update_self]
  · rw [Function.update_of_ne hi, extend_update_ne r ⟨j, hj⟩ c i hi]

/-- Truncate a computation after `n` questions (answer `false` past the budget). -/
def trunc {I O : Type} : OC I O Bool → ℕ → OC I O Bool
  | .ret b, _ => .ret b
  | .ask _ _, 0 => .ret false
  | .ask i k, n + 1 => .ask i (fun o => trunc (k o) n)

theorem trunc_bounded {I O : Type} : ∀ (A : OC I O Bool) (n : ℕ), (trunc A n).Bounded n := by
  intro A
  induction A with
  | ret b => intro n; trivial
  | ask i k ih =>
    intro n
    cases n with
    | zero => trivial
    | succ n => exact fun o => ih o n

/-- A computation within the budget is unchanged by the truncation. -/
theorem trunc_eq {I O : Type} : ∀ (A : OC I O Bool) (n : ℕ), A.Bounded n → trunc A n = A := by
  intro A
  induction A with
  | ret b => intro n _; rfl
  | ask i k ih =>
    intro n hA
    cases n with
    | zero => exact absurd hA (by simp [OC.Bounded])
    | succ n =>
      show OC.ask i (fun o => trunc (k o) n) = OC.ask i k
      exact congrArg (OC.ask i) (funext fun o => ih o n (hA o))

/-! ## The stand-in hybrid, request by request -/

section StandinHybrid

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} (P : Protocol Q D Coins M) [Inhabited M.Input]
  (W : M.Weights)

/-- Hybrid `j`'s answer to request number `m`: the stand-in prover (its coin's second half) before `j`, the honest
prover (the first half) from `j` on. -/
noncomputable def hans (H : Q → D) (j m : ℕ) (x : M.Input) (c : Coins × Coins) : P.Stmt × P.Receipt :=
  if m < j then P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x)) c.2 else P.prove H W x c.1

/-- Hybrid `j`'s run with the coins indexed by POSITION (as `hybProb` draws them). -/
noncomputable def runPos (H : Q → D) (j : ℕ) (rand : ℕ → Coins × Coins) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool → ℕ → ℕ → Bool
  | .ret b, _, _ => b
  | .ask (.inl z) k, pos, m => runPos H j rand (k (.inl (H z))) (pos + 1) m
  | .ask (.inr x) k, pos, m => runPos H j rand (k (.inr (hans P W H j m x (rand pos)))) (pos + 1) (m + 1)

/-- Hybrid `j`'s run with request number `m` reading the coin of INDEX `m`. -/
noncomputable def runIdx (H : Q → D) (j : ℕ) (d : ℕ → Coins × Coins) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool → ℕ → Bool
  | .ret b, _ => b
  | .ask (.inl z) k, m => runIdx H j d (k (.inl (H z))) m
  | .ask (.inr x) k, m => runIdx H j d (k (.inr (hans P W H j m x (d m)))) (m + 1)

/-- The hybrid's stateful run, for the stand-in simulator, is `runPos`. -/
theorem hyb_runPos (H : Q → D) (j : ℕ) (rand : ℕ → Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (pos m : ℕ),
      Dist.runState (hybStep (standinSim P) W H j) rand pos (m, []) = runPos P W H j rand Dist pos m := by
  intro Dist
  induction Dist with
  | ret b => intro pos m; rfl
  | ask i k ih =>
    intro pos m
    rw [runState_ask]
    cases i with
    | inl z => exact ih (.inl (H z)) (pos + 1) m
    | inr x =>
      have e : hybStep (standinSim P) W H j (m, []) (.inr x) (rand pos)
          = (.inr (hans P W H j m x (rand pos)), (m + 1, [])) := by
        rw [standin_hybStep]
        unfold hans
        split_ifs <;> rfl
      rw [e]
      exact ih _ (pos + 1) (m + 1)

omit [DecidableEq Q] in
/-- `runPos` reads the coins only from its position on. -/
theorem runPos_congr (H : Q → D) (j : ℕ) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (pos m : ℕ) (rand rand' : ℕ → Coins × Coins),
      (∀ i, pos ≤ i → rand i = rand' i) → runPos P W H j rand Dist pos m = runPos P W H j rand' Dist pos m := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro pos m rand rand' h
    cases i with
    | inl z =>
      show runPos P W H j rand (k (.inl (H z))) (pos + 1) m = runPos P W H j rand' (k (.inl (H z))) (pos + 1) m
      exact ih _ (pos + 1) m rand rand' (fun i hi => h i (by omega))
    | inr x =>
      show runPos P W H j rand (k (.inr (hans P W H j m x (rand pos)))) (pos + 1) (m + 1)
        = runPos P W H j rand' (k (.inr (hans P W H j m x (rand' pos)))) (pos + 1) (m + 1)
      rw [h pos le_rfl]
      exact ih _ (pos + 1) (m + 1) rand rand' (fun i hi => h i (by omega))

omit [DecidableEq Q] in
/-- `runIdx` reads the coins only from its request count on. -/
theorem runIdx_congr (H : Q → D) (j : ℕ) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (m : ℕ) (d d' : ℕ → Coins × Coins),
      (∀ i, m ≤ i → d i = d' i) → runIdx P W H j d Dist m = runIdx P W H j d' Dist m := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro m d d' h
    cases i with
    | inl z =>
      show runIdx P W H j d (k (.inl (H z))) m = runIdx P W H j d' (k (.inl (H z))) m
      exact ih _ m d d' h
    | inr x =>
      show runIdx P W H j d (k (.inr (hans P W H j m x (d m)))) (m + 1)
        = runIdx P W H j d' (k (.inr (hans P W H j m x (d' m)))) (m + 1)
      rw [h m le_rfl]
      exact ih _ (m + 1) d d' (fun i hi => h i (by omega))

omit [DecidableEq Q] in
/-- **Re-indexing, counted** (fixed oracle): for a distinguisher within its budget, drawing request `m`'s coin at its
position or at index `m` gives the same count. -/
theorem reindex_count [Inhabited Coins] [Fintype Coins] (H : Q → D) (j n : ℕ) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r pos m : ℕ), Dist.Within q r →
      pos + q + r ≤ n → m + r ≤ n →
      (univ.filter (fun c : Fin n → Coins × Coins => runPos P W H j (extend c) Dist pos m = true)).card
        = (univ.filter (fun d : Fin n → Coins × Coins => runIdx P W H j (extend d) Dist m = true)).card := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro q r pos m hW hpos hm
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        exact ih (.inl (H z)) q r (pos + 1) m (hW _) (by omega) hm
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        have hp : pos < n := by omega
        have hmn : m < n := by omega
        classical
        have hL : univ.filter (fun c : Fin n → Coins × Coins =>
              runPos P W H j (extend c) (.ask (.inr x) k) pos m = true)
            = univ.filter (fun c : Fin n → Coins × Coins => runPos P W H j (extend c)
                (k (.inr (hans P W H j m x (c ⟨pos, hp⟩)))) (pos + 1) (m + 1) = true) := by
          refine filter_congr (fun c _ => ?_)
          show runPos P W H j (extend c) (k (.inr (hans P W H j m x (extend c pos)))) (pos + 1) (m + 1) = true ↔ _
          rw [extend_lt c hp]
        have hR : univ.filter (fun d : Fin n → Coins × Coins => runIdx P W H j (extend d) (.ask (.inr x) k) m = true)
            = univ.filter (fun d : Fin n → Coins × Coins => runIdx P W H j (extend d)
                (k (.inr (hans P W H j m x (d ⟨m, hmn⟩)))) (m + 1) = true) := by
          refine filter_congr (fun d _ => ?_)
          show runIdx P W H j (extend d) (k (.inr (hans P W H j m x (extend d m)))) (m + 1) = true ↔ _
          rw [extend_lt d hmn]
        have h1 := card_coord ⟨pos, hp⟩ (fun (a : Coins × Coins) (c : Fin n → Coins × Coins) =>
            runPos P W H j (extend c) (k (.inr (hans P W H j m x a))) (pos + 1) (m + 1) = true)
          (fun a c b => by
            rw [runPos_congr P W H j _ (pos + 1) (m + 1) (extend (Function.update c ⟨pos, hp⟩ b)) (extend c)
              (fun i hi => extend_update_ne c ⟨pos, hp⟩ b i (by show i ≠ pos; omega))])
        have h2 := card_coord ⟨m, hmn⟩ (fun (a : Coins × Coins) (d : Fin n → Coins × Coins) =>
            runIdx P W H j (extend d) (k (.inr (hans P W H j m x a))) (m + 1) = true)
          (fun a d b => by
            rw [runIdx_congr P W H j _ (m + 1) (extend (Function.update d ⟨m, hmn⟩ b)) (extend d)
              (fun i hi => extend_update_ne d ⟨m, hmn⟩ b i (by show i ≠ m; omega))])
        beta_reduce at h1 h2
        rw [hL, hR]
        refine Nat.eq_of_mul_eq_mul_right (Fintype.card_pos (α := Coins × Coins)) ?_
        rw [h1, h2]
        exact sum_congr rfl (fun a _ => ih (.inr (hans P W H j m x a)) q r (pos + 1) (m + 1) (hW _)
          (by omega) (by omega))

/-- **Re-indexing**: the stand-in hybrid's probability, with request number `m` reading the coin of index `m`. -/
theorem hybProb_reindex [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (j q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (hD : Dist.Within q R) :
    hybProb (standinSim P) W (q + R) Dist j
      = (PMF.uniformOfFintype ((Q → D) × (Fin (q + R) → Coins × Coins))).toOuterMeasure
          {p | runIdx P W p.1 j (extend p.2) Dist 0 = true} := by
  classical
  unfold hybProb
  have hset : {p : (Q → D) × (Fin (q + R) → Coins × Coins) |
      Dist.runState (hybStep (standinSim P) W p.1 j) (extend p.2) 0 (0, []) = true}
      = {p | runPos P W p.1 j (extend p.2) Dist 0 0 = true} := by
    ext p
    simp only [Set.mem_ofPred_eq]
    rw [hyb_runPos P W p.1 j (extend p.2) Dist 0 0]
  rw [hset, prob_filter, prob_filter, card_filter_prod, card_filter_prod]
  congr 2
  refine sum_congr rfl (fun H _ => ?_)
  exact reindex_count P W H j (q + R) Dist q R 0 0 hD (by omega) (by omega)

/-! ### The context of request `j` -/

/-- What the part before request `j` returns: the verdict if the distinguisher stops first, else request `j`'s input
and the continuation. -/
abbrev PreRes : Type :=
  Bool ⊕ (M.Input × ((D ⊕ (P.Stmt × P.Receipt)) → OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool))

/-- **Everything before request `j`** (`A₁`): the distinguisher's queries and the stand-in provers of the earlier
requests, as one oracle computation. -/
noncomputable def pre (pOC : M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (j : ℕ) (d : ℕ → Coins × Coins) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool → ℕ → OC Q D (PreRes P)
  | .ret b, _ => .ret (.inl b)
  | .ask (.inl z) k, m => .ask z (fun h => pre pOC j d (k (.inl h)) m)
  | .ask (.inr x) k, m =>
    if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2).bind
      (fun o => pre pOC j d (k (.inr o)) (m + 1))
    else .ret (.inr (x, k))

/-- **Everything after request `j`** (`A₂`): the honest provers of the later requests and the distinguisher's rest. -/
noncomputable def post (pOC : M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (d : ℕ → Coins × Coins) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool → ℕ → OC Q D Bool
  | .ret b, _ => .ret b
  | .ask (.inl z) k, m => .ask z (fun h => post pOC d (k (.inl h)) m)
  | .ask (.inr x) k, m => (pOC x (d m).1).bind (fun o => post pOC d (k (.inr o)) (m + 1))

/-- Request `j`'s input, read off the prefix's result. -/
def xOf : PreRes P → M.Input
  | .inl _ => default
  | .inr p => p.1

/-- The context after request `j`, truncated at its budget `N`. -/
noncomputable def ctx₂ (pOC : M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (j N : ℕ) (d : ℕ → Coins × Coins) :
    PreRes P → P.Stmt × P.Receipt → OC Q D Bool
  | .inl b, _ => .ret b
  | .inr p, o => trunc (post P pOC d (p.2 (.inr o)) (j + 1)) N

variable (pOC : M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (qp : ℕ)

omit [DecidableEq Q] in
/-- The prefix's budget: the distinguisher's queries and `j − m` provers. -/
theorem pre_bounded (hbd : ∀ x c, (pOC x c).Bounded qp) (j : ℕ) (d : ℕ → Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r → m ≤ j →
      (pre P W pOC j d Dist m).Bounded (q + (j - m) * qp) := by
  intro Dist
  induction Dist with
  | ret b => intros; trivial
  | ask i k ih =>
    intro q r m hW hm
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        have e : q + 1 + (j - m) * qp = (q + (j - m) * qp) + 1 := by ring
        rw [e]
        exact fun h => ih _ q r m (hW _) hm
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        by_cases hmj : m < j
        · show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2).bind
            (fun o => pre P W pOC j d (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).Bounded (q + (j - m) * qp)
          rw [ite_eq_left hmj]
          have hb := OC.Bounded.bind (hbd (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2)
            (fun o => ih (.inr o) q r (m + 1) (hW _) hmj)
          refine hb.mono ?_
          have : j - m = (j - (m + 1)) + 1 := by omega
          rw [this, add_mul, one_mul]
          omega
        · show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2).bind
            (fun o => pre P W pOC j d (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).Bounded (q + (j - m) * qp)
          rw [ite_eq_right hmj]
          trivial

omit [DecidableEq Q] [Inhabited M.Input] in
/-- The suffix's budget: the distinguisher's queries and one prover per remaining request. -/
theorem post_bounded (hbd : ∀ x c, (pOC x c).Bounded qp) (d : ℕ → Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r →
      (post P pOC d Dist m).Bounded (q + r * qp) := by
  intro Dist
  induction Dist with
  | ret b => intros; trivial
  | ask i k ih =>
    intro q r m hW
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        have e : q + 1 + r * qp = (q + r * qp) + 1 := by ring
        rw [e]
        exact fun h => ih _ q r m (hW _)
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        have hb := OC.Bounded.bind (hbd x (d m).1) (fun o => ih (.inr o) q r (m + 1) (hW _))
        refine hb.mono ?_
        rw [add_mul, one_mul]
        omega

omit [DecidableEq Q] in
/-- **After request `j` every request is honest**: hybrid `J` (`J = j` or `J = j + 1`) from a later request on is the
suffix's run. -/
theorem runIdx_post (hrun : ∀ H x c, (pOC x c).run H = P.prove H W x c) (H : Q → D) (J j : ℕ)
    (d₀ : ℕ → Coins × Coins) (c : Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (m : ℕ), j < m → J ≤ m →
      runIdx P W H J (Function.update d₀ j c) Dist m = (post P pOC d₀ Dist m).run H := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro m hjm hJm
    cases i with
    | inl z => exact ih (.inl (H z)) m hjm hJm
    | inr x =>
      show runIdx P W H J (Function.update d₀ j c) (k (.inr (hans P W H J m x (Function.update d₀ j c m)))) (m + 1)
        = ((pOC x (d₀ m).1).bind (fun o => post P pOC d₀ (k (.inr o)) (m + 1))).run H
      rw [OC.run_bind, hrun, Function.update_of_ne (Nat.ne_of_gt hjm)]
      have e : hans P W H J m x (d₀ m) = P.prove H W x (d₀ m).1 := by
        unfold hans
        rw [ite_eq_right (by omega)]
      rw [e]
      exact ih _ (m + 1) (by omega) (by omega)

omit [DecidableEq Q] in
/-- **Hybrid `j`, split at request `j`**: the prefix's run, then the honest receipt on request `j`'s input with the coin
`c.1`, then the (truncated) suffix. -/
theorem runIdx_split (hrun : ∀ H x c, (pOC x c).run H = P.prove H W x c) (hbd : ∀ x c, (pOC x c).Bounded qp)
    (H : Q → D) (j N : ℕ) (d₀ : ℕ → Coins × Coins) (c : Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r →
      q + r * qp ≤ N → m ≤ j →
      runIdx P W H j (Function.update d₀ j c) Dist m
        = (ctx₂ P pOC j N d₀ ((pre P W pOC j d₀ Dist m).run H)
            (P.prove H W (xOf P ((pre P W pOC j d₀ Dist m).run H)) c.1)).run H := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro q r m hW hN hm
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        exact ih (.inl (H z)) q r m (hW _) (by omega) hm
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        by_cases hmj : m < j
        · have e1 : (pre P W pOC j d₀ (.ask (.inr x) k) m).run H
              = (pre P W pOC j d₀ (k (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x))
                  (d₀ m).2))) (m + 1)).run H := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2).bind
              (fun o => pre P W pOC j d₀ (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).run H = _
            rw [ite_eq_left hmj, OC.run_bind, hrun]
          have e2 : hans P W H j m x (Function.update d₀ j c m)
              = P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2 := by
            rw [Function.update_of_ne (Nat.ne_of_lt hmj)]
            unfold hans
            rw [ite_eq_left hmj]
          show runIdx P W H j (Function.update d₀ j c) (k (.inr (hans P W H j m x (Function.update d₀ j c m))))
            (m + 1) = _
          rw [e1, e2]
          exact ih _ q r (m + 1) (hW _) (le_trans (Nat.add_le_add_left (Nat.mul_le_mul_right qp (Nat.le_succ r)) q) hN) hmj
        · have hmj' : m = j := by omega
          have e1 : (pre P W pOC j d₀ (.ask (.inr x) k) m).run H = .inr (x, k) := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2).bind
              (fun o => pre P W pOC j d₀ (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).run H = _
            rw [ite_eq_right hmj]
            rfl
          have e2 : hans P W H j m x (Function.update d₀ j c m) = P.prove H W x c.1 := by
            rw [hmj', Function.update_self]
            unfold hans
            rw [ite_eq_right (lt_irrefl j)]
          show runIdx P W H j (Function.update d₀ j c) (k (.inr (hans P W H j m x (Function.update d₀ j c m))))
            (m + 1) = _
          rw [e1, e2]
          show _ = (trunc (post P pOC d₀ (k (.inr (P.prove H W x c.1))) (j + 1)) N).run H
          rw [trunc_eq (post P pOC d₀ (k (.inr (P.prove H W x c.1))) (j + 1)) N
            ((post_bounded P pOC qp hbd d₀ (k (.inr (P.prove H W x c.1))) q r (j + 1) (hW _)).mono
              (le_trans (Nat.add_le_add_left (Nat.mul_le_mul_right qp (Nat.le_succ r)) q) hN))]
          rw [hmj']
          exact runIdx_post P W pOC hrun H j j d₀ c _ (j + 1) (by omega) (by omega)

omit [DecidableEq Q] in
/-- **Hybrid `j + 1`, split at request `j`**: the same prefix and suffix, request `j` answered by the stand-in prover
with the coin `c.2`. -/
theorem runIdx_split_succ (hrun : ∀ H x c, (pOC x c).run H = P.prove H W x c)
    (hbd : ∀ x c, (pOC x c).Bounded qp) (H : Q → D) (j N : ℕ) (d₀ : ℕ → Coins × Coins) (c : Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r →
      q + r * qp ≤ N → m ≤ j →
      runIdx P W H (j + 1) (Function.update d₀ j c) Dist m
        = (ctx₂ P pOC j N d₀ ((pre P W pOC j d₀ Dist m).run H)
            (P.prove H W (standin P W (M.publicPart (M.forward W (xOf P ((pre P W pOC j d₀ Dist m).run H))),
              P.leak (xOf P ((pre P W pOC j d₀ Dist m).run H)))) c.2)).run H := by
  intro Dist
  induction Dist with
  | ret b => intros; rfl
  | ask i k ih =>
    intro q r m hW hN hm
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        exact ih (.inl (H z)) q r m (hW _) (by omega) hm
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        by_cases hmj : m < j
        · have e1 : (pre P W pOC j d₀ (.ask (.inr x) k) m).run H
              = (pre P W pOC j d₀ (k (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x))
                  (d₀ m).2))) (m + 1)).run H := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2).bind
              (fun o => pre P W pOC j d₀ (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).run H = _
            rw [ite_eq_left hmj, OC.run_bind, hrun]
          have e2 : hans P W H (j + 1) m x (Function.update d₀ j c m)
              = P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2 := by
            rw [Function.update_of_ne (Nat.ne_of_lt hmj)]
            unfold hans
            rw [ite_eq_left (by omega)]
          show runIdx P W H (j + 1) (Function.update d₀ j c)
            (k (.inr (hans P W H (j + 1) m x (Function.update d₀ j c m)))) (m + 1) = _
          rw [e1, e2]
          exact ih _ q r (m + 1) (hW _) (le_trans (Nat.add_le_add_left (Nat.mul_le_mul_right qp (Nat.le_succ r)) q) hN) hmj
        · have hmj' : m = j := by omega
          have e1 : (pre P W pOC j d₀ (.ask (.inr x) k) m).run H = .inr (x, k) := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d₀ m).2).bind
              (fun o => pre P W pOC j d₀ (k (.inr o)) (m + 1)) else .ret (.inr (x, k))).run H = _
            rw [ite_eq_right hmj]
            rfl
          have e2 : hans P W H (j + 1) m x (Function.update d₀ j c m)
              = P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x)) c.2 := by
            rw [hmj', Function.update_self]
            unfold hans
            rw [ite_eq_left (Nat.lt_succ_self j)]
          show runIdx P W H (j + 1) (Function.update d₀ j c)
            (k (.inr (hans P W H (j + 1) m x (Function.update d₀ j c m)))) (m + 1) = _
          rw [e1, e2]
          show _ = (trunc (post P pOC d₀ (k (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x),
            P.leak x)) c.2))) (j + 1)) N).run H
          rw [trunc_eq (post P pOC d₀ (k (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x),
            P.leak x)) c.2))) (j + 1)) N
            ((post_bounded P pOC qp hbd d₀ (k (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x),
              P.leak x)) c.2))) q r (j + 1) (hW _)).mono
              (le_trans (Nat.add_le_add_left (Nat.mul_le_mul_right qp (Nat.le_succ r)) q) hN))]
          rw [hmj']
          exact runIdx_post P W pOC hrun H (j + 1) j d₀ c _ (j + 1) (by omega) le_rfl

/-! ### One receipt in its context ⇒ the hybrid step -/

variable [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **One receipt, honest versus stand-in, in any context** (the form `ZKW16Step.fs_step` proves): for every `A₁`
of at most `q₁` queries choosing the input and every `A₂` of at most `q₂` queries reading the receipt, the two success
probabilities differ by at most `ε q₁ q₂`, both ways. -/
def OneStep (ε : ℕ → ℕ → ℝ≥0∞) : Prop :=
  ∀ (α : Type) (A₁ : OC Q D α) (q₁ : ℕ), A₁.Bounded q₁ → ∀ (x : α → M.Input)
    (A₂ : α → P.Stmt × P.Receipt → OC Q D Bool) (q₂ : ℕ), (∀ a o, (A₂ a o).Bounded q₂) →
    (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true}
      ≤ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
          P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true} + ε q₁ q₂
    ∧ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
          P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true}
      ≤ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true} + ε q₁ q₂

/-- The first coin of a pair integrates out. -/
theorem prob_coin_fst {C₁ C₂ : Type} [Fintype C₁] [Nonempty C₁] [Fintype C₂] [Nonempty C₂]
    (E : (Q → D) → C₁ → Prop) :
    (PMF.uniformOfFintype ((Q → D) × (C₁ × C₂))).toOuterMeasure {p | E p.1 p.2.1}
      = (PMF.uniformOfFintype ((Q → D) × C₁)).toOuterMeasure {p | E p.1 p.2} :=
  prob_marginal (Equiv.prodAssoc (Q → D) C₁ C₂).symm {p | E p.1 p.2}

/-- The second coin of a pair integrates out. -/
theorem prob_coin_snd {C₁ C₂ : Type} [Fintype C₁] [Nonempty C₁] [Fintype C₂] [Nonempty C₂]
    (E : (Q → D) → C₂ → Prop) :
    (PMF.uniformOfFintype ((Q → D) × (C₁ × C₂))).toOuterMeasure {p | E p.1 p.2.2}
      = (PMF.uniformOfFintype ((Q → D) × C₂)).toOuterMeasure {p | E p.1 p.2} :=
  prob_marginal (((Equiv.refl (Q → D)).prodCongr (Equiv.prodComm C₁ C₂)).trans
    (Equiv.prodAssoc (Q → D) C₂ C₁).symm) {p | E p.1 p.2}

/-- **The hybrid step from one receipt.** If one receipt in any context costs at most `ε q₁ q₂` (`OneStep`), then for
every distinguisher with at most `q` hash queries and `R` requests, hybrid `j` and hybrid `j + 1` of the stand-in
simulator differ by at most `ε (q + j·qp) (q + R·qp)`, both ways. -/
theorem hstep_of_oneStep (hrun : ∀ H x c, (pOC x c).run H = P.prove H W x c)
    (hbd : ∀ x c, (pOC x c).Bounded qp) (ε : ℕ → ℕ → ℝ≥0∞) (hone : OneStep P W ε) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (hD : Dist.Within q R) (j : ℕ) (hj : j < R) :
    hybProb (standinSim P) W (q + R) Dist j
        ≤ hybProb (standinSim P) W (q + R) Dist (j + 1) + ε (q + j * qp) (q + R * qp)
      ∧ hybProb (standinSim P) W (q + R) Dist (j + 1)
        ≤ hybProb (standinSim P) W (q + R) Dist j + ε (q + j * qp) (q + R * qp) := by
  classical
  have hjn : j < q + R := by omega
  set N := q + R * qp with hNdef
  set c₀ : Coins × Coins := default
  have : Nonempty {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀} := ⟨⟨fun _ => c₀, rfl⟩⟩
  -- re-index both hybrids, then split coordinate `j` off
  have hsplitJ : ∀ J : ℕ, hybProb (standinSim P) W (q + R) Dist J
      = (PMF.uniformOfFintype
          ({d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀} × ((Q → D) × (Coins × Coins)))).toOuterMeasure
          {p | runIdx P W p.2.1 J (Function.update (extend p.1.1) j p.2.2) Dist 0 = true} := by
    intro J
    rw [hybProb_reindex P W J q R Dist hD]
    rw [← Hiding.map_uniform_equiv (splitAt (A := Q → D) ⟨j, hjn⟩ c₀), PMF.toOuterMeasure_map_apply]
    congr 1
    ext p
    simp only [Set.mem_preimage, Set.mem_ofPred_eq]
    have hext : Function.update (extend (Function.update p.2 ⟨j, hjn⟩ c₀)) j (p.2 ⟨j, hjn⟩) = extend p.2 := by
      rw [← extend_update _ hjn, Function.update_idem, Function.update_eq_self]
    show runIdx P W p.1 J (extend p.2) Dist 0 = true
      ↔ runIdx P W p.1 J (Function.update (extend (Function.update p.2 ⟨j, hjn⟩ c₀)) j (p.2 ⟨j, hjn⟩)) Dist 0 = true
    rw [hext]
  rw [hsplitJ j, hsplitJ (j + 1)]
  -- the context for fixed other coordinates
  have hfib : ∀ r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀},
      (PMF.uniformOfFintype ((Q → D) × (Coins × Coins))).toOuterMeasure
          {p | runIdx P W p.1 j (Function.update (extend r.1) j p.2) Dist 0 = true}
        = (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (ctx₂ P pOC j N (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run p.1)
            (P.prove p.1 W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1)) p.2)).run p.1 = true}
      ∧ (PMF.uniformOfFintype ((Q → D) × (Coins × Coins))).toOuterMeasure
          {p | runIdx P W p.1 (j + 1) (Function.update (extend r.1) j p.2) Dist 0 = true}
        = (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (ctx₂ P pOC j N (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run p.1)
            (P.prove p.1 W (standin P W (M.publicPart (M.forward W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1))),
              P.leak (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1)))) p.2)).run p.1 = true} := by
    intro r
    constructor
    · refine Eq.trans ?_ (prob_coin_fst (C₂ := Coins) (fun H c₁ =>
        (ctx₂ P pOC j N (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H)
          (P.prove H W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H)) c₁)).run H = true))
      congr 1
      ext p
      simp only [Set.mem_ofPred_eq]
      rw [runIdx_split P W pOC qp hrun hbd p.1 j N (extend r.1) p.2 Dist q R 0 hD le_rfl (Nat.zero_le _)]
    · refine Eq.trans ?_ (prob_coin_snd (C₁ := Coins) (fun H c₂ =>
        (ctx₂ P pOC j N (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H)
          (P.prove H W (standin P W (M.publicPart (M.forward W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H))),
            P.leak (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H)))) c₂)).run H = true))
      congr 1
      ext p
      simp only [Set.mem_ofPred_eq]
      rw [runIdx_split_succ P W pOC qp hrun hbd p.1 j N (extend r.1) p.2 Dist q R 0 hD le_rfl (Nat.zero_le _)]
  have hA₁ : ∀ r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀},
      (pre P W pOC j (extend r.1) Dist 0).Bounded (q + j * qp) := by
    intro r
    have h := pre_bounded P W pOC qp hbd j (extend r.1) Dist q R 0 hD (Nat.zero_le _)
    rwa [Nat.sub_zero] at h
  have hA₂ : ∀ (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) a o,
      (ctx₂ P pOC j N (extend r.1) a o).Bounded N := by
    intro r a o
    cases a with
    | inl b => trivial
    | inr p => exact trunc_bounded _ N
  constructor
  · refine prob_le_of_forall_fst
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 j (Function.update (extend r.1) j x.2) Dist 0 = true)
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 (j + 1) (Function.update (extend r.1) j x.2) Dist 0 = true) _ (fun r => ?_)
    obtain ⟨h1, h2⟩ := hfib r
    rw [h1, h2]
    exact (hone _ (pre P W pOC j (extend r.1) Dist 0) (q + j * qp) (hA₁ r) (xOf P)
      (ctx₂ P pOC j N (extend r.1)) N (hA₂ r)).1
  · refine prob_le_of_forall_fst
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 (j + 1) (Function.update (extend r.1) j x.2) Dist 0 = true)
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 j (Function.update (extend r.1) j x.2) Dist 0 = true) _ (fun r => ?_)
    obtain ⟨h1, h2⟩ := hfib r
    rw [h1, h2]
    exact (hone _ (pre P W pOC j (extend r.1) Dist 0) (q + j * qp) (hA₁ r) (xOf P)
      (ctx₂ P pOC j N (extend r.1)) N (hA₂ r)).2

end StandinHybrid

/-! ## Zero knowledge from one receipt -/

section ZK

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **Zero knowledge from one receipt's step.** If the honest prover is a query-bounded oracle computation (`qp`
queries) and, for every weight set, one receipt in any context costs at most `ε q₁ q₂` (`OneStep`), then the protocol
is zero knowledge with the stand-in simulator and error `Σ_{j<R} ε (q + j·qp) (q + R·qp)`. -/
theorem zeroKnowledge_of_oneStep (pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (qp : ℕ)
    (hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c) (hbd : ∀ W x c, (pOC W x c).Bounded qp)
    (ε : ℕ → ℕ → ℝ≥0∞) (hone : ∀ W, OneStep P W ε) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, ε (q + j * qp) (q + R * qp)) :=
  zeroKnowledge_of_hybrid_R (standinSim P) (fun q R j => ε (q + j * qp) (q + R * qp))
    (fun W q R Dist hD j hj => hstep_of_oneStep P W (pOC W) qp (hrun W) (hbd W) ε (hone W) q R Dist hD j hj)

omit [Inhabited Coins] in
open Classical in
/-- **`OneStep` from a Fiat–Shamir receipt model** (`ZKW16Step.fs_step` with the flag `true`): if the protocol's
prover is the model's honest prover, the receipts on an input and on its stand-in have the same honest-verifier law at
every value vector, and the counting hypotheses hold, one receipt costs at most
`2(q₁·K + 2·Kc)/|C × D^k| + 2·q₂·KU/|C|`. -/
theorem oneStep_of_fsModel [Inhabited D] (W : M.Weights) (FM : FSModel Q D M.Input Coins (P.Stmt × P.Receipt))
    (hP : ∀ H x c, P.prove H W x c = FM.prove H x c)
    (hHV : ∀ x (v : Fin FM.k → D), (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
      = (PMF.uniformOfFintype Coins).map
          (fun c => FM.out (standin P W (M.publicPart (M.forward W x), P.leak x)) c v))
    (K Kc KU : ℕ)
    (hK : ∀ x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ K)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hU : ∀ (q₂ : ℕ) x (H : Q → D) (v : Fin FM.k → D) (Z : (P.Stmt × P.Receipt) → Finset Q),
      (∀ o, (Z o).card ≤ q₂) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Z (FM.out x c v))).card ≤ q₂ * KU) :
    OneStep P W (fun q₁ q₂ => (((2 * (q₁ * K + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → D))
      + (((2 * (q₂ * KU)) : ℕ) : ℝ≥0∞) / Fintype.card Coins) := by
  intro α A₁ q₁ hA₁ x A₂ q₂ hA₂
  have hstd := FSModel.fs_step FM A₁ q₁ hA₁ x
    (fun a => standin P W (M.publicPart (M.forward W (x a)), P.leak (x a)))
    (fun a v => hHV (x a) v) K Kc KU q₂ hK hKc (hU q₂) A₂ hA₂ (fun _ => True)
  beta_reduce at hstd
  have hset : ∀ u : α → M.Input, {p : (Q → D) × Coins | FM.realEv A₁ u A₂ (fun _ => True) p}
      = {p | (A₂ (A₁.run p.1) (P.prove p.1 W (u (A₁.run p.1)) p.2)).run p.1 = true} := by
    intro u
    ext p
    simp only [Set.mem_ofPred_eq, FSModel.realEv, true_and, hP]
  have hone : (PMF.uniformOfFintype (Q → D)).toOuterMeasure {_H : Q → D | True} = 1 :=
    (PMF.toOuterMeasure_apply_eq_one_iff _ _).mpr (fun _ _ => trivial)
  rw [hset, hset, hone] at hstd
  simp only [one_mul] at hstd
  exact hstd

end ZK

end ZK60.ZKW16
