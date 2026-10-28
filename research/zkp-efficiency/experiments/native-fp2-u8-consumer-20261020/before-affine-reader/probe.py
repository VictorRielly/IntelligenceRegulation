from pathlib import Path
import hashlib,json,random,resource,subprocess,time
from fp2 import E,P,Attempt
from tiled_fp2 import execute,consumer
import reference as R

H=Path(__file__).resolve().parent;t0=time.monotonic();rng=random.Random(20261020108)
checks=cases=helper_entries=0;controls=[];lines=[];expected=[];fixtures=[]
def check(x):
    global checks
    assert x;checks+=1
def control(name,x):check(x);controls.append(name)
def rand():return E(rng.randrange(P),rng.randrange(P))
def flat(x):return '%d %d'%(x.a,x.b)
def pairs(v):return [tuple(x.pair()) for x in v]
def pack_result(result):
    rows,end,final,_=result
    return [[tuple(x.pair()) for x in row] for row in rows],tuple(end.pair()),tuple(tuple(x.pair()) for x in final)
def status(f):
    try:return f()
    except ValueError:return None

# Helpers are compared entry-by-entry to compiled pinned native arithmetic.
for rep in range(12):
    g=rand();a=rand() if rep<8 else g+E([0,17,255,-1][rep-8])
    attempt=Attempt(a,g)
    values=list(range(256))+[-(1<<63),-65537,-257,-1,256,257,65537,(1<<63)-1]
    want=[]
    for v in values:
        x=status(lambda:attempt.helper(v));want.append(x)
        # Native inverses later independently verify every cache-produced value.
        if x is not None:check(x*attempt.denominator(v)==1)
        helper_entries+=1
    lines.append('H '+flat(a)+' '+flat(g)+' '+' '.join(map(str,values)))
    expected.append(('H',want))
    lines.append('T '+flat(a)+' '+flat(g));expected.append(('T',attempt))

# Ordered byte leaves, plus one global histogram with all 256 table values.
for h in range(1,7):
    n=1<<h
    for rep in range(2):
        a,g=rand(),rand();attempt=Attempt(a,g)
        values=tuple(rng.randrange(256) for _ in range(n))
        hist=[values.count(v) for v in range(256)]
        check(sum(hist)==n)
        helpers=[attempt.helper(v) for v in values]
        table=attempt.table_helper(hist)
        check(sum(helpers,E())==sum(table,E()))
        leaves=tuple(attempt.leaf(v) for v in values)
        tab_leaves=tuple(attempt.leaf(v,-hist[v]) for v in range(256))
        lr=R.tree([(tuple(x.pair()),tuple(y.pair())) for x,y in leaves])[0][0]
        tr=R.tree([(tuple(x.pair()),tuple(y.pair())) for x,y in tab_leaves])[0][0]
        check(R.add(R.mul(lr[0],tr[1]),R.mul(tr[0],lr[1]))==(0,0))
        check(E(*lr[0])*E(*lr[1]).inv()==sum(helpers,E()))
        before=hashlib.sha256(repr((values,leaves)).encode()).hexdigest()
        for d in range(1,min(h,5)+1):
            k=d-1
            point=[E(0) if (j+rep)%3==0 else E(1) if (j+rep)%3==1 else rand() for j in range(k)]
            challenges=[E(1) if (j+rep)%3==0 else E(0) if (j+rep)%3==1 else rand() for j in range(k)]
            lam=rand()
            original=[(tuple(x.pair()),tuple(y.pair())) for x,y in leaves]
            ref=R.direct(R.tree(original)[d],pairs(point),pairs(challenges),tuple(lam.pair()))
            for q in range(min(k,4)+1):
                seen=[]
                def read(i):seen.append(i);return leaves[i]
                got=execute(read,n,d,point,challenges,q,lam,P)
                check(pack_result(got)==ref)
                check(seen==list(range(n))*(q+1))
                check(got[3]['scans']==q+1 and got[3]['leaves']==(q+1)*n)
                check(got[3]['internal']==(q+1)*(n-(1<<d)))
                if k:check(R.verify(R.add(*ref[0][0][:2]),*ref[:2],pairs(challenges)))
                check(hashlib.sha256(repr((values,leaves)).encode()).hexdigest()==before)
                check(pack_result(execute(read,n,d,point,challenges,q,lam,P,'direct'))==ref)
                cases+=1
            tokens=['L',str(n),str(d),flat(lam)]+[flat(x) for x in point+challenges]+[flat(z) for xy in leaves for z in xy]
            lines.append(' '.join(tokens));expected.append(('L',ref))
            fixtures.append({'n':n,'d':d,'point':pairs(point),'challenges':pairs(challenges),'lambda':lam.pair(),
                'values':values,'alpha':a.pair(),'g':g.pair(),'rows':ref[0],'terminal':ref[1],'final':ref[2]})

inp='\n'.join(lines)+'\n';(H/'native-input.txt').write_text(inp)
r=subprocess.run([str(H/'oracle')],input=inp,text=True,capture_output=True,timeout=20,check=True)
(H/'native-output.txt').write_text(r.stdout);(H/'native-stderr.txt').write_text(r.stderr)
outs=r.stdout.splitlines();check(len(outs)==len(expected))
native_layers=0
for line,(kind,want) in zip(outs,expected):
    tok=line.split();check(tok.pop(0)==kind)
    if kind=='H':
        for x in want:
            flag=tok.pop(0)
            if x is None:check(flag=='ERR')
            else:check(flag=='OK');check([int(tok.pop(0)),int(tok.pop(0))]==x.pair())
        check(not tok)
    elif kind=='T':
        good=all(x is not None for x in want.cache)
        check(tok.pop(0)==('OK' if good else 'ERR'))
        if good:
            vals=[int(x) for x in tok]
            check(vals==[c for x in want.cache for c in x.pair()])
    else:
        vals=[int(x) for x in tok]
        serialized=[c for row in want[0] for x in row for c in x]+list(want[1])+[c for x in want[2] for c in x]
        check(vals==serialized);native_layers+=1

# Decisive controls: preserve the FULL refusal domain and original leaf order.
g=E(19,23);a=g+17;at=Attempt(a,g);hist=[0]*256;hist[3]=8
control('absent_bad_table_value_helper_accepts',at.helper(3)*(a-g-3)==1)
control('absent_zero_multiplicity_table_refuses',status(lambda:at.table_helper(hist)) is None)
control('zero_denominator_zero_numerator_leaf_refuses',status(lambda:at.leaf(17,0)) is None)
control('present_zero_denominator_helper_refuses',status(lambda:at.helper(17)) is None)
control('out_of_range_zero_denominator_refuses',status(lambda:Attempt(g-1,g).helper(-1)) is None)
control('out_of_range_nonzero_fallback_exact',Attempt(a,g).helper(256)*(a-g-256)==1)
fresh=Attempt(a+1,g)
control('stale_cache_across_challenges_is_wrong',at.helper(3)!=fresh.helper(3) and at.helper(3)*(a+1-g-3)!=1)
wrong_u=E(0,1)
control('extension_nonresidue_is_not_minus_one',wrong_u*wrong_u==7 and wrong_u*wrong_u!=-1)

n=32;d=5;values=tuple(range(n));at=Attempt(E(1001,37),E(5,3));leaves=tuple(at.leaf(v) for v in values)
point=[E(2,3),E(5,7),E(11,13),E(17,19)];ch=[E(23,29),E(31,37),E(41,43),E(47,53)];lam=E(59,61)
got=execute(leaves.__getitem__,n,d,point,ch,2,lam,P);good=pack_result(got)
bad=list(leaves);bad[0],bad[2]=bad[2],bad[0]
root=lambda v:R.tree([(tuple(x.pair()),tuple(y.pair())) for x,y in v])[0]
control('wrong_site_swap_preserves_fraction_root',root(bad)==root(leaves))
control('original_order_MLE_detects_swap',pack_result(execute(bad.__getitem__,n,d,point,ch,2,lam,P))!=good)
control('bit_order_matters',pack_result(execute(leaves.__getitem__,n,d,point[::-1],ch,2,lam,P))!=good)
rows=[r[:] for r in good[0]];rows[1][2]=R.add(rows[1][2],(1,0));claim=R.add(*good[0][0][:2])
control('altered_sample_fails',not R.verify(claim,rows,good[1],pairs(ch)))
control('altered_terminal_fails',not R.verify(claim,good[0],R.add(good[1],(0,1)),pairs(ch)))
genc=consumer(lambda:iter(leaves),16,point,2,lam,P,dict(fold_scalar_updates=0,stream_eq_products=0))
next(genc)
control('missing_challenge_refuses',status(lambda:genc.send(None)) is None)
seen=0
def drift(i):
    global seen
    scan=seen//n;seen+=1;x,y=leaves[i]
    return (x+1,y) if scan and i==0 else (x,y)
control('source_drift_detected_by_original_MLE',pack_result(execute(drift,n,d,point,ch,2,lam,P))!=good)
# A fractional root can hide denominator-zero defects without explicit checks.
control('degenerate_zero_over_zero_would_be_ambiguous',R.mix(((0,0),(0,0)),((1,0),(2,0)))==((0,0),(0,0)))

(H/'fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
result={'status':'PASS','seed':20261020108,'checks':checks,'tiled_consumers':cases,'native_helper_entries':helper_entries,
 'native_layer_cases':native_layers,'negative_controls':controls,'elapsed_s':time.monotonic()-t0,
 'maxrss_KiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 'native_child_maxrss_KiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
 'new_denominator_cache_payload_B':256*16,'scope':'Exact native Goldilocks Fp2 arithmetic/helper extraction, unmasked prospective tiled consumer; no native proof/private transcript.',
 'full_stack':{'proofs':0,'passes':0,'positions':0,'context_length':None,'device':None,'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,'startup_s':None,'startup_fraction':None,'steady_rate':None,'total_rate':None}}
(H/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
