"""D24 review R14: whole-run soundness recount, written by the reviewer.

Independent of Sol's full26_count.py. Inputs read:
  * the R14 source as READ (split_layout.rs piece extents and slot list,
    split_wire.rs encoded_len, split_protocol.rs groups, split_endpoint.rs rows),
  * the per-domain byte-lookup counts reviewed at R13 (accuracy_layout.rs is
    byte-identical in R14; R13 review reviewer_bits_r13.py, 144/144 census rows),
  * the 26 public layer manifests of the actual export (silu_groups shape only),
  * Sol's final-census-1 numbers ONLY as a cross-check (never as an input).

Terms per run (union bound, D15 reading; Fp2, |F| = p^2):
  lookup   : sum over blocks (N + 4*T_d - 1)            (R13 review section 4 / CHECK.md 3)
  column   : 79 regular openings * (1 - delta/3)^256 + 26 mask openings * (3/4)^256
             delta = 1 - (n + 256)/(4n)                 (D15 correction, zero-knowledge code)
  sumcheck : sum over blocks sum_slots (main + ext) * degree
  zerocheck: sum over blocks sum_slots (3*(main+ext) + 3) (reviewer allowance, conservative: tau MLE,
             two hosted output points, mu and nu batching, one spare)
  pcs_field: Sol's retained ceiling, carried as is (not derived here)
"""
import json
import math
import sys
from fractions import Fraction

P = 2**64 - 2**32 + 1
F = P * P
ROOT = "/home/victor/IntelligenceRegulation"
EXPORT = ROOT + "/results/zk60_shieldstral_export_20261026/native_low_h24_t128"
CENSUS = ROOT + "/results/zk60_1b_native_20261017/r14/final-census-1/ACCEPTANCE.json"
NATIVE = ROOT + "/results/zk60_1b_native_20261017/r14/full26-native-1/ACCEPTANCE.json"


def lg(x):
    assert x & (x - 1) == 0
    return x.bit_length() - 1


def geometry(T, dd):
    """Shieldstral sizes. D/F are TRUE pieces in R14 (2048+1024, 8192+1024)."""
    log_cols = 14 if T == 128 else 15
    n = 1 << log_cols
    heads, hd, kv, width, hidden, cap = 32, 128, 8, 3072, 9216, 32
    sizes = {
        "L": max(16 * T, n),            # lifted to the row width (P-3)
        "D": T * width,                 # pieces: T*2048 + T*1024 (no pad lanes)
        "Q": T * heads * hd,
        "Kv": T * kv * hd,
        "S": heads * T * T,
        "F": T * hidden,                # pieces: T*8192 + T*1024
    }
    if dd:
        sizes["Dd"] = heads * T * cap
    wrho_s = lg(T) + 9                  # f_e = 9 at every actual layer
    ls = (wrho_s + 7) // 8
    lpp = {"L": 2, "D": 34, "Q": 14, "Kv": 14, "F": 14, "S": 6 if dd else 11 + 2 * ls}
    if dd:
        lpp["Dd"] = 5 + 2 * ls
    return n, sizes, lpp


def lookup_numerator(T, dd, groups):
    n, s, lpp = geometry(T, dd)
    byte = sum(s[d] * lpp[d] for d in lpp)
    exp_q = s["S"]
    act_q = s["F"]
    dd_q = s["S"] if dd else 0
    N = byte + exp_q + act_q + dd_q
    t_dd = s["Dd"] if dd else 0
    Td = 512 + 4096 * groups + t_dd
    return byte, N, Td, N + 4 * Td - 1


def r13_lookup_numerator(T, dd, groups):
    """Same accounting at R13's padded D/F domains (for the R13 -> R14 delta)."""
    n, s, lpp = geometry(T, dd)
    s = dict(s)
    s["D"] = T * 4096
    s["F"] = T * 16384
    byte = sum(s[d] * lpp[d] for d in lpp)
    N = byte + s["S"] + s["F"] + (s["S"] if dd else 0)
    Td = 512 + 4096 * groups + (s["Dd"] if dd else 0)
    return N + 4 * Td - 1


def slots(T, dd):
    """(base, part, main, ext, degree) from split_layout.rs SplitLayout::new, as read."""
    lt, ld, lf = lg(T), lg(2048), lg(8192)
    log = {"T": lt, "L": lg(max(16 * T, 1 << (14 if T == 128 else 15))), "S": lg(32 * T * T),
           "Q": lg(T * 32 * 128), "Kv": lg(T * 8 * 128), "Tab": 14 if T == 128 else 15,
           "Dd": lg(32 * T * 32)}
    out = []
    # legacy BASE_DEGREE (shape.rs:471) + indicator for padded D/F hosts (removed in pieces)
    out += [("SS", "W", lt + ld, 1, 3), ("SSM", "W", lt + ld, 1, 3)]
    out += [("TZC", "W", log["T"], 1, 3), ("LZC", "W", log["L"], 1, 4), ("RS", "W", log["S"], 1, 3)]
    out += [(x, "W", ld, 1, 2) for x in ("QMM", "KMM", "VMM")]
    out += [("SCORE", "W", 3 + 7, 2, 3), ("PV", "W", 3 + lt, 2, 3)]
    out += [("WO", p, lg(4096), 1, 2) for p in ("w", "n")]
    out += [(x, p, ld, 1, 2) for x in ("GMM", "UMM") for p in ("w", "n")]
    out += [("DMM", p, lf, 1, 2) for p in ("w", "n")]
    out += [("DZC", "w", lg(T * 2048), 1, 4), ("DZC", "n", lg(T * 1024), 1, 4)]
    out += [("QZC", "W", log["Q"], 1, 4), ("KVZC", "W", log["Kv"], 1, 4), ("SZC", "W", log["S"], 1, 4)]
    out += [("FZC", "w", lg(T * 8192), 1, 4), ("FZC", "n", lg(T * 1024), 1, 4)]
    out += [("TAB", "W", log["Tab"], 1, 3), ("ZS", "W", log["Tab"], 1, 2)]
    out += [(x, p, lg(T * w), 1, 2) for x in ("IOIN", "IOOUT") for p, w in (("w", 2048), ("n", 1024))]
    if dd:
        out += [("DD", "W", log["Dd"], 1, 4)]
    return out


def column_term(n, regular, masks, q=256, rate=4):
    base = Fraction(2 * n * rate + n + q, 3 * n * rate)
    return regular * base**q + masks * Fraction(3, 4) ** q


def bits(x):
    return -math.log2(float(x))


def main(out_path):
    groups = []
    for k in range(26):
        m = json.load(open(f"{EXPORT}/layer_{k:02d}/manifest.json"))
        g = m["arrays"]["silu_groups"]["shape"][0]
        assert m["constants"]["f_e"] == 9
        groups.append(g)
    census = json.load(open(CENSUS))
    native = json.load(open(NATIVE))
    res = {"groups_per_layer": groups, "variants": []}
    for T in (128, 256):
        n = 1 << (14 if T == 128 else 15)
        for dd in (False, True):
            sl = slots(T, dd)
            sc = sum((m + e) * d for (_, _, m, e, d) in sl)
            zc = sum(3 * (m + e) + 3 for (_, _, m, e, _) in sl)
            per = [lookup_numerator(T, dd, g) for g in groups]
            lookup = sum(p[3] for p in per)
            r13 = sum(r13_lookup_numerator(T, dd, g) for g in groups)
            col = column_term(n, 79, 26)
            erasure = (4 * n - (n + 256)) // 3
            pcs = 79 * (erasure + 1 + 4096) + 26 * (1025 + 4096)
            total = col + Fraction(lookup + 26 * sc + 26 * zc + pcs, F)
            total_author_terms = col + Fraction(lookup + 26 * sc + pcs, F)
            r13_total = col + Fraction(r13 + 26 * sc + pcs, F)
            row = {
                "T": T, "dd": dd, "byte_queries": per[0][0], "N": per[0][1],
                "T_d_G3": 512 + 4096 * 3 + (32 * T * 32 if dd else 0),
                "lookup_numerator": lookup, "sumcheck_numerator_per_block": sc,
                "zerocheck_allowance_per_block": zc, "pcs_ceiling_numerator": pcs,
                "lookup_bits": bits(Fraction(lookup, F)),
                "column_bits": bits(col),
                "pcs_bits": bits(Fraction(pcs, F)),
                "sumcheck_bits": bits(Fraction(26 * sc, F)),
                "zerocheck_bits": bits(Fraction(26 * zc, F)),
                "whole_run_bits_author_terms": bits(total_author_terms),
                "whole_run_bits_with_reviewer_allowance": bits(total),
                "r13_same_accounting_lookup_bits": bits(Fraction(r13, F)),
                "r13_same_accounting_whole_run_bits": bits(r13_total),
                "slots": len(sl),
            }
            # cross-checks against Sol's census (inputs never taken from it)
            base = [r for r in census["inventory"] if r["tokens"] == T and r["dd"] == dd and r["f_e"] == 9][0]
            row["census_byte_queries_match"] = base["byte_queries"] == per[0][0]
            row["census_act_queries_match"] = base["act_queries"] == T * 9216
            cs = [r for r in census["slot_definitions"] if r["base"] == base["base_profile"]]
            row["census_slots_match"] = [(r["main"], r["ext"], r["degree"]) for r in cs] == [(m, e, d) for (_, _, m, e, d) in sl]
            g = [r for r in census["groups"] if r["base"] == base["base_profile"]][0]
            row["census_sc_sum_match"] = g["sc_round_degree_sum"] == sc
            res["variants"].append(row)
    # independent frame-length recount at T128 (split_wire.rs encoded_len as read)
    frames = {}
    for dd in (False, True):
        T, n, q, rate = 128, 1 << 14, 256, 4
        base = [r for r in census["inventory"] if r["tokens"] == T and r["dd"] == dd and r["f_e"] == 9][0]
        cs = [r for r in census["slot_definitions"] if r["base"] == base["base_profile"]]
        g = [r for r in census["groups"] if r["base"] == base["base_profile"]][0]
        vec, path = n + q, lg(n * rate)

        def opening(groups_, rows):
            return (groups_ + 1) * vec * 16 + q * (8 + rows * 8 + 32 + path * 32)
        slot_bytes = sum((1 + (r["main"] + r["ext"]) * (r["degree"] + 1) + r["terminals"]) * 16 for r in cs)
        assert (g["a_groups"], g["h_groups"]) == (56 + 2 * dd, 11 + dd)
        lengths = []
        for k in range(26):
            L = (120 + (32 if k < 25 else 0) + 96 + slot_bytes + 2 * 1024 * 16
                 + q * (8 + base["m_rows"] * 8 + 32 + 12 * 32)
                 + opening(g["a_groups"], base["a_rows"]) + opening(g["h_groups"], base["h_rows"])
                 + opening(2 if k == 0 else 4, 31 if k == 0 else 34)
                 + (opening(2, 31) if k == 25 else 0) + 32)
            lengths.append(L)
        mode = [m for m in native["modes"] if m["dd"] == dd][0]
        logged = [s["bytes"] for s in mode["segments"]]
        frames["dd" if dd else "non-dd"] = {"recounted_total": sum(lengths), "acceptance_total": mode["bytes"],
                                            "all_52_lengths_equal": lengths == logged}
    res["frames"] = frames
    json.dump(res, open(out_path, "w"), indent=1)
    for r in res["variants"]:
        print(f"T{r['T']} dd={int(r['dd'])} N={r['N']:,} lookup 2^-{r['lookup_bits']:.4f} col 2^-{r['column_bits']:.3f} "
              f"sc 2^-{r['sumcheck_bits']:.1f} zc 2^-{r['zerocheck_bits']:.1f} pcs 2^-{r['pcs_bits']:.1f} | "
              f"run {r['whole_run_bits_author_terms']:.4f} (+allowance {r['whole_run_bits_with_reviewer_allowance']:.4f}) "
              f"| R13 same accounting {r['r13_same_accounting_whole_run_bits']:.4f} | census "
              f"{r['census_byte_queries_match']}/{r['census_act_queries_match']}/{r['census_slots_match']}/{r['census_sc_sum_match']}")
    print(json.dumps(frames))


if __name__ == "__main__":
    main(sys.argv[1])
