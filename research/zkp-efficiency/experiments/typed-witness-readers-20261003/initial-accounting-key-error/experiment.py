#!/usr/bin/env python3
"""Synthetic exact typed readers and lazy LogUp preparation, CPU only."""
import functools
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')
SOURCE = ROOT / 'ops/zkp-mvp/sonnet-hardening/hashline/src/private_block'
SEED = 2026100317
RUN = '20261003T230146Z-65ad9aeb'
P = 2**64 - 2**32 + 1
MASK64 = 2**64 - 1
ZERO = (0, 0)
REFUSAL = 'zero LogUp denominator; discard attempt'


class Plane:
    """Private immutable metadata, exact indexed decode; no full i64 expansion."""
    def __init__(self, values):
        if any(type(v) is not int or not -2**63 <= v < 2**63 for v in values):
            raise ValueError('not i64')
        lo, hi = (min(values), max(values)) if values else (0, 0)
        self.signed = lo < 0
        for self.width in (1, 2, 4, 8):
            low = -2**(8*self.width-1) if self.signed else 0
            high = 2**(8*self.width-int(self.signed))
            if low <= lo and hi < high:
                break
        self.count = len(values)
        self.blob = b''.join(v.to_bytes(self.width, 'little', signed=self.signed) for v in values)

    def __len__(self):
        return self.count

    def get(self, i):
        if not 0 <= i < self.count:
            raise IndexError('plane index')
        j = i*self.width
        return int.from_bytes(self.blob[j:j+self.width], 'little', signed=self.signed)

    def fp(self, i):
        v = self.get(i)
        return v if v >= 0 else P - (-v % P)


def wrap(v):
    v &= MASK64
    return v if v < 2**63 else v - 2**64


def affine(planes, spec, i):
    constant, terms = spec
    acc = constant
    for name, coefficient in terms:
        acc = wrap(acc + wrap(coefficient * planes[name].get(i)))
    return acc


def affine_ref(raw, spec, i):
    constant, terms = spec
    value = constant + sum(coefficient*raw[name][i] for name, coefficient in terms)
    return (value + 2**63) % 2**64 - 2**63


def add(a, b):
    return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)


def sub(a, b):
    return ((a[0]-b[0]) % P, (a[1]-b[1]) % P)


def mul(a, b):
    return ((a[0]*b[0]+7*a[1]*b[1]) % P, (a[0]*b[1]+a[1]*b[0]) % P)


def inv(a):
    if a == ZERO:
        raise ValueError(REFUSAL)
    norm = (a[0]*a[0]-7*a[1]*a[1]) % P
    ni = pow(norm, P-2, P)
    return (a[0]*ni % P, -a[1]*ni % P)


def convolution(a, b):
    # Independent polynomial convolution and u^2 = 7 reduction.
    words = [0, 0, 0]
    for i in range(2):
        for j in range(2):
            words[i+j] += a[i]*b[j]
    return ((words[0]+7*words[2]) % P, words[1] % P)


@functools.lru_cache(maxsize=16384)
def inv_ref(a):
    if a == ZERO:
        raise ValueError(REFUSAL)
    exponent = P*P-2
    result = (1, 0)
    while exponent:
        if exponent & 1:
            result = convolution(result, a)
        a = convolution(a, a)
        exponent >>= 1
    return result


def delta(planes, tp, i):
    ht, j = divmod(i, tp)
    score = planes['s8'].get(i) if j <= ht % tp else -127
    return wrap(planes['mx'].get(ht)-score)


def delta_ref(raw, tp, i):
    head, row, col = i//(tp*tp), (i//tp) % tp, i % tp
    value = raw['s8'][head*tp*tp+row*tp+col] if row >= col else -127
    return (raw['mx'][head*tp+row]-value+2**63) % 2**64-2**63


def denominator(index, value, alpha, beta, tag):
    return sub(alpha, add(add((index % P, 0), mul(beta, (value % P, 0))), tag))


def histogram(values):
    bins = [0]*256
    for v in values:
        bins[v if 0 <= v < 256 else 0] += 1
    return bins


def a_bytes(planes, reference=False):
    out = bytearray()
    offsets = []
    for name, plane in planes.items():
        offsets.append(len(out))
        values = plane if reference else (plane.fp(i) for i in range(len(plane)))
        for value in values:
            out.extend(struct.pack('<Q', value % P))
        # Disjoint row padding, not a native layout/commitment.
        out.extend(bytes(8*((-len(plane)) % 8)))
    return bytes(out), offsets


def prepare(raw, specs, tp, alpha, beta, gu8, gexp, gact, exp, act, lazy):
    planes = {name: Plane(v) for name, v in raw.items()} if lazy else raw
    length = len(raw['s8'])
    get = (lambda name, i: planes[name].get(i)) if lazy else (lambda name, i: raw[name][i])
    if lazy:
        column = lambda k: (affine(planes, specs[k], i) for i in range(length))
        # Only 256 counters persist; recompute values in the helper pass.
        hist = histogram(v for k in range(len(specs)) for v in column(k))
        ds = lambda: (delta(planes, tp, i) for i in range(length))
        ais = lambda: (get('g8', i)+128 for i in range(length))
        invert = inv
    else:
        looked = [[affine_ref(raw, s, i) for i in range(length)] for s in specs]
        column = lambda k: iter(looked[k])
        hist = histogram(v for col in looked for v in col)
        deltas = [delta_ref(raw, tp, i) for i in range(length)]
        act_idx = [v+128 for v in raw['g8']]
        ds, ais = lambda: iter(deltas), lambda: iter(act_idx)
        invert = inv_ref
    mh_exp, mh_act = [0]*256, [0]*256
    for i, d in enumerate(ds()):
        hit = 0 <= d < 256 and exp[d] == get('e', i)
        mh_exp[d if hit else 0] += 1
    for i, index in enumerate(ais()):
        hit = 0 <= index < 256 and act[index] == get('a16', i)
        mh_act[index if hit else 0] += 1
    table = [None if sub(alpha, add((v, 0), gu8)) == ZERO else invert(sub(alpha, add((v, 0), gu8))) for v in range(256)]
    def one(v):
        if lazy and 0 <= v < 256:
            if table[v] is None:
                raise ValueError(REFUSAL)
            return table[v]
        return invert(sub(alpha, add((v % P, 0), gu8)))
    helpers = []
    for k in range(0, len(specs), 2):
        if k+1 < len(specs):
            helpers.append([add(one(a), one(b)) for a, b in zip(column(k), column(k+1))])
        else:
            helpers.append([one(v) for v in column(k)])
    helpers.append([invert(denominator(d, get('e', i), alpha, beta, gexp)) for i, d in enumerate(ds())])
    helpers.append([invert(denominator(v, get('a16', i), alpha, beta, gact)) for i, v in enumerate(ais())])
    # Preserve inversion of EVERY public-table denominator, including unused entries.
    for rows, histo, tag, is_byte in [(list(range(256)), hist, gu8, True), (exp, mh_exp, gexp, False), (act, mh_act, gact, False)]:
        table_helper = []
        for i, value in enumerate(rows):
            den = sub(alpha, add((i % P, 0), tag)) if is_byte else denominator(i, value, alpha, beta, tag)
            x = invert(den)
            table_helper.append((x[0]*histo[i] % P, x[1]*histo[i] % P))
        helpers.append(table_helper)
    h_words = []
    for helper in helpers:
        for limb in (0, 1):
            h_words += [v[limb] for v in helper] + [0]*((-len(helper)) % 8)
    h_bytes = b''.join(struct.pack('<Q', v) for v in h_words)
    return dict(a=a_bytes(planes, not lazy), hist=hist, mexp=mh_exp, mact=mh_act,
                deltas=list(ds()), indices=list(ais()), helpers=helpers, h=h_bytes)


def fixture(t, heads, rng):
    tp, hp = 1 << (t-1).bit_length(), 1 << (heads-1).bit_length()
    n = hp*tp*tp
    exp = [512//(i+1)+1 for i in range(256)]
    act = [(i-128)*17 for i in range(256)]
    raw = dict(s8=tuple(rng.randrange(-127, 128) for _ in range(n)),
        mx=tuple(rng.randrange(-127, 128) for _ in range(hp*tp)),
        g8=tuple(rng.randrange(-128, 128) for _ in range(n)),
        byte=tuple(rng.randrange(256) for _ in range(n)),
        wide=tuple(rng.choice((-2**63, 2**63-1, -65536, 65536, 0)) for _ in range(n)),
        e=(), a16=(), mu8=(), mexp=(), mact=())
    ds = [delta_ref(raw, tp, i) for i in range(n)]
    raw['e'] = tuple(exp[d] if 0 <= d < 256 else 0 for d in ds)
    raw['a16'] = tuple(act[v+128] for v in raw['g8'])
    # Nonzero E padding analogue and out-of-table/mismatched pairs.
    if n > 1:
        raw['e'] = raw['e'][:-1]+(513,)
        raw['a16'] = raw['a16'][:-1]+(-32768,)
    specs = [(0, [('byte', 1)]), (127, [('s8', 1)]), (127, [('s8', -1)])]
    specs += [(0, [('byte', k)]) for k in (2, 4, 8, 64, 128)]
    specs += [(2**63-1, [('wide', -3), ('byte', 128)])]
    return raw, specs, tp, exp, act


def ledger(prior):
    rows = []
    for old in prior['layout_ledger']:
        t, d, f, hp, kv, dh, lc = [old[k] for k in ('tokens','width','hidden','q_heads','kv_heads','head_dim','log_cols')]
        pad = lambda x: 1 << (x-1).bit_length()
        tp, dp, fp, hp = map(pad, (t,d,f,hp))
        n = 1 << lc
        ln, ls = old['norm_limbs'], old['softmax_limbs']
        wrho = 12 + math.isqrt(1+d*32768**2).bit_length()
        top = int(8*ln != wrho)
        sizes = dict(L=max(16*tp,n),D=max(tp*dp,n),F=max(tp*fp,n),Q=max(tp*hp*dh,n),Kv=max(tp*kv*dh,n),S=max(hp*tp*tp,n))
        counts = dict(L=2,D=18+4*(ln+top),F=9,Q=13,Kv=12,S=7+2*(ls+1))
        # Independent enumeration of the native one-term byte/sym/scaled groups.
        named = dict(L=[2], D=[2,2,ln,top,ln,top,6,2,ln,top,ln,top,2,4],
                     F=[2,2,2,3],Q=[2,2,2,2,2,3],Kv=[2,2,2,2,2,2],S=[2,2,2,1,ls,1,ls,1])
        assert counts == {k:sum(v) for k,v in named.items()}
        looked = sum(counts[k]*sizes[k] for k in counts)
        indices = sizes['S']+sizes['F']
        raw, typed = old['i64_payload_bytes'], old['conservative_typed_payload_bytes']
        baseline = raw+8*(looked+indices)
        typed_only = typed+8*(looked+indices)
        lazy = typed
        # Every actual native U8 Lk is one term. Exp/activation lazy reads counted separately.
        rows.append(dict(name=old['name'],context=t,registered=old['registered_witness_geometry'],
            witness_raw_bytes=raw,witness_typed_bytes=typed,lookup_words=looked,lookup_i64_bytes=8*looked,
            index_i64_bytes=8*indices,pre_h_transient_baseline_bytes=baseline,
            typed_only_transient_bytes=typed_only,typed_lazy_transient_bytes=lazy,
            typed_only_removed_bytes=raw-typed,typed_lazy_removed_bytes=baseline-lazy,
            raw_to_typed_pack_overlap_payload_bytes=raw+typed,
            lazy_added_u8_term_multiplies_and_wrap_adds_each=looked,
            baseline_u8_source_and_materialization_bytes=8*looked+24*looked,
            typed_lazy_u8_source_read_upper_bytes=16*looked,
            typed_lazy_u8_source_read_u8_admitted_bytes=2*looked,
            lookup_fixed_metadata_only=True,
            global_peak_and_native_time_unknown=True))
    return rows


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU, (55,55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    begin = time.perf_counter()
    snap = HERE/'snapshots'; snap.mkdir(exist_ok=True)
    pins = {}
    for path in [SOURCE/k for k in ('protocol.rs','layout.rs','shape.rs','witness.rs')] + [ROOT/'zkp-core/src/field.rs', HERE.parent/'witness-suffix-replay-20261003/result.json', ROOT/'results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/report.json', ROOT/'results/zk60_mvp_20260929/cli-stack-gpu/report.json']:
        data = path.read_bytes()
        rel = str(path.relative_to(ROOT))
        pins[rel] = hashlib.sha256(data).hexdigest()
        (snap/rel.replace('/','__')).write_bytes(data)
    rng = random.Random(SEED)
    controls = []
    def reject(label, fn):
        try:
            fn()
        except (ValueError, IndexError):
            controls.append(label)
        else:
            raise AssertionError('accepted '+label)
    vectors = [(),(-128,127),(0,255),(-32768,32767),(0,65535),(-2**31,2**31-1),
               (0,2**32-1),(-2**63,2**63-1),(0,513),(-127,0,127)]
    for bits in (7,8,15,16,31,32,62):
        vectors += [tuple(rng.randrange(-2**bits,2**bits) for _ in range(rng.randrange(1,64))) for _ in range(8)]
    words = 0
    for values in vectors:
        p = Plane(values)
        code = {(1,True):'b',(1,False):'B',(2,True):'h',(2,False):'H',(4,True):'i',(4,False):'I',(8,True):'q',(8,False):'Q'}[p.width,p.signed]
        assert p.blob == struct.pack('<'+code*len(values),*values)
        for i, v in enumerate(values):
            assert p.get(i) == struct.unpack_from('<'+code,p.blob,i*p.width)[0] == v
            assert struct.pack('<Q',p.fp(i)) == struct.pack('<Q',v % P)
            words += 1
        reject('past_end_'+str(len(controls)), lambda:p.get(len(values)))
    reject('negative_index',lambda:Plane((1,)).get(-1))
    reject('i64_overflow',lambda:Plane((2**63,)))
    reject('i64_underflow',lambda:Plane((-2**63-1,)))
    cases = []
    compared = 0
    for t,heads in [(1,1),(2,1),(3,3),(5,1),(5,3),(8,2)]:
        raw,specs,tp,exp,act = fixture(t,heads,rng)
        for alpha,beta,tags in [((997,19),(11,23),((31,2),(47,3),(61,5))),
                               ((P-3,P-5),(P-9,7),((31,2),(47,3),(61,5))),
                               ((997,19),(11,23),(ZERO,ZERO,ZERO))]:
            args = (raw,specs,tp,alpha,beta,*tags,exp,act)
            ref = prepare(*args,False)
            got = prepare(*args,True)
            assert got == ref
            compared += sum(len(v)*2 for v in got['helpers'])
            cases.append(dict(t=t,heads=heads,t_pad=tp,score_words=len(raw['s8']),
                lookup_columns=len(specs),h_sha256=hashlib.sha256(got['h']).hexdigest(),
                raw_plane_payload=sum(len(v)*8 for v in raw.values()),
                typed_plane_payload=sum(len(Plane(v).blob) for v in raw.values())))
    # Independent decisive mutations: these are rejected designs, not alternate accepted semantics.
    p = Plane((-1,)); assert int.from_bytes(p.blob,'little',signed=False) != p.get(0); controls.append('unsigned_signed_decode')
    assert (2**64-1) % P != (-1) % P; controls.append('two_complement_mod_p')
    raw,specs,tp,exp,act = fixture(3,3,rng)
    pp = {k:Plane(v) for k,v in raw.items()}
    assert any(affine(pp,s,i) != s[0]+sum(c*raw[k][i] for k,c in s[1]) for s in specs for i in range(len(raw['s8']))); controls.append('missing_i64_wrap')
    assert any(delta(pp,tp,i) != wrap(raw['mx'][i//tp]-raw['s8'][i]) for i in range(len(raw['s8']))); controls.append('future_scores_not_masked')
    assert any(delta(pp,tp,i) != wrap(raw['mx'][(i//tp)%tp]-(raw['s8'][i] if i%tp<=i//tp%tp else -127)) for i in range(len(raw['s8']))); controls.append('head_stride')
    assert histogram([-1,256,255]) != histogram([v & 255 for v in [-1,256,255]]); controls.append('invalid_byte_modulo_bucket')
    args=(raw,specs,tp,(997,19),(11,23),(31,2),(47,3),(61,5),exp,act)
    full = prepare(*args,True)
    changed=dict(raw); changed['e']=tuple(0 for _ in raw['e'])
    assert prepare(changed,*args[1:],True) != full; controls.append('nonzero_exp_zeroed')
    changed=dict(raw); changed.pop('mu8'); assert a_bytes({k:Plane(v) for k,v in changed.items()}) != full['a']; controls.append('empty_histogram_plane_removed')
    assert denominator(2,513,(997,19),(11,23),(47,3)) != denominator(2,513,(997,19),(11,0),(47,3)); controls.append('extension_limb_lost')
    assert full['h'] != b''.join(struct.pack('<Q',w[0])+struct.pack('<Q',w[1]) for col in full['helpers'] for w in col); controls.append('h_limb_layout')
    # Used and unused table zeros refuse in both schedules, plus invalid signed fallback.
    refusal_cases = 0
    for target in ('used_u8','unused_u8','invalid_signed','exp_table_unused','act_table_unused'):
        rr,ss,tt,ee,aa = fixture(2,1,rng)
        gu,ge,ga,beta=(31,2),(47,3),(61,5),(11,23)
        if target=='used_u8':
            alpha=add((rr['byte'][0],0),gu)
        elif target=='unused_u8':
            rr['byte']=(0,)*len(rr['byte']); ss=[(0,[('byte',1)])]; alpha=add((255,0),gu)
        elif target=='invalid_signed':
            rr['byte']=(-1,)*len(rr['byte']); ss=[(0,[('byte',1)])]; alpha=add((P-1,0),gu)
        elif target=='exp_table_unused':
            alpha=add(add((255,0),mul(beta,(ee[255],0))),ge)
        else:
            alpha=add(add((255,0),mul(beta,(aa[255] % P,0))),ga)
        for lazy in (False,True):
            reject(target+('_lazy' if lazy else '_materialized'),lambda:prepare(rr,ss,tt,alpha,beta,gu,ge,ga,ee,aa,lazy))
            refusal_cases += 1
    # Actual byte payload micro-fixture: avoid reexpansion, without claiming global RSS benefit.
    values = tuple(i % 127-63 for i in range(4096))
    plane = Plane(values)
    assert b''.join(struct.pack('<Q',plane.fp(i)) for i in range(len(plane))) == b''.join(struct.pack('<Q',v % P) for v in values)
    payload = dict(entries=len(values),raw_i64_payload_bytes=8*len(values),typed_payload_bytes=len(plane.blob),
                   expanded_i64_buffer_allocated_by_candidate=False,source_counts_not_global_rss=True)
    prior=json.loads((HERE.parent/'witness-suffix-replay-20261003/result.json').read_text())
    result=dict(status='passed',run_identity=RUN,seed=SEED,vector_cases=len(vectors),indexed_field_word_comparisons=words,
        preparation_cases=cases,helper_limb_comparisons=compared,refusal_cases=refusal_cases,negative_controls=controls,
        payload_micro_fixture=payload,layout_ledger=ledger(prior),source_pins_sha256=pins,
        script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),elapsed_s=time.perf_counter()-begin,
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,python=platform.python_version(),
        cpu=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown'),
        device='CPU only; no GPU',limits=dict(wall_s=59,cpu_s=55,address_space_mib=512,estimated_memory_mib=48),
        scope='Synthetic reader/preparation arithmetic; no native Layout execution, full witness builder, mask/RNG/PCS, proof or trained model',
        full_stack=dict(completed_independently_verified_model_passes=0,countable_tokens=0,context_length=None,passes=0,
            steady_tokens_per_s=None,total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,
            serialization_s=None,verification_s=None,proof_lag_s=None,pipeline_drain_s=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','vector_cases','indexed_field_word_comparisons','helper_limb_comparisons','refusal_cases','elapsed_s','peak_rss_kib')}))


if __name__=='__main__':
    main()
