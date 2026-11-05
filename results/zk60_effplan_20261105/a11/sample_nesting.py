#!/usr/bin/env python3
"""A11: how deep rayon workers' stacks nest jobs inside join waits.

usage: sample_nesting.py <sample.txt>

For every rayon-worker self sample, count the `wait_until_cold` frames on its stack. The
worker's own idle loop is one; each further one is a join (or scope) the worker is waiting
on INSIDE a job, while it runs whatever it stole (possibly another fork's task). A sample
at nesting >= 2 that is executing a job means the worker is busy with stolen work while an
enclosing job of its own waits for it.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sample_summary as ss  # noqa: E402

WAITS = ("__psynch_cvwait", "__psynch_mutexwait", "swtch_pri", "__ulock_wait", "semaphore_wait", "__semwait")


def main():
    path = sys.argv[1]
    hist = collections.Counter()
    for header, nodes in ss.parse(path):
        samples = ss.self_samples(nodes)
        # a rayon worker (of the global pool or of a fork's own pool), outside any
        # fork's main line (`prove_core`, which A11's pools run on a pool thread)
        rayonish = any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for st, _ in samples for n in st)
        if not rayonish:
            continue
        for st, c in samples:
            if ss.is_main(st):
                continue
            depth = sum(1 for n in st if "wait_until_cold" in n)
            waiting = any(w in st[-1] for w in WAITS) or "wait_until_cold" in st[-1] or "Sleep::" in " ".join(st[-3:])
            # a job is running below the deepest wait_until_cold
            last = max((i for i, n in enumerate(st) if "wait_until_cold" in n), default=-1)
            running = any("execute" in n and "Job" in n for n in st[last + 1:]) if last >= 0 else False
            kind = "waiting/idle" if waiting else ("running a job" if running else "other")
            hist[(depth, kind)] += c
    tot = sum(hist.values())
    print(f"# rayon worker self samples by wait_until_cold nesting ({path}); total {tot}")
    for (d, k), c in sorted(hist.items()):
        print(f"  nesting {d}  {k:<14} {c:>8}  {100 * c / tot:5.1f}%")


if __name__ == "__main__":
    main()
