"""B-CHECK 4: the WHOLE linear view, with no reduction, on generic data --
at group sizes the memo's brute force never reached (m = 3 and m = 5, where
it did m = 1 and m = 2), and with `H`'s zero-sum pair modelled as built.

Two questions:
  (1) do the INDIVIDUAL claim values of a group with m > 2 members add
      anything?  (Lemma S item 5 / the toy's Step 7 / terminal surjection;
      the real `A` has a 35-member group and an 11-member group.)
  (2) is the space `H` discloses EXACTLY the public LogUp identity, or only
      2-dimensional?  The memo proves 2-dimensionality and defers the
      IDENTITY at 125M to GS-1.  Here the span equality is computed.

The view, exactly as the verifier receives it (`pcs.rs:1023-1051`):
  (a) every claim VALUE            -- one Fp2 scalar each
  (b) every GROUP vector           -- rho_g^T [M | pads], n + Q entries
  (c) the PROXIMITY vector         -- likewise
  (d) every OPENED COLUMN          -- one Fp per row, weights E_j over the
                                      n message and Q pad positions
Unknowns: every entry of [M | pads], rows x (n + Q).  The HIDDEN block is
the data rows' message entries.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from f2 import (P, F2ONE, F2U, f2add, f2mul, f2iszero, rank_fp, realify, Rng)  # noqa: E402

OUT = []


def say(s=""):
    print(s)
    OUT.append(s)


N = 8          # row width
Q = 4          # pad symbols == opened columns budget
NCOL = 4       # opened columns


def two_adic_root(k):
    """a primitive 2^k-th root of unity in Goldilocks"""
    g = 7
    e = (P - 1) >> k
    w = pow(g, e, P)
    assert pow(w, 1 << k, P) == 1 and pow(w, 1 << (k - 1), P) != 1
    return w


def column_functionals(ncol, seed):
    """E_j over the n message + Q pad coordinates of one row: the systematic
    Reed-Solomon evaluation at a coset point plus the pad block
    Z_n(x_j) * x_j^k  (the memo's model of `pcs.rs`' encoding, and the one
    its H-pad determinant uses)."""
    import random
    r = random.Random(seed)
    nn = N * 4
    w = two_adic_root(nn.bit_length() - 1)
    shift = 7
    idx = r.sample(range(nn), ncol)
    out = []
    for j in idx:
        x = (shift * pow(w, j, P)) % P
        # Lagrange basis of the n systematic positions (the n-th roots of unity)
        wn = two_adic_root(N.bit_length() - 1)
        zn = (pow(x, N, P) - 1) % P
        e = []
        for s in range(N):
            xs = pow(wn, s, P)
            # L_s(x) = (x^n - 1) / (n * xs^{-1} * (x - xs))
            num = zn * pow(xs, 1, P) % P
            den = (N % P) * ((x - xs) % P) % P
            e.append(num * pow(den, P - 2, P) % P)
        for k in range(Q):
            e.append(zn * pow(x, k, P) % P)
        out.append(e)
    return out


def build(group_sizes, rng, *, pairless_groups=(), u_touchers=(), u_rows=0,
          data_rows=4):
    """Returns (functional matrix over Fp, n_nonhidden_cols, extras)."""
    n_claims = sum(group_sizes)
    n_pairs = n_claims - len(pairless_groups)
    pair_base = data_rows + u_rows
    prox_base = pair_base + 2 * n_pairs
    rows = prox_base + 2
    total = rows * (N + Q)

    def coord(i, s):
        return i * (N + Q) + s

    # ---- the claims: row weights (over all rows) and one column key each
    claims = []      # (row_weights[Fp2] over rows, col_weights[Fp2] over N)
    pair_cursor = 0
    for gi, m in enumerate(group_sizes):
        cw = [rng.f2() for _ in range(N)]       # one key per group
        for _ in range(m):
            rw = [(0, 0)] * rows
            cd, cm = rng.f2(), rng.f2()
            for i in range(data_rows):          # the claim's data-row eq tensor
                rw[i] = f2mul(cd, rng.f2())
            if gi in pairless_groups:
                rw[pair_base - u_rows] = F2ONE  # coefs (1, U) on the u pair
                rw[pair_base - u_rows + 1] = F2U
            else:
                if gi in u_touchers:
                    rw[pair_base - u_rows] = cd
                    rw[pair_base - u_rows + 1] = f2mul(cd, F2U)
                rw[pair_base + 2 * pair_cursor] = cm
                rw[pair_base + 2 * pair_cursor + 1] = f2mul(cm, F2U)
                pair_cursor += 1
            claims.append((rw, cw, gi))

    # ---- the group vectors (zk_rhos) and the proximity vector
    gvecs = []
    for gi in range(len(group_sizes)):
        rho = [(0, 0)] * rows
        for rw, cw, g in claims:
            if g != gi:
                continue
            lam = rng.f2()
            for i in range(rows):
                rho[i] = f2add(rho[i], f2mul(lam, rw[i]))
        gvecs.append(rho)
    prox = [rng.f2() for _ in range(rows)]

    # ---- the functionals, as Fp rows over `total` unknowns
    F = []
    for rw, cw, g in claims:                     # (a) claim values
        v = [(0, 0)] * total
        for i in range(rows):
            if f2iszero(rw[i]):
                continue
            for s in range(N):
                v[coord(i, s)] = f2mul(rw[i], cw[s])
        F.append(v)
    for rho in gvecs + [prox]:                   # (b)(c) group + prox vectors
        for s in range(N + Q):                   # one functional per position
            v = [(0, 0)] * total
            for i in range(rows):
                v[coord(i, s)] = rho[i]
            F.append(v)
    cols = column_functionals(NCOL, 99)          # (d) opened columns
    for e in cols:
        for i in range(rows):
            v = [(0, 0)] * total
            for s in range(N + Q):
                v[coord(i, s)] = (e[s], 0)
            F.append(v)

    # (e) THE ZERO-SUM CONSTRAINT, the thing that makes `H` disclose anything.
    # `protocol.rs:760-768` fills each u row with n-1 random words and sets the
    # last to their negation, so the ALL-ONES functional on a u row is PUBLICLY
    # ZERO.  The u rows therefore give the LogUp sum claim -- whose column
    # weights are exactly all-ones on [0, n) -- no blinding at all.
    for k in range(u_rows):
        v = [(0, 0)] * total
        for s in range(N):
            v[coord(pair_base - u_rows + k, s)] = F2ONE
        F.append(v)

    hidden = [coord(i, s) for i in range(data_rows) for s in range(N)]
    return F, hidden, total, claims, data_rows, rows


def disclosed_of(F, hidden, total):
    hid = set(hidden)
    order = [c for c in range(total) if c not in hid] + list(hidden)
    real = []
    for v in F:
        row = [v[c] for c in order]
        re, im = realify(row)
        real += [re, im]
    nh = total - len(hidden)
    return rank_fp(real) - rank_fp([r[:nh] for r in real])


def rref(vectors):
    """row-reduced echelon basis and its pivot columns"""
    m = [list(r) for r in vectors]
    nr = len(m)
    nc = len(m[0]) if nr else 0
    r = 0
    piv = []
    for c in range(nc):
        p = None
        for i in range(r, nr):
            if m[i][c] % P:
                p = i
                break
        if p is None:
            continue
        m[r], m[p] = m[p], m[r]
        inv = pow(m[r][c], P - 2, P)
        m[r] = [(x * inv) % P for x in m[r]]
        for i in range(nr):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(x - f * y) % P for x, y in zip(m[i], m[r])]
        piv.append(c)
        r += 1
        if r == nr:
            break
    return [m[i] for i in range(r)], piv


def span_of(vectors):
    b, _ = rref(vectors)
    return tuple(tuple(x % P for x in row) for row in b)


def main():
    say("B-CHECK 4  the whole linear view, no reduction, generic data")
    say("=" * 78)
    say("")
    say("(1) A-LIKE: groups of 5, 3, 1, 1 -- the individual claim values of a")
    say("    group with m > 2 members.  The memo's brute force reached m = 2.")
    for s in range(3):
        rng = Rng(4242 + s)
        F, hidden, total, claims, dr, rows = build([5, 3, 1, 1], rng)
        d = disclosed_of(F, hidden, total)
        say(f"    seed {s}: {len(F)} functionals, {total} coordinates, "
            f"{len(hidden)} hidden -> disclosed {d}")
    say("")
    say("    controls (each must FIRE):")
    for label, kw in [("one cm = 0 in a SINGLETON group", dict(zero_cm_singleton=True))]:
        pass
    # control: two claims of DIFFERENT groups sharing one reserved pair
    for s in range(2):
        rng = Rng(555 + s)
        F, hidden, total, claims, dr, rows = build([5, 3, 1, 1], rng)
        # break it: make the two singleton groups' vectors collinear on non-data
        # by zeroing one group's pair entries (a cm = 0 draw in a singleton)
        F2_, hidden2, total2, _, _, _ = build([5, 3, 1, 1], Rng(555 + s))
        # rebuild with cm = 0 on the last claim (a singleton)
        rng2 = Rng(555 + s)
        Fz, hz, tz, cl, dr2, rows2 = build_zero_cm([5, 3, 1, 1], rng2)
        say(f"    seed {s}: cm = 0 in a singleton group -> disclosed "
            f"{disclosed_of(Fz, hz, tz)}")
    say("")
    say("(2) H-LIKE: groups of 3 and 1 with a reserved pair each, SC_ZS's")
    say("    group also touching the two zero-sum u rows, and the pairless")
    say("    LogUp sum claim alone in its group with coefficients (1, U).")
    for s in range(3):
        rng = Rng(9100 + s)
        F, hidden, total, claims, dr, rows = build(
            [3, 1, 1], rng, pairless_groups=(2,), u_touchers=(1,), u_rows=2)
        d = disclosed_of(F, hidden, total)
        # the public LogUp identity: the sum claim's data-row weights, all-ones
        # column weights, restricted to the hidden block
        sumclaim = claims[-1]
        rw, cw, _ = sumclaim
        ident = [(0, 0)] * total
        for i in range(dr):
            for sc in range(N):
                ident[i * (N + Q) + sc] = rw[i]
        hid = set(hidden)
        order = [c for c in range(total) if c not in hid] + list(hidden)
        nh = total - len(hidden)
        ire, iim = realify([ident[c] for c in order])
        ident_span = span_of([ire[nh:], iim[nh:]])
        # the disclosed space: row-reduce with the NON-HIDDEN columns first;
        # the basis rows whose pivot lands in the hidden block, restricted to
        # the hidden block, span exactly what the view pins down about it.
        real = []
        for v in F:
            row = [v[c] for c in order]
            re, im = realify(row)
            real += [re, im]
        basis, piv = rref(real)
        disc = [basis[i][nh:] for i in range(len(basis)) if piv[i] >= nh]
        disc_span = span_of(disc) if disc else ()
        say(f"    seed {s}: disclosed {d}; disclosed span dim "
            f"{len(disc_span)}; public-identity span dim {len(ident_span)}; "
            f"EQUAL: {disc_span == ident_span}")
    say("")
    say("    (the sum claim's value is the public 0, so the identity is the")
    say("    only thing the 2 disclosed dimensions can be, and here it is")
    say("    computed rather than assumed -- which is what GS-1 asks for at")
    say("    125M and what the run gate measured at rung-G.)")

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "brute_view.txt"), "w") as fh:
        fh.write("\n".join(OUT) + "\n")


def build_zero_cm(group_sizes, rng, **kw):
    """`build` with the LAST claim's terminal mask coefficient forced to zero
    (the refused draw ruling G-4 names), as a control that the computation can
    see a leak at all."""
    n_claims = sum(group_sizes)
    data_rows = 4
    pair_base = data_rows
    prox_base = pair_base + 2 * n_claims
    rows = prox_base + 2
    total = rows * (N + Q)

    def coord(i, s):
        return i * (N + Q) + s

    claims = []
    pair_cursor = 0
    for gi, m in enumerate(group_sizes):
        cw = [rng.f2() for _ in range(N)]
        for _ in range(m):
            rw = [(0, 0)] * rows
            cd = rng.f2()
            cm = (0, 0) if (gi == len(group_sizes) - 1) else rng.f2()
            for i in range(data_rows):
                rw[i] = f2mul(cd, rng.f2())
            rw[pair_base + 2 * pair_cursor] = cm
            rw[pair_base + 2 * pair_cursor + 1] = f2mul(cm, F2U)
            pair_cursor += 1
            claims.append((rw, cw, gi))
    gvecs = []
    for gi in range(len(group_sizes)):
        rho = [(0, 0)] * rows
        for rw, cw, g in claims:
            if g != gi:
                continue
            lam = rng.f2()
            for i in range(rows):
                rho[i] = f2add(rho[i], f2mul(lam, rw[i]))
        gvecs.append(rho)
    prox = [rng.f2() for _ in range(rows)]
    F = []
    for rw, cw, g in claims:
        v = [(0, 0)] * total
        for i in range(rows):
            if f2iszero(rw[i]):
                continue
            for s in range(N):
                v[coord(i, s)] = f2mul(rw[i], cw[s])
        F.append(v)
    for rho in gvecs + [prox]:
        for s in range(N + Q):
            v = [(0, 0)] * total
            for i in range(rows):
                v[coord(i, s)] = rho[i]
            F.append(v)
    for e in column_functionals(NCOL, 99):
        for i in range(rows):
            v = [(0, 0)] * total
            for s in range(N + Q):
                v[coord(i, s)] = (e[s], 0)
            F.append(v)
    hidden = [coord(i, s) for i in range(data_rows) for s in range(N)]
    return F, hidden, total, claims, data_rows, rows


if __name__ == "__main__":
    main()
