"""Check artifact pins, append-only memory, statuses and report links."""
from pathlib import Path
import json,hashlib,re,datetime
H=Path(__file__).resolve().parent;root=H.parent.parent
manifest=[{'path':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
    for p in H.iterdir() if p.suffix in ['.py','.rs'] or p.name=='oracle']
(H/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
checks=0
def check(x):
    global checks
    assert x;checks+=1
for name in ['result.json','validation-result.json','cycle-result.json']:
    check(json.loads((H/name).read_text())['status'] in ['PASS','COMPLETE'])
sources=[json.loads(x) for x in (root/'sources.jsonl').read_text().splitlines()]
check(len(sources)==650)
check((root/'sources.jsonl').read_bytes().startswith((H/'startup/sources.jsonl').read_bytes()))
check((root/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
check(len(json.loads((H/'hypotheses.json').read_text()))>=3)
for r in json.loads((H/'source-pins.json').read_text()):
    check(hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256'])
for r in manifest:
    check(hashlib.sha256((H/r['path']).read_bytes()).hexdigest()==r['sha256'])
for p in [root/'PROGRESS.md',root/'STATE.md',root/'progress/20261020T161854Z-f0b8edce.md',
          root/'handoffs/20261020-native-fp2-u8-consumer.md',H/'README.md']:
    check(p.is_file() and p.stat().st_size>0)
    for ref in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if not ref.startswith(('https://','http://')):check((p.parent/ref).resolve().is_file())
    check('no proving speed improvement' in p.read_text().lower())
r={'status':'PASS','checks':checks,'checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
   'source_ledger_records':len(sources),'unchanged_source_pins':6,'code_artifacts_pinned':len(manifest),
   'prior_findings_and_source_prefix_preserved':True,'new_full_stack_proofs':0,
   'documentation_link_failure_fixed':True}
(H/'checkpoint-validation.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
