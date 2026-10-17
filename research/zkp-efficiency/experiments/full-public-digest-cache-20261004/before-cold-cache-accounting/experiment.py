#!/usr/bin/env python3
"""Synthetic complete public-preimage/cache oracle; SHA256 is diagnostic only."""
import dataclasses as dc
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import resource
import signal
import struct
import time

RUN = '20261004T090146Z-73c03938'
SEED = 2026100427
DOMAIN = b'hashline/private-block-public/1'
ROOT_DOMAIN = b'hashline/private-run-blocks/1'


@dc.dataclass(frozen=True)
class Shape:
    tokens: int
    width: int
    d: int
    hidden: int
    f: int
    hd: int
    kv: int
    slots: tuple
    fe: int = 12


@dc.dataclass(frozen=True)
class Words:
    wq: tuple
    wk: tuple
    wv: tuple
    wo: tuple
    gamma_a: tuple
    rope_cos: tuple
    rope_sin: tuple
    exp: tuple
    gamma_m: tuple
    wg: tuple
    wu: tuple
    wd: tuple
    act: tuple


# Candidate schema is separate from the explicit original-order reference.
SCHEMA = [('wq', 1), ('wk', 1), ('wv', 1), ('wo', 1), ('gamma_a', 1),
          ('rope_cos', 8), ('rope_sin', 8), ('exp', 8), ('gamma_m', 1),
          ('wg', 1), ('wu', 1), ('wd', 1), ('act', 2)]


def reference(w):
    """Monolithic independent struct.pack reference to pinned absorb_into."""
    out = bytearray(DOMAIN)
    for v in (w.wq, w.wk, w.wv, w.wo, w.gamma_a):
        out.extend(struct.pack('<Q', len(v)))
        out.extend(struct.pack('<' + str(len(v)) + 'b', *v))
    for v in (w.rope_cos, w.rope_sin, w.exp):
        out.extend(struct.pack('<Q', len(v)))
        out.extend(struct.pack('<' + str(len(v)) + 'q', *v))
    for v in (w.gamma_m, w.wg, w.wu, w.wd):
        out.extend(struct.pack('<Q', len(v)))
        out.extend(struct.pack('<' + str(len(v)) + 'b', *v))
    out.extend(struct.pack('<Q', len(w.act)))
    out.extend(struct.pack('<' + str(len(w.act)) + 'h', *w.act))
    return bytes(out)


def chunks(w, cap):
    """Bounded chunks may split words; no change to lengths/order/endian."""
    if cap <= 0:
        raise ValueError('chunk cap')
    yield DOMAIN
    buf = bytearray()
    for name, size in SCHEMA:
        v = getattr(w, name)
        # Frame count is elements, NOT byte length for i16/i64.
        for value, n, signed in itertools.chain(((len(v), 8, False),), ((x, size, True) for x in v)):
            for b in value.to_bytes(n, 'little', signed=signed):
                buf.append(b)
                if len(buf) == cap:
                    yield bytes(buf)
                    buf.clear()
    if buf:
        yield bytes(buf)


def validate(sh, w):
    d, f, k = sh.d, sh.f, sh.kv * sh.hd
    qsupport = {s * sh.hd + c for s in sh.slots for c in range(sh.hd)}
    ds, fs = set(range(sh.width)), set(range(sh.hidden))
    specs = [(w.wq, d, d, qsupport, ds), (w.wk, k, d, set(range(k)), ds),
             (w.wv, k, d, set(range(k)), ds), (w.wo, d, d, ds, qsupport),
             (w.gamma_a, 1, d, {0}, ds), (w.gamma_m, 1, d, {0}, ds),
             (w.wg, d, f, ds, fs), (w.wu, d, f, ds, fs), (w.wd, f, d, fs, ds)]
    for v, rows, cols, osup, isup in specs:
        if len(v) != rows * cols:
            raise ValueError('weight shape')
        if any(x < -128 or x > 127 for x in v):
            raise ValueError('i8 domain')
        if any(x and (i // cols not in osup or i % cols not in isup) for i, x in enumerate(v)):
            raise ValueError('support')
    half, ro, e = sh.hd // 2, 1 << 14, 1 << sh.fe
    if len(w.rope_cos) != sh.tokens * half or len(w.rope_sin) != sh.tokens * half or len(w.exp) != 256:
        raise ValueError('table shape')
    if any(abs(x) > ro for x in w.rope_cos + w.rope_sin) or w.rope_cos[:half] != (ro,) * half or w.rope_sin[:half] != (0,) * half:
        raise ValueError('rope structure')
    if w.exp[0] != e or any(x < 0 or x > e for x in w.exp) or any(a < b for a, b in zip(w.exp, w.exp[1:])):
        raise ValueError('exp structure')
    if len(w.act) != 256 or any(x < -32768 or x > 32767 for x in w.act):
        raise ValueError('act domain/shape')


class Owner:
    """Immutable tuple-copy boundary; Python models, not enforces Rust access."""
    def __init__(self, sh, w):
        copied = Words(**{n: tuple(getattr(w, n)) for n, _ in SCHEMA})
        validate(sh, copied)
        self._words = copied
        self._digest = None
        self.scans = 0
        self.hashed_bytes = 0

    def digest(self):
        if self._digest is None:
            h = hashlib.sha256()
            for b in chunks(self._words, 257):
                h.update(b)
                self.hashed_bytes += len(b)
            self._digest = h.digest()
            self.scans += 1
        return self._digest

    def clone(self):
        # Corresponds to Clone of an initialized/noninitialized OnceLock.
        o = object.__new__(Owner)
        o._words = self._words
        o._digest = self._digest
        o.scans = o.hashed_bytes = 0
        return o


def fixture(sh, rng, mode):
    d, f, k = sh.d, sh.f, sh.kv * sh.hd
    ds, fs = set(range(sh.width)), set(range(sh.hidden))
    qs = {s * sh.hd + c for s in sh.slots for c in range(sh.hd)}
    def mat(rows, cols, rs, cs):
        return tuple((0 if mode == 'zero' else (-128 if (i + j) % 2 else 127) if mode == 'extrema' else rng.randrange(-128, 128))
                     if i in rs and j in cs else 0 for i in range(rows) for j in range(cols))
    ro, half, e = 1 << 14, sh.hd // 2, 1 << sh.fe
    cos = (ro,) * half + tuple(rng.randrange(-ro, ro + 1) for _ in range((sh.tokens - 1) * half))
    sin = (0,) * half + tuple(rng.randrange(-ro, ro + 1) for _ in range((sh.tokens - 1) * half))
    exp = (e,) + tuple(sorted((rng.randrange(e + 1) for _ in range(255)), reverse=True))
    act = tuple((-32768 if i % 2 else 32767) if mode == 'extrema' else rng.randrange(-32768, 32768) for i in range(256))
    return Words(mat(d, d, qs, ds), mat(k, d, set(range(k)), ds), mat(k, d, set(range(k)), ds), mat(d, d, ds, qs),
                 mat(1, d, {0}, ds), cos, sin, exp, mat(1, d, {0}, ds),
                 mat(d, f, ds, fs), mat(d, f, ds, fs), mat(f, d, fs, ds), act)


def root_reference(blocks):
    return hashlib.sha256(ROOT_DOMAIN + b''.join(hashlib.sha256(reference(w)).digest() for w in blocks)).digest()


def root_candidate(owners):
    h = hashlib.sha256(ROOT_DOMAIN)
    for o in owners:
        h.update(o.digest())
    return h.digest()


def outer_binding_projection(digests, fields):
    """Diagnostic of binding separation, NOT native Transcript/state bytes."""
    h = hashlib.sha256(b'synthetic-outer-binding-projection/1')
    for v in tuple(digests) + tuple(fields):
        h.update(struct.pack('<Q', len(v)))
        h.update(v)
    return h.digest()


def large_count(tokens):
    # From public config, padded native storage; no allocation/admitted profile.
    d, f, kv, hd, layers = 4096, 16384, 8, 128, 32
    i8 = 2*d*d + 2*kv*hd*d + 2*d + 3*d*f
    tables = 2*tokens*(hd//2)*8 + 256*8 + 256*2
    per = len(DOMAIN) + 13*8 + i8 + tables
    return {'context_count_only': tokens, 'layers': layers, 'per_block_preimage_bytes': per,
            'model_preimage_bytes': layers*per, 'i8_cast_payload_per_scan_bytes': layers*i8,
            'largest_current_cast_vector_bytes': d*f, 'candidate_Rust_scratch_bytes': 65536,
            'cached_digest_payload_bytes': layers*32, 'OnceLock_layout_overhead_bytes': None}


def main():
    start = time.monotonic()
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    rng = random.Random(SEED)
    counts = {'cases': 0, 'chunk_comparisons': 0, 'canonical_bytes_compared': 0, 'owner_digest_comparisons': 0,
              'model_root_comparisons': 0, 'tensor_mutations': 0, 'outer_binding_mutations': 0}
    shapes = [Shape(t, width, d, hidden, f, hd, kv, slots) for t in (1, 3, 8) for width, d, hidden, f, hd, kv, slots in
              [(4,4,8,8,2,1,(0,1)), (6,8,11,16,2,2,(0,2,3)), (8,8,16,16,4,1,(0,1))]]
    controls = []
    def mismatch(name, good, bad):
        assert good != bad, name
        controls.append({'name': name, 'detected': 'independent mismatch'})
    def refusal(name, action, why):
        try:
            action()
        except ValueError as e:
            assert str(e) == why, (name, str(e))
            controls.append({'name': name, 'detected': str(e)})
        else:
            raise AssertionError(name)
    for sh in shapes:
        for mode in ('zero', 'extrema', 'random'):
            w = fixture(sh, rng, mode)
            validate(sh, w)
            ref = reference(w)
            dg = hashlib.sha256(ref).digest()
            for cap in (1, 7, 8, 31, 64, 257, 4096, 65536):
                parts = list(chunks(w, cap))
                assert all(len(p) <= max(cap, len(DOMAIN)) for p in parts)
                assert b''.join(parts) == ref
                counts['canonical_bytes_compared'] += len(ref)
                counts['chunk_comparisons'] += 1
            o = Owner(sh, w)
            # Cold clones before any digest each scan once; warm clones don't.
            cold = o.clone()
            assert cold.digest() == dg and cold.scans == 1
            assert o.digest() == dg and o.scans == 1
            warm = o.clone()
            for _ in range(9):
                assert o.digest() == warm.digest() == dg
                counts['owner_digest_comparisons'] += 2
            assert o.scans == 1 and warm.scans == 0
            # All thirteen tensors, including true tables, enter the preimage.
            for name, _ in SCHEMA:
                v = list(getattr(w, name))
                pos = len(v) - 1
                old = v[pos]
                v[pos] = old + 1 if old <= 0 else old - 1
                alt = dc.replace(w, **{name: tuple(v)})
                assert reference(alt) != ref and hashlib.sha256(reference(alt)).digest() != dg
                counts['tensor_mutations'] += 1
            fresh = Owner(sh, fixture(sh, rng, 'random'))
            for owners in ([o], [o, fresh], [fresh, o, o]):
                assert root_candidate(owners) == root_reference([p._words for p in owners])
                counts['model_root_comparisons'] += 1
            fields = [b'profile', b'shape', b'parameters', b'calibration', b'expected-IO', b'schedule', b'context']
            binding = outer_binding_projection([dg], fields)
            for i in range(len(fields)):
                altfields = fields[:]
                altfields[i] += b'changed'
                assert outer_binding_projection([dg], altfields) != binding
                counts['outer_binding_mutations'] += 1
            counts['cases'] += 1
    sh = Shape(3,6,8,11,16,2,2,(0,2,3))
    w = fixture(sh, rng, 'random')
    ref = reference(w); dg = hashlib.sha256(ref).digest()
    mismatch('omit attention half', ref, DOMAIN + ref[len(DOMAIN)+8+len(w.wq):])
    mismatch('physical/endian format change', ref, ref.replace(struct.pack('<q',1<<14), struct.pack('>q',1<<14),1))
    mismatch('domain version change', dg, hashlib.sha256(ref.replace(DOMAIN, DOMAIN[:-1]+b'2',1)).digest())
    swapped = dc.replace(w, wg=w.wu, wu=w.wg)
    mismatch('swap equal-sized gate/up tensors', dg, hashlib.sha256(reference(swapped)).digest())
    badframe = bytearray(ref); pos=len(DOMAIN)+8+len(w.wq)+8+len(w.wk)+8+len(w.wv)+8+len(w.wo)+8+len(w.gamma_a)
    badframe[pos:pos+8]=struct.pack('<Q',len(w.rope_cos)*8)
    mismatch('i64 byte-count instead of element-count frame', ref, bytes(badframe))
    good = Owner(sh,w); good.digest()
    v=list(w.wq); v[0]=v[0]+1 if v[0]<=0 else v[0]-1
    changed=dc.replace(w,wq=tuple(v))
    new=Owner(sh,changed)
    mismatch('cached caller identity reused for new content', good.digest(), new.digest())
    bad=good.clone(); bad._words=changed
    mismatch('unsafe internal mutation after initialized clone is stale', hashlib.sha256(reference(bad._words)).digest(),bad.digest())
    # No persistent or caller-fed cache: imported owners recompute independently.
    imported=Owner(sh,w); assert imported.scans==0 and imported.digest()==dg and imported.scans==1
    controls.append({'name':'fresh-process/import independently hashes content','detected':'one new scan'})
    editable={n:list(getattr(w,n)) for n,_ in SCHEMA}
    mutable=Words(**editable); detached=Owner(sh,mutable); detached.digest(); editable['wq'][0]+=1
    assert detached.digest()==dg and detached._words.wq[0]==w.wq[0]
    controls.append({'name':'constructor copies caller-mutable arrays','detected':'snapshot unchanged'})
    refusal('short weight buffer',lambda:Owner(sh,dc.replace(w,wd=w.wd[:-1])),'weight shape')
    v=list(w.wq);v[2*sh.d]=1
    refusal('dirty padded query head',lambda:Owner(sh,dc.replace(w,wq=tuple(v))),'support')
    v=list(w.wd);v[-1]=1
    refusal('dirty padded FFN width',lambda:Owner(sh,dc.replace(w,wd=tuple(v))),'support')
    refusal('invalid i8 value',lambda:Owner(sh,dc.replace(w,gamma_m=(128,)+w.gamma_m[1:])),'i8 domain')
    refusal('wrong rope shape',lambda:Owner(sh,dc.replace(w,rope_cos=w.rope_cos[:-1])),'table shape')
    refusal('invalid rope first row',lambda:Owner(sh,dc.replace(w,rope_sin=(1,)+w.rope_sin[1:])),'rope structure')
    refusal('invalid exp calibration scale',lambda:Owner(sh,dc.replace(w,exp=(1,)+w.exp[1:])),'exp structure')
    refusal('invalid activation endpoint',lambda:Owner(sh,dc.replace(w,act=(32768,)+w.act[1:])),'act domain/shape')
    refusal('invalid activation length',lambda:Owner(sh,dc.replace(w,act=w.act[:-1])),'act domain/shape')
    refusal('empty chunk cap',lambda:list(chunks(w,0)),'chunk cap')
    o=Owner(sh,w); fresh=Owner(sh,changed)
    mismatch('model block order',root_candidate([o,fresh]),root_candidate([fresh,o]))
    mismatch('model block multiplicity',root_candidate([o]),root_candidate([o,o]))
    # SAME preimage under distinct compatible true supports: outer binding required.
    z=fixture(sh,rng,'zero'); sh2=dc.replace(sh,width=5,hidden=10)
    assert Owner(sh,z).digest()==Owner(sh2,z).digest()
    mismatch('shape excluded from block hash still bound outside it',outer_binding_projection([Owner(sh,z).digest()],[b'width6/hidden11']),
             outer_binding_projection([Owner(sh2,z).digest()],[b'width5/hidden10']))
    allcounts=[large_count(t) for t in (512,1024,2048,4096)]
    schedules=[]
    for passes in (1,2,8,32):
        B=allcounts[0]['model_preimage_bytes']
        for label,scans in [('cold-CLI-prover-build-model-and-statement-per-pass',2*passes),
                            ('resident-model-root-once-fresh-statement-per-pass',1+passes),
                            ('fixed-existing-statement-diagnostic-no-rebuild',2)]:
            schedules.append({'mode':label,'passes_count_only':passes,'baseline_full_model_scans':scans,'cache_full_model_scans':1,
                              'eliminated_logical_scan_bytes':(scans-1)*B,
                              'limits':'count-only call pattern, no masks/proofs/DRAM clocks; fixed endpoints not fresh independent passes'})
    accounting={k:None for k in ('context_length','steady_state_tokens_per_s','total_workload_tokens_per_s','startup_fraction',
                 'witness_s','proof_s','serialization_s','independent_verification_s','proof_latency_s','proof_lag_s','pipeline_drain_s')}
    accounting.update({'accepted_complete_private8b_passes':0,'countable_tokens':0,'passes':0,'device':'CPU only','prefill':'none','resident_passes':'none','decode':'none'})
    result={'run_id':RUN,'seed':SEED,'status':'pass',**counts,'controls':controls,'control_count':len(controls),
            'synthetic_shapes':[dc.asdict(s) for s in shapes],'count_only_unadmitted_model':allcounts,'count_only_scan_schedules':schedules,
            'elapsed_seconds':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'resources':{'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.getpriority(os.PRIO_PROCESS,0),'wall_alarm_s':59,
                         'CPU_limit_s':59,'address_space_cap_MiB':512,'estimated_memory_MiB':64},
            'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'proof_accounting':accounting,
            'limits':['Exact public preimage oracle, not native BLAKE3/RNG/transcript/PCS/proof','SHA256 diagnostic only',
                      'Python owner privacy models do not enforce Rust child-module immutability or concurrent initialization',
                      'No real weights/tokens/activations','No actual speed/DRAM/peak-memory gain measured','Outer binding is a diagnostic projection, not native header bytes']}
    Path(__file__).with_name('result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','cases','chunk_comparisons','canonical_bytes_compared','owner_digest_comparisons',
                      'model_root_comparisons','tensor_mutations','outer_binding_mutations','control_count','elapsed_seconds','peak_rss_kib')},sort_keys=True))


if __name__=='__main__':
    main()
