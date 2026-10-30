from pathlib import Path
import hashlib,json,difflib
D=Path(__file__).resolve().parent
R=Path('/home/victor/IntelligenceRegulation')
base=R/'results/zk60_1b_native_20261017/r13/frozen-tree'
paths=['zkp-core/src/pcs.rs','zkp-core/src/field.rs','hashline/src/gpu/kernels.cu','hashline/src/gpu/cuda.rs','hashline/src/gpu/mod.rs']
pins=[]
for name in paths:
 p=base/name;b=p.read_bytes();q=D/'native'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
 pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
def extract(s,needle):
 at=s.index(needle);start=s.rfind('\n',0,at)+1;br=s.index('{',at);end=br+1;depth=1
 while depth:
  depth+=(s[end]=='{')-(s[end]=='}');end+=1
 return s[start:end]+'\n'
pcs=(base/paths[0]).read_text();kernel=(base/paths[2]).read_text()
host=extract(pcs,'fn fold_rows_host(')
(D/'native_host.rs').write_text(host.replace('.into_par_iter()','.into_iter()'))
(D/'field.rs').write_bytes((base/paths[1]).read_bytes())
original=extract(kernel,'extern "C" __global__ void k_fold_rows(')
old='''        u64 v = data[(size_t)i * n + j];
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            if (g < k) {
                f2 r = ld_f2(rhos, (size_t)g * rows + i);
                acc[g] = f2_add(acc[g], f2_mul_base(r, v));
            }
        }'''
new='''        // rho is public opening data. No branch inspects private data.
        f2 rw[FR_MAX_K];
        bool any = false;
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            rw[g] = f2_zero();
            if (g < k) {
                rw[g] = ld_f2(rhos, (size_t)g * rows + i);
                any |= (rw[g].c0 != 0ULL || rw[g].c1 != 0ULL);
            }
        }
        if (!any) continue;
        u64 v = data[(size_t)i * n + j];
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            if (g < k && (rw[g].c0 != 0ULL || rw[g].c1 != 0ULL)) {
                acc[g] = f2_add(acc[g], f2_mul_base(rw[g], v));
            }
        }'''
assert original.count(old)==1
candidate=original.replace(old,new)
(D/'baseline_kernel.cu').write_text('#define FR_MAX_K 4\n'+original)
(D/'candidate_kernel.cu').write_text('#define FR_MAX_K 4\n'+candidate)
(D/'kernels_host.cpp.inc').write_text('#define FR_MAX_K 4\n'+original.replace('void k_fold_rows(', 'void baseline_fold_rows(')+candidate.replace('void k_fold_rows(', 'void candidate_fold_rows('))
patched=kernel.replace(original,candidate)
(D/'native-public-rho-skip.patch').write_text(''.join(difflib.unified_diff(kernel.splitlines(True),patched.splitlines(True),fromfile='a/hashline/src/gpu/kernels.cu',tofile='b/hashline/src/gpu/kernels.cu')))
# A newer owner checkpoint is read only; verify the same seam is still present.
newbase=R/'results/zk60_1b_native_20261017/r14/checkpoints/core-build-2/tree'
compare={}
for name in paths:
 p=newbase/name;b=p.read_bytes();q=D/'r14-seam'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
 pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
 if name.endswith('pcs.rs'):compare['host_function_equal']=extract(b.decode(),'fn fold_rows_host(')==host;compare['wrapper_equal']=extract(b.decode(),'fn fold_rows_multi_zk<')==extract(pcs,'fn fold_rows_multi_zk<')
 if name.endswith('kernels.cu'):compare['kernel_equal']=extract(b.decode(),'extern "C" __global__ void k_fold_rows(')==original
 if name.endswith('cuda.rs'):compare['adapter_equal']=extract(b.decode(),'pub fn dev_fold_rows(')==extract((base/name).read_text(),'pub fn dev_fold_rows(')
for name in ['CURRENT_DEV_STATE.json','MATCHED_R13_R14_COMPARISON.json','NATIVE_BUILDERS_CENSUS.json']:
 p=R/'results/zk60_1b_native_20261017/r14'/name;b=p.read_bytes();q=D/'owner'/name;q.parent.mkdir(exist_ok=True);q.write_bytes(b);pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),mutable_owner_report=True))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
(D/'extraction.json').write_text(json.dumps(dict(host_adapter='into_par_iter -> into_iter only',kernel_compiled=False,cuda_launched=False,patch_applied=False,r14_checkpoint_seam=compare),indent=2)+'\n')
assert all(compare.values())
print(json.dumps(compare))
