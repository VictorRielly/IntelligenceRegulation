from pathlib import Path
import hashlib, json, os, resource, time
import model as m
import reference as ref

HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def check(x):
    global checks
    checks+=1
    assert x,checks

pins=json.loads((HERE/'source-manifest.json').read_text())
for p in pins:
    check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])

def assertions(k,c):
    p=k[k.index('extern "C" __global__ void k_ntt_p1('):k.index('// [UPERF3-AO] The three strided-tile')]
    z=k[k.index('extern "C" __global__ void k_zk_pad_scale('):k.index('// [UPERF3-AC] THE CHUNKED COMMIT')]
    return [
        '#define NTT_BLK 4096' in k,
        '#define NTT_LOG_BLK 12' in k,
        'const int lb = log_n < NTT_LOG_BLK ? log_n : NTT_LOG_BLK;' in p,
        'src + (size_t)row * (size_t)n_src' in p,
        'int x = blk * bs + q;' in p,
        '__brev((u32)x) >> (32 - log_n)' in p,
        'sh[q] = (r < n_src) ? s[r] : 0ULL;' in p,
        'for (int q = threadIdx.x; q < bs; q += blockDim.x)' in p,
        'd[q] = v;' in p and '__syncthreads();' in p,
        'out[g] = gl_mul(v, pows[i]);' in z,
        'if (i >= n && i < n + q)' in z,
        'int row = (int)(g / (size_t)nn);' in z,
        'pub const NTT_LOG_BLK: u32 = 12;' in c,
        'unwrap_or(512u32).clamp(32, 1024)' in c,
        'self.ntt_rows(coef2, enc, rows, pw, log_nn, false)' in c,
        'pw == nn || pw == n + q' in c,
        'log_nn as i32, pw as i32, 1u64' in c,
        'let pw = n + q;' in c,
        'pw > nn || pw > i32::MAX as usize' in c,
        'k_dit_p1_pad' in c and 'k_dif_pb' in c,
    ]

mutation_count=0
for lane in ['gpu','r9','main']:
    k=(HERE/f'source/{lane}__hashline__src__gpu__kernels.cu').read_text()
    c=(HERE/f'source/{lane}__hashline__src__gpu__cuda.rs').read_text()
    checks_here=assertions(k,c)
    for b in checks_here:check(b)
    mutations=[('src + (size_t)row * (size_t)n_src','src + (size_t)row * (size_t)n'),
               ('int x = blk * bs + q;','int x = q;'),
               ('__brev((u32)x) >> (32 - log_n)','__brev((u32)x) >> (32 - lb)'),
               ('sh[q] = (r < n_src) ? s[r] : 0ULL;','sh[q] = s[r];'),
               ('out[g] = gl_mul(v, pows[i]);','out[g] = v;')]
    for old,new in mutations:
        check(old in k)
        check(not all(assertions(k.replace(old,new),c)))
        mutation_count+=1

out=json.loads((HERE/'result.json').read_text()); census=json.loads((HERE/'census.json').read_text())
check(out['tile_schedules']==len(census))
check(out['tile_schedules']==936 and out['specs']==21)
check(out['logical_words_checked']==3326208)
check(out['full_stack']['proofs']==0 and out['full_stack']['positions']==0)
for s in out['dense_summary']:
    modes=s['modes']; l=s['logn']
    if l in [8,10,11,12,13]:
        check(modes['rotate1']['requested_sectors']*2==modes['literal']['requested_sectors'])
    if l>=14:
        check(len({v['requested_sectors'] for v in modes.values()})==1)
        check(modes['literal']['source_words']==modes['literal']['requested_sectors'])
    check(len({v['unique_source_sectors'] for v in modes.values()})==1)
    if l>=10:
        check(modes['literal']['bank_peak_u32_per_fixed16lane_group_sampled']==1)
        check(modes['rotate1']['bank_peak_u32_per_fixed16lane_group_sampled']==2)
        check(modes['rotate2']['bank_peak_u32_per_fixed16lane_group_sampled']==4)
        check(modes['reverse']['bank_peak_u32_per_fixed16lane_group_sampled']==16)

# No within-tile scalar-load permutation can combine sectors once tile source
# stride >=4 words: enumerate every q in a high-size tile, not just warp pairs.
large_stride_cases=0
for l in [14,16,20,24]:
    for nsrc in [1<<l,(1<<l)-1,513]:
        w=m.p1(l,nsrc,2,0,512,base=8)
        active=[a for warp in w for _,_,a in warp if a is not None]
        check(len(active)==len({a//32 for a in active}))
        large_stride_cases+=1

# Newly screened older external implementation casts field inputs to float64.
# A legal native Goldilocks coefficient loses information before any multiply.
# This tiny local binary64 check does NOT execute any upstream implementation.
p=0xffffffff00000001; x=p-2
check(int(float(x))!=x)
check(int(float(x))%p!=x%p)
precision={'field_prime':p,'legal_input':x,'after_binary64_roundtrip':int(float(x)),
           'loss_before_multiply':int(float(x))-x,
           'conclusion':'Direct unlimbed float64 cast is not exact for all native Goldilocks inputs; no rejection of every possible exact decomposition',
           'upstream_code_executed':False}
(HERE/'older-gntt-precision-screen.json').write_text(json.dumps(precision,indent=2)+'\n')

result={'status':'PASS_SOURCE_AND_ARTIFACT_AUDIT_ONLY','checks':checks,
        'unchanged_source_pins':len(pins),'source_mutations_rejected':mutation_count,
        'large_stride_distinct_sector_cases':large_stride_cases,
        'wall_s':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'threads':1,'affinity':sorted(os.sched_getaffinity(0)),
        'native_gpu_or_proof_execution':False}
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
