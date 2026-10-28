"""The FULL zero-data preimage of one commitment's view at the RUN's shape --
`A` and `H` included, message half and pad half and opened columns.

WHAT ROUNDS 1-6 SAID, AND WHY.  `zk60_native_rg_preimage` constructs the
MESSAGE half of a commitment whose opening groups are all SINGLETONS (the
two external endpoints and every internal boundary).  It skipped `A` and
`H` -- "skipped, not faked" -- for two stated reasons:

  (1) their opening groups have SEVERAL members, so each claim's own
      published value is an extra constraint, and
  (2) the correction step that handles (1) lives in `zk60_native_pg_pcs`,
      whose `MSG == PAD == 256` (that module's lines 95-96) does not hold
      at the run's shape: here the message half is `n = 1,024` wide and the
      pad half `Q = 256`.

This module removes (2), and with it (1).  It is `zk60_native_pg_pcs`'s
construction with the two widths as INSTANCE DATA instead of module
constants, and with the two shape-dependent public functions -- the group
column weights `zkey_weights` and the column functional `E_j` -- taken from
the caller instead of from the toy profile's module scope.

NOT A SILENT FORK.  Every arithmetic primitive is IMPORTED from
`zk60_native_pg_pcs` and none is re-implemented here: `solve_pair`,
`kernel_basis`, `poly_div_exact`, `Lagrange` (with its `Z_S` and its
interpolation basis) and `poly_eval`.  What is re-derived is the two
CLASSES around them, because a class cannot be widened from outside and the
toy module is a hash-pinned record that this lane does not edit.
`DERIVED_FROM` below names, method by method, the toy method each one comes
from and the ONE thing that differs; `tests/test_zk60_native_run_gate_ahpreimage.py`
asserts the claim the hard way -- it runs THIS module on the TOY captures at
`msg_width == pad_width == 256` and requires the exhibited randomness digest,
the verification counts and the fibre dimension to equal
`zk60_native_pg_pcs`'s to the byte.

THE MODEL (`zk60_native_jv_pcs`'s, restated with the two widths apart).
One hiding commitment holds `rows` committed rows; row `i` is
`z_i = (msg_i, pad_i)` in `Fp^n x Fp^Q`.  Split the coordinates:

  d  DATA      `msg_i[t]` for `i` a data row -- the hidden activations
  r  BLINDING  `msg_i[t]` for `i` a non-data row (the claims' reserved mask
               pairs, the proximity pair, the zero-sum `u` pair) and
               `pad_i[k]` for EVERY row, subject to the layout's public
               linear constraints

The verifier's field-valued view is `y = M_data d + M_nondata r`:

  y1 each opening group's vector    `v_g[t] = sum_i rho_g[i] X[i][t]`, n+Q Fp2
  y2 the proximity vector           `v_p[t] = sum_i rho_p[i] X[i][t]`, n+Q Fp2
  y3 each claim's value             `val_c = sum_i rw_c[i] <msg_i, cw_c>`
  y4 each opened column             `col_j[i] = <E_j, z_i>`, distinct j x rows

THE SOLVE, in the order the system decomposes (no dense elimination over the
600+ rows appears anywhere, and every step is exact over `Fp`):

  1 msg, per opening group, in dependency order.  Under H-pair each claim
    owns one reserved pair no other claim touches, so a group's only
    non-data support is its own claims' pairs.  Put the whole per-position
    residual on ONE anchor pair (a 2x2 `Fp` system per position, whose
    determinant the verifier itself refuses when zero), then correct INSIDE
    the kernel of that constraint for (a) every claim's own published value
    and (b) the public zero-sum constraint on any `u` row.
  2 msg, the proximity pair, last: no claim touches it (H-pair).
  3 pads, per row: writing `Enc_i = Msg_i + Z_n Pad_i`, the opened columns
    fix `Pad_i` at the `d` distinct sampled nodes, and Lagrange
    interpolation through those nodes gives one solution; the fibre is
    `I(p_i) + Z_S q_i`, `deg q_i < Q - d`.
  4 the pad half of each group vector and of the proximity vector: fixes
    `sum_i rho[i] q_i`, which is a polynomial ONLY when the residual is
    divisible by `Z_S` -- exactly when the verifier's own sampled-column
    identity holds.  That divisibility is the channel's feasibility test.

WHY THE ALL-ZERO HIDDEN INPUT NEEDS NO WITNESS.  `d = 0` is a public object:
the data block is set to zero and nothing is read from any capture but its
PUBLISHED fields.  A capture carries no witness and this module opens none.

WHAT MAKES IT A GATE AND NOT A FIT.  After the solve the view is RECOMPUTED
from `(0, r')` by the forward map -- every group-vector entry, every
proximity entry, every claim value, every opened column entry -- and
compared with the capture.  One mismatch is a failure.  The opened columns
are then re-hashed under the bundle's own rule and the salted leaves
re-authenticated against the published salts and paths.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

import hashlib
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from operator import mul  # noqa: E402

from zk60_native_jv_field import (  # noqa: E402
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_mul_base,
    f2_sub,
    inv,
    solve,
)
from zk60_native_pg_pcs import (  # noqa: E402  -- imported, never re-implemented
    Lagrange,
    kernel_basis,
    poly_div_exact,
    poly_eval,
    solve_pair,
)
from zk60_native_rg_hashlayer import column_bytes  # noqa: E402

__all__ = [
    "DERIVED_FROM",
    "WideRoleLayout",
    "WideRolePreimage",
    "full_preimages",
    "preimage_for_view",
]

# Every primitive that is IMPORTED rather than written again, with the line
# of `zk60_native_pg_pcs` it lives on.  A test asserts each name resolves to
# that module.
IMPORTED_PRIMITIVES = {
    "solve_pair": "zk60_native_pg_pcs.solve_pair (2x2 over Fp2, refused on a zero determinant)",
    "kernel_basis": "zk60_native_pg_pcs.kernel_basis",
    "poly_div_exact": "zk60_native_pg_pcs.poly_div_exact",
    "Lagrange": "zk60_native_pg_pcs.Lagrange (Z_S and the interpolation basis)",
    "poly_eval": "zk60_native_pg_pcs.poly_eval",
}

# Method by method, what this module re-derives and the ONE thing that
# differs.  The equivalence test is the real evidence; this is the map.
DERIVED_FROM = {
    "WideRoleLayout.__init__": (
        "zk60_native_pg_pcs.RoleLayout.__init__ -- identical, except that the "
        "message width, the pad width, the group column weights and the column "
        "functional come from the caller instead of the toy module's MSG / PAD "
        "constants and its own zkey_weights / column_functional_parts"
    ),
    "WideRoleLayout._group_kernel": "RoleLayout._group_kernel -- identical",
    "WideRoleLayout._correction_positions": (
        "RoleLayout._correction_positions -- identical, with `range(MSG)` the "
        "run's `n` rather than 256"
    ),
    "WideRoleLayout.matrix_digest": (
        "RoleLayout.matrix_digest -- identical (it hashes rho, the pairs, the "
        "anchors, the kernels, cw and the nodes; none of which is a width)"
    ),
    "WideRolePreimage._group_msg": (
        "RolePreimage._group_msg -- the same two steps; the per-position loop "
        "runs over `n` positions, and the residual accumulation is done column "
        "by column over the rows whose message block is currently nonzero "
        "(an exact re-association of the same sum: a zero row contributes zero)"
    ),
    "WideRolePreimage._prox_msg": "RolePreimage._prox_msg -- the same, over `n` positions",
    "WideRolePreimage._pads": (
        "RolePreimage._pads -- the same interpolation; the message inner product "
        "runs over `n` entries and the pad row is padded to `Q`, which at the toy "
        "were one number"
    ),
    "WideRolePreimage._pad_group": (
        "RolePreimage._pad_group -- the same Z_S division and anchor absorption, "
        "over `Q` pad coefficients (`deg q < Q - d`)"
    ),
    "WideRolePreimage.verify": (
        "RolePreimage.verify -- the same four comparisons; the column pass splits "
        "the msg and pad halves because they now have different lengths, and the "
        "hash arm below is NEW (the toy gate has no Merkle layer)"
    ),
    "WideRolePreimage.build": (
        "RolePreimage.build -- the same three phases in the same order, with a "
        "wall clock per phase recorded"
    ),
    "WideRolePreimage.blinding_digest": "RolePreimage.blinding_digest -- identical",
    "WideRolePreimage.fibre_dimension": (
        "RolePreimage.fibre_dimension -- identical, with `MSG` and `PAD` apart: "
        "the pad term is `(rows - 2(G+1)) * (Q - d)`"
    ),
}

# Methods with NO toy counterpart, named so that the map above is a complete
# account of this module and not only of its overlaps.
NEW_HERE = {
    "WideRoleLayout.dimensions": "the system's own dimensions, for the report",
    "WideRolePreimage._nonzero_msg_rows": "the rows whose message block is not "
    "all zero, so a zero row's contribution is dropped from a sum it adds "
    "nothing to",
    "WideRolePreimage._combination_msg": "the same accumulation the toy does "
    "position by position, done column by column -- an exact re-association, "
    "which is what makes `A`'s 36 groups over 1,024 positions cheap",
    "WideRolePreimage._inner_products": "`<msg_i, cw>` per nonzero row, cached "
    "for the claim-value targets",
    "WideRolePreimage._hash_layer": "NEW: the rebuilt columns re-hashed under "
    "the bundle's own rule and their salted leaves re-authenticated against "
    "the PUBLISHED salts and paths.  The toy gate has no Merkle layer",
}


# --------------------------------------------------------------- the layout
class WideRoleLayout:
    """Everything about one commitment's view that does not depend on the
    witness, at a shape whose message and pad widths may differ."""

    def __init__(self, view, *, msg_width, pad_width, zkey, colfun, name=None):
        """`zkey(key) -> cw` and `colfun(j, pad_width) -> (msg, pad, x_j, Z_n(x_j))`
        are the two PUBLIC functions of the profile's own geometry."""
        self.v = view
        self.name = name or view.name
        self.rows = view.rows
        self.role = view.role
        self.m = msg_width
        self.q = pad_width
        self.findings: list[str] = []

        self.data_rows = list(view.data_rows)
        self.u_rows = list(view.u_rows)
        kinds = {r["row"]: r["kind"] for r in view.role["row_roles"]}
        self.prox_rows = [r for r in range(self.rows) if kinds[r] == "prox"]
        self.rhos = view.rhos
        self.prox_rho = view.prox_rho
        self.rws = view.rws
        self.groups = view.groups
        self.cw = [zkey(k) for k in view.keys]
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

        # the anchor pair of every group, and the group's own non-data rows
        self.anchor, self.group_rows = [], []
        for gi, members in enumerate(self.groups):
            rws_rows = sorted({r for c in members for r in self.claim_pair.get(c, ())})
            self.group_rows.append(rws_rows)
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

        # the order the groups are solved in: a group must come AFTER every
        # group that owns a row its claims READ (H's zsum slot reads the u
        # pair another group owns)
        owner = {}
        for gi, rws_rows in enumerate(self.group_rows):
            for r in rws_rows:
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
        self.emsg, self.epad, self.xj, self.znj, self.zninv = {}, {}, {}, {}, {}
        for j in self.nodes_j:
            mm, pp, x, zn = colfun(j, self.q)
            self.emsg[j], self.epad[j], self.xj[j], self.znj[j] = mm, pp, x, zn
            self.zninv[j] = inv(zn) if zn else 0
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
        if self.d > self.q:
            self.findings.append(
                f"{self.name}: {self.d} distinct opened columns exceed the {self.q} pads"
            )

        # the captured view
        self.gvec = [[f2_from_list(x) for x in g["vector"]] for g in view.role["groups"]]
        self.pvec = [f2_from_list(x) for x in view.role["proximity_vector"]]
        self.values = [f2_from_list(c["value"]) for c in view.role["claims"]]

        self.gkernel, self.gpos = [], []
        for gi in range(len(self.groups)):
            self.gkernel.append(self._group_kernel(gi))
            self.gpos.append(self._correction_positions(gi))

    # ---- RoleLayout._group_kernel, unchanged
    def _group_kernel(self, gi):
        rows = self.group_rows[gi]
        rho = self.rhos[gi]
        if not rows:
            return []
        re = [rho[i][0] for i in rows]
        im = [rho[i][1] for i in rows]
        return kernel_basis([re, im], len(rows))

    # ---- RoleLayout._correction_positions, with `n` for 256
    def _correction_positions(self, gi):
        """A maximal independent set of the columns `(cw_re[t], cw_im[t], 1)`.

        The correction acts on the claim values only through `<delta_i, cw>`
        and on a `u` row only through the row sum, so a correction supported
        on these <= 3 positions reaches EXACTLY the same (value, row-sum)
        pairs as one supported on all `n`.  That is why "no solution" is a
        statement about the channel and not about the parametrisation.
        """
        cw = self.cw[gi]
        chosen, basis = [], []
        for t in range(self.m):
            v = [cw[t][0], cw[t][1], 1]
            trial = basis + [v]
            if len(kernel_basis(list(map(list, zip(*trial))), len(trial))) == 0:
                basis, chosen = trial, chosen + [t]
            if len(chosen) == 3:
                break
        return chosen

    # ---- RoleLayout.matrix_digest, unchanged
    def matrix_digest(self):
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

    def dimensions(self):
        """The system's own dimensions, for the report."""
        pairs = sorted({p for p in self.claim_pair.values()})
        return {
            "commitment": self.name,
            "rows": self.rows,
            "data_rows": len(self.data_rows),
            "non_data_rows": self.rows - len(self.data_rows),
            "message_positions_n": self.m,
            "pad_symbols_Q": self.q,
            "opened_columns": len(self.col_index),
            "distinct_opened_columns_d": self.d,
            "groups": len(self.groups),
            "claims": len(self.rws),
            "generators_2_G_plus_1": 2 * (len(self.rhos) + 1),
            "reserved_pairs": len(pairs),
            "u_rows": list(self.u_rows),
            "proximity_rows": list(self.prox_rows),
            "unknowns_msg_block_fp": (self.rows - len(self.data_rows)) * self.m,
            "unknowns_pad_block_fp": self.rows * self.q,
            "unknowns_total_fp": (self.rows - len(self.data_rows)) * self.m
            + self.rows * self.q
            - len(self.u_rows),
            "equations_group_vectors_fp": 2 * len(self.rhos) * (self.m + self.q),
            "equations_proximity_fp": 2 * (self.m + self.q),
            "equations_claim_values_fp": 2 * len(self.rws),
            "equations_opened_columns_fp": self.d * self.rows,
            "equations_public_zero_sum_fp": len(self.u_rows),
            "equations_total_fp": 2 * (len(self.rhos) + 1) * (self.m + self.q)
            + 2 * len(self.rws)
            + self.d * self.rows
            + len(self.u_rows),
            "groups_reading_another_groups_rows": self.cross_group_reads,
            "solve_order": list(self.order),
            "matrix_digest": self.matrix_digest(),
            "findings": list(self.findings),
        }


# ------------------------------------------------------------- the preimage
class WideRolePreimage:
    """One commitment's preimage of the captured view at a FIXED hidden input."""

    def __init__(self, layout, data=None, pad_width=None):
        """`data` maps a data row index to its `n` message values (`Fp`).
        The all-zero hidden input is `data = None`.

        `pad_width` exists ONLY for the rank-loss control: it is the number
        of pad symbols the commitment is MODELLED as having.  At the
        receipt's own budget every row's pad polynomial can meet the opened
        columns; below `d` it cannot, and the gate must then find no
        preimage.
        """
        self.L = layout
        self.pad_budget = layout.q if pad_width is None else pad_width
        self.data = data or {}
        self.fail: list[str] = []
        self.steps: list[dict] = []
        m, q = layout.m, layout.q
        self.X = [[0] * (m + q) for _ in range(layout.rows)]
        for i in layout.data_rows:
            row = self.data.get(i)
            if row:
                self.X[i][:m] = [v % P for v in row]

    # ------------------------------------------------------------ helpers
    def _nonzero_msg_rows(self):
        m = self.L.m
        return [i for i in range(self.L.rows) if any(self.X[i][:m])]

    def _combination_msg(self, rho, skip):
        """`sum_i rho[i] X[i][t]` over the message positions, as two `Fp`
        lists.  Rows in `skip` are left out; a row whose message block is
        zero contributes zero and is dropped -- an exact re-association."""
        m = self.L.m
        acc_re = [0] * m
        acc_im = [0] * m
        for i in range(self.L.rows):
            if i in skip or rho[i] == F2_ZERO:
                continue
            xi = self.X[i][:m]
            if not any(xi):
                continue
            w0, w1 = rho[i]
            if w0:
                acc_re = [(a + w0 * x) % P for a, x in zip(acc_re, xi)]
            if w1:
                acc_im = [(a + w1 * x) % P for a, x in zip(acc_im, xi)]
        return acc_re, acc_im

    # ------------------------------------------------------------ msg block
    def _group_msg(self, gi):
        L = self.L
        m = L.m
        rho, members, rows = L.rhos[gi], L.groups[gi], L.group_rows[gi]
        anchor = L.anchor[gi]
        if anchor is None:
            self.fail.append(f"{L.name}: group {gi} has no anchor pair")
            return
        # (1) a particular solution: the per-position residual on the anchor pair
        acc_re, acc_im = self._combination_msg(rho, set(anchor))
        a, b = rho[anchor[0]], rho[anchor[1]]
        xa, xb = self.X[anchor[0]], self.X[anchor[1]]
        gv = L.gvec[gi]
        for t in range(m):
            rhs = (
                (gv[t][0] - acc_re[t]) % P,
                (gv[t][1] - acc_im[t]) % P,
            )
            xy = solve_pair(a, b, rhs)
            if xy is None:
                self.fail.append(f"{L.name}: group {gi} anchor pair is singular")
                return
            xa[t], xb[t] = xy
        # (2) the correction, inside the kernel of (1)
        ker, pos = L.gkernel[gi], L.gpos[gi]
        cw = L.cw[gi]
        u_here = [u for u in L.u_rows if u in rows]
        unknown = [(k, t) for k in range(len(ker)) for t in pos]
        cols = []
        for (k, t) in unknown:
            v = ker[k]
            col = []
            for c in members:  # the claim's own published value
                acc = F2_ZERO
                for aa, i in enumerate(rows):
                    if v[aa] and L.rws[c][i] != F2_ZERO:
                        acc = f2_add(acc, f2_mul_base(L.rws[c][i], v[aa]))
                z = f2_mul(acc, cw[t])
                col.extend([z[0], z[1]])
            for u in u_here:  # the public zero-sum constraint
                col.append(v[rows.index(u)])
            cols.append(col)
        target = []
        inner = self._inner_products(gi)
        for c in members:
            got = F2_ZERO
            for i in range(L.rows):
                w = L.rws[c][i]
                if w == F2_ZERO:
                    continue
                s = inner.get(i)
                if s is None:
                    continue
                got = f2_add(got, f2_mul(w, s))
            need = f2_sub(L.values[c], got)
            target.extend([need[0], need[1]])
        for u in u_here:
            target.append((-sum(self.X[u][:m])) % P)
        x, kr = solve(cols, target)
        rank_cu = len(cols) - len(kr)
        self.steps.append(
            {
                "step": f"msg:group{gi}",
                "kernel_dim_per_position": len(ker),
                "correction_unknowns": len(cols),
                "constraints": len(target),
                "constraint_rank": rank_cu,
                "free_fp": max(0, len(ker)) * m - rank_cu,
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
                for aa, i in enumerate(rows):
                    if v[aa]:
                        self.X[i][t] = (self.X[i][t] + c * v[aa]) % P

    def _inner_products(self, gi):
        """`<msg_i, cw_gi>` for every row whose message block is nonzero.

        A zero row contributes `(0, 0)` to every claim value, so leaving it
        out is an exact re-association of the same sum -- not an
        approximation and not a shortcut past a constraint.
        """
        L = self.L
        cwre, cwim = L.cw_re[gi], L.cw_im[gi]
        m = L.m
        out = {}
        for i in self._nonzero_msg_rows():
            msg = self.X[i][:m]
            out[i] = (sum(map(mul, msg, cwre)) % P, sum(map(mul, msg, cwim)) % P)
        return out

    def _prox_msg(self):
        L = self.L
        m = L.m
        if len(L.prox_rows) < 2:
            self.fail.append(f"{L.name}: fewer than two proximity rows")
            return
        p0, p1 = L.prox_rows[0], L.prox_rows[1]
        rho = L.prox_rho
        acc_re, acc_im = self._combination_msg(rho, {p0, p1})
        a, b = rho[p0], rho[p1]
        x0, x1 = self.X[p0], self.X[p1]
        for t in range(m):
            rhs = ((L.pvec[t][0] - acc_re[t]) % P, (L.pvec[t][1] - acc_im[t]) % P)
            xy = solve_pair(a, b, rhs)
            if xy is None:
                self.fail.append(f"{L.name}: the proximity pair is singular")
                return
            x0[t], x1[t] = xy
        self.steps.append(
            {
                "step": "msg:prox",
                "correction_unknowns": 2 * m,
                "free_fp": (len(L.prox_rows) - 2) * m,
                "feasible": True,
            }
        )

    # ------------------------------------------------------------ pad block
    def _pads(self):
        L = self.L
        m, q = L.m, L.q
        for i in range(L.rows):
            msg = self.X[i][:m]
            nz = any(msg)
            cvals = []
            for j in L.nodes_j:
                mv = sum(map(mul, msg, L.emsg[j])) % P if nz else 0
                cvals.append((L.colval[j][i] - mv) % P * L.zninv[j] % P)
            co = L.lag.coeffs(cvals)
            if self.pad_budget < L.d and any(co[self.pad_budget:]):
                self.fail.append(
                    f"{L.name}: row {i} -- NO PREIMAGE: {self.pad_budget} pad symbols "
                    f"cannot meet {L.d} distinct opened columns (the interpolant of "
                    f"the required values has degree {max(k for k, c in enumerate(co) if c)})"
                )
                return
            self.X[i][m:] = co + [0] * (q - L.d)
        for gi in L.order:  # the same order as the msg block, for the same reason
            if self.fail:
                return
            self._pad_group(f"pad:group{gi}", L.rhos[gi], L.group_rows[gi],
                            L.anchor[gi], L.gvec[gi][m:])
        if not self.fail:
            self._pad_group("pad:prox", L.prox_rho, L.prox_rows,
                            tuple(L.prox_rows[:2]), L.pvec[m:])

    def _pad_group(self, name, rho, rows, anchor, target):
        L = self.L
        m, q = L.m, L.q
        re = [target[k][0] for k in range(q)]
        im = [target[k][1] for k in range(q)]
        for i in range(L.rows):
            w = rho[i]
            if w == F2_ZERO:
                continue
            pad = self.X[i][m:]
            if not any(pad):
                continue
            w0, w1 = w
            if w0:
                re = [(r - w0 * c) % P for r, c in zip(re, pad)]
            if w1:
                im = [(r - w1 * c) % P for r, c in zip(im, pad)]
        qre, rre = poly_div_exact(re, L.z_s)
        qim, rim = poly_div_exact(im, L.z_s)
        free = max(0, len(rows) - 2) * (q - L.d)
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
        for k in range(q - L.d):
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
                            xr[m + k + e] = (xr[m + k + e] + coef * zc) % P
        self.steps.append({"step": name, "feasible": True, "free_fp": free})

    # ------------------------------------------------------------------ run
    def build(self):
        t0 = time.time()
        for gi in self.L.order:
            if self.fail:
                break
            self._group_msg(gi)
        t1 = time.time()
        if not self.fail:
            self._prox_msg()
        t2 = time.time()
        if not self.fail:
            self._pads()
        self.timing = {
            "msg_groups_seconds": round(t1 - t0, 2),
            "msg_proximity_seconds": round(t2 - t1, 2),
            "pads_seconds": round(time.time() - t2, 2),
            "solve_seconds": round(time.time() - t0, 2),
        }
        return self

    # ---------------------------------------------------------- the witness
    def blinding_digest(self):
        """A sha256 of the EXHIBITED randomness `r'`.

        The record keeps this digest, not the values: the solve is
        deterministic, so the digest makes the exhibited object checkable
        across runs without printing hundreds of thousands of field
        elements.  These are SOLVED values for a PUBLIC fixed input, not any
        prover's real randomness -- the captures contain none.
        """
        h = hashlib.sha256()
        data = set(self.L.data_rows)
        for i in range(self.L.rows):
            start = self.L.m if i in data else 0
            h.update(b"|")
            h.update(",".join(str(v) for v in self.X[i][start:]).encode())
        return h.hexdigest()

    # --------------------------------------------------------- verification
    def verify(self, hash_rule=None, root=None):
        """Recompute the whole view from `(d_fixed, r')` and compare it with
        the capture entry by entry."""
        L = self.L
        m, q = L.m, L.q
        t0 = time.time()
        out = {
            "group_vector_entries": 0, "group_vector_mismatches": 0,
            "proximity_entries": 0, "proximity_mismatches": 0,
            "claim_values": 0, "claim_value_mismatches": 0,
            "column_entries": 0, "column_mismatches": 0, "columns_verified": 0,
            "first_mismatch": None,
        }

        def note(kind, where):
            if out["first_mismatch"] is None:
                out["first_mismatch"] = {"kind": kind, "where": where}

        cols = list(zip(*self.X))  # position -> the whole committed column
        for gi, rho in enumerate(L.rhos):
            re = [v[0] for v in rho]
            im = [v[1] for v in rho]
            gv = L.gvec[gi]
            for t in range(m + q):
                ct = cols[t]
                got = (sum(map(mul, ct, re)) % P, sum(map(mul, ct, im)) % P)
                out["group_vector_entries"] += 1
                if got != gv[t]:
                    out["group_vector_mismatches"] += 1
                    note("group vector", {"group": gi, "position": t})
        re = [v[0] for v in L.prox_rho]
        im = [v[1] for v in L.prox_rho]
        for t in range(m + q):
            ct = cols[t]
            got = (sum(map(mul, ct, re)) % P, sum(map(mul, ct, im)) % P)
            out["proximity_entries"] += 1
            if got != L.pvec[t]:
                out["proximity_mismatches"] += 1
                note("proximity vector", {"position": t})
        del cols
        inner = {}
        for ci, rw in enumerate(L.rws):
            gi = L.group_of_claim[ci]
            cwre, cwim = L.cw_re[gi], L.cw_im[gi]
            got = F2_ZERO
            for i in range(L.rows):
                if rw[i] == F2_ZERO:
                    continue
                key = (gi, i)
                s = inner.get(key)
                if s is None:
                    msg = self.X[i][:m]
                    s = (0, 0) if not any(msg) else (
                        sum(map(mul, msg, cwre)) % P,
                        sum(map(mul, msg, cwim)) % P,
                    )
                    inner[key] = s
                if s != (0, 0):
                    got = f2_add(got, f2_mul(rw[i], s))
            out["claim_values"] += 1
            if got != L.values[ci]:
                out["claim_value_mismatches"] += 1
                note("claim value", {"claim": ci})
        t1 = time.time()
        # the opened columns: re-encode every row and read the sampled position
        recomputed = {}
        for j in L.nodes_j:
            emsg, epad = L.emsg[j], L.epad[j]
            want = L.colval[j]
            col = []
            out["columns_verified"] += 1
            for i in range(L.rows):
                xi = self.X[i]
                msg = xi[:m]
                got = sum(map(mul, xi[m:], epad))
                if any(msg):
                    got += sum(map(mul, msg, emsg))
                got %= P
                col.append(got)
                out["column_entries"] += 1
                if got != want[i]:
                    out["column_mismatches"] += 1
                    note("opened column", {"column_index": j, "row": i})
            recomputed[j] = col
        t2 = time.time()
        out["all_entries_equal"] = (
            out["group_vector_mismatches"] == 0
            and out["proximity_mismatches"] == 0
            and out["claim_value_mismatches"] == 0
            and out["column_mismatches"] == 0
        )
        out["entries_compared"] = (
            out["group_vector_entries"]
            + out["proximity_entries"]
            + out["claim_values"]
            + out["column_entries"]
        )
        out["seconds_vectors_and_claims"] = round(t1 - t0, 2)
        out["seconds_opened_columns"] = round(t2 - t1, 2)
        out["hash_layer"] = self._hash_layer(recomputed, hash_rule, root)
        out["channels_verified"] = [
            "every opening group's vector, message half AND pad half",
            "the proximity vector, both halves",
            "every claim value",
            "every opened column, every row",
        ]
        out["channels_not_verified"] = [
            "the UNOPENED leaves of the Merkle tree: they are hidden behind their "
            "salts, so nothing can reproduce them from a preimage -- their hiding "
            "is assumption M-2 / M-3 and stays ARGUED",
            "the masking commitment M's own rows (the CFS channel)",
        ]
        return out

    def _hash_layer(self, recomputed, rule, root):
        """The reconstructed columns re-hashed and re-authenticated.

        Every opened column of the capture (256 with replacement) is rebuilt
        from the preimage, hashed under the bundle's own rule, salted with
        the PUBLISHED salt and folded along the PUBLISHED path.  Reaching
        the committed root means the construction reproduces the receipt's
        BYTES for the opened columns, not only its field values.
        """
        if rule is None or root is None:
            return {
                "checked": False,
                "why": "no hash rule or root was supplied (the equivalence run "
                "against the toy gate has no Merkle layer)",
            }
        out = {
            "checked": True,
            "rule": rule.name,
            "columns_rehashed": 0,
            "leaf_digests_equal_to_the_capture_s": 0,
            "salted_leaves_authenticated": 0,
            "failures": [],
            "unopened_leaves": "NOT reproducible from any preimage: an unopened "
            "leaf is a salted digest and nothing about it is published.  Its "
            "hiding is M-2 / M-3 and stays ARGUED",
        }
        rootb = bytes(root)
        for c in self.L.v.role["columns"]:
            j = c["index"]
            vals = recomputed.get(j)
            if vals is None:
                continue
            out["columns_rehashed"] += 1
            if vals == list(c["values"]):
                out["leaf_digests_equal_to_the_capture_s"] += 1
            leaf = rule.column_digest(column_bytes(vals))
            salted = rule.salt_leaf(leaf, bytes(c["salt"]))
            if rule.verify_path(rootb, j, salted, [bytes(x) for x in c["path"]]):
                out["salted_leaves_authenticated"] += 1
            else:
                out["failures"].append(
                    f"{self.L.name}: the column rebuilt at index {j} does not "
                    f"authenticate against the published salt and path"
                )
        out["ok"] = (
            not out["failures"]
            and out["salted_leaves_authenticated"] == out["columns_rehashed"]
        )
        return out

    # ------------------------------------------------------- fibre dimension
    def fibre_dimension(self):
        """`dim {r : view(d_fixed, r) = y}`, exactly, from the triangular solve.

          msg  per group, `(pair rows - 2) * n` minus the COMPUTED rank of the
               claim-value and u-row constraints on that kernel, plus the free
               proximity rows;
          pad  `(rows - g) * (Q - d)` with `g = 2(G+1)` the Fp generators.

        The number does not depend on the fixed input: every matrix solved is
        a function of rho, rw, cw and the sampled nodes only.
        """
        L = self.L
        msg_free = sum(s["free_fp"] for s in self.steps if s["step"].startswith("msg"))
        g = 2 * (len(L.rhos) + 1)
        pad_free = (L.rows - g) * (L.q - L.d)
        return {
            "blinding_unknowns": (L.rows - len(L.data_rows)) * L.m
            + L.rows * L.q
            - len(L.u_rows),
            "msg_block_fp": msg_free,
            "pad_block_fp": pad_free,
            "fibre_dimension_fp": msg_free + pad_free,
            "generators_fp": g,
            "distinct_opened_columns": L.d,
            "independent_of_the_fixed_input": True,
            "why": "every matrix solved is a function of rho, rw, cw and the sampled "
            "nodes only; the fixed input enters the right-hand side alone",
        }


# ------------------------------------------------------------ the driver
def layout_for_view(view, name=None):
    """The layout of one RUN commitment, from its `RunRoleView`."""
    return WideRoleLayout(
        view,
        msg_width=view.sp.n_cols,
        pad_width=view.pad_len,
        zkey=view.sp.zkey_weights,
        colfun=view.sp.column_functional_parts,
        name=name or view.name,
    )


def preimage_for_view(view, name=None, data=None, pad_width=None,
                      hash_rule=None, root=None, verify=True):
    """Solve and (by default) verify one commitment, returning the record."""
    t0 = time.time()
    layout = layout_for_view(view, name=name)
    dims = layout.dimensions()
    t_layout = time.time() - t0
    pre = WideRolePreimage(layout, data=data, pad_width=pad_width).build()
    rec = {
        "commitment": layout.name,
        "commitment_kind": view.role["commitment_kind"],
        "boundary": view.role["boundary"],
        "fixed_input": "all zero" if not data else "supplied",
        "half": "message and pad",
        "system": dims,
        "steps": pre.steps,
        "solve_findings": list(pre.fail),
        "solved": not pre.fail,
        "layout_seconds": round(t_layout, 2),
        **pre.timing,
    }
    if pre.fail or not verify:
        rec["preimage_exhibited"] = False
        rec["verification"] = None
        rec["fibre"] = pre.fibre_dimension()
        return rec, pre
    ver = pre.verify(hash_rule=hash_rule, root=root)
    rec["verification"] = ver
    rec["fibre"] = pre.fibre_dimension()
    rec["exhibited_randomness_sha256"] = pre.blinding_digest()
    rec["preimage_exhibited"] = bool(
        ver["all_entries_equal"] and (not ver["hash_layer"]["checked"]
                                      or ver["hash_layer"]["ok"])
    )
    rec["seconds"] = round(time.time() - t0, 2)
    return rec, pre


def full_preimages(bundle, views, names=None, verify=True):
    """Every PCS commitment of the run, solved and verified at `d = 0`."""
    t0 = time.time()
    order = names if names is not None else sorted(views)
    rule = bundle.hash_rule
    per = []
    for nm in order:
        v = views[nm]
        rec, _pre = preimage_for_view(
            v, name=nm, hash_rule=rule,
            root=v.role["commitment"]["root"], verify=verify,
        )
        per.append(rec)
    done = [p for p in per if p["preimage_exhibited"]]
    entries = sum(
        (p["verification"] or {}).get("entries_compared", 0) for p in per
    )
    leaves = sum(
        ((p["verification"] or {}).get("hash_layer") or {}).get(
            "salted_leaves_authenticated", 0)
        for p in per
    )
    return {
        "what": "for every PCS commitment of the run -- A and H included -- prover "
        "blinding that reproduces the captured view under the ALL-ZERO hidden "
        "input, solved exactly over Fp and then verified by recomputing the view "
        "entry by entry",
        "fixed_input": "all zero (a public object: no capture carries a witness "
        "and none is read)",
        "half": "message and pad, plus every opened column, plus the salted "
        "leaves of the opened columns",
        "bundle": bundle.name,
        "commitments": list(order),
        "exhibited": [p["commitment"] for p in done],
        "not_exhibited": [p["commitment"] for p in per if not p["preimage_exhibited"]],
        "view_entries_compared": entries,
        "view_entries_differing": sum(
            (p["verification"] or {}).get("group_vector_mismatches", 0)
            + (p["verification"] or {}).get("proximity_mismatches", 0)
            + (p["verification"] or {}).get("claim_value_mismatches", 0)
            + (p["verification"] or {}).get("column_mismatches", 0)
            for p in per
        ),
        "salted_leaves_authenticated": leaves,
        "per_commitment": per,
        "seconds": round(time.time() - t0, 1),
        "what_it_does_not_show": [
            "nothing about the LAW of the blinding: a preimage EXISTS, which is "
            "not the statement that the honest prover's randomness is uniform on "
            "the fibre (that is the lemma's job)",
            "nothing about the masking commitment M's own rows (the CFS channel)",
            "nothing about an UNOPENED Merkle leaf, which no preimage can "
            "reproduce (M-2, M-3)",
            "nothing at the 125M shape and nothing nonlinear",
        ],
        "this_is_not_a_privacy_result": True,
        "ok": bool(per) and all(p["preimage_exhibited"] for p in per),
    }
