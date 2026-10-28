"""Stream tied embedding/head and directly quantized classifier margin tables.

Input is the completed dg base and its calibration checkpoints. All files are
new candidate public tables; a native loader/proof and A1 fidelity are still
required. This does not reuse another model's embedding, head or norm bounds.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import numpy as np
import calibration_port as P
from collect_stats import sha,atomic_json,widened
from shieldstral_geometry import D,LAYERS,VOCAB,MODEL,Rotation,tied_source

HERE=Path(__file__).resolve().parent


def quantized_rows(folded,limit):
    """One scale per output row, half-up signed quantization, zero rows exact."""
    folded=np.asarray(folded,dtype=np.float64)
    if not np.isfinite(folded).all():raise ValueError('nonfinite folded weights')
    scale=np.abs(folded).max(-1)/limit
    divisor=np.where(scale>0,scale,1.0)
    words=np.floor(folded/divisor[...,None]+.5)
    if np.any(words < -limit) or np.any(words > limit):raise ValueError('row quantizer overflow')
    return words,scale


def embedding_rows(raw,R,scale):
    if not np.isfinite(scale) or scale<=0:raise ValueError('invalid residual scale')
    # Match the calibration chain's float64 rotation -> float32 residual.
    residual=R.fwd(widened(raw)).astype(np.float32)
    words=np.floor(residual.astype(np.float64)/scale+.5)
    if np.any(words < -32768) or np.any(words > 32767):raise ValueError('vocabulary embedding leaves int16')
    return words.astype('<i2')


def final_norm_maxima(stats):
    ready=json.loads((stats/f'layer_{LAYERS-1:02d}/ready.json').read_text())
    path=stats/f'layer_{LAYERS-1:02d}/residual.npy'
    if sha(path)!=ready['residual_sha256']:raise ValueError('final calibration residual changed')
    residual=np.load(path,mmap_mode='r',allow_pickle=False);maxima=np.zeros(D)
    for start in range(0,len(residual),2):
        x=np.asarray(residual[start:start+2],dtype=np.float64).reshape(-1,D)
        xhat=x/np.sqrt(np.mean(x*x,axis=-1,keepdims=True)+P.tc.GEO.eps)
        maxima=np.maximum(maxima,np.abs(xhat).max(0))
    return maxima


def norm_parameters(maxima,scale,tn):
    report={}
    gain,cn,actual_tn,ceps,sy,_=P.tc.norm_site(np.ones(D),maxima,[], 'final_norm',
                P.tc.CalibOptions(margin=.5,tn=tn),scale,report,'final_norm')
    if actual_tn!=tn or not np.all(gain==127) or not 1<=cn<=1<<20:
        raise ValueError('final norm constants outside native class')
    return {'g0':127,'tn':int(tn),'ceps':int(ceps),'cn_calibrated':int(cn),
            'cn_refusal_free':1<<tn,'window_bits':int(P.tc.norm_window(D,tn)),
            'calibrated_output_scale':float(sy),'rule':'own final float calibration maxima, margin 0.5'}


def write_array(path,array,dtype):
    tmp=path.with_suffix(path.suffix+'.tmp')
    with tmp.open('wb') as stream:
        stream.write(np.asarray(array,dtype=dtype).tobytes());stream.flush();os.fsync(stream.fileno())
    os.replace(tmp,path)
    return {'file':path.name,'sha256':sha(path),'bytes':path.stat().st_size,'dtype':np.dtype(dtype).name,
            'shape':list(np.asarray(array).shape)}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--export',type=Path,default=HERE/'dg_base_t256')
    parser.add_argument('--stats',type=Path,default=HERE/'stats_t256');parser.add_argument('--vocab-chunk',type=int,default=512)
    args=parser.parse_args()
    if not 1<=args.vocab_chunk<=1024:raise ValueError('bounded vocabulary chunk required')
    root=args.export;profile=json.loads((root/'profile.json').read_text())
    layers=json.loads((root/'layers.complete.json').read_text())
    if layers['layers']!=LAYERS or sha(root/'profile.json')!=layers['profile_sha256']:
        raise ValueError('complete base export required')
    if profile['model']!=MODEL:raise ValueError('model pin differs')
    stats_complete=json.loads((args.stats/'complete.json').read_text())
    if sha(args.stats/'run.json')!=stats_complete['run_sha256']:raise ValueError('calibration provenance changed')
    base_build=json.loads((root/'build.json').read_text())
    if stats_complete['layers']!=LAYERS or base_build['stats_sha256']!=stats_complete['stats_sha256'] or \
            base_build['stats_run_sha256']!=stats_complete['run_sha256']:
        raise ValueError('token tables and base use different calibration statistics')
    for name,digest in base_build['source'].items():
        if sha(HERE/name)!=digest:raise ValueError('base calibration source changed before token IO build')
    plan={'schema':'zk60-shieldstral-token-build/1','profile_sha256':sha(root/'profile.json'),
          'stats_complete_sha256':sha(args.stats/'complete.json'),
          'sources':{p.name:sha(p) for p in (Path(__file__),HERE/'shieldstral_geometry.py',HERE/'shieldstral_weights.py')},
          'scope':'candidate tied public tables; not proof, classifier acceptance or fidelity evidence'}
    destination=root/'token_io';stage=root/'token_io.building'
    if destination.exists():
        saved=json.loads((destination/'complete.json').read_text())
        if saved['plan']!=plan:raise ValueError('token IO already exists with another plan')
        for name,digest in saved['files'].items():
            if sha(destination/name)!=digest:raise ValueError('completed token IO changed')
        print(json.dumps({'status':'already complete','out':str(destination)}));return
    stage.mkdir(exist_ok=True)
    if (stage/'build.json').exists() and json.loads((stage/'build.json').read_text())!=plan:
        raise ValueError('partial token IO build source changed')
    atomic_json(stage/'build.json',plan)
    R=Rotation();rotation=profile['metadata_out_of_proof']['rotation']
    if rotation!=R.metadata() or sha(root/'rotation_sign.bin')!=rotation['sign_sha256']:
        raise ValueError('rotation differs')
    s_in=profile['metadata_out_of_proof']['residual_scales_in'][0]
    s_out=profile['metadata_out_of_proof']['residual_scales_out'][-1]
    tn=profile['profile_constants']['norm_tn'];ceps=profile['profile_constants']['norm_ceps']
    maxima=final_norm_maxima(args.stats)
    head_norm=norm_parameters(maxima,s_out,tn)
    # The classifier's output relation requires exactly a 32-bit norm window:
    # tn=10 at width3072 and Ceps<2^40 (DESIGN_CLASSIFIER section4.1).
    classifier_norm=norm_parameters(maxima,s_out,10)
    if head_norm['ceps']!=ceps or classifier_norm['ceps']!=ceps or classifier_norm['window_bits']!=32:
        raise ValueError('final norm epsilon/window differs from the native profile')
    write_array(stage/'calib_final_xhat_rot_absmax.bin',maxima,'<f8')
    ck=P.tc.open_checkpoint();raw=ck.refs['model.embed_tokens.weight'].bf16_rows()
    norm=P.tc.tensor_f32(ck.refs['model.norm.weight']).astype(np.float64)
    scales=np.zeros(VOCAB,dtype=np.float64)
    embedding=stage/'embedding_int16.bin';head=stage/'head_int8_perrow.bin'
    # A partial stream is overwritten inside the private staging directory;
    # only the complete directory is atomically published.
    with embedding.open('wb') as ef,head.open('wb') as hf:
        for first in range(0,VOCAB,args.vocab_chunk):
            rows=raw[first:first+args.vocab_chunk]
            ef.write(embedding_rows(rows,R,s_in).tobytes())
            folded=R.fwd(widened(rows).astype(np.float64)*norm[None,:])
            words,s=quantized_rows(folded,127)
            hf.write(words.astype(np.int8).tobytes());scales[first:first+len(s)]=s
        for stream in (ef,hf):stream.flush();os.fsync(stream.fileno())
    maximum=float(scales.max())
    if maximum<=0:raise ValueError('degenerate head')
    mult=np.maximum(1,np.floor(4096*scales/maximum+.5)).astype('<i8')
    if np.any(mult>4096):raise ValueError('head multiplier overflow')
    mult_meta=write_array(stage/'head_mult12.bin',mult,'<i8')
    scales_meta=write_array(stage/'head_row_scales_f64.bin',scales,'<f8')
    prep=HERE.parent/'zk60_shieldstral_prep_20261021'
    sys.path.insert(0,str(prep/'tools'));import shieldstral_common as C
    C.setup_paths();yes,no,_,_=C.verdict_token_ids();bos=C.hf_tokenizer().token_to_id('<s>')
    pair=widened(raw[np.array([yes,no])]).astype(np.float64)
    difference=R.fwd((pair[0]-pair[1])*norm)
    margin,scale=quantized_rows(difference,32767)
    margin_meta=write_array(stage/'margin_int16.bin',margin,'<i2')
    if float(scale)<=0:raise ValueError('zero classifier difference row')
    emb_meta={'file':embedding.name,'sha256':sha(embedding),'bytes':embedding.stat().st_size,
              'shape':[VOCAB,D],'dtype':'int16','source_tensor':tied_source()}
    head_meta={'file':head.name,'sha256':sha(head),'bytes':head.stat().st_size,'shape':[VOCAB,D],'dtype':'int8'}
    atomic_json(stage/'token_io.json',{'schema':'zk60-trained-profile-export/1','kind':'token_io','model':MODEL,
        'T':profile['T'],'bos':bos,'embedding_table':emb_meta,'s_x_in_layer0':s_in,'s_x_out_layer25':s_out,
        'rotation':rotation,'rms_norm_eps':P.tc.GEO.eps,'scope':plan['scope']})
    atomic_json(stage/'head_manifest.json',{'kind':'D25 per-row int8 plus 12-bit multipliers','source_tensor':tied_source(),
        'V':VOCAB,'d':D,'bos':bos,'head_int8_perrow.bin':head_meta,'head_mult12.bin':mult_meta,
        'row_scales':scales_meta,'final_norm':head_norm,'scope':plan['scope']})
    fn={k:classifier_norm[k] for k in ('g0','tn','ceps')};fn['cn']=classifier_norm['cn_refusal_free']
    atomic_json(stage/'classifier.json',{'schema':'zk60-classifier-tables/1','bos':bos,'final_norm':fn,
        'margin_vector':{**margin_meta,'d':D,'scale':float(scale),'source_tensor':tied_source()},
        'yes_id':yes,'no_id':no,'threshold_c':0,'tau':.5,
        'real_margin_scale':float(P.b3.norm_K(fn['cn'],fn['tn'])/fn['g0']*scale),
        'final_norm_candidates':classifier_norm,'choice':'refusal-free pending A1 fidelity comparison',
        'scope':plan['scope']})
    files={p.name:sha(p) for p in sorted(stage.iterdir()) if p.is_file()}
    atomic_json(stage/'complete.json',{'plan':plan,'files':files})
    os.rename(stage,destination);ck.close()
    print(json.dumps({'status':'complete candidate tables','out':str(destination),'files':files}))


if __name__=='__main__':main()
