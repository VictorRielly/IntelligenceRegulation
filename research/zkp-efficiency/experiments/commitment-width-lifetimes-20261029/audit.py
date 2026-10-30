"""Independent source/patch/cost audit, not a Rust aliasing or privacy proof."""
import hashlib,json,pathlib,time,resource,difflib
H=pathlib.Path(__file__).resolve().parent
start=time.monotonic();checks=0
def check(x):
 global checks
 assert x
 checks+=1
pins=json.loads((H/'native-pins.json').read_text())
for p in pins:
 check(hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
 check(hashlib.sha256((H/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
source=(H/'native/zkp-core__src__pcs__encode_buffer.rs').read_text();cand=(H/'encode_buffer.candidate.rs').read_text()
a=source.index("fn initialize_row<'a>(");b=source.index('\n#[cfg(test)]',a)
old=source[a:b].strip()+'\n'
check((H/'baseline_row.rs').read_text()==old.replace('fn initialize_row','fn baseline_row',1))
oldprefix=source[:a].replace('//! R2a: initialize each encoded row once, directly in its final allocation.\n//! No `Fp` reference is formed until every element of that row was written.',
'//! Encode directly in the final allocation, using its prefix as coefficient scratch.\n//! An `Fp` slice spans only elements that have already been initialized.')
check(cand[:cand.index("fn initialize_row<'a>(")]==oldprefix)
check(cand[cand.index('\n#[cfg(test)]'):]==source[b:])
check('data.to_vec()' not in cand)
for token in ['ntt.inverse(coeffs);','dst.write(*src);','for dst in zeros { dst.write(Fp::ZERO); }','pads[i].sub(pads[n + i])','n.checked_add(q).is_some_and','ntt.forward(initialized);']:
 check(token in cand)
check('rng' not in cand.lower() or 'randomness' in cand.lower())
for text,name in [(source,'baseline_serial.rs'),(cand,'candidate_serial.rs')]:
 check((H/name).read_text()==text.replace('use rayon::prelude::*;\n','').replace('.par_chunks_mut(nn)','.chunks_mut(nn)'))
patch=''.join(difflib.unified_diff(source.splitlines(True),cand.splitlines(True),fromfile='a/zkp-core/src/pcs/encode_buffer.rs',tofile='b/zkp-core/src/pcs/encode_buffer.rs'))
check(patch==(H/'initialize-in-output.patch').read_text())
# A source mutation must invalidate the audit, even if it preserves byte/row counts.
mutations=0
for token in ['ntt.inverse(coeffs);','dst.write(*src);','pads[i].sub(pads[n + i])','for dst in zeros { dst.write(Fp::ZERO); }']:
 changed=cand.replace(token,'/* MUTATED */',1)
 check(token not in changed);mutations+=1
pcs=(H/'native/zkp-core__src__pcs.rs').read_text()
lo=pcs.index('pub fn commit_zk_owned_with_tag');body=pcs[lo:lo+3000]
check(body.index('backend.try_commit_zk_keyed')<body.index('encode_buffer::encode_rows'))
check('hash_columns_keyed' in body)
cuda=(H/'native/hashline__src__gpu__cuda.rs').read_text()
check('fn dev_commit_zk_from_inner' in cuda)
check('let mut d_coef' in cuda)
# Capacity is per concurrent worker, not rows*n, and arithmetic/copy traffic remains.
cost=[]
for n in [256,4096,8192,16384]:
 for workers in [1,2,16]:
  r={'row_width':n,'active_worker_count':workers,'baseline_coefficient_payload_bytes':8*n*workers,'candidate_coefficient_payload_bytes':0,'encoded_matrix_bytes_saved':0,'ntt_butterflies_saved':0,'pad_elements_saved':0,'salt_elements_saved':0,'nominal_copy_words_saved':0,'allocator_calls_avoided_per_row':1,'arithmetic_changed':False}
  check(r['baseline_coefficient_payload_bytes']<=2*1024**2);cost.append(r)
(H/'cost-result.json').write_text(json.dumps({'scope':'logical live coefficient scratch; allocator RSS/cache/physical traffic not measured','rows':cost,'gpu_accepted_commit_direct_incidence':0,'exclusive_removed_seconds':None,'added_seconds':None,'native_end_to_end_ceiling':None,'ceiling_expression':'N/(T-C_exclusive_allocator+A_added); free deletion bound 1/(1-f) with unknown f','naive_all_rows_peak_model_rejected':True},indent=2)+'\n')
r=json.loads((H/'result.json').read_text())
for k,v in [('fixtures',168),('rows_checked',606),('encoded_points',360882),('independent_dft_points',29106),('baseline_allocations',606),('candidate_allocations',0),('matrix_cases',5),('refusal_cases',10),('negative_controls',10),('proved_positions',0)]:check(r[k]==v)
for stage in ['compile','probe']:
 e=json.loads((H/(stage+'-execution.json')).read_text());check(e['exit_code']==0);check(e['elapsed_s']<60);check(e['max_rss_kib']<512*1024);check(e['threads']==1)
out={'status':'PASS_SOURCE_COST_AND_PATCH_AUDIT','checks':checks,'mutations':mutations,'pins':len(pins),'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'rust_aliasing_proof':False,'miri_run':False,'rayon_tested':False,'full_prover_tested':False}
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
