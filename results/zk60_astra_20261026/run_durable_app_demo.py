"""Bounded stages of a new public demo, with durable private state and openings.

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
import subprocess
import fcntl

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE/'real_app_demo_2'
PRIVATE = Path('/home/victor/zk60-owner-private/proven-media-astra-demo-2')
TEXT = 'The library opened early today. I borrowed a book about birds and read it by the window.'
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
    with temporary.open('w') as stream:
        stream.write(json.dumps(data, indent=2)+'\n')
        stream.flush(); os.fsync(stream.fileno())
    os.replace(temporary, path)
    fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    os.fsync(fd); os.close(fd)


def sources():
    files = sorted((ROOT/'apps/proven-media/proven_media').glob('*.py'))
    files += [ROOT/'apps/proven-media/tools/classifier_pipeline.py', Path(__file__).resolve()]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def retained_openings(store, pid):
    """Check retained locations and capture only already-public native events."""
    from proven_media.classifier_cli import one_event
    post = store.post(pid)
    require(records.salt_of(pid, post['salt_enc']) is not None, 'salt opening missing')
    result = []
    for row in store.q('SELECT * FROM jobs WHERE post_id=? ORDER BY chunk', (pid,)):
        require(row['status'] == 'done', 'not all category jobs accepted')
        job = Path(row['job_dir']); spec = json.loads((job/'classifier-job.json').read_text())
        owner = Path(spec['owner_dir'])/'input.dec'
        require(owner.resolve().is_relative_to(PRIVATE) and owner.is_file() and owner.stat().st_size > 0,
                'durable owner opening missing')
        require(owner.stat().st_mode & 0o077 == 0, 'owner opening permissions too broad')
        checked = one_event((job/'logs/inowner.log').read_text(), 0, 'content-checked')
        require(checked['content_total'] == spec['total'], 'owner event missing')
        result.append({'category':spec['category'], 'input_owner':checked,
                       'private_opening_retained':True, 'private_opening_mode':'0600',
                       'guard':json.loads((job/'logs/inowner.guard.json').read_text())})
    require(len(result) == 3, 'three opening checks required')
    return {'at':datetime.now(timezone.utc).isoformat(), 'post_id':pid,
            'salt_opening_retained':True, 'categories':result,
            'scope':'Public owner-check events and retention checks; no private opening bytes included.'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('prepare', 'category', 'inspect', 'anchor'))
    parser.add_argument('--category', choices=('sexual', 'violence', 'hate'))
    parser.add_argument('--native-threads', type=int, choices=(2, 8), default=8)
    parser.add_argument('--detach', action='store_true')
    args = parser.parse_args()
    os.environ['PM_CLASSIFIER_NATIVE_THREADS'] = str(args.native_threads)
    if args.detach:
        require(args.action == 'category' and args.category, 'only one category may be detached')
        require((OUT/'plan.json').exists(), 'prepare first')
        launch = OUT/(args.category+'.launch.json')
        with launch.open('x') as record:
            with (OUT/(args.category+'.supervisor.log')).open('xb') as output:
                proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'category',
                    '--category',args.category,'--native-threads',str(args.native_threads)], cwd=ROOT,
                    stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                    start_new_session=True, close_fds=True)
            state = {'pid':proc.pid, 'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
                     'worker_done':str(OUT/(args.category+'.supervisor.done'))}
            json.dump(state, record); record.flush(); os.fsync(record.fileno())
        print(json.dumps(state)); return
    if args.action == 'prepare':
        require(not (OUT/'plan.json').exists(), 'demo already prepared')
        OUT.mkdir(exist_ok=True)
        PRIVATE.mkdir(mode=0o700, exist_ok=True)
        app.init_state(start_worker=False)
        require(not app.S.store.one('SELECT id FROM posts LIMIT 1'), 'demo database already contains a post')
        from fastapi.testclient import TestClient
        from proven_media.provers import write_private
        credential_path = PRIVATE/'author-access.key'
        if credential_path.exists():
            credential = credential_path.read_text()
        else:
            credential = app.S.auth.provision('astra_demo')
            write_private(credential_path, credential.encode())
        with TestClient(app.app) as client:
            login = client.post('/api/session', json={'access_key': credential})
            require(login.status_code == 200, 'demo author login failed')
            csrf = login.json()['csrf']
            created = client.post('/api/posts', data={'author':'astra_demo', 'kind':'text', 'text':TEXT},
                                  headers={'x-pm-csrf':csrf})
            if created.status_code != 200:
                save(OUT/'prepare_failure.json', {'at':datetime.now(timezone.utc).isoformat(),
                    'status_code':created.status_code,'response':created.json(),
                    'posts':len(app.S.store.q('SELECT id FROM posts'))})
                require(False, 'authenticated demo submission failed; see prepare_failure.json')
            response = created.json()
            require(client.get('/api/posts/'+response['post_id']).status_code == 200, 'author view missing')
            client.cookies.clear()
            require(client.get('/api/posts/'+response['post_id']).status_code == 404, 'unproved post is public')
        require(response['proofs'] == response['chunks'] == 3, 'expected one short chunk per category')
        post = app.S.store.post(response['post_id'])
        evidence = {'schema': 'pm-real-shieldstral-testnet-demo/1', 'at': datetime.now(timezone.utc).isoformat(),
            'post_id': response['post_id'], 'submitted_via': 'authenticated ASGI /api/session then CSRF-protected /api/posts; original app Store and Worker',
            'post_text': TEXT, 'content_tokens': app.S.prover.content_length(TEXT),
            'plan': loads(post['chunks']), 'prover': app.S.prover.describe(), 'source_sha256': sources(),
            'private_root': str(PRIVATE), 'public_root': str(OUT/'public'), 'categories': {}}
        save(OUT/'plan.json', evidence)
        save(OUT/'publisher_public_key.json', {'public_key':app.manifest.public_key_hex()})
        settings = json.loads(Path(os.environ['PM_SEPOLIA_CONFIG']).read_text())
        settings.pop('key_file', None)
        save(OUT/'sepolia_public_config.json', settings)
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
        lock = (PRIVATE/'supervisor.lock').open('a')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
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
        execution_file = Path(job['job_dir'])/'execution.json'
        execution = json.loads(execution_file.read_text()) if execution_file.exists() else {'native_threads': 2,
            'source': 'original pinned two-thread pipeline; retained guard argv is authoritative'}
        result = {'category': args.category, 'finished_at': datetime.now(timezone.utc).isoformat(),
                  'record': record, 'execution': execution, 'source_sha256': sources()}
        save(OUT/(args.category+'.json'), result)
        (OUT/(args.category+'.done')).write_text('0\n')
        print(json.dumps({'category': args.category, 'verdict': record['labels'][args.category]['value'],
            'receipt_bytes': record['receipt']['bytes'], 'work_s': record['timings']['work_s']}), flush=True)
        return
    require(post['status'] == 'published', 'all proofs must be accepted before anchoring')
    opening_checks = retained_openings(store, pid)
    save(OUT/'input_owner_capture.json', opening_checks)
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
              'publication_checks': checks, 'source_sha256_revalidated': sources() == evidence['source_sha256'],
              'openings_retained':opening_checks}
    save(OUT/'complete.json', result)
    (OUT/'worker.done').write_text('0\n')
    print(json.dumps({'complete': str(OUT/'complete.json'), 'transactions': sorted({a.tx_hash for a in anchors.values()}),
                      'privacy_status': 'privacy statement pending'}), flush=True)


if __name__ == '__main__':
    code = 0
    try:
        main()
    except BaseException:
        code = 1
        raise
    finally:
        if len(sys.argv) > 1 and sys.argv[1] == 'category' and '--detach' not in sys.argv and '--category' in sys.argv:
            category = sys.argv[sys.argv.index('--category')+1]
            if category in ('sexual','violence','hate'):
                save(OUT/(category+'.supervisor.done'), code)
