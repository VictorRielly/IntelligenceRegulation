#!/usr/bin/env python3
"""Bounded synthetic compatibility/filter experiment; no proof performance."""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time
from arithmetic import P, MASK, POWER2, candidate_mul, general_mul, reduce_words, root, shift_mul
import oracle

BASE = Path(__file__).resolve().parent
SEED = 2026101345
COUNTS = {}
CONTROLS = []
DIGEST = hashlib.sha256()


def count(name, n=1):
    COUNTS[name] = COUNTS.get(name, 0) + n


def same(a, b, name):
    assert a == b, name
    count(name)
    DIGEST.update(str(a).encode())


def negative(name, condition):
    assert condition, name
    CONTROLS.append(name)


def ntt(values, inverse=False, candidate=True, counters=None, wrong_root=False, skip_scale=False):
    a = list(values)
    n = len(a)
    assert n >= 1 and n & (n - 1) == 0
    log = n.bit_length() - 1
    mul = (lambda x, y: candidate_mul(x, y, counters)) if candidate else general_mul
    # Independent native algorithm port, not used by the direct oracle.
    for i in range(n):
        j = int(f'{i:0{log}b}'[::-1], 2) if log else 0
        if i < j:
            a[i], a[j] = a[j], a[i]
    for st in range(1, log + 1):
        half = 1 << (st - 1)
        w = root(st)
        if wrong_root and st == 3:
            w = pow(2, 24, P)
        if inverse:
            w = pow(w, P - 2, P)
        for begin in range(0, n, 2 * half):
            tw = 1
            for k in range(half):
                u, v = a[begin + k], mul(a[begin + k + half], tw)
                a[begin + k] = (u + v) % P
                a[begin + k + half] = (u - v) % P
                # Untimed table construction, not a claimed avoided cost.
                tw = tw * w % P
    if inverse and not skip_scale:
        scale = pow(n, P - 2, P)
        a = [mul(x, scale) for x in a]
    return a


def encode_zk(msg, pad, nn, candidate=True, coset=7, legacy_overlap=False):
    n = len(msg)
    assert n + len(pad) <= nn and nn % n == 0
    coeff = ntt(msg, inverse=True, candidate=candidate)
    out = coeff + [0] * (nn - n)
    if legacy_overlap:
        out = [(coeff[i] - pad[i]) % P if i < n and i < len(pad) else coeff[i] if i < n else pad[i-n] if i < n+len(pad) else 0 for i in range(nn)]
    else:
        for i, v in enumerate(pad):
            out[i] = (out[i] - v) % P
            out[n+i] = v
    # Coset multiplications are retained general multiplications.
    out = [general_mul(x, pow(coset, i, P)) for i, x in enumerate(out)]
    return ntt(out, candidate=candidate)


def accounting(log, first_stage=1):
    n = 1 << log
    stages = []
    for st in range(first_stage, log + 1):
        half = 1 << (st - 1)
        eligible_tw = min(half, 32)
        repeats = n // (2 * half)
        stages.append({'stage': st, 'unique_twiddles': half, 'eligible_twiddles': eligible_tw,
                       'butterflies': n//2, 'eligible_calls': eligible_tw*repeats,
                       'identity_calls': repeats, 'nonidentity_shift_calls': (eligible_tw-1)*repeats})
    baseline = len(stages) * n // 2
    eligible = sum(s['eligible_calls'] for s in stages)
    return {'log_n': log, 'n': n, 'first_stage': first_stage, 'baseline_butterfly_gl_mul_calls': baseline,
            'eligible_calls': eligible, 'identity_calls': sum(s['identity_calls'] for s in stages),
            'nonidentity_shift_calls': sum(s['nonidentity_shift_calls'] for s in stages),
            'general_calls_remaining': baseline-eligible, 'eligible_call_fraction': eligible/baseline if baseline else 0,
            'inverse_scale_calls_separately_eligible': n if log else 0, 'stages': stages}


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*1024*1024, 512*1024*1024))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    start = time.monotonic()
    rng = random.Random(SEED)
    # All 192 possible public exponents, boundary values and random canonical words.
    vals = [0,1,P-1,P-2, (1<<32)-1, 1<<32, (1<<32)+1, 1<<63, (1<<63)-1]
    vals += [rng.randrange(P) for _ in range(192)]
    for e in range(192):
        for a in vals:
            same(shift_mul(a,e), a*pow(2,e,P)%P, 'shift_integer_checks')
    for _ in range(4096):
        lo, hi = rng.getrandbits(64), rng.getrandbits(64)
        same(reduce_words(lo,hi), (lo+(hi<<64))%P, 'native_reducer_checks')
        a,b=rng.randrange(P),rng.randrange(P)
        same(candidate_mul(a,b),a*b%P,'general_fallback_checks')
    same(pow(2,96,P), P-1, 'power2_order_checks')
    same(pow(2,192,P), 1, 'power2_order_checks')
    for divisor in [96,64]:
        assert pow(2,divisor,P)!=1
        count('power2_exact_order_checks')
    # Full native max-log12 table and stage-major stride/prefix conformance.
    maxlog=12
    tables=[]
    for inverse in [False,True]:
        w=root(maxlog)
        if inverse: w=pow(w,P-2,P)
        table=[1]
        for _ in range((1<<(maxlog-1))-1): table.append(table[-1]*w%P)
        tables.append(table)
        for st in range(1,maxlog+1):
            half=1<<(st-1);stride=1<<(maxlog-st);eligible=0
            for k in range(half):
                w0=table[k*stride]
                ws=pow(7,(P-1)//(1<<st),P)
                if inverse:ws=pow(ws,P-2,P)
                same(w0,pow(ws,k,P),'stage_major_native_checks')
                expected=k%(1<<max(0,st-6))==0
                same(w0 in POWER2,expected,'eligibility_checks')
                eligible+=w0 in POWER2
                for a in [0,P-1,rng.randrange(P)]:
                    same(candidate_mul(a,w0),a*w0%P,'native_twiddle_arithmetic_checks')
            same(eligible,min(half,32),'unique_count_checks')
    # Large lengths are algebraic/sample counts, never materialized transforms.
    for st in range(13,33):
        for inverse in [False,True]:
            w=root(st)
            if inverse:w=pow(w,P-2,P)
            step=1<<(st-6)
            for j in range(32):
                same(pow(w,j*step,P) in POWER2,True,'large_eligible_samples')
                same(pow(w,j*step+1,P) in POWER2,False,'large_ineligible_samples')
    for log in range(0,10):
        n=1<<log
        fixtures=[[0]*n,[P-1]*n,[(i*7919+13)%P for i in range(n)], [rng.randrange(P) for _ in range(n)]]
        for a in fixtures:
            stats={}
            f=ntt(a,counters=stats)
            same(f,ntt(a,candidate=False),'baseline_forward_checks')
            inv=ntt(f,inverse=True)
            same(inv,a,'roundtrip_checks')
            if log <=7:
                same(f,oracle.dft(a),'independent_forward_checks')
                same(ntt(a,inverse=True),oracle.dft(a,inverse=True),'independent_inverse_checks')
            cost=accounting(log)
            same(stats.get('identity',0)+stats.get('shift_mul',0),cost['eligible_calls'],'runtime_count_checks')
            same(stats.get('fallback_mul',0),cost['general_calls_remaining'],'runtime_count_checks')
    # Row RS zero-padding and coset evaluation by independent Horner.
    for n in [1,2,4,8,16,32]:
        coeff=[rng.randrange(P) for _ in range(n)]
        nn=4*n
        f=ntt(coeff+[0]*(nn-n))
        same(f,[oracle.eval_poly(coeff,pow(root(nn.bit_length()-1),i,P)) for i in range(nn)],'rs_encode_checks')
        for q in sorted({0,1,n-1,n,n+1,2*n+1}):
            msg=[rng.randrange(P) for _ in range(n)];pad=[rng.randrange(P) for _ in range(q)]
            f=encode_zk(msg,pad,nn)
            same(f,encode_zk(msg,pad,nn,candidate=False),'hiding_baseline_checks')
            same(f,oracle.hiding_row(msg,pad,nn),'hiding_lagrange_checks')
            count('hiding_output_values',nn)
    # Decisive correctness controls and input/refusal boundary controls.
    a=[rng.randrange(P) for _ in range(16)]
    f=ntt(a)
    negative('paper_root_substitution',ntt(a,wrong_root=True)!=oracle.dft(a))
    negative('wrong_inverse_scale',ntt(f,inverse=True,skip_scale=True)!=a)
    negative('bit_reversed_output', [f[int(f'{i:04b}'[::-1],2)] for i in range(16)]!=oracle.dft(a))
    negative('truncated_u64_shift',((P-1)<<48 & MASK)!=shift_mul(P-1,48))
    negative('dropped_third_limb',reduce_words(0,((P-1)<<31)&MASK)!=shift_mul(P-1,95))
    negative('wrong_exponent_sign',shift_mul(P-1,120)!=shift_mul(P-1,24))
    msg=[rng.randrange(P) for _ in range(4)]; pad=[rng.randrange(P) for _ in range(7)]
    f=encode_zk(msg,pad,16)
    negative('legacy_q_gt_n_overlap',encode_zk(msg,pad,16,legacy_overlap=True)!=f)
    negative('pad_mutation',encode_zk(msg,pad[:-1]+[(pad[-1]+1)%P],16)!=f)
    negative('wrong_coset',encode_zk(msg,pad,16,coset=11)!=f)
    negative('wrong_root_direction',ntt(a,inverse=True)!=oracle.dft(a))
    negative('noneligible_uses_general',pow(root(7),1,P) not in POWER2)
    for name, call in [('noncanonical_input',lambda:shift_mul(P,3)),('exponent_out_of_range',lambda:shift_mul(1,192)),('oversize_root',lambda:root(33)),('nonpower_length',lambda:ntt([1]*3))]:
        try:call()
        except AssertionError:CONTROLS.append(name)
        else:raise AssertionError(name)
    rows=[accounting(log) for log in [6,10,12,16,20,24,28,32]]
    # Existing zero-pad skip must be subtracted from any claimed saving.
    pad_skip=[accounting(log,first_stage=rb+1) for log in [12,16,20] for rb in [2,3]]
    elapsed=time.monotonic()-start
    cpu=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown')
    result={'run_id':'20261013T022555Z-d570e67c','cycle':'0045','status':'pass','seed':SEED,
            'counts':COUNTS,'controls':CONTROLS,'control_count':len(CONTROLS),
            'root_exponents':{str(s):POWER2.get(root(s)) for s in range(7)},
            'cost_rows':rows,'existing_zero_pad_skip_rows':pad_skip,
            'elapsed_seconds':elapsed,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'hardware':{'device':'CPU only','cpu':cpu,'threads':1,'nice':os.getpriority(os.PRIO_PROCESS,0),'affinity':sorted(os.sched_getaffinity(0)),'python':platform.python_version()},
            'resource_limits':{'wall_seconds':59,'cpu_seconds':59,'address_space_mib':512,'estimated_memory_mib':32},
            'digest_sha256':DIGEST.hexdigest(),
            'code_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in BASE.glob('*.py')},
            'proof_accounting':{'accepted_complete_private8b_proofs':0,'countable_tokens':0,'context_length':None,'passes':0,'device':'CPU only','steady_state_tokens_per_s':None,'total_workload_tokens_per_s':None,'startup_seconds':None,'startup_fraction':None,'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'independent_verification_seconds':None,'proof_latency_seconds':None,'proof_lag_seconds':None,'pipeline_drain_seconds':None,'prefill':'none','resident_passes':'none','decode':'none'},
            'limits':['Python u64 CUDA model, no compiled/native/GPU proof or timing','Native generator7/order/scales/coset and exact pads preserved; no masks/RNG changed','Full stages inspected through12;13..32 algebraic classification plus samples only','No total-stack affected-phase fractions or accepted8B clocks; operation fraction is not time']}
    (BASE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    (BASE/'cost-accounting.json').write_text(json.dumps({'rows':rows,'existing_zero_pad_skip_rows':pad_skip},indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['cost_rows','existing_zero_pad_skip_rows','code_hashes']},indent=2))


if __name__=='__main__':main()
