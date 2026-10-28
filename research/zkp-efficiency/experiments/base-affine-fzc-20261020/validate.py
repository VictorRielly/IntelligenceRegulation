"""Validate retained artifacts and exact current native source pins; read only."""
from pathlib import Path
import hashlib,json,resource,time
H=Path(__file__).resolve().parent
def main():
    start=time.perf_counter();checks=0
    manifest=json.loads((H/'source-manifest.json').read_text())
    for row in manifest:
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256'];checks+=1
        assert hashlib.sha256(Path(row['prior_snapshot']).read_bytes()).hexdigest()==row['sha256'];checks+=1
    host=Path(manifest[0]['path']).read_text();kernel=Path(manifest[2]['path']).read_text()
    anchors=['let base = self.base && self.next == 0;',
             'if base && base_table(t) && !v.par_iter().all(|x| x.c1.is_zero())',
             'if base_table(t) {\n                        base = false;',
             'n - 1 > tail_log', 'Pooled::take_min(&dev, kd * l * 2)?']
    for a in anchors:assert a in host,a;checks+=1
    for a in ['if (raw && !FOLD)', 'lo = fzs_derived_at(sv, sd, lane, false, which, sp);',
              'const f2 hi = fzs_derived_at(sv, sd, lane, true, which, sp);',
              'st_f2(tabs, tb + i + npairs, hi);',
              'fzs_impl<FZ_D, (FZ_SUPP != 0), true, true, false>']:
        assert a in kernel,a;checks+=1
    result=json.loads((H/'result.json').read_text());cases=json.loads((H/'cases.json').read_text())
    assert len(cases)==result['fixtures']==36;checks+=1
    assert sum(len(c['dispatches']) for c in cases)==result['rounds']==144;checks+=1
    assert sum(sum(c['dispatches']) for c in cases)==18;checks+=1
    for c in cases:
        assert not any(c['dispatches'][1:]);checks+=1
    assert result['negative_controls']==len(json.loads((H/'negative-controls.json').read_text()))==18;checks+=1
    assert result['full_stack']['proofs']==result['full_stack']['positions']==0;checks+=1
    deps=[]
    for name in ['base_pair.py','probe.py','affine.py','reference.py','prior_fzc_model.py','candidate_base_pair.cuh','run_bounded.py','validate.py']:
        b=(H/name).read_bytes();deps.append(dict(path=name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
    (H/'research-code-manifest.json').write_text(json.dumps(deps,indent=2)+'\n')
    out=dict(status='PASS_RESEARCH_ARTIFACTS_ONLY',checks=checks,source_pins_unchanged=len(manifest),native_execution=False,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
