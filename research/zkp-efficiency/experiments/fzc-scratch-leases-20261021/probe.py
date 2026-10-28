import itertools, json, random, resource, time
from pathlib import Path
from lease_model import Pool, Key, Ticket, Refused, U64
from reference import fresh_result, fresh_count, chain

ROOT = Path(__file__).resolve().parent
SEED = 202610210118
rng = random.Random(SEED)
checks = cases = messages = 0
controls = []
start = time.monotonic()

def check(condition):
    global checks
    checks += 1
    assert condition

def refused(label, f):
    try:
        f()
    except Refused:
        controls.append(label)
    else:
        raise AssertionError(label)

pool = Pool()
for device, context, stream, degree, supp, rounds in itertools.product(range(2), range(2), range(2), [4, 5], [False, True], [1, 2, 7]):
    cases += 1
    key = Key(device, context, stream, 'mapped', 2)
    lease = pool.acquire(key, 2 * (degree + 1) + 1)
    h_ref = h_new = b'synthetic-FZC-storage-only'
    for round_index in range(rounds):
        payload = [rng.getrandbits(64) for _ in range(2 * (degree + 1))]
        # Include coordinate/padding adversaries, not only random payloads.
        if round_index == 0:
            payload[0:4] = [0, 1, U64, 1 << 63]
        lease.submit(payload)
        check(lease.poll() is None)
        lease.publish(lease.ticket)
        got = lease.consume()
        check(got == fresh_result(payload))
        check(len(got) == 2 * (degree + 1))
        h_ref, h_new = chain(h_ref, fresh_result(payload)), chain(h_new, got)
        check(h_ref == h_new)
        messages += 1
    # Message publication never authorizes release without completion.
    refused('no_completion', lambda: pool.release(lease, None))
    pool.release(lease, lease.completed_event(lease.ticket))
    refused('use_after_release', lambda: lease.submit([0] * (lease.count - 1)))

# Exhaustive changed-degree histories expose stale flag offsets. Even if the
# old payload at the new flag position equals 1, active clearing defeats it.
boundary_cases = 0
for old_degree, new_degree, old_flag in itertools.product([4, 5, 8], [4, 5, 8], [0, 1, 2, U64]):
    p = Pool(); key = Key(0, 9, 0, 'mapped', 2)
    a = p.acquire(key, 2 * (old_degree + 1) + 1)
    a.storage.words[:] = [1] * len(a.storage.words)
    a.storage.words[a.count - 1] = old_flag
    old_ticket = a.ticket
    p.release(a, a.completed_event(a.ticket))
    b = p.acquire(key, 2 * (new_degree + 1) + 1)
    check(all(v == 0 for v in b.storage.words[:b.count]))
    payload = [rng.getrandbits(64) for _ in range(b.count - 1)]
    b.submit(payload); check(b.poll() is None)
    refused('stale_writer', lambda: b.publish(old_ticket))
    b.publish(b.ticket); check(b.consume() == fresh_result(payload))
    refused('stale_completion', lambda: p.release(b, old_ticket))
    p.release(b, b.completed_event(b.ticket)); boundary_cases += 1

p = Pool(); key = Key(0, 0, 0, 'mapped', 2)
a = p.acquire(key, 11); a.submit([7] * 10); a.publish(a.ticket)
old_event = a.completed_event(a.ticket)
a.consume(); a.submit([8] * 10)
refused('earlier_round_completion', lambda: p.release(a, old_event))
refused('completion_before_publish', lambda: a.completed_event(a.ticket))
a.publish(a.ticket)
b = p.acquire(key, 11)
check(a.ticket.allocation != b.ticket.allocation)  # in-flight storage not reused
wrong = Ticket(a.ticket.allocation, a.ticket.generation, Key(0, 1, 0, 'mapped', 2))
refused('wrong_context_completion', lambda: p.release(a, wrong))
p.quarantine(a)
c = p.acquire(key, 11); check(c.ticket.allocation != a.ticket.allocation)
refused('quarantined_read', lambda: a.poll())
refused('mapping_acquisition_failure', lambda: p.acquire(key, 11, fail=True))
refused('fallback_acquisition_failure', lambda: p.acquire(Key(0,0,0,'fallback',0), 10, fail=True))
c.seq = U64
refused('sequence_wrap', lambda: c.submit([0] * 10))
refused('invalid_length', lambda: p.acquire(key, 0))
prefix_pool=Pool()
large=prefix_pool.acquire(Key(0,0,0,'fallback',0),12)
prefix_pool.release(large,large.completed_event(large.ticket))
small=prefix_pool.acquire(Key(0,0,0,'fallback',0),10)
check(len(small.storage.words)==12 and small.count==10)
device_source=list(range(10))
check(len(small.storage.words)>len(device_source))
check(len(small.storage.words[:small.count])==len(device_source))
controls.append('unsafe_capacity_sized_copy_overreads_smaller_device_result')
limited = Pool(max_words=16)
held = limited.acquire(key, 11)
limited.quarantine(held)
refused('quarantine_budget_exhausted', lambda: limited.acquire(key, 11))
# Roles and host flags must remain distinct even when capacities happen to fit.
d = p.acquire(Key(0,0,0,'fallback',0), 10)
check(d.ticket.allocation != b.ticket.allocation)

# Deliberately unsafe controls demonstrate why equality-polling alone fails.
memory = [17] * 13; memory[10] = 1
check(memory[10] == 1 and tuple(memory[:10]) != tuple([99] * 10))
controls.append('unsafe_no_clear_accepts_stale_matching_one')
memory = [1] * 13; memory[12] = 27
check(memory[10] == 1)  # changed degree reads old coordinate, not old flag
controls.append('unsafe_old_flag_offset_clear_misses_new_offset')
check(a.published and a.closed and a.storage.poisoned)
controls.append('published_message_is_not_completion')

traces = []
for count in [1, 2, 4, 8, 32, 64, 256]:
    attempts = [(5, True, 5, True)] * count
    baseline = fresh_count(attempts)
    p = Pool()
    for degree, supp, tail_log, mapped in attempts:
        for role, flags, size in [('fallback',0,2*(degree+1)), ('mapped',2,2*(degree+1)+1), ('tail',0,(20+int(supp))*(1<<tail_log)*2)]:
            a = p.acquire(Key(0,0,0,role,flags), size)
            p.release(a, a.completed_event(a.ticket))  # real last-use fence required
    check(p.allocations == 3)
    check(baseline['allocations'] == 3 * count)
    traces.append({'attempts':count,'baseline':baseline,'lease_allocations':p.allocations,'lease_mapping_calls':1,'retained_host_bytes':sum(len(s.words) for s in p.entries)*8,'peak_host_bytes':p.peak_words*8,'conditional_allocation_reduction':baseline['allocations']-p.allocations})

varying=[(4,False,5,True),(5,True,6,True),(5,False,5,True),(4,True,6,True)]*8
p=Pool()
for degree,supp,tail_log,mapped in varying:
    for role,flags,size in [('fallback',0,2*(degree+1)),('mapped',2,2*(degree+1)+1),('tail',0,(20+int(supp))*(1<<tail_log)*2)]:
        a=p.acquire(Key(0,0,0,role,flags),size)
        p.release(a,a.completed_event(a.ticket))
varying_trace={'attempts':32,'baseline':fresh_count(varying),'lease_allocations':p.allocations,'lease_cumulative_allocated_bytes':p.cumulative_allocated_words*8,'lease_peak_host_bytes':p.peak_words*8,'lease_retained_host_bytes':sum(len(s.words) for s in p.entries)*8}
check(varying_trace['lease_allocations']==6)
check(varying_trace['lease_cumulative_allocated_bytes']==32112)
check(varying_trace['lease_retained_host_bytes']==21704)
check(varying_trace['lease_peak_host_bytes']==31944)
independent=json.loads((ROOT/'audit/independent_audit.json').read_text())['counts']
check(varying_trace['baseline']['cumulative_requested_bytes']==independent['baseline_cumulative_bytes'])
check(varying_trace['lease_allocations']==independent['bounded_growth_cache_native_allocation_events'])
check(varying_trace['lease_cumulative_allocated_bytes']==independent['bounded_growth_cache_cumulative_allocated_bytes'])
result = {'status':'PASS_SYNTHETIC_STORAGE_ONLY','seed':SEED,'checks':checks,'cases':cases,'messages':messages,'changed_shape_cases':boundary_cases,'negative_control_types':sorted(set(controls)),'negative_control_events':len(controls),'traces':traces,'varying_trace':varying_trace,'wall_seconds':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'scope':'No CUDA, native FZC, masker, PCS, proof, verifier or device memory-order validation. Completion is an external oracle assumption; physical allocation failure behavior not reproduced.'}
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
