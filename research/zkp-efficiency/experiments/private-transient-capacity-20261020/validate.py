"""Final provenance, resource, result and report consistency; no native run."""
from pathlib import Path
import json,hashlib,time,resource,os,datetime
H=Path(__file__).resolve().parent;R=H.parents[1];CHECKS=0

def ck(v,msg=''):
 global CHECKS
 CHECKS+=1
 assert v,msg

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 t=time.perf_counter();changed=[]
 for n in ['source-manifest.json','extra-source-manifest.json']:
  for row in json.loads((H/n).read_text()):
   ck(sha(H/'source'/row['snapshot'])==row['sha256'],row['snapshot'])
   live=sha(Path(row['path']));ck(live==row['sha256'],row['path'])
 for row in json.loads((H/'final-direction-manifest.json').read_text()):
  ck(sha(Path(row['path']))==row['sha256'],row['path']);ck(row['matches_startup'],'Direction changed before final checkpoint')
 old=(H/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes();ck((R/'FINDINGS.md').read_bytes().startswith(old),'prior findings altered')
 old=(H/'startup/research__zkp-efficiency__sources.jsonl').read_bytes();ledger=(R/'sources.jsonl').read_bytes();ck(ledger.startswith(old),'prior source records altered')
 rows=[json.loads(x) for x in ledger.decode().splitlines()];ck(len(rows)==548)
 batch=json.loads((H/'source-records.json').read_text());ck(rows[-10:]==batch)
 for r in batch:
  ck(r['access_date']=='2026-10-20' and r['run_id']=='20261020T031854Z-e03e28dc')
  ck(not r['external_execution'] and not r['reproduced_performance'])
  ck(all(k in r for k in ['published','updated','date_evidence','implementation_license','inspected_commit_id']))
 ck(batch[7]['published']=='2024-02-02')
 m=json.loads((H/'model-result.json').read_text());a=json.loads((H/'audit-result.json').read_text());l=json.loads((H/'layout-result.json').read_text())
 ck((m['cases'],m['events'])==(72,23094));ck((a['checks'],a['negative_controls'])==(646591,441));ck((l['fixtures'],l['checks'],l['negative_controls'])==(30,535848,121))
 for x in [m,a,l]:ck(x['threads']==1 and len(x['affinity'])==1 and x['wall_seconds']<60 and x['rss_kib']<512*1024)
 cmd=json.loads((H/'commands.json').read_text())
 for leaf in ['model.py','audit.py','layout_probe.py']:
  r=next(x for x in cmd[::-1] if x['leaf']==leaf);ck(r['exit_code']==0 and r['sha256']==sha(H/leaf),leaf)
  ck(r['limits']['cpu_s']<=60 and r['limits']['alarm_s']<=60 and r['limits']['address_space_bytes']<=512*1024**2 and r['limits']['threads']==1)
 p=json.loads((H/'layout-projection.json').read_text());ck(len(p)==72)
 for x in p:
  ck(x['baseline_tabs']-x['mixed_tabs']==17*x['T']*16384*8)
  if x['mode']=='resident':ck(x['backing_saving']==0)
 ex=next(x for x in p if x['T']==128 and x['mode']=='chunked' and x['supp']==1 and not x['compact'] and x['repetitions']==1)
 ck(ex['baseline_tabs']==736*2**20 and ex['mixed_tabs']==464*2**20 and ex['backing_saving']==272*2**20)
 complete=json.loads((H/'completion.json').read_text());ck(complete['status']=='complete' and complete['countable_positions']==0 and not complete['native_build'] and not complete['gpu_job'] and complete['production_patch'] is None)
 ck(datetime.datetime.now(datetime.timezone.utc)<datetime.datetime(2026,10,20,3,38,54,tzinfo=datetime.timezone.utc),'deadline')
 for name in ['STATE.md','PROGRESS.md','FINDINGS.md','progress/20261020T031854Z-e03e28dc.md']:
  s=(R/name).read_text();ck('20261020T031854Z-e03e28dc' in s)
 for name in ['README.md','hypotheses.json','source-facts.json','layout-cases.json','layout-projection.json','search-log.json']:
  ck((H/name).is_file(),name)
 ck((R/'handoffs/20261020-mixed-fzc-arena.md').is_file())
 report=(H/'README.md').read_text();ck('535848' in report and '121 controls' in report and 'not measured VRAM' in report)
 ck(len(json.loads((H/'hypotheses.json').read_text()))>=3)
 # Pin final artifacts and external research reports,excluding self-changing
 # validation outputs and this wrapper's commands record.
 manifest=[]
 for q in sorted(H.rglob('*')):
  if q.is_file() and q.name not in ['artifact-manifest.json','validation-result.json','commands.json'] and 'validate.py.' not in q.name:
   manifest.append(dict(path=str(q.relative_to(R)),bytes=q.stat().st_size,sha256=sha(q)))
 for name in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','handoffs/20261020-mixed-fzc-arena.md','progress/20261020T031854Z-e03e28dc.md']:
  q=R/name;manifest.append(dict(path=name,bytes=q.stat().st_size,sha256=sha(q)))
 (H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 res=dict(status='PASS',checks=CHECKS,artifact_pins=len(manifest),changed_live_sources=changed,prior_findings_and_source_prefix_preserved=True,source_records_before=538,source_records_after=548,estimated_experiment_memory_mib=128,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Provenance,resources,reports only; no native proof or privacy review')
 (H/'validation-result.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res))
if __name__=='__main__':main()
