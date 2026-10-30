"""Add short synthetic inputs to the retained model-bound development fixture."""
import hashlib
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import numpy as np

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE=HERE/'classifier_c2_fixture'
DEST=HERE/'classifier_c3_fixture'
PRIVATE=Path('/tmp/zk60-astra-classifier-c3-20261029')
sys.path.insert(0,str(ROOT/'results/zk60_shieldstral_export_20261026'))
import calibration_port as P

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert not DEST.exists() and not PRIVATE.exists(), 'never overwrite an existing fixture'
    source=json.loads((SOURCE/'fixture.json').read_text())
    for name,digest in source['files'].items():assert sha(SOURCE/name)==digest
    assert sha(Path(P.tc.__file__))==source['integer_kernel_sha256']
    directory=SOURCE/'prover-export/layer_00'
    meta=json.loads((directory/'manifest.json').read_text());words={}
    for key,info in meta['arrays'].items():
        path=directory/info['file'];assert sha(path)==info['sha256']
        words[key]=np.fromfile(path,dtype=np.dtype(info['dtype']).newbyteorder('<')).reshape(info['shape'])
    c=meta['constants'];geometry=SimpleNamespace(d=384,H=12,KV=4,G=3,dh=32,f=512)
    layer=P.tc.LayerInt(**{k:words[k] for k in ('wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t','exp','act')},
        cn_a=c['norm_cn_a'],cn_m=c['norm_cn_m'],tn=c['norm_tn'],ceps=c['norm_ceps'],norm_wrho=P.tc.norm_window(384,c['norm_tn']),
        **{k:c[k] for k in ('sh_qkv','sh_rope','sh_s','sh_o','sh_ao','sh_g','sh_u','sh_h','sh_z','f_e','f_p','f_ro','sh_r2')})
    def forward(x):
        rec=P.tc.Rec(1)
        y=P.tc.i_block(x.astype(np.int64)[None],layer,(words['rope_cos'],words['rope_sin']),rec,clamp=False,g=geometry)[0]
        assert rec.first[0] is None and np.all((y>=-32768)&(y<=32767))
        return y.astype('<i2')
    # Recheck an independently retained native full-length input/output before
    # using this numerical implementation for short-item witness candidates.
    full=source['cases'][0]
    for directory,hashes in zip(full['sequence_dirs'],full['sequence_sha256']):
        for name,digest in hashes.items():assert sha(Path(directory)/name)==digest
        x=np.fromfile(Path(directory)/'x_in_L00.bin',dtype='<i2').reshape(32,384)
        y=np.fromfile(Path(directory)/'x_out_L00.bin',dtype='<i2').reshape(32,384)
        assert np.array_equal(forward(x),y)
    embedding=np.fromfile(SOURCE/'tables/embedding_int16.bin',dtype='<i2').reshape(300,384)
    margin=np.fromfile(SOURCE/'tables/margin_int16.bin',dtype='<i2').astype(np.int64)
    DEST.mkdir();PRIVATE.mkdir(mode=0o700);cases=[]
    for n in (1,11,22):
        ids=list(range(9,9+n));prompt=list(range(1,9))+ids+[32]+[2]*(23-n)
        x=embedding[prompt];y=forward(x);rec=P.tc.Rec(1);row=8+n
        z,_=P.tc.i_norm(y.astype(np.int64)[None,row:row+1],np.full(384,127,dtype=np.int8),2048,11,33554467,32,rec,'final_norm',0,False)
        assert rec.first[0] is None
        seq=PRIVATE/f'short{n}-seq-0';seq.mkdir(mode=0o700)
        for name,array in [('x_in_L00.bin',x),('x_out_L00.bin',y)]:
            p=seq/name;p.write_bytes(array.tobytes());p.chmod(0o600)
        cases.append({'name':f'short{n}','content_ids':ids,'sequence_dirs':[str(seq)],
                      'sequence_sha256':[{p.name:sha(p) for p in seq.iterdir()}],
                      'margins':[int(z.reshape(-1)@margin)],'item_length':9+n,'pad_positions':23-n,'verdict_row':row})
    result={'schema':'pm-r-c3-development-fixture/1','source_fixture_sha256':sha(SOURCE/'fixture.json'),
            'scope':'Synthetic R-C3 candidate witnesses; actual native verification required',
            'tool_sha256':sha(Path(__file__)),'integer_kernel_sha256':source['integer_kernel_sha256'],
            'private_root':str(PRIVATE),'cases':cases+source['cases']}
    (DEST/'fixture.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'cases':[c['name'] for c in result['cases']],'native_proofs_pending':True}))

if __name__=='__main__':main()
