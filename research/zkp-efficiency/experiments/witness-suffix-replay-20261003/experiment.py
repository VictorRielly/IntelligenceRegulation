#!/usr/bin/env python3
"""CPU-only lossless RAM replay oracle; no native proof or real model data."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import re
import resource
import signal
import struct
import sys
import time

ROOT = Path('/home/victor/IntelligenceRegulation')
HERE = Path(__file__).resolve().parent
SEED = 2026100316
RUN = '20261003T220146Z-cf20886e'
SOURCE = ROOT / 'ops/zkp-mvp/sonnet-hardening/hashline/src/private_block'
FILES = ['mvp_driver.rs', 'witness.rs', 'layout.rs', 'shape.rs', 'run.rs', 'protocol.rs']


def digest(planes):
    """Independent canonical i64 reference, including empty-plane boundaries."""
    h = hashlib.sha256()
    h.update(struct.pack('<Q', len(planes)))
    for p in planes:
        h.update(struct.pack('<Q', len(p)))
        for v in p:
            h.update(struct.pack('<q', v))
    return h.digest()


def pack_plane(p):
    if any(type(v) is not int or not -(1 << 63) <= v < (1 << 63) for v in p):
        raise ValueError('not i64')
    lo, hi = (min(p), max(p)) if p else (0, 0)
    signed = lo < 0
    for width in (1, 2, 4, 8):
        fits = (-(1 << (8 * width - 1)) <= lo and hi < (1 << (8 * width - 1))) if signed else hi < (1 << (8 * width))
        if fits:
            break
    blob = b''.join(v.to_bytes(width, 'little', signed=signed) for v in p)
    return width, signed, len(p), blob


def unpack_plane(rec, expected):
    w, signed, n, blob = rec
    if w not in (1, 2, 4, 8) or type(signed) is not bool or n != expected or len(blob) != n * w:
        raise ValueError('plane metadata')
    p = tuple(int.from_bytes(blob[i:i+w], 'little', signed=signed) for i in range(0, len(blob), w))
    if any(v >= 1 << 63 for v in p):
        raise ValueError('not i64')
    return p


def model(layers, width):
    r = random.Random(SEED + width + layers)
    return tuple(tuple(tuple(r.randrange(-2, 3) for _ in range(width)) for _ in range(width)) for _ in range(layers))


def build(x, weights, t, d, refuse=False):
    """Reduced deterministic attention+FFN stand-in, not native block semantics."""
    if refuse:
        raise ValueError('synthetic late range refusal')
    q = tuple((sum(x[a*d+i] * weights[j][i] for i in range(d)) + 4) // 8 for a in range(t) for j in range(d))
    scores = tuple(sum(q[a*d+i] * q[b*d+i] for i in range(d)) for a in range(t) for b in range(t))
    # All pairs checked, including future pairs, like the frozen range obligation.
    if any(not -32768 <= s <= 32767 for s in scores):
        raise ValueError('synthetic score range')
    mixed = tuple(sum(q[b*d+i] for b in range(a+1)) // (a+1) for a in range(t) for i in range(d))
    ff = tuple((sum(mixed[a*d+i] * weights[j][i] for i in range(d)) + 16) // 32 for a in range(t) for j in range(d))
    y = tuple(x[i] + ff[i] for i in range(t*d))
    if any(not -32768 <= v <= 32767 for v in y):
        raise ValueError('synthetic residual range')
    # Deliberately nonzero padding analogue and genuinely EMPTY histograms.
    pad_exp = (512, 1, 512, 1)
    return (tuple(x), q, scores, mixed, ff, y, pad_exp, (), (), ())


def reference(x, weights, t, d):
    """Separate loops and divmod rounding, without the candidate source/cache."""
    rows = [list(x[a*d:(a+1)*d]) for a in range(t)]
    out = []
    for w in weights:
        qs = []
        for row in rows:
            qr = []
            for wr in w:
                acc = 0
                for a, b in zip(row, wr):
                    acc += a*b
                qr.append(divmod(acc+4, 8)[0])
            qs.append(qr)
        sc = []
        for a in range(t):
            for b in range(t):
                sc.append(sum(a*b for a,b in zip(qs[a], qs[b])))
        mr = [[divmod(sum(qs[b][i] for b in range(a+1)), a+1)[0] for i in range(d)] for a in range(t)]
        fr = [[divmod(sum(mr[a][i]*w[j][i] for i in range(d))+16, 32)[0] for j in range(d)] for a in range(t)]
        yr = [[rows[a][i]+fr[a][i] for i in range(d)] for a in range(t)]
        flat = lambda z: tuple(v for row in z for v in row)
        out.append((flat(rows), flat(qs), tuple(sc), flat(mr), flat(fr), flat(yr), (512,1,512,1), (), (), ()))
        rows = yr
    return out


class ReplaySource:
    """One sealing/proving attempt; cache contains no RNG, masks or commitments."""
    def __init__(self, x, weights, t, d, suffix, budget=1 << 20, run=RUN):
        self.initial = tuple(x)
        self.weights = weights
        self.t, self.d = t, d
        self.suffix, self.budget, self.run = suffix, budget, run
        self.model_id = hashlib.sha256(repr(weights).encode()).digest()
        self.cache = {}
        self.cache_bytes = 0
        self.builds = self.replays = 0
        self.next = 0
        self.pending = None
        self.x = self.initial
        self.phase = 'new'
        self.pack_s = self.unpack_s = 0.0

    def prepass(self, fail_layer=None):
        if self.phase != 'new':
            raise ValueError('prepass phase')
        x = self.initial
        try:
            for k, w in enumerate(self.weights):
                planes = build(x, w, self.t, self.d, k == fail_layer)
                self.builds += 1
                if k >= len(self.weights) - self.suffix:
                    at = time.perf_counter()
                    recs = tuple(pack_plane(p) for p in planes)
                    sizes = tuple(map(len, planes))
                    # 16 bytes per plane metadata + 96-byte private context/digest allowance.
                    cost = sum(len(r[3]) + 16 for r in recs) + 96
                    # Optional optimization must not add hidden-input refusals.
                    # Retain newest suffix entries; evict or skip then recompute.
                    while self.cache and self.cache_bytes + cost > self.budget:
                        old = self.cache.pop(min(self.cache))
                        self.cache_bytes -= sum(len(r[3])+16 for r in old[5])+96
                    if cost <= self.budget:
                        self.cache[k] = (self.run, self.model_id, k, sizes, digest(planes), recs)
                        self.cache_bytes += cost
                    self.pack_s += time.perf_counter() - at
                x = planes[5]
        except ValueError:
            self.cache.clear()
            self.cache_bytes = 0
            self.phase = 'failed'
            raise
        self.sealed = x
        self.phase = 'sealed'
        return self.initial, x

    def restart(self, x):
        if self.phase != 'sealed' or tuple(x) != self.initial:
            raise ValueError('restart context')
        self.x = tuple(x)
        self.next = 0
        self.builds = 0
        self.phase = 'prove'

    def advance(self, k):
        if self.phase != 'prove' or k != self.next or k >= len(self.weights):
            raise ValueError('order or phase')
        if k in self.cache:
            at = time.perf_counter()
            run, mid, stage, sizes, pin, recs = self.cache.pop(k)
            if (run, mid, stage) != (self.run, self.model_id, k) or len(recs) != len(sizes):
                raise ValueError('cache context')
            planes = tuple(unpack_plane(r, n) for r,n in zip(recs,sizes))
            if digest(planes) != pin or planes[0] != self.x:
                raise ValueError('cache integrity or chain')
            self.replays += 1
            self.unpack_s += time.perf_counter() - at
        else:
            planes = build(self.x, self.weights[k], self.t, self.d)
            self.builds += 1
        self.x = planes[5]
        self.next += 1
        if self.next == len(self.weights) and self.x != self.sealed:
            raise ValueError('sealed output mismatch')
        return planes

    def boundary_plane(self, k):
        if self.pending is not None:
            raise ValueError('pending witness')
        p = self.advance(k)
        self.pending = (k, p)
        return p[5]

    def witness(self, k):
        if self.pending is not None:
            j, p = self.pending
            self.pending = None
            if j != k:
                raise ValueError('pending stage')
            return p
        return self.advance(k)


def manifest(ln, ls, lp):
    # Independent named list from witness.rs typed outputs; E/SUM retain i64.
    groups = [('T',[4,8,4,8]), ('Ht',[1,8]), ('L',[1,1]),
              ('D',[2,1,1,1] + [1]*(2*ln) + [2,1,1,1,2,1,1,1] + [1]*(2*ln) + [2,2,1,1,1,1,1]),
              ('Q',[1]*7), ('Kv',[1]*6), ('S',[1,1,1,8,2]+[1]*(lp+2*ls)),
              ('F',[1,1,2,2,1,1,2,1,1,1,1])]
    return [(dom,w) for dom, widths in groups for w in widths]


def ledger(layout, shape):
    consts = {name: int(v) for name,v in re.findall(r'const (A_\w+|LN_TOY|LS_TOY|LP_TOY): usize = (\d+);',layout)}
    section = layout.split('let segs:')[-1].split('let mut map')[0]
    segs = re.findall(r'\((A_\w+), (\d+|LN_TOY|LS_TOY|LP_TOY), (\d+|ln|ls|lp), Dom::(\w+)\)', section)
    assert len(segs) == 18
    rows = []
    for name,t,d,f,h,kv,dh,lc,fe,layers,admitted in [
        ('toy',32,16,16,2,1,8,8,9,1,True),
        ('rung_p2',32,96,256,12,4,8,10,12,3,True),
        ('m125',512,768,2048,12,4,64,14,9,12,True),
        ('llama3_8b_T512',512,4096,14336,32,8,128,14,9,32,False),
        ('llama3_8b_T1024',1024,4096,14336,32,8,128,14,9,32,False),
        ('llama3_8b_T2048',2048,4096,14336,32,8,128,14,9,32,False)]:
        pad = lambda x: 1 << (x-1).bit_length()
        tp,dp,fp,hp = map(pad,(t,d,f,h))
        # Correct full signed-int16 endpoint bound, including -32768 and epsilon.
        ln = math.ceil((12+math.isqrt(1+d*32768**2).bit_length())/8)
        ls, lp = math.ceil(((t-1).bit_length()+fe)/8), 2
        sizes = dict(T=tp,Ht=hp*tp,L=max(16*tp,1<<lc),D=max(tp*dp,1<<lc),Q=max(tp*hp*dh,1<<lc),Kv=max(tp*kv*dh,1<<lc),S=max(hp*tp*tp,1<<lc),F=max(tp*fp,1<<lc),Tab=max(256,1<<lc))
        env = dict(ln=ln,ls=ls,lp=lp)
        parsed = []
        for _,_,n,dom in segs:
            if dom != 'Tab':
                parsed += [dom]*(int(n) if n.isdigit() else env[n])
        named = manifest(ln,ls,lp)
        assert parsed == [d for d,_ in named]
        # Independent closed-form plane count, from Shape::a_plane_doms.
        assert len(parsed) == 4+2+2+(19+4*ln)+7+6+(5+lp+2*ls)+11
        raw = sum(sizes[d]*8 for d in parsed)
        typed = sum(sizes[d]*w for d,w in named)
        floor = sum(sizes[d] for d in parsed)
        # Public fixed RAM budget examples, excluding all enclosing proof memory.
        budget_rows = []
        for b in (256<<20,1<<30,4<<30):
            k = min(layers,b//typed)
            budget_rows.append(dict(cache_budget_bytes=b,max_suffix_layers_by_payload=k,
                rebuilt_layers=layers-k,removed_fraction_of_second_build_count=k/layers,
                payload_bytes=k*typed,not_peak_memory=True))
        rows.append(dict(name=name,tokens=t,layers=layers,width=d,hidden=f,q_heads=h,kv_heads=kv,head_dim=dh,log_cols=lc,
             norm_limbs=ln,softmax_limbs=ls,witness_plane_count=len(parsed),i64_payload_bytes=raw,
             conservative_typed_payload_bytes=typed,one_byte_per_entry_floor=floor,
             complete_stack_i64_payload_bytes=raw*layers,complete_stack_typed_payload_bytes=typed*layers,
             replay_minimum_logical_read_write_bytes_per_cached_layer=2*(raw+typed),
             minimum_traffic_excludes_extrema_scans_checksums_input_and_output_copies=True,
             attention_i64_payload_bytes=sum(sizes[dom]*8 for dom in parsed if dom=='S'),
             guaranteed_small_dtype_manifest_requires_native_validation=True,
             registered_witness_geometry=admitted,
             builder_refuses_norm_limbs=ln!=4,
             payload_only_excludes_weights_helpers_commitments_scratch_allocator_and_pack_overlap=True,
             cache_budget_examples=budget_rows))
    assert 'v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);' in shape
    return rows


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(55,55))
    signal.alarm(59)
    if hasattr(os,'sched_getaffinity'):
        os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    at = time.perf_counter()
    snapshots = HERE/'snapshots'
    snapshots.mkdir(exist_ok=True)
    pins = {}
    texts = {}
    for name in FILES:
        data = (SOURCE/name).read_bytes()
        pins[str((SOURCE/name).relative_to(ROOT))] = hashlib.sha256(data).hexdigest()
        (snapshots/name).write_bytes(data)
        texts[name] = data.decode()
    additional = [
        'results/zk60_sol_model_20260927/layout_account.json',
        'results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/report.json',
        'results/zk60_mvp_20260929/cli-stack-gpu/report.json',
        'results/zk60_mvp_20260929/llama3-8b/config.json',
    ]
    for rel in additional:
        data = (ROOT/rel).read_bytes()
        pins[rel] = hashlib.sha256(data).hexdigest()
        (snapshots/rel.replace('/','__')).write_bytes(data)
    old_layout = json.loads((ROOT/additional[0]).read_text())
    cfg = json.loads((ROOT/additional[3]).read_text())
    assert (cfg['hidden_size'],cfg['intermediate_size'],cfg['num_attention_heads'],cfg['num_key_value_heads'],cfg['num_hidden_layers']) == (4096,14336,32,8,32)
    controls = []
    def reject(name, fn):
        try:
            fn()
        except (ValueError, OverflowError):
            controls.append(name)
        else:
            raise AssertionError('negative accepted: '+name)
    r = random.Random(SEED)
    # Signed/unsigned extrema, width promotion, empty, pad and 64-bit fallback.
    vectors = [(),(-128,-1,0,127),(0,127,128,255),(-32768,32767),
        (0,65535),(-(1<<31),(1<<31)-1),(0,(1<<32)-1),(-(1<<63),(1<<63)-1),
        (0,512,0,512),(0,)*7]
    for _ in range(100):
        bits = r.choice([7,8,15,16,31,32,62])
        vectors.append(tuple(r.randrange(-(1<<bits),(1<<bits)) for _ in range(r.randrange(1,35))))
    bytes_raw=bytes_packed=0
    for p in vectors:
        rec = pack_plane(p)
        assert unpack_plane(rec,len(p)) == p
        code = {(1,True):'b',(1,False):'B',(2,True):'h',(2,False):'H',(4,True):'i',(4,False):'I',(8,True):'q',(8,False):'Q'}[rec[:2]]
        assert rec[3] == struct.pack('<'+code*len(p),*p)
        bytes_raw += 8*len(p)
        bytes_packed += len(rec[3])
    reject('i64_overflow_no_truncation',lambda:pack_plane((1<<63,)))
    reject('i64_underflow_no_truncation',lambda:pack_plane((-(1<<63)-1,)))
    reject('truncated_plane',lambda:unpack_plane((2,True,2,b'abc'),2))
    reject('length_metadata',lambda:unpack_plane(pack_plane((1,2)),3))
    reject('invalid_width',lambda:unpack_plane((3,True,1,b'abc'),1))
    cases=[]
    comparisons=0
    for t,d,l in [(2,4,1),(3,8,3),(7,8,6),(16,16,8)]:
        x=tuple(r.randrange(-12,13) for _ in range(t*d))
        ws=model(l,d)
        ref=reference(x,ws,t,d)
        for suffix in sorted({0,1,l//2,l}):
            s=ReplaySource(x,ws,t,d,suffix)
            begin=time.perf_counter()
            assert s.prepass() == (x,ref[-1][5])
            prepass_s=time.perf_counter()-begin
            peak=s.cache_bytes
            assert s.builds == l
            s.restart(x)
            got=[]
            begin=time.perf_counter()
            for k in range(l):
                if k+1<l:
                    assert s.boundary_plane(k) == ref[k][5]
                p=s.witness(k)
                assert p == ref[k]
                comparisons += len(p)
                got.append(p)
            prove_witness_s=time.perf_counter()-begin
            assert not s.cache and s.builds == l-suffix and s.replays == suffix
            # A fresh proof-state seed changes mock proof material, not witness replay.
            pins_p=b''.join(digest(p) for p in got)
            assert hashlib.sha256(b'fresh-proof-A'+pins_p).digest()!=hashlib.sha256(b'fresh-proof-B'+pins_p).digest()
            cases.append(dict(tokens=t,width=d,layers=l,suffix=suffix,sealing_builds=l,
                recurring_builds=s.builds,replays=s.replays,cache_accounted_bytes=peak,
                prepass_s=prepass_s,recurring_witness_oracle_s=prove_witness_s,pack_s=s.pack_s,unpack_s=s.unpack_s,
                oracle_digest=hashlib.sha256(pins_p).hexdigest()))
    def ready():
        s=ReplaySource((1,)*12,model(3,4),3,4,3)
        s.prepass();s.restart(s.initial)
        return s
    s=ready()
    reject('out_of_order',lambda:s.witness(1))
    s=ready();s.boundary_plane(0)
    reject('duplicate_boundary',lambda:s.boundary_plane(1))
    reject('wrong_pending_stage',lambda:s.witness(1))
    s=ready()
    reject('restart_twice',lambda:s.restart(s.initial))
    s=ReplaySource((1,)*12,model(3,4),3,4,3);s.prepass()
    reject('different_restart_input',lambda:s.restart((2,)*12))
    for label,idx,value in [('foreign_run',0,'other'),('foreign_model',1,b'foreign'),('wrong_cached_layer',2,7)]:
        s=ready();entry=list(s.cache[0]);entry[idx]=value;s.cache[0]=tuple(entry)
        reject(label,lambda:s.witness(0))
    s=ready();entry=list(s.cache[0]);recs=list(entry[5]);rec=list(recs[1]);rec[3]=bytes([rec[3][0]^1])+rec[3][1:];recs[1]=tuple(rec);entry[5]=tuple(recs);s.cache[0]=tuple(entry)
    reject('cached_plane_tamper',lambda:s.witness(0))
    s=ready();s.x=(2,)*12
    reject('chain_input_mismatch',lambda:s.witness(0))
    s=ready();entry=list(s.cache[0]);entry[3]=entry[3][:-1];entry[5]=entry[5][:-1];s.cache[0]=tuple(entry)
    reject('missing_empty_histogram_changes_plane_inventory',lambda:s.witness(0))
    for budget in (0,1,400,800):
        s=ReplaySource((1,)*12,model(3,4),3,4,3,budget=budget)
        ref=reference(s.initial,s.weights,3,4)
        s.prepass()
        assert s.cache_bytes <= budget
        s.restart(s.initial)
        assert [s.witness(k) for k in range(3)] == ref
    controls.append('four_budget_exhaustion_cases_fall_back_without_new_refusal')
    s=ReplaySource((1,)*12,model(3,4),3,4,3)
    reject('late_sealing_refusal_clears_cache',lambda:s.prepass(fail_layer=2))
    assert s.phase=='failed' and not s.cache
    # Negative alternative: compacting every padded value to zero changes relation.
    p=reference((1,)*12,model(3,4),3,4)[0]
    z=list(p);z[6]=(0,)*4
    assert digest(z)!=digest(p)
    controls.append('unsafe_zero_pad_changes_nonzero_exp_analogue')
    controls.append('fresh_proof_state_separate_from_cached_witness')
    cpu=next((v.split(':',1)[1].strip() for v in Path('/proc/cpuinfo').read_text().splitlines() if v.startswith('model name')),'unknown')
    geometry = ledger(texts['layout.rs'],texts['shape.rs'])
    for row in geometry:
        if row['name'] in ('toy','m125'):
            assert row['i64_payload_bytes'] == old_layout[row['name']]['witness_A_plane_i64_payload_bytes']
    result=dict(run_identity=RUN,seed=SEED,status='passed',vector_cases=len(vectors),
        independent_struct_byte_comparisons=len(vectors),independent_forward_plane_comparisons=comparisons,
        raw_vector_bytes=bytes_raw,packed_vector_bytes=bytes_packed,cases=cases,negative_controls=controls,
        source_counted_geometry=geometry,independent_prior_native_layout_matches=['toy','m125'],source_pins_sha256=pins,
        script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        elapsed_s=time.perf_counter()-at,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        threads=1,cpu=cpu,device='CPU only; no accelerator',python=platform.python_version(),platform=platform.platform(),
        limits=dict(wall_s=59,cpu_s=55,address_space_mib=512,estimated_memory_mib=32),
        scope='Lossless synthetic integer packing and reduced deterministic in-memory two-pass replay. NOT native block equivalence, cryptographic proof, GPU or trained model. Mock fresh-state digests are not proof transcripts.',
        full_stack=dict(completed_independently_verified_model_passes=0,countable_tokens=0,context_length=None,passes=0,
            steady_tokens_per_s=None,total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,proof_lag_s=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','vector_cases','independent_forward_plane_comparisons','elapsed_s','peak_rss_kib','negative_controls']}))


if __name__=='__main__':
    main()
