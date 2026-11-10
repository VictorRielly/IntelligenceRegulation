#!/usr/bin/env python3
"""Lane A28: a macOS `sample` call graph's RUNNING self time, each sample attributed to its nearest
named (non-library) caller (A26's sample_profile.py parser; diagnostics only, public code symbols).

usage: sample_self.py <sample.txt> [--top 40] [--under NAME]
  --under NAME: only stacks that pass through NAME (e.g. prove_classify_run_with)
"""
import argparse
import collections
import sys

sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107')
import sample_profile as sp  # noqa: E402

BORING = ('rayon', 'core::', 'std::', 'crossbeam', 'alloc::', 'closure', 'call_mut', 'call_once', 'FnOnce', 'thread_start', '_pthread',
          'Iterator', 'from_iter', 'Vec', 'objc::rc', 'autoreleasepool', 'SpecFromIter', 'Folder', 'Producer', 'Consumer', 'bridge',
          'for_each', 'try_fold', 'fold', 'map', 'collect', 'join_context', 'in_worker', 'install', 'Job::execute', 'StackJob', 'unwind',
          'panicking', '_platform_', '__bzero', 'memset', 'memmove', 'memcpy')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('path')
    ap.add_argument('--top', type=int, default=40)
    ap.add_argument('--under', default=None)
    a = ap.parse_args()
    entries = list(sp.parse(a.path))
    names = [sp.short(e[2]) for e in entries]
    parent = [None] * len(entries)
    st = []
    kids = collections.defaultdict(int)
    for i, (d, n, s) in enumerate(entries):
        while st and entries[st[-1]][0] >= d:
            st.pop()
        parent[i] = st[-1] if st else None
        if parent[i] is not None:
            kids[parent[i]] += n
        st.append(i)
    agg = collections.Counter()
    leafname = collections.Counter()
    total = 0
    for i, (d, n, s) in enumerate(entries):
        self_n = n - kids[i]
        if self_n <= 0:
            continue
        nm = names[i]
        if any(b in nm for b in sp.BLOCKED) or any(y in nm for y in sp.YIELD) or nm in sp.BLOCKED:
            continue
        chain = []
        q = i
        while q is not None:
            chain.append(names[q])
            q = parent[q]
        if a.under and not any(a.under in c for c in chain):
            continue
        owner = next((c for c in chain if not any(b in c for b in BORING)), nm)
        agg[owner] += self_n
        leafname[(owner, nm)] += self_n
        total += self_n
    print(f'running self samples{" under " + a.under if a.under else ""}: {total}')
    for k, v in agg.most_common(a.top):
        top_leaf = max(((l, c) for (o, l), c in leafname.items() if o == k), key=lambda x: x[1])
        print(f'{v:9d} {100 * v / max(total, 1):5.1f}%  {k[:110]}   [leaf: {top_leaf[0][:60]}]')


if __name__ == '__main__':
    main()
