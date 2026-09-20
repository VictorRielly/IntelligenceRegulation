#!/usr/bin/env python3
"""U-3a evidence 1: the pad blocks are scaled Vandermonde / Cauchy matrices,
so hypothesis H-pad (and M-cols) holds for EVERY set of opened columns.

Nothing here reads a capture.  The only inputs are the protocol's fixed
parameters (Goldilocks p, log_cols 8, inv_rate 8, Q_PAD 256; the mask
commitment's 512 message positions, 4096 encoded positions, 256 pads) and
the coset generator 7.  That is the whole point: the claim under test is
that the pad block's full rank does not depend on the challenge-derived
column indices at all.

Checked here, exactly, over the integers mod p:

  A/H/endpoint commitments (zkp-core/src/pcs.rs::encode_row_zk)
    E_j[pad k] = (x_j^n - 1) * x_j^k,   x_j = 7 * w_2048^j,   n = 256
    (1) the 2048 nodes x_j are distinct and nonzero;
    (2) Z_n(x_j) = x_j^256 - 1 != 0 for all 2048 j;
    => every d <= 256 rows form diag(Z_n) * Vandermonde(x_j)_{k<256},
       which has rank d for any distinct nodes.  Verified numerically on
       several column sets including adversarial ones (consecutive,
       maximally spread, the birthday-collision case).

  M commitment (scripts/zk60_native_jv_cfs.py::m_pad_block_rank, which is
  the port of hashline/src/zk.rs's mask commitment)
    row j, pad position t:  z_j * m^-1 * w^t / (y_j - w^t)
    y_j = 7 * w_4096^j, w = w_512, m = 512, z_j = y_j^512 - 1
    (3) z_j != 0 for all 4096 j;
    (4) y_j != w^t for all j, t  (implied by (3), checked anyway);
    => the block is diag(z_j/m) * Cauchy(y_j, w^t) * diag(w^t), and a
       Cauchy matrix on distinct nodes is totally nonsingular, so any
       d <= 256 rows have rank d.  Verified numerically as above.
"""

P = (1 << 64) - (1 << 32) + 1
GEN = 7  # zkp-core/src/field.rs::NONRESIDUE, and the pcs coset generator


def two_adic_root(log_n: int) -> int:
    """A primitive 2^log_n-th root of unity in Fp (p - 1 = 2^32 * 3 * 5 * 17 * 257 * 65537)."""
    assert 0 <= log_n <= 32
    g = 7  # 7 is a generator of Fp*
    r = pow(g, (P - 1) >> 32, P)  # primitive 2^32-th root
    for _ in range(32 - log_n):
        r = r * r % P
    return r


def rank_mod_p(rows, ncols):
    mat = [list(r) for r in rows]
    piv, r = [], 0
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
        piv.append(c)
        r += 1
        if r == len(mat):
            break
    return r


# ------------------------------------------------------------ A / H / endpoints
LOG_COLS, INV_RATE = 8, 8
N_COLS = 1 << LOG_COLS          # 256 message positions per row
ENC_COLS = N_COLS * INV_RATE    # 2048 encoded positions
Q_PAD = 256

w_enc = two_adic_root(ENC_COLS.bit_length() - 1)
assert pow(w_enc, ENC_COLS, P) == 1 and pow(w_enc, ENC_COLS // 2, P) != 1

nodes, zs = [], []
for j in range(ENC_COLS):
    x = GEN * pow(w_enc, j, P) % P
    nodes.append(x)
    zs.append((pow(x, N_COLS, P) - 1) % P)

print("A / H / endpoint pad block  (E_j[pad k] = Z_n(x_j) x_j^k)")
print(f"  encoded positions nn           = {ENC_COLS}")
print(f"  distinct nodes x_j             = {len(set(nodes))}  (want {ENC_COLS})")
print(f"  nodes equal to zero            = {sum(1 for x in nodes if x == 0)}  (want 0)")
print(f"  j with Z_n(x_j) == 0           = {sum(1 for z in zs if z == 0)}  (want 0)")
print(f"  7^{ENC_COLS} mod p == 1?            = {pow(GEN, ENC_COLS, P) == 1}  "
      f"(if True the coset would meet the n-th roots of unity)")

# The structural reason, in one line: x_j^256 = 7^256 * w_8^j, so Z_n(x_j) = 0
# for some j iff 7^256 is an 8th root of unity iff 7^2048 = 1.
w8 = two_adic_root(3)
print(f"  7^256 * w_8^j == 1 for some j? = "
      f"{any(pow(GEN, N_COLS, P) * pow(w8, j, P) % P == 1 for j in range(8))}  (want False)")


def pad_rows(idx):
    out = []
    for j in idx:
        x, z = nodes[j], zs[j]
        row, xp = [], 1
        for _ in range(Q_PAD):
            row.append(z * xp % P)
            xp = xp * x % P
        out.append(row)
    return out


CASES = {
    "256 consecutive from 0": list(range(256)),
    "256 consecutive from 1792": list(range(1792, 2048)),
    "256 maximally spread (step 8)": list(range(0, 2048, 8)),
    "246 spread (the observed distinct count)": list(range(0, 2048, 8))[:246],
    "256 pseudo-random (LCG, no repeats)": None,
}
seen, x = [], 12345
while len(seen) < 256:
    x = (1103515245 * x + 12345) % 2048
    if x not in seen:
        seen.append(x)
CASES["256 pseudo-random (LCG, no repeats)"] = sorted(seen)

for name, idx in CASES.items():
    r = rank_mod_p(pad_rows(idx), Q_PAD)
    print(f"  rank of the pad block, {name:42s} = {r} / {len(idx)}  "
          f"{'OK' if r == len(idx) else 'FAIL'}")

# negative control: a repeated column index must LOSE a rank
dup = sorted(set(range(0, 2048, 8)))[:255]
r = rank_mod_p(pad_rows(dup + [dup[0]]), Q_PAD)
print(f"  negative control, one index repeated              = {r} / 256  "
      f"{'OK (rank drops, as it must)' if r == 255 else 'FAIL'}")

# ------------------------------------------------------------------------ M
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256
mm, dom = 1 << MASK_LOG_MSG, 1 << MASK_LOG_DOM
w_dom, w_msg = two_adic_root(MASK_LOG_DOM), two_adic_root(MASK_LOG_MSG)
minv = pow(mm, P - 2, P)

ys = [GEN * pow(w_dom, j, P) % P for j in range(dom)]
zsm = [(pow(y, mm, P) - 1) % P for y in ys]
msgnodes = {pow(w_msg, t, P) for t in range(mm)}

print()
print("M pad block  (Lagrange weights on the 256 pad positions)")
print(f"  encoded positions              = {dom}")
print(f"  distinct nodes y_j             = {len(set(ys))}  (want {dom})")
print(f"  j with Z(y_j) == 0             = {sum(1 for z in zsm if z == 0)}  (want 0)")
print(f"  y_j that collide with a message node = "
      f"{sum(1 for y in ys if y in msgnodes)}  (want 0)")
print(f"  7^{dom} mod p == 1?            = {pow(GEN, dom, P) == 1}  (want False)")


def m_pad_rows(idx):
    out = []
    for j in idx:
        y, z = ys[j], zsm[j]
        row = []
        for t in range(MASK_Q):
            wt = pow(w_msg, t, P)
            row.append(z * minv % P * wt % P * pow((y - wt) % P, P - 2, P) % P)
        out.append(row)
    return out


MCASES = {
    "256 consecutive from 0": list(range(256)),
    "256 spread (step 16)": list(range(0, 4096, 16)),
    "246 spread (the observed distinct count)": list(range(0, 4096, 16))[:246],
}
for name, idx in MCASES.items():
    r = rank_mod_p(m_pad_rows(idx), MASK_Q)
    print(f"  rank of the M pad block, {name:40s} = {r} / {len(idx)}  "
          f"{'OK' if r == len(idx) else 'FAIL'}")

print()
print("CONCLUSION.  H-pad and M-cols hold for every admissible set of opened")
print("columns, because the only inputs are node distinctness (automatic: the")
print("index map j -> 7 w^j is injective) and the nonvanishing of a fixed")
print("scalar per node (checked exhaustively above over the whole encoded")
print("domain).  NO union bound over column sets is needed, and no challenge")
print("enters.")
