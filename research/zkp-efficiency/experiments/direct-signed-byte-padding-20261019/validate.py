"""Final provenance/consistency gate. No native build or proof execution."""
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import resource
import signal
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261019T191854Z-6444ea2f'
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
started=time.perf_counter()
checks=0


def check(ok):
    global checks
    assert ok
    checks+=1


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


pins=json.loads((HERE/'source-pins.json').read_text())
manifest=json.loads((HERE/'native/manifest_frozen.json').read_text())['files']
r8='/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8/'
matches=0
for p in pins:
    check(sha(Path(p['source']))==p['sha256'])
    check(sha(HERE/p['snapshot'])==p['sha256'])
    if p['source'].startswith(r8):
        check(manifest[p['source'][len(r8):]]==p['sha256'])
        matches+=1
check(matches==14)

# Apply the review patch in memory ONLY, checking every removal/context line.
old=(HERE/'native/hashline__src__private_block__trained_block.rs').read_text().splitlines(True)
patch=(HERE/'review-only-direct-signed-byte-padding.patch').read_text().splitlines(True)
out=[]
cursor=0
hunks=0
for line in patch:
    if line.startswith(('--- ','+++ ')):
        continue
    if line.startswith('@@'):
        match=re.match(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',line)
        check(match is not None)
        old_start=int(match[1])-1
        check(old_start>=cursor)
        out.extend(old[cursor:old_start]);cursor=old_start;hunks+=1
    elif line.startswith(' '):
        check(old[cursor]==line[1:]);out.append(old[cursor]);cursor+=1
    elif line.startswith('-'):
        check(old[cursor]==line[1:]);cursor+=1
    elif line.startswith('+'):
        out.append(line[1:])
    else:
        raise AssertionError('unexpected patch record')
out.extend(old[cursor:])
candidate=''.join(out)
check(candidate==(HERE/'candidate-trained_block.rs').read_text())
check(hunks==4)
check(candidate.count('pad_matrix_bytes(')==10)
check('.i8s()' not in candidate)
check('fn pad_matrix_bytes(w: &[u8]' in candidate)
check('*dst = *value as i8;' in candidate and 'row[inner[i]] = *v as i8;' in candidate)
oldtext=''.join(old)
# Admission/read/check regions before changed padding calls are byte identical.
load_start=oldtext.index('fn load_array_checked(')
load_end=oldtext.index('    fn load_layer_mode(')
check(oldtext[load_start:load_end]==candidate[candidate.index('fn load_array_checked('):candidate.index('    fn load_layer_mode(')])
ls=oldtext.index('    fn load_layer_mode(')
le=oldtext.index('        let aw = [',ls)
check(oldtext[ls:le]==candidate[candidate.index('    fn load_layer_mode('):candidate.index('        let aw = [',candidate.index('    fn load_layer_mode('))])
tail=oldtext.index('        let public = AttentionPublic::new_shaped(sh, &aw[0]')
tailend=oldtext.index('/// a true `(to, ti)` row-major matrix')
check(oldtext[tail:tailend]==candidate[candidate.index('        let public = AttentionPublic::new_shaped(sh, &aw[0]'):candidate.index('/// a true `(to, ti)` row-major matrix')])

main=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'audit-result.json').read_text())
check(main['status']==audit['status']=='PASS')
check(main['matrix_cases']==main['layouts']*9==432)
check(main['exhaustive_byte_sweeps']==3)
check(sum(main['controls'][s] for s in ['short','long','dtype_before_length','shape_before_length'])==1728)
check(sum(main['controls'][s] for s in ['unsigned','source_stride','pad_nonzero','prefix'])==942)
for r in [main,audit]:
    check(r['threads']==1)
    check(r['wall_seconds']<59)
    check(r['rss_kib']<512*1024)
    check(len(r['affinity'])==1)
commands=json.loads((HERE/'commands.json').read_text())
check(len(commands)>=2)
check({'experiment.py','audit.py'}.issubset({Path(c['argv'][-1]).name for c in commands}))
for c in commands:
    check(c['exit_code']==0)
    source=Path(c['argv'][-1])
    check(source.name in ['experiment.py','audit.py','validate.py'])
    if sha(source)!=c['source_sha256']:
        source=HERE/'before-idempotent-validation'/source.name
    check(sha(source)==c['source_sha256'])
    check((HERE/c['stderr']).read_text()=='')
    check(json.loads((HERE/c['stdout']).read_text())['status']=='PASS')

base_sources=(HERE/'startup/sources.jsonl').read_bytes()
current_sources=(ROOT/'sources.jsonl').read_bytes()
check(current_sources.startswith(base_sources))
check((ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes()))
records=json.loads((HERE/'source-records.json').read_text())
added=[json.loads(l) for l in current_sources[len(base_sources):].decode().splitlines()]
check(added==records and len(added)==7)
check(len(current_sources.splitlines())==485)
for r in records:
    check(r['accessed']=='2026-10-19')
    check(r['run_id']==RUN)
    check(r['reproduced_performance'] is False and r['external_execution'] is False)
    check(r['url'].startswith('https://'))
check(sum(r['inspected_commit_id'] is not None for r in records)==1)
for p in ['AGENDA.md','CLAUDE.md','ZK60_THROUGHPUT_TARGET.md']:
    m=next(m for m in json.loads((HERE/'startup-manifest.json').read_text()) if Path(m['path']).name==p)
    check(sha(Path(m['path']))==m['sha256'])

target=json.loads((HERE/'target-accounting.json').read_text())
for k in ['new_target_proofs','new_target_passes','new_target_positions','passes']:
    check(target[k]==0)
for k in ['context_length','device','target_steady_state_positions_per_second','target_total_workload_positions_per_second','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:
    check(target[k] is None)
owner=target['carried_owner']
check(owner['context_length']==128 and owner['blocks']==32 and owner['passes']==1 and owner['threads']==16)
check(owner['researcher_independent_verification'] is False and owner['target_credit']==0)
check(math.isclose(owner['all_load_deletion_optimistic_total_seconds'],433.991))
check(math.isclose(owner['diagnostic_positions_per_second'],128/478.737))
for row in json.loads((HERE/'payload-ledger.json').read_text())['rows']:
    check(row['full_envelope_saving_bytes']==0)
    check(row['pad_phase_bytes']==461952000)
    check(row['record_phase_bytes']>row['pad_phase_bytes'])

queue=json.loads((HERE/'hypotheses.json').read_text())
check(len(queue)>=3 and [q['rank'] for q in queue]==list(range(1,len(queue)+1)))
for q in queue:
    check(all(k in q for k in ['baseline','eliminated_work','added_costs','end_to_end_ceiling','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','falsification']))
for p in [ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'progress'/f'{RUN}.md',ROOT/'handoffs/20261019-direct-signed-byte-padding.md',HERE/'README.md']:
    t=p.read_text()
    check(RUN in t)
    check('unbuilt' in t.lower() or 'UNBUILT' in t)

result=dict(status='PASS',checks=checks,source_pins=len(pins),r8_manifest_matches=matches,
            patch_hunks_checked_in_memory=hunks,prior_findings_and_sources_preserved=True,
            wall_seconds=time.perf_counter()-started,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            threads=1,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            scope='Static patch/source/evidence/report consistency only; no Rust compile or proof.')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
