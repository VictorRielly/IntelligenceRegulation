#!/usr/bin/env python3
"""Synthetic exact Fp2 U8 helper plane writer; no native proof or benchmark."""
import hashlib
import json
import os
import platform
import random
import resource
import signal
import time
from pathlib import Path

P = (1 << 64) - (1 << 32) + 1
SEED = 2026092711
REFUSAL = "zero LogUp denominator; discard attempt"
HERE = Path(__file__).resolve().parent


def limits():
    try:
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    except (AttributeError, OSError):
        pass
    resource.setrlimit(resource.RLIMIT_CPU, (55, 56))
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    signal.alarm(59)


def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def mul(x, y):
    return ((x[0] * y[0] + 7 * x[1] * y[1]) % P,
            (x[0] * y[1] + x[1] * y[0]) % P)


def inverse_reference(x):
    # Independent of the candidate's conjugate/norm formula.
    assert x != (0, 0)
    z = (1, 0)
    for bit in bin(P * P - 2)[2:]:
        z = mul(z, z)
        if bit == "1":
            z = mul(z, x)
    assert mul(z, x) == (1, 0)
    return z


def inverse_candidate(x):
    a, b = x
    d = (a * a - 7 * b * b) % P
    if d == 0:
        raise ValueError(REFUSAL)
    r = pow(d, -1, P)
    return (a * r % P, -b * r % P)


def denom(v, alpha, g):
    return ((alpha[0] - g[0] - v) % P, (alpha[1] - g[1]) % P)


def table(alpha, g, n=256):
    return [None if denom(v, alpha, g) == (0, 0)
            else inverse_candidate(denom(v, alpha, g)) for v in range(n)]


def candidate_one(v, alpha, g, tbl):
    if 0 <= v < len(tbl):
        x = tbl[v]
        if x is None:
            raise ValueError(REFUSAL)
        return x
    return inverse_candidate(denom(v, alpha, g))


def reference(col_a, col_b, alpha, g):
    if col_b is not None and len(col_a) != len(col_b):
        raise ValueError("private block: paired lookup columns of different lengths")
    ans = []
    for i, v in enumerate(col_a):
        x = denom(v, alpha, g)
        if x == (0, 0):
            raise ValueError(REFUSAL)
        y = inverse_reference(x)
        if col_b is not None:
            x = denom(col_b[i], alpha, g)
            if x == (0, 0):
                raise ValueError(REFUSAL)
            y = add(y, inverse_reference(x))
        ans.append(y)
    return ans


def baseline(h, off, col_a, col_b, alpha, g, tbl):
    if col_b is not None and len(col_a) != len(col_b):
        raise ValueError("private block: paired lookup columns of different lengths")
    tmp = []
    for i, v in enumerate(col_a):
        x = candidate_one(v, alpha, g, tbl)
        if col_b is not None:
            x = add(x, candidate_one(col_b[i], alpha, g, tbl))
        tmp.append(x)
    for i, x in enumerate(tmp):
        h[off[0] + i], h[off[1] + i] = x


def direct(h, off, col_a, col_b, alpha, g, tbl):
    if col_b is not None and len(col_a) != len(col_b):
        raise ValueError("private block: paired lookup columns of different lengths")
    for i, v in enumerate(col_a):
        x = candidate_one(v, alpha, g, tbl)
        if col_b is not None:
            x = add(x, candidate_one(col_b[i], alpha, g, tbl))
        h[off[0] + i], h[off[1] + i] = x


def direct_atomic(h, off, col_a, col_b, alpha, g, tbl):
    # Transactional variant: preserves the old writer's no-partial-H guarantee.
    if col_b is not None and len(col_a) != len(col_b):
        raise ValueError("private block: paired lookup columns of different lengths")
    for i, v in enumerate(col_a):
        candidate_one(v, alpha, g, tbl)
        if col_b is not None:
            candidate_one(col_b[i], alpha, g, tbl)
    direct(h, off, col_a, col_b, alpha, g, tbl)


def direct_guarded(h, off, col_a, col_b, alpha, g, tbl):
    # Every looked value is an embedded base-field integer. When the
    # denominator's extension coefficient is nonzero, no value can refuse.
    # The equality branch handles all honest and dishonest signed i64 values.
    if col_b is not None and len(col_a) != len(col_b):
        raise ValueError("private block: paired lookup columns of different lengths")
    if alpha[1] == g[1]:
        for i, v in enumerate(col_a):
            candidate_one(v, alpha, g, tbl)
            if col_b is not None:
                candidate_one(col_b[i], alpha, g, tbl)
    direct(h, off, col_a, col_b, alpha, g, tbl)


def outcome(fn, *args):
    try:
        return fn(*args), None
    except ValueError as e:
        return None, str(e)


def main():
    limits()
    begin = time.monotonic()
    rng = random.Random(SEED)
    cases = 0
    success_cases = 0
    refused_cases = 0
    words = 0
    checks = 0
    guarded_preflight_cases = 0
    guarded_fast_cases = 0
    digest = hashlib.sha256()
    for n in [0, 1, 2, 7, 31, 257, 1024]:
        for pair in [False, True]:
            for mode in ["valid", "invalid-signed", "used-zero", "unused-zero", "mismatch"]:
                if mode == "mismatch" and not pair:
                    continue
                alpha = (rng.randrange(P), rng.randrange(P))
                g = (rng.randrange(P), rng.randrange(P))
                if mode in ("used-zero", "unused-zero"):
                    alpha = add(g, (19, 0))
                tbl = table(alpha, g)
                a = [rng.randrange(256) for _ in range(n)]
                b = [rng.randrange(256) for _ in range(n)] if pair else None
                if mode == "invalid-signed" and n:
                    a[0] = -(1 << 63)
                    if pair:
                        b[-1] = (1 << 63) - 1
                if mode == "used-zero" and n:
                    a[-1] = 19
                if mode == "unused-zero":
                    a = [v if v != 19 else 20 for v in a]
                    if pair:
                        b = [v if v != 19 else 20 for v in b]
                if mode == "mismatch":
                    b.append(1)
                off = (13, 13 + n + 19)
                size = off[1] + n + 17
                h0 = [777] * size
                h1 = h0.copy()
                h2 = h0.copy()
                h3 = h0.copy()
                _, e0 = outcome(baseline, h0, off, a, b, alpha, g, tbl)
                _, e1 = outcome(direct, h1, off, a, b, alpha, g, tbl)
                _, e2 = outcome(direct_atomic, h2, off, a, b, alpha, g, tbl)
                _, e3 = outcome(direct_guarded, h3, off, a, b, alpha, g, tbl)
                _, er = outcome(reference, a, b, alpha, g)
                assert e0 == e1 == e2 == e3 == er, (n, pair, mode, e0, e1, e2, e3, er)
                guarded_preflight_cases += alpha[1] == g[1]
                guarded_fast_cases += alpha[1] != g[1]
                if er is None:
                    success_cases += 1
                    want = reference(a, b, alpha, g)
                    assert h0 == h1 == h2 == h3
                    assert [(h1[off[0]+i], h1[off[1]+i]) for i in range(n)] == want
                    assert all(h1[j] == 777 for j in list(range(off[0])) + list(range(off[0]+n, off[1])) + list(range(off[1]+n, size)))
                    for x in want:
                        digest.update(x[0].to_bytes(8, "little") + x[1].to_bytes(8, "little"))
                    words += n
                else:
                    refused_cases += 1
                    # Candidate can leave a private partial H on refusal; never commit it.
                    assert h0 == h2 == h3 == [777] * size
                cases += 1
    # Negative controls must diverge from the reference.
    alpha, g = (515, 41), (7, 9)
    tbl = table(alpha, g)
    a, b, off = [4, 8, 11], [9, 3, 1], (5, 19)
    h = [777] * 40
    direct(h, off, a, b, alpha, g, tbl)
    want = reference(a, b, alpha, g)
    assert h[off[1]] != want[0][0]; checks += 1  # swapped limb
    assert h[off[0]] != inverse_reference(denom(a[0], alpha, g))[0]; checks += 1  # dropped second column
    bad_tbl = tbl.copy(); bad_tbl[4] = (0, 0)
    hb = [777] * 40
    direct(hb, off, a, b, alpha, g, bad_tbl)
    assert hb != h; checks += 1
    bad_zero = table(add(g, (19, 0)), g)
    _, e = outcome(direct, [777]*40, off, [19], None, add(g, (19, 0)), g, bad_zero)
    assert e == REFUSAL; checks += 1
    _, e = outcome(direct, [777]*40, off, [4], [3, 2], alpha, g, tbl)
    assert e == "private block: paired lookup columns of different lengths"; checks += 1
    alpha_zero = add(g, (19, 0))
    zero_tbl = table(alpha_zero, g)
    part = [777] * 40
    _, e = outcome(direct, part, off, [1, 19], None, alpha_zero, g, zero_tbl)
    assert e == REFUSAL and part[off[0]] != 777
    atomic = [777] * 40
    _, e = outcome(direct_atomic, atomic, off, [1, 19], None, alpha_zero, g, zero_tbl)
    assert e == REFUSAL and atomic == [777] * 40
    checks += 1
    guarded = [777] * 40
    _, e = outcome(direct_guarded, guarded, off, [1, 19], None, alpha_zero, g, zero_tbl)
    assert e == REFUSAL and guarded == [777] * 40
    checks += 1
    # Deliberate wrong guard: equality of real limbs cannot certify safety.
    assert alpha_zero[1] == g[1] and alpha_zero[0] != g[0]
    checks += 1
    result = {
        "status": "passed", "seed": SEED, "cases": cases,
        "successful_cases": success_cases, "refused_cases": refused_cases,
        "successful_output_words": words,
        "negative_controls": checks, "output_digest_sha256": digest.hexdigest(),
        "guarded_preflight_cases": guarded_preflight_cases,
        "guarded_fast_cases": guarded_fast_cases,
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "native_source_sha256": hashlib.sha256(Path("/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs").read_bytes()).hexdigest(),
        "elapsed_s": time.monotonic()-begin, "peak_rss_kib": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "cpu": next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), platform.processor()),
        "platform": platform.platform(),
        "experiment_limits": {"threads": 1, "cpu_s": 55, "wall_s": 59, "address_space_mib": 512, "estimated_memory_mib": 64},
        "clocks": {"witness_s": None, "prove_s": None, "serialization_s": None, "verify_s": None},
        "scope": "Synthetic helper arithmetic, planes, refusal strings, and traffic accounting; no native compilation, receipt, GPU or end-to-end speed."}
    (HERE / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
