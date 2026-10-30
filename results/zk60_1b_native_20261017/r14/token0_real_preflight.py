"""Fast token0 causal preflight, not a full T128 reference or native proof."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,importlib.util,json,sys
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026/native_low_h24_t128'
REFERENCE=ROOT/'results/zk60_d24_review_20261017/r13/reviewer_export_reference.py'
OUT=HERE/'TOKEN0_REAL_INPUT_PREFLIGHT.json'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()
assert not OUT.exists()
assert sha(REFERENCE)=='d7c175e154cef761e7e574e417c6979634e05243e6abf0357fb3cb2c7cdfe4ac'
assert sha(EXPORT/'profile.json')=='2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
spec=importlib.util.spec_from_file_location('review',REFERENCE)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
profile=json.loads((EXPORT/'profile.json').read_text())
seed=ROOT/'results/zk60_d24_review_20261017/r13/shield_input_L00.bin'
x=np.fromfile(seed,dtype='<i2').reshape(256,3072)[:1].astype(np.int64)
records=[];refusal=None
for k,row in enumerate(profile['layers']):
    manifest_path=EXPORT/row['dir']/'manifest.json'
    assert sha(manifest_path)==row['manifest_sha256']
    manifest=json.loads(manifest_path.read_text())
    for name,array in manifest['arrays'].items():
        assert sha(manifest_path.parent/array['file'])==array['sha256']
    weight_names = {"wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t"}
    dtypes = {"int8": np.dtype("i1"), "int16": np.dtype("<i2"), "int64": np.dtype("<i8")}
    layer = {"c": manifest["constants"]}
    for name, array in manifest["arrays"].items():
        path = manifest_path.parent / array["file"]
        dtype = dtypes[array["dtype"]]
        assert path.stat().st_size == int(np.prod(array["shape"])) * dtype.itemsize
        if name in weight_names:
            assert array["dtype"] == "int8"
            layer[name] = np.memmap(path, mode="r", dtype=dtype, shape=tuple(array["shape"]))
        else:
            layer[name] = np.fromfile(path, dtype=dtype).reshape(array["shape"]).astype(np.int64)
    assert weight_names <= layer.keys()
    try:
        trace=module.block(layer,x,'h24',32,8,128)
    except module.Refusal as error:
        refusal={'layer':k,'error':str(error)}
        print('TOKEN0 RANGE REFUSAL',refusal,flush=True)
        break
    x=trace['x2']
    records.append({'layer':k,'output_sha256':hashlib.sha256(np.asarray(x,dtype='<i8').tobytes()).hexdigest(),'output_range':[int(x.min()),int(x.max())]})
    print('TOKEN0 PASS',k,flush=True)
OUT.write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'script_sha256':sha(Path(__file__)),'seed_sha256':sha(seed),'reference_sha256':sha(REFERENCE),'tokens':1,'passed_layers':records,'refusal':refusal,'scope':'Only the token0 causal path with unchanged integer arithmetic and actual T128 calibration. A refusal falsifies this input path; a pass does not certify full128 unmasked scores or native proof.','privacy_accepted':False},indent=2)+'\n')
