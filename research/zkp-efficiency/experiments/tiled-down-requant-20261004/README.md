# Exact tiled FFN-down reconstruction and requantization

Cycle 0023, run `20261004T050146Z-1f54a8f9`, 2026-10-04 UTC. Research only;
production and runtime untouched. No native build, GPU, downloaded code,
dependency installation, Git operation or full proof ran.

The final CPU experiment passes **260 schedules**, **3,380 independently
compared raw dots**, **9,508 accepted output/remainder plane words**,
**162 rounding edges**, **14 mutation controls** and **two invalid-int16
domain controls**. Outcomes: 178 accepted synthetic cases, 81 down refusals,
one residual refusal. Synthetic acceptance is arithmetic acceptance, never
an accepted proof or countable token. Execution: **1.252728 s**, **23,096 KiB
peak RSS**, one pinned low-priority Core Ultra 9 185H thread, Python 3.10.12,
seed 2026100423, estimated 64 MiB experiment memory, 512 MiB address-space cap
and 59-second alarm. Exact command/exit/logs are retained.

## Question and source seam

The previous cycle established the identity
`x = low + 256*high + 128` for inclusive signed-int16 input, with low/high
signed bytes. Two integer byte products plus a weight-column sum reconstruct
the exact down dot in i64. This cycle asks whether the output can be consumed
tile by tile instead of materializing whole partial and raw-accumulator planes.

Pinned `private_block/witness.rs:685` calls `quantize` on a temporary
`matmul_in_out` result. **The raw down accumulator is not retained**: only
`z16` and biased remainder `RDL` survive, followed by residual and limb work.
The candidate can eliminate that temporary locally. Final z16/RDL storage,
their commitment/proof obligations, h16 and fresh proof randomness remain.

Interface sketch: `tile-review.rs`, **uncompiled and unapplied**. Full-K tile
inputs are exact i32 low/high partials, identity-bound column sums and public
row/column metadata. Widen before combining; apply the full column correction
once; use the existing SH_Z=6 rounding and biased remainder; write only true
support into full-sized zero-padded outputs. A split-K route first reduces
partial pairs in tile-local i64, then does the same finalization. Never round
or range-check an incomplete K sum. Device integration would be new witness
GEMM/reconstruction plumbing beside `hashline/src/gpu/cuda.rs`/`kernels.cu`;
the existing field NTT/commitment uploader is not a witness GEMM adapter.

## Independent evidence and controls

The independent reference performs checked direct i64 products over the
entire padded K and materializes all padded output columns on true rows.
Its separate floor-division quotient/remainder oracle consumes true support
only. The candidate models stacked byte-product calls, public output tiles,
both weight orientations and forward/reverse tile completion. Raw dots are
independently compared even when both implementations refuse, so refusal
agreement cannot hide a wrong accumulator. Audit dictionaries are test-only
and are excluded from proposed GPU buffer accounting.

Dimensions: true M=1/2/3/5, K=1/3/17/31/129 and N=1/3/5/7;
padded M=2/4/8, K=2/4/32/256 and N=2/4/8; output tiles
(1,1)/(2,3)/(3,4)/(64,128), K tiles 1/7/31/full. Additional dot boundaries
K=1023/1024/1025/14336/16384, and K=262146 with 1024-wide reduction tiles.
The latter has an untiled byte-prefix overflow but exact i64 reconstruction;
its synthetic shift18 acceptance does not admit a production profile.
Rounding edges include shifts0/1/6/7/14/31 and inclusive int16 MIN/MAX.
Dirty internal K values are consumed; dirty padded token rows are ignored;
dirty padded output columns retain zero output/remainder. These helper
controls do not admit dirty padded proofs or alter upstream h16 validation.

Controls detect per-K rounding, premature K-range checks, residual-before-down
fusion, completion-order refusal selection, float32 partial conversion,
i32 reconstruction, dropped K padding, changed padded remainders, missing or
repeated column corrections, orientation and tie errors. A synthetic fixture
fails residual2 at an early output and down at a later output: down must win.
The internal first-support index is private test instrumentation; only the
unchanged static refusal site is proposed to the caller.

Initial execution failed at a **nondiscriminating control**: exact and
wrapped-i32 versions both refused the chosen shift6 fixture. Its script/logs
are preserved under `initial-nondiscriminating-control/`. A shift14 fixture
distinguishes them. An intermediate pass before independent raw-dot checks
is retained separately; final evidence strengthens that pass. No timing
comparison across these revisions is a speed measurement.

## Eliminated work, costs and lifetime-aware ceiling

Baseline CPU down allocates one full i64 accumulator, then final z16/RDL.
The alternative materialized split route packs two byte planes, computes two
i32 outputs, reconstructs full i64, drops scratch, then quantizes. The ledger
explicitly releases packed and partial buffers at their last reads before
counting that route's peak. It does not sum unrelated phase maxima.

Count-only public Llama3-8B metadata: T512, padded K16384, N4096. Geometry is
unadmitted, and these small experiments never allocate those matrices.
The local materialized split baseline peaks at **48 MiB** (32 MiB final
z16/RDL plus 16 MiB raw accumulator in the quantization phase).

| Output/K tile | Counted local payload | Difference vs 48 MiB | Stacked GEMM calls | Packing bytes total |
|---|---:|---:|---:|---:|
| 512×4096 / full | 64 MiB | **16 MiB worse** | 1 | 16 MiB |
| 64×4096 / full | 36 MiB | 12 MiB less | 8 | 16 MiB |
| 64×128 / full | 34.0625 MiB | 13.9375 MiB less | 256 | 16 MiB |
| 64×128 / 1024 | 32.25 MiB | 15.75 MiB less | 4096 | 512 MiB |
| 16×128 / full | 32.515625 MiB | 15.484375 MiB less | 1024 | 16 MiB |

Full-K row packing is reused across output-column tiles. The split-K schedule
re-packs for each output tile; its 512 MiB packing traffic is a decisive cost
warning. Naive logical weight reads for 64-row schedules total512 MiB versus
64 MiB once, before any device cache reuse. These are logical reads, not
measured DRAM transfers. Conceptual reconstruction calls follow GEMM calls;
custom persistent/grouped kernels could change launch counts but are not built.
Fine N/K tiling trades a small extra payload reduction for many calls.
Full-K K16384 already has a safe i32 byte-partial bound, so K-splitting is not
needed for this geometry's arithmetic safety.

Payload counts describe one abstract storage tier. They omit BLAS workspace,
host/device mirrors, pool retention, transfers/status flags, existing input,
weights, other witness planes and any preallocated destination placeholders.
Final planes remain32 MiB. No native peak or end-to-end saving is established.
Native output-plane overlap and lifetime measurements are required before
calling these whole-builder memory savings.

End-to-end ceiling for P accepted complete positions is
`P/(T-C_down_all_builds+C_pack+C_upload+C_byte_GEMM+C_reconstruct+C_download+C_sync)`.
No accepted8B term is measured. Historical 86.691s first-mark parent includes
witness/boundary/A fill, while73.36s initial-chain clock includes setup/census;
neither isolates down. Deleting BOTH entire parents from the retained
408.609226s synthetic twelve-block diagnostic leaves248.558226s (arithmetic
2.05988 positions/s). This loose parent bound is not a proposed saving or
private8B throughput. Earlier allocation-only attribution remains withdrawn.

Falsify on any raw-dot, output/remainder, support/padding, first-refusal,
native RNG/transcript/receipt divergence, added privacy leakage/new refusal,
or if actual peak/enclosing time fails to improve after packing, twice the
byte MAC work, synchronization, workspace and repeated reads are included.

## Search and next step

LIVE primary search checked September30 exact integer fast-matmul work,
September CUTLASS4.8 source/release contracts and older October25 2024
custom-epilogue instructions/code references. Dates, license scope, commit
qualification, exact URLs and GitHub errors are in `source-records.json` and
`search-log.md`. No author performance is reproduced or external code copied.
The recent exact fast-matmul lead is demoted pending full-domain (-128)
bounds and usable kernel performance; its own timing section reports a
regression, reinforcing this cycle's launch/traffic concern.

Owner next: isolate both witness passes and down timing, then validate the
coarse row/full-K adapter on actual complete witnesses and receipts under
the shared guard. Start with coarse row tiling rather than treating tiny
partial buffers as a throughput win. Preserve CPU fallback, fresh masks,
full native bytes/RNG/refusal parity and independent full-stack verification.
Next local experiment: public strided/grouped tile plan with row-pack reuse
and staggered completion; test whether batching can keep coarse-tile scratch
while avoiding the naive output-tile repacking/call multiplication. No build
or device job is launched by this research lane.

This cycle: CPU only, accepted complete private8B passes0, countable tokens0,
context null; steady/total rates, startup fraction, witness/proof/serialization/
independent verification, latency/lag/drain clocks null. No long-context
prefill/resident-pass/decode run. Longer workloads remain allowed; quadratic
attention and authenticated decode-state obligations stand. >=50/s unachieved.
