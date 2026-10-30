"""Check actual Astra table bytes against the successful native recomputation."""
from pathlib import Path
import hashlib
import json
import datetime
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026/dg_r12b_t256'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        while data:=stream.read(1<<20):h.update(data)
    return h.hexdigest()

def main():
    stem=sys.argv[1] if len(sys.argv)>1 else 'astra-tables'
    record=json.loads((HERE/f'{stem}.guard.json').read_text())
    assert record['exit']==0 and record['child_rc']==0 and not record.get('guard_killed')
    events=[json.loads(s) for s in (HERE/f'{stem}.log').read_text().splitlines() if s.startswith('{')]
    assert len(events)==1
    derived=events[0]
    assert sha(EXPORT/'profile.json')==derived['profile_sha256']
    td=EXPORT/'token_io'
    tio=json.loads((td/'token_io.json').read_text())
    head=json.loads((td/'head_manifest.json').read_text())
    classifier=json.loads((td/'classifier.json').read_text())
    params=json.loads((EXPORT/'profile.json').read_text())['token_io_parameters']
    assert classifier['bos']==params['bos']==derived['bos']
    assert classifier['final_norm']==params['classifier_final_norm']
    specifications=[('embedding_int16.bin','embedding_sha256',tio['embedding_table'],'int16',[131072,3072]),
        ('head_int8_perrow.bin','head_sha256',head['head_int8_perrow.bin'],'int8',[131072,3072]),
        ('head_mult12.bin','multipliers_sha256',head['head_mult12.bin'],'int64',[131072]),
        ('margin_int16.bin','margin_sha256',classifier['margin_vector'],'int16',[3072])]
    files={}
    for name,key,metadata,dtype,shape in specifications:
        assert metadata['dtype']==dtype and metadata['shape']==shape,name
        got=sha(td/name)
        assert got==derived[key]==metadata['sha256'],name
        files[name]=got
    assert sha(EXPORT/'profile.json')==derived['profile_sha256']
    result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'MEASURED actual export-table bytes equal native checkpoint derivation; no classifier/fidelity/privacy acceptance',
        'profile_sha256':derived['profile_sha256'],'files':files,'bos_and_classifier_norm_match_profile':True}
    destination='ASTRA_TABLES_CROSSCHECK.json' if stem=='astra-tables' else 'ASTRA_TABLES_CROSSCHECK_r2.json'
    (HERE/destination).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()
