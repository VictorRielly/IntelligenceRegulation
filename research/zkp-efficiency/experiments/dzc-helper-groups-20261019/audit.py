"""Independent boundary initialization, traffic, assembly and source audit."""
import collections,hashlib,json,os,re,resource,signal,subprocess,time
from pathlib import Path
H=Path(__file__).resolve().parent


def replay(q,p,skip=None,corrupt=False):
    ns=q['ops'];mem={};slots={int(k):v for k,v in p['slots'].items()};count=0
    last={x['id']:x['id'] for x in ns}
    for x in ns:
        for d in x['deps']:last[d]=x['id']
    for d in q['output']:last[d]=len(ns)
    for g in p['groups']:
        a,b=g['start'],g['end']
        expected_ins=sorted({d for x in ns[a:b] for d in x['deps'] if d<a})
        expected_out=[i for i in range(a,b) if last[i]>=b]
        assert expected_ins==g['inputs'] and expected_out==g['outputs']
        local={}
        for d in expected_ins:
            assert mem.get(slots[d])==d,('stale/uninitialized',d)
            local[d]=d;count+=1
        for x in ns[a:b]:
            assert all(d in local for d in x['deps'])
            local[x['id']]=x['id'];count+=1
        for d in expected_out:
            if d!=skip:mem[slots[d]]=d
            count+=1
        if corrupt and g['index']==0:
            d=expected_out[0];mem[slots[d]]=-1
        future={d for x in ns[b:] for d in x['deps'] if d<b}|{d for d in q['output'] if d<b}
        assert all(mem.get(slots[d])==d for d in future)
        assert len(set(slots[d] for d in future))==len(future);count+=1
    assert all(mem[slots[d]]==d for d in q['output']);return count


def assembly():
    text=(H/'kernels.s').read_text();ans={}
    for m in re.finditer(r'^([A-Za-z_][A-Za-z_0-9.$]*):\n(.*?)(?=^\.Lfunc_end)',text,re.M|re.S):
        name,f=m.groups()
        subs=[int(x) for x in re.findall(r'^\s*subq\s+\$(\d+), %rsp',f,re.M)]
        adds=[int(x) for x in re.findall(r'^\s*addq\s+\$(\d+), %rsp',f,re.M)]
        assert subs==adds and len(subs)<=1
        pushes=len(re.findall(r'^\s*pushq\s',f,re.M));pops=len(re.findall(r'^\s*popq\s',f,re.M));assert pushes==pops
        redzone=max([0]+[-int(x) for x in re.findall(r'(-\d+)\(%rsp\)',f)])
        calls=re.findall(r'^\s*callq\s+([^\s#]+)',f,re.M)
        assert not re.search(r'^\s*j(?!mp)[a-z]+\s',f,re.M)
        ans[name]=dict(local_sub_bytes=sum(subs),push_bytes=8*pushes,red_zone_bytes=redzone,
             own_span_below_entry_rsp_bytes=sum(subs)+8*pushes+redzone,
             calls=calls,call_count=len(calls),instruction_lines=len(re.findall(r'^\s+[a-z][a-z0-9]*\s',f,re.M)),
             rsp_references=len(re.findall(r'\(%rsp\)',f)))
    for n in ans:
        assert all(c in ans for c in ans[n]['calls']),ans[n]
    def span(n,seen=()):
        assert n not in seen
        a=ans[n];callee=max([0]+[8+span(c,seen+(n,)) for c in a['calls']])
        # Caller has no red-zone allocation when making calls in this build.
        assert not a['calls'] or a['red_zone_bytes']==0
        return a['own_span_below_entry_rsp_bytes']+callee
    for n in ans:ans[n]['call_chain_span_below_entry_rsp_bytes']=span(n)
    cp=subprocess.run(['nm','-S','--defined-only',str(H/'libkernels.so')],capture_output=True,text=True,timeout=5)
    assert cp.returncode==0;(H/'symbols.log').write_text(cp.stdout)
    for line in cp.stdout.splitlines():
        a=line.split()
        if len(a)==4 and a[3] in ans:ans[a[3]]['symbol_bytes']=int(a[1],16)
    return ans


def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    p=json.loads((H/'group-plan.json').read_text());q=json.loads((H/'scalar-dags.json').read_text())
    assert q['baseline']==q['driven'];checks=replay(q['driven'],p)
    controls={}
    for name,args in [('missing_store',dict(skip=p['groups'][0]['outputs'][0])),('stale_slot',dict(corrupt=True))]:
        try:replay(q['driven'],p,**args)
        except AssertionError:controls[name]=True
        else:raise AssertionError(name)
    ns=q['driven']['ops'];counts=collections.Counter(x['kind'] for x in ns)
    assert counts==dict(load_raw=118,load_param=129,load_base=36,add=272,sub=209,mul=331,base=72)
    reads=sum(len(g['inputs']) for g in p['groups']);writes=sum(len(g['outputs']) for g in p['groups'])
    assert reads==p['crossing_loads'] and writes==p['crossing_stores'];checks+=2
    common=16*(118+129+5)+8*36;added=16*(reads+writes+5)
    asm=assembly();group_names=[n for n in asm if re.search(r'helper_\d+$',n)]
    assert len(group_names)==len(p['groups'])==19
    assert asm['baseline']['call_count']==884 and asm['driven']['call_count']==19
    assert all(asm[n]['call_count']==0 for n in group_names)
    assert asm['driven']['local_sub_bytes']<asm['baseline']['local_sub_bytes']
    controls['caller_only_stack_misleads']=asm['driven']['call_chain_span_below_entry_rsp_bytes']>asm['baseline']['call_chain_span_below_entry_rsp_bytes']
    controls['ignoring_frontier_traffic_misleads']=common+added>common
    assert all(controls.values());checks+=6
    for pin in json.loads((H/'source-pins.json').read_text()):
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
    assert (H/'native-field.rs').read_bytes()==Path('/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/zkp-core/src/field.rs').read_bytes()
    r=json.loads((H/'result.json').read_text());assert r['status']=='PASS' and len(r['controls'])==7 and all(r['controls'].values());checks+=2
    out=dict(status='PASS',checks=checks,controls=controls,groups=len(group_names),scratch_bytes=16*p['capacity'],
        crossing_loads=reads,crossing_stores=writes,final_scratch_loads=5,
        baseline_logical_requested_bytes=common,candidate_added_logical_scratch_bytes=added,
        candidate_logical_requested_bytes=common+added,physical_DRAM_bytes=None,
        original_fold_reads=118,original_fold_writes=59,original_fold_field_calls=dict(add=59,sub=59,mul=59),
        assembly=asm,baseline_code_bytes=sum(a['symbol_bytes'] for n,a in asm.items() if n=='baseline' or 'Fp2' in n),
        candidate_code_bytes=sum(asm[n]['symbol_bytes'] for n in group_names+['driven']),
        wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        threads=1,cpu_affinity=[cpu],limits='59sCPU/wall,512MiBAS,one nice19 CPU',
        caveat='Static x86 allocation and address extent, including leaf red zone and return addresses below exported entry RSP; excludes caller return address, harness/enclosing stack and dynamic sampling. Logical scratch traffic is not DRAM. No GPU or proving performance measured.')
    (H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k!='assembly'},indent=2))
    for n in ['baseline','driven']:print(n,{k:v for k,v in asm[n].items() if k!='calls'})


if __name__=='__main__':main()
