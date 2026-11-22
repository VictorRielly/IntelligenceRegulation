#!/usr/bin/env python3
"""Device rounds per zero-check slot in a GPU trace, for the tail-round test (HL_METAL_BATCH_TAIL_US).

usage: python3 -I -B tail_rounds_nd.py <trace.tsv or trace.tsv.xz> [more traces ...]

For every `batch` row the trace's detail field gives nd (the rounds the device ran in one command buffer) and n_vars
(all rounds of the slot).  Per slot this prints the count of rows, nd (every value seen), n_vars, the host rounds
n_vars - nd, and the mean execution time of the buffer; then the sums over the slots that occur in at least half of the
blocks.  Standard library only.
"""
import collections
import lzma
import re
import sys


def rows(path):
    op = lzma.open if path.endswith('.xz') else open
    with op(path, 'rt') as f:
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) >= 9 and p[0] == 'batch':
                yield p


def main():
    for path in sys.argv[1:]:
        slots = collections.defaultdict(lambda: {'n': 0, 'nd': collections.Counter(), 'nv': collections.Counter(), 'ex': 0.0})
        for p in rows(path):
            ms = re.match(r'slot (\d+) ', p[1])
            md = re.search(r'\bnd=(\d+)', p[1])
            mv = re.search(r'\bn_vars=(\d+)', p[1])
            if not (ms and md and mv):
                continue
            s = slots[int(ms.group(1))]
            s['n'] += 1
            s['nd'][int(md.group(1))] += 1
            s['nv'][int(mv.group(1))] += 1
            s['ex'] += float(p[-2]) - float(p[-3])
        if not slots:
            print(path, ': no batch rows')
            continue
        top = max(s['n'] for s in slots.values())
        print(path.rsplit('/', 1)[-1])
        print('  slot  rows  nd (count)            n_vars  host rounds  mean exec ms')
        tnd = tnv = 0
        tex = 0.0
        for k in sorted(slots):
            s = slots[k]
            nd = s['nd'].most_common(1)[0][0]
            nv = s['nv'].most_common(1)[0][0]
            main_slot = s['n'] * 2 >= top
            if main_slot:
                tnd += nd
                tnv += nv
                tex += s['ex'] / s['n'] * 1e3
            print('  %4d %5d  %-20s  %6d  %11d  %12.3f%s' % (k, s['n'], ' '.join('%d (%d)' % kv for kv in sorted(s['nd'].items())), nv, nv - nd,
                                                      s['ex'] / s['n'] * 1e3, '' if main_slot else '   (rare, not summed)'))
        print('  main slots: device rounds %d, all rounds %d, host rounds %d, mean execution of their buffers %.2f ms a block' % (tnd, tnv, tnv - tnd, tex))


if __name__ == '__main__':
    main()
