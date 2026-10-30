"""Exercise real-mode ASGI routes with the pinned tokenizer and saved queued post.

The proof worker stays off. No native proof or chain transaction is launched.
"""
from datetime import datetime, timezone
import hashlib
from importlib import metadata
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE/'real_app_demo_1'
PRIVATE = Path('/tmp/zk60-astra-real-app-demo-20261029-1')
os.environ.update({'PM_PRIVATE_DIR': str(PRIVATE), 'PM_PUBLIC_DIR': str(OUT/'public'),
                   'PM_PROVER': 'shieldstral', 'PM_NO_WORKER': '1', 'PM_PUBLISHER': 'base-sepolia',
                   'PM_SEPOLIA_CONFIG': str(ROOT/'apps/proven-media/.testnet-private/sepolia.json'),
                   'OPENBLAS_NUM_THREADS': '2', 'OMP_NUM_THREADS': '2', 'RAYON_NUM_THREADS': '2'})
sys.path.insert(0, str(ROOT/'apps/proven-media'))
from fastapi.testclient import TestClient
from proven_media import app, records, shieldstral_runtime as runtime


def main():
    plan = json.loads((OUT/'plan.json').read_text())
    for name, digest in plan['source_sha256'].items():
        assert records.sha256_file(ROOT/name) == digest, name
    pid = plan['post_id']; checks = {}; started = time.monotonic()

    def check(name, condition):
        checks[name] = bool(condition)
        assert condition, name

    with TestClient(app.app) as client:
        check('proof_worker_disabled', app.S.worker is None)
        before = app.S.store.q('SELECT * FROM jobs ORDER BY id')
        check('all_original_jobs_queued', len(before) == 3 and all(j['status'] == 'queued' for j in before))
        check('page_served', client.get('/').status_code == 200)
        check('frontend_served', client.get('/static/app.js').status_code == 200)
        cfg = client.get('/api/config').json()
        check('real_model_pinned', cfg['prover']['kind'] == 'shieldstral'
              and cfg['prover']['model_digest'] == runtime.IDENTITY
              and cfg['prover']['binary_sha256'] == runtime.BINARY_SHA)
        check('privacy_pending', cfg['classifier']['status'] == 'privacy statement pending')
        check('registered_category_set', cfg['category_set']['id'] == 'shieldstral-moderate-testnet-v1')
        check('native_context_and_limits', cfg['limits']['T'] == 128
              and cfg['deploy']['max_content_tokens'] == 336
              and [cfg['deploy']['category_geometry'][c]['chunk_tokens'] for c in ('sexual','violence','hate')] == [55,55,49])
        tok = client.post('/api/tokenize', json={'text': plan['post_text']}).json()
        check('real_tokenizer_matches_saved_post', tok['count'] == plan['content_tokens'] == 17)
        check('one_job_per_category', tok['fits'] and tok['proofs'] == tok['chunks'] == 3
              and tok['category_chunks'] == {'sexual':1, 'violence':1, 'hate':1})
        status = client.get('/api/status').json()
        check('real_queue_work_estimate', status['queue']['per_job_s'] == 700)
        own = client.get(f'/api/posts/{pid}', params={'author':'astra_demo'}).json()
        check('author_sees_queued_post', own['text'] == plan['post_text'] and own['status'] == 'queued')
        check('queued_labels_unproved', all(l['value'] == 'unproved' and not l['bound_by_proof'] for l in own['labels']))
        for audience in ('adult','minor'):
            view = client.get(f'/api/posts/{pid}', params={'audience':audience}).json()
            check(audience+'_cannot_read_unproved_post', view['text'] is None and view['text_hidden'])
            check(audience+'_feed_excludes_unproved_post', client.get('/api/feed', params={'audience':audience}).json()['posts'] == [])
        for path in ('manifest.json','record.json','bundle.tar'):
            check('no_unproved_'+path, client.get(f'/api/posts/{pid}/{path}').status_code == 404)
        duplicate = client.post('/api/posts', data={'author':'other_author', 'kind':'text', 'text':plan['post_text']})
        check('repeat_screening_refused', duplicate.status_code == 409)
        check('original_jobs_unchanged', app.S.store.q('SELECT * FROM jobs ORDER BY id') == before)
        check('no_duplicate_post', app.S.store.one('SELECT COUNT(*) AS n FROM posts')['n'] == 1)
        check('no_public_receipts', not list((OUT/'public/runs').iterdir()))
        check('no_anchor_created', app.S.publisher.anchors_of(pid) == {})
        app.S.store.db.close()
    result = {'at': datetime.now(timezone.utc).isoformat(), 'scope': 'Real ASGI routes, real pinned tokenizer and queued demo database; worker disabled',
              'checks': checks, 'seconds': time.monotonic()-started, 'source_sha256': plan['source_sha256'],
              'checker_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'packages': {d.metadata['Name']: d.version for d in metadata.distributions()},
              'native_proof_run': False, 'chain_transaction_sent': False}
    (OUT/'real_routes_check.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'checks_passed': len(checks), 'seconds': result['seconds'],
                      'native_proof_run': False, 'chain_transaction_sent': False}))


if __name__ == '__main__':
    main()
