#!/usr/bin/env python3
"""Independent re-derivation of the bound-FFN IO layout and frame (review O7).

Reviewer: Opus 5.  Implementation pin: 137b109296d9a4cc9a05792bfdbd91aa45850abe
("Reserve FFN equality masks in one commitment before all challenges"),
profile ``ffn-v3-mr1-fresh-io-poc/2``.  The superseded ``/1`` draft
(``e8d4261``) differed only in where the two equality CFS slots live, so both
frame lengths are modelled here and their difference is asserted.

The profile states four fixture numbers: the A commitment grows to **702**
rows, its two dedicated IO mask pairs sit at rows **698/699** and **700/701**,
the A opening has **seven** groups, and each endpoint is a **seven**-row hiding
commitment opened once.  This module derives all of them from the layout rules
instead of reading them back:

``a_row_map``
    Every A row of the repaired function-1 layout, allocated one site at a time
    exactly as ``ZkLayoutV3::with_masks`` does (``hashline/src/zk.rs:2002``),
    then the four rows ``ZkLayoutV3::with_io`` appends (``zk.rs:2057``).  The
    map is checked for *disjointness and completeness*: no IO row may alias a
    data row, an existing terminal-mask row, a table row, a table-mask row or
    the proximity pair, and no row may be left unaccounted.

``endpoint_plane``
    The endpoint commitment of ``private_seam::prepare_with_rng``
    (``hashline/src/private_seam.rs:170``) at the fixed 32x16 shape: two data
    rows, the terminal-mask pair, the proximity budget, and the CFS slot
    ``(log_len + 1, DEGREE)`` (``private_seam.rs:106``) whose coefficient count
    is ``CfsMask::len`` (``zkp-core/src/sumcheck.rs:197``).

``io_frame_len``
    The receipt length: ``io_shape`` (``zk_ffn_fresh_wire.rs:228`` -- the base
    ``Shape`` with ``rows[1] += 4``, ``a_groups = 7`` and ``mask_rows += 4``)
    minus the old header, plus ``EXTRA_BYTES`` (``zk_ffn_fresh_io.rs:15-17``).
    The base payload comes from this reviewer's O5 model
    ``zk60_opus_wire_length``, itself derived three independent ways.

Everything is exact Python integer arithmetic.  This is a layout and transport
model only.  It makes no soundness, zero-knowledge or privacy claim, and a
matching number is evidence about shapes, never about a construction.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import zk60_opus_wire_length as wire  # noqa: E402

# --------------------------------------------------------------------------
# Fixed constants of the IO profile.
# --------------------------------------------------------------------------
PROFILE = b"hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2"
MAGIC = b"HFFNIO\0\x02"
DRAFT_PROFILE = b"hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/1"  # superseded
POLICY_MAGIC = b"HFFNEXP1"
PROFILE_SHIFTS = (7, 0, 14, 6)

# zk_ffn_fresh_io.rs:14  -- two equality slots, ten variables, degree two.
IO_SPECS = ((10, 2), (10, 2))
# zk_ffn_fresh_io.rs:19  -- 8 magic + 32 context + 4 + 4 scales + 2 * 32 roots.
EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2 * 32
# zk_ffn_fresh_wire.rs:219 -- the IO payload's two changes to the base shape.
IO_EXTRA_A_ROWS = 4
IO_A_GROUPS = 7

# private_seam.rs:28-36
SEAM_LOG_COLS = 8
SEAM_CHECKS = 256
SEAM_INV_RATE = 8
SEAM_MASK_ROWS = 5
SEAM_DEGREE = 2
SEAM_SHAPE = (32, 16)
SEAM_PATH_DEPTH = 11  # log2(512 * 8 / 256) + ... == the recorded column path


def cfs_len(n_vars: int, degree: int) -> int:
    """``CfsMask::len`` (zkp-core/src/sumcheck.rs:197)."""
    return n_vars * degree + 2


# --------------------------------------------------------------------------
# The A row map, allocated site by site.
# --------------------------------------------------------------------------
def a_row_map(shifts=PROFILE_SHIFTS, dims=wire.PROFILE_DIMS,
              log_cols: int = wire.LOG_COLS, io: bool = True) -> dict:
    """Every A row of the repaired function-1 layout, as an allocation trace."""
    wire.check_shifts(shifts)
    lay = wire.layout(*dims)
    log_n = min(log_cols, lay["log_a_min"])
    a_n = 1 << log_n
    width = 2  # mr1: every single-row mask site is an Fp2 pair
    sites = []
    cursor = 0
    planes = {}

    def take(kind, name, rows):
        nonlocal cursor
        start = cursor
        cursor += rows
        sites.append({"kind": kind, "name": name, "start": start, "rows": rows})
        if kind == "data":
            planes[name] = start * a_n
        return start

    # The ten data planes, in Layout::new's order (statement.rs:160-163).
    for name in ("g8", "rg", "a16", "u16", "ru", "h16", "rh"):
        for b in range(lay["nb_f"]):
            take("data", f"{name}[{b}]", lay["tfb"] // a_n)
    for name in ("x", "z", "rd"):
        for c in range(lay["nb_d"]):
            take("data", f"{name}[{c}]", lay["tdb"] // a_n)
    assert cursor == lay["a_len"] // a_n, "data rows disagree with Layout::new"

    # The mask sites, in ZkLayoutV3::with_masks's order (zk.rs:2013-2027).
    for i in range(7 * lay["nb_f"]):
        take("mask", f"a_mf[{i}]", width)
    for i in range(3 * lay["nb_d"]):
        take("mask", f"a_md[{i}]", width)
    for i in range(lay["nb_d"]):
        take("mask", f"a_mgu[{i}]", width)
    for i in range(lay["nb_f"]):
        take("mask", f"a_mdd[{i}]", width)
    take("prox", "a_prox", width)
    for i, (tag, size) in enumerate(wire.table_specs(shifts)):
        log_size = max(size.bit_length() - 1, log_n)
        rows = (1 << log_size) // a_n
        take("table", f"tab[{i}].a_row", rows)
        take("mask", f"tab[{i}].a_mask", 2 if rows == 1 else rows)
    base_rows = cursor

    # ZkLayoutV3::with_io (zk.rs:2057): two pairs appended after everything.
    a_io = None
    if io:
        a_io = [base_rows, base_rows + 2]
        take("mask", "a_io[0] (X endpoint)", width)
        take("mask", "a_io[1] (z16 endpoint)", width)

    # Disjointness and completeness, the two properties the review needs.
    covered = []
    for site in sites:
        covered.extend(range(site["start"], site["start"] + site["rows"]))
    assert len(covered) == len(set(covered)), "A row map: a site aliases another"
    assert sorted(covered) == list(range(cursor)), "A row map: a row is unaccounted"

    return {
        "a_n": a_n,
        "log_n": log_n,
        "data_rows": lay["a_len"] // a_n,
        "base_rows": base_rows,
        "a_rows": cursor,
        "a_io": a_io,
        "x_slice": {"offset": planes["x[0]"], "log_size": lay["log_t"] + lay["log_db"]},
        "z_slice": {"offset": planes["z[0]"], "log_size": lay["log_t"] + lay["log_db"]},
        "sites": sites,
    }


def io_mask_rows(row_map: dict) -> list:
    """The four IO rows, expanded from the two pair heads."""
    return [r for head in row_map["a_io"] for r in (head, head + 1)]


def base_mask_rows(row_map: dict) -> list:
    """Every A row allocated before ``with_io`` appended its pairs."""
    return list(range(row_map["base_rows"]))


# --------------------------------------------------------------------------
# The A claim inventory, and therefore the opening-group count.
# --------------------------------------------------------------------------
def a_claim_groups(shifts=PROFILE_SHIFTS, dims=wire.PROFILE_DIMS,
                   io: bool = True) -> dict:
    """A claims and their column-tail groups (build_claims_zk_v3, zk.rs:3305).

    Grouping is by the claim's column tail, first occurrence wins
    (zkp-core/src/pcs.rs:809).  Five distinct tails exist in the base profile
    -- rho_F, rho_D, p2, p5 and rho_tab -- and each IO equality adds its own.
    """
    lay = wire.layout(*dims)
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    claims = []
    for b in range(nb_f):
        for name in ("g8", "rg", "a16", "u16", "ru", "h16", "rh"):
            claims.append((f"zcF {name}[{b}]", "rho_F"))
    for c in range(nb_d):
        for name in ("x", "z", "rd"):
            claims.append((f"zcD {name}[{c}]", "rho_D"))
    for c in range(nb_d):
        claims.append((f"gu x[{c}]", "p2"))
    for b in range(nb_f):
        claims.append((f"d h16[{b}]", "p5"))
    for i, _ in enumerate(wire.table_specs(shifts)):
        claims.append((f"tab[{i}] multiplicities", "rho_tab"))
    base = len(claims)
    if io:
        claims.append(("io[0] X equality", "rho_io0"))
        claims.append(("io[1] z16 equality", "rho_io1"))
    groups = []
    for _, tail in claims:
        if tail not in groups:
            groups.append(tail)
    return {"claims": [c for c, _ in claims], "base_claims": base,
            "total_claims": len(claims), "groups": groups,
            "n_groups": len(groups)}


# --------------------------------------------------------------------------
# The endpoint commitment.
# --------------------------------------------------------------------------
def endpoint_plane(shape=SEAM_SHAPE) -> dict:
    """One ``PreparedPlane`` at the fixed FFN IO shape (private_seam.rs:170)."""
    rows, cols = shape
    length = rows * cols
    assert length & (length - 1) == 0, "seam plane length must be a power of two"
    log_len = length.bit_length() - 1
    n = 1 << SEAM_LOG_COLS
    data_rows = -(-length // n)  # div_ceil
    first_mask = data_rows
    spec = (log_len + 1, SEAM_DEGREE)
    return {
        "values": length,
        "log_len": log_len,
        "data_rows": data_rows,
        "commitment_rows": data_rows + SEAM_MASK_ROWS,
        "terminal_mask_rows": [first_mask, first_mask + 1],
        "prox_mask_row": first_mask + 2,
        "prox_pair_checked": [first_mask + 2, first_mask + 3],
        "unused_random_rows": [first_mask + 4],
        "cfs_spec": spec,
        "cfs_coefficients": cfs_len(*spec),
        "claim_slice": {"offset": 0, "log_size": log_len},
    }


# --------------------------------------------------------------------------
# The receipt frame.
# --------------------------------------------------------------------------
def argument_bytes() -> int:
    """zk_ffn_fresh_io.rs:16 -- gamma, ten degree-2 rounds, two terminals, g."""
    (rounds, degree) = IO_SPECS[0]
    return 16 + rounds * (degree + 1) * 16 + 2 * 16 + 16


def draft_mask_bytes() -> int:
    """The SUPERSEDED ``/1`` draft's separate two-slot CFS opening.

    ``/1`` committed the two equality slots in their own ``MaskCommit`` during
    finalization (2*2+4 = 8 base rows) and carried its root and opening in the
    receipt.  ``/2`` has neither: the slots live in the FFN M.  Kept only to
    assert the difference between the two recorded frame lengths.
    """
    n_base = 2 * len(IO_SPECS) + 4
    return 2 * 1024 * 16 + 256 * (8 + n_base * 8 + 32 + 12 * 32)


def endpoint_open_bytes() -> int:
    """zk_ffn_fresh_io.rs:15 -- one group, one prox vector, 256 columns."""
    rows = endpoint_plane()["commitment_rows"]
    return 2 * 512 * 16 + SEAM_CHECKS * (8 + rows * 8 + 32 + SEAM_PATH_DEPTH * 32)


def extra_bytes(draft: bool = False) -> int:
    """``EXTRA_BYTES`` (zk_ffn_fresh_io.rs:17): magic, binding, two arguments,
    two endpoint openings -- and, in the superseded draft only, the second
    mask root and its opening."""
    total = (len(MAGIC) + 32 + 2 * argument_bytes() + 2 * endpoint_open_bytes())
    return total + 32 + draft_mask_bytes() if draft else total


def io_payload_len(shifts=PROFILE_SHIFTS, private: bool = False,
                   dims=wire.PROFILE_DIMS, draft: bool = False) -> int:
    """``io_shape(...).len() - HEADER`` (zk_ffn_fresh_wire.rs:228-236).

    Re-derived rather than delegated: the base closed form with the A opening
    taken at ``rows[1] + 4`` rows and ``IO_A_GROUPS`` groups, and the CFS mask
    opening's sampled columns taken at ``2 * 8 + 4 = 20`` base rows because the
    two equality slots are reserved in the FFN M.  Under the superseded draft
    the base M kept its six slots and 16 base rows.
    """
    rows = list(wire.rows_triple(shifts, private, dims))
    rows[1] += IO_EXTRA_A_ROWS
    specs = wire.mask_specs(private, dims)
    mask_rows = 2 * len(specs) + 4 + (0 if draft else 2 * len(IO_SPECS))

    def opening(groups, n_rows, hiding):
        return ((groups + 1) * (512 if hiding else 256) * 16
                + wire.CHECKS * (8 + n_rows * 8 + (32 if hiding else 0) + 11 * 32))

    arguments = sum((1 + rounds * (degree + 1) + terms) * 16
                    for (rounds, degree), terms in zip(specs, wire.TERMINALS))
    masks = 2 * 1024 * 16 + wire.CHECKS * (8 + mask_rows * 8 + 32 + 12 * 32)
    total = (wire.HEADER + 3 * 44 + 32 + arguments + masks
             + opening(2, rows[0], private)
             + opening(IO_A_GROUPS, rows[1], True)
             + opening(5, rows[2], True))
    return total - wire.HEADER


def io_frame_len(shifts=PROFILE_SHIFTS, private: bool = False,
                 dims=wire.PROFILE_DIMS, draft: bool = False) -> int:
    """``encoded_len`` (zk_ffn_fresh_io.rs:487)."""
    total = (io_payload_len(shifts, private, dims, draft)
             + extra_bytes(draft))
    if total > wire.MAX_WIRE_BYTES:
        raise ValueError("FFN IO: frame exceeds bound")
    return total


def mask_base_rows(private: bool = False, dims=wire.PROFILE_DIMS) -> int:
    """The FFN mask commitment's base rows: 2 per slot plus b_re/b_im/u_re/u_im
    (zk.rs:435).  Eight slots under this profile, so twenty rows."""
    return 2 * (len(wire.mask_specs(private, dims)) + len(IO_SPECS)) + 4


def report(shifts=PROFILE_SHIFTS) -> dict:
    row_map = a_row_map(shifts)
    endpoint = endpoint_plane()
    return {
        "profile": PROFILE.decode(),
        "shifts": list(shifts),
        "a_rows_base": row_map["base_rows"],
        "a_rows_io": row_map["a_rows"],
        "a_io_pairs": [[h, h + 1] for h in row_map["a_io"]],
        "x_slice": row_map["x_slice"],
        "z_slice": row_map["z_slice"],
        "a_groups": a_claim_groups(shifts)["n_groups"],
        "a_claims": a_claim_groups(shifts)["total_claims"],
        "endpoint": endpoint,
        "expected_policy_bytes": EXPECTED_BYTES,
        "extra_bytes": extra_bytes(),
        "cfs_slots": len(wire.mask_specs(False)) + len(IO_SPECS),
        "cfs_base_rows": mask_base_rows(),
        "frame_bytes": {"p1": io_frame_len(shifts, False),
                        "p3": io_frame_len(shifts, True)},
        "superseded_draft_frame_bytes": {
            "p1": io_frame_len(shifts, False, draft=True),
            "p3": io_frame_len(shifts, True, draft=True)},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    out = report()
    if args.json:
        print(json.dumps(out, indent=2, sort_keys=True))
        return
    print(f"A rows: {out['a_rows_base']} -> {out['a_rows_io']}")
    print(f"IO mask pairs: {out['a_io_pairs']}")
    print(f"A opening groups: {out['a_groups']} over {out['a_claims']} claims")
    print(f"endpoint: {out['endpoint']['commitment_rows']} rows, "
          f"masks {out['endpoint']['terminal_mask_rows']}, "
          f"prox {out['endpoint']['prox_mask_row']}, "
          f"CFS {out['endpoint']['cfs_spec']} "
          f"({out['endpoint']['cfs_coefficients']} coefficients)")
    print(f"CFS: {out['cfs_slots']} slots, {out['cfs_base_rows']} base rows")
    print(f"frame bytes: P1 {out['frame_bytes']['p1']}, P3 {out['frame_bytes']['p3']}")
    print(f"superseded /1 draft: P1 {out['superseded_draft_frame_bytes']['p1']}, "
          f"P3 {out['superseded_draft_frame_bytes']['p3']}")


if __name__ == "__main__":
    main()
