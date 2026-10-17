#!/usr/bin/env python3
"""Round-2 independent checker (reviewer, 2026-10-17). Written from the Rust of
ops/zkp-mvp/trained-1b-review-r2/ (argument.rs SC_QZC/SC_KVZC/SC_SZC/SC_FZC/
SC_DZC hosts, layout.rs lookups_at, shape.rs classes), NOT from the author's
nowrap_check.py / reviewer_nowrap_round2.py. Exact integers. Writes
reviewer_nowrap_r2.json beside itself.

Adversarial range facts (each from a lookup or a limb decomposition):
  int8 sym values (y, nm, q8, k8, v8, qr8, kr8, s8, o8) in [-127, 127]
  g8 in [-128, 127] (the 256-row activation table index)
  int16 values (x, x1, x2, ao, z16, u16, h16; a16 by the table's i16 type) in [-32768, 32767]
  public int8 weights in [-128, 127]
  softmax: e in [0, 2^f_e] (exp table structure), p in [0, 2^(F_P+1)) (2 limbs + top pin),
           sr, sg in [0, 2^wrho_s) (ls limbs + top pin), Sum = row sum of e over T
  one-limb biased remainder l: byte(l) and scaled(l, 2^(8-sh)) in [0, 256)
  two-limb biased remainder l0 + 256 l1: byte(l0), byte(l1), scaled(l1, 2^(16-sh))
"""
import json
import math
import os
import sys

P = 2**64 - 2**32 + 1
F_P = 9
I8S = (-127, 127)
I8G = (-128, 127)
I16 = (-32768, 32767)
W8 = (-128, 127)


def prod(*ivs):
    lo, hi = ivs[0]
    for a, b in ivs[1:]:
        c = [lo * a, lo * b, hi * a, hi * b]
        lo, hi = min(c), max(c)
    return (lo, hi)


def scale(iv, k):
    return (iv[0] * k, iv[1] * k)


def absmax(terms):
    return max(abs(sum(t[0] for t in terms)), abs(sum(t[1] for t in terms)))


def half(sh):
    return 0 if sh == 0 else 2 ** (sh - 1)


def admissible_one_limb(sh):
    """every l a byte with 2^(8-sh) l also a byte (no wrap: l < 256 so the
    product is < 2^16)"""
    return [l for l in range(256) if 0 <= (2 ** (8 - sh)) * l < 256]


def admissible_two_limb(sh):
    """the set of l0 + 256 l1 with l0, l1 bytes and 2^(16-sh) l1 a byte"""
    l1s = [l1 for l1 in range(256) if 0 <= (2 ** (16 - sh)) * l1 < 256]
    return (0, 255 + 256 * max(l1s)), len(l1s)


def main():
    out = {"P": P}
    # ---------------- 1. shift windows: exactness of every remainder window
    win = {}
    for sh in range(0, 9):
        ls = admissible_one_limb(sh)
        ok = ls == list(range(2**sh))
        win[f"one-limb sh={sh}"] = ok
        assert ok or sh == 0 and ls == [0], sh
    for sh in range(9, 17):
        (lo, hi), n1 = admissible_two_limb(sh)
        ok = (lo, hi) == (0, 2**sh - 1)
        win[f"two-limb sh={sh}"] = ok
        assert ok, sh
    out["remainder_windows_exact"] = win
    # honest remainders: requant(acc, sh) gives r + half in [0, 2^sh) for EVERY integer acc
    for sh in range(0, 17):
        for acc in list(range(-70000, 70000, 37)) + [-(2**40), 2**40 - 1, -1, 0, 1]:
            y = (acc + half(sh)) >> sh
            r = acc - (y << sh)
            assert 0 <= r + half(sh) < 2**sh, (sh, acc)
    # ---------------- 2. host relations over the declared windows (adversarial values)
    #  width up to 4096 (class), hidden up to 16384 padded, head_dim 64, T 32
    d_pad, f_pad, hd, T = 4096, 16384, 64, 32
    hosts = {}

    def host(name, sh, out_iv, rem_hi, acc_iv):
        b = absmax([scale(out_iv, 2**sh), (0, rem_hi), (-half(sh), -half(sh)), (-acc_iv[1], -acc_iv[0])])
        hosts[f"{name} sh={sh}"] = b
        return b

    acc_qkv = scale(prod(I8S, W8), d_pad)
    acc_gate = scale(prod(I8S, W8), d_pad)
    acc_score = scale(prod(I8S, I8S), hd)
    acc_o = scale(prod((0, 2 ** (F_P + 1) - 1), I8S), T)
    acc_ao = scale(prod(I8S, W8), d_pad)
    acc_down = scale(prod(I16, W8), f_pad)
    worst = 0
    for sh in range(1, 9):
        worst = max(worst, host("Q/K/V", sh, I8S, 2**sh - 1, acc_qkv), host("score", sh, I8S, 2**sh - 1, acc_score), host("gate", sh, I8G, 2**sh - 1, acc_gate), host("down", sh, I16, 2**sh - 1, acc_down))
    for sh in range(0, 9):
        worst = max(worst, host("AO", sh, I16, 2**sh - 1, acc_ao))
    for sh in range(9, 17):
        worst = max(worst, host("O", sh, I8S, 2**sh - 1, acc_o))
        # product clause f0 = a16 u16 - 2^sh h16 - rh + half
        b = absmax([prod(I16, I16), scale(I16, -(2**sh)), (-(2**sh - 1), 0), (half(sh), half(sh))])
        hosts[f"product sh={sh}"] = b
        worst = max(worst, b)
    out["host_bounds_log2"] = {k: round(math.log2(v), 3) for k, v in hosts.items()}
    out["host_worst_log2"] = round(math.log2(worst), 3)
    assert 2 * worst < P
    # uniqueness under no wrap: for each site, given acc, the (out, rem) pair with
    # rem+half in [0, 2^sh) is unique (spot-checked exhaustively on a grid)
    for sh in range(0, 17):
        for acc in range(-5000, 5000, 7):
            sols = [o for o in range(acc // (2**sh) - 3, acc // (2**sh) + 4) if 0 <= acc - o * 2**sh + half(sh) < 2**sh]
            assert len(sols) == 1, (sh, acc, sols)
    # ---------------- 3. softmax over the declared class f_e 9..16, every T with wrho_s <= 24
    sm = {}
    worst_sm = 0
    for T_ in [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]:
        lt = (T_ - 1).bit_length()
        for f_e in range(9, 17):
            wrho_s = lt + f_e
            if wrho_s > 24:
                continue
            e = (0, 2**f_e)
            p = (0, 2 ** (F_P + 1) - 1)
            S = (1, T_ * 2**f_e)
            sr = (0, 2**wrho_s - 1)
            sg = (0, 2**wrho_s - 1)
            c2 = absmax([scale(e, 2**F_P), scale(prod(p, S), -1), (-sr[1], 0)])
            c3 = absmax([sg, sr, (1, 1), (-S[1], -S[0])])
            rs = T_ * 2**f_e  # the row sum of e
            b = max(c2, c3, rs)
            worst_sm = max(worst_sm, b)
            # a wrapping solution needs |c2 integer| >= P: impossible if 2 c2 < P
            sm[f"T{T_} f_e{f_e}"] = dict(c2_log2=round(math.log2(c2), 3), c3_log2=round(math.log2(c3), 3), wraps=2 * b >= P)
    out["softmax_class"] = sm
    out["softmax_worst_log2"] = round(math.log2(worst_sm), 3)
    assert 2 * worst_sm < P
    # explicit forgery search at the class edge (T32, f_e 16) with all-equal rows,
    # every row length t+1, every delta, k in {-2..2}\{0}
    found = []
    f_e = 16
    wrho_s = 5 + f_e
    for t in range(32):
        Sum = (t + 1) * 2**f_e
        e = 2**f_e
        p, sr = divmod(e << F_P, Sum)
        for delta in range(-1023, 1024):
            if delta == 0 or not (0 <= p + delta < 2 ** (F_P + 1)):
                continue
            for k in (-2, -1, 1, 2):
                sr2 = sr - delta * Sum + k * P
                if 0 <= sr2 < Sum and 0 <= Sum - 1 - sr2 < 2**wrho_s and sr2 < 2**wrho_s:
                    found.append((t, delta, k))
    out["forgery_search_T32_f_e16_all_equal_rows"] = found
    assert not found
    # ---------------- 4. the pg_rot1 export's constants through my round-1 validator logic
    import importlib.util
    spec = importlib.util.spec_from_file_location("r1", os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap.py"))
    r1 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(r1)
    adm = r1.derive_at_width(10, 3999, 3122, 91255, 3, 2048)
    out["pg_rot1_norm_admitted_d_max_wrho"] = adm[0]
    cb = r1.clause_bounds(10, 3999, 91255, 3, 2048)
    out["pg_rot1_norm_clause_log2"] = {k: round(math.log2(v), 3) for k, v in cb.items()}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviewer_nowrap_r2.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1, default=str)
    print(json.dumps({k: out[k] for k in ["host_worst_log2", "softmax_worst_log2", "forgery_search_T32_f_e16_all_equal_rows", "pg_rot1_norm_admitted_d_max_wrho", "pg_rot1_norm_clause_log2"]}, indent=1))
    print("remainder windows exact:", all(out["remainder_windows_exact"].values()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
