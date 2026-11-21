#!/usr/bin/env python3
"""Tick 31 (queue item 51): split of the host gap between a block's boundary-opening gather and the
next block's boundary commit, from the retained HL_PB_TIMING lines. Standard library only.
Usage: python3 -I this.py <results-dir>   (the A24 results directory, zk60_a24_app_20261107)
Reads two retained records, both at the R13 classifier profile (no W16R2 record has the run/frame
phases): baseline_b1_gpu_prove.log (one category, 26 blocks, solo GPU) and stream_p1/prover_phases.txt
(three categories, 78 blocks, summed). Prints every DERIVED number of the handoff."""
import re, sys, statistics as st, os

d = sys.argv[1]
want = ['run: block load + statement check', 'run: boundary B_k commitment', 'run: witness (CliSource)',
        'run: boundary B_(k-1) opening', 'frame: encode segment', 'sink: segment to disk', 'run: drop block']
per = {w: [] for w in want}
wall = []
for line in open(os.path.join(d, 'baseline_b1_gpu_prove.log'), errors='replace'):
    if line.startswith('PB-TIMING prove [') and 'wall' in line:
        m = re.search(r'wall ([0-9.]+) s', line)
        if m:
            wall.append(float(m.group(1)))
    if line.startswith('PB-TIMING prove |'):
        cells = [c.strip() for c in line.split('|')]
        if len(cells) > 4 and cells[1] in per:
            per[cells[1]].append(float(cells[3]))
print('baseline (R13, solo, GPU): proving calls', len(wall), 'median wall %.0f ms' % (1000 * st.median(wall)))
for w in want:
    v = per[w]
    if v:
        print('  %-40s n=%2d median %7.1f ms  min %7.1f  max %7.1f' % (w, len(v), 1000 * st.median(v), 1000 * min(v), 1000 * max(v)))
# first block carries cold costs; repeat without it
print('  without block 0:')
for w in want:
    v = per[w][1:]
    if v:
        print('  %-40s median %7.1f ms' % (w, 1000 * st.median(v)))

# the stream record: summed seconds over 78 blocks
tot = {}
for line in open(os.path.join(d, 'stream_p1', 'prover_phases.txt')):
    m = re.match(r'\s+([0-9.]+)\s+(.*)$', line)
    if m:
        tot[m.group(2).strip()] = float(m.group(1))
print('stream_p1 (R13, one lane of 32 threads, 78 blocks, summed %.3f s):' % tot['WALL CLOCK OF THE CALL'])
for w in want:
    if w in tot:
        print('  %-40s %7.1f ms per block' % (w, 1000 * tot[w] / 78))
pre = ['run: block load + statement check', 'run: boundary B_k commitment']
post = ['run: boundary B_(k-1) opening', 'frame: encode segment', 'sink: segment to disk', 'run: drop block']
print('  stream: phases after the opening gather in the same block (encode+sink+drop) %.1f ms; next block before the commit ends (load+check, B_k phase incl. its commit) %.1f ms'
      % (1000 * sum(tot.get(w, 0) for w in post[1:]) / 78, 1000 * sum(tot[w] for w in pre) / 78))
print('  stream: whole block %.1f ms; segment write share %.1f%%' % (1000 * tot['WALL CLOCK OF THE CALL'] / 78, 100 * tot['sink: segment to disk'] / tot['WALL CLOCK OF THE CALL']))
