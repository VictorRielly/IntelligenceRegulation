#!/usr/bin/env python3
"""A11: summarize a macOS `/usr/bin/sample` call graph of the D55 harness's sampling window.

usage: sample_summary.py <sample.txt> [--interval-ms 2] [--top 25] [--label NAME]

Every SAMPLE is given a role:
- fork:   a fork's main line: every sample whose stack holds `prove_core`, on whatever thread runs it
          (a fork worker thread with the global pool; a thread of the fork's own pool with A11's pools);
- rayon:  a rayon pool worker's other samples (the global pool's, or a fork pool's);
- other:  anything else (the harness thread, Metal's and the system's threads).

For every self sample (a node's count minus its children's) the full stack is known, so:
- a fork worker's sample is
  `gpu-wait` (under `wait_done`, spinning or blocked on a command buffer),
  `pool-wait` (blocked in a rayon join it injected: `in_worker_cold`),
  `job-wait` (waiting for its next block on the job channel),
  or `host` (the worker's own code), split by the first frame under `prove_core` (the phase)
  and by the leaf;
- a rayon worker's sample is `idle` (sleeping or spinning for work) or `busy`, split by the
  outermost project frame of the job (the parallel region) and by the leaf.
Counts are printed with seconds (count x interval).
"""
import collections
import re
import sys

LINE = re.compile(r"^    ([ +!:|]*)(\d+) (.*)$")
HASH = re.compile(r"::h[0-9a-f]{16}$")
PROJECT = ("hashline::", "zkp_core::", "<hashline::", "<zkp_core::", "_<hashline", "_<zkp_core")


def fn_name(text):
    name = text.split("  (in ")[0].strip()
    return HASH.sub("", name)


def parse(path):
    """yield (thread_header, [(depth, count, name)]) per thread"""
    threads = []
    cur = None
    in_graph = False
    with open(path, errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if line.startswith("Call graph:"):
                in_graph = True
                continue
            if not in_graph:
                continue
            if line.startswith("Total number in stack") or line.startswith("Sort by top of stack"):
                break
            m = LINE.match(line)
            if not m:
                continue
            guides, count, rest = m.group(1), int(m.group(2)), m.group(3)
            depth = len(guides) // 2
            if depth == 0:
                cur = [rest, []]
                threads.append(cur)
                continue
            if cur is not None:
                cur[1].append((depth, count, fn_name(rest)))
    return threads


def self_samples(nodes):
    """yield (stack names root..node, self count)"""
    stack = []  # (depth, count, name, child_sum)
    out = []

    def pop_to(d):
        while stack and stack[-1][0] >= d:
            dd, c, n, cs = stack.pop()
            if c - cs > 0:
                out.append(([s[2] for s in stack] + [n], c - cs))

    for depth, count, name in nodes:
        pop_to(depth)
        if stack:
            stack[-1][3] += count
        stack.append([depth, count, name, 0])
    pop_to(0)
    return out


def role(samples):
    names = set()
    for st, _ in samples:
        names.update(st)
    if any("prove_one" in n or "prove_forks_inner" in n and "closure" in n for n in names):
        return "fork"
    if any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for n in names):
        return "rayon"
    return "other"


def first_project(st, after=None):
    i0 = 0
    if after is not None:
        for i, n in enumerate(st):
            if after in n:
                i0 = i + 1
                break
        else:
            return None
    for n in st[i0:]:
        if n.startswith(PROJECT):
            return n
    return None


def deepest_project(st):
    for n in reversed(st):
        if n.startswith(PROJECT):
            return n
    return None


# a fork's main line: `prove_core` (its caller `prove_one` is inlined)
MAIN = "private_block::protocol::prove_core"


def is_main(st):
    return any(MAIN in n for n in st)


WAIT_LEAVES = ("__psynch_cvwait", "__psynch_mutexwait", "swtch_pri", "__ulock_wait", "semaphore_wait", "__semwait", "thread_switch")


def classify_fork(st):
    """a sample of a fork's main line (a stack holding `prove_core`), on whatever thread runs it"""
    if any("wait_done" in n or "waitUntilCompleted" in n or "wait_until_completed" in n for n in st):
        return "gpu-wait"
    if any("in_worker_cold" in n for n in st):
        return "pool-wait"
    # A11 per-fork pools: the main line is a pool worker; in a join it waits in
    # `wait_until_cold`, sleeping, yielding or running its own fork's stolen tasks
    i = next((i for i, n in enumerate(st) if MAIN in n), None)
    if i is not None:
        later = [j for j, n in enumerate(st) if j > i and "wait_until_cold" in n]
        if later:
            below = st[later[-1] + 1:]
            if any("execute" in n and "Job" in n for n in below):
                return "pool-work"
            return "pool-wait"
    if any("mpsc" in n or "Receiver" in n and "recv" in n for n in st):
        return "job-wait"
    return "host"


IDLE_HINTS = ("Sleep::sleep", "wait_until_cold", "no_work_found", "yield_now", "swtch_pri", "__psynch_cvwait", "thread_switch")


def classify_rayon(st):
    # busy if any job frame is on the stack
    if any("StackJob" in n and "execute" in n or "HeapJob" in n and "execute" in n or "JobRef::execute" in n or "join_context" in n or "bridge_producer_consumer" in n for n in st):
        return "busy"
    if any(h in n for n in st for h in IDLE_HINTS):
        return "idle"
    return "idle?"


def main():
    args = sys.argv[1:]
    path = args[0]
    interval = 2.0
    top = 25
    label = path
    if "--interval-ms" in args:
        interval = float(args[args.index("--interval-ms") + 1])
    if "--top" in args:
        top = int(args[args.index("--top") + 1])
    if "--label" in args:
        label = args[args.index("--label") + 1]
    sec = interval / 1000.0
    threads = parse(path)
    # roles per SAMPLE: a stack holding `prove_core` is a fork's main line on whatever
    # thread runs it (a plain fork worker thread with the global pool; a pool thread
    # of the fork's own pool with A11's per-fork pools); the rest of a rayon
    # worker's samples are the pool's; everything else is "other"
    by_role = collections.defaultdict(list)
    for header, nodes in threads:
        ss = self_samples(nodes)
        main = [(st, c) for st, c in ss if is_main(st)]
        rest = [(st, c) for st, c in ss if not is_main(st)]
        rayonish = any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for st, _ in rest for n in st)
        if main:
            by_role["fork"].append((header, main))
        if rest:
            by_role["rayon" if rayonish else "other"].append((header, rest))
    print(f"# A11 sample summary: {label}")
    print(f"interval {interval} ms; threads: " + ", ".join(f"{r} {len(v)}" for r, v in sorted(by_role.items())))
    # fork workers
    forks = by_role.get("fork", [])
    cat = collections.Counter()
    phase = collections.Counter()
    leaf = collections.Counter()
    region_host = collections.Counter()
    pool_phase = collections.Counter()
    gpu_phase = collections.Counter()
    for _, ss in forks:
        for st, c in ss:
            k = classify_fork(st)
            cat[k] += c
            ph = first_project(st, after="prove_core") or first_project(st, after="prove_one") or "(outside prove_core)"
            if k == "host":
                phase[ph] += c
                leaf[st[-1]] += c
                region_host[deepest_project(st) or st[-1]] += c
            elif k == "pool-wait":
                pool_phase[ph] += c
                # the project frame that made the join
                d = None
                for i, n in enumerate(st):
                    if "in_worker_cold" in n or "in_worker" in n and "registry" in n:
                        break
                    if n.startswith(PROJECT):
                        d = n
                pool_phase["  via " + (d or "?")] += c
            elif k == "gpu-wait":
                gpu_phase[ph] += c
    tot = sum(cat.values())
    print(f"\n## fork workers ({len(forks)} threads): {tot} samples = {tot * sec:.2f} thread-s")
    for k, c in cat.most_common():
        print(f"  {k:<10} {c:>7} = {c * sec:7.2f} s  {100 * c / max(tot, 1):5.1f}%")
    print(f"\n### fork host samples by phase (first project frame under prove_core), top {top}")
    for k, c in phase.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(cat['host'], 1):5.1f}%  {k}")
    print(f"\n### fork host samples by deepest project frame, top {top}")
    for k, c in region_host.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(cat['host'], 1):5.1f}%  {k}")
    print(f"\n### fork host samples by leaf, top {top}")
    for k, c in leaf.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(cat['host'], 1):5.1f}%  {k}")
    print(f"\n### fork pool-wait samples by phase and by the frame that joined, top {top}")
    for k, c in pool_phase.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {k}")
    print(f"\n### fork gpu-wait samples by phase, top {top}")
    for k, c in gpu_phase.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {k}")
    # rayon workers
    ray = by_role.get("rayon", [])
    rcat = collections.Counter()
    rregion = collections.Counter()
    rleaf = collections.Counter()
    rdeep = collections.Counter()
    for _, ss in ray:
        for st, c in ss:
            k = classify_rayon(st)
            rcat[k] += c
            if k == "busy":
                rregion[first_project(st) or "(no project frame)"] += c
                rleaf[st[-1]] += c
                rdeep[deepest_project(st) or st[-1]] += c
    rt = sum(rcat.values())
    print(f"\n## rayon workers ({len(ray)} threads): {rt} samples = {rt * sec:.2f} thread-s")
    for k, c in rcat.most_common():
        print(f"  {k:<10} {c:>7} = {c * sec:7.2f} s  {100 * c / max(rt, 1):5.1f}%")
    print(f"\n### rayon busy samples by region (outermost project frame), top {top}")
    for k, c in rregion.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(rcat['busy'], 1):5.1f}%  {k}")
    print(f"\n### rayon busy samples by deepest project frame, top {top}")
    for k, c in rdeep.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(rcat['busy'], 1):5.1f}%  {k}")
    print(f"\n### rayon busy samples by leaf, top {top}")
    for k, c in rleaf.most_common(top):
        print(f"  {c:>7} = {c * sec:6.2f} s  {100 * c / max(rcat['busy'], 1):5.1f}%  {k}")
    # others
    oth = by_role.get("other", [])
    print(f"\n## other threads ({len(oth)})")
    for header, ss in sorted(oth, key=lambda t: -sum(c for _, c in t[1]))[:12]:
        n = sum(c for _, c in ss)
        lc = collections.Counter()
        for st, c in ss:
            lc[st[-1]] += c
        tops = "; ".join(f"{k} {c}" for k, c in lc.most_common(3))
        print(f"  {n:>7} {header[:70]} | {tops[:160]}")


if __name__ == "__main__":
    main()
