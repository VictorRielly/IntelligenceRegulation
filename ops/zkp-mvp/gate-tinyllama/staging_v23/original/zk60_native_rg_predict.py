#!/usr/bin/env python3
"""ROUND 9: what the gate MUST report at a shape, computed from the shape
before the gate is run there.

    python3 scripts/zk60_native_rg_predict.py \
      --bundle /home/victor/zk60-artifacts/m125-capture-dense-l2 \
      --validate-against results/zk60_native_run_gate_s20/run-g-dense-s20.json \
      --validate-against results/zk60_native_run_gate_k4/run-i-dense-k4.json \
      --evidence results/zk60_native_run_gate_m125 --name prediction_m125

WHY A PREDICTION IS A DIFFERENT OBJECT FROM A CHECK.

Round 5 established the method and this module is it, written down: every
figure the gate reports at a new shape is either SHAPE-INDEPENDENT -- it must
come out identical, or something the ports assumed is wrong -- or it SCALES,
and then the scaling law is an arithmetic statement that can be written
before the number is seen.  A figure read first and explained afterwards is
worth much less, because any number can be explained.

So this module takes a bundle's `run.json["shape"]` and the per-opening
geometry the capture declares (row counts, group counts, claim counts --
INPUTS, not the gate's output), and computes what the gate's record must
say.  It is VALIDATED by being run against the two development shapes whose
records are committed: if it does not reproduce those to the unit, it
predicts nothing at 125M either.  `--validate-against` is not optional in
practice and the record says whether it passed.

NOTHING HERE IS A PRIVACY STATEMENT.  A prediction about a rank is a
prediction about a rank.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# [ROUND 9j] a run bundle or a standalone block bundle, by what the
# directory holds
from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_gqa import Geometry  # noqa: E402

# ------------------------------------------------- [ROUND 9b] the pad rule
# `shape.rs`'s own arithmetic, restated here rather than imported, so that
# this module PREDICTS the pad rule instead of agreeing with the port that
# implements it.  `zk60_native_rg_terminals.PadGeometry` is the port; if the
# two ever disagree, the prediction says so before the gate is run.
LIMBS_ISQRT = 3      # shape.rs:28
U8_LEN = 256         # layout.rs:59

# The eight zero-check slots, each with the domains it HOSTS
# (`pad::pad_zero_host`), the domain whose log gives its `tau` draws, and the
# `mu` base and `nu` counts its closure asks for at `argument.rs`'s own
# arithmetic.  `helpers` is the number of LogUp helper columns of the named
# domain, read from the capture's plane index.  The draw count is then
#
#     tau(log dom) + mu(base + n_pad) + nu + zeta(n_pad),   n_pad = pad_on
#
# and `pad_on = any(Shape::pads(d))` over the hosted domains -- the sentence
# of `pad.rs` that finding M-F1 is about.
ZERO_CHECK_SLOTS = {
    2:  ("SC_TZC",  "T",   ("T",),        0,  6, 2),
    3:  ("SC_LZC",  "L",   ("L",),        0,  0, 0),
    14: ("SC_DZC",  "D",   ("D",),        1, 11, 2),
    15: ("SC_QZC",  "Q",   ("Q",),        1,  1, 2),
    16: ("SC_KVZC", "Kv",  ("Kv",),       1,  1, 2),
    17: ("SC_SZC",  "S",   ("Ht", "S"),   1,  6, 2),
    18: ("SC_FZC",  "F",   ("F",),        1,  4, 2),
    19: ("SC_TAB",  "Tab", ("Tab",),      0,  3, 0),
}
# (name, tau domain, hosted domains, helpers_of_the_tau_domain, mu base, nu).
# Slot 17's base is `5 + n_help + 1`, written as `6 + n_help` here; slot 14's
# is `11 + n_help`, slot 15's and 16's `1 + n_help`, slot 18's `4 + n_help`,
# and slots 02, 03 and 19 take no helper into their `mu`.
HOST_SLOT = {d: s for s, (_n, _t, doms, *_r) in ZERO_CHECK_SLOTS.items()
             for d in doms}


def true_size(sh: dict, dom: str) -> int:
    """`Shape::true_size` (shape.rs:405), from `run.json["shape"]` alone."""
    return {
        "T": sh["tokens"],
        "Ht": sh["q_heads"] * sh["tokens"],
        "L": 3 * LIMBS_ISQRT * sh["tokens"],
        "D": sh["tokens"] * sh["width"],
        "Q": sh["tokens"] * sh["q_heads"] * sh["head_dim"],
        "Kv": sh["tokens"] * sh["kv_heads"] * sh["head_dim"],
        "S": sh["q_heads"] * sh["tokens"] * sh["tokens"],
        "F": sh["tokens"] * sh["hidden"],
        "Tab": U8_LEN,
    }[dom]


def domain_logs(bundle) -> dict:
    """Each domain's log, as the capture's plane index DECLARES it (an
    input, like the per-opening geometry: `domain_log_at`'s P-3 lift is the
    table's business and this module does not re-derive it)."""
    out = {}
    idx = bundle.run["plane_index"]
    for p in idx["a_planes"] + idx["h_planes"]:
        out.setdefault(p["domain"], p["log_size"])
    return out


def helper_counts(bundle) -> dict:
    """`Shape::helpers(dom)`, read from the plane index: the `H` planes of
    the domain, minus the ONE extra pair helper `Dom::S` and `Dom::F` carry
    (`H_SEXP`, `H_FACT`; shape.rs:486-489)."""
    extra = {"S": "H_SEXP", "F": "H_FACT"}
    out: dict = {}
    for p in bundle.run["plane_index"]["h_planes"]:
        d = p["domain"]
        if p["name"] == extra.get(d):
            continue
        out[d] = out.get(d, 0) + 1
    return out


def pad_rule(bundle) -> dict:
    """[ROUND 9b] Which domains pad, which host slot each one sits in, and
    how many DEFINITION draws each zero-check slot therefore consumes --
    computed from the shape and compared with what the capture declares.

    Round 9's finding M-F1 was exactly this number being wrong at three
    slots, and the reason it could not be found earlier is in the table:
    until the 125M shape every domain padded, so `n_pad` was 1 everywhere
    and a hardcoded 1 was right.  At `rung-P2` three domains are exact
    powers of two at a development size."""
    sh = bundle.shape.raw
    logs = domain_logs(bundle)
    helps = helper_counts(bundle)
    doms = []
    for d in sorted(logs):
        ts, log = true_size(sh, d), logs[d]
        doms.append({
            "domain": d,
            "true_size": ts,
            "domain_log": log,
            "padded_size": 1 << log,
            "pads": (1 << log) != ts,
            "host_slot": HOST_SLOT.get(d),
        })
    slots = []
    declared = [len(s["definition_challenges"]) for s in bundle.stages[0].slots]
    for s in sorted(ZERO_CHECK_SLOTS):
        name, tau_dom, hosts, uses_help, base, nu = ZERO_CHECK_SLOTS[s]
        on = any((1 << logs[d]) != true_size(sh, d) for d in hosts)
        n_pad = 1 if on else 0
        n_help = helps.get(tau_dom, 0) if uses_help else 0
        want = logs[tau_dom] + base + n_help + n_pad + nu + n_pad
        slots.append({
            "slot": s, "name": name, "hosts": list(hosts),
            "tau_domain": tau_dom, "tau_draws": logs[tau_dom],
            "mu_base": base + n_help, "helpers_in_mu": n_help,
            "pad_on": on, "n_pad": n_pad, "nu": nu, "zeta": n_pad,
            "predicted_definition_draws": want,
            "declared_by_the_capture": declared[s],
            "equal": want == declared[s],
        })
    return {
        "the_rule": "tau(log dom) + mu(base + n_pad) + nu + zeta(n_pad), "
        "with pad_on = any(Shape::pads(d)) over the domains the slot hosts "
        "(argument.rs:936, pad.rs:361-369)",
        "domains": doms,
        "domains_that_pad": [d["domain"] for d in doms if d["pads"]],
        "domains_that_do_not_pad": [d["domain"] for d in doms
                                    if not d["pads"]],
        "per_zero_check_slot": slots,
        "slots_whose_draw_count_is_derived_here": sorted(ZERO_CHECK_SLOTS),
        "all_derived_counts_equal_the_capture": all(x["equal"] for x in slots),
        "disagreements": [
            f"slot {x['slot']} ({x['name']}): this module derives "
            f"{x['predicted_definition_draws']} definition draws and the "
            f"capture declares {x['declared_by_the_capture']}"
            for x in slots if not x["equal"]
        ],
        "what_this_is_not": "a check of the prover: the capture's declared "
        "count is an INPUT.  What it predicts is that the port will consume "
        "exactly this many, and the gate's own confirmation is that the "
        "slot's terminal identity holds -- `Ctx.pad_draws` refuses BY NAME "
        "on any mismatch, which is finding M-F1's repair",
    }


MASK_ROWS = 5     # layout.rs: the endpoint's mask rows above its data rows
U8_LOG = 8        # layout.rs: the byte table's natural log
D_HELPERS_C6_OFF = 19   # `Dom::D`'s helper planes when the norm top byte is
D_HELPERS_C6_ON = 17    # not full / is full: correction C-6's four lookups
SLOT14_TERMINALS_C6_OFF = 56
SLOT14_TERMINALS_C6_ON = 54


def _isqrt(n: int) -> int:
    import math
    return math.isqrt(n)


def corrections_and_geometry(bundle) -> dict:
    """[ROUND 9c] The three things the three new shapes are FOR, each derived
    from `run.json["shape"]`'s own numbers and then compared with what the
    capture declares.  Round 9b's pad rule reads the plane index for the
    helper counts and the domain logs; these three do not.

    * **correction C-6** (`Shape::norm_top_is_full_byte`).  `D_max =
      isqrt(1 + width * 32767^2)`, the norm window is `NORM_TN + 1 +
      bit_length(D_max) = 12 + bit_length(D_max)`, and the window FILLS its
      top byte limb exactly when that is a multiple of eight -- which needs
      `width > 256`.  When it does, the `scaled(top, 1 << 0)` lookup IS the
      `byte(top)` lookup already in the list, so FOUR lookups (`rho` and
      `sigma` of `norm_a` and of `norm_m`) are dropped: `Dom::D` carries two
      helper planes fewer and slot 14 two terminals fewer.
    * **the `Dom::Tab` lift** (ruling P-3).  The byte table's natural log is
      8 and it is served at the ROW WIDTH, so its domain log is `log_cols`
      and the lift is `2^(log_cols - 8)` -- 4 at every development shape so
      far and **64** at `rung-W14` and 125M.
    * **the endpoint's ROW COUNT.**  The external endpoint commits the
      padded `Dom::D` cube, `t_pad * d_pad` words, in rows of
      `2^endpoint_log_n`; its commitment has `MASK_ROWS = 5` more, and an
      internal boundary has one more than that, the run layer's second
      reserved IO-tab row.
    """
    sh = bundle.shape.raw
    d_max = _isqrt(1 + sh["width"] * 32767 ** 2)
    wrho = 12 + d_max.bit_length()
    c6 = wrho % 8 == 0
    logs = domain_logs(bundle)
    helps = helper_counts(bundle)
    ep_data = (sh["t_pad"] * sh["d_pad"]) >> sh["endpoint_log_n"]
    roles = [r for st in bundle.stages for r in st.roles]
    ep = [r for r in roles if r["commitment_kind"] == "external-endpoint"]
    ib = [r for r in roles if r["commitment_kind"] == "internal-boundary"]
    s14 = len(bundle.stages[0].slots[14]["terminals"])
    return {
        "correction_c6": {
            "d_max": d_max,
            "norm_wrho_derived": wrho,
            "norm_wrho_declared": sh.get("norm_wrho"),
            "norm_wrho_equal": wrho == sh.get("norm_wrho"),
            "norm_top_is_full_byte": c6,
            "why": "the window is 12 + bit_length(D_max) and C-6 applies "
            "exactly when that is a multiple of 8, which needs width > 256",
            "lookups_dropped": 4 if c6 else 0,
            "d_helper_planes_predicted":
                D_HELPERS_C6_ON if c6 else D_HELPERS_C6_OFF,
            "d_helper_planes_declared": helps.get("D"),
            "d_helper_planes_equal":
                (D_HELPERS_C6_ON if c6 else D_HELPERS_C6_OFF) == helps.get("D"),
            "slot14_terminals_predicted":
                SLOT14_TERMINALS_C6_ON if c6 else SLOT14_TERMINALS_C6_OFF,
            "slot14_terminals_declared": s14,
            "slot14_terminals_equal":
                (SLOT14_TERMINALS_C6_ON if c6 else SLOT14_TERMINALS_C6_OFF) == s14,
        },
        "tab_lift": {
            "natural_log": U8_LOG,
            "domain_log_predicted": sh["log_cols"],
            "domain_log_declared": logs.get("Tab"),
            "domain_log_equal": logs.get("Tab") == sh["log_cols"],
            "lift_factor": 1 << (sh["log_cols"] - U8_LOG),
            "why": "ruling P-3 serves the byte table at the row width",
        },
        "endpoint": {
            "cube_words": sh["t_pad"] * sh["d_pad"],
            "endpoint_log_n": sh["endpoint_log_n"],
            "data_rows_predicted": ep_data,
            "commitment_rows_predicted": ep_data + MASK_ROWS,
            "commitment_rows_declared_by_the_shape": sh["endpoint_rows"],
            "commitment_rows_equal":
                ep_data + MASK_ROWS == sh["endpoint_rows"],
            "external_endpoints_declared":
                sorted({(r["data_rows"], r["commitment"]["rows"]) for r in ep}),
            "external_endpoints_equal": all(
                r["data_rows"] == ep_data
                and r["commitment"]["rows"] == ep_data + MASK_ROWS for r in ep),
            "internal_boundary_rows_predicted": ep_data + MASK_ROWS + 1,
            "internal_boundaries_declared":
                sorted({(r["data_rows"], r["commitment"]["rows"]) for r in ib}),
            "internal_boundaries_equal": all(
                r["commitment"]["rows"] == ep_data + MASK_ROWS + 1 for r in ib),
            "column_digest_bytes_of_the_largest_commitment":
                max(r["commitment"]["rows"] for r in roles) * 8,
            "why": "the endpoint commits the padded Dom::D cube in rows of "
            "2^endpoint_log_n, plus MASK_ROWS = 5; an internal boundary has "
            "one more, the run layer's second reserved IO-tab row",
        },
        "what_this_is_not": "a check of the prover.  These are three "
        "statements about the SHAPE, derived from its own seven numbers, "
        "and compared with what the capture declares about itself",
    }


def receipt(bundle) -> dict:
    """[ROUND 9b] The segment lengths, and the one arithmetic statement that
    relates two shapes with the same padded layout.

    A sumcheck round sends one field-extension element per degree, so a slot
    that loses its pad-zero factor loses one `Fp2` (16 bytes) in each of its
    `main + ext` rounds.  Between `rung-K4` and `rung-P2` -- the same padded
    layout, the same domain logs, the same slot table -- the only slots whose
    declared degree moves are 16 and 18, and that is the whole difference
    between a stage of one and a stage of the other."""
    sh = bundle.shape.raw
    rounds = [m + e for m, e, _d in bundle.shape.slots]
    # [ROUND 9j] a STANDALONE block has no segment: its receipt is ONE frame,
    # `receipt.bin`, whose length `block.json["proof_bytes"]` declares.  The
    # key names below are the run's, so a comparison table lines them up.
    if getattr(bundle, "standalone", False):
        segs = [bundle.run["proof_bytes"]]
    else:
        segs = [st.doc["segment_bytes"] for st in bundle.stages]
    return {
        "segment_bytes_declared": segs,
        "total_segment_bytes": sum(segs),
        "sumcheck_rounds_per_slot": rounds,
        "degrees": [d for _m, _e, d in bundle.shape.slots],
        "rounds_of_slots_16_and_18": rounds[16] + rounds[18],
        "bytes_per_round_per_degree": 16,
        "the_law": "a stage of a shape whose slots 16 and 18 have one degree "
        f"less sends {16 * (rounds[16] + rounds[18])} bytes less per stage, "
        "everything else being equal",
        "endpoint_rows": sh["endpoint_rows"],
    }


# ---------------------------------------------------------------- the laws
SHAPE_INDEPENDENT = {
    "a_disclosed": (0, "A commits witness data under 36 opening groups whose "
                    "blinding block is 246 rows at every shape so far; the "
                    "disclosed dimension is a rank of the BLINDING structure, "
                    "not of the data"),
    "h_disclosed": (2, "the public LogUp identity, and the gate checks that "
                    "it IS that identity rather than assuming it"),
    "endpoint_disclosed": (0, "one singleton group, 2(G+1) = 4 generators"),
    "boundary_disclosed": (0, "ruling M-8's figure on the reserved rows"),
    "m_disclosed": (0, "M commits no witness data, so its part over the "
                    "commitments' coordinates is 0"),
    "boundary_reserved_rank": (6, "2*sites + 2 = 6 reserved columns over "
                               "2(G+1) = 6 generators, full rank"),
    "m_rows": (50, "layout.rs: M_ROWS = 2 * N_SLOTS + 4, a constant of the "
               "slot table and not of the shape"),
    "m_functionals": (34, "layout.rs: N_FUNCTIONALS = 34, likewise"),
    "n_slots": (23, "the block's slot table"),
    "a_groups": (36, "read from the shape, not assumed -- but equal at all "
                 "three shapes so far"),
    "h_groups": (9, "likewise"),
    "channels": (28, "the channel array is a property of the gate, not of "
                 "the shape"),
    "three_role_generators": (154, "74 + 6 + 74: A's 2(36+1), the boundary's "
                              "2(2+1) and A's again"),
}


def geometry_of(bundle) -> dict:
    """Per-opening geometry as the CAPTURE declares it (an input)."""
    out = {"per_stage": [], "roles": []}
    for st in bundle.stages:
        rs = []
        for r in st.roles:
            rs.append({
                "key": st.key(r["role"]),
                "kind": r["commitment_kind"],
                "rows": r["commitment"]["rows"],
                "data_rows_declared": r["data_rows"],
                "groups": len(r["groups"]),
                "claims": sum(len(g["members"]) for g in r["groups"]),
                "non_data_rows_by_row_roles": sum(
                    1 for x in r["row_roles"] if x["kind"] != "data"
                ),
            })
        out["per_stage"].append(rs)
        out["roles"].extend(rs)
    return out


def predict(bundle) -> dict:
    """Every figure the gate must report, from the shape and the geometry."""
    sh = bundle.shape
    L = bundle.blocks
    geo = geometry_of(bundle)
    g = Geometry(sh.raw)
    # The number of DEFINITION draws a slot makes is a property of that
    # slot's composition, not of the shape: `Geometry.n_definition_challenges`
    # is the port for the two BILINEAR slots (08, 09) and returns the generic
    # count elsewhere.  So this term is read from the capture -- a declared
    # count, an INPUT -- and the two slots the port really covers are
    # compared with the derivation instead.  Said here rather than hidden in
    # a number that happened to come out right.
    n_defs = sum(len(a["definition_challenges"]) for a in bundle.stages[0].slots)
    bilinear = [
        {"slot": s,
         "captured": len(bundle.stages[0].slots[s]["definition_challenges"]),
         "derived": g.n_definition_challenges(s)}
        for s in (8, 9)
    ]
    # [ROUND 9b] and the EIGHT zero-check slots are derived too now, from the
    # pad rule, which is the half of the sentence above that finding M-F1
    # made worth deriving.  Thirteen of the twenty-three are still read.
    pads = pad_rule(bundle)
    sc_rounds = sum(m + e for m, e, _d in sh.slots)

    # ---- the transcript replay, exactly as `RunReplay` counts it
    # positions: 1 (the run binding) + per stage 1 header + 5 per slot
    # (the site's before, before_definition, before, after, the site's after)
    # + 2 for the M opening + 2 per PCS opening.
    positions = 1 + L * (1 + 5 * sh.n_slots + 2) + 2 * len(geo["roles"])
    # challenges COMPARED: 3 LogUp + per slot (its definition draws, its
    # mask challenge c, one per sumcheck round) + M's theta and its
    # proximity rhos + per opening (one lambda per claim, one rho per row).
    m_prox = [len(st.mask["proximity_rhos"]) for st in bundle.stages]
    challenges = (
        L * (3 + n_defs + sh.n_slots + sc_rounds + 1)
        + sum(m_prox)
        + sum(r["claims"] + r["rows"] for r in geo["roles"])
    )

    # ---- the hash layer: every opened column of every commitment
    pcs_cols = sum(sh.opened_cols for _r in geo["roles"])
    pcs_bytes = sum(sh.opened_cols * r["rows"] * 8 for r in geo["roles"])
    m_cols = L * sh.mask_columns
    m_bytes = L * sh.mask_columns * (2 * sh.n_slots + 4) * 8
    tree_depth = sh.log_cols + (sh.inv_rate.bit_length() - 1)

    # ---- the masking layer: L_s = (main + ext) * degree + 2
    lens = [(m + e) * d + 2 for m, e, d in sh.slots]
    mask_msg = 1 << 9  # zk.rs::MASK_LOG_MSG, and the shape now refuses above it
    mask_q = sh.mask_columns

    # ---- the joint systems
    # [ROUND 9j] a standalone block has no boundary: its identified rows are
    # the two EXTERNAL endpoints' data planes, each against `A@0`'s IO plane
    # (slots 21 and 22), so `2 * L * endpoint data rows` with L = 1.  The
    # old fallback -- the FIRST role's data rows -- is `A`'s at a block, and
    # no run of one block had ever been read to show it.
    standalone = getattr(bundle, "standalone", False)
    if bundle.boundaries:
        ident_rows = bundle.boundary(0)["data_rows"]
    elif standalone:
        ident_rows = next(r["data_rows_declared"] for r in geo["roles"]
                          if r["kind"] == "external-endpoint")
    else:
        ident_rows = geo["roles"][0]["data_rows_declared"]
    pairs = 2 * L * ident_rows
    sum_of_parts = L * SHAPE_INDEPENDENT["h_disclosed"][0]

    per_role = []
    for r in geo["roles"]:
        if r["key"].startswith("A@"):
            disc, gen = SHAPE_INDEPENDENT["a_disclosed"][0], 2 * (sh.a_groups + 1)
        elif r["key"].startswith("H@"):
            disc, gen = SHAPE_INDEPENDENT["h_disclosed"][0], 2 * (sh.h_groups + 1)
        else:
            disc, gen = 0, 2 * (r["groups"] + 1)
        # The law: one reserved PAIR per claim, plus the proximity pair --
        # and an EXTERNAL ENDPOINT has one SPARE mask row on top (report 3,
        # finding 3, ruling M-7's "a pair, a proximity pair and a spare"),
        # while a derived boundary has none.
        spare = 1 if r["kind"] == "external-endpoint" else 0
        per_role.append({
            **r,
            "predicted_disclosed_dimension": disc,
            "predicted_generators": gen,
            "spare_mask_rows": spare,
            "predicted_non_data_rows": 2 * r["claims"] + 2 + spare,
            "non_data_rows_match": r["non_data_rows_by_row_roles"]
            == 2 * r["claims"] + 2 + spare,
            "the_law": "non-data rows = 2 * claims + 2 (the proximity pair) "
            "+ 1 for an external endpoint's spare mask row",
        })

    return {
        "shape": sh.name,
        "blocks": L,
        "tokens": sh.tokens, "width": sh.width, "hidden": sh.hidden,
        "q_heads": sh.q_heads, "kv_heads": sh.kv_heads, "head_dim": sh.head_dim,
        "lkv": (sh.kv_heads - 1).bit_length(),
        "cols": sh.cols, "encoded_cols": sh.enc_cols,
        "opened_cols": sh.opened_cols,
        "a_groups": sh.a_groups, "h_groups": sh.h_groups,
        "n_slots": sh.n_slots,
        "shape_independent": {k: v[0] for k, v in SHAPE_INDEPENDENT.items()},
        "shape_independent_why": {k: v[1] for k, v in SHAPE_INDEPENDENT.items()},
        "pad_rule": pads,
        "corrections_and_geometry": corrections_and_geometry(bundle),
        "receipt": receipt(bundle),
        "replay": {
            "positions_checked": positions,
            "challenges_checked": challenges,
            "definition_draws_per_stage": n_defs,
            "definition_draws_are_read_from_the_capture": True,
            "definition_draws_derived_for": sorted(
                set(ZERO_CHECK_SLOTS) | {8, 9}),
            "definition_draws_still_read_from_the_capture": [
                s for s in range(sh.n_slots)
                if s not in ZERO_CHECK_SLOTS and s not in (8, 9)],
            "bilinear_definition_draws_derived_and_compared": bilinear,
            "sumcheck_rounds_per_stage": sc_rounds,
            "m_proximity_rhos_per_stage": m_prox,
            # [ROUND 9j] a standalone block squeezes no position tag
            "segment_position_tags": 0 if standalone else 2 * L,
        },
        "hash_layer": {
            "openings": len(geo["roles"]) + L,
            "columns": pcs_cols + m_cols,
            "column_bytes": pcs_bytes + m_bytes,
            "largest_column_bytes": max(r["rows"] for r in geo["roles"]) * 8,
            "tree_depth": tree_depth,
        },
        "masking": {
            "rows": 2 * sh.n_slots + 4,
            "functionals": 34,
            "slot_lengths": lens,
            "largest_L": max(lens),
            "largest_L_slot": lens.index(max(lens)),
            "mask_msg": mask_msg,
            "mask_q": mask_q,
            "ruling_C4_headroom": mask_msg - max(lens) - mask_q,
            "coefficient_unknowns_fp": 2 * sum(lens),
            "q_entries_per_stage": 1 << (sh.mask_log_dom - 2),
        },
        "terminals": {
            "slot_checks_expected": sh.n_slots * L,
            "why": "public_tables_included is "
            f"{bundle.public_tables_included}, so "
            + ("every slot's tables are carried and all 23 can be evaluated"
               if bundle.public_tables_included
               else "the eleven table-bearing slots stay open"),
        },
        "joint": {
            "identified_row_pairs": pairs,
            "sum_of_the_parts": sum_of_parts,
            "whole_run_joint": sum_of_parts,
            "whole_run_generators": sum(
                p["predicted_generators"] for p in per_role
            ) + L * 2,
        },
        "per_commitment": per_role,
        "what_this_is": "a PREDICTION, computed from run.json[\"shape\"] and "
        "the capture's declared per-opening geometry, before the gate was "
        "run at this shape.  Every figure the gate reports that this does "
        "not name, or names wrongly, is the round's headline",
        "what_this_is_not": "a privacy statement, and not a check: nothing "
        "here reads a published value",
    }


# ------------------------------------------------------- validation
VALIDATE = [
    ("replay.positions_checked", ["stage2_transcript_replay", "positions_checked"]),
    ("replay.challenges_checked", ["stage2_transcript_replay", "challenges_checked"]),
    ("hash_layer.openings", ["stage9_hash_layer", "openings"]),
    ("hash_layer.columns", ["stage9_hash_layer", "columns_checked"]),
    ("hash_layer.column_bytes", ["stage9_hash_layer", "bytes_hashed"]),
    ("terminals.slot_checks_expected",
     ["stage8_plane_index_and_terminals", "terminal_identity",
      "slot_checks_expected"]),
    ("masking.rows", ["stage3_per_commitment", "masking_commitments", 0, "rows"]),
    ("joint.whole_run_joint",
     ["stage4_the_boundary", "whole_run", "joint_fp"]),
    ("joint.sum_of_the_parts",
     ["stage4_the_boundary", "whole_run", "sum_of_parts_fp"]),
    ("joint.whole_run_generators",
     ["stage4_the_boundary", "whole_run", "generators"]),
    ("joint.identified_row_pairs",
     ["stage4_the_boundary", "whole_run", "identified_rows"]),
]


def _dig(o, path):
    for k in path:
        if o is None:
            return None
        o = o[k] if not isinstance(k, int) else o[k]
    return o


def _pget(pred, dotted):
    o = pred
    for k in dotted.split("."):
        o = o[k]
    return o


def validate(pred_fn, bundle_dir, record_path) -> dict:
    b = load_bundle(bundle_dir)
    p = pred_fn(b)
    with open(record_path) as fh:
        rec = json.load(fh)
    rows, bad = [], []
    for name, path in VALIDATE:
        want = _pget(p, name)
        try:
            got = _dig(rec, path)
        except (KeyError, IndexError, TypeError):
            got = "<absent>"
        rows.append({"figure": name, "predicted": want, "recorded": got,
                     "equal": want == got})
        if want != got:
            bad.append(f"{name}: predicted {want}, the record says {got}")
    # [ROUND 9b] the pad rule, two ways: the derived per-slot draw counts
    # against the capture's declaration (both are available before the gate
    # runs), and the record's own slot checks -- which are what says the
    # PORT consumed those draws, since `Ctx.pad_draws` refuses by name on a
    # mismatch and a refused slot is not in `slot_checks_equal`.
    bad.extend(p["pad_rule"]["disagreements"])
    want_eq = p["terminals"]["slot_checks_expected"]
    try:
        got_eq = sum(len(s["equal"]) for s in
                     rec["stage8_plane_index_and_terminals"]
                     ["terminal_identity"]["per_stage"])
    except (KeyError, IndexError, TypeError):
        got_eq = "<absent>"
    rows.append({"figure": "terminals.slot_checks_equal", "predicted": want_eq,
                 "recorded": got_eq, "equal": want_eq == got_eq})
    if want_eq != got_eq:
        bad.append(f"terminals.slot_checks_equal: predicted {want_eq}, "
                   f"the record says {got_eq}")
    for r in p["per_commitment"]:
        recorded = next(
            (x for x in rec["stage3_per_commitment"]["per_commitment"]
             if x["role"] == r["key"]), None)
        if recorded is None:
            bad.append(f"{r['key']}: no such commitment in the record")
            continue
        for field, want in (("disclosed_dimension", r["predicted_disclosed_dimension"]),
                            ("rows", r["rows"]),
                            ("claims", r["claims"]),
                            ("groups", r["groups"])):
            if recorded[field] != want:
                bad.append(f"{r['key']}.{field}: predicted {want}, "
                           f"the record says {recorded[field]}")
    return {
        "bundle": b.name,
        "record": os.path.basename(record_path),
        "figures": rows,
        "mismatches": bad,
        "ok": not bad,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--validate", action="append", default=[],
                    metavar="BUNDLE_DIR:RECORD.json")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", default="prediction")
    args = ap.parse_args(argv)

    b = load_bundle(args.bundle)
    out = {"prediction": predict(b), "validation": []}
    for spec in args.validate:
        d, r = spec.rsplit(":", 1)
        out["validation"].append(validate(predict, d, r))
    out["validated_on"] = [v["bundle"] for v in out["validation"]]
    out["validation_ok"] = all(v["ok"] for v in out["validation"])
    out["ok"] = out["validation_ok"] and bool(out["validation"])
    os.makedirs(args.evidence, exist_ok=True)
    path = os.path.join(args.evidence, f"{args.name}.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for v in out["validation"]:
        print(f"validated on {v['bundle']}: {'OK' if v['ok'] else 'MISMATCH'}")
        for m in v["mismatches"]:
            print("   ", m)
    print(json.dumps({k: v for k, v in out["prediction"].items()
                      if k in ("replay", "hash_layer", "masking", "terminals",
                               "joint", "shape_independent", "pad_rule",
                               "receipt")}, indent=1))
    print(f"record: {path}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
