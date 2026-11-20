#!/usr/bin/env python3
"""Batch 7 review: recompute the log-level numbers (standard library only, read-only).

Usage: python3 -I recompute_logs.py
Reads the three Batch 7 stdout logs and prints medians, IQRs, spreads, cadence, lane figures and the
cadence model max(P, (S + W + P)/L) with the values the logs carry.
"""
import re
import statistics as st
from pathlib import Path

D = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_batch7_sealing_lanes3_20261117")
LOGS = {"serve1": "batch7_serve1_6warm.log", "serve4": "batch7_serve4_lanes2_6warm.log", "serve6": "batch7_serve6_lanes3_6warm.log"}

REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(?P<arm>[^\]]+)\] (?:pass (?P<p>\d+) request (?P<q>\d+)|cold request (?P<cq>\d+)): "
    r"arrived (?P<arr>[0-9.]+), sealing turn (?P<turn>[0-9.]+), sealing side done (?P<sdone>[0-9.]+) \(sealing pass (?P<seal>[0-9.]+) s\), "
    r"prover (?P<ps>[0-9.]+)-(?P<pe>[0-9.]+) \(waited (?P<wait>[0-9.]+) s; prove call (?P<pc>[0-9.]+) s: "
    r"preflight (?P<pre>[0-9.]+), commit (?P<com>[0-9.]+), forks (?P<forks>[0-9.]+), join (?P<join>[0-9.]+)\), "
    r"receipt write (?P<w>[0-9.]+) s \([^)]*\), result (?P<res>[0-9.]+);")
STR = re.compile(r"A22-AB STREAM \S+ L32 N6 \[(?P<arm>[^\]]+)\] pass (?P<p>\d+): (?P<n>\d+) requests in (?P<wall>[0-9.]+) s .*?steady (?P<steady>[0-9.NaN]+) tok/s; amortized (?P<am>[0-9.]+) tok/s;.*?footprint start (?P<fs>[0-9.]+) GiB, peak (?P<fp>[0-9.]+) GiB, end (?P<fe>[0-9.]+) GiB; user (?P<u>[0-9.]+) s \+ sys (?P<sy>[0-9.]+) s")


def q(v, p):
    s = sorted(v)
    n = len(s)
    pos = p * (n - 1)
    lo = int(pos)
    hi = min(lo + 1, n - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def summ(v, nd=4):
    return f"n={len(v)} med={q(v,.5):.{nd}f} iqr={q(v,.75)-q(v,.25):.{nd}f} min={min(v):.{nd}f} max={max(v):.{nd}f} mean={sum(v)/len(v):.{nd}f} sd={st.pstdev(v) if len(v)>1 else 0:.{nd}f}"


def load(name):
    t = (D / LOGS[name]).read_text()
    reqs = {}
    for m in REQ.finditer(t):
        g = m.groupdict()
        if g["p"] is None:
            continue  # cold request excluded
        reqs[(int(g["p"]), int(g["q"]))] = {k: float(v) for k, v in g.items() if k not in ("arm", "p", "q", "cq") and v is not None}
    strs = {int(m.group("p")): {k: (float(v) if v != "NaN" else float("nan")) for k, v in m.groupdict().items() if k not in ("arm", "p")} for m in STR.finditer(t)}
    return reqs, strs


R = {"serve1": 1, "serve4": 4, "serve6": 6}
LANES = {"serve1": 2, "serve4": 2, "serve6": 3}
data = {k: load(k) for k in LOGS}

print("== A. sealing pass (log column 'sealing pass'), warm only, n = passes x requests")
solo1 = [data["serve1"][0][(p, 0)]["seal"] for p in range(6)]
print("serve1 solo (req 0)      :", summ(solo1, 3), solo1)
solo4 = [data["serve4"][0][(p, 0)]["seal"] for p in range(6)]
print("serve4 req 0 (unoverlapped):", summ(solo4, 3), solo4)
ov4 = [data["serve4"][0][(p, k)]["seal"] for p in range(6) for k in (1, 2, 3)]
print("serve4 reqs 1..3 (n=18)  :", summ(ov4, 3))
for k in (1, 2, 3):
    v = [data["serve4"][0][(p, k)]["seal"] for p in range(6)]
    print(f"   serve4 req {k} only   :", summ(v, 3))
ov6 = [data["serve6"][0][(p, k)]["seal"] for p in range(6) for k in range(1, 6)]
print("serve6 reqs 1..5 (n=30)  :", summ(ov6, 3))
for k in range(0, 6):
    v = [data["serve6"][0][(p, k)]["seal"] for p in range(6)]
    print(f"   serve6 req {k} only   :", summ(v, 3))
print("ratio serve4 ov / serve1 solo  = %.3f ; ratio serve4 ov / serve4 req0 = %.3f" % (q(ov4, .5) / q(solo1, .5), q(ov4, .5) / q(solo4, .5)))
print("pooled solo (serve1 + serve4 req0, n=12): ", summ(solo1 + solo4, 3))
print("MIXING CHECK: do any of the serve4 'overlapped' sealing passes run with no prover beside them?")
for p in range(6):
    r = data["serve4"][0]
    for k in (1, 2, 3):
        prev_pe = r[(p, k - 1)]["pe"]
        turn = r[(p, k)]["turn"]
        sdone = r[(p, k)]["sdone"]
        beside = max(0.0, min(sdone, prev_pe) - turn)
        frac = beside / (sdone - turn)
        if p == 0:
            print(f"  pass0 req{k}: sealing {turn:.3f}-{sdone:.3f}, previous prover ends {prev_pe:.3f}; share of sealing with previous prover running = {frac:.3f}")
print("share of the overlapped sealing span that has the previous request's prover running (all 18):")
fr = []
for p in range(6):
    r = data["serve4"][0]
    for k in (1, 2, 3):
        # prover of request k-1 runs [ps(k-1), pe(k-1)]
        a, b = r[(p, k - 1)]["ps"], r[(p, k - 1)]["pe"]
        turn, sd = r[(p, k)]["turn"], r[(p, k)]["sdone"]
        ov = max(0.0, min(sd, b) - max(turn, a))
        fr.append(ov / (sd - turn))
print("   ", summ(fr, 3))

print("\n== B. stream cadence and tok/s")
for name in ("serve4", "serve6"):
    reqs, strs = data[name]
    n = R[name]
    cad = [(reqs[(p, n - 1)]["res"] - reqs[(p, 0)]["res"]) / (n - 1) for p in range(6)]
    print(name, "cadence (res[last]-res[0])/(R-1):", summ(cad, 4), " tok/s=128/cad:", summ([128 / c for c in cad], 2))
    print(name, "log 'steady' tok/s per pass:", [strs[p]["steady"] for p in range(6)], " median", q([strs[p]["steady"] for p in range(6)], .5))
    L = LANES[name]
    post = [(reqs[(p, n - 1)]["res"] - reqs[(p, L - 1)]["res"]) / (n - L) for p in range(6)]
    print(name, f"post-fill cadence (q>= {L}):", summ(post, 4), " tok/s:", summ([128 / c for c in post], 2))
    # per-request steady intervals (all q>=1)
    iv = [reqs[(p, k)]["res"] - reqs[(p, k - 1)]["res"] for p in range(6) for k in range(1, n)]
    print(name, "per-request result intervals (all q>=1):", summ(iv, 3))
    pc = [reqs[(p, k)]["pc"] for p in range(6) for k in range(1, n)]
    print(name, "prove call q>=1:", summ(pc, 3))
    pc_all = [reqs[(p, k)]["pc"] for p in range(6) for k in range(0, n)]
    print(name, "prove call q>=0:", summ(pc_all, 3))
    fk = [reqs[(p, k)]["forks"] for p in range(6) for k in range(1, n - 1)]
    print(name, "forks mid (q=1..R-2):", summ(fk, 3))
    fl = [reqs[(p, n - 1)]["forks"] for p in range(6)]
    print(name, "forks last request:", summ(fl, 3))
    wr = [reqs[(p, k)]["w"] for p in range(6) for k in range(0, n)]
    print(name, "receipt write W:", summ(wr, 3))
    sl = [reqs[(p, k)]["wait"] for p in range(6) for k in range(1, n)]
    print(name, "prover 'waited' q>=1 (prover_start - seal_done):", summ(sl, 3))
    adm = [max(0.0, reqs[(p, k)]["turn"] - reqs[(p, k - 1)]["sdone"]) for p in range(6) for k in range(L, n)]
    print(name, f"lane admission wait seal_turn(q)-seal_done(q-1), q>={L}:", summ(adm, 3))
    am = [strs[p]["am"] for p in range(6)]
    print(name, "amortized tok/s:", summ(am, 2))
    wall = [strs[p]["wall"] for p in range(6)]
    print(name, "pass wall:", summ(wall, 3), " per req:", summ([w / n for w in wall], 4))
    print(name, "footprint peak:", summ([strs[p]["fp"] for p in range(6)], 2), " user:", summ([strs[p]["u"] for p in range(6)], 1), " sys:", summ([strs[p]["sy"] for p in range(6)], 1))
s1strs = data["serve1"][1]
print("serve1 sys per pass:", summ([s1strs[p]["sy"] for p in range(6)], 1), " user:", summ([s1strs[p]["u"] for p in range(6)], 1), " wall:", summ([s1strs[p]["wall"] for p in range(6)], 3))
print("serve1 footprint peak:", summ([s1strs[p]["fp"] for p in range(6)], 2))
print("serve1 amortized wall per request:", summ([s1strs[p]["wall"] for p in range(6)], 3))

print("\n== C. lanes3 vs lanes2: difference and spread")
c2 = []
c3 = []
for name, store in (("serve4", c2), ("serve6", c3)):
    reqs, _ = data[name]
    n = R[name]
    for p in range(6):
        store.append((reqs[(p, n - 1)]["res"] - reqs[(p, 0)]["res"]) / (n - 1))
print("cadence lanes2 per pass:", [round(x, 4) for x in c2])
print("cadence lanes3 per pass:", [round(x, 4) for x in c3])
print("median lanes2 %.4f lanes3 %.4f ratio %.4f" % (q(c2, .5), q(c3, .5), q(c2, .5) / q(c3, .5)))
print("means lanes2 %.4f lanes3 %.4f" % (st.mean(c2), st.mean(c3)))
# permutation-style: Welch t
def welch(a, b):
    ma, mb = st.mean(a), st.mean(b)
    va, vb = st.variance(a), st.variance(b)
    se = (va / len(a) + vb / len(b)) ** .5
    return (mb - ma) / se, ma, mb, se
t, ma, mb, se = welch(c2, c3)
print("Welch t = %.2f (diff %.4f s, se %.4f). |t| < ~2.3 means not distinguishable at n=6 vs 6." % (t, mb - ma, se))
# per-request interval comparison on the SAME requests (q 1..3) between arms
print("Note: serve6 steady cadence averages requests 1..5; serve4 averages 1..3. Different request mixes.")
# like for like: lanes3 requests 1..3 vs lanes2 requests 1..3 individual intervals
for name in ("serve4", "serve6"):
    reqs, _ = data[name]
    for k in (1, 2, 3, 4, 5):
        if (0, k) in reqs:
            iv = [reqs[(p, k)]["res"] - reqs[(p, k - 1)]["res"] for p in range(6)]
            print(f"  {name} interval res[{k}]-res[{k-1}]:", summ(iv, 3))

print("\n== D. Batch 6 consistency (Batch 6: serve1 6.093 s; serve4 steady cadence 3.606 s; seal alone 2.172; seal overlapped 3.321; P 3.626)")
r1 = [data["serve1"][0][(p, 0)]["res"] for p in range(6)]
print("serve1 wall/request now:", summ(r1, 3), " Batch 6 6.093")
print("serve4 steady cadence now: %.3f ; Batch 6 3.606 -> drift %+.3f s (%+.1f%%)" % (q(c2, .5), q(c2, .5) - 3.606, 100 * (q(c2, .5) / 3.606 - 1)))
print("serve1 seal now %.3f vs Batch6 2.172 ; serve4 ov seal now %.3f vs Batch 6 3.321" % (q(solo1, .5), q(ov4, .5)))

print("\n== E. cadence model max(P,(S+W+P)/L)")
reqs4, _ = data["serve4"]
S = q(ov4, .5)
W = q([reqs4[(p, k)]["w"] for p in range(6) for k in range(1, 4)], .5)
P = q([reqs4[(p, k)]["pc"] for p in range(6) for k in range(1, 4)], .5)
print(f"serve4 medians S_ov={S:.3f} W={W:.3f} P_ov(q1..3)={P:.3f}")
print("  lanes2: (S+W+P)/2 = %.3f ; max(P, .) = %.3f ; measured median cadence %.3f" % ((S + W + P) / 2, max(P, (S + W + P) / 2), q(c2, .5)))
print("  lanes3: (S+W+P)/3 = %.3f ; max(P,S_ov?) ..." % ((S + W + P) / 3))
reqs6, _ = data["serve6"]
S6 = q(ov6, .5)
W6 = q([reqs6[(p, k)]["w"] for p in range(6) for k in range(1, 6)], .5)
P6 = q([reqs6[(p, k)]["pc"] for p in range(6) for k in range(1, 6)], .5)
print(f"serve6 medians S_ov={S6:.3f} W={W6:.3f} P_ov(q1..5)={P6:.3f}; lanes3: (S+W+P)/3 = {(S6+W6+P6)/3:.3f}; measured {q(c3,.5):.3f}")
print("Report claim: 'S_ov = 3.231 s is the hard ceiling'. The report's own cadence (3.739) is above both S_ov (3.231) and (S+W+P)/3 (%.3f) -> P-bound." % ((S6 + W6 + P6) / 3))
# what does the 'ceiling' arithmetic say for a faster prover P'?
for Pp in (3.2, 3.0, 2.8, 2.5, 2.0):
    print(f"   P'={Pp}: lanes2 cadence max(P',(S+W+P')/2)={max(Pp,(S+W+Pp)/2):.3f} ; lanes3 max(P',(S+W+P')/3, S_ov?)={max(Pp,(S+W+Pp)/3, S):.3f}  (S held fixed at today's overlapped value)")
print("ratio of 3.231 to 3.668 (report says 1.135x):", round(3.668 / 3.231, 3))
