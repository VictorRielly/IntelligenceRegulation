"""Read-only evidence audit except this audit's own result. No native execution."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(30,30))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(35)
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
begin=time.monotonic();checks=0
def ck(v):
    global checks
    checks+=1
    assert v,checks
def read(name): return json.loads((HERE/name).read_text())
manifest=read('artifact-manifest.json')['files']
for entry in manifest:
    path=ROOT/entry['path']
    ck(path.is_relative_to(ROOT) and 'runtime' not in path.relative_to(ROOT).parts)
    b=path.read_bytes();ck(len(b)==entry['bytes']);ck(hashlib.sha256(b).hexdigest()==entry['sha256'])
for entry in read('native-pins.json'):
    ck(hashlib.sha256(Path(entry['path']).read_bytes()).hexdigest()==entry['sha256'])
for entry in read('startup-manifest.json'):
    path=Path(entry['path'])
    if not path.is_relative_to(ROOT): ck(hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'])
old=(HERE/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
new=(ROOT/'FINDINGS.md').read_bytes()
ck(new.startswith(old))
ck(new[len(old):].count(b'## Cycle 0136 ')==1)
oldsrc=(HERE/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
newsrc=(ROOT/'sources.jsonl').read_bytes();ck(newsrc.startswith(oldsrc))
rows=[json.loads(x) for x in newsrc.splitlines()];ck(len(rows)==901)
ck(len(oldsrc.splitlines())==891)
newrows=rows[891:];ck(newrows==read('sources-cycle.json'))
for row in newrows:
    ck(row['access_date']=='2026-10-29' and row['run_id']=='20261029T055649Z-74b83633')
    ck(row['external_execution']==row['reproduced_performance']==False)
    ck('publication_date' in row and 'verified_update_date' in row and 'implementation_license' in row)
    ck(row['url'].startswith('https://') and row['inspected_commit_id'] is None)
hyp=read('hypotheses.json');prior=read('prior-hypotheses.json')
ck(len(prior)==52 and len(hyp)==54 and hyp[:52]==prior)
ck([x['rank'] for x in hyp]==list(range(1,55)))
for h in hyp[-2:]:
    for k in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost',
              'exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']: ck(bool(h[k]))
res=read('result.json'); au=read('audit-result.json');ck(res['status']==au['status']=='PASS')
ck(res['checks']==1042 and len(res['fixtures'])==102 and len(res['negative_controls'])==13)
ck(res['seed']==202610290136 and res['cpu_affinity']==[0])
ck(res['elapsed_s']<45 and res['peak_rss_kib']<96*1024)
for name in ['probe-execution.json','audit-execution.json']:
    run=read(name);ck(run['exit_code']==0 and run['elapsed_s']<50)
    ck(run['threads']==1 and run['address_space_bytes']<=512*1024**2)
    ck(run['native_build']==run['gpu']==False)
for key in ['native_execution','gpu_execution']: ck(res[key]==False)
for key in ['complete_verified_proofs','complete_passes','proved_positions']: ck(res[key]==0)
target=read('target-accounting.json')
for key in ['witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s',
            'startup_fraction','proof_latency_s','proof_bytes','steady_state_positions_s',
            'total_workload_positions_s','model_context','model_accelerator']: ck(target[key] is None)
ck(target['larger_workloads_allowed'] and target['attention_quadratic_growth_caveat'])
ck(not any(target[k] for k in ['long_context_prefill','resident_model_proof_series','decode','target_achieved']))
adapter=read('adapter-manifest.json');ck(adapter['compiled']==adapter['applied']==False)
ck(not adapter['new_private_storage'])
for clock in read('startup/prior-historical-measurements.json'):
    ck(hashlib.sha256(Path(clock['path']).read_bytes()).hexdigest()==clock['sha256'])
clock=read('historical-extension-clocks.json')
ck(hashlib.sha256(Path(clock['path']).read_bytes()).hexdigest()==clock['sha256'])
for f in ['README.md','../../PROGRESS.md','../../STATE.md','../../progress/20261029T055649Z-74b83633.md',
          '../../handoffs/20261029-sc-tab-mask-tail-weights.md']:
    ck((HERE/f).is_file())
for textfile in ['../../STATE.md','../../PROGRESS.md','../../progress/20261029T055649Z-74b83633.md']:
    body=(HERE/textfile).read_text();ck('unmeasured' in body.lower());ck('unachieved' in body)
complete=read('completion.json');ck(complete['status']=='complete' and complete['new_proofs']==0)
now=datetime.datetime.now(datetime.timezone.utc)
ck(now<datetime.datetime.fromisoformat(complete['deadline_utc']))
out={'status':'PASS','checks':checks,'elapsed_s':time.monotonic()-begin,
     'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
     'audited_artifact_pins':len(manifest),'native_pins':8,'prior_sources_preserved':891,
     'prior_hypotheses_preserved':52,'prior_findings_preserved_bytes':len(old),
     'checkpoint_utc':now.isoformat(),'proving_gain_measured':False,'new_full_stack_proofs':0}
(HERE/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
