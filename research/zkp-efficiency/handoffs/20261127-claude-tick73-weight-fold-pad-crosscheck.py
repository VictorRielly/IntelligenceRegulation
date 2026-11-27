#!/usr/bin/env python3
"""Coordinator's cross-check of research tick 73 (queue item 115: the pad in the verifier's seven weight folds).

Standard library only. Reads source files, two record files and one raw log of the repository; runs nothing.
usage: python3 -I <this file> [path of a copy of the pinned checker binary]

What it does that the tick's script does not: it takes the shapes from the source instead of typing them, tests every
cited line, reads the per-matrix rows of the one-thread run of 27 November (the tick used their sum only), and asks
whether those rows separate the cost of a pad entry from the cost of a live one.
"""
import hashlib
import os
import re
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
G = 'ops/zkp-mvp/gpu-metal/'
N = [0, 0]


def check(ok, text):
    N[0] += 1
    if not ok:
        N[1] += 1
    print(('ok   ' if ok else 'FAIL ') + text)


def lines(rel):
    return open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace').read().split('\n')


def at(rel, n, needle, short=None):
    ok = needle in lines(rel)[n - 1]
    check(ok, '%s:%d contains %r' % (short or rel.split('/')[-1], n, needle))


# ---- 1. shapes, from the source -------------------------------------------------------------------------------
SH = G + 'hashline/src/private_block/shape.rs'
sl = lines(SH)
m8 = re.search(r'Shape::build\(name, p, tokens, (\d+), (\d+), (\d+), (\d+), (\d+),', sl[704])
ms = re.search(r'Shape::build\(name, p, tokens, (\d+), (\d+), (\d+), (\d+), (\d+),', sl[709])
check(bool(m8) and bool(ms), 'shape.rs:705 and :710 are the two Shape::build lines (8B and Shieldstral closures)')
B8 = tuple(int(x) for x in m8.groups())
BS = tuple(int(x) for x in ms.groups())
check(B8 == (4096, 14336, 32, 128, 8), 'shape.rs:705 gives width 4096, hidden 14336, 32 heads of 128, 8 key-value heads')
check(BS == (3072, 9216, 32, 128, 8), 'shape.rs:710 gives width 3072, hidden 9216, 32 heads of 128, 8 key-value heads')
at(SH, 745, 'SHIELDSTRAL_T128_TRAINED_PROFILE => ss(')
at(SH, 301, 'name:"W16R2_SHIELD_T128_H24",legacy:SHIELDSTRAL_T128_TRAINED_PROFILE,stack:super::accuracy_precision::Stack::LowH24')
at(SH, 302, 'name:"W16R2_8B_T128_H24",legacy:LLAMA3_8B_T128_TRAINED_PROFILE,stack:super::accuracy_precision::Stack::LowH24')
at(SH, 699, 'Shape::build(s.name,s.profile,s.tokens,s.width,s.hidden,s.q_heads,s.head_dim,s.kv_heads,')
qp = [i + 1 for i, l in enumerate(sl) if l.strip() == 'pub(crate) fn q_pad(&self) -> usize {']
check(len(qp) == 1 and 'self.h_pad * self.head_dim' in sl[qp[0]], 'shape.rs: q_pad is h_pad * head_dim (line %d)' % (qp[0] + 1))
th = [i + 1 for i, l in enumerate(sl) if 'pub(crate) fn slot_is_true_head' in l]
check(len(th) == 1 and 'sl % self.slots_per_kv_group() < self.q_heads / self.kv_heads' in sl[th[0]],
      'shape.rs: a head slot is a true head when its index in its key-value group is below q_heads / kv_heads (line %d)' % (th[0] + 1))


def p2(n):
    return 1 << (n - 1).bit_length()


def slots(shape):
    d, f, qh, hd, kvh = shape
    dp, fp, q, kvw = p2(d), p2(f), p2(qh) * hd, kvh * hd
    live_q = qh * hd
    # slot: (matrix, loop form, rows, cols, live rows, live cols)
    return {5: ('Wq', 'rows', q, dp, live_q, d), 6: ('Wk', 'rows', kvw, dp, kvw, d), 7: ('Wv', 'rows', kvw, dp, kvw, d),
            10: ('Wo', 'rows', dp, q, d, live_q), 11: ('Wg', 'cols', dp, fp, d, f), 12: ('Wu', 'cols', dp, fp, d, f),
            13: ('Wd', 'cols', fp, dp, f, d)}


TOT = {}
for name, shape in (('installed', BS), ('8B', B8)):
    S = slots(shape)
    padded = sum(v[2] * v[3] for v in S.values())
    live = sum(v[4] * v[5] for v in S.values())
    TOT[name] = (padded, live, padded - live, S)
check(TOT['installed'][0] == 243269632 and TOT['8B'][0] == 243269632, 'both profiles fold 243,269,632 padded entries a block')
check(TOT['installed'][2] == 126877696, 'installed profile: 126,877,696 pad entries (%.1f%%)' % (100 * TOT['installed'][2] / TOT['installed'][0]))
check(TOT['8B'][2] == 25165824, '8B profile: 25,165,824 pad entries (%.1f%%)' % (100 * TOT['8B'][2] / TOT['8B'][0]))
SI = TOT['installed'][3]
ffn_pad = sum(SI[s][2] * SI[s][3] - SI[s][4] * SI[s][5] for s in (11, 12, 13))
check(ffn_pad == 3 * 38797312, 'installed profile: the three feed-forward matrices hold %.1f%% of the pad' % (100 * ffn_pad / TOT['installed'][2]))
check(BS[2] == p2(BS[2]) and BS[2] // BS[4] == 4, 'at 32 heads over 8 key-value heads the padded head axis has 32 slots, four a group, all true heads: Wq and Wo have no head pad')
check(3072 % 256 == 0, 'the live width 3072 is twelve whole chunks of 256 columns: in the row form the pad of Wq, Wk, Wv is four whole chunks of sixteen')

# ---- 2. the verifier's path, line by line -----------------------------------------------------------------------
AR = G + 'hashline/src/private_block/argument.rs'
AF = G + 'hashline/src/private_block/accuracy_fold.rs'
ML = G + 'zkp-core/src/mle.rs'
PB = G + 'hashline/src/private_block.rs'
at(AR, 3231, 'SC_QMM => (ids.at(A_Y), ctx.public.wq.as_slice(), sh.q_pad(), sh.d_pad),')
at(AR, 3232, 'SC_KMM => (ids.at(A_Y), ctx.public.wk.as_slice(), kvw, sh.d_pad),')
at(AR, 3234, '_ => (ids.at(A_O8), ctx.public.wo.as_slice(), sh.d_pad, sh.q_pad()),')
at(AR, 3249, 'fold_checked(w,outer,inner,Axis::Rows,&coefficients(sh,data,site)?,&weights,pts.weights_checked,pts.prove_side)?')
at(AR, 3375, 'SC_GMM => (ids.at(A_YM), ctx.ff.wg_t.as_slice(), sh.d_pad, sh.f_pad),')
at(AR, 3377, '_ => (ids.at(A_H16), ctx.ff.wd_t.as_slice(), sh.f_pad, sh.d_pad),')
at(AR, 3390, 'fold_checked(w,rows,cols,Axis::Columns,&coefficients(sh,data,site)?,&weights,pts.weights_checked,pts.prove_side)?')
at(AR, 4110, 'let prove_side = matches!(side, Side::Prove { .. });')
at(AF, 1149, 'if !prove_side {')
at(AF, 1150, 'return fold_with_mode(matrix, rows, cols, axis, coefficients, eq, false);')
at(AF, 47, 'matrix.par_chunks(1<<20).any(|c|c.contains(&i8::MIN))')
at(AF, 1073, 'if has_i8_min(matrix) {')
at(AF, 1082, 'Axis::Rows => fold_rows_i8(matrix, rows, cols, &weighted),')
at(AF, 1083, 'Axis::Columns => fold_cols_i8(matrix, rows, cols, &weighted),')
at(ML, 160, 'if deferred_rows() {')
at(ML, 185, 'if deferred_cols() {')
at(ML, 231, 'std::env::var("HL_FSP_ROW_FOLD").map(|v| v != "0").unwrap_or(true)')
at(ML, 286, 'std::env::var("HL_FSP_COL_FOLD").map(|v| v != "0").unwrap_or(true)')
at(ML, 270, 'if v == 0 { continue; }')
at(ML, 313, 'if v == 0 { continue; }')
ml = lines(ML)
check(not any('is_zero' in l for l in ml[244:319]), 'mle.rs:245-319 (both deferred folds): no test of a zero weight, only of a zero matrix value')
check('for (i, &wi) in w.iter().enumerate() {' in ml[265] and 'let chunk = 256usize.min(cols);' in ml[259],
      'mle.rs:260, 266: the row form walks every row for each chunk of 256 columns')
at(PB, 510, 'fn weights_vanish_off_support(sh: &shape::Shape, w: &[i8], outer: Axis, inner: Axis) -> Result<(), String> {')
for n, needle in ((635, 'weights_vanish_off_support(sh, wq, Axis::Q, Axis::D)?;'), (636, 'weights_vanish_off_support(sh, wk, Axis::Full(kv), Axis::D)?;'),
                  (637, 'weights_vanish_off_support(sh, wv, Axis::Full(kv), Axis::D)?;'), (638, 'weights_vanish_off_support(sh, wo, Axis::D, Axis::Q)?;'),
                  (776, 'weights_vanish_off_support(sh, wg_t, Axis::D, Axis::F)?;'), (777, 'weights_vanish_off_support(sh, wu_t, Axis::D, Axis::F)?;'),
                  (778, 'weights_vanish_off_support(sh, wd_t, Axis::F, Axis::D)?;')):
    at(PB, n, needle)
at(PB, 485, 'Axis::D => i < sh.width,')
at(PB, 486, 'Axis::Q => sh.slot_is_true_head(i / sh.head_dim),')
at(PB, 487, 'Axis::F => i < sh.hidden,')
at(PB, 526, 'row.iter().any(|v| *v != 0)')
at(PB, 528, 'inner_off.iter().any(|&i| row[i] != 0)')
pl = lines(PB)
cw = [i + 1 for i, l in enumerate(pl) if 'Self::check_words(' in l]
check(cw == [602, 661, 759, 797], 'private_block.rs: the word check is called at four lines, two in the constructors and two in check_for_shape (%s)' % cw)
nc = 0
for dp, dn, fn in os.walk(os.path.join(ROOT, G, 'hashline/src')):
    for f in fn:
        if f.endswith('.rs'):
            nc += sum(1 for l in open(os.path.join(dp, f), encoding='utf-8', errors='replace') if '.check_for_shape(' in l)
print('     note: check_for_shape is called at %d lines of the prover source; which of them the installed checker passes through was not traced' % nc)

# ---- 3. Lean -----------------------------------------------------------------------------------------------------
at('formal/ZK60Formal/BlockR13HostBase.lean', 664, 'structure PubR')
at('formal/ZK60Formal/BlockR13HostBase.lean', 673, 'wq : ')
at('formal/ZK60Formal/BlockR13HostBase.lean', 700, 'wd : ')
at('formal/ZK60Formal/LayoutW16.lean', 225, 'the padded entries zero.')

# ---- 4. the measurement, and its per-matrix rows -----------------------------------------------------------------
RD = 'results/zk60_verify_1t_installed_20261127/'
rt = '\n'.join(lines(RD + 'reading_t1a.txt'))
for needle in ('F: slots 5 to 7, 10 to 13 (weight folds)            139.5', 'T: setup + 23 slots + M + A + H                     338.9',
               'wall of a table                                     740.0', 'F as ns a padded weight entry (243269632 entries a block): 0.573',
               'the other seven slots                                 1.6'):
    check(needle in rt, 'reading_t1a.txt has %r' % ' '.join(needle.split()))
tables, cur = [], None
for l in lines(RD + 'raw/t1a.log'):
    if l.startswith('PB-TIMING verify [') and 'phases, wall' in l:
        cur = {}
        tables.append(cur)
    elif cur is not None and l.startswith('PB-TIMING verify | slot '):
        c = [x.strip() for x in l.split('|')]
        cur[int(c[1].split()[1])] = float(c[8]) * int(c[5].split()[0]) / 1e6  # ms: ns a unit times units
FOLD = (5, 6, 7, 10, 11, 12, 13)
check(len(tables) == 26 and all(sorted(t) == list(range(23)) for t in tables), 'raw/t1a.log: 26 tables of 23 slot rows')
med_sum = statistics.median(sum(t[s] for s in FOLD) for t in tables)
check(abs(med_sum - 139.5) < 0.05, 'the median over the tables of the seven rows together is %.1f ms' % med_sum)
print('     per matrix [MEASURED, one run, one thread, the pinned binary, real weights]: median row over 26 tables')
print('     %4s %-3s %-5s %12s %7s %8s %12s' % ('slot', '', 'form', 'padded', 'pad %', 'ms', 'ns a padded entry'))
avg, ceil_slot = {}, 0.0
for s in FOLD:
    nm, form, r, c, lr, lc = SI[s]
    ms_ = statistics.median(t[s] for t in tables)
    avg[s] = ms_ * 1e6 / (r * c)
    pad = r * c - lr * lc
    ceil_slot += pad * avg[s] / 1e6
    print('     %4d %-3s %-5s %12s %7.1f %8.2f %12.3f' % (s, nm, form, format(r * c, ','), 100 * pad / (r * c), ms_, avg[s]))
sum_med = sum(statistics.median(t[s] for t in tables) for s in FOLD)
print('     sum of the seven medians %.1f ms' % sum_med)
rows_avg = sum(statistics.median(t[s] for t in tables) for s in (5, 6, 7, 10)) * 1e6 / sum(SI[s][2] * SI[s][3] for s in (5, 6, 7, 10))
cols_avg = sum(statistics.median(t[s] for t in tables) for s in (11, 12, 13)) * 1e6 / sum(SI[s][2] * SI[s][3] for s in (11, 12, 13))
check(rows_avg > cols_avg, 'the four row-form matrices (25.0%% pad) cost %.3f ns a padded entry, the three column-form ones (57.8%% pad) %.3f' % (rows_avg, cols_avg))
PADI = TOT['installed'][2]
pooled = PADI * 139.5 / 243269632
check(abs(pooled - 72.8) < 0.05, 'the handoff\x27s ceiling: pad entries at the pooled average rate, %.1f ms a block' % pooled)
print('     the same ceiling taken matrix by matrix (a pad entry costs no more than the average entry of its own matrix): %.1f ms a block' % ceil_slot)
for lab, z, want in (('low', 0.22 + 1 / 25.0, 33.0), ('mid', (0.22 + 0.40) / 2 + (1 / 25.0 + 1 / 8.0) / 2, 49.8), ('high', 0.40 + 1 / 8.0, 66.6)):
    check(abs(PADI * z / 1e6 - want) < 0.05, 'the handoff\x27s %s figure: %.4f ns a pad entry gives %.1f ms a block' % (lab, z, PADI * z / 1e6))

# ---- 5. do the per-matrix rows separate a pad entry from a live one? ---------------------------------------------
# a = 0.25 z + 0.75 l_rows ; b = pr z + (1 - pr) l_cols, with l_cols = l_rows - delta
a, b, pr = rows_avg, cols_avg, ffn_pad / (3 * 67108864)
print('     two equations, three unknowns (cost z of a pad entry, cost of a live entry in each loop form):')
zs = []
for delta in (0.0, 0.1, 0.2, 0.3):
    z = (b + (1 - pr) * delta - (1 - pr) * a / 0.75) / (pr - (1 - pr) * 0.25 / 0.75)
    l_rows = (a - 0.25 * z) / 0.75
    zs.append(z)
    print('       live entry of the column form %.1f ns cheaper than of the row form: z = %.2f ns, live %.2f and %.2f ns, saving %.0f ms a block'
          % (delta, z, l_rows, l_rows - delta, PADI * z / 1e6))
check(zs[0] < 0.26 and zs[-1] > 0.50, 'NOT IDENTIFIED: a difference of 0 to 0.3 ns between the two loop forms moves z from %.2f to %.2f ns, across the whole of the handoff\x27s band (0.26 to 0.53)' % (zs[0], zs[-1]))

# ---- 6. the anchor ------------------------------------------------------------------------------------------------
t68 = lines('research/zkp-efficiency/handoffs/20261126-claude-tick68-verifier-non-pcs-count.md')
hit = [i + 1 for i, l in enumerate(t68) if '0.224 ns an' in l]
ctx = ' '.join(t68[hit[0] - 2:hit[0] + 3]) if hit else ''
check(len(hit) == 1 and 'prover side, six forks' in ctx and '45 ms of pool CPU a block' in ctx and 'Sampled pool time' in ctx and 'indications, not one-thread timings' in ctx,
      'tick 68, line %s: the 0.224 ns is 45 ms of sampled pool CPU a block, prover side, six forks; the text calls it an indication, not a one-thread timing' % hit)
check(abs(45e6 / (3 * 67108864) - 0.2235) < 0.0005, '45 ms over the 201,326,592 entries of the three feed-forward matrices is 0.2235 ns')
at(AF, 1152, 'if crate::zk::host_fast_w2_on() {')
print('     note: on the prover side fold_checked can take other loops (accuracy_fold.rs:1152-1155); which loop that profile sampled was not read, so the figure is neither a floor nor a ceiling for the checker\x27s loop')

# ---- 7. the switches in the pinned binary and in the app -----------------------------------------------------------
na = 0
named = []
for dp, dn, fn in os.walk(os.path.join(ROOT, 'apps')):
    dn[:] = [d for d in dn if d not in ('node_modules', '__pycache__')]
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.getsize(p) > 4000000:
            continue
        na += 1
        bb = open(p, 'rb').read()
        if b'HL_FSP_ROW_FOLD' in bb or b'HL_FSP_COL_FOLD' in bb:
            named.append(f)
check(not named, 'no file under apps/ names HL_FSP_ROW_FOLD or HL_FSP_COL_FOLD (%d files read)' % na)
if len(sys.argv) > 1:
    bb = open(sys.argv[1], 'rb').read()
    h = hashlib.sha256(bb).hexdigest()
    dj = open(os.path.join(ROOT, 'apps/proven-media/deploy.json'), encoding='utf-8').read()
    check(dj.count('"binary_sha256": "%s"' % h) == 1, 'the binary copy given (%d bytes) has the SHA-256 that apps/proven-media/deploy.json pins once: %s' % (len(bb), h))
    check(bb.count(b'HL_FSP_ROW_FOLD') == 1 and bb.count(b'HL_FSP_COL_FOLD') == 1, 'that binary holds the names HL_FSP_ROW_FOLD and HL_FSP_COL_FOLD once each: both switches, and so both deferred folds, are compiled in')
else:
    print('     (no binary copy given: the two checks of the pinned binary were not made)')

print('%d checks, %d failed' % (N[0], N[1]))
sys.exit(1 if N[1] else 0)
