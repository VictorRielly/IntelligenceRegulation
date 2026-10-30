"""Bounded stages of the first real post through the app and testnet publisher.

Private content, owner openings and activations stay outside the repository.
Each category is supervised to a terminal result; no implicit re-proving.
"""
import argparse
import asyncio
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE/'real_app_demo_1'
PRIVATE = Path('/tmp/zk60-astra-real-app-demo-20261029-1')
TEXT = 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.'
os.environ.update({'PM_PRIVATE_DIR': str(PRIVATE), 'PM_PUBLIC_DIR': str(OUT/'public'),
                   'PM_PROVER': 'shieldstral', 'PM_NO_WORKER': '1', 'PM_PUBLISHER': 'base-sepolia',
                   'PM_SEPOLIA_CONFIG': str(ROOT/'apps/proven-media/.testnet-private/sepolia.json'),
                   'OPENBLAS_NUM_THREADS': '2', 'OMP_NUM_THREADS': '2', 'RAYON_NUM_THREADS': '2'})
sys.path.insert(0, str(ROOT/'apps/proven-media'))
from proven_media import app, config, records
from proven_media.jobs import Worker
from proven_media.store import loads
from proven_media.classifier_cli import require


def save(path, data):
    temporary = path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(data, indent=2)+'\n')
    os.replace(temporary, path)


def sources():
    files = [ROOT/'apps/proven-media/proven_media'/name for name in
             ('shieldstral_prover.py', 'shieldstral_runtime.py', 'classifier_cli.py', 'classifier_prover.py',
              'provers.py', 'jobs.py', 'proof_plans.py', 'records.py', 'config.py', 'app.py', 'manifest.py')]
    files += [ROOT/'apps/proven-media/tools/classifier_pipeline.py', Path(__file__)]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('prepare', 'category', 'inspect', 'anchor'))
    parser.add_argument('--category', choices=('sexual', 'violence', 'hate'))
    args = parser.parse_args()
    if args.action == 'prepare':
        require(not (OUT/'plan.json').exists(), 'demo already prepared')
        OUT.mkdir(exist_ok=True)
        PRIVATE.mkdir(mode=0o700, exist_ok=True)
        app.init_state(start_worker=False)
        require(not app.S.store.one('SELECT id FROM posts LIMIT 1'), 'demo database already contains a post')
        response = asyncio.run(app.api_create_post(author='astra_demo', kind='text', text=TEXT, file=None))
        require(response['proofs'] == response['chunks'] == 3, 'expected one short chunk per category')
        post = app.S.store.post(response['post_id'])
        evidence = {'schema': 'pm-real-shieldstral-testnet-demo/1', 'at': datetime.now(timezone.utc).isoformat(),
            'post_id': response['post_id'], 'submitted_via': 'app.api_create_post handler; original app Store and Worker',
            'post_text': TEXT, 'content_tokens': app.S.prover.content_length(TEXT),
            'plan': loads(post['chunks']), 'prover': app.S.prover.describe(), 'source_sha256': sources(),
            'private_root': str(PRIVATE), 'public_root': str(OUT/'public'), 'categories': {}}
        save(OUT/'plan.json', evidence)
        print(json.dumps({'prepared': response, 'tokens': evidence['content_tokens']}), flush=True)
        return
    evidence = json.loads((OUT/'plan.json').read_text())
    require(evidence['source_sha256'] == sources(), 'demo sources changed; inspect before resuming')
    app.init_state(start_worker=False)
    store = app.S.store; pid = evidence['post_id']; post = store.post(pid)
    if args.action == 'inspect':
        jobs = store.q('SELECT id,chunk,status,job_dir,error FROM jobs WHERE post_id=? ORDER BY id', (pid,))
        print(json.dumps({'post_id': pid, 'status': post['status'], 'jobs': [{**j,
            'pipeline': app.S.prover.poll(Path(j['job_dir'])) if j['job_dir'] else None} for j in jobs]}), flush=True)
        return
    worker = Worker(store, app.S.prover, app.S.publisher)
    if args.action == 'category':
        require(args.category is not None, 'category required')
        ch = next(ch for ch in evidence['plan'] if ch['category'] == args.category)
        require(all(not p.exists() for p in (config.HOLD_FILE,
            ROOT/'results/zk60_shieldstral_prep_20261021/HOLD',
            ROOT/'results/zk60_shieldstral_export_20261026/HOLD')), 'coordinator HOLD active')
        job = store.one('SELECT * FROM jobs WHERE post_id=? AND chunk=?', (pid, ch['index']))
        require(not store.one("SELECT id FROM jobs WHERE post_id=? AND chunk<? AND status!='done'", (pid,ch['index'])),
                'earlier category has not completed')
        if job['status'] == 'queued':
            worker.start_job(job)
            job = store.one('SELECT * FROM jobs WHERE id=?', (job['id'],))
        require(job['status'] in ('running','done'), 'category failed; never re-prove automatically')
        previous = None
        while job['status'] == 'running':
            state = app.S.prover.poll(Path(job['job_dir']))
            changed = (state['step'], state['done'], state['exit'])
            if changed != previous:
                print(json.dumps({'category': args.category, 'pipeline': state}), flush=True)
                previous = changed
            if state['done']:
                worker.finish(job)
                break
            require(state['alive'] is not False, 'pipeline terminated without completion marker')
            time.sleep(5)
        job = store.one('SELECT * FROM jobs WHERE id=?', (job['id'],))
        require(job['status'] == 'done', 'category did not complete successfully')
        row = store.one('SELECT * FROM chunk_proofs WHERE post_id=? AND chunk=?', (pid, ch['index']))
        record = loads(row['record'])
        require(row['status'] == 'done' and record is not None, 'accepted category record missing')
        result = {'category': args.category, 'finished_at': datetime.now(timezone.utc).isoformat(),
                  'record': record, 'source_sha256': sources()}
        save(OUT/(args.category+'.json'), result)
        (OUT/(args.category+'.done')).write_text('0\n')
        print(json.dumps({'category': args.category, 'verdict': record['labels'][args.category]['value'],
            'receipt_bytes': record['receipt']['bytes'], 'work_s': record['timings']['work_s']}), flush=True)
        return
    require(post['status'] == 'published', 'all proofs must be accepted before anchoring')
    item = loads(post['record'])
    require(all(v['proof']=='accepted' and v['bound_by_proof'] for v in item['labels'].values()),
            'published item lacks proved labels')
    anchors = app.S.publisher.anchors_of(pid)
    require(len(anchors) == 3, 'three receipt bundles must be stored before anchoring')
    for _ in range(30):
        app.S.publisher.tick(force=True)
        anchors = app.S.publisher.anchors_of(pid)
        if all(a.status == 'anchored' for a in anchors.values()):
            break
        time.sleep(5)
    require(all(a.status == 'anchored' for a in anchors.values()), 'anchor pending; resume the retained transaction')
    checks = {k: app.S.publisher.verify_publication(a) for k,a in anchors.items()}
    require(all(v['accepted'] for v in checks.values()), 'published bundle or anchor check failed')
    worker.finalize(pid)
    post = store.post(pid)
    result = {**evidence, 'finished_at': datetime.now(timezone.utc).isoformat(), 'record': loads(post['record']),
              'manifest': loads(post['manifest']), 'anchors': {k:a.to_dict() for k,a in anchors.items()},
              'publication_checks': checks, 'source_sha256_revalidated': sources() == evidence['source_sha256']}
    save(OUT/'complete.json', result)
    (OUT/'worker.done').write_text('0\n')
    print(json.dumps({'complete': str(OUT/'complete.json'), 'transactions': sorted({a.tx_hash for a in anchors.values()}),
                      'privacy_status': 'privacy statement pending'}), flush=True)


if __name__ == '__main__':
    main()
