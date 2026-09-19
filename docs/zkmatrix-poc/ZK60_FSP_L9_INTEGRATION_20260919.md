# FSP-L9 integration — 2026-09-19

Codex review of Claude's delivery `f0d34812e0653310eee9a87457f1df03d2ab77d6`,
integrated on `0bd43ed`. Production changes are limited to
`hashline/src/gpu/cuda.rs` and `kernels.cu`. The delivery's original scripts,
logs and [ledger](ZK60_FSP_L9_PROGRESS.md) are retained separately from
[the integration run](../../results/zk60_fsp_l9_integration_20260919/attempt-2/validation.json).

**GPU correctness gates passed.** The CPU Rust suite passed 261 tests,
with zero failures and two explicitly ignored saved-receipt capture entry
points. Four required-device configurations each passed 34 commitment tests
and reported 189 executed device cases; all four oracle sets passed. The
12-test device cache suite, all twelve frozen proof-byte gates and the native
lattice freeze also passed. The full Python regression is still running;
its completion is tracked separately in `regression-v2.json`.

## What changes

The non-hiding, chunked opening writes only the first transform's residues
that its next transform will read. The producer and consumer agree on a
`rows × tiles × padded_residues` prefix of the existing scratch allocation.
The transform arithmetic, selected columns, duplicate-index mapping and
proof protocol stay the same. The host column split also runs in parallel.
Two experimental shared-memory permutations stay disabled by default because
Claude's measurements showed regressions.

The delivery measured **1.162× over four re-encode kernels** at its largest
tested row count. Its estimated saving over the historical 58.40-second
public-IO FFN pass is **0.8–1.8 seconds [COUNTED]**, not a measured complete
proof improvement. The full-call timings have substantial variance. No new
model-scale timing or private-model performance result is claimed here.

## Review and corrections

- The compact producer preserves the original inverse-transform ordering,
  padding broadcast and all remaining butterflies. Its store selects the
  same shared-memory entries that the previous consumer loaded. The new
  consumer changes those addresses only; twiddles and final column selection
  remain the same. The padded residue-list length is passed as the stride.
- The host copy casts immutable `u64` slices to `Fp` slices. `Fp` is
  `repr(transparent)` over `u64`; the copy preserves exactly the previous
  `Fp(v)` values. Each parallel destination is separate, including duplicates.
- **Integration fix:** `HL_GPU_PAD_SKIP=0` now also disables the compact
  producer, so it restores the documented original producer. The delivered
  compact dispatch checked only `HL_GPU_P1_COMPACT`. Default behavior is
  unchanged.
- The output allocation is **not pooled in this delivery**. The existing
  assertion requiring two scratch-pool takes remains correct; no allocation
  test is weakened. A future pooling patch must update its corresponding
  accounting tests together with the implementation.
- Archived shell oracle wrappers pipe command output through filters without
  reliably propagating failures. Their retained logs were inspected, but the
  integration runner independently checks process exits, nonzero test counts,
  verifier acceptance, complete SHA-256 values and proof lengths.

## Hiding-path follow-up

The ledger's suggested direct substitution into `encode_rows_view_zk_gather`
is incorrect. That path uses `k_ntt_p1` on natural-order coefficients after
pad insertion and coset scaling, with physical stride `nn` or `n+q`.
`k_dit_p1_pad_c` expects the non-hiding inverse transform's bit-reversed
coefficients and its zero-padding pattern. Those inputs are not interchangeable.

The compact-store approach can transfer through a compact-output variant of
the actual `k_ntt_p1` producer, retaining its bit reversal, source bounds and
mask/coset semantics. This remains Claude's GPU lane. Acceptance must include
both CL18 pad widths and CL7/CL15 duplicate, ragged, fallback and deliberately
incorrect hiding-encoding controls, followed by the legacy frozen proofs.

## Integration gates

The retained `run.py` serializes builds and GPU work under the repository's
shared locks. Each GPU program requires an idle, sufficiently large device
and an empty compute-process list. Four fresh-process configurations exercise
default behavior, compact off, pad-skip off and both experimental permutations
on. Each runs the device oracles and 34 commitment tests with
`HL_GPU_REQUIRED=1`; the default configuration also runs 12 cache tests.

The proof gate generates all four frozen 12-layer × 512-row fixtures on CPU,
GPU and forced-chunked GPU, requiring the full expected digest and length for
all twelve proofs. Legacy `--zk` fixtures are compatibility checks, **not
privacy evidence**. Sources are hashed before and after; actual executable
hashes, commands and exit codes are retained. The full Python regression and
native lattice freeze have separate logs in the same directory.

The first attempt stopped at its initial idle preflight (zero MiB reported,
93% utilization immediately after the previous job). It ran no GPU tests.
That failure remains in `validation.json` with exit marker 1. The successful
`attempt-2` reused the exact passed builds after rechecking their hashes and
required two consecutive idle samples before each GPU program. Its terminal
exit marker is 0; it did not relax the memory, utilization or process checks.
The first Python attempt reached its incorrectly short 240-second timeout;
the detached retry uses the prior suite's recorded 861-second duration to
justify its longer limit. No timed-out run is reported as passing.

The five-second model-scale objective, complete model coverage and whole-proof
privacy remain open. The native verifier captures are ready for Claude's
joint-view review; this GPU change does not resolve D8/D11.
