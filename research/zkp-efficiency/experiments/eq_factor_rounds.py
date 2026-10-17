#!/usr/bin/env python3
"""Bounded exact-arithmetic experiment; NOT a cryptographic proof implementation.

Compare an ordinary MSB-first sumcheck evaluator (with R1d's recover-one
optimization) to separated equality factors and split equality tables. Field:
Goldilocks quadratic extension u^2=7, exactly as zkp-core/src/field.rs.
No project source imports, downloads, secrets, GPU calls, or dependencies.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import platform
import random
import time

P = 2**64 - 2**32 + 1
ZERO = (0, 0)
ONE = (1, 0)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def mul(a, b):
    return ((a[0]*b[0] + 7*a[1]*b[1]) % P,
            (a[0]*b[1] + a[1]*b[0]) % P)


def scale(a, b):
    return (a[0]*b % P, a[1]*b % P)


def inv(a):
    if a == ZERO:
        raise ValueError("zero inverse")
    d = pow((a[0]*a[0] - 7*a[1]*a[1]) % P, -1, P)
    return (a[0]*d % P, -a[1]*d % P)


def enc(a):
    return a[0].to_bytes(8, "little") + a[1].to_bytes(8, "little")


def eq_one(w, t):
    return add(mul(sub(ONE, w), sub(ONE, t)), mul(w, t))


def eq_table(point):
    out = [ONE]
    for w in point:
        out = [x for v in out for x in (mul(v, sub(ONE, w)), mul(v, w))]
    return out


def product(v):
    out = ONE
    for x in v:
        out = mul(out, x)
    return out


def fold(table, r):
    half = len(table)//2
    return [add(a, mul(r, sub(b, a))) for a, b in zip(table[:half], table[half:])]


def interpolate(values, r):
    # Small degree only. Independent Lagrange expression, no unknown inverse.
    out = ZERO
    for i, value in enumerate(values):
        numerator = ONE
        denominator = 1
        for j in range(len(values)):
            if i != j:
                numerator = mul(numerator, sub(r, (j, 0)))
                denominator *= i-j
        out = add(out, mul(value, scale(numerator, pow(denominator % P, -1, P))))
    return out


def validate(point, tables):
    if not point or not tables or not all(len(t) == 1 << len(point) for t in tables):
        raise ValueError("nonempty full-cube tables and equality point required")


class Reference:
    """P(x)=eq(w,x)*product(tables(x)), degree d+1; recover s(1)."""
    def __init__(self, point, tables, recover=True):
        validate(point, tables)
        self.tables = [eq_table(point)] + [list(t) for t in tables]
        self.degree = len(tables)+1
        self.claim = None
        self.recover = recover
        self.pending = None
        self.inner_products = 0
        self.eq_peak_elements = len(self.tables[0])

    def round(self):
        half = len(self.tables[0])//2
        sums = [ZERO]*(self.degree+1)
        for i in range(half):
            a = [v[i] for v in self.tables]
            delta = [sub(v[i+half], v[i]) for v in self.tables]
            for t in range(self.degree+1):
                if t != 1 or self.claim is None or not self.recover:
                    sums[t] = add(sums[t], product(a))
                    self.inner_products += 1
                a = [add(x, dx) for x, dx in zip(a, delta)]
        if self.claim is not None and self.recover:
            sums[1] = sub(self.claim, sums[0])
        self.pending = sums
        return sums

    def bind(self, r):
        self.claim = interpolate(self.pending, r)
        self.tables = [fold(t, r) for t in self.tables]
        self.pending = None

    def finals(self):
        return [t[0] for t in self.tables]


class Factored:
    """Reconstruct the same s(t), not a changed-degree sumcheck protocol.

    h(t) = sum_y eq(w_suffix,y)*product(table(t,y)) has degree d.
    s(t) = prefix*eq(w_current,t)*h(t). Compute d+1 inner sums, or d
    when an ACTUAL preceding unmasked claim permits recovering h(1).
    Zero divisors use the full d+1 path; no challenge resampling.
    Two small eq tables replace the suffix's single exponential table.
    """
    def __init__(self, point, tables):
        validate(point, tables)
        self.point = list(point)
        self.tables = [list(t) for t in tables]
        self.degree = len(tables)+1
        self.prefix = ONE
        self.j = 0
        self.claim = None
        self.pending = None
        self.inner_products = 0
        self.eq_peak_elements = 0
        self.zero_divisor_fallbacks = 0

    def round(self):
        d = self.degree-1
        half = len(self.tables[0])//2
        suffix = self.point[self.j+1:]
        split = len(suffix)//2
        left, right = eq_table(suffix[:split]), eq_table(suffix[split:])
        self.eq_peak_elements = max(self.eq_peak_elements, len(left)+len(right))
        e = [mul(self.prefix, eq_one(self.point[self.j], (t, 0)))
             for t in range(self.degree+1)]
        recover_h1 = self.claim is not None and e[1] != ZERO
        if self.claim is not None and e[1] == ZERO:
            self.zero_divisor_fallbacks += 1
        points = [t for t in range(d+1) if t != 1 or not recover_h1]
        h = [ZERO]*(d+1)
        for li, lv in enumerate(left):
            accum = [ZERO]*(d+1)
            for ri, rv in enumerate(right):
                i = li*len(right)+ri
                assert i < half
                a = [v[i] for v in self.tables]
                delta = [sub(v[i+half], v[i]) for v in self.tables]
                for t in range(d+1):
                    if t in points:
                        accum[t] = add(accum[t], mul(rv, product(a)))
                        self.inner_products += 1
                    a = [add(x, dx) for x, dx in zip(a, delta)]
            for t in points:
                h[t] = add(h[t], mul(lv, accum[t]))
        if recover_h1:
            h[1] = mul(sub(self.claim, mul(e[0], h[0])), inv(e[1]))
        # A degree-d polynomial's next sample follows from zero (d+1)st
        # forward difference. All coefficients are fixed public integers.
        last = ZERO
        for i in range(d+1):
            last = add(last, scale(h[i], (-1)**(d-i)*math.comb(d+1, i)))
        h.append(last)
        self.pending = [mul(x, y) for x, y in zip(e, h)]
        return self.pending

    def bind(self, r):
        self.claim = interpolate(self.pending, r)
        self.prefix = mul(self.prefix, eq_one(self.point[self.j], r))
        self.tables = [fold(t, r) for t in self.tables]
        self.j += 1
        self.pending = None

    def finals(self):
        return [self.prefix] + [t[0] for t in self.tables]


def transcript_run(cls, point, tables, forced_first=None):
    evaluator = cls(point, tables)
    transcript = b"zkp-efficiency/eq-factor-toy-transcript/v1"
    messages, challenges = [], []
    actual_claim = ZERO
    for row in zip(eq_table(point), *tables):
        actual_claim = add(actual_claim, product(row))
    for j in range(len(point)):
        values = evaluator.round()
        assert add(values[0], values[1]) == actual_claim
        messages.append(values)
        # Deliberately a TOY deterministic wire wrapper, not production CFS.
        # Its purpose is to catch downstream challenge drift, not establish ZK.
        alpha = (11+j, 17+j)
        masked = [add(v, mul(alpha, (2*t-1, 0))) for t, v in enumerate(values)]
        transcript += b"round" + b"".join(map(enc, masked))
        digest = hashlib.sha256(transcript).digest()
        r = (int.from_bytes(digest[:16], "little") % P,
             int.from_bytes(digest[16:], "little") % P)
        if j == 0 and forced_first is not None:
            r = forced_first
        transcript += enc(r)
        challenges.append(r)
        actual_claim = interpolate(values, r)
        evaluator.bind(r)
    final = evaluator.finals()
    assert product(final) == actual_claim
    return {"messages": messages, "challenges": challenges, "finals": final,
            "digest": hashlib.sha256(transcript).hexdigest(),
            "inner_products": evaluator.inner_products,
            "eq_peak_elements": evaluator.eq_peak_elements,
            "zero_divisor_fallbacks": getattr(evaluator, "zero_divisor_fallbacks", 0)}


def randfp(rng, full=True):
    return (rng.randrange(P), rng.randrange(P) if full else 0)


def case(rng, n, d, mode):
    point = [randfp(rng) for _ in range(n)]
    tables = [[randfp(rng, mode == "extension") for _ in range(1 << n)] for _ in range(d)]
    if mode == "zero":
        tables[0] = [ZERO]*(1 << n)
    elif mode == "signed16":
        tables = [[(rng.randrange(-32768, 32768) % P, 0) for _ in range(1 << n)] for _ in range(d)]
    return point, tables


def identity(a, b):
    for key in ("messages", "challenges", "finals", "digest"):
        assert a[key] == b[key], key


def independent_mle(table, prefix):
    # Direct weighted sum over original cube, independent of fold().
    out = ZERO
    for index, value in enumerate(table):
        weight = ONE
        for j, r in enumerate(prefix):
            bit = (index >> (len(prefix)-1-j)) & 1
            weight = mul(weight, r if bit else sub(ONE, r))
        out = add(out, mul(value, weight))
    return out


def main():
    started = time.perf_counter()
    rng = random.Random(20260922)
    checked, independent_points, degenerate = 0, 0, 0
    for n in (1, 2, 3, 5, 7):
        for d in (1, 2, 3):
            for mode in ("extension", "base", "signed16", "zero"):
                point, tables = case(rng, n, d, mode)
                a = transcript_run(Reference, point, tables)
                b = transcript_run(Factored, point, tables)
                identity(a, b)
                checked += 1
                if n <= 3:
                    for j, message in enumerate(a["messages"]):
                        for t, expected in enumerate(message):
                            direct = ZERO
                            for suffix in range(1 << (n-j-1)):
                                coordinates = a["challenges"][:j] + [(t, 0)] + [
                                    ((suffix >> k) & 1, 0) for k in reversed(range(n-j-1))]
                                ev = [product([eq_one(w, r) for w, r in zip(point, coordinates)])]
                                ev += [independent_mle(tb, coordinates) for tb in tables]
                                direct = add(direct, product(ev))
                            assert direct == expected
                            independent_points += 1
    # e(1)=0 and a zero accumulated prefix are valid algebraic states.
    for mode in ("e1_zero", "prefix_zero"):
        point, tables = case(rng, 5, 2, "extension")
        forced = None
        if mode == "e1_zero":
            point[1] = ZERO
        else:
            point[0] = (2, 0)
            forced = (pow(3, -1, P), 0)
        a = transcript_run(Reference, point, tables, forced)
        b = transcript_run(Factored, point, tables, forced)
        identity(a, b)
        assert b["zero_divisor_fallbacks"] > 0
        degenerate += b["zero_divisor_fallbacks"]
        checked += 1
    # Negative control: an additive term outside E is not factorizable by E.
    # A generic host polynomial cannot be rewritten wholesale as E*h.
    wrong_factoring_detected = add(mul((2, 0), (3, 0)), (5, 0)) != mul((2, 0), add((3, 0), (5, 0)))
    assert wrong_factoring_detected
    malformed_refused = 0
    for cls in (Reference, Factored):
        try:
            cls([ONE], [[ONE]])
        except ValueError:
            malformed_refused += 1
    assert malformed_refused == 2
    timings = []
    for d in (2, 3):
        point, tables = case(rng, 10, d, "extension")
        for cls in (Reference, Factored, Factored, Reference):
            t0 = time.perf_counter()
            result = transcript_run(cls, point, tables)
            timings.append({"inner_degree": d, "n_vars": 10,
                            "evaluator": cls.__name__, "seconds": time.perf_counter()-t0,
                            **{k: result[k] for k in ("digest", "inner_products", "eq_peak_elements")}})
    output = {
        "schema": "zkp-efficiency/experiment/v1", "date": "2026-09-22",
        "status": "passed", "python": platform.python_version(),
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "field": "Fp2 over p=2^64-2^32+1, u^2=7", "seed": 20260922,
        "differential_cases": checked, "independent_direct_round_points": independent_points,
        "zero_divisor_fallback_rounds": degenerate, "malformed_refusals": malformed_refused,
        "nonfactorable_additive_control_detected": wrong_factoring_detected,
        "timing_order": "reference/candidate/candidate/reference; shared CPU, Python microbenchmark",
        "timings": timings, "elapsed_seconds": time.perf_counter()-started,
        "scope": "Synthetic exact unmasked evaluator identities and toy transcript only. No native receipt, GPU, CFS privacy or model-speed claim.",
    }
    if output["elapsed_seconds"] > 60:
        raise RuntimeError("bounded experiment exceeded 60 seconds")
    path = Path(__file__).with_name("eq_factor_rounds.result.json")
    path.write_text(json.dumps(output, indent=2)+"\n")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
