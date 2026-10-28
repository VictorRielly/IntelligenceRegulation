"""Read-only source pin and experiment artifact validation; no native run."""
from pathlib import Path
import hashlib,json,resource,time
H=Path(__file__).resolve().parent
start=time.perf_counter();checks=0
manifest=json.loads((H/'source-manifest.json').read_text())
for row in manifest:
    assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256'];checks+=1
    assert hashlib.sha256((H/'startup'/Path(row['path']).name).read_bytes()).hexdigest()==row['sha256'];checks+=1
host=(H/'startup/cuda.rs').read_text();kernel=(H/'startup/fzc_kernels.cu').read_text()
for a in ['let base = self.base && self.next == 0;', 'n - 1 > tail_log', 'if base && base_table(t) && !v.par_iter().all(|x| x.c1.is_zero())']:
    assert a in host,a;checks+=1
for a in ['if (raw && !FOLD)', 'lo = fzs_derived_at(sv, sd, lane, false, which, sp);','const f2 hi = fzs_derived_at(sv, sd, lane, true, which, sp);','st_f2(tabs, tb + i + npairs, hi);']:
    assert a in kernel,a;checks+=1
r=json.loads((H/'result.json').read_text());cases=json.loads((H/'cases.json').read_text())
assert len(cases)==r['fixtures']==36;checks+=1
assert sum(len(c['dispatches']) for c in cases)==r['rounds']==144;checks+=1
assert sum(sum(c['dispatches']) for c in cases)==18;checks+=1
for c in cases:
    assert c['dispatches']==[c['base']]+[False]*(c['n']-1);checks+=1
    assert len(c['round_hashes'])==c['n'];checks+=1
assert len(json.loads((H/'negative-controls.json').read_text()))==r['negative_controls']==15;checks+=1
costs=json.loads((H/'cost-cases.json').read_text());assert len(costs)==90;checks+=1
for c in costs:
    assert c['global_bytes_saved']==c['capacity_bytes_saved']==c['extra_barriers']==0;checks+=1
    if c['mode']=='gl_only':assert c['host_preweight_fp2_products']==c['added_parameter_bytes']==0;checks+=1
assert r['full_stack']['proofs']==r['full_stack']['passes']==r['full_stack']['positions']==0;checks+=1
assert all(v is None for k,v in r['full_stack'].items() if k not in ['proofs','passes','positions']);checks+=1
sketch=(H/'candidate_gl_only.cuh').read_text()
assert 'if (BASE && which == 0)' in sketch and 'f2& lo, f2& dif, f2& hi' in sketch;checks+=1
out=dict(status='PASS_RESEARCH_ARTIFACTS_ONLY',checks=checks,source_pins_unchanged=len(manifest),native_execution=False,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
