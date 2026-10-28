"""Artifact/provenance/resource checks only; does not verify a proof."""
from pathlib import Path
import hashlib,json,os,resource,time,datetime
H=Path(__file__).resolve().parent;R=H.parent.parent
CHECKS=0
def ck(v,m=''):
    global CHECKS
    CHECKS+=1
    assert v,m
def read(n):return json.loads((H/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    start=time.perf_counter();changed=[]
    for row in read('source-manifest.json'):
        ck(sha(H/row['snapshot'])==row['sha256'],'source snapshot')
        if sha(Path(row['path']))!=row['sha256']:changed.append(row['path'])
    for row in read('research-dependencies.json'):ck(sha(Path(row['path']))==row['sha256'],'prior research dependency')
    prior=(H/'startup/FINDINGS.md').read_bytes();current=(R/'FINDINGS.md').read_bytes();ck(current.startswith(prior),'prior findings prefix')
    previous=(H/'startup/sources.jsonl').read_bytes();current=(R/'sources.jsonl').read_bytes();ck(current.startswith(previous),'prior sources prefix')
    before=[json.loads(x) for x in previous.splitlines()];after=[json.loads(x) for x in current.splitlines()]
    ck(len(before)==548 and len(after)==548+len(read('source-records.json')),'source counts');ck(after[len(before):]==read('source-records.json'),'new source records')
    for row in after[len(before):]:
        for key in ['url','access_date','published','updated','date_evidence','implementation_license','inspected_commit_id']:ck(key in row,key)
        ck(row['reproduced_performance'] is False)
    rs=read('result.json');cs=read('cases.json');ns=read('negative-controls.json')
    ck(rs['fixtures']==len(cs)==108);ck(rs['rounds']==sum(x['n'] for x in cs)==468);ck(rs['negative_controls']==len(ns)==11)
    groups={}
    for c in cs:groups.setdefault((c['n'],c['support'],c['base_round0'],c['pad_nonempty'],c['tail_log']),[]).append(c)
    ck(len(groups)==36)
    for group in groups.values():
        ck({c['mode'] for c in group}=={'dense','mixed','implicit'})
        ck(len({tuple(c['round_hashes']) for c in group})==1)
        ck(len({c['final_sha256'] for c in group})==1)
        ck(all(c['n']-1>c['tail_log'] for c in group),'unchanged raw eligibility')
    for key in ['proofs','passes','positions']:ck(rs['full_stack'][key]==0)
    for key in ['context_length','device','witness_s','proof_s','serialization_s','verification_s','startup_fraction','steady_rate','total_rate']:ck(rs['full_stack'][key] is None)
    cap=read('capacity-result.json');ck(cap['cases']==72);ck(cap['negative_controls']==72);ck(cap['zero_resident_additional_backing_cases']==cap['resident_cases']==24)
    alloc=read('allocation-projection.json')
    for row in alloc:
        l=row['T']*16384;kd=21 if not row['support'] else 23;k=20+row['support']
        ck(row['dense_request']==16*kd*l)
        ck(row['implicit_request']==16*((k-17)*l+17*l//2))
        ck(row['mixed_request']-row['implicit_request']==16*(1+row['support'])*l)
    cen=read('census-result.json');ck(cen['sites']==len(read('address-census.json'))==107)
    facts=read('source-facts.json');ck(next(x['line'] for x in facts if x['label']=='constructor_full_view')==4332)
    for row in facts:
        src=H/'source'/row['file'].replace('/','__');ck(row['text'] in src.read_text().splitlines()[row['line']-1],'source anchor')
    for h in read('hypotheses.json'):
        for key in ['rank','baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:ck(key in h,key)
    commands=read('commands.json')
    for cmd in commands:
        ck(cmd['exit_code']==0);ck(cmd['wall_seconds']<60)
        ck(cmd['maxrss_kib']<512*1024)
        ck(cmd['limits']==dict(cpu_s=59,alarm_s=59,address_space_bytes=512*1024**2,threads=1,nice=19))
        ck((H/cmd['stdout']).exists() and (H/cmd['stderr']).exists())
    for name in ['probe.py','census.py','capacity.py']:
        last=[c for c in commands if c['leaf']==name][-1];ck(last['sha256']==sha(H/name),'final authored leaf run')
    run='20261020T041854Z-f70297a5'
    for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{run}.md']:
        text=p.read_text();ck(run in text);ck('unmeasured' in text.lower() or 'UNMEASURED' in text)
    for p in [H/'README.md',R/'handoffs/20261020-implicit-affine-fzc.md']:ck(p.exists())
    for row in read('artifact-manifest.json'):ck(sha(H/row['path'])==row['sha256'],'artifact pin')
    out=dict(status='PASS_PROVENANCE_ONLY',checks=CHECKS,source_records_before=len(before),source_records_after=len(after),prior_findings_and_sources_prefix_preserved=True,changed_live_source_paths=changed,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Local artifacts/provenance/resource limits only; no native proof verification')
    (H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
