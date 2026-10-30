"""Bounded single-CPU contract experiment; execute this authored file only."""
from pathlib import Path
import collections
import datetime
import hashlib
import itertools
import json
import os
import random
import resource
import signal
import sys
import time

resource.setrlimit(resource.RLIMIT_AS, (256 << 20, 256 << 20))
resource.setrlimit(resource.RLIMIT_CPU, (40, 40))
signal.alarm(45)
os.nice(19)
cpu = min(os.sched_getaffinity(0))
os.sched_setaffinity(0, {cpu})
for key in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS']:
    os.environ[key] = '1'
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import candidate as c
import reference as r

t0 = time.monotonic()
seed = 202610280130
rng = random.Random(seed)
counts = collections.Counter()
def check(ok, kind):
    counts[kind] += 1
    assert ok, (kind, counts[kind])

P, R = c.P, c.R
edges = sorted(set([0,1,2,255,256,65535,65536,(1<<31)-1,1<<31,
                   (1<<32)-1,1<<32,(1<<32)+1,(1<<63)-1,1<<63,
                   P-(1<<32),P-2,P-1,P,P+1,R-2,R-1]))
params = {k:c.prepare(k) for k in edges}
check(c.inverse_word(P) == pow(P,-1,R), 'word_inverse')
check(c.inverse_word(P) == (1<<32)+1, 'word_inverse')
borrow_hits = no_borrow_hits = 0
for a,k in itertools.chain(itertools.product(edges,repeat=2),
                          ((rng.getrandbits(64),rng.getrandbits(64)) for _ in range(12000))):
    p = params.get(k) or c.prepare(k)
    z = c.fixed_mul(a,p)
    check(z == r.product(a,k), 'general_fixed_multiplier')
    check(0 <= z < P, 'canonical_multiplier')
    b,bp = p
    check((a*b - ((a*bp)&(R-1))*P) % R == 0, 'low_word_cancellation')
    borrow = (a*b >> 64) < (((a*bp)&(R-1))*P >> 64)
    borrow_hits += borrow
    no_borrow_hits += not borrow

# Explicit supported-parameter guard controls, with only public constants.
guards = []
for n,bits,allowed in [(0x1FFFFFF900000001,64,True),((1<<62)+1,64,False),
                       (P,64,False),(17,64,False),(0x1FFFFFF900000001,40,False)]:
    try:
        c.friendly_guard(n,bits); actual=True
    except ValueError:
        actual=False
    check(actual == allowed, 'source_guard_contract')
    guards.append(dict(n=n,bits=bits,accepted=actual))

controls=[]
def reject(name, actual, expected, **kw):
    check(actual != expected, 'negative_control')
    controls.append(dict(name=name,actual=actual,expected=expected,**kw))

reject('omitted borrow correction', c.fixed_mul(1,c.prepare(1),wrong_borrow=True),1,a=1,k=1)
reject('wrong Montgomery sign', c.fixed_mul(1,(params[1][0],(-params[1][1])&(R-1))),1)
reject('lazy 2N even with general multiplier',c.lazy_butterfly_bypass(0,0,1),r.butterfly(0,0,1))
reject('lazy addition loses overflow',c.lazy_butterfly_bypass(P-1,P-1,1),r.butterfly(P-1,P-1,1))

ntts=[]
for log in [1,2,3,4,5,6]:
    n=1<<log
    root=pow(7,(P-1)//n,P)
    check(pow(root,n,P)==1 and pow(root,n//2,P)!=1, 'root_order')
    for label in ['zero','edge','random']:
        a = ([0]*n if label=='zero' else [edges[i%len(edges)]%P for i in range(n)]
             if label=='edge' else [rng.randrange(P) for _ in range(n)])
        z=c.transform(a,root)
        expected=r.dft(a,root)
        for x,y in zip(z,expected):check(x==y,'ntt_vs_independent_dft')
        for x,y in zip(c.transform(z,root,True),a):check(x==y,'inverse_roundtrip')
        for x,y in zip(c.transform(z,root,True),r.dft(z,root,True)):check(x==y,'inverse_vs_dft')
        ntts.append(dict(n=n,fixture=label,wire_sha256=hashlib.sha256(b''.join(x.to_bytes(8,'little') for x in z)).hexdigest()))
        if label=='random' and n>=4:
            reject('wrong root n'+str(n),c.transform(a,pow(root,-1,P)),expected)
            reject('wrong output order n'+str(n),list(reversed(z)),expected)
        # Independent Horner checks over a nonunit public coset (layout gate).
        coset=11
        scaled=[r.product(v,pow(coset,j,P)) for j,v in enumerate(a)]
        zz=c.transform(scaled,root)
        for i,v in enumerate(zz):
            x=coset*pow(root,i,P)%P
            check(v==sum(vj*pow(x,j,P) for j,vj in enumerate(a))%P,'coset_dft')

dot_rows=[]
max_ss=max_tt=0
for label in ['all-ones64','all-pminus1','alternating']+['random'+str(i) for i in range(32)]:
    a=([R-1]*16 if label=='all-ones64' else [P-1]*16 if label=='all-pminus1'
       else [0 if i%2 else P-1 for i in range(16)] if label=='alternating'
       else [rng.randrange(P) for _ in range(16)])
    b=([R-1]*16 if label=='all-ones64' else [P-1]*16 if label=='all-pminus1'
       else [P-1]*16 if label=='alternating' else [rng.randrange(P) for _ in range(16)])
    tt,ssmax,ttmax=c.dot_digits(a,b); max_ss=max(max_ss,ssmax);max_tt=max(max_tt,ttmax)
    total=sum(x*y for x,y in zip(a,b))
    check(sum(t<<(16*i) for i,t in enumerate(tt))==total,'byte_diagonal_reconstruction')
    lo,hi,top=c.dot_words(tt)
    check(lo+(hi<<64)+(top<<128)==total,'fixed_width_carry_reconstruction')
    check(top==total>>128,'top_carry_bound')
    check(c.dot_reduce(tt)==r.dot(a,b),'carry_aware_dot_reduction')
    if total>>128:
        reject('truncate dot16 '+label,c.dot_reduce(tt,truncate=True),r.dot(a,b),top128=total>>128)
    if label=='all-pminus1':
        wrong_lo,wrong_hi,wrong_top=c.dot_words(tt,omit_carry=True)
        reject('omit intermediate 16-bit carries',wrong_lo+(wrong_hi<<64)+(wrong_top<<128),total)
    dot_rows.append(dict(fixture=label,bits=total.bit_length(),top128=total>>128,max_s=ssmax,max_t=ttmax))

matrix_cases=[]
root16=pow(7,(P-1)//16,P)
factor128=pow(2,128,P)
unscale=c.prepare(pow(factor128,-1,P))
for label in ['zero','one','edge','random']:
    a=([0]*16 if label=='zero' else [1]*16 if label=='one'
       else [edges[i%len(edges)]%P for i in range(16)] if label=='edge'
       else [rng.randrange(P) for _ in range(16)])
    expected=r.dft(a,root16)
    natural=[None]*16
    scaled_outputs=[]
    for row in range(16):
        # The inspected NTT16 precompute uses bit-reversed row exponent and
        # a 2^128 factor. Map both explicitly; this is a CPU contract only.
        out_index=int(f'{row:04b}'[::-1],2)
        b=[pow(root16,out_index*j,P)*factor128%P for j in range(16)]
        tt,_,_=c.dot_digits(a,b)
        raw=c.dot_reduce(tt)
        z=c.fixed_mul(raw,unscale)
        check(z==expected[out_index],'scaled_digit_matrix_vs_dft')
        natural[out_index]=z
        scaled_outputs.append(raw)
    check(natural==expected,'scaled_matrix_output_permutation')
    if label in ['edge','random']:
        reject('omit matrix scaling '+label,scaled_outputs,[expected[int(f'{i:04b}'[::-1],2)] for i in range(16)])
        reject('omit matrix output permutation '+label,[natural[int(f'{i:04b}'[::-1],2)] for i in range(16)],expected)
    matrix_cases.append(dict(fixture=label,n=16,source_factor=128,output_mapping='bitreverse4 row -> natural output',wire_sha256=hashlib.sha256(b''.join(x.to_bytes(8,'little') for x in natural)).hexdigest()))

check(max_ss==8*16*255**2,'accumulator_bound')
check(max_tt==(7+256*8)*16*255**2,'accumulator_bound')
check(max_tt < 1<<31,'accumulator_bound')
check((7+256*8)*32*255**2 >= 1<<31,'accumulator_bound')

result=dict(status='PASS_SYNTHETIC_WORD_AND_LAYOUT_CONTRACT_ONLY',seed=seed,
    checks=sum(counts.values()),checks_by_kind=dict(counts),general_pairs=counts['general_fixed_multiplier'],
    borrow_hits=borrow_hits,no_borrow_hits=no_borrow_hits,guard_cases=guards,
    ntt_cases=ntts,dot_cases=dot_rows,matrix_cases=matrix_cases,negative_controls=controls,
    signed32_dot16_t_bound=max_tt,radix32_same_formula_exceeds_i32=True,
    elapsed_seconds=time.monotonic()-t0,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    cpu_affinity=[cpu],threads=1,estimated_memory_mib=64,address_space_cap_mib=256,cpu_cap_seconds=40,alarm_seconds=45,
    hardware=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown'),
    checked_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE/'candidate.py',HERE/'reference.py',HERE/'run.py']},
    device='CPU only; no accelerator',native_full_proofs=0,passes=0,proved_positions=0,context_length=None,
    witness_seconds=None,proof_seconds=None,serialization_seconds=None,verification_seconds=None,
    startup_seconds=None,startup_fraction=None,steady_proved_tokens_per_second=None,total_proved_tokens_per_second=None,
    scope='Both algorithms locally authored; general multiplier math, canonical radix2 and carry-aware dot16 contract only. No external code/PTX/GPU/native build, complete Tensor Core NTT, hiding pads/PCS/transcript/receipt or privacy acceptance. Checking clocks are not proving clocks.')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['ntt_cases','dot_cases','matrix_cases','negative_controls','guard_cases']},indent=2))
