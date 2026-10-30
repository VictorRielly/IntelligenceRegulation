"""Read-only checks of the new real post and retained private openings."""
from datetime import datetime,timezone
import json
import os
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];APP=ROOT/'apps/proven-media'
OUT=HERE/'real_app_demo_2'
plan=json.loads((OUT/'plan.json').read_text())
os.environ.update(PM_PRIVATE_DIR=plan['private_root'],PM_PUBLIC_DIR=plan['public_root'],
    PM_PROVER='shieldstral',PM_NO_WORKER='1',PM_PUBLISHER='base-sepolia',
    PM_SEPOLIA_CONFIG=str(APP/'.testnet-private/sepolia.json'))
sys.path.insert(0,str(APP))
from fastapi.testclient import TestClient
from proven_media import app,manifest,records
from proven_media.publisher import content_commitment
from proven_media.store import ScreeningConflict
from run_durable_app_demo import retained_openings


def no_timing(value):
    if isinstance(value,dict):
        assert not {'timings','work_s','proved_at'} & value.keys()
        for v in value.values():no_timing(v)
    elif isinstance(value,list):
        for v in value:no_timing(v)


def main():
    pid=plan['post_id'];checks=[]
    with TestClient(app.app) as client:
        before={t:app.S.store.q(f'SELECT * FROM {t}') for t in ('posts','jobs','screenings','chunk_proofs')}
        response=client.get('/api/posts/'+pid)
        assert response.status_code==200 and response.json()['status']=='published'
        assert response.json()['text']==plan['post_text']
        checks.append('new public post and original text')
        response=client.get('/api/posts/'+pid+'/record.json');assert response.status_code==200
        record=response.json();no_timing(record)
        assert set(record['labels'])=={'sexual','violence','hate'}
        assert all(x['proof']=='accepted' and x['bound_by_proof'] for x in record['labels'].values())
        assert record['receipt']['segments']==84
        checks.append('three bound labels,84segments,no public timing')
        for audience in ('adult','minor'):
            response=client.get('/api/feed',params={'audience':audience});assert response.status_code==200
            data=response.json();posts=data if isinstance(data,list) else data['posts']
            visible=any(p['id']==pid for p in posts)
            expected=audience=='adult' or all(x['value']=='no' for x in record['labels'].values())
            assert visible==expected
            checks.append(audience+' feed matches proved labels')
        signed=client.get('/api/posts/'+pid+'/manifest.json').json()
        issuer=json.loads((OUT/'publisher_public_key.json').read_text())['public_key']
        assert signed['issuer']['public_key']==issuer and 'recovery' not in signed
        checked=manifest.verify_manifest(signed,app.S.publisher,expected_public_key=issuer)
        assert checked['accepted'] and not checked['pending_anchor']
        checks.append('original manifest key and all confirmed references verify')
        assert client.get('/api/publisher-key').json()['public_key']==issuer
        checks.append('publisher endpoint retains original key')
        post=app.S.store.post(pid);salt=records.salt_of(pid,post['salt_enc']);assert salt is not None
        commitment=content_commitment(salt,post['text'].encode())
        anchors=app.S.publisher.anchors_of(pid);assert len(anchors)==3
        for anchor in anchors.values():
            assert app.S.publisher.resolve(anchor)['manifest']['content_commitment']==commitment
        checks.append('retained salt opens all three anchored content commitments')
        openings=retained_openings(app.S.store,pid)
        assert all(c['input_owner']['content_total']==plan['content_tokens'] for c in openings['categories'])
        checks.append('all three private input-owner openings retained outside repo with mode0600')
        assert client.get('/api/submissions?author=astra_demo').status_code==401
        assert client.post('/api/posts',data={'author':'astra_demo','text':plan['post_text']}).status_code==401
        checks.append('unauthenticated author query and submission refused')
        try:
            app.S.store.add_screened_post(plan['post_text'],plan=(),id='duplicate-control',
                author='@astra_demo',kind='text',text=plan['post_text'],status='queued')
        except ScreeningConflict:pass
        else:raise AssertionError('original screening reservation missing')
        checks.append('original D45 reservation refuses duplicate screening')
        after={t:app.S.store.q(f'SELECT * FROM {t}') for t in before}
        assert before==after and not app.S.worker
        checks.append('read-only checks leave posts,proofs,reservations unchanged; no worker')
    result={'at':datetime.now(timezone.utc).isoformat(),'post_id':pid,'passed':len(checks),
            'checks':checks,'new_proofs':0,'new_transactions':0,'browser_visual_check':False}
    (OUT/'app_checks.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))


if __name__=='__main__':main()
