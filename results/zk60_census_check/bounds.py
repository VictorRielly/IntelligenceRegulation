#!/usr/bin/env python3
"""Independent re-derivation of the shaped refusal census bounds (stage 38-39).

Written by the adversarial checker from the CODE (witness.rs, the shaped
kernel lib.rs, layout.rs lookups_at, shape.rs Shape::new), not from the
census test. Exact integer arithmetic only. Prints one block per shape and
asserts the figures the census memo states (section 3 table, AO threshold,
LogUp multiplicity, kernel intermediate, windows).

Run: python3 results/zk60_census_check/bounds.py
"""

from math import isqrt

# calibration constants (layout.rs / kernel calib)
NORM_TN, NORM_CN, NORM_CEPS = 11, 1024, 1
SH_QKV, SH_ROPE, SH_S, SH_O, SH_AO = 7, 7, 6, 9, 7
SH_G, SH_H, SH_Z = 7, 14, 6
F_P, F_RO = 9, 7
MASK = -127
LIMBS_ISQRT = 3
X_ABS, W_LO, W_HI = 32768, -128, 127
P_FIELD = (1 << 64) - (1 << 32) + 1


def rq(acc, sh):
    """requant, ties toward +inf (floor((acc + 2^(sh-1)) / 2^sh)); identity at sh = 0"""
    return acc if sh == 0 else (acc + (1 << (sh - 1))) >> sh


def clog2(v):
    return (v - 1).bit_length()


def npow2(v):
    return 1 << clog2(v)


# (name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols, f_e)
SHAPES = [
    ("toy", 32, 16, 16, 2, 8, 1, 8, 9),
    ("rung", 24, 96, 192, 6, 16, 2, 10, 12),
    ("rung-G", 24, 96, 192, 6, 16, 2, 10, 12),
    ("rung-K4", 24, 96, 192, 12, 8, 4, 10, 12),
    ("rung-K8", 24, 128, 192, 16, 8, 8, 10, 12),
    ("rung-P2", 32, 96, 256, 12, 8, 4, 10, 12),
    ("rung-C6", 32, 384, 512, 12, 32, 4, 10, 12),
    ("rung-W14", 64, 768, 1024, 12, 64, 4, 14, 12),
    ("rung-E32", 32, 768, 1024, 12, 64, 4, 10, 12),
    ("125M", 512, 768, 2048, 12, 64, 4, 14, 9),
]


def y_range():
    """exact image of the norm quotient q = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1)))
    over |x| <= D, g in [-128, 127] (the numerator scales with D, so D = 1 suffices
    for the extremes: x in {-1, 0, 1}, and |x| = D is reachable for every D)"""
    lo, hi = 10**9, -(10**9)
    for d in (1, 2, 3, 1000, 32768):
        for x in (-d, -d + 1, -1, 0, 1, d - 1, d):
            for g in range(W_LO, W_HI + 1):
                num = 2 * x * g * NORM_CN + (d << NORM_TN)
                den = d << (NORM_TN + 1)
                q = num // den
                lo, hi = min(lo, q), max(hi, q)
    return lo, hi


def shape_facts(name, tokens, width, hidden, qh, dh, kv, log_cols, f_e):
    t_pad, d_pad, h_pad, f_pad = npow2(tokens), npow2(width), npow2(qh), npow2(hidden)
    d_max_shape = isqrt(NORM_CEPS + width * 32767 * 32767)  # Shape::new's figure
    norm_wrho = NORM_TN + 1 + d_max_shape.bit_length()
    d_max = isqrt(NORM_CEPS + width * X_ABS * X_ABS)  # the int16 class, -32768 legal
    den_max = d_max << (NORM_TN + 1)
    wrho_s = clog2(tokens) + f_e
    ln = -(-norm_wrho // 8)
    ls = -(-wrho_s // 8)
    lp = -(-(F_P + 1) // 8)
    full_top = norm_wrho == 8 * ln

    ylo, yhi = y_range()
    y_abs = max(-ylo, yhi)
    # Q/K/V and the FFN gate/up accumulators: |y| <= 64, |w| <= 128
    qacc = width * y_abs * 128
    q_img = (rq(-qacc, SH_QKV), rq(qacc, SH_QKV))
    gate_img = (rq(-qacc, SH_G), rq(qacc, SH_G))
    up_img = (-qacc, qacc)
    rope_img = (rq(-2 * 128 * 127, SH_ROPE), rq(2 * 128 * 127, SH_ROPE))
    score_img = (rq(-dh * 127 * 127, SH_S), rq(dh * 127 * 127, SH_S))
    o_img = (rq(-(1 << F_P) * 127, SH_O), rq((1 << F_P) * 127, SH_O))
    # AO: o8 in [-127, 127], w in [-128, 127]: extreme products +-16256
    ao_img = (rq(-width * 16256, SH_AO), rq(width * 16256, SH_AO))
    ao_reach = ao_img[1] > 32767 or ao_img[0] < -32768
    prod_img = (rq(-(X_ABS * 32767), SH_H), rq(X_ABS * X_ABS, SH_H))  # a16, u16 int16
    down_img = (rq(-hidden * X_ABS * 128, SH_Z), rq(hidden * X_ABS * 128, SH_Z))

    # sizes after the P-3 lift (domain_log_at: lift only domains carrying H planes)
    def size(nat_log, carries_h=True):
        return 1 << (log_cols if (carries_h and nat_log < log_cols) else nat_log)

    sizes = {
        "L": size(clog2(16 * t_pad)),
        "D": size(clog2(t_pad * d_pad)),
        "F": size(clog2(t_pad * f_pad)),
        "Q": size(clog2(t_pad * h_pad * dh)),
        "Kv": size(clog2(t_pad * kv * dh)),
        "S": size(clog2(h_pad * t_pad * t_pad)),
    }
    per_pos = {
        "L": 2,
        "D": 18 + 4 * ln + (0 if full_top else 4),
        "F": 9,
        "Q": 13,
        "Kv": 12,
        "S": 7 + lp + 2 * ls,
    }
    u8_total = sum(per_pos[d] * sizes[d] for d in sizes)
    max_count = max(u8_total, sizes["S"], sizes["F"])
    f_true = tokens * hidden
    f_pads = sizes["F"] != f_true

    one_e = 1 << f_e
    kernel_terms = [
        NORM_CEPS + width * X_ABS * X_ABS,
        2 * X_ABS * 128 * NORM_CN + (d_max << NORM_TN),
        den_max,
        qacc + (1 << (SH_QKV - 1)),
        2 * 128 * 127 + (1 << (SH_ROPE - 1)),
        dh * 127 * 127 + (1 << (SH_S - 1)),
        tokens * one_e,
        one_e << F_P,
        (1 << F_P) * 127 + (1 << (SH_O - 1)),
        width * 16256 + (1 << (SH_AO - 1)),
        2 * X_ABS,
        X_ABS * X_ABS + (1 << (SH_H - 1)),
        hidden * X_ABS * 128 + (1 << (SH_Z - 1)),
    ]
    kernel_max = max(kernel_terms)

    return {
        "name": name,
        "pads": (t_pad, d_pad, h_pad, f_pad),
        "d_max_shape": d_max_shape,
        "d_max": d_max,
        "norm_wrho": norm_wrho,
        "den_max": den_max,
        "norm_window_ok": den_max <= (1 << norm_wrho),
        "norm_margin_ratio": ((1 << norm_wrho) / den_max),
        "isqrt_ok": 2 * d_max < (1 << (8 * LIMBS_ISQRT)),
        "wrho_s": wrho_s,
        "softmax_window_ok": tokens * one_e <= (1 << wrho_s),
        "y": (ylo, yhi),
        "q_img": q_img,
        "gate_img": gate_img,
        "up_img": up_img,
        "rope_img": rope_img,
        "score_img": score_img,
        "o_img": o_img,
        "ao_img": ao_img,
        "ao_reachable": ao_reach,
        "prod_img": prod_img,
        "down_img": down_img,
        "u8_total": u8_total,
        "max_count": max_count,
        "f_pads": f_pads,
        "f_padded_positions": sizes["F"] - f_true,
        "f_size": sizes["F"],
        "kernel_max": kernel_max,
    }


def main():
    rows = [shape_facts(*s) for s in SHAPES]
    for r in rows:
        print(f"== {r['name']}")
        for k, v in r.items():
            if k != "name":
                print(f"   {k:20s} {v}")
    by = {r["name"]: r for r in rows}

    # --- the census memo's section-3 table, re-derived ---
    want_ao = {"toy": 2032, "rung": 12192, "rung-G": 12192, "rung-K4": 12192, "rung-K8": 16256, "rung-P2": 12192,
               "rung-C6": 48768, "rung-W14": 97536, "rung-E32": 97536, "125M": 97536}
    want_q = {"toy": 1024, "rung": 6144, "rung-G": 6144, "rung-K4": 6144, "rung-K8": 8192, "rung-P2": 6144,
              "rung-C6": 24576, "rung-W14": 49152, "rung-E32": 49152, "125M": 49152}
    want_down = {"toy": 1048576, "rung": 12582912, "rung-G": 12582912, "rung-K4": 12582912, "rung-K8": 12582912,
                 "rung-P2": 16777216, "rung-C6": 33554432, "rung-W14": 67108864, "rung-E32": 67108864, "125M": 134217728}
    want_fpad = {"rung", "rung-G", "rung-K4", "rung-K8"}
    for n, r in by.items():
        assert r["ao_img"][1] == want_ao[n], (n, r["ao_img"])
        assert r["q_img"][1] == want_q[n], (n, r["q_img"])
        assert r["down_img"][1] == want_down[n], (n, r["down_img"])
        assert r["ao_reachable"] == (n in {"rung-C6", "rung-W14", "rung-E32", "125M"}), n
        assert r["f_pads"] == (n in want_fpad), n
        assert r["norm_window_ok"] and r["isqrt_ok"] and r["softmax_window_ok"], n
        assert r["o_img"] == (-127, 127) and r["y"] == (-64, 64), n
        assert r["max_count"] < P_FIELD and r["kernel_max"] < (1 << 63) - 1, n
    # the AO threshold: 127 w <= 32767 iff w <= 258
    assert max(w for w in range(1, 2000) if rq(w * 16256, SH_AO) <= 32767) == 258
    # the LogUp multiplicity end points
    assert by["toy"]["max_count"] == 61440, by["toy"]["max_count"]
    assert by["125M"]["max_count"] == 98_598_912, by["125M"]["max_count"]
    # the rung padded Dom::F count the memo states: 3,584 of 8,192
    for n in want_fpad:
        assert (by[n]["f_padded_positions"], by[n]["f_size"]) == (3584, 8192), (n, by[n]["f_padded_positions"])
    # the kernel's largest intermediate end points (1.7e10 toy, 8.2e11 125M)
    print("kernel_max toy %.3g, 125M %.3g" % (by["toy"]["kernel_max"], by["125M"]["kernel_max"]))
    print("norm margin at 125M: %.4f bits" % __import__("math").log2(by["125M"]["norm_margin_ratio"]))
    print("ALL CENSUS FIGURES RE-DERIVED: OK")


if __name__ == "__main__":
    main()
