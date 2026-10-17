# Independent review of grouped-round fusion (2026-09-27)

Scope: compared `/tmp/zk60-sol-fusion-20260927/zkp-core/src/sumcheck/grouped.rs`
against `/tmp/zk60-groups-20260926/zkp-core/src/sumcheck/grouped.rs`, read the
candidate tests and the `SumcheckRounds` driver. This is a **static review**;
I did not edit the candidate or run its Rust tests. No concrete correctness
or soundness defect was found in the inspected change. That conclusion is
bounded by the untested cases below and the caller's declared bracket-degree
and equality-support assumptions.

## Checked invariants

* **Quarter indexing and writes.** With current table length `4q`, the old
  fold writes `q0 <- q0 + r(q2-q0)` and `q1 <- q1 + r(q3-q1)`, then keeps
  `2q` elements. The fusion computes exactly those two values per index,
  uses them as `cur` and `cur+dif` for the next round, and truncates to `2q`.
  Next-round row index `offset+i` covers the lower `q` positions; its paired
  high position is represented by `dif`. This also works at `n=2`, `q=1`.
* **Ownership and parallel reduction.** Each table is split into four
  nonoverlapping mutable slices. Recursive `split_at_mut(mid)` partitions
  every quarter into disjoint Rayon tasks. `offset+mid` follows the right
  task's row indices. Tile sums are reduced by field addition, so a different
  reduction tree can change work order but not the field result. No unsafe
  aliasing path appears in this code.
* **Prior group claims.** `fold` first interpolates each group's *unmasked*
  pending values at `r`, then updates the equality prefix. Only after that
  does it build metadata for round `j+1`, evaluate the fused sums, and recover
  `H(1)` when `factor[1]` is invertible. This preserves the baseline's
  per-group identity; it never seeds recovery from the public masked scalar
  or hosted sum. When `factor[1]=0`, `inverse_one=None` and degree 1 is
  evaluated directly. In debug builds the recovered result is checked against
  an explicit degree-1 evaluation.
* **Support indexing.** `round_groups(j+1)` uses the remaining suffix after
  consuming the next variable. In the tile, `(row >> trailing) & mask`
  extracts just that support from the next-round low-row index. Empty suffix
  yields a one-element equality table and weight 1. The constructor bounds
  `start` and support length, so `end` stays within `n_vars` and the shifts
  stay below the platform bit width for any representable table length.
* **Round transitions and transcript.** At `n=0` the driver calls no round;
  at `n=1` fusion takes the original fold path. For `n>=2`, `fold` stores a
  ready round for exactly `next=j+1`, and `round(j+1)` moves it to `pending`.
  The final fold takes the original path and leaves `ready=None`, satisfying
  `finals`. The fused evaluator itself does not touch the transcript or RNG;
  `prove_rounds` still absorbs one round and draws one challenge per variable.
* **Arithmetic bounds.** The newly introduced `2*q*k` cutoff multiplication
  could overflow `usize` in release for an artificial collection of tables
  whose combined element count is impossibly near address-space size. The
  original `half*k` cutoff has the same issue. It is a robustness cleanup to
  use `checked_mul`/`saturating_mul`, not evidence of a reachable proof
  failure on the declared profiles. The fresh `q`, `mid`, `offset+mid` and
  support-mask expressions remain in bounds for an allocated power-of-two
  table. `chunk` is positive whenever the fused branch executes.

## Validation still needed before enabling fusion by default

The candidate's differential suite covers `n=0,1,2,4,8,15`, masks,
tagged/untagged transcripts, zero/one factors, finals, and extension
rounds. Its generated support starts are only 0 or 1. Add an independent
oracle case with `start>1`, a support of length 0, a support of length 1,
and a support ending before the final variable. Include a nonzero challenge
outside `{0,1}` at the `n=2` transition. Run optimized/release differential
tests, because the degree-1 explicit check is debug-only, and repeat across
one- and multi-thread Rayon pools at a size above the `1<<16` cutoff.

The bracket closure is assumed to be a pure polynomial of its declared
degree. Fusion evaluates the next round during `fold`, after the challenge
has been drawn; a closure with side effects or external mutable state could
observe a different call schedule. That would violate the evaluator's
polynomial contract, but the contract should be made explicit in the public
API comment if fusion becomes standard.

This review does not establish an 8B speed result, privacy, or GPU parity.
The feature remains opt-in through `ZK60_FUSED_ROUNDS=1` at the private-block
call site in the inspected candidate.
