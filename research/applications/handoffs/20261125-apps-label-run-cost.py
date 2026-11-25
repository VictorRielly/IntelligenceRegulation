#!/usr/bin/env python3
"""A18 arithmetic. Reads files and prints; writes nothing. Run: python3 <this file>.

Every input is checked against the cited file:line first (a failed check prints CHECK FAILED and the
arithmetic below it should not be trusted). Figures from different timing sets are printed in separate
columns and are not ranked or chained.
"""
R = '/Users/victorrielly/IntelligenceRegulation/'


def line(path, n):
    with open(R + path, encoding='utf-8') as f:
        for i, t in enumerate(f, 1):
            if i == n:
                return t
    return ''


def check(path, n, *needles):
    t = line(path, n)
    ok = all(s in t for s in needles)
    print(('ok   ' if ok else 'CHECK FAILED ') + path.split('/')[-1] + ':' + str(n) + '  ' + ' | '.join(needles))
    return ok


LT = 'results/zk60_lane_threads_20261122/README.md'
PILOT = 'results/zk60_astra_20261026/app_composed_native_20261122/PILOT.md'
ST = 'docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md'
DS = 'results/zk60_token_io_design_20261017/DESIGN.md'

print('== inputs checked against their lines ==')
check(LT, 83, '6 x 5', '47.11')
check(LT, 85, '6 x 8', '48.64')
check(LT, 110, 'X 48.96', 'Y 50.00')
check(PILOT, 15, '669,561,472', '28 segments')
check('apps/proven-media/proven_media/config.py', 72, 'TAU = 0.5')
check('apps/proven-media/proven_media/shieldstral_text.py', 86, 'context_tokens - len(self.prefix) - len(self.suffix)')
check(ST, 204, 'P0 72, chunk 55', 'P0 78, chunk 49', 'S = 1')
check(ST, 476, '118,593,824', '7,161,056')
check(ST, 202, '848,412,096')
check(ST, 201, 'T 128, width 3072', 'hidden 9216', '32 query heads, 8 key-value heads, head_dim 128')
check(DS, 520, '2.769 M')
check(DS, 532, '285.7 M')
check(DS, 721, '2.769 M', '28.3 M')

# ---------------------------------------------------------------- 1. n separate single-category runs
print()
print('== 1. n separate runs, one registered policy each (DERIVED; one 128-position window per run) ==')
RATES = [  # (label, tok/s, source)
    ('set A: 6 lanes x 5 threads, level of 6 legs', 47.11, LT + ':83'),
    ('set B: 6 lanes x 8 threads, level of 6 legs', 48.64, LT + ':85'),
    ('set C: 6x8, default arm X, level of 4 legs', 48.96, LT + ':110'),
    ('set D: 6x8, tail-250 arm Y, level of 4 legs', 50.00, LT + ':110'),
]
WINDOW = 128
RECEIPT = 669_561_472
print('per run: window %d padded positions; receipt %s B (%.3f GB)' % (WINDOW, format(RECEIPT, ','), RECEIPT / 1e9))
for lab, r, src in RATES:
    print('%-46s %6.2f tok/s -> %.3f s of stream capacity per run  [%s]' % (lab, r, WINDOW / r, src))
print()
print('%-4s %-12s' % ('n', 'receipt GB') + ''.join('%-9s' % ('set ' + s) for s in 'ABCD') + '  (seconds of stream capacity, one chunk window per policy)')
for n in (1, 3, 4, 8, 16):
    print('%-4d %-12.3f' % (n, n * RECEIPT / 1e9) + ''.join('%-9.2f' % (n * WINDOW / r) for _, r, _ in RATES))
print('chunks multiply: a post of J chunks per category costs n x J windows (J = 3 to 22 at T128 per %s:63,205).' % ST.split('/')[-1][:40])

# ---------------------------------------------------------------- 2. shared prefix
print()
print('== 2. shared-prefix saving the records support ==')
print('template order is prefix (policy text, starts with BOS id 1) + content chunk + suffix [4] + pad ids to 128')
print('(shieldstral_text.py:76, 114-115). Two policies therefore share only the BOS token; the content follows the policy.')
print('Registered policy lengths P0 = 72 (sexual, violence), 78 (hate); S = 1 [%s:204].' % ST.split('/')[-1][:30])
print('Prefix reuse across runs: no measurement and no accepted construction (kv-proof-state.md:126; deepprove-gap.md:105).')
print('Saving carried into the table above: 0 s (not measured, no mechanism), not an estimate of zero.')

# ---------------------------------------------------------------- 3. window room for a k-token label
print()
print('== 3. room in the 128-position window for a k-token label read in one pass (COUNTED geometry, DERIVED room) ==')
print('item_length = P0 + n_content + S; spare positions = 128 - item_length; a k-token label needs k-1 spare positions')
print('(teacher-forced label tokens; the design of mode (ii), %s:465-470).' % DS.split('/')[-1])
for P0, chunk in ((72, 55), (78, 49)):
    for n in (17, 38, 40, chunk):
        item = P0 + n + 1
        spare = 128 - item
        print('P0 %d, content n %2d: item_length %3d, spare %3d -> largest k = %2d%s' %
              (P0, n, item, spare, spare + 1 if spare >= 0 else 0, '  (full chunk: k = 1 only)' if n == chunk else ''))
print('a k-token label at a full chunk would cut the chunk by k-1 (55 -> 55-(k-1) at P0 72).')

# ---------------------------------------------------------------- 4. label side, count only
print()
print('== 4. one-position choice among n label tokens (DERIVED from shape; no time exists at the installed profile) ==')
d, dq, dkv, hid = 3072, 4096, 1024, 9216
per_pos_block = d * dq + 2 * d * dkv + dq * d + 3 * d * hid
print('block MACs per position, projections and gated MLP only (width %d, q width %d, kv width %d, hidden %d): %s' %
      (d, dq, dkv, hid, format(per_pos_block, ',')))
window_macs = WINDOW * 26 * per_pos_block
print('window, 26 blocks x 128 positions, same terms: %s MACs' % format(window_macs, ','))
for n in (2, 4, 8, 16):
    extra = (n - 1) * d
    print('n=%2d: head comparison = %2d public difference vectors of width %d at one position = %s MACs = %.2e of the window, %.2e of one block position' %
          (n, n - 1, d, format(extra, ','), extra / window_macs, extra / per_pos_block))
print('NOT a proof-time figure: committed planes, lookups and the stage geometry set proof cost, and OUT-C has a fixed geometry.')
print('Record sizes at R13 (older profile; bytes, not time): OUT-C %s B, one block %s B, receipt %s B [%s:476,202]' %
      (format(7_161_056, ','), format(118_593_824, ','), format(848_412_096, ','), ST.split('/')[-1][:30]))
print('OUT-C / one block = %.4f ; OUT-C / receipt = %.4f. No W16R2 per-stage size or time was found in the records read.' %
      (7_161_056 / 118_593_824, 7_161_056 / 848_412_096))
print()
print('Full-vocabulary argmax, the design counts (Llama-3-8B, V = 128,256, d = 4096; NOT the Shieldstral classifier) [%s:520-532, 721]:' % DS.split('/')[-1])
m1, blk32, m128 = 2.769, 28.3, 285.7
print('  mode (i), one output position: %.3f M committed elements = %.3f of a T32 block (%.1f M)' % (m1, m1 / blk32, blk32))
print('  mode (ii) at T128, 128 output positions: %.1f M elements = %.3f M per position (design table, n = 2^15)' % (m128, m128 / 128))
print('  restricting the choice to n registered ids replaces the V-wide planes by n-wide ones; no count of that exists.')

# ---------------------------------------------------------------- 5. public bits
print()
print('== 5. public information per chunk and category (DERIVED) ==')
print('today: 1 verdict bit per policy per chunk, public (%s:103). n separate yes/no policies: n bits.' % ST.split('/')[-1][:30])
import math
for n in (4, 8, 16):
    print('n=%2d: n separate policies publish %2d bits; one n-way choice publishes at most %.0f bits (log2 n)' % (n, n, math.log2(n)))
