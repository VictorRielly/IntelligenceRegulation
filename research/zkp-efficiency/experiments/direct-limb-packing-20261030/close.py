import datetime, difflib, hashlib, json, pathlib
D=pathlib.Path(__file__).resolve().parent
R=D.parent.parent
run='20261030T064123Z-6637fd3d'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((D/'result.json').read_text())
assert result['status']=='PASS'
prior=json.loads((D/'prior-hypotheses.json').read_text())
h=json.loads((D/'hypotheses.json').read_text())
assert h[:len(prior)]==prior and len(h)==88
changes=[]
for p in json.loads((D/'startup-index.json').read_text()):
    if not p['path'].startswith(str(R)):
        b=pathlib.Path(p['path']).read_bytes();same=hashlib.sha256(b).hexdigest()==p['sha256']
        changes.append(dict(path=p['path'],unchanged=same,closing_sha256=hashlib.sha256(b).hexdigest()))
        if not same:
            dest=D/'closing-documents'/pathlib.Path(p['path']).name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(b)
            diff=''.join(difflib.unified_diff((D/p['snapshot']).read_text().splitlines(True),b.decode().splitlines(True),fromfile='startup/'+dest.name,tofile='closing/'+dest.name))
            (D/(dest.name+'.diff')).write_text(diff)
(D/'closing-doc-audit.json').write_text(json.dumps(changes,indent=2)+'\n')
native=[]
for p in json.loads((D/'source-pins.json').read_text()):
    native.append(dict(path=p['path'],unchanged=hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256']))
(D/'closing-native-audit.json').write_text(json.dumps(native,indent=2)+'\n')
execs={stage:json.loads((D/(stage+'-execution.json')).read_text()) for stage in ['compile','probe','audit']}
clocks='; '.join(f"{k}: {v['wall_s']:.3f} s / {v['max_rss_kib']:,} KiB maximum RSS" for k,v in execs.items())
metrics='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; only conditional historical cost accounting uses T128.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no accelerator.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model pass
series or decode ran. Larger workloads remain allowed; longer dense attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.'''
short='''**No measured proving improvement.** Direct explicit-limb packing passed
168 optimized Rust fixtures and 40 independently authored Python references.
In a nonempty four-vector helper, instrumented allocation requests fall from
five to one. At 3,517 rows, requested packing peak falls from 281,360 to
225,088 bytes; cumulative requested bytes fall from 450,176 to 225,088.
These measure a synthetic CPU host helper, not native GPU or proof performance.'''
next_action='''Next: owner measurements of exclusive packing, allocation, GPU initialization,
mutex wait/hold, H2D, kernel, D2H, conversion and synchronization, reconciled
with an enclosing independently verified workload. `secs_fold` starts after
GPU initialization and mutex acquisition, so that phase alone misses waits.
Keep actual current groups and capacity in the profile. Park further packing
or staging variants if removable costs are negligible. No lock move is proposed
without contention, capacity and failure-order evidence.'''
progress=f'''# ZKP efficiency progress

Cycle 0158 complete — `{run}`, October 30, 2026 UTC.
Checkpoint {now}.

{short}

The single-hunk review patch targets
`hashline/src/gpu/cuda.rs::dev_fold_rows`, replacing each temporary Vec with
ordered c0/c1 writes. Transfer payload, kernels, folds, masks and transcript
work are unchanged. Production source was not modified.

{next_action}

{metrics}

Four LIVE primary-source records saved (Rust Vec, ICICLE, StateSync-GKR and
zkLLMPoT); source fetch limits recorded. All 86 prior hypothesis records are
preserved; 87 is tested, 88 refines the mutex/timer measurement question.

[Experiment](experiments/direct-limb-packing-20261030/README.md) ·
[Handoff](handoffs/20261030-direct-limb-packing.md) ·
[Dated report](progress/{run}.md).
Saved reports do not establish user delivery or supervisor liveness.
'''
(R/'PROGRESS.md').write_text(progress)
details=f'''# Cycle 0158 — direct explicit-limb packing

Run `{run}`; started 2026-10-30T06:41:23Z;
checkpoint {now}; deadline 07:01:23Z.

{short}

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

{next_action}

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
Observed execution: {clocks}.
These shared-host correctness clocks are not witness/prover/GPU benchmarks.

{metrics}

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
'''
(D/'README.md').write_text(details)
(R/'progress'/f'{run}.md').write_text(details)
handoff=f'''# Review handoff: direct Fp2 limb packing

Run `{run}`; checkpoint {now}. No measured proving improvement.

Replace the per-rho temporary `as_u64s_f2` Vec in
`hashline/src/gpu/cuda.rs::dev_fold_rows` with explicit c0.0/c1.0 writes into
the existing reserved flat destination. Interface, assertion placement,
call-local lifetime and upload bytes are unchanged. Fp2 lacks repr(C);
never upload/cast raw Fp2 bytes. No production source was edited or merged.

Patch: `../experiments/direct-limb-packing-20261030/direct-pack-review-only.patch`.
Prototype and evidence: `native_pack.rs`, `packing.rs`, `source-pins.json`,
`result.json` in that experiment. 168Rust packing fixtures/458160limbs,
120native scalar-fold cases,40Python references/1600bigint output limbs,
11Rust and5Python negative-control families,49checked length cases.
Nonempty k=4 allocation requests5→1;rows3517 requested peak281360→225088B.
Instrumented optimized1.75CPU helper only; custom allocator makes calls
observable. The current production compiler and GPU were not evaluated.

Removed: temporary allocations and logical temporary writes/reads/copies.
Added: direct stores and existing push checks. No payload,launch,fold,
arithmetic,synchronization,proof-byte or fresh randomness saving. Conditional
historical A57 opening:72→15 host pack allocations,not a full8B result.
Ceiling N/(T-C_pack_exclusive+A_added),exclusive fractionunknown. Falsify on
negligible packing,compiler elision,net regression or any byte/order/refusal/
receipt/privacy mismatch. Do not promote solely from allocation counts.

Required owner validation: source-matched native CPU/GPU/forced-chunked
receipt-byte gates,extension/order/pad/proximity/fresh-call controls,
initialization/poison/shape/error/refusal ordering,actual current group/host
capacity census and exclusive packing/allocation/init/mutex-wait/hold/H2D/
kernel/D2H/conversion clocks in a complete independently verified workload.
secs_fold begins after gpu initialization and mutex acquisition; do not
interpret it as full call latency. No outside-mutex move is proposed without
measured contention and capacity/refusal review. Use shared heavy/build locks
and current guard for any owner native/GPU work; none launched here.

{metrics}

Main/Claude owns review/integration. Further packing/staging variants stay
parked until native costs warrant them. Full report:
`../progress/{run}.md`.
'''
(R/'handoffs'/'20261030-direct-limb-packing.md').write_text(handoff)
append='\n## Cycle 0158 — explicit host limb packing and omitted mutex waits\n\n'+details.split('\n\n',1)[1]
(D/'findings-append.md').write_text(append)
with (R/'FINDINGS.md').open('a') as f:f.write(append)
state=f'''# ZKP efficiency explorer — durable state

Cycle 0158 COMPLETE: `{run}`.
Started2026-10-30T06:41:23Z; checkpoint{now}.
Deadline07:01:23Z; next cycle no earlier than07:41:23Z.
Read AGENDA.md EVERY cycle.

{short}

{next_action}

Baseline helper was extracted verbatim from root dev_fold_rows/as_u64s_f2;
candidate writes identical explicit limbs into the reserved flat destination.
168fixtures compare458160limbs;120native scalar-fold cases pass.40Python
references match4000serialized limbs and1600bigint fold-output limbs.
11Rust/5Python negative-control families and49capacity plans pass.
Raw noncanonical representation tests do not admit invalid field values;
three synthetic tail columns are not generated PCS pads/privacy evidence.

Baseline/direct nonempty allocation requests:k+1/1; cumulative requested
bytes:32*k*rows/16*k*rows; packing peak:16*rows*(k+1)/16*k*rows.
Inputs,outputs/device/matrix,pads,allocator overhead/runtime are excluded.
Instrumented optimized1.75 helper results do not establish production
optimizer behavior,DRAM traffic,latency or native GPU/proving improvement.
Conditional historical T128A57 groups:72→15pack allocation requests.

Patch retains original assertion placement and unchecked length products;
the checked overflow planner is separate,not native profile admission.
No rawFp2 ABI cast,repr change,dependency/cache/mask/opening reuse.
Original max4 API remains. Native init/poison/allocation/refusal order,
async lifetimes,RNG/transcript/receipt bytes and privacy remain untested.
Ceiling:N/(T-C_pack_exclusive+A_added);perfect removal f<=1/(1-f),funknown.
Falsify on negligible packing,compiler elision,net regression or mismatch.

Global ranking:(1)complete verified high-endGPU workloads and resident
1/2/4/8passes;(2)admitted context/DD/fidelity;(3)exclusive phase/capacity.
All86prior hypotheses preserved;87tests86;88adds timer/mutex measurement
question. No new local packing/staging variant should outrank native clocks.
Four LIVE source records1045→1049. Rust specialization newly assessed;
ICICLE commit6c77775961b0e4dc2be359feec1ac11536c18043 inspected,
releaseyearunverified;October26GKR/October11zkLLMPoT refreshed. Exact
fetch blockers retained; no network bypass or foreign source execution.

Seed202610300641;oneCPUaffinity,nice19,onecodegenunit;40sCPU/45salarm/
50sparent/384MiBaddress-space cap per leaf. Compile memory estimate300MiB,
others96MiB. Auxiliary compiler thread countunmeasured;oneCPUat a time.
Clocks:{clocks}. These are correctness execution,not proof benchmarks.

{metrics}

Carried CPU8B baseline,not rerun/reverified/newly counted:T128,32layers,
one16-thread pass,GPUoff,total478.737s,0.267370positions/s. prove_run
393.785s includes witness98.348s/load17.595s;preceding sealing84.824s
includes overlapping load27.151s/witness80.897s. Receipt922711264B;
verify42.709s+13.681sload. Serialization/startup fraction/steadyunknown.
Never sum nested/overlapping clocks.

Owner05:30MVP status reports recovery/reverification of existing classifier
receipts;D46safeguards,D47fundinghold,D48release direction do not amend
private8B target or research permissions. Re-review remains not privacy
acceptance. No supervisor/job liveness inferred or heavy job duplicated.
Startup memory/pins:experiments/direct-limb-packing-20261030/startup-index.json.

[Experiment](experiments/direct-limb-packing-20261030/README.md) ·
[Handoff](handoffs/20261030-direct-limb-packing.md) ·
[Dated report](progress/{run}.md).
Only research outside runtime written;no production/Git/receipts/calibration/
instructions/safety/reviewer changes,GPU/nativebuild/install/external
write/message/escalation/merge. Saved reports do not establish delivery.
'''
(R/'STATE.md').write_text(state)
# Artifact manifest excludes itself and still-open close logs/execution/completion.
excluded={'artifact-manifest.json','close.stdout.log','close.stderr.log','close-execution.json','completion.json'}
manifest=[dict(path=str(p.relative_to(D)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(D.rglob('*')) if p.is_file() and p.name not in excluded]
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
completion=dict(status='COMPLETE',run_id=run,cycle='0158',checkpoint_utc=now,new_full_stack_proofs=0,new_proved_positions=0,target_achieved=False,
   native_source_unchanged=all(x['unchanged'] for x in native),owner_docs_unchanged=all(x['unchanged'] for x in changes),prior_hypotheses_preserved=True)
(D/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
print(json.dumps(completion))
