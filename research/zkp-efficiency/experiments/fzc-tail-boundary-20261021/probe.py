"""Synthetic actual-FZC rounds and fold-pack differential, one worker."""
from pathlib import Path
import hashlib,json,random,resource,time
import tail as t
import reference as ref
import prior_fzc_model as fzc
H=Path(__file__).resolve().parent
SEED=202610210117
checks=0
def ck(v,msg=''):
    global checks
    checks+=1
    assert v,msg
def run_rounds(original,p,supp,threshold,candidate):
    n=(len(original[0])-1).bit_length();tabs=[list(tb) for tb in original]
    history=[];hashes=[];chain=b'fzc-tail-synthetic-challenge-v1';host=False
    for j in range(n):
        half=len(tabs[0])//2;sums=[t.Z]*6
        for i in range(half):
            for d in range(6):
                v=[t.fold(tb[i],tb[i+half],(d,0)) for tb in tabs]
                sums[d]=t.add(sums[d],fzc.split_poly(v,p,supp,fzc.derive(v,p,supp)))
        # Original table MLE and original unsplit polynomial, separate field implementation.
        rt=[ref.direct_prefix(tb,[ref.R(*r) for r in history]) for tb in original]
        expect=ref.round_values(rt,fzc.refparams(p),supp,5)
        ck(sums==expect,'original-slot round');ck(t.enc(sums)==t.enc(expect),'canonical bytes')
        # s(1) recovery must preserve the same round message.
        claim=t.add(expect[0],expect[1]);rec=list(sums);rec[1]=t.sub(claim,rec[0]);ck(rec==expect)
        chain=hashlib.sha256(chain+t.enc(sums)).digest();hashes.append(chain.hex())
        r=(int.from_bytes(chain[:16],'little')%t.P,int.from_bytes(chain[16:],'little')%t.P)
        history.append(r)
        to_host=threshold>0 and j+1<n and half>=2 and half<=1<<threshold
        if to_host and not host:
            stride=len(original[0]);flat=[]
            for tb in tabs:flat.extend(tb+[None]*(stride-len(tb)))
            packed=t.fold_pack(flat,len(tabs),stride,len(tabs[0]),r)
            expected=[(ref.R(*tb[i])+ref.R(*r)*(ref.R(*tb[i+half])-ref.R(*tb[i]))).v for tb in tabs for i in range(half)]
            ck(packed==expected,'independent boundary fold');ck(t.enc(packed)==t.enc(expected))
            if candidate:tabs=[packed[z*half:(z+1)*half] for z in range(len(tabs))]
            else:tabs=[[t.fold(tb[i],tb[i+half],r) for i in range(half)] for tb in tabs]
            host=True
        else:tabs=[[t.fold(tb[i],tb[i+half],r) for i in range(half)] for tb in tabs]
    finals=[tb[0] for tb in tabs]
    ck(finals==[ref.direct_prefix(tb,[ref.R(*r) for r in history])[0].v for tb in original],'original MLE terminals')
    return dict(hashes=hashes,final_sha256=hashlib.sha256(t.enc(finals)).hexdigest())

def main():
    start=time.monotonic();rng=random.Random(SEED);cases=[];negative=[];fixtures=[]
    # Actual FZC polynomial, original 20/21 tables and degree 5 (degree 4 is
    # included in the schedule census, independently of this overbound oracle).
    for n in (1,3,6):
      for supp in (False,True):
        p=fzc.params(rng,supp)
        if supp:
            zeta=(rng.randrange(1,t.P),rng.randrange(1,t.P));w=(1,0);p['pad']=[]
            for z in range(11):p['pad'].append(w);w=t.mul(w,zeta)
        original=[[(rng.randrange(t.P),rng.randrange(t.P)) for _ in range(1<<n)] for _ in range(20+supp)]
        if supp:original[20]=[(int(i<(1<<n)*3//4),0) for i in range(1<<n)]
        fixtures.append(dict(n=n,support=supp,params=p,original=original))
        baseline=run_rounds(original,p,supp,0,False)
        for threshold in (0,5,8,10):
          for candidate in (False,True):
            got=run_rounds(original,p,supp,threshold,candidate);ck(got==baseline,'threshold changes chain')
            cases.append(dict(n=n,support=supp,threshold=threshold,candidate=candidate,**got))
    # Large threshold edges need only test the local fold/pack operation,
    # not an expensive full polynomial or a native proof.
    boundary_cases=[]
    for k in (20,21):
      for length in (4,8,64,512,2048):
       for pad in (0,7):
        stride=length+pad
        flat=[(rng.randrange(t.P),rng.randrange(t.P)) for _ in range(k*stride)]
        for r in ((0,0),(1,0),(0,1),(t.P-1,t.P-1)):
         got=t.fold_pack(flat,k,stride,length,r);half=length//2
         expected=[((1-ref.R(*r))*ref.R(*flat[z*stride+i])+ref.R(*r)*ref.R(*flat[z*stride+i+half])).v for z in range(k) for i in range(half)]
         ck(got==expected,'boundary schoolbook oracle');ck(t.enc(got)==t.enc(expected))
         boundary_cases.append(dict(k=k,length=length,stride=stride,r=list(r),sha256=hashlib.sha256(t.enc(got)).hexdigest()))
    k=21;stride=19;length=16;r=(17,29)
    flat=[(rng.randrange(t.P),rng.randrange(t.P)) for _ in range(k*stride)]
    good=t.fold_pack(flat,k,stride,length,r)
    for bug in ('packed_input_stride','adjacent_pairing','drop_challenge_extension','omit_fold','swap_coordinates'):
        ck(t.fold_pack(flat,k,stride,length,r,bug)!=good,bug);negative.append(bug)
    for dims in ((0,16,8),(21,8,16),(21,16,3)):
        kk,ss,ll=dims
        try:t.fold_pack(flat,kk,ss,ll,r)
        except AssertionError:negative.append('reject_dimensions_'+str(dims));ck(True)
        else:raise AssertionError(dims)
    # Poison derived suffix: they are not inputs to the boundary consumer.
    ck(t.fold_pack(flat+[None]*(2*stride),k,stride,length,r)==good);negative.append('derived_suffix_unused')
    result=dict(status='PASS_SYNTHETIC_ONLY',seed=SEED,checks=checks,full_round_cases=len(cases),modeled_rounds=sum(x['n'] for x in cases),boundary_cases=len(boundary_cases),negative_controls=negative,wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='Authored Fp2/fold-pack/synthetic chain and actual FZC polynomial reference; no native masked transcript, device kernel, receipt or verifier')
    for name,data in [('result.json',result),('cases.json',cases),('boundary-cases.json',boundary_cases),('fixtures.json',fixtures)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result))
if __name__=='__main__':main()
