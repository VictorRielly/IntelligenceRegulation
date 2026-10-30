"""Current R14 accuracy-DD algebra only; no native proof or model data."""
from pathlib import Path
from collections import Counter
import hashlib,json,random,time,os,platform
import engine as s
import reference as r

E=Path(__file__).resolve().parent
SEED=20261030171
NAMES=['eq_tau','eq_ht','eq_s','mask','score','rs0','rs1','rs2','zsel','e','p','mx','sum','h0','h1','h2','hx','ht']

class Generic:
    def __init__(self,f):
        self.tables=[[s.F(*x) for x in t] for t in f['tables']]
        self.c={k:s.F(*v) for k,v in f['constants'].items()};self.shift=f['shift']
        self.claim=None;self.pending=None
    def round(self,j):
        out=[s.Z]*5;m=len(self.tables[0])//2
        with s.phase('scan'):
            for i in range(m):
                cur=[t[i] for t in self.tables];dif=[t[i+m].sub(t[i]) for t in self.tables]
                for t in range(5):
                    if t!=1 or self.claim is None:out[t]=out[t].add(s.poly(cur,self.c,self.shift))
                    if t!=4:cur=[x.add(d) for x,d in zip(cur,dif)]
        with s.phase('completion'):
            if self.claim is not None:out[1]=self.claim.sub(out[0])
        self.pending=out
        return out
    def fold(self,j,ch):
        with s.phase('claim'):self.claim=s.interpolate(self.pending,ch)
        with s.phase('fold'):
            m=len(self.tables[0])//2
            self.tables=[[a.add(ch.mul(b.sub(a))) for a,b in zip(t[:m],t[m:])] for t in self.tables]
        self.pending=None

def fixture(rng,n,span,shift,mode):
    rand=lambda:s.F(rng.randrange(s.P),rng.randrange(s.P) if mode!='base' else 0)
    points=[[rand() for _ in range(l)] for l in [n,span,n]]
    challenges=[rand() for _ in range(n)]
    if mode=='one_factor_zero':
        for point in points:
            if len(point)>1:point[1]=s.Z
    if mode=='prefix_zero':
        for point in points:
            if point:point[0]=s.O
        challenges[0]=s.Z
    if mode=='half':
        for point in points:
            for j in range(len(point)):point[j]=s.F(pow(2,-1,s.P))
    if mode=='late_zero':
        for point in points:
            if len(point)>1:point[-1]=s.Z
    constants={k:rand() for k in ['alpha','beta','gexp','gdd','gu8','lam','nu0','nu1']+[f'mu{i}' for i in range(7)]}
    constants['beta2']=s.F(*r.mul(tuple(constants['beta'].pair()),tuple(constants['beta'].pair())))
    tables=[[rand() for _ in range(1<<n)] for _ in NAMES]
    # Original Eq tables with a shorter leading-coordinate row equality.
    for g,point in enumerate(points):
        tables[g]=[s.F(*r.eq([tuple(w.pair()) for w in point],[(b,0) for b in r.bits(i,n)[:len(point)]])) for i in range(1<<n)]
    # Source's public causal mask (toy head multiplicity on an even score cube).
    lt=n//2
    tables[3]=[s.F(int(((i>>lt)&((1<<lt)-1))>=(i&((1<<lt)-1)))) for i in range(1<<n)]
    for q in [11,12]:
        base=[rand() for _ in range(1<<span)]
        tables[q]=[base[i>>(n-span)] for i in range(1<<n)]
    return dict(n=n,span=span,shift=shift,mode=mode,points=[[x.pair() for x in p] for p in points],
                tables=[[x.pair() for x in t] for t in tables],constants={k:v.pair() for k,v in constants.items()},
                challenges=[x.pair() for x in challenges])

def bracket_ops():
    c={k:s.F(13,17) for k in ['alpha','beta','beta2','gexp','gdd','gu8','lam','nu0','nu1']+[f'mu{i}' for i in range(7)]}
    out=[]
    for g in range(3):
        s.COUNTS.clear()
        with s.phase('scan'):s.bracket(g,[s.F(19,23)]*18,c,18)
        out.append(Counter({k.split(':')[1]:v for k,v in s.COUNTS.items()}))
    return out

def counts(n,span,recovery,ops):
    old,new=Counter(),Counter()
    for j in range(n):
        m=1<<(n-j-1);samples=5-int(j>0)
        for cc,steps in [(old,4),(new,3)]:
            cc['sub']+=2*m*18;cc['mul']+=m*18;cc['add']+=(steps+1)*m*18
        for g,d in enumerate([3,1,1]):
            k=d+1-int(recovery[j][g])
            for op,v in ops[g].items():old[op]+=m*samples*v;new[op]+=m*k*v
            new['mul']+=m*(1+k);new['add']+=m*k
        old['mul']+=3*m*samples;old['add']+=3*m*samples
        old.update(s.interpolation_counts(5))
        if j>0:old['sub']+=1
    scalar,_=s.scalar_counts(n,span,recovery);new.update(scalar)
    return old,new

def main():
    start=time.monotonic();rng=random.Random(SEED);checks=Counter();saved=[];controls=[]
    ops=bracket_ops()
    # 4 reachable precision shifts, two tiny cube shapes, all six edge modes.
    for shift in range(17,21):
        for n,span in [(3,1),(4,2)]:
            for mode in ['extension','base','one_factor_zero','prefix_zero','half','late_zero']:
                f=fixture(rng,n,span,shift,mode);poly=r.polynomial(f['constants'],shift)
                assert max(map(len,poly.terms))==4
                assert [max(map(len,b.terms)) for b in r.brackets(f['constants'],shift)]==[3,1,1]
                checks['degree_checks']+=4
                all_rounds=[];prefix=[]
                for j,ch in enumerate(f['challenges']):
                    all_rounds.append([list(r.direct_round(f['tables'],poly,prefix,t,n)) for t in range(5)])
                    prefix.append(tuple(ch))
                finals=[list(r.mle(tb,prefix)) for tb in f['tables']]
                for arm in ['generic','grouped']:
                    s.COUNTS.clear();ev=Generic(f) if arm=='generic' else s.Grouped(f,'individual')
                    for j,ch in enumerate(f['challenges']):
                        got=[v.pair() for v in ev.round(j)]
                        assert got==all_rounds[j],(shift,n,mode,arm,j)
                        checks[arm+'_round_values']+=5
                        ev.fold(j,s.F(*ch))
                    got_final=[t[0].pair() for t in ev.tables]
                    assert got_final==finals;checks[arm+'_final_values']+=18
                    recovery=[[False]*3 if j==0 else [True]*3 for j in range(n)] if arm=='generic' else [x['recover'] for x in ev.round_records]
                    formulas=counts(n,span,recovery,ops)
                    actual=Counter({op:sum(v for key,v in s.COUNTS.items() if key.split(':')[1]==op) for op in {k.split(':')[1] for k in s.COUNTS}})
                    expected=formulas[0 if arm=='generic' else 1]
                    assert actual==expected,(arm,mode,actual-expected,expected-actual)
                    checks['literal_count_matches']+=1
                    if arm=='grouped':f['recovery']=recovery
                f.update(rounds=all_rounds,finals=finals);saved.append(f)
    # Pointwise negative controls are reexecuted in independent audit.
    witness=saved[0]
    for mutation in ['drop_high_limb','drop_middle_limb','legacy_shift','drop_helper2','swap_lookup','wrong_top_range','drop_tuple_key','drop_tuple_mask','swap_eq']:
        correct=r.polynomial(witness['constants'],witness['shift'])
        mutant=r.polynomial(witness['constants'],witness['shift'],mutation)
        for row in range(1<<witness['n']):
            vector=[tuple(tb[row]) for tb in witness['tables']]
            truth,bad=correct.at(vector),mutant.at(vector)
            if truth!=bad:break
        else:raise AssertionError(mutation)
        controls.append(dict(mutation=mutation,row=row,truth=truth,mutated=bad));checks['negative_controls']+=1
    # Explicit source-index and ordered-final controls.
    wrong=list(saved[0]['finals']);wrong[6],wrong[7]=wrong[7],wrong[6]
    assert wrong!=saved[0]['finals'];checks['negative_controls']+=1
    controls.append(dict(mutation='swap_ordered_rs_finals',truth=saved[0]['finals'],mutated=wrong))
    census=[]
    for n,span,label in [(3,1,'synthetic'),(4,2,'synthetic'),(7,4,'synthetic'),(19,12,'public-T128-32head-dimension'),(21,13,'dimension-only-T256'),(23,14,'dimension-only-T512')]:
        for fallback in [False,True]:
            rec=[[not fallback and j>0]*3 for j in range(n)]
            before,after=counts(n,span,rec,ops);b=s.base_product_count(before);a=s.base_product_count(after)
            census.append(dict(n=n,span=span,label=label,zero_fallback=fallback,tables=18,before_api=dict(before),after_api=dict(after),
                expanded_base_products_before=b,expanded_base_products_after=a,removed=b-a,removed_fraction=(b-a)/b,
                scalar_counts=dict(s.scalar_counts(n,span,rec)[0]),not_timing=True))
    (E/'fixtures.json').write_text(json.dumps(saved,separators=(',',':'))+'\n')
    (E/'negative-controls.json').write_text(json.dumps(controls,indent=2)+'\n')
    (E/'cost-census.json').write_text(json.dumps(dict(bracket_ops=[dict(x) for x in ops],rows=census),indent=2)+'\n')
    hardware=dict(cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),python=platform.python_version(),affinity=list(os.sched_getaffinity(0)),threads=1,gpu='not used')
    (E/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
    result=dict(status='PASS',seed=SEED,fixtures=len(saved),checks=dict(checks),wall_s=time.monotonic()-start,native_execution=False,proofs=0,proved_positions=0,
        scope='Current unpadded R14 LOW/LOW+h24 DD18-table polynomial algebra. Small synthetic cubes, no native cryptographic or privacy verification.')
    (E/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
