"""Ruling GC-2 (round 9l): the run gate's EXCLUSIVITY check, clause by
clause, and one negative control per clause.

WHY THIS MODULE EXISTS.  The reduction `disclosed = n*k0 + u*` rests on
three checked hypotheses; H-pair is the one about the claims.  Until round
9l the gate's H-pair was `zk60_native_jv_pcs.RoleView._check_pair_schedule`
(the toy's, inherited), and finding F-4 of
`ZK60_GS4_GS5_GS11_GS12_CLOSURES_CHECK.md` showed it is WEAKER than the
verifier's own `protocol.rs::audit_claims`: it accepts two claims on the
OVERLAPPING pairs (4, 5) and (5, 6), an odd-offset pair, and a schedule
that leaves a reserved pair unused -- it refuses a shared pair only when the
two pairs are IDENTICAL.  Finding F-6 showed that the negative controls
behind the GS-4 closure exercise 7 kinds and leave most clauses of
exclusivity unexercised.  Ruling GC-2 (the disposition, §3): make the
gate's check refuse overlap, and exercise every clause at least once.

WHAT IS CHECKED.  Sixteen clauses, each evaluated on its own (no
short-circuit, so a perturbation reports EVERY clause it breaks), on the
claim list the capture carries and on the row weights the gate already
builds from it.  The geometry is the gate's own reading of the capture
(`row_roles`, the declared `site_rows` / `sum_rows`, the shape's group
counts); stage 1 cross-checks those declarations against the run header.
Line numbers are `hashline/src/private_block/protocol.rs` at lane commit
`2ea7221` (read-only), unless another file is named.

  EX-1  geometry                  :233-235, :356-370
  EX-2  no claim reaches the proximity pair            :242-244
  EX-3  no claim part leaves the commitment            :242-244
  EX-4  a part on a site row has a nonzero coefficient :246-248
  EX-5  an evaluation claim carries two ADJACENT site rows   :258-262
  EX-6  ... at an EVEN offset from the first site row  :259
  EX-7  no weight on a spare reserved row              (X); :379-384
  EX-8  the sum claim: no site row, both zero-sum rows :252-257
  EX-9  no other point-free claim                      :263
  EX-10 pairs DISJOINT (no site row carries two claims)  :268-270
  EX-11 every reserved row USED                        :268-270
  EX-12 the pair basis: an Fp-basis of Fp2   argument.rs:382-384 (not audit)
  EX-13 one column key per claim                       :203-205
  EX-14 the group count is the schedule's              :321-324, :389
  EX-15 the endpoint claim's shape                     :379-384
  EX-16 every group coefficient lambda nonzero         :296-301

EX-7, EX-12 and the no-spare half of EX-1 are not `audit_claims` clauses:
they are the rest of the reduction's hypothesis (X) (every claim's weights,
restricted to the non-data non-zero-sum rows and the proximity pair, are an
Fp-basis pair on its own adjacent reserved rows), held by `build_claim`
and the endpoint geometry.  H-prox (the proximity pair's determinant) stays
the gate's separate third hypothesis.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  A clause that holds is a fact
about a claim list; the controls show that the check can SEE each way the
list could be wrong.
"""

from __future__ import annotations

import copy

from zk60_native_jv_field import P, f2_from_list
from zk60_native_jv_pcs import RoleView

CLAUSES = [
    ("EX-1", "geometry",
     "protocol.rs:233-235 (audit_claims: the proximity pair is the last two rows, "
     "an even number of reserved rows) and :356-370 (endpoint_geometry)",
     "A / H / boundary: the proximity pair is the last two rows, the reserved "
     "(non-data, non-proximity, non-zero-sum) rows are exactly the declared site "
     "rows and there is an even number of them, and H's zero-sum rows are its "
     "declared sum rows; an external endpoint: (rows, rows - 5, rows - 3), sites "
     "[d, d+1], proximity [d+2, d+3], one spare row d+4"),
    ("EX-2", "no claim reaches the proximity pair",
     "protocol.rs:242-244 (first half)",
     "no part's rows end past the first proximity row (A / H / boundary), and no "
     "claim puts weight on a proximity row (every kind)"),
    ("EX-3", "no claim part leaves the commitment",
     "protocol.rs:242-244 (second half)",
     "every part's rows lie inside the commitment"),
    ("EX-4", "a part on a site row has a nonzero coefficient",
     "protocol.rs:246-248 ('zero terminal mask coefficient')",
     "every part that covers a site row carries a nonzero coefficient"),
    ("EX-5", "an evaluation claim carries exactly two adjacent site rows",
     "protocol.rs:258-262",
     "every claim that is not point-free puts nonzero weight on exactly two site "
     "rows, and they are adjacent"),
    ("EX-6", "the pair sits at an even offset",
     "protocol.rs:259 ((touched[0] - site_rows[0]) % 2)",
     "the first site row a claim touches is an even number of rows past the "
     "first site row"),
    ("EX-7", "no weight on a spare reserved row",
     "the reduction's hypothesis (X); protocol.rs:379-384 for the endpoint",
     "no claim puts weight on a reserved row that is no site row (the endpoint's "
     "row d+4)"),
    ("EX-8", "the sum claim is masked by the zero-sum pair alone",
     "protocol.rs:252-257",
     "the point-free LAST claim of a commitment with sum rows touches no site "
     "row and covers both zero-sum rows with nonzero coefficients"),
    ("EX-9", "no unexpected sum claim",
     "protocol.rs:263 ('unexpected sum claim')",
     "no point-free claim before the last one, and none on a commitment without "
     "sum rows"),
    ("EX-10", "pairs are disjoint",
     "protocol.rs:268-270 (uses[r] != 1: the 'shared' face)",
     "no site row carries weight from two claims -- the OVERLAP refusal of "
     "finding F-4"),
    ("EX-11", "every reserved row is used",
     "protocol.rs:268-270 (uses[r] != 1: the 'unused' face)",
     "every site row carries weight from some claim"),
    ("EX-12", "the pair basis",
     "not in audit_claims; argument.rs:382-384 (build_claim's (cm, cm*U))",
     "a claim's two site-row weights are an Fp-basis of Fp2"),
    ("EX-13", "one column key per claim",
     "protocol.rs:203-205 (opening_groups_at)",
     "every part of a claim has the same column-weight key"),
    ("EX-14", "the group count is the schedule's",
     "protocol.rs:321-324 (check_opening) and :389 (the endpoint's one group)",
     "the first-occurrence groups number a_groups on A, h_groups on H, the "
     "boundary's sites on a boundary, and 1 on an endpoint"),
    ("EX-15", "the endpoint claim's shape",
     "protocol.rs:379-384 (check_endpoint_opening)",
     "an endpoint opens exactly one claim of three parts on rows 0..d, d and "
     "d+1, every coefficient nonzero"),
    ("EX-16", "every group coefficient is nonzero",
     "protocol.rs:296-301 (check_opening_challenges: 'zero group member "
     "coefficient')",
     "every replayed lambda is nonzero"),
]
CLAUSE_IDS = [c[0] for c in CLAUSES]
CLAUSE_NAME = {c[0]: c[1] for c in CLAUSES}
ENDPOINT_MASK_ROWS = 5  # protocol.rs:341, private_seam::MASK_ROWS


# ------------------------------------------------------------ part helpers
def part_rows(part, n):
    """protocol.rs:215-218: the rows a part touches at row width `n`."""
    r0 = part["offset"] // n
    return range(r0, r0 + -(-(1 << part["log_size"]) // n))


def part_key(part, log_n):
    """protocol.rs::part_key_at (:186-192)."""
    n = 1 << log_n
    ls = part["log_size"]
    c0, ln = (0, n) if ls >= log_n else (part["offset"] % n, 1 << ls)
    pt = part["point"]
    tail = () if not pt else tuple(tuple(f2_from_list(v)) for v in pt[max(0, ls - log_n):])
    return (tail, c0, ln)


def _zero(c):
    return c[0] % P == 0 and c[1] % P == 0


def point_free(claim):
    return all(len(p["point"]) == 0 for p in claim["parts"])


# ----------------------------------------------------------------- geometry
class Geometry:
    """The rows the audit is called with -- the gate's reading of ONE opening."""

    def __init__(self, *, name, kind, rows, data, sites, u, prox, spare,
                 sum_rows, want_groups, log_n, reserved):
        self.name = name
        self.kind = kind
        self.rows = rows
        self.data = list(data)
        self.sites = list(sites)
        self.u = list(u)
        self.prox = list(prox)
        self.spare = list(spare)
        self.sum_rows = None if sum_rows is None else list(sum_rows)
        self.want_groups = want_groups
        self.log_n = log_n
        self.reserved = list(reserved)

    @classmethod
    def of_view(cls, view):
        role = view.role
        rows = view.rows
        kinds = {r["row"]: r["kind"] for r in role["row_roles"]}
        data = [r for r in range(rows) if kinds[r] == "data"]
        prox = [r for r in range(rows) if kinds[r] == "prox"]
        u = list(view.u_rows)
        reserved = [r for r in range(rows)
                    if kinds[r] != "data" and r not in prox and r not in u]
        sites = list(role["site_rows"])
        kind = role["commitment_kind"]
        shape = view.shape
        if kind == "external-endpoint":
            want = 1
        elif kind == "internal-boundary":
            want = len(sites) // 2
        elif role["role"] == "A":
            want = shape.a_groups
        elif role["role"] == "H":
            want = shape.h_groups
        else:
            want = None
        return cls(name=view.name, kind=kind, rows=rows, data=data, sites=sites,
                   u=u, prox=prox, spare=[r for r in reserved if r not in sites],
                   sum_rows=role.get("sum_rows"), want_groups=want,
                   log_n=role["params"]["log_cols"], reserved=reserved)

    def with_sites(self, sites):
        """A copy whose declared site rows are `sites` (control X01)."""
        g = copy.copy(self)
        g.sites = list(sites)
        g.spare = [r for r in self.reserved if r not in g.sites]
        return g


# -------------------------------------------------------------------- audit
def audit(geom, claims, rws, lambdas):
    """Every clause on ONE opening; `rws[ci]` is claim ci's row weights, or
    None where they cannot be built (a part outside the commitment, or two
    column keys) -- the part-level clauses report why."""
    f = {cid: [] for cid in CLAUSE_IDS}
    rows = geom.rows
    n = 1 << geom.log_n
    site = set(geom.sites)
    endpoint = geom.kind == "external-endpoint"
    prox0 = geom.prox[0] if geom.prox else rows

    # EX-1 --------------------------------------------------------- geometry
    if endpoint:
        d = rows - ENDPOINT_MASK_ROWS
        if not (d > 0 and geom.data == list(range(d)) and geom.sites == [d, d + 1]
                and geom.prox == [d + 2, d + 3] and geom.spare == [d + 4]
                and not geom.u and not geom.sum_rows):
            f["EX-1"].append(
                f"endpoint rows {rows}: data {len(geom.data)}, sites {geom.sites}, "
                f"proximity {geom.prox}, spare {geom.spare}, not the geometry "
                f"({rows}, {d}, {d + 2})")
    else:
        if geom.prox != [rows - 2, rows - 1]:
            f["EX-1"].append(f"the proximity pair {geom.prox} is not the last two rows")
        if len(geom.sites) % 2:
            f["EX-1"].append(f"{len(geom.sites)} site rows: an odd number")
        if geom.spare:
            f["EX-1"].append(f"{len(geom.spare)} reserved row(s) that are no site row, "
                             f"first {geom.spare[0]}")
        stray = [r for r in geom.sites if r not in geom.reserved]
        if stray:
            f["EX-1"].append(f"declared site row {stray[0]} is not a reserved row")
        if sorted(geom.u) != sorted(geom.sum_rows or []):
            f["EX-1"].append(f"zero-sum rows {geom.u} are not the declared sum rows "
                             f"{geom.sum_rows}")

    # the claims ------------------------------------------------------------
    uses = {r: [] for r in geom.sites}
    groups = []
    last = len(claims) - 1
    n_eval = n_sum = 0
    for ci, c in enumerate(claims):
        parts = c["parts"]
        keys = [part_key(p, geom.log_n) for p in parts]
        if any(k != keys[0] for k in keys):
            f["EX-13"].append(f"claim {ci}: parts with different column weights")
        if keys and keys[0] not in groups:
            groups.append(keys[0])
        prs = [part_rows(p, n) for p in parts]
        if any(pr.start < 0 or pr.stop > rows for pr in prs):
            f["EX-3"].append(f"claim {ci}: a part leaves the commitment's {rows} rows")
        if not endpoint and any(pr.stop > prox0 for pr in prs):
            f["EX-2"].append(f"claim {ci}: a part reaches row {prox0} or beyond")
        for p, pr in zip(parts, prs):
            if _zero(p["coefficient"]) and any(r in site for r in pr):
                f["EX-4"].append(f"claim {ci}: a zero coefficient on a site row")
                break
        rw = rws[ci] if ci < len(rws) else None
        touched = None
        if rw is not None:
            if any(not _zero(rw[r]) for r in geom.prox):
                f["EX-2"].append(f"claim {ci}: weight on a proximity row")
            sp = [r for r in geom.spare if not _zero(rw[r])]
            if sp:
                f["EX-7"].append(f"claim {ci}: weight on spare row {sp[0]}")
            touched = [r for r in geom.sites if not _zero(rw[r])]
            for r in touched:
                uses[r].append(ci)
        if point_free(c) and geom.sum_rows and ci == last:
            n_sum += 1
            if touched:
                f["EX-8"].append(f"claim {ci} (the sum claim) touches site row {touched[0]}")
            for u in geom.sum_rows:
                if not any(u in pr and not _zero(p["coefficient"])
                           for p, pr in zip(parts, prs)):
                    f["EX-8"].append(f"claim {ci} (the sum claim) does not cover "
                                     f"zero-sum row {u}")
        elif point_free(c):
            f["EX-9"].append(
                f"claim {ci}: a point-free claim "
                + ("before the last" if geom.sum_rows else "on a commitment without sum rows"))
        else:
            n_eval += 1
            if touched is None:
                continue
            if len(touched) != 2 or touched[1] != touched[0] + 1:
                f["EX-5"].append(f"claim {ci}: site rows {touched[:4]}"
                                 f"{'...' if len(touched) > 4 else ''}, not one adjacent pair")
            if touched and geom.sites and (touched[0] - geom.sites[0]) % 2:
                f["EX-6"].append(f"claim {ci}: its pair starts at row {touched[0]}, an odd "
                                 f"offset from {geom.sites[0]}")
            if len(touched) == 2 and touched[1] == touched[0] + 1:
                a, b = rw[touched[0]], rw[touched[1]]
                if (a[0] * b[1] - a[1] * b[0]) % P == 0:
                    f["EX-12"].append(f"claim {ci}: its pair's weights are Fp-dependent")

    shared = [r for r in geom.sites if len(uses[r]) > 1]
    unused = [r for r in geom.sites if not uses[r]]
    if shared:
        r = shared[0]
        f["EX-10"].append(f"{len(shared)} site row(s) carry two claims, first row {r} "
                          f"(claims {uses[r][:2]})")
    if unused:
        f["EX-11"].append(f"{len(unused)} site row(s) carry no claim, first row {unused[0]}")
    if geom.want_groups is not None and len(groups) != geom.want_groups:
        f["EX-14"].append(f"{len(groups)} opening groups, the schedule declares "
                          f"{geom.want_groups}")
    if endpoint:
        d = rows - ENDPOINT_MASK_ROWS
        ok15 = (len(claims) == 1 and len(claims[0]["parts"]) == 3
                and part_rows(claims[0]["parts"][0], n) == range(0, d)
                and part_rows(claims[0]["parts"][1], n) == range(d, d + 1)
                and part_rows(claims[0]["parts"][2], n) == range(d + 1, d + 2)
                and all(not _zero(p["coefficient"]) for p in claims[0]["parts"]))
        if not ok15:
            f["EX-15"].append(f"{len(claims)} claim(s); the endpoint opens one claim of "
                              f"three parts on rows 0..{d}, {d}, {d + 1}, every "
                              "coefficient nonzero")
    if lambdas is not None:
        zl = [(gi, mi) for gi, lam in enumerate(lambdas) for mi, x in enumerate(lam)
              if _zero(x)]
        if zl:
            f["EX-16"].append(f"group {zl[0][0]} member {zl[0][1]}: lambda is zero")

    failing = [cid for cid in CLAUSE_IDS if f[cid]]
    return {
        "clauses": {cid: not f[cid] for cid in CLAUSE_IDS},
        "failing": failing,
        "findings": {cid: f[cid][:3] for cid in failing},
        "site_rows": len(geom.sites),
        "site_rows_used_exactly_once": sum(1 for r in geom.sites if len(uses[r]) == 1),
        "evaluation_claims": n_eval,
        "sum_claims": n_sum,
        "groups": len(groups),
        "groups_the_schedule_declares": geom.want_groups,
        "ok": not failing,
    }


def summary(res):
    """What a per-commitment record carries."""
    return {
        "clauses_checked": len(CLAUSE_IDS),
        "clauses_passed": sum(res["clauses"].values()),
        "clauses": dict(res["clauses"]),
        "failing": list(res["failing"]),
        "site_rows": res["site_rows"],
        "site_rows_used_exactly_once": res["site_rows_used_exactly_once"],
        "evaluation_claims": res["evaluation_claims"],
        "sum_claims": res["sum_claims"],
        "groups": res["groups"],
        "groups_the_schedule_declares": res["groups_the_schedule_declares"],
        "ok": res["ok"],
    }


# ----------------------------------------------------------------- controls
class _Old:
    """The inherited weight-level check's host: `rws`, `fail`, `facts`."""

    def __init__(self, name, rws):
        self.name = name
        self.rws = rws
        self.findings = []
        self.facts = {}

    def fail(self, what):
        self.findings.append(f"{self.name}: {what}")


class _Copy:
    """An in-memory copy of one opening's claim list, row weights, geometry
    and lambdas.  Nothing on disk is ever written."""

    def __init__(self, view):
        self.view = view
        self.claims = list(view.role["claims"])
        self.rws = list(view.rws)
        self.geom = Geometry.of_view(view)
        self.n = 1 << self.geom.log_n
        self.lambdas = [list(x) for x in view._lambdas]

    def weights(self, claim):
        rows = self.view.rows
        for p in claim["parts"]:
            pr = part_rows(p, self.n)
            if pr.start < 0 or pr.stop > rows:
                return None
        try:
            rw, _ = self.view.sp.claim_rows(claim, rows)
        except (ValueError, AssertionError, IndexError):
            return None
        return rw

    def claim(self, ci):
        """A deep copy of claim ci, to be edited and then `put` back."""
        return copy.deepcopy(self.claims[ci])

    def put(self, ci, claim):
        self.claims[ci] = claim
        self.rws[ci] = self.weights(claim)

    def append(self, claim):
        self.claims.append(claim)
        self.rws.append(self.weights(claim))

    def site_parts(self, claim):
        """The parts of a claim that cover a site row, in order."""
        site = set(self.geom.sites)
        return [p for p in claim["parts"] if any(r in site for r in part_rows(p, self.n))]


def _old_verdict(c):
    if any(rw is None for rw in c.rws):
        return {"applicable": False,
                "why": "a claim's row weights cannot be built, so the weight-level "
                "check has nothing to read"}
    host = _Old(c.view.name, c.rws)
    ok = RoleView._check_pair_schedule(host, c.view.data_rows, c.view.other_rows,
                                       c.view.prox_rows, c.view.u_rows)
    return {"applicable": True, "h_pair": ok, "findings": host.findings[:2]}


def _control(view, cid, what, mutate):
    honest = audit(Geometry.of_view(view), view.role["claims"], view.rws, view._lambdas)
    c = _Copy(view)
    mutate(c)
    pert = audit(c.geom, c.claims, c.rws, c.lambdas)
    return {
        "commitment": view.name,
        "target_clause": cid,
        "target_clause_name": CLAUSE_NAME[cid],
        "what": what,
        "honest": {"target_clause_holds": honest["clauses"][cid],
                   "every_clause_holds": honest["ok"]},
        "perturbed": {"target_clause_holds": pert["clauses"][cid],
                      "clauses_that_fail": pert["failing"],
                      "finding": (pert["findings"].get(cid) or ["<none>"])[0]},
        "the_old_weight_level_check_on_the_same_weights": _old_verdict(c),
        "fires": honest["clauses"][cid] and honest["ok"] and not pert["clauses"][cid],
    }


def exclusivity_controls(bundle, views):
    """One control per clause (some clauses more than one) on stage 0's `A`,
    `H`, its input endpoint and, for a run, the first internal boundary."""
    st = bundle.stages[0]
    A = views[st.key("A")]
    H = views[st.key("H")]
    E = views[st.key("Input")]
    B = views.get("B0")
    out = {}

    def add(name, view, cid, what, mutate):
        out[name] = _control(view, cid, what, mutate)

    def pair_of(c, ci):
        rw = c.rws[ci]
        return [r for r in c.geom.sites if not _zero(rw[r])]

    # EX-1
    def x01(c):
        c.geom = c.geom.with_sites(c.geom.sites[:-2])
    add("X01_A_last_reserved_pair_declared_spare", A, "EX-1",
        f"{A.name}: its last reserved pair, rows {A.role['site_rows'][-2:]}, declared "
        "spare -- two reserved rows that are no site row", x01)

    # EX-2 / EX-3 / EX-4
    def x02(c):
        cl = c.claim(0)
        c.site_parts(cl)[1]["offset"] = c.geom.prox[0] * c.n
        c.put(0, cl)
    add("X02_A_claim_part_on_the_proximity_row", A, "EX-2",
        f"{A.name}: claim 0's second mask part moved onto the proximity row "
        f"{A.role['prox_row']}", x02)

    def x03(c):
        cl = c.claim(0)
        c.site_parts(cl)[1]["offset"] = (c.geom.rows + 3) * c.n
        c.put(0, cl)
    add("X03_A_claim_part_outside_the_commitment", A, "EX-3",
        f"{A.name}: claim 0's second mask part moved three rows past the last row", x03)

    def x04(c):
        cl = c.claim(0)
        c.site_parts(cl)[0]["coefficient"] = [0, 0]
        c.put(0, cl)
    add("X04_A_zero_mask_coefficient", A, "EX-4",
        f"{A.name}: claim 0's first mask coefficient set to zero", x04)

    # EX-5 (the four shapes finding F-6 lists)
    def x05a(c):
        cl = c.claim(0)
        sp = c.site_parts(cl)
        cl["parts"] = [p for p in cl["parts"] if not any(p is q for q in sp)]
        c.put(0, cl)
    add("X05a_A_evaluation_claim_with_no_site_row", A, "EX-5",
        f"{A.name}: claim 0's two mask parts removed (0 site rows)", x05a)

    def x05b(c):
        cl = c.claim(0)
        drop = c.site_parts(cl)[1]
        cl["parts"] = [p for p in cl["parts"] if p is not drop]
        c.put(0, cl)
    add("X05b_A_evaluation_claim_with_one_site_row", A, "EX-5",
        f"{A.name}: claim 0's second mask part removed (1 site row)", x05b)

    def x05c(c):
        # a copy of claim 0's OWN second mask part (so the column key is
        # claim 0's and the weights can be built), placed on claim 1's first
        # site row
        cl = c.claim(0)
        extra = copy.deepcopy(c.site_parts(cl)[1])
        extra["offset"] = c.site_parts(c.claims[1])[0]["offset"]
        cl["parts"].append(extra)
        c.put(0, cl)
    add("X05c_A_evaluation_claim_with_three_site_rows", A, "EX-5",
        f"{A.name}: claim 0 given a third mask part, on claim 1's first site row "
        "(3 site rows)", x05c)

    def x05d(c):
        cl = c.claim(0)
        c.site_parts(cl)[1]["offset"] = c.site_parts(c.claims[1])[1]["offset"]
        c.put(0, cl)
    add("X05d_A_non_adjacent_pair", A, "EX-5",
        f"{A.name}: claim 0's second mask part moved onto claim 1's second row "
        "(a non-adjacent pair)", x05d)

    # EX-6
    def x06(c):
        cl = c.claim(0)
        for p in c.site_parts(cl):
            p["offset"] += c.n
        c.put(0, cl)
    add("X06_A_pair_shifted_one_row", A, "EX-6",
        f"{A.name}: claim 0's pair shifted down one row (an odd offset)", x06)

    # EX-7
    def x07(c):
        cl = c.claim(0)
        cl["parts"][2]["offset"] = c.geom.spare[0] * c.n
        c.put(0, cl)
    add("X07_endpoint_mask_part_on_the_spare_row", E, "EX-7",
        f"{E.name}: its claim's second mask part moved onto the spare row", x07)

    # EX-8
    def x08a(c):
        ci = len(c.claims) - 1
        cl = c.claim(ci)
        p = copy.deepcopy(cl["parts"][0])
        p["offset"] = c.geom.sites[0] * c.n
        cl["parts"].append(p)
        c.put(ci, cl)
    add("X08a_H_sum_claim_touches_a_site_row", H, "EX-8",
        f"{H.name}: the sum claim given a point-free part on the first site row", x08a)

    def x08b(c):
        ci = len(c.claims) - 1
        cl = c.claim(ci)
        u1 = c.geom.sum_rows[1]
        cl["parts"] = [p for p in cl["parts"] if u1 not in part_rows(p, c.n)]
        c.put(ci, cl)
    add("X08b_H_sum_claim_misses_the_second_zero_sum_row", H, "EX-8",
        f"{H.name}: the sum claim's parts on zero-sum row {H.role['sum_rows'][1]} removed",
        x08b)

    # EX-9
    def x09a(c):
        c.claims.insert(0, c.claims.pop())
        c.rws.insert(0, c.rws.pop())
    add("X09a_H_sum_claim_first", H, "EX-9",
        f"{H.name}: the sum claim moved to the front of the claim list", x09a)

    def x09b(c):
        c.append(copy.deepcopy(H.role["claims"][-1]))
    add("X09b_H_sum_claim_appended_to_A", A, "EX-9",
        f"{A.name}: {H.name}'s sum claim appended (A has no sum rows)", x09b)

    # EX-10 -- the F-4 control first
    def x10a(c):
        t0 = pair_of(c, 0)[0]
        cl = c.claim(1)
        sp = c.site_parts(cl)
        sp[0]["offset"] = (t0 + 1) * c.n
        sp[1]["offset"] = (t0 + 2) * c.n
        c.put(1, cl)
    add("X10a_A_overlapping_pairs", A, "EX-10",
        f"{A.name}: claim 1's pair moved to (s0+1, s0+2), overlapping claim 0's "
        "(s0, s0+1) in one row -- finding F-4's case on real bytes", x10a)

    def x10b(c):
        cl = c.claim(1)
        for a, b in zip(c.site_parts(cl), c.site_parts(c.claims[0])):
            a["offset"] = b["offset"]
        c.put(1, cl)
    add("X10b_A_one_pair_shared_by_two_claims", A, "EX-10",
        f"{A.name}: claim 1's pair moved onto claim 0's pair", x10b)

    if B is not None:
        def x10c(c):
            cl = c.claim(1)
            for a, b in zip(c.site_parts(cl), c.site_parts(c.claims[0])):
                a["offset"] = b["offset"]
            c.put(1, cl)
        add("X10c_boundary_site1_on_site0s_pair", B, "EX-10",
            f"{B.name}: the site-1 claim's pair moved onto site 0's pair", x10c)

    # EX-11
    def x11(c):
        c.claims.pop()
        c.rws.pop()
    add("X11_A_last_claim_dropped", A, "EX-11",
        f"{A.name}: its last claim dropped -- one reserved pair unused, nothing "
        "shared", x11)

    # EX-12
    def x12(c):
        cl = c.claim(0)
        a, b = c.site_parts(cl)[:2]
        x = f2_from_list(a["coefficient"])
        b["coefficient"] = [2 * x[0] % P, 2 * x[1] % P]
        c.put(0, cl)
    add("X12_A_pair_weights_Fp_dependent", A, "EX-12",
        f"{A.name}: claim 0's second mask coefficient set to twice the first "
        "(an Fp-dependent pair)", x12)

    # EX-13
    def x13(c):
        cl = c.claim(0)
        p = cl["parts"][-1]
        p["point"] = p["point"][:-1] + [[1, 2]]
        c.put(0, cl)
    add("X13_A_parts_with_different_column_weights", A, "EX-13",
        f"{A.name}: the last coordinate of claim 0's last part's point changed", x13)

    # EX-14
    def x14(c):
        log_n = c.geom.log_n
        tail0, c00, ln0 = A.keys[0]
        pick = None
        for gi, members in enumerate(A.groups):
            if gi == 0 or len(members) != 1:
                continue
            cl = c.claims[members[0]]
            if all(p["log_size"] >= log_n and len(p["point"]) == p["log_size"]
                   for p in cl["parts"]):
                pick = members[0]
                break
        if pick is None or not tail0 or (c00, ln0) != (0, 1 << log_n):
            raise ValueError("no singleton group to re-key into group 0")
        cl = c.claim(pick)
        for p in cl["parts"]:
            lr = p["log_size"] - log_n
            p["point"] = p["point"][:lr] + [[v[0], v[1]] for v in tail0]
        c.put(pick, cl)
        c.x14_claim = pick
    add("X14_A_singleton_group_rekeyed_into_group_0", A, "EX-14",
        f"{A.name}: the first singleton group's claim given group 0's column key "
        "(its row weights unchanged) -- one group fewer than the schedule's", x14)

    # EX-15
    def x15a(c):
        c.append(copy.deepcopy(c.claims[0]))
    add("X15a_endpoint_two_claims", E, "EX-15",
        f"{E.name}: its one claim opened twice", x15a)

    def x15b(c):
        cl = c.claim(0)
        cl["parts"][1]["coefficient"] = [0, 0]
        c.put(0, cl)
    add("X15b_endpoint_zero_coefficient", E, "EX-15",
        f"{E.name}: its claim's first mask coefficient set to zero", x15b)

    # EX-16
    def x16(c):
        c.lambdas[0][0] = (0, 0)
    add("X16_A_zero_group_coefficient", A, "EX-16",
        f"{A.name}: group 0's first replayed lambda set to zero", x16)

    names = list(out)
    exercised = sorted({out[k]["target_clause"] for k in names if out[k]["fires"]},
                       key=CLAUSE_IDS.index)
    missed = [cid for cid in CLAUSE_IDS if cid not in exercised]
    return {
        "what": "one negative control per clause of exclusivity (ruling GC-2, "
        "finding F-6): each perturbs an in-memory COPY of one opening's claim "
        "list (or its declared geometry, or one replayed lambda), fires iff its "
        "target clause holds on the honest opening and fails on the perturbed "
        "one, and records every clause the perturbation broke and what the OLD "
        "weight-level H-pair check made of the same weights",
        "clauses": [{"id": c[0], "name": c[1], "source": c[2], "what": c[3]}
                    for c in CLAUSES],
        "controls": out,
        "control_names": names,
        "clauses_exercised": exercised,
        "clauses_not_exercised": missed,
        "every_clause_exercised": not missed,
        "all_fire": all(out[k]["fires"] for k in names),
        "the_old_check_accepted": [k for k in names
                                   if out[k]["the_old_weight_level_check_on_the_same_weights"]
                                   .get("h_pair") is True],
        "ok": all(out[k]["fires"] for k in names) and not missed,
    }
