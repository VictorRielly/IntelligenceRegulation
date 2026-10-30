from pathlib import Path
import hashlib, json, platform, os
D=Path(__file__).resolve().parent
R=Path('/home/victor/IntelligenceRegulation')
def extract(s,needle):
    a=s.index(needle); b=s.index('{',a); i=b+1; depth=1
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}'); i+=1
    return s[s.rfind('\n',0,a)+1:i]+'\n'
pins=[]
paths=['zkp-core/src/field.rs','zkp-core/src/pcs.rs','zkp-core/src/pcs/backend.rs','hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu','hashline/src/gpu/mod.rs']
for name in paths:
    p=R/name; b=p.read_bytes(); q=D/'native'/name; q.parent.mkdir(parents=True,exist_ok=True); q.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
prior=json.loads((D/'prior-native-pins.json').read_text())
for rec in prior:
    if '/documents/' not in rec['snapshot'] and '/owner/' not in rec['snapshot'] and '/native/' not in rec['snapshot']: continue
    p=Path(rec['path']); b=p.read_bytes(); q=D/'context'/rec['snapshot']; q.parent.mkdir(parents=True,exist_ok=True); q.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),matches_prior=hashlib.sha256(b).hexdigest()==rec['sha256']))
(D/'field.rs').write_bytes((D/'native/zkp-core/src/field.rs').read_bytes())
pcs=(D/'native/zkp-core/src/pcs.rs').read_text()
host=extract(pcs,'fn fold_rows_host(')
assert '.into_par_iter()' in host
(D/'native_host.rs').write_text(host.replace('.into_par_iter()','.into_iter()'))
kernel=extract((D/'native/hashline/src/gpu/kernels.cu').read_text(),'extern "C" __global__ void k_fold_rows(')
(D/'baseline_kernel.cu').write_text('#define FR_MAX_K 4\n'+kernel)
(D/'candidate_kernel.cu').write_text('#define FR_MAX_K 5\n'+kernel.replace('k_fold_rows(','k_fold_rows_tail5('))
(D/'kernels_host.cpp.inc').write_text('#define FR_MAX_K 4\n'+kernel.replace('k_fold_rows(','baseline_fold_rows(')+'\n#undef FR_MAX_K\n#define FR_MAX_K 5\n'+kernel.replace('k_fold_rows(','candidate_fold_rows('))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
(D/'extraction.json').write_text(json.dumps(dict(host_adapter='Rayon iterator serial only',kernel_change='max4 -> max5 plus symbol rename only',cuda_compiled=False,native_crate_built=False,patch_applied=False),indent=2)+'\n')
cpu=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),None)
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu,platform=platform.platform(),affinity=list(os.sched_getaffinity(0)),threads=1,gpu_used=False,private_data_used=False),indent=2)+'\n')
print(json.dumps(dict(pins=len(pins),prior_context_unchanged=all(p.get('matches_prior',True) for p in pins))))
