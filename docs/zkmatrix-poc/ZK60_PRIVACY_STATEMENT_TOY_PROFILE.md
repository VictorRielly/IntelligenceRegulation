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
> branch). *(CLOSED 2026-09-22 14:50: the gate's round 5 (`7ef86d6`) added
> the 20-file path-pin table — 32 distinct paths checked, 0 refusals on the
> integrator's new-tree bundle (round 9d) — and the two Cargo manifests were
> pinned on 2026-09-22 (round 9f), so the pin set of condition 7 is 31 files.
> Named residuals, still open: the private-attention profile's three files
> (`private_attention.rs`, `private_attention/wire.rs`,
> `private_attention/witness.rs`) appear in no pin table — two of the four
> toy captures of record are attention receipts, so this residual is real
> and is on the open list (gate ledger §R9g.8); `hashline/src/gpu/cuda.rs`
> is unpinned and off this profile's CPU path.)* *(CLOSED 2026-09-22 15:15,
> gate round 9h, `zk60-native-jointview` at `d5dbd33`: all three are on the
> attention path by call site — the profile root, the prover's witness, and
> the wire whose `validate` is the verifier's first statement — and are now
> pinned at their `4751b93` digests (`dfc02d91…`, `a35a468c…`, `795cf629…`;
> the lane's copies are byte-identical, so nothing is owed at integration)
> in a module both toy gates run before any analysis, refusing by name per
> file; failing-first shown on three one-line tampers; the record guard
> re-pinned; 217 tests and 42 guard tests green. Only `gpu/cuda.rs` remains
> unpinned, off this path.)* **What the re-run does not establish:** that the gates replay a
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

> **Re-examined against the complete hash-call table — note of 2026-09-21
> 05:03.** An independent agent re-examined step 5's argument for this
> profile, on the main branch at `4751b93`, against everything learned about
> the hashing during the night (`ZK60_TOY_ROUTE_A_REEXAMINATION.md`). **Verdict:
> unchanged, with clarifications.** Every figure of §4 reproduces from the code
> (327,052 draws call site by call site; the per-draw distance exactly 2^-96,
> never priced as an event; 64,768 denominators; the tree counts; the 4,000
> bound on absorbs, counted for the first time: 2,180 points); no accepted
> sentence relies on anything now known to be false. The nine clarifying
> sentences it recommended are in §9 below. None changes §2's sentence, any
> figure, or the substance of any condition.

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
- *(Added 2026-09-23, ruling P-2 of `ZK60_D22_PREREAD_SHAPED_SNAPSHOT.md`
  §9.)* The operator diagnostics `HL_PB_BASEFIELD` and `HL_PB_TIMING` print
  to the prover's own stdout, and the base-field census's counts depend on
  the hidden input. Their output from a run on a hidden input is
  **prover-private**: never retained in a capture bundle or a published log.
  Production runs leave both unset. This is an operating rule, not a change
  to what a receipt shows.
- *(Added 2026-09-23 16:52, the security owner carrying the privacy case's
  hypothesis O-2 — `ZK60_PRIVACY_CASE_FIRST_MVP.md` §1.2 item 1, §5.2, l.1633
  — which was never listed here; found by
  `ZK60_BLINDING_LAW_GR4_TOY_READING.md`.)* **The endpoint roots of an
  accepted receipt are never registered, republished or referred to by a
  later artifact.** The moment they are, the D8/D11 question applies to that
  receipt and this statement no longer covers it. This is a hypothesis of the
  statement, not a new condition on the code; the operating rule itself is
  Victor's to accept (proposed **D23**, `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`).
  Nothing in the argument or its figures changes.

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

**Replayed on the integrator's new-tree bundle — 2026-09-22 10:20.** The
integrator delivered a schema-3 capture of a receipt produced by the merged
tree's binary at `4751b93` on the CPU path (receipt digest `10b9d4be…`,
2,816,472 B, byte-identical to the new-tree receipt the re-pin record's §7 had
named as the one no bundle yet carried). The gate's round 9d
(`zk60-native-jointview` at `d837d50`; the record's new §8) replayed both toy
gates on it: **all 132 source pins the bundle carries equal the blobs at
`4751b93`, and its 32 pinned paths are all at digests this statement accepts;
no figure of record moved** (an A/B/N leaf comparison against the two block
captures of record: 0 moved at every stage; 28 channels with the same names
and grades; ranks 72 / 20 / 4 / 4; `M` disclosed 2 as predicted); **all ten
controls fire**; no pinned tool had to change. So §7's gap is closed: the
ports describe the merged tree's proofs, not only the old tree's. Three
things recorded: (a) this statement never named a digest for "the accepted
receipt" — it accepts a PROFILE, evidenced by four captures named by digest,
and the new bundle is a fifth, not one of the four; (b) the gate's manifest
cross-check silently skipped this bundle — a weakness in the gate, not in the
proof; *corrected 10:47 after the fix (round 9e, joint-view `025e1ac`): the
cause was the manifest's FILE NAME (`capture-validation.json`, where the gate
looked only for `validation.json`), and the single-record `accepted` form was
a second defect behind it (an unnamed error); the pinned tool now reads
either name and either form, refuses by name when the manifest is absent,
unreadable, malformed or disagrees with the bundle, and the three tool
hashes were re-pinned with the reason in the guard's record; the replay
repeated without any shim — the check fires on its own, 0 figures moved,
187 tests and the 12-test guard green;* (c) `M`'s pad margin on this receipt is 4
(252 distinct opened columns of 256 pads) — condition 2 holds, and a margin
of 0 would ALSO hold: at wide shapes all 256 draws are routinely distinct and
the pad rank check holds with equality (round 9 at 125M), so 0 is the generic
case, not a boundary. **This replay extends nothing**: same profile, CPU path,
the integration branch and the stage-36 observers still owe their own
condition-7 read.

## 9. Clarifications added after the re-examination of 2026-09-21

They say more exactly what the sections above already meant. Source:
`ZK60_TOY_ROUTE_A_REEXAMINATION.md` §7, accepted by the security owner as
written except where noted.

1. **§4, the 2^-112.0 row.** It is the one-world probability of the
   input-dependent refusal class (64,768 inverted denominators over |Fp2|). The
   distance a two-world comparison needs is twice the tighter count over
   distinct arguments, 2 × 768/p² = 2^-117.4, which 2^-112.0 bounds with 5.4
   bits to spare. The figure stays; its label is "a bound on the distance".
2. **§4, the sampler row.** Exactly 327,052 × 2^-96 = 2^-77.68. "2^-77.7" is a
   rounding, not an upper bound; "about" in §2 carries it. It is a *distance*
   and is never priced as an event (the rejection region is 2^-64 per draw).
3. **§4, a row that was missing.** A salted-leaf input equal to a Merkle node
   input (both 64 untagged bytes; ruling L-7): 2^-484.8, a distance.
4. **§5 condition 5, scope.** The condition is about the five commitments of
   this proof (`A`, `H`, `M` and the two endpoints). The Merkle trees over the
   *public* weights that the synthetic fixture builds are unsalted and contain
   no hidden value.
5. **§5 condition 6.** Three fresh reads of the operating system's entropy per
   proof, not one: the block's and one per endpoint. The assumption of §2 is
   that the three generators are jointly indistinguishable from uniform, which
   includes that separate reads are independent (already noted at 03:23).
6. **§5 condition 6, a weakness to know.** The two endpoint generators derive
   their keys from **byte-identical** public inputs; the two entropy reads are
   the only thing separating them. At this frozen profile there is no domain
   separation behind that assumption for two of the three generators. It
   cannot be changed here without moving frozen code; **for every unfrozen
   profile the endpoint's role and spec digest go into the generator's domain**
   (owed on the lane; it moves no verifier-visible byte).
7. **§5 condition 4.** The generator is not `Clone`: it cannot be forked, by
   the type system.
8. **§5 condition 7.** The pin set is what keeps the hash-layer argument's code
   conditions true: no commitment has 5 or 8 rows, and no transcript domain on
   this path has length 28 or 35 — properties of files that are all pinned.
9. **§3, step 5.** The lift uses uniqueness of the challenge *point* along the
   live transcript, not of the call: the prover's refusal replay re-issues
   1,027 of those points per proof with no absorb in between, which returns the
   value already sampled and enters no bound. The earlier phrase "challenge
   queries are unique unconditionally" is to be read that way.
10. **§4, the 2^-112.0 row again (added 2026-09-21 10:44; source: ruling V-3 of
    `ZK60_BLOCK125M_S28_DISPOSITION.md`, after an independent review of the
    lane's stage 28 re-derived it on the real path and exhibited the
    counterexample that fixes its wording).** The row is an over-estimate, and
    for a sharper reason than clarification 1 gives. On every attempt the
    prover inverts the WHOLE of each of the three public tables before
    multiplicities enter (`hashline/src/private_block/protocol.rs:353-357` on
    main, read by the security owner), and for every witness the constructors
    admit each witness-side denominator is one of those table denominators.
    So **whether an attempt is refused for a zero LogUp denominator is a
    deterministic function of the three public challenges and the three public
    tables** — the event that `alpha` equals one of at most 768 public field
    elements — and not of the hidden input. What does depend on the hidden
    input is only WHICH of two lines returns first (`:339-351` or `:357`); the
    two return the identical string, and no transcript absorb and no generator
    draw lies between the challenge draw (`:332`) and the second line (the
    next draw is `:362`), so a refused attempt leaves the same state and
    publishes nothing either way. **The figure stays 2^-112.0** — it binds
    nowhere and an over-estimate is safe; its label stays "a bound on the
    distance". The unqualified sentence — "a function of public values alone"
    for ANY witness — is false: a witness carrying a value no table carries
    makes the refusal depend on that value; such a witness is not admitted,
    cannot yield a verifying proof, and is outside §2's quantifier. The elapsed
    time of a refused attempt is a timing channel and is, like every timing
    channel, outside this statement (§6, by decisions D20 and D21).
11. **§4 the sampler row and §9 items 2, 5 and 9 — the counts are now MEASURED
    by an accessor, not only counted (added 2026-09-22 08:55).** With the
    integrator's authorisation of 07:25 that day, the lane
    (`zk60-private-block-125m` at `29cba9a`, stage 36) added read-only,
    test-only observers to the generator and the transcript — derived from
    their existing counter state, compiled only under a test feature, every
    added line behind a `cfg` gate (proved by a script), the release build and
    the frozen toy receipt unchanged. On the toy profile they measure
    **327,052 field draws per proof** — the figure of §4 and item 2 exactly —
    plus 12,288 salt draws, as 5,396,672 bytes on the block's generator (659
    refills) and 229,376 bytes on the two endpoint generators; **1,863 live
    squeezes** of the transcript; and the refusal replay re-issuing **1,027
    points in four calls, all accepted, consuming no generator bytes** (item
    9). Two honest limits: absorbs cannot be counted from existing state, so
    the 317 absorbs of the query table stay a count; and the two endpoint
    generators were measured on a replica of their two call sites (pinned by
    a source test), not on the endpoint objects themselves. The measurement
    is on the lane's tree, which differs from the pinned main tree by the
    integrator's later host changes and by this delta; **the six pinned
    files this delta moves (`zkp-core/src/rng.rs`, `transcript.rs`, both
    `Cargo.toml`, `private_block/protocol.rs`, `private_block.rs`) will be
    re-read by the security owner at integration, and this statement's pin
    set updated then — until then it pins main as before.** Condition 6's
    "three fresh reads" is asserted by the same test. *Pre-read done
    2026-09-22 11:42 (`ZK60_D22_CONDITION7_PREREAD_STAGE36.md` on the lane's
    review branch): every condition holds against the delta; the production
    residue of the four moved source files is byte-identical by an
    independent method and the release graph resolves the core crate with no
    feature and no observer symbol. Two things it adds: the two `Cargo.toml` files now decide whether
    the observers compile and were pinned by nothing — **since 12:14 they are
    pinned** (gate round 9f, `zk60-native-jointview` at `442634b`) at their
    main digests (`zkp-core/Cargo.toml` `b9038a52…`, `hashline/Cargo.toml`
    `eaba50ec…`), in a check both toy gates run before any analysis, together
    with a CONTENT assertion that refuses by name any manifest putting a
    feature in `default` or in `[dependencies]`, or enabling the observers
    anywhere but a dev-dependency — so a future manifest that ships the
    observers is refused even at a re-pinned digest (failing-first evidence
    kept; the record guard re-pinned; 204 tests and 29 guard tests green);
    and the exclusion rested on Cargo's resolver v2 being implied by the
    edition — `resolver = "2"` is now written explicitly in both manifests.
    The pin set of §5 condition 7 is therefore 31 files *(corrected 15:15
    the same day: counted over the tables by machine it is 37 — 35 Rust
    files and the two manifests; "31" was the 29 block-path files plus the
    manifests and omitted the attention profile's `argument.rs`,
    `layout.rs`, `protocol.rs`, pinned since rounds 1 and 5, and the three
    attention files pinned by round 9h)*. Thirteen of
    the pinned paths already differ between the lane's base and the pinned
    main tree, so the re-pin is against the integrator's merged tree, never
    against the lane.*
