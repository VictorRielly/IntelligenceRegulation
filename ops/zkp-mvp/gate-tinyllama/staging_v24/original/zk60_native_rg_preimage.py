"""A zero-data preimage of the MESSAGE half of one commitment's view.

`zk60_native_privacy_gate` CONSTRUCTS, for the toy captures, prover
randomness that reproduces a whole captured view under a fixed hidden input.
That module's arithmetic is written for `MSG == PAD == 256`
(`zk60_native_pg_pcs.py:95-96`); at the run's rung shape the message half is
1,024 wide and the pad half 256, so it does not generalise as it stands.
What DOES generalise, cheaply and exactly, is the message half of a
commitment all of whose opening groups are SINGLETONS -- the two external
endpoints and every internal boundary:

  the view's message half is    v_g[t] = sum_i rho_g[i] X[i][t],  t < n,
  for the G group combinations and the proximity combination; splitting each
  `Fp2` equation into its real and imaginary parts gives, at EVERY message
  position t, the same `2(G+1) x (#non-data rows)` system over `Fp` -- the
  matrix whose rank this gate reports as the commitment's reserved-row
  figure.

So CONSTRUCTING a preimage under the all-zero hidden input is exactly:
fix `X[data][t] = 0`, solve that one system once per position, and recompute
the view.  Full row rank of the reserved block is precisely the statement
that a preimage exists for EVERY published message half, and the exhibited
solution is what turns that rank from a number into a construction.

WHAT IS NOT CONSTRUCTED HERE, and is reported as OPEN with its reason:
the PAD half and the opened column values (they need the Lagrange
interpolation and the `Z_S` divisibility step of `zk60_native_pg_pcs`, whose
`MSG == PAD` assumption is load-bearing there); the commitments `A` and `H`,
whose opening groups have several members, so the individual claim values
are extra constraints that need that module's correction step; and the
masking commitment `M`.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

import hashlib

from zk60_native_jv_field import F2_ZERO, P, f2_add, f2_from_list, f2_mul_base, inv


def _rref_with_transform(a, ncols):
    """RREF of `a` (list of rows) with the accumulated row transform T.

    Returns (rows, pivots, T) with `rows = T @ a` in reduced row echelon
    form.  One factorisation serves every message position.
    """
    m = len(a)
    mat = [list(r) + [1 if i == j else 0 for j in range(m)] for i, r in enumerate(a)]
    pivots = []
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, m):
            if mat[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        mat[r], mat[piv] = mat[piv], mat[r]
        pinv = inv(mat[r][c])
        mat[r] = [x * pinv % P for x in mat[r]]
        for i in range(m):
            if i != r and mat[i][c] % P:
                f = mat[i][c]
                mat[i] = [(x - f * y) % P for x, y in zip(mat[i], mat[r])]
        pivots.append(c)
        r += 1
        if r == m:
            break
    rows = [row[:ncols] for row in mat]
    t = [row[ncols:] for row in mat]
    return rows, pivots, t


class MsgPreimage:
    """The zero-data preimage of one commitment's published message half."""

    def __init__(self, view, shape):
        self.view = view
        self.n = shape.cols
        self.name = view.name
        self.findings: list[str] = []

    def build(self):
        v = self.view
        n = self.n
        gens = v._p1_rows()
        g = len(gens)
        nondata = list(v.other_rows)
        singleton = all(len(m) == 1 for m in v.groups)
        a = [[gens[r][c] for c in nondata] for r in range(g)]
        rows, pivots, t = _rref_with_transform(a, len(nondata))
        rank_a = len(pivots)

        vectors = [gr["vector"] for gr in v.role["groups"]] + [v.role["proximity_vector"]]
        # the RHS at position s, in the generator order of `_p1_rows`
        x = [[0] * n for _ in range(v.rows)]  # the whole message block, data = 0
        infeasible = 0
        for s in range(n):
            b = []
            for vec in vectors:
                val = f2_from_list(vec[s])
                b.append(val[0])
                b.append(val[1])
            bb = [sum(t[i][j] * b[j] for j in range(g)) % P for i in range(g)]
            for i in range(rank_a, g):
                if bb[i] % P:
                    infeasible += 1
                    break
            else:
                for i, c in enumerate(pivots):
                    x[nondata[c]][s] = bb[i]
        self.x = x
        facts = {
            "commitment": self.name,
            "commitment_kind": v.role["commitment_kind"],
            "boundary": v.role["boundary"],
            "rows": v.rows,
            "data_rows": len(v.data_rows),
            "non_data_rows": len(nondata),
            "generators": g,
            "rank_of_the_non_data_block": rank_a,
            "full_row_rank": rank_a == g,
            "every_group_is_a_singleton": singleton,
            "message_positions": n,
            "positions_without_a_solution": infeasible,
            "fixed_input": "all zero",
            "free_fp_per_position": len(nondata) - rank_a,
            "fibre_free_fp": (len(nondata) - rank_a) * n,
        }
        if infeasible:
            self.findings.append(
                f"{self.name}: {infeasible} message positions have no zero-data preimage"
            )
        facts["verification"] = self._verify()
        facts["randomness_digest"] = self._digest(nondata)
        facts["findings"] = self.findings
        facts["preimage_exhibited"] = bool(
            not infeasible and facts["verification"]["all_entries_equal"]
        )
        return facts

    # ---------------------------------------------------------- verify
    def _verify(self):
        """Recompute the view's message half and every claim value from the
        exhibited randomness and compare it with the capture."""
        v = self.view
        n = self.n
        bad_vec = 0
        checked_vec = 0
        combos = list(v.rhos) + [v.prox_rho]
        vectors = [gr["vector"] for gr in v.role["groups"]] + [v.role["proximity_vector"]]
        for rho, vec in zip(combos, vectors):
            support = [i for i in range(v.rows) if rho[i] != F2_ZERO]
            for s in range(n):
                got = F2_ZERO
                for i in support:
                    if self.x[i][s]:
                        got = f2_add(got, f2_mul_base(rho[i], self.x[i][s]))
                checked_vec += 1
                if got != f2_from_list(vec[s]):
                    bad_vec += 1
        # every claim value, recomputed from the preimage
        bad_claim = 0
        for ci, rw in enumerate(v.rws):
            cw = v.sp.zkey_weights(v.keys[[ci in m for m in v.groups].index(True)])
            got = F2_ZERO
            for i in range(v.rows):
                if rw[i] == F2_ZERO:
                    continue
                inner = F2_ZERO
                row = self.x[i]
                for tpos in range(n):
                    if row[tpos] and cw[tpos] != F2_ZERO:
                        inner = f2_add(inner, f2_mul_base(cw[tpos], row[tpos]))
                got = f2_add(got, _f2_mul(rw[i], inner))
            if got != f2_from_list(v.role["claims"][ci]["value"]):
                bad_claim += 1
        if bad_vec or bad_claim:
            self.findings.append(
                f"{self.name}: the recomputed view differs from the capture "
                f"({bad_vec} vector entries, {bad_claim} claim values)"
            )
        return {
            "message_entries_checked": checked_vec,
            "message_entries_differing": bad_vec,
            "claim_values_checked": len(v.rws),
            "claim_values_differing": bad_claim,
            "all_entries_equal": bad_vec == 0 and bad_claim == 0,
            "channels_verified": [
                "every opening group's vector, message half",
                "the proximity vector, message half",
                "every claim value",
            ],
            "channels_not_verified": [
                "the pad half of every published vector",
                "the opened column values",
                "the Merkle root, the leaf salts and the authentication paths",
            ],
        }

    def _digest(self, nondata):
        """A sha256 of the EXHIBITED randomness, so a reader can pin it
        without the values ever being printed."""
        h = hashlib.sha256()
        h.update(self.name.encode())
        for i in nondata:
            for val in self.x[i]:
                h.update(int(val).to_bytes(8, "little"))
        return h.hexdigest()


def _f2_mul(a, b):
    ac = a[0] * b[0] % P
    bd = a[1] * b[1] % P
    ad = a[0] * b[1] % P
    bc = a[1] * b[0] % P
    return ((ac + bd * 7) % P, (ad + bc) % P)


def preimages(bundle, views, names):
    """The zero-data message-half preimage of each named commitment."""
    out = []
    for nm in names:
        v = views[nm]
        if not all(len(m) == 1 for m in v.groups):
            out.append(
                {
                    "commitment": nm,
                    "preimage_exhibited": False,
                    "skipped": "this commitment has multi-member opening groups, so the "
                    "individual claim values are extra constraints; the correction step "
                    "that handles them lives in zk60_native_pg_pcs, whose MSG == PAD "
                    "assumption does not hold at this shape",
                }
            )
            continue
        out.append(MsgPreimage(v, bundle.shape).build())
    attempted = [p for p in out if "skipped" not in p]
    return {
        "per_commitment": out,
        "fixed_input": "all zero",
        "half": "message only",
        "attempted": [p["commitment"] for p in attempted],
        "skipped": [p["commitment"] for p in out if "skipped" in p],
        "ok": bool(attempted) and all(p["preimage_exhibited"] for p in attempted),
    }
