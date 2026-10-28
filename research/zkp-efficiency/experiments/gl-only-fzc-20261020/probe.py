"""Bounded Python algebra, round-byte and partial source-cost experiment."""
from pathlib import Path
from collections import Counter
import hashlib,json,os,random,resource,struct,time
import reference as ref
import prior_fzc_model as prior
from affine import Ops,pair,prepare,Z,P
from base_pair import derived as full_derived
from gl_only import derived
H=Path(__file__).resolve().parent
SEED=2026102099

def enc(v):return b''.join(struct.pack('<QQ',*x) for x in v)

def original_affine(a,p,supp):
    # Original clauses, independent quotient-field arithmetic, no scalar code.
    a=[ref.R(*x) for x in a];m=[ref.R(*x) for x in p['mu']]
    g=m[0]*(-p['kh']*a[6]+p['kh']//2-a[9]-256*a[10])
    g+=m[1]*(a[3]+32768-a[4]-256*a[5])
    g+=m[2]*(a[6]+32768-a[7]-256*a[8])
    out=[g.v]
    if supp:out.append((ref.R(*p['mupad'])*sum((ref.R(*w)*x for w,x in zip(p['pad'],a)),ref.R())).v)
    return out

def primitive_count(p,supp,mode):
    lo=[(i+1,0) for i in range(11)];delta=[(2*i+3,0) for i in range(11)]
    o=Ops()
    if mode=='literal':got,reads=pair(o,lo,delta,p,supp,'literal')
    elif mode=='gl_only':got,reads=derived(o,lo,delta,p,supp,True)
    else:got,reads=full_derived(o,lo,delta,p,supp,prepare(Ops(),p),True)
    # Each path writes the same high endpoint. Literal already computed it;
    # GL-only reconstructs GL high, full_base reconstructs GL and PL highs.
    if mode=='gl_only':o.a(*got[0])
    elif mode=='full_base':
        for v,dv in got:o.a(v,dv)
    return {k:o.c[k] for k in ['base_mul','base_add','base_sub']},reads

def main():
    start=time.perf_counter();checks=0;rounds=0;cases=[];negative=[]
    edge=[0,1,2**32-1,2**32,2**63,P-2,P-1]
    for n in [3,4,5]:
     for supp in [0,1]:
      for support_size in ([0] if not supp else [0,1,3,8,11]):
       for base in [False,True]:
        seed=SEED+n*10000+supp*1000+support_size*10+base;rng=random.Random(seed)
        p=prior.params(rng,True);p['kh']=1<<rng.choice([9,10,12,15,16]);p['kg']=1<<rng.choice([1,4,8])
        pos=rng.sample(range(11),support_size);p['pad']=[p['pad'][j] if j in pos else Z for j in range(11)]
        if not support_size:p['mupad']=Z
        original=[[(rng.choice(edge) if (i+t)%4==0 else rng.randrange(P),0 if base and (3<=t<=13 or t==20) else rng.randrange(P)) for i in range(1<<n)] for t in range(20+supp)]
        tabs=[list(t) for t in original]
        dt=[[original_affine([t[i] for t in original[3:14]],p,supp)[j] for i in range(1<<n)] for j in range(1+supp)]
        q=prepare(Ops(),p) if supp else None;history=[];digest=b'gl-only-synthetic-v1';hashes=[];dispatches=[]
        for rno in range(n):
         half=len(tabs[0])//2;out=[Z]*6;dispatch=base and rno==0;dispatches.append(dispatch)
         for i in range(half):
          lo=[t[i] for t in tabs];hi=[t[i+half] for t in tabs]
          delta=[prior.sub(y,x) for x,y in zip(lo[3:14],hi[3:14])]
          got,_=derived(Ops(),lo[3:14],delta,p,supp,dispatch)
          expected=[(t[i],prior.sub(t[i+half],t[i])) for t in dt]
          assert got==full_derived(Ops(),lo[3:14],delta,p,supp,q,dispatch)[0];checks+=1
          assert got==expected;checks+=1
          assert [prior.add(v,d) for v,d in got]==[t[i+half] for t in dt];checks+=1
          if dispatch:
           assert all(x[1]==0 for x in lo[3:14]+hi[3:14]);checks+=1
          for x in range(6):
           v=[prior.fold(a,b,(x,0)) for a,b in zip(lo,hi)]
           vd=[prior.add(a,prior.mul((x,0),d)) for a,d in got]
           out[x]=prior.add(out[x],prior.split_poly(v,p,supp,vd))
         rt=[ref.direct_prefix(t,[ref.R(*r) for r in history]) for t in original]
         assert enc(out)==enc(ref.round_values(rt,prior.refparams(p),supp,5));checks+=1;rounds+=1
         digest=hashlib.sha256(digest+enc(out)).digest();hashes.append(digest.hex())
         r=(int.from_bytes(digest[:16],'little')%P,int.from_bytes(digest[16:],'little')%P);history.append(r)
         tabs=[[prior.fold(t[i],t[i+half],r) for i in range(half)] for t in tabs]
         dt=[[prior.fold(t[i],t[i+half],r) for i in range(half)] for t in dt]
        assert [t[0] for t in tabs]==[ref.direct_prefix(t,[ref.R(*r) for r in history])[0].v for t in original];checks+=1
        final=original_affine([t[0] for t in tabs[3:14]],p,supp)
        assert [t[0] for t in dt]==final;checks+=1
        assert prior.split_poly([t[0] for t in tabs],p,supp,final)==ref.poly([ref.R(*t[0]) for t in tabs],prior.refparams(p),supp).v;checks+=1
        cases.append(dict(seed=seed,entries=1<<n,n=n,support=supp,pad_nonzero=support_size,base=base,dispatches=dispatches,round_hashes=hashes))
    # Existing BASE only; keep sparse PL exact and all derived imaginary parts.
    rng=random.Random(SEED);p=prior.params(rng,True)
    lo=[(rng.randrange(P),0) for _ in range(11)];d=[(rng.randrange(P),0) for _ in range(11)]
    good=derived(Ops(),lo,d,p,True,True)[0]
    assert any(v[1] for vd in good for v in vd);checks+=1
    def reject(name,bad,expected=good):
        assert bad!=expected,name;negative.append(name)
    for j in [3,4,5,6,7,8,9,10]:
        badlo=list(lo);badlo[j]=(badlo[j][0],1)
        expected=pair(Ops(),badlo,d,p,True,'literal')[0]
        reject('BASE_on_extension_GL_A_'+str(j),derived(Ops(),badlo,d,p,True,True)[0],expected)
    # A0,1,2 are PL-only; literal PL must keep their imaginary coordinates.
    for j in [0,1,2]:
        badlo=list(lo);badlo[j]=(badlo[j][0],1)
        assert derived(Ops(),badlo,d,p,True,True)[0]==pair(Ops(),badlo,d,p,True,'literal')[0];checks+=1
    badd=list(d);badd[6]=(badd[6][0],1)
    reject('BASE_on_extension_difference',derived(Ops(),lo,badd,p,True,True)[0],pair(Ops(),lo,badd,p,True,'literal')[0])
    foldedlo=[prior.add(a,prior.mul((2,3),b)) for a,b in zip(lo,d)]
    reject('BASE_after_extension_fold',derived(Ops(),foldedlo,d,p,True,True)[0],pair(Ops(),foldedlo,d,p,True,'literal')[0])
    reject('truncate_extension_results',[((v[0],0),(dv[0],0)) for v,dv in good])
    reject('constant_in_difference',[(good[0][0],original_affine(d,p,False)[0]),good[1]])
    reject('omit_high_reconstruction',[(v,v) for v,dv in good],[(v,prior.add(v,dv)) for v,dv in good])
    # The untouched PL path must use current mu_pad without host coefficients.
    stale=dict(p,mupad=prior.add(p['mupad'],(1,0)))
    reject('stale_mupad',derived(Ops(),lo,d,stale,True,True)[0])
    reject('zero_mupad',derived(Ops(),lo,d,dict(p,mupad=Z),True,True)[0])
    costs=[]
    for supp,k in [(False,0)]+[(True,k) for k in [0,1,3,8,11]]:
      pp=dict(p,pad=[(j+1,j+2) if j<k else Z for j in range(11)],mupad=(17,19))
      for mode in ['literal','gl_only','full_base']:
       c,rd=primitive_count(pp,supp,mode)
       if mode=='literal':f=dict(base_mul=34+supp*6*(k+1),base_add=72+supp*(18*k+12),base_sub=48+supp*(6*k+8));rr=384+48*k*supp
       elif mode=='gl_only':f=dict(base_mul=20+supp*6*(k+1),base_add=13+supp*(18*k+12),base_sub=14+supp*(6*k+8));rr=128+48*k*supp
       else:f=dict(base_mul=20+supp*4*k,base_add=13+supp*(4*k+2),base_sub=14);rr=128+16*k*supp
       assert c==f and rd==rr,(mode,k,c,f,rd,rr);checks+=2
       for n in [3,6,12,21,24]:
        count=1<<(n-1)
        costs.append(dict(mode=mode,support=supp,pad_nonzero=k,n=n,entries=1<<n,per_pair=c,raw_round0_primitives={x:v*count for x,v in c.items()},logical_shared_operand_read_bytes=rd*count,host_preweight_fp2_products=k if mode=='full_base' and supp else 0,added_parameter_bytes=16*k if mode=='full_base' and supp else 0,global_bytes_saved=0,capacity_bytes_saved=0,extra_barriers=0,scope='derived phase1b only; includes high stores; source calls not compiled instructions'))
    for supp in [False,True]:
      for padzero in [False,True]:
       pp=dict(p,mupad=Z if padzero else p['mupad'],pad=[Z]*11 if padzero else p['pad'])
       assert derived(Ops(),lo,d,pp,supp,True)[0]==pair(Ops(),lo,d,pp,supp,'literal')[0];checks+=1
    result=dict(status='PASS_PYTHON_ALGEBRA_AND_PARTIAL_SOURCE_COSTS_ONLY',fixtures=len(cases),rounds=rounds,checks=checks,negative_controls=len(negative),cost_cases=len(costs),seed=SEED,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_fraction=None,steady_rate=None,total_rate=None),scope='Synthetic quotient-field/original-polynomial/direct-original-MLE checks; no native code/masks/transcript/PCS/receipt/verifier')
    for name,data in [('result.json',result),('cases.json',cases),('negative-controls.json',negative),('cost-cases.json',costs)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result))
if __name__=='__main__':main()
