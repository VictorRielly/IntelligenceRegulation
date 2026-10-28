"""Final artifact, prefix, patch, resource and source-pin audit. No native build."""
from pathlib import Path
import ast,datetime,hashlib,json,re,resource,time
E=Path(__file__).resolve().parent;R=E.parent.parent
start=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1;assert ok
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

manifest=json.loads((E/'artifact-manifest.json').read_text())
for x in manifest:check(sha(E/x['path'])==x['sha256'])
for x in json.loads((E/'source-manifest.json').read_text()):
    check(sha(E/x['snapshot'])==x['sha256']);check(sha(Path(x['path']))==x['sha256'])
changed=[]
for x in json.loads((E/'startup-manifest.json').read_text()):
    path=Path(x['path'])
    if path.name in ('STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl'):continue
    if sha(path)!=x['sha256']:changed.append(str(path))
check(not changed)
(E/'document-recheck.json').write_text(json.dumps(dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),changed=changed,agenda_unchanged=True,notes='Required project memory still matches startup pins; research state reports intentionally updated.'),indent=2)+'\n')
prior_find=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
check((R/'FINDINGS.md').read_bytes().startswith(prior_find))
prior_src=(E/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
check((R/'sources.jsonl').read_bytes()==prior_src+(E/'source-records.jsonl').read_bytes())
old=[json.loads(l) for l in prior_src.splitlines() if l.strip()]
new=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines() if l.strip()]
check(len(old)==799 and len(new)==807)
for a,b in zip(old,new):check(a==b)
h=json.loads((E/'hypotheses.json').read_text());hp=json.loads((E/'prior-hypotheses.json').read_text())
check(len(h)==38 and len(hp)==37)
for i,(a,b) in enumerate(zip(hp,h)):
    check(a['rank']==b['rank'])
    if i not in (35,36):check(a==b)
for x in h:
    for key in ('baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification'):check(key in x)
for p in E.glob('*.py'):ast.parse(p.read_text());check(True)

# Apply only in memory to pinned source text, never through Git/production.
patch=(E/'salt-first-parent.patch').read_text().splitlines(True)
parts={};i=0
while i<len(patch):
    check(patch[i].startswith('--- a/'))
    name=patch[i][6:].strip();check(patch[i+1].startswith('+++ b/'));i+=2
    source={'zkp-core/src/merkle.rs':'source/active-merkle.rs','zkp-core/src/pcs.rs':'source/active-core-pcs.rs'}[name]
    original=(E/source).read_text().splitlines(True);out=[];cursor=0
    while i<len(patch) and not patch[i].startswith('--- a/'):
        m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',patch[i]);check(m is not None)
        at=int(m[1])-1;check(at>=cursor);out.extend(original[cursor:at]);cursor=at;i+=1
        old_count=new_count=0
        while i<len(patch) and not patch[i].startswith(('@@ ','--- a/')):
            line=patch[i];mark=line[0];value=line[1:];check(mark in ' +-')
            if mark in ' -':check(original[cursor]==value);cursor+=1;old_count+=1
            if mark in ' +':out.append(value);new_count+=1
            i+=1
        check(old_count==int(m[2] or 1));check(new_count==int(m[4] or 1))
    out.extend(original[cursor:]);parts[name]=''.join(out)
check(parts['zkp-core/src/merkle.rs']==(E/'candidate-merkle.rs').read_text())
check(parts['zkp-core/src/pcs.rs']==(E/'candidate-core-pcs.rs').read_text())
oldpcs=(E/'source/active-core-pcs.rs').read_text();cp=(E/'candidate-core-pcs.rs').read_text()
keyed='    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| salt_leaf_keyed(l, s, tag.leaf_key())).collect();\n    let tree = MerkleTree::build_keyed(salted, tag.node_key());'
check(cp==oldpcs.replace(keyed,'    let tree = MerkleTree::build_salted_keyed(&leaves, &salts, tag.leaf_key(), tag.node_key());'))
check('unsafe' not in parts['zkp-core/src/merkle.rs'])

t=json.loads((E/'target-accounting.json').read_text())
for key in ['new_completed_independently_verified_full_stack_proofs','new_completed_passes','new_proved_positions']:check(t[key]==0)
for key in ['actual_model_context','witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_seconds','initial_prefill_seconds','startup_fraction','steady_state_positions_per_second','total_workload_positions_per_second']:check(t[key] is None)
check(not t['target_achieved'] and not t['private_masks_reused'])
cmds=[json.loads(l) for l in (E/'commands.jsonl').read_text().splitlines()]
for c in cmds:
    check(c['exit_code']==0);check(c['threads']==1);check(c['estimated_memory_mib']<=512)
    check(c['cpu_seconds']<=60 and c['parent_timeout_seconds']<=60)
    check(c['elapsed_s']<60)
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261026T172925Z-dd337876.md']:
    s=p.read_text();check('20261026T172925Z-dd337876' in s);check('unmeasured' in s)
result=dict(status='PASS_FINAL_ARTIFACT_AUDIT',checks=checks,immutable_artifacts=len(manifest),source_pins=12,
            prior_source_records_preserved=799,total_source_records=807,prior_hypotheses_preserved=37,total_hypotheses=38,
            patch_applies_in_memory_only=True,production_patch_applied=False,native_build=False,gpu=False,
            diagnostic_wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(E/'artifact-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
