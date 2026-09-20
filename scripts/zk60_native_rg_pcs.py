"""The per-commitment disclosed dimension, with the SHAPE read from the run.

`zk60_native_jv_pcs.RoleView` is the model and states the model in full: one
hiding commitment holds `rows` committed rows, row `i` is the pair
`z_i = (msg_i, pad_i)` in `Fp^n x Fp^Q`, the verifier's whole field-valued
view at fixed challenges is affine in `(msg, pad)`, and

    disclosed = dim_Fp ( F intersect T )

with `T` the functionals supported on the DATA rectangle.  Under H-pad,
H-pair and H-prox (each CHECKED, not assumed) that reduces to
`n * k0 + (u-row term)`.

That module's geometry is the toy's, as module constants
(`LOG_COLS = 8`, `N_COLS = 256`, `INV_RATE = 8`, `ENC_COLS = 2048`,
`Q_PAD = 256`).  Its committed evidence is hash-pinned, so it is NOT edited:
this module subclasses `RoleView` and overrides exactly the methods that read
those constants, taking every number instead from `run.json["shape"]` and
from the opening's own `params` / `q_pad` (format findings U-7).  Everything
that is already shape-agnostic -- the reserved-pair schedule check, the
proximity-pair determinant, the certifying minor, the kernel on the data rows
-- is inherited unchanged, so the two gates compute the same things by the
same code wherever they can.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  Every number is a number about
this linear model at these captures' real challenges.
"""

from __future__ import annotations

from zk60_native_jv_field import (
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_mul_base,
    inv,
    rank,
    row_reduce,
    two_adic_root,
)
from zk60_native_jv_pcs import RoleView

COSET = 7  # pcs.rs::encode_row_zk, the coset generator


class ShapePcs:
    """The shape numbers the per-commitment model needs, as one object."""

    def __init__(self, shape):
        self.log_cols = shape.log_cols
        self.n_cols = shape.cols
        self.inv_rate = shape.inv_rate
        self.enc_cols = shape.enc_cols
        self.opened_cols = shape.opened_cols

    # ---------------------------------------------- claim -> row weights
    def zpart_weights(self, part, rows):
        """pcs.rs::zpart_weights (row weights over Fp2, column key)."""
        n = self.n_cols
        rw = [F2_ZERO] * rows
        ls = part["log_size"]
        coef = f2_from_list(part["coefficient"])
        point = [f2_from_list(v) for v in part["point"]]
        off = part["offset"]
        if not point:
            if ls >= self.log_cols:
                assert off % n == 0
                r0 = off // n
                for i in range(1 << (ls - self.log_cols)):
                    rw[r0 + i] = f2_add(rw[r0 + i], coef)
                key = ((), 0, n)
            else:
                r0, c0 = off // n, off % n
                rw[r0] = f2_add(rw[r0], coef)
                key = ((), c0, 1 << ls)
        else:
            assert len(point) == ls, "zk claim: point arity != slice size"
            if ls >= self.log_cols:
                assert off % n == 0
                lr = ls - self.log_cols
                r0 = off // n
                for i, e in enumerate(eq_table_msb(point[:lr])):
                    rw[r0 + i] = f2_add(rw[r0 + i], f2_mul(coef, e))
                key = (tuple(point[lr:]), 0, n)
            else:
                r0, c0 = off // n, off % n
                rw[r0] = f2_add(rw[r0], coef)
                key = (tuple(point), c0, 1 << ls)
        return rw, key

    def zkey_weights(self, key):
        """pcs.rs::zkey_weights: the column weight vector of a group key."""
        tail, c0, ln = key
        cw = [F2_ZERO] * self.n_cols
        if not tail:
            for c in range(c0, c0 + ln):
                cw[c] = F2_ONE
        else:
            for i, e in enumerate(eq_table_msb(list(tail))):
                cw[c0 + i] = e
        return cw

    def claim_rows(self, claim, rows):
        rw, key = self.zpart_weights(claim["parts"][0], rows)
        for p in claim["parts"][1:]:
            rw2, key2 = self.zpart_weights(p, rows)
            if key2 != key:
                raise ValueError("zk claim: parts with different column weights")
            rw = [f2_add(a, b) for a, b in zip(rw, rw2)]
        return rw, key

    def group_claims(self, claims, rows):
        """pcs.rs::group_zclaims, first-occurrence order."""
        keys, groups, rws = [], [], []
        for ci, c in enumerate(claims):
            rw, key = self.claim_rows(c, rows)
            rws.append(rw)
            if key in keys:
                groups[keys.index(key)].append(ci)
            else:
                keys.append(key)
                groups.append([ci])
        return keys, groups, rws

    # ------------------------------------------- the column functionals
    def column_node(self, j):
        """`(x_j, Z_n(x_j))` alone -- the pad-budget check needs no vector."""
        w_nn = two_adic_root(self.enc_cols.bit_length() - 1)
        xj = COSET * pow(w_nn, j, P) % P
        return xj, (pow(xj, self.n_cols, P) - 1) % P

    def column_functional_parts(self, j, q):
        """(msg half, pad half, node, Z_n(node)) of E_j at this shape.

        `pcs.rs::encode_row_zk` writes `n` message coefficients and `q` pad
        symbols into an `n*inv_rate` coset evaluation, so

            E_j[msg s] = (x_j^n - 1) / (n (x_j w_n^-s - 1)),
            E_j[pad k] = (x_j^n - 1) x_j^k   for k < q,   x_j = 7 w_nn^j.

        The two halves have DIFFERENT lengths here (`n = 1024`, `q = 256`);
        at the toy profile both were 256, which is why the toy tool's own
        column functional carries one length only.
        """
        xj, zn = self.column_node(j)
        w_n = two_adic_root(self.log_cols)
        ninv = inv(self.n_cols)
        msg = []
        wns = 1
        w_n_inv = inv(w_n)
        for _ in range(self.n_cols):
            msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
            wns = wns * w_n_inv % P
        pad, xp = [], 1
        for _ in range(q):
            pad.append(zn * xp % P)
            xp = xp * xj % P
        return msg, pad, xj, zn


class RunRoleView(RoleView):
    """One commitment of one stage, ranked at the run's own shape."""

    def __init__(self, stage, role, prox_rho, shape, checks_budget=6, perturb=None,
                 q_pad=None, name=None):
        self.sp = ShapePcs(shape)
        super().__init__(stage, role, prox_rho, checks_budget=checks_budget,
                         perturb=perturb, q_pad=role["q_pad"] if q_pad is None else q_pad)
        # the pad half's TRUE length, from the published vector: a control may
        # move `q_pad` (the budget the model is allowed) but never the bytes
        self.pad_len = len(role["proximity_vector"]) - self.sp.n_cols
        if self.pad_len != role["q_pad"]:
            self.fail(
                f"the published vectors carry {self.pad_len} pad positions, "
                f"the opening declares q_pad {role['q_pad']}"
            )
        if name is not None:
            self.name = name
        self.facts["role"] = self.name
        self.facts["commitment_kind"] = role["commitment_kind"]
        self.facts["boundary"] = role["boundary"]
        self.stage_index = getattr(stage, "index", None)
        self.facts["stage"] = self.stage_index

    # ---------------------------------------------------------------- run
    def run(self, lambdas):
        """`RoleView.run` with the shape-driven grouping; the checks it calls
        are the inherited ones wherever they do not read a size."""
        role = self.role
        rows = self.rows
        kinds = {r["row"]: r["kind"] for r in role["row_roles"]}
        data_rows = [r for r in range(rows) if kinds[r] == "data"]
        other_rows = [r for r in range(rows) if kinds[r] != "data"]
        prox_rows = [r for r in range(rows) if kinds[r] == "prox"]
        u_rows = []
        for plc in role["public_linear_constraints"]:
            u_rows.extend(plc["rows"])
        self.facts.update(
            {"data_rows": len(data_rows), "non_data_rows": len(other_rows), "u_rows": u_rows}
        )
        # the writer's own row fields, cross-checked against row_roles
        declared = role["data_rows"]
        if declared != len(data_rows):
            self.facts["declared_data_rows_vs_row_roles"] = {
                "declared": declared,
                "kind_data": len(data_rows),
                "difference_is_the_zero_sum_rows": sorted(u_rows)
                == sorted(range(len(data_rows), declared)),
            }
        if role["prox_row"] != prox_rows[0] or prox_rows != [role["prox_row"],
                                                             role["prox_row"] + 1]:
            self.fail("the declared prox_row is not the pair row_roles marks 'prox'")
        if sorted(role["site_rows"]) != sorted(
            r for r in other_rows if r not in prox_rows and r not in u_rows
        ):
            self.fail("site_rows is not the set of reserved non-proximity mask rows")

        keys, groups, rws = self.sp.group_claims(role["claims"], rows)
        if [g for g in groups] != [g["members"] for g in role["groups"]]:
            self.fail("recomputed group membership differs from the capture")
        for gi, g in enumerate(role["groups"]):
            tail = tuple(f2_from_list(v) for v in g["key"]["tail"])
            if (tail, g["key"]["offset"], g["key"]["len"]) != keys[gi]:
                self.fail(f"group {gi}: recomputed column key differs from the capture")
        rhos = []
        for gi, members in enumerate(groups):
            lam = lambdas[gi]
            rho = [F2_ZERO] * rows
            for m, l in zip(members, lam):
                for i in range(rows):
                    if rws[m][i] != F2_ZERO:
                        rho[i] = f2_add(rho[i], f2_mul(l, rws[m][i]))
            rhos.append(rho)
        self.rhos = rhos
        self.rws = rws
        self.groups = groups
        self.keys = keys
        self.data_rows = data_rows
        self.other_rows = other_rows
        self.prox_rows = prox_rows
        self.u_rows = u_rows
        self._lambdas = lambdas
        if self.perturb is not None:
            self.perturb(self)

        self._check_group_claims(lambdas)
        self._check_columns()
        pad_ok = self._check_pad_budget()
        pair_ok = self._check_pair_schedule(data_rows, other_rows, prox_rows, u_rows)
        prox_ok = self._check_prox_refusal(prox_rows)
        disclosed = self._disclosed(data_rows, other_rows, u_rows)
        self.facts["certifying_minor"] = self.certifying_minor(other_rows)
        self.facts["reduction_hypotheses"] = {
            "H-pad": pad_ok,
            "H-pair": pair_ok,
            "H-prox": prox_ok,
        }
        self.facts["disclosed_dimension"] = disclosed
        self.facts["groups"] = len(self.groups)
        self.facts["claims"] = len(self.rws)
        self.facts["findings"] = self.findings
        return self.facts

    # ------------------------------------------------------------- checks
    def _check_group_claims(self, lambdas):
        bad = 0
        for gi, members in enumerate(self.groups):
            cw = self.sp.zkey_weights(self.keys[gi])
            v = self.role["groups"][gi]["vector"]
            got = F2_ZERO
            _, c0, ln = self.keys[gi]
            for t in range(c0, c0 + ln):
                if cw[t] != F2_ZERO:
                    got = f2_add(got, f2_mul(f2_from_list(v[t]), cw[t]))
            want = F2_ZERO
            for m, l in zip(members, lambdas[gi]):
                want = f2_add(want, f2_mul(l, f2_from_list(self.role["claims"][m]["value"])))
            if got != want:
                bad += 1
        self.facts["group_claim_identity_failures"] = bad
        self.facts["group_claim_identities_checked"] = len(self.groups)
        if bad:
            self.fail(f"{bad} group(s): <group vector, column weights> != the combined claim")

    def _check_columns(self):
        cols = self.role["columns"]
        n = self.sp.n_cols
        checked = 0
        bad = 0
        step = max(1, len(cols) // self.checks_budget)
        vectors = [g["vector"] for g in self.role["groups"]] + [self.role["proximity_vector"]]
        rhos = self.rhos + [self.prox_rho]
        gstep = max(1, len(vectors) // 3)
        for ci in range(0, len(cols), step):
            col = cols[ci]
            msg, pad, _, _ = self.sp.column_functional_parts(col["index"], self.pad_len)
            for gi in range(0, len(vectors), gstep):
                v = vectors[gi]
                rho = rhos[gi]
                lhs = F2_ZERO
                for i, x in enumerate(col["values"]):
                    if x:
                        lhs = f2_add(lhs, f2_mul_base(rho[i], x))
                rhs = F2_ZERO
                for t in range(n):
                    rhs = f2_add(rhs, f2_mul_base(f2_from_list(v[t]), msg[t]))
                for kk in range(self.pad_len):
                    rhs = f2_add(rhs, f2_mul_base(f2_from_list(v[n + kk]), pad[kk]))
                checked += 1
                if lhs != rhs:
                    bad += 1
        self.facts["column_identity_checked"] = checked
        self.facts["column_identity_failures"] = bad
        if bad:
            self.fail(f"{bad}/{checked} sampled-column identities do not reproduce (model error)")

    def _check_pad_budget(self):
        idx = [c["index"] for c in self.role["columns"]]
        distinct = sorted(set(idx))
        d = len(distinct)
        zn_zero = 0
        nodes = set()
        for j in distinct:
            xj, zn = self.sp.column_node(j)
            if zn == 0:
                zn_zero += 1
            nodes.add(xj)
        q_pad = self.q_pad
        ok = d <= q_pad and zn_zero == 0 and len(nodes) == d
        self.facts.update(
            {
                "sampled_columns": len(idx),
                "distinct_columns": d,
                "q_pad": q_pad,
                "pad_margin": q_pad - d,
                "coset_nodes_distinct": len(nodes) == d,
                "vanishing_Zn_nodes": zn_zero,
                "distinct_opened_columns": d,
                "pad_count": q_pad,
                "distinct_opened_columns_within_pad_count": d <= q_pad,
            }
        )
        if not ok:
            self.fail(
                f"pad budget: {d} distinct opened columns, {q_pad} pads, "
                f"{zn_zero} vanishing Z_n nodes"
            )
        return ok

    def pad_block_rank(self, limit=None):
        """Exact rank of the pad half of {E_j} over the distinct columns."""
        distinct = sorted({c["index"] for c in self.role["columns"]})
        if limit:
            distinct = distinct[:limit]
        mat = [self.sp.column_functional_parts(j, self.pad_len)[1] for j in distinct]
        return rank(mat, self.pad_len), len(distinct)

    def pad_block_rank_at_full_budget(self):
        distinct = sorted({c["index"] for c in self.role["columns"]})
        used = set(distinct)
        j = 0
        while len(distinct) < self.q_pad and j < self.sp.enc_cols:
            if j not in used:
                distinct.append(j)
                used.add(j)
            j += 1
        distinct.sort()
        mat = [self.sp.column_functional_parts(k, self.pad_len)[1] for k in distinct]
        return rank(mat, self.pad_len), len(distinct)

    # ------------------------------------------------- the disclosed space
    def _disclosed(self, data_rows, other_rows, u_rows):
        """`RoleView._disclosed` with `n` the run's column count, not 256."""
        gens = self._p1_rows()
        r1 = rank(gens, self.rows)
        r_other = rank([[g[i] for i in other_rows] for g in gens], len(other_rows))
        k0 = r1 - r_other
        self.facts.update({"rank_P1": r1, "rank_P1_on_non_data_rows": r_other, "k0": k0})
        free = self.sp.n_cols * k0
        u_dim = 0
        if u_rows:
            u_dim = self._u_term(gens, data_rows, other_rows, u_rows)
        return free + u_dim

    def _u_term(self, gens, data_rows, other_rows, u_rows):
        from zk60_native_jv_field import solve

        block = [[g[i] for i in other_rows] for g in gens]
        xis, admissible = [], 0
        for u in u_rows:
            target = [1 if i == u else 0 for i in other_rows]
            x, _ = solve(block, target)
            if x is None:
                continue
            admissible += 1
            xi = [0] * len(data_rows)
            for kk, c in enumerate(x):
                if c:
                    for a, i in enumerate(data_rows):
                        xi[a] = (xi[a] + c * gens[kk][i]) % P
            xis.append(xi)
        kbasis = self._kernel_on_data(gens, other_rows, data_rows)
        u_dim = rank(xis + kbasis, len(data_rows)) - rank(kbasis, len(data_rows))
        logup = []
        for ci, rw in enumerate(self.rws):
            touched = [r for r in other_rows if rw[r] != F2_ZERO]
            if set(touched) == set(u_rows):
                logup.append([rw[i][0] for i in data_rows])
                logup.append([rw[i][1] for i in data_rows])
        same = None
        if logup:
            same = (
                rank(xis, len(data_rows)) == rank(logup, len(data_rows)) == 2
                and rank(xis + logup, len(data_rows)) == 2
            )
        self.facts["u_row_term"] = {
            "u_row_indicators_admissible": admissible,
            "extra_dimension_beyond_k0": u_dim,
            "xi_row_weights_nonzero": [sum(1 for v in x if v) for x in xis],
            "equals_public_logup_identity": same,
        }
        return u_dim

    # ------------------------------------------- the reserved-row figure
    def reserved_row_rank(self, reserved_rows):
        """Ruling M-1 / check A1.4: the rank RESTRICTED to named rows.

        Over ALL rows every degenerate geometry looks like full rank; only
        the restriction to the reserved mask rows separates the honest case
        from a shared pair or a single proximity row.  Returns the rank, the
        number of generators, the shortfall and the certifying minor when the
        block has full row rank.
        """
        gens = self._p1_rows()
        g = len(gens)
        block = [[row[i] for i in reserved_rows] for row in gens]
        _, pivots = row_reduce(block, len(reserved_rows))
        out = {
            "reserved_rows": list(reserved_rows),
            "generators": g,
            "rank_on_reserved_rows": len(pivots),
            "full_row_rank": len(pivots) == g,
            "disclosed_on_the_reserved_block_fp": g - len(pivots),
            "pivot_rows": [reserved_rows[c] for c in pivots],
        }
        if len(pivots) == g:
            from zk60_native_jv_field import det_mod_p

            sub = [[gens[r][reserved_rows[c]] for c in pivots] for r in range(g)]
            out["determinant"] = det_mod_p(sub)
            out["determinant_nonzero"] = out["determinant"] != 0
            out["generator_indices"] = list(range(g))
        else:
            out["determinant"] = None
            out["determinant_nonzero"] = False
            out["generator_indices"] = []
        return out
