"""Final provenance, resource and reporting checks; no native proof work."""
import datetime,hashlib,json,os,pathlib,resource,time
H=pathlib.Path(__file__).resolve().parent;R=H.parent.parent;P=R.parent.parent
RUN='20261020T021854Z-e084e681'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 t=time.perf_counter();checks=0
 def ck(v):
  nonlocal checks
  checks+=1;assert v
 for row in json.loads((H/'input-manifest.json').read_text()):ck(sha(H/'startup'/row['snapshot'])==row['sha256'])
 changed=[]
 for name in ['source-manifest.json','extra-source-manifest.json']:
  for row in json.loads((H/name).read_text()):
   ck(sha(H/'source'/row['snapshot'])==row['sha256'])
   if sha(pathlib.Path(row['path']))!=row['sha256']:changed.append(row['path'])
 before=[json.loads(x) for x in (H/'startup/research__zkp-efficiency__sources.jsonl').read_text().splitlines() if x]
 after=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines() if x]
 ck(len(before)==531);ck(after[:len(before)]==before)
 records=json.loads((H/'source-records.json').read_text())
 ck(after[len(before):]==records);ck(len(after)==538)
 for s in records:
  for k in ['access_date','url','published','updated','implementation_license','inspected_commit_id','assessment']:ck(k in s)
  ck(s['reproduced_performance'] is False);ck(s['external_execution'] is False)
 res=json.loads((H/'result.json').read_text());mod=json.loads((H/'model-result.json').read_text())
 ck(res['status']=='PASS');ck(res['checks']==182348);ck(res['negative_controls']==330)
 ck(mod['full_stack']['independently_verified_proofs']==0);ck(mod['full_stack']['positions']==0)
 ck(mod['full_stack']['steady_positions_per_s'] is None);ck(mod['full_stack']['startup_fraction'] is None)
 for row in json.loads((H/'capacity.json').read_text()):
  ck(row['release_only_saving_bytes']==0)
  ck(row['output_pooled_backing_released_by_drop_bytes']==0)
  ck(row['persistent_owner_peak_bytes']-row['output_evicted_peak_bytes']==row['output_evicted_peak_saving_bytes'])
 ck(len(json.loads((H/'hypotheses.json').read_text()))>=3)
 for name in ['AGENDA.md','STATE.md','PROGRESS.md','FINDINGS.md']:
  s=(R/name).read_text();ck(bool(s))
  if name!='AGENDA.md':ck(RUN in s)
 ck((R/'progress'/f'{RUN}.md').exists());ck((R/'handoffs/20261020-private-stage-lifetimes.md').exists())
 # A changing production document is recorded as concurrency, never edited.
 directions=[]
 for name in ['AGENDA.md']:
  live=R/name
  snap=H/'startup'/('research__zkp-efficiency__'+name)
  directions.append(dict(path=str(live),sha256=sha(live),matches_startup=sha(live)==sha(snap)))
 for name in ['MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']:
  live=P/'docs/zkmatrix-poc'/name;snap=H/'startup'/('docs__zkmatrix-poc__'+name)
  directions.append(dict(path=str(live),sha256=sha(live),matches_startup=sha(live)==sha(snap)))
 (H/'final-direction-manifest.json').write_text(json.dumps(directions,indent=2)+'\n')
 cmds=json.loads((H/'commands.json').read_text())
 for row in cmds:
  ck(row['wall_seconds']<=60);ck(row['maxrss_kib']<512*1024)
  ck(row['limits']['threads']==1);ck(row['limits']['address_space_bytes']==512*1024**2)
 # Pin research artifacts, including reports. Exclude this output and the
 # wrapper command ledger, which is appended after this leaf completes.
 artifacts=[]
 for p in sorted(H.rglob('*')):
  if p.is_file() and p.name not in ['artifact-manifest.json','validation-result.json','commands.json'] and not p.name.endswith(('.stdout.log','.stderr.log')):
   artifacts.append(dict(path=str(p.relative_to(R)),sha256=sha(p),bytes=p.stat().st_size))
 for p in [R/'STATE.md',R/'PROGRESS.md',R/'FINDINGS.md',R/'sources.jsonl',R/'progress'/f'{RUN}.md',R/'handoffs/20261020-private-stage-lifetimes.md']:
  artifacts.append(dict(path=str(p.relative_to(R)),sha256=sha(p),bytes=p.stat().st_size))
 (H/'artifact-manifest.json').write_text(json.dumps(artifacts,indent=2)+'\n')
 result=dict(status='PASS',checks=checks,source_records_before=len(before),source_records_after=len(after),artifact_pins=len(artifacts),changed_live_source_paths=changed,changed_direction_paths=[x['path'] for x in directions if not x['matches_startup']],wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Provenance/resources/report consistency only; no native proof')
 (H/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
