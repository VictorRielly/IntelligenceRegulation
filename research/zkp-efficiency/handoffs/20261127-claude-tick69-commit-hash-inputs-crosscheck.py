#!/usr/bin/env python3
"""Coordinator's cross-check of research tick 69 (queue item 109): what the commitment hash kernel reads a block, the
rate it runs at, and the price of a field hash in its place. Standard library only; reads tracked files of this
repository, runs nothing of the prover.

  python3 -I 20261127-claude-tick69-commit-hash-inputs-crosscheck.py

Part A: code lines the handoff's counts rest on, asserted in the source (tree ops/zkp-mvp/gpu-metal/).
Part B: every figure borrowed from a retained record or an earlier tick, asserted in that file.
Part C: every derived figure recomputed here and asserted against the handoff's text.
MINE:   the coordinator's own remarks, computed here.
Exit 0 only if every check passes."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..')) + '/'
G = ROOT + 'ops/zkp-mvp/gpu-metal/'
HB = HERE + '/20261127-claude-tick69-commit-hash-inputs'
n_checks = n_failed = 0


def check(name, cond, shown=''):
    global n_checks, n_failed
    n_checks += 1
    if not cond:
        n_failed += 1
    print('%s %s%s' % ('ok  ' if cond else 'FAIL', name, (' | ' + str(shown)) if shown != '' else ''))


def norm(t):
    return ' '.join(t.split())


_cache = {}


def lines(path):
    if path not in _cache:
        _cache[path] = open(path, encoding='utf-8').read().split('\n')
    return _cache[path]


def at(path, n, sub):
    """line n (1-based) of path contains sub"""
    return sub in lines(path)[n - 1]


def text(path):
    return norm('\n'.join(lines(path)))


hand = text(HB + '.md')

print('== Part A: the code ==')
MR = G + 'hashline/src/gpu/metal.rs'
check('the two-pass hash is on unless HL_A28_HASH=0 (metal.rs:535-538)',
      at(MR, 535, 'fn hash2_on() -> bool') and at(MR, 537, 'HL_A28_HASH') and at(MR, 537, 'unwrap_or(true)'))
PC = G + 'zkp-core/src/pcs.rs'
check('rows of a commit = data words / n (pcs.rs:788)', at(PC, 788, 'let rows = data_ref.len() / n;'))
check('the salted leaves and the tree are made on the host after the device returns (pcs.rs:806-807)',
      at(PC, 806, 'salt_leaf_keyed(l, s, tag.leaf_key())') and at(PC, 807, 'MerkleTree::build_keyed(salted, tag.node_key())'))
MK = G + 'hashline/src/gpu/metal_kernels.metal'
check('a block of a chunk of column j reads words (chunk*128 + blk*8 + t) * nn + j (metal_kernels.metal:1140-1143)',
      at(MK, 1140, 'ulong e0 = chunk * 128UL + ulong(blk) * 8UL;') and at(MK, 1143, 'enc[e * nn + j]'))
LY = G + 'hashline/src/private_block/layout.rs'
check('A rows = data rows + two rows a site + a proximity pair (layout.rs:1340-1342)',
      at(LY, 1340, 'let a_mask_base = a_data_rows;') and at(LY, 1341, 'let a_prox = a_mask_base + 2 * a_prefix[ns];')
      and at(LY, 1342, 'let a_rows = a_prox + 2;'))
check('H rows by the same rule (layout.rs:1351-1353)',
      at(LY, 1351, 'let h_mask_base = h_data_rows;') and at(LY, 1352, 'let h_prox = h_mask_base + 2 * h_prefix[ns];')
      and at(LY, 1353, 'let h_rows = h_prox + 2;'))
VM = ROOT + 'results/zk60_a28_app_20261107/nbench/variants.metal'
check('the bench probe: 16 words a thread, 88 operations a thread (variants.metal:291)',
      at(VM, 291, '16 words per thread, 11 rounds of 8 butterflies each (88 butterflies)'))
check('its third form is the product alone (variants.metal:302-303)',
      at(VM, 302, '// the product alone') and at(VM, 303, 'u = gl_mul(v, w);'))

print('== Part B: the records ==')
NB = ROOT + 'results/zk60_a28_app_20261107/nb3.log'
nb = {}
for i in (34, 35, 38, 39, 40, 41, 42, 29):
    l = lines(NB)[i - 1]
    nb[i] = (l[:36].strip(), float(l.split()[-2]))
check('nb3.log:34 hash (tree) 5.469 ms', nb[34] == ('hash (tree)', 5.469), nb[34])
check('nb3.log:35 hash chunk+merge 4.237 ms', nb[35] == ('hash chunk+merge tg 64', 4.237), nb[35])
check('nb3.log:38 hash chunk only 3.951 ms', nb[38] == ('hash chunk only tg 256', 3.951), nb[38])
check('nb3.log:40 butterfly probe 15.723 ms', nb[40] == ('alu: butterfly (mul+add+sub)', 15.723), nb[40])
check('nb3.log:41 add and sub alone 10.355 ms', nb[41] == ('alu: add+sub only', 10.355), nb[41])
check('nb3.log:42 product alone 13.155 ms', nb[42] == ('alu: mul only', 13.155), nb[42])
AR = ROOT + 'results/zk60_a28_app_20261107/README.md'
check('the bench shape: 4577 rows x 2^14 -> 2^16, each kernel alone, best of 5 (README:126-127)',
      at(AR, 126, '4577 rows x') and at(AR, 127, '2^14 -> 2^16, each kernel alone, GPU timestamps, best of 5'))
check('the probe is "11 stages\' worth" with no memory (README:135)',
      at(AR, 135, "an in-register butterfly probe (no memory): 11 stages' worth | 15.72 ms"))
check('the README itself reads 105 G/s for butterflies in registers (README:138)',
      at(AR, 138, '105 G/s for butterflies in registers'))
SJ = json.load(open(ROOT + 'results/zk60_w16r2_shield_block_20261120/summary.json', encoding='utf-8'))
arm = SJ['20261117_w16r2_8b_armA_prod_batched']
check('the 8B arm of the Nov 17 trace: A 2504 rows, H 2606 rows',
      arm['a_commit_rows'] == 2504 and arm['other_commit_rows'] == [2606])
check('same arm: block GPU 91.462 ms, commits 13.987 and 13.9 ms (5 warm passes)',
      arm['median_ms']['block_gpu'] == 91.462 and arm['median_ms']['commit_A'] == 13.987
      and arm['median_ms']['commit_H'] == 13.9 and arm['warm_passes'] == 5)
CL = ROOT + 'results/zk60_effplan_20261105/census.log'
check('census.log:218 the 8B profile on Nov 5: A rows 2501 (data 2279), H rows 2602 (data 2514)',
      at(CL, 218, 'CENSUS W16R2_8B_T128_H24 (n = 2^14): A rows 2501 (data 2279), H rows 2602 (data 2514)'))
check('census.log:227 and 235: Tab planes 15 in A and 16 in H',
      norm(lines(CL)[226]) == 'CENSUS W16R2_8B_T128_H24 A Tab planes 15 rows 15'
      and norm(lines(CL)[234]) == 'CENSUS W16R2_8B_T128_H24 H Tab planes 16 rows 16')
check('census.log:236 H helper rows 1257 (two rows each = 2514)',
      norm(lines(CL)[235]) == 'CENSUS W16R2_8B_T128_H24 H data rows by domain: 1257' and 2 * 1257 == 2514)
T21 = text(HERE + '/20261119-claude-tick21-commit-split.md')
check('tick 21: old-form hash 1.660 and 1.727 ms; forward 6.897 and 7.132 ms',
      '| Diag: hash (old one-thread-per-column `k_hash_cols`) | 1.660 | 1.727 |' in T21
      and '| Diag: forward transform (2^14 to 2^15 or 2^16) | 6.897 | 7.132 |' in T21)
check('tick 21 names its rows: 2,504 (A) and 2,606 (H) at 8B', 'Rows: 2,504 (A) and 2,606 (H) at 8B with `log_n = 14, log_nn = 15`' in T21)
T67 = text(HERE + '/20261126-claude-tick67-field-hash-wrapper.md')
check('tick 67 used the census rows: 5,103 rows x 2^15 = 167.2 M words', '5,103 rows x 2^15 = 167.2 M words' in T67)
check('tick 67: the 478 G/s ceiling was assumed, and gave its 32 ms',
      'an ASSUMED hardware ceiling of 478 G/s (80 cores x 128 lanes x 1.4 GHz / 30 operations) gives **32 ms**' in T67)
LR = text(ROOT + 'results/zk60_claude_review_20261116/W16R2_LAYOUT_CONSUME_READ_20261127.md')
check('the installed classifier profile, read today: A sites 2280..2501, rows 2504; H sites 2516..2603, rows 2606',
      'Sites 2280..2501, proximity pair 2502-2503, rows 2504' in LR and 'Sites 2516..2603, proximity 2604-2605, rows 2606' in LR)
check('same read: 16 Tab planes in A, 3+13+1 Tab helpers in H', 'Tab 16 planes' in LR and 'Tab 3+13+1 = 44' in LR)

print('== Part C: the derived figures ==')
NN = 2 ** 15
ra, rh = 2504, 2606
words = (ra + rh) * NN
mb = words * 8 / 1e6
check('words a block = 167,444,480 = 167.44 M, 1,339.6 MB', words == 167444480 and '%.1f' % mb == '1339.6'
      and '167.44 M words a block' in hand and '1,339.6 MB' in hand)
cw = (2501 + 2602) * NN
check('against the census rows: 167,215,104 words, +0.137%', cw == 167215104 and 0.13 < (words / cw - 1) * 100 < 0.14,
      '%.3f%%' % ((words / cw - 1) * 100))


def b3(rows):
    by = rows * 8
    chunks = math.ceil(by / 1024)
    blocks = math.ceil(by / 64)
    return chunks, blocks, blocks + chunks - 1


ca, ch = b3(ra), b3(rh)
check('compressions a column: A 20 chunks, 313 + 19 = 332; H 21 chunks, 326 + 20 = 346',
      ca == (20, 313, 332) and ch == (21, 326, 346) and '**332 compressions**' in hand and '**346**' in hand)
comp = (ca[2] + ch[2]) * NN
check('compressions a block = 22,216,704 (22.22 M)', comp == 22216704 and '**22.22 M compressions**' in hand)
perms = (math.ceil(ra / 8) + math.ceil(rh / 8)) * NN
check('rate-8 sponge permutations a block = 20,938,752 (20.94 M)', perms == 20938752 and '**20.94 M a block**' in hand)
check('736 = 4*8*12 + 4*22 + 12*22 products a permutation (the instance is the handoff\x27s assumption)',
      4 * 8 * 12 + 4 * 22 + 12 * 22 == 736)
mults = perms * 736
check('products a block = 15.41 G', '%.2f' % (mults / 1e9) == '15.41' and '15.41 G a block' in hand)
old = 1.660 + 1.727
check('old-form hash at this shape: 3.387 ms = 395 GB/s', '%.0f' % (mb / old) == '395' and '**395 GB/s' in hand, '%.1f' % (mb / old))
bmb = 4577 * 2 ** 16 * 8 / 1e6
check('bench bytes 2,399.7 MB: old form 439 GB/s, two passes 566 GB/s, ratio 0.775',
      '%.1f' % bmb == '2399.7' and '%.0f' % (bmb / 5.469) == '439' and '%.0f' % (bmb / 4.237) == '566'
      and '%.3f' % (4.237 / 5.469) == '0.775')
check('two passes at this shape, three ways: 2.62, 2.37, 2.68 ms (derived, not measured)',
      '%.2f' % (old * 4.237 / 5.469) == '2.62' and '%.2f' % (mb / (bmb / 4.237)) == '2.37' and '%.2f' % (mb / 500) == '2.68'
      and '2.4 to 2.7 ms' in hand)
ops = 4577 * 2 ** 16 // 16 * 88
check('probe operations = 4577 x 2^16 / 16 threads x 88 = 1,649,770,496', ops == 1649770496)
r_mul, r_bf, r_as = ops / 13.155e6, ops / 15.723e6, ops / 10.355e6
check('product alone 125.4 G/s, butterfly 104.9 G/s, add and sub 159.3 G/s',
      '%.1f' % r_mul == '125.4' and '%.1f' % r_bf == '104.9' and '%.1f' % r_as == '159.3' and '**125.4 G/s**' in hand,
      '%.1f %.1f %.1f' % (r_mul, r_bf, r_as))
head = ops / 19.588e6
check('forward head 19.59 ms (README:131) over the same count = 84.2 G/s', at(AR, 131, '| 19.59 ms |') and '%.1f' % head == '84.2')
ms = [mults / 1e9 / r * 1e3 for r in (r_mul, r_bf, head)]
check('a field hash of the same columns: 123, 147, 183 ms a block',
      ['%.0f' % x for x in ms] == ['123', '147', '183'] and '**125.4 G/s gives 123 ms; 105 G/s 147 ms; 84 G/s 183 ms**' in hand, ms)
lo, hi = (ms[0] - 2.68) * 32 / 1e3, (ms[2] - 2.37) * 32 / 1e3
check('extra over the shipped hash, 32 blocks: +3.8 to +5.8 s a request', '%.1f' % lo == '3.8' and '%.1f' % hi == '5.8'
      and '+3.8 to +5.8 s a request' in hand, '%.2f %.2f' % (lo, hi))
check('share of the 91.46 ms block: 134% to 200%', '%.0f' % (ms[0] / 91.462 * 100) == '134' and '%.0f' % (ms[2] / 91.462 * 100) == '200'
      and '134% to 200%' in hand)
check('tick 67\x27s low end reproduced: 15.41 G / 478 G/s = 32 ms', '%.0f' % (mults / 478e9 * 1e3) == '32')
fw = (ra + rh) * 2 ** 14 * 15
check('forward transform: 5,110 rows, 1,255.8 M butterflies, 14.03 ms = 89.5 G/s',
      '%.1f' % (fw / 1e6) == '1255.8' and '%.1f' % (fw / (6.897 + 7.132) / 1e6) == '89.5' and '**89.5 G/s**' in hand)

print('== MINE ==')
check('the 7 rows are one range sub-plane: census A 2279 + 2*110 + 2 = 2501, H 2514 + 2*43 + 2 = 2602',
      2279 + 2 * 110 + 2 == 2501 and 2514 + 2 * 43 + 2 == 2602)
check('traced: A 2280 + 2*111 + 2 = 2504, H 2516 + 2*44 + 2 = 2606',
      2280 + 2 * 111 + 2 == 2504 and 2516 + 2 * 44 + 2 == 2606)
check('so A differs by 1 data row and 1 site pair (3 rows), H by 1 helper and 1 site pair (4 rows)',
      (2280 - 2279, 111 - 110, 2516 - 2514, 44 - 43) == (1, 1, 2, 1) and 1 + 2 == 3 and 2 + 2 == 4)
check('and the census has one Tab plane fewer on each side than the profile read today (15 against 16, 16 against 17)',
      16 - 15 == 1 and (3 + 13 + 1) - 16 == 1)
c26 = ((ms[0] - 2.68) * 26 / 1e3, (ms[2] - 2.37) * 26 / 1e3)
check('for the 26-layer classifier request the same per-block price is +3.1 to +4.7 s',
      '%.1f' % c26[0] == '3.1' and '%.1f' % c26[1] == '4.7', '%.2f %.2f' % c26)
C67 = text(HERE + '/20261126-claude-tick67-field-hash-wrapper.md')
check('my own remark under tick 67 (94 to 108 ms a block from assumed operation counts) is below the measured-rate figure',
      '94 to 108 ms a block' in C67 and 108 < ms[0])
print('checks: %d, failed: %d' % (n_checks, n_failed))
sys.exit(1 if n_failed else 0)
