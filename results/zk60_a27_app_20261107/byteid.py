#!/usr/bin/env python3
"""Lane A27 (from A26): RECEIPT BYTE IDENTITY on the real Shieldstral export under FIXED TEST ENTROPY (macOS).

A24 could not run the fixed-entropy byte comparison (`r18/tools/run_fixed.sh` needs bubblewrap).
Here every prover process runs with `fixed_entropy.c`'s interposer (DYLD_INSERT_LIBRARIES): each
`ZkRng::from_os` reads the same public 32 bytes. One public post, the activation writer run ONCE,
then for each binary in `--order` (e.g. A,B,A: the repeat is the harness's own determinism
control) the prover server proves the post's three categories into its own directories. Every
receipt file (28 segments, the unverified statement, and the owner decommitment by hash only) is
SHA-256'd and compared across the runs. Then each binary's verifier server checks the OTHER
binary's receipts (cross-verification: verify + input-owner + label).

PUBLIC CONTENT ONLY: under fixed entropy the receipts hide nothing. Nothing private is printed:
the decommitment and the activations stay in the owner-only directory; only hashes are compared
and only whether they are equal is written to the public summary.

usage: byteid.py --tag T --posts FILE --bin A=PATH --bin B=PATH --order A,B,A [--lanes 3 --lane-threads 10]
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stream_driver as sd  # noqa: E402

DYLIB = Path('/Users/victorrielly/zk60-artifacts/a26-tools/a26_fixed_entropy.dylib')
FIXED = sd.PRIV / 'fixed_entropy.bin'


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            b = f.read(1 << 24)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def receipt_hashes(art, owner):
    files = {}
    for p in sorted(Path(art).iterdir()):
        if p.is_file():
            files[p.name] = sha(p)
    st = Path(str(art) + '.unverified-statement')
    if (st / 'statement.json').is_file():
        files['.unverified-statement/statement.json'] = sha(st / 'statement.json')
    dec = Path(owner) / 'input.dec'
    if dec.is_file():
        files['owner input.dec (hash compared only)'] = sha(dec)
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', required=True)
    ap.add_argument('--posts', required=True)
    ap.add_argument('--bin', action='append', required=True, help='LABEL=PATH')
    ap.add_argument('--order', required=True)
    ap.add_argument('--env', action='append', default=[], help='LABEL:K=V (that label\'s prover and verifier only)')
    ap.add_argument('--lanes', type=int, default=3)
    ap.add_argument('--lane-threads', type=int, default=10)
    ap.add_argument('--check-lanes', type=int, default=3)
    ap.add_argument('--check-threads', type=int, default=4)
    a = ap.parse_args()
    os.umask(0o077)
    bins = dict(b.split('=', 1) for b in a.bin)
    extra = {}
    for e in a.env:
        label, kv = e.split(':', 1)
        k, v = kv.split('=', 1)
        extra.setdefault(label, {})[k] = v
    order = a.order.split(',')
    out = sd.R / f'byteid_{a.tag}'
    out.mkdir(exist_ok=False)
    priv = sd.PRIV / f'byteid-{a.tag}'
    priv.mkdir(mode=0o700, parents=True)
    pub = sd.PUB / f'byteid-{a.tag}'
    pub.mkdir(parents=True)
    texts = json.loads(Path(a.posts).read_text())
    ids = sd.encode(texts)[0]
    content = priv / 'content.ids'
    sd.private_write(content, (','.join(map(str, ids)) + '\n').encode())
    req = []
    for c, size in sd.CATS.items():
        assert len(sd.plan(len(ids), size)) == 1, 'one chunk per category (a short public post)'
        req.append({'name': f'{c}-c0', 'policy_id': sd.POL[c], 'content_file': str(content), 'chunk_index': 0})
    sd.private_write(priv / 'act-request.json', json.dumps(req).encode())
    w = subprocess.run(['/usr/bin/env', 'OPENBLAS_NUM_THREADS=4', 'OMP_NUM_THREADS=4', 'VECLIB_MAXIMUM_THREADS=4', sd.PY, str(sd.WRITER),
                        '--request', str(priv / 'act-request.json'), '--out', str(priv / 'act')], capture_output=True, text=True)
    if w.returncode != 0:
        raise SystemExit('the writer failed')
    base_env = dict(os.environ, ZK60_MODELS=str(sd.REPO / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'),
                    HL_PB_ORACLE='0', HL_GPU='1', HL_GPU_REQUIRED='0', HL_PB_TIMING='0', HL_OWNER_PRIVATE_DIR=str(priv / 'refusals'))
    fixed_env = dict(base_env, DYLD_INSERT_LIBRARIES=str(DYLIB), A26_FIXED_ENTROPY_FILE=str(FIXED))
    pols = ','.join(sd.POL.values())
    runs = []
    for i, label in enumerate(order):
        run = f'{i}-{label}'
        (pub / run).mkdir()
        (priv / run).mkdir(mode=0o700)
        prover = sd.Server([bins[label], 'serve', '--export', str(sd.EXP), '--tables', str(sd.VEXP / 'token_io'), '--policies', pols,
                            '--lanes', str(a.lanes), '--lane-threads', str(a.lane_threads), '--witness-cache-gib', '16'],
                           str(out / f'prover_{run}.log'), dict(fixed_env, **extra.get(label, {})))
        prover.ready.wait(900)
        if not prover.start or prover.start.get('event') != 'serve-start':
            raise SystemExit(f'prover {run} refused to start')
        done = threading.Semaphore(0)
        status = {}
        for c in sd.CATS:
            def cb(j, t, c=c):
                status[c] = j['status']
                done.release()
            prover.send({'id': f'{run}-{c}', 'content_file': str(content), 'policy': sd.POL[c], 'chunk': 0,
                         'seq_dir': str(priv / 'act' / f'{c}-c0'), 'out': str(pub / run / f'{c}-c0'),
                         'owner_dir': str(priv / run / f'{c}-c0-owner'), 'log': str(priv / run / f'{c}-c0-prove.log')}, cb)
        for _ in sd.CATS:
            done.acquire()
        prover.close()
        hashes = {c: receipt_hashes(pub / run / f'{c}-c0', priv / run / f'{c}-c0-owner') for c in sd.CATS}
        runs.append({'run': run, 'binary': label, 'status': status, 'hashes': hashes})
    # comparisons: every run against the first (equal or not, file by file)
    first = runs[0]
    comparisons = []
    for r in runs[1:]:
        per = {}
        for c in sd.CATS:
            fa, fb = first['hashes'][c], r['hashes'][c]
            names = sorted(set(fa) | set(fb))
            per[c] = {'files': len(names), 'equal': sum(1 for n in names if fa.get(n) == fb.get(n) and fa.get(n) is not None),
                      'differ': [n for n in names if fa.get(n) != fb.get(n)]}
        comparisons.append({'against': first['run'], 'run': r['run'], 'per_category': per,
                            'byte_identical': all(v['differ'] == [] for v in per.values())})
    # cross-verification: each binary's verifier on the other binary's receipts (the first run of each)
    cross = []
    labels = list(dict.fromkeys(order))
    first_of = {}
    for r in runs:
        first_of.setdefault(r['binary'], r['run'])
    for vl in labels:
        for pl in labels:
            if vl == pl:
                continue
            run = first_of[pl]
            checker = sd.Server([bins[vl], 'check-serve', '--export', str(sd.VEXP), '--tables', str(sd.VEXP / 'token_io'), '--policies', pols,
                                 '--expect-statement', sd.R13_IDENTITY, '--min-bits', '95', '--lanes', str(a.check_lanes),
                                 '--lane-threads', str(a.check_threads)], str(out / f'checker_{vl}_on_{run}.log'), dict(base_env, **extra.get(vl, {})))
            checker.ready.wait(900)
            if not checker.start or checker.start.get('event') != 'serve-start':
                raise SystemExit(f'verifier {vl} refused to start')
            done = threading.Semaphore(0)
            res = {}
            for c in sd.CATS:
                def cb(j, t, c=c):
                    res[c] = {'status': j['status'], 'verify_seconds': j.get('verify_seconds')}
                    done.release()
                checker.send({'id': f'{vl}-on-{run}-{c}', 'policy': sd.POL[c], 'expect_total': len(ids), 'content_file': str(content),
                              'chunks': [{'artifact': str(pub / run / f'{c}-c0'), 'decommitment': str(priv / run / f'{c}-c0-owner' / 'input.dec')}],
                              'log': str(priv / run / f'{c}-check-by-{vl}.log')}, cb)
            for _ in sd.CATS:
                done.acquire()
            checker.close()
            cross.append({'verifier': vl, 'receipts_of': run, 'results': res, 'all_checked': all(v['status'] == 'checked' for v in res.values())})
    summary = {'tag': a.tag, 'env': extra, 'binaries': {k: {'path': v, 'sha256': sha(v)} for k, v in bins.items()}, 'order': order,
               'runs': [{'run': r['run'], 'binary': r['binary'], 'status': r['status'],
                         'files_per_category': {c: len(h) for c, h in r['hashes'].items()},
                         'segment_sha256_digest': {c: hashlib.sha256(json.dumps({k: v for k, v in sorted(h.items()) if 'input.dec' not in k}).encode()).hexdigest()
                                                   for c, h in r['hashes'].items()}} for r in runs],
               'comparisons': comparisons, 'cross_verification': cross,
               'note': 'fixed public test entropy (fixed_entropy.c); public content only; receipts deleted after'}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({'comparisons': [{k: c[k] for k in ('against', 'run', 'byte_identical')} for c in comparisons],
                      'cross': [{k: x[k] for k in ('verifier', 'receipts_of', 'all_checked')} for x in cross]}))
    shutil.rmtree(pub, ignore_errors=True)


if __name__ == '__main__':
    main()
