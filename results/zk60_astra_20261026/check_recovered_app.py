"""Read-only ASGI checks of the recovered real post after P7/P8 promotion."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sqlite3
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APP = ROOT/'apps/proven-media'
OUT = HERE/'real_app_demo_1'
complete = json.loads((OUT/'complete.json').read_text())
private = Path(complete['recovery']['private_root'])
os.environ.update(PM_PRIVATE_DIR=str(private), PM_PUBLIC_DIR=str(OUT/'public'),
                  PM_PROVER='shieldstral', PM_NO_WORKER='1', PM_PUBLISHER='base-sepolia',
                  PM_SEPOLIA_CONFIG=str(APP/'.testnet-private/sepolia.json'))
sys.path.insert(0,str(APP))
from fastapi.testclient import TestClient
from proven_media import app, manifest, records
from proven_media.store import ScreeningConflict


def assert_no_timings(value):
    if isinstance(value,dict):
        assert not {'timings','work_s','proved_at'} & value.keys()
        for child in value.values():assert_no_timings(child)
    elif isinstance(value,list):
        for child in value:assert_no_timings(child)


def main():
    pid=complete['post_id']; checks=[]
    with TestClient(app.app) as client:
        before={table:app.S.store.q(f'SELECT * FROM {table}') for table in ('posts','jobs','screenings','chunk_proofs')}
        response=client.get('/api/posts/'+pid)
        assert response.status_code==200,response.text
        view=response.json()
        assert view['status']=='published' and view['text']==complete['post_text']
        checks.append('public verified post restored')
        for audience in ('adult','minor'):
            response=client.get('/api/feed',params={'audience':audience})
            assert response.status_code==200,response.text
            data=response.json()
            posts=data if isinstance(data,list) else data['posts']
            assert any(p['id']==pid for p in posts),data
            checks.append(audience+' feed contains all-three-no post')
        response=client.get('/api/posts/'+pid+'/record.json')
        assert response.status_code==200,response.text
        record=response.json()
        assert_no_timings(record)
        assert record['receipt']['segments']==84
        assert all(v['value']=='no' and v['proof']=='accepted' for v in record['labels'].values())
        checks.append('real record has three proved labels and no public runtime timing')
        response=client.get('/api/posts/'+pid+'/manifest.json')
        assert response.status_code==200,response.text
        signed=response.json()
        assert signed['recovery']['original_signature_recovered'] is False
        assert signed['issuer']['public_key']==complete['recovery']['new_manifest_key']
        checked=manifest.verify_manifest(signed,app.S.publisher,expected_public_key=signed['issuer']['public_key'])
        assert checked['accepted'] and not checked['pending_anchor'],checked
        checks.append('explicit recovery key and all three confirmed publication references verify')
        response=client.get('/api/publisher-key')
        assert response.status_code==200 and response.json()['public_key']==signed['issuer']['public_key']
        checks.append('publisher endpoint matches explicitly rotated development key')
        for url in ('/api/submissions?author=astra_demo','/api/submissions?author=@astra_demo'):
            assert client.get(url).status_code==401
        checks.append('claimed author query grants no access')
        assert client.post('/api/posts',data={'author':'astra_demo','text':complete['post_text']}).status_code==401
        checks.append('unauthenticated mutation refused')
        try:
            app.S.store.add_screened_post(complete['post_text'],plan=(),id='recovery-duplicate-control',
                author='@astra_demo',kind='text',text=complete['post_text'],status='queued')
        except ScreeningConflict:
            pass
        else:
            raise AssertionError('duplicate reservation was lost')
        checks.append('D45 original reservation refuses duplicate screening')
        after={table:app.S.store.q(f'SELECT * FROM {table}') for table in before}
        assert after==before,'read-only checks changed post/proof/reservation state'
        assert not app.S.worker
        checks.append('no worker, proof, transaction, or retained post mutation')
    result={'at':datetime.now(timezone.utc).isoformat(),'passed':len(checks),'checks':checks,
            'post_id':pid,'new_proofs':0,'new_transactions':0,'browser_visual_check':False}
    (OUT/'recovery-20261030/app_checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':main()
