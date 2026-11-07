"""[A24] The shieldstral-fast development candidate: mode selection, metadata, transport,
the concurrent queue and the service lifecycle, with simulated servers (never a native proof).

The native proofs, fresh verifications and negative controls of this mode are measured and
tested natively (hashline `classify_serve_tests.rs`, results/zk60_a24_app_20261107/).
"""
from contextlib import contextmanager, ExitStack
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from native_fixtures import use_context
from proven_media import config, fast_service, hardware_profiles, records
from proven_media import shieldstral_fast_runtime as fast
from proven_media.classifier_privacy import statement_info
from proven_media.items import TextItem
from proven_media.jobs import Worker
from proven_media.publisher import LocalChainPublisher
from proven_media.shieldstral_text import ShieldstralTextEncoder
from proven_media.store import Store

FAKE_WRITER = '''import argparse, json, os
from pathlib import Path
p = argparse.ArgumentParser(); p.add_argument('--request'); p.add_argument('--out'); a = p.parse_args()
os.makedirs(a.out, mode=0o700)
for row in json.loads(Path(a.request).read_text()):
    os.makedirs(Path(a.out) / row['name'], mode=0o700)
print('TEST FIXTURE: no activations')
'''

# A simulated native server: answers every request line with `served` of a fixed status.
FAKE_SERVER = '''import json, sys
status = sys.argv[1]
print(json.dumps({"event": "serve-start", "command": "simulated"}), flush=True)
for line in sys.stdin:
    if not line.strip():
        continue
    req = json.loads(line)
    if req.get("log"):
        open(req["log"], "w").write(json.dumps({"event": "refused", "command": "simulated"}) + "\\n")
    print(json.dumps({"event": "served", "id": req["id"], "status": status, "seconds": 0.01}), flush=True)
'''


@contextmanager
def fast_fixture(root):
    """non-executable binary bytes and a stand-in writer, with their real digests (the pins'
    checks stay active); not native validation"""
    with ExitStack() as stack:
        binary = root / 'NOT-A-NATIVE-PROVER'
        binary.write_bytes(b'TEST FIXTURE ONLY: native execution must be simulated\n')
        writer_root = root / 'writer'
        writer_root.mkdir()
        (writer_root / 'write_item_activations.py').write_text(FAKE_WRITER)
        deps = {}
        for name in ('mac_model.py', 'source-pins.json'):
            (writer_root / name).write_text('fixture\n')
            deps[writer_root / name] = hashlib.sha256(b'fixture\n').hexdigest()
        sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
        stack.enter_context(patch.object(fast, 'BINARY', binary))
        stack.enter_context(patch.object(fast, 'BINARY_SHA', sha(binary)))
        stack.enter_context(patch.object(fast, 'WRITER', writer_root / 'write_item_activations.py'))
        stack.enter_context(patch.object(fast, 'WRITER_SHA', sha(writer_root / 'write_item_activations.py')))
        stack.enter_context(patch.object(fast, 'WRITER_DEPENDENCIES', deps))
        stack.enter_context(patch.object(fast, 'WRITER_PYTHON', sys.executable))
        yield binary


class FastModeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        use_context(self, fast_fixture(self.root))
        patches = [patch.dict(os.environ, {'PM_PROVER': 'shieldstral-fast'}),
                   patch.object(config, 'PRIVATE_DIR', self.root / 'private'),
                   patch.object(config, 'JOBS_DIR', self.root / 'private/jobs'),
                   patch.object(config, 'RUNS_DIR', self.root / 'public/runs'),
                   patch.object(config, 'HOLD_FILE', self.root / 'HOLD')]
        self.encoder = object.__new__(ShieldstralTextEncoder)
        self.encoder.content_ids = lambda text: tuple(range(1000, 1000 + len(text.split())))
        patches.append(patch('proven_media.shieldstral_fast_prover.ShieldstralTextEncoder', return_value=self.encoder))
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.launches = []
        from proven_media.shieldstral_fast_prover import ShieldstralFastProver
        self.prover = ShieldstralFastProver(launcher=lambda argv: self.launches.append(argv))
        self.text = 'a calm afternoon in the garden'

    def test_default_and_reviewed_modes_are_unchanged_and_separately_screened(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('PM_PROVER', None)
            self.assertEqual(config.prover_mode(), 'stub')
            stub_set = config.category_set_id()
        with patch.dict(os.environ, {'PM_PROVER': 'shieldstral'}):
            reviewed = config.category_set_id()
            self.assertEqual(config.deploy()['profile'], 'shieldstral-t128')
        self.assertEqual(reviewed, 'shieldstral-moderate-testnet-v1')
        self.assertEqual(config.category_set_id(), 'shieldstral-moderate-fast-dev-v1')
        self.assertNotIn(config.category_set_id(), (stub_set, reviewed), 'a post screened in one mode is never finalized by another')
        self.assertEqual([c['policy_id'] for c in config.registered_categories()],
                         [f'shieldstral-1.0-3b-moderate-{c}/1' for c in ('sexual', 'violence', 'hate')], 'D61 policies unchanged')

    def test_metadata_says_development_candidate_privacy_pending_not_production(self):
        d = self.prover.describe()
        self.assertEqual(d['kind'], 'shieldstral-fast')
        self.assertEqual(d['privacy_status'], 'privacy statement pending')
        self.assertFalse(d['privacy_statement']['accepted'])
        self.assertFalse(d['privacy_statement']['permits_non_public_posts'])
        self.assertIs(d['production'], False)
        self.assertIs(d['development_candidate'], True)
        self.assertEqual(d['model_digest'], fast.IDENTITY)
        # even described as the reviewed kind, this binary/profile/device is not D58's
        spoof = {**fast.descriptor(), 'kind': 'shieldstral', 'device': 'cpu', 'proof_mode': 'per-category',
                 'privacy_adapter_supported': True}
        self.assertFalse(statement_info(spoof)['accepted'])

    def test_a26_pins_its_binary_and_the_servers_device_settings_and_keeps_its_ruling_switches_off(self):
        """[A26] the pinned binary is lane A26's (a SHA-256, never A24's ccd58102...), with the same
        statement identity and run profile as A24's; the servers get one Metal queue per thread;
        the two work cuts that wait for the security owner (HL_A26_KEPT, HL_A26_VERIFY_ONCE) are
        not switched on by the app"""
        pin = fast_runtime_pin()
        self.assertRegex(pin, r'^[0-9a-f]{64}$')
        self.assertNotEqual(pin, 'ccd58102e3fdbe4fb0be3446b5d539cd6741779a6efaea073251ef040968a946')
        self.assertEqual(fast.IDENTITY, 'e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d', 'the same receipts: the same identity')
        self.assertEqual(fast.RUN_PROFILE, 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2')
        self.assertEqual(fast.LANE, 'A26')
        self.assertEqual(fast.NATIVE_SETTINGS, {'HL_METAL_QUEUES': 'thread'})
        models = self.root / 'models/shieldstral-1.0-3b/snapshot-003ec7e2'
        models.mkdir(parents=True)
        (models / 'model.safetensors').write_bytes(b'TEST FIXTURE\n')
        with patch.object(fast, 'NATIVE_MODELS', self.root / 'models'):
            env = fast.native_environment()
        self.assertEqual(env['HL_METAL_QUEUES'], 'thread')
        self.assertEqual(env['HL_GPU'], '1')
        for off in ('HL_A26_KEPT', 'HL_A26_VERIFY_ONCE'):
            self.assertNotIn(off, env, f'{off} waits for the security owner')
        self.assertIn('A26', fast.CLI_DESCRIPTION)

    def test_preparation_pins_the_candidate_and_submits_one_spool_request_per_job(self):
        item = TextItem(self.text)
        plan = self.prover.plan_text(item.text)
        self.assertEqual(len(plan), 3)
        for ch in plan:
            job = config.JOBS_DIR / 'post' / ('prove' if ch['index'] == 0 else f'prove-c{ch["index"]}')
            self.prover.start('post', item, job, ch)
            spec = json.loads((job / 'classifier-job.json').read_text())
            self.assertEqual(spec['deployment']['binary_sha256'], fast.BINARY_SHA)
            self.assertEqual(spec['deployment']['statement_identity'], fast.IDENTITY)
            self.assertEqual((job / 'content.ids').stat().st_mode & 0o777, 0o600)
            req = fast.service_dir() / 'spool' / (job / 'service.request').read_text().strip()
            self.assertEqual(req.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(req.read_text()), {'schema': 'pm-fast-request/1', 'op': 'prove', 'job': str(job.resolve())})
            st = self.prover.poll(job)
            self.assertFalse(st['done'])
            self.assertTrue(st['alive'], 'a queued request waits for a launching service')
        self.assertEqual(len(self.launches), 1, 'one service launch for the three jobs')
        argv = self.launches[0]
        self.assertEqual(argv[:4], ['python3', str(config.GUARD), 'run', '--class'])
        self.assertIn('--need-gib', argv)
        self.assertEqual(argv[-1], str(fast.service_dir()))

    def test_a_job_claimed_by_a_dead_service_is_not_alive_and_a_done_job_is_done(self):
        ch = self.prover.plan_text(self.text)[0]
        job = config.JOBS_DIR / 'post' / 'prove'
        self.prover.prepare('post', TextItem(self.text), job, ch)
        fast_service.ensure_dirs(fast.service_dir())
        (job / 'service.claim').write_text(json.dumps({'run_id': 'gone', 'pid': 1}))
        self.assertIs(self.prover.poll(job)['alive'], False, 'no live service holds the lock: fail closed, never retried')
        (job / 'pipeline.done').write_text('0\n')
        self.assertEqual(self.prover.poll(job)['done'], True)

    def test_fast_hardware_profile_validates_against_the_runtime_and_refuses_retuning(self):
        with ExitStack() as stack:
            # the real pins (no fixture) against the checked-in deploy.json
            for name in ('BINARY_SHA',):
                stack.enter_context(patch.object(fast, name, fast_runtime_pin()))
            p = hardware_profiles.fast_classifier_profile()
            self.assertTrue(p['validated_against_runtime'])
            data = json.loads(config.DEPLOY_FILE.read_text())
            data['classifier_profiles'][hardware_profiles.FAST_PROFILE]['servers']['prover_lanes'] = 7
            path = self.root / 'deploy.json'
            path.write_text(json.dumps(data))
            with self.assertRaises(Exception):
                hardware_profiles.fast_classifier_profile(path)


def fast_runtime_pin():
    """the module's own BINARY_SHA, read from its source (the fixture patches the attribute)"""
    src = Path(fast.__file__).read_text()
    return src.split("BINARY_SHA = '")[1].split("'")[0]


class ConcurrentQueueTests(unittest.TestCase):
    """the worker starts up to `max_running` jobs of a concurrent prover, in queue order"""

    def setUp(self):
        from test_category_queue import CategoryFixture
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for key, path in {'PRIVATE_DIR': self.root / 'private', 'JOBS_DIR': self.root / 'jobs',
                          'SIGNING_KEY': self.root / 'private/key', 'HOLD_FILE': self.root / 'HOLD'}.items():
            p = patch.object(config, key, path)
            p.start()
            self.addCleanup(p.stop)
        self.store = Store(self.root / 'app.sqlite3')
        self.addCleanup(lambda: self.store.db.close())

        class Concurrent(CategoryFixture):
            max_running = 3
            started = []

            def start(self, post_id, item, job, chunk=None):
                job.mkdir(parents=True)
                self.started.append(chunk['index'])

        self.prover = Concurrent()
        self.worker = Worker(self.store, self.prover, LocalChainPublisher(self.root / 'public'))
        self.text = ' '.join(f'word{i}' for i in range(20))

    def test_up_to_three_jobs_run_at_once_and_every_post_still_finalizes(self):
        plan = self.prover.plan_text(self.text)
        self.assertGreater(len(plan), 3)
        self.store.add_screened_post(self.text, plan, id='cd' * 16, author='@test', kind='text', text=self.text,
            status='queued', prover_kind=self.prover.kind, chunks=json.dumps(plan),
            content_key=records.content_key(self.text), salt_enc=records.new_salt_enc('cd' * 16))
        self.worker.tick()
        running = self.store.q("SELECT * FROM jobs WHERE status='running' ORDER BY id")
        self.assertEqual(len(running), 3, 'three at once')
        self.assertEqual(self.prover.started, [0, 1, 2], 'in queue order')
        self.worker.tick()
        self.assertEqual(len(self.store.q("SELECT * FROM jobs WHERE status='running'")), 3, 'no fourth while three run')
        Path(running[0]['job_dir'], 'pipeline.done').write_text('0\n')
        self.worker.tick()
        self.assertEqual(self.prover.started, [0, 1, 2, 3], 'a finished job frees one slot')
        for _ in range(20):
            for j in self.store.q("SELECT * FROM jobs WHERE status='running'"):
                Path(j['job_dir'], 'pipeline.done').write_text('0\n')
            self.worker.tick()
        self.assertFalse(self.store.q("SELECT id FROM jobs WHERE status IN ('queued','running')"))
        post = self.store.post('cd' * 16)
        self.assertIn(post['status'], ('published', 'failed'))
        self.assertEqual(len(self.prover.started), len(plan))


class ServiceLifecycleTests(unittest.TestCase):
    """tools/fast_service.py with simulated native servers: a refused step fails its job closed;
    STOP ends the service after its jobs; the heartbeat names the live run"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        use_context(self, fast_fixture(self.root))
        patches = [patch.dict(os.environ, {'PM_PROVER': 'shieldstral-fast'}),
                   patch.object(config, 'PRIVATE_DIR', self.root / 'private'),
                   patch.object(config, 'JOBS_DIR', self.root / 'private/jobs'),
                   patch.object(config, 'RUNS_DIR', self.root / 'public/runs')]
        encoder = object.__new__(ShieldstralTextEncoder)
        encoder.content_ids = lambda text: tuple(range(1000, 1000 + len(text.split())))
        patches.append(patch('proven_media.shieldstral_fast_prover.ShieldstralTextEncoder', return_value=encoder))
        server = self.root / 'fake_server.py'
        server.write_text(FAKE_SERVER)
        self.server = server
        patches.append(patch.object(fast, 'native_environment', lambda: {}))
        patches.append(patch.object(fast, 'SERVICE_IDLE_SECONDS', 600))
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        spec = importlib.util.spec_from_file_location('fast_service_tool', config.TOOLS_DIR / 'fast_service.py')
        self.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.tool)
        from proven_media.shieldstral_fast_prover import ShieldstralFastProver
        self.prover = ShieldstralFastProver(launcher=lambda argv: None)

    def run_service(self, prove_status):
        argv = {'prove': [sys.executable, str(self.server), prove_status], 'check': [sys.executable, str(self.server), 'refused']}
        root = fast.service_dir()
        fast_service.ensure_dirs(root)
        p = patch.object(fast, 'server_argv', lambda kind: argv[kind])
        p.start()
        self.addCleanup(p.stop)
        svc = self.tool.Service(root)
        t = threading.Thread(target=svc.main, daemon=True)
        t.start()
        return svc, t, root

    def test_a_refused_prove_or_check_fails_the_job_closed_and_stop_ends_the_service(self):
        item = TextItem('a calm afternoon in the garden')
        plan = self.prover.plan_text(item.text)
        for status in ('refused', 'proved'):
            with self.subTest(prove=status):
                job = config.JOBS_DIR / f'post-{status}' / 'prove'
                self.prover.start(f'post-{status}', item, job, plan[0])
                svc, t, root = self.run_service(status)
                deadline = time.time() + 60
                while not (job / 'pipeline.done').exists() and time.time() < deadline:
                    time.sleep(0.2)
                self.assertEqual((job / 'pipeline.done').read_text().strip(), '1', 'fail closed')
                err = json.loads((job / 'logs/error.json').read_text())
                self.assertIn('refused', err['message'])
                self.assertTrue((job / 'logs/seqgen.log').exists(), 'the writer ran before the native step')
                hb = json.loads((root / 'heartbeat.json').read_text())
                self.assertEqual(hb['run_id'], json.loads((job / 'service.claim').read_text())['run_id'])
                self.assertTrue(fast_service.service_live(root))
                fast_service.stop(root)
                t.join(60)
                self.assertFalse(t.is_alive(), 'STOP ends an idle service')
                self.assertFalse(fast_service.service_live(root), 'the lock is released')
                self.assertEqual(json.loads((root / 'heartbeat.json').read_text())['state'], 'stopped')
                self.assertIs(self.prover.poll(job)['done'], True)
                (root / 'STOP').unlink()


if __name__ == '__main__':
    unittest.main()
