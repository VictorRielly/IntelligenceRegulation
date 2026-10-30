"""Deterministic public synthetic v2 exports; no hidden sequence is written."""
from pathlib import Path
import hashlib
import json
import math
import struct

out=Path(__file__).resolve().parent
root=out.parent/'loader-fixtures'
vectors=out.parent/'working-tree/hashline/src/private_block/r13_vectors'
sha=lambda b:hashlib.sha256(b).hexdigest()

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists():assert path.read_bytes()==data,str(path)
    else:path.write_bytes(data)

def encode(obj):return (json.dumps(obj,indent=2,sort_keys=True)+'\n').encode()
def i64(values):return b''.join(struct.pack('<q',v) for v in values)
def matrix(rows,cols):
    data=bytearray(rows*cols)
    for i in range(min(rows,cols)):data[i*cols+i]=64
    return bytes(data)

constants={'norm_tn':10,'norm_cn_a':4000,'norm_cn_m':4000,'norm_ceps':1,'sh_ao':7,'sh_qkv':8,
    'sh_s':6,'sh_o':9,'sh_g':8,'sh_h':14,'sh_z':6,'f_e':12,'rope_theta':10000,
    'sh_rope':7,'sh_u':0,'f_p':12,'f_ro':7,'sh_r2':0,'silu_member':[-3,-11],'exp_e_s':4}
catalog=[]
for variant,stack,ng in [('r13-low-1g','low-v1',1),('r13-h24-4g','low-h24-v1',4)]:
    path=root/variant;layer=path/'layer_00';arrays={}
    def array(name,data,dtype,shape):
        write(layer/(name+'.bin'),data)
        arrays[name]={'file':name+'.bin','dtype':dtype,'shape':shape,'sha256':sha(data)}
    for name,rows,cols in [('wq',1024,384),('wk',512,384),('wv',512,384),('wo',384,1024),
        ('wg_t',384,768),('wu_t',384,768),('wd_t',768,384)]:
        array(name,matrix(rows,cols),'int8',[rows,cols])
    for name in ['gamma_a','gamma_m']:array(name,bytes([64])*384,'int8',[384])
    array('exp',i64(math.floor(4096*math.exp(-d*16/math.sqrt(64))+.5) for d in range(256)),'int64',[256])
    for name,n in [('m_q',1024),('m_k',512),('m_v',512),('m_o',384),('m_g',768),('m_u',768),('m_d',384)]:
        array(name,i64([1]*n),'int64',[n])
    groups=[(-4,-13),(-3,-12),(-2,-11),(-1,-9)][:ng]
    array('silu_groups',i64(v for g in groups for v in g),'int64',[ng,2])
    array('silu_group_ids',i64(i%ng for i in range(768)),'int64',[768])
    array('act',b''.join((vectors/f'silu_{a}_{b}.bin').read_bytes() for a,b in groups),'int16',[ng,4096])
    manifest=encode({'layer':0,'constants':constants,'arrays':arrays})
    write(layer/'manifest.json',manifest)
    profile={'schema':'zk60-trained-profile-export/2','accuracy_stack':stack,'kind':'profile','variant':variant,
        'geometry':'rung-hd-t32-dev','model':{'repo':'synthetic/r13-native-public-fixture','revision':'r13-public-v2',
        'sha256':sha(b'synthetic v2 public matrices')},'calibration_tool':{'path':'loader-next/prepare_fixtures.py',
        'sha256':sha(Path(__file__).read_bytes())},'T':32,'profile_constants':constants,'per_layer_constants_differ':[],
        'layers':[{'layer':0,'dir':'layer_00','manifest_sha256':sha(manifest)}],'residual_unit':1.0}
    write(path/'profile.json',encode(profile))
    catalog.append({'variant':variant,'stack':stack,'groups':ng,'profile_sha256':sha(encode(profile)),
        'layer_manifest_sha256':sha(manifest),'scope':'public synthetic import fixture; no trained model or proof'})
write(root/'CATALOG.json',encode(catalog))
print(json.dumps(catalog))
