"""Pinned lexical address-consumer census; not a Rust/CUDA parser."""
from pathlib import Path
import hashlib,json,re,time,resource,os
H=Path(__file__).resolve().parent
def strip_comments(text):
    # Preserve line numbers; source strings cannot introduce address sites.
    pattern=r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"'
    return re.sub(pattern,lambda m:''.join('\n' if c=='\n' else ' ' for c in m.group()),text)
def main():
    t0=time.perf_counter();rows=[];facts=[]
    paths={p['path'].split('/gpu-zerocheck/')[-1]:p for p in json.loads((H/'source-manifest.json').read_text())}
    for rel,meta in paths.items():
        if rel not in ['hashline/src/gpu/cuda.rs','hashline/src/gpu/fzc_kernels.cu','hashline/src/gpu/kernels.cu']:continue
        p=H/meta['snapshot'];s=p.read_text();clean=strip_comments(s);lines=clean.splitlines();orig=s.splitlines()
        lo,hi=0,len(lines)
        if rel.endswith('cuda.rs'):
            lo=next(i for i,l in enumerate(lines) if l.startswith('impl DevFzcRounds {'))
            hi=next(i for i,l in enumerate(lines[lo:],lo) if l.startswith('fn fzs_groups('))
        fn='unknown'
        for i,line in enumerate(lines):
            if rel.endswith('.cu'):
                m=re.search(r'(?:void|f2)\s+(\w+)\(',line)
                if m:fn=m.group(1)
            else:
                m=re.search(r'\bfn\s+(\w+)\(',line)
                if m:fn=m.group(1)
            if not lo<=i<hi:continue
            if rel.endswith('kernels.cu') and not rel.endswith('fzc_kernels.cu') and fn not in ['k_sc_fold','k_fzc_finals']:continue
            # Exhaust every selected host table/stride consumer, and direct
            # device address expression. Launch plumbing is included too.
            selected=bool(re.search(r'\btabs\b|self\.stride|const size_t (?:base|tb)\s*=|const size_t o\s*=.*\bL\b',line))
            if selected:
                rows.append(dict(file=rel,line=i+1,function=fn,text=orig[i].strip(),physical_address=bool(re.search(r'ld_f2|st_f2|tabs\[|slice_mut|take_min|self\.stride|const size_t (?:base|tb|o)\s*=',line))))
    groups={}
    for row in rows:groups.setdefault(row['file']+'::'+row['function'],[]).append(row['line'])
    required=['new','try_round','try_fold','fzs_ld','fzs_derive_impl','fzs_impl','k_fzc_pack','k_sc_fold','k_fzc_finals','fzc_round_impl','fzc_fold_round_impl','fz_ld','fzl_fold_round_impl']
    for fn in required:assert any(r['function']==fn for r in rows),('missing consumer',fn)
    c=(H/paths['hashline/src/gpu/cuda.rs']['snapshot']).read_text()
    class_start=c.index('impl DevFzcRounds {')
    for label,needle in [
        ('full_request','Pooled::take_min(&dev, kd * l * 2)'),
        ('constructor_full_view','slice_mut(t * l * 2..(t + 1) * l * 2)'),
        ('raw_requires_fusion','&& fzc_fused()'),
        ('raw_first_fold_above_tail','&& n - 1 > tail_log'),
        ('generic_fold_all_derived','(self.tabs.get_mut(), self.kd as i32, half as i32, self.stride as i32'),
        ('host_tail_only_original_k','let n_words = self.k * half * 2;'),
        ('finals_only_original_k','(self.tabs.get(), self.k as i32, self.stride as i64, &mut self.d_fin)')]:
        assert needle in c[class_start:],label
        at=c.index(needle,class_start)
        line=c[:at].count('\n')+1;facts.append(dict(label=label,file='hashline/src/gpu/cuda.rs',line=line,text=needle))
    # Mathematical byte accounting, independent of allocator/runtime.
    projections=[]
    for supp in [0,1]:
        for n in [18,19,20,21]:
            l=1<<n;k=20+supp;kd=k+1+supp
            dense=16*kd*l;mixed=16*((kd-17)*l+17*l//2);implicit=16*((k-17)*l+17*l//2)
            # Initial derived writes: D*L*16. Fused folds use 3 Fp2
            # transfers/remaining output, sum outputs L/2+...+1=L-1.
            derived_tables=1+supp
            eliminated_global_traffic=16*derived_tables*(l+3*(l-1))
            # A round sees lengths L,L/2,...,2. Rematerializing low/high
            # endpoints once requires 2L-2 endpoint evaluations of affine
            # forms. No field/SIMT bandwidth equivalence asserted.
            endpoints=2*l-2
            projections.append(dict(support=bool(supp),cube_log=n,dense_bytes=dense,mixed_bytes=mixed,implicit_bytes=implicit,additional_request_saving=mixed-implicit,derived_eliminated_table_build_and_fold_bytes=eliminated_global_traffic,candidate_derived_endpoint_evaluations=endpoints,baseline_derived_endpoint_evaluations=l,incremental_derived_endpoint_evaluations=endpoints-l,eliminated_derived_fp2_folds=derived_tables*(l-1),note='Symbolic device-only route; tail and unmodeled costs differ; no allocator/VRAM/time claim'))
    out=dict(status='PASS_LEXICAL_SOURCE_ONLY',sites=len(rows),physical_sites=sum(r['physical_address'] for r in rows),functions=len(groups),required_functions=len(required),facts=len(facts),source_versions='Active GPU candidate only; not frozen R8 geometry or current CPU DD tree',complete_program_coverage=False,wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)))
    for name,data in [('address-census.json',rows),('address-functions.json',groups),('source-facts.json',facts),('capacity-projection.json',projections),('census-result.json',out)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(out))
if __name__=='__main__':main()
