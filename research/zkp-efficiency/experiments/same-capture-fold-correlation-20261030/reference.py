"""Independent list-scan join and endpoint-cell interval oracle; synthetic only."""
import copy, hashlib, json, pathlib, random, subprocess, sys
D=pathlib.Path(__file__).resolve().parent
SEED=202610300841
LIMIT=2**64

def covered(intervals):
    # Different from Rust's sorted-interval merge: partition at every endpoint.
    edges=sorted({x for interval in intervals for x in interval})
    return sum(b-a for a,b in zip(edges,edges[1:]) if any(s<=a and b<=e for s,e in intervals))

def reference(rows):
    def fail(): raise ValueError('invalid normalized capture')
    counts={'M':8,'C':10,'H':12,'A':13,'E':4,'G':12}
    if any(t not in counts or len(v)!=counts[t] or any(type(x)!=int or not 0<=x<LIMIT for x in v) for t,v in rows): fail()
    select=lambda tag:[v for t,v in rows if t==tag]
    manifests=select('M')
    if len(manifests)!=1: fail()
    m=manifests[0]
    if m[0]==0 or m[1]!=0 or m[2]!=1 or any(v[0]!=m[0] for t,v in rows): fail()
    if m[3:]!=[len(select(t)) for t in ['C','H','A','E','G']]: fail()
    cs,hs,aa,ee,gg=[select(t) for t in ['C','H','A','E','G']]
    if not cs or not hs or not aa or not gg or len(aa)!=len(ee): fail()
    for vals,idxs in [(cs,[1,2]),(hs,[1,2]),(aa,[1,2]),(ee,[1,2]),(gg,[1,2])]:
        keys=[tuple(v[i] for i in idxs) for v in vals]
        if len(set(keys))!=len(keys): fail()
    if any(not all(c[i]>0 for i in [1,2,3,5,7,8]) or c[8]&(c[8]-1) or c[9] not in [1,2,3,4] for c in cs): fail()
    for h in hs:
        if not all(h[i]>0 for i in [1,2,3,4,5,7]) or h[5] not in [1,2,3] or h[9]>=h[10] or h[11]!=0: fail()
        matches=[c for c in cs if c[1:3]==[h[1],h[3]]]
        if len(matches)!=1: fail()
        c=matches[0]
        if h[4]!=c[3] or h[6:9]!=c[4:7]: fail()
    for c in cs:
        phases=[h[5] for h in hs if [h[1],h[3]]==c[1:3]]
        if sorted(phases)!=[1,2,3]: fail()
    for i,h in enumerate(hs):
        if any(h[1]==j[1] and h[4]==j[4] and max(h[9],j[9])<min(h[10],j[10]) for j in hs[:i]): fail()
    for a in aa:
        if not all(a[i]>0 for i in [1,2,3,6]) or a[4] not in [1,2,3] or a[8]>=a[9] or a[10:]!=[1,0,0]: fail()
    if any(not all(v[i]>0 for i in [1,2,3]) for v in ee): fail()
    if any(not all(g[i]>0 for i in [1,2,3,6,8]) or g[4] not in [1,2,3] or g[8]>=g[9] or g[10:]!=[0,0] for g in gg): fail()
    joined=[]; host=[]; dev=[]; role=[]; usedh=set(); useda=set()
    for a in aa:
        maps=[e for e in ee if e[1:3]==a[1:3]]
        if len(maps)!=1: fail()
        e=maps[0]
        matches=[h for h in hs if [h[1],h[2]]==[e[1],e[3]]]
        if len(matches)!=1: fail()
        h=matches[0]
        if a[3]!=h[4] or a[4]!=h[5] or a[5:8]!=h[6:9] or not h[9]<=a[8]<a[9]<=h[10]: fail()
        usedh.add((h[1],h[2])); host.append(((a[1],a[3]),(a[8],a[9])))
    if len(usedh)!=len(hs): fail()
    for g in gg:
        matches=[a for a in aa if a[1:3]==[g[1],g[3]]]
        if len(matches)!=1: fail()
        a=matches[0]
        if g[4:8]!=a[4:8]: fail()
        e=next(e for e in ee if e[1:3]==a[1:3]); h=next(h for h in hs if [h[1],h[2]]==[e[1],e[3]])
        joined.append((g[1],g[2],h[3],h[5],g[3])); useda.add((a[1],a[2]))
        dev.append((g[5],(g[8],g[9]))); role.append(((g[5],h[5]),(g[8],g[9])))
    if len(useda)!=len(aa): fail()
    output=['J '+' '.join(map(str,x)) for x in sorted(joined)]
    for tag,pairs in [('H',host),('D',dev),('R',role)]:
        for key in sorted({key for key,interval in pairs}):
            k=key if isinstance(key,tuple) else (key,)
            output.append(tag+' '+' '.join(map(str,(*k,covered([iv for ky,iv in pairs if ky==key])))))
    return '\n'.join(output)+'\n'

def manifest(rows):
    nonm=[(t,v) for t,v in rows if t!='M']; cap=nonm[0][1][0]
    return [('M',[cap,0,1]+[sum(t==tag for t,v in nonm) for tag in ['C','H','A','E','G']])]+nonm

def make(n=2,pids=1,fanout=1,multi=1,big=0):
    rows=[]; stream_time={}; aid={}; corr={}
    for i in range(n):
        pid=1+i%pids; tid=10+pid; fold=i+1; dev=i%2; ctx=20+pid; stream=i%3
        rows.append(('C',[7,pid,fold,tid,dev,ctx,stream,1+i%7,2**(i%5),1+i%4]))
        for role in [1,2,3]:
            ext=fold*10+role; start=big+1000*fold+100*role
            rows.append(('H',[7,pid,ext,fold,tid,role,dev,ctx,stream,start,start+80,0]))
            for sub in range(multi):
                corr[pid]=corr.get(pid,0)+1; co=corr[pid]
                rows.append(('A',[7,pid,co,tid,role,dev,ctx,stream,start+1+sub*15,start+8+sub*15,1,0,0]))
                rows.append(('E',[7,pid,co,ext]))
                for part in range(fanout):
                    aid[pid]=aid.get(pid,0)+1
                    key=(dev,ctx,stream); st=stream_time.get(key,500)
                    rows.append(('G',[7,pid,aid[pid],co,role,dev,ctx,stream,st,st+5+role,0,0]))
                    stream_time[key]=st+7+role
    return manifest(rows)

def overlap_fixture():
    rows=make(2)
    next(v for t,v in rows if t=='C' and v[2]==2)[4]=0
    for t,v in rows:
        if t=='H' and v[3]==2:v[6]=0
        if t=='A' and v[2]>3:v[5]=0
        if t=='G' and v[3]>3:v[5]=0
    return rows

def coherent_call_deletion():
    # A deliberately indistinguishable loss if the collector also loses its roster.
    rs=[(t,v) for t,v in make(2) if not(t=='C' and v[2]==2 or t=='H' and v[3]==2 or t in ['A','E'] and v[2]>3 or t=='G' and v[3]>3)]
    return manifest(rs)

def serialize(rows): return '\n'.join(t+' '+' '.join(map(str,v)) for t,v in rows)

def prepare():
    rng=random.Random(SEED); cases=[]
    for i in range(180):
        rows=make(n=1+i%6,pids=1+i%3,fanout=1+i%3,multi=1+i%2,big=[0,2**53+17,2**63+101][i%3])
        rng.shuffle(rows); cases.append({'name':f'valid-{i}','rows':rows,'expected':'OK'})
    cases.append({'name':'overlap-across-streams','rows':overlap_fixture(),'expected':'OK'})
    shifted=make(2)
    for t,v in shifted:
        if t=='G':v[8]+=2**63+17;v[9]+=2**63+17
    cases.append({'name':'independent-large-gpu-clock','rows':shifted,'expected':'OK'})
    cases.append({'name':'limitation-coherent-call-and-manifest-deletion','rows':coherent_call_deletion(),'expected':'OK'})
    base=make(n=2)
    def change(name,tag,index,field,value,recount=False):
        rs=copy.deepcopy(base); target=[v for t,v in rs if t==tag][index]; target[field]=value(target[field]) if callable(value) else value
        if recount: rs=manifest(rs)
        cases.append({'name':name,'rows':rs,'expected':'ERR'})
    change('equal-count-role-shuffle','E',0,3,12)
    change('equal-count-same-role-wrong-fold','E',0,3,21)
    for tag in ['C','H','A','E','G']:
        rs=copy.deepcopy(base); rs.remove(next(x for x in rs if x[0]==tag)); cases.append({'name':f'missing-{tag}-manifest','rows':rs,'expected':'ERR'})
        rs=copy.deepcopy(base); rs.append(copy.deepcopy(next(x for x in rs if x[0]==tag))); cases.append({'name':f'duplicate-{tag}','rows':manifest(rs),'expected':'ERR'})
    for tag,index in [('G',3),('E',2),('E',3),('H',3)]: change(f'unknown-{tag}-{index}',tag,0,index,9999)
    for field in [1,4,5,6,7]: change(f'wrong-activity-field-{field}','G',0,field,lambda x:x+10)
    for field in [3,4,5,6,7]: change(f'wrong-api-field-{field}','A',0,field,lambda x:x+10)
    change('mixed-capture','G',0,0,8)
    change('reported-drop','M',0,1,1); change('unflushed','M',0,2,0)
    change('unknown-gpu-timestamp','G',0,8,0); change('reversed-gpu-timestamp','G',0,9,1)
    change('graph-unsupported','G',0,10,1); change('runtime-unsupported','A',0,10,2)
    change('invalid-shape','C',0,8,3); change('invalid-k','C',0,9,5)
    change('negative-timestamp','G',0,8,-1); change('u64-overflow','G',0,9,2**64)
    change('overlap-host-scopes','H',1,9,1101)
    # Coherent deletion with recomputed export counts still fails the call roster.
    rs=[(t,v) for t,v in copy.deepcopy(base) if not (t=='H' and v[2]==11 or t=='A' and v[2]==1 or t=='E' and v[2]==1 or t=='G' and v[3]==1)]
    cases.append({'name':'whole-phase-deletion-recounted','rows':manifest(rs),'expected':'ERR'})
    rs=[(t,v) for t,v in copy.deepcopy(base) if not(t=='G' and v[3]==1)]
    cases.append({'name':'api-no-activity-recounted','rows':manifest(rs),'expected':'ERR'})
    rs=copy.deepcopy(base); rs.append(('X',[7])); cases.append({'name':'unknown-record','rows':rs,'expected':'ERR'})
    # Kernel invocations have equal counts but causally swapped attachments.
    rs=copy.deepcopy(base); kernels=[v for t,v in rs if t=='G' and v[4]==2]; kernels[0][3],kernels[1][3]=kernels[1][3],kernels[0][3]
    cases.append({'name':'equal-kernel-count-device-scope-shuffle','rows':rs,'expected':'ERR'})
    for c in cases:
        try: c['oracle']=reference(c['rows']); status='OK'
        except ValueError: status='ERR'; c['oracle']=''
        assert status==c['expected'],c['name']
    (D/'fixtures.jsonl').write_text(''.join(json.dumps(c)+'\n' for c in cases))
    (D/'input.tsv').write_text('\n---\n'.join(serialize(c['rows']) for c in cases))
    print(json.dumps({'fixtures':len(cases),'positive':sum(c['expected']=='OK' for c in cases),'negative':sum(c['expected']=='ERR' for c in cases),'seed':SEED}))

def audit():
    cases=[json.loads(x) for x in (D/'fixtures.jsonl').read_text().splitlines()]
    p=subprocess.run([str(D/'adapter')],input=(D/'input.tsv').read_text(),text=True,capture_output=True,check=True,timeout=15)
    (D/'adapter.stdout.log').write_text(p.stdout); (D/'adapter.stderr.log').write_text(p.stderr)
    chunks=p.stdout.split('END\n'); assert not chunks[-1]; chunks.pop(); assert len(chunks)==len(cases)
    fields=0; joins=0; negatives=[]
    for i,(case,chunk) in enumerate(zip(cases,chunks)):
        header,_,body=chunk.partition('\n'); status=header.split()[2]
        assert status==case['expected'],(i,case['name'],header)
        if status=='OK':
            expected=reference(case['rows']); assert body==expected,(i,case['name'],body,expected)
            fields+=sum(len(x.split())-1 for x in expected.splitlines()); joins+=sum(x.startswith('J ') for x in expected.splitlines())
        else: assert not body; negatives.append(case['name'])
    # Record explicit counterexamples: kernel counts/host enclosures cannot establish identity.
    x=make(2,pids=2,fanout=2,multi=2)
    out=reference(x); gs=[v for t,v in x if t=='G']
    summed=sum(g[9]-g[8] for g in gs); unioned=sum(int(s.split()[-1]) for s in out.splitlines() if s.startswith('D '))
    # Two roles overlap on one device in a separate valid fixture.
    overlap=overlap_fixture()
    o=reference(overlap); g=[v for t,v in overlap if t=='G']; sumg=sum(v[9]-v[8] for v in g); uniong=sum(int(s.split()[-1]) for s in o.splitlines() if s.startswith('D '))
    assert uniong<sumg
    counter={'overlap_summed_activity_ticks':sumg,'overlap_device_union_ticks':uniong,'ticks_are':'arbitrary synthetic units, not latency','host_device_subtraction':'never performed','cross_thread_host_totals':'separate per pid/tid; not summed as elapsed','fanout_activities':len(gs),'fanout_api_count':sum(t=='A' for t,v in x),'whole_call_and_roster_and_manifest_coherent_deletion':'ACCEPTED by both adapters; requires independent source-derived invocation roster. Local consistency is not capture authenticity or complete workload coverage.'}
    (D/'counterexamples.json').write_text(json.dumps(counter,indent=2)+'\n')
    result={'status':'PASS','fixtures':len(cases),'valid':len(cases)-len(negatives),'ordinary_valid':len(cases)-len(negatives)-1,'known_limitation_accepted':1,'invalid':len(negatives),'reference_numeric_fields':fields,'joined_activities':joins,'negative_controls':negatives,'seed':SEED,'scope':'standalone normalized Rust metadata adapter versus independent Python list-scan/endpoint-cell oracle; no CUPTI capture, GPU, proof or physical timing','full_stack_proofs':0,'passes':0,'positions':0}
    (D/'result.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))

if __name__=='__main__': {'prepare':prepare,'audit':audit}[sys.argv[1]]()
