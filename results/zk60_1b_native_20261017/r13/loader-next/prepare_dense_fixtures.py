"""Public dense v2 proof fixtures; outputs still require an independent oracle."""
from pathlib import Path
import hashlib
import json
import shutil
import struct

out=Path(__file__).resolve().parent
root=out.parent/'loader-fixtures'
sha=lambda b:hashlib.sha256(b).hexdigest()
encode=lambda x:(json.dumps(x,indent=2,sort_keys=True)+'\n').encode()
catalog=[]
for source,name in [('r13-low-1g','r13-low-dense'),('r13-h24-4g','r13-h24-dense')]:
    dst=root/name
    assert not dst.exists(),'retain prior fixtures; choose a new revision before regeneration'
    shutil.copytree(root/source,dst)
    layer=dst/'layer_00';m=json.loads((layer/'manifest.json').read_text())
    def dense(length,seed):
        for i in range(length):
            z=(i+seed*0x9e3779b9)&0xffffffff
            z=((z^(z>>16))*0x7feb352d)&0xffffffff
            z=((z^(z>>15))*0x846ca68b)&0xffffffff
            z^=z>>16
            yield ((1+((z>>1)&1))*(1 if z&1 else -1))&255
    for k,name_ in enumerate(['wq','wk','wv','wo','wg_t','wu_t','wd_t']):
        spec=m['arrays'][name_];payload=bytes(dense(len((layer/spec['file']).read_bytes()),k+1))
        (layer/spec['file']).write_bytes(payload);spec['sha256']=sha(payload)
    for key,limit in [('m_q',32),('m_k',32),('m_v',64),('m_o',256),('m_g',64),('m_u',16),('m_d',64)]:
        spec=m['arrays'][key]
        payload=b''.join(struct.pack('<q',1+i%limit) for i in range(spec['shape'][0]))
        (layer/spec['file']).write_bytes(payload);spec['sha256']=sha(payload)
    mb=encode(m);(layer/'manifest.json').write_bytes(mb)
    p=json.loads((dst/'profile.json').read_text());p['variant']=name
    p['layers'][0]['manifest_sha256']=sha(mb)
    p['calibration_tool']={'path':'loader-next/prepare_dense_fixtures.py','sha256':sha(Path(__file__).read_bytes())}
    pb=encode(p);(dst/'profile.json').write_bytes(pb)
    # Explicitly public synthetic input. No x_out is fabricated from the
    # native builder; the independent oracle supplies it later.
    seq=dst/'seq_public';seq.mkdir()
    x=b''.join(struct.pack('<h',((i*37+11)%201)-100) for i in range(32*384))
    (seq/'x_in_L00.bin').write_bytes(x)
    catalog.append({'variant':name,'profile_sha256':sha(pb),'layer_manifest_sha256':sha(mb),
        'input_sha256':sha(x),'matrix_density':1.0,'scope':'public synthetic; independent output/proof still pending'})
(root/'DENSE_CATALOG.json').write_bytes(encode(catalog))
print(json.dumps(catalog))
