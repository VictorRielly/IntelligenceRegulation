"""Guarded, resumable dg base calibration for Shieldstral's chosen S2 stack.

The base is the input to c2/group-SiLU/width conversion, as in fp_variant.py.
It is not the final accuracy-stack export. Native acceptance also requires the
tied embedding/head files and sequence checks, produced by later stages.
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
from collect_stats import sha, atomic_json
from shieldstral_geometry import LAYERS, Rotation, profile_model_fields

HERE=Path(__file__).resolve().parent


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--stats',type=Path,default=HERE/'stats_t256')
    ap.add_argument('--out',type=Path,default=HERE/'dg_base_t256')
    ap.add_argument('--T',type=int,choices=[128,256],default=256)
    ap.add_argument('--max-minutes',type=float,default=25)
    a=ap.parse_args()
    complete=json.loads((a.stats/'complete.json').read_text())
    if complete['layers']!=LAYERS or sha(a.stats/'stats.pkl')!=complete['stats_sha256']:
        raise ValueError('full 26-layer calibration statistics required')
    if sha(a.stats/'run.json')!=complete['run_sha256']:raise ValueError('statistics provenance changed')
    with (a.stats/'stats.pkl').open('rb') as f:stats=pickle.load(f)
    if len(stats)!=LAYERS or any(st['excluded_total'] for st in stats):raise ValueError('incomplete/excluded calibration')
    # Same dg choices as fp_variant: per-layer norm/tables/free shifts, one
    # residual scale, and no weight-noise floors. With these choices all
    # prepass decisions are per layer; its global scale is determined by the
    # range statistics alone. Avoid solving every layer three times.
    var=P.b3.variant_by_name('dg',rotate=1,margin=.5)
    var.tn=9;var.cn_max=1<<20
    rin,rout=P.bl.range_needs(stats,var)
    sin,sout=P.bl.residual_schedule(rin,rout,'global')
    glob=P.b3.Globals(s_in=sin,s_out=sout)
    sources=[Path(__file__),HERE/'shieldstral_geometry.py',HERE/'shieldstral_weights.py',HERE/'calibration_port.py',
             *sorted((HERE/'vendor').glob('*.py'))]
    provenance={'stats_sha256':complete['stats_sha256'],'stats_run_sha256':complete['run_sha256'],
        'T':a.T,'variant':var.__dict__,'source':{str(p.relative_to(HERE)):sha(p) for p in sources},
        'residual_scales_in':sin,'residual_scales_out':sout}
    # JSON canonicalization makes tuple/list provenance round-trip identically.
    provenance=json.loads(json.dumps(provenance))
    a.out.mkdir(parents=True,exist_ok=True)
    plan=a.out/'build.json'
    if plan.exists():
        if json.loads(plan.read_text())!=provenance:raise ValueError('resume build parameters changed')
    else:atomic_json(plan,provenance)
    ck=P.tc.open_checkpoint();R=Rotation();started=time.time();layers=[];constants=[]
    for l in range(LAYERS):
        directory=a.out/f'layer_{l:02d}';ready=directory/'ready.json'
        if ready.exists():
            info=json.loads(ready.read_text())
            if sha(directory/'manifest.json')!=info['manifest_sha256']:raise ValueError('layer manifest changed')
            man=json.loads((directory/'manifest.json').read_text())
            for name,meta in man['arrays'].items():
                if sha(directory/meta['file'])!=meta['sha256']:raise ValueError(f'layer {l} {name} changed')
            if sha(directory/'calibration_scales.npz')!=info['scales_sha256']:raise ValueError('layer scales changed')
        else:
            if time.time()-started>a.max_minutes*60:
                print(json.dumps({'status':'timebox','next_layer':l}),flush=True);return 3
            tick=time.time();W=P.bl.load_layer(ck,l,R)
            layer,report=P.b3.solve_layer(W,stats[l],var,sin[l],sout[l],glob,{})
            del W
            man=P.bl.export_layer(a.out,l,layer,report,a.T,var)
            man['tables']['rope']['generator']='Shieldstral YaRN float64, factor16/original16384/beta32,1/mscale1,1; same native digest framing'
            atomic_json(directory/'manifest.json',man)
            np.savez(directory/'calibration_scales.npz',**layer.diag)
            atomic_json(directory/'calibration_report.json',report)
            info={'layer':l,'seconds':time.time()-tick,'manifest_sha256':sha(directory/'manifest.json'),
                  'scales_sha256':sha(directory/'calibration_scales.npz'),
                  'weights_clipped':report.get('weights_clipped',{})}
            atomic_json(ready,info);print(json.dumps(info),flush=True)
            del layer,report
        constants.append(man['constants'])
        layers.append({'layer':l,'dir':directory.name,'manifest_sha256':info['manifest_sha256']})
    raw=R.sign.astype('<f8').tobytes();(a.out/'rotation_sign.bin').write_bytes(raw)
    uniform={k:constants[0][k] if all(c[k]==constants[0][k] for c in constants) else None for k in constants[0]}
    profile={'schema':'zk60-trained-profile-export/1','kind':'profile','variant':'shieldstral_dg_rot1_base',
        **profile_model_fields(a.T),'variant_options':var.__dict__,
        'calibration_tool':{'path':str(Path(__file__).relative_to(HERE.parents[1])),'sha256':provenance['source']},
        'profile_constants':uniform,'per_layer_constants_differ':sorted(k for k,v in uniform.items() if v is None),
        'layers':layers,'sequences':[],
        'metadata_out_of_proof':{'residual_scales_in':sin,'residual_scales_out':sout,'rotation':R.metadata()},
        'scope':'dg base for S2 conversion; token IO, integer fidelity and native acceptance remain pending'}
    atomic_json(a.out/'profile.json',profile)
    atomic_json(a.out/'layers.complete.json',{'layers':LAYERS,'profile_sha256':sha(a.out/'profile.json')})
    ck.close();return 0


if __name__=='__main__':raise SystemExit(main())
