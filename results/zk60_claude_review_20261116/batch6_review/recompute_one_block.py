#!/usr/bin/env python3
"""Reviewer recomputation of the Batch 6 one-block numbers from the author's raw data.

Reads only:
  results/zk60_h132_batched_forward_20261116/batch6_1block_m4_7warm.log   (PB-TIMING phase rows, M4-TRAINED lines)
  results/zk60_h132_batched_forward_20261116/BATCH6_HEAD_PROFILE_METRICS.json (per-pass samples of the GPU numbers;
      the raw TSV traces were deleted by the author's script, so GPU figures can only be re-aggregated from these samples)
  results/zk60_h132_batched_forward_20261116/rust_m4_8b_pbtiming.log     (Batch 5 log, for the 337 ms comparison)
Writes nothing but stdout. Run with: python3 -I <this file>
"""
import json
import re
import statistics

R = "/Users/victorrielly/IntelligenceRegulation/results/zk60_h132_batched_forward_20261116/"


def pct(s, p):
    s = sorted(s)
    n = len(s)
    pos = p * (n - 1)
    lo = int(pos)
    hi = min(lo + 1, n - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def med_iqr(v):
    return pct(v, 0.5), pct(v, 0.75) - pct(v, 0.25)


def parse_passes(path):
    txt = open(path).read()
    pat = re.compile(r"PB-TIMING (prove(?:-metal)?) \| (.+?)\s+\|\s*([^|]*?)\s*\|\s*([0-9.]+) \|")
    passes, cur, kind = [], {}, ""
    for m in pat.finditer(txt):
        kind = m.group(1)
        name = m.group(2).strip()
        cur[name] = float(m.group(4))
        if name == "WALL CLOCK OF THE CALL":
            passes.append((kind, cur))
            cur = {}
    m4 = re.findall(r"M4-TRAINED \S+ cpu ([0-9.]+) s metal-(cold|warm) ([0-9.]+) s \(prove core cpu ([0-9.]+) s metal ([0-9.]+) s", txt)
    return passes, m4


passes, m4 = parse_passes(R + "batch6_1block_m4_7warm.log")
metal = [d for k, d in passes if k == "prove-metal"]
print("PB-TIMING blocks: total", len(passes), "metal", len(metal), "M4 lines", len(m4))
warm = metal[1:]
warm_m4 = [x for x in m4 if x[1] == "warm"]
core_ms = [float(x[4]) * 1000 for x in warm_m4]
print("prove-core metal ms per warm pass (M4-TRAINED line):", core_ms)
print("  median/IQR (author interpolation):", med_iqr(core_ms), " statistics.median:", statistics.median(core_ms))
wall_pb = [d["WALL CLOCK OF THE CALL"] * 1000 for d in warm]
print("PB-TIMING wall per warm pass:", wall_pb, med_iqr(wall_pb))
print("warm pass order trend (first 2 passes vs last 5):", statistics.mean(core_ms[:2]), statistics.mean(core_ms[2:]))

# phase groups
def g(d, key):
    return d.get(key, 0.0) * 1000

H_INV = ["H: LogUp helper inverses (six lookup domains)", "H: exp + activation helper inverses", "H: the three table helpers"]
H_MASK = "H: mask rows + the zero-sum rows"
H_COMMIT = "H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)"
OPEN_H = "open H (schedule audit + pcs::open_zk)"
inv = [sum(g(d, k) for k in H_INV) for d in warm]
mask = [g(d, H_MASK) for d in warm]
hc = [g(d, H_COMMIT) for d in warm]
oh = [g(d, OPEN_H) for d in warm]
author_total = [a + b + c + e for a, b, c, e in zip(inv, mask, hc, oh)]
print("\nAuthor's 52 ms list recomputed from the log (per pass):", author_total)
print("  median/IQR", med_iqr(author_total), " share of prove core per-pass median:", med_iqr([100 * a / b for a, b in zip(author_total, core_ms)]))
print("  components median: inverses", med_iqr(inv)[0], "H masks", med_iqr(mask)[0], "H commit wall", med_iqr(hc)[0], "open H wall", med_iqr(oh)[0])

# slot rows
slot_keys = sorted({k for d in warm for k in d if k.startswith("slot ")})
print("\nnumber of slot rows:", len(slot_keys))
slot_med = {k: med_iqr([g(d, k) for d in warm])[0] for k in slot_keys}
for k in slot_keys:
    print(f"  {k:62s} median {slot_med[k]:6.1f} ms   raw {[round(g(d, k)) for d in warm]}")
print("  sum of slot medians:", sum(slot_med.values()))
slots_tot = [sum(g(d, k) for k in slot_keys) for d in warm]
print("  per-pass sum of 23 slots:", slots_tot, med_iqr(slots_tot))

# helper-relation slots among the 23
def slot_no(k):
    return int(k.split()[1])

zc = {14: ("D", 10, 37), 15: ("Q", 3, 15), 16: ("Kv", 3, 15), 17: ("S", 4, 19), 18: ("F", 4, 19)}
# helper/table counts are the ones research/zkp-efficiency/experiments/logup-gkr-20261101/projection.py uses (DOM)
by_no = {slot_no(k): k for k in slot_keys}
print("\nHelper-relation slots (all from the same warm passes):")
tab = [g(d, by_no[19]) for d in warm]
zs = [g(d, by_no[20]) for d in warm]
print("  slot 19 TAB table helper zero-check:", tab, med_iqr(tab))
print("  slot 20 ZS zero-sum row:", zs, med_iqr(zs))
five = [sum(g(d, by_no[i]) for i in zc) for d in warm]
print("  slots 14-18 five domain zero-checks, total per pass:", five, med_iqr(five))
share = []
for d in warm:
    s = 0.0
    for i, (nm, hlp, tbl) in zc.items():
        s += g(d, by_no[i]) * hlp / tbl
    share.append(s)
print("  helper share of slots 14-18 by helper/table count (the 20261101 projection.py method), per pass:", [round(x, 1) for x in share], med_iqr(share))
print("   (same method per domain, medians):", {zc[i][0]: round(hh * slot_med[by_no[i]] / tt, 2) for i, (nm, hh, tt) in zc.items()})
# second, wider reading: total of whole slots 19,20 + helper share of 14-18
low = [a for a in share]
wide_add = [s + t + z for s, t, z in zip(share, tab, zs)]
print("  helper share of 14-18 + slot 19 + slot 20 per pass:", [round(x, 1) for x in wide_add], med_iqr(wide_add))
print("  helper share of 14-18 + slot 20 (TAB kept):", med_iqr([s + z for s, z in zip(share, zs)]))

# gross ceilings
core_med = med_iqr(core_ms)[0]
for label, vals in [("author list", author_total),
                    ("author list + helper share of 14-18", [a + s for a, s in zip(author_total, share)]),
                    ("author list + helper share of 14-18 + ZS (slot 20)", [a + s + z for a, s, z in zip(author_total, share, zs)]),
                    ("author list + helper share of 14-18 + TAB + ZS", [a + w for a, w in zip(author_total, wide_add)])]:
    m = med_iqr(vals)[0]
    print(f"  {label:55s}: removed {m:6.1f} ms = {100*m/core_med:5.1f}% of {core_med:.0f} ms ; ceiling x{core_med/(core_med-m):.3f}")

# Upper bound: all slot work whose size scales with H table counts, i.e. whole slots 14-18 (impossible: domain still checked)
whole5 = med_iqr(five)[0]
print("  (not credible, upper) whole slots 14-18 + TAB + ZS removed too:", whole5 + med_iqr(tab)[0] + med_iqr(zs)[0])

# JSON samples re-aggregation
d = json.load(open(R + "BATCH6_HEAD_PROFILE_METRICS.json"))
o = d["item1_one_block_w16r2_8b_t128_7warm"]
gpu = o["prove_core_gpu_busy_from_cb_timestamps_ms"]["samples"]
host = o["prove_core_host_between_cbs_ms"]["samples"]
print("\nGPU busy samples:", gpu, "median/IQR", med_iqr(gpu))
print("author median", o["prove_core_gpu_busy_from_cb_timestamps_ms"]["median"], o["prove_core_gpu_busy_from_cb_timestamps_ms"]["iqr"])
print("host = wall - gpu per pass:", [round(c - x, 3) for c, x in zip(core_ms, gpu)], "median", med_iqr([c - x for c, x in zip(core_ms, gpu)]))
print("median(wall) - median(gpu) =", core_med - med_iqr(gpu)[0], " vs author's host median", o["prove_core_host_between_cbs_ms"]["median"])
print("GPU share per pass (gpu/wall):", [round(100 * x / c, 2) for x, c in zip(gpu, core_ms)], med_iqr([100 * x / c for x, c in zip(gpu, core_ms)]))
print("median ratio of medians 93.482/268 =", 93.482 / 268.0)
print("author claims 35.12% (median of per-pass shares) and 64.88% host (= 100 - 35.12?)  ; host/wall medians:", med_iqr([100 * (c - x) / c for x, c in zip(gpu, core_ms)]))
print("H commit GPU samples", o["phases_ms"]["H_commit_gpu_cb_ms"]["samples"])
a_g = o["phases_ms"]["A_commit_gpu_cb_ms"]["samples"]
sl_g = o["phases_ms"]["slots_23_gpu_cb_ms"]["samples"]
oa_g = o["phases_ms"]["open_A_gpu_devfold_and_gather_cb_ms"]["samples"]
oh_g = o["phases_ms"]["open_H_gpu_devfold_and_gather_cb_ms"]["samples"]
h_g = o["phases_ms"]["H_commit_gpu_cb_ms"]["samples"]
tot = [a + b + c + e + f for a, b, c, e, f in zip(a_g, h_g, sl_g, oa_g, oh_g)]
print("sum of GPU buckets per pass (A, H, slots, openA, openH):", [round(x, 3) for x in tot])
print("  vs union per pass:", gpu, " (difference means some CB outside those buckets or rounding)")
print("  slots GPU share of union per pass median:", med_iqr([100 * s / u for s, u in zip(sl_g, gpu)]))
print("  slots wall - slot gpu = host in slots:", med_iqr([a - b for a, b in zip(slots_tot, sl_g)]))

print("\nA-side group: commit A wall / GPU", med_iqr([g(dd, 'A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)') for dd in warm])[0])

# phase table for the whole warm pass, medians, for the report
allk = []
for k in warm[0]:
    allk.append(k)
print("\nAll phase medians (ms):")
tot = 0
for k in allk:
    if k.startswith("slot ") or k in ("SUM OF PHASES", "WALL CLOCK OF THE CALL", "unaccounted (wall - sum)"):
        continue
    m = med_iqr([g(dd, k) for dd in warm])[0]
    tot += m
    print(f"  {k:70s} {m:6.1f}")
print("  23 slots total (median of per-pass sums):", med_iqr(slots_tot)[0])
print("  non-slot phases total:", tot)

# Batch 5 log: last warm pass phases
p5, m5 = parse_passes(R + "rust_m4_8b_pbtiming.log")
metal5 = [dd for k, dd in p5 if k == "prove-metal"]
print("\nBatch 5 log: PB blocks", len(p5), "metal", len(metal5), "M4 lines", [(x[1], x[4]) for x in m5])
last5 = metal5[-1]
print("Batch 5 last warm pass vs Batch 6 median (ms):")
keys = [k for k in last5 if not k.startswith("slot ") and k not in ("SUM OF PHASES", "WALL CLOCK OF THE CALL", "unaccounted (wall - sum)")]
for k in keys:
    b6 = med_iqr([g(dd, k) for dd in warm])[0]
    print(f"  {k:70s} B5 {last5[k]*1000:6.0f}   B6 {b6:6.1f}   diff {b6-last5[k]*1000:6.1f}")
s5 = sum(v for k, v in last5.items() if k.startswith("slot ")) * 1000
print(f"  {'23 slots':70s} B5 {s5:6.0f}   B6 {med_iqr(slots_tot)[0]:6.1f}   diff {med_iqr(slots_tot)[0]-s5:6.1f}")
print("  B5 wall", last5["WALL CLOCK OF THE CALL"] * 1000)
for k in sorted(last5):
    if k.startswith("slot "):
        no = slot_no(k)
        print(f"    {k:60s} B5 {last5[k]*1000:5.0f}  B6 {slot_med.get(by_no[no], 0):5.1f}")
