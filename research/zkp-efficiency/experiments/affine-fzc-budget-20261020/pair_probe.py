"""Independent original-slot/MLE reference versus paired affine derivation."""
from pathlib import Path
import hashlib,json,os,random,resource,struct,time
import reference as ref
import prior_fzc_model as prior
from affine import Ops,pair,prepare,Z,P
H=Path(__file__).resolve().parent
SEED=2026102097

def explicit_affine(a,p,supp):
    # Schoolbook quotient-field original clauses, separate from affine.py.
    a=[ref.R(*x) for x in a];mu=[ref.R(*x) for x in p['mu']]
    g=mu[0]*(-p['kh']*a[6]+p['kh']//2-a[9]-256*a[10])
    g+=mu[1]*(a[3]+32768-a[4]-256*a[5])
    g+=mu[2]*(a[6]+32768-a[7]-256*a[8])
    out=[g.v]
    if supp:out.append((ref.R(*p['mupad'])*sum((ref.R(*w)*x for w,x in zip(p['pad'],a)),ref.R())).v)
    return out

def enc(v):return b''.join(struct.pack('<QQ',*x) for x in v)

def main():
    start=time.perf_counter();cases=[];checks=0;rounds=0
    edge=[0,1,P-1,P-2,2**32-1,2**32,2**63]
    for i,x in enumerate((a,b) for a in edge for b in edge):
        y=(edge[(i+2)%len(edge)],edge[(i+4)%len(edge)])
        o=Ops();rr=ref.R(*x)*ref.R(*y)
        assert o.m(x,y)==o.generic_mul(x,y)==rr.v
        assert o.a(x,y)==(ref.R(*x)+ref.R(*y)).v
        assert o.s(x,y)==(ref.R(*x)-ref.R(*y)).v;checks+=3
    for n in [3,4,5]:
      for supp in [0,1]:
       for support_size in ([0] if not supp else [0,1,3,8,11]):
        for base in [False,True]:
         seed=SEED+10000*n+1000*supp+10*support_size+base
         rng=random.Random(seed);p=prior.params(rng,True)
         p['kh']=1<<rng.choice([9,12,16]);p['kg']=1<<rng.choice([1,4,8])
         positions=rng.sample(range(11),support_size)
         p['pad']=[p['pad'][j] if j in positions else Z for j in range(11)]
         if not support_size:p['mupad']=Z # active params() empty-pad rule
         orig=[[(rng.randrange(P),0 if base and (3<=t<=13 or t==20) else rng.randrange(P)) for _ in range(1<<n)] for t in range(20+supp)]
         tabs=[list(x) for x in orig]
         derived=[[explicit_affine([tb[i] for tb in orig[3:14]],p,supp)[j] for i in range(1<<n)] for j in range(1+supp)]
         prep=prepare(Ops(),p) if supp else None
         history=[];digest=b'affine-pair-synthetic-challenge-v1';hashes=[]
         for rno in range(n):
          half=len(tabs[0])//2;out=[Z]*6;o=Ops()
          for i in range(half):
           lo=[tb[i] for tb in tabs];hi=[tb[i+half] for tb in tabs]
           delta=[o.s(y,x) for x,y in zip(lo[3:14],hi[3:14])]
           got,_=pair(o,lo[3:14],delta,p,supp,'paired',prep)
           literal,_=pair(Ops(),lo[3:14],delta,p,supp,'literal')
           expected=[(tb[i],((tb[i+half][0]-tb[i][0])%P,(tb[i+half][1]-tb[i][1])%P)) for tb in derived]
           assert got==literal==expected;checks+=1
           assert [prior.add(v,dv) for v,dv in got]==[tb[i+half] for tb in derived];checks+=1
           for d in range(6):
            values=[prior.fold(x,y,(d,0)) for x,y in zip(lo,hi)]
            dv=[prior.add(v,prior.mul((d,0),dif)) for v,dif in got]
            out[d]=prior.add(out[d],prior.split_poly(values,p,supp,dv))
          rt=[ref.direct_prefix(tb,[ref.R(*r) for r in history]) for tb in orig]
          expected_poly=ref.round_values(rt,prior.refparams(p),supp,5)
          assert enc(out)==enc(expected_poly);checks+=1;rounds+=1
          digest=hashlib.sha256(digest+enc(out)).digest();hashes.append(digest.hex())
          r=(int.from_bytes(digest[:16],'little')%P,int.from_bytes(digest[16:],'little')%P)
          history.append(r)
          tabs=[[prior.fold(tb[i],tb[i+half],r) for i in range(half)] for tb in tabs]
          derived=[[prior.fold(tb[i],tb[i+half],r) for i in range(half)] for tb in derived]
         assert [tb[0] for tb in tabs]==[ref.direct_prefix(tb,[ref.R(*r) for r in history])[0].v for tb in orig];checks+=1
         cases.append(dict(n=n,entries=1<<n,support=supp,pad_nonzero=support_size,base_round0=base,seed=seed,round_hashes=hashes))
    # Deliberately incorrect candidates. Each must differ from original math.
    rng=random.Random(SEED);p=prior.params(rng,True);a=[(rng.randrange(P),rng.randrange(P)) for _ in range(11)];d=[(1+j,2+j) for j in range(11)]
    good,_=pair(Ops(),a,d,p,True,'paired',prepare(Ops(),p));controls=[]
    def reject(name,bad):
        assert bad!=good,name;controls.append(name)
    reject('unweighted_pad_coefficients',pair(Ops(),a,d,p,True,'paired',p['pad'])[0])
    q=dict(p);q['mupad']=prior.add(p['mupad'],(1,0))
    reject('prepared_coefficients_reused_after_new_mu_pad',pair(Ops(),a,d,p,True,'paired',prepare(Ops(),q))[0])
    bad=list(good);bad[0]=(good[0][0],explicit_affine(d,p,False)[0]);reject('affine_constant_added_to_difference',bad)
    bad=list(good);bad[0]=(good[0][0],Z);reject('missing_extension_delta',bad)
    bad=list(good);bad[1]=(Z,Z);reject('drop_nonzero_public_pad_support',bad)
    assert [v for v,dv in good]!=[prior.add(v,dv) for v,dv in good]
    controls.append('store_low_endpoint_in_high_half')
    # Extension multiplication is not two independent residue products.
    wrong=lambda a,b:(a[0]*b[0]%P,a[1]*b[1]%P)
    assert Ops().m((0,1),(0,1))==(ref.R(0,1)*ref.R(0,1)).v
    assert wrong((0,1),(0,1))!=(ref.R(0,1)*ref.R(0,1)).v;controls.append('componentwise_extension_multiply')
    result=dict(status='PASS_PYTHON_ALGEBRA_ONLY',fixtures=len(cases),rounds=rounds,checks=checks,negative_controls=len(controls),seed=SEED,wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Synthetic field tables; independent original-slot polynomial/direct-original-MLE; no CUDA/Rust, native masks/transcript/receipt or verifier',full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
    for name,data in [('pair-result.json',result),('cases.json',cases),('negative-controls.json',controls)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result))
if __name__=='__main__':main()
