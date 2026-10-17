#!/usr/bin/env python3
"""Round-3 checker (reviewer, 2026-10-17): every clause whose bound depends on
the GEOMETRY, at the registered trained geometries, adversarial legal values.
Written from argument.rs / layout.rs of ops/zkp-mvp/trained-1b-review-r3/.
Geometries: TinyLlama T32/T64/T128 (d 2048, f 5632 -> 8192, 32 q / 4 kv,
head_dim 64) and Llama-3-8B T32 (d 4096, f 14336 -> 16384, 32 q / 8 kv,
head_dim 128). Shifts at the worst end of their windows, f_e at the worst
end of 9..=16, norm class corners. Writes reviewer_nowrap_r3.json."""
import json
import math
import os
import sys

P = 2**64 - 2**32 + 1
F_P = 9
F_RO = 7
SH_ROPE = 7


def absmax(terms):
    return max(abs(sum(t[0] for t in terms)), abs(sum(t[1] for t in terms)))


def prod(*ivs):
    lo, hi = ivs[0]
    for a, b in ivs[1:]:
        c = [lo * a, lo * b, hi * a, hi * b]
        lo, hi = min(c), max(c)
    return (lo, hi)


def sc(iv, k):
    a, b = iv[0] * k, iv[1] * k
    return (min(a, b), max(a, b))


I8S, I8G, I16, W8 = (-127, 127), (-128, 127), (-32768, 32767), (-128, 127)
L24, L32 = 2**24 - 1, 2**32 - 1


def geom_bounds(name, T, d, f, q, kv, hd):
    d_pad, f_pad = 1 << (d - 1).bit_length(), 1 << (f - 1).bit_length()
    out = {}
    # norm (independent of the shifts): R4 at this width, C0 at the class corner
    S = (0, d * 32768 * 32768)
    out["norm R4"] = absmax([(0, L24 * L24), (0, L24), (-(2**40), -1), sc(S, -1)])
    out["norm C0"] = absmax([sc(prod(W8, I16), 2 * 2**20), (0, 2**16 * L24), sc(prod((0, L24), I8S), -(2**17)), (-L32, 0)])
    out["norm C1"] = absmax([(0, L32), (0, L32), (1, 1), (-(2**17) * L24, 0)])
    worst_one = lambda acc, outc: max(absmax([sc(outc, 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), sc(acc, -1)]) for sh in range(1, 9))
    worst_two = lambda acc, outc: max(absmax([sc(outc, 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), sc(acc, -1)]) for sh in range(9, 17))
    out["Q/K/V host (sum over d_pad)"] = worst_one(sc(prod(I8S, W8), d_pad), I8S)
    out["RoPE clause"] = absmax([sc(prod((-(2**F_RO), 2**F_RO), I8S), 2), sc(I8S, -(2**SH_ROPE)), (-(2**SH_ROPE - 1), 0), (2 ** (SH_ROPE - 1), 2 ** (SH_ROPE - 1))])
    out["score host (sum over head_dim)"] = worst_one(sc(prod(I8S, I8S), hd), I8S)
    # softmax at f_e 16 (class top)
    fe = 16
    wrho_s = (T - 1).bit_length() + fe
    out["softmax c2"] = absmax([(0, 2 ** (fe + F_P)), sc(prod((0, 2 ** (F_P + 1) - 1), (1, T * 2**fe)), -1), (-(2**wrho_s - 1), 0)])
    out["softmax row sum"] = T * 2**fe
    out["PV host (sum over T)"] = worst_two(sc(prod((0, 2 ** (F_P + 1) - 1), I8S), T), I8S)
    out["AO host (sum over d_pad)"] = max(absmax([sc(I16, 2**sh), (0, 2**sh - 1), (-(2 ** max(sh - 1, 0)), 0), sc(sc(prod(I8S, W8), d_pad), -1)]) for sh in range(0, 9))
    out["gate host (sum over d_pad)"] = worst_one(sc(prod(I8S, W8), d_pad), I8G)
    out["up (SH_U = 0, int16 by limbs)"] = absmax([I16, sc(sc(prod(I8S, W8), d_pad), -1)])
    out["product clause"] = max(absmax([prod(I16, I16), sc(I16, -(2**sh)), (-(2**sh - 1), 0), (2 ** (sh - 1), 2 ** (sh - 1))]) for sh in range(9, 17))
    out["down host (sum over f_pad)"] = worst_one(sc(prod(I16, W8), f_pad), I16)
    out["residuals (x1 = x + ao, x2 = x1 + z16)"] = 3 * 32768
    # LogUp multiplicities: at most the number of lookups (positions x lookups per position)
    doms = {"D": T * d_pad, "Q": T * q * hd, "Kv": T * kv * hd, "S": q * T * T, "F": T * f_pad}
    out["LogUp multiplicity bound (all U8 lookups, generous 64 per position)"] = 64 * sum(doms.values())
    worst = max(out.values())
    return {"domains_log2": {k: math.log2(v) for k, v in doms.items()}, "clauses_log2": {k: round(math.log2(v), 3) for k, v in out.items()}, "worst_log2": round(math.log2(worst), 3), "below_half_p": 2 * worst < P}


def main():
    res = {}
    for name, g in [("TinyLlama T32", (32, 2048, 5632, 32, 4, 64)), ("TinyLlama T64", (64, 2048, 5632, 32, 4, 64)), ("TinyLlama T128", (128, 2048, 5632, 32, 4, 64)), ("Llama-3-8B T32", (32, 4096, 14336, 32, 8, 128))]:
        r = geom_bounds(name, *g)
        assert r["below_half_p"], name
        res[name] = r
    # the 8B norm window: tn <= 9 derived at width 4096 for every ceps in the class
    dmaxes = {c: math.isqrt(c + 4096 * 32768 * 32768) for c in (1, 78617, 2**40)}
    res["8B D_max and max tn"] = {str(c): (dm, 31 - dm.bit_length(), 2 * dm < 2**24) for c, dm in dmaxes.items()}
    # the real 8B export's constants
    dm = math.isqrt(78617 + 4096 * 32768 * 32768)
    res["8B export (tn 9, Ceps 78617)"] = {"D_max": dm, "wrho": 9 + 1 + dm.bit_length()}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap_r3.json")
    with open(path, "w") as fh:
        json.dump(res, fh, indent=1)
    for k, v in res.items():
        if isinstance(v, dict) and "worst_log2" in v:
            print(k, "worst 2^%s" % v["worst_log2"], {kk: vv for kk, vv in v["clauses_log2"].items() if vv > 30})
        else:
            print(k, v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
