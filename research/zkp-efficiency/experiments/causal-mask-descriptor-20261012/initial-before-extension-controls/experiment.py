"""Bounded correctness/cost study, standard library only, synthetic data."""
import hashlib,json,os,platform,random,resource,signal,time
from pathlib import Path
from field import F,P,fold,bits
from descriptor import CausalMask,eval_formula
import oracle
HERE=Path(__file__).resolve().parent
SEED=2026101237
def tup(x): return x.a,x.b
def random_field(rng,mode):
    if mode=='bool': return F(rng.randrange(2))
    if mode=='base': return F(rng.randrange(P))
    if mode=='zero': return F()
    return F(rng.randrange(P),rng.randrange(P))
def native_words(h,lt):
    t=1<<lt
    return [F(int(x%t<=(x//t)%t)) for x in range(1<<(h+2*lt))]
def support_words(h,lt,true_t,true_h):
    t=1<<lt
    return [F(int(x//(t*t)<true_h and (x//t)%t<true_t and x%t<true_t))
            for x in range(1<<(h+2*lt))]
def sensitive(v):
    # Mask-bearing source terms in SC_RS and SC_SZC. Other full clauses are
    # unchanged; this fixture does not claim an honest native witness.
    m,e,z,s8,mx,total,p,hx,gs,ght,eq,lam,alpha,beta,gexp=v
    rs=gs*eq*(m*e+lam*z)
    delta=mx-m*(s8+127)+127
    zc=z*delta+(512*m*e-p*total)
    cx=alpha*hx-hx*delta-beta*hx*e-gexp*hx-1
    return rs+eq*(gs*zc+cx)+ght*eq*(total+lam)
def oracle_sensitive(v):
    m,e,z,s8,mx,total,p,hx,gs,ght,eq,lam,alpha,beta,gexp=v
    a,s,mul=oracle.add,oracle.sub,oracle.mul;k=lambda n:(n%P,0)
    rs=mul(mul(gs,eq),a(mul(m,e),mul(lam,z)))
    delta=a(s(mx,mul(m,a(s8,k(127)))),k(127))
    zc=a(mul(z,delta),s(mul(mul(k(512),m),e),mul(p,total)))
    exp=s(s(s(s(mul(alpha,hx),mul(hx,delta)),mul(mul(beta,hx),e)),mul(gexp,hx)),oracle.O)
    return a(a(rs,mul(eq,a(mul(gs,zc),exp))),mul(mul(ght,eq),a(total,lam)))
def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    affinity=os.sched_getaffinity(0);os.sched_setaffinity(0,{min(affinity)});os.nice(19)
    start=time.monotonic();rng=random.Random(SEED);digest=hashlib.sha256()
    counts=dict(fixtures=0,endpoint_values=0,sample_values=0,round_sensitive_samples=0,
                direct_cube_mles=0,terminals=0,off_domain_formula=0,folded_states=0)
    controls=[];models=[]
    # Up to 1024 words; h includes any lifted/dummy leading axes.
    for h,lt in [(0,0),(3,0),(0,1),(1,1),(2,2),(1,3),(2,3),(0,4),(2,4)]:
        original=native_words(h,lt);ows=oracle.mask_words(h,lt)
        assert list(map(tup,original))==ows
        for mode in ['full','base','bool','zero']:
            n=h+2*lt;challenges=[random_field(rng,mode) for _ in range(n)]
            desc=CausalMask(h,lt);v=original[:];prefix=[]
            true_t=max(1,(1<<lt)-1);true_h=max(1,(1<<h)-1)
            g=support_words(h,lt,true_t,true_h)
            planes=[original]+[[random_field(rng,'full') for _ in original] for _ in range(7)]
            planes+=[g,g[:], [random_field(rng,'full') for _ in original]]
            constants=[random_field(rng,'full') for _ in range(4)]
            frozen=[[tup(x) for x in tab] for tab in planes]
            for r in challenges:
                assert [desc.at(i) for i in range(len(v))]==v
                counts['endpoint_values']+=len(v);counts['folded_states']+=1
                half=len(v)//2
                # All native degree samples are exact linear combinations of
                # endpoints; explicit degree0..6 catches nonlinear consumers.
                for x in range(7):
                    for i in range(half):
                        got=desc.at(i)+F(x)*(desc.at(i+half)-desc.at(i))
                        want=v[i]+F(x)*(v[i+half]-v[i]);assert got==want
                        counts['sample_values']+=1;digest.update(got.wire())
                    # Source-sensitive round expression for one fixed tail.
                    row=[tab[0]+F(x)*(tab[half]-tab[0]) for tab in planes]+constants
                    crow=row[:];crow[0]=desc.at(0)+F(x)*(desc.at(half)-desc.at(0))
                    assert sensitive(crow)==sensitive(row)
                    counts['round_sensitive_samples']+=1
                    if n<=5:
                        point=list(map(tup,prefix))+[(x,0)]+[(0,0)]*(n-len(prefix)-1)
                        direct=[oracle.mle(tab,point) for tab in frozen]+list(map(tup,constants))
                        assert tup(sensitive(crow))==oracle_sensitive(direct)
                        counts['direct_cube_mles']+=len(frozen)
                desc.bind(r);v=fold(v,r);planes=[fold(tab,r) for tab in planes];prefix.append(r)
            assert desc.terminal()==v[0]==eval_formula(h,lt,challenges)
            direct=oracle.mle(ows,list(map(tup,challenges)))
            assert tup(v[0])==direct;counts['direct_cube_mles']+=1
            counts['terminals']+=1;counts['fixtures']+=1
            expected=2*((1<<lt)-1)
            assert desc.interpolations==expected
            models.append(dict(leading_bits=h,token_bits=lt,total_vars=n,mode=mode,
                               dense_words=1<<n,dense_folds=(1<<n)-1,
                               candidate_interpolations=expected,peak_candidate_words=desc.peak_words,
                               candidate_predicates=desc.predicates,reads=desc.reads))
        for _ in range(8):
            point=[random_field(rng,'full') for _ in range(h+2*lt)]
            assert tup(eval_formula(h,lt,point))==oracle.mle(ows,list(map(tup,point)))
            counts['off_domain_formula']+=1;counts['direct_cube_mles']+=1
    def catch(name,condition):
        assert condition,name;controls.append(name)
    h,lt=2,2;t=1<<lt;words=native_words(h,lt);n=h+2*lt
    # Padded-head / lifted-axis invariance and true token padding must survive.
    catch('filter_padded_head_changes_relation',words!=[x if i//(t*t)<3 else F() for i,x in enumerate(words)])
    catch('filter_true_token_bounds_changes_relation',words!=[x if (i//t)%t<3 and i%t<3 else F() for i,x in enumerate(words)])
    catch('strict_comparator_loses_diagonal',words!=[F(int(i%t<(i//t)%t)) for i in range(1<<n)])
    catch('transpose_axes_changes_relation',words!=[F(int((i//t)%t<=i%t)) for i in range(1<<n)])
    q=[F(2,3),F(7,1),F(11,5),F(17,4),F(19,13),F(23,29)]
    final=eval_formula(h,lt,q)
    catch('reverse_MSB_coordinates',final!=eval_formula(h,lt,q[:h]+q[h:h+lt][::-1]+q[h+lt:][::-1]))
    catch('drop_extension_components',final!=eval_formula(h,lt,[F(x.a) for x in q]))
    broken=words[:];broken[t+0]=broken[t+0]+1
    catch('mutated_boolean_cell',oracle.mle(list(map(tup,broken)),list(map(tup,q)))!=tup(final))
    d=CausalMask(h,lt)
    for r in q[:h+1]:d.bind(r)
    catch('stale_unfolded_reader',d.at(2)!=words[2])
    catch('wrong_midpoint_update',d.hi!=[F(1)]*len(d.hi))
    for label,fun in [('negative_index',lambda:d.at(-1)),('oversized_index',lambda:d.at(1<<d.remaining())),
                      ('premature_terminal',d.terminal),('negative_dimension',lambda:CausalMask(-1,2)),
                      ('noninteger_dimension',lambda:CausalMask(0,1.5)),
                      ('wrong_formula_arity',lambda:eval_formula(2,2,[]))]:
        try:fun()
        except ValueError:controls.append(label)
        else:raise AssertionError(label)
    for r in q[h+1:]:d.bind(r)
    try:d.bind(F(1))
    except ValueError:controls.append('terminal_overbind')
    else:raise AssertionError('terminal overbind')
    # Native dimension illustration only, never allocate large tables.
    large=[]
    for leading,lt in [(5,9),(5,10),(5,11),(5,12)]:
        size=1<<(leading+2*lt);tp=1<<lt
        peak=3*tp if lt else 2 # old+new two-vector temporary bound at last t step
        large.append(dict(context_padded=tp,leading_slots=1<<leading,explicit_payload_bytes=16*size,
                          compact_peak_payload_bytes=16*peak,compact_retained_at_t_end_bytes=16*tp,
                          dense_fold_interpolations=size-1,compact_interpolations=2*(tp-1),
                          excluded='other tables, capacities/allocator, witness, commitments, masks, transcript, verification'))
    cpu=next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),'unknown')
    out=dict(run_id='20261012T182555Z-4bc569b3',cycle='0037',status='pass',seed=SEED,counts=counts,
             controls=controls,control_count=len(controls),fixtures=models,count_only_dimensions=large,
             digest_sha256=digest.hexdigest(),elapsed_seconds=time.monotonic()-start,
             peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             hardware=dict(device='CPU only',cpu=cpu,threads=1,affinity=list(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),python=platform.python_version()),
             resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=32),
             code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
             proof_accounting=dict(context_length=None,passes=0,device='CPU only',accepted_complete_private8b_proofs=0,countable_tokens=0,
                 steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,witness_seconds=None,
                 proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,proof_latency_seconds=None,proof_lag_seconds=None,
                 pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
             limits=['Synthetic public-mask replacement and mask-sensitive clauses only; not complete native SC_SZC or honest witness',
                     'No native build/compiler/device/timing/masked extension/RNG/transcript/receipt/privacy gates',
                     'Counted payload/interpolation savings are not runtime or parent peak savings'])
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ['fixtures','count_only_dimensions','code_hashes']},indent=2))
if __name__=='__main__':main()
