import os, signal, resource, time, json, random, hashlib, platform
from pathlib import Path
from itertools import combinations_with_replacement, product

# Enforce the lane's limits before importing either model.
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(40,40))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45)
from candidate import window, inside, product_hull, weak_backward, guarded_backward, provable, remove_cumulative
from reference import solutions, equality_relation, least_facts, signed

BASE=Path(__file__).resolve().parent
SEED=202610290134
rng=random.Random(SEED)
t0=time.perf_counter()
checks=0
def check(v):
    global checks
    checks+=1
    assert v, checks

weak_failures=[]; weak_cases=0; strong_cases=0; concrete_solutions=0; refinements=0
# All nonzero singleton divisors and all signed singleton c over four fields.
for p in (7,11,17,31):
    W=window(p)
    for b in range(W[0],W[1]+1):
        if b==0: continue
        for c in range(W[0],W[1]+1):
            a=signed((-c*pow(b,-1,p))%p,p)
            check((a*b+c)%p==0)
            d=weak_backward(p,(b,b),(c,c)); weak_cases+=1
            if not d[0] <= a <= d[1]:
                weak_failures.append(dict(p=p,a=a,b=b,c=c,inferred=d,integer_product=a*b))
            strong=guarded_backward(p,W,(b,b),(c,c))
            check(strong[0] <= a <= strong[1]);strong_cases+=1
    # Independent concrete oracle enumerates all triples inside random premises.
    for _ in range(160):
        A=tuple(sorted(rng.sample(range(W[0],W[1]+1),2)))
        B=tuple(sorted(rng.sample(range(W[0],W[1]+1),2)))
        C=tuple(sorted(rng.sample(range(W[0],W[1]+1),2)))
        d=guarded_backward(p,A,B,C);strong_cases+=1
        if d != A: refinements+=1
        for a,b,c in solutions(p,A,B,C):
            concrete_solutions+=1
            check(d[0]<=a<=d[1])
    # Explicit positive narrow-domain and zero-divisor controls.
    for B in ((1,2),(-2,-1),(0,0),(-1,1)):
        A=(-1,1);C=(0,0)
        d=guarded_backward(p,A,B,C)
        for a,b,c in solutions(p,A,B,C):check(d[0]<=a<=d[1])
        if B[0] > 0 or B[1] < 0: check(d==(0,0));refinements+=1
        else: check(d==A)
check(len(weak_failures)>0)
# Exhaust ALL interval triples over F5 and F7, including divisor intervals
# containing zero. This checks local-rule soundness, not just honest traces.
exhaustive_interval_cases=0
for p in (5,7):
    W=window(p)
    intervals=list(combinations_with_replacement(range(W[0],W[1]+1),2))
    for A,B,C in product(intervals,repeat=3):
        d=guarded_backward(p,A,B,C); exhaustive_interval_cases+=1
        for a,b,c in solutions(p,A,B,C):
            check(d[0]<=a<=d[1])
# Large-field adversarial witness; constant-space, no p-sized enumeration.
p=2**64-2**32+1
a=(p-1)//2;b=2;c=1
check((a*b+c)%p==0)
# Nonempty integer conclusion rules out a mere empty-interval artifact.
C=(1,2)
check(weak_backward(p,(b,b),C)==(-1,-1))
check(not weak_backward(p,(b,b),C)[0] <= a <= weak_backward(p,(b,b),C)[1])
check(guarded_backward(p,window(p),(b,b),C)==window(p))
large=dict(p=p,a=a,b=b,c=c,c_premise=C,ab_plus_c=a*b+c,weak_conclusion=weak_backward(p,(b,b),C))

# Sound rule instances for equality x=y, plus range facts X,Y.
rules=[('Rx','X',()),('Ry','Y',()),('E','Y',('X',)),('E','X',('Y',))]
obligations={'Rx':('X',),'Ry':('Y',)}
relation_cases=[];unsafe_new=0
for p in (7,11,17,31):
    for k in (0,1,2):
        for order in (('Rx','Ry'),('Ry','Rx')):
            removed=remove_cumulative(rules,obligations,order)
            check(len(removed)==1)
            original=equality_relation(p,k,set())
            after=equality_relation(p,k,removed)
            check(original==after)
            # Negative: separately proved redundancies do not compose.
            independently={c for c in order if all(provable(rules,f,{c}) for f in obligations[c])}
            check(independently=={'Rx','Ry'})
            unsafe=equality_relation(p,k,independently)
            check(len(unsafe-original)==p-k-1)
            unsafe_new+=len(unsafe-original)
            relation_cases.append(dict(p=p,k=k,order=order,kept=sorted(set(order)-removed),
                original_witnesses=len(original),unsafe_new_witnesses=len(unsafe-original)))

# Independent least-fixed-point oracle for randomly generated AND/OR graphs.
graphs=0;graph_queries=0
for _ in range(180):
    n=5; r=[]
    for j in range(rng.randrange(2,11)):
        r.append((f'c{j}',f'f{rng.randrange(n)}',tuple(f'f{v}' for v in
                  rng.sample(range(n),rng.randrange(3)))))
    for maskno in range(4):
        mask={s for s,_,_ in r if rng.randrange(3)==0}
        expected=least_facts(r,mask)
        for j in range(n):
            f=f'f{j}';check(provable(r,f,mask)==(f in expected));graph_queries+=1
    graphs+=1
cycle=[('E','X',('Y',)),('E','Y',('X',))]
check(not provable(cycle,'X',set()));check(not provable(cycle,'Y',set()))

# Multi-cell control: changing x alone is caught by equality; changing both
# escapes after both range checks were wrongly removed.
p=17;k=2;old=(1,1);attack=(3,3)
check((3,1) not in equality_relation(p,k,{'Rx','Ry'}))
check(attack in equality_relation(p,k,{'Rx','Ry'}))
check(attack not in equality_relation(p,k,set()))

# A variable name is not a range identity. Keep the stronger domain when
# deduplicating. This is a new synthetic control, not a reported Clap bug.
range_dominance_cases=0;range_bad_removals=0
for p in (7,11,17):
    W=window(p)
    intervals=list(combinations_with_replacement(range(W[0],W[1]+1),2))
    for narrow,wide in product(intervals,repeat=2):
        if not inside(narrow,wide): continue
        original={x for x in range(p) if narrow[0] <= signed(x,p) <= narrow[1]
                  and wide[0] <= signed(x,p) <= wide[1]}
        kept_narrow={x for x in range(p) if narrow[0] <= signed(x,p) <= narrow[1]}
        check(original==kept_narrow);range_dominance_cases+=1
        if narrow != wide:
            kept_wide={x for x in range(p) if wide[0] <= signed(x,p) <= wide[1]}
            check(bool(kept_wide-original));range_bad_removals+=1

out=dict(status='PASS_PREREQUISITE_AND_NEGATIVE_CONTROLS_ONLY',seed=SEED,checks=checks,
 weak_singleton_cases=weak_cases,weak_unsound_cases=len(weak_failures),
 weak_examples=weak_failures[:12],goldilocks_counterexample=large,
 guarded_cases=strong_cases,concrete_solutions_checked=concrete_solutions,
 strict_refinement_cases=refinements,relation_cases=relation_cases,
 exhaustive_interval_cases=exhaustive_interval_cases,
 unsafe_extra_witness_instances=unsafe_new,graphs=graphs,graph_queries=graph_queries,
 multi_cell_attack=dict(original=old,attack=attack,p=p,k=k),
 range_dominance_cases=range_dominance_cases,range_weaker_only_negative_cases=range_bad_removals,
 elapsed_s=time.perf_counter()-t0,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 cpu_affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),hardware=platform.uname()._asdict(),
 limits=dict(cpu_s=40,alarm_s=45,address_space_bytes=256*1024**2,estimated_memory_bytes=64*1024**2),
 source_hashes={name:hashlib.sha256((BASE/name).read_bytes()).hexdigest()
 for name in ('candidate.py','reference.py','run.py')},
 native_checks_removed=0,verified_full_stack_proofs=0,proved_positions=0,
 limitations=['Not author implementation or theorem reproduction; weak rule is an explicit negative control.',
 'Tiny scalar relations and symbolic fact graphs only, no native IR/LogUp/masks/receipt executed.',
 'Whole native timing, redundancy fraction, privacy/soundness and GPU compatibility unmeasured.'])
(BASE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k in ('status','checks','elapsed_s','max_rss_kib',
 'weak_unsound_cases','guarded_cases','concrete_solutions_checked','graph_queries','strict_refinement_cases')}))
