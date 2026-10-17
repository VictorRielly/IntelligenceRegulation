#!/usr/bin/env python3
"""Bounded artifact/count checks; does not compile or execute native code."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import resource
import signal

D = Path(__file__).resolve().parent
ROOT = D.parent.parent
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
signal.alarm(59)
sha = lambda b: hashlib.sha256(b).hexdigest()
r = json.loads((D/'result.json').read_text())
assert r['status'] == 'passed'
assert sha((D/'experiment.py').read_bytes()) == r['experiment_sha256']
assert r['differential_cases'] == len(r['cases']) == 108
assert r['independent_round_oracles'] == 180
assert r['independent_final_mles'] == 432
assert r['synthetic_masked_driver_cases'] == 54
assert len(r['negative_controls']) == 8 and all(r['negative_controls'].values())
assert len(r['schedule_refusals']) == 10 and all(r['schedule_refusals'].values())
assert r['malformed_fixture_refusals'] == 8
assert r['script_wall_s_not_proving'] < 60 and r['peak_rss_kib'] < 512*1024
assert not r['native_executed'] and not r['gpu_executed']
assert all(r[x] is None for x in ('proving_seconds', 'verification_seconds', 'complete_readiness_seconds'))
for c in r['cases']:
    n = c['n']; baseline = fused = writes = 0
    if n > 1:
        fused += 4*n  # ordinary initial round
    while n > 1:
        baseline += 8*n  # K=4, round and fold read current table
        fused += 4*n     # fused fold; samples stay in local temporaries
        writes += 2*n
        n //= 2
    assert (baseline, fused, writes) == (c['baseline_reads'], c['fused_reads'], c['writes'])
pins = json.loads((D/'source-pins.json').read_text())
for pin in pins:
    assert sha(Path(pin['path']).read_bytes()) == pin['sha256'], pin['path']
for name in ('rounds', 'grouped'):
    orig = next(p for p in pins if p['path'].endswith('/sumcheck/'+name+'.rs'))
    assert sha((D/'source-snapshots'/f'{name}.rs').read_bytes()) == orig['sha256']
for filename, prefix in json.loads((D/'source-log-prefix.json').read_text()).items():
    assert sha((ROOT/filename).read_bytes()[:prefix['bytes']]) == prefix['sha256']
source_records = [json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
new = json.loads((D/'source-records.json').read_text())
assert source_records[-len(new):] == new
assert len({x['id'] for x in source_records if 'id' in x}) == len([x for x in source_records if 'id' in x])
for record in new:
    assert all(k in record for k in ('accessed', 'url', 'publication_date', 'update_date',
                                     'implementation_license', 'inspected_commit_id'))
artifact_hashes = {str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in D.rglob('*')
                   if p.is_file() and p.name not in ('validation.json', 'validation.log')}
out = dict(status='passed', run_identity=r['run_identity'], cycle='0005',
           checkpoint_utc=datetime.now(timezone.utc).isoformat(), exit_code=0,
           source_pins_match=True, previous_findings_and_source_prefixes_preserved=True,
           source_records_added=len(new), artifact_sha256=artifact_hashes,
           experiment_command='python3 experiments/fused-fold-round-20260926/experiment.py > experiments/fused-fold-round-20260926/run.log 2>&1',
           validation_command='python3 experiments/fused-fold-round-20260926/validate.py > experiments/fused-fold-round-20260926/validation.log 2>&1',
           cwd=str(ROOT), rust_sketch_compiled=False, production_edits=False,
           runtime_writes=False, gpu_jobs=False, builds=False, git_operations=False,
           dependencies_installed=False, downloaded_code_executed=False,
           external_writes_or_messages=False)
(D/'validation.json').write_text(json.dumps(out, indent=2)+'\n')
print(json.dumps(out, indent=2))
