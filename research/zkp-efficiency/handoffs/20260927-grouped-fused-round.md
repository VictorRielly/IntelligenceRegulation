# Owner handoff — retain grouped arithmetic while fusing folds

**Candidate for native evaluation, not integration approval or a measured
speed result.** Cycle 0009, run `20260927T005233Z-ccb9384b`.

The [experiment](../experiments/grouped-fused-round-20260927/README.md) passes
37 synthetic cases: all 651 samples have an independent cube-MLE check;
1,953 group samples, 962 independent finals, six zero-factor fallbacks and
10 controls also pass. Final run 9.2027 s, 24,192 KiB, one CPU thread.
At 26 tables × 256 rows, logical table reads+writes fall 530,400 -> 424,736 B
(19.92%) while preserving padded group bracket counts `[1148,638,638]`.
No native timing, proof or GPU execution occurred.

## Interface and proposed patch location

Source target is the owner's existing `/tmp/zk60-groups-20260926` candidate,
`zkp-core/src/sumcheck/grouped.rs::{GroupedEqRounds,round,fold,finals}`.
The native slot is `hashline/src/private_block/argument.rs:553`; the three
SC_SZC descriptors are at lines 1784–1786. Five native files and the two
local research oracles are pinned in the experiment's `source-pins.json`.

The only proposed Rust file is
[`grouped_fused.proposed.rs`](../experiments/grouped-fused-round-20260927/grouped_fused.proposed.rs).
**It is an uncompiled/unapplied serial helper sketch, not a full native patch.**
It takes all mutable tables, current challenge r, public degree, next-round
group metadata and the existing bracket closure; it returns an optional vector
of unmasked next-group polynomials. It retains every equality table and returns
None at the final two-row fold. It has no transcript, mask or RNG access.

Proposed caller wiring:

1. Add a distinct `ready` cache alongside `pending`. Round zero uses the
   existing evaluator; a subsequent `round(j)` takes ready into pending.
2. `fold(r)` consumes pending, interpolates each actual UNMASKED group round at
   the unchanged MASKED-driver challenge, updates each equality prefix, then
   prepares metadata for `j+1`. Never seed from the asserted combined host sum.
3. The helper folds quarters `(0,2)` and `(1,3)`, stores both endpoints, and
   accumulates the next bracket samples. Recover sample one per group only
   with a nonzero factor. Keep the debug assertion and explicit zero fallback.
4. After the final fold, require no ready/pending value; finals keep the exact
   original table order. Do not compute a nonexistent extra round.

For production parallel work, expose disjoint mutable four-quarter slices per
table/tile or another reviewed safe ownership scheme. Do not capture a shared
mutable `Vec<Vec<Fp2>>` in Rayon or replace the parallel path with this serial
sketch. Preserve the existing cutoff unless measured evidence supports a change.
The experiment only exercises start-zero descriptors used by SC_SZC; generic
nonzero-start support in the Rust API requires additional tests.

## Negative findings and remaining costs

The first passing implementation added needless per-tile reductions in serial
execution. At four padded rows it added 11 field additions; at 256 padded rows,
tile three, 506. It is retained under `initial/` and as a final negative arm.
The final serial path directly accumulates; no such extra reductions remain.
Length two has no traffic benefit. Parallel reductions, cache effects,
instruction count, register pressure and allocation costs are unmeasured.

The Rust helper reuses `cur`/`dif` vectors of 2k elements, group sums of
sum(d_g+1), plus group weights/inverses and next factors/suffix tables. Pending
group values require g*(degree+1) fields; consume them before allocating ready.
The Python harness uses additional oracle and temporary arrays; its RSS is not
a native-memory prediction. Metadata builds and suffix-weight products match
between the synthetic arms, but native allocator behavior remains to measure.

## Owner validation and measurement proposal — not launched

Under the shared build/heavy locks, compile a separately retained evaluator and
run the owner's existing core debug/release grouped tests. Check all unmasked
samples/finals, native masked bytes/challenges/RNG consumption, extension rounds,
bad-witness behavior and the independent slot IR/original scalar oracle. Include
all shapes, short Ht support, zero factors, ragged parallel chunks and length
one/two. Fresh and archived receipts must cross-verify with corruption controls.
Keep D22's scope unchanged; no new acceptance follows from this arithmetic.

If those pass, compare complete evaluator/slot clocks: work has moved from
`round` into `fold`, so a round-only timing is misleading. Run release arrays
both within and beyond cache, then the dense grouped block with witness and
serialization included. Record one-/two-thread diagnostics separately from
quiesced hardware results, with peak memory and all source/binary pins.
Demote the candidate if lost parallelism, cache reuse or extra work offsets it.

The owner's latest complete softmax slot is 8.601/7.832 s inside known readiness
40.322/39.095 s. Removing that whole slot would save only 21.3%/20.0%; fusion's
actual saving is unknown. The large commitments remain. This cannot establish
the complete private 8B >=50-token/s target, and prefill is not decode.
Nothing was merged, queued, or sent externally; the main agent/Claude owns review.
