#!/usr/bin/env python3
"""A11: the most common caller chains of the self samples whose leaf matches a pattern.

usage: sample_chains.py <sample.txt> <leaf-regex> [--role fork|rayon|other|any] [--depth 8] [--top 15]
       [--under <frame-regex>]   (only stacks with a frame matching this)

Reuses sample_summary.py's parser and roles. Each chain is printed leaf first.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sample_summary as ss  # noqa: E402


def main():
    a = sys.argv[1:]
    path, pat = a[0], re.compile(a[1])
    opt = lambda k, d: a[a.index(k) + 1] if k in a else d
    role_want = opt("--role", "any")
    depth = int(opt("--depth", "8"))
    top = int(opt("--top", "15"))
    under = opt("--under", None)
    under = re.compile(under) if under else None
    chains = collections.Counter()
    total = 0
    for header, nodes in ss.parse(path):
        samples = ss.self_samples(nodes)
        r = ss.role(samples)
        if role_want != "any" and r != role_want:
            continue
        for st, c in samples:
            if not pat.search(st[-1]):
                continue
            if under and not any(under.search(n) for n in st):
                continue
            total += c
            chains[" <- ".join(n[:90] for n in reversed(st[-depth:]))] += c
    print(f"# {total} self samples with leaf ~ {a[1]} (role {role_want})")
    for k, c in chains.most_common(top):
        print(f"{c:>7}  {k}")


if __name__ == "__main__":
    main()
