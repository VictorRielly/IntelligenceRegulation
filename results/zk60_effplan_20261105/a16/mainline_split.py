#!/usr/bin/env python3
"""A16 measure-first: split the sealing pass's main line (stacks holding build_accuracy) by
phase (the first project frames below build_accuracy) and by serial / inside a parallel region
(a rayon bridge / join frame between the phase frame and the leaf), plus the rayon workers'
busy samples by the phase they serve (the outermost project frame of the job)."""
import collections
import os
import sys

sys.path.insert(0, sys.argv[2])
import sample_summary as ss  # noqa: E402

path = sys.argv[1]
sec = 0.002
threads = ss.parse(path)
RAYON = ("rayon::iter::plumbing", "rayon_core::join", "rayon_core::registry::in_worker", "rayon::slice", "rayon::iter")
GPU = ("wait_done", "waitUntilCompleted", "wait_until_completed")


def short(n):
    for p in ("hashline::private_block::witness::accuracy::", "hashline::private_block::witness::", "hashline::private_block::", "hashline::"):
        if n.startswith(p):
            return n[len(p):]
    return n


def phase(st):
    """the project frames below build_accuracy, two levels"""
    i = max(i for i, n in enumerate(st) if "witness::build_accuracy" in n)
    proj = [short(n) for n in st[i + 1:] if n.startswith(ss.PROJECT)]
    a = proj[0] if proj else "(build_accuracy itself)"
    b = proj[1] if len(proj) > 1 else "-"
    return a, b, i


main = collections.Counter()
mainpar = collections.Counter()
worker = collections.Counter()
tot_main = 0
for header, nodes in threads:
    for st, c in ss.self_samples(nodes):
        has_main = any("witness::build_accuracy" in n for n in st)
        leaf = st[-1]
        if has_main:
            a, b, i = phase(st)
            below = st[i + 1:]
            par = any(n.startswith(RAYON) for n in below)
            gpu = any(g in n for n in below for g in GPU)
            sleepish = any(leaf.startswith(k) for k in ("__psynch_cvwait", "__ulock_wait", "swtch_pri", "semaphore_wait", "__psynch_mutexwait"))
            kind = "gpu" if gpu else ("wait" if sleepish else ("par" if par else "serial"))
            main[(a, b, kind)] += c
            tot_main += c
        else:
            # a worker's job: the outermost project frame
            proj = [short(n) for n in st if n.startswith(ss.PROJECT)]
            if proj and not any(leaf.startswith(k) for k in ("__psynch_cvwait", "swtch_pri", "__ulock_wait", "__psynch_mutexwait")):
                worker[(proj[0], proj[1] if len(proj) > 1 else "-")] += c

print(f"main line total {tot_main * sec:.2f} s (2 passes)")
by_a = collections.Counter()
for (a, b, k), c in main.items():
    by_a[(a, k)] += c
print("\n## main line by first phase frame and kind (s, 2 passes)")
for (a, k), c in sorted(by_a.items(), key=lambda x: -x[1])[:40]:
    print(f"  {c * sec:6.2f}  {k:6}  {a}")
print("\n## main line by two frames and kind (top 60)")
for (a, b, k), c in main.most_common(60):
    print(f"  {c * sec:6.2f}  {k:6}  {a} > {b}")
print("\n## workers busy by job frames (top 40)")
for (a, b), c in worker.most_common(40):
    print(f"  {c * sec:6.2f}  {a} > {b}")
