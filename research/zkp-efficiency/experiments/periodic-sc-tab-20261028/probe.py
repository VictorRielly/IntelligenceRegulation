"""Bounded differential SC_TAB algebra; no CFS/transcript/PCS/native proof."""
import json,random,resource,time
from pathlib import Path
from field import F,P,bits
from driver import Dense,Tables,Rounds,extend
from periodic import Periodic,encode,tab_poly,eval_public
import reference as ref
ROOT=Path(__file__).resolve().parent; START=time.monotonic();SEED=202610280128
rng=random.Random(SEED);checks=0;controls=[];rounds=entries=finals=ext_checks=0
def check(ok,label):
    global checks
    checks+=1
    assert ok,label
def refuse(f,label):
    try:f()
    except ValueError: controls.append(label);check(True,label);return
    raise AssertionError(label)
def rf():return F(rng.randrange(P),rng.randrange(P))
def tuples(v):return [ref.tup(x) for x in v]

for n in (8,9,10):
  for mode in ('full_fp2','zero_one'):
    N=1<<n;padded=n>8
    beta,gamma,alpha=rf(),[rf() for _ in range(3)],rf();mu=[rf() for _ in range(4)];zeta=rf()
    raws=[[0]*256,[rng.randrange(-2**40,2**40) for _ in range(256)],[-32768,32767]+[rng.randrange(-32768,32768) for _ in range(254)]]
    pubs=[encode(kind,raw,beta,g) for kind,raw,g in zip(('u8','exp','act'),raws,gamma)]
    for kind,raw,g,values in zip(('u8','exp','act'),raws,gamma,pubs):
        check(tuples(values)==ref.encode(kind,raw,ref.tup(beta),ref.tup(g)),'fresh integer encoding')
    tau=[rf() for _ in range(n)]
    eq=[]
    for x in range(N):
        a=F(1)
        for b,t in zip(bits(x,n),tau):a*= t if b else 1-t
        eq.append(a)
    words=[eq]
    for k in range(3):words.extend([[rf() for _ in range(N)],[rf() for _ in range(N)],[pubs[k][i%256] for i in range(N)]])
    if padded:words.append([F(int(i<256)) for i in range(N)])
    original=[tuples(w) for w in words]
    private={1,2,4,5,7,8}
    defs=[];dense=[]
    for i,w in enumerate(words):
        compact=Periodic(n,pubs[(i-3)//3],N) if i in (3,6,9) else Dense(n,w)
        defs.append((str(i),i in private,compact));dense.append((str(i),i in private,Dense(n,w)))
    poly=lambda v:tab_poly(v,alpha,mu,zeta,padded)
    ct=Tables(n,defs);dt=Tables(n,dense)
    # SC_TAB is standalone: no invented generic initial total or asserted-zero recovery.
    cr=Rounds(ct,3,poly,chunk=7,recover=True,claim=None);dr=Rounds(dt,3,poly,chunk=1024,recover=True,claim=None)
    prefix=[]
    for j in range(n):
        for idx in (3,6,9):
            for cell in range(1<<(n-j)):
                check(defs[idx][2].at(cell)==dense[idx][2].at(cell),'each public restricted row')
        a=cr.round(j);b=dr.round(j);o=ref.round_samples(original,n,prefix,ref.tup(alpha),tuples(mu),ref.tup(zeta),padded)
        check(a==b,'dense vs compact round');check(tuples(a)==o,'original-cube expanded polynomial round');rounds+=1
        r=rf() if mode=='full_fp2' else [F(),F(1),F(0,1)][j%3]
        cr.bind(r);dr.bind(r);prefix.append(ref.tup(r))
    cf,df=cr.finals(),dr.finals();check(cf==df,'all terminals original order')
    for i,w in enumerate(original):check(ref.tup(cf[i])==ref.mle(w,prefix),'original-cube full Fp2 terminal');finals+=1
    for i in (3,6,9):
        desc=defs[i][2];check(desc.lerps==255,'255 suffix interpolations');check(desc.noop_binds==n-8,'leading constant bind count')
        check(eval_public(n,pubs[(i-3)//3],[F(*r) for r in prefix])==cf[i],'verifier periodic terminal')
    for j in range(2):
        # Native SC_TAB has one extension; the second is an extra adapter stress case.
        targets={str(i):rf() for i in private} if j==0 else {}
        for x in range(4):
            cv=extend(cf,defs,targets,F(x));dv=extend(df,dense,targets,F(x));check(cv==dv,'public zero extension table')
            ov=[ref.add(ref.mul((1-x,0),ref.tup(a)),ref.mul((x,0),ref.tup(targets.get(str(i),F())))) for i,a in enumerate(cf)]
            check(ref.tup(poly(cv))==ref.poly(ov,ref.tup(alpha),tuples(mu),ref.tup(zeta),padded),'expanded extension polynomial');ext_checks+=1
        e=rf();cf=extend(cf,defs,targets,e);df=extend(df,dense,targets,e)
        if j==0:es=[e]
        else:es.append(e)
        for i in (3,6,9):check(eval_public(n,pubs[(i-3)//3],[F(*r) for r in prefix],es)==cf[i],'every extension selector')
    for i in range(N):check(words[3][i]==pubs[0][i%256],'complete lifted U8 cube');entries+=1

# Larger public descriptor-only points; no large private fixture/native profile inferred.
large=[]
for n in (13,14):
    base=[rf() for _ in range(256)];point=[rf() for _ in range(n)];point[0]=F()
    desc=Periodic(n,base,1<<n)
    for i in range(1<<n):check(desc.at(i)==base[i%256],'large every periodic index');entries+=1
    for r in point:desc.bind(r)
    oracle=ref.mle([ref.tup(base[i%256]) for i in range(1<<n)],tuples(point))
    check(ref.tup(desc.terminal())==oracle,'large original cube zero-leading Fp2');large.append({'n':n,'rows':1<<n})

base=[F(i*i+3,7*i+1) for i in range(256)];point=[F(2,1),F(3,4)]+[F(i+2,i+1) for i in range(8)]
good=eval_public(10,base,point)
wrong=eval_public(10,base,[*point[2:],*point[:2]])
check(good!=wrong,'wrong suffix axis detected');controls.append('wrong suffix axis')
check(good!=eval_public(10,[F(x.a) for x in base],point),'dropped extension coordinate');controls.append('dropped Fp2 coordinate')
check(good!=eval_public(10,base,point,[F(2,3)]),'missing public extension selector');controls.append('missing extension selector')
check(eval_public(10,base,point,[F(1)])==F(),'algebraic extension one is zero; native refusal still required')
for n in (0,7,31,-1):refuse(lambda:Periodic(n,base),'bad cube '+str(n))
for k in (0,255,257):refuse(lambda:Periodic(8,base[:k] if k<256 else base+[F()]),'bad row cardinality '+str(k))
refuse(lambda:Periodic(9,base,256),'declared length mismatch')
p=Periodic(8,base);refuse(p.terminal,'premature terminal');refuse(lambda:p.at(-1),'negative index');refuse(lambda:p.at(256),'outside index')
for _ in range(8):p.bind(F())
refuse(lambda:p.bind(F()),'overbind');refuse(lambda:eval_public(8,base,[F()]*7),'terminal point length')
# Full padded cube remains essential even when private histograms are zero on pads.
v=[F() for _ in range(11)];v[0]=F(1);v[2]=F(1);v[3]=F(6);v[1]=F(4);a=F(10);m=[F(1)]*4
check(tab_poly(v,a,m,F(1),False)==F(),'padded forged residual alone vanishes')
check(tab_poly(v,a,m,F(1),True)!=F(),'pad-zero still rejects forged padded helper/multiplicity');controls.append('pad-zero cannot be dropped')
# Periodic table != zero-extended 256-row table off domain.
zeroextended=ref.mle([ref.tup(x) for x in base]+[ref.Z]*768,tuples(point))
check(ref.tup(good)!=zeroextended,'zero extension across lifted main cube is wrong');controls.append('zero-filled lifted public cube')
raw=[i*i-30000 for i in range(256)];b=F(2,3);g=F(4,5)
check(encode('exp',raw,b,g)!=encode('exp',raw,b+1,g),'fresh beta required');controls.append('stale beta')
check(encode('act',raw,b,g)!=encode('act',raw,b,g+1),'fresh gamma required');controls.append('stale gamma')
check(encode('act',raw,b,g)!=encode('u8',raw,b,g),'table family kept');controls.append('wrong lookup family')
refuse(lambda:encode('exp',raw[:-1],b,g),'malformed raw table')
refuse(lambda:encode('other',raw,b,g),'unknown public table family')
# Native terminal e=0/1 refusal is a SOURCE obligation, not implemented here.
indexlift=[F(i+1) for i in range(1024)];check(ref.mle(tuples(indexlift),tuples(point))!=ref.mle(tuples([F(i%256+1) for i in range(1024)]),tuples(point)),'index cannot lift range');controls.append('index lift weakens range')
for n in (8,9,13,14):
    N=1<<n
    check(3*(N-1)-3*255==3*(N-256),'independent eliminated folds')
out={'status':'PASS_SYNTHETIC_SC_TAB_ONLY','seed':SEED,'checks':checks,'full_slot_cases':6,'full_slot_n':[8,9,10],'rounds':rounds,'round_sample_coordinates':4*rounds,'independent_terminals':finals,'extension_polynomial_checks':ext_checks,'public_entries_checked':entries,'large_descriptor_only':large,'controls':controls,'elapsed_seconds':time.monotonic()-START,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'native_proofs':0,'limits':'Two locally authored independent algorithms. No native transcript, CFS masks, PCS, receipts, GPU, privacy acceptance or speedup. All private/equality/support tables still dense.'}
(ROOT/'result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
