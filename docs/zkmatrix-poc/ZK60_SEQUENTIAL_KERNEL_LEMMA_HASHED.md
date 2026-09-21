# The sequential-kernel lemma for (field, hash) message pairs — condition O-4 / gap G-H1

> **REVISED after an independent check and the security owner's disposition,
> 2026-09-21 02:20 PDT: the lemma is PROVED WITH CHANGES; the claim that O-4
> is closed is REFUSED — it is REDUCED to three owed items (K-R1's hybrid hop,
> K-R2's query-class table, K-R3's joint sentence); nothing accepted changes.**
>
> The check is `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md` (findings
> **B-1 … B-13**); the rulings this revision obeys are
> `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md` (**K-R1 … K-R5**).
> Where the check's suggested repair and a ruling differ, the ruling wins.
> Register entry **D22** rests on the random-oracle hybrid of its step 5
> (Route A), not on this lemma; its sentence, its 2^-77.7 and its conditions
> are untouched.

### Changes in this revision

| ruling (check finding) | what changed on this page |
|---|---|
| **K-R1** (B-1) | `B_sep` is **out** of the fixed-challenge bad event. Hypothesis (iii) stays a hypothesis of the composition lemma; one explicit **Hop 0** (§3.6) reaches the world where it holds, priced at exactly the figure the draft gave `B_sep`. Every "proved in a weaker model (L0)" sentence is cut back to the disposition's headline (§0, §1.3, §3.7, §3.8, §3.9, §5.1) |
| **K-R2** (B-2) | §1.3's five-way partition is replaced by an **avowedly incomplete** eleven-row table of oracle-query kinds, each with what separates it today and whether anything pins that. **Claim N5 is withdrawn as stated.** The complete table with a test behind each row is **OWED** — **GAP S-5, re-sized**. Until it exists, (iii) is a hypothesis, not a code fact |
| **K-R3** (B-3) | **GAP S-1 is re-sized to its true size**: (iv′) does **not** follow from the accepted theorems. The owed joint sentence is printed in full (§3.6 Repair 3); it is new mathematics, the next paper task. Every "closes O-4 / G-H1" now reads **reduces** |
| **K-R4** (B-4, B-5, B-6, B-9 … B-13) | Repair 1 names the rejection-region coupling (with an editor's note on its price — read it); §5.3 gains the five rows the accepted tables carry; the LogUp factor 2 is explained and re-attributed; `Pr^ξ[B]` is defined past an abort; the evidence section carries the checker's multi-round results; "Game ⊥"/"Game prefix" are defined at first use as this page's own shorthand for the project's **accepted receipts only**; citation defects fixed |
| **K-R5** | §1.5's game paragraph rewritten: the project's statements are about **accepted receipts only** (D21; M-9 for a run); the lemma's fixed-challenge hypothesis holds under that game and **fails** if refused prefixes are handed to the adversary (checker's D1, one protocol, both sides); the abort probability's own information is priced separately by the refusal terms |
| **hypotheses** | **(ii) is NOT NEEDED** (checker's B2: two adaptive witness sources, adaptive distance 0); the soundness appeal in §4 row (ii) is struck as a category error and **GAP S-4 is re-filed against (iv)'s admissibility set**. A **new numbered hypothesis (0)** — every word the transcript absorbs is public — is added, with the checker's counterexample and its code match |
| **K-1** | narrowed: it touches **no accepted sentence**; its novelty is that the older field-only lemma's parenthetical bound is **per-challenge-vector** and cannot bound the adaptive probability. It stays a correction to the toy memo's §3.3 comparison row |

| | |
|---|---|
| Author | **Drafted by a delegated Opus agent for the security owner** |
| Written | 2026-09-21, 01:14 – 01:45 PDT (`date` read at the start and at the end); **revised by an errata editor 02:20 – 03:05 PDT the same night**, to the disposition above |
| Occasion | the one step of the privacy path that has never been closed: the **sequential composition** of a multi-round Fiat–Shamir protocol's per-challenge joint-law statement into a statement about the whole hashed view. Left open at the toy as condition **O-4 / Route B** (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3); ruled last night to be **the** remaining gap for a run as well (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §3, headed "The gap that remains: O-4, the sequential composition" — the label **G-H1** is coined in the run *memo* §4.5, not in that §3; citation corrected per B-13) |
| Code read | lane `zk60-private-block-125m` at **`8c5922b`**, read-only, via `git show`. Every code fact below carries `file:line` at that commit |
| The lemma it extends | `ZK60_MVP_JOINT_VIEW.md` §1.2 and `tests/test_zk60_sequential_kernel.py`, **branch `zk60-mvp-fable` only**, for **field** messages |
| Evidence | `results/zk60_sequential_kernel_lemma_hashed/` — `sequential_kernel_hashed.py`, `checks.json`, `checks.log`, `README.md`. Exact rational arithmetic; eight checks; six generic random instances with fixed seeds and five deliberately adversarial ones. **Every one of those protocols has exactly ONE challenge round** (checker's count, B-11); the *sequential* part is exercised only by the checker's own directory, `results/zk60_sequential_kernel_lemma_hashed_check/`, which this revision now cites throughout §7 |
| Scope guard | **No privacy property of any artifact is claimed here, and none of the project's numbers moves.** Register entry **D22** (the toy block) is untouched — see §5.1. This page is a lemma and a hypothesis-by-hypothesis match against the code; it is not an acceptance of anything |

---

## 0. In plain words, before any notation

A proof of this kind is a conversation that has been flattened. The prover
says something, the verifier answers with a random-looking number, the prover
says the next thing, and so on; in the real system the verifier is not there,
and each "random-looking number" is a hash of everything said so far.

Every privacy argument this project has written so far works in the easy
world: **freeze the challenges** — pretend somebody outside handed the prover
the numbers `ρ = (r_0, r_1, …)` before it started — and show that what the
prover then publishes carries nothing about the hidden input. Two documents do
that: `ZK60_JOINT_LAW_COMPOSITION.md` for a block and
`ZK60_JOINT_LAW_COMPOSITION_RUN.md` for a run.

The step nobody has written is the step back to the real world, where the
challenges are hashes of what the prover has already said. It is not obvious,
and it is not free: the prover's own messages are *also* hashes (a commitment
root is a hash), so the thing that generates the challenges and the thing
being challenged are made out of the same material.

This page writes that step. Its findings, in plain words — **as they read
after the check and the disposition**:

1. **The composition itself needs no model of the hash.** It needs one thing:
   that the function answering the challenges is *independent of the dice the
   prover rolls*. Given that, there is a one-line identity (§3.1) that makes
   the whole composition go through for **any** challenge function whatever —
   hash, constant, adversarial.

   That is the whole of the honest headline, and here is the rest of it, which
   the first draft of this page got wrong (ruling **K-R1**): **reaching the
   world in which that independence is true costs one hop inside the
   random-oracle model** (§3.6, Hop 0) — a hop of exactly the kind Route A is
   made of, priced at exactly the figure the draft had wrongly put inside its
   bad event. And **the fixed-challenge hypothesis (iv′) is a statement inside
   the model throughout**: its hash half is Lemma H, which its own memo calls
   "a statement inside an assumed model", not a theorem. So: *the composition
   is model-free; reaching the model in which its independence hypothesis
   holds costs one hybrid hop; and the fixed-challenge hypothesis is an
   in-model statement from beginning to end.*
2. **The obvious approximate version of the lemma is FALSE**, and the way it
   fails is the way a real attack would work. "The per-challenge laws are
   within δ" does **not** give "the real law is within δ": the error can
   multiply by the number of *reachable challenge vectors* — measured `|C|` at
   one round (§3.4) and **`|C|²` at two rounds** (the checker's C1: ×4, ×9,
   ×16 at `|C| = 2, 3, 4`). The correct form conditions on a **bad event** and
   prices that event **in the real experiment**, not per challenge (§3.3).
   There *is* a correct lossy form, and it is tight: `d ≤ Σ_ρ TV_ρ` over the
   reachable `ρ` (§3.4a).
3. **Because of 2, the lemma as the project stated it is false for the
   protocol as built** — by one hair, and the hair is the one input-dependent
   refusal the project already tracks (the zero LogUp denominator). For an
   *arbitrary* challenge function an adversary can steer that refusal to
   certainty (§3.4, check C6). What is true is the lemma with that refusal
   inside the bad event, and the bad event can only be priced by saying
   something about the actual challenge function — which is one of the places
   the random-oracle model comes back in. The toy memo's sentence
   "Route B … does not need the challenges to be uniform" is corrected here
   (§3.4, correction **K-1**) — narrowly: K-1 touches **no accepted sentence**.
4. **A hypothesis this page's first draft never numbered is needed**: every
   word the transcript absorbs must be public (hypothesis **(0)**, §3.2). A
   challenge function that reads one hidden absorbed word gives adaptive
   distance **1** while the per-`ρ` hypothesis holds exactly (checker's B5).
   And one the draft *did* number is **not** needed: "the witness is fixed
   before the first message" (§3.2, hypothesis (ii) — checker's B2).

What the project gets: O-4 is **REDUCED, not closed** (ruling **K-R3**). The
composition step is written and correct; three things are owed before it can
carry anything — K-R1's hop written out as a hop, K-R2's complete query-class
table with a test behind each row, and K-R3's joint sentence, which is new
mathematics. Two error terms of Route A disappear, none is added and **one hop
is added**; **no residual total moves** — the toy stays at about 2^-77.7 and a
twelve-block 125M run at about 2^-69.3, both still the blinding sampler's bias
and nothing else.

---

## 1. Setting and notation

### 1.1 The prover as a sequence of randomized maps

**Definition 1.1.** A *paired-message protocol* is:

* a set `W` of admissible hidden inputs (a *witness*; for a run, an admissible
  hidden run input — the JOINT condition on all `L` stages, ruling **R-1.1** of
  `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`);
* a probability space `(Ω, μ)` of **prover-internal randomness**, with `μ` not
  depending on the witness. `ω ∈ Ω` carries everything the prover draws or
  reads that is not a challenge: the generator's output stream, and the
  answers of every oracle the prover's own hashing uses (§1.3);
* a challenge alphabet `C`;
* message maps `f_j : W × Ω × C^j → M_j ∪ {⊥}` for `j = 0 … N`, deterministic;
  `⊥` is the refusal symbol and ends the run.

Write `m_j = f_j(w, ω, r_0 … r_{j−1})`. **Hypothesis (i) — causality** is this
shape itself: message `j` is a function of the witness, the prover's
randomness and the challenges drawn *before* it, and of nothing else.

### 1.2 The message alphabet: `M_j = F^{a_j} × H^{b_j}`

Each message is a **pair** `m_j = (f_j, h_j)`:

* the **field part** `f_j ∈ F^{a_j}` — `Fp` and `Fp2` words: masked scalars,
  masked sumcheck round values, masked terminals, group vectors, proximity
  vectors, the masking commitment's `q` and proximity rows, and the opened
  columns;
* the **hash part** `h_j ∈ H^{b_j}` — 32-byte objects. There are exactly three
  kinds on this protocol's path, and it matters that the list is short:
  1. **commitment roots** (`A`, `M`, `H`, each internal boundary `B_k`, and the
     two external endpoints) — the only hash objects that are ever **absorbed**
     (`protocol.rs:150-154` `absorb_root`, `protocol.rs:666`, `:676`, `:774`;
     `run.rs:505`);
  2. at opening time, the **published salts** and the **authentication paths**
     of the sampled columns (`pcs.rs:1043`, `:1048`; `zk.rs:598`) — emitted
     *after* the index challenges and **absorbed nowhere**;
  3. the derived framing objects of a run — the run **binding** (`run.rs:480`)
     and the `2L` **position tags** (`run.rs:404-409`), each a deterministic
     function of the public prefix.

The salted-leaf digests of the **never-opened** columns are *not* published;
they are the hidden inputs of the Merkle map, and they are what
`Lemma H` / `Lemma H^run` is about.

**Remark 1.2 (why the pairing is the whole difficulty).** The field lemma of
`ZK60_MVP_JOINT_VIEW.md` §1.2 is stated for messages in an abstract alphabet,
so at first sight nothing stops one writing `M_j = F^{a_j} × H^{b_j}` and
declaring the lemma applied. Privacy-case item 17's carve-out (ii) says why
that is not allowed: the reviewed lemma "*is about field messages and says
nothing about the hash layer, because roots, salts and paths are not messages
chosen given `ρ`*". The substance behind that sentence is §2 below: the hash
parts are images of the **same oracle** that produces the challenges, so
hypothesis (iii) of the lemma — the one the field version gets for free — is
exactly what has to be earned.

### 1.3 The oracles, and the weakest model in which the lemma is proved

**I use three levels, and I say at every step which one a claim is in.**

> **(L0) No idealisation — the partition model.** There is a source `ξ`, and
> the challenge functions are deterministic given `ξ`. `ξ` is **independent**
> of `(ω, w)`. *Nothing else.* No random oracle, no uniformity, no
> indifferentiability.
>
> **(L1) The random-oracle model of decision D19** (and **D19a** for a tagged
> profile: a family of independent random functions indexed by BLAKE3's mode
> and key; per ruling **H-4** the honest justification is that BLAKE3's
> **compression function is ideal, also when the adversary knows and chooses
> the chaining value** — proposed **D19b**, not accepted). Conventions
> **V-1** (one long-output oracle for unkeyed BLAKE3 in both its 32-byte and
> its XOF form; needs indifferentiability; ASSUMED) and **V-2** (keyed BLAKE3
> an independent oracle) travel with it.
>
> **(L2) The named generator assumption M-3** (privacy-case ruling C-3): the
> generator's whole output stream is indistinguishable from uniform. Primary
> by ruling **L-2**; the in-model derivation is the labelled alternative.

**The result of this page, stated honestly (ruling K-R1).** The **composition**
(§3.1–§3.4) is proved in **(L0)**: given its hypotheses, no property of the
hash is used. What is *not* (L0) is everything around it.

* reaching the world in which hypothesis **(iii)** is true costs **one hybrid
  hop inside (L1)** — §3.6, **Hop 0**, priced at what the first draft called
  `Pr[B_sep]`. It is not a bad event and cannot be one (§3.6);
* hypothesis **(iv′)** is an **in-model statement throughout**: its hash half
  is `Lemma H` = **(H6)**, of which its own memo says "*Nothing above turns
  (H6) into a theorem: it is a statement inside an assumed model*"
  (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §5.2);
* (L1) also prices two quantities (§3.7): the distinguisher's oracle access
  and the one witness-dependent refusal class. (L2) or (L1) supplies
  hypothesis (iii-b).

So the sentence to print is: **the composition is model-free; reaching the
model in which its independence hypothesis holds costs one hop; the
fixed-challenge hypothesis is a statement in the model throughout.** Anything
shorter oversells the page (check **B-9**).

#### The oracle-query classes — an INCOMPLETE inventory (ruling K-R2)

`ξ := O|_T`, the restriction of the oracle to the **transcript class** `T` —
every input the challenge chain makes. A random oracle's restrictions to
**disjoint** input sets are independent random functions; that is the shape of
the argument for (iii-a). For it to be a *fact of the code* one needs the
complete list of the query kinds the production path makes and, for each, what
puts it outside `T`.

**The first draft of this page gave a five-way partition and it was not
complete.** The checker's full BLAKE3 call-site inventory of the tree at
`8c5922b` found more (**B-2**). The honest list, with what separates each kind
**today** and whether anything **pins** that separation:

| # | query kind | input, length, mode | what separates it from `T` | pinned by |
|---|---|---|---|---|
| **T1** | transcript **absorb** | `state(32) ‖ le64(\|label\|) ‖ label ‖ le64(\|data\|) ‖ data`, `≥ 48 + \|label\| + \|data\|`, min 49 and realised min 57 on the block path; keyed under `K_T` at a tagged profile (`transcript.rs:59-68`) | — it **is** `T` | — |
| **T2** | transcript **squeeze** | `state(32) ‖ "squeeze"(7) ‖ le64(counter)(8)` — **exactly 47 bytes** (`transcript.rs:101-112`) | — it **is** `T` | — |
| **T3** | transcript **CONSTRUCTOR** — a THIRD format under the same key | `b"hashline-v1/"(12) ‖ profile`; toy 51, **125M run profile 46**; unkeyed at a legacy profile, **keyed under `K_T`** at a tagged one (`transcript.rs:30`, `:41`) | length only: `12 + \|profile\| = 47` would be squeeze-identical, i.e. a **35-byte profile**. The two 35-byte profiles in the tree are refused before a transcript is built; the closest production profile is 46 | **NOTHING at the shaped layouts** — finding **F-2**'s one-byte margin; ruling **H-8** orders a one-line test, not yet written |
| **P1** | salted **leaf** | `digest ‖ salt`, 64 bytes (`pcs.rs:677`, `:691`); keyed `K_L` when tagged | length 64 ≠ 47, and `≥48+\|label\|+\|data\|` absorbs reach 64 only at `\|label\| = 8` | condition **C-H4′**; the one 64-byte absorb (`absorb_u64(b"log-cols", ·)`) is **counted**, at 2^-241.42 |
| **P2** | Merkle **node** | 64 bytes; keyed `K_N` when tagged | same | same |
| **P3** | **column digest** | `8·rows` bytes (`pcs.rs:138`, `:148`); keyed `K_C` when tagged | no commitment on the path has 5 or 8 rows (455/384/50/7/7) | condition **C-H4** — true, and **accidental** for `A`, `H`, `M` |
| **P4** | generator **refill** | `key(32) ‖ le64(counter)(8)` — **exactly 40 bytes**, **UNKEYED** (`rng.rs:53-61`, ruling **H-3**) | length 40, and the unkeyed function even at a tagged profile | on the path only. **Claim N5 is withdrawn as stated** — see below |
| **P5** | generator **SEED derivation** | `b"hashline-zk-os-rng/v1/"(22) ‖ domain`, **keyed under the fresh secret 32-byte OS entropy** (`rng.rs:44-51`). At the generalised endpoint `\|domain\| = 42` (`endpoint_g.rs:45`, `:224`), so the input is **exactly 64 bytes** — the leaf-and-node length — and it is made **twice per block** on the production path (`private_block.rs:755-757`) | **NOT length — the key.** It is `blake3::Hasher::new_keyed(&entropy)`, so convention **V-2** makes it another member of the family. That is a sound separation, but it is **not the argument §1.3 runs** | the key exists, nothing tests the length coincidence. **Verified here at `8c5922b`**: the domain literal is `b"hashline/private-block/general-endpoint/v1"`, 42 bytes; 22 + 42 = 64 |
| **U1** | statement / schedule / spec digests and the calibration identity | domain-prefixed framed public data, 30 … thousands of bytes, **UNKEYED even at a tagged profile** (`private_block.rs:511`, `:221`, `layout.rs:1288`, `run.rs:220`, `:285`, `boundary.rs:210`, `endpoint_g.rs:157`, `private_seam.rs:115`) | their own domain prefixes, and — at a tagged profile — that `T` is keyed while these are not | **nothing states it as a condition.** They are public functions of public data, so they leak nothing; but they are in the unkeyed oracle with `P4`, and no document enumerates them |
| **U2** | two further **40-byte unkeyed** transcript constructors, crate-wide | `b"hashline-v1/"(12) ‖ 28-byte domain` (`boundary.rs:604`, `stable_weight_material_tests.rs:119`) — **test-only** | nothing: they are the same length and the same (unkeyed) function as `P4` | **nothing.** At the two legacy-rule profiles (`shape.rs:549-551`: the frozen toy and the frozen-seam rung) the **entire unkeyed oracle is shared** by `T`, `P`, the constructor, every digest of `U1`, the layer/pass path, `private_attention`, `private_seam`, the public receipts, `pcs_compact`, `wcache` and `stable_weight_*` |
| **KD** | the tag **key derivation** | `blake3::derive_key(CTX, profile)` ×4 (`hashtag.rs:95-98`) | BLAKE3's **third mode** | D19a |
| **X1** | a **position tag** | two squeezes off `Transcript::clone_state`, which copies state, counter **and** key (`transcript.rs:153-163`, `run.rs:396-411`) | it is in `T` **by design** — a published challenge, not a message (§4 row (iii-c)). But it **re-issues the live chain's next two squeeze inputs verbatim**, because the clone carries the counter | ruling **H-5** and the lane's stage-24 test pin that the live chain's next operation is an absorb or the end of the run; **any distinct-query count — `Pr[B_sep]`'s and `ε_hit`'s — must say so** |

> **Claim N5, as stated, is WITHDRAWN.** "40 bytes is used by nothing else on
> this path" is true **on this path**; "40 bytes is used by nothing else" is
> **false crate-wide** (row `U2`, already known as ruling **L-3**). The run
> memo's own rider (ii) — a legacy-rule profile proved on the same machine —
> is exactly the attack shape this withdrawal protects against.

> **RULING K-R2, printed here because it is what this section now is.** A
> complete query-class table — **every** oracle query kind on the toy's path
> and on a run's path, with its mode, key, input layout and length, and why it
> is disjoint from every other — **is owed as a document with a test behind
> each row**. Until it exists, **hypothesis (iii) is a hypothesis, not a
> verified fact of the code.** This section is an inventory, not that table,
> and it does not claim to be exhaustive: it is the first draft's five kinds
> plus the six the checker found. **GAP S-5, re-sized.**

### 1.4 The challenge functions

**Definition 1.4.** A *challenge schedule* is a family of deterministic maps
`χ_j : (public prefix) → C`, where the public prefix is
`π_j = (m_0, r_0, …, r_{j−1}, m_j)`. In the protocol as built,

```
χ_j(π_j)  =  squeeze( absorb-chain( header, π_j ) )
```

— the absorb chain folds the prefix into the 32-byte state
(`transcript.rs:59-68`), the squeeze reads a 47-byte input off that state and
the squeeze counter and **overwrites the state with its own output**
(`transcript.rs:101-112`, note `self.state = out` at `:109`). Both halves are
queries in `T`, so `χ = χ^ξ` is a deterministic function of the prefix **given
`ξ`**, and of nothing else. Three consequences worth stating once:

* **the counter makes every squeeze input within one transcript distinct**
  (`transcript.rs:107`), but the lemma does **not** need that (§3.8);
* **state collisions are irrelevant to this lemma.** If two prefixes folded to
  the same state, `χ` would answer them alike — it would still be a function of
  the prefix. Transcript-binding collisions are a **soundness** question, not
  a privacy one (§3.8);
* a **position tag** is two squeezes off a discarded clone that copies the
  state, the counter and the key (`transcript.rs:156-161`, `run.rs:404-409`),
  so it is an `O|_T` image at a point determined by the public prefix: a
  *published challenge*, not a message (§4, row (iii-c)).

### 1.5 The game: ACCEPTED RECEIPTS ONLY (ruling K-R5)

**The project's statements are about accepted receipts only.** That is
decision **D21** for a block and operating rule **M-9** for a run: on a
refusal the adversary gets nothing — no receipt, no segment, no partial run
directory, no refusal reason. A refusal is **terminal**: `prove_with_stats`
calls `prove_inner` once, the endpoint owners are consumed by value and
`PreparedPlane` has no `Clone` (ruling **J-4**).

**Two names, used only on this page.** The check (**B-13**) is right that
"Game ⊥" and "Game prefix" appear in no other project document; they are this
page's shorthand and are defined here at first use, not borrowed:

> **"Game ⊥"** = the project's game — *accepted receipts only* (D21; M-9 for a
> run). On a refusal the view is the single symbol `⊥`.
>
> **"Game prefix"** = the counterfactual in which refused prefixes are handed
> to the adversary: on a refusal the view is everything published before it.
> **No project statement is made in this game**, and none may be.

The composition lemma below covers both (`⊥` is a message value with no
continuation). What differs is **hypothesis (iv′)**, and the difference is not
cosmetic — the checker built **one and the same protocol** (its check **D1**)
on which (iv′) holds at every `ρ` under accepted-receipts-only and **fails**
at the challenge-refused `ρ` when refused prefixes are handed over, with the
adaptive conclusion following the hypothesis in both directions (per-`ρ` view
TV 0 vs **1**; adaptive TV 0 vs **1**). So:

* **the lemma's fixed-challenge hypothesis holds under "accepted receipts
  only" and fails if refused prefixes are handed to the adversary.** That is
  one more reason **M-9 is a condition of any run statement and not a
  courtesy** (ruling K-R5);
* for a block it is a code fact (`prove_inner` returns `Err`, no receipt
  exists, ruling **J-4**). For a run it is **operating rule M-9**, which
  ruling **H-2** records has **no production code behind it** at `8c5922b`
  (`prove_run` has no production caller; `verify_then_write` is test-only) —
  **GAP S-3**, and it is load-bearing for this lemma, not only for tidiness;
* **what the abort *probability* itself tells a relying party is priced
  separately** — by the refusal terms of §2.5 and §5.3 — and stays so. The
  distinguisher sees whether a receipt exists at all, and that indicator is
  inside the view even under accepted-receipts-only: the checker exhibits a
  perfectly masked prefix whose refusal *rate* depends on the hidden input and
  whose adaptive distance is therefore exactly the rate gap, **1/2** in its
  instance. Nothing in the composition hides it, and nothing here claims to.
  §2.5's "a **liveness** figure, never a distance" is valid **only because**
  the challenge-driven class is a function of `ρ` alone — see the line-by-line
  caveat there.

### 1.6 The distinguisher

`D` receives the view (a receipt, a run directory, or `⊥`), makes at most `q`
queries to the hash family — before, during and after — and outputs a bit. The
object the statement is about is therefore the **augmented view**

```
AV  =  ( view ,  (x_1, O(x_1)), … , (x_q, O(x_q)) )
```

with the `x_i` chosen adaptively by `D`. §3.5 separates this into "the view"
(the composition lemma) and "the oracle access" (one extra step with its own
error term). The field lemma of `ZK60_MVP_JOINT_VIEW.md` has **no notion of
`AV`**; that is difficulty (e) of §2.

---

## 2. Why the field-only lemma does not already cover it

### 2.1 The existing lemma, quoted, with what it covers

> **Lemma (sequential kernel), `ZK60_MVP_JOINT_VIEW.md` §1.2, branch
> `zk60-mvp-fable`.** *Let the prover publish messages `m_0, m_1, …, m_n`; let
> the challenge `r_j` after `m_j` be any function `H` of the public prefix; let
> `m_j` depend only on the witness, the prover's private randomness and
> `r_<j`. If for every fixed challenge vector `ρ` the joint law of
> `(m_0, …, m_n)` given `ρ` is the same for witnesses `w` and `w′`, then for
> every `H` the law of the whole view `(m, r)` is the same for `w` and `w′`.*
>
> *Proof: by induction on `j`, the kernel `K_j(m_j | m_<j, r_<j)` is a ratio of
> two marginals of the per-`ρ` joint law (which by hypothesis is
> witness-independent for every `ρ`, hence for every prefix `r_<j`); the
> challenges are deterministic in the public prefix; the joint law is the
> product of the kernels and the challenge indicators. Public refusal events
> that are functions of the public prefix inherit the same law;
> witness-dependent refusal events break it (the LogUp collision … at most
> `(lookups + table rows)/2^128` per proof).*

Its **defining feature is the JOINT hypothesis**, and that is not a stylistic
choice: the project has a counterexample to the marginal version
(`(H(mask), mask ⊕ w)` — each value uniform alone, the pair determines `w`),
and a second one found by the joint-law check (two terminals sharing one
reserved pair: identical marginals, different joint law — ruling J-5's
inventory). `tests/test_zk60_sequential_kernel.py` on that branch checks the
lemma exhaustively on finite toy protocols, places both counterexamples as
failures of the hypothesis, and shows a witness-dependent refusal breaking the
conclusion.

**What it covers:** field-valued messages, one deterministic challenge
function at a time, no oracle anywhere in the statement, exact equality of
laws, no distinguisher with oracle access, and — in the proof as written — a
kernel defined as a **ratio of marginals**, which is where the approximate
version will fail (§3.4).

**What it does not cover, in the project's own words:** privacy-case item 17's
carve-out (ii), quoted in §1.2 above. The toy memo's §3.3 records Route B as
**extending** the lemma's message alphabet, not applying it, and labels the
row **RELIES ON** with the honest note that the check could not verify a lemma
living on another branch (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §8 row 24,
condition **O-D**).

### 2.2 Difficulty (a): challenges and messages are made of the same material

`χ_j` is evaluated on a state that has absorbed `h_j`, and `h_j` is itself an
oracle output (a root: `pcs.rs:740`/`:797` build the salted leaves,
`merkle.rs` folds them, `protocol.rs:150-154` absorbs the root). So the
challenge *does* depend on an oracle image of hidden data, and hypothesis
(iii) — "the challenge family is independent of everything the prover's
messages depend on" — **cannot be assumed; it must be derived**.

The derivation is §1.3's inventory: `χ` reads only `O|_T`, the prover's hash
parts read only the complement, and disjointness makes the two independent.
Two things must then be dealt with — **and note what changed in this revision:
the first is now paid by an explicit game hop (§3.6, Hop 0), NOT by a term
inside the bad event** (ruling **K-R1**):

* **the classes might overlap.** At the untagged toy exactly one input is in
  both: `absorb_u64(b"log-cols", ·)` is `32 + 8 + 8 + 8 + 8 = 64` bytes, the
  node-and-salted-leaf length — and the checker confirms it is the **only**
  absorb on the path that reaches 64 bytes, exhaustively over the
  `absorb_u64` labels (`rows` 4, `log-cols` 8, `pb-slot` 7, `pb-run-stage` 12,
  `io-side` 7, `pa-slot` 7, `layer` 5, `t_rows` 6, `use` 3, `d` 1, `f` 1).
  Counted at **2^-241.42** (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §1.5). At a
  tagged profile the overlap is *assumed* away by D19a rather than counted —
  the run memo says so itself (§2.2: "the bound got shorter because the model
  got stronger, not because anything was measured");
* **the generator sits outside the transcript class and carries a secret.**
  Its refill input is 40 bytes in the **unkeyed** function (`rng.rs:53-61`;
  ruling **H-3** — two of the security owner's own documents had this wrong),
  and its **seed derivation** is a *keyed* hash of an input that is **exactly
  64 bytes** at the generalised endpoint (`rng.rs:44-51`, `endpoint_g.rs:224`,
  §1.3 row `P5`), separated by its key and not by its length. **Claim N5 as
  the run memo §2.3 states it — "40 bytes is used by nothing else" — is
  withdrawn** (§1.3 row `U2`): it is true on this path and false crate-wide,
  which is ruling **L-3**, and it was being leaned on "at the toy and at a run
  alike".

**Check C7 shows this is not bookkeeping.** In a two-message toy where the
challenge query point *coincides* with the generator's refill point, the
challenge equals the prover's pad, `m_1 = pad + w` is opened by subtraction and
the distinguisher recovers `w` with certainty: **TV = 1**. With the two classes
separated, **TV = 0** over all 256 challenge functions.

**But C7 tests only a TOTAL coincidence, and that invites exactly the wrong
reading** (check **B-1**) — that a small overlap probability buys a small
distance. It does not. The checker's **B3** makes the point with a protocol
whose per-`ρ` joint law is witness-free at **every** `ρ` and a challenge
source that leaks **one bit** of the prover's pad, at `|C| = 4`:

| leak from `ω` into `ξ` | per-`ρ` TV | adaptive TV |
|---|---|---|
| none | 0 | **0** |
| **one bit of the pad** | 0 | **1** |
| the whole pad | 0 | **1** |

**One bit is already fatal.** That is why "(iii) holds except with probability
`Pr[B_sep]`" is not a sentence this lemma can consume, and why 2^-241.42 is
not the price of a small failure of (iii) — it is the price of a *different
argument*, the game hop of §3.6. Hypothesis (iii-a) is all of it or none of
it; that is the content of this line.

### 2.3 Difficulty (b): hypothesis (iv) lives in two different models

The two ingredients the project has are not the same kind of statement.

* **Theorem 3.3** (block) / **Theorem B** (run) is about the **field view `V`
  only**, and it holds *in the uniform-blinding idealisation* (ruling **J-3**):
  `law(V | ρ, NR, w) = law(V | ρ, NR, w′)`. It is an **exact equality in an
  idealised world**, reached from the real world only by an explicit
  replacement hop costing decision **D9**'s sampler term.
* **Lemma H** (block) / **Lemma H^run** is a **conditional** statement about
  the hash objects **given the field view**, holding **off a bad event
  `B_H`** — and the toy disposition insists on exactly that conditional form,
  because the project's counterexample kills the product of two marginals
  (`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` §1: "the central move is the
  right one … the *conditional* law of the hash objects given the field view").

So "(iv) for pairs" is the product

```
law(V, H | ρ, NR, w)  =  law(V | ρ, NR, w) · law(H | V, ρ, NR, w)
                      =  [witness-free by Thm 3.3] · [witness-free kernel K(H|V) by Lemma H]
```

and the three things that have to be true for that line to be legitimate are
set out in §3.6: the idealisation must become an **event** (coupling), `B_H`
must be replaced by a **witness-free superset** so the sub-measures can be
compared, and the **joint** law of (field view, published salts, hash
objects, flag) must be witness-free.

**The first draft wrote "None of the three is hard; none had been written."
That is withdrawn (ruling K-R3).** The first two are elementary and are
discharged in §3.6 (Repair 1 — subject to the editor's note there — and
Repair 2). **The third is not.** It is not "the two theorems holding
conditionally on the salts", which was the draft's under-sized phrasing; it
is a joint sentence about field values, published salts, hash objects and
the flag together, it is **not delivered by the accepted theorems** — they
are field-only and their probability space excludes the salts — and it is
**new mathematics** landing on the project's one candidate with no
structural answer. **GAP S-1, re-sized.**

**Check C3** is the reminder of why the joint form is compulsory even with
hash parts: over all 256 public functions `H` on a 4-element domain, the
marginals of `(H(mask), mask + w)` are witness-free for **all 256**, the joint
law is witness-dependent for **252**, and a distinguishing challenge function
exists for exactly those 252.

### 2.4 Difficulty (c): lazy sampling and programming

**None is needed.** The ideal world of this project is the honest prover on
the **all-zero input** (decision **D18-A**), not a simulator: `check_endpoints`
refuses any policy whose endpoint roots differ from the prover's own fresh
ones (`protocol.rs:447-459`, reached at `:484`; `run.rs:470`). A simulator that
had to hit a **caller-fixed** root would have to program the oracle — decisions
**D8**/**D11**, untouched here — and then Lemma H would be the wrong tool
entirely (privacy-case item 14). The lemma of §3 programs nothing and samples
nothing lazily: it conditions on the whole challenge oracle and never needs to
choose an answer after the fact. What it does need is that **the all-zero input
is admissible and proves** — measured for the toy
(`zero_witness_tests.rs`) and for the two development rungs, and **not
measured at 125M** (gap **G-R3**, ruling **R-4**, blocking).

### 2.5 Difficulty (d): the aborts

Three classes, from `ZK60_HASH_LAYER_AND_FS_LIFT.md` §4 and the run memo §5.2:

| class | where it enters this lemma |
|---|---|
| shape / schedule / policy / environment refusals (10 of 18 at the toy) | identical public functions of identical public data; they are part of the message maps and cost nothing |
| **challenge-driven** (`c_s = 0`; `e ∈ {0,1}`; a zero group coefficient; a dependent proximity pair — `protocol.rs:246`, `:282-292`; rate `4/p ≈ 2^-62.0` per opening, `(3L+1)/p = 2^-58.79` at `L = 12`) | functions of `ρ` **alone**, so the refusal is the same event in both worlds. Under accepted-receipts-only hypothesis (iv) is trivially true at such `ρ` (both worlds output `⊥`); if refused prefixes were handed over it is supplied by nothing (claim **S-6**, confirmed by the checker's D1). A **liveness** figure, never a distance — **and that holds ONLY because the class is a function of `ρ` alone.** The checker read two of the four in the code: `check_opening_challenges` (`protocol.rs:283-294`) refuses on a zero drawn group coefficient or a zero determinant of two drawn proximity coefficients, both functions of the drawn challenges and public layout data — ✓ CODE FACT for those two. **`c_s = 0` and `e ∈ {0,1}` have not been read line by line by anyone.** If any of the four also reads `ω` or `w`, it becomes a **distance** term (check **B-12**). That reading is owed |
| **the one input-dependent class**: a zero LogUp denominator (`protocol.rs:403`), at most 768 distinct inverted arguments per block at every shape (ruling **S-4**). **Two figures, and they are different quantities** (check **B-6**): the **one-world** event is ruling S-4's `768/p²` = **2^-118.42** per block and `12·768/p²` = **2^-114.83** at `L = 12`; the **two-world union** that a distance bound requires is twice them, **2^-117.42** and **2^-113.83** (§3.7 R-a) | hypothesis (iv) **fails** at the `ρ` where it fires. It goes into the bad event, and pricing it **requires** saying something about the actual challenge function — §3.4 and §3.7. This is the single place where the "arbitrary challenge function" reading of O-4 is *false* |

### 2.6 Difficulty (e), which the brief did not name: the distinguisher's oracle access

The field lemma concludes about the law of the view. The project's statements
are about a verifier that **makes `q` hash queries** — and Lemma H's own
conditional statement was corrected (C-10) precisely to include "the
adversary's `q` oracle answers" in the conditioning, because the distinguisher
holds them when it decides. A composition lemma about the view alone is
therefore not enough, and the gap is not cosmetic: check **C8** exhibits a
protocol whose view is *exactly* witness-free at `q = 0` and whose advantage is
`1/4` at `q = 1`. §3.5 supplies the missing step.

---

## 3. The lemma

Throughout: `w, w′ ∈ W` admissible; `ξ` the challenge source; `χ^ξ` the
schedule; `A(w, ω, ξ)` the adaptive run; `F(w, ω, ρ)` the run at fixed
challenges `ρ`; `d(·,·)` total variation.

### 3.1 Lemma P — the path identity (the engine)

> **Lemma P.** Assume **(0) publicness of the absorbed words** (§3.2 — added
> in this revision; without it `ρ^ξ(m)` below is not well defined) and
> **(i) causality**. Fix `w`, `ω` and `ξ`.
> 1. If the adaptive run `A(w, ω, ξ)` produces messages `m = (m_0 … m_k)` and
>    challenges `(r_0 … r_{k−1})`, then for **every** `ρ` extending
>    `(r_0 … r_{k−1})` the fixed-challenge run `F(w, ω, ρ)` produces the same
>    `m`, and every internal variable of the two runs agrees.
> 2. Conversely, define `ρ^ξ(m)` recursively by
>    `ρ^ξ(m)_i = χ_i^ξ(m_{≤i}, ρ^ξ(m)_{<i})` — the unique `ξ`-consistent
>    challenge vector along `m`. If `F(w, ω, ρ^ξ(m)) = m` then
>    `A(w, ω, ξ)` produces `m` with those challenges.
> 3. Hence, as subsets of `Ω`,
>    `{ω : A(w, ω, ξ) has messages m} = {ω : F(w, ω, ρ^ξ(m)) = m}`,
>    and for any event `E` that is the same measurable rule of
>    `(w, ω, the challenges seen)` in both runs,
>    `{A has messages m} ∩ E = {F(·, ρ^ξ(m)) = m} ∩ E`. Therefore
>
>    ```
>    Pr_ω[ A(w,ω,ξ) has messages m , E ]  =  Pr_ω[ F(w,ω,ρ^ξ(m)) = m , E ]      (★)
>    ```
>
> **PROVED HERE** (elementary). **Machine-checked: C1**, 0 mismatches of exact
> rational laws over every challenge function of six paired protocols — all
> of them ONE-ROUND (check B-11). **The checker's A1/A3 re-check it at two
> and three rounds, with aborts and every completion of a truncated `ρ`,
> 4,101 schedules each: 0 mismatches**, and its §3 records that part 3 is a
> genuine **set** equality, verified independently.

*Proof.* Induction on `j`. At `j = 0` both runs compute
`m_0 = f_0(w, ω, ())` — no challenge has been drawn. Suppose both runs have
produced the same `m_{<j}` and the same challenges `r_{<j}`. The adaptive run
draws `r_{j−1} = χ_{j−1}^ξ(m_{≤j−1}, r_{<j−1})`, which is the same value the
recursion `ρ^ξ` assigns, and the fixed run is handed it by assumption; both
then evaluate the same `f_j` at the same arguments. Refusal ends both at the
same index. Part 2 is the same induction read forwards. Part 3 follows because
the two runs are *the same computation* on that set of `ω`, so any event
defined by the same rule of `(w, ω, r)` holds in one iff in the other. ∎

**Why this replaces the kernel-ratio induction.** The published lemma computes
`K_j` as a quotient of two marginals. The quotient is where an approximate
hypothesis would have to be divided by a possibly tiny denominator, and it is
also where a reader has to check that the denominators are non-zero. (★) has
neither problem, and it is the identity the approximate form (§3.3) needs.

### 3.2 Theorem S-H — the exact lemma for (field, hash) pairs

> **Theorem S-H.** Let a paired-message protocol satisfy
> * **(0) publicness of the absorbed words** — NEW IN THIS REVISION, check
>   **B-7**: every word the transcript absorbs is a component of the message
>   tuple `m` (or of the public statement), so that `χ_j` is a function of the
>   *public* prefix and nothing else. Without it `ρ^ξ(m)` of Lemma P is not
>   even well defined and (★) is false;
> * **(i) causality** (Definition 1.1);
> * **(ii) the witness is fixed before `m_0`**: `w` is a parameter of the
>   experiment and is not a function of `ξ` or of any published value.
>   **NOT NEEDED for the conclusion** — see the remark below; it is a
>   well-posedness condition that fixes what (iv)'s quantifier ranges over,
>   and it is kept in the list only because deleting a label silently is
>   worse than marking it;
> * **(iii) challenge independence**: `ξ ⊥ (ω, w)`, i.e. the source that
>   determines the challenge schedule is independent of the prover's internal
>   randomness — *including the oracle answers the prover's own hash parts are
>   images of* — and of the witness;
> * **(iv) the joint per-`ρ` hypothesis for PAIRS**: for every `ρ ∈ C^N`,
>   `law_ω(F(w, ω, ρ)) = law_ω(F(w′, ω, ρ))` as laws on tuples of pairs
>   `(f_j, h_j)` (with `⊥` a value).
>
> Then for **every** realization `ξ` and every schedule `χ^ξ` — hash,
> constant, adversarial, anything —
> `law(A(w, ·, ξ)) = law(A(w′, ·, ξ))`, and consequently the **joint** law of
> `(view, ξ)` is the same for `w` and `w′`. The same holds for the view of
> **either** abort game of §1.5, and for the joint law of the view and the
> abort indicator.
>
> **PROVED HERE, in model (L0) — the composition itself uses no property of
> the hash.** Reaching the world in which (iii) is true costs the hop of
> §3.6; (iv) and (iv′) are in-model statements throughout (§1.3, ruling
> **K-R1**). **Machine-checked: C2 at one round; and by the checker at TWO
> and THREE rounds with aborts, 4,101 challenge schedules each, 0 mismatches
> and max adaptive TV 0** (checks A1/A3).

*Proof.* Fix `ξ`. The view is a deterministic function of the message tuple
(the challenges are recovered as `ρ^ξ(m)` and the abort games are fixed maps of
the tuple), so it suffices to compare message laws. By (★) with `E = Ω`,
`Pr[A(w,·,ξ) has messages m] = Pr[F(w,·,ρ^ξ(m)) = m]`, and the same for `w′`;
by (iv) at the single challenge vector `ρ^ξ(m)` the two right-hand sides are
equal. Summing over `m` gives equality of the message laws, hence of the view
laws. Since this holds for every `ξ` and `ξ ⊥ w` by (iii), the joint law of
`(view, ξ)` is the same, so a distinguisher that knows `ξ` **in full** gains
nothing. ∎

**Three things to notice.**

1. The proof uses (iv) at **one** challenge vector per message tuple. That is
   why the per-`ρ` hypothesis suffices even though the prover's "tree" of
   responses across different challenge vectors is wildly witness-dependent:
   the adaptive view exposes exactly one branch.
2. Nothing asked the challenges to be uniform, and nothing asked `χ` to be
   hard to compute. Pre-querying the challenge oracle is free: the conclusion
   is *conditional on the whole of `ξ`*.
3. (iii) is about `ξ` versus the prover's **internal randomness**, not versus
   the prover's **messages**. The messages depend on `ξ` through the
   challenges, necessarily and harmlessly. A statement of (iii) that said
   "independent of the messages" would be false and would make the theorem
   vacuous.
4. **Where (iii) is consumed.** The first draft's proof read as if (iii) were
   used at the end, to join `ξ` to the view. It is not: "Fix `ξ`" means
   *condition on* `ξ`, and (★) is then applied with `ω ~ μ`, which is
   legitimate only because `law(ω | ξ) = μ` — that is (iii), consumed in the
   first move (check **B-1**). This matters for §3.6: a hypothesis consumed
   at the first move cannot be repaired by an event quantified inside the
   experiment whose measure that move already fixed.

**Remark (ii) — NOT NEEDED, with the measurement (check B-8 / B2, ruling in
the disposition §1).** Two *adaptive* witness sources — the stage-1 secret
chosen **after** `r_0`, as a function of `r_0` and the source's own seed,
which is exactly `RunWitnessSource` being called inside the stage loop
(`run.rs:500`, `:512`) — satisfying (0), (i), (iii) and (iv) at every `ρ`
give **adaptive TV 0** over every schedule. An adaptive source folds into the
message maps and causality is untouched. So (ii) is not a hypothesis of the
conclusion; it is **well-posedness**: it fixes what the quantifier in (iv)
ranges over. In the privacy game the honest prover's witness is fixed by the
game's own quantifier — the statement is "for all admissible `w`" — so there
is nothing to prove and, in particular, **no appeal to the commitment's
binding or to soundness is needed or permitted here**; the first draft made
one and it was a category error (§4 row (ii), rewritten). The residual
obligation is real but lives elsewhere: the *deployed* interface must not be
usable outside (iv)'s admissibility set — condition **C-R3**, **GAP S-4,
re-filed against (iv)**.

**Remark (0) — NEEDED, with the counterexample.** A one-round protocol with
per-`ρ` TV **0** — (iv) holds *exactly* — in which `χ` reads one unpublished
absorbed word has adaptive TV **1** (checker's B5). The numbered list
(i)–(iv) alone does not exclude it, which is why (0) is now numbered.

**(0) against the code at `8c5922b` — it holds by construction, and here are
the lines.** The verifier recomputes **every** absorb from public data: it
builds the transcript with the *same* constructor the prover uses
(`protocol.rs:113-123`, called by the prover at `:490` and by the verifier at
`:978`), which absorbs `expected-IO`, `public-statement`, `parameters`,
`calibration` and `schedule`; `verify_core` (`:841`) then absorbs the roots at
`:860` and `:868` through the same `absorb_root` (`:150-154`) the prover uses
at `:666`, `:676`, `:774`; and a masked sumcheck round absorbs **the masker's
output**, i.e. exactly the value the receipt carries (`transcript.rs:82-99`).
For a run the header (`run.rs:302-321`) is re-absorbed word for word by
`RunVerifier` (`run.rs:599`, stage absorbs at `:640-641`, `B_k`'s root at
`:645`). A word the verifier could not recompute would fail verification, so
on the accepted-receipt path (0) cannot be violated. **What is NOT done here
is the exhaustive reading**: this revision spot-checked the block and run
headers and the root absorbs, as the checker did; the exhaustive reading is
the toy memo §3.1 and the run memo §1.2, and neither this page nor the check
re-read them line by line (§4 row (iii-d), status corrected).

### 3.3 Theorem S-H′ — the identical-until-bad form (the one the project needs)

Hypothesis (iv) never holds exactly for the real prover: the blinding is
slightly biased, the hash layer's kernel holds only off `B_H`, and one refusal
class is witness-dependent. The correct approximate form is **not** a
total-variation hypothesis (§3.4 shows why) but a bad-event one.

> **Theorem S-H′.** Assume **(0)**, (i), (iii) — (ii) is not needed, see the
> remark in §3.2 — and
> * **(iv′) identical-until-bad at fixed challenges.** There is a *flag*
>   `B(w, ω, ρ) ∈ {0,1}`, given by **the same rule in both worlds** and
>   measurable with respect to `(w, ω, ρ)`, such that for every `ρ ∈ C^N` and
>   every message tuple `m`
>
>   ```
>   Pr_ω[ F(w, ω, ρ) = m , ¬B ]  =  Pr_ω[ F(w′, ω, ρ) = m , ¬B ] .
>   ```
>
> Then for every `ξ`
>
> ```
> d( law A(w,·,ξ) , law A(w′,·,ξ) )  ≤  ½ ( Pr^ξ_w[B] + Pr^ξ_{w′}[B] )
> ```
>
> where `Pr^ξ_w[B]` is the probability of the flag **in the adaptive run**.
>
> **PROVED HERE, in model (L0)** — the composition step uses no property of
> the hash; (iii) is reached by the hop of §3.6 and (iv′) is an in-model
> statement (§1.3). **Machine-checked: C5** (the bound holds and is tight in
> every row of C4); and by the checker with a **non-adapted** flag, 0
> violations in 256 checks over every schedule × every completion (check C3).

> **Convention `Pr^ξ[B]` past an abort (check B-10, ruling K-R4).** If the
> flag reads a component of `ρ` at a round the adaptive run never reached,
> "the probability of the flag in the adaptive run" has **no referent**.
> Therefore: **`B` is required *adapted* — it may read only the challenges
> actually drawn — or, equivalently, fix any completion of `ρ^ξ(m)` past the
> abort and read `Pr^ξ[B]` under it.** (iv′) is quantified over the whole of
> `C^N`, so the choice is free and the smallest completion is the sharpest.
> This is a convention, not a hole: the checker built a two-round instance in
> which (iv′) holds under a non-adapted flag, half the runs abort before `ρ_1`
> is drawn, and the true adaptive TV is `1/2`; the bound holds under **every**
> completion (0 violations in 256 checks) but its *value* moves by a factor 2
> — 1/2 under one completion, 1 under another, for the same schedule.

> **Why the flag must be the UNION over the two worlds when it reads the
> witness (check B-6).** "The same rule in both worlds" is not the same thing
> as "evaluated in one world". For a witness-reading refusal the flag has to
> be `B = B_w ∪ B_{w′}`, and that is where the factor 2 on the LogUp term
> comes from. It is **forced, not decorative**: on the checker's 8-value
> LogUp-shaped instance (refuse iff the challenge equals `g(w)`), over every
> schedule, the union flag gives max `(TV − bound) = 0` — the bound holds and
> is tight — while the single-world flag `B = B_w` **violates** the bound by
> **3/8**. A reader who "simplifies" to ruling S-4's one-sided figure gets a
> **false** bound.

*Proof.* By (★) applied with `E = {¬B}` and with `E = {B}`,

```
Pr^ξ_w[m] = Pr_ω[F(w,·,ρ^ξ(m)) = m, ¬B] + Pr_ω[F(w,·,ρ^ξ(m)) = m, B],
```

the first term equal to the corresponding term for `w′` by (iv′). Hence

```
2·d = Σ_m |Pr^ξ_w[m] − Pr^ξ_{w′}[m]| ≤ Σ_m ( Pr_ω[F(w,·,ρ^ξ(m))=m, B] + same for w′ ).
```

By (★) again, `Σ_m Pr_ω[F(w,·,ρ^ξ(m)) = m, B] = Σ_m Pr^ξ_w[m, B] = Pr^ξ_w[B]`.
∎

> **Corollary S-H′a (the taxonomy that decides how a bad event is priced).**
> * If `B` is a function of `ω` alone — it does not read the challenges — then
>   `Pr^ξ_w[B] = Pr_w[B]` for **every** `ξ`, and a fixed-challenge count is a
>   valid bound. *(The blinding-coupling failure and the salt-collision event
>   are of this kind.)*
> * If `B` reads the challenges, then `Pr^ξ_w[B]` depends on `ξ` and **no
>   per-`ρ` count bounds it**. Something must be said about the actual `ξ`.
>   *(The LogUp class and the adversary's salt-guessing event are of this
>   kind.)*

### 3.4 What is FALSE: the naive approximate form — and a correction to the toy memo

> **Claim K-0 (negative).** Hypotheses (i)–(iii) together with
> "`d(law F(w,·,ρ), law F(w′,·,ρ)) ≤ δ` for every `ρ`" do **NOT** imply
> `d(law A(w,·,ξ), law A(w′,·,ξ)) ≤ δ`. The error can multiply by `|C|`, and
> in the worst case by the number of reachable challenge vectors.
>
> **Counterexample (constructed here; machine-checked C4 at `|C| = 2, 4, 8,
> 16, 32`).** `ω = u` uniform on `C`. `m_0 = (u, ∅)` — a published value
> carrying nothing about `w`. Then
> `m_1 = (w, ∅)` if `r_0 = u`, and `(0, ∅)` otherwise. At every fixed `ρ_0`
> the leak fires with probability `1/|C|`, so the per-`ρ` distance is exactly
> `1/|C|`. The schedule `χ_0(m_0) := u` — *read the first message* — makes it
> fire always: adaptive distance **1**. Measured blow-up at ONE round:
> exactly `|C|`.
>
> **At TWO rounds the blow-up is `|C|²`** (checker's C1: per-`ρ` TV `1/4`,
> `1/9`, `1/16` against adaptive TV **1** at `|C| = 2, 3, 4` — ×4, ×9, ×16).
> The prose above is right that the worst case is "the number of reachable
> challenge vectors"; the first draft's headline "blow-up exactly `|C|`"
> understated its own finding, because its evidence never left one round
> (check **B-11**).
>
> The same instance satisfies S-H′ with `B = {r_0 = u}`: `Pr^ξ[B] = 1` under
> the steering schedule and `1/|C|` under a constant one, and the bound of
> §3.3 holds with equality in both. **The bad event has to be priced in the
> adaptive experiment; that is the whole content of the correct form.**

> **Correction K-1, to `ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3 — NARROWED per
> the disposition (§1, last bullet), and it touches NO ACCEPTED SENTENCE.**
> That page says "Route B is stronger in one way — **it does not need the
> challenges to be uniform** — and weaker in another: it needs the per-`ρ`
> hypothesis at *every* `ρ`". The first half is right about the
> **composition** and wrong about the **statement as a whole**, and the two
> halves are the same fact seen from two sides. Because the protocol has one
> witness-dependent refusal class, hypothesis (iv) fails at some `ρ`; S-H′
> then applies with that class in `B`; and `B` reads the challenges, so by
> Corollary S-H′a its probability **cannot be bounded without a property of
> `χ`**. For an arbitrary `χ` it is not small.
>
> **What is and is not new here.** The first draft claimed more than it
> should. The *same sentence* K-1 corrects already names the defect's second
> half ("*and weaker in another …*"), and the branch lemma's own proof
> already ends "*witness-dependent refusal events break it (the LogUp
> collision … at most `(lookups + table rows)/2^128` per proof)*" — so the
> older field-only lemma's proof **already excludes** witness-dependent
> refusals. **K-1's real novelty is narrower and is this: that parenthetical
> bound is a PER-CHALLENGE-VECTOR count, and a per-`ρ` count cannot bound the
> ADAPTIVE probability for an arbitrary `H`.** That is a genuine and useful
> sharpening and it should be claimed as that, not as a new falsification.
>
> **Where it lands.** The corrected sentence lives in **one place**: §3.3 of
> `ZK60_HASH_LAYER_AND_FS_LIFT.md`, a row labelled **MIXED / RELIES ON** (§8
> row 24, condition **O-D**), whose own text already records that its lemma
> lives on another branch. The checker searched the toy privacy statement and
> its draft, `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`,
> `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`,
> `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md`,
> `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md` and `ZK60_DECISIONS.md`: **zero
> accepted sentences depend on it.** The toy statement contains no occurrence
> of "Route", "sequential-kernel", "kernel", "arbitrary" or "challenge
> function" at all.
>
> **Check C6** makes the mathematics concrete on the LogUp shape: a protocol
> that refuses iff the challenge equals a hidden-data-determined value `g(w)`.
> A **constant** challenge function `χ ≡ g(w_0)` gives adaptive distance **1**
> at every `|C| ∈ {4, 8, 16}` (the checker reproduces this exactly); over 200
> random challenge functions the mean distance is 0.658 / 0.321 / 0.163 —
> halving as `|C|` doubles, i.e. of order `1/|C|`, which is the union bound
> the project already carries.
>
> **So the honest reading of O-4 is: the composition is unconditional given
> its hypotheses; reaching hypothesis (iii) costs one hybrid hop; hypothesis
> (iv′) is an in-model statement; and the random-oracle model is needed for
> one further line of arithmetic** — bounding `Pr^ξ[B]` for the `χ` the code
> actually uses. That is a *differently distributed* dependence on D19 than
> Route A's, not obviously a smaller one, and §5.1 prints the trade.

### 3.4a The correct approximate form, which K-0 does not kill

The first draft printed the false form and the event form and nothing in
between. There **is** a correct lossy form, it falls out of the same identity
(★), and the checker verified it is **tight in every row** of its C1:

> **Claim K-0′ (positive, the lossy form).** Under (0), (i), (iii),
>
> ```
> d( law A(w,·,ξ) , law A(w′,·,ξ) )  ≤  Σ_{reachable ρ}  d( law F(w,·,ρ) , law F(w′,·,ρ) )
> ```
>
> hence `≤ (#reachable ρ) · δ` if every per-`ρ` distance is at most `δ`.
>
> **PROVED by (★)** — sum the identity over the message tuples grouped by
> their `ρ^ξ(m)`. **Machine-checked by the checker (C1/C2), tight in every
> row.** It is not usable for this protocol at the sizes in play — the number
> of reachable `ρ` is astronomically larger than `1/δ` — which is exactly why
> §3.3's bad-event form is the one the project needs. It is printed because a
> reader who only sees K-0 may conclude that nothing approximate survives.

### 3.5 Corollary S-H″ — the distinguisher's oracle access

> **Corollary S-H″ (augmentation).** Assume the conclusion of S-H′ for the
> view. Let `Q_pub` be the set of oracle points the prover queried whose
> answers are **determined by the view** (every transcript absorb and squeeze;
> the column digest, salted leaf and every path node of every *opened* column
> — the verifier itself recomputes them, `salt_leaf_keyed(hash_column_keyed(col,
> K_C), salt, K_L)` before walking the path: `pcs.rs:1248`, `zk.rs:671`), and
> `Q_hid` the rest (the salted-leaf inputs of
> never-opened columns; the generator's refill points; internal nodes above an
> unopened subtree). If, in model (L1),
>
> ```
> Pr[ D's q queries hit Q_hid ]  ≤  ε_hit(q)
> ```
>
> then `d(AV_w, AV_{w′}) ≤ d(view_w, view_{w′}) + ε_hit^w(q) + ε_hit^{w′}(q)`.
>
> **PROVED HERE, in (L1)** (the step needs the oracle's freshness at
> unqueried points, so it is not an (L0) step). **Machine-checked: C8** —
> exact advantage `1/4` and `1/8` against one hidden salted leaf at
> `|S| = 2, 4`, always under the `q·N/|S|` bound. **Two corrections from the
> check (B-11):** C8 fixes the query set in advance and asserts that this is
> "without loss"; the checker re-ran it against an **optimal adaptive**
> `q`-query distinguisher (exact dynamic programming over the posterior) and
> the bound still holds at `q = 0, 1, 2` and `|S| = 2, 4`. And the bound is
> **very loose** — `q·N/|S|` already exceeds 1 at `q = 1` in those instances
> (bound 1 against advantage 1/4; bound 1/2 against 1/8), so C8 is weak
> evidence either way and should not be cited as confirmation.

*Proof sketch.* Sample the oracle lazily. Off the hit event, every answer `D`
receives is either a function of the view (points in `Q_pub`, equal in both
worlds given equal views) or a fresh uniform value independent of everything
else. So off the hit event `AV` is a randomized function of the view alone,
and randomized functions do not increase total variation; identical-until-bad
adds the two hit probabilities. ∎

`ε_hit` is exactly the project's existing accounting: `q·N_leaf·2^-256`
(salt guessing — 2^-114.42 at the toy and 2^-106.76 at 125M `L = 12`, both at
`q = 2^128`), plus `ε_gen(q) ≤ 6q·2^-256` on the in-model route for the
generator's key and the OS entropy (**or** assumption M-3 on the primary
route), plus `q·(#nodes)·2^-512` for an internal node, which is below 2^-480.

### 3.6 Assembling hypothesis (iv′) for pairs from what the project has

This is where the two composition theorems and the two hash-layer lemmas are
cited and **not** re-proved. It opens with the hop that the first draft of
this page did not perform.

#### Hop 0 — reaching the world in which hypothesis (iii) is true (ruling K-R1)

**This replaces `B_sep`.** The first draft put "a transcript-class query
input equals a prover-class query input" inside the bad event `B` of (iv′).
That is the wrong place and no bookkeeping inside Theorem S-H′ repairs it:

* (iv′) is a statement *inside* the fixed-challenge experiment, with
  `ω ~ μ` **unconditioned**. Hypothesis (iii) is what licenses the proof's
  very first move — "Fix `ξ`" means *condition on* `ξ`, and applying (★) with
  `ω ~ μ` is legitimate only because `law(ω | ξ) = μ`. If the two classes
  share a coordinate, conditioning on `ξ` changes `ω`'s law, and (iv′) —
  stated for the unconditioned `μ` — no longer supplies what the proof
  consumes. An event quantified inside an experiment cannot repair the
  measure that experiment was set up with;
* **and a failed (iii) cannot be priced as a bad event at all, because it is
  not all-or-nothing in the direction that would make pricing work.** The
  checker's B3 (reprinted in §2.2): a challenge source leaking **one bit** of
  the prover's pad, on a protocol whose per-`ρ` joint law is witness-free at
  **every** `ρ`, gives adaptive distance **1** — while the fixed-challenge
  hypothesis holds everywhere. One bit costs everything. A quantity that goes
  from 0 to 1 on one leaked bit is not a term in a union bound.

The repair the disposition accepts is **one explicit hybrid hop, performed
before Theorem S-H′ is applied, at the same price**:

> **Hop 0.**
> **Game 0** — the real experiment, one oracle `O`.
> **Game 1** — two *independent* oracles `O_T` and `O_P`: the prover's
> transcript queries (§1.3 rows `T1`–`T3`, `X1`) are answered by `O_T`, its
> commitment, digest and generator queries (rows `P1`–`P5`, `U1`, `U2`) by
> `O_P`.
> The two games are **identical until** a transcript-class input equals a
> query input of the other class, so any distinguisher's advantage differs by
> at most `Pr[B_sep]`.
> **In Game 1, hypothesis (iii-a) holds exactly**, and Theorem S-H′ applies.
>
> **Price: exactly the figure the first draft gave `B_sep`** — **2^-241.42**
> at the untagged toy (the 64-byte `absorb_u64(b"log-cols", ·)`,
> `ZK60_HASH_LAYER_AND_FS_LIFT.md` §1.5); **0 by D19a** at a tagged profile,
> i.e. assumed, not measured. Numerically nothing changes. **What changes is
> the headline**: the hop is an **(L1)** step of exactly the kind Route A is
> made of, and it is *added*, not dropped (§3.8).
>
> **And it is only as complete as §1.3's inventory** — which is avowedly
> incomplete (ruling K-R2). `Pr[B_sep]` is a count over a list of query
> kinds; until the complete table with a test behind each row exists, the
> hop's price is a count over a list nobody has closed. **GAP S-5.**

> **Claim S-5 (assembly) — RESTATED.** Take
> `B := B_samp ∪ B_salt ∪ B_logup` — **`B_sep` is no longer a member; it is
> Hop 0** — with
> * `B_samp` — the **coupling failure** of the prover's real blinding stream to
>   a uniform one;
> * `B_salt` — **two salts of the run coincide**;
> * `B_logup` — the zero-LogUp-denominator refusal fires **in either world**
>   (the union; §3.3's box says why the union is forced).
>
> Then, **in Game 1**, (iv′) holds, given: **Theorem 3.3 / Theorem B** with
> their travelling conditions; **Lemma H / Lemma H^run**; and the three
> repairs below.
>
> **NOT ESTABLISHED as it stands** (check **B-3**, ruling **K-R3**): Repair 3
> is not a bookkeeping sentence but **new mathematics**, and until it exists
> (iv′) does **not** follow from the accepted theorems. What is established is
> a **REDUCTION** to those four documents **+ GAP S-1 at its true size**.

**Repair 1 — the idealisation becomes an event (PROVED HERE, elementary; the
coupling is now NAMED, per check B-4 and ruling K-R4).**
Theorem 3.3 is stated in the uniform-blinding idealisation; S-H′ needs an
event, not a distance. `fp()` reduces a uniform 128-bit integer mod `p`
(`rng.rs:73-77`), a law at total-variation distance exactly `2^-96` from
uniform on `Fp`.

**"The coupling lemma" is not enough, and the first draft's appeal to it was
under-specified.** The assembly needs Theorem 3.3 to apply *conditionally on
`¬B_samp`*, i.e. its hypothesis (H5) — "`α`, `π`, `μ` mutually independent
and `α` uniform" — must survive the conditioning. Under a generic **maximal**
coupling it does **not**: conditioned on agreement the common value is
distributed as the normalised minimum of the two measures, which is *not*
uniform, and Theorem 3.3's fibre-count step (H2) then fails.

**The coupling that does work is the rejection-region coupling native to
`fp()`.** Let `k = ⌊2^128/p⌋`, `r = 2^128 − kp`, `U` uniform on `[0, 2^128)`,
real value `X = U mod p`; define the ideal value `Y = X` when `U < kp` and a
fresh independent uniform when `U ≥ kp`; set `B_samp = {U ≥ kp}` per draw,
union over draws. Then `Y` is exactly uniform, and — the point —
**conditionally on `¬B_samp` the value `U mod p` is exactly uniform on `Fp`
and the draws stay independent**, because `kp` is a multiple of `p`. (H5)
survives the conditioning, which is what (iv′) needs.

Numerically the term is decision **D9**'s, unchanged: `327,052·2^-96 =`
**2^-77.7** for one toy proof; `109,728,784·2^-96 =` **2^-69.29** for a
twelve-block 125M run (ruling **H-6**'s post-repair count). `bytes32()` needs
no coupling: it is raw stream output (`rng.rs:93-99`). **`B_samp` is a
function of `ω` alone**, so by Corollary S-H′a it costs the same under every
challenge schedule.

> **EDITOR'S NOTE — a ruling I applied as written and believe to be
> arithmetically wrong, 2026-09-21 (errata pass).** The paragraph above is
> ruling K-R4's ("the rejection-region coupling … number unchanged"), taken
> from the check's B-4, which asserts "*the memo's `2^-96` per draw is the
> same `r/2^128`*". **It is not.** For Goldilocks `p = 2^64 − 2^32 + 1`,
> `2^128 ≡ −2^32 (mod p)`, so `r = 2^128 mod p = p − 2^32` and
> **`r/2^128 = 2^-64.000`**, while the total-variation distance is
> `r(1 − r/p)/2^128 = ` **`2^-96.000`** — the two differ by 32 bits.
> Recomputed here in exact integers: `327,052·r/2^128 = ` **2^-45.68** (toy)
> and `109,728,784·r/2^128 = ` **2^-37.29** (run), against D9's 2^-77.68 and
> 2^-69.29. Moreover the gap is forced, not an artefact of this coupling: if
> `law(X | ¬B)` is to be exactly uniform then
> `(1 − Pr[B])/p ≤ min_x Pr[X = x] = k/2^128`, i.e. `Pr[B] ≥ r/2^128`, for a
> **single** draw. So **no event-form repair of the sampler idealisation can
> cost 2^-96 per draw**, and "number unchanged" cannot be right as stated.
>
> What this does **not** mean: no accepted number moves, because D22 rests on
> Route A, where the sampler enters as a *distance* hop (a hybrid over draws,
> paying the total variation `2^-96` each) and never as an event. The
> available repairs, none of which I may choose here, are (a) apply S-H′ in
> the idealised world and pay the sampler distance by the triangle
> inequality outside it — Route A's move, keeping 2^-77.7 but giving up the
> "one event" form; (b) keep the event form and re-price D9 at `r/2^128` per
> draw, which would move the toy residual to about **2^-45.7** and a run's to
> about **2^-37.3**; or (c) find a third coupling, which the bound above says
> does not exist. **This is a ruling for the security owner, not for an
> errata editor.** Everything else in Repair 1 stands.
>
> **SECURITY OWNER'S RESOLUTION, 2026-09-21 02:42 (ruling K-R4a): the editor
> is right, and the checker and I were wrong.** I recomputed it in exact
> integers: `r/2^128 = 2^-64.000`, the distance per draw `2^-96.000`, and the
> lower bound `Pr[B] ≥ r/2^128` for any event that leaves the sample exactly
> uniform. **Repair (a) is the ruling.** The sampler idealisation is a
> *distance* hop taken **before** the lemma: the blinding draws are made at
> schedule-determined positions and the whole view is a function of the draws,
> the salts, the oracle and the challenges, so replacing the real draws by
> uniform ones moves the view's law by at most the distance between the two
> draw vectors, at most `N · 2^-96` — decision D9's accepted figure, 2^-77.68
> at the toy and 2^-69.29 for a twelve-block 125M run. The lemma is then
> applied in the uniform-blinding world, **and `B_samp` leaves the flag**; what
> is left in the flag is the salt coincidence and the lookup refusal. Repair
> (b) is refused: it would re-price an accepted decision for the convenience
> of a proof's form.

**Repair 2 — `B_H`'s witness-dependence is removed for free (PROVED HERE).**
Lemma H's bad event includes "two salted-leaf **inputs** coincide", which
requires both the column digests and the salts to be equal — and the columns
depend on the witness, so `Pr[B_H | w]` is witness-dependent and the
sub-measures of (iv′) could not be compared. Replace it by the **superset**
`B_salt` = "two of the run's salts coincide". It contains the original event,
it is a function of the salts alone — hence witness-free and `ω`-measurable —
and it costs **exactly the published figure**, because the published figure was
already `C(N_leaf, 2)·2^-256` over uniform salts: **2^-229.83** at the toy
(`N_leaf = 12,288`), **2^-214.52** at 125M `L = 12` (`N_leaf = 2,473,984`).
Nothing is lost and the statement becomes comparable.

**Repair 3 — the joint sentence. GAP S-1, RE-SIZED TO ITS TRUE SIZE (ruling
K-R3; check B-3). This is not a bookkeeping sentence and it is not
"immediate": it is NEW MATHEMATICS, and it is why "O-4 is closed" is
refused.**

The assembly multiplies `law(V | ρ, NR, w)` by the hash kernel and intersects
with `¬B`. For that to be legitimate one needs `law(V, H, 1_{¬B} | ρ, w)`
witness-free — the **joint** law of the field view, the published salts, the
hash objects **and the flag** — not only `law(V | ρ, w)`.

**(iv′) does NOT follow from the accepted theorems.** Three reasons, from the
documents themselves:

* they are **field-only**. Theorem 3.3's probability space is `α, π, μ` —
  blinding families B1–B9 — and that is all (`ZK60_JOINT_LAW_COMPOSITION.md`
  §3.3 setup). Its conditional sampler "*takes no witness, no pad, no mask,
  no salt*" and "*produces no roots, no salts and no authentication paths. It
  is a field-view sampler.*";
* **their probability space excludes the salts and publishes them.** B10, the
  leaf salts, is in the blinding table but **not** in the partition, and is
  the only family marked published: "*the 5 × 2,048 / 4,096 leaf salts … yes,
  for the 256 opened leaves per commitment*". The salts sit on the
  **conditioning side** of the hash-layer assumption (H6): "*the conditional
  law of (the three roots, the 5 × 256 authentication paths) **given** the
  field view **and the published salts***";
* **the block memo's own §5.3 row 6 calls this the one candidate with no
  structural answer**: "*`A`'s 256 **published salts**, drawn from the same
  stream that later produces `H`'s pads | the receipt, and (secretly) `H`'s
  pads | **only** assumption M-3 in its two-sided, whole-stream form (ruling
  C-3). **This is the one candidate with no structural answer**.*" Its §8 Q6
  says the same: those come from **one** BLAKE3 stream as disjoint
  consecutive segments.

So "the field view never mentions a salt" is **not** evidence that the two
are independent — the salts and the blinding are **consecutive segments of
one stream**, and the project has already identified their independence as
its single structural hole. The first draft's "*I believe the conditional
form is immediate*" is withdrawn; the word "immediate" is struck.

> **THE OWED SENTENCE, as the disposition gives it (K-R3).**
>
> *At every non-refused challenge vector the joint law of (field view,
> published salts, hash objects, flag) is witness-free, with the blinding
> uniform conditionally on the sampler's good event and the salt segment of
> the stream independent of the blinding segments.*
>
> Written out in the checker's longer form, which names what each clause
> rests on:
>
> *For every admissible `w` and every `ρ` with `NR(ρ)`, the joint law of (the
> field view `V`, the published salts, the hash objects `H`, and the
> indicator `1_{¬B}`) is the same for all admissible `w` — where
> `B = B_samp ∪ B_salt ∪ B_logup`, the theorem's blinding randomness is
> uniform **conditionally on `¬B_samp`** under the coupling of Repair 1, and
> the salt segment of the generator's stream is independent of its blinding
> segments (assumption **M-3** in its two-sided whole-stream form, ruling
> **C-3**; at a run, gap **G-R4**).*

**Who owes which half.** Not one sentence from two documents but **four**:
one from each **field** theorem (`ZK60_JOINT_LAW_COMPOSITION.md` Theorem 3.3,
`ZK60_JOINT_LAW_COMPOSITION_RUN.md` Theorem B) **and one from each hash
lemma** (`Lemma H`, `Lemma H^run`) — their conditional kernel must stay
witness-free after conditioning on `¬B_samp` (a blinding-stream event). And
the hash half is weaker than a "core accepted" label suggests: **Lemma H
*is* (H6)**, of which its own memo says "*Nothing above turns (H6) into a
theorem: it is a statement inside an assumed model*" (§5.2), listing it as a
gap.

**What the owed proof must defeat.** Ruling **R-3**'s counterexample — the
one the project built for "joint = sum of parts", **two blinding rows with
coinciding values** — is exactly what has to be aimed at this line and
survived. At a run this is gap **G-R4** (cross-role blinding independence
over `4L + 1` roles on one stream, "to be machine-asserted").

**GAP S-1 — re-sized: OWED, new mathematics, the next paper task.** It is not
a loop and not an erratum; it is the step that makes the difference between
"O-4 is closed" and "O-4 is reduced".

> **Claim S-6 (the abort game decides a quantifier) — PROVED HERE, and
> CONFIRMED BY THE CHECKER on one protocol (its D1).** Under **accepted
> receipts only** ("Game ⊥", §1.5), hypothesis (iv′) at a `ρ` on which the
> **challenge-driven** refusal fires is trivial: both worlds output `⊥` with
> probability 1, so the sub-measures agree without any appeal to Theorem 3.3
> — which is fortunate, because Theorem 3.3 is conditioned on `NR` and says
> nothing there. If refused prefixes were handed to the adversary ("Game
> prefix") the truncated view at a refused `ρ` would have to be shown
> witness-free, and **no project document supplies that**. The checker built
> **one and the same protocol** on which per-`ρ` view TV is 0 under
> accepted-receipts-only and **1** under prefixes, with adaptive TV following
> (0 vs **1**). So the project's game is load-bearing for this lemma, and for
> a run it rests on operating rule **M-9**, which ruling **H-2** records as
> having **no production code behind it** at `8c5922b` — **GAP S-3**.

### 3.7 Where the random-oracle model enters

**Heading corrected (check B-9, ruling K-R1): it is not "and only there".**
The first draft counted three priced quantities and called the rest (L0).
The honest count has four entries, and one of them is a hypothesis, not a
price:

| # | quantity | why (L0) cannot do it | size |
|---|---|---|---|
| **R-a** | `Pr^ξ[B_logup]` — the witness-dependent refusal, in the adaptive experiment | reads the challenges; for an arbitrary `χ` it is not small (check C6). **It also needs the squeeze counter's distinctness** — each challenge point must be fresh — which §3.8 wrongly listed as needed only for R-c and for soundness (check B-9) | with `χ` a random oracle, **as a two-world union** (§3.3's box: the union is forced, the single-world flag violates the bound by 3/8): `2·768/\|Fp2\|` = **2^-117.42** per block, `2·L·768/\|Fp2\|` = **2^-113.83** at `L = 12`. **Ruling S-4's own figures are the ONE-WORLD counts** — `768/p²` = 2^-118.42 and `12·768/p²` = 2^-114.83 — and have no factor 2; the doubling is the run memo §5.2's discharge ("*the constant is 2, not 1, because the conditioning event itself differs between the worlds in the LogUp class*", toy correction C-8), and the run check names the confusion as its trap **B-12c**. *(D22's own statement carries the coarser raw count, "up to 2^-112" — with no factor 2; the first draft's "2·2^-112.0" is corrected here, check B-13.)* |
| **R-b** | `Pr[B_sep]` — **the price of Hop 0**, no longer a member of `B` | reaching the world in which hypothesis (iii-a) is true is a statement about the hash's inputs, not about the composition | untagged toy: **2^-241.42** (the 64-byte absorb, §1.5 of the toy memo). Tagged: **0 by D19a**, i.e. assumed, not measured. **A hop, not a bad event** (ruling K-R1), and only as complete as §1.3's inventory (GAP S-5) |
| **R-c** | `ε_hit(q)` of Corollary S-H″ | needs freshness of unqueried oracle points | `q·N_leaf·2^-256` = **2^-114.42** (toy) / **2^-106.76** (125M `L = 12`) at `q = 2^128`; plus `ε_gen(q) ≤ 6q·2^-256` = 2^-125.42, or M-3 |
| **R-d** | **hypothesis (iv′) itself** — NOT a price, a hypothesis | its hash half is `Lemma H` = **(H6)**, "*a statement inside an assumed model*" (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §5.2); its field half needs the owed joint sentence of Repair 3 | not a number. **In-model throughout** |

The **composition** — the part O-4 asked for — is model-free given its
hypotheses. That is the true and useful sentence, and it is smaller than the
one the first draft printed.

### 3.8 What the lemma does **not** need (and what therefore drops out of the tally)

| Route A needs | Route B (this lemma) | why |
|---|---|---|
| **B3 / B5**, the distinguisher pre-querying a challenge point (`q·4,000·2^-256` = 2^-116.03 at the toy; `q·A·2^-256` = 2^-110.52 at 125M `L = 12`) | **not needed** | the conclusion holds for **every** realization of `ξ`, so knowing part of `ξ` in advance is worth nothing |
| **B4 / B6**, two absorb inputs colliding (2^-233.07 toy; 2^-222.04 run) | **not needed** | `χ_j` is a function of the *prefix* whatever the state chain does; collisions are a **soundness** matter (the transcript's binding), and this page says nothing about soundness |
| the squeeze counter making every challenge input distinct (`transcript.rs:107`) | **not needed** for the composition | same reason; but it **is** needed for R-c's book-keeping, for **R-a** (pricing `Pr^ξ[B_logup]` in the ROM requires each challenge point to be fresh — corrected per check B-9) and for soundness |
| "replace every challenge by a uniform value drawn in advance" (hop G_6 → G_7) | **not needed** | there is no such hop; `ξ` is conditioned on, not replaced |
| lazy sampling of the whole oracle (hop G_0 → G_1) | needed only inside Corollary S-H″ | the composition never chooses an answer after the fact |
| oracle **programming** | **not needed** | the ideal world is the honest prover on the all-zero input (D18-A). Under D8/D11 this changes completely — §2.4 |
| — | **ADDED: Hop 0** (§3.6), the two-oracle hybrid that makes hypothesis (iii-a) true, at `Pr[B_sep]` | ruling **K-R1**. It is an (L1) hop of exactly the kind Route A is made of |

**Two terms leave the tally, none joins it, AND ONE HOP IS ADDED** (ruling
K-R1; the first draft's "none joins it" was measured against its own tally,
not the project's — see §5.3, which now carries the five rows it was
missing). No total moves: at the toy the sum is still **2^-77.7** and at a
twelve-block 125M run still **2^-69.3**, both of them decision D9's sampler
bias and nothing else (§5.3) — **subject to the editor's note in §3.6 Repair
1**, which is a question for the security owner and not a change made here.

### 3.9 The lemma in one box

> **Theorem S-H′ applied to this protocol.** After **Hop 0** (§3.6), which
> costs `Pr[B_sep]`, and then in model (L0) for every challenge schedule,
> with `B = B_samp ∪ B_salt ∪ B_logup` (**`B_sep` is NOT a member**),
>
> ```
> d( view_w , view_0 )  ≤  Pr[B_sep]  +  ½ ( Pr^ξ_w[B] + Pr^ξ_0[B] )
> d( AV_w  , AV_0  )    ≤  Pr[B_sep]  +  ½ ( Pr^ξ_w[B] + Pr^ξ_0[B] )
>                                      +  ε_hit^w(q) + ε_hit^0(q)
> ```
>
> with the three components of `B`, the hop's price and `ε_hit` sized in §3.6
> and §3.7, under hypotheses **(0)**, (i), (iii-a), (iii-b), (iv′) — (ii) is
> not needed — matched against the code in §4, and conditional on Theorem 3.3
> / Theorem B, Lemma H / Lemma H^run, **the owed joint sentence of Repair 3
> (GAP S-1, not yet written)** and their own open conditions.
>
> The numerical sum is unchanged, because `Pr[B_sep]` was already in the
> first draft's `B` at the same value; what changed is that it is now a hop
> and not a bad event.

---

## 4. The hypotheses against the protocol as built (`8c5922b`)

| hyp. | what it demands | where it holds, at `8c5922b` | status |
|---|---|---|---|
| **(i) causality** — `m_j` a function of `(w, ω, r_{<j})` only | every published object is computed before the challenge that follows it | **block**: `protocol.rs:662` (`A` committed) → `:666` (absorbed) → `:676` (`M`) → `:682-684` (`β, γ, α`) → `:770-775` (`H`) → the 23 slots → `:790` (`M` opened) → `:796`, `:800` (`A`, `H`) → `:494`, `:498` (endpoints). **Run**: `run.rs:494-495` (stage index, block digest) → `:504-505` (`B_k` committed and absorbed **before any challenge of either adjacent equality slot**) → `:512` (witness) → `:522` (`prove_core`) → `:525-531` (the incoming commitment opened, "the claim list is complete NOW, and not before") → `:535`, `:543` (endpoint openings). The salts and paths are gathered **after** the index challenges and absorbed nowhere (`pcs.rs:1036` then `:1043`/`:1048`; `zk.rs:594` then `:598`) | **CODE FACT** (re-read here; it is also the toy memo's §3.1 table and the run memo's §1.2, both VERIFIED IN THE CODE there) |
| **(ii) the witness fixed before `m_0`** — **NOT NEEDED for the conclusion** (check B-8 / B2; disposition §1) | nothing, for the lemma. It is **well-posedness**: it fixes what (iv)'s quantifier ranges over | **The obligation is a quantifier, not a code fact.** In the privacy game the prover is honest and `w` is universally quantified — "for every admissible hidden (run) input" — so (ii) holds by the statement's own shape, and **no appeal to binding or soundness is made or needed**. *(The first draft argued the interior chain is fixed "because the endpoints are committed and the relations are proved". That is a **category error** — it imports an unreviewed soundness property (`FA5`) into a privacy proof to establish something the game already gives. It is struck.)* The code facts remain true and are kept for the record: `prove_inner` takes the witness **by value** (`protocol.rs:469`, `:477`), the transcript is built afterwards (`:490`), and ruling **H-1**'s header absorbs `expected-IO` with both external endpoint roots before any challenge exists (`run.rs:316`, header `:302-321`, `check_endpoints` `:470`) | **NOT NEEDED.** The residual obligation is real but belongs elsewhere: the *deployed* interface must not be usable outside (iv)'s admissibility set — `src.boundary_plane(k)` at `run.rs:500` and `src.witness(k)` at `run.rs:512` are **inside** the stage loop, segment `k−1` having left at `:568`, so an adaptive chain can be assembled, and **Theorem B is stated only for an admissible run input (ruling R-1.1), so it simply does not cover one**. **GAP S-4 = condition C-R3, RE-FILED AGAINST (iv)**, enforced by nothing |
| **(iii-a) separation** — the challenge source is independent of the prover's oracle answers | disjoint query classes — **the eleven-row inventory of §1.3, which is INCOMPLETE by ruling K-R2**. Untagged: squeezes are **47 bytes** (`transcript.rs:101-112`), absorbs `≥ 48` (`:59-68`), leaves and nodes 64, refills **40** (`rng.rs:53-61`), column digests `8·rows`, **the constructor `12 + \|profile\|`** (`transcript.rs:30`, `:41`), **the generator's seed derivation exactly 64 bytes but KEYED** (`rng.rs:44-51`, `endpoint_g.rs:224`), **the unkeyed digest family** (`private_block.rs:511` and seven more). Tagged: `F_T` vs `F_C/F_L/F_N/F_U` (D19a) | toy: conditions **C-H4** (no commitment has 5 or 8 rows — true: 455/384/50/7/7, *accidental* for `A`, `H`, `M`), **C-H4′** (no transcript domain of length 28 or 35 — true on the block path, **false crate-wide**), one counted overlap at **2^-241.42**. Run: **claim N5 WITHDRAWN as stated** (40 bytes is unoccupied on the path, not crate-wide — ruling L-3), finding **F-2** (the 125M **run** profile's constructor input is **46 bytes**, one byte from the squeeze class, and nothing checks it — ruling H-8 orders a one-line test, not yet written) | **A HYPOTHESIS, NOT A CODE FACT** (ruling **K-R2**). It looks true at every profile in scope and is pinned by nothing at several of them; at tagged profiles it is **ASSUMED** via D19a (and H-4's stronger-than-D19 model, proposed **D19b**). **The complete query-class table with a test behind each row is OWED — GAP S-5** |
| **(iii-b) generator independence** — `ω` independent of `ξ` | the prover's randomness must not be readable off the challenge oracle (a missing fourth column in the first draft; the row rendered short) | `ZkRng::from_os` reads 32 bytes of `/dev/urandom` and derives a key with **keyed** BLAKE3 (`rng.rs:44-51`); the stream is **unkeyed** BLAKE3 over `key ‖ le64(counter)`, 40 bytes (`rng.rs:53-61`, ruling **H-3**). One stream per block (`protocol.rs:486`); **one per run** plus one per external endpoint (`run.rs:475`, `endpoint_g.rs:224`, ruling **R-2**) | **ASSUMED (M-3, primary, ruling L-2)**, or derived in (L1) at `ε_gen(q) ≤ 6q·2^-256` with conventions V-1 (indifferentiability, ASSUMED) and V-2. In the ROM the prover's randomness is itself an oracle output at a point the adversary cannot query without the 256-bit key or the OS entropy — the two routes of that `6q` |
| **(iii-c) the position tags are challenges, not messages** | a tag must be a deterministic function of the public prefix and `ξ` | `position_tag` squeezes two `Fp2` off `Transcript::clone_state`, which copies **state, counter and key** (`run.rs:404-409`, `transcript.rs:156-161`); the clone is discarded, so the live chain is undisturbed; the verifier re-derives them. Ruling **H-5**: a segment's trailer *equals* the next segment's start tag (no transcript operation between them) — a repetition by design, not a collision. **Add (check B-2):** because the clone copies the **counter**, the tag **re-issues the live chain's next two squeeze inputs verbatim** — harmless only because the live chain's next operation is always an absorb or the end of the run (now pinned by the lane's stage-24 test), and **any distinct-query count, `Pr[B_sep]`'s and `ε_hit`'s alike, must say so** | **CODE FACT**, with that rider |
| **(0) / (iii-d) every absorbed word is public or published** — **now a NUMBERED hypothesis**, (0) of §3.2 | otherwise `χ` is not a function of the *public* prefix, `ρ^ξ(m)` is not well defined and (★) is false (checker's B5: adaptive TV **1** while per-`ρ` TV is 0) | prover and verifier build the transcript with the **same** constructor (`protocol.rs:113-123`, prover `:490`, verifier `:978`), absorbing `expected-IO`, `public-statement`, `parameters`, `calibration`, `schedule`; roots through the same `absorb_root` (`:150-154`) on both sides (prover `:666`, `:676`, `:774`; verifier `verify_core` `:841`, absorbs at `:860`, `:868`); a masked sumcheck round absorbs **the masker's output**, i.e. exactly the value the receipt carries (`transcript.rs:82-99`). Run: header `run.rs:302-321`, re-absorbed by `RunVerifier` (`run.rs:599`, `:640-641`, `:645`) | **CODE FACT by construction on the accepted-receipt path** — a word the verifier could not recompute would fail verification — **but NOT EXHAUSTIVELY READ** here or by the checker; the exhaustive reading is the toy memo §3.1 and run memo §1.2, which neither re-read line by line |
| **(iv′) joint per-`ρ`, in event form, for pairs** | §3.6 | field half: **Theorem 3.3** (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, core accepted) / **Theorem B** (`ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`, accepted as a *reduction*, conditional on **G-R1, G-R2, G-R4**, and at 125M **G-R3**). Hash half: **Lemma H** = **(H6)**, of which its own memo says "*a statement inside an assumed model*" (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2, §5.2) / **Lemma H^run** (§3.2 of the run memo, proved in the model). Repairs 1–3 of §3.6 | **NOT DELIVERED BY THE ACCEPTED THEOREMS** (ruling **K-R3**): they are field-only, their probability space excludes the published salts, and the owed joint sentence is **new mathematics**. What exists is a **REDUCTION** to those four documents **+ GAP S-1 at its true size + their own open gaps**. Also **in-model throughout** (§3.7 R-d) |
| **the ideal world exists** | the all-zero input is admissible and proves | toy: `zero_witness_tests.rs` (measured 2026-09-20, two range boundaries pinned). Rungs G and K4: `run_tests.rs` and five zero bundles. **125M: no test exists** | **MEASURED** at the toy and the rungs; **GAP G-R3, BLOCKING**, at 125M (ruling R-4) |
| **accepted receipts only** (D21; M-9 for a run — "Game ⊥" of §1.5) | a refusal publishes nothing | block: `prove_inner` returns `Err`, no receipt (ruling J-4). Run: `verify_then_write` verifies the whole run before the statement file exists (`run_statement_file.rs:235-247`), a run directory must start empty (`run_sink.rs:151-159`) — but segments are fsynced and renamed into place as they are made (`run_sink.rs:181-203` from `run.rs:568`), so for a run the rule is about what is **transmitted**, not about what is on disk | block: **CODE FACT**. Run: **operating rule M-9**, and ruling **H-2** records it has **no production code behind it** — `prove_run` has no production caller at `8c5922b`. **GAP S-3**, and ruling **K-R5** makes it a *condition of any run statement*, because the lemma's hypothesis (iv′) fails without it |

---

## 5. What the lemma gives the project

### 5.1 The toy block — what O-4 becomes, and what D22 does **not** become

**D22's sentence does not change, and must not.** It stays:

> *In the random-oracle model for BLAKE3 (decision D19), and assuming the
> prover's randomness generator's output stream is indistinguishable from
> uniform, a verifier who receives an accepted receipt of this profile and
> makes at most `q ≤ 2^128` hash queries sees a view whose distribution is
> within about 2^-77.7 of a distribution that does not depend on the hidden
> input, output or activations — per proof. Whether the prover refuses is, up
> to 2^-112, a function of the verifier-visible random challenges alone …*

**Where step 5 stands after the check and the disposition** — this is the
disposition's own §3 table, printed verbatim, and it replaces the first
draft's version, which said "closed as a lemma":

| | The toy (accepted, D22) | A run |
|---|---|---|
| What it rests on today | the random-oracle hybrid (Route A), accepted | the same hybrid, conditional on the run's open gaps |
| What this lemma adds | a second, shorter route — **not yet usable**: owes K-R1's hop, K-R2's table, K-R3's joint sentence | the same |
| Does any accepted sentence change | **no** | none exists |

**Condition O-4 / O-D is REDUCED, not closed** (ruling K-R3). The bookkeeping
underneath, for whoever picks this up:

| | before (Route A) | after (this lemma, as revised) |
|---|---|---|
| the lift | a ten-hop lazy-sampling hybrid inside the ROM, with the challenges replaced by uniform values (hop G_6 → G_7) and the whole oracle sampled lazily (G_0 → G_1) | the path identity (§3.1) + Theorem S-H′ (§3.3), the composition itself in **(L0)**; **plus Hop 0** to reach hypothesis (iii); with (iv′) an in-model statement throughout and three further quantities priced in the ROM (§3.7) |
| condition **O-4 / O-D** | **open**: "Route B extends the lemma's message alphabet rather than applying it", the lemma itself on another branch | **REDUCED**: the composition step for `(field, hash)` pairs is written and correct, with hypotheses matched line by line (§4) — **subject to GAPs S-1 … S-5**, of which S-1 is new mathematics |
| terms in the tally | includes B3 (`q·2^-244.03`) and B4 (2^-233.07) | both **drop** (§3.8) |
| terms added | — | **none — but one HOP is added** (Hop 0, §3.6), at the price the draft gave `B_sep` |
| the total | 2^-77.7 | **2^-77.7** (see the editor's note in §3.6 Repair 1) |
| the refusal sentence | "up to 2^-112" (the raw LogUp count) | unchanged by this page; ruling **S-4**'s distinct-value refinement would make it 2^-118.4 per block **one-sided**, 2^-117.4 as the two-world union §3.3 requires, and §3.7 R-a shows it is now a bound **on `Pr^ξ`**, which is a stronger kind of claim and needs the ROM |
| **what supports the accepted refusal clause** | Route A's uniform-challenge hop supplies the word "**random**" in "*a function of the verifier-visible **random** challenges alone*" | **R-a supplies it instead**, which needs (L1) **and** the squeeze-input distinctness §3.8 lists as unneeded for the composition. The clause does not change; what supports it does (check B-13) |

**Does step 5 end up on more assumptions, fewer, or the same?** The same
*set* — D19/D19a, V-1, V-2, M-3-or-`ε_gen`, D9 — differently distributed,
**plus one requirement Route A does not visibly make**: the sub-measure form
of (iv′), i.e. the owed sentence of Repair 3. Route A's hops need only a
chain of pairwise distances; Route B needs the joint law of *(view, salts,
hash objects, flag)*. **So until GAP S-1 is discharged, moving step 5 to
Route B would rest step 5 on MORE, not less.** After S-1 is discharged it
rests on less. That is the trade, and it is printed here rather than left to
a reader (check B-9). One thing the checker could not settle: whether Route
A's ten hops implicitly need the same conditional-on-salts sentence — if they
do, "Route B needs more" softens.

**The statement must not get stronger silently, and here is the one place it
could.** Route B's conclusion holds "for every challenge function", which reads
like a stronger sentence. It is not one for this protocol, because of the
LogUp class (§3.4, correction K-1): the quantifier over `χ` is only free
*inside* the composition. Anyone tempted to write "…and the argument does not
depend on the hash being ideal" must write instead: **"the composition does
not; reaching its independence hypothesis costs a hop in the model, its
fixed-challenge hypothesis lives in the model, and three of its error terms
need the model."**

### 5.2 A run — which gaps remain under it

The gap the run disposition's §3 describes (the label **G-H1** is the run
memo §4.5's) asked for exactly the lemma of §3. **The composition step is
written; the gap is REDUCED, not closed.** What a run's sentence would then
still be conditional on:

* **the three owed items of this revision**: **Hop 0** written out as a hop
  (done here, §3.6 — but its price is a count over §1.3's incomplete
  inventory); **GAP S-5**, the complete query-class table with a test behind
  each row; and **GAP S-1**, the owed joint sentence, which is new
  mathematics and is the one that actually blocks;
* **G-R1** ((H1) per commitment at a shaped layout), **G-R2** (the 23 slot
  closures), **G-R4** (cross-role blinding independence — which §3.6 Repair 3
  now leans on **harder**, since it is the only thing standing behind the
  salt/blinding independence), all under Theorem B;
* **G-R3** at 125M — no all-zero chain has been proved there: **BLOCKING**;
* **C-R3 / GAP S-4** — the adaptive witness source. **Re-filed**: it is not a
  hypothesis of this lemma (hypothesis (ii) is not needed) but a gap in
  **(iv)'s admissibility set** — Theorem B is stated only for an admissible
  run input, and a chain assembled adaptively is outside its quantifier;
* **M-9 / GAP S-3** — accepted-receipts-only has no production code behind
  it, and ruling **K-R5** makes it a condition of any run statement;
* conditions **C-R1, C-R2, C-R4, C-R5** and finding **F-2**'s one-byte
  margin (ruling **H-8**'s one-line test, not yet written).

### 5.3 The sums, against last night's residual tables

Nothing moves — **but the first draft's tally was not the project's** (check
**B-5**): "two terms leave and none is added" was measured against eight rows
of this page's own choosing, while the accepted residual tables carry five
more. They are added here. **No total moves** even so; the sampler dominates
the second-largest distance term by 37 bits at 125M.

| term | toy block | run, 125M `L = 12` | kind |
|---|---:|---:|---|
| `B_samp` (decision D9, accepted) | **2^-77.70** | **2^-69.29** | distance, `ω`-only |
| `B_logup` — **the two-world union**, `2·L·768/\|Fp2\|` (the *one-sided* figures of ruling **S-4** are 2^-118.42 / 2^-114.83; the doubling is the run memo §5.2's discharge, trap **B-12c**) | 2^-117.42 | 2^-113.83 | distance, **challenge-reading** |
| `B_salt` (`C(N_leaf,2)·2^-256`) | 2^-229.83 | 2^-214.52 | distance, `ω`-only |
| `ε_hit` salt guessing at `q = 2^128` | 2^-114.42 | 2^-106.76 | distance |
| `ε_gen` in-model alternative, `6q·2^-256` | 2^-125.42 | 2^-125.42 | distance / else assumption M-3 |
| **the price of Hop 0** (was listed as `B_sep`; untagged: the 64-byte absorb) | 2^-241.42 | 0 by D19a (assumed) | **a hybrid hop**, not a bad event (ruling K-R1) |
| **ADDED — constructor-vs-absorb (row B10 of the run's accepted table, the run check's B-7)**, `(A + q)·2^-256` at `q = 2^128` | — (the toy table does not carry it) | **2^-128.00** | presumably **drops** under Route B by the same argument as B4/B6 — both inputs are transcript-class and a collision is transcript binding, i.e. soundness — **but that has to be said, not assumed**, and it is said here for the first time |
| **ADDED — tag-key collision** (ruling **H-4**), `C(12, 2)·2^-256` | — | **2^-249.96** | **does NOT drop**: D19a/V-2 bookkeeping, which Route B leans on *harder*, not less. (Only eight of the twelve keys are pinned pairwise distinct; the extension is owed — run memo hash-layer errata) |
| **ADDED — key collision** (a tag key equals a generator key), `3·4·2^-256` | — | **2^-252.42** | **does NOT drop**, same reason |
| **ADDED — leaf input = node input** (condition **C-4**, ruling **L-7**) | **2^-484.83** | — | carried by the toy's accepted table; a soundness-side ambiguity, out of this page's scope |
| **ADDED — the generic-rank term `Δ_gr`** | **0** on the accepted structural route; **≈ 2^-56** on the fallback if its structural step is rejected | same | **the only term in the corpus that would DOMINATE 2^-77.7.** It is 0 today; a page that reprints the tally must carry it even at 0 |
| ~~B3 / B5 pre-query~~ | ~~2^-116.03~~ **dropped** | ~~2^-110.52~~ **dropped** | — |
| ~~B4 / B6 absorb collision~~ | ~~2^-233.07~~ **dropped** | ~~2^-222.04~~ **dropped** | — |
| **total** | **2^-77.70** | **2^-69.29** | |
| separately: challenge-only refusal | 2^-62.0 | 2^-58.79 | **liveness, not distance** (and only because the class is a function of `ρ` alone — §2.5) |

Every figure in this table is quoted from the two hash-layer memos and their
dispositions; the five recomputed independently when this page was drafted
agree to two decimals (`ε_hit` toy and run, `B_salt` toy and run, `B_logup`
at `L = 12`). **The checker recomputed the whole table in exact integers**
(its check E1) and every row reproduces: toy total **2^-77.6808**, run total
**2^-69.2906** — the latter equal to the run memo's own −69.2906. **One
figure is not recomputable from this page or from the toy memo**: B4/B6, the
absorb-input collision at 2^-233.07, because neither states the absorb count
`A` (the toy memo says outright "*I have not counted them exactly, and say
so*"; 2^-233.07 back-solves to `A = 4,296`). That is a gap in the source, not
here, and it is named rather than papered over.

---

## 6. Step table, what to attack first, what this is not

### 6.1 Every step

| # | step | label |
|---:|---|---|
| 1 | the setting, the message alphabet, the three kinds of hash object (§1.1–§1.2) | **VERIFIED IN THE CODE** |
| 2 | the three models (L0)/(L1)/(L2) and the oracle-query inventory (§1.3) | **ASSUMED** where (L1)/(L2) are used; **the inventory is AVOWEDLY INCOMPLETE** — ruling K-R2, **GAP S-5**; see §4 row (iii-a) |
| 3 | `χ_j` is a deterministic function of the public prefix given `ξ` (§1.4) | **VERIFIED IN THE CODE** (`transcript.rs:59-68`, `:101-112`) |
| 4 | the field lemma quoted, and exactly what it covers (§2.1) | **CITED** (branch `zk60-mvp-fable`; **not** in the main tree — unchanged from condition O-D) |
| 5 | difficulty (a): dependence through one oracle; reduced to the inventory (§2.2) | **PROVED HERE**, given the inventory — and the reduction is now performed by **Hop 0**, not by a bad event |
| 6 | difficulty (b): the two models of (iv) and how they multiply (§2.3) | **REDUCED** to Theorem 3.3 / B × Lemma H / H^run, **+ GAP S-1, re-sized to new mathematics** |
| 7 | difficulty (c): no programming, no lazy sampling in the composition (§2.4) | **PROVED HERE** |
| 8 | difficulty (d): the three abort classes (§2.5) | **REDUCED** to the toy memo §4 and run memo §5.2; **two of the four challenge-driven refusals have never been read line by line** (check B-12) |
| 9 | difficulty (e): the distinguisher's oracle access (§2.6, §3.5) | **PROVED HERE, in (L1)** |
| 10 | **Lemma P**, the path identity (§3.1) | **PROVED HERE**; machine-checked C1, and by the checker at 2 and 3 rounds with aborts, 4,101 schedules each, **0 mismatches**. The checker's verdict: "*a genuine set equality … the best paragraph on the page*" |
| 11 | **Theorem S-H**, exact (§3.2) | **PROVED HERE, in (L0)** on (0), (i), (iii), (iv) — **(ii) is not needed**; machine-checked C2 and the checker's A1/A3 |
| 12 | **Theorem S-H′**, identical-until-bad (§3.3) | **PROVED HERE, in (L0)**; machine-checked C5 and the checker's C3/C4. `Pr^ξ[B]` now carries its convention past an abort (B-10) and the union flag its justification (B-6) |
| 13 | **Claim K-0**: the naive approximate form is false — blow-up `\|C\|` at one round, **`\|C\|²` at two** (§3.4) | **PROVED HERE by counterexample**; machine-checked C4, extended by the checker's C1 |
| 13a | **Claim K-0′**: the correct lossy form `d ≤ Σ_ρ TV_ρ` (§3.4a) — NEW IN THIS REVISION | **PROVED** by (★); the checker verified it is **tight in every row** |
| 14 | **Correction K-1** to the toy memo's "Route B does not need uniform challenges" (§3.4) | **PROVED HERE by counterexample**; machine-checked C6. **NARROWED**: touches no accepted sentence; its novelty is the per-`ρ`-versus-adaptive point |
| 15 | **Corollary S-H″**, augmentation (§3.5) | **PROVED HERE, in (L1)**; machine-checked C8, and by the checker against an **optimal adaptive** distinguisher. The bound is very loose |
| 15a | **Hop 0**, the two-oracle hybrid that makes (iii-a) true (§3.6) — NEW IN THIS REVISION | **AN (L1) HOP**, priced at `Pr[B_sep]`; its price is a count over the incomplete inventory (**GAP S-5**) |
| 16 | Repair 1, the coupling of the biased sampler (§3.6) | **PROVED HERE** for the **rejection-region** coupling named there (a maximal coupling breaks under conditioning). **Read the editor's note**: the ruling's "number unchanged" does not survive this editor's arithmetic, and the question is referred to the security owner |
| 17 | Repair 2, `B_salt` as a witness-free superset of `B_H`'s collision event (§3.6) | **PROVED HERE**; costs nothing — the checker confirms to three decimals |
| 18 | Repair 3, **the owed joint sentence** (§3.6) | **GAP S-1, RE-SIZED: OWED, new mathematics.** (iv′) does **not** follow from the accepted theorems |
| 19 | **Claim S-6**: accepted-receipts-only makes (iv′) trivial at challenge-refused `ρ`; handing over refused prefixes does not (§3.6) | **PROVED HERE**, **CONFIRMED** on one protocol by the checker's D1; the consequence is **GAP S-3** and ruling **K-R5** |
| 20 | hypothesis (i) against the code (§4) | **CODE FACT** at `8c5922b`; **NEEDED** (checker's B1: a non-causal prover has per-`ρ` TV 0 and adaptive TV 1/2) |
| 21 | hypothesis (ii) | **NOT NEEDED** (checker's B2). The soundness appeal is **struck** as a category error; **GAP S-4 re-filed against (iv)'s admissibility set** |
| 21a | hypothesis **(0)**, publicness of the absorbed words (§3.2, §4) — NEW NUMBER IN THIS REVISION | **NEEDED** (checker's B5: adaptive TV 1). **CODE FACT by construction** — the verifier recomputes every absorb — **but not exhaustively read** here |
| 22 | hypotheses (iii-a) … (iii-d) (§4) | (iii-a) is **A HYPOTHESIS, NOT A CODE FACT** (K-R2); the rest **CODE FACT / ASSUMED**, row by row |
| 23 | the terms that drop (§3.8) | **PROVED HERE** — and **one hop is added** |
| 24 | the sums (§5.3) | **COUNTED**; five figures recomputed when the page was drafted, **the whole table recomputed in exact integers by the checker (E1), every row reproducing**; five rows the accepted tables carry are now present; one figure (B4/B6) is not recomputable from its own source |
| 25 | every shape other than the toy, and every 125M figure | **GAP** — G-R1 … G-R4 and R-4 are not touched by this page |

### 6.2 What the NEXT drafter must deliver

The adversarial check has happened (`ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`,
findings B-1 … B-13; **GAP S-6 discharged**). What follows is no longer a
list of attacks but a list of **owed work**, in the order the disposition
puts it.

1. **GAP S-1 — the owed joint sentence (ruling K-R3). This is the one that
   blocks.** Prove, or record as an assumption with its price: *at every
   non-refused challenge vector the joint law of (field view, published
   salts, hash objects, flag) is witness-free, with the blinding uniform
   conditionally on the sampler's good event and the salt segment of the
   stream independent of the blinding segments.* Four documents owe a half
   each (the two field theorems, the two hash lemmas). It is **new
   mathematics, the next paper task**, not an erratum, and it lands on the
   project's own "one candidate with no structural answer". **Point ruling
   R-3's counterexample — two blinding rows with coinciding values — at it,
   and show it fails.**
2. **GAP S-5 — the complete query-class table (ruling K-R2).** Every oracle
   query kind on the toy's path and on a run's path: mode, key, input layout,
   length, and why it is disjoint from every other — **with a test behind
   each row**. §1.3's eleven rows are the starting inventory, not the table.
   Until it exists, hypothesis (iii) is a hypothesis and Hop 0's price is a
   count over an unclosed list.
3. **Hop 0 written into whatever statement uses this lemma** (ruling K-R1).
   It is written here as a hop; a statement that cites this page must carry
   it, and must not describe the result as "no idealisation of the hash".
4. Then, in order: **ruling H-8's one-line test** for finding F-2's one-byte
   margin, and the **two unread challenge-driven refusal classes** (`c_s = 0`
   and `e ∈ {0,1}`) — if either reads `ω` or `w` it becomes a **distance**
   term, not a liveness figure (check B-12); the **absorb count `A`**, which
   no document states and which B4/B6 and B10 both need; and whether
   `B_logup` is really the **only** challenge-reading bad event (the run's
   witness-build class is excluded by the admissibility quantifier — is that
   exclusion airtight when segments are already on disk?).
5. **Open and unanswered by anyone:** whether Route A's ten hops implicitly
   need the same conditional-on-salts sentence. If they do, the "Route B
   needs more" verdict of §5.1 softens.

### 6.3 What this is not

* **Not a privacy acceptance of anything.** D22 is untouched; no run, no
  development rung and no 125M block may be called private on the strength of
  this page.
* **Not a proof that the protocol satisfies hypothesis (iv′).** That is
  Theorem 3.3 / Theorem B × Lemma H / Lemma H^run, cited and not re-proved,
  with their own gaps — and, since ruling **K-R3**, **not even a reduction
  to them as they stand**: the joint sentence of §3.6 Repair 3 is owed and
  is new mathematics.
* **Not a closure of O-4 / G-H1.** O-4 is **REDUCED**. Three things are owed
  before this route can carry a statement: Hop 0 carried into that
  statement, the complete query-class table (**GAP S-5**) and the joint
  sentence (**GAP S-1**).
* **Not soundness.** Transcript-binding collisions, the internal-node /
  salted-leaf ambiguity (ruling L-7) and the Fiat–Shamir soundness loss (FA5)
  are all outside; §3.8 *drops* two terms that a soundness argument would still
  need.
* **Not a statement about timings, memory, power** (D20), **about refusal
  strings** (D21, ruling L-6), or **about a directory without its run
  statement** (M-9).
* **Not a statement about caller-fixed roots** (D8, D11): there the ideal world
  is a simulator that programs oracle points, and §2.4 says why this lemma
  would not be the right tool.
* **Reviewed once, and revised.** One delegated agent wrote it; an independent
  adversarial agent attacked it (`ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`,
  B-1 … B-13); the security owner ruled
  (`ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md`, K-R1 … K-R5); this
  page is the errata pass that applies those rulings. **Neither the check nor
  this pass is a privacy acceptance, and the revised page has not itself been
  re-checked.**

---

## 7. Evidence

### 7.1 This page's own checks — and their one structural weakness

**Read this first (check B-11).** Every protocol in this directory has
exactly **one** challenge round: `rounds = len(rules) − 1 = 1` for C1 … C7,
and C8 has no rounds at all. For a page whose subject is the *sequential*
composition of a multi-round protocol, **the induction is never exercised by
its own evidence.** Two smaller weaknesses: C2 is tautological on instances
built to satisfy (iv) exactly, and C8's bound `q·N/|S|` already exceeds 1 at
`q = 1`, so it cannot fail. §7.2 is where the sequential part is actually
tested.

`results/zk60_sequential_kernel_lemma_hashed/` — `sequential_kernel_hashed.py`
(exact `Fraction` arithmetic, fixed seeds, no dependencies outside the standard
library), `checks.json`, `checks.log`, `README.md`, `timing.txt`.

```
python3 /home/victor/IntelligenceRegulation/results/zk60_sequential_kernel_lemma_hashed/sequential_kernel_hashed.py
```

Runtime **3.72 s**, single core, no heavy lock needed (`timing.txt`).

| check | claim | result |
|---|---|---|
| **C1** | Lemma P (★) | **0 mismatches** over every challenge function of six paired protocols (one salted-leaf model, five random, seeds 1–6; 384–1,152 randomness points each) |
| **C2** | Theorem S-H | max per-`ρ` TV **0** and max adaptive TV **0** on all six |
| **C3** | the joint hypothesis is compulsory with hash parts | over all 256 public `H` on 4 points: marginals witness-free **256/256**; joint witness-dependent **252**; adaptively distinguishable **exactly those 252**; max adaptive TV **1** |
| **C4** | Claim K-0 | per-`ρ` TV `1/\|C\|`, adaptive TV **1**: blow-up **exactly `\|C\|`** at `\|C\| = 2, 4, 8, 16, 32` — **at ONE round; see §7.2 for `\|C\|²` at two** |
| **C5** | Theorem S-H′ | the bound holds — and is **tight** — in every row of C4, with `Pr[BAD]` taken in the adaptive experiment |
| **C6** | Correction K-1 | a constant challenge function drives one witness-dependent refusal to adaptive TV **1** at `\|C\| = 4, 8, 16`; the mean over 200 random challenge functions is 0.658 / 0.321 / 0.163, halving with `\|C\|` |
| **C7** | hypothesis (iii-a) is load-bearing | shared challenge/refill query point: TV **1** (the witness is recovered); separated: TV **0** over all 256 challenge functions |
| **C8** | Corollary S-H″ | exact advantage 1/4 (`\|S\|=2`) and 1/8 (`\|S\|=4`) at `q = 1, 2`, always below `q·N/\|S\|`; **0** at `q = 0` |

Two modelling conventions are stated in the README because they are
load-bearing: in C1/C2/C7 the oracle tables are the prover's randomness and are
**not** in the view (the `q = 0` case; C8 prices `q > 0` separately, which is
exactly how §3.2 and §3.5 divide the work); in C3 the function `H` is
**public**, because there the hashed value is one the protocol goes on to
publish.

**What the evidence does not do.** It checks an inference on finite toy
protocols. It touches no ZK60 code, replays no receipt, and establishes
nothing about any shape.

### 7.2 The checker's evidence — the multi-round work, cited as the checker's

`results/zk60_sequential_kernel_lemma_hashed_check/` —
`adversarial_kernel_check.py`, `checks.json`, `checks.log`, `README.md`.
Exact `Fraction` arithmetic, standard library only, fixed seeds, about 80 s,
**nothing reused from this page's script**.

```
python3 /home/victor/IntelligenceRegulation/results/zk60_sequential_kernel_lemma_hashed_check/adversarial_kernel_check.py
```

Where the exhaustive family of schedules exceeds 4,096 the sweep is a
fixed-seed uniform sample of 4,096 **plus** four named adversarial schedules
— constant, **hash-part-only**, field-bit-encoding, round-parity — added
unconditionally so a sample cannot miss them: 4,101 schedules per protocol.

| check | what it attacks | result |
|---|---|---|
| **A1/A3** | **the lemma survives the sequential part**: (★) and Theorem S-H at **two and three** challenge rounds, every completion of a truncated `ρ` | two-round `(field, hash)` protocols (256 `ω`, 20 challenge slots, two variants) and a three-round protocol with a challenge-driven abort (16 `ω`, 34 slots), **4,101 schedules each**: **0 path-identity mismatches**, max per-`ρ` TV **0**, max adaptive TV **0** |
| **A2** | the identity with an early abort, under both games | **0 mismatches**, 64 schedules; both games inherit the conclusion |
| **B1** | is **(i) causality** needed? A prover reading the challenge that follows its own message | per-`ρ` TV **0**, adaptive TV **1/2** — **(i) is NECESSARY.** This page never tested it |
| **B2** | is **(ii) the witness fixed before `m_0`** needed? Two adaptive witness sources | per-`ρ` TV 0 and adaptive TV **0** — **(ii) is NOT NEEDED** |
| **B3** | is **(iii)** all-or-nothing? | one leaked bit of `ω` into `ξ` gives adaptive TV **1** while (iv) holds at every `ρ` — **(iii) cannot be priced as a bad event** (this is K-R1's reason) |
| **B4** | (iv) with marginals only | fails: per-`ρ` TV 1, adaptive TV 1 |
| **B5** | the unnumbered hypothesis: `χ` must read only the **public** prefix | per-`ρ` TV **0**, adaptive TV **1** when `χ` reads one unpublished absorbed word — **hypothesis (0) is NECESSARY** |
| **C1/C2** | the naive approximate form at **two** rounds | blow-up **`\|C\|²`** — ×4, ×9, ×16 at `\|C\| = 2, 3, 4` — and the correct lossy form `d ≤ Σ_ρ TV_ρ` holds and is **tight in every row** (§3.4a) |
| **C3** | S-H′ with a **non-adapted** flag | (iv′) holds; **0 violations in 256 checks** over every schedule × every completion; but `Pr^ξ[B]` is 1/2 under one completion and 1 under another — hence §3.3's convention |
| **C4** | the pair-dependent flag `B = B_w ∪ B_{w′}` | union flag: slack **0**. Single-world flag: bound **VIOLATED by 3/8**. **The factor 2 is forced** |
| **D1** | claim **S-6**, and the abort probability as a channel | one protocol: (iv′) holds at every `ρ` under accepted-receipts-only and **fails** under prefixes, adaptive TV 0 vs **1**. Separately, a masked prefix with a witness-dependent refusal *rate* has adaptive TV **1/2** = the rate gap |
| **D2** | S-H″ against an **optimal adaptive** distinguisher | bound holds at `q = 0, 1, 2` and `\|S\| = 2, 4`; and it is loose (`q·N/\|S\| > 1` at `q = 1`) |
| **E1** | every number in §5.3, recomputed in exact integers | all reproduce; totals **2^-77.6808** toy, **2^-69.2906** run; one figure (B4/B6) not recomputable from its source |

**Where the checker attacked hardest and found nothing** — recorded because
a page that only lists its wounds is not honest either: Lemma P part 3 is a
genuine **set** equality, not merely an equality of probabilities, and
nothing in it cares that `χ_j` reads the hash part of `m_j` nor that the hash
part is an oracle image of `ω`'s salts; the one line doing the real work,
`Σ_m Pr_ω[F(w,·,ρ^ξ(m)) = m, B] = Pr^ξ_w[B]`, has no double- or
under-counting, including when two different `ω` give the same transcript;
the identity is insensitive to the completion of `ρ` past an abort in both
games; the `Q_pub`/`Q_hid` split and the "randomized functions do not
increase total variation" step survive adaptive querying; dropping B3/B5 and
B4/B6 is legitimate and for exactly the reasons given; **Repair 2 is exactly
right and costs nothing**; Corollary S-H′a's taxonomy is "the right
organising idea on the page"; and the negative findings K-0, C6 and C7 all
reproduce, C7's point being *stronger* than this page stated.

### 7.3 What no evidence on this page does

It checks an inference on finite toy protocols. It touches no ZK60 code,
replays no receipt, and establishes nothing about any shape. In particular
**nothing here bears on whether Lemma H / Lemma H^run is true** — they are
(H6) / (H6^run), statements inside an assumed model — nor on the exhaustive
reading of hypothesis (0), nor on anything at 125M.

---

## 8. Circularity check

| section | what it assumes | where that is concluded | circular? |
|---|---|---|---|
| §3.1 Lemma P | (0) and (i) only | Definition 1.1 and §1.4; §4 rows (i) and (0)/(iii-d) read them off the code | no |
| §3.2 S-H | (0), (i), (iii), (iv) — **not (ii)** | (iv) is §3.6, which uses nothing from §3.1–§3.5 | no |
| §3.3 S-H′ | (0), (i), (iii), (iv′) | same | no |
| §3.4 K-0/K-0′/K-1 | nothing (counterexamples, and (★) for K-0′) | — | no |
| §3.5 S-H″ | the view-level conclusion + (L1) freshness | §3.3; the model is declared at §1.3 | no |
| §3.6 **Hop 0** | (L1), and §1.3's inventory of query kinds | §1.3 — **and the inventory is incomplete, GAP S-5** | no, but **not closed** |
| §3.6 assembly | Theorem 3.3 / B, Lemma H / H^run, M-3 or the non-adaptive-refill argument | four other documents, all of which are *fixed-challenge* statements and none of which cites this page | no |
| §3.7 pricing | (L1) | §1.3 | no |
| §4 | the code at `8c5922b` | read here | no |

The one place a loop could hide is §3.6 Repair 3: it asks the fixed-challenge
theorems for a statement *conditional on the salts*, and the salts are objects
the hash-layer lemma also speaks about. The two uses are disjoint — Theorem 3.3
is asked only to hold with the salts held fixed, and Lemma H is asked only
about the conditional law of the hash objects **given** the field view. No
statement is used to prove itself, so there is **no loop**.

**But the first draft's next words — "*a bookkeeping gap*" — are withdrawn
(ruling K-R3).** The absence of a loop is not the absence of work. GAP S-1 is
**new mathematics**, owed by four documents, landing on the project's one
candidate with no structural answer. The circularity check says the argument
is well founded; it does not say the argument is finished.

---

### Gaps, by name

Names are unchanged. Three are re-sized, one is re-filed, one is discharged;
nothing has been deleted.

| name | status after the check | what is missing | who owes it |
|---|---|---|---|
| **GAP S-1** | **RE-SIZED — OWED, NEW MATHEMATICS** (ruling K-R3). The first draft called it "one sentence, bookkeeping"; it is not | the **joint sentence** of §3.6 Repair 3, printed there in full: at every non-refused `ρ`, the joint law of (field view, published salts, hash objects, flag) is witness-free, with the blinding uniform conditionally on the sampler's good event and the salt segment of the stream independent of the blinding segments. **Four halves**, not two: `ZK60_JOINT_LAW_COMPOSITION.md`, `ZK60_JOINT_LAW_COMPOSITION_RUN.md`, `Lemma H`, `Lemma H^run`. It rests on assumption **M-3** in its two-sided whole-stream form (ruling C-3) — the block memo's §5.3 row 6, "the one candidate with no structural answer" — and at a run on **G-R4**. Ruling **R-3**'s counterexample (two blinding rows with coinciding values) is what it must defeat | the owners of those four documents; **it is the next paper task** |
| **GAP S-2** | unchanged | the per-`ρ` hypothesis for pairs is only as good as Theorem 3.3 / Theorem B; at a run those carry **G-R1, G-R2, G-R4** and at 125M **G-R3 (blocking)** | unchanged, not this page |
| **GAP S-3** | unchanged, and **promoted to a condition of any run statement** by ruling **K-R5** | **accepted receipts only** — a refusal publishes nothing — is a code fact for a block and, for a run, operating rule **M-9** with **no production code behind it** (ruling H-2). If refused prefixes reach the adversary, hypothesis (iv′) at a challenge-refused `ρ` is supplied by nothing, and the checker's D1 shows the conclusion then fails on a real instance | the integrator (the run wrapper) |
| **GAP S-4** | **RE-FILED against hypothesis (iv)**, not (ii) (check B-8) | `RunWitnessSource` permits an adaptive source (`run.rs:500`, `:512` inside the loop) — condition **C-R3**, enforced by nothing. It is **not** a failure of hypothesis (ii), which is not needed; it is that **Theorem B is stated only for an admissible run input (ruling R-1.1)**, so an adaptively assembled chain is outside its quantifier. *(The first draft's binding/soundness argument for the interior is struck as a category error.)* | the integrator (a `RunWitnessSource` handed the whole chain at construction) |
| **GAP S-5** | **RE-SIZED** to carry ruling **K-R2** | **the complete query-class table**: every oracle query kind on the toy's path and on a run's path — mode, key, input layout, length, and why it is disjoint from every other — **as a document with a test behind each row**. §1.3's eleven rows are the inventory, not the table. It subsumes the old contents of this row: the untagged conditions **C-H4**, **C-H4′** (false crate-wide), the run's **C-R1**, **C-R2**, finding **F-2**'s one-byte margin at the 125M run profile, the withdrawal of claim **N5**, the 64-byte keyed seed derivation at `endpoint_g.rs:224`, and the position tag's repeated squeeze inputs | the 125M lane (one-line tests, ruled by **L-3** and **H-8**) plus whoever writes the table |
| **GAP S-6** | **DISCHARGED** | this page had not been independently checked. It has been: `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`, findings B-1 … B-13, with its own evidence directory. **The revised page has not been re-checked**, which is a smaller and different obligation | — |

---

---

## 9. What the check changed

One line per finding of `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`, with
where it landed on this page. **Nothing that survived has been softened, and
no finding has been dropped.**

| finding | what it said | what changed here |
|---|---|---|
| **B-1** (serious) | `B_sep` sits inside the (iv′) bad event, where it cannot live: an overlap of the two query classes is a failure of hypothesis (iii), consumed at "Fix `ξ`", and one leaked bit is already fatal | **Accepted in full (ruling K-R1).** `B_sep` removed from `B` in §3.6, §3.9, §5.3; **Hop 0** written as an explicit (L1) hybrid at the same price; the one-bit-leak table printed in §2.2; §3.2 note 4 says where (iii) is consumed; §3.8 now says "one hop is added" |
| **B-2** (serious) | the enumeration of the prover's oracle queries is incomplete on the production path — the 64-byte **keyed** seed derivation, the transcript constructor, the unkeyed digest family, two test-only 40-byte constructors, the position tag's repeated squeeze inputs; claim N5 false crate-wide | **Accepted in full (ruling K-R2).** §1.3's five-way partition replaced by an eleven-row **incomplete** inventory with what separates each and what pins it; the 64-byte seed derivation **re-verified here at `8c5922b`** (domain literal 42 bytes, 22 + 42 = 64, `endpoint_g.rs:45`, `:224`, twice per block from `private_block.rs:755-757`); **claim N5 withdrawn as stated**; **GAP S-5 re-sized** to the owed table with a test behind each row; §4 row (iii-a) downgraded from CONDITIONAL code fact to **hypothesis** |
| **B-3** (serious) | GAP S-1 is under-sized and the reason for believing it is the reason it is missing: the accepted theorems are field-only, their space excludes the published salts, and salt/blinding independence is the project's "one candidate with no structural answer" | **Accepted in full (ruling K-R3).** §3.6 Repair 3 rewritten with the three documentary reasons quoted, the **owed sentence printed** in both the disposition's and the checker's wording, four owers named, R-3's counterexample named as what it must defeat, "immediate" struck; §8's "bookkeeping gap" withdrawn; **every "closes O-4 / G-H1" now reads "reduces"** |
| **B-4** (medium) | Repair 1 is correct for the rejection-region coupling only; a maximal coupling breaks under conditioning, and the memo does not say which it means | **Accepted, with a dissent.** §3.6 Repair 1 now names the rejection-region coupling and says why a maximal one fails (H5 must survive the conditioning). **But see the editor's note there**: the check's "the number is unchanged" is arithmetically wrong — the rejection coupling costs `r/2^128 = 2^-64` per draw, not the total variation `2^-96`, and `Pr[B] ≥ r/2^128` is forced for any event form. Referred to the security owner; no number changed here |
| **B-5** (medium) | "none is added" is measured against a tally that is not the project's: five rows missing | **Accepted (ruling K-R4).** §5.3 gains constructor-vs-absorb **2^-128.00**, tag-key collision **2^-249.96**, key collision **2^-252.42**, leaf-input = node-input **2^-484.83** and the generic-rank term **`Δ_gr` (0, or ≈ 2^-56 on the fallback)**, each with whether it drops under Route B; totals unchanged; the non-recomputable B4/B6 row named as a gap in its source |
| **B-6** (medium) | the memo carries both sides of the one-bit LogUp trap and attributes the doubled figure to a ruling that has no factor 2 | **Accepted (ruling K-R4).** Both figures kept and labelled: ruling S-4's **one-world** `768/p²` = 2^-118.42 / `12·768/p²` = 2^-114.83, and the **two-world union** 2^-117.42 / 2^-113.83 that a distance bound forces. §3.3 carries the reason (single-world flag violates the bound by **3/8**); §2.5, §3.7 R-a and §5.3 use the same convention; the S-4 attribution corrected; D22's "2·2^-112.0" corrected to "up to 2^-112" |
| **B-7** (medium) | a needed hypothesis is unnumbered: every absorbed word must be public | **Accepted (ruling K-R4).** **Hypothesis (0)** added to Theorem S-H and S-H′, with the checker's counterexample (adaptive TV 1 at per-`ρ` TV 0) and a code match showing the verifier recomputes every absorb (`protocol.rs:113-123`, `:490`, `:978`, `:150-154`, `:841`, `:860`, `:868`, `transcript.rs:82-99`; `run.rs:302-321`, `:599`, `:640-641`, `:645`); §4 row (0)/(iii-d) marked **not exhaustively read** |
| **B-8** (medium) | (ii) is not needed, and the soundness appeal is a category error; S-4 is a gap in (iv) | **Accepted (disposition §1).** (ii) marked **NOT NEEDED** in §3.2 with the measurement; the remark says the honest prover's witness is fixed by the game's quantifier; the binding/soundness sentence **struck** from §4 row (ii); **GAP S-4 re-filed against (iv)'s admissibility set** in §4, §5.2 and the gap table |
| **B-9** (medium) | "proved in a weaker model (L0)" is oversold: (iv′) is itself (L1), and (iii) needs one more hop | **Accepted (ruling K-R1).** The headline rewritten in §0, §1.3, §3.2, §3.3, §3.7 (heading and new row **R-d**), §3.8, §3.9 and §5.1; §5.1 now prints the trade ("until S-1 is discharged, Route B rests step 5 on **more**"); §3.8 corrected — the squeeze counter's distinctness is also needed for **R-a** |
| **B-10** (medium-low) | `Pr^ξ[B]` is undefined past an abort — a factor-2 ambiguity, no soundness hole | **Accepted (ruling K-R4).** §3.3 carries the convention: `B` adapted, or any fixed completion, with (iv′) quantified over all of `C^N` and the smallest completion sharpest; the checker's 1/2-versus-1 measurement is cited |
| **B-11** (low) | the machine evidence never leaves one challenge round; and two positive additions — `\|C\|²` at two rounds, and the tight lossy form | **Accepted (ruling K-R4).** §7 split: **§7.1** opens by admitting the one-round weakness (and C2's tautology, C8's vacuous bound); **§7.2** is the checker's directory in full — A1/A3 at two and three rounds, 4,101 schedules, 0 mismatches; the per-hypothesis necessity results B1/B2/B3/B4/B5; C1's `\|C\|²`; C3, C4, D1, D2, E1 — plus what the checker attacked and found nothing on. **§3.4a** prints the lossy form `d ≤ Σ_ρ TV_ρ` as new claim **K-0′** |
| **B-12** (low) | S-6 confirmed and sharpened; and under accepted-receipts-only the abort *indicator* is inside the view; two of the four challenge-driven refusals were never read | **Accepted (ruling K-R5).** §1.5 rewritten, carrying the refusal-rate channel (adaptive TV **1/2** = the rate gap) and the statement that the abort probability is priced separately by the refusal terms; §2.5's liveness row now records that only `check_opening_challenges`'s two are read (`protocol.rs:283-294`) and that **`c_s = 0` and `e ∈ {0,1}` are unread**; §6.2 item 4 owes that reading |
| **B-13** (low) | citation and vocabulary defects: the G-H1 label, "Game ⊥"/"Game prefix" as private coinages, the S-4 attribution, D22's "2·2^-112.0", and what supports the refusal clause under Route B | **Accepted (ruling K-R4).** The G-H1 citation corrected in the header and §5.2; **§1.5 defines both game names at first use as this page's shorthand for the project's accepted-receipts-only (D21, M-9)** and says they appear in no other document; the S-4 attribution and the D22 parenthetical corrected; §5.1 gains the row saying the accepted refusal clause's word "random" is supplied by **R-a** under Route B, needing (L1) **and** squeeze-input distinctness |

---

*Drafted by a delegated Opus agent (2026-09-21, 01:14–01:45), attacked by an
independent adversarial agent (01:42–02:30), ruled on by the security owner
(02:19), and revised by an errata editor to those rulings (02:20–03:05).
Nothing here establishes a privacy property. The lemma is proved with
changes; condition O-4 is reduced, not closed; the revised page has not
itself been re-checked.*
