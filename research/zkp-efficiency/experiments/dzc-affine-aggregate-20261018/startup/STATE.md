# ZKP efficiency explorer — durable state

Cycle 0073 COMPLETE: `20261018T022105Z-6cb6453f`.
Next cycle no earlier than 2026-10-18 03:21:05 UTC.
Report: progress/20261018T022105Z-6cb6453f.md.

No native proving speedup measured. AGENDA, target, durable memory, current
project status/decisions/coordination and latest results consulted. Startup
records: experiments/fzc-derived-cost-audit-20261018/startup/; MVP status is
an aggregate-only summary, with original source hash retained. The original
383 source records are preserved; six LIVE records appended, 389 total.

New tested candidate: base-aware F derived-table construction plus proof-local
mu_pad*w coefficients. Main passes 120 fixtures, 4,644 baseline and 4,644
candidate values, 6,966 fold values, 1,944 offcube values, 600 counter checks,
120,744 unchanged source values and 10 controls. Independent 32-fixture audit
passes 2,960 full-F-polynomial comparisons, 720 original-cube terminal values,
2,072 prefix values and five controls. Main 0.439298 s including compilation,
RSS 17,584 KiB/compiler 24,716 KiB; audit 0.464633 s/RSS 15,944 KiB. One Core
Ultra 9 185H CPU0 thread, nice19, seeds2026101873/74, each59s/512MiB AS.
N2..64; larger shapes counted only. No native field/PTX/CUDA/proof/RNG/privacy
or runtime result. Artifacts: experiments/fzc-derived-cost-audit-20261018/.

Full-pad scalar products 53N -> 32N+33, constructor only; a Rust five-product
coefficient preparation costs55 instead33. Adds176B proof-local workspace.
Same source accesses, 32N derived table bytes and all folds. Generic N2/w11
loses27 products. Base after extension folding, stale coefficients, nonlinear
materialization, MSB reversal and missing final fold controls all catch errors.
Seam: gpu/fzc_kernels.cu::fzs_derive_impl/k_fzc_derive;
gpu/cuda.rs::DevFzcRounds::new; gpu/fzc.rs::FzcDesc::params.
Unapplied low-priority handoff: handoffs/20261018-base-aware-derived-build.md.

Owner round3 enclosing results now completed and fresh-process verified:
TinyLlama1.1B, T128, 22 blocks, one pass each, 16 CPU threads, RTX4070Laptop;
497,665,904B receipts, peak VRAM3,137MiB, zero declines. Default app174.052 /
process174.196237s, diagnostic0.735412positions/s; prove132.202 includes
15.473witness/11.181reload; initial load13.521, seal0.059, in-process verify
23.290. Fresh verifier load11.009+check9.394, process20.480536s. Warm app
216.500/process216.656004s, diagnostic0.591224positions/s; prove153.729
includes17.952witness/12.785reload; load29.322, seal0.100, in-process verify
24.227. Fresh verifier13.082+13.067, process26.236683s. Its22 spins total
6.6241s recurring. Load+seal7.802%/13.590% are phase fractions, not isolated
startup. Serialization, steady slope, prefill and lag/drain unknown. Shared
n1, different settings: no causal A/B or accepted trained-shape privacy.

Slot18 body3.409578/1.268204s, inclusive build0.952456/0.533091s. Deleting
ALL build removes only0.547%/0.246% of observed total application time; this
candidate touches a subset. Actual derive phase and8B ceiling remain unknown.
Default kernel timers are implausible/unsynchronized: do not infer bandwidth.
Thermal policy unchanged. Larger default phases: A row construction30.827s,
D zero-check26.691s, softmax11.381s; warm35.587/31.885/14.063s. Do not
relaunch owner jobs. Aggregate owner logs/hashes: owner-metrics.json.

Carried R5b8B T128:32 blocks, one cold CPU pass, 16threads, GPU off, shared n1.
App606.598/process606.728291s, diagnostic0.211013/0.210968positions/s.
Seal105.287s (17.357% phase, not startup), overlapping load36.570/witness
103.349. Prove501.126 includes122.694witness rebuild/21.176reload;
serialization unisolated. Fresh load14.126+check43.902s, reload18.459 inside
check, arithmetic remainder25.443. Verifier process186.088255 includes11
controls. Receipt922,711,264B; RSS6.55/cgroup8.47GiB. R5 accepts soundness
and T64/T128 arithmetic, not privacy; publication marker race assignedR6.
All previous baselines and negative findings remain preserved.

Ranked hypotheses:
1. OWNER whole-prover GPU arithmetic, especially D zero-check and A row work.
   Charge full adapter/build/fold/transfer/verification/drain costs. Reject
   any gate failure or absent enclosing gain. Full8B ceiling unknown.
2. OWNER immutable public residency and fixed-context fresh-pass slopes.
   Charge all recurring work and fresh private masks/openings. Reject stale
   identity, backlog or invalid state reuse; no measured steady slope exists.
3. TESTED base-aware derived constructor: low adapter cost, exact CPU result,
   tiny enclosing ceiling and generic small-N loss; profile derive first.
4. Prior root compression: exact table capacity opportunity, added shifts,
   cached uploads and unknown device benefit. GenericOT remains demoted.
5. Factored lookup/pending-fold/newPCS work: charge GKR/PCS/link/masking costs;
   preserve all joint-mask/offcube/singleton/D-C/wrapping/history negatives.

NEXT LOCAL: read fresh owner changes, then source-capture D zero-check's11
clauses and test an affine aggregate plus four bilinear terms against the
original full polynomial. Charge construction, extra table/folds and base
eligibility; compare earlier cubic/CSE negatives. Main/Claude owns device
ports and integration. Rotation next: lookup/softmax and memory; retain NTT,
sumcheck/GKR, batching/amortization, arithmetic/quantization and composition.

LIVE sources: known SumCATS refresh; extended sumcheck receivedMar24/approved
Mar25,2026 and Sep1 author explanation; NEW older Zhang precombined GKR
arrays (reportMay1,2025, thesis2023); Plonky3 rc.2 release tags16Oct with year
unverified, PR2293/2297 mergedSep22,2026. Full commit fetches failed; exposed
hashes are labeled uninspected. License/date/error scopes retained. No foreign
code executed or author performance reproduced.

New target proofs/passes/positions0/0/0. Target steady/total rates, startup
fraction and witness/proof/serialization/verification clocks unmeasured;
device none. No resident repeat series, long-context prefill or decode. Larger
workloads may amortize valid setup, but attention can grow quadratically and
decode needs proved state. >=50/s complete private8B on a high-end GPU remains
unchanged and unachieved. Fresh masks and privacy obligations remain.
Production/runtime/Git/receipts/calibration/safety/instructions/reviewer files
untouched; no installations, GPU/heavy jobs, external writes/messages or
escalation. Saved reports do not establish delivery.

Checkpoint: 2026-10-18T02:33:03.307626+00:00

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

Final checkpoint: 2026-10-18T02:33:50.623924+00:00
