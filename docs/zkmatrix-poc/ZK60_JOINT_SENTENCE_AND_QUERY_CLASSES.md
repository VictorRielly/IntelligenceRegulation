# The joint sentence, and the complete query-class table

**Drafted by a delegated Opus agent for the security owner.**
2026-09-21, started 02:21, written 02:46–02:55 (`date` read at 02:21, 02:46,
02:53 and 02:54 on the WSL box, PDT).

It incorporates ruling **K-R4a** (security owner, 02:42), which reached
claims A-12…A-14 below independently and at the same hour; where this page
says "before reading K-R4a" it means the computation, not the ruling.

It delivers the two items ruling **K-R3** and ruling **K-R2** of
`ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md` left owed. K-R1 is an
errata matter and is not touched here.

| | |
|---|---|
| **Part A (K-R3)** | the joint sentence the composition lemma needs: the probability space read off the code, the sentence split into four checkable clauses, the project's two counterexamples aimed at it, and what changes at a shaped block and in a run |
| **Part B (K-R2)** | every BLAKE3 call kind on the toy's path and a run's path at `8c5922b`, its mode, key, layout and length per shape, what separates it from every other, and what pins that separation today |

**This establishes no privacy property of anything.** Register entry D22 (the
toy block) is untouched and rests on Route A, not on this page. No sentence
here may be quoted as an acceptance.

Code facts are readings of the lane worktree `/home/victor/wt-zk60-block125m`
at commit **`8c5922b`**; nothing was compiled or run in Rust. Numbers are
labelled **[COUNTED]** (read off the code), **[COMPUTED]** (this page's
scripts, exact arithmetic), **[ARGUED]**, **[ASSUMED]**, **[UNVERIFIED]**.
Evidence: `results/zk60_joint_sentence_query_classes/` — four scripts, each
ending `ALL ASSERTIONS PASSED`, with their outputs and a README naming every
`file:line` transcribed.

---

## 0. In plain words, before any notation

The composition step needs one sentence that the accepted theorems do not
say. The accepted theorems say: *for fixed challenges, the numbers a receipt
publishes look the same whoever the hidden input was.* What the composition
needs is bigger in three ways. It needs the **salts** in the picture, because
a receipt publishes 1,280 of them and the theorems' probability space does
not contain them. It needs the **hashes** in the same picture, jointly, not
as a second marginal — the project's standing counterexample is two values
each uniform on its own whose pair gives the secret away. And it needs the
**flag** — the indicator that no bad event happened — inside the same joint
law, because the lemma compares two worlds "until something bad happens" and
the bad thing has to be the same thing in both worlds.

Part A writes that sentence, says exactly which of its clauses is a theorem
about the code, which rests on the generator assumption, and which needs a
test nobody has written.

The other owed item is smaller but sharper. The lemma needs the prover's hash
queries and the queries that make the challenges to be different queries.
Last night's check found the draft's list of query kinds incomplete. Part B
is the complete list — **24 call kinds, not five** — with, for every pair,
the thing that keeps them apart, and for every separation, the test that pins
it or the admission that nothing does.

Three things this page found that nobody had written down:

1. **The prover does query the transcript class.** The refusal replay and the
   run's position tags squeeze off a discarded clone, at points the live
   chain queries next. The draft's "partition into a prover class and a
   transcript class" is not a partition of the prover's queries at all. The
   hypothesis survives, in a different form: *the prover's transcript-class
   queries are all at points determined by the public prefix* (§6.3, claim
   B-6).
2. **A commitment of 16 rows would hash a column to 128 bytes, the length of
   the frozen-seam spec digest, and no guard anywhere refuses 16.** The lane's
   completed guard carries 5, 8, 11, 12, 13, 15, 17, 19 and the shape-driven
   ones; the statement digests were never in its set [COMPUTED].
3. **A `pb-term` absorb of six terminals is 151 bytes, the length of the
   internal-boundary spec digest**, which is unkeyed at every rule — so it is
   a cross-profile coincidence between a legacy proof and a tagged run on one
   machine (§7, claim B-8). Whether any slot really carries six terminals is
   [UNVERIFIED] here and is work-list item W-6.
4. **Lemma H's owed half is a WITHIN-segment conditioning, not a
   between-segment one.** The published and the withheld salts are one stream
   segment split by the challenge; "the unopened ones are still uniform" is
   therefore not the disjoint-positions argument and needs M-3 again, plus the
   fact that the split is `ρ`-determined. Written out as clause (c′) in §2.4;
   it is the half ruling K-R3 says the hash-layer lemma owes.

---

# PART A — the joint sentence (ruling K-R3)

## 1. The probability space, exactly

### 1.1 One generator, one stream, a constant price per draw

**Claim A-1 [COUNTED].** `ZkRng` (`zkp-core/src/rng.rs:9-99`) is a byte
stream with a 32-byte key and a counter. `refill` (`:53-61`) produces each
8,192-byte block as **unkeyed** BLAKE3 in XOF mode over `key(32) ‖
le64(counter)(8)` — 40 bytes. `RNG_BLOCK = 8192` (`:16`) is a multiple of 8
and every read is `next_u64` (`:63-70`), so a buffer boundary never splits a
word and **the byte position of the `i`-th `next_u64` is exactly `8i`**.

**Claim A-2 [COUNTED] — the field sampler is REDUCTION, not rejection.**
`fp()` (`rng.rs:73-77`) takes two `next_u64`s as a 128-bit integer and calls
`Fp::from_u128`, which is `Fp((v % (P as u128)) as u64)`
(`zkp-core/src/field.rs:36-38`), `P = 0xFFFF_FFFF_0000_0001` (`field.rs:10`).
There is no loop, no retry, no branch. **One `fp()` consumes exactly 16 bytes
whatever it draws**; `fp2()` 32; `bytes32()` (`rng.rs:93-99`) 32.

This is the fact the coordinator asked to be confirmed, and it is confirmed.
It is what makes "the draws sit at schedule-determined positions" true, and
therefore what licenses ruling **K-R4a**'s distance hop. Had the sampler
rejected, the hop would still be valid but the *argument* for it would have
to change (§2.1, claim A-9).

**Claim A-3 [COUNTED] — there is no re-draw anywhere on the path.** The two
places that look like one are not:

* `H`'s zero-sum rows (`hashline/src/private_block/protocol.rs:760-768`) draw
  exactly `n−1` values per row and **compute** the last as the negated sum. A
  prefix that happens to sum to zero simply gives a zero last entry. No
  condition, no loop.
* `M`'s `b` rows (`hashline/src/zk.rs:503-506`) draw `2m` values and then
  **overwrite** `b_re[m] := −b_re[0]`. An overwrite, not a re-draw.

Grep over the path finds no `loop {`/`while` around any `rng` call. The only
witness-sensitive control flow inside the draw window is a **total abort** —
`inverses()` returning `Err("zero LogUp denominator; discard attempt")`
(`protocol.rs:402-405`, called at `:691, :702, :704, :734`) — which discards
the stream and produces no receipt. Under D21 and rule M-9 the game is
accepted receipts only, so an aborted attempt contributes nothing to the view
(§2.4).

### 1.2 The segment schedule of one block body, in order

**Claim A-4 [COUNTED].** The prover reads the stream in exactly this order.
Sites are at `8c5922b`.

| # | segment | site | count | width | published? |
|---|---|---|---|---|---|
| 1 | `A` mask + proximity rows | `protocol.rs:655-658` | `(a_rows − a_data)·n` | `fp` | no |
| 2 | `A` pads | `zkp-core/src/pcs.rs:777` | `a_rows·Q` | `fp` | no |
| 3 | **`A` salts** | `pcs.rs:778` | `nn` | `bytes32` | **yes, 256 slots** |
| 4 | `M` CFS mask coefficients | `zk.rs:485` → `sumcheck.rs:201-203` | `2·Σ L_s` | `fp` | no |
| 5 | `M` per-row pads | `zk.rs:496` | `46·256` | `fp` | no |
| 6 | `M` `b_re,b_im,u_re,u_im` | `zk.rs:503-508` | `4·1024` | `fp` | no |
| 7 | **`M` salts** | `zk.rs:513` | `4096` | `bytes32` | **yes, 256 slots** |
| 8 | `H` mask + proximity rows | `protocol.rs:757-759` | `(h_rows − h_data)·n` | `fp` | no |
| 9 | `H` zero-sum rows | `protocol.rs:760-768` | `2(n−1)` | `fp` | no |
| 10 | `H` pads | `pcs.rs:777` | `h_rows·Q` | `fp` | no |
| 11 | **`H` salts** | `pcs.rs:778` | `nn` | `bytes32` | **yes, 256 slots** |

The order **pads then salts** inside a commitment is the same on the legacy
twin (`pcs.rs:724-725`) and is drawn *before* the accelerator is offered
(`pcs.rs:782-785`), so neither the GPU path nor the hash tag moves a byte —
the lane pins that with `the_tag_does_not_move_one_byte_of_the_generator`
(`zkp-core/src/pcs.rs:1736-1753`).

**The published salts sit between secret segments, in both directions.** `A`'s
salts (segment 3) are published, and segments 4–11, including all of `H`'s
pads, are drawn from the same stream afterwards. That is the two-sidedness
ruling C-3 insists on, and it is the whole reason M-3 must be read as a
statement about the *whole stream*, not as forward unpredictability.

**Claim A-5 [COMPUTED].** `stream_positions.py` lays segments 1–11 out with
byte offsets at five shapes, asserts pairwise disjointness, and totals:

| shape | `fp()` draws, block body | salts | stream bytes |
|---|---:|---:|---:|
| toy | 320,908 | 8,192 | 5,396,672 |
| rung / rung-G | 687,028 | 12,288 | 11,385,664 |
| rung-K4 | 750,540 | 12,288 | 12,401,856 |
| 125M | 9,029,804 | 135,168 | 148,802,240 |

Cross-check: the toy body's 320,908 plus the two frozen-seam endpoints'
6,144 is **327,052**, decision D9's accepted figure to the draw; the 125M
figures are ruling H-6's. Both reproduce from the code with no imported
number.

### 1.3 How many generators

**Claim A-6 [COUNTED].** Every `ZkRng::from_os` on the path, with its domain
and therefore its seed-derivation input length:

| caller | `file:line` | domain | seed input |
|---|---|---|---|
| block prover | `protocol.rs:486` | the block profile | `22 + |profile|` |
| **run prover** | `run.rs:475` | the run profile | `22 + |profile|` |
| generalised endpoint | `endpoint_g.rs:224` | `DOMAIN`, 42 B (`:45`) | **exactly 64** |
| frozen-seam endpoint | `private_seam.rs:196` | `DOMAIN`, 28 B (`:26`) | 50 |

A boundary takes the **caller's** generator (`boundary.rs:315-328`) and makes
none of its own.

* **A toy proof has three generators**: the block's, and one per frozen-seam
  endpoint, each from its own 32-byte `/dev/urandom` read (`rng.rs:45-46`).
  Their mutual independence is **information-theoretic**, not an M-3
  consequence (correction C-11 of the toy joint-law memo).
* **A shaped block has three**, the two endpoints now generalised.
* **A run of `L` blocks has three too — but the sharing is different.** One
  generator serves the whole run (`run.rs:475`, threaded by `&mut` through
  the stage loop at `:487`, never cloned or reseeded), i.e. `L` blocks and
  `L−1` boundaries: **47 of the 49 commitments at `L = 12`** share one
  stream [COUNTED]. Only the two external endpoints keep their own.

**Claim A-7 [COMPUTED].** At 125M, `L = 12`: the run stream carries
109,546,000 `fp()` draws and 2,342,912 salt draws over 1,827,709,184 bytes;
with the two external endpoints, 109,728,784 `fp()` draws — **ruling H-6's
figure, reproduced independently**. At rung-G `L = 3`: 2,093,340; at rung-K4
`L = 3`: 2,283,876. Both are H-6's.

### 1.4 The position map, and whether it is witness-independent

**Claim A-8 [COUNTED + ARGUED].** Write `pos(segment)` for the byte offset at
which a segment starts. By A-1 and A-2, `pos` is `8 ×` the number of
`next_u64`s already made, and by A-4 every count in the schedule is built
from shape constants: row counts (`layout.rs:1063-1140`), `n = 2^log_cols`,
`nn = n·inv_rate`, `Q = 256` (`shape.rs:51`, `pcs.rs:579-581`), `MASK_Q`,
`MASK_DOM`, `Σ L_s`, `N_SLOTS`. By A-3 no count is conditioned on anything.
**Therefore `pos` is a function of the shape alone — not of the witness, not
of the challenges, not of the values drawn.** In a run, the offset of stage
`k` is `k·(block) + min(k, L−1)·(boundary)`, a function of `k` and the shape
[COMPUTED].

This is the load-bearing code fact of Part A, and it is established **by
reading, and pinned by no test** (§8, gap **GAP-JS-1**).

**Claim A-9 [COMPUTED] — what rejection sampling would have cost.** If
`fp()` rejected, `pos` would be a random stopping time. The conclusion would
survive — `stream_positions.py` §4 computes, in exact rationals on an i.i.d.
stream with a rejection region, that the post-stopping-time symbols are still
exactly uniform and exactly independent of the accepted values (the strong
Markov property). But the *argument* would change: "disjoint fixed positions"
would have to become a stopping-time argument, and the stopping time would
have to be shown witness-free — a strictly stronger reading of the owed test.
The project needs only the weaker reading, and that is a fact of
`field.rs:37` which nothing pins as privacy-relevant (work-list item W-1).

## 2. The sentence, split into checkable parts

### 2.0 The sentence, as this page can state it

Fix a shape and an admissible public statement. Let `ω` be the prover's
randomness — **the uniform-blinding idealisation**: every `fp()` value a
uniform element of `Fp`, every `bytes32()` value a uniform 256-bit string,
all mutually independent, at the schedule-determined positions of §1.2. Let
`ρ` be a challenge vector with `NR(ρ)` (the prover does not refuse). Let

* `V` = the field view, exactly the list of `ZK60_JOINT_LAW_COMPOSITION.md`
  §2.1 (masked scalars, masked round values, masked terminals, group and
  proximity vectors, `M`'s `q` and proximity rows, and the opened columns);
* `S_pub` = the published salts — 256 slots per commitment, about 1,211
  distinct at the toy;
* `H` = the hash objects — the roots, the authentication paths, and in a run
  the `2L` position-tag fields and the run binding;
* `B = B_salt ∪ B_logup`, with `B_salt` the salt-coincidence event of Lemma H
  (§2.3) and `B_logup` the **union over both worlds** of the zero-lookup-
  denominator refusal;
* `1_{¬B}` the no-bad-event flag, defined by the **same rule** in both worlds.

> **The joint sentence (JS).** For every pair of admissible hidden inputs
> `w, w′` and every `ρ` with `NR(ρ)`,
> ```
> law( V, S_pub, H, 1_{¬B}  |  ρ, NR, w )  =  law( V, S_pub, H, 1_{¬B}  |  ρ, NR, w′ )
> ```
> where
> * **(a)** the salt segments of the stream are independent of every blinding
>   segment, because their byte ranges are disjoint and witness-independent
>   (§1.4) and the stream is uniform;
> * **(b)** `S_pub` is the restriction of the salt segments to an index set
>   `OPEN_r = f(ρ)` that is a public function of `ρ` alone, so publishing it
>   reveals a fresh uniform string and nothing about `V`;
> * **(c)** given `(V, S_pub, ρ, NR, w)` and the unopened columns and the
>   adversary's `q` oracle answers, the never-opened leaf digests are, off
>   `B_salt`, an i.i.d. uniform product — so `H` is a fixed witness-free
>   kernel `K(H | V, S_pub)` (Lemma H, `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2);
> * **(d)** `B` is a function of `(ρ, w, w′, ω)` through rules identical in
>   both worlds, and `Pr[B | w] = Pr[B | w′]`.
>
> **The real prover is reached by one distance hop taken BEFORE this sentence
> is used**, not inside it: the whole experiment is a deterministic function
> of `(ω, O)`, so replacing the real `ω` by the ideal one moves the view by at
> most `N · 2^-96` (decision D9: 2^-77.7 at the toy, 2^-69.3 for a
> twelve-block 125M run). **`B_samp` is not in the flag.**

### 2.1 Clause (a): the salt segment against the blinding segments

**Claim A-10.** Under the idealisation "the stream is uniform" — assumption
**M-3** in ruling C-3's two-sided whole-stream form — clause (a) **is
immediate**, and it is immediate for exactly one reason: *disjoint byte
ranges of a uniform string are independent.* Two things have to be true for
that to be the whole argument, and only one of them is an assumption:

| ingredient | status |
|---|---|
| the positions are **disjoint** | **theorem about the code** (A-4, A-8): consecutive non-overlapping ranges, asserted pairwise in `stream_positions.py` |
| the positions are **witness-independent** | **theorem about the code** (A-2, A-3, A-8): every count is a shape constant; no rejection, no re-draw, no witness branch |
| the stream is **uniform** | **[ASSUMED] — M-3 (ruling C-3)**, in the two-sided whole-stream form, and nothing else. The block memo's §5.3 row 6 calls this "the one candidate with no structural answer" and it is right to |
| the positions are pinned by a **test** | **no. GAP-JS-1** |

So: clause (a) is immediate *given* M-3, and the code half of it is a reading
that nothing in the test suite would notice breaking. That is the honest
shape of the answer to the brief's question, and it is weaker than "immediate"
and stronger than "no structural answer": **the structural answer exists and
is unpinned; the assumption is unavoidable and is M-3.**

**Claim A-11 [COUNTED].** The information-theoretic part is smaller than a
reader might hope. At the toy, three separate `/dev/urandom` reads make the
block's stream and the two endpoints' streams independent *without* M-3; but
`A`, `M` and `H` — and therefore every salt the block publishes against every
pad it hides — are one stream, and there M-3 is the only argument. Counting
pairs: at a single block **three** commitments share one stream, so
`C(3,2) = 3` pairs rest on M-3 and the rest are information-theoretic. **In a
twelve-block run forty-seven of the forty-nine share one stream, so
`C(47,2) = 1,081` pairs rest on M-3** [COMPUTED]. Unchanged in kind; worse by
two and a half orders of magnitude in degree.

### 2.2 The sampler leaves the flag — and why the arithmetic forces it

**Claim A-12 [COMPUTED].** For `p = 2^64 − 2^32 + 1` and `N = 2^128`:
`k = ⌊N/p⌋`, `r = N − kp = 18446744065119617025`, and `p − r = 2^32` exactly.
Hence

```
TV(real draw, uniform)   = r(p−r)/(pN) = 2^-96.0000000003
Pr[rejection region]     = r/N         = 2^-64.0000000007
```

**Claim A-13 [PROVED + COMPUTED].** No coupling whose good event carries an
exactly uniform value can have bad probability below `r/N`. Such a coupling
is a constant `c ≥ 0` with `Pr[X = v, good] = c` for every `v` and
`c ≤ Pr[X = v]`, so `c ≤ min_v Pr[X = v] = k/N` and
`Pr[bad] = 1 − pc ≥ 1 − pk/N = r/N`. The rejection-region coupling attains it.
`sampler_coupling.py` confirms the identity exhaustively on six small
analogues (`p, N` = 5,16; 7,32; 11,64; 13,128; 5,1024; 17,256), and reproduces
the maximal coupling's conditional law as **not uniform** — which is the
check's B-4 objection, correct as far as it goes.

**Claim A-14 [COMPUTED].** In event form the sampler would cost
`327,052 · 2^-64 = 2^-45.68` at the toy and `109,728,784 · 2^-64 = 2^-37.29`
for a twelve-block 125M run — 32.0 bits worse than the distance form at every
shape.

This page reached A-12…A-14 independently and before reading ruling
**K-R4a** (security owner, 2026-09-21 02:42), which rules the same way and
for the same reason. Two things this page adds:

* **the closed-form criterion** [COMPUTED]: the distance hop beats the event
  form iff `2·TV < Pr[rej]` iff `2(p − r) < p`. Goldilocks satisfies it by
  31 bits because `p − r = 2^32`; a small field need not, and
  `sampler_coupling.py` prints an instance (`p = 5, N = 16`) where the event
  form is the *better* of the two, so that nobody reads the criterion as
  universal;
* **why the hop is legitimate under an ADAPTIVE challenge schedule**, which
  K-R4a states in one clause. The whole experiment — prover, challenge
  oracle, distinguisher — is one deterministic function of `(ω, O)`, and `O`
  is independent of `ω`; so by data processing the view moves by at most
  `TV(ω_real, ω_ideal)` **whatever the challenge schedule does**. This is
  exactly where the schedule-determined positions of A-8 are needed: they are
  what makes `ω` a well-defined product measure that the map consumes.
  `sampler_coupling.py` §6 runs a complete two-round adaptive model with a
  witness-dependent refusal, exhaustively over all 3,125 challenge schedules,
  and confirms both bounds hold and which is smaller in which regime.

**A code-comment defect worth one line.** `zkp-core/src/rng.rs:72` reads *"a
128-bit draw reduced mod p: bias 2^-64"*, and `zkp-core/src/transcript.rs:113`
says the same of `challenge_fp`. `2^-64` is the **rejection-region
probability**, not the distance from uniform, which is `2^-96`. The comment is
wrong for the number the project publishes and accidentally right for the
number K-R4a has just ruled out. It is a comment in the integrator's crate;
it goes to the integrator with the `hashtag.rs:22-33` correction already
named by ruling H-3.

### 2.3 Clause (b): the published salts

**Claim A-15 [COUNTED + ARGUED].** Given `ρ`, the opened index set is
`Transcript::challenge_indices` (`zkp-core/src/transcript.rs:136-148`), a
public function of the transcript state and counter, hence of `ρ` in the
fixed-challenge experiment. A salt enters exactly one object: the leaf hash
`salt_leaf(hash_column(col), salt)` (`pcs.rs:678`), and the verifier
recomputes that same leaf from the published column and the published salt
(`pcs.rs:1126-1127`, tagged `:1248-1249`). It enters **no** field value, no
absorb, no challenge. So `(V, S_pub)` has the product law
`law(V | ρ, NR, w) ⊗ Unif({0,1}^256)^{|S_pub|}`, and the first factor is
witness-free by the accepted fixed-challenge theorem.

Two riders, both needed:

1. **No refusal reads a salt.** The eighteen refusal classes are
   challenge-driven or witness-driven; the witness-driven one is the zero
   LogUp denominator (`protocol.rs:402-405`), the challenge-driven ones are
   `argument.rs:332-334, :404-406, :765-768` and `protocol.rs:284-291`. None
   touches `salts`. So conditioning on `NR(ρ)` does not tilt the salt
   segment. [ARGUED from the refusal inventory; not machine-checked.]
2. **In the fixed-challenge experiment `ρ` is exogenous, so the index set is
   independent of the salt values.** In the *real* protocol `ρ` is a hash of
   the roots, which are functions of *all* the salts — so which salts get
   published is correlated with what they are. That correlation is exactly
   what the Fiat–Shamir lift has to handle and what this sentence must not be
   read as handling. It is the first place an attacker should look (§11).

### 2.4 Clause (c): the hash objects given the field view and the salts

**Claim A-16 [RELIES ON Lemma H].** `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2, as
corrected by its check (C-10), gives exactly the conditional form needed: off
an event `B_salt` of probability `q·N_leaf·2^-256 + C(N_leaf,2)·2^-256 +
N_overlap·2^-256 + N_node·N_leaf·2^-512`, the never-opened leaf digests are an
i.i.d. uniform product **given** the field view, the published salts, the
unopened columns themselves, the witness, and the adversary's `q` answers.
Hence `H = T^O(opened columns, S_pub, unopened digests)` with `T^O` public,
and `law(H | V, S_pub, ρ, NR, w)` is a witness-free kernel.

**Does it silently use independence it has not got? One place, and it is the
same place.** Lemma H's hiding randomness is the salts of the **unopened**
leaves — 11,077 of the toy's 12,288. Those live in the **same stream
segments** as the published ones (segments 3, 7, 11 of §1.2): the published
and the withheld salts are interleaved inside one segment, selected by `ρ`.
So "the unopened salts are still uniform given the published ones" is not a
disjoint-segment fact; it is a **within-segment** conditioning, and it needs
M-3 in the whole-stream form again, plus rider 2 of A-15 (the selection is
`ρ`-determined). Lemma H states its model and does not state this; it is the
half ruling K-R3 says the hash-layer lemma owes, and this is it, written:

> **(c′)** *Under M-3 in its two-sided whole-stream form, and with the opened
> index set a function of `ρ` alone, the restriction of a salt segment to the
> unopened indices is uniform and independent of its restriction to the
> opened indices and of every blinding segment.*

That is a **[GAP → now stated]**, not a theorem proved here: it is immediate
from M-3 and A-15 rider 2, and it is not immediate without either.

### 2.5 Clause (d): the flag

**Claim A-17.** After K-R4a the flag is two events, not four:

| event | rule | same in both worlds? | price |
|---|---|---|---|
| ~~`B_samp`~~ | **removed** (K-R4a) — a distance hop before the lemma | — | 2^-77.7 / 2^-69.3 as a distance |
| ~~`B_sep`~~ | **removed** (K-R1) — a failed hypothesis, repaired by one hybrid hop | — | the same price, in the model |
| `B_salt` | a function of the salt segments and the adversary's queries; no witness enters | yes, by construction | 2^-229.8 (toy) |
| `B_logup` | **the union over both worlds** of the zero-lookup-denominator refusal | yes, because the union is taken | 2^-117.4 per block (two-world); the one-world figure is 2^-118.4 |

The union in `B_logup` is forced, not decorative: the check's C4 computation
shows a single-world flag violating the bound by 3/8 on an eight-value
instance. Both figures stay, each labelled.

**One thing the flag must also say, which no document states.** The game is
**accepted receipts only** (D21; M-9 for a run). An aborted attempt — the
`inverses()` discard of A-3 — has already consumed segments 1–7 of the stream
and produced no receipt. Under the accepted-receipts game that attempt is not
in the probability space at all, and the sentence is conditioned on `NR`. If
anybody ever hands a relying party a refused prefix, the conditioning breaks
and so does the lemma's hypothesis (ruling K-R5 says the same from the other
side). **This is a second reason the sentence cannot be quoted without M-9.**

## 3. The two counterexamples, aimed at (JS)

`counterexamples.py`, exact arithmetic mod 101, six seeds plus one
adversarially constructed instance per seed.

**Claim A-18 [COMPUTED] — counterexample (i), a shared blinding row.** Two
claim sites, three published coordinates each. With independent rows the
disclosed dimension is 0; with one row shared it is 3, while **each site's
marginal is still perfectly blinded**. The difference `V_0 − V_1` equals
`(M_0 − M_1)·w` with the blinding cancelled, for every blinding value, and it
separates two witnesses. Six seeds, all assert.

**Which clause of (JS) excludes it, and what kind of thing that clause is.**
Clause (a) — *disjoint witness-independent stream positions* — via A-4 and
A-8: a shared row would mean two roles reading the **same byte range**, which
the segment schedule forbids by construction. **This is a THEOREM about the
code** (the schedule is built from shape constants and the ranges are
consecutive) **and it is pinned by no test.** The project's rank gates would
also catch it, because a shared row changes the *structure* the gate reads.

**Claim A-19 [COMPUTED] — counterexample (ii), ruling R-3's variant.** Two
**distinct** rows at **disjoint** positions whose **values** coincide. The
gate's disclosed dimension is 0 on all six seeds — the honest answer, because
the gate computes a rank over two independent symbols — and the realised view
determines `(M_0 − M_1)·w` exactly on all six. **No rank computation can see
it**, because the gate is a statement about which symbol each site uses and
the leak is a statement about the values.

**Which clause excludes it.** Clause (a) again, but a *different half* of it:
not "the positions are disjoint" but "the stream is uniform" — **M-3**. Under
M-3 two disjoint 256-word ranges coincide with probability `p^-256 = 2^-16384`
[COMPUTED], which is not a term anybody carries.

**And this is the honest sharpening ruling R-3 was reaching for.** The
counterexample is not really about an accident. If the draw discipline is
broken — a reused buffer, a cloned generator, an off-by-one in a draw count,
a re-entered commit path — the coincidence has probability **one**, and it is
invisible to every gate the project runs *and* to M-3, which is an assumption
about a correctly consumed stream and says nothing about a stream consumed
twice. So:

> **The part of (JS) that excludes ruling R-3's counterexample is the
> witness-independence AND injectivity of the position map — a theorem about
> the code today, a reading, and the thing the owed test must assert.**

`counterexamples.py` measures the accidental rate at two small dimensions to
show the pricing is the right shape (`k=1`: predicted 9.901e-03, measured
1.014e-02 over 400,000 trials; `k=2`: predicted 9.803e-05, measured
1.075e-04) and then says in as many words that the accident is not the risk.

### 3.1 What the owed test must assert, exactly

Ruling **R-3** asks for a machine assertion. Here is what it has to say for
clause (a) to become a code fact. Each line is one assertion.

1. **Total consumption.** A block proof at shape `S` consumes exactly
   `bytes(S)` stream bytes, the closed form of `stream_positions.py`
   (5,396,672 at the toy). A run at shape `S`, `L` blocks, consumes exactly
   `L·bytes(S) + (L−1)·bytes_boundary(S)`.
2. **Per-role offsets.** Each of the eleven segments of §1.2 begins at the
   offset the schedule predicts, and the segments are pairwise disjoint and
   cover the consumption with no hole.
3. **Witness-independence.** Two different admissible witnesses at the same
   shape produce **identical** consumption and identical per-segment offsets.
   (The zero-witness fixtures give one of the two for free.)
4. **Injectivity across roles.** No two roles — the `4L+1` commitments'
   pads, mask rows and salts — are ever assigned overlapping ranges; in a run
   this is the `47`-commitment statement, and it is the one R-3 names.
5. **The generator is never cloned, forked or serialised**, and `prove_run`
   constructs exactly one (ruling R-2's condition, today a reading of
   `run.rs:475`).

**Does it need a hook inside `zkp-core/src/rng.rs`?** **Yes, and that file
belongs to another engineer.** `ZkRng`'s fields are private
(`rng.rs:9-14`) and there is no `pos()`, `consumed()` or counter accessor.
Assertions 1–4 cannot be written from outside the crate. The smallest thing
that would do it is a `#[cfg(test)]`-or-always accessor returning
`counter·8192 + pos`, plus (for 4) an optional label-and-range recorder. **It
is to be requested of the integrator, not written by the lane** — as ruling
R-3 already anticipates ("If that needs a hook in `zkp-core/src/rng.rs`, it
is asked of the integrator"). This page's contribution is the list above, so
the request can be made once and completely.

## 4. What changes at a shaped block, and in a run

**Claim A-20 [COUNTED] — a shaped block.** Three differences, none of which
touches the structure of (JS):

1. **More commitments and bigger ones.** The generalised endpoint has five
   mask rows (`endpoint_g.rs:52, 148`: one reserved pair plus three proximity
   rows) against the frozen seam's same five (`private_seam.rs:36, 110`); the
   geometry differs, the schedule does not.
2. **Internal boundaries exist** (runs only), six mask rows and
   `(endpoint_rows+1)·256` pads, on the **caller's** stream
   (`boundary.rs:315-328`).
3. **The pad-zero term draws nothing from the generator. CONFIRMED.** `ζ` and
   `mu_pad` are transcript squeezes — `argument.rs:961, 1027, 1028, 1224,
   1299, 1352, 1410, 1485`, each `tr.challenge_fp2_vec(1)` or
   `tr.challenge_fp2()`, with the zero refusal at `argument.rs:765-768`
   (`fn nonzero` at `:765`, its string at `:767`).
   `n_pad = usize::from(pad_on)` (`argument.rs:935`) and `pad_doms`
   (`:933`) are pure functions of the shape, so even the *challenge* counts
   are shape-determined. The brief asked this to be confirmed; it is.

**Claim A-21 [COUNTED] — a run.** Four differences, one of which matters:

1. **One generator for the whole run** (`run.rs:475`), ruling R-2 as built.
   The run's blinding and the run's salts for `4L−1` of the `4L+1`
   commitments are segments of one stream, so clause (a) rests on M-3 across
   **eleven stage boundaries** at `L = 12` — stage 1's salts are published
   before stage 12's mask rows are drawn.
2. **Block `k`'s generator state is CARRIED, not dropped** — `rng` is
   declared outside the stage loop and threaded by `&mut` (`run.rs:475`,
   `:504`, `:522`). Is that a memory fact or a privacy-relevant one? **It is
   privacy-relevant, and in the project's favour**: carrying one stream is
   what makes the per-stage offsets `k·(block) + min(k,L−1)·(boundary)`
   deterministic, hence disjoint, hence clause (a). What is *dropped* between
   stages is the witness segment and the committed data, which is a memory
   fact. The one thing carrying costs is the information-theoretic
   independence a per-commitment generator would have given (A-11) — which
   ruling R-2 withdrew deliberately, for one fail-closed entropy point
   instead of forty-nine.
3. **The draw counts per stage are shape-determined and witness-independent,
   verified on the refusal and re-draw paths** [COUNTED]: per-stage layouts
   differ only in `io_mask_row` (`run.rs:391-393` →
   `layout.rs:1151-1154`), which does not change `a_rows` or `h_rows`, so
   every stage draws the same amount; the re-draw paths do not exist (A-3);
   the refusal paths abort the run (and, by ruling H-1, the whole forward
   pass has already run before the header, so an admissible chain never
   refuses).
4. **The hash view gains objects**: the `2L` position tags and the run
   binding. They are transcript outputs at prefix-determined points, so they
   belong to `H` and are covered by clause (c) — but see claim B-6, which is
   where they bite.

---

# PART B — the complete query-class table (ruling K-R2)

## 5. Every BLAKE3 call kind on the path

**Claim B-1 [COUNTED].** Twenty-four distinct call kinds, against the draft's
five. Mode column: `new()` = unkeyed, `new_keyed(k)` = keyed, `derive_key` =
BLAKE3's third mode. "Rule" says whether the kind moves into a tagged family.

| # | kind | `file:line` at `8c5922b` | mode / key | input layout | length | who | input is |
|---|---|---|---|---|---|---|---|
| **T1** | transcript constructor, legacy | `zkp-core/src/transcript.rs:30` | `new()` | `"hashline-v1/"(12) ‖ domain` | `12+\|d\|` | both | public |
| **T2** | transcript constructor, tagged | `transcript.rs:41` | keyed, **transcript key** | same layout | `12+\|d\|` | both | public |
| **T3** | transcript absorb | `transcript.rs:61` | selector, transcript key or none | `state(32) ‖ le64(\|l\|) ‖ l ‖ le64(\|d\|) ‖ d` | `48+\|l\|+\|d\|` | both | **public** (see B-5) |
| **T4a** | transcript squeeze, live | `transcript.rs:103` | selector | `state(32) ‖ "squeeze"(7) ‖ le64(ctr)(8)` | **47** | both | public |
| **T4b** | squeeze off a discarded clone — a run **position tag** | `run.rs:404-411` via `transcript.rs:156-162` | selector | identical to T4a | 47 ×2 | both | public |
| **T4c** | squeeze off a discarded clone — the **refusal replay** | `protocol.rs:305-306`, `:367-368`, `boundary.rs:281-283` | selector | identical to T4a | 47 each | prover, then verifier | public |
| **P1** | column digest, single (verify side) | `zkp-core/src/pcs.rs:139` / keyed `:149` | selector, **column key** | the column's `rows` words, LE, **no tag, no length prefix** | `8·rows` | both | **secret** for unopened |
| **P2** | column digests, bulk (commit side) | `pcs.rs:171` (`blake3::hash`) / keyed `:196` | selector, column key | same bytes | `8·rows` × `nn` | prover | secret |
| **P3** | salted leaf | `pcs.rs:678` / keyed `:692` | selector, **leaf key** | `column digest(32) ‖ salt(32)`, **untagged** | **64** | both | **secret — the salt** |
| **P4** | Merkle inner node | `zkp-core/src/merkle.rs:15` / keyed `:28` | selector, **node key** | `left(32) ‖ right(32)`, **untagged** | **64** | both | secret above unopened |
| **P5** | `M` column digest | `hashline/src/zk.rs:689` / keyed `:697` | selector, column key | as P1, `rows = 50` | **400** | both | secret |
| **R1** | generator **seed derivation** | `zkp-core/src/rng.rs:47` | **keyed, key = 32 raw `/dev/urandom` bytes** | `"hashline-zk-os-rng/v1/"(22) ‖ domain` | `22+\|d\|`; **64** at `endpoint_g` | prover | public message, **secret key** |
| **R2** | generator **refill** | `rng.rs:54` | `new()`, **XOF → 8,192 B** | `key(32) ‖ le64(counter)(8)` | **40** | prover | **secret — the key** |
| **R3** | generator fixture seed | `rng.rs:21` | `new()` | `"hashline-zk-rng/"(16) ‖ domain ‖ le64(seed)` | `24+\|d\|` | — | public; **off the production path** |
| **K** | tag key derivation ×4 | `zkp-core/src/hashtag.rs:95-98` | **`derive_key`** | contexts of 48/43/48/47 B over the profile string | — | both | public |
| **D1** | calibration identity | `hashline/src/private_block.rs:222` | `new()`, **unkeyed at every rule** | `b"B3 public fixed calibration v1"` | **30** | both | public constant |
| **D2** | block public / weights digest | `private_block.rs:513` | `new()`, unkeyed | `b"hashline/private-block-public/1"(31) ‖` length-prefixed weights | `31+w` | both | public, **attacker-chosen weights** |
| **D3** | block schedule digest | `layout.rs:1289` | `new()`, unkeyed | `b"…-schedule/1"(33) ‖ Σ(le64(len) ‖ line)` | `33+Σ` | both | public |
| **D4** | run public statement | `run.rs:221` | `new()`, unkeyed | `b"hashline/private-run-blocks/1"(29) ‖ L×32` | `29+32L` | both | public |
| **D5** | run schedule digest | `run.rs:286` | `new()`, unkeyed | `b"…-run-schedule/1"(31) ‖ Σ(le64(len) ‖ line)` | `31+Σ` | both | public |
| **D6** | generalised endpoint spec digest | `endpoint_g.rs:158` | `new()`, unkeyed | `DOMAIN(42) ‖ ctx(32) ‖ 8×u64 ‖ i32` | **142** | both | public |
| **D7** | internal boundary spec digest | `boundary.rs:211` | `new()`, unkeyed | `DOMAIN(43) ‖ ctx(32) ‖ 9×u64 ‖ i32` | **151** | both | public |
| **D8** | frozen-seam spec digest | `private_seam.rs:116` | `new()`, unkeyed | `DOMAIN(28) ‖ ctx(32) ‖ 8×u64 ‖ i32` | **128** | both | public |
| **C1** | capture / sink file digests | `run_capture.rs:325, 803, 1002, 1544…`; `run_sink.rs:29, 49-51`; `export_v3.rs:168-173` | **SHA-256, not BLAKE3** (`sha2`) | file bytes | var | capture | **a different hash function entirely — it shares no oracle with anything above** |

**Not on the path, checked clean [COUNTED]:** `wire.rs` hashes nothing;
`run_statement_file.rs`, `run_sink.rs` are SHA-256 only; `audit_claims`
(`protocol.rs:230-274`) performs **zero** hash calls — its wrapper
`check_opening` only clones the transcript and squeezes (row T4c);
`private-block-kernel*`, `zkvm-*` contain no call site;
the CUDA column kernel (`gpu/kernels.cu:447-600`) is a hand-written unkeyed
BLAKE3, feature-gated and declined by tagged commitments (`pcs.rs:782-785`,
ruling T-8).

**In the crate but off this path, and therefore sharing `F_U` at a legacy
profile [COUNTED]:** the two 40-byte `Transcript::new` constructors
(`private_seam.rs:26` with `b"experimental-private-seam/v1"`,
`public_block_receipt.rs:20` with `b"zk60-public-block-receipt-v1"`, both
`12+28 = 40`), the private-attention profile's constructor (55), and
`stable_weight_*`, `wcache`, `pcs_compact`, `attention_schedule`,
`public_chain_receipt` (which holds the tree's **only other** `derive_key`,
`public_chain_receipt.rs:119`).

### 5.1 The lengths, per shape [COMPUTED]

Every number below is `query_classes.py`'s, from the layouts above. The four
shapes the D19 scoping memo tabulated reproduce it exactly; `rung-K4`'s column
lengths are new here (from `a_rows = 727`, `h_rows = 720`).

| | toy | rung | rung-G | rung-K4 | 125M |
|---|---:|---:|---:|---:|---:|
| rule | legacy | legacy | tagged | tagged | tagged |
| transcript constructor (T1/T2) | 51 | 56 | 58 | 59 | 48 |
| column digest `A` | 3,640 | 4,984 | 4,984 | 5,816 | 45,448 |
| column digest `H` | 3,072 | 4,608 | 4,608 | 5,760 | 56,960 |
| column digest `M` | 400 | 400 | 400 | 400 | 400 |
| column digest endpoint | 56 | 168 | 72 | 72 | 296 |
| column digest boundary | — | — | 80 | 80 | 304 |
| **seed derivation, block prover (R1)** | 61 | 66 | 68 | 69 | 58 |
| **seed derivation, endpoint (R1)** | 50 | 50 | **64** | **64** | **64** |
| `pcs-vec` absorb, block | 8,247 | 20,535 | 20,535 | 20,535 | 266,295 |
| `pcs-vec` absorb, endpoint | 8,247 | 8,247 | 20,535 | 20,535 | 266,295 |

Fixed at every shape: squeeze **47**; refill **40**; node and salted leaf
**64**; `rows` absorb 60, `pb-slot` 63, **`log-cols` 64**, `pb-run-stage` 68,
`pb-scalar` 73, root absorbs 81, `schedule` 88, `pb-run-block` 92,
`public-statement` 96, `sc-round` 104/120/136/152, `run-shape` 113,
`expected-IO` 171, `mask-q` 16,438, `mask-prox` 16,441; `pb-term` `55 + 16k`;
calibration 30, seam spec 128, endpoint spec 142, boundary spec 151.

Runs: constructor 56 (rung-G `L=3`), 57 (rung-K4 `L=3`), **46** (125M `L=12`);
run public statement `29 + 32L` = 125, 125, **413**.

## 6. The classes, and what separates them

### 6.1 Under the LEGACY rule (the toy, the frozen-seam rung)

**Claim B-2.** There is **one** unkeyed function. T1, T3, T4a/b/c, P1–P5,
R2, R3, D1–D8 and every off-path unkeyed digest are queries to it. The only
separations available are (i) **input length**, (ii) **a fixed literal at a
fixed offset**, and (iii) for R1 only, **BLAKE3's keyed mode under a secret
key** (convention V-2).

`query_classes.py` computes the whole length set per shape. At the toy, 95
input kinds occupy 86 distinct lengths, with **four genuine clashes** (two
more are one call kind at two geometries):

| length | who shares it | what separates them |
|---|---|---|
| **64** | P3 salted leaf, P4 Merkle node, T3 `absorb "log-cols"` | leaf vs node: **NOTHING** (both `blake3(32‖32)`, untagged) — ruling L-7, 2^-484.8. Against the absorb: the absorb carries `le64(8) ‖ "log-cols" ‖ le64(8)` at a fixed offset, so a coincidence needs a digest to spell 24 fixed bytes — 2^-241.42 as counted |
| **81** | T3 `absorb "A"/"H"/"B"/"M"` | the **label byte**, at a fixed offset. Not a length separation at all |
| **151** | T3 `absorb "pb-term"` with 6 terminals, D7 boundary spec digest | a fixed literal on both sides; a coincidence needs a transcript state to equal the 43-byte `DOMAIN` prefix — 2^-256 per absorb. **NEW, §7** |
| **171** | T3 `absorb "expected-IO"`, T3 `absorb "parameters"` | the label bytes |

### 6.2 Under the TAGGED rule (rung-G, rung-K4, 125M, and the runs)

**Claim B-3 [COUNTED].** Five functions, not six (ruling H-3): `F_T`
(transcript key), `F_C` (column key), `F_L` (leaf key), `F_N` (node key), and
`F_U`, still unkeyed, carrying **R2 the refill and every statement digest
D1–D8**. Plus R1's keyed function under a secret key, and `derive_key` for K.

Inside `F_T` the only genuine clash is the 81-byte root absorbs (the label
byte separates them). Inside `F_C`, `F_L`, `F_N`, `F_U` there is none.

**The cross-family coincidences are the interesting rows**, because a length
argument says nothing about them and a *mode* argument has to. At rung-G,
rung-K4, 125M and all three runs [COMPUTED]:

| length | the pair | separated by |
|---|---|---|
| 64 | P3 leaf (`F_L`) vs P4 node (`F_N`) | **the two keys** — D19a's family reading, whose honest justification is proposed **D19b** (ideal compression function at an adversary-chosen chaining value). Under the legacy rule: nothing |
| 64 | T3 `absorb "log-cols"` (`F_T`) vs P3/P4 | the keys |
| **64** | **R1 seed derivation at the generalised endpoint** (keyed, secret OS key) **vs P3 leaf and P4 node** | **BLAKE3's keyed mode and a key the adversary does not know — convention V-2, and nothing else.** This is the check's B-2(a), and it is the sharpest row in the table: by length it is in the leaf/node class, twice per block, on the production path |
| 68 | T3 `absorb "pb-run-stage"` (`F_T`) vs R1 seed derivation at the rung-G block prover | the keys |
| 151 | T3 `absorb "pb-term"(6)` (`F_T`) vs D7 boundary digest (`F_U`) | the transcript key vs unkeyed |

### 6.2a The partition into classes, with the separating feature per pair

**Claim B-4 [COUNTED].** Six classes, not two. A pairwise matrix over 24 rows
is unreadable; this is the partition, and every pair of classes has one named
separating feature.

| class | members | what it is |
|---|---|---|
| **X_T** | T1/T2, T3, T4a, T4b, T4c | the challenge chain and the prover's own replays of it |
| **X_C** | P1, P2, P5 | column digests |
| **X_L** | P3 | salted leaves |
| **X_N** | P4 | Merkle inner nodes |
| **X_G** | R2 (refill), R1 (seed derivation) | the generator |
| **X_D** | D1–D8, R3, K | public digests, fixtures, key derivation |

| pair | separated, under the legacy rule, by | under a tag, by |
|---|---|---|
| X_T / X_C | length: no `8·rows` on a registered path meets a transcript length (the completed guard) | the transcript key vs the column key |
| X_T / X_L, X_T / X_N | length, **except `absorb "log-cols"` at 64** → a fixed 24-byte literal, 2^-241.42 | the keys |
| X_T / X_G | length: 40 and `22+\|d\|` against the transcript set; the constructor margin is **1 byte** at the 125M run profile | the keys (refill stays unkeyed: length again) |
| X_T / X_D | length, **except `pb-term(6)` = 151 = the boundary digest** → a fixed 43-byte literal, 2^-256 | the transcript key vs unkeyed |
| X_C / X_L, X_C / X_N | length: no commitment has 8 rows (the guard refuses it) | the keys |
| **X_L / X_N** | **NOTHING** — 2^-484.83 | the two keys, under D19b |
| X_L / X_N / X_G | **`22+42 = 64` at the generalised endpoint**: the seed derivation is leaf/node-length. Separated by **mode and a secret key only** (V-2) | the same — the tag does not touch it |
| X_C / X_D | length, **except `rows = 16` → 128 = the seam digest**, refused by nothing | the column key vs unkeyed |
| X_G / X_D | length (40 against 30/128/142/151/`29+32L`/schedules); `29+32L ≠ 40` proved | unchanged |
| anything / C1 | a different hash function (SHA-256) | unchanged |

### 6.2b Every absorbed word is public — the hypothesis K-R4 asks to be
### matched to the code

**Claim B-5 [COUNTED].** The check's B-7 made "every word the transcript
absorbs is public" a numbered hypothesis of the lemma, and K-R4 asks for it to
be matched to the code with the lines. It holds **by construction**, and the
construction is one sentence: *the verifier recomputes every absorb from the
receipt.* The verifier's absorb sequence is the prover's, site for site —
`protocol.rs:860, 861, 862-864, 868` against the prover's `:666, 676,
682-684, 774`; `sumcheck.rs:154` against `:109`; `argument.rs:378` against
`:347`; `run.rs:640, 641, 645` against `:494, 495, 505`; the masked extension
round `zk.rs:1099` on both sides; `pcs::verify_zk` `:1090, 1095` and
`verify_zk_tagged` `:1212, 1217` against `open_zk` `:1033, 1035`;
`zk::mask_verify` `:613, 616` (legacy) and `:657, 660` (tagged) against
`mask_open` `:584, 593`. A word the verifier
could not recompute would fail the receipt, and the lane pins the agreement
with `honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_
transcript_order` (`tests.rs:92-95`). **So the hypothesis is not an
assumption here; it is a consequence of the protocol being publicly
verifiable, and the pin exists.** It is the only hypothesis of the lemma in
that happy position.

The one thing it does *not* cover: an absorb of a value that is public but
**attacker-chosen**. There is exactly one, D2 (the block's weights digest),
and it is the row §9 marks to watch.

### 6.3 The hypothesis's form is wrong, and the repair

**Claim B-6 [COUNTED + ARGUED] — the prover DOES query the transcript class.**
The kernel draft's §1.3 partitions the oracle's inputs into a transcript class
`T` and a prover class `P`, sets `ξ := O|_T`, and says a random oracle's
restrictions to disjoint sets are independent. That is right about the
*inputs* and wrong about the *queries*: the prover makes `T`-queries, in two
families:

* **the position tag** (T4b) — two squeezes off `clone_state`, which copies
  the state, the counter **and** the key (`transcript.rs:156-162`), so the
  two 47-byte inputs are exactly the two the live chain will query next if no
  absorb intervenes (K-R2 already records this);
* **the refusal replay** (T4c) — `check_opening` clones and draws
  `Σ counts + rows` challenges (`protocol.rs:305-306`,
  `check_opening_challenges` `:282-293`), and then `pcs::open_zk` draws
  *the same* `Σ counts + rows` challenges from the live transcript
  (`zk_rhos`, `pcs.rs:943-964`). **These are not two near-misses; they are the
  same oracle points, queried twice, by design.** No document names this
  family, and it is far larger than the tag's two inputs.

Neither is a leak, and neither breaks the hypothesis — but the hypothesis has
to be restated to be true:

> **(iii-a′)** *Every transcript-class query the prover makes is at a point
> determined by the public prefix* — so the prover learns `ξ` only at points
> the verifier evaluates too, and learns nothing about `ξ` beyond the
> challenges themselves.

Consequences. (1) Any count of **distinct** queries — `ε_hit`, the collision
rows, the former `B_sep` — must not double-count them, and must not assume
the prover makes none. (2) The clean statement "the classes are disjoint" is
false as a statement about the prover's behaviour and true as a statement
about the oracle's input sets; the two were being used interchangeably.

## 7. Every pair separated by nothing structural, priced

**Claim B-7 [COUNTED].** Exactly one pair on the production path is separated
by nothing at all, at any rule:

> **P3 salted leaf and P4 Merkle inner node**, both `blake3(32 ‖ 32)`, 64
> untagged bytes, `pcs.rs:678` and `merkle.rs:15`. Under the **legacy rule**
> (the toy, the frozen-seam rung) they are literally the same function on the
> same input shape. Price for hiding: **2^-484.83** (ruling L-7 / correction
> C-4). Price for **soundness**: not a probability — the depth-confusion
> ambiguity, which the wire format and ruling T-4's path-length check close
> (`hash_domain.rs:379-390`, `:427-438`), not the hash. Under a tag the two
> keys separate them, at the cost of assumption **D19b**.

**Claim B-8 [COMPUTED] — NEW: the 151-byte pair.** `absorb "pb-term"` with
six terminals is `48 + 7 + 96 = 151` bytes; the internal-boundary spec digest
(`boundary.rs:211`) is 151 bytes and is **unkeyed at every rule**. At a tagged
profile the absorb is in `F_T` and the digest in `F_U`, so the key separates
them. But a legacy profile's absorb is in `F_U` too, and a legacy profile has
no boundary — so the live pair is **cross-profile**: a legacy toy proof's
`pb-term(6)` absorb and a tagged run's boundary digest are queries to the same
unkeyed function, on one machine. The separation is probabilistic: the digest
begins with a 43-byte ASCII `DOMAIN`, the absorb with a 32-byte transcript
state, so a coincidence needs a state to equal that literal's first 32 bytes —
`2^-256` per absorb, the same shape and the same price as finding F-2's
constructor-versus-squeeze margin. **[UNVERIFIED]** whether any slot's
`pb-term` really carries six terminals: the range `1..56` used here is an
over-approximation from the toy memo; `hash_domain.rs:172-182` builds the
exact per-slot set. Work-list item **W-6**.

Also computed and clean: `55 + 16k` is `7 mod 16` for every `k`, and a column
digest is `0` or `8 mod 16`, so **no `pb-term` absorb can ever equal a column
digest**, at any shape [PROVED]. And `29 + 32L = 40` has no integer solution,
so the run public statement can never land in the refill class [COMPUTED].

**Claim B-9 [COMPUTED] — NEW: the dangerous row count in no guard.** A
commitment of **16 rows** hashes a column to 128 bytes, the length of the
frozen-seam spec digest D8. The lane's completed guard
(`hash_domain.rs:239-256`, imposed at `:320-326`) builds its set from the
transcript lengths, the squeeze, the refill and the node — **the statement
digests D1–D8 and the seed derivation R1 were never in it**. So 16 is
dangerous at every shape and refused by nothing. No real commitment is at 16
(toy 455/384/50/7; rung 623/576/50/21; rung-G and K4 …/9/10; 125M
5681/7120/50/37/38), and the assertion in `query_classes.py` confirms no real
count is on any dangerous value — but the *set* is incomplete, and the next
geometry is the risk, exactly as stage 16's own finding S16-F1 said about a
different half of the set.

**The 47-byte margin, recomputed** [COMPUTED]: the dangerous domain length is
35 (`12 + 35 = 47`). Measured over all seven registered profiles plus the toy,
the nearest is the **125M run profile at 34 — one byte away**, which is ruling
**H-8**'s margin and is watched by no test today.

## 8. What pins each separation, and the work list

**Claim B-10.** The "what pins it" column, honestly:

| separation | pinned by |
|---|---|
| 47 is occupied by nothing else, on the path | **nothing**, at the run profile — ruling H-8's one-line test is **owed** (W-2) |
| 40 is occupied by nothing else, on the path | the completed length guard, legacy profiles only (`hash_domain.rs:266-277`, `:320-326`); false crate-wide (ruling L-3) |
| the label table is complete | `every_absorb_label_on_the_path_is_in_the_table` (`hash_domain.rs:98-101`, naming a source-scan test) — **this is a real pin and the best one in the table** |
| the refill still hashes 40 bytes | `hash_domain_tests.rs:35`, a source-text assertion |
| the four tag keys are pairwise distinct | `hashtag.rs:206-220` for rung-G and 125M's eight; rung-K4's four only as a **set** (`hash_tag_tests.rs:96, :109`) — the twelve-key pairwise test is **owed** (ruling H-4) |
| leaf ≠ node under a tag | the two keys; the isolated controls of ruling T-6 |
| leaf ≠ node under the legacy rule | **nothing** — 2^-484.8, and T-4's path-length check for the soundness half |
| the tag travels through a clone | the `clone_state` comment and ruling T-7; a unit test recomputes the legacy transcript by hand (`transcript.rs:231-235`) |
| the position tag's re-issue is harmless | the lane's stage-24 test (per K-R2) |
| **the refusal replay's re-issue** | **nothing — and nobody has named it** (W-3) |
| no commitment is at a dangerous row count | the completed guard, **legacy profiles only**, and its set omits D1–D8 and R1 (W-4) |
| the seed derivation is separated from leaves and nodes | **convention V-2 alone** — no test, and none is possible: it is a model statement (W-5 is a *documentation* item, not a test) |
| the capture writer is a different function | `export_v3.rs:168-173` uses `sha2`; no test asserts it must stay so |

### The work list for the lane — one line each, no code written here

| # | the test |
|---|---|
| **W-1** | assert that `Fp::from_u128` is a reduction and that `fp()` consumes exactly 16 stream bytes, **named as a privacy-relevant property** (today it is an arithmetic fact nobody guards); the natural home is beside the D9 fixtures |
| **W-2** | ruling H-8's: no registered profile's `Transcript::new*` input has the squeeze length — equivalently no profile domain is 35 bytes — over every profile the lane registers, runs included |
| **W-3** | the refusal replay re-issues exactly the challenge points the live chain draws next, and the live transcript's counter is unchanged by it — on a real block's real openings, extending the stage-24 tag test to the replay family |
| **W-4** | extend the length-guard set with the statement digests D1–D8 and the seed-derivation input `22+\|domain\|`, so `rows = 16` and the endpoint's 64 are in it; keep the imposition legacy-only |
| **W-5** | a table in the register naming, per pair of BLAKE3 functions, the model that separates them (length, literal, mode, key), so D19b's scope is auditable |
| **W-6** | print the exact per-slot `pb-term` data lengths at every registered shape and assert none equals a statement-digest length (151 is the live one) |
| **W-7** | the twelve-key pairwise distinctness test of ruling H-4 |
| **W-8** | **the draw-accounting test of ruling R-3**, assertions 1–5 of §3.1 — needs a consumption accessor in `zkp-core/src/rng.rs`, which is to be **requested of the integrator** |

## 9. Which rows matter for privacy, which only for soundness

**Claim B-11.** The composition lemma's independence hypothesis is about
**prover-side queries against challenge-derivation queries**. Sorting the
table:

* **Privacy-relevant (the hypothesis):** T3, T4a, T4b, T4c (the challenge
  derivation and the prover's own queries into it — claim B-6); P1–P5 and R2
  (the prover's queries that carry a secret: the unopened salts and the
  stream key); R1 (keyed, secret key). These are the rows the hypothesis
  quantifies over.
* **Privacy-irrelevant but hypothesis-relevant:** T1/T2, D1–D8, K, R3 — their
  inputs are public, so the adversary can make those queries itself and they
  are already inside the `q` budget. They matter only because a *coincidence*
  with a secret-carrying input would import a secret query into a public
  class. That is why D2 (attacker-chosen weights) is the one to watch: it is
  the only `F_U` input whose length an adversary moves.
* **Soundness only:** the leaf/node ambiguity's binding half (ruling L-7 and
  T-4), `verify_zk`'s missing path-length check, transcript-state collisions.
  None of them is in this page's scope and none is reviewed here.

**Claim B-12 — the model behind each separation.**

| separation mechanism | model |
|---|---|
| different input **length**, same function | plain random oracle: restrictions to disjoint input sets are independent random functions. No extra assumption; the residual is the coincidence probability |
| a fixed **literal** at a fixed offset, same function | the same, plus an argument that the other side's bytes at that offset are a hash output: `2^-8·(literal length)`, in practice `2^-256` for a 32-byte state |
| different BLAKE3 **mode** (`hash` / `keyed_hash` / `derive_key`) | BLAKE3's own design claim, convention **V-2**. This is the one the designers' claim really covers |
| same mode, different **public** key (`F_C` vs `F_L` vs `F_N` vs `F_T`) | **proposed D19b**: the compression function is ideal also at an adversary-known, adversary-chosen chaining value. Stronger than D19 as put to the project owner; nothing accepted rests on it |
| same mode, a **secret** key (R1) | convention **V-2** read as an independent oracle indexed by the key; conservative, because the adversary is given the power to query at any key |
| a different hash function (SHA-256, C1) | no shared oracle; nothing to say |

---

## 10. Step table

| # | step | where | label |
|---|---|---|---|
| 1 | `fp()` is modular reduction, 16 bytes, no rejection | A-2 | **COUNTED** |
| 2 | no re-draw or witness-conditioned draw exists on the path | A-3 | **COUNTED** |
| 3 | the eleven-segment schedule, in order, with offsets | A-4, A-5 | **COUNTED** |
| 4 | the totals reproduce D9's 327,052 and H-6's four figures | A-5, A-7 | **COMPUTED** |
| 5 | the position map is a function of the shape alone | A-8 | **ARGUED** from 1–3; no test — **GAP-JS-1** |
| 6 | three generators at a block; one for a whole run plus two | A-6 | **COUNTED** |
| 7 | clause (a) is immediate given M-3 and step 5 | A-10 | **PROVED** (given the two inputs) |
| 8 | the stream is uniform | A-10 | **ASSUMED** — M-3, ruling C-3 |
| 9 | `Pr[rej] = 2^-64` ≠ `TV = 2^-96`, and `2^-64` is optimal for an exactly-uniform good event | A-12, A-13 | **PROVED + COMPUTED** |
| 10 | the sampler is a distance hop before the lemma; data processing licenses it under any schedule | A-14 | **PROVED**; agrees with ruling K-R4a |
| 11 | clause (b): publishing `ρ`-selected salts adds nothing to `V` | A-15 | **ARGUED** from the code; rider 1 not machine-checked |
| 12 | clause (c): Lemma H's conditional kernel | A-16 | **RELIES ON** `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2 |
| 13 | clause (c′): unopened salts uniform given the opened ones | A-16 | **GAP, now stated** — immediate from M-3 + A-15 rider 2, not written before |
| 14 | clause (d): the flag is `B_salt ∪ B_logup`, union over both worlds | A-17 | **PROVED** given K-R1 and K-R4a |
| 15 | counterexample (i) excluded by disjoint positions | A-18 | **COMPUTED**; the excluding clause is a code theorem, **untested** |
| 16 | counterexample (ii) excluded by M-3 for an accident, by the position map for a broken discipline | A-19 | **COMPUTED**; the excluding clause is a code theorem, **untested** |
| 17 | what the owed draw-accounting test must assert, and that it needs an `rng.rs` hook | §3.1 | **ARGUED** |
| 18 | ζ and `mu_pad` come from the transcript, not the generator | A-20 | **COUNTED** |
| 19 | a run carries one generator; the per-stage offsets are deterministic | A-21 | **COUNTED** |
| 20 | 24 call kinds, with mode, key, layout, length | B-1 | **COUNTED** |
| 21 | the legacy-rule clashes: 64, 81, 151, 171 | B-2 | **COMPUTED** |
| 22 | the tagged-rule families and the five cross-family coincidences | B-3 | **COMPUTED** |
| 22a | the six-class partition with a separating feature per pair | B-4 | **COUNTED + COMPUTED** |
| 22b | every absorbed word is public, because the verifier recomputes it | B-5 | **PROVED** (a code fact, and pinned) |
| 23 | the prover queries the transcript class; the hypothesis restated | B-6 | **COUNTED + ARGUED** |
| 24 | leaf vs node is the only pair separated by nothing | B-7 | **COUNTED** |
| 25 | the 151-byte `pb-term`/boundary-digest pair | B-8 | **COMPUTED**; the six-terminal slot is **UNVERIFIED** |
| 26 | `rows = 16` is dangerous and in no guard | B-9 | **COMPUTED** |
| 27 | the pin table and the eight-item work list | B-10 | **COUNTED** (what exists) + **ARGUED** (what is owed) |

## 11. What the checker should attack first

1. **The hop order, hardest.** Claim A-14 says data processing licenses
   replacing the real randomness by the ideal one *inside the adaptive
   experiment*. Is the whole experiment really a deterministic function of
   `(ω, O)` — including the distinguisher's own coins, including the abort,
   including the fact that the prover chooses when to stop? Build a protocol
   where it is not.
2. **Clause (c′), the within-segment conditioning.** The opened and unopened
   salts are one segment split by `ρ`. §2.4 says M-3 plus a `ρ`-determined
   selection makes the unopened half uniform given the opened half. In the
   *real* protocol `ρ` is a hash of the roots, which depend on **all** the
   salts. Show that the lift does not quietly use the fixed-challenge version
   of this where it needs the real one. This is the circularity this project
   has already refused one argument for.
3. **Claim A-8, the position map.** It is the load-bearing code fact and it
   rests on a reading of eleven sites. Find a twelfth draw. Look at
   `boundary::prepare`'s mask rows, the endpoint's five rows, the accelerator
   path, and anything reachable when a stage refuses mid-loop.
4. **Claim B-6.** Is the restated hypothesis (iii-a′) enough? A prover that
   queries a transcript point *before* the live chain reaches it learns a
   future challenge. The replay and the tag both do exactly that. Argue that
   causality is not violated — or find a case where it is.
5. **Claim B-1's completeness.** Twenty-four kinds. Find the twenty-fifth.
   Candidates not chased here: the `masker` path
   (`transcript.rs:84-85`, a masked `sc-round`), anything the GPU feature
   gate reaches, `run_capture`'s independent header rebuild
   (`run_capture.rs:265-279`).
6. **Claim B-8's [UNVERIFIED].** Read `hash_domain.rs:172-182` against
   `Shape::claim_sites()` and settle whether a six-terminal slot exists.

## 12. What this is not

* **Not a privacy acceptance.** Nothing here establishes a privacy property of
  the toy block, a shaped block, a run, or any artifact. D22 is untouched and
  does not rest on this page.
* **Not a proof that the joint sentence is true.** It is a *statement* of the
  sentence with its clauses separated, one of which (a) is immediate given an
  assumption the project has already named as its weakest, and one of which
  (c′) is written here for the first time.
* **Not a verification of the code.** Every code claim is a reading at
  `8c5922b`. No Rust was compiled, no test run, no proof produced.
* **Not soundness.** §9 says which rows are soundness rows and leaves them.
* **Not a review of Lemma H**, which is relied on in clause (c) as the
  security owner's disposition left it.
* **Not complete on `rung-K4`**: its `parameters` line was not read, so that
  shape's length set is missing one entry.

## 13. Gaps, by name

| name | what |
|---|---|
| **GAP-JS-1** | The position map's disjointness and witness-independence (A-8) is a reading of eleven sites, pinned by **no test at any shape**. It is the clause that excludes both counterexamples. §3.1 says what the test must assert; it needs a hook in `zkp-core/src/rng.rs`, which is another engineer's file and can only be requested. |
| **GAP-JS-2** | Clause (c′) — the unopened salts uniform given the opened ones, a within-segment conditioning — is stated here and rests on M-3 plus a `ρ`-determined index set. It is not proved anywhere, and Lemma H does not state it. |
| **GAP-JS-3** | M-3 itself, in ruling C-3's two-sided whole-stream form, is the only argument for salt/blinding independence, and a run stretches it across 47 commitments and eleven stage boundaries. Unchanged in kind; worse in degree. |
| **GAP-QC-1** | Claim B-1's completeness is a reading, not an enumeration a tool produced. No source-scan test covers hash *call sites* the way `every_absorb_label_on_the_path_is_in_the_table` covers absorb *labels*. |
| **GAP-QC-2** | Eight separations are pinned by nothing (§8): ruling H-8's margin, the refusal-replay re-issue, the incomplete guard set, the twelve-key pairwise test, and the four model statements that no test can pin. |
| **GAP-QC-3** | `rows = 16` (128 bytes = the frozen-seam spec digest) is dangerous at every shape and in no guard. No real commitment is there today. |
| **GAP-QC-4** | [UNVERIFIED] whether a slot's `pb-term` absorb is 151 bytes (claim B-8). |
| **GAP-QC-5** | The toy's own step 5 rests on Route A, which this page does not re-examine. Whether Route A's hops implicitly need clause (c′) — the check's own open question 4 — is not answered here. |
