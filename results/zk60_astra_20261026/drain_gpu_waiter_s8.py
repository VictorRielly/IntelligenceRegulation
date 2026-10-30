"""Withdraw only Astra's identified, not-yet-started GPU guard for D44/S8."""
import json
import os
from pathlib import Path
import signal
import time
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
JOB = HERE / 'gpu_replay_jobs/benchmark-l00-2'
launch = json.loads(JOB.with_suffix('.launch.json').read_text())
assert launch['boot_id'] == Path('/proc/sys/kernel/random/boot_id').read_text().strip()
parent = launch['pid']
parent_path = Path('/proc') / str(parent)
result = {'at': datetime.now(timezone.utc).isoformat(), 'parent': parent, 'signals': []}
if not (JOB / 'worker.done').exists():
    argv = (parent_path / 'cmdline').read_bytes().split(b'\0')
    assert any(x.endswith(b'/run_gpu_replay.py') for x in argv)
    assert b'benchmark' in argv and b'--layer' in argv and b'--attempt' in argv
    children = (parent_path / f'task/{parent}/children').read_text().split()
    assert len(children) == 1, 'expected exactly the queued guard'
    guard = int(children[0]); proc = Path('/proc') / str(guard)
    cmd = (proc / 'cmdline').read_bytes().split(b'\0')
    assert any(x.endswith(b'/zk60_resource_guard.py') for x in cmd)
    assert b'astra-gpu-benchmark-l00' in cmd and str(JOB/'guard.json').encode() in cmd
    assert not (proc / f'task/{guard}/children').read_text().split(), 'guard has started a leaf; let it finish'
    assert 'START astra-gpu-' not in JOB.with_suffix('.launcher.log').read_text(), 'leaf already started'
    fd = os.pidfd_open(guard)
    try:
        signal.pidfd_send_signal(fd, signal.SIGTERM)
    finally:
        os.close(fd)
    result['signals'].append({'pid': guard, 'signal': 'SIGTERM', 'reason': 'coordinator S8 drain of waiting own guard'})
    for _ in range(100):
        if (JOB/'worker.done').exists(): break
        time.sleep(0.1)
assert (JOB/'worker.done').exists(), 'guard has not reached a terminal marker'
result['worker_exit'] = int((JOB/'worker.done').read_text())
result['guard'] = json.loads((JOB/'guard.json').read_text())
if result['signals']:
    assert result['guard']['child_rc'] is None, 'unexpected launched leaf'
else:
    assert result['guard']['child_rc'] in (0,3), 'running leaf did not finish successfully'
    assert not result['guard']['gpu_drain_failed'] and not result['guard']['gpu_telemetry_lost']
for _ in range(20):
    try:
        stat = (parent_path/'stat').read_text().split(') ',1)[1].split()
        if stat[0] == 'Z': break
    except FileNotFoundError: break
    time.sleep(0.1)
else: raise RuntimeError('launcher has not exited')
result['parent_terminal'] = True
(HERE/'s8_gpu_waiter_drain.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'worker_exit': result['worker_exit'], 'parent_terminal':True,
                  'child_started':result['guard']['child_rc'] is not None}))
