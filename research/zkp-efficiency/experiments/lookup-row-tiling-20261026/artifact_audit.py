"""Bounded final evidence audit. Reads production only to compare pinned hashes."""
import datetime,hashlib,json,re,resource,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
RESEARCH=ROOT.parents[1]
START=time.monotonic();checks=0
def check(v,label):
    global checks
    checks+=1
    assert v,label
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((ROOT/'artifact-manifest.json').read_text())
for entry in manifest:
    path=ROOT/entry['path']
    check(path.is_file(),'immutable artifact exists')
    check(sha(path.read_bytes())==entry['sha256'],'immutable artifact hash '+entry['path'])

prior_sources=(ROOT/'startup/sources.jsonl').read_bytes()
current_sources=(RESEARCH/'sources.jsonl').read_bytes()
check(current_sources.startswith(prior_sources),'814 previous source records preserved byte for byte')
added=(ROOT/'source-records.jsonl').read_bytes()
check(current_sources[len(prior_sources):]==added,'seven append records only')
check(len(prior_sources.splitlines())==814 and len(current_sources.splitlines())==821,'source counts')
prior_findings=(ROOT/'startup/FINDINGS.md').read_bytes()
check((RESEARCH/'FINDINGS.md').read_bytes().startswith(prior_findings),'previous findings and negatives preserved byte for byte')
prior_h=json.loads((ROOT/'startup/experiments__sumcheck-public-shape-20261026__hypotheses.json').read_text())
h=json.loads((ROOT/'hypotheses.json').read_text())
check(len(prior_h)==39 and len(h)==41,'hypothesis counts')
check([x['rank'] for x in h]==list(range(1,42)),'unique ordered ranks')
for old,new in zip(prior_h,h):
    check(old['rank']==new['rank'],'retained hypothesis identity')
    if old['rank'] not in (1,14):check(old==new,'untouched older hypothesis')
    for key in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:
        check(bool(new[key]),'ranked requirements')

live=[]
for pin in json.loads((ROOT/'native-pins.json').read_text()):
    check(sha(Path(pin['snapshot']).read_bytes())==pin['sha256'],'native copy hash')
    current=sha(Path(pin['path']).read_bytes())
    check(current==pin['sha256'],'tested current code unchanged '+pin['path'])
    live.append(pin['path'])

# Apply the exact unified diff in memory only; no patch tool or Git call.
pin=next(x for x in json.loads((ROOT/'native-pins.json').read_text()) if x['path'].endswith('/trained-1b/hashline/src/private_block/argument.rs'))
old=Path(pin['snapshot']).read_text().splitlines(True)
patch=(ROOT/'row-tiling.patch').read_text().splitlines(True)
check(patch[0].startswith('--- a/') and patch[1].startswith('+++ b/'),'review patch paths')
out=[];position=0;i=2;hunks=0
while i<len(patch):
    m=re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\n]*\n',patch[i])
    check(m is not None,'hunk header')
    old_at=int(m[1])-1;old_count=int(m[2] or 1);new_count=int(m[4] or 1)
    check(old_at>=position,'ordered hunks')
    out.extend(old[position:old_at]);position=old_at;i+=1;used_old=used_new=0
    while i<len(patch) and not patch[i].startswith('@@ '):
        kind=patch[i][0];line=patch[i][1:]
        check(kind in ' +-','allowed unified body')
        if kind in ' -':
            check(old[position]==line,'patch context pinned');position+=1;used_old+=1
        if kind in ' +':out.append(line);used_new+=1
        i+=1
    check(used_old==old_count and used_new==new_count,'exact hunk lengths');hunks+=1
out.extend(old[position:])
check(''.join(out)==(ROOT/'candidate-argument.rs').read_text(),'in-memory patch produces copied candidate')
check(hunks==2,'two bounded constructor hunks')

result=json.loads((ROOT/'result.json').read_text())
audit=json.loads((ROOT/'audit-result.json').read_text())
check(result['checks']==3353 and result['constructor_cases']==204,'model result scope')
check(result['compared_output_entries']==2264184 and result['native_proofs']==0,'no synthetic positions credited')
check(audit['checks']==158,'separate source audit')
for run in map(json.loads,(ROOT/'commands.jsonl').read_text().splitlines()):
    check(run['exit_code']==0,'bounded run success')
    check(run['threads']==1 and run['cpu_seconds']<=60 and run['address_space_mib']<=512,'resource caps')
    check(run['elapsed_s']<60,'experiment duration bound')
for path in sorted((ROOT/'web-live').glob('*.json')):
    check(bool(json.loads(path.read_text())),'retained native LIVE result')
check(len(list((ROOT/'web-live').glob('*.json')))==10,'ten web batches')
for record in map(json.loads,added.decode().splitlines()):
    for key in ['access_date','url','publication_date','verified_update_date','implementation_license','inspected_commit_id','assessment']:
        check(key in record,'primary provenance field')
    check(record['external_execution'] is False and record['reproduced_performance'] is False,'author claims not reproduced')

for file in ['STATE.md','PROGRESS.md','progress/20261026T192925Z-2a61ec3c.md']:
    text=(RESEARCH/file).read_text()
    check('20261026T192925Z-2a61ec3c' in text,'matching final run report')
    check('unmeasured' in text and '0 / 0 / 0' in text,'full stack scope explicit')
    check('50' in text and '8B' in text.replace('8B','8B').replace('8 B','8B'),'target preserved')

now=datetime.datetime.now(datetime.timezone.utc).isoformat()
out=dict(status='PASS_EVIDENCE_INTEGRITY_ONLY',checks=checks,immutable_artifacts=len(manifest),
    tested_current_native_pins=len(live),patch_hunks=hunks,prior_sources=814,total_sources=821,
    prior_hypotheses=39,total_hypotheses=41,utc=now,elapsed_seconds=time.monotonic()-START,
    max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    native_proofs=0,scope='Artifact preservation and source-pinned in-memory patch only; no native integration or privacy acceptance')
(ROOT/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
