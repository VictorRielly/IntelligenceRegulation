#!/usr/bin/env python3
"""A17: inside one bucket of A14's `rank.py`, the fork main lines' (not waiting on the GPU) and the pools'
busy samples by LEAF frame (system frames included: `__bzero`, `_platform_memset`, `mach_vm_deallocate`, a page
fault's faulting store) and the deepest project frame above it, so a bucket such as the A/H zero-fill can be split
into its allocation fill, its first-touch faults and its frees.

usage: leaf_detail.py <sample.txt> <bucket-prefix> [top] [--interval-ms 2] [--calls 3]
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "a14"))
import rank  # noqa: E402

ss = rank.ss


def short(n):
    return n.replace("hashline::private_block::", "").replace("zkp_core::", "zc::")[:90]


def main():
    a = sys.argv[1:]
    path, want = a[0], a[1]
    top = int(a[2]) if len(a) > 2 and a[2].isdigit() else 25
    interval = float(a[a.index("--interval-ms") + 1]) if "--interval-ms" in a else 2.0
    calls = int(a[a.index("--calls") + 1]) if "--calls" in a else 3
    sec = interval / 1000.0
    rank.keep_helper_hashes()
    threads = ss.parse(path)
    owners = rank.helper_owner_map(threads)
    mc, pc = collections.Counter(), collections.Counter()
    for header, nodes in threads:
        samples = ss.self_samples(nodes)
        rayonish = any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for st, _ in samples for n in st)
        for st, c in samples:
            st2 = rank.resolve(st, owners)
            if not rank.bucket(st2).startswith(want):
                continue
            proj = [n for n in st2 if n.startswith(ss.PROJECT) and not n.startswith(rank.HELPER)]
            key = f"{short(st[-1])}  <=  {short(proj[-1]) if proj else '-'}"
            if ss.is_main(st):
                if ss.classify_fork(st) == "gpu-wait":
                    continue
                mc[key] += c
            elif rayonish and ss.classify_rayon(st) == "busy":
                pc[key] += c
    print(f"## bucket: {want} (by leaf frame <= deepest project frame; s per fork per call = samples x {interval} ms / {calls} calls / 6 forks)")
    print("main line")
    for k, c in mc.most_common(top):
        print(f"  {c:6d} {c * sec / calls / 6:7.4f} s  {k}")
    print(f"  total {sum(mc.values())} = {sum(mc.values()) * sec / calls / 6:.4f} s per fork per call")
    print("pool busy")
    for k, c in pc.most_common(top):
        print(f"  {c:6d} {c * sec / calls:7.3f} CPU-s/call  {k}")
    print(f"  total {sum(pc.values())} = {sum(pc.values()) * sec / calls:.3f} CPU-s per call")


if __name__ == "__main__":
    main()
