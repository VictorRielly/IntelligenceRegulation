/-
D63 lane L20 (2026-11-07), part 1: **the per-position Fiat–Shamir count on the code's chain** (finding L16-1).

L8's `fs_code_chain_sound_sched` (`ExecComposeFS.lean`) and its knowledge version `fs_code_chain_sound_sched_log`
(`ExtractW16Chain.lean`) charge EVERY position of the joint run, the verifier's `ℓ + 1` included, the LARGEST
sub-protocol error `ε`: their bound is `(q + ℓ + 1)·ε + collisions`, so the query-free part is `(ℓ + 1)·ε`. For the
block (`ℓ ≈ 2^20`, `ε ≈ 2^-103` for LogUp's `α`, `2^-106` for `M`) that constant is about `2^-83`, above the approved
target's `2^-100` (L16-1). `FSPathWide.lean`'s `chain_sound_wide_seq` (finding F25) charges each verifier position its
OWN step's error. This file carries it to L8's schedule on the code's chain:

* `CSk`, `CSub.sk`: a sub-protocol's skeleton (window, rounds, error), what the charge reads (the state may read the
  prover's log; the skeleton may not);
* `Charged`, `chargeC`: **the charge of a step**: the step after a chain of whole steps, with head `h`, is charged the
  error of every sub-protocol whose round it STARTS (its window has started, its reader is between rounds and not
  frozen, the head is a squeeze of the round's width, the message flag agrees), capped at `εmax`. An absorb, an
  interstitial squeeze, a frozen sub-protocol's item, and the continuation of a wide challenge are charged nothing;
* `potRd`, `potS`, `potW`, `potS_step`, **`vSumFrom_chargeC_le`**: the potential "rounds still owed": one item never
  raises it, a charged step lowers it by one, so along ANY chain the charges sum to at most `Σ_c n_c·ε_c` (the
  verifier's charge `B` of `chain_sound_wide_seq`, independent of the run's length);
* `rdAlive_charged`: a sub-protocol that is doomed at a step's end can be revived only by a charged step;
* `CodeRbrE`, **`allSt_rbr_pos`**, `everSt_rbr_pos`, `codeRbr_step_pos`: L8's `allSt_rbr` / `everSt_rbr` /
  `codeRbr_step` with the per-step error `chargeC` (the largest doomed sub-protocol's revival is charged at its own
  round);
* **`fs_code_chain_ever_log_pos`**, **`fs_code_chain_sound_sched_log_pos`**: L16's log-reading composition with the
  per-position count: the probability that some sub-protocol enters its window with a false claim and yet every
  sub-protocol is alive at the end is at most `q·εmax + Σ_c n_c·ε_c + collBound T + collBound (T + 1)`,
  `T = q + ℓ + 1`. The prover's `q` queries are charged the largest error; the verifier's whole chain costs
  `Σ_c n_c·ε_c`, NOT `(ℓ + 1)·εmax`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Chain
import ZK60Formal.FSPathWide

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open scoped ENNReal

/-! ## Sums of lists in `ℝ≥0∞` -/

section LSum

variable {α : Type}

theorem lsum_map_add (l : List α) (f g : α → ℝ≥0∞) :
    (l.map (fun x => f x + g x)).sum = (l.map f).sum + (l.map g).sum := by
  induction l with
  | nil => simp
  | cons a l ih =>
    simp only [List.map_cons, List.sum_cons, ih]
    exact add_add_add_comm _ _ _ _

theorem lsum_le_lsum {l : List α} {f g : α → ℝ≥0∞} (h : ∀ x ∈ l, f x ≤ g x) :
    (l.map f).sum ≤ (l.map g).sum := by
  induction l with
  | nil => simp
  | cons a l ih =>
    simp only [List.map_cons, List.sum_cons]
    exact add_le_add (h a List.mem_cons_self) (ih (fun x hx => h x (List.mem_cons_of_mem _ hx)))

theorem le_lsum_of_mem {l : List α} {f : α → ℝ≥0∞} {x : α} (hx : x ∈ l) : f x ≤ (l.map f).sum := by
  induction l with
  | nil => simp at hx
  | cons a l ih =>
    simp only [List.map_cons, List.sum_cons]
    rcases List.mem_cons.mp hx with rfl | hx
    · exact le_self_add
    · exact (ih hx).trans le_add_self

end LSum

/-! ## Skeletons and the charge of a step -/

/-- **A sub-protocol's skeleton**: its window, its rounds and its error. The per-position charge reads only this (a
sub-protocol's state may read the prover's log, its skeleton is the schedule's). -/
structure CSk where
  a : ℕ
  R : Rounds
  ε : ℝ≥0∞

/-- The skeleton of a sub-protocol. -/
def CSub.sk {D : Type} (c : CSub D) : CSk := ⟨c.a, c.R, c.ε⟩

section Charge

variable {D : Type}

/-- **The step after `τ`, with head `h`, starts a round of the sub-protocol `k`**: `τ` is whole steps, `k`'s window
has started, its reader is between rounds and not frozen, and `h` is a squeeze of the round's width with the message
flag agreeing (exactly the case in which `rdAlive_step` charges `k`'s error). -/
def Charged (W : UInt64 → ℕ) (k : CSk) (τ : List (TItem × D)) (h : TItem) : Prop :=
  k.a ≤ τ.length ∧ tRem W τ = some 0 ∧ ∃ (ptr : List (List UInt8 × List D)) (pm : Option (List UInt8)),
    cRd k.R W (τ.drop k.a) = some (ptr, pm, []) ∧ ptr.length < k.R.n ∧ k.R.hasMsg ptr.length = pm.isSome
    ∧ ∃ kk, h = .squeeze kk ∧ W kk = k.R.w ptr.length

open Classical in
/-- **The charge of a step** (the per-position count): the errors of the sub-protocols whose round the step starts,
capped at `εmax`. -/
noncomputable def chargeC (W : UInt64 → ℕ) (sk : List CSk) (εmax : ℝ≥0∞) (τ : List (TItem × D)) (h : TItem) :
    ℝ≥0∞ :=
  min εmax (sk.map (fun k => if Charged W k τ h then k.ε else 0)).sum

/-- The charge never exceeds the cap. -/
theorem chargeC_le_max (W : UInt64 → ℕ) (sk : List CSk) (εmax : ℝ≥0∞) (τ : List (TItem × D)) (h : TItem) :
    chargeC W sk εmax τ h ≤ εmax := by
  unfold chargeC
  exact min_le_left _ _

/-- **The rounds a reading still owes** (a round in progress already paid for). -/
def potRd (n : ℕ) : CRS D → ℕ
  | none => 0
  | some (ptr, _, []) => n - ptr.length
  | some (ptr, _, _ :: _) => n - ptr.length - 1

/-- **A sub-protocol's potential on a chain**: all its rounds before its window, then what its reader owes. -/
def potS (W : UInt64 → ℕ) (k : CSk) (τ : List (TItem × D)) : ℕ :=
  if τ.length < k.a then k.R.n else potRd k.R.n (cRd k.R W (τ.drop k.a))

/-- The schedule's potentials, weighted by the errors. -/
noncomputable def potW (W : UInt64 → ℕ) (sk : List CSk) (τ : List (TItem × D)) : ℝ≥0∞ :=
  (sk.map (fun k => (potS W k τ : ℝ≥0∞) * k.ε)).sum

theorem potS_nil (W : UInt64 → ℕ) (k : CSk) : potS W k ([] : List (TItem × D)) = k.R.n := by
  unfold potS
  split_ifs
  · rfl
  · simp [cRd, potRd]

theorem potW_nil (W : UInt64 → ℕ) (sk : List CSk) :
    potW W sk ([] : List (TItem × D)) = (sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum := by
  unfold potW
  simp only [potS_nil]

/-- **One item never raises a reading's potential.** -/
theorem potRd_step (R : Rounds) (W : UInt64 → ℕ) (st : CRS D) (e : TItem × D) :
    potRd R.n (cRdStep R W st e) ≤ potRd R.n st := by
  rcases st with _ | ⟨ptr, pm, ds⟩
  · exact le_rfl
  obtain ⟨it, dg⟩ := e
  by_cases hn : R.n ≤ ptr.length
  · have h : cRdStep R W (some (ptr, pm, ds)) (it, dg) = some (ptr, pm, ds) := by
      cases it <;> simp [cRdStep, hn]
    rw [h]
  · cases it with
    | absorb l x =>
      simp only [cRdStep, hn, ↓reduceIte]
      split
      · split_ifs
        · simp only [potRd]
          exact le_rfl
        · exact Nat.zero_le _
      · exact Nat.zero_le _
    | squeeze kk =>
      simp only [cRdStep, hn, ↓reduceIte]
      split_ifs
      · cases ds with
        | nil => simp only [potRd, List.length_append, List.length_singleton]; omega
        | cons d ds => simp only [potRd, List.length_append, List.length_singleton]; omega
      · cases ds with
        | nil => simp only [potRd, List.nil_append]; omega
        | cons d ds => simp only [potRd, List.cons_append]; omega
      · exact Nat.zero_le _

/-- **A charged step lowers the potential by one.** -/
theorem potRd_step_charged (R : Rounds) (W : UInt64 → ℕ) (ptr : List (List UInt8 × List D))
    (pm : Option (List UInt8)) (kk : UInt64) (dg : D) (hlt : ptr.length < R.n) (hm : R.hasMsg ptr.length = pm.isSome)
    (hw : W kk = R.w ptr.length) :
    potRd R.n (cRdStep R W (some (ptr, pm, [])) (.squeeze kk, dg)) + 1 ≤ potRd R.n (some (ptr, pm, [])) := by
  have hn : ¬ R.n ≤ ptr.length := by omega
  simp only [cRdStep, hn, ↓reduceIte]
  split_ifs with hc hl
  · simp only [potRd, List.length_append, List.length_singleton]
    omega
  · simp only [potRd, List.nil_append]
    omega
  · exact (hc ⟨hm, fun _ => hw⟩).elim

/-- **One entry never raises a sub-protocol's potential, and a charged one lowers it.** -/
theorem potS_step (W : UInt64 → ℕ) (k : CSk) (τ : List (TItem × D)) (e : TItem × D) :
    potS W k (τ ++ [e]) ≤ potS W k τ ∧ (Charged W k τ e.1 → potS W k (τ ++ [e]) + 1 ≤ potS W k τ) := by
  by_cases ha : k.a ≤ τ.length
  · have hlt : ¬ τ.length < k.a := by omega
    have hlt' : ¬ (τ ++ [e]).length < k.a := by
      rw [List.length_append, List.length_singleton]
      omega
    have hc : cRd k.R W ((τ ++ [e]).drop k.a) = cRdStep k.R W (cRd k.R W (τ.drop k.a)) e := by
      rw [List.drop_append_of_le_length ha, cRd, cRd, List.foldl_append, List.foldl_cons, List.foldl_nil]
    unfold potS
    rw [ite_eq_right hlt, ite_eq_right hlt', hc]
    refine ⟨potRd_step k.R W _ e, ?_⟩
    rintro ⟨-, -, ptr, pm, hrd, hn, hm, kk, hh, hw⟩
    rw [hrd]
    obtain ⟨it, dg⟩ := e
    simp only at hh
    subst hh
    exact potRd_step_charged k.R W ptr pm kk dg hn hm hw
  · have hnc : ¬ Charged W k τ e.1 := fun h => ha h.1
    refine ⟨?_, fun h => absurd h hnc⟩
    unfold potS
    rw [ite_eq_left (by omega : τ.length < k.a)]
    by_cases hlt : (τ ++ [e]).length < k.a
    · rw [ite_eq_left hlt]
    · rw [ite_eq_right hlt]
      have hl : (τ ++ [e]).length ≤ k.a := by
        rw [List.length_append, List.length_singleton]
        omega
      rw [List.drop_eq_nil_of_le hl]
      simp [cRd, potRd]

/-- **A step's charge plus the potential after it is at most the potential before.** -/
theorem chargeC_add_potW_le (W : UInt64 → ℕ) (sk : List CSk) (εmax : ℝ≥0∞) (τ : List (TItem × D))
    (e : TItem × D) : chargeC W sk εmax τ e.1 + potW W sk (τ ++ [e]) ≤ potW W sk τ := by
  unfold chargeC potW
  refine le_trans (add_le_add (min_le_right _ _) le_rfl) ?_
  rw [← lsum_map_add]
  refine lsum_le_lsum (fun k _ => ?_)
  obtain ⟨h1, h2⟩ := potS_step W k τ e
  by_cases hc : Charged W k τ e.1
  · rw [ite_eq_left hc]
    have h3 := h2 hc
    calc k.ε + (potS W k (τ ++ [e]) : ℝ≥0∞) * k.ε = ((potS W k (τ ++ [e]) + 1 : ℕ) : ℝ≥0∞) * k.ε := by
          push_cast
          ring
      _ ≤ (potS W k τ : ℝ≥0∞) * k.ε := mul_le_mul' (by exact_mod_cast h3) le_rfl
  · rw [ite_eq_right hc, zero_add]
    exact mul_le_mul' (by exact_mod_cast h1) le_rfl

/-- **The verifier's charge along ANY chain is at most the potential at its start** (`FSPathWide.lean`'s `vSumFrom`
with the per-step charge `chargeC`). -/
theorem vSumFrom_chargeC_le {It' Q : Type} (C : ChainEnc It' Q D) (toT : It' → TItem) (W : UInt64 → ℕ)
    (sk : List CSk) (εmax : ℝ≥0∞) (H : Q → D) :
    ∀ (τ : List (It' × D)) (its : List It'),
      C.vSumFrom (fun τ it => chargeC W sk εmax (τ.map (toTE toT)) (toT it)) H τ its ≤ potW W sk (τ.map (toTE toT))
  | τ, [] => by
    simp only [ChainEnc.vSumFrom]
    exact zero_le
  | τ, it :: its => by
    simp only [ChainEnc.vSumFrom]
    refine le_trans (add_le_add le_rfl (vSumFrom_chargeC_le C toT W sk εmax H _ its)) ?_
    rw [List.map_append, List.map_singleton]
    exact chargeC_add_potW_le W sk εmax _ (toTE toT (it, H (C.link (C.lastD H τ) it)))

/-- **From the empty chain: the verifier's charge is at most `Σ_c n_c·ε_c`.** -/
theorem vSumFrom_chargeC_nil_le {It' Q : Type} (C : ChainEnc It' Q D) (toT : It' → TItem) (W : UInt64 → ℕ)
    (sk : List CSk) (εmax : ℝ≥0∞) (H : Q → D) (its : List It') :
    C.vSumFrom (fun τ it => chargeC W sk εmax (τ.map (toTE toT)) (toT it)) H [] its
      ≤ (sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum := by
  refine (vSumFrom_chargeC_le C toT W sk εmax H [] its).trans (le_of_eq ?_)
  rw [List.map_nil]
  exact potW_nil W sk

/-- **A doomed sub-protocol is revived only by a charged step** (`rdAlive_step`'s cases: an absorb, a frozen or a
dead reading, or a squeeze off the round's width or flag cannot revive it). -/
theorem rdAlive_charged (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (c : CSub D) (τ : List (TItem × D)) (h : TItem)
    (ks : List UInt64) (ds : List D) (hτ : tRem W τ = some 0) (hk : ks.length + 1 = tWd W h)
    (hd : ds.length = ks.length + 1) (ha : c.a ≤ τ.length) (hns : ¬ rdAlive W c τ)
    (hal : rdAlive W c (τ ++ stE h ks ds)) : Charged W c.sk τ h := by
  have hset : ∀ e : List (TItem × D), rdAlive W c (τ ++ e) ↔ tRem W (τ.take c.a) = some 0
      ∧ liftC (c.St (τ.take c.a)) (e.foldl (cRdStep c.R W) (cRd c.R W (τ.drop c.a))) := by
    intro e
    unfold rdAlive
    rw [List.take_append_of_le_length ha, List.drop_append_of_le_length ha, cRd, cRd, List.foldl_append]
  obtain ⟨htk, hlift⟩ := (hset _).mp hal
  have hdrop : (τ.drop c.a).foldl (fun o x => tRemStep W o x.1) (some 0) = some 0 := by
    have h0 := hτ
    rw [← List.take_append_drop c.a τ, tRem_append, htk] at h0
    exact h0
  have hbnd := cInv_bnd (cInv_foldl c.R W hW (τ.drop c.a) _ 0 0 (cInv_start c.R) hdrop)
  have hns' : ¬ liftC (c.St (τ.take c.a)) (cRd c.R W (τ.drop c.a)) := fun h' => hns ⟨htk, h'⟩
  rcases hbnd with hnone | ⟨ptr, pm, hsome⟩
  · exfalso
    have hn' : cRd c.R W (τ.drop c.a) = none := hnone
    rw [hn', foldl_cRdStep_none] at hlift
    exact hlift
  have hsome' : cRd c.R W (τ.drop c.a) = some (ptr, pm, []) := hsome
  rw [hsome'] at hlift hns'
  simp only [liftC] at hns'
  by_cases hfz : c.R.n ≤ ptr.length
  · exfalso
    rw [foldl_cRdStep_frozen c.R W hfz] at hlift
    exact hns' hlift
  have hlt := lt_of_not_ge hfz
  obtain ⟨d0, ds', rfl⟩ : ∃ d0 ds', ds = d0 :: ds' := by
    cases ds with
    | nil => simp at hd
    | cons d0 ds' => exact ⟨d0, ds', rfl⟩
  rw [stE_cons, List.foldl_cons] at hlift
  cases h with
  | absorb l x =>
    exfalso
    simp only [tWd] at hk
    obtain rfl : ks = [] := List.eq_nil_of_length_eq_zero (by omega)
    simp only [List.map_nil, List.zip_nil_left, List.foldl_nil] at hlift
    cases pm with
    | none =>
      simp only [cRdStep, hfz, ↓reduceIte] at hlift
      split_ifs at hlift
      · exact hns' hlift
      · exact hlift
    | some m => simp [cRdStep, hfz, liftC] at hlift
  | squeeze kk =>
    by_cases hc : c.R.hasMsg ptr.length = pm.isSome ∧ W kk = c.R.w ptr.length
    · exact ⟨ha, hτ, ptr, pm, hsome', hlt, hc.1, kk, rfl, hc.2⟩
    · exfalso
      have hc' : ¬ (c.R.hasMsg ptr.length = pm.isSome ∧ (([] : List D).length = 0 → W kk = c.R.w ptr.length)) :=
        fun h' => hc ⟨h'.1, h'.2 rfl⟩
      have hstep : cRdStep c.R W (some (ptr, pm, [])) (TItem.squeeze kk, d0) = none := by
        simp only [cRdStep, hfz, ↓reduceIte]
        rw [ite_eq_right hc']
      rw [hstep, foldl_cRdStep_none] at hlift
      exact hlift

end Charge

/-! ## Round-by-round with per-step errors -/

section RbrPos

variable {D : Type} [Fintype D] [Nonempty D]

/-- **Round-by-round on the code's chain with a per-step error** `e τ h` (L8's `CodeRbr` with `ε` depending on the
chain and the step's head). -/
def CodeRbrE (W : UInt64 → ℕ) (Φ : List (TItem × D) → Prop) (e : List (TItem × D) → TItem → ℝ≥0∞) : Prop :=
  ∀ (τ : List (TItem × D)) (h : TItem) (ks : List UInt64), tRem W τ = some 0 → ks.length + 1 = tWd W h → ¬ Φ τ →
    (PMF.uniformOfFintype (Fin (ks.length + 1) → D)).toOuterMeasure {b | Φ (τ ++ stE h ks (List.ofFn b))} ≤ e τ h

/-- **The combined state is round-by-round with the per-step charge** (L8's `allSt_rbr`, per position): from a doomed
chain, the largest doomed sub-protocol `c₀` can be revived only by its own reading (`hframe`), at most its error, and
only by a step that starts one of its rounds (`rdAlive_charged`), which the charge counts. -/
theorem allSt_rbr_pos (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (CSub D)) (εmax : ℝ≥0∞)
    (hR : ∀ c ∈ cs, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ c ∈ cs, c.ε ≤ εmax)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      cs[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h → ds.length = ks.length + 1 →
      ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ cs[k']? = some c' ∧ ¬ subSt W c' τ) :
    CodeRbrE W (allSt W cs) (chargeC W (cs.map CSub.sk) εmax) := by
  intro τ h ks hτ hk hns
  classical
  have hne : ((Finset.range cs.length).filter (fun k => doomedAt W cs τ k)).Nonempty := by
    simp only [allSt, not_forall] at hns
    obtain ⟨k, c, hc, hd⟩ := hns
    exact ⟨k, Finset.mem_filter.mpr ⟨Finset.mem_range.mpr (List.getElem?_eq_some_iff.mp hc).1,
      (⟨c, hc, hd⟩ : ∃ c, cs[k]? = some c ∧ ¬ subSt W c τ)⟩⟩
  obtain ⟨-, c₀, hc₀, hd₀⟩ := Finset.mem_filter.mp (Finset.max'_mem _ hne)
  have hmax : ∀ k' c', ((Finset.range cs.length).filter (fun k => doomedAt W cs τ k)).max' hne < k' →
      cs[k']? = some c' → subSt W c' τ := by
    intro k' c' hlt hc'
    by_contra hd'
    have := Finset.le_max' ((Finset.range cs.length).filter (fun k => doomedAt W cs τ k)) k'
      (Finset.mem_filter.mpr ⟨Finset.mem_range.mpr (List.getElem?_eq_some_iff.mp hc').1,
        (⟨c', hc', hd'⟩ : ∃ c, cs[k']? = some c ∧ ¬ subSt W c τ)⟩)
    omega
  have ha : c₀.a ≤ τ.length := by
    by_contra hlt
    exact hd₀ (Or.inl (lt_of_not_ge hlt))
  have hnsA : ¬ rdAlive W c₀ τ := fun h' => hd₀ (Or.inr (Or.inl h'))
  have hmem : c₀ ∈ cs := List.mem_of_getElem? hc₀
  have hsub : {b : Fin (ks.length + 1) → D | allSt W cs (τ ++ stE h ks (List.ofFn b))}
      ⊆ {b | rdAlive W c₀ (τ ++ stE h ks (List.ofFn b))} := by
    intro b hb
    rcases hb _ c₀ hc₀ with h1 | h1 | h1
    · simp only [List.length_append] at h1
      omega
    · exact h1
    · obtain ⟨k', c', hlt, hc', hd'⟩ := hframe _ c₀ τ h ks (List.ofFn b) hc₀ hτ hk List.length_ofFn hd₀ h1
      exact absurd (hmax k' c' hlt hc') hd'
  have hstep := rdAlive_step W hW c₀ (hR c₀ hmem) τ h ks hτ hk ha hnsA
  unfold chargeC
  refine le_min ((MeasureTheory.measure_mono hsub).trans (hstep.trans (hε c₀ hmem))) ?_
  by_cases hch : Charged W c₀.sk τ h
  · refine (MeasureTheory.measure_mono hsub).trans (hstep.trans ?_)
    have hm : c₀.sk ∈ cs.map CSub.sk := List.mem_map_of_mem hmem
    refine le_trans ?_ (le_lsum_of_mem hm)
    simp only [ite_eq_left hch]
    exact le_rfl
  · have hempty : {b : Fin (ks.length + 1) → D | allSt W cs (τ ++ stE h ks (List.ofFn b))} = ∅ := by
      refine Set.eq_empty_iff_forall_notMem.mpr (fun b hb => ?_)
      exact hch (rdAlive_charged W hW c₀ τ h ks (List.ofFn b) hτ hk List.length_ofFn ha hnsA (hsub hb))
    rw [hempty, MeasureTheory.measure_empty]
    exact zero_le

/-- **Doomed at a later step's end costs nothing extra, per position** (L8's `everSt_rbr` with a per-step error). -/
theorem everSt_rbr_pos (W : UInt64 → ℕ) (cs : List (CSub D)) (e : List (TItem × D) → TItem → ℝ≥0∞)
    (hA : CodeRbrE W (allSt W cs) e) : CodeRbrE W (everSt W cs) e := by
  intro τ h ks hτ hk hns
  by_cases hal : allSt W cs τ
  · have hall : ∀ j, j ≤ τ.length → tRem W (τ.take j) = some 0 → allSt W cs (τ.take j) := by
      intro j hj ht
      by_contra hc
      exact hns ⟨hal, j, hj, ht, hc⟩
    have hE : ∀ b : Fin (ks.length + 1) → D, ¬ everSt W cs (τ ++ stE h ks (List.ofFn b)) := by
      rintro b ⟨hb1, j, hj, ht, hc⟩
      have hlen : (stE h ks (List.ofFn b)).length = ks.length + 1 := stE_length _ _ _ List.length_ofFn
      rw [List.length_append, hlen] at hj
      by_cases hj1 : j ≤ τ.length
      · rw [List.take_append_of_le_length hj1] at ht hc
        exact hc (hall j hj1 ht)
      · by_cases hj2 : j = τ.length + (ks.length + 1)
        · rw [List.take_of_length_le (show (τ ++ stE h ks (List.ofFn b)).length ≤ j by
            rw [List.length_append, hlen]; omega)] at hc
          exact hc hb1
        · rw [List.take_append, List.take_of_length_le (show τ.length ≤ j by omega)] at ht
          exact tRem_stE_take W hτ h ks _ hk List.length_ofFn (j - τ.length) (by omega) (by omega) ht
    have hE' : {b : Fin (ks.length + 1) → D | everSt W cs (τ ++ stE h ks (List.ofFn b))} = ∅ :=
      Set.eq_empty_iff_forall_notMem.mpr (fun b hb => hE b hb)
    rw [hE', MeasureTheory.measure_empty]
    exact zero_le
  · exact (MeasureTheory.measure_mono (fun b hb => hb.1)).trans (hA τ h ks hτ hk hal)

/-- **From the per-step code-item bound to `chain_sound_wide_seq`'s round hypothesis** (L8's `codeRbr_step`, per
position). -/
theorem codeRbr_step_pos {It' : Type} (W : UInt64 → ℕ) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {Φ : List (TItem × D) → Prop} {e : List (TItem × D) → TItem → ℝ≥0∞} (hΦ : CodeRbrE W Φ e)
    (τ : List (It' × D)) (it : It') (hbd : ∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items)
    (hns : ¬ Φ (τ.map (toTE toT))) :
    (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure
      {b | Φ ((τ ++ S.ents it (List.ofFn b)).map (toTE toT))} ≤ e (τ.map (toTE toT)) (toT it) := by
  obtain ⟨hs, hhs⟩ := hbd
  obtain ⟨ks, hks, hkl⟩ := hS it
  have hwd : S.wd it = ks.length + 1 := by
    have e2 := congrArg List.length hks
    rw [List.length_map, Steps.items_length, List.length_cons, List.length_map] at e2
    exact e2
  have hτ : tRem W (τ.map (toTE toT)) = some 0 := by
    have h0 := tRem_steps W toT S hS hs [] τ rfl hhs
    rwa [List.nil_append] at h0
  rw [prob_ofFn_congr (D := D) hwd (fun ds : List D => Φ ((τ ++ S.ents it ds).map (toTE toT)))]
  have hset : {b : Fin (ks.length + 1) → D | Φ ((τ ++ S.ents it (List.ofFn b)).map (toTE toT))}
      = {b | Φ (τ.map (toTE toT) ++ stE (toT it) ks (List.ofFn b))} := by
    ext b
    simp only [Set.mem_ofPred_eq]
    rw [List.map_append, ents_eq_zip S it _ (by rw [List.length_ofFn, hwd]), map_toTE_zip, hks]
    rfl
  rw [hset]
  exact hΦ _ (toT it) ks hτ hkl hns

end RbrPos

/-! ## The composition with log-reading states, per position -/

section LogChainPos

variable {D It' : Type} [Fintype D] [Nonempty D] [DecidableEq D] {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The knowledge version of L8's composition with the PER-POSITION count, the general form** (D63 lane L20;
finding L16-1). A family of schedules `cs P` indexed by the run's log, with one skeleton `sk` (windows, rounds,
errors), each sub-protocol `RbrWide` with its error `≤ εmax`, releases handed on only forward, every window after `s`
entries, frozen once a chain's first `s` entries are logged (`hstab`). The probability that the chain is alive at the
end but was doomed at some step's end is at most `q·εmax + Σ_c n_c·ε_c + collBound T D + collBound (T + 1) D`,
`T = q + ℓ + 1`: the prover's queries are charged the largest error, the verifier's whole chain `Σ_c n_c·ε_c`. -/
theorem fs_code_chain_ever_log_pos (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (Q × D) → List (CSub D))
    (sk : List CSk) (hsk : ∀ P, (cs P).map CSub.sk = sk)
    (εmax : ℝ≥0∞) (hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ εmax)
    (hframe : ∀ (P : List (Q × D)) (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64)
      (ds : List D), (cs P)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (cs P)[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (s : ℕ) (hwin : ∀ P, ∀ c ∈ cs P, s < c.a) (hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It' × D)) (qs : List Q), C.Chain H τ qs →
      τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × D),
          allSt W (cs P) (τ.map (toTE toT) ++ ext) ↔ allSt W (cs P') (τ.map (toTE toT) ++ ext))
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => everSt W (cs ((C.stepRun S heads A).runLog H).2) (cChain C toT S H (heads (A.run H))))
      ≤ (q : ℝ≥0∞) * εmax + (sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum
        + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  have hE : ∀ P, CodeRbrE W (everSt W (cs P)) (chargeC W sk εmax) := fun P => by
    have h := everSt_rbr_pos W (cs P) _ (allSt_rbr_pos W hW (cs P) εmax (hR P) (hε P) (hframe P))
    rwa [hsk P] at h
  have hround : ∀ (P : List (Q × D)) (τ : List (It' × D)) (it : It'), s ≤ τ.length →
      (∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items) → ¬ everSt W (cs P) (τ.map (toTE toT)) →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure
        {b | everSt W (cs P) ((τ ++ S.ents it (List.ofFn b)).map (toTE toT))}
        ≤ chargeC W sk εmax (τ.map (toTE toT)) (toT it) :=
    fun P τ it _ h2 h3 => codeRbr_step_pos W toT S hS (hE P) τ it h2 h3
  have hstab' : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It' × D)) (qs : List Q) (ext : List (It' × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (everSt W (cs P) ((τ ++ ext).map (toTE toT)) ↔ everSt W (cs P') ((τ ++ ext).map (toTE toT))) := by
    intro H P P' τ qs ext hc hs hq hpre hans
    obtain ⟨qs₀, hc₀, hq₀⟩ := chain_take C H hc s hs
    have hl0 : (τ.take s).length = s := by
      rw [List.length_take]
      omega
    have hsplit : (τ ++ ext).map (toTE toT) = (τ.take s).map (toTE toT) ++ ((τ.drop s ++ ext).map (toTE toT)) := by
      rw [← List.map_append, ← List.append_assoc, List.take_append_drop]
    rw [hsplit]
    exact everSt_congr_pre W (cs P) (cs P') s _ (by rw [List.length_map, hl0]) (hwin P) (hwin P')
      (hstab H P P' (τ.take s) qs₀ hc₀ hl0 (fun y hy => hq y (hq₀ y hy)) hpre hans) _
  have hhe : ∀ (τ : List (It' × D)) (it : It'), chargeC W sk εmax (τ.map (toTE toT)) (toT it) ≤ εmax :=
    fun τ it => chargeC_le_max W sk εmax (τ.map (toTE toT)) (toT it)
  have hB : ∀ (H : Q → D) (o : α), C.vSumFrom (fun τ it => chargeC W sk εmax (τ.map (toTE toT)) (toT it)) H []
      ((heads o).flatMap S.items) ≤ (sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum :=
    fun H o => vSumFrom_chargeC_nil_le C toT W sk εmax H _
  have hmain := chain_sound_wide_seq C S (fun P τ => everSt W (cs P) (τ.map (toTE toT))) s
    (fun τ it => chargeC W sk εmax (τ.map (toTE toT)) (toT it)) εmax hhe hround hstab' heads ℓ hℓ
    ((sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum) hB q A hA
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  refine ⟨?_, hH⟩
  rintro ⟨-, j, -, -, h2⟩
  apply h2
  intro k c hc
  have hl : ((C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items)).map (toTE toT)).length ≤ s := by
    rw [List.length_map, ChainEnc.chainFrom_length, List.length_nil, zero_add]
    exact hhd _
  have hc' := hwin _ c (List.mem_of_getElem? hc)
  refine Or.inl ?_
  rw [List.length_take]
  omega

/-- **The knowledge version of L8's scheduled composition with the PER-POSITION count** (D63 lane L20; L16-1's fix):
for the schedule at the run's own log, the probability that SOME sub-protocol enters its window with a false claim
(at a step's end, not released) and yet EVERY sub-protocol is alive at the end is at most
`q·εmax + Σ_c n_c·ε_c + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. -/
theorem fs_code_chain_sound_sched_log_pos (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (Q × D) → List (CSub D))
    (sk : List CSk) (hsk : ∀ P, (cs P).map CSub.sk = sk)
    (εmax : ℝ≥0∞) (hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ εmax)
    (hframe : ∀ (P : List (Q × D)) (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64)
      (ds : List D), (cs P)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (cs P)[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (s : ℕ) (hwin : ∀ P, ∀ c ∈ cs P, s < c.a) (hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It' × D)) (qs : List Q), C.Chain H τ qs →
      τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × D),
          allSt W (cs P) (τ.map (toTE toT) ++ ext) ↔ allSt W (cs P') (τ.map (toTE toT) ++ ext))
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), (cs ((C.stepRun S heads A).runLog H).2)[k]? = some c
          ∧ c.a ≤ (cChain C toT S H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT S H (heads (A.run H))).take c.a) = some 0
          ∧ ¬ c.St ((cChain C toT S H (heads (A.run H))).take c.a) []
          ∧ ¬ c.rel ((cChain C toT S H (heads (A.run H))).take c.a))
        ∧ allSt W (cs ((C.stepRun S heads A).runLog H).2) (cChain C toT S H (heads (A.run H))))
      ≤ (q : ℝ≥0∞) * εmax + (sk.map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum
        + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_code_chain_ever_log_pos W hW cs sk hsk εmax hR hε hframe C toT S hS heads ℓ hℓ s hwin hhd hstab q A hA)
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  obtain ⟨⟨k, c, hc, ha, hal, hst, hrel⟩, hall⟩ := hH
  refine ⟨hall, c.a, ha, hal, fun h' => ?_⟩
  rcases h' k c hc with h1 | ⟨-, h1⟩ | h1
  · rw [List.length_take, min_eq_left ha] at h1
    omega
  · rw [List.take_take, min_self, List.drop_eq_nil_of_le (by rw [List.length_take]; omega)] at h1
    exact hst h1
  · exact hrel h1

end LogChainPos

end ZK60.Exec
