import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from scripts import zk60_guarded_command as guarded

ROOT = Path(__file__).resolve().parents[1]


class GuardedCommandTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.out = Path(self.tmp.name)
        self.fake = self.out / 'fake_guard.py'
        self.fake.write_text('''import json,sys
from pathlib import Path
a=sys.argv[1:]
def value(flag): return a[a.index(flag)+1]
mode=a[-1]
code=70 if mode=='refuse' else 0
record={'exit':code,'child_rc':None if code else 0,'guard_killed':None,
        'refused':'busy' if code else None,'class':value('--class')}
if mode=='wrong-record': record['exit']=1
if mode=='guard-error': record.update(child_rc=None,guard_error='launch failed')
if mode!='missing-record': Path(value('--result-json')).write_text(json.dumps(record))
Path(value('--log')).write_text('native log retained')
Path(value('--done')).write_text(str(code))
sys.exit(code)
''')
        for p in (patch.object(guarded, 'GUARD', self.fake),
                  patch.object(guarded, 'REVIEWED_GUARD_SHA256', guarded.sha(self.fake))):
            p.start()
            self.addCleanup(p.stop)

    def run_mode(self, mode):
        return guarded.run(['never-launched-native', mode], cwd=self.out,
                           env={}, output=self.out, label='test')

    def test_only_the_guard_is_launched_and_class_is_build(self):
        result = self.run_mode('success')
        self.assertEqual(result['guard_command'][1], str(self.fake))
        self.assertEqual(result['guard_result']['class'], 'build')
        self.assertEqual(result['exit_code'], 0)
        self.assertIsNotNone(result['log_sha256'])

    def test_refusal_is_returned_without_a_direct_native_fallback(self):
        result = self.run_mode('refuse')
        self.assertEqual(result['exit_code'], 70)
        self.assertIsNone(result['guard_result']['child_rc'])

    def test_missing_or_disagreeing_terminal_result_fails(self):
        with self.assertRaises(OSError):
            self.run_mode('missing-record')
        (self.out / 'test.guard.log').unlink()
        with self.assertRaisesRegex(ValueError, 'disagrees'):
            self.run_mode('wrong-record')

    def test_guard_error_never_reports_a_successful_build(self):
        with self.assertRaisesRegex(ValueError, 'successful native'):
            self.run_mode('guard-error')

    def test_changed_guard_fails_before_launch(self):
        with patch.object(guarded, 'REVIEWED_GUARD_SHA256', 'wrong'):
            with patch.object(guarded.subprocess, 'Popen') as launch:
                with self.assertRaisesRegex(RuntimeError, 'source changed'):
                    self.run_mode('success')
        launch.assert_not_called()

    def test_interrupt_requests_cleanup_and_waits_without_killing_guard(self):
        child = Mock()
        child.wait.side_effect = [guarded.GuardInterrupted('test interrupt'), 75]
        child.poll.return_value = None
        with patch.object(guarded.subprocess, 'Popen', return_value=child):
            with self.assertRaises(guarded.GuardInterrupted):
                self.run_mode('success')
        child.terminate.assert_called_once()
        child.kill.assert_not_called()
        self.assertEqual(child.wait.call_count, 2)


def load_launcher(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LegacyLauncherTests(unittest.TestCase):
    def test_native_refusal_retains_original_evidence_and_writes_terminal_attempt(self):
        launcher = load_launcher(ROOT / 'ops/zkp-mvp/build_native.py', 'legacy_native_build')
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            original = output / 'stack-cli.json'
            original.write_text('original interrupted report\n')
            step = {'exit_code': 70, 'guard_result': {'exit': 70, 'child_rc': None}}
            with patch.object(launcher, 'OUT', output), patch.object(sys, 'argv', ['build', 'stack-cli']):
                with patch.object(launcher.guarded, 'run', return_value=step) as run, patch('builtins.print'):
                    self.assertEqual(launcher.main(), 70)
            run.assert_called_once()
            self.assertEqual(original.read_text(), 'original interrupted report\n')
            attempt = next(p for p in output.iterdir() if p.is_dir())
            self.assertEqual((attempt / 'run.done').read_text(), '70\n')
            self.assertEqual(json.loads((attempt / 'report.json').read_text())['state'], 'failed')

    def test_hardening_stops_after_guard_refusal(self):
        launcher = load_launcher(ROOT / 'ops/zkp-mvp/sonnet-hardening/build_check.py', 'legacy_hardening_build')
        with tempfile.TemporaryDirectory() as tmp:
            step = {'exit_code': 70, 'guard_result': {'exit': 70, 'child_rc': None}}
            with patch.object(launcher, 'EVIDENCE', Path(tmp)):
                with patch.object(launcher.guarded, 'run', return_value=step) as run, patch('builtins.print'):
                    self.assertEqual(launcher.main(), 70)
            run.assert_called_once()
            attempt = next(Path(tmp).iterdir())
            self.assertEqual((attempt / 'run.done').read_text(), '70\n')
            self.assertEqual(json.loads((attempt / 'report.json').read_text())['state'], 'failed')


if __name__ == '__main__':
    unittest.main()
