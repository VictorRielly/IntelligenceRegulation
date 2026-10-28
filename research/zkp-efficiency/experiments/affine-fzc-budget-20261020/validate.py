"""Read-only source/artifact validation for the research experiment."""
from pathlib import Path
import hashlib,json,re,resource,time
H=Path(__file__).resolve().parent

def main():
    start=time.perf_counter();checks=0
    for row in json.loads((H/'source-manifest.json').read_text()):
        b=(H/row['snapshot']).read_bytes()
        assert hashlib.sha256(b).hexdigest()==row['sha256'];checks+=1
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256'];checks+=1
    src=(H/'source/hashline__src__gpu__fzc_kernels.cu').read_text()
    def body(text,name):
        match=re.search(r'\b'+re.escape(name)+r'\([^;]+?\)\s*\{',text)
        assert match,name
        a=match.end();depth=1;b=a
        while depth:
            depth+=(text[b]=='{')-(text[b]=='}');b+=1
        return text[a:b-1]
    mul=body(src,'fz_mulk')
    assert len(re.findall(r'\bgl_mul\(',mul))==3
    assert len(re.findall(r'\bgl_add\(',mul))==6
    assert len(re.findall(r'\bgl_sub\(',mul))==3;checks+=3
    mainbody=body(src,'fzs_impl')
    assert 'if (raw && !FOLD)' in mainbody and 'const f2 hi = fzs_derived_at' in mainbody
    assert 'st_f2(tabs, tb + i + npairs, hi)' in mainbody;checks+=2
    host=(H/'source/hashline__src__gpu__cuda.rs').read_text()
    # Deliberately scope to this evaluator; other constructors repeat strings.
    scoped=host[host.index('impl DevFzcRounds'):]
    for anchor in ['Pooled::take_min(&dev, kd * l * 2)','n - 1 > tail_log','let n_words = self.k * half * 2','self.tabs.get(), self.k as i32, self.stride as i64, &mut self.d_fin']:
        assert anchor in scoped,anchor;checks+=1
    pair=json.loads((H/'pair-result.json').read_text());cost=json.loads((H/'cost-result.json').read_text())
    assert pair['fixtures']==36 and pair['rounds']==144 and pair['negative_controls']==7
    assert cost['cases']==720 and cost['negative_controls']==7;checks+=2
    assert pair['full_stack']['proofs']==pair['full_stack']['positions']==0;checks+=1
    rows=json.loads((H/'cost-cases.json').read_text())
    for row in rows:
        if row['variant']=='raw_pair':
            assert row['saved_global_bytes_vs_baseline']==0
            assert row['extra_chunk_barriers']==0
            assert row['device_delta_vs_baseline']['base_mul']<=0
            assert row['device_delta_vs_baseline']['base_add']<0;checks+=4
    deps=[]
    for name in ['affine.py','pair_probe.py','cost_probe.py','candidate_pair.cuh','reference.py','prior_fzc_model.py','run_bounded.py','validate.py']:
        b=(H/name).read_bytes();deps.append(dict(path=name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
    (H/'research-code-manifest.json').write_text(json.dumps(deps,indent=2)+'\n')
    result=dict(status='PASS_RESEARCH_ARTIFACTS_ONLY',checks=checks,source_files_unchanged=8,native_execution=False,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (H/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
