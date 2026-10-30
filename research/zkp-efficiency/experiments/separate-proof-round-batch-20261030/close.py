from pathlib import Path
import datetime, hashlib, json
D=Path(__file__).resolve().parent;R=D.parents[1];P=R.parents[1]
RUN='20261030T104123Z-3535232c'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((D/'result.json').read_text());assert result['status']=='PASS' and result['control_count']==22
for stage in ['prepare','compile','seam','audit']:
    assert json.loads((D/(stage+'-execution.json')).read_text())['exit_code']==0
compile=json.loads((D/'compile-execution.json').read_text());audit=json.loads((D/'audit-execution.json').read_text())
seam=json.loads((D/'native-seam-check.json').read_text());assert seam['argument_direct_legacy_gpu_calls']==0
hyp=json.loads((D/'hypotheses.json').read_text())
hyp[93]['cycle0162_status']='TESTED synthetic prerequisite, not native benefit: 42 groups/126 scalar jobs/378 Rust job runs/21,744 limb comparisons/22 controls. 4 equal n6 jobs:48->12 logical eval/fold submissions; table payload5->20KiB; field arithmetic unchanged. Retagged challenge accepted raw but independently detected; source points to SumcheckRounds, not legacy GPU API.'
hyp[93]['disposition']='Park further toy batching variants until native critical-path materiality and capacity evidence. This is no GPU port or privacy/soundness result.'
hyp[94]['disposition']='New source-informed queue question, not measured gain; bounded public-capacity admission accounting is the next local option if owner clocks remain absent.'
(D/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')
queue=json.loads((D.parent/'slot-batching-census-20261030/rotation-queue.json').read_text())
queue['cycle0162']='Separate-proof batch arithmetic/ownership prerequisite passed; zero native gain. New SET/Kernelet screens emphasize ready cohorts, completion and capacity, not repeated toy variants.'
queue['next_primary']='GPU NTT/commitments and memory traffic: actual public buffer capacity and exclusive phase incidence. Keep lookup/softmax, quantization and composition rotation.'
(D/'rotation-queue.json').write_text(json.dumps(queue,indent=2)+'\n')
target=dict(run_id=RUN,complete_independently_verified_full_stack_proofs=0,complete_model_passes=0,proved_positions=0,
    actual_context_length=None,synthetic_sumcheck_variables=[3,4,5,6],synthetic_table_entries=[8,16,32,64],
    device='One affinity-pinned Intel Core Ultra 9 185H CPU worker; no GPU',gpu_count=0,
    witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,initial_prefill_s=None,
    startup_fraction=None,steady_interval_s=None,total_workload_s=None,steady_proved_tokens_per_s=None,
    total_workload_proved_tokens_per_s=None,proof_latency_s=None,proof_bytes=None,
    workload_kinds_run=[],target_achieved=False,
    exclusion='All synthetic sumcheck tests excluded from proved-token numerator. No long-context prefill, resident-model passes or decode executed.')
(D/'target-accounting.json').write_text(json.dumps(target,indent=2)+'\n')
blockers=[
 dict(url='https://eprint.iacr.org/2024/1862.pdf',error='403 Forbidden',effect='No new PDF inspection; landing-page claim only.'),
 dict(url='https://developer.nvidia.com/blog/constructing-cuda-graphs-with-dynamic-parameters/',error='(400) Timeout fetching',effect='Used current official CUDA graph guide and already-readable older blog; no bypass.'),
 dict(url='https://github.com/ingonyama-zk/icicle/pull/946',error='Cache miss',effect='Release-note metadata only; no implementation inspection.'),
 dict(url='https://github.com/ingonyama-zk/icicle/tree/6c77775',error='Cache miss',effect='Abbreviated inspected commit only; full SHA not established.'),
 dict(url='https://github.com/AbdelStark/tessera/issues/470',error='Cache miss',effect='Unassessed search lead; no technical claim used.'),
 dict(url='https://github.com/NVlabs/mirage',error='Cache miss',effect='Unassessed search lead; no technical claim used.')]
(D/'web-blockers.json').write_text(json.dumps(blockers,indent=2)+'\n')
scope='''New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
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
'''
summary='''**No measured proving improvement.** A serial Rust batch interface and an
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
'''
baseline='''Baseline: sequential independent proof arithmetic with one job admitted at a
time. Eliminated work: zero field operations; potential launch/dispatch work
only. Added costs: multiple live tables/masks/witnesses, result routing,
coefficients/challenges, synchronization, failure isolation, admission and
drain. Native ceiling is unknown: N/(T - C_launch_critical + A_batch), even
ideal launch elimination is bounded by N/(T-C_launch_critical). A necessary
50-token/s condition is T-C_launch_critical+A_batch <= N/50; no such measured
phase fraction exists here. Falsify on any per-proof scalar difference,
retagged/misrouted state, insufficient capacity, or added costs exceeding
exclusive launch savings. No numerical end-to-end speedup is inferred.
'''
next_action='''Owner priority: independently verified complete workloads on a named high-end
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
'''
seam_text='''The actual frozen-R13 seam is `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`
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
'''
source_text='''Native LIVE primary search refreshed zkDuel (2026-10-26), BatchZK, ICICLE's
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
'''
historical='''Carried historical CPU8B baseline (not rerun/reverified or newly counted):
T128/L32, one 16-thread pass, GPU off, total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Earlier
sealing 84.824 s contains overlapping load 27.151 s / witness 80.897 s.
Receipt 922,711,264 B; verify 42.709 s plus 13.681 s load. Serialization,
startup fraction and steady slope unknown; never sum nested clocks. Latest
owner R18 record is a different 3B classifier scope: one shared-box batch
1418 s vs three singles 1453 s (one input, three categories), independently
reviewed with adoption conditions. It is not private8B/high-end-GPU evidence
or a measured startup fraction, and no such receipts are counted this cycle.
'''
resources=f'''Resource envelope per stage: one CPU affinity, nice 19, 30 s CPU / 40 s alarm /
45 s parent timeout, 384 MiB address cap; compile estimate 300 MiB, audit 64 MiB.
Final standalone Rust compile {compile['wall_s']:.3f} s / {compile['max_rss_kib']:,} KiB;
final audit {audit['wall_s']:.3f} s / {audit['max_rss_kib']:,} KiB. These are correctness
execution clocks, not proof clocks. Rust scalar baseline admits one job/process at
a time while batched runs keep multiple jobs; process timing is incomparable.
Commands, fixtures, seeds 601–604 / control 20261030, source hashes and raw logs
are retained. No native dependency build, GPU or installation occurred.
'''
rules='''Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer edit, downloaded-script execution, external write/
message, purchase, escalation, merge or job-liveness claim. Native owner/Claude
reviews any future integration. Saved reports do not establish message delivery.
'''
links=f'''[Experiment](experiments/{D.name}/README.md) · [Integration boundary](experiments/{D.name}/INTEGRATION.md) · [Dated report](progress/{RUN}.md).\n'''
readme='# Separate-proof masked-round batching prerequisite\n\n'+summary+'\n'+baseline+'\n'+seam_text+'\n'+scope+'\n'+resources+'''
Reproduce sequentially from the research directory:

```text
python3 experiments/separate-proof-round-batch-20261030/run_bounded.py prepare
python3 experiments/separate-proof-round-batch-20261030/run_bounded.py compile
python3 experiments/separate-proof-round-batch-20261030/run_bounded.py seam
python3 experiments/separate-proof-round-batch-20261030/run_bounded.py audit
```

`prepare` reconstructs source fixtures and resets the copied hypothesis ledger;
use a fresh research copy to preserve finalized evidence. `close.py` writes
reports and should not be used as an arithmetic test. `sources.py` has no
network calls; LIVE tool evidence is in web-*.json.
\n'''+next_action+'\n'+source_text+'\n'+rules
(D/'README.md').write_text(readme)
(D/'INTEGRATION.md').write_text('# Native integration boundary — research only\n\n'+seam_text+'\n'+baseline+'\n'+summary+'\n'+next_action+'\n'+rules)
handoff=R/'handoffs/20261030-separate-proof-round-batch.md'
handoff.write_text('# Separate-proof round batching prerequisite — cycle0162\n\n'+seam_text+'\n'+summary+'\n'+baseline+'\n'+next_action+'\n'+f'Patch/artifact location: `experiments/{D.name}/batch.rs`, `native_mask.rs`, `reference.py`, `native-pins.json`, `native-seam-check.json`, `result.json`.\n\n'+scope+'\n'+rules)
report=f'# Cycle0162 — {RUN}\n\nCheckpoint {now}; deadline11:01:23Z.\n\n'+summary+'\n'+baseline+'\n'+seam_text+'\n'+scope+'\n'+next_action+'\n'+source_text+'\n'+historical+'\n'+resources+'\n'+rules
(R/'progress'/f'{RUN}.md').write_text(report)
progress=f'''# ZKP efficiency progress

Cycle 0162 COMPLETE — `{RUN}`, checkpoint {now}.

**No measured proving improvement.** Independent-proof round batching passes
42 synthetic groups / 126 scalar jobs / 378 Rust job runs / 22 controls. Four
equal jobs group 48 logical eval/fold submissions into 12 but retain 4x table
payload and all arithmetic. Tags do not authenticate retagged challenges or
mask contents; independent checks detect those. Native benefit remains unknown.

'''+scope+'''
Next: the native owner measures verified fixed-context resident 1/2/4/8-pass
workloads with startup/drain, exclusive phase clocks and actual capacity.
Further toy batching variants are parked. If clocks remain absent, the next
local test counts public buffer capacity for cohorts 1/2/4 at one frozen R13
slot, including live commitments and completion-controlled retirement.

'''+links
(R/'PROGRESS.md').write_text(progress)
state=f'# ZKP efficiency explorer — durable state\n\nCycle 0162 COMPLETE: `{RUN}`.\nStarted 2026-10-30T10:41:23Z; checkpoint {now}.\nDeadline 11:01:23Z; next cycle no earlier than 11:41:23Z. Read AGENDA.md EVERY cycle.\n\n'+summary+'\n'+baseline+'\n'+seam_text+'\n'+next_action+'\nAll 94 previous hypotheses/negative results preserved; hypothesis 94 tested/refined and 95 added.\n\n'+scope+'\n'+historical+'\n'+source_text+'\n'+resources+'\n'+links+'\n'+rules
(R/'STATE.md').write_text(state)
findings=R/'FINDINGS.md'
if f'## Cycle0162 — {RUN}' not in findings.read_text():
    with findings.open('a') as f:f.write('\n\n'+f'## Cycle0162 — {RUN}\n\nCheckpoint {now}.\n\n'+summary+'\n'+baseline+'\n'+seam_text+'\n'+scope+'\n'+next_action+'\n'+source_text+'\n'+historical+'\n'+resources+'\n'+rules)
drift=[]
for pin in json.loads((D/'native-pins.json').read_text()):
    assert hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256']
    if hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()!=pin['sha256']:drift.append(pin['path'])
(D/'owner-source-recheck.json').write_text(json.dumps(dict(at=now,drift=drift,scope='Pinned experiment snapshots remain authoritative'),indent=2)+'\n')
manifest=[]
for f in sorted(D.rglob('*')):
    if f.is_file() and f.name not in ['artifact-manifest.json','completion.json','close-execution.json','close.stdout.log','close.stderr.log','final-audit.json','commands.jsonl']:
        b=f.read_bytes();manifest.append(dict(path=str(f.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(D/'completion.json').write_text(json.dumps(dict(run_id=RUN,cycle='0162',status='complete',checkpoint=now,
    arithmetic_status='PASS',full_stack_proofs=0,production_merge=False,manifest_entries=len(manifest)),indent=2)+'\n')
print(json.dumps(dict(status='complete',checkpoint=now,groups=result['fixture_groups'],controls=result['control_count'],manifest_entries=len(manifest),native_source_drift=drift)))
