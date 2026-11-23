#!/usr/bin/env python3
"""Host-fast test driver (the driver of results/zk60_scchain_app_20261123 with other arms; one guarded gpu job per SET).
Arms: A = B0 (the pushed head) with HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1 HL_METAL_SC_CHAIN_FAST=1; B = B1 (agy/host-g5g4g6) with the same three and the new switch unset;
C = B1 with the same three plus HL_HOST_FAST=1. Every switch in SWITCHES is removed from the driver's own
environment first, so unset means unset. Receipts of B1 (arms B and C) are checked by B0's check-serve; arm A's are deleted unverified.
The rest is the earlier text: A36 T2 driver (one guarded gpu job per SET). The T1 fixture (t1_driver.py's paths, settings, writer and request kind) as a CONTINUOUS STREAM:
one leg = one fresh resident `zk60_classify serve --lanes L --lane-threads T` launch; N + 48 requests (N = L) over the eight public posts in
rotation (results/zk60_a24_app_20261107/posts/stream8.json, category sexual, chunk 0), ALL written to the server's stdin at once, the way the A28
stream driver feeds a server, so every lane has a request waiting from the first to the last (the server's reader hands a request to the next idle
lane). Completion times come from ONE clock (time.monotonic at the driver when the `served` line is read). After the stream ends and the server
is closed, an ON leg's receipts are checked by `check-serve` (the binary's own fresh verification) and each receipt is deleted after its check;
an OFF leg's receipts are deleted unverified. Deleting is done here, only inside the leg's own directory under --scratch.

usage: hostfast_driver.py --out DIR --scratch DIR --spec ARM:LANES:THREADS:TIMED[,...] --bin0 B0 --bin1 B1 --trace-prefix P
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

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'zk60_a36_core_ahead_20261121'))
import t1_driver as t1  # noqa: E402

POSTS8 = t1.REPO / 'results/zk60_a24_app_20261107/posts/stream8.json'
MIN_FREE_GB = 80
SWITCHES = ('HL_METAL_FUSED_RS', 'HL_METAL_SPARSE_FOLD', 'HL_METAL_SPARSE_FOLD_REG8', 'HL_METAL_OPEN_FAST', 'HL_METAL_OPEN_SKIP_TABLES',
            'HL_METAL_OPEN_HOST_GATHER', 'HL_METAL_SC_CHAIN_FAST', 'HL_HOST_FAST', 'HL_A36_CORE_AHEAD')
BASE = {'HL_METAL_FUSED_RS': '1', 'HL_METAL_SPARSE_FOLD': '1', 'HL_METAL_SC_CHAIN_FAST': '1'}


def free_gb(path):
    st = os.statvfs(path)
    return st.f_bavail * st.f_frsize / 1e9


def safe_rmtree(p, root):
    p, root = Path(p).resolve(), Path(root).resolve()
    if root not in p.parents and p != root:
        raise SystemExit(f'refusing to delete outside the leg directory: {p}')
    shutil.rmtree(p, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--scratch', required=True)
    ap.add_argument('--spec', required=True, help='legs: ARM:LANES:THREADS:TIMED separated by commas (ARM = A, B or C), e.g. A:6:5:48,B:6:5:48,C:6:5:48')
    ap.add_argument('--trace-prefix', required=True)
    ap.add_argument('--bin0', required=True, help='B0: the pushed head (arm A; also the verifier for every receipt of B1)')
    ap.add_argument('--bin1', required=True, help='B1: the host-fast binary (arms B and C)')
    ap.add_argument('--leg-offset', type=int, default=0, help='leg numbers start after this')
    ap.add_argument('--smoke-verify', type=int, default=0, help='verify the first K completed receipts of an OFF leg too (smoke only)')
    ap.add_argument('--check-lanes', type=int, default=3)
    ap.add_argument('--check-threads', type=int, default=4)
    a = ap.parse_args()
    BIN0, BIN1 = Path(a.bin0), Path(a.bin1)
    ARMS = {'A': (BIN0, dict(BASE)), 'B': (BIN1, dict(BASE)), 'C': (BIN1, dict(BASE, HL_HOST_FAST='1'))}
    for k in SWITCHES:
        os.environ.pop(k, None)
    os.umask(0o077)
    out, scr = Path(a.out), Path(a.scratch)
    out.mkdir(parents=True, exist_ok=True)
    scr.mkdir(parents=True, exist_ok=True)
    specs = [tuple(x.split(':')) for x in a.spec.split(',')]
    # the eight public posts, tokenized as the stream driver does; the activations by Astra's writer client (my own process, closed before any server)
    sys.path.insert(0, str(t1.REPO / 'apps/proven-media'))
    os.environ['PM_SHIELDSTRAL_TOKENIZER'] = str(t1.TEKKEN)
    from proven_media.shieldstral_text import ShieldstralTextEncoder
    texts = json.loads(POSTS8.read_text())
    enc = ShieldstralTextEncoder(t1.TEKKEN)
    ids = [enc.content_ids(x) for x in texts]
    assert len(ids) == 8, len(ids)
    contents = []
    req = []
    for i, x in enumerate(ids):
        c = scr / f'content{i}.ids'
        c.write_text(','.join(map(str, x)) + '\n')
        contents.append(c)
        req.append({'name': f'p{i}', 'policy_id': t1.POL[t1.CAT], 'content_file': str(c), 'chunk_index': 0})
    (scr / 'act-request.json').write_text(json.dumps(req))
    t0 = time.time()
    sys.path.insert(0, str(t1.REPO / 'results/zk60_astra_20261026/w16r2_resident_app_candidate_20261112'))
    from client import Pool
    from export_selection import UNIFORM
    wlog = out / 'writer'
    wlog.mkdir(exist_ok=True)
    pool = Pool(t1.PY, scr, wlog, count=1, export=UNIFORM)
    try:
        pool.write(scr / 'act-request.json', scr / 'act')
    finally:
        pool.close()
    print(f'writer {time.time() - t0:.1f} s; posts {len(ids)}; content ids per post {[len(x) for x in ids]}', flush=True)
    pols = ','.join(t1.POL.values())
    result = {'binary_B0': str(BIN0), 'binary_B1': str(BIN1), 'spec': a.spec, 'content_ids': [len(x) for x in ids], 'legs': []}
    for li, (arm, lanes_s, threads_s, timed_s) in enumerate(specs):
        lanes, threads, timed = int(lanes_s), int(threads_s), int(timed_s)
        queues = 'thread'
        sw = 0 if arm == 'A' else 1  # every receipt of B1 (arms B and C) is verified; arm A is not
        t1.BIN = ARMS[arm][0]
        N = lanes
        total = N + timed
        leg_no = li + 1 + a.leg_offset
        legdir = scr / f'leg{leg_no}'
        free = free_gb(scr)
        if free < MIN_FREE_GB:
            raise SystemExit(f'STOP: only {free:.0f} GB free before leg {leg_no} (limit {MIN_FREE_GB})')
        (scr / f'leg{li}-refusals').mkdir(mode=0o700, exist_ok=True)
        env = dict(os.environ, ZK60_MODELS=str(t1.MODELS), HL_PB_ORACLE='0', HL_GPU='1', HL_GPU_REQUIRED='0', HL_PB_TIMING='0',
                   HL_OWNER_PRIVATE_DIR=str(scr / f'leg{li}-refusals'), **ARMS[arm][1], **dict(t1.NATIVE, HL_METAL_QUEUES=queues), **({'HL_A27_GPU_TRACE': f'{a.trace_prefix}_leg{leg_no}'} if a.trace_prefix else {}))
        argv = [str(t1.BIN), 'serve', '--export', str(t1.EXP), '--tables', str(t1.VEXP / 'token_io'), '--policies', pols, '--label', 'zk60-classify-verdict',
                '--lanes', str(lanes), '--lane-threads', str(threads), '--witness-cache-gib', '16', t1.SWITCH]
        leg = {'leg': leg_no, 'arm': arm, 'binary': str(ARMS[arm][0]), 'arm_env': ARMS[arm][1], 'verified_by_B0': bool(sw), 'lanes': lanes, 'threads': threads, 'queues': queues, 'N': N, 'timed': timed, 'trace_prefix': (f'{a.trace_prefix}_leg{leg_no}' if a.trace_prefix else None), 'argv': argv, 'free_gb_before': round(free, 1)}
        leg['ds4_bench_before'] = subprocess.run(['pgrep', '-fl', 'ds4-bench'], capture_output=True, text=True).stdout.strip() or '(none)'
        st = subprocess.run([sys.executable, '-B', '/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py', 'status'], capture_output=True, text=True).stdout
        (out / f'guard_status_leg{leg_no}_arm{arm}.txt').write_text(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()) + '\n' + st)
        leg['utc_start'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        t_boot = time.time()
        srv = t1.Server(argv, out / f'leg{leg_no}_arm{arm}.prover.log', env)
        srv.ready.wait(900)
        if not srv.start or srv.start.get('event') != 'serve-start':
            raise SystemExit(f'the prover refused to start: {srv.start}')
        leg['startup_s'] = time.time() - t_boot
        leg['serve_start'] = {k: srv.start.get(k) for k in ('gpu', 'lanes', 'lane_threads', 'trained_statement_identity', 'startup_seconds')}
        (legdir / 'pub').mkdir(parents=True, exist_ok=True)
        (legdir / 'priv').mkdir(parents=True, exist_ok=True)
        done = []
        lock = threading.Lock()
        all_done = threading.Event()
        samples, stop = [], threading.Event()
        t1.sampler(samples, stop)

        def make_cb(q):
            def cb(j, _t):
                tm = time.monotonic()
                with lock:
                    done.append((tm, q, j))
                    if len(done) == total:
                        all_done.set()
            return cb

        t_send = time.monotonic()
        leg['t_send_abs'] = t_send
        leg['server_pid'] = srv.p.pid
        for q in range(total):
            rid = f'l{leg_no}-q{q}'
            post = q % 8
            o = legdir / 'pub' / f'q{q}'
            po = legdir / 'priv'
            obj = {'id': rid, 'content_file': str(contents[post]), 'policy': t1.POL[t1.CAT], 'chunk': 0, 'seq_dir': str(scr / 'act' / f'p{post}'), 'out': str(o),
                   'owner_dir': str(po / f'q{q}-owner'), 'log': str(po / f'q{q}-prove.log')}
            with srv.lock:
                srv.waiting[rid] = make_cb(q)
            srv.p.stdin.write(json.dumps(obj) + '\n')
        srv.p.stdin.flush()
        if not all_done.wait(5400):
            raise SystemExit('the stream did not finish')
        stop.set()
        srv.close()
        leg['server_exit'] = srv.p.returncode
        done.sort(key=lambda x: x[0])
        recs = []
        for idx, (tm, q, j) in enumerate(done, 1):
            ev = t1.events_of(j)
            proved = next((e for e in ev if e.get('event') == 'proved'), None)
            recs.append({'n': idx, 'q': q, 'post': q % 8, 'lane': j.get('lane'), 'status': j.get('status'), 't_s': tm - t_send, 't_abs': tm, 'queued_s': j.get('queued_seconds'),
                         'served_s': j.get('seconds'), 'prove_s': proved.get('prove_seconds') if proved else None,
                         'receipt_bytes': proved.get('receipt_bytes') if proved else None})
        leg['completions'] = recs
        leg['gpu_util_mean'] = round(sum(u for _, u in samples) / len(samples), 1) if samples else None
        leg['ds4_bench_after'] = subprocess.run(['pgrep', '-fl', 'ds4-bench'], capture_output=True, text=True).stdout.strip() or '(none)'
        c = [r['t_s'] for r in recs]
        leg['rate'] = timed * 128 / (c[N + timed - 1] - c[N - 1]) if len(c) >= total else None
        leg['all_proved'] = all(r['status'] == 'proved' for r in recs)
        result['legs'].append(leg)
        (out / 't2_results.json').write_text(json.dumps(result, indent=1))
        leg['utc_end'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        print(json.dumps({'leg': leg_no, 'arm': arm, 'rate': leg['rate'], 'all_proved': leg['all_proved'], 'span_s': c[-1]}), flush=True)
        # verification: ON legs, every receipt, by check-serve, each deleted after its check (outside the timed window); OFF legs: deleted unverified
        verify = [r for r in recs if r['status'] == 'proved'] if sw else []  # ON legs: every receipt by check-serve, each deleted after its check
        if verify:
            ident = srv.start['trained_statement_identity']
            t1.BIN = BIN0
            cargv = [str(BIN0), 'check-serve', '--export', str(t1.VEXP), '--tables', str(t1.VEXP / 'token_io'), '--policies', pols, '--label', 'zk60-classify-verdict',
                     '--expect-statement', ident, '--min-bits', '95', '--lanes', str(a.check_lanes), '--lane-threads', str(a.check_threads), t1.SWITCH]
            chk = t1.Server(cargv, out / f'leg{leg_no}_arm{arm}.checker.log', {k: v for k, v in env.items() if k not in SWITCHES})
            chk.ready.wait(900)
            if not chk.start or chk.start.get('event') != 'serve-start':
                raise SystemExit(f'the verifier refused to start: {chk.start}')
            vres = []
            vdone = threading.Event()

            def vcb_for(r):
                def cb(jv, _t):
                    vres.append({'n': r['n'], 'q': r['q'], 'status': jv.get('status'), 'verify_seconds': jv.get('verify_seconds')})
                    safe_rmtree(legdir / 'pub' / f'q{r["q"]}', legdir)
                    safe_rmtree(legdir / 'priv' / f'q{r["q"]}-owner', legdir)
                    if len(vres) == len(verify):
                        vdone.set()
                return cb
            for r in verify:
                rid = f'v-l{leg_no}-q{r["q"]}'
                with chk.lock:
                    chk.waiting[rid] = vcb_for(r)
                chk.p.stdin.write(json.dumps({'id': rid, 'policy': t1.POL[t1.CAT], 'expect_total': len(ids[r['post']]), 'content_file': str(contents[r['post']]),
                                              'chunks': [{'artifact': str(legdir / 'pub' / f'q{r["q"]}'), 'decommitment': str(legdir / 'priv' / f'q{r["q"]}-owner' / 'input.dec')}],
                                              'log': str(legdir / 'priv' / f'q{r["q"]}-check.log')}) + '\n')
            chk.p.stdin.flush()
            if not vdone.wait(3600):
                raise SystemExit('the verification did not finish')
            chk.close()
            leg['verified'] = sorted(vres, key=lambda v: v['n'])
            leg['verify_summary'] = {'receipts': len(verify), 'checked': sum(v['status'] == 'checked' for v in vres), 'other': sum(v['status'] != 'checked' for v in vres)}
            print(json.dumps({'leg': leg_no, 'verify': leg['verify_summary']}), flush=True)
        else:
            leg['verify_summary'] = {'receipts': 0, 'note': 'off leg: receipts deleted unverified'}
        safe_rmtree(legdir, scr)
        (out / 't2_results.json').write_text(json.dumps(result, indent=1))
    print('done', flush=True)


if __name__ == '__main__':
    main()
