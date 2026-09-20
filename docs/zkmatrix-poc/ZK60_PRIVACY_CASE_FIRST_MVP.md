# The privacy case for the first MVP — the argument, with every step labelled

**DRAFT for the security owner's review — NOT ACCEPTED and NOT a privacy
acceptance. Delegated Opus draft, 2026-09-19. It lays out an argument and
labels every step; several steps are open.**

| | |
|---|---|
| Author | delegated Opus cryptographic drafter, working for the security owner |
| Baseline | working tree at `perf/zk-batch-optimizations`, `f814ee8`, 2026-09-19 23:07 |
| Scope | the custom (hashline) line, profile `hashline-zk-mr1/private-block-t32-poc/1`; the zkVM line (D7) is referenced for contrast only |
| Occasion | ruling **D18** (2026-09-19): for the first MVP the **prover** seals the hidden input and output at proof time. The configuration D8/D11 bind does not arise in the first MVP's artifacts, so the standard game applies to them. Nobody had written down what "the standard game" then requires |
| What it is | the privacy case stated as a chain of numbered steps, each labelled **PROVED**, **COMPUTED ON CAPTURES**, **ASSUMED** or **OPEN**, so each can be attacked separately |
| What it is not | the acceptance. No privacy property is established here. D8 and D11 stay open and bind the configuration of the next milestone |
| Runs | nothing was built, run, tested or benchmarked for this document. Every number is read from a source file, from a committed record, or counted by hand and labelled as such |

---

## 0. For the project owner, in plain words

The product promise (decision **D1**) is that someone can check a proof that an
approved model produced an answer **without learning the prompt, the answer or
anything computed in between**. The custom prover now has one complete
transformer block that runs that way at a toy size. It is accepted only as an
**experimental component**: "no privacy property is established"
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md`).

Until today the road to saying more was blocked by an obligation called
**D8/D11**: what does a verifier learn when the sealed envelope holding the
hidden input was sealed by **somebody else** — a regulator, say, who fixes an
input today and asks for a proof about it tomorrow? That party keeps the key,
and the usual proof technique cannot treat it as an outsider. Today you ruled
**D18**: for the first MVP the **prover** seals the input and the output at the
moment it proves, and the seals appear for the first time inside the receipt.
Sealing in advance is a recorded todo for the milestone after.

That ruling does not close D8 or D11. What it does is change **which game has
to be won** for the thing being built. The game that now applies is the
ordinary one: *a program that knows no secret must be able to produce a receipt
nobody can tell apart from the real one.* This document writes down, for the
first time, what exactly would have to be true for that to hold, what is
already in hand, and what is not.

**The short version.** The candidate imaginary program is not exotic: it is
**the honest prover run on an all-zero input**. It knows the model (weights are
public under P1), it seals its own envelopes because D18 says the prover does,
and it produces a receipt of exactly the same shape. So the whole question
collapses to one thing: **does the receipt look the same whatever the hidden
input was?** That is a question about the bytes, and the bytes split into two
halves.

* **The numbers half** — claimed values, opened combinations, sumcheck
  messages. Here the evidence is real and recent: on four captured receipts
  from the actual prover, at their actual challenge values, the numbers pin
  down **nothing** about the hidden planes beyond one identity that is public
  and equal to zero. Every deliberate sabotage test fires. That is strong
  engineering evidence. It is **not** a proof: it is four challenge values out
  of astronomically many, and the project's own reviewer said so in writing.
* **The fingerprints half** — the 32-byte hashes that authenticate the opened
  windows. Under the old configuration this half had no argument at all,
  because the simulator had to produce paths under somebody else's root. Under
  D18 that difficulty **disappears**: the simulator makes its own root, so
  every hash it publishes is a genuine hash of its own data. What is left is a
  standard and universally made assumption — that a hashed value with a fresh
  32-byte salt hides what was hashed. That assumption now has to be **named in
  the statement**, not left implicit.

**What is still missing**, in one list a non-cryptographer can hold:

1. There is **no test** that the prover even accepts an all-zero input and that
   its receipt verifies. That is the imaginary program's existence certificate
   and it is a day of work (item **U-4**).
2. The four-challenge evidence has **never been lifted to all challenges**
   (item **U-3**). The lemma that would lift it is written and reviewed; its
   hypothesis is not established.
3. The **whole-view** analysis models the numbers as straight-line algebra. The
   real relation between the two halves of the proof is curved (degree up to
   four), and a curved leak is invisible to a straight-line tool.
4. Nobody has **written the simulator down** or computed a single overall
   number of bits.

**So the honest status is:** the first MVP's artifacts are in the ordinary
game for the first time, the numbers half has real evidence, the fingerprints
half became a named assumption instead of a hole, and four specific things
stand between today and a sentence that reads "privacy accepted for the toy
profile, in this model, with these residuals". Section 5 sets out what could
honestly be said at each rung, and section 7 ranks the four.

## 1. The claim

### 1.1 In plain words

**The claim the project would like to be able to make, for the first MVP:**

> A receipt produced by the private block prover reveals nothing about the
> hidden input, the hidden output, or any value computed inside the block,
> beyond what the public statement already says — which is the model, the
> calibration, the shapes, and the fact that *some* input of the declared
> integer class was processed. Anyone who is handed the receipt bytes learns
> no more than someone handed a receipt manufactured by a program that never
> saw the input.

Two terms, defined on first use. A **hidden plane** is one of the rectangles
of integers the proof keeps secret — the input `x_in`, the output `xres2`, and
every intermediate the block computes. The **verifier's view** is the complete
set of bytes a checker receives and every value it derives from them.

**What the claim does NOT say**, and this is a real limitation of the product
rather than of the argument: it says nothing about what an observer can infer
from *outside* the receipt. If a service answers only questions from a list of
thirty-two, the receipt hides which one was asked but the list is still thirty
-two long. This is history item **H6** of
`ZK60_D8_D11_RESTATEMENT.md` §1.3, and D7 already carries the same qualifier
for the zkVM line (`ZK60_DECISIONS.md:242-247`). No hiding commitment can buy
more than this, and the project should keep saying so.

### 1.2 The game

**The adversary.** A verifier — more precisely, any party that receives receipt
bytes. It is **not** restricted to behaving honestly. Concretely, it may:

| the adversary may | yes / no | why |
|---|---|---|
| choose the public statement: the weights, the activation table, `gamma`, the calibration, the request-context digest | **yes** | all of it is public input to the prover and is absorbed into the transcript before any commitment (`private_block/protocol.rs:25-27`, the header order). A privacy claim that held only for one fixture would be worthless |
| choose the hidden input, or a pair of candidate hidden inputs | **yes** | this is the standard indistinguishability formulation; the environment picks the witness |
| see **many** proofs by the same prover about related or identical hidden inputs | **yes**, and this is item 21 of the chain. Note that the answer today is evidence, not a theorem, and it covers **two** proofs, not an arbitrary number |
| see **refusals** — that a proof attempt did not produce a receipt | **yes**. Whether that is a leak is item 20 |
| see **timing** and memory behaviour | **out of scope for the first MVP** — and that is an owner ruling this document asks for (§5.3, ask R-3), not something the argument establishes |
| see receipt **sizes** and message counts | **yes**, and they are witness-independent by construction: the toy block's receipt is exactly 2,816,472 bytes for every witness, because every count in the layout is a public shape fact (`layout.rs:516-527`) |
| **fix a commitment root in advance** and then demand a proof about it | **no — excluded by ruling D18 for the first MVP.** This is the D8/D11 configuration. It is excluded by the *design of the product*, not by a theorem, and it comes back the day a third party seals an input |

**The simulator.** A program `S` that is given the **public statement only** —
the block's public weights, tables and `gamma`, the calibration digest, the
schedule digest, the 112-byte expected-IO policy's public part (context digest
and the two scales, both pinned to `(0, 0)` by `IoSpec::new`) — and **nothing
of the witness**: no plane, no pad, no mask, no salt, no seed, no auxiliary
leakage. It must output a complete receipt **together with the two endpoint
roots**, because under D18 the prover produces those roots. The distinguisher
then sees `(statement, roots, receipt)` in both worlds and must not tell them
apart.

**Which of the two standard experiments this is.** `ZK60_ENDPOINT_SIMULATION_MODEL.md`
distinguishes two games, and the distinction is the crux of D18:

* the **external-statement, root-only** game, where the roots are already
  fixed by a party the simulator never sees (`:37-42`) — the D8/D11 game, and
  the one the model document says "remains open rather than being relabelled
  as solved" (`:86`);
* the **joint preparation-and-proof** game, where the simulator issues its own
  roots during the preparation phase and keeps its own state (`:53-66`), cited
  to Lyubashevsky–Nguyen–Seiler Definition 2.8.

**Under D18 the applicable game is the second one**, for every artifact the
first MVP produces. That is a consequence of the ruling plus a code fact the
independent check confirmed on every path: `Endpoints` cannot leave the
process, is non-`Clone`, is consumed by value, is never built from a seed and
is never imported or serialised (`zk_ffn_fresh_io.rs:103-120`, three
`compile_fail` doctests). So in today's code the committer **is** the prover
and the first game does not physically arise
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2.2). *This is a statement about
which game applies. It is not a discharge of D8 or D11, which stand as
written.*

**Honest-verifier versus malicious-verifier.** The protocol is
non-interactive: every challenge is a BLAKE3 function of the public prefix
(`transcript.rs:44-52`). There is no verifier to be honest or dishonest during
the proof, so "malicious verifier" here means exactly two freedoms, both
granted above: an **adversarially chosen statement** and an **adversarially
chosen auxiliary input** (whatever the distinguisher already knows, including
prior receipts and prior oracle answers). There is no rewinding and no
challenge-choosing adversary. The price of that convenience is that every
challenge depends on the roots, which depend on the witness — the adaptivity
problem, chain item 10.

**Statistical or computational.** **Computational**, and it cannot be
otherwise. Three separate places force it:

1. the prover's randomness is a keyed BLAKE3 stream (`ZkRng`,
   `zkp-core/src/rng.rs:8-13`), not true randomness — a PRG assumption;
2. the leaves are `blake3(blake3(column) ‖ salt)` and the 212 or so *unopened*
   leaf digests published as siblings hide their columns only under a hiding
   assumption on BLAKE3;
3. the challenges are BLAKE3 of the public prefix, so the whole adaptive lift
   lives in the random-oracle model.

On top of the computational terms sit statistical ones, of which the largest
named today is the `fp()` reduction bias (D9).

### 1.3 The model: what is assumed about the world

| # | assumption | status | source |
|---|---|---|---|
| M-1 | **One random oracle** models BLAKE3 for the Fiat–Shamir transcript, the Merkle node hash and the salted leaf hash. These are not three domains: the transcript's `absorb_u64` input is 32 + 8 + 8 + 8 + 8 = **64 untagged bytes**, exactly the shape of `hash_pair(l, r)` and `salt_leaf(d, s)` | ASSUMED; the code fact is verified | `transcript.rs:44-52`; `merkle.rs:14`; `pcs.rs:640-645`. Recorded as hole 5 of the D8/D11 check and as O10 F10.1 |
| M-2 | **Salted-leaf hiding**: with a uniform 256-bit salt, `blake3(y ‖ s)` hides `y`. In the random-oracle model this is immediate (`≤ q·2^-256` over `q` queries); in the standard model it is a keyed-hiding / extractor assumption on BLAKE3 that **is not implied by collision resistance** and must be named | ASSUMED | `ZK60_D8_D11_RESTATEMENT.md` §3.4 |
| M-3 | **PRG on `ZkRng`**: the keyed BLAKE3 stream is computationally indistinguishable from independent uniform draws, in the specific direction that **later published outputs do not reveal earlier secret outputs**. This matters because within one commitment the pads are drawn first and the salts second from the same stream, and 256 of the salts are published in the clear | ASSUMED | `rng.rs:52-59`, `:91-97`; `pcs.rs:670-675`, `:935` |
| M-4 | **`fp()` reduction bias**: each field draw is a 128-bit integer reduced mod `p = 2^64 − 2^32 + 1`; its total statistical distance from uniform is **exactly 2^-96** per draw (the per-outcome relative bias, 2^-64, is a different quantity) | PROVED by exact arithmetic; **accepted by ruling D9** | `rng.rs:72-77`; D9 verification note, `ZK60_DECISIONS.md:395-410` |
| M-5 | **No side channels.** Timing, memory traffic, power and the behaviour of the surrounding service are outside the model | ASSUMED; **needs an owner ruling** (§5.3, ask R-3) | `ZK60_NATIVE_JOINT_VIEW.md` §7.7 |
| M-6 | **Application-level side information** (H6) bounds what any commitment can buy and is outside the proof | ASSUMED, and already carried as a D7 qualifier | `ZK60_DECISIONS.md:242-247` |

### 1.4 The target: what bound would be acceptable, and who rules on it

There is no privacy target on the register today. There is a soundness
comparison, and it sets the scale of what would be reasonable to ask.

**On the soundness side**, D15 is the clarification that matters: the
much-quoted "106 bits" is the level of **one opening** — `(3/4)^256` from 256
opened columns at encoding rate 1/4 (`zkp-core/src/pcs.rs:17-19`). A whole 8B
proof makes about six openings per layer over 32 layers, and the security
owner's projection puts it near **2^-94** (`ZK60_FABLE_SECURITY_OBLIGATIONS.md`
§5, deployment row — a PROJECTION). The tiny fixed block is a different object
at about **2^-110** over its two commitments, and that figure does not scale
up. The zkVM line sits at about 97 bits conjectured (D3). **At 8B both lines
are below 100 bits today, against a 128-bit target.**

**On the privacy side**, what a statement will look like once written:

> indistinguishable up to `ε_stat + ε_PRG + ε_ROM`, where `ε_stat` is at most
> about **2^-77.7** at the toy block shape and **2^-72.9** at the 125M shape
> from the `fp()` bias alone (§3.2 item 16), plus about **2^-113** for the
> LogUp collision event at the toy shape, and where `ε_PRG` and `ε_ROM` are
> the advantages of an adversary against M-2 and M-3 with the stated query
> budget.

**Three things follow, and the first two are asks for the project owner.**

1. **What is the target, in bits, and is it a per-artifact or a whole-run
   figure?** The same question D15 poses for soundness poses itself here. The
   recommendation of §5.3 (ask R-2) is: adopt **one whole-proof statistical
   target of 100 bits for the first MVP**, matched to where the soundness side
   actually sits rather than to the aspirational 128, and record that the
   computational terms are governed by M-1…M-3 rather than by a bit count.
2. **Who rules.** The project owner, in the way D3, D4, D7 and D9 were ruled,
   and it should be one ruling covering both sides so the two numbers are
   never quoted at different standards.
3. **What must not happen**: quoting 2^-96 (a per-draw term) or 2^-110 (the
   toy block's soundness) as "the privacy level". The privacy statement's
   dominant terms are computational and have no bit count until M-2 and M-3
   are given concrete query budgets.

## 2. The view, channel by channel

### 2.1 The receipt, byte class by byte class

The toy private block's receipt is **2,816,472 bytes**
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md` §3, measured). Its shape
is fixed: `Receipt { a_root, h_root, mask_root, slots, mask_open, a_open,
h_open, io_open[2] }` (`private_block/protocol.rs:404-405`). The geometry is
`log_cols 8`, `inv_rate 8`, `num_col_checks 256`
(`private_block/protocol.rs:21-23`), so each commitment has `n = 256` message
columns, `nn = 2048` encoded columns, an 11-level Merkle tree, and `Q = 256`
pad symbols per row (`ZkOpts::standard`, `pcs.rs:540-543`). `A` has 455 rows
(213 data), `H` 384 rows (280 data), each endpoint 7 rows (2 data), `M` 50
rows over a 4,096-wide coset with a 12-level tree (`layout.rs:519-526`,
`zk.rs:373-375`).

**The byte count, class by class** [COUNTED by this drafter from the
geometry; the 2,816,472 total is the measured figure and the residue is the
slots]:

| class | where | bytes | what it is a function of | what hides it |
|---|---|---:|---|---|
| **roots** | 3 × 32 | 96 | all of the witness, through the tree | M-2 (hiding of unopened leaves) + the pads and masks below the leaves; and, under D18, the simulator generates them itself |
| **opening-group vectors** | 46 groups × 512 `Fp2` (`A` 35, `H` 9, In 1, Out 1) | 376,832 | `v_g = Σ_i ρ_g[i]·z_i`, so the witness **and** the reserved mask rows **and** all pads | one reserved mask pair per claim site, audited by `audit_claims` (`protocol.rs:89-133`); the pair's two coefficients are an `Fp`-basis of `Fp2`, so the pair alone randomises the group vector over the whole 512 coordinates |
| **proximity vectors (PCS)** | 4 × 512 `Fp2` | 32,768 | same, with `ρ_prox` | a dedicated proximity pair, whose 2 × 2 determinant the verifier refuses if zero (`check_opening_challenges`, `protocol.rs:139-152`) |
| **claimed evaluations** | inside the slots | — | linear functionals of the data rows | each claim carries **its own** reserved pair; `audit_claims` refuses a shared or unused pair |
| **opened column values** | 5 × 256 columns × `rows` words | 1,849,344 | one linear functional `⟨E_j, z_i⟩` of **every** row, per opened column | the `Q = 256` pads per row: the pad half of `E_j` is `diag(x_j^n − 1)` times a Vandermonde in distinct nodes, full **row** rank for every `d ≤ Q` |
| **column indices** | 5 × 256 × 8 B | 10,240 | the transcript only | public by construction (`transcript.rs:119-131`, drawn **with replacement**) |
| **leaf salts** | 5 × 256 × 32 B | 40,960 | the prover's randomness only | nothing needs to hide them; they are published deliberately. They are, however, **later outputs of the same stream** that produced the pads — assumption M-3 |
| **authentication paths** | A/H/In/Out 256 × 11 digests, M 256 × 12 | 458,752 | the whole encoded matrix, through BLAKE3 | M-2. Includes the digests of **unopened** leaves: about **212.5** of them per 2,048-leaf tree, and the top pair with probability `1 − 2^-255` |
| **masked sumcheck rounds** | 23 slots | part of 14,712 | `masked_round_j = honest_round_j + c_s·g_s.round(j, ρ_<j)` | the CFS mask `g_s`, committed in `M` before any challenge; `L_s = (main+ext)·deg + 2` coefficients, `L_s + 256 ≤ 512` asserted (`zk.rs:442`) |
| **published masked scalars, `Γ`** | 23 slots | part of 14,712 | `s + c_s·G` for a private slot; `c_s·G` for a standalone | the same mask. Hosts run **after** the slots they host, so a host's claimed sum consumes the hosted masked scalars |
| **published terminals** | 173 on a block capture | part of 14,712 | evaluations of hidden planes at challenge points | each is republished as the value of the PCS claim its private table names (`argument.rs:223`), hence carries its own reserved pair |
| **mask evaluations** | 23 | part of 14,712 | derived, not observed: `mask_eval_s = (fin_s − poly_s(terminals_s))·c_s^{-1}` | not an independent observation at all — see chain item 6 |
| **the M opening's `q`** | 1,024 `Fp2` | 16,384 | `q = Σ_s p_{a_s} p_{W_s} + p_b` | `b` is uniform on 1,024 coefficients subject to `b[512] = −b[0]`, so it masks every coefficient of `q` **except** `q[0] + q[512]` — that one combination is the disclosed `Fp2` functional, and it equals the public θ-combination of the slots' terminal identities |
| **the `M` proximity vector** | 1,024 `Fp2` | 16,384 | `u + Σ r_row p_row`, `u` uniform with coefficient 1 | perfectly masked by `u` |
| **LogUp sums** | one sum claim on `H` | part of the H groups | `Σ_j u[j] = 0` | the individual helper sums are **never published**; only the value-0 claim on `u`, masked by a zero-sum pair. This is the one disclosed identity, and its published value is `Fp2::ZERO` |
| **counts and lengths** | throughout | — | public shape facts only | the layout asserts them (`layout.rs:521-526`: `A_GROUPS = 35`, `H_GROUPS = 9`, `N_FUNCTIONALS = 34`, `M_ROWS = 50`) and the verifier refuses a mismatch |
| **slots, scalars, framing** | the residue | 14,712 | — | — |
| **total openings + roots** | | **2,801,760** | | |
| **receipt (measured)** | | **2,816,472** | | |

**Two facts this table makes concrete.**

* **Hash material is 499,712 bytes, 17.7 % of the receipt** (salts plus
  authentication paths), and it is the part no linear analysis touches. Per
  *endpoint* opening the proportion is much higher: 98,304 of 131,072 bytes,
  **exactly 75 %** (`ZK60_D8_D11_RESTATEMENT.md` §3.1, reproduced here from
  the geometry).
* **Opened column values are 1,849,344 bytes, 66 % of the receipt** — and
  every one of them is a linear functional of *every* committed row. They are
  the reason the pad budget is load-bearing.

### 2.2 What is outside the receipt but still in the view

| channel | in the view? | what it is a function of |
|---|---|---|
| the public statement and the 112-byte expected-IO policy | yes, public | the model and the caller's context digest; the two endpoint roots travel here, not in `ENDPOINT_OPEN_BYTES` |
| the receipt's **length** | yes | nothing witness-dependent: it is 2,816,472 B for every witness at this profile |
| **whether a proof attempt produced a receipt** | yes, to anyone watching the service | chain item 20. The only witness-dependent refusal is the LogUp collision |
| **rejected-but-emitted receipts** | yes, if they are ever transmitted | `finish` has **no equality precheck** — a proof built against an endpoint committed to other values is fully constructed, emits 256 genuine authentication paths per root, and is rejected only by the verifier's polynomial identity (`private_block/protocol.rs:255-257`). History item H8 |
| **retained captures** | yes, on disk | `native_capture.rs::export` writes the receipt, the 112-byte policy and the JSON for every accepted capture (`:267-281`). A retained capture is a published opening of its two endpoint roots. History item H9 |
| timing, memory, power | assumed out of scope (M-5) | not analysed anywhere |
| prior proofs by the same prover | yes | chain item 21 |

## 3. The argument, as a numbered chain

### 3.1 How to read the labels

| label | means | what it does **not** mean |
|---|---|---|
| **PROVED** | a written proof exists, or the statement is a fact about the source that was read and can be re-read at a named line | that anyone has re-derived it independently, unless the entry says who |
| **COMPUTED ON CAPTURES** | a tool computed it from real captured receipts, and the record is on disk | a universal statement. The project's own review is explicit: *"Four actual captured vectors do not establish its universal premise"* (`ZK60_JOINT_VIEW_REVIEW_20260918.md:67-70`). Every such entry is evidence at **two challenge vectors per profile** |
| **ASSUMED** | a modelling assumption, stated, that the final theorem must name | that it is unreasonable. M-1…M-6 are standard; being standard is not the same as being written down |
| **OPEN** | nobody has established it. Each entry says what would close it and how big that is | that it is known to be false |

Where a step has a secondary character it is given as a **rider** under the
primary label, never merged into it.

### 3.2 The chain

#### Frame

**1. The game to win is the joint preparation-and-proof game.** — **ASSUMED**
(a modelling choice, settled by ruling D18 plus a code fact).
The simulator issues its own endpoint roots during a preparation phase and
keeps its own state; the roots are then fixed for the rest of the experiment
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:53-66`, Lyubashevsky–Nguyen–Seiler Def.
2.8). This is the right game **only because** D18 rules that the prover seals
(`ZK60_DECISIONS.md:582-617`) and because `Endpoints` cannot leave the process
(`zk_ffn_fresh_io.rs:103-120`, confirmed on every code path by the independent
check). *Rider:* the other game — roots fixed by a third party — is D8/D11 and
stays open. Nothing here narrows it.

**2. The simulator is the honest prover run on the all-zero witness.** —
**OPEN** (the construction is trivial; its **existence condition** is
untested).
`S(statement)`: take the public weights, tables, `gamma`, calibration and
context digest; build the all-zero input; run the honest witness builder, the
honest `prepare` for both endpoints and the honest prover; output the roots
and the receipt. `S` sees no witness, draws its own OS randomness, and is as
efficient as the prover. **What is not established is that it works**: no
Rust test builds the zero witness, proves and verifies. That test is U-4,
requested from Codex on 2026-09-15 and still absent — `grep` over
`hashline/tests` and `hashline/src/**/tests.rs` finds no zero-witness proof
test; the only "all-zero" hit is an unrelated norm-alias regression
(`hashline/tests/zk60_fable_arith.rs:348`). Round 1 §5 already specified it
and called it *"the simulator's existence condition"*
(`ZK60_MVP_SECURITY_DECISION.md` §5). **What would close it:** one integration
test, half a day. *Rider:* the zero input must remain **in the declared
integer class** for every future statement; if a profile ever declares a class
that excludes zero, this simulator must be replaced by one on a second random
witness.

**3. Given step 2, zero knowledge reduces to witness indistinguishability of
the whole view.** — **PROVED** (elementary, and stated here for the first
time).
If `S` is the honest prover on witness `0`, then "real vs simulated" **is**
"witness `w` vs witness `0`", for the same public statement. The move is
legitimate here for one specific reason, which must be re-checked whenever the
statement changes: **the public statement contains no witness-dependent value
except the two endpoint roots, and under D18 the prover — hence the simulator
— produces those roots itself.** The statement is the block's public weights,
tables and `gamma` (covered by one digest), the calibration digest, the
schedule digest, and the 112-byte policy whose non-root content is the
caller's context digest and two scales pinned to `(0, 0)` by `IoSpec::new`.
*Consequence worth saying out loud:* **all of the content of the privacy case
now sits in witness-indistinguishability.** There is no clever simulator to
build and no equivocation to perform. That is what D18 bought.

#### A — the linear channels: `A`, `H`, the two endpoints, and `M`

**4. Every claim, group vector and proximity vector carries its own reserved
mask pair, and the code refuses anything else.** — **PROVED** (source, read at
the line).
`audit_claims` (`private_block/protocol.rs:89-133`) refuses: a claim reaching
the proximity pair; a zero terminal mask coefficient; a claim not carrying
exactly its own adjacent reserved pair; a reserved pair unused or shared
between claims; a sum claim not masked by the zero-sum pair alone.
`check_opening_challenges` (`:139-152`) refuses a zero group-member
coefficient and a proximity pair with zero determinant, drawing from a
**cloned** transcript prefix and never resampling. `check_opening`
(`:154-176`) additionally refuses a group count different from the declared
35 / 9. The endpoints get their own shape check (`:196-204`). *Rider:* the
function's own doc comment names what it does not cover — *"PREMISE, not
proven here: independence from the sampled columns, the salted paths and the
CFS channel"* (`:86-88`). Items 5, 14 and 10 are those.

**5. The 256 opened columns are absorbed by the 256 pads per row.** —
**PROVED** (structural) with **COMPUTED ON CAPTURES** confirmation.
Each opened column reveals one linear functional of every row,
`E_j[msg s] = (x_j^{256} − 1)/(256(x_j ω^{−s} − 1))` and
`E_j[pad k] = (x_j^{256} − 1)·x_j^k` (the closed form of `encode_row_zk`,
`zkp-core/src/pcs.rs:611-632`). The pad half is `diag(x_j^n − 1)` times a
Vandermonde in the distinct nodes `x_j`, which has **full row rank for every
`d ≤ q_pad`, including `d = q_pad`**; absorption needs full *row* rank, not
spare columns. Measured: exact Gaussian rank **256 of 256** at the receipts'
own geometry, and boundary cases `q_pad = d`, `d+1`, `d−1` disclosing 0, 0, 3
(`ZK60_NATIVE_JOINT_VIEW.md` §9b). `commit_zk_owned_with` refuses `q_pad <
num_col_checks` (`pcs.rs:670`) and `ZkOpts::standard` sets them equal
(`pcs.rs:540-543`), so the margin the receipts happen to show — 9 to 25
symbols, produced by birthday collisions among 256 draws with replacement from
2,048 positions — is **surplus, not requirement**. The group vectors consume
no pad freedom: measured `q_pad · k0` with `k0 = 0` on every role of every
capture. *Rider:* `ZkOpts::standard` is shared with legacy paths whose digests
are frozen, so the "reserve one extra pad" defence-in-depth idea was declined
for a freeze reason, not a security one (§9a answer 2).

**6. At the receipts' real challenges the commitment side discloses `A` 0,
`H` 2, Input 0, Output 0.** — **COMPUTED ON CAPTURES**.
Four captures (two `private-block-t32-poc/1`, two
`private-attention-t32-poc/1`) under
`results/zk60_native_captures_20260919/captures/`, analysed by
`scripts/zk60_native_joint_view.py` on branch `zk60-native-jointview`, stages
1–2. The model is stated exactly and its three hypotheses (H-pad, H-pair,
H-prox) are **checked on the capture**, not assumed; the reduction formula is
validated against a brute-force dense rank on a small synthetic instance of
the same shape; the verifier's own column identity is re-checked on sampled
(group, column) pairs, 77 per block capture, 0 failures
(`ZK60_NATIVE_JOINT_VIEW.md` §2.1-2.3). **Limits, from the lane itself:** two
challenge vectors per profile; a *linear* model; hash objects excluded.

**7. The two disclosed dimensions on `H` are exactly the public LogUp
identity, and its published value is zero.** — **COMPUTED ON CAPTURES**.
The gate computes the disclosed row-functional `ξ(γ)` explicitly and checks
that its `Fp`-span equals the span of the LogUp sum claim's data-row weights
and that both have dimension 2 — the real and imaginary parts of one `Fp2`
identity whose published claim value is `Fp2::ZERO`, checked on every capture
(`ZK60_NATIVE_JOINT_VIEW.md` §2.3, §5). **Why this matters for step 3:** the
zero witness gives the same value, so the one disclosed functional does not
separate `w` from `0`.

**8. Stacking `A`, `H`, the endpoints and `M` adds nothing: joint = sum of
parts = 4 `Fp`.** — **COMPUTED ON CAPTURES**, on an **ASSUMED** hypothesis.
The hypothesis is *disjoint randomness*: each commitment draws its own pads
and salts and the CFS masks draw their own coefficients, so a functional
supported on data coordinates that is a sum across channels must have each
channel's part separately so supported (`ZK60_NATIVE_JOINT_VIEW.md` §4).
**This hypothesis is the one that bit somebody today.** The form-E
independent check measured a case where a blinding source is **shared** across
two commitments holding *different* planes: **joint 8, left alone 0, right
alone 0, sum of parts 0** — every per-commitment figure blind, only the joint
view seeing it (`ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md` §1.4 case 3b, §1.7).
Item 22 checks the hypothesis in the source for the block as built.

**9. From "disclosed dimension zero at these challenges" to "at all but a
negligible fraction of challenges".** — **OPEN**. This is the half of
**U-3** that is a generic-rank statement.
*What exists:* nothing written. `ZK60_MVP_JOINT_VIEW.md:67` names it — *"a
generic-rank argument for all non-refused `ρ` is the write-up obligation
U-3"* — and `ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5 reaffirms it as open on
2026-09-19. There is **no Schwartz–Zippel argument anywhere in the
repository** for this; I searched.
*What the argument would look like, and why it is plausible:* the disclosed
dimension is `dim_Fp(F ∩ T)`, and the reduction shows it equals `256·k0 +`
(a `u`-row term) with `k0 = dim{p ∈ rowspace(ρ) : p vanishes on every
non-data row}`. The entries of `ρ` are challenge-dependent, so `k0 > 0` is a
**determinantal condition** — the vanishing of certain minors, each a
polynomial in the challenge coordinates of bounded degree. Generic behaviour
is `k0 = 0`; the bad set is a proper closed subvariety; Schwartz–Zippel then
bounds the fraction of challenge vectors in it by `deg/|Fp2| ≈ deg·2^-128`.
*Why that is not yet a result:* nobody has (i) written the minors down,
(ii) bounded their degrees, (iii) shown they are **not identically zero** —
which is the step that carries the content and for which the four captures are
exactly the evidence that they are not, at four points, (iv) checked that the
refusal set (`check_opening_challenges`, the `c_s = 0` and `e = 0` refusals)
contains or is disjoint from the exceptional locus in the right way, and
(v) composed the bound over all five commitments and all 23 slots.
*Size:* a written lemma with the degree bookkeeping — days, not weeks, and it
is the single highest-value open item because every COMPUTED label in this
chain depends on it. *Owner class:* construction.

#### B — the masked sumchecks

**10. Every slot's mask covers the whole consistency subspace, so the masked
rounds are uniform on it given the data.** — **COMPUTED ON CAPTURES**.
`rank R_s = dim C_s` for **every** slot — 23 block, 18 attention — on all four
captures; the mask's own rounds stay inside `C_s` (0 violations); every
published `M` functional lies inside the round span (`rank F = 34` block / 28
attention, `rank(F mod rounds) = 0`) (`ZK60_NATIVE_JOINT_VIEW.md` §3). The
consequence for step 3 is that the masked rounds can be **sampled uniformly on
`C_s`** in the simulated world.

**11. The slot schedule's hiding discipline is enforced, not merely
designed.** — **PROVED** (source + tool).
`L_s + 256 ≤ 512` is asserted at commit time (`zk.rs:442`), and at the toy
profile the largest `L` is 50 of a 256 budget; at 125M the worst slot is the
softmax zero-check at `L = 94` (37 %), and at 8B it would be 98
(`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §5) — the masking commitment is not a
scaling problem on this line. A zero mask challenge is **refused outright and
never redrawn** (`private_block/argument.rs:275-276`;
`private_attention/argument.rs:261`; legacy `zk.rs:1675`, `:3533`); a
degenerate terminal mask challenge (`e = 0` or `e = 1`) likewise
(`argument.rs:347-348`); a zero batching challenge likewise (`:493-494`).
**Hosts run after the slots they host** — a host's claimed sum consumes their
masked scalars — and the transcript order is fixed and recorded
(`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` §5; `HOSTS`, `layout.rs:501-508`).
The six host groups were modelled jointly with their hosted slots, kernel 3,
nothing leaked.

**12. A derived mask evaluation is not an independent observation.** —
**PROVED** (a lemma with a three-line proof, ruled on by the security owner,
and asserted numerically per slot).
The verifier's final check is `fin_s = c_s·mask_eval_s + poly_s(terminals_s)`
— literally the code, `private_block/argument.rs:340` — and `c_s ≠ 0` is
refused, so `mask_eval_s = (fin_s − poly_s(terminals_s))·c_s^{-1}` with every
quantity on the right already published. The verifier **computes** it; it
never observes it (`ZK60_NATIVE_JOINT_VIEW.md` §3.1; security owner's answer 1
of §9a). The accounting consequence: the headline for these receipts is
**4 `Fp`**, with the pessimistic 70 / 58 reported beside it, never instead of
it. *Rider:* the lemma is an **ingredient** of a simulation argument, not the
argument. It says the simulator need not sample `mask_eval_s`; it says nothing
about whether the simulator's other samples have the right law.

**13. The strong per-slot terminal check: the verifier's own masked final
equation, recomputed.** — **COMPUTED ON CAPTURES**.
All 41 composition closures (23 block, 18 attention) were ported to Python and
the equation `fin_s == c_s·mask_eval_s + poly_s(vals_s)` recomputed with
`vals_s` rebuilt exactly as the verifier builds it: **82 of 82 slot equations
hold** on the four captures, **none not checkable, no capture field missing**.
Negative controls: perturbing one term of a slot's ported polynomial, and
perturbing one published terminal, each fire **at that slot and only there**,
23/23 and 18/18 (`ZK60_NATIVE_JOINT_VIEW.md` §11).
**What this closes:** the loop the 2026-09-18 review said was open — *"the
source-level link from the conditional model to the actual terminal
polynomial is still required"* (`ZK60_JOINT_VIEW_REVIEW_20260918.md:76-80`).
Before tonight the weak identity was blind to a perturbed terminal; now it is
not.
**What it does not close, and this is a rider that must travel with the
result:** (i) the equality of each Python function with its Rust closure is
established **by reading, not by machine** — the security owner has not
re-read it line by line, and no test can establish it; it is a **REVIEWED
OBLIGATION** (§11.4). (ii) It is a *consistency* check of the verifier's own
equation, not a statement that the equation leaks nothing. (iii) The public
tables are taken from the capture, not re-derived from the public statement.
(iv) Eight Rust files are pinned by sha256 and git blob id and a change is a
hard error — and `zkp-core/src/mle.rs` is one of them and is **currently
modified in the working tree**, so the port will need a re-pin before it runs
again.

#### C — the hash layer

**14. Under D18, the simulator programs no oracle point at all.** —
**PROVED** (this drafter's argument, from the code; it is the structural
consequence of the ruling and, as far as I can find, has not been written
down before).
In the D8/D11 game the simulator must publish authentication paths that add up
to a root **somebody else chose**; it holds no preimage of that root, so it
must program one oracle point (the tree's top pair), and that programmed point
is detectable if the honest top pair has ever been revealed — which is why the
one-point closure was retracted. **Under D18 none of that arises.** The
simulator of step 2 calls `private_seam::prepare` on the zero plane
(`private_seam.rs:186-198`), which builds a **genuine** tree: real column
hashes, real fresh 32-byte salts, real `salt_leaf`, real `MerkleTree::build`
(`pcs.rs:640-645`, `:662-679`). Every path it publishes verifies because the
tree is real. No oracle answer is ever changed, no query is refused, and the
`q/2^256` freshness bound of the candidate bookkeeping construction is not
needed.
**So the hash layer stops being an equivocation problem and becomes an
indistinguishability problem**: two genuine trees over two different data
sets. That is item 15. *Rider:* this is a statement about the first MVP's
artifacts only. It does **not** discharge D8 or D11, which bind the day a
third party fixes a root, and it does not survive any change that lets a
caller supply a root.

**15. What replaces programming: hiding of the unopened columns.** —
**ASSUMED** (M-2), with the exposure **COUNTED**.
Per 2,048-leaf tree, 256 draws with replacement give **240.7** distinct opened
leaves, **453.2** leaf digests revealed of which **212.5 are of columns that
are never opened**, **1,200.6** internal nodes, and the root: **1,654.8 of
4,095 nodes, 40.4 % of the tree**. The top pair is revealed with probability
`1 − 2^-255` (`ZK60_D8_D11_RESTATEMENT.md` §3.3, counts reproduced by the
independent check). At the model geometry (65,536 leaves) it is 4,154.7 of
131,071, **3.2 %**.
In the simulated world all of those are genuine hashes of the zero witness's
encoded columns, so the two worlds differ only in (i) the **opened** column
values, covered by item 5, and (ii) the **unopened** columns, which reach the
view only through salted leaf digests and the internal nodes above them.
**The assumption, stated at the strength actually needed:** not just that one
salted leaf hides its column, but that the **digest of a subtree of unopened
salted leaves** hides those columns. In the random-oracle model this is
immediate — each salted leaf is a fresh 64-byte query whose answer is uniform,
so everything above it is a function of uniform values, and a distinguisher
must guess a 256-bit salt (`≤ q·2^-256`). In the standard model it is a
PRF/extractor-style assumption on BLAKE3 keyed by the second half of its
input, **not implied by collision resistance**, and any theorem must name it.
The 32-byte salt is ample: the leak is bounded by its 256 bits of min-entropy
against a 256-bit digest.

**16. The Fiat–Shamir table and the Merkle/leaf table are one untagged 64-byte
BLAKE3 domain.** — **ASSUMED** (M-1); the code fact is **PROVED**.
`Transcript::absorb` hashes `state(32) ‖ len(8) ‖ label ‖ len(8) ‖ data`, so
`absorb_u64(b"log-cols", v)` is a **64-byte untagged input** — the same shape
as `hash_pair(l, r)` and `salt_leaf(d, s)` (`transcript.rs:44-52`;
`merkle.rs:14`; `pcs.rs:640`). Call sites: `private_seam.rs:253`,
`private_block/protocol.rs:43`, `private_attention/protocol.rs:38`.
**No attack follows** and the bound does not move (`2^-256` per candidate
point), but a privacy argument in the ROM must be composed with the soundness
reduction **over the same table**, and the composition must be written rather
than assumed. Domain separation would move every frozen digest, so it belongs
to the next statement version, not to a patch.
*Two nearby invariants worth asserting in code* (condition 28 of the D8/D11
check): a seam commitment's row count is never 5 or 8 — today it is always one
of `{6, 7, 9, 13, 21}` because `SeamSpec::new` forces a power-of-two length
(`private_seam.rs:66-72`, `:106-111`), and 8 rows would make `hash_column`'s
input 64 bytes while 5 would alias `ZkRng::refill`'s 40-byte input; and no
deployment-path commitment is reproducible from a seed. Neither invariant is
asserted today, and **the other commitments in a proof — `A` at 455 rows, `H`
at 384, `M` at 50 — are protected by no rule at all** (their `hash_column`
inputs are `8·rows` bytes, far from 64, but by arithmetic accident rather than
by a check).

#### D — adaptivity: the challenges depend on the roots, which depend on the witness

**17. The sequential-kernel lemma.** — **PROVED**, and independently
reviewed.
*Statement:* let the prover publish `m_0 … m_n`, let each challenge `r_j`
after `m_j` be any function of the public prefix, and let `m_j` depend only on
the witness, the prover's private randomness and `r_{<j}`. **If, for every
fixed challenge vector `ρ`, the joint law of `(m_0 … m_n)` given `ρ` is the
same for witnesses `w` and `w′`,** then for every challenge function the law
of the whole view is the same. *Proof:* induction on `j`; each kernel is a
ratio of two marginals of the per-`ρ` joint law
(`ZK60_MVP_JOINT_VIEW.md` §1.2, branch `zk60-mvp-fable`). *Review:* accepted
as valid for the stated causal message rules under the strengthened joint
hypothesis (`ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`). Exhaustive checks on
finite toy protocols in `tests/test_zk60_sequential_kernel.py` — **on branch
`zk60-mvp-fable` only, not in the main tree**.
**Two carve-outs that must travel with every use of it:** (i) a refusal event
that is a function of the public prefix inherits the same law, but a
**witness-dependent refusal breaks the conclusion** — item 19 shows there is
exactly one; (ii) the hypothesis is about **field** messages and says nothing
about the hash layer, because roots, salts and paths are not messages chosen
given `ρ` — they exist before the challenges do. Items 14–16 are the hash
layer's own argument and are not covered by this lemma.

**18. The lemma's joint hypothesis is not discharged.** — **OPEN**. This is
the other half of **U-3**, and it is the one that matters most.
*What U-3 is, precisely.* It is a **write-up obligation** with two components,
both stated at `ZK60_MVP_JOINT_VIEW.md:67` and `:73`: (a) *a generic-rank
argument for all non-refused `ρ`* — item 9 above; and (b) *the composition
write-up itself, independently reviewed* — that the per-`ρ` **joint** law of
**all** published field messages, across all five commitments and all 23
slots, is witness-independent, not merely that each channel's marginal is.
The earlier counterexample `(H(mask), mask ⊕ w)` — witness-independent
marginals, witness-*dependent* joint law — is why the hypothesis must be
joint. *(Note for readers grepping the repository: there is a **second,
unrelated U-3** in the seam and IO reviews, "nothing marks a seam endpoint
consumed exactly once" — `ZK60_OPUS_SEAM_REVIEW.md:647` — which is closed for
this API by ownership, `ZK60_OPUS_IO_REVIEW.md:477`. That is not this U-3.)*
**Does D18's option A change U-3? No.** U-3 is a statement about the field
messages given fixed challenges; it is indifferent to who fixed the roots.
What D18 changes is the *hash layer* (item 14) and the *game* (item 1), not
this. The one thing D18 does contribute is that under option A the simulator
is the honest prover, so the joint law in the ideal world is literally the
honest prover's law at witness `0` — which makes the hypothesis exactly "the
honest joint law does not depend on the witness", the cleanest possible form
of it, with no idealisation gap between simulator and prover.
*What would close it:* the write-up of item 9 plus a composition argument over
the channels, with an independent review. *Size:* the largest construction
item on this page. *Owner class:* construction.

#### E — LogUp, and what the integers add

**19. LogUp: one public identity, and exactly one witness-dependent
refusal.** — **PROVED** (source), with the probability **COUNTED**.
The individual helper sums are never published; the only sum claim on `H` is
the value-`0` claim on the row `u`, masked by a zero-sum pair
(`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` §4.1; the zero-sum rows are drawn
`N−1` fresh and the last set to the negated sum,
`private_block/protocol.rs:363-371`). That is the "2 `Fp`" of item 7, and the
negative control in which the nineteen sums *are* published discloses nineteen
dimensions — the control fires, so the mechanism is doing work.
**The collision event.** `inverses` wraps `batch_inverse2_checked` and returns
`"zero LogUp denominator; discard attempt"` (`private_block/protocol.rs:231-
234`). This is the **only** refusal in the prover whose occurrence depends on
the witness values, and it is precisely the event carve-out (i) of item 17
names. Its probability is `(lookups + table rows)/|Fp2|`; at the toy block the
three tables are 256 entries each and the lookup count is a few tens of
thousands, so the bound is about **2^-113** [my own count from
`|Fp2| ≈ 2^128`; not measured]. **Is `H`'s 2-dimensional identity really
public?** Yes: the gate checks that the disclosed functional's span equals the
LogUp sum claim's data-row weight span and that the published claim value is
`Fp2::ZERO` on every capture (item 7). *Rider:* the multiplicity planes
`m_u8`, `m_exp`, `m_act` are **witness-dependent data**, committed as `A` rows
and covered by the mask discipline like any other plane
(`protocol.rs:305-310`); they are not published.

**20. Integer-range side information.** — **OPEN** (small, and probably
benign).
*The worry.* The committed planes are small integers embedded in `Fp`, and the
proof range-proves them; the joint-view model treats them as free `Fp` values
and says so (`ZK60_NATIVE_JOINT_VIEW.md` §7.6).
*Why it should not be a leak.* The integer classes — int8, int16, the byte
limbs of `D` — are **public parameters of the statement**, identical in both
worlds, and the zero witness satisfies all of them. And if the disclosed
dimension over `Fp` is genuinely 0, the view is independent of the data *as an
`Fp`-vector*, which is a stronger statement than independence of its integer
structure. So the range facts cannot separate `w` from `0`.
*Why it is nevertheless OPEN.* That argument is only valid **inside the linear
model**. What is not covered is whether some published quantity is a
**nonlinear** function of the data that the linear model cannot see — item 21
— and whether the *conditional* law, once the two verifier identities are
imposed, remains uniform when the data is constrained to a small integer set.
A commitment to the all-zero plane does **not** automatically have the right
law once the verifier's two linear identities condition it, which is exactly
the sentence the D8/D11 draft had to withdraw (hole 7 of its check). *What
would close it:* one written paragraph plus the sampler of item 21's
neighbourhood. *Size:* small, if item 21 goes well. *Owner class:*
construction.

**21. The nonlinear link between the two channels.** — **OPEN**.
The verifier's relation `fin − c·g(ρ) = poly(terminals)` has degree up to
**4** in up to 61 table values. A linear model cannot see a nonlinear
functional of the joint view, and the joint-view lane says so in its own §7.4.
Item 13's strong terminal check does something important here — it verifies
the identity numerically on all 82 slot equations — but verifying that an
identity *holds* is not the same as showing that **no other nonlinear
functional of the view depends on the witness**. *What would close it:* either
an argument that every published value is a polynomial in a set of quantities
already shown uniform (which items 10 and 12 nearly give, slot by slot), or
the explicit joint conditional sampler **O1** that the D8/D11 draft named and
said does not exist (§3.2 item 1 of that draft). *Size:* medium; it is the
part of P10 that goes beyond running the existing tools. *Owner class:*
construction.

#### F — the randomness

**22. Every blinding source is drawn fresh from an OS-seeded stream, and the
streams used in one block proof are independent.** — **PROVED** (source, path
by path).
Checked in the source for the block profile:

| stream | seeded by | what it produces, in order |
|---|---|---|
| the **block** stream | `ZkRng::from_os(PROFILE)`, one per attempt (`private_block/protocol.rs:275`) | `A`'s mask rows (`:313-315`) → `A`'s pads then `A`'s 2,048 salts (`pcs.rs:673-674`) → the 23 CFS masks, their pads, `b_re/b_im/u_re/u_im`, and `M`'s salts (`zk.rs:434-462`) → `H`'s mask rows and the two zero-sum rows (`:362-371`) → `H`'s pads then `H`'s salts |
| the **input endpoint** stream | `ZkRng::from_os(DOMAIN)` inside `private_seam::prepare` (`private_seam.rs:196`) | that endpoint's 5 mask rows, then its pads, then its salts |
| the **output endpoint** stream | a second, separate `from_os` call, same line | the same for the other endpoint |

`from_os` reads 32 bytes from `/dev/urandom` and fails closed on an
unsupported host (`rng.rs:28-50`); there is **no seed reachable** on the
deployment path (`ZkOpts`-style seeded construction exists only in
`ZkRng::new`, documented "for public test fixtures ONLY", and its call sites
are all test modules).
**So: is every pad, mask and salt drawn independently?** In the idealisation,
**yes** — no blinding source is shared between two commitments, and no value
is derived deterministically from the witness or from the statement. I found
**no** shared or witness-derived blinding source in the block path. The one
thing to be precise about: all of `A`, `M` and `H` come from **one stream**
as **disjoint consecutive segments**, not from three streams. Disjoint
segments of a PRG output are computationally independent under M-3 and are
exactly what the joint-view §4 argument assumes; they are **not**
information-theoretically independent, and a theorem must say so. *Rider:*
`CommittedZk`'s `data`, `pads` and `salts` fields are `pub`
(`pcs.rs:551-564`), so the invariant "no new accessor exposes
`PreparedPlane`'s `CommittedZk`" is a code-review rule with nothing enforcing
it. Recommend the assertion of condition 28.

**23. The `fp()` reduction bias, counted for this profile.** — **COMPUTED**
(exact per-draw term PROVED; the draw counts are this drafter's own count),
and **accepted by ruling D9**.
Each `fp()` is a 128-bit draw reduced mod `p = 2^64 − 2^32 + 1`
(`rng.rs:72-77`). Because `2^128 mod p = p − 2^32`, all but `2^32` of the
`2^64` residues occur equally often, so the **total statistical distance of
one draw from uniform is exactly `2^-96`** (the `2^-64` in the source comment
is the per-outcome *relative* bias, a different quantity — D9's verification
note). Salts are `bytes32`, unreduced, and contribute nothing.

| profile | `fp()` draws per proof | total bias |
|---|---:|---|
| toy private block, `private-block-t32-poc/1` | **327,052** ≈ 2^18.3 | **≤ 2^-77.7** |
| 125M complete private block (`A` 5,681 / `H` 7,186 rows, width 16,384) | **≈ 9,257,800** ≈ 2^23.1 | **≤ 2^-72.9** |

The toy count, term by term [COUNTED by this drafter from the source]: `A`
mask rows 242 × 256 = 61,952; `A` pads 455 × 256 = 116,480; `H` mask rows
104 × 256 = 26,624 plus 510 for the two zero-sum rows; `H` pads 384 × 256 =
98,304; the 23 CFS masks 2 × Σ`L_s` = 2 × 583 = 1,166; `M` pads 46 × 256 =
11,776; `b` and `u` 4 × 1,024 = 4,096; the two endpoints 2 × (5 × 256 +
7 × 256) = 6,144. The 125M count uses the layout memo's row totals and the
same rules. **The 125M figure reproduces D9's "2^-72.9 at 2^23.1"
independently**, which is a small cross-check that the register's accepted
numbers are the right shape.

#### G — refusals, repetition, and the operational channels

**24. Refusals: the inventory, and what a verifier can learn from one.** —
**PROVED** (inventory read at the source), with a **ruling ask** attached.
The repaired profile's rule is *refusal instead of resampling*, and every
refusal is drawn from a **cloned** transcript prefix so it is a deterministic
function of the public prefix (`private_block/protocol.rs:174-176`). The
complete list at the block profile, with their dependence:

| refusal | depends on | witness-dependent? |
|---|---|---|
| zero group-member coefficient; dependent proximity coefficients (`:144`, `:149`) | challenges | no |
| zero CFS mask challenge `c_s` (`argument.rs:275`) | challenges | no |
| degenerate terminal mask challenge `e ∈ {0, 1}` (`:347`) | challenges | no |
| zero batching challenge (`:493`) | challenges | no |
| mask-schedule audit failures; group-count, claim-shape, table-shape, terminal-count, functional-count mismatches | the fixed schedule | no |
| expected endpoint root mismatch; endpoint geometry (`protocol.rs:248`, `:251`) | the caller's policy | no |
| witness shape (`:272`) | the witness's **shape**, not its values | no |
| **zero LogUp denominator** (`:231-234`) | witness **and** challenges | **yes** — probability ≈ 2^-113 (item 19) |
| the kernel's own refusal sites (an out-of-class input) | the witness | **yes**, but these fire in the *witness builder*, before any proof exists |

**A refusal produces no receipt**: `prove_inner` returns `Err` and nothing is
published on the deployment path. So the leak is not in the bytes. It is in
the **service**: a caller who retries, or an observer who sees a request
answered late or not at all, learns that a refusal happened, and for the
kernel's own refusal sites that means learning the input was out of class.
*This is an application-level channel, it is real, and it is not analysed
anywhere.* Recommended ruling: **out of scope for the first MVP, recorded**
(§5.3, ask R-3).

**25. Rejected-but-emitted receipts and retained captures.** — **OPEN**
(the facts are PROVED; the rule that would make them harmless is not
enforced).
`finish` has **no equality precheck**: a proof built against endpoints
committed to other values is fully constructed and emits 256 genuine
authentication paths per root before the verifier's polynomial identity
rejects it (`private_block/protocol.rs:255-257`, the same comment at
`zk_ffn_fresh_io.rs:256-257`). And `native_capture.rs::export` writes the
receipt, the policy and the JSON to disk for every accepted capture
(`:267-281`). Both are **published path sets** — history items H8 and H9,
added to the enumeration only after the independent check of 2026-09-19.
**Why this still matters under D18.** A *second* published path set under the
same root is the fatal case: two openings of one endpoint commitment recover
all 512 hidden data words, reproduced natively
(`zkp-core/tests/endpoint_reuse.rs`; `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`),
and a verifier **cannot check from the bytes** that it has not happened. Today
each capture uses fresh roots, so one path set per root still holds — but that
is an operational fact, not an enforced one. **What would close it:** a stated
rule ("a rejected receipt is never transmitted; a capture counts as
publishing") plus, where possible, a code assertion; and D12 item 1 extended
to say so. *Size:* small. *Owner class:* engineering plus a one-line ruling.

**26. Many proofs of the same or related hidden inputs.** — **COMPUTED ON
CAPTURES**, and narrow.
Fresh OS entropy per proof and per endpoint (item 22) means two proofs of the
same hidden input share **no** root, no salt, no pad and no mask. Nothing in
the receipt is derived deterministically from the witness. The only measured
evidence for the joint law of two proofs is round 23: **zero disclosed base
dimensions over 88,064 shared data unknowns**, four with every private
commitment added (exactly the two public `H` LogUp identities), and 256 in the
single-mask ablation control (`ZK60_ROUND23.md:58-65`) — **at fixed
coefficients, on two captures, field channels only**, explicitly excluding the
CFS, pad, encoded-column and Merkle channels and adaptive composition
(`:67-71`). **It does not cover an arbitrary number of proofs, and it does not
cover the hash layer.** *Rider:* history item H7 — a different commitment to
the same plane opened by another proof — is a *data-channel* correlation, not
hash-layer history; the two trees share no oracle point except by `2^-256`
accident.

**27. Capture bundles contain the verifier's view and nothing beyond it.** —
**PROVED** (inspected at key level, no values read out).
The schema-3 JSON's top-level keys are the profile and coverage strings, the
transcript domain, the source commit, the privacy mode, the field modulus and
extension non-residue, the receipt's sha256 and length, the 112-byte expected
policy and its digest, the public-statement / layout / schedule digests, the
opening order, the three LogUp challenges, the header checkpoint, the 23 slot
records, the mask record and the four role records. A role record carries the
commitment root and row count, the transcript checkpoints, the claims, the
groups with their lambdas and vectors, the proximity rhos and vector, the 256
columns each with `index`, `values`, `salt` and `path`, `q_pad`, the row
roles, and the public linear constraints. **Every one of those is a value the
verifier already has.** There is no plane, no pad, no mask coefficient and no
RNG state, which is what §9a answer 4 records and what I confirmed at key
level. *Rider:* the bundle also writes the `.receipt` bytes, which is item 25.

#### H — the sum

**28. A whole-view bound.** — **OPEN**. None exists.
Nothing in the repository composes items 4–27 into a single advantage
expression. When it is written it will be a **computational,
programmable-random-oracle statement** — though, thanks to item 14, in the
*non*-programming direction for the first MVP — with an assumption list of at
least five entries: M-1 (one untagged table), M-2 (salted-leaf and
salted-subtree hiding), M-3 (PRG on `ZkRng`), M-4 (the `fp()` term, ruled), and
the LogUp collision event. The D8/D11 disposition says the same thing in its
own words (§4). *Size:* it is the last item, not the first; it should be
written after items 9, 18 and 21 land, because until then its field-layer term
would have to read "whatever the discharge of U-3 contributes" — which is
exactly the defect that made the refused draft's advantage expression not a
bound (hole 6).

### 3.3 The circularity check, step by step

The refused D8/D11 draft failed because its central reduction assumed its own
conclusion. The discipline that would have caught it is to ask, of every step:
**what does this step assume that a later step concludes?** Here is that
question answered for each step of §3.2. An entry in the last column is a
red flag; there is one, and it is declared rather than hidden.

| step | assumes | which step concludes it | circular? |
|---|---|---|---|
| 1 game | D18 and the ownership code facts | neither is concluded later | no |
| 2 simulator | that the zero witness is in class and the prover accepts it | nothing later; it is the OPEN test U-4 | no |
| 3 reduction | step 2; and that the statement holds no witness-dependent value but the roots | checked directly against the transcript order, not concluded later | no |
| 4 pair discipline | nothing | — | no |
| 5 pads | H-pad (distinct opened ≤ `Q`), checked on the capture | — | no |
| 6 disclosed 0 | steps 4, 5 (as hypotheses H-pair, H-prox, H-pad), all three checked on the capture | — | no |
| 7 `H`'s identity | step 6's machinery | — | no |
| 8 joint = sum | disjoint randomness | step 22 establishes it in the source | no — the order is 22 then 8, and this page states it that way |
| 9 generic rank | that the minors are not identically zero | **step 6 is the evidence, at four points** | **not circular, but weak**: four points cannot establish a non-vanishing over the whole space. This is the honest form of the gap, and it must never be written as though step 6 discharged step 9 |
| 10 mask covers `C_s` | nothing | — | no |
| 11 discipline | nothing | — | no |
| 12 derived mask eval | `c_s ≠ 0`, refused in code | step 11 | no |
| 13 strong check | that the Python port equals the Rust closures | **nothing** — it is a REVIEWED OBLIGATION and stays one | no, but the obligation is real |
| 14 no programming | step 1 (the game) and step 2 (the simulator is the honest prover) | — | no |
| 15 hiding | M-2 | nothing concludes M-2; it is an assumption | no |
| 16 one table | M-1 | — | no |
| 17 lemma | its joint hypothesis | step 18, which is OPEN | no — the lemma is stated *conditionally* and this page never uses it unconditionally |
| 18 joint hypothesis | items 6, 7, 8, 10 as evidence at four challenge vectors | — | same shape as step 9: evidence, not discharge |
| 19 LogUp | nothing | — | no |
| 20 integers | that the linear model is complete | **step 21, which is OPEN** | no, but step 20 cannot be closed before step 21 |
| 21 nonlinear | nothing | — | no |
| 22 randomness | M-3 for "independent" | — | no |
| 23 bias | M-4, an exact computation | — | no |
| 24 refusals | that the service does not leak | a ruling, not a step | no |
| 25 emitted/retained | that one path set per root is maintained | **nothing enforces it** | no, but it is an unenforced premise and must be written as one |
| 26 many proofs | steps 22 and 8 | — | no |
| 27 captures | nothing | — | no |
| 28 bound | steps 9, 18, 21 | — | no; it is correctly last |

**The one pattern to watch.** Steps 9, 18 and 20 all have the form "the
evidence for this is a computation at four challenge vectors". That is not
circular, but it is the place where an over-claim would be easiest to make and
hardest to notice. The rule this page proposes: **no sentence may use a
COMPUTED ON CAPTURES result as the premise of a universally quantified
claim.** Where a universal claim is needed, it is item 9 or item 18, and both
are OPEN.

### 3.4 The tally

| label | count | steps |
|---|---:|---|
| **PROVED** | 11 | 3, 4, 5, 11, 12, 14, 17, 19, 22, 24, 27 |
| **COMPUTED ON CAPTURES** | 7 | 6, 7, 8, 10, 13, 23, 26 |
| **ASSUMED** | 3 | 1, 15, 16 |
| **OPEN** | 7 | 2, 9, 18, 20, 21, 25, 28 |

Item 23 is counted as COMPUTED because the draw counts are a count rather than
a theorem, although its per-draw term is exact and ruled.

## 4. The gate P10, defined precisely enough to implement

The MVP plan calls P10 *"the block-scope privacy gate — on captured real
receipts, a zero-witness preimage with the same free dimension as the real
witness **on every channel**, plus the zero-witness acceptance test"*
(`ZK60_MVP_COMPLETION_PLAN.md:1171`, quoting
`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`, which quotes round 1 §6 item 6).
That sentence is a gate only once "every channel" is enumerated and once the
channels that **cannot** have a constructed preimage are required to say so
out loud. This section does both.

### 4.1 Inputs

| input | where |
|---|---|
| capture bundles | `results/zk60_native_captures_20260919/captures/` — four bundles, each `<sha256>.{receipt,expected,json}`, two `private-block-t32-poc/1` and two `private-attention-t32-poc/1`, cross-checked against `validation.json` by sha256 and byte count, all four carrying `canonical_capture_reproduced` and `native_reverified` true and `privacy_review_complete` false |
| the tool | `scripts/zk60_native_joint_view.py` on branch `zk60-native-jointview` (stages 1–7), with `scripts/zk60_native_jv_replay.py` and `scripts/zk60_native_terminal_polys.py` |
| the record it writes | `results/zk60_native_joint_view/joint_view.json` plus the marker `joint_view.done` |
| source pins | eight Rust files pinned by sha256 **and** git blob id, re-checked at run time; a changed file is a hard error. **`zkp-core/src/mle.rs` is one of them and is modified in the working tree today**, so a re-pin (after re-reading, not blindly) is a precondition for running P10 |
| what it must not read | no witness plane, no pad, no mask coefficient, no RNG state — none of which the bundles contain (chain item 27) |

### 4.2 Channel by channel: CONSTRUCTED or ARGUED

**The rule this table exists to impose:** for each channel the gate must
either **construct** a zero-witness preimage — actually compute the pads,
masks and coefficients that reproduce the captured view under the all-zero
witness, and check that the affine fibre has the same free dimension as at the
real witness — or **declare in its own output record** that the channel is
covered by argument and name the assumption. *Silence is the failure mode
this table is designed to prevent:* today's tools exclude the hash layer and
say so in prose, and the record does not carry the exclusion in a field
anybody must read.

| # | channel (from §2.1) | status | what the gate must do |
|---|---|---|---|
| 1 | opening-group vectors, all 46 | **CONSTRUCTED** | solve for the reserved pair values and mask rows reproducing each captured `v_g` at the zero witness; assert the fibre dimension equals the real one |
| 2 | proximity vectors, all 5 | **CONSTRUCTED** | same, through the proximity pair |
| 3 | claimed evaluations | **CONSTRUCTED** | each claim's value at the zero witness, through its own pair |
| 4 | opened column values, 5 × 256 | **CONSTRUCTED** | solve for the pads; the exact Gaussian rank check (256 of 256) is the existence certificate |
| 5 | column indices | **public** | the stage-1 replay derives them from the public prefix; record "derived, not sampled" |
| 6 | masked sumcheck rounds, 41 slots | **CONSTRUCTED** | sample uniformly on `C_s`; `rank R_s = dim C_s` is the existence certificate |
| 7 | masked scalars and `Γ` | **CONSTRUCTED** | with the slot's mask |
| 8 | published terminals | **CONSTRUCTED** | as claim values with their own pairs |
| 9 | mask evaluations, 41 | **DERIVED** | *not* sampled: `mask_eval_s := (fin_s − poly_s(terminals_s))·c_s^{-1}`. The record must label these `derived`, with the per-slot identity asserted (chain item 12) |
| 10 | the `M` opening's `q` and proximity vector | **CONSTRUCTED** | `b` masks every coefficient but `q[0] + q[512]`; that one is the public θ-combination |
| 11 | the LogUp sum claim on `H` | **CONSTRUCTED** | its published value is `Fp2::ZERO`, which the zero witness gives |
| 12 | **the three Merkle roots** | **ARGUED** | record: *"generated by the simulator itself under D18 option A; no oracle point is programmed (chain item 14); indistinguishability rests on M-2"* |
| 13 | **the 256 leaf salts per opening** | **ARGUED** | record: *"fresh uniform in both worlds; equality of laws rests on M-3, the PRG assumption on `ZkRng`, in the direction that published later outputs do not reveal earlier secret outputs"* |
| 14 | **the 11- and 12-level authentication paths, including ~212.5 unopened leaf digests and ~1,200 internal nodes per tree** | **ARGUED** | record: *"genuine hashes of the simulator's own zero-witness columns; hiding of the unopened columns and of the subtrees above them rests on M-2"*, with the counts |
| 15 | receipt byte encoding and length | **ARGUED** | record: *"witness-independent shape facts; 2,816,472 B at this profile for every witness"* |
| 16 | the integer-range facts the statement implies | **ARGUED, and weakly** | record chain item 20 as an **open** channel, not a covered one |
| 17 | any nonlinear functional of the joint view | **NOT COVERED** | record chain item 21 as **open**. The gate must not report "every channel covered" while this is open |

**Machine-readable form.** The record gains one array, `channels`, with one
entry per row above: `{"channel": …, "status": "constructed" | "derived" |
"argued" | "open", "assumption": "M-2" | null, "fibre_dim_real": n,
"fibre_dim_zero": n}`. A gate run in which any `constructed` channel has
`fibre_dim_zero != fibre_dim_real`, or in which an `open` channel is absent
from the array, is a **fail**.

### 4.3 Pass criteria

All of the following, on **every** capture:

1. stage 1 replays every transcript state and challenge from public data, 0
   failures, and the manifest cross-check passes;
2. disclosed dimensions: `A` 0, `H` 2, Input 0, Output 0, `M` 2 (the θ
   combination), **joint 4 = sum of parts**, and `k0 = 0` on every role;
3. `H`'s two dimensions are *shown* to be the public LogUp identity, with
   published value `Fp2::ZERO`;
4. `rank R_s = dim C_s` on every slot, and every published `M` functional
   inside the round span;
5. all **82** strong per-slot terminal equations hold, none `not_checkable`;
6. every `constructed` channel has an exhibited preimage with equal fibre
   dimension;
7. every `argued` and `open` channel is present in the `channels` array with
   its assumption named;
8. every negative control of §4.4 fires;
9. `privacy_property_established` stays **false** in the record — the gate
   passing is evidence for a privacy case, not the case.

**And one thing the present tools cannot yet do, which P10 should:**
*exhibit* rather than *argue from linearity*. The security owner's answer 4(a)
already asked Codex for the input: the **unmasked honest round messages of one
slot on a synthetic fixture**, labelled a test fixture. With that, the
zero-witness preimage on the CFS channel can be displayed instead of inferred
from `rank R_s = dim C_s`. Recommend it be treated as part of P10, not as an
optional extra.

### 4.4 The negative controls, and the rule about them

Controls that must fire (each perturbs one thing and is undone afterwards):

| control | expected | status today |
|---|---|---|
| **one pad fewer than the distinct opened columns** | discloses (3 in the small model) | fires |
| **two claims sharing one reserved mask pair** | discloses (8) | fires |
| **the same commitment opened twice** | discloses (10) | fires |
| **an unmasked scalar published** — e.g. the nineteen LogUp helper sums in the clear | discloses (1 in the small model; 19 at the attention schedule) | fires |
| **a blinding source shared across two commitments, with the two planes NOT aliased** | discloses (**8**, while every per-commitment figure stays **0**) | fires **only in a genuine cross-commitment joint rank**; the per-role acceptance the first form-E draft scheduled would have returned all zeros on it |
| an altered capture | the stage-1 replay fails | fires on all four |
| one slot's round coefficient / `mask_eval` / `terminal_polynomial` perturbed | the per-slot identity fires | fires 4/4 |
| **one published terminal perturbed** | the *strong* check fires at that slot and only there | fires 23/23 and 18/18 since tonight; the weak identity was blind to it |
| a slot's table push order altered | that slot reported `not_checkable`, run not `ok` | fires |
| a pinned Rust source changed by one byte | `SourcePinError` naming the file | fires |

**The rule, learned the hard way today.** *A control that cannot fire at an
honest witness is not a control.* The form-E independent check ran the draft's
own acceptance experiment and found **three** of its controls measure 0 on an
honest instance — a shared blinding source with the two planes *aliased*
(case 3a), a zero masking coefficient `c = 0` (case 5), and a slot that is too
short (case 14) — each for a good reason: when the two planes are equal there
is nothing for the shared source to fail to hide, and on the honest witness
the seam's rounds carry no data. Run as written, that experiment would have
**stopped a construction with nothing wrong with it**
(`ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md` §1.6). So P10 adds one step before it
runs: **for each control, first verify that it discloses more than zero on an
honest instance of the model it is run in.** A control that does not is
demoted from "stop" to "recorded as inapplicable at this shape", with the
reason.

**One control this gate should add and does not have.** A **real-receipt**
version of "the same commitment opened twice". Today it exists only in the
small synthetic model. The security owner already passed the request to Codex
(answer 4(b)): a capture of one commitment deliberately opened twice, labelled
a test fixture. Given that two openings recover all 512 hidden words at this
geometry — the one *proved* leak in the whole system
(`zkp-core/tests/endpoint_reuse.rs`) — having the control on a real receipt is
worth the fixture.

### 4.5 "The component's zero-witness acceptance test" — what it is, and the fact that it does not exist

Round 1 §5 defines it exactly: *"Add one Rust integration test … build the
zero witness through the existing oracle on an all-zero input,
`prepare_endpoints` on zero planes, `prepare`/`finish`, and `verify_bytes`
under the same `WeightStatement::Public(root)` used by the honest fixture,
then the same under `FreshPrivate`. This pins the simulator's existence
condition and doubles as the acceptance gate every future private component
must pass before its channels are analysed"*
(`ZK60_MVP_SECURITY_DECISION.md` §5). It is obligation **U-4**, requested from
Codex on 2026-09-15 and listed as *"still requested"* in the round-2 ledger.

**It does not exist.** I searched `hashline/tests/*.rs`,
`hashline/src/**/tests.rs` and `zkp-core/tests/` for a zero-witness proof
test; there is none. `hashline/tests/zk60_private_block.rs` holds four tests
(honest frame, every region load-bearing, endpoints fixed to other values
refused, two receipts share no root) and none of them is this one.

**It is the gate's first item, not its last**, because every other channel
analysis is conditional on it: if the honest prover cannot produce an
accepting receipt at the zero witness, the simulator of chain item 2 does not
exist and the whole reduction of chain item 3 is vacuous. Recommended shape
for the block profile: the all-zero input, the same public fixture, both
endpoints prepared on zero planes, prove, verify in a fresh process, assert
acceptance, and assert the receipt's length equals the honest fixture's
2,816,472 bytes.

## 5. The acceptance ladder

Three rungs. For each: the exact words the security owner could honestly use,
and what has to be true first.

### 5.1 Rung (i) — today

> **"The custom line has one complete private transformer block at a toy
> shape. It is accepted as an experimental component. No privacy property is
> established. Ruling D18 means the first MVP's artifacts are in the standard
> privacy game — the prover seals its own input and output — and that changes
> which obligations bind, not what has been shown."**

That is exactly what is true. The disposition already says the first two
sentences; the third is what today adds. Nothing about D8 or D11 has been
closed; they bind the configuration of the next milestone.

**What may be said alongside it, with the labels attached:** on a linear model
of the complete verifier view at the real challenges of four real receipts,
nothing about the hidden planes is determined beyond public identities; every
negative control fires; an altered capture breaks the transcript replay; and
as of tonight the verifier's own masked final equation is recomputed and holds
on all 82 slot instances. Each of those is *evidence at four challenge
vectors*, and the sentence must say so.

### 5.2 Rung (ii) — after P10 and a written simulator

> **"Privacy is accepted for the toy private block profile
> `hashline-zk-mr1/private-block-t32-poc/1`, in the model of §1.3, with these
> named residuals."**

**What must exist first**, in dependency order:

1. **U-4**, the zero-witness acceptance test (chain item 2 / §4.5). Without
   it the simulator does not demonstrably exist. *Engineering, half a day,
   can start today.*
2. **P10** as defined in §4, green on all four captures, with the `channels`
   array present and the three demoted controls handled by the honest-instance
   rule. *Engineering to run, security-owner reading. Can start once the
   worktree is free and `mle.rs` is re-pinned.*
3. **U-3 written**: the generic-rank argument (chain item 9) and the joint
   composition write-up (chain item 18), independently reviewed. *Construction,
   the largest item. Can start today; it is paper.*
4. **The nonlinear cross-channel argument** (chain item 21), or an explicit
   statement that the acceptance is conditional on it. *Construction.*
5. **A written simulator**: chain items 1, 2, 3, 14 assembled into one
   document with the assumption list M-1…M-6 and a single advantage
   expression (chain item 28). *Construction, security owner.*
6. **The residual terms ruled**: D9 is already accepted; the PRG assumption on
   the keyed hash stream, the LogUp collision event and the side-channel scope
   must be **in the statement**, not in a memo's footnote. *§5.3.*

**The residuals the sentence would have to name**, verbatim: the random-oracle
model for BLAKE3 over **one untagged table** shared with the Merkle and leaf
hashes (M-1); salted-leaf and salted-subtree hiding (M-2); the PRG assumption
on `ZkRng` (M-3); the `fp()` reduction bias, at most **2^-77.7** at this
profile (M-4, ruled by D9); the LogUp collision event at about **2^-113**;
application-level side information (M-6); and **side channels out of scope**
(M-5). Plus, if item 4 above is not done: "conditional on no nonlinear
functional of the joint view depending on the witness".

**What rung (ii) would still not be.** It is the *toy* profile — 32 tokens,
width 16, two heads, feed-forward width 16, weights public. It is one proof,
not a run. It says nothing about 125M or 8B, about hidden weights (P3), about
soundness, or about the sealed-in-advance configuration.

### 5.3 Rung (iii) — at the 125M shape

> **"Privacy is accepted for the 125M complete private block profile, in the
> same model, with these residuals — and here is what was re-established at
> the new shape."**

**Everything in §4 must be re-run on the grown layout.** The tools' verdicts
at the toy shape say nothing about the grown one, and the project already
applies that standard elsewhere: D17/R-3 makes the analogous gate a hard gate
on the endpoints path. The 125M layout memo lists it as open obligation 3.

**What specifically changes, and each one touches hiding:**

| change at 125M | why it touches hiding | source |
|---|---|---|
| **`log_cols` 8 → 14, `inv_rate` 8 → 4** | new tree depth (16 levels, 65,536 leaves), new revealed-node counts (4,154.7 of 131,071, **3.2 %** instead of 40.4 %), and a different per-opening soundness term. `Q` stays 256 while rows go to 16,384 wide | layout §2.2, decision 1 |
| **five of nine domains become padded** | at the toy shape every domain is exactly a power of two, so **no relation is ever evaluated off-support**. At 125M they are, for the first time | layout §1.3 T-4 |
| **a public support indicator on padded domains** | a new *public* table per padded domain and degree 4 → 5 on two slots. A public indicator is the right choice for hiding (the pad holds zeros and nothing is derived per constraint), but it is a new published object that the joint view has never modelled | layout decision 3 |
| **`d` 768 → 1,024 and 12 heads → 16 slots** padded | padding positions are public zeros in a hidden plane; the mask discipline must cover them exactly as it covers data | layout decision 4 |
| **re-tiled endpoints per D17** | the whole hidden plane must be bound at every width through the batched multi-block seam; `T·d = 393,216` words is three `d`-blocks and is **not** a power of two, so `SeamSpec::new` refuses it outright today | D17; layout §6 |
| **`outer.trailing_zeros()` at `d = 768`** | trap T-2: the slot would draw an 8-variable point over a 1,024-column output and bind **a 256-column slice**. Same shape of hole as D17's. It is a soundness hole, but an output-binding hole is also a privacy question the moment the unbound part is a hidden plane | layout §1.3 T-2 |
| **`N` means two things** | trap T-1: at `N = 16,384` the "is this value in the table" test silently changes meaning and an out-of-range lookup lands in bucket 300 instead of bucket 0, leaving the LogUp identity as the only catch. A one-line fix that must land **before** any row-width change | layout §1.3 T-1 |
| **grouped-query attention, 12 query heads over 4 KV heads** | a genuinely new relation between two claim points; new claim sites, hence new reserved pairs, hence a new `audit_claims` instance to check | layout §1.3 T-3 |
| **`D`'s range pin and the isqrt witnesses** | D16 binds: byte-limb range pins sized to the new maximum, at most four limbs, exact remainder window, and the alias tamper tests must reject at the widened profile | D16 |

**New negative controls the grown gate needs**, over and above §4.4: a
control on the **support indicator** (a padded position carrying a nonzero
witness value must disclose); a control on the **re-tiled endpoint seam** (a
sealed plane honest on the first block and arbitrary elsewhere must be
rejected — this is exactly the attack an independent check built and the
present code does not reject); and a control on the **grouped-query map** (a
query head reading the wrong KV group must disclose or be refused).

### 5.4 The rulings this needs from the project owner

Each in one paragraph of plain words, with a recommendation, in the form D3,
D4, D7 and D9 took.

**Ask R-1 — the random-oracle model for BLAKE3, over one shared table.**
*In plain words.* Almost every proof system of this kind is proved secure by
pretending the hash function is a perfect random box. It is a standard and
universally accepted way to argue, but it is a pretence, and the project has
never written down that it is relying on it. There is a wrinkle here: the same
hash is used for three jobs — deriving the challenges, hashing pairs of tree
nodes, and hashing the salted leaves — and all three feed it **64 untagged
bytes**, so they are literally the same box rather than three separate ones.
No attack follows and no number moves, but any future proof must be written
against one box, not three, and the soundness argument must be composed over
the same box. Separating them would change every frozen digest in the
repository, so it belongs to the next statement version.
*Recommendation:* **accept the random-oracle model, and accept the single
untagged domain as a recorded deviation**, with domain separation scheduled
for the next statement version rather than patched in.

**Ask R-2 — the privacy target, in bits, and per what.**
*In plain words.* The soundness side has a number (about 106 bits per opening,
about 94 for a whole 8B proof, about 97 for the zkVM line). The privacy side
has none. Most of the privacy statement will not be a bit count at all — it
will be "as hard as breaking BLAKE3" — but the part that *is* a number, the
statistical part, needs a target so that a future change (a different field, a
different rate) can be judged against it. Today that part is at most about
2^-77.7 at the toy shape and 2^-72.9 at 125M, dominated by a tiny unevenness
in the prover's random draws that you already accepted as D9.
*Recommendation:* **set one whole-proof statistical target of 100 bits**, to
be met by the sum of the statistical terms, and record that the computational
terms are governed by R-1 and R-3 rather than by a bit count. Ask for it to be
ruled together with the soundness target D15 leaves open, so the two are never
quoted at different standards.

**Ask R-3 — side channels out of scope for the first MVP.**
*In plain words.* The receipt hides the input. The **service around it** may
not: how long a proof took, how much memory it used, and — the sharpest one —
whether a proof was **refused**. There is exactly one place inside the proof
where a refusal depends on the secret, and it is about as likely as guessing a
128-bit number. But the *witness builder* refuses an out-of-class input before
any proof starts, so a caller who retries learns something about their own
input, and an observer who watches the service learns that a refusal happened.
None of this is analysed anywhere.
*Recommendation:* **rule side channels out of scope for the first MVP and
record it**, with two conditions: that the privacy statement says so in its
own words, and that a deployment design item is opened now for the retry and
timing behaviour, because it is cheap to design in and expensive to retrofit.

**Ask R-4 — the PRG assumption on the prover's randomness.**
*In plain words.* The prover's masks, pads and salts are not true randomness;
they are the output of a keyed hash stream seeded from the operating system.
That is normal and it is the right engineering choice. But 256 of the salts
are **published in the clear**, and they come out of the same stream that a
moment earlier produced the secret pads. So the privacy statement depends on
the stream being a good pseudorandom generator in a specific direction: later
published output must not reveal earlier secret output.
*Recommendation:* **accept it as a named assumption** (M-3) and add the two
source comments the D8/D11 check asked for, so the next reader of `rng.rs`
sees both the assumption and D9's two numbers.

**Ask R-5 — the rule about published openings, in one line.**
*In plain words.* Opening the same sealed envelope twice gives the whole
contents away — that is proved, not suspected. The code makes a second
*accepted* proof impossible, but two other things put a full opening into the
world: a receipt that fails verification is still fully built and emitted, and
every capture the project keeps for evidence writes a receipt to disk. Neither
is a bug today, because each capture uses fresh seals. But nothing enforces
it, and a verifier cannot check it from the bytes.
*Recommendation:* **rule that a rejected receipt is never transmitted and
that writing a capture counts as publishing**, and extend D12 item 1 to say
so. It costs nothing today and it is the kind of rule that is impossible to
retrofit after an incident.

## 6. What must not be claimed, even after the gate passes

A short list the status pages can quote verbatim.

1. **Not "D8 and D11 are closed".** They stand as written. D18 says which
   product configuration they bind — the one where somebody other than the
   prover seals an input in advance — and Victor expects that configuration to
   be the product's end state. Nothing on this page touches them.
2. **Not "the proof is zero knowledge".** Even at rung (ii) the statement is
   "privacy accepted for this profile, in this model, with these residuals".
   The residuals include a random-oracle idealisation and two hash
   assumptions; those never go away.
3. **Not "proved" for anything computed on captures.** Four captured challenge
   vectors are two per profile. The project's own reviewer wrote the sentence:
   *"Four actual captured vectors do not establish its universal premise."*
   Until chain items 9 and 18 are written, every such number is evidence.
4. **Not "every channel is covered".** The hash layer is covered by
   **assumption**, not by construction, and §4.2 requires the tool to say so
   in its record.
5. **Not "the tools showed the block is private".** They are static and
   linear. The leak-checking runs on the block source were a check of a
   linear-algebra model of a schedule; the adversarial code review was a
   **soundness** review. Neither is a privacy result.
6. **Not a claim about 125M or 8B.** Rung (ii) is 32 tokens at width 16.
   Everything in §5.3 has to be redone, and two of the traps there
   (`N`'s double meaning, `outer.trailing_zeros()` at `d = 768`) are live
   defects at the grown shape.
7. **Not a claim about hidden weights.** P1 has no `W` commitment; P3 is a
   different statement.
8. **Not a soundness claim.** Nothing here is about whether a false proof can
   be forged. On that side the whole 8B proof is about 94 bits, not 106 and
   not 128 (D15).
9. **Not "the receipt reveals nothing".** It reveals the model, the shapes,
   the calibration, the caller's context digest, the declared integer classes
   and the fact that a computation of that shape happened. Application-level
   side information (H6) bounds what any commitment can buy.
10. **Not "a private run can be chained".** Separately finished private proofs
    **cannot** be chained through a commitment root — the upstream receipt
    already opens it. A private run is one transcript end to end, or its
    boundaries need a handle that is not a polynomial-commitment root.
11. **Not "the terminal-polynomial port is verified".** Its equality with the
    Rust closures is established by reading, and the security owner has not
    re-read it. It is a reviewed obligation and stays one.

## 7. Open items, ranked; and what I did not check

### 7.1 Ranked by what blocks rung (ii)

| rank | item | chain | owner class | size | can start today? |
|---:|---|---|---|---|---|
| **1** | **U-4, the zero-witness acceptance test.** Without it the simulator of chain item 2 is not known to exist, and every other step is conditional on a vacuous premise | 2 | **engineering** | half a day, one Rust integration test | **yes** — it touches no frozen bytes and needs no design decision |
| **2** | **U-3(a), the generic-rank argument.** Lift "disclosed dimension 0 at these four challenge vectors" to "at all but a negligible fraction". §3.2 item 9 sketches the shape: write the minors, bound their degrees, show they are not identically zero, reconcile with the refusal set, compose over five commitments and 23 slots | 9 | **construction** | days; paper | **yes** |
| **3** | **U-3(b), the joint composition write-up**, independently reviewed: the per-`ρ` **joint** law of all published field messages, not the per-channel marginals | 18 | **construction** | days; paper; it is the hypothesis of the one lemma that lifts everything to real BLAKE3 | **yes** |
| 4 | **P10 run as §4 defines it**, with the `channels` array and the honest-instance rule for controls | §4 | engineering to run, security owner to read | a day, once the worktree is free and `mle.rs` is re-pinned | nearly — blocked on the worktree and the pin |
| 5 | **The nonlinear cross-channel argument** (or an explicit conditional acceptance) | 21 | construction | medium | yes |
| 6 | **The written simulator and the single advantage expression**, with M-1…M-6 named | 28 | construction, security owner | after 2, 3, 5 | no — correctly last |
| 7 | **The five rulings** R-1…R-5 of §5.3 | — | **ruling** | one page each | yes |
| 8 | **The published-opening rule** (rejected receipts, retained captures) written into D12 and, where possible, asserted | 25 | engineering + ruling | small | yes |
| 9 | **The integer-range paragraph** | 20 | construction | small, after 5 | after 5 |
| 10 | **A real-receipt "opened twice" control** and the **unmasked-rounds fixture** for exhibiting the CFS preimage | §4.4 | engineering (Codex's call) | small | yes |
| 11 | **Code invariants**: seam row count never 5 or 8; no deployment commitment reproducible from a seed; no new accessor exposing `PreparedPlane`'s `CommittedZk`; the two `rng.rs` / `transcript.rs` comments carrying both of D9's numbers | 16, 22 | engineering | small | yes |

**The three that matter most** are ranks 1, 2 and 3. Rank 1 is half a day and
unblocks the logical form of the whole argument. Ranks 2 and 3 are the two
halves of U-3, they are paper, they can both start today, and **every
COMPUTED ON CAPTURES label on this page is conditional on them**.

### 7.2 What I did not check

* **I ran nothing.** No build, no test, no prover, no verifier, no benchmark.
  Every figure is read from a source file, from a committed record, or counted
  by hand and labelled.
* **I did not re-run the joint-view gate**, the terminal-polynomial port or
  any tool. The numbers in chain items 6, 7, 8, 10, 13 and 26 are taken from
  `ZK60_NATIVE_JOINT_VIEW.md` (branch `zk60-native-jointview`),
  `ZK60_ROUND23.md` and `ZK60_PRIVATE_BLOCK_FORM_E_CHECK.md`. I read the
  capture bundles only at **key level**, to confirm chain item 27; I read no
  value out of them.
* **I did not re-derive the hash-layer counts** (240.7 distinct leaves, 212.5
  unopened, 1,654.8 of 4,095 nodes, 1 − 2^-255 for the top pair). They are
  the D8/D11 draft's, reproduced exactly by its independent check.
* **I did not read the Python port line by line against the Rust closures.**
  Chain item 13's REVIEWED OBLIGATION is unchanged by this page.
* **I did not read the untracked or modified files** in the working tree
  (Codex is live there), which includes `ZK60_SEALED_HANDLE_SCOPING_CHECK.md`,
  `ZK60_HARDENING_INTEGRATION_REVIEW.md`, `ZK60_CEREMONY_CHECK_REVIEW.md`,
  the modified `MVP_STATUS.md`, `TASK_BOARD.md` and `zkp-core/src/mle.rs`. If
  any of them bears on hiding, this page does not reflect it.
* **I did not verify the attention profile's numbers independently** where
  they differ from the block's; where both are quoted I have said which is
  which.
* **I did not check completeness** — that an honest witness always exists
  within the declared ranges — which the construction disposition also records
  as unchecked, and which chain item 2 needs for the zero witness
  specifically.
* **I did not analyse the zkVM line.** D7's salted-SHA profile is a different
  statement format and is referenced here only for contrast.
* **I did not model the GPU path.** `commit_zk_owned_with` draws the pads and
  salts *before* offering the encode to a backend, "so the bytes do not depend
  on who encoded" (`pcs.rs:667-669`), which is the right design for this
  argument, but I did not check the device path's column gather for anything
  privacy-relevant.
* **I could not find** any Schwartz–Zippel or generic-rank argument for the
  challenge space anywhere in the repository, on any branch I searched. If one
  exists, chain item 9's status changes and this page is wrong about the
  highest-value open item.

*(draft complete)*
