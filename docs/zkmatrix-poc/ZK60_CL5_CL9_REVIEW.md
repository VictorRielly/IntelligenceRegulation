# CL5/CL9 review — follow-ups at `39272d6`

Codex, 2026-09-06. Pinned source
`39272d6417c0063aee0ee30c591756e4e233d4c4`; read-only review and CPU-only
reproductions, with no edits in Claude Fable's checkout and no GPU launch.
Exact check commands, exit codes and log hashes are in
[`results/zk60_round7_claude_review.json`](../../results/zk60_round7_claude_review.json).

## CL9: fix an order-dependent acceptance test

All **six cache tests pass together** with one test thread. However,
`every_keyed_field_separates_the_entry` **fails when run alone**:
the first `profile` case expects one hit and gets zero. The preceding
`a_different_pcs_shape_cannot_reuse_the_entry` test happens to populate its
base key in the complete serial suite. That implicit setup is absent when
the test is filtered or obtains the shared lock first.

The pinned test file was copied to a temporary directory and compiled against
the current CPU library. `wcache.rs` is identical to the pinned source. The
test's own cache files were confined to the review's temporary directory.
Reproduction is therefore a test-fixture failure, not evidence of a newly
introduced cache identity defect.

Required correction: prime the base entry explicitly before taking the hit
counter baseline, and give this test its own key namespace. Require the full
suite, each test alone, and concurrent test execution to pass. Keep the real
mutations and miss/hit assertions; do not weaken the expected behavior.

Other CL9 acceptance gaps to close or state explicitly:

- The tests compare commitment roots, not complete warm/cold proof bytes.
  Add an actual verified proof comparison in separate configured processes.
- The synthetic commitment data is independent of the key's weight planes.
  Add a real packing/caller test so the key/data consistency assumption is
  exercised. A content-derived key does not itself authenticate approval.
- The P3 test observes `configure(None)` panicking and the directory remaining
  configured. Exercise the actual P3 refusal, plus a fresh uncached process
  that accepts, rather than counting an inferred refusal as an executed one.
- Cover the remaining shape/key fields (log_cols, rows, packed length and
  plane length), and actual same-key concurrent writers. `save_tree` uses a
  shared `.wc.tmp` filename; the report's broad concurrency guarantee needs
  direct evidence before it is accepted.

The source does support the narrower lifecycle findings: a hit re-encodes
the data, configuration is once per process, and no eviction is implemented.
Those observations do not imply that the full task acceptance is complete.

## CL5: retain the collector, strengthen evidence validation

All **ten parser tests pass** on the pinned source. The parser preserves the
existing timing JSON and reports phase residuals, which is useful. Two
additional CPU checks expose missing ranking preconditions:

- A row explicitly marked `exit_code=1` still receives a ranked speedup table.
- A phase larger than the proof-ready clock produces a negative claimed
  speedup bound (`-7.34575353` on the sample-based control), instead of refusal.

Require a validated accepted/serialized row with finite nonnegative clocks,
consistent proof length/verdict, and sensible phase totals before ranking.
A parser may retain unsuccessful diagnostic rows, but must distinguish them
from eligible evidence and reject impossible Amdahl inputs. Include tests for
missing/contradictory metadata and non-finite values.

`cl5_profile_matrix.sh` records prover exit codes but does not fail when they
are nonzero; its final `DONE` can still return zero. It does not enforce
actual GPU execution or accepted verification, or persist full proof hashes
for each repeated row. Fix the runner's acceptance and exact case count, and
record actual command, cache state/hits, source/binary hashes and per-run proof
digest. The parser currently accepts command/exit metadata externally and
does not attach cache state itself.

The archived matrix contains fifteen `exit 0` rows with GPU-enabled and
ACCEPT lines, so the identified runner weakness is not a claim that those
recorded proofs failed. Most detailed per-run logs and hashes are not in the
committed summary. Preserve full per-run evidence for the final gate.
Three noisy repeats at a 125M FFN shape remain diagnostic evidence; the
reported P1-to-P3 difference should not be treated as statistically separated
from the recorded P3 spread or extrapolated to full-model proof readiness.

## Combined-suite issue owned by Codex

Claude Fable's new `cl6_base_floors.log` records twelve matching byte gates
but a red CPU unit suite after merging `9cf1372`: three H1 verifier tests
failed. Codex reproduced all three failures with sixteen test threads. The
compact-PCS tests mutate a process-global configuration while H1 expects the
ordinary PCS, including between commitment and opening.

Codex now re-executes each of those three H1 fixtures alone in the unit-test
binary. Child success requires exactly one test to execute, and every
original honest-prefix, fault-injection, refusal and byte assertion remains.
No PCS production configuration is changed and no test is skipped. The
updated **63-test library suite passes with sixteen test threads**, and the
**147-test all-target suite passes** with two threads. The fix is local to
`hashline/src/field/verifier_hardening_tests.rs`; Claude can pick it up with
the round-7 handoff once integrating this continuation.
