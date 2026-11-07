#!/usr/bin/env python3
"""The shieldstral-fast service (DEVELOPMENT CANDIDATE, lane A24): ONE guarded job for its life.

usage: fast_service.py <private service directory>

Launched by the app (proven_media/fast_service.py) through the shared resource guard. It
holds `service.lock`, starts the two resident native servers (`zk60_classify serve` and
`check-serve`, its children), and runs every job request in `spool/`:

  prove:   activation writer -> one `serve` request -> one `check-serve` request (fresh
           verification in the verifier process + input-owner) -> for a category's last
           chunk, once its earlier chunks are done, one `check-serve` request over every
           chunk of the category with the label (the post's own count)
  recheck: one `check-serve` request (verify + input-owner)

Each job's directory receives `step.current`, `logs/*.log`, `logs/steps.json`,
`checked.json` (and `label-checked.json`) and `pipeline.done`, computed with the same
ClassifierCLI collectors the app re-runs. Nothing is retried: a failed step fails its job
(fail closed). The service exits after its idle period, on `STOP` once its jobs finish, or
when a native server dies (its in-flight jobs then fail). Logs stay private.
"""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import traceback
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media import shieldstral_fast_runtime as runtime  # noqa: E402
from proven_media.classifier_cli import ClassifierCLI, require  # noqa: E402
from proven_media.classifier_prover import deployment_from_json  # noqa: E402
from proven_media.provers import ProverError  # noqa: E402

BEAT_S = 5.0


def atomic(path, text):
    path = Path(path)
    tmp = path.with_name('.' + path.name + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(text)
    os.replace(tmp, path)


class Native:
    """one resident server: request lines in, its `served` lines routed to their callers"""

    def __init__(self, name, argv, env, log_dir):
        self.name = name
        self.err = open(log_dir / f'{name}.stderr.log', 'ab')
        self.out_log = open(log_dir / f'{name}.stdout.log', 'a')
        self.p = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.err,
                                  text=True, bufsize=1, env=env)
        self.start = None
        self.waiting = {}
        self.lock = threading.Lock()
        self.ready = threading.Event()
        self.ended = threading.Event()
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            if not line.startswith('{'):
                continue
            try:
                j = json.loads(line)
            except ValueError:
                continue
            ev = j.get('event')
            if ev == 'served':
                # result lines carry public words and the private log path only
                self.out_log.write(json.dumps({k: j.get(k) for k in ('id', 'status', 'lane', 'queued_seconds', 'seconds', 'verify_seconds')}) + '\n')
                self.out_log.flush()
                with self.lock:
                    slot = self.waiting.pop(j.get('id'), None)
                if slot:
                    slot['line'] = j
                    slot['event'].set()
            elif ev == 'serve-start':
                self.start = j
                self.ready.set()
            elif ev in ('refused', 'serve-end'):
                self.ready.set()
        self.ended.set()
        self.ready.set()
        with self.lock:
            for slot in self.waiting.values():
                slot['event'].set()
            self.waiting.clear()

    def alive(self):
        return self.p.poll() is None and not self.ended.is_set()

    def call(self, req, timeout):
        slot = {'event': threading.Event(), 'line': None}
        with self.lock:
            require(req['id'] not in self.waiting, 'duplicate service request id')
            self.waiting[req['id']] = slot
        try:
            self.p.stdin.write(json.dumps(req) + '\n')
            self.p.stdin.flush()
        except (OSError, ValueError):
            raise ProverError(f'the {self.name} server is gone')
        if not slot['event'].wait(timeout):
            raise ProverError(f'the {self.name} server did not answer within {timeout} s')
        if slot['line'] is None:
            raise ProverError(f'the {self.name} server ended')
        return slot['line']

    def close(self):
        try:
            self.p.stdin.close()
        except OSError:
            pass
        self.ended.wait(600)
        try:
            self.p.wait(60)
        except subprocess.TimeoutExpired:
            self.p.terminate()
        for f in (self.p.stdout, self.err, self.out_log):
            try:
                f.close()
            except (OSError, AttributeError):
                pass


class Service:
    def __init__(self, root):
        self.root = Path(root)
        self.run_id = uuid.uuid4().hex
        self.started = time.time()
        self.inflight = {}
        self.lock = threading.Lock()
        self.state = 'starting'
        self.writers = threading.Semaphore(runtime.WRITERS_AT_ONCE)
        self.stop = threading.Event()
        self.counts = {'jobs': 0, 'ok': 0, 'failed': 0}

    # ---------------------------------------------------------------- liveness
    def beat(self):
        with self.lock:
            inflight = len(self.inflight)
        atomic(self.root / 'heartbeat.json', json.dumps({
            'schema': 'pm-fast-heartbeat/1', 'pid': os.getpid(), 'run_id': self.run_id, 'started_at': self.started,
            'beat_at': time.time(), 'state': self.state, 'inflight': inflight, 'counts': self.counts,
            'prover_alive': getattr(self, 'prover', None) is not None and self.prover.alive(),
            'checker_alive': getattr(self, 'checker', None) is not None and self.checker.alive(),
            'binary_sha256': runtime.BINARY_SHA}))

    def beater(self):
        while not self.stop.is_set():
            try:
                self.beat()
            except OSError:
                pass
            self.stop.wait(BEAT_S)

    # ---------------------------------------------------------------- one job
    def step(self, job, name):
        atomic(job / 'step.current', f'{name} {time.time()}\n')

    def record(self, job, steps, name, t0, queued=0.0, **extra):
        steps[name] = {'ok': True, 'seconds': round(time.time() - t0, 3), 'queued_seconds': round(queued, 3), **extra}
        atomic(job / 'logs/steps.json', json.dumps(steps, sort_keys=True) + '\n')

    def writer(self, job, spec, steps):
        self.step(job, 'seqgen')
        t0 = time.time()
        with self.writers:
            queued = time.time() - t0
            t1 = time.time()
            env = dict(os.environ, OPENBLAS_NUM_THREADS=str(runtime.WRITER_THREADS), OMP_NUM_THREADS=str(runtime.WRITER_THREADS),
                       VECLIB_MAXIMUM_THREADS=str(runtime.WRITER_THREADS))
            with open(job / 'logs/seqgen.log', 'wb') as log:
                r = subprocess.run([runtime.WRITER_PYTHON, str(runtime.WRITER), '--request', spec['activation_request'],
                                    '--out', str(Path(spec['sequence_dir']).parent)], stdout=log, stderr=subprocess.STDOUT,
                                   env=env, timeout=runtime.STEP_TIMEOUTS['seqgen'])
            atomic(job / 'logs/seqgen.exit', f'{r.returncode}\n')
            require(r.returncode == 0, 'activation writer failed')
        self.record(job, steps, 'seqgen', t1, queued)

    def check(self, job, spec, chunks, label, log_name):
        req = {'id': f'{job}#{log_name}#{time.time_ns()}', 'policy': json.loads((job / 'classifier-job.json').read_text())['deployment']['policy'],
               'expect_total': spec['total'], 'content_file': spec['content_file'], 'chunks': chunks, 'label': label,
               'log': str(job / 'logs' / log_name)}
        line = self.checker.call(req, runtime.STEP_TIMEOUTS['check'])
        events = [json.loads(x) if x.startswith('{') else {'line': x} for x in (job / 'logs' / log_name).read_text().splitlines()]
        require(line.get('status') == 'checked', 'fresh verification refused')
        return line, events

    def run_job(self, op, job):
        job = Path(job)
        steps = {}
        (job / 'logs').mkdir(mode=0o700, exist_ok=True)
        atomic(job / 'service.claim', json.dumps({'run_id': self.run_id, 'pid': os.getpid(), 'at': time.time(), 'op': op}))
        spec = json.loads((job / 'classifier-job.json').read_text())
        require(spec.get('schema') == 'pm-classifier-job/1' and spec.get('mode') == ('prove' if op == 'prove' else 'recheck'),
                'unknown job schema or mode')
        deployment = deployment_from_json(spec['deployment'])
        runtime.validate(deployment)
        cli = ClassifierCLI(deployment)
        owner = Path(spec['owner_dir'])
        artifact = spec['artifact']
        if op == 'prove':
            self.writer(job, spec, steps)
            self.step(job, 'prove')
            t0 = time.time()
            line = self.prover.call({'id': f'{job}#prove', 'content_file': spec['content_file'], 'policy': deployment.policy,
                                     'chunk': spec['chunk'], 'seq_dir': spec['sequence_dir'], 'out': artifact,
                                     'owner_dir': str(owner), 'log': str(job / 'logs/prove.log')}, runtime.STEP_TIMEOUTS['prove'])
            atomic(job / 'logs/prove.exit', ('0' if line.get('status') == 'proved' else '1') + '\n')
            require(line.get('status') == 'proved', 'the prove request was refused')
            self.record(job, steps, 'prove', t0, line.get('queued_seconds') or 0.0, server_seconds=line.get('seconds'))
        # fresh verification + input-owner of this chunk (verify's and input-owner's event lines);
        # a one-chunk category is labelled in the same request (one verification of its bytes)
        single = op == 'prove' and spec['last_category_chunk'] and not spec['prior_jobs']
        self.step(job, 'verify')
        t0 = time.time()
        line, events = self.check(job, spec, [{'artifact': artifact, 'decommitment': str(owner / 'input.dec')}], single, 'check.log')
        classified = [e for e in events if e.get('event') == 'classified']
        owned = [e for e in events if e.get('event') == 'content-checked']
        require(len(classified) == 1 and len(owned) == 1, 'unexpected verifier events')
        atomic(job / 'logs/verify.log', json.dumps(classified[0]) + '\n')
        atomic(job / 'logs/inowner.log', json.dumps(owned[0]) + '\n')
        atomic(job / 'logs/verify.exit', '0\n')
        atomic(job / 'logs/inowner.exit', '0\n')
        self.record(job, steps, 'verify', t0, line.get('queued_seconds') or 0.0, verify_seconds=line.get('verify_seconds'))
        checked = cli.collect_verified(artifact, spec['total'], spec['chunk'], (job / 'logs/verify.log').read_text(), 0,
                                       (job / 'logs/inowner.log').read_text(), 0)
        if op == 'prove' and spec['last_category_chunk']:
            self.step(job, 'label')
            t0 = time.time()
            prior = []
            for previous in spec['prior_jobs']:
                previous = Path(previous)
                deadline = time.time() + runtime.STEP_TIMEOUTS['check'] * 2
                while not (previous / 'pipeline.done').exists():
                    require(time.time() < deadline and not self.stop.is_set(), 'an earlier chunk of this category did not finish')
                    time.sleep(1.0)
                ps = json.loads((previous / 'classifier-job.json').read_text())
                require((previous / 'pipeline.done').read_text().strip() == '0' and ps['deployment'] == spec['deployment']
                        and ps['post_id'] == spec['post_id'] and Path(ps['content_file']).read_bytes() == Path(spec['content_file']).read_bytes(),
                        'category aggregate belongs to different content or deployment')
                prior.append((ps, json.loads((previous / 'checked.json').read_text())))
            parts = [p for _, p in prior] + [checked]
            cli.check_label_records(parts, spec['total'])
            if not single:
                # every chunk of the category again in one request, with the label
                chunks = [{'artifact': ps['artifact'], 'decommitment': str(Path(ps['owner_dir']) / 'input.dec')} for ps, _ in prior]
                chunks.append({'artifact': artifact, 'decommitment': str(owner / 'input.dec')})
                line, events = self.check(job, spec, chunks, True, 'label-check.log')
            labels = [e for e in events if e.get('event') == 'label']
            require(len(labels) == 1, 'missing native label')
            atomic(job / 'logs/label.log', json.dumps(labels[0]) + '\n')
            atomic(job / 'logs/label.exit', '0\n')
            aggregate = cli.collect_label(parts, (job / 'logs/label.log').read_text(), 0, spec['total'])
            atomic(job / 'label-checked.json', json.dumps({'result': aggregate, 'statement_sha256': [p['statement_sha256'] for p in parts],
                                                           'total': spec['total']}, sort_keys=True) + '\n')
            self.record(job, steps, 'label', t0, line.get('queued_seconds') or 0.0, verify_seconds=line.get('verify_seconds'))
        atomic(job / 'checked.json', json.dumps(checked, sort_keys=True) + '\n')

    def job_thread(self, op, job, claimed):
        code = 1
        try:
            self.run_job(op, job)
            code = 0
        except Exception as exc:
            try:
                atomic(Path(job) / 'logs/error.json', json.dumps({'type': type(exc).__name__, 'message': str(exc)[:2000]}) + '\n')
            except OSError:
                pass
        finally:
            try:
                atomic(Path(job) / 'step.current', f'done {time.time()}\n')
                atomic(Path(job) / 'pipeline.done', f'{code}\n')
            except OSError:
                pass
            with self.lock:
                self.inflight.pop(claimed, None)
                self.counts['ok' if code == 0 else 'failed'] += 1

    # ---------------------------------------------------------------- the loop
    def claim_next(self):
        spool = self.root / 'spool'
        claimed_dir = self.root / 'claimed'
        claimed_dir.mkdir(mode=0o700, exist_ok=True)
        for f in sorted(p for p in spool.iterdir() if p.suffix == '.json' and not p.name.startswith('.')):
            target = claimed_dir / f'{self.run_id}-{f.name}'
            try:
                os.replace(f, target)
            except FileNotFoundError:
                continue
            try:
                req = json.loads(target.read_text())
                require(req.get('schema') == 'pm-fast-request/1' and req.get('op') in ('prove', 'recheck'), 'bad request')
                # the claim names this service run at once (a poll in between still sees the
                # request in claimed/ while this run lives)
                atomic(Path(req['job']) / 'service.claim', json.dumps({'run_id': self.run_id, 'pid': os.getpid(), 'at': time.time(),
                                                                      'op': req['op']}))
                return req['op'], Path(req['job']), target
            except (ValueError, OSError, ProverError):
                continue
        return None

    def main(self):
        os.umask(0o077)
        lock_fd = os.open(self.root / 'service.lock', os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps({'event': 'service-already-running'}), flush=True)
            return 0
        threading.Thread(target=self.beater, daemon=True).start()
        env = dict(os.environ, **runtime.native_environment(), HL_OWNER_PRIVATE_DIR=str(self.root / 'refusals'))
        logs = self.root / 'logs'
        logs.mkdir(mode=0o700, exist_ok=True)
        try:
            runtime.validate(runtime.deployment(runtime.templates()[0]))
            self.prover = Native('prover', runtime.server_argv('prove'), env, logs)
            self.checker = Native('checker', runtime.server_argv('check'), env, logs)
            self.prover.ready.wait(900)
            self.checker.ready.wait(900)
            require(self.prover.start is not None and self.checker.start is not None, 'a native server refused to start')
            self.state = 'ready'
            self.beat()
            idle_since = time.time()
            limit = runtime.JOBS_IN_FLIGHT
            while True:
                if not (self.prover.alive() and self.checker.alive()):
                    self.state = 'server-died'
                    break
                with self.lock:
                    n = len(self.inflight)
                stopping = (self.root / 'STOP').exists()
                if n < limit and not stopping:
                    nxt = self.claim_next()
                    if nxt:
                        op, job, claimed = nxt
                        with self.lock:
                            self.inflight[claimed] = str(job)
                            self.counts['jobs'] += 1
                        threading.Thread(target=self.job_thread, args=(op, job, claimed), daemon=True).start()
                        idle_since = time.time()
                        continue
                if n:
                    idle_since = time.time()
                elif stopping or time.time() - idle_since > runtime.SERVICE_IDLE_SECONDS:
                    self.state = 'stopping'
                    break
                time.sleep(0.5)
        except Exception:
            (self.root / 'logs' / 'service-error.log').write_text(traceback.format_exc())
            self.state = 'failed'
        finally:
            self.beat()
            for s in (getattr(self, 'prover', None), getattr(self, 'checker', None)):
                if s is not None:
                    s.close()
            # in-flight jobs of a dead server end through their failed calls; wait briefly
            deadline = time.time() + 30
            while time.time() < deadline:
                with self.lock:
                    if not self.inflight:
                        break
                time.sleep(0.5)
            self.state = 'stopped'
            self.stop.set()
            self.beat()
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        return 0


if __name__ == '__main__':
    raise SystemExit(Service(sys.argv[1]).main())
