#!/usr/bin/env python3
"""Prepared S3 swap. Defaults to read-only checks; --apply requires lane holds.

Coordinator readiness: GUARD_SWAP_READY.json in this directory, with a
nonempty `hold_files` list (absolute existing lane HOLD paths), current
`boot_id`, and `sandbox_views_checked: true`. This records NOTES section 7's
cross-lane checks without writing into another lane. Keep holds through tests.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
STAGED = ROOT / 'results/zk60_guard_fix_20261021'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
OLD = 'f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772'
NEW = '87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c'
PINS = [(ROOT / 'scripts/zk60_guarded_command.py', 'REVIEWED_GUARD_SHA256'),
        (ROOT / 'scripts/zk60_techweek_demo.py', 'GUARD_PIN')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic(path, data):
    temp = path.with_name('.' + path.name + '.sol-swap.tmp')
    with temp.open('xb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    temp.chmod(0o644)
    os.replace(temp, path)


def rollback(tests):
    atomic(GUARD, (OUT / 'guard-backup/zk60_resource_guard.py').read_bytes())
    for path, pin in PINS:
        atomic(path, path.read_text().replace(f"{pin} = '{NEW}'", f"{pin} = '{OLD}'", 1).encode())
    if tests.exists():
        os.replace(tests, OUT / 'rolled_back_test_zk60_guard_fix.py')


def preflight():
    problems = []
    status = json.loads(subprocess.check_output([sys.executable, str(GUARD), 'status', '--json'], cwd=ROOT))
    if status['live_guarded_jobs']:
        problems.append('live guarded jobs: ' + ', '.join(j['label'] for j in status['live_guarded_jobs']))
    if not status['heavy_lock_free'] or not status['build_lock_free']:
        problems.append('heavy/build lock is held')
    if not status['kernel_memory_cap_available']:
        problems.append('run from the host: systemd user scope unavailable here')
    live = []
    consumers = {'zk60_private_stack_benchmark.py', 'zk60_guarded_command.py', 'zk60_techweek_demo.py'}
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal() or int(proc.name) == os.getpid():
            continue
        try:
            argv = (proc / 'cmdline').read_bytes().decode(errors='replace').split('\0')
            bases = {Path(a).name for a in argv if a}
            guard_run = 'run' in argv and any(b.startswith('zk60_resource_guard.py') for b in bases)
            if guard_run or bases & consumers:
                live.append({'pid': int(proc.name), 'argv': argv})
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
    if live:
        problems.append('guard waiter or consumer process exists')
    ready = OUT / 'GUARD_SWAP_READY.json'
    if not ready.exists():
        problems.append('coordinator lane HOLD/readiness record missing')
    else:
        data = json.loads(ready.read_text())
        holds = data.get('hold_files', [])
        if not holds or not all(Path(p).is_absolute() and Path(p).is_file() for p in holds):
            problems.append('lane HOLD files are absent')
        if data.get('boot_id') != Path('/proc/sys/kernel/random/boot_id').read_text().strip():
            problems.append('readiness is from a different boot')
        if data.get('sandbox_views_checked') is not True:
            problems.append('other sandbox process views not acknowledged')
    if sha(GUARD) != OLD:
        problems.append('live guard differs from the reviewed diff base')
    assert sha(STAGED / 'zk60_resource_guard.py.new') == NEW
    assert sha(STAGED / 'tests/test_zk60_guard_fix.py') == '7814c8f43f8ab5fc337fbe1ffa1c1740f8eb812ca58e93bd90a59747cff512c9'
    assert sha(OUT / 'guard-backup/zk60_resource_guard.py') == OLD
    for path, pin in PINS:
        assert f"{pin} = '{OLD}'" in path.read_text()
    assert not (Path('/tmp/zk-guard') / 'fifo.on').exists(), 'FIFO must remain OFF'
    assert os.environ.get('ZK60_GUARD_FIFO') != '1', 'FIFO must remain OFF in the launch environment'
    result = dict(written_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  problems=problems, live_processes=live, guard_status=status)
    (OUT / 'guard_swap_preflight.json').write_text(json.dumps(result, indent=2) + '\n')
    return problems


def main():
    problems = preflight()
    print(json.dumps({'preflight': 'BLOCKED' if problems else 'READY', 'problems': problems}), flush=True)
    if '--apply' not in sys.argv:
        return 0
    if problems:
        return 70
    tests = ROOT / 'tests/test_zk60_guard_fix.py'
    assert not tests.exists(), 'staged test already installed; inspect state before applying'
    atomic(GUARD, (STAGED / 'zk60_resource_guard.py.new').read_bytes())
    assert sha(GUARD) == NEW
    atomic(tests, (STAGED / 'tests/test_zk60_guard_fix.py').read_bytes())
    records = []
    for pattern in ('test_zk60_resource_guard.py', 'test_zk60_guard_fix.py'):
        log_path = OUT / f'installed_{pattern}.log'
        with log_path.open('w') as log:
            rc = subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover',
                                 '-s', str(ROOT / 'tests'), '-p', pattern, '-v'],
                                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
        text = log_path.read_text()
        expected = 45 if pattern == 'test_zk60_resource_guard.py' else 31
        complete = f'Ran {expected} tests' in text and 'skipped=' not in text
        records.append({'suite': pattern, 'exit': rc, 'all_cases_executed': complete})
        (OUT / 'guard_swap_tests.json').write_text(json.dumps(records, indent=2) + '\n')
        if rc or not complete:
            rollback(tests)
            print('Suite failed: base guard restored, pins unchanged, holds retained.', flush=True)
            return rc or 1
    for path, pin in PINS:
        data = path.read_text().replace(f"{pin} = '{OLD}'", f"{pin} = '{NEW}'", 1)
        atomic(path, data.encode())
    for pattern in ('test_zk60_guarded_command.py', 'test_zk60_techweek_demo.py',
                    'test_zk60_private_stack_benchmark.py'):
        with (OUT / f'installed_{pattern}.log').open('w') as log:
            rc = subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover',
                                 '-s', str(ROOT / 'tests'), '-p', pattern, '-v'],
                                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
        records.append({'suite': pattern, 'exit': rc})
        (OUT / 'guard_swap_tests.json').write_text(json.dumps(records, indent=2) + '\n')
        if rc:
            rollback(tests)
            print('Consumer suite failed: base guard and pins restored; holds retained.', flush=True)
            return rc
    protocol = ROOT / 'docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md'
    text = protocol.read_text().replace('`tests/test_zk60_resource_guard.py` (45 pass).',
        '`tests/test_zk60_resource_guard.py` (45 cases) and `tests/test_zk60_guard_fix.py` (31 cases).')
    text = text.replace('already queues on the lock, so enqueue follow-ups immediately.',
        'queues on admission before acquiring the heavy/build locks, then rechecks and registers under the locks. Failed rechecks release the locks before waiting again.')
    text += '\n\n## Guard admission update, 2026-10-26 (S3)\n\nThe reviewed guard is SHA-256 `' + NEW + '`. Waiting jobs hold no heavy/build lock until the advisory admission check passes. Admission is rechecked and registration remains atomic under the admission lock. Both static Codex pins name this release; the private-stack benchmark still pins dynamically per run. FIFO is OFF by default; `/tmp/zk-guard/fifo.on` or `ZK60_GUARD_FIFO=1` enables it and requires a separate announced decision. A reboot clears the file. Evidence and rollback backup: `results/zk60_sol_20261026/`. The older lane-rule pre-check requirement can remain in callers; it is conservative.\n'
    atomic(protocol, text.encode())
    note = '\n\n## Codex Sol S3 installed — ' + datetime.datetime.now(datetime.timezone.utc).isoformat() + '\n\nGuard atomically replaced with `' + NEW + '` after quiescent host/process/HOLD checks. Official 45-case suite and staged 31-case suite passed against the installed guard; both static pins updated. The benchmark has no static third pin. FIFO remains OFF. Durable rollback and validation: `results/zk60_sol_20261026/`. Coordinator may release lane HOLDs after reviewing this terminal record. Lane-rule gap (a) is fixed; FIFO gap (b) remains opt-in.\n'
    with (ROOT / 'ops/zkp-mvp/RECOVERY_COORDINATION.md').open('a') as stream:
        stream.write(note)
    (OUT / 'guard_swap.done').write_text('0\n')
    print('S3 installed; both static pins updated; FIFO OFF.', flush=True)
    return 0


if __name__ == '__main__':
    result = 1
    try:
        result = main()
    finally:
        if '--apply' in sys.argv:
            (OUT / 'guard_swap.done').write_text(f'{result}\n')
    sys.exit(result)
