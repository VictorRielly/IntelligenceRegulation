#!/usr/bin/env python3
"""Exact signed-i64 conversion oracle; synthetic inputs, no proving/builds."""
import hashlib
import json
import os
from pathlib import Path
import random
import re
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
SEED = 2026100421
MODULUS = (1 << 64) - (1 << 32) + 1
WORD = (1 << 64) - 1
EPSILON = (1 << 32) - 1
LOW = -(1 << 63)
HIGH = (1 << 63) - 1


def checked(v):
    # Python harness boundary only: Rust's i64 signature already enforces this.
    if type(v) is not int or not LOW <= v <= HIGH:
        raise ValueError("not signed i64")
    return v


def baseline(v):
    """Pinned native source expression, modeled with exact Python integers."""
    checked(v)
    t = v if v >= 0 else MODULUS - ((-v) % MODULUS)
    return t - MODULUS if t >= MODULUS else t


def candidate_abs(v):
    checked(v)
    return v if v >= 0 else MODULUS - abs(v)


def candidate_word(v):
    checked(v)
    raw = v & WORD
    sign_mask = (v >> 63) & WORD
    return (raw - (sign_mask & EPSILON)) & WORD


def assembly_model(v):
    """Independently decode current ELF loop 0x525830..0x525855.

    ELF is NOT the baseline report's pinned binary. This is an arithmetic
    model of the inspected instructions, not execution of that binary.
    """
    raw = checked(v) & WORD
    rcx = (raw + 0xFFFFFFFF00000000) & WORD
    chosen = 0xFFFFFFFF00000001 if rcx < 0xFFFFFFFF00000001 else 0xFFFFFFFE00000002
    sign = WORD if raw & (1 << 63) else 0
    return (raw + (chosen & sign)) & WORD, chosen


def reference(v):
    # Euclidean quotient/remainder is independent of sign/magnitude mapping.
    checked(v)
    q, r = divmod(v, MODULUS)
    assert q * MODULUS + r == v and 0 <= r < MODULUS
    return r


def literal_bytes(v):
    # An independent integer-to-byte algorithm, separate from struct.pack.
    r = reference(v)
    return bytes((r // (256 ** i)) % 256 for i in range(8))


def vector_words(values, lanes):
    # SIMD arithmetic model only; scalar Python, no native vector instruction.
    result = []
    for start in range(0, len(values), lanes):
        chunk = values[start:start + lanes]
        raw = [checked(v) & WORD for v in chunk]
        masks = [WORD if v < 0 else 0 for v in chunk]
        result.extend((r - (m & EPSILON)) & WORD for r, m in zip(raw, masks))
    return result


def require_counterexample(label, wrong, values, controls):
    hits = [v for v in values if wrong(v) != reference(v)]
    assert hits, label
    v = hits[0]
    controls.append(dict(label=label, counterexample=v, expected=reference(v), wrong=wrong(v)))


def main():
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024 ** 2, 512 * 1024 ** 2))
    os.nice(10)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    t0 = time.perf_counter()
    src = (HERE / 'snapshots/ops__zkp-mvp__candidate__zkp-core__src__field.rs').read_text()
    assert 'pub const P: u64 = 0xFFFF_FFFF_0000_0001;' in src
    exact = 'if v >= 0 { Fp::new(v as u64) } else { Fp::new(P - ((-(v as i128)) as u64 % P)) }'
    assert exact in src, 'baseline implementation changed; revise the source model'
    assert MODULUS > (1 << 63), 'signed magnitude bound is essential'

    rng = random.Random(SEED)
    boundaries = {LOW, HIGH, LOW + 1, HIGH - 1, -1, 0, 1}
    for n in range(1, 64):
        for sign in (-1, 1):
            for delta in (-2, -1, 0, 1, 2):
                v = sign * (1 << n) + delta
                if LOW <= v <= HIGH:
                    boundaries.add(v)
    values = sorted(boundaries) + list(range(-32768, 32768))
    values += [rng.getrandbits(64) - (1 << 63) for _ in range(65536)]
    values += [LOW + rng.randrange(1 << 32) for _ in range(4096)]
    values += [HIGH - rng.randrange(1 << 32) for _ in range(4096)]
    digest = hashlib.sha256()
    choose_counts = {hex(MODULUS): 0, hex((2 * MODULUS) & WORD): 0}
    negative_second_choice = 0
    for v in values:
        expected = reference(v)
        a, b, c = baseline(v), candidate_abs(v), candidate_word(v)
        d, chosen = assembly_model(v)
        assert a == b == c == d == expected
        assert 0 <= c < MODULUS
        actual = struct.pack('<Q', c)
        assert actual == literal_bytes(v)
        # Fp2::from_i64 is base embedding: imaginary component must be zero.
        assert struct.pack('<QQ', c, 0) == literal_bytes(v) + bytes(8)
        digest.update(struct.pack('<q', v) + actual)
        choose_counts[hex(chosen)] += 1
        negative_second_choice += int(v < 0 and chosen != MODULUS)
    assert all(choose_counts.values()) and negative_second_choice == 0

    vector_cases = 0
    vector_words_checked = 0
    for lanes in (1, 2, 4, 8, 16):
        for length in (0, 1, 2, 3, 7, 8, 9, 15, 16, 17, 257, 1025):
            fixture = [values[rng.randrange(len(values))] for _ in range(length)]
            if length:
                fixture[0] = LOW
            if length > 1:
                fixture[-1] = HIGH
            assert vector_words(fixture, lanes) == [reference(v) for v in fixture]
            vector_cases += 1
            vector_words_checked += length

    # Representative A row copy with public tails, including dirty supplied
    # internal padded coordinates. No real layout, mask or transcript used.
    row_cases, row_words = 0, 0
    for width in (1, 2, 7, 8, 17, 256, 512):
        for length in sorted({0, 1, width // 2, width}):
            plane = [values[rng.randrange(len(values))] for _ in range(length)]
            if length:
                plane[-1] = -7  # cannot infer input padding is zero
            reference_row = b''.join(literal_bytes(v) for v in plane) + bytes(8 * (width - length))
            actual = b''.join(struct.pack('<Q', candidate_word(v)) for v in plane) + bytes(8 * (width - length))
            assert actual == reference_row
            row_cases += 1
            row_words += width

    controls = []
    edge = sorted(boundaries)
    require_counterexample('raw signed-to-u64 reinterpretation', lambda v: v & WORD, edge, controls)
    require_counterexample('normalize raw signed-to-u64 with Fp::new', lambda v: (v & WORD) % MODULUS, edge, controls)
    require_counterexample('subtract 2^32 instead of 2^32-1', lambda v: ((v & WORD) - ((1 << 32) if v < 0 else 0)) & WORD, edge, controls)
    require_counterexample('subtract epsilon from positive values', lambda v: ((v & WORD) - EPSILON) & WORD, edge, controls)
    require_counterexample('logical shift yields 0/1, not all-ones sign mask', lambda v: ((v & WORD) - (((v & WORD) >> 63) & EPSILON)) & WORD, edge, controls)
    require_counterexample('truncate to signed i32 before conversion', lambda v: reference(((v + (1 << 31)) & ((1 << 32) - 1)) - (1 << 31)), edge, controls)
    require_counterexample('wrapping i64 magnitude cast after P subtraction', lambda v: v if v >= 0 else MODULUS - (((-v + (1 << 63)) & WORD) - (1 << 63)), edge, controls)
    for invalid in [LOW - 1, HIGH + 1, MODULUS, -MODULUS, True, 1.0, '1', None]:
        for fn in [baseline, candidate_abs, candidate_word, reference]:
            try:
                fn(invalid)
            except ValueError:
                pass
            else:
                raise AssertionError('harness accepted non-i64')
        controls.append(dict(label='harness i64 boundary', value=repr(invalid)))
    # Full-u64/Fp::new and challenge-u128 reduction are different domains.
    # This counterexample forbids extending the no-modulo shortcut to them.
    assert MODULUS != MODULUS % MODULUS
    controls.append(dict(label='u64 domain extension fails at p', counterexample=MODULUS, expected=0, wrong=MODULUS))
    assert struct.pack('>Q', candidate_word(-1)) != literal_bytes(-1)
    controls.append(dict(label='wrong byte endianness', counterexample=-1))
    alternating = [-1, 1, LOW, HIGH, 0, -7, 7]
    stale_mask = [((v & WORD) - EPSILON) & WORD for v in alternating]
    assert stale_mask != [reference(v) for v in alternating]
    controls.append(dict(label='one negative lane sign reused across vector'))
    assert literal_bytes(-7) != bytes(8)
    controls.append(dict(label='discarding supplied internal padding'))
    controls.append(dict(label='nonzero imaginary Fp2 embedding'))
    assert struct.pack('<QQ', candidate_word(-1), 1) != literal_bytes(-1) + bytes(8)

    # Verify the address-bounded decoded loop does not contain division.
    disasm = (HERE / 'prove-core.disassembly.txt').read_text()
    loop = []
    for line in disasm.splitlines():
        m = re.match(r'\s*([0-9a-f]+):', line)
        if m and 0x525830 <= int(m[1], 16) <= 0x525855:
            loop.append(line)
    assert len(loop) == 9
    assert not any(re.search(r'\b(?:i?div|call)\b', l) for l in loop)
    (HERE / 'conversion-loop.txt').write_text('\n'.join(loop) + '\n')
    result = dict(run_identity='20261004T030146Z-711aedad', seed=SEED, status='pass',
        signed_scalar_values=len(values), full_i16_values=65536,
        boundary_values=len(boundaries), full_i64_random_values=65536,
        near_extreme_values=8192, scalar_mappings_per_value=4,
        checked_byte_embeddings_per_value=2, digest=digest.hexdigest(),
        vector_model_cases=vector_cases, vector_model_words=vector_words_checked,
        row_copy_cases=row_cases, row_copy_words=row_words,
        controls=controls, control_count=len(controls),
        assembly_chosen_constant_counts=choose_counts,
        assembly_negative_second_constant_count=negative_second_choice,
        observed_conversion_loop_instruction_count=len(loop),
        observed_conversion_loop_integer_division_instructions=0,
        source_level_removed_magnitude_modulo=True,
        observed_removed_division=False, candidate_native_instruction_count=None,
        actual_time_saved_s=None, actual_native_traffic_saved_bytes=None,
        added_capacity_bytes=0, estimated_memory_mib=64,
        elapsed_s=time.perf_counter()-t0, peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        threads=1, affinity=sorted(os.sched_getaffinity(0)), device='CPU only',
        cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
        python=os.sys.version.split()[0], RLIMIT_AS_mib=512, alarm_s=59,
        script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        scope='Exact synthetic signed-i64 value/byte oracle and decoded current-ELF arithmetic; no native candidate, proof, GPU, transcript, RNG, or trained model',
        full_stack=dict(countable_tokens=0, passes=0, context_length=None, steady_tokens_per_s=None,
            total_tokens_per_s=None, startup_fraction=None, witness_s=None, proof_s=None,
            serialization_s=None, verification_s=None, proof_latency_s=None,
            proof_lag_s=None, pipeline_drain_s=None))
    (HERE / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k,v in result.items() if k not in ['controls','full_stack']}))


if __name__ == '__main__':
    main()
