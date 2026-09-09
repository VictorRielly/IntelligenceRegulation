# Opus 5 handoff — executable FFN repair

**Round 17 update:** O1–O4 are delivered and integrated through `2fb7e0a`.
Codex reran all 69 Opus tests and 57 legacy joint-analysis tests with no skips.
Their results are accepted within the stated capture/linear-model/inventory
scope; full privacy acceptance remains open. Read [round 17](ZK60_ROUND17.md)
first. The original dispatch below remains the definition of the completed
items. Do not rerun or rewrite those reports as new work.

## Current dispatch: O5, then O6

**O5 — independent wire-boundary review (priority 0).** Review source `29d3436`,
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

**O6 — pending FFN input/output seam review (priority 0, read-only).** Codex's
next implementation binds the repaired FFN's X and z16 to independently supplied
endpoints. Inventory the exact source requirements from the fresh FFN owner,
`private_seam.rs`, and the existing private-block seam contract: committed row
offsets, input/output dimensions, required mask slots, transcript ownership,
when randomness becomes unavailable, and when each endpoint is consumed.
List the existing tests that would detect a wrong endpoint or second opening.
Do not add an arbitrary-opening API, publish partial proofs, reuse a commitment
across proof attempts, or invent a new masking construction. Any missing
construction argument goes to Codex as an unresolved item.

O3's H/table/proximity test gaps and O4's attention obligations remain visible
to Codex. The small CL20 helper move `2dec4a9` is delivered but queued at
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
