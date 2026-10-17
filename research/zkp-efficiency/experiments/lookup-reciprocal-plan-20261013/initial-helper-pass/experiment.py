#!/usr/bin/env python3
"""Cycle0046: refinement of cycle0004; synthetic CPU correctness/accounting."""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time
from field_model import P, ZERO, ONE, REFUSAL, counts, den, mul, native_reference, batch
from candidate import prepare, hybrid, write_into
from independent import solve, table_helpers

HERE = Path(__file__).resolve().parent
SEED = 2026101346

def outcome(fn, *args, **kwargs):
    try:
        return ('ok', fn(*args, **kwargs))
    except ZeroDivisionError as exc:
        return ('refuse', str(exc))

def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*2**20, 512*2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(19)
    started = time.monotonic()
    rng = random.Random(SEED)
    point = lambda: (rng.randrange(P), rng.randrange(P))
    checked = dict(fixtures=0, schedules=0, independent_words=0,
                   comparisons=0, refusal_schedules=0, table_helpers=0,
                   table_helper_words=0, split_plane_sentinel_checks=0,
                   formula_checks=0)
    digest = hashlib.sha256()
    details, controls = [], []
    def check(pairs, table, alpha, beta, tag, chunks, name):
        checked['fixtures'] += 1
        oracle = outcome(solve, pairs, alpha, beta, tag)
        ref = outcome(native_reference, pairs, alpha, beta, tag, counts())
        assert ref == oracle, name
        if ref[0] == 'ok':
            checked['independent_words'] += len(pairs)
            for a, b in oracle[1]:
                digest.update(a.to_bytes(8, 'little')+b.to_bytes(8, 'little'))
        for k in chunks:
            c = counts()
            got = outcome(hybrid, pairs, table, alpha, beta, tag, k, c)
            assert got == oracle, (name, k)
            checked['schedules'] += 1
            checked['comparisons'] += 1
            if got[0] == 'refuse':
                checked['refusal_schedules'] += 1
            else:
                checked['split_plane_sentinel_checks'] += 1
                hits = sum(0 <= i < len(table) and v == table[i] for i, v in pairs)
                use_cache = len(pairs) >= len(table)
                expected_hits = hits if use_cache else 0
                u = len(pairs)-expected_hits
                fb_chunks = sum(any(not (use_cache and 0 <= i < len(table) and v == table[i])
                    for i, v in pairs[j:j+k]) for j in range(0, len(pairs), k))
                cache_nz = sum(den(i, v, alpha, beta, tag) != ZERO for i, v in enumerate(table)) if use_cache else 0
                assert c['cache_hits'] == expected_hits and c['fallback'] == u
                assert c['batch_mul'] == 3*(cache_nz+u)
                assert c['inversions'] == int(cache_nz > 0)+fb_chunks
                assert c['max_fallback_words'] <= k
                assert c['destination_writes'] == len(pairs)
                checked['formula_checks'] += 5
            details.append({'name':name, 'chunk':k, 'length':len(pairs), 'table':len(table),
                            'outcome':got[0], 'counts':c})
    for m in [1, 4, 16, 256]:
        tables = [tuple(1000-i*3 for i in range(m)),
                  tuple((i-128)**3 for i in range(m)),
                  tuple((-(1<<63) if i == 0 else (1<<63)-1 if i == m-1 else i)
                        for i in range(m))]
        for table in tables:
            for n in [0, 1, 31, 257, 1025]:
                base = [(rng.randrange(m), 0) for _ in range(n)]
                valid = [(i, table[i]) for i, _ in base]
                mixed = list(valid)
                for j in range(0, n, 7):
                    i, v = mixed[j]
                    mixed[j] = ((-1 if j % 2 else m+3), v+1)
                for mode, pairs in [('valid',valid), ('mixed',mixed)]:
                    alpha, beta, tag = point(), point(), point()
                    check(pairs, table, alpha, beta, tag, [1, 7, 256, 1024],
                          f'{m}/{n}/{tables.index(table)}/{mode}')
                # beta0 permits different values to compress identically.
                check(mixed, table, point(), ZERO, point(), [7, 1024], f'{m}/{n}/beta0')
    # Large valid and invalid-heavy refinements, not timing benchmarks.
    table = tuple(8192-i*23 for i in range(256))
    alpha, beta, tag = point(), point(), point()
    for n, mode in [(16384,'valid'), (16385,'mixed'), (257,'invalid')]:
        pairs = [(j%256, table[j%256]) for j in range(n)]
        if mode == 'invalid':
            pairs = [(i, v+1) for i, v in pairs]
        elif mode == 'mixed':
            pairs = [(i, v+(j%19==0)) for j, (i,v) in enumerate(pairs)]
        check(pairs, table, alpha, beta, tag, [7,256,1024], f'large/{mode}')
    # Used/unused public zeros, compression collisions, and malformed pairs.
    small = (19, 17, 15, 13)
    beta, tag = (1,0), (9,12)  # beta=1/2 below causes all i+beta*v=19/2
    collision_beta = (pow(2,-1,P), 0)
    cases = []
    for i in range(4):
        a = den(i, small[i], ZERO, beta, tag)
        alpha0 = ((-a[0])%P, (-a[1])%P)
        cases += [(f'usedzero/{i}', [(i,small[i])]*8, small, alpha0,beta,tag),
                  (f'unusedzero/{i}', [((i+1)%4,small[(i+1)%4])]*8,small,alpha0,beta,tag)]
    a = den(0,small[0],ZERO,collision_beta,tag)
    alpha0 = ((-a[0])%P,(-a[1])%P)
    cases += [('allpubliczero/empty',[],small,alpha0,collision_beta,tag),
              ('allpubliczero/offtable',[(9,111)]*5,small,alpha0,collision_beta,tag),
              ('allpubliczero/used',[(1,small[1])]*5,small,alpha0,collision_beta,tag)]
    for i, v in [(-1,17),(256,19), (3,small[3]+1), (-(1<<63),(1<<63)-1), ((1<<63)-1,-(1<<63))]:
        a = den(i,v,ZERO,beta,tag)
        alpha0 = ((-a[0])%P,(-a[1])%P)
        cases.append((f'offzero/{i}',[(0,small[0]),(i,v)],small,alpha0,beta,tag))
    for name,pairs,t,a,b,g in cases:
        check(pairs,t,a,b,g,[1,3,7],name)
        # Later full public-table stage remains mandatory, including unused zeros.
        for length in [len(t), len(t)*4]:
            expected = outcome(table_helpers,t,pairs,a,b,g,length)
            tv = [(j%len(t),t[j%len(t)]) for j in range(length)]
            iv = outcome(native_reference,tv,a,b,g,counts())
            if iv[0] == 'refuse':
                assert expected == iv
            else:
                hist=[0]*len(t)
                for i,v in pairs:
                    hist[i if 0 <= i < len(t) and t[i]==v else 0] += 1
                got=[(x*(hist[j] if j<len(t) else 0)%P,y*(hist[j] if j<len(t) else 0)%P)
                     for j,(x,y) in enumerate(iv[1])]
                assert expected == ('ok',got)
            checked['table_helpers'] += 1
            checked['table_helper_words'] += length
    # Negative controls must distinguish wrong arithmetic/state/lifetime policies.
    def control(name, predicate):
        assert predicate, name
        controls.append(name)
    t=(19,17,15,13); a,b,g=(987,4),(31,5),(42,9)
    pairs=[(1,t[1]+1)]*5
    control('index-only-cache-ignores-value', solve(pairs,a,b,g)!=solve([(1,t[1])]*5,a,b,g))
    control('wrapped-negative-index', solve([(-1,13)],a,b,g)!=solve([(3,13)],a,b,g))
    control('out-of-range-index-mod-table',solve([(5,17)],a,b,g)!=solve([(1,17)],a,b,g))
    for name,ta,aa,bb,gg in [('alpha',t,(a[0]+1,a[1]),b,g),('beta',t,a,(b[0],b[1]+1),g),
                          ('tag',t,a,b,(g[0]+1,g[1])),('public',tuple(x+1 for x in t),a,b,g)]:
        plan=prepare(t,a,b,g,counts())
        try:
            hybrid([(0,ta[0])]*8,ta,aa,bb,gg,3,counts(),plan=plan)
            raise AssertionError('stale accepted')
        except ValueError as exc:
            control('stale-'+name, str(exc)=='stale public/challenge plan')
        control('unchecked-stale-'+name, solve([(0,ta[0])],aa,bb,gg)!=[plan.reciprocals[0]])
    control('wrong-imaginary-sign',solve([(0,t[0])],a,b,g)[0][1] != (-solve([(0,t[0])],a,b,g)[0][1])%P)
    control('wrong-extension-nonresidue',7 != 1 and mul((0,1),(0,1))==(7,0))
    for chunk,offset,size,name in [(0,0,8,'zerochunk'),(3,-1,8,'negative-offset'),(3,7,8,'short-destination')]:
        try:
            write_into([(0,19)]*8,t,a,b,g,chunk,[0]*size,[0]*size,offset,counts())
            raise AssertionError('invalid geometry accepted')
        except ValueError:
            controls.append(name)
    for i in [0,3]:
        aa0=((i+b[0]*t[i]+g[0])%P,(b[1]*t[i]+g[1])%P)
        unused=[((i+1)%4,t[(i+1)%4])]*5
        control('unused-zero-not-early-refusal-'+str(i), outcome(hybrid,unused,t,aa0,b,g,3,counts())[0]=='ok')
        control('unused-zero-still-late-table-refusal-'+str(i),outcome(table_helpers,t,unused,aa0,b,g,16)[0]=='refuse')
    # Chunk-sparse fallback count does NOT equal ceil(number of invalid words/K).
    sparse=[(j%4,t[j%4]) for j in range(16)]
    sparse[0]=(0,t[0]+1); sparse[8]=(0,t[0]+1)
    c=counts(); hybrid(sparse,t,a,b,g,8,c)
    control('sparse-fallback-chunks-not-ceil-count',c['fallback_chunks']==2 and (2+7)//8==1)
    native_paths = json.loads((HERE/'native-pins.json').read_text())
    for p in native_paths:
        assert hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256']
    # Historical phase scope: refresh from native immutable raw log, no invented timing.
    result=dict(run_id='20261013T032555Z-3e60f70b',cycle='0046',status='pass',seed=SEED,
                counts=checked,controls=controls,control_count=len(controls),cases=details,
                digest_sha256=digest.hexdigest(),elapsed_seconds=time.monotonic()-started,
                peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(device='CPU only',cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),threads=1,affinity=list(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),python=platform.python_version()),
                resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
                code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,device='CPU only',steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
                limits=['Synthetic helper arithmetic and split-plane memory model, not honest/native witness or proof',
                        'Current native exp/act helper phase only0.197s; SC_SZC polynomial/PCS/masks untouched',
                        'Private partial writes discarded on refusal before H commit; native lifetime/transcript proof owed',
                        'No foreign code executed; no cached reciprocals across changed challenges/public identity',
                        'No native compiler/parallel/masked/frozen/refusal/privacy/peak/enclosing/GPU gates executed'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','counts','control_count','elapsed_seconds','peak_rss_kib','digest_sha256']},indent=2))

if __name__ == '__main__':
    main()
