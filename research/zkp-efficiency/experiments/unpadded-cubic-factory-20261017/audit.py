"""Bounded evidence-integrity audit, no native program or network execution."""
import ast,datetime,hashlib,json,os,resource,signal
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
signal.alarm(20);resource.setrlimit(resource.RLIMIT_CPU,(20,20));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
checks=[]
def ck(ok,label):
 assert ok,label
 checks.append(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((HERE/'result.json').read_text());cmd=json.loads((HERE/'command.json').read_text());ex=json.loads((HERE/'execution.json').read_text())
ck(ex['exit_code']==0,'final exit0');ck(r['status']=='passed','experiment passed')
ck(r['run_id']=='20261017T042624Z-0f7bf604','run identity')
ck(r['wall_seconds']<60 and r['max_rss_kib']<512*1024,'experiment wall/memory caps')
ck(r['hardware']['threads']==1 and r['hardware']['nice']==19 and r['hardware']['device']=='CPU only','one low-priority CPU thread')
for fn,h in cmd['source_sha256'].items():ck(sha(HERE/fn)==h,'executed source hash:'+fn)
for p in HERE.glob('*.py'):ast.parse(p.read_text());ck(True,'parse:'+p.name)
for item in json.loads((HERE/'startup-manifest.json').read_text()):ck(sha(ROOT/item['path'])==item['sha256'],'startup hash:'+item['path'])
old=(HERE/'startup/FINDINGS.md').read_bytes();ck((ROOT/'FINDINGS.md').read_bytes().startswith(old),'historical findings preserved')
old=(HERE/'startup/sources.jsonl').read_bytes();ck((ROOT/'sources.jsonl').read_bytes().startswith(old),'historical sources preserved')
ss=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x]
ck(len(ss)==276,'276 total source records');new_ids=[s['id'] for s in ss[-7:]];ck(len(set(new_ids))==7 and not any(x in {s.get('id',s.get('source_id')) for s in ss[:-7]} for x in new_ids),'seven new unique source ids;historical schemas preserved')
cs=json.loads((HERE/'sources-cycle54.json').read_text());ck(len(cs)==7 and ss[-7:]==cs,'source append exact')
for s in cs:
 ck(s['access_date']=='2026-10-17' and s['url'].startswith('https://'),'source access/url:'+s['id'])
 ck('published' in s and 'updated' in s and 'implementation_license' in s and 'inspected_commit_id' in s,'source metadata:'+s['id'])
 ck(not s['reproduced_performance'],'author performance unclaimed:'+s['id'])
for q in json.loads((HERE/'native-pins.json').read_text()):
 ck(sha(Path(q['path']))==q['sha256'],'current native/measurement pin:'+q['path'])
 ck(sha(HERE/q['snapshot'])==q['sha256'],'native/measurement snapshot:'+q['snapshot'])
seams=json.loads((HERE/'active-seam-comparison.json').read_text())
for q in seams:ck(sha(Path(q['path']))==q['sha256'],'active seam:'+q['path'])
ck(seams[0]['sha256']==seams[2]['sha256'] and seams[1]['sha256']==seams[3]['sha256'],'candidate=sonnet argument/grouped')
ck(seams[-1]['sha256']!=seams[0]['sha256'],'root main distinct')
want={'fixtures':63,'full_schedules':1890,'independent_round_samples':19650,'independent_final_values':43920,'independent_extension_checks':144,'value_independent_row_censuses':12,'executed_vs_allocation_free_censuses':20,'padded_factory_refusals':3}
for k,v in want.items():ck(r['counts'][k]==v,'count:'+k)
ck(r['recoveries']==732 and r['zero_factor_fallbacks']==708,'claim recovery/fallback coverage')
for name in ['drop_cubic','reverse_coefficients','omit_suffix_weight','drop_part','drop_ragged']:ck(name+'-detected' in r['controls'],'negative control:'+name)
ck(len(r['projections'])==6,'six no-allocation projections')
for p in r['projections']:
 nr=(1<<p['n'])-1;ck(p['total_rows']==nr,'geometric row count')
 for mode,v in p['results'].items():
  cc=v['all_field_ops'];ck(sum(cc.values())==v['sum_api_ops'],'API total:'+mode)
  exp=v['literal_native_field_api_expansion'];ck(exp['fp_mul']==5*cc.get('mul',0)+2*cc.get('mul_base',0),'Fp mul expansion:'+mode)
  ck(exp['fp_add']==2*cc.get('mul',0)+2*cc.get('add',0) and exp['fp_sub']==2*cc.get('sub',0),'Fp add/sub expansion:'+mode)
  schedules=p['schedules'][mode];ck(sum(s['rows'] for s in schedules)==nr,'schedule rows:'+mode)
  for k in ('mul','mul_base','add','sub'):
   total=sum(s['round_field_ops'].get(k,0) for s in schedules)+v['preparation'].get(k,0)
   ck(total==cc.get(k,0),'independent schedule total:'+mode+':'+k)
  ck(v['coefficient_words'] in (0,4) and v['native_peak_scratch_bytes'] is None,'output-only scratch label:'+mode)
  if mode=='cubic_round0':
   ck(sum(s['coefficient_group0'] for s in schedules)==1 and schedules[0]['coefficient_group0'],'roundzero-only policy')
   ck(all(v['delta_vs_prepared_scalar'][k]<0 for k in ('mul','mul_base','add','sub')),'roundzero all field categories lower')
pa=r['proof_accounting'];ck(pa['accepted_complete_private_8b_proofs']==0 and pa['passes']==0 and pa['proved_tokens']==0,'no accepted full8B credit')
for k,v in pa.items():
 if k not in ('accepted_complete_private_8b_proofs','passes','proved_tokens'):ck(v is None,'unmeasured target field:'+k)
ck(r['output_sha256']==json.loads((HERE/'before-self-contained-accounting-input/result.json').read_text())['output_sha256'],'self-contained accounting input unchanged outputs')
report=ROOT/'progress/20261017T042624Z-0f7bf604.md';ck(report.read_bytes()==(ROOT/'PROGRESS.md').read_bytes(),'dated/current progress parity')
for name in ['README.md','checkpoint.json','research-source-diff.patch','copy-provenance.json']:ck((HERE/name).exists(),'artifact:'+name)
for p in [ROOT/'STATE.md',ROOT/'FINDINGS.md',ROOT/'PROGRESS.md',report,ROOT/'handoffs/20261017-unpadded-cubic-round0.md']:
 ck('20261017T042624Z-0f7bf604' in p.read_text(),'report identity:'+str(p))
# Check whether owner memory moved during this cycle. Read only; no claim of liveness.
project=ROOT.parents[1];changes=[]
for name,orig in [('CLAUDE.md','CLAUDE.md'),('MVP_STATUS.md','docs/zkmatrix-poc/MVP_STATUS.md'),('ZK60_DECISIONS.md','docs/zkmatrix-poc/ZK60_DECISIONS.md'),('ZK60_CODEX_FABLE_COORDINATION.md','docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md'),('ZK60_THROUGHPUT_TARGET.md','docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md')]:
 if sha(HERE/'startup'/name)!=sha(project/orig):changes.append(orig)
result=dict(status='passed',checks=len(checks),check_labels=checks,checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),owner_memory_changed=changes,
 audited_artifact_sha256={str(p.relative_to(ROOT)):sha(p) for p in [HERE/'result.json',HERE/'command.json',HERE/'execution.json',HERE/'README.md',ROOT/'STATE.md',ROOT/'FINDINGS.md',ROOT/'sources.jsonl',ROOT/'PROGRESS.md',report,ROOT/'handoffs/20261017-unpadded-cubic-round0.md']})
(HERE/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('check_labels','audited_artifact_sha256')}))
