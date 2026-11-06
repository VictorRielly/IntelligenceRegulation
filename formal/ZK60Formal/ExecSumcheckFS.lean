/-
D63 step L7 (the executable verifier): Fiat–Shamir soundness of the EXECUTABLE sumcheck verifier, end to end.

L5 proved that the code's transcript is `FSChain.lean`'s chain (`chainEnc`, `runOps_chain`) and L6 that the code's
`sumcheck::verify` accepts exactly when `scAccept` holds on the chain's challenges (`scVerify_fs`). `FSChainRbr.lean`'s
bound (`fs_sumcheck_chain_sound_code`) is about a chain of `PItem`s (one statement item, then `msg`, `sq j`, …, with a
natural-number counter `j`), not the code's `TItem`s (finding L6-4). This file closes that gap without a `PItem`
encoding: it states the protocol's state function directly on the code's chain.

**The bridge (`codeSt`).** A code chain transcript is a list of the code's items with their digests. Its first `s`
entries are the header (any operations: absorbs and squeezes, as the caller ran them); the statement is any function
`stmtOf` of those `s` entries (items, counters AND the digests, so a statement may use challenges squeezed in the
header). After the header the reader `cDecode` reads the protocol transcript: an absorb under the round label `lab`
is the round's message (`dec` of its bytes), the next squeeze completes the round with the challenge `chal` of its
digest; anything else leaves the schedule. The squeeze COUNTER is not read: it is hashed (so the chain stays
injective, `decodeLink_msg`), but the reader needs no counter arithmetic. So nothing about the wrapping `u64` counter
is assumed: no `c0 + n < 2^64` premise, no injectivity of a counter map. The state is "not doomed" while the header is
incomplete, then the protocol's state (`liftOf`, as in `FSChainRbr.lean`).

Why this rather than a `ChainEnc` over `PItem`: a `ChainEnc` hashes ONE link per item, while the code's header is
SEVERAL links (each absorb of the public statement, every squeeze before the sumcheck), so the statement cannot be one
`PItem` link; and mapping `sq j` to the code's counter `c0 + j` as a `u64` is not injective over `ℕ`. Reading the
code's own chain (`chainEnc`, already injective) needs neither.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `codeSt_round`: from a doomed code chain of at least `s` entries, whatever the next item, at most `e·K` digests
  escape (an RBR-sound protocol with `e` escaping challenges per round, `K` digests per challenge value);
* `cDecode_rounds`: the verifier's own round items (absorb under `lab`, squeeze, per round, any counters) read back as
  the protocol transcript of the messages and the squeezes' challenges;
* `fs_code_chain_sound`: so `FSChain.lean`'s `chain_sound` applies to the code's chain: `T·e·K/|D| + collBound T D +
  collBound (T + 1) D`, `T = q + ℓ + 1`;
* `chainEncB`, `chainFrom_liftH`: the code's chain on the finite oracle domain `QB L` (L5's framing, `ExecMerkle.lean`),
  equal to L5's chain under `liftH G` for items of at most `L` bytes; `opTrace_chainFrom`: the header's trace (each
  operation's item and the transcript's state after it) is the chain's;
* `card_chal_fiber_le`: every `Fp2` challenge value has at most `(⌊2^128/p⌋ + 1)²` digest preimages under the code's
  `challenge_fp2` (read in any `K ⊇ GF` of degree 2 with `U² = 7`; `halves_injective`, `card_filter_le_of_injective`);
  `card_dig`, `card_of_pairs`, `dig_bound_le`: `|Dig| = 2^256`, `|K| = p²`, and the digest count is the field count
  times `FSChallenge.lean`'s bias;
* `scWin_flip`: a win of the prover (`ScWin`) makes the header's chain doomed and the whole chain alive;
* **`exec_sumcheck_fs_sound`**: for ANY header of `s` operations chosen by the prover, a prover making at most `q`
  queries to a random oracle on `QB L` outputs a header, a false claim (`C ≠ Σ f`, `f` of individual degree `≤ d`, both
  functions of the header's trace) and round messages that the EXECUTABLE `scVerify`, started from the code's
  transcript after the header, accepts with the caller's terminal check `fin = f(rs)`, with probability at most
  `T·d/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)` over `|Dig| = 2^256`, `T = q + (s + 2n) + 1`;
* `exec_sumcheck_fs_sound_goldilocks`: the same with `|K| = p²` and the bias `(1 + 2^-64)²`;
  `slot_bound_le`, `exec_sumcheck_fs_sound_slot`: at `d ≤ 4` and `T ≤ 2^64 + 2^20` (e.g. `q = 2^64`, `n = 30`, a
  header of up to `2^20 − 61` operations) the bound is at most `2^-61` (`natFrac_le`, `natFrac_mul`: the arithmetic).

How the proof avoids enumerating concrete sets: every fact about a `Finset.univ` of a concrete huge type (`Dig`,
`Fin (2^128) × Fin (2^128)`) and every step on the literal `p` is proved for abstract types or a variable `p` first
(`card_filter_le_of_injective`, `card_of_pairs`, `dig_bound_le`, `slot_bound_le`) and then instantiated; the direct
proofs on the concrete types ran the elaborator into its recursion limit or past 24 GiB.

What the per-profile instance must discharge (the theorem's premises and the event's conjuncts): the start premise
`decodeLink (startMsg domain) = none` (L5-3, a `decide` per profile string); `L` with every hash input of the header at
most `L` bytes, `|startMsg domain| ≤ L`, `56 + 16(d + 1) ≤ L` (a round's absorb) and `L < 2^64` (L5-4; the receipt
decoder bounds sizes); `1 ≤ d < p` (L6-1); `K` of degree 2 over `GF` with `U² = 7`; a fixed header length `s` (the
profile's schedule); canonical round values and claimed sum (L5-2); and that the claimed sum and the polynomial are
functions of the header's trace (the arithmetization and the extraction: the polynomial is the committed tables').
-/
import ZK60Formal.ExecSumcheck
import ZK60Formal.ExecMerkle

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Finset

/-! ## Reading the code's chain back as a protocol transcript -/

section Reader

variable {D M Ch : Type}

/-- One step of the reader on the code's items after the header: an absorb under `lab` is the round's message (`dec` of
its bytes), held until the round's squeeze; a squeeze completes the round (fewer than `n` so far) with the challenge
`chal` of its digest. The squeeze's counter is not read. Anything else leaves the schedule (`none`). -/
def cStep (n : ℕ) (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch) :
    Option (List (M × Ch) × Option M) → TItem × D → Option (List (M × Ch) × Option M)
  | some (τ, none), (.absorb l x, _) => if l = lab then some (τ, some (dec x)) else none
  | some (τ, some m), (.squeeze _, dg) => if τ.length < n then some (τ ++ [(m, chal dg)], none) else none
  | _, _ => none

/-- **The reader** of the entries after the header: the protocol transcript so far and the pending message. -/
def cDecode (n : ℕ) (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch) (τ : List (TItem × D)) :
    Option (List (M × Ch) × Option M) :=
  τ.foldl (cStep n lab dec chal) (some ([], none))

theorem cDecode_snoc (n : ℕ) (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch) (τ : List (TItem × D))
    (e : TItem × D) : cDecode n lab dec chal (τ ++ [e]) = cStep n lab dec chal (cDecode n lab dec chal τ) e := by
  simp [cDecode, List.foldl_append]

/-- **The protocol's state on the code's chain**, with a header of `s` entries: not doomed while the header is
incomplete; then the protocol's state `St` of the statement `stmtOf` of the header and the transcript read off the
rest (`FSChainRbr.lean`'s `liftOf`: a pending message does not change it, a chain out of the schedule is doomed). -/
def codeSt {X : Type} (s n : ℕ) (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch)
    (stmtOf : List (TItem × D) → X) (St : X → List (M × Ch) → Prop) (τ : List (TItem × D)) : Prop :=
  τ.length < s ∨ liftOf St (stmtOf (τ.take s)) (cDecode n lab dec chal (τ.drop s))

/-- **The code-chain state is round-by-round.** From a doomed chain of at least `s` entries, whatever the next item,
at most `e·K` digests lead out of doom: an absorb never does, a squeeze completing a round is the protocol round (`e`
challenges, `K` digests each), anything else dooms the chain. -/
theorem codeSt_round [DecidableEq Ch] [Fintype D] {X Mf : Type} {s n e : ℕ} {Lg : X → Prop}
    {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop} (hR : RbrSound n Lg accept St e)
    (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K) (stmtOf : List (TItem × D) → X) :
    ∀ (τ : List (TItem × D)) (it : TItem), s ≤ τ.length → ¬ codeSt s n lab dec chal stmtOf St τ →
      EscapesWithin (fun dg : D => codeSt s n lab dec chal stmtOf St (τ ++ [(it, dg)])) (e * K) := by
  intro τ it hs hns
  have h0 : ∀ P : D → Prop, (∀ d, ¬ P d) → EscapesWithin P (e * K) :=
    fun P hP => ⟨∅, by simp, fun d hd => absurd hd (hP d)⟩
  have hfun : (fun dg : D => codeSt s n lab dec chal stmtOf St (τ ++ [(it, dg)]))
      = fun dg => liftOf St (stmtOf (τ.take s))
          (cStep n lab dec chal (cDecode n lab dec chal (τ.drop s)) (it, dg)) := by
    funext dg
    unfold codeSt
    rw [List.take_append_of_le_length hs, List.drop_append_of_le_length hs, cDecode_snoc, List.length_append,
      List.length_singleton]
    exact propext ⟨fun h => h.resolve_left (by omega), Or.inr⟩
  rw [hfun]
  have hns' : ¬ liftOf St (stmtOf (τ.take s)) (cDecode n lab dec chal (τ.drop s)) := fun h => hns (Or.inr h)
  rcases hrd : cDecode n lab dec chal (τ.drop s) with _ | ⟨ptr, pend⟩
  · exact h0 _ (fun d hd => by simp [cStep, liftOf] at hd)
  · rw [hrd] at hns'
    simp only [liftOf] at hns'
    cases pend with
    | none =>
      cases it with
      | absorb l x =>
        by_cases hl : l = lab
        · exact h0 _ (fun d hd => hns' (by simpa [cStep, hl, liftOf] using hd))
        · exact h0 _ (fun d hd => by simp [cStep, hl, liftOf] at hd)
      | squeeze c => exact h0 _ (fun d hd => by simp [cStep, liftOf] at hd)
    | some m =>
      cases it with
      | absorb l x => exact h0 _ (fun d hd => by simp [cStep, liftOf] at hd)
      | squeeze c =>
        by_cases hn : ptr.length < n
        · obtain ⟨B, hB, hmem⟩ := (hR.round (stmtOf (τ.take s)) ptr m hn hns').comap chal hK
          refine ⟨B, hB, fun d hd => hmem d ?_⟩
          simpa [cStep, hn, liftOf] using hd
        · exact h0 _ (fun d hd => by simp [cStep, hn, liftOf] at hd)

/-- The verifier's operations for the messages `ms` (encoded by `enc`): per round, the absorb under `lab`, then one
squeeze. -/
def rdOps (lab : List UInt8) {M' : Type} (enc : M' → List UInt8) (ms : List M') : List Op :=
  ms.flatMap (fun m => [Op.absorb lab (enc m), Op.squeeze])

/-- The digests of the squeeze entries of a code chain transcript, in order. -/
def sqD (l : List (TItem × D)) : List D :=
  l.filterMap (fun e => match e.1 with
    | .squeeze _ => some e.2
    | .absorb _ _ => none)

/-- **The reader on the verifier's own rounds**: from a transcript `ptr` with nothing pending, the items of the round
operations (with the code's counters from any `c`, and any digests) read as exactly those rounds: the messages `dec`
of their bytes, the challenges `chal` of the squeezes' digests. -/
theorem cDecode_rounds (n : ℕ) (lab : List UInt8) {M' : Type} (enc : M' → List UInt8) (dec : List UInt8 → M)
    (chal : D → Ch) :
    ∀ (ms : List M') (c : UInt64) (ptr : List (M × Ch)) (ext : List (TItem × D)),
      ext.map Prod.fst = opItems c (rdOps lab enc ms) → ptr.length + ms.length ≤ n →
      ext.foldl (cStep n lab dec chal) (some (ptr, none))
        = some (ptr ++ (ms.map (fun m => dec (enc m))).zip ((sqD ext).map chal), none)
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
      have ih := cDecode_rounds n lab enc dec chal ms (c + 1) (ptr ++ [(dec (enc m), chal d2)]) ext' hext'
        (by rw [List.length_append, List.length_singleton]; rw [List.length_cons] at hn; omega)
      have e1 : cStep n lab dec chal (some (ptr, none)) (TItem.absorb lab (enc m), d1)
          = some (ptr, some (dec (enc m))) := by simp [cStep]
      have e2 : cStep n lab dec chal (some (ptr, some (dec (enc m)))) (TItem.squeeze c, d2)
          = some (ptr ++ [(dec (enc m), chal d2)], none) := by simp [cStep, hlt]
      rw [List.foldl_cons, List.foldl_cons, e1, e2, ih]
      simp [sqD]

end Reader

/-! ## Soundness on the code's chain -/

section ChainSound

variable {D M Ch : Type} {It' Q : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **Fiat–Shamir soundness of an RBR-sound protocol on the code's chain**, after a header of `s` items. `C` is any
chain encoding whose items read as the code's (`toT`), e.g. L5's `chainEnc` or `chainEncB` below. A prover making at
most `q` hash queries outputs items; the verifier hashes the first `ℓ`. The probability that the chain of the header is
doomed while the whole chain is not is at most `T·e·K/|D| + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. -/
theorem fs_code_chain_sound [DecidableEq Ch] {X Mf : Type} {n e : ℕ} {Lg : X → Prop}
    {accept : X → List (M × Ch) → Mf → Prop} {St : X → List (M × Ch) → Prop} (hR : RbrSound n Lg accept St e)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (lab : List UInt8) (dec : List UInt8 → M) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K) (stmtOf : List (TItem × D) → X) (s : ℕ)
    {α : Type} (q ℓ : ℕ) (A : OC Q D (List It' × α)) (hA : A.Bounded q) :
    prH (fun H => ¬ codeSt s n lab dec chal stmtOf St
          ((C.chainFrom H [] (((A.run H).1.take ℓ).take s)).map (fun p => (toT p.1, p.2)))
        ∧ codeSt s n lab dec chal stmtOf St ((C.chainFrom H [] ((A.run H).1.take ℓ)).map (fun p => (toT p.1, p.2))))
      ≤ (((q + ℓ + 1) * (e * K) : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + ℓ + 1) D
        + collBound (q + ℓ + 1 + 1) D :=
  chain_sound C (fun τ => codeSt s n lab dec chal stmtOf St (τ.map (fun p => (toT p.1, p.2)))) s (e * K)
    (fun τ it hs hns => by
      have h := codeSt_round hR lab dec chal K hK stmtOf (τ.map (fun p => (toT p.1, p.2))) (toT it)
        (by rwa [List.length_map]) hns
      simpa only [List.map_append, List.map_cons, List.map_nil] using h)
    q ℓ A hA

end ChainSound

/-! ## The code's operations: counters, lengths, the header's trace -/

/-- The squeeze counter after the operations, from `c`. -/
def opsCtr : UInt64 → List Op → UInt64
  | c, [] => c
  | c, .absorb _ _ :: ops => opsCtr c ops
  | c, .squeeze :: ops => opsCtr (c + 1) ops

theorem opItems_append : ∀ (c : UInt64) (ops₁ ops₂ : List Op),
    opItems c (ops₁ ++ ops₂) = opItems c ops₁ ++ opItems (opsCtr c ops₁) ops₂
  | _, [], _ => rfl
  | c, .absorb l x :: ops₁, ops₂ => by
    simp only [List.cons_append, opItems, opsCtr]
    rw [opItems_append c ops₁ ops₂]
  | c, .squeeze :: ops₁, ops₂ => by
    simp only [List.cons_append, opItems, opsCtr]
    rw [opItems_append (c + 1) ops₁ ops₂]

theorem opItems_length : ∀ (c : UInt64) (ops : List Op), (opItems c ops).length = ops.length
  | _, [] => rfl
  | c, .absorb _ _ :: ops => by simp only [opItems, List.length_cons, opItems_length c ops]
  | c, .squeeze :: ops => by simp only [opItems, List.length_cons, opItems_length (c + 1) ops]

theorem runOps_counter (H : HIn → Dig) : ∀ (ops : List Op) (t : Tr), (runOps H t ops).counter = opsCtr t.counter ops
  | [], _ => rfl
  | .absorb l x :: ops, t => runOps_counter H ops (t.absorb H l x)
  | .squeeze :: ops, t => runOps_counter H ops (t.squeeze H).2

/-- The number of bytes of an item's hash input: an absorb's `32 + 8 + |label| + 8 + |data|`, a squeeze's
`32 + 7 + 8`. -/
def TItem.len : TItem → ℕ
  | .absorb l x => 48 + l.length + x.length
  | .squeeze _ => 47

/-- The number of bytes an operation hashes (its item's). -/
def Op.len : Op → ℕ
  | .absorb l x => 48 + l.length + x.length
  | .squeeze => 47

theorem TItem.msg_length (dg : Dig) : ∀ it : TItem, (it.msg dg).length = it.len
  | .absorb l x => by
    simp only [TItem.msg, absorbMsg, TItem.len, List.length_append, length_le64, List.Vector.toList_length]
    omega
  | .squeeze c => by
    simp only [TItem.msg, squeezeMsg, TItem.len, List.length_append, length_le64, squeezeTag_length,
      List.Vector.toList_length]

/-- Operations of at most `L < 2^64` bytes give items the code hashes unambiguously, of at most `L` bytes. -/
theorem opItems_fit (L : ℕ) (hL : L < 2 ^ 64) : ∀ (c : UInt64) (ops : List Op), (∀ op ∈ ops, op.len ≤ L) →
    ∀ it ∈ opItems c ops, it.Ok ∧ it.len ≤ L
  | _, [], _ => by simp [opItems]
  | c, .absorb l x :: ops, h => by
    intro it hit
    simp only [opItems, List.mem_cons] at hit
    rcases hit with rfl | hit
    · have h1 := h _ List.mem_cons_self
      simp only [Op.len] at h1
      refine ⟨⟨by omega, by omega⟩, ?_⟩
      simp only [TItem.len]
      omega
    · exact opItems_fit L hL c ops (fun op hop => h op (List.mem_cons_of_mem _ hop)) it hit
  | c, .squeeze :: ops, h => by
    intro it hit
    simp only [opItems, List.mem_cons] at hit
    rcases hit with rfl | hit
    · have h1 := h _ List.mem_cons_self
      simp only [Op.len] at h1
      exact ⟨trivial, by simp only [TItem.len]; omega⟩
    · exact opItems_fit L hL (c + 1) ops (fun op hop => h op (List.mem_cons_of_mem _ hop)) it hit

/-- **The header's trace**: each operation's chain item (with the code's counter) and the transcript's state after
it, as the executable transcript computes them. -/
def opTrace (H : HIn → Dig) : Tr → List Op → List (TItem × Dig)
  | _, [] => []
  | t, .absorb l x :: ops => (.absorb l x, (t.absorb H l x).state) :: opTrace H (t.absorb H l x) ops
  | t, .squeeze :: ops => (.squeeze t.counter, (t.squeeze H).1) :: opTrace H (t.squeeze H).2 ops

/-- An entry of L5's chain as a plain code item with its digest. -/
def entT (p : It × Dig) : TItem × Dig := (p.1.1, p.2)

/-- **The header's trace is the chain's**, from any point: for every hash function, the trace of the operations
after `τ` is the chain's entries after `τ`. -/
theorem opTrace_chainFrom (H : HIn → Dig) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) :
    ∀ (ops : List Op) (t : Tr) (τ : List (It × Dig)) (its : List It), t.key = key →
      (chainEnc key domain hs).lastD H τ = t.state → its.map Subtype.val = opItems t.counter ops →
      opTrace H t ops = (((chainEnc key domain hs).chainFrom H τ its).drop τ.length).map entT
  | [], t, τ, its, _, _, hits => by
    have : its = [] := List.map_eq_nil_iff.mp hits
    subst this
    simp [opTrace, ChainEnc.chainFrom]
  | .absorb l x :: ops, t, τ, its, hk, hτ, hits => by
    cases its with
    | nil => simp [opItems] at hits
    | cons it its =>
      simp only [List.map_cons, opItems, List.cons.injEq] at hits
      have hd : H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it) = (t.absorb H l x).state := by
        show H ⟨key, it.1.msg ((chainEnc key domain hs).lastD H τ)⟩ = H ⟨t.key, absorbMsg t.state l x⟩
        rw [hits.1, hτ, hk]
        rfl
      have ih := opTrace_chainFrom H key domain hs ops (t.absorb H l x)
        (τ ++ [(it, H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it))]) its hk
        (by rw [ChainEnc.lastD_snoc]; exact hd) hits.2
      obtain ⟨ext, hext, -⟩ := (chainEnc key domain hs).chainFrom_eq_append H its
        (τ ++ [(it, H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it))])
      rw [hext, List.drop_left' rfl] at ih
      rw [opTrace, ChainEnc.chainFrom, hext, List.append_assoc, List.drop_left' rfl, List.singleton_append,
        List.map_cons, ih, hd]
      simp only [entT, hits.1]
  | .squeeze :: ops, t, τ, its, hk, hτ, hits => by
    cases its with
    | nil => simp [opItems] at hits
    | cons it its =>
      simp only [List.map_cons, opItems, List.cons.injEq] at hits
      have hd : H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it) = (t.squeeze H).1 := by
        show H ⟨key, it.1.msg ((chainEnc key domain hs).lastD H τ)⟩ = H ⟨t.key, squeezeMsg t.state t.counter⟩
        rw [hits.1, hτ, hk]
        rfl
      have ih := opTrace_chainFrom H key domain hs ops (t.squeeze H).2
        (τ ++ [(it, H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it))]) its hk
        (by rw [ChainEnc.lastD_snoc]; exact hd) hits.2
      obtain ⟨ext, hext, -⟩ := (chainEnc key domain hs).chainFrom_eq_append H its
        (τ ++ [(it, H ((chainEnc key domain hs).link ((chainEnc key domain hs).lastD H τ) it))])
      rw [hext, List.drop_left' rfl] at ih
      rw [opTrace, ChainEnc.chainFrom, hext, List.append_assoc, List.drop_left' rfl, List.singleton_append,
        List.map_cons, ih, hd]
      simp only [entT, hits.1]

/-- L6's squeeze digests are the plain reader's. -/
theorem sqDigests_eq (l : List (It × Dig)) : sqDigests l = sqD (l.map entT) := by
  unfold sqDigests sqD
  rw [List.filterMap_map]
  rfl

/-! ## The code's chain on the finite oracle domain `QB L` -/

/-- The items the code hashes unambiguously whose hash input has at most `L` bytes. -/
abbrev ItB (L : ℕ) := {it : TItem // it.Ok ∧ it.len ≤ L}

/-- An item of `ItB L` as one of L5's `It`. -/
def ItB.toIt {L : ℕ} (it : ItB L) : It := ⟨it.1, it.2.1⟩

/-- An entry over `ItB L` as one over `It`. -/
def entIt {L : ℕ} (p : ItB L × Dig) : It × Dig := (p.1.toIt, p.2)

/-- An entry over `ItB L` as a plain code item with its digest. -/
def entB {L : ℕ} (p : ItB L × Dig) : TItem × Dig := (p.1.1, p.2)

/-- **The code's transcript as a `ChainEnc` on `QB L`**: L5's encoding (`chainEnc`) restricted to the items of at most
`L` bytes, for one mode (`key`) and one domain string with the start premise. -/
def chainEncB (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (L : ℕ)
    (hL : (startMsg domain).length ≤ L) : ChainEnc (ItB L) (QB L) Dig where
  start := (key, ⟨startMsg domain, hL⟩)
  link dg it := (key, ⟨it.1.msg dg, (TItem.msg_length dg it.1).trans_le it.2.2⟩)
  ldec y :=
    if y.1 = key then
      match decodeLink y.2.1 with
      | none => none
      | some p => if h : p.2.1.len ≤ L then some (p.1, ⟨p.2.1, p.2.2, h⟩) else none
    else none
  ldec_link dg it := by
    have h := decodeLink_msg dg it.toIt
    simp only [ItB.toIt] at h
    simp [h, it.2.2]
  ldec_start := by simp [hs]

section Lift

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (L : ℕ)
  (hL : (startMsg domain).length ≤ L) (G : QB L → Dig)

theorem lastD_liftH (τ : List (ItB L × Dig)) :
    (chainEnc key domain hs).lastD (liftH G) (τ.map entIt) = (chainEncB key domain hs L hL).lastD G τ := by
  unfold ChainEnc.lastD
  rw [List.getLast?_map, Option.map_map]
  have hst : liftH G (chainEnc key domain hs).start = G (chainEncB key domain hs L hL).start :=
    liftH_eq G key (startMsg domain) hL
  rw [hst]
  rfl

/-- **The two chains agree**: under `liftH G` (the oracle on `QB L` as a hash function), L5's chain of the items of
`ItB L` is `chainEncB`'s chain under `G`. -/
theorem chainFrom_liftH : ∀ (its : List (ItB L)) (τ : List (ItB L × Dig)),
    (chainEnc key domain hs).chainFrom (liftH G) (τ.map entIt) (its.map ItB.toIt)
      = ((chainEncB key domain hs L hL).chainFrom G τ its).map entIt
  | [], _ => rfl
  | it :: its, τ => by
    rw [List.map_cons, ChainEnc.chainFrom, ChainEnc.chainFrom, lastD_liftH key domain hs L hL G τ]
    have hq : liftH G ((chainEnc key domain hs).link ((chainEncB key domain hs L hL).lastD G τ) it.toIt)
        = G ((chainEncB key domain hs L hL).link ((chainEncB key domain hs L hL).lastD G τ) it) :=
      liftH_eq G key _ ((TItem.msg_length _ it.1).trans_le it.2.2)
    rw [hq, ← chainFrom_liftH its
      (τ ++ [(it, G ((chainEncB key domain hs L hL).link ((chainEncB key domain hs L hL).lastD G τ) it))]),
      List.map_append]
    rfl

end Lift

/-- Lift the items of at most `L` bytes (the first that does not fit ends the list). -/
noncomputable def liftItems (L : ℕ) : List TItem → List (ItB L)
  | [] => []
  | it :: its =>
    haveI := Classical.propDecidable (it.Ok ∧ it.len ≤ L)
    if h : it.Ok ∧ it.len ≤ L then ⟨it, h⟩ :: liftItems L its else []

theorem liftItems_val (L : ℕ) : ∀ its : List TItem, (∀ it ∈ its, it.Ok ∧ it.len ≤ L) →
    (liftItems L its).map Subtype.val = its
  | [], _ => rfl
  | it :: its, h => by
    rw [liftItems, dite_eq_left (h it List.mem_cons_self), List.map_cons,
      liftItems_val L its (fun i hi => h i (List.mem_cons_of_mem _ hi))]

theorem liftItems_append (L : ℕ) : ∀ (a b : List TItem), (∀ it ∈ a, it.Ok ∧ it.len ≤ L) →
    liftItems L (a ++ b) = liftItems L a ++ liftItems L b
  | [], _, _ => rfl
  | it :: a, b, h => by
    rw [List.cons_append, liftItems, liftItems, dite_eq_left (h it List.mem_cons_self), dite_eq_left (h it List.mem_cons_self),
      liftItems_append L a b (fun i hi => h i (List.mem_cons_of_mem _ hi)), List.cons_append]

/-! ## The round message and the challenge -/

theorem Fp2.toBytes_length (a : Fp2) : a.toBytes.length = 16 := by
  simp [Fp2.toBytes, Fp.toBytes, le64_length]

theorem flatMap_toBytes_length : ∀ s : List Fp2, (s.flatMap Fp2.toBytes).length = 16 * s.length
  | [] => rfl
  | a :: s => by
    rw [List.flatMap_cons, List.length_append, Fp2.toBytes_length, flatMap_toBytes_length s, List.length_cons]
    ring

theorem drop_flatMap_toBytes : ∀ (s : List Fp2) (i : ℕ),
    (s.flatMap Fp2.toBytes).drop (16 * i) = (s.drop i).flatMap Fp2.toBytes
  | [], i => by simp
  | _ :: _, 0 => by simp
  | a :: s, i + 1 => by
    rw [List.flatMap_cons, show 16 * (i + 1) = 16 + 16 * i by ring, ← List.drop_drop,
      List.drop_left' (Fp2.toBytes_length a), drop_flatMap_toBytes s i, List.drop_succ_cons]

theorem Fp2.fromBytes_append (b r : List UInt8) (hb : b.length = 16) : Fp2.fromBytes (b ++ r) = Fp2.fromBytes b := by
  unfold Fp2.fromBytes
  rw [List.take_append_of_le_length (by omega), List.drop_append_of_le_length (by omega),
    List.take_append_of_le_length (by simp [hb])]

/-- **The round message read off an absorb's bytes**: value `i` is `Fp2::from_bytes` of the `i`-th 16-byte word. -/
def decMsg {K : Type} [Field K] [Algebra GF K] (U : K) (d : ℕ) (b : List UInt8) : Fin (d + 1) → K :=
  fun i => (Fp2.fromBytes (b.drop (16 * (i : ℕ)))).toK U

/-- On the bytes the verifier absorbs (`absorb_fp2` of `d + 1` canonical values), the reader's message is the round
message `scTau` reads (`msgK`). -/
theorem decMsg_enc {K : Type} [Field K] [Algebra GF K] (U : K) (d : ℕ) (s : List Fp2) (hs : ∀ a ∈ s, a.Canon)
    (hl : s.length = d + 1) : decMsg U d (s.flatMap Fp2.toBytes) = msgK U d s := by
  funext i
  have hi : (i : ℕ) < s.length := by rw [hl]; exact i.isLt
  unfold decMsg msgK
  rw [drop_flatMap_toBytes, List.drop_eq_getElem_cons hi, List.flatMap_cons,
    Fp2.fromBytes_append _ _ (Fp2.toBytes_length _), Fp2.fromBytes_toBytes _ (hs _ (List.getElem_mem hi)),
    getD_eq_get s i Fp2.zero hi]

/-- A digest's two 128-bit halves, little-endian (`FSChallenge.lean`'s reading of a 256-bit digest). -/
def halves (dg : Dig) : Fin (2 ^ 128) × Fin (2 ^ 128) :=
  (⟨leNat (dg.toList.take 16), leNat_take16_lt dg⟩, ⟨leNat (dg.toList.drop 16), leNat_drop16_lt dg⟩)

theorem leNat_inj : ∀ (a b : List UInt8), a.length = b.length → leNat a = leNat b → a = b
  | [], [], _, _ => rfl
  | [], _ :: _, h, _ => by simp at h
  | _ :: _, [], h, _ => by simp at h
  | x :: a, y :: b, h, he => by
    simp only [leNat] at he
    have hx := x.toNat_lt
    have hy := y.toNat_lt
    have h1 : x.toNat = y.toNat := by omega
    have h2 : leNat a = leNat b := by omega
    rw [UInt8.toNat_inj.mp h1, leNat_inj a b (by simpa using h) h2]

theorem halves_injective : Function.Injective halves := by
  intro a b h
  simp only [halves, Prod.mk.injEq, Fin.mk.injEq] at h
  have h1 := leNat_inj _ _ (by simp) h.1
  have h2 := leNat_inj _ _ (by simp) h.2
  apply List.Vector.toList_injective
  rw [← List.take_append_drop 16 a.toList, ← List.take_append_drop 16 b.toList, h1, h2]

/-- `challenge_fp2` read in `K` is `FSChallenge.lean`'s `fp2Field` of the digest's halves, for the field reading `ι`. -/
theorem challengeFp2Of_toK {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (dg : Dig) :
    (challengeFp2Of dg).toK U = fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) (halves dg) := by
  unfold Fp2.toK fp2Field
  rw [Equiv.ofBijective_apply]
  congr 1
  exact challengeFp2Of_toGF dg

/-- An injection `g` with `P a → Q (g a)` has at most as many points of `P` as there are points of `Q` (stated for
abstract finite types, so that nothing enumerates a concrete `univ`). -/
theorem card_filter_le_of_injective {α β : Type} [Fintype α] [Fintype β] (g : α → β) (hg : Function.Injective g)
    (P : α → Prop) (Q : β → Prop) [DecidablePred P] [DecidablePred Q] (hPQ : ∀ a, P a → Q (g a)) :
    (univ.filter P).card ≤ (univ.filter Q).card := by
  classical
  calc (univ.filter P).card = ((univ.filter P).image g).card := (Finset.card_image_of_injective _ hg).symm
    _ ≤ (univ.filter Q).card := by
        apply Finset.card_le_card
        intro b hb
        obtain ⟨a, ha, rfl⟩ := Finset.mem_image.mp hb
        exact Finset.mem_filter.mpr ⟨Finset.mem_univ _, hPQ a (Finset.mem_filter.mp ha).2⟩

/-- **Every challenge value has at most `(⌊2^128/p⌋ + 1)²` digest preimages** under the code's `challenge_fp2`. -/
theorem card_chal_fiber_le {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (c : K) :
    (univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U = c)).card ≤ (2 ^ 128 / gP + 1) ^ 2 := by
  have h := card_fp2Field_fiber_le (2 ^ 128) gP (Equiv.ofBijective _ hbij) c
  refine le_trans (card_filter_le_of_injective halves halves_injective
    (fun dg : Dig => (challengeFp2Of dg).toK U = c)
    (fun v : Fin (2 ^ 128) × Fin (2 ^ 128) => fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) v = c)
    (fun dg hdg => by
      show fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) (halves dg) = c
      rw [← challengeFp2Of_toK U hbij dg]
      exact hdg)) h

/-- A field read bijectively from the pairs mod `p` has `p²` elements. -/
theorem card_of_pairs {K : Type} [Fintype K] (p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ K) :
    Fintype.card K = p ^ 2 := by
  rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]

theorem card_dig : Fintype.card Dig = Fintype.card (Fin (2 ^ 128) × Fin (2 ^ 128)) := by
  rw [card_vector, Fintype.card_prod, Fintype.card_fin, Fintype.card_congr (FinEnum.equiv (α := UInt8)),
    Fintype.card_fin]
  show (2 ^ 8) ^ 32 = 2 ^ 128 * 2 ^ 128
  norm_num

/-- **The digest count is the field count times the bias of `challenge_fp2`**: over `|Dig| = 2^256`, `a·(⌊2^128/p⌋+1)²`
digests are at most `a/|K| · (1 + p/2^128)²` (`FSChallenge.lean`'s `biasFactor_fp2_le`). -/
theorem dig_bound_le {K : Type} [Fintype K] [Nonempty K] (p : ℕ) [NeZero p] (hF : Fintype.card K = p ^ 2) (a : ℕ) :
    ((a * (2 ^ 128 / p + 1) ^ 2 : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ≤ (a : ℝ≥0∞) / Fintype.card K * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 := by
  rw [div_card_eq_mul_bias (Ch := K)]
  refine mul_le_mul' le_rfl ?_
  have hb : biasFactor ((2 ^ 128 / p + 1) ^ 2) K Dig
      = biasFactor ((2 ^ 128 / p + 1) ^ 2) K (Fin (2 ^ 128) × Fin (2 ^ 128)) := by
    unfold biasFactor
    rw [card_dig]
  rw [hb]
  exact biasFactor_fp2_le (2 ^ 128) p hF

/-! ## The sumcheck rounds -/

theorem scOps_length : ∀ rounds : List (List Fp2), (scOps rounds).length = 2 * rounds.length
  | [] => rfl
  | r :: rounds => by
    have h := scOps_length rounds
    simp only [scOps, List.flatMap_cons, List.length_append, List.length_cons, List.length_nil] at h ⊢
    omega

theorem scLabel_length : scLabel.length = 8 := rfl

/-- A round's absorb (`d + 1` values) and its squeeze fit in `L` bytes. -/
theorem scOps_len (L d : ℕ) (hLr : 56 + 16 * (d + 1) ≤ L) (rounds : List (List Fp2))
    (hls : ∀ r ∈ rounds, r.length = d + 1) : ∀ op ∈ scOps rounds, op.len ≤ L := by
  intro op hop
  simp only [scOps, List.mem_flatMap, List.mem_cons, List.not_mem_nil, or_false] at hop
  obtain ⟨r, hr, rfl | rfl⟩ := hop
  · simp only [Op.len, scLabel_length, flatMap_toBytes_length, hls r hr]
    omega
  · simp only [Op.len]
    omega

/-- The list transcript of the reader on the verifier's rounds is L6's `scTau`. -/
theorem zip_dec_scTau {K : Type} [Field K] [Algebra GF K] (U : K) (d : ℕ) :
    ∀ (rounds : List (List Fp2)) (ds : List Dig), (∀ r ∈ rounds, (∀ a ∈ r, a.Canon) ∧ r.length = d + 1) →
      (rounds.map (fun r => decMsg U d (r.flatMap Fp2.toBytes))).zip (ds.map (fun dg => (challengeFp2Of dg).toK U))
        = scTau U d rounds (ds.map challengeFp2Of)
  | [], _, _ => by simp [scTau]
  | _ :: _, [], _ => by simp [scTau]
  | r :: rounds, dg :: ds, h => by
    have ih := zip_dec_scTau U d rounds ds (fun r' hr' => h r' (List.mem_cons_of_mem _ hr'))
    have h0 := h r List.mem_cons_self
    simp only [List.map_cons, List.zip_cons_cons, scTau] at ih ⊢
    rw [ih, decMsg_enc U d r h0.1 h0.2]

/-! ## The executable sumcheck under Fiat–Shamir -/

/-- The sumcheck's state function (`sumcheck_rbr`'s) for the statement `stmt` of the header's trace, the claim read
in `K`. -/
def scSt {K : Type} [Field K] [Algebra GF K] (U : K) (d n : ℕ) (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2)
    (x : List (TItem × Dig)) (τ : List ((Fin (d + 1) → K) × K)) : Prop :=
  ¬ IndDegLE d (stmt x).1 ∨ scState τ n (stmt x).1 ((stmt x).2.toK U)

/-- **The prover wins against the executable verifier.** The prover's output `o` is a header (any `s` transcript
operations, each hash input of at most `L` bytes) and round messages (canonical words, as the receipt decoder
enforces). The statement is `stmt` of the header's trace: a polynomial `f` of individual degree `≤ d` and a canonical
claimed sum `C` with `C ≠ Σ f` (a FALSE claim). The executable `sumcheck::verify` (`scVerify`), run on the code's
transcript after the header (`runOps`, from `Transcript::new` / `new_tagged`), returns `Ok (fin, rs)` and the caller's
terminal check `fin = f(rs)` holds. -/
def ScWin {K : Type} [Field K] [Algebra GF K] (U : K) (key : Option Dig) (domain : List UInt8) (L d n s : ℕ)
    (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2) (G : QB L → Dig) (o : List Op × List (List Fp2)) : Prop :=
  o.1.length = s ∧ (∀ op ∈ o.1, op.len ≤ L) ∧ (∀ r ∈ o.2, ∀ a ∈ r, a.Canon)
    ∧ (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).2.Canon
    ∧ IndDegLE d (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).1
    ∧ (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).2.toK U
        ≠ cubeSum (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).1
    ∧ ∃ fin rs, (scVerify (liftH G) (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).2 d n o.2
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).1 = .ok (fin, rs)
        ∧ fin.toK U = (stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) o.1)).1
            (fun i => (rs.getD i Fp2.zero).toK U)

/-- **A win flips the code-chain state**: the chain of the header is doomed (the claim is false) and the whole chain
of the verifier's items is not (the program accepted, so `scAccept` holds on the chain's challenges). -/
theorem scWin_flip {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP)
    (hLr : 56 + 16 * (d + 1) ≤ L) (s : ℕ) (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2)
    (G : QB L → Dig) (o : List Op × List (List Fp2)) (hwin : ScWin U key domain L d n s stmt G o) :
    ¬ codeSt s n scLabel (decMsg U d) (fun dg => (challengeFp2Of dg).toK U) id (scSt U d n stmt)
        (((chainEncB key domain hs L hL).chainFrom G []
          (((liftItems L (opItems 0 (o.1 ++ scOps o.2))).take (s + 2 * n)).take s)).map entB)
      ∧ codeSt s n scLabel (decMsg U d) (fun dg => (challengeFp2Of dg).toK U) id (scSt U d n stmt)
        (((chainEncB key domain hs L hL).chainFrom G []
          ((liftItems L (opItems 0 (o.1 ++ scOps o.2))).take (s + 2 * n))).map entB) := by
  obtain ⟨hdr, rounds⟩ := o
  obtain ⟨hlen, hfit, hrc, hcc, hdeg, hfalse, fin, rs, hok, hterm⟩ := hwin
  dsimp only at hlen hfit hrc hcc hdeg hfalse hok hterm ⊢
  generalize hx : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr = x at hcc hdeg hfalse hok hterm
  -- what the program's acceptance says
  obtain ⟨hls, hrs, hsc⟩ := (scVerify_accept_iff U (liftH G) hU d n hd hdp (stmt x).2 hcc rounds hrc
    (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) (stmt x).1 rs).mp ⟨fin, hok, hterm⟩
  have hn : rounds.length = n := by
    have h1 := scAccept_length _ _ _ _ hsc
    rw [scTau_length, hrs, scChal_length, min_self] at h1
    exact h1
  -- the verifier's items: the header's, then the rounds' (from the counter after the header)
  set c0 := (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr).counter with hc0def
  have hc0 : opsCtr 0 hdr = c0 := (runOps_counter (liftH G) hdr (Tr.newKeyed (liftH G) domain key)).symm
  have hfitH : ∀ it ∈ opItems 0 hdr, it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 hdr hfit
  have hfitR : ∀ it ∈ opItems c0 (scOps rounds), it.Ok ∧ it.len ≤ L :=
    opItems_fit L hL64 c0 (scOps rounds) (scOps_len L d hLr rounds hls)
  have hits : liftItems L (opItems 0 (hdr ++ scOps rounds))
      = liftItems L (opItems 0 hdr) ++ liftItems L (opItems c0 (scOps rounds)) := by
    rw [opItems_append, hc0, liftItems_append L _ _ hfitH]
  have hbH : (liftItems L (opItems 0 hdr)).map Subtype.val = opItems 0 hdr := liftItems_val L _ hfitH
  have hbR : (liftItems L (opItems c0 (scOps rounds))).map Subtype.val = opItems c0 (scOps rounds) :=
    liftItems_val L _ hfitR
  have hlH : (liftItems L (opItems 0 hdr)).length = s := by
    have h := congrArg List.length hbH
    rw [List.length_map, opItems_length, hlen] at h
    exact h
  have hlR : (liftItems L (opItems c0 (scOps rounds))).length = 2 * n := by
    have h := congrArg List.length hbR
    rw [List.length_map, opItems_length, scOps_length, hn] at h
    exact h
  have htk : (liftItems L (opItems 0 hdr) ++ liftItems L (opItems c0 (scOps rounds))).take (s + 2 * n)
      = liftItems L (opItems 0 hdr) ++ liftItems L (opItems c0 (scOps rounds)) :=
    List.take_of_length_le (by rw [List.length_append, hlH, hlR])
  rw [hits, htk, List.take_left' hlH]
  generalize hbHg : liftItems L (opItems 0 hdr) = bH at hbH hlH ⊢
  generalize hbRg : liftItems L (opItems c0 (scOps rounds)) = bR at hbR hlR ⊢
  -- the chains
  set CB := chainEncB key domain hs L hL with hCB
  obtain ⟨ext, hext, hextm⟩ := CB.chainFrom_eq_append G bR (CB.chainFrom G [] bH)
  have hfull : CB.chainFrom G [] (bH ++ bR) = CB.chainFrom G [] bH ++ ext := by
    rw [CB.chainFrom_append, hext]
  have hlCH : (CB.chainFrom G [] bH).length = s := by
    rw [CB.chainFrom_length, List.length_nil, zero_add, hlH]
  have hlCHm : ((CB.chainFrom G [] bH).map entB).length = s := by rw [List.length_map, hlCH]
  -- the header's trace is the chain's
  have h2 := chainFrom_liftH key domain hs L hL G bH []
  rw [List.map_nil] at h2
  have hτ0 : x = (CB.chainFrom G [] bH).map entB := by
    have h1 := opTrace_chainFrom (liftH G) key domain hs hdr (Tr.newKeyed (liftH G) domain key) [] (bH.map ItB.toIt)
      rfl rfl (by rw [List.map_map]; exact hbH)
    rw [← hx, h1, h2, List.length_nil, List.drop_zero, List.map_map]
    rfl
  constructor
  · -- the header's chain is doomed: the claim is false
    unfold codeSt
    rw [List.take_of_length_le hlCHm.le, List.drop_eq_nil_of_le hlCHm.le]
    rintro (h | h)
    · omega
    · simp only [cDecode, List.foldl_nil, liftOf, scSt, scState, id] at h
      rw [← hτ0] at h
      rcases h with h | h
      · exact h hdeg
      · exact hfalse h
  · -- the whole chain is not: the program accepted
    unfold codeSt
    right
    rw [hfull, List.map_append, List.take_left' hlCHm, List.drop_left' hlCHm]
    have hextT : (ext.map entB).map Prod.fst = opItems c0 (rdOps scLabel (fun r => r.flatMap Fp2.toBytes) rounds) := by
      have h : (ext.map entB).map Prod.fst = (ext.map Prod.fst).map Subtype.val := by
        rw [List.map_map, List.map_map]
        rfl
      rw [h, hextm, hbR]
      rfl
    have hdec := cDecode_rounds n scLabel (fun r => r.flatMap Fp2.toBytes) (decMsg U d)
      (fun dg => (challengeFp2Of dg).toK U) rounds c0 [] (ext.map entB) hextT (by rw [List.length_nil, hn]; omega)
    unfold cDecode
    rw [hdec]
    simp only [liftOf, scSt, id, List.nil_append]
    right
    rw [← hτ0]
    apply scAccept_state
    -- the challenges are the chain's (L6's `scVerify_fs`), read through the two chains' agreement
    have hfs := (scVerify_fs (liftH G) U hU key domain hs hdr (bH.map ItB.toIt) (by rw [List.map_map]; exact hbH) d n
      hd hdp (stmt x).2 hcc rounds hrc (bR.map ItB.toIt) (by rw [List.map_map]; exact hbR) (stmt x).1 rs).mp
      ⟨fin, hok, hterm⟩
    obtain ⟨-, hrs2, -⟩ := hfs
    have hsq : rs = (sqD (ext.map entB)).map challengeFp2Of := by
      rw [hrs2, h2, chainFrom_liftH key domain hs L hL G bR (CB.chainFrom G [] bH), hext, List.map_append,
        List.length_map, List.drop_left' (by rw [List.length_map, hlCH, hlH]), sqDigests_eq, List.map_map]
      rfl
    rw [zip_dec_scTau U d rounds (sqD (ext.map entB)) (fun r hr => ⟨hrc r hr, hls r hr⟩), ← hsq]
    exact hsc

/-- **Fiat–Shamir soundness of the EXECUTABLE sumcheck verifier** (D63 step L7). In the random-oracle model on the hash
inputs of at most `L` bytes (`QB L`, L5's framing), a prover making at most `q` queries chooses a header of `s`
transcript operations (anything: the public statement's absorbs, earlier sumchecks, squeezes), a statement that is a
function `stmt` of the header's trace (a polynomial `f` of individual degree `≤ d` and a claimed sum `C ≠ Σ f`), and
round messages. The executable `sumcheck::verify`, run on the code's transcript after the header, accepts with the
caller's terminal check `fin = f(rs)` with probability at most
`T·d/|K| · (1 + p/2^128)² + collBound T + collBound (T + 1)` over `|Dig| = 2^256`, `T = q + (s + 2n) + 1`:
`fs_sumcheck_chain_sound_code`'s bound, now about the program. -/
theorem exec_sumcheck_fs_sound {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (hLr : 56 + 16 * (d + 1) ≤ L)
    (s : ℕ) (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2)
    (q : ℕ) (A : OC (QB L) Dig (List Op × List (List Fp2))) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => ScWin U key domain L d n s stmt G (A.run G))
      ≤ (((q + (s + 2 * n) + 1) * d : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (s + 2 * n) + 1) Dig + collBound (q + (s + 2 * n) + 1 + 1) Dig := by
  have : Nonempty K := ⟨0⟩
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  have hdK : d < ringChar K := by rw [ringChar_eq_gP]; exact hdp
  have hR := sumcheck_rbr hdK (fun x : List (TItem × Dig) => ((stmt x).1, (stmt x).2.toK U))
  let A' : OC (QB L) Dig (List (ItB L) × Unit) :=
    A.bind (fun o => .ret (liftItems L (opItems 0 (o.1 ++ scOps o.2)), ()))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (liftItems L (opItems 0 (o.1 ++ scOps o.2)), ()) :
      OC (QB L) Dig (List (ItB L) × Unit)).Bounded 0 from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = (liftItems L (opItems 0 ((A.run G).1 ++ scOps (A.run G).2)), ()) := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hmain := fs_code_chain_sound hR (chainEncB key domain hs L hL) (fun it => it.1) scLabel (decMsg U d)
    (fun dg => (challengeFp2Of dg).toK U) _ (card_chal_fiber_le U hbij) id s q (s + 2 * n) A' hA'
  refine le_trans (MeasureTheory.measure_mono ?_) (hmain.trans ?_)
  · intro G hwin
    rw [Set.mem_ofPred_eq, hrun G]
    exact scWin_flip U hU key domain hs L hL hL64 d n hd hdp hLr s stmt G (A.run G) hwin
  · refine add_le_add (add_le_add ?_ le_rfl) le_rfl
    rw [← mul_assoc]
    exact dig_bound_le gP hF _

/-! ## At Goldilocks, and at the shape of a slot -/

/-- **At Goldilocks** (`|K| = p²`, `p = 2^64 − 2^32 + 1`): the bound of `exec_sumcheck_fs_sound` with the bias written
as `(1 + 2^-64)²`. -/
theorem exec_sumcheck_fs_sound_goldilocks {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (hLr : 56 + 16 * (d + 1) ≤ L)
    (s : ℕ) (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2)
    (q : ℕ) (A : OC (QB L) Dig (List Op × List (List Fp2))) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => ScWin U key domain L d n s stmt G (A.run G))
      ≤ (((q + (s + 2 * n) + 1) * d : ℕ) : ℝ≥0∞) / ((gP ^ 2 : ℕ) : ℝ≥0∞) * (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2
        + collBound (q + (s + 2 * n) + 1) Dig + collBound (q + (s + 2 * n) + 1 + 1) Dig := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (exec_sumcheck_fs_sound U hU hK2 key domain hs L hL hL64 d n hd hdp hLr s stmt q A hA).trans ?_
  rw [hF]
  exact add_le_add (add_le_add (mul_le_mul' le_rfl (bias_le_two_pow_64 gP (by norm_num))) le_rfl) le_rfl

/-- `a/b ≤ c/e` in `ℝ≥0∞` from the cross-multiplied inequality of naturals. -/
theorem natFrac_le {a b c e : ℕ} (hb : b ≠ 0) (he : e ≠ 0) (h : a * e ≤ c * b) :
    (a : ℝ≥0∞) / b ≤ (c : ℝ≥0∞) / e := by
  have hb' : (b : ℝ≥0∞) ≠ 0 := by exact_mod_cast hb
  have he' : (e : ℝ≥0∞) ≠ 0 := by exact_mod_cast he
  rw [← ENNReal.mul_div_mul_right (a : ℝ≥0∞) b he' (ENNReal.natCast_ne_top e),
    ← ENNReal.mul_div_mul_right (c : ℝ≥0∞) e hb' (ENNReal.natCast_ne_top b), mul_comm (e : ℝ≥0∞) (b : ℝ≥0∞)]
  exact ENNReal.div_le_div_right (by exact_mod_cast h) _

/-- The product of two fractions of naturals. -/
theorem natFrac_mul (a b c e : ℕ) (hb : b ≠ 0) :
    (a : ℝ≥0∞) / b * ((c : ℝ≥0∞) / e) = ((a * c : ℕ) : ℝ≥0∞) / ((b * e : ℕ) : ℝ≥0∞) := by
  rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, Nat.cast_mul, Nat.cast_mul,
    ENNReal.mul_inv (Or.inl (by exact_mod_cast hb)) (Or.inl (ENNReal.natCast_ne_top b))]
  ring

/-- **The numbers at the shape of a slot** (for orientation): with `p` within `2^32` below `2^64` (Goldilocks),
`d ≤ 4` and `T ≤ 2^64 + 2^20`, the bound is at most `2^-61`. (`T·d/p²·(1 + p/2^128)² ≤ 3/2^63`, each collision term
`≤ 2^-126`.) -/
theorem slot_bound_le (p T d : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (hT : T ≤ 2 ^ 64 + 2 ^ 20)
    (hd : d ≤ 4) :
    ((T * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound T Dig + collBound (T + 1) Dig ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hp0 : p ≠ 0 := by
    intro h
    rw [h] at hp2
    norm_num at hp2
  have hN0 : ((2 ^ 128 : ℕ) : ℝ≥0∞) ≠ 0 := by exact_mod_cast (by positivity : (2 ^ 128 : ℕ) ≠ 0)
  have hone : (1 : ℝ≥0∞) + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)
      = ((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 (ENNReal.natCast_ne_top _)]
  have hsq : (((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      = (((2 ^ 128 + p) * (2 ^ 128 + p) : ℕ) : ℝ≥0∞) / ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [sq, natFrac_mul _ _ _ _ (by positivity)]
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  have h1 : ((T * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((3 * 2 ^ 63 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
    rw [hone, hsq, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
    refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
    calc T * d * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 126
        ≤ (2 ^ 64 + 2 ^ 20) * 4 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126 := by gcongr
      _ ≤ 3 * 2 ^ 63 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128)) := by norm_num
      _ ≤ 3 * 2 ^ 63 * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by gcongr
  have hcoll : ∀ t : ℕ, t ≤ 2 ^ 64 + 2 ^ 20 + 1 →
      collBound t Dig ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
    intro t ht
    unfold collBound
    rw [hcard]
    refine natFrac_le (by positivity) (by positivity) ?_
    calc t * (t - 1) / 2 * 2 ^ 126 ≤ t * t * 2 ^ 126 := by
          gcongr
          exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
      _ ≤ (2 ^ 64 + 2 ^ 20 + 1) * (2 ^ 64 + 2 ^ 20 + 1) * 2 ^ 126 := by gcongr
      _ ≤ 1 * (2 ^ 128 * 2 ^ 128) := by norm_num
  calc _ ≤ ((3 * 2 ^ 63 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞)
        + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) :=
        add_le_add (add_le_add h1 (hcoll T (by omega))) (hcoll (T + 1) (by omega))
    _ = ((3 * 2 ^ 63 + 1 + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same, Nat.cast_add, Nat.cast_add]
    _ ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 61 : ℕ) : ℝ≥0∞) := natFrac_le (by positivity) (by positivity) (by norm_num)
    _ = (2⁻¹ : ℝ≥0∞) ^ 61 := by
        rw [Nat.cast_one, one_div, Nat.cast_pow, Nat.cast_ofNat, ENNReal.inv_pow]

/-- **At the shape of a slot** (for orientation only): with Goldilocks' `|K| = p²`, round degree `d ≤ 4` and
`T = q + (s + 2n) + 1 ≤ 2^64 + 2^20` (e.g. `q = 2^64` queries, `n = 30` rounds and a header of up to `2^20 − 61`
operations), the executable sumcheck accepts a false claim with probability at most `2^-61`. -/
theorem exec_sumcheck_fs_sound_slot {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (hLr : 56 + 16 * (d + 1) ≤ L)
    (s : ℕ) (stmt : List (TItem × Dig) → ((Fin n → K) → K) × Fp2)
    (q : ℕ) (A : OC (QB L) Dig (List Op × List (List Fp2))) (hA : A.Bounded q)
    (hd4 : d ≤ 4) (hT : q + (s + 2 * n) + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB L → Dig => ScWin U key domain L d n s stmt G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (exec_sumcheck_fs_sound U hU hK2 key domain hs L hL hL64 d n hd hdp hLr s stmt q A hA).trans ?_
  rw [hF]
  exact slot_bound_le gP (q + (s + 2 * n) + 1) d (by norm_num) (by norm_num) hT hd4

end ZK60.Exec
