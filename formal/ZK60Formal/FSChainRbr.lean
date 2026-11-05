/-
D63, step L3 (soundness): a round-by-round sound protocol run on the code's transcript chain.

`FSChain.lean` proves soundness for any state function on chain transcripts. This file builds that state function
from a protocol's (`FSRbr.lean`'s `RbrSound`) for the chain the code's verifiers hash: the statement, then per round
the prover's message and one squeeze with its counter,

  `start`, `stmt x`, `msg m_0`, `sq 0`, `msg m_1`, `sq 1`, …, `msg m_{n−1}`, `sq (n−1)`

(`pItems`; in `zkp_core::sumcheck::verify`: `absorb_fp2("sc-round", s_j)` then `challenge_fp2()`, whose squeeze counter
is the number of squeezes so far). The challenge of round `j` is `chal` of the digest of the `sq j` link.

What is proved.
* `rDecode`, `rDecode_rounds`: reading a chain's items back as a protocol transcript (messages from the `msg` items,
  challenges from the `sq` items' digests) succeeds on the verifier's chain and returns its `n` messages.
* `liftSt`, `liftSt_round`: the protocol's state function on chains. A `msg` item never changes the state, a `sq` item
  is the protocol round; items out of the schedule doom the chain. From a doomed chain at most `e·K` digests escape.
* `fs_chain_sound_of_rbr`: an RBR-sound protocol with `e` escaping challenges per round, run on the chain, is sound
  against a `q`-query prover with error at most `T·e·K/|D| + collBound T D + collBound (T + 1) D`,
  `T = q + 2n + 2` (the prover's queries, the verifier's `2n + 1` links and the start query).
* `fs_sumcheck_chain_sound`: the sumcheck so, `T·d·K/|D| + …`, and with the code's `challenge_fp2`
  (`fs_sumcheck_chain_sound_code`) `T·d/|F|·(1 + p/2^128)² + collBound T + collBound (T + 1)` over `|D| = 2^256`.

What it takes from the code, and what it does not cover. The statement is ONE item here; the code absorbs it as the
header's several labelled absorbs (`ZK60_LEAN_L3_FINDINGS_20261104.md`, Fiat–Shamir section, lists them), which is the
same chain with more links and changes nothing but `T`. The counter of `sq j` is `j` here; in the code it is the
transcript's squeeze count, which differs from `j` by the squeezes drawn before the sumcheck: a fixed offset, so the
decoder with that offset is the same argument. Slots of a block share one chain; the composition of several
protocols on one chain is `FSCompose.lean`'s.
-/
import ZK60Formal.FSChain
import ZK60Formal.FSSumcheck

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-- **The items of a protocol's chain**: the statement, a prover message, a squeeze with its counter. -/
inductive PItem (X M : Type) where
  | stmt : X → PItem X M
  | msg : M → PItem X M
  | sq : ℕ → PItem X M

variable {X M Ch Mf Q D : Type}

/-- The items of the rounds from round `j` on: each message, then a squeeze with the round's counter. -/
def roundItems : ℕ → List M → List (PItem X M)
  | _, [] => []
  | j, m :: ms => .msg m :: .sq j :: roundItems (j + 1) ms

/-- **The verifier's items** for the statement `x` and the messages `ms`. -/
def pItems (x : X) (ms : List M) : List (PItem X M) := .stmt x :: roundItems 0 ms

theorem roundItems_length : ∀ (j : ℕ) (ms : List M), (roundItems (X := X) j ms).length = 2 * ms.length
  | _, [] => rfl
  | j, m :: ms => by
    rw [roundItems, List.length_cons, List.length_cons, roundItems_length (j + 1) ms, List.length_cons]
    ring

/-! ## Reading a chain back as a protocol transcript -/

/-- One step of the reader: a message is held until its squeeze; the squeeze of round `|τ|` (below `n`) completes the
round with the challenge `chal d`; anything else leaves the schedule (`none`). -/
def rStep (n : ℕ) (chal : D → Ch) :
    Option (List (M × Ch) × Option M) → PItem X M × D → Option (List (M × Ch) × Option M)
  | some (τ, none), (.msg m, _) => some (τ, some m)
  | some (τ, some m), (.sq j, d) => if j = τ.length ∧ τ.length < n then some (τ ++ [(m, chal d)], none) else none
  | _, _ => none

/-- **The reader** of the items after the statement: the protocol transcript so far and the pending message. -/
def rDecode (n : ℕ) (chal : D → Ch) (τ : List (PItem X M × D)) : Option (List (M × Ch) × Option M) :=
  τ.foldl (rStep n chal) (some ([], none))

theorem rDecode_snoc (n : ℕ) (chal : D → Ch) (τ : List (PItem X M × D)) (e : PItem X M × D) :
    rDecode n chal (τ ++ [e]) = rStep n chal (rDecode n chal τ) e := by
  simp [rDecode, List.foldl_append]

/-- **The reader on the verifier's chain**: from a transcript of `j` rounds, the items of the next rounds (with any
digests) are read as exactly those rounds' messages, with nothing pending. -/
theorem rDecode_rounds (n : ℕ) (chal : D → Ch) :
    ∀ (ms : List M) (j : ℕ) (ptr : List (M × Ch)) (ext : List (PItem X M × D)),
      ext.map Prod.fst = roundItems j ms → ptr.length = j → j + ms.length ≤ n →
      ∃ ptr', ext.foldl (rStep n chal) (some (ptr, none)) = some (ptr', none)
        ∧ ptr'.map Prod.fst = ptr.map Prod.fst ++ ms ∧ ptr'.length = j + ms.length
  | [], j, ptr, ext, hext, hj, _ => by
    have : ext = [] := by simpa [roundItems] using hext
    subst this
    exact ⟨ptr, rfl, by simp, by simp [hj]⟩
  | m :: ms, j, ptr, ext, hext, hj, hn => by
    match ext, hext with
    | [], h => simp [roundItems] at h
    | [_], h => simp [roundItems] at h
    | (a1, d1) :: (a2, d2) :: ext', h =>
      simp only [roundItems, List.map_cons, List.cons.injEq] at h
      obtain ⟨rfl, rfl, hext'⟩ := h
      have hlt : ptr.length < n := by
        rw [List.length_cons] at hn
        omega
      obtain ⟨ptr', h1, h2, h3⟩ := rDecode_rounds n chal ms (j + 1) (ptr ++ [(m, chal d2)]) ext' hext'
        (by rw [List.length_append, List.length_singleton, hj]) (by rw [List.length_cons] at hn; omega)
      refine ⟨ptr', ?_, ?_, ?_⟩
      · rw [List.foldl_cons, List.foldl_cons]
        simp only [rStep, show (j = ptr.length ∧ ptr.length < n) ↔ True from iff_true_intro ⟨hj.symm, hlt⟩,
          ↓reduceIte]
        exact h1
      · rw [h2, List.map_append, List.append_assoc]
        rfl
      · rw [h3, List.length_cons]
        omega

/-! ## The protocol's state function on chains -/

/-- The state read off a decoded chain: the protocol's state of the transcript so far (a pending message does not
change it); a chain out of the schedule is doomed. -/
def liftOf (St : X → List (M × Ch) → Prop) (x : X) : Option (List (M × Ch) × Option M) → Prop
  | some (ptr, _) => St x ptr
  | none => False

/-- **The protocol's state function on chains**: the chain must start with the statement; then the protocol's
state of the transcript read off the rest. -/
def liftSt (n : ℕ) (St : X → List (M × Ch) → Prop) (chal : D → Ch) : List (PItem X M × D) → Prop
  | (.stmt x, _) :: rest => liftOf St x (rDecode n chal rest)
  | _ => False

/-- **The lifted state is round-by-round.** From a doomed chain with its statement, whatever the next item, at most
`e·K` digests lead out of doom: a `msg` item never does, a `sq` item is a protocol round (`e` challenges, `K`
digests each), anything else dooms the chain. -/
theorem liftSt_round [DecidableEq Ch] [Fintype D] {n e : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop}
    {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K) :
    ∀ (τ : List (PItem X M × D)) (it : PItem X M), 1 ≤ τ.length → ¬ liftSt n St chal τ →
      EscapesWithin (fun d : D => liftSt n St chal (τ ++ [(it, d)])) (e * K) := by
  intro τ it hlen hns
  have h0 : ∀ P : D → Prop, (∀ d, ¬ P d) → EscapesWithin P (e * K) :=
    fun P hP => ⟨∅, by simp, fun d hd => absurd hd (hP d)⟩
  rcases τ with _ | ⟨⟨it0, d0⟩, rest⟩
  · simp at hlen
  cases it0 with
  | msg m => exact h0 _ (fun d hd => by simp [liftSt] at hd)
  | sq j => exact h0 _ (fun d hd => by simp [liftSt] at hd)
  | stmt x =>
    have hstep : ∀ d, liftSt n St chal (((PItem.stmt x, d0) :: rest) ++ [(it, d)])
        = liftOf St x (rStep n chal (rDecode n chal rest) (it, d)) := by
      intro d
      rw [List.cons_append, liftSt, rDecode_snoc]
    simp only [hstep]
    simp only [liftSt] at hns
    rcases hrd : rDecode n chal rest with _ | ⟨ptr, pend⟩
    · exact h0 _ (fun d hd => by simp [rStep, liftOf] at hd)
    · rw [hrd] at hns
      simp only [liftOf] at hns
      cases pend with
      | none =>
        cases it with
        | msg m => exact h0 _ (fun d hd => hns (by simpa [rStep, liftOf] using hd))
        | stmt _ => exact h0 _ (fun d hd => by simp [rStep, liftOf] at hd)
        | sq _ => exact h0 _ (fun d hd => by simp [rStep, liftOf] at hd)
      | some m =>
        cases it with
        | sq j =>
          by_cases hj : j = ptr.length ∧ ptr.length < n
          · obtain ⟨B, hB, hmem⟩ := (hR.round x ptr m hj.2 hns).comap chal hK
            refine ⟨B, hB, fun d hd => hmem d ?_⟩
            simp only [rStep, show (j = ptr.length ∧ ptr.length < n) ↔ True from iff_true_intro hj, ↓reduceIte,
              liftOf] at hd
            exact hd
          · exact h0 _ (fun d hd => by simp only [rStep,
            show (j = ptr.length ∧ ptr.length < n) ↔ False from iff_false_intro hj, ↓reduceIte, liftOf] at hd)
        | stmt _ => exact h0 _ (fun d hd => by simp [rStep, liftOf] at hd)
        | msg _ => exact h0 _ (fun d hd => by simp [rStep, liftOf] at hd)

/-! ## Soundness on the chain -/

/-- **The chain verifier**: exactly `n` messages; the chain of the verifier's items is hashed from the start query;
the items after the statement are read back as a transcript of `n` rounds (messages and `chal` of the squeezes'
digests), and the protocol's verifier accepts it. -/
def chainAccepts (n : ℕ) (accept : X → List (M × Ch) → Mf → Prop) (C : ChainEnc (PItem X M) Q D) (chal : D → Ch)
    (H : Q → D) (x : X) (ms : List M) (mf : Mf) : Prop :=
  ms.length = n ∧ ∃ ptr, rDecode n chal ((C.chainFrom H [] (pItems x ms)).drop 1) = some (ptr, none)
    ∧ accept x ptr mf

/-- A chain extended by items is the chain followed by entries for exactly those items. -/
theorem ChainEnc.chainFrom_eq_append {It : Type} (C : ChainEnc It Q D) (H : Q → D) :
    ∀ (its : List It) (τ : List (It × D)), ∃ ext, C.chainFrom H τ its = τ ++ ext ∧ ext.map Prod.fst = its
  | [], τ => ⟨[], by simp [ChainEnc.chainFrom], rfl⟩
  | it :: its, τ => by
    obtain ⟨ext, h1, h2⟩ := ChainEnc.chainFrom_eq_append C H its (τ ++ [(it, H (C.link (C.lastD H τ) it))])
    refine ⟨(it, H (C.link (C.lastD H τ) it)) :: ext, ?_, by simp [h2]⟩
    rw [ChainEnc.chainFrom, h1, List.append_assoc, List.singleton_append]

/-- **Fiat–Shamir soundness of an RBR-sound protocol on the code's chain.** With `e` escaping challenges per round,
`K` digests per challenge value, and a prover making at most `q` hash queries:
`T·e·K/|D| + collBound T D + collBound (T + 1) D`, `T = q + (2n + 1) + 1`. -/
theorem fs_chain_sound_of_rbr [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] [DecidableEq Ch]
    {n e : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop}
    (hR : RbrSound n L accept St e) (C : ChainEnc (PItem X M) Q D) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ chainAccepts n accept C chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + (2 * n + 1) + 1) * (e * K) : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + (2 * n + 1) + 1) D
        + collBound (q + (2 * n + 1) + 1 + 1) D := by
  let A' : OC Q D (List (PItem X M) × (X × List M × Mf)) := A.bind (fun o => .ret (pItems o.1 o.2.1, o))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (pItems o.1 o.2.1, o) : OC Q D _).Bounded 0 from trivial))).mono (by simp)
  have hrun : ∀ H, A'.run H = (pItems (A.run H).1 (A.run H).2.1, A.run H) := fun H => by
    simp only [A', OC.run_bind]
    rfl
  refine le_trans (MeasureTheory.measure_mono ?_)
    (chain_sound C (liftSt n St chal) 1 (e * K) (liftSt_round hR chal K hK) q (2 * n + 1) A' hA')
  rintro H ⟨hL, hlen, ptr, hdec, hacc⟩
  show ¬ liftSt n St chal (C.chainFrom H [] (((A'.run H).1.take (2 * n + 1)).take 1))
    ∧ liftSt n St chal (C.chainFrom H [] ((A'.run H).1.take (2 * n + 1)))
  rw [hrun]
  set x := (A.run H).1
  set ms := (A.run H).2.1
  have htake : (pItems x ms).take (2 * n + 1) = pItems x ms := List.take_of_length_le (by
    rw [pItems, List.length_cons, roundItems_length, hlen])
  rw [htake]
  obtain ⟨ext, hext, hmap⟩ := C.chainFrom_eq_append H (roundItems 0 ms)
    [(PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x)))]
  have hfull : C.chainFrom H [] (pItems x ms) = (PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x))) :: ext := by
    rw [pItems, ChainEnc.chainFrom, List.nil_append, hext, List.singleton_append]
  constructor
  · -- the statement's chain is doomed
    show ¬ liftSt n St chal (C.chainFrom H [] [PItem.stmt x])
    rw [ChainEnc.chainFrom, ChainEnc.chainFrom, List.nil_append, liftSt]
    exact hR.start x hL
  · -- the whole chain is not: the verifier accepts its transcript
    rw [hfull, liftSt]
    rw [hfull, List.drop_one, List.tail_cons] at hdec
    obtain ⟨ptr', h1, -, h3⟩ := rDecode_rounds n chal ms 0 [] ext hmap rfl (by rw [hlen, zero_add])
    have hpp : ptr' = ptr := by
      have : rDecode n chal ext = some (ptr', none) := h1
      rw [hdec] at this
      exact (Prod.mk.inj (Option.some.inj this)).1.symm
    rw [hdec]
    show St x ptr
    by_contra hns
    exact hR.final x ptr _ (by rw [← hpp, h3, hlen, zero_add]) hns hacc

/-! ## The sumcheck on the chain -/

section Sumcheck

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {d : ℕ}
variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **The sumcheck as the code hashes it**: the statement, then each round's message absorbed and one squeeze. With
challenges `chal` of the squeeze digests (at most `K` digests per value) and a prover making at most `q` hash queries,
a false claim is accepted with probability at most `T·d·K/|D| + collBound T D + collBound (T + 1) D`,
`T = q + (2n + 1) + 1`. -/
theorem fs_sumcheck_chain_sound {n : ℕ} (hd : d < ringChar F) (stmt : X → ((Fin n → F) → F) × F)
    (C : ChainEnc (PItem X (Fin (d + 1) → F)) Q D) (chal : D → F) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ chainAccepts n (fun x τ (_ : Unit) => scAccept τ n (stmt x).1 (stmt x).2) C chal H (A.run H).1
            (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + (2 * n + 1) + 1) * (d * K) : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + (2 * n + 1) + 1) D
        + collBound (q + (2 * n + 1) + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_chain_sound_of_rbr (sumcheck_rbr hd stmt) C chal K hK q A hA)
  rintro H ⟨h1, h2, h3⟩
  exact ⟨fun h => h.elim (fun h' => h' h1) h2, h3⟩

/-- **The sumcheck as the code runs it**, with the code's `challenge_fp2` (a 256-bit digest, each 128-bit half reduced
mod `p`): `T·d/|F| · (1 + p/2^128)²` plus the chain's collision and guess terms over `|D| = 2^256`. -/
theorem fs_sumcheck_chain_sound_code {n p : ℕ} [NeZero p] (hd : d < ringChar F) (ι : ZMod p × ZMod p ≃ F)
    (stmt : X → ((Fin n → F) → F) × F)
    (C : ChainEnc (PItem X (Fin (d + 1) → F)) Q (Fin (2 ^ 128) × Fin (2 ^ 128))) (q : ℕ)
    (A : OC Q (Fin (2 ^ 128) × Fin (2 ^ 128)) (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ chainAccepts n (fun x τ (_ : Unit) => scAccept τ n (stmt x).1 (stmt x).2) C (fp2Field p (2 ^ 128) ι) H
            (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + (2 * n + 1) + 1) * d : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (2 * n + 1) + 1) (Fin (2 ^ 128) × Fin (2 ^ 128))
        + collBound (q + (2 * n + 1) + 1 + 1) (Fin (2 ^ 128) × Fin (2 ^ 128)) := by
  have : Nonempty F := ⟨0⟩
  have hF : Fintype.card F = p ^ 2 := by
    rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]
  refine (fs_sumcheck_chain_sound hd stmt C (fp2Field p (2 ^ 128) ι) ((2 ^ 128 / p + 1) ^ 2)
    (card_fp2Field_fiber_le (2 ^ 128) p ι) q A hA).trans ?_
  gcongr
  rw [← mul_assoc, div_card_eq_mul_bias (Ch := F)]
  exact mul_le_mul' le_rfl (biasFactor_fp2_le (2 ^ 128) p hF)

end Sumcheck

end ZK60.Sound
