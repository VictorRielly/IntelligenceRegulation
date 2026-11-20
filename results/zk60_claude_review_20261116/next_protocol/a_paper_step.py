#!/usr/bin/env python3
"""Candidate A paper step: (1) degrees-of-freedom count for the masked LogUp-GKR tree, layers 1..n;
(2) committed rows per 8B block with the helper planes removed.

Used by docs/zkmatrix-poc/ZK60_NEXT_PROTOCOL_A_PAPER_STEP_20261116.md. Standard library only; reads no file.

Inputs, all COUNTED from the recorded census output
results/zk60_effplan_20261105/census.log:218-237 (W16R2_8B_T128_H24, n = 2^14):
  A rows 2501 (data 2279), H rows 2602 (data 2514); H planes per domain D 10, F 5, Kv 3, L 1, Q 3, S 5, Tab 16;
  rows per plane D 32, F 128, Kv 8, L 1, Q 32, S 32, Tab 1; an H plane is Fp2 and takes two base rows (layout.rs:1345-1349).
Plane roles from cycle 6a sec 2 (shape.rs:2562-2589): range helpers L 1, D 10, Q 3, Kv 3, S 4, F 4 planes;
exp/act tuple helpers S 1, F 1; table helpers 15 of the 16 Tab planes; u (zero-sum pair) 1 Tab plane.
Sites: one reserved mask pair (2 rows) per claim site plus one proximity pair (2 rows) per commitment
(layout.rs:1318-1353); H has 43 sites = 43 H planes (census: 88 = 2*43 + 2), so one site per H plane is ASSUMED.
"""

ROW = 2 ** 14
T = 128

H_PLANES = {"D": 10, "F": 5, "Kv": 3, "L": 1, "Q": 3, "S": 5, "Tab": 16}
ROWS_PER_PLANE = {"D": 32, "F": 128, "Kv": 8, "L": 1, "Q": 32, "S": 32, "Tab": 1}
ROLE = {  # planes per domain by role
    "range": {"D": 10, "F": 4, "Kv": 3, "L": 1, "Q": 3, "S": 4, "Tab": 0},
    "expact": {"D": 0, "F": 1, "Kv": 0, "L": 0, "Q": 0, "S": 1, "Tab": 0},
    "table": {"D": 0, "F": 0, "Kv": 0, "L": 0, "Q": 0, "S": 0, "Tab": 15},
    "u": {"D": 0, "F": 0, "Kv": 0, "L": 0, "Q": 0, "S": 0, "Tab": 1},
}
A_ROWS, A_DATA = 2501, 2279


def h_rows(roles):
    planes = sum(ROLE[r][d] for r in roles for d in H_PLANES)
    data = sum(2 * ROLE[r][d] * ROWS_PER_PLANE[d] for r in roles for d in H_PLANES)
    if planes == 0:
        return 0, 0, 0
    return planes, data, data + 2 * planes + 2


def check_census():
    for d, n in H_PLANES.items():
        assert sum(ROLE[r][d] for r in ROLE) == n, d
    planes, data, total = h_rows(list(ROLE))
    assert (planes, data, total) == (43, 2514, 2602), (planes, data, total)


def part2():
    check_census()
    print("PART 2: committed rows per 8B W16R2 block with helper planes removed (base rows of 2^14 words)")
    print("today: A 2501 + H 2602 = 5103 (COUNTED)")
    # what GKR adds to A: one small block of blinding values (+1 row), optionally 2-4 CFS extension rows for
    # the leaf layer (ZK_DESIGN_NOTE sec 4); M: +48..+144 rows of 512 message words (4,096-word codewords).
    for label, kept in [
        ("V1 range+table helpers retired, exp/act and u stay", ["expact", "u"]),
        ("V2 every lookup in the tree, u stays", ["u"]),
        ("V3 H retired entirely", []),
    ]:
        planes, data, hr = h_rows(kept)
        for a_add in (1, 5):
            total = A_ROWS + a_add + hr
            words = total * ROW / T
            m_words = (48 * 512 / T, 144 * 512 / T)
            print(f"  {label:50s} A+{a_add}: A {A_ROWS + a_add}, H {hr} (planes {planes}, data {data}) "
                  f"total {total}  ({100 * total / 5103:.1f}%)  {words / 1e3:.1f} k words/token-layer "
                  f"(+{m_words[0]:.0f}..{m_words[1]:.0f} words/token-layer in M)  kill line 2700: {'PASS' if total <= 2700 else 'KILL'}")
    # Product-tree form (FlashProve): multiplicities committed as 32 bit-planes per table entry.
    # 111,028 range-table entries per block (COUNTED, experiments/logup-gkr-20261101/results.json:14).
    import math
    bits_rows = math.ceil(32 * 111028 / ROW)
    v2 = A_ROWS + 1 + h_rows(["u"])[2]
    for drop in (0, 15):
        total = v2 + bits_rows - drop
        print(f"  product-tree form: V2 + {bits_rows} bit-plane rows - {drop} word-multiplicity rows = {total} "
              f"({total * ROW / T / 1e3:.1f} k words/token-layer)  kill line 2700: {'PASS' if total <= 2700 else 'KILL'}")
    removed = {r: h_rows([r]) for r in ROLE}
    print("  rows that go, by role (data, with their site pairs):",
          {r: (v[1], 2 * v[0]) for r, v in removed.items()})


def part1(n_layers=25):
    """Degrees of freedom of the local masked design, per layer.

    Layer 1 (root's children, no parent coordinate): the verifier sees (p(0), p(1), q(0), q(1)) and checks
    p(0) q(1) + p(1) q(0) = 0. Free revealed values: 4 - 1 = 3. Masks: s, r1, r2 (blinding leaves): 3.
    Layer k >= 2 (k - 1 parent variables, rounds of degree 3 except the last, degree 7 because of Z*R):
      revealed: the masked claim scalar S + c G (1); round polynomials sum_j (deg_j + 1) coefficients minus
      (k - 1) chain constraints = sum_j deg_j; finals 4 plus the M functional V, minus the final check = 4.
      masks: CFS g_k as a sum of univariates, 1 + sum_j deg_j coefficients at minimum (the note allocates
      7k + 2); Libra R^p, R^q: multilinear in the child bit, degree <= 2 in one parent coordinate, 6 + 6.
    Coverage: the scalar by g's constant term, each non-constant round coefficient by the matching
    coefficient of g, the four finals by R^p(0, r), R^p(1, r), R^q(0, r), R^q(1, r) (independent, Z(r) != 0).
    """
    print("PART 1: revealed free values against mask degrees of freedom (Fp2 elements)")
    tot_rev = tot_min = tot_alloc = 0
    for k in range(1, n_layers + 1):
        if k == 1:
            rev, mmin, malloc = 3, 3, 3
        else:
            degs = [3] * (k - 2) + [7]
            rounds_free = sum(degs)
            rev = 1 + rounds_free + 4
            g_min = 1 + sum(degs)
            g_alloc = 7 * k + 2
            mmin = g_min + 12
            malloc = g_alloc + 12
        tot_rev += rev
        tot_min += mmin
        tot_alloc += malloc
        if k <= 3 or k == n_layers:
            print(f"  layer {k:2d}: revealed {rev:3d}  masks (minimum design) {mmin:3d}  "
                  f"(as allocated) {malloc:3d}  spare {mmin - rev:3d}  {'fits' if rev <= mmin else 'DOES NOT FIT'}")
    print(f"  all {n_layers} layers: revealed {tot_rev}, masks minimum {tot_min}, as allocated {tot_alloc}")
    # FlashProve-style pads: one mask entry per sent scalar. Product level with m variables sends 2m + 5 scalars
    # (AUTHORS, format 11-1 via fetch); a fractional (LogUp) level of degree 3 sends about 3m + 4 free scalars
    # (DERIVED by analogy: m rounds of 3 free coefficients plus 4 finals) before its hiding polynomial.
    v = n_layers
    print(f"  FlashProve product key tree, v = {v}: pads sum(2m+5) = {sum(2 * m + 5 for m in range(1, v + 1))}"
          f" (+ hiding-polynomial coefficients per sumcheck, count not read)")
    print(f"  fractional tree with one pad per sent scalar: about {sum(3 * m + 4 for m in range(1, v))} "
          f"(DERIVED by analogy)")


if __name__ == "__main__":
    part1()
    print()
    part2()
