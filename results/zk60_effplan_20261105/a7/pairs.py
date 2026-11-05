#!/usr/bin/env python3
"""A7: the shared queue against per-thread queues, paired by pass, over every interleaved A/B log.

usage: pairs.py <log> [<log> ...]

Reads the in-process A/B lines (stage 1's `D55-AB QUEUES ... queues shared|thread`, later `D55-AB GPU-AB ...
[shared+spin|thread+spin]`) at N = 6: the proof-only fork wall, the sealed wall and the stream's steady and amortized
tok/s. Pairs the two arms within each (log, pass), and prints per log and pooled: the means, the mean paired change
and how many pairs favour per-thread queues.
"""
import re
import sys
from collections import defaultdict

Q1 = re.compile(r"^D55-AB QUEUES \S+ L\d+ T\d+ forks N6 queues (shared|thread) pass (\d+): wall ([\d.]+) s")
PO = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N6 \[(shared|thread)\+spin\] pass (\d+): wall ([\d.]+) s")
SE = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N6 \[(shared|thread)\+spin\] SEALED pass (\d+): wall ([\d.]+) s")
PI = re.compile(r"^D55-AB GPU-AB PIPE \S+ L\d+ T\d+ forks N6 \[(shared|thread)\+spin\] pass (\d+): .*amortized ([\d.]+) proved tok/s; steady state ([\d.]+) tok/s")


def collect(paths):
    d = defaultdict(dict)  # (metric, log, pass) -> {arm: value}
    for p in paths:
        name = p.rsplit("/", 1)[-1]
        for ln in open(p):
            for rx, metric in ((Q1, "proof-only wall s"), (PO, "proof-only wall s"), (SE, "sealed wall s")):
                m = rx.match(ln)
                if m:
                    d[(metric, name, int(m.group(2)))][m.group(1)] = float(m.group(3))
            m = PI.match(ln)
            if m:
                d[("stream steady tok/s", name, int(m.group(2)))][m.group(1)] = float(m.group(4))
                d[("stream amortized tok/s", name, int(m.group(2)))][m.group(1)] = float(m.group(3))
    return d


def main():
    d = collect(sys.argv[1:])
    metrics = ["proof-only wall s", "sealed wall s", "stream steady tok/s", "stream amortized tok/s"]
    print("| metric | logs | pairs | shared mean | per-thread mean | change | pairs favouring per-thread |")
    print("|---|---|---:|---:|---:|---:|---:|")
    for metric in metrics:
        logs = sorted({k[1] for k in d if k[0] == metric})
        for scope in logs + ["pooled"]:
            prs = [(v["shared"], v["thread"]) for k, v in d.items() if k[0] == metric and (scope == "pooled" or k[1] == scope) and "shared" in v and "thread" in v]
            if not prs:
                continue
            s = sum(a for a, _ in prs) / len(prs)
            t = sum(b for _, b in prs) / len(prs)
            lower_better = metric.endswith(" s")
            fav = sum(1 for a, b in prs if (b < a if lower_better else b > a))
            print(f"| {metric} | {scope} | {len(prs)} | {s:.3f} | {t:.3f} | {100 * (t - s) / s:+.1f}% | {fav} of {len(prs)} |")


if __name__ == "__main__":
    main()
