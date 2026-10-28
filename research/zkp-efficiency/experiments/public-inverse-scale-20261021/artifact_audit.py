"""Final evidence-integrity checks, independent of the arithmetic producer."""
from pathlib import Path
import ast,datetime,hashlib,json,resource,time
E=Path(__file__).resolve().parent
R=E.parent.parent
RUN='20261021T001854Z-77f04b06'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def run():
    start=time.monotonic();checks=0
    def ck(x):
        nonlocal checks
        assert x;checks+=1
    prior=(E/'startup/sources.jsonl').read_bytes()
    current=(R/'sources.jsonl').read_bytes()
    ck(current.startswith(prior))
    old=[json.loads(x) for x in prior.splitlines()]
    new=[json.loads(x) for x in current[len(prior):].splitlines()]
    ck(len(old)==718);ck(len(new)==9)
    ck(new==json.loads((E/'source-records.json').read_text()))
    for x in new:
        for field in ['access_date','publication_date','verified_update_date','url','implementation_license','inspected_commit_id']:
            ck(field in x)
        ck(x['run_id']==RUN);ck(x['external_execution'] is False)
    ck((R/'FINDINGS.md').read_bytes().startswith((E/'startup/FINDINGS.md').read_bytes()))
    q=json.loads((E/'hypotheses.json').read_text())
    oldq=json.loads((E/'source/prior__public-ntt-cache-incidence-20261020__hypotheses.json').read_text())
    ck(q[:29]==oldq);ck(len(q)==31)
    for i,x in enumerate(q,1):ck(x['rank']==i)
    p=json.loads((E/'result.json').read_text());a=json.loads((E/'validation-result.json').read_text());c=json.loads((E/'census-result.json').read_text())
    for x in [p,a,c]:
        ck(x['status']=='PASS');ck(x['wall_seconds']<60);ck(x['rss_kib']<512*1024)
    ck(p['synthetic_rows']==a['synthetic_rows']==200)
    ck(p['encoded_positions']==a['encoded_positions']==6900)
    ck(len(p['negative_controls'])==15);ck(p['scale_entries']==33)
    ck(a['overlap_rows']==30);ck(a['independent_batch_cases']==c['synthetic_batch_cases']==144)
    ck(a['independent_schedules']==c['conditional_commit_schedules']==36)
    ck(a['source_pins']==18);ck(len(c['source_definitions'])==18)
    ck({x['scope'] for x in c['source_definitions']}=={'r9','active','gpu-owner'})
    pins=json.loads((E/'source-pins.json').read_text());live_changes=[]
    for pin in pins:
        ck(digest(E/pin['copy'])==pin['sha256'])
        if digest(Path(pin['source']))!=pin['sha256']:live_changes.append(pin['source'])
    # Required source reads were snapshotted; concurrent main edits are recorded,
    # never "repaired" by this read-only lane.
    project=Path('/home/victor/IntelligenceRegulation')
    for pin in json.loads((E/'startup-pins.json').read_text()):
        src=Path(pin['path'])
        key=src.name if src.parent==R else str(src.relative_to(project)).replace('/','__')
        ck(digest(E/'startup'/key)==pin['sha256'])
    accounting=json.loads((E/'target-accounting.json').read_text())
    for k in ['new_completed_independently_verified_full_stack_proofs','passes','proved_positions']:ck(accounting[k]==0)
    for k in ['witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_seconds','startup_fraction','steady_state_proved_tokens_per_second','total_workload_proved_tokens_per_second','actual_context_length','actual_accelerator']:ck(accounting[k] is None)
    ck(accounting['complete_private_8B_50_per_s_achieved'] is False)
    for name in ['STATE.md','PROGRESS.md','progress/'+RUN+'.md','handoffs/20261021-public-inverse-scale.md']:
        text=(R/name).read_text();ck(len(text)>200)
        ck('No proving' in text or 'no measured proving' in text)
    ck('UNCOMPILED' in (E/'candidate.rs').read_text())
    tree=ast.parse((E/'audit.py').read_text())
    for node in ast.walk(tree):
        if isinstance(node,(ast.Import,ast.ImportFrom)):
            names=[a.name for a in node.names] if isinstance(node,ast.Import) else [node.module]
            ck(not any(x and ('probe' in x or 'census' in x) for x in names))
    commands=[json.loads(x) for x in (E/'commands.jsonl').read_text().splitlines()]
    for x in commands:
        ck(x['exit_code']==0);ck(x['elapsed_s']<60)
    # Hash final evidence and reports; exclude audit's live logs and its own
    # result/manifest to avoid self-referential hashes.
    excluded={'artifact-audit-result.json','artifact-hashes.json','artifact_audit.py.stdout','artifact_audit.py.stderr','commands.jsonl'}
    files=[x for x in E.rglob('*') if x.is_file() and x.name not in excluded]
    files += [R/x for x in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/'+RUN+'.md','handoffs/20261021-public-inverse-scale.md']]
    hashes=[]
    for f in sorted(files):
        ck(not f.is_symlink());ck(R in f.parents)
        hashes.append(dict(path=str(f.relative_to(R)),sha256=digest(f)))
    (E/'artifact-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    result=dict(status='PASS',checks=checks,artifact_hashes=len(hashes),prior_source_records=718,new_source_records=9,
                preserved_prior_hypotheses=29,ranked_hypotheses=31,source_pins=len(pins),
                live_source_changes_after_capture=live_changes,
                required_document_updates=json.loads((E/'concurrent-document-updates.json').read_text()),
                finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (E/'artifact-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':run()
