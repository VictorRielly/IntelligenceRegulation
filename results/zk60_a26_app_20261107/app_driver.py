#!/usr/bin/env python3
"""Lane A26 (A25's app_driver.py): the media app end to end in PM_PROVER=shieldstral-fast, on public posts only, with the
fast service's binary chosen by `--binary` (A26's candidate, or A24's pinned one for an A/B; the app checks the pin it is given).

Runs the real app in process (the FastAPI app with its lifespan: storage policy, store, auth,
prover factory, the queue Worker thread, the local publisher) through its HTTP routes
(sign-in, POST /api/posts, GET /api/posts/{id}). The app itself launches the fast service
through the shared resource guard (one guarded gpu-class job), as it would in a showing.
This driver is light (no heavy work of its own) and is not guarded.

usage: app_driver.py --tag T --phase NAME=FILE [--phase NAME=FILE ...] [--warm] [--timeout S]
  each phase posts every text of FILE at once and waits until the app has published (or
  failed) all of them; phases run one after another on the same app and service.
  --warm: start the service and wait until its servers are ready before the first clock.
Every post's three labels come from fresh verification in the separate verifier process; a
post counts once the app has published it (local content-addressed store, local ledger leaf,
signed manifest).
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import time

WT = Path('/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb')
MAIN = Path('/Users/victorrielly/IntelligenceRegulation')
R = WT / 'results/zk60_a26_app_20261107'
VENV = '/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python'


def run_phase(client, appmod, texts, timeout):
    t0 = time.time()
    posts = []
    for text in texts:
        r = client.post('/api/posts', data={'author': 'a24_operator', 'kind': 'text', 'text': text})
        assert r.status_code == 200, r.text
        j = r.json()
        posts.append({'post_id': j['post_id'], 'proofs': j['proofs'], 'submitted': time.time(), 'done': None, 'status': None,
                      'tokens': appmod.S.prover.content_length(text)})
    while any(p['done'] is None for p in posts) and time.time() - t0 < timeout:
        for p in posts:
            if p['done'] is None:
                row = appmod.S.store.post(p['post_id'])
                if row['status'] in ('published', 'failed'):
                    p['done'] = time.time()
                    p['status'] = row['status']
                    p['labels'] = json.loads(row['labels'] or '{}')
        time.sleep(0.25)
    t_end = time.time()
    done = [p for p in posts if p['status'] == 'published']
    proofs = sum(p['proofs'] for p in done)
    wall = t_end - t0
    order = sorted(done, key=lambda p: p['done'])
    steady = None
    if len(order) >= 4:
        k = len(order) // 2
        span = order[-1]['done'] - order[k - 1]['done']
        n = sum(p['proofs'] for p in order[k:])
        steady = {'from_post': k, 'span_s': span, 'proofs': n, 'proved_tok_per_s': 128 * n / span if span > 0 else None}
    first = done[0] if done else None
    check = None
    if first:
        detail = client.get(f'/api/posts/{first["post_id"]}').json()
        rec = detail.get('record') or {}
        check = {'prover_kind': rec.get('prover', {}).get('kind'), 'privacy_status': rec.get('prover', {}).get('privacy_status'),
                 'production': rec.get('prover', {}).get('production'), 'labels': detail.get('labels'),
                 'run_profile': rec.get('prover', {}).get('run_profile'), 'development_profile': rec.get('prover', {}).get('development_profile'),
                 'public_posts_only': rec.get('prover', {}).get('public_posts_only'),
                 'chunks': len(rec.get('chunks', [])), 'manifest_entries': len((detail.get('manifest') or {}).get('entries', [])),
                 'status': detail.get('status')}
    return {'posts': len(posts), 'published': len(done), 'failed': sum(p['status'] == 'failed' for p in posts),
            'unfinished': sum(p['status'] is None for p in posts), 'wall_s': wall, 'category_proofs': proofs,
            'proved_tok_per_s': 128 * proofs / wall if wall else None,
            'content_tok_per_s': sum(p['tokens'] for p in done) / wall if wall else None, 'steady': steady,
            'per_post': [{'tokens': p['tokens'], 'proofs': p['proofs'], 'status': p['status'],
                          'latency_s': p['done'] - p['submitted'] if p['done'] else None,
                          'done_at_s': p['done'] - t0 if p['done'] else None, 'labels': p.get('labels')} for p in posts],
            'first_post_check': check, 'post_ids': [p['post_id'] for p in posts]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', required=True)
    ap.add_argument('--phase', action='append', required=True)
    ap.add_argument('--warm', action='store_true')
    ap.add_argument('--timeout', type=float, default=3600)
    ap.add_argument('--mode', choices=('shieldstral-fast',), default='shieldstral-fast')
    ap.add_argument('--binary', default=str(Path.home() / 'zk60-artifacts/proven-media-fast/bin/zk60_classify.a26'))
    a = ap.parse_args()
    out = R / f'app_{a.tag}'
    out.mkdir(exist_ok=False)
    priv = Path.home() / f'zk60-owner-private/a26-app-{a.tag}'
    pub = Path.home() / f'zk60-artifacts/a26-app-{a.tag}'
    priv.mkdir(mode=0o700)
    pub.mkdir()
    os.environ.update({
        'PM_PROVER': a.mode, 'PM_PRIVATE_DIR': str(priv), 'PM_PUBLIC_DIR': str(pub),
        'PM_SHIELDSTRAL_TOKENIZER': str(MAIN / 'results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tekken.json'),
        'PM_TINYLLAMA_TOKENIZER': str(MAIN / 'results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tokenizer.model'),
        'PM_FAST_BINARY': a.binary,
        'PM_FAST_WRITER_ROOT': str(MAIN / 'results/zk60_astra_20261026/a3_mac_writer_20261105'),
        'PM_FAST_MODELS': str(MAIN / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'),
        'PM_FAST_EXPORT_ROOT': str(MAIN / 'results/zk60_shieldstral_export_20261026'),
        'PM_FAST_WRITER_PYTHON': VENV, 'PM_FAST_SERVICE_PYTHON': VENV, 'PM_FAST_IDLE_SECS': '120',
        'PM_BATCH_SECS': '30', 'PYTHONDONTWRITEBYTECODE': '1'})
    sys.path.insert(0, str(WT / 'apps/proven-media'))
    from fastapi.testclient import TestClient
    from proven_media import app as appmod, fast_service
    from proven_media import shieldstral_fast_runtime as fast
    t_boot = time.time()
    client = TestClient(appmod.app).__enter__()
    key = appmod.S.auth.provision('a24_operator', operator=True, rotate=True)
    r = client.post('/api/session', json={'access_key': key})
    assert r.status_code == 200, r.text
    client.headers['X-PM-CSRF'] = r.json()['csrf']
    del key
    cfg = client.get('/api/config').json()
    (out / 'config.json').write_text(json.dumps({'prover': cfg['prover'], 'prover_mode': cfg['prover_mode'],
                                                 'deploy': cfg['deploy']}, indent=2) + '\n')
    service = fast.service_dir()
    summary = {'tag': a.tag, 'mode': a.mode, 'warm': a.warm, 'app_boot_s': time.time() - t_boot, 'phases': {}}
    if a.warm:
        t0 = time.time()
        fast_service.ensure_running(service, fast)
        while True:
            hb = fast_service.heartbeat(service) or {}
            if hb.get('state') == 'ready' and fast_service.service_live(service):
                break
            if hb.get('state') in ('stopped', 'failed', 'server-died'):
                raise SystemExit('the service stopped before it was ready (see its private logs)')
            if time.time() - t0 > 3600:
                raise SystemExit('the service did not become ready')
            time.sleep(1)
        summary['service_ready_s'] = time.time() - t0
    for spec in a.phase:
        name, path = spec.split('=', 1)
        texts = json.loads(Path(path).read_text())
        res = run_phase(client, appmod, texts, a.timeout)
        summary['phases'][name] = res
        print(json.dumps({'phase': name, **{k: res[k] for k in ('posts', 'published', 'failed', 'wall_s', 'category_proofs', 'proved_tok_per_s', 'steady')}}), flush=True)
        # disk: keep the first post's receipts of each phase, drop the rest (the app is done with them)
        keep = res['post_ids'][:1]
        for d in (pub / 'runs').iterdir() if (pub / 'runs').is_dir() else []:
            if any(d.name.startswith(pid) for pid in res['post_ids']) and not any(d.name.startswith(k) for k in keep):
                shutil.rmtree(d, ignore_errors=True)
    summary['service_heartbeat'] = fast_service.heartbeat(service)
    summary['on_the_clock'] = ('from the phase\'s first POST /api/posts to its last post published by the app: tokenization and '
                               'screening, the queue, the activation writer, the sealing pass and witnesses, the proof, the receipt '
                               'write, fresh verification and the input-owner check in the separate verifier process, the category '
                               'label, the app\'s re-checks of every native output, publication to the local store and ledger, the '
                               'signed manifest' + ('' if a.warm else '; and the service startup'))
    fast_service.stop(service)
    client.__exit__(None, None, None)
    (out / 'summary.json').write_text(json.dumps(summary, indent=2, default=str) + '\n')


if __name__ == '__main__':
    main()
