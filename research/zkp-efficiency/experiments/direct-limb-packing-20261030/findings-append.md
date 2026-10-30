
## Cycle 0158 — explicit host limb packing and omitted mutex waits

Run `20261030T064123Z-6637fd3d`; started 2026-10-30T06:41:23Z;
checkpoint 2026-10-30T06:52:49.356272+00:00; deadline 07:01:23Z.

**No measured proving improvement.** Direct explicit-limb packing passed
168 optimized Rust fixtures and 40 independently authored Python references.
In a nonempty four-vector helper, instrumented allocation requests fall from
five to one. At 3,517 rows, requested packing peak falls from 281,360 to
225,088 bytes; cumulative requested bytes fall from 450,176 to 225,088.
These measure a synthetic CPU host helper, not native GPU or proof performance.

Baseline and candidate use the pinned native field. The baseline packing
helper and allocation/shape loop were extracted verbatim from current root
source. The candidate replaces `flat.extend(as_u64s_f2(rho))` with the same
explicit c0.0/c1.0 stores into the already reserved destination. It retains
the original k=1..4 assertion, per-vector length assertions and multiplication.
The standalone checked-length oracle is separate; the patch does not add
profile admission or repair pre-existing unchecked launch/capacity arithmetic.

Rows 0/1/3/7/33/257/3517, k=1/2/3/4 and six value patterns give 168 fixtures
and 458,160 compared limbs. Patterns include random canonical values, P-1,
pure imaginary values, limb boundaries, protected-tail stand-ins and raw
noncanonical limbs. The last group verifies representation preservation
only; it does not admit invalid field inputs. The 120 canonical scalar-fold
cases use the exact native host body with only Rayon iteration made serial,
against independently written u128 arithmetic. Three tail columns are
synthetic controls, not generated PCS pads or native privacy evidence.

Forty exported synthetic vectors match 4,000 Python serialization limbs and
1,600 Python bigint fold-output limbs. Python whole sums use unbounded
integers and reduce once per output limb. Eleven Rust negative controls
cover vector-count/length refusals, swapped/reordered/missing limbs/vectors,
fresh calls and split-limb layout. Five independent Python corruption
families reject; 49 separate capacity/usize-overflow plans agree. The 1,406
Python assertions are correctness accounting, not security strength.

The optimized instrumented executable observes k+1 versus one nonempty
allocation, zero reallocations, cumulative requested bytes 32*k*rows versus
16*k*rows, and requested packing peak 16*rows*(k+1) versus 16*k*rows.
Zero-row helpers allocate neither. This excludes inputs, outputs/downloads,
device allocations, matrix/pads, allocator overhead and other runtime state.
The custom System allocator counters make calls observable; production
toolchains, optimization, actual physical traffic and elapsed benefit still
need owner measurement. No packing latency benchmark was performed.

| Conditional historical T128 f_e9 role | k / chunks | Pack allocation requests, baseline → direct | Peak requested packing B, baseline → direct |
|---|---:|---:|---:|
| A non-DD | 57 / 15 | 72 → 15 | 281,360 → 225,088 |
| H non-DD | 12 / 3 | 15 → 3 | 261,760 → 209,408 |
| A DD | 59 / 15 | 74 → 15 | 271,600 → 217,280 |
| H DD | 13 / 4 | 17 → 4 | 249,280 → 199,424 |

These are conditional sums of current max-four pack helper calls over prior
historical groups, not a current 8B census, full-workload memory or GPU gain.
Transfers, matrix scans, arithmetic, launches, proof bytes and fresh masks
are unchanged. Removed work is limited to temporary allocations and logical
temporary writes/reads/copies; hardware DRAM movement was not measured.
Added costs are direct stores and existing push capacity checks.
End-to-end ceiling is `N/(T-C_pack_exclusive+A_added)`; ideal free removal of
exclusive fraction f gives at most `1/(1-f)`. f is unknown. Falsify if native
packing is negligible, optimizer already removes costs, direct writes lose
more than allocation/copy removal saves, or any native byte/order/refusal/
receipt/privacy behavior differs. No numerical GPU/8B rate follows.

Global ranking remains: (1) complete verified high-end GPU workloads and
fixed-context resident 1/2/4/8 passes; (2) admitted context/DD/fidelity scaling;
(3) exclusive phase/capacity clocks. Local record 87 tests prior 86; new 88
asks whether host packing can safely leave the GPU mutex only if actual
contention matters. All 86 prior records are exactly preserved. Source
`dev_fold_rows` calls gpu(), obtains the mutex and clones dev before t0;
secs_fold omits those waits while including packing and synchronous calls.
This is a source observation, not a contention measurement or lock patch.

Next: owner measurements of exclusive packing, allocation, GPU initialization,
mutex wait/hold, H2D, kernel, D2H, conversion and synchronization, reconciled
with an enclosing independently verified workload. `secs_fold` starts after
GPU initialization and mutex acquisition, so that phase alone misses waits.
Keep actual current groups and capacity in the profile. Park further packing
or staging variants if removable costs are negligible. No lock move is proposed
without contention, capacity and failure-order evidence.

The integration interface is unchanged:
`dev_fold_rows(&DevCommit, &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String>`.
Patch: `direct-pack-review-only.patch`; runnable prototypes: `native_pack.rs`
and `packing.rs`. Main/Claude reviews and integrates; no merge or native
override was performed. Keep call-local ownership and explicit limbs:
native Fp2 has no repr(C). No buffer, mask, pad, proximity, private opening,
challenge or RNG reuse is proposed. Device ABI/lifetimes, native init/poison/
allocation failure order, actual FS/RNG parity, byte-identical receipts,
malformed native behavior and P1/P3 privacy gates remain untested here.

Commands from the research root, each bounded independently:

```sh
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py bootstrap
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py prepare
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py compile
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py probe
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py audit
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py record
python3 -B experiments/direct-limb-packing-20261030/run_bounded.py close
```

`bootstrap`, `record` and `close` write checkpoints/append history; they are
not idempotent rerun targets. For reproduction use prepare/compile/probe/audit
in a separate research copy; all generated input data is synthetic. Pin
manifest: `source-pins.json`; startup memory: `startup-index.json`; exported
vectors, allocation counters and results are adjacent. Seed 202610300641.
Compiler rustc1.75.0, commit82e1608dfa6e0b5569232559e3d385fea5a93112,
LLVM17.0.6, opt-level2, one codegen unit. Foreign source was never executed.

One CPU affinity, nice19, OMP/Rayon/BLAS/MKL thread counts1, 40-second CPU
limit, 45-second alarm, 50-second parent timeout and 384MiB address-space
cap per leaf. Estimated compile memory300MiB, other stages96MiB. Compiler
auxiliary thread count was not measured; one CPU could run at a time.
Observed execution: compile: 1.829 s / 166,164 KiB maximum RSS; probe: 0.033 s / 7,608 KiB maximum RSS; audit: 0.033 s / 15,844 KiB maximum RSS.
These shared-host correctness clocks are not witness/prover/GPU benchmarks.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; only conditional historical cost accounting uses T128.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no accelerator.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model pass
series or decode ran. Larger workloads remain allowed; longer dense attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

Carried historical CPU8B baseline, not rerun/reverified/newly counted:
T128,32layers,one16-thread pass,GPUoff;total478.737s,0.267370positions/s.
prove_run393.785s contains witness98.348s and load17.595s. Preceding sealing
84.824s contains overlapping load27.151s and witness80.897s. Receipt
922,711,264B; verification42.709s plus13.681s load. Serialization,startup
fraction and steady slope unknown. Do not add nested/overlapping clocks.

Four native LIVE primary-source records were appended, 1045 → 1049.
The new older technique assessed is Rust Vec extension specialization:
the inspected source appends an IntoIter slice and deallocates its source;
do not assume preallocation removes temporary ownership costs. Current
rustdoc is not the tested1.75 source pin. The source-oriented inference was
tested with local allocator counters. [Rust source](https://doc.rust-lang.org/src/alloc/vec/spec_extend.rs.html).

The repository release screen inspected ICICLE's two-file version-bump
commit6c77775961b0e4dc2be359feec1ac11536c18043 and its root MIT license.
Its field/Program interface changes do not establish exact native Fp2,
masking or device compatibility. Release display11Jul has no verified year.
Targeted wrapper and API fetches failed; no upgrade was attempted.
[ICICLE release](https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0).

The current October26 StateSync-GKR v2 distinguishes prepared arithmetic,
queue/reply costs and verified completion, reinforcing phase-boundary and
request-identity obligations. Its CPU sparse-Merkle measurements are author
claims for another workload. [Paper](https://arxiv.org/abs/2610.14849).
The October11 zkLLMPoT revision certifies checkpoint properties by forward
evaluation, with a different audit/privacy relation; abstract refreshed only.
[Paper](https://arxiv.org/abs/2610.08258). No author performance reproduced.
Exact access/publication/update dates or nulls, implementation license scope,
inspected commit and exact fetch blockers are in `sources-cycle.json` and
`blockers.json`; all six web response batches were retained.

Owner docs remain read-only. The05:30MVP status reports crash recovery and
reverification of existing public classifier receipts, not new proofs here.
D46 safeguards,D47 funding hold and D48 release direction do not amend this
private8B target or this lane's write authority. The classifier statement's
latest re-review still says not a privacy acceptance. No supervisor/job
liveness was inferred and no main heavy job was duplicated.

Only research files outside runtime were written. No production,Git
metadata/operations,receipts,calibration,instructions,safety gates or reviewer
files changed. No GPU/native build/install/downloaded script/external
write/message/purchase/escalation/merge. Saved reports do not establish user
delivery or supervisor liveness.
