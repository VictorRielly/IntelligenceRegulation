#!/usr/bin/env python3
"""Synthetic arithmetic/layout oracle; no native code, GPU, or real witness.

Candidate: inverse DIF -> coefficient-address view -> mixed-radix forward
in mapped order -> logical-column adapter. Original implementation of the
DFT factorization, not a port/reproduction of any downloaded GPU code.
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
SEED = 20260926
HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 2**20, 512 * 2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def root(n):
    assert n > 0 and n & (n - 1) == 0 and n <= 2**32
    return pow(7, (P - 1) // n, P)


def rev(x, n):
    return int(f'{x:0{n.bit_length()-1}b}'[::-1], 2) if n > 1 else 0


def dit(values, inverse=False, max_n=None):
    """Source-derived CPU convention: shared twiddles, input bit reversal."""
    n = len(values)
    max_n = max_n or n
    assert max_n >= n and max_n % n == 0
    w = root(max_n)
    if inverse:
        w = pow(w, P - 2, P)
    tw = [pow(w, j, P) for j in range(max_n // 2)]
    a = [values[rev(i, n)] for i in range(n)]
    size = 2
    while size <= n:
        h = size // 2
        for base in range(0, n, size):
            for j in range(h):
                u, v = a[base+j], a[base+j+h] * tw[j*(max_n//size)] % P
                a[base+j], a[base+j+h] = (u+v) % P, (u-v) % P
        size *= 2
    return [v * pow(n, P-2, P) % P for v in a] if inverse else a


def inverse_dif(values):
    """Natural evaluations to bit-reversed coefficients; distinct loop."""
    a = list(values)
    n = size = len(a)
    wi = pow(root(n), P-2, P)
    while size > 1:
        half = size // 2
        step = pow(wi, n // size, P)
        for base in range(0, n, size):
            w = 1
            for j in range(half):
                u, v = a[base+j], a[base+j+half]
                a[base+j] = (u+v) % P
                a[base+j+half] = (u-v)*w % P
                w = w*step % P
        size //= 2
    scale = pow(n, P-2, P)
    return [v*scale % P for v in a]


def coefficient(i, n, pad, coef_at):
    # Independent contributions MUST add: negative and shifted pads overlap q>n.
    v = coef_at(i) if i < n else 0
    if i < len(pad):
        v -= pad[i]
    if n <= i < n+len(pad):
        v += pad[i-n]
    return v % P


def cpu_encode(msg, pad, nn, h=7, max_n=None):
    n = len(msg)
    assert n+len(pad) <= nn and nn % n == 0
    assert h != 0 and pow(h, nn, P) != 1
    coeff = dit(msg, True, max_n or nn)
    out = coeff + [0]*(nn-n)
    for i, v in enumerate(pad):
        out[i] = (out[i]-v) % P
        out[n+i] = v
    for i in range(n+len(pad)):
        out[i] = out[i]*pow(h, i, P) % P
    return dit(out, False, max_n or nn)


def four_step_mapped(nn, a_size, coef_at, omit_twiddle=False):
    """j=j0+A*j1, k=k1+B*k0. Physical output p=k1*A+k0."""
    assert nn % a_size == 0
    b_size = nn // a_size
    w = root(nn)
    first = [dit([coef_at(j0+a_size*j1) for j1 in range(b_size)])
             for j0 in range(a_size)]
    out = []
    for k1 in range(b_size):
        cross = [first[j0][k1] * (1 if omit_twiddle else pow(w, j0*k1, P)) % P
                 for j0 in range(a_size)]
        out.extend(dit(cross))
    return out


def physical(k, nn, a_size):
    b_size = nn // a_size
    return (k % b_size)*a_size + k//b_size


def mapped_encode(msg, pad, nn, a_size, h=7, bug=None):
    n = len(msg)
    assert n+len(pad) <= nn and nn % n == 0
    assert h != 0 and pow(h, nn, P) != 1
    coef = inverse_dif(msg)

    def at(i):
        def read(j):
            v = coef[rev(j, n)]
            return v*n*pow(nn, P-2, P) % P if bug == 'inverse_scale_nn' else v
        if bug == 'cuda_branch_overlap':
            # Scalar transcription of inspected k_zk_pad_scale branch, not GPU execution.
            if i < n:
                v = read(i) - (pad[i] if i < len(pad) else 0)
            elif i < n+len(pad):
                v = pad[i-n]
            else:
                v = 0
        else:
            v = coefficient(i, n, pad, read)
        return v*pow(1 if bug == 'missing_coset' else h, i, P) % P

    return four_step_mapped(nn, a_size, at, bug == 'missing_twiddle')


def natural(mapped, a_size):
    return [mapped[physical(k, len(mapped), a_size)] for k in range(len(mapped))]


def horner(coeff, x):
    acc = 0
    for v in reversed(coeff):
        acc = (acc*x+v) % P
    return acc


def definition_encode(msg, pad, nn, h=7):
    """Independent definition: direct inverse DFT and separate Horner polys."""
    n = len(msg)
    w = pow(7, (P-1)//n, P)
    scale = pow(n, -1, P)
    coeff = [sum(v*pow(w, (-i*j) % n, P) for j,v in enumerate(msg))*scale % P
             for i in range(n)]
    wn = pow(7, (P-1)//nn, P)
    result = []
    for k in range(nn):
        x = h*pow(wn, k, P) % P
        result.append((horner(coeff, x)+(pow(x,n,P)-1)*horner(pad,x)) % P)
    return result


def lagrange_at(msg, pad, x):
    n = len(msg)
    w = pow(7, (P-1)//n, P)
    z = (pow(x,n,P)-1) % P
    data = sum(v*pow(w,j,P)*pow(n*(x-pow(w,j,P)) % P, -1, P)
               for j,v in enumerate(msg))*z % P
    return (data+z*horner(pad,x)) % P


def packed(row):
    return b''.join(v.to_bytes(8,'little') for v in row)


def digest(row):
    return hashlib.sha256(packed(row)).hexdigest()


def main():
    limits()
    start = time.monotonic()
    rng = random.Random(SEED)
    cases, comparisons, points, lagrange_points = [], 0, 0, 0
    for n in [8,16,64]:
        nn = 4*n
        for q in [0,n//2,n,n+3,nn-n]:
            for kind in ['zero','random','edge']:
                msg = ([0]*n if kind == 'zero' else
                       [rng.randrange(P) for _ in range(n)] if kind == 'random' else
                       [0,1,P-1,P-2]*(n//4))
                pad = ([0]*q if kind == 'zero' else
                       [rng.randrange(1,P) for _ in range(q)] if kind == 'random' else
                       [P-1 if i%2 else 1 for i in range(q)])
                for h in [7,11]:
                    expected = definition_encode(msg,pad,nn,h)
                    assert cpu_encode(msg,pad,nn,h,nn*2) == expected
                    splits = sorted(set([2,4,1 << ((nn.bit_length()-1)//2)]))
                    for a in splits:
                        m = mapped_encode(msg,pad,nn,a,h)
                        assert natural(m,a) == expected
                        assert sorted(physical(k,nn,a) for k in range(nn)) == list(range(nn))
                        comparisons += 1
                    for k in [0,1,nn//2,nn-1]:
                        assert lagrange_at(msg,pad,h*pow(root(nn),k,P)%P) == expected[k]
                        lagrange_points += 1
                    points += nn
                    cases.append({'n':n,'nn':nn,'q':q,'kind':kind,'coset':h,
                                  'splits_A':splits,'digest':digest(expected)})

    # Read-only third-implementation vectors, full equality for 15 small rows.
    vec_path = ROOT/'results/zk60_encode_vectors/vectors.json'
    full_path = ROOT/'results/zk60_encode_vectors/full_rows.json'
    vectors = json.loads(vec_path.read_text())['vectors']
    full = json.loads(full_path.read_text())['rows']
    conformance = []
    for v in vectors:
        if v['n'] > 64:
            continue
        got = natural(mapped_encode(v['msg'],v['pad'],v['nn'],4,v['coset_h']),4)
        assert got == full[v['name']]
        assert digest(got) == v['encoded_sha256']
        conformance.append(v['name'])

    # Column bytes and request ordering are the actual external-store obligations.
    n, nn, a = 16,64,4  # nonsquare A=4, B=16: inverse map differs
    msgs = [[rng.randrange(P) for _ in range(n)] for _ in range(5)]
    pads = [[rng.randrange(1,P) for _ in range(n+3)] for _ in range(5)]
    rows = [mapped_encode(m,p,nn,a) for m,p in zip(msgs,pads)]
    refs = [definition_encode(m,p,nn) for m,p in zip(msgs,pads)]
    for k in range(nn):
        assert packed([r[physical(k,nn,a)] for r in rows]) == packed([r[k] for r in refs])
    indices = [63,1,1,0,32,7,63]
    gathered = [[r[physical(k,nn,a)] for r in rows] for k in indices]
    assert gathered == [[r[k] for r in refs] for k in indices]
    # Streaming row chunks preserve the byte stream, including a partial last chunk.
    chunks = [(0,2),(2,4),(4,5)]
    for k in range(nn):
        stream = b''.join(packed([rows[r][physical(k,nn,a)] for r in range(lo,hi)]) for lo,hi in chunks)
        assert stream == packed([r[k] for r in refs])

    bad = {}
    msg,pad,expected = msgs[0],pads[0],refs[0]
    m = rows[0]
    bad['mapped_output_treated_as_natural'] = m != expected
    bad['inverse_permutation_used_as_forward'] = [m[(k%a)*(nn//a)+k//a] for k in range(nn)] != expected
    for bug in ['missing_coset','inverse_scale_nn','missing_twiddle','cuda_branch_overlap']:
        bad[bug] = natural(mapped_encode(msg,pad,nn,a,bug=bug),a) != expected
    changed_pad = list(pad); changed_pad[-1] = (changed_pad[-1]+1)%P
    bad['changed_pad_changes_encoding'] = natural(mapped_encode(msg,changed_pad,nn,a),a) != expected
    bad['duplicate_requests_dropped'] = len(set(indices)) != len(gathered)
    bad['row_order_changes_column_bytes'] = packed([r[1] for r in refs[::-1]]) != packed([r[1] for r in refs])
    assert all(bad.values())
    # Localize the inspected CUDA branch limitation; q<=n remains equal.
    overlap = []
    for q in [0,8,16,19,48]:
        p = [rng.randrange(1,P) for _ in range(q)]
        good = definition_encode(msg,p,nn)
        wrong = natural(mapped_encode(msg,p,nn,a,bug='cuda_branch_overlap'),a)
        assert (wrong == good) == (q <= n)
        overlap.append({'n':n,'nn':nn,'q':q,'mismatch_columns':sum(x!=y for x,y in zip(wrong,good)),
                        'evidence':'scalar branch transcription, no device execution'})

    # Closed-form counterexample removes reliance on randomized comparisons.
    # n=8, q=9, msg=0, pad[8]=1: correct x^16-x^8; inspected branch x^16.
    sparse_msg, sparse_pad = [0]*8, [0]*8+[1]
    sparse_good = definition_encode(sparse_msg,sparse_pad,32)
    sparse_bad = natural(mapped_encode(sparse_msg,sparse_pad,32,4,bug='cuda_branch_overlap'),4)
    for k in range(32):
        x = 7*pow(root(32),k,P)%P
        assert sparse_good[k] == (pow(x,16,P)-pow(x,8,P))%P
        assert sparse_bad[k] == pow(x,16,P)
        assert (sparse_bad[k]-sparse_good[k])%P == pow(x,8,P) != 0

    refused = 0
    for pad0,nn0,h0 in [([1]*49,64,7),([1]*3,64,1),([1]*3,64,0)]:
        try:
            mapped_encode(msg,pad0,nn0,a,h0)
        except AssertionError:
            refused += 1
    assert refused == 3
    pin_paths = ['zkp-core/src/ntt.rs','zkp-core/src/pcs.rs','zkp-core/src/pcs/backend.rs',
                 'hashline/src/gpu/kernels.cu','hashline/src/gpu/cuda.rs',
                 'results/zk60_encode_vectors/vectors.json','results/zk60_encode_vectors/full_rows.json']
    cpu = next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name'))
    result = {'schema':'zkp-efficiency/ntt-mapped-layout/v1','status':'passed',
              'run_identity':'20260926T185233Z-aa002e55','seed':SEED,
              'field':'Goldilocks base field','threads':1,'cpu_affinity':sorted(os.sched_getaffinity(0)),
              'cpu':cpu,'platform':platform.platform(),'python':platform.python_version(),
              'max_wall_seconds':59,'max_cpu_seconds':55,'max_address_space_mib':512,'estimated_memory_mib':32,
              'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'source_pins':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in pin_paths},
              'differential_cases':len(cases),'mapped_comparisons':comparisons,'direct_output_points':points,
              'lagrange_points':lagrange_points,'conformance_vectors':conformance,'cases':cases,
              'column_byte_checks':nn,'chunk_stream_checks':nn,'gather_indices':indices,'rows':5,
              'negative_controls':bad,'malformed_fixture_refusals':refused,'cuda_overlap_control':overlap,
              'closed_form_overlap':{'n':8,'nn':32,'q':9,'msg':'all zero','pad':'only pad[8]=1',
                  'correct':'x^16-x^8','inspected_branch':'x^16','mismatch_columns':32},
              'conditional_restore_traffic':{'basis':'Extra restore copy, ONLY if a replacement emits mapped output',
                  'removed_read_write_bytes_per_row_at_nn65536':16*65536,
                  'existing_cuda_has_separate_restore':False,'runtime_gain':None},
              'proving_seconds':None,'verification_seconds':None,'complete_readiness_seconds':None,
              'elapsed_seconds':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              'scope':'Exact synthetic arithmetic and byte-stream adapter only. No upstream algorithm reproduction, native execution, BLAKE3, receipt, GPU, security acceptance, or model-speed result.'}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['cases','source_pins']},indent=2))


if __name__ == '__main__':
    main()
