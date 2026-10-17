#!/usr/bin/env python3
"""Synthetic arithmetic/traffic oracle; not a proof or native benchmark."""
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
SEED = 2026092606
HERE = Path(__file__).resolve().parent

def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)

def mul(x, y):
    return ((x[0]*y[0] + 7*x[1]*y[1]) % P,
            (x[0]*y[1] + x[1]*y[0]) % P)

def eq_table(point):
    out = [(1, 0)]
    for r in point:
        comp = ((1-r[0]) % P, -r[1] % P)
        out = [z for v in out for z in (mul(v, comp), mul(v, r))]
    return out

def direct_eq(point, index):
    # Independent MSB cube definition and explicit polynomial multiplication.
    a, b = 1, 0
    for k, (u, v) in enumerate(point):
        if not (index >> (len(point)-1-k)) & 1:
            u, v = 1-u, -v
        a, b = (a*u + 7*b*v) % P, (a*v + b*u) % P
    return a, b

def native_reference(matrix, rows, cols, cs):
    out = []
    for c in cs:
        proof = []
        for i in range(rows):
            acc = (0, 0)
            for j in range(cols):
                v = matrix[i*cols+j]
                if v:
                    # Native sign embedding + per-term modular reductions.
                    fv = v % P
                    acc = add(acc, (c[j][0]*fv % P, c[j][1]*fv % P))
            proof.append(acc)
        out.append(proof)
    return out

def integer_oracle(matrix, rows, cols, cs):
    # Independent exact signed integer dot, reduced only at each output.
    return [[tuple(sum(matrix[i*cols+j]*c[j][limb] for j in range(cols)) % P
                   for limb in (0, 1)) for i in range(rows)] for c in cs]

def batch_fold(matrix, rows, cols, cs, tile, mutation=None):
    if rows <= 0 or cols <= 0 or tile <= 0 or not cs:
        raise ValueError('positive shape/tile/batch required by prototype')
    if len(matrix) != rows*cols or any(len(c) != cols for c in cs):
        raise ValueError('length mismatch')
    if any(not -128 <= v <= 127 for v in matrix):
        raise ValueError('i8 range')
    if any(not 0 <= limb < P for c in cs for v in c for limb in v):
        raise ValueError('noncanonical field input')
    b = len(cs)
    out = [[(0, 0)]*rows for _ in cs]
    counts = dict(weight_bytes=0, coefficient_bytes=0, output_bytes=0,
                  accumulator_init_bytes=0, accumulator_update_bytes=0,
                  coefficient_local_read_bytes=0, arithmetic_terms=0,
                  max_live_accumulator_bytes=0, max_live_coefficient_bytes=16*b)
    end = rows - (rows % tile) if mutation == 'drop_tail' else rows
    for start in range(0, end, tile):
        nr = min(tile, rows-start)
        acc = [[(0, 0)]*nr for _ in cs]
        counts['max_live_accumulator_bytes'] = max(counts['max_live_accumulator_bytes'], 16*b*nr)
        counts['accumulator_init_bytes'] += 16*b*nr
        for j in range(cols):
            coeff = [cs[0 if mutation == 'stale_challenge' else k][j] for k in range(b)]
            counts['coefficient_bytes'] += 16*b
            for i in range(nr):
                v = matrix[(start+i)*cols+j]
                counts['weight_bytes'] += 1
                if mutation == 'unsigned':
                    v &= 255
                if not v:
                    continue
                for k, (a, c) in enumerate(coeff):
                    if mutation == 'drop_extension':
                        c = 0
                    x, y = acc[k][i]
                    acc[k][i] = ((x+v*a) % P, (y+v*c) % P)
                    counts['arithmetic_terms'] += 1
                    counts['accumulator_update_bytes'] += 32
                    counts['coefficient_local_read_bytes'] += 16
        for k in range(b):
            out[k][start:start+nr] = acc[k]
            counts['output_bytes'] += 16*nr
    return out, counts

def analytical(rows, cols, b, tile, nnz):
    # Boundary traffic assumes coefficients/accumulators remain local while live.
    coeff = 16*b*cols*((rows+tile-1)//tile)
    output = 16*b*rows
    separate = b*rows*cols + coeff + output
    batched = rows*cols + coeff + output
    return dict(rows=rows, cols=cols, batch=b, row_tile=tile,
                independent_tiled_weight_bytes=b*rows*cols,
                batched_weight_bytes=rows*cols, coefficient_bytes=coeff,
                output_bytes=output, independent_resident_bytes=separate,
                batched_resident_bytes=batched,
                resident_reduction_fraction=1-batched/separate,
                accumulator_init_bytes=output, accumulator_update_bytes=32*b*nnz,
                coefficient_local_read_bytes=16*b*nnz,
                live_accumulator_bytes=16*b*min(rows,tile),
                live_coefficient_bytes=16*b,
                arithmetic_terms=b*nnz,
                caveat='Logical counts, not DRAM. Fair baseline uses same row tile. Local spills/cache lines/allocations/control/eq construction excluded from resident boundary; local accesses separately reported.')

def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*2**20, 512*2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    start = time.perf_counter()
    rng = random.Random(SEED)
    cases, eq_checks, outputs, mle_checks = [], 0, 0, 0
    for rows, cols in [(1,1),(3,4),(8,8),(13,16),(32,64),(65,128)]:
        for mode in ['dense','sparse','padded','zero']:
            matrix = [rng.randrange(-128,128) for _ in range(rows*cols)]
            matrix[:min(4,len(matrix))] = [-128,127,-1,0][:min(4,len(matrix))]
            if mode == 'sparse':
                matrix = [v if k%7==0 else 0 for k,v in enumerate(matrix)]
            if mode == 'padded':
                matrix = [v if k//cols < max(1,rows-2) and k%cols < max(1,cols-3) else 0 for k,v in enumerate(matrix)]
            if mode == 'zero':
                matrix = [0]*len(matrix)
            for b in [1,2,4,8]:
                points = [[(rng.randrange(P),rng.randrange(P)) for _ in range(cols.bit_length()-1)] for _ in range(b)]
                if cols > 1:
                    points[0][0] = (0,0) if mode == 'sparse' else ((1,0) if mode == 'padded' else (P-1,P-1))
                cs = [eq_table(pt) for pt in points]
                for pt,c in zip(points,cs):
                    assert c == [direct_eq(pt,j) for j in range(cols)]
                    eq_checks += cols
                want = integer_oracle(matrix,rows,cols,cs)
                assert native_reference(matrix,rows,cols,cs) == want
                for tile in [1,3,8,32]:
                    got, counts = batch_fold(matrix,rows,cols,cs,tile)
                    assert got == want
                    nnz = sum(v!=0 for v in matrix)
                    model = analytical(rows,cols,b,tile,nnz)
                    assert counts['weight_bytes'] == model['batched_weight_bytes']
                    for k in ['coefficient_bytes','output_bytes','accumulator_init_bytes','accumulator_update_bytes','coefficient_local_read_bytes','arithmetic_terms']:
                        assert counts[k] == model[k]
                    assert counts['max_live_accumulator_bytes'] == model['live_accumulator_bytes']
                    cases.append(dict(rows=rows,cols=cols,batch=b,tile=tile,mode=mode))
                    outputs += b*rows
                # Independently contract original matrix along both dimensions.
                rp = [(rng.randrange(P),rng.randrange(P)) for _ in range((rows-1).bit_length())]
                for k in range(b):
                    lhs = (0,0)
                    rhs = (0,0)
                    for i in range(rows):
                        er = direct_eq(rp,i)
                        lhs = add(lhs,mul(er,want[k][i]))
                        for j in range(cols):
                            ec = direct_eq(points[k],j)
                            x,y = mul(er,ec)
                            v = matrix[i*cols+j]
                            rhs = add(rhs,(x*v%P,y*v%P))
                    assert lhs == rhs
                    mle_checks += 1
    # Canonical extrema coefficients need not come from an equality table.
    matrix = [-128,127,0,1, -1,2,-3,4, 5,-6,7,-8, 9,10,11,12, 13,14,15,16]
    cs = [[(P-1,P-1),(0,1),(1,0),(P-2,P-3)],[(3,4),(5,6),(7,8),(9,10)]]
    want = integer_oracle(matrix,5,4,cs)
    assert batch_fold(matrix,5,4,cs,3)[0] == native_reference(matrix,5,4,cs) == want
    negatives = {m:batch_fold(matrix,5,4,cs,3,m)[0]!=want for m in ['stale_challenge','unsigned','drop_extension','drop_tail']}
    changed = matrix.copy(); changed[0] += 1
    negatives['mixed_model_reuse'] = batch_fold(matrix,5,4,cs,3)[0][1] != integer_oracle(changed,5,4,[cs[1]])[0]
    dirty = matrix.copy(); dirty[-1] = 0
    negatives['dirty_padding'] = batch_fold(matrix,5,4,cs,3)[0] != integer_oracle(dirty,5,4,cs)
    negatives['proof_order_swap'] = want[::-1] != want
    # Same shape/labels cannot authorize sharing matrices with different bytes.
    key = lambda m: hashlib.sha256(bytes(v%256 for v in m)).hexdigest()
    negatives['model_key_digest'] = key(changed) != key(matrix)
    assert all(negatives.values())
    refused = 0
    for args in [(matrix[:-1],5,4,cs,3),(matrix,5,4,[cs[0][:-1]],3),(matrix,5,4,cs,0),(matrix,5,4,[],3),([128]+matrix[1:],5,4,cs,3),(matrix,5,4,[[(P,0)]*4],3)]:
        try: batch_fold(*args)
        except ValueError: refused += 1
        else: raise AssertionError('missing fixture refusal')
    traffic = [analytical(1024,4096,b,t,1024*4096) for b in [1,2,4,8] for t in [1,3,8,32]]
    (HERE/'traffic.json').write_text(json.dumps(traffic,indent=2)+'\n')
    cpu = next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name'))
    result = dict(status='passed',run_identity='20260926T215233Z-c6bf3a4b',seed=SEED,
                  threads=1,cpu=cpu,platform=platform.platform(),python=platform.python_version(),
                  cpu_affinity=sorted(os.sched_getaffinity(0)),estimated_memory_mib=32,
                  limits=dict(wall_s=59,cpu_s=55,address_space_mib=512),
                  differential_cases=len(cases)+1,field_outputs_compared=outputs+10,
                  independent_eq_entries=eq_checks,independent_matrix_mles=mle_checks,
                  negative_controls=negatives,fixture_refusals=refused,cases=cases,
                  elapsed_s=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  proving_s=None,verification_s=None,complete_readiness_s=None,
                  source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))

if __name__ == '__main__':
    main()
