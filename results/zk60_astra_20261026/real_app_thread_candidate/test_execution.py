"""Mocked scheduling controls only; no subprocess, model or native proof runs."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'apps/proven-media'))
from proven_media import shieldstral_runtime as runtime
from proven_media.provers import ProverError
spec = importlib.util.spec_from_file_location('candidate_pipeline', HERE/'classifier_pipeline.py')
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


class ExecutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.job = Path(self.temp.name)
        (self.job/'logs').mkdir()
        self.cli = SimpleNamespace(deployment=SimpleNamespace(development=False, validate=lambda: None))
        holds = patch.object(pipeline, 'HOLDS', ())
        holds.start()
        self.addCleanup(holds.stop)

    def test_default_two_threads_have_27_minute_margin(self):
        with patch.dict(os.environ, {}, clear=True):
            value = pipeline.freeze_execution(self.job)
        self.assertEqual(value['native_threads'], 2)
        self.assertGreaterEqual(value['max_seconds']['prove'], 27*60)

    def test_eight_threads_and_caps_are_recorded_per_job(self):
        with patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': '8'}):
            value = pipeline.freeze_execution(self.job)
        self.assertEqual(json.loads((self.job/'execution.json').read_text()), value)
        self.assertEqual(value['native_threads'], 8)
        self.assertGreaterEqual(value['max_seconds']['prove'], 1.5*456)

    def test_invalid_or_changed_settings_refused(self):
        for value in ('0', '1', '16', '-2', 'eight'):
            with self.subTest(value=value), patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': value}):
                with self.assertRaises(ProverError): pipeline.freeze_execution(self.job)
        with patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': '2'}):
            pipeline.freeze_execution(self.job)
        with patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': '8'}):
            with self.assertRaises(ProverError): pipeline.freeze_execution(self.job)

    def test_real_guard_commands_keep_memory_caps_and_use_recorded_threads(self):
        for threads in (2, 8):
            for step in ('seqgen', 'prove', 'verify', 'inowner', 'label'):
                (self.job/'execution.json').unlink(missing_ok=True)
                with self.subTest(threads=threads, step=step), \
                     patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': str(threads)}), \
                     patch.object(pipeline, 'HOLDS', ()), patch.object(runtime, 'validate'), \
                     patch.object(pipeline.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='')) as run:
                    settings = pipeline.freeze_execution(self.job)
                    pipeline.run_step(self.job, step, ['native-fixture', step], self.cli)
                    argv = run.call_args.args[0]
                    self.assertEqual(argv[argv.index('--need-gib')+1], str(runtime.RESOURCES[step][0]))
                    self.assertEqual(argv[argv.index('--cap-gib')+1], str(runtime.RESOURCES[step][1]))
                    self.assertEqual(argv[argv.index('--max-secs')+1], str(settings['max_seconds'][step]))
                    self.assertIn('RAYON_NUM_THREADS='+str(2 if step == 'seqgen' else threads), argv)
                    self.assertIn('OPENBLAS_NUM_THREADS=2', argv)

    def test_tampered_execution_file_never_launches_native_command(self):
        with patch.dict(os.environ, {'PM_CLASSIFIER_NATIVE_THREADS': '8'}), \
             patch.object(runtime, 'validate'), patch.object(pipeline.subprocess, 'run') as run:
            value = pipeline.freeze_execution(self.job)
            value['max_seconds']['verify'] = 1
            (self.job/'execution.json').write_text(json.dumps(value))
            with self.assertRaises(ProverError): pipeline.run_step(self.job, 'verify', ['native-fixture'], self.cli)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
