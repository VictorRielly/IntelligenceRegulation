"""Periodic SC_TAB under source-derived masks/replay; synthetic evidence only."""
import copy,hashlib,json,random,resource,time
from pathlib import Path
from field import F,P,bits,fold
from driver import Dense,Tables,Rounds,interpolate,extend
from periodic import Periodic,encode,tab_poly,eval_public
from masking import Transcript,Mask,refuse_c,refuse_terminal
import reference as ref
import mask_reference as mr
E=Path(__file__).resolve().parent; START=time.monotonic(); SEED=202610280129
rng=random.Random(SEED);checks=0;controls=[];rows=[];round_count=mask_samples=oracle_samples=claim_count=0
PRIVATE=(1,2,4,5,7,8);DOMAIN=b'research/synthetic-sc-tab-mask/1'
def check(ok,label):
    global checks
    checks+=1
    if not ok: raise AssertionError(label)
def rf(): return F(rng.randrange(P),rng.randrange(P))
def ts(v): return [ref.tup(x) for x in v]
def refused(fn,label,expected=None):
    try: fn()
    except ValueError as ex:
        if expected is not None: check(expected in str(ex),'refusal identity '+label)
        controls.append(label);return
    raise AssertionError('missed control '+label)
def params(n,key):
    t=Transcript(DOMAIN,key); r=mr.Replay(DOMAIN,key)
    def draw():
        a=t.challenge();check(ref.tup(a)==r.challenge(),'prelude challenge');return a
    alpha,beta=draw(),draw();gammas=[draw() for _ in range(3)]
    tau=[draw() for _ in range(n)]; mu=[draw() for _ in range(3+int(n>8))]
    if n==8: mu.append(F()); zeta=F()
    else: zeta=draw()
    t.u64(b'pb-slot',19);r.u64(b'pb-slot',19);c=draw();refuse_c(c)
    return t,r,alpha,beta,gammas,tau,mu,zeta,c

def make_words(n,alpha,beta,gs,tau):
    raw=[[0]*256,[rng.randrange(-2**30,2**30) for _ in range(256)],[rng.randrange(-32768,32768) for _ in range(256)]]
    pub=[encode(k,v,beta,g) for k,v,g in zip(('u8','exp','act'),raw,gs)]
    for k,v,g,p in zip(('u8','exp','act'),raw,gs,pub): check(ts(p)==ref.encode(k,v,ref.tup(beta),ref.tup(g)),'fresh encoded rows')
    N=1<<n; eq=[]
    for i in range(N):
        w=F(1)
        for b,x in zip(bits(i,n),tau): w*=x if b else 1-x
        eq.append(w)
    words=[eq]
    for k in range(3):
        m=[F(rng.randrange(100)) for _ in range(256)]+[F()]*(N-256)
        h=[m[i]/(alpha-pub[k][i%256]) for i in range(N)]
        words.extend([m,h,[pub[k][i%256] for i in range(N)]])
    if n>8: words.append([F(int(i<256)) for i in range(N)])
    return words,pub

def verify_record(record,key,mask,original,pub,alpha,mu,zeta,target_rows):
    n=record['n']; t=Transcript(DOMAIN,key)
    # Replay exactly the synthetic caller prelude. Native prior slots are absent.
    for _ in range(2+3+n+3+int(n>8)+int(n>8)): t.challenge()
    t.u64(b'pb-slot',19);c=t.challenge();refuse_c(c)
    if len(record['rounds'])!=n+1: raise ValueError('round count')
    if len(record['terms'])!=6: raise ValueError('terminal count')
    t.fp2(b'pb-scalar',[record['scalar']]);claim=record['scalar'];rho=[]
    for j,s in enumerate(record['rounds']):
        if len(s)!=4: raise ValueError('round degree')
        if s[0]+s[1]!=claim: raise ValueError('round sum '+str(j))
        t.fp2(b'sc-round',s);r=t.challenge();rho.append(r);claim=interpolate(s,r)
    es=rho[n:];refuse_terminal(es);sel=1-es[0]
    values=[];k=0
    for i,w in enumerate(original):
        if i in PRIVATE: values.append(record['terms'][k]);k+=1
        elif i in (3,6,9): values.append(eval_public(n,pub[(i-3)//3],rho[:n],es))
        else: values.append(F(*ref.mle(w,ts(rho[:n])))*sel)
    inferred=(claim-tab_poly(values,alpha,mu,zeta,n>8))/c
    # Local linear-functional equality stands in for the native committed opening.
    if inferred!=mask.evaluate(rho): raise ValueError('mask evaluation functional')
    if record['scalar']!=c*mask.total(): raise ValueError('mask sum functional')
    for k,i in enumerate(PRIVATE):
        expected=F(*ref.mle(original[i],ts(rho[:n])))*sel
        # Independently evaluate the original reserved pair at the column tail.
        re,im=target_rows[i]
        tail=ts(rho[n-8:n]);rv=ref.mle([(x,0) for x in re],tail);iv=ref.mle([(x,0) for x in im],tail)
        target=ref.add(rv,ref.mul((0,1),iv));expected+=es[0]*F(*target)
        if expected!=record['terms'][k]: raise ValueError('private claim '+str(i))
    t.fp2(b'pb-term',record['terms'])
    return t.state,t.challenge(),rho

for n in (8,9,10):
  for keyed in (False,True):
    key=bytes(rng.randrange(256) for _ in range(32)) if keyed else None
    t,rt,alpha,beta,gs,tau,mu,zeta,c=params(n,key)
    words,pub=make_words(n,alpha,beta,gs,tau);original=[ts(w) for w in words]
    cf=Mask(n+1,3,[rf() for _ in range(3*(n+1)+2)]);coeff=ts(cf.coeffs)
    check(ref.tup(cf.total())==mr.total_direct(coeff,n+1),'mask total original full cube')
    entries=[];dense=[]
    for i,w in enumerate(words):
        entries.append((str(i),i in PRIVATE,Periodic(n,pub[(i-3)//3],1<<n) if i in (3,6,9) else Dense(n,w)))
        dense.append((str(i),i in PRIVATE,Dense(n,w)))
    poly=lambda v:tab_poly(v,alpha,mu,zeta,n>8)
    cr=Rounds(Tables(n,entries),3,poly,chunk=7,recover=True,claim=None)
    dr=Rounds(Tables(n,dense),3,poly,chunk=1024,recover=False)
    scalar=c*cf.total();t.fp2(b'pb-scalar',[scalar]);rt.fp2(b'pb-scalar',[ref.tup(scalar)])
    prev=[];masked=[];claim=scalar
    for j in range(n):
        u=cr.round(j);v=dr.round(j);o=ref.round_samples(original,n,ts(prev),ref.tup(alpha),ts(mu),ref.tup(zeta),n>8)
        check(u==v,'explicit dense vs recovered descriptor');check(ts(u)==o,'independent original cube round');oracle_samples+=4
        g=cf.round(j,prev);og=mr.round_direct(coeff,n+1,ts(prev));check(ts(g)==og,'full mask round from Boolean suffix');mask_samples+=4
        s=[a+c*b for a,b in zip(u,g)];os=[ref.add(a,ref.mul(ref.tup(c),b)) for a,b in zip(o,og)]
        check(ts(s)==os,'masked wire coordinates');check(s[0]+s[1]==claim,'masked round recurrence')
        t.fp2(b'sc-round',s);rt.fp2(b'sc-round',os);r=t.challenge();rr=rt.challenge()
        check(ref.tup(r)==rr and t.state==rt.state,'masked transcript and draw')
        claim=interpolate(s,r);check(ref.tup(claim)==mr.lagrange(os,rr),'independent interpolation')
        cr.bind(r);dr.bind(r);prev.append(r);masked.append(s);round_count+=1
    finals=cr.finals();check(finals==dr.finals(),'final table order')
    for i,w in enumerate(original):check(ref.tup(finals[i])==ref.mle(w,ts(prev)),'original MLE final')
    target_rows={i:([rng.randrange(P) for _ in range(256)],[rng.randrange(P) for _ in range(256)]) for i in PRIVATE}
    targets={}
    for i,(re,im) in target_rows.items():
        a=[F(x,y) for x,y in zip(re,im)]
        for r in prev[-8:]:a=fold(a,r)
        targets[str(i)]=a[0]
    ext=[];ext_o=[]
    for x in range(4):
        v=extend(finals,entries,targets,F(x));ext.append(poly(v))
        ov=[ref.add(ref.mul((1-x,0),ref.tup(f)),ref.mul((x,0),ref.tup(targets.get(str(i),F())))) for i,f in enumerate(finals)]
        ext_o.append(ref.poly(ov,ref.tup(alpha),ts(mu),ref.tup(zeta),n>8))
    g=cf.round(n,prev);og=mr.round_direct(coeff,n+1,ts(prev));check(ts(g)==og,'extension mask independent');mask_samples+=4
    s=[a+c*b for a,b in zip(ext,g)];os=[ref.add(a,ref.mul(ref.tup(c),b)) for a,b in zip(ext_o,og)]
    check(ts(s)==os,'independent extension polynomial + mask');check(s[0]+s[1]==claim,'extension recurrence')
    t.fp2(b'sc-round',s);rt.fp2(b'sc-round',os);e=t.challenge();check(ref.tup(e)==rt.challenge(),'extension draw');refuse_terminal([e])
    cur=extend(finals,entries,targets,e);terms=[cur[i] for i in PRIVATE];prev.append(e);masked.append(s);round_count+=1
    claim=interpolate(s,e);gv=(claim-poly(cur))/c
    check(gv==cf.evaluate(prev),'terminal mask functional')
    check(ref.tup(gv)==mr.polynomial(coeff,ts(prev)),'independent terminal mask polynomial')
    check(len(cf.weights(prev))==3*(n+1)+2,'full mask coefficient count')
    for i in (3,6,9):check(cur[i]==eval_public(n,pub[(i-3)//3],prev[:-1],[e]),'public zero extension selector')
    check([terms[i] for i in (0,2,4)]==[cur[i] for i in (1,4,7)],'A private claim order')
    check([terms[i] for i in (1,3,5)]==[cur[i] for i in (2,5,8)],'H private claim order');claim_count+=6
    t.fp2(b'pb-term',terms);rt.fp2(b'pb-term',ts(terms));check(t.state==rt.state,'private terminals absorbed after refusal')
    state=t.state;next_r=t.challenge();check(ref.tup(next_r)==rt.challenge(),'next squeeze')
    record={'n':n,'scalar':scalar,'rounds':masked,'terms':terms}
    vs,vn,_=verify_record(record,key,cf,original,pub,alpha,mu,zeta,target_rows)
    check((vs,vn)==(state,next_r),'fresh local verifier replay')
    # Refuse actual mutant wire/arity/private-claim records under the same prelude.
    for kind in ('round','round_count','degree','term_count','term_order','term_value','scalar'):
        bad=copy.deepcopy(record)
        if kind=='round':bad['rounds'][0][0]+=1
        elif kind=='round_count':bad['rounds'].pop()
        elif kind=='degree':bad['rounds'][0].pop()
        elif kind=='term_count':bad['terms'].pop()
        elif kind=='term_order':bad['terms'][0],bad['terms'][1]=bad['terms'][1],bad['terms'][0]
        elif kind=='term_value':bad['terms'][0]+=F(0,1)
        else:bad['scalar']+=1
        refused(lambda:verify_record(bad,key,cf,original,pub,alpha,mu,zeta,target_rows),f'n{n}/key{keyed}/{kind}')
    # Inconsistent standalone witnesses must supply their actual first round.
    bad_words=[list(w) for w in words];bad_words[1][37]+=1
    bad_entries=[(str(i),i in PRIVATE,Dense(n,w)) for i,w in enumerate(bad_words)]
    actual=Rounds(Tables(n,bad_entries),3,poly,recover=True,claim=None).round(0)
    check(actual[0]+actual[1]!=F(),'inconsistent standalone first round retained')
    bad_masked=[a+c*b for a,b in zip(actual,cf.round(0,[]))]
    check(bad_masked[0]+bad_masked[1]!=scalar,'inconsistent standalone refuses round zero');controls.append(f'n{n}/key{keyed}/inconsistent standalone')
    # An optimized descriptor must never shorten the full CFS variable basis.
    short=Mask(9,3,cf.coeffs[:29])
    if n>8:
        check(short.total()!=cf.total(),'shortened CFS changes total');controls.append(f'n{n}/key{keyed}/shortened mask')
    wire=b''.join(v.wire() for row in masked for v in row)
    filename=f'synthetic-n{n}-key{int(keyed)}-rounds.bin';(E/filename).write_bytes(wire)
    rows.append({'n':n,'full_mask_variables':n+1,'mask_coefficients':len(cf.coeffs),'keyed':keyed,'rounds':n+1,'synthetic_round_bytes':len(wire),'round_sha256':hashlib.sha256(wire).hexdigest(),'state_hex':state.hex(),'private_claims':6,'recoveries':cr.recoveries})

# Exhaust every coefficient basis on small full cubes, including a'=product term.
basis_checks=0
for n in (2,4):
  for index in range(3*n+2):
    coeffs=[F()]*(3*n+2);coeffs[index]=F(2,3);mask=Mask(n,3,coeffs);orig=ts(coeffs)
    check(ref.tup(mask.total())==mr.total_direct(orig,n),'basis mask total');basis_checks+=1
    prev=[]
    for j in range(n):
        check(ts(mask.round(j,prev))==mr.round_direct(orig,n,ts(prev)),'basis mask rounds');basis_checks+=4
        prev.append((F(),F(1),F(2,3),F(0,1))[j])
    check(ref.tup(mask.evaluate(prev))==mr.polynomial(orig,ts(prev)),'basis terminal');basis_checks+=1

refused(lambda:refuse_c(F()),'zero CFS','zero CFS')
for e in (F(),F(1)):refused(lambda:refuse_terminal([e]),'terminal '+str(e.a),'degenerate terminal')
for e in (F(2),F(0,1)):refuse_terminal([e]);check(True,'nondegenerate terminal accepted')
refused(lambda:Mask(10,3,[F()]*29),'wrong full mask extent','mask shape')
refused(lambda:Mask(2,3,[F()]*8).round(1,[]),'mask prefix mismatch','mask round')
out={'status':'PASS_SOURCE_DERIVED_MASKED_MODEL_ONLY','seed':SEED,'checks':checks,'cases':rows,'main_plus_extension_rounds':round_count,'independent_main_polynomial_samples':oracle_samples,'independent_mask_samples':mask_samples,'basis_sample_checks':basis_checks,'private_claims_checked':claim_count,'controls':controls,'control_instances':len(controls),'elapsed_seconds':time.monotonic()-START,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'native_proofs':0,'limits':'Synthetic locally authored source-derived CFS, BLAKE3 framing, six reserved-pair claims and original-cube oracle; not a native executable, full transcript/profile, mask RNG/commitment/PCS, capture, receipt or privacy proof. No GPU or speedup.'}
(E/'result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
