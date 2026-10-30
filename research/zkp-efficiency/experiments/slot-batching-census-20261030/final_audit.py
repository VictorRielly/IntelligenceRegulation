from pathlib import Path
import ast, hashlib, json, re
D=Path(__file__).resolve().parent;R=D.parent.parent
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=0
for pin in json.loads((D/'native-pins.json').read_text()):
    assert digest(Path(pin['path']))==pin['sha256'];checks+=1
    assert digest(D/pin['snapshot'])==pin['sha256'];checks+=1
pin=json.loads((D/'census-pin.json').read_text())
assert digest(Path(pin['path']))==pin['sha256'];checks+=1
assert digest(D/'native/NATIVE_LAYOUT_CENSUS.json')==pin['sha256'];checks+=1
native=(D/'native/shape.rs').read_text();generated=(D/'native_metadata.rs').read_text()
for method in json.loads((D/'extraction.json').read_text())['methods']:
    # Hash the exact generated method as well as requiring its native inclusion.
    match=re.search(r'(?m)^\s*(?:pub(?:\([^)]*\))? )?fn '+method['name']+r'\(',generated)
    assert match;op=generated.index('{',match.end());depth=0
    for end in range(op,len(generated)):
        depth+=(generated[end]=='{')-(generated[end]=='}')
        if depth==0:break
    body=generated[match.start():end+1]
    # Leading newline can differ when concatenated, so locate the original
    # segment by method hash from native (copied byte-for-byte by prepare).
    target=re.search(r'(?m)^\s*(?:pub(?:\([^)]*\))? )?fn '+method['name']+r'\(',native)
    no=native.index('{',target.end());nd=0
    for ne in range(no,len(native)):
        nd+=(native[ne]=='{')-(native[ne]=='}')
        if nd==0:break
    segment=native[target.start():ne+1]
    assert hashlib.sha256(segment.encode()).hexdigest()==method['sha256']
    assert segment.strip()==body.strip();checks+=2
for file in ['prepare.py','reference.py','run_bounded.py','close.py','final_audit.py']:
    ast.parse((D/file).read_text());checks+=1
r=json.loads((D/'result.json').read_text());assert r['status']=='PASS' and r['all_native_fs_independent_pairs']==0;checks+=1
assert r['eight_b_t128']['native']['equal_shape_pairs']==24
assert r['eight_b_t128']['native']['blocked_pairs']==24
assert len(r['eight_b_t128']['no_fs_counterfactual']['independent_pairs'])==21;checks+=3
assert len(json.loads((D/'hypotheses.json').read_text()))==94;checks+=1
sources=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines() if s.strip()]
ids=[s['id'] for s in sources if s.get('cycle')=='0161'];assert len(ids)==len(set(ids))==9;checks+=1
for record in [s for s in sources if s.get('cycle')=='0161']:
    for key in ['url','access_date','publication_date','verified_update_date','implementation_license','inspected_commit_id']:
        assert key in record;checks+=1
    assert record['external_execution'] is False and record['reproduced_performance'] is False;checks+=1
for name in ['STATE.md','PROGRESS.md','progress/20261030T094123Z-ce04cf1a.md']:
    text=(R/name).read_text();assert '20261030T094123Z-ce04cf1a' in text and 'unmeasured' in text;checks+=1
# Recheck owner-direction files, retain changed hashes; no claim that a stale
# snapshot establishes current state or job liveness.
changes=[]
for x in json.loads((D/'startup/read-index.json').read_text()):
    if not x['path'].startswith('research/'):
        p=Path('/home/victor/IntelligenceRegulation')/x['path']
        changes.append(dict(path=str(p),startup_sha256=x['sha256'],current_sha256=digest(p),changed=digest(p)!=x['sha256']))
(D/'owner-document-recheck.json').write_text(json.dumps(changes,indent=2)+'\n')
assert not any(x['changed'] for x in changes),'Owner documents changed; read changed content before final checkpoint.'
manifest=[]
for p in sorted(D.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json','commands.jsonl']:
        manifest.append(dict(path=str(p.relative_to(D)),sha256=digest(p),bytes=p.stat().st_size))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(D/'final-audit-result.json').write_text(json.dumps(dict(status='PASS',checks=checks,files=len(manifest),source_pins_unchanged=True,owner_directions_unchanged=True),indent=2)+'\n')
print(json.dumps(dict(status='PASS',checks=checks,files=len(manifest),source_pins_unchanged=True,owner_directions_unchanged=True)))
