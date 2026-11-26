"""Integration behavior with synthetic workers/servers; no models or native proofs."""
from contextlib import ExitStack
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

import test_app
from proven_media import config, fast_service, hardware_profiles, resident_writer
from proven_media import shieldstral_fast_runtime as runtime
from proven_media.provers import ProverError
from proven_media.shieldstral_fast_prover import ShieldstralFastProver
from proven_media.shieldstral_text import TEKKEN_SHA256


class Pool:
    def __init__(self):
        self.clients = [Mock(closed=False, process=Mock(poll=Mock(return_value=None))) for _ in range(2)]
        self.write = Mock(return_value=({'seconds': 0.01}, 0.0))
        self.closed = 0

    def close(self):
        self.closed += 1
        for client in self.clients:
            client.closed = True
            client.process.poll.return_value = 0


class Native:
    instances = []

    def __init__(self, *args):
        self.ready = threading.Event()
        self.ready.set()
        self.start = {'event': 'serve-start'}
        self.closed = False
        self.__class__.instances.append(self)

    def alive(self):
        return not self.closed

    def close(self):
        self.closed = True


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.service_root = self.root / 'private/fast-service'
        fast_service.ensure_dirs(self.service_root)
        mode = patch.object(runtime, 'WRITER_MODE', 'resident')
        mode.start()
        self.addCleanup(mode.stop)
        env = patch.dict(os.environ, {})
        env.start()
        self.addCleanup(env.stop)
        spec = importlib.util.spec_from_file_location('resident_service_test', config.TOOLS_DIR / 'fast_service.py')
        self.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.tool)
        self.pool = Pool()

    def service(self):
        Native.instances = []
        with ExitStack() as stack:
            stack.enter_context(patch.object(runtime, 'validate'))
            stack.enter_context(patch.object(runtime, 'native_environment', return_value={}))
            stack.enter_context(patch.object(runtime, 'server_argv', return_value=['simulated']))
            stack.enter_context(patch.object(self.tool, 'Native', Native))
            factory = stack.enter_context(patch.object(resident_writer, 'open_pool', return_value=self.pool))
            service = self.tool.Service(self.service_root)
            yield service, factory

    def test_memory_budget_changes_only_with_explicit_mode_and_unknown_refuses(self):
        for mode, expected in [('oneshot', (110, 180)), ('resident', (196, 220))]:
            with patch.object(runtime, 'WRITER_MODE', mode):
                argv = fast_service.guard_command(self.service_root, runtime)
                self.assertEqual(argv[argv.index('--need-gib') + 1], str(expected[0]))
                self.assertEqual(argv[argv.index('--cap-gib') + 1], str(expected[1]))
                self.assertEqual(argv[-3:], ['--writer-mode', mode, str(self.service_root)])
                self.assertEqual(argv[argv.index('--class') + 1], 'gpu')
                self.assertEqual(runtime.PROVER_LANES, 6)
                self.assertEqual(runtime.CHECK_LANES, 3)
        with patch.object(runtime, 'WRITER_MODE', 'automatic'):
            with self.assertRaises(ProverError):
                fast_service.guard_command(self.service_root, runtime)

    def test_hardware_record_selects_resident_budget_and_refuses_baseline_or_retuning(self):
        profile = hardware_profiles.fast_classifier_profile()
        self.assertEqual(profile['name'], hardware_profiles.RESIDENT_FAST_PROFILE)
        self.assertEqual(profile['guard_resources']['service']['need_gib'], 196)
        self.assertFalse(profile['production'])
        with self.assertRaises(ProverError):
            hardware_profiles.fast_classifier_profile(name=hardware_profiles.FAST_PROFILE)
        data = json.loads(config.DEPLOY_FILE.read_text())
        data['classifier_profiles'][hardware_profiles.RESIDENT_FAST_PROFILE]['guard_resources']['service']['cap_gib'] = 180
        path = self.root / 'changed.json'
        path.write_text(json.dumps(data))
        with self.assertRaises(ProverError):
            hardware_profiles.fast_classifier_profile(path)

    def test_changed_live_service_is_not_reused_and_job_is_not_enqueued(self):
        with patch.object(runtime, 'WRITER_MODE', 'oneshot'):
            old = runtime.service_binding()
        job = self.root / 'job'
        job.mkdir()
        (job / 'classifier-job.json').write_text('{}')
        prover = object.__new__(ShieldstralFastProver)
        prover.service = self.service_root
        prover.launcher = Mock()
        with patch.object(fast_service, 'health', return_value={
            'live': True, 'launching': False, 'heartbeat': {'writer_binding': old}}):
            with self.assertRaises(ProverError):
                prover._submit(job, 'prove')
        self.assertFalse((job / 'service.request').exists())
        self.assertEqual(list((self.service_root / 'spool').iterdir()), [])
        prover.launcher.assert_not_called()
        self.assertFalse((self.service_root / 'STOP').exists())

    def test_matching_live_service_is_reused_without_launch(self):
        current = {'live': True, 'launching': False, 'heartbeat': {'writer_binding': runtime.service_binding()}}
        launch = Mock()
        with patch.object(fast_service, 'health', return_value=current):
            self.assertEqual(fast_service.ensure_running(self.service_root, runtime, launcher=launch), current)
        launch.assert_not_called()

    def test_pending_guard_configuration_must_match_and_is_never_replaced(self):
        launch = self.service_root / 'launch.json'
        for binding, accepted in [(runtime.service_binding(), True), ({'mode': 'oneshot'}, False), (None, False)]:
            launch.write_text(json.dumps({'writer_binding': binding}))
            before = launch.read_bytes()
            with patch.object(fast_service, 'health', return_value={'live': False, 'launching': True}):
                if accepted:
                    fast_service.ensure_running(self.service_root, runtime, launcher=Mock(side_effect=AssertionError))
                else:
                    with self.assertRaises(ProverError):
                        fast_service.ensure_running(self.service_root, runtime, launcher=Mock(side_effect=AssertionError))
            self.assertEqual(launch.read_bytes(), before)

    def test_new_guard_launch_persists_writer_identity(self):
        with patch.object(fast_service, 'health', return_value={'live': False, 'launching': False}):
            fast_service.ensure_running(self.service_root, runtime, launcher=lambda argv: 123)
        launch = json.loads((self.service_root / 'launch.json').read_text())
        self.assertEqual(launch['writer_binding'], runtime.service_binding())
        self.assertEqual(launch['argv'][-3:], ['--writer-mode', 'resident', str(self.service_root)])

    def test_busy_lock_prevents_worker_or_native_startup(self):
        lock = os.open(self.service_root / 'service.lock', os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            for service, factory in self.service():
                self.assertEqual(service.main(), 0)
                factory.assert_not_called()
                self.assertFalse(Native.instances)
        finally:
            os.close(lock)

    def test_stop_closes_both_workers_before_releasing_service_lock(self):
        (self.service_root / 'STOP').write_text('stop')
        close = self.pool.close

        def close_while_locked():
            self.assertTrue(fast_service.service_live(self.service_root))
            close()

        self.pool.close = close_while_locked
        for service, factory in self.service():
            self.assertEqual(service.main(), 0)
            factory.assert_called_once()
        self.assertEqual(self.pool.closed, 1)
        self.assertEqual(len(Native.instances), 2)
        self.assertTrue(all(n.closed for n in Native.instances))
        self.assertFalse(fast_service.service_live(self.service_root))

    def test_worker_startup_failure_closes_lock_and_starts_no_native_server(self):
        for service, factory in self.service():
            factory.side_effect = ProverError('fixture startup refusal')
            self.assertEqual(service.main(), 1)
        self.assertFalse(Native.instances)
        self.assertFalse(fast_service.service_live(self.service_root))
        self.assertEqual(json.loads((self.service_root / 'heartbeat.json').read_text())['state'], 'stopped')

    def test_dead_worker_stops_service_without_claiming_pending_job(self):
        self.pool.clients[0].process.poll.return_value = 1
        for service, _ in self.service():
            with patch.object(service, 'claim_next', side_effect=AssertionError('no work after worker death')):
                self.assertEqual(service.main(), 1)
        self.assertEqual(self.pool.closed, 1)
        self.assertTrue(all(n.closed for n in Native.instances))
        self.assertFalse(fast_service.service_live(self.service_root))

    def test_resident_write_failure_is_not_retried_or_exposed_in_public_status(self):
        service = self.tool.Service(self.service_root)
        service.writer_pool = self.pool
        self.pool.write.side_effect = RuntimeError('private fixture words must not escape')
        job = self.root / 'job'
        (job / 'logs').mkdir(parents=True)
        spec = {'activation_request': str(job / 'request.json'), 'sequence_dir': str(job / 'activations/chunk')}
        steps = {}
        with self.assertRaisesRegex(ProverError, 'no retry') as exc:
            service.writer(job, spec, steps)
        self.assertNotIn('private fixture words', str(exc.exception))
        self.pool.write.assert_called_once()
        self.assertEqual((job / 'logs/seqgen.exit').read_text(), '1\n')
        self.assertTrue((self.service_root / 'STOP').exists())
        self.assertNotIn('seqgen', steps)

    def test_resident_write_success_keeps_step_contract(self):
        service = self.tool.Service(self.service_root)
        service.writer_pool = self.pool
        job = self.root / 'job'
        (job / 'logs').mkdir(parents=True)
        spec = {'activation_request': str(job / 'request.json'), 'sequence_dir': str(job / 'activations/chunk')}
        steps = {}
        service.writer(job, spec, steps)
        self.assertTrue(steps['seqgen']['ok'])
        self.assertTrue(steps['seqgen']['resident'])
        self.assertEqual((job / 'logs/seqgen.exit').read_text(), '0\n')
        self.assertFalse((self.service_root / 'STOP').exists())

    def test_old_or_changed_job_configuration_refuses_before_writer_or_native_work(self):
        service = self.tool.Service(self.service_root)
        service.writer_pool = self.pool
        for index, binding in enumerate([None, {'mode': 'oneshot'}]):
            job = self.root / f'job-{index}'
            job.mkdir()
            (job / 'classifier-job.json').write_text(json.dumps({'writer_binding': binding}))
            with self.assertRaises(ProverError):
                service.run_job('prove', job)
        self.pool.write.assert_not_called()


class SourceAndReadyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()

    def fake_sources(self, mutation=None):
        source = self.root / 'source'
        source.mkdir()
        for name in ['engine.py', 'pipe_worker.py']:
            (source / name).write_text('# synthetic fixture only\n')
        pins = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.iterdir()}
        ready = {'event': 'ready', 'profile_sha256': runtime.PROFILE_SHA, 'original_writer_sha256': runtime.WRITER_SHA,
                 'writer_sha256': pins['engine.py'], 'tokenizer_sha256': TEKKEN_SHA256,
                 'layers_loaded': 26, 'numpy': resident_writer.NUMPY_VERSION}
        if mutation:
            ready.update(mutation)
        code = ('from pathlib import Path\nfrom types import SimpleNamespace\n'
                'class Pool:\n'
                ' def __init__(self, python, root, logs, count):\n'
                '  self.root=Path(root)\n'
                f'  self.clients=[SimpleNamespace(ready={ready!r}) for _ in range(count)]\n'
                ' def close(self):\n'
                '  (self.root/"closed").write_text("closed")\n')
        (source / 'client.py').write_text(code)
        pins['client.py'] = hashlib.sha256((source / 'client.py').read_bytes()).hexdigest()
        return source, pins

    def test_source_drift_refuses_before_import(self):
        source, pins = self.fake_sources()
        (source / 'client.py').write_text('raise AssertionError("changed code executed")')
        with patch.object(resident_writer, 'ROOT', source), patch.object(resident_writer, 'SOURCE_PINS', pins):
            with self.assertRaises(ProverError):
                resident_writer.open_pool(runtime, self.root, self.root, 'changed')
        self.assertFalse((self.root / 'resident-changed').exists())

    def test_ready_mismatch_closes_constructed_pool(self):
        source, pins = self.fake_sources({'profile_sha256': 'wrong'})
        with patch.object(resident_writer, 'ROOT', source), patch.object(resident_writer, 'SOURCE_PINS', pins):
            with self.assertRaises(ProverError):
                resident_writer.open_pool(runtime, self.root, self.root, 'mismatch')
        self.assertTrue((self.root / 'closed').exists())

    def test_ready_success_has_separate_private_logs_on_each_restart(self):
        source, pins = self.fake_sources()
        with patch.object(resident_writer, 'ROOT', source), patch.object(resident_writer, 'SOURCE_PINS', pins):
            for run_id in ('first', 'second'):
                pool = resident_writer.open_pool(runtime, self.root, self.root, run_id)
                path = self.root / f'resident-{run_id}/ready.json'
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
                self.assertEqual(len(json.loads(path.read_text())), 2)
                pool.close()


if __name__ == '__main__':
    unittest.main()
