#!/usr/bin/env python3
"""CPU-only actual SC_SZC closure differential on synthetic Fp2 tables."""
import hashlib
import json
import os
import platform
import random
import resource
import signal
import sys
import time
from pathlib import Path

P = 18446744069414584321
Z = (0, 0)
O = (1, 0)
SEED = 2026092714
ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).with_name("result.json")


def add(a, b): return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)
def sub(a, b): return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)
def mul(a, b): return ((a[0] * b[0] + 7 * a[1] * b[1]) % P,
                       (a[0] * b[1] + a[1] * b[0]) % P)
def f(n): return (n % P, 0)
def rnd(g): return (g.randrange(P), g.randrange(P))
def raw(a): return a[0].to_bytes(8, "little") + a[1].to_bytes(8, "little")


# Table order from argument.rs::SC_SZC: three equality factors, causal mask,
# A_S8..A_SG1, MX, SUM, seven LogUp helpers and H_SEXP. 25 tables total.
S8, RSL, ZSEL, E, PR, PL0, PL1, SR0, SR1, SG0, SG1 = range(4, 15)
MX, SUM, H0, HX = 15, 16, 17, 24


def lookup_specs():
    return [(S8, 1, 127), (S8, -1, 127), (RSL, 1, 0),
            (RSL, 4, 0), (PL0, 1, 0), (PL1, 1, 0), (PL1, 64, 0),
            (SR0, 1, 0), (SR1, 1, 0), (SR1, 4, 0),
            (SG0, 1, 0), (SG1, 1, 0), (SG1, 4, 0)]


def poly(v, mu, nu, lam, cfg):
    """Indexed translation of the complete source closure, including LogUp."""
    alpha, beta, g_exp, g_u8, p1 = cfg
    mask, s8, zsel, e, prob, row_sum = v[3], v[S8], v[ZSEL], v[E], v[PR], v[SUM]
    sr = add(v[SR0], mul(v[SR1], p1))
    delta = add(sub(v[MX], mul(mask, add(s8, f(127)))), f(127))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(f(512), mask), e), mul(prob, row_sum)), sr)
    c3 = sub(add(add(v[SG0], mul(v[SG1], p1)), add(sr, O)), row_sum)
    c4 = sub(sub(prob, v[PL0]), mul(v[PL1], p1))
    cx = sub(mul(v[HX], sub(sub(sub(alpha, delta), mul(beta, e)), g_exp)), O)
    specs = lookup_specs()
    helper = Z
    for k in range(7):
        a, b = specs[2*k], specs[2*k+1] if 2*k+1 < len(specs) else None
        d1 = sub(alpha, add(add(f(a[2]), g_u8), mul(v[a[0]], f(a[1]))))
        if b is None:
            rel = sub(mul(v[H0+k], d1), O)
        else:
            d2 = sub(alpha, add(add(f(b[2]), g_u8), mul(v[b[0]], f(b[1]))))
            rel = sub(mul(mul(v[H0+k], d1), d2), add(d1, d2))
        helper = add(helper, mul(mu[5+k], rel))
    zc = add(helper, mul(mu[12], cx))
    for w, c in zip(mu, (c0, c1, c2, c3, c4)):
        zc = add(zc, mul(w, c))
    host_rs = add(row_sum, lam)
    host_s = sub(add(mul(f(64), s8), v[RSL]), f(32))
    return add(add(mul(v[0], zc), mul(nu[0], mul(v[1], host_rs))),
               mul(nu[1], mul(v[2], host_s)))


def poly_ref(v, mu, nu, lam, cfg):
    """Separate semantic expression, with the 13 lookup denominators explicit."""
    alpha, beta, g_exp, g_u8, p1 = cfg
    def den(i, scale=1, offset=0):
        return sub(sub(alpha, g_u8), add(f(offset), mul(f(scale), v[i])))
    ds = [den(S8, 1, 127), den(S8, -1, 127),
          den(RSL), den(RSL, 4), den(PL0), den(PL1), den(PL1, 64),
          den(SR0), den(SR1), den(SR1, 4), den(SG0), den(SG1), den(SG1, 4)]
    terms = [sub(mul(mul(v[H0+i], ds[2*i]), ds[2*i+1]),
                 add(ds[2*i], ds[2*i+1])) for i in range(6)]
    terms.append(sub(mul(v[H0+6], ds[12]), O))
    rel = Z
    for weight, term in zip(mu[5:12], terms): rel = add(rel, mul(weight, term))
    score = sub(mul(v[3], add(v[S8], f(127))), f(127))
    delta = sub(v[MX], score)
    sr = add(v[SR0], mul(p1, v[SR1]))
    zeros = [sub(mul(v[ZSEL], v[ZSEL]), v[ZSEL]), mul(v[ZSEL], delta),
             sub(sub(mul(f(512), mul(v[3], v[E])), mul(v[PR], v[SUM])), sr),
             sub(add(add(v[SG0], mul(p1, v[SG1])), add(sr, O)), v[SUM]),
             sub(v[PR], add(v[PL0], mul(p1, v[PL1])))]
    for i in range(5): rel = add(rel, mul(mu[i], zeros[i]))
    exp_rel = sub(mul(v[HX], sub(alpha, add(add(delta, mul(beta, v[E])), g_exp))), O)
    rel = add(rel, mul(mu[12], exp_rel))
    return add(add(mul(v[0], rel), mul(nu[0], mul(v[1], add(v[SUM], lam)))),
               mul(nu[1], mul(v[2], sub(add(mul(f(64), v[S8]), v[RSL]), f(32)))))


def u(coeffs, degree, j, x):
    out, power = Z, O
    for e in range(degree):
        power = mul(power, x)
        out = add(out, mul(coeffs[2 + j * degree + e], power))
    return out


def mask_round(coeffs, n, degree, j, prev):
    # Separate transcription of zkp-core::CfsMask::round, including a' term.
    half = f((P + 1) // 2)
    base = coeffs[0]
    for i, x in enumerate(prev): base = add(base, u(coeffs, degree, i, x))
    for i in range(j + 1, n): base = add(base, mul(u(coeffs, degree, i, O), half))
    prefix_product = O
    for x in prev: prefix_product = mul(prefix_product, x)
    return [add(mul(f(1 << (n - 1 - j)), add(base, u(coeffs, degree, j, f(x)))),
                mul(coeffs[1], mul(prefix_product, f(x)))) for x in range(degree + 1)]


def mask_eval(coeffs, n, degree, point):
    out, product = coeffs[0], O
    for j, x in enumerate(point):
        out = add(out, u(coeffs, degree, j, x))
        product = mul(product, x)
    return add(out, mul(coeffs[1], product))


def mask_total(coeffs, n, degree):
    out = add(mul(f(1 << n), coeffs[0]), coeffs[1])
    for j in range(n): out = add(out, mul(f(1 << (n - 1)), u(coeffs, degree, j, O)))
    return out


def interpolate(samples, x):
    out = Z
    for i, value in enumerate(samples):
        weight = O
        for j in range(len(samples)):
            if i != j:
                weight = mul(weight, mul(sub(x, f(j)), f(pow(i - j, -1, P))))
        out = add(out, mul(value, weight))
    return out


def challenge(masked, j):
    # Deliberately a test transcript, not Rust's BLAKE3 transcript.
    digest = hashlib.sha256(b"sc-round-test" + bytes([j]) + b"".join(map(raw, masked))).digest()
    return (int.from_bytes(digest[:16], "little") % P,
            int.from_bytes(digest[16:], "little") % P)


def direct_round(original, prev, degree, mu, nu, lam):
    """Original hypercube reference; no folded tables or tile partials."""
    n = (len(original[0])).bit_length() - 1
    j = len(prev)
    answer = []
    for xi in range(degree + 1):
        total = Z
        for suffix in range(1 << (n - j - 1)):
            vals = []
            for table in original:
                val = Z
                for prefix in range(1 << j):
                    weight = O
                    for bit, r in enumerate(prev):
                        weight = mul(weight, r if (prefix >> (j - bit - 1)) & 1 else sub(O, r))
                    pos = (prefix << (n - j)) + suffix
                    val = add(val, mul(weight, add(mul(sub(O, f(xi)), table[pos]),
                                                   mul(f(xi), table[pos + (1 << (n - j - 1))]))))
                vals.append(val)
            total = add(total, poly(vals, mu, nu, lam))
        answer.append(total)
    return answer


def tiled_round(tables, degree, tile, mu, nu, lam):
    half = len(tables[0]) // 2
    partials = []
    for lo in range(0, half, tile):
        part = [Z] * (degree + 1)
        for i in range(lo, min(lo + tile, half)):
            endpoints = [(tab[i], tab[i + half]) for tab in tables]
            for x in range(degree + 1):
                vals = [add(a, mul(f(x), sub(b, a))) for a, b in endpoints]
                part[x] = add(part[x], poly(vals, mu, nu, lam))
        partials.append(part)
    return [sum_fp2(part[x] for part in partials) for x in range(degree + 1)], partials


def sum_fp2(xs):
    out = Z
    for x in xs: out = add(out, x)
    return out


def fold(tables, r):
    half = len(tables[0]) // 2
    return [[add(tab[i], mul(r, sub(tab[i + half], tab[i]))) for i in range(half)]
            for tab in tables]


def direct_terminal(original, point):
    n = len(point)
    ans = []
    for tab in original:
        total = Z
        for i, value in enumerate(tab):
            weight = O
            for bit, r in enumerate(point):
                weight = mul(weight, r if (i >> (n - bit - 1)) & 1 else sub(O, r))
            total = add(total, mul(value, weight))
        ans.append(total)
    return ans


def one_case(n, k, degree, tile):
    # Same fixture at a given (n,k) so different tile sizes compare exactly.
    g = random.Random(SEED + 100 * n + k)
    size = 1 << n
    original = [[rnd(g) for _ in range(size)] for _ in range(k)]
    # Exercise zero factors and base-only / full-extension combinations.
    original[0] = [f(0) if i % 3 == 0 else rnd(g) for i in range(size)]
    original[1] = [f(i % 5) for i in range(size)]
    mu, nu, lam = [rnd(g) for _ in range(7)], [rnd(g), rnd(g)], rnd(g)
    coeffs, c = [rnd(g) for _ in range(n * degree + 2)], rnd(g)
    if c == Z: c = O
    tables = [row[:] for row in original]
    prev, masked_messages, partial_count = [], [], 0
    claim = add(sum_fp2(poly([row[i] for row in original], mu, nu, lam) for i in range(size)),
                mul(c, mask_total(coeffs, n, degree)))
    for j in range(n):
        raw_sum, partials = tiled_round(tables, degree, tile, mu, nu, lam)
        direct = direct_round(original, prev, degree, mu, nu, lam)
        assert raw_sum == direct, (n, k, tile, j, "direct mismatch")
        if j == 0 and half_if_ragged(size, tile):
            assert [sum_fp2(part[x] for part in partials[:-1]) for x in range(degree + 1)] != direct
        masked = [add(s, mul(c, m)) for s, m in zip(raw_sum, mask_round(coeffs, n, degree, j, prev))]
        assert add(masked[0], masked[1]) == claim
        if j == 0:
            assert [add(s, mul(c, m)) for s, m in zip(direct, mask_round(coeffs, n, degree, j, prev))] == masked
        r = challenge(masked, j)
        claim = interpolate(masked, r)
        tables = fold(tables, r)
        prev.append(r)
        masked_messages.append(masked)
        partial_count += len(partials)
    finals = [row[0] for row in tables]
    assert finals == direct_terminal(original, prev)
    assert claim == add(poly(finals, mu, nu, lam), mul(c, mask_eval(coeffs, n, degree, prev)))
    return {
        "n_vars": n, "rows": size, "tables": k, "degree": degree, "tile_pairs": tile,
        "rounds": n, "total_tile_partials": partial_count,
        "digest_sha256": hashlib.sha256(b"".join(raw(v) for msg in masked_messages for v in msg)).hexdigest(),
        "checks": {"direct_rounds": n * (degree + 1), "direct_terminals": k,
                   "masked_claim_chain": n, "ragged_tile": any((1 << (n-j-1)) % tile for j in range(n))}
    }


def half_if_ragged(size, tile):
    return (size // 2) % tile != 0


def controls():
    # Mutations must be distinguishable at the transcript, masked claim or
    # direct-round boundary. No real receipt verifier is invoked.
    g = random.Random(SEED + 1)
    n, degree = 4, 4
    coeffs = [rnd(g) for _ in range(n * degree + 2)]
    m0 = mask_round(coeffs, n, degree, 0, [])
    m1 = mask_round(coeffs, n, degree, 1, [O])
    assert m0 != m1
    clean = [rnd(g) for _ in range(degree + 1)]
    masked = [add(a, b) for a, b in zip(clean, m0)]
    assert challenge(masked, 0) != challenge(clean, 0)
    assert challenge(masked, 0) != challenge(masked[::-1], 0)
    assert challenge(masked, 0) != challenge(masked, 1)
    assert challenge(masked, 0) != challenge([(x[1], x[0]) for x in masked], 0)
    p0, p1 = rnd(g), rnd(g)
    assert mask_round(coeffs, n, degree, 2, [p0, p1]) != mask_round(coeffs, n, degree, 2, [p1, p0])
    tab = [rnd(g) for _ in range(8)]
    r = rnd(g)
    assert [add(tab[i], mul(r, sub(tab[i + 4], tab[i]))) for i in range(4)] != [add(tab[i], mul(r, sub(tab[i + 1], tab[i]))) for i in range(4)]
    return ["mask_round_order", "omit_mask", "reverse_samples", "stale_round_index",
            "swapped_extension_limbs", "swapped_challenge_order", "wrong_fold_pair", "dropped_ragged_tile"]


def main():
    os.environ["OPENBLAS_NUM_THREADS"] = "1"
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    started = time.monotonic()
    profiles = [one_case(n, k, 4, tile) for n, k, tile in
                [(3, 13, 3), (5, 26, 7), (7, 26, 16), (7, 26, 3)]]
    assert profiles[2]["digest_sha256"] == profiles[3]["digest_sha256"], "tile schedule changed masked transcript"
    bad = controls()
    # Source-level traffic ledger: current serial sumcheck reads all active
    # table endpoints for round and fold; resident device does the same.
    for p in profiles:
        N, k, d, n = p["rows"], p["tables"], p["degree"], p["n_vars"]
        p["traffic_model"] = {
            "table_upload_bytes_once": 16 * N * k,
            "round_and_fold_logical_device_reads_bytes": 16 * 4 * k * (N - 1),
            "fold_logical_device_write_bytes": 16 * k * (N - 1),
            "reduced_round_vector_d2h_bytes": 16 * (d + 1) * n,
            "challenge_h2d_bytes": 16 * n,
            "final_table_d2h_bytes": 16 * k,
            "unreduced_tile_partials_d2h_bytes": 16 * (d + 1) * p["total_tile_partials"],
            "minimum_sequential_round_trips": n,
            "device_round_evaluation_launches": n,
            "device_fold_launches": n,
            "extra_device_reduction_launches_if_used": n,
        }
    files = ["hashline/src/private_attention/argument.rs", "hashline/src/zk.rs",
             "zkp-core/src/sumcheck.rs", "zkp-core/src/transcript.rs", "zkp-core/src/field.rs"]
    source_pins = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}
    result = {
        "status": "passed", "run_identity": "20260927T045233Z-e6183046", "seed": SEED,
        "profiles": profiles, "negative_controls": bad, "source_pins_sha256": source_pins,
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "elapsed_s": time.monotonic() - started,
        "peak_rss_kib": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "threads": 1, "cpu": next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), "unknown"),
        "platform": platform.platform(), "python": sys.version.split()[0],
        "limits": {"wall_s": 59, "cpu_s": 55, "address_space_mib": 512, "estimated_memory_mib": 8},
        "scope": "Synthetic SC_SZC-shaped degree-four polynomial and CfsMask schedule. Independent original-cube reference, no native/GPU execution, BLAKE3 transcript parity, full slot, receipt, or full-stack proof.",
        "full_stack": {"complete_model_passes": 0, "countable_tokens": 0, "context_length": None,
                       "steady_tokens_per_s": None, "total_tokens_per_s": None,
                       "startup_fraction": None, "witness_s": None, "prove_s": None,
                       "serialization_s": None, "verification_s": None, "proof_lag_s": None},
    }
    OUT.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "elapsed_s": result["elapsed_s"], "profiles": len(profiles), "controls": len(bad)}))


if __name__ == "__main__": main()
