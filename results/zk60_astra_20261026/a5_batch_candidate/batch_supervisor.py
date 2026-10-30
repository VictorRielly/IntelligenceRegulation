"""Staged guarded-child lifecycle; not a selectable application prover.

No batch command plan or factory is installed here. The caller must have
atomically registered its prepared batch, and must still collect/verify every
receipt. This module only establishes whether recovery may move output files.
"""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess

from batch_cleanup import _atomic_private
from batch_registry import boot_id
from proven_media import config
from proven_media.classifier_cli import require

GUARD_SHA256 = '67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3'


class BatchSupervisor:
    def __init__(self, job, launch_id):
        self.job = Path(job)
        self.launch_id = launch_id
        self.boot = boot_id()
        self.child = None
        self.stopping = False
        self.children_reaped = True

    def stop(self, _signum=None, _frame=None):
        self.stopping = True
        if self.child is not None and self.child.poll() is None:
            # Signal only this guard. Its contract drains its child tree and
            # publishes terminal evidence; never kill the guard or its group.
            self.child.terminate()

    def _guard_argv(self, name, command, need, cap, maximum):
        require(hashlib.sha256(config.GUARD.read_bytes()).hexdigest() == GUARD_SHA256,
                'guard source changed; lifecycle contract needs review')
        logs = self.job/'logs'
        return ['python3', str(config.GUARD), 'run', '--class', 'cpu',
                '--need-gib', str(need), '--cap-gib', str(cap),
                '--max-secs', str(maximum), '--wait-secs', str(config.GUARD_WAIT_SECS),
                '--label', 'pm-batch-'+name, '--log', str(logs/(name+'.log')),
                '--done', str(logs/(name+'.guard.done')),
                '--result-json', str(logs/(name+'.guard.json')), '--', *command]

    def step(self, name, command, need, cap, maximum):
        require(not self.stopping, 'batch supervisor stopped')
        require(not config.HOLD_FILE.exists(), 'coordinator hold blocks batch launch')
        require(type(name) is str and re.fullmatch(r'[a-z0-9-]{1,64}', name), 'invalid step name')
        require(all(type(v) in (int, float) and math.isfinite(v) and v > 0 for v in (need, cap, maximum))
                and need <= cap, 'invalid guarded resource declaration')
        logs = self.job/'logs'
        require(not any((logs/(name+s)).exists() for s in ('.guard.done','.guard.json','.guard.out')),
                'batch step already exists; no automatic retry')
        argv = self._guard_argv(name, command, need, cap, maximum)
        with (logs/(name+'.guard.out')).open('xb') as out:
            self.child = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=out,
                                          stderr=subprocess.STDOUT, close_fds=True)
            self.children_reaped = False
            if self.stopping:
                self.child.terminate()
            try:
                rc = self.child.wait()
            except BaseException:
                self.stop()
                self.child.wait()  # do not impose a shorter drain deadline than the guard
                raise
            child_pid = self.child.pid
            self.child = None
        # Process exit alone is insufficient: a killed guard can orphan a
        # native child. Missing or uncertain cleanup evidence leaves no safe
        # terminal marker; the queue must wait for reboot/operator recovery.
        done = int((logs/(name+'.guard.done')).read_text().strip())
        guard = json.loads((logs/(name+'.guard.json')).read_text())
        require(type(guard.get('exit')) is int and guard['exit'] == done == rc
                and guard.get('guard_pid') == child_pid and guard.get('boot_id') == self.boot
                and not guard.get('guard_error') and not guard.get('foreign_cgroups_refused')
                and not guard.get('gpu_drain_failed'), 'guard cleanup is unconfirmed')
        self.children_reaped = True
        require(rc == 0 and not self.stopping, 'guarded batch step failed or was stopped')
        return guard

    def run(self, steps):
        fd = os.open(self.job/'batch-supervisor.lock', os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'r+b') as lock:
            # A competing supervisor must not write a terminal marker while
            # the original supervisor's child is still running.
            fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
            return self._run_locked(steps)

    def _run_locked(self, steps):
        """Run explicit leaf declarations and retain a truthful terminal marker.

        `steps` must be constructed by the future pinned batch pipeline; each
        tuple is (name, argv, need_gib, cap_gib, max_seconds). This function
        makes no claim that a successful step accepted any proof.
        """
        require(not (self.job/'pipeline-terminal.json').exists(), 'batch is already terminal')
        (self.job/'logs').mkdir(mode=0o700, exist_ok=True)
        previous = {s:signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGINT)}
        for s in previous: signal.signal(s, self.stop)
        code = 1
        try:
            for step in steps:
                self.step(*step)
            require(not self.stopping, 'batch supervisor stopped')
            code = 0
        except Exception as exc:
            _atomic_private(self.job/'supervisor-error.json',
                            {'type':type(exc).__name__, 'message':str(exc),
                             'children_reaped':self.children_reaped})
        finally:
            for s, handler in previous.items(): signal.signal(s, handler)
            if self.children_reaped:
                _atomic_private(self.job/'pipeline-terminal.json',
                    {'schema':'pm-batch-terminal/1', 'launch_id':self.launch_id,
                     'boot_id':self.boot, 'children_reaped':True, 'exit':code})
        return code
