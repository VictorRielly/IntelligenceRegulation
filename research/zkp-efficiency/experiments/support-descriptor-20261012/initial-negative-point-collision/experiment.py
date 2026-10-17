"""One-thread, <60 s, standard-library exactness and accounting experiment."""
import hashlib,json,os,platform,random,resource,signal,time
from pathlib import Path
from field import F,P,fold,bits
from descriptor import Axis,Support,geometry,spec,make
from reference import source_cube
import oracle
HERE=Path(__file__).resolve().parent
SEED=2026101238
def tup(x):return x.a,x.b
def rnd(rng,mode='full'):
    if mode=='zero':return F()
    if mode=='bool':return F(rng.randrange(2))
    return F(rng.randrange(P),0 if mode=='base' else rng.randrange(P))
def expect_refusal(name,f,controls):
    try:f()
    except (ValueError,AssertionError):controls.append(name);return
    raise AssertionError('missed refusal '+name)
def predicate_eval(axes,point):
    # Independent direct-cube evaluation of EACH factor, valid only disjoint.
    out=oracle.O
    for a in axes:
        words=[oracle.O if i<a.limit else oracle.Z for i in range(1<<a.bits)]
        out=oracle.mul(out,oracle.mle(words,list(map(tup,point[a.start:a.start+a.bits]))))
    return out
def sensitive(gs,ght,eq,plane,sumv,lam,mu):
    # Support-sensitive clauses: RS summand, both SZC hosts and pad-zero terms.
    # Full nonlinear and LogUp arms are not ported or claimed here.
    return eq*(gs*plane+ght*(sumv+lam)+gs*(512*plane-32)+(1-gs)*mu*plane+(1-ght)*mu*sumv)
def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    start=time.monotonic();rng=random.Random(SEED);digest=hashlib.sha256()
    counts=dict(fixtures=0,endpoints=0,samples=0,folded_states=0,direct_mles=0,
                factored_mles=0,terminals=0,public_extension_values=0,
                support_sensitive_round_sums=0,independent_sensitive_points=0)
    rows=[];controls=[]
    small=geometry(3,6,2,2,5,0)
    cases=[('small-'+dom,small,dom,None) for dom in ('T','Ht','S','D','Q','Kv','F','L','Tab')]
    cases += [('small-Ht-in-S',small,'Ht',7),('small-T-lift',small,'T',6)]
    cases += [(f'ragged{t}-S',geometry(t,q,kv,2,9,0),'S',None)
              for t,q,kv in [(1,1,1),(2,3,1),(5,10,2),(7,12,4),(4,4,4)]]
    lift=geometry(3,6,2,2,5,9)
    cases += [('row-lift-'+dom,lift,dom,None) for dom in ('D','F','L','Tab')]
    toy=geometry(32,2,1,8,16,8);rung=geometry(24,6,2,16,192,10)
    cases += [('native-toy-S',toy,'S',None),('native-toy-Ht-in-S',toy,'Ht',11),
              ('native-rung-S',rung,'S',None),('native-rung-Ht-in-S',rung,'Ht',13)]
    for name,g,dom,cube in cases:
        n,axes,own,natural,liftbits=spec(g,dom,cube)
        original=source_cube(g,dom,cube)
        modes=['full','base','bool','zero'] if len(original)<=512 else ['full','bool']
        for mode in modes:
            desc=make(g,dom,cube);v=[F(*x) for x in original]
            challenges=[rnd(rng,mode) for _ in range(n)];prefix=[]
            for r in challenges:
                got=[desc.at(i) for i in range(len(v))]
                assert got==v,(name,mode,len(prefix),'endpoint')
                counts['endpoints']+=len(v);counts['folded_states']+=1
                half=len(v)//2
                for sample in range(7):
                    for i in range(half):
                        c=got[i]+sample*(got[i+half]-got[i]);b=v[i]+sample*(v[i+half]-v[i])
                        assert c==b;counts['samples']+=1;digest.update(c.wire())
                    if n<=6:
                        point=prefix+[F(sample)]+[F()]*(n-len(prefix)-1)
                        direct=oracle.mle(original,list(map(tup,point)))
                        assert tup(got[0]+sample*(got[half]-got[0]))==direct
                        counts['direct_mles']+=1
                desc.bind(r);v=fold(v,r);prefix.append(r)
            assert desc.terminal()==v[0]
            direct=oracle.mle(original,list(map(tup,challenges)))
            assert tup(v[0])==direct==predicate_eval(axes,challenges)
            counts['direct_mles']+=1;counts['factored_mles']+=1;counts['terminals']+=1
            for es in ([F(2,3)],[F(3,2),F(5,7)],[F()],[F(1)]):
                sel=F(1);osel=oracle.O
                for e in es:sel*=1-e;osel=oracle.mul(osel,oracle.sub(oracle.O,tup(e)))
                assert tup(sel*desc.terminal())==oracle.mul(osel,direct)
                if n<=6:
                    extended=original[:]
                    for _ in es:extended=extended+[oracle.Z]*len(extended)
                    # Extension dimensions are TRAILING natively: append
                    # selector bits to each word rather than leading doubling.
                    extended=[x if j==0 else oracle.Z for x in original for j in range(1<<len(es))]
                    assert oracle.mle(extended,list(map(tup,challenges+list(es))))==oracle.mul(osel,direct)
                counts['public_extension_values']+=1
            rows.append(dict(name=name,mode=mode,dom=dom,n=n,own_log=own,natural_log=natural,
                             lift_bits=liftbits,axes=[a.__dict__ for a in desc.axes],
                             dense_words=len(original),dense_folds=len(original)-1,
                             candidate_bind_lerps=desc.bind_lerps,endpoint_reads=desc.reads,
                             integer_tests=desc.integer_tests))
            counts['fixtures']+=1
    # The full-tail sums use disjoint support readers but arbitrary private
    # synthetic planes. Native host/pad-sensitive relation, not honest witness.
    for t,q,kv in [(3,3,1),(2,4,2),(1,1,1)]:
        g=geometry(t,q,kv,2,5,0);n=spec(g,'S')[0]
        ds=make(g,'S');dh=make(g,'Ht',n)
        frozen=[source_cube(g,'S'),source_cube(g,'Ht',n)]
        tabs=[[F(*x) for x in v] for v in frozen]
        tabs += [[rnd(rng) for _ in range(1<<n)] for _ in range(3)]
        frozen += [[tup(x) for x in v] for v in tabs[2:]]
        lam,mu=rnd(rng),rnd(rng);prefix=[]
        for step in range(n):
            half=1<<(n-step-1)
            for sample in range(7):
                a=F();b=F()
                for i in range(half):
                    row=[v[i]+sample*(v[i+half]-v[i]) for v in tabs]
                    gs=ds.at(i)+sample*(ds.at(i+half)-ds.at(i));ght=dh.at(i)+sample*(dh.at(i+half)-dh.at(i))
                    a+=sensitive(gs,ght,*row[2:],lam,mu);b+=sensitive(*row,lam,mu)
                    if n<=5:
                        point=prefix+[F(sample)]+[F(x) for x in bits(i,n-step-1)]
                        rr=[oracle.mle(v,list(map(tup,point))) for v in frozen]
                        # Independent original-cube inputs + schoolbook field
                        # formula, without candidate field operations.
                        gs0,ht0,eq0,plane0,sum0=rr;add,mul,sub=oracle.add,oracle.mul,oracle.sub
                        term=add(mul(gs0,plane0),mul(ht0,add(sum0,tup(lam))))
                        term=add(term,mul(gs0,sub(mul((512,0),plane0),(32,0))))
                        term=add(term,mul(mul(sub(oracle.O,gs0),tup(mu)),plane0))
                        term=add(term,mul(mul(sub(oracle.O,ht0),tup(mu)),sum0))
                        assert tup(sensitive(gs,ght,*row[2:],lam,mu))==mul(eq0,term)
                        counts['independent_sensitive_points']+=1;counts['direct_mles']+=len(rr)
                assert a==b;counts['support_sensitive_round_sums']+=1
            r=rnd(rng);ds.bind(r);dh.bind(r);tabs=[fold(v,r) for v in tabs];prefix.append(r)
    # Negative controls, all deterministic and independent of prover success.
    g=geometry(3,6,2,2,5,0);ows=source_cube(g,'S');n=spec(g,'S')[0]
    point=[F(2,3) for _ in range(n)]
    bad=[];tp=g['t_pad'];hp=g['h_pad']
    for x in range(1<<n):
        h=x//(tp*tp);t=(x//tp)%tp;j=x%tp
        bad.append(oracle.O if h<g['q_heads'] and t<3 and j<3 else oracle.Z)
    assert oracle.mle(bad,list(map(tup,point)))!=oracle.mle(ows,list(map(tup,point)))
    controls.append('flat_head_prefix_changes_grouped_support')
    ht=source_cube(g,'Ht',n)
    assert ht!=ows;controls.append('S_support_replaces_Ht_host_and_forces_true_rows_zero_at_padded_j')
    wrong=[source_cube(g,'Ht')[x%(g['h_pad']*tp)] for x in range(1<<n)]
    assert wrong!=ht;controls.append('coarse_tile_on_trailing_coordinates')
    # Original Boolean product MLE differs from multiplying overlapping MLEs.
    from itertools import product
    m=[oracle.O if j<=t else oracle.Z for t,j in product(range(2),repeat=2)]
    s=[oracle.O,oracle.Z,oracle.Z,oracle.Z]
    p=[(2,0),(3,0)];merged=[oracle.mul(a,b) for a,b in zip(m,s)]
    assert oracle.mul(oracle.mle(m,p),oracle.mle(s,p))!=oracle.mle(merged,p)
    controls.append('merged_causal_and_support_MLE_changes_native_offdomain_product')
    one=Support(1,[Axis(0,1,1)]);one.bind(F(2));assert one.terminal()!=F(1)
    controls.append('stale_boolean_threshold_at_terminal')
    liftg=geometry(3,6,2,2,5,9);tab=source_cube(liftg,'Tab')
    repeat=[oracle.O]*len(tab)
    assert tab!=repeat;controls.append('lifted_support_must_zero_high_positions_not_repeat_table_values')
    ds=make(g,'S')
    for _ in range(n):ds.bind(F(2,1))
    assert ds.terminal().b!=0
    controls.append('drop_extension_component')
    ds=make(g,'S');ds.bind(F(2,1));bad=ds.at(0)+1
    assert bad!=ds.at(0);controls.append('mutate_partial_endpoint')
    for name,f in [
        ('overlapping_predicate_axes',lambda:Support(3,[Axis(0,2,3),Axis(1,2,3)])),
        ('axis_outside_cube',lambda:Support(2,[Axis(1,2,3)])),
        ('invalid_bound',lambda:Support(1,[Axis(0,1,3)])),
        ('noninteger_dimension',lambda:Support(1.5,[])),
        ('negative_index',lambda:make(g,'S').at(-1)),
        ('oversized_index',lambda:make(g,'S').at(1<<n)),
        ('premature_terminal',lambda:make(g,'S').terminal()),
        ('overbind',lambda:Support(0,[]).bind(F())),
        ('non_tiling_coarse_indicator',lambda:make(g,'Ht',1)),
        ('native_S_row_lift_refusal',lambda:make(liftg,'S')),
        ('native_Q_row_lift_refusal',lambda:make(liftg,'Q')),
        ('native_Kv_row_lift_refusal',lambda:make(liftg,'Kv')),
        ('head_group_divisibility',lambda:geometry(3,5,2))]:expect_refusal(name,f,controls)
    # Conditional scalar census, not wall-time or peak predictions.
    cost=[]
    for label,hq,kv in [('native-m125-heads',12,4),('illustrative-32-slots',24,8)]:
        for t in (512,1024,2048,4096):
            gg=geometry(t,hq,kv,64,2048,14);nn,_,_,_,_=spec(gg,'S');N=1<<nn
            ss=make(gg,'S');hh=make(gg,'Ht',nn)
            for dsc in (ss,hh):
                for _ in range(nn):dsc.bind(F(2))
            cost.append(dict(label=label,context=t,h_pad=gg['h_pad'],N=N,
                SZC_two_support_payload_bytes=2*N*16,RS_one_support_payload_bytes=N*16,
                SZC_dense_lerps=2*(N-1),SZC_candidate_lerps=ss.bind_lerps+hh.bind_lerps,
                candidate_retained_field_words_per_support=3,
                candidate_transient_field_words_bound_per_support=6,
                candidate_axis_metadata_count_SZC=len(ss.axes)+len(hh.axes),
                endpoint_reads_for_two_supports=4*(N-1),
                integer_comparisons_upper_bound=2*(N-1)*(len(ss.axes)+len(hh.axes)),
                per_endpoint_field_operations=0))
    out=dict(run_id='20261012T192555Z-2488fec6',cycle='0038',status='pass',seed=SEED,
        counts=counts,controls=controls,control_count=len(controls),fixtures=rows,cost_rows=cost,
        digest_sha256=digest.hexdigest(),elapsed_seconds=time.monotonic()-start,
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
            affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.getpriority(os.PRIO_PROCESS,0),python=platform.python_version()),
        resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=32),
        code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(HERE.glob('*.py'))},
        proof_accounting=dict(context_length=None,passes=0,device='CPU only',countable_tokens=0,
            accepted_complete_private8b_proofs=0,steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,
            startup_seconds=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,
            serialization_seconds=None,independent_verification_seconds=None,proof_latency_seconds=None,
            proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
        limits=['Synthetic public support algebra, no native speed or honest witness',
            'Small synthetic geometries are not registered/admitted profiles',
            'Native profile gate, mask/RNG/transcript/bytes/refusals/PCS/device/privacy unexecuted',
            'No production changes/build/GPU/install/Git/downloaded-code execution'])
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:out[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256')},indent=2))
if __name__=='__main__':main()
