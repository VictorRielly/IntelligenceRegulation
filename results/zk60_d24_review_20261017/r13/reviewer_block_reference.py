"""D24 review R13: an independent integer reference of ONE R13 block, written
from the S2 build spec (results/zk60_fidelity_parity_20261019/S2_BUILD_SPEC.json)
and the coordinator notes of 2026-10-26 19:11Z / 19:50Z / 20:00:40Z and
2026-10-28 21:14Z, NOT from Sol's code or Python.

Spec arithmetic used (base calibration -> R13):
  norm   y = round(g*Cn*x / (D * 2^(tn-8))), D = isqrt(ceps + sum x^2), int16 [-32768,32767]
  q,k    round(acc*m_j / 2^(sh_qkv+7)), v: 2^(sh_qkv+8), int16
  rope   half-split, round(/2^7), int16
  score  round(sum qr*kr / 2^(sh_s+12)), int8 symmetric [-127,127] on ALL (t,j) (masked too)
  P      floor(e * 2^12 / Sum), e = exp[mx - s] over j<=t
  o      round(sum P*v / 2^(sh_o+3)), int16
  ao     round(acc*m_o / 2^(sh_ao+14)), int16; x1 = x + ao
  gate   per channel j in group (e_in_j,e_out_j): round(acc*m_g / 2^(sh_g+10+e_in_j-e_in_base)), int12
  silu   table(e_in,e_out)[g] = floor(silu(g*2^(e_in-4)) / 2^e_out + 1/2), |.|<=32767 (std members clamp)
  up     round(acc*m_u / 2^12), int16
  h      LOW : round(a * u * 2^(e_out_j-e_out_base) / 2^sh_h), int16
         H24 : round(a * u * 2^(e_out_j-e_out_base) / 2^(sh_h-8)), int24
         (group scale BEFORE the single h rounding; computed with exact rationals)
  down   round(acc*m_d / 2^(sh_z+6 [+8 at H24])), int16; x2 = x1 + z
round(n/2^s) means floor((n + 2^(s-1)) / 2^s) (ties toward +inf).

Usage: python3 reviewer_block_reference.py <fixture.tsv> <trace_low.tsv> <trace_h24.tsv> <out.json>
"""
import json
import math
import sys
from fractions import Fraction


def rnd(n, s):
    return (n + (1 << (s - 1))) >> s  # python >> is floor for negatives


def rnd_frac(fr):
    return math.floor(fr + Fraction(1, 2))


def isqrt(n):
    return math.isqrt(n)


def silu_word(g, e_in, e_out, clamp=True):
    x = g * 2.0 ** (e_in - 4)
    v = x / (1.0 + math.exp(-x))
    w = math.floor(v / 2.0 ** e_out + 0.5)
    if clamp:
        w = max(-32767, min(32767, w))
    return w


def check(lo, hi, v, what):
    if not (lo <= v <= hi):
        raise ValueError(f"refusal at {what}: {v}")
    return v


def block(f, stack, geo, base):
    T, d, F, H, dh, KV = geo
    half = dh // 2
    grp = H // KV
    tn, cn_a, cn_m, ceps = base["tn"], base["cn_a"], base["cn_m"], base["ceps"]
    gamma = f["gamma"]
    x = [f["input"][t * d:(t + 1) * d] for t in range(T)]

    def norm(rows, gam, cn):
        out = []
        tn2 = tn - 8
        for r in rows:
            D = isqrt(ceps + sum(v * v for v in r))
            row = []
            for i, xi in enumerate(r):
                # y = round(g*Cn*x / (D*2^tn2)) exactly
                num = Fraction(gam[i] * cn * xi, D * (1 << tn2))
                row.append(check(-32768, 32767, rnd_frac(num), "norm"))
            out.append(row)
        return out

    def mat(rows, w, nin, nout):  # w input-major [i*nout + j]
        return [[sum(r[i] * w[i * nout + j] for i in range(nin)) for j in range(nout)] for r in rows]

    y = norm(x, gamma, cn_a)
    qw, kvw = H * dh, KV * dh
    sq = base["qkv"]
    q = [[check(-32768, 32767, rnd(a * f["m_q"][j], sq + 7), "q") for j, a in enumerate(r)] for r in mat(y, f["w_q"], d, qw)]
    k = [[check(-32768, 32767, rnd(a * f["m_k"][j], sq + 7), "k") for j, a in enumerate(r)] for r in mat(y, f["w_k"], d, kvw)]
    v = [[check(-32768, 32767, rnd(a * f["m_v"][j], sq + 8), "v") for j, a in enumerate(r)] for r in mat(y, f["w_v"], d, kvw)]

    def rope(rows, heads):
        out = []
        for t, r in enumerate(rows):
            o = [0] * len(r)
            for h in range(heads):
                b = h * dh
                for i in range(half):
                    c, s = f["cos"][t * half + i], f["sin"][t * half + i]
                    a0, a1 = r[b + i], r[b + i + half]
                    o[b + i] = check(-32768, 32767, rnd(c * a0 - s * a1, 7), "rope")
                    o[b + i + half] = check(-32768, 32767, rnd(s * a0 + c * a1, 7), "rope")
            out.append(o)
        return out

    qr, kr = rope(q, H), rope(k, KV)
    ss = base["score"] + 12
    s = [[[check(-127, 127, rnd(sum(qr[t][h * dh + i] * kr[j][(h // grp) * dh + i] for i in range(dh)), ss), "score")
           for j in range(T)] for t in range(T)] for h in range(H)]
    exp = f["exp"]
    P = [[[0] * T for _ in range(T)] for _ in range(H)]
    o = [[0] * qw for _ in range(T)]
    for h in range(H):
        for t in range(T):
            mx = max(s[h][t][j] for j in range(t + 1))
            es = [exp[mx - s[h][t][j]] for j in range(t + 1)]
            tot = sum(es)
            for j in range(t + 1):
                P[h][t][j] = (es[j] << 12) // tot
            for i in range(dh):
                acc = sum(P[h][t][j] * v[j][(h // grp) * dh + i] for j in range(t + 1))
                o[t][h * dh + i] = check(-32768, 32767, rnd(acc, base["pv"] + 3), "pv")
    ao = [[check(-32768, 32767, rnd(a * f["m_o"][j], base["ao"] + 14), "ao") for j, a in enumerate(r)] for r in mat(o, f["w_o"], qw, d)]
    x1 = [[check(-32768, 32767, a + b, "res1") for a, b in zip(r1, r2)] for r1, r2 in zip(x, ao)]
    nm = norm(x1, gamma, cn_m)
    members = [tuple(f["members"][2 * i:2 * i + 2]) for i in range(len(f["members"]) // 2)]
    gid = f["groups"]
    bin_, bout = base["member"]
    gacc = mat(nm, f["w_g"], d, F)
    uacc = mat(nm, f["w_u"], d, F)
    gate, a_raw, up, hh = [], [], [], []
    for t in range(T):
        gr, ar, ur, hr = [], [], [], []
        for j in range(F):
            ein, eout = members[gid[j]]
            g = check(-2048, 2047, rnd(gacc[t][j] * f["m_g"][j], base["gate"] + 10 + ein - bin_), "gate")
            a = silu_word(g, ein, eout)
            u = check(-32768, 32767, rnd(uacc[t][j] * f["m_u"][j], 12), "up")
            Hs = base["product"] - (8 if stack == "h24" else 0)
            hv = rnd_frac(Fraction(a * u) * Fraction(2) ** (eout - bout) / (1 << Hs))
            lim = (1 << 23) if stack == "h24" else (1 << 15)
            hv = check(-lim, lim - 1, hv, "h")
            gr.append(g); ar.append(a); ur.append(u); hr.append(hv)
        gate.append(gr); a_raw.append(ar); up.append(ur); hh.append(hr)
    dsh = base["down"] + 6 + (8 if stack == "h24" else 0)
    z = [[check(-32768, 32767, rnd(a * f["m_d"][j], dsh), "down") for j, a in enumerate(r)] for r in mat(hh, f["w_d"], F, d)]
    x2 = [[check(-32768, 32767, a + b, "res2") for a, b in zip(r1, r2)] for r1, r2 in zip(x1, z)]
    flat = lambda m: [v for r in m for v in r]
    return {
        "y": flat(y), "q": flat(q), "k": flat(k), "v": flat(v), "qr": flat(qr), "kr": flat(kr),
        "s": [s[h][t][j] for h in range(H) for t in range(T) for j in range(T)],
        "p": [P[h][t][j] for h in range(H) for t in range(T) for j in range(T)],
        "o8": flat(o), "ao": flat(ao), "x1": flat(x1), "nm": flat(nm), "gate": flat(gate),
        "a_group": flat(a_raw), "u16": flat(up), "h16": flat(hh), "z16": flat(z), "x2": flat(x2),
    }


def parse(path):
    out = {}
    for line in open(path):
        c = line.rstrip("\n").split("\t")
        out[c[0]] = [int(v) for v in c[1:]]
    return out


def main():
    fx, tl, th, outp = sys.argv[1:5]
    f = parse(fx)
    # the fixture's geometry and base calibration, as Sol's Rust test sets them
    geo = (32, 16, 32, 4, 4, 2)
    base = dict(tn=10, cn_a=200, cn_m=180, ceps=123, qkv=8, score=6, pv=9, ao=7, gate=8, product=14, down=6, member=(-3, -11))
    report = {}
    for stack, path in [("low", tl), ("h24", th)]:
        mine = block(f, stack, geo, base)
        theirs = parse(path)
        res = {}
        for key, vals in mine.items():
            if key not in theirs:
                res[key] = "absent in trace"
                continue
            diff = sum(1 for a, b in zip(vals, theirs[key]) if a != b) + abs(len(vals) - len(theirs[key]))
            res[key] = {"n": len(vals), "differ": diff, "nonzero": sum(1 for a in vals if a)}
        report[stack] = res
    json.dump(report, open(outp, "w"), indent=1)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
