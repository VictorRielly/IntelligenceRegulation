"""Goldilocks Fp2 and actual FZC algebra, Python-only arena differential.

This is an executable mathematical model, not a native Rust/CUDA execution,
masked prover, receipt verifier, or privacy proof.
"""
from pathlib import Path
import hashlib,json,os,random,resource,struct,time
import reference as ref
H=Path(__file__).resolve().parent
P=ref.P; Z=(0,0); O=(1,0); SEED=2026102096
CHECKS=0; NEG=0; EVENTS={}; OPS={'mul':0,'add':0,'sub':0}
def ck(x,msg=''):
    global CHECKS
    CHECKS+=1
    assert x,msg
def add(a,b):
    OPS['add']+=1
    return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):
    OPS['sub']+=1
    return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):
    OPS['mul']+=1
    ac=a[0]*b[0]%P;bd=a[1]*b[1]%P
    return ((ac+7*bd)%P,((a[0]+a[1])*(b[0]+b[1])-ac-bd)%P)
def b(x):return (x%P,0)
def sm(xs):
    a=Z
    for x in xs:a=add(a,x)
    return a
def fold(a,c,r):return add(a,mul(r,sub(c,a)))
def derive(v,p,supp,bad_constant=False):
    a=v[3:14]
    f0=sub(sub(add(mul(b(-p['kh']),a[6]),b(0 if bad_constant else p['kh']//2)),a[9]),mul(b(256),a[10]))
    f1=sub(sub(add(a[3],b(32768)),a[4]),mul(b(256),a[5]))
    fh=sub(sub(add(a[6],b(32768)),a[7]),mul(b(256),a[8]))
    gl=sm(mul(p['mu'][i],x) for i,x in enumerate([f0,f1,fh]))
    return [gl]+([mul(p['mupad'],sm(mul(w,x) for w,x in zip(p['pad'],a)))] if supp else [])
def split_poly(v,p,supp,derived):
    a=v[3:14]
    ds=[sub(p['alpha'],add(p['cst'][j],mul(b(p['coef'][j]),a[t]))) for j,t in enumerate([1,1,4,5,7,8,9,10,10])]
    terms=[]
    for j in range(4):
        d,e=ds[2*j:2*j+2]
        terms.append(mul(p['mu'][4+j],sub(sub(mul(mul(v[14+j],d),e),d),e)))
    terms.append(mul(p['mu'][8],sub(mul(v[18],ds[8]),O)))
    fd=sub(p['alpha'],sm([a[0],b(128),mul(p['beta'],a[2]),p['gact']]))
    terms.append(mul(p['mu'][3],sub(mul(v[19],fd),O)))
    gated=add(derived[0],mul(p['mu'][0],mul(a[2],a[3])))
    host=add(mul(mul(p['nu'][0],v[1]),sub(add(mul(b(p['kg']),a[0]),a[1]),b(p['kg']//2))),mul(mul(p['nu'][1],v[2]),a[3]))
    if supp:
        terms.extend([mul(v[20],gated),mul(sub(O,v[20]),derived[1])])
        host=mul(v[20],host)
    else:terms.append(gated)
    return add(mul(v[0],sm(terms)),host)

class Arena:
    def __init__(self,k,l,mode,raw,bug=None):
        ck(mode=='dense' or raw,'compressed arena needs existing raw eligibility')
        self.k=k;self.kd=k+1+(k==21);self.l=l;self.mode=mode;self.bug=bug
        self.cap=[l//2 if mode!='dense' and 3<=t<=19 else (0 if mode=='implicit' and t>=k else l) for t in range(self.kd)]
        self.off=[];n=0
        for w in self.cap:self.off.append(n);n+=w
        self.mem=[None]*n;self.raw=raw
    def addr(self,t,i,phase,write=False):
        ck(0<=t<self.kd and 0<=i<self.cap[t],(phase,'bounds',t,i,self.cap[t]))
        addr=self.off[t]+i
        if self.bug==phase:addr=t*self.l+i
        ck(0<=addr<len(self.mem),(phase,'allocation bounds'))
        EVENTS[phase]=EVENTS.get(phase,0)+1
        return addr
    def put(self,t,i,v,phase):self.mem[self.addr(t,i,phase,True)]=v
    def get(self,t,i,phase):
        v=self.mem[self.addr(t,i,phase)];ck(v is not None,(phase,'uninitialized',t,i));return v

def params(rng,pad):
    x=lambda:(rng.randrange(P),rng.randrange(P))
    return dict(alpha=x(),beta=x(),gact=x(),mu=[x() for _ in range(9)],nu=[x(),x()],cst=[x() for _ in range(9)],coef=[rng.randrange(P) for _ in range(9)],kh=512,kg=32,mupad=x(),pad=[x() if pad else Z for _ in range(11)])
def refparams(p):
    return {k:ref.R(*v) if isinstance(v,tuple) else [ref.R(*x) if isinstance(x,tuple) else x for x in v] if isinstance(v,list) else v for k,v in p.items()}
def bytesof(v):return b''.join(struct.pack('<QQ',*x) for x in v)

def fixture(n,supp,base,pad,mode,tail,seed,bug=None):
    rng=random.Random(seed);l=1<<n;k=20+supp;degree=4+(seed%2)
    p=params(rng,pad);rp=refparams(p)
    original=[[(rng.randrange(P),0 if base and (3<=t<=13 or t==20) else rng.randrange(P)) for _ in range(l)] for t in range(k)]
    if supp:original[20]=[(int(i<l*3//4),0) for i in range(l)]
    raw=mode!='dense';ar=Arena(k,l,mode,raw,bug)
    if bug=='constructor':
        for t in range(k):ck(l<=ar.cap[t],'old full slice runs beyond table capacity')
    for t in range(k):
        if not raw or not 3<=t<=19:
            for i in range(l):ar.put(t,i,original[t][i],'constructor')
    derived=[[derive([original[t][i] for t in range(k)],p,supp)[j] for i in range(l)] for j in range(1+supp)]
    if mode!='implicit':
        for j,tb in enumerate(derived):
            for i,x in enumerate(tb):ar.put(k+j,i,x,'raw_round0_derived')
    challenges=[];previous=b'native-fzc-arena-synthetic-chain-v1';round_hashes=[];host=None;active=l
    for round_no in range(n):
        rt=[ref.direct_prefix(tb,[ref.R(*r) for r in challenges]) for tb in original]
        expected=ref.round_values(rt,rp,supp,degree)
        def read(t,i,phase):
            if host is not None:return host[t][i]
            if round_no==0 and raw and 3<=t<=19:return original[t][i]
            return ar.get(t,i,phase)
        phase='raw_round0_read' if round_no==0 and raw else 'later_round_read'
        half=active//2;sums=[Z]*(degree+1)
        for i in range(half):
            endpoints=[[read(t,j,phase) for t in range(k)] for j in [i,i+half]]
            if mode=='implicit' or host is not None:
                # Proposed native seam: rematerialize the two derived
                # endpoints once from staged A, then step their differences.
                ed=[derive(v,p,supp,bad_constant=bug=='affine') for v in endpoints]
                if bug=='affine_delta':
                    delta=derive([sub(c,a) for a,c in zip(*endpoints)],p,supp)
                    ed[1]=[add(a,dv) for a,dv in zip(ed[0],delta)]
            for d in range(degree+1):
                v=[fold(a,c,b(d)) for a,c in zip(*endpoints)]
                dv=[fold(a,c,b(d)) for a,c in zip(*ed)] if mode=='implicit' or host is not None else [fold(ar.get(k+j,i,phase),ar.get(k+j,i+half,phase),b(d)) for j in range(1+supp)]
                sums[d]=add(sums[d],split_poly(v,p,supp,dv))
        ck(sums==expected,('round polynomial',n,mode,round_no))
        # Exercise s(1) recovery on the actual polynomial, with a synthetic
        # valid claim for this arbitrary table fixture (not a zero witness).
        claim=add(expected[0],expected[1]); recovered=list(sums);recovered[1]=sub(claim,sums[0]);ck(recovered==expected,'recover_one')
        cb=bytesof(sums);rb=bytesof(expected);ck(cb==rb,'canonical field bytes')
        cd=hashlib.sha256(previous+cb).digest();rd=hashlib.sha256(previous+rb).digest();ck(cd==rd,'synthetic next challenge')
        r=(int.from_bytes(cd[:16],'little')%P,int.from_bytes(cd[16:],'little')%P);ck(r[1]!=0,'extension challenge')
        round_hashes.append(cd.hex());previous=cd;challenges.append(r)
        is_last=round_no==n-1
        if host is not None:
            host=[[fold(tb[i],tb[i+half],r) for i in range(half)] for tb in host]
        else:
            # Fused kernel's disjoint four-entry chunks; all reads for a
            # thread occur before either destination is overwritten.
            phase='generic_fold' if is_last or (tail and half<=1<<tail) else 'first_fused_fold' if round_no==0 else 'later_fused_fold'
            limit=k if mode=='implicit' else ar.kd
            for t in range(limit):
                if half>=2 and 'fused' in phase:
                    q=half//2;order=list(range(q));rng.shuffle(order)
                    for i in order:
                        def source(j):
                            return original[t][j] if round_no==0 and raw and 3<=t<=19 else ar.get(t,j,phase)
                        a0,a1,b0,b1=[source(j) for j in [i,i+half,i+q,i+q+half]]
                        ar.put(t,i,fold(a0,a1,r),phase);ar.put(t,i+q,fold(b0,b1,r),phase)
                else:
                    for i in range(half):ar.put(t,i,fold(ar.get(t,i,phase),ar.get(t,i+half,phase),r),phase)
            for t in range(k):
                got=[ar.get(t,i,'fold_check') for i in range(half)]
                ck(got==[x.v for x in ref.direct_prefix(original[t],[ref.R(*r) for r in challenges])],'direct original MLE')
            if tail and not is_last and half<=1<<tail:
                # Native packs original k tables only; derived tables stay
                # device-only and desc.eval is used by the host tail.
                host=[[ar.get(t,i,'pack') for i in range(half)] for t in range(k)]
                ck(bytesof([v for tb in host for v in tb])==bytesof([x.v for tb in original for x in ref.direct_prefix(tb,[ref.R(*r) for r in challenges])]),'pack bytes')
        active=half
    finals=[tb[0] for tb in host] if host is not None else [ar.get(t,0,'finals') for t in range(k)]
    ck(finals==[ref.direct_prefix(tb,[ref.R(*r) for r in challenges])[0].v for tb in original],'finals')
    return dict(n=n,support=supp,base_round0=base,pad_nonempty=pad,mode=mode,tail_log=tail,seed=seed,degree=degree,entries=len(ar.mem),round_hashes=round_hashes,final_sha256=hashlib.sha256(bytesof(finals)).hexdigest())

def main():
    global NEG
    start=time.perf_counter();rng=random.Random(SEED)
    edges=[0,1,P-1,P-2,2**32-1,2**32,2**63]
    vals=[(a,b) for a in edges for b in edges]+[(rng.randrange(P),rng.randrange(P)) for _ in range(1000)]
    for a in vals:
        c=vals[rng.randrange(len(vals))];ck(mul(a,c)==(ref.R(*a)*ref.R(*c)).v,'field schoolbook');ck(add(a,c)==(ref.R(*a)+ref.R(*c)).v);ck(sub(a,c)==(ref.R(*a)-ref.R(*c)).v)
    ck(mul((0,1),(0,1))==(7,0),'u squared')
    cases=[]
    for n in [3,4,6]:
        for supp in [0,1]:
            for base in [False,True]:
                for pad in ([False,True] if supp else [False]):
                    for tail in [0,1]:
                        seed=SEED+10000*n+1000*supp+100*base+10*pad+tail
                        group=[]
                        for mode in ['dense','mixed','implicit']:
                            c=fixture(n,supp,base,pad,mode,tail,seed);cases.append(c);group.append(c)
                        ck(len({tuple(x['round_hashes']) for x in group})==1,'all layouts synthetic chain');ck(len({x['final_sha256'] for x in group})==1,'all layouts finals')
    controls=[]
    for bug in ['constructor','first_fused_fold','later_fused_fold','generic_fold','later_round_read','pack','finals','affine','affine_delta']:
        try:fixture(4,1,True,True,'implicit' if bug.startswith('affine') else 'mixed',1 if bug=='pack' else 0,SEED,bug)
        except AssertionError as ex:NEG+=1;controls.append(dict(bug=bug,rejected=str(ex)[:160]))
        else:raise AssertionError(('bad consumer accepted',bug))
    try:Arena(21,16,'mixed',False)
    except AssertionError:NEG+=1;controls.append(dict(bug='compressed_without_raw',rejected=True))
    else:raise AssertionError('missing eligibility accepted')
    # Negative arithmetic: two independent residue lanes miss u*u=7.
    bad_componentwise=lambda a,c:((a[0]*c[0])%P,(a[1]*c[1])%P)
    ck(bad_componentwise((0,1),(0,1))!=(ref.R(0,1)*ref.R(0,1)).v)
    NEG+=1;controls.append(dict(bug='old_componentwise_extension_multiply',rejected=True))
    out=dict(status='PASS_PYTHON_MODEL_ONLY',checks=CHECKS,negative_controls=NEG,fixtures=len(cases),rounds=sum(x['n'] for x in cases),seed=SEED,field_modulus=P,extension='u^2=7',events=EVENTS,ops=OPS,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,affinity=sorted(os.sched_getaffinity(0)),threads=1,scope='Authored Python Goldilocks Fp2/actual-FZC algebra and addressing; no Rust/CUDA execution, native transcript/masks, proof or verification',full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
    for name,data in [('result.json',out),('cases.json',cases),('negative-controls.json',controls)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(out))
if __name__=='__main__':main()
