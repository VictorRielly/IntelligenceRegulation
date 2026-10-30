"""Public h24 fixture whose product words must use the signed24 class."""
from pathlib import Path
import hashlib
import json
import shutil

root=Path(__file__).resolve().parent.parent/'loader-fixtures'
sha=lambda b:hashlib.sha256(b).hexdigest()
encode=lambda x:(json.dumps(x,indent=2,sort_keys=True)+'\n').encode()
dst=root/'r13-h24-wide'
assert not dst.exists()
shutil.copytree(root/'r13-h24-dense',dst)
m=json.loads((dst/'layer_00/manifest.json').read_text())
p=json.loads((dst/'profile.json').read_text())
for c in [m['constants'],p['profile_constants']]:c.update(norm_cn_a=10000,norm_cn_m=10000)
p['variant']='r13-h24-wide'
p['calibration_tool']={'path':'loader-next/prepare_wide_fixture.py','sha256':sha(Path(__file__).read_bytes())}
mb=encode(m);(dst/'layer_00/manifest.json').write_bytes(mb)
p['layers'][0]['manifest_sha256']=sha(mb);pb=encode(p);(dst/'profile.json').write_bytes(pb)
# Copied prior references belong to the old calibration; retain them under
# explicit prior names until the independent oracle writes the new ones.
for name in ['independent_trace.tsv','seq_public/x_out_L00.bin','seq_public/manifest.json']:
    original=dst/name
    if original.exists():original.rename(original.with_name(original.name+'.prior-calibration'))
catalog=json.loads((root/'DENSE_CATALOG.json').read_text())
catalog.append({'variant':p['variant'],'profile_sha256':sha(pb),'layer_manifest_sha256':sha(mb),
    'input_sha256':sha((dst/'seq_public/x_in_L00.bin').read_bytes()),'matrix_density':1.0,
    'scope':'public h24 synthetic; independent output/proof pending'})
(root/'DENSE_CATALOG.json').write_bytes(encode(catalog))
print(json.dumps(catalog[-1]))
