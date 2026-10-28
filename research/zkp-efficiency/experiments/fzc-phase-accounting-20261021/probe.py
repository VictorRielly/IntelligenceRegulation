"""Bounded differential and negative tests of an accounting proposal, no proof."""
import copy,json,random,resource,time
from pathlib import Path
from accounting import summarize,critical_path,family_thread_wall
from reference import replay,path_enumeration,selected_ticks
ROOT=Path(__file__).resolve().parent
SEED=202610210120
rng=random.Random(SEED);checks=0;controls=[];start=time.monotonic()
def check(x):
    global checks
    assert x
    checks+=1
def span(i,p,a,b,phase='other',role='none',thread=0,size=0):
    return dict(id=i,parent=p,thread=thread,clock='host_monotonic_ns',start_ns=a,end_ns=b,
                phase=phase,role=role,outcome='success',requested_bytes=size)

# Deliberately artificial integer timing, preserving source control-flow order.
fixed=[span(0,None,0,200,'attempt'),span(1,0,0,60,'constructor'),
 span(2,1,0,5,'other'),span(3,1,5,10,'module'),span(4,1,10,60,'build'),
 span(5,4,12,18,'host_alloc','round_fallback_pin',size=96),span(6,5,13,17,'driver'),
 span(7,4,20,28,'module'),span(8,4,30,36,'device_alloc','device_part'),
 span(9,4,38,44,'host_alloc','round_mapped_pin',size=104),span(10,9,39,41,'driver'),
 span(11,9,42,43,'host_map','round_mapped_pin'),span(12,4,50,58,'sync'),
 span(13,0,60,170,'masked_protocol'),span(14,13,60,100,'round'),
 span(15,14,60,64,'driver'),span(16,14,64,100,'poll'),
 span(17,13,100,140,'tail'),span(18,17,100,104,'device_alloc','tail_device_pack',size=10752),
 span(19,17,108,112,'host_alloc','tail_pin',size=10752),span(20,17,112,114,'copy'),
 span(21,17,114,128,'sync'),span(22,17,128,132,'other'),
 span(23,17,132,135,'host_free','tail_pin'),span(24,17,135,140,'device_free','tail_device_pack'),
 span(25,13,140,150,'round'),span(26,0,170,172,'report'),
 span(27,0,175,195,'cleanup'),span(28,27,178,183,'host_free','round_fallback_pin'),
 span(29,27,183,190,'host_free','round_mapped_pin'),span(30,27,190,195,'device_free','device_sums')]
got=summarize(fixed);check(got['exclusive_by_id_ns']==replay(fixed));check(got['sum_thread_wall_ns']==200)
check(sum(got['inclusive_ns'].values())>200);controls.append('inclusive_children_double_count')
legacy={'body_to_report':160,'enclosing_attempt':200,'outside_body_to_report':40,
        'tail_timer_before_local_drop':32,'tail_scope_through_local_drop':40,
        'tail_local_drop_omission':8,'unit':'synthetic integer ns; never native timing'}
check(legacy['tail_scope_through_local_drop']-legacy['tail_timer_before_local_drop']==8)
controls.append('pre_report_and_tail_drop_omission')
check(family_thread_wall(fixed,{5,6,9,10,11,19})==16)
check(sum(s['end_ns']-s['start_ns'] for s in fixed if s['id'] in {5,6,9,10,11,19})==23)
controls.append('nested_allocator_wrapper_driver_counted_once')
check(got['exclusive_ns']['host_alloc']==9)
controls.append('allocation_exclusive_label_alone_misses_nested_driver')

# One host thread is the permitted execution device. These are simulated thread
# ordinals, not spawned workers. The independent oracle replays each integer tick.
cases=1500;max_nodes=0
for case in range(cases):
    base=0 if case%2 else 2**60+case*100
    trace=[]
    def grow(parent,a,b,depth,thread):
        i=len(trace);trace.append(span(i,parent,a,b,rng.choice(['other','constructor','round','tail','host_alloc','driver']),thread=thread))
        if depth==0 or b-a<2:return
        cursor=a
        for _ in range(rng.randrange(4)):
            lo=rng.randint(cursor,b);hi=rng.randint(lo,b)
            grow(i,lo,hi,depth-1,thread);cursor=hi
    for thread in range(1+case%3):grow(None,base,base+rng.randint(1,64),4,thread)
    max_nodes=max(max_nodes,len(trace))
    rng.shuffle(trace)
    got_random=summarize(trace);check(got_random['exclusive_by_id_ns']==replay(trace))
    check(sum(got_random['exclusive_ns'].values())==got_random['sum_thread_wall_ns'])
    shifted=copy.deepcopy(trace)
    for s in shifted:s['start_ns']+=17;s['end_ns']+=17
    check(summarize(shifted)['exclusive_by_id_ns']==got_random['exclusive_by_id_ns'])
    selected={s['id'] for s in trace if rng.randrange(3)==0}
    check(family_thread_wall(trace,selected)==selected_ticks(trace,selected))

# Mutated trace controls must be rejected, rather than quietly made into clocks.
def reject(name,fn):
    x=copy.deepcopy(fixed);fn(x)
    try:summarize(x)
    except ValueError:controls.append(name);check(True)
    else:raise AssertionError(name)
reject('mixed_gpu_clock',lambda x:x[5].update(clock='cuda_event_ms'))
reject('floating_timestamp',lambda x:x[5].update(start_ns=12.0))
reject('duplicate_id',lambda x:x[5].update(id=4))
reject('orphan',lambda x:x[5].update(parent=999))
reject('negative_duration',lambda x:x[5].update(end_ns=11))
reject('cross_thread_parent',lambda x:x[5].update(thread=1))
reject('outside_parent',lambda x:x[5].update(start_ns=9))
reject('overlapping_siblings',lambda x:x[7].update(start_ns=16))
reject('zero_duration_parent_cycle',lambda x:(x.append(span(88,89,20,20)),x.append(span(89,88,20,20))))
reject('unknown_private_label',lambda x:x[5].update(phase='private_value'))
reject('arbitrary_payload',lambda x:x[5].update(payload='forbidden'))
reject('unknown_outcome',lambda x:x[5].update(outcome='private_refusal_message'))
reject('negative_size',lambda x:x[5].update(requested_bytes=-1))
reject('two_roots_same_thread',lambda x:x.append(span(99,None,0,200)))
failed=copy.deepcopy(fixed);failed[0]['outcome']='infrastructure_error';failed[5]['outcome']='infrastructure_error'
check(summarize(failed)['sum_thread_wall_ns']==200);controls.append('failed_attempt_stays_charged')
parallel=copy.deepcopy(fixed)
for s in fixed:
    z=copy.deepcopy(s);z['id']+=100;z['parent']=None if z['parent'] is None else z['parent']+100;z['thread']=1;parallel.append(z)
check(summarize(parallel)['sum_thread_wall_ns']==400);controls.append('parallel_thread_wall_is_not_elapsed')

# Same allocation API time, different dependencies: observed fractions cannot
# establish a causal saving, even with an exact host interval partition.
overlap=[dict(id='alloc',deps=[],duration=8,role='alloc'),dict(id='gpu',deps=[],duration=20,role='work'),
         dict(id='join',deps=['alloc','gpu'],duration=10,role='work')]
serial=[dict(id='alloc',deps=[],duration=8,role='alloc'),dict(id='gpu',deps=['alloc'],duration=20,role='work'),
        dict(id='join',deps=['gpu'],duration=2,role='work')]
paths={}
for name,tasks in [('overlap',overlap),('serial',serial)]:
    before=critical_path(tasks);after=critical_path(tasks,('alloc',))
    check(before==path_enumeration(tasks));check(after==path_enumeration(tasks,('alloc',)))
    paths[name]={'before':before,'after_free_allocation_deletion':after,'saved':before-after,'allocation_api_duration':8}
check(paths['overlap']['saved']==0);check(paths['serial']['saved']==8);controls.append('same_api_fraction_different_causal_saving')
for c in range(400):
    tasks=[]
    for i in range(1+rng.randrange(10)):
        deps=[j for j in range(i) if rng.randrange(5)==0]
        tasks.append(dict(id=i,deps=deps,duration=rng.randrange(15),role='alloc' if rng.randrange(4)==0 else 'work'))
    check(critical_path(tasks)==path_enumeration(tasks));check(critical_path(tasks,('alloc',))==path_enumeration(tasks,('alloc',)))

(ROOT/'synthetic-trace.json').write_text(json.dumps(fixed,indent=2)+'\n')
(ROOT/'synthetic-summary.json').write_text(json.dumps(summarize(fixed),indent=2)+'\n')
result=dict(status='PASS_SYNTHETIC_ACCOUNTING_ONLY',seed=SEED,checks=checks,differential_traces=cases,
            max_trace_nodes=max_nodes,random_dags=400,negative_control_types=len(controls),controls=controls,
            illustrative_legacy_gaps=legacy,critical_path_counterexample=paths,
            wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            threads=1,estimated_memory_mib=32,native_cuda_executed=False,new_verified_full_stack_proofs=0,
            limitations=['No actual allocation clocks','Integer tick oracle tests artificial intervals only',
                         'Metadata partition is not CPU utilization or GPU execution time','No native instrumentation adapter or causal graph',
                         'No proof/mask/transcript/receipt/verification executed'])
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
