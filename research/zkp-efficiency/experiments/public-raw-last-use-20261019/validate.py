"""Final source/provenance/consistency checks, without any native execution."""
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
RUN='20261019T201854Z-ec298e23'
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
t0=time.perf_counter();checks=0


def check(ok):
    global checks
    assert ok
    checks+=1


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


pins=json.loads((HERE/'source-pins.json').read_text())
manifest_path=next(Path(p['source']) for p in pins if Path(p['source']).name=='manifest_frozen.json')
manifest=json.loads(manifest_path.read_text())['files'];matches=0
r8='/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8/'
for p in pins:
    check(sha(Path(p['source']))==p['sha256'])
    if p['source'].startswith(r8):
        check(manifest[p['source'][len(r8):]]==p['sha256']);matches+=1
for p in (HERE/'native').iterdir():
    check(sha(p)==next(x['sha256'] for x in pins if Path(x['snapshot']).name==p.name))
check(len(pins)==18 and matches==14)
for p in json.loads((HERE/'input-pins.json').read_text()):check(sha(HERE/p['path'])==p['sha256'])

# Apply hunks in memory, checking all source/context lines. No production writes.
old=(HERE/'native/hashline__src__private_block__trained_block.rs').read_text().splitlines(True)
patch=(HERE/'review-only-raw-last-use.patch').read_text().splitlines(True)
out=[];cursor=0;hunks=0
for line in patch:
    if line.startswith(('--- ','+++ ')):continue
    if line.startswith('@@'):
        m=re.match(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',line)
        check(m is not None);start=int(m[1])-1;check(start>=cursor)
        out.extend(old[cursor:start]);cursor=start;hunks+=1
    elif line.startswith(' '):check(old[cursor]==line[1:]);out.append(old[cursor]);cursor+=1
    elif line.startswith('-'):check(old[cursor]==line[1:]);cursor+=1
    elif line.startswith('+'):out.append(line[1:])
    else:raise AssertionError('unknown diff record')
out.extend(old[cursor:]);candidate=''.join(out);original=''.join(old)
check(candidate==(HERE/'candidate-trained_block.rs').read_text());check(hunks==2)
insert=('        // All raw PUBLIC arrays have passed their checks and been copied\n'
        '        // into the owned block. End their lifetime before record hashing.\n'
        '        let _ = (wq.sha256, exp.sha256);\n'
        '        drop((wq, wk, wv, wo, ga, gm, wg, wu, wd, exp, act));\n')
check(candidate.count(insert)==1)
restored=candidate.replace(insert,'').replace('        record.own = own;\n','        record.own = own;\n        let _ = (wq.sha256, exp.sha256);\n',1)
check(restored==original)
# No raw array can be used after the inserted drop in the method tail.
tail=candidate.split(insert,1)[1].split('    /// The PRIVATE hidden input',1)[0]
check(not re.search(r'\b(wq|wk|wv|wo|ga|gm|wg|wu|wd|exp|act)\.',tail))
check('impl Drop for Array' not in original)
constructors=(HERE/'native/hashline__src__private_block.rs').read_text()
for field in ['wq','wk','wv','wo','gamma_a','rope_cos','rope_sin','exp','gamma_m','wg_t','wu_t','wd_t']:
    check(f'{field}: {field}.to_vec()' in constructors)

main=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'audit-result.json').read_text())
check(main['status']==audit['status']=='PASS');check(main['fixtures']==48)
check(main['accepted_path_cases']==audit['accepted_path_cases']==78)
check(main['honest_refusals']==18)
check(main['mutation_path_cases']==audit['independent_first_error_checks']==6720)
check(audit['independent_corruptions']==1404)
check(main['negative_controls']==dict(early_drop_refused=78,digest_copy_does_not_release=78,reload_digest_mismatch=78))
for r in [main,audit]:
    check(r['threads']==1 and len(r['affinity'])==1 and r['nice']==19)
    check(r['rss_kib']<512*1024 and r['wall_seconds']<59)
commands=json.loads((HERE/'commands.json').read_text())
check({'experiment.py','audit.py'}.issubset({Path(c['argv'][-1]).name for c in commands}))
for c in commands:
    check(c['exit_code']==0)
    src=Path(c['argv'][-1])
    if sha(src)!=c['source_sha256']:src=HERE/'before-independent-control-audit'/src.name
    check(sha(src)==c['source_sha256'])
    check((HERE/c['stderr']).read_text()=='')
    check(json.loads((HERE/c['stdout']).read_text())['status']=='PASS')

base=(HERE/'startup/sources.jsonl').read_bytes();current=(ROOT/'sources.jsonl').read_bytes()
check(current.startswith(base))
records=json.loads((HERE/'source-records.json').read_text())
check([json.loads(l) for l in current[len(base):].decode().splitlines()]==records)
check(len(records)==8 and len(current.splitlines())==493)
check((ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes()))
for r in records:
    check(r['access_date']=='2026-10-19' and r['run_id']==RUN)
    check(r['external_execution'] is False and r['reproduced_performance'] is False)
    check(all(k in r for k in ['published','updated','date_evidence','url','implementation_license','inspected_commit_id']))
check(all(r['inspected_commit_id'] is None for r in records))
for record in json.loads((HERE/'startup-manifest.json').read_text()):
    if Path(record['path']).name in ['CLAUDE.md','AGENDA.md','ZK60_THROUGHPUT_TARGET.md']:
        check(sha(Path(record['path']))==record['sha256'])

t=json.loads((HERE/'target-accounting.json').read_text())
for k in ['new_target_proofs','new_target_passes','new_target_positions','passes']:check(t[k]==0)
for k in ['context_length','device','target_steady_state_positions_per_second','target_total_workload_positions_per_second','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:check(t[k] is None)
owner=t['carried_owner'];check(owner['researcher_independent_verification'] is False and owner['target_credit']==0)
check(math.isclose(owner['diagnostic_positions_per_second'],128/478.737))
check(math.isclose(owner['all_load_deletion_optimistic_total_seconds'],478.737-27.151-17.595))
rows=json.loads((HERE/'payload-ledger.json').read_text())['rows'];check(len(rows)==32)
for r in rows:
    check(r['after_envelope_bytes']==max(r['after_phase_bytes']))
    check(r['saving_bytes']==r['before_envelope_bytes']-r['after_envelope_bytes'])
    if not r['full']:check(r['saving_bytes']==0)
    elif r['constructor']=='borrowed_copy':check(r['saving_bytes']==(66977792 if r['hash_workers']==1 else 218114560))

q=json.loads((HERE/'hypotheses.json').read_text());check(len(q)>=3 and [x['rank'] for x in q]==list(range(1,len(q)+1)))
for h in q:check(all(k in h for k in ['baseline','eliminated_work','added_costs','end_to_end_ceiling','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','falsification']))
check(any(h['id']=='new-split-public-matrix-release-before-constructors' for h in q))
for p in [ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'progress'/f'{RUN}.md',ROOT/'handoffs/20261019-public-raw-last-use.md',HERE/'README.md']:
    text=p.read_text();check(RUN in text)
    check('unbuilt' in text.lower() and 'unapplied' in text.lower())
    check('0/0/0' in text and 'serialization' in text)
result=dict(status='PASS',checks=checks,source_pins=len(pins),r8_manifest_matches=matches,
    patch_hunks_checked_in_memory=hunks,prior_findings_and_sources_preserved=True,
    wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    threads=1,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,sort_keys=True))
