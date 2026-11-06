#!/usr/bin/env python3
"""A22: tables from `a22_stream_ab`'s lines.

usage: stream_table.py LOG [BASE TEST ...]

Reads the `A22-AB STREAM` lines (one stream each: its arm, pass, steady and amortized
proved tok/s, completions, latencies, footprint) and the `A22-AB REQ` lines (one served
request's parts). Prints, in markdown:
  * per arm: passes, steady tok/s mean (min, max), amortized tok/s mean (min, max), the
    first request's latency mean, the mean latency, the peak footprint;
  * for each BASE TEST pair given: per pass the change of the test arm's steady and
    amortized tok/s against the base's (the passes alternate the arm order when the run
    set HL_D55_AB_ALTERNATE=1), the mean change, the passes where the test arm was faster,
    and the means split by the pass's parity (the order bias);
  * per served arm: the means of each request's parts after the first (sealing pass,
    waited for the prover, prove call and its phases, receipt write).
"""
import re
import sys
from collections import defaultdict

STREAM = re.compile(r"A22-AB STREAM \S+ L\d+ N\d+ \[(?P<arm>[^\]]+)\] pass (?P<p>\d+): (?P<r>\d+) requests in (?P<wall>[\d.]+) s .*?steady (?P<steady>[\d.]+|NaN) tok/s; amortized (?P<amort>[\d.]+) tok/s; completions (?P<done>[^;]+); latency from arrival (?P<lat>[^;]+); from the sealing turn (?P<lats>[^;]+); footprint start (?P<f0>[\d.]+) GiB, peak (?P<peak>[\d.]+) GiB, end (?P<f1>[\d.]+) GiB")
REQ = re.compile(r"A22-AB REQ \S+ L\d+ N\d+ \[(?P<arm>[^\]]+)\] pass (?P<p>\d+) request (?P<q>\d+): .*?\(sealing pass (?P<seal>[\d.]+) s\), prover [\d.]+-[\d.]+ \(waited (?P<wait>[\d.]+) s; prove call (?P<call>[\d.]+) s: preflight (?P<pre>[\d.]+), commit (?P<com>[\d.]+), forks (?P<forks>[\d.]+), join (?P<join>[\d.]+)\), receipt write (?P<write>[\d.]+) s")


def mean(v):
    return sum(v) / len(v) if v else float("nan")


def main():
    log = sys.argv[1]
    pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))
    streams = defaultdict(dict)
    reqs = defaultdict(lambda: defaultdict(list))
    order = []
    for line in open(log, errors="replace"):
        m = STREAM.search(line)
        if m:
            arm, p = m["arm"], int(m["p"])
            if arm not in order:
                order.append(arm)
            nums = lambda s: [float(x) for x in s.split(",")]
            streams[arm][p] = {"steady": float(m["steady"]) if m["steady"] != "NaN" else float("nan"), "amort": float(m["amort"]), "lat": nums(m["lat"]), "peak": float(m["peak"]), "r": int(m["r"])}
            continue
        m = REQ.search(line)
        if m and int(m["q"]) > 0:
            for k in ("seal", "wait", "call", "pre", "com", "forks", "join", "write"):
                reqs[m["arm"]][k].append(float(m[k]))
    print("| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    for arm in order:
        v = list(streams[arm].values())
        st = [x["steady"] for x in v if x["steady"] == x["steady"]]
        am = [x["amort"] for x in v]
        stc = f"{mean(st):.2f} ({min(st):.2f}, {max(st):.2f})" if st else "n/a (one request)"
        print(f"| {arm} | {len(v)} | {stc} | {mean(am):.2f} ({min(am):.2f}, {max(am):.2f}) | {mean([x['lat'][0] for x in v]):.3f} s | {mean([mean(x['lat']) for x in v]):.3f} s | {max(x['peak'] for x in v):.1f} GiB |")
    for base, test in pairs:
        if base not in streams or test not in streams:
            print(f"\n(no pair {base} / {test} in the log)")
            continue
        ps = sorted(set(streams[base]) & set(streams[test]))
        print(f"\n**{base} -> {test}** ({len(ps)} passes)\n")
        print("| pass | steady, base / test | change | amortized, base / test | change |")
        print("|---:|---:|---:|---:|---:|")
        ds, da = [], []
        for p in ps:
            b, t = streams[base][p], streams[test][p]
            d1 = (t["steady"] / b["steady"] - 1) * 100 if b["steady"] == b["steady"] and t["steady"] == t["steady"] else float("nan")
            d2 = (t["amort"] / b["amort"] - 1) * 100
            ds.append(d1)
            da.append(d2)
            print(f"| {p} | {b['steady']:.2f} / {t['steady']:.2f} | {d1:+.1f}% | {b['amort']:.2f} / {t['amort']:.2f} | {d2:+.1f}% |")
        even = [i for i, p in enumerate(ps) if p % 2 == 0]
        odd = [i for i, p in enumerate(ps) if p % 2 == 1]
        f = lambda v, ix: mean([v[i] for i in ix if v[i] == v[i]])
        print(f"\nsteady: mean {mean([x for x in ds if x == x]):+.1f}% ({sum(1 for x in ds if x > 0)} of {len(ps)} faster; even passes {f(ds, even):+.1f}%, odd {f(ds, odd):+.1f}%); amortized: mean {mean(da):+.1f}% ({sum(1 for x in da if x > 0)} of {len(ps)} faster; even {f(da, even):+.1f}%, odd {f(da, odd):+.1f}%)")
    if reqs:
        print("\n| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |")
        print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for arm in order:
            r = reqs.get(arm)
            if not r:
                continue
            print(f"| {arm} | {len(r['seal'])} | " + " | ".join(f"{mean(r[k]):.3f} s" for k in ("seal", "wait", "call", "pre", "com", "forks", "join", "write")) + " |")


if __name__ == "__main__":
    main()
