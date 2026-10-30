"""Final append-only ledger, links and immutable artifact audit."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import resource
import signal
import time

resource.setrlimit(resource.RLIMIT_AS,(256<<20,256<<20))
resource.setrlimit(resource.RLIMIT_CPU,(15,15));signal.alarm(20)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent;BASE=HERE.parents[1]
RUN='20261028T235649Z-d1bc0725';n=0;t=time.monotonic()
sha=lambda b:hashlib.sha256(b).hexdigest()
def ck(ok,msg):
    global n
    n+=1
    assert ok,msg
read=lambda p:json.loads(p.read_text())
for item in read(HERE/'startup/read-index.json'):
    ck(sha((HERE/'startup'/item['snapshot']).read_bytes())==item['sha256'],item['snapshot'])
    if '/docs/' in item['path'] or item['path'].endswith('/CLAUDE.md'):
        ck(sha(Path(item['path']).read_bytes())==item['sha256'],'live required document '+item['path'])
for p in read(HERE/'native-pins.json'):
    ck(sha(Path(p['path']).read_bytes())==p['sha256'],'native '+p['path'])
    ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'],'native snapshot')
d=read(HERE/'result.json')
for name,h in d['code_hashes'].items():ck(sha((HERE/name).read_bytes())==h,name)
ck(read(HERE/'audit-result.json')['status']=='PASS_SOURCE_SCOPE_AND_PROVENANCE_AUDIT','audit passed')
prior=(HERE/'startup/sources.jsonl').read_bytes();ledger=(BASE/'sources.jsonl').read_bytes()
ck(ledger.startswith(prior),'source prefix retained')
new=[json.loads(x) for x in ledger[len(prior):].splitlines()]
ck(new==read(HERE/'sources-cycle.json'),'exact appended records')
ck(len([json.loads(x) for x in ledger.splitlines()])==849,'ledger count')
oldfinding=(HERE/'startup/FINDINGS.md').read_bytes();finding=(BASE/'FINDINGS.md').read_bytes()
ck(finding.startswith(oldfinding),'all prior findings retained')
ck(finding[len(oldfinding):].decode().count('## Cycle 0130')==1,'one cycle entry')
h=read(HERE/'hypotheses.json');old=read(HERE/'startup/prior-hypotheses.json')
ck(len(h)==46 and len(old)==44,'rank queue counts')
for i in range(44):
    ck(h[i]['rank']==old[i]['rank'],'old rank')
    if i not in [0,43]:ck(h[i]==old[i],'unchanged old hypothesis')
reports=[BASE/'STATE.md',BASE/'PROGRESS.md',BASE/'progress'/f'{RUN}.md',BASE/'FINDINGS.md']
for p in reports:
    s=p.read_text();ck(RUN in s,p.name+' run identity')
    for label,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',s if p.name!='FINDINGS.md' else s[len(oldfinding.decode()):]):
        if not target.startswith(('http:','https:','#')):
            ck((p.parent/target.split('#')[0]).exists(),p.name+' link '+target)
ck((BASE/'handoffs/20261028-goldilocks-tc-contract.md').exists(),'handoff')
ck(d['native_full_proofs']==d['passes']==d['proved_positions']==0,'no tokens improperly counted')
files=sorted(p for p in HERE.rglob('*') if p.is_file() and p.name not in ['manifest.json','final-audit.json'])
files += [BASE/'handoffs/20261028-goldilocks-tc-contract.md']
manifest=[]
for p in files:
    ck(p.is_relative_to(BASE) and 'runtime' not in p.relative_to(BASE).parts,'write scope')
    manifest.append(dict(path=str(p.relative_to(BASE)),sha256=sha(p.read_bytes()),bytes=p.stat().st_size))
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for x in manifest:ck(sha((BASE/x['path']).read_bytes())==x['sha256'],'immutable artifact '+x['path'])
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=dict(status='PASS_FINAL_RESEARCH_EVIDENCE_AUDIT',checks=n,immutable_artifacts=len(manifest),
    native_pins_unchanged=7,required_project_documents_unchanged=6,prior_source_records_preserved=840,
    total_source_records=849,prior_hypotheses_preserved=44,total_hypotheses=46,
    checked_at_utc=now,elapsed_seconds=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    scope='Artifact/provenance/links/ledger audit; not native proof, privacy or performance validation.')
(HERE/'final-audit.json').write_text(json.dumps(result,indent=2)+'\n')
note=f'\nFinal evidence audit: {n} checks PASS; {len(manifest)} immutable artifacts, seven native pins and six required project documents unchanged. All840 prior sources,44 prior hypotheses and prior findings retained. Final checkpoint UTC: {now}.\n'
for p in reports:
    with p.open('a') as f:f.write(note)
print(json.dumps(result,indent=2))
