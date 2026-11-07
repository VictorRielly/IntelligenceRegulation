#!/usr/bin/env python3
"""Lane A26: summarize a macOS `sample` call-graph file (diagnostics only; public code symbols).

usage: sample_profile.py <sample.txt> [--top N] [--inclusive PATTERN,...]

Prints, over every thread of the process:
  * the samples by STATE of the top of the stack: blocked in the kernel (waits, I/O), yielding
    (rayon's idle spin: `swtch_pri` / `thread_switch` / `sched_yield`), or running code;
  * the running samples by top-of-stack function (self time);
  * the INCLUSIVE samples of every function (each sample counted once per function, the
    outermost occurrence on its stack), for the top N and for the names matching PATTERNs.
Rust symbols are shortened (hash suffixes and generic arguments dropped).
"""
import collections
import re
import sys

BLOCKED = ('__psynch_cvwait', '__workq_kernreturn', 'mach_msg2_trap', 'mach_msg_trap', '__semwait_signal', 'kevent', 'kevent_id',
           '__ulock_wait', '__ulock_wait2', 'read', '__read_nocancel', '__select', 'poll', '__open', 'write', '__write_nocancel',
           '__psynch_mutexwait', 'semaphore_wait_trap', 'semaphore_timedwait_trap', '__wait4', '__sigsuspend', 'fsync', '__fsync',
           '__close_nocancel', 'close', '__pread', 'pread', '__mmap', '__munmap', 'madvise', '__open_nocancel', 'openat',
           '__getdirentries64', 'stat64', '__stat64', 'lstat', 'fstat64', '__fcntl', 'fcntl', '__rename', 'rename', 'unlink', 'mkdir')
YIELD = ('swtch_pri', 'thread_switch', 'sched_yield', '__sched_yield')

LINE = re.compile(r'^(?P<pre>[\s+!:|]*)(?P<n>\d+)\s+(?P<sym>.+?)\s*$')


KEEP_HASH = False


def short(sym):
    s = sym
    if KEEP_HASH and ('rayon' in s or 'closure' in s or 'call_mut' in s):
        m = re.search(r'::(h[0-9a-f]{16})', s)
        tail = m.group(1) if m else ''
        return short_plain(s) + (' #' + tail if tail else '')
    return short_plain(s)


def short_plain(sym):
    s = sym
    s = re.sub(r'\s+\(in [^)]*\)\s*\+\s*\d+.*$', '', s)
    s = re.sub(r'\s+\(in [^)]*\).*$', '', s)
    s = re.sub(r'\s+\+\s+\d+.*$', '', s)
    s = re.sub(r'::h[0-9a-f]{16}$', '', s)
    s = s.replace('_$LT$', '<').replace('$GT$', '>').replace('$u20$', ' ').replace('..', '::')
    # drop generic arguments
    out, depth = [], 0
    for ch in s:
        if ch == '<':
            depth += 1
            continue
        if ch == '>':
            depth = max(0, depth - 1)
            continue
        if depth == 0:
            out.append(ch)
    s = ''.join(out)
    s = re.sub(r'\{\{closure\}\}', '{closure}', s)
    return s.strip()


def parse(path):
    """yield (depth, count, symbol) for the call graph section, threads at depth 0"""
    in_graph = False
    for raw in open(path, errors='replace'):
        line = raw.rstrip('\n')
        if line.startswith('Call graph:'):
            in_graph = True
            continue
        if not in_graph:
            continue
        if line.startswith('Total number in stack') or line.startswith('Sort by top of stack') or line.startswith('Binary Images'):
            break
        if not line.strip():
            continue
        m = LINE.match(line)
        if not m:
            continue
        pre = m.group('pre')
        depth = len(pre)
        yield depth, int(m.group('n')), m.group('sym')


def main():
    path = sys.argv[1]
    top = 40
    pats = []
    args = sys.argv[2:]
    while args:
        if args[0] == '--top':
            top = int(args[1]); args = args[2:]
        elif args[0] == '--hash':
            global KEEP_HASH
            KEEP_HASH = True; args = args[1:]
        elif args[0] == '--who':
            pats.append('__WHO__'); args = args[1:]
        elif args[0] == '--inclusive':
            pats = [p for p in args[1].split(',') if p]; args = args[2:]
        else:
            args = args[1:]
    entries = list(parse(path))
    # the tree: each entry's parent is the nearest earlier entry of smaller indentation
    parent = [None] * len(entries)
    st = []
    for idx, (depth, n, sym) in enumerate(entries):
        while st and entries[st[-1]][0] >= depth:
            st.pop()
        parent[idx] = st[-1] if st else None
        st.append(idx)
    kids = collections.Counter()
    for idx, p in enumerate(parent):
        if p is not None:
            kids[p] += entries[idx][1]
    names = [short(e[2]) for e in entries]
    selfc = collections.Counter()
    state = collections.Counter()
    total = 0
    for idx, (depth, n, sym) in enumerate(entries):
        s = n - kids[idx]
        if s <= 0:
            continue
        if parent[idx] is None:
            # a thread line itself carrying samples with no frames: ignore
            continue
        nm = names[idx]
        base = nm.split('::')[-1]
        if base in BLOCKED or nm in BLOCKED:
            state['blocked (kernel wait / I/O)'] += s
        elif base in YIELD or nm in YIELD:
            state['yield (idle spin)'] += s
        else:
            state['running'] += s
            selfc[nm] += s
        total += s
    # inclusive: each sample once per function (outermost occurrence): count a node only if no ancestor has its name
    incl = collections.Counter()
    for idx in range(len(entries)):
        if parent[idx] is None:
            continue
        nm = names[idx]
        p = parent[idx]
        dup = False
        while p is not None:
            if names[p] == nm:
                dup = True
                break
            p = parent[p]
        if not dup:
            incl[nm] += entries[idx][1]
    run = state['running']
    print(f'{path}: {total} thread-samples')
    for k, v in state.most_common():
        print(f'  {v:9d}  {100.0 * v / max(total, 1):5.1f}%  {k}')
    print(f'\nrunning, by top-of-stack function (self), top {top} (% of running):')
    for k, v in selfc.most_common(top):
        print(f'  {v:9d}  {100.0 * v / max(run, 1):5.1f}%  {k[:150]}')
    print(f'\ninclusive (% of all thread-samples), top {top}:')
    for k, v in incl.most_common(top):
        print(f'  {v:9d}  {100.0 * v / max(total, 1):5.1f}%  {k[:150]}')
    if '__WHO__' in pats:
        # for the top self symbols: the nearest ancestor that is not rayon / std / core machinery
        boring = ('rayon', 'core::', 'std::', 'crossbeam', 'alloc::', '{closure}', 'call_mut', 'call_once', 'FnOnce', 'thread_start', '_pthread', 'Iterator', 'from_iter', 'SpecFromIter', 'Vec')
        who = collections.defaultdict(collections.Counter)
        for idx, (depth, n, sym) in enumerate(entries):
            s_ = n - kids[idx]
            if s_ <= 0 or parent[idx] is None:
                continue
            nm = names[idx]
            q = parent[idx]
            anc = None
            while q is not None:
                if not any(b in names[q] for b in boring) and parent[q] is not None:
                    anc = names[q]
                    break
                q = parent[q]
            who[nm][anc or '(worker thread: no named caller)'] += s_
        for k, v in selfc.most_common(top):
            print(f'\n{v:9d} self  {k[:120]}')
            for a, c in who[k].most_common(6):
                print(f'      {c:9d}  <- {a[:120]}')
    for p in pats:
        if p == '__WHO__':
            continue
        print(f'\ninclusive matching {p!r}:')
        for k, v in incl.most_common():
            if p in k:
                print(f'  {v:9d}  {100.0 * v / max(total, 1):5.1f}%  {k[:150]}')


if __name__ == '__main__':
    main()
