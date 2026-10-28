from pathlib import Path
import hashlib, itertools, json, random, resource, time
from retirement import Lease, Fence, Budget
from reference import physically_safe, reference_decision, schedules

ROOT = Path(__file__).resolve().parent
SEED = 202610210119
rng = random.Random(SEED)
t0 = time.monotonic()
checks = 0
def check(value, message):
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)

# Exhaustive cross-product. Uses are represented differently by the candidate
# (stream frontiers) and the reference (unique tokens). Include missing/failed
# event records, old generations, wrong contexts and incomplete per-stream fences.
cases = 0
decision_counts = {x: 0 for x in ['retire', 'hold', 'quarantine']}
for n_a, n_b in itertools.product(range(4), repeat=2):
    uses = [('a', i) for i in range(1, n_a+1)] + [('b', i) for i in range(1, n_b+1)]
    for done_a, done_b in itertools.product(range(n_a+1), range(n_b+1)):
        for mode, sealed, failed, poison in itertools.product(
                ['valid', 'unrecorded', 'record_failed', 'query_failed', 'old_generation', 'wrong_context'],
                [False, True], [False, True], [False, True]):
            lease = Lease(7, 3, 104)
            for stream, ticket in uses:
                lease.submit(stream, ticket)
            lease.closed, lease.failed, lease.poisoned = sealed, failed, poison
            valid = mode == 'valid'
            cert = Fence(8 if mode == 'wrong_context' else 7,
                         2 if mode == 'old_generation' else 3,
                         {'a': done_a, 'b': done_b},
                         success=mode not in ['record_failed', 'query_failed'],
                         recorded=mode != 'unrecorded')
            completed = {(s, i) for s, n in [('a', done_a), ('b', done_b)] for i in range(1, n+1)}
            observed = completed if valid else set()
            got = lease.decision([cert])
            want = reference_decision(uses, observed, sealed, failed, poison)
            check(got == want, ('differential', mode, uses, got, want))
            if got == 'retire':
                check(physically_safe(uses, completed, sealed, poison), 'unsafe retirement')
            decision_counts[got] += 1
            cases += 1

# Realistic source-order skeleton: mapped publication precedes last kernel use;
# fallback copy follows kernel completion on A. Stream B remains independent.
# Success cert on A covers mapped and fallback uses, never B automatically.
nodes = ['publish', 'kernel_done', 'copy_done', 'a_sync', 'b_done', 'b_sync', 'cleanup']
edges = [('publish','kernel_done'), ('kernel_done','copy_done'), ('copy_done','a_sync'), ('b_done','b_sync')]
interleavings = 0
early_counts = {'timeout_drop':0, 'published_flag':0, 'a_sync_only':0}
witnesses = {}
for order in schedules(nodes, edges):
    lease = Lease(7, 3, 104)
    lease.submit('a', 1); lease.submit('a', 2); lease.submit('b', 1)
    lease.closed = True; lease.failed = True
    completed, certs = set(), []
    for event in order:
        if event == 'kernel_done': completed.add('mapped_kernel')
        if event == 'copy_done': completed.add('fallback_copy')
        if event == 'b_done': completed.add('other_stream')
        if event == 'a_sync': certs.append(Fence(7,3,{'a':2}))
        if event == 'b_sync': certs.append(Fence(7,3,{'b':1}))
        if event == 'cleanup':
            got = lease.decision(certs)
            safe = physically_safe(['mapped_kernel','fallback_copy','other_stream'], completed, True)
            check(got != 'retire' or safe, ('schedule unsafe', order))
            for mutant, trigger in [('timeout_drop',True),('published_flag','publish' in order[:order.index('cleanup')]),('a_sync_only',any('a' in f.covered for f in certs))]:
                if trigger and not safe:
                    early_counts[mutant] += 1
                    witnesses.setdefault(mutant, order)
    interleavings += 1
for mutant, count in early_counts.items():
    check(count > 0, ('negative control not detected', mutant))

# Focused controls: early records, event-record failure followed by empty-event
# query SUCCESS, stale generations, wrong contexts, poisoned contexts, post-close
# submissions, failed frees, and proof refusal independent of safe cleanup.
controls = []
def control(name, good):
    check(good, name); controls.append(name)

lease = Lease(7,3,104); lease.submit('a',1); lease.submit('a',2); lease.closed=True
control('earlier_event_does_not_cover_later_copy', lease.decision([Fence(7,3,{'a':1})]) == 'hold')
control('unrecorded_event_query_success_ignored', lease.decision([Fence(7,3,{'a':2},recorded=False)]) == 'hold')
control('failed_event_record_query_success_ignored', lease.decision([Fence(7,3,{'a':2},success=False)]) == 'hold')
control('wrong_generation_ignored', lease.decision([Fence(7,2,{'a':2})]) == 'hold')
control('wrong_context_ignored', lease.decision([Fence(8,3,{'a':2})]) == 'hold')
lease.failed=True
control('failed_sync_does_not_retire', lease.decision([Fence(7,3,{'a':2},success=False)]) == 'quarantine')
control('late_successful_sync_can_retire_after_copy_error', lease.decision([Fence(7,3,{'a':2})]) == 'retire')
control('cleanup_does_not_turn_failed_attempt_into_proof', lease.failed)
lease.poisoned=True
control('poisoned_context_remains_quarantined', lease.decision([Fence(7,3,{'a':2})]) == 'quarantine')
try:
    lease.submit('a',3)
    control('submission_after_close_refused', False)
except ValueError:
    control('submission_after_close_refused', True)

# Capacity was reserved BEFORE launch, not checked for the first time on error.
# Failed frees remain charged. Persistent failures stop new admission; a cap
# bounds retained bytes but cannot guarantee forward progress or eventual release.
budget = Budget(3*104)
for i in range(3): control('admit_reserved_'+str(i), budget.admit(i,Lease(7,4,104,closed=True)))
control('quarantine_budget_admission_refused', not budget.admit(3,Lease(7,4,104,closed=True)))
control('failed_free_remains_charged', not budget.release(0,[],free_success=False) and len(budget.held)==3)
control('ambiguous_free_is_never_blindly_retried', not budget.release(0,[],free_success=True) and len(budget.held)==3)
control('successful_free_releases_reservation', budget.release(1,[]) and budget.bytes_held()==208)
control('readmission_after_release', budget.admit(3,Lease(7,4,104,closed=True)))
bound=Budget(4096); pending=Lease(7,4,104); pending.submit('a',1); pending.closed=True
control('pending_owner_admitted', bound.admit('pending',pending))
control('reservation_cannot_release_unrelated_empty_lease', not bound.release('pending',[]))
control('same_lease_double_reservation_refused', not bound.admit('duplicate',pending))
bound.poison(7)
control('poison_stops_context_readmission', not bound.admit('new',Lease(7,5,104)))
control('poison_blocks_release_even_with_fence', not bound.release('pending',[Fence(7,4,{'a':1})]))

# Deterministic mixed shapes and timeout/error outcomes. Payload equality is not
# tested here: only ownership metadata. Actual sizes come from degree4/5 mapped
# messages (88/104 B), fallback (80/96 B), and small synthetic tail (1024/2048 B).
trace=[]; held={}; budget=Budget(4096)
for attempt in range(64):
    size=rng.choice([88,104,80,96,1024,2048])
    admitted=budget.admit(attempt,Lease(7,4+attempt,size,closed=True))
    if admitted:
        held[attempt]=size
        if rng.randrange(3)==0:
            budget.release(attempt,[]); held.pop(attempt)
    check(sum(held.values()) == budget.bytes_held() <= 4096, 'budget differential')
    trace.append({'attempt':attempt,'size':size,'admitted':admitted,'held':sum(held.values())})

result={'status':'PASS_SYNTHETIC_RETIREMENT_ONLY','seed':SEED,'checks':checks,'differential_cases':cases,
        'decision_counts':decision_counts,'topological_interleavings':interleavings,
        'unsafe_control_schedules':early_counts,'counterexamples':witnesses,'controls':controls,
        'admission_trace':trace,'wall_seconds':time.monotonic()-t0,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'estimated_memory_mib':32,'threads':1,'native_cuda_executed':False,'new_verified_full_stack_proofs':0,
        'limitations':['trusted native fence adapter not implemented','not a CUDA memory-order model','operation completion is a conservative last-use upper bound, not confirmed post-flag memory access','error may enqueue assumptions are conservative','poisoned-context release not established','no proof/transcript/native timing']}
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['admission_trace','controls']}))
