"""Stage 2: the joint commitment-side view of a native capture, with columns.

MODEL (stated exactly, because every number below is a number ABOUT THIS
MODEL at these captures' real challenges, and nothing more).

One hiding commitment of the profile holds `rows` committed rows.  Row i is
the pair z_i = (msg_i, pad_i) in Fp^256 x Fp^256: `msg_i` is the committed
message (hidden witness data on the DATA rows, uniform on the MASK and
PROXIMITY rows) and `pad_i` is the row's Q = 256 uniform pad symbols
(pcs.rs::commit_zk_owned_with).  The verifier's whole field-valued view of
that commitment, at FIXED challenges, is affine in (msg, pad):

  (a) every claim value,      value_c = sum_i rw_c[i] <msg_i, cw_c>
  (b) every group vector,     v_g     = sum_i rho_g[i] z_i        (512 entries)
  (c) the proximity vector,   v_prox  = sum_i rho_prox[i] z_i
  (d) every sampled column j, col_j[i] = <E_j, z_i>  for every row i

with rw_c / cw_c from pcs.rs::zpart_weights + zkey_weights, rho from
zk_rhos at the replayed challenges, and E_j the coset-encoding functional
of pcs.rs::encode_row_zk, in closed form

  E_j[msg s] = (x_j^n - 1) / (n (x_j w_n^-s - 1)),  E_j[pad k] = (x_j^n - 1) x_j^k,
  x_j = 7 * w_2048^j.

DISCLOSED DIMENSION.  Write X in Fp^{rows x 512} for the unknowns and F for
the Fp-span of all the observation functionals above (an Fp2-valued
functional contributes its c0 and its c1 coefficient vectors).  Let T be the
space of functionals supported on the DATA rectangle (data rows x message
positions).  Everything outside that rectangle is prover randomness, so what
the view determines about the data is exactly

  disclosed = dim_Fp (F intersect T).

This is the "rank of what is revealed about the hidden planes beyond what the
public statement implies", counted over Fp: one Fp2-valued public identity
counts 2.

THE REDUCTION actually computed (each hypothesis is CHECKED on the capture,
and the reduction itself is validated against a brute-force dense rank on a
small synthetic instance of the same shape by `zk60_native_jv_smallmodel`):

  H-pad   the d DISTINCT sampled columns satisfy d <= Q and the pad block of
          {E_j} has rank d (diag(x_j^n - 1) times a Vandermonde in the
          distinct nonzero nodes x_j).  Then no functional of {E_j} is
          supported on the message positions, and (d) contributes nothing
          to F intersect T beyond (a)-(c).
  H-pair  every claim's row weights rw_c, restricted to the non-data rows,
          are supported on exactly one adjacent reserved pair, that pair is
          used by no other claim, the pair's two coefficients are an Fp-basis
          of Fp2, and no claim touches the proximity pair
          (protocol.rs::audit_claims).
  H-prox  det(rho_prox[prox], rho_prox[prox+1]) != 0
          (protocol.rs::check_opening_challenges refuses otherwise).
  Then every admissible claim combination collapses into the group
  combinations rho_g, so (a) adds nothing to F intersect T, and

      disclosed = 256 * k0 + (the u-row term),
      k0 = dim {p in rowspace(rho) : p vanishes on every non-data row}.

  The u-row term exists only where the layout declares a public linear
  constraint on non-data rows (H's zero-sum pair): it is the space of
  row-functionals xi(gamma) that a P1-combination must put on the data rows
  to cancel a u-row indicator, reported with the row weights it produces.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  A rank of zero is evidence
about this linear model at these two receipts' challenges.
"""

from __future__ import annotations

from zk60_native_jv_capture import LOG_COLS, N_COLS, ENC_COLS, Q_PAD
from zk60_native_jv_field import (
    P,
    F2_ONE,
    F2_ZERO,
    det_mod_p,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_mul_base,
    f2_sub,
    inv,
    rank,
    row_reduce,
    solve,
    two_adic_root,
)

COSET = 7


# ------------------------------------------------------ claim -> row weights
def zpart_weights(part, rows):
    """pcs.rs::zpart_weights, returning (row weights over Fp2, column key)."""
    n = N_COLS
    rw = [F2_ZERO] * rows
    ls = part["log_size"]
    coef = f2_from_list(part["coefficient"])
    point = [f2_from_list(v) for v in part["point"]]
    off = part["offset"]
    if not point:
        if ls >= LOG_COLS:
            assert off % n == 0
            r0 = off // n
            for i in range(1 << (ls - LOG_COLS)):
                rw[r0 + i] = f2_add(rw[r0 + i], coef)
            key = ((), 0, n)
        else:
            r0, c0 = off // n, off % n
            rw[r0] = f2_add(rw[r0], coef)
            key = ((), c0, 1 << ls)
    else:
        assert len(point) == ls, "zk claim: point arity != slice size"
        if ls >= LOG_COLS:
            assert off % n == 0
            lr = ls - LOG_COLS
            r0 = off // n
            for i, e in enumerate(eq_table_msb(point[:lr])):
                rw[r0 + i] = f2_add(rw[r0 + i], f2_mul(coef, e))
            key = (tuple(point[lr:]), 0, n)
        else:
            r0, c0 = off // n, off % n
            rw[r0] = f2_add(rw[r0], coef)
            key = (tuple(point), c0, 1 << ls)
    return rw, key


def zkey_weights(key):
    """pcs.rs::zkey_weights: the column weight vector of a group key."""
    tail, c0, ln = key
    cw = [F2_ZERO] * N_COLS
    if not tail:
        for c in range(c0, c0 + ln):
            cw[c] = F2_ONE
    else:
        for i, e in enumerate(eq_table_msb(list(tail))):
            cw[c0 + i] = e
    return cw


def claim_rows(claim, rows):
    rw, key = zpart_weights(claim["parts"][0], rows)
    for p in claim["parts"][1:]:
        rw2, key2 = zpart_weights(p, rows)
        if key2 != key:
            raise ValueError("zk claim: parts with different column weights")
        rw = [f2_add(a, b) for a, b in zip(rw, rw2)]
    return rw, key


def group_claims(claims, rows):
    """pcs.rs::group_zclaims, first-occurrence order."""
    keys, groups, rws = [], [], []
    for ci, c in enumerate(claims):
        rw, key = claim_rows(c, rows)
        rws.append(rw)
        if key in keys:
            groups[keys.index(key)].append(ci)
        else:
            keys.append(key)
            groups.append([ci])
    return keys, groups, rws


# --------------------------------------------------- the column functionals
def column_functional_parts(j):
    """(the msg half, the pad half) of E_j, as Fp vectors of length 256 each."""
    w_nn = two_adic_root(ENC_COLS.bit_length() - 1)
    w_n = two_adic_root(LOG_COLS)
    xj = COSET * pow(w_nn, j, P) % P
    zn = (pow(xj, N_COLS, P) - 1) % P
    ninv = inv(N_COLS)
    msg = []
    wns = 1
    w_n_inv = inv(w_n)
    for _ in range(N_COLS):
        msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
        wns = wns * w_n_inv % P
    pad, xp = [], 1
    for _ in range(N_COLS):
        pad.append(zn * xp % P)
        xp = xp * xj % P
    return msg, pad, xj, zn


# ------------------------------------------------------------ the analysis
class RoleView:
    """The stage-2 joint view of one commitment (A, H, Input or Output)."""

    def __init__(self, capture, role, prox_rho, checks_budget=6, perturb=None, q_pad=None):
        """`perturb` and `q_pad` exist ONLY for the negative controls.

        `perturb(view)` is called after the claim row weights `self.rws` and
        the group combinations `self.rhos` have been built and before any
        check runs, so a control can model a claim whose weight reaches a
        non-data row outside its reserved pair.  `q_pad` overrides the
        commitment's pad count, so a control can model a commitment with
        fewer pads than the opening has distinct columns.  Both default to
        the capture's own values; an honest run passes neither.
        """
        self.cap = capture
        self.role = role
        self.name = role["role"]
        self.rows = role["commitment"]["rows"]
        self.prox_rho = prox_rho
        self.checks_budget = checks_budget
        self.perturb = perturb
        self.q_pad = Q_PAD if q_pad is None else q_pad
        self.findings: list[str] = []
        self.facts: dict = {"role": self.name, "rows": self.rows}

    def fail(self, what):
        self.findings.append(f"{self.name}: {what}")

    # ---------------------------------------------------------------- run
    def run(self, lambdas):
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

        # -- the claims, the grouping and the group row-combinations
        keys, groups, rws = group_claims(role["claims"], rows)
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
        self.facts["findings"] = self.findings
        return self.facts

    # ------------------------------------------------------------- checks
    def _check_group_claims(self, lambdas):
        """The verifier's own group identity: <v_g[:n], cw_g> == sum lambda*value."""
        bad = 0
        for gi, members in enumerate(self.groups):
            cw = zkey_weights(self.keys[gi])
            v = self.role["groups"][gi]["vector"]
            got = F2_ZERO
            tail, c0, ln = self.keys[gi]
            for t in range(c0, c0 + ln):
                if cw[t] != F2_ZERO:
                    got = f2_add(got, f2_mul(f2_from_list(v[t]), cw[t]))
            want = F2_ZERO
            for m, l in zip(members, lambdas[gi]):
                want = f2_add(want, f2_mul(l, f2_from_list(self.role["claims"][m]["value"])))
            if got != want:
                bad += 1
        self.facts["group_claim_identity_failures"] = bad
        if bad:
            self.fail(f"{bad} group(s): <group vector, column weights> != the combined claim")

    def _check_columns(self):
        """Validate the E_j model against the verifier's accepted column checks."""
        cols = self.role["columns"]
        n = N_COLS
        checked = 0
        bad = 0
        step = max(1, len(cols) // self.checks_budget)
        vectors = [g["vector"] for g in self.role["groups"]] + [self.role["proximity_vector"]]
        rhos = self.rhos + [self.prox_rho]
        gstep = max(1, len(vectors) // 3)
        for ci in range(0, len(cols), step):
            col = cols[ci]
            msg, pad, _, _ = column_functional_parts(col["index"])
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
                for k in range(n):
                    rhs = f2_add(rhs, f2_mul_base(f2_from_list(v[n + k]), pad[k]))
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
            _, _, xj, zn = column_functional_parts(j)
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
                # The pad budget has ZERO slack by construction (q_pad ==
                # num_col_checks): the columns are sampled WITH replacement,
                # the rank of the pad block equals the number of DISTINCT
                # columns, and that number must not exceed the pad count.
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
        """Exact rank of the pad half of {E_j} over the distinct sampled columns."""
        distinct = sorted({c["index"] for c in self.role["columns"]})
        if limit:
            distinct = distinct[:limit]
        mat = [column_functional_parts(j)[1] for j in distinct]
        return rank(mat, N_COLS), len(distinct)

    def pad_block_rank_at_full_budget(self):
        """The BOUNDARY the source actually allows (report §9b): Q_PAD pads
        against Q_PAD DISTINCT opened positions, the collision-free draw.

        The positions are this role's own distinct sampled ones, extended by
        the next unused positions of the same encoded domain until there are
        exactly Q_PAD = num_col_checks of them, so the geometry, the coset and
        the nodes are the receipt's, only the birthday surplus is removed."""
        distinct = sorted({c["index"] for c in self.role["columns"]})
        used = set(distinct)
        j = 0
        while len(distinct) < Q_PAD and j < ENC_COLS:
            if j not in used:
                distinct.append(j)
                used.add(j)
            j += 1
        distinct.sort()
        mat = [column_functional_parts(k)[1] for k in distinct]
        return rank(mat, Q_PAD), len(distinct)

    def _check_pair_schedule(self, data_rows, other_rows, prox_rows, u_rows):
        """H-pair, on the captured claims (protocol.rs::audit_claims, verified)."""
        used = {}
        ok = True
        sum_claims = 0
        on_u = 0
        for ci, rw in enumerate(self.rws):
            touched = [r for r in other_rows if rw[r] != F2_ZERO]
            if any(r in prox_rows for r in touched):
                self.fail(f"claim {ci} touches the proximity pair")
                ok = False
            # The zero-sum (u) rows are themselves prover randomness with a
            # public linear constraint; a claim may EVALUATE them (the zsum
            # slot does) as well as carry its own reserved pair.  Only the
            # reserved pair has to be exclusive.
            rest = [r for r in touched if r not in u_rows]
            if len(rest) < len(touched):
                on_u += 1
            if not rest and u_rows and set(touched) == set(u_rows):
                sum_claims += 1
                pair = tuple(sorted(u_rows))
            elif len(rest) == 2 and rest[1] == rest[0] + 1:
                pair = (rest[0], rest[1])
            else:
                self.fail(f"claim {ci} carries {len(rest)} non-data mask rows, not one pair")
                ok = False
                continue
            if pair in used:
                self.fail(f"claim {ci} shares its reserved pair with claim {used[pair]}")
                ok = False
            used[pair] = ci
            a, b = rw[pair[0]], rw[pair[1]]
            det = (a[0] * b[1] - a[1] * b[0]) % P
            if det == 0:
                self.fail(f"claim {ci}: its pair's two coefficients are not an Fp-basis of Fp2")
                ok = False
        self.facts["reserved_pairs_used"] = len(used)
        self.facts["sum_claims_on_u_rows"] = sum_claims
        self.facts["claims_evaluating_u_rows"] = on_u
        return ok

    def _check_prox_refusal(self, prox_rows):
        if len(prox_rows) < 2:
            self.fail("fewer than two proximity rows")
            return False
        p0, p1 = prox_rows[0], prox_rows[1]
        a, b = self.prox_rho[p0], self.prox_rho[p1]
        det = (a[0] * b[1] - a[1] * b[0]) % P
        self.facts["proximity_pair_determinant_nonzero"] = det != 0
        if det == 0:
            self.fail("the proximity pair's coefficients are dependent (the verifier refuses)")
        return det != 0

    # ------------------------------------------------- the disclosed space
    def _p1_rows(self):
        """A generating set of P1 = rowspace(rho-tilde) over Fp."""
        out = []
        for rho in self.rhos + [self.prox_rho]:
            out.append([v[0] for v in rho])
            out.append([v[1] for v in rho])
        return out

    # ---------------------------------------------- the certifying minor
    def certifying_minor(self, other_rows):
        """The g x g nonsingular submatrix that CERTIFIES the good event.

        The generic-rank lemma's good event is `rank(gens | non-data rows) =
        g = 2(G+1)`, i.e. the non-vanishing of SOME g x g minor of the
        non-data block.  The lemma argues about that minor; until now the
        gate printed only the rank, so a reader could not check the claim
        against anything.  Here the row reduction's pivot columns name one
        such minor explicitly: which generators, which non-data rows, and
        the determinant as an element of Fp.  A reader (and the gate's own
        tests) can rebuild the submatrix from those indices alone.

        `determinant_nonzero` is the certificate.  When the rank is short of
        `g` there is no such minor and the fields say so.
        """
        gens = self._p1_rows()
        g = len(gens)
        block = [[row[i] for i in other_rows] for row in gens]
        _, pivots = row_reduce(block, len(other_rows))
        out = {
            "g": g,
            "G": len(self.rhos),
            "generators": "the real and imaginary parts of the G group vectors and of "
            "the proximity vector",
            "rank_on_non_data_rows": len(pivots),
            "full_row_rank": len(pivots) == g,
            "generator_indices": list(range(g)) if len(pivots) == g else [],
            "non_data_row_indices": [other_rows[c] for c in pivots],
        }
        if len(pivots) == g:
            sub = [[gens[r][other_rows[c]] for c in pivots] for r in range(g)]
            det = det_mod_p(sub)
            out["determinant"] = det
            out["determinant_nonzero"] = det != 0
        else:
            out["determinant"] = None
            out["determinant_nonzero"] = False
            self.fail(
                f"the non-data block has rank {len(pivots)} < g = {g}: no certifying minor"
            )
        return out

    def rebuild_minor(self, generator_indices, non_data_row_indices):
        """The submatrix named by an emitted index pair, and its determinant.

        Takes ONLY the indices, so a checker can start from the evidence file
        and never from the object that produced it.
        """
        gens = self._p1_rows()
        sub = [[gens[r][c] for c in non_data_row_indices] for r in generator_indices]
        det = det_mod_p(sub)
        return {"submatrix": sub, "determinant": det, "nonsingular": det != 0}

    def _disclosed(self, data_rows, other_rows, u_rows):
        gens = self._p1_rows()
        r1 = rank(gens, self.rows)
        r_other = rank([[g[i] for i in other_rows] for g in gens], len(other_rows))
        k0 = r1 - r_other
        self.facts.update({"rank_P1": r1, "rank_P1_on_non_data_rows": r_other, "k0": k0})
        free = 256 * k0
        # the u-row (public linear constraint) term
        u_dim, u_note = 0, None
        if u_rows:
            basis, _ = row_reduce([[g[i] for i in other_rows] for g in gens], len(other_rows))
            # coefficients of the generators for each reduced basis row are not
            # needed: solve directly in terms of the generators.
            targets = []
            for u in u_rows:
                t = [1 if i == u else 0 for i in other_rows]
                targets.append(t)
            xis = []
            admissible = 0
            for t in targets:
                x, _ = solve([[g[i] for i in other_rows] for g in gens], t)
                if x is None:
                    continue
                admissible += 1
                xi = [0] * len(data_rows)
                for k, c in enumerate(x):
                    if c:
                        for a, i in enumerate(data_rows):
                            xi[a] = (xi[a] + c * gens[k][i]) % P
                xis.append(xi)
            kbasis = self._kernel_on_data(gens, other_rows, data_rows)
            u_dim = rank(xis + kbasis, len(data_rows)) - rank(kbasis, len(data_rows))
            # Is the disclosed functional exactly the PUBLIC LogUp identity?
            # The sum claim (the one whose only non-data support is the u pair)
            # carries the identity's data-row weights; compare the spans.
            logup = []
            for ci, rw in enumerate(self.rws):
                touched = [r for r in other_rows if rw[r] != F2_ZERO]
                if u_rows and set(touched) == set(u_rows):
                    logup.append([rw[i][0] for i in data_rows])
                    logup.append([rw[i][1] for i in data_rows])
            same = None
            if logup:
                same = (
                    rank(xis, len(data_rows)) == rank(logup, len(data_rows)) == 2
                    and rank(xis + logup, len(data_rows)) == 2
                )
            u_note = {
                "u_row_indicators_admissible": admissible,
                "extra_dimension_beyond_k0": u_dim,
                "xi_row_weights_nonzero": [sum(1 for v in x if v) for x in xis],
                "equals_public_logup_identity": same,
            }
            self.facts["u_row_term"] = u_note
            self.facts["xi_vectors"] = xis
            self.facts["data_rows_index"] = data_rows
        return free + u_dim

    def _kernel_on_data(self, gens, other_rows, data_rows):
        """{p in P1 : p vanishes off the data rows}, restricted to the data rows."""
        red = [[g[i] for i in other_rows] + [k] for k, g in enumerate(gens)]
        # kernel of the map (coefficients) -> P1 restricted to non-data rows
        m = len(gens)
        cols = len(other_rows)
        aug = [[gens[k][i] for k in range(m)] for i in other_rows]
        # find the kernel of the (cols x m) matrix
        mat = [row[:] for row in aug]
        pivots, r = [], 0
        for c in range(m):
            piv = None
            for i in range(r, cols):
                if mat[i][c] % P:
                    piv = i
                    break
            if piv is None:
                continue
            mat[r], mat[piv] = mat[piv], mat[r]
            pinv = inv(mat[r][c])
            mat[r] = [x * pinv % P for x in mat[r]]
            for i in range(cols):
                if i != r and mat[i][c] % P:
                    f = mat[i][c]
                    mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
            pivots.append(c)
            r += 1
            if r == cols:
                break
        free_cols = [c for c in range(m) if c not in pivots]
        out = []
        for fc in free_cols:
            v = [0] * m
            v[fc] = 1
            for i, pc in enumerate(pivots):
                v[pc] = (-mat[i][fc]) % P
            row = [0] * len(data_rows)
            for k, cff in enumerate(v):
                if cff:
                    for a, i in enumerate(data_rows):
                        row[a] = (row[a] + cff * gens[k][i]) % P
            out.append(row)
        return out
