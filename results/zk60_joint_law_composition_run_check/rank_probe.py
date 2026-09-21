#!/usr/bin/env python3
"""A miniature of the run gate's own linear model, used to build ONE
dependence between the three commitments that hold a boundary plane that a
marginal/rank computation as the gate performs it CANNOT see.

Model (one message position of one interior boundary plane, over GF(q)):

  role A_k      : 2 reserved-pair rows + 2 proximity rows -> publishes its
                  IO group vector (2 Fp) and its proximity vector (2 Fp)
  role B_k      : 2 + 2 reserved-pair rows (site 0, site 1) + 2 proximity
                  rows -> publishes 2 group vectors and 1 proximity vector
                  (6 Fp)
  role A_{k+1}  : as A_k (4 free, 4 published)

  the DATA coordinate d is the plane's word at this position; it enters all
  three roles' published functionals with its own (public, challenge-derived)
  coefficients, i.e. it is a SHARED DATA coordinate, exactly as the gate
  identifies it.

`disclosed` is Lemma 4.1's criterion computed the way the gate computes it:

      disclosed = rank([G_b | G_d]) - rank(G_b)

(the number of independent linear functionals of the published view that
survive averaging over the blinding and still depend on the data).

Four cases:
  H  honest                      -> per-role 0, joint 0, joint == sum
  S  a blinding ROW shared       -> per-role 0, joint > 0   (the project's own
     between B and A_{k+1}          known control; the gate DOES see this one)
  V  two DISTINCT rows that
     always carry EQUAL VALUES   -> per-role 0, joint > 0 in truth, but the
                                    gate's model scores it 0 because it
                                    assigns distinct rows distinct free
                                    symbols.  THIS IS THE BLIND SPOT.
  P  the 37-row boundary (one
     proximity row instead of a
     pair)                       -> discloses 1, reproducing ruling M-1
"""

import random

Q = 10_007          # a small prime; the model is Fp-linear, the size is irrelevant
random.seed(20260920)


# --------------------------------------------------------------- linear algebra
def rank(rows, ncols):
    m = [r[:] for r in rows]
    r = 0
    for c in range(ncols):
        piv = next((i for i in range(r, len(m)) if m[i][c] % Q), None)
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = pow(m[r][c], Q - 2, Q)
        m[r] = [(x * inv) % Q for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c] % Q:
                f = m[i][c]
                m[i] = [(a - f * b) % Q for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def disclosed(G_b, G_d):
    """G_b, G_d: lists of rows, one row per PUBLISHED Fp coordinate."""
    nb = len(G_b[0]) if G_b else 0
    nd = len(G_d[0]) if G_d else 0
    joint = [b + d for b, d in zip(G_b, G_d)]
    return rank(joint, nb + nd) - rank(G_b, nb)


def rnd():
    return random.randrange(1, Q)


# --------------------------------------------------------------- the model
# free blinding coordinates, in one global vector
#   0,1   A_k   reserved pair
#   2,3   A_k   proximity pair
#   4,5   B     site-0 pair
#   6,7   B     site-1 pair
#   8,9   B     proximity pair
#  10,11  A_{k+1} reserved pair
#  12,13  A_{k+1} proximity pair
NB = 14
ND = 1          # the one shared data coordinate

A_K = [0, 1, 2, 3]
B = [4, 5, 6, 7, 8, 9]
A_K1 = [10, 11, 12, 13]


def zero(n):
    return [0] * n


def build(shared_row=None):
    """Return (published_rows_b, published_rows_d, role_index_map).

    `shared_row` = (i, j) makes published coordinates read blinding column i
    wherever they would have read j: a physically SHARED row.
    """
    def col(c):
        if shared_row and c == shared_row[1]:
            return shared_row[0]
        return c

    rows_b, rows_d, role = [], [], []

    def emit(who, blind_cols, data_coef):
        """one published Fp2 value = 2 published Fp coordinates"""
        for _ in range(2):
            rb, rd = zero(NB), zero(ND)
            for c in blind_cols:
                rb[col(c)] = (rb[col(c)] + rnd()) % Q
            rd[0] = data_coef and rnd() or 0
            rows_b.append(rb)
            rows_d.append(rd)
            role.append(who)

    # A_k: its IO group vector (own pair + data), its proximity vector (all
    # four of its free rows + data)
    emit("A_k", [0, 1], True)
    emit("A_k", [0, 1, 2, 3], True)
    # B: group 0 (site-0 pair + data), group 1 (site-1 pair + data),
    #    proximity (every free row + data)
    emit("B", [4, 5], True)
    emit("B", [6, 7], True)
    emit("B", [4, 5, 6, 7, 8, 9], True)
    # A_{k+1}
    emit("A_k1", [10, 11], True)
    emit("A_k1", [10, 11, 12, 13], True)
    return rows_b, rows_d, role


def restrict_equal(rows_b, i, j):
    """impose b_i == b_j (two DISTINCT rows that always carry equal values):
    substitute column j into column i and drop column j."""
    out = []
    for r in rows_b:
        s = r[:]
        s[i] = (s[i] + s[j]) % Q
        s[j] = 0
        out.append(s)
    return out


def report(tag, rows_b, rows_d, role, note):
    per = {}
    for who in ("A_k", "B", "A_k1"):
        rb = [r for r, w in zip(rows_b, role) if w == who]
        rd = [r for r, w in zip(rows_d, role) if w == who]
        per[who] = disclosed(rb, rd)
    j = disclosed(rows_b, rows_d)
    s = sum(per.values())
    flag = "joint == sum" if j == s else "*** JOINT > SUM ***"
    print(f"{tag:<4} per-role {per}  sum {s}  joint {j}   {flag}")
    print(f"      {note}")


def main():
    print("=" * 78)
    print("three roles over one interior boundary plane, one message position")
    print("disclosed = rank([G_b | G_d]) - rank(G_b), over GF(%d)" % Q)
    print("=" * 78)

    rb, rd, role = build()
    report("H", rb, rd, role,
           "honest: every role's own free rows cover its own published "
           "functionals; the shared DATA coordinate couples nothing.")

    # S: B's site-1 pair IS A_{k+1}'s reserved pair (one physical row shared)
    rbS, rdS, roleS = build()
    rbS = restrict_equal(rbS, 6, 10)
    rbS = restrict_equal(rbS, 7, 11)
    report("S", rbS, rdS, roleS,
           "a blinding ROW shared between B's site-1 pair and A_{k+1}'s "
           "reserved pair. THE GATE SEES THIS (control C3): it is a shared "
           "coordinate class in the model.")

    # V: distinct rows, equal VALUES. Same linear consequence as S...
    print()
    print("V    the same arithmetic, reached a different way: two rows that")
    print("     the gate's model calls DISTINCT free symbols but whose values")
    print("     the generator makes equal.  In the model the generators are")
    print("     the honest ones (case H) -> the gate reports joint 0 = sum 0.")
    print("     In truth the blinding lives on the subspace b6=b10, b7=b11,")
    print("     so the real disclosed dimension is case S's:", disclosed(rbS, rdS))
    print("     The gate CANNOT distinguish H from V: it never looks at values.")

    # P: the 37-row boundary, one proximity row instead of a pair
    rbP, rdP, roleP = [], [], []
    def emitP(who, cols, rows_b, rows_d, role):
        for _ in range(2):
            r = zero(NB)
            for c in cols:
                r[c] = (r[c] + rnd()) % Q
            rows_b.append(r)
            rows_d.append([rnd()])
            role.append(who)
    emitP("B", [4, 5], rbP, rdP, roleP)
    emitP("B", [6, 7], rbP, rdP, roleP)
    emitP("B", [4, 5, 6, 7, 8], rbP, rdP, roleP)   # ONE proximity row (col 8)
    print()
    report("P", rbP, rdP, roleP,
           "the 37-row geometry (rows = data + 2*sites + 1): 6 published Fp "
           "against 5 free rows -> discloses 1. Reproduces ruling M-1 and "
           "the gate's control C2.")


if __name__ == "__main__":
    main()
