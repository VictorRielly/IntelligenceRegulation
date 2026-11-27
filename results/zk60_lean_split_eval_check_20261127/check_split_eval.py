"""A reading check, 2026-11-27 (co-coordinator): how the Lean model and the Rust verifier evaluate a public table at a
slot's final point. Standard library only; reads source text, runs nothing of the prover.

Usage: python3 -I check_split_eval.py

Part 1 asserts the cited source lines. Part 2 re-computes, in plain integers, a transliteration of the Rust loops:
the eq table against the product that the Lean theorem states, and the split evaluation against the full one.
Part 2 checks my reading of the loops and the identity between them; it is not a run of the Rust code and not a proof.
"""
import os
import random
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) + '/'
CORE = 'ops/zkp-mvp/gpu-metal/zkp-core/src/'
HASH = 'ops/zkp-mvp/gpu-metal/hashline/src/'
LEAN = 'formal/ZK60Formal/'
N = [0, 0]


def check(ok, text):
    N[0] += 1
    if not ok:
        N[1] += 1
    print(('ok   ' if ok else 'FAIL ') + text)


def lines(path):
    return open(ROOT + path, encoding='utf-8').read().split('\n')


def at(path, n, sub):
    return sub in lines(path)[n - 1]


# ---------------------------------------------------------------- part 1: the cited lines
M = CORE + 'mle.rs'
check(at(M, 17, 'pub fn eq_table(r: &[Fp2]) -> Vec<Fp2> {') and at(M, 19, 'vec![Fp2::ONE; 1 << n]')
      and at(M, 37, '*b = e.mul(ri);') and at(M, 38, '*a = e.mul(one_minus);') and at(M, 47, 'len <<= 1;'),
      'Rust eq_table: a buffer of 2^n ones, then for each r_i the low half times (1 - r_i) and a copy times r_i '
      '(mle.rs:17-47)')
check(at(M, 56, 'pub fn eq_table_msb(r: &[Fp2]) -> Vec<Fp2> {') and at(M, 57, 'r.iter().rev()') and at(M, 58, 'eq_table(&rev)'),
      'Rust eq_table_msb is eq_table of the reversed point (mle.rs:56-58)')
E = LEAN + 'ExecMle.lean'
check(at(E, 399, 'def eqStep (len : ℕ) (ri : Fp2) (buf : List Fp2) : List Fp2 :=')
      and at(E, 401, '(buf.take len).map (fun e => e.mul om) ++ ((buf.take len).map (fun e => e.mul ri) ++ buf.drop (2 * len))')
      and at(E, 406, '| ri :: rs, len, buf => eqTableAux rs (len * 2) (eqStep len ri buf)')
      and at(E, 409, 'def eqTable (r : List Fp2) : List Fp2 := eqTableAux r 1 (List.replicate (2 ^ r.length) Fp2.one)'),
      'Lean eqTable: the same buffer and the same doubling step, in the order of r (ExecMle.lean:399-409)')
check(at(E, 412, 'def eqTableMsb (r : List Fp2) : List Fp2 := eqTable r.reverse'),
      'Lean eqTableMsb is eqTable of the reversed point (ExecMle.lean:412)')
check(at(E, 419, 'def msbBits (n idx : ℕ) (j : Fin n) : Bool := decide (idx / 2 ^ (n - 1 - (j : ℕ)) % 2 = 1)')
      and at(E, 563, 'theorem toK_eqTableMsb') and at(E, 565, 'eqPoly (vecK U r.length r) (fun j => bit (msbBits r.length idx j))'),
      'Lean proves the order: entry idx of eqTableMsb is the eq polynomial with variable j at bit n-1-j of idx '
      '(ExecMle.lean:419, 563-565)')
check(at(M, 362, 'fn eq_table_sums_to_one_and_matches_point()') and at(M, 368, '(idx >> (4 - i)) & 1 == 1')
      and at(M, 369, 'assert_eq!(t[idx], eq_point(&r, &bits));'),
      'a Rust test compares the same order on a table of five variables (mle.rs:362-369)')
check(at(E, 639, 'def evalMleExt (v r : List Fp2) : Option Fp2 :=')
      and at(E, 640, 'if v.length = 2 ^ r.length then some (mleSumExt v (eqTableMsb r)) else none'),
      'Lean evalMleExt: the sum of v against the full eq table of the point (ExecMle.lean:639-640)')
B = LEAN + 'ExecBlockVerify.lean'
check(at(B, 243, 'def tabVal (sel : Fp2) (rho terms : List Fp2) : Tab → ℕ → Except String (Fp2 × ℕ)')
      and at(B, 250, '| .pub v, k =>') and at(B, 251, 'match evalMleExt v rho with'),
      "the Lean model of a block's verifier arm evaluates a public table with evalMleExt (ExecBlockVerify.lean:243-251)")
A = HASH + 'private_block/argument.rs'
check(at(A, 1840, 'fn a26_mle_on() -> bool {') and at(A, 1842, 'std::env::var("HL_A26_MLE").map(|v| v != "0").unwrap_or(true)'),
      'the Rust switch HL_A26_MLE is on unless set to 0 (argument.rs:1840-1842)')
check(at(A, 2249, 'Side::Verify { slots } => {') and at(A, 2262, 'crate::mle::SplitEq::new(&rho)')
      and at(A, 2268, 'Tab::Pub(v) => sel.mul(match &split { Some(s) => s.eval_ext(v), None => eval_mle_ext(v, &rho) }),'),
      "with the switch on, the block's verifier arm evaluates a public table through the split form; eval_mle_ext is "
      'the branch taken only with the switch off (argument.rs:2249-2268)')
check(at(M, 104, 'SplitEq { hi: eq_table_msb(&r[..n - lo_log]), lo: eq_table_msb(&r[n - lo_log..]) }')
      and at(M, 103, 'let lo_log = n / 2;') and at(M, 110, 'assert_eq!(v.len(), self.hi.len() * w);')
      and at(M, 114, '.map(|(row, h)| row.iter().zip(lo.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(x.mul(*e))).mul(*h))'),
      'the split form: two half eq tables, one product an entry, one product a row; its length assertion is the same '
      'condition as the full form (mle.rs:103-114)')
check(at(M, 75, 'assert_eq!(v.len(), 1 << r.len());') and at(M, 81, 'assert_eq!(v.len(), 1 << r.len());'),
      'the full forms assert the table length 2^n (mle.rs:75, 81)')
check(at(M, 440, 'fn a26_split_eq_evaluation_equals_eval_mle_ext()') and at(M, 442, 'for n in [0usize, 1, 2, 3, 5, 8, 11, 16, 17] {')
      and at(M, 448, 'for v in [&dense, &base, &edge] {') and at(M, 449, 'assert_eq!(s.eval_ext(v), eval_mle_ext(v, &r), "n {n}");'),
      'the two forms are compared by a Rust test at nine sizes and three kinds of table (mle.rs:440-449): a test, not a proof')
F = CORE + 'field.rs'
check(at(F, 15, 'pub const NONRESIDUE: u64 = 7;') and at(F, 18, 'PartialEq') and at(F, 20, 'pub struct Fp(pub u64);')
      and at(F, 28, 'if v >= P { Fp(v - P) } else { Fp(v) }') and at(F, 137, 'PartialEq')
      and at(F, 168, 'Fp2 { c0: ac.add(bd.mul(Fp(NONRESIDUE))), c1: ad.add(bc) }'),
      'Rust field words: one reduced u64 a base element, compared as words; the extension has u^2 = 7 (field.rs:15-28, 137, 168)')
T = HASH + 'private_block/token_io.rs'
check(at(T, 1106, 'Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho)),'),
      "the stage slots' verifier arm uses the full form (token_io.rs:1106)")
S = LEAN + 'StageCheckDefs.lean'
check(at(S, 149, 'def stageVals') and at(S, 156, 'let m ← evalMleExt v rho'),
      'and its Lean model uses evalMleExt: the same form there (StageCheckDefs.lean:149-156)')
check(at(S, 147, 'token_io.rs:1074-1087'),
      'that Lean comment cites token_io.rs:1074-1087; the lines are at 1101-1110 today (a stale citation)')
# the split form is called from one place in the prover source in use
calls = []
for d, _, fs in os.walk(ROOT + HASH):
    for f in sorted(fs):
        if f.endswith('.rs'):
            p = os.path.join(d, f)
            for i, l in enumerate(open(p, encoding='utf-8').read().split('\n')):
                if '.eval_ext(' in l:
                    calls.append((p[len(ROOT + HASH):], i + 1))
check(calls == [('private_block/argument.rs', 2268)], 'the split form is called from one place in the prover source in use: %s' % calls)
# no Lean file names the split form
lean_files = sorted(f for f in os.listdir(ROOT + LEAN) if f.endswith('.lean'))
hits = []
for f in lean_files:
    t = open(ROOT + LEAN + f, encoding='utf-8').read()
    if any(w in t for w in ('SplitEq', 'splitEq', 'split_eq', 'HL_A26', 'eval_ext')):
        hits.append(f)
check(len(lean_files) > 100 and hits == [],
      'none of the %d Lean files under formal/ZK60Formal names the split form or its switch' % len(lean_files))

R4 = 'results/zk60_claude_review_20261116/W16R2_LAYOUT_CONSUME_READ_20261127.md'
check(at(R4, 188, '| B21 | public table value |') and at(R4, 188, 'NOT DETERMINED (A26 path not read)')
      and at(R4, 188, 'when A26 is on'),
      "the fourth reading's report left this row, B21, not determined: 'A26 path not read' (its line 188)")
# the switch is named at its definition only, and the two sides' history (read through git, nothing checked out)


def git(*args):
    r = subprocess.run(['git', '-C', ROOT] + list(args), capture_output=True, text=True)
    assert r.returncode == 0, r.stderr[-300:]
    return r.stdout


named = git('grep', '-l', 'HL_A26_MLE', '--', 'apps', 'ops/zkp-mvp/gpu-metal', 'scripts').split()
check(named == [A], 'the switch is named in one tracked file of the app, the prover source in use and the scripts: its definition')
first_lean = git('log', '--diff-filter=A', '--format=%cs %h', '--', B).split('\n')[0]
old_lean = git('show', first_lean.split()[1] + ':' + B)
check(first_lean.startswith('2026-11-06 ') and 'match evalMleExt v rho with' in old_lean,
      'the Lean model of the verifier arm was first committed on 2026-11-06, with evalMleExt for a public table')
first_sw = git('log', '--reverse', '-S', 'fn a26_mle_on', '--format=%cs %h', '--', A).split('\n')[0]
before = git('show', first_sw.split()[1] + '^:' + A)
check(first_sw.startswith('2026-11-07 ') and 'SplitEq' not in before
      and 'Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho)),' in before,
      'the switch entered the Rust file in a commit of 2026-11-07; the commit before it has the full form only')

# ---------------------------------------------------------------- part 2: the loops, in integers
P = 0xFFFFFFFF00000001
ZERO, ONE = (0, 0), (1, 0)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def mul(a, b):
    return ((a[0] * b[0] + 7 * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def eq_table(r):
    out = [ONE] * (1 << len(r))
    ln = 1
    for ri in r:
        om = sub(ONE, ri)
        for i in range(ln):
            e = out[i]
            out[ln + i] = mul(e, ri)
            out[i] = mul(e, om)
        ln <<= 1
    return out


def eq_table_msb(r):
    return eq_table(r[::-1])


def eval_mle_ext(v, r):
    assert len(v) == 1 << len(r)
    acc = ZERO
    for a, e in zip(v, eq_table_msb(r)):
        acc = add(acc, mul(e, a))
    return acc


def split_eval(v, r):
    n = len(r)
    lo_log = n // 2
    hi, lo = eq_table_msb(r[:n - lo_log]), eq_table_msb(r[n - lo_log:])
    w = len(lo)
    assert len(v) == len(hi) * w
    total = ZERO
    for c, h in enumerate(hi):
        s = ZERO
        for x, e in zip(v[c * w:(c + 1) * w], lo):
            s = add(s, mul(x, e))
        total = add(total, mul(s, h))
    return total


rng = random.Random(20261127)


def rnd():
    return (rng.randrange(P), rng.randrange(P))


bad = 0
entries = 0
for n in range(0, 9):
    r = [rnd() for _ in range(n)]
    t = eq_table_msb(r)
    for idx in range(1 << n):
        want = ONE
        for j in range(n):
            want = mul(want, r[j] if (idx >> (n - 1 - j)) & 1 else sub(ONE, r[j]))
        bad += t[idx] != want
        entries += 1
check(bad == 0, 'transliterated eq_table_msb, sizes 0 to 8 variables, %d entries: each is the product with variable j '
      'at bit n-1-j, as the Lean theorem states' % entries)
bad = 0
cases = 0
for n in range(0, 13):
    r = [rnd() for _ in range(n)]
    dense = [rnd() for _ in range(1 << n)]
    base = [((i % 255 - 127) % P, 0) for i in range(1 << n)]
    edge = [(ZERO, (P - 1, P - 1), ONE, (i % P, P - 1))[i % 4] for i in range(1 << n)]
    for v in (dense, base, edge):
        bad += split_eval(v, r) != eval_mle_ext(v, r)
        cases += 1
check(bad == 0, 'transliterated split form against the full form, sizes 0 to 12 variables, three kinds of table, '
      '%d cases: the same pair of words every time' % cases)
print('checks: %d, failed: %d' % (N[0], N[1]))
sys.exit(1 if N[1] else 0)
