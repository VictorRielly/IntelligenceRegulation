#!/usr/bin/env python3
"""Artifact, history, source and patch consistency; does not rerun the experiment."""
from pathlib import Path
import datetime
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sha = lambda x: hashlib.sha256(x).hexdigest()
read = lambda name: json.loads((HERE/name).read_text())
r = read('result.json')
assert r == json.loads((HERE/'run.log').read_text())
assert r['status'] == 'passed' and r['seed'] == 2026092607
assert r['threads'] == 1 and len(r['cpu_affinity']) == 1
assert r['elapsed_s'] < 60 and r['peak_rss_kib'] < 512*1024
assert r['source_sha256'] == sha((HERE/'experiment.py').read_bytes())
assert (r['multiplication_cases'], r['square_cases'], r['exponent_cases']) == (24641, 10121, 35)
assert len(r['negative_controls']) == 11 and all(r['negative_controls'].values())
assert r['fixture_refusals'] == 4
assert all(r[k] is None for k in ('proving_s','verification_s','complete_readiness_s'))
assert not r['native_compiled'] and not r['gpu_executed']
d = r['downstream']
assert (d['fused_fixtures'],d['grouped_fixtures']) == (24,13)
assert (d['fused_round_samples'],d['final_mles'],d['grouped_independent_round_points']) == (630,288,189)
assert d['zero_factor_fallbacks'] == 4

for name, pin in read('history-prefixes.json').items():
    assert sha((ROOT/name).read_bytes()[:pin['bytes']]) == pin['sha256'], name
for path, pin in read('source-pins.json').items():
    assert sha(Path(path).read_bytes()) == pin['sha256'], path
    if 'snapshot' in pin:
        assert sha((HERE/pin['snapshot']).read_bytes()) == pin['sha256']
b = read('bottleneck.json')
assert sha(Path(b['comparison_path']).read_bytes()) == b['comparison_sha256']
for row in b['runs']:
    assert sha(Path(row['log_path']).read_bytes()) == row['sha256']

# Apply the unified diff in memory, asserting every context/deleted line.
old = (HERE/'field.rs').read_text().splitlines(True)
diff = (HERE/'fp2-arithmetic.proposed.patch').read_text().splitlines(True)
out, cursor, hunks = [], 0, 0
i = 2
while i < len(diff):
    m = re.fullmatch(r'@@ -(\d+),(\d+) \+(\d+),(\d+) @@\n', diff[i])
    assert m, diff[i]
    pos = int(m[1])-1
    out.extend(old[cursor:pos]); cursor=pos; i+=1
    consumed=produced=0
    while i < len(diff) and not diff[i].startswith('@@'):
        kind, text = diff[i][0], diff[i][1:]
        if kind in ' -':
            assert old[cursor] == text
            cursor+=1; consumed+=1
        if kind in ' +':
            out.append(text); produced+=1
        assert kind in ' +-'
        i+=1
    assert consumed==int(m[2]) and produced==int(m[4])
    hunks+=1
out.extend(old[cursor:])
assert hunks==2
assert ''.join(out)==(HERE/'field.candidate.rs').read_text()
pin=read('patch-provenance.json')
for key,name in [('baseline_sha256','field.rs'),('candidate_sha256','field.candidate.rs'),('patch_sha256','fp2-arithmetic.proposed.patch')]:
    assert sha((HERE/name).read_bytes())==pin[key]

history=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
assert len({x['id'] for x in history})==len(history)
records=read('source-records.json')
assert len(records)==6 and history[-6:]==records
assert 'cycle-0007' in (ROOT/'STATE.md').read_text()
artifacts={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in HERE.iterdir()
           if p.is_file() and p.name not in ('validation.json','validation.log')}
for p in [ROOT/'STATE.md',ROOT/'FINDINGS.md',ROOT/'sources.jsonl',ROOT/'handoffs/20260926-fp2-arithmetic.md']:
    artifacts[str(p.relative_to(ROOT))]=sha(p.read_bytes())
result=dict(status='passed', run_identity=r['run_identity'],
            checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            sources_match=True, owner_logs_match=True, prior_history_prefixes_preserved=True,
            proposed_patch_hunks=hunks, proposed_patch_applies_in_memory=True,
            source_records_appended=6, artifacts_sha256=artifacts,
            experiment_command='python3 experiments/fp2-arithmetic-20260926/experiment.py > experiments/fp2-arithmetic-20260926/run.log 2>&1',
            validation_command='python3 experiments/fp2-arithmetic-20260926/validate.py > experiments/fp2-arithmetic-20260926/validation.log 2>&1',
            cwd=str(ROOT), native_builds=False, gpu_jobs=False,
            production_or_runtime_writes=False, git_operations=False,
            dependencies_installed=False, downloaded_code_executed=False,
            external_writes_or_messages=False)
(HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='artifacts_sha256'},indent=2))
