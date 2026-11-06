/-
D63 step L8 (the executable verifier): Fiat–Shamir COMPOSITION on the code's own transcript chain.

L7 (`ExecSumcheckFS.lean`) read ONE sub-protocol off the code's chain (`codeSt`: a header, then rounds "absorb under a
label, one squeeze"). `FSCompose.lean` composes sub-protocols on one chain with the MAXIMUM round error, and
`FSWideRbr.lean` adds vector challenges and rounds with no message, but both read `PItem` model chains. This file states
the composition directly on the code's chain (`List (TItem × D)`, the items with the code's counters and their
digests), so a whole receipt (many sub-protocols, interstitial absorbs and challenge vectors, ONE executable
transcript) gets the composed bound as a theorem about the executable transcript.

**The schedule** (`CSub`, `Rounds`). A sub-protocol's window starts at a FIXED entry `a` (the profile's schedule shape,
as L7's fixed header length, L7-3); its header is EVERYTHING before the window (items, counters, digests: earlier
sub-protocols, interstitial absorbs and challenges), so its claim may depend on any of it (L7-2: a slot's claimed sum is
its `pb-scalar` plus earlier scalars times `ν`-derived coefficients). Its rounds: per round a message flag, a label and
a width `w i` (a vector challenge of `w i` squeezes, `challenge_fp2_vec`). Its state `St` reads the header and its own
rounds (absorbed bytes and raw digests) and is `RbrWide` with error `ε` (`FSCompose.lean`'s `SubProt`); `rel` is a
release (its claim handed on to a later sub-protocol, `SubProt.post`).

**The scheduled reader** (`cRdStep`, `cRd`). From the window on, a round's message is one absorb under its label, its
challenge its squeezes; the round's FIRST squeeze must start a step of the round's width (`W k = w i`: the squeeze's
counter is read only through a width function `W`); the `w i`-th digest completes the round; after the `n` rounds the
reader is FROZEN (interstitial items and other sub-protocols' items leave it unchanged). A vector challenge is ONE step
of `FSWide.lean`'s `Steps` (`chain_sound_wide` charges its joint error once); the step parse `tRem` says where steps end,
and a window must start at a step's end.

**The states.** `subSt`: alive before its window, then alive when read alive (`rdAlive`) or released. `allSt`: all alive
(`AllAlive`). `everSt`: alive now, but doomed at SOME earlier step's end.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* the parse: `tRem_stE` (a whole step keeps it at a step's end), `tRem_stE_take` (inside a step it owes items);
* the reader: `cInv_step`, `cInv_foldl`, `cInv_bnd` (over whole steps the reader is between rounds), `cRd_sqRun` (a
  round's squeeze run completes it with exactly its digests), `foldl_cRdStep_frozen`;
* `rdAlive_step`: from a doomed reading, the next step revives it with probability at most the sub-protocol's `ε`;
* `allSt_rbr`: **the combined state is round-by-round with the LARGEST error**: the largest doomed sub-protocol has
  started its window, cannot be revived by a release (`hframe`: a release only when a LATER one is doomed), so a revival
  is its own reading's (`Composed.rbrWide`'s argument, on chains);
* `everSt_rbr`: being doomed at a LATER step's end costs nothing extra (an alive chain whose step ends were all alive
  cannot make `everSt` hold in one step), so a claim that becomes false long after the start (a slot's) is covered
  without a union over the windows;
* `codeRbr_step`, `tRem_steps`, `ents_eq_zip`: the step bound is `chain_sound_wide`'s round hypothesis on any
  `ChainEnc` whose items read as code items and whose steps are a head then squeezes (`StepsOK`);
* **`fs_code_chain_ever`, `fs_code_chain_sound_sched`**: on ANY code-item chain, a `q`-query prover makes some
  sub-protocol enter its window with a false claim and yet every sub-protocol alive at the end with probability at most
  `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`, for any `ε` above every sub-protocol's error;
* `stepsB`, `stepsB_ok`: the code's own items (`ItB L`) with any widths `W` (`1 ≤ W k ≤ 2^64`) are such steps (a
  squeeze `k` continues with `k + 1, k + 2, …`, distinct although the counter wraps: `ctr_add_ne`, `ctr_add_inj`);
  `stepsOne`, `W1`, `tRem_W1`: every squeeze its own step, every chain whole steps (no counter premise at all);
* the executable instance: `Slot` (a sumcheck slot: its interstitial operations' count `s`, degree `d`, rounds `n`, and
  its statement as a function of the code's trace before its rounds), `slotSub`, `slotSubs`, `slotSub_rbr` (each slot
  `RbrWide` with `d·(⌊2^128/p⌋+1)²/|Dig|`, from `sumcheck_rbr` by `rbrWide_of_rbrSound` and `RbrWide.comap`),
  `cRd_rounds`, `slot_take` (a slot's header is the executable transcript's trace), `slot_alive` (an accepting
  `scVerify` makes the slot alive on the run's chain), `slot_transcript_next` (each slot runs on the transcript the
  previous slot's accepting `verify` leaves: ONE transcript), `slotsWin_event`;
* **`exec_sumchecks_fs_sound`**: for a run of slots on one executable transcript, the probability that SOME slot's claim
  is false and yet EVERY slot's executable `sumcheck::verify` accepts with its terminal check is at most
  `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ` the run's items: the LARGEST
  degree, not a sum over slots; `exec_sumchecks_fs_sound_goldilocks`, `exec_sumchecks_fs_sound_slot` (`dmax ≤ 4`,
  `T ≤ 2^64 + 2^20`: at most `2^-61`, the bound of ONE slot).

Why not `FSCompose.lean`'s `Composed` itself: it is indexed by ROUND number (`w : ℕ → ℕ`, `own : ℕ → J`), while on the
code's chain a step's width is its head ITEM's (a squeeze counter) and interstitial items are no round. Its
largest-doomed argument is re-proved on chains (`allSt_rbr`); `RbrWide`, `RbrWide.comap`, `rbrWide_of_rbrSound`,
`chain_sound_wide`, `prob_ofFn_congr` and L7's bridge (`chainEncB`, `chainFrom_liftH`, `opTrace_chainFrom`,
`card_chal_fiber_le`, `dig_bound_le`, `slot_bound_le`, `decMsg_enc`, `zip_dec_scTau`) are reused as they are.

What a per-profile instance must still supply: its schedule (the window positions, each sub-protocol's rounds, state and
`RbrWide`, and `W`: `W1` when every challenge is single squeezes, otherwise a `W` under which the verifier's own items
parse as whole steps with each wide round's first squeeze a step head of its width); for each slot its statement as a
function of the trace (the arithmetization) and its polynomial as the committed tables' (the extraction); a release and
`hframe` when a claim is handed on (a slot's terminal claim to an opening); the premises of L7 (start premise, `L`,
`1 ≤ d < p`, canonical words).
-/
import ZK60Formal.ExecSumcheckFS
import ZK60Formal.FSComposeBlock

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Finset

/-! ## The step parse of the code's items -/

section Parse

variable {D : Type}

/-- The width of the step a code item starts: an absorb is a step of one item; a squeeze whose counter is `k` starts a
step of `W k` squeezes (a vector challenge). -/
def tWd (W : UInt64 → ℕ) : TItem → ℕ
  | .absorb _ _ => 1
  | .squeeze k => W k

/-- One item of the step parse: the number of items still owed to the step in progress (`none`: the items are not a
sequence of whole steps). -/
def tRemStep (W : UInt64 → ℕ) : Option ℕ → TItem → Option ℕ
  | some 0, .absorb _ _ => some 0
  | some 0, .squeeze k => some (W k - 1)
  | some (r + 1), .squeeze _ => some r
  | _, _ => none

theorem tRemStep_zero_absorb (W : UInt64 → ℕ) (l x : List UInt8) : tRemStep W (some 0) (.absorb l x) = some 0 := rfl

theorem tRemStep_zero_sq (W : UInt64 → ℕ) (k : UInt64) : tRemStep W (some 0) (.squeeze k) = some (W k - 1) := rfl

theorem tRemStep_succ_sq (W : UInt64 → ℕ) (r : ℕ) (k : UInt64) : tRemStep W (some (r + 1)) (.squeeze k) = some r := rfl

theorem tRemStep_succ_absorb (W : UInt64 → ℕ) (r : ℕ) (l x : List UInt8) :
    tRemStep W (some (r + 1)) (.absorb l x) = none := rfl

theorem tRemStep_none (W : UInt64 → ℕ) (it : TItem) : tRemStep W none it = none := by cases it <;> rfl

/-- **The step parse** of a chain transcript: `some 0` exactly when it is a sequence of whole steps. -/
def tRem (W : UInt64 → ℕ) (τ : List (TItem × D)) : Option ℕ := τ.foldl (fun o e => tRemStep W o e.1) (some 0)

/-- **A step's entries**: its first item `h`, then squeezes with the counters `ks`, paired with the step's digests. -/
def stE (h : TItem) (ks : List UInt64) (ds : List D) : List (TItem × D) := (h :: ks.map TItem.squeeze).zip ds

theorem tRem_append (W : UInt64 → ℕ) (τ e : List (TItem × D)) :
    tRem W (τ ++ e) = e.foldl (fun o x => tRemStep W o x.1) (tRem W τ) := by
  simp only [tRem, List.foldl_append]

theorem foldl_tRemStep_none (W : UInt64 → ℕ) :
    ∀ es : List (TItem × D), es.foldl (fun o x => tRemStep W o x.1) none = none
  | [] => rfl
  | e :: es => by
    rw [List.foldl_cons]
    rw [tRemStep_none]
    exact foldl_tRemStep_none W es

/-- A run of squeezes takes one owed item each. -/
theorem foldl_tRemStep_sq (W : UInt64 → ℕ) : ∀ (es : List (TItem × D)) (m : ℕ),
    (∀ e ∈ es, ∃ k, e.1 = .squeeze k) → es.length ≤ m →
      es.foldl (fun o x => tRemStep W o x.1) (some m) = some (m - es.length)
  | [], m, _, _ => by simp
  | e :: es, m, h, hl => by
    obtain ⟨k, hk⟩ := h e List.mem_cons_self
    obtain ⟨m', rfl⟩ : ∃ m', m = m' + 1 := ⟨m - 1, by simp only [List.length_cons] at hl; omega⟩
    simp only [List.foldl_cons, hk, tRemStep_succ_sq]
    rw [foldl_tRemStep_sq W es m' (fun e' he' => h e' (List.mem_cons_of_mem _ he'))
        (by simp only [List.length_cons] at hl; omega)]
    simp only [List.length_cons, Option.some.injEq]
    omega

theorem stE_cons (h : TItem) (ks : List UInt64) (d : D) (ds : List D) :
    stE h ks (d :: ds) = (h, d) :: (ks.map TItem.squeeze).zip ds := rfl

theorem stE_length (h : TItem) (ks : List UInt64) (ds : List D) (hd : ds.length = ks.length + 1) :
    (stE h ks ds).length = ks.length + 1 := by
  simp only [stE, List.length_zip, List.length_cons, List.length_map, hd, min_self]

theorem zip_sq_isSq (ks : List UInt64) (ds : List D) :
    ∀ e ∈ (ks.map TItem.squeeze).zip ds, ∃ k, e.1 = .squeeze k := by
  intro e he
  obtain ⟨k, -, hk⟩ := List.mem_map.mp (List.of_mem_zip he).1
  exact ⟨k, hk.symm⟩

theorem zip_sq_length (ks : List UInt64) (ds : List D) (hd : ds.length = ks.length) :
    ((ks.map TItem.squeeze).zip ds).length = ks.length := by
  simp only [List.length_zip, List.length_map, hd, min_self]

/-- **A whole step keeps the parse at a step's end.** -/
theorem tRem_stE (W : UInt64 → ℕ) {τ : List (TItem × D)} (hτ : tRem W τ = some 0) (h : TItem) (ks : List UInt64)
    (ds : List D) (hk : ks.length + 1 = tWd W h) (hd : ds.length = ks.length + 1) :
    tRem W (τ ++ stE h ks ds) = some 0 := by
  rw [tRem_append, hτ]
  obtain ⟨d0, ds', rfl⟩ : ∃ d0 ds', ds = d0 :: ds' := by
    cases ds with
    | nil => simp at hd
    | cons d0 ds' => exact ⟨d0, ds', rfl⟩
  simp only [List.length_cons, Nat.add_right_cancel_iff] at hd
  simp only [stE_cons, List.foldl_cons]
  cases h with
  | absorb l x =>
    simp only [tWd] at hk
    obtain rfl : ks = [] := List.eq_nil_of_length_eq_zero (by omega)
    simp [tRemStep_zero_absorb]
  | squeeze k =>
    simp only [tWd] at hk
    simp only [tRemStep_zero_sq]
    rw [foldl_tRemStep_sq W _ _ (zip_sq_isSq ks ds') (by rw [zip_sq_length ks ds' hd]; omega), zip_sq_length ks ds' hd]
    simp only [Option.some.injEq]
    omega

/-- **Inside a step the parse is not at a step's end**: a proper nonempty prefix of a step leaves items owed. -/
theorem tRem_stE_take (W : UInt64 → ℕ) {τ : List (TItem × D)} (hτ : tRem W τ = some 0) (h : TItem)
    (ks : List UInt64) (ds : List D) (hk : ks.length + 1 = tWd W h) (hd : ds.length = ks.length + 1) (r : ℕ)
    (hr0 : 0 < r) (hr : r < ks.length + 1) : tRem W (τ ++ (stE h ks ds).take r) ≠ some 0 := by
  rw [tRem_append, hτ]
  obtain ⟨d0, ds', rfl⟩ : ∃ d0 ds', ds = d0 :: ds' := by
    cases ds with
    | nil => simp at hd
    | cons d0 ds' => exact ⟨d0, ds', rfl⟩
  simp only [List.length_cons, Nat.add_right_cancel_iff] at hd
  obtain ⟨r', rfl⟩ : ∃ r', r = r' + 1 := ⟨r - 1, by omega⟩
  simp only [stE_cons, List.take_succ_cons, List.foldl_cons]
  cases h with
  | absorb l x =>
    simp only [tWd] at hk
    omega
  | squeeze k =>
    simp only [tWd] at hk
    have hsq : ∀ e ∈ ((ks.map TItem.squeeze).zip ds').take r', ∃ k, e.1 = .squeeze k :=
      fun e he => zip_sq_isSq ks ds' e (List.mem_of_mem_take he)
    have hl : (((ks.map TItem.squeeze).zip ds').take r').length = r' := by
      rw [List.length_take, zip_sq_length ks ds' hd]
      omega
    simp only [tRemStep_zero_sq]
    rw [foldl_tRemStep_sq W _ _ hsq (by rw [hl]; omega), hl]
    simp only [ne_eq, Option.some.injEq]
    omega

end Parse

/-! ## The scheduled reader -/

/-- **A sub-protocol's round schedule** on the code's chain: `n` rounds; round `i` has a message iff `hasMsg i` (one
absorb under the label `lab i`), then `w i` squeezes (its challenge: one digest, or a vector of `w i`). -/
structure Rounds where
  n : ℕ
  w : ℕ → ℕ
  hasMsg : ℕ → Bool
  lab : ℕ → List UInt8

/-- The reader's state: the rounds read so far (each round's absorbed bytes, `[]` for a round with no message, and its
digests), the message pending, the digests of the round in progress; `none` once the chain leaves the schedule. -/
abbrev CRS (D : Type) := Option (List (List UInt8 × List D) × Option (List UInt8) × List D)

section Reader

variable {D : Type}

/-- **One step of the scheduled reader.** After the `n` rounds the reader is frozen (it ignores every later item: an
interstitial, another sub-protocol's). Before: an absorb under the round's label is its message (only in a round
that has one, and only between rounds); a squeeze adds a digest to the round in progress, and the round's FIRST
squeeze must start a step of the round's width (`W k = w i`: the parse and the round agree); the round's `w i`-th
digest completes it. The squeeze's counter is read only through `W`. Anything else leaves the schedule. -/
def cRdStep (R : Rounds) (W : UInt64 → ℕ) : CRS D → TItem × D → CRS D
  | none, _ => none
  | some (τ, pm, ds), (.absorb l x, _) =>
    if R.n ≤ τ.length then some (τ, pm, ds)
    else match pm, ds with
      | none, [] => if R.hasMsg τ.length = true ∧ l = R.lab τ.length then some (τ, some x, []) else none
      | _, _ => none
  | some (τ, pm, ds), (.squeeze k, dg) =>
    if R.n ≤ τ.length then some (τ, pm, ds)
    else if R.hasMsg τ.length = pm.isSome ∧ (ds.length = 0 → W k = R.w τ.length) then
      (if ds.length + 1 = R.w τ.length then some (τ ++ [(pm.getD [], ds ++ [dg])], none, [])
      else some (τ, pm, ds ++ [dg]))
    else none

/-- **The scheduled reader** of the entries from a sub-protocol's window on. -/
def cRd (R : Rounds) (W : UInt64 → ℕ) (τ : List (TItem × D)) : CRS D := τ.foldl (cRdStep R W) (some ([], none, []))

theorem foldl_cRdStep_none (R : Rounds) (W : UInt64 → ℕ) :
    ∀ es : List (TItem × D), es.foldl (cRdStep R W) none = none
  | [] => rfl
  | e :: es => by
    rw [List.foldl_cons]
    have h : cRdStep R W none e = none := rfl
    rw [h]
    exact foldl_cRdStep_none R W es

/-- **Frozen after the window**: once the `n` rounds are read, nothing changes the reading. -/
theorem foldl_cRdStep_frozen (R : Rounds) (W : UInt64 → ℕ) {ptr : List (List UInt8 × List D)}
    {pm : Option (List UInt8)} {ds : List D} (hn : R.n ≤ ptr.length) :
    ∀ es : List (TItem × D), es.foldl (cRdStep R W) (some (ptr, pm, ds)) = some (ptr, pm, ds)
  | [] => rfl
  | (it, dg) :: es => by
    rw [List.foldl_cons]
    have h : cRdStep R W (some (ptr, pm, ds)) (it, dg) = some (ptr, pm, ds) := by
      cases it <;> simp [cRdStep, hn]
    rw [h]
    exact foldl_cRdStep_frozen R W hn es

/-- The reader and the parse agree: the invariant tying the reader's state to the items still owed to the step in
progress. Frozen: no digests pending. Active: between rounds nothing is owed; inside a round's challenge, the
digests read and the items owed make the round's width. -/
def CInv (R : Rounds) : CRS D → ℕ → Prop
  | none, _ => True
  | some (ptr, _, ds), r => (R.n ≤ ptr.length → ds = [])
      ∧ (ptr.length < R.n → (ds = [] ∧ r = 0) ∨ (ds ≠ [] ∧ ds.length + r = R.w ptr.length ∧ 0 < r))

theorem cInv_start (R : Rounds) : CInv (D := D) R (some ([], none, [])) 0 :=
  ⟨fun _ => rfl, fun _ => Or.inl ⟨rfl, rfl⟩⟩

/-- **The invariant is kept by every item** of a sequence of whole steps. -/
theorem cInv_step (R : Rounds) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (st : CRS D) (r r' : ℕ) (e : TItem × D)
    (hI : CInv R st r) (hr : tRemStep W (some r) e.1 = some r') : CInv R (cRdStep R W st e) r' := by
  obtain ⟨it, dg⟩ := e
  rcases st with _ | ⟨ptr, pm, ds⟩
  · trivial
  obtain ⟨hfz, hact⟩ := hI
  by_cases hn : R.n ≤ ptr.length
  · have hstep : cRdStep R W (some (ptr, pm, ds)) (it, dg) = some (ptr, pm, ds) := by
      cases it <;> simp [cRdStep, hn]
    rw [hstep]
    exact ⟨hfz, fun h => absurd h (not_lt.mpr hn)⟩
  have hlt : ptr.length < R.n := lt_of_not_ge hn
  cases it with
  | absorb l x =>
    have hr0 : r = 0 ∧ r' = 0 := by
      cases r with
      | zero =>
        simp only [tRemStep, Option.some.injEq] at hr
        exact ⟨rfl, hr.symm⟩
      | succ r => simp [tRemStep] at hr
    obtain ⟨rfl, rfl⟩ := hr0
    have hds : ds = [] := by
      rcases hact hlt with h | h
      · exact h.1
      · omega
    subst hds
    cases pm with
    | none =>
      simp only [cRdStep, hn, ↓reduceIte]
      split_ifs
      · exact ⟨fun h => absurd h hn, fun _ => Or.inl ⟨rfl, rfl⟩⟩
      · trivial
    | some m => simp [cRdStep, hn, CInv]
  | squeeze k =>
    simp only [cRdStep, hn, ↓reduceIte]
    cases r with
    | zero =>
      simp only [tRemStep, Option.some.injEq] at hr
      have hds : ds = [] := by
        rcases hact hlt with h | h
        · exact h.1
        · omega
      subst hds
      split_ifs with hc hl
      · refine ⟨fun _ => rfl, fun _ => Or.inl ⟨rfl, ?_⟩⟩
        have := hc.2 rfl
        simp only [List.length_nil, zero_add] at hl
        omega
      · refine ⟨fun h => absurd h hn, fun _ => Or.inr ⟨by simp, ?_, ?_⟩⟩
        · have := hc.2 rfl
          simp only [List.length_nil, zero_add] at hl
          simp only [List.nil_append, List.length_singleton]
          have := hW k
          omega
        · have := hc.2 rfl
          simp only [List.length_nil, zero_add] at hl
          have := hW k
          omega
      · trivial
    | succ r0 =>
      simp only [tRemStep, Option.some.injEq] at hr
      subst hr
      rcases hact hlt with h | ⟨hne, hsum, -⟩
      · omega
      split_ifs with hc hl
      · exact ⟨fun _ => rfl, fun _ => Or.inl ⟨rfl, by omega⟩⟩
      · refine ⟨fun h => absurd h hn, fun _ => Or.inr ⟨by simp, ?_, ?_⟩⟩
        · simp only [List.length_append, List.length_singleton]
          omega
        · omega
      · trivial

/-- **Over whole steps the invariant holds.** -/
theorem cInv_foldl (R : Rounds) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) :
    ∀ (es : List (TItem × D)) (st : CRS D) (r r' : ℕ), CInv R st r →
      es.foldl (fun o x => tRemStep W o x.1) (some r) = some r' → CInv R (es.foldl (cRdStep R W) st) r'
  | [], st, r, r', hI, h => by
    simp only [List.foldl_nil, Option.some.injEq] at h
    subst h
    exact hI
  | e :: es, st, r, r', hI, h => by
    rw [List.foldl_cons] at h ⊢
    rcases hs : tRemStep W (some r) e.1 with _ | r1
    · rw [hs, foldl_tRemStep_none] at h
      cases h
    · rw [hs] at h
      exact cInv_foldl R W hW es _ r1 r' (cInv_step R W hW st r r1 e hI hs) h

/-- At a step's end the reader is between rounds (or out of the schedule). -/
theorem cInv_bnd {R : Rounds} {st : CRS D} (h : CInv R st 0) : st = none ∨ ∃ ptr pm, st = some (ptr, pm, []) := by
  rcases st with _ | ⟨ptr, pm, ds⟩
  · exact Or.inl rfl
  · right
    refine ⟨ptr, pm, ?_⟩
    obtain ⟨hfz, hact⟩ := h
    by_cases hn : R.n ≤ ptr.length
    · rw [hfz hn]
    · rcases hact (lt_of_not_ge hn) with h | h
      · rw [h.1]
      · omega

/-- **A round's squeeze run**: from the round's start (or inside its challenge), the round's remaining squeezes
complete it with exactly their digests. -/
theorem cRd_sqRun (R : Rounds) (W : UInt64 → ℕ) (ptr : List (List UInt8 × List D)) (pm : Option (List UInt8))
    (hn : ptr.length < R.n) (hm : R.hasMsg ptr.length = pm.isSome) :
    ∀ (es : List (TItem × D)) (ds0 : List D), es ≠ [] → (∀ e ∈ es, ∃ k, e.1 = .squeeze k) →
      ds0.length + es.length = R.w ptr.length →
      (ds0 = [] → ∀ k dg rest, es = (.squeeze k, dg) :: rest → W k = R.w ptr.length) →
      es.foldl (cRdStep R W) (some (ptr, pm, ds0)) = some (ptr ++ [(pm.getD [], ds0 ++ es.map Prod.snd)], none, [])
  | [], _, h, _, _, _ => absurd rfl h
  | (it, dg) :: rest, ds0, _, hsq, hlen, hW0 => by
    obtain ⟨k, hk⟩ := hsq _ List.mem_cons_self
    simp only at hk
    subst hk
    rw [List.foldl_cons]
    have hc : R.hasMsg ptr.length = pm.isSome ∧ (ds0.length = 0 → W k = R.w ptr.length) :=
      ⟨hm, fun h0 => hW0 (List.eq_nil_of_length_eq_zero h0) k dg rest rfl⟩
    have hstep : cRdStep R W (some (ptr, pm, ds0)) (TItem.squeeze k, dg)
        = if ds0.length + 1 = R.w ptr.length then some (ptr ++ [(pm.getD [], ds0 ++ [dg])], none, [])
          else some (ptr, pm, ds0 ++ [dg]) := by
      simp only [cRdStep, not_le.mpr hn, ↓reduceIte]
      rw [ite_eq_left hc]
    rw [hstep]
    simp only [List.length_cons] at hlen
    by_cases hl : ds0.length + 1 = R.w ptr.length
    · rw [ite_eq_left hl]
      obtain rfl : rest = [] := List.eq_nil_of_length_eq_zero (by omega)
      simp
    · rw [ite_eq_right hl]
      have hne : rest ≠ [] := fun h => by
        subst h
        simp only [List.length_nil] at hlen
        omega
      rw [cRd_sqRun R W ptr pm hn hm rest (ds0 ++ [dg]) hne (fun e he => hsq e (List.mem_cons_of_mem _ he))
        (by simp only [List.length_append, List.length_singleton]; omega) (fun h => absurd h (by simp))]
      simp

end Reader

/-! ## Sub-protocols on the code's chain and their states -/

/-- **A sub-protocol of a schedule on the code's chain.** Its window starts at entry `a` (a fixed position: the
schedule's shape); its header is EVERYTHING before (the chain's first `a` entries: items, counters, digests), so its
claim may depend on any earlier absorb or challenge. `R` is its round schedule, `ε` its error, `St` its state on the
header and its own rounds (each round's absorbed bytes and raw digests), and `rel` a RELEASE of its state: once its
claim is handed on to a later sub-protocol (`FSCompose.lean`'s `post`), `rel` may hold and the state is alive. -/
structure CSub (D : Type) where
  a : ℕ
  R : Rounds
  ε : ℝ≥0∞
  St : List (TItem × D) → List (List UInt8 × List D) → Prop
  rel : List (TItem × D) → Prop

section States

variable {D : Type}

/-- The protocol's state of a reading: the rounds read (a pending message or digests do not change it); a reading out
of the schedule is doomed. -/
def liftC (P : List (List UInt8 × List D) → Prop) : CRS D → Prop
  | some (ptr, _, _) => P ptr
  | none => False

/-- **The sub-protocol's state read off the chain**: its window starts at a step's end, and its state of the header
and of the rounds the reader reads from the window on is alive. -/
def rdAlive (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) : Prop :=
  tRem W (τ.take c.a) = some 0 ∧ liftC (c.St (τ.take c.a)) (cRd c.R W (τ.drop c.a))

/-- **A sub-protocol's state on the chain**: alive before its window; then alive when read alive or released. -/
def subSt (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) : Prop :=
  τ.length < c.a ∨ rdAlive W c τ ∨ c.rel τ

/-- **The combined state**: every sub-protocol of the schedule is alive (`FSCompose.lean`'s `AllAlive`). -/
def allSt (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) : Prop :=
  ∀ (k : ℕ) (c : CSub D), cs[k]? = some c → subSt W c τ

/-- **Doomed at some step's end, alive now.** The combined state is alive, and at some earlier step's end it was
doomed (a sub-protocol entered its window with a false claim, possibly long after the start). -/
def everSt (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) : Prop :=
  allSt W cs τ ∧ ∃ j, j ≤ τ.length ∧ tRem W (τ.take j) = some 0 ∧ ¬ allSt W cs (τ.take j)

/-- Sub-protocol `k` is doomed (a definition, so that the instance search sees only the classical decision). -/
def doomedAt (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) (k : ℕ) : Prop :=
  ∃ c, cs[k]? = some c ∧ ¬ subSt W c τ

variable [Fintype D] [Nonempty D]

/-- **Round-by-round on the code's chain, step by step**: from a doomed sequence of whole steps, a uniform draw of the
next step's digests escapes with probability at most `ε`, whatever the step's items. -/
def CodeRbr (W : UInt64 → ℕ) (Φ : List (TItem × D) → Prop) (ε : ℝ≥0∞) : Prop :=
  ∀ (τ : List (TItem × D)) (h : TItem) (ks : List UInt64), tRem W τ = some 0 → ks.length + 1 = tWd W h → ¬ Φ τ →
    (PMF.uniformOfFintype (Fin (ks.length + 1) → D)).toOuterMeasure {b | Φ (τ ++ stE h ks (List.ofFn b))} ≤ ε

/-- **A sub-protocol's own step.** From a doomed reading inside or after its window, the next step revives it with
probability at most its error: an absorb never does, a round's squeeze run is the protocol's round (`RbrWide`), a
frozen reading never changes, anything else leaves the schedule. -/
theorem rdAlive_step (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (c : CSub D) (hR : RbrWide c.R.n c.R.w c.St c.ε)
    (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (hτ : tRem W τ = some 0) (hk : ks.length + 1 = tWd W h)
    (ha : c.a ≤ τ.length) (hns : ¬ rdAlive W c τ) :
    (PMF.uniformOfFintype (Fin (ks.length + 1) → D)).toOuterMeasure {b | rdAlive W c (τ ++ stE h ks (List.ofFn b))}
      ≤ c.ε := by
  have hempty : ∀ E : Set (Fin (ks.length + 1) → D), (∀ b, b ∉ E) →
      (PMF.uniformOfFintype (Fin (ks.length + 1) → D)).toOuterMeasure E ≤ c.ε := by
    intro E hE
    rw [Set.eq_empty_iff_forall_notMem.mpr hE, MeasureTheory.measure_empty]
    exact zero_le
  have hset : ∀ e : List (TItem × D), rdAlive W c (τ ++ e) ↔ tRem W (τ.take c.a) = some 0
      ∧ liftC (c.St (τ.take c.a)) (e.foldl (cRdStep c.R W) (cRd c.R W (τ.drop c.a))) := by
    intro e
    unfold rdAlive
    rw [List.take_append_of_le_length ha, List.drop_append_of_le_length ha, cRd, cRd, List.foldl_append]
  by_cases hal : tRem W (τ.take c.a) = some 0
  swap
  · exact hempty _ (fun b hb => hal ((hset _).mp hb).1)
  have hdrop : (τ.drop c.a).foldl (fun o x => tRemStep W o x.1) (some 0) = some 0 := by
    have h0 := hτ
    rw [← List.take_append_drop c.a τ, tRem_append, hal] at h0
    exact h0
  have hbnd := cInv_bnd (cInv_foldl c.R W hW (τ.drop c.a) _ 0 0 (cInv_start c.R) hdrop)
  have hns' : ¬ liftC (c.St (τ.take c.a)) (cRd c.R W (τ.drop c.a)) := fun h' => hns ⟨hal, h'⟩
  change ¬ liftC (c.St (τ.take c.a)) ((τ.drop c.a).foldl (cRdStep c.R W) (some ([], none, []))) at hns'
  rcases hbnd with hnone | ⟨ptr, pm, hsome⟩
  · refine hempty _ (fun b hb => ?_)
    have h1 := ((hset _).mp hb).2
    rw [cRd, hnone, foldl_cRdStep_none] at h1
    exact h1
  rw [hsome] at hns'
  simp only [liftC] at hns'
  by_cases hfz : c.R.n ≤ ptr.length
  · refine hempty _ (fun b hb => ?_)
    have h1 := ((hset _).mp hb).2
    rw [cRd, hsome, foldl_cRdStep_frozen c.R W hfz] at h1
    exact hns' h1
  have hlt := lt_of_not_ge hfz
  cases h with
  | absorb l x =>
    simp only [tWd] at hk
    obtain rfl : ks = [] := List.eq_nil_of_length_eq_zero (by omega)
    refine hempty _ (fun b hb => ?_)
    have h1 := ((hset _).mp hb).2
    rw [cRd, hsome] at h1
    have hb1 : stE (TItem.absorb l x) [] (List.ofFn b) = [(TItem.absorb l x, b 0)] := by
      simp [stE, List.ofFn_succ]
    rw [hb1, List.foldl_cons, List.foldl_nil] at h1
    cases pm with
    | none =>
      simp only [cRdStep, hfz, ↓reduceIte] at h1
      split_ifs at h1
      · exact hns' h1
      · exact h1
    | some m => simp [cRdStep, hfz, liftC] at h1
  | squeeze k =>
    simp only [tWd] at hk
    by_cases hc : c.R.hasMsg ptr.length = pm.isSome ∧ W k = c.R.w ptr.length
    · have hrun : ∀ b : Fin (ks.length + 1) → D, (stE (.squeeze k) ks (List.ofFn b)).foldl (cRdStep c.R W)
          (some (ptr, pm, [])) = some (ptr ++ [(pm.getD [], List.ofFn b)], none, []) := by
        intro b
        have hl : (List.ofFn b).length = ks.length + 1 := List.length_ofFn
        rw [cRd_sqRun c.R W ptr pm hlt hc.1 _ [] (by
            intro h0
            have := congrArg List.length h0
            rw [stE_length _ _ _ hl] at this
            simp at this)
          (by
            intro e he
            obtain ⟨d0, ds', hds⟩ : ∃ d0 ds', List.ofFn b = d0 :: ds' := by
              cases h' : List.ofFn b with
              | nil => rw [h'] at hl; simp at hl
              | cons d0 ds' => exact ⟨d0, ds', rfl⟩
            rw [hds, stE_cons, List.mem_cons] at he
            rcases he with rfl | he
            · exact ⟨k, rfl⟩
            · exact zip_sq_isSq ks ds' e he)
          (by rw [List.length_nil, zero_add, stE_length _ _ _ hl]; omega)
          (by
            intro _ k' dg rest hes
            obtain ⟨d0, ds', hds⟩ : ∃ d0 ds', List.ofFn b = d0 :: ds' := by
              cases h' : List.ofFn b with
              | nil => rw [h'] at hl; simp at hl
              | cons d0 ds' => exact ⟨d0, ds', rfl⟩
            rw [hds, stE_cons, List.cons.injEq, Prod.mk.injEq, TItem.squeeze.injEq] at hes
            rw [← hes.1.1]
            exact hc.2)]
        have hsnd : (stE (.squeeze k) ks (List.ofFn b)).map Prod.snd = List.ofFn b := by
          simp only [stE]
          exact List.map_snd_zip (by simp)
        rw [List.nil_append, hsnd]
      have hset2 : {b : Fin (ks.length + 1) → D | rdAlive W c (τ ++ stE (.squeeze k) ks (List.ofFn b))}
          = {b | c.St (τ.take c.a) (ptr ++ [(pm.getD [], List.ofFn b)])} := by
        ext b
        rw [Set.mem_ofPred_eq, Set.mem_ofPred_eq, hset, cRd, hsome, hrun b]
        simp only [hal, true_and, liftC]
      rw [hset2, prob_ofFn_congr (show ks.length + 1 = c.R.w ptr.length by omega)
        (fun ds => c.St (τ.take c.a) (ptr ++ [(pm.getD [], ds)]))]
      exact hR.round (τ.take c.a) ptr (pm.getD []) hlt hns'
    · refine hempty _ (fun b hb => ?_)
      have h1 := ((hset _).mp hb).2
      rw [cRd, hsome] at h1
      have hl : (List.ofFn b).length = ks.length + 1 := List.length_ofFn
      obtain ⟨d0, ds', hds⟩ : ∃ d0 ds', List.ofFn b = d0 :: ds' := by
        cases h' : List.ofFn b with
        | nil => rw [h'] at hl; simp at hl
        | cons d0 ds' => exact ⟨d0, ds', rfl⟩
      rw [hds, stE_cons, List.foldl_cons] at h1
      have hc' : ¬ (c.R.hasMsg ptr.length = pm.isSome ∧ (([] : List D).length = 0 → W k = c.R.w ptr.length)) :=
        fun h' => hc ⟨h'.1, h'.2 rfl⟩
      have hstep : cRdStep c.R W (some (ptr, pm, [])) (TItem.squeeze k, d0) = none := by
        simp only [cRdStep, hfz, ↓reduceIte]
        rw [ite_eq_right hc']
      rw [hstep, foldl_cRdStep_none] at h1
      exact h1

/-- **The combined state is round-by-round, step by step, with the LARGEST error** (`FSCompose.lean`'s
`Composed.rbrWide`, on the code's chain). From a doomed chain, take the largest doomed sub-protocol `k₀`. Its window
has started (before it a sub-protocol is alive). A release cannot revive it (`hframe`: only a later doomed one could
take its claim, and none is), so a revival is its own reading's, at most its error. -/
theorem allSt_rbr (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (CSub D)) (ε : ℝ≥0∞)
    (hR : ∀ c ∈ cs, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ c ∈ cs, c.ε ≤ ε)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      cs[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h → ds.length = ks.length + 1 →
      ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ cs[k']? = some c' ∧ ¬ subSt W c' τ) :
    CodeRbr W (allSt W cs) ε := by
  intro τ h ks hτ hk hns
  classical
  have hne : ((range cs.length).filter (fun k => doomedAt W cs τ k)).Nonempty := by
    simp only [allSt, not_forall] at hns
    obtain ⟨k, c, hc, hd⟩ := hns
    exact ⟨k, mem_filter.mpr ⟨mem_range.mpr (List.getElem?_eq_some_iff.mp hc).1,
      (⟨c, hc, hd⟩ : ∃ c, cs[k]? = some c ∧ ¬ subSt W c τ)⟩⟩
  obtain ⟨-, c₀, hc₀, hd₀⟩ := mem_filter.mp (max'_mem _ hne)
  have hmax : ∀ k' c', ((range cs.length).filter (fun k => doomedAt W cs τ k)).max' hne < k' →
      cs[k']? = some c' → subSt W c' τ := by
    intro k' c' hlt hc'
    by_contra hd'
    have := le_max' ((range cs.length).filter (fun k => doomedAt W cs τ k)) k'
      (mem_filter.mpr ⟨mem_range.mpr (List.getElem?_eq_some_iff.mp hc').1,
        (⟨c', hc', hd'⟩ : ∃ c, cs[k']? = some c ∧ ¬ subSt W c τ)⟩)
    omega
  have ha : c₀.a ≤ τ.length := by
    by_contra hlt
    exact hd₀ (Or.inl (lt_of_not_ge hlt))
  have hnsA : ¬ rdAlive W c₀ τ := fun h' => hd₀ (Or.inr (Or.inl h'))
  have hsub : {b : Fin (ks.length + 1) → D | allSt W cs (τ ++ stE h ks (List.ofFn b))}
      ⊆ {b | rdAlive W c₀ (τ ++ stE h ks (List.ofFn b))} := by
    intro b hb
    rcases hb _ c₀ hc₀ with h1 | h1 | h1
    · simp only [List.length_append] at h1
      omega
    · exact h1
    · obtain ⟨k', c', hlt, hc', hd'⟩ := hframe _ c₀ τ h ks (List.ofFn b) hc₀ hτ hk List.length_ofFn hd₀ h1
      exact absurd (hmax k' c' hlt hc') hd'
  exact (MeasureTheory.measure_mono hsub).trans ((rdAlive_step W hW c₀ (hR c₀ (List.mem_of_getElem? hc₀)) τ h ks hτ
    hk ha hnsA).trans (hε c₀ (List.mem_of_getElem? hc₀)))

/-- **Doomed at a LATER step's end costs nothing extra.** `everSt` is round-by-round with the combined state's error:
from a doomed combined state an escape is the combined state's; from an alive one whose every step's end was alive, the
next step cannot make `everSt` hold (no new step's end is doomed and alive at once, and inside the step the parse
owes items). -/
theorem everSt_rbr (W : UInt64 → ℕ) (cs : List (CSub D)) (ε : ℝ≥0∞) (hA : CodeRbr W (allSt W cs) ε) :
    CodeRbr W (everSt W cs) ε := by
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

end States

/-! ## On any code-item chain -/

section Chain

variable {D It' : Type}

/-- A chain entry as a code item with its digest. -/
def toTE (toT : It' → TItem) (p : It' × D) : TItem × D := (toT p.1, p.2)

theorem map_toTE_zip (toT : It' → TItem) : ∀ (l : List It') (ds : List D),
    (l.zip ds).map (toTE toT) = (l.map toT).zip ds
  | [], _ => rfl
  | _ :: _, [] => rfl
  | a :: l, d :: ds => by
    simp only [List.zip_cons_cons, List.map_cons, toTE, map_toTE_zip toT l ds]

theorem map_toTE_eq_zip (toT : It' → TItem) : ∀ l : List (It' × D),
    l.map (toTE toT) = ((l.map Prod.fst).map toT).zip (l.map Prod.snd)
  | [] => rfl
  | p :: l => by simp only [List.map_cons, List.zip_cons_cons, toTE, map_toTE_eq_zip toT l]

theorem zipItems_eq (f : ℕ → It') : ∀ (j : ℕ) (ds : List D),
    zipItems f j ds = ((List.range ds.length).map (fun i => f (j + i))).zip ds
  | _, [] => rfl
  | j, d :: ds => by
    rw [zipItems, zipItems_eq f (j + 1) ds, List.length_cons, List.range_succ_eq_map, List.map_cons, List.map_map,
      List.zip_cons_cons, Nat.add_zero]
    congr 2
    refine List.map_congr_left (fun i _ => ?_)
    simp only [Function.comp_apply]
    exact congrArg f (by omega)

/-- A whole step's entries pair the step's items with its digests. -/
theorem ents_eq_zip (S : Steps It') (it : It') (ds : List D) (hd : ds.length = S.wd it) :
    S.ents it ds = (S.items it).zip ds := by
  rw [Steps.ents, zipItems_eq, Steps.items, hd]
  simp only [zero_add]

/-- **The steps read as code items**: each step is its head, then squeezes, and its width is the head's (`tWd`). -/
def StepsOK (W : UInt64 → ℕ) (toT : It' → TItem) (S : Steps It') : Prop :=
  ∀ it, ∃ ks : List UInt64, (S.items it).map toT = toT it :: ks.map TItem.squeeze ∧ ks.length + 1 = tWd W (toT it)

/-- **Whole steps parse as whole steps.** -/
theorem tRem_steps (W : UInt64 → ℕ) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S) :
    ∀ (hs : List It') (π : List (TItem × D)) (τ : List (It' × D)), tRem W π = some 0 →
      τ.map Prod.fst = hs.flatMap S.items → tRem W (π ++ τ.map (toTE toT)) = some 0
  | [], π, τ, hπ, hτ => by
    have h0 : τ = [] := by
      rw [List.flatMap_nil] at hτ
      exact List.map_eq_nil_iff.mp hτ
    subst h0
    simpa using hπ
  | h :: hs, π, τ, hπ, hτ => by
    obtain ⟨ks, hks, hkl⟩ := hS h
    rw [List.flatMap_cons] at hτ
    have h1 : (τ.take (S.items h).length).map Prod.fst = S.items h := by
      rw [List.map_take, hτ, List.take_left' rfl]
    have h2 : (τ.drop (S.items h).length).map Prod.fst = hs.flatMap S.items := by
      rw [List.map_drop, hτ, List.drop_left' rfl]
    have hl : ((τ.take (S.items h).length).map Prod.snd).length = ks.length + 1 := by
      have e1 := congrArg List.length h1
      have e2 := congrArg List.length hks
      rw [List.length_map] at e1
      rw [List.length_map, List.length_cons, List.length_map] at e2
      rw [List.length_map, e1, e2]
    have hstep : (τ.take (S.items h).length).map (toTE toT)
        = stE (toT h) ks ((τ.take (S.items h).length).map Prod.snd) := by
      rw [map_toTE_eq_zip, h1, hks]
      rfl
    rw [← List.take_append_drop (S.items h).length τ, List.map_append, ← List.append_assoc, hstep]
    exact tRem_steps W toT S hS hs _ _ (tRem_stE W hπ (toT h) ks _ hkl hl) h2

variable [Fintype D] [Nonempty D]

/-- **From the code-item bound to `chain_sound_wide`'s round hypothesis**: on a chain of whole steps, the next step's
uniform digests are a step of code items. -/
theorem codeRbr_step (W : UInt64 → ℕ) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {Φ : List (TItem × D) → Prop} {ε : ℝ≥0∞} (hΦ : CodeRbr W Φ ε) (τ : List (It' × D)) (it : It')
    (hbd : ∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items) (hns : ¬ Φ (τ.map (toTE toT))) :
    (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure
      {b | Φ ((τ ++ S.ents it (List.ofFn b)).map (toTE toT))} ≤ ε := by
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

/-- The code items of a chain of the prover's heads, each expanded to its step. -/
def cChain {Q : Type} (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (H : Q → D) (hs : List It') :
    List (TItem × D) :=
  (C.chainFrom H [] (hs.flatMap S.items)).map (toTE toT)

variable [DecidableEq D] {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The scheduled composition on any code-item chain, the general form.** For sub-protocols on one chain (`cs`, each
`RbrWide` with its error, releases handed on only forward: `hframe`), the probability that the chain is alive at the
end but was doomed at some step's end is at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`, for any
`ε` above every sub-protocol's error. -/
theorem fs_code_chain_ever (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (CSub D)) (ε : ℝ≥0∞)
    (hR : ∀ c ∈ cs, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ c ∈ cs, c.ε ≤ ε)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      cs[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h → ds.length = ks.length + 1 →
      ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ cs[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => everSt W cs (cChain C toT S H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  have hE := everSt_rbr W cs ε (allSt_rbr W hW cs ε hR hε hframe)
  refine le_trans (MeasureTheory.measure_mono ?_)
    (chain_sound_wide C S (fun _ τ => everSt W cs (τ.map (toTE toT))) 0 ε
      (fun _ τ it _ h2 h3 => codeRbr_step W toT S hS hE τ it h2 h3) (fun _ _ _ _ _ _ _ _ _ _ _ => Iff.rfl)
      heads ℓ hℓ q A hA)
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  refine ⟨?_, hH⟩
  simp only [List.take_zero, List.flatMap_nil, ChainEnc.chainFrom, List.map_nil]
  rintro ⟨h1, j, hj, -, h2⟩
  simp only [List.length_nil, Nat.le_zero] at hj
  subst hj
  exact h2 h1

/-- **The scheduled composition on any code-item chain** (D63 step L8): `FSCompose.lean`'s `fs_chain_sound_sched`, on
the code's own chain. Sub-protocols (`cs`) run on one chain, each in its window at a fixed position, its header
everything before the window, its rounds read by the scheduled reader (labels, messages, vector challenges of the
step parse's widths `W`), each `RbrWide` with its error; a release is handed on only forward (`hframe`). A prover
making at most `q` hash queries outputs heads; the verifier hashes their steps (at most `ℓ` items). The probability
that SOME sub-protocol enters its window with a false claim (`¬ St header []`, at a step's end, not released) and yet
EVERY sub-protocol is alive at the end is at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`, for
any `ε` above every sub-protocol's error: the per-query rate is the largest error, not the sum. -/
theorem fs_code_chain_sound_sched (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (CSub D)) (ε : ℝ≥0∞)
    (hR : ∀ c ∈ cs, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ c ∈ cs, c.ε ≤ ε)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      cs[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h → ds.length = ks.length + 1 →
      ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ cs[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), cs[k]? = some c ∧ c.a ≤ (cChain C toT S H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT S H (heads (A.run H))).take c.a) = some 0
          ∧ ¬ c.St ((cChain C toT S H (heads (A.run H))).take c.a) []
          ∧ ¬ c.rel ((cChain C toT S H (heads (A.run H))).take c.a))
        ∧ allSt W cs (cChain C toT S H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_code_chain_ever W hW cs ε hR hε hframe C toT S hS heads ℓ hℓ q A hA)
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

end Chain

/-! ## The code's own steps, for any widths -/

section CodeSteps

/-- The forced continuation of a code item's step: a squeeze with counter `k` continues with the counters
`k + 1, k + 2, …` (wrapping, as the code's `u64` counter does); an absorb's step has none (any value). -/
def contB {L : ℕ} : ItB L → ℕ → ItB L
  | ⟨.squeeze k, h⟩, j => ⟨.squeeze (k + 1 + UInt64.ofNat j), ⟨trivial, h.2⟩⟩
  | it, _ => it

theorem ctr_add_ne (k : UInt64) (j : ℕ) (hj : j + 1 < 2 ^ 64) : k + 1 + UInt64.ofNat j ≠ k := by
  intro h
  have h1 := congrArg UInt64.toNat h
  have hk : k.toNat < 2 ^ 64 := k.toNat_lt_size
  have hone : (1 : UInt64).toNat = 1 := rfl
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat', hone] at h1
  omega

theorem ctr_add_inj (k : UInt64) (i j : ℕ) (hi : i < 2 ^ 64) (hj : j < 2 ^ 64)
    (h : k + 1 + UInt64.ofNat i = k + 1 + UInt64.ofNat j) : i = j := by
  have h1 := congrArg UInt64.toNat h
  have hk : k.toNat < 2 ^ 64 := k.toNat_lt_size
  have hone : (1 : UInt64).toNat = 1 := rfl
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat', hone] at h1
  omega

/-- **The code's own steps for widths `W`** (each `1 ≤ W k ≤ 2^64`): an absorb is a step of one item; a squeeze with
counter `k` starts a step of `W k` squeezes with the counters `k, k + 1, …` (a `challenge_fp2_vec` of `W k`). The
items of a step are distinct although the counter wraps. -/
def stepsB (L : ℕ) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64) : Steps (ItB L) where
  wd it := tWd W it.1
  wd_pos it := by
    obtain ⟨t, _⟩ := it
    cases t with
    | absorb l x => exact Nat.one_pos
    | squeeze k => exact hW k
  cont := contB
  distinct it i j hi hj h := by
    obtain ⟨t, ht⟩ := it
    cases t with
    | absorb l x =>
      simp only [tWd] at hi hj
      omega
    | squeeze k =>
      simp only [tWd] at hi hj
      have hk := hW64 k
      cases i with
      | zero =>
        cases j with
        | zero => rfl
        | succ j =>
          exfalso
          simp only [stepItem, contB, Subtype.mk.injEq, TItem.squeeze.injEq] at h
          exact ctr_add_ne k j (by omega) h.symm
      | succ i =>
        cases j with
        | zero =>
          exfalso
          simp only [stepItem, contB, Subtype.mk.injEq, TItem.squeeze.injEq] at h
          exact ctr_add_ne k i (by omega) h
        | succ j =>
          simp only [stepItem, contB, Subtype.mk.injEq, TItem.squeeze.injEq] at h
          rw [ctr_add_inj k i j (by omega) (by omega) h]

/-- **The code's own steps read as code items** (`StepsOK`): the theorem `fs_code_chain_sound_sched` applies to them
with any widths `W`. -/
theorem stepsB_ok (L : ℕ) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64) :
    StepsOK W (fun it : ItB L => it.1) (stepsB L W hW hW64) := by
  intro it
  obtain ⟨t, ht⟩ := it
  cases t with
  | absorb l x => exact ⟨[], rfl, rfl⟩
  | squeeze k =>
    obtain ⟨m, hm⟩ : ∃ m, W k = m + 1 := ⟨W k - 1, by have := hW k; omega⟩
    refine ⟨(List.range m).map (fun j => k + 1 + UInt64.ofNat j), ?_, by simp [tWd, hm]⟩
    simp [Steps.items, stepsB, tWd, hm, List.range_succ_eq_map, stepItem, contB, Function.comp_def]

end CodeSteps

/-! ## Operations: counters, a run of slots -/

theorem opsCtr_append : ∀ (c : UInt64) (ops₁ ops₂ : List Op), opsCtr c (ops₁ ++ ops₂) = opsCtr (opsCtr c ops₁) ops₂
  | _, [], _ => rfl
  | c, .absorb _ _ :: ops₁, ops₂ => opsCtr_append c ops₁ ops₂
  | c, .squeeze :: ops₁, ops₂ => opsCtr_append (c + 1) ops₁ ops₂

/-- **The operations of a run of slots**: per slot, its interstitial operations, then its rounds' operations. -/
def slotsOps : List (List Op × List (List Fp2)) → List Op
  | [] => []
  | o :: os => o.1 ++ scOps o.2 ++ slotsOps os

theorem slotsOps_append : ∀ (l₁ l₂ : List (List Op × List (List Fp2))),
    slotsOps (l₁ ++ l₂) = slotsOps l₁ ++ slotsOps l₂
  | [], _ => rfl
  | o :: l₁, l₂ => by
    rw [List.cons_append, slotsOps, slotsOps, slotsOps_append l₁ l₂]
    simp only [List.append_assoc]

/-- The verifier's operations before slot `k`'s rounds: the earlier slots', then slot `k`'s interstitial ones. -/
def slotPre (o : List (List Op × List (List Fp2))) (k : ℕ) (ok : List Op × List (List Fp2)) : List Op :=
  slotsOps (o.take k) ++ ok.1

/-- The run's operations around slot `k`'s rounds. -/
theorem slotsOps_split (o : List (List Op × List (List Fp2))) (k : ℕ) (ok : List Op × List (List Fp2))
    (h : o[k]? = some ok) : slotsOps o = slotPre o k ok ++ scOps ok.2 ++ slotsOps (o.drop (k + 1)) := by
  obtain ⟨hk, hget⟩ := List.getElem?_eq_some_iff.mp h
  have hd : o.drop k = ok :: o.drop (k + 1) := by rw [List.drop_eq_getElem_cons hk, hget]
  conv_lhs => rw [← List.take_append_drop k o, hd]
  rw [slotsOps_append, slotsOps, slotPre]
  simp only [List.append_assoc]

theorem slotsOps_fit (L : ℕ) : ∀ (o : List (List Op × List (List Fp2))),
    (∀ ok ∈ o, (∀ op ∈ ok.1, op.len ≤ L) ∧ (∀ op ∈ scOps ok.2, op.len ≤ L)) → ∀ op ∈ slotsOps o, op.len ≤ L
  | [], _ => by simp [slotsOps]
  | ok :: o, h => by
    intro op hop
    simp only [slotsOps, List.mem_append] at hop
    rcases hop with (hop | hop) | hop
    · exact (h ok List.mem_cons_self).1 op hop
    · exact (h ok List.mem_cons_self).2 op hop
    · exact slotsOps_fit L o (fun ok' h' => h ok' (List.mem_cons_of_mem _ h')) op hop

/-! ## The reader on a sumcheck's rounds -/

theorem sqD_cons_absorb {D : Type} (l x : List UInt8) (d : D) (es : List (TItem × D)) :
    sqD ((TItem.absorb l x, d) :: es) = sqD es := rfl

theorem sqD_cons_sq {D : Type} (c : UInt64) (d : D) (es : List (TItem × D)) :
    sqD ((TItem.squeeze c, d) :: es) = d :: sqD es := rfl

/-- **The scheduled reader on the verifier's own rounds** (one labelled absorb and one squeeze per round, every
squeeze its own step): from a transcript `ptr` between rounds, the round items (from any counter `c`, with any
digests) read as exactly those rounds, each its absorbed bytes and its squeeze's digest. -/
theorem cRd_rounds (n : ℕ) (lab : List UInt8) {M' : Type} (enc : M' → List UInt8) {D : Type} (W : UInt64 → ℕ)
    (hW : ∀ k, W k = 1) :
    ∀ (ms : List M') (c : UInt64) (ptr : List (List UInt8 × List D)) (ext : List (TItem × D)),
      ext.map Prod.fst = opItems c (rdOps lab enc ms) → ptr.length + ms.length ≤ n →
      ext.foldl (cRdStep ⟨n, fun _ => 1, fun _ => true, fun _ => lab⟩ W) (some (ptr, none, []))
        = some (ptr ++ (ms.map enc).zip ((sqD ext).map (fun d => [d])), none, [])
  | [], c, ptr, ext, hext, _ => by
    have : ext = [] := by simpa [rdOps, opItems] using hext
    subst this
    simp [sqD]
  | m :: ms, c, ptr, ext, hext, hn => by
    have hops : rdOps lab enc (m :: ms) = Op.absorb lab (enc m) :: Op.squeeze :: rdOps lab enc ms := by
      simp [rdOps]
    rw [hops] at hext
    match ext, hext with
    | [], h => simp [opItems] at h
    | [_], h => simp [opItems] at h
    | (a1, d1) :: (a2, d2) :: ext', h =>
      simp only [opItems, List.map_cons, List.cons.injEq] at h
      obtain ⟨rfl, rfl, hext'⟩ := h
      have hlt : ptr.length < n := by
        rw [List.length_cons] at hn
        omega
      have ih := cRd_rounds n lab enc W hW ms (c + 1) (ptr ++ [(enc m, [d2])]) ext' hext'
        (by rw [List.length_append, List.length_singleton]; rw [List.length_cons] at hn; omega)
      have e1 : cRdStep (⟨n, fun _ => 1, fun _ => true, fun _ => lab⟩ : Rounds) W (some (ptr, none, []))
          (TItem.absorb lab (enc m), d1) = some (ptr, some (enc m), []) := by
        simp [cRdStep, not_le.mpr hlt]
      have e2 : cRdStep (⟨n, fun _ => 1, fun _ => true, fun _ => lab⟩ : Rounds) W
          (some (ptr, some (enc m), [])) (TItem.squeeze c, d2) = some (ptr ++ [(enc m, [d2])], none, []) := by
        simp [cRdStep, not_le.mpr hlt, hW]
      rw [List.foldl_cons, List.foldl_cons, e1, e2, ih, sqD_cons_absorb, sqD_cons_sq]
      simp

theorem sqD_rounds_length (lab : List UInt8) {M' : Type} (enc : M' → List UInt8) {D : Type} :
    ∀ (ms : List M') (c : UInt64) (ext : List (TItem × D)), ext.map Prod.fst = opItems c (rdOps lab enc ms) →
      (sqD ext).length = ms.length
  | [], c, ext, hext => by
    have : ext = [] := by simpa [rdOps, opItems] using hext
    subst this
    rfl
  | m :: ms, c, ext, hext => by
    have hops : rdOps lab enc (m :: ms) = Op.absorb lab (enc m) :: Op.squeeze :: rdOps lab enc ms := by
      simp [rdOps]
    rw [hops] at hext
    match ext, hext with
    | [], h => simp [opItems] at h
    | [_], h => simp [opItems] at h
    | (a1, d1) :: (a2, d2) :: ext', h =>
      simp only [opItems, List.map_cons, List.cons.injEq] at h
      obtain ⟨rfl, rfl, hext'⟩ := h
      rw [sqD_cons_absorb, sqD_cons_sq, List.length_cons, List.length_cons,
        sqD_rounds_length lab enc ms (c + 1) ext' hext']

/-! ## The executable instance: sumcheck slots in sequence on one transcript -/

section Slots

/-- The digest `0^32` (the reader's default digest; a slot's rounds always carry one). -/
def dig0 : Dig := ⟨List.replicate 32 0, List.length_replicate⟩

/-- **The steps of a schedule of single squeezes**: every item is a step of its own. -/
def stepsOne (It' : Type) : Steps It' where
  wd _ := 1
  wd_pos _ := one_pos
  cont it _ := it
  distinct _ _ _ hi hj _ := by omega

theorem stepsOne_items {It' : Type} (it : It') : (stepsOne It').items it = [it] := rfl

theorem flatMap_stepsOne {It' : Type} : ∀ l : List It', l.flatMap (stepsOne It').items = l
  | [] => rfl
  | a :: l => by rw [List.flatMap_cons, stepsOne_items, flatMap_stepsOne l]; rfl

/-- Every squeeze a step of its own. -/
def W1 : UInt64 → ℕ := fun _ => 1

theorem stepsOne_ok {It' : Type} (toT : It' → TItem) : StepsOK W1 toT (stepsOne It') := by
  intro it
  refine ⟨[], rfl, ?_⟩
  cases toT it <;> rfl

theorem foldl_tRemStep_W1 {D : Type} :
    ∀ τ : List (TItem × D), τ.foldl (fun o e => tRemStep W1 o e.1) (some 0) = some 0
  | [] => rfl
  | (it, _) :: τ => by
    have h : tRemStep W1 (some 0) it = some 0 := by cases it <;> rfl
    simp only [List.foldl_cons, h]
    exact foldl_tRemStep_W1 τ

/-- With single squeezes every chain is a sequence of whole steps. -/
theorem tRem_W1 {D : Type} (τ : List (TItem × D)) : tRem W1 τ = some 0 := foldl_tRemStep_W1 τ

/-- **A sumcheck slot of a schedule**: the number `s` of its interstitial operations (run before its rounds: the
challenge vectors it draws, the absorbs of its scalars), its round degree `d`, its number of rounds `n`, and its
statement (the polynomial, read in `K`, and the claimed sum) as a FUNCTION OF THE CODE'S TRACE BEFORE ITS ROUNDS:
everything from the transcript's start, the earlier slots and their challenges included. -/
structure Slot (K : Type) where
  s : ℕ
  d : ℕ
  n : ℕ
  stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2

/-- A slot's items: its interstitial operations, then two per round. -/
def Slot.len {K : Type} (sl : Slot K) : ℕ := sl.s + 2 * sl.n

/-- The items of a run of slots. -/
def slotsLen {K : Type} (slots : List (Slot K)) : ℕ := (slots.map Slot.len).sum

/-- `challenge_fp2`'s digests per value (`card_chal_fiber_le`). -/
abbrev fibC : ℕ := (2 ^ 128 / gP + 1) ^ 2

variable {K : Type} [Field K] [Algebra GF K]

/-- **A slot as a sub-protocol of the schedule**, its window at `a`: per sumcheck round one absorb under `sc-round`
and one squeeze; its state the sumcheck's (L7's `scSt`), the messages read by `decMsg`, the challenges by
`challenge_fp2`; error `d·(⌊2^128/p⌋+1)²/|Dig|`; never released (the caller's terminal check is in the state). -/
noncomputable def slotSub (U : K) (sl : Slot K) (a : ℕ) : CSub Dig where
  a := a
  R := ⟨sl.n, fun _ => 1, fun _ => true, fun _ => scLabel⟩
  ε := ((sl.d * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
  St hdr τ := scSt U sl.d sl.n sl.stmt hdr
    (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 (τ.map (fun e => (decMsg U sl.d e.1, e.2))))
  rel _ := False

theorem slotSub_a (U : K) (sl : Slot K) (a : ℕ) : (slotSub U sl a).a = a := rfl

theorem slotSub_R (U : K) (sl : Slot K) (a : ℕ) :
    (slotSub U sl a).R = ⟨sl.n, fun _ => 1, fun _ => true, fun _ => scLabel⟩ := rfl

theorem slotSub_St (U : K) (sl : Slot K) (a : ℕ) (hdr : List (TItem × Dig)) (τ : List (List UInt8 × List Dig)) :
    (slotSub U sl a).St hdr τ = scSt U sl.d sl.n sl.stmt hdr
      (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 (τ.map (fun e => (decMsg U sl.d e.1, e.2)))) := rfl

theorem liftC_some {D : Type} (P : List (List UInt8 × List D) → Prop) (ptr : List (List UInt8 × List D))
    (pm : Option (List UInt8)) (ds : List D) : liftC P (some (ptr, pm, ds)) = P ptr := rfl

/-- **The schedule of a run of slots**: slot `k`'s window starts after the earlier slots' items and its own
interstitial operations. -/
noncomputable def slotSubs (U : K) (slots : List (Slot K)) : List (CSub Dig) :=
  slots.mapIdx (fun k sl => slotSub U sl (slotsLen (slots.take k) + sl.s))

theorem slotSubs_getElem? (U : K) (slots : List (Slot K)) (k : ℕ) :
    (slotSubs U slots)[k]? = slots[k]?.map (fun sl => slotSub U sl (slotsLen (slots.take k) + sl.s)) := by
  simp [slotSubs, List.getElem?_mapIdx]

/-- **A slot is round-by-round sound on digests**, with error `d·(⌊2^128/p⌋+1)²/|Dig|` (`sumcheck_rbr`, carried to
digests by `rbrWide_of_rbrSound`, to the absorbed bytes by `RbrWide.comap`). -/
theorem slotSub_rbr [Fintype K] [DecidableEq K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (sl : Slot K) (hdp : sl.d < gP) (a : ℕ) :
    RbrWide (slotSub U sl a).R.n (slotSub U sl a).R.w (slotSub U sl a).St (slotSub U sl a).ε := by
  have hdK : sl.d < ringChar K := by rw [ringChar_eq_gP]; exact hdp
  exact (rbrWide_of_rbrSound (sumcheck_rbr hdK (fun x : List (TItem × Dig) => ((sl.stmt x).1, (sl.stmt x).2.toK U)))
    (fun dg => (challengeFp2Of dg).toK U) fibC (card_chal_fiber_le U hbij) dig0).comap id (decMsg U sl.d)

/-- The reader's rounds, their challenges read through `challenge_fp2`: the messages and challenges of L6's lists. -/
theorem chalTr_zip (U : K) (d : ℕ) (chal : Dig → K) :
    ∀ (bs : List (List UInt8)) (ds : List Dig),
      chalTr chal dig0 ((bs.zip (ds.map (fun dg => [dg]))).map (fun e => (decMsg U d e.1, e.2)))
        = (bs.map (decMsg U d)).zip (ds.map chal)
  | [], _ => rfl
  | _ :: _, [] => rfl
  | b :: bs, dg :: ds => by
    have ih := chalTr_zip U d chal bs ds
    simp only [chalTr] at ih ⊢
    simp only [List.map_cons, List.zip_cons_cons, List.headD_cons, ih]

/-- **A slot's header is its trace**: the run's chain's first `|P|` entries are the executable transcript's trace of
the operations `P` before the slot's rounds. -/
theorem slot_take (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (P rest : List Op) (G : QB L → Dig)
    (hfP : ∀ op ∈ P, op.len ≤ L) :
    (((chainEncB key domain hs L hL).chainFrom G [] (liftItems L (opItems 0 (P ++ rest)))).map entB).take P.length
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) P
      ∧ P.length ≤ (((chainEncB key domain hs L hL).chainFrom G [] (liftItems L (opItems 0 (P ++ rest)))).map
          entB).length := by
  have hfitP : ∀ it ∈ opItems 0 P, it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 P hfP
  have hbP : (liftItems L (opItems 0 P)).map Subtype.val = opItems 0 P := liftItems_val L _ hfitP
  have hlP : (liftItems L (opItems 0 P)).length = P.length := by
    have h := congrArg List.length hbP
    rw [List.length_map, opItems_length] at h
    exact h
  rw [opItems_append, liftItems_append L _ _ hfitP]
  generalize hbPg : liftItems L (opItems 0 P) = bP at hbP hlP ⊢
  generalize liftItems L (opItems (opsCtr 0 P) rest) = bQ
  obtain ⟨ext, hext, -⟩ := (chainEncB key domain hs L hL).chainFrom_eq_append G bQ
    ((chainEncB key domain hs L hL).chainFrom G [] bP)
  have hlC : ((chainEncB key domain hs L hL).chainFrom G [] bP).length = P.length := by
    rw [ChainEnc.chainFrom_length, List.length_nil, zero_add, hlP]
  rw [ChainEnc.chainFrom_append, hext, List.map_append]
  have hlCm : (((chainEncB key domain hs L hL).chainFrom G [] bP).map entB).length = P.length := by
    rw [List.length_map, hlC]
  refine ⟨?_, ?_⟩
  · rw [List.take_left' hlCm]
    have h2 := chainFrom_liftH key domain hs L hL G bP []
    rw [List.map_nil] at h2
    have h1 := opTrace_chainFrom (liftH G) key domain hs P (Tr.newKeyed (liftH G) domain key) [] (bP.map ItB.toIt)
      rfl rfl (by rw [List.map_map]; exact hbP)
    rw [h1, h2, List.length_nil, List.drop_zero, List.map_map]
    rfl
  · rw [List.length_append, hlCm]
    omega

/-- **An accepting slot is alive on the run's chain.** If the executable `sumcheck::verify` of the slot, run on the
code's transcript after the operations `P`, accepts with the caller's terminal check, the slot's state read off the
run's chain (`P`, its rounds' operations, then any `Q`) is alive: its rounds read back as the program's, and
`scAccept` holds on the chain's challenges. -/
theorem slot_alive (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (sl : Slot K) (hd : 1 ≤ sl.d) (hdp : sl.d < gP)
    (hLr : 56 + 16 * (sl.d + 1) ≤ L) (P Q : List Op) (rounds : List (List Fp2)) (G : QB L → Dig)
    (hfP : ∀ op ∈ P, op.len ≤ L) (hrc : ∀ r ∈ rounds, ∀ a ∈ r, a.Canon)
    (hcc : (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) P)).2.Canon)
    (hacc : ∃ fin rs, (scVerify (liftH G) (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) P)).2 sl.d
          sl.n rounds (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) P)).1 = .ok (fin, rs)
        ∧ fin.toK U = (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) P)).1
            (fun i => (rs.getD i Fp2.zero).toK U)) :
    rdAlive W1 (slotSub U sl P.length)
      (((chainEncB key domain hs L hL).chainFrom G [] (liftItems L (opItems 0 (P ++ scOps rounds ++ Q)))).map entB) := by
  obtain ⟨fin, rs, hok, hterm⟩ := hacc
  generalize hx : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) P = x at hcc hok hterm
  obtain ⟨hls, hrs, hsc⟩ := (scVerify_accept_iff U (liftH G) hU sl.d sl.n hd hdp (sl.stmt x).2 hcc rounds hrc
    (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) P) (sl.stmt x).1 rs).mp ⟨fin, hok, hterm⟩
  have hn : rounds.length = sl.n := by
    have h1 := scAccept_length _ _ _ _ hsc
    rw [scTau_length, hrs, scChal_length, min_self] at h1
    exact h1
  set c0 := (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) P).counter with hc0def
  have hc0 : opsCtr 0 P = c0 := (runOps_counter (liftH G) P (Tr.newKeyed (liftH G) domain key)).symm
  have hfitP : ∀ it ∈ opItems 0 P, it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 P hfP
  have hfitR : ∀ it ∈ opItems c0 (scOps rounds), it.Ok ∧ it.len ≤ L :=
    opItems_fit L hL64 c0 (scOps rounds) (scOps_len L sl.d hLr rounds hls)
  have hfitPR : ∀ it ∈ opItems 0 P ++ opItems c0 (scOps rounds), it.Ok ∧ it.len ≤ L := by
    intro it hit
    rcases List.mem_append.mp hit with h | h
    · exact hfitP it h
    · exact hfitR it h
  have hits : liftItems L (opItems 0 (P ++ scOps rounds ++ Q))
      = liftItems L (opItems 0 P) ++ liftItems L (opItems c0 (scOps rounds))
        ++ liftItems L (opItems (opsCtr c0 (scOps rounds)) Q) := by
    rw [opItems_append 0 (P ++ scOps rounds) Q, opItems_append 0 P (scOps rounds), opsCtr_append, hc0,
      liftItems_append L _ _ hfitPR, liftItems_append L _ _ hfitP]
  have hbP : (liftItems L (opItems 0 P)).map Subtype.val = opItems 0 P := liftItems_val L _ hfitP
  have hbR : (liftItems L (opItems c0 (scOps rounds))).map Subtype.val = opItems c0 (scOps rounds) :=
    liftItems_val L _ hfitR
  have hlP : (liftItems L (opItems 0 P)).length = P.length := by
    have h := congrArg List.length hbP
    rw [List.length_map, opItems_length] at h
    exact h
  rw [hits]
  generalize hbPg : liftItems L (opItems 0 P) = bP at hbP hlP ⊢
  generalize hbRg : liftItems L (opItems c0 (scOps rounds)) = bR at hbR ⊢
  generalize liftItems L (opItems (opsCtr c0 (scOps rounds)) Q) = bQ
  set CB := chainEncB key domain hs L hL with hCB
  obtain ⟨extR, hextR, hextRm⟩ := CB.chainFrom_eq_append G bR (CB.chainFrom G [] bP)
  obtain ⟨extQ, hextQ, -⟩ := CB.chainFrom_eq_append G bQ (CB.chainFrom G [] bP ++ extR)
  have hfull : CB.chainFrom G [] (bP ++ bR ++ bQ) = CB.chainFrom G [] bP ++ extR ++ extQ := by
    rw [CB.chainFrom_append, CB.chainFrom_append, hextR, hextQ]
  have hlC : (CB.chainFrom G [] bP).length = P.length := by
    rw [CB.chainFrom_length, List.length_nil, zero_add, hlP]
  have hlCm : ((CB.chainFrom G [] bP).map entB).length = P.length := by rw [List.length_map, hlC]
  have h2 := chainFrom_liftH key domain hs L hL G bP []
  rw [List.map_nil] at h2
  have hτ0 : x = (CB.chainFrom G [] bP).map entB := by
    have h1 := opTrace_chainFrom (liftH G) key domain hs P (Tr.newKeyed (liftH G) domain key) [] (bP.map ItB.toIt)
      rfl rfl (by rw [List.map_map]; exact hbP)
    rw [← hx, h1, h2, List.length_nil, List.drop_zero, List.map_map]
    rfl
  -- the program's challenges are the reader's digests
  have hfs := (scVerify_fs (liftH G) U hU key domain hs P (bP.map ItB.toIt) (by rw [List.map_map]; exact hbP) sl.d
    sl.n hd hdp (sl.stmt x).2 hcc rounds hrc (bR.map ItB.toIt) (by rw [List.map_map]; exact hbR) (sl.stmt x).1 rs).mp
    ⟨fin, hok, hterm⟩
  obtain ⟨-, hrs2, -⟩ := hfs
  have hsq : rs = (sqD (extR.map entB)).map challengeFp2Of := by
    rw [hrs2, h2, chainFrom_liftH key domain hs L hL G bR (CB.chainFrom G [] bP), hextR, List.map_append,
      List.length_map, List.drop_left' (by rw [List.length_map, hlC, hlP]), sqDigests_eq, List.map_map]
    rfl
  have hextT : (extR.map entB).map Prod.fst
      = opItems c0 (rdOps scLabel (fun r : List Fp2 => r.flatMap Fp2.toBytes) rounds) := by
    have h : (extR.map entB).map Prod.fst = (extR.map Prod.fst).map Subtype.val := by
      rw [List.map_map, List.map_map]
      rfl
    rw [h, hextRm, hbR]
    rfl
  have hsqlen : (sqD (extR.map entB)).length = rounds.length :=
    sqD_rounds_length scLabel (fun r : List Fp2 => r.flatMap Fp2.toBytes) rounds c0 _ hextT
  have hz : ((rounds.map (fun r : List Fp2 => r.flatMap Fp2.toBytes)).map (decMsg U sl.d)).zip
      ((sqD (extR.map entB)).map (fun dg => (challengeFp2Of dg).toK U)) = scTau U sl.d rounds rs := by
    rw [List.map_map, hsq]
    exact zip_dec_scTau U sl.d rounds (sqD (extR.map entB)) (fun r hr => ⟨hrc r hr, hls r hr⟩)
  -- the reading
  rw [hfull]
  unfold rdAlive
  refine ⟨tRem_W1 _, ?_⟩
  rw [List.map_append, List.map_append, List.append_assoc, slotSub_a, List.take_left' hlCm, List.drop_left' hlCm,
    ← hτ0, cRd, List.foldl_append, slotSub_R,
    cRd_rounds sl.n scLabel (fun r : List Fp2 => r.flatMap Fp2.toBytes) W1 (fun _ => rfl) rounds c0 [] (extR.map entB)
      hextT
      (by rw [List.length_nil, zero_add, hn])]
  have hfz : (⟨sl.n, fun _ => 1, fun _ => true, fun _ => scLabel⟩ : Rounds).n
      ≤ (([] : List (List UInt8 × List Dig)) ++ (rounds.map (fun r : List Fp2 => r.flatMap Fp2.toBytes)).zip
        ((sqD (extR.map entB)).map (fun dg => [dg]))).length := by
    rw [List.nil_append, List.length_zip, List.length_map, List.length_map, hsqlen, min_self, hn]
  rw [foldl_cRdStep_frozen _ W1 hfz, liftC_some, slotSub_St, List.nil_append, chalTr_zip, hz]
  unfold scSt
  right
  exact scAccept_state _ _ _ _ hsc

theorem runOps_append (H : HIn → Dig) : ∀ (t : Tr) (a b : List Op), runOps H t (a ++ b) = runOps H (runOps H t a) b
  | _, [], _ => rfl
  | t, .absorb l x :: a, b => runOps_append H (t.absorb H l x) a b
  | t, .squeeze :: a, b => runOps_append H (t.squeeze H).2 a b

/-- **One executable transcript.** Slot `k + 1`'s transcript (`runOps` of the operations before its rounds) is the
transcript that slot `k`'s accepting `sumcheck::verify` LEAVES (L6's `scVerify_tr`), after slot `k + 1`'s
interstitial operations: the run's slots share the program's one transcript. -/
theorem slot_transcript_next (H : HIn → Dig) (t : Tr) (o : List (List Op × List (List Fp2))) (k : ℕ)
    (ok ok' : List Op × List (List Fp2)) (h : o[k]? = some ok) (claimed : Fp2) (d n : ℕ) (hd : 1 ≤ d) (fin : Fp2)
    (rs : List Fp2) (hacc : (scVerify H claimed d n ok.2 (runOps H t (slotPre o k ok))).1 = .ok (fin, rs)) :
    runOps H t (slotPre o (k + 1) ok')
      = runOps H (scVerify H claimed d n ok.2 (runOps H t (slotPre o k ok))).2 ok'.1 := by
  rw [scVerify_tr H d n hd claimed ok.2 _ fin rs hacc]
  simp only [slotPre, List.take_add_one, h, Option.toList_some, slotsOps_append, slotsOps, List.append_nil,
    runOps_append]

theorem slotsOps_length {K' : Type} : ∀ (o : List (List Op × List (List Fp2))) (slots : List (Slot K')),
    o.length = slots.length →
    (∀ (k : ℕ) (sl : Slot K') (ok : List Op × List (List Fp2)), slots[k]? = some sl → o[k]? = some ok →
      ok.1.length = sl.s ∧ ok.2.length = sl.n) → (slotsOps o).length = slotsLen slots
  | [], [], _, _ => rfl
  | [], _ :: _, hl, _ => by simp at hl
  | _ :: _, [], hl, _ => by simp at hl
  | ok :: o, sl :: slots, hl, h => by
    obtain ⟨h1, h2⟩ := h 0 sl ok rfl rfl
    have ih := slotsOps_length o slots (by simpa using hl)
      (fun k sl' ok' e1 e2 => h (k + 1) sl' ok' (by simpa using e1) (by simpa using e2))
    simp only [slotsOps, List.length_append, scOps_length, ih, slotsLen, List.map_cons, List.sum_cons, Slot.len, h1,
      h2]

/-- **The prover wins against the executable verifier of a run of slots.** The prover outputs, per slot, its
interstitial operations (`s` of them, each hash input of at most `L` bytes) and its rounds (canonical words). For every
slot `k`, with `P` the verifier's operations before its rounds (`slotPre`: the earlier slots', then its own
interstitial ones) and `(f, C)` its statement of `P`'s trace: `C` is canonical, and the executable
`sumcheck::verify`, run on the code's transcript after `P`, returns `Ok (fin, rs)` with the caller's terminal check
`fin = f(rs)`. And for SOME slot the claim is FALSE: `f` of individual degree `≤ d` and `C ≠ Σ f`. -/
def SlotsWin (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (slots : List (Slot K)) (G : QB L → Dig)
    (o : List (List Op × List (List Fp2))) : Prop :=
  o.length = slots.length
  ∧ (∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl → o[k]? = some ok →
      ok.1.length = sl.s ∧ (∀ op ∈ ok.1, op.len ≤ L) ∧ (∀ r ∈ ok.2, ∀ a ∈ r, a.Canon)
      ∧ (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).2.Canon
      ∧ ∃ fin rs, (scVerify (liftH G) (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (slotPre o k ok))).2 sl.d sl.n ok.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
              (slotPre o k ok))).1 = .ok (fin, rs)
        ∧ fin.toK U = (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1
            (fun i => (rs.getD i Fp2.zero).toK U))
  ∧ ∃ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl ∧ o[k]? = some ok
      ∧ IndDegLE sl.d (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1
      ∧ (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).2.toK U
          ≠ cubeSum (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1

/-- **A win is the composed event on the run's chain**: the false slot enters its window doomed (its header is its
trace, `slot_take`), and every slot is alive at the end (`slot_alive`), on the chain of the verifier's items. -/
theorem slotsWin_event (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (Slot K))
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (G : QB L → Dig) (o : List (List Op × List (List Fp2))) (τ : List (TItem × Dig))
    (hτ : τ = cChain (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) G
      ((liftItems L (opItems 0 (slotsOps o))).take (slotsLen slots)))
    (hwin : SlotsWin U key domain L slots G o) :
    (∃ (k : ℕ) (c : CSub Dig), (slotSubs U slots)[k]? = some c ∧ c.a ≤ τ.length ∧ tRem W1 (τ.take c.a) = some 0
        ∧ ¬ c.St (τ.take c.a) [] ∧ ¬ c.rel (τ.take c.a))
      ∧ allSt W1 (slotSubs U slots) τ := by
  subst hτ
  obtain ⟨hlen, hall, kf, slf, okf, hslf, hokf, hdegf, hfalse⟩ := hwin
  have hget : ∀ (k : ℕ) (ok : List Op × List (List Fp2)), o[k]? = some ok → ∃ sl, slots[k]? = some sl := by
    intro k ok h
    have hk := (List.getElem?_eq_some_iff.mp h).1
    exact ⟨_, List.getElem?_eq_getElem (l := slots) (i := k) (by omega)⟩
  have hgetO : ∀ (k : ℕ) (sl : Slot K), slots[k]? = some sl → ∃ ok, o[k]? = some ok := by
    intro k sl h
    have hk := (List.getElem?_eq_some_iff.mp h).1
    exact ⟨_, List.getElem?_eq_getElem (l := o) (i := k) (by omega)⟩
  have hfacts : ∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl → o[k]? = some ok →
      (∀ r ∈ ok.2, r.length = sl.d + 1) ∧ ok.2.length = sl.n := by
    intro k sl ok h1 h2
    obtain ⟨-, -, hrc, hcc, fin, rs, hok, hterm⟩ := hall k sl ok h1 h2
    have hsl1 := hsl sl (List.mem_of_getElem? h1)
    obtain ⟨hls, hrs, hsc⟩ := (scVerify_accept_iff U (liftH G) hU sl.d sl.n hsl1.1 hsl1.2.1
      (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).2 hcc ok.2 hrc
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))
      (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1 rs).mp ⟨fin, hok, hterm⟩
    refine ⟨hls, ?_⟩
    have h3 := scAccept_length _ _ _ _ hsc
    rw [scTau_length, hrs, scChal_length, min_self] at h3
    exact h3
  have hfitAll : ∀ op ∈ slotsOps o, op.len ≤ L := by
    refine slotsOps_fit L o (fun ok hok => ?_)
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hok
    obtain ⟨sl, hsl'⟩ := hget k ok hk
    exact ⟨(hall k sl ok hsl' hk).2.1,
      scOps_len L sl.d (hsl sl (List.mem_of_getElem? hsl')).2.2 ok.2 (hfacts k sl ok hsl' hk).1⟩
  have hlenAll : (slotsOps o).length = slotsLen slots :=
    slotsOps_length o slots hlen (fun k sl ok h1 h2 => ⟨(hall k sl ok h1 h2).1, (hfacts k sl ok h1 h2).2⟩)
  have hliftlen : (liftItems L (opItems 0 (slotsOps o))).length = slotsLen slots := by
    have h := congrArg List.length (liftItems_val L _ (opItems_fit L hL64 0 _ hfitAll))
    rw [List.length_map, opItems_length, hlenAll] at h
    exact h
  have hpre_len : ∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl →
      o[k]? = some ok → (slotPre o k ok).length = slotsLen (slots.take k) + sl.s := by
    intro k sl ok h1 h2
    rw [slotPre, List.length_append, (hall k sl ok h1 h2).1]
    congr 1
    refine slotsOps_length (o.take k) (slots.take k) (by simp [hlen]) (fun i sl' ok' e1 e2 => ?_)
    rw [List.getElem?_take] at e1 e2
    split_ifs at e1 e2 with hi
    · exact ⟨(hall i sl' ok' e1 e2).1, (hfacts i sl' ok' e1 e2).2⟩
  have hfitSplit : ∀ (k : ℕ) (ok : List Op × List (List Fp2)), o[k]? = some ok → ∀ op ∈ slotPre o k ok, op.len ≤ L := by
    intro k ok h op hop
    exact hfitAll op (by rw [slotsOps_split o k ok h]; exact List.mem_append_left _ (List.mem_append_left _ hop))
  have hTE : (toTE (fun it : ItB L => it.1) : ItB L × Dig → TItem × Dig) = entB := rfl
  unfold cChain
  rw [List.take_of_length_le hliftlen.le, flatMap_stepsOne, hTE]
  refine ⟨⟨kf, slotSub U slf (slotsLen (slots.take kf) + slf.s), by rw [slotSubs_getElem?, hslf]; rfl, ?_⟩, ?_⟩
  · rw [slotSub_a, ← hpre_len kf slf okf hslf hokf, slotsOps_split o kf okf hokf, List.append_assoc]
    have hst := slot_take key domain hs L hL hL64 (slotPre o kf okf) (scOps okf.2 ++ slotsOps (o.drop (kf + 1))) G
      (hfitSplit kf okf hokf)
    refine ⟨hst.2, tRem_W1 _, ?_, fun h => h⟩
    rw [hst.1, slotSub_St, List.map_nil]
    show ¬ scSt U slf.d slf.n slf.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o kf okf)) []
    unfold scSt
    rintro (h | h)
    · exact h hdegf
    · exact hfalse h
  · intro k c hc
    rw [slotSubs_getElem?] at hc
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hc
    obtain ⟨ok, hok⟩ := hgetO k sl hsl'
    have hsl1 := hsl sl (List.mem_of_getElem? hsl')
    obtain ⟨-, -, hrc, hcc, hacc⟩ := hall k sl ok hsl' hok
    right
    left
    rw [← hpre_len k sl ok hsl' hok, slotsOps_split o k ok hok]
    exact slot_alive U hU key domain hs L hL hL64 sl hsl1.1 hsl1.2.1 hsl1.2.2 (slotPre o k ok)
      (slotsOps (o.drop (k + 1))) ok.2 G (hfitSplit k ok hok) hrc hcc hacc

/-- **Fiat–Shamir soundness of a RUN of executable sumcheck slots on ONE transcript** (D63 step L8). In the
random-oracle model on the hash inputs of at most `L` bytes (`QB L`), a prover making at most `q` queries outputs, for
each slot of the schedule `slots`, its interstitial operations and its rounds. Each slot's statement (a polynomial `f`
of individual degree `≤ d` and a claimed sum `C`) is a function of the code's trace before its rounds. The probability
that SOME slot's claim is false (`C ≠ Σ f`) and yet EVERY slot's executable `sumcheck::verify`, on the code's
transcript after the operations before it, accepts with its terminal check, is at most
`T·dmax/|K| · (1 + p/2^128)² + collBound T + collBound (T + 1)` over `|Dig| = 2^256`, `T = q + ℓ + 1`, `ℓ` the run's
items (`slotsLen`): the LARGEST degree, not the sum over the slots. -/
theorem exec_sumchecks_fs_sound [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (q : ℕ) (A : OC (QB L) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => SlotsWin U key domain L slots G (A.run G))
      ≤ (((q + slotsLen slots + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + slotsLen slots + 1) Dig + collBound (q + slotsLen slots + 1 + 1) Dig := by
  have : Nonempty K := ⟨0⟩
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  let A' : OC (QB L) Dig (List (ItB L)) := A.bind (fun o => .ret (liftItems L (opItems 0 (slotsOps o))))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (liftItems L (opItems 0 (slotsOps o))) : OC (QB L) Dig (List (ItB L))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = liftItems L (opItems 0 (slotsOps (A.run G))) := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hR : ∀ c ∈ slotSubs U slots, RbrWide c.R.n c.R.w c.St c.ε := by
    intro c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    rw [slotSubs_getElem?] at hk
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hk
    exact slotSub_rbr U hbij sl (hsl sl (List.mem_of_getElem? hsl')).2.1 _
  have hε : ∀ c ∈ slotSubs U slots, c.ε ≤ ((dmax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    intro c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    rw [slotSubs_getElem?] at hk
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hk
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ (hsl sl (List.mem_of_getElem? hsl')).2.2.1)) _
  have hframe : ∀ (k : ℕ) (c : CSub Dig) (τ : List (TItem × Dig)) (h : TItem) (ks : List UInt64) (ds : List Dig),
      (slotSubs U slots)[k]? = some c → tRem W1 τ = some 0 → ks.length + 1 = tWd W1 h →
      ds.length = ks.length + 1 → ¬ subSt W1 c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (slotSubs U slots)[k']? = some c' ∧ ¬ subSt W1 c' τ := by
    intro k c τ h ks ds hc _ _ _ _ hrel
    rw [slotSubs_getElem?] at hc
    obtain ⟨sl, -, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact absurd hrel id
  have hmain := fs_code_chain_sound_sched W1 (fun _ => Nat.one_pos) (slotSubs U slots) _ hR hε hframe
    (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) (stepsOne_ok _)
    (fun l => l.take (slotsLen slots)) (slotsLen slots)
    (fun l => by
      show ((l.take (slotsLen slots)).flatMap (stepsOne (ItB L)).items).length ≤ slotsLen slots
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) q A' hA'
  refine le_trans (MeasureTheory.measure_mono ?_) (hmain.trans ?_)
  · intro G hwin
    rw [Set.mem_ofPred_eq] at hwin ⊢
    rw [hrun G]
    exact slotsWin_event U hU key domain hs L hL hL64 slots
      (fun sl h => ⟨(hsl sl h).1, (hsl sl h).2.1, (hsl sl h).2.2.2⟩) G (A.run G) _ rfl hwin
  · refine add_le_add (add_le_add ?_ le_rfl) le_rfl
    rw [← mul_div_assoc, ← Nat.cast_mul, ← mul_assoc]
    exact dig_bound_le gP hF _

/-- **At Goldilocks** (`|K| = p²`): the bound of `exec_sumchecks_fs_sound` with the bias `(1 + 2^-64)²`. -/
theorem exec_sumchecks_fs_sound_goldilocks [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (q : ℕ) (A : OC (QB L) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => SlotsWin U key domain L slots G (A.run G))
      ≤ (((q + slotsLen slots + 1) * dmax : ℕ) : ℝ≥0∞) / ((gP ^ 2 : ℕ) : ℝ≥0∞) * (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2
        + collBound (q + slotsLen slots + 1) Dig + collBound (q + slotsLen slots + 1 + 1) Dig := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (exec_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 slots dmax hsl q A hA).trans ?_
  rw [hF]
  exact add_le_add (add_le_add (mul_le_mul' le_rfl (bias_le_two_pow_64 gP (by norm_num))) le_rfl) le_rfl

/-- **At the shape of a run of slots** (for orientation only): with Goldilocks' `|K| = p²`, every round degree at most
`dmax ≤ 4` and `T = q + ℓ + 1 ≤ 2^64 + 2^20` (e.g. `q = 2^64` queries and a run of up to `2^20 − 1` items: 32 slots of
30 rounds and up to 32,000 interstitial operations each), a false claim in ANY slot passes every slot's executable
verifier with probability at most `2^-61`: the bound of ONE slot (L7's `exec_sumcheck_fs_sound_slot`), not 32 times it.
-/
theorem exec_sumchecks_fs_sound_slot [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (q : ℕ) (A : OC (QB L) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q)
    (hd4 : dmax ≤ 4) (hT : q + slotsLen slots + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB L → Dig => SlotsWin U key domain L slots G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (exec_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 slots dmax hsl q A hA).trans ?_
  rw [hF]
  exact slot_bound_le gP (q + slotsLen slots + 1) dmax (by norm_num) (by norm_num) hT hd4

end Slots

end ZK60.Exec
