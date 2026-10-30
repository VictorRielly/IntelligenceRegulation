"""Independent Python closed-form clock and unbounded-integer payload oracle.

Does not import the Rust mock, prior experiment or downloaded code. Model costs
are arbitrary integer ticks; no conversion to real latency is meaningful.
"""
import copy, hashlib, json, pathlib
D=pathlib.Path(__file__).resolve().parent
P=2**64-2**32+1
KEYS=['outcome','out','start','sample','counter_ticks','samples','bytes_d2h','scope_end','ready']
def reference(x):
    c=x['costs']; k=x['k']; rows=x['rows']; n=x['n']; fail=x['fail']; prior=x['prior_ready']
    r=dict(outcome='err',out=[],start=None,sample=None,counter_ticks=0,samples=0,bytes_d2h=0,scope_end=c[0],ready=prior)
    if fail==1:return r
    r['scope_end']+=c[1]
    if fail==2:r['outcome']='panic';return r
    start=sum(c[:3]);r['start']=start
    # Each exit receives only destructors for objects constructed on that path.
    cleanup=c[18]
    if not 1<=k<=4 or any(len(v)!=2*rows for v in x['rho']):
        r.update(outcome='panic',scope_end=start+cleanup);return r
    before_alloc=start+k*c[3]+c[4]
    if fail==3:r['scope_end']=before_alloc+cleanup;return r
    cleanup+=c[16]
    upload_end=max(before_alloc+c[5],prior)+c[6];r['ready']=upload_end
    if fail==4:r['scope_end']=upload_end+cleanup;return r
    allocated=upload_end+c[7]
    if fail==5:r['scope_end']=allocated+cleanup;return r
    cleanup+=c[17]
    lookup_end=allocated+c[8]
    if fail==6:r['scope_end']=lookup_end+cleanup;return r
    launch_end=lookup_end+c[9]
    if fail==7:r['scope_end']=launch_end+cleanup;return r
    kernel_end=max(upload_end,launch_end)+c[10]
    download_end=max(kernel_end,launch_end+c[11])+c[12];r['ready']=download_end
    if fail==8:r['scope_end']=download_end+cleanup;return r
    sampled=download_end+c[13]
    if fail==9:r.update(outcome='panic',scope_end=sampled+cleanup);return r
    output=[]
    for rho in x['rho']:
        for j in range(n):
            for limb in (0,1):
                output.append(sum(x['data'][i*n+j]*rho[2*i+limb] for i in range(rows))%P)
    r.update(outcome='ok',out=output,sample=sampled,counter_ticks=sampled-start,samples=1,bytes_d2h=16*k*n,scope_end=sampled+c[14]+k*n*c[15]+cleanup)
    return r
def check(x):
    expected=reference(x)
    for k in KEYS:
        assert x[k]==expected[k],(x['id'],k,x[k],expected[k])
    return len(KEYS)
def example(prior,pack,wait=0,convert=0,stats_before=0):
    costs=[0]*19;costs[1]=wait;costs[3]=pack;costs[6]=2;costs[10]=5;costs[12]=2;costs[15]=convert;costs[13]=stats_before
    return dict(id='synthetic',costs=costs,k=4,rows=1,n=8,fail=0,prior_ready=prior,rho=[[1,2]]*4,data=[1]*8)
def main():
    fixtures=[json.loads(l) for l in (D/'fixtures.jsonl').read_text().splitlines()]
    checks=sum(check(x) for x in fixtures)
    success=[x for x in fixtures if x['outcome']=='ok']; failures=[x for x in fixtures if x['outcome']!='ok']
    assert len(success)>50 and len(failures)>100
    # Deliberately broken observations must be rejected, including missing tails/errors.
    controls={}
    ok=next(x for x in success if x['scope_end']>x['sample'] and any(x['out']))
    bad=next(x for x in failures if x['start'] is not None)
    mutants={
      'counter_called_whole_function':(ok,'counter_ticks',ok['scope_end']),
      'conversion_omitted_from_scope':(ok,'scope_end',ok['sample']),
      'init_wait_counted_as_fold':(ok,'counter_ticks',ok['counter_ticks']+sum(ok['costs'][:3])+1),
      'failed_call_counted_success':(bad,'samples',1),
      'missing_failure_cleanup':(bad,'scope_end',0),
      'swapped_output_limbs':(ok,'out',[ok['out'][1],ok['out'][0]]+ok['out'][2:]),
      'double_count_kernel_wait':(ok,'counter_ticks',ok['counter_ticks']+ok['costs'][10]+1),
      'sample_timestamp_changed':(ok,'sample',ok['sample']+1),
    }
    for name,(base,k,v) in mutants.items():
        x=copy.deepcopy(base);x[k]=v
        try:check(x)
        except AssertionError:controls[name]='rejected'
        else:raise AssertionError(name)
    # Same current-fold kernel, less host packing: queue wait absorbs all saving.
    slow=reference(example(100,10));fast=reference(example(100,2));assert slow['scope_end']==fast['scope_end']==109
    # No prior queued work: same change saves exactly 32 ticks, never GPU arithmetic.
    idle_slow=reference(example(0,10));idle_fast=reference(example(0,2));assert idle_slow['scope_end']-idle_fast['scope_end']==32
    # Moving uncounted wait into startup alters scope while leaving counter identical.
    wait0=reference(example(0,2));wait30=reference(example(0,2,wait=30));assert wait0['counter_ticks']==wait30['counter_ticks'];assert wait30['scope_end']-wait0['scope_end']==30
    # Conversion is outside counter but inside scope. Stats lock wait is inside counter.
    convert=reference(example(0,2,convert=3));assert convert['counter_ticks']==wait0['counter_ticks'];assert convert['scope_end']-wait0['scope_end']==96
    stats=reference(example(0,2,stats_before=7));assert stats['counter_ticks']-wait0['counter_ticks']==7
    # >2^53 timestamps stay integer in schema/reference; duration not absolute float subtraction.
    huge=example(2**54+1,2);h=reference(huge);assert h['sample']==2**54+10
    cases=dict(queued_pack_slow=slow,queued_pack_fast=fast,idle_pack_slow=idle_slow,idle_pack_fast=idle_fast,wait0=wait0,wait30=wait30,conversion=convert,stats_lock=stats,large_integer=h)
    # Six explicit Rust executions independently exhibit the principal examples.
    named={x['id']:x for x in fixtures}
    assert named[320]['scope_end']==named[321]['scope_end']==109
    assert named[322]['scope_end']-named[323]['scope_end']==32
    assert named[324]['counter_ticks']==named[323]['counter_ticks']
    assert named[324]['scope_end']-named[323]['scope_end']==30
    assert named[325]['counter_ticks']==named[323]['counter_ticks']
    assert named[325]['scope_end']-named[323]['scope_end']==96
    (D/'counterexamples.json').write_text(json.dumps(cases,indent=2)+'\n')
    for p in json.loads((D/'source-pins.json').read_text()):
        assert hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256']
    result=dict(status='PASS',fixtures=len(fixtures),successful=len(success),errors_or_panics=len(failures),reference_checks=checks,payload_limbs=sum(len(x['out']) for x in success),malformed_shape_fixtures=sum(x['malformed']>0 for x in fixtures),negative_controls=controls,counterexamples=9,explicit_rust_counterexample_fixtures=6,source_checks=8,large_timestamp_scope='Python integer-reference-only; native floating seconds and device clock alignment not tested',scope='Extracted native function with synthetic deterministic Rust device/clock; independent Python closed-form timing and bigint fold oracle. No physical timings, native device or proof.',full_stack_proofs=0,passes=0,positions=0)
    (D/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
