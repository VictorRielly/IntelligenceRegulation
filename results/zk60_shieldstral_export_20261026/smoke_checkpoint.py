"""Guarded actual-checkpoint cross-check before collecting calibration statistics."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np
import calibration_port as P
from shieldstral_geometry import MODEL, TIED, Rotation


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--out',type=Path,required=True); a=ap.parse_args()
    started=time.time()
    ck=P.tc.open_checkpoint()
    ids=np.load(Path(__file__).parent/'calibration_t256/ids.npy')[:2,:16]
    raw=ck.refs['model.embed_tokens.weight'].bf16_rows()[ids]
    x=(raw.astype(np.uint32)<<16).view(np.float32)
    W=P.tc.layer_f32(ck,0)
    got=P.tc.f_block(x,W,*P.tc.rope_f32(16))
    del W
    prep=Path(__file__).resolve().parent.parent/'zk60_shieldstral_prep_20261021/tools'
    sys.path.insert(0,str(prep)); import shieldstral_ref as ref
    model=ref.Ref('hf')
    want=model._layer(x.reshape(-1,P.tc.GEO.d),0,np.tile(np.arange(16),2),np.array([0,16,32]),None,2048).reshape(x.shape)
    model.f.close()
    err=np.abs(got-want)
    np.testing.assert_allclose(got,want,rtol=2e-5,atol=2e-5)
    R=Rotation()
    W=P.bl.load_layer(ck,0,R)
    st={}
    rotated=P.b3.f_block_stats(R.fwd(x).astype(np.float32),W,*P.tc.rope_f32(16),st)
    unrotated=R.inv(rotated).astype(np.float32)
    rot_err=np.abs(unrotated-want)
    np.testing.assert_allclose(unrotated,want,rtol=4e-5,atol=4e-5)
    result={'status':'PASS','model':MODEL,'tied_tensor':TIED,'sequences':2,'T':16,'layers':1,
            'float_reference_max_abs_error':float(err.max()),'rotation_max_abs_error':float(rot_err.max()),
            'full_score_max':float(st['raw_kv'].max()),'causal_score_max':st['raw_causal'],
            'seconds':time.time()-started,'scope':'actual pinned layer-0 float cross-check; no integer fidelity/proof claim'}
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result),flush=True)
    ck.close()


if __name__=='__main__':main()
