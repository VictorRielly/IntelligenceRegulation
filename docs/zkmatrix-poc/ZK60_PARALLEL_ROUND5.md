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

In progress. No CL1 merge or throughput claim is implied by this round.
