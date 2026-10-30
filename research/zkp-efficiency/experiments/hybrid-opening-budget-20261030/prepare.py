from pathlib import Path
import hashlib,json,re,os,platform
D=Path(__file__).resolve().parent
P=Path('/home/victor/IntelligenceRegulation')
prior=D.parent/'opening-staging-20261030'
pins=[]
for name in ['field.rs','native_host.rs']:
 b=(prior/name).read_bytes();(D/name).write_bytes(b)
 pins.append({'path':str(prior/name),'snapshot':name,'sha256':hashlib.sha256(b).hexdigest()})
for rel in ['zkp-core/src/field.rs','zkp-core/src/pcs.rs','zkp-core/src/pcs/backend.rs','hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu']:
 src=P/rel;b=src.read_bytes();dest=D/'native'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
 prev=prior/'context/native'/rel
 pins.append({'path':str(src),'snapshot':str(dest.relative_to(D)),'sha256':hashlib.sha256(b).hexdigest(),'matches_prior':prev.exists() and b==prev.read_bytes()})
assert (D/'field.rs').read_bytes()==(P/'zkp-core/src/field.rs').read_bytes()
# Copied host body replaces only Rayon parallel iteration with serial iteration.
s=(P/'zkp-core/src/pcs.rs').read_text();start=s.index('fn fold_rows_host(');end=s.index('\n}',start)+2
assert (D/'native_host.rs').read_text().strip()==s[start:end].replace('.into_par_iter()', '.into_iter()').strip()
(D/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
cpu=next((v.split(':',1)[1].strip() for v in Path('/proc/cpuinfo').read_text().splitlines() if v.startswith('model name')),'unknown')
(D/'hardware.json').write_text(json.dumps({'cpu':cpu,'affinity':sorted(os.sched_getaffinity(0)),'platform':platform.platform(),'gpu_used':False,'device_count':0},indent=2)+'\n')
print(json.dumps({'status':'PASS','pins':len(pins),'native_host_matches':True}))
