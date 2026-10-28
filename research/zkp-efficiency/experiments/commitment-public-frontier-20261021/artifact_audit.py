"""Final artifact/prefix/patch audit; never compiles or applies native patches."""
from pathlib import Path
import hashlib,json,re,resource,time
ROOT=Path(__file__).resolve().parent;HERE=ROOT.parent.parent
start=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    assert ok
manifest=json.loads((ROOT/'artifact-manifest.json').read_text())
for item in manifest:
    check(hashlib.sha256((ROOT/item['path']).read_bytes()).hexdigest()==item['sha256'])
for item in json.loads((ROOT/'source-manifest.json').read_text())+json.loads((ROOT/'next-source-manifest.json').read_text()):
    check(hashlib.sha256(Path(item['path']).read_bytes()).hexdigest()==item['sha256'])
    check(hashlib.sha256((ROOT/item['snapshot']).read_bytes()).hexdigest()==item['sha256'])
prior=(ROOT/'startup/FINDINGS.md').read_bytes();check((HERE/'FINDINGS.md').read_bytes().startswith(prior))
prior_sources=(ROOT/'startup/sources.jsonl').read_bytes()
new=(ROOT/'source-records.jsonl').read_bytes()
check((HERE/'sources.jsonl').read_bytes()==prior_sources+new)
check(len([l for l in prior_sources.splitlines() if l.strip()])==790)
records=[json.loads(l) for l in new.splitlines()]
check(len(records)==9)
for r in records:
    check(r['access_date']=='2026-10-21');check(r['url'].startswith('https://'))
    check(r['reproduced_performance'] is False and r['external_execution'] is False)
    for field in ['publication_date','verified_update_date','inspected_commit_id','implementation_license','access_issues']:
        check(field in r)
prior_q=json.loads((ROOT/'prior-hypotheses.json').read_text());q=json.loads((ROOT/'hypotheses.json').read_text())
check(len(q)==len(prior_q)==37);check([x['rank'] for x in q]==[x['rank'] for x in prior_q])
for old,newq in zip(prior_q,q):
    check(old==newq if old['rank'] not in (36,37) else old!=newq)
for field in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:
    check(all(field in x for x in q))

def apply_in_memory(patch,originals):
    """Strict unified-diff parser, operating on strings only."""
    lines=patch.splitlines(keepends=True);i=0;result={}
    while i<len(lines):
        check(lines[i].startswith('--- a/'))
        name=lines[i][6:].strip();i+=1
        check(lines[i].strip()=='+++ b/'+name);i+=1
        original=originals[name].splitlines(keepends=True);cursor=0;output=[]
        while i<len(lines) and not lines[i].startswith('--- '):
            m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',lines[i]);check(m is not None)
            old_at=int(m[1])-1;old_count=int(m[2] or 1);new_count=int(m[4] or 1);i+=1
            check(old_at>=cursor);output.extend(original[cursor:old_at]);cursor=old_at
            consumed=produced=0
            while i<len(lines) and not lines[i].startswith(('@@ ','--- ')):
                tag,text=lines[i][:1],lines[i][1:];i+=1
                check(tag in (' ','-','+'))
                if tag in (' ','-'):
                    check(cursor<len(original) and original[cursor]==text);cursor+=1;consumed+=1
                if tag in (' ','+'):
                    output.append(text);produced+=1
            check(consumed==old_count and produced==new_count)
        output.extend(original[cursor:]);result[name]=''.join(output)
    return result
def semantic(s):
    return '\n'.join(l for l in s.splitlines() if l.strip() and not l.lstrip().startswith('//'))
patches=[]
for label,host,kernel,kcount in [('legacy','hashline__src__gpu__cuda.rs','hashline__src__gpu__kernels.cu',1),
                               ('active','active-cuda.rs','active-kernels.cu',2)]:
    originals={'hashline/src/gpu/cuda.rs':(ROOT/'source'/host).read_text(),
               'hashline/src/gpu/kernels.cu':(ROOT/'source'/kernel).read_text()}
    changed=apply_in_memory((ROOT/(label+'-count-free.patch')).read_text(),originals)
    h=originals['hashline/src/gpu/cuda.rs']
    h=h.replace('        dev.memset_zeros(d_state.get_mut()).map_err(|e| format!("state memset: {e}"))?;\n','').replace('const B3_STATE_SLOTS: usize = 8 * 24 + 1;','const B3_STATE_SLOTS: usize = 8 * 24;')
    check(semantic(h)==semantic(changed['hashline/src/gpu/cuda.rs']))
    k=originals['hashline/src/gpu/kernels.cu']
    load='int stack_len = (int)state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j];'
    check(k.count(load)==kcount)
    k=k.replace(load,'int stack_len = row0 == 0 ? 0 : __popc((u32)(row0 / 128) - 1u) + 1;').replace('    state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j] = (u32)stack_len;\n','').replace('#define B3_STATE_SLOTS (8 * B3_MAX_DEPTH + 1)','#define B3_STATE_SLOTS (8 * B3_MAX_DEPTH)')
    check(semantic(k)==semantic(changed['hashline/src/gpu/kernels.cu']))
    patches.append({'label':label,'parsed_files':len(changed),'semantic_scope_matches':True,'native_execution':False})
result=json.loads((ROOT/'result.json').read_text());audit=json.loads((ROOT/'audit-result.json').read_text())
check(result['checks']==1528 and len(result['fixtures'])==30 and len(result['keyed_fixtures'])==19)
check(result['restart_cases']==109 and result['control_types']==26)
check(audit['checks']==1835886 and audit['symbolic_prefixes']==262144 and audit['source_pins']==9)
account=json.loads((ROOT/'target-accounting.json').read_text())
for key in ['proofs','passes','positions']:check(account[key]==0)
for key in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_rate','total_workload_rate']:check(account[key] is None)
for record in [result,audit]:check(record['wall_seconds']<60 and record['rss_kib']<512*1024)
completion=json.loads((ROOT/'completion.json').read_text());check(completion['new_positions']==0)
report=dict(status='PASS_FINAL_ARTIFACT_PREFIX_PATCH_AUDIT',checks=checks,
    immutable_artifacts=len(manifest),source_pins=9,next_inspection_pins=2,patches=patches,
    wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    prior_sources_preserved=790,prior_hypotheses_preserved=37,prior_findings_prefix_preserved=True)
(ROOT/'artifact-audit-result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
