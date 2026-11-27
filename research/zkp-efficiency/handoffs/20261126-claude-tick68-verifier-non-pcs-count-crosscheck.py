#!/usr/bin/env python3
"""Coordinator's cross-check of research tick 68 (queue item 104): how much of one W16R2_8B diagonal-weight verifier block
is not PCS. Standard library only; reads tracked files of this repository, runs nothing of the prover.

  python3 -I 20261126-claude-tick68-verifier-non-pcs-count-crosscheck.py

Part A: every code line the handoff's counts rest on, asserted in the source (tree ops/zkp-mvp/gpu-metal/).
Part B: every figure the handoff borrows from a retained record or an earlier tick, asserted in that file.
Part C: every derived figure recomputed here and asserted against the handoff's text.
MINE:   the coordinator's own remarks, computed here.
Exit 0 only if every check passes."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..')) + '/'
G = ROOT + 'ops/zkp-mvp/gpu-metal/'
PB = G + 'hashline/src/private_block/'
HB = HERE + '/20261126-claude-tick68-verifier-non-pcs-count'
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


def flat(path):
    return norm(open(path, encoding='utf-8').read())


hand = flat(HB + '.md')


def said(name, text, value=''):
    check('handoff says: ' + name, text in hand, value)


print('== Part A: the code the counts rest on (ops/zkp-mvp/gpu-metal/)')
P, RUN, RF, RFT = PB + 'protocol.rs', PB + 'run.rs', PB + 'run_fork.rs', PB + 'run_fork_tests.rs'
BLK, ARG, ACC, AF = G + 'hashline/src/private_block.rs', PB + 'argument.rs', PB + 'argument_accuracy.rs', PB + 'accuracy_fold.rs'
MLE, SHP = G + 'zkp-core/src/mle.rs', PB + 'shape.rs'
check('the timed line is the D12a serial verifier over a RepeatBlock (run_fork_tests.rs:2673-2675)',
      at(RFT, 2673, 'let tv = Instant::now();') and at(RFT, 2674, 'run::verify_run_with(&st, &mut rep_d12a, &segs)')
      and at(RFT, 2675, 'serial: verified (D12a verifier, one thread)'))
check('verify_run_with = start, then one step a segment, then finish (run.rs:1636-1640)',
      at(RUN, 1636, 'RunVerifier::start(st, blocks)?') and at(RUN, 1638, 'v.step(k, bytes)?') and at(RUN, 1640, 'v.finish()'))
check('check 1 of 2: the start checks every block at its stage shape (run.rs:1424, 1131-1133)',
      at(RUN, 1424, 'blocks.fit_the_stages(st)?;') and at(RUN, 1131, 'for k in 0..st.rs.l')
      and at(RUN, 1133, 'self.block(k)?.check_for_shape(&sh)'))
rb = '\n'.join(lines(RF)[1129:1151])
check('RepeatBlock does not replace fit_the_stages, and its digest is made once (run_fork.rs:1109, 1130-1151)',
      'fn fit_the_stages' not in rb and at(RF, 1109, 'RepeatBlock { blk, l, digest: blk.digest() }')
      and at(RF, 1147, 'digest_is_the_statements(k, &self.digest, want)'))
check('check 2 of 2: verify_core checks the block again (protocol.rs:4325, 4332; called at run.rs:1486)',
      at(P, 4325, 'fn verify_core(') and at(P, 4332, 'blk.check_for_shape(sh)?;') and at(RUN, 1486, 'protocol::verify_core('))
check('the fork verifier has the same two (run_fork.rs:2810, 1184, 1178, 2788)',
      at(RF, 2810, 'preflight(st, blocks, true)?;') and at(RF, 1184, 'protocol::CheckedPublic::check(')
      and at(RF, 1178, 'the verifier always runs the check') and at(RF, 2788, 'protocol::verify_core('))
check('a check at this profile is the accuracy check: both halves, one registry check, one min-scan of nine words '
      '(private_block.rs:952-954, 923-924, 927, 933-935)',
      at(BLK, 954, 'return self.check_accuracy_for_shape(sh);') and at(BLK, 923, 'self.attention.check_for_shape(sh)?;')
      and at(BLK, 924, 'self.feed_forward.check_for_shape(sh)?;') and at(BLK, 927, 'data.check_for_registry(')
      and at(BLK, 935, 'words.par_chunks(1<<20).any(|c|c.contains(&i8::MIN))')
      and norm(lines(BLK)[932] + lines(BLK)[933]).count('&self.') == 9)
nine = sum(1 for i in list(range(635, 640)) + list(range(775, 779)) if 'weights_vanish_off_support(sh, ' in lines(BLK)[i - 1])
check('nine off-support scans a check, on padded lengths (private_block.rs:628, 635-639, 772, 775-778)',
      nine == 9 and at(BLK, 628, '[q * d; 2]') and at(BLK, 772, '[d * f; 2]'), nine)
check('the off-support scan reads only off-support entries (private_block.rs:522-529)',
      at(BLK, 522, 'inner.supported(sh, i).is_err()') and at(BLK, 526, 'row.iter().any(|v| *v != 0)')
      and at(BLK, 528, 'inner_off.iter().any(|&i| row[i] != 0)'))
check('every slot definition re-checks the registry unless a record covers it (argument_accuracy.rs:19-20; argument.rs:2955)',
      at(ACC, 19, 'if !pts.registry_checked {') and at(ACC, 20, 'data.check_for_registry(')
      and at(ARG, 2955, 'accuracy::define_changed(slot,ctx,pts,tr)'))
check('the verifier passes no record, over twenty-three slots (protocol.rs:4363; argument.rs:4031, 4112, 4023, 4145)',
      at(P, 4363, 'argument(&mut side, &ctx, tr, ph)?') and at(ARG, 4031, 'argument_with(side, ctx, tr, ph, None)')
      and at(ARG, 4112, 'pts.registry_checked = checked.is_some_and(') and at(ARG, 4023, 'All twenty-three slots')
      and at(ARG, 4145, 'for slot in 0..sh.n_slots()'))
check('seven weight folds: Q, K, V, O and Gate, Up, Down (argument.rs:3248-3249, 3389-3390)',
      at(ARG, 3248, 'SC_QMM=>Site::Q,SC_KMM=>Site::K,SC_VMM=>Site::V,_=>Site::O') and at(ARG, 3249, 'fold_checked(w,outer,inner,Axis::Rows')
      and at(ARG, 3389, 'SC_GMM=>Site::Gate,SC_UMM=>Site::Up,_=>Site::Down') and at(ARG, 3390, 'fold_checked(w,rows,cols,Axis::Columns'))
check('a verifier fold is the base fold: a min-scan, then the plain loop (accuracy_fold.rs:1149-1150, 1073, 1082-1083, 45-47)',
      at(AF, 1149, 'if !prove_side {') and at(AF, 1150, 'return fold_with_mode(matrix, rows, cols, axis, coefficients, eq, false);')
      and at(AF, 1073, 'if has_i8_min(matrix) {') and at(AF, 1082, 'fold_rows_i8(matrix, rows, cols, &weighted)')
      and at(AF, 1083, 'fold_cols_i8(matrix, rows, cols, &weighted)') and at(AF, 47, 'matrix.par_chunks(1<<20).any(|c|c.contains(&i8::MIN))'))
check('the plain loops visit every entry and skip zeros one by one (zkp-core mle.rs:157-161, 182-186, 268-270, 311-313)',
      at(MLE, 157, 'pub fn fold_rows_i8(') and at(MLE, 161, 'fold_rows_deferred(m, rows, cols, w, 128') and at(MLE, 182, 'pub fn fold_cols_i8(')
      and at(MLE, 186, 'fold_cols_deferred(m, rows, cols, c, 128') and at(MLE, 270, 'if v == 0 { continue; }')
      and at(MLE, 313, 'if v == 0 { continue; }') and at(MLE, 268, 'for (sum, &v) in sums.iter_mut().zip(row)')
      and at(MLE, 311, 'for (&v, cw) in row.iter().zip(c.iter())'))
check('the profile (shape.rs:302): width 4096, hidden 14336, 32 query heads of 128, 8 key heads',
      at(SHP, 302, 'name:"W16R2_8B_T128_H24"') and at(SHP, 302, 'width:4096,hidden:14336,q_heads:32,head_dim:128,kv_heads:8'))

print('== Part B: figures borrowed from retained records and earlier ticks')
VT = flat(ROOT + 'results/zk60_verify_threads_20261125/README.md')
t1, t1d = (9.04 + 8.59) / 2, (12.78 + 13.00) / 2
check('verifier thread set: one thread, sparse loop, 8.815 s a 32-block receipt = 275.5 ms a block; dense 402.8',
      '| t1 | one thread | sparse (default) | 9.04, 8.59 |' in VT and '| t1d | one thread | dense | 12.78, 13.00 |' in VT
      and '8.815 s / 32 = **275.5 ms**' in VT and abs(t1 / 32 * 1e3 - 275.5) < 0.05 and abs(t1d / 32 * 1e3 - 402.8) < 0.05,
      '%.1f %.1f' % (t1 / 32 * 1e3, t1d / 32 * 1e3))
A18 = flat(ROOT + 'results/zk60_effplan_20261105/a18/README.md')
A14 = flat(ROOT + 'results/zk60_effplan_20261105/a14/README.md')
check('A18: same profile and diagonal weights, 32 blocks, six forks; the table is main-line seconds per fork per call and pool CPU-s per call',
      'All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6' in A18 and 'synthetic and diagonal at the 8B geometry' in A18
      and 'main line per fork per call: | bucket | whose file | % of non-GPU | s | pool CPU-s per call |' in A18)
check('A18: registry row 0.017 s main line and 2.15 pool CPU-s; "23 per block, about 3 ms"',
      "registry re-check) | `argument_accuracy.rs` call | 1.5% | 0.017 | 2.15 |" in A18 and '(23 per block, about 3 ms)' in A18)
check('A18: folds-and-tables row 0.121 s and 1.97 pool CPU-s; fold_cols_i8 alone 1.44 CPU-s a call in the pools',
      '| 10.9% | 0.121 | 1.97 |' in A18 and '`fold_cols_i8` (1.44 CPU-s per call in the pools)' in A18)
check('A14: folds-and-tables row 0.120 s and 1.87 pool CPU-s', '| 9.7% | 0.120 | 1.87 |' in A14 and '0.12 s per fork per call, 1.9 CPU-s per call' in A14)
check('A20: the nine padded words are 243,277,824 B',
      "The block's nine padded words are 243,277,824 B" in flat(ROOT + 'results/zk60_effplan_20261105/a20/README.md'))
check('A21: block digest 115.3 ms in one pass on one thread, 5.9 ms by the tree',
      '`BlockPublic::digest` | 115.3 ms (one pass, one thread) | **5.9 ms** (the tree, 1 MiB leaf)' in flat(ROOT + 'results/zk60_effplan_20261105/a21/README.md'))
A26 = flat(ROOT + 'results/zk60_a26_app_20261107/README.md')
check('A26 (the classifier, another profile): a once-only verifier exists and is off pending a reading',
      'Two further cuts are in the binary but OFF' in A26 and '`HL_A26_VERIFY_ONCE=1`' in A26
      and 'each block checked three times per verification' in A26)
T60 = flat(HERE + '/20261125-claude-tick60-verifier-ntt-column-count.md')
T60o = flat(HERE + '/20261125-claude-tick60-verifier-ntt-column-count.out.txt')
check('tick 60: NTT term 75 to 94 ms, derived at rates from other loops; hashing 6.1; absorb 6.1 measured; inner products 3.7 at an assumed 5 ns',
      '75 to 94 ms a block, one thread' in T60 and 'is one thread\'s work at rates from other loops and was not measured by that set' in T60
      and "about 6.1 ms at tick 58's 0.53 ms a MB" in T60 and '(12.53 MB) is 6.1 ms (MEASURED, prover side)' in T60
      and '737,280 Fp2 multiplications, 3.7 ms at 5 ns, ASSUMED rate' in T60)
check('tick 60: 33.20 M dense products, 1.43 M proximity products; its "stays" was 6.1 to 23.9 ms (hashing plus all non-PCS work)',
      '**33.20 M `mul_base` products**' in T60 and 'stay dense: 1.43 M products' in T60
      and 'stays under B6a (hashing + all non-PCS work): 6.1 to 23.9 ms' in T60o)
T58 = flat(HERE + '/20261125-claude-tick58-verifier-side-b6a.md')
check('tick 58: BAT + tower 28.3 ms (rational row, rate 1/8) to 57.2 ms (optimized build, rate 1/2)',
      '**28.3 / 28.5 / 29.3 ms a block, flat over the rate**' in T58 and '(sum 39.4 / 43.4 / 57.2)' in T58)

print('== Part C: the derived figures, recomputed')
d, f, q, kv, hid = 4096, 16384, 32 * 128, 8 * 128, 14336
words = {'wq': q * d, 'wo': q * d, 'wk': kv * d, 'wv': kv * d, 'gamma_a': d, 'gamma_m': d, 'wg_t': d * f, 'wu_t': d * f, 'wd_t': f * d}
total = sum(words.values())
check('padded public bytes a block = 243,277,824', total == 243277824, total)
said('243,277,824 int8 bytes padded', '**243,277,824 int8 bytes padded**')
off = f - hid
vanish = 2 * d * off + off * d
check('off-support entries a check = 25,165,824 (only the hidden axis pads: 2,048 of 16,384)', vanish == 25165824 and off == 2048, vanish)
said('25.2 M off-support entries', '25.2 M off-support entries')
scan = (total / 25e9 * 1e3, total / 8e9 * 1e3)
van = tuple(2 * d * off * a / 1e6 + off * d * b / 1e6 for a, b in ((0.5, 0.05), (1.0, 0.2)))
checks = (2 * (scan[0] + van[0]), 2 * (scan[1] + van[1]))
check('two checks at the assumed rates = 37.1 to 97.7 ms (min-scan 19.5 to 60.8, off-support 17.6 to 36.9)',
      (round(checks[0], 1), round(checks[1], 1), round(2 * scan[0], 1), round(2 * scan[1], 1), round(2 * van[0], 1), round(2 * van[1], 1))
      == (37.1, 97.7, 19.5, 60.8, 17.6, 36.9), '%.1f %.1f' % checks)
said('two checks 37 to 98', 'two checks 37 to 98 (min-scan 20 to 61, vanish 18 to 37)')
reg = (3.0 * 25 / 23, 2.15 / 32 * 1e3 * 25 / 23)
check('25 registry checks = 3.3 to 73.0 ms', (round(reg[0], 1), round(reg[1], 1)) == (3.3, 73.0), '%.1f %.1f' % reg)
said('registry x25 3 to 73', 'registry x25 3 to 73')
loop = (total * 0.25 / 1e6, total * 0.6 / 1e6)
folds = (scan[0] + loop[0], scan[1] + loop[1])
check('seven folds at the assumed rates = 70.6 to 176.4 ms', (round(folds[0], 1), round(folds[1], 1)) == (70.6, 176.4), '%.1f %.1f' % folds)
said('seven folds 71 to 176', 'seven folds 71 to 176')
bf = 12 * 2048
mop = (50 * (bf * 2.11 + 4096 * 1.12) / 1e6 + 0.3, 50 * (bf * 2.67 + 4096 * 1.12) / 1e6 + 1.0)
check('M opening by the handoff\'s formula = 3.1 to 4.5 ms (formula repeated, its inputs not re-read by me)',
      (round(mop[0], 1), round(mop[1], 1)) == (3.1, 4.5), '%.1f %.1f' % mop)
low, high = checks[0] + reg[0] + folds[0] + mop[0], checks[1] + reg[1] + folds[1] + mop[1]
check('bottom-up sum = 114.0 to 351.6 ms', (round(low, 1), round(high, 1)) == (114.0, 351.6), '%.1f %.1f' % (low, high))
said('Sum 114 to 352 ms', '**Sum 114 to 352 ms**')
rate = (402.8 - 275.5) / (33.20e6 - 1.43e6) * 1e6
cols = 1.43e6 * rate / 1e6
check('the measured sparse saving over at most 31.77 M products = at least 4.01 ns a product; proximity products at least 5.7 ms',
      round(rate, 2) == 4.01 and round(cols, 1) == 5.7, '%.2f %.1f' % (rate, cols))
said('at least 4.0 ns a product', '**at least 4.0 ns a product**')
pcs = (75 + 6.1 + 6.1 + 3.7 + cols, 94 + 6.1 + 6.1 + 3.7 + cols)
resid = (275.5 - pcs[1], 275.5 - pcs[0])
check('residual after the counted PCS parts = 159.9 to 178.9 ms', (round(resid[0], 1), round(resid[1], 1)) == (159.9, 178.9), '%.1f %.1f' % resid)
said('Residual: 160 to 179 ms', '**Residual: 160 to 179 ms**')
lo, hi = low, min(high, resid[1])
check('the range = 114.0 to 178.9 ms, 41 to 65% of 275.5, width 64.9: the 15 ms line fails',
      (round(lo, 1), round(hi, 1), round(lo / 275.5 * 100), round(hi / 275.5 * 100)) == (114.0, 178.9, 41, 65) and hi - lo > 15,
      '%.1f %.1f' % (lo, hi))
said('114 to 179 ms (41 to 65%), width 65 ms', '**114 to 179 ms (41 to 65%), width 65 ms**')
said('stays is 120 to 185 ms', 'stays is 120 to 185 ms', '%.1f %.1f' % (lo + 6.1, hi + 6.1))
check('stays = 120.1 to 185.0 ms', (round(lo + 6.1, 1), round(hi + 6.1, 1)) == (120.1, 185.0))
removed = (75 + 6.1 + 3.7 + cols, 94 + 6.1 + 3.7 + cols)
b6a = (275.5 - removed[1] + 28.3, 275.5 - removed[0] + 57.2)
check('one-thread block under B6a = 194 to 242 ms, x1.14 to x1.42 (conditional on tick 60\'s NTT term)',
      (round(b6a[0]), round(b6a[1]), round(275.5 / b6a[1], 2), round(275.5 / b6a[0], 2)) == (194, 242, 1.14, 1.42),
      '%.1f %.1f' % b6a)
said('194 to 242 ms a block', '194 to 242 ms a block')
said('x1.14 to x1.42', '**x1.14 to x1.42**')
one = (checks[0] / 2 + reg[0] / 25, checks[1] / 2 + reg[1] / 25)
r23 = (reg[0] * 23 / 25, reg[1] * 23 / 25)
lever = (one[0] + r23[0], one[1] + r23[1])
check('a once-only verifier would save one check (19 to 52 ms) and 23 registry checks (3 to 67 ms) = 22 to 119 ms a block',
      (round(one[0]), round(one[1]), round(r23[0]), round(r23[1]), round(lever[0]), round(lever[1])) == (19, 52, 3, 67, 22, 119),
      '%.1f %.1f' % lever)
said('(19 to 52 ms) ... (3 to 67 ms): about 22 to 119 ms', 'one of the two checks (19 to 52 ms) and the 23 registry rebuilds (3 to 67 ms): about 22 to 119 ms')
check('that is 0.7 to 3.8 s a 32-block request on one thread, 0.1 to 0.6 s at an ideal six-fold',
      (round(lever[0] * 32 / 1e3, 1), round(lever[1] * 32 / 1e3, 1), round(lever[0] * 32 / 6e3, 1), round(lever[1] * 32 / 6e3, 1)) == (0.7, 3.8, 0.1, 0.6))
said('0.7 to 3.8 s a 32-block request one thread, 0.1 to 0.6 s', '0.7 to 3.8 s a 32-block request one thread, 0.1 to 0.6 s')
dig = (total / 1e6 * 0.474, total / 1e6 * 0.53)
check('block digest in one pass = 115.3 to 128.9 ms; 115.3 / 243.28 MB = 0.474 ms a MB',
      (round(dig[0], 1), round(dig[1], 1)) == (115.3, 128.9) and round(115.3 / (total / 1e6), 3) == 0.474, '%.1f %.1f' % dig)

print('== MINE: the coordinator\'s remarks')
fold_entries = total - 2 * d
check('MINE 1: the seven folds together visit 243,269,632 entries a pass (the two gain vectors are not folded); the queue line\'s '
      '"243.3 M entries each" should read "together"', fold_entries == 243269632, fold_entries)
mb = (2 * total + 2 * fold_entries + 2 * vanish) / 1e6
check('MINE 2: bytes read a block by the scans = 1,023 MB (two min-scans, the folds\' min-scan and loop, two off-support scans)',
      round(mb) == 1023, '%.1f' % mb)
said('about 1,024 MB', 'about 1,024 MB')
a18_main, a18_pool, a14_main, a14_pool = 0.121 * 6 / 32 * 1e3, 1.97 / 32 * 1e3, 0.120 * 6 / 32 * 1e3, 1.87 / 32 * 1e3
check('MINE 3: a sampled anchor on the same loops, profile and test weights (prover side, six forks): folds and public tables cost '
      '22.5 to 22.7 ms of main line plus 58.4 to 61.6 ms of pool CPU a block, 81 to 84 ms together',
      (round(a14_main, 1), round(a18_main, 1), round(a14_pool, 1), round(a18_pool, 1), round(a14_main + a14_pool), round(a18_main + a18_pool))
      == (22.5, 22.7, 58.4, 61.6, 81, 84), '%.1f %.1f' % (a14_main + a14_pool, a18_main + a18_pool))
ffn = 3 * d * f
check('MINE 4: fold_cols_i8 alone, 1.44 pool CPU-s a call = 45.0 ms a block over 201,326,592 entries = 0.224 ns an entry, '
      'at the low edge of the assumed 0.25 to 0.6 ns',
      round(1.44 / 32 * 1e3, 1) == 45.0 and ffn == 201326592 and round(1.44e9 / 32 / ffn, 3) == 0.224, '%.3f' % (1.44e9 / 32 / ffn))
check('MINE 5: tick 60 allowed at most 17.8 ms for all non-PCS work (23.9 less 6.1 of hashing); the sampled 45 ms for three folds '
      'alone is 2.5 times that', round(23.9 - 6.1, 1) == 17.8 and round(45.0 / 17.8, 1) == 2.5)
check('MINE 6: "low by a factor of 5 to 7" compares with tick 60\'s upper end only: 120.1 / 23.9 = 5.0 and 185.0 / 23.9 = 7.7',
      (round((lo + 6.1) / 23.9, 1), round((hi + 6.1) / 23.9, 1)) == (5.0, 7.7))
said('low by a factor of 5 to 7', 'low by a factor of 5 to 7')
check('MINE 7: registry main line 0.017 s per fork per call = 3.2 ms a block, which is the record\'s "about 3 ms"; the 67 ms is '
      'sampled pool CPU of six forks and is an upper figure only',
      round(0.017 * 6 / 32 * 1e3, 1) == 3.2 and round(2.15 / 32 * 1e3) == 67)
check('MINE 8: the timed line also covers the run\'s start and finish (run.rs:1431 builds the NTT tables; 1640 finish), '
      'which the handoff does not list; they sit in the residual',
      at(RUN, 1431, 'NttTables::new(st.rs.ntt_log())') and at(RUN, 1640, 'v.finish()'))
check('MINE 9: the set\'s own note called the weight folds "nearly free" on diagonal weights; the code and the sampled profile say '
      'the products are, the scan is not', 'where the public weight folds are nearly free' in VT)
print('checks: %d, failed: %d' % (n_checks, n_failed))
sys.exit(1 if n_failed else 0)
