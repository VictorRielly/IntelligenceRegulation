/-
D63, step L3 (soundness): a protocol on the code's chain whose rounds have their OWN errors, which may depend on the
statement, the transcript so far and the round's message (finding F25, Victor's ruling D66(4)).

`FSWideRbr.lean`'s `RbrWide` has one error `ε` for every round, and `fs_chain_sound_of_rbr_wide` charges it
`q + ℓW + 1` times. Here a round's error is `er x τ m`: the statement `x`, the transcript `τ` of the rounds before,
the round's message `m`. `FSPathWide.lean`'s `chain_sound_wide_seq` then gives
`q·εmax + B + collision terms`, where `εmax` bounds every round's error and `B` bounds, for every statement and every
transcript, the sum of the errors of its rounds along it (`trSumFrom`). The second term is the query-free part.

**What is proved.**
* `RbrWideT`: round-by-round soundness with vector challenges and errors `er x τ m`. `RbrWide.toT`: a constant error
  is the special case.
* `eW`: the charge of a chain item: a round's first squeeze, after a chain that reads as the statement `x` and the
  transcript `ptr` with the pending message `pm` between rounds, is charged `er x ptr (pm.getD m₀)`; every other item
  is charged `0`. `eW_sq_of_not_ctr`: a squeeze whose counter is no round's first is charged nothing.
* `liftStW_roundT`: the lifted state of `FSWideRbr.lean` satisfies `chain_sound_wide_seq`'s round hypothesis with the
  charge `eW` (the proof of `liftStW_round`, with the round's own error).
* `vSumFrom_roundHeads`: the verifier's charge along its own chain is the transcript sum `trSumFrom` of the rounds it
  reads, round by round: the message item is charged nothing, the round's first squeeze its error, the rest of its
  squeezes nothing.
* `fs_chain_wide_flip_T` (states that read the log) and `fs_chain_sound_of_rbrWideT`: **a false statement is accepted
  with probability at most `q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`.**
-/
import ZK60Formal.FSPathWide

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

section Lift

variable {X M Q D : Type}

/-- **Round-by-round soundness with vector challenges and per-round errors** that may depend on the statement, the
transcript of the rounds before and the round's message. -/
structure RbrWideT [Fintype D] [Nonempty D] (n : ℕ) (w : ℕ → ℕ) (St : X → List (M × List D) → Prop)
    (er : X → List (M × List D) → M → ℝ≥0∞) : Prop where
  round : ∀ x τ m, τ.length < n → ¬ St x τ →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure {b | St x (τ ++ [(m, List.ofFn b)])} ≤ er x τ m

/-- A constant error is the special case. -/
theorem RbrWide.toT [Fintype D] [Nonempty D] {n : ℕ} {w : ℕ → ℕ} {St : X → List (M × List D) → Prop}
    {ε : ℝ≥0∞} (h : RbrWide n w St ε) : RbrWideT n w St (fun _ _ _ => ε) :=
  ⟨h.round⟩

/-- **The sum of a transcript's round errors**: each round `r` after the transcript `ptr` before it is charged
`er x ptr r.1`. -/
def trSumFrom (er : X → List (M × List D) → M → ℝ≥0∞) (x : X) :
    List (M × List D) → List (M × List D) → ℝ≥0∞
  | _, [] => 0
  | ptr, r :: rs => er x ptr r.1 + trSumFrom er x (ptr ++ [r]) rs

/-- **The charge of a chain item.** A round's first squeeze, after a chain that reads as the statement `x` and the
transcript `ptr` between rounds (pending message `pm`), is charged that round's error; any other item nothing. -/
def eW (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (m₀ : M) (er : X → List (M × List D) → M → ℝ≥0∞) :
    List (PItem X M × D) → PItem X M → ℝ≥0∞
  | (.stmt x, _) :: rest, .sq c =>
    match rDecodeW n w hasMsg m₀ rest with
    | some (ptr, pm, []) => if ptr.length < n ∧ c = ctr w ptr.length then er x ptr (pm.getD m₀) else 0
    | _ => 0
  | _, _ => 0

variable {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}

/-- The charge is at most `εmax` when every round's error is. -/
theorem eW_le {er : X → List (M × List D) → M → ℝ≥0∞} {εmax : ℝ≥0∞}
    (hε : ∀ x τ m, τ.length < n → er x τ m ≤ εmax) (τ : List (PItem X M × D)) (it : PItem X M) :
    eW n w hasMsg m₀ er τ it ≤ εmax := by
  unfold eW
  split
  · split
    · split_ifs with h
      · exact hε _ _ _ h.1
      · exact zero_le
    · exact zero_le
  · exact zero_le

/-- A squeeze whose counter is no round's first squeeze is charged nothing. -/
theorem eW_sq_of_not_ctr (er : X → List (M × List D) → M → ℝ≥0∞) (τ : List (PItem X M × D)) (c : ℕ)
    (hc : ∀ i, ctr w i ≠ c) : eW n w hasMsg m₀ er τ (.sq c) = 0 := by
  rcases τ with _ | ⟨⟨it0, d0⟩, rest⟩
  · rfl
  · cases it0 with
    | stmt x =>
      show (match rDecodeW n w hasMsg m₀ rest with
        | some (ptr, pm, []) => if ptr.length < n ∧ c = ctr w ptr.length then er x ptr (pm.getD m₀) else 0
        | _ => 0) = 0
      split
      · exact ite_eq_right (fun h => hc _ h.2.symm)
      · rfl
    | msg m => rfl
    | sq c0 => rfl

/-- The squeezes inside a round, after its first, carry no round's first counter. -/
theorem ctr_ne_inside (hw : ∀ i, 0 < w i) (i j : ℕ) (hj0 : 0 < j) (hj : j < w i) : ∀ i', ctr w i' ≠ ctr w i + j := by
  intro i' h
  rcases Nat.lt_or_ge i i' with hlt | hge
  · have h1 : ctr w (i + 1) ≤ ctr w i' := (ctr_strictMono hw).monotone (by omega)
    have h2 : ctr w (i + 1) = ctr w i + w i := rfl
    omega
  · have h1 : ctr w i' ≤ ctr w i := (ctr_strictMono hw).monotone hge
    omega

/-- **The lifted state is round by round with the charge `eW`.** From a doomed chain of whole steps, a message step
never escapes, the squeeze step of round `i` escapes with probability at most that round's error, and any other step
dooms the chain. -/
theorem liftStW_roundT [Fintype D] [Nonempty D] (hw : ∀ i, 0 < w i)
    (St : List (Q × D) → X → List (M × List D) → Prop) (er : X → List (M × List D) → M → ℝ≥0∞)
    (hR : ∀ P, RbrWideT n w (St P) er)
    (P : List (Q × D)) (τ : List (PItem X M × D)) (it : PItem X M) (hlen : 1 ≤ τ.length)
    (hbd : ∃ hs : List (PItem X M), τ.map Prod.fst = hs.flatMap (pSteps n w hw).items)
    (hns : ¬ liftStW n w hasMsg m₀ St P τ) :
    (PMF.uniformOfFintype (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)).toOuterMeasure
        {b | liftStW n w hasMsg m₀ St P (τ ++ (pSteps n w hw).ents it (List.ofFn b))}
      ≤ eW n w hasMsg m₀ er τ it := by
  have hempty : ∀ (E : Set (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)), (∀ b, b ∉ E) →
      (PMF.uniformOfFintype (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)).toOuterMeasure E
        ≤ eW n w hasMsg m₀ er τ it := by
    intro E hE
    have : E = ∅ := Set.eq_empty_iff_forall_notMem.mpr hE
    rw [this, MeasureTheory.measure_empty]
    exact zero_le
  obtain ⟨⟨it0, d0⟩, rest, rfl⟩ : ∃ e rest, τ = e :: rest := by
    cases τ with
    | nil => simp at hlen
    | cons e rest => exact ⟨e, rest, rfl⟩
  cases it0 with
  | msg m0 => exact hempty _ (fun b hb => by simp [liftStW] at hb)
  | sq c0 => exact hempty _ (fun b hb => by simp [liftStW] at hb)
  | stmt x =>
    obtain ⟨hs, hhs⟩ := hbd
    obtain ⟨h0, hs', rfl⟩ : ∃ h0 hs', hs = h0 :: hs' := by
      cases hs with
      | nil => simp at hhs
      | cons h0 hs' => exact ⟨h0, hs', rfl⟩
    obtain ⟨r0, hr0⟩ := (pSteps (X := X) (M := M) n w hw).items_cons h0
    rw [List.map_cons, List.flatMap_cons, hr0, List.cons_append, List.cons.injEq] at hhs
    obtain ⟨rfl, hhs⟩ := hhs
    rw [pSteps_items_stmt, List.cons.injEq] at hr0
    rw [← hr0.2, List.nil_append] at hhs
    have hbnd := foldl_bnd_flatMap (m₀ := m₀) (hasMsg := hasMsg) hw hs' rest (some ([], none, []))
      (Or.inr ⟨[], none, rfl⟩) hhs
    have hstep : ∀ b : Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D,
        liftStW n w hasMsg m₀ St P (((PItem.stmt x, d0) :: rest) ++ (pSteps n w hw).ents it (List.ofFn b))
          = liftOfW (St P) x (((pSteps n w hw).ents it (List.ofFn b)).foldl (rStepW n w hasMsg m₀)
              (rDecodeW n w hasMsg m₀ rest)) := by
      intro b
      rw [List.cons_append, liftStW, rDecodeW, rDecodeW, List.foldl_append]
    simp only [liftStW] at hns
    rcases hbnd with hnone | ⟨ptr, pm, hsome⟩
    · refine hempty _ (fun b hb => ?_)
      rw [Set.mem_ofPred_eq, hstep, rDecodeW, hnone, foldl_rStepW_none] at hb
      exact hb
    · rw [rDecodeW] at hns
      rw [hsome] at hns
      simp only [liftOfW] at hns
      cases it with
      | stmt x' =>
        refine hempty _ (fun b hb => ?_)
        rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
        have hb' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.stmt x') (List.ofFn b))
            = [(PItem.stmt x', b ⟨0, (pSteps (X := X) (M := M) n w hw).wd_pos _⟩)] := rfl
        rw [hb'] at hb
        cases pm <;> exact hb
      | msg m =>
        refine hempty _ (fun b hb => ?_)
        rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
        have hb' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.msg m) (List.ofFn b))
            = [(PItem.msg m, b ⟨0, (pSteps (X := X) (M := M) n w hw).wd_pos _⟩)] := rfl
        rw [hb'] at hb
        cases pm with
        | none =>
          change liftOfW (St P) x (if ptr.length < n ∧ hasMsg ptr.length = true then some (ptr, some m, []) else none)
            at hb
          split_ifs at hb
          · exact hns hb
          · exact hb
        | some m' => exact hb
      | sq c =>
        have hents := fun b : Fin ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)) → D =>
          pSteps_ents_sq (X := X) (M := M) n w hw c (List.ofFn b)
        by_cases hc : ptr.length < n ∧ c = ctr w ptr.length + ([] : List D).length ∧ hasMsg ptr.length = pm.isSome
        · have hcw : (pSteps (X := X) (M := M) n w hw).wd (PItem.sq c) = w ptr.length := by
            show sqWidth n w c = w ptr.length
            rw [hc.2.1, List.length_nil, add_zero, sqWidth_ctr hw hc.1]
          have hset : {b : Fin ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)) → D |
              liftStW n w hasMsg m₀ St P (((PItem.stmt x, d0) :: rest) ++ (pSteps n w hw).ents (.sq c) (List.ofFn b))}
              = {b | St P x (ptr ++ [(pm.getD m₀, List.ofFn b)])} := by
            ext b
            rw [Set.mem_ofPred_eq, Set.mem_ofPred_eq, hstep, rDecodeW, hsome]
            have hne : (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b) ≠ [] := by
              intro h
              have := congrArg List.length (hents b).2
              rw [h] at this
              simp only [List.map_nil, List.length_nil, List.length_ofFn] at this
              have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c)
              omega
            have hlen' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b)).length
                = w ptr.length := by
              have := congrArg List.length (hents b).2
              rw [List.length_map, List.length_ofFn] at this
              rw [this, hcw]
            rw [foldl_rStepW_sq hc.1 hc.2.2 _ [] hne (by rw [List.length_nil, zero_add, hlen'])
              (by rw [(hents b).1, hlen', List.length_ofFn, hcw, hc.2.1]),
              (hents b).2, List.nil_append]
            rfl
          have heW : eW n w hasMsg m₀ er ((PItem.stmt x, d0) :: rest) (PItem.sq c) = er x ptr (pm.getD m₀) := by
            have hc' : ptr.length < n ∧ c = ctr w ptr.length := ⟨hc.1, by rw [hc.2.1, List.length_nil, add_zero]⟩
            simp only [eW, rDecodeW] at hsome ⊢
            rw [hsome]
            simp only [hc', and_self, ↓reduceIte]
          rw [hset, prob_ofFn_congr hcw (fun ds => St P x (ptr ++ [(pm.getD m₀, ds)])), heW]
          exact (hR P).round x ptr (pm.getD m₀) hc.1 hns
        · refine hempty _ (fun b hb => ?_)
          rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
          obtain ⟨⟨it1, d1⟩, es, hes⟩ : ∃ e es, (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b)
              = e :: es := by
            cases h : (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b) with
            | nil =>
              have := congrArg List.length (hents b).2
              rw [h] at this
              simp only [List.map_nil, List.length_nil, List.length_ofFn] at this
              have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c)
              omega
            | cons e es => exact ⟨e, es, rfl⟩
          have hit1 : it1 = PItem.sq c := by
            have h1 := (hents b).1
            rw [hes, List.map_cons, List.length_ofFn,
              show (pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)
                = ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c) - 1) + 1 by
                  have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c); omega,
              List.range_succ_eq_map, List.map_cons] at h1
            simpa using (List.cons.inj h1).1
          rw [hes, hit1, List.foldl_cons, rStepW_sq, ite_eq_right hc, foldl_rStepW_none] at hb
          exact hb

end Lift

/-! ## The verifier's charge along its own chain -/

section VSum

variable {X M Q D : Type}
variable {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}

/-- The charge of an item list splits at any point. -/
theorem ChainEnc.vSumFrom_append {It : Type} (C : ChainEnc It Q D) (e : List (It × D) → It → ℝ≥0∞)
    (H : Q → D) : ∀ (τ : List (It × D)) (its₁ its₂ : List It),
    C.vSumFrom e H τ (its₁ ++ its₂) = C.vSumFrom e H τ its₁ + C.vSumFrom e H (C.chainFrom H τ its₁) its₂
  | τ, [], its₂ => by simp [ChainEnc.vSumFrom, ChainEnc.chainFrom]
  | τ, it :: its₁, its₂ => by
    rw [List.cons_append, ChainEnc.vSumFrom, ChainEnc.vSumFrom, ChainEnc.vSumFrom_append C e H _ its₁ its₂,
      add_assoc]
    rfl

/-- Items that are all charged nothing are charged nothing. -/
theorem ChainEnc.vSumFrom_zero {It : Type} (C : ChainEnc It Q D) (e : List (It × D) → It → ℝ≥0∞)
    (H : Q → D) : ∀ (τ : List (It × D)) (its : List It), (∀ τ' it, it ∈ its → e τ' it = 0) →
      C.vSumFrom e H τ its = 0
  | τ, [], _ => rfl
  | τ, it :: its, h => by
    rw [ChainEnc.vSumFrom, h τ it List.mem_cons_self,
      ChainEnc.vSumFrom_zero C e H _ its (fun τ' it' hit => h τ' it' (List.mem_cons_of_mem _ hit)), add_zero]

/-- **The verifier's charge along its own chain is the transcript sum of the rounds it reads.** From a chain that
reads as the statement `x` and the transcript `ptr` (round `i`, between rounds), the items of the rounds `i, i + 1, …`
for the messages `ms` are charged exactly `trSumFrom er x ptr new`, where `new` are the rounds they read. -/
theorem vSumFrom_roundHeads (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D)
    (er : X → List (M × List D) → M → ℝ≥0∞) (H : Q → D) (x : X) (d : D) :
    ∀ (ms : List M) (i : ℕ) (rest : List (PItem X M × D)) (ptr : List (M × List D)),
      rDecodeW n w hasMsg m₀ rest = some (ptr, none, []) → ptr.length = i → i + ms.length ≤ n →
      ∃ new : List (M × List D), new.length = ms.length
        ∧ C.vSumFrom (eW n w hasMsg m₀ er) H ((PItem.stmt x, d) :: rest)
            ((roundHeads w hasMsg i ms).flatMap (pSteps n w hw).items) = trSumFrom er x ptr new
  | [], i, rest, ptr, _, _, _ => ⟨[], rfl, by simp [roundHeads, ChainEnc.vSumFrom, trSumFrom]⟩
  | m :: ms, i, rest, ptr, hdec, hp, hn => by
    have hi : i < n := by simp at hn; omega
    -- the round's squeeze run, from a chain that reads `ptr` with the pending message `pm`
    have hrun : ∀ (rest₁ : List (PItem X M × D)) (pm : Option M), hasMsg i = pm.isSome →
        rDecodeW n w hasMsg m₀ rest₁ = some (ptr, pm, []) →
        ∃ new : List (M × List D), new.length = ms.length + 1
          ∧ C.vSumFrom (eW n w hasMsg m₀ er) H ((PItem.stmt x, d) :: rest₁)
              ((pSteps (X := X) (M := M) n w hw).items (PItem.sq (ctr w i))
                ++ (roundHeads w hasMsg (i + 1) ms).flatMap (pSteps n w hw).items)
            = trSumFrom er x ptr new := by
      intro rest₁ pm hpm hdec₁
      have hsq := pSteps_items_sq (X := X) (M := M) n w hw (ctr w i)
      rw [sqWidth_ctr hw hi] at hsq
      rw [ChainEnc.vSumFrom_append]
      -- the squeezes: the first is charged the round's error, the others nothing
      have hfirst : C.vSumFrom (eW n w hasMsg m₀ er) H ((PItem.stmt x, d) :: rest₁)
          ((pSteps (X := X) (M := M) n w hw).items (PItem.sq (ctr w i))) = er x ptr (pm.getD m₀) := by
        obtain ⟨k, hk⟩ : ∃ k, w i = k + 1 := ⟨w i - 1, by have := hw i; omega⟩
        rw [hsq, hk, List.range_succ_eq_map, List.map_cons, ChainEnc.vSumFrom]
        have h0 : eW n w hasMsg m₀ er ((PItem.stmt x, d) :: rest₁) (PItem.sq (ctr w i + 0))
            = er x ptr (pm.getD m₀) := by
          simp only [eW, hdec₁, add_zero, hp, hi, and_self, ↓reduceIte]
        rw [h0, ChainEnc.vSumFrom_zero, add_zero]
        intro τ' it hit
        rw [List.map_map, List.mem_map] at hit
        obtain ⟨j, hj, rfl⟩ := hit
        rw [List.mem_range] at hj
        exact eW_sq_of_not_ctr er τ' _ (ctr_ne_inside hw i (j + 1) (by omega) (by omega))
      rw [hfirst]
      -- after the round, the chain reads one more round
      obtain ⟨ext, hext, hmap⟩ := C.chainFrom_eq_append H ((pSteps (X := X) (M := M) n w hw).items
        (PItem.sq (ctr w i))) ((PItem.stmt x, d) :: rest₁)
      have hlenext : ext.length = w i := by
        rw [← List.length_map Prod.fst, hmap, Steps.items_length]
        exact sqWidth_ctr hw hi
      have hne : ext ≠ [] := fun h => by rw [h] at hlenext; have := hw i; simp at hlenext; omega
      have hdec₂ : rDecodeW n w hasMsg m₀ (rest₁ ++ ext)
          = some (ptr ++ [(pm.getD m₀, ext.map Prod.snd)], none, []) := by
        rw [rDecodeW, List.foldl_append, ← rDecodeW, hdec₁,
          foldl_rStepW_sq (by rw [hp]; exact hi) (by rw [hp]; exact hpm) ext [] hne
            (by rw [List.length_nil, zero_add, hlenext, hp])
            (by rw [hmap, hsq, hlenext, hp, List.length_nil, add_zero]), List.nil_append]
      obtain ⟨new', hlen', hsum'⟩ := vSumFrom_roundHeads hw C er H x d ms (i + 1) (rest₁ ++ ext)
        (ptr ++ [(pm.getD m₀, ext.map Prod.snd)]) hdec₂ (by simp [hp])
        (by simp only [List.length_cons] at hn; omega)
      refine ⟨(pm.getD m₀, ext.map Prod.snd) :: new', by simp [hlen'], ?_⟩
      rw [hext, List.cons_append, hsum', trSumFrom]
    rw [roundHeads, List.flatMap_append, List.flatMap_cons]
    cases hhm : hasMsg i with
    | false =>
      rw [ite_eq_right (by simp)]
      simp only [List.flatMap_nil, List.nil_append]
      obtain ⟨new, hlen, hsum⟩ := hrun rest none (by simp [hhm]) hdec
      exact ⟨new, by rw [hlen]; rfl, hsum⟩
    | true =>
      rw [ite_eq_left rfl]
      simp only [List.flatMap_cons, List.flatMap_nil, List.append_nil, pSteps_items_msg, List.singleton_append]
      rw [ChainEnc.vSumFrom]
      have hmsg0 : eW n w hasMsg m₀ er ((PItem.stmt x, d) :: rest) (PItem.msg m) = 0 := by
        simp [eW]
      have hdec₁ : rDecodeW n w hasMsg m₀
          (rest ++ [(PItem.msg m, H (C.link (C.lastD H ((PItem.stmt x, d) :: rest)) (PItem.msg m)))])
          = some (ptr, some m, []) := by
        rw [rDecodeW, List.foldl_append, ← rDecodeW, hdec, List.foldl_cons, List.foldl_nil]
        show (if ptr.length < n ∧ hasMsg ptr.length = true then some (ptr, some m, []) else none) = _
        rw [ite_eq_left ⟨by rw [hp]; exact hi, by rw [hp]; exact hhm⟩]
      obtain ⟨new, hlen, hsum⟩ := hrun _ (some m) (by simp [hhm]) hdec₁
      refine ⟨new, by rw [hlen]; rfl, ?_⟩
      rw [hmsg0, zero_add, List.cons_append] at *
      exact hsum

end VSum

/-! ## The protocol on the chain -/

section FS

variable {X M Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]
variable {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}

omit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] in
/-- **The verifier's charge is at most `B`** when every transcript's round errors sum to at most `B`. -/
theorem vSumFrom_pHeadsW_le (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D)
    (er : X → List (M × List D) → M → ℝ≥0∞) (B : ℝ≥0∞)
    (hB : ∀ x τ, τ.length ≤ n → trSumFrom er x [] τ ≤ B) (H : Q → D) (x : X) (ms : List M) :
    C.vSumFrom (eW n w hasMsg m₀ er) H [] ((pHeadsW n w hasMsg x ms).flatMap (pSteps n w hw).items) ≤ B := by
  rw [pHeadsW, List.flatMap_cons, pSteps_items_stmt, List.singleton_append, ChainEnc.vSumFrom]
  have h0 : eW n w hasMsg m₀ er [] (PItem.stmt x) = 0 := rfl
  rw [h0, zero_add, List.nil_append]
  have hlen0 : 0 + (ms.take n).length ≤ n := by
    rw [zero_add, List.length_take]
    exact min_le_left _ _
  obtain ⟨new, hlen, hsum⟩ := vSumFrom_roundHeads (n := n) (hasMsg := hasMsg) (m₀ := m₀) hw C er H x
    (H (C.link (C.lastD H []) (PItem.stmt x))) (ms.take n) 0 [] [] rfl rfl hlen0
  rw [hsum]
  exact hB x new (by rw [hlen, List.length_take]; exact min_le_left _ _)

/-- **The protocol on the chain, with per-round errors, the general form** (a state that may read the log, stable
once the statement's link is logged). -/
theorem fs_chain_wide_flip_T (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D)
    (St : List (Q × D) → X → List (M × List D) → Prop) (er : X → List (M × List D) → M → ℝ≥0∞)
    (hR : ∀ P, RbrWideT n w (St P) er) (εmax : ℝ≥0∞) (hε : ∀ x τ m, τ.length < n → er x τ m ≤ εmax)
    (B : ℝ≥0∞) (hB : ∀ x τ, τ.length ≤ n → trSumFrom er x [] τ ≤ B)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (x : X) (τ : List (M × List D)), C.start ∈ P.map Prod.fst →
      C.link (H C.start) (PItem.stmt x) ∈ P.map Prod.fst → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P x τ ↔ St P' x τ))
    {Mf : Type} (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H =>
        ¬ St ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2 (A.run H).1 []
        ∧ ∃ ptr pm, rDecodeW n w hasMsg m₀ ((C.chainFrom H []
            ((pHeadsW n w hasMsg (A.run H).1 (A.run H).2.1).flatMap (pSteps n w hw).items)).drop 1)
              = some (ptr, pm, [])
          ∧ St ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2 (A.run H).1 ptr)
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓW n w + 1) D + collBound (q + ℓW n w + 1 + 1) D := by
  have hstab' : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (PItem X M × D)) (qs : List Q)
      (ext : List (PItem X M × D)), C.Chain H τ qs → 1 ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) →
        P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
          (liftStW n w hasMsg m₀ St P (τ ++ ext) ↔ liftStW n w hasMsg m₀ St P' (τ ++ ext)) := by
    intro H P P' τ qs ext hc hlen hqs hpre hL
    obtain ⟨⟨it0, d0⟩, rest, rfl⟩ : ∃ e rest, τ = e :: rest := by
      cases τ with
      | nil => simp at hlen
      | cons e rest => exact ⟨e, rest, rfl⟩
    obtain ⟨h1, h2⟩ := C.chain_head_mem H hc _ rest rfl
    cases it0 with
    | stmt x =>
      rw [List.cons_append, liftStW, liftStW]
      rcases rDecodeW n w hasMsg m₀ (rest ++ ext) with _ | ⟨ptr, pm, ds⟩
      · exact Iff.rfl
      · exact hstab H P P' x ptr (hqs _ h1) (hqs _ h2) hpre hL
    | msg m => simp [liftStW]
    | sq c => simp [liftStW]
  refine le_trans (MeasureTheory.measure_mono ?_)
    (chain_sound_wide_seq C (pSteps n w hw) (liftStW n w hasMsg m₀ St) 1 (eW n w hasMsg m₀ er) εmax
      (fun τ it => eW_le hε τ it)
      (fun P τ it h1 h2 h3 => liftStW_roundT hw St er hR P τ it h1 h2 h3) hstab'
      (fun o => pHeadsW n w hasMsg o.1 o.2.1) (ℓW n w) (fun o => pHeadsW_length_le hw _ _) B
      (fun H o => vSumFrom_pHeadsW_le hw C er B hB H o.1 o.2.1) q A hA)
  rintro H ⟨hns, ptr, pm, hdec, hst⟩
  set L := ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2
  set x := (A.run H).1
  obtain ⟨ext, hext, -⟩ := C.chainFrom_eq_append H ((roundHeads w hasMsg 0 ((A.run H).2.1.take n)).flatMap
    (pSteps n w hw).items) [(PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x)))]
  have hfull : C.chainFrom H [] ((pHeadsW n w hasMsg x (A.run H).2.1).flatMap (pSteps n w hw).items)
      = (PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x))) :: ext := by
    rw [pHeadsW, List.flatMap_cons, pSteps_items_stmt, List.singleton_append, ChainEnc.chainFrom,
      List.nil_append, hext, List.singleton_append]
  constructor
  · show ¬ liftStW n w hasMsg m₀ St L (C.chainFrom H [] (((pHeadsW n w hasMsg x (A.run H).2.1).take 1).flatMap
      (pSteps n w hw).items))
    rw [pHeadsW, List.take_succ_cons, List.take_zero, List.flatMap_cons, List.flatMap_nil, List.append_nil,
      pSteps_items_stmt, ChainEnc.chainFrom, ChainEnc.chainFrom, List.nil_append, liftStW]
    exact hns
  · show liftStW n w hasMsg m₀ St L (C.chainFrom H [] ((pHeadsW n w hasMsg x (A.run H).2.1).flatMap
      (pSteps n w hw).items))
    rw [hfull, liftStW]
    rw [hfull, List.drop_one, List.tail_cons] at hdec
    rw [hdec]
    exact hst

/-- **Fiat–Shamir soundness with per-round errors on the code's chain.** A protocol that is round-by-round sound with
per-round errors `er x τ m ≤ εmax` (`RbrWideT`, plus the start and final conditions), whose round errors sum to at
most `B` along every transcript, accepts a false statement from a prover making at most `q` hash queries with
probability at most `q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`. -/
theorem fs_chain_sound_of_rbrWideT (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type}
    {L : X → Prop} {accept : X → List (M × List D) → Mf → Prop} {St : X → List (M × List D) → Prop}
    {er : X → List (M × List D) → M → ℝ≥0∞} (hR : RbrWideT n w St er) (εmax : ℝ≥0∞)
    (hε : ∀ x τ m, τ.length < n → er x τ m ≤ εmax) (B : ℝ≥0∞)
    (hB : ∀ x τ, τ.length ≤ n → trSumFrom er x [] τ ≤ B) (hstart : ∀ x, ¬ L x → ¬ St x [])
    (hfinal : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓW n w + 1) D + collBound (q + ℓW n w + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_chain_wide_flip_T (hasMsg := hasMsg) (m₀ := m₀) hw C (fun _ => St) er (fun _ => hR) εmax hε B hB
      (fun _ _ _ _ _ _ _ _ _ => Iff.rfl) q A hA)
  rintro H ⟨hL, hlen, ptr, hdec, hacc⟩
  refine ⟨hstart _ hL, ptr, none, hdec, ?_⟩
  have hn := chainAcceptsW_length hw C H _ _ ptr hlen hdec
  by_contra hns
  exact hfinal _ _ _ hn hns hacc

end FS

end ZK60.Sound
