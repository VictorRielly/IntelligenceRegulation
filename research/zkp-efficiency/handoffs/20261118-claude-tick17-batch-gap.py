#!/usr/bin/env python3
"""Tick 17: decompose the Arm A (batched) minus Arm B (one command buffer per round) GPU gap per slot.
Reads results/zk60_slot18_14_breakdown_20261117/summary.json. Standard library only."""
import json, re, statistics as st
R = "/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/summary.json"
S = json.load(open(R))["arms"]

def rows(prof):
    a = S[f"{prof}_armA_prod_batched"]["batched"]["slots_sorted_ms"]
    b = S[f"{prof}_armB_unbatched_sync_lin1"]["unbatched"]
    out = []
    for r in a:
        lbl = r["slot_label"]
        m = re.search(r"nd=(\d+)", r["meta"])
        if lbl not in b or not m: continue
        nd = int(m.group(1))
        pr = b[lbl]["per_round_median_ms"]
        rounds = [pr[k] for k in sorted(pr, key=lambda s: int(s[2:]))]
        tot = b[lbl]["phases_median_ms"]["total_unbatched_with_tables_gpu_ms"]
        out.append(dict(slot=int(re.match(r"slot (\d+)", lbl).group(1)), A=r["median_ms"], B=tot, ndA=nd,
                        ndB=len(rounds), tail=statistics_tail(rounds), r0=rounds[0]))
    return out

def statistics_tail(rounds):
    t = rounds[-3:]
    return sum(t) / len(t)

def fit(x, y):
    n = len(x); mx = sum(x)/n; my = sum(y)/n
    sxx = sum((a-mx)**2 for a in x); sxy = sum((a-mx)*(b-my) for a, b in zip(x, y))
    s = sxy/sxx; c = my - s*mx
    ss = sum((b-(c+s*a))**2 for a, b in zip(x, y)); rmse = (ss/n)**0.5
    return c, s, rmse

for prof in ("w16r2_8b", "r13_shield"):
    rs = rows(prof)
    print("==", prof)
    print("slot ndA ndB  A      B      gap   extra*tailB  gap-extra*tailB  per-round")
    xs, ys = [], []
    for r in sorted(rs, key=lambda r: -r["A"]):
        gap = r["A"] - r["B"]; ex = (r["ndA"]-r["ndB"]) * r["tail"]
        print(f'{r["slot"]:4d} {r["ndA"]:3d} {r["ndB"]:3d} {r["A"]:6.3f} {r["B"]:6.3f} {gap:5.3f} {ex:8.3f} {gap-ex:12.3f} {(gap-ex)/r["ndA"]:10.3f}')
        xs.append(r["ndA"]); ys.append(gap-ex)
    c, s, rm = fit(xs, ys)
    print(f"fit (gap - extra*tailB) = {c:.3f} + {s:.3f} * ndA   rmse {rm:.3f}; sum gap {sum(r['A']-r['B'] for r in rs):.3f}; sum ndA {sum(xs)}; sum extra*tail {sum((r['ndA']-r['ndB'])*r['tail'] for r in rs):.3f}")
    # through-origin per-round rate
    sf = sum(y for y in ys)/sum(xs)
    print(f"through-origin per-round overhead {sf:.3f} ms; sum fixed residual {sum(y - sf*x for x, y in zip(xs, ys)):.3f}")
    # small slots only (B total <= 0.55 ms)
    sm = [r for r in rs if r["B"] <= 0.55]
    print("small slots:", [(r["slot"], r["ndA"], round(r["A"]-r["B"],3)) for r in sm])

# knob probe: same nd in both arms at HL_METAL_BATCH_TAIL_US=250 (B uses 250 us by default)
K = json.load(open("/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/knob_probe.json"))
print("knob_probe keys:", list(K.keys())[:10])
