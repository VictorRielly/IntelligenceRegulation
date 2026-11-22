#!/usr/bin/env python3
"""A36 T1 driver (one guarded gpu job runs this): legs of one resident `zk60_classify serve` (lanes 1, lane-threads 5)
at the W16R2 development profile on PUBLIC content, with HL_A36_CORE_AHEAD per leg; harness-style (A28's stream_driver.py:
the activation writer once, `serve` requests one at a time, `check-serve` for the fresh verification).

usage: t1_driver.py --out DIR --scratch DIR --legs 0,1,1,0 [--warm 1] [--timed 3] [--verify-on] [--verify-all]

DIR (public logs and the result json) is under the repo's results; SCRATCH (activations, receipts, owner dirs; large) is outside it.
Never touches the installed app's services or binary, and reads nothing owner-private. Content is public (results/zk60_a24_app_20261107/posts/one.json).
"""
import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO = Path('/Users/victorrielly/IntelligenceRegulation')
WT = Path(__file__).resolve().parents[2]
BIN = WT / 'ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify'
# the installed W16R2 app's prover export (apps/proven-media/proven_media/w16r2_runtime.py: EXPORT); its verifier export
# (PUBLIC_DIR/verifier-export-w16r2-94643880) is not on this disk, so the same directory serves the verifier (read-only)
EXP = Path('/Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1')
VEXP = EXP
PY = '/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python'
WRITER = REPO / 'results/zk60_astra_20261026/a3_mac_writer_20261105/write_item_activations.py'
TEKKEN = REPO / 'results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tekken.json'
POSTS = REPO / 'results/zk60_a24_app_20261107/posts/one.json'
MODELS = REPO / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'
SWITCH = '--dev-w16r2-public-content-only'
CATS = ['sexual', 'violence', 'hate']
POL = {c: f'shieldstral-1.0-3b-moderate-{c}/1' for c in CATS}
CAT = 'sexual'
# the installed app's settings for the W16R2 profile (apps/proven-media/deploy.json, shieldstral-mac-fast-w16r2.native_settings)
NATIVE = {'HL_METAL_QUEUES': 'thread', 'HL_METAL_SPIN_US': '200', 'HL_A28_STAGGER_MS': '300', 'HL_A26_KEPT': '1', 'HL_A30_B3PAR': '1',
          'HL_A26_VERIFY_ONCE': '0', 'HL_A28_SEAL_AHEAD': '0'}


class Server:
    def __init__(self, argv, log, env):
        self.p = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(str(log) + '.err', 'w'), text=True, bufsize=1, env=env)
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

    def request(self, obj, timeout=3600):
        done = threading.Event()
        box = {}

        def cb(j, t):
            box['j'], box['t'] = j, t
            done.set()
        with self.lock:
            self.waiting[obj['id']] = cb
        t0 = time.time()
        self.p.stdin.write(json.dumps(obj) + '\n')
        self.p.stdin.flush()
        if not done.wait(timeout):
            raise SystemExit(f'request {obj["id"]} timed out')
        return box['j'], box['t'] - t0

    def close(self):
        try:
            self.p.stdin.close()
        except OSError:
            pass
        self.ended.wait(600)
        self.p.wait(60)


def util():
    try:
        out = subprocess.run(['ioreg', '-r', '-d', '1', '-c', 'IOAccelerator'], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    key = '"Device Utilization %"='
    i = out.find(key)
    if i < 0:
        return None
    j = i + len(key)
    k = j
    while k < len(out) and out[k].isdigit():
        k += 1
    return int(out[j:k]) if k > j else None


def sampler(samples, stop, period=2.0):
    def run():
        while not stop.is_set():
            u = util()
            if u is not None:
                samples.append((time.time(), u))
            stop.wait(period)
    threading.Thread(target=run, daemon=True).start()


def events_of(j):
    """the request's event lines: from its own log file (the request names one), else the served line's"""
    ev = []
    lp = j.get('log')
    if lp and Path(lp).exists():
        lines = Path(lp).read_text(errors='replace').splitlines()
    else:
        lines = j.get('events') if isinstance(j.get('events'), list) else []
    for line in lines:
        if line.startswith('{'):
            try:
                ev.append(json.loads(line))
            except ValueError:
                pass
    return ev


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--scratch', required=True)
    ap.add_argument('--legs', required=True)
    ap.add_argument('--warm', type=int, default=1)
    ap.add_argument('--timed', type=int, default=3)
    ap.add_argument('--verify-on', action='store_true')
    ap.add_argument('--verify-all', action='store_true')
    a = ap.parse_args()
    os.umask(0o077)
    out, scr = Path(a.out), Path(a.scratch)
    out.mkdir(parents=True, exist_ok=True)
    scr.mkdir(parents=True, exist_ok=True)
    legs = [int(x) for x in a.legs.split(',')]
    # the public content: the same text every request; the tokenizer and the writer as the stream driver uses them
    sys.path.insert(0, str(REPO / 'apps/proven-media'))
    os.environ['PM_SHIELDSTRAL_TOKENIZER'] = str(TEKKEN)
    from proven_media.shieldstral_text import ShieldstralTextEncoder
    ids = ShieldstralTextEncoder(TEKKEN).content_ids(json.loads(POSTS.read_text())[0])
    content = scr / 'content.ids'
    content.write_text(','.join(map(str, ids)) + '\n')
    req = [{'name': f'{CAT}-c0', 'policy_id': POL[CAT], 'content_file': str(content), 'chunk_index': 0}]
    (scr / 'act-request.json').write_text(json.dumps(req))
    # the activations for export_u1 come from Astra's parameterized resident writer, run here as my OWN writer process through her
    # client (as the coordinator's batch-2 harness does for W16R2); it is closed before any server starts (not on the timed clock)
    t = time.time()
    sys.path.insert(0, str(REPO / 'results/zk60_astra_20261026/w16r2_resident_app_candidate_20261112'))
    from client import Pool
    from export_selection import UNIFORM
    wlog = out / 'writer'
    wlog.mkdir(exist_ok=True)
    pool = Pool(PY, scr, wlog, count=1, export=UNIFORM)
    try:
        pool.write(scr / 'act-request.json', scr / 'act')
    finally:
        pool.close()
    seq = scr / 'act' / f'{CAT}-c0'
    print(f'writer {time.time() - t:.1f} s, content tokens {len(ids)}', flush=True)
    pols = ','.join(POL.values())
    result = {'content_tokens': len(ids), 'binary': str(BIN), 'legs': []}
    for li, sw in enumerate(legs):
        (scr / f'leg{li}-refusals').mkdir(mode=0o700, exist_ok=True)
        env = dict(os.environ, ZK60_MODELS=str(MODELS), HL_PB_ORACLE='0', HL_GPU='1', HL_GPU_REQUIRED='0', HL_PB_TIMING='0',
                   HL_OWNER_PRIVATE_DIR=str(scr / f'leg{li}-refusals'), HL_A36_CORE_AHEAD=str(sw), **NATIVE)
        argv = [str(BIN), 'serve', '--export', str(EXP), '--tables', str(VEXP / 'token_io'), '--policies', pols, '--label', 'zk60-classify-verdict',
                '--lanes', '1', '--lane-threads', '5', '--witness-cache-gib', '16', SWITCH]
        leg = {'leg': li + 1, 'A36': sw, 'argv': argv, 'requests': []}
        pre = subprocess.run(['pgrep', '-fl', 'ds4-bench'], capture_output=True, text=True).stdout
        leg['ds4_bench_before'] = pre or '(none)'
        leg['gpu_util_before'] = util()
        samples, stop = [], threading.Event()
        t_boot = time.time()
        srv = Server(argv, out / f'leg{li + 1}_A36-{sw}.prover.log', env)
        srv.ready.wait(900)
        if not srv.start or srv.start.get('event') != 'serve-start':
            raise SystemExit(f'the prover refused to start: {srv.start}')
        leg['startup_s'] = time.time() - t_boot
        leg['serve_start'] = srv.start
        sampler(samples, stop)
        for r in range(a.warm + a.timed):
            rid = f'l{li + 1}-r{r}'
            o = scr / 'pub' / f'leg{li + 1}' / f'r{r}'
            po = scr / 'priv' / f'leg{li + 1}'
            o.parent.mkdir(parents=True, exist_ok=True)
            po.mkdir(parents=True, exist_ok=True)
            j, wall = srv.request({'id': rid, 'content_file': str(content), 'policy': POL[CAT], 'chunk': 0, 'seq_dir': str(seq), 'out': str(o),
                                   'owner_dir': str(po / f'r{r}-owner'), 'log': str(po / f'r{r}-prove.log')})
            ev = events_of(j)
            if j.get('log') and Path(j['log']).exists():
                shutil.copy(j['log'], out / f'leg{li + 1}_{rid}.request.log')
            proved = next((e for e in ev if isinstance(e, dict) and e.get('event') == 'proved'), None)
            segs = [e.get('elapsed_seconds') for e in ev if isinstance(e, dict) and e.get('event') == 'segment']
            rec = {'id': rid, 'warmup': r < a.warm, 'status': j.get('status'), 'wall_s': wall, 'served_seconds': j.get('seconds'), 'queued_seconds': j.get('queued_seconds'),
                   'prove_seconds': proved.get('prove_seconds') if proved else None, 'total_seconds': proved.get('total_seconds') if proved else None,
                   'receipt_bytes': proved.get('receipt_bytes') if proved else None, 'segment_elapsed': segs, 'out': str(o)}
            leg['requests'].append(rec)
            print(json.dumps({k: rec[k] for k in ('id', 'status', 'wall_s', 'prove_seconds', 'total_seconds')}), flush=True)
            if j.get('status') != 'proved':
                (out / f'leg{li + 1}_{rid}.served.json').write_text(json.dumps(j, indent=1))
        stop.set()
        srv.close()
        leg['gpu_util_samples'] = [[round(t, 1), u] for t, u in samples]
        timed = [r['prove_seconds'] for r in leg['requests'] if not r['warmup'] and r['prove_seconds'] is not None]
        leg['timed_prove_seconds'] = timed
        leg['median_prove_seconds'] = statistics.median(timed) if len(timed) == a.timed else None
        walls = [r['wall_s'] for r in leg['requests'] if not r['warmup']]
        leg['median_wall_s'] = statistics.median(walls) if walls else None
        leg['ds4_bench_after'] = subprocess.run(['pgrep', '-fl', 'ds4-bench'], capture_output=True, text=True).stdout or '(none)'
        result['legs'].append(leg)
        (out / 't1_results.json').write_text(json.dumps(result, indent=1))
        # fresh verification by the unchanged verifier (check-serve), after the leg's timed window, receipts kept until checked
        if (sw and a.verify_on) or a.verify_all:
            ident = srv.start['trained_statement_identity']
            cenv = dict(env)
            cargv = [str(BIN), 'check-serve', '--export', str(VEXP), '--tables', str(VEXP / 'token_io'), '--policies', pols, '--label', 'zk60-classify-verdict',
                     '--expect-statement', ident, '--min-bits', '95', '--lanes', '1', '--lane-threads', '4', SWITCH]
            chk = Server(cargv, out / f'leg{li + 1}_A36-{sw}.checker.log', cenv)
            chk.ready.wait(900)
            if not chk.start or chk.start.get('event') != 'serve-start':
                raise SystemExit(f'the verifier refused to start: {chk.start}')
            leg['verified'] = []
            for rec in leg['requests']:
                if rec['status'] != 'proved':
                    leg['verified'].append({'id': rec['id'], 'status': 'not-proved'})
                    continue
                o = Path(rec['out'])
                jv, wv = chk.request({'id': 'v-' + rec['id'], 'policy': POL[CAT], 'expect_total': len(ids), 'content_file': str(content),
                                      'chunks': [{'artifact': str(o), 'decommitment': str(scr / 'priv' / f'leg{li + 1}' / (o.name + '-owner') / 'input.dec')}],
                                      'log': str(scr / 'priv' / f'leg{li + 1}' / f'{rec["id"]}-check.log')})
                leg['verified'].append({'id': rec['id'], 'status': jv.get('status'), 'verify_seconds': jv.get('verify_seconds'), 'wall_s': wv})
                print(json.dumps(leg['verified'][-1]), flush=True)
            chk.close()
            (out / 't1_results.json').write_text(json.dumps(result, indent=1))
        shutil.rmtree(scr / 'pub' / f'leg{li + 1}', ignore_errors=True)
        shutil.rmtree(scr / 'priv' / f'leg{li + 1}', ignore_errors=True)
    med = [l['median_prove_seconds'] for l in result['legs']]
    result['medians'] = med
    if len(med) == 4 and all(m is not None for m in med):
        result['ratio_pair1_on_over_off'] = med[1] / med[0]
        result['ratio_pair2_on_over_off'] = med[2] / med[3]
    (out / 't1_results.json').write_text(json.dumps(result, indent=1))
    print(json.dumps({k: result.get(k) for k in ('medians', 'ratio_pair1_on_over_off', 'ratio_pair2_on_over_off')}), flush=True)


if __name__ == '__main__':
    main()
