# Lane stages 39–43: independent adversarial code review

Reviewer: Claude (Opus 5.5), review branch `zk60-private-block-125m-review`
(worktree `/home/victor/wt-zk60-block125m-review`), started 2026-09-23
01:59 PDT. Under review: lane `zk60-private-block-125m`, delta
`a9d6d4c..f486e6f` (stages 39–43, plus the `timing.rs` comment fix), merged
into this branch at `5fd5a69`. The merge had one conflict: the test-module
list in `private_block.rs`, resolved by keeping both sides.

**SKELETON. Nothing below is a finding yet.**

## 0. Status

| # | question | status |
|---|---|---|
| 1 | soundness regressions (verifier-side hunks) | pending |
| 2 | completeness regressions (new refusals on honest registered inputs) | pending |
| 3 | ordering (each refusal before the first absorb / commit / draw) | pending |
| 4 | test-only gating (`CheatingProver`, `cheating_prover_is_on`, K8 registry) and the release build | pending |
| 5 | input-dependent refusals and secret-derived messages | pending |
| 6 | D22 condition-7 hunk table (the toy's pin set plus P-1's six) | pending |
| 7 | the declaration pin standing in for the deleted tests | pending |

## 1. Findings

pending

## 2. Verdicts per question

pending

## 3. D22 condition-7 hunk table

pending

## 4. What was NOT checked

pending

## 5. Evidence

`results/zk60_s39_s43_review/`; attack tests
`hashline/src/private_block/s39_s43_review_tests.rs`.
