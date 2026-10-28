#!/usr/bin/env python3
"""Synthetic public owner, independent streaming reference and lifetime ledger.

No native admission, witness, masks, proof, or GPU. SHA256 here names synthetic
objects; it does not replace native BLAKE3 statement digests. No real arrays.
"""
import copy
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

HERE = Path(__file__).resolve().parent
SEED = 2026101985
BLOCK_BYTES = 243411456
checks = 0


def check(ok):
    global checks
    assert ok
    checks += 1


def cap():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def canonical(x):
    return json.dumps(x, sort_keys=True, separators=(',', ':')).encode()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def fingerprint(record):
    # Length-delimited identity plus every raw public array: no stat/mtime key.
    h = hashlib.sha256(canonical(record['meta']))
    for name, row in sorted(record['arrays'].items()):
        h.update(canonical([name, row['rows'], row['cols'], len(row['data'])]))
        h.update(bytes(row['data']))
    return h.hexdigest()


def reference(record, request):
    """Streaming oracle: independent element-by-element row padding."""
    if record['meta'] != request['meta']:
        raise ValueError('descriptor')
    out = []
    for name in sorted(record['arrays']):
        arr = record['arrays'][name]
        r, c = arr['rows'], arr['cols']
        if len(arr['data']) != r*c:
            raise ValueError('length')
        if sha(bytes(arr['data'])) != request['array_hashes'][name]:
            raise ValueError('content')
        pr, pc = request['padding'][name]
        if r > pr or c > pc:
            raise ValueError('padding')
        out.append(bytes(arr['data'][i*c+j] if i < r and j < c else 0
                         for i in range(pr) for j in range(pc)))
    value = tuple(out)
    if sha(b''.join(value)) != request['public_digest']:
        raise ValueError('digest')
    return value


def construct(record, request):
    """Candidate bulk row copies, separate implementation from oracle."""
    if canonical(record['meta']) != canonical(request['meta']):
        raise ValueError('descriptor')
    result = []
    for name, arr in sorted(record['arrays'].items()):
        r, c = arr['rows'], arr['cols']
        data = bytes(arr['data'])
        if len(data) != r*c or sha(data) != request['array_hashes'][name]:
            raise ValueError('array')
        pr, pc = request['padding'][name]
        if pr < r or pc < c:
            raise ValueError('padding')
        padded = bytearray(pr*pc)
        for i in range(r):
            padded[i*pc:i*pc+c] = data[i*c:(i+1)*c]
        result.append(bytes(padded))
    result = tuple(result)
    if sha(b''.join(result)) != request['public_digest']:
        raise ValueError('digest')
    return result


@dataclass(frozen=True)
class Owner:
    key: bytes
    raw_fingerprint: str
    value: tuple


class PublicPool:
    def __init__(self, pinned, guard=True):
        self.pinned = frozenset(pinned)
        self.guard = guard
        self.entries = {}
        self.hits = self.constructs = self.revalidated_raw_bytes = 0

    def get(self, record, request):
        key = canonical(request)
        owner = self.entries.get(key)
        if owner is not None:
            if self.guard:
                self.revalidated_raw_bytes += sum(len(a['data']) for a in record['arrays'].values())
                if fingerprint(record) != owner.raw_fingerprint:
                    raise ValueError('changed source')
            self.hits += 1
            return owner.value
        value = construct(record, request)
        self.constructs += 1
        if request['meta']['layer'] in self.pinned:
            self.entries[key] = Owner(key, fingerprint(record), value)
        return value


def fixture(layer, rng):
    meta = dict(model='synthetic/model-A', checkpoint='synthetic-revision-A',
                config='config-A', approval='approval-A', export_profile='profile-A',
                manifest='manifest-'+str(layer), layer=layer, geometry=[5, 3, 7],
                tokens=128, padded_axes=[8, 4, 8], format='synthetic-public-v1',
                run_layers=list(range(32)), base_calibration=[7, 12, 3],
                own_calibration=[7 + layer % 2, 12, 3],
                exp_key=[layer % 3, 8], silu_key=[layer % 2, 10],
                rope_mode='generator', rope_theta=500000, source_format='R8-pinned')
    arrays, padding = {}, {}
    for name in ['wq', 'wk', 'wv', 'wo', 'wg', 'wu', 'wd',
                 'gamma_a', 'gamma_m', 'exp', 'act', 'rope_cos', 'rope_sin']:
        rows, cols = (5, 3) if name.startswith('w') else (1, 3)
        data = [rng.randrange(256) for _ in range(rows*cols)]
        arrays[name] = dict(rows=rows, cols=cols, data=data)
        padding[name] = [8, 4] if rows == 5 else [1, 4]
    rec = dict(meta=meta, arrays=arrays)
    req = dict(meta=copy.deepcopy(meta), padding=padding,
               array_hashes={n: sha(bytes(a['data'])) for n, a in arrays.items()})
    # Fixture digest calculated directly, not using candidate construction.
    raw = b''
    for n in sorted(arrays):
        a = arrays[n]; pr, pc = padding[n]
        raw += bytes(a['data'][i*a['cols']+j] if i<a['rows'] and j<a['cols'] else 0
                     for i in range(pr) for j in range(pc))
    req['public_digest'] = sha(raw)
    return rec, req


def outcome(f, *args):
    try:
        return ('ok', f(*args))
    except ValueError:
        return ('refused', None)


def lifetime_trace(pins, leases=2, borrowed=2, safe=True):
    """Abstract owner IDs, no actual model allocation; includes old leases.

    Two old-generation objects remain borrowed across model change.
    The limit is pinned slots + two streaming/prefetch slots. New admissions
    are optional: a miss always streams with the native loader.
    """
    budget = pins + leases
    old_live = {('old', i) for i in range(min(pins,borrowed))}
    retained = set()
    peaks = []
    admitted = denied = 0
    for i in range(pins):
        oid = ('new', i)
        # Conservative reserve includes the mandatory current/next envelope.
        accounted = len(old_live | retained) if safe else len(retained)
        if accounted + 1 + leases <= budget:
            retained.add(oid); admitted += 1
        else:
            denied += 1
        actual = len(old_live | retained) + leases
        peaks.append(actual)
    return dict(pins=pins, stream_slots=leases, borrowed_old_blocks=len(old_live), budget_blocks=budget,
                admitted=admitted, denied=denied, peak_blocks=max(peaks, default=leases),
                peak_bytes=max(peaks, default=leases)*BLOCK_BYTES,
                within_budget=max(peaks, default=leases)<=budget)


def main():
    cap(); t0 = time.perf_counter(); rng = random.Random(SEED)
    records = [fixture(k, rng) for k in range(32)]
    controls, ledgers = {}, []
    # Normal scans: immutable values must agree at every request; not proofs.
    for passes in [1, 2, 4, 8]:
        for n in [0, 1, 4, 16, 32]:
            pool = PublicPool(range(n))
            for _ in range(passes):
                for phase in ['seal', 'prove']:
                    for rec, req in records:
                        got = pool.get(rec, req); ref = reference(rec, req)
                        check(got == ref)
                        for a, b in zip(got, ref):
                            check(a == b)
            requests = 64*passes
            check(pool.hits == n*(2*passes-1))
            check(pool.constructs == requests-pool.hits)
            ledgers.append(dict(passes=passes, pins=n, requests=requests,
                                hits=pool.hits, constructs=pool.constructs,
                                revalidated_raw_bytes=pool.revalidated_raw_bytes,
                                raw_read_requests=requests,
                                pinned_payload_bytes=n*BLOCK_BYTES,
                                peak_public_envelope_bytes=(n+min(2,32-n))*BLOCK_BYTES))

    rec, req = records[0]
    pool = PublicPool([0]); pool.get(rec, req)
    for field in req['meta']:
        bad = copy.deepcopy(req)
        v = bad['meta'][field]
        bad['meta'][field] = v+1 if isinstance(v,int) else v+[99] if isinstance(v,list) else v+'-changed'
        check(outcome(pool.get,rec,bad) == outcome(reference,rec,bad))
        check(outcome(pool.get,rec,bad)[0] == 'refused')
    controls['all_descriptor_fields_refuse_cross_identity'] = True
    # Mutations with the ORIGINAL requested identity: the hard cache-hit case.
    stale = []
    for name in rec['arrays']:
        bad = copy.deepcopy(rec); bad['arrays'][name]['data'][0] ^= 1
        guarded = PublicPool([0]); guarded.get(rec,req)
        unsafe = PublicPool([0],guard=False); unsafe.get(rec,req)
        check(outcome(reference,bad,req)[0] == 'refused')
        check(outcome(guarded.get,bad,req)[0] == 'refused')
        check(outcome(unsafe.get,bad,req)[0] == 'ok')
        stale.append(name)
    controls['complete_key_does_not_detect_mutated_backing_bytes'] = True
    controls['raw_guard_detects_every_tested_array_mutation'] = True
    # Invalid length and altered manifest/table key remain refused on hits.
    for kind in ['length','manifest','exp_key','rope_mode']:
        bad=copy.deepcopy(rec)
        if kind=='length': bad['arrays']['wq']['data'].pop()
        elif kind=='exp_key': bad['meta'][kind][0]+=1
        else: bad['meta'][kind]+='-changed'
        check(outcome(pool.get,bad,req)[0]=='refused')
        check(outcome(reference,bad,req)[0]=='refused')
    controls['length_manifest_table_rope_mutations_refused'] = True
    owner=pool.entries[canonical(req)]
    immutable=False
    try: owner.value[0][0]=1
    except TypeError: immutable=True
    check(immutable); controls['owned_payload_is_immutable_bytes'] = True
    # Show omitted identity components alias old and new requests even if
    # byte-equal; this is an identity/refusal test, not a soundness attack.
    aliases=[]
    for field in req['meta']:
        bad=copy.deepcopy(req); bad['meta'][field]=None
        def omitted_key(x):
            y=copy.deepcopy(x); y['meta'].pop(field); return canonical(y)
        check(omitted_key(req)==omitted_key(bad)); check(canonical(req)!=canonical(bad))
        aliases.append(field)
    controls['each_omitted_identity_component_aliases'] = True
    safe=lifetime_trace(4,safe=True); unsafe=lifetime_trace(4,safe=False)
    check(safe['within_budget']); check(not unsafe['within_budget'])
    check(safe['denied']==2); check(unsafe['peak_blocks']==8)
    controls['eviction_does_not_free_borrowed_generation'] = True
    controls['admission_charges_live_objects_and_stream_reserve'] = True
    # Pin/source checks assert actual seams have not drifted.
    pins=json.loads((HERE/'source-pins.json').read_text())
    for pin in pins:
        check(sha(Path(pin['source']).read_bytes())==pin['sha256'])
        check(sha((HERE/pin['snapshot']).read_bytes())==pin['sha256'])
    native=(HERE/'native/hashline__src__private_block__trained_block.rs').read_text()
    for anchor in ['self.cur = None;', 'if blk.digest() != self.digests[k]',
                   'rayon::join(', 'self.load_layer_mode(sh, c, index, rope_from_export, false)',
                   'let cache = BlockCache::shared', 'fn seal_and_record(']:
        check(anchor in native)
    (HERE/'fixtures.json').write_text(json.dumps(records,indent=2)+'\n')
    (HERE/'request-ledger.json').write_text(json.dumps(ledgers,indent=2)+'\n')
    (HERE/'lifetime-ledger.json').write_text(json.dumps(dict(safe=safe,unsafe=unsafe,
        note='Logical public payload only; excludes raw decode/padding temporaries, witnesses, proof buffers, allocator and device.'),indent=2)+'\n')
    result=dict(status='PASS',run_id='20261019T171854Z-d589849d',seed=SEED,
        checks=checks,negative_controls=controls,identity_fields=len(aliases),
        stale_array_counterexamples=stale,source_pins=len(pins),
        synthetic_requests=sum(x['requests'] for x in ledgers),
        pinned4_R8=next(x for x in ledgers if x['pins']==4 and x['passes']==8),
        safe_generation_overlap=safe,unsafe_generation_overlap=unsafe,
        scope='Synthetic public-array padding/identity/freshness/lease accounting only. No native CS/H-1/proof/privacy equivalence or cache performance.',
        conclusion='Key-only owner fails streaming source-change refusal semantics. Guarded owner preserves synthetic outcomes but eliminates zero raw reads; only construction is avoided. Lease-aware admission required.',
        limits='59s CPU/wall,512MiB address space;estimated64MiB;one nice19 CPU;no GPU/build/install/foreign code',
        wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),
        python=platform.python_version(),platform=platform.platform(),
        cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))


if __name__=='__main__': main()
