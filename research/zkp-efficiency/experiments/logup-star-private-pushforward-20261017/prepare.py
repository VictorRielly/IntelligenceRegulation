"""Read-only public source capture. No downloaded code is used or executed."""
from pathlib import Path
import datetime, hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
LANE=ROOT/'ops/zkp-mvp/gpu-zerocheck'
dest=HERE/'native'; dest.mkdir(exist_ok=True)
files={name:LANE/'hashline/src/private_block'/name for name in ['protocol.rs','argument.rs','shape.rs','layout.rs']}
files['field.rs']=LANE/'zkp-core/src/field.rs'
files['owner-progress.md']=ROOT/'results/zk60_gpu_zerocheck_20261017/PROGRESS.md'
files['speed-plan.md']=ROOT/'docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md'
files['phases-T128.md']=ROOT/'results/zk60_1b_native_20261017/r4/PHASES_T128.md'
pins=[]
for name,path in files.items():
    b=path.read_bytes(); (dest/name).write_bytes(b)
    pins.append(dict(source=str(path),capture='native/'+name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
field=(dest/'field.rs').read_text().replace('//!','//').split('#[cfg(test)]')[0]
(HERE/'isolated.rs').write_text('#![allow(dead_code)]\nmod field {\n'+field+'\n}\n'+(HERE/'pushforward.rs').read_text())
(HERE/'prepared-at.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})+'\n')
print('Captured',len(pins),'public source/phase files; generated local std-only Rust seam.')
