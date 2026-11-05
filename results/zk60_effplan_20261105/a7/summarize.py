#!/usr/bin/env python3
"""A7: summarise the GPU timeline reports of a D55 harness log (HL_D55_TIMELINE=1).

usage: summarize.py <s?_d55.log> [...]

For every fork call it pairs the forks-phase report with the call's result line (the
standard passes' `forks N.. pass ..` lines and the A/B's `GPU-AB` lines) and prints one
row: the arm, the call's wall, the forks phase, GPU busy and idle, the most command
buffers executing at once, the summed commit -> GPU start and GPU end -> seen waits,
and the fork threads' mean host time between command buffers. Then the mean per arm.
"""
import re
import sys
from collections import defaultdict

WIN = re.compile(r"^D55-AB A7 TIMELINE \S+ L\d+ forks N(\d+) \(queues (\w+)\): the forks phase")
BUSY = re.compile(r"window ([\d.]+) s: (\d+) command buffers; GPU busy \(>= 1 executing\) ([\d.]+) s = ([\d.]+)%, idle ([\d.]+) s")
DEPTH = re.compile(r"time at k executing: (.*)$")
TAG = re.compile(r"^  tag (\w+)\s+(\d+) cbs: GPU ([\d.]+) s .*commit -> GPU start ([\d.]+) s .*GPU end -> seen ([\d.]+) s")
THREAD = re.compile(r"host between ([\d.]+) s")
STD = re.compile(r"^D55-AB \S+ L\d+ T\d+ forks N(\d+) pass (\d+) .*wall ([\d.]+) s = ([\d.]+) proved tok/s")
AB = re.compile(r"^D55-AB GPU-AB \S+ L\d+ T\d+ forks N(\d+) \[([^\]]+)\] pass (\d+): wall ([\d.]+) s = ([\d.]+) proved tok/s")
# stage 1's first form of the A/B line (queues only)
QAB = re.compile(r"^D55-AB QUEUES \S+ L\d+ T\d+ forks N(\d+) queues (\w+) pass (\d+): wall ([\d.]+) s = ([\d.]+) proved tok/s")
CPU = re.compile(r"^D55-AB A7 CPU \S+ L\d+ forks N(\d+): ([\d.]+) CPU-seconds .* = ([\d.]+) cores busy")


def rows(path):
    out, cur, cpu = [], None, None
    with open(path) as f:
        lines = f.read().splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        m = CPU.match(ln)
        if m:
            cpu = float(m.group(3))
        m = WIN.match(ln)
        if m:
            cur = {"n": int(m.group(1)), "queues": m.group(2), "tags": {}, "host": [], "cores": cpu}
            j = i + 1
            while j < len(lines) and lines[j].startswith("  "):
                s = lines[j]
                b = BUSY.search(s)
                if b:
                    cur.update(window=float(b.group(1)), cbs=int(b.group(2)), busy=float(b.group(3)), busy_pct=float(b.group(4)), idle=float(b.group(5)))
                d = DEPTH.search(s)
                if d:
                    parts = [p.split(": ") for p in d.group(1).split(", ")]
                    cur["max_at_once"] = max([int(k.rstrip("+")) for k, v in parts if float(v.split()[0]) > 0.0005] or [0])
                t = TAG.match(s)
                if t:
                    cur["tags"][t.group(1)] = (int(t.group(2)), float(t.group(3)), float(t.group(4)), float(t.group(5)))
                if s.startswith("  per thread:"):
                    cur["host"] = [float(x) for x in THREAD.findall(s)]
                j += 1
            i = j
            continue
        m = STD.match(ln) or AB.match(ln) or QAB.match(ln)
        if m and cur is not None:
            if m.re is AB:
                arm, wall, tok = m.group(2), float(m.group(4)), float(m.group(5))
            elif m.re is QAB:
                arm, wall, tok = f"{m.group(2)}+spin", float(m.group(4)), float(m.group(5))
            else:
                arm, wall, tok = f"default ({cur['queues']})", float(m.group(3)), float(m.group(4))
            cur.update(arm=arm, wall=wall, tok=tok)
            out.append(cur)
            cur = None
        i += 1
    return out


def main():
    allr = []
    for p in sys.argv[1:]:
        allr += [dict(r, log=p.rsplit("/", 1)[-1]) for r in rows(p)]
    print("| log | N | arm | wall s | tok/s | forks phase s | GPU busy | idle s | max at once | commit->start s | end->seen s | host between, mean per thread s | cores busy |")
    print("|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    by = defaultdict(list)
    for r in allr:
        qd = sum(v[2] for v in r["tags"].values())
        es = sum(v[3] for v in r["tags"].values())
        hb = sum(r["host"]) / len(r["host"]) if r["host"] else float("nan")
        print(f"| {r['log']} | {r['n']} | {r['arm']} | {r['wall']:.3f} | {r['tok']:.2f} | {r['window']:.3f} | {r['busy_pct']:.1f}% | {r['idle']:.3f} | {r.get('max_at_once', 0)} | {qd:.3f} | {es:.3f} | {hb:.3f} | {r['cores'] if r['cores'] is not None else float('nan'):.1f} |")
        by[(r["n"], r["arm"])].append((r, qd, es, hb))
    print()
    print("| N | arm | calls | mean wall s | mean tok/s | mean GPU busy | mean idle s | mean end->seen s | mean host between s |")
    print("|---:|---|---:|---:|---:|---:|---:|---:|---:|")
    for (n, arm), v in sorted(by.items()):
        k = len(v)
        mw = sum(x[0]["wall"] for x in v) / k
        print(f"| {n} | {arm} | {k} | {mw:.3f} | {128 / mw:.2f} | {sum(x[0]['busy_pct'] for x in v) / k:.1f}% | {sum(x[0]['idle'] for x in v) / k:.3f} | {sum(x[2] for x in v) / k:.3f} | {sum(x[3] for x in v) / k:.3f} |")


if __name__ == "__main__":
    main()
