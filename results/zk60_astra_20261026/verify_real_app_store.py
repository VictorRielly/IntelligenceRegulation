"""Fresh verification of all three off-chain demo receipts, without signing transactions.

Each native verification uses the existing app resource guard. No outer guard,
new proof, private opening, or activation source is used by the verifier.
"""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'real_app_demo_1'
os.environ['PM_PROVER'] = 'shieldstral'
sys.path[:0] = [str(ROOT / 'apps/proven-media'), str(ROOT / 'apps/proven-media/tools')]
from proven_media.classifier_cli import require
from proven_media.manifest import verify_manifest
from proven_media.publisher import make_publisher
from verify_publication import run_verifier


def save(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    os.replace(temporary, path)


def main():
    plan = json.loads((OUT / 'plan.json').read_text())
    # The original /tmp workspace was lost on reboot. Recovery explicitly
    # records a durable display database and a replacement development signer;
    # retain the original plan and public-key pin as historical evidence.
    completion = json.loads((OUT / 'complete.json').read_text()) if (OUT / 'complete.json').exists() else {}
    recovery = completion.get('recovery', {})
    require(not completion or completion['post_id'] == plan['post_id'], 'completion names another post')
    private_root = Path(recovery.get('private_root', plan['private_root']))
    db = sqlite3.connect(f'file:{private_root / "app.sqlite3"}?mode=ro', uri=True)
    row = db.execute('SELECT status,manifest FROM posts WHERE id=?', (plan['post_id'],)).fetchone()
    db.close()
    require(row is not None and row[0] == 'published', 'all app proofs must finish before stored verification')
    manifest = json.loads(row[1])
    key_file = OUT / ('recovery-20261030/publisher_public_key.json' if recovery else 'publisher_public_key.json')
    issuer = json.loads(key_file.read_text())['public_key']
    require(not recovery or issuer == recovery['new_manifest_key'], 'recovery issuer pin differs')
    pub = make_publisher(Path(plan['public_root']), mode='base-sepolia',
                         config_path=OUT / 'sepolia_public_config.json', read_only=True)
    checks = verify_manifest(manifest, pub, expected_public_key=issuer, rehash_segments=False)
    require(checks['accepted'], 'signed manifest or publication inventory did not verify')
    entries = manifest['entries']
    require(len(entries) == 3 and {e['category'] for e in entries} == {'sexual', 'violence', 'hate'}
            and all(e['proof_status'] == 'accepted' for e in entries), 'complete three-category proof set required')
    source = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in
              (Path(__file__), ROOT / 'apps/proven-media/tools/verify_publication.py',
               ROOT / 'apps/proven-media/proven_media/shieldstral_runtime.py')}
    runs = []
    for entry in entries:
        category = entry['category']
        anchor = pub.anchor_of(plan['post_id'], category, entry['chunk'])
        require(anchor is not None, 'stored publication reference missing')
        publication = pub.resolve(anchor)['manifest']
        identity = {'post_id': plan['post_id'], 'category': category, 'chunk': entry['chunk'],
                    'statement_sha256': entry['statement_sha256'], 'source_sha256': source}
        path = OUT / f'stored_verify_{category}.json'
        if path.exists():
            result = json.loads(path.read_text())
            require(all(result[k] == v for k, v in identity.items()) and result['ok'] is True,
                    'previous stored verification differs or failed; inspect before another attempt')
        else:
            print(json.dumps({'category': category, 'step': 'fresh verify from content-addressed store'}), flush=True)
            result = {**identity, **run_verifier(pub, publication, plan['post_id'])}
            # The process status and stdout alone are not an acceptance boundary.
            guard_path = Path(result['rebuilt_run']).parent / 'verify.guard.json'
            guard = json.loads(guard_path.read_text())
            clean = (all(type(guard.get(k)) is int and guard[k] == 0 for k in ('exit', 'child_rc'))
                     and not any(guard.get(k) for k in ('guard_killed', 'refused', 'guard_error',
                                                       'hard_killed', 'stragglers_killed', 'gpu_drain_failed')))
            result['ok'] = result['ok'] is True and clean
            result['guard_record'] = guard
            result['finished_at'] = datetime.now(timezone.utc).isoformat()
            save(path, result)
        require(result['ok'], 'stored receipt verification failed')
        runs.append(result)
        print(json.dumps({'category': category, 'verified': True}), flush=True)
    save(OUT / 'stored_verify_complete.json', {'at': datetime.now(timezone.utc).isoformat(),
        'post_id': plan['post_id'], 'accepted': True, 'manifest_checks': checks, 'runs': runs,
        'scope': 'Three native fresh verifications of stored public receipts; no new proof or transaction.'})


if __name__ == '__main__':
    main()
