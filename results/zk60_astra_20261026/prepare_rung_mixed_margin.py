"""Public synthetic classifier margin that gives opposite chunk verdicts.

This fixture is deliberately constructed for the integration test, never a
trained classifier or a fidelity result. Native proof remains required.
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'zk60_shieldstral_export_20261026'))
import calibration_port as P

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    source=HERE/'classifier_fixture/tables';inputs=HERE/'rung_chunk_inputs.json'
    info=json.loads(inputs.read_text());classifier=json.loads((source/'classifier.json').read_text());norm=classifier['final_norm']
    ys=[]
    for seq in info['sequences']:
        path=Path(seq['dir'])/'x_out_L00.bin'
        if sha(path)!=seq['sha256'][path.name]:raise ValueError('candidate sequence changed')
        x=np.fromfile(path,dtype='<i2').astype(np.int64).reshape(1,32,384)[:,-1:]
        rec=P.tc.Rec(1)
        y,_=P.tc.i_norm(x,np.full(384,norm['g0'],dtype=np.int8),norm['cn'],norm['tn'],norm['ceps'],32,rec,'final_norm',0,False)
        if rec.first[0] is not None:raise ValueError('final norm refused')
        ys.append(y.reshape(-1))
    a,b=ys;direction=a/np.linalg.norm(a)-b/np.linalg.norm(b)
    if not np.any(direction):raise ValueError('chunks have identical normalized outputs')
    margin=np.floor(direction/max(abs(direction))*32767+.5).astype('<i2')
    dots=[int(y@margin.astype(np.int64)) for y in ys]
    if not dots[0]>0>dots[1]:raise ValueError('constructed margin did not separate chunks')
    out=HERE/'classifier_multi_tables';out.mkdir(exist_ok=False)
    for name in ('token_io.json','embedding_int16.bin'):shutil.copyfile(source/name,out/name)
    path=out/'margin_int16.bin';path.write_bytes(margin.tobytes())
    classifier['margin_vector']['sha256']=sha(path)
    (out/'classifier.json').write_text(json.dumps(classifier,indent=2)+'\n')
    result={'scope':'constructed public synthetic fixture: opposite chunk verdicts; no trained-model or native-proof claim',
        'input_manifest_sha256':sha(inputs),'tool_sha256':sha(Path(__file__)),
        'table_dir':str(out),'files':{p.name:sha(p) for p in sorted(out.iterdir())},
        'expected_chunk_verdict_bits':[1,0],'integer_margins':dots}
    (HERE/'rung_chunk_mixed_tables.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'expected_bits':[1,0],'integer_margins':dots}))

if __name__=='__main__':main()
