/-
D63 lane L39 (2026-11-10), part 2: **the parse congruence** (lane L34's finding L34-1).

A sub-protocol on the code's chain reads its window through a STEP PARSE `W : UInt64 → ℕ` (the width of the step a
squeeze starts, by its counter): the parse decides where steps end (`tRem`), the scheduled reader (`cRd`) checks that
a round's first squeeze starts a step of the round's width, and an opening's second half (`opBCSub`) reads its first
half's digests off its header through the same parse. Lanes L20, L22, L28 and L31 state their per-block results at the
block's OWN parse (L28's `OProf.W`: the block's seven wide runs from the counter at its `M` window, every other counter
`1`); the run's kinds (L34's `RunTrKinds.lean`) are at the RUN's parse `rtW pf.sqs` (every part's runs, back to back).
The two parses differ outside the block's window. This file proves that a sub-protocol and its events depend on the
parse only through the counters of its window, and that the two parses agree there, so per-block results carry:

* `SqAgree`: two parses agree at every squeeze counter of a chain segment;
* `rc_tRemStep_congr`, `rc_foldl_tRem_congr`, **`rc_tRem_congr`**, `rc_cRdStep_congr`, `rc_foldl_cRd_congr`,
  **`rc_cRd_congr`**: the step parse and the scheduled reader read the parse only at the segment's counters;
* **`rc_tRem_take_congr`**: two parses both at a step's end at a cut, agreeing from the cut on, agree at every later cut;
* **`rc_rdAlive_congr`**, **`rc_subSt_congr`**, **`rc_entD_congr`**: a sub-protocol's state on the chain (alive,
  entered doomed) under two such parses is the same, when its own state does not read the parse otherwise (`M`'s
  `maskCSubX`, an opening's first half `opACSub`, the slots, the draws);
* `rc_opARead_congr`, `rc_opBSt_congr`, **`rc_opBCSub_St`**, **`rc_subSt_opBCSub_congr`**, **`rc_entD_opBCSub_congr`**:
  the same for an opening's second half, whose state reads its first half's digests through the parse;
* `RdDone`, `rc_cRd_done_append`, **`rc_subSt_take`**, `rc_entD_take`: once a sub-protocol's reader is done (all its
  rounds read, or out of the schedule), the rest of the chain does not change its state;
* `rc_wRuns_append_ge`, `rc_wRuns_append_lt`, **`rc_rtW_runs`**, **`rc_rtW_oprof`**: the run's parse `rtW (pre ++ ns ++
  post)` IS a part's own parse `wRuns pre.sum ns` (L28's `OProf.W` when `pre.sum` is its `cM`) at every counter of the
  part's runs; `rc_sqs_split`, `rc_sqs_pre_sum`, **`rc_rtW_part`**, **`rc_rtW_part_oprof`**: the run profile's widths
  `pf.sqs` split at part `i`'s `M` and `A` / `H` runs, so `rtW pf.sqs` is part `i`'s own parse from the counter
  `pf.sqAt i + preSq` on (L34's `rtTr_part` gives the counter there);
* **`rc_subSt_carry`**, **`rc_opB_carry`**, **`rc_entD_carry`**: THE CARRY. A state stated at a block's own parse
  (`OProf.W`) on the run's transcript through the block's `H` opening is the state at the run's parse on the whole
  run's transcript, given: both parses at a step's end at the window, every counter from the window on inside the
  block's runs, and the reader done at the segment's end.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrKinds

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

/-! ## Two parses on a segment -/

section Congr

variable {D : Type}

/-- **Two parses agree at every squeeze counter of `τ`.** -/
def SqAgree (W W' : UInt64 → ℕ) (τ : List (TItem × D)) : Prop :=
  ∀ e ∈ τ, ∀ k, e.1 = TItem.squeeze k → W k = W' k

theorem sqAgree_mono {W W' : UInt64 → ℕ} {τ τ' : List (TItem × D)} (h : SqAgree W W' τ) (hs : τ' ⊆ τ) :
    SqAgree W W' τ' := fun e he => h e (hs he)

theorem sqAgree_symm {W W' : UInt64 → ℕ} {τ : List (TItem × D)} (h : SqAgree W W' τ) : SqAgree W' W τ :=
  fun e he k hk => (h e he k hk).symm

theorem rc_drop_take_sub (τ : List (TItem × D)) (a b : ℕ) : (τ.take b).drop a ⊆ τ.drop a := by
  intro x hx
  rw [List.drop_take] at hx
  exact List.mem_of_mem_take hx

theorem rc_drop_drop_sub (τ : List (TItem × D)) (a b : ℕ) (hab : a ≤ b) : τ.drop b ⊆ τ.drop a := by
  intro x hx
  have e : τ.drop b = (τ.drop a).drop (b - a) := by
    rw [List.drop_drop]
    congr 1
    omega
  rw [e] at hx
  exact List.mem_of_mem_drop hx

theorem rc_tRemStep_congr (W W' : UInt64 → ℕ) (o : Option ℕ) (it : TItem)
    (h : ∀ k, it = TItem.squeeze k → W k = W' k) : tRemStep W o it = tRemStep W' o it := by
  cases o with
  | none => cases it <;> rfl
  | some r =>
    cases r with
    | zero =>
      cases it with
      | absorb l x => rfl
      | squeeze k =>
        show some (W k - 1) = some (W' k - 1)
        rw [h k rfl]
    | succ r => cases it <;> rfl

theorem rc_foldl_tRem_congr (W W' : UInt64 → ℕ) : ∀ (τ : List (TItem × D)) (o : Option ℕ), SqAgree W W' τ →
    τ.foldl (fun o e => tRemStep W o e.1) o = τ.foldl (fun o e => tRemStep W' o e.1) o
  | [], _, _ => rfl
  | e :: τ, o, h => by
    have h1 : tRemStep W o e.1 = tRemStep W' o e.1 :=
      rc_tRemStep_congr W W' o e.1 (fun k hk => h e List.mem_cons_self k hk)
    simp only [List.foldl_cons]
    rw [h1]
    exact rc_foldl_tRem_congr W W' τ _ (fun e' he' => h e' (List.mem_cons_of_mem _ he'))

/-- **The step parse reads the parse only at the segment's counters.** -/
theorem rc_tRem_congr (W W' : UInt64 → ℕ) (τ : List (TItem × D)) (h : SqAgree W W' τ) : tRem W τ = tRem W' τ :=
  rc_foldl_tRem_congr W W' τ (some 0) h

theorem rc_cRdStep_congr (R : Rounds) (W W' : UInt64 → ℕ) (st : CRS D) (e : TItem × D)
    (h : ∀ k, e.1 = TItem.squeeze k → W k = W' k) : cRdStep R W st e = cRdStep R W' st e := by
  obtain ⟨it, dg⟩ := e
  rcases st with _ | ⟨ptr, pm, ds⟩
  · rfl
  · cases it with
    | absorb l x => rfl
    | squeeze k =>
      have hk : W k = W' k := h k rfl
      simp only [cRdStep, hk]

theorem rc_foldl_cRd_congr (R : Rounds) (W W' : UInt64 → ℕ) :
    ∀ (τ : List (TItem × D)) (st : CRS D), SqAgree W W' τ → τ.foldl (cRdStep R W) st = τ.foldl (cRdStep R W') st
  | [], _, _ => rfl
  | e :: τ, st, h => by
    rw [List.foldl_cons, List.foldl_cons, rc_cRdStep_congr R W W' st e (fun k hk => h e List.mem_cons_self k hk)]
    exact rc_foldl_cRd_congr R W W' τ _ (fun e' he' => h e' (List.mem_cons_of_mem _ he'))

/-- **The scheduled reader reads the parse only at the segment's counters.** -/
theorem rc_cRd_congr (R : Rounds) (W W' : UInt64 → ℕ) (τ : List (TItem × D)) (h : SqAgree W W' τ) :
    cRd R W τ = cRd R W' τ :=
  rc_foldl_cRd_congr R W W' τ _ h

/-- **Two parses both at a step's end at a cut `a`, agreeing at every counter from `a` on, agree at every later
cut.** -/
theorem rc_tRem_take_congr (W W' : UInt64 → ℕ) (τ : List (TItem × D)) (a b : ℕ) (hab : a ≤ b)
    (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0) (h : SqAgree W W' (τ.drop a)) :
    tRem W (τ.take b) = tRem W' (τ.take b) := by
  have e : τ.take b = τ.take a ++ (τ.take b).drop a := by
    have e0 := (List.take_append_drop a (τ.take b)).symm
    rw [List.take_take, min_eq_left hab] at e0
    exact e0
  rw [e, tRem_append, tRem_append, hW, hW']
  exact rc_foldl_tRem_congr W W' _ (some 0) (sqAgree_mono h (rc_drop_take_sub τ a b))

theorem rc_liftC_congr {P Q : List (List UInt8 × List D) → Prop} (h : ∀ x, P x ↔ Q x) (st : CRS D) :
    liftC P st ↔ liftC Q st := by
  rcases st with _ | ⟨ptr, pm, ds⟩
  · exact Iff.rfl
  · exact h ptr

/-- **A sub-protocol's reading under two parses** that are both at a step's end at a cut `a ≤ c.a` and agree from `a`
on: the same, for two sub-protocols with the same window and rounds and the same state on the header. -/
theorem rc_rdAlive_congr (W W' : UInt64 → ℕ) (c c' : CSub D) (τ : List (TItem × D)) (a : ℕ) (ha : a ≤ c.a)
    (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0) (h : SqAgree W W' (τ.drop a))
    (hca : c.a = c'.a) (hR : c.R = c'.R) (hSt : ∀ τ', c.St (τ.take c.a) τ' ↔ c'.St (τ.take c.a) τ') :
    rdAlive W c τ ↔ rdAlive W' c' τ := by
  unfold rdAlive
  rw [← hca, ← hR, rc_tRem_take_congr W W' τ a c.a ha hW hW' h,
    rc_cRd_congr c.R W W' (τ.drop c.a) (sqAgree_mono h (rc_drop_drop_sub τ a c.a ha))]
  exact and_congr Iff.rfl (rc_liftC_congr hSt _)

/-- **A sub-protocol's state on the chain under two such parses** is the same. -/
theorem rc_subSt_congr (W W' : UInt64 → ℕ) (c c' : CSub D) (τ : List (TItem × D)) (a : ℕ) (ha : a ≤ c.a)
    (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0) (h : SqAgree W W' (τ.drop a))
    (hca : c.a = c'.a) (hR : c.R = c'.R) (hSt : ∀ τ', c.St (τ.take c.a) τ' ↔ c'.St (τ.take c.a) τ')
    (hrel : c.rel τ ↔ c'.rel τ) : subSt W c τ ↔ subSt W' c' τ := by
  unfold subSt
  rw [← hca]
  exact or_congr Iff.rfl (or_congr (rc_rdAlive_congr W W' c c' τ a ha hW hW' h hca hR hSt) hrel)

/-- **Entering doomed under two such parses** is the same. -/
theorem rc_entD_congr (W W' : UInt64 → ℕ) (c c' : CSub D) (τ : List (TItem × D)) (a : ℕ) (ha : a ≤ c.a)
    (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0) (h : SqAgree W W' (τ.drop a))
    (hca : c.a = c'.a) (hSt : c.St (τ.take c.a) [] ↔ c'.St (τ.take c.a) []) : EntD W c τ ↔ EntD W' c' τ := by
  unfold EntD
  rw [← hca, rc_tRem_take_congr W W' τ a c.a ha hW hW' h]
  exact and_congr Iff.rfl (and_congr Iff.rfl (not_congr hSt))

/-! ## Cutting the chain once the reader is done -/

/-- **The reader is done** on a segment: out of the schedule, or all its rounds read. -/
def RdDone (R : Rounds) (W : UInt64 → ℕ) (τ : List (TItem × D)) : Prop :=
  cRd R W τ = none ∨ ∃ ptr pm ds, cRd R W τ = some (ptr, pm, ds) ∧ R.n ≤ ptr.length

theorem rc_cRd_done_append (R : Rounds) (W : UInt64 → ℕ) (τ rest : List (TItem × D)) (h : RdDone R W τ) :
    cRd R W (τ ++ rest) = cRd R W τ := by
  unfold RdDone cRd at h
  unfold cRd
  rw [List.foldl_append]
  rcases h with h | ⟨ptr, pm, ds, h, hn⟩
  · rw [h]
    exact foldl_cRdStep_none R W rest
  · rw [h]
    exact foldl_cRdStep_frozen R W hn rest

/-- **Cutting the chain after a sub-protocol's reader is done does not change its state.** -/
theorem rc_subSt_take (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) (b : ℕ) (hab : c.a ≤ b)
    (hb : b ≤ τ.length) (hd : RdDone c.R W ((τ.take b).drop c.a)) (hrel : c.rel τ ↔ c.rel (τ.take b)) :
    subSt W c τ ↔ subSt W c (τ.take b) := by
  have e1 : (τ.take b).take c.a = τ.take c.a := by rw [List.take_take, min_eq_left hab]
  have e2 : τ.drop c.a = (τ.take b).drop c.a ++ τ.drop b := by
    conv_lhs => rw [← List.take_append_drop b τ]
    rw [List.drop_append_of_le_length (by rw [List.length_take]; omega)]
  have hl : (τ.take b).length = b := by
    rw [List.length_take]
    omega
  unfold subSt rdAlive
  rw [e1, e2, rc_cRd_done_append c.R W _ _ hd, hl]
  exact or_congr ⟨fun h' => by omega, fun h' => by omega⟩ (or_congr Iff.rfl hrel)

/-- Entering doomed is read off the header: cutting the chain after the window does not change it. -/
theorem rc_entD_take (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) (b : ℕ) (hab : c.a ≤ b) :
    EntD W c τ ↔ EntD W c (τ.take b) := by
  unfold EntD
  rw [List.take_take, min_eq_left hab, List.length_take]
  constructor
  · rintro ⟨h1, h2, h3⟩
    exact ⟨by omega, h2, h3⟩
  · rintro ⟨h1, h2, h3⟩
    exact ⟨by omega, h2, h3⟩

/-- **THE CARRY, for a sub-protocol whose state does not read the parse** (`M`'s `maskCSubX`, an opening's first half
`opACSub`, the slots, the draws): its state at a parse `W` on a chain `τ` is its state at a parse `W'` on any
extension `τ ++ rest`, given both parses at a step's end at a cut `a ≤ c.a`, agreeing at every counter of `τ` from `a`
on, and its reader done at `τ`'s end under `W'`. -/
theorem rc_subSt_carry (W W' : UInt64 → ℕ) (c : CSub D) (τ rest : List (TItem × D)) (a : ℕ) (ha : a ≤ c.a)
    (hca : c.a ≤ τ.length) (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0)
    (h : SqAgree W W' (τ.drop a)) (hdone : RdDone c.R W' (τ.drop c.a)) (hrel : c.rel τ ↔ c.rel (τ ++ rest)) :
    subSt W c τ ↔ subSt W' c (τ ++ rest) := by
  have ht : (τ ++ rest).take τ.length = τ := List.take_left' rfl
  have e := rc_subSt_take W' c (τ ++ rest) τ.length hca (by rw [List.length_append]; omega) (by rw [ht]; exact hdone)
    (by rw [ht]; exact hrel.symm)
  rw [ht] at e
  exact (rc_subSt_congr W W' c c τ a ha hW hW' h rfl rfl (fun _ => Iff.rfl) Iff.rfl).trans e.symm

/-- **THE CARRY of entering doomed**, for a sub-protocol whose state does not read the parse. -/
theorem rc_entD_carry (W W' : UInt64 → ℕ) (c : CSub D) (τ rest : List (TItem × D)) (a : ℕ) (ha : a ≤ c.a)
    (hca : c.a ≤ τ.length) (hW : tRem W (τ.take a) = some 0) (hW' : tRem W' (τ.take a) = some 0)
    (h : SqAgree W W' (τ.drop a)) : EntD W c τ ↔ EntD W' c (τ ++ rest) := by
  have ht : (τ ++ rest).take τ.length = τ := List.take_left' rfl
  have e := rc_entD_take W' c (τ ++ rest) τ.length hca
  rw [ht] at e
  exact (rc_entD_congr W W' c c τ a ha hW hW' h rfl Iff.rfl).trans e.symm

end Congr

/-! ## An opening's second half -/

section Open

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ}

/-- `opA`'s digests read off a header under two parses agreeing from `opA`'s window on. -/
theorem rc_opARead_congr (W W' : UInt64 → ℕ) (aA w0 : ℕ) (hdr : List (TItem × Dig))
    (hh : SqAgree W W' (hdr.drop aA)) : opARead W aA w0 hdr = opARead W' aA w0 hdr := by
  unfold opARead
  rw [rc_cRd_congr _ W W' _ hh]

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- L10's `opBSt` reads its `(λ, ρ)` only at its statement. -/
theorem rc_opBSt_congr {X : Type} (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : X → OClaims Cl G κ μ F)
    (Ux : X → κ → Fin (2 ^ h) → F) (lrOf lrOf' : X → (Cl → F) × (κ → F)) (vOf : X → G → μ → F) (d₀ : Dg) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (x : X) (hx : lrOf x = lrOf' x)
    (τ : List (Option (μ → F) × List Dg)) :
    opBSt enc e clOf Ux lrOf vOf d₀ m chalJ x τ ↔ opBSt enc e clOf Ux lrOf' vOf d₀ m chalJ x τ := by
  have e1 : opBSt enc e clOf Ux lrOf vOf d₀ m chalJ x = opBSt enc e clOf Ux (fun _ => lrOf x) vOf d₀ m chalJ x := rfl
  have e2 : opBSt enc e clOf Ux lrOf' vOf d₀ m chalJ x = opBSt enc e clOf Ux (fun _ => lrOf' x) vOf d₀ m chalJ x :=
    rfl
  rw [e1, e2, hx]

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **An opening's second half reads the parse only from its first half's window on**: its state on a header is the
same under two parses that agree at every counter of the header from `aA` on. -/
theorem rc_opBCSub_St (W W' : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (hdr : List (TItem × Dig)) (hh : SqAgree W W' (hdr.drop aA))
    (τ : List (List UInt8 × List Dig)) :
    (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB).St hdr τ
      ↔ (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB).St hdr τ := by
  have hr := rc_opARead_congr W W' aA w0 hdr hh
  have hlr : opBLR W aA w0 d₀ chalLR hdr = opBLR W' aA w0 d₀ chalLR hdr := by
    unfold opBLR
    rw [hr]
  show (opARead W aA w0 hdr).isSome = true
      ∧ opBSt enc e (fun y : HdrX κ F h => clOf (y.1.take aA)) (fun y => y.2) (fun y => opBLR W aA w0 d₀ chalLR y.1)
        (fun y => vOf y.1) d₀ m chalJ (hdr, Ux (hdr.take aA)) (τ.map (fun p => (decB p.1, p.2.map halves)))
    ↔ (opARead W' aA w0 hdr).isSome = true
      ∧ opBSt enc e (fun y : HdrX κ F h => clOf (y.1.take aA)) (fun y => y.2) (fun y => opBLR W' aA w0 d₀ chalLR y.1)
        (fun y => vOf y.1) d₀ m chalJ (hdr, Ux (hdr.take aA)) (τ.map (fun p => (decB p.1, p.2.map halves)))
  rw [hr]
  exact and_congr Iff.rfl (rc_opBSt_congr enc e (fun y : HdrX κ F h => clOf (y.1.take aA)) (fun y => y.2)
    (fun y : HdrX κ F h => opBLR W aA w0 d₀ chalLR y.1) (fun y : HdrX κ F h => opBLR W' aA w0 d₀ chalLR y.1)
    (fun y => vOf y.1) d₀ m chalJ (hdr, Ux (hdr.take aA)) hlr _)

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **An opening's second half's state on the chain under two parses** both at a step's end at its first half's
window `aA` and agreeing from there on. -/
theorem rc_subSt_opBCSub_congr (W W' : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ : List (TItem × Dig)) (hab : aA ≤ aB) (hW : tRem W (τ.take aA) = some 0)
    (hW' : tRem W' (τ.take aA) = some 0) (hh : SqAgree W W' (τ.drop aA)) :
    subSt W (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ
      ↔ subSt W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ :=
  rc_subSt_congr W W' _ _ τ aA hab hW hW' hh rfl rfl
    (fun τ' => rc_opBCSub_St W W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB (τ.take aB)
      (sqAgree_mono hh (rc_drop_take_sub τ aA aB)) τ') Iff.rfl

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **An opening's second half entering doomed under two such parses** is the same. -/
theorem rc_entD_opBCSub_congr (W W' : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ : List (TItem × Dig)) (hab : aA ≤ aB) (hW : tRem W (τ.take aA) = some 0)
    (hW' : tRem W' (τ.take aA) = some 0) (hh : SqAgree W W' (τ.drop aA)) :
    EntD W (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ
      ↔ EntD W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ :=
  rc_entD_congr W W' _ _ τ aA hab hW hW' hh rfl
    (rc_opBCSub_St W W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB (τ.take aB)
      (sqAgree_mono hh (rc_drop_take_sub τ aA aB)) [])

end Open

/-! ## The run's parse is a part's own parse on the part's runs -/

theorem rc_wRuns_append_ge : ∀ (c : ℕ) (a b : List ℕ), (∀ n ∈ a, 0 < n) → ∀ k, c + a.sum ≤ k →
    wRuns c (a ++ b) k = wRuns (c + a.sum) b k
  | c, [], b, _, k, _ => by simp
  | c, n :: a, b, hp, k, hk => by
    have hn := hp n List.mem_cons_self
    rw [List.sum_cons] at hk
    rw [List.cons_append, wRuns, ite_eq_right (by omega),
      rc_wRuns_append_ge (c + n) a b (fun m hm => hp m (List.mem_cons_of_mem _ hm)) k (by omega), List.sum_cons,
      Nat.add_assoc]

theorem rc_wRuns_append_lt : ∀ (c : ℕ) (a b : List ℕ), (∀ n ∈ b, 0 < n) → ∀ k, k < c + a.sum →
    wRuns c (a ++ b) k = wRuns c a k
  | c, [], b, hp, k, hk => by
    simp only [List.sum_nil, Nat.add_zero] at hk
    rw [List.nil_append, wRuns_lt c b hp k hk]
    rfl
  | c, n :: a, b, hp, k, hk => by
    rw [List.sum_cons] at hk
    rw [List.cons_append, wRuns, wRuns]
    split_ifs
    · rfl
    · exact rc_wRuns_append_lt (c + n) a b hp k (by omega)

/-- **The run's parse is a part's own parse on the part's runs**: if the run's widths are `pre ++ ns ++ post` (every
width positive), at every counter of the runs `ns` the run's parse `rtW` is `wRuns pre.sum ns`, the runs `ns` back to
back from the counter `pre.sum`. -/
theorem rc_rtW_runs (pre ns post : List ℕ) (hp : ∀ n ∈ pre ++ ns ++ post, 0 < n) (k : UInt64)
    (hk1 : pre.sum ≤ k.toNat) (hk2 : k.toNat < pre.sum + ns.sum) :
    rtW (pre ++ ns ++ post) k = wRuns pre.sum ns k.toNat := by
  show wRuns 0 (pre ++ ns ++ post) k.toNat = _
  rw [List.append_assoc, rc_wRuns_append_ge 0 pre (ns ++ post) (fun n hn => hp n (by simp [hn])) k.toNat (by omega),
    Nat.zero_add, rc_wRuns_append_lt pre.sum ns post (fun n hn => hp n (by simp [hn])) k.toNat hk2]

/-- **The run's parse is L28's block parse `OProf.W` on the block's runs**, when the run's widths are
`pre ++ pr.ns ++ post` with `pre.sum` the counter at the block's `M` window (`pr.cM`). -/
theorem rc_rtW_oprof {P : Block.BlockParams} (pr : OProf P) (pre post : List ℕ) (hpre : pre.sum = pr.cM)
    (hp : ∀ n ∈ pre ++ pr.ns ++ post, 0 < n) (k : UInt64) (hk1 : pr.cM ≤ k.toNat)
    (hk2 : k.toNat < pr.cM + pr.ns.sum) : rtW (pre ++ pr.ns ++ post) k = pr.W k := by
  rw [rc_rtW_runs pre pr.ns post hp k (by omega) (by omega), hpre]
  rfl

theorem rc_sum_flatMap_sqs : ∀ l : List RtPart, (l.flatMap RtPart.sqs).sum = (l.map RtPart.sq).sum
  | [] => rfl
  | p :: l => by
    rw [List.flatMap_cons, List.sum_append, RtPart.sqs_sum, rc_sum_flatMap_sqs l, List.map_cons, List.sum_cons]

/-- Part `i`'s `M` and `A` / `H` runs: `θ`, `M`'s row coefficients, `M`'s indices, `A`'s batching and indices, `H`'s. -/
def rcRunsMAH (p : RtPart) : List ℕ := [1, 2 * p.S + 2, 64, p.wA, p.mA, p.wH, p.mH]

/-- The widths before part `i`'s `M` window. -/
def rcPre (pf : RtProf) (i : ℕ) : List ℕ :=
  List.replicate pf.hdrSq 1 ++ (pf.parts.take i).flatMap RtPart.sqs ++ List.replicate (pf.part i).preSq 1

/-- The widths after part `i`'s `H` opening. -/
def rcPost (pf : RtProf) (i : ℕ) : List ℕ := [(pf.part i).wX, (pf.part i).mX] ++ (pf.parts.drop (i + 1)).flatMap RtPart.sqs

/-- **The run profile's widths, split at part `i`'s `M`, `A` and `H` runs.** -/
theorem rc_sqs_split (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length) :
    pf.sqs = rcPre pf i ++ rcRunsMAH (pf.part i) ++ rcPost pf i := by
  have hpart : pf.part i = pf.parts[i] := by simp [RtProf.part, hi]
  have hp : pf.parts = pf.parts.take i ++ pf.part i :: pf.parts.drop (i + 1) := by
    rw [hpart, ← List.drop_eq_getElem_cons hi, List.take_append_drop]
  unfold RtProf.sqs rcPre rcPost rcRunsMAH
  conv_lhs => rw [hp]
  simp only [List.flatMap_append, List.flatMap_cons, RtPart.sqs, List.append_assoc, List.cons_append, List.nil_append]

/-- **The counter at part `i`'s `M` window** is the sum of the widths before it. -/
theorem rc_sqs_pre_sum (pf : RtProf) (i : ℕ) : (rcPre pf i).sum = pf.sqAt i + (pf.part i).preSq := by
  unfold rcPre RtProf.sqAt
  rw [List.sum_append, List.sum_append, List.sum_replicate, List.sum_replicate, rc_sum_flatMap_sqs, List.map_take]
  simp

/-- **The run's parse on part `i`'s `M`, `A` and `H` runs**: at every counter from part `i`'s `M` window
(`pf.sqAt i + preSq`) through its `H` opening, the run's parse `rtW pf.sqs` is part `i`'s own parse. -/
theorem rc_rtW_part (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length) (hp : ∀ n ∈ pf.sqs, 0 < n) (k : UInt64)
    (hk1 : pf.sqAt i + (pf.part i).preSq ≤ k.toNat)
    (hk2 : k.toNat < pf.sqAt i + (pf.part i).preSq + (rcRunsMAH (pf.part i)).sum) :
    rtW pf.sqs k = wRuns (pf.sqAt i + (pf.part i).preSq) (rcRunsMAH (pf.part i)) k.toNat := by
  rw [← rc_sqs_pre_sum pf i] at hk1 hk2 ⊢
  have e := rc_sqs_split pf i hi
  have hp' : ∀ n ∈ rcPre pf i ++ rcRunsMAH (pf.part i) ++ rcPost pf i, 0 < n := by
    rw [← e]
    exact hp
  rw [e]
  exact rc_rtW_runs _ _ _ hp' k hk1 hk2

/-- **The run's parse is L28's `OProf.W` of block part `i`** at every counter of the block's `M` / `A` / `H` runs,
when the block's opening profile has the part's counter and runs: `pr.cM = pf.sqAt i + preSq` and `pr.ns` the part's
seven runs (`[1, 2S + 2, 64, nA + rA, mI, nH + rH, mI]`). -/
theorem rc_rtW_part_oprof {P : Block.BlockParams} (pr : OProf P) (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length)
    (hp : ∀ n ∈ pf.sqs, 0 < n) (hcM : pr.cM = pf.sqAt i + (pf.part i).preSq) (hns : pr.ns = rcRunsMAH (pf.part i))
    (k : UInt64) (hk1 : pr.cM ≤ k.toNat) (hk2 : k.toNat < pr.cM + pr.ns.sum) : rtW pf.sqs k = pr.W k := by
  rw [hcM] at hk1
  rw [hcM, hns] at hk2
  rw [rc_rtW_part pf i hi hp k hk1 hk2, ← hcM, ← hns]
  rfl

/-! ## The carry of an opening's second half -/

section CarryB

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ}

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **THE CARRY of an opening's second half from a block's own parse to the run's** (finding L34-1): on the run's
transcript `τ` through the block's opening (a step's end under both parses at `opA`'s window `aA`; every counter from
`aA` on inside the block's runs, where `W` and the run's parse `W'` agree; `opB`'s reader done at `τ`'s end), the state
of `opBCSub` at the block's parse on `τ` is its state at the run's parse on the whole run `τ ++ rest`. -/
theorem rc_opB_carry (W W' : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ rest : List (TItem × Dig)) (hab : aA ≤ aB) (hτ : aB ≤ τ.length)
    (hW : tRem W (τ.take aA) = some 0) (hW' : tRem W' (τ.take aA) = some 0) (hh : SqAgree W W' (τ.drop aA))
    (hdone : RdDone (opBRounds labB m) W' (τ.drop aB)) :
    subSt W (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ
      ↔ subSt W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) (τ ++ rest) := by
  have ht : (τ ++ rest).take τ.length = τ := List.take_left' rfl
  have e1 := rc_subSt_take W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) (τ ++ rest)
    τ.length hτ (by rw [List.length_append]; omega) (by rw [ht]; exact hdone) Iff.rfl
  rw [ht] at e1
  exact (rc_subSt_opBCSub_congr W W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB τ hab hW hW' hh).trans
    e1.symm

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **THE CARRY of an opening's second half entering doomed.** -/
theorem rc_opB_entD_carry (W W' : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ rest : List (TItem × Dig)) (hab : aA ≤ aB) (hτ : aB ≤ τ.length)
    (hW : tRem W (τ.take aA) = some 0) (hW' : tRem W' (τ.take aA) = some 0) (hh : SqAgree W W' (τ.drop aA)) :
    EntD W (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) τ
      ↔ EntD W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) (τ ++ rest) := by
  have ht : (τ ++ rest).take τ.length = τ := List.take_left' rfl
  have e1 := rc_entD_take W' (opBCSub W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB) (τ ++ rest)
    τ.length hτ
  rw [ht] at e1
  exact (rc_entD_opBCSub_congr W W' aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB τ hab hW hW'
    hh).trans e1.symm

end CarryB

/-- **The counters of a segment inside a block's runs give the agreement** of L28's `OProf.W` and the run's parse. -/
theorem rc_sqAgree_part {D : Type} {P : Block.BlockParams} (pr : OProf P) (pf : RtProf) (i : ℕ)
    (hi : i < pf.parts.length) (hp : ∀ n ∈ pf.sqs, 0 < n) (hcM : pr.cM = pf.sqAt i + (pf.part i).preSq)
    (hns : pr.ns = rcRunsMAH (pf.part i)) (τ : List (TItem × D))
    (hτ : ∀ x ∈ τ, ∀ k, x.1 = TItem.squeeze k → pr.cM ≤ k.toNat ∧ k.toNat < pr.cM + pr.ns.sum) :
    SqAgree pr.W (rtW pf.sqs) τ :=
  fun x hx k hk => (rc_rtW_part_oprof pr pf i hi hp hcM hns k (hτ x hx k hk).1 (hτ x hx k hk).2).symm

end ZK60.ProtocolClassify
