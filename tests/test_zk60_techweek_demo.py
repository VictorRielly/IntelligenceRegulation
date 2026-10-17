import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import zk60_techweek_demo as demo


class TechweekDemoTests(unittest.TestCase):
    @unittest.skipUnless((demo.ROOT / 'zkvm-block/target/release/zk60-token-wrap').is_file()
                        and '--result-json' in demo.GUARD.read_text(),
                        'local verifier or released guard interface absent')
    def test_saved_real_receipt_and_controls(self):
        with tempfile.TemporaryDirectory() as parent:
            out = Path(parent) / 'run'
            result = demo.verify_saved_demo(out)
            self.assertEqual(result['status'], 'passed')
            self.assertEqual(result['receipt_bytes'], 785)
            self.assertFalse(result['new_proof_generated'])
            self.assertTrue(result['scope']['private_inputs'])
            self.assertEqual(json.loads((out / 'report.json').read_text()), result)
            self.assertEqual((out / 'run.done').read_text(), '0\n')

    def test_wrong_pin_fails_before_verifier_launch(self):
        with tempfile.TemporaryDirectory() as parent:
            with patch.object(demo, '_pin', side_effect=demo.zkvm.RunnerError('pin mismatch')), patch.object(demo, '_command') as command:
                result = demo.verify_saved_demo(Path(parent) / 'run')
            command.assert_not_called()
            self.assertEqual(result['status'], 'failed')

    def test_verifier_crash_is_not_rejection(self):
        responses = [(0, False, demo.SAVED['token'][2]),
                     (0, False, '{"verified":true,"kind":"groth16"}'),
                     (-11, False, 'crash')]
        with tempfile.TemporaryDirectory() as parent:
            with patch.object(demo, '_command', side_effect=responses), patch.object(demo, '_pin', return_value='test-pin'):
                result = demo.verify_saved_demo(Path(parent) / 'run')
            self.assertEqual(result['status'], 'failed')
            self.assertFalse(result['checks'][-1]['passed'])

    def test_existing_output_not_overwritten(self):
        with tempfile.TemporaryDirectory() as parent:
            with self.assertRaises(demo.zkvm.RunnerError):
                demo.verify_saved_demo(Path(parent))

    def test_interruption_retains_running_report_without_success_marker(self):
        with tempfile.TemporaryDirectory() as parent:
            out = Path(parent) / 'run'
            def interrupted(*_):
                raise KeyboardInterrupt()
            with self.assertRaises(KeyboardInterrupt):
                demo._demo(out, 'test', {}, interrupted)
            self.assertEqual(json.loads((out / 'report.json').read_text())['status'], 'running')
            self.assertFalse((out / 'run.done').exists())

    def test_empty_check_set_never_reports_success(self):
        with tempfile.TemporaryDirectory() as parent:
            out = Path(parent) / 'run'
            result = demo._demo(out, 'test', {}, lambda *_: None)
            self.assertEqual(result['status'], 'failed')
            self.assertEqual((out / 'run.done').read_text(), '1\n')

    def test_oversize_log_is_not_read_into_memory(self):
        with tempfile.TemporaryDirectory() as parent:
            log = Path(parent) / 'command.log'
            with log.open('wb') as output:
                output.truncate(demo.MAX_DIAGNOSTIC_BYTES + 1)
            log.with_suffix('.guard.json').write_text(json.dumps({'exit': 0, 'child_rc': 0, 'guard_killed': None}))
            with patch.object(demo, '_guarded_child', return_value=0):
                with self.assertRaisesRegex(demo.zkvm.RunnerError, 'read limit'):
                    demo._command(['unused'], log)

    def test_guard_refusal_never_launches_native_directly(self):
        with tempfile.TemporaryDirectory() as parent:
            log = Path(parent) / 'prove.log'
            def refused(command, log, env):
                self.assertEqual(command[1], str(demo.GUARD))
                self.assertIn('--max-secs', command)
                self.assertIn('--class', command)
                self.assertEqual(command[command.index('--class') + 1], 'cpu')
                log.write_text('guard refused admission')
                Path(command[command.index('--result-json') + 1]).write_text(json.dumps({'exit': 70}))
                return 70
            with patch.object(demo, '_guarded_child', side_effect=refused):
                code, expired, message = demo._command(['native', 'prove'], log, proof=True)
            self.assertEqual(code, 70)
            self.assertFalse(expired)
            self.assertIn('refused', message)

    def test_changed_guard_fails_before_launch(self):
        with tempfile.TemporaryDirectory() as parent:
            with patch.object(demo, '_pin', side_effect=demo.zkvm.RunnerError('guard pin mismatch')):
                with patch.object(demo, '_guarded_child') as child:
                    with self.assertRaisesRegex(demo.zkvm.RunnerError, 'guard pin mismatch'):
                        demo._command(['native', 'verify'], Path(parent) / 'verify.log')
            child.assert_not_called()

    def test_missing_or_inconsistent_guard_result_is_failure(self):
        with tempfile.TemporaryDirectory() as parent:
            log = Path(parent) / 'verify.log'
            with patch.object(demo, '_guarded_child', return_value=0):
                with self.assertRaisesRegex(demo.zkvm.RunnerError, 'terminal result'):
                    demo._command(['native', 'verify'], log)
                log.with_suffix('.guard.json').write_text(json.dumps({'exit': 1}))
                with self.assertRaisesRegex(demo.zkvm.RunnerError, 'disagrees'):
                    demo._command(['native', 'verify'], log)

    def test_guard_diagnostics_do_not_change_verifier_output(self):
        with tempfile.TemporaryDirectory() as parent:
            log = Path(parent) / 'image.log'
            def run(command, guard_log, env):
                guard_log.write_text('guard start\nguard end\n')
                Path(command[command.index('--log') + 1]).write_text('trusted-image-id\n')
                Path(command[command.index('--result-json') + 1]).write_text(json.dumps({'exit': 0, 'child_rc': 0}))
                return 0
            with patch.object(demo, '_guarded_child', side_effect=run):
                code, expired, output = demo._command(['native', 'image-id'], log)
            self.assertEqual((code, expired, output.strip()), (0, False, 'trusted-image-id'))

    def test_guard_error_cannot_become_a_native_rejection(self):
        with tempfile.TemporaryDirectory() as parent:
            log = Path(parent) / 'verify.log'
            log.write_text('REJECT: guard error is not a verifier result\n')
            log.with_suffix('.guard.json').write_text(json.dumps(
                {'exit': 1, 'child_rc': None, 'guard_error': 'launch failed'}))
            with patch.object(demo, '_guarded_child', return_value=1):
                with self.assertRaisesRegex(demo.zkvm.RunnerError, 'native child outcome'):
                    demo._command(['native', 'verify'], log)

    def test_exit_one_with_success_json_is_not_rejection(self):
        responses = [(0, False, demo.SAVED['token'][2]),
                     (0, False, '{"verified":true,"kind":"groth16"}'),
                     (1, False, 'zk60 token wrap: error\n{"verified":true}')]
        with tempfile.TemporaryDirectory() as parent:
            with patch.object(demo, '_command', side_effect=responses), patch.object(demo, '_pin', return_value='test-pin'):
                result = demo.verify_saved_demo(Path(parent) / 'run')
            self.assertEqual(result['status'], 'failed')
            self.assertFalse(result['checks'][-1]['passed'])


if __name__ == '__main__':
    unittest.main()
