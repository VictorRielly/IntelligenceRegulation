"""Guarded, layer-resumable Shieldstral float calibration with complete statistics.

No sequence exclusions. All score pairs are included. Gate statistics include all
six policies. Vocabulary-wide layer-0 input/norm/Q/K/V maxima are merged once.
Each completed layer has a hash-checked output and statistics checkpoint. A time
box exits 3 between layers, so a new guarded leaf can resume without lost work.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import pickle
import time
import numpy as np
import calibration_port as P
from shieldstral_geometry import D, LAYERS, MODEL, Rotation, VOCAB

HERE=Path(__file__).resolve().parent


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def atomic_json(path,obj):
    tmp=path.with_suffix('.tmp')
    with tmp.open('w') as f:
        json.dump(obj,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
    os.replace(tmp,path)


def widened(raw):return (raw.astype(np.uint32)<<16).view(np.float32)


def vocab0(ck,R,W,st,chunk=256):
    g=P.tc.GEO
    raw=ck.refs['model.embed_tokens.weight'].bf16_rows()
    before={k:float(np.max(st[k])) for k in ('xa_max','q_pair','k_pair','v_max','x_amax')}
    for first in range(0,VOCAB,chunk):
        x=R.fwd(widened(raw[first:first+chunk])).astype(np.float32)
        xa=P.tc.f_xhat(x,g.eps)
        q=(xa@W['self_attn.q_proj.weight'].T).reshape(-1,g.H,g.dh)
        k=(xa@W['self_attn.k_proj.weight'].T).reshape(-1,g.KV,g.dh)
        v=xa@W['self_attn.v_proj.weight'].T
        pair=lambda a:np.sqrt(a[...,:g.half].astype(np.float64)**2+a[...,g.half:].astype(np.float64)**2).max(0)
        st['xa_max']=np.maximum(st['xa_max'],np.abs(xa).max(0))
        st['q_pair']=np.maximum(st['q_pair'],pair(q))
        st['k_pair']=np.maximum(st['k_pair'],pair(k))
        st['v_max']=np.maximum(st['v_max'],np.abs(v).max(0))
        st['x_amax']=max(st['x_amax'],float(np.abs(x).max()))
    return {k:[before[k],float(np.max(st[k]))] for k in before}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--input',type=Path,default=HERE/'calibration_t256')
    ap.add_argument('--out',type=Path,default=HERE/'stats_t256')
    ap.add_argument('--chunk',type=int,default=2)
    ap.add_argument('--max-minutes',type=float,default=25)
    ap.add_argument('--layers',type=int,default=LAYERS)
    a=ap.parse_args()
    if not 1<=a.layers<=LAYERS or not 1<=a.chunk<=4:raise ValueError('invalid layers/chunk')
    ids=np.load(a.input/'ids.npy',allow_pickle=False)
    data=json.loads((a.input/'input.json').read_text())
    if ids.shape!=(data['sequences'],data['T']) or hashlib.sha256(ids.astype('<i8').tobytes()).hexdigest()!=data['ids_sha256']:
        raise ValueError('calibration input hash or shape mismatch')
    files=[Path(__file__),HERE/'shieldstral_geometry.py',HERE/'shieldstral_weights.py',HERE/'calibration_port.py',*sorted((HERE/'vendor').glob('*.py'))]
    signature={'source':{str(p.relative_to(HERE)):sha(p) for p in files},'input':sha(a.input/'input.json'),
               'model':MODEL,'rotation':Rotation().metadata(),'scope':'float calibration; no evaluation/proof claim'}
    a.out.mkdir(parents=True,exist_ok=True)
    manifest=a.out/'run.json'
    if manifest.exists():
        if json.loads(manifest.read_text())!=signature:raise ValueError('resume source/input signature changed')
    else:atomic_json(manifest,signature)
    started=time.time();R=Rotation();ck=P.tc.open_checkpoint()
    P.fl._CK=ck
    initial=a.out/'input_rotated.npy'
    if not (a.out/'input.ready.json').exists():
        dest=np.lib.format.open_memmap(initial.with_suffix('.tmp.npy'),mode='w+',dtype=np.float32,shape=(*ids.shape,D))
        for first in range(0,len(ids),a.chunk):
            dest[first:first+a.chunk]=R.fwd(P.fl.emb_rows(ids[first:first+a.chunk])).astype(np.float32)
        dest.flush();del dest
        os.replace(initial.with_suffix('.tmp.npy'),initial)
        atomic_json(a.out/'input.ready.json',{'sha256':sha(initial)})
    elif sha(initial)!=json.loads((a.out/'input.ready.json').read_text())['sha256']:
        raise ValueError('initial residual checkpoint hash mismatch')
    source=initial; stats=[];rope=P.tc.rope_f32(data['T'])
    for layer in range(a.layers):
        stage=a.out/f'layer_{layer:02d}';stage.mkdir(exist_ok=True)
        ready=stage/'ready.json';target=stage/'residual.npy';sp=stage/'statistics.pkl'
        if ready.exists():
            info=json.loads(ready.read_text())
            if sha(target)!=info['residual_sha256'] or sha(sp)!=info['statistics_sha256']:
                raise ValueError(f'layer {layer} checkpoint changed')
            with sp.open('rb') as f:stats.append(pickle.load(f))
            source=target;continue
        if time.time()-started>a.max_minutes*60:
            print(json.dumps({'status':'timebox','next_layer':layer}),flush=True);return 3
        tick=time.time();W=P.bl.load_layer(ck,layer,R);st={}
        x=np.load(source,mmap_mode='r',allow_pickle=False)
        temp=target.with_suffix('.tmp.npy')
        dest=np.lib.format.open_memmap(temp,mode='w+',dtype=np.float32,shape=x.shape)
        for first in range(0,len(ids),a.chunk):
            dest[first:first+a.chunk]=P.b3.f_block_stats(x[first:first+a.chunk],W,*rope,st)
        report=vocab0(ck,R,W,st) if layer==0 else None
        del W,x
        st=P.b3.finalize_stats(st)
        if st['rows']!=ids.size or st['excluded_total']!=0:raise ValueError('incomplete statistics')
        dest.flush();del dest;os.replace(temp,target)
        with sp.with_suffix('.tmp').open('wb') as f:pickle.dump(st,f);f.flush();os.fsync(f.fileno())
        os.replace(sp.with_suffix('.tmp'),sp)
        info={'layer':layer,'seconds':time.time()-tick,'residual_sha256':sha(target),'statistics_sha256':sha(sp),
              'score_all_max':float(st['raw_kv'].max()),'score_causal_max':st['raw_causal'],
              'gate_absmax':st['gate_absmax_all_sequences'],'rows':st['rows'],'vocab0':report}
        atomic_json(ready,info);print(json.dumps(info),flush=True)
        stats.append(st);source=target
    if a.layers==LAYERS:
        with (a.out/'stats.tmp').open('wb') as f:pickle.dump(stats,f);f.flush();os.fsync(f.fileno())
        os.replace(a.out/'stats.tmp',a.out/'stats.pkl')
        atomic_json(a.out/'complete.json',{'layers':LAYERS,'stats_sha256':sha(a.out/'stats.pkl'),'run_sha256':sha(manifest)})
    ck.close();return 0


if __name__=='__main__':raise SystemExit(main())
