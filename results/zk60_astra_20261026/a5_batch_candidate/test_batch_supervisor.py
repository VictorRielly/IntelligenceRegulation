"""Real tiny subprocess lifecycle controls; no native or shared-guard work."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

import batch_supervisor as supervisor_module
from batch_supervisor import BatchSupervisor
from proven_media import config
from proven_media.provers import ProverError

FAKE = '''import json,os,signal,sys,time
from pathlib import Path
job,name,mode=sys.argv[1:]
job=Path(job);logs=job/'logs';rc=0
if mode=='missing':sys.exit(1)
if mode=='stop':
    stopped=[]
    signal.signal(signal.SIGTERM,lambda *args:stopped.append(True))
    (job/'ready').write_text('ready')
    while not stopped:time.sleep(.01)
    rc=75
if mode=='failed':rc=1
g={'exit':rc,'child_rc':rc,'guard_pid':os.getpid(),
   'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
   'guard_error':'straggler sweep failed' if mode=='uncertain' else None}
if mode=='wrongpid':g['guard_pid']+=1
(logs/(name+'.guard.json')).write_text(json.dumps(g))
(logs/(name+'.guard.done')).write_text(str(rc))
sys.exit(rc)
'''


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='astra-batch-supervisor-')
        self.addCleanup(self.tmp.cleanup)
        self.job = Path(self.tmp.name)
        self.fake = self.job/'fake_guard.py'; self.fake.write_text(FAKE)
        self.supervisor = BatchSupervisor(self.job, 'a'*32)
        p = patch.object(config, 'HOLD_FILE', self.job/'HOLD')
        p.start(); self.addCleanup(p.stop)

    def run_fake(self, mode='ok', on_terminal=None):
        def command(name, argv, *resources):
            return [sys.executable,str(self.fake),str(self.job),name,mode]
        with patch.object(self.supervisor, '_guard_argv', side_effect=command):
            return self.supervisor.run([('prove-batch',['unused'],.1,.2,5),('verify',['unused'],.1,.2,5)],
                                       on_terminal=on_terminal)

    def marker(self):
        return json.loads((self.job/'pipeline-terminal.json').read_text())

    def test_clean_children_allow_terminal_contract(self):
        self.assertEqual(self.run_fake(),0)
        self.assertTrue(self.marker()['children_reaped'])
        self.assertEqual(self.marker()['launch_id'],'a'*32)
        self.assertTrue((self.job/'logs/verify.guard.done').exists())

    def test_nonzero_clean_child_stops_sequence_but_allows_quarantine(self):
        self.assertEqual(self.run_fake('failed'),1)
        self.assertEqual(self.marker()['exit'],1)
        self.assertFalse((self.job/'logs/verify.guard.out').exists())

    def test_guard_exit_without_cleanup_evidence_never_declares_reaped(self):
        self.assertEqual(self.run_fake('missing'),1)
        self.assertFalse((self.job/'pipeline-terminal.json').exists())
        self.assertFalse(json.loads((self.job/'supervisor-error.json').read_text())['children_reaped'])

    def test_uncertain_cleanup_blocks_terminal_marker(self):
        self.assertEqual(self.run_fake('uncertain'),1)
        self.assertFalse((self.job/'pipeline-terminal.json').exists())

    def test_foreign_guard_identity_blocks_terminal_marker(self):
        self.assertEqual(self.run_fake('wrongpid'),1)
        self.assertFalse((self.job/'pipeline-terminal.json').exists())

    def test_competing_supervisor_cannot_mark_active_job_terminal(self):
        with (self.job/'batch-supervisor.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):self.run_fake()
        self.assertFalse((self.job/'pipeline-terminal.json').exists())

    def test_terminal_batch_cannot_restart(self):
        self.run_fake()
        with self.assertRaises(ProverError):self.run_fake()

    def test_hold_refuses_before_child_launch(self):
        (self.job/'HOLD').touch()
        self.assertEqual(self.run_fake(),1)
        self.assertEqual(self.marker()['exit'],1)
        self.assertFalse((self.job/'logs/prove-batch.guard.out').exists())

    def test_terminal_collector_runs_before_marker_on_known_failure(self):
        def terminal(code):
            self.assertEqual(code,1)
            self.assertFalse((self.job/'pipeline-terminal.json').exists())
        collect=Mock(side_effect=terminal)
        self.assertEqual(self.run_fake('failed',on_terminal=collect),1)
        collect.assert_called_once_with(1)
        self.assertEqual(self.marker()['exit'],1)

    def test_unknown_cleanup_never_calls_terminal_collector(self):
        collect=Mock()
        self.assertEqual(self.run_fake('missing',on_terminal=collect),1)
        collect.assert_not_called()
        self.assertFalse((self.job/'pipeline-terminal.json').exists())

    def test_terminal_collector_failure_cannot_report_success(self):
        collect=Mock(side_effect=OSError('TEST: quarantine filesystem failure'))
        self.assertEqual(self.run_fake(on_terminal=collect),1)
        collect.assert_called_once_with(0)
        self.assertEqual(self.marker()['exit'],1)
        self.assertTrue((self.job/'collector-error.json').exists())

    def test_process_metadata_failure_stops_own_guard_and_waits_for_cleanup(self):
        real=supervisor_module._atomic_private
        def write(path,value):
            if path.name=='prove-batch.guard-process.json':
                deadline=time.monotonic()+5
                while not (self.job/'ready').exists() and time.monotonic()<deadline:time.sleep(.01)
                self.assertTrue((self.job/'ready').exists())
                raise OSError('TEST: metadata write failed after Popen')
            return real(path,value)
        collect=Mock()
        with patch.object(supervisor_module,'_atomic_private',side_effect=write):
            self.assertEqual(self.run_fake('stop',on_terminal=collect),1)
        collect.assert_called_once_with(1)
        self.assertTrue(self.marker()['children_reaped'])
        self.assertEqual((self.job/'logs/prove-batch.guard.done').read_text(),'75')

    def test_sigterm_forwards_only_to_own_guard_and_waits_for_evidence(self):
        runner=self.job/'runner.py'
        runner.write_text('import sys\nfrom pathlib import Path\n'
            +'sys.path.insert(0,'+repr(str(Path(__file__).resolve().parent))+')\n'
            +'from batch_supervisor import BatchSupervisor\nfrom proven_media import config\n'
            +'job=Path('+repr(str(self.job))+')\nconfig.HOLD_FILE=job/"HOLD"\n'
            +'s=BatchSupervisor(job,"'+('a'*32)+'")\n'
            +'s._guard_argv=lambda name,*args:[sys.executable,str(job/"fake_guard.py"),str(job),name,"stop"]\n'
            +'raise SystemExit(s.run([("prove-batch",["unused"],.1,.2,5)]))\n')
        with (self.job/'runner.log').open('wb') as log:
            proc=subprocess.Popen([sys.executable,str(runner)],stdout=log,stderr=subprocess.STDOUT)
            try:
                deadline=time.monotonic()+5
                while not (self.job/'ready').exists() and proc.poll() is None and time.monotonic()<deadline:
                    time.sleep(.01)
                self.assertTrue((self.job/'ready').exists())
                proc.terminate()
                self.assertEqual(proc.wait(timeout=5),1)
            finally:
                if proc.poll() is None:
                    proc.terminate();proc.wait(timeout=5)
        self.assertEqual(self.marker()['exit'],1)
        self.assertTrue(self.marker()['children_reaped'])
        self.assertEqual((self.job/'logs/prove-batch.guard.done').read_text(),'75')


if __name__=='__main__':unittest.main()
