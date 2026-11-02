#!/usr/bin/env python3
"""Independent re-check of results/zk60_w16r2_20261101/ACCOUNTING.md (D59 condition 2).

Written 2026-11-02 by the re-checker. It does NOT import count.py. Every input is either
  (a) derived here from the shape parameters by replicating the Rust rules read in
      hashline/src/private_block/shape.rs (Shape::natural_log, domain_log_at, Shape::slots,
      BASE_DEGREE, INDICATOR_SLOT_DOMAIN) and accuracy_layout.rs (lookups_w16), or
  (b) a protocol constant read in the code (zk.rs MASK_*, ZkOpts::standard q_pad = Q,
      W16R2_INV_RATE / W16R2_OPENED_COLS / W16R2_LOG_COLS), or
  (c) a carried convention (the 4096 PCS ceiling, the LogUp (N + 4 T_d - 1) form, G = 4),
and the code-printed W16R2-ACCOUNTING lines are parsed by an independent parser and compared
with (a)/(b).

Arithmetic: exact rationals (fractions.Fraction); log2 is taken once at the end through a
bit-length normalisation (not math.log2 of the two big integers, which is what count.py does).

Usage:  python3 accounting_recheck.py [<log with W16R2-ACCOUNTING lines>]
"""
import math
import re
import sys
from fractions import Fraction as F

P = 2**64 - 2**32 + 1          # Goldilocks
FP2 = P * P                     # |Fp2|
CEIL = 4096                     # carried PCS ceiling per opening (REVIEW_R14 A5)
G = 4                           # activation groups, conservative (REVIEW_W16 s.1)
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256   # zk.rs:373-375


def log2q(x: F) -> float:
    """log2 of a positive rational, via bit-length normalisation (independent of count.py's method)."""
    a, b = x.numerator, x.denominator
    k = a.bit_length() - b.bit_length()
    y = F(a, b) / (F(2) ** k) if k >= 0 else F(a, b) * (F(2) ** (-k))
    return k + math.log2(float(y))


def clog2(v):
    return (v - 1).bit_length()


# ---------------------------------------------------------------- per-opening terms
def ud_opening(n, inv_rate, q):
    """D59 / BCIKS20 Thm 3.1 at delta_t = (1 - K/N)/2, K = n + q_pad, q_pad = Q (ZkOpts::standard)."""
    N, K = n * inv_rate, n + q
    e = (N - K) // 2
    col = F(N - (e + 1), N) ** q
    col_cont = (F(N + K, 2 * N)) ** q            # (1 - delta_t)^Q, the non-integer form
    field = F(N + CEIL, FP2)                     # N/|Fp2| (Thm 3.1's eps) + carried ceiling
    return dict(N=N, K=K, e=e, col=col, col_cont=col_cont, field=field)


def gc_opening(n, inv_rate, q):
    """D15 / Ligero delta/3, delta = 1 - K/N."""
    N, K = n * inv_rate, n + q
    e = (N - K) // 3                             # floor(delta N / 3)
    col = F(2 * N + K, 3 * N) ** q
    field = F(e + 1 + CEIL, FP2)
    return dict(N=N, K=K, e=e, col=col, field=field)


def mask_opening():
    """M: RS(2*512, 4096) under delta/3 (RECOUNT s.2), MASK_Q columns."""
    N, K = 1 << MASK_LOG_DOM, 2 * (1 << MASK_LOG_MSG)
    e = (N - K) // 3
    col = F(2 * N + K, 3 * N) ** MASK_Q
    field = F(e + 1 + CEIL, FP2)
    return dict(N=N, K=K, e=e, col=col, field=field)


# ---------------------------------------------------------------- the shape replica
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]  # 23 non-DD slots
SLOT = dict(SS=0, SSM=1, TZC=2, LZC=3, RS=4, QMM=5, KMM=6, VMM=7, SCORE=8, PV=9, WO=10, GMM=11, UMM=12, DMM=13,
            DZC=14, QZC=15, KVZC=16, SZC=17, FZC=18, TAB=19, ZS=20, IO_IN=21, IO_OUT=22)
CUBE = {SLOT[k]: d for k, d in [("SS", "D"), ("SSM", "D"), ("DZC", "D"), ("IO_IN", "D"), ("IO_OUT", "D"), ("TZC", "T"),
                                 ("LZC", "L"), ("RS", "S"), ("SZC", "S"), ("QZC", "Q"), ("KVZC", "Kv"), ("FZC", "F"),
                                 ("TAB", "Tab"), ("ZS", "Tab")]}
INDICATOR = {SLOT["SS"]: "D", SLOT["SSM"]: "D", SLOT["RS"]: "S", SLOT["DZC"]: "D", SLOT["QZC"]: "Q",
             SLOT["KVZC"]: "Kv", SLOT["SZC"]: "S", SLOT["FZC"]: "F"}


class Shape:
    def __init__(self, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols):
        self.t, self.w, self.f, self.h, self.hd, self.kv, self.lc = tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols
        self.tp, self.dp, self.hp, self.fp = [1 << clog2(x) for x in (tokens, width, q_heads, hidden)]

    def natural_log(self, d):
        return {"T": clog2(self.tp), "Ht": clog2(self.hp * self.tp), "L": clog2(16 * self.tp),
                "D": clog2(self.tp * self.dp), "Q": clog2(self.tp * self.hp * self.hd),
                "Kv": clog2(self.tp * self.kv * self.hd), "S": clog2(self.hp * self.tp * self.tp),
                "F": clog2(self.tp * self.fp), "Tab": clog2(256)}[d]

    def log(self, d):  # domain_log_at: the P-3 lift for every domain but T and Ht
        nat = self.natural_log(d)
        return self.lc if (d not in ("T", "Ht") and nat < self.lc) else nat

    def size(self, d):
        return 1 << self.log(d)

    def true_size(self, d):
        return {"D": self.t * self.w, "Q": self.t * self.h * self.hd, "Kv": self.t * self.kv * self.hd,
                "S": self.h * self.t * self.t, "F": self.t * self.f}[d]

    def slots(self):
        lkv = clog2(self.kv)
        inner = {SLOT["QMM"]: clog2(self.dp), SLOT["KMM"]: clog2(self.dp), SLOT["VMM"]: clog2(self.dp),
                 SLOT["GMM"]: clog2(self.dp), SLOT["UMM"]: clog2(self.dp), SLOT["WO"]: clog2(self.hp * self.hd),
                 SLOT["SCORE"]: lkv + clog2(self.hd), SLOT["PV"]: lkv + clog2(self.tp), SLOT["DMM"]: clog2(self.fp)}
        out = []
        for s in range(23):
            main = self.log(CUBE[s]) if s in CUBE else inner[s]
            ind = s in INDICATOR and self.size(INDICATOR[s]) != self.true_size(INDICATOR[s])
            ext = 2 if s in (SLOT["SCORE"], SLOT["PV"]) else 1
            geq = s in (SLOT["SCORE"], SLOT["PV"]) and lkv > 0
            out.append((main, ext, BASE_DEGREE[s] + int(ind) + int(geq)))
        return out

    def sumcheck(self):
        return sum((m + e) * d for m, e, d in self.slots())

    def zerocheck(self):
        return sum(3 * (m + e) + 3 for m, e, d in self.slots())

    def lookup_words(self, s_count=7):
        # lookups_w16 at T128 (accuracy_layout.rs:289-344, REVIEW_W16 s.1): L 2, D 19, Q 6, Kv 6, S 7, F 7
        per = {"L": 2, "D": 19, "Q": 6, "Kv": 6, "S": s_count, "F": 7}
        return sum(c * self.size(d) for d, c in per.items())


SH_8B = Shape(128, 4096, 14336, 32, 128, 8, 14)
SH_SS = Shape(128, 3072, 9216, 32, 128, 8, 14)
SH_RUNG = Shape(32, 384, 768, 16, 64, 8, 14)

FAMILIES_T128 = [(2, 1), (4, 1), (5, 1), (7, 1), (12, 1), (13, 1), (15, 2), (16, 4)]
FAMILIES_RUNG = [(1, 1)] + FAMILIES_T128


def range_entries(fams):
    return sum(1 << w for w in sorted({w for w, _ in fams}))


# ---------------------------------------------------------------- the profiles
PROFILES = {
    # name: (regime, shape, inv_rate, Q, L list, families, lookup S-count)
    "W16R2_8B_T128_H24": ("UD", SH_8B, 2, 260, [32], FAMILIES_T128, 7),
    "W16_8B_T128_H24": ("GC", SH_8B, 4, 256, [32], FAMILIES_T128, 7),
    "W16R2_SHIELD_T128_H24": ("UD", SH_SS, 2, 260, [26], FAMILIES_T128, 7),
    "W16_SHIELD_T128_H24": ("GC", SH_SS, 4, 256, [26], FAMILIES_T128, 7),
    "W16R2_RUNG_H24": ("UD", SH_RUNG, 2, 260, [1, 3], FAMILIES_RUNG, 9),
    "W16_RUNG_H24": ("GC", SH_RUNG, 4, 256, [1, 3], FAMILIES_RUNG, 9),
}


def block_terms(sh, fams, s_count):
    lw = sh.lookup_words(s_count)
    exp, act = sh.size("S"), sh.size("F")
    n_lk = lw + exp + act
    t_d = 256 + 256 + 4096 * G + range_entries(fams)
    return dict(lookup_words=lw, exp=exp, act=act, N_lk=n_lk, T_d=t_d,
                logup=F(n_lk + 4 * t_d - 1, FP2), sumcheck=F(sh.sumcheck(), FP2), zerocheck=F(sh.zerocheck(), FP2),
                sc=sh.sumcheck(), zc=sh.zerocheck())


def opening(regime, n, inv_rate, q):
    return ud_opening(n, inv_rate, q) if regime == "UD" else gc_opening(n, inv_rate, q)


def run_terms(name, L, column_mult=1, ceil=CEIL):
    regime, sh, ir, q, _, fams, sc = PROFILES[name]
    o = opening(regime, 1 << sh.lc, ir, q)
    m = mask_opening()
    b = block_terms(sh, fams, sc)
    reg = 3 * L + 1
    field_reg = o["field"] - F(CEIL, FP2) + F(ceil, FP2)
    field_m = m["field"] - F(CEIL, FP2) + F(ceil, FP2)
    t = dict(column=reg * column_mult * o["col"] + L * m["col"], pcs_field=reg * field_reg + L * field_m,
             logup=L * b["logup"], sumcheck=L * b["sumcheck"], zerocheck=L * b["zerocheck"])
    return t, sum(t.values()), reg


# ---------------------------------------------------------------- the code-printed inputs
def parse(path):
    got = {}
    for line in open(path, errors="replace"):
        if "W16R2-ACCOUNTING" not in line:
            continue
        name = re.search(r'"name":"([^"]+)"', line).group(1)
        rec = {k: v for k, v in re.findall(r'"([A-Za-z_0-9]+)":(-?[0-9.]+)', line)}
        rec["regime"] = re.search(r'"regime":"([A-Za-z]+)"', line).group(1)
        rec["range_families"] = [tuple(int(x) for x in t) for t in re.findall(r"\((\d+), (\d+)\)", line)]
        got[name] = rec
    return got


def check_inputs(path):
    got = parse(path)
    bad = []
    for name, (regime, sh, ir, q, _, fams, sc) in PROFILES.items():
        d = got[name]
        n = 1 << sh.lc
        b = block_terms(sh, fams, sc)
        want = {
            "regime": "UniqueDecoding" if regime == "UD" else "GeneralCode",
            "log_cols": sh.lc, "n": n, "inv_rate": ir, "N": n * ir, "Q": q, "q_pad": q, "K": n + q,
            "e_unique": (n * ir - n - q) // 2, "endpoint_log_n": sh.lc, "endpoint_inv_rate": ir,
            "m_rows": 2 * 23 + 4, "mask_log_dom": MASK_LOG_DOM, "mask_log_msg": MASK_LOG_MSG, "mask_q": MASK_Q,
            "lookup_words": b["lookup_words"], "exp_queries": b["exp"], "act_queries": b["act"],
            "range_entries": range_entries(fams), "slots": 23,
            "sumcheck_main_ext_degree": b["sc"], "zerocheck_allowance": b["zc"],
            "range_families": fams,
        }
        for k, v in want.items():
            have = d[k] if k in ("regime", "range_families") else int(d[k])
            if have != v:
                bad.append(f"{name}.{k}: code prints {have}, re-check derives {v}")
        o = opening(regime, n, ir, q)
        for k in ("column_log2", "endpoint_column_log2"):
            if abs(float(d[k]) - log2q(o["col"])) > 5e-5:
                bad.append(f"{name}.{k}: code prints {d[k]}, re-check {log2q(o['col']):.4f}")
    return got, bad


def main():
    out = []
    pr = lambda s="": out.append(s)
    if len(sys.argv) > 1:
        got, bad = check_inputs(sys.argv[1])
        pr(f"[inputs] {len(got)} code-printed profiles parsed; mismatches against the re-check's derivation: {len(bad)}")
        for b_ in bad:
            pr("   MISMATCH " + b_)
        rows = {k: (got[k]["a_rows"], got[k]["h_rows"], got[k]["endpoint_rows"]) for k in got}
        pr(f"[inputs] rows (code, not re-derived; they enter only the bias and the bytes): {rows}")

    n = 1 << 14
    pr("\n== 1. per regular opening at n = 2^14, N = 2^15 (rate 1/2), unique decoding, q_pad = Q")
    pr(f"{'Q':>4} {'K':>6} {'e':>5} {'col (exact)':>12} {'col (1-dt)^Q':>13} {'field':>9} {'col+field':>10}")
    w16 = gc_opening(n, 4, 256)
    w16_tot = log2q(w16["col"] + w16["field"])
    for q in range(256, 263):
        o = ud_opening(n, 2, q)
        pr(f"{q:>4} {o['K']:>6} {o['e']:>5} {log2q(o['col']):>12.4f} {log2q(o['col_cont']):>13.4f} {log2q(o['field']):>9.3f} {log2q(o['col'] + o['field']):>10.4f}"
           + ("   <- W16R2" if q == 260 else "") + ("   (>= W16)" if log2q(o['col'] + o['field']) <= w16_tot else "   (short of W16)"))
    pr(f"W16 (rate 1/4, Q 256, delta/3): K {w16['K']}, e {w16['e']}, col {log2q(w16['col']):.4f}, field {log2q(w16['field']):.3f}, total {w16_tot:.4f}")
    m = mask_opening()
    pr(f"M (RS(1024, 4096), MASK_Q 256, delta/3): e {m['e']}, col {log2q(m['col']):.4f}, field {log2q(m['field']):.3f}, total {log2q(m['col'] + m['field']):.4f}")
    qmin_col = min(q for q in range(250, 300) if log2q(ud_opening(n, 2, q)["col"]) <= log2q(w16["col"]))
    qmin_tot = min(q for q in range(250, 300) if log2q(sum((ud_opening(n, 2, q)[k] for k in ("col", "field")), F(0))) <= w16_tot)
    pr(f"minimum Q keeping W16's figure: column-only {qmin_col}, column+field {qmin_tot}")

    pr("\n== 2. per block (derived from the shape replica)")
    for name in ("W16R2_8B_T128_H24", "W16R2_SHIELD_T128_H24", "W16R2_RUNG_H24"):
        _, sh, _, _, _, fams, sc = PROFILES[name]
        b = block_terms(sh, fams, sc)
        pr(f"{name:<24} lookups {b['lookup_words']:,} exp {b['exp']:,} act {b['act']:,} N_lk {b['N_lk']:,} T_d {b['T_d']:,} "
           f"LogUp {log2q(b['logup']):.3f} | sum(main+ext)deg {b['sc']} -> {log2q(b['sumcheck']):.3f} | zero-check {b['zc']} -> {log2q(b['zerocheck']):.3f}")
    pr("   8B vs Shieldstral sumcheck: +60 = three D-domain indicator slots (SS, SSM, DZC: (19+1) each) because d = 3072 pads to 4096")
    pr(f"   slots 8B {SH_8B.slots()}")
    pr("   rung lookups: S-count 9, not 7 (inferred: wrho_s = 17 there, so SR and SG are two-limb; the (1, 1) family is their top limb)")

    pr("\n== 3. whole run (3L + 1 regular openings, L M openings, L blocks), log2")
    pr(f"{'profile':<24} {'L':>3} {'reg':>4} {'column':>9} {'pcs fld':>9} {'logup':>9} {'sumchk':>9} {'zerochk':>9} {'WHOLE':>9}")
    whole = {}
    for name, v in PROFILES.items():
        for L in v[4]:
            t, tot, reg = run_terms(name, L)
            whole[(name, L)] = tot
            pr(f"{name:<24} {L:>3} {reg:>4} " + " ".join(f"{log2q(t[k]):>9.3f}" for k in ("column", "pcs_field", "logup", "sumcheck", "zerocheck")) + f" {log2q(tot):>9.3f}")
    for r2, w in (("W16R2_8B_T128_H24", "W16_8B_T128_H24"), ("W16R2_SHIELD_T128_H24", "W16_SHIELD_T128_H24"), ("W16R2_RUNG_H24", "W16_RUNG_H24")):
        for L in PROFILES[r2][4]:
            pr(f"   {r2} L{L}: {-log2q(whole[(r2, L)]):.3f} vs W16 {-log2q(whole[(w, L)]):.3f} ({log2q(whole[(w, L)]) - log2q(whole[(r2, L)]):+.3f} bit); margin over 95: {-log2q(whole[(r2, L)]) - 95:+.3f}")

    pr("\n== 4. the lemma check's s.6 row #1, reproduced with ITS per-opening form ((1 - delta_t)^Q)")
    o = ud_opening(n, 2, 260)
    col_cont = 97 * o["col_cont"] + 32 * m["col"]
    col_exact = 97 * o["col"] + 32 * m["col"]
    pr(f"   column term, 97 regular + 32 M: (1-dt)^Q form {log2q(col_cont):.3f}; exact integer form {log2q(col_exact):.3f}")

    pr("\n== 5. sensitivities (8B T128, L 32)")
    base = log2q(run_terms("W16R2_8B_T128_H24", 32)[1])
    t2 = log2q(run_terms("W16R2_8B_T128_H24", 32, column_mult=2)[1])
    t0 = log2q(run_terms("W16R2_8B_T128_H24", 32, ceil=0)[1])
    t100 = log2q(run_terms("W16R2_8B_T128_H24", 32, ceil=409600)[1])
    pr(f"   as counted: {base:.3f}")
    pr(f"   far + close halves ADDED per opening (no exclusivity, i.e. without refinement 1): {t2:.3f}")
    pr(f"   carried 4096 ceiling dropped: {t0:.3f}; ceiling x100: {t100:.3f}")
    bias = F(2 * 2606 * P, 2**128)
    pr(f"   row-weight reduction bias (1 + p/2^128)^(2m) - 1 ~ 2m p / 2^128 at m = 2606: 2^{log2q(bias):.2f}")
    pr(f"   powers of one challenge instead (Thm 1.6): (m - 1) N / |Fp2| at m = 2606: 2^{log2q(F(2605 * 2**15, FP2)):.2f} per opening")
    mt = F(36, FP2)  # M's theta combination of up to 36 functionals (powers of theta), not separately itemised
    pr(f"   M's theta batching of <= 36 functionals per block (powers of one theta), not itemised: 32 x 36/|Fp2| = 2^{log2q(32 * mt):.2f}")

    pr("\n== 6. D27's named workload (8B T512, R13 layout, MEMO_G02 s.2 terms) -- carried figure cross-check")
    n15 = 1 << 15
    lu, sc = 2.0 ** -94.73, 2.0 ** -112.19  # MEMO_G02 s.2: LogUp (derived) and sumcheck run totals, carried
    for label, reg_o in (("today rate 1/4 Q 256 delta/3", gc_opening(n15, 4, 256)), ("rate 1/2 Q 258 delta/2", ud_opening(n15, 2, 258)), ("rate 1/2 Q 260 delta/2", ud_opening(n15, 2, 260))):
        col = 97 * reg_o["col"] + 32 * m["col"]
        fld = 97 * reg_o["field"] + 32 * m["field"]
        tot = float(col + fld) + lu + sc
        pr(f"   {label:<30} per opening {log2q(reg_o['col']):.3f}; column {log2q(col):.3f}; field {log2q(fld):.3f}; whole {math.log2(tot):.3f}")

    pr("\n== 7. what the in-tree token / classifier counters (token_io.rs hiding_opening_log2, delta/3 only) would price a W16R2 opening at")
    gc_r2 = gc_opening(n, 2, 260)
    pr(f"   (1 - delta/3)^260 at rate 1/2: {log2q(gc_r2['col']):.3f} per opening; 97 of them {log2q(97 * gc_r2['col']):.3f} (a D27 policy gate on that figure fails closed)")

    print("\n".join(out))


if __name__ == "__main__":
    main()
