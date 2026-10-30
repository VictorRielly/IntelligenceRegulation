from pathlib import Path
import hashlib,json,datetime
D=Path(__file__).resolve().parent;R=D.parent.parent
checks=[]
def ck(name,v):
    checks.append(dict(name=name,passed=bool(v)))
    if not v:raise AssertionError(name)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p in json.loads((D/'native-pins.json').read_text()):
    ck('snapshot:'+p['snapshot'],sha(D/p['snapshot'])==p['sha256'])
    ck('immutable input:'+p['path'],sha(Path(p['path']))==p['sha256'])
pins=json.loads((D/'startup/pins.json').read_text())
recheck=[]
for name,p in pins.items():
    src=Path(name);snapshot=D/'startup'/src.name
    ck('startup snapshot:'+src.name,sha(snapshot)==p['sha256'])
    if src.name in ['AGENDA.md','CLAUDE.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']:
        now=sha(src);recheck.append(dict(path=name,start=p['sha256'],end=now,unchanged=now==p['sha256']))
        # Owner documents can change concurrently; retain new evidence,
        # never write to them or equate a changed status with liveness.
        if now!=p['sha256']:(D/'owner'/('closing-'+src.name)).write_bytes(src.read_bytes())
(D/'owner-document-recheck.json').write_text(json.dumps(recheck,indent=2)+'\n')
old=json.loads((D.parent/'multi-rho-rowfold-20261029/hypotheses.json').read_text());new=json.loads((D/'hypotheses.json').read_text())
ck('all66priorhypotheses',new[:66]==old and len(new)==68)
ck('old findings preserved', (R/'FINDINGS.md').read_bytes().startswith((D/'startup/FINDINGS.md').read_bytes()))
ck('old source bytes preserved',(R/'sources.jsonl').read_bytes().startswith((D/'startup/sources.jsonl').read_bytes()))
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
ck('source count993',len(sources)==993)
ck('six new sources',len([x for x in sources if x.get('run_id')=='20261029T175649Z-b41890ba'])==6)
for s in sources[-6:]:
    ck('source provenance:'+s['id'],s['access_date']=='2026-10-29' and s['url'].startswith('https://') and s['external_execution'] is False and 'verified_update_date' in s and 'implementation_license' in s and s['inspected_commit_id'] is None)
def extract(s,name):
    at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;b=s.index('{',at);depth=1;i=b+1
    while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]+'\n'
pcs=(D/'native/zkp-core/src/pcs.rs').read_text();pro=(D/'native/hashline/src/private_block/protocol.rs').read_text()
ck('exact audit functions',(D/'native_audit.rs').read_text()==extract(pro,'part_rows')+'\n'+extract(pro,'audit_claims'))
ck('exact group rho functions',(D/'native_groups.rs').read_text()=='\n'.join(extract(pcs,n) for n in ['zpart_weights','zkey_weights','group_zclaims','zk_rhos']))
ck('native batch4 remains','rhos.chunks(4)' in pcs)
ck('native masks remain','if site_rows.iter().any(|r| uses[*r] != 1)' in pro and 'if pr.end > prox' in pro)
r=json.loads((D/'result.json').read_text());c=json.loads((D/'census-result.json').read_text());t=json.loads((D/'target-accounting.json').read_text())
for k,v in dict(status='PASS',fixtures=81,h_sum_fixtures=3,reserved_row_checks=4752,independent_dense_coefficients=405216,independent_message_plus_pad_fold_values=5049,restored_order_values=5049,dense_proximity_fixtures=81,audit_refusals=7,negative_controls=164).items():ck('probe:'+k,r[k]==v)
ck('four source geometry bounds',len(c['profiles'])==4 and c['checks']==38)
for p in c['profiles']:
    ck('bound:'+p['label'],p['guaranteed_skipped_row_visits']<=p['symbolic_order_skipped_row_visits'] and p['baseline_chunk4_row_visits']-p['symbolic_order_skipped_row_visits']==p['mask_only_row_visit_upper_bound'])
    ck('row geometry:'+p['label'],p['rows']==p['non_site_non_proximity_rows']+p['mask_rows']+2)
n=c['mask_count_packing_counterexample'];ck('packing negative',n['packed_actual_row_visits']==2706 and n['original_actual_row_visits']==2274 and n['packed_envelope_row_visits']<n['original_envelope_row_visits'])
for stage in ['prepare','compile','probe','census']:
    e=json.loads((D/(stage+'-execution.json')).read_text());ck('bounded:'+stage,e['exit_code']==0 and e['wall_s']<60 and e['max_rss_kib']<512*1024 and e['address_space_mib']<=512 and e['one_cpu_affinity'] and not e['gpu'])
for k in ['new_independently_verified_full_stack_proofs','completed_model_passes','proved_positions']:ck('zero new model work:'+k,t[k]==0)
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_prefill_s','startup_fraction','steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s']:ck('unmeasured:'+k,t[k] is None)
for name in ['README.md','progress/20261029T175649Z-b41890ba.md','PROGRESS.md','STATE.md','handoffs/20261029-public-mask-row-bound.md']:
    p=D/name if name=='README.md' else R/name;ck('report exists:'+name,p.is_file())
for name in ['PROGRESS.md','STATE.md','progress/20261029T175649Z-b41890ba.md']:
    x=(R/name).read_text();ck('current run:'+name,'20261029T175649Z-b41890ba' in x);ck('no acceptance:'+name,'unachieved' in x)
for i in range(1,13):ck('live web saved:'+str(i),(D/f'web{i:02}.json').is_file())
out=dict(status='PASS',checks=len(checks),details=checks,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),owner_documents_unchanged=all(x['unchanged'] for x in recheck),native_inputs=10,full_stack_proofs=0,model_passes=0,proved_positions=0)
(D/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='details'}))
