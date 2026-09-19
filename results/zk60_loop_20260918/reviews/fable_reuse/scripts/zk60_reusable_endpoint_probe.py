#!/usr/bin/env python3
"""Can a caller-fixed endpoint PCS root be opened more than once and stay private?

Research-only, independent linear model of the ACTUAL `/2` endpoint commitment
and its ordinary opening, pinned to source by SHA-256 and by quoted anchors:

  hashline/src/private_seam.rs   prepare_with_rng: 2 data rows + 5 uniform rows,
                                 mask_rows = [2, 3], prox_mask_row = 4
  zkp-core/src/pcs.rs            encode_row_zk: f = f_data + (x^n - 1) g_pad on
                                 the coset 7*G_nn; Q = 256 pads per row; one
                                 32-byte salt per encoded column; open_zk
                                 publishes rho^T [M | pads], the proximity
                                 vector and 256 columns with salts and paths
  hashline/src/zk_ffn_fresh_io.rs  claim(): (1-e) * data(rho) + e * (row2 + U*row3);
                                 Endpoints/PendingProof are consumed by finish()

What it demonstrates (every number is a model run, not a theorem, and no
native Rust was executed here):

  1. One fixed root opened TWICE at independent challenges discloses all 512
     data words from the message halves of the two group vectors alone: one
     F_p2 word per opening per coordinate pair. No column, salt, path or pad
     entry is used. Three base-field words plus the int16 range already pin a
     pair. Columns alone determine every row once the distinct opened
     positions reach n + Q = 512 (three openings in expectation).
  2. The defect is a BUDGET, not a property of every construction: a layout
     with one terminal pair, one proximity pair and `checks` pads PER USE
     discloses 0 through use k and discloses at use k + 1 (exact rank on a
     small geometry, complete system including columns).
  3. A stateful ROM simulator for such a k-use endpoint under a caller-fixed
     root WITH prior public openings: it keeps every authenticated node,
     samples one virtual owner from the fibre of the prior field observations,
     programs only nodes whose preimage is not public (the frontier), mirrors
     the owner's use budget by refusing, and never creates a second observed
     preimage of a public node. The fresh top-pair simulator is the special
     case of an empty history and is a distinguisher otherwise (control).

Nothing here changes a production protocol, relaxes P1 or accepts privacy.
"""
import argparse
import hashlib
import json
import random
from dataclasses import dataclass, field
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = 0xFFFF_FFFF_0000_0001
NONRESIDUE = 7          # zkp-core/src/field.rs: Fp2 = Fp[u]/(u^2 - 7)
GENERATOR = 7           # field.rs GENERATOR, also ZkOpts::standard's coset shift
TWO_ADICITY = 32

SOURCE_PINS = {
    "zkp-core/src/pcs.rs": "2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d",
    "zkp-core/src/field.rs": "df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13",
    "zkp-core/src/merkle.rs": "77bc5f51e5f11f150bec0813a2a810dd77d3dff3d1d4963e43a8923d106e4f62",
    "zkp-core/src/ntt.rs": "97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890",
    "zkp-core/src/mle.rs": "131cf1b49a2f280147ccb1d8f374c139cd7033a8a4ddb02c473b751937409614",
    "zkp-core/src/transcript.rs": "31ce3c9a72da3bd3d6dcc9203c9ed7a51963cde462b59a66186467b4cb733da8",
    "hashline/src/zk_ffn_fresh_io.rs": "1d9bab12929ba82d79735c88cc3fb8fc047424a598b9990038e7f7780dda362c",
    "hashline/src/private_seam.rs": "2f36c779e79c4d7a45538fb1d596a83e6eef9fe18f1b5e138b7d72afd3ee8cf5",
    "hashline/src/zk_ffn_fresh_poc.rs": "de86a47b067f950ff780c93e85b3dba28292603f8db581ec9c9c77bbd24f70ba",
}

# Each modelled fact is tied to a literal source line. A pin failure means the
# model must be re-derived, not that the finding moved.
SOURCE_ANCHORS = {
    "zkp-core/src/pcs.rs": [
        "ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }",
        "out[i] = out[i].sub(pad[i]);",
        "out[n + i] = pad[i];",
        "let pads = rng.fp_vec(rows * q);",
        "let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();",
        "let padf = fold_rows_host(&cmz.pads, rows, q, q, 1, rhos);",
        "(j, col, cmz.salts[j], cm.tree.path(j))",
        "let prox_rho = tr.challenge_fp2_vec(rows);",
    ],
    "zkp-core/src/transcript.rs": ["out.push((v as usize) & (bound - 1));"],
    "zkp-core/src/merkle.rs": ["cur = if idx & 1 == 0 { hash_pair(&cur, sib) } else { hash_pair(sib, &cur) };"],
    "hashline/src/private_seam.rs": [
        "const MASK_ROWS: usize = 5;",
        "committed.mask_rows = vec![first_mask, first_mask + 1];",
        "committed.prox_mask_row = Some(first_mask + 2);",
        "pub(crate) fn into_ffn_endpoint(self, spec: &SeamSpec) -> Result<CommittedZk, String> {",
    ],
    "hashline/src/zk_ffn_fresh_io.rs": [
        "coef: Fp2::ONE.sub(e),",
        "coef: e.mul(Fp2::U),",
        "right_claims.push(claim(0, 2, &rho, e, a.terminals[1]));",
        "check_masks(claims, 7, 8, &[2, 3], 4, &self.tr)?;",
        "endpoint_open[i] = pcs::open_zk(&endpoint, claims, &mut self.tr);",
        "pub fn finish(mut self, endpoints: Endpoints) -> Result<Receipt, String> {",
    ],
    "hashline/src/zk_ffn_fresh_poc.rs": [
        "if prox + 1 >= rows || determinant(rho[prox], rho[prox + 1]).is_zero() {",
    ],
}


class Refusal(Exception):
    """A public refusal: part of the view in both worlds."""


def require(ok, message):
    if not ok:
        raise ValueError(message)


def check_source_pins(root=ROOT):
    record = {}
    for rel, want in SOURCE_PINS.items():
        text = (root / rel).read_bytes()
        got = hashlib.sha256(text).hexdigest()
        missing = [a for a in SOURCE_ANCHORS.get(rel, []) if a.encode() not in text]
        record[rel] = dict(sha256=got, pinned=got == want, missing_anchors=missing)
    return record


# ---------------------------------------------------------------- field ----

def inv(x):
    require(x % P != 0, "inverse of zero")
    return pow(x, P - 2, P)


F2_ZERO, F2_ONE, F2_U = (0, 0), (1, 0), (0, 1)


def f2_add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2_sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2_mul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2_is_zero(a):
    return a[0] % P == 0 and a[1] % P == 0


def determinant(a, b):
    """zk_ffn_fresh_poc.rs::determinant: Fp-independence of two Fp2 words."""
    return (a[0] * b[1] - a[1] * b[0]) % P


def two_adic_root(k):
    require(0 <= k <= TWO_ADICITY, "two-adic order")
    return pow(pow(GENERATOR, (P - 1) >> TWO_ADICITY, P), 1 << (TWO_ADICITY - k), P)


def ntt(values, root):
    """Natural-order radix-2 transform: coefficients -> values at root^i (ntt.rs)."""
    a = list(values)
    n = len(a)
    require(n > 0 and n & (n - 1) == 0, "NTT length")
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    length = 2
    while length <= n:
        step = pow(root, n // length, P)
        half = length // 2
        tw = [1] * half
        for k in range(1, half):
            tw[k] = tw[k - 1] * step % P
        for i in range(0, n, length):
            for k in range(half):
                u, v = a[i + k], a[i + k + half] * tw[k] % P
                a[i + k], a[i + k + half] = (u + v) % P, (u - v) % P
        length <<= 1
    return a


def intt(values, root):
    n_inv = inv(len(values))
    return [x * n_inv % P for x in ntt(values, inv(root))]


def eq_table_msb(point):
    """mle.rs::eq_table_msb: point[0] is the most significant index bit."""
    out = [F2_ONE]
    for r in point:
        one_minus = f2_sub(F2_ONE, r)
        out = [x for e in out for x in (f2_mul(e, one_minus), f2_mul(e, r))]
    return out


# --------------------------------------------------------------- layout ----

@dataclass(frozen=True)
class Layout:
    """Rows: 2 data | one terminal pair per use | one proximity pair per use | extra.

    uses = 1, extra_rows = 1 is exactly the source endpoint (7 rows, terminal
    pair (2, 3), proximity pair (4, 5), spare row 6, Q = checks pads). uses > 1
    is the research-only budgeted layout of the repair discussion.
    """
    log_n: int
    checks: int
    inv_rate: int = 8
    uses: int = 1
    extra_rows: int = 1

    def __post_init__(self):
        require(self.uses >= 1 and self.n + self.q <= self.nn, "layout exceeds the code length")

    @property
    def n(self):
        return 1 << self.log_n

    @property
    def q(self):
        return self.uses * self.checks

    @property
    def nn(self):
        return self.n * self.inv_rate

    @property
    def width(self):
        return self.n + self.q

    @property
    def rows(self):
        return 2 + 4 * self.uses + self.extra_rows

    @property
    def depth(self):
        return self.nn.bit_length() - 1

    def terminal_pair(self, use):
        require(0 <= use < self.uses, "use index outside the terminal-mask budget")
        return (2 + 2 * use, 3 + 2 * use)

    def prox_pair(self, use):
        require(0 <= use < self.uses, "use index outside the proximity-mask budget")
        base = 2 + 2 * self.uses
        return (base + 2 * use, base + 2 * use + 1)

    def opening_bytes(self):
        """zk_ffn_fresh_io.rs::ENDPOINT_OPEN_BYTES generalized to this layout."""
        return 2 * self.width * 16 + self.checks * (8 + self.rows * 8 + 32 + self.depth * 32)


SOURCE = Layout(log_n=8, checks=256)
SMALL_SOURCE = Layout(log_n=2, checks=4)
SMALL_BUDGET2 = Layout(log_n=2, checks=4, uses=2, extra_rows=0)


def encode_row(layout, message, pad):
    """pcs.rs::encode_row_zk. Returns the nn values of f on the coset 7*G_nn."""
    n, nn = layout.n, layout.nn
    require(len(message) == n and len(pad) == layout.q, "row shape")
    coeffs = intt(message, two_adic_root(layout.log_n)) + [0] * (nn - n)
    for i, x in enumerate(pad):
        coeffs[i] = (coeffs[i] - x) % P
        coeffs[n + i] = (coeffs[n + i] + x) % P
    shift = 1
    for i in range(layout.width):
        coeffs[i] = coeffs[i] * shift % P
        shift = shift * GENERATOR % P
    return ntt(coeffs, two_adic_root(layout.depth))


class Endpoint:
    """The private owner's field content: message rows, pads, encoded rows."""

    def __init__(self, layout, data, rng, message=None, pads=None):
        n = layout.n
        require(len(data) == 2 * n and all(0 <= x < P for x in data), "endpoint data")
        self.layout = layout
        if message is None:
            message = [list(data[:n]), list(data[n:])]
            message += [[rng.randrange(P) for _ in range(n)] for _ in range(layout.rows - 2)]
            pads = [[rng.randrange(P) for _ in range(layout.q)] for _ in range(layout.rows)]
        require(message[0] == list(data[:n]) and message[1] == list(data[n:]), "data rows")
        self.message, self.pads = message, pads
        self._encoded = None

    def full(self, row):
        return self.message[row] + self.pads[row]

    def encoded(self):
        if self._encoded is None:
            self._encoded = [encode_row(self.layout, m, p) for m, p in zip(self.message, self.pads)]
        return self._encoded

    def column(self, j):
        return [row[j] for row in self.encoded()]


# ------------------------------------------------------------- openings ----

@dataclass
class Challenge:
    use: int
    lam: tuple
    e: tuple
    r0: tuple
    tail: list
    prox: list
    index_seed: bytes


def draw_challenge(layout, use, rng):
    """Uniform challenges with the source refusals mirrored (never resampled there;
    resampling here only keeps the synthetic run inside the accepted set)."""
    while True:
        ch = Challenge(use, _f2(rng), _f2(rng), _f2(rng), [_f2(rng) for _ in range(layout.log_n)],
                       [_f2(rng) for _ in range(layout.rows)], rng.randbytes(16))
        a, b = layout.prox_pair(use)
        if not (f2_is_zero(ch.lam) or f2_is_zero(ch.e) or determinant(ch.prox[a], ch.prox[b]) == 0):
            return ch


def _f2(rng):
    return (rng.randrange(P), rng.randrange(P))


def group_weights(layout, ch):
    """Row weights of the single endpoint claim group: lam * claim(0, 2, rho, e, .)."""
    w = [F2_ZERO] * layout.rows
    body = f2_mul(ch.lam, f2_sub(F2_ONE, ch.e))
    w[0] = f2_mul(body, f2_sub(F2_ONE, ch.r0))
    w[1] = f2_mul(body, ch.r0)
    t0, t1 = layout.terminal_pair(ch.use)
    w[t0] = f2_mul(ch.lam, ch.e)
    w[t1] = f2_mul(w[t0], F2_U)
    return w


def fold(weights, rows):
    """rho^T [M | pads]: base-field rows under Fp2 weights."""
    live = [(w, r) for w, r in zip(weights, rows) if not f2_is_zero(w)]
    return [(sum(w[0] * r[c] for w, r in live) % P, sum(w[1] * r[c] for w, r in live) % P)
            for c in range(len(rows[0]))]


def derive_indices(layout, ch, group_vec, prox_vec):
    """Adaptive positions: a hash of the published vectors (SHA-256 stands in for the
    transcript), masked with replacement as transcript.rs::challenge_indices."""
    h = hashlib.sha256(ch.index_seed)
    for v in (group_vec, prox_vec):
        for x in v:
            h.update(x[0].to_bytes(8, "little") + x[1].to_bytes(8, "little"))
    seed, out, counter = h.digest(), [], 0
    while len(out) < layout.checks:
        block = hashlib.sha256(seed + counter.to_bytes(8, "little")).digest()
        counter += 1
        for k in range(0, 32, 8):
            if len(out) < layout.checks:
                out.append(int.from_bytes(block[k:k + 8], "little") & (layout.nn - 1))
    return out


@dataclass
class Opening:
    challenge: Challenge
    group_vec: list
    prox_vec: list
    value: tuple
    columns: list                      # [(index, column words)] in sampled order
    salts: dict = field(default_factory=dict)
    paths: dict = field(default_factory=dict)


def open_field(endpoint, ch):
    layout = endpoint.layout
    rows = [endpoint.full(i) for i in range(layout.rows)]
    weights = group_weights(layout, ch)
    group_vec, prox_vec = fold(weights, rows), fold(ch.prox, rows)
    cw = eq_table_msb(ch.tail)
    value = F2_ZERO
    for c in range(layout.n):
        value = f2_add(value, f2_mul(cw[c], group_vec[c]))
    value = f2_mul(value, _f2_inv(ch.lam))
    indices = derive_indices(layout, ch, group_vec, prox_vec)
    return Opening(ch, group_vec, prox_vec, value, [(j, endpoint.column(j)) for j in indices])


def _f2_inv(a):
    norm = inv((a[0] * a[0] - NONRESIDUE * a[1] * a[1]) % P)
    return (a[0] * norm % P, -a[1] * norm % P)


def verify_field(layout, op):
    """The field half of pcs.rs::verify_zk for the one-claim endpoint opening."""
    ch = op.challenge
    if len(op.group_vec) != layout.width or len(op.prox_vec) != layout.width:
        return "vector length"
    cw = eq_table_msb(ch.tail)
    got = F2_ZERO
    for c in range(layout.n):
        got = f2_add(got, f2_mul(cw[c], op.group_vec[c]))
    if got != f2_mul(ch.lam, op.value):
        return "group vector disagrees with the combined claim"
    if [j for j, _ in op.columns] != derive_indices(layout, ch, op.group_vec, op.prox_vec):
        return "column positions"
    checks = []
    for weights, vec in ((group_weights(layout, ch), op.group_vec), (ch.prox, op.prox_vec)):
        n = layout.n
        re = encode_row(layout, [x[0] for x in vec[:n]], [x[0] for x in vec[n:]])
        im = encode_row(layout, [x[1] for x in vec[:n]], [x[1] for x in vec[n:]])
        checks.append((weights, re, im))
    for j, col in op.columns:
        if len(col) != layout.rows:
            return "column length"
        for weights, re, im in checks:
            acc = (sum(w[0] * x for w, x in zip(weights, col)) % P,
                   sum(w[1] * x for w, x in zip(weights, col)) % P)
            if acc != (re[j], im[j]):
                return f"column {j} disagrees with a clear vector"
    return None


# ------------------------------------------------------ linear algebra ----

def _eliminate(matrix, rhs=None, reduce=True):
    """In-place elimination mod P (reduced row echelon form unless reduce=False,
    which clears below the pivot only). Returns the pivot list [(row, col)]."""
    pivots, r = [], 0
    width = len(matrix[0]) if matrix else 0
    for c in range(width):
        p = next((i for i in range(r, len(matrix)) if matrix[i][c]), None)
        if p is None:
            continue
        matrix[r], matrix[p] = matrix[p], matrix[r]
        if rhs is not None:
            rhs[r], rhs[p] = rhs[p], rhs[r]
        s = inv(matrix[r][c])
        matrix[r] = [x * s % P for x in matrix[r]]
        if rhs is not None:
            rhs[r] = rhs[r] * s % P
        for i in range(0 if reduce else r + 1, len(matrix)):
            f = matrix[i][c]
            if i != r and f:
                matrix[i] = [(x - f * y) % P for x, y in zip(matrix[i], matrix[r])]
                if rhs is not None:
                    rhs[i] = (rhs[i] - f * rhs[r]) % P
        pivots.append((r, c))
        r += 1
        if r == len(matrix):
            break
    return pivots


def rank(matrix):
    return len(_eliminate([list(row) for row in matrix], reduce=False))


def solve_affine(matrix, rhs, rng=None):
    """One solution of matrix * x = rhs (uniform over the fibre when rng is given,
    free coordinates zero otherwise); None when inconsistent."""
    a, b = [list(row) for row in matrix], list(rhs)
    pivots = _eliminate(a, b)
    if any(b[i] for i in range(len(pivots), len(a))):
        return None
    width = len(a[0])
    pivot_cols = {c for _, c in pivots}
    x = [0] * width
    for c in range(width):
        if c not in pivot_cols and rng is not None:
            x[c] = rng.randrange(P)
    for r, c in pivots:
        x[c] = (b[r] - sum(a[r][k] * x[k] for k in range(width) if k != c and a[r][k])) % P
    return x


_EVAL_CACHE = {}


def evaluation_matrix(layout):
    """E[j][c]: value at coset position j of the unit message/pad coordinate c."""
    if layout not in _EVAL_CACHE:
        require(layout.nn * layout.width <= 1 << 12, "complete-system model is for small geometries")
        cols = []
        for c in range(layout.width):
            unit = [0] * layout.width
            unit[c] = 1
            cols.append(encode_row(layout, unit[:layout.n], unit[layout.n:]))
        _EVAL_CACHE[layout] = [[cols[c][j] for c in range(layout.width)] for j in range(layout.nn)]
    return _EVAL_CACHE[layout]


def observation_system(layout, openings, channels=("group", "prox", "columns")):
    """Every published field word of `openings` as one linear system over the
    rows * (n + Q) owner unknowns. Exact and complete for the field layer."""
    unknowns = layout.rows * layout.width
    matrix, rhs = [], []
    for op in openings:
        vectors = []
        if "group" in channels:
            vectors.append((group_weights(layout, op.challenge), op.group_vec))
        if "prox" in channels:
            vectors.append((op.challenge.prox, op.prox_vec))
        for weights, vec in vectors:
            for c in range(layout.width):
                for part in (0, 1):
                    row = [0] * unknowns
                    for i, w in enumerate(weights):
                        row[i * layout.width + c] = w[part]
                    matrix.append(row)
                    rhs.append(vec[c][part])
        if "columns" in channels:
            e = evaluation_matrix(layout)
            for j, col in op.columns:
                for i, y in enumerate(col):
                    row = [0] * unknowns
                    row[i * layout.width:(i + 1) * layout.width] = e[j]
                    matrix.append(row)
                    rhs.append(y)
    return matrix, rhs


def data_columns(layout):
    return [i * layout.width + c for i in (0, 1) for c in range(layout.n)]


def disclosed_dimension(layout, openings, channels=("group", "prox", "columns")):
    """Number of independent linear functionals of the DATA fixed by the view:
    rank(A) - rank(A without the data columns)."""
    matrix, _ = observation_system(layout, openings, channels)
    data = set(data_columns(layout))
    rest = [[x for k, x in enumerate(row) if k not in data] for row in matrix]
    return rank(matrix) - rank(rest)


def sample_owner(layout, data, openings, rng):
    """A uniformly sampled owner (masks and pads) holding `data` and reproducing
    every published field word of `openings`; None when no such owner exists."""
    matrix, rhs = observation_system(layout, openings)
    data_idx = data_columns(layout)
    if not matrix:
        return Endpoint(layout, data, rng)
    data_set = set(data_idx)
    rest_idx = [k for k in range(layout.rows * layout.width) if k not in data_set]
    shifted = [(b - sum(row[k] * d for k, d in zip(data_idx, data))) % P for row, b in zip(matrix, rhs)]
    x = solve_affine([[row[k] for k in rest_idx] for row in matrix], shifted, rng)
    if x is None:
        return None
    flat = [0] * (layout.rows * layout.width)
    for k, d in zip(data_idx, data):
        flat[k] = d
    for k, v in zip(rest_idx, x):
        flat[k] = v
    rows = [flat[i * layout.width:(i + 1) * layout.width] for i in range(layout.rows)]
    return Endpoint(layout, data, rng, [r[:layout.n] for r in rows], [r[layout.n:] for r in rows])


def per_coordinate_disclosure(layout, challenges, channels=("group", "prox")):
    """Exact at ANY geometry: the clear vectors decouple per coordinate, so their
    disclosure is a rows-unknown system. A lower bound for the complete view."""
    matrix = []
    for ch in challenges:
        if "group" in channels:
            matrix += [[w[part] for w in group_weights(layout, ch)] for part in (0, 1)]
        if "prox" in channels:
            matrix += [[w[part] for w in ch.prox] for part in (0, 1)]
    return rank(matrix) - rank([row[2:] for row in matrix])


# -------------------------------------------------------------- attacks ----

def recover_from_group_vectors(layout, first, second):
    """THE MINIMUM SET. Two openings of one root whose claims share a terminal
    pair: coordinate k of both group vectors is 4 base equations in the 4
    unknowns (x[k], x[n + k], row2[k], row3[k])."""
    rows = [0, 1, *layout.terminal_pair(first.challenge.use)]
    require(rows[2:] == list(layout.terminal_pair(second.challenge.use)), "openings use different terminal pairs")
    w = [group_weights(layout, op.challenge) for op in (first, second)]
    system = [[wi[r][part] for r in rows] for wi in w for part in (0, 1)]
    require(rank(system) == 4, "degenerate challenge pair")
    out = [None] * (2 * layout.n)
    for k in range(layout.n):
        rhs = [op.group_vec[k][part] for op in (first, second) for part in (0, 1)]
        x = solve_affine(system, rhs)
        out[k], out[layout.n + k] = x[0], x[1]
    return out


def recover_pair_from_three_words(layout, first, second, k, bound=1 << 15):
    """Three base words (both halves of v1[k], the real half of v2[k]) plus the
    int16 range: eliminate the mask pair, then enumerate one coordinate."""
    rows = [*layout.terminal_pair(first.challenge.use), 0, 1]
    w1, w2 = group_weights(layout, first.challenge), group_weights(layout, second.challenge)
    a = [[w1[r][0] for r in rows], [w1[r][1] for r in rows], [w2[r][0] for r in rows]]
    b = [first.group_vec[k][0], first.group_vec[k][1], second.group_vec[k][0]]
    _eliminate(a, b)
    require(a[2][0] == 0 and a[2][1] == 0 and a[2][2] == 1, "mask elimination")
    beta, gamma = a[2][3], b[2]                     # x0 + beta * x1 = gamma
    found = []
    for x1 in range(-bound, bound):
        x0 = (gamma - beta * x1) % P
        x0 = x0 - P if x0 > P // 2 else x0
        if -bound <= x0 < bound:
            found.append((x0 % P, x1 % P))
    return found


def recover_from_columns(layout, openings):
    """Pad exhaustion: once n + Q distinct positions of a row are public the row
    polynomial is interpolated and the data read at the subgroup (Z_n vanishes)."""
    points = {}
    for op in openings:
        for j, col in op.columns:
            points.setdefault(j, col)
    if len(points) < layout.width:
        return None
    omega = two_adic_root(layout.depth)
    chosen = sorted(points)[:layout.width]
    xs = [GENERATOR * pow(omega, j, P) % P for j in chosen]
    weights = []
    for i, xi in enumerate(xs):
        d = 1
        for m, xm in enumerate(xs):
            if m != i:
                d = d * (xi - xm) % P
        weights.append(d)
    weights = _batch_inverse(weights)
    base = two_adic_root(layout.log_n)
    out = [[], []]
    for k in range(layout.n):
        t = pow(base, k, P)
        diffs = [(t - x) % P for x in xs]
        ell = 1
        for d in diffs:
            ell = ell * d % P
        inv_diffs = _batch_inverse(diffs)
        for row in (0, 1):
            acc = sum(wt * points[j][row] % P * idf for wt, j, idf in zip(weights, chosen, inv_diffs)) % P
            out[row].append(ell * acc % P)
    return out[0] + out[1]


def _batch_inverse(values):
    prefix, acc = [], 1
    for v in values:
        prefix.append(acc)
        acc = acc * v % P
    acc = inv(acc)
    out = [0] * len(values)
    for i in range(len(values) - 1, -1, -1):
        out[i] = acc * prefix[i] % P
        acc = acc * values[i] % P
    return out


# ----------------------------------------------------- ideal hash layer ----

class Oracle:
    """One lazily sampled table for every input. As in the source, salted leaves
    and tree nodes are both untagged 64-byte inputs and therefore share it."""

    def __init__(self, seed):
        self._rng = random.Random(seed)
        self.table, self.programmed = {}, []

    def query(self, data):
        if data not in self.table:
            self.table[data] = self._rng.randbytes(32)
        return self.table[data]

    def program(self, data, digest):
        if data in self.table:
            raise Refusal("programmed input was already answered")
        self.table[data] = digest
        self.programmed.append(data)


def column_bytes(col):
    require(len(col) != 8, "an 8-row column is 64 bytes and would share the node domain")
    return b"".join(x.to_bytes(8, "little") for x in col)


def salted_leaf(oracle, col, salt):
    return oracle.query(oracle.query(column_bytes(col)) + salt)


def verify_path(oracle, root, index, leaf, path):
    cur = leaf
    for sib in path:
        cur = oracle.query(cur + sib if index & 1 == 0 else sib + cur)
        index >>= 1
    return cur == root


class Owner:
    """Honest owner: endpoint, salts, tree, and a use counter. The source owner
    is the uses = 1 case and is consumed by move; a spent owner refuses."""

    def __init__(self, layout, data, rng, oracle):
        self.layout, self.oracle, self.spent = layout, oracle, 0
        self.endpoint = Endpoint(layout, data, rng)
        self.salts = [rng.randbytes(32) for _ in range(layout.nn)]
        level = [salted_leaf(oracle, self.endpoint.column(j), s) for j, s in enumerate(self.salts)]
        self.levels = [level]
        while len(level) > 1:
            level = [oracle.query(level[i] + level[i + 1]) for i in range(0, len(level), 2)]
            self.levels.append(level)
        self.root = level[0]

    def open(self, ch):
        if self.spent >= self.layout.uses or ch.use != self.spent:
            raise Refusal("endpoint owner has no unspent use for this proof")
        self.spent += 1
        op = open_field(self.endpoint, ch)
        for j, _ in op.columns:
            op.salts[j] = self.salts[j]
            op.paths[j] = [self.levels[l][(j >> l) ^ 1] for l in range(self.layout.depth)]
        return op


def verify_opening(layout, oracle, root, op):
    problem = verify_field(layout, op)
    if problem:
        return problem
    for j, col in op.columns:
        if not verify_path(oracle, root, j, salted_leaf(oracle, col, op.salts[j]), op.paths[j]):
            return f"Merkle path for column {j}"
    return None


class FrontierSimulator:
    """Stateful simulator for ONE caller-fixed root, given the root's complete
    public history. It never receives endpoint data, masks, pads or unopened
    salts. Explicit assumptions are listed in the review memo, section 6.

    Hash layer: every node authenticated by the history is kept. A new position
    is served under its lowest already-authenticated ancestor N. Nothing below
    N is public, so the simulator builds its own subtree there with ordinary
    queries and programs exactly one point, children(N) -> N (or the salted
    leaf itself when N is a leaf). A node whose children are public is never
    programmed; repeated positions return the identical column, salt and path.

    Field layer: one virtual owner holding statement-valid dummy data is sampled
    from the fibre of all prior field observations and then answers like the
    honest owner, so prior and new vectors and columns are jointly consistent.

    Refusals: spent budget (the mirror of the consumed owner), a history that
    does not verify or is not explained by any owner with dummy data (a root
    already outside its zero-disclosure budget), and an already-answered
    programmed input.
    """

    def __init__(self, layout, oracle, root, history, dummy, rng):
        self.layout, self.oracle, self.root, self.rng = layout, oracle, root, rng
        self.nodes = {(layout.depth, 0): root}
        self.leaves = {}
        self.spent = len(history)
        for use, op in enumerate(history):
            if op.challenge.use != use or verify_opening(layout, oracle, root, op):
                raise Refusal("public history does not verify under this root")
            for j, col in op.columns:
                self._record_path(j, col, op.salts[j], op.paths[j])
        self.owner = sample_owner(layout, dummy, history, rng)
        if self.owner is None:
            raise Refusal("no owner with dummy data explains the public history")

    def _set(self, key, digest):
        if self.nodes.setdefault(key, digest) != digest:
            raise Refusal("conflicting authenticated nodes")

    def _record_path(self, j, col, salt, path):
        if self.leaves.setdefault(j, (col, salt)) != (col, salt):
            raise Refusal("conflicting openings of one position")
        cur, idx = salted_leaf(self.oracle, col, salt), j
        for level, sib in enumerate(path):
            self._set((level, idx), cur)
            self._set((level, idx ^ 1), sib)
            cur = self.oracle.query(cur + sib if idx & 1 == 0 else sib + cur)
            idx >>= 1

    def _serve(self, j):
        if j in self.leaves:
            return
        level, idx = 0, j
        while (level, idx) not in self.nodes:
            level, idx = level + 1, idx >> 1
        target = self.nodes[(level, idx)]
        if level == 0:
            col, salt = self.owner.column(j), self.rng.randbytes(32)
            self.oracle.program(self.oracle.query(column_bytes(col)) + salt, target)
            self.leaves[j] = (col, salt)
            return
        first = idx << level
        digests = []
        for leaf in range(first, first + (1 << level)):
            require(leaf not in self.leaves and (0, leaf) not in self.nodes, "public node below the frontier")
            col, salt = self.owner.column(leaf), self.rng.randbytes(32)
            self.leaves[leaf] = (col, salt)
            digests.append(salted_leaf(self.oracle, col, salt))
        for lower in range(level):
            for k, d in enumerate(digests):
                self.nodes[(lower, (first >> lower) + k)] = d
            if lower + 1 < level:
                digests = [self.oracle.query(digests[k] + digests[k + 1]) for k in range(0, len(digests), 2)]
        self.oracle.program(digests[0] + digests[1], target)

    def open(self, ch):
        if self.spent >= self.layout.uses or ch.use != self.spent:
            raise Refusal("endpoint root has no unspent use for this proof")
        self.spent += 1
        op = open_field(self.owner, ch)
        for j, col in op.columns:
            self._serve(j)
            require(self.leaves[j][0] == col, "virtual owner disagrees with an authenticated column")
            op.salts[j] = self.leaves[j][1]
            op.paths[j] = [self.nodes[(l, (j >> l) ^ 1)] for l in range(self.layout.depth)]
        return op

    def refusal_bound(self, prior_answers):
        """Union bound for the programmed-input refusal of the points programmed
        so far: each input contains a fresh 256-bit salt or digests of such."""
        return Fraction(len(self.oracle.programmed) * prior_answers, 1 << 256)


def naive_top_pair_opening(layout, oracle, root, dummy, ch, rng):
    """CONTROL: the delivered root-only idea applied regardless of history: a fresh
    tree whose top pair is programmed to the caller's root."""
    owner = Endpoint(layout, dummy, rng)
    salts = [rng.randbytes(32) for _ in range(layout.nn)]
    levels = [[salted_leaf(oracle, owner.column(j), s) for j, s in enumerate(salts)]]
    while len(levels[-1]) > 2:
        prev = levels[-1]
        levels.append([oracle.query(prev[i] + prev[i + 1]) for i in range(0, len(prev), 2)])
    oracle.program(levels[-1][0] + levels[-1][1], root)
    op = open_field(owner, ch)
    for j, _ in op.columns:
        op.salts[j] = salts[j]
        op.paths[j] = [levels[l][(j >> l) ^ 1] for l in range(layout.depth)]
    return op


def observed_preimages(layout, oracle, openings):
    """What an observer of public openings can exhibit: for every digest it has
    seen hashed, the set of distinct inputs it has seen hash to it."""
    seen = {}
    for op in openings:
        for j, col in op.columns:
            cur, idx = oracle.query(column_bytes(col)) + op.salts[j], j
            for sib in op.paths[j] + [None]:
                digest = oracle.query(cur)
                seen.setdefault(digest, set()).add(cur)
                if sib is None:
                    break
                cur = digest + sib if idx & 1 == 0 else sib + digest
                idx >>= 1
    return seen


def max_preimages(layout, oracle, openings):
    return max(len(v) for v in observed_preimages(layout, oracle, openings).values())


# ------------------------------------------------------------ the record ----

def synthetic_data(layout, rng):
    """int16-range words, as the endpoint's integer planes."""
    return [rng.randrange(-(1 << 15), 1 << 15) % P for _ in range(2 * layout.n)]


def full_geometry_demo(seed=20260918):
    rng = random.Random(seed)
    data = synthetic_data(SOURCE, rng)
    endpoint = Endpoint(SOURCE, data, rng)
    # The Rust owner cannot do this: into_ffn_endpoint(self) moves it into the one
    # finish(). The model reopens it to measure what a reusable root would publish.
    ops = [open_field(endpoint, draw_challenge(SOURCE, 0, rng)) for _ in range(2)]
    problems = [verify_field(SOURCE, op) for op in ops]
    recovered = recover_from_group_vectors(SOURCE, *ops)
    three = recover_pair_from_three_words(SOURCE, ops[0], ops[1], 0)
    while len({j for op in ops for j, _ in op.columns}) < SOURCE.width:
        ops.append(open_field(endpoint, draw_challenge(SOURCE, 0, rng)))
    by_columns = recover_from_columns(SOURCE, ops)
    challenges = [op.challenge for op in ops[:2]]
    return dict(
        geometry=dict(rows=SOURCE.rows, n=SOURCE.n, pads=SOURCE.q, encoded_columns=SOURCE.nn,
                      checks=SOURCE.checks, opening_bytes=SOURCE.opening_bytes()),
        openings_verify=[p is None for p in problems],
        group_vector_words_used=2 * SOURCE.n,
        recovered_words=sum(a == b for a, b in zip(recovered, data)),
        recovered_all=recovered == data,
        three_word_candidates=len(three),
        three_word_unique_and_correct=three == [(data[0], data[SOURCE.n])],
        column_only=dict(openings_needed=len(ops),
                         distinct_positions=len({j for op in ops for j, _ in op.columns}),
                         recovered_all=by_columns == data),
        per_coordinate_disclosed=dict(
            one_opening=per_coordinate_disclosure(SOURCE, challenges[:1]),
            two_openings=per_coordinate_disclosure(SOURCE, challenges),
            two_openings_group_only=per_coordinate_disclosure(SOURCE, challenges, ("group",))),
    )


def budget_table(seed=7):
    """Complete field system (vectors and columns) on the small geometry."""
    out = {}
    for name, layout, reopen in (("source_layout_uses1", SMALL_SOURCE, 3), ("budget_layout_uses2", SMALL_BUDGET2, 3)):
        rng = random.Random(seed)
        endpoint = Endpoint(layout, synthetic_data(layout, rng), rng)
        ops, row = [], {}
        for t in range(reopen):
            use = min(t, layout.uses - 1)          # past the budget a pair must be reused
            ops.append(open_field(endpoint, draw_challenge(layout, use, rng)))
            row[f"after_{t + 1}"] = dict(
                disclosed=disclosed_dimension(layout, ops),
                of=2 * layout.n,
                distinct_positions=len({j for op in ops for j, _ in op.columns}),
                within_budget=t < layout.uses)
        out[name] = dict(rows=layout.rows, pads=layout.q, width=layout.width, encoded=layout.nn, table=row)
    return out


def simulator_demo(seed=11):
    layout = SMALL_BUDGET2
    rng = random.Random(seed)
    oracle = Oracle(seed)
    data = synthetic_data(layout, rng)
    owner = Owner(layout, data, rng, oracle)
    first = owner.open(draw_challenge(layout, 0, rng))
    second_ch = draw_challenge(layout, 1, rng)
    dummy = [0] * (2 * layout.n)
    sim = FrontierSimulator(layout, oracle, owner.root, [first], dummy, rng)
    second = sim.open(second_ch)
    answers = len(oracle.table)
    try:
        sim.open(draw_challenge(layout, 1, rng))
        third = "answered"
    except Refusal as e:
        third = str(e)
    control_oracle = Oracle(seed + 1)
    control_owner = Owner(layout, data, random.Random(seed), control_oracle)
    control_first = control_owner.open(draw_challenge(layout, 0, random.Random(seed + 2)))
    control = naive_top_pair_opening(layout, control_oracle, control_owner.root, dummy,
                                     draw_challenge(layout, 1, random.Random(seed + 3)), random.Random(seed + 4))
    return dict(
        history_openings=1,
        simulated_verifies=verify_opening(layout, oracle, owner.root, second) is None,
        programmed_points=len(oracle.programmed),
        new_positions=len({j for j, _ in second.columns} - {j for j, _ in first.columns}),
        max_observed_preimages=max_preimages(layout, oracle, [first, second]),
        real_data_explains_joint_view=sample_owner(layout, data, [first, second], rng) is not None,
        joint_disclosed=disclosed_dimension(layout, [first, second]),
        third_use=third,
        refusal_bound_log2_per_prior_answer=-256,
        programmed_refusal_bound=str(sim.refusal_bound(answers)),
        control_top_pair_after_history=dict(
            verifies=verify_opening(layout, control_oracle, control_owner.root, control) is None,
            max_observed_preimages=max_preimages(layout, control_oracle, [control_first, control])),
    )


def cost_table():
    rows = {}
    for k in (1, 2, 3):
        layout = Layout(log_n=8, checks=256, uses=k, extra_rows=1 if k == 1 else 0)
        rows[f"uses_{k}"] = dict(rows=layout.rows, pads_per_row=layout.q, message_plus_pads=layout.width,
                                 encoded_columns=layout.nn, rate=str(Fraction(layout.width, layout.nn)),
                                 relative_distance=str(1 - Fraction(layout.width, layout.nn)),
                                 opening_bytes_per_use=layout.opening_bytes(),
                                 owner_field_words=layout.rows * layout.width)
    return rows


def run():
    pins = check_source_pins()
    return dict(
        schema="zk60-reusable-endpoint-probe/1",
        source_pins_ok=all(v["pinned"] and not v["missing_anchors"] for v in pins.values()),
        source_pins=pins,
        full_geometry=full_geometry_demo(),
        budget=budget_table(),
        simulator=simulator_demo(),
        costs=cost_table(),
        privacy_accepted=False,
        note="model evidence only; no native Rust executed; P1 unchanged",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, help="also write the JSON record here")
    args = parser.parse_args()
    text = json.dumps(run(), indent=2, sort_keys=True)
    if args.out:
        args.out.write_text(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
