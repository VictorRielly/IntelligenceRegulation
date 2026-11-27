#!/usr/bin/env python3
"""Coordinator's cross-check of research tick 72 (why a census shows 2,501 / 2,602 rows and a traced block
2,504 / 2,606). Independent of the researcher's script: every cited source line is asserted from the file, the width
list is transliterated again from range16.rs, and the installed export's own calibration is read (the handoff did
not read it). Reads only. Usage: python3 -I <this file>
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PB = ROOT + '/ops/zkp-mvp/gpu-metal/hashline/src/private_block/'
N = [0, 0]


def check(name, cond, detail=''):
    N[0] += 1
    if not cond:
        N[1] += 1
    print('%s %2d %s%s' % ('ok  ' if cond else 'FAIL', N[0], name, (' | ' + str(detail)) if detail else ''))


def lines(path):
    return open(path, encoding='utf-8', errors='replace').read().split('\n')


def at(L, n, needle):
    return needle in L[n - 1]


# ---- 1. the two fixtures -------------------------------------------------------------------------------------------
T = lines(PB + 'range16_tests.rs')
check('range16_tests.rs:14 the calibration: tn 9 at width >= 3072, sh_ao 7, sh_qkv 8, sh_s 6, sh_o 9, sh_g 8, sh_h 14, sh_z 6',
      at(T, 14, 'tn: if width >= 3072 { 9 } else { 10 }') and at(T, 14, 'sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6'))
check('range16_tests.rs:20 built(): the shape is made with a common gate shift of 20',
      at(T, 20, 'Shape::accuracy_trained(profile, &calibration(spec.width), fe, 20)'))
check('range16_tests.rs:37 case(): groups with e_in -4, -3, -2, -1, the first ng of them',
      at(T, 37, 'Group { e_in: -4, e_out: -13 }, Group { e_in: -3, e_out: -12 }, Group { e_in: -2, e_out: -11 }, Group { e_in: -1, e_out: -9 }][..ng]'))
check('range16_tests.rs:39-40 case(): base member (-3, -11); the shape takes the gate shift of the group data',
      at(T, 39, 'sh.accuracy_base(), (-3, -11)') and at(T, 40, 'sh.with_accuracy_gate_shift(data.folds().gate.shift)'))
S = lines(PB + 'slot_ir_accuracy.rs')
check('slot_ir_accuracy.rs:1814, 1819 the harness test: built at 20, then case(original, 3)',
      at(S, 1814, 'Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20)') and at(S, 1819, 'case(original, 3)'))
W = lines(PB + 'w16r2_tests.rs')
check('w16r2_tests.rs:2694, 2704, 2716 the A8 census test: case(original, 3), then prints the layout rows',
      at(W, 2694, 'fn a8_store_fold_census_and_bench_on_the_8b_block') and at(W, 2704, 'range16_tests::case(original, 3)')
      and at(W, 2716, 'A8-CENSUS {} A rows {} H rows {} n {}'))
G = lines(PB + 'accuracy_groups.rs')
check('accuracy_groups.rs:48, 50 gate shift = max over channels of (base_sh_g + 10 + e_in - base_e_in), at least 17',
      at(G, 48, 'base_sh_g as i64 + 10 + (groups[id].e_in - base_e_in) as i64') and at(G, 50, '.max(17)'))

# ---- 2. widths, families, planes, sites, rows ----------------------------------------------------------------------
R = lines(PB + 'range16.rs')
order = ['rem(24);', 'rem(p.ao);', 'rem(p.down);', 'for bits in [p.q, SH_ROPE, p.pv, p.k, p.v, SH_ROPE] {', 'rem(gate_shift);',
         'rem(p.up);', 'rem(if h24 { 16 } else { 24 });', 'rem(p.score);', 'rem(p.f_p + 1);', 'rem(wrho_s);']
pos = [next(i for i in range(163, 196) if o in R[i]) for o in order]
check('range16.rs:164-195 widths(): starts from 16, the ten rem calls in the order transliterated here, byte width dropped, sorted, de-duplicated',
      at(R, 164, 'pub(crate) fn widths(stack: Stack, p: &Precision, gate_shift: u32, wrho_s: u32)') and at(R, 166, 'vec![16u32]')
      and pos == sorted(pos) and at(R, 172, 'w.push(bits - 16)') and at(R, 192, 'w.retain(|&x| x != 8)') and at(R, 194, 'w.dedup()'), pos)
check('range16.rs:208 families(): sub-planes of a width = max(1, 2^width >> log_cols)',
      at(R, 208, 'sub: ((1usize << width) >> log_cols).max(1)'))
A = lines(PB + 'accuracy_precision.rs')
check('accuracy_precision.rs:73-83, 91 the derived shifts: q +7, k +7, v +8, score +12, pv +3, ao +14, gate +10, up +12, down +6 +8 (LowH24), f_p 12',
      at(A, 73, 'p.q += 7') and at(A, 74, 'p.k += 7') and at(A, 75, 'p.v += 8') and at(A, 76, 'p.score += 12') and at(A, 77, 'p.pv += 3')
      and at(A, 78, 'p.ao += 14') and at(A, 79, 'p.gate += 10') and at(A, 80, 'p.up += 12')
      and at(A, 81, 'if stack == Stack::LowH24 { 8 } else { 0 }') and at(A, 83, 'p.down += 6 + h_extra') and at(A, 91, 'p.f_p = 12'))
H = lines(PB + 'shape.rs')
check('shape.rs:875 range_families(): widths(stack, precision, the shape\x27s gate shift, wrho_s) at the shape\x27s log_cols',
      at(H, 875, 'super::range16::widths(self.accuracy_stack(), &p, self.accuracy_gate_shift, self.wrho_s), self.log_cols'))
check('shape.rs:2482, 2587 Tab planes: 3 + sub-planes in A, 4 + sub-planes in H',
      at(H, 2482, 'vec![Dom::Tab;3+super::range16::sub_planes(&self.range_families()).len()]')
      and at(H, 2587, 'vec![Dom::Tab; 4 + super::range16::sub_planes(&self.range_families()).len()]'))
check('shape.rs:2628-2630 claim sites of the table slot: 3 + sub-planes on each side (so one more sub-plane is one more site in A and in H)',
      at(H, 2628, 'let n_range = super::range16::sub_planes(&self.range_families()).len();') and at(H, 2629, 'a[SC_TAB] = 3 + n_range;')
      and at(H, 2630, 'h[SC_TAB] = 3 + n_range;'))
Y = lines(PB + 'layout.rs')
check('layout.rs:67 SH_ROPE = 7', at(Y, 67, 'pub(crate) const SH_ROPE: u32 = 7;'))
check('layout.rs:1341-1342, 1348, 1352-1353 rows = data rows + 2 a site + 2; an H plane counts twice in the data rows',
      at(Y, 1341, 'let a_prox = a_mask_base + 2 * a_prefix[ns];') and at(Y, 1342, 'let a_rows = a_prox + 2;') and at(Y, 1348, 'row += 2 * r;')
      and at(Y, 1352, 'let h_prox = h_mask_base + 2 * h_prefix[ns];') and at(Y, 1353, 'let h_rows = h_prox + 2;'))


def widths(ao, down, q, pv, k, v, gate_shift, up, score, f_p, wrho_s):
    w = [16]

    def rem(bits):
        if bits <= 16:
            w.append(bits)
        else:
            w.append(16)
            w.append(bits - 16)
    for bits in (24, ao, down, q, 7, pv, k, v, 7, gate_shift, up, 16, score, f_p + 1, wrho_s):
        rem(bits)
    return sorted(set(x for x in w if x != 8))


def subs(ws):
    return sum(max(1, (1 << x) >> 14) for x in ws)


def shape_widths(sh_ao, sh_qkv, sh_s, sh_o, sh_z, gate):
    return widths(ao=sh_ao + 14, down=sh_z + 14, q=sh_qkv + 7, pv=sh_o + 3, k=sh_qkv + 7, v=sh_qkv + 8, gate_shift=gate, up=12,
                  score=sh_s + 12, f_p=12, wrho_s=7 + 9)


fix = {g: shape_widths(7, 8, 6, 9, 6, g) for g in range(17, 25)}
check('test calibration: gate shift 20 gives 12 sub-planes (width 4 is also the down projection\x27s), 19 gives 13 (width 3 is new)',
      subs(fix[20]) == 12 and subs(fix[19]) == 13 and 4 in shape_widths(7, 8, 6, 9, 6, 24) and 3 not in fix[20], (fix[20], fix[19]))
check('test calibration, by gate shift 17..24: 13 sub-planes at 17, 19, 22 and 12 at 18, 20, 21, 23, 24 (the handoff\x27s table)',
      [g for g in range(17, 25) if subs(fix[g]) == 13] == [17, 19, 22] and all(subs(fix[g]) in (12, 13) for g in fix))
gs = {ng: max(17, max(8 + 10 + (e + 3) for e in (-4, -3, -2, -1)[:ng])) for ng in (1, 2, 3, 4)}
check('gate shift of case(shape, ng): 17, 18, 19, 20 for ng = 1, 2, 3, 4', gs == {1: 17, 2: 18, 3: 19, 4: 20}, gs)

# ---- 3. the two records --------------------------------------------------------------------------------------------
C = lines(ROOT + '/results/zk60_effplan_20261105/census.log')
check('census.log:218, 227, 235, 236 the census: A rows 2501 (data 2279), H rows 2602 (data 2514); Tab planes 15 in A, 16 in H; H data rows by domain 1257',
      at(C, 218, 'CENSUS W16R2_8B_T128_H24 (n = 2^14): A rows 2501 (data 2279), H rows 2602 (data 2514)')
      and C[226].split() == ['CENSUS', 'W16R2_8B_T128_H24', 'A', 'Tab', 'planes', '15', 'rows', '15']
      and C[234].split() == ['CENSUS', 'W16R2_8B_T128_H24', 'H', 'Tab', 'planes', '16', 'rows', '16']
      and at(C, 236, 'H data rows by domain: 1257'))
a_sites, h_sites = (2501 - 2 - 2279) // 2, (2602 - 2 - 2514) // 2
check('sites from the census\x27s own figures: 110 in A, 43 in H; 15 = 3 + 12 and 16 = 4 + 12',
      (a_sites, h_sites) == (110, 43) and 2279 + 2 * 110 + 2 == 2501 and 2514 + 2 * 43 + 2 == 2602 and 3 + subs(fix[20]) == 15 and 4 + subs(fix[20]) == 16)
check('one more sub-plane: A (2279 + 1) + 2 x 111 + 2 = 2504; H (2514 + 2) + 2 x 44 + 2 = 2606',
      2280 + 2 * 111 + 2 == 2504 and 2516 + 2 * 44 + 2 == 2606)
B = lines(ROOT + '/results/zk60_effplan_20261105/a8/s1_bench.log')
check('a8/s1_bench.log:224-226 the A8 census of the same directory: A rows 2504, H rows 2606; commits of 2504 and 2606 rows',
      at(B, 224, 'A8-CENSUS W16R2_8B_T128_H24 A rows 2504 H rows 2606 n 16384') and at(B, 225, 'commit 2504 x 2^14') and at(B, 226, 'commit 2606 x 2^14'))
K = lines(ROOT + '/results/zk60_slot18_14_breakdown_20261117/raw/w16r2_8b_armC_unbatched_sync_lin0.guard.txt')
check('breakdown record of 17 November, the 8B arm, line 4: a commit of 2504 rows (the file of the R13 arm beside it has 4577 on that line)',
      at(K, 4, 'commit 2504 x 2^14'))
K2 = lines(ROOT + '/results/zk60_w16r2_shield_block_20261120/raw/w16r2_shield_a1.guard.txt')
check('block test of 20 November at the Shieldstral geometry (the same test, so the same fixture: test calibration, three groups), line 4: a commit of 2504 rows',
      at(K2, 4, 'commit 2504 x 2^14'))

# ---- 4. the installed profile: its own calibration (not read by the handoff) ------------------------------------------
E = os.path.expanduser('~') + '/zk60-artifacts/astra-merged-w16r2-slget05j/verifier-export-w16r2-94643880/profile.json'
if os.path.exists(E):
    d = json.load(open(E, encoding='utf-8'))
    u, c = d['uniform_calibration_derivation']['uniform'], d['profile_constants']
    check('installed export, profile file: uniform values gate 20, sh_ao 7, sh_s 7, sh_z 8; constants sh_qkv 8, sh_o 9, sh_g 8, f_e 9, f_p 12, sh_rope 7; 26 layers',
          u == {'gate': 20, 'sh_ao': 7, 'sh_s': 7, 'sh_z': 8} and (c['sh_qkv'], c['sh_o'], c['sh_g'], c['f_e'], c['f_p'], c['sh_rope']) == (8, 9, 8, 9, 12, 7)
          and (c['sh_ao'], c['sh_s'], c['sh_z']) == (7, 7, 8) and d['accuracy_stack'] == 'low-h24-v1' and len(d['layers']) == 26)
else:
    check('installed export present on this machine', False, 'absent: section 4 rests on the builder\x27s source only')
U = lines(ROOT + '/results/zk60_a29_uniform_calibration_20261110/build_uniform.py')
L = lines(ROOT + '/results/zk60_a29_uniform_calibration_20261110/a29lib.py')
check('the export\x27s builder: target gate 20 is the common gate shift of group_folds_for, required of every layer',
      at(U, 53, "TARGET = {'sh_ao': 7, 'sh_s': 7, 'sh_z': 8, 'gate': 20}") and at(U, 200, 'gate = A.gate_common_shift(c, groups, ids)')
      and at(U, 201, "A.require(gate == TARGET['gate']") and at(L, 137, 'group_folds_for') and at(L, 140, "return max(17, int((int(c['sh_g']) + 10 + ej - ein).max()))"))
inst = {g: shape_widths(7, 8, 7, 9, 8, g) for g in range(17, 25)}
check('installed calibration at gate shift 20: widths 3, 4, 5, 6, 7, 12, 13, 15, 16, so 13 sub-planes, 16 Tab planes in A and 17 in H',
      inst[20] == [3, 4, 5, 6, 7, 12, 13, 15, 16] and subs(inst[20]) == 13, inst[20])
lib = sorted(({16, 15, 12, 13, 7} | {b - 16 if b > 16 else b for b in (7 + 14, 8 + 14, 7 + 12, 20)}) - {8})
check('the builder\x27s own mirror of the width list (a29lib.py:150-162) gives the same nine widths for (7, 7, 8, 20)',
      at(L, 150, 'def w16r2_widths(sh_ao, sh_s, sh_z, gate):') and at(L, 155, 'w = {16, 15, 12, 13, 7}') and lib == inst[20], lib)
i13 = [g for g in range(17, 25) if subs(inst[g]) == 13]
check('installed calibration, by gate shift: 13 sub-planes at 17, 18, 20 and 12 at 19, 21, 22, 23, 24; so the handoff\x27s list (17, 19, 22) is the test calibration\x27s only',
      i13 == [17, 18, 20] and all(subs(inst[g]) in (12, 13) for g in inst), i13)
F = lines(ROOT + '/formal/ZK60Formal/BlockInstW16Shield.lean')
P = lines(ROOT + '/formal/ZK60Formal/BlockInstProf.lean')
check('Lean record of the installed profile: rows 2504 and 2606, claim counts 111 and 45 (BlockInstW16Shield.lean:117; fields rA, rH, nA, nH)',
      at(F, 117, 'def numsW16Shield : ProfNums := ⟨23, 2504, 2606, 111, 45,') and at(P, 145, 'rA : ℕ') and at(P, 146, 'rH : ℕ')
      and at(P, 147, 'nA : ℕ') and at(P, 148, 'nH : ℕ'))
check('the H claim count is the H sites plus one in both Lean records: 44 + 1 = 45 here; R13 Shield (4390 - 2 - 4282) / 2 + 1 = 54',
      at(P, 157, 'def numsR13Shield : ProfNums := ⟨23, 4577, 4390, 146, 54,') and at(C, 238, 'A rows 4577 (data 4283), H rows 4390 (data 4282)')
      and (4390 - 2 - 4282) // 2 + 1 == 54 and (4577 - 2 - 4283) // 2 == 146 and (2606 - 2 - 2516) // 2 + 1 == 45)

# ---- 5. the handoff\x27s citation of the two model files ---------------------------------------------------------------
M6 = lines(ROOT + '/results/zk60_effplan_20261105/b6/model.py')
M45 = lines(ROOT + '/results/zk60_effplan_20261105/b4b5/model.py')
check('b6/model.py:35-36 names the census as its source and holds 2501, 2602; in b4b5/model.py the pair is at line 72 under another name',
      at(M6, 35, 'census.log: A rows 2501, H rows 2602') and at(M6, 36, 'A_ROWS, H_ROWS = 2501, 2602')
      and at(M45, 72, 'A_ROWS_TODAY, H_ROWS_TODAY = 2501, 2602') and 'A_ROWS' not in M45[35])
print('\n%d checks, %d failed' % (N[0], N[1]))
print('test calibration,      sub-planes by gate shift:', {g: subs(fix[g]) for g in fix})
print('installed calibration, sub-planes by gate shift:', {g: subs(inst[g]) for g in inst})
sys.exit(1 if N[1] else 0)
