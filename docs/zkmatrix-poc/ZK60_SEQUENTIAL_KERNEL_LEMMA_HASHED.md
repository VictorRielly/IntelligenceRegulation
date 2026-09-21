# The sequential-kernel lemma for (field, hash) message pairs — condition O-4 / gap G-H1

| | |
|---|---|
| Author | **Drafted by a delegated Opus agent for the security owner** |
| Written | 2026-09-21, 01:14 – 01:45 PDT (`date` read at the start and at the end) |
| Occasion | the one step of the privacy path that has never been closed: the **sequential composition** of a multi-round Fiat–Shamir protocol's per-challenge joint-law statement into a statement about the whole hashed view. Left open at the toy as condition **O-4 / Route B** (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3); ruled last night to be **the** remaining gap for a run as well (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §3, gap **G-H1**) |
| Code read | lane `zk60-private-block-125m` at **`8c5922b`**, read-only, via `git show`. Every code fact below carries `file:line` at that commit |
| The lemma it extends | `ZK60_MVP_JOINT_VIEW.md` §1.2 and `tests/test_zk60_sequential_kernel.py`, **branch `zk60-mvp-fable` only**, for **field** messages |
| Evidence | `results/zk60_sequential_kernel_lemma_hashed/` — `sequential_kernel_hashed.py`, `checks.json`, `checks.log`, `README.md`. Exact rational arithmetic; eight checks; six generic random instances with fixed seeds and five deliberately adversarial ones |
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

This page writes that step. Its three findings, in plain words:

1. **The composition itself needs no idealisation of the hash at all.** It
   needs one thing: that the function answering the challenges is *independent
   of the dice the prover rolls*. Given that, there is a one-line identity
   (§3.1) that makes the whole composition go through for **any** challenge
   function whatever — hash, constant, adversarial. That is stronger than the
   project's Route A, which replaces the challenges by uniform values inside
   the random-oracle model.
2. **The obvious approximate version of the lemma is FALSE**, and the way it
   fails is the way a real attack would work. "The per-challenge laws are
   within δ" does **not** give "the real law is within δ": the error can
   multiply by the number of challenge values (§3.4, machine-checked at five
   sizes, blow-up exactly `|C|`). The correct form conditions on a **bad
   event** and prices that event **in the real experiment**, not per challenge
   (§3.3).
3. **Because of 2, the lemma as the project stated it is false for the
   protocol as built** — by one hair, and the hair is the one input-dependent
   refusal the project already tracks (the zero LogUp denominator). For an
   *arbitrary* challenge function an adversary can steer that refusal to
   certainty (§3.4, check C6). What is true is the lemma with that refusal
   inside the bad event, and the bad event can only be priced by saying
   something about the actual challenge function — which is where, and **only**
   where, the random-oracle model comes back in. The toy memo's sentence
   "Route B … does not need the challenges to be uniform" is corrected here
   (§3.4, correction **K-1**).

What the project gets: O-4 becomes a **proved lemma with three named gaps**
instead of a missing lemma (§5). Two error terms of Route A disappear and none
is added; **no residual total moves** — the toy stays at about 2^-77.7 and a
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

**The result of this page:** the **composition** (§3.1–§3.4) is proved in
**(L0)**. (L1) is needed for exactly three things, all of them *pricing*
(§3.7): the distinguisher's oracle access, the separation of the two query
classes at an untagged profile, and the one witness-dependent refusal class.
(L2) or (L1) supplies hypothesis (iii-b).

Concretely, in (L1) the oracle's query space is partitioned into

* the **transcript class** `T` — every input the challenge chain makes. At an
  untagged profile these are the absorbs (`state(32) ‖ le64(|label|) ‖ label ‖
  le64(|data|) ‖ data`, so `≥ 48 + |label| + |data|` bytes,
  `transcript.rs:59-68`) and the squeezes (`state(32) ‖ "squeeze"(7) ‖
  le64(counter)(8)` — **exactly 47 bytes**, `transcript.rs:101-112`). At a
  tagged profile they are the queries of the keyed function `F_T`;
* the **prover class** `P` — the salted-leaf inputs (`digest ‖ salt`, 64 bytes,
  `pcs.rs:677`, `:691`), the Merkle node inputs (64 bytes), the column digests
  (`8·rows` bytes, `pcs.rs:138`, `:148`), and the generator's refill inputs
  (`key(32) ‖ le64(counter)(8)` — **exactly 40 bytes**, `rng.rs:53-61`). At a
  tagged profile, the queries of `F_L`, `F_N`, `F_C` and of the unkeyed `F_U`.

`ξ := O|_T`, the restriction of the oracle to the transcript class. A random
oracle's restrictions to **disjoint** input sets are independent random
functions; that — not an extra assumption — is what supplies (iii-a), at the
price of the overlap events counted in §3.7.

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

### 1.5 The two abort games

A refusal is **terminal**: `prove_with_stats` calls `prove_inner` once, the
endpoint owners are consumed by value and `PreparedPlane` has no `Clone`
(ruling **J-4**). There are two games one could define, and they differ:

> **Game ⊥** (the one the project's statements use, decision **D21** and
> operating rule **M-9**): on a refusal the adversary gets `⊥` and nothing
> else — no receipt, no segment, no partial run directory, no refusal reason.
>
> **Game prefix**: on a refusal the adversary gets everything published before
> it.

The lemma below covers **both** (`⊥` is a message value with no continuation).
But the two games need hypothesis (iv) on different sets — see §3.6, claim
**S-6**, which is a finding: under Game ⊥ the hypothesis is *trivially* true at
every challenge-refused `ρ`, and under Game prefix it is an unproved
obligation that no project document supplies. For a block, Game ⊥ is a code
fact (`prove_inner` returns `Err`, no receipt exists). For a run it is
**operating rule M-9**, which ruling **H-2** records has **no production code
behind it** at `8c5922b` (`prove_run` has no production caller;
`verify_then_write` is test-only).

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

The derivation is §1.3's partition: `χ` reads only `O|_T`, the prover's hash
parts read only `O|_P`, and `T ∩ P = ∅` makes the two independent. Two things
must then be paid for:

* **the classes might overlap.** At the untagged toy exactly one input is in
  both: `absorb_u64(b"log-cols", ·)` is `32 + 8 + 8 + 8 + 8 = 64` bytes, the
  node-and-salted-leaf length. Counted at **2^-241.42**
  (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §1.5). At a tagged profile the overlap is
  *assumed* away by D19a rather than counted — the run memo says so itself
  (§2.2: "the bound got shorter because the model got stronger, not because
  anything was measured");
* **the generator sits inside the prover class and carries a secret.** Its
  refill input is 40 bytes in the **unkeyed** function (`rng.rs:53-61`; ruling
  **H-3** — two of the security owner's own documents had this wrong). "40
  bytes is used by nothing else on this path" is therefore load-bearing, at the
  toy and at a run alike (run memo §2.3, claim N5).

**Check C7 shows this is not bookkeeping.** In a two-message toy where the
challenge query point *coincides* with the generator's refill point, the
challenge equals the prover's pad, `m_1 = pad + w` is opened by subtraction and
the distinguisher recovers `w` with certainty: **TV = 1**. With the two classes
separated, **TV = 0** over all 256 challenge functions. The whole of
hypothesis (iii-a) is in that one line.

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
set out and discharged in §3.6: the idealisation must become an **event**
(coupling), `B_H` must be replaced by a **witness-free superset** so the
sub-measures can be compared, and the two theorems must hold **conditionally
on the salts**. None of the three is hard; none had been written.

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
| **challenge-driven** (`c_s = 0`; `e ∈ {0,1}`; a zero group coefficient; a dependent proximity pair — `protocol.rs:246`, `:282-292`; rate `4/p ≈ 2^-62.0` per opening, `(3L+1)/p = 2^-58.79` at `L = 12`) | functions of `ρ` **alone**, so the refusal is the same event in both worlds. Under **Game ⊥** hypothesis (iv) is trivially true at such `ρ` (both worlds output `⊥`); under **Game prefix** it is not supplied by anything (claim **S-6**). A **liveness** figure, never a distance |
| **the one input-dependent class**: a zero LogUp denominator (`protocol.rs:403`), at most 768 distinct inverted arguments per block at every shape (ruling **S-4**) — `2^-118.4` per block, `2^-114.8` for a twelve-block 125M run | hypothesis (iv) **fails** at the `ρ` where it fires. It goes into the bad event, and pricing it **requires** saying something about the actual challenge function — §3.4 and §3.7. This is the single place where the "arbitrary challenge function" reading of O-4 is *false* |

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

> **Lemma P.** Assume (i) causality. Fix `w`, `ω` and `ξ`.
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
> rational laws over every challenge function of six paired protocols.

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
> * **(i) causality** (Definition 1.1);
> * **(ii) the witness is fixed before `m_0`**: `w` is a parameter of the
>   experiment and is not a function of `ξ` or of any published value;
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
> **PROVED HERE, in model (L0) — no idealisation of the hash is used.**
> **Machine-checked: C2.**

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

### 3.3 Theorem S-H′ — the identical-until-bad form (the one the project needs)

Hypothesis (iv) never holds exactly for the real prover: the blinding is
slightly biased, the hash layer's kernel holds only off `B_H`, and one refusal
class is witness-dependent. The correct approximate form is **not** a
total-variation hypothesis (§3.4 shows why) but a bad-event one.

> **Theorem S-H′.** Assume (i), (ii), (iii), and
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
> **PROVED HERE, in model (L0).** **Machine-checked: C5** (the bound holds and
> is tight in every row of C4).

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
> fire always: adaptive distance **1**. Measured blow-up: exactly `|C|`.
>
> The same instance satisfies S-H′ with `B = {r_0 = u}`: `Pr^ξ[B] = 1` under
> the steering schedule and `1/|C|` under a constant one, and the bound of
> §3.3 holds with equality in both. **The bad event has to be priced in the
> adaptive experiment; that is the whole content of the correct form.**

> **Correction K-1, to `ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3.** That page says
> "Route B is stronger in one way — **it does not need the challenges to be
> uniform** — and weaker in another: it needs the per-`ρ` hypothesis at *every*
> `ρ`". The first half is right about the **composition** and wrong about the
> **statement as a whole**, and the two halves are the same fact seen from two
> sides. Because the protocol has one witness-dependent refusal class,
> hypothesis (iv) fails at some `ρ`; S-H′ then applies with that class in `B`;
> and `B` reads the challenges, so by Corollary S-H′a its probability **cannot
> be bounded without a property of `χ`**. For an arbitrary `χ` it is not small.
>
> **Check C6** makes this concrete on the LogUp shape: a protocol that refuses
> iff the challenge equals a hidden-data-determined value `g(w)`. A **constant**
> challenge function `χ ≡ g(w_0)` gives adaptive distance **1** at every
> `|C| ∈ {4, 8, 16}`; over 200 random challenge functions the mean distance is
> 0.658 / 0.321 / 0.163 — halving as `|C|` doubles, i.e. of order `1/|C|`,
> which is the union bound the project already carries.
>
> **So the honest reading of O-4 is: the composition is unconditional, and the
> random-oracle model is needed for exactly one line of arithmetic** — bounding
> `Pr^ξ[B]` for the `χ` the code actually uses. That is a much smaller
> dependence on D19 than Route A has, and it should be stated as such rather
> than as "no uniformity needed".

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
> `|S| = 2, 4`, always under the `q·N/|S|` bound.

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
cited and **not** re-proved.

> **Claim S-5 (assembly).** Take
> `B := B_samp ∪ B_salt ∪ B_sep ∪ B_logup` with
> * `B_samp` — the **coupling failure** of the prover's real blinding stream to
>   a uniform one;
> * `B_salt` — **two salts of the run coincide**;
> * `B_sep` — a transcript-class query input equals a prover-class query input;
> * `B_logup` — the zero-LogUp-denominator refusal fires in either world.
>
> Then (iv′) holds, given: **Theorem 3.3 / Theorem B** with their travelling
> conditions; **Lemma H / Lemma H^run**; and the three repairs below.
>
> **REDUCED** to those documents, **plus GAP S-1** (one sentence owed by each
> of their owners).

**Repair 1 — the idealisation becomes an event (PROVED HERE, elementary).**
Theorem 3.3 is stated in the uniform-blinding idealisation; S-H′ needs an
event, not a distance. `fp()` reduces a uniform 128-bit integer mod `p`
(`rng.rs:73-77`), a law at total-variation distance exactly `2^-96` from
uniform on `Fp`. By the coupling lemma there is, for each draw, a coupling of
the real draw and a uniform one that agree except with probability `2^-96`;
the draws are independent ranges of one stream, so the product coupling fails
with probability at most `(#draws)·2^-96`. Define `B_samp` as that failure.
Numerically it **is** decision **D9**'s term, unchanged: `327,052·2^-96 =`
**2^-77.7** for one toy proof; `109,728,784·2^-96 =` **2^-69.29** for a
twelve-block 125M run (ruling **H-6**'s post-repair count). `bytes32()` needs
no coupling: it is raw stream output (`rng.rs:93-99`). **`B_samp` is a
function of `ω` alone**, so by Corollary S-H′a it costs the same under every
challenge schedule.

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

**Repair 3 — the field theorems must hold conditionally on the salts
(GAP S-1).** The assembly multiplies `law(V | ρ, NR, w)` by the hash kernel and
intersects with `¬B`. For that to be legitimate one needs
`law(V, 1_{¬B} | ρ, w)` witness-free, not only `law(V | ρ, w)`. Since `B_samp`
and `B_salt` are functions of the prover's randomness *other than the blinding
values whose law Theorem 3.3 is about*, this follows **provided the salt draws
and the blinding draws are independent** — which is assumption **M-3**
(primary) or the in-model non-adaptive-refill argument (alternative), and at a
run is precisely gap **G-R4** (cross-role blinding independence over `4L + 1`
roles on one stream, "to be machine-asserted", ruling **R-3**). The field view
never mentions a salt, so I believe the conditional form is immediate; **but
it is not written in either document, and I will not write it for them.**
*What is owed is one sentence in each: "the theorem's randomness is the
blinding stream, and the statement holds conditionally on the salts, which are
independent of it."* **GAP S-1.**

> **Claim S-6 (the abort game decides a quantifier) — PROVED HERE.** Under
> **Game ⊥**, hypothesis (iv′) at a `ρ` on which the **challenge-driven**
> refusal fires is trivial: both worlds output `⊥` with probability 1, so the
> sub-measures agree without any appeal to Theorem 3.3 — which is fortunate,
> because Theorem 3.3 is conditioned on `NR` and says nothing there. Under
> **Game prefix** the truncated view at a refused `ρ` would have to be shown
> witness-free, and **no project document supplies that**. So the project's
> choice of Game ⊥ is load-bearing for this lemma, and Game ⊥ rests, for a
> run, on operating rule **M-9**, which ruling **H-2** records as having **no
> production code behind it** at `8c5922b`.

### 3.7 Where the random-oracle model enters — and only there

Collecting §3.3's taxonomy, exactly three quantities need (L1):

| # | quantity | why (L0) cannot do it | size |
|---|---|---|---|
| **R-a** | `Pr^ξ[B_logup]` — the witness-dependent refusal, in the adaptive experiment | reads the challenges; for an arbitrary `χ` it is not small (check C6) | with `χ` a random oracle: `2·768/\|Fp2\|` = **2^-117.42** per block (ruling S-4); `2·L·768/\|Fp2\|` = **2^-113.83** at `L = 12`. *(D22's own statement carries the coarser raw count, 2·2^-112.0.)* |
| **R-b** | `Pr[B_sep]` — the two query classes overlap | a statement about the hash's inputs, not about the composition | untagged toy: **2^-241.42** (the 64-byte absorb, §1.5 of the toy memo). Tagged: **0 by D19a**, i.e. assumed, not measured |
| **R-c** | `ε_hit(q)` of Corollary S-H″ | needs freshness of unqueried oracle points | `q·N_leaf·2^-256` = **2^-114.42** (toy) / **2^-106.76** (125M `L = 12`) at `q = 2^128`; plus `ε_gen(q) ≤ 6q·2^-256` = 2^-125.42, or M-3 |

Everything else in the lemma is (L0). In particular the **composition** —
the part O-4 asked for — is model-free.

### 3.8 What the lemma does **not** need (and what therefore drops out of the tally)

| Route A needs | Route B (this lemma) | why |
|---|---|---|
| **B3 / B5**, the distinguisher pre-querying a challenge point (`q·4,000·2^-256` = 2^-116.03 at the toy; `q·A·2^-256` = 2^-110.52 at 125M `L = 12`) | **not needed** | the conclusion holds for **every** realization of `ξ`, so knowing part of `ξ` in advance is worth nothing |
| **B4 / B6**, two absorb inputs colliding (2^-233.07 toy; 2^-222.04 run) | **not needed** | `χ_j` is a function of the *prefix* whatever the state chain does; collisions are a **soundness** matter (the transcript's binding), and this page says nothing about soundness |
| the squeeze counter making every challenge input distinct (`transcript.rs:107`) | **not needed** for the composition | same reason; it is still needed for R-c's book-keeping and for soundness |
| "replace every challenge by a uniform value drawn in advance" (hop G_6 → G_7) | **not needed** | there is no hop; `ξ` is conditioned on, not replaced |
| lazy sampling of the whole oracle (hop G_0 → G_1) | needed only inside Corollary S-H″ | the composition never chooses an answer after the fact |
| oracle **programming** | **not needed** | the ideal world is the honest prover on the all-zero input (D18-A). Under D8/D11 this changes completely — §2.4 |

**Two terms leave the tally and none joins it.** No total moves: at the toy the
sum is still **2^-77.7** and at a twelve-block 125M run still **2^-69.3**,
both of them decision D9's sampler bias and nothing else (§5.3).

### 3.9 The lemma in one box

> **Theorem S-H′ applied to this protocol.** In model (L0), for every
> challenge schedule, and for `B = B_samp ∪ B_salt ∪ B_sep ∪ B_logup`,
>
> ```
> d( view_w , view_0 )        ≤  ½ ( Pr^ξ_w[B] + Pr^ξ_0[B] )
> d( AV_w  , AV_0  )          ≤  ½ ( Pr^ξ_w[B] + Pr^ξ_0[B] )  +  ε_hit^w(q) + ε_hit^0(q)
> ```
>
> with the four components of `B` and `ε_hit` sized in §3.6 and §3.7, under
> hypotheses (i), (ii), (iii-a), (iii-b), (iv′) — matched against the code in
> §4 — and conditional on Theorem 3.3 / Theorem B, Lemma H / Lemma H^run and
> their own open conditions.

---

## 4. The hypotheses against the protocol as built (`8c5922b`)

| hyp. | what it demands | where it holds, at `8c5922b` | status |
|---|---|---|---|
| **(i) causality** — `m_j` a function of `(w, ω, r_{<j})` only | every published object is computed before the challenge that follows it | **block**: `protocol.rs:662` (`A` committed) → `:666` (absorbed) → `:676` (`M`) → `:682-684` (`β, γ, α`) → `:770-775` (`H`) → the 23 slots → `:790` (`M` opened) → `:796`, `:800` (`A`, `H`) → `:494`, `:498` (endpoints). **Run**: `run.rs:494-495` (stage index, block digest) → `:504-505` (`B_k` committed and absorbed **before any challenge of either adjacent equality slot**) → `:512` (witness) → `:522` (`prove_core`) → `:525-531` (the incoming commitment opened, "the claim list is complete NOW, and not before") → `:535`, `:543` (endpoint openings). The salts and paths are gathered **after** the index challenges and absorbed nowhere (`pcs.rs:1036` then `:1043`/`:1048`; `zk.rs:594` then `:598`) | **CODE FACT** (re-read here; it is also the toy memo's §3.1 table and the run memo's §1.2, both VERIFIED IN THE CODE there) |
| **(ii) the witness fixed before `m_0`** | `w` is not a function of any `r_j` | **block**: `prove_inner(blk, wit, expected, endpoints)` takes the witness **by value** (`protocol.rs:469`, `:477`) and the transcript is built afterwards (`:490`); `check_endpoints` (`:447-459`) refuses unless the prover's own owners produce exactly the policy's roots. **Run**: ruling **H-1** — the header absorbs `expected-IO`, which carries **both** external endpoint roots, before any challenge exists (`run.rs:316`, header at `:302-321`, `check_endpoints` at `:470`); since every block is a deterministic public function of its input, sealing the input plane fixes the whole hidden chain | **CODE FACT for the input plane; COMPUTATIONAL for the interior.** The interior chain is fixed *because* the endpoints are committed and the relations are proved — a **binding/soundness** argument used inside a privacy proof. Soundness has not been reviewed (`FA5`). And the witness source still *permits* an adaptive caller: `src.boundary_plane(k)` at `run.rs:500` and `src.witness(k)` at `run.rs:512` are **inside** the stage loop, segment `k−1` having left at `:568`. **GAP S-4 = condition C-R3**, enforced by nothing |
| **(iii-a) separation** — the challenge source is independent of the prover's oracle answers | disjoint query classes. Untagged: squeezes are **47 bytes** (`transcript.rs:101-112`), absorbs `≥ 48` (`:59-68`), leaves and nodes 64, refills **40** (`rng.rs:53-61`), column digests `8·rows`. Tagged: `F_T` vs `F_C/F_L/F_N/F_U` (D19a) | toy: conditions **C-H4** (no commitment has 5 or 8 rows — true: 455/384/50/7/7, *accidental* for `A`, `H`, `M`), **C-H4′** (no transcript domain of length 28 or 35 — true on the block path, **false crate-wide**), one counted overlap at **2^-241.42**. Run: claim N5 (40 bytes unoccupied in `F_U`), finding **F-2** (the 125M **run** profile's constructor input is **46 bytes**, one byte from the squeeze class, and nothing checks it — ruling H-8 orders a one-line test) | **CONDITIONAL**: a code fact today at every profile in scope, pinned by nothing at some of them; at tagged profiles it is **ASSUMED** via D19a (and H-4's stronger-than-D19 model, proposed **D19b**) |
| **(iii-b) generator independence** — `ω` independent of `ξ` | `ZkRng::from_os` reads 32 bytes of `/dev/urandom` and derives a key with **keyed** BLAKE3 (`rng.rs:44-51`); the stream is **unkeyed** BLAKE3 over `key ‖ le64(counter)`, 40 bytes (`rng.rs:53-61`, ruling **H-3**). One stream per block (`protocol.rs:486`); **one per run** plus one per external endpoint (`run.rs:475`, `endpoint_g.rs:224`, ruling **R-2**) | **ASSUMED (M-3, primary, ruling L-2)**, or derived in (L1) at `ε_gen(q) ≤ 6q·2^-256` with conventions V-1 (indifferentiability, ASSUMED) and V-2. In the ROM the prover's randomness is itself an oracle output at a point the adversary cannot query without the 256-bit key or the OS entropy — the two routes of that `6q` |
| **(iii-c) the position tags are challenges, not messages** | a tag must be a deterministic function of the public prefix and `ξ` | `position_tag` squeezes two `Fp2` off `Transcript::clone_state`, which copies **state, counter and key** (`run.rs:404-409`, `transcript.rs:156-161`); the clone is discarded, so the live chain is undisturbed; the verifier re-derives them. Ruling **H-5**: a segment's trailer *equals* the next segment's start tag (no transcript operation between them) — a repetition by design, not a collision | **CODE FACT** |
| **(iii-d) every absorbed word is public or published** | otherwise `χ` is not a function of the *public* prefix | header words `protocol.rs:113-123`, `run.rs:315-320`; roots `protocol.rs:150-154`; a masked sumcheck round absorbs **the masker's output**, i.e. exactly the value the receipt carries (`transcript.rs:82-99`) | **CODE FACT**, spot-checked here; the exhaustive reading is the toy memo §3.1 and run memo §1.2 |
| **(iv′) joint per-`ρ`, in event form, for pairs** | §3.6 | field half: **Theorem 3.3** (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, core accepted) / **Theorem B** (`ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`, accepted as a *reduction*, conditional on **G-R1, G-R2, G-R4**, and at 125M **G-R3**). Hash half: **Lemma H** (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2, core accepted) / **Lemma H^run** (§3.2 of the run memo, proved in the model). Repairs 1–3 of §3.6 | **REDUCED** to those four documents **+ GAP S-1** (the conditional-on-salts sentence) **+ their own open gaps** |
| **the ideal world exists** | the all-zero input is admissible and proves | toy: `zero_witness_tests.rs` (measured 2026-09-20, two range boundaries pinned). Rungs G and K4: `run_tests.rs` and five zero bundles. **125M: no test exists** | **MEASURED** at the toy and the rungs; **GAP G-R3, BLOCKING**, at 125M (ruling R-4) |
| **Game ⊥** | a refusal publishes nothing | block: `prove_inner` returns `Err`, no receipt (ruling J-4). Run: `verify_then_write` verifies the whole run before the statement file exists (`run_statement_file.rs:235-247`), a run directory must start empty (`run_sink.rs:151-159`) — but segments are fsynced and renamed into place as they are made (`run_sink.rs:181-203` from `run.rs:568`) | block: **CODE FACT**. Run: **operating rule M-9**, and ruling **H-2** records it has **no production code behind it** — `prove_run` has no production caller at `8c5922b`. **GAP S-3** |

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

**What changes is what step 5 of D22 §3 rests on.**

| | before (Route A) | after (this lemma, if it survives its check) |
|---|---|---|
| the lift | a ten-hop lazy-sampling hybrid inside the ROM, with the challenges replaced by uniform values (hop G_6 → G_7) and the whole oracle sampled lazily (G_0 → G_1) | the path identity (§3.1) + Theorem S-H′ (§3.3), **in (L0)**; the ROM used for three priced quantities only (§3.7) |
| condition **O-4 / O-D** | **open**: "Route B extends the lemma's message alphabet rather than applying it", the lemma itself on another branch | **closed as a lemma** for `(field, hash)` pairs, written here, with hypotheses matched line by line (§4) — **subject to GAPs S-1 … S-4** |
| terms in the tally | includes B3 (`q·2^-244.03`) and B4 (2^-233.07) | both **drop** (§3.8) |
| terms added | — | **none** |
| the total | 2^-77.7 | **2^-77.7** |
| the refusal sentence | "up to 2^-112" (the raw LogUp count) | unchanged by this page; ruling **S-4**'s distinct-value refinement would make it 2^-118.4 per block, and §3.7 R-a shows it is now a bound **on `Pr^ξ`**, which is a stronger kind of claim and needs the ROM |

**The statement must not get stronger silently, and here is the one place it
could.** Route B's conclusion holds "for every challenge function", which reads
like a stronger sentence. It is not one for this protocol, because of the
LogUp class (§3.4, correction K-1): the quantifier over `χ` is only free
*inside* the composition. Anyone tempted to write "…and the argument does not
depend on the hash being ideal" must write instead: **"the composition does
not; three of its error terms do."**

### 5.2 A run — which gaps remain under it

Gap **G-H1** of `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §3 asked for
exactly the lemma of §3. It is written. What a run's sentence would then still
be conditional on, unchanged by this page:

* **G-R1** ((H1) per commitment at a shaped layout), **G-R2** (the 23 slot
  closures), **G-R4** (cross-role blinding independence — which §3.6 Repair 3
  now also leans on), all under Theorem B;
* **G-R3** at 125M — no all-zero chain has been proved there: **BLOCKING**;
* **C-R3 / GAP S-4** — the adaptive witness source, which is a **hypothesis of
  this lemma** (§4 row (ii)), not an operating nicety;
* **M-9 / GAP S-3** — Game ⊥ has no production code behind it;
* **GAP S-1** — the conditional-on-salts sentence owed by the two
  fixed-challenge theorems;
* conditions **C-R1, C-R2, C-R4, C-R5** and finding **F-2**'s one-byte margin.

### 5.3 The sums, against last night's residual tables

Nothing moves. Written out so the checker can subtract:

| term | toy block | run, 125M `L = 12` | kind |
|---|---:|---:|---|
| `B_samp` (decision D9, accepted) | **2^-77.70** | **2^-69.29** | distance, `ω`-only |
| `B_logup` (ruling S-4, `2·L·768/\|Fp2\|`) | 2^-117.42 | 2^-113.83 | distance, **challenge-reading** |
| `B_salt` (`C(N_leaf,2)·2^-256`) | 2^-229.83 | 2^-214.52 | distance, `ω`-only |
| `B_sep` (untagged: the 64-byte absorb) | 2^-241.42 | 0 by D19a (assumed) | distance |
| `ε_hit` salt guessing at `q = 2^128` | 2^-114.42 | 2^-106.76 | distance |
| `ε_gen` in-model alternative, `6q·2^-256` | 2^-125.42 | 2^-125.42 | distance / else assumption M-3 |
| ~~B3 / B5 pre-query~~ | ~~2^-116.03~~ **dropped** | ~~2^-110.52~~ **dropped** | — |
| ~~B4 / B6 absorb collision~~ | ~~2^-233.07~~ **dropped** | ~~2^-222.04~~ **dropped** | — |
| **total** | **2^-77.70** | **2^-69.29** | |
| separately: challenge-only refusal | 2^-62.0 | 2^-58.79 | **liveness, not distance** |

Every figure in this table is quoted from the two hash-layer memos and their
dispositions; the five I recomputed independently here agree to two decimals
(`ε_hit` toy and run, `B_salt` toy and run, `B_logup` at `L = 12`).

---

## 6. Step table, what to attack first, what this is not

### 6.1 Every step

| # | step | label |
|---:|---|---|
| 1 | the setting, the message alphabet, the three kinds of hash object (§1.1–§1.2) | **VERIFIED IN THE CODE** |
| 2 | the three models (L0)/(L1)/(L2) and the query-class partition (§1.3) | **ASSUMED** where (L1)/(L2) are used; the partition itself is §4 row (iii-a) |
| 3 | `χ_j` is a deterministic function of the public prefix given `ξ` (§1.4) | **VERIFIED IN THE CODE** (`transcript.rs:59-68`, `:101-112`) |
| 4 | the field lemma quoted, and exactly what it covers (§2.1) | **CITED** (branch `zk60-mvp-fable`; **not** in the main tree — unchanged from condition O-D) |
| 5 | difficulty (a): dependence through one oracle; reduced to the partition (§2.2) | **PROVED HERE**, given the partition |
| 6 | difficulty (b): the two models of (iv) and how they multiply (§2.3) | **REDUCED** to Theorem 3.3 / B × Lemma H / H^run, **+ GAP S-1** |
| 7 | difficulty (c): no programming, no lazy sampling in the composition (§2.4) | **PROVED HERE** |
| 8 | difficulty (d): the three abort classes (§2.5) | **REDUCED** to the toy memo §4 and run memo §5.2 |
| 9 | difficulty (e): the distinguisher's oracle access (§2.6, §3.5) | **PROVED HERE, in (L1)** |
| 10 | **Lemma P**, the path identity (§3.1) | **PROVED HERE**; machine-checked C1 |
| 11 | **Theorem S-H**, exact (§3.2) | **PROVED HERE, in (L0)**; machine-checked C2 |
| 12 | **Theorem S-H′**, identical-until-bad (§3.3) | **PROVED HERE, in (L0)**; machine-checked C5 |
| 13 | **Claim K-0**: the naive approximate form is false, blow-up `\|C\|` (§3.4) | **PROVED HERE by counterexample**; machine-checked C4 |
| 14 | **Correction K-1** to the toy memo's "Route B does not need uniform challenges" (§3.4) | **PROVED HERE by counterexample**; machine-checked C6 |
| 15 | **Corollary S-H″**, augmentation (§3.5) | **PROVED HERE, in (L1)**; machine-checked C8 |
| 16 | Repair 1, the coupling of the biased sampler (§3.6) | **PROVED HERE** (coupling lemma); the number is decision D9's, unchanged |
| 17 | Repair 2, `B_salt` as a witness-free superset of `B_H`'s collision event (§3.6) | **PROVED HERE**; costs nothing |
| 18 | Repair 3, the field theorems conditionally on the salts (§3.6) | **GAP S-1** |
| 19 | **Claim S-6**: Game ⊥ makes (iv′) trivial at challenge-refused `ρ`; Game prefix does not (§3.6) | **PROVED HERE**; the consequence is **GAP S-3** |
| 20 | hypothesis (i) against the code (§4) | **CODE FACT** at `8c5922b` |
| 21 | hypothesis (ii) — input plane sealed in the header (H-1) | **CODE FACT** for the plane; **COMPUTATIONAL** for the interior; **GAP S-4** for the interface |
| 22 | hypotheses (iii-a) … (iii-d) (§4) | **CODE FACT / CONDITIONAL / ASSUMED**, row by row |
| 23 | the terms that drop (§3.8) | **PROVED HERE** |
| 24 | the sums (§5.3) | **COUNTED**; five figures recomputed here, the rest quoted |
| 25 | every shape other than the toy, and every 125M figure | **GAP** — G-R1 … G-R4 and R-4 are not touched by this page |

### 6.2 What the checker should attack first

1. **The path identity (§3.1) and the claim that it replaces the kernel-ratio
   induction.** If (★) is wrong, everything on this page is wrong. Attack the
   quantifier in part 3: is `ρ^ξ(m)` really well defined for every `m` in the
   support, including truncated (refused) tuples, and is the set equality
   really an equality of sets rather than of probabilities? Then attack
   `Σ_m Pr_ω[F(w,·,ρ^ξ(m)) = m, B] = Pr^ξ_w[B]` in §3.3 — that step is doing
   the real work and it is one line.
2. **Hypothesis (iii) as I have stated it** — `ξ ⊥ (ω, w)` where `ω` includes
   *the prover's oracle answers*. Is the partition of §1.3 exhaustive of the
   prover's queries at `8c5922b`? I checked the five kinds I list; a sixth
   kind of query on the block or run path (a capture writer, a digest helper,
   an accelerator path) would put a prover query into the transcript class and
   break the independence with no term to pay for it. The run memo's own
   §2.3 rider (ii) about a **legacy-rule profile proved on the same machine**
   is the shape of the attack.
3. **Repair 3 / GAP S-1**, and whether the assembly of §3.6 is really the
   product it claims. Specifically: is `law(V, 1_{¬B} | ρ, w)` witness-free, or
   have I hidden a dependence between the blinding values and the salts that
   only G-R4 would rule out? Build the counterexample the project's own R-3
   ruling built for "joint = sum of parts", and point it at this line.

Then, in order: hypothesis (ii) for a run (is the binding argument of H-1
really enough to fix the *interior* chain before `m_0`, and is using soundness
inside a privacy proof legitimate when soundness has not been reviewed?);
Corollary S-H″'s "randomized functions do not increase total variation" step
with an **adaptive** query strategy; and whether `B_logup` as I define it is
really the *only* challenge-reading bad event (the run's witness-build class is
excluded by the admissibility quantifier — is that exclusion airtight for
**Game ⊥** when segments are already on disk?).

### 6.3 What this is not

* **Not a privacy acceptance of anything.** D22 is untouched; no run, no
  development rung and no 125M block may be called private on the strength of
  this page.
* **Not a proof that the protocol satisfies hypothesis (iv′).** That is
  Theorem 3.3 / Theorem B × Lemma H / Lemma H^run, cited and not re-proved,
  with their own gaps.
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
* **Not reviewed.** One delegated agent wrote it; the adversarial check has not
  happened yet.

---

## 7. Evidence

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
| **C4** | Claim K-0 | per-`ρ` TV `1/\|C\|`, adaptive TV **1**: blow-up **exactly `\|C\|`** at `\|C\| = 2, 4, 8, 16, 32` |
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

---

## 8. Circularity check

| section | what it assumes | where that is concluded | circular? |
|---|---|---|---|
| §3.1 Lemma P | (i) only | Definition 1.1; §4 row (i) reads it off the code | no |
| §3.2 S-H | (i)–(iv) | (iv) is §3.6, which uses nothing from §3.1–§3.5 | no |
| §3.3 S-H′ | (i)–(iii), (iv′) | same | no |
| §3.4 K-0/K-1 | nothing (counterexamples) | — | no |
| §3.5 S-H″ | the view-level conclusion + (L1) freshness | §3.3; the model is declared at §1.3 | no |
| §3.6 assembly | Theorem 3.3 / B, Lemma H / H^run, M-3 or the non-adaptive-refill argument | four other documents, all of which are *fixed-challenge* statements and none of which cites this page | no |
| §3.7 pricing | (L1) | §1.3 | no |
| §4 | the code at `8c5922b` | read here | no |

The one place a loop could hide is §3.6 Repair 3: it asks the fixed-challenge
theorems for a statement *conditional on the salts*, and the salts are objects
the hash-layer lemma also speaks about. The two uses are disjoint — Theorem 3.3
is asked only to hold with the salts held fixed, and Lemma H is asked only
about the conditional law of the hash objects **given** the field view. No
statement is used to prove itself. That is **GAP S-1**, and it is a
bookkeeping gap, not a loop.

---

### Gaps, by name

| name | what is missing | who owes it |
|---|---|---|
| **GAP S-1** | one sentence from each of `ZK60_JOINT_LAW_COMPOSITION.md` and `ZK60_JOINT_LAW_COMPOSITION_RUN.md`: the theorem's randomness is the blinding stream and the statement holds **conditionally on the salts**, which are independent of it (assumption M-3 / gap G-R4) | the owners of those two documents |
| **GAP S-2** | the per-`ρ` hypothesis for pairs is only as good as Theorem 3.3 / Theorem B; at a run those carry **G-R1, G-R2, G-R4** and at 125M **G-R3 (blocking)** | unchanged, not this page |
| **GAP S-3** | **Game ⊥** — a refusal publishes nothing — is a code fact for a block and, for a run, operating rule **M-9** with **no production code behind it** (ruling H-2). Under Game prefix, hypothesis (iv′) at a challenge-refused `ρ` is supplied by nothing | the integrator (the run wrapper) |
| **GAP S-4** | hypothesis (ii) for a run's **interior**: `RunWitnessSource` permits an adaptive source (`run.rs:500`, `:512` inside the loop) — condition **C-R3**, enforced by nothing. H-1 fixes the input plane; the interior is fixed only through binding, i.e. through an unreviewed soundness property | the integrator (a `RunWitnessSource` handed the whole chain at construction) |
| **GAP S-5** | hypothesis (iii-a) at shapes where it is unpinned: the untagged conditions **C-H4**, **C-H4′** (false crate-wide), the run's **C-R1**, **C-R2**, and finding **F-2**'s one-byte margin at the 125M run profile | the 125M lane (one-line tests, ruled by L-3 and H-8) |
| **GAP S-6** | this page has not been independently checked | the adversarial checker |

---

*Written by a delegated Opus agent. Nothing here establishes a privacy
property. Every step was drafted once and machine-checked where a machine
could check it; the argument has not been attacked yet.*
