"""Recover the public garden demo after loss of its original /tmp workspace.

Never proves, retries a screening, fabricates owner openings, or replaces an
existing publication. Native verification reads the retained public store.
The lost local manifest key is explicitly replaced by a new development key;
the original salted commitment is retained, but its opening is unavailable.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APP = ROOT / 'apps/proven-media'
OUT = HERE / 'real_app_demo_1'
RECOVERY = OUT / 'recovery-20261030'
PRIVATE = APP / '.testnet-private/real-app-demo-recovery'
os.environ.update(PM_PRIVATE_DIR=str(PRIVATE), PM_PUBLIC_DIR=str(OUT/'public'),
                  PM_PROVER='shieldstral', PM_NO_WORKER='1', PM_PUBLISHER='base-sepolia')
sys.path[:0] = [str(APP), str(APP/'tools')]
from proven_media import config, manifest, proof_plans, records
from proven_media.classifier_cli import require
from proven_media.items import TextItem
from proven_media.jobs import PubInfo
from proven_media.publisher import make_publisher
from proven_media.shieldstral_prover import ShieldstralProver
from proven_media.store import Store
from verify_publication import run_verifier


def now():
    return datetime.now(timezone.utc).isoformat()


def save(path, value):
    path = Path(path)
    tmp = path.with_suffix(path.suffix + '.tmp')
    with tmp.open('w') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(tmp, path)


def source_pins():
    files = [Path(__file__), APP/'tools/verify_publication.py',
             APP/'proven_media/shieldstral_runtime.py']
    return {str(p.relative_to(ROOT)): records.sha256_file(p) for p in files}


def audit():
    plan = json.loads((OUT/'plan.json').read_text())
    require(all(records.sha256_file(ROOT/p) == digest for p, digest in plan['source_sha256'].items()),
            'original demo source provenance changed')
    require(not Path(plan['private_root']).exists(), 'original workspace exists; use normal continuation')
    owner = json.loads((OUT/'input_owner_capture.json').read_text())
    require(owner['complete'] is True and owner['post_id'] == plan['post_id'] and owner['public_input'] is True,
            'retained complete public owner capture missing')
    require(len(owner['categories']) == 3 and {r['category'] for r in owner['categories']} == {'sexual','violence','hate'},
            'owner capture category set differs')
    prover = ShieldstralProver()
    proof_plans.check_plan(plan['plan'], prover.plan_text(plan['post_text']))
    require(prover.content_length(plan['post_text']) == plan['content_tokens'] == 17, 'public item differs')
    pub = make_publisher(OUT/'public', mode='base-sepolia', config_path=OUT/'sepolia_public_config.json', read_only=True)
    anchors = pub.anchors_of(plan['post_id'])
    require(len(anchors) == 3, 'expected exactly three retained publications')
    rows, publications, inputs = [], {}, {}
    for ch in plan['plan']:
        category = ch['category']
        require((OUT/(category+'.done')).read_text().strip() == '0', 'original category not successful')
        record_file = OUT/(category+'.json')
        rec = json.loads(record_file.read_text())['record']
        inputs[str(record_file.relative_to(ROOT))] = records.sha256_file(record_file)
        proof_plans.check_category_record(rec, plan['post_id'], ch, require_verdict=True)
        require(rec['checks']['verify']['ok'] is True and rec['checks']['content_binding']['ok'] is True,
                'original verification or input binding missing')
        capture = next(r for r in owner['categories'] if r['category'] == category)
        require(capture['statement_sha256'] == rec['statement_sha256']
                and capture['trained_statement_identity'] == rec['statement']['trained_statement_identity']
                and capture['input_owner'] == {'event':'content-checked','chunk':0,'range':[0,17],
                                             'content_total':17,'verdict':rec['statement']['verdict']}
                and capture['guard']['exit'] == capture['guard']['child_rc'] == 0,
                'retained owner result differs from the receipt')
        key = f'c{ch["index"]}.{category}'
        anchor = anchors[key]
        check = pub.verify_publication(anchor, rehash_segments=True)
        require(all(v for k,v in check['checks'].items() if k != 'anchored')
                and (check.get('pending') is True or check['accepted'] is True),
                'retained publication inventory invalid')
        publication = pub.resolve(anchor)
        pm = publication['manifest']
        require(publication['statement'] == rec['statement'] and pm['segments'] == rec['receipt']['files']
                and pm['statement_sha256'] == rec['statement_sha256']
                and pm['model_id'] == rec['prover']['model_digest']
                and pm['profile_id'] == rec['prover']['token_profile_digest']
                and pm['verifier_id'] == rec['prover']['binary_sha256']
                and pm['policy_id'] == rec['labels'][category]['policy_sha256']
                and pm['verdict'] == rec['labels'][category]['value']
                and pm['token_range'] == [ch['start'],ch['end']], 'publication differs from retained checked record')
        rows.append(rec)
        publications[key] = pm
    prover.check_final_records(TextItem(plan['post_text']), rows)
    commitments = {m['content_commitment'] for m in publications.values()}
    require(len(commitments) == 1 and len(next(iter(commitments))) == 64, 'post commitments disagree')
    result = {'at':now(), 'post_id':plan['post_id'], 'accepted':True, 'current_boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
              'original_workspace_missing':True, 'receipt_segments':sum(len(r['receipt']['files']) for r in rows),
              'receipt_bytes':sum(r['receipt']['bytes'] for r in rows), 'source_sha256_revalidated':True,
              'retained_records':inputs, 'source_sha256':source_pins(), 'plan_sha256':records.sha256_file(OUT/'plan.json'),
              'lost':['original app database','local development signing key','salt opening','owner openings and job logs'],
              'preserved':['all public receipt bytes','publication manifests and pending leaves','checked records','public owner capture'],
              'new_proofs':0, 'original_manifest_signature_recovered':False}
    save(RECOVERY/'audit.json',result)
    return plan, rows, publications, anchors


def verify(plan, publications):
    pub = make_publisher(OUT/'public', mode='base-sepolia', config_path=OUT/'sepolia_public_config.json', read_only=True)
    results = []
    for ch in plan['plan']:
        category = ch['category']; publication = publications[f'c{ch["index"]}.{category}']
        path = RECOVERY/f'stored_verify_{category}.json'
        identity = {'post_id':plan['post_id'], 'category':category, 'chunk':ch['index'],
                    'statement_sha256':publication['statement_sha256'], 'source_sha256':source_pins()}
        if path.exists():
            result = json.loads(path.read_text())
            require(all(result.get(k) == v for k,v in identity.items()) and result['ok'] is True,
                    'previous stored verification failed or changed; inspect before retry')
        else:
            require(not any(p.exists() for p in (config.HOLD_FILE, ROOT/'results/zk60_shieldstral_export_20261026/HOLD',
                                                ROOT/'results/zk60_shieldstral_prep_20261021/HOLD')), 'coordinator HOLD active')
            print(json.dumps({'category':category,'step':'fresh native verification from retained store'}),flush=True)
            result = {**identity, **run_verifier(pub,publication,plan['post_id'])}
            guard = json.loads((Path(result['rebuilt_run']).parent/'verify.guard.json').read_text())
            result['ok'] = result['ok'] is True and all(type(guard.get(k)) is int and guard[k] == 0 for k in ('exit','child_rc')) \
                and not any(guard.get(k) for k in ('guard_killed','refused','guard_error','hard_killed','stragglers_killed','gpu_drain_failed'))
            result.update(guard_record=guard, finished_at=now())
            save(path,result)
        require(result['ok'] is True,'native stored verification failed')
        results.append(result)
        print(json.dumps({'category':category,'verified':True}),flush=True)
    save(RECOVERY/'stored_verify_complete.json',{'at':now(),'post_id':plan['post_id'],'accepted':True,'runs':results,
          'scope':'Fresh public-store native verification; retained historical owner checks, no new openings or proofs.'})


def signed_snapshot(plan, rows, publications, anchors):
    # New local signing authority is explicit; no attempt to recreate the old key.
    PRIVATE.mkdir(mode=0o700,parents=True,exist_ok=True)
    original_key = json.loads((OUT/'publisher_public_key.json').read_text())['public_key']
    new_key = manifest.public_key_hex()
    require(new_key != original_key,'expected an explicitly distinct recovery signing key')
    aggregate = records.aggregate_labels(rows,len(plan['plan']),plan['plan'])
    require(all(v['proof']=='accepted' and v['bound_by_proof'] for v in aggregate.values()),'all labels must be proved')
    item = {'schema':'proven-media-item/1','post_id':plan['post_id'],'item_kind':'text','prover':rows[0]['prover'],
            'labels':aggregate,'policies':[{**c['policy'],'category':c['id'],'name':c['name']} for c in records.categories()],
            'threshold':records.threshold(),'chunking':{'profile':'per-category','n_chunks':3},
            'chunks':[{**ch,'record':rec,'error':None} for ch,rec in zip(plan['plan'],rows)],
            'content_length':17,'proved_at':max(r['proved_at'] for r in rows),
            'receipt':{'segments':sum(r['receipt']['segments'] for r in rows),'bytes':sum(r['receipt']['bytes'] for r in rows)},
            'timings':{'work_s':sum(r['timings']['work_s'] for r in rows)},'created_at':plan['at']}
    post = {'id':plan['post_id'],'kind':'text','created_at':plan['at']}
    pubs = {k:PubInfo(m['model_id'],m['profile_id'],m['statement_sha256']) for k,m in publications.items()}
    signed = manifest.build_manifest(post,item,anchors,pubs,next(iter(publications.values()))['content_commitment'])
    signed['recovery'] = {'at':now(),'reason':'original /tmp workspace lost after reboot',
                          'original_publisher_key':original_key,'new_development_key':new_key,
                          'original_signature_recovered':False,'content_salt_opening_available':False,
                          'owner_checks':'retained original successful checks; private openings unavailable',
                          'new_native_proofs':0}
    signed = manifest.sign(signed)
    save(RECOVERY/'publisher_public_key.json',{'alg':'Ed25519','public_key':new_key,'replaces_lost_development_key':original_key})
    save(RECOVERY/'manifest.json',signed)
    save(RECOVERY/'item.json',item)
    return item,signed,new_key


def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=('audit','verify','anchor'))
    args=parser.parse_args()
    RECOVERY.mkdir(exist_ok=True)
    with (RECOVERY/'recovery.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        plan,rows,publications,anchors=audit()
        if args.action == 'audit':
            print(json.dumps({'audit':'passed','receipts':3,'segments':84,'new_proofs':0}));return
        verify(plan,publications)
        if args.action == 'verify':return
        item,signed,key=signed_snapshot(plan,rows,publications,anchors)
        pub=make_publisher(OUT/'public',mode='base-sepolia',config_path=APP/'.testnet-private/sepolia.json')
        require(manifest.verify_manifest(signed,pub,expected_public_key=key)['accepted'],'recovered signed inventory failed')
        for _ in range(30):
            pub.tick(force=True)
            anchors=pub.anchors_of(plan['post_id'])
            if all(a.status=='anchored' for a in anchors.values()):break
            time.sleep(5)
        require(len(anchors)==3 and all(a.status=='anchored' for a in anchors.values()),'anchor pending; resume retained transaction')
        checks={k:pub.verify_publication(a) for k,a in anchors.items()}
        require(all(c['accepted'] for c in checks.values()),'on-chain publication verification failed')
        signed_check=manifest.verify_manifest(signed,pub,expected_public_key=key)
        require(signed_check['accepted'] and not signed_check['pending_anchor'],'signed inventory not fully anchored')
        # Recover a display snapshot and immutable D45 reservation in durable private storage.
        # Native job directories/openings are not recoverable and are never invented.
        db=Store(PRIVATE/'app.sqlite3')
        if db.post(plan['post_id']) is None:
            db.add_screened_post(plan['post_text'],plan=(),id=plan['post_id'],author='astra_demo',kind='text',text=plan['post_text'],
                status='published',prover_kind='shieldstral',prove_attempted=1,salt_enc=None,
                content_key=records.content_key(plan['post_text']),created_at=plan['at'],published_at=now(),
                chunks=json.dumps(plan['plan']),record=json.dumps(item),manifest=json.dumps(signed),
                labels=json.dumps({c:v['value'] for c,v in item['labels'].items()}),
                status_message='Recovered after reboot from verified public receipts; original salt and owner openings unavailable.')
            for ch,rec in zip(plan['plan'],rows):
                db.x('INSERT INTO chunk_proofs(post_id,chunk,status,record,attempted,finished_at) VALUES(?,?,?,?,?,?)',
                     (plan['post_id'],ch['index'],'done',json.dumps(rec),1,rec['proved_at']))
        else:
            require(db.post(plan['post_id'])['text']==plan['post_text'],'recovered database contains another item')
            db.update_post(plan['post_id'],record=json.dumps(item),manifest=json.dumps(signed))
        db.db.execute('PRAGMA wal_checkpoint(TRUNCATE)');db.db.close()
        result={**plan,'finished_at':now(),'record':item,'manifest':signed,'anchors':{k:a.to_dict() for k,a in anchors.items()},
                'publication_checks':checks,'manifest_checks':signed_check,'source_sha256_revalidated':True,
                'recovery':{'audit':str(RECOVERY/'audit.json'),'private_root':str(PRIVATE),'original_plan_unchanged':True,
                            'original_manifest_key_lost':True,'new_manifest_key':key,'salt_opening_lost':True,
                            'private_owner_openings_lost':True,'new_proofs':0,'automatic_reprove_allowed':False}}
        save(OUT/'complete.json',result)
        saved_verify=json.loads((RECOVERY/'stored_verify_complete.json').read_text())
        saved_verify['manifest_checks']=signed_check
        save(OUT/'stored_verify_complete.json',saved_verify)
        (OUT/'worker.done').write_text('0\n')
        print(json.dumps({'complete':str(OUT/'complete.json'),'transactions':sorted({a.tx_hash for a in anchors.values()}),
                          'recovery_key_changed':True,'private_openings_lost':True,'new_proofs':0}),flush=True)


if __name__=='__main__':main()
