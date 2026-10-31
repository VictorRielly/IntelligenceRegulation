"""D24 review R14-tier: independent exact recount of Sol's native D27 claims.

Inputs: Sol's native claim encodings (decoded here, never trusted), the
REVIEW_R14 section 3 formula, Shieldstral geometry and the slot list
transcribed from split_layout.rs (as read for this review). Python ints and
Fractions only; floats are used for printed bit figures only.
"""
import json
import math
import random
import re
import struct
import sys
from fractions import Fraction

P = 2**64 - 2**32 + 1
F = P * P
S = 2**128


def lg(x):
    assert x > 0 and x & (x - 1) == 0
    return x.bit_length() - 1


def geometry(T, dd):
    n = 1 << (14 if T == 128 else 15)
    width, hidden, heads, hd, kv, cap = 3072, 9216, 32, 128, 8, 32
    size = {"L": max(16 * T, n), "D": T * width, "Q": T * heads * hd, "Kv": T * kv * hd,
            "S": heads * T * T, "F": T * hidden}
    if dd:
        size["Dd"] = heads * T * cap
    ls = -(-(lg(T) + 9) // 8)            # f_e = 9 at every actual layer
    per = {"L": 2, "D": 34, "Q": 14, "Kv": 14, "F": 14, "S": 6 if dd else 11 + 2 * ls}
    if dd:
        per["Dd"] = 5 + 2 * ls
    return n, size, per


def slot_list(T, dd):
    """(main, ext, degree) per physical slot, transcribed from SplitLayout::new."""
    n = 1 << (14 if T == 128 else 15)
    lt, ld, lf = lg(T), lg(2048), lg(8192)
    out = []
    out += [(lt + ld, 1, 3)] * 2                                   # SS, SSM (indicator removed)
    out += [(lt, 1, 3), (lg(max(16 * T, n)), 1, 4), (lg(32 * T * T), 1, 3)]  # TZC LZC RS
    out += [(ld, 1, 2)] * 3                                        # QMM KMM VMM
    out += [(3 + 7, 2, 3), (3 + lt, 2, 3)]                         # SCORE PV
    out += [(lg(4096), 1, 2)] * 2                                  # WO w/n
    out += [(ld, 1, 2)] * 4                                        # GMM, UMM w/n
    out += [(lf, 1, 2)] * 2                                        # DMM w/n
    out += [(lg(T * 2048), 1, 4), (lg(T * 1024), 1, 4)]            # DZC w/n
    out += [(lg(T * 4096), 1, 4), (lg(T * 1024), 1, 4), (lg(32 * T * T), 1, 4)]  # QZC KVZC SZC
    out += [(lg(T * 8192), 1, 4), (lg(T * 1024), 1, 4)]            # FZC w/n
    out += [(lg(n), 1, 3), (lg(n), 1, 2)]                          # TAB ZS
    out += [(lg(T * 2048), 1, 2), (lg(T * 1024), 1, 2)] * 2        # IO_IN, IO_OUT w/n
    if dd:
        out += [(lg(32 * T * 32), 1, 4)]
    return out


def expected_terms(T, dd, groups):
    n, size, per = geometry(T, dd)
    byte = sum(size[d] * per[d] for d in per)
    N = byte + size["S"] + size["F"] + (size["S"] if dd else 0)
    lookup = sum(N + 4 * (512 + 4096 * g + (size["Dd"] if dd else 0)) - 1 for g in groups)
    sl = slot_list(T, dd)
    L = len(groups)
    sc = L * sum((m + e) * d for m, e, d in sl)
    zc = L * sum(3 * (m + e) + 3 for m, e, _ in sl)
    regular = 3 * L + 1
    encoded = 4 * n
    pcs = regular * ((encoded - (n + 256)) // 3 + 1 + 4096) + L * (2 * 512 + 1 + 4096)
    pcs_ceil = regular * (-(-(encoded - (n + 256)) // 3) + 1 + 4096) + L * (2 * 512 + 1 + 4096)
    col_base = Fraction(2 * encoded + n + 256, 3 * encoded)
    mask_base = Fraction(2 * 4096 + 2 * 512, 3 * 4096)
    assert mask_base == Fraction(3, 4)
    col = regular * col_base**256 + L * mask_base**256
    exact = col + Fraction(lookup + sc + zc + pcs, F)
    exact_pcs_ceil = col + Fraction(lookup + sc + zc + pcs_ceil, F)
    return dict(n=n, byte=byte, N=N, lookup=lookup, sc=sc, zc=zc, pcs=pcs, regular=regular,
                exact=exact, exact_pcs_ceil=exact_pcs_ceil, col=col, sc_per=sc // L, zc_per=zc // L,
                slots=len(sl))


# --- an independent Python port of the native integer algorithm -------------
def fraction_units(num, den):
    assert 0 < den and num < den
    return -(-(num * S) // den)          # exact ceil, big-int


def scale_up(v, num, den):
    return -(-(v * num) // den)


def power_units(num, den, e):
    v = fraction_units(num, den)
    for _ in range(1, e):
        v = scale_up(v, num, den)
    return v


def native_units(T, dd, L, terms):
    n = 1 << (14 if T == 128 else 15)
    encoded = 4 * n
    regular = 3 * L + 1
    field = fraction_units(terms["lookup"] + terms["sc"] + terms["zc"] + terms["pcs"], F)
    col = power_units(2 * encoded + n + 256, 3 * encoded, 256) * regular
    mask = power_units(2 * 4096 + 2 * 512, 3 * 4096, 256) * L
    return field + col + mask


# --- a bit-exact emulation of the Rust long division (u128 wrap semantics) ---
M128 = S - 1


def rust_fraction_units(num, den):
    if den == 0 or num >= den:
        return None
    rem, q = num, 0
    for _ in range(128):
        carry = rem >> 127
        rem = (rem << 1) & M128
        q = (q << 1) & M128
        if carry != 0 or rem >= den:
            rem = (rem - den) & M128
            q |= 1
    q2 = q + (1 if rem != 0 else 0)
    return None if q2 > M128 else q2


def rust_scale_up(v, num, den):
    whole = (v // den) * num
    tail = (v % den) * num + den - 1
    if whole > M128 or tail > M128:
        return None
    r = whole + tail // den
    return None if r > M128 else r


def decode(hexs):
    raw = bytes.fromhex(hexs)
    assert len(raw) == 160
    head = struct.unpack("<10Q", raw[:80])
    tail = [int.from_bytes(raw[k:k + 16], "little") for k in range(80, 160, 16)]
    keys = ["tier", "blocks", "tokens", "dd", "n", "rate", "q", "mask_n", "mask_dom", "mask_q"]
    d = dict(zip(keys, head))
    d.update(dict(zip(["lookup", "sc", "zc", "pcs", "units"], tail)))
    return d


def bits(x):
    return -math.log2(x.numerator) + math.log2(x.denominator) if isinstance(x, Fraction) else None


def main(log_path, dense_dir, out_path):
    text = open(log_path).read()
    rows = []
    for m in re.finditer(r"R14_SECURITY_MIXED (\{.*\})", text):
        r = json.loads(m.group(1))
        c = decode(r["claim"])
        T, dd, groups = r["tokens"], r["dd"], r["groups"]
        e = expected_terms(T, dd, groups)
        nat = native_units(T, dd, len(groups), c)
        ceil_exact = -(-(e["exact"] * S).numerator // (e["exact"] * S).denominator)
        row = {
            "T": T, "dd": dd, "blocks": len(groups), "groups": f"{groups.count(3)}xG3/{groups.count(4)}xG4",
            "header_ok": (c["tier"], c["blocks"], c["tokens"], c["dd"], c["n"], c["rate"], c["q"],
                          c["mask_n"], c["mask_dom"], c["mask_q"]) == (95, len(groups), T, int(dd), e["n"], 4, 256, 512, 4096, 256),
            "lookup_eq": c["lookup"] == e["lookup"], "sc_eq": c["sc"] == e["sc"], "zc_eq": c["zc"] == e["zc"],
            "pcs_eq": c["pcs"] == e["pcs"], "native_units": c["units"], "python_port_units": nat,
            "port_equal": nat == c["units"], "ceil_exact_units": ceil_exact,
            "conservative": c["units"] >= ceil_exact, "slack_units": c["units"] - ceil_exact,
            "admit_95": c["units"] <= 2**33,
            "N_per_block": e["N"], "byte_per_block": e["byte"], "sc_per_block": e["sc_per"], "zc_per_block": e["zc_per"],
            "slots": e["slots"],
            "exact_bits": -math.log2(float(e["exact"])),
            "rounded_bits": 128 - math.log2(c["units"]),
            "bits_if_erasure_ceil": -math.log2(float(e["exact_pcs_ceil"])),
            "units_if_erasure_ceil_minus_native": -(-(e["exact_pcs_ceil"] * S).numerator // (e["exact_pcs_ceil"] * S).denominator) - ceil_exact,
            "margin_units_to_2^33": 2**33 - c["units"],
        }
        rows.append(row)
    # 1-block dense fixture receipts (G = 2 by construction of the fixture)
    dense = []
    for dd in (0, 1):
        st = open(f"{dense_dir}/dense-{dd}/statement.txt").read()
        c = decode(re.search(r"security=([0-9a-f]+)", st).group(1))
        e = expected_terms(128, bool(dd), [2])
        dense.append({"dd": dd, "lookup_eq_G2": c["lookup"] == e["lookup"], "sc_eq": c["sc"] == e["sc"],
                      "zc_eq": c["zc"] == e["zc"], "pcs_eq": c["pcs"] == e["pcs"],
                      "port_equal": native_units(128, bool(dd), 1, c) == c["units"], "units": c["units"],
                      "bits": 128 - math.log2(c["units"])})
    # Rust long division emulation vs exact ceil, incl. the carry path (den >= 2^127)
    rnd = random.Random(20261031)
    cases = [(0, 3), (1, 2), (1, 3), (F - 1, F), (1, F), (S - 2, S - 1), (2**127, 2**127 + 1), (1, 2**127 + 1)]
    for _ in range(20000):
        den = rnd.randrange(2, S)
        if rnd.random() < 0.5:
            den |= 1 << 127
        num = rnd.randrange(0, den)
        cases.append((num, den))
    div_bad = []
    for num, den in cases:
        exact = -(-(num * S) // den)
        got = rust_fraction_units(num, den)
        if exact > M128:
            if got is not None:
                div_bad.append((num, den, "overflow not refused"))
        elif got != exact:
            div_bad.append((num, den, got, exact))
    scale_bad = 0
    for _ in range(20000):
        den = rnd.randrange(1, 2**20)
        num = rnd.randrange(0, den + 1)
        v = rnd.randrange(0, 2**100)
        if rust_scale_up(v, num, den) != -(-(v * num) // den):
            scale_bad += 1
    # Max admitted block count at each geometry (all-G4, worst case), informational
    max_blocks = {}
    for T in (128, 256):
        for dd in (False, True):
            L = 1
            while L <= 128:
                e = expected_terms(T, dd, [4] * L)
                c = dict(lookup=e["lookup"], sc=e["sc"], zc=e["zc"], pcs=e["pcs"])
                if native_units(T, dd, L, c) > 2**33:
                    break
                L += 1
            max_blocks[f"T{T}{'-DD' if dd else ''}"] = L - 1
    res = {"mixed": rows, "dense_fixture": dense, "long_division_cases": len(cases), "long_division_mismatches": div_bad[:5],
           "scale_up_cases": 20000, "scale_up_mismatches": scale_bad, "max_admitted_blocks_all_G4": max_blocks}
    json.dump(res, open(out_path, "w"), indent=1)
    for r in rows:
        print(f"T{r['T']} dd={int(r['dd'])} hdr={r['header_ok']} eq={r['lookup_eq']}/{r['sc_eq']}/{r['zc_eq']}/{r['pcs_eq']} "
              f"port={r['port_equal']} cons={r['conservative']} slack={r['slack_units']} admit={r['admit_95']} "
              f"exact={r['exact_bits']:.4f} rounded={r['rounded_bits']:.4f} erasure-ceil={r['bits_if_erasure_ceil']:.6f} "
              f"(+{r['units_if_erasure_ceil_minus_native']} units) N={r['N_per_block']:,} sc={r['sc_per_block']} zc={r['zc_per_block']} slots={r['slots']}")
    print(json.dumps(dense))
    print("long division", len(cases), "mismatches", len(div_bad), "| scale_up mismatches", scale_bad)
    print("max admitted blocks (all G4)", max_blocks)


if __name__ == "__main__":
    main(*sys.argv[1:4])
