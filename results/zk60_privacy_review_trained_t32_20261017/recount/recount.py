#!/usr/bin/env python3
"""Independent recount of the trained TinyLlama T32 privacy residuals,
derived from the Rust source of ops/zkp-mvp/trained-1b-gate (not from the
gate lane's script).  Exact integer / Fraction arithmetic."""
import math
from fractions import Fraction

P = (1 << 64) - (1 << 32) + 1
P2 = P * P
Q = 256                       # ZkOpts::standard -> num_col_checks = opened_cols = COL_CHECKS
MASK_Q, MASK_MSG, MASK_DOM = 256, 512, 4096   # zk.rs MASK_Q, 1<<MASK_LOG_MSG, 1<<MASK_LOG_DOM


def clog2(v):
    return (v - 1).bit_length()


def lg(x):
    if isinstance(x, Fraction):
        return math.log2(x.numerator) - math.log2(x.denominator)
    return math.log2(x)


# ---------------- shape (shape.rs Shape::new / tinyllama_t32_trained) ----------------
def shape(tokens, width, hidden, qh, hd, kv, log_cols, inv_rate, f_e, norm_wrho, endpoint_rows):
    s = dict(tokens=tokens, width=width, hidden=hidden, qh=qh, hd=hd, kv=kv,
             log_cols=log_cols, inv_rate=inv_rate, f_e=f_e, endpoint_rows=endpoint_rows)
    s["t_pad"], s["d_pad"] = 1 << clog2(tokens), 1 << clog2(width)
    s["h_pad"], s["f_pad"] = 1 << clog2(qh), 1 << clog2(hidden)
    s["norm_wrho"] = norm_wrho
    s["wrho_s"] = clog2(tokens) + f_e
    return s


NAT = {}
def natural_log(s, d):
    t, h, dp, fp = s["t_pad"], s["h_pad"], s["d_pad"], s["f_pad"]
    return {"T": clog2(t), "Ht": clog2(h * t), "L": clog2(16 * t), "D": clog2(t * dp),
            "Q": clog2(t * h * s["hd"]), "Kv": clog2(t * s["kv"] * s["hd"]),
            "S": clog2(h * t * t), "F": clog2(t * fp), "Tab": 8}[d]


def true_size(s, d):
    T = s["tokens"]
    return {"T": T, "Ht": s["qh"] * T, "L": 3 * 3 * T, "D": T * s["width"],
            "Q": T * s["qh"] * s["hd"], "Kv": T * s["kv"] * s["hd"],
            "S": s["qh"] * T * T, "F": T * s["hidden"], "Tab": 256}[d]


def log(s, d):
    nat = natural_log(s, d)
    carries = d not in ("T", "Ht")
    return s["log_cols"] if (carries and nat < s["log_cols"]) else nat


def size(s, d):
    return 1 << log(s, d)


def rows_of(s, d):
    return max(1, size(s, d) >> s["log_cols"])


def pads(s, d):
    return size(s, d) != true_size(s, d)


def limbs(s):
    ln = -(-s["norm_wrho"] // 8)
    top_full = s["norm_wrho"] == 8 * ln
    ls = -(-s["wrho_s"] // 8)
    lp = -(-(9 + 1) // 8)
    return ln, top_full, ls, lp


def a_plane_doms(s):
    ln, _, ls, lp = limbs(s)
    v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2 + ["D"] * (4 + 2 * ln + 8 + 2 * ln + 7)
    v += ["Q"] * 7 + ["Kv"] * 6 + ["S"] * (5 + lp + 2 * ls) + ["F"] * 11 + ["Tab"] * 3
    return v


def lookups_per_position(s, d):
    ln, top_full, ls, lp = limbs(s)
    top = 0 if top_full else 1
    per_norm = 2 + 2 * (ln + top)
    return {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9, "Q": 13, "Kv": 12,
            "S": 2 + 2 + (lp + 1) + 2 * (ls + 1), "T": 0, "Ht": 0, "Tab": 0}[d]


def helpers(s, d):
    return -(-lookups_per_position(s, d) // 2)


def h_plane_doms(s):
    v = ["L"] * helpers(s, "L") + ["D"] * helpers(s, "D") + ["Q"] * helpers(s, "Q")
    v += ["Kv"] * helpers(s, "Kv") + ["S"] * (helpers(s, "S") + 1) + ["F"] * (helpers(s, "F") + 1)
    v += ["Tab"] * 4
    return v


SC = dict(SS=0, SSM=1, TZC=2, LZC=3, RS=4, QMM=5, KMM=6, VMM=7, SCORE=8, PV=9, WO=10, GMM=11,
          UMM=12, DMM=13, DZC=14, QZC=15, KVZC=16, SZC=17, FZC=18, TAB=19, ZS=20, IO_IN=21, IO_OUT=22)
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
IND = [("SS", "D"), ("SSM", "D"), ("RS", "S"), ("DZC", "D"), ("QZC", "Q"), ("KVZC", "Kv"), ("SZC", "S"), ("FZC", "F")]


def claim_sites(s):
    a = [0] * 23
    h = [0] * 23
    on = lambda d: a_plane_doms(s).count(d)
    a[SC["SS"]] = a[SC["SSM"]] = 1
    a[SC["TZC"]] = 4 + 2 * 9
    a[SC["LZC"]] = on("L"); h[SC["LZC"]] = helpers(s, "L")
    a[SC["RS"]] = 2
    for k in ("QMM", "KMM", "VMM", "WO", "GMM", "UMM", "DMM"):
        a[SC[k]] = 1
    a[SC["SCORE"]] = a[SC["PV"]] = 2
    a[SC["DZC"]] = on("D") + 2; h[SC["DZC"]] = helpers(s, "D")
    a[SC["QZC"]] = on("Q") + 1; h[SC["QZC"]] = helpers(s, "Q")
    a[SC["KVZC"]] = on("Kv") + 1; h[SC["KVZC"]] = helpers(s, "Kv")
    a[SC["SZC"]] = on("S") + 2; h[SC["SZC"]] = helpers(s, "S") + 1
    a[SC["FZC"]] = on("F"); h[SC["FZC"]] = helpers(s, "F") + 1
    a[SC["TAB"]] = 3; h[SC["TAB"]] = 3
    h[SC["ZS"]] = 1
    a[SC["IO_IN"]] = a[SC["IO_OUT"]] = 1
    return a, h


def slots(s, pad_rule=True):
    cube = {"SS": "D", "SSM": "D", "DZC": "D", "IO_IN": "D", "IO_OUT": "D", "TZC": "T", "LZC": "L",
            "RS": "S", "SZC": "S", "QZC": "Q", "KVZC": "Kv", "FZC": "F", "TAB": "Tab", "ZS": "Tab"}
    lkv = clog2(s["kv"])
    inner = {"QMM": clog2(s["d_pad"]), "KMM": clog2(s["d_pad"]), "VMM": clog2(s["d_pad"]),
             "WO": clog2(s["d_pad"]), "GMM": clog2(s["d_pad"]), "UMM": clog2(s["d_pad"]),
             "SCORE": lkv + clog2(s["hd"]), "PV": lkv + clog2(s["t_pad"]), "DMM": clog2(s["f_pad"])}
    out = []
    for name, i in sorted(SC.items(), key=lambda kv: kv[1]):
        main = log(s, cube[name]) if name in cube else inner[name]
        ind = pad_rule and any(n == name and pads(s, d) for n, d in IND)
        ext = 2 if name in ("SCORE", "PV") else 1
        geq = name in ("SCORE", "PV") and lkv > 0
        out.append((main, ext, BASE_DEGREE[i] + int(ind) + int(geq)))
    return out


def layout(s, pad_rule=True):
    n = 1 << s["log_cols"]
    a_data = sum(rows_of(s, d) for d in a_plane_doms(s))
    asites, hsites = claim_sites(s)
    a_rows = a_data + 2 * sum(asites) + 2
    h_data = sum(2 * rows_of(s, d) for d in h_plane_doms(s))
    h_rows = h_data + 2 * sum(hsites) + 2
    specs = [(m + e, d) for (m, e, d) in slots(s, pad_rule)]
    return dict(n=n, a_data=a_data, a_rows=a_rows, a_sites=sum(asites), h_data=h_data,
                h_rows=h_rows, h_sites=sum(hsites), specs=specs)


# ---------------- draws, site by site ----------------
def block_draws(lay):
    n = lay["n"]
    A_mask = (lay["a_rows"] - lay["a_data"]) * n            # protocol.rs:874-876
    A_pads = lay["a_rows"] * Q                               # zkp-core pcs.rs:774 via protocol.rs:881
    cfs = 2 * sum(nv * d + 2 for nv, d in lay["specs"])     # zk.rs:485 CfsMask::random -> fp2_vec(L_s)
    M_pads = 2 * len(lay["specs"]) * MASK_Q                  # zk.rs:496
    M_bu = 4 * 2 * MASK_MSG                                  # zk.rs:503-508 (b_re,b_im,u_re,u_im)
    H_mask = (lay["h_rows"] - lay["h_data"]) * n            # protocol.rs:987-989
    H_u = 2 * (n - 1)                                        # protocol.rs:990-998 (u rows are DATA rows)
    H_pads = lay["h_rows"] * Q                               # pcs.rs:774 via protocol.rs:1000
    parts = dict(A_mask=A_mask, A_pads=A_pads, M_cfs=cfs, M_pads=M_pads, M_b_u=M_bu,
                 H_mask=H_mask, H_zero_sum=H_u, H_pads=H_pads)
    parts["total"] = sum(parts.values())
    return parts


def io_draws(n, data_rows, rows):
    return (rows - data_rows) * n + rows * Q


def run(L, blk, bd, ep):
    return L * blk + (L - 1) * bd + 2 * ep


# exact per-draw statistical distance of (U128 mod p)
r = (1 << 128) % P
SD = Fraction(r * (P - r), P * (1 << 128))

if __name__ == "__main__":
    print("per-draw SD log2 = %.6f (D9 bound 2^-96)" % lg(SD))
    # toy calibration (layout.rs SLOTS literal, rows 455/213, 384/280, n=256, seam endpoints 7 rows / 2 data)
    toy_specs = [(9,1,3),(9,1,3),(5,1,3),(9,1,4),(11,1,3),(4,1,2),(4,1,2),(4,1,2),(3,2,2),(5,2,2),(4,1,2),(4,1,2),(4,1,2),(4,1,2),(9,1,4),(9,1,4),(8,1,4),(11,1,4),(9,1,4),(8,1,3),(8,1,2),(9,1,2),(9,1,2)]
    toy = dict(n=256, a_data=213, a_rows=455, h_data=280, h_rows=384, specs=[(a + b, c) for a, b, c in toy_specs])
    tb = block_draws(toy)
    print("toy block", tb, "toy total", tb["total"] + 2 * io_draws(256, 2, 7), "(D22: 327,052)")

    tl = shape(32, 2048, 5632, 32, 64, 4, 12, 4, 9, 32, 21)
    lay = layout(tl)
    print("TL layout: A rows %d data %d sites %d | H rows %d data %d sites %d" % (
        lay["a_rows"], lay["a_data"], lay["a_sites"], lay["h_rows"], lay["h_data"], lay["h_sites"]))
    print("TL specs", lay["specs"], "sum L_s (Fp2) =", sum(a * b + 2 for a, b in lay["specs"]),
          "sum rounds =", sum(a for a, _ in lay["specs"]))
    print("pads per dom:", {d: pads(tl, d) for d in ["T","Ht","L","D","Q","Kv","S","F","Tab"]})
    bd_ = block_draws(lay)
    print("TL block", bd_)
    n = 1 << 12
    bnd = io_draws(n, 16, 16 + 2 * 2 + 2)
    ep = io_draws(n, 16, 21)
    print("boundary", bnd, "endpoint", ep)
    nn = n * 4
    for L in (1, 2, 22):
        D = run(L, bd_["total"], bnd, ep)
        salts = L * (2 * nn + MASK_DOM) + (L - 1) * nn + 2 * nn
        print("L=%d draws %d  sampler(2^-96) %.3f  exactSD %.3f | S4 1w %.3f 2w %.3f | salts %d salt-guess %.3f leafcoll %.3f | live (3L+1)/p %.3f  exact-det (3L+1)(1/p+1/p^2) %.3f | 2^20 runs %.3f 10^6 runs %.3f" % (
            L, D, lg(Fraction(D, 1 << 96)), lg(D * SD), lg(Fraction(L * 768, P2)), lg(Fraction(2 * L * 768, P2)),
            salts, lg(Fraction(salts << 128, 1 << 256)), lg(Fraction(salts * (salts - 1) // 2, 1 << 256)),
            lg(Fraction(3 * L + 1, P)), lg((3 * L + 1) * (Fraction(1, P) + Fraction(1, P2))),
            lg(Fraction(D << 20, 1 << 96)), lg(Fraction(D * 10**6, 1 << 96))))
    # transcript: A = absorbs + live squeezes + tag squeezes
    # per-stage squeezes from code: beta,gamma,alpha 3; c 23; rounds sum; M theta+rs(50)+idx 64;
    # A opening: claims 120 + rows 1729 + 64; H opening: claims 50 (49 sites + LogUp sum claim) + 1798 + 64
    rounds = sum(a for a, _ in lay["specs"])
    per_stage_counted = 3 + 23 + rounds + (1 + 50 + 64) + (lay["a_sites"] + lay["a_rows"] + 64) + (lay["h_sites"] + 1 + lay["h_rows"] + 64)
    print("per-stage counted squeezes (no slot-definition draws):", per_stage_counted)
    meas_L2 = 9578
    defn = (meas_L2 - (2 * per_stage_counted + 2 * (1 + 21 + 64) + (2 + 22 + 64))) / 2
    print("implied slot-definition draws per stage from the measured L=2 counter 9,578:", defn)
    def absorbs(L):
        common = 2 + 3 + 1 + 3 + 3 * 23 + rounds + 2 + (36 + 1) + (9 + 1)
        t = 6
        for k in range(L):
            x = common + (3 if k + 1 < L else 0) + (2 if k == 0 else 3) + (2 if k + 1 == L else 0)
            t += x
        return t
    for L in (1, 2, 22):
        counted = L * per_stage_counted + 2 * (1 + 21 + 64) + (L - 1) * (2 + 22 + 64)
        live_meas = counted + int(defn) * L
        chal = live_meas - 64 * (4 * L + 1)
        A_bound = absorbs(L) + counted + 4 * L + 1024 * L
        A_meas = absorbs(L) + live_meas + 4 * L
        q = 1 << 128
        print("L=%d absorbs %d counted %d challenges(meas-extrap) %d | A_bound %d prequery %.3f coll %.3f B10 %.3f | A_meas %d prequery %.3f" % (
            L, absorbs(L), counted, chal, A_bound, lg(Fraction(q * A_bound, 1 << 256)),
            lg(Fraction(A_bound * (A_bound - 1) // 2, 1 << 256)), lg(Fraction(A_bound + q, 1 << 256)),
            A_meas, lg(Fraction(q * A_meas, 1 << 256))))
    print("tag-key C(12,2) %.2f ; 3*4 %.2f" % (lg(Fraction(66, 1 << 256)), lg(Fraction(12, 1 << 256))))
