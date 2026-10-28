"""Independent labelled-interval forest, native-source and cost audit.

Does not import the candidate, compression or probe modules.
"""
from pathlib import Path
import hashlib,json,resource,time
ROOT=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    assert ok

manifest=json.loads((ROOT/'source-manifest.json').read_text())
for item in manifest:
    check(hashlib.sha256((ROOT/item['snapshot']).read_bytes()).hexdigest()==item['sha256'])
    check(hashlib.sha256(Path(item['path']).read_bytes()).hexdigest()==item['sha256'])
cuda=(ROOT/'source/hashline__src__gpu__cuda.rs').read_text()
kernel=(ROOT/'source/hashline__src__gpu__kernels.cu').read_text()
check('const B3_STATE_SLOTS: usize = 8 * 24 + 1;' in cuda)
check('#define B3_MAX_DEPTH 24' in kernel)
check('return Ok(pool.swap_remove(i));' in cuda)
check('self.0.as_mut().unwrap()' in cuda)
sites=[]
for name in ['commit_zk_chunked','commit_chunked','commit_chunked_upload']:
    text=cuda.split('    fn '+name+'(',1)[1].split('\n    fn ',1)[0]
    check('let state_words = B3_STATE_SLOTS * nn;' in text)
    check('let mut d_state = Pooled::take_min(&dev, (state_words + 1) / 2)?;' in text)
    check('dev.memset_zeros(d_state.get_mut())' in text)
    check('chunk_plan(rows, chunk)' in text)
    check('r0 as i32, rows as i32, nn as i32' in text)
    sites.append(name)
plan=cuda.split('fn chunk_plan(',1)[1].split('\n}',1)[0]
check('chunk / 128' in plan and '* 128' in plan)
stream=kernel.split('extern "C" __global__ void k_hash_cols_stream(',1)[1].split('// Column gather',1)[0]
check('int stack_len = (int)state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j];' in stream)
check('const int want = __popc(c);' in stream)
check('state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j] = (u32)stack_len;' in stream)
check('return;' in stream.split('leaves[(size_t)j * 8 + w] = cv[w];',1)[1].split('STK(stack_len, i)',1)[0])

# A lazy forest on entry to c consists of a canonical eager cover of [0,c-1)
# followed by the newest leaf [c-1,c). Derive that cover without popcount.
def cover(n):
    out=[]; at=0
    for bit in range(n.bit_length()-1,-1,-1):
        width=1<<bit
        if n & width:
            out.append((at,at+width));at+=width
    check(at==n)
    return out

stack=[];peak=0;max_chunks=1<<18
for c in range(max_chunks):
    expected=[] if c==0 else cover(c-1)+[(c-1,c)]
    check(stack==expected)
    check(len(stack)==(0 if c==0 else (c-1).bit_count()+1))
    want=bin(c).count('1')
    while len(stack)>want:
        left,right=stack[-2:]
        check(left[1]==right[0]);check(left[1]-left[0]==right[1]-right[0])
        stack[-2:]=[(left[0],right[1])]
    check(stack==cover(c))
    stack.append((c,c+1));peak=max(peak,len(stack))

# Public integer/address boundary checks near the entire modelled u32 length
# limit, without allocating model-sized columns or iterating every chunk.
max_rows=((1<<32)-1-1023)//8;max_c=(max_rows+127)//128
boundaries={0,1,max_c}
for k in range(23):
    for delta in [-1,0,1]:
        c=(1<<k)+delta
        if 0<=c<=max_c:boundaries.add(c)
for c in sorted(boundaries):
    s=[] if c==0 else cover(c-1)+[(c-1,c)]
    check(len(s)==(0 if c==0 else (c-1).bit_count()+1))
    for a,b in s:
        check(0<=a<b<=c)
    check(len(s)<=24)
check(peak<=24)

# Use retained, source-pinned R9 census, not a newly admitted fidelity profile.
census=json.loads((ROOT/'source/results__zk60_1b_native_20261017__r9__r9_counts.json').read_text())
cost=[]
for label,entry in census.items():
    if not label.startswith('Llama-3-8B'):continue
    context=128 if 'T128' in label else 512; nn=4*(1<<(14 if context==128 else 15))
    for mode in ['today','dd']:
        for role in ['a','h']:
            rows=entry[mode][role+'_rows'];chunks=(rows+127)//128;d=(chunks-1).bit_length()
            for chunk_rows in [128,384,1024]:
                launches=(rows+chunk_rows-1)//chunk_rows
                # Original: one read per launch, store only on nonfinal.
                # Previous first-init: reads/stores only on nonfinal edges.
                base_rw=(2*launches-1)*nn*4
                first_rw=2*(launches-1)*nn*4
                old=((193*nn+1)//2)*8;static=((192*nn+1)//2)*8
                prior_compact=(((8*d+1)*nn+1)//2)*8
                compact=(((8*d)*nn+1)//2)*8
                check(base_rw>=first_rw>=0);check(old-static==nn*4)
                check(prior_compact-compact==nn*4)
                # Independent per-launch event count instead of formula.
                loads=sum(nn for _ in range(launches));stores=sum(nn for _ in range(launches-1))
                check((loads+stores)*4==base_rw)
                extra=(launches-1)*nn
                check(extra*8==first_rw)
                cost.append(dict(context=context,mode=mode,role=role,rows=rows,encoded_columns=nn,
                    public_chunk_rows=chunk_rows,launches=launches,depth=d,
                    baseline_count_read_write_bytes=base_rw,prior_first_init_count_read_write_bytes=first_rw,
                    derived_count_read_write_bytes=0,added_popcount_evaluations=extra,
                    original_request_bytes=old,static_count_free_request_bytes=static,
                    extra_request_saving_vs_same_depth_with_count_bytes=nn*4,
                    prior_dynamic_depth_request_bytes=prior_compact,compact_count_free_request_bytes=compact,
                    eliminated_original_clear_lower_bound_bytes=old,
                    actual_clear_bytes=None,physical_peak_saving_bytes=None,elapsed_saving_s=None,
                    scope='One A/H temporary commitment; frozen R9 counts, T512 counted-only; LOW/HIGH excluded'))
check(len(cost)==24)
controls=[{'capacity_case':'exact fresh backing','old':cost[0]['original_request_bytes'],
           'new':cost[0]['static_count_free_request_bytes']},
          {'capacity_case':'retained best fit','old':cost[0]['original_request_bytes'],
           'new':cost[0]['original_request_bytes']}]
check(controls[1]['old']==controls[1]['new'])
(ROOT/'cost-result.json').write_text(json.dumps({'rows':cost,'capacity_controls':controls,
    'warning':'Logical requested and read/write bytes, not DRAM transactions or elapsed fraction. No compression/CV traffic saving. Never sum sequential A/H as simultaneous peak.'},indent=2)+'\n')
result=dict(status='PASS_INDEPENDENT_FOREST_SOURCE_AND_COST_AUDIT',checks=checks,
    source_pins=len(manifest),host_sites=sites,symbolic_prefixes=max_chunks,large_boundaries=len(boundaries),
    peak_symbolic_stack=peak,cost_rows=len(cost),wall_seconds=time.monotonic()-start,
    rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,native_executed=False)
(ROOT/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
