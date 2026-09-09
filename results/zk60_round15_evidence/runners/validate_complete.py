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
OUT = Path('/tmp/zk60-round15/final-complete')
OUT.mkdir(parents=True, exist_ok=True)
os.chdir(ROOT)
HEAD = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
assert HEAD.startswith('612ff9c'), HEAD
ENV = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
ENV.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', ZK_THREADS='2',
           CARGO_NET_OFFLINE='true',
           M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'))
ENV.pop('CARGO_TARGET_DIR', None)
REPORT = {'schema_version': 1, 'source_commit': HEAD,
          'scope': 'Fable FA6-FA9/CL21 integration, CFS safeguards, int8 registration and live-source suite-v6 validation and corrected typed-core extraction',
          'threads': 2, 'address_space_limit_bytes': 8 << 30,
          'gpu_executed': False, 'gpu_scope': 'Bounded 189-case oracle and frozen FFN fixtures; no throughput qualification', 'stages': [],
          'limits': ['Local registration storage and access boundary only; no reviewed mask generator, authenticated approval or stable P3 prover/verifier.',
                     'Conditional privacy analyses are not an implemented repaired proof.',
                     'Typed FFN core/decoder integrated with 50f1ea5 corrections; standalone complete FFN prover/verifier remains open.']}

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for data in iter(lambda: f.read(1 << 20), b''): h.update(data)
    return {'bytes': Path(path).stat().st_size, 'sha256': h.hexdigest()}

def save(): (OUT / 'summary.json').write_text(json.dumps(REPORT, indent=2) + '\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS, (8 << 30, 8 << 30))
def stage(name, command, timeout=1200, cap_memory=True):
    print('START ' + name, flush=True)
    log = OUT / (name + '.log')
    metrics = OUT / (name + '.time')
    start = time.monotonic()
    with log.open('w') as stream:
        result = subprocess.run(['/usr/bin/time', '-v', '-o', str(metrics)] + command,
            env=ENV, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout, preexec_fn=cap if cap_memory else None)
    REPORT['stages'].append({'stage': name, 'command': command, 'exit_code': result.returncode,
        'elapsed_s': time.monotonic() - start, 'log': str(log), 'log_sha256': digest(log)['sha256'],
        'resource_log': str(metrics), 'address_space_cap_applied': cap_memory})
    save()
    print('END ' + name + ' exit=' + str(result.returncode), flush=True)
    if result.returncode: raise RuntimeError('stage failed: ' + name)
    return log.read_text()

def counts(log):
    rows = re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', log)
    assert rows
    return dict(zip(('passed', 'failed', 'ignored'), [sum(int(r[i]) for r in rows) for i in range(3)]))

paths = subprocess.check_output(['git', 'ls-files', 'hashline', 'zkp-core', 'scripts', 'tests', 'results/cl1_floors.sh'], text=True).splitlines()
paths = [p for p in paths if Path(p).suffix in ('.rs', '.cu', '.toml', '.lock', '.py', '.sh')]
before = {p: digest(ROOT / p)['sha256'] for p in paths}
rc = 1
try:
    print('WAIT shared heavy lock', flush=True)
    with open('/tmp/zk-heavy.lock', 'a') as heavy:
        fcntl.flock(heavy, fcntl.LOCK_EX)
        print('ACQUIRED shared heavy lock', flush=True)
        assert subprocess.check_output(['git', 'diff', 'HEAD', '--', 'hashline', 'zkp-core']) == b''
        cargo = ['flock', '/tmp/zk-build.lock', 'cargo']
        previous = json.loads(Path('/tmp/zk60-round15/complete/summary.json').read_text())
        assert previous['exit_code'] == 1 and previous['stages'][-1]['stage'] == 'python_full'
        prior_log = Path('/tmp/zk60-round15/complete/python_full.log').read_text()
        failures = re.findall(r'^FAIL: ([^\n]+)', prior_log, re.M)
        assert failures == ['test_usage_and_success_line_name_the_core (test_hashline_cl_gpu_gates.FloorsRunner)'], failures
        assert not re.findall(r'^ERROR:', prior_log, re.M)
        assert 'FAILED (failures=1)' in prior_log
        REPORT['prior_python_full'] = {'source_commit': previous['source_commit'],
            'tests_run': int(re.search(r'Ran (\d+) tests?', prior_log).group(1)), 'failures': failures,
            'log': '/tmp/zk60-round15/complete/python_full.log', 'sha256': digest('/tmp/zk60-round15/complete/python_full.log')['sha256'],
            'note': 'One stale help-text assertion; rerun all affected hashline/zk60 tooling below. Remaining native/Python sources unchanged. Core integration landed while the first run finished unchanged native tests; no final-source full-suite claim.'}
        unchanged = subprocess.check_output(['git', 'diff', '22c9b35', HEAD, '--', 'zkmatrix-rs', 'zkmatrix', 'tests/test_zkmatrix_native_backends.py'])
        assert unchanged == b''
        stage('python_tooling', ['python3', '/tmp/zk60-round15/run_tooling.py', str(OUT/'tooling_result.json')], timeout=1200)
        REPORT['python_tooling'] = json.loads((OUT/'tooling_result.json').read_text())
        probe = '/tmp/zk60-round15/core_review/probe/Cargo.toml'
        stage('decoder_probe_lock', cargo + ['generate-lockfile', '--offline', '--manifest-path', probe])
        expected = {'CONTROL_NORMAL_ROUNDTRIP':'true', 'Q_MAX_PARAM_CHECK_ACCEPT':'false', 'Q_MAX_DECODE_PANIC':'false',
            'SHIFT64_EMPTY_DECODE_PANIC':'false', 'LOG0_PARAM_CHECK_ACCEPT':'true', 'LOG0_LEGACY_VERIFY':'true',
            'LOG0_ACTUAL_GROUPS':'1,1,2', 'LOG0_DECODER_GROUPS':'1,1,2', 'LOG0_CORE_DECODE':'true'}
        REPORT['decoder_probes'] = {}
        for mode in ('debug', 'release'):
            log = stage('decoder_probe_' + mode, ['env', 'CARGO_TARGET_DIR='+str(ROOT/'hashline/target')] + cargo +
                ['run', '--locked', '--offline', '--manifest-path', probe] + (['--release'] if mode=='release' else []))
            got = dict(re.findall(r'^([A-Z0-9_]+)=(.*)$', log, re.M))
            assert got == expected, got
            REPORT['decoder_probes'][mode] = got
        log = stage('core_debug_tests', cargo + ['test', '--locked', '--offline', '--manifest-path', 'zkp-core/Cargo.toml', '--', '--test-threads=2'])
        assert counts(log) == {'passed':32,'failed':0,'ignored':0}
        REPORT['optional_dependency_checks'] = {}
        for label, manifest in [('hashline_default', 'hashline/Cargo.toml'), ('core', 'zkp-core/Cargo.toml')]:
            tree = stage(label + '_dependencies', cargo + ['tree', '--locked', '--offline',
                '--manifest-path', manifest, '--prefix', 'none', '--format', '{p}'])
            names = {line.split()[0] for line in tree.splitlines() if line.strip()}
            forbidden = names.intersection({'chacha20poly1305', 'chacha20', 'poly1305', 'zeroize', 'cudarc'})
            assert not forbidden, (label, forbidden)
            REPORT['optional_dependency_checks'][label] = {'forbidden_dependencies': sorted(forbidden)}
        stage('gpu_storage_feature_check', ['env', 'CUDA_ROOT=/home/victor/cuda-root',
            'LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib',
            'CARGO_TARGET_DIR=hashline/target-gpu'] + cargo + ['check', '--release', '--locked', '--offline',
            '--manifest-path', 'hashline/Cargo.toml', '--features', 'gpu-cuda,stable-weight-storage', '--lib'])
        # No outer build lock: cl1_floors.sh acquires it internally. CUDA needs
        # a large virtual address space, so this bounded fixture stage has no AS cap.
        stage('combined_floors', ['bash', 'results/cl1_floors.sh', '--repo', str(ROOT),
            '--threads', '2', '--build-jobs', '2', '--rayon-threads', '2', '--suite-version', '6',
            str(OUT / 'floors')], timeout=3600, cap_memory=False)
        import sys
        sys.path.insert(0, str(ROOT / 'scripts'))
        from hashline_cl_gpu_gates import validate_manifest, probe_source_identity
        manifest = json.loads((OUT / 'floors/manifest.json').read_text())
        verdict = validate_manifest(manifest, expect_head=HEAD, require_production=True, expect_source=probe_source_identity(str(ROOT)))
        assert verdict['ok'], verdict
        assert verdict['summary']['cases_recorded'] == verdict['summary']['cases_expected'] == 24
        assert verdict['summary']['oracle_executed_cases'] == 189
        REPORT['combined_manifest'] = {'path': str(OUT / 'floors/manifest.json'), **digest(OUT / 'floors/manifest.json'), 'verdict': verdict}
        REPORT['gpu_executed'] = True
        REPORT['hashline_tests_including_doctests'] = counts((OUT / 'floors/storage_tests.out').read_text())
        REPORT['core_tests'] = counts((OUT / 'floors/core_tests.out').read_text())
        REPORT['rust_tests_total'] = {k: REPORT['hashline_tests_including_doctests'][k] + REPORT['core_tests'][k]
                                     for k in ('passed', 'failed', 'ignored')}
        assert REPORT['rust_tests_total'] == {'passed': 247, 'failed': 0, 'ignored': 0}

        REPORT['default_hashline_tests'] = counts((OUT / 'floors/cargo_test_cpu.out').read_text())
        REPORT['frozen_artifacts'] = [{'case': c['id'], **c['proof']} for c in manifest['cases'] if c['kind'] == 'byte_gate']
        assert len(REPORT['frozen_artifacts']) == 12
        save()
        stage('binaries', cargo + ['build', '--release', '--locked', '--offline', '--manifest-path',
            'hashline/Cargo.toml', '--example', 'zk60_block_receipt', '--example', 'zk60_chain_receipt'])
        binary = ROOT / 'hashline/target/release/hashline'
        REPORT['cpu_binary'] = {'path': str(binary), **digest(binary)}
        b4 = ROOT / 'hashline/target/release/examples/zk60_block_receipt'
        stage('b4_reprove', [str(b4), 'prove', str(ROOT / 'results/zk60_round4_expected.bin'), str(OUT / 'b4.proof')])
        REPORT['b4'] = digest(OUT / 'b4.proof')
        assert REPORT['b4'] == digest(ROOT / 'results/zk60_round4_receipt.proof')
        previous = json.loads((ROOT / 'results/zk60_round11_validation.json').read_text())
        cmd = next(s['command'] for s in previous['stages'] if s['stage'] == 'chain_verify')
        stage('chain_verify', cmd)
        for name in ['graph_a', 'graph_b']:
            stage(name, ['python3', 'zkp-core/tools/dep_closure.py', '--out', str(OUT / (name + '.json')), '--md', ''])
        assert (OUT / 'graph_a.json').read_bytes() == (OUT / 'graph_b.json').read_bytes()
        REPORT['dependency_graph_repeatable'] = True
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
