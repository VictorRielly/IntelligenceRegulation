from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
D=Path(__file__).resolve().parent;W=D.parent.parent
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(35)
t=time.monotonic();checks=0
def ck(v):
 global checks
 checks+=1
 assert v
meta=json.loads((D/'memory-index.json').read_text())
for n in ['FINDINGS.md','sources.jsonl']:
 old=next(x for x in meta if x['path']==n);current=(W/n).read_bytes()
 ck(hashlib.sha256(current[:old['bytes']]).hexdigest()==old['sha256'])
for p in json.loads((D/'native-pins.json').read_text()):
 ck(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
 ck(hashlib.sha256((D/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
 ck(str(D/p['snapshot']).startswith(str(W/'experiments')))
hyp=json.loads((D/'hypotheses.json').read_text());prior=json.loads((D/'prior-hypotheses.json').read_text())
ck(len(hyp)==80);ck(hyp[:78]==prior);ck(len({x['rank'] for x in hyp})==80)
all_sources=[json.loads(s) for s in (W/'sources.jsonl').read_text().splitlines()]
cycle=[json.loads(s) for s in (D/'sources-cycle.jsonl').read_text().splitlines()]
ck(len(all_sources)==1027);ck(len(cycle)==5);ck(all_sources[-5:]==cycle)
ck('REFRESH' in cycle[3]['title']);ck(cycle[3]['prior_exact_url_records']==2)
ck(cycle[4]['prior_exact_url_records']==0);ck('NEW' in cycle[4]['title'])
ck(all(s['inspected_commit_id'] is None and not s['reproduced_performance'] and not s['external_execution'] for s in cycle))
for n in ['prepare','compile','probe','audit']:
 e=json.loads((D/(n+'-execution.json')).read_text());ck(e['exit_code']==0);ck(e['wall_s']<60);ck(e['max_rss_kib']<512*1024);ck(e['cpu_affinity']=='one');ck(not e['gpu'])
r=json.loads((D/'result.json').read_text());ck(r['status']=='PASS');ck(r['assertions']==11251);ck(r['fixtures']==12)
ck(r['python_negative_controls']+r['extracted_native_negative_controls']==252)
ck(all(p['equal'] for p in r['source_manifest_comparison'] if 'actual-build-2' in p['manifest']))
ck(sum(not p['equal'] for p in r['source_manifest_comparison'] if 'builders-2' in p['manifest'])==4)
for k in ['new_independently_verified_full_stack_proofs','new_complete_passes','new_proved_positions']:
 ck(json.loads((D/'target-accounting.json').read_text())[k]==0)
for n in ['steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s','startup_fraction','witness_s','proof_s','serialization_s','verification_s']:
 ck(json.loads((D/'target-accounting.json').read_text())[n] is None)
ck((W/'AGENDA.md').read_bytes()==(D/'prior-AGENDA.md').read_bytes())
ck(len(json.loads((D/'web-provenance.json').read_text()))+len(json.loads((D/'web-provenance-followup.json').read_text()))==16)
for p in [W/'PROGRESS.md',W/'STATE.md',W/'progress/20261029T235649Z-a82f1ea9.md',W/'handoffs/20261030-r14-fold-geometry.md']:
 ck(p.exists());ck(p.stat().st_size>100)
manifest=[]
for p in sorted(D.rglob('*')):
 if p.is_file() and p.name not in ['artifact-manifest.json','closing-audit-result.json']:
  b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
result=dict(status='PASS',assertions=checks,artifact_count=len(manifest),wall_s=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,source_pins=27,all_prior_source_and_findings_bytes_preserved=True,all_prior_hypotheses_preserved=True,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),note='Report/source correction retained. No re-run of native proofs or new performance claim.')
(D/'closing-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
