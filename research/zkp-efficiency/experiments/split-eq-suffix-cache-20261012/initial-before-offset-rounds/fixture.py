#!/usr/bin/env python3
"""Synthetic complete SC_SZC algebra, heterogeneous public/dense driver.

Seeded inconsistent planes are deliberate. This is neither an honest witness
nor a masked proof. An independent original-cube tuple oracle checks every
sample, and a separate expanded-monomial oracle checks the literal clauses.
"""
import copy, hashlib, json, os, platform, random, resource, signal, time
from collections import Counter
from pathlib import Path
from field import F, P, fold
from support import geometry, make
from causal import CausalMask
from support_reference import source_cube
from driver import Dense, Tables, Rounds, extend
from source_port import layout, bracket
from polynomial_ir import expanded
import full_oracle as o
import oracle as basic

HERE = Path(__file__).resolve().parent
SEED = 2026101239
RUN = '20261012T202555Z-550cccf0'

def limits():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})

def original_partial(original, prefix, n):
    """Sum original cells against prefix basis weights, independently of folds.

    The untouched Boolean tail selects its cells; no descriptor, dense bind,
    sample interpolation, or candidate field is called.
    """
    tail = n-len(prefix); length = 1 << tail
    out = [[o.Z for _ in range(length)] for _ in original]
    for index in range(1 << n):
        weight = o.O
        for j, x in enumerate(prefix):
            weight = o.mul(weight,x if (index>>(n-1-j))&1 else o.sub(o.O,x))
        pos = index & (length-1)
        for target, words in zip(out,original):
            target[pos] = o.add(target[pos],o.mul(words[index],weight))
    return out

def original_round(original, ir, prefix, n, degree):
    out=[]
    for x in range(degree+1):
        values=original_partial(original,prefix+[(x,0)],n)
        acc=o.Z
        for i in range(len(values[0])):
            acc=o.add(acc,o.poly(list(enumerate(ir)),[a[i] for a in values]))
        out.append(F(*acc))
    return out

def literal_poly(cfg,const,mutation=None):
    return lambda v: sum((v[g]*bracket(g,v,cfg,const,mutation)[0] for g in range(3)),F())

def fixtures(rng):
    # Ht/S include KV-interleaved head padding and ragged token bounds.
    specs=[(1,1,1),(2,1,1),(3,3,1),(3,6,2)]
    for tokens,heads,kv in specs:
        for mode in ('full','base','boolean','zero'):
            for ls in (2,3):
                draw=lambda: (F(rng.randrange(P),rng.randrange(P)) if mode=='full'
                              else F(rng.randrange(P)) if mode=='base'
                              else F(rng.randrange(2)) if mode=='boolean' else F())
                g=geometry(tokens,heads,kv,head_dim=2,hidden=5,row_log=0)
                leading=g['h_pad'].bit_length()-1; lt=g['t_pad'].bit_length()-1
                n=leading+2*lt; cfg=layout(ls=ls,padded=True,
                                        lookup_count=None if ls==3 else 12)
                const={name:draw() for name in ['alpha','beta','gexp','gu8','lam',
                                               'nu0','nu1','zeta','mupad']+
                       ['mu'+str(j) for j in range(6+cfg['helpers'])]}
                for name in ('nu0','nu1','zeta'):
                    if const[name]==0:const[name]=F(1)
                words=[]; originals=[]; entries=[]; group_points=[]
                for name in cfg['names']:
                    private=name not in ('eq0','eq1','eq2','mask','ght','gs')
                    if name in ('ght','gs'):
                        dom='Ht' if name=='ght' else 'S'
                        original=source_cube(g,dom,n)
                        a=[F(*v) for v in original]; tab=make(g,dom,n)
                    elif name=='mask':
                        original=basic.mask_words(leading,lt)
                        a=[F(*v) for v in original]; tab=CausalMask(leading,lt)
                    elif name.startswith('eq'):
                        # Equality table remains dense in this representation study.
                        k=int(name[-1]); size=leading+lt if k==1 else n
                        point=[draw() for _ in range(size)]
                        group_points.append(point)
                        original=[o.eq(list(map(o.tup,point)),[(b,0) for b in o.bits(i,n)[:size]])
                                  for i in range(1 << n)]
                        a=[F(*v) for v in original];tab=Dense(n,a)
                    else:
                        a=[draw() for _ in range(1 << n)]
                        if name in ('mx','sum') and lt:
                            a=[a[(i>>lt)<<lt] for i in range(1 << n)]
                        original=list(map(o.tup,a));tab=Dense(n,a)
                    words.append(a);originals.append(original);entries.append((name,private,tab))
                yield g,n,cfg,const,expanded(cfg,const),words,originals,entries,[draw() for _ in range(n)],draw,mode,group_points

def expect_error(name,fn,controls):
    try:fn()
    except ValueError:controls.append(name)
    else:raise AssertionError('control failed: '+name)

def main():
    limits();start=time.perf_counter();rng=random.Random(SEED)
    counts=Counter();digest=hashlib.sha256();cost_rows=[];control_fixture=None
    for g,n,cfg,const,ir,words,originals,entries,rhos,draw,mode in fixtures(rng):
        counts['fixtures']+=1;poly=literal_poly(cfg,const);degree=5
        # Direct tuple algebra at the Boolean cube checks generic claimed total.
        total_o=o.Z
        for i in range(1 << n):
            total_o=o.add(total_o,o.poly(list(enumerate(ir)),[a[i] for a in originals]))
        total=F(*total_o);base=copy.deepcopy(words);messages=[];prefix=[]
        for j,r in enumerate(rhos):
            half=len(base[0])//2
            reference=[sum((poly([a[i]+F(x)*(a[i+half]-a[i]) for a in base])
                            for i in range(half)),F()) for x in range(degree+1)]
            independent=original_round(originals,ir,prefix,n,degree)
            assert reference==independent,(mode,n,j,'independent clause/cube')
            counts['independent_round_samples']+=degree+1
            messages.append(reference);base=[fold(a,r) for a in base];prefix.append(o.tup(r))
        finals=[a[0] for a in base]
        direct=[F(*o.mle(a,list(map(o.tup,rhos)))) for a in originals]
        assert finals==direct;counts['independent_table_finals']+=len(finals)
        schedules=[(1,False,None,False),(3,False,None,False),
                   (7,True,None,False),(1024,True,total,True)]
        for chunk,recover,claim,debug in schedules:
            t=Tables(n,copy.deepcopy(entries))
            for c in (1,3,1024):
                assert t.total(poly,c)==total;counts['generic_total_checks']+=1
            ev=Rounds(t,degree,poly,chunk,recover,claim,debug)
            for j,r in enumerate(rhos):
                sums=ev.round(j);assert sums==messages[j],(mode,n,j,chunk)
                for value in sums:digest.update(value.wire())
                counts['candidate_round_samples']+=len(sums)
                ev.bind(r)
            assert ev.finals()==finals;counts['candidate_table_finals']+=len(finals)
            assert t.bind_calls==n*len(entries)
            counts['descriptor_bind_calls']+=n*3;counts['recoveries']+=ev.recoveries
            counts['schedules']+=1
            public=[i for i,(_,private,_) in enumerate(entries) if not private]
            cur=list(finals);independent_cur=list(map(o.tup,direct));selector=F(1)
            # Two synthetic private extension targets, public target always zero.
            for stage in range(2):
                exts={name:draw() for i,(name,private,_) in enumerate(entries)
                      if private and i%2==stage}
                for x in range(degree+1):
                    vals=extend(cur,entries,exts,F(x))
                    oracle_vals=[o.add(a,o.mul((x,0),o.sub(
                        o.tup(exts.get(name,F())) if private else o.Z,a)))
                        for a,(name,private,_) in zip(independent_cur,entries)]
                    assert list(map(o.tup,vals))==oracle_vals
                    counts['independent_extension_table_samples']+=len(vals)
                    lhs=poly(vals);rhs=o.poly(list(enumerate(ir)),oracle_vals)
                    assert lhs==F(*rhs);counts['extension_polynomial_samples']+=1
                e=F(3+stage,5+stage)
                cur=extend(cur,entries,exts,e);selector*=1-e
                independent_cur=[o.add(a,o.mul(o.tup(e),o.sub(
                    o.tup(exts.get(name,F())) if private else o.Z,a)))
                    for a,(name,private,_) in zip(independent_cur,entries)]
                assert list(map(o.tup,cur))==independent_cur
                for i in public:
                    assert cur[i]==selector*direct[i];counts['public_extension_terminals']+=1
            if chunk==1:
                descriptors=[tab for name,_,tab in t.entries if name in ('mask','ght','gs')]
                rows=dict(mode=mode,context=g['tokens'],t_pad=g['t_pad'],h_pad=g['h_pad'],
                          cube_log=n,tables=len(entries),dense_public_lerps_before=3*((1<<n)-1),
                          causal_lerps=descriptors[0].interpolations,
                          support_lerps=sum(tab.bind_lerps for tab in descriptors[1:]),
                          descriptor_reads=sum(tab.reads for tab in descriptors),
                          integer_tests=sum(getattr(tab,'integer_tests',getattr(tab,'predicates',0))
                                            for tab in descriptors),
                          common_sample_interpolation_unchanged=True)
                cost_rows.append(rows)
        # The companion RS polynomial shares S support and causal tables;
        # Eq1 covers the LEADING Ht axes and stays constant over padded j.
        rs_indices=[cfg['index'][name] for name in ('eq1','mask','e','zsel','gs')]
        rs_entries=[copy.deepcopy(entries[i]) for i in rs_indices]
        rs_original=[originals[i] for i in rs_indices]
        rs_poly=lambda v:v[4]*v[0]*(v[1]*v[2]+const['lam']*v[3])
        def rs_oracle(v):
            return o.mul(o.mul(v[4],v[0]),o.add(o.mul(v[1],v[2]),o.mul(o.tup(const['lam']),v[3])))
        rs=Rounds(Tables(n,rs_entries),4,rs_poly,chunk=3,recover=True,claim=None)
        rs_total=o.Z
        for i in range(1 << n):rs_total=o.add(rs_total,rs_oracle([a[i] for a in rs_original]))
        assert rs.tables.total(rs_poly)==F(*rs_total);counts['RS_generic_total_checks']+=1
        prefix=[]
        for j,r in enumerate(rhos):
            expected=[]
            for x in range(5):
                values=original_partial(rs_original,prefix+[(x,0)],n);value=o.Z
                for i in range(len(values[0])):value=o.add(value,rs_oracle([a[i] for a in values]))
                expected.append(F(*value))
            assert rs.round(j)==expected;counts['RS_independent_round_samples']+=5
            rs.bind(r);prefix.append(o.tup(r))
        assert rs.finals()==[F(*o.mle(a,list(map(o.tup,rhos)))) for a in rs_original]
        counts['RS_independent_table_finals']+=len(rs_indices)
        if mode=='full' and n==6 and cfg['ls']==3 and control_fixture is None:
            control_fixture=(g,n,cfg,const,ir,words,originals,entries,rhos,total,messages,finals)
    controls=[]
    g,n,cfg,const,ir,words,originals,entries,rhos,total,messages,finals=control_fixture
    poly=literal_poly(cfg,const);ix=cfg['index']
    def changed(name,new_entries,changed_poly=None):
        ev=Rounds(Tables(n,new_entries),5,changed_poly or poly)
        found=False
        for j,r in enumerate(rhos):
            if ev.round(j)!=messages[j]:found=True;break
            ev.bind(r)
        assert found,'mutation escaped '+name;controls.append(name)
    bad=copy.deepcopy(entries);i=ix['mask'];bad[i]=('mask',False,Dense(n,[F()]*(1<<n)))
    changed('zero_dense_placeholder_for_causal',bad)
    bad=copy.deepcopy(entries);i=ix['ght'];bad[i]=('ght',False,make(g,'S',n))
    changed('Ht_support_replaced_by_S',bad)
    bad=copy.deepcopy(entries);a,b=ix['ght'],ix['gs'];bad[a],bad[b]=bad[b],bad[a]
    changed('table_order_swapped',bad)
    bad=copy.deepcopy(entries);i=ix['mask'];w=list(words[i]);w[1]=1-w[1]
    bad[i]=('mask',False,Dense(n,w));changed('mutated_causal_boolean_cell',bad)
    changed('drop_softmax_clause',copy.deepcopy(entries),literal_poly(cfg,const,'drop_c2'))
    changed('gate_lookup_helpers_by_support',copy.deepcopy(entries),literal_poly(cfg,const,'gate_helpers'))
    changed('future_score_host_gated_by_causal',copy.deepcopy(entries),
            lambda v:v[0]*bracket(0,v,cfg,const)[0]+v[1]*bracket(1,v,cfg,const)[0]
            +v[2]*v[ix['mask']]*bracket(2,v,cfg,const)[0])
    ev=Rounds(Tables(n,copy.deepcopy(entries)),5,poly,recover=True,claim=F())
    assert total!=0 and ev.round(0)!=messages[0];controls.append('asserted_host_zero_seed_changes_inconsistent_first_round')
    ev=Rounds(Tables(n,copy.deepcopy(entries)),5,poly,recover=True,claim=F(),debug=True)
    expect_error('debug_wrong_seed_refused',lambda:ev.round(0),controls)
    e=F(3,5);correct=extend(finals,entries,{},e)
    bad=list(correct);bad[ix['mask']]=finals[ix['mask']]
    assert poly(correct)!=poly(bad);controls.append('missing_public_extension_selector')
    wrong=extend(finals,entries,{},e);wrong[ix['ght']]+=e
    assert poly(correct)!=poly(wrong);controls.append('nonzero_public_extension_target')
    expect_error('explicit_cube_mismatch',lambda:Tables(n+1,copy.deepcopy(entries)),controls)
    expect_error('empty_table_set',lambda:Tables(n,[]),controls)
    expect_error('duplicate_table_identity',lambda:Tables(n,[entries[0],entries[0]]),controls)
    expect_error('dense_length_mismatch',lambda:Dense(n,[F()]),controls)
    t=Tables(n,copy.deepcopy(entries));expect_error('negative_index',lambda:t.row(-1),controls)
    expect_error('outside_cube_index',lambda:t.row(1<<n),controls)
    expect_error('early_finals',lambda:t.finals(),controls)
    ev=Rounds(Tables(n,copy.deepcopy(entries)),5,poly)
    expect_error('bind_before_round',lambda:ev.bind(F(2)),controls)
    expect_error('round_order',lambda:ev.round(1),controls);ev.round(0)
    expect_error('second_round_before_bind',lambda:ev.round(0),controls)
    for j,r in enumerate(rhos):
        if j:ev.round(j)
        ev.bind(r)
    expect_error('round_after_terminal',lambda:ev.round(n),controls)
    expect_error('bind_after_terminal',lambda:ev.tables.bind(F(1)),controls)
    expect_error('descriptor_prebound_initial_state',lambda:Tables(n,ev.tables.entries),controls)
    # Discarding original public tables cannot discard the logical cube extent.
    public_only=[entries[i] for i in (ix['mask'],ix['ght'],ix['gs'])]
    t=Tables(n,copy.deepcopy(public_only));assert len(t.row(0))==3
    counts['all_public_explicit_cube_check']+=1
    result=dict(run_id=RUN,cycle='0039',status='pass',seed=SEED,counts=dict(counts),
                controls=controls,control_count=len(controls),cost_rows=cost_rows,
                digest_sha256=digest.hexdigest(),elapsed_seconds=time.perf_counter()-start,
                peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(device='CPU only',cpu=next(line.split(':',1)[1].strip()
                    for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),
                    threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),python=platform.python_version()),
                resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
                code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                proof_accounting=dict(context_length=None,passes=0,device='CPU only',countable_tokens=0,
                    accepted_complete_private8b_proofs=0,steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,
                    startup_seconds=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,
                    serialization_seconds=None,independent_verification_seconds=None,proof_latency_seconds=None,
                    proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
                limits=['Synthetic complete SC_SZC equations with deliberately inconsistent dense planes, not honest witness',
                        'Generic Closure-style driver only; optimized GroupedEqRounds integration unexecuted',
                        'No masks/RNG/transcript/refusal/PCS/receipt/native build/device/privacy proof',
                        'Logical allocation/lerp counts exclude native constructor, dispatch, compiler and enclosing clocks'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},indent=2))

if __name__=='__main__':main()
