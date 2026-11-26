"""Coordinator's cross-check of research tick 67 (queue item 95): which hash makes a wrapper cheap.

Three parts, standard library only, nothing of the tick's script is imported:
  A. the sentences and table rows the handoff quotes from public pages, asserted in the coordinator's own downloads
     (run with the directory of those downloads as the one argument; without it part A is skipped and says so);
  B. the figures the handoff takes from earlier handoffs and from the code, asserted where they stand in this
     repository;
  C. the handoff's derived figures recomputed from the inputs, each asserted against the text of the handoff, and
     three remarks of the coordinator's own (marked MINE).
Run from anywhere: python3 -I <this file> [directory of downloads]. Exit 0 only if every check passes."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__)) + '/'
ROOT = os.path.abspath(HERE + '../../..') + '/'
fails = []
n_checks = 0


def check(name, cond, shown=''):
    global n_checks
    n_checks += 1
    print(('PASS ' if cond else 'FAIL ') + name + ((' | ' + str(shown)) if shown != '' else ''))
    if not cond:
        fails.append(name)


def norm(t):
    return ' '.join(t.split())


# ---------------------------------------------------------------- A. public pages, the coordinator's copies
print('== A. quoted public pages ==')
if len(sys.argv) > 1:
    D = sys.argv[1].rstrip('/') + '/'

    def page(key, name):
        return norm(open(D + key + '/' + name, encoding='utf-8', errors='replace').read())

    c = page('columns', 'columns.rs.txt')
    for s in ('pub inputs: [T; WIDTH],',
              'pub beginning_full_rounds: [FullRound<T, WIDTH, SBOX_DEGREE, SBOX_REGISTERS>; HALF_FULL_ROUNDS],',
              'pub partial_rounds: [PartialRound<T, SBOX_DEGREE, SBOX_REGISTERS>; PARTIAL_ROUNDS],',
              'pub ending_full_rounds: [FullRound<T, WIDTH, SBOX_DEGREE, SBOX_REGISTERS>; HALF_FULL_ROUNDS],',
              'pub sbox: [SBox<T, SBOX_DEGREE, SBOX_REGISTERS>; WIDTH],', 'pub post: [T; WIDTH],',
              'pub sbox: SBox<T, SBOX_DEGREE, SBOX_REGISTERS>,', 'pub post_sbox: T,',
              'pub struct SBox<T, const DEGREE: u64, const REGISTERS: usize>(pub [T; REGISTERS]);'):
        check('column layout holds: ' + s[:60], s in c)
    a = page('air', 'air.rs.txt')
    check('constraints: degree 7 with no register is x^7 directly', '(7, 0) => x.exp_const_u64::<7>(),' in a)
    check('constraints: degree 7 with one register commits x^3 and returns x3^2 * x',
          '(7, 1) => { let committed_x3 = sbox.0[0].into(); builder.assert_eq(committed_x3.dup(), x.cube()); '
          'committed_x3.square() * x.dup() }' in a)
    g = page('p3gold', 'poseidon2.rs.txt')
    check('library 1: 4 + 4 full rounds', 'pub const GOLDILOCKS_POSEIDON2_HALF_FULL_ROUNDS: usize = 4;' in g)
    check('library 1: 22 partial rounds at width 12', 'pub const GOLDILOCKS_POSEIDON2_PARTIAL_ROUNDS_12: usize = 22;' in g)
    h = page('horizen', 'instance.rs.txt')
    check('library 2: width 12, degree 7, 8 full, 22 partial', 'Poseidon2Params::new(12, 7, 8, 22,' in h)
    j = json.load(open(D + 'issue/issue.json', encoding='utf-8'))
    b = norm(j['body'])
    check('issue: number and state', j['number'] == 476 and j['state'] == 'open', j['title'].strip())
    check('issue: the measured row', '| Measured | 682.606583ms | 282.43675ms | 72.933ms | 3.694164167s | ? |' in b)
    check('issue: 2^13 Goldilocks leaves', 'a Merkle tree with 2^13 Goldilocks leaves' in b)
    check('issue: a dev build', 'The times were obtained from a `dev` build, not a `--release` one.' in b)
    check('issue: width 16', 'are configured with a width of 16' in b)
    check('issue: each leaf is one field element', 'each of which is a single element field element' in b)
    cm = ' '.join(norm(x['body']) for x in json.load(open(D + 'issuec/comments.json', encoding='utf-8')))
    check('issue comments: one core', 'they were all run on a single core (with `RAYON_NUM_THREADS=1`)' in cm)
    check('issue comments: the implementation was unoptimised then',
          'currently the Poseidon2 implementation is rather unoptimized' in cm)
    r_k, r_b = 682.606583 / 282.43675, 682.606583 / 72.933
    check('issue: ratios 2.4 and 9 (measured row)', round(r_k, 1) == 2.4 and 9.0 < r_b < 9.5, '%.2f %.2f' % (r_k, r_b))
    print('     MINE: from the estimated row the ratio to Blake3 is %.1f' % (661.0547 / 56.521))
    z = page('zeknox', 'README.md.txt')
    check('GPU library: Poseidon2, 8192 leaves, 8.4 ms with the GPU', 'Poseidon2 | 8192 | 30.9 ms | 8.4 ms | 3.7 X' in z)
    check('GPU library: one NVIDIA L4', 'one NVIDIA L4 GPU' in z)
    w = page('webgpu2', 'README.md.txt')
    check('browser demo: 2^16 leaves 177.2 ms', '| 16 (65536 Leaves) | 3606.4 ms | 177.2 ms |' in w)
    check('browser demo: height 20, 2119.3 ms', '| 20 (1048676 Leaves) | 58219.7 ms | 2119.3 ms |' in w)
    check('browser demo: Chrome on a 2021 M1 Max', 'Benchmark Results on Chrome / 2021 Apple M1 Max (MacBook Pro)' in w)
    m = page('hackmd', 'page.md.txt')
    check('secondary page: heading of the timing table', 'Native speed (Goldilocks prime, t=12)' in m)
    check('secondary page: Monolith-64 210.5 ns', '| **Monolith-64** | **210.5** | **230.4** |' in m)
    check('secondary page: Poseidon2 1291.5 ns (variable-time column)', '| Poseidon2 | 1291.5 | 1617.9 |' in m
          and '| Hash function | Variable-time (ns) | Constant-time (ns) |' in m)
    check('secondary page: Monolith needs lookups in a circuit too',
          'Inside a circuit, the same AndRX operations translate cleanly to small lookup tables.' in m)
else:
    print('SKIPPED: no directory of downloads given')

# ---------------------------------------------------------------- B. earlier handoffs and the code
print('== B. figures taken from this repository ==')


def hand(name):
    return norm(open(HERE + name, encoding='utf-8').read())


t62 = hand('20261126-claude-tick62-wrapper-hash-counts.md')
for s in ('**412,788 to 415,419 compressions**', '**Per block 212,438 to 215,069;**', '**6.99 to 7.08 M at B6a**',
          '| **block** | **208,615** | **203,920** | **412,788 to 415,419** |', 'columns only 194,040',
          '**9 to 41 s (3 to 13 cadences)**', 'A and H columns 198,800 of 212,438 a block, 94%'):
    check('tick 62: ' + s, s in t62)
t55 = hand('20261125-claude-tick55-recursive-wrapper-cost.md')
for s in ('| column products per request | 1,062 M | 53.4 M | 2.6 M |', '**constant tail of 15 to 197 s**',
          '16 cells an extension operation [AUTHORS, estimate, not measured]'):
    check('tick 55: ' + s, s in t55)
t42 = hand('20261122-claude-tick42-device-work-ranked.md')
check('tick 42: the split and the hash share', 'inverse 8.3, forward 14.0, hash 3.4 ms' in t42 and 'hash 3.9 (3.4%)' in t42)
check('tick 58: verifier at B6a', '**1.46 to 2.93 s**' in hand('20261125-claude-tick58-verifier-side-b6a.md'))
t64 = hand('20261126-claude-tick64-sable-scope.md')
check('tick 64: cells and rates', '5,344 committed cells; 0.16 s and 2.4 us at 2^16 compressions' in t64
      and '0.33 s and 1.3 us at 2^18' in t64 and '"30% above the 4,096 of the design estimate"' in t64)
check('tick 21: block GPU', '**91.46 ms at W16R2_8B' in hand('20261119-claude-tick21-commit-split.md'))
P = open(ROOT + 'ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs', encoding='utf-8').read().split('\n')
check('code: salted leaf at pcs.rs:695-701 of the GPU prover tree', P[694] == '/// leaf = blake3(unsalted leaf || salt)'
      and P[695].startswith('pub fn salt_leaf(leaf: &Digest, salt: &[u8; 32]) -> Digest {')
      and P[697].strip() == 'h.update(leaf);' and P[698].strip() == 'h.update(salt);')
H = open(ROOT + 'ops/zkp-mvp/gpu-metal/zkp-core/src/hashtag.rs', encoding='utf-8').read().split('\n')
seg = '\n'.join(H[110:160])
check('code: four keys of 32 bytes, one keyed hasher (hashtag.rs:111-160)',
      all(s in seg for s in ('Rule::Keyed { transcript, .. } => Some(transcript)', 'pub fn column_key(&self) -> Option<&[u8; 32]>',
                             'pub fn leaf_key(&self) -> Option<&[u8; 32]>', 'pub fn node_key(&self) -> Option<&[u8; 32]>',
                             'Some(k) => blake3::Hasher::new_keyed(k),')))
root_pcs = open(ROOT + 'zkp-core/src/pcs.rs', encoding='utf-8').read().split('\n')
print('     note: in the root zkp-core/src/pcs.rs the salted leaf is at line',
      1 + [i for i, l in enumerate(root_pcs) if l.startswith('pub fn salt_leaf(')][0],
      'and there is no hashtag.rs beside it:', not os.path.exists(ROOT + 'zkp-core/src/hashtag.rs'))

# ---------------------------------------------------------------- C. recomputation against the handoff's text
print('== C. derived figures, recomputed ==')
HT = norm(open(HERE + '20261126-claude-tick67-field-hash-wrapper.md', encoding='utf-8').read())


def said(name, value, text):
    check(name + ' = ' + value, text in HT, 'handoff: ' + text)


W, HALF, PART = 12, 4, 22
cols = {r: W + 2 * HALF * W * (r + 1) + PART * (r + 1) for r in (0, 1)}      # inputs + full rounds + partial rounds
said('cells at one register', str(cols[1]), '**248 at R = 1**')
said('cells at no register', str(cols[0]), '**130 at R = 0**')
check('ratio 16.5 to 41.1', '%.1f %.1f' % (4096 / cols[1], 5344 / cols[0]) == '16.5 41.1' and '16.5 to 41.1 times fewer cells' in HT)
RATE = 8
pA, pH, pM = math.ceil(2501 / RATE), math.ceil(2602 / RATE), math.ceil(50 / RATE)
colA, colH, colM = pA + 1 + 15, pH + 1 + 15, pM + 1 + 12
check('permutations a column 313, 326; opened column 329, 342, 20', (pA, pH, colA, colH, colM) == (313, 326, 329, 342, 20)
      and 'is 313 or 326 permutations' in HT and 'A column 329 (BLAKE3 348), H 342 (362), M 20 (20)' in HT)


def b3(nbytes):   # BLAKE3 compressions of one message: 64-byte blocks in 1,024-byte chunks, plus the parents
    chunks = max(1, math.ceil(nbytes / 1024))
    full, rest = divmod(nbytes, 1024)
    return full * 16 + (math.ceil(rest / 64) if rest else 0) + chunks - 1


check('BLAKE3 side of the same columns: 348 and 362, 203,920 in all',
      (b3(2501 * 8) + 16, b3(2602 * 8) + 16) == (348, 362) and 280 * 348 + 280 * 362 + 256 * 20 == 203920)
col_all = 280 * colA + 280 * colH + 256 * colM
vec = 47 * math.ceil(2 * 16664 / RATE) + 2 * math.ceil(2048 / RATE)
said('absorbed vectors', '%d' % vec, 'absorbed vectors 196,314 (208,615)')
today = (col_all + vec + 253, col_all + vec + 2884)
said('block today', '%d to %d' % today, '389,567 to 392,198 permutations')
tower = 4140 + 2520 + math.ceil(2048 / RATE) + 786          # the handoff's tower terms, taken as given
b6a = col_all + tower
said('B6a block', '%d' % b6a, 'B6a block 200,702')
join = 33 * 280 * (math.ceil(38 / RATE) + 1 + 15) + 10000
req = 32 * b6a + join
said('B6a request', '%.2f M' % (req / 1e6), 'request at B6a 6.63 M')
check('5 to 7% fewer than compressions', 0.05 < 1 - req / 6.99e6 < 0.07 and 0.05 < 1 - req / 7.08e6 < 0.07,
      '%.1f%% %.1f%%' % (100 * (1 - req / 6.99e6), 100 * (1 - req / 7.08e6)))
ext = 53.4e6 * 16
hc1, hc0 = req * cols[1], req * cols[0]
said('hash cells', '%.2f G and %.2f G, products %.2f G' % (hc1 / 1e9, hc0 / 1e9, ext / 1e9), 'hash cells 1.64 G (R = 1) or 0.86 G (R = 0)')
said('total cells', '%.2f to %.2f G' % ((hc0 + ext) / 1e9, (hc1 + ext) / 1e9), 'Total 1.72 to 2.50 G cells')
OURS, S_FAST, S_SLOW = 1.094e-9, 1.3e-6 / 5344, 2.4e-6 / 5344
said('seconds at this prover rate', '%.1f to %.1f s' % ((hc0 + ext) * OURS, (hc1 + ext) * OURS), '**1.9 to 2.7 s**')
check('per-cell rates 0.24 to 0.45 ns', '%.2f %.2f' % (S_FAST * 1e9, S_SLOW * 1e9) == '0.24 0.45')
said('seconds at the other system fastest rate alone (the handoff writes 0.7 for the upper end)',
     '%.2f to %.2f s' % ((hc0 + ext) * S_FAST, (hc1 + ext) * S_FAST), '0.4 to 0.7 s')
both = ((hc0 + ext) * S_FAST, (hc1 + ext) * S_SLOW)
print('     MINE: over both of that system rates, as the handoff words it (0.24 to 0.45 ns): %.1f to %.1f s' % both)
check('MINE: over both rates the range is 0.4 to 1.1 s, inside 0.4 to 2.7 s', '%.1f %.1f' % both == '0.4 1.1')
words = (2501 + 2602) * 2 ** 15
perms = words / RATE
muls = (2 * HALF * W + PART) * 4 + PART * W
said('encoded words and permutations a block', '%.1f M, %.1f M' % (words / 1e6, perms / 1e6), '167.2 M words (1.34 GB), 20.9 M permutations a block')
said('multiplications a permutation', str(muls), 'about 736 a permutation')
tot = perms * muls
said('multiplications a block', '%.1f G' % (tot / 1e9), '15.4 G a block')
bf = (2501 + 2602) * 2 ** 14 * 15
r_ntt, r_top = bf / 14.0e-3, 80 * 128 * 1.4e9 / 30
said('rate bounds', '%.1f and %.0f G/s' % (r_ntt / 1e9, r_top / 1e9), '**89.6 G/s**')
check('the assumed ceiling is 478 G/s', round(r_top / 1e9) == 478 and 'ASSUMED hardware ceiling of 478 G/s' in HT)
t_slow, t_fast = tot / r_ntt * 1e3, tot / r_top * 1e3
check('32 and 172 ms a block', (round(t_fast), round(t_slow)) == (32, 172) and '**172 ms** a block' in HT and '**32 ms**' in HT,
      '%.1f %.1f' % (t_fast, t_slow))
check('8 to 50 times slower', 8 < t_fast / 3.9 < 9 and 50 < t_slow / 3.4 < 51, '%.1f %.1f' % (t_fast / 3.9, t_slow / 3.4))
said('extra a block', '+%.0f to +%.0f ms' % (t_fast - 3.9, t_slow - 3.9), '**+28 to +168 ms a block')
said('share of block GPU', '+%.0f%% to +%.0f%%' % ((t_fast - 3.65) / 91.46 * 100, (t_slow - 3.65) / 91.46 * 100), '+31% to +184% of block GPU 91.46 ms')
said('extra a request', '+%.1f to +%.1f s' % ((t_fast - 3.65) * 32 / 1e3, (t_slow - 3.65) * 32 / 1e3), '+0.9 to +5.4 s a request**')
u16, u20 = 177.2e-3 / (2 * 2 ** 16) * 1e6, 2119.3e-3 / (2 * 2 ** 20) * 1e6
check('browser demo per permutation 1.0 to 1.35 us, 21 to 28 s a block',
      '%.2f %.2f' % (u20, u16) == '1.01 1.35' and round(perms * 1.0e-6) == 21 and round(perms * 1.35e-6) == 28
      and '1.0 to 1.35 us a permutation, 21 to 28 s a block' in HT)
said('verifier hashing on one thread', '%.1f s' % (req * 1291.5e-9), '**8.6 s on one thread**')
check('four field words are 255.99 bits', 255.99 < 4 * math.log2(2 ** 64 - 2 ** 32 + 1) < 256 and '255.99 bits' in HT)

print('== MINE: three remarks, not in the handoff ==')
like = (4096 / cols[1], 5344 / cols[1])
lo3, hi3 = (hc1 + ext) * S_FAST, (hc1 + ext) * OURS
print('  1. like for like (constraint degree 3 on both sides): %.1f to %.1f times fewer cells a step; layer 1 %.1f to %.1f s'
      % (like[0], like[1], lo3, hi3))
check('MINE 1: degree-3 range is 0.6 to 2.7 s', '%.1f %.1f' % (lo3, hi3) == '0.6 2.7')
leaf_b3 = 280 * (b3(2501 * 8) + b3(2602 * 8))
leaf_f = 280 * (pA + pH)
print('  2. share of a B6a block that is the opened columns own words: BLAKE3 %.1f to %.1f%%, field hash %.1f%%; '
      'prover side: %.2f%% of the permutations are column words (the rest is the tree)'
      % (100 * leaf_b3 / 215069, 100 * leaf_b3 / 212438, 100 * leaf_f / b6a, 100 * perms / (perms + 2 * 2 ** 15 * 2)))
check('MINE 2: the columns own words are 88 to 90% of the hashing on the checking side', 0.88 < leaf_b3 / 215069 and leaf_f / b6a < 0.90)
ops_b3 = 7 * 8 * 14 + 16            # 7 rounds of 8 G functions of 14 word operations, 16 closing XORs
ops_p2 = muls * 30                  # the handoff's 30 operations a multiplication; additions left out
k = ops_p2 / ops_b3
print('  3. by operation count at the rate the shipped BLAKE3 kernel already reaches (ASSUMED counts, not measured): '
      '%d against %d word operations a step, %.1f times; %.0f to %.0f ms a block' % (ops_p2, ops_b3, k, 3.4 * k, 3.9 * k))
check('MINE 3: that figure lies inside the 32 to 172 ms range', t_fast < 3.4 * k and 3.9 * k < t_slow)

print('checks: %d, failed: %d' % (n_checks, len(fails)))
sys.exit(1 if fails else 0)
