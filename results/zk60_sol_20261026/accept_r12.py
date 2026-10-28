#!/usr/bin/env python3
"""Durable, serial R12 acceptance. Every heavy leaf uses the shared guard."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
NATIVE = ROOT / 'ops/zkp-mvp/trained-1b'
LEDGER = ROOT / 'results/zk60_1b_native_20261017'
R12 = LEDGER / 'r12'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
CARGO = '/home/victor/.cargo/bin/cargo'
MANIFEST = NATIVE / 'hashline/Cargo.toml'
CLI = R12 / 'zk60_trained_block.release.bin'
ENV = ['RAYON_NUM_THREADS=16', 'HL_PB_TIMING=1',
       f'ZK60_R12_EVIDENCE_DIR={OUT / "dense-receipts"}']


def utc():
    return datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def report(message):
    line = f'- {utc()}: {message}\n'
    print(line, end='', flush=True)
    with (OUT / 'PROGRESS.md').open('a') as f:
        f.write('\n' + line)
    path = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
    text = path.read_text()
    anchor = '\n---\n\n## Astra'
    if anchor not in text:
        raise RuntimeError('Sol log boundary missing')
    path.write_text(text.replace(anchor, '\n' + line + anchor, 1))


def manifest(root):
    files = {}
    for parent, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith('target'))
        for name in sorted(names):
            path = Path(parent) / name
            if not path.is_symlink():
                files[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    tree = hashlib.sha256(''.join(f'{k} {v}\n' for k, v in sorted(files.items())).encode()).hexdigest()
    return dict(written_utc=utc(), root=str(root), tree_sha256=tree, count=len(files), files=files)


def save(path, obj):
    path.write_text(json.dumps(obj, indent=2) + '\n')


def cargo(action, *args, manifest_path=MANIFEST):
    return [CARGO, action, '--release', '--offline', '--locked', '-j2',
            '--manifest-path', str(manifest_path), *args]


def run(label, kind, need, cap, seconds, command):
    report(f'S1 {label}: waiting for admission ({kind}, need {need} GiB, cap {cap} GiB).')
    deadline = time.monotonic() + 21600
    while True:
        if time.monotonic() >= deadline:
            raise RuntimeError(f'{label}: admission timeout before launch')
        held = any(p.exists() for p in [OUT / 'HOLD', R12 / 'HOLD'])
        check = subprocess.run([sys.executable, str(GUARD), 'check', '--class', kind,
                                '--need-gib', str(need)], cwd=ROOT, capture_output=True, text=True)
        with (OUT / 'admission.log').open('a') as f:
            f.write(f'{utc()} {label} hold={held}: {check.stdout.strip()} {check.stderr.strip()}\n')
        if not held and check.returncode == 0 and 'OK to start now' in check.stdout:
            break
        time.sleep(20)
    if manifest(NATIVE)['tree_sha256'] != SOURCE['tree_sha256']:
        raise RuntimeError(f'{label}: source changed during acceptance')
    report(f'S1 {label}: running through the resource guard; log results/zk60_sol_20261026/{label}.log.')
    cmd = [sys.executable, str(GUARD), 'run', '--class', kind, '--need-gib', str(need),
           '--cap-gib', str(cap), '--label', f'sol-{label}', '--wait-secs', '30',
           '--max-secs', str(seconds), '--log', str(OUT / f'{label}.log'),
           '--done', str(OUT / f'{label}.done'), '--result-json', str(OUT / f'{label}.guard.json'),
           '--', '/usr/bin/env', *ENV, *command]
    save(OUT / f'{label}.command.json', cmd)
    rc = subprocess.run(cmd, cwd=ROOT).returncode
    record = json.loads((OUT / f'{label}.guard.json').read_text())
    marker = (OUT / f'{label}.done').read_text().strip()
    if rc or record.get('exit') != 0 or record.get('child_rc') != 0 or marker != '0' or record.get('guard_killed'):
        raise RuntimeError(f'{label}: failed rc={rc}, record={record}')
    if manifest(NATIVE)['tree_sha256'] != SOURCE['tree_sha256']:
        raise RuntimeError(f'{label}: source changed during command')
    report(f'S1 {label}: PASS [MEASURED, n=1, shared box], child {record.get("child_wall_seconds")} s, '
           f'peak RSS {record.get("peak_rss_gib")} GiB, enforcement {record.get("enforcement")}.')


def main():
    global SOURCE
    SOURCE = manifest(NATIVE)
    save(OUT / 'acceptance_source.json', SOURCE)
    prior = {r: manifest(LEDGER / r / 'frozen-tree') for r in ('r8', 'r9')}
    save(OUT / 'prior_frozen_before.json', prior)
    report(f'S1 R12 acceptance started; source {SOURCE["tree_sha256"]}. S3 swap remains held while jobs run; S2 awaits final fidelity spec.')
    run('r12-build', 'build', 2.5, 5, 900, cargo('test', '--lib', '--no-run'))
    run('r12-check', 'cpu', 2, 5, 900, cargo('test', '--lib', '--', '--test-threads=4',
        'r12_tests', 'r9_tests', 'trained_stack_tests', 'trained_block_tests', 'r6_tests',
        'r8_tests', 's24_tests', 's25_tests', 's33_tests', 'pad::tests', 'trained_statement',
        'review_e_', 'cs_port_tests', 'parity', 'dense_tests', 'trained_calib_tests',
        'rung_tests', 'grow_tests', 'run_capture'))
    run('r12-golden', 'cpu', 8, 10.5, 1800,
        cargo('test', '--lib', '--', '--ignored', '--test-threads=1', '--nocapture', 'r12_golden'))
    run('r12-dense', 'cpu', 8.5, 11, 1800,
        cargo('test', '--lib', '--', '--ignored', '--test-threads=1', '--nocapture', 'f2_a_generic_dense_shieldstral'))
    run('r12-fresh-verify', 'cpu', 3, 6, 900,
        cargo('test', '--lib', '--', '--ignored', '--test-threads=1', '--nocapture', 'f2_saved_shieldstral'))
    run('r12-cli-build', 'build', 2.5, 5, 900, cargo('build', '--example', 'zk60_trained_block'))
    shutil.copy2(NATIVE / 'hashline/target/release/examples/zk60_trained_block', CLI)
    gpu = ['/usr/bin/env', 'CUDA_ROOT=/home/victor/cuda-root',
           'LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib',
           f'CARGO_TARGET_DIR={NATIVE / "hashline/target-gpu"}',
           *cargo('build', '--features', 'gpu-cuda', '--example', 'zk60_trained_block')]
    run('r12-gpu-cli-build', 'build', 3, 5, 900, gpu)
    shutil.copy2(NATIVE / 'hashline/target-gpu/release/examples/zk60_trained_block', R12 / 'zk60_trained_block.gpu.release.bin')
    cases = [
        ('tl', 'r8', 'tinyllama_dg_rot1_T128', 'caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165', 2.5, False),
        ('8b', 'r8', 'llama3_8b_pg_rot1_b7voc0_T128', '5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4', 3, False),
        ('tl-dd', 'r9', 'tinyllama_dg_rot1_T128', 'd57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b', 2.5, True),
        ('8b-dd', 'r9', 'llama3_8b_pg_rot1_b7voc0_T128', '4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520', 3, True),
    ]
    for name, revision, export, statement, need, dd in cases:
        base = LEDGER / revision
        artifact = base / f'stack-{export}-ho00-cpu{"-dd" if dd else ""}/run'
        run(f'r12-compat-{name}', 'cpu', need, 8, 900,
            [str(CLI), 'stack-verify', '--export', str(base / 'verifier-exports' / export),
             '--artifact', str(artifact), '--expect-statement', statement, *(['--dd'] if dd else [])])
    probe = OUT / 'dd-refusal-probe'
    assert not probe.exists()
    refusal = subprocess.run([str(CLI), 'stack-prove', '--export', str(ROOT / 'results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32'),
                              '--seq', 'ho00', '--out', str(probe), '--dd'], cwd=ROOT, capture_output=True, text=True)
    (OUT / 'dd-refusal.log').write_text(refusal.stdout + refusal.stderr)
    assert refusal.returncode == 1 and not probe.exists() and 'DD (D30) is registered only' in refusal.stderr + refusal.stdout
    run('r12-suite', 'cpu', 6, 8, 1800, cargo('test', '--no-fail-fast', '--', '--test-threads=4'))
    run('r12-suite-kernel', 'build', 0.7, 3, 300,
        cargo('test', manifest_path=NATIVE / 'private-block-kernel-shaped/Cargo.toml'))
    for revision in prior:
        assert manifest(LEDGER / revision / 'frozen-tree')['tree_sha256'] == prior[revision]['tree_sha256'], f'{revision} frozen tree changed'
    assert manifest(NATIVE)['tree_sha256'] == SOURCE['tree_sha256']
    frozen = R12 / 'frozen-tree'
    assert not frozen.exists(), 'never modify an existing frozen tree'
    shutil.copytree(NATIVE, frozen, ignore=lambda path, names: [n for n in names if n.startswith('target')])
    final = manifest(frozen)
    assert final['tree_sha256'] == SOURCE['tree_sha256']
    save(R12 / 'manifest_frozen.json', final)
    save(R12 / 'manifest_frozen_working.json', manifest(NATIVE))
    with (R12 / 'r12-vs-r9.patch').open('w') as f:
        diff = subprocess.run(['diff', '-ruN', '-x', 'target', '-x', 'target-gpu', '-x', 'results',
                               str(LEDGER / 'r9/frozen-tree'), str(frozen)], stdout=f)
    assert diff.returncode in (0, 1)
    (R12 / 'FROZEN.txt').write_text(f'{utc()}\nR12 tree {final["tree_sha256"]}\nAcceptance logs: results/zk60_sol_20261026/\nIndependent D24 review and privacy gate not claimed.\n')
    evidence = {}
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.name not in ('acceptance.log', 'PROGRESS.md', 'evidence.sha256.json'):
            with path.open('rb') as f:
                evidence[str(path.relative_to(OUT))] = hashlib.file_digest(f, 'sha256').hexdigest()
    for path in (CLI, R12 / 'zk60_trained_block.gpu.release.bin', R12 / 'r12-vs-r9.patch'):
        evidence[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    save(OUT / 'evidence.sha256.json', evidence)
    report(f'S1 R12 FROZEN: {final["tree_sha256"]}; acceptance complete, frozen tree + patch + manifest in r12/. Claude: route independent D24 review. No privacy/soundness acceptance claimed.')


if __name__ == '__main__':
    rc = 1
    try:
        main()
        rc = 0
    except Exception as exc:
        traceback.print_exc()
        report(f'S1 acceptance STOPPED: {exc}. Inspect acceptance.log and stage logs before resuming; guard/pins unchanged.')
    finally:
        (OUT / 'acceptance.done').write_text(f'{rc}\n')
    sys.exit(rc)
