"""Synthetic two-chunk activations from the independent Python integer kernel.

First require bitwise parity with the retained native one-block sequence. The
new chunks are candidate private activations until the frozen CLI proves them.
No model tables or existing fixture files are changed.
"""
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import numpy as np

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'results/zk60_shieldstral_export_20261026'))
import calibration_port as P

FIX=HERE/'classifier_fixture';PRIVATE=Path('/tmp/zk60-astra-classifier-owner-20261026')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    directory=FIX/'prover-export/layer_00';manifest=json.loads((directory/'manifest.json').read_text())
    words={}
    for name,meta in manifest['arrays'].items():
        path=directory/meta['file']
        if sha(path)!=meta['sha256']:raise ValueError('fixture member differs')
        words[name]=np.fromfile(path,dtype=np.dtype(meta['dtype']).newbyteorder('<')).reshape(meta['shape'])
    c=manifest['constants'];geo=SimpleNamespace(d=384,H=12,KV=4,G=3,dh=32,f=512)
    layer=P.tc.LayerInt(**{k:words[k] for k in ('wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t','exp','act')},
        cn_a=c['norm_cn_a'],cn_m=c['norm_cn_m'],tn=c['norm_tn'],ceps=c['norm_ceps'],
        norm_wrho=P.tc.norm_window(384,c['norm_tn']),
        **{k:c[k] for k in ('sh_qkv','sh_rope','sh_s','sh_o','sh_ao','sh_g','sh_u','sh_h','sh_z','f_e','f_p','f_ro','sh_r2')})
    rope=words['rope_cos'],words['rope_sin']
    def forward(x):
        rec=P.tc.Rec(1);y=P.tc.i_block(x.astype(np.int64)[None],layer,rope,rec,clamp=False,g=geo)[0]
        if rec.first[0] is not None:raise ValueError('synthetic integer activation refused: '+str(rec.first[0]))
        if np.any(y<-32768) or np.any(y>32767):raise ValueError('synthetic residual out of range')
        return y.astype('<i2')
    original=FIX/'prover-export/seq_s0'
    xin=np.fromfile(original/'x_in_L00.bin',dtype='<i2').reshape(32,384)
    xout=np.fromfile(original/'x_out_L00.bin',dtype='<i2').reshape(32,384)
    if not np.array_equal(forward(xin),xout):raise ValueError('retained native/Python sequence mismatch')
    embedding=np.fromfile(FIX/'tables/embedding_int16.bin',dtype='<i2').reshape(300,384)
    content=list(range(9,32))+list(range(33,37));ranges=[(0,23),(4,27)]
    root=PRIVATE/'multi-sequences';root.mkdir(mode=0o700,exist_ok=False)
    result={'scope':'candidate synthetic two-chunk activations; Python matches retained native sequence bitwise; fresh native proof pending',
        'content_ids':content,'ranges':ranges,'source_manifest_sha256':sha(FIX/'fixture.json'),
        'tool_sha256':sha(Path(__file__)),'integer_kernel_sha256':sha(Path(P.tc.__file__)),'sequences':[]}
    for index,(start,stop) in enumerate(ranges):
        tokens=list(range(1,9))+content[start:stop]+[32];x=embedding[tokens];y=forward(x)
        stage=root/str(index);stage.mkdir(mode=0o700)
        for name,array in (('x_in_L00.bin',x),('x_out_L00.bin',y)):
            path=stage/name;path.write_bytes(array.astype('<i2').tobytes());path.chmod(0o600)
        result['sequences'].append({'dir':str(stage),'sha256':{p.name:sha(p) for p in sorted(stage.iterdir())}})
    (HERE/'rung_chunk_inputs.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'native_python_bitwise_parity':True,'chunks':len(ranges),'tokens':len(content)}))

if __name__=='__main__':main()
