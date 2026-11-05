#!/usr/bin/env python3
"""A15: summarize a macOS `/usr/bin/sample` call graph of the D55 harness's sealing-pass window.

usage: sample_seal.py <sample.txt> [--interval-ms 2] [--top 20] [--label NAME]

Reuses A11's parser (`../a11/sample_summary.py`). Every self sample (a node's count minus its children's,
so its full stack is known) is given
- a ROLE: `main` (the witness build's own line: any stack holding the builder, `witness::build_accuracy`,
  on whatever thread runs it: the harness thread, a global worker or a sealing-pool thread), `rayon`
  (a rayon worker's other samples: the global pool's or the sealing pool's), `other`;
- a STATE by its leaf: `yield` (`swtch_pri`, rayon's idle spin: `thread::yield_now`), `sleep` (blocked:
  condition variables, ulocks, semaphores, Mach messages), `wake` (signalling a condition variable or ulock),
  `mutex` (blocked on a pthread mutex), `vm` (VM calls: deallocate, madvise, munmap), `run` (anything else:
  user code, or a page fault taken in it).
A sampled thread is counted at every tick whatever its state, so `sleep` costs no CPU; `yield`, `wake`,
`mutex` and `vm` are system calls (system CPU); `run` is mostly user CPU.
The main line is also split by what it waits on: `gpu-wait` (a command buffer), `region-wait` (a parallel
region it handed to the pool: `in_worker_cold` / a latch), or its own work by the deepest project frame.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "a11"))
import sample_summary as ss  # noqa: E402

MAIN = ("witness::build_accuracy", "witness::build_for_block", "witness_accuracy::build", "witness_accuracy::assign")
YIELD = ("swtch_pri", "thread_switch", "sched_yield")
SLEEP = ("__psynch_cvwait", "__ulock_wait", "__ulock_wait2", "semaphore_wait_trap", "semaphore_timedwait_trap", "__semwait_signal", "mach_msg2_trap", "mach_msg_trap", "__workq_kernreturn", "kevent", "kevent64", "kevent_id", "__select", "__sigsuspend", "read", "__read_nocancel", "poll")
WAKE = ("__psynch_cvsignal", "__psynch_cvbroad", "__ulock_wake")
MUTEX = ("__psynch_mutexwait", "__psynch_mutexdrop", "_os_unfair_lock_lock_slow")
VM = ("_kernelrpc_mach_vm_deallocate_trap", "mach_vm_deallocate", "madvise", "__munmap", "munmap", "_kernelrpc_mach_vm_allocate_trap", "_kernelrpc_mach_vm_map_trap", "__mmap", "vm_deallocate")


def state(leaf):
    for name, keys in (("yield", YIELD), ("sleep", SLEEP), ("wake", WAKE), ("mutex", MUTEX), ("vm", VM)):
        if any(leaf == k or leaf.startswith(k) for k in keys):
            return name
    return "run"


def is_main(st):
    return any(m in n for n in st for m in MAIN)


def main_kind(st):
    if any("wait_done" in n or "waitUntilCompleted" in n or "wait_until_completed" in n for n in st):
        return "gpu-wait"
    if any("in_worker_cold" in n or "LockLatch" in n or "in_worker_cross" in n for n in st):
        return "region-wait"
    i = max((i for i, n in enumerate(st) if any(m in n for m in MAIN)), default=None)
    if i is not None and any("wait_until_cold" in n for n in st[i:]):
        below = st[[j for j, n in enumerate(st) if j > i and "wait_until_cold" in n][-1] + 1:]
        if any("execute" in n and "Job" in n for n in below):
            return "region-work (its own region's stolen task)"
        return "region-wait"
    return "own work"


def main():
    a = sys.argv[1:]
    path = a[0]
    opt = lambda k, d: a[a.index(k) + 1] if k in a else d
    sec = float(opt("--interval-ms", "2")) / 1000.0
    top = int(opt("--top", "20"))
    label = opt("--label", path)
    threads = ss.parse(path)
    by = collections.Counter()  # (role, state) -> samples
    nthreads = collections.Counter()
    main_k = collections.Counter()
    main_deep = collections.Counter()
    rayon_busy = collections.Counter()
    yield_chains = collections.Counter()
    wake_chains = collections.Counter()
    for header, nodes in threads:
        samples = ss.self_samples(nodes)
        roles_here = set()
        rayonish = any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for st, _ in samples for n in st)
        for st, c in samples:
            r = "main" if is_main(st) else ("rayon" if rayonish else "other")
            roles_here.add(r)
            s = state(st[-1])
            by[(r, s)] += c
            if r == "main":
                k = main_kind(st)
                main_k[(k, s)] += c
                if k == "own work" and s == "run":
                    main_deep[ss.deepest_project(st) or st[-1]] += c
            elif r == "rayon" and s == "run":
                if ss.classify_rayon(st) == "busy":
                    rayon_busy[ss.deepest_project(st) or st[-1]] += c
                else:
                    rayon_busy["(idle, not yielding: " + st[-1][:60] + ")"] += c
            if s == "yield":
                yield_chains[" <- ".join(n[:70] for n in reversed(st[-6:]))] += c
            if s == "wake":
                wake_chains[" <- ".join(n[:70] for n in reversed(st[-7:]))] += c
        for r in roles_here:
            nthreads[r] += 1
    print(f"# A15 sealing-pass sample summary: {label}")
    print(f"interval {sec * 1000:.0f} ms; threads with samples: " + ", ".join(f"{r} {n}" for r, n in sorted(nthreads.items())))
    print("\n## samples by role and state (thread-seconds = samples x interval)")
    print("| role | run | yield | wake | mutex | vm | sleep | total |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    for r in ("main", "rayon", "other"):
        row = [by[(r, s)] for s in ("run", "yield", "wake", "mutex", "vm", "sleep")]
        print(f"| {r} | " + " | ".join(f"{c * sec:.2f}" for c in row) + f" | {sum(row) * sec:.2f} |")
    print("\n## the main line (the build's own thread), by what it does")
    tot = sum(main_k.values())
    for (k, s), c in main_k.most_common():
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(tot, 1):5.1f}%  {k} [{s}]")
    print(f"\n### the main line's own running work by deepest project frame, top {top}")
    for k, c in main_deep.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {k}")
    print(f"\n### rayon workers' running samples by deepest project frame, top {top}")
    for k, c in rayon_busy.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {k}")
    print("\n### the yield samples' chains (leaf first), top 6")
    for k, c in yield_chains.most_common(6):
        print(f"  {c:>7}  {k}")
    print("\n### the wake samples' chains (leaf first), top 6")
    for k, c in wake_chains.most_common(6):
        print(f"  {c:>7}  {k}")


if __name__ == "__main__":
    main()
