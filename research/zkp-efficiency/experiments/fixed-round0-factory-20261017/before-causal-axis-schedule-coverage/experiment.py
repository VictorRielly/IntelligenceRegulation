"""Bounded independent cube checks, actual operation counters, liveness audit."""
import ast,datetime,hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from fixtures import constants
from prior_optional_experiment import fixture
from prepared import Plan,generalize
from axis_factory import measured_dependencies
from cubic_factory import CubicPlan,CubicTerms,CubicRounds
from fixed_factory import FixedPlan,compile_factory
from generate import build,emit,write_artifacts
from polynomial_ir import expanded
import prior_experiment as prior
import oracle as o

HERE=Path(__file__).resolve().parent
SEED=2026101755


class CountF:
    """Separate execution counter, not the generator's symbolic op counter."""
    counts=Counter()
    def __init__(self,a=0,b=0):
        self.value=a if isinstance(a,F) else F(a,b)
    def __add__(self,y):
        type(self).counts['add']+=1
        return CountF(self.value+y.value)
    def __sub__(self,y):
        type(self).counts['sub']+=1
        return CountF(self.value-y.value)
    def __mul__(self,y):
        type(self).counts['mul' if isinstance(y,CountF) else 'mul_base']+=1
        return CountF(self.value*(y.value if isinstance(y,CountF) else y))


def make(cfg,con,ir,tabs,n,chunk,debug,kind,mutation=None):
    deps={cfg['index']['mask']:measured_dependencies(tabs[cfg['index']['mask']]['words'],n)}
    plan=Plan(generalize(cfg),con['alpha'],con['gu8'])
    if kind in ('fixed_ssa','fixed_recycled'):
        rp=FixedPlan(cfg,con,plan,deps,recycled=kind=='fixed_recycled',fixed_mutation=mutation)
    else:
        rp=CubicPlan(cfg,con,plan,deps,mode=kind)
    groups=[(g,CubicTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    rr=CubicRounds(tabs,n,4,groups,rp,chunk,debug)
    return rr,rp


def main():
    started=time.perf_counter()
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);counts=Counter();controls=[];digest=hashlib.sha256()
    kinds=('literal','prepared_scalar','cubic_round0','fixed_ssa','fixed_recycled')
    stats=[];recoveries=fallbacks=0
    cases=[fixture(n,ls,(False,False),mode,rng,lookup_count=lc)
           for n,ls,mode,lc in itertools.product((0,1,2,3,4),(2,3),('full','zero','boolean'),(7,8,None))]
    for cfg,con,ir,tabs,rs in cases:
        n=len(rs);orig=[o.table(t,n) for t in tabs];prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(orig,list(enumerate(ir)),prefix,t,n) for t in range(5)])
            prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in orig]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            engines={m:make(cfg,con,ir,tabs,n,chunk,debug,m) for m in kinds}
            for j,r in enumerate(rs):
                pending=None
                for kind,(rr,rp) in engines.items():
                    got=rr.round(j)
                    assert list(map(o.tup,got))==want[j],(kind,j)
                    pp=[list(map(o.tup,x)) for x in rr.pending]
                    if pending is None:pending=pp
                    else:assert pp==pending
                    counts['independent_round_samples']+=5
                    for x in got:digest.update(x.wire())
                    rr.fold(r)
            ref=engines['literal'][0]
            for kind,(rr,rp) in engines.items():
                assert list(map(o.tup,rr.finals()))==finals
                assert rr.claims==ref.claims and rr.data_fold_ops==ref.data_fold_ops and rr.eq_scalar_ops==ref.eq_scalar_ops
                assert (rr.recoveries,rr.zero_fallbacks)==(ref.recoveries,ref.zero_fallbacks)
                counts['independent_final_values']+=len(finals);counts['full_schedules']+=1
            # Fixed generation changes no field calls vs the prior dynamic K.
            dyn=prior.costs(*engines['cubic_round0'])['all_field_ops']
            for k in ('fixed_ssa','fixed_recycled'):
                assert prior.costs(*engines[k])['all_field_ops']==dyn
                counts['schedule_field_counter_parity']+=1
            recoveries+=ref.recoveries;fallbacks+=ref.zero_fallbacks
        counts['fixtures']+=1
    # Arbitrary extension inputs. Active-mask fixtures use genuinely moving
    # slopes; inactive fixtures force the public mask's unused difference zero.
    for ls,lc,active in itertools.product((2,3),(7,8,None),(False,True)):
        cfg,con,ir,tabs,rs=fixture(3,ls,(False,False),'full',rng,lookup_count=lc)
        g,out,artifact=write_artifacts(cfg,active,HERE/'generated')
        shape_record=dict(ls=ls,lookup_count=len(cfg['lookups']),mask_active=active,generated=artifact)
        for recycled in (False,True):
            fn,st,src,_,_=compile_factory(cfg,active,recycled)
            tree=ast.parse(src)
            assert not any(isinstance(x,(ast.If,ast.IfExp,ast.For,ast.While,ast.ListComp,ast.GeneratorExp)) for x in ast.walk(tree))
            counts['branchless_generated_bodies']+=1
            dynamic=[]
            for zero in (False,True):
                draw=lambda:F() if zero else F(rng.randrange(P),rng.randrange(P))
                co=constants(cfg,draw);co_ir=expanded(cfg,co)
                vals=[draw() for _ in cfg['names']];dif=[draw() for _ in vals]
                if not active:dif[cfg['index']['mask']]=F()
                pl=Plan(generalize(cfg),co['alpha'],co['gu8']);offs=[x[0] for x in pl.entries]
                got=fn(vals,dif,co,offs)
                rp=CubicPlan(cfg,co,pl,{cfg['index']['mask']:({0} if active else set())},mode='cubic_round0')
                rp.round_index=0;rp.begin(vals,dif)
                assert got==rp.pending[0].c and dict(rp.counts)==st['field_ops']
                counts['dynamic_row_and_counter_parity']+=1
                for t in (F(),F(1),F(P-1,P-1),draw()):
                    vv=[a+t*b for a,b in zip(vals,dif)];expect=o.bracket(co_ir[0],list(map(o.tup,vv)))
                    value=o.Z
                    for c in reversed(got):value=o.add(o.mul(value,o.tup(t)),o.tup(c))
                    assert value==expect
                    counts['independent_extension_values']+=1
                scope={'F':CountF};exec(compile(src,'<local-counter>','exec'),scope)
                CountF.counts.clear()
                actual=scope['factory']([CountF(x) for x in vals],[CountF(x) for x in dif],{k:CountF(v) for k,v in co.items()},[CountF(x) for x in offs])
                assert tuple(x.value for x in actual)==got
                assert dict(CountF.counts)==st['field_ops']
                dynamic.append(dict(CountF.counts));counts['executed_operation_censuses']+=1
                rp.end()
            assert dynamic[0]==dynamic[1];counts['value_independent_operation_censuses']+=1
        stats.append(shape_record)
    # Negative controls are actually executed and must disagree with an
    # independent expanded-clause oracle, not merely raise a deliberate error.
    cfg,con,ir,tabs,rs=fixture(4,3,(False,False),'full',rng)
    for mut in ('drop_cubic','reverse_coefficients','wrong_cross_sign'):
        rr,rp=make(cfg,con,ir,tabs,4,3,False,'fixed_recycled',mut)
        orig=[o.table(t,4) for t in tabs]
        want=[o.round_direct(orig,list(enumerate(ir)),[],t,4) for t in range(5)]
        assert list(map(o.tup,rr.round(0)))!=want,mut
        controls.append(mut+'-detected')
    # A wrong public mask dependency must fail at an extension point.
    vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']]
    dif=[F(rng.randrange(P),rng.randrange(P)) for _ in vals]
    offs=[x[0] for x in Plan(generalize(cfg),con['alpha'],con['gu8']).entries]
    bad=compile_factory(cfg,False)[0](vals,dif,con,offs)
    t=F(2,3);vv=[a+t*b for a,b in zip(vals,dif)];expect=o.bracket(ir[0],list(map(o.tup,vv)))
    value=o.Z
    for c in reversed(bad):value=o.add(o.mul(value,o.tup(t)),o.tup(c))
    assert value!=expect;controls.append('incorrect-public-mask-metadata-detected')
    # Overwrite a still-live slot immediately after its definition. This is a
    # concrete bad lifetime schedule, independently caught by output parity.
    fn,st,src,g,out=compile_factory(cfg,True,True)
    lines=src.splitlines();target=lines[1].strip().split(' = ')[0]
    lines.insert(2,'    '+target+' = F()')
    scope={'F':F};exec(compile('\n'.join(lines)+'\n','<local-negative-output>','exec'),scope)
    assert scope['factory'](vals,dif,con,offs)!=fn(vals,dif,con,offs)
    controls.append('premature-live-slot-overwrite-detected')
    for supp in ((True,False),(False,True),(True,True)):
        cf=prior.config(supp)
        try:build(cf,False)
        except ValueError:counts['padded_factory_refusals']+=1
        else:raise AssertionError('padded accepted')
    prior_result=json.loads((HERE/'prior-result.json').read_text())
    projection=next(x for x in prior_result['projections'] if x['limbs']==3 and x['shape']['head_pad']==32 and x['shape']['token_pad']==512)
    result=dict(status='passed',cycle='0055',run_id='20261017T052624Z-c8881557',seed=SEED,counts=dict(counts),
                controls=controls,recoveries=recoveries,zero_factor_fallbacks=fallbacks,output_sha256=digest.hexdigest(),
                generated_shapes=stats,unchanged_scoped_field_census=projection,
                eliminated_public_width_tests=projection['results']['cubic_round0']['extra']['public_width_tests'],
                scope='Synthetic CPU round/fold/final and row arithmetic; no native constructor, transcript, RNG, PCS, verifier, GPU or proof.',
                wall_seconds=time.perf_counter()-started,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(device='CPU only',cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),threads=1,nice=os.nice(0),affinity=sorted(os.sched_getaffinity(0))),
                limits=dict(cpu_seconds=59,wall_seconds=59,address_space_bytes=512*1024**2,estimated_memory_bytes=64*1024**2),
                proof_accounting=prior_result['proof_accounting'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('generated_shapes','unchanged_scoped_field_census')},indent=2))
    print('GENERATED',json.dumps(stats))


if __name__=='__main__':main()
