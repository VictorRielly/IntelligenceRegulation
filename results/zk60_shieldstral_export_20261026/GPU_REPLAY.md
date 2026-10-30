# Exact integer GPU replay

This is an execution backend for the numerical fidelity evaluator. Native
proving, profile registration and privacy acceptance remain separate. The CPU
runner and its retained results are unchanged; GPU runs use separate manifests
that pin both the GPU code and the shared CPU journal/scorer.

## Arithmetic

`gpu_integer.py` replaces the seven public-weight matrix operations per layer.
Inputs must be finite integer words in signed 24-bit range; weights must be
symmetric int8. Norms, attention, SiLU, rounding and refusal recording retain
the baseline implementation.

For signed 16-bit inputs, the exact decomposition is
`x = lo + 256*hi + 128`, with signed-byte `lo` and `hi`. Signed 24-bit inputs
use `x = lo + 256*mid + 65536*hi + 32896`. Each piece is multiplied by the
same weights using int8 multiplication and int32 accumulation. The offset is
restored using the exact weight column sums; recombination uses int64.

With at most 16384 inner coordinates, a partial dot has absolute value at
most `16384*128*127 = 266338304 < 2^28`. Recombination fits int64, and the
final dot has absolute value below `2^44`, so conversion to the baseline's
float64 representation is exact. Padding inserts zero weights and is removed
from the returned result.

CPU tests cover every signed16 input, signed24 boundaries, independent int64
dot products, and refusal of nonfinite, fractional and out-of-range inputs.

## Retained actual-layer probes

Each row was one separate guarded GPU process on the laptop RTX4070, followed
by device drain. All three probes match the baseline residuals and complete
refusal diagnostics exactly.

| Probe | Refusal diagnostics | Guard RSS peak, GiB | Torch reserved peak, bytes |
|---|---|---:|---:|
| Layer 0 | Zero | 1.05 | 459276288 |
| Original layer 25 | Up: 2; gate: 395 | 0.92 | 459276288 |
| Corrected layer 25 | Zero | 1.10 | 459276288 |

Evidence: `gpu_probe/{layer0,original25,fixed25}-1/complete.json` and
`../zk60_astra_20261026/gpu_jobs/`. These are MEASURED, n=1, shared-box
correctness probes. The guard's device samples reported only70MiB on these
short probes and missed Torch's allocation peak; they are not a reliable
peak estimate. No speedup or native-proof claim follows from these probes.

## Full replay gate and limits

The eight-item smoke must match every embedding/layer residual file, every
journal including refusal diagnostics, and final verdict bytes across all
26 layers. `compare_gpu_replay.py` creates `gpu_smoke_parity.json` only after
this comparison succeeds. The full benchmark launcher requires that artifact
to match the current backend, runner and shared CPU helper sources. The full
smoke comparison passed on Oct28; `gpu_smoke_parity.json` binds every retained
residual, journal and final verdict. All26 guards exited0, with peak RSS1.24GiB
and sampled GPU use660MiB; all device-drain checks passed. These are shared-box
correctness results, not a controlled performance benchmark. The full4872-item
benchmark has started under the same backend and remains incomplete.

`run_gpu_replay.py` launches exactly one layer per guarded process, with a
resumable timebox, the shared heavy lock and both lane HOLD checks. The Torch
allocator is capped at3GiB; total-device guard telemetry must remain at or
below4096MiB. Subsequent layers start only after the prior guard has completed
and drained the device. No input is truncated to fit the timebox.

All4872 benchmark inputs,702006 tokens and original lengths throughT533 are
required for full numerical acceptance. A smoke pass alone does not establish
held-out fidelity, an accepted native profile, or an application proof.
