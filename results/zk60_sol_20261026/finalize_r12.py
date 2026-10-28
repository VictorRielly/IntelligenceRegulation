#!/usr/bin/env python3
"""Audit every R12 acceptance gate and package evidence with Python 3.10.

The running acceptance worker uses hashlib.file_digest in its final packaging
step, which is unavailable on this host's Python 3.10. Do not edit that running
file. This finalizer runs only after its terminal marker, preserves its original
failure, and requires every proof/build/test gate plus an intact frozen copy.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
LEDGER = ROOT / 'results/zk60_1b_native_20261017'
R12 = LEDGER / 'r12'
NATIVE = ROOT / 'ops/zkp-mvp/trained-1b'
STAGES = ['r12-build', 'r12-check', 'r12-golden', 'r12-dense', 'r12-fresh-verify',
          'r12-cli-build', 'r12-gpu-cli-build', 'r12-compat-tl', 'r12-compat-8b',
          'r12-compat-tl-dd', 'r12-compat-8b-dd', 'r12-suite', 'r12-suite-kernel']


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def tree(root):
    files = {}
    for parent, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith('target'))
        for name in sorted(names):
            path = Path(parent) / name
            if not path.is_symlink():
                files[str(path.relative_to(root))] = sha(path)
    return hashlib.sha256(''.join(f'{k} {v}\n' for k, v in sorted(files.items())).encode()).hexdigest()


def main():
    assert (OUT / 'acceptance.done').exists(), 'acceptance worker is not terminal'
    rc = (OUT / 'acceptance.done').read_text().strip()
    if rc != '0':
        log = (OUT / 'acceptance.log').read_text()
        assert "module 'hashlib' has no attribute 'file_digest'" in log, 'failure is not solely the known packaging incompatibility'
    source = json.loads((OUT / 'acceptance_source.json').read_text())
    expected = source['tree_sha256']
    assert tree(NATIVE) == expected
    assert tree(R12 / 'frozen-tree') == expected
    assert json.loads((R12 / 'manifest_frozen.json').read_text())['tree_sha256'] == expected
    prior = json.loads((OUT / 'prior_frozen_before.json').read_text())
    for revision, before in prior.items():
        assert tree(LEDGER / revision / 'frozen-tree') == before['tree_sha256'], f'{revision} frozen tree moved'
    records = {}
    for label in STAGES:
        record = json.loads((OUT / f'{label}.guard.json').read_text())
        assert record['exit'] == 0 and record['child_rc'] == 0 and not record.get('guard_killed'), label
        assert record['child_wall_seconds'] > 0, label
        assert record['enforcement'] == 'cgroup+watchdog', label
        assert (OUT / f'{label}.done').read_text().strip() == '0', label
        command = json.loads((OUT / f'{label}.command.json').read_text())
        if any(Path(str(arg)).name == 'cargo' for arg in command):
            assert '--offline' in command and '--locked' in command and '-j2' in command, label
        records[label] = record
    for label in ['r12-check', 'r12-golden', 'r12-dense', 'r12-fresh-verify', 'r12-suite', 'r12-suite-kernel']:
        log = (OUT / f'{label}.log').read_text()
        counts = re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', log)
        assert counts and all(int(failed) == 0 for _, failed, _ in counts), label
        assert sum(int(passed) for passed, _, _ in counts) > 0, label
    golden = (OUT / 'r12-golden.log').read_text()
    assert len(re.findall(r'R12-GOLDEN-DIGEST \S+ [0-9a-f]{64}', golden)) == 4
    assert len(re.findall(r'R12-GOLDEN-IDENTITY \S+ [0-9a-f]{64}', golden)) == 5
    assert 'no recorded golden' not in golden
    verify = (OUT / 'r12-fresh-verify.log').read_text()
    for dd in ('false', 'true'):
        assert f'R12 fresh-process Shieldstral T128 DD={dd}:' in verify
    assert verify.count('bytes verified; modified segment rejected') == 2
    for suffix, blocks in [('tl', 22), ('8b', 32), ('tl-dd', 22), ('8b-dd', 32)]:
        label = 'r12-compat-' + suffix
        command = json.loads((OUT / f'{label}.command.json').read_text())
        wanted = command[command.index('--expect-statement') + 1]
        events = [json.loads(line) for line in (OUT / f'{label}.log').read_text().splitlines() if line.startswith('{')]
        verified = [event for event in events if event.get('event') == 'verified']
        assert len(verified) == 1 and verified[0]['statement_identity'] == wanted, label
        assert verified[0]['blocks'] == blocks and verified[0]['receipt_bytes'] > 0, label
    assert 'DD (D30) is registered only' in (OUT / 'dd-refusal.log').read_text()
    assert not (OUT / 'dd-refusal-probe').exists()
    patch = R12 / 'r12-vs-r9.patch'
    diff = subprocess.run(['diff', '-ruN', '-x', 'target', '-x', 'target-gpu', '-x', 'results',
                           str(LEDGER / 'r9/frozen-tree'), str(R12 / 'frozen-tree')], capture_output=True)
    assert diff.returncode == 1 and diff.stdout == patch.read_bytes(), 'review patch is incomplete'
    hashes = {}
    for path in sorted(OUT.rglob('*')):
        relative = path.relative_to(OUT)
        fixed = path.name in {'acceptance_source.json', 'prior_frozen_before.json', 'native_before.json',
                              'acceptance.log', 'acceptance.done', 'accept_r12.py', 'finalize_r12.py', 'dd-refusal.log'}
        if path.is_file() and (path.name.startswith('r12-') or relative.parts[0] == 'dense-receipts' or fixed):
            hashes[str(path.relative_to(OUT))] = sha(path)
    for path in [R12 / 'zk60_trained_block.release.bin', R12 / 'zk60_trained_block.gpu.release.bin', patch]:
        hashes[str(path.relative_to(ROOT))] = sha(path)
    for dd in (0, 32):
        path = OUT / f'dense-receipts/t128-dd{dd}/segment.bin'
        assert path.stat().st_size > 0
    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    (OUT / 'evidence.sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
    audit = dict(written_utc=now, source_tree_sha256=expected, stages=records,
                 original_acceptance_exit=int(rc), packaging_repaired=(rc != '0'),
                 prior_frozen_trees_unchanged=True, s1_complete=True,
                 security_acceptance='Not claimed; Claude routes D24 review and privacy gate.')
    (OUT / 'R12_AUDIT.json').write_text(json.dumps(audit, indent=2) + '\n')
    (OUT / 'R12_COMPLETE.done').write_text('0\n')
    message = f'{now}: S1 R12 acceptance audited and frozen: {expected}. All 13 guarded stages passed with kernel caps; four R9 seeded goldens/five identities, dense Shieldstral T128 DD/non-DD, fresh-process verify + tamper rejection, CPU/GPU CLI builds, four retained R8/R9 stack verifies and full suites. Python 3.10 packaging incompatibility repaired separately; original terminal evidence retained. See results/zk60_sol_20261026/R12_AUDIT.json and r12/manifest_frozen.json. Claude: ready for independent D24 review; no privacy/soundness acceptance claimed.'
    with (OUT / 'PROGRESS.md').open('a') as f:
        f.write('\n- ' + message + '\n')
    path = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
    text = path.read_text()
    anchor = '\n---\n\n## Astra'
    assert anchor in text
    path.write_text(text.replace(anchor, '\n- ' + message + '\n' + anchor, 1))
    print(message)


if __name__ == '__main__':
    main()
