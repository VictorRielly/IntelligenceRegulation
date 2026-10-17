# R2a encoded-buffer allocation candidate

This candidate is built on the tested R1d source, without changing that
source tree or its binaries. Its goal is to remove the redundant whole-buffer
zero fill from the tagged CPU hiding-commitment fallback. It does not add a
GPU path, extend privacy acceptance, or implement the trained 8B model.

The original `encode_row_zk` and untagged commitment function are unchanged.
Pads and salts are still drawn before encoding, in the same order. The new
helper initializes the final allocation row by row, then applies the same
forward NTT. Hashing, leaf salts, Merkle construction and verifier code are
unchanged. Input/pad widths where the coefficient contributions overlap are
handled by the same subtraction as the old encoder.

## Memory-safety review obligations

There are two production unsafe boundaries in `pcs/encode_buffer.rs`:

1. Converting one `MaybeUninit<Fp>` row to `&mut [Fp]` occurs only after
   three disjoint slices covering the entire row have been written. The
   row-length and coefficient bounds are checked before the writes. No
   reference to an uninitialized `Fp` is formed.
2. Setting the vector length occurs only after Rayon has joined all row
   workers successfully. Exact row partitioning covers the entire final
   length; allocation size uses checked multiplication. If a worker panics,
   the vector length remains zero. `Fp` is Copy with no destructor.

Each worker's input, pads and destination are disjoint by row. NTT tables and
coset powers are read-only. The initializer consumes no RNG. These are source
arguments, not a formal memory-safety proof. Miri and Valgrind are not installed;
neither has been run. Independent review of the unsafe boundaries is requested
in the Codex/Fable coordination file before integration.

## Validation

`validation-1/validation.json` and its terminal marker are authoritative.
Core debug and release pass 68 unit tests plus 2 integration tests. Tests
compare every encoded element with the original path, whole commitment
roots/pads/salts and the next RNG output, serial/parallel initialization,
poisoned buffers and invalid sizes. The independent conformance module from
review commit `3257c33` is retained with an additive check that the new buffer
matches all 35 full-row digests, including width 2^14 and ordering controls.

The first debug attempt exposed an incorrect overlapping-pad coefficient in
this candidate. It was corrected and coverage expanded; the failed source
and log remain in `candidate-initial/` and `core-debug/`. Current reviewed
source copies, hashes and diff are `candidate-v1/`, `source-changes-v1.json`
and `candidate-v1.patch`.

Native tests, fresh receipt verification and old/new receipt compatibility now
pass; validation session 6175 completed on the following continuation. See
`validation-1/validation.json` and its terminal marker. `benchmark.py` refuses
to start before those pass. It includes one old/new warm-up pair followed by
old/new/new/old dense 125M block runs under the heavy lock. Both binaries
include the same small-slot sumcheck oracle. Timing is shared CPU with two
Rayon threads; the anticipated memory-write saving is not yet a measured
whole-proof improvement and is not an 8B/GPU result.

## 2026-09-26 A/B completion

`dense-ab-1/comparison.json` and `run.done` now record six successful dense
125M proofs (one warm-up per arm, then old/new/new/old), all 40,783,352 bytes.
Source/binary pins were checked before and source pins after the run; retained
log hashes were independently rechecked. Measured non-warm proving seconds:
old **44.51 / 40.27**, new **39.73 / 40.10**. The A commitment phase was
9.288 / 9.123 s old and 7.284 / 8.119 s new; H was 12.389 / 10.724 s old and
10.986 / 10.390 s new. Rounded phase logs are preserved in
`dense-ab-1/measured-summary.json`.

These are two-thread shared-CPU diagnostics; native compilation of the separate
grouped-equality candidate overlapped part of them. The spread in old timings
and unrelated phases precludes an established end-to-end speedup. The result
closes the deferred correctness-at-125M measurement, not private 8B performance.
