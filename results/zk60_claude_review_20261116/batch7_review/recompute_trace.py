#!/usr/bin/env python3
"""Batch 7 review: recompute the phase split and the overlap decomposition from the retained GPU traces.

Standard library only; read-only; prints to the screen.  Run:  python3 -I recompute_trace.py
It does NOT import the author's script.  The decomposition follows the report's definitions
(P1..P9 from the begin/done times of the 224 'wprod' command buffers of each request) so that the
numbers can be compared; extra checks are marked CHECK.
"""
import gzip
import hashlib
import re
import statistics as st
from pathlib import Path

D = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_batch7_sealing_lanes3_20261117")
T = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")
ARMS = {
    "serve1": ("serve1_6warm.15048.tsv.gz", "batch7_serve1_6warm.log", 1, 2),
    "serve4": ("serve4_lanes2_6warm.15818.tsv.gz", "batch7_serve4_lanes2_6warm.log", 4, 2),
    "serve6": ("serve6_lanes3_6warm.16734.tsv.gz", "batch7_serve6_lanes3_6warm.log", 6, 3),
}
REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(?P<arm>[^\]]+)\] (?:pass (?P<p>\d+) request (?P<q>\d+)|cold request (?P<cq>\d+)): "
    r"arrived (?P<arr>[0-9.]+), sealing turn (?P<turn>[0-9.]+), sealing side done (?P<sdone>[0-9.]+) \(sealing pass (?P<seal>[0-9.]+) s\)")


def q(v, p):
    s = sorted(v)
    pos = p * (len(s) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def med(v):
    return q(v, .5)


def iqr(v):
    return q(v, .75) - q(v, .25)


def load_trace(path):
    rows = []
    with gzip.open(path, "rt") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p[0] == "tag" or len(p) != 9:
                continue
            kv = dict(tok.split("=", 1) for tok in p[1].split() if "=" in tok)
            rows.append(dict(tag=p[0], detail=p[1], th=int(p[2]), qu=int(p[3]), b=float(p[4]), c=float(p[5]), gs=float(p[6]), ge=float(p[7]), d=float(p[8]), kv=kv))
    return rows


def union_len(iv, lo=None, hi=None):
    """total length of the union of intervals (a, b), clipped to [lo, hi]"""
    ev = []
    for a, b in iv:
        if lo is not None:
            a = max(a, lo)
            b = min(b, hi)
        if b > a:
            ev.append((a, 1))
            ev.append((b, -1))
    ev.sort(key=lambda e: (e[0], -e[1]))
    depth = 0
    last = None
    tot = 0.0
    for t, dlt in ev:
        if depth > 0:
            tot += t - last
        depth += dlt
        last = t
    return tot


def group_parts(grp):
    """(wall, gpu_busy_union, queue_wait_not_busy, host_rest) for one parallel wprod group, report's definition"""
    b0 = min(r["b"] for r in grp)
    d1 = max(r["d"] for r in grp)
    wall = d1 - b0
    ev = []
    for r in grp:
        if r["gs"] > 0 and r["ge"] > r["gs"]:
            a, b = max(b0, min(d1, r["gs"])), max(b0, min(d1, r["ge"]))
            if b > a:
                ev += [(a, "g", 1), (b, "g", -1)]
        if r["c"] > 0 and r["gs"] > r["c"]:
            a, b = max(b0, min(d1, r["c"])), max(b0, min(d1, r["gs"]))
            if b > a:
                ev += [(a, "q", 1), (b, "q", -1)]
    ev.sort(key=lambda e: e[0])
    g = qd = 0
    last = b0
    busy = qw = 0.0
    for t, k, dl in ev:
        dt = t - last
        if dt > 0:
            if g > 0:
                busy += dt
            elif qd > 0:
                qw += dt
        if k == "g":
            g += dl
        else:
            qd += dl
        last = t
    return wall, busy, qw, max(0.0, wall - busy - qw)


def parse_log(path):
    out = {}
    for m in REQ.finditer(Path(path).read_text()):
        g = m.groupdict()
        key = ("cold", 0) if g["p"] is None else (int(g["p"]), int(g["q"]))
        out[key] = dict(turn=float(g["turn"]), sdone=float(g["sdone"]), seal=float(g["seal"]))
    return out


def decompose(chunk, logrec, nonw):
    ws = sorted(chunk, key=lambda r: r["b"])
    blocks = [ws[7 * i:7 * i + 7] for i in range(32)]
    P = dict(p1=0, p2=0, p3=0, p4=0, p5=0, p6=0, p7=0, p8a=0, busy=0, qw=0, hin=0)
    gaps = []
    pre = {"qkv": [], "wo": [], "gu": [], "wd": []}  # the host gap that precedes each group (includes the prelude before 'begin')
    for i, blk in enumerate(blocks):
        qkv, wo, gu, wd = blk[0:3], blk[3], blk[4:6], blk[6]
        # CHECK shapes
        assert sorted((int(r["kv"]["k"]), int(r["kv"]["n"])) for r in qkv) == [(4096, 1024), (4096, 1024), (4096, 4096)], qkv
        assert (int(wo["kv"]["k"]), int(wo["kv"]["n"])) == (4096, 4096)
        assert sorted((int(r["kv"]["k"]), int(r["kv"]["n"])) for r in gu) == [(4096, 16384)] * 2
        assert (int(wd["kv"]["k"]), int(wd["kv"]["n"])) == (16384, 4096)
        qd1 = max(r["d"] for r in qkv)
        assert wo["b"] >= qd1 - 1e-6
        gb0 = min(r["b"] for r in gu)
        assert gb0 >= wo["d"] - 1e-6
        gd1 = max(r["d"] for r in gu)
        assert wd["b"] >= gd1 - 1e-6
        if i > 0:
            g = min(r["b"] for r in qkv) - blocks[i - 1][6]["d"]
            assert g > -1e-6
            P["p8a"] += max(0, g)
            gaps.append(g)
        for key, grp in (("p1", qkv), ("p3", [wo]), ("p5", gu), ("p7", [wd])):
            w, b, qw, h = group_parts(grp)
            P[key] += w
            P["busy"] += b
            P["qw"] += qw
            P["hin"] += h
        P["p2"] += wo["b"] - qd1
        P["p4"] += gb0 - wo["d"]
        P["p6"] += wd["b"] - gd1
    first = min(r["b"] for r in blocks[0][:3])
    last = blocks[31][6]["d"]
    chain = last - first
    P["chain"] = chain
    P["p8b"] = max(0.0, logrec["seal"] - chain)
    P["p8"] = P["p8a"] + P["p8b"]
    P["seal"] = logrec["seal"]
    P["side"] = logrec["sdone"] - logrec["turn"]
    P["p9"] = P["side"] - P["seal"]
    P["wall4"] = P["p1"] + P["p3"] + P["p5"] + P["p7"]
    P["mid"] = P["p2"] + P["p4"] + P["p6"]
    P["host_total"] = P["mid"] + P["p8"] + P["hin"]
    P["sum_spans"] = sum(max(0.0, r["ge"] - r["gs"]) for r in ws if r["gs"] > 0)
    # prover GPU busy beside this request's wprod chain
    P["prov_busy"] = union_len([(r["gs"], r["ge"]) for r in nonw if r["gs"] > 0 and r["ge"] >= r["gs"]], first, last)
    P["gaps"] = gaps
    P["residual_check"] = (P["p1"] + P["p2"] + P["p3"] + P["p4"] + P["p5"] + P["p6"] + P["p7"] + P["p8"]) - P["seal"]
    # CHECK: sum of per-CB commit->gpu_start waits (all 224), and per-CB encode (begin->commit), wake (done-ge)
    P["cb_commit_to_gs_sum"] = sum(max(0.0, r["gs"] - r["c"]) for r in ws)
    P["cb_encode_sum"] = sum(max(0.0, r["c"] - r["b"]) for r in ws)
    P["cb_wake_sum"] = sum(max(0.0, r["d"] - r["ge"]) for r in ws)
    P["cb_gpu_gs_to_ge_sum"] = sum(max(0.0, r["ge"] - r["gs"]) for r in ws)
    return P


results = {}
for arm, (gz, lg, R, L) in ARMS.items():
    path = T / gz
    print(f"\n######## {arm}: sha256 {hashlib.sha256(path.read_bytes()).hexdigest()}")
    rows = load_trace(path)
    print("rows", len(rows))
    wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
    extra = len(wp) - 224 * (1 + 6 * R)
    print("t=128 wprods", len(wp), "expected per-request", 224 * (1 + 6 * R), "extra (startup)", extra)
    wp = wp[extra:]
    nonw = [r for r in rows if r["tag"] != "wprod"]
    log = parse_log(D / lg)
    order = [("cold", 0)] + [(p, k) for p in range(6) for k in range(R)]
    dec = {}
    for i, key in enumerate(order):
        chunk = wp[224 * i:224 * (i + 1)]
        # per-pass prover buffers: use the whole trace's non-wprod rows (clipped to the request's wprod window inside)
        dec[key] = decompose(chunk, log[key], nonw)
    results[arm] = dec
    # CHECK: chunk boundaries: the first block of request i+1 starts after the last Wd done of request i
    bad = 0
    for i in range(len(order) - 1):
        a = wp[224 * i:224 * (i + 1)]
        b = wp[224 * (i + 1):224 * (i + 2)]
        if min(r["b"] for r in b) < max(r["d"] for r in a):
            bad += 1
    print("CHECK request chunks overlap in time (should be 0):", bad)
    print("CHECK max |sum(P1..P8) - seal_pass| over requests (should be 0 by construction):", max(abs(d["residual_check"]) for d in dec.values()))
    print("CHECK min P8b (bookend residual = seal_pass - chain span):", min(d["p8b"] for d in dec.values()), " (<0 would be clipped to 0)")

KEYS = [("seal", "seal_pass_s"), ("side", "seal_side_total"), ("p1", "P1 QKV wall"), ("p2", "P2 host"), ("p3", "P3 Wo wall"), ("p4", "P4 host"), ("p5", "P5 GU wall"),
        ("p6", "P6 host"), ("p7", "P7 Wd wall"), ("p8", "P8 total"), ("p8a", "P8a 31 gaps"), ("p8b", "P8b bookends (residual)"), ("p9", "P9 side-pass"),
        ("wall4", "wprod 4-group wall"), ("busy", "wprod GPU busy union"), ("qw", "wprod queue wait"), ("hin", "wprod host inside (encode+wake+rest)"),
        ("mid", "P2+P4+P6"), ("host_total", "host total"), ("prov_busy", "prover GPU busy beside"), ("sum_spans", "wprod summed spans"),
        ("cb_commit_to_gs_sum", "sum of 224 commit->gs"), ("cb_encode_sum", "sum of 224 begin->commit"), ("cb_wake_sum", "sum of 224 done-ge"),
        ("chain", "chain span (first QKV begin .. last Wd done)")]


def sets(arm):
    d = results[arm]
    solo = [d[(p, 0)] for p in range(6)]
    ov = [d[(p, k)] for p in range(6) for k in range(1, ARMS[arm][2])]
    return solo, ov


s1_solo, _ = sets("serve1")
s4_solo, s4_ov = sets("serve4")
_, s6_ov = sets("serve6")
print("\n=== TABLE (medians; n shown) : serve1 solo(6) | serve4 req0(6) | serve4 ov(18) | serve6 ov(30) | serve6 req0(6)")
s6_solo, _x = sets("serve6")
print(f"{'metric':44s} {'s1solo':>9s} {'s4req0':>9s} {'s4ov':>9s} {'s6ov':>9s} {'s6req0':>9s}   iqr(s1,s4ov)")
for k, nm in KEYS:
    a = [x[k] for x in s1_solo]
    b = [x[k] for x in s4_solo]
    c = [x[k] for x in s4_ov]
    e = [x[k] for x in s6_ov]
    f = [x[k] for x in s6_solo]
    print(f"{nm:44s} {med(a):9.4f} {med(b):9.4f} {med(c):9.4f} {med(e):9.4f} {med(f):9.4f}   {iqr(a):.4f} {iqr(c):.4f}")

print("\n=== shares of serve1 solo seal_pass (median of parts / median of whole)")
tot = med([x["seal"] for x in s1_solo])
for k in ("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p8a", "p8b", "wall4", "busy", "qw", "hin", "mid", "host_total"):
    print(f"  {k:10s} {med([x[k] for x in s1_solo]):.4f}  {100*med([x[k] for x in s1_solo])/tot:5.1f}%")
print("  sum of the nine medians P1..P8 =", sum(med([x[k] for x in s1_solo]) for k in ("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8")), "vs median seal", tot)
print("  CHECK per-pass shares (P8/seal) for serve1 passes:", [round(x["p8"] / x["seal"], 3) for x in s1_solo])
print("  CHECK host share 'total host / seal' per pass:", [round(x["host_total"] / x["seal"], 3) for x in s1_solo])

print("\n=== overlap decomposition: serve4 ov vs serve1 solo (the report's baseline) and vs serve4 req0 (in-process)")
for base_name, base in (("serve1 solo", s1_solo), ("serve4 req0", s4_solo)):
    dtot = med([x["seal"] for x in s4_ov]) - med([x["seal"] for x in base])
    print(f"--- baseline {base_name}: delta seal_pass (median ov - median base) = {dtot:.4f}")
    comp = [("queue wait (wprod)", "qw"), ("P8", "p8"), ("P2+P4+P6", "mid"), ("wprod GPU busy", "busy"), ("wprod host inside", "hin")]
    ssum = 0
    for nm, k in comp:
        dd = med([x[k] for x in s4_ov]) - med([x[k] for x in base])
        ssum += dd
        print(f"   {nm:22s} {dd:+.4f}  {100*dd/dtot:5.1f}%")
    print(f"   sum of five                  {ssum:+.4f}  {100*ssum/dtot:5.1f}%   unexplained {dtot-ssum:+.4f} ({100*(dtot-ssum)/dtot:.1f}%)")
    # identity check with means (parts must add exactly to the delta of means, modulo P8b clip)
    dm = st.mean([x["seal"] for x in s4_ov]) - st.mean([x["seal"] for x in base])
    sm = sum(st.mean([x[k] for x in s4_ov]) - st.mean([x[k] for x in base]) for _, k in comp)
    print(f"   delta of MEANS: total {dm:.4f}, sum of five parts {sm:.4f} (means add exactly; medians need not)")
    print(f"   CHECK P8 delta split: P8a {med([x['p8a'] for x in s4_ov])-med([x['p8a'] for x in base]):+.4f} P8b {med([x['p8b'] for x in s4_ov])-med([x['p8b'] for x in base]):+.4f}")
    # the P9 / side residue is outside seal_pass, so not part of this
print("\nCHECK serve4: do the 'overlapped' requests 1..3 differ by position (req1 sealing has req0's prover; later have prior reqs')")
for k in (1, 2, 3):
    v = [results["serve4"][(p, k)] for p in range(6)]
    print(f"   req{k}: seal {med([x['seal'] for x in v]):.3f}  P8 {med([x['p8'] for x in v]):.3f} qw {med([x['qw'] for x in v]):.3f} mid {med([x['mid'] for x in v]):.3f} busy {med([x['busy'] for x in v]):.3f} provbusy {med([x['prov_busy'] for x in v]):.3f}")

print("\n=== P8 gap by block (serve1 solo, median over the 6 passes of gap k->k+1, ms)")
g = [[x["gaps"][i] * 1000 for x in s1_solo] for i in range(31)]
print("  ", [round(med(v), 1) for v in g])
print("  first 3 / last 3 / middle median:", [round(med(v), 1) for v in g[:3]], [round(med(v), 1) for v in g[-3:]], round(med([med(v) for v in g[3:-3]]), 1))
print("  per-pass sum of P8a/31 (ms/gap):", [round(x["p8a"] / 31 * 1000, 2) for x in s1_solo])

print("\n=== queue-wait definition CHECK (serve1 solo)")
print("  mean commit->GPUStart per CB (all 224, ms): ", round(1000 * med([x["cb_commit_to_gs_sum"] for x in s1_solo]) / 224, 3))
print("  sum over 224 CBs of commit->gs (s): median", round(med([x["cb_commit_to_gs_sum"] for x in s1_solo]), 4), " vs 'queue wait' (group union, not busy)", round(med([x["qw"] for x in s1_solo]), 4))
print("  sum of begin->commit (encode) (s):", round(med([x["cb_encode_sum"] for x in s1_solo]), 4), "  sum of done-gpu_end (wake) (s):", round(med([x["cb_wake_sum"] for x in s1_solo]), 4))
print("  'wprod host inside' (s):", round(med([x["hin"] for x in s1_solo]), 4), " -> encode + wake over the 128 groups is about", round(med([x["cb_encode_sum"] for x in s1_solo]) + med([x["cb_wake_sum"] for x in s1_solo]), 4), "(224 CBs)")

# CHECK how much of the commit->GPU-start gap in solo is a single first-CB effect (clock ramp) vs every CB
print("\n=== per-CB commit->gpu_start (ms) in serve1 warm passes, by position in group (Q,K,V | Wo | Wg,Wu | Wd): median")
pos = {"Q/K/V first": [], "Q/K/V later": [], "Wo": [], "Wg/Wu first": [], "Wg/Wu second": [], "Wd": []}
# rebuild from trace (solo passes)
rows = load_trace(T / ARMS["serve1"][0])
wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
wp = wp[len(wp) - 224 * 7:]
for i in range(1, 7):  # warm passes
    ch = wp[224 * i:224 * (i + 1)]
    for b in range(32):
        blk = ch[7 * b:7 * b + 7]
        qk = sorted(blk[0:3], key=lambda r: r["b"])
        gl = lambda r: 1000 * (r["gs"] - r["c"])
        pos["Q/K/V first"].append(gl(qk[0]))
        pos["Q/K/V later"] += [gl(qk[1]), gl(qk[2])]
        pos["Wo"].append(gl(blk[3]))
        gu = sorted(blk[4:6], key=lambda r: r["b"])
        pos["Wg/Wu first"].append(gl(gu[0]))
        pos["Wg/Wu second"].append(gl(gu[1]))
        pos["Wd"].append(gl(blk[6]))
for k, v in pos.items():
    print(f"   {k:14s} n={len(v):4d} median {med(v):.3f} ms  mean {st.mean(v):.3f}  p90 {q(v,.9):.3f}")

# --- Section 4: per-slot spans from serve1
print("\n=== Section 4 recompute: per-slot GPU spans from serve1 trace")
rows = load_trace(T / ARMS["serve1"][0])
b = [r for r in rows if r["tag"] == "batch"]
slot_re = re.compile(r"slot (\d+) \(([^)]*(?:\([^)]*\))?[^)]*)\)")
# warm passes: split by commit rows with 2606 rows: 32 per request; 7 requests incl cold
comm = [(i, r) for i, r in enumerate(rows) if r["tag"] == "commit" and r["kv"].get("rows") == "2606"]
print("H-commit rows in serve1 trace:", len(comm))
# order rows by 'done' to cut passes
srt = sorted(rows, key=lambda r: r["d"])
hc = [i for i, r in enumerate(srt) if r["tag"] == "commit" and r["kv"].get("rows") == "2606"]
# 7 requests x 32 H commits
bounds = [hc[32 * k + 31] for k in range(7)]
start = 0
per_pass = []
for k in range(7):
    seg = srt[start:bounds[k] + 1] if k < 6 else srt[start:]
    start = bounds[k] + 1
    per_pass.append(seg)
slot_ms = {}
slot_conc = {}
for k in range(1, 7):
    acc = {}
    ivs = {}
    for r in per_pass[k]:
        if r["tag"] == "batch":
            m = re.match(r"slot (\d+) ", r["detail"])
            if not m:
                continue
            s = int(m.group(1))
            lab = r["detail"].split(" at ")[0]
            acc.setdefault((s, lab), 0.0)
            acc[(s, lab)] += max(0.0, r["ge"] - r["gs"])
            ivs.setdefault((s, lab), []).append((r["gs"], r["ge"]))
    for key, v in acc.items():
        slot_ms.setdefault(key, []).append(v / 32 * 1000)
        slot_conc.setdefault(key, []).append(v / union_len(ivs[key]) if union_len(ivs[key]) > 0 else 0)
tot = []
for key in sorted(slot_ms, key=lambda k: -med(slot_ms[k])):
    print(f"  slot {key[0]:2d} {key[1][:52]:52s} median {med(slot_ms[key]):8.3f} ms/blk  iqr {iqr(slot_ms[key]):.3f}  mean {st.mean(slot_ms[key]):.3f}   (sum-of-spans / union-of-spans over the pass: {med(slot_conc[key]):.2f})")
print("  slots 14..18 sum of medians:", round(sum(med(slot_ms[k]) for k in slot_ms if 14 <= k[0] <= 18), 3), " slot 19:", round(sum(med(slot_ms[k]) for k in slot_ms if k[0] == 19), 3), " all:", round(sum(med(v) for v in slot_ms.values()), 3))
# GPU busy union / wall of prover part in serve1 for context
bs = [r for r in per_pass[3] if r["tag"] != "wprod"]
span = max(r["d"] for r in bs) - min(r["b"] for r in bs)
print("  CHECK prover-side span of one pass (first begin to last done):", round(span, 3), "s; union of GPU spans:", round(union_len([(r['gs'], r['ge']) for r in bs if r['gs'] > 0]), 3))

# ---- appended: mean-based shares of the overlap decomposition (parts add exactly on means)
print("\n=== overlap decomposition on MEANS (parts add exactly): serve4 ov (n=18) minus baseline")
for base_name, base in (("serve1 solo (n=6)", s1_solo), ("serve4 req0 (n=6)", s4_solo)):
    dm = st.mean([x["seal"] for x in s4_ov]) - st.mean([x["seal"] for x in base])
    print(f"--- baseline {base_name}: delta of means = {dm:.4f}")
    for nm, k in [("queue wait", "qw"), ("P8", "p8"), ("P2+P4+P6", "mid"), ("wprod GPU busy", "busy"), ("wprod host inside", "hin")]:
        dd = st.mean([x[k] for x in s4_ov]) - st.mean([x[k] for x in base])
        print(f"   {nm:18s} {dd:+.4f} {100*dd/dm:5.1f}%")
# spread: each part's overlapped per-request values vs. the baseline range
print("\n=== is the serve1 vs serve4-req0 difference in solo sealing noise? (median 2.215 vs 2.152, n=6 each)")
print("  serve1 per-pass:", [x['seal'] for x in s1_solo])
print("  serve4 req0   :", [x['seal'] for x in s4_solo])
print("  serve6 req0   :", [x['seal'] for x in s6_solo])
print("  P8 solo per-request: serve1", [round(x['p8'],3) for x in s1_solo], " serve4 req0", [round(x['p8'],3) for x in s4_solo], " serve6 req0", [round(x['p8'],3) for x in s6_solo])
# bootstrap-free sensitivity: use pooled solo (serve1 + serve4 req0 + serve6 req0, n=18) as the baseline
pool = s1_solo + s4_solo + s6_solo
print("  pooled solo n=18 median seal %.4f P8 %.4f qw %.4f mid %.4f busy %.4f" % (med([x['seal'] for x in pool]), med([x['p8'] for x in pool]), med([x['qw'] for x in pool]), med([x['mid'] for x in pool]), med([x['busy'] for x in pool])))
dm = st.mean([x["seal"] for x in s4_ov]) - st.mean([x["seal"] for x in pool])
print(f"  mean shares vs pooled solo: total {dm:.4f}; " + ", ".join(f"{nm} {100*(st.mean([x[k] for x in s4_ov])-st.mean([x[k] for x in pool]))/dm:.1f}%" for nm, k in [("qw", "qw"), ("P8", "p8"), ("mid", "mid"), ("busy", "busy"), ("hin", "hin")]))
