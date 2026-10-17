#!/usr/bin/env python3
"""Locally authored synthetic TN/cache oracle. No native code or dependencies."""
from dataclasses import dataclass, replace
from pathlib import Path
import hashlib
import json
import os
import random
import resource
import signal
import struct
import time

ROOT = Path(__file__).resolve().parent
RUN = '20261004T070146Z-edcb9b00'
SEED = 2026100425


def signed(b):
    return b if b < 128 else b - 256


def align4(n):
    return (n + 3) // 4 * 4


@dataclass(frozen=True)
class Model:
    # Immutable synthetic tensor owner; hash once when loading, never per use.
    checkpoint: str
    layer: int
    tensor: str
    profile: str
    calibration: str
    epoch: int
    orientation: str
    kp: int
    np: int
    ld: int
    blob: bytes
    content_hash: str


def model(rng, kp, np, mode, extra, pattern):
    ld = (np if mode == 'in_out' else kp) + extra
    rows = kp if mode == 'in_out' else np
    w = [[rng.randint(-128, 127) if pattern == 'wide' else
          rng.randint(-2, 2) if pattern == 'small' else 0
          for _ in range(np)] for _ in range(kp)]
    if pattern == 'wide':
        w[0][0] = -128
    b = bytearray([71] * (rows * ld))  # dirty physical stride guards
    for k in range(kp):
        for j in range(np):
            b[k * ld + j if mode == 'in_out' else j * ld + k] = w[k][j] & 255
    blob = bytes(b)
    return Model('synthetic-A', 2, 'wd_t', 'synthetic-helper/1', 'synthetic-cal/1',
                 1, mode, kp, np, ld, blob, hashlib.sha256(blob).hexdigest())


def at(m, k, j):
    return signed(m.blob[k * m.ld + j if m.orientation == 'in_out' else j * m.ld + k])


def independent_matrix(m):
    # Decode storage one physical row at a time, independent of candidate indexing.
    width = m.np if m.orientation == 'in_out' else m.kp
    rows = m.kp if m.orientation == 'in_out' else m.np
    physical = [list(struct.unpack(f'{width}b', m.blob[r*m.ld:r*m.ld+width]))
                for r in range(rows)]
    return physical if m.orientation == 'in_out' else [list(c) for c in zip(*physical)]


def key(m, k0, kl, j0, jl):
    assert 0 <= k0 < m.kp and 0 < kl <= m.kp-k0
    assert 0 <= j0 < m.np and 0 < jl <= m.np-j0
    return (m.checkpoint, m.layer, m.tensor, m.profile, m.calibration, m.epoch,
            m.orientation, m.kp, m.np, m.ld, m.content_hash,
            k0, kl, j0, jl, 'TN-col-int8/1')


@dataclass(frozen=True)
class Packed:
    identity: tuple
    k0: int
    kl: int
    j0: int
    jl: int
    lda: int
    columns: int
    a: bytes
    sums: tuple
    borrowed: bool
    a0: int


def prepare(m, k0, kl, j0, jl, borrow=False):
    # A before transpose is KxN column-major; op(A)=T, B remains N.
    kp4, jp4 = align4(kl), align4(jl)
    sums = tuple(sum(at(m, k, j) for k in range(k0, k0+kl))
                 if j < j0+jl else 0 for j in range(j0, j0+jp4))
    # Borrow only a full, already aligned out_in tensor. Partial odd views pack.
    can_borrow = (borrow and m.orientation == 'out_in' and k0 == 0 and kl == m.kp
                  and kl % 4 == 0 and jl % 4 == 0 and m.ld % 4 == 0)
    if can_borrow:
        return Packed(key(m,k0,kl,j0,jl),k0,kl,j0,jl,m.ld,jp4,m.blob,sums,True,j0*m.ld)
    a = bytearray(jp4*kp4)
    for j in range(jl):
        for k in range(kl):
            a[j*kp4+k] = at(m,k0+k,j0+j) & 255
    return Packed(key(m,k0,kl,j0,jl),k0,kl,j0,jl,kp4,jp4,bytes(a),sums,False,0)


class Cache:
    def __init__(self):
        self.entries = {}
        self.builds = self.hits = self.hash_bytes_on_hits = 0

    def get(self,m,k0,kl,j0,jl,borrow):
        ident = key(m,k0,kl,j0,jl)
        if ident not in self.entries:
            self.entries[ident] = prepare(m,k0,kl,j0,jl,borrow)
            self.builds += 1
        else:
            self.hits += 1
        result = self.entries[ident]
        assert result.identity == ident, 'stale cache identity'
        return result


def audit(p,m):
    # Startup/test-only audit; a persisted/external cache must earn trust anew.
    assert p.identity == key(m,p.k0,p.kl,p.j0,p.jl), 'identity'
    oracle = independent_matrix(m)
    count = 0
    for j in range(p.columns):
        for k in range(align4(p.kl)):
            v = signed(p.a[p.a0+j*p.lda+k])
            expected = oracle[p.k0+k][p.j0+j] if k < p.kl and j < p.jl else 0
            assert v == expected, 'packed bytes'
            count += 1
        expected_sum = sum(row[p.j0+j] for row in oracle[p.k0:p.k0+p.kl]) if j < p.jl else 0
        assert p.sums[j] == expected_sum, 'column sum'
    return count


def raw_reference(m,x,mt,mp,xs):
    weights = independent_matrix(m)
    dst = [0]*(mp*m.np)
    for t in range(mt):
        for j in range(m.np):
            acc = 0
            for k,row in enumerate(weights):
                acc += x[t*xs+k]*row[j]
                assert -(1<<63) <= acc < (1<<63)
            dst[t*m.np+j] = acc
    return dst


def candidate(m,x,mt,mp,xs,jtile,ktile,cache,borrow):
    low = [0]*(mt*m.np); high = [0]*(mt*m.np); sw = [0]*m.np
    trace = []; gemm_words = 0
    for j0 in range(0,m.np,jtile):
        jl = min(jtile,m.np-j0)
        for k0 in range(0,m.kp,ktile):
            kl = min(ktile,m.kp-k0)
            p = cache.get(m,k0,kl,j0,jl,borrow)
            kb = align4(kl)
            b = bytearray(2*mt*kb)
            for t in range(mt):
                for i in range(kl):
                    v = x[t*xs+k0+i]
                    assert -32768 <= v <= 32767
                    b[t*kb+i] = ((v & 255)-128) & 255
                    b[(mt+t)*kb+i] = (v >> 8) & 255
            c = [0]*(p.columns*2*mt)
            for column in range(2*mt):
                for row in range(p.columns):
                    # Physical BLAS address: opA=T => A(inner,row).
                    value = sum(signed(p.a[p.a0+row*p.lda+i])*signed(b[column*kb+i])
                                for i in range(kb))
                    assert -(1<<31) <= value < (1<<31)
                    c[column*p.columns+row] = value
                    # Independent logical byte-product oracle, no candidate packing.
                    t = column % mt
                    want = 0
                    if row < jl:
                        for i in range(kl):
                            v = x[t*xs+k0+i]
                            piece = divmod(v,256)[1]-128 if column < mt else divmod(v,256)[0]
                            want += piece*independent_matrix_cached(m)[k0+i][j0+row]
                    assert value == want, 'physical TN result'
                    gemm_words += 1
            for row in range(jl):
                sw[j0+row] += p.sums[row]
                for t in range(mt):
                    q = t*m.np+j0+row
                    low[q] += c[t*p.columns+row]
                    high[q] += c[(mt+t)*p.columns+row]
            trace.append((j0,jl,k0,kl,p.columns,kb,p.lda,p.borrowed))
    out = [0]*(mp*m.np)
    for t in range(mt):
        for j in range(m.np):
            q = t*m.np+j
            out[q] = low[q]+256*high[q]+128*sw[j]
            assert -(1<<63) <= out[q] < (1<<63)
    return out,trace,gemm_words


ORACLE_MATRICES = {}
def independent_matrix_cached(m):
    if m not in ORACLE_MATRICES:
        ORACLE_MATRICES[m] = independent_matrix(m)
    return ORACLE_MATRICES[m]


def finish_ref(raw,mt,mp,np,nt,x1):
    z = [0]*(mp*np); r = [0]*(mp*np)
    for t in range(mt):
        for j in range(nt):
            i=t*np+j; q,rem=divmod(raw[i]+32,64)
            if not -32768 <= q <= 32767:
                return ('FFN down',i)
            z[i]=q; r[i]=rem
    for t in range(mt):
        for j in range(nt):
            i=t*np+j
            if not -32768 <= x1[i]+z[i] <= 32767:
                return ('residual 2',i)
    return ('accepted',struct.pack(f'{len(z)*2}q',*(z+r)))


def finish_candidate(raw,mt,mp,np,nt,x1):
    support=[t*np+j for t in range(mt) for j in range(nt)]
    q=[(raw[i]+32)>>6 for i in support]
    failures=[i for i,v in zip(support,q) if v < -32768 or v > 32767]
    if failures:
        return ('FFN down',min(failures))
    fails=[i for i,v in zip(support,q) if not -32768 <= x1[i]+v <= 32767]
    if fails:
        return ('residual 2',min(fails))
    z=[0]*(mp*np); rem=[0]*(mp*np)
    for i,v in zip(support,q):
        z[i]=v; rem[i]=raw[i]-(v<<6)+32
    return ('accepted',b''.join(v.to_bytes(8,'little',signed=True) for v in z+rem))


def accounting():
    # Counts only. No large allocations or speed assumptions.
    k,n,layers,builds=16384,4096,32,2
    full=k*n; sums=4*n; tile=k*128+4*128
    rows=[]
    for passes in (1,2,4,16):
        uses=passes*layers*builds
        for strategy,preps,peak in (
            ('rebuild every witness',uses,full+sums),
            ('one-layer cache per pass',passes*layers,full+sums),
            ('all-layer resident',layers,layers*(full+sums)),
            ('128-column cache per pass',passes*layers,tile)):
            rows.append(dict(passes=passes,strategy=strategy,weight_preprocess_epochs=preps,
                             consumed_weight_reads=preps*full,packed_weight_writes=preps*full,
                             packed_weight_upload_bytes=preps*full,
                             extra_cache_peak_bytes=peak,
                             original_weight_bytes=layers*full,
                             setup_hash_bytes_once=layers*full,
                             source='count-only unadmitted Llama3-8B metadata',
                             limits='uploads conditional on CPU packing; no proof speed, workspace, mirrors or original-drop claim'))
    return rows


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    start=time.monotonic(); rng=random.Random(SEED); digest=hashlib.sha256()
    cases=dots=packed_words=gemm_words=output_words=hits=builds=0
    outcomes={}; controls=[]; borrow_cases=0
    shapes=[(1,1,1,2,3,3),(3,5,5,4,8,8),(5,17,7,8,32,8),
            (3,7,9,4,7,12),(2,9,5,4,16,7),(4,8,8,4,8,8)]
    for mt,kt,nt,mp,kp,np in shapes:
        for orientation in ('in_out','out_in'):
            for extra in (0,1,4):
                for pattern in ('zero','small','wide'):
                    m=model(rng,kp,np,orientation,extra,pattern)
                    for jt,kk,borrow in ((np,kp,False),(4,kp,True),(3,3,False)):
                        cache=Cache(); prior_trace=None
                        for repetition in range(3):
                            # All padded inner coordinates participate; padded token rows do not.
                            xs=kp+1; x=[rng.choice((-32768,32767,128,-129,0,1))
                                       if pattern=='wide' else rng.randint(-64,64)
                                       for _ in range(mp*xs)]
                            x1=[rng.choice((-32768,32767,0)) for _ in range(mp*np)]
                            ref=raw_reference(m,x,mt,mp,xs)
                            got,trace,gw=candidate(m,x,mt,mp,xs,jt,kk,cache,borrow)
                            assert got == ref, 'raw dots'
                            if prior_trace is not None:
                                assert trace==prior_trace, 'value-dependent plan'
                            prior_trace=trace
                            a=finish_ref(ref,mt,mp,np,nt,x1)
                            b=finish_candidate(got,mt,mp,np,nt,x1)
                            assert a==b, 'support/remainder/refusal'
                            outcomes[a[0]]=outcomes.get(a[0],0)+1
                            if a[0]=='accepted': output_words+=mp*np*2
                            digest.update(struct.pack(f'{len(got)}q',*got))
                            cases+=1; dots+=mt*np; gemm_words+=gw
                        for p in cache.entries.values():
                            packed_words+=audit(p,m); borrow_cases+=int(p.borrowed)
                        assert cache.hits==2*cache.builds and cache.hash_bytes_on_hits==0
                        hits+=cache.hits; builds+=cache.builds
    # Identity controls distinguish content, orientation, dimensions, public calibration and epoch.
    m=model(rng,8,8,'in_out',1,'small'); c=Cache(); p=c.get(m,0,8,0,8,False)
    mutations={'checkpoint':'B','layer':3,'tensor':'wg_t','profile':'other',
               'calibration':'other','epoch':2,'orientation':'out_in','kp':7,'np':7,'ld':10,
               'content_hash':'f'*64}
    for name,v in mutations.items():
        changed=replace(m,**{name:v})
        try:
            audit(p,changed)
        except AssertionError as exc:
            controls.append({'name':'stale '+name,'detected':str(exc)})
        else: raise AssertionError(name)
    for name,bad in (('corrupt packed bytes',replace(p,a=bytes([p.a[0]^1])+p.a[1:])),
                     ('corrupt column sum',replace(p,sums=(p.sums[0]+1,)+p.sums[1:])),
                     ('wrong packed leading dimension',replace(p,lda=p.lda+1)),
                     ('wrong K range',replace(p,k0=1,kl=7)),
                     ('wrong output range',replace(p,j0=1,jl=7))):
        try: audit(bad,m)
        except (AssertionError,IndexError) as exc:
            controls.append({'name':name,'detected':str(exc)})
        else: raise AssertionError(name)
    # Show why identity hashes must be recomputed for a new immutable tensor owner.
    altered=bytes([m.blob[0]^1])+m.blob[1:]
    assert hashlib.sha256(altered).hexdigest()!=m.content_hash
    controls.append({'name':'changed weights with reused caller label','detected':'new content digest differs'})
    # Dirty internal K is consumed, never narrowed to the nominal true inner dimension.
    v=Model('A',0,'wd','p','c',1,'in_out',8,4,4,bytes([0]*28+[1,0,0,0]),'synthetic')
    x=[0]*7+[256]; ref=raw_reference(v,x,1,1,8)
    assert ref[0]==256 and sum(x[k]*at(v,k,0) for k in range(7))==0
    controls.append({'name':'trim internal K','expected':256,'wrong':0})
    # Full-K sums cannot be substituted into every split-K tile.
    p0=prepare(v,0,4,0,4); p1=prepare(v,4,4,0,4)
    assert p0.sums[0]+p1.sums[0]==1
    controls.append({'name':'full sum per K tile','expected_correction':128,'wrong':256})
    # Omitting the centered-byte correction changes even a simple exact identity.
    assert (-128)*1+128*1==0
    controls.append({'name':'omit offset correction','expected':0,'wrong':-128})
    # Borrow alignment and dirty guard controls: public decision forces packing.
    out=model(rng,8,8,'out_in',1,'small'); odd=prepare(out,0,8,0,8,True)
    assert not odd.borrowed and odd.lda==8
    controls.append({'name':'borrow odd source stride','detected':'packed aligned copy required'})
    cpu=next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
              if line.startswith('model name')),'unknown')
    result=dict(run_identity=RUN,seed=SEED,status='pass',cases=cases,raw_dots=dots,
                independent_packed_words=packed_words,physical_TN_byte_outputs=gemm_words,
                accepted_plane_words=output_words,outcomes=outcomes,cache_builds=builds,
                cache_hits=hits,hash_bytes_on_cache_hits=0,borrowed_entries=borrow_cases,
                controls=controls,control_count=len(controls),digest=digest.hexdigest(),
                count_only_cache_schedules=accounting(),elapsed_s=time.monotonic()-start,
                peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                threads=1,affinity=sorted(os.sched_getaffinity(0)),cpu=cpu,device='CPU only',
                synthetic_contexts=[s[0] for s in shapes],estimated_memory_mib=64,
                RLIMIT_AS_mib=512,alarm_s=59,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                scope='synthetic TN arithmetic, identity and count model; no CUDA/native witness/proof/RNG/transcript',
                actual_gpu_speedup=None,actual_end_to_end_saved_s=None,
                full_stack=dict(countable_tokens=0,passes=0,context_length=None,
                                steady_tokens_per_s=None,total_tokens_per_s=None,startup_fraction=None,
                                witness_s=None,proof_s=None,serialization_s=None,verification_s=None,
                                proof_latency_s=None,proof_lag_s=None,pipeline_drain_s=None))
    (ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('controls','count_only_cache_schedules')},indent=2))


if __name__=='__main__':
    main()
