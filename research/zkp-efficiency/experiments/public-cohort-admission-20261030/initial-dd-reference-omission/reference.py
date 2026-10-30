"""Independent closed-form geometry and allocation-interval oracle.

The reference never imports the native metadata or admission implementation
to compute expected rows, payloads, budget boundaries or replay invariants.
"""
from pathlib import Path
import copy,hashlib,json,os,platform,random,subprocess,time
from admission import Arena,Refusal
D=Path(__file__).resolve().parent
SEED=20261030163
checks=0;controls=0
def check(b,msg='check'):
    global checks
    checks+=1
    if not b:raise AssertionError(msg)
def refused(fn):
    global controls
    try:fn()
    except Refusal:controls+=1;return
    raise AssertionError('negative control accepted')
def dump(name,obj):(D/name).write_text(json.dumps(obj,indent=2)+'\n')
def ceil_log(x):return (x-1).bit_length()
def reference(v):
    t,w,f,h,dh,kv,lc,dd,nw,sw=v;n=2**lc
    ext={'T':2**ceil_log(t),'Ht':2**ceil_log(h)*2**ceil_log(t),
         'L':16*2**ceil_log(t),'D':2**ceil_log(t)*2**ceil_log(w),
         'Q':2**ceil_log(t)*2**ceil_log(h)*dh,'Kv':2**ceil_log(t)*kv*dh,
         'S':2**ceil_log(h)*2**(2*ceil_log(t)),'F':2**ceil_log(t)*2**ceil_log(f),'Tab':256,
         'Dd':2**ceil_log(h)*2**ceil_log(t)*max(dd,1)}
    sizes={d:2**ceil_log(x) if d in ('T','Ht') else max(n,2**ceil_log(x)) for d,x in ext.items()}
    ln=(nw+7)//8;ls=(sw+7)//8;lp=2
    a={'T':4,'Ht':2,'L':2,'D':19+4*ln,'Q':7,'Kv':6,'S':5 if dd else 5+lp+2*ls,'F':11,'Tab':3}
    if dd:a['Dd']=2+lp+2*ls
    pernorm=2+2*(ln+int(nw!=8*ln))
    look={'L':2,'D':14+2*pernorm,'Q':13,'Kv':12,'S':4 if dd else 4+(lp+1)+2*(ls+1),'F':9}
    if dd:look['Dd']=(lp+1)+2*(ls+1)
    hcount={d:(x+1)//2 for d,x in look.items()};hcount['S']+=1+bool(dd);hcount['F']+=1;hcount['Tab']=4
    ad=sum(c*max(1,sizes[d]//n) for d,c in a.items())
    hd=sum(2*c*max(1,sizes[d]//n) for d,c in hcount.items())
    # Independently enumerated opened-site families, not the Rust slot array.
    ac=[1,1,22,a['L'],2]+[1]*7+[2,2,a['D']+2,a['Q']+1,a['Kv']+1,a['S']+2,a['F'],3,1,1]
    hc=[(look[d]+1)//2 for d in ('L','D','Q','Kv')]+[hcount['S'],hcount['F'],3,1]
    if dd:ac.append(a['Dd']+1);hc.append(hcount['Dd'])
    supports=int(sizes['Ht']!=t*h)+int(sizes['S']!=h*t*t)
    k=4+a['S']+2+hcount['S']+supports
    return [ad+2*sum(ac)+2,hd+2*sum(hc)+2,50+2*bool(dd),ceil_log(sizes['S']),k,a['S']+2,hcount['S'],supports,ad,hd]
def replay(events,background,budget):
    """Offline list-scanning allocation oracle; no incremental total counter."""
    records=[];owners=[];generations={};pending={};finished=set()
    for e in events:
        op=e['op']
        if op=='admit':
            i,o,g=e['token'];check(o not in [x[0] for x in owners])
            owners.append((o,e['persistent']))
            match=[r for r in records if r[0]==i]
            if e['reused']:
                check(len(match)==1 and match[0][2] is None);r=match[0]
                check(g==generations[i]+1 and r[1]>=e['requested']);r[2]=o
            else:
                check(not match and g==0);r=[i,e['capacity'],o];records.append(r)
            generations[i]=g;pending[(i,o,g)]=set()
        elif op in ('use','complete','truncate','finish_slot','retire'):
            token=tuple(e['token']);i,o,g=token;r=[r for r in records if r[0]==i][0]
            check(r[2]==o and generations[i]==g)
            if op=='use':check(token not in finished and e['event'] not in pending[token]);pending[token].add(e['event'])
            if op=='complete':check(e['event'] in pending[token]);pending[token].remove(e['event'])
            if op=='finish_slot':check(token not in finished);finished.add(token)
            if op=='retire':check(token in finished and not pending[token]);r[2]=None
        elif op=='open_complete':
            check(not any(r[2]==e['owner'] for r in records));match=[x for x in owners if x[0]==e['owner']]
            check(len(match)==1 and match[0][1]==e['released']);owners.remove(match[0])
        elif op=='free_idle':
            r=[r for r in records if r[0]==e['index']][0];check(r[2] is None and r[1]==e['released']);records.remove(r)
        else:raise AssertionError('unknown event')
        total=background+sum(x[1] for x in owners)+sum(r[1] for r in records)
        check(total==e['total'] and total<=budget,'independent capacity replay')
    return True
def main():
    global controls
    start=time.perf_counter();rng=random.Random(SEED)
    cases=[]
    for t,lc in [(32,13),(64,13),(128,14),(256,14),(512,14),(17,13),(127,14)]:
        for dd in ([0,32] if t in (32,64,128,256,512) else [0]):
            for nw in (24,32,34):
                for fe in (9,12,16):
                    v=[t,4096,14336,32,128,8,lc,dd,nw,ceil_log(t)+fe]
                    cases.append(dict(id='g'+str(len(cases)),v=v,admission_scope='metadata only; constructor/calibration/profile admission NOT executed'))
    probe_cases=[(n,k) for n in (3,6,9,12) for k in (1,4,13,25,28)]
    inp=''.join('M '+c['id']+' '+' '.join(map(str,c['v']))+'\n' for c in cases)
    inp+=''.join(f'V p{i} {n} {k}\n' for i,(n,k) in enumerate(probe_cases))
    (D/'probe-input.txt').write_text(inp)
    p=subprocess.run([str(D/'probe')],input=inp,text=True,capture_output=True,timeout=10)
    (D/'probe-stdout.log').write_text(p.stdout);(D/'probe-stderr.log').write_text(p.stderr);check(p.returncode==0)
    meta={};vrows=[]
    for line in p.stdout.splitlines():
        s=line.split()
        if s[0]=='M':meta[s[1]]=list(map(int,s[2:]))
        else:vrows.append(s)
    geometry=[]
    for c in cases:
        got=meta[c['id']];want=reference(c['v']);check(len(got)==len(want))
        for x,y in zip(got,want):check(x==y,(c,x,y))
        geometry.append(dict(**c,metadata=got))
    for s in vrows:
        n,k=probe_cases[int(s[1][1:])];full=k*(2**n)*16
        if s[0]=='V':
            r,logical,cap=map(int,s[2:]);check(logical==k*2**(n-r)*16);check(cap==full)
            if r>0:check(cap>logical)
        else:check(int(s[2])==full)
    dump('geometry.json',geometry)
    # Partial persistent owner payload: exact declared field entries for
    # single-block A/H/IN/OUT plus their complete CPU encodings and M encoding.
    # Pads, trees, salts, witnesses, public model and pools explicitly excluded.
    projections=[]
    for c in geometry:
        t,w,f,h,dh,kv,lc,dd,nw,sw=c['v'];ar,hr,m,n,k,*_=c['metadata'];cols=2**lc
        er=max(1,(2**ceil_log(t)*2**ceil_log(w))//cols)+5
        data=(ar+hr+2*er)*cols*8
        encoded=(ar+hr+2*er)*cols*4*8+m*4096*8
        round_bytes=k*2**n*16
        projections.append(dict(id=c['id'],context_metadata=t,dd_cap=dd,norm_window=nw,softmax_window=sw,
          a_rows=ar,h_rows=hr,endpoint_rows=er,slot_tables=k,slot_log=n,
          systematic_commitment_data_bytes=data,cpu_encoding_payload_bytes=encoded,
          round_capacity_bytes=round_bytes,
          cohorts=[dict(jobs=b,data_plus_round_lower_bound_bytes=b*(data+round_bytes),cpu_store_payload_subtotal_bytes=b*(data+encoded+round_bytes)) for b in (1,2,4)],
          actual_gpu_placement_or_fit=False))
    dump('capacity-projections.json',projections)
    selected=[x for x in projections if x['context_metadata']==128 and x['dd_cap']==0 and x['norm_window']==32 and x['softmax_window']==16][0]
    P=selected['systematic_commitment_data_bytes']+selected['cpu_encoding_payload_bytes'];R=selected['round_capacity_bytes'];B=4096
    traces=[];boundary_tests=0
    for cohort in (1,2,4):
        for delta in (-1,0,1):
            budget=B+cohort*(P+R)+delta;a=Arena(budget,B);tokens=[]
            for j in range(cohort):
                if delta==-1 and j==cohort-1:refused(lambda j=j:a.admit(j,P,R))
                else:tokens.append(a.admit(j,P,R))
            check(len(tokens)==cohort-int(delta<0));boundary_tests+=1
            for token in tokens:
                a.use(token,100);a.use(token,200);a.truncate(token,R//2);a.finish_slot(token)
                refused(lambda token=token:a.retire(token));a.complete(token,100)
                refused(lambda token=token:a.retire(token));a.complete(token,200);a.retire(token)
                check(a.capacity()>=B+sum(a.commitments.values()))
                a.open_complete(token[1])
            for i in list(a.tables):a.free_idle(i)
            check(a.capacity()==B);replay(a.events,B,budget);traces.append(dict(budget=budget,background=B,events=a.events))
    # Decisive false-admission counterexample: logical lengths halve but
    # original capacity remains reserved. Completed pool return allows reuse,
    # with a new generation and distinct still-live commitment owners.
    budget=B+2*P+R+R//2;a=Arena(budget,B);t=a.admit('A',P,R)
    a.use(t,10);a.use(t,11);a.truncate(t,R//2)
    naive_total=B+P+R//2+P+R;actual_second_total=B+2*P+2*R
    check(naive_total<=budget<actual_second_total)
    refused(lambda:a.admit('B',P,R));refused(lambda:a.open_complete('A'))
    refused(lambda:a.complete((t[0],'wrong',t[2]),10))
    refused(lambda:a.complete((t[0],t[1],t[2]+1),10))
    refused(lambda:a.complete(t,999));refused(lambda:a.retire(t));refused(lambda:a.free_idle(t[0]))
    a.finish_slot(t);a.complete(t,10);refused(lambda:a.retire(t));a.complete(t,11);a.retire(t)
    check(a.capacity()==B+P+R,'pool return does not free capacity')
    t2=a.admit('B',P,R);check(t2[0]==t[0] and t2[2]==t[2]+1)
    refused(lambda:a.use(t,12));refused(lambda:a.admit('B',P,R));refused(lambda:a.retire(t2))
    a.use(t2,20);a.complete(t2,20);a.finish_slot(t2);a.retire(t2)
    a.open_complete('A');a.open_complete('B');a.free_idle(t2[0]);check(a.capacity()==B)
    replay(a.events,B,budget);traces.append(dict(budget=budget,background=B,events=a.events))
    refused(lambda:Arena(10**20,0,reserve_known=False).admit('unknown',P,R))
    # Model trace corruption controls: understated total, missing completion,
    # freeing a live table, and old generation after reuse must be caught by
    # a separate replay, not by the admission class that generated the trace.
    for mutation in ('total','completion','generation','free-live'):
        es=copy.deepcopy(traces[-1]['events'])
        if mutation=='total':es[0]['total']-=1
        elif mutation=='completion':es=[e for e in es if not(e['op']=='complete' and e['event']==11)]
        elif mutation=='generation':
            next(e for e in es if e['op']=='admit' and e['owner']=='B')['token']=(0,'B',0)
        else:
            es.insert(1,dict(op='free_idle',index=0,released=R,total=B+P))
        try:replay(es,B,budget)
        except (AssertionError,KeyError,IndexError):controls+=1
        else:raise AssertionError('corrupt trace accepted: '+mutation)
    # Independent random capacity boundaries at arbitrary public sizes, with
    # no simulated timings and no allocation of the modeled payload.
    for _ in range(150):
        p=rng.randrange(1,10**7);r=rng.randrange(1,10**7);bg=rng.randrange(0,10000);count=rng.choice((1,2,4));d=rng.choice((-1,0,1))
        a=Arena(bg+count*(p+r)+d,bg);admitted=0
        for owner in range(count):
            try:a.admit(owner,p,r);admitted+=1
            except Refusal:pass
        check(admitted==min(count,(a.budget-bg)//(p+r)));replay(a.events,bg,a.budget)
    dump('events.json',traces)
    dump('counterexample.json',dict(budget=budget,background=B,persistent_payload=P,table_capacity=R,
      naive_second_admission_total=naive_total,actual_second_admission_total=actual_second_total,
      naive_underestimate=actual_second_total-naive_total,correct_result='REFUSE until table last-use completion and retirement; safe same-capacity reuse only',actual_fit_claim=False))
    result=dict(status='PASS',seed=SEED,geometry_cases=len(cases),metadata_numeric_comparisons=len(cases)*10,
      vec_probe_cases=len(probe_cases),vec_output_rows=len(vrows),cohort_boundary_cases=boundary_tests,
      randomized_boundary_cases=150,retained_traces=len(traces),checks=checks,negative_controls=controls,
      selected_T128_noDD=selected,wall_s=time.perf_counter()-start,
      native_prover=False,gpu=False,full_stack_proofs=0,proved_positions=0,
      limits='Logical requested-capacity model and metadata extraction only. Unmodeled components require measured public reserve; no fit, speed, cryptographic or privacy result.')
    dump('result.json',result)
    dump('hardware.json',dict(cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),platform=platform.platform(),affinity=list(os.sched_getaffinity(0)),threads=1,estimated_memory_mib=64,gpu_used=False))
    print(json.dumps(result))
if __name__=='__main__':main()
