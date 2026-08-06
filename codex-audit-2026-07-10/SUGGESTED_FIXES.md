# Suggested code and documentation fixes

This audit did not modify implementation files. The following changes are
recommended in priority order.

## Immediate low-risk corrections

### Correct benchmark labels

In `lookup_bench`:

- print `measured: 1T` for the actual result;
- print `projected using M5 commitment scaling` instead of “MEASURED 22T”;
- remove the GPU row or name its baseline explicitly;
- report peak RSS and the exact proof components omitted.

In `m5_bench`:

- rename “end-to-end” to “commitment-stream end-to-end”;
- print that A/B/C are independent random tensors and no relation is proved;
- replace the generic GPU factor with a placeholder pending the actual kernel.

Add `lookup-bench` to `usage()`.

### Repair status drift

- Change the M4 lookup header from “no engine code” to a component table.
- Keep row 12 explicitly `NOT ZK` until U-K5e.
- Reopen U-K6/U-K8 against their original FFN-shape exits.
- Update the stale R1 row in `M4_ACTIVATION_DESIGN.md`.
- Update the M5 “E3/E4 pending” text to distinguish unmasked implementation
  from masked work.

### Freeze the table

Replace runtime `f64::exp` table construction with a checked-in
`[(i8, i8); 256]`. Retain a generator in a test/script and assert the digest.

## Protocol implementation

### Introduce a first-class masked lookup proof

Define explicit objects rather than assembling the protocol inside a self-test:

```text
MaskedLookupStatement
MaskedLookupWitness
MaskedLookupProof
LookupTranscriptVersion
prove_masked_lookup(...)
verify_masked_lookup(...) -> Result<(), VerifyError>
```

The statement should contain tensor IDs/shapes, table digest, instance layout,
mask commitment IDs, range-proof reference, output-consumer reference, and
security parameter ID. The proof should not expose unmasked `v^M` or other
per-tensor MLE values.

### Enforce mask freshness

Freshness cannot be a comment. Bind a proof nonce/session identifier and mask
commitments into the statement, maintain an explicit one-proof mask type that
cannot be cloned/reused in the normal API, and retain a negative test that
deliberately reuses it. If cross-process reuse prevention is required, specify
the persistence/trust model rather than assuming type safety is enough.

### Validate all vector and commitment lengths

Examples needing checked invariants before indexing or zipping:

- `ct_h0`: require equal `t1s`/`t2s` lengths and hash counts;
- `link_h0`: same;
- every `KElem`: exactly 16 canonical coefficients;
- sumcheck rounds/final evaluations;
- roots, instances, powers of two, depth, and table length;
- commitment group dimensions and all claim indices.

This should return a verifier error, never panic.

## Memory and GPU representation

### Replace `type KElem = Vec<u64>`

Use an inline semantic type:

```rust
#[repr(transparent)]
struct KElem([u64; 16]);
```

Then introduce a separate GPU batch layout, likely coordinate-major. Do not
expose raw device layout as the semantic transcript encoding.

### Eliminate per-element heap allocation

- reuse two fold buffers;
- allocate round tables from an arena;
- avoid cloning complete K tables;
- build/recompute GKR layers in a bounded schedule;
- make `mle_weights_block` write into caller-provided storage;
- collect allocation, host RSS, and device VRAM metrics in the benchmark.

### Backend interface

Keep challenge generation and proof verification backend-independent. GPU
backends should implement batched pure arithmetic functions and return exact
canonical values. The CPU verifier should remain the reference security path
until the GPU verifier has its own audit.

## Test/CI fixes

- Convert field, sumcheck, GKR, E4, R1, E2, and chunking batteries to Rust
  `#[test]` modules.
- Add property tests over zero, one, q-1, centered extrema, all table rows,
  malformed lengths, and capacity boundaries.
- Run the Python masking spike in CI until its logic is ported, then retain it
  as a cross-language oracle.
- Require `cargo fmt --check`, Clippy with an agreed warning baseline, debug and
  release tests, and benchmark-status drift checks.
- Add CPU/GPU differential known-answer tests before performance tuning.

## Cost-model fixes

Generate a typed inventory from the statement DAG:

```text
object kind, count, used elements, paid elements, chunks,
proof rounds, transcript bytes, host bytes, device bytes
```

The benchmark should consume that inventory. A result may be labeled measured
only when that exact component ran on that exact backend; applying a measured
factor from another component must be labeled projected.

