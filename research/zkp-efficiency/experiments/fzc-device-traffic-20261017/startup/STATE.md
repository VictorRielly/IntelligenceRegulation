# ZKP efficiency explorer — durable state

Cycle 0064 COMPLETE: `20261017T142624Z-6b84b6ef`.
Checkpoint: 2026-10-17T14:36:34Z. Next cycle no earlier than 15:26:24Z.
AGENDA, current target, durable/project memory, latest three results and
handoffs read. Startup snapshots and prior state are under
`experiments/fzc-grouped-equality-20261017/startup/`. Starting 325 source
records preserved; six LIVE primary records appended (331 total).

The current F zero-check can use three grouped equality brackets: degree 3
for the main bracket, degree 1 for each host without padding, degree 2 with
padding. The existing host-slot recover-one evaluator is the baseline.
72 synthetic fixtures pass: 1,600 cross-evaluator round values, 960 direct
original-cube/off-grid values, 1,512 terminal words, 512 bracket values and
128 extension-like polynomial values. Twelve mutation controls pass, with
190 subgroup recoveries and 98 zero-factor fallbacks without resampling.
A separate 290-check source/work/degree audit passes. No native proof gate.

Main run: 7.059977 s, 74,824 KiB parent RSS, 149,768 KiB compiler RSS.
Audit: 0.005162 s, 16,112 KiB. One pinned CPU thread (Core Ultra 9 185H,
CPU 0), nice 19, seed 2026101764, 59 s / 512 MiB limits. Standalone std-only
rustc 1.97; no Cargo/native crate build or GPU. Captured Rayon scheduling is
serialized. Three corrected harness/audit failures are preserved. No live native
source drift at the audit.

For H = N/2, baseline uses 9H-4 full polynomial calls; grouping uses 7H-3
main calls and 3H-1 / 5H-2 calls per unpadded/padded host. Added costs:
equality setup, weighting, interpolation, inversions and subgroup state.
All original tables and folds remain. N=16 regresses (baseline/grouped
0.633 / 0.731); larger synthetic tables show 1.03–1.42, with shared-host
variability. No stable factor, native proof gain or GPU rate is established.
Unapplied handoff: `handoffs/20261017-fzc-grouped-equality.md`. Review against
the active owner F-device lane; native bytes/refusals/masking/RNG/PCS/M,
shape privacy and fresh verification remain owner gates.

Owner functional 8B diagnostics carried forward, not rerun: one cold pass per
arm, T32, 32 linked blocks, 8,030,261,248 parameters, 16 threads. CPU process
384.542564 s / RTX 4070 Laptop process 391.287091 s; diagnostic 32/process
rates 0.083216 / 0.081781 positions/s. Witness 18.629 / 18.109 s; inclusive
prove_run 208.019 / 213.831 s includes reload 79.222 / 77.997 s. Remaining
110.168 / 117.725 s includes serialization/sink. Initial load+seal gives only
a partial startup fraction: 21.595% / 20.341%. In-process verify 93.356 /
92.741 s; fresh check 96.103 / 90.935 s plus initial load 80.675 / 78.635 s.
Receipt 465,815,776 B per arm. Do not aggregate arms. Full startup/prefill,
isolated serialization, steady slope, proof latency/lag/drain are unknown.
See `progress/20261017T142624Z-6b84b6ef.md` for all boundaries and evidence.

Ranked hypotheses:
1. OWNER: F/D device arithmetic and full prover residency. Charge transfers,
   scratch and all native gates. Prior 1.1B T128 GPU F masked cost is
   16.457 / 161.857226 s; deleting all of it caps direct gain at 1.113184x.
   No measured 8B F subclock or 5090 rate is available.
2. OWNER: immutable public digest/load/reload residency across complete
   fixed-context fresh-proof passes. Charge memory/revalidation and preserve
   mutation refusal and fresh masks. Measure pass-count slopes.
3. TESTED: F grouped evaluation. Preserve the small-table regression; owner
   native A/B remains owed. Do not combine this factor with prior constant
   factoring or GPU forecasts.
4. NEW NEXT LOCAL: audit the proposed 72 B * size(F) * 17 terms / time
   bandwidth numerator. Capture actual F CUDA/Rust buffers and count shared
   reads/writes, round-0 field widths, folds, padding, scratch and transfers.
   Distinguish logical term bytes from device/DRAM traffic. No speed claim
   without phase measurements/counters; do not override owner thresholds.

Next local: source-captured F device/table traffic census, then rotate to
lookup/softmax and proof composition. Next owner: review the handoff against
the active F port and run native correctness/bytes/privacy/fresh-verification
and enclosing timings under shared resource locks. No heavy/GPU job queued.
Borrowed lookups remain a capacity option; all prior negatives are retained.

Accepted target-compliant new 8B proofs/passes/positions: 0 / 0 / 0. Owner
functional freshly verified 8B evidence is separate; shape privacy acceptance
and independent 8B review remain open. No resident-pass, longer-context or
decode experiment here. Larger workloads remain allowed, with fresh masks and
complete verification; dense attention can grow quadratically. The >=50/s
target is unchanged and unachieved. No production/runtime/Git/receipt/
calibration/gate/instruction/reviewer writes, native proof, GPU job, install,
foreign script execution, external write/message or merge. No supervisor
liveness claim; saved reports do not establish user-message delivery.

Final artifact audit, 2026-10-17T14:38:35Z: 91 checks passed, 68 files
pinned, no live source drift. The initial historical-source schema failure
is retained. Final readable-report and command-status edits are hashed in
the artifact manifest.
