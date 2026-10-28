"""Independent NumPy reference for R12b: no native/Astra quantizer imported.

Creates a component fixture from pinned weights and a COPY of the A2 profile.
The chosen norm constants are public test calibration, not a fidelity claim.
Run under the resource guard. Never changes the A2 export.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import numpy as np

ROOT = Path('/home/victor/IntelligenceRegulation')
HERE = Path(__file__).resolve().parent
BASE = ROOT/'results/zk60_shieldstral_export_20261026/dg_base_t256'
CHECKPOINT = Path('/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors')
OUT = HERE/'tied-fixture'
TENSOR = 'language_model.model.embed_tokens.weight'
NORM = 'language_model.model.norm.weight'
D,V = 3072,131072

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        while data:=f.read(1<<20): h.update(data)
    return h.hexdigest()

def write_json(path,value):
    path.write_text(json.dumps(value,indent=2)+'\n')

def main():
    OUT.mkdir(exist_ok=True)
    tables=OUT/'token_io';tables.mkdir(exist_ok=True)
    profile=json.loads((BASE/'profile.json').read_text())
    assert sha(CHECKPOINT)==profile['model']['sha256']
    with CHECKPOINT.open('rb') as ck:
        n=struct.unpack('<Q',ck.read(8))[0]
        header=json.loads(ck.read(n));base=8+n
        assert header[TENSOR]['dtype']=='BF16' and header[TENSOR]['shape']==[V,D]
        assert header[NORM]['dtype']=='BF16' and header[NORM]['shape']==[D]
        def read_tensor(name):
            begin,end=header[name]['data_offsets'];ck.seek(base+begin)
            return ck.read(end-begin)
        def widen(raw):
            return (np.frombuffer(raw,dtype='<u2').astype(np.uint32)<<16).view(np.float32).astype(np.float64)
        norm=widen(read_tensor(NORM))
        signs=np.frombuffer((BASE/'rotation_sign.bin').read_bytes(),dtype='<f8')
        (OUT/'rotation_sign.bin').write_bytes(signs.tobytes())
        def rotate(rows):
            x=(np.asarray(rows,dtype=np.float64)*signs).reshape(-1,3,1024).copy()
            for bit in range(10):
                step=1<<bit
                z=x.reshape(-1,3,1024//(2*step),2,step)
                left=z[...,0,:].copy();right=z[...,1,:].copy()
                z[...,0,:]=left+right;z[...,1,:]=left-right
            return x.reshape(-1,D)/32.
        def quantize(x,scale,low,high):
            words=np.floor(x/scale+.5)
            if not np.isfinite(words).all() or np.any(words<low) or np.any(words>high):
                raise ValueError('reference quantization overflow; no clipping')
            return words
        scale=profile['metadata_out_of_proof']['residual_scales_in'][0]
        assert math.isfinite(scale) and scale>0
        scales=np.zeros(V)
        tensor_hash=hashlib.sha256()
        ck.seek(base+header[TENSOR]['data_offsets'][0])
        with (tables/'embedding_int16.bin').open('wb') as ef,(tables/'head_int8_perrow.bin').open('wb') as hf:
            for first in range(0,V,128):
                raw=ck.read(128*D*2);assert len(raw)==128*D*2
                tensor_hash.update(raw)
                rows=widen(raw).reshape(128,D)
                embedding=rotate(rows).astype(np.float32).astype(np.float64)
                ef.write(quantize(embedding,scale,-32768,32767).astype('<i2').tobytes())
                folded=rotate(rows*norm)
                row_scale=np.max(np.abs(folded),axis=1)/127
                head=quantize(folded,np.where(row_scale>0,row_scale,1.)[:,None],-127,127)
                hf.write(head.astype('i1').tobytes());scales[first:first+128]=row_scale
        assert tensor_hash.hexdigest()==profile['tied_embeddings']['sha256']
        mult=np.maximum(1,np.floor(4096*scales/scales.max()+.5)).astype('<i8')
        (tables/'head_mult12.bin').write_bytes(mult.tobytes())
        pairs=[]
        for token in [1,2]:
            ck.seek(base+header[TENSOR]['data_offsets'][0]+token*D*2)
            pairs.append(widen(ck.read(D*2)))
        difference=rotate((pairs[0]-pairs[1])*norm)[0]
        margin_scale=float(np.max(np.abs(difference))/32767)
        margin=quantize(difference,margin_scale,-32767,32767).astype('<i2')
        (tables/'margin_int16.bin').write_bytes(margin.tobytes())
    c=profile['profile_constants']
    profile['token_io_parameters']={'bos':1,'classifier_final_norm':{'g0':127,'cn':1024,'tn':10,'ceps':c['norm_ceps']},
        'head_final_norm':{'g0':127,'cn':1<<c['norm_tn'],'tn':c['norm_tn'],'ceps':c['norm_ceps']}}
    write_json(OUT/'profile.json',profile)
    source={'name':TENSOR,'sha256':tensor_hash.hexdigest()}
    def meta(name,dtype,shape):
        path=tables/name
        return {'file':name,'dtype':dtype,'shape':shape,'bytes':path.stat().st_size,'sha256':sha(path)}
    embedding=meta('embedding_int16.bin','int16',[V,D]);embedding['source_tensor']=source
    head=meta('head_int8_perrow.bin','int8',[V,D]);mult=meta('head_mult12.bin','int64',[V])
    write_json(tables/'token_io.json',{'embedding_table':embedding,'bos':1})
    write_json(tables/'head_manifest.json',{'source_tensor':source,'head_int8_perrow.bin':head,'head_mult12.bin':mult})
    result={'embedding_sha256':embedding['sha256'],'head_sha256':head['sha256'],
            'multipliers_sha256':mult['sha256'],'margin_sha256':sha(tables/'margin_int16.bin'),
            'margin_scale':margin_scale,'yes':1,'no':2,'profile_sha256':sha(OUT/'profile.json'),
            'scope':'component fixture; pinned full tensor, public test norm calibration; no trained classifier/fidelity acceptance'}
    write_json(HERE/'reference_tables.json',result)
    print(json.dumps(result),flush=True)

if __name__=='__main__':main()
