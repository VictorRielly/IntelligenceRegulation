"""Withdraw only the original app's waiting guard, refusing any started leaf."""
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import signal
import time

HERE = Path(__file__).resolve().parent
JOB = Path('/tmp/zk60-astra-real-app-demo-20261029-1/jobs/d1800de17fffed4565733d12e5c30f52/prove')
assert not (JOB/'pipeline.done').exists(), 'already terminal; inspect instead'
assert (JOB/'pipeline.boot_id').read_text().strip() == Path('/proc/sys/kernel/random/boot_id').read_text().strip()
spec = json.loads((JOB/'classifier-job.json').read_text())
assert spec['mode'] == 'prove' and spec['category'] == 'sexual'


def unstarted():
    assert not Path(spec['artifact']).exists(), 'public proof already exists'
    assert not Path(spec['sequence_dir']).parent.exists(), 'activation generation started'
    assert not Path(spec['owner_dir']).exists(), 'native proof started'
    for name in ('seqgen', 'prove', 'verify', 'inowner', 'label'):
        p = JOB/'logs'/f'{name}.log'
        assert not p.exists() or p.stat().st_size == 0, f'{name} already ran'
    assert 'START ' not in (JOB/'logs/seqgen.guard.out').read_text(), 'guard admitted a leaf'


pipelines = []
for proc in Path('/proc').iterdir():
    if not proc.name.isdigit():
        continue
    try:
        argv = (proc/'cmdline').read_bytes().split(b'\0')
        if any(a.endswith(b'/classifier_pipeline.py') for a in argv) and str(JOB).encode() in argv:
            pipelines.append(proc)
    except (FileNotFoundError, PermissionError, ProcessLookupError):
        pass
assert len(pipelines) == 1, 'expected exactly the owned pipeline in host namespace'
pipeline = pipelines[0]
with Path('/tmp/zk-guard/admit.lock').open('a+') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    unstarted()
    children = (pipeline/f'task/{pipeline.name}/children').read_text().split()
    assert len(children) == 1, 'expected only the queued guard'
    pid = int(children[0]); proc = Path('/proc')/str(pid)
    argv = (proc/'cmdline').read_bytes().split(b'\0')
    assert any(a.endswith(b'/zk60_resource_guard.py') for a in argv)
    assert b'pm-classify-seqgen' in argv and str(JOB/'logs/seqgen.guard.json').encode() in argv
    assert not (proc/f'task/{pid}/children').read_text().split(), 'guard has a leaf; let it finish'
    fd = os.pidfd_open(pid)
    try:
        signal.pidfd_send_signal(fd, signal.SIGTERM)
    finally:
        os.close(fd)

deadline = time.monotonic()+20
while not (JOB/'pipeline.done').exists() and time.monotonic()<deadline:
    time.sleep(0.1)
assert (JOB/'pipeline.done').read_text().strip() == '1'
guard = json.loads((JOB/'logs/seqgen.guard.json').read_text())
assert guard['exit'] == 70 and guard['child_rc'] is None, 'unexpected leaf execution'
unstarted()
result = {'at': datetime.now(timezone.utc).isoformat(), 'pipeline_host_pid': int(pipeline.name),
          'guard_host_pid': pid, 'signal': 'SIGTERM', 'pipeline_exit': 1, 'guard': guard,
          'computation_started': False, 'reason': 'apply tested metadata fixes while shared heavy machine is occupied',
          'retry_scope': 'same reserved post, original policies and threshold; no proof work has run'}
(HERE/'real_app_demo_1/unstarted_waiter_withdrawal.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({'pipeline_exit': 1, 'guard_exit': 70, 'computation_started': False}))
