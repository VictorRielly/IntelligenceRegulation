"""The joint figures of a RUN: the boundary, the three roles, the whole run.

`zk60_native_jv_joint` states the joint model in full and this module uses
its `Block` / `JointSystem` unchanged -- they are shape-agnostic, taking the
message width as an argument.  What is new here is a RUN's identifications
and ruling M-8's restricted rank.  **[ROUND 9l]** every joint system here is
a `RunJointSystem`: the same ranks, with the EXACT u-row term of ruling GC-2
in place of the toy's per-indicator solve (which is kept beside it).

THE THREE THINGS COMPUTED

(a) **The boundary, restricted to its reserved rows.**  Over ALL rows every
    degenerate geometry looks like full rank; only the restriction to the
    reserved block separates them (`ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md`
    A1.4, ruling M-1).  The boundary commitment of a run has two claim sites
    -- block k's output-equality slot 22 and block k+1's input-equality slot
    21 -- discharged by ONE opening with two singleton groups, so its
    generators are `2 (G + 1) = 6` real vectors and its reserved block is the
    two claim pairs plus the proximity pair, `2 sites + 2 = 6` columns.
    Honest: rank 6 of 6, disclosed 0.

(b) **The three roles of one boundary plane.**  The same hidden plane sits in
    block k's activation commitment (its output plane), in the boundary
    commitment, and in block k+1's activation commitment (its input plane).
    The identification is read from `claim_sources`, never from the role
    names: the role name of a private table names the CLAIM SITE, and stage
    k's `"Output"` site and stage k+1's `"Input"` site are the same
    commitment only because that commitment's `claim_sources` says so
    (format finding U-8).  One generator system over the three commitments,
    with the shared DATA coordinates identified, gives the joint disclosed
    dimension; it is compared with the sum of the three parts.

    Is `joint == sum` a theorem here?  Only the DATA coordinates are shared
    -- no blinding source is (each commitment draws its own mask rows,
    proximity rows and pads), so the non-data block of the joint generator
    matrix is block diagonal by role and its rank is the sum of the three.
    Identifying data coordinates can then only LOWER `rank(all)`, so
    `k0_joint <= sum k0_r`; with every part 0 the joint is forced to 0 and
    the equality is a theorem GIVEN those two facts, both of which the module
    computes rather than assuming (`non_data_block_is_block_diagonal`, the
    parts).  It is NOT a theorem in general: the controls below share a
    blinding row and the joint rises above the sum.

(c) **The whole run.**  One system over every commitment of every stage --
    A, H, the masking commitment M, the external endpoints and the internal
    boundaries -- with every shared plane identified.  Its size is reported
    with the figure.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

from zk60_native_jv_field import F2_ZERO, P, f2_from_list, rank, row_reduce, det_mod_p
from zk60_native_jv_joint import Block, JointSystem
from zk60_native_rg_pcs import EXACT_U_FORM, exact_u_term


class RunJointSystem(JointSystem):
    """**[ROUND 9l, ruling GC-2 / finding F-3]** `JointSystem` with the EXACT
    u-row term.

    `JointSystem` lives in the toy module, whose bytes are hashed into the
    toy gates' evidence, so it is not edited; this subclass recomputes
    `disclosed` with the same ranks and the same facts, and replaces only
    the u-row figure by `u* = rank Γ_{D∪N'} − rank Γ_{N'} − k0` over the
    joint coordinate classes (`N'` the non-data classes holding no zero-sum
    row).  The toy's per-indicator solve is still computed and reported
    beside it.  A system with no zero-sum row returns exactly the facts
    `JointSystem.disclosed` returns.
    """

    def disclosed(self, msg_width=None):
        if msg_width is None:
            raise ValueError("RunJointSystem.disclosed needs the run's message width")
        gens, owner = self.generators()
        data_cols = self.columns("data")
        other_cols = self.columns("non-data")
        r_all = rank(gens, len(self.classes))
        r_other = rank([[g[c] for c in other_cols] for g in gens], len(other_cols))
        k0 = r_all - r_other
        facts = {
            "generators": len(gens),
            "coordinate_classes": len(self.classes),
            "data_classes": len(data_cols),
            "non_data_classes": len(other_cols),
            "rank_all": r_all,
            "rank_on_non_data": r_other,
            "k0": k0,
            "free_fp": msg_width * k0,
        }
        u_dim, u_detail = JointSystem._u_term(self, gens, data_cols, other_cols)
        if u_detail.get("u_classes"):
            u_cls = {self.index[(b.name, r)] for b in self.blocks for r in b.u_rows
                     if (b.name, r) not in self.removed}
            n_prime = [c for c in other_cols if c not in u_cls]
            exact, r_dn, r_n = exact_u_term(gens, data_cols, n_prime, k0)
            u_detail = dict(u_detail)
            u_detail.update({
                "extra_dimension_beyond_k0": exact,
                "exact_form": EXACT_U_FORM,
                "rank_gamma_on_data_and_n_prime": r_dn,
                "rank_gamma_on_n_prime": r_n,
                "per_indicator_term_fp": u_dim,
                "per_indicator_equals_exact": u_dim == exact,
            })
            u_dim = exact
        facts["u_row_term_fp"] = u_dim
        facts["u_row_detail"] = u_detail
        facts["disclosed_fp"] = msg_width * k0 + u_dim
        return facts


IO_SITE_ROLES = ("Input", "Output")

# **RULING R-3 (ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md, 2026-09-20),
# carried on every joint figure this module reports.**  Recorded in round 4;
# it corrects rounds 1-3's WORDING and changes none of their numbers.
RULING_R3 = (
    "ruling R-3: `joint == sum of the parts` is a CONSISTENCY CHECK of this "
    "model's coordinate classes, NOT evidence that the commitments' blinding "
    "is independent.  The checker built the counterexample: two DISTINCT "
    "blinding rows whose VALUES coincide score exactly like an honest run "
    "(joint 0 = sum 0) while disclosing 1,024 field elements at this shape.  "
    "Independence across the 4L+1 commitments rests on the generator and the "
    "draw discipline (gap G-R4), is to be machine-asserted elsewhere, and is "
    "not established by anything in this figure"
)


# --------------------------------------------------------- the blocks
def block_from_view(view):
    """The joint-system block of a `RunRoleView` that has already run."""
    return Block(
        name=view.name,
        rows=view.rows,
        data_rows=view.data_rows,
        u_rows=view.u_rows,
        gens_f2=view.rhos + [view.prox_rho],
    )


def mask_block(stage):
    """The masking commitment M of one stage as a block: rows, no data.

    `zk.rs::mask_commit` gives M `2*slots + 4` rows and its opening publishes
    ONE row combination, the proximity vector, whose coefficients are the
    `2*slots + 2` replayed challenges on the `a` and `b` rows and 1 on each
    `u` row.  No row of M carries witness data, so its contribution to the
    run's `k0` is nil -- computed here, not argued.
    """
    m = stage.mask
    rows = m["rows"]
    rhos = [f2_from_list(v) for v in m["proximity_rhos"]]
    vec = list(rhos) + [(1, 0)] * (rows - len(rhos))
    return Block(
        name=f"M@{stage.index}",
        rows=rows,
        data_rows=[],
        u_rows=[],
        gens_f2=[vec],
        is_data_bearing=False,
    )


# ------------------------------------------------ the shared coordinates
def resolve_claim_site(bundle, stage_index, slot_index):
    """Which opening discharges the claim raised by (stage, slot), and where.

    This is finding U-8 obeyed: the answer comes from `claim_sources`, the
    only field that says that stage k's `"Output"` site and stage k+1's
    `"Input"` site are the SAME commitment.
    """
    for st in bundle.stages:
        for r in st.roles:
            base = 0
            for src in r["claim_sources"]:
                if src["stage"] == stage_index and src["slot"] == slot_index:
                    return {
                        "stage": st,
                        "opening": r,
                        "key": st.key(r["role"]),
                        "first_claim": base,
                        "claims": src["claims"],
                    }
                base += src["claims"]
    return None


def discover_shared_planes(bundle):
    """Every (A row) ~ (IO commitment row) identification of the whole run.

    A slot qualifies when its private tables are exactly one `A` table and
    one IO-site table, the two claims' first parts have the same `log_size`
    and the same evaluation point (the slot's tau), and the slot is a
    Standalone zero-check -- so a zero sum at a random tau says the two
    planes are equal and their rows are the same unknowns.

    The third condition is a property of the pinned layout that a capture
    does carry: `arguments[s]["kind"] == "Standalone"`.
    """
    n = bundle.shape.cols
    out = {"pairs": [], "slots": [], "findings": [], "source_facts": [
        "private_block/argument.rs: the two endpoint-equality slots run "
        "eq(tau) * (A_plane - IO_plane) over log_size variables",
        "private_block/layout.rs SLOT_KINDS marks them Standalone, so the sum they "
        "prove is zero and the published scalar is the CFS mask term alone; the "
        "capture carries the kind as data",
        "the commitment behind an IO SITE is named by claim_sources, never by the "
        "site's role name (run-capture format finding U-8)",
    ]}
    for st in bundle.stages:
        k = st.index
        a_key = st.key("A")
        for arg in st.slots:
            privates = [t for t in arg["tables"] if t["kind"] == "private"]
            roles = [t["role"] for t in privates]
            if len(privates) != 2 or "A" not in roles:
                continue
            ends = [r for r in roles if r in IO_SITE_ROLES]
            if len(ends) != 1:
                continue
            a_tab = privates[roles.index("A")]
            o_tab = privates[1 - roles.index("A")]
            site = resolve_claim_site(bundle, k, arg["slot"])
            if site is None:
                out["findings"].append(
                    f"stage {k} slot {arg['slot']}: no opening of the run declares it "
                    "as the source of a claim (claim_sources)"
                )
                continue
            # WHICH claim of the opening this site raises is `claim_sources`'
            # accumulation, NOT the table's own `claim` field: for an IO table
            # of a run that field is the index inside the STAGE's own claim
            # pair and is always 0, so a tool that trusted it would attribute
            # both of a boundary's claims to claim 0 (see the gate's report).
            ci = site["first_claim"]
            if site["claims"] != 1:
                out["findings"].append(
                    f"stage {k} slot {arg['slot']}: claim_sources gives it "
                    f"{site['claims']} claims on {site['key']}, not one"
                )
                continue
            want_pair = site["opening"]["site_rows"][2 * ci]
            if o_tab["mask_row"] != want_pair:
                out["findings"].append(
                    f"stage {k} slot {arg['slot']}: its {o_tab['role']} table uses mask "
                    f"row {o_tab['mask_row']}, but claim_sources puts this slot at claim "
                    f"{ci} of {site['key']}, whose reserved pair starts at {want_pair}"
                )
                continue
            a_cl = st.role("A")["claims"][a_tab["claim"]]
            o_cl = site["opening"]["claims"][ci]
            ap, ep = a_cl["parts"][0], o_cl["parts"][0]
            if ap["log_size"] != ep["log_size"] or ap["point"] != ep["point"]:
                out["findings"].append(
                    f"stage {k} slot {arg['slot']}: the A claim and the {o_tab['role']} "
                    f"claim of {site['key']} are not the same evaluation "
                    "(different log_size or point) -- the two planes are not shown equal"
                )
                continue
            if arg["kind"] != "Standalone":
                out["findings"].append(
                    f"stage {k} slot {arg['slot']}: kind {arg['kind']!r} is not "
                    "Standalone, so its sum is not a zero-check"
                )
                continue
            nrows = 1 << max(0, ap["log_size"] - bundle.shape.log_cols)
            a0, e0 = ap["offset"] // n, ep["offset"] // n
            out["pairs"].extend(
                [((a_key, a0 + i), (site["key"], e0 + i)) for i in range(nrows)]
            )
            out["slots"].append(
                {
                    "stage": k,
                    "slot": arg["slot"],
                    "name": arg["name"],
                    "site_role": o_tab["role"],
                    "commitment": site["key"],
                    "commitment_kind": site["opening"]["commitment_kind"],
                    "boundary": site["opening"]["boundary"],
                    "opened_at_stage": site["stage"].index,
                    "log_size": ap["log_size"],
                    "rows": nrows,
                    "a_rows": [a0 + i for i in range(nrows)],
                    "commitment_rows": [e0 + i for i in range(nrows)],
                    "same_evaluation_point": True,
                    "claim_index_in_the_opening": ci,
                    "reserved_pair_first_row": want_pair,
                    "table_claim_field": o_tab["claim"],
                }
            )
    return out


# ------------------------------------------------------ (a) the boundary
def boundary_reserved_figure(bundle, view, k, merge_pairs=False, drop_prox_row=False):
    """Ruling M-8(a): boundary k's disclosed dimension on its RESERVED rows.

    `merge_pairs` models the shared-pair control (the two claim sites' pairs
    made the same coordinates); `drop_prox_row` models the single-proximity-
    row geometry (`data + 2*sites + 1`).  Both are perturbations of the MODEL
    only: no captured byte is altered.
    """
    b = bundle.boundary(k)
    sites = [tuple(b["site_rows"][2 * i : 2 * i + 2]) for i in range(b["sites"])]
    prox = (b["prox_row"], b["prox_row"] + 1)
    reserved = [r for p in sites for r in p] + list(prox)
    if drop_prox_row:
        reserved = [r for p in sites for r in p] + [prox[0]]
    gens = view._p1_rows()
    g = len(gens)
    if merge_pairs:
        # columns: pair 0's two rows (carrying pair 1's weights too), then prox
        cols = []
        for j in range(2):
            col = []
            for row in gens:
                v = row[sites[0][j]]
                for p in sites[1:]:
                    v = (v + row[p[j]]) % P
                col.append(v)
            cols.append(col)
        for r in (reserved[-2:] if not drop_prox_row else reserved[-1:]):
            cols.append([row[r] for row in gens])
        block = [[cols[c][i] for c in range(len(cols))] for i in range(g)]
        names = ["pair0[0]+pair1[0]", "pair0[1]+pair1[1]"] + [
            f"row {r}" for r in (reserved[-2:] if not drop_prox_row else reserved[-1:])
        ]
    else:
        block = [[row[i] for i in reserved] for row in gens]
        names = [f"row {r}" for r in reserved]
    _, pivots = row_reduce(block, len(names))
    out = {
        "boundary": k,
        "commitment": view.name,
        "rows": b["rows"],
        "data_rows": b["data_rows"],
        "sites": b["sites"],
        "site_rows": b["site_rows"],
        "prox_row": b["prox_row"],
        "row_rule": b["row_rule"],
        "reserved_columns": names,
        "generators": g,
        "groups": len(view.groups),
        "rank_on_the_reserved_block": len(pivots),
        "disclosed_on_the_reserved_block_fp": g - len(pivots),
        "full_row_rank": len(pivots) == g,
        "pivot_columns": [names[c] for c in pivots],
        "rank_over_all_rows": rank([list(r) for r in gens], view.rows),
    }
    if len(pivots) == g:
        sub = [[block[r][c] for c in pivots] for r in range(g)]
        out["determinant"] = det_mod_p(sub)
        out["determinant_nonzero"] = out["determinant"] != 0
    else:
        out["determinant"] = None
        out["determinant_nonzero"] = False
    return out


# --------------------------------------------- (b) the three-role figure
def three_role_figure(bundle, views, shared, k, extra_identifications=(),
                      msg_width=None):
    """Ruling M-8(b): A_k, B_k and A_{k+1} as ONE generator system."""
    msg_width = bundle.shape.cols if msg_width is None else msg_width
    bkey = f"B{k}"
    names = [f"A@{k}", bkey, f"A@{k+1}"]
    blocks = [block_from_view(views[n]) for n in names]
    ids, by_slot = [], []
    for rec in shared["slots"]:
        if rec["commitment"] != bkey:
            continue
        akey = f"A@{rec['stage']}"
        ids.extend(
            [((akey, a), (bkey, e)) for a, e in zip(rec["a_rows"], rec["commitment_rows"])]
        )
        by_slot.append(rec)
    ids.extend(tuple(p) for p in extra_identifications)

    parts, part_detail = {}, {}
    for blk in blocks:
        f = RunJointSystem([blk]).disclosed(msg_width=msg_width)
        parts[blk.name] = f["disclosed_fp"]
        part_detail[blk.name] = {
            "k0": f["k0"],
            "rank_all": f["rank_all"],
            "rank_on_non_data": f["rank_on_non_data"],
            "disclosed_fp": f["disclosed_fp"],
            "rows": blk.rows,
            "data_rows": len(blk.data_rows),
        }
    js = RunJointSystem(blocks, identifications=ids)
    jf = js.disclosed(msg_width=msg_width)
    unmerged = RunJointSystem(blocks).disclosed(msg_width=msg_width)
    block_diagonal = not js.shared_non_data_classes and not js.mixed_classes
    total = sum(parts.values())
    findings = list(js.findings)
    if jf["disclosed_fp"] != total:
        findings.append(
            f"boundary {k}: the three-role joint {jf['disclosed_fp']} differs from the "
            f"sum of the parts {total}"
        )
    return {
        "boundary": k,
        "roles": names,
        "what": "the same hidden plane under three commitments: block k's activation "
        "commitment (its output plane), the boundary commitment, and block k+1's "
        "activation commitment (its input plane)",
        "identification_source": "claim_sources / internal_boundaries[].claim_sites, "
        "not the role names (finding U-8)",
        "equality_slots": by_slot,
        "identified_row_pairs": [{"a": f"{a[0]}[{a[1]}]", "b": f"{b[0]}[{b[1]}]"}
                                 for a, b in ids],
        "identified_rows": len(ids),
        "coordinate_classes": jf["coordinate_classes"],
        "generators": jf["generators"],
        "classes_shared_between_roles_data": len(js.shared_data_classes),
        "classes_shared_between_roles_non_data": len(js.shared_non_data_classes),
        "non_data_block_is_block_diagonal_by_role": block_diagonal,
        "parts_fp": parts,
        "parts_detail": part_detail,
        "sum_of_parts_fp": total,
        "joint_fp": jf["disclosed_fp"],
        "joint_detail": jf,
        "joint_without_the_identifications_fp": unmerged["disclosed_fp"],
        "aliasing_lost_to_the_identification_fp": (
            unmerged["disclosed_fp"] - jf["disclosed_fp"]
        ),
        "joint_equals_sum_of_parts": jf["disclosed_fp"] == total,
        "ruling_R3": RULING_R3,
        "is_that_a_theorem_here": {
            "answer": bool(block_diagonal and total == 0),
            "why": (
                "only DATA coordinates are shared -- no blinding source is -- so the "
                "non-data block is block diagonal by role and its rank is the sum of "
                "the three; identifying data coordinates can then only LOWER rank(all), "
                "so k0_joint <= sum k0_r, and with every part 0 the joint is forced to "
                "0.  Both facts are COMPUTED above, and the controls show the equality "
                "breaking when a blinding row IS shared"
                if block_diagonal and total == 0
                else "no: a non-data coordinate is shared between two roles, or a part "
                "is nonzero, so the block structure does not force the equality"
            ),
        },
        "findings": findings,
        "ok": not findings and jf["disclosed_fp"] == total,
    }


# --------------------------------------------------- (c) the whole run
def run_wide_figure(bundle, views, shared, include_mask=True, subset=None,
                    extra_identifications=(), label="whole run"):
    """Ruling M-8(c): one system over every commitment named by `subset`.

    `subset` is a list of block names; None means every commitment of every
    stage.  The size of the system is reported with the figure so that a
    reader knows what was ranked.
    """
    msg_width = bundle.shape.cols
    blocks = []
    for st in bundle.stages:
        for r in st.roles:
            key = st.key(r["role"])
            if subset is None or key in subset:
                blocks.append(block_from_view(views[key]))
        if include_mask and (subset is None or f"M@{st.index}" in subset):
            blocks.append(mask_block(st))
    have = {b.name for b in blocks}
    ids = [
        (tuple(a), tuple(b))
        for a, b in shared["pairs"]
        if a[0] in have and b[0] in have
    ] + [tuple(p) for p in extra_identifications]

    parts = {}
    for blk in blocks:
        parts[blk.name] = RunJointSystem([blk]).disclosed(msg_width=msg_width)["disclosed_fp"]
    js = RunJointSystem(blocks, identifications=ids)
    jf = js.disclosed(msg_width=msg_width)
    total = sum(parts.values())
    block_diagonal = not js.shared_non_data_classes and not js.mixed_classes
    findings = list(js.findings)
    if jf["disclosed_fp"] != total:
        findings.append(
            f"{label}: the joint {jf['disclosed_fp']} differs from the sum of the parts "
            f"{total}"
        )
    return {
        "label": label,
        "commitments": [b.name for b in blocks],
        "rows_total": sum(b.rows for b in blocks),
        "generators": jf["generators"],
        "coordinate_classes": jf["coordinate_classes"],
        "matrix": f"{jf['generators']} x {jf['coordinate_classes']}",
        "identified_rows": len(ids),
        "classes_shared_between_roles_data": len(js.shared_data_classes),
        "classes_shared_between_roles_non_data": len(js.shared_non_data_classes),
        "non_data_block_is_block_diagonal_by_role": block_diagonal,
        "parts_fp": parts,
        "sum_of_parts_fp": total,
        "joint_fp": jf["disclosed_fp"],
        "joint_detail": jf,
        "joint_equals_sum_of_parts": jf["disclosed_fp"] == total,
        "ruling_R3": RULING_R3,
        "findings": findings,
        "ok": not findings and jf["disclosed_fp"] == total,
    }
