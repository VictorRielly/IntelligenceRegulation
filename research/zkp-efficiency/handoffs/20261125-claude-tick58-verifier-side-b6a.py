#!/usr/bin/env python3
"""Tick 58 (queue item 98): the verifier's side of the size step (B6a), per request.

Reads only retained records (spike measure.log files, the D55 A/B log's verifier lines) and does arithmetic.
Standard library, well under a second. Every figure is labelled MEASURED (record), COUNTED (file:line, in the
handoff), DERIVED (arithmetic here) or ASSUMED.
"""
import re
import statistics as st

ROOT = "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/b6a_wp0/"
LOGS = {
    "as_pinned": ROOT + "qualification-wp0/attempt-00/measure.log",
    "hostfix": ROOT + "qualification-wp0-hostfix/attempt-00/measure.log",
}
RATE_CHECKS = {"1/8": 138, "1/4": 169, "1/2": 280}  # w_checks per rate, tick 56 section 2


def medians(path):
    rows = {}
    pat = re.compile(r"B6A-M34 rate=(\S+) iteration=(\d+) warm=(\w+) .*verify_bat_ms=([\d.]+) verify_tower_ms=([\d.]+)")
    for line in open(path):
        m = pat.search(line)
        if m and m.group(3) == "false":
            rows.setdefault(m.group(1), []).append((float(m.group(4)), float(m.group(5))))
    return {r: (st.median(a for a, _ in v), st.median(b for _, b in v), len(v)) for r, v in rows.items()}


M = {k: medians(v) for k, v in LOGS.items()}
print("== 1. Spike verifier medians, one thread, per block (MEASURED; warm=false iterations)")
print("build        rate   bat_ms  tower_ms  sum_ms   n")
S = {}
for build, d in M.items():
    for rate in ("1/8", "1/4", "1/2"):
        b, t, n = d[rate]
        S[(build, rate)] = b + t
        print(f"{build:11s}  {rate}  {b:7.2f}  {t:8.2f}  {b+t:7.2f}  {n}")

print()
print("== 2. Tower verifier = fold replay + switch step + remainder (DERIVED; tick 56 rates)")
NS_ENTRY = 7.7e-6  # ms per entry, tick 56 section 3 (verifier slope MEASURED 7.7 to 7.8 ns)
FOLD_PAIRS = 1_032_192  # tick 56 section 2 (COUNTED)
FOLD_NS = 5.0e-6  # ms per Fp2 multiplication, tick 56 working figure
rational = {"1/8": 6.1, "1/4": 6.3, "1/2": 7.0}  # tick 56 section 4 (DERIVED there)
mulbase = {"1/8": 8.7, "1/4": 10.7, "1/2": 17.7}
TOWER = {}
for rate, checks in RATE_CHECKS.items():
    switch = checks * 16384 * NS_ENTRY * 1e3 / 1e3  # ms
    switch = checks * 16384 * 7.7e-6
    fold = FOLD_PAIRS * FOLD_NS
    meas = M["as_pinned"][rate][1]
    rest = meas - switch - fold
    TOWER[rate] = (switch, fold, rest, meas)
    print(f"{rate}: switch {switch:5.1f} + fold replay {fold:4.1f} + remainder {rest:4.1f} = {meas:5.1f} measured")
print("The remainder (BASE, openings, canonical checks, eq tables) is 2.2 to 2.6 ms at every rate: the model hangs together.")

print()
print("== 3. Tick 56's changes against the verifier (DERIVED)")
print("Verifier's tower after the rational switch row / after mul_base alone; BAT as measured on the hostfix build")
S_RAT, S_MB = {}, {}
for rate in RATE_CHECKS:
    switch, fold, rest, meas = TOWER[rate]
    t_rat = meas - switch + rational[rate]
    t_mb = meas - switch + mulbase[rate]
    bat = M["hostfix"][rate][0]
    S_RAT[rate] = bat + t_rat
    S_MB[rate] = bat + t_mb
    print(f"{rate}: tower {meas:5.1f} -> {t_rat:5.1f} (rational) / {t_mb:5.1f} (mul_base); BAT+tower {bat+meas:5.1f} -> {S_RAT[rate]:5.1f} / {S_MB[rate]:5.1f}")

print()
print("== 4. Today's verifier (MEASURED, a12merge_d55_ab.log lines 227, 232, 237, 245)")
T1 = 4.54  # s, D12a verifier, ONE thread, 32 blocks, receipt 818,728,480 B
T6 = (2.31, 2.33, 2.32)  # s, D55 verifier, 6 threads, 32 blocks
T6m = st.median(T6)
L8 = 32
t0 = T1 / L8 * 1e3
print(f"one thread: {T1} s / {L8} = {t0:.1f} ms a block; six threads: {T6m} s = {T6m/L8*1e3:.1f} ms a block of wall")
print(f"six-thread speed-up on today's record: x{T1/T6m:.2f} (two different verifiers, D12a and D55: a caution)")
model_cpu = 2.31 * 6 / 32 * 1e3
print(f"W16R3 study 3.3 calibration: 2.31 s x 6 / 32 = {model_cpu:.0f} ms CPU a block; one-thread record says {t0:.0f}: x{model_cpu/t0:.2f} too high")
amdahl = ((T6m / T1) - 1 / 6) / (1 - 1 / 6)
print(f"Amdahl serial fraction if both runs were the same program: {amdahl:.2f} ({amdahl*T1:.2f} s of the one-thread {T1} s). DERIVED, not established")

print()
print("== 5. What B6a removes from today's block, from counts x measured rates (DERIVED)")
# rate of an Fp multiplication inside BAT: verifier BAT (as pinned, 1/4) minus two rational generators (1.85 ms each)
fp2_mul, mul_base_n = 1_639_045, 1_428_840  # tick 56 section 2 (COUNTED)
fp_mul_eq = fp2_mul * 5 + mul_base_n * 2
bat_products_ms = M["as_pinned"]["1/4"][0] - 2 * 1.85
rate_ns = bat_products_ms * 1e6 / fp_mul_eq
print(f"BAT body {bat_products_ms:.1f} ms over {fp_mul_eq/1e6:.1f} M Fp-multiplication equivalents = {rate_ns:.2f} ns each (includes adds and memory)")
products = 33.2e6  # W16R3 study 3.3, column products a block today
prod_lo, prod_hi = products * 2 * 0.8e-6, products * 2 * 1.4e-6  # ms, 0.8 to 1.4 ns per Fp multiplication
prod_mid = products * 2 * rate_ns * 1e-6
ntt_points = 3.08e6
bfly_lo, bfly_hi = ntt_points * 8 * 1.1e-6, ntt_points * 8 * 2 * 2.1e-6  # one component at 1.1 ns to two components at 2.1 ns
absorb = 6.1161 * 1.0  # ms, MEASURED baseline_absorb_ms for 12.5 MB in result.json
hash_ms = 12.0 / 12.5 * 6.1161 + 0.5  # 12.0 MB at the same rate plus paths and salted leaves (ASSUMED 0.5)
print(f"column products 33.2 M x 2 Fp mul: {prod_mid:.0f} ms (range {prod_lo:.0f} to {prod_hi:.0f})")
print(f"NTT re-encode 3.08 M points x 8 butterflies per point: {bfly_lo:.0f} to {bfly_hi:.0f} ms")
print(f"transcript absorb of the 47 vectors, 12.5 MB: {absorb:.1f} ms (MEASURED; the spike's 'legacy absorbs' saved 6.16 ms)")
print(f"column hashing that stays, 12.0 MB: {hash_ms:.1f} ms (rate of the absorb record; paths ASSUMED 0.5)")
rem_lo = prod_mid + bfly_lo + absorb
rem_hi_raw = prod_mid + bfly_hi + absorb
rem_hi = min(rem_hi_raw, t0 - hash_ms)
print(f"removed work: {rem_lo:.0f} to {rem_hi_raw:.0f} ms by counts; capped by T0 - hashing at {t0 - hash_ms:.0f}: range {rem_lo:.0f} to {rem_hi:.0f} ms of {t0:.0f}")

print()
print("== 6. B6a verifier per block and per request, one thread (DERIVED)")
print("per block = T0 - removed + (BAT + tower). Rows: as pinned verifier / with the rational switch row (hostfix BAT)")
out = {}
for rate in RATE_CHECKS:
    s_pin = S[("as_pinned", rate)]
    s_hf = S[("hostfix", rate)]
    lo_as, hi_as = t0 - rem_hi + s_hf, t0 - rem_lo + s_hf
    lo_rat, hi_rat = t0 - rem_hi + S_RAT[rate], t0 - rem_lo + S_RAT[rate]
    out[rate] = (lo_as, hi_as, lo_rat, hi_rat)
    print(f"{rate}: as built {lo_as:5.1f} to {hi_as:5.1f} ms a block; rational {lo_rat:5.1f} to {hi_rat:5.1f}")
for L, name in ((32, "8B profile, 32 blocks"), (26, "classifier, 26 blocks")):
    print(f"-- {name}")
    for rate, (a, b, c, d) in out.items():
        print(f"   {rate}: one thread, as built {a*L/1e3:.2f} to {b*L/1e3:.2f} s; rational {c*L/1e3:.2f} to {d*L/1e3:.2f} s;"
              f" spike part alone (BAT + tower, hostfix) {S[('hostfix', rate)]*L/1e3:.2f} s")
ours_lo = min(v[0] for v in out.values()) * 32 / 1e3
ours_hi = max(v[1] for v in out.values()) * 32 / 1e3
rat_lo = min(v[2] for v in out.values()) * 32 / 1e3
rat_hi = max(v[3] for v in out.values()) * 32 / 1e3
print(f"8B all rates: as built {ours_lo:.2f} to {ours_hi:.2f} s (today {T1}); ratio x{T1/ours_hi:.1f} to x{T1/ours_lo:.1f}")
print(f"8B all rates: rational  {rat_lo:.2f} to {rat_hi:.2f} s; ratio x{T1/rat_hi:.1f} to x{T1/rat_lo:.1f}")

print()
print("== 7. Six threads (the study's frame: 2.31 s today), two bounds (DERIVED)")
# perfect: blocks in waves of 6, each wave one block's one-thread time
import math
waves = math.ceil(32 / 6)
for rate, (a, b, c, d) in out.items():
    perfect_lo = waves * a / 1e3
    perfect_hi = waves * b / 1e3
    print(f"{rate}: perfect block parallelism {waves} waves: as built {perfect_lo:.2f} to {perfect_hi:.2f} s")
spike_only_ideal = {r: 32 * S[("hostfix", r)] / 6 / 1e3 for r in RATE_CHECKS}
print("spike part alone at ideal 6x (32 x S / 6):", {r: round(v, 3) for r, v in spike_only_ideal.items()}, "s; study's whole-PCS figure 0.15 s")
obs_lo, obs_hi = ours_lo * T6m / T1, ours_hi * T6m / T1
print(f"today's observed scaling carried over ({T6m/T1:.3f}): {obs_lo:.2f} to {obs_hi:.2f} s")
perf_all_lo = min(waves * v[0] for v in out.values()) / 1e3
perf_all_hi = max(waves * v[1] for v in out.values()) / 1e3
print(f"six-thread range all rates, as built: {perf_all_lo:.2f} (perfect) to {obs_hi:.2f} s (today's scaling); against 2.31 s: x{T6m/obs_hi:.1f} to x{T6m/perf_all_lo:.1f}")
print(f"study 3.3: 0.15 s and x5 to x15 (ESTIMATE); its B6a PCS CPU-s a block 28 ms; spike BAT+tower alone is 39 to 57 ms one thread")

print()
print("== 8. Public-weight fold, outside all of this (tick 55, COUNTED there: 14 G mults a request)")
for ns in (0.8, 1.1, 1.4):
    print(f"   at {ns} ns per multiplication: {14e9*ns*1e-9:.1f} s one thread; {14e9*ns*1e-9/6:.1f} s at 6 threads if parallel")
print("   The A/B verifier times above are on diagonal synthetic weights, so they exclude it; B6a does not change it.")
