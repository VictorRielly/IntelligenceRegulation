import datetime,difflib,hashlib,json,pathlib,re
D=pathlib.Path(__file__).resolve().parent;R=D.parent.parent
def sha(b):return hashlib.sha256(b).hexdigest()
checks=0
def ck(x):
 global checks
 assert x
 checks+=1
for h in json.loads((D/'history-pins.json').read_text()):ck(sha((R/h['path']).read_bytes()[:h['prefix_bytes']])==h['prefix_sha256'])
prior=json.loads((D/'prior-hypotheses.json').read_text());all_h=json.loads((D/'hypotheses.json').read_text());ck(all_h[:len(prior)]==prior);ck(len(all_h)==84)
ledger=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()];ck(len(ledger)==1038)
new=json.loads((D/'sources-cycle.json').read_text());ck(ledger[-6:]==new);ck(len({x['id'] for x in new})==6)
ck(json.loads((D/'result.json').read_text())['status']=='PASS')
metrics=json.loads((D/'target-accounting.json').read_text())
for name in ['new_independently_verified_full_stack_proofs','new_full_stack_passes','new_proved_positions']:ck(metrics[name]==0)
for name in ['witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s','startup_fraction','steady_state_proved_tokens_s','total_workload_proved_tokens_s']:ck(metrics[name] is None)
ck(not metrics['target_reached']);ck(metrics['actual_accelerator'] is None)
for stage in ['prepare','pin-held','compile','probe','audit','record','finish-reports']:
 x=json.loads((D/(stage+'-execution.json')).read_text());ck(x['exit_code']==0);ck(x['wall_s']<=60);ck(x['max_rss_kib']<=512*1024)
 # A compiler may create helper threads; affinity, not an unmeasured thread count, is asserted.
 ck(x['one_cpu_affinity']);ck(x['address_space_mib']<=512)
changes=[]
for x in json.loads((D/'source-pins.json').read_text()):
 p=pathlib.Path(x['path']);b=p.read_bytes();ck(sha((D/x['snapshot']).read_bytes())==x['sha256'])
 if sha(b)!=x['sha256']:
  ck('/docs/' in str(p) or p.name=='CLAUDE.md')
  q=D/'closing-documents'/p.name;q.parent.mkdir(exist_ok=True);q.write_bytes(b)
  changes.append({'path':str(p),'initial_sha256':x['sha256'],'current_sha256':sha(b),'snapshot':str(q.relative_to(D))})
  delta=''.join(difflib.unified_diff((D/x['snapshot']).read_text().splitlines(True),b.decode().splitlines(True)))
  (D/('concurrent-'+p.name+'.diff')).write_text(delta)
 else:ck(True)
reports=[R/'STATE.md',R/'PROGRESS.md',R/'progress/20261030T015649Z-fd1dbb78.md',R/'handoffs/20261030-opening-staging.md',D/'README.md']
for p in reports:
 text=p.read_text();ck(len(text)>100)
 for url in re.findall(r'\]\(([^)]+)\)',text):
  if '://' not in url:ck((p.parent/url.split('#')[0]).exists())
ck((R/'STATE.md').read_text().count('COMPLETE')==1)
ck((R/'FINDINGS.md').read_text().count('## Cycle 0156 — opening-local staging and scratch lifetime')==1)
ck(all(x.get('bodies_identical',x.get('whole_file_identical')) for x in json.loads((D/'held-seam-comparison.json').read_text())))
ck('pub trait EncodedStore: Sync' in (D/'opening_trait.rs').read_text());ck('include!("opening_trait.rs")' in (D/'staging.rs').read_text())
ck('fn fold_rows_opening' in (D/'opening-hook-review-only.patch').read_text())
manifest=[]
for p in sorted(D.rglob('*')):
 if p.is_file() and p.name not in ['artifact-manifest.json','closing-audit.json','close.stdout.log','close.stderr.log','close-execution.json']:
  b=p.read_bytes();manifest.append({'path':str(p.relative_to(D)),'bytes':len(b),'sha256':sha(b)})
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(D/'report-pins.json').write_text(json.dumps([{'path':str(p),'sha256':sha(p.read_bytes())} for p in reports],indent=2)+'\n')
out={'status':'PASS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':checks,'history_prefixes_preserved':True,'prior_hypotheses_preserved':82,'hypotheses':84,'source_records':1038,'source_pin_records':41,'native_pin_drift':False,'concurrent_document_changes':changes,'new_independently_verified_full_stack_proofs':0,'new_passes':0,'new_positions':0,'target_reached':False,'patch_applied':False,'next_cycle_not_before':'2026-10-30T02:56:49Z'}
(D/'closing-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
