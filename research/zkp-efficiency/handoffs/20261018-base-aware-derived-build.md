# Base-aware F derived-table construction — unapplied, low priority

Cycle0073, `20261018T022105Z-6cb6453f`. Native owner/Claude reviews and
integrates; no production changes, merge, device run or privacy acceptance.

The current round-3 `fzs_derive_impl` constructs affine `T_GL` and `T_PL`
using general Fp2 products even when the existing host BASE contract ensures
that A planes hold base-field values. Use scalar arithmetic for the three
affine forms, multiply each by its Fp2 mu with `f2_mul_base`, and prepare
`mu_pad*w_j` once per proof before the row loop. Keep the generic path.

Research candidate: `experiments/fzc-derived-cost-audit-20261018/candidate.hpp`.
Captured baseline and source hashes are in that directory's `native/` and
`source-pins.json`. `shim.cpp` exposes
`derive(tabs, L, supp, variant, base, original_params, counters)` only for the
serial CPU experiment. The candidate header is a review aid, not a complete
CUDA adapter or an apply-ready production patch.

Actual seams: `ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/fzc_kernels.cu`
`fzs_derive_impl` / `k_fzc_derive`; `gpu/cuda.rs::DevFzcRounds::new` construction around
`base_table`, `base` and the derive launch; `gpu/fzc.rs::FzcDesc::params`.
An implementation can append eleven proof-local weighted Fp2 coefficients
to the device parameter workspace and select a base-specialized derive
entry using the already checked BASE flag. Preserve the original pad weights
for the old public zero-weight skip predicate. Do not overwrite parameters
used by round kernels or the verifier/extension oracle. Recompute after this
proof's transcript challenges; no cross-proof coefficient cache.

Main CPU audit:120 fixtures,4,644 baseline and4,644 candidate derived values,
6,966 fold-commutation values,1,944 offcube values,600 counter checks and
120,744 untouched source values pass. Ten controls pass, including forced
base after an extension fold and stale mu. Independent audit:32 fixtures,
2,960 original full-F-polynomial comparisons,720 original-cube terminal
values,2,072 prefix reconstruction values and five controls pass. The latter
also catches MSB reversal, omitted final fold and invalid nonlinear
precomputation. Seeds2026101873/74; N2..64; canonical extremes and extension
values. Main0.4393s including compilation, audit0.4646s; one CoreUltra9 185H
CPU0 thread, nice19; each59s/512MiB address-space limit. No native field/PTX,
CUDA concurrency, transcript/RNG/receipt or GPU performance gate ran.

Counted Karatsuba scalar products per N-row constructor, w active pad weights:

| Case | Existing | Candidate, including one-time preparation |
|---|---:|---:|
| No support, base A |17N|10N|
| Support, base A |(20+3w)N|(10+2w)N+3w|
| Support, extension A |(20+3w)N|(17+3w)N+3w|

For all11 pad planes at N=2^20:55,574,528 ->33,554,465 counted scalar
products, a39.62% constructor-only reduction. Native `pad.rs` makes all F A
planes ZERO-rule on padded shapes, and layout's contiguous F range has11
planes; zeta nonzero means their powers do not vanish. Smaller/degenerate
public parameter cases are tested too. Rust's existing five-product Fp2 mul
would charge55 rather than33 scalar products for preparing11 coefficients;
device parameter packing/copy and dispatch also cost time.

Keep the owner's existing two derived tables and all their folds/finals.
They occupy32N bytes and add2(N-1) Fp2 fold products /96(N-1) source-level
fold bytes versus a layout without those two tables; those costs already
belong to round3 and are unchanged by this candidate. New workspace176B,
plus any padding/alignment. At N=2^20 this proposal does not remove the32MiB
derived tables. Source load/store counts are unchanged. The constructor
performs8+w explicit Fp2 loads and1+support stores per row; the owner's208N
byte counter is a unique-plane-union accounting convention at full padding,
not a measurement of repeated source loads or physical DRAM traffic.

Priority is low: retained round3 TinyLlama T128 runs took174.052s default
and216.500s with repeated warm-up spins, each fresh-process verified. Their
inclusive slot18 builds totaled0.952456/0.533091s. Even making *all* that
build work free would remove only0.547%/0.246% of observed total application
time; the candidate changes a subset. Derived-build time is not isolated.
No full8B timing ceiling or steady-state result follows. Generic N2,w11
loses27 counted scalar products due to coefficient setup; preserve a small-N
fallback or let measurement decide. No speedup has been measured.

Required owner gates: checked base provenance and generic fallback, all
original shapes/refusals, source/module-cache identity, every derived write
before read, unchanged finals and extension path, seeded CPU/GPU proof-byte
parity, fresh independent verification and normal privacy gates. Preserve
fresh masks and exact arithmetic. Falsify on any mismatch, changed refusal/
privacy behavior, peak/register regression, or no enclosing improvement.

Next local priority: audit slot14's eleven D clauses for an affine aggregate
plus four remaining bilinear terms, charge construction and folds, and compare
with the prior cubic/CSE negatives. Its26.691s default /31.885s warm phase
is larger than this constructor; an owner device port remains separate work.

## Final owner-source movement checkpoint

At the final hash check, the owner had begun round4 in `gpu/cuda.rs` and
`gpu/fzc_kernels.cu`. Captured round3 baseline/test hashes remain intact.
Separate snapshots/diffs are in `owner-update/`; the initial stable-source
assertion failure is retained as `audit-attempt-source-movement.json` and is
resolved as concurrent owner movement, not an arithmetic failure. No researcher
production write occurred.

Observed round4 code reads resident base/pair sources directly in rounds0/1,
derives GL/PL inside round0 through `fzs_derived_at`, uses mapped results, and
changes the default host tail. This cycle did not compile, test or measure
those changes. Rebase the handoff on BOTH `fzs_derived_at` and the standalone
`fzs_derive_impl` fallback; an old derive-only patch may miss the new default.
The base/mixed identities remain research candidates, but new inline register,
shared-memory, lifetime and synchronization costs need the owner's gates.
Round3's inclusive-build deletion bound is specific to its recorded runs;
round4 moves arithmetic into round0, so it is not a universal ceiling for
the new schedule. Do not transplant the old source-load/counter accounting.
Read the owner's newest results before another local experiment.
