# D8/D11 restated: the caller-fixed endpoint-root obligation, the hash layer, and the closures that could discharge it

**DRAFT for the security owner's review — NOT ACCEPTED, and NOT a closure of
D8/D11. Delegated Opus draft, 2026-09-19. Paper only.**

| | |
|---|---|
| Author | delegated Opus researcher-drafter, working for the security owner |
| Baseline | working tree at `perf/zk-batch-optimizations`, `db5ee01`, 2026-09-19 |
| Scope | the custom (hashline) line only. The zkVM line's D7 profile is referenced for contrast, never as evidence about this line |
| Status | a restatement, an inventory of what is settled, a counted analysis of the hash layer, and five candidate closures with costs. No privacy property is established here |
| Reads | nothing was built, run, tested or benchmarked for this document |

---

## 0. For the project owner: what this is about, in plain words

The product promise (D1) is that a regulator can check a proof that an
approved model produced an answer, **without learning the prompt or the
answer**. To make that checkable, the prompt and the answer are each put in a
**sealed envelope** whose outside is a 32-byte fingerprint called a **root**.
The root is public; the contents are not. The proof says: "the model,
applied to what is inside envelope A, produced what is inside envelope B."

For the proof to be checkable the prover must show the verifier *some* of the
envelope. The custom prover does this by opening **256 randomly chosen
windows** into each envelope. Each window shows a strip of scrambled numbers,
a 32-byte random **salt**, and a short chain of 11 fingerprints (an
**authentication path**) proving that this strip really is part of *that*
root. The scrambling is designed so the 256 strips look uniformly random
whatever is inside — that part is analysed and, on real receipts, measured
(§2.5). The 32-byte fingerprints are not analysed at all. That is the gap.

The open obligation, recorded as decisions **D8** and **D11**, is the standard
cryptographic test for "reveals nothing": a **simulator** — a program that
does *not* know what is in the envelope — must be able to manufacture a fake
receipt that nobody can tell apart from a real one. If such a program exists,
the real receipt cannot be leaking anything, because the fake one contains no
secret to leak. For the numbers in the receipt, the project has a long way
towards this. For the **fingerprints**, the simulator faces a wall: it must
produce authentication paths that add up to a root **somebody else chose**.
That is exactly what a fingerprint is designed to make impossible.

There are only three ways out, and §3.6 proves it is only three:

1. Make sure the root has **never been opened before** and give the simulator
   one free "let this fingerprint come out however I want" move, which is a
   standard and widely used modelling assumption (the *random-oracle model*).
   This is the cheapest route and it is where this draft's recommendation
   lands — but it only works for a root with no earlier opening, and it means
   changing what the project promises about roots.
2. Make the root something the **prover generates fresh inside each proof**,
   and have the caller refer to the hidden data by something else. This is
   what the other proving line already does (D7, salted SHA-256 handles). On
   the custom line it costs a proof that the two references agree, and §4.2
   counts that cost: it is large, and at model scale it is bigger than the
   entire speed budget.
3. **Never publish the opening at all** — check the envelope inside the proof.
   That is the zkVM line. It is correct and it is roughly 10^4 times too slow
   to be the product (D2).

Nothing in this document closes D8 or D11. §5 says which route to attack
first, what theorem it would need, and what result would kill it.

---

## 1. The obligation, restated exactly

### 1.1 The objects

**Terms, each on first use.** A *plane* is the rectangular block of integer
words that carries one hidden activation (the block's input `x_in` or its
output `xres2`). A *commitment* is a short public value that pins down a
plane without revealing it. *Hiding* means the commitment reveals nothing
about the plane; *binding* means the committer cannot later claim a different
plane. An *opening* is the prover's public evidence that some stated fact
about the committed plane is true. The *random-oracle model (ROM)* is a
proof technique in which the hash function is replaced by an idealised random
function; *programmable* ROM additionally lets the simulator choose the
oracle's answer at points that have not yet been queried. A *simulator* is
the program of §0 step 1; a *distinguisher* is the adversary that tries to
tell the real receipt from the simulated one.

**The endpoint commitment, exactly as built.** `private_seam::prepare`
(`hashline/src/private_seam.rs:186`) builds it:

| item | value at the tiny (pinned) shape | source |
|---|---|---|
| plane | 512 field words (`rows = 32`, `cols = 16`) | `zk_ffn_fresh_io.rs:40-42` (`SeamSpec::new(context, 32, 16, scale, …)`) |
| message columns `n` | 256 (`LOG_COLS = 8`) | `private_seam.rs:28` |
| data rows | 2 = `ceil(512/256)` | `private_seam.rs:106-108` |
| mask rows | 5 (`MASK_ROWS`): two terminal-mask rows, three proximity rows | `private_seam.rs:36`, `:216-217` |
| commitment rows | **7** | `private_seam.rs:109-111`; pinned in the policy at `zk_ffn_fresh_io.rs:58-68` and re-checked at `private_block/protocol.rs:184,250` |
| pad symbols per row `Q` | 256 (`ZkOpts::standard` sets `q_pad = num_col_checks`) | `zkp-core/src/pcs.rs:543`; refused below that at `:670` |
| inverse rate | 8 (`INV_RATE`) → encoded columns `nn = 2048` | `private_seam.rs:30`; `pcs.rs:50-52` |
| opened columns | 256 (`CHECKS`), drawn **with replacement** | `private_seam.rs:29`; `transcript.rs:119-131` |
| leaf | `blake3(blake3(column bytes) ‖ salt)`, salt = **32 bytes** | `pcs.rs:137-143` (`hash_column`), `:640-645` (`salt_leaf`), salts drawn at `:674` as `rng.bytes32()` |
| Merkle node | `blake3(left ‖ right)`, **no tag, no length frame** | `zkp-core/src/merkle.rs:14-19` |
| tree | 2048 salted leaves, **11 levels of siblings** | `pcs.rs:689-690`; `merkle.rs:22-35`, path length `merkle.rs:46-54` |

The published root is `Commitment { root, rows: 7, log_cols: 8 }`
(`private_seam.rs:150-152`). The whole of what the verifier is handed about
one endpoint is that root plus one `OpeningZk`
(`pcs.rs:567-573`): two group vectors of 512 `Fp2` values, one proximity
vector of 512 `Fp2` values, and 256 tuples `(column index, 7 field words,
32-byte salt, 11 sibling digests)`. That is
`ENDPOINT_OPEN_BYTES = 2·512·16 + 256·(8 + 7·8 + 32 + 11·32) = 131,072`
bytes per endpoint (`zk_ffn_fresh_io.rs:15`), 256 KiB for the pair.

### 1.2 The timeline: who fixes what, and when

1. The endpoint owner calls `prepare_endpoints(spec, input, output)`
   (`zk_ffn_fresh_io.rs:109`; siblings `private_block.rs:375`,
   `private_attention.rs:220`). This draws **fresh OS entropy**
   (`private_seam.rs:196`, `ZkRng::from_os(DOMAIN)`), commits both planes,
   and returns a public `ExpectedIo` and a private, non-`Clone`,
   non-serialisable `Endpoints`.
2. The two roots become the statement. `ExpectedIo::to_bytes` is a **112-byte**
   record: `b"HFFNEXP1"` (8) ‖ context (32) ‖ `input_scale` (4) ‖
   `output_scale` (4) ‖ input root (32) ‖ output root (32)
   (`zk_ffn_fresh_io.rs:76-85`). Those 112 bytes are absorbed into the
   transcript **before any challenge exists** (`:138-146`), so both roots are
   fixed before the columns that will be opened are chosen.
3. The prover runs `prepare` (`:148`) and then
   `PendingProof::finish(endpoints)` (`:276`), which consumes the owners on
   success *and* on failure (`:274-277`) and emits the receipt.
4. The verifier runs `verify` (`:412`), rebuilds the transcript from the
   112 bytes alone, and checks the 256 openings per endpoint against the root
   it was given (`pcs::verify_zk`, `pcs.rs:947`, Merkle check at `:1018-1021`).

**The asymmetry that creates the obligation.** The verifier accepts *any*
well-formed 112 bytes — `ExpectedIo::from_bytes` (`:86-100`) validates only
length, magic and the seam spec, and the doc comment at `:47` says so
explicitly. The honest prover, by contrast, can only prove for roots **it
just generated**: `check_endpoints` (`:258-270`) refuses unless the owner's
own commitment roots equal the policy roots. This is O9's finding **F2**
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:152-157`). The statement the
verifier checks is therefore strictly larger than the statement the prover
can produce, and zero knowledge is a property of the *statement*.

### 1.3 What "prior public history" can physically be in this system

D11 says prior authentication/hash history "remains in scope"
(`ZK60_DECISIONS.md:283-296`) but does not enumerate it. Enumerated:

| # | Candidate history about root `R` | Physically reachable today? |
|---|---|---|
| **H0** | Nothing at all; `R` first appears with the receipt that consumes it | Yes — the default path |
| **H1** | `R` alone published earlier (a policy record, a registry entry, an earlier message), with **no** opening | Yes. Harmless to the one-point construction: publishing an *output* of the oracle blocks nothing, because programming needs a fresh *input* (§3.5) |
| **H2** | Public metadata pinned beside `R`: `rows = 7`, `log_cols = 8`, the two scales, the context digest | Yes, and it is inside the absorbed 112 bytes. It is public parameter data, not oracle history |
| **H3** | A previously published **authentication path** under `R` (any one of them; the last sibling plus the recomputed child *is* the honest top pair) | **Only via a second opening of the same commitment.** Structurally unreachable — see §1.5. This is the history that killed the round-2 closure |
| **H4** | A distinguisher oracle query at the honest top pair `l‖r` | Requires already holding `(l, r)`, i.e. H3, or the committer's salts, or a `2^-256`-per-try guess |
| **H5** | A distinguisher oracle query at any other node or salted-leaf input of the honest tree | Same: requires the salts or the encoded columns |
| **H6** | Application side information about the plane's *contents* (e.g. "the answer is one of 32 values" — the qualifier already written into D7 for the zkVM line, `ZK60_DECISIONS.md:242-247`) | Yes, always. It is not hash-layer history; it bounds what *any* hiding commitment can buy |
| **H7** | A **different** commitment to the same plane, with independent randomness, opened by another proof | Yes, and it is exactly what closure (iii) would create. It is a *data-channel* correlation (the round-23 "two proofs of one witness" study, `ZK60_ROUND23.md:29`), not hash-layer history: the two trees share no oracle point except by `2^-256` accident |

**The point of the table.** The only entry that breaks the hash-layer
argument is **H3**, and H3 is exactly "the root was opened before". So the
case split that matters is not "history / no history" but **"opened before /
not opened before"**, and D8's own correction text already says this
(`ZK60_DECISIONS.md:268-274`). D11 is nevertheless right to refuse the
reduction as it was argued in round 2, for the reason in §1.8.

### 1.4 The three cases the documents conflate

- **Case (a)** — `R` has no prior opening and no prior history at all (H0,
  optionally H1/H2), and is consumed by exactly one proof.
- **Case (b)** — `R` has prior history but still exactly one opening in
  total. By §1.3 this can only be H1, H2, H6 or H7. **A prior
  authentication path is not in case (b): it is case (c).** The documents
  place it in (b) and that is the conflation.
- **Case (c)** — `R` is opened more than once. This is where the two-opening
  recovery of §2.1 lives, and it is fatal at this geometry.

Three consequences, stated now and argued below:

1. Case (b) as it can actually arise (H1, H2, H6, H7) does **not** touch the
   hash layer. H1/H2 are public outputs and parameters; H6 is an
   application-level bound on any commitment; H7 lives on a disjoint tree.
2. The "case (b)" the retraction was about (H3) is case (c) in disguise.
3. So the hash-layer question reduces to: **is there a simulator for case (a)
   — and is case (c) excluded by something a verifier can rely on?**

### 1.5 What the code enforces, and for which roots

The enforcement of "one opening per commitment", with sources:

| Mechanism | Source | What it forbids |
|---|---|---|
| `PreparedPlane` has no `Clone`, no data getter, no opening method | `private_seam.rs:143-147` | holding two copies of one committed plane |
| `into_ffn_endpoint(self, …)` takes `self` by value and is `pub(crate)` | `private_seam.rs:156` | extracting the `CommittedZk` twice, or at all from outside the crate |
| `Endpoints` has no `Clone`, no serialisation, private fields | `zk_ffn_fresh_io.rs:103-107`; `private_block.rs:367-370`; `private_attention.rs:212-215` | passing the same owners to two provers |
| `finish` / `prove` take `Endpoints` **by value** and consume on success *and* failure | `zk_ffn_fresh_io.rs:276-277`; `private_block/protocol.rs:257`; the `compile_fail` doctests at `zk_ffn_fresh_io.rs:125-131`, `private_block.rs:360-366`, `private_attention.rs:205-211` | a second proof attempt against the same commitment — at **compile** time |
| `private_seam::prove` likewise consumes both planes | `private_seam.rs:335-339` | the standalone seam re-opening a plane |
| `prepare` always draws `ZkRng::from_os`; the seed-injecting `prepare_with_rng` is crate-private | `private_seam.rs:186-198`, `:200` | reproducing the same root twice from the same plane |

**The precise answer to "does code enforce one opening for caller-fixed
roots?" is: for a root the prover generated, yes, at compile time. For a root
the prover did *not* generate, the code enforces something stronger — no
proof is possible at all**, because `check_endpoints`
(`zk_ffn_fresh_io.rs:258-270`, `private_block/protocol.rs:243-253`) requires
the prover to hold a `PreparedPlane` whose own root equals the policy root,
and the only producer of a `PreparedPlane` is `private_seam::prepare` with
fresh OS entropy. There is no import interface, no seed interface and no
serialisation.

**Two things this does not settle.**

- It is a property of *this crate's public API*, not of the verifier's
  statement. `verify` will accept a receipt for any root; whether some other
  producer could ever exist is a system rule, not a type.
- A **failed** attempt still emits bytes. `finish` builds the full receipt
  and only the verifier's polynomial identity rejects it
  (`zk_ffn_fresh_io.rs:274-275`: "No equality precheck"). A rejected receipt
  carries 256 genuine authentication paths under `R`. The owner is consumed,
  so no *second* opening follows — but if anyone ever adds a retry path that
  re-prepares the same plane **with the same randomness**, H3 becomes
  reachable. Today it cannot, because there is no seed interface.

### 1.6 The experiment, written as a game

Notation follows O9 (`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:74-135`), which
this section restates and sharpens rather than replaces. `pp` = public
parameters (the profile string, the shape, `log_cols 8 / inv_rate 8 / Q 256`);
`x` = the 48-byte statement part of the policy (magic, context, two scales);
`c_in, c_out` = the two 32-byte roots; `O` = the hash oracle; `q` = the
distinguisher's total oracle queries.

**Game E (the obligation).** The one D8 states.

| phase | real world | ideal world |
|---|---|---|
| setup | `pp` published; `D` may query `O` | same; `S` holds its own state |
| fix | an environment `E` picks the plane values and honest commitment randomness `r` (salts, pads, mask rows) and publishes `c_in`, `c_out`. **`r` is given to neither `S` nor `D`.** `D` additionally receives an auxiliary string `aux` drawn from the history set of §1.3 | identical; `S` receives `(pp, x, c_in, c_out, aux)` |
| prove | the honest prover, holding the `Endpoints`, runs `finish` and publishes the receipt or the refusal | `S(pp, x, c_in, c_out, aux)` publishes a receipt or a refusal |
| output | `D` sees `pp`, the 112-byte policy, the receipt or the refusal string, and all its own oracle answers; it outputs one bit | identical |

`S` is **not** given: any plane value, any salt, any pad, any mask row, any
`PreparedPlane`, or the real `ZkRng` stream. `S` **may**: program `O` at
points that have not yet been answered, and must answer consistently
thereafter. Refusal is an output, not a silent restart (O9 **F6**,
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:168-173`).

**Game J (joint preparation).** The same, except that the *preparation* is
inside the experiment: `SimPrepare(x, dims)` issues its **own** roots and
keeps its own state, and `SimProve` must then honour them
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:48-64`). Game J covers the honest
workflow completely and covers Game E not at all, because `SimPrepare` chose
the roots.

**Why the "`r` is given to neither" clause is load-bearing, and contestable.**
If `D` holds `r`, it can rebuild the honest tree, read off the honest top pair
`(l, r̂)` with `blake3(l‖r̂) = c_in`, and detect any programmed second
preimage — no simulator of the present shape survives. Restricting `aux` to
exclude the commitment randomness is exactly the restriction in
Lyubashevsky–Nguyen–Seiler Definition 2.8 (randomness drawn from `χ`, not
chosen by the adversary), which O9 §5 checked against the primary source
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:221-236`). It is a **weaker notion
than textbook NIZK zero knowledge**, which quantifies over all auxiliary
inputs. It has to be written into any theorem this project states, and it has
to be defended on product grounds: the party holding the salts is the endpoint
owner, who in this system is the prover, i.e. the party whose privacy is being
protected — not the regulator.

### 1.7 The security notion, and the residual terms already accepted

The notion in view is **computational zero knowledge in the programmable
random-oracle model**, with a statistical core: the field-valued part of the
view is argued statistically (up to the reduction bias below) and only the
hash layer is computational-and-programmable. Statistical ZK is not
available: §3.6 shows a non-programming simulator would break binding.

Residual terms the project has already accepted or recorded, which any
theorem must carry rather than hide:

| term | size | source |
|---|---|---|
| mask/pad reduction bias (`ZkRng::fp` draws 128 bits and reduces mod `p`) | `2^-96` per draw; about **`2^-75`** over a tiny proof, `2^-72.9` at 125M, **`2^-72`** at 8B | **D9, accepted as stated** (`ZK60_DECISIONS.md:370-392`) |
| a further recorded residual at the same shape | about `2^-62` | D9 entry, `ZK60_DECISIONS.md:387` |
| LogUp collision (a witness-dependent refusal event, the one such event in `/2`) | `(lookups + table rows)/2^128` per proof | `ZK60_MVP_JOINT_VIEW.md` §1.2 (branch `zk60-mvp-fable`) |
| PRG assumption on the keyed BLAKE3 prover stream | assumption, not a term | `ZK60_NATIVE_JOINT_VIEW.md` §7 item 7 (branch `zk60-native-jointview`) |
| hash-layer programming freshness | `≤ q/2^256` per programmed point, **plus** the union terms of §3.5 | `ZK60_ENDPOINT_SIMULATION_MODEL.md` "fresh-query bound"; O10 §3 |

**One correction to the record, offered for the security owner's ruling.**
O10 **F10.4** states a reduction-bias floor of `2^-51.4` from
`6144 · 2^-64`, using the "bias 2^-64" wording in the source comments
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:135-142`). D9's accepted ruling uses
`2^-96` per draw (`ZK60_DECISIONS.md:372`). At `2^-96`, the same 6,144
endpoint draws give `6144 · 2^-96 ≈ 2^-83.4`, and the whole-proof figure of
`2^-75` is dominated by the ~`2^21` draws of the *whole* proof, not by the
endpoints. F10.4's qualitative conclusion — that the reduction term dwarfs
the `q/2^256` hash term and a bound must not lead with `q/2^256` — is
**unchanged and correct**. Only the number moves. I did not re-derive either
per-draw figure and flag this as a discrepancy to be closed, not as a finding.

### 1.8 What a reviewer attacks first in this section

1. **"§1.5 is the retracted argument again."** It is not, but it is one
   sentence away from it. Round 1 §2 argued from the Rust API that Game E is
   unreachable and was retracted because the *verifier's statement* does not
   know about the API (`ZK60_MVP_JOINT_VIEW.md` §1.1 and its correction note;
   D8's correction, `ZK60_DECISIONS.md:268-274`). §1.5 makes no claim about
   the statement. It says only: *if* the project chooses closure (i) or (v),
   the system rule those closures need is already enforced by the types for
   every root this prover can prove about, so the rule costs nothing to adopt
   and is cheap to test. That is a different claim, and it still requires a
   decision by Victor about what the product promises.
2. **"H3 unreachable" is a claim about a moving target.** It rests on there
   being no import, no seed and no serialisation interface. Any of the three
   would reopen it. It should be a named, tested invariant (§5), not an
   observation.
3. **The `aux`-excludes-`r` clause (§1.6).** The first thing an external
   cryptographer will say is that this is not zero knowledge as usually
   defined. The honest answer is that no hash-Merkle commit-and-prove system
   achieves the stronger notion for foreign roots, that the weaker notion is
   the established one for commit-and-prove (LNS Def 2.8), and that the
   product's threat model matches it. That answer must be written down and
   accepted, not assumed.
4. **Case (b)'s emptiness (§1.4).** If anyone finds a fifth kind of history
   that is neither a public output, a parameter, an application bound nor a
   disjoint tree, the case split collapses and §4's costing changes.

## 2. What is proved, what is refuted, what is open

### 2.1 Proved natively: two openings of one endpoint commitment recover the plane

**Statement (PROVED, reproduced in native Rust).** At the actual seven-row,
256-column endpoint geometry, **two PCS openings of one commitment recover
all 512 data words**, using only the two public group vectors and their
public challenge coefficients — no masks, pads, salts, paths or RNG seed
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`, `:16-22`; regression
`zkp-core/tests/endpoint_reuse.rs`, invoked by
`cargo test --release --offline --manifest-path zkp-core/Cargo.toml --test endpoint_reuse`).

**The mechanism, in one line.** For each coordinate pair an opening publishes
`v = a·x + b·y + c·m` over the quadratic extension, where `x, y` are
base-field data words and `m` is the *fixed* terminal mask. Two openings
share `m`; subtracting cancels it and leaves one complex equation, i.e. two
base-field equations, in `x, y`. The tested public coefficient matrix is
invertible (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:16-22`).

**What it settles.** Case (c) is not repairable at this geometry by any
simulator: in the real world two openings *determine* the plane, so no
witness-independent distribution exists. D12 rule 1 ("no commitment is opened
more than once, anywhere in a composed block", `ZK60_DECISIONS.md:319`)
is the correct and necessary response.

**What it does not settle.** The disposition says so itself: it deliberately
bypasses the consuming owner, no production code changed, and "the one-use
lifecycle does not close the outstanding caller-fixed-root privacy argument"
(`:35-43`).

### 2.2 Refuted: the forced-challenge counterexample, and what it does not show

**The premise refuted.** The archived two-use redesign asserted (its item
**A4**) that for **every** non-refused challenge vector, the per-use
proximity checks leave the data rows unrecoverable. That universal assertion
is **false as written**: there exist challenge pairs that pass both uses'
individual proximity-pair checks while sharing identical mask coefficients,
so that subtracting the two proximity vectors cancels the masks and reveals
both data coordinates (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:48-56`;
test `tests/test_zk60_budgeted_endpoint_boundary.py`, whose own docstring
states the scope, lines 1-8; the control at
`test_separate_proximity_masks_do_not_cancel_in_the_control`).

**What it does *not* show**, stated as strongly as the evidence allows:

- It is **not** an efficient attack on randomly sampled Fiat–Shamir
  challenges. The bad challenge set is exhibited by *forcing* the challenges,
  not by sampling them; nothing bounds its density from below.
- It is **not** a native full-proof attack, and it touches no production
  path: the model it refutes is an archived research proposal
  (`results/zk60_loop_20260918/reviews/fable_reuse/…`, pinned by SHA-256 in
  the test at `tests/test_zk60_budgeted_endpoint_boundary.py:25`).
- It says nothing about case (a) or about the hash layer.

**What a repaired budgeted argument would need** (from the same disposition,
`:45-54`): either a *joint*-rank refusal — a check the verifier can run that
rejects exactly the degenerate challenge pairs — or a justified upper bound on
the probability of the bad-challenge event under real Fiat–Shamir. Neither
exists. Since D12 forbids two uses anyway, the practical status is: the
budgeted two-use scheme is not a live candidate, and nothing should be built
on A4.

### 2.3 Retracted: the one-programmed-point closure, and exactly where it breaks

**The claim that was made.** `ZK60_MVP_JOINT_VIEW.md` §1.1 (branch
`zk60-mvp-fable`) proposed: run the honest prover on the all-zero witness
with fresh randomness, building each endpoint's own tree over zero data with
fresh salts; let `(l′, r′)` be that tree's two top-level children; and
**program the single oracle point `l′‖r′ ↦ R`**, where `R` is the caller's
root. Two programmed points per proof (one per endpoint); every other leaf,
node and transcript hash a genuine query. The stated detection bound was
`q/2^256` for `q` prior oracle answers.

**Where it breaks.** An accepted opening under `R` publishes an 11-sibling
authentication path. Recompute the chain from the opened leaf; at the top,
the recomputed value is one child of the root and **the last sibling on the
path is the other**. So any previously published path hands the distinguisher
the honest pair `(l, r̂)` with `blake3(l‖r̂) = R`, with no secret salt and no
guessing. The distinguisher now holds **two distinct 64-byte preimages of
`R`** — the honest one from the earlier path and the simulator's `(l′, r′)`
from this receipt — which cannot happen in the real world except with
probability about `2^-256`. The simulator's own freshness guard does not
fire, because it guards the *input* it is about to program, not whether a
preimage of the same *output* is already public
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:10-22`; regression
`tests/test_zk60_root_history_boundary.py`, which loads the pinned delivery
read-only at lines 17-19 and skips rather than substitutes if the commit is
absent, lines 24-35; validated 2026-09-18, three tests, 0.068 s,
`ZK60_JOINT_VIEW_REVIEW_20260918.md:49`).

**Exactly what survives the retraction, and exactly what does not.**

- **Survives:** the construction for a root with **no prior opening**. The
  retraction note in the memo itself says so, and D8's correction repeats it
  (`ZK60_DECISIONS.md:270-274`).
- **Does not survive:** the sentence in the memo's §1.1 bullet that the
  distinguisher "can tell the worlds apart only if … it already holds the
  honest committer's `(l, r)`, which requires the committer's secret salts or
  a `2^-256`-per-guess event". A path is a third way and it needs neither.
- **Also does not survive:** using `q/2^256` as *the* bound. O10 §3 lists
  six further union terms it omits (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:100-142`),
  and §1.7 above records which term actually dominates.

**Note on which artefact is being talked about.** Two different hash-layer
constructions exist in the record and are easy to confuse:

| construction | leaves | programmed points | where |
|---|---|---|---|
| round-23 candidate | 2048 **free digest handles**, not preimages of anything | up to 256 salted-leaf points per endpoint, programmed late | `scripts/zk60_endpoint_simulation.py`; `ZK60_ENDPOINT_SIMULATION_MODEL.md` "A concrete candidate" |
| round-2 / two-point | a **genuine** fresh commitment to zero data: all 2048 leaves are real `salt_leaf(hash_column(·), ·)` images | **one node point per endpoint**, at the top | `scripts/zk60_root_simulator.py` on branch `zk60-mvp-fable` (not in the main tree) |

O10's **F10.3** — "the unopened leaves are the larger half of the union",
1792 of 2048 unexplained handles per endpoint
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:159-161`) — is a criticism of the
**round-23** construction only. The two-point construction has no unexplained
leaves. Any restatement must not carry F10.3 across; §3.5 does the count
afresh for the two-point shape.

### 2.4 The sequential-kernel lemma and its joint hypothesis

**Lemma (sequential kernel), as stated and as accepted.** Let the prover
publish `m_0, …, m_n`; let each challenge `r_j` after `m_j` be any function
`H` of the public prefix; let `m_j` depend only on the witness, the prover's
private randomness and `r_{<j}`. **If, for every fixed challenge vector `ρ`,
the *joint* law of `(m_0, …, m_n)` given `ρ` is the same for witnesses `w`
and `w′`,** then for every `H` the law of the whole view `(m, r)` is the same
for `w` and `w′`. Proof: induction on `j`; each kernel
`K_j(m_j | m_{<j}, r_{<j})` is a ratio of two marginals of the per-`ρ` joint
law, the challenges are deterministic in the public prefix, and the view's law
is the product of the kernels with the challenge indicators
(`ZK60_MVP_JOINT_VIEW.md` §1.2, branch `zk60-mvp-fable`).

**Its status.** The independent review accepted it as **valid for the stated
causal message rules, under the strengthened joint hypothesis**
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`). The earlier
marginal-law counterexample (`H(mask), mask ⊕ w`: witness-independent
marginals, witness-*dependent* joint law) does not contradict it; it shows
why the hypothesis must be joint. Exhaustive checks on finite toy protocols
are in `tests/test_zk60_sequential_kernel.py` — **on branch `zk60-mvp-fable`
only; it is not in the main tree** (verified 2026-09-19).

**Two carve-outs in the lemma itself, which must travel with any use of it.**

1. Refusal events that are functions of the public prefix inherit the same
   law; **witness-dependent refusals break the conclusion**. In `/2` there is
   exactly one such event, the LogUp collision, priced at
   `(lookups + table rows)/2^128` per proof.
2. The hypothesis is about *field* messages. The lemma says nothing about the
   hash layer, because roots, salts and paths are not "messages the prover
   chooses given `ρ`" in the sense of its causal rule — they are determined
   before the challenges exist.

**The open item.** The joint hypothesis is **not discharged**. It is carried
as **U-3** (`ZK60_MVP_JOINT_VIEW.md` §4) and reaffirmed as open by the
security owner as recently as 2026-09-19
(`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5, branch `zk60-native-jointview`).

### 2.5 What today's joint-view evidence supports, and what it cannot touch

The 2026-09-19 native joint-view lane analysed **real receipts** — two
complete-block and two attention receipts — at their **real** BLAKE3
challenges, replayed from the public prefix (`ZK60_NATIVE_JOINT_VIEW.md`
§§1-6, branch `zk60-native-jointview`).

**Supported, on the linear channels:**

- Disclosed dimension **0** on `A`, on the Input endpoint and on the Output
  endpoint; **2** on `H`, and that 2 is its public LogUp identity, whose
  published claim value is `Fp2::ZERO` (§5). A zero-data preimage therefore
  exists on every channel.
- Channels covered: claim values, opening-group vectors, the proximity
  vector, every sampled column value, the M opening's `q`, its proximity
  vector and column values, and the slots' masked round messages (§5).
- The pad budget is **sufficient with zero margin**: 256 pads against 256
  distinct opened positions of the real encoded domain gives exact Gaussian
  rank **256 of 256**; the boundary cases `q_pad = d`, `d+1`, `d−1` disclose
  0, 0, 3 (§9b). The reason is structural — the pad half of the column map is
  `diag(x_j^n − 1)` times a Vandermonde in distinct nodes, full **row** rank
  for every `d ≤ q_pad` (§9b, citing `pcs.rs:618`, `:543`, `:670`).
- Group vectors consume **no** pad freedom: measured `q_pad · k0` with
  `k0 = 0` on every role of every capture (§9b).
- Every negative control fires, including "the commitment opened twice"
  (disclosed 10 in the small model, §6) and an altered capture (the replay
  fails on all four, §6).

**Not touched — stated by the lane itself** (§5 "Channels NOT covered", §7):

1. **The three Merkle roots, the 256 salts served per opening, and the 11-
   and 12-level authentication paths.** "Hash objects; linear algebra does
   not cover them." What is *assumed* for them is salted-leaf hiding of the
   unopened columns and, for the two caller-fixed roots, "the programmable
   random-oracle argument of D8/D11, **which is OPEN**" (§5).
2. Only two challenge vectors per profile — not a generic-rank argument.
3. The adaptive/distributional lift (the lemma of §2.4 and its joint
   hypothesis).
4. The nonlinear link between the two channels (`fin − c·g(ρ) =
   poly(terminals)`, degree up to 4).
5. Integer-range side information: the planes are small integers embedded in
   `Fp`; the model treats them as free `Fp` values.
6. Timing and other side channels; the PRG assumption on `ZkRng`.

**The sentence the project may quote** is the lane's own (§9a, last
paragraph), and it is careful: on a *linear model* of the verifier's view at
the *real* challenges of four receipts, nothing about the hidden planes is
determined beyond public identities — **and** the hash layer, which rests on
the open D8/D11 obligation, is excluded.

**So the division of labour is now clean.** The field layer has strong,
real-receipt evidence and one named written obligation (U-3, the joint
hypothesis). The hash layer has **no** argument at all for foreign roots.
Everything below is about the hash layer.

### 2.6 The ledger

| item | status | where |
|---|---|---|
| two openings of one endpoint commitment recover all 512 data words | **PROVED** (native regression) | `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`; `zkp-core/tests/endpoint_reuse.rs` |
| case (c) has no simulator at this geometry | **follows from the above** | §2.1 |
| the budgeted two-use scheme's universal per-use rank premise (A4) | **REFUTED** as stated | `:48-56`; `tests/test_zk60_budgeted_endpoint_boundary.py` |
| an efficient attack on random challenges | **not shown** | same |
| the one-programmed-point closure for a root with a prior public opening | **RETRACTED** | `ZK60_JOINT_VIEW_REVIEW_20260918.md:10-22`; D8 correction |
| the same closure for a root with **no** prior opening | **not retracted; also not proved** — the bound as written omits the union terms of O10 §3 | §2.3, §3.5 |
| sequential-kernel lemma | **valid** under its joint hypothesis | `ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56` |
| the joint hypothesis itself | **OPEN (U-3)** | `ZK60_NATIVE_JOINT_VIEW.md` §9a.5 |
| disclosed dimension 0 on the linear channels of real receipts | **MEASURED** on four captures at real challenges | `ZK60_NATIVE_JOINT_VIEW.md` §2.3, §5, §9b |
| the hash layer (roots, salts, paths) for foreign roots | **OPEN — no construction exists** | `ZK60_NATIVE_JOINT_VIEW.md` §5, §7.1; O9 §7.1 |
| one opening per commitment, enforced in code | **enforced at compile time for every root this prover can prove about**; not a property of the verifier's statement | §1.5 |

## 3. The hash layer, which is the actual gap

### 3.1 What the verifier actually sees, counted

Per endpoint, exactly (`pcs.rs:567-573`, `:915-943`; serialisation `:582-601`):

| object | count | bytes | note |
|---|---|---|---|
| root | 1 | 32 | in the absorbed 112-byte policy |
| group vector | 1 | `(n+Q)·16 = 512·16 = 8,192` | `Fp2`, message then pad entries |
| proximity vector | 1 | 8,192 | |
| column index | 256 | 2,048 | drawn **with replacement**, `transcript.rs:119-131` |
| column values | 256 × 7 words | 14,336 | |
| **salts** | 256 × 32 B | **8,192** | one per opened column, `pcs.rs:935` |
| **authentication paths** | 256 × 11 digests | **90,112** | full path emitted per *draw*, duplicates included |
| **total** | | **131,072** | matches `ENDPOINT_OPEN_BYTES`, `zk_ffn_fresh_io.rs:15` |

So the hash layer is `32 + 8,192 + 90,112 = 98,336` bytes of the 131,072 —
**75 % of an endpoint opening is hash material**, and none of it is covered
by the linear analysis of §2.5.

### 3.2 What a simulator must produce

For case (a), `S` receives `(pp, x, R_in, R_out)` and must output, per
endpoint:

1. **256 column value vectors.** These it can sample: the pad argument
   (§2.5, `ZK60_NATIVE_JOINT_VIEW.md` §9b) shows that with `q_pad = 256` pads
   per row and up to 256 distinct opened positions, the opened symbols of
   each row are **jointly uniform given the data** — the pad half of the
   column map is `diag(x_j^n − 1)` times a Vandermonde in distinct nodes,
   full row rank for every `d ≤ q_pad`. Sampling a real commitment to the
   all-zero plane and reading off its columns gives exactly the right law.
2. **256 salts.** Uniform 32-byte strings, drawn freshly. Same law in both
   worlds (`pcs.rs:674`).
3. **256 authentication paths verifying under a root it did not choose.**
   This is the whole problem.
4. **Group and proximity vectors consistent with (1)** and with the FFN's
   field messages. This is the U-3 field-layer obligation of §2.4, not the
   hash layer; §3 assumes it and says so.

**Can (3) be done without programming the oracle?** No. `verify_zk`
recomputes `salt_leaf(hash_column(col), salt)` and walks the 11 siblings to
the root (`pcs.rs:1018-1021`, `merkle.rs:56-63`). To produce a chain that
lands on `R` without holding a preimage of `R` is to invert BLAKE3, or to
find a second preimage of `R` — both `2^-256`-class. The model document
states this (`ZK60_ENDPOINT_SIMULATION_MODEL.md`, "A valid authentication
path also reveals a pair of top-level child digests hashing to the fixed
root"), O9 restates it (`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:111-135`, Game E),
and §3.6 turns it into a statement about *every* construction, not just this
one.

### 3.3 Counting the tree: revealed nodes at both geometries

The 256 column indices are drawn uniformly **with replacement** from `nn`
positions (`pcs.rs:928` → `transcript.rs:119-131`). Writing `A_j` for the
expected number of distinct level-`j` ancestors of the opened set,
`A_j = (nn/2^j)·(1 − (1 − 2^j/nn)^{256})`. Every node at level `j` that is a
child of a level-`(j+1)` ancestor becomes public — it is either recomputed by
the verifier or published as a sibling — so the revealed set at level `j` has
size `2·A_{j+1}`.

**Tiny geometry (`nn = 2048`, depth 11 — the pinned endpoint profile, and
also the widened profile if it keeps `log_cols 8 / inv_rate 8`)**
[COUNTED, exact expectations]:

| quantity | value |
|---|---|
| distinct opened leaves | **240.7** of 256 draws (≈ 15.3 duplicate draws) |
| `A_1 … A_{11}` | 226.6, 201.6, 162.0, 110.8, 62.9, 32.0, 16.0, 8.0, 4.0, 2.0, 1.0 |
| leaf digests revealed | **453.2** = 240.7 opened + **212.5 unopened** |
| internal nodes revealed (levels 1–10) | **1,200.6** |
| root | 1 |
| **total distinct tree nodes revealed** | **1,654.8 of 4,095** — **40.4 % of the whole tree** |
| distinct sibling digests actually published | **587.2** (of 2,816 digest slots emitted — heavy duplication) |
| honest oracle queries to build the tree | 2,048 column hashes + 2,048 salted leaves + 2,047 nodes = **6,143** |

**Model geometry (`nn = 65,536`, depth 16 — `log_cols 14 / inv_rate 4`, the
CLI default at `hashline/src/bin/hashline.rs:59` and the geometry a widened
`SeamSpecG` would inherit from `LayerParams` under D17/E-2)**
[COUNTED]:

| quantity | value |
|---|---|
| distinct opened leaves | **255.5** of 256 |
| leaf digests revealed | **510.0** = 255.5 opened + **254.5 unopened** |
| internal nodes revealed (levels 1–15) | **3,643.8** |
| **total distinct nodes revealed** | **4,154.7 of 131,071** — **3.2 %** |
| distinct sibling digests published | **1,822.4** (of 4,096 slots) |
| honest queries to build the tree | 65,536 + 65,536 + 65,535 = **196,607** |

**Opening bytes for reference** [COUNTED from the geometry]: 131,072 B per
endpoint at the tiny shape; **946,176 B (0.90 MiB)** per endpoint at
`log_cols 14 / inv_rate 4` with a `512 × 4096 = 2^21`-word plane (133 rows);
and **16,904,192 B (16.1 MiB)** per endpoint if the same `2^21` plane were
committed at `log_cols 8 / inv_rate 8` (8,197 rows). The last figure is a
reason to widen the endpoint profile with the layer, independent of privacy.

**Two things this count makes concrete.** First, the tiny geometry publishes
**40 % of the tree** — near the top, every node is revealed (`A_j` saturates:
levels 6–11 are fully covered). Second, the top pair is *always* revealed:
`A_{10} = 2.0` exactly, because 256 draws hit both halves of a 2048-leaf tree
with probability `1 − 2·2^-256`. There is no "sometimes the top pair stays
hidden" case to hide behind. Same at the model geometry (`A_{15} = 2.0`).

### 3.4 The unopened leaves, the salt, and what hiding requires of the oracle

Of the leaf digests published as level-0 siblings, **212.5 at the tiny
geometry and 254.5 at the model geometry are hashes of columns that are never
opened**. Each is `blake3( blake3(column bytes) ‖ salt )` with a **32-byte
(256-bit) salt** drawn from `ZkRng::bytes32()` (`pcs.rs:640-645`, `:674`).

**What their hiding needs.**

- *In the ROM*: immediate. The input is a fresh 64-byte point, the output is
  uniform, and the distinguisher learns the preimage only by querying it,
  which requires guessing the 256-bit salt: `≤ q·2^-256` over all `q`
  queries.
- *In the standard model*: **an assumption that is not collision
  resistance.** What is needed is that `BLAKE3(y ‖ s)` with uniform
  256-bit `s` is a computationally hiding commitment to `y`. That is a
  PRF/extractor-style assumption on BLAKE3 keyed by the second half of its
  input. It is reasonable and universally made; it is not implied by
  anything the project has written down, and any theorem must name it.
- *Sharpness*: the 32-byte salt is ample (the leak, if any, is bounded by
  the salt's min-entropy, 256 bits, against a 256-bit digest).

**The domain-overlap constraint, re-checked and narrowed.** O10 **F10.1**
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:143-157`) records that `salt_leaf`
(`pcs.rs:640`) and `hash_pair` (`merkle.rs:14`) are **the same untagged
64-byte BLAKE3 domain**, and that `hash_column` (`pcs.rs:137`) avoids them
only by length (`8·rows`), degenerating at exactly 8 rows — and that a 5-row
commitment would alias `ZkRng::refill`'s 40-byte input (`rng.rs:53`).

**New observation, offered as a correction to the risk framing.** For seam
endpoints the degenerate row counts are **unreachable by construction**.
`SeamSpec::new` refuses unless both axes are powers of two and
`2 ≤ len ≤ 4096` (`private_seam.rs:66-72`), so `len` is a power of two;
`data_rows = ceil(len/256)` (`:106-108`) is therefore 1, 2, 4, 8 or 16, and
`commitment_rows = data_rows + 5` (`:109-111`) is one of **{6, 7, 9, 13, 21}**
— never 5, never 8. A widened `SeamSpecG` inherits the same shape rule, so
the invariant is `2^k + MASK_ROWS ≠ 8` and `≠ 5`, which holds for every
`k ≥ 0` given `MASK_ROWS = 5`. This should be an **asserted, tested
invariant** rather than a coincidence, because it is one change to
`MASK_ROWS` away from being false, and because the *other* commitments in a
proof (`A` at 702 rows, `H` at 1326, `M` at 20, P3 `W` at 11, P1 public `W`
at 3 — O9 §4) are not protected by any rule at all.

### 3.5 Case (a): how many points are programmed, where, and are they fresh

Take the **two-point** construction of §2.3 (a genuine fresh commitment to
zero data, not the round-23 free-handle tool). Per endpoint:

| level | what the simulator does | count | genuine or programmed |
|---|---|---|---|
| column hashes | `hash_column` over its own encoded columns | 2,048 (tiny) / 65,536 (model) | genuine |
| salted leaves | `salt_leaf(·, fresh salt)` | 2,048 / 65,536 | genuine |
| internal nodes, levels 1..depth−1 | `hash_pair` up its own tree | 2,046 / 65,534 | genuine |
| **root** | `hash_pair(l′, r′) ↦ R` | **1** | **programmed** |

**One programmed point per endpoint, two per proof, both at the topmost
level** (the hash of the two level-`(depth−1)` children). Everything else —
6,142 of 6,143 queries at the tiny geometry, 196,606 of 196,607 at the model
geometry — is a genuine oracle call.

**Is the programmed point fresh in case (a)?** Freshness means: no answer for
the 64-byte string `l′‖r′` exists yet. The bad events, counted:

| event | bound (tiny) | bound (model) |
|---|---|---|
| the distinguisher already answered `l′‖r′` (it must guess two uniform digests) | `q·2^-256` per endpoint | same |
| `l′‖r′` collides with one of the simulator's own genuine node or salted-leaf inputs | `(2,046 + 2,048)·2^-256 ≈ 2^-244.0` | `(65,534 + 65,536)·2^-256 ≈ 2^-239.0` |
| `l′‖r′` collides with a `hash_column` input | **0** — column inputs are `8·rows` bytes, never 64, by the invariant of §3.4 | 0 |
| the two endpoints' programmed points coincide | `2^-256` | `2^-256` |
| the distinguisher's own verification queries enter the same table (O10 **F10.5**) — 13 queries per opening it checks at the tiny geometry, 18 at the model geometry | inside `q` | inside `q` |
| **a second preimage of `R` is already public** | **excluded by the case-(a) hypothesis** — this is exactly H3 | — |

**Total hash-layer term in case (a): about `2·(q + 4,094)·2^-256`** [COUNTED
from the stated events]. For any realistic `q` (say `2^80`) this is about
`2^-175`. **It is dwarfed by the accepted D9 term of `2^-72`** (§1.7).

**The honest reading of that.** In case (a), the hash layer is *not* the
binding constraint on the privacy bound — the mask/pad reduction bias and
the unfinished field-layer joint hypothesis are. What the hash layer costs in
case (a) is not bits; it is an **assumption**: the programmable random-oracle
model, in which the *same* oracle also carries the Fiat–Shamir challenges.
The project already assumes the ROM for Fiat–Shamir soundness of this
transcript, so this is not a new assumption class — but it *is* a new *use*:
programming for privacy, on a table shared with the soundness argument. A
reviewer should be asked explicitly whether the two uses compose (see §3.8).

**Not established by any of this**, and it must be said in the same breath:
the column values the simulator serves at step (1) of §3.2 must be sampled
from the **real joint conditional distribution**, jointly with the group
vectors, the proximity vectors, the CFS rounds and the FFN messages. That
sampler does not exist (O9 §7.2; `ZK60_ENDPOINT_SIMULATION_MODEL.md` "What
remains before acceptance", first bullet). §3.5 is a statement about the
hash layer **given** that sampler, not a simulator.

### 3.6 The equivocation trilemma: why there are only three kinds of closure

**Proposition (PROPOSED; elementary, but not previously written down in this
repository).** Let `C` be a computationally binding commitment scheme and let
a proof system publish, as part of its accepted transcript, an opening of `C`
at a commitment value `c` that the simulator did not produce. Then any
efficient simulator that produces an accepting transcript without the
committed value must do at least one of:

1. **program the idealised primitive** underlying `C` (the random oracle, a
   CRS trapdoor, or an equivalent), or
2. **break binding** of `C`, or
3. **not publish an opening of `C` at all.**

*Argument.* Suppose neither (1) nor (3). The simulator outputs an accepting
opening of `c` to some value `v′`. The real prover's opening is to the true
value `v`. If the two worlds are indistinguishable and the witness
distribution is non-trivial, then with noticeable probability `v′ ≠ v`, and
the pair of openings is a binding break; if `v′ = v` always, the simulator
computed the witness, contradicting that it was not given it (for a hiding
commitment with non-trivial witness entropy). ∎

*What a reviewer attacks:* the step "if the two worlds are indistinguishable
then with noticeable probability `v′ ≠ v`" is informal — the simulator could
in principle output an opening to `v` without "computing" it, if the
commitment's opening set is small enough. That is why this is labelled
**PROPOSED**, and why it is offered as a structuring device rather than as a
theorem the project relies on. Its value is that it exactly matches the three
routes already visible in the record: the ROM programming of §2.3 (route 1);
"the commitment's randomness is the simulator's", i.e. Game J (which escapes
the hypothesis, not the conclusion); and the zkVM line's D7 profile, where
the opening is a private witness computation and only a salted SHA-256 handle
and the Groth16 proof are public (route 3,
`ZK60_DECISIONS.md:222-232`).

**Corollary for the hash layer.** Statistical zero knowledge for foreign
roots is unavailable with this commitment: route 2 is a break, route 3 is a
different protocol, and route 1 is computational-and-programmable by
definition. Any theorem this project states about case (a) is therefore a
**computational, programmable-ROM** theorem, and §1.7's framing is forced,
not chosen.

### 3.7 Case (b): which programmed points stop being fresh, item by item

Taking the history enumeration of §1.3 item by item against the single
programmed point `l′‖r′ ↦ R` of §3.5:

| history | does the programmed point stop being fresh? | why |
|---|---|---|
| **H0** nothing | no | the case-(a) analysis applies unchanged |
| **H1** `R` alone published early | **no** | programming needs an unanswered **input**. `R` is an *output*. Publishing it constrains nothing about which 64-byte strings are answered. The simulator may program after `R` is public, and must, since it learns `R` then |
| **H2** shape/scale/context metadata | no | not oracle history; it is absorbed public parameter data (`zk_ffn_fresh_io.rs:76-85`) |
| **H3** a prior authentication path under `R` | **YES — fatally** | the path hands the distinguisher the honest pair `(l, r̂)` with `blake3(l‖r̂) = R`. Together with the simulator's published `(l′, r′)` that is **two distinct preimages of one output**, an event of probability `≈ 2^-256` in the real world. The programmed point is still *fresh as an input*; it is **detectable as an output collision**. This is the precise failure mode, and it is why "fresh input" is the wrong guard (`ZK60_JOINT_VIEW_REVIEW_20260918.md:16-20`) |
| **H4** a query at the honest top pair | **YES** | same detection, arrived at differently; requires H3 or the salts |
| **H5** a query at another honest node/leaf input | **partially** | it does not break the top programming, but it lets the distinguisher rebuild part of the honest tree upward and eventually reach `(l, r̂)` — from a level-`j` honest node it needs the `2^j` honest leaves below it. Reachable only with the salts or the columns |
| **H6** application knowledge of the plane's contents | **no** (to the hash layer) | it bounds what hiding is worth, exactly as D7's qualifier (1) records for the zkVM line (`ZK60_DECISIONS.md:242-247`). It is a product statement, not a simulator failure |
| **H7** a second, independent commitment to the same plane | **no** (to the hash layer) | the two trees share no oracle point except with probability `≈ 6,143·6,143·2^-256`. It **does** load the *field* layer: two openings of two commitments to one plane is the round-23 "two proofs of one witness" configuration, whose joint analysis is not done (`ZK60_ROUND23.md:29`) |

**So: within the hash layer, case (b) is either empty or equal to case (a).**
Every history that breaks the construction (H3, H4, H5) requires a prior
opening or the commitment randomness — i.e. it is case (c) or it violates the
`aux`-excludes-`r` clause of §1.6. Every history that is genuinely reachable
with one opening (H1, H2, H6, H7) leaves the programmed point fresh **and**
leaves the output-collision detector without a second preimage.

**This is a narrowing of D11, and it needs the security owner's ruling, not
mine.** D11 says the general obligation "stands unchanged"
(`ZK60_DECISIONS.md:283-296`). Nothing above contradicts that as a statement
about the *verifier's statement space*. What it claims is narrower: *in this
system, with these interfaces, the only prior history that defeats the
hash-layer construction is a prior opening.* If that is accepted, the
obligation becomes "exclude case (c) by a rule, and prove case (a)".

### 3.8 What a reviewer attacks first in this section

1. **Programming for privacy on the same oracle table that carries
   Fiat–Shamir soundness.** The simulator fixes `blake3(l′‖r′) = R`. The
   transcript's challenges are `squeeze_bytes` outputs on 47-byte inputs
   (`transcript.rs:85`, O10 row 3) — a different length, so no direct
   overlap. But a *joint* statement ("this system is sound **and** zero
   knowledge") quantifies over one oracle, and the soundness reduction may
   not remain valid against an adversary that sees programmed answers. This
   composition is **not** addressed anywhere in the record and is the single
   most likely place an external reviewer stops. Naming it is part of the
   deliverable of §5.
2. **The `2·(q + 4,094)·2^-256` figure.** It counts the events I could
   enumerate. O10 §3 lists seven gap classes between a local fresh-query
   bound and a whole-view bound; items 1, 3 and 4 of that list are covered
   above, items 5 (reduction bias) and 7 (unmodelled couplings) are carried
   in §1.7 and §3.5's last paragraph, and item 2 (unopened leaves) does not
   apply to the two-point shape (§2.3's table). Item 6 (repetition) does
   apply and is not counted here: the union grows with the number of proofs
   a distinguisher sees.
3. **"40 % of the tree is revealed" sounds alarming and is not.** In the
   simulated world those nodes are genuine hashes of a genuine zero-data
   tree; the count matters only because it fixes how much the simulator must
   build honestly, not because it leaks. A reviewer should nevertheless check
   that no *statistical* test on 1,655 revealed digests separates the worlds
   — in the ROM it cannot, in the standard model it is the same BLAKE3
   assumption as §3.4.
4. **The proposition of §3.6 is informal.** It should either be tightened to
   a standard commit-and-prove impossibility statement with a proper
   reduction, or demoted to a taxonomy and not cited as a result.
5. **The whole of §3 is conditional on the field-layer sampler that does not
   exist.** If the joint conditional sampler (U-3 plus O9 §7.2) turns out to
   be impossible at these parameters, §3 is moot.

## 4. Candidate closures

All five are costed against the same two reference points: the pinned tiny
shape, and the **58.40 s** Mistral-7B 32-layer × 512-token pass on a laptop
RTX 4070 (`MVP_STATUS.md:139`, [MEASURED, NOISY-SHARED, 2026-09-04]), whose
committed volume is **9.78 × 10^9 field words** — 18,649 rows × 16,384
columns per layer × 32 layers, 78 GB of message data into 313 GB of codeword
(`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md:127-138`, [COUNTED/MEASURED]). That is
**1.67 × 10^8 committed words per second** on that machine, which is the rate
every estimate below divides by. The LogUp helper volume of the same pass is
`H = 4,379 × 16,384 × 32 = 2.29 × 10^9` field inverses; "helpers + commit H"
is 5.555 s of the public pass and **146.26 s of 265.34 s (55 %)** of the
legacy private pass (`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md:463`).

Every option is measured against **D17 rule 2**: the tiny private-IO path
stays byte-frozen and everything new is additive
(`ZK60_DECISIONS.md:521-525`).

### 4.1 (i) Restrict the obligation to case (a)

**The change.** Make it a rule of the system that an endpoint root is
**published for the first time together with the first (and only) proof that
consumes it**. Nothing is proved about roots with prior openings, because no
such root can occur.

**Does the code already do this?** For every root this prover can prove
about, yes — §1.5. What is missing is that it is not *stated*, not *asserted*
and not *tested as an invariant*, and that the verifier cannot check it from
the bytes. "This root has never been opened before" is a property of the
world, not of the artefact.

**What it makes the verifier's statement.** Today: "there exist hidden planes
under `R_in`, `R_out` such that the model maps one to the other." Under (i):
the same, **plus** a caveat the artefact cannot carry — "and this proof is
private provided `R_in`, `R_out` were never opened before". A regulator
receiving one receipt cannot verify the proviso. Three ways to give it
teeth, in increasing cost:

1. **A registry.** Whoever publishes roots records `(root, context)` and
   refuses a repeat. Detection, not prevention; it is an operational
   control, and it is exactly the kind of control a regulator already
   understands.
2. **Bind freshness into the statement.** The 112-byte policy already
   absorbs a 32-byte `context` (`zk_ffn_fresh_io.rs:79`). Require the
   context to be a per-request nonce and require the verifier to reject a
   context it has seen. Cheap; still operational; changes no bytes because
   the field exists.
3. **Make reuse impossible by construction** — which is closure (ii) or the
   architectural fix of §4.3.

**What it costs.** Nothing in prover time, nothing in proof bytes, at either
geometry. Zero rows, zero seconds. [COUNTED: no change to any committed
object.]

**What it loses, and this is the real price.** The root stops being a stable
public name for a hidden value. A regulator cannot use it to say "the same
prompt was used in these two proofs"; a downstream proof cannot refer to an
upstream hidden output by its root. §4.3 shows the second of those is
recoverable architecturally and the first is not.

**Closes:** (a) — in the sense that it makes (a) the only case. **(b):**
vacuously, since §3.7 shows the reachable (b) histories do not touch the
hash layer. **(c):** excluded by rule, and by the types today.
**Residual assumptions:** everything in §5's theorem, plus the operational
control. **Files:** `ZK60_DECISIONS.md` (a new ruling),
`ZK60_ENDPOINT_SIMULATION_MODEL.md`, this document, and one new test file
asserting the invariants of §1.5 and §3.4. No source file on a frozen path.
**Measurement that would test it:** a capture-level gate that refuses two
retained receipts sharing an endpoint root or a context digest — runnable
today on `results/` captures.

### 4.2 (ii) Change what the caller fixes

**The change.** The caller fixes a **salted hash handle** `h = H(plane ‖ s)`
— the D7 shape already accepted for the zkVM line
(`ZK60_DECISIONS.md:222-232`) — and the proof's endpoint PCS commitment is
**prover-generated and fresh for every proof**. The proof additionally shows
that the fresh PCS commitment and `h` are commitments to the same plane. The
PCS root then never has any prior history *by construction*, so the whole
endpoint question moves from Game E to Game J, where the simulator issues its
own roots and **programs nothing** (`ZK60_MVP_JOINT_VIEW.md` §1.1, third
bullet).

**The cost is entirely in "showing they agree".** Counted:

*At model scale.* The plane is `512 tokens × 4096 = 2^21` words; as int16
that is 4,194,304 bytes = **65,536** 64-byte compressions per endpoint. The
project has **no bitwise machinery at all** — its arithmetisation is integer
arithmetic plus range lookups plus LogUp — so a hash must be built from
8-bit XOR/AND lookup tables and 32-bit carry facts. Per SHA-256 compression
that is, on a byte-lookup arithmetisation: 64 rounds × (Σ0, Σ1 at 8 lookups
each; Ch, Maj at ~12 each; ~5 modular additions at ~4 each) plus 48 message-
schedule rounds ≈ **4,000 lookups and ~2,500 committed words per
compression** [ESTIMATE, factor-2 band, NOT MEASURED].

| per-compression cost | lookups, both endpoints | of the pass's `H` (2.29e9) | committed words, both endpoints | of the pass's 9.78e9 |
|---|---|---|---|---|
| 2,000 / 1,250 (optimistic) | 2.62 × 10^8 | **+11.4 %** | 1.64 × 10^8 | +1.7 % |
| **4,000 / 2,500 (central)** | **5.24 × 10^8** | **+22.9 %** | **3.28 × 10^8** | **+3.4 %** |
| 8,000 / 5,000 (pessimistic) | 1.05 × 10^9 | +45.8 % | 6.55 × 10^8 | +6.7 % |

Turning that into seconds: on the **public** 58.40 s pass, helpers+commit H
is 5.555 s (9.5 %), so +22.9 % of helpers is **+1.3 s**, and +3.4 % of the
committed volume at 1.67 × 10^8 words/s is **+2.0 s** — call it **+3 to +4 s,
central; +2 to +8 s across the band** [COUNTED from the stated assumptions;
NOT MEASURED]. On a **private** profile, where helpers are 55 % of the time,
the same +22.9 % is **+12.6 % of the whole pass**.

**The honest verdict on those numbers.** Against 58.40 s, +3 to +8 s is
survivable. Against the **5-second target** (`MVP_STATUS.md:132-135`) it is
between 60 % and 160 % of the *entire* budget, paid on every proof, for a
statement that is bookkeeping rather than computation. It is the wrong place
to spend the last remaining headroom. And this is before the bit
decomposition of `2^21` words (another 3.4 × 10^7 bit cells per endpoint
minimum), before the new 8-bit table planes and their multiplicity planes,
and before the wire and verifier work.

*At the tiny shape* the same estimate gives 16 compressions per endpoint,
**128,000 extra lookups (+38 % of the tiny `H` = 1,326 × 256 = 339,456)** and
**80,000 extra committed words (+13 %)** [COUNTED]. Proportionally worse,
because the tiny proof's fixed overheads are small.

**Cheaper algebraic handles, worked and rejected.** The obvious question is
whether the caller's handle can be something the verifier checks with field
arithmetic instead of a hash.

- *A second Ligero/PCS commitment*: circular. It is the same object with the
  same problem, and it would have to be opened, which is case (c).
- *Pedersen*: the commitment itself is cheap to publish, but linking a
  Pedersen-committed vector to a Ligero-committed one is a cross-system
  argument (LegoSNARK-style CP-link) that needs the second commitment to be
  homomorphic. Ligero is not. This is a new proof system beside the existing
  one, plus elliptic-curve arithmetic in a verifier that today does
  Goldilocks only.
- *Ajtai/SIS over the same Goldilocks prime*, which looks attractive because
  the plane is **already short** (int8/int16) and the relation `t = A·x mod p`
  is **linear over `Fp`**, i.e. exactly the shape the existing sumcheck
  speaks. It fails on verifier cost: folding the `k` rows with a random `ρ`
  gives one inner product `⟨ρᵀA, x⟩`, and the verifier must evaluate the MLE
  of `A` at the sumcheck's point, which for a dense `k × 2^21` matrix is
  `O(k·2^21)` verifier work — non-succinct. Structuring `A` to be succinct
  (for instance "evaluate the plane's MLE at `k` fixed public points")
  **destroys binding for short vectors**: the multilinear polynomials
  vanishing at `k` fixed points form a space of dimension `2^21 − k`, which
  by pigeonhole contains short vectors, so two distinct short planes collide.
  I could not find a structured `A` that is both succinct for this verifier
  and SIS-binding, and I record that as a negative result rather than an
  exhausted search.
- *Delegating the link to the zkVM line*: a small RISC Zero program could
  prove `h = SHA-256(plane ‖ s)` **and** that the same plane produces the
  PCS root, but the second half means recomputing a coset NTT and 2,048
  BLAKE3 leaves inside the guest. At the tiny shape that is plausibly
  seconds; at `2^21` words and 65,536 leaves it is 10^10-class cycles, i.e.
  out (D2's arithmetic, `ZK60_DECISIONS.md:62-65`). It would also import D3
  (97 bits) and D4 (trusted setup) into the custom line's statement.

**Closes:** (a), (b) **and** (c) — because a fresh prover-generated root is
opened exactly once and has no history at all, and the caller's handle is
never opened. This is the only option that closes all three.
**Residual assumptions:** hiding of the salted hash handle (with D7's
qualifier (1): the handle hides only as well as the salt's secrecy and the
plane's own entropy, `ZK60_DECISIONS.md:242-247`); Game J's simulator, still
unbuilt; the field-layer obligations unchanged.
**Files:** a new endpoint-handle module beside `private_seam.rs`; a new hash
gadget with its tables in the layout (`hashline/src/zk.rs`), new lookup
domains and their LogUp helpers (`hashline/src/private_block/protocol.rs`,
`zkp-core/src/ffn_v3/*`), a new wire frame, a new profile tag. All additive
under D17.2, but it is a subsystem, not a patch.
**Measurement that would test it:** implement **one** SHA-256 (or BLAKE3)
compression in the existing lookup framework and count its committed rows and
lookup instances. That single number turns the factor-2 band above into an
answer, and it is a day of work, not a quarter.

### 4.3 (iii) Re-randomise per proof, with a link argument

**The change.** The owner publishes a fresh commitment to the same plane for
every consumer, plus an argument that they all commit to the same thing.

**Count the openings, which is what D12 rule 1 is about**
(`ZK60_DECISIONS.md:319-323`). Let the plane be consumed by `k` proofs, with
fresh commitments `C_1 … C_k`, each opened once by its own proof. A link
argument between two commitments opens **each side once** — that is what
`private_seam::prove` does (`private_seam.rs:335-339`, consuming both
planes).

| topology | openings of the caller's stable commitment `C_0` | openings of an interior `C_i` | verdict |
|---|---|---|---|
| star (every `C_i` linked to a master `C_0`) | 1 per link → **`k`** | 1 (proof) + 1 (link) = **2** | **violates D12 at `k ≥ 2`**, and the object that gets opened `k` times is precisely the caller's stable reference |
| path (`C_1—C_2—…—C_k`) | — | 1 (proof) + 2 (links) = **3** | violates D12 at `k ≥ 3`, and at `k = 2` the two endpoints are opened twice each |
| no links; each proof carries the caller's non-PCS handle | 0 (never opened) | **1** | this is closure (ii) |
| **no reuse: `k = 1` for every commitment** | — | **1** | satisfies D12 exactly |

So (iii) as usually imagined is **dominated**: either it collapses into (ii),
or it breaks D12 and hence §2.1.

**But the last row is reachable, and it is the useful part of (iii).** The
reason `k > 1` arises at all is that a forward pass is being assembled from
several separately-finished proofs. D12 rule 2 already forbids that inside a
block ("a block is one proof under one transcript with exactly two external
endpoints", `ZK60_DECISIONS.md:323-327`). Extended to the whole request, the
rule is: **one request, one transcript, exactly two external endpoints (the
model's hidden input and its hidden output); every intermediate activation
lives on a commitment the prover generates inside that one proof and opens
once.** Then `k = 1` everywhere and no link argument is needed.

**Is that architecture already there?** Partly, and this is encouraging: the
measured 58.40 s pass is produced by `hashline pass <layers> <t_rows>`,
documented as "the multi-layer pass, **one transcript**"
(`hashline/src/bin/hashline.rs:6`), which builds a single
`Transcript::new(b"hashline-pass")` at `:707` and then loops the layers at
`:714`. One transcript is a necessary condition, not a sufficient one — see
§6 item 2.

**What it costs.** In the `k = 1` architecture: nothing extra; it is the
architecture already measured. In the link-argument form: one extra seam
argument per link. At the tiny shape a seam proof is 416,456 bytes
(`ZK60_PRIVATE_SEAM.md`, validation section) against a much smaller FFN
receipt, so links are not cheap even before they break D12.

**Closes:** neither (a) nor (b) on its own. Its value is that it removes the
*reason* to want case (b) or (c), which is what makes closure (i) affordable.
**Residual assumptions:** unchanged. **Files:** none if the architecture is
already `k = 1`; the composition work D12 and D17 already schedule otherwise.
**Measurement:** confirm from a real 32-layer receipt that no commitment root
appears in two openings — a capture-level check, runnable today.

### 4.4 (iv) A zero-knowledge opening at the hash layer

Four sub-options, each worked to a verdict:

**(iv-a) Hide which columns are opened.** Impossible. The 256 indices are
derived from the transcript by `challenge_indices` (`pcs.rs:928` →
`transcript.rs:119-131`) and the verifier must recompute and check them; they
are public by construction and their publicity is what makes the proximity
test sound.

**(iv-b) A hiding/equivocal vector commitment instead of a plain Merkle
tree.** For a simulator to open a root it did not create *without*
programming, the commitment must be **equivocal** — a trapdoor (chameleon)
commitment whose trapdoor holder can open to anything. A transparent system
has no trapdoor holder, so this means introducing a structured reference
string. The project has accepted a trusted setup once already, for the zkVM
line's Groth16 layer (D4, `ZK60_DECISIONS.md:128-160`), so it is not
unthinkable — but note D4's own observation that a setup affects
*soundness*, not privacy, whereas here it would be the privacy that depends
on it. Cost: a new commitment scheme, a new verifier, **every frozen digest
in the repository moves**, and the GPU commit path is rewritten. And it does
**not** buy case (c): the two-opening recovery of §2.1 is a *field-layer*
attack on the mask budget, not a hash-layer one, so it survives any change of
tree. **Verdict: highest cost of the five, and it does not buy the case it
would be bought for.**

**(iv-c) Commit to the salts differently** (a salt tree, PRF-derived salts).
Moves the wrong way: the simulator wants *more* freedom in the salts, not
less. A PRF-derived salt is *worse*, because it is no longer independently
samplable.

**(iv-d) A Merkle cap** — publish the top `c` levels as the commitment
instead of one root. The top pair becomes public by construction, so the
simulator programs `2^c` points at the cap level instead of one; each is
fresh under exactly the analysis of §3.5, so the term becomes
`2^c·(q + …)·2^-256`, still negligible. It neither helps nor hurts case (a),
does nothing for (c), and on proof size it is worth about **1 %** on this
commitment, not the 29 % first recorded — a figure D10's correction already
fixed (`ZK60_DECISIONS.md:411-418`). **Verdict: not a privacy lever.**

**Closes:** (iv-b) would close (a) and (b) and not (c); the others close
nothing. **Files:** `zkp-core/src/pcs.rs`, `zkp-core/src/merkle.rs` — the
frozen core, so nothing here can be additive under D17.2; it is a new
profile from the ground up.

### 4.5 (v) A computational, programmable-random-oracle statement for case (a) only

This is (i) plus the written theorem. It is not an alternative to (i); it is
what (i) has to produce to be worth anything. Stated in §5.

**Closes:** (a), with (b) reduced to (a) by §3.7 and (c) excluded by the rule
of (i). **Residual assumptions:** the programmable ROM; salted-leaf hiding in
the standard model if anyone wants a standard-model reading (§3.4); D9's
`2^-72`; the LogUp collision; the PRG assumption on `ZkRng`; and the
composition of programming with Fiat–Shamir soundness (§3.8 item 1).
**Cost:** zero prover seconds, zero proof bytes, at both geometries.
**Files:** documents, one new test file, one ruling in `ZK60_DECISIONS.md`.

### 4.6 Side by side

| | closes (a) | closes (b) | closes (c) | prover cost, tiny | prover cost, 8B | proof bytes | frozen bytes move? | files |
|---|---|---|---|---|---|---|---|---|
| **(i)** restrict to case (a) | makes it the only case | vacuously (§3.7) | by rule + by the types | **0** | **0** | **0** | no | docs + 1 test |
| **(ii)** caller fixes a salted handle, PCS root fresh per proof | yes (Game J) | yes | **yes** | +13 % words, +38 % lookups [COUNTED from an ESTIMATE] | **+3 to +4 s central (+2 to +8 s band) on 58.40 s**; +12.6 % of a private pass | +hash witness rows | no (additive) | new handle module, hash gadget + tables, wire, verifier, new profile tag |
| **(iii)** re-randomise + link | no | no | no — **breaks D12** in star or path form | one seam per link (416 KB at tiny) | not costed; dominated | + a seam per link | no | dominated by (ii); its `k = 1` reading is free |
| **(iv-b)** equivocal/trapdoor vector commitment | yes | yes | **no** | new scheme | new scheme | new scheme | **yes, all of them** | `pcs.rs`, `merkle.rs`, GPU commit path |
| **(iv-d)** Merkle cap | neutral | neutral | no | ~0 | ~0 | −1 % | yes (format) | `pcs.rs` |
| **(v)** the written case-(a) theorem | yes, if proved | yes via §3.7 | no (needs (i)'s rule) | **0** | **0** | **0** | no | docs + 1 test |

## 5. Recommendation

### 5.1 In plain words, for the project owner

**Pursue (i) + (v) first: make "a sealed envelope is used exactly once and is
first published with the proof that uses it" a rule of the product, and then
write the theorem for that case.** It costs no proving time and no proof
bytes, the code already enforces it for every root this prover can prove
about, and the analysis in §3 says the remaining hash-layer risk in that case
is astronomically smaller than terms the project has already accepted
(`2^-175`-class against D9's accepted `2^-72`).

**What it gives up, said plainly.** The root stops being a permanent public
name for a hidden prompt or answer. A regulator can no longer point at two
different receipts and say "these used the same input" — unless the
application gives it a different way to do that. **That is a product
decision and it belongs to Victor, not to the security owner.** Two
cheap mitigations exist and neither is cryptography: a registry of
`(root, context)` pairs, and making the 32-byte `context` a per-request
nonce (the field already exists and is already absorbed).

**What it does not give up.** The multi-block story survives: §4.3 shows the
reason to want a reusable root is joining separately-finished proofs, and the
project's own D12 already forbids that inside a block. Extending the same
rule to the whole request — one transcript, two external endpoints, every
intermediate on a prover-generated commitment opened once — removes the need
entirely, and the 58.40 s pass is already built as one transcript.

**Keep (ii) alive as the fallback, and buy the one measurement that prices
it.** (ii) is the only option that closes all three cases, and its cost is
currently an estimate with a factor-of-two band. One SHA-256 compression
implemented in the existing lookup framework converts that band into a
number. Do that before deciding anything irreversible.

### 5.2 The theorem it would need

**Theorem (PROPOSED — NOT PROVED; no part of this is established in this
repository).** Fix the pinned tiny profile `pp` (`T32/d16/f16`,
`log_cols 8 / inv_rate 8 / Q 256`, endpoint shape `rows 7`). Model BLAKE3 as
a programmable random oracle `O`, shared by the commitment layer, the
transcript and the prover's RNG refill (one table, per O10 §1). Consider
Game E of §1.6 under these restrictions:

- **(R1) Honest commitment randomness, hidden from everyone.** Both endpoint
  roots are produced by `private_seam::prepare` on planes of the caller's
  choice with randomness from the honest distribution (`ZkRng::from_os`,
  `private_seam.rs:196`). That randomness — salts, pads, mask rows — is given
  to neither the simulator nor the distinguisher.
- **(R2) First publication.** No opening of either commitment, accepting or
  rejecting, has been published before the challenge receipt, and neither
  root's honest top pair has reached the distinguisher by any route.
- **(R3) Bounded, randomness-independent auxiliary input.** The
  distinguisher's auxiliary input is independent of the commitment
  randomness, and it makes at most `q` oracle queries in total, including the
  queries its own verification performs.

Then there is an efficient simulator `S`, given only `(pp, x, R_in, R_out,
aux)`, which makes **exactly two programming calls**, both at the top node of
an endpoint tree, such that no distinguisher's advantage exceeds

> `2·(q + 2·nn − 2)·2^-256  +  Δ_field`,

where `nn = 2048` and `Δ_field` is the field-layer term: D9's `2^-75` at this
shape, plus the LogUp collision term `(lookups + table rows)/2^128`, plus
whatever the discharge of U-3 contributes.

**Every clause of that statement is load-bearing.** Drop (R1) and the
distinguisher rebuilds the honest tree. Drop (R2) and §3.7's H3 row applies
and the theorem is false — that is the retraction of 2026-09-18. Drop the
programmability of `O` and §3.6 says no simulator exists at all.

### 5.3 The proof obligations, in order

| # | obligation | kind | who |
|---|---|---|---|
| **O1** | **The joint conditional field-view sampler exists** at the pinned profile: given fixed challenges, produce the columns, group vectors, proximity vectors, CFS rounds and terminals with the real joint law from the zero witness. This is U-3's substance plus O9 §7.2 | **written construction + proof**; the hard one | security owner, then external review |
| **O2** | The sequential-kernel lemma's **joint hypothesis** holds at the pinned profile for **every** non-refused challenge vector — not four captures (`ZK60_JOINT_VIEW_REVIEW_20260918.md:67-69`) | written proof (a generic-rank argument, or a verifier-side refusal of the degenerate set) | security owner |
| **O3** | The **hash-layer lemma of §3.5** written against the actual `pcs.rs` geometry with one-table overlap accounting. This is **U-6** of `ZK60_MVP_JOINT_VIEW.md` §4, and §3.3/§3.5 supply its arithmetic | short written proof | delegable |
| **O4** | **Salted-leaf hiding** named as an explicit assumption (§3.4), and the **domain invariant** asserted: `commitment_rows ∉ {5, 8}` for every reachable seam shape, and no commitment in a receipt has a 64-byte or 40-byte `hash_column` input | one sentence + **mechanical** | delegable |
| **O5** | **Composition of the two uses of `O`**: programming two node points for privacy must not invalidate the Fiat–Shamir soundness reduction that uses the same table (§3.8 item 1). Nothing in the record addresses this | written proof; **most likely external stopping point** | external reviewer |
| **O6** | **(R2) enforced as a system rule** with a code-level invariant, a test, and an operational control (registry or nonce context) | **mechanical** + a ruling | Codex + Victor |

### 5.4 What can be checked mechanically today, and what cannot

**Mechanically checkable now, on captured receipts with existing tools:**

- **O6.** A capture gate that refuses two retained receipts sharing an
  endpoint root or a context digest. The captures already carry both
  (`hashline/src/native_capture.rs:291`; the joint-view gate already reads
  them, `ZK60_NATIVE_JOINT_VIEW.md` §§1-2).
- **O4's invariant half.** Assert over every commitment in a receipt that
  `8·rows ∉ {40, 64}`, and over `SeamSpec`/`SeamSpecG` that
  `data_rows + MASK_ROWS ∉ {5, 8}`. Both are one-line checks and both are
  cheap negative controls (feed a synthetic 8-row commitment; the gate must
  fire).
- **O3's arithmetic.** Recompute §3.3's node counts from a real receipt's
  own 256 paths and check them against the closed form. Also assert the
  thing §3.3 predicts and no test currently checks: the **top pair is always
  revealed** (`A_{depth−1} = 2`), so a construction that assumed otherwise is
  refuted by the artefact.
- **The `k = 1` architecture claim of §4.3.** Check that no commitment root
  appears in two openings anywhere in a 32-layer receipt.

**Needs a written proof and an external reviewer:** O1, O2, O5. O1 and O2 are
the U-3 obligation the security owner already owns. **O5 is the one nobody
owns**, it is new in this document, and it should be added to the ledger
today.

### 5.5 The kill criterion

**Primary kill.** If **O1** is shown impossible at the pinned profile — that
is, if some functional of the joint view (including the nonlinear
cross-channel link `fin − c·g(ρ) = poly(terminals)`, which `ZK60_NATIVE_JOINT_VIEW.md`
§7 item 4 explicitly says the linear model cannot see) is shown to determine
a data direction, the way the two-opening recovery determines the plane in
case (c) — then case (a) is dead as well, and the custom line's P1 must move
to route 3 of §3.6: the endpoint openings become private witness
computations, i.e. the zkVM shape, and the custom line becomes a
throughput vehicle for a statement it cannot itself make private.

**Early warning, cheaper than the primary.** If the existing joint-view gate
ever reports a **nonzero disclosed data dimension on an endpoint role** once
the nonlinear channel is brought into the model — today it reports 0 on
Input and Output on all four captures
(`ZK60_NATIVE_JOINT_VIEW.md` §2.3, §9a) — stop and re-plan before writing any
of §5.2.

**Second kill, on the assumption rather than the algebra.** If **O5** cannot
be argued — if programming the oracle for privacy is shown to invalidate the
Fiat–Shamir soundness reduction on the same table — then route 1 of §3.6 is
closed for this system and only (ii) and the zkVM shape remain. That would
make the one-compression measurement of §4.2 urgent rather than prudent.

**What is explicitly not a kill.** A reviewer objecting that (R1) or (R3)
makes the notion weaker than textbook NIZK zero knowledge is right, and it
is not a kill: it is the established commit-and-prove notion (LNS Def 2.8,
checked against the primary source at
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:221-236`), and the honest response
is to write the weakening into the product claim, as D7 already does for the
zkVM line's three qualifiers.

## 6. What I did not read, and what I could not determine

**Could not determine, and it is load-bearing:**

1. **Whether the round-2 two-point simulator tool can be exercised here.**
   `scripts/zk60_root_simulator.py` and `tests/test_zk60_sequential_kernel.py`
   exist **only on branch `zk60-mvp-fable`**, not in the main tree (checked
   2026-09-19). `tests/test_zk60_root_history_boundary.py` loads the pinned
   delivery through `git show` and **skips** if the commit is unavailable
   (lines 24-35). So the "validated, three tests, 0.068 s" record is a
   statement about that branch, and I did not re-run anything.
2. **Whether the 32-layer pass is one proof with two external endpoints, or
   32 statements sharing one transcript.** The CLI is documented as "the
   multi-layer pass, one transcript" (`hashline/src/bin/hashline.rs:6`) and
   uses a single `Transcript::new(b"hashline-pass")` at `:707`, but the
   measured pass is **public IO** and I did not trace how the per-layer
   activations are joined. §4.3's conclusion — that the `k = 1` architecture
   is already there — depends on this and should be confirmed before it is
   relied on.
3. **The per-compression cost of a hash gadget in this arithmetisation.**
   §4.2's central figures (4,000 lookups, 2,500 committed words per SHA-256
   compression) are an **estimate with a factor-two band**, derived from the
   structure of SHA-256 against an 8-bit lookup arithmetisation. The project
   has no bitwise gadget to measure. The measurement is named in §4.2.
4. **Whether the D9 per-draw bias is `2^-64` or `2^-96`.** O10 F10.4 uses the
   first and derives a `2^-51.4` floor
   (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:135-142`); D9 as ruled uses the
   second (`ZK60_DECISIONS.md:372`). §1.7 records the discrepancy and the
   recomputation; I did not re-derive either figure from `rng.rs`.
5. **Whether a structured SIS matrix exists that is both succinct for this
   verifier and binding for short vectors.** §4.2 gives a pigeonhole argument
   against the one structure I tried (evaluation at fixed public points). It
   is not an exhausted search and I would not want it cited as impossibility.
6. **The exact endpoint geometry a widened profile will adopt.** §3.3 costs
   both readings (`log_cols 8 / inv_rate 8` keeping 2,048 leaves, and
   `log_cols 14 / inv_rate 4` giving 65,536), because
   `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §2.3 (P12) records the two-sources-of-
   truth hazard and the additive `SeamSpecG` fix without pinning which
   parameters it inherits. The privacy analysis is the same in both; the
   bytes differ by 18×.

**Read in full:** `ZK60_ENDPOINT_SIMULATION_MODEL.md`;
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`;
`ZK60_JOINT_VIEW_REVIEW_20260918.md`;
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md`;
`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md`; `ZK60_DECISIONS.md` entries D1,
D3–D5, D7–D12, D15, D17; `ZK60_MVP_JOINT_VIEW.md` §§0-7 (branch
`zk60-mvp-fable`); `ZK60_NATIVE_JOINT_VIEW.md` §§5, 7, 9a, 9b (branch
`zk60-native-jointview`); `zkp-core/src/pcs.rs` (the ZK half and
`hash_column`), `zkp-core/src/merkle.rs`, `zkp-core/src/transcript.rs`
(index sampling), `hashline/src/private_seam.rs`,
`hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_block/protocol.rs`
(the endpoint half), the headers of
`tests/test_zk60_root_history_boundary.py` and
`tests/test_zk60_budgeted_endpoint_boundary.py`.

**Read only in part:** `ZK60_ROUND23/24/25.md` (headings and the endpoint
sections); `ZK60_PRIVATE_SEAM.md` (budget and limitations);
`ZK60_OPUS_SEAM_REVIEW.md` (headings only);
`ZK60_FABLE_SECURITY_OBLIGATIONS.md` (the endpoint/root/salt/Merkle grep and
the PCS row); `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` and its disposition (the
geometry pins and the errata table's endpoint rows);
`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md` §B.2 and the option table;
`MVP_STATUS.md` §2. **Not read:** the attention construction memos, the
block construction memos and their checks, `ZK60_ROUND20/21/22.md`,
`ZK60_FABLE_TRANSCRIPT_REVIEW.md`, and the zkVM line beyond D3–D7.

**Nothing was built, run, tested, proved or benchmarked for this document.**
Every number labelled [COUNTED] is arithmetic from geometry or from a figure
cited to a measured source; every number labelled [ESTIMATE] is mine and is
banded. No file other than this one was created or modified.

*(draft complete)*
