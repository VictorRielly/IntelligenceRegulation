#!/usr/bin/env python3
"""The project's two blinding counterexamples, aimed at the joint sentence.

Evidence for ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md, Part A claims A-15/A-16.

Counterexample (i) -- A SHARED BLINDING ROW.  Two claim sites masked by the
same row.  Every marginal stays uniform; the joint law determines a witness
difference.  This is the shape of `(H(mask), mask XOR w)`.  The project's run
gate measured the disclosure jumping to 1,024 field elements at the
development shape when two roles share a row.

Counterexample (ii) -- ruling R-3's variant: two DISTINCT blinding rows whose
VALUES coincide.  Structurally there are two independent symbols, so every
rank / disclosed-dimension computation the project's gates run returns the
honest answer; but the realised view is counterexample (i)'s.  This is the one
that is "invisible to every rank computation the project's gates run".

What the script does, in exact arithmetic over a small prime field, over
several seeds and one adversarially constructed instance:

  1. builds a miniature of the protocol's published linear view;
  2. computes the DISCLOSED DIMENSION the project's gates compute -- the
     dimension of the quotient of the published view by the image of the
     blinding map (this is the "disclosed 0 Fp" figure);
  3. shows it is 0 with independent rows, positive with a shared row;
  4. shows that with two DISTINCT symbols whose VALUES coincide the disclosed
     dimension is still 0 -- the gate sees nothing -- while the realised view
     determines a witness difference exactly;
  5. prices the accidental coincidence, and separates it from the case where
     the draw discipline is broken (probability 1, not p^-n).

No randomness from the OS: seeds are explicit, and every number is an integer
mod a small prime.

Run:  python3 counterexamples.py
"""

import itertools
import random

# ---------------------------------------------------------------------------
# exact linear algebra over F_q
# ---------------------------------------------------------------------------

Q = 101  # a small prime; the argument is dimension-counting, not size-sensitive


def inv(a, q=Q):
    return pow(a % q, q - 2, q)


def rref(mat, q=Q):
    """Reduced row echelon form; returns (matrix, pivot columns)."""
    m = [row[:] for row in mat]
    rows = len(m)
    cols = len(m[0]) if rows else 0
    piv = []
    r = 0
    for c in range(cols):
        pr = None
        for i in range(r, rows):
            if m[i][c] % q:
                pr = i
                break
        if pr is None:
            continue
        m[r], m[pr] = m[pr], m[r]
        iv = inv(m[r][c], q)
        m[r] = [(x * iv) % q for x in m[r]]
        for i in range(rows):
            if i != r and m[i][c] % q:
                f = m[i][c]
                m[i] = [(m[i][k] - f * m[r][k]) % q for k in range(cols)]
        piv.append(c)
        r += 1
        if r == rows:
            break
    return m, piv


def rank(mat, q=Q):
    if not mat or not mat[0]:
        return 0
    return len(rref(mat, q)[1])


def matmul_vec(mat, vec, q=Q):
    return [sum(mat[i][j] * vec[j] for j in range(len(vec))) % q
            for i in range(len(mat))]


# ---------------------------------------------------------------------------
# the miniature protocol
# ---------------------------------------------------------------------------
#
# Two claim sites.  Site s publishes  V_s = M_s . w  +  B_s . beta,  where
#   w     is the hidden message (dimension DW),
#   beta  is the blinding vector (dimension DB),
#   M_s   is the public, challenge-determined message map,
#   B_s   is the public blinding map -- WHICH ROW OF beta each site uses.
#
# The project's "disclosed dimension" is
#     dim(published space)  -  rank(the blinding map into it),
# i.e. how many field coordinates of the view are NOT covered by blinding.
# "Disclosed 0" means the blinding map is onto the published space, so for
# every w the view is uniform on the same coset -- witness-free.

DW = 3          # hidden coordinates per site
DB_INDEP = 6    # two independent blinding rows of 3 coordinates
VIEW = 3        # coordinates published per site


def message_map(seed, site):
    rnd = random.Random((seed, site, "M"))
    return [[rnd.randrange(Q) for _ in range(DW)] for _ in range(VIEW)]


def blinding_map_independent(site):
    """Site 0 uses beta[0:3], site 1 uses beta[3:6].  Disjoint rows."""
    B = [[0] * DB_INDEP for _ in range(VIEW)]
    for i in range(VIEW):
        B[i][site * VIEW + i] = 1
    return B


def blinding_map_shared(site):
    """BOTH sites use beta[0:3].  One row, two claims -- counterexample (i)."""
    B = [[0] * DB_INDEP for _ in range(VIEW)]
    for i in range(VIEW):
        B[i][i] = 1
    return B


def stacked(maps):
    """Stack the per-site maps into one (2*VIEW) x k matrix."""
    out = []
    for m in maps:
        out.extend(m)
    return out


def disclosed_dimension(Bs):
    """The figure the project's gates compute: published dim - blinding rank."""
    B = stacked(Bs)
    return len(B) - rank(B)


def view(Ms, Bs, w, beta):
    out = []
    for M, B in zip(Ms, Bs):
        out.extend((a + b) % Q for a, b in
                   zip(matmul_vec(M, w), matmul_vec(B, beta)))
    return out


def line(s=""):
    print(s)


# ---------------------------------------------------------------------------

def part1_shared_row(seeds):
    line("=" * 78)
    line("COUNTEREXAMPLE (i) -- a SHARED blinding row")
    line("=" * 78)
    line("Two claim sites, three published coordinates each.")
    line()
    line(f"{'seed':>5} {'disclosed dim (independent)':>28} "
         f"{'disclosed dim (shared)':>24}  {'marginals uniform?':>19}")
    for seed in seeds:
        Ms = [message_map(seed, 0), message_map(seed, 1)]
        Bi = [blinding_map_independent(0), blinding_map_independent(1)]
        Bs = [blinding_map_shared(0), blinding_map_shared(1)]
        di = disclosed_dimension(Bi)
        ds = disclosed_dimension(Bs)
        # marginal check: each site alone is covered in BOTH cases
        mi = all(disclosed_dimension([b]) == 0 for b in Bs)
        line(f"{seed:>5} {di:>28} {ds:>24}  "
             f"{('yes, each site 0' if mi else 'no'):>19}")
        assert di == 0, "independent rows should disclose nothing"
        assert ds == VIEW, "a shared row should disclose exactly VIEW coords"
    line()
    line("  Reading: with a shared row each site's MARGINAL view is still")
    line("  perfectly blinded (disclosed 0 on its own), and the JOINT view")
    line("  discloses VIEW = 3 coordinates.  That is the project's known trap.")
    line()
    line("  What determines the witness, explicitly:")
    seed = seeds[0]
    Ms = [message_map(seed, 0), message_map(seed, 1)]
    Bs = [blinding_map_shared(0), blinding_map_shared(1)]
    rnd = random.Random((seed, "w"))
    w = [rnd.randrange(Q) for _ in range(DW)]
    w2 = [(x + 1) % Q for x in w]
    for beta_seed in range(4):
        rb = random.Random((seed, beta_seed, "b"))
        beta = [rb.randrange(Q) for _ in range(DB_INDEP)]
        v = view(Ms, Bs, w, beta)
        v2 = view(Ms, Bs, w2, beta)
        d = [(v[i] - v[i + VIEW]) % Q for i in range(VIEW)]
        d2 = [(v2[i] - v2[i + VIEW]) % Q for i in range(VIEW)]
        exp = [(a - b) % Q for a, b in
               zip(matmul_vec(Ms[0], w), matmul_vec(Ms[1], w))]
        assert d == exp, "the difference is not the witness functional"
        assert d != d2, "the two witnesses are not separated"
        if beta_seed == 0:
            line(f"    V_0 - V_1 = (M_0 - M_1).w  = {d}   (blinding cancels)")
            line(f"    the other witness gives      {d2}   -- separated")
    line("  -> the difference of the two sites' views is a function of w with")
    line("     no blinding left in it, whatever beta is.  [COMPUTED]")


def part2_coinciding_values(seeds):
    line()
    line("=" * 78)
    line("COUNTEREXAMPLE (ii) -- ruling R-3: two DISTINCT rows, coinciding")
    line("VALUES")
    line("=" * 78)
    line("The maps are the INDEPENDENT ones (two distinct symbols, disjoint")
    line("stream positions).  Only the VALUES drawn happen to coincide.")
    line()
    n_bad = 0
    for seed in seeds:
        Ms = [message_map(seed, 0), message_map(seed, 1)]
        Bi = [blinding_map_independent(0), blinding_map_independent(1)]
        gate = disclosed_dimension(Bi)
        rnd = random.Random((seed, "w2"))
        w = [rnd.randrange(Q) for _ in range(DW)]
        w2 = [(x + 7) % Q for x in w]
        # the ADVERSARIAL instance: beta[3:6] == beta[0:3]
        rb = random.Random((seed, "coincide"))
        half = [rb.randrange(Q) for _ in range(VIEW)]
        beta = half + half
        v = view(Ms, Bi, w, beta)
        v2 = view(Ms, Bi, w2, beta)
        d = [(v[i] - v[i + VIEW]) % Q for i in range(VIEW)]
        d2 = [(v2[i] - v2[i + VIEW]) % Q for i in range(VIEW)]
        exp = [(a - b) % Q for a, b in
               zip(matmul_vec(Ms[0], w), matmul_vec(Ms[1], w))]
        leaked = (d == exp)
        n_bad += int(leaked)
        line(f"  seed {seed}: gate's disclosed dimension = {gate}  "
             f"(the honest answer); realised view leaks the witness "
             f"functional: {leaked}; separated from w': {d != d2}")
        assert gate == 0, "the gate must see nothing -- that is the point"
        assert leaked, "the realised view must leak on this instance"
    line()
    line(f"  -> on {n_bad}/{len(seeds)} adversarial instances the gate reports")
    line("     'disclosed 0' and the realised view still determines")
    line("     (M_0 - M_1).w exactly.  The gate is a statement about the")
    line("     STRUCTURE (which symbol each site uses); the leak is a")
    line("     statement about the VALUES.  No rank computation can see it.")


def part3_pricing(seeds):
    line()
    line("=" * 78)
    line("PRICING: an accident versus a broken draw discipline")
    line("=" * 78)
    # empirical: how often do two independently drawn rows coincide?
    trials = 400000
    line("  independent draws, k coordinates mod {}:".format(Q))
    for k in (1, 2):
        rnd = random.Random((20260921, k))
        hits = 0
        for _ in range(trials):
            a = [rnd.randrange(Q) for _ in range(k)]
            b = [rnd.randrange(Q) for _ in range(k)]
            hits += int(a == b)
        line(f"    k={k}: predicted q^-k = {Q ** -k:.3e}; measured over "
             f"{trials:,} trials = {hits / trials:.3e} ({hits} hits)")
    line()
    line("  At the real geometry a blinding row is 256 Goldilocks words, so an")
    line("  ACCIDENTAL coincidence of two rows is p^-256 = 2^-16384 -- not a")
    line("  term anybody needs to carry.  [COMPUTED]")
    line()
    line("  A BROKEN DRAW DISCIPLINE is a different object entirely: if two")
    line("  roles read the SAME stream positions (a reused buffer, a cloned")
    line("  generator, an off-by-one in a draw count, a re-entered commit")
    line("  path), the coincidence has probability ONE and is invisible to")
    line("  every gate above.  That -- not the accident -- is what ruling R-3")
    line("  asks a draw-accounting test to exclude.")


def main():
    seeds = [1, 2, 3, 5, 8, 13]
    part1_shared_row(seeds)
    part2_coinciding_values(seeds)
    part3_pricing(seeds)
    line()
    line("ALL ASSERTIONS PASSED.")


if __name__ == "__main__":
    main()
