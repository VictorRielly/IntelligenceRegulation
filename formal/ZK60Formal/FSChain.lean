/-
D63, step L3 (soundness): Fiat–Shamir with the code's transcript, a hash CHAIN.

`FSRbr.lean` hashes the whole transcript prefix for each challenge. `zkp_core::transcript` does not: it keeps a 32-byte
state, and every operation hashes the state with one new item:
* `Transcript::new(domain)`: the state is `H(start)`, `start = "hashline-v1/" ‖ domain` (under a tagged profile, in
  BLAKE3's keyed mode under the profile's Fiat–Shamir key);
* `absorb(label, data)`: the state becomes `H(state ‖ le64|label| ‖ label ‖ le64|data| ‖ data)`;
* `squeeze_bytes`: the state becomes `H(state ‖ "squeeze" ‖ le64 counter)`, and that digest is the challenge's raw
  bytes.
So a run of the verifier is a CHAIN: items `it_0, it_1, …` (absorbs and squeezes), digests `D_0 = H(start)` and
`D_{j+1} = H(link(D_j, it_j))`. This file models exactly that (`ChainEnc`, `chainFrom`), for any items and any
injective `link` with a left inverse, and proves that a chain is as good as a prefix hash, up to collisions and
out-of-order guesses.

The idea (the trace-back). A query `link(d, it)` names the digest `d`. Reading the log BEFORE that query is first
asked, the trace-back (`traceBack`) finds the logged question whose answer is `d`, decodes it as `link(d', it')`, and
repeats until it reaches `start`: it recovers the whole chain behind `d` from the log alone, like `SoundExtract.lean`'s
extractor. It recovers the TRUE chain unless
* two different logged questions have the same answer (a collision: `collBound`), or
* some query, the first time it is asked, has an answer that an earlier query (or the query itself) already names: the
  prover used a digest before it existed, a guess (`FreshHitQ` on `chainTargets`, at most `t + 1` digests at position
  `t`).
Outside those two events, the chain step that takes a doomed transcript out of doom is a fresh hit on a set named by the
query and the log before it (`FreshHitQ` on `chainBad`), as in `FSRbr.lean`.

What is proved.
* `freshHitQ_prob_le_gen`: `FSRbr.lean`'s fresh-hit lemma with a position-dependent set size `m t`.
* `traceBack_chain`: on a log where every query of a chain is logged and none collides, the trace-back returns the
  chain.
* `chain_ordered`: unless a guess occurs, every query of a chain is logged before the first occurrence of the next one.
* `chain_sound`: let at most `k` digests take a doomed chain (of at least `s` items) out of doom, whatever the next
  item. For a prover making at most `q` hash queries and outputting items (the verifier hashes the first `ℓ` of
  them), the probability that the chain of the first `s` items is doomed but the whole chain is not is at most
  `T·k/|D| + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`.
The two added terms together are about `T²/|D|`; for `|D| = 2^256` they stay below `2^-100` while `T ≤ 2^78`.

How it applies to the code (`FSChainRbr.lean` formalizes the round-by-round case: one statement item, then a message
and a squeeze per round; the rest is stated so it can be checked). The first `s` items are the header
absorbs (expected-IO, public statement, parameters, calibration, schedule), so a false statement makes the chain of the
first `s` items doomed. A protocol state function `St` lifts to chains: read the transcript's messages off the absorb
items and the challenges off the squeeze items' digests (`chal` of the digest), and let an absorb item never change the
state (from a doomed chain it has no escaping digest). A squeeze item then has the protocol round's escaping digests,
at most `e·K` (`FSRbr.lean`, `FSChallenge.lean`). What this file assumes of the code:
* `link` is injective with a left inverse: an absorb input is length-prefixed (label and data), a squeeze input has
  exactly 47 bytes and an absorb input at least 48, so the two kinds never meet;
* `start` decodes as no link (`ldec_start`): `"hashline-v1/" ‖ domain` is an ASCII string, and as a link it would have
  to carry a little-endian length field in bytes 32–39, which ASCII text cannot be (it is at least `2^56`), or be one
  of the 47-byte squeezes, whose bytes 32–38 are `"squeeze"`; a domain string must therefore not be one whose bytes
  20–26 are `"squeeze"` with total length 35;
* a challenge read from SEVERAL squeezes (`challenge_fp2_vec`, more than four `challenge_indices`) is several squeeze
  items here; the joint escape of such a vector is not bounded item by item, so for those rounds this file's `k` is not
  the round's interactive error. That case is still open (see the findings document).
-/
import ZK60Formal.FSRbr
import ZK60Formal.SoundExtract

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## The fresh-hit lemma with a position-dependent size -/

section FreshGen

variable {Q D : Type}

/-- A logged question whose answer lies, at its first occurrence, in the set `F` names from it and the log before it,
gives a fresh hit. -/
theorem freshHitQ_of_first (H : Q → D) {L : List (Q × D)} (hL : ∀ e ∈ L, e.2 = H e.1)
    (F : List (Q × D) → Q → Finset D) {v : Q} (hv : v ∈ L.map Prod.fst)
    (hF : ∀ t e, L[t]? = some e → e.1 = v → v ∉ (L.take t).map Prod.fst → H v ∈ F (L.take t) v) :
    FreshHitQ F L := by
  obtain ⟨t, e, h1, h2, h3⟩ := exists_first hv
  refine ⟨t, e, h1, by rw [h2]; exact h3, ?_⟩
  rw [hL e (List.mem_of_getElem? h1), h2]
  exact hF t e h1 h2 h3

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The fresh-hit lemma, with the bad set named by the query and of size `m t` at position `t`.** -/
theorem freshHitQ_prob_le_gen {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T)
    (F : List (Q × D) → Q → Finset D) (m : ℕ → ℕ) (hF : ∀ P y, (F P y).card ≤ m P.length) :
    prH (fun H => FreshHitQ F (A.runLog H).2) ≤ ((∑ t ∈ range T, m t : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  set μ := (PMF.uniformOfFintype (Q → D)).toOuterMeasure
  let G : ℕ → Q → (Q → D) → Prop := fun t y H =>
    ∃ e, (A.runLog H).2[t]? = some e ∧ e.1 = y ∧ y ∉ ((A.runLog H).2.take t).map Prod.fst
  let Tt : ℕ → Q → (Q → D) → Finset D := fun t y H => F ((A.runLog H).2.take t) y
  have hsub : {H : Q → D | FreshHitQ F (A.runLog H).2}
      ⊆ ⋃ t ∈ range T, {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} := by
    intro H hH
    obtain ⟨t, e, h1, h2, h3⟩ := hH
    have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
    simp only [Set.mem_iUnion, Set.mem_ofPred_eq, mem_range]
    refine ⟨t, lt_of_lt_of_le ht (OC.runLog_length_le H A T hA), e.1, ⟨e, h1, rfl, h2⟩, ?_⟩
    rw [← OC.runLog_answer H A e (List.mem_of_getElem? h1)]
    exact h3
  have hpos : ∀ t, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} ≤ (m t : ℝ≥0∞) / Fintype.card D := by
    intro t
    refine prob_fresh_mem_le (G t) (Tt t) (m t) ?_ ?_ ?_
    · rintro y y' H ⟨e, h1, rfl, -⟩ ⟨e', h1', rfl, -⟩
      rw [h1] at h1'
      cases h1'
      rfl
    · rintro y H d ⟨e, h1, rfl, h3⟩
      have hag := OC.runLog_take_agree H (Function.update H e.1 d) A t (fun e' he' => by
        refine Function.update_of_ne ?_ d H
        intro hc
        exact h3 (hc ▸ List.mem_map_of_mem he'))
      refine ⟨?_, by simp only [Tt, hag.1]⟩
      have hq : ((A.runLog (Function.update H e.1 d)).2[t]?).map Prod.fst = some e.1 := by
        rw [hag.2, h1]
        rfl
      obtain ⟨e', he', he'1⟩ := Option.map_eq_some_iff.mp hq
      exact ⟨e', he', he'1, by rw [hag.1]; exact h3⟩
    · rintro y H ⟨e, h1, rfl, -⟩
      have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
      have := hF ((A.runLog H).2.take t) e.1
      rwa [List.length_take, min_eq_left ht.le] at this
  calc prH (fun H => FreshHitQ F (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | ∃ y, G t y H ∧ H y ∈ Tt t y H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} :=
        MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ t ∈ range T, (m t : ℝ≥0∞) / Fintype.card D := sum_le_sum (fun t _ => hpos t)
    _ = ((∑ t ∈ range T, m t : ℕ) : ℝ≥0∞) / Fintype.card D := by
        rw [Nat.cast_sum]
        simp only [div_eq_mul_inv, sum_mul]

end FreshGen

/-! ## Positions in a log -/

section Pos

variable {Q D : Type}

/-- An entry at a position below `s` is in the first `s` entries. -/
theorem mem_take_of_getElem? {L : List (Q × D)} {t s : ℕ} {e : Q × D} (h : L[t]? = some e) (hts : t < s) :
    e.1 ∈ (L.take s).map Prod.fst := by
  have : (L.take s)[t]? = some e := by
    rw [List.getElem?_take]
    simp [hts, h]
  exact List.mem_map_of_mem (List.mem_of_getElem? this)

/-- A question missing from the first `s` entries is asked at a position `≥ s`. -/
theorem le_of_not_mem_take {L : List (Q × D)} {s t : ℕ} {e : Q × D} {v : Q}
    (hv : v ∉ (L.take s).map Prod.fst) (h : L[t]? = some e) (he : e.1 = v) : s ≤ t := by
  by_contra hlt
  push Not at hlt
  exact hv (he ▸ mem_take_of_getElem? h hlt)

/-- The first `s` entries are among the first `s'` when `s ≤ s'`. -/
theorem mem_take_mono {L : List (Q × D)} {s s' : ℕ} {v : Q} (hv : v ∈ (L.take s).map Prod.fst) (hs : s ≤ s') :
    v ∈ (L.take s').map Prod.fst := by
  obtain ⟨e, he, rfl⟩ := List.mem_map.mp hv
  exact List.mem_map_of_mem ((List.take_prefix_take_left hs).subset he)

/-- A question among the first `t` entries is in the log. -/
theorem mem_of_mem_take_map {L : List (Q × D)} {t : ℕ} {v : Q} (hv : v ∈ (L.take t).map Prod.fst) :
    v ∈ L.map Prod.fst := by
  rw [List.map_take] at hv
  exact List.mem_of_mem_take hv

/-- The first occurrence of a question in the first `s` entries is below `s`. -/
theorem first_lt_of_mem_take {L : List (Q × D)} {s t : ℕ} {v : Q}
    (hv : v ∈ (L.take s).map Prod.fst) (hfirst : v ∉ (L.take t).map Prod.fst) : t < s := by
  by_contra hle
  push Not at hle
  exact hfirst (mem_take_mono hv hle)

end Pos

/-! ## The chain -/

/-- **The code's transcript as a chain**: the start query (`"hashline-v1/" ‖ domain`), and the link of a state digest
with one item (an absorb or a squeeze), injective with a left inverse; the start query decodes as no link. -/
structure ChainEnc (It Q D : Type) where
  start : Q
  link : D → It → Q
  ldec : Q → Option (D × It)
  ldec_link : ∀ d it, ldec (link d it) = some (d, it)
  ldec_start : ldec start = none

namespace ChainEnc

variable {It Q D : Type} (C : ChainEnc It Q D)

/-- The link query is never the start query. -/
theorem link_ne_start (d : D) (it : It) : C.link d it ≠ C.start := by
  intro h
  have := C.ldec_link d it
  rw [h, C.ldec_start] at this
  cases this

/-- The digest a chain transcript ends at: its last entry's, or `H(start)` for the empty chain. -/
def lastD (H : Q → D) (τ : List (It × D)) : D := (τ.getLast?.map Prod.snd).getD (H C.start)

theorem lastD_nil (H : Q → D) : C.lastD H [] = H C.start := rfl

theorem lastD_snoc (H : Q → D) (τ : List (It × D)) (e : It × D) : C.lastD H (τ ++ [e]) = e.2 := by
  simp [lastD]

/-- **The chain transcript**: starting from `τ`, each item `it` gets the digest `H(link(lastD τ, it))`. -/
def chainFrom (H : Q → D) : List (It × D) → List It → List (It × D)
  | τ, [] => τ
  | τ, it :: its => chainFrom H (τ ++ [(it, H (C.link (C.lastD H τ) it))]) its

/-- The verifier's hashing of a chain, as an oracle computation (`d0` is the start digest). -/
def chainOCFrom (d0 : D) : List (It × D) → List It → OC Q D (List (It × D))
  | τ, [] => .ret τ
  | τ, it :: its =>
      .ask (C.link ((τ.getLast?.map Prod.snd).getD d0) it) (fun d => chainOCFrom d0 (τ ++ [(it, d)]) its)

/-- The verifier's hashing: the start query, then one link query per item. -/
def chainOC (its : List It) : OC Q D (List (It × D)) := .ask C.start (fun d0 => C.chainOCFrom d0 [] its)

theorem chainOCFrom_bounded (d0 : D) : ∀ (τ : List (It × D)) (its : List It),
    (C.chainOCFrom d0 τ its).Bounded its.length
  | _, [] => trivial
  | τ, it :: its => fun d => chainOCFrom_bounded d0 (τ ++ [(it, d)]) its

theorem chainOC_bounded (its : List It) : (C.chainOC its).Bounded (its.length + 1) :=
  fun d0 => C.chainOCFrom_bounded d0 [] its

theorem chainFrom_length (H : Q → D) : ∀ (τ : List (It × D)) (its : List It),
    (C.chainFrom H τ its).length = τ.length + its.length
  | _, [] => rfl
  | τ, it :: its => by
    rw [chainFrom, chainFrom_length H _ its]
    simp only [List.length_append, List.length_cons, List.length_nil]
    omega

theorem chainFrom_append (H : Q → D) : ∀ (τ : List (It × D)) (its₁ its₂ : List It),
    C.chainFrom H τ (its₁ ++ its₂) = C.chainFrom H (C.chainFrom H τ its₁) its₂
  | _, [], _ => rfl
  | _, _ :: its₁, its₂ => chainFrom_append H _ its₁ its₂

/-- The recomputation's queries on `its₁ ++ its₂`: those on `its₁`, then those on `its₂` from where `its₁` ends. -/
theorem chainOCFrom_queries_append (H : Q → D) : ∀ (τ : List (It × D)) (its₁ its₂ : List It),
    OC.queries H (C.chainOCFrom (H C.start) τ (its₁ ++ its₂))
      = OC.queries H (C.chainOCFrom (H C.start) τ its₁)
        ++ OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H τ its₁) its₂)
  | τ, [], its₂ => by simp [chainOCFrom, chainFrom, OC.queries, OC.runLog]
  | τ, it :: its₁, its₂ => by
    rw [List.cons_append, chainOCFrom, chainOCFrom, OC.queries_ask, OC.queries_ask,
      chainOCFrom_queries_append H _ its₁ its₂]
    rfl

/-- **A chain and its queries**: the empty chain asks the start query; one more item asks its link with the chain's
last digest and gets the answer. -/
inductive Chain (H : Q → D) : List (It × D) → List Q → Prop
  | nil : Chain H [] [C.start]
  | snoc {τ : List (It × D)} {qs : List Q} (it : It) :
      Chain H τ qs → Chain H (τ ++ [(it, H (C.link (C.lastD H τ) it))]) (qs ++ [C.link (C.lastD H τ) it])

/-- Extending a chain by `chainFrom` keeps it a chain; its new queries are the recomputation's. -/
theorem chain_chainFrom (H : Q → D) : ∀ (its : List It) (τ : List (It × D)) (qs : List Q), C.Chain H τ qs →
    C.Chain H (C.chainFrom H τ its) (qs ++ OC.queries H (C.chainOCFrom (H C.start) τ its))
  | [], τ, qs, h => by simpa [chainFrom, chainOCFrom, OC.queries, OC.runLog] using h
  | it :: its, τ, qs, h => by
    have h' := chain_chainFrom H its _ _ (h.snoc it)
    rw [chainOCFrom, OC.queries_ask]
    simpa [chainFrom, lastD] using h'

/-- **The step where the chain escapes.** If the chain `τ` is doomed and its extension by `its` is not, some item `it`
after a doomed chain `τ'` (with its queries `qs'`) has a link whose answer takes `τ'` out of doom. The queries of `τ'`
and that link are among `τ`'s and the recomputation's. -/
theorem chain_flip (H : Q → D) (St : List (It × D) → Prop) : ∀ (its : List It) (τ : List (It × D)) (qs : List Q),
    C.Chain H τ qs → ¬ St τ → St (C.chainFrom H τ its) →
      ∃ τ' qs' it, C.Chain H τ' qs' ∧ τ.length ≤ τ'.length ∧ τ'.length < τ.length + its.length
        ∧ (∀ y ∈ qs', y ∈ qs ∨ y ∈ OC.queries H (C.chainOCFrom (H C.start) τ its))
        ∧ C.link (C.lastD H τ') it ∈ OC.queries H (C.chainOCFrom (H C.start) τ its)
        ∧ ¬ St τ' ∧ St (τ' ++ [(it, H (C.link (C.lastD H τ') it))])
  | [], _, _, _, hns, hs => absurd hs hns
  | it :: its, τ, qs, hc, hns, hs => by
    have hq0 : C.link (C.lastD H τ) it ∈ OC.queries H (C.chainOCFrom (H C.start) τ (it :: its)) := by
      rw [chainOCFrom, OC.queries_ask]
      exact List.mem_cons_self
    by_cases h1 : St (τ ++ [(it, H (C.link (C.lastD H τ) it))])
    · exact ⟨τ, qs, it, hc, le_rfl, by simp, fun y hy => Or.inl hy, hq0, hns, h1⟩
    · obtain ⟨τ', qs', it', hc', hl1, hl2, hqs, hq, hns', hs'⟩ :=
        chain_flip H St its _ _ (hc.snoc it) h1 hs
      have hsub : ∀ y, y ∈ OC.queries H (C.chainOCFrom (H C.start) (τ ++ [(it, H (C.link (C.lastD H τ) it))]) its)
          → y ∈ OC.queries H (C.chainOCFrom (H C.start) τ (it :: its)) := by
        intro y hy
        rw [chainOCFrom, OC.queries_ask]
        exact List.mem_cons_of_mem _ (by simpa [lastD] using hy)
      refine ⟨τ', qs', it', hc', ?_, ?_, fun y hy => ?_, hsub _ hq, hns', hs'⟩
      · simp only [List.length_append, List.length_cons, List.length_nil] at hl1
        omega
      · simp only [List.length_append, List.length_cons, List.length_nil] at hl2 ⊢
        omega
      · rcases hqs y hy with h | h
        · rcases List.mem_append.mp h with h | h
          · exact Or.inl h
          · rw [List.mem_singleton] at h
            rw [h]
            exact Or.inr hq0
        · exact Or.inr (hsub y h)

/-! ### The trace-back -/

variable [DecidableEq Q] [DecidableEq D]

/-- **The trace-back** of a digest `d` through a log `P`: the first logged question with answer `d`; if it is the
start query, the empty chain; otherwise decode it as `link(d', it)` and trace back `d'` (at most `f` steps). -/
def traceBack (P : List (Q × D)) : ℕ → D → Option (List (It × D))
  | 0, _ => none
  | f + 1, d =>
    match findPre P d with
    | none => none
    | some y =>
      if y = C.start then some []
      else
        match C.ldec y with
        | none => none
        | some p => (traceBack P f p.1).map (fun τ => τ ++ [(p.2, d)])

omit [DecidableEq Q] in
/-- Without a collision, the first logged question with the answer of a logged question `y` is `y`. -/
theorem findPre_of_noColl (H : Q → D) {P : List (Q × D)} (hP : ∀ e ∈ P, e.2 = H e.1) {y : Q}
    (hy : y ∈ P.map Prod.fst) (hnc : ∀ a ∈ P.map Prod.fst, a ≠ y → H a ≠ H y) : findPre P (H y) = some y := by
  rcases hf : findPre P (H y) with _ | y'
  · obtain ⟨e, he, rfl⟩ := List.mem_map.mp hy
    exact absurd (hP e he) (findPre_none hf e he)
  · obtain ⟨e, he, he1, he2⟩ := findPre_some hf
    by_contra hne
    have hne' : y' ≠ y := fun h => hne (by rw [h])
    exact hnc y' (he1 ▸ List.mem_map_of_mem he) hne' (by rw [← he1, ← hP e he, he2])

/-- **The trace-back recovers a chain** whose queries are all logged in `P`, when no two logged questions collide:
with fuel at least its length plus one it returns the chain itself. -/
theorem traceBack_chain (H : Q → D) {P : List (Q × D)} (hP : ∀ e ∈ P, e.2 = H e.1)
    (hnc : ∀ a ∈ P.map Prod.fst, ∀ b ∈ P.map Prod.fst, a ≠ b → H a ≠ H b) :
    ∀ {τ : List (It × D)} {qs : List Q}, C.Chain H τ qs → (∀ y ∈ qs, y ∈ P.map Prod.fst) →
      ∀ x, C.traceBack P (τ.length + 1 + x) (C.lastD H τ) = some τ := by
  intro τ qs hc
  induction hc with
  | nil =>
    intro hq x
    have hs : C.start ∈ P.map Prod.fst := hq _ List.mem_cons_self
    rw [List.length_nil, zero_add, add_comm, traceBack, lastD_nil,
      findPre_of_noColl H hP hs (fun a ha hne => hnc a ha _ hs hne)]
    simp
  | @snoc τ qs it hc ih =>
    intro hq x
    have hy : C.link (C.lastD H τ) it ∈ P.map Prod.fst := hq _ (List.mem_append_right _ List.mem_cons_self)
    have hrec := ih (fun y hy' => hq y (List.mem_append_left _ hy')) x
    rw [List.length_append, List.length_singleton, show τ.length + 1 + 1 + x = (τ.length + 1 + x) + 1 by omega,
      traceBack, lastD_snoc, findPre_of_noColl H hP hy (fun a ha hne => hnc a ha _ hy hne)]
    simp [C.link_ne_start, C.ldec_link, hrec]

/-! ### Out-of-order guesses -/

omit [DecidableEq Q] in
/-- An option has at most one element. -/
theorem option_card_toFinset_le {β : Type} (o : Option β) : o.toFinset.card ≤ 1 := by
  cases o <;> simp

/-- **The digests a log names**: for each logged question that decodes as a link, its state digest; and the state
digest of the query itself. A first-time answer in this set is a GUESS: the prover used the digest before it existed. -/
def chainTargets (P : List (Q × D)) (y : Q) : Finset D :=
  (P.map Prod.fst).toFinset.biUnion (fun y' => ((C.ldec y').map Prod.fst).toFinset) ∪ ((C.ldec y).map Prod.fst).toFinset

theorem chainTargets_card (P : List (Q × D)) (y : Q) : (C.chainTargets P y).card ≤ P.length + 1 := by
  unfold chainTargets
  refine (card_union_le _ _).trans (Nat.add_le_add ?_ ?_)
  · refine card_biUnion_le.trans ?_
    calc ∑ y' ∈ (P.map Prod.fst).toFinset, ((C.ldec y').map Prod.fst).toFinset.card
        ≤ ∑ _y' ∈ (P.map Prod.fst).toFinset, 1 := sum_le_sum (fun y' _ => option_card_toFinset_le _)
      _ = (P.map Prod.fst).toFinset.card := by rw [sum_const, smul_eq_mul, mul_one]
      _ ≤ P.length := (List.toFinset_card_le _).trans (by simp)
  · exact option_card_toFinset_le _

/-- **One step in order.** Unless a guess occurs, a logged question `y` is asked before ANY position `t` whose
question names `H y` as its state digest. -/
theorem inorder_step (H : Q → D) {L : List (Q × D)} (hL : ∀ e ∈ L, e.2 = H e.1)
    (hng : ¬ FreshHitQ C.chainTargets L) {y : Q} (hy : y ∈ L.map Prod.fst) {t : ℕ} {e : Q × D}
    (ht : L[t]? = some e) {it : It} (hname : C.ldec e.1 = some (H y, it)) : y ∈ (L.take t).map Prod.fst := by
  by_contra hny
  obtain ⟨ty, ey, h1, h2, h3⟩ := exists_first hy
  have hle : t ≤ ty := le_of_not_mem_take hny h1 h2
  apply hng
  refine ⟨ty, ey, h1, by rw [h2]; exact h3, ?_⟩
  rw [hL ey (List.mem_of_getElem? h1), h2]
  rcases Nat.lt_or_ge t ty with hlt | hge
  · -- the naming question is earlier: `H y` is a target of the log before `ty`
    have hmem : e.1 ∈ (L.take ty).map Prod.fst := mem_take_of_getElem? ht hlt
    refine mem_union_left _ (mem_biUnion.mpr ⟨e.1, List.mem_toFinset.mpr hmem, ?_⟩)
    rw [hname]
    simp
  · -- the same position: `y` names its own answer
    have hteq : t = ty := le_antisymm hle hge
    subst hteq
    have hee : e = ey := by
      rw [h1] at ht
      exact (Option.some.inj ht).symm
    rw [hee, h2] at hname
    refine mem_union_right _ ?_
    rw [hname]
    simp

/-- **A chain is logged in order.** Unless a guess occurs, every query of a chain (all logged) is asked before the
first occurrence of the next link query. -/
theorem chain_ordered (H : Q → D) {L : List (Q × D)} (hL : ∀ e ∈ L, e.2 = H e.1)
    (hng : ¬ FreshHitQ C.chainTargets L) :
    ∀ {τ : List (It × D)} {qs : List Q}, C.Chain H τ qs → (∀ y ∈ qs, y ∈ L.map Prod.fst) →
      ∀ {t : ℕ} {e : Q × D} (it : It), L[t]? = some e → e.1 = C.link (C.lastD H τ) it →
        ∀ y ∈ qs, y ∈ (L.take t).map Prod.fst := by
  intro τ qs hc
  induction hc with
  | nil =>
    intro hq t e it ht he y hy
    rw [List.mem_singleton] at hy
    subst hy
    exact inorder_step C H hL hng (hq _ List.mem_cons_self) ht (by rw [he, C.ldec_link, lastD_nil])
  | @snoc τ qs it' hc ih =>
    intro hq t e it ht he y hy
    -- the chain's last query is asked before `t`
    have hyl : C.link (C.lastD H τ) it' ∈ L.map Prod.fst := hq _ (List.mem_append_right _ List.mem_cons_self)
    have hlast : C.link (C.lastD H τ) it' ∈ (L.take t).map Prod.fst :=
      inorder_step C H hL hng hyl ht (by rw [he, C.ldec_link, lastD_snoc])
    rcases List.mem_append.mp hy with hy | hy
    · -- the earlier queries are asked before the chain's last query, hence before `t`
      obtain ⟨tp, ep, hp1, hp2, hp3⟩ := exists_first hyl
      have htp : tp < t := first_lt_of_mem_take hlast hp3
      exact mem_take_mono (ih (fun z hz => hq z (List.mem_append_left _ hz)) it' hp1 hp2 y hy) htp.le
    · rw [List.mem_singleton] at hy
      rw [hy]
      exact hlast

end ChainEnc

/-! ## Soundness of a chain -/

section Sound

variable {It Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **Fiat–Shamir soundness with the code's hash chain.** Let `St` be a state function on chain transcripts such that
from a doomed chain of at least `s` items, whatever the next item, at most `k` digests lead out of doom. A prover makes
at most `q` hash queries and outputs items; the verifier hashes the first `ℓ` of them as a chain. The probability that
the chain of the first `s` items is doomed while the whole chain is not is at most
`T·k/|D| + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`: the prefix-hash bound of `FSRbr.lean`, a collision
term, and a guess term. -/
theorem chain_sound (C : ChainEnc It Q D) (St : List (It × D) → Prop) (s k : ℕ)
    (hround : ∀ τ it, s ≤ τ.length → ¬ St τ → EscapesWithin (fun d : D => St (τ ++ [(it, d)])) k)
    {α : Type} (q ℓ : ℕ) (A : OC Q D (List It × α)) (hA : A.Bounded q) :
    prH (fun H => ¬ St (C.chainFrom H [] (((A.run H).1.take ℓ).take s))
        ∧ St (C.chainFrom H [] ((A.run H).1.take ℓ)))
      ≤ (((q + ℓ + 1) * k : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + ℓ + 1) D
        + collBound (q + ℓ + 1 + 1) D := by
  classical
  set T := q + ℓ + 1 with hT
  -- the whole run: the prover, then the verifier's chain
  let V : List It × α → OC Q D (List (It × D)) := fun o => C.chainOC (o.1.take ℓ)
  let Cm : OC Q D (List (It × D)) := A.bind V
  have hCm : Cm.Bounded T :=
    (hA.bind (fun o => (C.chainOC_bounded (o.1.take ℓ)).mono
      (show (o.1.take ℓ).length + 1 ≤ ℓ + 1 by simp))).mono (by omega)
  -- the escaping digests named by a query: trace its state back through the log, and take the step's escape set
  let bad : List (It × D) → It → Finset D := fun τ it =>
    if h : s ≤ τ.length ∧ ¬ St τ then Classical.choose (hround τ it h.1 h.2) else ∅
  let F : List (Q × D) → Q → Finset D := fun P y =>
    match C.ldec y with
    | none => ∅
    | some p =>
      match C.traceBack P (ℓ + 1) p.1 with
      | none => ∅
      | some τ => bad τ p.2
  have hbad : ∀ τ it, (bad τ it).card ≤ k := by
    intro τ it
    simp only [bad]
    split_ifs with h
    · exact (Classical.choose_spec (hround τ it h.1 h.2)).1
    · simp
  have hF : ∀ P y, (F P y).card ≤ k := by
    intro P y
    simp only [F]
    split
    · simp
    · split
      · simp
      · exact hbad _ _
  have hfr := freshHitQ_prob_le Cm T hCm F k hF
  have hcoll := collision_prob_le Cm T hCm
  have hgs := freshHitQ_prob_le_gen Cm T hCm C.chainTargets (fun t => t + 1) (fun P y => C.chainTargets_card P y)
  have hsum : ∀ n : ℕ, ∑ t ∈ range n, (t + 1) = (n + 1) * (n + 1 - 1) / 2 := by
    intro n
    rw [← Finset.sum_range_id (n + 1)]
    simp [Finset.sum_range_succ']
  rw [hsum T] at hgs
  have hsub : {H : Q → D | ¬ St (C.chainFrom H [] (((A.run H).1.take ℓ).take s))
        ∧ St (C.chainFrom H [] ((A.run H).1.take ℓ))}
      ⊆ ({H | FreshHitQ F (Cm.runLog H).2}
          ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b})
        ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2} := by
    rintro H ⟨hns, hs⟩
    by_cases hg : FreshHitQ C.chainTargets (Cm.runLog H).2
    · exact Or.inr hg
    by_cases hc : ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b
    · exact Or.inl (Or.inr hc)
    refine Or.inl (Or.inl ?_)
    have hnc : ∀ a ∈ OC.queries H Cm, ∀ b ∈ OC.queries H Cm, a ≠ b → H a ≠ H b := by
      intro a ha b hb hab hH
      exact hc ⟨a, ha, b, hb, hab, hH⟩
    set its := (A.run H).1.take ℓ with hits
    have hL : ∀ e ∈ (Cm.runLog H).2, e.2 = H e.1 := OC.runLog_answer H Cm
    -- the verifier's queries are logged
    have hqV : ∀ y ∈ OC.queries H (C.chainOC its), y ∈ (Cm.runLog H).2.map Prod.fst := by
      intro y hy
      show y ∈ OC.queries H Cm
      simp only [Cm, OC.queries_bind]
      exact List.mem_append_right _ (by simpa [V, hits] using hy)
    have hqV' : OC.queries H (C.chainOC its)
        = C.start :: (OC.queries H (C.chainOCFrom (H C.start) [] (its.take s))
          ++ OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H [] (its.take s)) (its.drop s))) := by
      rw [ChainEnc.chainOC, OC.queries_ask, ← C.chainOCFrom_queries_append, List.take_append_drop]
    -- a short item list cannot escape: its first `s` items are all of it
    have hlen : s ≤ its.length := by
      by_contra hlt
      push Not at hlt
      rw [List.take_of_length_le hlt.le] at hns
      exact hns hs
    -- the chain of the first `s` items, and the full chain extends it
    have hcs := C.chain_chainFrom H (its.take s) [] [C.start] ChainEnc.Chain.nil
    have hfull : C.chainFrom H [] its = C.chainFrom H (C.chainFrom H [] (its.take s)) (its.drop s) := by
      rw [← C.chainFrom_append, List.take_append_drop]
    rw [hfull] at hs
    obtain ⟨τ', qs', it, hc', hl1, hl2, hqs, hq, hns', hs'⟩ := C.chain_flip H St (its.drop s) _ _ hcs hns hs
    have hlen_s : (C.chainFrom H [] (its.take s)).length = s := by
      rw [C.chainFrom_length, List.length_nil, zero_add, List.length_take, min_eq_left hlen]
    have hτ'len : τ'.length < ℓ + 1 := by
      have h1 : (C.chainFrom H [] (its.take s)).length + (its.drop s).length = its.length := by
        rw [C.chainFrom_length, List.length_nil, zero_add, ← List.length_append, List.take_append_drop]
      have h2 : its.length ≤ ℓ := by rw [hits, List.length_take]; exact min_le_left _ _
      omega
    -- every query of the chain `τ'` and the escaping link are logged
    have hq'L : ∀ y ∈ qs', y ∈ (Cm.runLog H).2.map Prod.fst := by
      intro y hy
      refine hqV y ?_
      rw [hqV']
      rcases hqs y hy with h | h
      · rcases List.mem_append.mp h with h | h
        · rw [List.mem_singleton] at h
          rw [h]
          exact List.mem_cons_self
        · exact List.mem_cons_of_mem _ (List.mem_append_left _ h)
      · exact List.mem_cons_of_mem _ (List.mem_append_right _ h)
    have hyL : C.link (C.lastD H τ') it ∈ (Cm.runLog H).2.map Prod.fst := by
      refine hqV _ ?_
      rw [hqV']
      exact List.mem_cons_of_mem _ (List.mem_append_right _ hq)
    refine freshHitQ_of_first H hL F hyL (fun t e ht he hfirst => ?_)
    -- at the escaping link's first occurrence, the log before it traces `τ'` back
    have hord := C.chain_ordered H hL hg hc' hq'L it ht he
    have hPL : ∀ e ∈ (Cm.runLog H).2.take t, e.2 = H e.1 := fun e he => hL e (List.mem_of_mem_take he)
    have hPnc : ∀ a ∈ ((Cm.runLog H).2.take t).map Prod.fst, ∀ b ∈ ((Cm.runLog H).2.take t).map Prod.fst,
        a ≠ b → H a ≠ H b := by
      intro a ha b hb
      exact hnc a (mem_of_mem_take_map ha) b (mem_of_mem_take_map hb)
    have htb := C.traceBack_chain H hPL hPnc hc' hord (ℓ - τ'.length)
    rw [show τ'.length + 1 + (ℓ - τ'.length) = ℓ + 1 by omega] at htb
    simp only [F, C.ldec_link, htb, bad]
    split_ifs with h
    · exact (Classical.choose_spec (hround τ' it h.1 h.2)).2 _ hs'
    · exact absurd ⟨hlen_s ▸ hl1, hns'⟩ h
  calc prH (fun H => ¬ St (C.chainFrom H [] (((A.run H).1.take ℓ).take s))
        ∧ St (C.chainFrom H [] ((A.run H).1.take ℓ)))
      ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure (({H | FreshHitQ F (Cm.runLog H).2}
          ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b})
          ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2}) := MeasureTheory.measure_mono hsub
    _ ≤ prH (fun H => FreshHitQ F (Cm.runLog H).2)
          + prH (fun H => ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b)
          + prH (fun H => FreshHitQ C.chainTargets (Cm.runLog H).2) :=
        (MeasureTheory.measure_union_le _ _).trans (add_le_add (MeasureTheory.measure_union_le _ _) le_rfl)
    _ ≤ _ := add_le_add (add_le_add hfr hcoll) hgs

end Sound

end ZK60.Sound
