#!/usr/bin/env python3
"""Lane A25: the native resident servers on a stream of public posts (no app), at the R13
profile (A24's fast path) or the W16R2 development profile. A24's stream_driver.py with three
additions: `--profile`, `--bin`, and `--defer-check` (the proof-only clock).

One guarded job runs this driver. It starts `zk60_classify serve` (prover) and
`zk60_classify check-serve` (verifier, its own process), then for each post:
  1. the activation writer (Python, one invocation for every category chunk of the post),
  2. one `serve` request per category chunk,
  3. one `check-serve` request per category once all its chunks are proved
     (fresh verification in the verifier process + input-owner + label).
Every proof is freshly verified; a post counts as done when all three category labels are
accepted.

`--defer-check` (the proof-only clock, "verification on another machine"): the verifier is NOT
started until the last proof is written; the prover clock stops there. Then the verifier starts
and checks every category of every post (same requests), on its own clock. Both are reported;
every receipt is still freshly verified before the run is accepted.

usage: stream_driver.py --tag T --posts FILE --profile r13|w16r2 [--bin PATH] [--identity HEX]
       [--lanes 6] [--lane-threads 5] [--check-lanes 3] [--check-threads 4] [--witness-gib 16]
       [--keep N] [--gap 0] [--defer-check]
FILE: JSON list of public texts (each is tokenized with the pinned Tekken encoder).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

WT = Path('/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c')
REPO = Path('/Users/victorrielly/IntelligenceRegulation')
R = WT / 'results/zk60_a25_app_20261107'
BIN = WT / 'ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify'
EXP = REPO / 'results/zk60_shieldstral_export_20261026/native_low_h24_t128'
VEXP = REPO / 'results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier'
PY = '/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python'
WRITER = REPO / 'results/zk60_astra_20261026/a3_mac_writer_20261105/write_item_activations.py'
TEKKEN = REPO / 'results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tekken.json'
PRIV = Path('/Users/victorrielly/zk60-owner-private/a25-media-app-20261107')
PUB = Path('/Users/victorrielly/zk60-artifacts/a25-media-app-20261107')
R13_IDENTITY = 'e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d'
SWITCH = '--dev-w16r2-public-content-only'
CATS = {'sexual': 55, 'violence': 55, 'hate': 49}
POL = {c: f'shieldstral-1.0-3b-moderate-{c}/1' for c in CATS}


def plan(total, size, overlap=8):
    if total < size:
        return [(0, total)]
    starts = list(range(0, total - size + 1, size - overlap))
    if starts[-1] != total - size:
        starts.append(total - size)
    return [(a, a + size) for a in starts]


def private_write(path, raw):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(raw)


def encode(texts):
    sys.path.insert(0, str(WT / 'apps/proven-media'))
    os.environ['PM_SHIELDSTRAL_TOKENIZER'] = str(TEKKEN)
    from proven_media.shieldstral_text import ShieldstralTextEncoder
    enc = ShieldstralTextEncoder(TEKKEN)
    return [enc.content_ids(t) for t in texts]


class Server:
    """a native server: request lines in, `served` lines out (other stdout lines are diagnostics)"""

    def __init__(self, argv, log, env):
        self.p = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(log + '.err', 'w'),
                                  text=True, bufsize=1, env=env)
        self.log = open(log, 'w')
        self.start = None
        self.waiting = {}
        self.lock = threading.Lock()
        self.ready = threading.Event()
        self.ended = threading.Event()
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            self.log.write(line)
            self.log.flush()
            if not line.startswith('{'):
                continue
            try:
                j = json.loads(line)
            except ValueError:
                continue
            ev = j.get('event')
            if ev == 'serve-start':
                self.start = j
                self.ready.set()
            elif ev == 'served':
                with self.lock:
                    cb = self.waiting.pop(j.get('id'), None)
                if cb:
                    cb(j, time.time())
            elif ev in ('serve-end', 'refused'):
                self.start = self.start or j
                self.ready.set()
        self.ended.set()
        self.ready.set()

    def send(self, obj, cb):
        with self.lock:
            self.waiting[obj['id']] = cb
        self.p.stdin.write(json.dumps(obj) + '\n')
        self.p.stdin.flush()

    def close(self):
        try:
            self.p.stdin.close()
        except OSError:
            pass
        self.ended.wait(600)
        self.p.wait(60)


def peak_rss_gib(pid):
    try:
        out = subprocess.run(['ps', '-o', 'rss=', '-p', str(pid)], capture_output=True, text=True).stdout.strip()
        return int(out) / (1 << 20) if out else None
    except (OSError, ValueError):
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', required=True)
    ap.add_argument('--posts', required=True)
    ap.add_argument('--profile', choices=('r13', 'w16r2'), required=True)
    ap.add_argument('--bin', default=str(BIN))
    ap.add_argument('--identity', default=None)
    ap.add_argument('--lanes', type=int, default=6)
    ap.add_argument('--lane-threads', type=int, default=5)
    ap.add_argument('--check-lanes', type=int, default=3)
    ap.add_argument('--check-threads', type=int, default=4)
    ap.add_argument('--witness-gib', type=float, default=16)
    ap.add_argument('--keep', type=int, default=1, help='keep the receipts of the first N posts; delete the rest after their check')
    ap.add_argument('--gap', type=float, default=0.0)
    ap.add_argument('--writer-threads', type=int, default=4)
    ap.add_argument('--defer-check', action='store_true')
    a = ap.parse_args()
    os.umask(0o077)
    tag = a.tag
    out = R / f'stream_{tag}'
    out.mkdir(exist_ok=False)
    PRIV.mkdir(mode=0o700, exist_ok=True)
    PUB.mkdir(exist_ok=True)
    priv = PRIV / f'stream-{tag}'
    priv.mkdir(mode=0o700)
    pub = PUB / f'stream-{tag}'
    pub.mkdir()
    texts = json.loads(Path(a.posts).read_text())
    ids = encode(texts)
    env = dict(os.environ, ZK60_MODELS=str(REPO / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'),
               HL_PB_ORACLE='0', HL_GPU=os.environ.get('HL_GPU', '1'), HL_GPU_REQUIRED='0',
               HL_PB_TIMING=os.environ.get('HL_PB_TIMING', '0'), HL_OWNER_PRIVATE_DIR=str(priv / 'refusals'))
    pols = ','.join(POL.values())
    sw = [SWITCH] if a.profile == 'w16r2' else []
    t_boot = time.time()
    prover = Server([a.bin, 'serve', '--export', str(EXP), '--tables', str(VEXP / 'token_io'), '--policies', pols,
                     '--lanes', str(a.lanes), '--lane-threads', str(a.lane_threads), '--witness-cache-gib', str(a.witness_gib)] + sw,
                    str(out / 'prover.log'), env)
    prover.ready.wait(900)
    if not prover.start or prover.start.get('event') != 'serve-start':
        raise SystemExit(f'the prover refused to start: {prover.start}')
    # the verifier pins the identity it is given (the R13 one by default); for W16R2 the
    # identity the prover's startup reports, unless one is given (the verifier re-derives its own
    # from its export and refuses to start on a mismatch)
    identity = a.identity or (R13_IDENTITY if a.profile == 'r13' else prover.start['trained_statement_identity'])
    checker_argv = [a.bin, 'check-serve', '--export', str(VEXP), '--tables', str(VEXP / 'token_io'), '--policies', pols,
                    '--expect-statement', identity, '--min-bits', '95', '--lanes', str(a.check_lanes),
                    '--lane-threads', str(a.check_threads)] + sw
    checker = None

    def start_checker():
        c = Server(checker_argv, str(out / 'checker.log'), env)
        c.ready.wait(900)
        if not c.start or c.start.get('event') != 'serve-start':
            raise SystemExit(f'the verifier refused to start: {c.start}')
        return c

    if not a.defer_check:
        checker = start_checker()
    t_ready = time.time()
    records = []
    rec_lock = threading.Lock()
    posts_done = threading.Semaphore(0)
    proofs_done = threading.Semaphore(0)
    state = {}
    pending_checks = []

    def note(kind, **kw):
        with rec_lock:
            records.append({'kind': kind, 't': time.time(), **kw})

    def category_done(pi, cat, j, t):
        st = state[pi]
        note('check', post=pi, category=cat, status=j['status'], seconds=j.get('seconds'), verify_seconds=j.get('verify_seconds'),
             queued=j.get('queued_seconds'))
        with st['lock']:
            st['labels'][cat] = (j['status'], t)
            finished = len(st['labels']) == 3
        if finished:
            st['done'] = t
            if pi >= a.keep:
                shutil.rmtree(pub / f'p{pi}', ignore_errors=True)
            posts_done.release()

    def check_request(pi, cat):
        st = state[pi]
        return {'id': f'p{pi}-{cat}', 'policy': POL[cat], 'expect_total': len(ids[pi]), 'content_file': str(st['content']),
                'chunks': [{'artifact': str(pub / f'p{pi}' / f'{cat}-c{k}'), 'decommitment': str(priv / f'p{pi}' / f'{cat}-c{k}-owner' / 'input.dec')}
                           for k in range(len(st['chunks'][cat]))],
                'log': str(priv / f'p{pi}' / f'{cat}-check.log')}

    def proved(pi, cat, ci, j, t):
        st = state[pi]
        note('prove', post=pi, category=cat, chunk=ci, status=j['status'], seconds=j.get('seconds'), queued=j.get('queued_seconds'),
             lane=j.get('lane'))
        proofs_done.release()
        with st['lock']:
            st['chunks'][cat][ci] = j['status']
            st['last_proof'] = t
            complete = all(v is not None for v in st['chunks'][cat])
        if complete:
            if all(v == 'proved' for v in st['chunks'][cat]):
                if a.defer_check:
                    with rec_lock:
                        pending_checks.append((pi, cat))
                else:
                    note('check-submit', post=pi, category=cat)
                    checker.send(check_request(pi, cat), lambda j, t, pi=pi, cat=cat: category_done(pi, cat, j, t))
            else:
                category_done(pi, cat, {'status': 'prove-refused'}, time.time())

    t0 = time.time()
    n_proofs = 0
    for pi, post_ids in enumerate(ids):
        if a.gap and pi:
            time.sleep(a.gap)
        d = priv / f'p{pi}'
        d.mkdir(mode=0o700)
        (pub / f'p{pi}').mkdir()
        content = d / 'content.ids'
        private_write(content, (','.join(map(str, post_ids)) + '\n').encode())
        req = []
        chunks = {}
        for c, size in CATS.items():
            n = len(plan(len(post_ids), size))
            chunks[c] = [None] * n
            for i in range(n):
                req.append({'name': f'{c}-c{i}', 'policy_id': POL[c], 'content_file': str(content), 'chunk_index': i})
        private_write(d / 'act-request.json', json.dumps(req).encode())
        state[pi] = {'lock': threading.Lock(), 'chunks': chunks, 'labels': {}, 'content': content, 'submitted': time.time(), 'done': None,
                     'tokens': len(post_ids), 'proofs': len(req), 'last_proof': None}
        n_proofs += len(req)
        tw = time.time()
        w = subprocess.run(['/usr/bin/env', f'OPENBLAS_NUM_THREADS={a.writer_threads}', f'OMP_NUM_THREADS={a.writer_threads}',
                            f'VECLIB_MAXIMUM_THREADS={a.writer_threads}', PY, str(WRITER), '--request', str(d / 'act-request.json'),
                            '--out', str(d / 'act')], capture_output=True, text=True)
        note('writer', post=pi, rc=w.returncode, seconds=time.time() - tw, jobs=len(req))
        if w.returncode != 0:
            (out / f'writer-p{pi}.err').write_text(w.stderr[-4000:])
            raise SystemExit(f'writer failed for post {pi}')
        for c, size in CATS.items():
            for i in range(len(chunks[c])):
                prover.send({'id': f'p{pi}-{c}-c{i}', 'content_file': str(content), 'policy': POL[c], 'chunk': i,
                             'seq_dir': str(d / 'act' / f'{c}-c{i}'), 'out': str(pub / f'p{pi}' / f'{c}-c{i}'),
                             'owner_dir': str(d / f'{c}-c{i}-owner'), 'log': str(d / f'{c}-c{i}-prove.log')},
                            lambda j, t, pi=pi, c=c, i=i: proved(pi, c, i, j, t))
                note('prove-submit', post=pi, category=c, chunk=i)
    proof_clock = None
    if a.defer_check:
        for _ in range(n_proofs):
            proofs_done.acquire()
        t_proofs = time.time()
        proof_clock = {'wall_s': t_proofs - t0, 'category_proofs': n_proofs, 'proved_tok_per_s': 128 * n_proofs / (t_proofs - t0),
                       'per_post_last_proof_s': [state[pi]['last_proof'] - state[pi]['submitted'] for pi in range(len(ids))]}
        prover.close()
        t_cb = time.time()
        checker = start_checker()
        t_c0 = time.time()
        for pi, cat in sorted(pending_checks):
            note('check-submit', post=pi, category=cat)
            checker.send(check_request(pi, cat), lambda j, t, pi=pi, cat=cat: category_done(pi, cat, j, t))
        for _ in ids:
            posts_done.acquire()
        t_c1 = time.time()
        proof_clock['verifier'] = {'startup_s': t_c0 - t_cb, 'wall_s': t_c1 - t_c0, 'category_proofs': n_proofs,
                                   'verified_tok_per_s': 128 * n_proofs / (t_c1 - t_c0)}
        t_end = t_c1
    else:
        for _ in ids:
            posts_done.acquire()
        t_end = time.time()
        prover.close()
    checker.close()
    posts = []
    for pi in range(len(ids)):
        st = state[pi]
        ok = all(v[0] == 'checked' for v in st['labels'].values()) and len(st['labels']) == 3
        posts.append({'post': pi, 'tokens': st['tokens'], 'proofs': st['proofs'], 'all_checked': ok,
                      'latency_s': st['done'] - st['submitted'], 'done_at_s': st['done'] - t0})
    proofs = sum(p['proofs'] for p in posts if p['all_checked'])
    tokens = sum(p['tokens'] for p in posts if p['all_checked'])
    wall = t_end - t0
    steady = None
    if not a.defer_check and len(posts) >= 3:
        order = sorted(posts, key=lambda p: p['done_at_s'])
        k = len(order) // 2
        span = order[-1]['done_at_s'] - order[k - 1]['done_at_s']
        steady = {'from_post': k, 'span_s': span, 'proofs': sum(p['proofs'] for p in order[k:]),
                  'proved_tok_per_s': 128 * sum(p['proofs'] for p in order[k:]) / span if span > 0 else None}
    summary = {'tag': tag, 'profile': a.profile, 'binary': a.bin, 'posts': len(ids), 'all_checked': all(p['all_checked'] for p in posts),
               'wall_s': wall, 'startup_s': t_ready - t_boot, 'prover_start': prover.start, 'checker_start': checker.start,
               'identity_pinned_by_verifier': identity,
               'category_proofs': proofs, 'proved_tok_per_s': 128 * proofs / wall, 'content_tok_per_s': tokens / wall,
               'per_post': posts, 'steady': steady, 'deferred': proof_clock,
               'settings': vars(a), 'hl_gpu': env['HL_GPU'],
               'on_the_clock': ('PROOF-ONLY CLOCK (deferred check): from the first post submitted to the last proof written: activation writer, '
                                'the prover\'s sealing pass and witnesses, proof, receipt write; the verifier (fresh, its own process, every receipt) '
                                'runs after it on its own clock, standing for a second machine' if a.defer_check else
                                'ZK60_THROUGHPUT_TARGET clock: from the first post submitted to the last post\'s third label accepted: activation writer '
                                '(Python forward pass), the prover\'s sealing pass and witnesses, proof, receipt write (fsync per segment), fresh '
                                'verification in the separate verifier process, input-owner check, category label; NOT on it: server startup '
                                '(model load), app/publication')}
    (out / 'records.json').write_text(json.dumps(records, indent=1) + '\n')
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({k: summary[k] for k in ('profile', 'posts', 'all_checked', 'wall_s', 'category_proofs', 'proved_tok_per_s', 'content_tok_per_s', 'steady', 'deferred')}))


if __name__ == '__main__':
    main()
