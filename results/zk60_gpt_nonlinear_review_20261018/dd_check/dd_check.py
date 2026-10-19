"""Adversarial check of DD (per-row division dictionary), REVIEW.md ROUND 2 section R2.4.

Independent of variants.py / variants_r2.py and of the speed plan's layout replica: every count
below is written from the R6 native tree (layout.rs, argument.rs, protocol.rs) by hand.
Pure Python, one thread, well under a second. Run as
    python3 -I -B results/zk60_gpt_nonlinear_review_20261018/dd_check/dd_check.py

Parts
  A  n_E census over the trained door's declared class (e_s in [-8, 8], f_e in [9, 16],
     head_dim 64 / 128): |{0} u outputs|, the size the dictionary's public e column needs.
  B  committed elements / U8 lookups / element-terms at Llama-3-8B T512, row 2^15, today vs DD,
     with and without the new dictionary zero-check slot's claim sites; cap 32 and cap 64.
  C  the LogUp bound with a COMMITTED table side, (N + 2303 + 4 T_DD)/|F|, today vs DD.
  D  toy LogUp over a 61-bit prime: honest DD holds; four cheats (bad P with every slot
     constrained; a gated-off padding slot; no row binding; multiplicities chosen after alpha)
     and the Sum-keyed variant.
  E  honest completeness at the 8B calibration (e_s 2/3/4, f_e 9, head_dim 128, T 512):
     every score entry's (row, mask*E, P) is in its row's dictionary and P equals the
     per-entry floor, bit for bit.
"""
import json
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = {}
P_GOLD = (1 << 64) - (1 << 32) + 1
LOG2_F = 2 * math.log2(P_GOLD)  # |F| = |Fp2| = p^2


def clog2(v):
    return (v - 1).bit_length()


# ---------------------------------------------------------------------------------------------
# A. n_E census (tables_attn.rs:96-104: E = round_half_up(2^fE exp(-d 2^e_s / sqrt(hd))))
# ---------------------------------------------------------------------------------------------
def exp_table(e_s, hd, fe):
    lam = (2.0 ** e_s) / math.sqrt(hd)
    s = 2.0 ** fe
    return [math.floor(s * math.exp(-d * lam) + 0.5) for d in range(256)]


def e_column_size(e_s, hd, fe):
    t = exp_table(e_s, hd, fe)
    return len(set(t) | {0}), (0 in t)


def part_a():
    rows = []
    for hd in (64, 128):
        for fe in range(9, 17):
            for es in range(-8, 9):
                n, has0 = e_column_size(es, hd, fe)
                rows.append(dict(hd=hd, fe=fe, e_s=es, n_col=n, zero_is_output=has0))
    admitted = len(rows)
    fits32 = sum(1 for r in rows if r["n_col"] <= 32)
    fits64 = sum(1 for r in rows if r["n_col"] <= 64)
    no_zero = [r for r in rows if not r["zero_is_output"]]
    # the members the existing exports use (results/*/export*/layer_*/manifest.json tallies)
    used = {
        "8B b6/b7 (T32/T64/T128), hd 128 fE 9": [2, 3, 4],
        "8B pg_rot1_T32 (older), hd 128 fE 9": [1, 2, 4],
        "TinyLlama pg_rot1 / b4, hd 64 fE 9": [1, 2, 3],
        "B6 candidate (a) one-sided score class, layer 1, hd 128 fE 9": [0],
    }
    hdfe = {"8B b6/b7 (T32/T64/T128), hd 128 fE 9": (128, 9), "8B pg_rot1_T32 (older), hd 128 fE 9": (128, 9),
            "TinyLlama pg_rot1 / b4, hd 64 fE 9": (64, 9), "B6 candidate (a) one-sided score class, layer 1, hd 128 fE 9": (128, 9)}
    used_rows = {k: {es: e_column_size(es, *hdfe[k])[0] for es in v} for k, v in used.items()}
    # the largest e_s that still needs more than 32 / 64 slots, per (hd, fe)
    edge = {}
    for hd in (64, 128):
        for fe in range(9, 17):
            over32 = [r["e_s"] for r in rows if r["hd"] == hd and r["fe"] == fe and r["n_col"] > 32]
            over64 = [r["e_s"] for r in rows if r["hd"] == hd and r["fe"] == fe and r["n_col"] > 64]
            edge["hd%d_fe%d" % (hd, fe)] = dict(max_e_s_over_32=max(over32) if over32 else None, max_e_s_over_64=max(over64) if over64 else None)
    OUT["A"] = dict(admitted_members=admitted, fit_cap32=fits32, fit_cap64=fits64, members_without_zero_output=len(no_zero),
                    used=used_rows, edge=edge, max_n_col=max(r["n_col"] for r in rows))
    print("== A. e-column size |{0} u outputs| over the trained class (e_s -8..8, f_e 9..16, hd 64/128) ==")
    print("   members %d; fit cap 32: %d; fit cap 64: %d; largest column %d; members with no 0 output: %d"
          % (admitted, fits32, fits64, OUT["A"]["max_n_col"], len(no_zero)))
    for k, v in used_rows.items():
        print("   %-62s %s" % (k, ", ".join("e_s %d -> %d" % (es, n) for es, n in v.items())))
    for hd in (64, 128):
        first = lambda v: -8 if v is None else v + 1
        print("   hd %d: smallest e_s whose column fits 32 / 64 slots, at fE 9, 12, 16: %s" % (hd, ", ".join(
            "%d / %d" % (first(edge["hd%d_fe%d" % (hd, fe)]["max_e_s_over_32"]), first(edge["hd%d_fe%d" % (hd, fe)]["max_e_s_over_64"]))
            for fe in (9, 12, 16))))


# ---------------------------------------------------------------------------------------------
# B. counts at Llama-3-8B T512, row width 2^15 (layout.rs / shape.rs, written out by hand)
# ---------------------------------------------------------------------------------------------
def counts(dd=False, cap=32, dd_slot_sites=True):
    T, h, hd, kv, d, f_pad, log_n = 512, 32, 128, 8, 4096, 16384, 15
    n = 1 << log_n
    fe, fp = 9, 9
    wrho_s = clog2(T) + fe  # 18
    ls, lp = (wrho_s + 7) // 8, (fp + 1 + 7) // 8  # 3, 2
    ln, top = 4, 0  # D24: norm window 32 bits at 8B -> four limbs, top pin dropped (C-6)
    size = {"T": T, "Ht": h * T, "L": 1 << max(log_n, clog2(16 * T)), "D": T * d, "Q": T * h * hd,
            "Kv": T * kv * hd, "S": h * T * T, "F": T * f_pad, "Tab": 1 << log_n, "DD": h * T * cap}
    rows_of = {k: max(1, v >> log_n) for k, v in size.items()}
    # A planes per domain (layout.rs segment table, at ln = 4, ls = 3, lp = 2)
    a = {"T": 4, "Ht": 2, "L": 2, "D": 4 + 2 * ln + 8 + 2 * ln + 7, "Q": 7, "Kv": 6,
         "S": 5 + lp + 2 * ls, "F": 11, "Tab": 3}
    # U8 lookups per position (lookups_at)
    per_norm = 2 + 2 * (ln + top)
    u8 = {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "Q": 13, "Kv": 12, "F": 9,
          "S": 2 + 2 + (lp + 1) + 2 * (ls + 1)}
    if dd:
        a["S"] = 5  # s8, rsl, zsel, E, P
        u8["S"] = 4  # sym(s8) 2, rsl byte + pin
        a["DD"] = 1 + lp + 2 * ls + 1  # P_dict, p limbs, sigma limbs, rho limbs, multiplicity
        u8["DD"] = (lp + 1) + 2 * (ls + 1)  # 3 + 4 + 4 = 11
    helpers = {k: (v + 1) // 2 for k, v in u8.items()}
    extra_h = {"S": 1, "F": 1, "Tab": 4}  # exp pair, act pair, three table helpers + u
    if dd:
        extra_h["S"] = 2  # exp pair + the tuple lookup
        extra_h["DD"] = 1  # the dictionary's table helper
    hplanes = {k: helpers.get(k, 0) + extra_h.get(k, 0) for k in size}
    # claim sites (argument.rs define, slot by slot; the replica's claim_sites agrees)
    a_sites = 1 + 1 + (4 + 2 * 9) + 2 + 2 + 7 + 2 + 2 + (a["D"] + 2) + (a["Q"] + 1) + (a["Kv"] + 1) + (a["S"] + 2) + a["F"] + 3 + 2
    h_sites = helpers["L"] + helpers["D"] + helpers["Q"] + helpers["Kv"] + hplanes["S"] + hplanes["F"] + 3 + 1
    if dd and dd_slot_sites:
        a_sites += a["DD"] + 1  # every DD plane + Sum read on the leading (h, t) coordinates
        h_sites += hplanes["DD"]
    a_rows = sum(a[k] * rows_of[k] for k in a) + 2 * a_sites + 2
    h_rows = sum(2 * hplanes[k] * rows_of[k] for k in hplanes) + 2 * h_sites + 2
    u8_total = sum(u8[k] * size[k] for k in u8)
    n_lookups = u8_total + size["S"] + size["F"] + (size["S"] if dd else 0)
    terms = {"D": (a["D"] + 2) + helpers["D"], "Q": (a["Q"] + 1) + helpers["Q"], "Kv": (a["Kv"] + 1) + helpers["Kv"],
             "S": (a["S"] + 2) + hplanes["S"], "F": a["F"] + hplanes["F"]}
    if dd:
        terms["DD"] = a["DD"] + 1 + hplanes["DD"]
    eterms = sum(size[k] * terms[k] for k in terms)
    per_entry = {k: dict(A=a.get(k, 0), U8=u8.get(k, 0), H=hplanes.get(k, 0), committed=a.get(k, 0) + 2 * hplanes.get(k, 0))
                 for k in ("S", "DD") if k in a}
    return dict(a_rows=a_rows, h_rows=h_rows, elems=(a_rows + h_rows) * n, u8=u8_total, N=n_lookups, eterms=eterms,
                a_sites=a_sites, h_sites=h_sites, per_entry=per_entry, dd_size=size["DD"] if dd else 0)


def part_b():
    today = counts()
    variants = {
        "DD cap 32, as counted in variants_r2 (no DD-slot sites)": counts(dd=True, dd_slot_sites=False),
        "DD cap 32, with the DD slot's 11 A + 7 H claim sites": counts(dd=True),
        "DD cap 64 (needed if any layer has e_s 0 at hd 128)": counts(dd=True, cap=64),
    }
    OUT["B"] = {"today": today}
    print("== B. Llama-3-8B T512, row 2^15, per block (independent count) ==")
    print("   today: A rows %d, H rows %d, committed %.1f M, U8 %.1f M, N %d, element-terms %.1f M"
          % (today["a_rows"], today["h_rows"], today["elems"] / 1e6, today["u8"] / 1e6, today["N"], today["eterms"] / 1e6))
    assert today["elems"] == 663_257_088 and today["N"] == 323_026_944, "today's anchors (speed plan 663.3 M, check_logup N)"
    for name, v in variants.items():
        d = dict(v)
        d["d_elems_pct"] = 100.0 * (v["elems"] / today["elems"] - 1)
        d["d_u8_pct"] = 100.0 * (v["u8"] / today["u8"] - 1)
        d["d_eterms_pct"] = 100.0 * (v["eterms"] / today["eterms"] - 1)
        OUT["B"][name] = d
        print("   %-56s rows %5d+%5d committed %.1f M (%+.2f%%) U8 %+.1f%% terms %+.1f%%"
              % (name, v["a_rows"], v["h_rows"], v["elems"] / 1e6, d["d_elems_pct"], d["d_u8_pct"], d["d_eterms_pct"]))
    pe = variants["DD cap 32, with the DD slot's 11 A + 7 H claim sites"]["per_entry"]
    print("   per entry: score %s ; dictionary slot %s" % (pe["S"], pe["DD"]))


# ---------------------------------------------------------------------------------------------
# C. LogUp bound with a committed table side
# ---------------------------------------------------------------------------------------------
def part_c():
    today = counts()
    dd = counts(dd=True)
    t_dd = dd["dd_size"]
    t_dd_tight = 32 * 512 * 19  # rows x distinct e values: every slot is a valid quotient of its own (row, e)
    b_today = today["N"] + 2303
    b_dd_naive = dd["N"] + 2303  # the proposal's reading (lookup count only)
    b_dd = dd["N"] + 2303 + 4 * t_dd  # B1: 2 T_DD (degree 2 in beta); B2: + T_DD; B3: + T_DD
    b_dd_tight = dd["N"] + 2303 + 4 * t_dd_tight
    bits = lambda b: LOG2_F - math.log2(b)
    r = dict(N_today=today["N"], N_dd=dd["N"], T_dd=t_dd, block_today=bits(b_today), block_dd_naive=bits(b_dd_naive),
             block_dd=bits(b_dd), block_dd_tight=bits(b_dd_tight), gain_naive=bits(b_dd_naive) - bits(b_today),
             gain=bits(b_dd) - bits(b_today), run32_today=bits(32 * b_today), run32_dd=bits(32 * b_dd),
             refusal_block=LOG2_F - math.log2(t_dd), refusal_run32=LOG2_F - math.log2(32 * t_dd))
    OUT["C"] = r
    print("== C. LogUp per block, (N + 2303 [+ 4 T_DD])/|F|, |F| = p^2 ==")
    print("   today 2^-%.2f | DD lookups only 2^-%.2f (+%.2f bits) | DD with committed table 2^-%.2f (+%.2f bits; tight T_DD 2^-%.2f)"
          % (r["block_today"], r["block_dd_naive"], r["gain_naive"], r["block_dd"], r["gain"], r["block_dd_tight"]))
    print("   32-block union: today 2^-%.2f, DD 2^-%.2f" % (r["run32_today"], r["run32_dd"]))
    print("   new refusal residual (alpha hits a HIDDEN table value): 2^-%.2f per block, 2^-%.2f per 32-block run"
          % (r["refusal_block"], r["refusal_run32"]))


# ---------------------------------------------------------------------------------------------
# D. toy LogUp over a prime field: the identity sum 1/(a - q) - sum m/(a - t) = 0 at random a
# ---------------------------------------------------------------------------------------------
PT = (1 << 61) - 1


def inv(x):
    return pow(x % PT, PT - 2, PT)


def logup_holds(queries, table, mult, alpha):
    s = 0
    for q in queries:
        s = (s + inv(alpha - q)) % PT
    for t, m in zip(table, mult):
        s = (s - m * inv(alpha - t)) % PT
    return s == 0


def toy_instance(rng, rows=6, T=12, cap=8, fe=4, fp=4):
    tab = sorted(set(exp_table(2, 16, fe)) | {0})
    assert len(tab) <= cap
    ecol = tab + [0] * (cap - len(tab))
    inst = []
    for r in range(rows):
        E = [rng.choice(tab) for _ in range(T)]
        E[0] = 1 << fe  # the row maximum has delta 0
        mask = [1 if j <= r * T // rows + 3 else 0 for j in range(T)]
        Sum = sum(m * e for m, e in zip(mask, E))
        inst.append(dict(E=E, mask=mask, Sum=Sum))
    return inst, ecol, fe, fp


def compress(beta, key, e, p, tag):
    return (tag + key + beta * e + beta * beta * p) % PT


def build(inst, ecol, fp, beta, tag, key_by="row", gate_padding=False, cheat=None):
    """queries from the score entries, table = every dictionary slot. cheat: dict(row, j, P_bad)."""
    queries, table, mult = [], [], []
    for r, row in enumerate(inst):
        key = r if key_by == "row" else (row["Sum"] if key_by == "sum" else 0)
        slot_of = {}
        for k, e in enumerate(ecol):
            pd = (e << fp) // row["Sum"]
            table.append(compress(beta, key, e, pd, tag))
            mult.append(0)
            slot_of.setdefault(e, len(table) - 1)
        for j, (m, e) in enumerate(zip(row["mask"], row["E"])):
            me = m * e
            p = (me << fp) // row["Sum"]
            if cheat and cheat["row"] == r and cheat["j"] == j:
                p = cheat["P_bad"]
            queries.append(compress(beta, key, me, p, tag))
            mult[slot_of[me]] += 1
    return queries, table, mult


def part_d(seed=20261019):
    rng = random.Random(seed)
    inst, ecol, fe, fp = toy_instance(rng)
    tag = rng.randrange(PT)
    res = {}
    trials = 20
    # honest
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag)
        ok += logup_holds(q, t, m, alpha)
    res["honest_holds"] = "%d/%d" % (ok, trials)
    # a cheat on one on-support entry: P off by one, every slot constrained; best multiplicities = honest
    r0, j0 = 2, 0
    honest_p = (inst[r0]["E"][j0] << fp) // inst[r0]["Sum"]
    cheat = dict(row=r0, j=j0, P_bad=honest_p + 1)
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, cheat=cheat)
        ok += logup_holds(q, t, m, alpha)
    res["bad_P_all_slots_constrained_passes"] = "%d/%d" % (ok, trials)
    # the same cheat, but padding slots (k >= n_E) carry no division constraint: the prover writes
    # (row, E, P_bad) into one, moves the count there -> the rational identity holds exactly
    n_e = len(set(ecol))
    assert n_e < len(ecol), "the toy needs at least one padding slot"
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, cheat=cheat)
        pad_index = r0 * len(ecol) + (len(ecol) - 1)  # last slot of row r0 is a padding slot
        t[pad_index] = compress(beta, r0, inst[r0]["E"][j0], honest_p + 1, tag)
        m[pad_index] = 1
        honest_slot = r0 * len(ecol) + ecol.index(inst[r0]["E"][j0])
        m[honest_slot] -= 1
        ok += logup_holds(q, t, m, alpha)
    res["bad_P_with_unconstrained_padding_slot_passes"] = "%d/%d" % (ok, trials)
    # no row binding (key 0): a cheat that copies another row's quotient for the same e passes
    rows_same_e = [(ra, rb) for ra in range(len(inst)) for rb in range(len(inst))
                   if ra != rb and (inst[ra]["E"][0] << fp) // inst[ra]["Sum"] != (inst[rb]["E"][0] << fp) // inst[rb]["Sum"]]
    ra, rb = rows_same_e[0]
    p_other = (inst[rb]["E"][0] << fp) // inst[rb]["Sum"]
    cheat2 = dict(row=ra, j=0, P_bad=p_other)
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, key_by="none", cheat=cheat2)
        # move one count from row ra's slot to row rb's slot of the same e (multiplicities are free)
        e0 = inst[ra]["E"][0]
        m[ra * len(ecol) + ecol.index(e0)] -= 1
        m[rb * len(ecol) + ecol.index(e0)] += 1
        ok += logup_holds(q, t, m, alpha)
    res["cross_row_reuse_without_row_key_passes"] = "%d/%d" % (ok, trials)
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, key_by="row", cheat=cheat2)
        e0 = inst[ra]["E"][0]
        m[ra * len(ecol) + ecol.index(e0)] -= 1
        m[rb * len(ecol) + ecol.index(e0)] += 1
        ok += logup_holds(q, t, m, alpha)
    res["cross_row_reuse_with_row_key_passes"] = "%d/%d" % (ok, trials)
    # keyed by Sum instead of row id: honest holds; the bad-P cheat fails
    ok_h = ok_c = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, key_by="sum")
        ok_h += logup_holds(q, t, m, alpha)
        q, t, m = build(inst, ecol, fp, beta, tag, key_by="sum", cheat=cheat)
        ok_c += logup_holds(q, t, m, alpha)
    res["sum_keyed_honest_holds"] = "%d/%d" % (ok_h, trials)
    res["sum_keyed_bad_P_passes"] = "%d/%d" % (ok_c, trials)
    # multiplicities chosen AFTER alpha (e.g. put on H instead of A): one linear equation, always solvable
    ok = 0
    for _ in range(trials):
        beta, alpha = rng.randrange(PT), rng.randrange(PT)
        q, t, m = build(inst, ecol, fp, beta, tag, cheat=cheat)
        resid = (sum(inv(alpha - x) for x in q) - sum(mm * inv(alpha - tt) for tt, mm in zip(t, m))) % PT
        k = r0 * len(ecol)  # adjust any one slot's multiplicity by resid * (alpha - t_k)
        m[k] = (m[k] + resid * (alpha - t[k])) % PT
        ok += logup_holds(q, t, m, alpha)
    res["bad_P_with_multiplicities_after_alpha_passes"] = "%d/%d" % (ok, trials)
    OUT["D"] = res
    print("== D. toy LogUp (p = 2^61 - 1, %d trials each) ==" % trials)
    for k, v in res.items():
        print("   %-48s %s" % (k, v))


# ---------------------------------------------------------------------------------------------
# E. honest completeness at the 8B calibration
# ---------------------------------------------------------------------------------------------
def part_e(seed=7, rows_per_es=96):
    rng = random.Random(seed)
    T, fe, fp, hd = 512, 9, 9, 128
    worst_used = {}
    checked = 0
    for es in (2, 3, 4, 1):
        tab = exp_table(es, hd, fe)
        ecol = sorted(set(tab) | {0})
        for r in range(rows_per_es):
            t = rng.randrange(T)  # query position; causal support j <= t
            scores = [rng.randint(-127, 127) for _ in range(T)]
            mask = [1 if j <= t else 0 for j in range(T)]
            masked = [(s if m else -127) for s, m in zip(scores, mask)]
            mx = max(masked[: t + 1])
            E = [tab[min(255, mx - x)] for x in masked]
            Sum = sum(m * e for m, e in zip(mask, E))
            assert Sum >= (1 << fe)
            dic = {e: (e << fp) // Sum for e in ecol}
            used = set()
            for m, e in zip(mask, E):
                me = m * e
                assert me in dic and dic[me] == (me << fp) // Sum
                assert dic[me] < (1 << (fp + 1))
                used.add(me)
                checked += 1
            worst_used[es] = max(worst_used.get(es, 0), len(used))
    OUT["E"] = dict(entries_checked=checked, worst_distinct_used_per_row_by_e_s=worst_used)
    print("== E. honest completeness, 8B calibration (hd 128, fE 9, T 512, random int8 scores): %d entries bit-exact ==" % checked)
    print("   most distinct (mask*E) values seen in one row, by e_s: %s" % ", ".join("e_s %d: %d" % kv for kv in sorted(worst_used.items())))


if __name__ == "__main__":
    part_a()
    part_b()
    part_c()
    part_d()
    part_e()
    with open(os.path.join(HERE, "dd_check.json"), "w") as fh:
        json.dump(OUT, fh, indent=1, default=str)
    print("wrote dd_check.json")
