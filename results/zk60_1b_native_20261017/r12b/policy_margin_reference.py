"""Count actual Shieldstral yes/no margin-coordinate refusals, without clipping."""
from pathlib import Path
import hashlib
import json
import struct
import numpy as np
import reference_tables as R

def main():
    profile=json.loads((R.OUT/'profile.json').read_text())
    assert R.sha(R.CHECKPOINT)==profile['model']['sha256']
    policy=R.ROOT/'results/zk60_shieldstral_prep_20261021/template_check.json'
    ids=json.loads(policy.read_text())['verdict_tokens'];yes,no=ids['yes_id'],ids['no_id']
    with R.CHECKPOINT.open('rb') as f:
        length=struct.unpack('<Q',f.read(8))[0];header=json.loads(f.read(length));base=8+length
        def row(name,index=None):
            meta=header[name];assert meta['dtype']=='BF16'
            offset=base+meta['data_offsets'][0]+(index or 0)*R.D*2
            f.seek(offset);data=f.read(R.D*2);assert len(data)==R.D*2
            return (np.frombuffer(data,dtype='<u2').astype(np.uint32)<<16).view(np.float32).astype(np.float64)
        difference=(row(R.TENSOR,yes)-row(R.TENSOR,no))*row(R.NORM)
    signs=np.frombuffer((R.OUT/'rotation_sign.bin').read_bytes(),dtype='<f8')
    value=(difference*signs).reshape(3,1024).copy()
    for bit in range(10):
        step=1<<bit;chunks=value.reshape(3,1024//(2*step),2,step)
        lo=chunks[...,0,:].copy();hi=chunks[...,1,:].copy()
        chunks[...,0,:]=lo+hi;chunks[...,1,:]=lo-hi
    value=value.reshape(R.D)/32.
    scale=float(np.abs(value).max()/32767)
    rounded=np.floor(value/scale+.5)
    refusals=int(np.sum((rounded < -32767)|(rounded > 32767)|~np.isfinite(rounded)))
    assert refusals==0,'margin quantization must refuse; clipping is forbidden'
    words=rounded.astype('<i2')
    (R.HERE/'policy_margin_int16.bin').write_bytes(words.tobytes())
    result={'yes':yes,'no':no,'scale':scale,'coordinates':R.D,'refused_coordinates':refusals,
        'quantized_min':int(words.min()),'quantized_max':int(words.max()),
        'margin_sha256':hashlib.sha256(words.tobytes()).hexdigest(),
        'policy_source_sha256':R.sha(policy),'profile_sha256':R.sha(R.OUT/'profile.json'),
        'scope':'COUNTED quantizer endpoints on actual public model difference row; not an inference refusal/fidelity evaluation'}
    R.write_json(R.HERE/'policy_margin_reference.json',result)
    print(json.dumps(result),flush=True)

if __name__=='__main__':main()
