# Isolated row-fold candidate, 2026-09-19

This is a recovery snapshot, not an integrated optimization.
The source worktree is `/tmp/wt-zk60-rowfold-20260919`, branch
`perf/zk60-rowfold-20260919`, based on `586eccd`.

- `candidate.patch` changes only `zkp-core/src/mle.rs`.
- `row_fold_bench.rs` belongs in that worktree's `zkp-core/examples/`.
- All Python runners here are archived copies from the isolated worktree.
  Do not run this snapshot against main.
- `attempt-1/` retains the first arithmetic passes and benchmark compile
  failure (ambiguous integer type, corrected with `rows: usize`).
- `attempt-2/` retains the corrected build, seven arithmetic tests in each
  switch configuration and the same-binary 0/1/1/0 benchmark. The unsigned
  bias strategy is 2.22–2.49x faster on dense inputs but 2.55–2.92x slower
  on 99%-zero inputs. See `comparison.json`; this candidate was rejected
  for integration. Its exact source is retained as `attempt-2/mle.rs`.
- `candidate.patch` now uses signed i128 accumulation and retains the
  inherited zero skip. The sum bound covers every intermediate sum;
  reduction happens once per output component.
- The current detached validation is PID 254599, session 47015, launched
  with `attempt-3.py`. It uses the same arithmetic and 8-case benchmark
  gates, under the build and heavy locks respectively. Inspect that handle
  and `attempt-3/run.done` in the isolated worktree before any restart.

Acceptance still requires exact differential tests, inspection of dense and
sparse timing behavior, and full proof-byte gates before main integration.
No model-scale speed or privacy claim follows from this candidate.
