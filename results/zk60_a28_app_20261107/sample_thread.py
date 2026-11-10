#!/usr/bin/env python3
"""Lane A28: where one thread of a macOS `sample` call graph spends its time (every sample, running or
blocked), by the deepest named frames of its stack (diagnostics only, public code symbols).

usage: sample_thread.py <sample.txt> <thread-name-substring> [--depth 3] [--top 40]
"""
import argparse
import collections
import sys

sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107')
import sample_profile as sp  # noqa: E402

BORING = ('rayon', 'core::', 'std::', 'crossbeam', 'alloc::', 'closure', 'call_mut', 'call_once', 'FnOnce', 'thread_start', '_pthread',
          'Iterator', 'from_iter', 'Vec', 'objc::rc', 'autoreleasepool', 'SpecFromIter', 'Folder', 'Producer', 'Consumer', 'bridge',
          'for_each', 'try_fold', 'collect', 'join_context', 'in_worker', 'install', 'Job::execute', 'StackJob', 'unwind',
          'panicking', 'Thread_', 'start_wqthread', '__rust_begin', 'thread::', 'Thread::new', 'objc_msgSend')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('path')
    ap.add_argument('thread')
    ap.add_argument('--depth', type=int, default=3)
    ap.add_argument('--top', type=int, default=40)
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
    total = 0
    for i, (d, n, s) in enumerate(entries):
        self_n = n - kids[i]
        if self_n <= 0:
            continue
        chain = []
        q = i
        while q is not None:
            chain.append(names[q])
            q = parent[q]
        if not any(a.thread in c for c in chain[-3:]):
            continue
        leaf = names[i]
        state = 'blocked' if any(b == leaf or leaf.startswith(b) for b in sp.BLOCKED) else ('yield' if any(y in leaf for y in sp.YIELD) else 'run')
        named = [c for c in chain if not any(b in c for b in BORING)]
        key = state + ' | ' + ' <- '.join(x.split('::')[-1][:40] for x in named[:a.depth]) + ' | ' + leaf.split('::')[-1][:30]
        agg[key] += self_n
        total += self_n
    print(f'{a.thread}: {total} samples')
    for k, v in agg.most_common(a.top):
        print(f'{v:7d} {100 * v / max(total, 1):5.1f}%  {k}')


if __name__ == '__main__':
    main()
