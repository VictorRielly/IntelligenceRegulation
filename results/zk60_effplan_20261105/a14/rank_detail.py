#!/usr/bin/env python3
"""A14: the project-frame paths inside one bucket of `rank.py`, for the fork main lines (not waiting on the GPU)
and the rayon pools' busy samples.

usage: rank_detail.py <sample.txt> <bucket-prefix> [top]
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rank  # noqa: E402

ss = rank.ss


def main():
    path, want = sys.argv[1], sys.argv[2]
    top = int(sys.argv[3]) if len(sys.argv) > 3 else 15
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
            key = " > ".join(p.replace("hashline::private_block::", "").replace("zkp_core::", "zc::")[:60] for p in proj[-4:])
            if ss.is_main(st):
                if ss.classify_fork(st) == "gpu-wait":
                    continue
                mc[key] += c
            elif rayonish and ss.classify_rayon(st) == "busy":
                pc[key] += c
    print(f"## bucket: {want}")
    print("main line (samples, the last four project frames)")
    for k, c in mc.most_common(top):
        print(f"  {c:6d} {k}")
    print("pool busy")
    for k, c in pc.most_common(top):
        print(f"  {c:6d} {k}")


if __name__ == "__main__":
    main()
