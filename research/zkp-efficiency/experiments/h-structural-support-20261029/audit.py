from pathlib import Path
import json,hashlib,datetime
D=Path(__file__).resolve().parent;R=D.parent.parent;checks=[]
def ck(name,v):
 checks.append(dict(name=name,passed=bool(v)))
 assert v,name
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def extract(s,name):
 at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;b=s.index('{',at);depth=1;i=b+1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]+'\n'
for p in json.loads((D/'native-pins.json').read_text()):
 ck('snapshot '+p['snapshot'],sha(D/p['snapshot'])==p['sha256']);ck('immutable source '+p['path'],sha(Path(p['path']))==p['sha256'])
mem=json.loads((D/'memory-index.json').read_text());owner=[]
for p in mem['snapshots']:
 ck('startup '+p['snapshot'],sha(D/'startup'/p['snapshot'])==p['sha256'])
 if p['snapshot'] in ['AGENDA.md','CLAUDE.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']:
  b=Path(p['path']).read_bytes();h=hashlib.sha256(b).hexdigest();owner.append(dict(path=p['path'],start=p['sha256'],end=h,unchanged=h==p['sha256']))
  if h!=p['sha256']:(D/'startup'/('closing-'+p['snapshot'])).write_bytes(b)
(D/'owner-document-recheck.json').write_text(json.dumps(owner,indent=2)+'\n')
native=D/'native/hashline/src/private_block';p=(native/'protocol.rs').read_text();a=(native/'argument.rs').read_text();l=(native/'layout.rs').read_text();s=(native/'shape.rs').read_text();pcs=(D/'native/zkp-core/src/pcs.rs').read_text();mle=(D/'native/zkp-core/src/mle.rs').read_text()
ck('build_claim unchanged',(D/'builder.rs').read_text()==extract(a,'build_claim'))
ck('B h unchanged',(D/'h_builder.rs').read_text()=="impl<'a>B<'a>{\n"+extract(a,'h')+'}\n')
ck('H domain builder unchanged',(D/'h_domains.rs').read_text()=='impl Shape{\n'+extract(s,'h_plane_doms')+'}\n')
start=l.index('pub(crate) struct HIds');end=l.index('// ---- lookups',start);ck('HIds unchanged',(D/'hids.rs').read_text()==l[start:end])
ck('sum claim unchanged',(D/'sum_claim.rs').read_text()==extract(p,'logup_sum_claim'))
ck('audit unchanged',(D/'native_audit.rs').read_text()=='\n'.join(extract(p,n) for n in ['part_rows','audit_claims']))
ck('group/rho unchanged',(D/'native_groups.rs').read_text()=='\n'.join(extract(pcs,n) for n in ['zpart_weights','zkey_weights','group_zclaims','zk_rhos']))
ck('serial Eq only',(D/'serial_eq.rs').read_text()=='\n'.join(extract(mle,n) for n in ['eq_table','eq_table_msb']).replace('.par_iter_mut()', '.iter_mut()'))
start=l.index('        let mut row = 0usize;',l.index('        let a_rows = a_prox + 2;'));end=l.index('        let h_data_rows = row;',start)+len('        let h_data_rows = row;')
ck('native H offset loop',l[start:end] in (D/'h_offsets.rs').read_text());ck('chunk4 seam','rhos.chunks(4)' in pcs)
prior=json.loads((D/'startup/prior-hypotheses.json').read_text());new=json.loads((D/'hypotheses.json').read_text());ck('all68priorhypotheses',new[:68]==prior and len(new)==70)
ck('old findings preserved',(R/'FINDINGS.md').read_bytes().startswith((D/'startup/FINDINGS.md').read_bytes()));ck('old sources preserved',(R/'sources.jsonl').read_bytes().startswith((D/'startup/sources.jsonl').read_bytes()))
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()];added=[x for x in sources if x.get('run_id')=='20261029T185649Z-81a2bde2'];ck('seven source records',len(added)==7 and len(sources)==1000)
for x in added:ck('source provenance '+x['id'],x['access_date']=='2026-10-29' and x['url'].startswith('https://') and x['external_execution'] is False and all(k in x for k in ['publication_date','verified_update_date','implementation_license','inspected_commit_id']))
for stage in ['prepare','compile','probe','census']:
 e=json.loads((D/(stage+'-execution.json')).read_text());ck('bounded '+stage,e['exit_code']==0 and e['wall_s']<60 and e['max_rss_kib']<512*1024 and e['address_space_mib']<=512 and e['one_cpu_affinity'] and not e['gpu'])
r=json.loads((D/'result.json').read_text());c=json.loads((D/'census-result.json').read_text())
for k,v in dict(status='PASS',fixtures=20,independent_coefficients=539532,message_plus_pad_folds=1683,restored_order_values=1683,negative_controls=90).items():ck('probe '+k,r[k]==v)
ck('census 175 checks',c['checks']==175 and len(c['profiles'])==2)
for x in c['profiles']:
 ck('positive conservative scope '+str(x['dd']),0<x['structural_upper_bytes']<x['baseline_bytes'] and x['packed_structural_upper_bytes']<x['structural_upper_bytes'] and x['context']==128 and not x['native_define_executed'] and not x['native_FS_executed'] and not x['device_test'])
t=json.loads((D/'target-accounting.json').read_text())
for k in ['new_independently_verified_full_stack_proofs','completed_model_passes','proved_positions']:ck('zero full work '+k,t[k]==0)
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_prefill_s','startup_fraction','steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s']:ck('unmeasured '+k,t[k] is None)
for name in ['PROGRESS.md','STATE.md','progress/20261029T185649Z-81a2bde2.md']:
 x=(R/name).read_text();ck('current report '+name,'20261029T185649Z-81a2bde2' in x and 'unachieved' in x)
ck('handoff',(R/'handoffs/20261029-h-structural-support.md').is_file());ck('README',(D/'README.md').is_file())
for i in range(1,10):ck('raw LIVE '+str(i),(D/f'web{i:02}.json').is_file())
for name in ['failed-include-in-impl','failed-corner-single-batch-control','before-packed-scatter']:ck('retained '+name,(D/name).is_dir())
out=dict(status='PASS',checks=len(checks),details=checks,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),owner_documents_unchanged=all(x['unchanged'] for x in owner),full_stack_proofs=0,model_passes=0,proved_positions=0)
(D/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='details'}))
