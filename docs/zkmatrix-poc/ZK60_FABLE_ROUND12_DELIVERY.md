# Fable delivery, 2026-09-08 — FA6–FA9, CL21 and the next CL20 boundaries

This is the Fable-side record of the round-11/12 queue
([ZK60_FABLE_QUEUE.md](ZK60_FABLE_QUEUE.md)): what was delivered on which
lane, how each delivery was validated, what it establishes, and what it
leaves open. Codex owns the integration into the performance branch; nothing
here is merged. The machine-readable statuses are in
[zk60_fable_tasks.json](zk60_fable_tasks.json) (`fable_round12_delivery` and
each task's `result`).

Base for every lane: `cfa46f6` (the round-11 integrator tip when the session
started). Codex moved the branch to `972da4e`, `ccc6f26` and `a94ce2c`
(rounds 12–14) while the lanes ran; the review lane merged all three, the CL21
lane keeps its validated tip, and the CL20 lane is merging `a94ce2c` as part
of the decoder correction (see "Integration notes").

## The lanes and their tips

| Lane (branch, worktree) | Commits | Validation at the tip |
|---|---|---|
| `zk60-fable-review` (`wt-zk60-fa`, pushed) | FA6 `e83a4ca`, FA7 `f6d8557`, FA3 ledger pointers `018d506`, merge `972da4e` = `ed478da`, FA8 `9d373e0`, merge `ccc6f26` = `641aa2d`, merge `a94ce2c` = `74f3b06`, handoff `7624bcb`, FA9 merged from `zk60-fable-fa9` (`9620f97`, `e7f9176`, `6673209`) | the four Fable Python suites together: 94 tests OK (FA2/FA3 34, FA6 21, FA7 23, FA8 16); FA6's Rust cross-check 2/2; FA9's six Rust adversarial tests, exit 0 on the merged source |
| `zk60-cl1` (`wt-zk60-cl1`, pushed) | CL21 `d4f0758` (code), `e18994c` (evidence) | gates tests 86, preflight tests 92; suite-v4 floors run GREEN 23/23 on the RTX 4070 |
| `zk60-cl20-core` (`wt-zk60-cl20`) | `ee775be`, `76ee275` (both integrated by Codex in `b044e20`), merge `972da4e` = `f61ee77`, `f8d40a7` (held by Codex for C20-R1–R3; correction in flight) | core 28/28; hashline 169/169 + 2 compile-fail checks; GPU feature `cargo check` clean; the four frozen CPU proofs byte-identical |

## What each task delivered

### FA6 — the CFS masking channel (blocker B1)

The question was whether the sumcheck round messages, which are products of
data polynomials and therefore outside the linear rank model, are hidden by
the CFS masks the way the code assumes. The review
([ZK60_FABLE_CFS_CHANNEL.md](ZK60_FABLE_CFS_CHANNEL.md)) writes the argument
against the actual `CfsMask`, `mask_open` and `mask_functionals` code and
checks it with exact arithmetic: for every masked slot (v2's six, v3's six
plus the predicate, the P3 matmul extension rounds and FA3's two seam slots),
the map from mask coefficients to the verifier's view is surjective onto the
consistency subspace, so the masked messages are uniform given the public
constants and the masked terminal values. The mask commitment M reveals
exactly the combined value the verifier is entitled to. Twenty-two negative
controls show the leak whenever a rule is broken (zero challenge, missing
constant, over-degree extension round, mask reuse, second opening). Verdict:
B1 closed for this construction; FA3's seam slots approved as specified; the
approved mask specification is stated in one paragraph. Two one-line
hardenings go to the source owner (assert equal lengths in `extension`; abort
on a zero challenge). One gap noticed: the attention-side seam terminals are
in no inventory yet.

### FA7 — the captured observations, jointly

Codex's round-11 captures gave the first real coefficients. FA7
([ZK60_FABLE_CAPTURE_REVIEW.md](ZK60_FABLE_CAPTURE_REVIEW.md)) parses them
digest-bound, reproduces Codex's 30 per-column numbers exactly, and then
builds the full-width joint system (every group-vector coordinate, the
proximity vector, every individual terminal value, H's zero-sum constraint,
shared row identities). Jointly the legacy profile discloses more than the
per-column view: A discloses 2n + 4 base-field functionals (the two rho-group
terminals add four), P3 W discloses 2n + 2, and H discloses exactly the public
LogUp identity and nothing else. Per plane, the tiny X and h16 rows and the
whole T32 Wd plane are determined from one proof, confirming Codex's
disclosure with the same actual coefficients (recovered-vector digests agree
across independent proofs; values never leave the tool). The six fresh
final-only captures are now hash-bound for the first time. Section 10 is the
schema Codex needs for the repaired-profile and predicate captures.

### FA8 — the transcript simulator and repeated proofs (B2–B4)

FA8 ([ZK60_FABLE_TRANSCRIPT_REVIEW.md](ZK60_FABLE_TRANSCRIPT_REVIEW.md))
writes the simulator FA3 asked for: commit the mask matrix first, program the
random oracle only at the sumcheck round challenges, commit zero-data A/H/W
with fresh pairs, pads and salts, run the honest openings, and sample each
slot's rounds on the fibre FA6 identified. Three facts beyond FA6/FA3 carry
it and are pinned by an exact tool. The single-proof distance is derived, not
inherited, and finds that the field-sampling bias is 2^-96, tighter than the
source's 2^-64 comment. B3 (ranges) closes for the repaired profile as a
corollary, and the legacy contrast is quantified: at T32 an int8 enumeration
turns one disclosed functional per column into both X rows. B4 splits: fresh
commitments compose as independent samples; FA4's budgeted stable W gets the
k-transcript simulator (H1) and closes only under three enforcement
conditions, of which Codex's new slot journal covers the public-state half.
The disposition table covers 22 channels over five profiles. The block
profile stays blocked on the attention side (A1–A4). One security finding:
the explicit-seed configuration path is reachable in production and a 64-bit
seed is brute-forceable from a single proof's mask root — it must be
test-only or refused (S1).

### FA9 — arithmetic and registrar obligations

Delivered; see "FA9 outcome" below, section 9 of
[ZK60_FABLE_SECURITY_OBLIGATIONS.md](ZK60_FABLE_SECURITY_OBLIGATIONS.md) and
`results/zk60_fable_fa9_review.json`.

### CL21 — the extracted core in the validation provenance

The floors manifest and the preflight now record both crates' tree ids at
HEAD, both dirty deltas, both lockfile hashes and the core's presence; a
dirty or missing core, a missing identity, or a mismatched dependency
identity refuses qualification, while archived v1–v3 manifests keep their
meaning. Suite v4 adds two explicit core cases (the core's 19 tests and the
public sumcheck example) with tied expectations. The v4 floors run at
`d4f0758` is GREEN, 23 of 23 cases, with the manifest bound to that HEAD and
the GPU binary (`results/cl21_floors_v4/`).

### CL20 — PCS and typed FFN pieces into zkp-core

The Ligero PCS moved into the core behind a narrow backend seam; hashline's
`pcs.rs` is an 84-line adapter and the CUDA switch lives in the GPU module.
The v3 table registry and the typed statement, parameters, layout and proof
followed, with a bounded shape-directed decoder that rejects truncation,
trailing bytes and non-canonical field elements. All four frozen CPU proofs
are byte-identical at both steps and the GPU feature still compiles. Codex
reviewed the lane locally and integrated the PCS step; it holds the typed
decoder commit for three reproduced robustness findings
([ZK60_CL20_ROUND14_REVIEW.md](ZK60_CL20_ROUND14_REVIEW.md)): an unbounded
query-count allocation, an unchecked shift in shape construction, and wrong
group counts for an honest one-column legacy proof. The correction, with a
regression per finding, is being made on the same lane after merging
`a94ce2c`. The prover and verifier (step 2c), the old/new prover parity test
and the tiny example remain open; the migration ledger names the exact next
step and its blockers.

## What this does and does not establish

Closed for the repaired FFN profile `ffn-v3-mr1` as designed by FA3: the CFS
channel (B1), the transcript simulator and conditioning (B2), ranges given
simulation (B3), and cross-proof composition for fresh commitments (B4/F1).
Closed for the stable P3 W only under enforcement of consumption. Not closed:
the attention side of a private block, the repaired profile's implementation
and its captures, the enforcement items E1–E3, the changed-rate bound (FA5),
and the arithmetic/registrar fixes FA9 proposes (Codex applies). No repaired
FFN proof, private block, private two-block proof, P3 stable weights,
deployment or throughput claim follows from this delivery.

## Integration notes for Codex

- CL20 raises the core test count (19 → 22 already integrated, 28 on the
  lane, more with the C20 regressions). Integrating it means cutting floors
  suite v5 in the gates helper with the new expectation; the v4 `core_tests`
  case refuses by design.
- Suite v4's `cargo_test_cpu` case covers hashline's default features only;
  the optional `stable-weight-storage` tests Codex added in rounds 13–14 are
  feature-enabled coverage and must be recorded as a separate case when v5 is
  cut, not folded into the default-suite claim (Codex's round-13/14 handoff).
- The CL21 lane was validated at its tip (`cfa46f6` + CL21) and is not merged
  with the later Codex commits; the review lane is merged through `a94ce2c`
  and is clean.
- S1 (FA8) is a production security finding for `zk.rs`'s configuration
  path; FA6's two hardenings and FA9's R09/R10/R31 diffs are Codex-owned edits
  with tests that pin the flip.
- FA7 §10 is the capture schema the repaired-profile and predicate proofs
  must export; FA3 acceptance test P3 runs FA7's tool on it.

## FA9 outcome

Lane `zk60-fable-fa9` (commits `9620f97` tests and diffs, `e7f9176` merge of
`a94ce2c`, `6673209` doc and review record), merged into the review lane. Six
adversarial tests in `hashline/tests/zk60_fable_arith.rs` pass on the merged
source; Codex-owned files were patched only inside one local verification run
and restored byte-identical before any commit.

- **R09, the norm alias.** Built exactly per FA5's derivation and replayed
  through every verifier relation. In the fixed profile it is excluded, and the
  test shows by which check (the two-limb remainder range; the margin is
  recomputed). In a wider profile (three limbs) the verifier accepts an
  all-zero norm row where the honest row is nonzero, pinned as a known gap.
  The proposed fix (D as two 16-bit limbs plus a pin) flips that test to a
  refusal while the honest fixture still verifies. It changes frozen proof
  bytes at the fixed profile, so it must ship as a new statement label with
  the wire and receipt counts bumped and the fixtures re-frozen. FA5's own
  suggestion of a single 16-bit lookup on D is corrected: D reaches 2^17.
- **R10, the remainder width.** The advertised width is a transcript label;
  the proof enforces the limb multiple. Pinned by test; the fix is a named
  contract guard and documentation, no byte change.
- **R31, the registrar premise.** An approved root over an out-of-range weight
  word is accepted and a proof against it verifies, pinned by test; the fix is
  a by-construction registration from the actual public weights, no byte
  change, with the range-lookup alternative costed.
- **R32.** Codex's fix (`42471f0`) is confirmed on the merged source, with
  extra neighbouring cases the Codex regression does not cover; no residual
  gap in the typed verifier. One precision note on the wire gate's bound on
  opening group vectors.

The exact patches Codex must apply, with their byte-change status, are in
section 9 of the obligations document and the task record.
