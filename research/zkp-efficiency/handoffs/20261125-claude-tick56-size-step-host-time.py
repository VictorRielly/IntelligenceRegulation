#!/usr/bin/env python3
"""Tick 56 (queue item 96): where the size step's per-block host time goes.

Reads only the retained spike record (measure.log, small) and does arithmetic.
Counts come from Sol's pinned sources (tower.rs, pcs/switch.rs, pcs/switched.rs,
b6a_spike_host.rs), read by hand; the constants below restate them with the file
and line they come from. Standard library only, under a second.
"""
import re
import statistics as st

LOG = ("/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/"
       "b6a_wp0/qualification-wp0/attempt-00/measure.log")

# ---------------------------------------------------------------- geometry (COUNTED)
N = 1 << 14                    # b6a_spike_host.rs:19 log_n 14
Q = 280                        # b6a_spike_host.rs:20
SRC = [(2501, 36), (2602, 9)]  # source rows, groups (b6a_spike_host.rs:21)
W2_WIDTH, W2_CHECKS = 1024, 120  # :22-23
VECTORS = sum(g + 1 for _, g in SRC)          # 47 (row_weights per source = groups+1)
ROWS = VECTORS + 1                            # W rows, switched.rs:265-269 -> 48
EVALS = sum(g for _, g in SRC)                # 45 vectors with an evaluation check
SWITCH_ROWS = -(-N // W2_WIDTH)               # 16, switched.rs:277
RATES = {"1/8": (8, 138), "1/4": (4, 169), "1/2": (2, 280)}   # (inv_rate, w_checks) spike:20


def bf(n):  # butterflies in one radix-2 NTT of size n
    return (n // 2) * (n.bit_length() - 1)


def pad_pow2(x):
    return 1 << (x - 1).bit_length()


# ---------------------------------------------------------------- the record (MEASURED)
text = open(LOG).read()


def med(pattern, key, rate=None, warm=False):
    out = []
    for line in text.splitlines():
        if not re.search(pattern, line):
            continue
        if rate and f"rate={rate}" not in line:
            continue
        if f"warm={'true' if warm else 'false'}" not in line:
            continue
        m = re.search(key + r"=([0-9.]+)", line)
        if m:
            out.append(float(m.group(1)))
    return st.median(out), len(out)


rec = {}
for r in RATES:
    d = {}
    for k in ["prove_bat_ms", "prove_tower_ms", "verify_bat_ms", "verify_tower_ms",
              "rational_a_ms", "rational_h_ms", "dense_a_ms"]:
        d[k], _ = med("B6A-M34", k, f"{r}")
    for k in ["gpu_ms", "encode_wall_ms", "prep_host_ms", "salt_tree_host_ms"]:
        d[k], _ = med("B6A-M1-METAL", k, f"{r}")
    d["cpu_w_ms"] = float(re.search(rf"B6A-M1-CPU rate={r} elapsed_ms=([0-9.]+)", text).group(1))
    rec[r] = d
absorb, _ = med("B6A-M2", "absorb_host_ms")

print("== 0. The record (medians of the 7 non-warm iterations; MEASURED)")
print(f"legacy absorb (baseline, 12.5 MB, one thread): {absorb:.3f} ms")
for r, d in rec.items():
    print(f"rate {r}: " + ", ".join(f"{k}={v:.3f}" for k, v in d.items()))

# ---------------------------------------------------------------- 1. counts
print("\n== 1. Counts (COUNTED unless said)")
padded = pad_pow2(ROWS) * N
msg_len = ROWS * N
fold1_pairs = padded - N                      # sum of half-lengths while len > N: 2^20 - 2^14
fold1_round_mul = 5 * fold1_pairs             # tower.rs:402-412 -> s2, dot m0c0, dot m1c1, fold x2
fold1_total = fold1_round_mul + msg_len + N   # + initial check dot (tower.rs:390) + final dot (:417)
print(f"W rows {ROWS}, padded extent {padded}, message {msg_len} Fp2 words")
print(f"first fold: rounds {int(round(__import__('math').log2(padded // N)))}, pairs {fold1_pairs}, "
      f"round multiplications {fold1_round_mul}, initial check dot {msg_len}, final dot {N}, "
      f"TOTAL {fold1_total} Fp2 muls (head start: 5,963,776)")
assert fold1_total == 5963776
last_ext = SWITCH_ROWS * W2_WIDTH
last_pairs = pad_pow2(SWITCH_ROWS) * W2_WIDTH - W2_WIDTH
last_total = 5 * last_pairs + last_ext + W2_WIDTH
print(f"last fold: pairs {last_pairs}, Fp2 muls {last_total}")
for r, (inv, m) in RATES.items():
    print(f"switch step at {r}: {m} positions x {N} entries = {m * N} entries; per entry: "
          f"1 Fp mul (power chain, tower.rs:101-106) + 1 generic Fp2 mul (c1 = 0) + 1 Fp2 add (:482-484)")

# W2 commitment (tower.rs:540, Commitment::new :192-235)
w2_pos = W2_WIDTH * 32
w2_nttbf = SWITCH_ROWS * 2 * bf(w2_pos)
w2_words = SWITCH_ROWS * 2 * w2_pos
print(f"W2 commitment: {SWITCH_ROWS} rows x 2 components = {SWITCH_ROWS * 2} NTTs of {w2_pos}, "
      f"{w2_nttbf} butterflies, {w2_words} encoded words ({w2_words * 8 / 1e6:.2f} MB hashed), "
      f"{w2_pos} salts, {w2_pos} salted leaves, {w2_pos - 1} Merkle nodes")

# BAT (switched.rs:306-366, switch.rs:224-281)
bat_mul_gen = VECTORS * (N + Q)                       # switch.rs:254-255 mu*generator
bat_mul_eval = EVALS * N                              # :262-264 eval.coefficient*value
bat_mul_comb = sum(SRC[i][0] * (SRC[i][1] + 1) for i in range(2))   # :250-252
bat_mulbase_dot = sum(Q * SRC[i][0] for i in range(2))                # :269-274
bat_fp2 = bat_mul_gen + bat_mul_eval + bat_mul_comb
print(f"BAT: Fp2 muls: generator scaling {bat_mul_gen}, evaluation columns {bat_mul_eval}, "
      f"combined row weights {bat_mul_comb}, total {bat_fp2}; mul_base (2 Fp muls) in column dots {bat_mulbase_dot}")
print(f"BAT output materialised twice: {VECTORS} vectors x {N + Q} words x 16 B = "
      f"{VECTORS * (N + Q) * 16 / 1e6:.1f} MB, then copied into W ({ROWS * N * 16 / 1e6:.1f} MB) by pack (switched.rs:283-303)")
# rational generator, per source, at m = Q distinct points (switch.rs:105-170)
m = Q
rat_den = m * (m + 1) // 2
rat_num = m * m * 3
rat_pad = m * m * 2
rat_ntt = 3 * bf(N)
rat_inv = 3 * N
rat_fin = 4 * N
print(f"rational generator per source (Fp-mul equivalents): denominator {rat_den}, numerator {rat_num}, "
      f"pads {rat_pad}, 3 NTTs {rat_ntt} butterflies, batch inverse ~{rat_inv}, final map {rat_fin}")

# bridge preparation and host tree (spike m1)
bridge_bf = 2 * ROWS * bf(N)
print(f"bridge prep: pack + clone {VECTORS * (N + Q) * 16 / 1e6:.1f} MB, host forward NTT of {2 * ROWS} rows of {N} "
      f"= {bridge_bf} butterflies on 5 threads (zk60_b6a_spike.rs:59-67)")
for r, (inv, m_) in RATES.items():
    pos = inv * N
    print(f"host salted tree at {r}: {pos} salts, {pos} salted leaves + {pos - 1} nodes = {2 * pos - 1} compressions")

# ---------------------------------------------------------------- 2. rates from this repository
print("\n== 2. Rates (labelled)")
bf_all = {}
for r, (inv, m_) in RATES.items():
    pos = inv * N
    b = 2 * ROWS * bf(pos)
    rate = (rec[r]["cpu_w_ms"] - rec[r]["salt_tree_host_ms"]) * 1e6 / b
    bf_all[r] = rate
    print(f"W commit on the host, {r}: ({rec[r]['cpu_w_ms']:.2f} - tree {rec[r]['salt_tree_host_ms']:.2f}) ms / "
          f"{b} butterflies = {rate:.3f} ns all-in per butterfly (NTT + setup + scatter + hash)  [MEASURED/COUNTED]")
r_w2 = bf_all["1/2"]    # same transform size 32768
tree_pos = {r: rec[r]["salt_tree_host_ms"] * 1e6 / (RATES[r][0] * N) for r in RATES}
print("tree per position: " + ", ".join(f"{r} {v:.1f} ns" for r, v in tree_pos.items()) + "  [MEASURED]")
slope_v = []
rs = list(RATES)
for a, b_ in [("1/8", "1/4"), ("1/4", "1/2"), ("1/8", "1/2")]:
    dm = (RATES[b_][1] - RATES[a][1]) * N
    sv = (rec[b_]["verify_tower_ms"] - rec[a]["verify_tower_ms"]) * 1e6 / dm
    sp = (rec[b_]["prove_tower_ms"] - rec[a]["prove_tower_ms"]) * 1e6 / dm
    slope_v.append(sv)
    print(f"switch-entry slope {a}->{b_}: verifier {sv:.2f} ns/entry, prover {sp:.2f} ns/entry  [MEASURED slopes, COUNTED entries]")
R_ENTRY = 7.7   # ns, verifier slope (single thread, same code as prover), rounded from above
R_MUL = 5.0     # ns per Fp2 mul-and-accumulate, DERIVED below
v18 = rec["1/8"]["verify_tower_ms"]
rem = v18 - 138 * N * R_ENTRY / 1e6
print(f"verifier at 1/8: {v18:.2f} ms - switch {138 * N * R_ENTRY / 1e6:.2f} ms = {rem:.2f} ms remainder for "
      f"{fold1_pairs} coefficient fold pairs plus about 2 ms of small items (ASSUMED) -> "
      f"{(rem - 2.0) * 1e6 / fold1_pairs:.2f} ns per fold pair; upper bound without the 2 ms: {rem * 1e6 / fold1_pairs:.2f} ns")
print(f"Fp2 mul = 5 Fp muls (field.rs:163-169); working figure {R_MUL} ns per Fp2 mul-and-accumulate (range 4.5 to 5.5)  [DERIVED]")

# ---------------------------------------------------------------- 3. model of the two timers
print("\n== 3. Model of prove_tower_ms and prove_bat_ms (DERIVED from counts x the rates above)")
fold_ms = fold1_total * R_MUL / 1e6
w2_ms = w2_nttbf * r_w2 / 1e6 + rec["1/2"]["salt_tree_host_ms"]
misc = 2.0
print(f"first fold {fold_ms:.1f} ms; W2 commitment {w2_ms:.1f} ms ({w2_nttbf * r_w2 / 1e6:.1f} NTT+hash at {r_w2:.2f} ns + "
      f"tree {rec['1/2']['salt_tree_host_ms']:.2f}); misc {misc} ms (canonical scans, resizes, W opening, last fold "
      f"{last_total * R_MUL / 1e6:.2f} ms, last openings; ASSUMED)")
tower_rows = []
for r, (inv, mm) in RATES.items():
    sw = mm * N * R_ENTRY / 1e6
    pred = fold_ms + w2_ms + sw + misc
    meas = rec[r]["prove_tower_ms"]
    tower_rows.append((r, sw, pred, meas))
    print(f"  rate {r}: switch {sw:.1f} + fold {fold_ms:.1f} + W2 {w2_ms:.1f} + misc {misc:.1f} = {pred:.1f} ms "
          f"vs measured {meas:.1f} ms ({100 * (pred / meas - 1):+.1f}%)")
print("  caution: the switch rate and the W2 rate are calibrated on this record; the fold rate is a residual-consistent "
      "figure, so the match is a consistency check, not an independent test.")

bat_fp2_ms = bat_fp2 * R_MUL / 1e6
bat_mb_ms = bat_mulbase_dot * 2.2 / 1e6
bat_rat_ms = rec["1/4"]["rational_a_ms"] + rec["1/4"]["rational_h_ms"]
bat_mem_ms = 2.0
bat_pred = bat_fp2_ms + bat_mb_ms + bat_rat_ms + bat_mem_ms
print(f"BAT at 1/4: Fp2 muls {bat_fp2_ms:.1f} + column dots (mul_base at 2.2 ns, ASSUMED) {bat_mb_ms:.1f} + two rational "
      f"generators {bat_rat_ms:.2f} (MEASURED diagnostics, same function) + memory work {bat_mem_ms:.1f} (ASSUMED) = "
      f"{bat_pred:.1f} ms vs measured {rec['1/4']['prove_bat_ms']:.2f}")
print(f"  the dense generator is NOT in the BAT time: dense_a {rec['1/4']['dense_a_ms']:.1f} ms vs rational "
      f"{rec['1/4']['rational_a_ms']:.2f} ms per source; opening_claim uses MessageBasis::Evaluations -> rational (switch.rs:240-241)")

# ---------------------------------------------------------------- 4. table at rate 1/4
r = "1/4"
d = rec[r]
sw = 169 * N * R_ENTRY / 1e6
rows = [
    ("first fold (tower.rs:382-425)", fold_ms, "serial", "yes, a product sumcheck, see section 6", "inherent in size, cheap on parallel hardware"),
    ("switch step (tower.rs:457-487)", sw, "serial", "no kernel read; host rational form instead (section 5)", "no"),
    ("W2 commitment (tower.rs:191-235)", w2_ms, "NTT row loop serial; hash and Merkle on the pool", "yes, the W commit route", "geometry fixed by the profile"),
    ("BAT (switched.rs:306-366)", bat_pred, "serial (no parallel loop)", "partly; per-vector loops independent", "the Fp2 scalings are inherent, the double copy is not"),
    ("bridge prep (spike:59-67)", d["prep_host_ms"], "NTT on 5 threads, pack serial", "device commit has NTT kernels (unread)", "unknown"),
    ("host salts + salted leaves + tree", d["salt_tree_host_ms"], "leaf map serial, tree parallel", "no", "inherent per position"),
]
print("\n== 4. Where the +99 ms goes at rate 1/4 (5 prover threads)")
tot = 0.0
for name, ms_, ser, dev, inh in rows:
    tot += ms_
    print(f"  {name:38s} {ms_:6.1f} ms  {100 * ms_ / (rows[0][1] + rows[1][1] + rows[2][1] + rows[3][1] + rows[4][1] + rows[5][1]):4.1f}%  | {ser} | {dev} | {inh}")
print(f"  sum of rows {tot:.1f}; minus legacy absorbs {absorb:.2f} = {tot - absorb:.1f}; result.json host_added 99.07; "
      f"sum of medians of measured timers {d['prove_bat_ms'] + d['prove_tower_ms'] + d['prep_host_ms'] + d['salt_tree_host_ms'] - absorb:.2f} "
      f"(+ encode wall minus GPU {d['encode_wall_ms'] - d['gpu_ms']:.2f} = "
      f"{d['prove_bat_ms'] + d['prove_tower_ms'] + d['prep_host_ms'] + d['salt_tree_host_ms'] - absorb + d['encode_wall_ms'] - d['gpu_ms']:.2f})")
cnt = fold_ms + sw + w2_ms + bat_fp2_ms + bat_mb_ms + bat_rat_ms
meas2 = d["prove_bat_ms"] + d["prove_tower_ms"]
print(f"  counted-work share of the 17 + 74 ms: {cnt:.1f} of {meas2:.1f} = {100 * cnt / meas2:.0f}% (pass line: two thirds)")

# ---------------------------------------------------------------- 5. switch step rational form
print("\n== 5. Switch step: rational form (item 3)")
print("  row_j = sum_k w_k x_k^j, j < n, x_k = 7 * omega^pos_k distinct and nonzero (tower.rs:94-108): the first n series")
print("  coefficients of N(T)/Z(T), Z = prod(1 - x_k T) (degree m, Z(0) = 1), N = sum_k w_k prod_{l != k}(1 - x_l T) (degree m-1).")
print("  Same vector over Fp2 exactly, so same proof bytes. Counts: Z and N by the loops of switch.rs:118-140 (m^2 scale), then")
print("  1/Z mod T^n by Newton (about 6 NTTs of 2n = 32768) and N * (1/Z) (1 + 2*2 = 5 NTTs of 32768, N is Fp2).")
ntt_ms = bf(2 * N) * bf_all["1/2"] / 1e6
print(f"  one 32768-NTT at the all-in rate {bf_all['1/2']:.2f} ns = {ntt_ms:.2f} ms (the 16384-NTT is {bf(N) * bf_all['1/2'] / 1e6:.2f})")
rat_small = {}
for r_, (inv, mm) in RATES.items():
    # m^2 loops scaled from the measured rational generator at 280: its time minus its 3 NTTs
    base = rec[r_]["rational_a_ms"] - 3 * bf(N) * bf_all["1/2"] / 1e6
    small = max(base, 0.2) * (mm / 280) ** 2
    t = small + 11 * ntt_ms
    rat_small[r_] = t
    sw_dense = mm * N * R_ENTRY / 1e6
    sw_mb = sw_dense * (3.0 / 6.0)   # mul_base: 3 Fp muls instead of 6 per entry (mul vs mul_base)
    print(f"  {r_}: dense {sw_dense:.1f} ms; with mul_base in place of Fp2::mul (c1 = 0) about {sw_mb:.1f} ms (3 of 6 Fp muls); "
          f"rational form about {t:.1f} ms (11 NTTs {11 * ntt_ms:.1f} + m^2 loops {small:.1f})")

# ---------------------------------------------------------------- 6. device product sumcheck
print("\n== 6. Device time of a degree-2 product sumcheck, 2^20 Fp2 entries, 6 rounds (item 4)")
pairs = [1 << (20 - k) for k in range(1, 7)]
assert sum(pairs) == fold1_pairs
traffic = sum(2 * 16 * (2 * p) for p in pairs) + sum(2 * 16 * p for p in pairs)  # reads of 2 tables + writes of folded
print(f"  pairs per round {pairs}; products 5 per pair = {5 * fold1_pairs}; traffic read+write {traffic / 1e6:.1f} MB "
      f"-> {traffic / 700e9 * 1e3:.2f} ms at K0's 700 GB/s")
cases = {
    "low  (K4 23.5 ps, floor = fast step 0.057 ms)": (23.5e-12, 0.057e-3),
    "mid  (50 ps, floor 0.118 ms = K5 slot 18)": (50e-12, 0.118e-3),
    "high (77.5 ps, floor 0.35 ms = K5 slot 14 rounds 6+)": (77.5e-12, 0.35e-3),
}
dev = {}
for name, (rate, floor) in cases.items():
    t = sum(max(5 * p * rate, floor) for p in pairs) * 1e3
    dev[name] = t
    print(f"  {name}: {t:.2f} ms")
w_gpu = {r: rec[r]["gpu_ms"] for r in RATES}
print(f"  W commit device time (MEASURED, spike M1): " + ", ".join(f"{r} {v:.2f}" for r, v in w_gpu.items()) + " ms")
w2_dev = rec["1/4"]["gpu_ms"] * w2_words / (2 * ROWS * RATES["1/4"][0] * N)
print(f"  W2 on the same route: {w2_words} / {2 * ROWS * RATES['1/4'][0] * N} words of W at 1/4 x {rec['1/4']['gpu_ms']:.2f} ms = {w2_dev:.2f} ms")
for lab, (fold_t, sync, wd) in {"low": (dev[list(cases)[0]], 0.2, 0.885), "mid": (dev[list(cases)[1]], 0.5, 1.18),
                                "high": (dev[list(cases)[2]], 1.0, 1.67)}.items():
    total = wd + fold_t + sync
    print(f"  {lab}: W {wd:.2f} + fold {fold_t:.2f} + hand-back/dispatch {sync:.1f} (ASSUMED; encode wall minus GPU in M1 is "
          f"{rec['1/4']['encode_wall_ms'] - rec['1/4']['gpu_ms']:.2f}) = {total:.2f} ms vs pass 3.0 / kill 6.0 "
          f"({'pass' if total <= 3.0 else 'between' if total < 6.0 else 'kill'}); with W2 on device +{w2_dev:.2f} = {total + w2_dev:.2f}")

# ---------------------------------------------------------------- 7. two exact-output host savings in the fold
print("\n== 7. Savings with identical proof bytes (DERIVED)")
sav_dot = fold1_pairs * R_MUL / 1e6
sav_chk = msg_len * R_MUL / 1e6
print(f"  round[1] = current target - round[0] (verifier already requires round[0] + round[1] = target, tower.rs:445): "
      f"skip dot(m1, c1): {fold1_pairs} muls = {sav_dot:.1f} ms of {fold_ms:.1f}")
print(f"  initial dot(message, coefficients) == target (tower.rs:390) is a prover self-check: {msg_len} muls = {sav_chk:.1f} ms")

# ---------------------------------------------------------------- 8. stacked what-if
print("\n== 8. Stacking every listed change at rate 1/4 (host ms; ASSUMED where marked)")
host = 99.07
steps = [
    ("switch step to rational form", -(sw - rat_small["1/4"])),
    ("fold: skip dot(m1,c1) and the self-check (host; superseded by the next line if the fold moves)", -(sav_dot + sav_chk)),
    ("fold on the device instead (remaining host fold time removed, device time reported in section 6)", -(fold_ms - sav_dot - sav_chk)),
    ("W2 commit on the device (leaves the host tree and about 1 ms of dispatch)", -(w2_nttbf * r_w2 / 1e6) + 1.0),
    ("BAT Fp2 work on 5 threads, ideal 5x (ASSUMED)", -(bat_fp2_ms + bat_mb_ms) * 0.8),
]
cur = host
for name, delta in steps:
    cur += delta
    print(f"  {name:100s} {delta:+7.1f} -> {cur:6.1f}")
print(f"  pass-through ceiling per request at 32 blocks: today {host * 32 / 1e3:.2f} s, stacked {cur * 32 / 1e3:.2f} s "
      f"against the 3.18 s stream period (coordination record); per-block kill line +15 ms")
print(f"  stacked remainder {cur:.1f} ms is above the +15 ms line: bridge {d['prep_host_ms']:.1f}, tree {d['salt_tree_host_ms']:.1f}, "
      f"W2 tree {rec['1/2']['salt_tree_host_ms']:.1f}, switch {rat_small['1/4']:.1f}, BAT and misc remain")
