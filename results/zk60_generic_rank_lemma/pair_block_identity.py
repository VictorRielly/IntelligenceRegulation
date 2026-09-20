#!/usr/bin/env python3
"""U-3a evidence 2: the non-data block's maximal minor factorises.

The claim under test (lemma section 3.2).  Let a commitment have G opening
groups; write the tool's Fp generators of P1 as the real and imaginary parts
of the G group combinations rho_g and of the proximity combination rho_prox
(scripts/zk60_native_jv_pcs.py::_p1_rows).  Pick, for each group, ONE of its
member claims, and let (r, r+1) be that claim's reserved mask pair; let
(prox, prox+1) be the proximity pair.  Then the square submatrix of the
generators on those 2(G+1) columns has determinant

    prod_g  Norm(lambda_g * cm_g)   *   wedge(rho_prox[prox], rho_prox[prox+1])

where cm_g is the claim's terminal-mask coefficient (the claim's row weight
at row r is cm and at row r+1 is cm*U: hashline/src/private_block/
argument.rs::build_claim, hashline/src/private_seam.rs::terminal_claim),
lambda_g is that member's PCS batching challenge (zkp-core/src/pcs.rs::
zk_rhos), Norm is the Fp2 norm c0^2 - 7 c1^2 (zkp-core/src/field.rs:177) and
wedge(a,b) = a.c0 b.c1 - a.c1 b.c0 (the same function the code calls
`determinant`, hashline/src/private_block/protocol.rs:135-137).

So the minor is nonzero iff every chosen lambda and cm is nonzero and the
proximity pair is Fp-independent -- exactly the three things the prover
refuses on.  Nothing generic is left.

This script (a) checks the two scalar identities symbolically-by-exhaustion
on random field elements, and (b) builds synthetic role matrices with the
real combinatorics of the four profiles' A and H commitments, runs the
TOOL'S OWN rank computation (k0 = rank(P1) - rank(P1 restricted to the
non-data rows)) on them, and checks k0 = 0 plus four negative controls.

No capture is read.  Only shapes (row counts, claim counts, group counts)
taken from the layout constants and from the captures' structural header are
used; all field values here are locally drawn.
"""

import random

P = (1 << 64) - (1 << 32) + 1
NONRESIDUE = 7


# ------------------------------------------------------------------ Fp2
def f2mul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


F2_ZERO, F2_ONE, F2_U = (0, 0), (1, 0), (0, 1)


def norm(a):
    return (a[0] * a[0] - NONRESIDUE * a[1] * a[1]) % P


def wedge(a, b):
    return (a[0] * b[1] - a[1] * b[0]) % P


def rank_mod_p(rows, ncols):
    mat = [list(r) for r in rows]
    r = 0
    for c in range(ncols):
        p = None
        for i in range(r, len(mat)):
            if mat[i][c] % P:
                p = i
                break
        if p is None:
            continue
        mat[r], mat[p] = mat[p], mat[r]
        inv = pow(mat[r][c], P - 2, P)
        mat[r] = [x * inv % P for x in mat[r]]
        for i in range(len(mat)):
            if i != r and mat[i][c] % P:
                f = mat[i][c]
                mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
        r += 1
        if r == len(mat):
            break
    return r


def det_mod_p(mat):
    m = [list(r) for r in mat]
    n = len(m)
    d = 1
    for c in range(n):
        p = None
        for i in range(c, n):
            if m[i][c] % P:
                p = i
                break
        if p is None:
            return 0
        if p != c:
            m[c], m[p] = m[p], m[c]
            d = (-d) % P
        d = d * m[c][c] % P
        inv = pow(m[c][c], P - 2, P)
        m[c] = [x * inv % P for x in m[c]]
        for i in range(c + 1, n):
            if m[i][c] % P:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[c])]
    return d


rng = random.Random(20260920)


def r2():
    return (rng.randrange(P), rng.randrange(P))


# ------------------------------------------- (a) the two scalar identities
print("(a) scalar identities, 20000 random draws each")
bad_wedge = bad_scale = 0
for _ in range(20000):
    c, lam = r2(), r2()
    if wedge(c, f2mul(c, F2_U)) != norm(c):
        bad_wedge += 1
    u, v = f2mul(lam, c), f2mul(lam, f2mul(c, F2_U))
    if wedge(u, v) != norm(lam) * norm(c) % P:
        bad_scale += 1
print(f"  wedge(c, c*U) == Norm(c)                       failures {bad_wedge}")
print(f"  wedge(lam*c, lam*c*U) == Norm(lam)*Norm(c)     failures {bad_scale}")
print(f"  Norm(x) == 0 only at x == 0 (Fp2 is a field):  "
      f"{'held' if all(norm(r2()) for _ in range(20000)) else 'FAILED'}")
print(f"  Norm(0) = {norm(F2_ZERO)}, wedge(0, 0) = {wedge(F2_ZERO, F2_ZERO)}")


# ------------------------------------------ (b) synthetic roles, tool's rank
def build_role(n_data, groups, has_u, zero_cm=None, zero_lam=None, dep_prox=False,
               share_pair=False, extra_prox=0):
    """A synthetic commitment with the real combinatorics.

    groups: list of member counts.  Every member claim gets its own reserved
    pair (2 rows), weights (cm, cm*U) there and arbitrary Fp2 weights on the
    data rows.  has_u adds one final 'sum' group of one member whose pair is
    the two zero-sum rows.  The proximity pair is the last two rows.
    Returns (gens, rows, data_rows, other_rows, chosen_minor_columns, cms, lams).
    """
    n_claims = sum(groups) + (1 if has_u else 0)
    n_site = 2 * n_claims
    rows = n_data + n_site + 2 + extra_prox
    prox = n_data + n_site
    all_groups = list(groups) + ([1] if has_u else [])
    rws, owner, pair_of = [], [], []
    r = n_data
    for gi, m in enumerate(all_groups):
        for k in range(m):
            cm = F2_ZERO if (zero_cm == (gi, k) or zero_cm == ("all", gi)) else r2()
            rw = [F2_ZERO] * rows
            for i in range(n_data):
                rw[i] = r2()
            pr = pair_of[0] if (share_pair and pair_of) else r
            rw[pr] = cm
            rw[pr + 1] = f2mul(cm, F2_U)
            if not (share_pair and pair_of):
                r += 2
            rws.append(rw)
            owner.append(gi)
            pair_of.append(pr)
    lams = []
    rhos = []
    for gi, m in enumerate(all_groups):
        rho = [F2_ZERO] * rows
        ls = []
        for k in range(m):
            lam = F2_ZERO if (zero_lam == (gi, k) or zero_lam == ("all", gi)) else r2()
            ls.append(lam)
            idx = sum(all_groups[:gi]) + k
            for i in range(rows):
                if rws[idx][i] != F2_ZERO:
                    rho[i] = f2add(rho[i], f2mul(lam, rws[idx][i]))
        lams.append(ls)
        rhos.append(rho)
    prox_rho = [r2() for _ in range(rows)]
    if dep_prox:
        prox_rho[prox + 1] = f2mul(prox_rho[prox], (rng.randrange(P), 0))
    gens = []
    for rho in rhos + [prox_rho]:
        gens.append([v[0] for v in rho])
        gens.append([v[1] for v in rho])
    data_rows = list(range(n_data))
    other_rows = [i for i in range(rows) if i >= n_data]
    cols = [pair_of[sum(all_groups[:gi])] for gi in range(len(all_groups))]
    cols = sum(([c, c + 1] for c in cols), []) + [prox, prox + 1]
    first_cm = [rws[sum(all_groups[:gi])][pair_of[sum(all_groups[:gi])]]
                for gi in range(len(all_groups))]
    first_lam = [lams[gi][0] for gi in range(len(all_groups))]
    return gens, rows, data_rows, other_rows, cols, first_cm, first_lam, prox_rho, prox


SHAPES = [
    # (name, data rows, eval-group member counts, zero-sum group?, extra prox rows)
    ("block A   (455 rows, 120 claims, 35 groups)", 213,
     [4] * 25 + [2] * 10, False, 0),
    ("block H   (384 rows,  52 claims,  9 groups)", 278,
     [7] * 5 + [6, 5, 5], True, 0),
    ("attn  A   (306 rows,  75 claims, 30 groups)", 154,
     [3] * 15 + [2] * 15, False, 0),
    ("attn  H   (290 rows,  36 claims,  8 groups)", 216,
     [5] * 7, True, 0),
    ("endpoint  (  7 rows,   1 claim,   1 group)", 2, [1], False, 1),
]

print()
print("(b) synthetic roles with the real combinatorics: the tool's own k0")
print(f"{'role':46s} {'rows':>5s} {'gens':>5s} {'rk(P1)':>7s} {'rk|nd':>6s} {'k0':>3s} "
      f"{'minor':>7s} {'=prod?':>7s}")
for name, nd, groups, has_u, xp in SHAPES:
    gens, rows, drows, orows, cols, cms, lams, prox_rho, prox = build_role(
        nd, groups, has_u, extra_prox=xp)
    r1 = rank_mod_p(gens, rows)
    rnd = rank_mod_p([[g[i] for i in orows] for g in gens], len(orows))
    minor = det_mod_p([[g[c] for c in cols] for g in gens])
    want = 1
    for cm, lam in zip(cms, lams):
        want = want * norm(lam) % P * norm(cm) % P
    want = want * wedge(prox_rho[prox], prox_rho[prox + 1]) % P
    print(f"{name:46s} {rows:5d} {len(gens):5d} {r1:7d} {rnd:6d} {r1 - rnd:3d} "
          f"{'nonzero' if minor else 'ZERO':>7s} {str(minor == want):>7s}")

print()
print("(b') negative controls on the block-H shape (each must break k0 = 0)")
ctl = [
    ("one cm zero in group 0", dict(zero_cm=(0, 0))),
    ("EVERY cm of group 0 zero", dict(zero_cm=("all", 0))),
    ("one lambda zero in group 0", dict(zero_lam=(0, 0))),
    ("EVERY lambda of group 0 zero", dict(zero_lam=("all", 0))),
    ("cm of the zero-sum (u) claim zero", dict(zero_cm=("all", 8))),
    ("proximity pair Fp-dependent", dict(dep_prox=True)),
    ("two claims share one reserved pair", dict(share_pair=True)),
]
nd, groups, has_u = 278, [7] * 5 + [6, 5, 5], True
for label, kw in ctl:
    g, rows, drows, orows, cols, cms, lams, prox_rho, prox = build_role(
        nd, groups, has_u, **kw)
    r1 = rank_mod_p(g, rows)
    rnd = rank_mod_p([[x[i] for i in orows] for x in g], len(orows))
    minor = det_mod_p([[x[c] for c in cols] for x in g])
    print(f"  {label:42s} k0 = {r1 - rnd:2d}   chosen minor "
          f"{'nonzero' if minor else 'ZERO'}")

print()
print("READING, control by control.")
print(" * ONE zero cm or lambda kills the minor taken at THAT member's pair but")
print("   not k0: another member of the same group still carries the group.  The")
print("   lemma therefore needs, per group, ONE member with lambda*cm != 0, and")
print("   the code refuses when ANY of them is zero -- strictly stronger.")
print(" * EVERY cm of a group zero is the real danger: the group vector is then")
print("   nonzero on the data rows and zero on every non-data row, i.e. a bare")
print("   functional of the hidden data.  k0 jumps to 2 (512 Fp disclosed).")
print("   audit_claims' zero-coefficient refusal is what forbids it.")
print(" * EVERY lambda of a group zero leaves k0 = 0: the group vector is then")
print("   identically zero, which discloses nothing.  The refusal on lambda = 0")
print("   is therefore conservative for THIS event (it is there for soundness).")
print(" * A dependent proximity pair also leaves k0 = 0 at this shape: the")
print("   proximity vector is random on the other 104 non-data rows and keeps")
print("   its two generators independent there.  The refusal is again")
print("   conservative -- but the u-row argument of section 3.3 does use it.")
print(" * Two claims sharing one reserved pair is the one control that breaks")
print("   the rank badly (k0 = 16 here), and audit_claims refuses it.")
