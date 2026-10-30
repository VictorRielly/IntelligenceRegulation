"""Isolated swap-driver checks: no real guard, job, scope or pin is changed."""
from pathlib import Path
import datetime as dt
import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from unittest import mock

SOURCE=Path(__file__).resolve().parent/'swap_guard_s8.candidate.py'

class Driver(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('isolated_s8_driver',SOURCE)
        self.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.m)
        self.tmp=tempfile.TemporaryDirectory(prefix='sol-s8-driver-');self.addCleanup(self.tmp.cleanup)
        root=Path(self.tmp.name);out=root/'results/sol';evidence=out/'s8';backup=out/'backup'
        for path in (root/'scripts',root/'tests',evidence,backup,root/'docs',root/'ops',root/'proc',root/'guardstate'):
            path.mkdir(parents=True,exist_ok=True)
        self.root=root
        self.m.ROOT=root;self.m.OUT=out;self.m.EVIDENCE=evidence;self.m.BACKUP=backup
        self.m.GUARD=root/'scripts/zk60_resource_guard.py';self.m.GUARD.write_bytes(b'old guard\n')
        self.m.CANDIDATE=evidence/'candidate';self.m.CANDIDATE.write_bytes(b'new guard\n')
        self.m.OLD=self.m.sha(self.m.GUARD);self.m.NEW=self.m.sha(self.m.CANDIDATE)
        self.m.PINS=[(root/'scripts/zk60_guarded_command.py','REVIEWED_GUARD_SHA256'),(root/'scripts/zk60_techweek_demo.py','GUARD_PIN')]
        for path,pin in self.m.PINS:path.write_text(f"{pin} = '{self.m.OLD}'\n")
        self.m.PROTOCOL=root/'docs/protocol';self.m.PROTOCOL.write_bytes(b'old protocol\n')
        self.m.RECOVERY=root/'ops/recovery';self.m.RECOVERY.write_bytes(b'old recovery\n')
        self.m.FIXTURE=root/'tests/fixture';self.m.FIXTURE.write_bytes(b'prepared fixture\n')
        self.m.POLICY=root/'tests/policy';self.m.POLICY.write_bytes(b'new policy tests\n')
        (root/'proc/boot').write_text('test-boot\n')
        hold=root/'HOLD';hold.write_text('hold\n')
        self.ready={'change':'S8','ruling':'D44','window':'OPEN','candidate_sha256':self.m.NEW,'boot_id':'test-boot',
            'sandbox_views_checked':True,'hold_files':[str(hold)],'written_utc':self.m.utc()}
        self.write_ready()
        manifest={'old':self.m.OLD,'new':self.m.NEW,'files':{},
            'independent_old_copy':{'path':str(root/'second-old')},'official_fixture_sha256':self.m.sha(self.m.FIXTURE),
            'official_policy_sha256':self.m.sha(self.m.POLICY)}
        (root/'second-old').write_bytes(self.m.GUARD.read_bytes())
        for name,data in [('zk60_resource_guard.py.orig',b'old guard\n'),
            ('zk60_guarded_command.py',self.m.PINS[0][0].read_bytes()),('zk60_techweek_demo.py',self.m.PINS[1][0].read_bytes()),
            ('test_zk60_resource_guard.py',b'original fixture\n')]:
            (backup/name).write_bytes(data);manifest['files'][name]={'sha256':self.m.sha(backup/name)}
        (backup/'manifest.json').write_text(json.dumps(manifest))
        (evidence/'protocol_note.draft.md').write_text('All required suites must all pass on the host without systemd skips before completion.\n')
        self.status={'live_guarded_jobs':[],'heavy_lock_free':True,'build_lock_free':True,'kernel_memory_cap_available':True}
        self.patches=[mock.patch.dict(os.environ,{},clear=True),mock.patch.object(self.m,'processes',return_value=([],[])),
            mock.patch.object(self.m.subprocess,'check_output',side_effect=lambda *a,**kw:json.dumps(self.status).encode()),
            mock.patch.object(self.m,'Path',side_effect=self.path)]
        for patch in self.patches:patch.start();self.addCleanup(patch.stop)

    def path(self,p):
        if str(p)=='/proc/sys/kernel/random/boot_id':return self.root/'proc/boot'
        if str(p)=='/tmp/zk-guard':return self.root/'guardstate'
        return Path(p)

    def write_ready(self):(self.m.OUT/'GUARD_SWAP_READY.json').write_text(json.dumps(self.ready))
    def assert_old(self):
        self.assertEqual(self.m.GUARD.read_bytes(),b'old guard\n')
        for path,pin in self.m.PINS:self.assertIn(f"{pin} = '{self.m.OLD}'",path.read_text())

    def test_fresh_window_and_exact_payloads_pass_preflight(self):
        self.assertEqual(self.m.preflight()['problems'],[])

    def test_old_closed_wrong_candidate_or_stale_window_is_refused(self):
        for key,value in [('change','S3'),('ruling','D42'),('window','CLOSED'),('candidate_sha256','wrong'),
            ('boot_id','older-boot'),('written_utc',(dt.datetime.now(dt.timezone.utc)-dt.timedelta(hours=1)).isoformat())]:
            saved=self.ready[key];self.ready[key]=value;self.write_ready()
            self.assertTrue(self.m.preflight()['problems'],key)
            self.ready[key]=saved
        self.write_ready()

    def test_live_jobs_host_scope_and_environment_overrides_fail_closed(self):
        self.status['live_guarded_jobs']=[{'label':'other-lane'}];self.status['heavy_lock_free']=False
        self.status['kernel_memory_cap_available']=False
        problems=self.m.preflight()['problems']
        self.assertTrue(any('other-lane' in p for p in problems));self.assertTrue(any('lock held' in p for p in problems))
        self.assertTrue(any('host required' in p for p in problems))
        with mock.patch.dict(os.environ,{'ZK60_GUARD_DIR':'/private-test'}):
            self.assertTrue(any('environment overrides' in p for p in self.m.preflight()['problems']))

    def test_blocked_apply_changes_no_guard_or_pin(self):
        self.ready['window']='CLOSED';self.write_ready()
        self.assertEqual(self.m.apply(),70);self.assert_old()

    def test_primary_suite_failure_restores_original_guard_pins_and_fixture(self):
        with mock.patch.object(self.m,'suite',side_effect=RuntimeError('deliberate primary failure')):
            self.assertEqual(self.m.apply(),1)
        self.assert_old();self.assertEqual(self.m.FIXTURE.read_bytes(),b'original fixture\n')
        self.assertFalse(self.m.POLICY.exists());self.assertTrue((self.m.EVIDENCE/'rolled_back_test_zk60_guard_s8.py').exists())
        self.assertEqual(self.m.PROTOCOL.read_bytes(),b'old protocol\n')
        self.assertEqual(json.loads((self.m.EVIDENCE/'S8_INSTALL.json').read_text())['rollback'],'complete')

    def test_failure_after_atomic_guard_rename_still_restores_the_base(self):
        original=self.m.atomic;raised=False
        def fail_after_rename(path,data):
            nonlocal raised
            original(path,data)
            if path==self.m.GUARD and not raised:
                raised=True
                raise OSError('deliberate directory fsync failure after rename')
        with mock.patch.object(self.m,'atomic',side_effect=fail_after_rename):
            self.assertEqual(self.m.apply(),1)
        self.assert_old()
        self.assertEqual(json.loads((self.m.EVIDENCE/'S8_INSTALL.json').read_text())['rollback'],'complete')

    def test_consumer_failure_after_pin_update_restores_both_pins(self):
        def run(pattern,expected=None):
            if expected is None:
                for path,pin in self.m.PINS:self.assertIn(f"{pin} = '{self.m.NEW}'",path.read_text())
                raise RuntimeError('deliberate consumer failure')
            return {'accepted':True,'tests':expected,'skipped':[]}
        with mock.patch.object(self.m,'suite',side_effect=run):self.assertEqual(self.m.apply(),1)
        self.assert_old();self.assertEqual(self.m.PROTOCOL.read_bytes(),b'old protocol\n')

    def test_success_updates_exact_guard_pins_docs_and_terminal_audit(self):
        with mock.patch.object(self.m,'suite',side_effect=lambda p,n=None:{'accepted':True,'tests':n or 1,'skipped':[]}):
            self.assertEqual(self.m.apply(),0)
        self.assertEqual(self.m.GUARD.read_bytes(),b'new guard\n')
        for path,pin in self.m.PINS:self.assertIn(f"{pin} = '{self.m.NEW}'",path.read_text())
        self.assertTrue(self.m.POLICY.exists());self.assertIn('passed on the host',self.m.PROTOCOL.read_text())
        audit=json.loads((self.m.EVIDENCE/'S8_INSTALL.json').read_text());self.assertEqual(audit['stage'],'complete')
        self.assertEqual(len(audit['tests']),6);self.assertEqual((self.m.EVIDENCE/'S8_INSTALL.done').read_text(),'0\n')

if __name__=='__main__':unittest.main(verbosity=2)
