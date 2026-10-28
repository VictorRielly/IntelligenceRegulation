"""Separate source/geometry audit; imports no candidate or probe code."""
from pathlib import Path
import hashlib,json,math,resource,time
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
core=(ROOT/'source/zkp-core__src__pcs.rs').read_text()
shape=(ROOT/'source/r9-shape.rs').read_text()
check('const B3_STATE_SLOTS: usize = 8 * 24 + 1;' in cuda)
check('#define B3_MAX_DEPTH 24' in kernel)
check('inv_rate: 4' in shape)
sites=[]
for name in ['commit_zk_chunked','commit_chunked','commit_chunked_upload']:
    text=cuda.split('    fn '+name+'(',1)[1].split('\n    fn ',1)[0]
    check('let state_words = B3_STATE_SLOTS * nn;' in text)
    clear='dev.memset_zeros(d_state.get_mut()).map_err(|e| format!("state memset: {e}"))?;'
    check(clear in text)
    check(text.index(clear)<text.index('for &(r0, rc) in &plan'))
    check('r0 as i32, rows as i32, nn as i32' in text)
    check('chunk_plan(rows, chunk)' in text)
    sites.append(name)
stream=kernel.split('extern "C" __global__ void k_hash_cols_stream(',1)[1].split('// Column gather',1)[0]
check('int stack_len = (int)state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j];' in stream)
check('const int want = __popc(c);' in stream)
check('STK(stack_len, i) = cv[i];' in stream)
check('state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j] = (u32)stack_len;' in stream)
check('state' not in stream.split('leaves[(size_t)j * 8 + w] = cv[w];',1)[1].split('return;',1)[0])
check('blake3(unsalted leaf || salt)' in core)

# Independent event simulation with labelled subtrees, no cryptographic code.
# On entry to chunk c, the earlier lazy push can leave one extra stack item.
# Verify coverage, order and initialization through every chunk count 1..1024.
max_peak=0
for chunks in range(1,1025):
    stack=[];peak=0
    for c in range(chunks):
        want=bin(c).count('1')
        while len(stack)>want:
            left,right=stack[-2:];check(left[1]==right[0])
            stack[-2:]=[(left[0],right[1])]
        check(sum(b-a for a,b in stack)==c)
        if c==chunks-1:
            current=(c,c+1)
            for left in stack[::-1]:
                check(left[1]==current[0]);current=(left[0],current[1])
            check(current==(0,chunks))
        else:
            stack.append((c,c+1));peak=max(peak,len(stack))
    expected=0 if chunks==1 else math.ceil(math.log2(chunks))
    check(peak==expected);max_peak=max(max_peak,peak)

census=json.loads((ROOT/'source/results__zk60_1b_native_20261017__r9__r9_counts.json').read_text())
cost=[]
for label,entry in census.items():
    if not label.startswith('Llama-3-8B'):continue
    context=128 if 'T128' in label else 512
    n=2**(14 if context==128 else 15);nn=4*n
    for mode in ['today','dd']:
        for role in ['a','h']:
            rows=entry[mode][role+'_rows'];chunks=(rows+127)//128
            depth=0 if chunks==1 else math.ceil(math.log2(chunks))
            old=((193*nn+1)//2)*8;new=(((8*depth+1)*nn+1)//2)*8
            check(old>=new);check(depth<=24)
            cost.append(dict(context=context,mode=mode,role=role,rows=rows,
                row_width=n,encoded_columns=nn,chunks=chunks,depth=depth,
                old_state_request_bytes=old,new_state_request_bytes=new,
                request_saving_bytes=old-new,old_full_clear_bytes=old,
                length_only_clear_bytes=nn*4,first_launch_clear_bytes=0,
                legacy_and_candidate_cv_read_write_count_identical=True,
                physical_peak_saving_bytes=None,elapsed_saving_s=None,
                scope='one temporary chunked-commit state, frozen R9 geometry; not an admitted new profile'))

# Pooled allocation reuse can erase a request reduction, independently of hashing.
old=cost[0]['old_state_request_bytes'];new=cost[0]['new_state_request_bytes']
fresh={'old_capacity':old,'new_capacity':new,'saving':old-new}
best_fit_retained={'old_capacity':old,'new_capacity':old,'saving':0}
check(best_fit_retained['saving']==0);check(fresh['saving']>0)
(ROOT/'cost-result.json').write_text(json.dumps(dict(rows=cost,capacity_controls=[fresh,best_fit_retained],
    warning='Requested bytes and avoided initialization only. Do not sum sequential A/H as simultaneous peak or infer time from byte fraction.'),indent=2)+'\n')
result=dict(status='PASS_INDEPENDENT_ORDER_SOURCE_AND_COST_AUDIT',checks=checks,
    source_pins=len(manifest),host_clear_sites=sites,symbolic_chunk_counts=1024,
    controls=['best_fit_retained_backing_erases_request_saving','fresh_exact_backing_can_save_request'],
    wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    native_executed=False,private_proof_implemented=False)
(ROOT/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
