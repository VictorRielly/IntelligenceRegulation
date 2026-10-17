#!/usr/bin/env python3
"""Grouped-equality A/B on the real dense 125M block, after correctness passes.

Shared-machine CPU diagnostics, not an 8B/GPU or quiesced publication result.
The old and new test binaries both retain identical oracle checks for small slots;
their time is INCLUDED, so do not claim an isolated production speed factor.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
BASE = Path('/tmp/zk60-encode-20260922')
CANDIDATE = Path('/tmp/zk60-groups-20260926')
OUT = HERE / 'dense-ab-1'
v = json.loads((HERE / 'validation-1/validation.json').read_text())
assert v['state'] == 'passed', 'correctness must pass before benchmarking'
b = json.loads((HERE.parent / 'zk60_encode_allocation_20260922/validation-1/validation.json').read_text())
old_paths = [BASE / p for p in b['binary_hashes'] if '/deps/hashline-' in p]
new_paths = [Path(p) for p in v['binary_hashes'] if '/deps/hashline-' in p]
assert len(old_paths) == len(new_paths) == 1
old, new = old_paths[0], new_paths[0]
OUT.mkdir(exist_ok=False)
report = {'state': 'waiting-for-heavy-lock', 'runs': [], 'cpu_only': True,
          'synthetic_dense_public_weights': True, 'model_scale_speed_claim': False,
          'candidate_includes_small_slot_oracle': True,
          'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}

def save():
    (OUT / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')

def pins(root, expected):
    for name, h in expected.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == h, name

env = {k: val for k, val in os.environ.items() if not k.startswith('HL_')}
env.update(RAYON_NUM_THREADS='2', HL_PB_WEIGHTS='dense', HL_PB_TIMING='1')
test = 'private_block::rulings_tests::private_block_125m_one_block'
save()
print('Correctness passed; waiting for heavy lock for dense 125M A/B', flush=True)
try:
    with open('/tmp/zk-heavy.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        pins(BASE, b['source_hashes_after'])
        pins(CANDIDATE, v['source_hashes_after'])
        assert hashlib.sha256(old.read_bytes()).hexdigest() == b['binary_hashes'][str(old)]
        assert hashlib.sha256(new.read_bytes()).hexdigest() == v['binary_hashes'][str(new)]
        for i, (arm, binary) in enumerate([('warm-old', old), ('warm-new', new), ('old', old), ('new', new), ('new', new), ('old', old)]):
            # This run approaches 11 GiB. Do not launch it on a memory-starved box.
            mem = dict(line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines())
            available = int(mem['MemAvailable'].split()[0]) * 1024
            if available < 11 * 1024**3:
                raise RuntimeError('less than 11 GiB available; dense A/B not started')
            name = f'{i:02}-{arm}'
            report.update(state='running', current=name)
            save()
            cmd = [str(binary), '--ignored', '--exact', test, '--nocapture', '--test-threads=1']
            start = time.monotonic()
            print('START ' + name, flush=True)
            log = OUT / (name + '.log')
            with log.open('w') as f:
                p = subprocess.run(cmd, cwd=CANDIDATE if arm.endswith('new') else BASE, env=env, stdout=f, stderr=subprocess.STDOUT)
            text = log.read_text()
            match = re.search(r'125M ONE BLOCK: prove ([0-9.]+) s, verify from bytes ([0-9.]+) s, receipt (\d+) B, peak RSS ([0-9.]+) MiB .* witness build ([0-9.]+) s', text)
            row = {'name': name, 'arm': arm, 'warmup': arm.startswith('warm-'), 'command': cmd, 'exit_code': p.returncode,
                   'wall_seconds': time.monotonic() - start,
                   'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
            if match:
                row.update(prove_seconds=float(match[1]), verify_seconds=float(match[2]),
                           receipt_bytes=int(match[3]), peak_rss_mib=float(match[4]), witness_seconds=float(match[5]))
            report['runs'].append(row)
            save()
            assert p.returncode == 0 and match and '1 passed; 0 failed' in text, name
            assert row['receipt_bytes'] == 40783352
            print('DONE ' + name + ' prove=' + str(row['prove_seconds']), flush=True)
        pins(BASE, b['source_hashes_after'])
        pins(CANDIDATE, v['source_hashes_after'])
    report.update(state='passed', current=None)
    save()
    (OUT / 'run.done').write_text('0\n')
except BaseException as exc:
    report.update(state='failed', error=str(exc))
    save()
    (OUT / 'run.done').write_text('1\n')
    raise
