import hashlib
import itertools
import json
import math
import random
import resource
import time
from pathlib import Path

import model as m
import reference as ref

ROOT = Path(__file__).resolve().parent
SEED = 202610260126
rng = random.Random(SEED)
checks = 0
controls = []


def check(v, label):
    global checks
    assert v, label
    checks += 1


def rand():
    return m.E(rng.randrange(m.P), rng.randrange(m.P))


def control(name, condition):
    check(condition, name)
    controls.append(name)


def transcript_challenge(state, row):
    # Diagnostic only: deliberately a SHA256 mock, not native keyed BLAKE3.
    state = hashlib.sha256(state + b''.join(x.wire() for x in row)).digest()
    return state, m.E(int.from_bytes(state[:8], 'little'), int.from_bytes(state[8:16], 'little'))


def verify(rows, degree, n_rounds, initial, evaluator, state):
    if len(rows) != n_rounds:
        return ('round_count',)
    claim, challenges = initial, []
    for j,row in enumerate(rows):
        if len(row) != degree + 1:
            return ('degree', j)
        if row[0].add(row[1]) != claim:
            return ('sum_identity', j)
        state, r = transcript_challenge(state, row)
        challenges.append(r.pair())
        claim = evaluator(row, r)
    return ('ok', claim.pair(), challenges, state.hex())


def main():
    start = time.monotonic()
    for k,c in enumerate(m.INVFACT):
        check(c * math.factorial(k) % m.P == 1, 'inverse factorial')
    cases = []
    for size in range(9):
        for family in range(12):
            values = ([m.E() for _ in range(size)] if family == 0 else
                      [m.E(m.P-1,m.P-1) for _ in range(size)] if family == 1 else
                      [m.E(i, i*i) for i in range(size)] if family == 2 else
                      [rand() for _ in range(size)])
            coeffs = ref.coefficients([v.pair() for v in values])
            points = [m.E(i) for i in range(size+2)] + [m.E(m.P-1), m.E(0,1), m.E(1,1)] + [rand() for _ in range(8)]
            for x in points:
                old, new = m.literal(values, x), m.prepared(values, x)
                expected = ref.evaluate(coeffs, x.pair())
                check(old.pair() == expected, 'literal/original monomials')
                check(new.pair() == expected, 'prepared/original monomials')
                check(old.wire() == new.wire(), 'canonical bytes')
            cases.append({'samples': size, 'family': family, 'points': len(points)})
    rows_tested, chain_cases, chain_rounds = 0, 0, 0
    fresh_hashes = set()
    for n in range(1,6):
        for degree in range(2,6):
            for repeat in range(2):
                tables = [[rand().pair() for _ in range(1<<n)] for _ in range(degree)]
                masks = [rand().pair() for _ in range(2+n*degree)]
                fresh_hashes.add(hashlib.sha256(repr(masks).encode()).hexdigest())
                def full(point):
                    return ref.masked_polynomial(tables, point, masks, degree)
                prefix, rows = [], []
                state0 = hashlib.sha256(f'{SEED}/{n}/{degree}/{repeat}'.encode()).digest()
                state = state0
                initial = m.E(*ref.add((0,0),(0,0)))
                for bits in itertools.product((0,1), repeat=n):
                    initial = initial.add(m.E(*full([(b,0) for b in bits])))
                previous_claim = initial
                for j in range(n):
                    row = []
                    for sample in range(degree+1):
                        acc = (0,0)
                        for suffix in itertools.product((0,1), repeat=n-j-1):
                            point = prefix + [(sample,0)] + [(b,0) for b in suffix]
                            acc = ref.add(acc, full(point))
                        row.append(m.E(*acc))
                    check(row[0].add(row[1]) == previous_claim, 'direct cube sum identity')
                    state, x = transcript_challenge(state,row)
                    direct = (0,0)
                    for suffix in itertools.product((0,1), repeat=n-j-1):
                        direct = ref.add(direct, full(prefix+[x.pair()]+[(b,0) for b in suffix]))
                    check(m.literal(row,x).pair() == direct, 'masked literal direct cube')
                    check(m.prepared(row,x).pair() == direct, 'masked prepared direct cube')
                    # The actual recovery use is unmasked; check f separately.
                    unmasked = []
                    for sample in range(degree+1):
                        acc = (0,0)
                        for suffix in itertools.product((0,1), repeat=n-j-1):
                            point=prefix+[(sample,0)]+[(b,0) for b in suffix]
                            v=(1,0)
                            for table in tables:
                                v=ref.mul(v,ref.direct_mle(table,point))
                            acc=ref.add(acc,v)
                        unmasked.append(m.E(*acc))
                    check(m.literal(unmasked,x)==m.prepared(unmasked,x), 'unmasked recovery interpolation')
                    prefix.append(x.pair())
                    previous_claim=m.E(*direct)
                    rows.append(row)
                    rows_tested += 2
                expected = verify(rows,degree,n,initial,m.literal,state0)
                check(expected == verify(rows,degree,n,initial,m.prepared,state0), 'mock transcript chain')
                check(expected[1] == full(prefix), 'direct terminal closure')
                variants = [(rows[:-1], n, initial),
                            ([rows[0][:-1]]+rows[1:], n, initial),
                            (rows, n, initial.add(m.E(1))),
                            ([[rows[0][0].add(m.E(1))]+rows[0][1:]]+rows[1:],n,initial)]
                for bad,count,claim in variants:
                    a=verify(bad,degree,count,claim,m.literal,state0)
                    b=verify(bad,degree,count,claim,m.prepared,state0)
                    check(a==b and a[0]!='ok','matching diagnostic refusal')
                chain_cases+=1
                chain_rounds+=n
    control('fresh synthetic CFS coefficients per fixture', len(fresh_hashes)==40)
    v=[m.E(i*i+3*i+7, 11+i**3) for i in range(6)]
    x=m.E(21,19)
    wrong=list(m.INVFACT);wrong[3]=(wrong[3]+1)%m.P
    control('wrong inverse factorial detected',m.prepared(v,x,wrong)!=m.literal(v,x))
    control('reversed node order detected',m.prepared(v[::-1],x)!=m.literal(v,x))
    control('stale challenge result detected',m.prepared(v,m.E(20,19))!=m.literal(v,x))
    control('dropped extension coordinate detected',m.prepared(v,m.E(x.a))!=m.literal(v,x))
    control('changed mask coefficients detected',ref.masked_polynomial([[(1,2),(3,4)]],[(2,3)],[(1,1),(2,2),(3,3),(4,4)],2)!=ref.masked_polynomial([[(1,2),(3,4)]],[(2,3)],[(2,1),(2,2),(3,3),(4,4)],2))
    control('empty inherited result',m.prepared([],x)==m.E())
    control('single inherited result',m.prepared([v[0]],x)==v[0])
    control('high degree generic fallback',m.prepared(v+v[:2],x)==m.literal(v+v[:2],x))
    control('nodes need no challenge inversion',all(m.prepared(v,m.E(i))==v[i] for i in range(6)))
    counts=[]
    for size in range(2,7):
        line={'samples':size,'degree':size-1}
        for name,fn in [('literal',m.literal),('prepared',m.prepared)]:
            m.OPS.clear();m.COUNT=True
            fn(v[:size],x)
            m.COUNT=False
            line[name]=dict(m.OPS)
        counts.append(line)
    result={'status':'PASS_ARITHMETIC_MODEL_ONLY','seed':SEED,'checks':checks,
            'interpolation_fixtures':len(cases),'point_evaluations':sum(x['points'] for x in cases),
            'masked_chain_cases':chain_cases,'masked_chain_rounds':chain_rounds,
            'rows_tested_masked_plus_unmasked':rows_tested,'control_types':len(controls),
            'controls':controls,'per_call_source_api_counts':counts,
            'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'native_proofs':0,'oracle':'Separate local Vandermonde solve / direct original cube; both implementations researcher-authored',
            'transcript':'SHA256 mock only; no native BLAKE3/CFS/PCS proof or privacy test'}
    (ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
