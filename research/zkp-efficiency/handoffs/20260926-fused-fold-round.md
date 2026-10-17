# Research handoff: fold and next-round sampling

**Exact small oracle passes; logical traffic falls; speed is unmeasured.**
Main/Claude owns review and integration. No production edits, build, Git or
GPU operation occurred. Run `20260926T205233Z-79c00f5e`, cycle 0005.

Artifacts: [experiment and commands](../experiments/fused-fold-round-20260926/README.md),
[results](../experiments/fused-fold-round-20260926/result.json),
[source pins](../experiments/fused-fold-round-20260926/source-pins.json),
[serial Rust sketch](../experiments/fused-fold-round-20260926/fused_fold_measure.proposed.rs).
The sketch is unapplied and uncompiled; it is not an approved speed patch.

## Interface and placement

Candidate seam `/tmp/zk60-groups-20260926/zkp-core/src/sumcheck/rounds.rs`:
an additive `SumcheckRounds` evaluator can use the helper
`fused_fold_measure(tables, r, degree, next_unmasked_claim, poly)` inside
`fold(r)` and save its optional next-round vector in `ready`. Preserve
the existing `pending` vector for the round the driver has requested. The
initial `round` stays ordinary; later `round` consumes `ready`; final fold
has no ready value. No driver/API/transcript change is needed by the design.

At N=4q, the paired endpoints for the next variable are folds of quarters
(0,2) and (1,3). Both are sampled before leaving the loop and stored in
quarters (0,1). Endpoint loads fall by one next-table traversal per transition.
No full folded-table allocation is needed. Serial helper scratch is
2K + degree+1 Fp2 values plus scalar registers, and the evaluator caches
degree+1 samples. Safe parallel quarter-slice borrowing remains owner work;
do not replace a parallel production evaluator with this serial sketch.

`private_block/argument.rs:556` constructs the generic evaluator; `:553`
constructs the existing grouped one. SC_SZC fusion needs its own grouped
sampler adaptation, with claims/prefixes updated before suffix setup and zero
factors evaluated explicitly. Retain the original equality tables and order
for final openings. The toy degree-2/3 experiment does not test this port.

## Validation and value

108 differential cases; 180 direct-MLE round checks; 432 final MLEs; 54
synthetic masked-driver comparisons; eight mutations, ten schedule and eight
fixture refusals. Full-extension data, zero factors, final/no-round cases,
chunk tails and reversed chunk processing pass. 2.7433 s / 17,700 KiB,
one CPU. Native masks/RNG/extension rounds/receipts were not executed.

For K=4, N=1024, modeled table reads+writes fall 327,360 -> 261,952 bytes,
19.98%, with unchanged polynomial call counts. No timing ratio follows:
the avoided read may hit cache, fusion may increase register pressure, and
parallelizing over tables is different from parallelizing over index tiles.

The measured source slot is significant (9.858/9.686 s in recent R2a CPU
logs), but deleting all of it would save only about 20.4% of the known
witness+prove+serialization sum. Fusion saves much less work than that.
Whole-slot clocks lack fold/round/cache attribution; measure these before
budgeting any end-to-end gain. Verification .98/.99 s from bytes is separate.
No complete private 8B/512 or GPU clock exists for this candidate.

## Review gate and next step

First port to an opt-in evaluator in the owner's lane and compare against
the original round implementation in debug/release, including supplied exact
private claims and unseeded inconsistent host claims. Preserve masked
transcript values, challenges, RNG consumption, table finals, native extension
rounds and corrupt-receipt refusals. Then adapt grouped SC_SZC without losing
its equality-factor savings. Build/heavy-lock tests are proposed, not queued.

Only after native parity should phase timers and logical/actual traffic be
compared under equal parallelism. A CPU improvement will not establish a GPU
improvement. A kernel improvement will not establish complete readiness at
50 proved tokens/s. D22/D19b/D23 and all current privacy boundaries stand.
