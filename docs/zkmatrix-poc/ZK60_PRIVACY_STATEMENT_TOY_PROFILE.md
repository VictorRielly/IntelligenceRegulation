# Privacy statement for the toy private-block profile — IN FORCE (register D22)

Drafted by the interactive Claude Fable 5.1 session (the security owner) at
05:32 on 2026-09-20; **brought into force at 13:46 the same day**, after the
project owner accepted D19, D20 and D21 at 13:45 (console: "Yes on D19 D20 and
D21").

| Status | **IN FORCE for ONE artifact, as register entry D22.** The security owner accepts the privacy of the toy private-block profile in the model the project owner accepted, with the residuals, conditions and limits written below. It is an argument each of whose steps was drafted by one delegated agent and survived an attack by another told to assume it wrong; **it is not a proof re-derived by the security owner, and it lapses for any code that changes one of the seven conditions of §5.** Nothing outside §1's scope may be described as private on the strength of this page. |
|---|---|

> **Condition 7 is in play — note of 2026-09-20 21:28.** At 20:52 the
> integrator committed its host/private work to the main branch (`4751b93`). It
> changes two Rust files the gate of step 3 pins, `hashline/src/pcs.rs` (47
> lines) and `hashline/src/zk.rs` (395 lines), besides files off this
> profile's path.
> The integrator states that the private opening, masks, salts, row spans and
> transcript are byte-identical and that the toy's proof gates pass; **that is
> its statement, not yet my reading.** By this page's own condition 7, **for
> the tree at and after `4751b93`, step 3 is suspended until the changed
> functions on this profile's path have been re-read and the pins moved with
> both hashes kept, and the gate re-run on the four captures.** The acceptance
> stands unchanged for the tree it was argued on (main before `4751b93`). The
> re-read is queued behind the run gate's current round.

> **The suspension is lifted — note of 2026-09-20 22:06.** The re-read is done
> (`ZK60_NATIVE_D22_REPIN_4751B93.md` on `zk60-native-jointview`, `8a3b3f1`,
> pushed). **No hunk of `4751b93` changes behaviour on this profile's path, and
> none touches the order of randomness draws or a pooled buffer on it.**
> `hashline/src/zk.rs` gained 380 lines and lost 15, every hunk at or below
> line 2277, in the feed-forward layer prover; lines 1–2276 — where the masking
> commitment, its opening and verification, the claim audit and the refusal
> rules live — are untouched (I checked the hunk positions and the line counts
> myself; the function-by-function reading of the eighteen items this profile
> reaches or the gates port is the delegated agent's). The new buffer pool was
> read as a privacy question: it does hand a caller a buffer still holding the
> previous holder's numbers, **but all its sites are inside the feed-forward
> layer prover, and no file of the private block, the private attention or the
> frozen seam names any of them.** One pin of fourteen moved
> (`hashline/src/zk.rs`, both digests kept, a third still refused); the gates
> were re-run on the four captures and every figure of record is unchanged
> (11 constructed, 2 derived, 8 argued, 7 open; ten controls firing).
> **D22 therefore covers main at `4751b93`.**
> **Two corrections to my 21:28 note, and one gap.** `hashline/src/pcs.rs` is
> *not* pinned — the pinned `pcs.rs` is `zkp-core`'s, which `4751b93` does not
> touch; the hashline file's change is 47 added lines, none removed, one new
> function with no caller on this path. **The gap:** `hashline/src/pcs.rs`,
> `private_block.rs`, and the hashline-side `merkle`, `transcript`, `field` and
> `ntt` files are on this profile's path and pinned by nothing, so condition 7
> was narrower in practice than in words. **Ruling: the pin set is extended to
> every file on the path**, re-exports included (owed on the joint-view
> branch). **What the re-run does not establish:** that the gates replay a
> receipt the new binaries made — the integrator proved this profile on the
> new tree, but no bundle from it exists in the gate's schema.

> **The pin gap is closed — note of 2026-09-20 23:57.** The path was
> established from the blobs at `4751b93`: 29 Rust files, of which 9 were
> pinned and **20 were pinned by nothing**. All 20 were read and pinned
> (`zk60-native-jointview` at `6667aba`, pushed), none refused as inconsistent
> with a port; a changed byte in any of them now stops the gate by name. Every
> figure of record is unchanged. Condition 7 now means in practice what it
> says in words. Named residual: three files of the separate private-attention
> profile, which two of the four captures reach and this statement does not
> cover.

> **Two clarifications of scope and of one assumption — note of 2026-09-21
> 03:23** (rulings J-2 and J-3 of
> `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md`). Neither changes the
> statement's sentence or any number; both say more exactly what it covers.
> **(1) This statement covers the profile on the CPU path.** At this untagged
> profile the commitment code still offers its column hashing to the
> accelerator: a build with the `gpu-cuda` feature and `HL_GPU=1` at run time
> sends it to two hand-written CUDA BLAKE3 kernels, and blinding rows and pads
> to device and pinned host memory. All the evidence behind this statement —
> the four captures and both gates — was produced on the CPU (the capture
> runner strips every `HL_*` variable). **That configuration is not covered
> until the kernels' agreement with the CPU function is cited to a gate by
> name and the lifetime of those buffers has been read.** It joins §1's "not
> in scope". **(2) "The prover's randomness generator" in §2 means the three
> generators of a block proof jointly** — the block's and the two endpoints' —
> each seeded by its own read of the operating system's entropy. The
> assumption is that their joint output is indistinguishable from uniform,
> which includes that **separate operating-system entropy reads are
> independent**. That was always what the argument used; it is now said.

**Changes since the 05:32 draft** (nothing in the argument changed): D19–D21
are decisions, no longer proposals; the gate's record of record was found
stale in one file and is being refreshed (its numbers were right); the run
gate for multi-block runs exists and passes at a development shape, which is
**outside** this statement's scope.

## 1. Scope — exactly one artifact

The profile `hashline-zk-mr1/private-block-t32-poc/1`: one complete transformer
block at 32 tokens, width 16, hidden 16, on **public synthetic weights**, with
hidden input, hidden output and hidden activations, the prover sealing its own
endpoints at proof time (decision D18, option A). Receipt 2,816,472 bytes.

**Not in scope, each owing the whole argument again at its own layout:** the
toy private-attention profile taken alone (the gates cover it; the composition
and hash-layer memos were written for the block); the development rung and the
125M profile (different matrices, padding, grouped heads, a pad-zero term, a
generalised endpoint, a separating hash tag); any feed-forward-only private
pass; any proof on real weights; sealing in advance by a third party (decisions
D8 and D11 bind that configuration and are untouched); the zkVM line.

## 2. The statement

> In the random-oracle model for BLAKE3 (decision D19), and assuming the
> prover's randomness generator's output stream is indistinguishable from
> uniform, a verifier who receives an **accepted** receipt of this profile and
> makes at most `q ≤ 2^128` hash queries sees a view whose distribution is
> within **about 2^-77.7** of a distribution that does not depend on the
> hidden input, output or activations — per proof. Whether the prover
> **refuses** is, up to 2^-112, a function of the verifier-visible random
> challenges alone and carries no information about the hidden data.

## 3. What it rests on

| # | Step | State | Where |
|---|---|---|---|
| 1 | The all-zero hidden input is admissible, proves and verifies | measured (Rust test, pinned boundaries) | `zero_witness_tests.rs`, lane `zk60-private-block-125m` |
| 2 | Per commitment, the linear view discloses nothing on any run the prover does not refuse | core accepted; reduction includes the individual claims | `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md` |
| 3 | The gate constructs blinding values reproducing each captured view under the all-zero input; joint figure computed; masking commitment closed | measured on four real receipts; 11 channels constructed, 7 open by design | `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md`, step-3 blocks |
| 4 | For fixed challenges the *joint* law of all published field values is input-free (uniform-blinding idealisation) | core accepted; its one supplied step independently reviewed and corrected | `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, `ZK60_TERMINAL_SURJECTION_REVIEW.md` |
| 5 | The hash layer adds nothing, and the fixed-challenge theorem lifts to the hashed protocol | core accepted, in the model of D19 | `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` |

Every step was drafted by one delegated agent and attacked by another
instructed to assume it wrong; I ruled on each check. **I have not re-derived
the mathematics myself, and the Python ports of Rust code used by step 3 are
equal to the Rust by one agent's reading each.** Those two sentences are part
of the statement.

## 4. Residuals, listed and sized

| Term | Size | Kind |
|---|---|---|
| The sampler's reduction bias (decision D9, accepted) | 2^-77.7 per proof; grows linearly — about 2^-57.7 at a million proofs | distance |
| Zero lookup denominator (the one input-dependent refusal class of eighteen) | 2^-112.0 | distance |
| Guessing an unopened leaf's salt | `q · 2^-242.4` | distance |
| Oracle collisions; the 64-byte absorb overlapping the node format | 2^-229.8; 2^-233.1; 2^-241.4 | distance |
| Challenge pre-query | `q · 2^-244.0` | distance |
| The generator | the named assumption; inside the model alternatively `6q · 2^-256` (labelled ASSUMED — it needs a stronger property of the hash) | assumption |
| Refusal on degenerate challenges | 2^-62.0 (four base-field determinants, `4/p`) | **liveness, not distance** |

## 5. Conditions — if any of these changes, this statement lapses for the changed code

1. One reserved mask pair per claim site, with weights of the exact shape
   `(cm, cm·U)`; the single deliberate exception is the helper commitment's
   shared zero-sum pair. **`audit_claims`' pair-exclusivity check is the whole
   defence against a shared pair** — the privacy tools' reduction cannot see
   one.
2. The pad count equals the number of opened columns, per row, always.
3. `d + 1` values published per sumcheck round; the exact-row-span assertions
   in the commitment code; the refusal on a zero mask challenge; the declared
   order of the mask functionals (machine-checked, 34 of 34).
4. One opening per commitment; a refusal is terminal (no retry with the same
   endpoints — enforced by the type system).
5. Every Merkle leaf is salted with 32 fresh bytes; no unsalted column digest
   is ever published, logged or captured.
6. Fresh operating-system randomness per proof; no seeded configuration on
   this profile's path.
7. The source pins of the Python gates: a change to any pinned Rust file
   suspends step 3 until it is re-read and re-pinned.

## 6. Out of scope by ruling (decisions D20, D21), and operating rules

- Timing, memory and power.
- A receipt the prover's own final check rejected is **never transmitted**.
- A retained capture bundle counts as **publishing**: nothing computed from a
  hidden input is ever added to one.
- A refusal reason is never shown to anyone not entitled to the input.

## 7. What must not be claimed, even when this is in force

That the fast line is private "at model scale"; that the 125M block is
private; that real weights or real data have been proved privately; that
sealing in advance is covered; that soundness was reviewed here (it was not:
one flagged ambiguity — Merkle node and salted-leaf inputs are both 64 untagged
bytes — is recorded for the integrator, unchecked); that this is a proof in the
mathematician's sense rather than an argument each of whose steps survived one
independent attack.

## 8. How it came into force, and what reopens it

Victor accepted D19, D20 and D21 on 2026-09-20 at 13:45
(`ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`); the register gained the acceptance as
entry D22 at 13:46; `MVP_STATUS.md` gained one sentence — for this profile and
no other.

**It is reopened by:** a change to any of the seven conditions of §5; a
finding against any of the five steps of §3 (each step's check lists what it
could not verify — those lists are where to look first); a published weakness
in BLAKE3 used as a random function, or in the generator; an auditor who
requires the sampler residual removed (then decision D9's one-line change and
a re-freeze); or an independent reader of the Python ports finding that one
differs from the Rust it claims to port.

**What it obliges next, under D19:** every NEW profile — the development
rungs, the 125M block, the multi-block run — gets a separating hash tag, and
owes this whole argument again at its own layout before anything is said
about its privacy.
