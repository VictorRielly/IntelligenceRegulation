# Round 22 — interruption recovery and O8 integration

The first PoC remains P1: private input, output and intermediate activations,
with public weights allowed. The full version also hides weights (P3).
[The requirements](ZK60_PRIVACY_REQUIREMENTS.md) have not changed.

## What stopped, and what survived

The prior session's last message said it was committing round 21. Its 47 files
were staged, but HEAD was still `9d06dd3`. The commit had not completed.
The resumed session committed those exact staged files as `de76a87`.

The recovery audit verified **75 hashes** across the saved evidence index,
stage logs, source, tools and result records. All **19 recorded stages** had
their expected exit codes and `validation.done` contained `0`. The earlier
P1 runner error was already recovered by the recorded finisher; it was not
an outstanding failed proof or interrupted test.

A host process inspection found no remaining proof/test/lock jobs. The original
`/tmp/zk60-round19`, `/tmp/zk60-round21` and `/tmp/zk60-opus-o8` directories
were absent, including outside the sandbox. A filename search found no backup
of the original IO captures in the home directory. The retained repository
logs and result records remain intact, but the original capture/receipt bytes
are unavailable in this environment. Their historical hashes cannot recreate
those files, and fresh cryptographic randomness cannot reproduce them exactly.

## Fresh evidence, with its own provenance

The unchanged Rust capture producer was rerun with fresh randomness. The
complete `hashline` and `zkp-core` diff against `1f0ff36` was empty, and all
ten recorded Rust source hashes matched. The separate-process verifier binary
also matches the recorded round-19/21 SHA-256.

The four new triples live in `results/zk60_round22_captures/`, a gitignored
workspace directory, rather than temporary storage. The source-bound
[new manifest](../../results/zk60_round22_captures.json) names their actual
capture, receipt and policy hashes. They are **new evidence**, not recovered
round-19 artifacts. Historical manifests and results were left untouched.
These large local files survive temporary-directory cleanup, but are not
included in a Git clone; regenerate into a new directory/manifest if missing.

The [validation record](../../results/zk60_round22_validation.json) and
`results/zk60_round22_evidence/` retain commands, exits, logs and completion
markers. The capture run repeats six bound-IO Rust tests, verifies all four
receipts in separate processes, rejects twelve changed-input-root,
changed-output-root and wrong-mode cases, and passes native freeze-check.
CPU tests use two threads and an 8 GiB address-space limit; the Rust stage
takes the shared heavy-job lock. No GPU or timing benchmark was launched.

## O8 integration and a corrected acceptance boundary

Opus delivered O8 in `d82a286`, with handoff `0f51e3f`. Its
[report](ZK60_OPUS_IO_ANALYSIS.md), archived analysis, new parser/model and
tests are integrated unchanged. Their source/import hashes are checked
against the original result. This retains the provenance of that delivery.

Review found an acceptance bug in the analysis CLI, separate from its linear
model. `analyze` records a failed preflight but continues, and the CLI checks
only `verdict.controls_all_pass` and `refused`. On an empty capture directory,
the verdict is vacuously true and `refused` is empty: the command can exit 0
with no analyzed captures. Its verdict also omits ingestion-battery failures.
This is not an invalid cryptographic receipt accepted by the Rust verifier.

Use [the strict entry point](../../scripts/zk60_io_review_gate.py) for new
integration runs. It verifies recorded dependency/source hashes, requires
successful preflight before analysis, and then checks the analysis preflight,
four distinct manifest-bound cases, two cases per mode, model controls and
all sixty ingestion controls. It refuses to overwrite an existing output.
Five regression tests cover the empty-directory reproduction, failed
preflight, absent/duplicate results and an ingestion rejection that the old
verdict fails to include, alongside acceptance of the delivered complete record.

The unchanged O8 tests also run against the explicitly selected fresh directory
and its matching manifest through `review_tests.py`. Only fixture bindings and
the three import-time directory skips are adjusted in that runner. Three tests
requiring the unavailable legacy capture directory remain skipped and are
reported individually. The archived legacy disclosure is historical evidence;
the fresh endpoint single-mask ablation is still executed as a positive control.

## Result scope and disposition

The fresh O8 run checks the same joint message/terminal/proximity model,
including shared X/z16 planes across A and the two endpoint commitments.
The opening and IO CFS tools are applied separately to these same fresh
captures and bound to the new manifest. Their fixed-challenge scope is unchanged.

All **23 validation stages** completed with expected exits:

- **Six Rust tests**, four receipt accepts, twelve policy/mode rejections,
  and native freeze-check pass.
- **26 IO Python tests** pass. The unchanged O8 suite runs 36 tests with
  **33 passing and three explicit legacy-fixture skips**: 59 Python passes
  in total. The full repository Python/Rust suites were not rerun.
- O8 passes **51 preflight checks**, all four joint analyses and **60 ingestion
  controls**. A/Input/Output/W disclose zero base dimensions in this model;
  the all-private union's two residual dimensions are exactly H's public
  LogUp identity. The fresh endpoint single-mask ablation detects disclosure.
- **18 private PCS opening checks, four shared M opening checks and 22 numerical
  corruption controls** pass on the fresh captures.
- **Eight IO CFS slot checks and 72 corruption controls** pass on those same
  captures. These algebraic checks do not construct new Fiat–Shamir receipts.

Both `capture.done` and `review.done` contain `0`. The evidence index binds
the retained runner scripts, logs, changed-policy artifacts and completion
markers; the validation record additionally binds the fresh analyses and gate.

O8's findings are retained with the following disposition:

- **F1, profile label:** the layout description begins with the base profile
  name, but its full geometry changes the digest and the actual IO profile,
  domain and frame are independently checked. A shared textual prefix does
  not itself imply a layout-digest collision. Label cleanup stays separate
  from the source-pinned evidence.
- **F2, two functionals per IO slot:** round 21 covers the two additional CFS
  fibres and their exact M functional bindings. The fresh run checks them
  again; adaptive transcript composition remains open.
- **F3, two encodings of each endpoint plane:** the joint model preserves the
  shared data planes while each owner's separate pads can be translated by
  the conditional round-20 construction. The Merkle roots/authentication paths
  are outside those checks. Caller-fixed roots still prevent claiming a full
  simulator from these results.
- **F4, repeated witness:** this is confirmed by
  `bound_ffn_honest_p1_p3_and_fresh_owners`: it builds one synthetic witness
  and proves it twice per mode with fresh owners. Both historical and fresh
  analyses examine individual receipts. Repeated-proof privacy remains open.
- **F5, M proximity count:** eighteen random coefficients plus the fixed
  `(1,u)` blinder pair is the intended twenty-row geometry.
- **F6, old helper's unused-row label:** retain the archived helper hash;
  the current adapters include all endpoint proximity rows. This stale label
  is not an omitted observation in the accepted joint model.

The model treats committed data coordinates as free. Within its linear scope,
fixing public data coordinates merely restricts allowed data differences:
if every data difference can be absorbed by masks, that remains true for a
subset with those coordinates zero. For the union containing H, differences
must also preserve its public LogUp identity. This observation does not give
a simulator for public roots, side information involving secret randomness,
or adaptively chosen transcript coefficients. The shared endpoint-plane
identification concerns honest witnesses satisfying the IO equality; the
equality argument's soundness remains a separate obligation.

## Continuation

O8 is delivered and integrated; do not wait for it or rerun its old artifacts
as new work. The next Codex task is to specify and justify P1 endpoint
preparation and simulation for caller-fixed roots, then compose the actual
adaptive transcript and repeated-proof argument. Preserve hidden IO and
activations. Private attention and a tiny complete P1 block follow that gate;
private weights/authenticated model identity remain required for P3. The
minimal maintained core refactor stays priority 3. Full privacy acceptance,
U-2 and the complete private block remain open.
