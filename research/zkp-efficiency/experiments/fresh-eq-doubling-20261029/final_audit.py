from pathlib import Path
import json,hashlib,datetime
H=Path(__file__).resolve().parent;R=H.parent.parent;checks=0
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ck((R/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()),'all prior findings preserved')
ck((R/'sources.jsonl').read_bytes().startswith((H/'startup/sources.jsonl').read_bytes()),'all prior sources preserved')
ck(len((R/'sources.jsonl').read_text().splitlines())==971,'source count')
old=json.loads((H/'startup/prior-hypotheses.json').read_text());cur=json.loads((H/'hypotheses.json').read_text());ck(cur[:-1]==old and len(cur)==62,'all61 prior hypotheses retained')
for pinfile in ['native-pins.json','consumer-pins.json']:
 for p in json.loads((H/pinfile).read_text()):
  ck(sha(Path(p['path']))==p['sha256'],'source unchanged');ck(sha(H/p['snapshot'])==p['sha256'],'snapshot pin')
for p in json.loads((H/'required-reading-index.json').read_text()):
 if '/docs/'in p['path']or p['path'].endswith('/CLAUDE.md'):ck(sha(Path(p['path']))==p['sha256'],'owner documents unchanged')
for n in ['compile','probe','account','audit']:
 e=json.loads((H/(n+'-execution.json')).read_text());ck(e['exit_code']==0,'all experiment stages pass');ck(e['elapsed_s']<60 and e['max_rss_kib']<512*1024,'resource limits');ck(e['one_cpu_affinity']and not e['gpu'],'oneCPU/noGPU')
for c in json.loads((H/'costs.json').read_text()):
 for k in ['fixed_eq','mask_eval_eq','pcs_data_row_eq_partial']:
  x=c[k];ck(x['nonempty_vector_payload_allocations_retained']==x['calls']+sum(int(n)>0 and v or 0 for n,v in x['log_histogram'].items()),'empty reverse Vec not counted as heap allocation')
target=json.loads((H/'target-accounting.json').read_text());ck(target['full_stack_proofs']==target['model_passes']==target['proved_positions']==0,'zero new proved work')
for k in ['model_context','witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s','startup_fraction','steady_tokens_per_s','total_tokens_per_s','proof_bytes']:ck(target[k]is None,'unmeasured remains null')
run='20261029T145649Z-fb1b89ab'
for path in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{run}.md',R/'handoffs/20261029-fresh-eq-doubling.md',H/'README.md']:
 s=path.read_text();ck(run in s,'correct run identity');ck('unmeasured'in s and 'unachieved'in s,'full target limits explicit');ck('0 / 0 / 0'in s,'proof/pass/token counts explicit')
ck((R/'STATE.md').read_text().count('Cycle0145 COMPLETE')==1,'state complete')
ck((R/'FINDINGS.md').read_text().count('## Cycle0145 ')==1,'findings append once')
now=datetime.datetime.now(datetime.timezone.utc);ck(now<datetime.datetime(2026,10,29,15,16,49,tzinfo=datetime.timezone.utc),'deadline met')
result=dict(status='PASS',checks=checks,checkpoint_utc=now.isoformat(),native_pins=14,owner_documents_unchanged=True,prior_findings_and_sources_preserved=True,prior_hypotheses_preserved=61,source_records=971,full_stack_proofs=0)
(H/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
manifest=[]
for p in sorted(H.rglob('*')):
 if p.is_file()and p.name not in ['artifact-manifest.json']:manifest.append(dict(path=str(p.relative_to(H)),sha256=sha(p),bytes=p.stat().st_size))
(H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(result))
