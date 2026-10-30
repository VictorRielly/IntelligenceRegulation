# ZKP efficiency explorer — durable state

Cycle 0162 COMPLETE: `20261030T104123Z-3535232c`.
Started 2026-10-30T10:41:23Z; checkpoint 2026-10-30T10:54:53.112075+00:00.
Deadline 11:01:23Z; next cycle no earlier than 11:41:23Z. Read AGENDA.md EVERY cycle.

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

All 94 previous hypotheses/negative results preserved; hypothesis 94 tested/refined and 95 added.

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

Carried historical CPU8B baseline (not rerun/reverified or newly counted):
T128/L32, one 16-thread pass, GPU off, total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Earlier
sealing 84.824 s contains overlapping load 27.151 s / witness 80.897 s.
Receipt 922,711,264 B; verify 42.709 s plus 13.681 s load. Serialization,
startup fraction and steady slope unknown; never sum nested clocks. Latest
owner R18 record is a different 3B classifier scope: one shared-box batch
1418 s vs three singles 1453 s (one input, three categories), independently
reviewed with adoption conditions. It is not private8B/high-end-GPU evidence
or a measured startup fraction, and no such receipts are counted this cycle.

Native LIVE primary search refreshed zkDuel (2026-10-26), BatchZK, ICICLE's
observed v4 release/docs, CUDA graph restrictions and CFS2017. Newly assessed
[SET](https://arxiv.org/abs/2606.05495) (2026-06-03) retains per-worker buffers
and completion-driven return, on non-ZKP workloads. Older
[Kernelet](https://arxiv.org/abs/1303.5164) (2013-03-21) slices independent thread
blocks and adds scheduling work; complementary resource use is a prerequisite.
Neither author's throughput is reproduced or transferred to this prover.
ICICLE docs still explicitly exclude extension-field challenges. Its inspected
version-bump commit is only the displayed abbreviated `6c77775`; no full SHA or
exact release year/date was established. Main MIT license body was inspected;
README distinguishes specially licensed non-exposed backends. PDF403/cache-miss/
timeout blockers and precise dates/licenses/pins are retained in source records.
Nine records append to 1,070 prior source records. No downloaded code executed.

Resource envelope per stage: one CPU affinity, nice 19, 30 s CPU / 40 s alarm /
45 s parent timeout, 384 MiB address cap; compile estimate 300 MiB, audit 64 MiB.
Final standalone Rust compile 1.577 s / 168,992 KiB;
final audit 1.324 s / 25,152 KiB. These are correctness
execution clocks, not proof clocks. Rust scalar baseline admits one job/process at
a time while batched runs keep multiple jobs; process timing is incomparable.
Commands, fixtures, seeds 601–604 / control 20261030, source hashes and raw logs
are retained. No native dependency build, GPU or installation occurred.

[Experiment](experiments/separate-proof-round-batch-20261030/README.md) · [Integration boundary](experiments/separate-proof-round-batch-20261030/INTEGRATION.md) · [Dated report](progress/20261030T104123Z-3535232c.md).

Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer edit, downloaded-script execution, external write/
message, purchase, escalation, merge or job-liveness claim. Native owner/Claude
reviews any future integration. Saved reports do not establish message delivery.
