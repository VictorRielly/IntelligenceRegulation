"""Separate oracle: polynomial convolution, saved fixtures and F17 enumeration.

No candidate/imported arithmetic or native prover executes in this audit.
"""
from pathlib import Path
import collections, datetime, hashlib, itertools, json, os, resource, signal, time
from decimal import Decimal

HERE=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));signal.alarm(59)
start=time.perf_counter();P=2**64-2**32+1
def plus(a,b): return tuple((x+y)%P for x,y in zip(a,b))
def times(a,b):
    c=[0]*3
    for i,x in enumerate(a):
        for j,y in enumerate(b): c[i+j]+=x*y
    return ((c[0]+7*c[2])%P,c[1]%P)
def eq(index,point):
    v=(1,0)
    for bit,z in zip(reversed(bin(index)[2:].zfill(len(point))),point):
        factor=z if bit=='1' else ((1-z[0])%P,-z[1]%P)
        v=times(v,factor)
    return v
def aggregate(xs):
    v=(0,0)
    for x in xs:v=plus(v,x)
    return v

result=json.loads((HERE/'result.json').read_text())
assert hashlib.sha256((HERE/'fixtures.json').read_bytes()).hexdigest()==result['fixture_sha256']
checks=0;words=0
for f in json.loads((HERE/'fixtures.json').read_text()):
    n,m,a=f['n'],f['m'],f['active'];r=f['r'];idx=f['index'];table=f['table']
    assert n==1<<len(r)
    weights=[eq(i,r) for i in range(n)]
    y=[aggregate(weights[i] for i in range(a) if idx[i]==j) for j in range(m)]
    assert y==[tuple(v) for v in f['out'][:-1]];checks+=m;words+=m
    claim=aggregate(times(weights[i],table[idx[i]]) for i in range(a))
    assert claim==tuple(f['out'][-1]);checks+=1
    assert aggregate(y)==aggregate(weights[:a]);checks+=1

# A complete enumeration: two private orderings have the SAME histogram.
# Their public evaluations differ for every F17 challenge except r=1/2.
distinguish=[];indistinguish=[]
for r in range(17):
    a=((1-r)*1+r*3)%17;b=((1-r)*3+r*1)%17
    (distinguish if a!=b else indistinguish).append(r)
assert indistinguish==[9] and len(distinguish)==16;checks+=17

# Binding omission witness: arithmetic with a substituted index is self-consistent;
# a diagnostic that compares to the ORIGINAL ordered witness rejects it.
r=3;t=[0,1,2,3];original=[1,3];substitute=[3,1]
def pf(v):
    y=[0]*4
    for i,w in enumerate([1-r,r]):y[v[i]]=(y[v[i]]+w)%17
    return y
y=pf(substitute);forged=sum(x*z for x,z in zip(y,t))%17
arithmetic_only=forged==sum(x*z for x,z in zip(y,t))%17
original_claim=sum(x*z for x,z in zip(pf(original),t))%17
assert arithmetic_only and forged!=original_claim;checks+=2

# Distinct terminal mutation detection in the independent diagnostic.
mut_y=y.copy();mut_y[3]=(mut_y[3]+1)%17
assert sum(x*z for x,z in zip(mut_y,t))%17!=forged
mut_t=t.copy();mut_t[1]+=1
assert sum(x*z for x,z in zip(y,mut_t))%17!=forged;checks+=2

# Independent count reconciliation against the owner's exact public counters.
account=json.loads((HERE/'accounting.json').read_text());h=account['H']
assert h['total_payload_bytes']==14401536*8
assert h['U8_reciprocal_payload_bytes']==1514*8192*8
assert sum(row['U8_queries'] for row in account['rows'])==11714560
assert h['U8_reciprocal_data_rows']+sum(h[k]//(8192*8) for k in ['exp_act_payload_bytes','three_table_payload_bytes','zero_sum_pair_payload_bytes','other_reserved_and_proximity_payload_bytes'])==1758
assert account['additional_saved_query_commitment_bytes']==0
assert account['illustrative_new_costs']['one_pushforward_if_lifted_to_current_row_width_bytes']==32*4096
ceiling=Decimal('171.578')/(Decimal('171.578')-Decimal('19.5'))
assert abs(float(ceiling)-account['phase_diagnostic']['idealized_ceiling_ratio'])<1e-12
checks+=7

drift=[]
for pin in json.loads((HERE/'native-pins.json').read_text()):
    assert hashlib.sha256((HERE/pin['capture']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
    if hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest()!=pin['sha256']:drift.append(pin['source'])

out=dict(status='PASS',checks=checks,pushforward_fp2_values=words,
    exhaustive_F17_permutation_challenges=17,distinguishing_challenges=16,degenerate_challenges=indistinguish,
    negative_controls={'substituted ordered witness passes unbound arithmetic but original binding rejects':True,'mutated pushforward terminal detected':True,'mutated table terminal detected':True},
    source_drift=drift,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    threads=1,scope='Independent polynomial-convolution re-evaluation and finite-field disclosure/binding diagnostics, not GKR/PCS soundness or native proof.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
