#!/usr/bin/env python3
"""Item 7 and the thread-time view: where the time with no prover buffer executing sits, and what the six fork threads spend their time on.
python3 -I gaps.py   (stdlib only)

Part A: gaps of the prover busy union inside the prove call [S, E]: total per call, count, and the (previous buffer -> next buffer) classes.
Part B: per fork thread, the time between its buffers (host work of that thread) split into 'hidden' (some prover buffer of any thread
        is executing on the GPU meanwhile) and 'exposed' (no prover buffer executing); and the share of each thread's life spent
        inside its buffers (queue wait + execution) against host.
"""
import sys
import bisect
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from labels import group_of


def coarse(r):
    g = group_of(r)
    if g.startswith("small commits"):
        return "commit-38 (serial start phase)"
    if g.startswith("small gathers"):
        return "gather-38/37 (join phase)"
    if g.startswith("commit A"):
        return "A commit"
    if g.startswith("commit H"):
        return "H commit"
    if g.startswith("gather A"):
        return "A open (gather)"
    if g.startswith("gather H"):
        return "H open (gather)"
    if g.startswith("slot"):
        n = int(g.split()[1])
        if n in (14, 15, 16, 17, 18):
            return "slot %d (domain zero-check)" % n
        if n == 19:
            return "slot 19 (TAB)"
        return "slots 0-4,13,20-22"
    return g


def part_a(A, rq, P):
    S, E = rq["S"], rq["E"]
    segs = [s for s in depth_segments(ivs(P), S, E) if s[2] == 0]
    ends = sorted(P, key=lambda r: r["ge"])
    end_t = [r["ge"] for r in ends]
    starts = sorted(P, key=lambda r: r["gs"])
    st_t = [r["gs"] for r in starts]
    out = []
    for a, b, d in segs:
        i = bisect.bisect_right(end_t, a + 1e-9) - 1
        j = bisect.bisect_left(st_t, b - 1e-9)
        prev = coarse(ends[i]) if i >= 0 else "(call start)"
        nxt = coarse(starts[j]) if j < len(starts) else "(call end)"
        if abs(a - S) < 1e-9:
            prev = "(call start)"
        if abs(b - E) < 1e-9:
            nxt = "(call end)"
        out.append((a, b, prev, nxt))
    return out


def run_arm(arm):
    A = windows(load_arm(arm))
    R = A["R"]
    prov = all_prover(A)
    res = {"beside": [], "last": [], "solo": []}
    for rq in A["reqs"]:
        if rq["key"][0] == "cold":
            continue
        q_ = rq["key"][1]
        rc = "solo" if R == 1 else ("last" if q_ == R - 1 else "beside")
        P = [r for r in prov if rq["S"] <= 0.5 * (r["gs"] + r["ge"]) <= rq["E"]]
        # part A
        gaps = part_a(A, rq, P)
        # part B: fork threads
        byth = {}
        for r in P:
            byth.setdefault(r["th"], []).append(r)
        merged = merge(ivs(P))
        mg_a = [a for a, b in merged]

        def hidden_len(a, b):
            """length of [a, b] covered by the prover busy union"""
            tot = 0.0
            i = max(0, bisect.bisect_right(mg_a, a) - 1)
            while i < len(merged) and merged[i][0] < b:
                lo, hi = max(a, merged[i][0]), min(b, merged[i][1])
                if hi > lo:
                    tot += hi - lo
                i += 1
            return tot
        forks = {t: sorted(L, key=lambda r: r["b"]) for t, L in byth.items() if sum(1 for r in L if group_of(r).startswith("commit A")) >= 3}
        gap_cls = {}
        life = dict(encode=0.0, qwait=0.0, exec=0.0, wake=0.0, gap=0.0, hidden=0.0, exposed=0.0)
        for t, L in forks.items():
            for k, r in enumerate(L):
                life["encode"] += max(0.0, r["c"] - r["b"])
                life["qwait"] += max(0.0, r["gs"] - r["c"])
                life["exec"] += max(0.0, r["ge"] - r["gs"])
                life["wake"] += max(0.0, r["d"] - r["ge"])
                if k + 1 < len(L):
                    g0, g1 = r["d"], L[k + 1]["b"]
                    if g1 > g0:
                        h = hidden_len(g0, g1)
                        life["gap"] += g1 - g0
                        life["hidden"] += h
                        life["exposed"] += (g1 - g0) - h
                        key = (coarse(r), coarse(L[k + 1]))
                        v = gap_cls.setdefault(key, [0.0, 0.0, 0])
                        v[0] += g1 - g0
                        v[1] += (g1 - g0) - h
                        v[2] += 1
        res[rc].append(dict(win=rq["E"] - rq["S"], gaps=gaps, life=life, gap_cls=gap_cls, nforks=len(forks),
                            fork_span=sum(L[-1]["d"] - L[0]["b"] for L in forks.values())))
    return A, res


if __name__ == "__main__":
    for arm in ARMS:
        A, res = run_arm(arm)
        for rc, L in res.items():
            if not L:
                continue
            print("\n" + "=" * 100)
            print("%s / %s: n = %d prove calls" % (arm, rc, len(L)))
            print("=" * 100)
            tot = [sum(b - a for a, b, _, _ in x["gaps"]) for x in L]
            cnt = [len(x["gaps"]) for x in L]
            big = [sum(1 for a, b, _, _ in x["gaps"] if b - a >= 0.005) for x in L]
            print("PART A  no prover buffer executing: total %.3f s per call (median; %.1f %% of the call), %d gaps per call (median), of which %d are >= 5 ms; call %.3f s" % (
                med(tot), 100 * med([t / x["win"] for t, x in zip(tot, L)]), med(cnt), med(big), med([x["win"] for x in L])))
            cls = {}
            for i, x in enumerate(L):
                for a, b, pv, nx in x["gaps"]:
                    v = cls.setdefault((pv, nx), [[0.0] * len(L), [0] * len(L), []])
                    v[0][i] += b - a
                    v[1][i] += 1
                    v[2].append(b - a)
            rows = sorted(cls.items(), key=lambda kv: -med(kv[1][0]))
            print("   %-34s -> %-34s %9s %7s %9s %9s" % ("previous buffer", "next buffer", "ms/call", "n/call", "median ms", "max ms"))
            shown = 0.0
            for (pv, nx), (tt, nn, lens) in rows[:14]:
                shown += med(tt)
                print("   %-34s -> %-34s %9.1f %7.1f %9.2f %9.1f" % (pv, nx, 1000 * med(tt), med(nn), 1000 * med(lens), 1000 * max(lens)))
            print("   (classes shown sum of medians %.0f ms of %.0f ms)" % (1000 * shown, 1000 * med(tot)))
            # size distribution
            allg = [b - a for x in L for a, b, _, _ in x["gaps"]]
            for lo, hi in ((0, 0.001), (0.001, 0.005), (0.005, 0.02), (0.02, 0.05), (0.05, 1)):
                sel = [g for g in allg if lo <= g < hi]
                print("   gap size %5.0f-%-5.0f ms: %6.1f gaps/call, %7.1f ms/call" % (1000 * lo, 1000 * hi, len(sel) / len(L), 1000 * sum(sel) / len(L)))
            # part B
            life = {k: med([x["life"][k] for x in L]) for k in L[0]["life"]}
            tot_th = sum(life[k] for k in ("encode", "qwait", "exec", "wake", "gap"))
            print("PART B  six fork threads (n threads per call %.0f, summed thread time %.2f s = %.2f x the call):" % (med([x["nforks"] for x in L]), tot_th, tot_th / med([x["win"] for x in L])))
            for k, nm in (("encode", "encode (begin->commit)"), ("qwait", "queue wait (commit->GPU start)"), ("exec", "execution (GPU start->end)"), ("wake", "wake (GPU end->host sees done)"),
                          ("gap", "between buffers (host work, lock waits)")):
                print("     %-42s %7.3f s  %5.1f %% of thread time" % (nm, life[k], 100 * life[k] / tot_th))
            print("     of the 'between buffers' time: hidden behind some prover buffer executing %.3f s (%.0f %%), exposed (no prover buffer executing) %.3f s" % (
                life["hidden"], 100 * life["hidden"] / life["gap"], life["exposed"]))
            gcl = {}
            for i, x in enumerate(L):
                for key, (g, e, n) in x["gap_cls"].items():
                    v = gcl.setdefault(key, [[0.0] * len(L), [0.0] * len(L), [0] * len(L)])
                    v[0][i] += g
                    v[1][i] += e
                    v[2][i] += n
            print("   per-thread host gaps by class (summed over the fork threads, per call; median):")
            print("   %-34s -> %-34s %9s %9s %7s %7s" % ("previous buffer", "next buffer", "ms/call", "exposed", "n", "mean ms"))
            for (pv, nx), (g, e, n) in sorted(gcl.items(), key=lambda kv: -med(kv[1][0]))[:10]:
                print("   %-34s -> %-34s %9.1f %9.1f %7.1f %7.2f" % (pv, nx, 1000 * med(g), 1000 * med(e), med(n), 1000 * med(g) / max(1e-9, med(n))))
