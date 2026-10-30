"""Source-derived DD calibration boundary differential; synthetic only."""
from pathlib import Path
from collections import Counter
import json,random,itertools,time,hashlib,platform,os
from field_support import F,P,lagrange,fold
from candidate import Rounds
import dd_projection as dd
import oracle as o
E=Path(__file__).resolve().parent;SEED=20261030169

def generic_round(tables,ir,claim=None,debug=False):
    m=len(tables[0])//2;out=[F() for _ in range(5)]
    for i in range(m):
        cur=[t[i] for t in tables];dif=[t[i+m]-t[i] for t in tables]
        for t in range(5):
            if t!=1 or claim is None or debug:
                out[t]+=F(*o.poly(list(enumerate(ir)),list(map(o.tup,cur))))
            if t!=4:cur=[a+b for a,b in zip(cur,dif)]
    if claim is not None:
        recovered=claim-out[0]
        if debug:assert out[1]==recovered
        out[1]=recovered
    return out

def source_facts():
    a=(E/'native/argument.rs').read_text();s=(E/'native/shape.rs').read_text();l=(E/'native/layout.rs').read_text()
    branch=a.split('SC_SZC if sh.dd_cap > 0 => {')[1].split('\n        SC_SZC => {')[0]
    assert 'b.finish(Box::new(poly), hosted)' in branch and 'def.groups' not in branch
    assert '1i64 << sh.sh_s' in branch and 'half(sh.sh_s)' in branch
    assert 'let lht = sh.log(Dom::Ht);' in branch and 'b.eq(&pts.p_ht, 0);' in branch
    assert 'ONE_LIMB_SHIFT: std::ops::RangeInclusive<u32> = 1..=8;' in s
    assert 'let one = |sh: u32| -> i64 { 1i64 << (8 - sh) };' in l
    assert 'v.extend([byte(ids.at(A_RSL)), scaled(ids.at(A_RSL), one(sh.sh_s))]);' in l
    assert 'if sh.dd_cap == 0' in l.split('Dom::S => {')[-1].split('Dom::Dd')[0]
    assert 'Dom::S if self.dd_cap > 0 => 2 + 2' in s
    assert 'DD_PROFILES: [&str; 5]' in s
    assert 'self.h_pad != self.q_heads || self.t_pad != self.tokens' in s
    assert 'self.natural_log(dom) < self.log_cols || self.size(dom) != self.true_size(dom)' in s
    return dict(checked_literal_facts=11,dd_branch_sha256=hashlib.sha256(branch.encode()).hexdigest(),shifts=list(range(1,9)),range_coefficients=[2**(8-x) for x in range(1,9)],lookups=4,helpers=2,bracket_degrees=[3,1,1],slot_degree=4,native_refusal_execution=False)

def main():
    start=time.monotonic();rng=random.Random(SEED);checks=Counter();fixtures=[];controls=[];costs=[]
    facts=source_facts()
    for shift,n in itertools.product(range(1,9),range(4)):
      for span in range(n+1):
       for mode in ('full','boolean'):
        def draw():
            return F(rng.randrange(2)) if mode=='boolean' else F(rng.randrange(P),rng.randrange(P))
        cfg=dd.config(shift)
        const={name:draw() for name in ['alpha','beta','gexp','gdd','gu8','lam','nu0','nu1']+['mu'+str(i) for i in range(6)]}
        for name in ['nu0','nu1']:
            if const[name]==0:const[name]=F(1)
        points=[[draw() for _ in range(n)],[draw() for _ in range(span)],[draw() for _ in range(n)]]
        tables=[[F(*o.eq(list(map(o.tup,p)),[(b,0) for b in o.bits(i,n)[:len(p)]])) for i in range(1<<n)] for p in points]
        # MX and Sum are genuine row slices: independent of trailing axes.
        for name in cfg['names'][3:]:
            if name in ('mx','sum'):
                row=[draw() for _ in range(1<<span)];tables.append([row[i>>(n-span)] for i in range(1<<n)])
            else:tables.append([draw() for _ in range(1<<n)])
        ir=dd.expanded(cfg,const)
        assert [max(map(lambda t:len(t[1]),g),default=0) for g in ir]==[3,1,1] or mode=='boolean'
        original=[list(map(o.tup,t)) for t in tables]
        for _ in range(2):
            v=[draw() for _ in tables]
            for g in range(3):
                assert o.tup(dd.bracket(g,v,cfg,const)[0])==o.bracket(ir[g],list(map(o.tup,v)))
                checks['independent_clause_values']+=1
        ev=Rounds(tables,points,cfg,const,bracket_eval=dd.bracket)
        dbg=Rounds(tables,points,cfg,const,debug=True,bracket_eval=dd.bracket)
        generic=[list(t) for t in tables];claim=None;prefix=[];rounds=[];rs=[]
        for j in range(n):
            expected=[o.round_direct(original,list(enumerate(ir)),prefix,t,n) for t in range(5)]
            for got in [generic_round(generic,ir,claim),generic_round(generic,ir,claim,True),ev.round(j),dbg.round(j)]:
                assert list(map(o.tup,got))==expected,(shift,n,span,mode,j)
                checks['round_values']+=5
            # Boolean coordinates force exact-zero factors, exercising fallback.
            r=draw();rs.append(o.tup(r));rounds.append([o.tup(x) for x in got]);claim=lagrange(got,r)
            generic=[fold(t,r) for t in generic];ev.fold(r);dbg.fold(r);prefix.append(o.tup(r))
            assert generic==ev.tables==dbg.tables
            checks['folded_table_values']+=len(tables)*(1<<(n-j-1))
        finals=[o.mle(t,prefix) for t in original]
        assert list(map(o.tup,ev.finals()))==list(map(o.tup,dbg.finals()))==finals
        checks['ordered_final_values']+=2*len(finals);checks.update(ev.counts)
        fixtures.append(dict(shift=shift,n=n,span=span,mode=mode,constants={k:o.tup(v) for k,v in const.items()},points=[[o.tup(x) for x in p] for p in points],tables=original,challenges=rs,rounds=rounds,finals=finals))
        checks['fixtures']+=1
    # Off-cube negative controls with independent expanded expected equations.
    for shift in range(1,9):
        cfg=dd.config(shift);const={name:F(rng.randrange(1,P),rng.randrange(1,P)) for name in ['alpha','beta','gexp','gdd','gu8','lam','nu0','nu1']+['mu'+str(i) for i in range(6)]}
        v=[F(rng.randrange(1,P),rng.randrange(1,P)) for _ in cfg['names']]
        for mutation,g in [('drop_key',0),('drop_mask_in_tuple',0),('drop_range_helper',0)]+([] if shift==6 else [('stale_range_scale',0),('stale_host_scale',2),('stale_half',2)]):
            expected=o.bracket(dd.expanded(cfg,const)[g],list(map(o.tup,v)))
            got=o.tup(dd.bracket(g,v,cfg,const,mutation)[0]);assert got!=expected,(shift,mutation)
            controls.append(dict(shift=shift,mutation=mutation,expected=expected,mutated=got))
        # Degree2 bracket would silently corrupt cubic helper/tuple terms.
        curve=[]
        dif=[F(rng.randrange(1,P),rng.randrange(1,P)) for _ in v]
        for t in range(4):curve.append(dd.bracket(0,[x+t*d for x,d in zip(v,dif)],cfg,const)[0])
        assert lagrange(curve[:3],F(3))!=curve[3]
        controls.append(dict(shift=shift,mutation='bracket_degree2',expected=o.tup(curve[3]),mutated=o.tup(lagrange(curve[:3],F(3)))))
        pc=[dict(dd.bracket(g,v,cfg,const)[1]) for g in range(3)]
        costs.append(dict(shift=shift,per_bracket_api_counts=pc,not_runtime=True))
    # Isolated row host shows extending short Eq to full changes the polynomial.
    good=o.eq([(2,3)],[(4,5)]);bad=o.eq([(2,3),(6,7)],[(4,5),(8,9)])
    assert good!=bad;controls.append(dict(mutation='extend_short_Ht_equality',expected=good,mutated=bad))
    assert checks['zero_factor_fallbacks']>0 and checks['recovered_groups']>0
    result=dict(status='PASS',seed=SEED,checks=dict(checks),negative_controls=len(controls),wall_s=time.monotonic()-start,source_facts=facts,proofs=0,proved_positions=0,native_execution=False,scope='160 synthetic n0..3 fixtures; shifts1..8, all Ht spans0..n, full Fp2/Boolean. No native proof,privacy or runtime gain.')
    for name,obj in [('result',result),('fixtures',fixtures),('negative-controls',controls),('costs',costs),('source-facts',facts)]:
        (E/(name+'.json')).write_text(json.dumps(obj,separators=(',',':'))+'\n')
    model=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown')
    (E/'hardware.json').write_text(json.dumps(dict(cpu=model,python=platform.python_version(),affinity=sorted(os.sched_getaffinity(0)),gpu='not used',threads=1),indent=2)+'\n')
    print(json.dumps(result))
if __name__=='__main__':main()
