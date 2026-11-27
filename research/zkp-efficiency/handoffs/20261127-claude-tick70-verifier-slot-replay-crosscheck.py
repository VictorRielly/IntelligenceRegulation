#!/usr/bin/env python3
"""Coordinator's cross-check of research tick 70 (queue item 111): the public tables a W16R2_8B verifier block builds
and evaluates in its slot replay. Standard library only; reads tracked files of this repository, runs nothing of the
prover.

  python3 -I 20261127-claude-tick70-verifier-slot-replay-crosscheck.py

Part A: code lines the handoff's counts rest on, asserted in the source (tree ops/zkp-mvp/gpu-metal/).
Part B: every figure borrowed from a retained record or an earlier tick, asserted in that file.
Part C: the derived figures recomputed here.
MINE:   what the coordinator adds: whether the proposed test prints, and two measured records of this machine that
        the handoff did not use.
Exit 0 only if every check passes."""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..')) + '/'
G = ROOT + 'ops/zkp-mvp/gpu-metal/'
P = G + 'hashline/src/private_block/'
HB = HERE + '/20261127-claude-tick70-verifier-slot-replay'
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
        _cache[path] = open(path, encoding='utf-8', errors='replace').read().split('\n')
    return _cache[path]


def at(path, n, sub):
    """line n (1-based) of path contains sub"""
    return sub in lines(path)[n - 1]


def text(path):
    return norm('\n'.join(lines(path)))


hand = text(HB + '.md')
out70 = text(HB + '.out.txt')

print('== Part A: the code ==')
AR = P + 'argument.rs'
AA = P + 'argument_accuracy.rs'
check('the verifier refuses the prover\'s compact table descriptors (argument.rs:1861-1862)',
      at(AR, 1861, 'if matches!(side, Side::Verify { .. }) && !def.pub_gens.is_empty() {')
      and at(AR, 1862, 'verifier received prover PubGen descriptors'))
check('the descriptors are switched on for the proving side only (argument.rs:4117)',
      at(AR, 4117, 'pts.pub_gen_prove = prove_side && crate::zk::host_fast_on();'))
check('the verifier arm starts at argument.rs:2249 and evaluates the public tables through one split table (2262)',
      at(AR, 2249, 'Side::Verify { slots } => {') and at(AR, 2262, 'a26_mle_on()') and at(AR, 2262, 'crate::mle::SplitEq::new(&rho)'))
check('the split evaluation is on unless HL_A26_MLE=0 (argument.rs:1840-1842)',
      at(AR, 1840, 'fn a26_mle_on() -> bool {') and at(AR, 1842, 'HL_A26_MLE') and at(AR, 1842, 'unwrap_or(true)'))
check('without a descriptor the causal mask is a full table (argument.rs:2382-2387)',
      at(AR, 2382, 'fn causal_mask(&mut self, sh: &Shape) -> usize {') and at(AR, 2386, 'self.public(causal_mask_at(sh))'))
check('repeat_vals writes one entry a cube position (argument.rs:2459)',
      at(AR, 2459, 'self.public((0..len).map(|x| k(vals[x % m].into())).collect())'))
check('supp returns nothing for a domain that does not pad (argument.rs:2579-2583)',
      at(AR, 2579, 'fn supp(&mut self, dom: Dom, cube_len: usize) -> Result<Option<usize>, String> {')
      and at(AR, 2581, 'if !sh.carries_pad_rule() || !sh.pads(dom) {') and at(AR, 2582, 'return Ok(None);'))
check('supp of a padded domain: an indicator table, then one entry a cube position (argument.rs:2609-2611)',
      at(AR, 2609, 'let t = super::pad::indicator_table(sh, dom);') and at(AR, 2611, 'self.public((0..cube_len).map(|x| k(t[x / rep])).collect())'))
check('slot 4 takes the causal mask (argument.rs:3162)', at(AR, 3162, 'b.causal_mask(sh);'))
check('slot 14 takes two repeated gain tables (argument_accuracy.rs:468-469)',
      at(AA, 468, 'let ig=b.repeat_vals(cube,&ctx.public.gamma_a[..sh.d_pad]);') and at(AA, 469, 'let igm=b.repeat_vals(cube,&ctx.ff.gamma_m[..sh.d_pad]);'))
check('slot 18 takes the group column and the support of F (argument_accuracy.rs:514-515)',
      at(AA, 514, 'let group=b.group_col(sh,data)?;') and at(AA, 515, 'b.supp(Dom::F,cube)?'))
check('slots 15 and 16 take the two rotation tables (argument_accuracy.rs:544)', at(AA, 544, 'let(ic,is)=b.rope_tables(sh,ctx.public,dom);'))
check('slot 17 takes the causal mask (argument_accuracy.rs:584)', at(AA, 584, 'let im=b.causal_mask(sh);'))
ACT = P + 'accuracy_act.rs'
check('the group column is a full table of the F domain, written for tokens x hidden entries (accuracy_act.rs:36-38)',
      at(ACT, 36, 'let mut out=vec![Fp2::ZERO;sh.size(Dom::F)];') and at(ACT, 37, 'for t in 0..sh.tokens {for j in 0..sh.hidden {'))
MLE = G + 'zkp-core/src/mle.rs'
check('the split evaluation takes one extension product an entry (mle.rs:108-116)',
      at(MLE, 108, 'pub fn eval_ext(&self, v: &[Fp2]) -> Fp2 {') and at(MLE, 114, 'a.add(x.mul(*e))') and at(MLE, 112, 'v.par_chunks(w)'))
FLD = G + 'zkp-core/src/field.rs'
prods = sum(lines(FLD)[i - 1].count('.mul(') for i in range(164, 169))
check('an extension product is five base products (field.rs:163-169)', at(FLD, 163, 'pub fn mul(self, r: Fp2) -> Fp2 {') and prods == 5, prods)
check('the per-slot work mark the verifier records (argument.rs:4207-4209)',
      at(AR, 4207, 'run_slot_with(side, &mut acc, def, tr, Some(&mut fold_cache))?;') and at(AR, 4209, 'ph.slot_work(slot, (1u64 << (main + ext)) * n_tabs);'))

print('== Part B: the records ==')
L8 = ROOT + 'results/zk60_slot18_14_breakdown_20261117/raw/w16r2_8b_armA_prod_batched.log'
build, cube = {}, {}
for l in lines(L8):
    m = re.match(r'PB-SLOTSTEP slot (\d+) \| tables: build.*\|\s+(\d+) \|', l)
    if m and int(m.group(1)) not in build:
        build[int(m.group(1))] = int(m.group(2))
    m = re.match(r'PB-SLOTSTEP slot (\d+) \| claimed sum.*\|\s+(\d+) \|', l)
    if m and int(m.group(1)) not in cube:
        cube[int(m.group(1))] = int(m.group(2))
shape = {s: (build[s] // cube[s], cube[s].bit_length() - 1) for s in (4, 14, 15, 16, 17, 18, 19)}
check('the 8B production log: slots 4, 14 to 19 hold 4, 36, 15, 15, 19, 19, 58 tables on cubes 2^19, 2^19, 2^19, 2^17, 2^19, 2^21, 2^14',
      sorted(build) == list(range(23)) and shape == {4: (4, 19), 14: (36, 19), 15: (15, 19), 16: (15, 17), 17: (19, 19), 18: (19, 21), 19: (58, 14)}, shape)
L125 = ROOT + 'results/zk60_sol_gpu_20260927/attempt-5-dense-ab/a1-cpu.log'


def tables(path):
    """the verifier phase tables of a log: list of (profile, wall, {row label: seconds})"""
    res, cur = [], None
    for l in lines(path):
        m = re.match(r'PB-TIMING verify \[(.*?)\] \d+ phases, wall ([0-9.]+) s', l)
        if m:
            cur = (m.group(1), float(m.group(2)), {})
            res.append(cur)
            continue
        m = re.match(r'PB-TIMING verify \| (.*?)\s*\|[^|]*\|\s*([0-9.]+) \|', l)
        if m and cur is not None and m.group(1) != 'phase':
            cur[2][m.group(1)] = float(m.group(2))
    return res


def slot_sum(rows, which=None):
    return sum(v for k, v in rows.items() if re.match(r'slot \d\d ', k) and (which is None or int(k[5:7]) in which))


t125 = tables(L125)
check('the 125M verifier log of 27 September: one table, wall 0.838 s, slot rows 0.565 s, slots 4 and 14 to 17 0.535 s',
      len(t125) == 1 and t125[0][1] == 0.838 and abs(slot_sum(t125[0][2]) - 0.565) < 5e-4
      and abs(slot_sum(t125[0][2], (4, 14, 15, 16, 17)) - 0.535) < 5e-4, '%.3f' % slot_sum(t125[0][2]))
check('in that log slot 18 reads 0.000 s (no public table of the F domain in that profile\'s slot)',
      [v for k, v in t125[0][2].items() if k.startswith('slot 18 ')] == [0.0])
O68 = text(HERE + '/20261126-claude-tick68-verifier-non-pcs-count.out.txt')
check('tick 68: its bottom-up sum covers checks, registry, folds and the M opening, 114.0 to 351.6 ms',
      'bottom-up non-PCS total (checks + registry + folds + M), one thread: 114.0 to 351.6 ms' in O68)
check('tick 68: capped by the residual, 114.0 to 178.9 ms', 'bottom-up capped by the residual: 114.0 to 178.9 ms' in O68)
check('tick 70\'s output: 8,052,736 public entries a block, replay 71 / 108 / 165 ms',
      'pub entries a block: 8,052,736' in out70 and 'REPLAY total (one thread): 71 / 108 / 165 ms' in out70)

print('== Part C: recomputed ==')
pub = {4: 1, 5: 1, 6: 1, 7: 1, 10: 1, 11: 1, 12: 1, 13: 1, 14: 2, 15: 2, 16: 2, 17: 1, 18: 2, 19: 25}
total = sum(k * cube[s] for s, k in pub.items())
check('public entries a block = 8,052,736 with the handoff\'s table counts; 128.8 MB at 16 bytes', total == 8052736 and round(total * 16 / 1e6, 1) == 128.8, total)
big = 2 * cube[18]
check('slot 18\'s two tables are 4,194,304 entries, %.0f%% of the total' % (100 * big / total), big == 4194304 and round(100 * big / total) == 52)
ev = [total * (5 * f + 0.5) / 1e6 for f in (0.8, 1.12, 1.6)]
check('evaluation at 5 products and an add an entry: 36.2, 49.1, 68.4 ms (rates assumed around one derived rate)',
      [round(x, 1) for x in ev] == [36.2, 49.1, 68.4], [round(x, 1) for x in ev])
check('the two lower ends, 114.0 + 71, exceed the largest residual 178.9 ms (the assumed rates cannot all hold)', 114.0 + 71 > 178.9, 114.0 + 71)

print('== MINE ==')
calls = [i + 1 for i, l in enumerate(lines(AR)) if 'slot_step(' in l]
check('the per-step timer is called four times in argument.rs, all before the verifier arm (lines %s < 2249)' % calls,
      calls == [1933, 2020, 2038, 2195])
RF = P + 'run_fork.rs'
check('the fork verifier starts a phase recorder and hands it to verify_core (run_fork.rs:2787-2788)',
      at(RF, 2787, 'let mut ph = timing::Phases::start();') and at(RF, 2788, 'protocol::verify_core(') and at(RF, 2794, 'Ok(Seen {'))
check('run_fork.rs never prints a phase table (no report call in the file)', not any('.report(' in l for l in lines(RF)))
rep = []
for dp, dn, fn in os.walk(P):
    for f in sorted(fn):
        if f.endswith('.rs'):
            p = os.path.join(dp, f)
            rep += [(os.path.relpath(p, P), i + 1) for i, l in enumerate(lines(p)) if 'ph.report("verify"' in l]
check('a verifier phase table is printed in two places only: protocol.rs:4498 and token_io/classify_run.rs:1014',
      sorted(rep) == [('protocol.rs', 4498), ('token_io/classify_run.rs', 1014)], sorted(rep))
A24 = ROOT + 'results/zk60_a24_app_20261107/baseline_b1_cpu_verify.log'
t24 = tables(A24)
walls = [t[1] for t in t24]
slots = [slot_sum(t[2]) for t in t24]
pubs = [slot_sum(t[2], (4, 14, 15, 16, 17, 18)) for t in t24]
opens = [sum(v for k, v in t[2].items() if k.startswith('verify ')) for t in t24]
check('the app lane\'s verifier log of 7 November: 26 phase tables, one a block, all of the R13 classifier profile',
      len(t24) == 26 and all('shieldstral-3b-t128-r13' in t[0] for t in t24))
mean = lambda v: sum(v) / len(v)
print('     a block, mean (least to most) over the 26 tables: wall %.3f (%.3f to %.3f) s; the 23 slot rows %.3f (%.3f to %.3f) s; '
      'slots 4 and 14 to 18 %.3f (%.3f to %.3f) s; the opening rows %.3f (%.3f to %.3f) s'
      % (mean(walls), min(walls), max(walls), mean(slots), min(slots), max(slots), mean(pubs), min(pubs), max(pubs),
         mean(opens), min(opens), max(opens)))
check('in every one of the 26 tables the slot rows are the largest group: more than the opening rows',
      all(s > o for s, o in zip(slots, opens)))
check('slot rows as a share of the wall: %.0f%% on average (%.0f%% to %.0f%%)'
      % (100 * mean(slots) / mean(walls), 100 * min(s / w for s, w in zip(slots, walls)), 100 * max(s / w for s, w in zip(slots, walls))),
      0.3 < mean(slots) / mean(walls) < 0.8)
sz = [v for k, v in t24[0][2].items() if k.startswith('slot 18 ')]
check('first table: wall 0.340 s, slot 18 0.042 s, slot 14 0.032 s', t24[0][1] == 0.340 and sz == [0.042]
      and [v for k, v in t24[0][2].items() if k.startswith('slot 14 ')] == [0.032])
et = {}
for l in lines(A24)[5:40]:
    m = re.match(r'PB-TIMING verify \| slot (\d\d) .*\|\s*(\d+) elem-terms', l)
    if m:
        et[int(m.group(1))] = int(m.group(2))
mult = {s: et[s] / 2 ** (n + 1) for s, n in {4: 19, 14: 19, 15: 19, 16: 17, 17: 19, 18: 21}.items()}
check('first table: the work marks of slots 4 and 14 to 18 are whole multiples of 2^(n+1) for the 8B cube sizes n = 19, 19, 19, 17, 19, 21 '
      '(4, 64, 27, 27, 28, 29 tables with one extension round): consistent with the same cubes',
      mult == {4: 4, 14: 64, 15: 27, 16: 27, 17: 28, 18: 29}, mult)
A26 = ROOT + 'results/zk60_a26_app_20261107/README.md'
check('the A26 record, sampled verifier CPU of the earlier binary: transform 12%, weight folds 14%, public tables about 10%, block checks 11% (README lines 97-100)',
      at(A26, 97, '| 12% | `NttTables::transform`') and at(A26, 98, '| 11% | `weights_vanish_off_support`')
      and at(A26, 99, '| 14% | `accuracy_fold::fold`') and at(A26, 100, '| ~10% | `argument_with` helpers')
      and at(A26, 100, 'a full eq table per table'))
check('the same record: the split tables are its change 3 (README line 136)', at(A26, 136, 'The slots\' public tables through split eq tables'))

print('checks: %d, failed: %d' % (n_checks, n_failed))
sys.exit(1 if n_failed else 0)
