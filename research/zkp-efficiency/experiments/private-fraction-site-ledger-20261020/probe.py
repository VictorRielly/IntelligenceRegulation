"""Bounded native-field algebra and semantic ledger; no proof creation."""
from pathlib import Path
import copy,json,random,resource,time
from fp2 import E,P,Attempt,OrderedLookup
from tiled_fp2 import execute
from reference import tree,direct,verify,mle
from ledger import columns,obligations,validate_ledger,summary,native_child_point,native_merged_point
import hashlib

HERE=Path(__file__).resolve().parent
SEED=20261020109
rng=random.Random(SEED);t0=time.monotonic();checks=0;controls=[];saved=[]
def check(x):
    global checks
    checks+=1
    if not x: raise AssertionError(checks)
def pair(x):return tuple(x.pair())
def ext(x):return E(*x)
def msb_eval(values,point):
    # Direct MSB basis. Independent audit uses a half-fold recurrence instead.
    return ext(mle([pair(x) for x in values],[pair(x) for x in reversed(point)]))
def challenge(i):return E(i%2) if i%4<2 else E(rng.randrange(P),rng.randrange(1,P))

fixtures=json.loads((HERE/'inputs.json').read_text())
summaries=[]
def swap_first_sites(z):
    z[:4],z[4:8]=z[4:8],z[:4]
for f in fixtures:
    cols=columns(f);o=obligations(f);validate_ledger(o,f);s=summary(f);summaries.append(s)
    check(len(cols)-1==(85 if f['T']==512 else 83))
    check(s['unmerged_original_A_leaf_obligations']==2*len(cols))
    # Same count and unique IDs can still bind a wrong original expression.
    for name,mutate in [
        ('swap_original_site',swap_first_sites),
        ('wrong_branch',lambda z:z[0].__setitem__('branch',1)),
        ('wrong_component',lambda z:z[0].__setitem__('component','D')),
        ('wrong_domain',lambda z:z[0].__setitem__('domain','Q')),
        ('wrong_original_expression',lambda z:z[0].__setitem__('expression_hash','0'*64)),
        ('wrong_point_axis',lambda z:z[0].__setitem__('point_rule','branch || reverse(data_rho_lsb)')),
        ('invent_existing_mask',lambda z:z[0].__setitem__('reserved_mask_pair',[0,1]))]:
        bad=copy.deepcopy(o);mutate(bad);check(len(bad)==len(o))
        try:validate_ledger(bad,f)
        except ValueError:controls.append(name)
        else:raise AssertionError(name)
    if f['model']=='8B' and f['T'] in (128,512):
        (HERE/('ledger-8B-T%d-%s.json'%(f['T'],'DD' if f['dd'] else 'nonDD'))).write_text(json.dumps(o,indent=1)+'\n')

consumer_cases=0;mapping_cases=0
for h in range(1,7):
    for rep in range(5):
        n=1<<h;attempt=Attempt(E(991,13),E(71,9))
        planes=[[rng.randrange(128) for _ in range(n)]]
        source=OrderedLookup(attempt,planes,[(0,1)])
        leaves=[source.read(i) for i in range(n)]
        tr=tree([(pair(a),pair(b)) for a,b in leaves]);point=[]
        previous=tuple(ext(x) for x in tr[0][0])
        for depth in range(1,h+1):
            k=depth-1;rho=[challenge(i+rep) for i in range(k)]
            lam=challenge(rep+6);q=min(k,rep%3)
            rows,terminal,finals,stats=execute(source.read,n,depth,point,rho,q,lam,P)
            child=tr[depth]
            ref_rows,ref_terminal,ref_finals=direct(child,[pair(x) for x in point],[pair(x) for x in rho],pair(lam))
            check([[pair(x) for x in row] for row in rows]==ref_rows)
            check(pair(terminal)==ref_terminal and tuple(pair(x) for x in finals)==ref_finals)
            initial=previous[0]+lam*previous[1]
            check(verify(pair(initial),ref_rows,ref_terminal,[pair(x) for x in rho]))
            for b in (0,1):
                pt=native_child_point(rho,b)
                for c in (0,1):
                    values=[ext(x[c]) for x in child]
                    check(msb_eval(values,pt)==finals[2*b+c]);mapping_cases+=1
            eta=challenge(rep+depth+8);native=native_merged_point(rho,eta)
            previous=((1-eta)*finals[0]+eta*finals[2],(1-eta)*finals[1]+eta*finals[3])
            for c in (0,1):check(msb_eval([ext(x[c]) for x in child],native)==previous[c])
            # Next parent point is LSB eta then the previous rho, not reversed eta.
            point=[eta]+rho
            consumer_cases+=1
            if rep==4:saved.append({'depth':depth,'rho_lsb':[x.pair() for x in rho],
                'eta':eta.pair(),'child':child,'finals':[x.pair() for x in finals],
                'merged':[x.pair() for x in previous]})

# Decisive asymmetric orientation controls (random coincidences avoided).
vals=[E(i*i+3*i+7,i+1) for i in range(8)];rho=[E(3,5),E(9,2)];eta=E(11,4)
good=msb_eval(vals,native_merged_point(rho,eta))
check(good!=msb_eval(vals,[eta]+list(reversed(rho))));controls.append('branch_must_be_last_native_axis')
check(good!=msb_eval(vals,rho+[eta]));controls.append('data_axes_must_reverse')
# A root does not establish source identity or order.
src=[(E(1),E(i+19,3)) for i in range(8)]
root=tree([(pair(a),pair(b)) for a,b in src])[0][0]
perm=src[1:2]+src[:1]+src[2:]
check(tree([(pair(a),pair(b)) for a,b in perm])[0][0]==root)
check(msb_eval([b for a,b in src],native_merged_point(rho,eta))!=msb_eval([b for a,b in perm],native_merged_point(rho,eta)))
controls.append('root_preserving_wrong_order_requires_original_A_link')

# Every symbolic native original-A lookup expression is linked at a random
# point of a tiny 8-entry original plane, not just checked by column count.
# Inputs are synthetic 0/1 words, so all emitted byte expressions stay in U8.
original_links=[]
for f in fixtures:
    for col in columns(f)[:-1]:
        expr=col['expression'];vectors={}
        for name,coef in expr['terms']:
            vectors[name]=[E(hashlib.sha256((name+':'+str(j)).encode()).digest()[0]&1) for j in range(8)]
        values=[expr['cst']+sum(coef*vectors[name][j].a for name,coef in expr['terms']) for j in range(8)]
        check(all(0<=v<256 for v in values))
        pt=[E(2,3),E(5,7),E(11,13)];alpha,g=E(991,13),E(71,9)
        denominator=msb_eval([alpha-g-E(v) for v in values],pt)
        original=alpha-g-E(expr['cst'])
        for name,coef in expr['terms']:original-=coef*msb_eval(vectors[name],pt)
        check(denominator==original)
        original_links.append({'model':f['model'],'T':f['T'],'dd':f['dd'],
            'domain':col['domain'],'ordinal':col['ordinal'],'expression_hash':col['expression_hash'],
            'planes':{k:[x.pair() for x in v] for k,v in vectors.items()},
            'point_msb':[x.pair() for x in pt],'alpha':alpha.pair(),'g':g.pair(),
            'denominator':denominator.pair()})

# P3 native table lift: first 256 multiplicities, then zero pad. Masks are
# separate private axes and are not included or reversed by this data adapter.
lift_cases=0
hist=[E(rng.randrange(4)) for _ in range(256)]
low=[challenge(i+2) for i in range(8)]
for high_count in (1,3,5,6):
    high=[E(i+2,i+1) for i in range(high_count)]
    value=msb_eval(hist+[E()] * ((1<<(8+high_count))-256),high+low)
    factor=E(1)
    for z in high:factor*=1-z
    check(value==factor*msb_eval(hist,low));lift_cases+=1
    check(value!=msb_eval(hist,low));controls.append('table_zero_lift_factor_required')

(HERE/'fixtures.json').write_text(json.dumps(saved)+'\n')
(HERE/'original-links.json').write_text(json.dumps(original_links)+'\n')
(HERE/'site-summary.json').write_text(json.dumps(summaries,indent=2)+'\n')
result={'status':'PASS','seed':SEED,'checks':checks,'profile_fixtures':len(fixtures),
    'consumer_cases':consumer_cases,'branch_component_mapping_cases':mapping_cases,
    'table_lift_cases':lift_cases,'negative_controls':controls,
    'tiny_original_A_expression_links':len(original_links),
    'elapsed_s':time.monotonic()-t0,'maxrss_KiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    'scope':'Native-field unmasked recursive arithmetic, semantic obligations and conditional row-payload subcost; not a native private claim/mask/PCS schedule.',
    'full_stack':{'proofs':0,'passes':0,'positions':0,'context_length':None,'device':None,
        'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,
        'startup_s':None,'startup_fraction':None,'steady_rate':None,'total_rate':None}}
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
