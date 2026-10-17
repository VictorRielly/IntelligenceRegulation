#!/usr/bin/env python3
"""Synthetic exact tiled down/requant oracle; no native code or GPU execution."""
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import struct
import sys
import time

ROOT = Path(__file__).resolve().parent
RUN = '20261004T050146Z-1f54a8f9'
SEED = 2026100423
I16 = (-32768, 32767)
I32 = (-(1 << 31), (1 << 31) - 1)
I64 = (-(1 << 63), (1 << 63) - 1)


def bound(v, limits):
    assert limits[0] <= v <= limits[1], (v, limits)
    return v


def shape(m, k, n, mp, kp, np, x, w, mode):
    assert 0 < m <= mp and 0 < k <= kp and 0 < n <= np
    assert len(x) == mp * kp and len(w) == kp * np
    assert mode in ('in_out', 'out_in')


def reference(x, w, m, k, n, mp, kp, np, mode, shift=6, x1=None):
    """Independent materialized checked-i64 dot, then floor-div quantization.

    Computes every padded output column on true rows, as the native helper
    does, but quantizes only true (t,j) support. Audit acc is test-only.
    """
    shape(m, k, n, mp, kp, np, x, w, mode)
    acc = [0] * (mp * np)
    for t in range(m):
        for j in range(np):
            z = 0
            for i in range(kp):
                ix = i * np + j if mode == 'in_out' else j * kp + i
                z = bound(z + bound(x[t * kp + i] * w[ix], I64), I64)
            acc[t * np + j] = z
    y, rem = [0] * (mp * np), [0] * (mp * np)
    half = 0 if shift == 0 else 2 ** (shift - 1)
    failures = []
    for t in range(m):
        for j in range(n):
            ix = t * np + j
            q = (acc[ix] + half) // (2 ** shift)
            if not I16[0] <= q <= I16[1]:
                failures.append(ix)
            y[ix], rem[ix] = q, acc[ix] - q * (2 ** shift) + half
    if failures:
        return {'refusal': 'FFN down', 'first_index': min(failures)}
    if x1 is not None:
        out = [0] * len(y)
        for t in range(m):
            for j in range(n):
                ix = t * np + j
                out[ix] = x1[ix] + y[ix]
                if not I16[0] <= out[ix] <= I16[1]:
                    return {'refusal': 'residual 2', 'first_index': ix}
        return {'y': y, 'rem': rem, 'x2': out}
    return {'y': y, 'rem': rem}


def pack(x, t0, rows, k0, width, kp):
    low, high = [], []
    for t in range(t0, t0 + rows):
        for i in range(k0, k0 + width):
            v = bound(x[t * kp + i], I16)
            low.append((v & 255) - 128)
            high.append(v >> 8)
    return low + high


def byte_tile(packed, w, rows, width, k0, j0, cols, kp, np, mode):
    """One conceptual stacked [low;high] byte GEMM with exact i32 outputs."""
    out = [0] * (2 * rows * cols)
    for r in range(2 * rows):
        for j in range(cols):
            z = 0
            for i in range(width):
                ix = (k0 + i) * np + j0 + j if mode == 'in_out' else (j0 + j) * kp + k0 + i
                z = bound(z + packed[r * width + i] * w[ix], I32)
            out[r * cols + j] = z
    return out


def candidate(x, w, m, k, n, mp, kp, np, mode, mt, nt, kt, shift=6,
              x1=None, schedule='forward', mutant=None, stats=None):
    """Tile reconstruction is integer-only; round only after the full K sum.

    Full K reuses one row-packed buffer across column tiles. Split K uses
    tile-local packing and i64 reduction; its repacking cost is explicit.
    A public tile schedule may differ from support order. A private failure
    index is reduced to the same first support index; it never leaves prover.
    """
    shape(m, k, n, mp, kp, np, x, w, mode)
    assert min(mt, nt, kt) > 0 and min(kt, kp) * 16384 <= I32[1]
    y, rem = [0] * (mp * np), [0] * (mp * np)
    sums = [sum(w[i * np + j if mode == 'in_out' else j * kp + i]
                for i in range(kp)) for j in range(n)]
    ranges = list(range(0, m, mt))
    columns = list(range(0, n, nt))
    if schedule == 'reverse':
        ranges.reverse(); columns.reverse()
    failures = []
    trace = []
    for t0 in ranges:
        rows = min(mt, m - t0)
        full_pack = pack(x, t0, rows, 0, kp, kp) if kt >= kp else None
        if stats is not None and full_pack is not None:
            stats['packed_values'] += len(full_pack)
        for j0 in columns:
            cols = min(nt, n - j0)
            accum = [0] * (rows * cols) if kt < kp else None
            for k0 in range(0, kp, kt):
                width = min(kt, kp - k0)
                p = full_pack if full_pack is not None else pack(x, t0, rows, k0, width, kp)
                if stats is not None and full_pack is None:
                    stats['packed_values'] += len(p)
                parts = byte_tile(p, w, rows, width, k0, j0, cols, kp, np, mode)
                if stats is not None:
                    stats['byte_gemm_calls'] += 1
                    stats['byte_products'] += 2 * rows * width * cols
                for r in range(rows):
                    for j in range(cols):
                        ij = r * cols + j
                        # Correction is applied ONCE after all K tiles. Each
                        # signed-byte partial is widened before combination.
                        z = bound(parts[ij] + 256 * parts[rows * cols + ij], I64)
                        if mutant == 'float_partial':
                            f = struct.unpack('<f', struct.pack('<f', parts[ij]))[0]
                            z = int(f) + 256 * parts[rows * cols + ij]
                        if kt < kp:
                            if mutant == 'round_k_tile':
                                z = (z + 128 * sum(w[i * np + j0 + j if mode == 'in_out' else (j0 + j) * kp + i]
                                                   for i in range(k0, k0 + width)) + (1 << (shift - 1))) >> shift
                            accum[ij] = bound(accum[ij] + z, I64)
                            if k0 + width < kp:
                                continue
                            z = accum[ij]
                        if mutant == 'round_k_tile' and kt < kp:
                            q, biased = z, 0
                        else:
                            correction = 128 * sums[j0 + j]
                            if mutant == 'correction_each':
                                correction *= (kp + kt - 1) // kt
                            if mutant == 'skip_correction':
                                correction = 0
                            z = bound(z + correction, I64)
                            if mutant == 'i32_reconstruct':
                                z = (z + (1 << 31)) % (1 << 32) - (1 << 31)
                            half = 0 if shift == 0 else 1 << (shift - 1)
                            q = (z + half) >> shift
                            biased = z - (q << shift) + half
                        ix = (t0 + r) * np + j0 + j
                        if not I16[0] <= q <= I16[1]:
                            failures.append(ix)
                        y[ix], rem[ix] = q, biased
                        trace.append(ix)
                        if mutant == 'residual_early' and x1 is not None and not I16[0] <= x1[ix] + q <= I16[1]:
                            return {'refusal': 'residual 2', 'first_index': ix}
    if failures:
        return {'refusal': 'FFN down', 'first_index': failures[0] if mutant == 'first_completed' else min(failures)}
    assert sorted(trace) == [t * np + j for t in range(m) for j in range(n)]
    if x1 is not None:
        out = [0] * len(y)
        for t in range(m):
            for j in range(n):
                ix = t * np + j
                out[ix] = x1[ix] + y[ix]
                if not I16[0] <= out[ix] <= I16[1]:
                    return {'refusal': 'residual 2', 'first_index': ix}
        return {'y': y, 'rem': rem, 'x2': out}
    return {'y': y, 'rem': rem}


def matrix(rng, m, k, n, mp, kp, np, style, dirty=False):
    x, w = [0] * (mp * kp), [0] * (kp * np)
    for t in range(m):
        for i in range(k):
            x[t * kp + i] = rng.randint(-500, 500) if style == 'small' else rng.choice(I16)
    for i in range(k):
        for j in range(n):
            w[i * np + j] = rng.randint(-3, 3) if style == 'small' else rng.choice((-128, 127))
    if dirty:
        for t in range(m):
            for i in range(k, kp):
                x[t * kp + i] = 99 + t
                for j in range(n):
                    w[i * np + j] = 7
        # Padded token rows are deliberately nonzero: helper never reads them.
        for t in range(m, mp):
            for i in range(kp): x[t * kp + i] = 32768
        # Padded output columns may be dirty: quantize does not consume them.
        for i in range(kp):
            for j in range(n, np): w[i * np + j] = 127
    return x, w


def accounting(m, k, n, mp, np, mt, nt, kt):
    """One-tier logical payload ledger. No hardware/cache/timing assumptions.

    Baseline materialized split schedule releases packed after GEMM, releases
    partials after reconstruct, then allocates final planes. This is already
    an optimistic baseline; it is not the current CPU-only native helper.
    """
    final = 16 * mp * np
    packed = 2 * m * k
    parts = 8 * m * np
    raw = 8 * mp * np
    baseline_phases = {'stacked_gemm': packed + parts,
                       'reconstruct_after_pack_release': parts + raw,
                       'requant_after_partial_release': raw + final}
    mb, nb, kb = min(mt, m), min(nt, n), min(kt, k)
    tiled_pack = 2 * mb * kb
    tiled_parts = 8 * mb * nb
    reduction = 8 * mb * nb if kt < k else 0
    # Retain packed/partials through reconstruction as a conservative choice.
    tiled_peak = final + tiled_pack + tiled_parts + reduction
    bm, bn, bk = (m + mt - 1)//mt, (n + nt - 1)//nt, (k + kt - 1)//kt
    return {'M':m, 'K':k, 'N_true':n, 'M_pad':mp, 'N_pad':np,
            'tile':[mt, nt, kt], 'final_z16_RDL_bytes':final,
            'materialized_split_phase_bytes':baseline_phases,
            'materialized_split_peak_bytes':max(baseline_phases.values()),
            'native_CPU_down_acc_plus_final_peak_bytes':raw + final,
            'tiled_pack_bytes':tiled_pack, 'tiled_partial_bytes':tiled_parts,
            'tiled_i64_K_reduction_bytes':reduction, 'tiled_peak_bytes':tiled_peak,
            'payload_peak_difference_bytes':max(baseline_phases.values()) - tiled_peak,
            'conceptual_stacked_gemm_calls':bm * bn * bk,
            'conceptual_reconstruction_calls':bm * bn * bk,
            'packing_bytes_total':2 * m * k * (bn if kt < k else 1),
            'naive_weight_read_bytes_total':bm * k * n,
            'weight_bytes_once':k * np,
            'final_plane_bytes_unchanged':True,
            'omitted':'BLAS workspace, retained input/weights/other witness planes, host/device duplication, transfers, pools, status flags, cache and actual allocator peaks'}


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    start = time.monotonic(); rng = random.Random(SEED)
    digest = hashlib.sha256(); controls = []; outcomes = {}; count = words = 0
    stat = {'packed_values':0, 'byte_gemm_calls':0, 'byte_products':0}

    def compare(x, w, m, k, n, mp, kp, np, mode, mt, nt, kt, shift=6, x1=None, schedule='forward'):
        nonlocal count, words
        a = reference(x, w, m, k, n, mp, kp, np, mode, shift, x1)
        b = candidate(x, w, m, k, n, mp, kp, np, mode, mt, nt, kt, shift, x1, schedule, stats=stat)
        assert a == b, (m, k, n, mt, nt, kt, a, b)
        label = a.get('refusal', 'accepted'); outcomes[label] = outcomes.get(label, 0) + 1
        count += 1; words += 2 * mp * np if label == 'accepted' else 0
        digest.update(json.dumps(a, sort_keys=True).encode())
        return a

    dims = [(1,1,1,2,2,2), (3,3,5,4,4,8), (5,17,7,8,32,8),
            (3,31,3,4,32,4), (2,129,5,4,256,8)]
    for dims0 in dims:
        m,k,n,mp,kp,np = dims0
        for style, dirty in (('small',False), ('extreme',False), ('small',True)):
            x,w = matrix(rng,*dims0,style,dirty)
            x1 = [rng.randint(-16000,16000) if t<m and j<n else 99999
                  for t in range(mp) for j in range(np)]
            for mode in ('in_out','out_in'):
                wf = w if mode == 'in_out' else [w[i*np+j] for j in range(np) for i in range(kp)]
                for mt,nt,kt in ((1,1,1),(2,3,7),(3,4,31),(64,128,kp)):
                    for schedule in ('forward','reverse'):
                        compare(x,wf,*dims0,mode,mt,nt,kt,x1=x1,schedule=schedule)
    # Full K profile boundaries, cancellation/extrema, output and K ragged tiles.
    for kp in (1023,1024,1025,14336,16384):
        x = [32767 if i%2==0 else -32768 for i in range(kp)]
        w = [1 if i+1<kp else 0 for i in range(kp)]
        for kt in (31,1024,kp):
            compare(x,w,1,kp,1,1,kp,1,'in_out',1,1,kt)
    # Same down-class thresholds and biased remainder at exact rounding edges.
    quant_cases = 0
    for shift in (0,1,6,7,14,31):
        half = 0 if shift == 0 else 1 << (shift-1)
        for q in (-32769,-32768,-128,-1,0,1,127,32767,32768):
            for delta in (-1,0,1):
                a = q * (1 << shift) - half + delta
                qr = ((a+half)//(1<<shift), a-((a+half)//(1<<shift))*(1<<shift)+half)
                y = (a+half)>>shift; actual=(y,a-(y<<shift)+half)
                assert qr == actual and 0 <= actual[1] < 1 << shift
                quant_cases += 1; digest.update(struct.pack('<qqq',a,*qr))

    def negative(name, exact, wrong):
        assert exact != wrong, name
        controls.append({'name':name,'expected':exact,'wrong':wrong})

    args=([32,32],[1,1],1,2,1,1,2,1,'in_out',1,1,1)
    negative('round separately per K tile',candidate(*args),candidate(*args,mutant='round_k_tile'))
    # Early partial range check refuses an ultimately valid cancellation dot.
    args=([32767]*10,[127]*5+[-127]*5,1,10,1,1,10,1,'in_out',1,1,5)
    exact=candidate(*args)
    partial=sum(a*b for a,b in zip(args[0][:5],args[1][:5]))
    wrong={'refusal':'FFN down','first_index':0} if ((partial+32)>>6)>32767 else exact
    negative('range check incomplete K sum',exact,wrong)
    # Wrong fusion can return residual at j0 before a later down fails.
    args=([32767],[1,127],1,1,2,1,1,2,'in_out',1,1,1)
    negative('residual before all down checks',candidate(*args,x1=[32767,0]),
             candidate(*args,x1=[32767,0],mutant='residual_early'))
    args=([32767],[127,127],1,1,2,1,1,2,'in_out',1,1,1)
    negative('first tile completion instead of first support refusal',candidate(*args,schedule='reverse'),
             candidate(*args,schedule='reverse',mutant='first_completed'))
    args=([0]*1024+[129],[-128]*1024+[1],1,1025,1,1,1025,1,'in_out',1,1,1025)
    negative('float32 partial changes biased remainder',candidate(*args),candidate(*args,mutant='float_partial'))
    args=([32767]*1024,[127]*1024,1,1024,1,1,1024,1,'in_out',1,1,1024)
    negative('i32 reconstruction changes range refusal',candidate(*args,shift=14),candidate(*args,shift=14,mutant='i32_reconstruct'))
    args=([1,2,3,99],[1,2,3,7],1,3,1,1,4,1,'in_out',1,1,3)
    negative('drop supplied padded K coordinate',candidate(*args),candidate([1,2,3,0],*args[1:]))
    # Quantization support must not include padded output columns/token rows.
    exact=candidate([0,99999],[1,127],1,1,1,2,1,2,'in_out',1,1,1)
    wrong=dict(exact); wrong['rem']=list(exact['rem']); wrong['rem'][1]=32
    negative('requantize padded outputs adds nonzero remainder',exact,wrong)
    negative('pad low byte zero plus nonzero offset correction',0,128*3)
    args=([0,0],[1,1],1,2,1,1,2,1,'in_out',1,1,1)
    negative('apply full weight correction once per K tile',candidate(*args),candidate(*args,mutant='correction_each'))
    negative('skip final weight correction',candidate(*args),candidate(*args,mutant='skip_correction'))
    negative('ties away from plus infinity',(( -32+32)//64,32-32),(-1,0))
    negative('transpose square weight matrix',reference([1,2],[3,4,5,6],1,2,2,1,2,2,'in_out'),
             reference([1,2],[3,4,5,6],1,2,2,1,2,2,'out_in'))
    negative('i32 partial unsafe at K 131072',131072*16384<=I32[1],True)
    # Verify the ordered pipeline on decisive accepted/down/residual fixtures.
    for x,w,x1,label in (([32767],[127],[32767],'FFN down'),
                         ([4096],[1],[32767],'residual 2'),
                         ([-32768],[0],[-32768],'accepted'),
                         ([32767]*10,[127]*5+[-127]*5,[0],'accepted')):
        a=compare(x,w,1,len(x),1,1,len(x),1,'in_out',1,1,3,x1=x1)
        assert a.get('refusal','accepted') == label
    domain_controls=[]
    for v in (-32769,32768):
        try: candidate([v],[1],1,1,1,1,1,1,'in_out',1,1,1)
        except AssertionError: domain_controls.append(v)
        else: raise AssertionError('bad i16 input accepted')
    ledger=[accounting(512,16384,4096,512,4096,mt,nt,kt)
            for mt,nt,kt in ((512,4096,16384),(64,4096,16384),(64,128,16384),
                             (64,128,1024),(16,128,16384),(64,128,31))]
    for row in ledger:
        assert row['final_z16_RDL_bytes'] == 32 << 20
    result={'status':'pass','run_identity':RUN,'seed':SEED,'matrix_schedule_cases':count,
            'accepted_plane_words':words,'outcomes':outcomes,'rounding_cases':quant_cases,
            'controls':controls,'control_count':len(controls),'domain_controls':domain_controls,
            'synthetic_work_counters':stat,'digest':digest.hexdigest(),
            'elapsed_s':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'device':'CPU only',
            'python':sys.version.split()[0],'estimated_memory_mib':64,'RLIMIT_AS_mib':512,'alarm_s':59,
            'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'scope':'synthetic down/requant/residual only, not full witness/native transcript/proof; tiled GPU buffers counted only',
            'actual_gpu_speedup':None,'actual_end_to_end_saved_s':None,
            'full_stack':dict(countable_tokens=0,passes=0,context_length=None,steady_tokens_per_s=None,
                             total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,
                             serialization_s=None,verification_s=None,proof_latency_s=None,
                             proof_lag_s=None,pipeline_drain_s=None)}
    result['cpu']=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown')
    (ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    (ROOT/'cost-accounting.json').write_text(json.dumps({'scope':'count-only unadmitted Llama3-8B metadata T512 FFN-down; payload per one abstract memory tier; not measured peak/rate',
                                                      'schedules':ledger},indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','matrix_schedule_cases','outcomes','accepted_plane_words','rounding_cases','control_count','elapsed_s','peak_rss_kib','digest')},indent=2))


if __name__ == '__main__':
    main()
