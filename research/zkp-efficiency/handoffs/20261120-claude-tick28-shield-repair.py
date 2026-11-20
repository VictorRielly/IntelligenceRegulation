#!/usr/bin/env python3
"""Tick 28 (item 47): re-pair the Shieldstral shares of ticks 11, 15, 16, 20, 21, 22, 26 and 27 to the app's profile
(W16R2_SHIELD_T128_H24). Reads the coordinator's four externalized GPU traces (gzip TSV, 199 lines each) and the
numbers typed below from the retained READMEs; runs nothing heavy, under a second.

Trace record: tag, detail, thread, queue, begin, committed, gpu_start, gpu_end, done (seconds). Each commit record is
followed by three `diag` records (inverse transform, forward transform, hash; tick 21 section 1).
"""
import gzip
import statistics
from pathlib import Path

EXT = Path("/Users/victorrielly/zk60-artifacts/w16r2_shield_block_20261120")
TR = {"w16r2_shield_a1": "w16r2_shield_a1.75029.tsv.gz", "w16r2_shield_a2": "w16r2_shield_a2.75288.tsv.gz",
      "w16r2_8b_ctl": "w16r2_8b_ctl.75103.tsv.gz", "r13_shield_ctl": "r13_shield_ctl.75193.tsv.gz"}


def recs(name):
    out = []
    with gzip.open(EXT / TR[name], "rt") as f:
        for ln in list(f)[1:]:
            p = ln.rstrip("\n").split("\t")
            if len(p) < 9:
                continue
            gs, ge, cm, dn = float(p[6]), float(p[7]), float(p[5]), float(p[8])
            ms = (ge - gs) * 1000 if ge > gs and gs > 0 else (dn - cm) * 1000
            out.append((p[0], p[1], ms))
    return out


def commit_diag_split(name):
    """Warm passes (first pass dropped as cold). Per pass: commit A, commit H, and the diag triples after each."""
    r = recs(name)
    idx = [i for i, (t, _, _) in enumerate(r) if t == "commit"]
    a_rows = r[idx[0]][1].split()[0]
    # group commits into passes: a pass starts at a commit whose rows string equals the first commit's
    starts = [i for i in idx if r[i][1].split()[0] == a_rows]
    res = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(r)
        seg = r[s:e]
        cur, rec = None, {}
        for t, d, ms in seg:
            if t == "commit":
                cur = "A" if d.split()[0] == a_rows else "H"
                rec[cur] = {"commit": ms, "diag": []}
            elif t == "diag" and cur:
                rec[cur]["diag"].append(ms)
        res.append(rec)
    return res[1:]  # warm


print("== diag split of the commit (warm passes, medians, ms): inverse / forward / hash for A and H")
F = {}
for name in TR:
    w = commit_diag_split(name)
    med = lambda key, who, i: statistics.median(p[who][key][i] if key == "diag" else p[who][key] for p in w)
    row = {}
    for who in "AH":
        inv, fwd, hsh = (statistics.median(p[who]["diag"][i] for p in w) for i in range(3))
        row[who] = (inv, fwd, hsh)
    ntt = sum(row[w][0] + row[w][1] for w in "AH")
    allp = sum(sum(row[w]) for w in "AH")
    c = statistics.median(p["A"]["commit"] + p["H"]["commit"] for p in w)
    F[name] = dict(row=row, f=ntt / allp, commit=c, inv=sum(row[w][0] for w in "AH"), fwd=sum(row[w][1] for w in "AH"))
    print(f"{name:16s} A inv/fwd/hash {row['A'][0]:.2f}/{row['A'][1]:.2f}/{row['A'][2]:.2f}  H {row['H'][0]:.2f}/{row['H'][1]:.2f}/{row['H'][2]:.2f}"
          f"  f={F[name]['f']:.3f}  commit A+H (production) {c:.2f}  inverse A+H {F[name]['inv']:.2f}  forward A+H {F[name]['fwd']:.2f}")

# ---- typed inputs (README of results/zk60_w16r2_shield_block_20261120, medians of 5 warm passes, ms)
BLOCK = {"a1": 94.056, "a2": 98.981, "pooled": 94.7, "8b_today": 94.293, "8b_1117": 91.462, "r13_1117": 174.249}
COMMIT_AH = {"a1": 28.719, "a2": 32.604, "pooled": 28.95, "8b_today": 30.504}
CADENCE = 4381.0  # ms per T128 request, W16R2 app, 2026-11-13 benchmark (REVIEW.json: 105.14 s / 24)
LAYERS = 26
cad = lambda ms: ms * LAYERS / CADENCE * 100

print("\n== commit share of block GPU at W16R2_SHIELD (tick 21's 43.7% was R13_SHIELD)")
for k in ("a1", "a2"):
    print(f"  arm {k}: {COMMIT_AH[k]/BLOCK[k]*100:.1f}% of {BLOCK[k]}")
print(f"  pooled: {COMMIT_AH['pooled']/BLOCK['pooled']*100:.1f}% of {BLOCK['pooled']}; 8B control {COMMIT_AH['8b_today']/BLOCK['8b_today']*100:.1f}%")

print("\n== NTT-free ceiling, H117b and traffic-floor at W16R2_SHIELD (f from the diag split above, applied to the production commit time)")
f = F["w16r2_shield_a1"]["f"]
f2 = F["w16r2_shield_a2"]["f"]
for nm, ff, c, b in (("a1", f, 28.719, 94.056), ("pooled commit, f of a1", f, 28.95, 94.7)):
    ntt = ff * c
    print(f"  {nm}: NTT {ntt:.1f} ms; free NTT -> block x{b/(b-ntt):.2f}, {cad(ntt):.1f}% of cadence at full pass-through")
# inverse transform share: H117b drops the inverse transform only. Inverse = measured diag inverse; the diag runs
# re-do the work once each so their sum is about the commit's own time (tick 21 section 2: 0.91 to 1.00).
inv = F["w16r2_shield_a1"]["inv"]
print(f"  H117b (drop the inverse): diag inverse A+H = {inv:.2f} ms (8B control {F['w16r2_8b_ctl']['inv']:.2f}; R13 control {F['r13_shield_ctl']['inv']:.2f}); "
      f"x{94.056/(94.056-inv):.2f} on the block; {cad(inv):.1f}% of the 4.381 s cadence at full pass-through")
# traffic floor (tick 21 section 3): same rows, same log_nn = 15 as 8B, so the 8B floor of 10.5 ms (NTT A+H) applies
fl_8b_floor_ntt = 10.5
meas_8b_ntt = 22.3
ntt_diag = F["w16r2_shield_a1"]["inv"] + F["w16r2_shield_a1"]["fwd"]
sv = ntt_diag - fl_8b_floor_ntt
print(f"  traffic floor: 8B floor 10.5 ms against 22.3 ms measured NTT (diag sum); at this profile the diag NTT is {ntt_diag:.2f} ms "
      f"(same rows, same length), so a kernel at the floor would save {sv:.1f} ms = {cad(sv):.1f}% of cadence at full pass-through "
      f"(block x{94.7/(94.7-sv):.2f}); [free-NTT line above uses f x production commit, tick 21's own method]")

print("\n== padded-pair skip (tick 11's method, substituting the app's slot facts)")
# 8B phases (tick 11 script PROFILES, ms): slot18 tab, r0, r14 ; slot14 tab, r0, r14 ; Arm A totals
S18 = dict(A=21.339, tab=1.701, r0=6.377, r14=9.020)
S14 = dict(A=14.007, tab=0.995, r0=3.546, r14=5.345)
F_PAD = (16384 - 9216) / 16384   # 0.4375
D_PAD = (4096 - 3072) / 4096     # 0.25
scale14 = 15.52 / 13.956          # slot 14 is 15.52 ms at W16R2_SHIELD (37 tables) against 13.96 at 8B (36)
sav = {}
for nm, s, pad, sc in (("slot18", S18, F_PAD, 1.0), ("slot14", S14, D_PAD, scale14)):
    bw_hi = (s["tab"] + s["r0"] + s["r14"]) * sc
    bw_lo = (s["r0"] + s["r14"]) * sc
    lo, hi = 0.6 * pad * bw_lo, pad * bw_hi
    sav[nm] = (lo, hi)
    print(f"  {nm}: pad {pad:.4f}, saving {lo:.2f} to {hi:.2f} ms (assumes the phase split of the 8B slot, scaled {sc:.3f}; slot totals 21.28 / 15.52 against 21.34 / 13.96)")
lo = sum(v[0] for v in sav.values())
hi = sum(v[1] for v in sav.values())
print(f"  slots 14 + 18: {lo:.2f} to {hi:.2f} ms per block = {lo/94.7*100:.1f} to {hi/94.7*100:.1f}% of block GPU (94.7 ms); "
      f"{cad(lo):.1f} to {cad(hi):.1f}% of the 4.381 s cadence at full pass-through; mid {cad((lo+hi)/2):.1f}%")
# the 8B reference (tick 22 D2a) with the same method
print(f"  (8B, same method: slot 18 only, F pad 0.125: {0.6*0.125*(S18['r0']+S18['r14']):.2f} to {0.125*(S18['tab']+S18['r0']+S18['r14']):.2f} ms)")
# slots 0 and 1 (row sums on the D cube, 2^19): gate table appears with the pad
print("  slots 0 and 1 (D-cube row sums): 3 tables at W16R2_SHIELD, 2 at 8B; 1.85 + 1.84 ms against 1.51 + 1.44 ms (a1 against the 8B control): "
      f"+{1.853-1.509:.2f} and +{1.839-1.436:.2f} ms; tick 11 did not count these two slots")
print(f"  total measured excess of the D pad over the 8B block: slot 14 +{15.521-13.956:.2f}, slots 0, 1 +{1.853-1.509+1.839-1.436:.2f} = "
      f"+{15.521-13.956+1.853-1.509+1.839-1.436:.2f} ms; slot sums 65.67 against 63.40 = +{65.668-63.403:.2f} ms")

print("\n== tail (tick 16; production central 12.7 ms at 8B; 4.7 to 20.5% of 117.285 solo = 5.5 to 24.0 ms)")
for lo_, c_, hi_ in ((5.51, 12.67, 24.05),):
    for b in (94.056, 94.7):
        print(f"  W16R2_SHIELD (8B ms carried over: slots 15 to 18 and 19 identical; slot 14 adds one table, 2 nodes): "
              f"{lo_/b*100:.1f} / {c_/b*100:.1f} / {hi_/b*100:.1f}% of {b}")
print(f"  cadence at full pass-through, central tail free: {cad(12.67):.1f}% ; tick 16's two-lane hiding (64 to 77%) is an 8B figure")

print("\n== K5 mixed split (tick 15): 8B 1.65 ms of the v13 times; R13 Shield 5.85 ms. Slots 14 and 18 at the app have 37/19 tables (8B 36/19)")
print(f"  W16R2_SHIELD about 1.65 ms (8B figure, slot 14 one table more): {1.65/94.7*100:.2f}% of block GPU, {cad(1.65):.2f}% of cadence")

print("\n== plain two-table slots (tick 20; G1): slots 20, 21, 22, batched")
b = 0.473 + 1.158 + 1.089
print(f"  W16R2_SHIELD a1/a2 medians: {b:.2f} ms = {b/94.7*100:.2f}% of block GPU (8B control {0.433+1.085+1.147:.2f} ms = {(0.433+1.085+1.147)/94.293*100:.2f}%); "
      f"{cad(b):.1f}% of cadence at full pass-through, and that is the batched figure with its barrier gap (tick 17)")

print("\n== cadence per block")
print(f"  W16R2 app: {CADENCE/LAYERS:.1f} ms per block (proof only {3839/LAYERS:.1f}); block GPU 94.7 -> {94.7/(CADENCE/LAYERS)*100:.0f}% of cadence (proof only {94.7/(3839/LAYERS)*100:.0f}%)")
print(f"  8B harness: {3745.5/32:.1f} ms per block; block GPU 91.46 -> {91.46/(3745.5/32)*100:.0f}%")
print("  rows: commit records give A 2,504 + H 2,606 = 5,110 at both W16R2 profiles; tick 26 counted 5,103 (7 more in the records); "
      "R13_SHIELD records give 4,577 + 4,390 = 8,967, equal to the R13 8B lists' totals")
