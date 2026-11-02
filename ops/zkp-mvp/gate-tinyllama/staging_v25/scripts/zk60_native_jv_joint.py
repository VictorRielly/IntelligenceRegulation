"""Stage 4, done properly: ONE generator system over the whole receipt.

WHY THIS FILE EXISTS.  Until 2026-09-20 the gate's stage 4 did not compute
anything: `zk60_native_joint_view.py` set `joint_equals_sum_of_parts = True`
as a literal and its verdict with it, so the stage could not fail, and every
statement that quoted "joint disclosed dimension 4, equal to the sum of the
parts" was quoting four MARGINALS and an assumption (the security owner's
ruling G-1, `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`).  This module replaces
the literal with a computation.

THE MODEL, stated exactly.  Each commitment of the profile holds `rows`
committed rows; row i is the pair z_i = (msg_i, pad_i) in Fp^256 x Fp^256
(see `zk60_native_jv_pcs` for the per-commitment model, which this one
extends).  Write the JOINT unknown vector as every commitment's rows
side by side.  A coordinate of that vector is a triple (role, row,
position).  Two coordinates are THE SAME UNKNOWN when the protocol makes
them so; §"shared coordinates" below says which, and how the capture itself
says it.

    disclosed_joint = dim_Fp ( F_joint  intersect  T_joint )

with F_joint the Fp-span of EVERY commitment's observation functionals,
pulled back to the joint (identified) unknown space, and T_joint the
functionals supported on the union of the data rectangles.

THE REDUCTION, jointly.  Per commitment, `zk60_native_jv_pcs` reduces
`F intersect T` to `256 * k0 + (u-row term)` under three hypotheses (H-pad,
H-pair, H-prox) that it CHECKS on the capture.  The same reduction applies
to the joint system, for one structural reason that this module also
checks: after the pad step, every surviving functional is of the form
`p (x) e_t` with `p` in the row space of the generators and `t` a MESSAGE
position, so the joint msg block is again a tensor product (joint row set)
(x) (256 message positions) -- and a shared coordinate of the msg block is
exactly a shared ROW.  Therefore

    k0_joint = rank_Fp(gens_joint)  -  rank_Fp(gens_joint | non-data rows)

over the JOINT row set, with a row identification merging two columns into
their SUM (the coefficient of a shared unknown is the sum of the
coefficients of the roles that read it).  That single rank is what makes
the difference between the marginals and the joint visible:

  * nothing shared  -> the matrix is block diagonal by role, the ranks add,
    and `joint == sum` is a THEOREM about that block structure -- which the
    module states in its output AND still computes rather than asserting;
  * a shared DATA row -> the merge can only lower `rank(all)` while
    `rank(non-data)` is untouched, so `k0_joint <= sum of k0_r`: two
    commitments can disclose the SAME functional (aliasing), and the joint
    is then SMALLER than the sum;
  * a shared BLINDING row -> the merge lowers `rank(non-data)` while
    `rank(all)` survives on the data columns, so `k0_joint > 0` and the
    joint is LARGER than the sum: a functional that neither commitment
    discloses on its own becomes disclosed once the two blinding sources
    cancel.  That is the case the gate could not previously see.

SHARED COORDINATES AT THE TOY PROFILES.  Read off the capture and the
pinned Rust, not assumed:

  * the two endpoint commitments share their DATA with A.  Slots
    `SC_IO_IN` / `SC_IO_OUT` (`private_block/argument.rs:902-908`, the last
    two slots of either profile) are Standalone slots -- their true sum is
    zero (`SLOT_KINDS`, `layout.rs:474-498`; the published scalar is the
    mask term) -- running `eq(tau) * (A_plane - endpoint_plane)` over 9
    variables.  A zero sum at a random tau says the two planes are equal, so
    the endpoint's 2 data rows ARE A's 2 data rows of that plane, position
    by position.  `discover_shared_rows` rebuilds those pairs from the
    capture's own claim offsets and points and refuses to guess.
  * NOTHING ELSE is shared.  Every commitment draws its own pads, its own
    reserved mask pairs and its own proximity rows
    (`zkp-core/src/pcs.rs::commit_zk_owned_with`), and the masking
    commitment M draws its own coefficients.  The module checks that no
    identification class contains a NON-DATA row of two different roles and
    reports the consequence in words.

WHAT M CONTRIBUTES.  The masking commitment participates in the joint
generator system as a commitment -- its 2*slots + 4 rows and its proximity
combination -- but it commits NO witness data: every one of its rows is
prover randomness, so its contribution to `k0_joint` is nil, and that is
computed here rather than argued.  M's own disclosed figure belongs to a
different unknown space (the honest sumcheck round messages) and is
computed by `zk60_native_jv_cfs`; stage 4 adds it and says so.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  It is a rank of an explicitly
stated linear model at four real receipts' challenges.  In particular the
nonlinear link between the two channels (the terminal identity) is outside
any linear model, and the caller-fixed endpoint-root obligation (D8/D11)
is untouched.
"""

from __future__ import annotations

from zk60_native_jv_capture import N_COLS
from zk60_native_jv_field import F2_ONE, F2_ZERO, P, f2_add, f2_from_list, rank, solve
from zk60_native_jv_pcs import RoleView

# The two endpoint-equality slots are the last two of either profile
# (private_block/layout.rs:408-409 SC_IO_IN = 21, SC_IO_OUT = 22; the
# attention profile's are 16 and 17).  `discover_shared_rows` does not trust
# the index: it requires the structure.
ENDPOINT_ROLES = ("Input", "Output")


# ----------------------------------------------------- shared coordinates
def discover_shared_rows(capture):
    """Which (role, row) coordinates are the SAME unknown, from the capture.

    A slot qualifies as an endpoint-equality slot when
      * its private tables are exactly one A table and one endpoint table,
      * both name claims whose FIRST part has the same `log_size` and the
        same evaluation point (the slot's tau), and
      * the slot's claimed sum is the mask term alone, i.e. the slot is a
        zero-check (checked here as: the slot has no hosted slots and its
        terminals enter the composition as a difference).
    The first two are read from the capture.  The third is a property of
    `SLOT_KINDS` in the pinned layout, which the capture does not carry;
    it is recorded as a named source fact, not as a check.
    """
    out = {"pairs": [], "slots": [], "source_facts": [
        "private_block/argument.rs:902-908 and private_attention's counterpart define "
        "the endpoint slots as eq(tau) * (A_plane - endpoint_plane)",
        "private_block/layout.rs:474-498 SLOT_KINDS marks them Standalone, so the "
        "sum they prove is zero and the published scalar is the CFS mask term alone",
    ]}
    for arg in capture.slots:
        privates = [t for t in arg["tables"] if t["kind"] == "private"]
        roles = [t["role"] for t in privates]
        if len(privates) != 2 or "A" not in roles:
            continue
        ends = [r for r in roles if r in ENDPOINT_ROLES]
        if len(ends) != 1:
            continue
        a_tab = privates[roles.index("A")]
        e_tab = privates[1 - roles.index("A")]
        a_cl = capture.role("A")["claims"][a_tab["claim"]]
        e_cl = capture.role(e_tab["role"])["claims"][e_tab["claim"]]
        ap, ep = a_cl["parts"][0], e_cl["parts"][0]
        if ap["log_size"] != ep["log_size"] or ap["point"] != ep["point"]:
            continue
        nrows = 1 << max(0, ap["log_size"] - 8)
        a0, e0 = ap["offset"] // N_COLS, ep["offset"] // N_COLS
        pairs = [(("A", a0 + i), (e_tab["role"], e0 + i)) for i in range(nrows)]
        out["pairs"].extend(pairs)
        out["slots"].append(
            {
                "slot": arg["slot"],
                "endpoint": e_tab["role"],
                "log_size": ap["log_size"],
                "a_rows": [a0 + i for i in range(nrows)],
                "endpoint_rows": [e0 + i for i in range(nrows)],
                "same_evaluation_point": True,
                "why": "a Standalone (zero-sum) slot proving eq(tau)*(A - endpoint) = 0, "
                "so the two planes are equal and their rows are the same unknowns",
            }
        )
    return out


# ----------------------------------------------------------- the blocks
class Block:
    """One commitment's contribution to the joint system."""

    def __init__(self, name, rows, data_rows, u_rows, gens_f2, is_data_bearing=True):
        self.name = name
        self.rows = rows
        self.data_rows = list(data_rows)
        self.u_rows = list(u_rows)
        self.gens_f2 = gens_f2  # list of Fp2 vectors of length `rows`
        self.is_data_bearing = is_data_bearing

    @property
    def other_rows(self):
        data = set(self.data_rows)
        return [r for r in range(self.rows) if r not in data]

    def fp_generators(self):
        out = []
        for rho in self.gens_f2:
            out.append([v[0] for v in rho])
            out.append([v[1] for v in rho])
        return out


def block_from_role_view(view):
    """The block of a `RoleView` that has already run."""
    return Block(
        name=view.name,
        rows=view.rows,
        data_rows=view.data_rows,
        u_rows=view.u_rows,
        gens_f2=view.rhos + [view.prox_rho],
    )


def mask_block(capture, replay):
    """The masking commitment M as a block: rows, no data, one combination.

    M's rows are `2*slots + 4` (two `a` rows per slot, two `b` rows, two `u`
    rows -- `zk60_native_jv_cfs` checks the count against the capture) and
    the opening publishes ONE row combination, the proximity vector, whose
    coefficients are the `2*slots + 2` replayed challenges on the `a` and
    `b` rows and 1 on each `u` row (`hashline/src/zk.rs::mask_commit`).
    No row of M carries witness data.
    """
    rows = len(capture.mask["columns"][0]["values"])
    rhos = [f2_from_list(v) for v in capture.mask["proximity_rhos"]]
    vec = list(rhos) + [(1, 0)] * (rows - len(rhos))
    return Block(
        name="M",
        rows=rows,
        data_rows=[],
        u_rows=[],
        gens_f2=[vec],
        is_data_bearing=False,
    )


# ------------------------------------------------------- the joint system
class JointSystem:
    """The stacked generator system, with the identifications applied."""

    def __init__(self, blocks, identifications=(), removed_rows=()):
        self.blocks = list(blocks)
        self.identifications = [tuple(p) for p in identifications]
        self.removed = {tuple(r) for r in removed_rows}
        self.findings: list[str] = []
        self._build()

    # ------------------------------------------------------------ classes
    def _build(self):
        parent = {}

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        def union(a, b):
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb

        for b in self.blocks:
            for r in range(b.rows):
                parent[(b.name, r)] = (b.name, r)
        for a, b in self.identifications:
            if a not in parent or b not in parent:
                self.findings.append(f"identification names a row that does not exist: {a} {b}")
                continue
            union(a, b)

        kind = {}
        for b in self.blocks:
            data = set(b.data_rows)
            for r in range(b.rows):
                kind[(b.name, r)] = "data" if r in data else "non-data"

        classes, index = [], {}
        for b in self.blocks:
            for r in range(b.rows):
                key = (b.name, r)
                if key in self.removed:
                    continue
                root = find(key)
                if root not in index:
                    index[root] = len(classes)
                    classes.append([])
                classes[index[root]].append(key)
        self.classes = classes
        self.index = {}
        for ci, members in enumerate(classes):
            for m in members:
                self.index[m] = ci
        self.class_kind = []
        self.mixed_classes = []
        self.shared_non_data_classes = []
        self.shared_data_classes = []
        for ci, members in enumerate(classes):
            kinds = {kind[m] for m in members}
            roles = {m[0] for m in members}
            if len(kinds) > 1:
                self.mixed_classes.append(ci)
                self.findings.append(
                    f"class {ci} identifies a data row with a non-data row: {members}"
                )
            k = "data" if kinds == {"data"} else "non-data"
            self.class_kind.append(k)
            if len(roles) > 1:
                (self.shared_data_classes if k == "data" else
                 self.shared_non_data_classes).append(ci)

    # ------------------------------------------------------------ vectors
    def generators(self):
        """Every block's Fp generators, over the joint class coordinates.

        A generator's coefficient at a class is the SUM over that block's
        rows in the class: a shared unknown is read by both roles, so the
        joint functional's coefficient there is the sum of what each role
        puts on it.
        """
        n = len(self.classes)
        out, owner = [], []
        for b in self.blocks:
            for g in b.fp_generators():
                v = [0] * n
                for r in range(b.rows):
                    key = (b.name, r)
                    if key in self.removed:
                        continue
                    if g[r] % P:
                        ci = self.index[key]
                        v[ci] = (v[ci] + g[r]) % P
                out.append(v)
                owner.append(b.name)
        return out, owner

    def columns(self, which):
        return [ci for ci, k in enumerate(self.class_kind) if k == which]

    # ---------------------------------------------------------- the ranks
    def disclosed(self, msg_width=N_COLS):
        """`msg_width` is the number of message positions per row: 256 on a
        receipt, and the toy value when the small model validates this
        reduction against a dense brute force."""
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
        u_dim, u_detail = self._u_term(gens, data_cols, other_cols)
        facts["u_row_term_fp"] = u_dim
        facts["u_row_detail"] = u_detail
        facts["disclosed_fp"] = msg_width * k0 + u_dim
        return facts

    def _u_term(self, gens, data_cols, other_cols):
        """The public-linear-constraint term, jointly (mirrors RoleView)."""
        u_classes = []
        for b in self.blocks:
            for r in b.u_rows:
                key = (b.name, r)
                if key in self.removed:
                    continue
                u_classes.append((b.name, r, self.index[key]))
        if not u_classes:
            return 0, {"u_classes": 0}
        block = [[g[c] for c in other_cols] for g in gens]
        xis, admissible = [], 0
        for _, _, ci in u_classes:
            target = [1 if c == ci else 0 for c in other_cols]
            x, _ = solve(block, target)
            if x is None:
                continue
            admissible += 1
            xi = [0] * len(data_cols)
            for k, coef in enumerate(x):
                if coef:
                    for a, c in enumerate(data_cols):
                        xi[a] = (xi[a] + coef * gens[k][c]) % P
            xis.append(xi)
        kbasis = self._kernel_on_data(gens, data_cols, other_cols)
        u_dim = rank(xis + kbasis, len(data_cols)) - rank(kbasis, len(data_cols))
        return u_dim, {
            "u_classes": len(u_classes),
            "u_class_owners": [f"{n}[{r}]" for n, r, _ in u_classes],
            "indicators_admissible": admissible,
            "extra_dimension_beyond_k0": u_dim,
        }

    def _kernel_on_data(self, gens, data_cols, other_cols):
        m = len(gens)
        aug = [[gens[k][c] for k in range(m)] for c in other_cols]
        mat = [row[:] for row in aug]
        nrows = len(mat)
        pivots, r = [], 0
        for c in range(m):
            piv = None
            for i in range(r, nrows):
                if mat[i][c] % P:
                    piv = i
                    break
            if piv is None:
                continue
            mat[r], mat[piv] = mat[piv], mat[r]
            pinv = pow(mat[r][c], P - 2, P)
            mat[r] = [x * pinv % P for x in mat[r]]
            for i in range(nrows):
                if i != r and mat[i][c] % P:
                    f = mat[i][c]
                    mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
            pivots.append(c)
            r += 1
            if r == nrows:
                break
        out = []
        for fc in [c for c in range(m) if c not in pivots]:
            v = [0] * m
            v[fc] = 1
            for i, pc in enumerate(pivots):
                v[pc] = (-mat[i][fc]) % P
            row = [0] * len(data_cols)
            for k, coef in enumerate(v):
                if coef:
                    for a, c in enumerate(data_cols):
                        row[a] = (row[a] + coef * gens[k][c]) % P
            out.append(row)
        return out


# ------------------------------------------------------------- the report
EXPECTED_PCS = {"A": 0, "H": 2, "Input": 0, "Output": 0}
EXPECTED_CFS_OPENING_ONLY_FP = 2


def joint_view(capture, replay, views, cfs_opening_only_fp, extra_identifications=(),
               removed_rows=()):
    """Stage 4 for ONE receipt: the parts and the joint, both COMPUTED.

    `views` are the `RoleView`s stage 2 already ran (so the parts below are
    the same objects stage 2 reported, recomputed here through the joint
    code path and cross-checked against it).  The two optional arguments
    exist for the negative controls and are empty on an honest run.
    """
    blocks = [block_from_role_view(v) for v in views] + [mask_block(capture, replay)]
    shared = discover_shared_rows(capture)
    ids = [tuple(p) for p in shared["pairs"]] + [tuple(p) for p in extra_identifications]

    # (i) every part, through the SAME code path, one block at a time
    parts, part_detail = {}, {}
    for b in blocks:
        one = JointSystem([b], removed_rows=removed_rows)
        f = one.disclosed()
        parts[b.name] = f["disclosed_fp"]
        part_detail[b.name] = {
            "k0": f["k0"],
            "rank_all": f["rank_all"],
            "rank_on_non_data": f["rank_on_non_data"],
            "u_row_term_fp": f["u_row_term_fp"],
            "disclosed_fp": f["disclosed_fp"],
            "data_rows": len(b.data_rows),
            "non_data_rows": b.rows - len(b.data_rows),
            "commits_witness_data": b.is_data_bearing,
        }

    # (ii) the joint system: every block at once, identifications applied
    js = JointSystem(blocks, identifications=ids, removed_rows=removed_rows)
    jf = js.disclosed()
    # What the endpoint identification itself is worth: the same joint system
    # with the endpoints' data left as separate unknowns.  Identifying DATA
    # coordinates can only lower the joint (two commitments disclosing the
    # same functional would be counted once), so the difference is the
    # aliasing, computed rather than argued.
    unmerged = JointSystem(blocks, identifications=list(extra_identifications),
                           removed_rows=removed_rows).disclosed()

    # the per-role figures stage 2 reported, for the cross-check
    stage2_parts = {v.name: v.facts["disclosed_dimension"] for v in views}
    recomputed_matches = all(parts[k] == stage2_parts[k] for k in stage2_parts)
    hypotheses = {
        v.name: all(v.facts["reduction_hypotheses"].values()) for v in views
    }

    pcs_sum = sum(parts[v.name] for v in views)
    m_part = parts["M"]  # 0 by construction: M commits no witness data
    sum_of_parts = pcs_sum + m_part + cfs_opening_only_fp
    joint = jf["disclosed_fp"] + cfs_opening_only_fp

    exceeds = [
        f"{k}: {parts[k]} > {EXPECTED_PCS[k]}"
        for k in EXPECTED_PCS
        if k in parts and parts[k] > EXPECTED_PCS[k]
    ]
    if m_part > 0:
        exceeds.append(f"M: {m_part} > 0 (M commits no witness data)")
    if cfs_opening_only_fp > EXPECTED_CFS_OPENING_ONLY_FP:
        exceeds.append(
            f"CFS opening-only: {cfs_opening_only_fp} > {EXPECTED_CFS_OPENING_ONLY_FP}"
        )

    block_diagonal = not js.shared_non_data_classes and not js.mixed_classes
    findings = list(js.findings)
    if not recomputed_matches:
        findings.append(
            "the parts recomputed through the joint code path differ from stage 2's"
        )
    if not all(hypotheses.values()):
        findings.append(
            "a commitment's reduction hypothesis (H-pad / H-pair / H-prox) fails, so "
            "the joint reduction does not apply and its ranks are not a disclosed "
            "dimension"
        )
    if joint != sum_of_parts:
        findings.append(
            f"the joint disclosed dimension {joint} differs from the sum of the parts "
            f"{sum_of_parts}"
        )
    findings.extend(f"a part exceeds its expected public value -- {e}" for e in exceeds)

    return {
        "capture": capture.proof_sha256,
        "profile": capture.profile,
        "shared_coordinates": {
            "identified_row_pairs": [
                {"a": f"{a[0]}[{a[1]}]", "b": f"{b[0]}[{b[1]}]"} for a, b in ids
            ],
            "endpoint_equality_slots": shared["slots"],
            "source_facts": shared["source_facts"],
            "classes_shared_between_roles_data": len(js.shared_data_classes),
            "classes_shared_between_roles_non_data": len(js.shared_non_data_classes),
            "non_data_block_is_block_diagonal_by_role": block_diagonal,
            "what_that_means": (
                "no blinding source is shared: every commitment's reserved mask pairs, "
                "proximity rows and pads are its own, so the non-data block of the joint "
                "generator matrix is block diagonal and joint == sum is a THEOREM about "
                "that block structure -- the rank below is computed anyway, and the "
                "controls show it moving when a blinding source IS shared"
                if block_diagonal
                else "a NON-DATA coordinate is shared between two roles: the block "
                "structure is gone and the joint rank is not the sum of the marginals"
            ),
        },
        "parts_fp": parts,
        "parts_detail": part_detail,
        "parts_recomputed_through_the_joint_path_match_stage2": recomputed_matches,
        "stage2_parts_fp": stage2_parts,
        "reduction_hypotheses_hold": hypotheses,
        "cfs_opening_only_fp": cfs_opening_only_fp,
        "joint_detail": jf,
        "joint_without_the_endpoint_identification_fp": (
            unmerged["disclosed_fp"] + cfs_opening_only_fp
        ),
        "aliasing_lost_to_the_endpoint_identification_fp": (
            unmerged["disclosed_fp"] - jf["disclosed_fp"]
        ),
        "sum_of_parts_fp": sum_of_parts,
        "joint_fp": joint,
        "joint_equals_sum_of_parts": joint == sum_of_parts,
        "expected_parts_fp": dict(EXPECTED_PCS, M=0, CFS=EXPECTED_CFS_OPENING_ONLY_FP),
        "parts_exceeding_their_expected_value": exceeds,
        "findings": findings,
        "what_is_NOT_covered": (
            "the two channels are linked NONLINEARLY by the terminal identity; no linear "
            "model sees that link.  The Merkle roots, the leaf salts and the "
            "authentication paths are hash objects and are not in this model either."
        ),
        "ok": (
            not findings
            and joint == sum_of_parts
            and not exceeds
            and recomputed_matches
            and all(hypotheses.values())
        ),
    }


# ----------------------------------------------------- negative controls
def singleton_pair_rows(view):
    """The reserved-pair rows of the claims that are ALONE in their group.

    Those are the places where the non-data block is exactly square: two
    generators (the real and the imaginary part of the group's combination)
    against the two rows of one reserved pair.  Wherever the block has
    slack -- a group with several claims, or the proximity pair -- one
    missing or shared column changes no rank, so a control placed there
    cannot fire.  A control must be placed where the model can see it, and
    this function says where that is.
    """
    other, u = set(view.other_rows), set(view.u_rows)
    out = []
    for members in view.groups:
        if len(members) != 1:
            continue
        ci = members[0]
        rows = sorted(r for r in other if view.rws[ci][r] != F2_ZERO and r not in u)
        if len(rows) == 2:
            out.append({"claim": ci, "rows": rows})
    return out


def _role_view(capture, replay, name, perturb=None, q_pad=None):
    role = capture.role(name)
    v = RoleView(capture, role, replay.role_prox_rhos[name], perturb=perturb, q_pad=q_pad)
    v.run(replay.role_lambdas[name])
    return v


def joint_controls(capture, replay, views, cfs_opening_only_fp):
    """Four perturbations, each of which must make stage 4 FAIL.

    Every control is measured against the SAME honest capture, and each
    entry records the honest verdict beside the perturbed one: a control
    that cannot fire is not a control.
    """
    byname = {v.name: v for v in views}
    honest = joint_view(capture, replay, views, cfs_opening_only_fp)
    a_singles = singleton_pair_rows(byname["A"])
    h_singles = singleton_pair_rows(byname["H"])
    out = {
        "honest": {
            "ok": honest["ok"],
            "joint_fp": honest["joint_fp"],
            "sum_of_parts_fp": honest["sum_of_parts_fp"],
            "parts_fp": honest["parts_fp"],
        },
        "singleton_opening_groups": {"A": len(a_singles), "H": len(h_singles)},
    }

    # (a) one blinding source shared between two commitments.
    a_row, h_row = a_singles[0]["rows"][0], h_singles[0]["rows"][0]
    shared = joint_view(
        capture, replay, views, cfs_opening_only_fp,
        extra_identifications=[(("A", a_row), ("H", h_row))],
    )
    out["shared_blinding_source"] = {
        "what": f"A[{a_row}] and H[{h_row}] -- one reserved mask row of a singleton "
        "opening group in each commitment -- made the SAME unknown",
        "fires": not shared["ok"],
        "joint_fp": shared["joint_fp"],
        "sum_of_parts_fp": shared["sum_of_parts_fp"],
        "parts_fp": shared["parts_fp"],
        "parts_unchanged": shared["parts_fp"] == honest["parts_fp"],
        "joint_greater_than_sum": shared["joint_fp"] > shared["sum_of_parts_fp"],
        "joint_k0": shared["joint_detail"]["k0"],
        "direction": (
            "UP.  Neither commitment discloses anything on its own -- the marginals "
            "do not move at all -- but once the two blinding rows are one unknown, a "
            "combination of the two commitments' group vectors cancels on every "
            "non-data coordinate and survives on the data rows, so the joint rises "
            "by 256 Fp per such direction while the sum of the parts stands still. "
            "This is precisely the case the hard-coded stage 4 could not see."
        ),
        "findings": shared["findings"],
    }

    # (b) one masking row removed from one commitment.
    removed = joint_view(
        capture, replay, views, cfs_opening_only_fp, removed_rows=[("A", a_row)]
    )
    out["one_mask_row_removed"] = {
        "what": f"A[{a_row}] removed: the commitment has one blinding row fewer, so "
        "its singleton group's non-data block is 2 generators against 1 column",
        "fires": not removed["ok"],
        "joint_fp": removed["joint_fp"],
        "sum_of_parts_fp": removed["sum_of_parts_fp"],
        "parts_fp": removed["parts_fp"],
        "exceeds": removed["parts_exceeding_their_expected_value"],
        "direction": (
            "UP, in the marginal AND in the joint: A discloses 256 Fp on its own, so "
            "the sum rises with the joint and they stay equal; stage 4 fails on the "
            "other arm, a part exceeding its expected public value."
        ),
        "findings": removed["findings"],
    }

    # (b') one pad fewer than the opening's distinct columns.
    d = byname["A"].facts["distinct_columns"]
    pad_views = [
        _role_view(capture, replay, "A", q_pad=d - 1) if v.name == "A" else v
        for v in views
    ]
    padded = joint_view(capture, replay, pad_views, cfs_opening_only_fp)
    out["one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"A's pad count set to {d - 1} against {d} distinct opened columns",
        "fires": not padded["ok"],
        "hypotheses": padded["reduction_hypotheses_hold"],
        "direction": (
            "the pad step of the reduction (H-pad) fails, so the ranks below are no "
            "longer a disclosed dimension at all and the stage refuses rather than "
            "reporting a number."
        ),
        "findings": padded["findings"],
    }

    # (c) a claim's weight reaching a non-data row outside its reserved pair.
    victim = a_singles[0]["claim"]
    straddled = a_singles[1]["rows"][0]

    def straddle(view):
        view.rws[victim][straddled] = f2_add(view.rws[victim][straddled], F2_ONE)
        for gi, members in enumerate(view.groups):
            if victim in members:
                lam = view._lambdas[gi][members.index(victim)]
                view.rhos[gi][straddled] = f2_add(view.rhos[gi][straddled], lam)

    straddle_views = [
        _role_view(capture, replay, "A", perturb=straddle) if v.name == "A" else v
        for v in views
    ]
    strad = joint_view(capture, replay, straddle_views, cfs_opening_only_fp)
    out["claim_weight_outside_its_reserved_pair"] = {
        "what": f"A's claim {victim} given a weight on row {straddled}, which belongs "
        "to another claim's reserved pair",
        "fires": not strad["ok"],
        "hypotheses": strad["reduction_hypotheses_hold"],
        "joint_fp": strad["joint_fp"],
        "sum_of_parts_fp": strad["sum_of_parts_fp"],
        "parts_fp": strad["parts_fp"],
        "direction": (
            "the pair step of the reduction (H-pair) fails -- two claims now share a "
            "reserved pair -- so the stage refuses; the Rust verifier would already "
            "have panicked on the row-span assertions in pcs.rs, which is why this "
            "cannot be reached by a real receipt."
        ),
        "findings": strad["findings"],
    }

    names = [
        "shared_blinding_source",
        "one_mask_row_removed",
        "one_pad_fewer_than_the_distinct_opened_columns",
        "claim_weight_outside_its_reserved_pair",
    ]
    out["all_fire"] = all(out[n]["fires"] for n in names)
    out["ok"] = honest["ok"] and out["all_fire"]
    return out
