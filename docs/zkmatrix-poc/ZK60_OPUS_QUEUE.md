# Opus 5 handoff — executable FFN repair

**Round 17 update:** O1–O4 are delivered and integrated through `2fb7e0a`.
Codex reran all 69 Opus tests and 57 legacy joint-analysis tests with no skips.
Their results are accepted within the stated capture/linear-model/inventory
scope; full privacy acceptance remains open. Read [round 17](ZK60_ROUND17.md)
first. The original dispatch below remains the definition of the completed
items. Do not rerun or rewrite those reports as new work.

## Current dispatch: O8 — analyze the new IO captures

**Codex round-20 update:** [round 20](ZK60_ROUND20.md) supplies a conditional
PCS pad/column and shared-M opening construction with checks on all four
captures. O8's task below is unchanged. In the remaining-obligations inventory,
reference this result with its fixed-challenge/Merkle exclusions; do not mark
the adaptive composition or caller-fixed endpoint simulation accepted.
The generic PCS lemma preserves aliases already respected by a message
difference, but does not establish O8's joint message premise for you.

**Round 19:** O7 (`4695503`, handoff `321ca22`) is integrated in `5193ee4`.
Codex verified all fourteen of its source hashes and added the source-pinned
schema-3 IO capture/replay in `1f0ff36`. Read [round 19](ZK60_ROUND19.md) and
`results/zk60_round19_validation.json` before starting. The source pin in that
record identifies the Rust capture producer; the recorded tool hashes identify
the final preflight. O1–O7 are delivered. Their original dispatches below are
historical, not requests to repeat them.

**O8, priority 0:** in your review worktree, add a separate
`scripts/zk60_opus_io_capture.py` adapter, corresponding parser/model tests,
`ZK60_OPUS_IO_ANALYSIS.md`, and a digest-bound result. Reuse the finite-field
and joint-rank routines of FA7/O2 without editing the archived tools or results.

1. Validate all four schema-3 captures and their sibling saved receipts/policy
   files against the round-19 manifest. Two are P1, two P3; coverage is
   `ffn-v3-mr1-fresh-io-poc-function-1`. The proof digest covers the complete
   HFFNIO `/2` frame. Missing files mean missing evidence, never permission to
   relabel old captures. Exact regeneration instructions/commands are in the
   evidence record. Review Codex's preflight and its real-capture controls.
2. Recompute every row/claim/group mapping. A has 702 rows and group counts
   `[7,3,1,1,6,1,1]`; input and output each have seven rows and one group.
   Preserve the X and z16 aliases in A. The endpoints' first two rows represent
   those same respective data planes, but their masks are separate. Endpoint
   rows 2/3 are terminal masks; 4/5/6 are random proximity rows, all recorded.
3. Apply the existing joint **message/terminal/proximity** model to every
   private commitment. Include every message coordinate and H's explicit
   zero-sum constraint. Check what is needed to combine the role results with
   shared data planes; do not simply report independent groups as a joint
   result. If the inherited model cannot express a needed alias or constraint,
   document that boundary for Codex rather than inventing an assumption.
4. Keep pad coordinates, encoded columns, CFS messages, repeated proofs and
   adaptive nonlinear composition explicitly outside that inherited model.
   The capture NOW contains these observations, including all eight CFS slots;
   their presence is not permission to claim they were analyzed. Produce a
   concrete inventory of the remaining cross-component obligations for Codex.
5. Retain the archived legacy disclosure as a positive control. Add negatives
   for a missing IO group/mask row, incorrect endpoint aliases, changed role
   order, altered source/profile, narrowed M columns and malformed fields.
   Bind results to capture, receipt, tool and source digests with exact commands
   and exits. Any unexpected disclosure is a finding, not a changed target.

Do not change Rust, design the private attention repair, or mark U-2/full
privacy closed. Codex owns integration and cryptographic judgment. The next
implementation after IO analysis remains private attention and a tiny block;
CL20 remains priority 3. O7 P3/P8 now have regression controls; its remaining
proposals and O5 F3/F5 remain bounded follow-ups.

## O7 — delivered implementation review (original dispatch)

**Round 18:** O5 (`e793fef`) and O6 (`d130de6`) are integrated in `ea3d886`.
Codex's replacement implementation is `137b109`, profile
`ffn-v3-mr1-fresh-io-poc/2`. It reserves eight slots in one FFN M and opens
M/W/A/H only after both equalities. O7's delivered review covers this source.
O1–O6 are completed review deliveries; do not repeat them as new work.

Codex verified all 32 O6 source hashes and reviewed its fifteen open items.
Read the [O6 disposition](ZK60_ROUND18_O6_REVIEW.md) and
[round 18](ZK60_ROUND18.md). `e8d4261` is the superseded `/1` draft;
never use its validation to describe `/2`. The checklist below is O7's scope,
not a claim that O6 reviewed either implementation.

Do not rerun O1–O4 as new evidence or relabel their captures as IO captures.
O4's generator reads live source while labelling its historical pin: reproduce
it only at that pin. The archive-integrity test now checks the recorded commit
instead of today's changed shared files. Its archived result is unchanged.

**O5 — independent wire-boundary review (delivered; original scope).** Review source `29d3436`,
specifically `zk_ffn_fresh_wire.rs`, `zk60_fresh_ffn.rs` and the process-check
script. Check the length calculation against the payload writer, including
all four maximum shift-16 tables; mode selection and expected roots must come
from the caller. Check canonical fields, column bounds, fixed round/group
counts, complete consumption, and the distinction between parse and verify.
Verify the CLI verification branch has no path into fixture/witness/proving
work. Report concrete findings with source references; any suggested Rust test
or fix stays a proposal for Codex. Preserve the existing proving transcript.
The already executed wire cases are in `results/zk60_round17_validation.json`;
identify any missing adversarial case rather than adding duplicate runners.

**O6 — pending FFN input/output seam inventory (delivered in `d130de6`).** Its
original scope was the requirements for binding X/z16 to independent endpoints,
before Codex's IO implementation existed. Inventory the exact source requirements from the fresh FFN owner,
`private_seam.rs`, and the existing private-block seam contract: committed row
offsets, input/output dimensions, required mask slots, transcript ownership,
when randomness becomes unavailable, and when each endpoint is consumed.
List the existing tests that would detect a wrong endpoint or second opening.
Do not add an arbitrary-opening API, publish partial proofs, reuse a commitment
across proof attempts, or invent a new masking construction. Any missing
construction argument goes to Codex as an unresolved item.

Concrete O7 checks at `137b109` (priority 0, read-only):

- `zk_ffn_fresh_io.rs`: both expected roots/context/scales enter the transcript
  before FFN challenges; endpoint policy is supplied by the caller. Verify the
  CLI saves it before `prepare` and never generates a witness in `verify`.
- `ZkLayoutV3::with_io`: four extra A rows are independently filled, do not
  alias existing masks, and bind the original `lay.x[0]` / `lay.z[0]` slices.
  Fixture A rows 702; IO pairs 698/699 and 700/701; seven A opening groups.
- `PendingProof::finish`: both seam slots are reserved in the eight-slot FFN M before the FFN challenges;
  each is `(10,2)` with a public zero claimed sum plus its mask. Check the
  verifier's terminal equation and the exact order of mask, W/A/H and endpoint
  openings. Each owner is consumed on success/failure and exposes no partial
  proof or arbitrary-opening API.
- The wrong-input/output tests fully recommit the wrong plane and use its real
  root as expected policy; refusal must come from the equality sumcheck.
  Include stale roots, role swaps, relabelled context/scales, missing endpoint,
  and attempted second finalization in the test inventory.
- List every NEW public observation across A, both endpoints and the expanded
  eight-slot FFN CFS commitment, including shared data-row aliases, full group/proximity
  vectors and sampled columns. The old FFN capture publication is disabled
  for this profile. There is no new joint IO capture/analysis result yet.

The real tests are in `zk_ffn_fresh_io_tests.rs`. The honest test now inspects
actual IO mask rows and CFS coefficient rows across two attempts per mode, and
asserts all eight M slots exist while every M/W/A/H opening is still empty.
Check allocation/consumption against that evidence. Fixed slots plus consuming
types may enforce the contract without a dynamic RoleSet; report actual missing
enforcement rather than requiring a particular type name.

Codex also addressed O5 F1 (public-W root mismatch during parse), F2 (slot-count
guard and derived M width), and F4 (matching in-memory/wire context bounds).
Verify these changes preserve honest old frames. Keep F3 (demo failure leaves
an incomplete artifact) and F5 (real proving at another shift tuple) listed as
bounded follow-ups. They do not imply verifier acceptance of an invalid proof.

For O7, deliver a concise `ZK60_OPUS_IO_REVIEW.md` with pass/fail/unresolved per item,
source references and proposed missing tests. This is implementation review;
do not derive a new privacy theorem or silently expand the inherited rank model.

Codex added O3 H/table/proximity negative controls and moved the table-coordinate
guard before repaired terminals are formed/used. Review those changes as part
of O7; O4's attention obligations remain open. The small CL20 helper move
`2dec4a9` is delivered but queued at
priority 3; do not restart the parked full extraction or merge it into the
performance branch. Its counts must be recomputed on the round-17 baseline
when integration is scheduled.

Victor has reassigned the pending Fable tasks to **Opus 5** because Fable usage
is exhausted. Fable's completed analyses remain credited to Fable. This document
is the current dispatch order; older Fable queues are historical context.

Codex owns cryptographic protocol changes, Rust proving/verifying code and final
integration. Work one bounded item at a time, report concrete evidence, and stop
that item on a mismatch rather than changing the expected result. Do not infer
whole-protocol zero knowledge from a passing test or a mask-site count.

## Start here

1. Read `CLAUDE.md`, `ZK60_ROUND16.md` and this queue. Implementation source:
   `b41d036c4c1eb1ed9272494815d742d0ccf29934`.
   Start from the published performance branch containing `046e965` or later,
   which includes the corrected validation-test expectation. Its proving code
   is identical to the capture source.
2. Inspect the existing review worktree's status before reusing it. Preserve
   local edits and committed Fable work. Keep review/tool edits in that sibling
   worktree; do not edit Codex's integration checkout.
3. Read `results/zk60_round16_captures.json` (capture stage complete). Actual capture
   files are under `/tmp/zk60-round16/captures`. Missing files mean that the
   capture check cannot run; do not fabricate observations or relabel legacy
   captures. Their digests and exact regeneration command are in the record.

## O1 — check the four capture files (first task, priority 0)

Read-only inputs: the capture record, its four capture JSON files, and
`hashline/src/zk_ffn_observation_json.rs`.

Write `results/zk60_opus_capture_preflight.json` and a short
`docs/zkmatrix-poc/ZK60_OPUS_REVIEW.md` section reporting each check:

- Exactly four files: two P1 and two P3; each SHA-256, byte length and proof
  digest match the manifest. Source is `b41d036...`, schema is 2, and coverage is
  **`ffn-v3-mr1-fresh-poc-function-1`**.
- Hash UTF-8 `layout_description` with SHA-256 and compare `layout_digest`.
  Check T32/d16/f16, shifts `[7,0,14,6]`, log_cols 8, inverse rate 8, Q/pads 256.
- P1 role order A/H; P3 role order W/A/H. A has 698 rows, H 1326, private W 11.
  Every row has exactly one row-role entry. Each role has two proximity rows.
- A group member counts `[7,3,1,1,6]`; H `[3,1,1,6,1]`; W `[2,1]`.
  Every group/proximity vector has 512 entries and every claim part has a
  symbolic coefficient tag. H records its zero-sum constraint.

Use exact Python integers, never floating-point field arithmetic. Report
pass/fail per check and the actual values. This is a capture-integrity check;
it is not a privacy verdict. Commit only the report/result, then proceed to O2.

## O2 — adapt the existing joint-observation analysis (priority 0, after O1)

Inputs: `scripts/zk60_fable_joint_capture.py`, its tests,
`scripts/zk60_fable_joint_rank.py`, FA7 review section 10, and the Rust repaired
layout/claim builders. Add a **separate** adapter
`scripts/zk60_opus_repaired_capture.py` and corresponding
`tests/test_zk60_opus_repaired_capture.py` so the archived legacy parser and its
digest-bound results keep their meaning.

First make the adapter accept only the exact experimental profile and fixed
shape above. Recompute expected rows, row roles and claim mappings from the
layout rules. Do not trust the capture's declared layout as the expected one.
Reject changed source/coverage/shape/roles, missing pair rows, and a legacy
capture with a repaired label. Add these negative tests before running the
analysis.

Then reuse Fable's existing finite-field/rank routines to analyze **all group
message coordinates and terminal values together**, retaining row aliases,
proximity message coordinates and the H zero-sum constraint. Validate the pad
and sampled-column structure, while preserving the original model's explicit
exclusions: pad/column leakage, CFS messages and repeated proofs need separate
arguments. Do not expand that model, redesign its mathematics or replace joint
analysis with individual-group rank checks. If adapting the existing model
requires a new mathematical assumption, document it for Codex and leave that
result unresolved.

Expected review target: A/W disclose zero base-field dimensions in the linear
model; H discloses only its public LogUp identity (two base dimensions), with
the residual identified explicitly. Preserve the legacy attack as a positive
control. A different result is a finding, not permission to edit an expectation.

Run:

```sh
python3 -m unittest discover -s tests -p 'test_zk60_fable_joint*.py' -v
python3 -m unittest discover -s tests -p 'test_zk60_opus_repaired_capture.py' -v
```

Deliver a result bound to input/tool/source digests, exact commands/exit codes,
and any excluded observation classes. No function-2, stable-weight or seam
coverage is claimed. Codex reviews before integration or privacy acceptance.

## O3 — audit the implemented mask schedule (priority 0)

Read-only audit of `hashline/src/zk_ffn_fresh_poc.rs` and the repaired branches
of `hashline/src/zk.rs`. Produce a table with one row for each of: A terminal
pairs, singleton table pairs, larger table blocks, H helper/zero-sum pairs,
A/H/W proximity pairs, P3 W terminal pairs and CFS challenges.

For each row, cite allocation, randomness fill, prover use, verifier use and
the regression test. Check the API accepts no caller seed/RNG/private reusable
commitment; private state does not escape; degeneracies discard without redraw.
Record untested or missing cases as gaps. Do not change Rust or certify the
full cryptographic argument. This supplies the bounded implementation portion
of FA8; Codex retains the overall judgment.

## O4 — attention inventory (priority 0, read-only)

Continue FA6 A1–A4 as a source inventory: list every attention CFS slot, private
terminal, mask allocation, proximity mask and proposed block seam endpoint.
Give exact file/line references and distinguish implemented sites from design
notes. Identify where a scalar base-field mask remains. Do not invent a repair
or mark a privacy blocker closed; hand the table to Codex.

## Lower priority

CL20 remains priority 3. Review the existing incomplete extraction and propose
one small pure helper to move with a byte/cross-verification check before moving
the full FFN prover. No broad refactor, dependency upgrade, storage redesign,
benchmark or new cryptographic construction is part of this dispatch.

Keep the existing two-thread/shared-lock rules. These review tasks need no GPU
or full-model proof. Report completed work and uncertainty plainly; historical
Fable findings retain their original attribution and scope.
