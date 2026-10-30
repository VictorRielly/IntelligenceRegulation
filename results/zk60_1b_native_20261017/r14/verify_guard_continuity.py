"""Check the actual current guard without changing its source or policy."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
EXPECTED = '67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3'
OUT = HERE / 'guard-continuity-67e9478f'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert not OUT.exists()
assert sha(GUARD) == EXPECTED
OUT.mkdir()
tests = ['test_zk60_resource_guard.py', 'test_zk60_guard_fix.py', 'test_zk60_guard_s8.py']
pins = {name: sha(ROOT / 'tests' / name) for name in tests}
records = []
for name in tests:
    assert sha(GUARD) == EXPECTED and all(sha(ROOT / 'tests' / n) == v for n, v in pins.items())
    command = [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', name]
    with (OUT / (name + '.log')).open('x') as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    assert sha(GUARD) == EXPECTED and all(sha(ROOT / 'tests' / n) == v for n, v in pins.items())
    records.append({'test': name, 'exit': result.returncode, 'command': command,
                    'log_sha256': sha(OUT / (name + '.log'))})
    (OUT / 'progress.json').write_text(json.dumps(records, indent=2) + '\n')
    print(name, result.returncode, flush=True)
    assert result.returncode == 0
record = {'utc': datetime.now(timezone.utc).isoformat(), 'guard_sha256': EXPECTED,
          'validation_passed': True, 'test_pins': pins, 'tests': records,
          'scope': 'Independent diff read and three source-pinned existing guard suites. Disk-only additions; shared memory budget, heavy locks, caps and cleanup retained. Tests may skip systemd-dependent cases in the sandbox. No change to live guard, static consumer pins or disk floors. This is local runner compatibility evidence, not host/kernel validation or a new guard installation.'}
(HERE / 'GUARD_DISK_CONTINUITY.json').write_text(json.dumps(record, indent=2) + '\n')
(OUT / 'done').write_text('0\n')
