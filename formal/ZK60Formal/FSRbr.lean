/-
D63, step L3 (soundness): Fiat–Shamir in the random-oracle model, from round-by-round soundness.

The interactive soundness files (`SoundSumcheck.lean`, `SoundLogUp*.lean`, `SoundZeroCheck.lean`, `SoundOpening*.lean`)
draw every challenge exactly uniformly and independently. The receipts do not: every challenge is a hash of the
transcript so far (Fiat–Shamir). This file proves the generic step from one to the other, in `Statements.lean`'s model
(the hash is one uniformly random function `H : Q → D`; the prover is a deterministic oracle computation `OC Q D _`
making at most `q` queries on every path; probabilities are `prH`).

**The protocol.** A public-coin protocol with `n` rounds: in round `i` the prover sends a message `m_i : M` and the
verifier answers with a challenge `c_i : Ch`; then the prover sends a final message `mf : Mf`, and the verifier decides
`accept x τ mf` from the statement `x`, the transcript `τ = [(m_0, c_0), …, (m_{n−1}, c_{n−1})]` and `mf`.

**Round-by-round soundness** (`RbrSound`; R. Canetti, Y. Chen, J. Holmgren, A. Lombardi, G. Rothblum, R. Rothblum,
D. Wichs, "Fiat–Shamir: from practice to theory", STOC 2019, ePrint 2018/1004, Def. 5.3; also A. Chiesa and E. Yogev,
"Building Cryptographic Proofs from Hash Functions"). A state function `St x τ` on partial transcripts
(`St` true: the prover may still win; false: it is DOOMED) such that
* a false statement starts doomed (`start`);
* from a doomed partial transcript, whatever the next message, at most `e` challenges lead to a state that is not
  doomed (`round`; the error per round is `e/|Ch|`, `EscapesWithin.prob_le`);
* a doomed full transcript is rejected, whatever the final message (`final`).
FlashProve's `Iop/Rbr.lean` (`Doomed`, a count of escaping challenges per round) states the same notion; nothing is
copied from it here.

**The compilation** (`fsTr`, `fsAccepts`). The challenge of round `i` is `chal (H (enc x τ_i m_i))`: the hash of an
injective encoding of the statement, the transcript so far (its messages AND its challenges) and the round's message,
read into the challenge space by `chal : D → Ch`. The prover outputs `(x, [m_0, …, m_{n−1}], mf)`; the verifier
recomputes the challenges and runs `accept`. The statement is chosen by the prover AFTER it has seen hash values
(adaptive soundness): that is why `x` is part of every hash input. With `x` left out, the theorem is false (the "weak
Fiat–Shamir" attacks).

**What is proved.**
* `freshHitQ_prob_le`: `SoundRO.lean`'s fresh-hit lemma with the bad set allowed to depend on the query itself:
  along a run of at most `T` queries, a first-time query whose answer lands in a set of at most `m` digests named by
  the query (and the log before it) has probability at most `T·m/|D|`.
* `fs_sound`: if the escaping DIGESTS of every round number at most `k`, a `q`-query prover makes the verifier accept a
  false statement with probability at most `(q + n)·k/|D|`. The `n` counts the verifier's own `n` hash queries (a
  prover that never asks a query the verifier will ask is not helped by it).
* `EscapesWithin.comap`: if at most `e` challenges escape and every challenge has at most `K` digest preimages under
  `chal`, at most `e·K` digests escape.
* `fs_sound_of_rbr`: round-by-round soundness with `e` escaping challenges per round gives the Fiat–Shamir bound
  `(q + n)·e·K/|D|`; `fs_sound_of_rbr_bias` writes it as `(q + n)·e/|Ch| · biasFactor K Ch D`, the interactive
  per-round error times the derivation's bias factor `K·|Ch|/|D|` (`1` for a uniform derivation, `fs_sound_uniform`;
  `(1 + p/2^128)²` for the code's `challenge_fp2`, `FSChallenge.lean`).

**What this does not cover** (each is said again where it matters, and in `ZK60_LEAN_L3_FINDINGS_20261104.md`):
* The code's transcript is a hash CHAIN (`zkp_core::transcript`: each absorb hashes the previous 32-byte state with the
  new message; each challenge hashes the state with a counter), not a hash of the whole prefix. The chain is a prefix
  hash only up to collisions and out-of-order guesses: that reduction is `FSChain.lean`, and `FSChainRbr.lean` runs
  an RBR-sound protocol on it.
* A challenge drawn as several squeezes (`challenge_fp2_vec`, `challenge_indices` beyond four indices) is one challenge
  of this model only if the squeezes are read as one wide digest; that reading is not proved here. It is proved on
  the code's chain in `FSWide.lean` (the wide-digest lemma).
* The protocol's messages are values here. In the receipts the large messages are Merkle roots, and the statement the
  state function speaks about is the committed data: that is the extractor's job (`SoundExtract.lean`), composed with
  this file in a later step (the log cut at the query that absorbs the root).
-/
import ZK60Formal.SoundRO

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Fresh hits on a set named by the query -/

section FreshQ

variable {Q D : Type}

/-- **A fresh hit on a set named by the query**: some entry of the log asks a question that no earlier entry asked,
and its answer lies in the set `F` names from the entries before it and from the question itself. (`SoundRO.lean`'s
`FreshHit` is the case where `F` ignores the question.) -/
def FreshHitQ (F : List (Q × D) → Q → Finset D) (L : List (Q × D)) : Prop :=
  ∃ t e, L[t]? = some e ∧ e.1 ∉ (L.take t).map Prod.fst ∧ e.2 ∈ F (L.take t) e.1

/-- A logged question whose answer lies in the set `F` names from it, whatever the log before it, gives a fresh hit
(at its first occurrence). -/
theorem freshHitQ_of_mem (H : Q → D) {L : List (Q × D)} (hL : ∀ e ∈ L, e.2 = H e.1)
    (F : List (Q × D) → Q → Finset D) {v : Q} (hv : v ∈ L.map Prod.fst) (hF : ∀ P, H v ∈ F P v) :
    FreshHitQ F L := by
  obtain ⟨t, e, h1, h2, h3⟩ := exists_first hv
  refine ⟨t, e, h1, by rw [h2]; exact h3, ?_⟩
  rw [hL e (List.mem_of_getElem? h1), h2]
  exact hF _

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The fresh-hit lemma, with the bad set named by the query.** For a computation making at most `T` queries on
every path, and a set `F P y` of at most `m` digests named by the query `y` and the log `P` before it: the probability,
over a uniform oracle, that some query gets, the first time it is asked, an answer in its set, is at most
`T·m/|D|`. -/
theorem freshHitQ_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T)
    (F : List (Q × D) → Q → Finset D) (m : ℕ) (hF : ∀ P y, (F P y).card ≤ m) :
    prH (fun H => FreshHitQ F (A.runLog H).2) ≤ ((T * m : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  set μ := (PMF.uniformOfFintype (Q → D)).toOuterMeasure
  -- position `t` names the point it asks, when that point is new
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
  have hpos : ∀ t, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} ≤ (m : ℝ≥0∞) / Fintype.card D := by
    intro t
    refine prob_fresh_mem_le (G t) (Tt t) m ?_ ?_ ?_
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
    · rintro y H -
      exact hF _ _
  calc prH (fun H => FreshHitQ F (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | ∃ y, G t y H ∧ H y ∈ Tt t y H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} :=
        MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ _t ∈ range T, (m : ℝ≥0∞) / Fintype.card D := sum_le_sum (fun t _ => hpos t)
    _ = ((T * m : ℕ) : ℝ≥0∞) / Fintype.card D := by
        rw [sum_const, card_range, nsmul_eq_mul, Nat.cast_mul, mul_div_assoc]

end FreshQ

/-! ## Round-by-round soundness -/

section Rbr

variable {X M Ch Mf : Type}

/-- **At most `e` escapes**: the values `c` with `S c` lie in a set of at most `e` values. -/
def EscapesWithin {C : Type} (S : C → Prop) (e : ℕ) : Prop :=
  ∃ B : Finset C, B.card ≤ e ∧ ∀ c, S c → c ∈ B

/-- A uniform draw escapes with probability at most `e/|C|`. -/
theorem EscapesWithin.prob_le {C : Type} [Fintype C] [Nonempty C] {S : C → Prop} {e : ℕ}
    (h : EscapesWithin S e) :
    (PMF.uniformOfFintype C).toOuterMeasure {c | S c} ≤ (e : ℝ≥0∞) / Fintype.card C := by
  obtain ⟨B, hB, hS⟩ := h
  refine le_trans (MeasureTheory.measure_mono (fun c hc => Finset.mem_coe.mpr (hS c hc)))
    (prob_le_of_card (↑B : Set C) e ?_)
  rw [Nat.card_coe_set_eq, Set.ncard_coe_finset]
  exact hB

/-- **Escapes through a derivation.** If at most `e` challenges escape and every challenge has at most `K` preimages
under the derivation `chal : D → C`, at most `e·K` digests escape. -/
theorem EscapesWithin.comap {C D : Type} [DecidableEq C] [Fintype D] {S : C → Prop} {e K : ℕ}
    (h : EscapesWithin S e) (chal : D → C) (hK : ∀ c, (univ.filter (fun d => chal d = c)).card ≤ K) :
    EscapesWithin (fun d => S (chal d)) (e * K) := by
  classical
  obtain ⟨B, hB, hS⟩ := h
  refine ⟨B.biUnion (fun c => univ.filter (fun d => chal d = c)), ?_, fun d hd => ?_⟩
  · refine card_biUnion_le.trans ?_
    calc ∑ c ∈ B, (univ.filter (fun d => chal d = c)).card ≤ ∑ _c ∈ B, K := sum_le_sum (fun c _ => hK c)
      _ = B.card * K := by rw [sum_const, smul_eq_mul]
      _ ≤ e * K := Nat.mul_le_mul_right _ hB
  · exact mem_biUnion.mpr ⟨chal d, hS _ hd, mem_filter.mpr ⟨mem_univ _, rfl⟩⟩

/-- **Round-by-round soundness** of a public-coin protocol with `n` rounds, for the language `L`, with the state
function `St` (true: the prover may still win; false: doomed) and at most `e` escaping challenges per round:
* `start`: a statement outside `L` starts doomed;
* `round`: from a doomed transcript of fewer than `n` rounds, whatever the next message `m`, at most `e` challenges
  `c` make `τ ++ [(m, c)]` not doomed;
* `final`: a doomed transcript of `n` rounds is rejected, whatever the final message.
The per-round error is `e/|Ch|` (`EscapesWithin.prob_le`). -/
structure RbrSound (n : ℕ) (L : X → Prop) (accept : X → List (M × Ch) → Mf → Prop)
    (St : X → List (M × Ch) → Prop) (e : ℕ) : Prop where
  start : ∀ x, ¬ L x → ¬ St x []
  round : ∀ x τ m, τ.length < n → ¬ St x τ → EscapesWithin (fun c => St x (τ ++ [(m, c)])) e
  final : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf

/-- One round of an RBR-sound protocol, as a probability: from a doomed transcript, a uniform challenge escapes with
probability at most `e/|Ch|`. -/
theorem RbrSound.round_prob [Fintype Ch] [Nonempty Ch] {n e : ℕ} {L : X → Prop}
    {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop} (h : RbrSound n L accept St e)
    (x : X) (τ : List (M × Ch)) (m : M) (hτ : τ.length < n) (hd : ¬ St x τ) :
    (PMF.uniformOfFintype Ch).toOuterMeasure {c | St x (τ ++ [(m, c)])} ≤ (e : ℝ≥0∞) / Fintype.card Ch :=
  (h.round x τ m hτ hd).prob_le

/-! ## The Fiat–Shamir compilation -/

/-- **The hash input of a round**: an injective encoding of the statement, the transcript so far (messages and
challenges) and the round's message, given with its left inverse. (In the code the transcript hash also carries the
profile's domain string and, for tagged profiles, the Fiat–Shamir key; both are fixed parts of the encoding.) -/
structure FSEnc (X M Ch Q : Type) where
  enc : X → List (M × Ch) → M → Q
  dec : Q → Option (X × List (M × Ch) × M)
  dec_enc : ∀ x τ m, dec (enc x τ m) = some (x, τ, m)

variable {Q D : Type}

/-- **The Fiat–Shamir transcript**: starting from `τ`, each message `m` gets the challenge `chal (H (enc x τ m))`,
the hash of everything before it. -/
def fsTr (E : FSEnc X M Ch Q) (chal : D → Ch) (H : Q → D) (x : X) : List (M × Ch) → List M → List (M × Ch)
  | τ, [] => τ
  | τ, m :: ms => fsTr E chal H x (τ ++ [(m, chal (H (E.enc x τ m)))]) ms

/-- The verifier's recomputation of the challenges, as an oracle computation: one hash query per message. -/
def fsChalOC (E : FSEnc X M Ch Q) (chal : D → Ch) (x : X) : List (M × Ch) → List M → OC Q D (List (M × Ch))
  | τ, [] => .ret τ
  | τ, m :: ms => .ask (E.enc x τ m) (fun dg => fsChalOC E chal x (τ ++ [(m, chal dg)]) ms)

/-- Running the recomputation gives the Fiat–Shamir transcript. -/
theorem fsChalOC_run (E : FSEnc X M Ch Q) (chal : D → Ch) (H : Q → D) (x : X) :
    ∀ (τ : List (M × Ch)) (ms : List M), (fsChalOC E chal x τ ms).run H = fsTr E chal H x τ ms
  | _, [] => rfl
  | τ, m :: ms => fsChalOC_run E chal H x (τ ++ [(m, chal (H (E.enc x τ m)))]) ms

/-- The recomputation makes one query per message. -/
theorem fsChalOC_bounded (E : FSEnc X M Ch Q) (chal : D → Ch) (x : X) :
    ∀ (τ : List (M × Ch)) (ms : List M), (fsChalOC E chal x τ ms).Bounded ms.length
  | _, [] => trivial
  | τ, m :: ms => fun dg => fsChalOC_bounded E chal x (τ ++ [(m, chal dg)]) ms

/-- The Fiat–Shamir transcript has one entry per message. -/
theorem fsTr_length (E : FSEnc X M Ch Q) (chal : D → Ch) (H : Q → D) (x : X) :
    ∀ (τ : List (M × Ch)) (ms : List M), (fsTr E chal H x τ ms).length = τ.length + ms.length
  | _, [] => rfl
  | τ, m :: ms => by
    rw [fsTr, fsTr_length E chal H x _ ms]
    simp only [List.length_append, List.length_cons, List.length_nil]
    omega

/-- **The Fiat–Shamir verifier**: exactly `n` messages, and the protocol's verifier accepts the transcript with the
recomputed challenges. -/
def fsAccepts (n : ℕ) (accept : X → List (M × Ch) → Mf → Prop) (E : FSEnc X M Ch Q) (chal : D → Ch) (H : Q → D)
    (x : X) (ms : List M) (mf : Mf) : Prop :=
  ms.length = n ∧ accept x (fsTr E chal H x [] ms) mf

/-- **The round where the prover escapes.** If the transcript starts doomed and ends not doomed, some round's hash
query `enc x τ' m`, asked by the recomputation, has an answer that takes the doomed `τ'` to a state that is not
doomed. -/
theorem fs_flip (E : FSEnc X M Ch Q) (chal : D → Ch) (H : Q → D) (x : X) (St : X → List (M × Ch) → Prop) (n : ℕ) :
    ∀ (ms : List M) (τ : List (M × Ch)), ¬ St x τ → τ.length + ms.length ≤ n → St x (fsTr E chal H x τ ms) →
      ∃ τ' m, E.enc x τ' m ∈ OC.queries H (fsChalOC E chal x τ ms) ∧ τ'.length < n ∧ ¬ St x τ'
        ∧ St x (τ' ++ [(m, chal (H (E.enc x τ' m)))])
  | [], _, hns, _, hs => absurd hs hns
  | m :: ms, τ, hns, hlen, hs => by
    rw [List.length_cons] at hlen
    by_cases h1 : St x (τ ++ [(m, chal (H (E.enc x τ m)))])
    · refine ⟨τ, m, ?_, by omega, hns, h1⟩
      rw [fsChalOC, OC.queries_ask]
      exact List.mem_cons_self
    · obtain ⟨τ', m', hq, hlt, hns', hs'⟩ := fs_flip E chal H x St n ms _ h1
        (by rw [List.length_append, List.length_singleton]; omega) hs
      refine ⟨τ', m', ?_, hlt, hns', hs'⟩
      rw [fsChalOC, OC.queries_ask]
      exact List.mem_cons_of_mem _ hq

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **Fiat–Shamir soundness, digest form.** Let a false statement start doomed (`hstart`), let at most `k` DIGESTS
take a doomed transcript of fewer than `n` rounds out of doom, whatever the next message (`hround`), and let a doomed
full transcript be rejected (`hfinal`). Then a prover making at most `q` hash queries, choosing the statement itself,
outputs a false statement that the Fiat–Shamir verifier accepts with probability at most `(q + n)·k/|D|`. -/
theorem fs_sound {n k : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop}
    {St : X → List (M × Ch) → Prop} (E : FSEnc X M Ch Q) (chal : D → Ch)
    (hstart : ∀ x, ¬ L x → ¬ St x [])
    (hround : ∀ x τ m, τ.length < n → ¬ St x τ → EscapesWithin (fun dg : D => St x (τ ++ [(m, chal dg)])) k)
    (hfinal : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ fsAccepts n accept E chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + n) * k : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  -- the whole run: the prover, then the verifier's recomputation of the challenges
  let V : X × List M × Mf → OC Q D (List (M × Ch)) := fun o => fsChalOC E chal o.1 [] (o.2.1.take n)
  let C : OC Q D (List (M × Ch)) := A.bind V
  have hC : C.Bounded (q + n) :=
    hA.bind (fun o => (fsChalOC_bounded E chal o.1 [] (o.2.1.take n)).mono (by simp))
  -- the escaping digests named by a query: decode it, and take the round's escape set
  let bad : X × List (M × Ch) × M → Finset D := fun p =>
    if h : p.2.1.length < n ∧ ¬ St p.1 p.2.1 then Classical.choose (hround p.1 p.2.1 p.2.2 h.1 h.2) else ∅
  let F : List (Q × D) → Q → Finset D := fun _ y => (E.dec y).elim ∅ bad
  have hbad : ∀ p, (bad p).card ≤ k := by
    intro p
    simp only [bad]
    split_ifs with h
    · exact (Classical.choose_spec (hround p.1 p.2.1 p.2.2 h.1 h.2)).1
    · simp
  have hF : ∀ P y, (F P y).card ≤ k := by
    intro P y
    simp only [F]
    rcases hdy : E.dec y with _ | p
    · simp
    · exact hbad p
  refine le_trans (MeasureTheory.measure_mono ?_) (freshHitQ_prob_le C (q + n) hC F k hF)
  rintro H ⟨hL, hlen, hacc⟩
  set o := A.run H with ho
  have hs : St o.1 (fsTr E chal H o.1 [] o.2.1) := by
    by_contra hns
    exact hfinal _ _ _ (by rw [fsTr_length, hlen]; simp) hns hacc
  obtain ⟨τ', m, hq, hlt, hns, hs'⟩ := fs_flip E chal H o.1 St n o.2.1 [] (hstart _ hL)
    (by rw [hlen]; simp) hs
  have hqC : E.enc o.1 τ' m ∈ OC.queries H C := by
    simp only [C, OC.queries_bind]
    refine List.mem_append_right _ ?_
    simp only [V]
    rw [← ho, List.take_of_length_le (le_of_eq hlen)]
    exact hq
  refine freshHitQ_of_mem H (OC.runLog_answer H C) F hqC (fun P => ?_)
  simp only [F, E.dec_enc, Option.elim, bad]
  split_ifs with h
  · exact (Classical.choose_spec (hround o.1 τ' m h.1 h.2)).2 _ hs'
  · exact absurd ⟨hlt, hns⟩ h

/-- **Fiat–Shamir soundness from round-by-round soundness.** An RBR-sound protocol with at most `e` escaping
challenges per round, its challenges derived as `chal (H (prefix))` with at most `K` digests per challenge value, is
sound against any prover making at most `q` hash queries, with error at most `(q + n)·e·K/|D|`. -/
theorem fs_sound_of_rbr [DecidableEq Ch] {n e : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop}
    {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e) (E : FSEnc X M Ch Q) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ fsAccepts n accept E chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + n) * (e * K) : ℕ) : ℝ≥0∞) / Fintype.card D :=
  fs_sound E chal hR.start (fun x τ m h1 h2 => (hR.round x τ m h1 h2).comap chal hK) hR.final q A hA

/-- **The bias factor of a derivation** `chal : D → Ch` with at most `K` digests per challenge: `K·|Ch|/|D|`. It is
`1` when `chal` is a bijection, and close to `1` when `D` is much larger than `Ch` and `chal` nearly balanced. -/
noncomputable def biasFactor (K : ℕ) (C D' : Type) [Fintype C] [Fintype D'] : ℝ≥0∞ :=
  (K * Fintype.card C : ℝ≥0∞) / Fintype.card D'

omit [Nonempty D] in
/-- The digest count over `|D|` is the challenge count over `|Ch|` times the bias factor. -/
theorem div_card_eq_mul_bias [Fintype Ch] [Nonempty Ch] (a K : ℕ) :
    ((a * K : ℕ) : ℝ≥0∞) / Fintype.card D = (a : ℝ≥0∞) / Fintype.card Ch * biasFactor K Ch D := by
  have hc0 : (Fintype.card Ch : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hct : (Fintype.card Ch : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  rw [biasFactor, Nat.cast_mul, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv]
  calc (a : ℝ≥0∞) * K * (Fintype.card D : ℝ≥0∞)⁻¹
      = (a : ℝ≥0∞) * K * (Fintype.card D : ℝ≥0∞)⁻¹ * ((Fintype.card Ch : ℝ≥0∞)⁻¹ * Fintype.card Ch) := by
        rw [ENNReal.inv_mul_cancel hc0 hct, mul_one]
    _ = (a : ℝ≥0∞) * (Fintype.card Ch : ℝ≥0∞)⁻¹ * (K * Fintype.card Ch * (Fintype.card D : ℝ≥0∞)⁻¹) := by ring

/-- **Fiat–Shamir soundness, the interactive error times the bias.** The bound of `fs_sound_of_rbr` is
`(q + n)·e/|Ch|` (the interactive per-round error `e/|Ch|`, once per hash query) times the derivation's bias factor
`K·|Ch|/|D|`. -/
theorem fs_sound_of_rbr_bias [Fintype Ch] [Nonempty Ch] [DecidableEq Ch] {n e : ℕ} {L : X → Prop}
    {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e)
    (E : FSEnc X M Ch Q) (chal : D → Ch) (K : ℕ) (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ fsAccepts n accept E chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + n) * e : ℕ) : ℝ≥0∞) / Fintype.card Ch * biasFactor K Ch D := by
  rw [← div_card_eq_mul_bias, mul_assoc]
  exact fs_sound_of_rbr hR E chal K hK q A hA

/-- **Uniform challenges** (the digest IS the challenge, `chal = id`): the Fiat–Shamir error is `(q + n)·e/|Ch|`, the
interactive per-round error once per hash query. -/
theorem fs_sound_uniform [Fintype Ch] [Nonempty Ch] [DecidableEq Ch] {n e : ℕ} {L : X → Prop}
    {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e)
    (E : FSEnc X M Ch Q) (q : ℕ) (A : OC Q Ch (X × List M × Mf))
    (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ fsAccepts n accept E id H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + n) * e : ℕ) : ℝ≥0∞) / Fintype.card Ch := by
  have h := fs_sound_of_rbr hR E id 1 (fun c => by
    rw [card_le_one]
    intro a ha b hb
    simp only [mem_filter, mem_univ, true_and, id] at ha hb
    rw [ha, hb]) q A hA
  simpa using h

end Rbr

end ZK60.Sound
