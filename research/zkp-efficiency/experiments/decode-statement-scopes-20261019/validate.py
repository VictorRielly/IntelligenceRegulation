"""Final bounded provenance/report consistency gate, no production mutations."""
import hashlib,json,os,re,resource,time
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[1];checks=0;t0=time.perf_counter()
def check(ok):
    global checks
    assert ok
    checks+=1
def sha(b):return hashlib.sha256(b).hexdigest()
pins=json.loads((H/'prior-source-pins.json').read_text())
for p in pins:
    check(sha(Path(p['source']).read_bytes())==p['sha256'])
    check(sha((H/p['snapshot']).read_bytes())==p['sha256'])
startup=json.loads((H/'startup-manifest.json').read_text())
for p in startup:
    check(sha((H/'startup'/Path(p['path']).name).read_bytes())==p['sha256'])
    if Path(p['path']).name not in ['STATE.md','FINDINGS.md','PROGRESS.md','sources.jsonl']:
        check(sha(Path(p['path']).read_bytes())==p['sha256'])
check((ROOT/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
check((ROOT/'sources.jsonl').read_bytes().startswith((H/'startup/sources.jsonl').read_bytes()))
sources=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
new=[s for s in sources if s.get('run_id')=='20261019T221854Z-a20c7a9f']
check(new==json.loads((H/'source-records.json').read_text()));check(len(new)==8)
check(len(sources)==507)
for row in new:
    check(row['access_date']=='2026-10-19' and not row['external_execution'] and not row['reproduced_performance'])
    check(row['url'].startswith('https://'))
commands=json.loads((H/'commands.json').read_text())
for c in commands:
    check(c['exit_code']==0);check((H/c['stdout']).exists() and (H/c['stderr']).exists())
    check(c['wall_seconds']<60);check(c['limits']['address_space_bytes']==512*1024**2)
    check(c['limits']['single_cpu_affinity'])
    source=H/('drop_probe.rs' if any('drop_probe' in a for a in c['argv']) else Path(c['argv'][-1]).name)
    if c['source_sha256']!=sha(source.read_bytes()):
        check(c['source_sha256']==sha((H/'before-seed-label-refinement/experiment.py').read_bytes()))
result=json.loads((H/'result.json').read_text());audit=json.loads((H/'audit-result.json').read_text())
check(result['status']==audit['status']=='PASS');check(result['checks']==898 and audit['checks']==2411)
check(result['new_full_stack_proofs']==result['new_passes']==result['new_proved_positions']==0)
check(all(result[n] is None for n in ['device','proof_context','steady_rate','total_rate','startup_fraction',
 'witness_seconds','proof_seconds','serialization_seconds','verification_seconds']))
native=(H/'native/hashline__src__private_block__trained_block.rs').read_text()
candidate=(H/'candidate-trained_block.rs').read_text()
check(sha(native.encode())==result['source_gate']['native_sha256'])
check(sha(candidate.encode())==result['source_gate']['candidate_sha256'])
# Replay the one unified-diff hunk in memory only, retaining exact context.
patch=(H/'review-only-statement-scopes.patch').read_text().splitlines(True)
lines=native.splitlines(True);out=[];cursor=0;hunks=0;i=2
while i<len(patch):
    m=re.match(r'@@ -(\d+),(\d+) \+(\d+),(\d+) @@',patch[i]);check(m is not None);hunks+=1
    start=int(m[1])-1;out+=lines[cursor:start];cursor=start;i+=1;deleted=added=0
    while i<len(patch) and not patch[i].startswith('@@'):
        row=patch[i];i+=1
        if row[0] in [' ','-']:
            check(lines[cursor]==row[1:]);cursor+=1;deleted+=1
        if row[0] in [' ','+']:out.append(row[1:]);added+=1
    check(deleted==int(m[2]) and added==int(m[4]))
out+=lines[cursor:];check(''.join(out)==candidate);check(hunks==1)
toolchain=json.loads((H/'toolchain.json').read_text())
check(sha(Path(toolchain['path']).read_bytes())==toolchain['sha256'])
check(sha((H/'drop_probe').read_bytes())==toolchain['probe_binary_sha256'])
hyps=json.loads((H/'hypotheses.json').read_text());check(len(hyps)>=3)
for i,hyp in enumerate(hyps,1):
    check(hyp['rank']==i)
    for field in ['baseline','eliminated_work','added_costs','end_to_end_ceiling','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','falsification']:
        check(bool(hyp[field]))
for path in [H/'README.md',ROOT/'PROGRESS.md',ROOT/'STATE.md',ROOT/'progress/20261019T221854Z-a20c7a9f.md',ROOT/'handoffs/20261019-decode-statement-scopes.md']:
    check(path.is_file());s=path.read_text();check('20261019T221854Z-a20c7a9f' in s)
    check('No speed improvement measured' in s)
out=dict(status='PASS',checks=checks,source_evidence_pins=len(pins),r8_marked_matches=sum(p['r8_manifest_match'] is True for p in pins),
    patch_hunks_replayed_in_memory=hunks,source_records_appended=8,ranked_hypotheses=len(hyps),
    wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    threads=1,nice=os.nice(0),scope='Provenance/report consistency; no native production build/proof')
(H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,sort_keys=True))
