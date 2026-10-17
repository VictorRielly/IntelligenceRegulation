#!/usr/bin/env python3
"""CPU-only synthetic hiding-NTT load fusion and address-traffic experiment.

No CUDA compiled/executed. The scalar stage split is a mathematical model,
not a simulator of the CUDA second-pass thread mapping or cache hierarchy.
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

P = 2**64 - 2**32 + 1
SEED = 2026092710
HERE = Path(__file__).resolve().parent


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def root(n):
    return pow(7, (P - 1) // n, P)


def rev(i, bits):
    v = 0
    for _ in range(bits):
        v = (v << 1) | (i & 1)
        i >>= 1
    return v


def stages(a, first, last):
    # Stage-major twiddles have exactly these values; no maximum-size dependence.
    for st in range(first, last + 1):
        size = 1 << st
        half = size >> 1
        w = root(size)
        tw = [pow(w, i, P) for i in range(half)]
        for b in range(0, len(a), size):
            for j in range(half):
                u, v = a[b+j], a[b+j+half] * tw[j] % P
                a[b+j], a[b+j+half] = (u+v) % P, (u-v) % P


def inverse_dif(msg):
    # Inverse DIF loop: independently structured relative to forward DIT.
    a = list(msg)
    size = len(a)
    while size > 1:
        half = size // 2
        wi = pow(root(size), P-2, P)
        tw = [pow(wi, j, P) for j in range(half)]
        for b in range(0, len(a), size):
            for j in range(half):
                u, v = a[b+j], a[b+j+half]
                a[b+j], a[b+j+half] = (u+v) % P, (u-v)*tw[j] % P
        size //= 2
    bits = len(a).bit_length()-1
    scale = pow(len(a), -1, P)
    return [a[rev(i, bits)]*scale % P for i in range(len(a))]


def check_shape(n, q, nn, h):
    if n < 2 or n & (n-1) or nn < n or nn & (nn-1):
        raise ValueError('power-of-two dimensions')
    if q < 0 or n+q > nn or not 0 < h < P or pow(h, nn, P) == 1:
        raise ValueError('pad bound or coset')


def materialize(coef, pads, pows, pw, legacy=False):
    n, q = len(coef), len(pads)
    a = list(coef) + [0] * (pw-n)
    if legacy:
        # Exact branch obligation from current CUDA, deliberately wrong for q>n.
        for i in range(pw):
            if i < n:
                a[i] = coef[i] - (pads[i] if i < q else 0)
            elif i < n+q:
                a[i] = pads[i-n]
    else:
        # Correct materialized polynomial, separate passes from fused accessor.
        for j, p in enumerate(pads):
            a[j] = (a[j]-p) % P
            a[n+j] = (a[n+j]+p) % P
    return [v*pows[i] % P for i, v in enumerate(a)]


def split_forward(nn, at, block_log=12, bug=None):
    bits = nn.bit_length()-1
    lb = min(block_log, bits)
    bs = 1 << lb
    out = [None] * nn
    for b in range(nn // bs):
        tile = [at(b*bs+j if bug == 'no_bitreversal' else rev(b*bs+j, bits))
                for j in range(bs)]
        stages(tile, 1, lb)
        out[b*bs:(b+1)*bs] = tile
    p1 = list(out)
    stages(out, lb+1, bits)
    return p1, out


def encode(msg, pads, nn, h, fused, pw=None, block_log=12, bug=None):
    n, q = len(msg), len(pads)
    check_shape(n, q, nn, h)
    pw = n+q if pw is None else pw
    if pw not in (n+q, nn):
        raise ValueError('invalid stride')
    coef = inverse_dif(msg)
    if bug == 'wrong_inverse_scale':
        coef = [v*n*pow(nn, -1, P) % P for v in coef]
    pows = [pow(h, i, P) for i in range(nn)]
    if not fused:
        a = materialize(coef, pads, pows, pw, legacy=(bug == 'legacy_overlap'))
        return split_forward(nn, lambda i: a[i] if i < pw else 0, block_log, bug)

    def at(i):
        if i >= n+q:
            return 0
        v = coef[i] if i < n else 0
        if i < q and bug != 'omit_negative_pad':
            v -= pads[i]
        if n <= i < n+q and bug != 'omit_positive_pad':
            v += pads[i-n]
        return v * (1 if bug == 'no_coset' else pows[i]) % P
    return split_forward(nn, at, block_log, bug)


def definition(msg, pads, nn, h):
    # Independent direct inverse DFT plus separate Horner polynomial evaluation.
    n = len(msg)
    w = pow(7, (P-1)//n, P)
    c = [sum(msg[j]*pow(w, (-i*j) % n, P) for j in range(n))*pow(n, -1, P) % P
         for i in range(n)]
    wn = pow(7, (P-1)//nn, P)
    answer = []
    for k in range(nn):
        x = h*pow(wn, k, P) % P
        f = g = 0
        for v in reversed(c):
            f = (f*x+v) % P
        for v in reversed(pads):
            g = (g*x+v) % P
        answer.append((f+(pow(x,n,P)-1)*g) % P)
    return answer


def packed(values):
    return b''.join(v.to_bytes(8, 'little') for v in values)


def digest(values):
    return hashlib.sha256(packed(values)).hexdigest()


class Traffic:
    """Count scalar u64 words and distinct 32-byte sectors per warp instruction.

    Cold issue count only: no cache reuse across instructions/warps or arrays.
    CUDA allocation bases are assumed 32-byte aligned. q need not align rows.
    """
    def __init__(self):
        self.words = {}
        self.sectors = {}

    def op(self, name, indices):
        self.words[name] = self.words.get(name, 0) + len(indices)
        self.sectors[name] = self.sectors.get(name, 0) + len({i//4 for i in indices})

    def result(self):
        return {'u64_words_by_op': self.words, 'logical_bytes': 8*sum(self.words.values()),
                'warp_sector_requests_by_op': self.sectors,
                'warp_sector_requests': sum(self.sectors.values())}


def traffic(n, q, nn, rows, compact=True, fused=False, natural_local=False):
    check_shape(n, q, nn, 7)
    pw = n+q if compact else nn
    t = Traffic()
    if not fused:
        # k_zk_pad_scale's flat grid, with overlap correction where q>n.
        for g0 in range(0, rows*pw, 32):
            items = [(g//pw, g % pw) for g in range(g0, min(g0+32, rows*pw))]
            t.op('coef_read', [r*n+i for r,i in items if i<n])
            t.op('pad_negative_read', [r*q+i for r,i in items if i<q])
            t.op('pad_positive_read', [r*q+i-n for r,i in items if n<=i<n+q])
            t.op('power_read', [i for r,i in items])
            t.op('scratch_write', [r*pw+i for r,i in items])
    bits = nn.bit_length()-1
    lb = min(12, bits)
    bs, bpr = 1 << lb, nn >> lb
    for row in range(rows):
        for block in range(bpr):
            for j0 in range(0, bs, 32):
                if natural_local:
                    # Same block ownership, reordered shared stores; not native tested.
                    ids = [j*bpr+rev(block, bits-lb) for j in range(j0,min(j0+32,bs))]
                else:
                    ids = [rev(block*bs+j, bits) for j in range(j0,min(j0+32,bs))]
                if fused:
                    t.op('coef_read', [row*n+i for i in ids if i<n])
                    t.op('pad_negative_read', [row*q+i for i in ids if i<q])
                    t.op('pad_positive_read', [row*q+i-n for i in ids if n<=i<n+q])
                    t.op('power_read', [i for i in ids if i<n+q])
                else:
                    t.op('scratch_read', [row*pw+i for i in ids if i<pw])
                # Unchanged p1 output store; excludes all shared/twiddle/p2 work.
                t.op('p1_write', [row*nn+block*bs+j for j in range(j0,min(j0+32,bs))])
    got = t.result()
    expected = rows*(n+2*q+(n+q if fused else 3*pw)+nn)*8
    assert got['logical_bytes'] == expected
    return got


def chunked(msgs, pads, nn, h, chunk, bug=None):
    # Chunk-local coefficient/pad views; natural output rows.
    rows = []
    for lo in range(0,len(msgs),chunk):
        for j, m in enumerate(msgs[lo:lo+chunk]):
            p = pads[j if bug == 'pad_chunk_offset' else lo+j]
            rows.append(encode(m,p,nn,h,True,block_log=3)[1])
    return rows


def main():
    limits()
    started = time.monotonic()
    rng = random.Random(SEED)
    cases, direct_points, comparisons = [], 0, 0
    for n in [2,8,16,64]:
        nn = 4*n
        for q in sorted(set([0,1,n//2,n,n+1,nn-n])):
            for kind in ['random','edge','zero']:
                msg = [rng.randrange(P) for _ in range(n)] if kind == 'random' else [
                    (0 if kind=='zero' else [0,1,P-1,P-2][i%4]) for i in range(n)]
                pads = [rng.randrange(P) for _ in range(q)] if kind == 'random' else [
                    (0 if kind=='zero' else [1,P-1,P-2][i%3]) for i in range(q)]
                for h in [7,11]:
                    oracle = definition(msg,pads,nn,h)
                    for lb in [2,3,12]:
                        fused = encode(msg,pads,nn,h,True,block_log=lb)
                        for pw in [n+q,nn]:
                            base = encode(msg,pads,nn,h,False,pw,lb)
                            assert fused == base
                            assert fused[1] == oracle
                            comparisons += 1
                        if q<=n:
                            assert encode(msg,pads,nn,h,False,block_log=lb,bug='legacy_overlap') == fused
                    direct_points += nn
                    cases.append({'n':n,'nn':nn,'q':q,'kind':kind,'h':h,'sha256':digest(oracle)})

    conformance = []
    for c in json.loads((HERE/'conformance-small.json').read_text()):
        out = encode(c['msg'],c['pad'],c['nn'],c['coset_h'],True,block_log=3)[1]
        assert out == c['expected'] and digest(out) == c['encoded_sha256']
        conformance.append(c['name'])

    # Actual p1 split boundary, sparse closed-form oracle avoids an O(N^2) DFT.
    wide = []
    for n,nn,q in [(1024,4096,17),(2048,8192,256),(2048,8192,2051)]:
        fc = {0:3,1:P-7,5:17}
        pc = {0:P-1,q//2:7,q-1:13}
        f = lambda x: sum(v*pow(x,k,P) for k,v in fc.items()) % P
        g = lambda x: sum(v*pow(x,k,P) for k,v in pc.items()) % P
        msg = [f(pow(root(n),k,P)) for k in range(n)]
        pads = [pc.get(i,0) for i in range(q)]
        expect = [(f(x)+(pow(x,n,P)-1)*g(x)) % P
                  for x in (11*pow(root(nn),k,P) % P for k in range(nn))]
        fused = encode(msg,pads,nn,11,True)
        assert fused == encode(msg,pads,nn,11,False)
        assert fused[1] == expect
        wide.append({'n':n,'nn':nn,'q':q,'output_points':nn,'sha256':digest(expect)})

    n,nn,q = 16,64,19
    msgs = [[rng.randrange(P) for _ in range(n)] for _ in range(7)]
    pads = [[rng.randrange(P) for _ in range(q)] for _ in msgs]
    refs = [definition(m,p,nn,11) for m,p in zip(msgs,pads)]
    chunk_checks = 0
    for chunk in [1,2,3,7]:
        got = chunked(msgs,pads,nn,11,chunk)
        assert got == refs
        for col in range(nn):
            assert packed([r[col] for r in got]) == packed([r[col] for r in refs])
            chunk_checks += 1
    indices = [63,0,17,17,1,63,32]
    gather = lambda rows, ids: [packed([r[k] for r in rows]) for k in ids]
    assert gather(got,indices) == gather(refs,indices)
    controls = {}
    for bug in ['no_bitreversal','wrong_inverse_scale','omit_negative_pad','omit_positive_pad','no_coset']:
        controls[bug] = encode(msgs[0],pads[0],nn,11,True,block_log=3,bug=bug)[1] != refs[0]
    controls['legacy_overlap'] = encode(msgs[0],pads[0],nn,11,False,bug='legacy_overlap')[1] != refs[0]
    controls['pad_chunk_offset'] = chunked(msgs,pads,nn,11,3,'pad_chunk_offset') != refs
    controls['drop_duplicates'] = gather(refs,sorted(set(indices))) != gather(refs,indices)
    controls['row_order'] = gather(list(reversed(refs)),indices) != gather(refs,indices)
    pad2 = list(pads[0]); pad2[-1] = (pad2[-1]+1) % P
    controls['changed_pad'] = encode(msgs[0],pad2,nn,11,True)[1] != refs[0]
    # Minimal old overlap defect, independent polynomial x^16-x^8.
    m,p = [0]*8,[0]*9; p[8]=1
    ok = encode(m,p,32,7,True)[1]
    bad = encode(m,p,32,7,False,bug='legacy_overlap')[1]
    assert all((b-a) % P == pow(7*pow(root(32),k,P) % P,8,P) for k,(a,b) in enumerate(zip(ok,bad)))
    controls['minimal_overlap_counterexample'] = all(a!=b for a,b in zip(ok,bad))
    assert all(controls.values())
    refusals = 0
    for n,q,nn,h in [(3,1,16,7),(8,25,32,7),(8,1,32,0),(8,1,32,1),(8,-1,32,7)]:
        try:
            check_shape(n,q,nn,h)
        except ValueError:
            refusals += 1
    assert refusals == 5
    try:
        encode([0]*8,[0]*3,32,7,True,pw=13)
    except ValueError:
        refusals += 1
    assert refusals == 6

    traffic_cases=[]
    for n,q,nn,rows in [(16,19,64,7),(1024,256,4096,1),(2048,256,8192,1),
                       (16384,256,65536,1),(16384,256,65536,3),(16384,16384,65536,1),
                       (16384,16387,65536,1)]:
        compact = traffic(n,q,nn,rows)
        full = traffic(n,q,nn,rows,compact=False)
        fused = traffic(n,q,nn,rows,fused=True)
        reorder = traffic(n,q,nn,rows,fused=True,natural_local=True)
        removed = 16*rows*(n+q)
        assert compact['logical_bytes']-fused['logical_bytes'] == removed
        traffic_cases.append({'n':n,'q':q,'nn':nn,'rows':rows,'compact':compact,'full':full,
                              'fused':fused,'natural_local_load_model':reorder,
                              'removed_scratch_bytes':8*rows*(n+q),
                              'logical_bytes_saved':removed,
                              'logical_reduction_percent':100*removed/compact['logical_bytes'],
                              'sector_increase_percent':100*(fused['warp_sector_requests']/compact['warp_sector_requests']-1),
                              'coset_multiplications_compact':rows*(n+q),
                              'coset_multiplications_fused':rows*(n+q),
                              'full_width_coset_multiplications':rows*nn})

    result={'status':'passed','seed':SEED,'cases':cases,'differential_cases':len(cases),
            'materialized_comparisons':comparisons,'direct_definition_points':direct_points,
            'native_conformance_vectors':conformance,'wide_sparse_cases':wide,
            'column_byte_checks':chunk_checks,'gather_requests':indices,'negative_controls':controls,
            'malformed_refusals':refusals,'traffic_cases':traffic_cases,
            'threads':1,'affinity':sorted(os.sched_getaffinity(0)),
            'cpu':next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
            'python':platform.python_version(),'platform':platform.platform(),
            'limits':{'wall_s':59,'cpu_s':55,'address_space_mib':512,'estimated_memory_mib':48},
            'elapsed_s':time.monotonic()-started,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'proving_s':None,'verification_s':None,'complete_readiness_s':None,
            'gpu_executed':False,'native_compiled':False,
            'scope':'Synthetic exact field encodes and source-address issue model; sector requests are not cache misses, DRAM bytes or time. No hashes/proof/transcript/RNG/device validation.'}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['cases','traffic_cases','native_conformance_vectors']},indent=2))
    for c in traffic_cases:
        print(json.dumps({k:v for k,v in c.items() if k not in ['compact','full','fused','natural_local_load_model']},sort_keys=True))


if __name__ == '__main__':
    main()
