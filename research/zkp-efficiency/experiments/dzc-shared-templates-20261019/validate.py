"""Bounded final artifact, source-pin and durable-memory validation."""
import datetime,hashlib,json,os,resource,signal,time
from pathlib import Path

H=Path(__file__).resolve().parent;R=H.parent.parent

def main():
    start=time.perf_counter();os.nice(19)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=[]
    def check(v,name):
        assert v,name
        checks.append(name)
    r=json.loads((H/'result.json').read_text())
    a=json.loads((H/'audit-shared-result.json').read_text())
    b=json.loads((H/'bench-result.json').read_text())
    t=json.loads((H/'target-accounting.json').read_text())
    for name,v in [('native',r),('audit',a),('bench',b)]:check(v['status']=='PASS',name+' passed')
    check(r['seed']==2026101982 and r['N']==[2,8,32],'seed/dimensions')
    check(r['checks']==dict(compiled_coefficients=780,value_independent_runtime_binding=36,
          captured_rust_grid_values=390,captured_rust_offgrid_values=78,
          round_messages=18,original_finals=354,final_relations=6,fixtures=6),'differential coverage')
    check(len(r['controls'])==8 and all(r['controls'].values()),'eight native controls')
    check(a['checks']==1455 and len(a['controls'])==6 and all(a['controls'].values()),'independent audit and controls')
    check(a['map_storage_bytes']==634 and a['shared_logical_bytes']==9162,'full map costs charged')
    check(a['unique_logical_bytes']==8528 and a['scalar_logical_bytes']==4320,'baseline traffic')
    check(a['original_fold_reads']==118 and a['original_fold_writes']==59,'original folds charged')
    check(a['assembly']['driven']['entry']['call_chain_span_below_entry_rsp_bytes']==504,'full stack charged')
    check(a['assembly']['driven']['code_bytes']==78421 and a['assembly']['unique']['code_bytes']==145739,'code-size accounting')
    for pfile in ['source-pins.json','owner-evidence-pins.json','carried-D-evidence-pins.json','local-reference-pins.json']:
        pins=json.loads((H/pfile).read_text())
        for p in pins:check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'],pfile+': '+p['path'])
    check(len(b['rows'])==27,'nine three-arm samples')
    for i in range(9):
        rows=[x for x in b['rows'] if x['rep']==i]
        check({x['arm'] for x in rows}=={'scalar','unique','shared'},'sample arms '+str(i))
        check(len({x['checksum'] for x in rows})==1,'sample checksums '+str(i))
        check(all(x['rows']==8192 and x['nanoseconds']>0 for x in rows),'sample work '+str(i))
    check(sum(x>1 for x in b['paired_speedups'])==3,'no demonstrated speed gain')
    check(t['new_target_work']['completed_independently_verified_full_stack_proofs']==0,'zero new full-stack proofs')
    check(t['new_target_work']['complete_model_passes']==0 and t['new_target_work']['proved_token_positions']==0,'zero target passes/positions')
    for f in ['context_tokens','steady_proved_tokens_per_second','total_workload_proved_tokens_per_second',
              'startup_seconds','startup_fraction','witness_seconds','proof_seconds',
              'serialization_seconds','verification_seconds']:
        check(t['new_target_work'][f] is None,'target unmeasured '+f)
    for f in ['FINDINGS.md','sources.jsonl']:
        check((R/f).read_bytes().startswith((H/'startup'/f).read_bytes()),'prior '+f+' preserved byte-for-byte')
    allsources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
    new=json.loads((H/'source-records.json').read_text())
    check(len(allsources)==448 and allsources[-6:]==new,'448 parsed sources; six exact appended records')
    check(len({x['id'] for x in new})==6,'unique source IDs')
    for rec in new:
        check(rec['access_date']=='2026-10-19' and not rec['reproduced_performance'],'dated source scope '+rec['id'])
    ranked=json.loads((H/'hypotheses.json').read_text())
    check(len(ranked)>=3 and [x['rank'] for x in ranked]==[1,2,3,4],'four ranked hypotheses')
    for x in ranked:
        check(all(x.get(k) for k in ['expected_impact','prerequisites','integration_cost','exactness','obligations','falsification']), 'hypothesis criteria '+str(x['rank']))
    for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261019T141854Z-0a847d64.md',
              R/'handoffs/20261019-dzc-shared-templates.md',H/'README.md']:
        check('20261019T141854Z-0a847d64' in p.read_text(),'run identity '+str(p))
    check('15:18:54 UTC' in (R/'STATE.md').read_text(),'next cycle hourly limit')
    # This manifest excludes itself and later validation/checkpoint receipts.
    manifest=[]
    for p in sorted(H.rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts and p.name not in ['artifact-manifest.json','validation.json','validation.log','final-state.md']:
            manifest.append(dict(path=str(p.relative_to(H)),bytes=p.stat().st_size,
                                 sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    (H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for p in manifest:check(hashlib.sha256((H/p['path']).read_bytes()).hexdigest()==p['sha256'],'artifact '+p['path'])
    now=datetime.datetime.now(datetime.timezone.utc)
    check(now<datetime.datetime(2026,10,19,14,38,54,tzinfo=datetime.timezone.utc),'checkpoint within20 minutes')
    out=dict(status='PASS',checks=len(checks),check_names=checks,artifacts=len(manifest),
             finished_utc=now.isoformat(),wall_seconds=time.perf_counter()-start,
             rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             threads=1,cpu_affinity=[cpu],limits='59s CPU/wall;512MiBAS;one nice19 CPU',
             caveat='Artifact/source/accounting validation only; not receipt verification or native/GPU integration.')
    (H/'validation.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k!='check_names'},indent=2))

if __name__=='__main__':main()
