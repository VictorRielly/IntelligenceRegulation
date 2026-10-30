"""One-time source-history correction; preserve initial artifacts and old ledgers."""
from pathlib import Path
import datetime,hashlib,json,shutil
D=Path(__file__).resolve().parent;W=D.parent.parent
RUN='20261029T235649Z-a82f1ea9';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
assert not (D/'source-history-correction.json').exists()
for name in ['sources-cycle.jsonl','completion.json']:
 shutil.copyfile(D/name,D/('initial-before-source-history-correction-'+name))
for p in [W/'STATE.md',W/'PROGRESS.md',W/'progress'/f'{RUN}.md']:
 shutil.copyfile(p,D/('initial-before-source-history-correction-'+p.name))
records=[json.loads(s) for s in (D/'sources-cycle.jsonl').read_text().splitlines()]
power=records[3]
power['title']='REFRESH older Power circuits GKR arithmetization compatibility screen'
power['assessment']=power['assessment'].replace('First ledger assessment. ','Already assessed in cycles0069 and0141. ')
power['history_correction']='Initial cycle draft incorrectly labelled NEW; full-ledger exact URL check found two prior records. Corrected only this cycle record; prior records preserved byte for byte.'
sisu=dict(id='cycle0154-source-5',cycle='0154',run_id=RUN,title='NEW older Sisu shared-pool commitment and pipeline-drain boundary',url='https://arxiv.org/abs/2404.10404',publication_date='2024-04-16',verified_update_date='2024-04-17',access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,evidence_kind='Native LIVE tools.web__run search/open/find; embedded instructions ignored',inspected_urls=['https://arxiv.org/html/2404.10404v2','https://github.com/sisu-network/sisu-bridge'],implementation_license='Repository declares MIT; full LICENSE body not inspected; no code adoption.',inspected_commit_id=None,prior_exact_url_records=0,date_evidence='Primary arXiv v1 Apr16,2024 and v2 Apr17,2024. Repository update date and commit not established.',blocked_urls=[],external_execution=False,reproduced_performance=False,assessment='First ledger assessment. Shared array uses designated worker slices and a leader completion barrier, trading extra constraints/cluster proofs for less communication. Two-stage overlap targets steady max-stage time, requiring startup/drain accounting. Repository explicitly prototype, not full Sisu. Architectural scheduling lead only: no single5090 gain or native privacy/soundness acceptance inferred.')
records.append(sisu)
memory=json.loads((D/'memory-index.json').read_text())
old_sources=next(x for x in memory if x['path']=='sources.jsonl')
ledger=(W/'sources.jsonl').read_bytes();prefix=ledger[:old_sources['bytes']]
assert hashlib.sha256(prefix).hexdigest()==old_sources['sha256']
assert len(prefix.decode().splitlines())==1022
current=ledger[old_sources['bytes']:].decode().splitlines()
assert len(current)==4 and all(json.loads(x)['run_id']==RUN for x in current)
assert not any('sisu' in s.lower() or '2404.10404' in s for s in prefix.decode().splitlines())
cycle=''.join(json.dumps(s,sort_keys=True)+'\n' for s in records)
(D/'sources-cycle.jsonl').write_text(cycle)
(W/'sources.jsonl').write_bytes(prefix+cycle.encode())
findmeta=next(x for x in memory if x['path']=='FINDINGS.md')
findall=(W/'FINDINGS.md').read_bytes();findprefix=findall[:findmeta['bytes']]
assert hashlib.sha256(findprefix).hexdigest()==findmeta['sha256']
append=findall[findmeta['bytes']:].decode()
(D/'initial-before-source-history-correction-findings-append.md').write_text(append)
def correct(s):
 s=s.replace('Newly screened older\n+[Power circuits]','Refreshed older\n+[Power circuits]')
 s=s.replace('Newly screened older\n[Power circuits]','Refreshed older\n[Power circuits]')
 s=s.replace('Four source records append1022→1026','Five source records append1022→1027')
 s=s.replace('licenses, blockers and11LIVE-call URL provenance entries.','licenses, blockers and16LIVE-call URL provenance entries.')
 s=s.replace('No foreign code was run\nor author performance reproduced.', 'Newly assessed [Sisu](https://arxiv.org/abs/2404.10404), submitted April16 and\nrevised April17,2024: designated shared-pool slices and a leader barrier\nreduce communication while adding constraints; stage overlap still needs\nstartup/drain accounting. Its repository calls itself a partial prototype.\nNo foreign code was run or author performance reproduced.')
 return s
append=correct(append);report=W/'progress'/f'{RUN}.md';report.write_text(correct(report.read_text()))
(W/'FINDINGS.md').write_bytes(findprefix+append.encode())
# The initial report is preserved above. Record the correction explicitly.
correction=dict(recorded_at_utc=now,issue='Power circuits incorrectly marked newly assessed; exact URL scan found cycles0069/0141.',resolution='Corrected current-cycle record4; added first Sisu assessment as record5. Initial draft artifacts retained; earlier1022source records and all priorFINDINGS bytes unchanged.',prior_sources_prefix_sha256=old_sources['sha256'],prior_findings_prefix_sha256=findmeta['sha256'])
(D/'source-history-correction.json').write_text(json.dumps(correction,indent=2)+'\n')
progress=f'''# ZKP efficiency progress

Cycle0154 complete — `{RUN}` (October29–30,2026 UTC).

**No native proving improvement found.** Twelve R14 public layouts match an
independent reference and retained native inventory: 11,251 assertions and
252 negative controls. These are Shieldstral 3B layouts. Four historical
census producer files differ from current source; current grouping remains
unmeasured. Fresh proximity adds one vector: 56 groups need 15 batches at
the current four-vector limit.

Next local test: exact five-vector final batch versus four-plus-one. Owner
priorities remain verified high-end GPU workloads and exclusive phase clocks.
Five LIVE source records saved, including the newly assessed older Sisu
shared-pool technique. Power circuits was a refresh; its initial NEW label
was corrected after a full-ledger check, with the first draft retained.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: none; modeled T128/T256; one pinned Core Ultra9
CPU worker. Witness, proof, serialization, verification, startup/initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
rates: **unmeasured**. No long-context prefill, resident passes or decode ran.
Larger workloads remain allowed; attention can grow quadratically.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

[Experiment](experiments/r14-fold-geometry-20261029/README.md) ·
[Handoff](handoffs/20261030-r14-fold-geometry.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish delivery or supervisor liveness.
'''
(W/'PROGRESS.md').write_text(progress)
state=f'''# ZKP efficiency explorer — durable state

Cycle0154 COMPLETE: `{RUN}`.
Started 2026-10-29T23:56:49Z; checkpoint {now}; deadline 00:16:49Z.
Next cycle no earlier than 2026-10-30T00:56:49 UTC. Read AGENDA every cycle.
Prior state/progress/agenda and all78 hypotheses are retained in
experiments/r14-fold-geometry-20261029/prior-*. Prior FINDINGS/source bytes
are preserved and hashed by source-history-correction.json.

No native proving improvement. Twelve public R14 layout fixtures match
extracted current SplitLayout/13 Shape methods, an independent Python
reference and historical native inventory: 11,251 assertions, 132 extracted
constructor/audit and120 Python controls. Seed202610290154. Native define,
actual groups/rhos/refusals, field arithmetic, FS, full PCS pads, CUDA,
complete receipts and privacy acceptance remain unrun.

T128/f_e9: nonDD A3517/H3272,111230976 words; DD A3395/H3116,106676224.
T256: nonDD A4065/H3978; DD A3639/H3454. These are explicit Shieldstral
3072/9216 layouts. R14's profile door names four Shieldstral profiles;
8B R13 counts do not transfer. External endpoints retain24 data+4 masks+
1 spare+2 proximity=31 rows; internal24+8+2=34. All data/component/mask
row bands are covered. No hidden data or reused masks/openings.

Historical generic groups A/H56/11(nonDD),58/12(DD) are conditional:
four producer endpoint/protocol/test/run files differ from current held
source. All11 pinned current native files match the284-file held manifest;
layout/shape/layout/argument_split/geometry also match the old producer.
Fresh proximity adds one rho BEFORE chunks4:57/12 or59/13 rhos. Ignoring
it misses one full A/nonDD or H/DD scan: logical matrix reads461373440B/
408420352B atT128. These are operands, not physical traffic or time.
Current internal endpoint grouping is unknown: four claims permit1..4
groups and1..2 batches. The counter model is a standalone generic core,
not a multi-block workload. Current secs_fold includes flatten/H2D/alloc/
kernel/D2H; exclusive fractions unknown.

All78 prior hypotheses preserved;#79 records this test,#80 asks whether a
five-vector final batch can replace4+1. Next local: a research-only exact
GoldilocksFp2 fold differential with independent scalar oracle, both limbs,
dense/sparse data, mask/proximity rows, output order and shape controls.
Falsify on any value/order/refusal mismatch; extra registers/spills can
erase gains. No CUDA candidate or production patch this cycle.
Global priorities:1 verified high-end GPU resident1/2/4/8 workloads,
2 admitted context/DD/fidelity scaling,3 exclusive phase/capacity clocks.
Ceiling N/(T-C_removed_exclusive+A_added); free deletion<=1/(1-f),f unknown.

Five LIVE source records1022→1027: StateSync October26v2/v1.2.1,zkIE,Jolt
Atlas,Power circuits refreshed; newly assessed Sisu2024 shared-pool
barriers/composition. Initial Power NEW label corrected after finding two
prior records; first draft retained. Exact URLs, dates/nulls, licenses,
blockers and16-call provenance retained. StateSync release link resolves
54e76515bf53777836221b88d7404a1ef67bcdd3; commit fetch failed, inspected
commit remains null. No author performance reproduced or foreign code run.
Next rotation: memory traffic,GPU NTT/commitments,quantization/arithmetic.

Owner state19:14:14 UTC is held-pipeline evidence, not liveness.22:50
classifier privacy remains DRAFT. A5 one-post/one-process reuse is not
generic cache authority. Matched two-block owner CPU timings omit initial
preparation and later verification. Do not duplicate held builds.

One pinned nice19 Core Ultra9 185H worker. Standalone compile0.772s/
158724KiB; probe0.004s/7772KiB; final audit0.217s/18440KiB. Each stage:
40s CPU,45s alarm,50s parent timeout,384MiB address cap; estimated300MiB
compile/96MiB others. Compiler auxiliary threads unmeasured; one CPU
affinity/codegen unit. Initial passing result retained;27 pins unchanged.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: none; modeled T128/T256. Witness, proof,
serialization, verification, startup/initial-prefill clocks, startup fraction,
proof latency/bytes, steady-state and total-workload rates: unmeasured.
No long-context prefill, resident series or decode ran. Larger workloads
remain allowed; attention can grow quadratically. Complete private8B
**>=50 proved tokens/s remains unachieved**.

Carried older CPU8B baseline, not rerun/reverified/newly counted: T128/L32,
one16-thread pass,GPUoff. Total478.737s=0.267370 positions/s;
prove_run393.785s includes witness98.348/load17.595. Sealing84.824s precedes
it, with overlapping load27.151/witness80.897. Receipt922711264B;
verify42.709+load13.681s. Serialization/startup fraction/steady slope unknown.

[Experiment](experiments/r14-fold-geometry-20261029/README.md) ·
[Handoff](handoffs/20261030-r14-fold-geometry.md) ·
[Dated report](progress/{RUN}.md).
Only research outside runtime written; no production/Git/receipt/calibration/
instruction/safety/reviewer edits, GPU/native build, install, downloaded
script, external write/message, purchase, escalation or merge. Main/Claude
reviews/integrates. Saved reports do not imply delivery or liveness.
'''
(W/'STATE.md').write_text(state)
completion=json.loads((D/'completion.json').read_text());completion.update(completed_at_utc=now,sources_added=5,source_history_correction=True)
(D/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
print(json.dumps(dict(status='CORRECTED',sources=5,prior_records_preserved=1022,checkpoint=now)))
