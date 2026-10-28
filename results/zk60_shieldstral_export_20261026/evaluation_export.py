"""Resumable S2 evaluator artifact, deliberately distinct from a native export.

The native R13 file interface is still being integrated. These NPZ files do not
carry profile.json, so a native loader cannot accidentally interpret S2 words
using legacy arithmetic. Every base, statistics and conversion source is pinned.
"""
import argparse
import json
import os
from pathlib import Path
import pickle
import time
import numpy as np
import calibration_port as P
from accuracy_stack import BITS,MODS,real_words,convert
from collect_stats import sha,atomic_json
from shieldstral_geometry import LAYERS,Rotation,rope_tables

HERE=Path(__file__).resolve().parent


def source_pins():
    files=[Path(__file__),HERE/'accuracy_stack.py',HERE/'shieldstral_geometry.py',HERE/'shieldstral_weights.py',
           HERE/'calibration_port.py',HERE/'signed_word_domain.py',HERE/'S2_DOMAIN_AMENDMENT.json',
           *sorted((HERE/'vendor').glob('*.py'))]
    return {str(p.relative_to(HERE)):sha(p) for p in files}


class EvaluationExport:
    def __init__(self,root):
        self.root=Path(root);self.plan=json.loads((self.root/'evaluation.json').read_text())
        if self.plan['schema']!='zk60-shieldstral-s2-evaluation/1' or self.plan['sources']!=source_pins():
            raise ValueError('evaluation format or conversion sources changed')
        done=json.loads((self.root/'complete.json').read_text())
        if done['layers']!=LAYERS or sha(self.root/'evaluation.json')!=done['plan_sha256']:
            raise ValueError('incomplete evaluation export')
        self.base=Path(self.plan['base']);self.profile=json.loads((self.base/'profile.json').read_text())
        if sha(self.base/'profile.json')!=self.plan['base_profile_sha256']:raise ValueError('base profile changed')
        self.layer_hashes=done['layers_sha256']

    def layer(self,index,T):
        directory=self.root/f'layer_{index:02d}'
        if sha(directory/'ready.json')!=self.layer_hashes[index]:raise ValueError('S2 layer checkpoint changed')
        ready=json.loads((directory/'ready.json').read_text())
        for name,digest in ready['files'].items():
            if sha(directory/name)!=digest:raise ValueError('S2 layer data changed')
        meta=json.loads((directory/'arithmetic.json').read_text())
        with np.load(directory/'arrays.npz',allow_pickle=False) as arrays:
            words={k[3:]:arrays[k] for k in arrays.files if k.startswith('w__')}
            extra={k[7:]:arrays[k] for k in arrays.files if k.startswith('extra__')}
        # Numerical full-item comparisons include A1 prompts longer than T256.
        # This does not register or claim a native profile at those lengths.
        constants=meta['constants'];cos,sin=rope_tables(T,int(constants['f_ro']))
        words['rope_cos']=cos.reshape(-1);words['rope_sin']=sin.reshape(-1)
        model=P.fl.LayerModel({'w':words,'c':constants},T,mods=MODS)
        model.mult={site:(extra['mult_'+site].astype(np.float64),bits) for site,bits in meta['mult_bits'].items() if bits}
        model.gate_pc=(extra['group_input_exponents'],extra['group_output_exponents'],np.empty((0,0)),False)
        return model


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--base',type=Path,default=HERE/'dg_base_t256')
    parser.add_argument('--stats',type=Path,default=HERE/'stats_t256');parser.add_argument('--out',type=Path,default=HERE/'s2_evaluation_t256')
    parser.add_argument('--max-minutes',type=float,default=25);args=parser.parse_args()
    completion=json.loads((args.base/'layers.complete.json').read_text())
    if completion['layers']!=LAYERS or sha(args.base/'profile.json')!=completion['profile_sha256']:
        raise ValueError('complete base export required')
    stats_complete=json.loads((args.stats/'complete.json').read_text())
    base_plan=json.loads((args.base/'build.json').read_text())
    if sha(args.stats/'stats.pkl')!=base_plan['stats_sha256'] or stats_complete['stats_sha256']!=base_plan['stats_sha256']:
        raise ValueError('S2 and base calibration statistics differ')
    for name,digest in base_plan['source'].items():
        if sha(HERE/name)!=digest:raise ValueError('base calibration sources changed')
    with (args.stats/'stats.pkl').open('rb') as stream:statistics=pickle.load(stream)
    base=P.fl.Export(args.base);R=Rotation();plan={'schema':'zk60-shieldstral-s2-evaluation/1',
        'base':str(args.base.resolve()),'base_profile_sha256':completion['profile_sha256'],'stats_sha256':base_plan['stats_sha256'],
        'sources':source_pins(),'requested_mult_bits':BITS,'mods':sorted(MODS),
        'scope':'numerical S2 evaluator only; native R13 export/acceptance and verdict fidelity still required'}
    args.out.mkdir(parents=True,exist_ok=True)
    if (args.out/'evaluation.json').exists():
        if json.loads((args.out/'evaluation.json').read_text())!=plan:raise ValueError('S2 resume plan changed')
    else:atomic_json(args.out/'evaluation.json',plan)
    started=time.time();checkpoint=None;hashes=[]
    for layer in range(LAYERS):
        stage=args.out/f'layer_{layer:02d}';stage.mkdir(exist_ok=True);ready=stage/'ready.json'
        if ready.exists():
            for name,digest in json.loads(ready.read_text())['files'].items():
                if sha(stage/name)!=digest:raise ValueError('S2 completed layer changed')
        else:
            if time.time()-started>args.max_minutes*60:
                print(json.dumps({'status':'timebox','next_layer':layer}),flush=True);return 3
            if checkpoint is None:checkpoint=P.tc.open_checkpoint()
            tick=time.time();base_layer=base.layer(layer)
            scale_file=args.base/f'layer_{layer:02d}/calibration_scales.npz'
            expected=json.loads((args.base/f'layer_{layer:02d}/ready.json').read_text())['scales_sha256']
            if sha(scale_file)!=expected:raise ValueError('exact solver scales changed')
            with np.load(scale_file,allow_pickle=False) as scales:diag={k:scales[k] for k in scales.files}
            weights=P.bl.load_layer(checkpoint,layer,R)
            real=real_words(weights,base_layer,diag);del weights,diag
            integer,mult,groups,meta,extra=convert(base_layer,real,statistics[layer]);del real,base_layer,mult,groups
            if meta['mult_bits']!=BITS or meta['group_report']['outside_registry']:
                raise ValueError('S2 arithmetic left the declared multiplier/table registry')
            meta['constants']=integer['c'];atomic_json(stage/'arithmetic.json',meta)
            payload={**{'w__'+k:v for k,v in integer['w'].items()},**{'extra__'+k:v for k,v in extra.items()}}
            temporary=stage/'arrays.tmp.npz';np.savez(temporary,**payload);os.replace(temporary,stage/'arrays.npz')
            del integer,extra,payload
            atomic_json(ready,{'layer':layer,'seconds':time.time()-tick,
                'files':{name:sha(stage/name) for name in ('arrays.npz','arithmetic.json')}})
            print(json.dumps({'layer':layer,'seconds':time.time()-tick}),flush=True)
        hashes.append(sha(ready))
    if checkpoint is not None:checkpoint.close()
    atomic_json(args.out/'complete.json',{'layers':LAYERS,'layers_sha256':hashes,'plan_sha256':sha(args.out/'evaluation.json')})
    return 0


if __name__=='__main__':raise SystemExit(main())
