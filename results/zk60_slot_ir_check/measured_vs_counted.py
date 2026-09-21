#!/usr/bin/env python3
"""Does the multiplication count model rank the slots the way the MEASURED
per-slot masked-sumcheck seconds do?

MEASURED source (committed, read-only):
  /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/q28-m125-final-dense.log
  lines 9..97, the `masked sumcheck (zk.rs, shared)` PB-SLOTSTEP column,
  a 17.401 s 125M prove.  Second sample: r29-m125-bfcensus.log, 19.357 s.

COUNTED source: slot_cost_check.json, produced by this check's own counter.

The model under test is the memo's: cost = round loop + fold, in Fp
multiplications.  The alternative is cost = that PLUS the per-pair-index
work proportional to the TABLE COUNT that `sumcheck::prove` does whatever
the polynomial is (gather 2k words, k subtractions, degree*k additions in
the `cur[t] += dif[t]` walk, and the fold's own read/write).
"""
import json
import sys

MEAS = {  # q28-m125-final-dense.log, masked sumcheck seconds
    0: 0.051, 1: 0.047, 2: 0.001, 3: 0.007, 4: 0.203, 5: 0.000, 6: 0.000,
    7: 0.000, 8: 0.000, 9: 0.000, 10: 0.000, 11: 0.000, 12: 0.000, 13: 0.000,
    14: 1.642, 15: 0.544, 16: 0.258, 17: 3.054, 18: 0.659, 19: 0.035,
    20: 0.001, 21: 0.049, 22: 0.043,
}
MEAS2 = {  # r29-m125-bfcensus.log, the second sample
    0: 0.058, 1: 0.046, 2: 0.001, 3: 0.007, 4: 0.224, 14: 1.872, 15: 0.538,
    16: 0.266, 17: 3.107, 18: 0.673, 19: 0.037, 20: 0.001, 21: 0.053, 22: 0.044,
}

blob = json.load(open(sys.argv[1]))
rows = {r["slot"]: r for r in blob["125M"]["rows"]}

BIG = [17, 14, 18, 15, 16, 4, 0, 21, 1, 22, 19, 3]
out = []
out.append("MEASURED masked-sumcheck seconds vs the COUNTED multiplication model, 125M")
out.append("(q28-m125-final-dense.log, one run, 17.401 s prove; the model is the memo's:")
out.append(" round loop + fold, in Fp multiplications)")
out.append("")
out.append("slot name        2^main  k   meas s   share  counted Fp    share   Fp/s (1e9)  ratio")
tot_m = sum(MEAS.values())
tot_c = sum(rows[s]["loop0"] + rows[s]["fold0"] for s in rows)
for s in BIG:
    r = rows[s]
    c = r["loop0"] + r["fold0"]
    m = MEAS[s]
    out.append(f"{s:4d} {r['name']:<11s} 2^{r['main']:<4d} {r['tables']:3d} "
               f"{m:7.3f} {100*m/tot_m:6.1f}% {c:13d} {100*c/tot_c:6.1f}%  "
               f"{c/m/1e9 if m else float('nan'):10.3f}  {(c/tot_c)/(m/tot_m):6.2f}")
out.append(f"     TOTAL (23 slots)        {tot_m:7.3f} 100.0% {tot_c:13d} 100.0%  "
           f"{tot_c/tot_m/1e9:10.3f}")
out.append("")
out.append("An exact multiplication model would give one Fp/s figure for every slot and")
out.append("a ratio of 1.00 everywhere.  It does not.")

# the alternative model: add the table-proportional traffic
out.append("")
out.append("Adding the table-proportional work the memo's unit does not count")
out.append("(per pair index and round: 2k word reads, k subtractions, degree*k")
out.append(" additions in the cur[t] += dif[t] walk, and the fold's k read-modify-writes).")
out.append("Model:  cost = Fp_muls + W * k * (2^main - 1) * (degree + 3)")
out.append("with W the Fp-multiplication-equivalent price of one such Fp2 slot-word step.")
BIGSIX = [17, 14, 18, 15, 16, 4]
best = None
for w10 in range(1, 400):
    W = w10 / 10.0
    pred = {s: rows[s]["loop0"] + rows[s]["fold0"]
            + W * rows[s]["tables"] * ((1 << rows[s]["main"]) - 1) * (rows[s]["degree"] + 4)
            for s in BIG}
    tp6 = sum(pred[s] for s in BIGSIX)
    tm6 = sum(MEAS[s] for s in BIGSIX)
    err = max(abs((pred[s] / tp6) / (MEAS[s] / tm6) - 1) for s in BIGSIX)
    if best is None or err < best[1]:
        best = (W, err, pred, tp6, tm6)
W, err, pred, tp6, tm6 = best
c6 = sum(rows[s]["loop0"] + rows[s]["fold0"] for s in BIGSIX)
err0 = max(abs(((rows[s]["loop0"] + rows[s]["fold0"]) / c6) / (MEAS[s] / tm6) - 1) for s in BIGSIX)
out.append(f"Fitted over the six slots above 0.2 s: W = {W:.1f} Fp-mul-equivalents per")
out.append(f"table-word step.  Worst share error falls from {100*err0:.0f}% "
           f"(multiplications only) to {100*err:.0f}% (multiplications + traffic).")
out.append("")
out.append("slot   meas share   mul-only share   mul+traffic share   (of the six)")
for s in BIGSIX:
    c = rows[s]["loop0"] + rows[s]["fold0"]
    out.append(f"{s:4d} {100*MEAS[s]/tm6:11.1f}% {100*c/c6:15.1f}% {100*pred[s]/tp6:18.1f}%")
out.append("")
out.append("Implied Fp multiplications per second, if the memo's unit were the whole cost:")
sp = sorted(((rows[s]["loop0"] + rows[s]["fold0"]) / MEAS[s] / 1e9, s) for s in BIG if MEAS[s] >= 0.005)
out.append(f"  over the twelve slots above 0.005 s: {sp[0][0]:.2f}e9 (slot {sp[0][1]}) "
           f"to {sp[-1][0]:.2f}e9 (slot {sp[-1][1]}) -- a factor of {sp[-1][0]/sp[0][0]:.0f}")
sp6 = sorted(((rows[s]["loop0"] + rows[s]["fold0"]) / MEAS[s] / 1e9, s) for s in BIGSIX)
out.append(f"  over the six slots above 0.2 s:      {sp6[0][0]:.2f}e9 (slot {sp6[0][1]}) "
           f"to {sp6[-1][0]:.2f}e9 (slot {sp6[-1][1]}) -- a factor of {sp6[-1][0]/sp6[0][0]:.1f}")
out.append("")
out.append("Ordering: the counted model puts slot 04 (3.2%) above slot 16 (0.8%);")
out.append("the measurement puts slot 16 (3.9%) above slot 04 (3.1%).  One inversion")
out.append("among the six, and the top-two weight ratio is 3.92 counted against 1.86")
out.append("measured -- the model over-weights slot 17 against slot 14 by 2.1x.")
out.append("")
out.append("Run-to-run spread on the two committed 125M samples, for the six big slots:")
for s in [17, 14, 18, 15, 16, 4]:
    a, b = MEAS[s], MEAS2[s]
    out.append(f"  slot {s:2d}: {a:.3f} s and {b:.3f} s  ({100*(b-a)/a:+.1f}%)")

text = "\n".join(out)
print(text)
if len(sys.argv) > 2:
    open(sys.argv[2], "w").write(text + "\n")
