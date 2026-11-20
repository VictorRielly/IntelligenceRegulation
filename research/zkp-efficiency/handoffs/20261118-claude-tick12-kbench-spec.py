#!/usr/bin/env python3
"""Tick 12 arithmetic (standard library only, reads no file). Inputs are copied from
results/zk60_a27_app_20261107/kb1.log (MEASURED) and kbench/gen.py output (COUNTED, run on the A26 dumps):
slot 14: v0 body 502 muls + 64 tables, v3 body 297 + 67 tables; slot 18: v0 222 + 29, v3 149 + 32."""

# kb1.log, ms for all later rounds from cap/4 (first five rounds, then the rest), random extension tables
kb = {
    14: {"v0": 43.2, "v1": 34.7, "v2": 30.1, "v3": 16.1, "v13": 14.1, "v123": 14.0,
         "first_v123": 4.2, "tables": 68, "cap": 2 ** 19},
    18: {"v0": 30.6, "v1": 25.2, "v2": 26.3, "v3": 17.2, "v13": 14.3, "v123": 14.4,
         "first_v123": 5.7, "tables": 33, "cap": 2 ** 21},
}
body = {14: (502, 64, 297, 67), 18: (222, 29, 149, 32)}  # v0 body, v0 tables, v3 body, v3 tables


def pct(a, b):
    return 100.0 * (a - b) / a


print("== 1. what A27's kb1 measured about line values by additions (v2)")
for s in (14, 18):
    k = kb[s]
    print(f"slot {s}: v2 vs v0 {pct(k['v0'], k['v2']):.1f}% faster (old kernel); "
          f"v123 vs v13 {pct(k['v13'], k['v123']):+.1f}% (on top of the A27 materialization); "
          f"v1 vs v0 {pct(k['v0'], k['v1']):.1f}% (4 points of 5 would give 20.0%)")

print("\n== 2. multiplication-count model against the measured v2 gain (old kernel, np = 5, line values at d = 2, 3, 4)")
for s in (14, 18):
    b0, t0, b3, t3 = body[s]
    body_m = 5 * b0
    line_m = 3 * t0 * 2
    print(f"slot {s}: body {body_m} + line {line_m} muls per pair: line share of multiplications "
          f"{100 * line_m / (body_m + line_m):.1f}%; measured v2 gain {pct(kb[s]['v0'], kb[s]['v2']):.1f}%")
    # after materialization, np = 4, line values at d = 2, 3
    body_m3 = 4 * b3
    line_m3 = 2 * t3 * 2
    print(f"   v13: body {body_m3} + line {line_m3}: line share {100 * line_m3 / (body_m3 + line_m3):.1f}%; "
          f"measured v123 gain over v13 {pct(kb[s]['v13'], kb[s]['v123']):+.1f}%")

print("\n== 3. logical and unique bytes read in the first later round (v123), all tables as 16-byte extension words")
for s in (14, 18):
    k = kb[s]
    half = k["cap"] // 4          # round 1 of the bench: half = cap / 4 pairs
    tabs = k["tables"]
    unique = tabs * 2 * half * 16
    logical = half * tabs * 16 * (1 + 1 + 2 + 2)  # points 0, 1 load one word; points 2, 3 load both (np = 4)
    t = k["first_v123"] * 1e-3
    print(f"slot {s}: half 2^{half.bit_length() - 1}, unique {unique / 1e6:.0f} MB ({unique / t / 1e9:.0f} GB/s), "
          f"logical {logical / 1e6:.0f} MB ({logical / t / 1e9:.0f} GB/s) in {k['first_v123']} ms")

print("\n== 4. a gl_mul : gl_add ratio the v0 -> v2 gain would imply, if the whole gain were multiplications saved")
for s in (14, 18):
    b0, t0, b3, t3 = body[s]
    body_m = 5 * b0
    line_m = 3 * t0 * 2
    # T0 = (body_m + line_m) u ; gain = line_m u - adds ; so u = T0 / (body_m + line_m) per mul-equivalent
    u = kb[s]["v0"] / (body_m + line_m)
    saved_per = (kb[s]["v0"] - kb[s]["v2"]) / line_m
    print(f"slot {s}: average cost per mul-equivalent {u * 1000:.2f} us per pair-set; saved per line-value multiplication "
          f"{saved_per * 1000:.2f} (same unit): ratio {saved_per / u:.2f} x the average body product")
