#!/usr/bin/env python3
"""Synthetic unchanged-order prefix checkpoint oracle; no native proof or speed test."""
import dataclasses as dc
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import resource
import signal
import time

from reference_support import Shape, Words, fixture, reference, validate, large_count

RUN = '20261004T100146Z-8793c93e'
SEED = 2026100428
DOMAIN = b'hashline/private-block-public/1'
PREFIX_NAMES = ('wq', 'wk', 'wv', 'wo', 'gamma_a')
TAIL_SCHEMA = (('rope_cos', 8), ('rope_sin', 8), ('exp', 8),
               ('gamma_m', 1), ('wg', 1), ('wu', 1), ('wd', 1), ('act', 2))


@dc.dataclass(frozen=True)
class Suffix:
    rope_cos: tuple
    rope_sin: tuple
    exp: tuple
    gamma_m: tuple
    wg: tuple
    wu: tuple
    wd: tuple
    act: tuple


def suffix_of(w):
    return Suffix(**{name: tuple(getattr(w, name)) for name, _ in TAIL_SCHEMA})


def stream(arrays, cap):
    """Separately implemented signed-byte/word stream, including ELEMENT frames."""
    if cap <= 0:
        raise ValueError('chunk cap')
    buf = bytearray()
    for vals, width in arrays:
        frame = len(vals).to_bytes(8, 'little')
        for octet in itertools.chain(frame, itertools.chain.from_iterable(
                x.to_bytes(width, 'little', signed=True) for x in vals)):
            buf.append(octet)
            if len(buf) == cap:
                yield bytes(buf)
                buf.clear()
    if buf:
        yield bytes(buf)


def prefix_parts(words, cap):
    yield DOMAIN
    yield from stream(((getattr(words, n), 1) for n in PREFIX_NAMES), cap)


def suffix_parts(suffix, cap):
    yield from stream(((getattr(suffix, n), width) for n, width in TAIL_SCHEMA), cap)


class PrefixOwner:
    """Tuple-owned public weights + nonserialized diagnostic incremental hash state.

    No caller key or complete BlockPublic is accepted on the reuse path. The
    prefix arrays used in the resulting statement are this exact owner. This
    models an ownership prerequisite; it does not enforce native Rust access.
    """
    def __init__(self, words, cap=257):
        self.weights = {n: tuple(getattr(words, n)) for n in PREFIX_NAMES}
        self._state = hashlib.sha256()
        self.prefix_bytes = 0
        for chunk in prefix_parts(self, cap):
            self._state.update(chunk)
            self.prefix_bytes += len(chunk)
        self.suffix_bytes = 0
        self.finishes = 0

    def __getattr__(self, name):
        if name in PREFIX_NAMES:
            return self.weights[name]
        raise AttributeError(name)

    def statement(self, suffix):
        return Words(**self.weights, **dc.asdict(suffix))

    def finish(self, sh, suffix, cap):
        # Preserve support/table checks; this still scans all public weights.
        validate(sh, self.statement(suffix))
        state = self._state.copy()
        for chunk in suffix_parts(suffix, cap):
            state.update(chunk)
            self.suffix_bytes += len(chunk)
        self.finishes += 1
        return state.digest()


def changed(w, name):
    v = list(getattr(w, name))
    v[0] = v[0] + 1 if v[0] <= 0 else v[0] - 1
    return dc.replace(w, **{name: tuple(v)})


def count_model(t):
    # Allocation-free two independent count decompositions must agree.
    d, f, kv, hd, layers = 4096, 16384, 8, 128, 32
    prefix = len(DOMAIN) + 5 * 8 + 2*d*d + 2*kv*hd*d + d
    suffix = 8*8 + 2*t*(hd//2)*8 + 256*8 + d + 3*d*f + 256*2
    whole = large_count(t)['model_preimage_bytes']
    assert layers*(prefix+suffix) == whole
    return {'context_count_only': t, 'layers': layers,
            'prefix_bytes_per_block': prefix, 'suffix_bytes_per_block': suffix,
            'model_prefix_bytes': prefix*layers, 'model_suffix_bytes': suffix*layers,
            'model_full_preimage_bytes': whole,
            'maximum_reusable_hash_byte_fraction': prefix/(prefix+suffix),
            'unavoidable_suffix_hash_byte_fraction': suffix/(prefix+suffix),
            'idealized_hash_byte_ratio_only': (prefix+suffix)/suffix,
            'native_checkpoint_state_size_bytes': None,
            'native_prefix_support_scan_bytes_per_new_constructor': (prefix-len(DOMAIN)-40)*layers,
            'native_prefix_copy_payload_bytes_per_new_constructor': (prefix-len(DOMAIN)-40)*layers}


def main():
    start = time.monotonic()
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    rng = random.Random(SEED)
    counts = {'cases': 0, 'prefix_owners': 0, 'byte_comparisons': 0,
              'canonical_bytes_compared': 0, 'resumed_hash_comparisons': 0,
              'tensor_mutations': 0, 'branch_isolation_checks': 0,
              'cold_import_scans': 0, 'schedule_checks': 0}
    controls, shapes = [], []

    def mismatch(name, expected, incorrect):
        assert expected != incorrect, name
        controls.append({'name': name, 'detected': 'independent reference mismatch'})

    def refuse(name, action, expected):
        try:
            action()
        except ValueError as err:
            assert str(err) == expected, (name, str(err))
            controls.append({'name': name, 'detected': str(err)})
        else:
            raise AssertionError(name)

    geometry = [(4,4,8,8,2,1,(0,1)), (6,8,11,16,2,2,(0,2,3)),
                (8,8,16,16,4,1,(0,1))]
    contexts = (1, 2, 3, 8, 16, 33)
    caps = (1, 7, 8, 31, 64, 257, 4096, 65536)
    for width, d, hidden, f, hd, kv, slots in geometry:
        for mode in ('zero', 'extrema', 'random'):
            long_sh = Shape(max(contexts), width, d, hidden, f, hd, kv, slots)
            wlong = fixture(long_sh, rng, mode)
            owner = PrefixOwner(wlong)
            counts['prefix_owners'] += 1
            pristine = owner._state.copy().digest()
            for t in contexts:
                sh = dc.replace(long_sh, tokens=t)
                half = sh.hd//2
                w = dc.replace(wlong, rope_cos=wlong.rope_cos[:t*half],
                               rope_sin=wlong.rope_sin[:t*half])
                validate(sh, w)
                s = suffix_of(w)
                ref = reference(w)
                expected = hashlib.sha256(ref).digest()
                for cap in caps:
                    pre = b''.join(prefix_parts(owner, cap))
                    tail = b''.join(suffix_parts(s, cap))
                    assert pre+tail == ref
                    assert owner.prefix_bytes == len(pre)
                    before = owner.suffix_bytes
                    assert owner.finish(sh, s, cap) == expected
                    assert owner.suffix_bytes-before == len(tail)
                    assert owner._state.copy().digest() == pristine
                    counts['byte_comparisons'] += 1
                    counts['resumed_hash_comparisons'] += 1
                    counts['canonical_bytes_compared'] += len(ref)
                    counts['branch_isolation_checks'] += 1
                # Every prefix and suffix tensor remains binding. Prefix changes
                # require a new owner; suffix changes reuse the original owner.
                for name in PREFIX_NAMES + tuple(n for n, _ in TAIL_SCHEMA):
                    alt = changed(w, name)
                    assert hashlib.sha256(reference(alt)).digest() != expected
                    if name in PREFIX_NAMES:
                        ao = PrefixOwner(alt)
                        assert ao.finish(sh, s, 257) == hashlib.sha256(reference(alt)).digest()
                    else:
                        # Hash comparison includes invalid structure deliberately;
                        # acceptance/refusal is separately tested below.
                        h = owner._state.copy()
                        for chunk in suffix_parts(suffix_of(alt), 257): h.update(chunk)
                        assert h.digest() == hashlib.sha256(reference(alt)).digest()
                    counts['tensor_mutations'] += 1
                imported = PrefixOwner(w)
                assert imported.prefix_bytes == owner.prefix_bytes
                assert imported.finish(sh, s, 257) == expected
                counts['cold_import_scans'] += 1
                counts['cases'] += 1
                shapes.append(dc.asdict(sh))

    sh = Shape(3,6,8,11,16,2,2,(0,2,3))
    w = fixture(sh, rng, 'random'); s = suffix_of(w); owner = PrefixOwner(w)
    pre = b''.join(prefix_parts(owner, 257)); tail = b''.join(suffix_parts(s, 257))
    ref = reference(w); expected = hashlib.sha256(ref).digest()
    mismatch('finalized prefix digest replaces incremental state', expected,
             hashlib.sha256(hashlib.sha256(pre).digest()+tail).digest())
    mismatch('hash(prefix)||hash(suffix) replaces full digest', expected,
             hashlib.sha256(pre).digest()+hashlib.sha256(tail).digest())
    mismatch('nested digest halves change statement', expected,
             hashlib.sha256(hashlib.sha256(pre).digest()+hashlib.sha256(tail).digest()).digest())
    mismatch('move FFN before dynamic RoPE to enlarge prefix', expected,
             hashlib.sha256(pre + tail[3*8+len(s.rope_cos)*8+len(s.rope_sin)*8+len(s.exp)*8:]
                            +tail[:3*8+len(s.rope_cos)*8+len(s.rope_sin)*8+len(s.exp)*8]).digest())
    alt = changed(w, 'wq')
    mismatch('stale prefix after owned weight mutation', hashlib.sha256(reference(alt)).digest(),
             owner.finish(sh, suffix_of(alt), 257))
    old_frame = bytearray(tail); old_frame[:8] = (1).to_bytes(8,'little')
    mismatch('cache includes obsolete context-dependent length frame', expected,
             hashlib.sha256(pre+old_frame).digest())
    byteframe = bytearray(tail); byteframe[:8] = (len(s.rope_cos)*8).to_bytes(8,'little')
    mismatch('RoPE byte count substitutes element count', expected, hashlib.sha256(pre+byteframe).digest())
    swapped = dc.replace(s, rope_cos=s.rope_sin, rope_sin=s.rope_cos)
    mismatch('swap equal-sized RoPE tables', expected,
             hashlib.sha256(pre+b''.join(suffix_parts(swapped,257))).digest())
    mismatch('omit unchanged FFN suffix', expected,
             hashlib.sha256(pre+tail[:3*8+len(s.rope_cos)*8+len(s.rope_sin)*8+len(s.exp)*8]).digest())
    h = owner._state.copy(); h.update(tail); h.update(tail)
    mismatch('mutating shared state instead of cloning per context', expected, h.digest())
    mismatch('omit original domain', expected, hashlib.sha256(ref[len(DOMAIN):]).digest())
    # Constructors still refuse malformed support and tables for every T.
    refuse('wrong context length', lambda: owner.finish(dc.replace(sh,tokens=8),s,257), 'table shape')
    refuse('short cosine table', lambda: owner.finish(sh,dc.replace(s,rope_cos=s.rope_cos[:-1]),257), 'table shape')
    refuse('wrong first sine row', lambda: owner.finish(sh,dc.replace(s,rope_sin=(1,)+s.rope_sin[1:]),257), 'rope structure')
    refuse('changed exponent requires original exp structure check', lambda: owner.finish(dc.replace(sh,fe=13),s,257), 'exp structure')
    refuse('wrong activation length', lambda: owner.finish(sh,dc.replace(s,act=s.act[:-1]),257), 'act domain/shape')
    refuse('short FFN tensor', lambda: owner.finish(sh,dc.replace(s,wd=s.wd[:-1]),257), 'weight shape')
    dirty=list(s.wd);dirty[-1]=1
    refuse('dirty FFN padding', lambda: owner.finish(sh,dc.replace(s,wd=tuple(dirty)),257), 'support')
    dirty=list(w.wq);dirty[2*sh.d]=1
    dirtyowner=PrefixOwner(dc.replace(w,wq=tuple(dirty)))
    refuse('cached prefix does not bypass support validation', lambda: dirtyowner.finish(sh,s,257),'support')
    refuse('empty stream cap',lambda:list(suffix_parts(s,0)), 'chunk cap')
    # Copy mutable caller arrays; this Python property is not Rust enforcement.
    mutable=dc.replace(w,wq=list(w.wq)); detached=PrefixOwner(mutable)
    mutable.wq[0]+=1
    assert detached.finish(sh,s,257)==expected
    controls.append({'name':'owned snapshot survives caller mutation','detected':'unchanged original preimage'})

    models=[count_model(t) for t in (512,1024,2048,4096,8192)]
    schedules=[]
    ts=(512,1024,2048,4096)
    scan=sum(count_model(t)['model_full_preimage_bytes'] for t in ts)
    shared=count_model(ts[0])['model_prefix_bytes']+sum(count_model(t)['model_suffix_bytes'] for t in ts)
    assert scan-shared == (len(ts)-1)*count_model(ts[0])['model_prefix_bytes']
    schedules.append({'mode':'resident immutable weights, four DIFFERENT contexts',
                      'contexts_count_only':ts,'baseline_hash_bytes':scan,
                      'checkpoint_hash_bytes':shared,'removed_hash_bytes':scan-shared,
                      'removed_byte_fraction':(scan-shared)/scan})
    counts['schedule_checks']+=1
    for p in (1,2,8,32):
        m=count_model(512); total=p*m['model_full_preimage_bytes']
        prefixpath=m['model_prefix_bytes']+p*m['model_suffix_bytes']
        assert total-prefixpath==(p-1)*m['model_prefix_bytes']
        schedules.append({'mode':'same context comparison; complete digest cache strictly dominates after first hash',
                          'calls_count_only':p,'uncached_hash_bytes':total,'prefix_checkpoint_hash_bytes':prefixpath,
                          'prior_complete_digest_cache_hash_bytes':m['model_full_preimage_bytes']})
        counts['schedule_checks']+=1
    accounting={k:None for k in ('context_length','steady_state_tokens_per_s','total_workload_tokens_per_s',
                'startup_fraction','startup_s','total_workload_s','witness_s','proof_s','serialization_s',
                'independent_verification_s','proof_latency_s','proof_lag_s','pipeline_drain_s')}
    accounting.update({'accepted_complete_private8b_passes':0,'countable_tokens':0,'passes':0,
                       'device':'CPU only','prefill':'none','resident_passes':'none','decode':'none'})
    result={'run_id':RUN,'seed':SEED,'status':'pass',**counts,'controls':controls,'control_count':len(controls),
            'synthetic_shapes':shapes,'count_only_unadmitted_model':models,'count_only_schedules':schedules,
            'elapsed_seconds':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'resources':{'threads':1,'affinity':sorted(os.sched_getaffinity(0)),
                         'nice':os.getpriority(os.PRIO_PROCESS,0),'wall_alarm_s':59,'CPU_limit_s':59,
                         'address_space_cap_MiB':512,'estimated_memory_MiB':64},
            'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'reference_support_sha256':hashlib.sha256(Path(__file__).with_name('reference_support.py').read_bytes()).hexdigest(),
            'proof_accounting':accounting,
            'limits':['SHA256 models incremental state; native BLAKE3 Clone/bytes unexecuted',
                      'No native/RNG/transcript/PCS/proof/concurrency/ownership enforcement tested',
                      'Validation/copy scans remain; cached words require exact immutable model authority',
                      'Logical byte ratios are not runtime speed/DRAM traffic or peak memory',
                      'No actual 8B allocation, admitted profile, private data or GPU job']}
    Path(__file__).with_name('result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','cases','prefix_owners','byte_comparisons',
                      'canonical_bytes_compared','resumed_hash_comparisons','tensor_mutations',
                      'control_count','elapsed_seconds','peak_rss_kib')},sort_keys=True))


if __name__=='__main__': main()
