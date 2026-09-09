import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import subprocess
import time
import traceback

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path('/tmp/zk60-round12')
os.chdir(ROOT)
HEAD = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
assert HEAD.startswith('72a884e'), HEAD
ENV = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
ENV.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', ZK_THREADS='2',
           CARGO_NET_OFFLINE='true', HL_GPU='0',
           M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'))
REPORT = {'schema_version': 1, 'source_commit': HEAD,
          'scope': 'R32 typed attention message consumption and FA4 H2 public slot journal',
          'threads': 2, 'address_space_limit_bytes': 8 << 30,
          'gpu_executed': False, 'stages': [],
          'limits': ['No stable P3 prover/verifier, secret-material store or privacy acceptance.',
                     'Full Python/native suite unchanged; 546 tests passed at round11.',
                     'GPU algorithms unchanged; round11 GPU validation remains historical.']}

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for data in iter(lambda: f.read(1 << 20), b''): h.update(data)
    return {'bytes': Path(path).stat().st_size, 'sha256': h.hexdigest()}

def save(): (OUT / 'summary.json').write_text(json.dumps(REPORT, indent=2) + '\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS, (8 << 30, 8 << 30))
def stage(name, command, timeout=1200):
    print('START ' + name, flush=True)
    log = OUT / (name + '.log')
    metrics = OUT / (name + '.time')
    start = time.monotonic()
    with log.open('w') as stream:
        result = subprocess.run(['/usr/bin/time', '-v', '-o', str(metrics)] + command,
            env=ENV, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout, preexec_fn=cap)
    REPORT['stages'].append({'stage': name, 'command': command, 'exit_code': result.returncode,
        'elapsed_s': time.monotonic() - start, 'log': str(log), 'log_sha256': digest(log)['sha256'],
        'resource_log': str(metrics)})
    save()
    print('END ' + name + ' exit=' + str(result.returncode), flush=True)
    if result.returncode: raise RuntimeError('stage failed: ' + name)
    return log.read_text()

def counts(log):
    rows = re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', log)
    assert rows
    return dict(zip(('passed', 'failed', 'ignored'), [sum(int(r[i]) for r in rows) for i in range(3)]))

paths = subprocess.check_output(['git', 'ls-files', 'hashline', 'zkp-core'], text=True).splitlines()
paths = [p for p in paths if Path(p).suffix in ('.rs', '.cu', '.toml', '.lock', '.py')]
before = {p: digest(ROOT / p)['sha256'] for p in paths}
rc = 1
try:
    print('WAIT shared heavy lock', flush=True)
    with open('/tmp/zk-heavy.lock', 'a') as heavy:
        fcntl.flock(heavy, fcntl.LOCK_EX)
        print('ACQUIRED shared heavy lock', flush=True)
        assert subprocess.check_output(['git', 'diff', 'HEAD', '--', 'hashline', 'zkp-core']) == b''
        cargo = ['flock', '/tmp/zk-build.lock', 'cargo']
        log = stage('hashline_tests', cargo + ['test', '--release', '--locked', '--offline',
            '--manifest-path', 'hashline/Cargo.toml', '--', '--test-threads=2'])
        REPORT['hashline_tests_including_doctests'] = counts(log)
        log = stage('core_tests', cargo + ['test', '--release', '--locked', '--offline',
            '--manifest-path', 'zkp-core/Cargo.toml', '--all-targets', '--', '--test-threads=2'])
        REPORT['core_tests'] = counts(log)
        REPORT['rust_tests_total'] = {k: REPORT['hashline_tests_including_doctests'][k] + REPORT['core_tests'][k]
                                     for k in ('passed', 'failed', 'ignored')}
        assert REPORT['rust_tests_total']['failed'] == REPORT['rust_tests_total']['ignored'] == 0
        stage('binaries', cargo + ['build', '--release', '--locked', '--offline', '--manifest-path',
            'hashline/Cargo.toml', '--bin', 'hashline', '--example', 'zk60_block_receipt',
            '--example', 'zk60_chain_receipt'])
        binary = ROOT / 'hashline/target/release/hashline'
        REPORT['cpu_binary'] = {'path': str(binary), **digest(binary)}
        b4 = ROOT / 'hashline/target/release/examples/zk60_block_receipt'
        stage('b4_reprove', [str(b4), 'prove', str(ROOT / 'results/zk60_round4_expected.bin'), str(OUT / 'b4.proof')])
        REPORT['b4'] = digest(OUT / 'b4.proof')
        assert REPORT['b4'] == digest(ROOT / 'results/zk60_round4_receipt.proof')
        previous = json.loads((ROOT / 'results/zk60_round11_validation.json').read_text())
        cmd = next(s['command'] for s in previous['stages'] if s['stage'] == 'chain_verify')
        stage('chain_verify', cmd)
        manifest = json.loads((ROOT / 'results/zk60_round11_evidence/floors/manifest.json').read_text())
        REPORT['frozen_artifacts'] = []
        for case in manifest['cases']:
            if case['id'] not in ('cpu-v2', 'cpu-v3', 'cpu-zk', 'cpu-zkv3'): continue
            cmd = case['argv'][3:].copy()
            cmd[0] = str(binary)
            proof = OUT / (case['id'] + '.proof')
            cmd[cmd.index('--proof-out') + 1] = str(proof)
            log = stage(case['id'], cmd)
            timing = [json.loads(line.removeprefix('HASHLINE_TIMING ')) for line in log.splitlines()
                      if line.startswith('HASHLINE_TIMING ')]
            assert len(timing) == 1 and timing[0]['verified'] is True
            assert timing[0]['gpu_enabled'] is False and timing[0]['serialized'] is True
            actual = digest(proof)
            assert timing[0]['proof_bytes'] == actual['bytes']
            assert actual == case['proof'], (case['id'], actual)
            REPORT['frozen_artifacts'].append({'case': case['id'], **actual})
            save()
        assert len(REPORT['frozen_artifacts']) == 4
        assert {p: digest(ROOT / p)['sha256'] for p in paths} == before
        REPORT['source_sha256'] = before
        REPORT['validation_status'] = 'complete'
        rc = 0
except BaseException:
    REPORT['error'] = traceback.format_exc()
    print(REPORT['error'], flush=True)
finally:
    REPORT['exit_code'] = rc
    save()
    (OUT / 'validation.done').write_text(str(rc) + '\n')
raise SystemExit(rc)
