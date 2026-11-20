#!/usr/bin/env python3
"""Reviewer recomputation of the Batch 6 stream numbers from the author's raw log lines.

Reads results/zk60_h132_batched_forward_20261116/batch6_stream_serve1_6warm.log and ..._serve4_6warm.log
and BATCH6_HEAD_PROFILE_METRICS.json. Run: python3 -I <this file>. Writes nothing.
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


def mi(v):
    return round(pct(v, 0.5), 4), round(pct(v, 0.75) - pct(v, 0.25), 4)


req_re = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(serve1|serve4)\] pass (\d+) request (\d+): arrived ([0-9.]+), sealing turn ([0-9.]+), "
    r"sealing side done ([0-9.]+) \(sealing pass ([0-9.]+) s\), prover ([0-9.]+)-([0-9.]+) \(waited ([0-9.]+) s; "
    r"prove call ([0-9.]+) s: preflight ([0-9.]+), commit ([0-9.]+), forks ([0-9.]+), join ([0-9.]+)\), receipt write ([0-9.]+) s \(\d+ writers\), result ([0-9.]+);"
)
stream_re = re.compile(r"A22-AB STREAM \S+ L32 N6 \[(serve1|serve4)\] pass (\d+): (\d+) requests in ([0-9.]+) s .*?steady ([0-9.NaN]+) tok/s; amortized ([0-9.]+) tok/s")


def load(path):
    txt = open(path).read()
    reqs = {}
    for m in req_re.finditer(txt):
        arm, p, q = m.group(1), int(m.group(2)), int(m.group(3))
        keys = ["arrived", "turn", "seal_done", "seal_s", "p0", "p1", "waited", "prove_call", "pre", "commit", "forks", "join", "write", "result"]
        reqs[(p, q)] = dict(zip(keys, map(float, m.groups()[3:])))
    streams = {}
    for m in stream_re.finditer(txt):
        streams[int(m.group(2))] = dict(n=int(m.group(3)), wall=float(m.group(4)), steady=float(m.group(5)), amort=float(m.group(6)))
    return reqs, streams


# ------------------------------------------------------------------ serve1
r1, s1 = load(R + "batch6_stream_serve1_6warm.log")
print("serve1: warm passes", sorted(s1), "requests", len(r1))
wall1 = [s1[p]["wall"] for p in sorted(s1)]
seal1 = [r1[(p, 0)]["seal_s"] for p in sorted(s1)]
pc1 = [r1[(p, 0)]["prove_call"] for p in sorted(s1)]
fk1 = [r1[(p, 0)]["forks"] for p in sorted(s1)]
wr1 = [r1[(p, 0)]["write"] for p in sorted(s1)]
print("  wall/request median,IQR", mi(wall1), " tok/s", mi([128 / w for w in wall1]))
print("  sealing pass", mi(seal1), "share of wall", mi([100 * a / b for a, b in zip(seal1, wall1)]))
print("  prove call", mi(pc1), "forks", mi(fk1), "write", mi(wr1))
print("  seal + prove + write vs wall:", [round(a + b + c, 3) for a, b, c in zip(seal1, pc1, wr1)], wall1)

# ------------------------------------------------------------------ serve4
r4, s4 = load(R + "batch6_stream_serve4_6warm.log")
P = sorted(s4)
print("\nserve4: warm passes", P, "requests", len(r4))
cad = []
for p in P:
    done = [r4[(p, q)]["result"] for q in range(4)]
    cad.append((done[3] - done[0]) / 3)
print("  steady cadence per request", mi(cad), " tok/s", mi([128 / c for c in cad]), "(log's own steady tok/s:", mi([s4[p]["steady"] for p in P]), ")")
print("  amortized wall/request", mi([s4[p]["wall"] / 4 for p in P]), "amortized tok/s", mi([s4[p]["amort"] for p in P]))
print("  note: 'tokens' = 128 per request, so tok/s = 128 / s")

allq = [(p, q) for p in P for q in range(4)]
print("  sealing pass, mean of the four requests per pass (author's number):", mi([sum(r4[(p, q)]["seal_s"] for q in range(4)) / 4 for p in P]))
print("  sealing pass of request 0 (unoverlapped, 4 passes):", mi([r4[(p, 0)]["seal_s"] for p in P]))
steady_seal = [r4[(p, q)]["seal_s"] for p in P for q in (1, 2, 3)]
print("  sealing pass of requests 1-3 (overlapped with proving), 18 values:", mi(steady_seal), "min", min(steady_seal), "max", max(steady_seal))
print("  solo sealing pass for comparison (serve1)", mi(seal1), "-> overlap slowdown x", round(mi(steady_seal)[0] / mi(seal1)[0], 3))
pc_all = [sum(r4[(p, q)]["prove_call"] for q in range(4)) / 4 for p in P]
print("  prove call, mean of four per pass (author's number)", mi(pc_all))
pc_steady = [r4[(p, q)]["prove_call"] for p in P for q in (1, 2, 3)]
pc_req0 = [r4[(p, 0)]["prove_call"] for p in P]
print("  prove call requests 1-3:", mi(pc_steady), " request 0:", mi(pc_req0))
wr_all = [r4[k]["write"] for k in allq]
print("  receipt write", mi(wr_all))

# 18/18 claim, two readings
wait_author = []
for p in P:
    for q in (1, 2, 3):
        wait_author.append(max(0.0, r4[(p, q)]["seal_done"] - r4[(p, q - 1)]["p1"]))
print("\n  author's 'unhidden wait' = max(0, seal_done(q) - prover_end(q-1)) over 18:", wait_author.count(0.0), "of", len(wait_author), "are 0.000")
print("  log's own 'waited' column (prover start - sealing done; positive = sealed work waited for the prover):",
      [r4[(p, q)]["waited"] for p in P for q in (1, 2, 3)])
slack = [r4[(p, q)]["p0"] - r4[(p, q)]["seal_done"] for p in P for q in (1, 2, 3)]
print("  slack (prover start - seal done) per steady request: min", round(min(slack), 3), "median,IQR", mi(slack), "max", round(max(slack), 3))
print("  slack as share of prove call: median", round(100 * pct(slack, .5) / pct(pc_steady, .5), 1), "%")
by_q = {q: mi([r4[(p, q)]["waited"] for p in P]) for q in (1, 2, 3)}
print("  slack by request index", by_q)

# lanes: sealing turn of request q+2 vs result of request q
print("\n  sealing turn of q vs result of q-2 (lanes = 2, A22 admission):")
for p in P[:2]:
    for q in (2, 3):
        print("   pass", p, "q", q, "sealing turn", r4[(p, q)]["turn"], "result of q-2", r4[(p, q - 2)]["result"])
print("  sealing turn(q) == result(q-2) within 2 ms for all 12 (q=2,3) :",
      all(abs(r4[(p, q)]["turn"] - r4[(p, q - 2)]["result"]) < 0.002 for p in P for q in (2, 3)))
print("  sealing turn(1) == seal_done(0)? :", all(abs(r4[(p, 1)]["turn"] - r4[(p, 0)]["seal_done"]) < 0.002 for p in P))
print("  prover start(q) == prover end(q-1)? :", all(abs(r4[(p, q)]["p0"] - r4[(p, q - 1)]["p1"]) < 0.002 for p in P for q in (1, 2, 3)))

# the contention claim: forks of req 1-2 vs req 3
c12 = [(r4[(p, 1)]["forks"] + r4[(p, 2)]["forks"]) / 2 for p in P]
c3 = [r4[(p, 3)]["forks"] for p in P]
print("\n  forks request 1-2 mean:", mi(c12), " request 3:", mi(c3), " difference median:", mi([a - b for a, b in zip(c12, c3)]))
f0 = [r4[(p, 0)]["forks"] for p in P]
print("  forks request 0 (nothing sealing beside it, but cold-start of a pass):", mi(f0))
print("  forks per request index:", {q: mi([r4[(p, q)]["forks"] for p in P]) for q in range(4)})
print("  forks serve1 (solo, nothing overlapped):", mi(fk1))
print("  -> forks overlapped with the next sealing pass vs solo: +", round(mi([r4[(p, q)]['forks'] for p in P for q in (1, 2)])[0] - mi(fk1)[0], 3), "s (request 1-2);", "request 3 (last, only 1 seal overlap?)", round(mi(c3)[0] - mi(fk1)[0], 3))

# ----------------------------------------------------------------- the 2-lane model
print("\n=== floor logic ===")
W = pct(wr_all, .5)


def sim(P_scale_fn, S_fn, n=200, W=W):
    """Event model of the serve stream with 2 lanes as seen in the log:
    sealing turn(q) = result(q-2) (turn(0)=0, turn(1)=seal_done(0)); seal_done(q)=turn(q)+S(q);
    prover start(q)=max(seal_done(q), prover_end(q-1)); prover_end(q)=start+P(q); result(q)=prover_end+W."""
    res, pe, sd, turn = [], [], [], []
    for q in range(n):
        if q == 0:
            t = 0.0
        elif q == 1:
            t = sd[0]
        else:
            t = res[q - 2]
        s = t + S_fn(q)
        ps = s if q == 0 else max(s, pe[q - 1])
        e = ps + P_scale_fn(q)
        turn.append(t); sd.append(s); pe.append(e); res.append(e + W)
    # steady cadence over the last half
    a, b = n // 2, n - 1
    return (res[b] - res[a]) / (b - a)


S0, P0 = pct(steady_seal, .5), pct(pc_steady, .5)
c0 = sim(lambda q: P0, lambda q: S0)
print(f"model with measured S={S0:.3f}, P={P0:.3f}, W={W:.3f}: steady cadence {c0:.3f} s (measured {mi(cad)[0]})")
print("  (analytic: cadence = max(P, (S+W+P)/2) ->", round(max(P0, (S0 + W + P0) / 2), 3), "; with this S the two branches are", round(P0, 3), "and", round((S0 + W + P0) / 2, 3), ")")

Sauthor = 3.054
print("\nWhat the author's own claim implies. P' = prove call after removing 19.4% of forks (author's arithmetic):")
forks_med = mi([sum(r4[(p, q)]['forks'] for q in range(4)) / 4 for p in P])[0]
pc_author = mi(pc_all)[0]
for frac, label in [(0.1931, "author, 19.31% of forks"), (0.1331, "H GPU-spans share 13.3%"), (0.2189, "H host share of solo host 21.9%"), (0.256, "52 ms + helper share of slots 14-18 (25.6%)"), (0.289, "52 + helper share + TAB (28.9%)")]:
    Pn = pc_author - forks_med * frac
    for S_label, S_fn in [("S stays at its overlapped value", lambda q, S=S0: S),
                          ("S = author's 3.054 mean incl. unoverlapped request 0", lambda q: Sauthor),
                          ("S falls half-way to solo 2.172 as prove shortens", lambda q, S=S0, Pn=Pn: S - 0.5 * (S - pct(seal1, .5)) * (P0 - Pn) / max(P0 - Pn, 1e-9) * min(1.0, (P0 - Pn) / 0.5)),
                          ("S = solo 2.172 (full release, lower bound)", lambda q: pct(seal1, .5))]:
        c = sim(lambda q, Pn=Pn: Pn, S_fn)
        print(f"  {label:48s} P'={Pn:.3f}  [{S_label:55s}] cadence {c:.3f}  ceiling x{mi(cad)[0]/c:.3f}")

print("\nAuthor's ceiling arithmetic: 3.606/3.054 =", round(3.606 / 3.054, 3), " 3.606/(3.606-0.657) =", round(3.606 / (3.606 - 0.657), 3))
print("  the stated floor 3.054 s is the mean of 4 sealing passes incl. unoverlapped request 0 (2.1 s); overlapped passes are", round(S0, 3), "s")

# -------------------------------------------------------------- compare to JSON
d = json.load(open(R + "BATCH6_HEAD_PROFILE_METRICS.json"))
s4j = d["item1_six_fork_stream_serve4_pipelined_6warm"]
print("\nJSON checks (author median vs mine):")
print("  cadence", s4j["steady_state_cadence"]["per_request_cadence_s"]["median"], mi(cad)[0])
print("  sealing pass", s4j["per_request_host_phases_s"]["sealing_pass_witness_chain_s"]["median"])
print("  prove call", s4j["per_request_host_phases_s"]["prove_call_total_s"]["median"], mi(pc_all)[0])
print("  forks", s4j["per_request_host_phases_s"]["forks_32_blocks_6_workers_s"]["median"])
print("  steady window GPU busy per req", s4j["steady_state_cadence"]["steady_window_gpu_busy_union_per_req_s"]["median"], "pct of wall", s4j["steady_state_cadence"]["steady_window_gpu_busy_pct_of_wall"]["median"])
print("  GPU union per req (pass)", s4j["per_request_gpu_from_cb_timestamps_s"]["gpu_busy_union_s"]["median"], "pct of pass wall", s4j["per_request_gpu_from_cb_timestamps_s"]["gpu_busy_pct_of_pass_wall"]["median"])
print("  witness unhidden wait (json)", s4j["steady_state_cadence"]["witness_unhidden_critical_path_wait_s"])
sj = d["item1_candidate_A_stream_expected_gain_ceiling"]
print("  ceiling summary", json.dumps(sj)[:700])
s1j = d["item1_six_fork_stream_serve1_solo_6warm"]
print("  serve1 GPU busy per req", s1j["per_request_gpu_from_cb_timestamps_s"]["gpu_busy_union_s"]["median"], s1j["per_request_gpu_from_cb_timestamps_s"]["gpu_busy_pct_of_pass_wall"]["median"])
print("  serve1 wall", s1j["amortized_per_request_wall_s"]["median"])
bk = s4j["per_request_gpu_from_cb_timestamps_s"]["by_bucket_summed_spans_s"]
print("  serve4 buckets", {k: v["median"] for k, v in bk.items()})
print("  serve4 summed spans", s4j["per_request_gpu_from_cb_timestamps_s"]["gpu_summed_spans_s"]["median"])
bk1 = s1j["per_request_gpu_from_cb_timestamps_s"]["by_bucket_summed_spans_s"]
print("  serve1 buckets", {k: v["median"] for k, v in bk1.items()}, s1j["per_request_gpu_from_cb_timestamps_s"]["gpu_summed_spans_s"]["median"])
tot = sum(v["median"] for v in bk.values())
print("  serve4 bucket sum", round(tot, 3), " H = commit_H+open_H =", round(bk['commit_H_32_cbs_s']['median'] + bk['open_H_32_blocks_s']['median'], 3),
      " share of non-witness spans =", round(100 * (bk['commit_H_32_cbs_s']['median'] + bk['open_H_32_blocks_s']['median']) / (tot - bk['wprod_witness_224_cbs_s']['median']), 2), "%")
tot1 = sum(v["median"] for v in bk1.values())
print("  serve1 H share of non-witness spans", round(100 * (bk1['commit_H_32_cbs_s']['median'] + bk1['open_H_32_blocks_s']['median']) / (tot1 - bk1['wprod_witness_224_cbs_s']['median']), 2), "%")
print("  commit_H span per block under 6 workers:", round(bk['commit_H_32_cbs_s']['median'] / 32 * 1000, 1), "ms vs solo 14.0 ms ; commit_A", round(bk['commit_A_32_cbs_s']['median'] / 32 * 1000, 1), "vs 13.4")
print("  slots span per block", round(bk['slots_sumcheck_s']['median'] / 32 * 1000, 1), "ms vs solo 65.9")


# ------------------------------------------------------------ extra: overlap model and lanes
print("\n=== overlap model: sealing runs at slowdown k while the prover runs, at solo speed after it stops ===")
k = S0 / pct(seal1, .5)  # measured slowdown 1.53
solo = pct(seal1, .5)


def sealing_with_overlap(Pn, W=W, k=k, solo=solo):
    """Sealing of request q+2 starts W after prover(q+1) starts and overlaps it for (Pn - W) seconds at 1/k speed."""
    ov = max(Pn - W, 0.0)
    done_solo_equiv = ov / k
    if done_solo_equiv >= solo:
        return solo * k
    return ov + (solo - done_solo_equiv)


print("slowdown k =", round(k, 3), "; check: with P =", round(P0, 3), "model S =", round(sealing_with_overlap(P0), 3), "(measured overlapped", round(S0, 3), ")")
for frac, label in [(0.1331, "13.3% of forks (H GPU share)"), (0.1931, "19.31% (author)"), (0.2189, "21.9% (H host share)"), (0.256, "25.6% (52 ms + helper share of slots 14-18)"), (0.289, "28.9% (+TAB)")]:
    Pn = pc_author - forks_med * frac
    Sn = sealing_with_overlap(Pn)
    for lanes in (2, 3):
        def simL(Pn=Pn, Sn=Sn, lanes=lanes, n=200):
            res, pe, sd = [], [], []
            for q in range(n):
                t = 0.0 if q == 0 else (sd[0] if q == 1 and lanes == 2 else (res[q - lanes] if q >= lanes else 0.0))
                if lanes == 3 and q in (1, 2):
                    t = sd[q - 1]
                s = t + Sn
                ps = s if q == 0 else max(s, pe[q - 1])
                e = ps + Pn
                sd.append(s); pe.append(e); res.append(e + W)
            a, b = n // 2, n - 1
            return (res[b] - res[a]) / (b - a)
        c = simL()
        print(f"  remove {label:46s} P'={Pn:.3f} S'={Sn:.3f} lanes={lanes}: cadence {c:.3f}  ceiling x{mi(cad)[0]/c:.3f}")
# the same model for lanes=3 at today's numbers (sanity: if sealing is not the floor today, a third lane changes nothing)
print("analytic (lanes=2): cadence = max(P', (S'+W+P')/2); (lanes=3): max(P', (S'+W+P'+...)/3-ish) -> the sealing floor moves down by a third lane (not measured)")
