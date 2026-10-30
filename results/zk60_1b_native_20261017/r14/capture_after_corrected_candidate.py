"""Compile the unchanged observer source after corrected arithmetic acceptance.

The earlier build2 failure and its markers remain intact. This dependency
records the test-only fixture correction rather than manufacturing acceptance
for the old source. Capture build1 has never run.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / 'capture-working-tree'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
LABEL = 'sol-r14-capture-build-1'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    acceptance = HERE / 'corrected-candidate-2'
    assert (acceptance / 'done').read_text().strip() == '0'
    accepted = json.loads((acceptance / 'ACCEPTANCE.json').read_text())
    actual = json.loads((HERE / 'sol-r14-actual-build-4.source.json').read_text())
    previous = json.loads((HERE / 'sol-r14-actual-build-2.source.json').read_text())
    assert accepted['source'] == actual['tree_sha256']
    assert set(actual['files']) == set(previous['files'])
    assert [n for n in actual['files'] if actual['files'][n] != previous['files'][n]] == [
        'hashline/src/private_block/split_attack_tests.rs']
    pin = json.loads((HERE / (LABEL + '.source.json')).read_text())
    plan = json.loads((HERE / 'sol-r14-observer-pipeline-1.plan.json').read_text())
    guard_review = json.loads((HERE / 'GUARD_DISK_CONTINUITY.json').read_text())
    assert guard_review['validation_passed'] is True
    assert guard_review['guard_sha256'] == '67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3'

    def check():
        assert sha(GUARD) == guard_review['guard_sha256']
        for n, want in pin['files'].items():
            assert sha(TREE / n) == want, n
        for n, want in plan['scripts'].items():
            assert sha(HERE / n) == want, n

    check()
    command = [sys.executable, str(GUARD), 'run', '--class', 'build', '--label', LABEL,
               '--need-gib', '2.6', '--cap-gib', '5', '--wait-secs', '3600', '--max-secs', '1800',
               '--log', str(HERE / (LABEL + '.log')), '--done', str(HERE / (LABEL + '.done')),
               '--result-json', str(HERE / (LABEL + '.guard.json')), '--', '/usr/bin/env',
               'RAYON_NUM_THREADS=2', 'OPENBLAS_NUM_THREADS=1', '/home/victor/.cargo/bin/cargo',
               'test', '--release', '--offline', '--locked', '-j2', '--manifest-path',
               str(TREE / 'hashline/Cargo.toml'), '--lib', 'split_', '--', '--test-threads=1', '--nocapture']
    path = HERE / (LABEL + '.command.json')
    assert not path.exists(), 'inspect original capture build rather than duplicate it'
    path.write_text(json.dumps({'command': command, 'source': pin['tree_sha256'],
        'dependency': str(acceptance / 'ACCEPTANCE.json'), 'dependency_sha256': sha(acceptance / 'ACCEPTANCE.json'),
        'arithmetic_source': actual['tree_sha256'],
        'note': 'Observer source unchanged; arithmetic source changed only test fixture. Earlier failed build2 gate retained.'}, indent=2) + '\n')
    while (HERE / 'HOLD').exists() or (HERE.parent / 'HOLD').exists():
        check()
        time.sleep(10)
    result = subprocess.run(command, cwd=ROOT)
    check()
    if result.returncode:
        sys.exit(result.returncode)
    log = (HERE / (LABEL + '.log')).read_text()
    assert '18 passed; 0 failed; 20 ignored' in log
    assert log.count('R14_ACTUAL_SLOT {') == 126 and log.count('R14_SPLIT_CENSUS {') == 12
    (HERE / (LABEL + '.validated.done')).write_text('0\n')
    print('Observer compile/components PASS18/0; native capture not yet run', flush=True)


if __name__ == '__main__':
    main()
