#!/usr/bin/env python3
"""Independent adversarial check: the JOINT rank of a boundary commitment's
published linear view, with two claim sites, computed in exact Goldilocks
arithmetic.

Model (labelled MY OWN MODEL, not the project's gate):

  Fp   = GF(2^64 - 2^32 + 1)          zkp-core/src/field.rs:1-13
  Fp2  = Fp[u]/(u^2 - 7)              zkp-core/src/field.rs:131, NONRESIDUE = 7

  A hiding commitment is `rows x n` base-field words: `data` rows of witness,
  then reserved uniformly-random mask rows (endpoint_g.rs:200-202 writes
  `rng.fp()` into every row from `first_mask` on).  An opening publishes, for
  each column-weight GROUP g, the vector  v_g = rho_g^T [M | pads]  and one
  extra `prox` vector with a fresh random rho over EVERY row
  (zkp-core/src/pcs.rs:835-875).

  rho_g = sum over the group's members of lambda_c * (that claim's row
  weights).  A claim's row weights are: cd * eq(point_head) on the data rows
  (argument.rs:253-257 / pcs.rs:774-782) and EXACTLY (cm, cm*U) on its own
  reserved pair (argument.rs:258-260).

  Hiding at a MESSAGE column j therefore asks: is the Fp-linear map

        Fp^{#mask rows}  -->  Fp2^{G+1} ~ Fp^{2(G+1)}
        (x_r)            |->  ( sum_r rho_g[r] x_r )_g

  surjective?  Equivalently: does the 2(G+1) x #maskrows real matrix have
  full ROW rank 2(G+1)?  That is the same object the joint-view gate factors
  (2(G+1) generators against the commitment's rows).

Controls:
  (1) honest: two claims, DISJOINT pairs, prox PAIR      -> expect rank 6
  (2) shared pair: both claims on pair 0                 -> expect rank < 6
  (3) single prox ROW (rows = data + 2*sites + 1)        -> expect rank < 6
  (4) the pad block (every row is random)                -> expect rank 6
"""

import random

P = (1 << 64) - (1 << 32) + 1
NONRESIDUE = 7


# ----------------------------------------------------------------- Fp2
def f2mul(a, b):
    (a0, a1), (b0, b1) = a, b
    return ((a0 * b0 + NONRESIDUE * a1 * b1) % P, (a0 * b1 + a1 * b0) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


ZERO = (0, 0)
ONE = (1, 0)
U = (0, 1)


def f2scal(a, s):
    """a * s for s in the BASE field."""
    return ((a[0] * s) % P, (a[1] * s) % P)


# ----------------------------------------------------------------- exact rank over Fp
def rank(rows_):
    m = [r[:] for r in rows_]
    nr, nc = len(m), len(m[0]) if m else 0
    r = 0
    for c in range(nc):
        piv = next((i for i in range(r, nr) if m[i][c] % P), None)
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = pow(m[r][c], P - 2, P)
        m[r] = [(x * inv) % P for x in m[r]]
        for i in range(nr):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(m[i][k] - f * m[r][k]) % P for k in range(nc)]
        r += 1
        if r == nr:
            break
    return r


def real_matrix(rhos, cols):
    """The 2*len(rhos) x len(cols) matrix over Fp: each Fp2 coefficient gives
    a real row (c0 part) and an imaginary row (c1 part) of the Fp-linear map
    x |-> sum_r rho[r] x_r."""
    out = []
    for rho in rhos:
        out.append([rho[r][0] for r in cols])
        out.append([rho[r][1] for r in cols])
    return out


# ----------------------------------------------------------------- the model
rng = random.Random(20260920)


def rnd_fp():
    return rng.randrange(P)


def rnd_fp2():
    return (rnd_fp(), rnd_fp())


def eq_table(point):
    """eq_table_msb: the multilinear equality weights of `point`,
    most-significant-first (pcs.rs:778 -> eq_table_msb)."""
    t = [ONE]
    for c in point:
        nxt = []
        for e in t:
            nxt.append(f2mul(e, f2add(ONE, (P - c[0], P - c[1]))))  # e * (1 - c)
            nxt.append(f2mul(e, c))
        t = nxt
    return t


def claim_rho(rows, data_rows, log_rows_of_plane, pair0, cd, cm, lam, point_head):
    """One claim's contribution to its group's rho, times lambda.
    `point_head` are the leading coordinates that index the data ROWS."""
    rho = [ZERO] * rows
    eq = eq_table(point_head)
    assert len(eq) == data_rows
    for i in range(data_rows):
        rho[i] = f2mul(lam, f2mul(cd, eq[i]))
    rho[pair0] = f2mul(lam, cm)
    rho[pair0 + 1] = f2mul(lam, f2mul(cm, U))
    return rho


def build(case):
    """Return (rows, mask_rows, rhos) for a case."""
    DATA_LOG = 5           # 2^5 = 32 data rows at the 125M boundary
    data_rows = 1 << DATA_LOG
    sites = 2
    if case == "single_prox_row":
        rows = data_rows + 2 * sites + 1
        prox0 = data_rows + 2 * sites
        mask_rows = list(range(data_rows, rows))
    else:
        rows = data_rows + 2 * sites + 2
        prox0 = data_rows + 2 * sites
        mask_rows = list(range(data_rows, rows))
    pairs = [data_rows, data_rows + 2]
    if case == "shared_pair":
        pairs = [data_rows, data_rows]
    rhos = []
    for g in range(2):
        rhos.append(
            claim_rho(rows, data_rows, DATA_LOG, pairs[g],
                      cd=rnd_fp2(), cm=rnd_fp2(), lam=rnd_fp2(),
                      point_head=[rnd_fp2() for _ in range(DATA_LOG)])
        )
    # the proximity rho: fresh random over EVERY row (pcs.rs:853)
    rhos.append([rnd_fp2() for _ in range(rows)])
    return rows, mask_rows, prox0, rhos


print("=" * 74)
print("BOUNDARY JOINT RANK — my own exact model, Goldilocks Fp2 = Fp[u]/(u^2-7)")
print("=" * 74)
print("125M boundary: 32 data rows, sites = 2, G = 2 groups, 3 published vectors")
print("required real dimension for a uniform view: 2*(G+1) = 6")
print()

for case, expect in [("honest", 6), ("shared_pair", "< 6"), ("single_prox_row", "< 6")]:
    rows, mask_rows, prox0, rhos = build(case)
    all_cols = list(range(rows))
    r_mask = rank(real_matrix(rhos, mask_rows))
    r_all = rank(real_matrix(rhos, all_cols))
    disclosed = 2 * len(rhos) - r_mask
    print(f"  case {case:<16} rows {rows}  mask rows {mask_rows}")
    print(f"    rank restricted to the mask rows : {r_mask}   (expected {expect})")
    print(f"    rank over all rows (incl. data)  : {r_all}")
    print(f"    DISCLOSED real dimensions        : {disclosed}")
    print()

# ---- the pad block: every row carries q independent random pads (pcs.rs:673)
rows, mask_rows, prox0, rhos = build("honest")
r_pads = rank(real_matrix(rhos, list(range(rows))))
print(f"  pad block (all {rows} rows are free unknowns): rank {r_pads} of 6 needed")
print()

# ---- how many times does the shared-pair control fire over random draws?
fires = 0
TRIALS = 40
for _ in range(TRIALS):
    _, mk, _, rh = build("shared_pair")
    if rank(real_matrix(rh, mk)) < 6:
        fires += 1
print(f"  shared-pair control fired in {fires}/{TRIALS} random draws")

fires = 0
for _ in range(TRIALS):
    _, mk, _, rh = build("honest")
    if rank(real_matrix(rh, mk)) < 6:
        fires += 1
print(f"  honest case degenerate in {fires}/{TRIALS} random draws")
print()
print("NOTE: this models the GROUP/PROX VECTOR channel only (the linear view the")
print("rank stage of the joint-view gate factors). It says nothing about the")
print("opened columns, the Merkle salts or the CFS channel, and it is NOT a")
print("privacy result.")
