# ZK60 round 5 — hardening, regression infrastructure and CL1 review

Opened after Victor requested commit/push, continued implementation and a
substantial Claude queue. Round 4 is committed and pushed as `5657a8d`.
Its validation record describes the pre-commit snapshot, not current publication.

## Ownership before work

| Lane | Owner / checkout | Writable scope |
|---|---|---|
| H1 explicit verifier denominator refusal | Codex hardening worker, `/tmp/zk60-round5-mO246D/hardening`, base `5657a8d` | `hashline/src/field.rs`, narrowly scoped verifier paths in `attention.rs` and `layer.rs`, new targeted tests and `docs/zkmatrix-poc/ZK60_VERIFIER_HARDENING.md`; no global formatting or transcript changes |
| R1 full Python fixture-path regression repair | Codex regression worker, `/tmp/zk60-round5-mO246D/regression`, base `5657a8d` | `tests/` fixture selection/helper/tests, narrow related scripts only when demonstrated necessary, `docs/zkmatrix-poc/ZK60_REGRESSION_FIXTURES.md`; native/prover source read-only |
| CL1 independent integration review | Codex review worker | Read-only Claude branch/code/logs; no GPU run or edits |
| Integration, validation and expanded queue | Codex lead, main tree | Shared boards, evidence, new `ZK60_CLAUDE_QUEUE.md` and task JSON, reviewed worker integration |

Workers are Codex agents, not Fable or Claude. Claude owns its GPU/PCS lane;
Fable owns the independent privacy/identity review. Do not merge CL1 before
concrete review findings are resolved and the actual handoff is rechecked.
The reviewed CL1 code is unchanged between `15eeda6` and observed `c9fc897`;
the later report corrects the pooled-memory bound and must accompany review.

Heavy work uses `/tmp/zk-heavy.lock`, two build/Rayon threads. Jobs expected
over five minutes detach with persistent logs and exit markers. No full 8B
laptop GPU runs. Do not weaken frozen fixtures, turn failures into silent skips,
modify transcript/RNG order, or claim whole-verifier/whole-proof security.

## Acceptance

H1: reject zero lookup denominators explicitly before asserting inversion;
exercise exact helper/production verifier paths with deterministic test-only
challenge injection where needed. Preserve valid inversion behavior, caller
error propagation and all legacy proof bytes. No production override switch.

R1: establish the actual failure cause; honor explicit fixture configuration,
otherwise select a complete supported local fixture without copying tensor
data. Reject invalid explicit configuration rather than silently substituting.
Run configuration unit tests and the full Python suite if resource-safe;
report any missing native build/export independently and keep failure visible.

Lead: run final integrated Rust and frozen CPU gates, preserve public receipt
bytes, record full Python scope/results, publish the expanded Claude queue
early enough for its independent session to pick up work.

## Handoff

Implementation reviewed and integrated in the working tree; all final
acceptance checks pass. H1 adds explicit checked inversion at the three verifier call
sites without changing the prover or valid transcript. All five exceptional
branch regressions pass. The lead reviewed the three-line categories of
attention source changes before updating its drift guard; all frozen runtime
schedule fingerprints remain unchanged.

R1 selects complete local fixtures, honors explicit overrides without
fallback and refuses the higher-precedence incompatible model override. Its
15 configuration/wiring tests pass. The full suite's four failure sites and
two previously skipped real-data smokes are kept distinct; the latter now run.

Combined Rust release gate: **129 tests pass**, including the ordinary-library
receipt/wire and schedule tests. Four complete frozen CPU artifacts preserve
full SHA-256 and length. The persisted B4 receipt verifies independently and a
fresh receipt preserves its full SHA-256/length. Full Python/native validation
passed **144 tests, zero failures, zero skips**, exit 0, in 921.316 s. All six
fixture-dependent methods ran, including both formerly skipped smokes. The
detached run used two threads, no GPU switches and an 8 GiB per-process
address-space cap (not an aggregate RSS bound), after an offline native build.
Reported maximum RSS: **1,707,192 KiB**, no swaps. Logs/exit marker:
`/tmp/zk60-round5-mO246D/python-gate/`. The first sandbox launcher did not start
its child; an approved host launch ran the resource-capped job successfully.

The second independent read-only review found no actionable introduced H1/R1
issue. All Codex workers/jobs are complete. Formatting of the new Rust test,
whitespace and JSON checks pass. Eight inherited hashline attention warnings
remain; existing native warnings were not globally cleaned up. Evidence:
[round-5 validation](../../results/zk60_round5_validation.json).

Concurrent CL8 files appeared after Python discovery and were left untouched;
they are not included in the 144-test count or this continuation commit.
No Claude GPU/PCS/memory-planner file or Fable-owned file was edited.

Round-4 code is pushed at `5657a8d`; the ten-task Claude queue and CL1 review
are pushed at `4a58f12`. No CL1 merge or throughput claim is implied.
