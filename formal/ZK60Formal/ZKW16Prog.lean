/-
D63 step L14 (Statement 2, zero knowledge), part 1: programming the random oracle at CHAIN points.

`ZKHybrid.lean`'s programming lemma (`program_real_ideal`) programs `k` points `y a σ` that are functions of the
distinguisher's state `a` and a fresh salt `σ` only. The code's Fiat–Shamir points are not of that form: every
transcript point is `H(key; state ‖ item)` where `state` is the PREVIOUS hash output (`ExecTranscript.lean`: an absorb
`H(key; s ‖ le64|label| ‖ label ‖ le64|data| ‖ data)`, a squeeze `H(key; s ‖ "squeeze" ‖ le64 ctr)`), and a Merkle node's
point holds its children's digests. The points form a CHAIN: point `i` depends on the values at the points before it.
Finding A5's route (a) and assembly §4.5 (a) suggested first replacing "the first fresh chain digest by a uniform
value"; this file does the whole chain at once instead, with one exact coupling.

* `Causal`, `chainVals`, `chainVals_fix`, `chainVals_unique`: points causal in the values (point `i` reads only the
  values before `i`); the honest computation's values `w = chainVals y H` are the unique solution of `w i = H(y w i)`.
* The worlds (`apReal`, `apIdeal`), on one space `(H, (σ, v))`: the honest world uses the chain `w` of `H` (the extra
  `v` unused); the programmed world uses fresh uniform values `v` and the oracle `H` programmed at the points `y v` to
  answer `v`. The points may read the oracle at a dependency set `dep` (the column hashes, keyed differently by D19
  T-1, and the public header's chain points; `hsep`); a programmed point landing in it is a bad event, counted with
  the collisions. The distinguisher's part before the request `A₁` is a query-bounded computation.
* `apPsi`, `apPhi`, `apPsi_spec`, `apPhi_spec`: the coupling `(H, σ, v) ↦ (H[y(w) := v], σ, w)` and its inverse
  `(H, σ, v) ↦ (H[y(v) := v], σ, H ∘ y(v))` are mutually inverse BIJECTIONS between the good sets (the points distinct,
  not asked by `A₁`, outside `dep`), and on them they carry the real world's event to the programmed world's.
  (Unlike `progSwap`, this is not an involution: the chain moves with the oracle.)
* `apCount`, **`aprog_real_ideal`**: for any flag `F` of `A₁`'s result (used to cut a hybrid at its `j`-th request),
  `Pr[F ∧ real] ≤ Pr[F ∧ programmed] + Pr_H[F]·(q₁·K + Kc)/|S × D^k|` and back, where `K` bounds, for one query `z`,
  how many `(σ, v)` put some point at `z` (`hK`) and `Kc` how many make two points collide or put one in `dep`
  (`hKc`). Nothing about the
  queries after the request (`A₂`) is needed.
* `apReal_marginal`: the real world's probability over `(H, σ)` alone.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ZKHybrid

namespace ZK60.ZKW16

open scoped ENNReal
open Finset

/-! ## Uniform probabilities as counts -/

/-- A uniform event's probability is its count over the space's size. -/
theorem prob_filter {Ω : Type} [Fintype Ω] [Nonempty Ω] (p : Ω → Prop) [DecidablePred p] :
    (PMF.uniformOfFintype Ω).toOuterMeasure {ω | p ω} = ((univ.filter p).card : ℝ≥0∞) / Fintype.card Ω := by
  have h : ({ω | p ω} : Set Ω) = ↑(univ.filter p) := by ext; simp
  rw [h, PMF.toOuterMeasure_apply_finset]
  simp [PMF.uniformOfFintype_apply, Finset.sum_const, nsmul_eq_mul, div_eq_mul_inv]

/-- A count on a product is the sum of the fibre counts. -/
theorem card_filter_prod {β γ : Type} [Fintype β] [Fintype γ] (p : β × γ → Prop) [DecidablePred p] :
    (univ.filter p).card = ∑ b : β, (univ.filter (fun c : γ => p (b, c))).card := by
  rw [card_filter, Fintype.sum_prod_type]
  refine sum_congr rfl (fun b _ => ?_)
  rw [card_filter]

/-! ## The chain of an honest computation -/

section Chain

variable {Q D : Type} {k : ℕ}

/-- **Causal points**: point `i` depends on the values only through the values before `i` (a transcript point holds
the previous state; a Merkle node's point holds its children). -/
def Causal (y : (Fin k → D) → Fin k → Q) : Prop :=
  ∀ (v v' : Fin k → D) (i : Fin k), (∀ j : Fin k, j < i → v j = v' j) → y v i = y v' i

/-- One pass: every value becomes the oracle's answer at its point. -/
def chainStep (y : (Fin k → D) → Fin k → Q) (H : Q → D) (v : Fin k → D) : Fin k → D := fun i => H (y v i)

/-- **The honest chain**: `k` passes from a fixed start. For causal points it is the values the honest computation
obtains by asking the oracle at each point in order (`chainVals_fix`, `chainVals_unique`). -/
def chainVals [Inhabited D] (y : (Fin k → D) → Fin k → Q) (H : Q → D) : Fin k → D :=
  (chainStep y H)^[k] (fun _ => default)

theorem chainStep_stable [Inhabited D] {y : (Fin k → D) → Fin k → Q} (hy : Causal y) (H : Q → D) :
    ∀ m (i : Fin k), (i : ℕ) < m →
      (chainStep y H)^[m + 1] (fun _ => default) i = (chainStep y H)^[m] (fun _ => default) i := by
  intro m
  induction m with
  | zero => intro i hi; exact absurd hi (Nat.not_lt_zero _)
  | succ m ih =>
    intro i hi
    have e1 : (chainStep y H)^[m + 1 + 1] (fun _ => default)
        = chainStep y H ((chainStep y H)^[m + 1] (fun _ => default)) :=
      Function.iterate_succ_apply' _ _ _
    have e2 : (chainStep y H)^[m + 1] (fun _ => default)
        = chainStep y H ((chainStep y H)^[m] (fun _ => default)) :=
      Function.iterate_succ_apply' _ _ _
    rw [e1]
    conv_rhs => rw [e2]
    show H (y _ i) = H (y _ i)
    rw [hy _ _ i (fun j hj => ih j (by have h1 : (j : ℕ) < i := hj; omega))]

/-- The honest chain is a fixed point: each value is the oracle's answer at its own point. -/
theorem chainVals_fix [Inhabited D] {y : (Fin k → D) → Fin k → Q} (hy : Causal y) (H : Q → D) (i : Fin k) :
    chainVals y H i = H (y (chainVals y H) i) := by
  have h := chainStep_stable hy H k i i.isLt
  rw [Function.iterate_succ_apply'] at h
  exact h.symm

/-- **The fixed point is unique** (causality): any values that are the oracle's answers at their own points are the
honest chain. -/
theorem chainVals_unique [Inhabited D] {y : (Fin k → D) → Fin k → Q} (hy : Causal y) (H : Q → D)
    (v : Fin k → D) (hv : ∀ i, v i = H (y v i)) : v = chainVals y H := by
  have key : ∀ n (i : Fin k), (i : ℕ) < n → v i = chainVals y H i := by
    intro n
    induction n with
    | zero => intro i hi; exact absurd hi (Nat.not_lt_zero _)
    | succ n ih =>
      intro i hi
      rw [hv i, chainVals_fix hy H i,
        hy v (chainVals y H) i (fun j hj => ih j (by have h1 : (j : ℕ) < i := hj; omega))]
  funext i
  exact key k i i.isLt

end Chain

/-! ## Programming a chain -/

section Prog

variable {Q D S α : Type} [DecidableEq Q] [Inhabited D] {k : ℕ}

/-- **The honest world**: the receipt's values are the honest chain of the oracle `H` (the third coordinate is
unused). -/
def apReal (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (ω : (Q → D) × (S × (Fin k → D))) : Prop :=
  (A₂ (A₁.run ω.1) ω.2.1 (chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1)).run ω.1 = true

/-- **The programmed world**: fresh values `v`, and after `A₁` the oracle answers `v i` at the point `y v i`. -/
def apIdeal (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (ω : (Q → D) × (S × (Fin k → D))) : Prop :=
  (A₂ (A₁.run ω.1) ω.2.1 ω.2.2).run (ZKHybrid.program (y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2) ω.2.2 ω.1) = true

/-- The programmed world's good set: the points of `v` are distinct, `A₁` asked none of them, and none is a point the
points read (`dep`). -/
def apGoodI (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α) (dep : α → S → Set Q)
    (ω : (Q → D) × (S × (Fin k → D))) : Prop :=
  Function.Injective (y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2) ∧ (∀ i, y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2 i ∉ OC.queries ω.1 A₁)
    ∧ ∀ i, y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2 i ∉ dep (A₁.run ω.1) ω.2.1

/-- The honest world's good set: the points of the honest chain are distinct, `A₁` asked none of them, and none is a
point the points read. -/
def apGoodR (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α) (dep : α → S → Set Q)
    (ω : (Q → D) × (S × (Fin k → D))) : Prop :=
  Function.Injective (y (A₁.run ω.1) ω.2.1 ω.1 (chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1))
    ∧ (∀ i, y (A₁.run ω.1) ω.2.1 ω.1 (chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1) i ∉ OC.queries ω.1 A₁)
    ∧ ∀ i, y (A₁.run ω.1) ω.2.1 ω.1 (chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1) i ∉ dep (A₁.run ω.1) ω.2.1

/-- **The coupling**: store the fresh values at the honest chain's points and hand the honest chain over as the
fresh values. -/
noncomputable def apPsi (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α)
    (ω : (Q → D) × (S × (Fin k → D))) : (Q → D) × (S × (Fin k → D)) :=
  (ZKHybrid.program (y (A₁.run ω.1) ω.2.1 ω.1 (chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1)) ω.2.2 ω.1,
    (ω.2.1, chainVals (y (A₁.run ω.1) ω.2.1 ω.1) ω.1))

/-- **Its inverse**: program the fresh values at their points and hand the oracle's old answers back. -/
noncomputable def apPhi (y : α → S → (Q → D) → (Fin k → D) → Fin k → Q) (A₁ : OC Q D α)
    (ω : (Q → D) × (S × (Fin k → D))) : (Q → D) × (S × (Fin k → D)) :=
  (ZKHybrid.program (y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2) ω.2.2 ω.1,
    (ω.2.1, fun i => ω.1 (y (A₁.run ω.1) ω.2.1 ω.1 ω.2.2 i)))

variable {y : α → S → (Q → D) → (Fin k → D) → Fin k → Q} {A₁ : OC Q D α} {dep : α → S → Set Q}

omit [Inhabited D] in
/-- Programming at points outside the points' dependency set changes nothing on it. -/
theorem program_agree (a : α) (σ : S) (H : Q → D) (u v : Fin k → D) (hd : ∀ i, y a σ H u i ∉ dep a σ) :
    ∀ z ∈ dep a σ, H z = ZKHybrid.program (y a σ H u) v H z :=
  fun z hz => (ZKHybrid.program_off _ _ _ z (fun i hi => hd i (by rw [hi]; exact hz))).symm

omit [Inhabited D] in
/-- `A₁` runs and asks the same against an oracle programmed at points it did not ask. -/
theorem run_queries_program (A₁ : OC Q D α) (yy : Fin k → Q) (v : Fin k → D) (H : Q → D)
    (hq : ∀ i, yy i ∉ OC.queries H A₁) :
    A₁.run (ZKHybrid.program yy v H) = A₁.run H ∧ OC.queries (ZKHybrid.program yy v H) A₁ = OC.queries H A₁ := by
  have hlog := ZKHybrid.runLog_program yy v H A₁ hq
  refine ⟨?_, ?_⟩
  · rw [← OC.runLog_fst, hlog, OC.runLog_fst]
  · simp only [OC.queries, hlog]

/-- **The coupling on the honest good set**: its image is in the programmed good set, the inverse undoes it, it carries
the honest world's event to the programmed world's, and it keeps `A₁`'s result. -/
theorem apPsi_spec (hy : ∀ a σ H, Causal (y a σ H))
    (hsep : ∀ a σ (H H' : Q → D) v, (∀ z ∈ dep a σ, H z = H' z) → y a σ H v = y a σ H' v)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (ω : (Q → D) × (S × (Fin k → D))) (hG : apGoodR y A₁ dep ω) :
    apGoodI y A₁ dep (apPsi y A₁ ω) ∧ apPhi y A₁ (apPsi y A₁ ω) = ω
      ∧ (apIdeal y A₁ A₂ (apPsi y A₁ ω) ↔ apReal y A₁ A₂ ω) ∧ A₁.run (apPsi y A₁ ω).1 = A₁.run ω.1 := by
  obtain ⟨H, σ, v⟩ := ω
  obtain ⟨hinj, hq, hd⟩ := hG
  simp only at hinj hq hd
  have hw : ∀ i, chainVals (y (A₁.run H) σ H) H i
      = H (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H) i) := chainVals_fix (hy _ σ H) H
  obtain ⟨hrun, hqs⟩ := run_queries_program A₁ (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H)) v H hq
  have hyH : ∀ u, y (A₁.run H) σ (ZKHybrid.program (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H)) v H) u
      = y (A₁.run H) σ H u :=
    fun u => (hsep _ σ H _ u (program_agree _ σ H _ v hd)).symm
  have hback : ZKHybrid.program (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H))
      (chainVals (y (A₁.run H) σ H) H)
      (ZKHybrid.program (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H)) v H) = H := by
    funext z
    by_cases hz : ∃ i, y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H) i = z
    · obtain ⟨i, rfl⟩ := hz
      rw [ZKHybrid.program_at hinj, hw i]
    · have hz' : ∀ i, y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H) i ≠ z := fun i hi => hz ⟨i, hi⟩
      rw [ZKHybrid.program_off _ _ _ z hz', ZKHybrid.program_off _ _ _ z hz']
  have hval : (fun i => ZKHybrid.program (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H)) v H
      (y (A₁.run H) σ H (chainVals (y (A₁.run H) σ H) H) i)) = v := by
    funext i
    exact ZKHybrid.program_at hinj v H i
  refine ⟨⟨?_, ?_, ?_⟩, ?_, ?_, hrun⟩
  · show Function.Injective (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
      (chainVals (y (A₁.run H) σ H) H))
    rw [hrun, hyH]
    exact hinj
  · intro i
    show y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H) (chainVals (y (A₁.run H) σ H) H) i
      ∉ OC.queries (ZKHybrid.program _ v H) A₁
    rw [hrun, hyH, hqs]
    exact hq i
  · intro i
    show y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H) (chainVals (y (A₁.run H) σ H) H) i
      ∉ dep (A₁.run (ZKHybrid.program _ v H)) σ
    rw [hrun, hyH]
    exact hd i
  · show (ZKHybrid.program (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
        (chainVals (y (A₁.run H) σ H) H)) (chainVals (y (A₁.run H) σ H) H) (ZKHybrid.program _ v H),
      (σ, fun i => ZKHybrid.program _ v H (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
        (chainVals (y (A₁.run H) σ H) H) i))) = (H, (σ, v))
    rw [hrun, hyH, hback, hval]
  · show (A₂ (A₁.run (ZKHybrid.program _ v H)) σ (chainVals (y (A₁.run H) σ H) H)).run
        (ZKHybrid.program (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
          (chainVals (y (A₁.run H) σ H) H)) (chainVals (y (A₁.run H) σ H) H) (ZKHybrid.program _ v H)) = true
      ↔ (A₂ (A₁.run H) σ (chainVals (y (A₁.run H) σ H) H)).run H = true
    rw [hrun, hyH, hback]

/-- **The inverse on the programmed good set**: its image is in the honest good set, the coupling undoes it, and it
keeps `A₁`'s result. -/
theorem apPhi_spec (hy : ∀ a σ H, Causal (y a σ H))
    (hsep : ∀ a σ (H H' : Q → D) v, (∀ z ∈ dep a σ, H z = H' z) → y a σ H v = y a σ H' v)
    (ω : (Q → D) × (S × (Fin k → D))) (hG : apGoodI y A₁ dep ω) :
    apGoodR y A₁ dep (apPhi y A₁ ω) ∧ apPsi y A₁ (apPhi y A₁ ω) = ω ∧ A₁.run (apPhi y A₁ ω).1 = A₁.run ω.1 := by
  obtain ⟨H, σ, v⟩ := ω
  obtain ⟨hinj, hq, hd⟩ := hG
  simp only at hinj hq hd
  obtain ⟨hrun, hqs⟩ := run_queries_program A₁ (y (A₁.run H) σ H v) v H hq
  have hyH : ∀ u, y (A₁.run H) σ (ZKHybrid.program (y (A₁.run H) σ H v) v H) u = y (A₁.run H) σ H u :=
    fun u => (hsep _ σ H _ u (program_agree _ σ H v v hd)).symm
  have hch : chainVals (y (A₁.run H) σ (ZKHybrid.program (y (A₁.run H) σ H v) v H))
      (ZKHybrid.program (y (A₁.run H) σ H v) v H) = v := by
    refine (chainVals_unique (hy _ σ _) _ v (fun i => ?_)).symm
    rw [hyH, ZKHybrid.program_at hinj]
  have hback : ZKHybrid.program (y (A₁.run H) σ H v) (fun i => H (y (A₁.run H) σ H v i))
      (ZKHybrid.program (y (A₁.run H) σ H v) v H) = H := by
    funext z
    by_cases hz : ∃ i, y (A₁.run H) σ H v i = z
    · obtain ⟨i, rfl⟩ := hz
      rw [ZKHybrid.program_at hinj]
    · have hz' : ∀ i, y (A₁.run H) σ H v i ≠ z := fun i hi => hz ⟨i, hi⟩
      rw [ZKHybrid.program_off _ _ _ z hz', ZKHybrid.program_off _ _ _ z hz']
  refine ⟨⟨?_, ?_, ?_⟩, ?_, hrun⟩
  · show Function.Injective (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
      (chainVals (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)) (ZKHybrid.program _ v H)))
    rw [hrun, hch, hyH]
    exact hinj
  · intro i
    show y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
      (chainVals (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)) (ZKHybrid.program _ v H)) i
        ∉ OC.queries (ZKHybrid.program _ v H) A₁
    rw [hrun, hch, hyH, hqs]
    exact hq i
  · intro i
    show y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
      (chainVals (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)) (ZKHybrid.program _ v H)) i
        ∉ dep (A₁.run (ZKHybrid.program _ v H)) σ
    rw [hrun, hch, hyH]
    exact hd i
  · show (ZKHybrid.program (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)
        (chainVals (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)) (ZKHybrid.program _ v H)))
        (fun i => H (y (A₁.run H) σ H v i)) (ZKHybrid.program _ v H),
      (σ, chainVals (y (A₁.run (ZKHybrid.program _ v H)) σ (ZKHybrid.program _ v H)) (ZKHybrid.program _ v H)))
      = (H, (σ, v))
    rw [hrun, hch, hyH, hback]

/-! ### Counting -/

open Classical in
/-- **The two worlds' counts**, cut by a flag of `A₁`'s result: each is at most the other plus the count of the
programmed world's bad set. -/
theorem apCount [Fintype Q] [Fintype D] [Fintype S] (hy : ∀ a σ H, Causal (y a σ H))
    (hsep : ∀ a σ (H H' : Q → D) v, (∀ z ∈ dep a σ, H z = H' z) → y a σ H v = y a σ H' v)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (F : α → Prop) :
    (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω)).card
        ≤ (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω)).card
          + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card
      ∧ (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω)).card
        ≤ (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω)).card
          + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card := by
  classical
  -- the good parts correspond
  have hsr : (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => (F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω) ∧ apGoodR y A₁ dep ω)).card
      = (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => (F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω) ∧ apGoodI y A₁ dep ω)).card := by
    refine card_nbij' (apPsi y A₁) (apPhi y A₁) ?_ ?_ ?_ ?_
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω ⊢
      obtain ⟨hG', -, hid, hrun⟩ := apPsi_spec hy hsep A₂ ω hω.2
      exact ⟨⟨by rw [hrun]; exact hω.1.1, hid.mpr hω.1.2⟩, hG'⟩
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω ⊢
      obtain ⟨hG', hpp, hrun⟩ := apPhi_spec hy hsep ω hω.2
      obtain ⟨-, -, hid, -⟩ := apPsi_spec hy hsep A₂ (apPhi y A₁ ω) hG'
      rw [hpp] at hid
      exact ⟨⟨by rw [hrun]; exact hω.1.1, hid.mp hω.1.2⟩, hG'⟩
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω
      exact (apPsi_spec hy hsep A₂ ω hω.2).2.1
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω
      exact (apPhi_spec hy hsep ω hω.2).2.1
  have hsg : (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apGoodR y A₁ dep ω)).card
      = (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apGoodI y A₁ dep ω)).card := by
    refine card_nbij' (apPsi y A₁) (apPhi y A₁) ?_ ?_ ?_ ?_
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω ⊢
      obtain ⟨hG', -, -, hrun⟩ := apPsi_spec hy hsep A₂ ω hω.2
      exact ⟨by rw [hrun]; exact hω.1, hG'⟩
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω ⊢
      obtain ⟨hG', -, hrun⟩ := apPhi_spec hy hsep ω hω.2
      exact ⟨by rw [hrun]; exact hω.1, hG'⟩
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω
      exact (apPsi_spec hy hsep A₂ ω hω.2).2.1
    · intro ω hω
      simp only [mem_coe, mem_filter, mem_univ, true_and] at hω
      exact (apPhi_spec hy hsep ω hω.2).2.1
  -- so the bad parts have equal counts
  have hsplit : ∀ G : (Q → D) × (S × (Fin k → D)) → Prop,
      (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ G ω)).card + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ G ω)).card
        = (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1))).card := by
    intro G
    rw [← card_filter_add_card_filter_not (s := univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1))) G,
      filter_filter, filter_filter]
  have hbad : (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodR y A₁ dep ω)).card
      = (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card := by
    have h1 := hsplit (apGoodR y A₁ dep)
    have h2 := hsplit (apGoodI y A₁ dep)
    omega
  -- an event with the flag is its good part plus at most the bad part
  have hcover : ∀ (E G : (Q → D) × (S × (Fin k → D)) → Prop),
      (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ E ω)).card
        ≤ (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => (F (A₁.run ω.1) ∧ E ω) ∧ G ω)).card
          + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ G ω)).card := by
    intro E G
    refine (card_le_card ?_).trans (card_union_le _ _)
    intro ω hω
    simp only [mem_filter, mem_univ, true_and, mem_union] at hω ⊢
    by_cases hg : G ω
    · exact Or.inl ⟨hω, hg⟩
    · exact Or.inr ⟨hω.1, hg⟩
  have hsub : ∀ (E G : (Q → D) × (S × (Fin k → D)) → Prop),
      (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => (F (A₁.run ω.1) ∧ E ω) ∧ G ω)).card
        ≤ (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ E ω)).card := by
    intro E G
    refine card_le_card (fun ω hω => ?_)
    simp only [mem_filter, mem_univ, true_and] at hω ⊢
    exact hω.1
  constructor
  · have a1 := hcover (apReal y A₁ A₂) (apGoodR y A₁ dep)
    have a2 := hsub (apIdeal y A₁ A₂) (apGoodI y A₁ dep)
    omega
  · have a1 := hcover (apIdeal y A₁ A₂) (apGoodI y A₁ dep)
    have a2 := hsub (apReal y A₁ A₂) (apGoodR y A₁ dep)
    omega

omit [Inhabited D] in
open Classical in
/-- **The bad set is small**, fibre by fibre: for an `A₁` of at most `q₁` queries, if one query is hit by some point for
at most `K` of the `(σ, v)` and two points collide for at most `Kc` of them, the flagged bad count is at most the flagged
oracle count times `q₁·K + Kc`. -/
theorem apBad_card [Fintype Q] [Fintype D] [Fintype S] (A₁ : OC Q D α) (q₁ : ℕ) (hA₁ : A₁.Bounded q₁) (K Kc : ℕ)
    (hK : ∀ a (H : Q → D) z, (univ.filter (fun s : S × (Fin k → D) => ∃ i, y a s.1 H s.2 i = z)).card ≤ K)
    (hKc : ∀ a (H : Q → D), (univ.filter (fun s : S × (Fin k → D) =>
      ¬ Function.Injective (y a s.1 H s.2) ∨ ∃ i, y a s.1 H s.2 i ∈ dep a s.1)).card ≤ Kc)
    (F : α → Prop) :
    (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (q₁ * K + Kc) := by
  classical
  rw [card_filter_prod]
  have hfib : ∀ H : Q → D, (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
      ≤ if F (A₁.run H) then q₁ * K + Kc else 0 := by
    intro H
    by_cases hF : F (A₁.run H)
    · rw [ite_eq_left hF]
      set L := OC.queries H A₁
      have hLlen : L.toFinset.card ≤ q₁ := (List.toFinset_card_le _).trans (OC.length_queries_le H A₁ q₁ hA₁)
      have hsub : univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))
          ⊆ L.toFinset.biUnion (fun z => univ.filter (fun s : S × (Fin k → D) => ∃ i, y (A₁.run H) s.1 H s.2 i = z))
            ∪ univ.filter (fun s : S × (Fin k → D) => ¬ Function.Injective (y (A₁.run H) s.1 H s.2)
              ∨ ∃ i, y (A₁.run H) s.1 H s.2 i ∈ dep (A₁.run H) s.1) := by
        intro s hs
        simp only [mem_filter, mem_univ, true_and, apGoodI, not_and_or, not_forall, not_not] at hs
        simp only [mem_union, mem_biUnion, List.mem_toFinset, mem_filter, mem_univ, true_and]
        rcases hs.2 with h | ⟨i, hi⟩ | ⟨i, hi⟩
        · exact Or.inr (Or.inl h)
        · exact Or.inl ⟨_, hi, i, rfl⟩
        · exact Or.inr (Or.inr ⟨i, hi⟩)
      calc (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
          ≤ (L.toFinset.biUnion (fun z => univ.filter (fun s : S × (Fin k → D) =>
                ∃ i, y (A₁.run H) s.1 H s.2 i = z))).card
              + (univ.filter (fun s : S × (Fin k → D) => ¬ Function.Injective (y (A₁.run H) s.1 H s.2)
                ∨ ∃ i, y (A₁.run H) s.1 H s.2 i ∈ dep (A₁.run H) s.1)).card :=
            (card_le_card hsub).trans (card_union_le _ _)
        _ ≤ (∑ _z ∈ L.toFinset, K) + Kc :=
            Nat.add_le_add (card_biUnion_le.trans (sum_le_sum (fun z _ => hK _ H z))) (hKc _ H)
        _ = L.toFinset.card * K + Kc := by rw [sum_const, smul_eq_mul]
        _ ≤ q₁ * K + Kc := Nat.add_le_add_right (Nat.mul_le_mul_right _ hLlen) _
    · rw [ite_eq_right hF]
      refine Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
  calc ∑ H : Q → D, (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then q₁ * K + Kc else 0) := sum_le_sum (fun H _ => hfib H)
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * (q₁ * K + Kc) := by
        rw [← sum_filter, sum_const, smul_eq_mul]

open Classical in
/-- **The chain-programming lemma.** For an `A₁` of at most `q₁` queries before the request, points causal in the
values that read the rest of the oracle only at `dep` (`hsep`), and any flag `F` of `A₁`'s result:
the honest world and the programmed world differ, in both directions, by at most `Pr_H[F]·(q₁·K + Kc)/|S × D^k|`,
whatever the rest of the distinguisher does. With `F` true: `(q₁·K + Kc)/|S × D^k|`. -/
theorem aprog_real_ideal [Fintype Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    (hy : ∀ a σ H, Causal (y a σ H))
    (hsep : ∀ a σ (H H' : Q → D) v, (∀ z ∈ dep a σ, H z = H' z) → y a σ H v = y a σ H' v)
    (q₁ : ℕ) (hA₁ : A₁.Bounded q₁) (K Kc : ℕ)
    (hK : ∀ a (H : Q → D) z, (univ.filter (fun s : S × (Fin k → D) => ∃ i, y a s.1 H s.2 i = z)).card ≤ K)
    (hKc : ∀ a (H : Q → D), (univ.filter (fun s : S × (Fin k → D) =>
      ¬ Function.Injective (y a s.1 H s.2) ∨ ∃ i, y a s.1 H s.2 i ∈ dep a s.1)).card ≤ Kc)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure
        {ω | F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω}
      ≤ (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure
          {ω | F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω}
        + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
          * (((q₁ * K + Kc : ℕ) : ℝ≥0∞) / Fintype.card (S × (Fin k → D)))
    ∧ (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure
        {ω | F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω}
      ≤ (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure
          {ω | F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω}
        + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
          * (((q₁ * K + Kc : ℕ) : ℝ≥0∞) / Fintype.card (S × (Fin k → D))) := by
  classical
  obtain ⟨c1, c2⟩ := apCount (A₁ := A₁) (dep := dep) hy hsep A₂ F
  have hb := apBad_card (y := y) (dep := dep) A₁ q₁ hA₁ K Kc hK hKc F
  set NH := Fintype.card (Q → D)
  set NS := Fintype.card (S × (Fin k → D))
  have hNH0 : (NH : ℝ≥0∞) ≠ 0 := by simp [NH]
  have hNS0 : (NS : ℝ≥0∞) ≠ 0 := by simp [NS]
  have hNHt : (NH : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hNSt : (NS : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hΩ : Fintype.card ((Q → D) × (S × (Fin k → D))) = NH * NS := Fintype.card_prod _ _
  have hbad : ((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card
        : ℝ≥0∞) / Fintype.card ((Q → D) × (S × (Fin k → D)))
      ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
          * (((q₁ * K + Kc : ℕ) : ℝ≥0∞) / NS) := by
    rw [prob_filter, hΩ]
    calc ((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card
          : ℝ≥0∞) / ((NH * NS : ℕ) : ℝ≥0∞)
        ≤ (((univ.filter (fun H : Q → D => F (A₁.run H))).card * (q₁ * K + Kc) : ℕ) : ℝ≥0∞)
            / ((NH * NS : ℕ) : ℝ≥0∞) := by
          gcongr
      _ = ((univ.filter (fun H : Q → D => F (A₁.run H))).card : ℝ≥0∞) / NH
            * (((q₁ * K + Kc : ℕ) : ℝ≥0∞) / NS) := by
          rw [Nat.cast_mul, Nat.cast_mul, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv,
            ENNReal.mul_inv (Or.inl hNH0) (Or.inl hNHt)]
          ring
  have hfin : ∀ (E : (Q → D) × (S × (Fin k → D)) → Prop),
      (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure {ω | F (A₁.run ω.1) ∧ E ω}
        = ((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ E ω)).card : ℝ≥0∞)
          / Fintype.card ((Q → D) × (S × (Fin k → D))) := fun E => prob_filter _
  rw [hfin, hfin]
  constructor
  · calc ((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω)).card : ℝ≥0∞)
          / Fintype.card ((Q → D) × (S × (Fin k → D)))
        ≤ (((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω)).card
              + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card : ℕ) : ℝ≥0∞)
            / Fintype.card ((Q → D) × (S × (Fin k → D))) := by
          gcongr
      _ = _ + _ := by rw [Nat.cast_add, ENNReal.add_div]
      _ ≤ _ := add_le_add le_rfl hbad
  · calc ((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apIdeal y A₁ A₂ ω)).card : ℝ≥0∞)
          / Fintype.card ((Q → D) × (S × (Fin k → D)))
        ≤ (((univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω)).card
              + (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card : ℕ) : ℝ≥0∞)
            / Fintype.card ((Q → D) × (S × (Fin k → D))) := by
          gcongr
      _ = _ + _ := by rw [Nat.cast_add, ENNReal.add_div]
      _ ≤ _ := add_le_add le_rfl hbad

/-- **The honest world over `(H, σ)` alone**: the unused third coordinate integrates out. -/
theorem apReal_marginal [Fintype Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × (S × (Fin k → D)))).toOuterMeasure {ω | F (A₁.run ω.1) ∧ apReal y A₁ A₂ ω}
      = (PMF.uniformOfFintype ((Q → D) × S)).toOuterMeasure
          {p | F (A₁.run p.1) ∧ (A₂ (A₁.run p.1) p.2 (chainVals (y (A₁.run p.1) p.2 p.1) p.1)).run p.1 = true} :=
  ZKHybrid.prob_marginal (Equiv.prodAssoc (Q → D) S (Fin k → D)).symm
    {p : (Q → D) × S | F (A₁.run p.1) ∧ (A₂ (A₁.run p.1) p.2 (chainVals (y (A₁.run p.1) p.2 p.1) p.1)).run p.1 = true}

end Prog

end ZK60.ZKW16
