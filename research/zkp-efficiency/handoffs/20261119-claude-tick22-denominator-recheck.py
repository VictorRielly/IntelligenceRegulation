#!/usr/bin/env python3
"""Tick 22 (queue item 38): restate every thresholded decision of ticks 11 to 21 against the production
block-GPU denominators. Standard library only; reads no file; every input is a figure quoted in the handoffs
or records named in the comments. Run: python3 <this file>."""

OLD = {"8B": 117.285, "SH": 248.899}          # breakdown README 2.1 (includes diag re-runs)
NEW = {"8B": 91.462, "SH": 174.249}           # tick 21: without the diag records
CAD_8B = 3745.5                               # ms per request, serve4 Arm A 12-pass median (README 3.2)
LAY = {"8B": 32, "SH": 26}
f8 = NEW["8B"] / OLD["8B"]
print("factor old->new share: 8B x%.3f, Shield x%.3f" % (OLD["8B"] / NEW["8B"], OLD["SH"] / NEW["SH"]))
print("cadence/32 = %.2f ms (old 8B denominator 117.285; new 91.462)" % (CAD_8B / 32))
print("production block sum x32 = %.3f s = %.1f%% of cadence; prove-call GPU union 2.50-2.69 s; floor (ii) 2.99 s"
      % (NEW["8B"] * 32 / 1000, NEW["8B"] * 32 / CAD_8B * 100))
print("cross-check: Batch 6 one-block log 93.48 ms vs this tick's 91.462: %.1f%%" % ((93.48 / 91.462 - 1) * 100))
print("sum of Arm A categories without diag: %.3f ms (63.302 + 13.987 + 13.900 + 0.185)" % (63.302 + 13.987 + 13.900 + 0.185))


def sh(ms, prof):
    return 100 * ms / NEW[prof]


def cad(ms):  # share of 8B cadence if a per-block saving of ms were fully passed through
    return 100 * ms * 32 / CAD_8B


print("\n== D1 G1 (tick 20) ==")
rows = {
    "P2 8B A": (2.259, "8B"), "P2 8B B": (0.796, "8B"), "P2 SH A": (2.790, "SH"), "P2 SH B": (0.818, "SH"),
    "gen 8B A (P2+P3)": (2.259 + 4.691, "8B"), "gen 8B B": (0.796 + 1.368, "8B"),
    "gen SH A": (2.790 + 5.336, "SH"), "gen SH B": (0.818 + 1.620, "SH"),
}
for k, (ms, p) in rows.items():
    print("%-20s %.3f ms: old %.2f%%  new %.2f%%" % (k, ms, 100 * ms / OLD[p], sh(ms, p)))

print("\n== D2 padded-pair skip (tick 11) ==")
for name, lo, hi, p in (("8B", 1.15, 2.14, "8B"), ("SH", 10.0, 18.3, "SH")):
    print("%s: %.2f-%.2f ms: old %.1f-%.1f%%  new %.1f-%.1f%%" % (name, lo, hi, 100 * lo / OLD[p], 100 * hi / OLD[p], sh(lo, p), sh(hi, p)))
print("8B cadence share (ms x32 / 3745.5): %.1f-%.1f%%" % (cad(1.15), cad(2.14)))
print("P2 pass line at Shield 8 ms: old %.1f%% new %.1f%%; 8B 1.0 ms: old %.2f%% new %.2f%%"
      % (100 * 8 / OLD["SH"], sh(8, "SH"), 100 * 1.0 / OLD["8B"], sh(1.0, "8B")))

print("\n== D3 tail (tick 16) ==")
for name, vals, p in (("8B", (5.540, 12.66, 24.08), "8B"), ("SH", (8.838, 15.2, 28.06), "SH")):
    print("%s: ms %s: old %s  new %s" % (name, vals, ["%.1f%%" % (100 * v / OLD[p]) for v in vals], ["%.1f%%" % sh(v, p) for v in vals]))
print("SH j>=6 tail 7.174 ms: old %.2f%% new %.2f%%" % (100 * 7.174 / OLD["SH"], sh(7.174, "SH")))
print("8B cadence share of the hidden-adjusted central tail: hide 64-77%% -> %.1f-%.1f%% (unchanged: ms vs cadence)"
      % (cad(12.66 * 0.23), cad(12.66 * 0.36)))

print("\n== D4 kernel ideas (tick 15) ==")
print("8B slot 18 quarter-length tail: 1.1 ms: old %.2f%% new %.2f%%; cadence %.2f%%" % (100 * 1.1 / OLD["8B"], sh(1.1, "8B"), cad(1.1)))
k5_8b = 0.138 * 7.40 + 0.075 * 8.45      # mixed schedule 0.862 / 0.925 of v13 (K5d), ms
k5_sh = 0.25 * 14.27 + 0.16 * 14.27      # mixed schedule 0.75 / 0.84 (tick 15 section 2), ms
print("K5 mixed split saving: 8B %.2f ms = old %.2f%% new %.2f%% (cadence %.2f%%); Shield %.2f ms = old %.2f%% new %.2f%%"
      % (k5_8b, 100 * k5_8b / OLD["8B"], sh(k5_8b, "8B"), cad(k5_8b), k5_sh, 100 * k5_sh / OLD["SH"], sh(k5_sh, "SH")))
print("coordinator's count 1-3%% (Shield) x1.428 = %.1f-%.1f%%; ~1%% (8B) x1.282 = %.1f%%" % (1 * 1.428, 3 * 1.428, 1.282))

print("\n== D5 traffic caps (tick 14) ==")
for lbl, v in (("windows 0-4 of slots 14-19 (33.6 ms)", 28.6), ("H133 both, cache", 4.3), ("both, DRAM", 15.6),
               ("both, 96 MB held", 12.7), ("H161", 4.5), ("H134 high", 0.2)):
    print("%-40s 8B old %.1f%% -> new %.1f%%" % (lbl, v, v * 1.282))
for lbl, v in (("both Shield cache", 3.5), ("both Shield DRAM", 13.2), ("both Shield 96 MB", 12.2), ("H161 Shield", 4.7)):
    print("%-40s Shield old %.1f%% -> new %.1f%%" % (lbl, v, v * 1.428))
print("K1 loads share of a v13 body 0.11-0.19 applied to windows 0-4 (33.6 ms): %.1f-%.1f ms = %.1f-%.1f%% of 91.462"
      % (0.11 * 33.6, 0.19 * 33.6, sh(0.11 * 33.6, "8B"), sh(0.19 * 33.6, "8B")))

print("\n== D6 tick 17 gap ==")
print("8B equal-round gap 11.30 ms: old %.1f%% new %.1f%%; total gap 18.54: old %.1f%% new %.1f%%" %
      (100 * 11.30 / OLD["8B"], sh(11.30, "8B"), 100 * 18.54 / OLD["8B"], sh(18.54, "8B")))
print("Shield 12.4 ms: old %.1f%% new %.1f%%; total 18.71: old %.1f%% new %.1f%%" %
      (100 * 12.4 / OLD["SH"], sh(12.4, "SH"), 100 * 18.71 / OLD["SH"], sh(18.71, "SH")))
print("cadence share if all of 11.30 ms/block passed through: %.1f%%; hidden 64-77%%: %.1f-%.1f%%"
      % (cad(11.30), cad(11.30 * 0.23), cad(11.30 * 0.36)))

print("\n== D7 tick 21 (already on the new denominator; cadence conversion) ==")
for lbl, ms in (("H117b inverse (8.30)", 8.30), ("NTT total, f x commit (0.868 x 27.887 = 24.2)", 0.868 * 27.887),
                ("traffic-floor saving (11.8)", 11.8)):
    s = sh(ms, "8B")
    print("%-52s block GPU %.1f%% (x%.3f); cadence upper %.1f%% (x%.3f)" % (lbl, s, 1 / (1 - s / 100), cad(ms), 1 / (1 - cad(ms) / 100)))

print("\n== D8 tick 14's 1/(1-s) rule ==")
print("old share s_old = ms/117.285 vs cadence share ms*32/3745.5: ratio %.4f (so old 8B shares were numerically cadence shares)"
      % ((1 / OLD["8B"]) / (32 / CAD_8B)))
print("prove-call GPU union 2.688 s of 3.809 s = %.1f%%; production solo sum 2.927 s = %.1f%% of cadence" % (100 * 2.688 / 3.809, 100 * 2927.0 / 3745.5))

print("\n== D9 tick 20 host matmul claims ==")
print("14 ms/block x 32 = %.0f ms thread-time per request; 'between small slots' 0.45 thread-s (35%% exposed), 'slots to slot 14' 1.06 thread-s (37%% exposed, 0.40 s)" % (14 * 32))
print("exposed 0.40 s of a 3.809 s call = %.1f%%" % (100 * 0.40 / 3.809))
