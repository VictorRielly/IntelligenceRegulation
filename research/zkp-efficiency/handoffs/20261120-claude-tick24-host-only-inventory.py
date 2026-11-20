#!/usr/bin/env python3
"""Tick 24 (queue item 42): union wall time of each host-gap class of a prove call, per arm, read from the saved
output of the stream-phase analysis (PART A of gaps.out.txt: no prover buffer executing, ms per call, medians),
plus the share of the call and a stated upper bound on what removing a class could give.
Reads one file, writes nothing. Standard library only. Run: python3 <this file>."""
import re
from pathlib import Path

SRC = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/"
           "stream_gpu_phases/gaps.out.txt")

# class name -> list of (previous label, next label) as printed in the table (whitespace-normalised)
CLASSES = {
    "C1 serial small-commit loop": [("commit-38 (serial start phase)", "commit-38 (serial start phase)")],
    "C2a last small slot -> A open (opening host work)": [("slots 0-4,13,20-22", "A open (gather)")],
    "C2b A open -> H open (host fold, audit, path)": [("A open (gather)", "H open (gather)")],
    "C2c gather to gather (H-H, A-A, H-A): opening host work": [("H open (gather)", "H open (gather)"), ("A open (gather)", "A open (gather)"), ("H open (gather)", "A open (gather)")],
    "C3 H open -> A commit (next block's A build)": [("H open (gather)", "A commit")],
    "C4 join gathers": [("gather-38/37 (join phase)", "gather-38/37 (join phase)")],
    "C5 between small slots": [("slots 0-4,13,20-22", "slots 0-4,13,20-22")],
    "C6 small slots -> slot 14": [("slots 0-4,13,20-22", "slot 14 (domain zero-check)")],
    "C7 hand-over: last small commit -> first A commit": [("commit-38 (serial start phase)", "A commit")],
    "C8 A commit -> H commit (helper inverses, masks)": [("A commit", "H commit")],
}
ARMS = ["serve1 / solo", "serve4 / beside", "serve4 / last", "serve6 / beside", "serve6 / last"]


def parse():
    arms, cur = {}, None
    for line in SRC.read_text().splitlines():
        m = re.match(r"^(serve\d / \w+): n = (\d+) prove calls", line)
        if m:
            cur = m.group(1)
            arms[cur] = {"n": int(m.group(2)), "rows": {}}
            continue
        if cur is None:
            continue
        m = re.match(r"^PART A .*total ([0-9.]+) s per call.*call ([0-9.]+) s", line)
        if m:
            arms[cur]["idle"] = float(m.group(1)) * 1000
            arms[cur]["P"] = float(m.group(2)) * 1000
            continue
        m = re.match(r"^\s+(.+?)\s+->\s+(.+?)\s{2,}([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*$", line)
        if m and "PART B" not in line and cur in arms and "idle" in arms[cur]:
            key = (m.group(1).strip(), m.group(2).strip())
            if key not in arms[cur]["rows"]:      # first table (PART A) only
                arms[cur]["rows"][key] = (float(m.group(3)), float(m.group(4)))
        if line.startswith("PART B"):
            arms[cur]["partB"] = True
    return arms


arms = parse()
for a in ARMS:
    d = arms[a]
    print("%-16s n=%2d  P %.0f ms  host-only (no prover buffer) %.0f ms (%.1f%%)"
          % (a, d["n"], d["P"], d["idle"], 100 * d["idle"] / d["P"]))

print("\nUnion wall time per call (ms), median over calls; share of the call in brackets; gaps per call (n) for serve4 beside")
hdr = "%-52s" % "class" + "".join("%18s" % a for a in ARMS)
print(hdr)
tot = {a: 0.0 for a in ARMS}
for cname, pairs in CLASSES.items():
    cells = []
    for a in ARMS:
        ms = sum(arms[a]["rows"].get(p, (0.0, 0.0))[0] for p in pairs)
        n = sum(arms[a]["rows"].get(p, (0.0, 0.0))[1] for p in pairs)
        tot[a] += ms
        cells.append("%7.1f (%4.1f%%)%s" % (ms, 100 * ms / arms[a]["P"], " " * 0))
    print("%-52s" % cname + "".join("%18s" % c for c in cells))
print("%-52s" % "sum of the ten rows" + "".join("%18s" % ("%7.1f (%4.1f%%)" % (tot[a], 100 * tot[a] / arms[a]["P"])) for a in ARMS))
print("%-52s" % "host-only total (all gaps)" + "".join("%18s" % ("%7.1f (%4.1f%%)" % (arms[a]["idle"], 100 * arms[a]["idle"] / arms[a]["P"])) for a in ARMS))
print("%-52s" % "left in classes not listed" + "".join("%18s" % ("%7.1f" % (arms[a]["idle"] - tot[a])) for a in ARMS))

print("\nGaps per call and typical gap (serve4 beside):")
for cname, pairs in CLASSES.items():
    for p in pairs:
        ms, n = arms["serve4 / beside"]["rows"].get(p, (0, 0))
        print("  %-52s %6.1f ms in %5.1f gaps -> %.1f ms each" % (cname, ms, n, ms / n if n else 0))

# Upper bounds. P = serve4 beside call; the two-lane stream follows P (A33 follow-up, measured), so a saving of x ms
# per call is at most x ms of cadence while P exceeds the sealing side, and about x/2 below that (stream document
# section 7). Cadence reference 3.7455 s (serve4 Arm A, 12-pass median) as in tick 22.
P = arms["serve4 / beside"]["P"]
CAD = 3745.5
print("\nIf a whole class vanished (upper bound, serve4 beside; P %.0f ms; cadence %.1f ms; target P 2560 ms):" % (P, CAD))
for cname, pairs in CLASSES.items():
    ms = sum(arms["serve4 / beside"]["rows"].get(p, (0.0, 0.0))[0] for p in pairs)
    print("  %-52s %6.1f ms = %.1f%% of P, at most %.1f%% of cadence" % (cname, ms, 100 * ms / P, 100 * ms / CAD))
a_ms = sum(arms["serve4 / beside"]["rows"].get(p, (0.0, 0.0))[0] for p in CLASSES["C1 serial small-commit loop"])
print("\nA34 numbers (record): serial loop 202 ms; pcs.rs split models -0.10 s; A34b alone 33 to 39 ms (hashline only)")
print("  A34b as share of P: %.1f%%; pcs.rs split: %.1f%% of P; loop remaining after the split ~%.0f ms"
      % (100 * 36 / P, 100 * 100 / P, a_ms - 100))
print("\nFloor check (STREAM_GPU_PHASES section 7): P floor with host-only gone: 2.50 s (nothing beside), 2.69 s (beside).")
print("  Target 2560 ms is %.0f ms under today's serve4-beside P and %.0f ms under serve4-last P (%.0f ms)."
      % (P - 2560, arms["serve4 / last"]["P"] - 2560, arms["serve4 / last"]["P"]))
print("  Sum of the ten rows in serve4 beside is %.0f ms; removing ALL of them leaves P about %.0f ms"
      " (upper bound: removed gaps change overlap, so not additive)." % (tot["serve4 / beside"], P - tot["serve4 / beside"]))
print("  Beside-minus-last cost of the sealing pass on P: %.0f ms (serve4), %.0f ms (serve6)"
      % (arms["serve4 / beside"]["P"] - arms["serve4 / last"]["P"], arms["serve6 / beside"]["P"] - arms["serve6 / last"]["P"]))

# item 40: class C6 as union wall time
print("\nItem 40 (slots -> slot 14): union wall per call: " + ", ".join(
    "%s %.1f ms (%.1f%% of call)" % (a, sum(arms[a]["rows"].get(p, (0, 0))[0] for p in CLASSES["C6 small slots -> slot 14"]),
                                     100 * sum(arms[a]["rows"].get(p, (0, 0))[0] for p in CLASSES["C6 small slots -> slot 14"]) / arms[a]["P"])
    for a in ARMS))
# one block alone (Batch 6 log, 1 ms resolution): table builds of slots 5 to 13 and PB-TIMING slot rows
tb = [1, 1, 1, 2, 3, 1, 0, 1, 1]            # PB-SLOTSTEP 'tables: build' ms, slots 5..13, last block of the 7-warm log
tm = [2, 2, 2, 3, 4, 2, 4, 3, 4]            # PB-TIMING slot rows, ms, slots 5..13
print("  Batch 6 one block alone, slots 5 to 13: PB-SLOTSTEP table builds sum %d ms; PB-TIMING slot rows sum %d ms"
      " (1 ms resolution); x32 blocks = %d and %d thread-ms per request" % (sum(tb), sum(tm), 32 * sum(tb), 32 * sum(tm)))
