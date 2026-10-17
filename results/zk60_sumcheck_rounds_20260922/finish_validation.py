#!/usr/bin/env python3
"""Close only the missing-fixture gate, then execute the pending receipt gates."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path('/tmp/zk60-rounds-20260922')
BASE = Path('/tmp/wt-zk60-shaped-20260920')
HERE = Path(__file__).resolve().parent
FIRST = HERE / 'validation-1'
OUT = HERE / 'validation-2'
prior = json.loads((FIRST / 'validation.json').read_text())
assert prior['state'] == 'failed' and prior['error'] == 'native-library-tests failed'
summary = (FIRST / 'native-library-tests.log').read_text()
assert '511 passed; 1 failed; 17 ignored' in summary
assert 'no pre-lane toy receipt was found' in summary
assert summary.count(' ... FAILED') == 1
for r in prior['runs']:
    assert hashlib.sha256((FIRST / (r['name'] + '.log')).read_bytes()).hexdigest() == r['log_sha256']
    assert r['exit_code'] == (101 if r['name'] == 'native-library-tests' else 0)
rows = [json.loads(s) for s in (FIRST / 'native-test-build.log').read_text().splitlines() if s.startswith('{')]
bins = [Path(r['executable']) for r in rows if r.get('reason') == 'compiler-artifact'
        and r.get('target', {}).get('name') == 'hashline' and r.get('profile', {}).get('test') and r.get('executable')]
assert len(bins) == 1
test_binary = bins[0]
example = ROOT / 'hashline/target/release/examples/zk60_private_block'
old = BASE / 'hashline/target/release/examples/zk60_private_block'
OUT.mkdir(exist_ok=False)
env = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
env.update(RAYON_NUM_THREADS='2')
report = {'state': 'waiting-for-heavy-lock', 'runs': [], 'cpu_only': True,
          'model_scale_speed_claim': False, 'privacy_extension': False,
          'prior_record': '../validation-1/validation.json',
          'prior_record_sha256': hashlib.sha256((FIRST / 'validation.json').read_bytes()).hexdigest(),
          'qualification': '511 native tests passed initially; sole missing-fixture failure rerun with authentic archived receipt, no source change',
          'source_hashes_before': prior['source_hashes_before'],
          'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}

def save():
    (OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')

def check_sources_and_fixtures():
    for p, h in prior['source_hashes_before'].items():
        assert hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h, p
    for p, h in json.loads((HERE / 'fixture-hashes.json').read_text()).items():
        assert hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h, p
    for row in json.loads((HERE / 'pre-lane-fixtures.json').read_text()):
        for key in ['source', 'baseline_copy', 'candidate_copy']:
            assert hashlib.sha256(Path(row[key]).read_bytes()).hexdigest() == row['sha256']

def run(name, args):
    report.update(state='running', current=name); save()
    print('START ' + name, flush=True)
    start = time.monotonic()
    log = OUT / (name + '.log')
    with log.open('w') as f:
        p = subprocess.run(args, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT)
    report['runs'].append({'name': name, 'command': args, 'exit_code': p.returncode,
                          'elapsed_shared_seconds': time.monotonic() - start,
                          'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
    save()
    assert p.returncode == 0, name + ': ' + log.read_text()[-2000:]
    print('DONE ' + name, flush=True)
    return log.read_text()

save()
try:
    with open('/tmp/zk-heavy.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        check_sources_and_fixtures()
        log = run('pre-lane-fixture', [str(test_binary), '--exact', 'private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies', '--nocapture'])
        assert '1 passed; 0 failed' in log and '1 archived toy receipts still verify' in log
        reference = json.loads((BASE / 'results/zk60_shaped_integration_20260922/baseline/validation.json').read_text())
        assert hashlib.sha256(old.read_bytes()).hexdigest() == reference['binary_hashes']['hashline/target/release/examples/zk60_private_block']
        fresh = OUT / 'native-block'
        run('block-prove', [str(example), 'prove', str(fresh)])
        for name, binary, receipt in [('block-fresh-verify', example, fresh),
                                      ('block-old-verifier', old, fresh),
                                      ('block-old-receipt', example, BASE / 'results/zk60_shaped_integration_20260922/baseline/native-block')]:
            log = run(name, [str(binary), 'verify', str(receipt)])
            assert 'ACCEPT: 2816472 bytes' in log and log.count('refused:') == 3, name
        report['binary_hashes'] = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [test_binary, example, old]}
        report['receipt_hashes'] = {str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in fresh.iterdir() if p.is_file()}
        check_sources_and_fixtures()
    report['source_hashes_after'] = prior['source_hashes_before']
    report.update(state='passed', current=None)
    save(); (OUT / 'run.done').write_text('0\n')
    print('PASS: core debug/release, 512 native tests in full+targeted runs, cross-version receipts and nine corruptions', flush=True)
except BaseException as exc:
    report.update(state='failed', error=str(exc)); save()
    (OUT / 'run.done').write_text('1\n')
    raise
