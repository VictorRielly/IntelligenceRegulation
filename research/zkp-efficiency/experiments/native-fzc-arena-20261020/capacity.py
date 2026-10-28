"""Extend prior partial schedules with implicit-derived arena request only.

This imports locally authored research models, executes no production code,
and keeps all writes in this experiment. No whole-device fit/time is inferred.
"""
from pathlib import Path
import hashlib,importlib.util,json,os,resource,sys,time,copy
H=Path(__file__).resolve().parent
PRIOR=H.parent/'private-transient-capacity-20261020'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m
model=module('model',PRIOR/'model.py')
audit=module('audit',PRIOR/'audit.py')
def main():
    t0=time.perf_counter();cases=json.loads((PRIOR/'traces.json').read_text());rows=[];checks=0;negative=0
    for c in cases:
        base=model.run(c['geometry'],c['mode'],c['compact'],c['supp'],c['repetitions'],packed=True)
        l=c['geometry']['T']*16384;der=1+c['supp'];saved=16*der*l
        original_cls=model.Trace
        class ImplicitTrace(original_cls):
            def take(self,name,size,kind='pooled',minimum=False,phase=''):
                if name=='fzc.tabs':size-=saved
                return super().take(name,size,kind,minimum,phase)
        model.Trace=ImplicitTrace
        try:alt=model.run(c['geometry'],c['mode'],c['compact'],c['supp'],c['repetitions'],packed=True)
        finally:model.Trace=original_cls
        alt['fzc']['tabs_requested']-=saved
        audit.oracle(alt['events'])
        checks+=1;assert alt['peak_backing']<=base['peak_backing']
        requests=[e['requested'] for e in alt['events'] if e['name']=='fzc.tabs' and e['op'] in ['reuse','alloc']]
        checks+=1;assert all(x==alt['fzc']['tabs_requested'] for x in requests)
        rows.append(dict(T=c['geometry']['T'],mode=c['mode'],compact=c['compact'],support=c['supp'],repetitions=c['repetitions'],dense_peak_backing=c['peak_backing'],mixed_peak_backing=base['peak_backing'],implicit_peak_backing=alt['peak_backing'],dense_request=c['fzc']['tabs_requested'],mixed_request=base['fzc']['tabs_requested'],implicit_request=alt['fzc']['tabs_requested'],additional_request_saving=saved,additional_backing_saving=base['peak_backing']-alt['peak_backing'],total_backing_saving=c['peak_backing']-alt['peak_backing'],native_measurement=False))
        # Inject a lying capacity event; the interval oracle must reject it.
        corrupted=copy.deepcopy(alt['events']);at=next(i for i,e in enumerate(corrupted) if e['name']=='fzc.tabs' and e['op'] in ['reuse','alloc']);corrupted[at]['capacity']-=1
        try:audit.oracle(corrupted)
        except AssertionError:negative+=1
        else:raise AssertionError('corrupt capacity accepted')
    outcome=dict(status='PASS_PARTIAL_ALLOCATION_MODEL_ONLY',cases=len(rows),checks=checks,interval_oracle_checks=audit.CHECKS,negative_controls=negative,zero_resident_additional_backing_cases=sum(r['mode']=='resident' and r['additional_backing_saving']==0 for r in rows),resident_cases=sum(r['mode']=='resident' for r in rows),max_additional_backing_saving=max(r['additional_backing_saving'] for r in rows),wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Same prior partial pinned-R8-geometry / different-GPU-allocator hypothetical model; opening scratch/other slots/cache history/driver/actual peak omitted')
    (H/'allocation-projection.json').write_text(json.dumps(rows,indent=2)+'\n');(H/'capacity-result.json').write_text(json.dumps(outcome,indent=2)+'\n')
    deps=[]
    for n in ['model.py','audit.py','traces.json']:
        p=PRIOR/n;deps.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size))
    (H/'research-dependencies.json').write_text(json.dumps(deps,indent=2)+'\n');print(json.dumps(outcome))
if __name__=='__main__':main()
