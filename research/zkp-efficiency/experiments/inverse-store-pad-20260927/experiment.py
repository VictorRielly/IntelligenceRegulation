#!/usr/bin/env python3
"""CPU-only inverse-NTT final-store fusion oracle and source-address ledger.

The candidate is a scalar transcription of a possible CUDA last-store mapping.
It does not compile or execute a GPU kernel. All inputs are synthetic.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

P = (1 << 64) - (1 << 32) + 1
SEED = 2026092712
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def rev(x, bits):
    r = 0
    for _ in range(bits):
        r = (r << 1) | (x & 1)
        x >>= 1
    return r


def root(n):
    return pow(7, (P - 1) // n, P)


def inverse_staged_raw(msg):
    """Current CUDA p1/p2 mathematical stage split, before final 1/n store."""
    n = len(msg)
    bits = n.bit_length() - 1
    a = [msg[rev(i, bits)] for i in range(n)]
    boundary = min(bits, 12)
    for st in range(1, bits + 1):
        half = 1 << (st - 1)
        wi = pow(root(half * 2), P - 2, P)
        tw = [pow(wi, j, P) for j in range(half)]
        for b in range(0, n, half * 2):
            for j in range(half):
                u, v = a[b+j], a[b+j+half] * tw[j] % P
                a[b+j], a[b+j+half] = (u+v) % P, (u-v) % P
        if st == boundary:
            p1 = list(a)
    return a, p1, ('p1' if bits <= 12 else 'p2')


def direct_inverse(msg):
    n = len(msg)
    w = root(n)
    scale = pow(n, -1, P)
    return [sum(msg[j] * pow(w, (-i*j) % n, P) for j in range(n)) * scale % P
            for i in range(n)]


def baseline(coef, pads, h, nn):
    """Independent materialized polynomial: f + (X^n - 1)g, then coset."""
    n, q = len(coef), len(pads)
    a = [0] * nn
    a[:n] = coef
    for j, v in enumerate(pads):
        a[j] = (a[j] - v) % P
        a[n+j] = (a[n+j] + v) % P
    return [v * pow(h, i, P) % P for i, v in enumerate(a)]


def final_store(raw, pads, h, nn, poison=-7, bug=None):
    """Unique p1/p2 block ownership, writing into independent coef2 storage."""
    n, q = len(raw), len(pads)
    pw = n + q
    nt = max(1, n // 4096)
    jwidth = n // nt
    out = [poison] * nn
    owners = [0] * pw
    scratch_before = tuple(raw)
    scale = pow(n, -1, P)
    for tile in range(nt):
        for k in range(4096 if nt > 1 else n):
            t, jj = divmod(k, jwidth)
            i = t * 4096 + tile * jwidth + jj if nt > 1 else k
            v = raw[i] * (1 if bug == 'wrong_scale' else scale) % P
            if i < q and bug != 'missing_negative':
                v = (v - pads[i]) % P
            out[i] = v * (1 if bug == 'missing_coset' else pow(h, i, P)) % P
            owners[i] += 1
        # Give each inverse block one contiguous and disjoint tail interval.
        per_tile = (q + nt - 1) // nt
        lo, hi = tile * per_tile, min(q, (tile + 1) * per_tile)
        for j in range(lo, hi):
            i = n + j
            v = pads[j]
            if i < q and bug != 'missing_tail_negative':
                v = (v - pads[i]) % P
            out[i] = v * (1 if bug == 'missing_coset' else pow(h, i, P)) % P
            owners[i] += 1
    assert tuple(raw) == scratch_before, 'inverse intermediate modified'
    assert all(x == 1 for x in owners), 'missing or duplicate final-store owner'
    assert out[pw:] == [poison] * (nn-pw), 'dirty zero-extension tail was written'
    return out[:pw] + [0] * (nn-pw), owners


def sector_counts(n, q, rows=1, threads=512):
    """Distinct 32-B sectors per 32-lane source-level instruction, no cache reuse."""
    pw = n + q
    nt = max(1, n // 4096)
    jwidth = n // nt
    d = {arm: {op: 0 for op in ('inverse_read','inverse_write','coef_read','neg_pad_read',
                               'pos_pad_read','power_read','out_write')}
         for arm in ('baseline','fused')}

    def add(arm, op, addresses):
        d[arm][op] += len({x // 4 for x in addresses})

    for row in range(rows):
        # Last inverse pass: p2 uses q=t*J+jj and i=t*4096+tile*J+jj;
        # p1 uses contiguous i. Each loop iteration is one warp instruction.
        for tile in range(nt):
            length = 4096 if nt > 1 else n
            for k0 in range(0, length, 32):
                idx = []
                for k in range(k0, min(length, k0+32)):
                    t, jj = divmod(k, jwidth)
                    idx.append(t*4096 + tile*jwidth + jj if nt > 1 else k)
                source_idx = [rev(i, n.bit_length()-1) for i in idx] if nt == 1 else idx
                add('baseline','inverse_read',[row*n+i for i in source_idx])
                add('fused','inverse_read',[row*n+i for i in source_idx])
                add('baseline','inverse_write',[row*n+i for i in idx])
                add('fused','out_write',[row*pw+i for i in idx])
                add('fused','neg_pad_read',[row*q+i for i in idx if i<q])
                add('fused','power_read',idx)
            per_tile = (q + nt - 1)//nt
            lo,hi = tile*per_tile, min(q,(tile+1)*per_tile)
            for j0 in range(lo,hi,32):
                js = range(j0,min(hi,j0+32))
                add('fused','pos_pad_read',[row*q+j for j in js])
                add('fused','neg_pad_read',[row*q+n+j for j in js if n+j<q])
                add('fused','power_read',[n+j for j in js])
                add('fused','out_write',[row*pw+n+j for j in js])
        for g0 in range(0,pw,32):
            ix = range(g0,min(pw,g0+32))
            add('baseline','coef_read',[row*n+i for i in ix if i<n])
            add('baseline','neg_pad_read',[row*q+i for i in ix if i<q])
            add('baseline','pos_pad_read',[row*q+i-n for i in ix if i>=n])
            add('baseline','power_read',list(ix))
            add('baseline','out_write',[row*pw+i for i in ix])
    return {arm: {'by_op': x, 'total': sum(x.values())} for arm,x in d.items()}


def main():
    limits()
    start = time.monotonic()
    rng = random.Random(SEED)
    cases = 0
    direct_points = 0
    branch_counts = {'p1':0,'p2':0,'q_lt_n':0,'q_eq_n':0,'q_gt_n':0}
    negatives = {}
    digest = hashlib.sha256()
    for n in (2,4,8,16,32,64,128,4096,8192,16384):
        qset = (0,1,n//2,n,n+1,min(3*n, 32768-n)) if n <= 128 else (0,1,256,n,min(n+3,3*n))
        for q in sorted(set(qset)):
            if q < 0: continue
            nn = 1 << (n+q-1).bit_length()
            msg = [rng.randrange(P) for _ in range(n)]
            pads = [rng.randrange(P) for _ in range(q)]
            h = 7
            raw, p1, branch = inverse_staged_raw(msg)
            scale = pow(n,-1,P)
            coef = [v*scale%P for v in raw]
            if n <= 32:
                assert coef == direct_inverse(msg), 'independent inverse DFT mismatch'
                direct_points += n
            expected = baseline(coef,pads,h,nn)
            got,owners = final_store(raw,pads,h,nn)
            assert got == expected, (n,q,'polynomial mismatch')
            if n <= 16:
                xroot = root(nn)
                for k in range(nn):
                    x = h*pow(xroot,k,P)%P
                    f=g=0
                    for v in reversed(coef):f=(f*x+v)%P
                    for v in reversed(pads):g=(g*x+v)%P
                    direct = (f+(pow(x,n,P)-1)*g)%P
                    assert direct == sum(expected[i]*pow(xroot,i*k,P) for i in range(nn))%P
                    direct_points += 1
            cases += 1
            branch_counts[branch] += 1
            branch_counts['q_lt_n' if q<n else 'q_eq_n' if q==n else 'q_gt_n'] += 1
            digest.update(n.to_bytes(4,'little')+q.to_bytes(4,'little'))
            digest.update(b''.join(v.to_bytes(8,'little') for v in got[:min(nn,64)]))
            if n == 8 and q == 9:
                for bug in ('wrong_scale','missing_negative','missing_tail_negative','missing_coset'):
                    negatives[bug] = final_store(raw,pads,h,nn,bug=bug)[0] != expected
                # Current k_zk_pad_scale omits -pad[i] when n<=i<q.
                legacy = list(coef)+[0]*(nn-n)
                for i in range(nn):
                    if i<n:legacy[i]=(coef[i]-(pads[i] if i<q else 0))%P
                    elif i<n+q:legacy[i]=pads[i-n]
                    legacy[i]=legacy[i]*pow(h,i,P)%P
                negatives['legacy_q_gt_n'] = legacy != expected
            if n == 64 and q == 1:
                bad_stride = list(expected[:n])+[99]+list(expected[n+1:])
                negatives['wrong_row_stride'] = bad_stride != expected
                # If the forward NTT consumes poisoned allocation tails
                # instead of applying n_src zero extension, output changes.
                negatives['dirty_pool_tail'] = got[:n+q]+[123]*(nn-n-q) != expected
                # A single wider-stride allocation aliased to the n-wide p2
                # scratch cannot hold both rows without destroying row 1 input.
                a = list(range(2*n))
                a[n+q:2*n+q] = a[n:2*n]
                negatives['in_place_widened_stride_alias'] = a[n:2*n] != list(range(n,2*n))
    # Three independently generated rows, partitioned as ragged chunks.
    multirow_checks = 0
    for n,q in ((16,3),(16,17),(64,1),(64,65)):
        nn=1 << (n+q-1).bit_length()
        vectors=[([rng.randrange(P) for _ in range(n)],
                  [rng.randrange(P) for _ in range(q)]) for _ in range(3)]
        refs=[baseline(direct_inverse(m),p,h,nn) for m,p in vectors]
        for parts in ((1,1,1),(2,1),(1,2),(3,)):
            flattened=[]
            cursor=0
            for rc in parts:
                for m,p in vectors[cursor:cursor+rc]:
                    raw,_,_=inverse_staged_raw(m)
                    flattened.extend(final_store(raw,p,h,nn,poison=97)[0][:n+q])
                cursor+=rc
            assert cursor==3
            assert flattened==[v for row in refs for v in row[:n+q]],(n,q,parts)
            multirow_checks+=1
    assert all(negatives.values()),negatives
    profiles=[]
    for n,q,nn,rows in ((1024,256,4096,1),(16384,256,65536,1),
                        (16384,257,65536,3),(16384,16384,65536,1),
                        (16384,16387,65536,1)):
        sec=sector_counts(n,q,rows)
        profiles.append({'n':n,'q':q,'nn':nn,'rows':rows,'branch':'p1' if n<=4096 else 'p2',
                         'baseline_logical_bytes':8*rows*(2*n+n+2*q+(n+q)+(n+q)),
                         'fused_logical_bytes':8*rows*(n+2*q+(n+q)+(n+q)),
                         'removed_bytes':16*rows*n,
                         'scratch_peak_baseline_bytes':8*rows*(n+n+q),
                         'scratch_peak_fused_bytes':8*rows*((0 if n<=4096 else n)+n+q),
                         'sectors':sec})
    pins={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
          ('hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu',
           'zkp-core/src/pcs.rs','zkp-core/src/ntt.rs')}
    result={'status':'passed','seed':SEED,'cases':cases,'multirow_chunk_checks':multirow_checks,'branch_counts':branch_counts,
            'independent_direct_points':direct_points,'negative_controls':negatives,
            'digest_sha256':digest.hexdigest(),'profiles':profiles,'source_pins':pins,
            'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'elapsed_s':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'threads':1,'cpu':next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),None),
            'platform':platform.platform(),'python':platform.python_version(),
            'limits':{'wall_s':59,'cpu_s':55,'address_space_mib':512,'estimated_memory_mib':40},
            'clocks':{'witness_s':None,'prove_s':None,'serialization_s':None,'verify_s':None},
            'scope':'Synthetic exact arithmetic, block ownership and source-address model. No CUDA/native compilation, GPU timings, hashing, receipt, full-stack proof or privacy review.'}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('profiles','source_pins')},indent=2))
    print(json.dumps([{'n':p['n'],'q':p['q'],'rows':p['rows'],'removed_bytes':p['removed_bytes'],
                       'scratch_delta':p['scratch_peak_baseline_bytes']-p['scratch_peak_fused_bytes'],
                       'sectors_baseline':p['sectors']['baseline']['total'],
                       'sectors_fused':p['sectors']['fused']['total']} for p in profiles],indent=2))


if __name__ == '__main__':
    main()
