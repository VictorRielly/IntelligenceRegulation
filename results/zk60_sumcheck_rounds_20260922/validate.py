#!/usr/bin/env python3
"""Sandbox CPU validation of the isolated, source-pinned R1d candidate."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path('/tmp/zk60-rounds-20260922')
BASE = Path('/tmp/wt-zk60-shaped-20260920')
HERE = Path(__file__).resolve().parent
OUT = HERE / 'validation-1'
CARGO = '/home/victor/.cargo/bin/cargo'
ENV = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
ENV.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2')
OUT.mkdir(exist_ok=False)
STATE = {'state': 'starting', 'cpu_only': True, 'model_scale_speed_claim': False,
         'privacy_extension': False, 'runs': [], 'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}

def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for crate in ['zkp-core', 'hashline', 'private-block-kernel', 'private-block-kernel-shaped']
            for p in sorted((ROOT / crate).rglob('*'))
            if p.is_file() and not any(x.startswith('target') for x in p.relative_to(ROOT).parts)
            and p.suffix in ['.rs', '.toml', '.lock', '.cu']}

def save():
    (OUT / 'validation.json').write_text(json.dumps(STATE, indent=2) + '\n')

def run(name, args):
    STATE.update(state='running', current=name)
    save()
    print('START ' + name, flush=True)
    start = time.monotonic()
    log = OUT / (name + '.log')
    with log.open('w') as f:
        p = subprocess.run(args, cwd=ROOT, env=ENV, stdout=f, stderr=subprocess.STDOUT)
    STATE['runs'].append({'name': name, 'command': args, 'exit_code': p.returncode,
                          'elapsed_shared_seconds': time.monotonic() - start,
                          'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
    save()
    print('DONE ' + name + ' exit=' + str(p.returncode), flush=True)
    if p.returncode:
        print('\n'.join(log.read_text().splitlines()[-28:]), flush=True)
        raise RuntimeError(name + ' failed')
    return log

def cargo(crate, *args):
    return [CARGO, args[0], '--offline', '--locked', '--manifest-path', str(ROOT / crate / 'Cargo.toml'), *args[1:]]

try:
    STATE['source_hashes_before'] = hashes()
    STATE['state'] = 'waiting-for-build-lock'
    save()
    print('Waiting for shared build lock; no escalation requested', flush=True)
    with open('/tmp/zk-build.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        run('core-debug', cargo('zkp-core', 'test', '--', '--test-threads=2'))
        run('core-release', cargo('zkp-core', 'test', '--release', '--', '--test-threads=2'))
        build = run('native-test-build', cargo('hashline', 'test', '--release', '--features', 'stable-weight-storage', '--lib', '--no-run', '--message-format=json'))
        artifacts = [json.loads(line) for line in build.read_text().splitlines() if line.startswith('{')]
        bins = [Path(a['executable']) for a in artifacts if a.get('reason') == 'compiler-artifact'
                and a.get('target', {}).get('name') == 'hashline' and a.get('profile', {}).get('test') and a.get('executable')]
        assert len(bins) == 1, bins
        test_binary = bins[0]
        run('native-example-build', cargo('hashline', 'build', '--release', '--features', 'stable-weight-storage', '--example', 'zk60_private_block'))
    STATE['state'] = 'waiting-for-heavy-lock'
    save()
    with open('/tmp/zk-heavy.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        run('native-library-tests', [str(test_binary), '--test-threads=2', '--nocapture'])
        example = ROOT / 'hashline/target/release/examples/zk60_private_block'
        old = BASE / 'hashline/target/release/examples/zk60_private_block'
        reference = json.loads((BASE / 'results/zk60_shaped_integration_20260922/baseline/validation.json').read_text())
        assert hashlib.sha256(old.read_bytes()).hexdigest() == reference['binary_hashes']['hashline/target/release/examples/zk60_private_block']
        fresh = OUT / 'native-block'
        run('block-prove', [str(example), 'prove', str(fresh)])
        for name, binary, receipt in [('block-fresh-verify', example, fresh),
                                      ('block-old-verifier', old, fresh),
                                      ('block-old-receipt', example, BASE / 'results/zk60_shaped_integration_20260922/baseline/native-block')]:
            log = run(name, [str(binary), 'verify', str(receipt)])
            assert 'ACCEPT:' in log.read_text() and log.read_text().count('refused:') == 3
        STATE['binary_hashes'] = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [test_binary, example, old]}
    STATE['source_hashes_after'] = hashes()
    assert STATE['source_hashes_before'] == STATE['source_hashes_after'], 'source changed during validation'
    STATE.update(state='passed', current=None)
    save()
    (OUT / 'run.done').write_text('0\n')
    print('PASS: all candidate gates; no model-scale speed or privacy acceptance implied', flush=True)
except BaseException as exc:
    STATE.update(state='failed', error=str(exc))
    save()
    (OUT / 'run.done').write_text('1\n')
    raise
