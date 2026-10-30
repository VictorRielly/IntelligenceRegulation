# Separate-proof round batching prerequisite — cycle0162

The actual frozen-R13 seam is `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`
called by `hashline/src/zk.rs::masked_prove_rounds` and the private block's
`argument.rs::run_slot`. `round(j)` returns UNMASKED values and has no transcript
or randomness authority; the driver applies its own CFS masker, absorbs one
message, draws one challenge, then folds. This study keeps the raw evaluator
unmasked and masks in its synthetic driver wrapper. A future batch interface
would return separate `(owner, site, generation, round, unmasked_values)`
results to each original transcript, then accept its challenge for fold.

The inspected R13 slot path uses ClosureRounds/GroupedEqRounds. The older
`gpu/cuda.rs::dev_zerocheck_blocks`/`dev_tab_zerocheck` are single-transcript
legacy layer/zk seams; changing those alone leaves the inspected R13 private
slot path unchanged. The GPU global mutex, synchronous round result copy,
memory pools, fresh masks, host dependencies and extension/terminal bindings
all need owner review. This is a local source screen, not general reachability
analysis. No drop-in native batch port is supplied or merged.

**No measured proving improvement.** A serial Rust batch interface and an
independently authored Python bigint reference agree on 42 synthetic fixture
groups, 126 scalar jobs and 378 Rust job runs (three schedules), with 21,744
limb comparisons and 22 controls. The reference sums the masking polynomial
over Boolean suffixes, uses a different interpolation expression, and checks
terminals by direct MLE weights. Rust uses pinned native field arithmetic and
CFS closed-form mask rounds; both match frozen R13 source. Transcripts use a
SHA256 surrogate, not native BLAKE3. No native prover, GPU, PCS, extension
rounds, grouped-equality recovery or privacy theorem was executed/established.

For four equal six-variable jobs, grouping changes **logical** evaluate/fold
submissions 48 -> 12 while live table payload grows 5 -> 20 KiB. Arithmetic
and per-proof masked messages/challenges remain unchanged. These are harness
command counts, not measured native kernel launches or saved wall time.
Ragged four-job counts are 36 -> 12 with 5 -> 9.375 KiB table payload. Payload
excludes witnesses, commitments, pools, allocator overhead and resident model.

Controls reject stale owners/sites/generations, duplicate descriptors,
premature folds/releases and zero mask multiplier. Main challenges 0 and 1
remain accepted. One deliberate negative is retained: a retagged wrong
challenge is accepted by the raw arithmetic API, then changes the next round
and fails the independent sumcheck identity. Retagged wrong mask content is
also detected by the reference, not authenticated by owner tags. This API
requires a trusted transcript/mask driver; tags alone are no binding proof.

Baseline: sequential independent proof arithmetic with one job admitted at a
time. Eliminated work: zero field operations; potential launch/dispatch work
only. Added costs: multiple live tables/masks/witnesses, result routing,
coefficients/challenges, synchronization, failure isolation, admission and
drain. Native ceiling is unknown: N/(T - C_launch_critical + A_batch), even
ideal launch elimination is bounded by N/(T-C_launch_critical). A necessary
50-token/s condition is T-C_launch_critical+A_batch <= N/50; no such measured
phase fraction exists here. Falsify on any per-proof scalar difference,
retagged/misrouted state, insufficient capacity, or added costs exceeding
exclusive launch savings. No numerical end-to-end speedup is inferred.

Owner priority: independently verified complete workloads on a named high-end
GPU at fixed admitted context, resident 1/2/4/8 passes, with startup/drain,
exclusive witness/proof/serialization/verification phases, peak capacity and
all failed/excluded attempts. Rank 2 remains admitted context/DD/fidelity
scaling; rank 3 remains native exclusive phase/capacity evidence. Local tested
hypothesis 94 is now parked pending materiality. New hypothesis 95 asks whether
public-capacity-admitted ready cohorts can avoid global barriers safely.
If native clocks remain unavailable, the next bounded local experiment is a
public logical-buffer admission calculation for cohorts 1/2/4 against one
frozen R13 slot, including other live commitments and a completed-buffer
retirement control. It must report unmeasured capacity components and cannot
assert actual fit or throughput. Do not repeat toy batch variants.

Patch/artifact location: `experiments/separate-proof-round-batch-20261030/batch.rs`, `native_mask.rs`, `reference.py`, `native-pins.json`, `native-seam-check.json`, `result.json`.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one affinity-pinned Intel Core Ultra 9
185H CPU worker; **no GPU**. Witness, proof, serialization, verification,
startup, initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. Synthetic
sumcheck variables 3–6 (8–64 table entries) are not model context lengths.
The complete private 8B **>=50 proved tokens/s target remains unachieved**.
Larger workloads remain allowed; increasing context may increase dense
attention work quadratically. No private masking values or openings reused
to improve amortization; fixed synthetic fixtures repeat only for differential tests.

Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer edit, downloaded-script execution, external write/
message, purchase, escalation, merge or job-liveness claim. Native owner/Claude
reviews any future integration. Saved reports do not establish message delivery.
