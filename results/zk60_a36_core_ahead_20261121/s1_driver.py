#!/usr/bin/env python3
"""A36 S1 driver (one guarded gpu job): the T1 fixture exactly (t1_driver.py's paths, settings, writer and request), ONE server launch with
HL_A36_CORE_AHEAD=0 and HL_PB_TIMING=1, one warm-up request and N timed requests, one at a time. The server prints the phase tables
(`PB-TIMING ...`, `PB-CLI ...`) on its stdout; the lane is one, so the lines between a request's send and its `served` line are that request's.
They are written to OUT/rK.timing.txt (K = 0 the warm-up). This is a reading, not a speed test.

usage: s1_driver.py --out DIR --scratch DIR [--warm 1] [--timed 3]
"""
import argparse
import json
import os
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import t1_driver as t1  # noqa: E402


class TimedServer(t1.Server):
    """t1_driver.Server that also keeps every non-JSON stdout line (the phase tables), in order"""

    def __init__(self, argv, log, env):
        self.extra = []
        self.extra_lock = threading.Lock()
        super().__init__(argv, log, env)

    def _read(self):
        # same as the parent's reader, plus: keep the non-JSON lines
        for line in self.p.stdout:
            self.log.write(line)
            self.log.flush()
            if not line.startswith('{'):
                with self.extra_lock:
                    self.extra.append(line)
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--scratch', required=True)
    ap.add_argument('--warm', type=int, default=1)
    ap.add_argument('--timed', type=int, default=3)
    a = ap.parse_args()
    os.umask(0o077)
    out, scr = Path(a.out), Path(a.scratch)
    out.mkdir(parents=True, exist_ok=True)
    scr.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(t1.REPO / 'apps/proven-media'))
    os.environ['PM_SHIELDSTRAL_TOKENIZER'] = str(t1.TEKKEN)
    from proven_media.shieldstral_text import ShieldstralTextEncoder
    ids = ShieldstralTextEncoder(t1.TEKKEN).content_ids(json.loads(t1.POSTS.read_text())[0])
    content = scr / 'content.ids'
    content.write_text(','.join(map(str, ids)) + '\n')
    (scr / 'act-request.json').write_text(json.dumps([{'name': f'{t1.CAT}-c0', 'policy_id': t1.POL[t1.CAT], 'content_file': str(content), 'chunk_index': 0}]))
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
    seq = scr / 'act' / f'{t1.CAT}-c0'
    pols = ','.join(t1.POL.values())
    (scr / 'refusals').mkdir(mode=0o700, exist_ok=True)
    env = dict(os.environ, ZK60_MODELS=str(t1.MODELS), HL_PB_ORACLE='0', HL_GPU='1', HL_GPU_REQUIRED='0', HL_PB_TIMING='1',
               HL_OWNER_PRIVATE_DIR=str(scr / 'refusals'), HL_A36_CORE_AHEAD='0', **t1.NATIVE)
    argv = [str(t1.BIN), 'serve', '--export', str(t1.EXP), '--tables', str(t1.VEXP / 'token_io'), '--policies', pols, '--label', 'zk60-classify-verdict',
            '--lanes', '1', '--lane-threads', '5', '--witness-cache-gib', '16', t1.SWITCH]
    srv = TimedServer(argv, out / 's1.prover.log', env)
    srv.ready.wait(900)
    if not srv.start or srv.start.get('event') != 'serve-start':
        raise SystemExit(f'the prover refused to start: {srv.start}')
    summary = {'argv': argv, 'env_added': {'HL_PB_TIMING': '1', 'HL_A36_CORE_AHEAD': '0', **t1.NATIVE}, 'requests': []}
    for r in range(a.warm + a.timed):
        rid = f's1-r{r}'
        o = scr / 'pub' / f'r{r}'
        po = scr / 'priv'
        o.parent.mkdir(parents=True, exist_ok=True)
        po.mkdir(parents=True, exist_ok=True)
        with srv.extra_lock:
            n0 = len(srv.extra)
        j, wall = srv.request({'id': rid, 'content_file': str(content), 'policy': t1.POL[t1.CAT], 'chunk': 0, 'seq_dir': str(seq), 'out': str(o),
                               'owner_dir': str(po / f'r{r}-owner'), 'log': str(po / f'r{r}-prove.log')})
        time.sleep(0.5)  # the reader thread may still hold the last stdout lines
        with srv.extra_lock:
            lines = srv.extra[n0:]
        (out / f'r{r}.timing.txt').write_text(''.join(lines))
        ev = t1.events_of(j)
        proved = next((e for e in ev if e.get('event') == 'proved'), None)
        rec = {'id': rid, 'warmup': r < a.warm, 'status': j.get('status'), 'wall_s': wall, 'prove_seconds': proved.get('prove_seconds') if proved else None, 'timing_lines': len(lines)}
        summary['requests'].append(rec)
        print(json.dumps(rec), flush=True)
    srv.close()
    (out / 's1_driver_result.json').write_text(json.dumps(summary, indent=1))


if __name__ == '__main__':
    main()
