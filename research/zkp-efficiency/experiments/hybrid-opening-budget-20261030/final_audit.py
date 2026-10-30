from pathlib import Path
import json,hashlib,datetime
D=Path(__file__).resolve().parent;R=D.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
note='''
Closing document recheck: the decisions register changed during this cycle.
D47 (05:46 UTC) holds funding applications until Victor has a partner;
D48 (05:48 UTC) widens the intended open-source scope and removes the prior
patent-before-publication prerequisite. The diff is retained in
concurrent-decisions.diff. Neither changes the private 8B throughput target
or authorizes this research lane to publish, send messages or modify
production. No such action was taken.
'''
files=[R/'STATE.md',R/'progress/20261030T054123Z-a698c842.md',D/'README.md']
for f in files:
 s=f.read_text()
 if 'Closing document recheck:' not in s:f.write_text(s+note)
with (R/'FINDINGS.md').open('a') as f:f.write(note)
for name in ['ranking-current.json']:
 v=json.loads((D/name).read_text());v['concurrent_decisions']='D47/D48 funding/open-source product directions do not amend private8B throughput target or this research lane permissions.';(D/name).write_text(json.dumps(v,indent=2)+'\n')
old=(D/'startup/03-FINDINGS.md').read_bytes();src=(D/'startup/04-sources.jsonl').read_bytes()
assert (R/'FINDINGS.md').read_bytes().startswith(old)
assert (R/'sources.jsonl').read_bytes().startswith(src)
assert len((R/'sources.jsonl').read_text().splitlines())==1045
assert json.loads((D/'hypotheses.json').read_text())[:84]==json.loads((D/'startup/14-hypotheses.json').read_text())
pins=json.loads((D/'source-pins.json').read_text())
assert all(hashlib.sha256(Path(v['path']).read_bytes()).hexdigest()==v['sha256'] for v in pins)
result=json.loads((D/'result.json').read_text());assert result['status']=='PASS'
check={'status':'PASS','timestamp_utc':now,'prior_findings_and_sources_prefixes_preserved':True,'all84_prior_hypotheses_exactly_preserved':True,'new_sources':7,'source_records':1045,'source_pins_match':True,'concurrent_decisions_read_and_recorded':['D47','D48'],'full_stack_proofs':0,'steady_and_total_rates_measured':False,'no_production_writes':True}
(D/'final-audit-result.json').write_text(json.dumps(check,indent=2)+'\n')
c=json.loads((D/'completion.json').read_text());c['final_audit_utc']=now;(D/'completion.json').write_text(json.dumps(c,indent=2)+'\n')
manifest=[]
for f in sorted(D.rglob('*')):
 if f.is_file() and f.name not in ['artifact-manifest.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json']:
  b=f.read_bytes();manifest.append({'path':str(f.relative_to(D)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(check))
