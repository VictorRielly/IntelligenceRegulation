"""Read-only public source extraction; no native prover build or private data."""
from pathlib import Path
import hashlib,json,re,shutil
D=Path(__file__).resolve().parent
P=Path('/home/victor/IntelligenceRegulation')
R=P/'results/zk60_1b_native_20261017/r14'
S=R/'actual-working-tree/hashline/src/private_block'
pins=[]
def pin(p,label):
    b=p.read_bytes();q=D/'snapshots'/label;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
    return b.decode()
texts={n:pin(S/n,'native/'+n) for n in ['split_layout.rs','split_profile.rs','split_geometry.rs','split_endpoint.rs','argument_split.rs','split_protocol.rs','split_definition_tests.rs','split_run.rs','protocol.rs','shape.rs','layout.rs']}
for n in ['NATIVE_INVENTORY_CENSUS.json','NATIVE_BUILDERS_CENSUS.json','CURRENT_DEV_STATE.json','MATCHED_R13_R14_COMPARISON.json','sol-r14-builders-2.source.json','sol-r14-actual-build-2.source.json']:
    pin(R/n,'owner/'+n)
for n in ['CLAUDE.md','docs/zkmatrix-poc/START_HERE.md','docs/zkmatrix-poc/MVP_STATUS.md','docs/zkmatrix-poc/ZK60_DECISIONS.md','docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md','docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md']:
    pin(P/n,'documents/'+n.replace('/','__'))
for n in ['hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu','zkp-core/src/pcs.rs']:
    pin(P/n,'seams/'+n.replace('/','__'))
pin(P/'results/zk60_1b_native_20261017/r13/NATIVE_LAYOUT_CENSUS.json','owner/R13_NATIVE_LAYOUT_CENSUS.json')
def extract(s,name):
    a=s.index('fn '+name+'(');a=s.rfind('\n',0,a)+1;b=s.index('{',a);i=b+1;depth=1
    while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[a:i]+'\n'
sh=texts['shape.rs'];lay=texts['layout.rs']
methods=['a_plane_doms','h_plane_doms','helpers','lookups_per_position','a_planes_on','claim_sites','slots','natural_log','true_size','log','size','pads','n_slots']
(D/'shape_methods.rs').write_text('impl Shape {\n'+''.join(extract(sh,n) for n in methods)+'}\n')
constants='\n'.join(re.findall(r'pub\(crate\) const (?:SC_\w+|N_SLOTS|MAX_SLOTS):[^;]+;',lay))
for n in ['BASE_DEGREE','INDICATOR_SLOT_DOMAIN']:
    at=sh.index('const '+n+':');end=sh.index(';',sh.index('=',at))+1;constants+='\npub(crate) '+sh[at:end]
(D/'constants.rs').write_text(constants+'\n')
native='\n'.join(l for l in texts['split_layout.rs'].split('#[cfg(test)]')[0].splitlines() if not l.startswith('//!') and not l.startswith('#!'))
native+='\npub(crate) fn probe_audit(s:&SplitLayout,b:&Shape)->Result<(),String>{s.audit(b)}\n'
(D/'native_split.rs').write_text(native)
meta=dict(
 exact_native=['SplitLayout structs/new/audit']+['Shape::'+n for n in methods],
 adapters=['minimal public Shape with fixed LOWH24 class; no loader/calibration admission','limb counts and row width from public fixture only','native constructor executed; native define/group construction/FS/PCS/CUDA not executed','recorded native generic-point groups only as separate historical evidence, not replayed'])
(D/'extraction.json').write_text(json.dumps(meta,indent=2)+'\n')
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
print(json.dumps(dict(pinned=len(pins),extracted_methods=len(methods),shape_profile='Shieldstral 3072/9216, T128/T256 only')))
