"""P10, the commitment side: CONSTRUCT a fixed-witness preimage and exhibit it.

This module is the part of the block-scope privacy gate that the existing
joint-view tool does NOT do.  `zk60_native_jv_pcs` MEASURES the disclosed
dimension of one commitment; here we SOLVE, exactly over Fp, for prover
randomness that reproduces the captured view under a FIXED hidden input, and
then recompute the view from that randomness and compare it with the capture
entry by entry (ruling C-6: equal fibre dimension is not a pass, because the
fibre may be empty; the preimage must be exhibited).

THE LINEAR MODEL (the same one `zk60_native_jv_pcs` states, split in two).
One commitment holds `rows` committed rows; row i is z_i = (msg_i, pad_i) in
Fp^256 x Fp^256.  Write the unknown as X in Fp^{rows x 512} and split its
coordinates:

  d  (the DATA block)      msg_i[t] for i a data row           -- the hidden
                           input, output and activations
  r  (the BLINDING block)  msg_i[t] for i a non-data row, and
                           pad_i[k] for EVERY row              -- the prover's
                           mask rows, proximity rows and Q = 256 pads per row,
                           subject to the layout's public linear constraints
                           (H's zero-sum pair: the sum over the 256 message
                           positions is 0 on each of the two u rows)

The verifier's field-valued view of this commitment is y = M_data d +
M_nondata r with four kinds of entry, all of them in the capture:

  y1  the opening-group vectors, 512 Fp2 each  v_g[t] = sum_i rho_g[i] X[i][t]
  y2  the proximity vector, 512 Fp2            v_p[t] = sum_i rho_p[i] X[i][t]
  y3  every claim's value, Fp2                 val_c  = sum_i rw_c[i] <msg_i, cw_c>
  y4  the opened columns, d_cols x rows Fp     col_j[i] = <E_j, z_i>

`rho`, `rw`, `cw` and the sampled column indices are functions of the public
layout and of the challenges stage 1 replays; `E_j` is the coset-encoding
functional of `pcs.rs::encode_row_zk`.  Nothing about the prover's randomness
or the witness is read: the capture contains y, never d and never r.

HOW THE PREIMAGE IS BUILT (a triangular elimination -- no 178,432-unknown
Gaussian elimination anywhere, and every step is exact):

  1 msg, per opening group.  Under H-pair every claim owns one reserved mask
    pair that no other claim touches, so group g's only non-data support is
    the pairs of its own claims.  Put the whole per-position residual on one
    anchor pair (a 2x2 Fp system whose determinant the verifier itself
    refuses when zero), then correct, INSIDE the kernel of the per-position
    constraint, for (a) every claim's own published value and (b) the public
    zero-sum constraint on any u row of the group.  The correction space is
    parametrised exactly (see `_correction_positions`), so "no solution"
    means the channel has no preimage, not that the search was too narrow.
  2 msg, the proximity rows.  No claim touches them (H-pair), so they are
    solved last, per position, against the proximity vector.
  3 pads.  Writing the row's encoded polynomial as Enc_i = Msg_i + Z_n Pad_i,
    the opened columns fix Pad_i at the d distinct sampled nodes; Lagrange
    interpolation gives one solution I(p_i), and the whole fibre is
    I(p_i) + Z_S q_i with Z_S the vanishing polynomial of those nodes.  The
    pad half of every group vector then fixes sum_i rho_g[i] q_i -- which is
    a polynomial only when the residual is divisible by Z_S, i.e. exactly
    when the verifier's own column identity holds.  That divisibility is this
    channel's feasibility test, and it fires (see the gate's controls).

WHAT MAKES IT A GATE AND NOT A FIT: after the solve the view is recomputed
from (d_fixed, r') by the forward map above -- every group-vector entry,
every proximity entry, every claim value and every opened column value --
and compared with the capture.  One mismatch is a failure.

THE FIBRE DIMENSION is the same for every fixed input BY CONSTRUCTION: every
matrix solved here is built from rho, rw, cw and the sampled nodes alone, and
the fixed input enters the right-hand side only.  The gate asserts this
rather than observing it: `RoleLayout.matrix_digest` hashes those matrices and
the gate requires the two runs' digests to be equal.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

import hashlib
from operator import mul

from zk60_native_jv_capture import N_COLS
from zk60_native_jv_field import (
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_is_zero,
    f2_mul,
    f2_mul_base,
    f2_sub,
    inv,
    solve,
)
from zk60_native_jv_pcs import column_functional_parts, zkey_weights

MSG = N_COLS  # 256 message positions per row
PAD = N_COLS  # 256 pad symbols per row


# --------------------------------------------------------------- small solves
def solve_pair(a, b, target):
    """x, y in Fp with a*x + b*y = target, for a, b, target in Fp2, or None."""
    det = (a[0] * b[1] - a[1] * b[0]) % P
    if det == 0:
        return None
    di = inv(det)
    x = (target[0] * b[1] - target[1] * b[0]) % P * di % P
    y = (a[0] * target[1] - a[1] * target[0]) % P * di % P
    return x, y


def kernel_basis(rows, ncols):
    """A basis of {x : sum_k x[k] * rows[k][.] = 0}, i.e. of the kernel of the
    matrix whose ROWS are `rows` read as coefficient vectors over `ncols`
    unknowns.  Exact over Fp."""
    mat = [list(r) for r in rows]
    pivots, r = [], 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(mat)):
            if mat[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        mat[r], mat[piv] = mat[piv], mat[r]
        pinv = inv(mat[r][c])
        mat[r] = [x * pinv % P for x in mat[r]]
        for i in range(len(mat)):
            if i != r and mat[i][c] % P:
                f = mat[i][c]
                mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
        pivots.append(c)
        r += 1
        if r == len(mat):
            break
    out = []
    for fc in [c for c in range(ncols) if c not in pivots]:
        v = [0] * ncols
        v[fc] = 1
        for i, pc in enumerate(pivots):
            v[pc] = (-mat[i][fc]) % P
        out.append(v)
    return out


def poly_eval(coeffs, x):
    acc = 0
    for c in reversed(coeffs):
        acc = (acc * x + c) % P
    return acc


def poly_div_exact(num, den):
    """(quotient, remainder) of num / den over Fp, `den` monic of degree m."""
    m = len(den) - 1
    q = [0] * max(0, len(num) - m)
    r = list(num)
    for k in range(len(num) - 1, m - 1, -1):
        c = r[k]
        if c:
            q[k - m] = c
            for i in range(m + 1):
                r[k - m + i] = (r[k - m + i] - c * den[i]) % P
    return q, r[:m]


class Lagrange:
    """Interpolation through a fixed set of distinct nodes, built once."""

    def __init__(self, nodes):
        self.nodes = list(nodes)
        d = len(nodes)
        z = [1]
        for x in nodes:  # Z_S = prod (X - x_j), monic of degree d
            nz = [0] * (len(z) + 1)
            for i, c in enumerate(z):
                nz[i] = (nz[i] - c * x) % P
                nz[i + 1] = (nz[i + 1] + c) % P
            z = nz
        self.z = z
        self.basis_by_coeff = [[0] * d for _ in range(d)]
        for j, xj in enumerate(nodes):
            q = [0] * d  # Z_S / (X - x_j), by synthetic division
            acc = z[d]
            q[d - 1] = acc
            for k in range(d - 1, 0, -1):
                acc = (z[k] + acc * xj) % P
                q[k - 1] = acc
            sc = inv(poly_eval(q, xj))  # Z_S'(x_j) = q(x_j)
            for k in range(d):
                self.basis_by_coeff[k][j] = q[k] * sc % P

    def coeffs(self, values):
        """The degree < d interpolant of `values` at the nodes, as coefficients."""
        return [sum(map(mul, row, values)) % P for row in self.basis_by_coeff]


# ------------------------------------------------------------------- layout
class RoleLayout:
    """Everything about one commitment's view that does not depend on the witness."""

    def __init__(self, capture, view):
        self.cap = capture
        self.v = view
        self.name = view.name
        self.rows = view.rows
        self.role = view.role
        self.findings: list[str] = []

        self.data_rows = list(view.data_rows)
        self.u_rows = list(view.u_rows)
        kinds = {r["row"]: r["kind"] for r in view.role["row_roles"]}
        self.prox_rows = [r for r in range(self.rows) if kinds[r] == "prox"]
        self.rhos = view.rhos
        self.prox_rho = view.prox_rho
        self.rws = view.rws
        self.groups = view.groups
        self.cw = [zkey_weights(k) for k in view.keys]
        self.cw_re = [[x[0] for x in c] for c in self.cw]
        self.cw_im = [[x[1] for x in c] for c in self.cw]
        self.group_of_claim = {}
        for gi, mem in enumerate(self.groups):
            for c in mem:
                self.group_of_claim[c] = gi

        # the reserved pair of every claim (H-pair, as audit_claims defines it)
        other = set(range(self.rows)) - set(self.data_rows)
        self.claim_pair = {}
        for ci, rw in enumerate(self.rws):
            touched = sorted(r for r in other if rw[r] != F2_ZERO)
            rest = [r for r in touched if r not in self.u_rows]
            if not rest and self.u_rows and set(touched) == set(self.u_rows):
                self.claim_pair[ci] = tuple(sorted(self.u_rows))
            elif len(rest) == 2 and rest[1] == rest[0] + 1:
                self.claim_pair[ci] = (rest[0], rest[1])
            else:
                self.findings.append(f"{self.name}: claim {ci} has no single reserved pair")

        # the anchor pair of every group and the group's own non-data rows
        self.anchor, self.group_rows = [], []
        for gi, members in enumerate(self.groups):
            rows = sorted({r for c in members for r in self.claim_pair.get(c, ())})
            self.group_rows.append(rows)
            # Prefer a pair that is NOT the u pair: the u rows carry a public
            # linear constraint, so loading the whole per-position residual on
            # them would break that constraint whenever another pair could
            # have carried it.
            pick, fallback = None, None
            for c in members:
                p = self.claim_pair.get(c)
                if p is None:
                    continue
                a, b = self.rhos[gi][p[0]], self.rhos[gi][p[1]]
                if (a[0] * b[1] - a[1] * b[0]) % P == 0:
                    continue
                if set(p) & set(self.u_rows):
                    fallback = fallback or p
                    continue
                pick = p
                break
            pick = pick or fallback
            if pick is None:
                self.findings.append(f"{self.name}: group {gi} has no usable anchor pair")
            self.anchor.append(pick)

        # The order the groups are solved in.  A claim may EVALUATE a row that
        # belongs to another group -- the zsum slot reads H's u pair as well as
        # carrying its own reserved pair (`audit_claims` allows exactly that) --
        # so a group must be solved AFTER every group that owns a row its claims
        # read, or the earlier solve would be undone.
        owner = {}
        for gi, rows in enumerate(self.group_rows):
            for r in rows:
                owner[r] = gi
        need = []
        for gi, members in enumerate(self.groups):
            dep = set()
            for c in members:
                for r in range(self.rows):
                    if self.rws[c][r] != F2_ZERO and r in owner and owner[r] != gi:
                        dep.add(owner[r])
            need.append(dep)
        self.order, done = [], set()
        while len(self.order) < len(self.groups):
            progressed = False
            for gi in range(len(self.groups)):
                if gi in done or not need[gi] <= done:
                    continue
                self.order.append(gi)
                done.add(gi)
                progressed = True
            if not progressed:
                rest = [g for g in range(len(self.groups)) if g not in done]
                self.findings.append(
                    f"{self.name}: groups {rest} read each other's rows cyclically"
                )
                self.order.extend(rest)
                break
        self.cross_group_reads = {gi: sorted(d) for gi, d in enumerate(need) if d}

        # the sampled columns, deduplicated, with their encoding functionals
        self.col_index = [c["index"] for c in view.role["columns"]]
        self.nodes_j = sorted(set(self.col_index))
        self.emsg, self.epad, self.xj, self.znj = {}, {}, {}, {}
        for j in self.nodes_j:
            m, p, x, zn = column_functional_parts(j)
            self.emsg[j], self.epad[j], self.xj[j], self.znj[j] = m, p, x, zn
        self.colval, dup_bad = {}, 0
        for c in view.role["columns"]:
            j = c["index"]
            if j in self.colval:
                if self.colval[j] != c["values"]:
                    dup_bad += 1
            else:
                self.colval[j] = c["values"]
        if dup_bad:
            self.findings.append(
                f"{self.name}: {dup_bad} repeated column index served two different vectors"
            )
        self.lag = Lagrange([self.xj[j] for j in self.nodes_j])
        self.z_s = self.lag.z
        self.d = len(self.nodes_j)

        # the captured view
        self.gvec = [[f2_from_list(x) for x in g["vector"]] for g in view.role["groups"]]
        self.pvec = [f2_from_list(x) for x in view.role["proximity_vector"]]
        self.values = [f2_from_list(c["value"]) for c in view.role["claims"]]

        # per group: the kernel of the per-position constraint, and the
        # positions that make the correction space exactly expressive
        self.gkernel, self.gpos = [], []
        for gi in range(len(self.groups)):
            self.gkernel.append(self._group_kernel(gi))
            self.gpos.append(self._correction_positions(gi))

    def _group_kernel(self, gi):
        rows = self.group_rows[gi]
        rho = self.rhos[gi]
        m = len(rows)
        if m == 0:
            return []
        re = [rho[i][0] for i in rows]
        im = [rho[i][1] for i in rows]
        return kernel_basis([re, im], m)

    def _correction_positions(self, gi):
        """A maximal independent set of the columns (cw_re[t], cw_im[t], 1).

        The correction acts on the claim values only through <delta_i, cw>
        (an Fp2 value) and on a u row only through the row sum (an Fp value),
        so a correction supported on these <= 3 positions reaches EXACTLY the
        same (value, row-sum) pairs as one supported on all 256.  That is why
        "no solution" below is a statement about the channel and not about the
        parametrisation.
        """
        cw = self.cw[gi]
        chosen, basis = [], []
        for t in range(MSG):
            v = [cw[t][0], cw[t][1], 1]
            trial = basis + [v]
            if len(kernel_basis(list(map(list, zip(*trial))), len(trial))) == 0:
                basis, chosen = trial, chosen + [t]
            if len(chosen) == 3:
                break
        return chosen

    def matrix_digest(self):
        """A digest of every matrix the solver uses: witness-independent by
        construction, and therefore equal across fixed inputs."""
        h = hashlib.sha256()
        h.update(f"{self.name}|{self.rows}|{self.d}|{self.u_rows}".encode())
        for gi, rho in enumerate(self.rhos):
            h.update(b"g")
            for r in self.group_rows[gi]:
                h.update(f"{r}:{rho[r][0]}:{rho[r][1]}".encode())
            h.update(f"{self.anchor[gi]}|{self.gpos[gi]}|{self.gkernel[gi]}".encode())
            for c in self.groups[gi]:
                for r in self.claim_pair.get(c, ()):
                    h.update(f"c{c}:{r}:{self.rws[c][r]}".encode())
            for x in self.cw[gi]:
                h.update(f"{x[0]}:{x[1]}".encode())
        for r in self.prox_rows:
            h.update(f"p{r}:{self.prox_rho[r][0]}:{self.prox_rho[r][1]}".encode())
        for j in self.nodes_j:
            h.update(f"n{j}:{self.xj[j]}".encode())
        return h.hexdigest()


# ------------------------------------------------------------- the preimage
class RolePreimage:
    """One commitment's preimage of the captured view at a FIXED hidden input."""

    def __init__(self, layout, data, pad_width=PAD):
        """`data` maps a data row index to its 256 message values (Fp).

        `pad_width` exists ONLY for the rank-loss control: it is the number of
        pad symbols the commitment is modelled as having.  At the receipt's
        own budget (256 pads against d <= 256 distinct opened columns) every
        row's pad polynomial can meet the opened columns; below d it cannot,
        and the gate must then find no preimage.  An honest run passes 256.
        """
        self.L = layout
        self.pad_width = pad_width
        self.data = data
        self.fail: list[str] = []
        self.steps = []
        self.X = [[0] * (MSG + PAD) for _ in range(layout.rows)]
        for i in layout.data_rows:
            row = data.get(i)
            if row:
                self.X[i][:MSG] = [v % P for v in row]

    # ------------------------------------------------------------ msg block
    def _group_msg(self, gi):
        L = self.L
        rho, members, rows = L.rhos[gi], L.groups[gi], L.group_rows[gi]
        anchor = L.anchor[gi]
        if anchor is None:
            self.fail.append(f"{L.name}: group {gi} has no anchor pair")
            return
        # (1) a particular solution: the per-position residual on the anchor
        #     pair.  Every other row this combination reads is subtracted --
        #     the data rows, and any row an earlier group already fixed (the
        #     zsum slot's claim reads H's u pair, which group 8 owns).
        contributors = [
            i for i in range(L.rows) if rho[i] != F2_ZERO and i not in anchor
        ]
        for t in range(MSG):
            rhs = L.gvec[gi][t]
            for i in contributors:
                x = self.X[i][t]
                if x:
                    rhs = f2_sub(rhs, f2_mul_base(rho[i], x))
            xy = solve_pair(rho[anchor[0]], rho[anchor[1]], rhs)
            if xy is None:
                self.fail.append(f"{L.name}: group {gi} anchor pair is singular")
                return
            self.X[anchor[0]][t], self.X[anchor[1]][t] = xy
        # (2) the correction, inside the kernel of (1)
        ker, pos = L.gkernel[gi], L.gpos[gi]
        cwre, cwim, cw = L.cw_re[gi], L.cw_im[gi], L.cw[gi]
        u_here = [u for u in L.u_rows if u in rows]
        unknown = [(k, t) for k in range(len(ker)) for t in pos]
        cols = []
        for (k, t) in unknown:
            v = ker[k]
            col = []
            for c in members:  # the claim's own published value
                acc = F2_ZERO
                for a, i in enumerate(rows):
                    if v[a] and L.rws[c][i] != F2_ZERO:
                        acc = f2_add(acc, f2_mul_base(L.rws[c][i], v[a]))
                z = f2_mul(acc, cw[t])
                col.extend([z[0], z[1]])
            for u in u_here:  # the public zero-sum constraint
                col.append(v[rows.index(u)])
            cols.append(col)
        target = []
        for c in members:
            got = F2_ZERO
            for i in range(L.rows):
                w = L.rws[c][i]
                if w == F2_ZERO:
                    continue
                msg = self.X[i][:MSG]
                s = (sum(map(mul, msg, cwre)) % P, sum(map(mul, msg, cwim)) % P)
                got = f2_add(got, f2_mul(w, s))
            need = f2_sub(L.values[c], got)
            target.extend([need[0], need[1]])
        for u in u_here:
            target.append((-sum(self.X[u][:MSG])) % P)
        x, kr = solve(cols, target)
        rank_cu = len(cols) - len(kr)
        self.steps.append(
            {
                "step": f"msg:group{gi}",
                "kernel_dim_per_position": len(ker),
                "correction_unknowns": len(cols),
                "constraints": len(target),
                "constraint_rank": rank_cu,
                "free_fp": max(0, len(ker)) * MSG - rank_cu,
                "feasible": x is not None,
            }
        )
        if x is None:
            self.fail.append(
                f"{L.name}: group {gi} -- NO PREIMAGE: the published claim values "
                f"and the public row constraints cannot be met inside the kernel of "
                f"the group-vector constraint"
            )
            return
        for (k, t), c in zip(unknown, x):
            if c:
                v = ker[k]
                for a, i in enumerate(rows):
                    if v[a]:
                        self.X[i][t] = (self.X[i][t] + c * v[a]) % P

    def _prox_msg(self):
        L = self.L
        if len(L.prox_rows) < 2:
            self.fail.append(f"{L.name}: fewer than two proximity rows")
            return
        p0, p1 = L.prox_rows[0], L.prox_rows[1]
        rho = L.prox_rho
        others = [i for i in range(L.rows) if i not in (p0, p1) and rho[i] != F2_ZERO]
        for t in range(MSG):
            rhs = L.pvec[t]
            for i in others:
                x = self.X[i][t]
                if x:
                    rhs = f2_sub(rhs, f2_mul_base(rho[i], x))
            xy = solve_pair(rho[p0], rho[p1], rhs)
            if xy is None:
                self.fail.append(f"{L.name}: the proximity pair is singular")
                return
            self.X[p0][t], self.X[p1][t] = xy
        self.steps.append(
            {
                "step": "msg:prox",
                "correction_unknowns": 2 * MSG,
                "free_fp": (len(L.prox_rows) - 2) * MSG,
                "feasible": True,
            }
        )

    # ------------------------------------------------------------ pad block
    def _pads(self):
        L = self.L
        for i in range(L.rows):
            msg = self.X[i][:MSG]
            nz = any(msg)
            vals = []
            for j in L.nodes_j:
                mv = sum(map(mul, msg, L.emsg[j])) % P if nz else 0
                vals.append((L.colval[j][i] - mv) % P * inv(L.znj[j]) % P)
            co = L.lag.coeffs(vals)
            if self.pad_width < L.d and any(co[self.pad_width:]):
                self.fail.append(
                    f"{L.name}: row {i} -- NO PREIMAGE: {self.pad_width} pad symbols "
                    f"cannot meet {L.d} distinct opened columns (the interpolant of "
                    f"the required values has degree {max(k for k, c in enumerate(co) if c)})"
                )
                return
            self.X[i][MSG:] = co + [0] * (PAD - L.d)
        for gi in L.order:  # the same order as the msg block, for the same reason
            if self.fail:
                return
            self._pad_group(f"pad:group{gi}", L.rhos[gi], L.group_rows[gi],
                            L.anchor[gi], L.gvec[gi][MSG:])
        if not self.fail:
            self._pad_group("pad:prox", L.prox_rho, L.prox_rows,
                            tuple(L.prox_rows[:2]), L.pvec[MSG:])

    def _pad_group(self, name, rho, rows, anchor, target):
        L = self.L
        re = [target[k][0] for k in range(PAD)]
        im = [target[k][1] for k in range(PAD)]
        for i in range(L.rows):
            w = rho[i]
            if w == F2_ZERO:
                continue
            for k, c in enumerate(self.X[i][MSG:]):
                if c:
                    re[k] = (re[k] - w[0] * c) % P
                    im[k] = (im[k] - w[1] * c) % P
        qre, rre = poly_div_exact(re, L.z_s)
        qim, rim = poly_div_exact(im, L.z_s)
        free = max(0, len(rows) - 2) * (PAD - L.d)
        if any(rre) or any(rim):
            self.steps.append({"step": name, "feasible": False, "free_fp": free})
            self.fail.append(
                f"{L.name}: {name} -- NO PREIMAGE: the pad half of this combination "
                f"is not reachable from the opened columns (the residual is not "
                f"divisible by the sampled nodes' vanishing polynomial)"
            )
            return
        if anchor is None or len(anchor) < 2:
            if any(qre) or any(qim):
                self.fail.append(f"{L.name}: {name} -- no anchor pair for the residual")
            return
        a, b = rho[anchor[0]], rho[anchor[1]]
        for k in range(PAD - L.d):
            xy = solve_pair(a, b, (qre[k] if k < len(qre) else 0,
                                   qim[k] if k < len(qim) else 0))
            if xy is None:
                self.fail.append(f"{L.name}: {name} -- singular anchor pair")
                return
            for row, coef in zip(anchor, xy):
                if coef:
                    xr = self.X[row]
                    for e, zc in enumerate(L.z_s):
                        if zc:
                            xr[MSG + k + e] = (xr[MSG + k + e] + coef * zc) % P
        self.steps.append({"step": name, "feasible": True, "free_fp": free})

    # ------------------------------------------------------------------ run
    def build(self):
        for gi in self.L.order:
            if self.fail:
                break
            self._group_msg(gi)
        if not self.fail:
            self._prox_msg()
        if not self.fail:
            self._pads()
        return self

    # ---------------------------------------------------------- the witness
    def blinding_digest(self):
        """A sha256 of the EXHIBITED randomness r' (the blinding coordinates).

        The evidence file records this digest, not the values: the solve is
        deterministic, so the digest makes the exhibited object checkable
        across runs without printing 178,432 field elements.  These are
        solved values for a PUBLIC fixed input, not any prover's real
        randomness -- the captures contain none.
        """
        h = hashlib.sha256()
        data = set(self.L.data_rows)
        for i in range(self.L.rows):
            start = MSG if i in data else 0
            h.update(b"|")
            h.update(",".join(str(v) for v in self.X[i][start:]).encode())
        return h.hexdigest()

    # --------------------------------------------------------- verification
    def verify(self, columns="full"):
        """Recompute the whole view from (d_fixed, r') and compare entry by entry."""
        L = self.L
        out = {
            "group_vector_entries": 0, "group_vector_mismatches": 0,
            "proximity_entries": 0, "proximity_mismatches": 0,
            "claim_values": 0, "claim_value_mismatches": 0,
            "column_entries": 0, "column_mismatches": 0, "columns_verified": 0,
        }
        cols = [[self.X[i][t] for i in range(L.rows)] for t in range(MSG + PAD)]
        for gi, rho in enumerate(L.rhos):
            re = [v[0] for v in rho]
            im = [v[1] for v in rho]
            for t in range(MSG + PAD):
                got = (sum(map(mul, cols[t], re)) % P, sum(map(mul, cols[t], im)) % P)
                out["group_vector_entries"] += 1
                if got != L.gvec[gi][t]:
                    out["group_vector_mismatches"] += 1
        re = [v[0] for v in L.prox_rho]
        im = [v[1] for v in L.prox_rho]
        for t in range(MSG + PAD):
            got = (sum(map(mul, cols[t], re)) % P, sum(map(mul, cols[t], im)) % P)
            out["proximity_entries"] += 1
            if got != L.pvec[t]:
                out["proximity_mismatches"] += 1
        for ci, rw in enumerate(L.rws):
            gi = L.group_of_claim[ci]
            cwre, cwim = L.cw_re[gi], L.cw_im[gi]
            got = F2_ZERO
            for i in range(L.rows):
                if rw[i] == F2_ZERO:
                    continue
                msg = self.X[i][:MSG]
                s = (sum(map(mul, msg, cwre)) % P, sum(map(mul, msg, cwim)) % P)
                got = f2_add(got, f2_mul(rw[i], s))
            out["claim_values"] += 1
            if got != L.values[ci]:
                out["claim_value_mismatches"] += 1
        nodes = L.nodes_j if columns == "full" else L.nodes_j[: int(columns)]
        for j in nodes:
            e = L.emsg[j] + L.epad[j]
            want = L.colval[j]
            out["columns_verified"] += 1
            for i in range(L.rows):
                got = sum(map(mul, self.X[i], e)) % P
                out["column_entries"] += 1
                if got != want[i]:
                    out["column_mismatches"] += 1
        out["all_entries_equal"] = (
            out["group_vector_mismatches"] == 0
            and out["proximity_mismatches"] == 0
            and out["claim_value_mismatches"] == 0
            and out["column_mismatches"] == 0
        )
        return out

    # ------------------------------------------------------- fibre dimension
    def fibre_dimension(self):
        """dim {r : view(d_fixed, r) = y}, exactly, from the triangular solve.

          msg   per group, (pair rows - 2) * 256 minus the COMPUTED rank of the
                claim-value and u-row constraints on that kernel, plus the free
                proximity rows;
          pad   (rows - g) * (256 - d) with g = 2 (G + 1) the Fp generators:
                every row's pad keeps 256 - d free coefficients once the opened
                columns are met, and each of the g combinations consumes one
                per coefficient.

        The number does not depend on the fixed input: see the module header.
        """
        L = self.L
        msg_free = sum(s["free_fp"] for s in self.steps if s["step"].startswith("msg"))
        g = 2 * (len(L.rhos) + 1)
        pad_free = (L.rows - g) * (PAD - L.d)
        return {
            "blinding_unknowns": (L.rows - len(L.data_rows)) * MSG
            + L.rows * PAD - len(L.u_rows),
            "msg_block_fp": msg_free,
            "pad_block_fp": pad_free,
            "fibre_dimension_fp": msg_free + pad_free,
            "generators_fp": g,
            "distinct_opened_columns": L.d,
            "independent_of_the_fixed_input": True,
            "why": "every matrix solved is a function of rho, rw, cw and the sampled "
            "nodes only; the fixed input enters the right-hand side alone",
        }
