"""Final provenance/patch/report consistency gates; bounded, research-only."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261019T181854Z-f5bd1f03'
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
t0=time.perf_counter()
checks=0


def check(ok):
    global checks
    assert ok
    checks+=1


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


for pin in json.loads((HERE/'source-pins.json').read_text()):
    check(sha(Path(pin['source']))==pin['sha256'])
    check(sha(HERE/pin['snapshot'])==pin['sha256'])
for snap in json.loads((HERE/'startup-manifest.json').read_text()):
    check(sha(HERE/snap['snapshot'])==snap['sha256'])
for n in ['FINDINGS.md','sources.jsonl']:
    check((ROOT/n).read_bytes().startswith((HERE/'startup'/n).read_bytes()))
rows=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
new=[x for x in rows if x.get('run_id')==RUN]
check(len(rows)==478 and len(new)==7)
check(new==json.loads((HERE/'source-records.json').read_text()))
for x in new:
    check(x['access_date']=='2026-10-19')
    check(x['url'].startswith('https://'))
    check(x['reproduced_performance'] is False)
    check(x['inspected_commit_id'] is None)

main=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'audit-result.json').read_text())
check(main['status']==audit['status']=='PASS')
check(main['threads']==audit['threads']==1)
check(main['rss_kib']<512*1024 and audit['rss_kib']<512*1024)
check(main['wall_seconds']<60 and audit['wall_seconds']<60)
check(main['fixtures']==audit['fixtures']==48)
check(main['checks']==7074)
check(main['rejected_mutations']==2200)
check(audit['source_pins']==18 and audit['r8_manifest_matches']==14)
target=json.loads((HERE/'target-accounting.json').read_text())
for k in ['new_target_proofs','new_target_passes','new_target_positions']:
    check(target[k]==0)
for k in ['device','context_length','target_steady_state_positions_per_second',
          'target_total_workload_positions_per_second','startup_fraction','proof_seconds',
          'witness_seconds','serialization_seconds','verification_seconds']:
    check(target[k] is None)
q=json.loads((HERE/'hypotheses.json').read_text())
check(len(q)>=3)
check([x['rank'] for x in q]==list(range(1,len(q)+1)))
for h in q:
    for key in ['baseline','eliminated_work','added_costs','falsification','prerequisites','exactness','privacy_soundness']:
        check(bool(h[key]))

commands=json.loads((HERE/'commands.json').read_text())
for name in ['experiment.py','audit.py']:
    latest=next(c for c in reversed(commands) if c['argv'][-1].endswith('/'+name))
    check(latest['exit_code']==0)
    check(latest['source_sha256']==sha(HERE/name))
    check((HERE/latest['stderr']).read_text()=='')
    logged=json.loads((HERE/latest['stdout']).read_text())
    check(logged==main if name=='experiment.py' else logged==audit)
check(any(c['exit_code']==1 for c in commands))
check((HERE/'before-support-reservation-fix/audit.py.stderr.log').read_text().endswith('AssertionError\n'))
check(json.loads((HERE/'initial-control-misclassification/failure.json').read_text())['exit']==1)

patch=(HERE/'review-only-owned-constructors.patch').read_text()
pm=json.loads((HERE/'patch-metadata.json').read_text())
check(pm['patch_sha256']==hashlib.sha256(patch.encode()).hexdigest())
check(pm['status']=='UNBUILT_UNAPPLIED_REVIEW_PROPOSAL')
originals={
    'hashline/src/private_block.rs':'native/hashline__src__private_block.rs',
    'hashline/src/private_block/trained_block.rs':'native/hashline__src__private_block__trained_block.rs',
}
modified={}
for chunk in patch.split('--- a/')[1:]:
    lines=chunk.splitlines(keepends=True)
    path=lines[0].strip()
    source=(HERE/originals[path]).read_text().splitlines(keepends=True)
    result=[];pos=0;i=2
    while i<len(lines):
        m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',lines[i])
        check(m is not None)
        start=int(m.group(1))-1;old_count=int(m.group(2) or 1);new_count=int(m.group(4) or 1)
        check(start>=pos);result+=source[pos:start];pos=start
        i+=1;seen_old=0;seen_new=0
        while i<len(lines) and not lines[i].startswith('@@'):
            op=lines[i][0];value=lines[i][1:]
            check(op in ' +-')
            if op in ' -':
                check(source[pos]==value);pos+=1;seen_old+=1
            if op in ' +':
                result.append(value);seen_new+=1
            i+=1
        check(seen_old==old_count and seen_new==new_count)
    result+=source[pos:];modified[path]=''.join(result)
check(len(modified)==2)
block=modified['hashline/src/private_block.rs']
check(block.count('pub(crate) fn new_shaped_owned')==2)
check('Self::check_words(sh, &wq, &wk, &wv, &wo, &gamma_a, &rope_cos, &rope_sin, &exp)?;' in block)
check('Self::check_words(sh, &gamma_m, &wg_t, &wu_t, &wd_t, act)?;' in block)
check('let act: [i16; 256] = act.try_into()' in block)
check('let [wq_p, wk_p, wv_p, wo_p, ga_p] = aw;' in modified['hashline/src/private_block/trained_block.rs'])

for p in [ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'FINDINGS.md',ROOT/'progress'/f'{RUN}.md']:
    check(RUN in p.read_text())
    check('No speed improvement measured.' in p.read_text())
for p in [HERE/'README.md',ROOT/'handoffs/20261019-public-constructor-transfer.md',HERE/'search-log.md']:
    check(p.exists() and p.stat().st_size>100)
now=datetime.datetime.now(datetime.timezone.utc)
check(now<datetime.datetime(2026,10,19,18,38,54,tzinfo=datetime.timezone.utc))
out=dict(status='PASS',checks=checks,utc=now.isoformat(),wall_seconds=time.perf_counter()-t0,
         scope='Provenance, saved synthetic results, report/target separation, and in-memory exact patch-hunk applicability; NOT Rust compilation/native validation.')
(HERE/'validation.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,sort_keys=True))
