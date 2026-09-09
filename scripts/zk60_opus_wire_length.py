#!/usr/bin/env python3
"""Independent model of the fresh-FFN wire frame length (review O5).

Reviewer: Opus 5.  Source pin: 29d34362f54a8539799a6f7a74211dd43aed15cc.

This script does NOT import anything from the Rust crate or from the other
review scripts.  It re-derives the encoded length of the experimental
``ffn-v3-mr1-fresh-poc/1`` frame three independent ways and compares them:

``shape_len``
    A transcription of the closed form in ``Shape::len``
    (``hashline/src/zk_ffn_fresh_wire.rs:39``).

``writer_len``
    A transcription of what the payload writer actually emits:
    ``LayerProofZk::to_bytes`` (``hashline/src/zk.rs:814``) together with
    ``SumcheckProof::write_bytes`` (``zkp-core/src/sumcheck.rs:27``),
    ``MaskOpening::write_bytes`` (``hashline/src/zk.rs:411``),
    ``Opening::write_bytes`` (``zkp-core/src/pcs.rs:116``) and
    ``OpeningZk::write_bytes`` (``zkp-core/src/pcs.rs:582``).

``reader_len``
    A transcription of the byte cursor of ``Proof::from_bytes``
    (``hashline/src/zk_ffn_fresh_wire.rs:191``).

The row counts driving all three come from an independent re-derivation of
``zkp_core::ffn_v3::Layout::new`` and ``ZkLayoutV3::with_masks`` (mr1 = true,
pred = false), not from any recorded value.

Everything is exact Python integer arithmetic.  This is a transport-format
length model only: it makes no cryptographic, soundness or privacy claim.
"""

from __future__ import annotations

import argparse
import functools
import itertools
import json

# ---------------------------------------------------------------------------
# Fixed profile constants (zk_ffn_fresh_wire.rs:7-12, zk_ffn_fresh_poc.rs:46).
# ---------------------------------------------------------------------------
MAGIC = b"HFFNMR1\x01"
HEADER = 8 + 1 + 32          # magic+version, weight mode, expectation digest
CHECKS = 256                 # num_col_checks
TERMINALS = (3, 2, 10, 4, 1, 12)
MAX_WIRE_BYTES = 32 * 1024 * 1024
MAX_CONTEXT_BYTES = 4096
MAX_TABLE_DIGEST_BYTES = 256

LOG_COLS = 8                 # LayerParams::log_cols
INV_RATE = 8                 # LayerParams::inv_rate
MASK_LOG_MSG = 9             # zk.rs:369  -> a-row message length 512
MASK_LOG_DOM = 12            # zk.rs:370  -> mask domain 4096, path depth 12
MASK_Q = 256                 # zk.rs:371  -> pads per a-row == opened columns

SHIFT_MIN, SHIFT_MAX = -8, 16   # zkp-core/src/ffn_v3/statement.rs:38-39
PROFILE_DIMS = (32, 16, 16)     # T32/d16/f16 (zk_ffn_fresh_poc.rs:69)

FP_BYTES = 8                 # one base-field limb
FP2_BYTES = 16               # two limbs
DIGEST_BYTES = 32


# ---------------------------------------------------------------------------
# zkp_core::ffn_v3::Layout::new  (statement.rs:152)
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def layout(t_rows: int, d: int, f: int) -> dict:
    if t_rows <= 0 or t_rows & (t_rows - 1):
        raise ValueError("t_rows must be a power of two")
    log_t = t_rows.bit_length() - 1
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    if log_db < 4 or log_fb < 4:
        raise ValueError("need >= 16 | d, f")
    db, fb = 1 << log_db, 1 << log_fb
    nb_d, nb_f = d // db, f // fb
    tfb, tdb = t_rows * fb, t_rows * db
    # A: 7 f-planes per f-block, then 3 d-planes per d-block.
    a_len = 7 * nb_f * tfb + 3 * nb_d * tdb
    # W: (wg, wu, wd) each nb_d * nb_f blocks of db * fb.
    wb = db * fb
    w_len = 3 * nb_d * nb_f * wb
    # H: hg/hu/hh are nb_f pairs of tfb, hz is nb_d pairs of tdb.
    h_len = 3 * nb_f * 2 * tfb + nb_d * 2 * tdb
    return {
        "t_rows": t_rows, "d": d, "f": f,
        "log_t": log_t, "log_db": log_db, "log_fb": log_fb,
        "nb_d": nb_d, "nb_f": nb_f, "tfb": tfb, "tdb": tdb,
        "a_len": a_len, "w_len": w_len, "h_len": h_len,
        "wb": wb, "log_wb": log_db + log_fb,
        "log_a_min": log_t + min(log_db, log_fb),
    }


# ---------------------------------------------------------------------------
# tag/window helpers (statement.rs:49-57) and table_specs_v3 (zk.rs:1940)
# ---------------------------------------------------------------------------
def rem_rows(sh: int) -> int:
    return 1 if sh <= 0 else 1 << sh


def tag_rem_v3(sh: int) -> int:
    return 64 + (sh + 8)


TAG_ACT16 = 3
TAG_INT16 = 4


def table_specs(shifts) -> list:
    sg, su, sh, sz = shifts
    return [(TAG_ACT16, 256), (TAG_INT16, 1 << 16),
            (tag_rem_v3(sg), rem_rows(sg)), (tag_rem_v3(su), rem_rows(su)),
            (tag_rem_v3(sh), rem_rows(sh)), (tag_rem_v3(sz), rem_rows(sz))]


def check_shifts(shifts) -> None:
    """Statement::check's shift window (statement.rs:93)."""
    for s in shifts:
        if not SHIFT_MIN <= s <= SHIFT_MAX:
            raise ValueError(f"shift {s} outside {SHIFT_MIN}..={SHIFT_MAX}")


# ---------------------------------------------------------------------------
# ZkLayoutV3::with_masks(32, 16, 16, params, shifts, pred=False, mr1=True)
# (zk.rs:2000).  Returns the committed row counts the wire format uses.
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def zk_layout(shifts, dims=PROFILE_DIMS, log_cols: int = LOG_COLS) -> dict:
    check_shifts(shifts)
    lay = layout(*dims)
    width = 2                                   # mr1 pairs every mask row
    log_n = min(log_cols, lay["log_a_min"])
    a_n = 1 << log_n
    log_s = max(log_n, 16)
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]

    # --- A rows -----------------------------------------------------------
    r = lay["a_len"] // a_n
    r += 7 * nb_f * width                       # a_mf
    r += 3 * nb_d * width                       # a_md
    r += nb_d * width                           # a_mgu
    r += nb_f * width                           # a_mdd
    r += width                                  # a_prox
    slots = []
    for tag, size in table_specs(shifts):
        log_size = max(size.bit_length() - 1, log_n)
        rows = (1 << log_size) // a_n
        r += rows                               # a_row (the multiplicities)
        r += 2 if rows == 1 else rows           # a_mask (paired if singleton)
        slots.append({"tag": tag, "size": size, "log_size": log_size,
                      "rows": rows})
    a_rows = r

    # --- H rows -----------------------------------------------------------
    r = lay["h_len"] // a_n
    r += 3 * nb_f * 2                           # h_mf (re, im)
    r += nb_d * 2                               # h_md
    r += 2 + 2                                  # h_u, h_up
    r += width                                  # h_prox
    for slot in slots:
        r += 4 * slot["rows"]                   # h_re, h_im, h_mre, h_mim
    h_rows = r

    # --- W rows -----------------------------------------------------------
    log_wn = min(log_cols, lay["log_wb"])
    w_n = 1 << log_wn
    r = lay["w_len"] // w_n
    w_rows_p1 = r
    r += 2 * nb_d * nb_f * width                # w_mgu
    r += nb_f * nb_d * width                    # w_mdd
    r += width                                  # w_prox
    w_rows_p3 = r

    return {"a_n": a_n, "w_n": w_n, "log_n": log_n, "log_s": log_s,
            "a_rows": a_rows, "h_rows": h_rows,
            "w_rows_p1": w_rows_p1, "w_rows_p3": w_rows_p3,
            "slots": slots, "lay": lay}


# ---------------------------------------------------------------------------
# mask_specs_v3 (zk.rs:2138): (rounds, degree) per sumcheck, in wire order.
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def mask_specs(is_p3: bool, dims=PROFILE_DIMS, log_cols: int = LOG_COLS) -> list:
    lay = layout(*dims)
    log_n = min(log_cols, lay["log_a_min"])
    log_s = max(log_n, 16)
    x = 1 if is_p3 else 0
    return [
        (lay["log_db"] + 1 + x, 2),
        (lay["log_fb"] + 1 + x, 2),
        (lay["log_t"] + lay["log_fb"] + 1, 4),
        (lay["log_t"] + lay["log_db"] + 1, 4),
        (log_n + 1, 2),
        (log_s + 1, 3),
    ]


# ---------------------------------------------------------------------------
# The terminal-vector lengths the v3 verifier enforces (zk.rs:3500, 3538,
# 3563, 3596, 3620), re-derived from the layout rather than copied from the
# wire module's hard-coded `TERMINALS`.
# ---------------------------------------------------------------------------
def terminal_counts(shifts, dims=PROFILE_DIMS) -> tuple:
    lay = layout(*dims)
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    n_slots = len(table_specs(shifts))
    return (nb_d + 2 * nb_d * nb_f,     # gu_term
            nb_f + nb_f * nb_d,         # d_term
            10 * nb_f,                  # zc20_term (zero-check F)
            4 * nb_d,                   # zc17_term (zero-check D)
            1,                          # zs_term (a single Fp2)
            2 * n_slots)                # tab_term (m~ and h_t~ per slot)


def mask_base_rows(is_p3: bool, dims=PROFILE_DIMS) -> int:
    """Rows of the CFS mask matrix: 2 per sumcheck plus b_re/b_im/u_re/u_im."""
    return 2 * len(mask_specs(is_p3, dims)) + 4


@functools.lru_cache(maxsize=None)
def rows_triple(shifts, private: bool, dims=PROFILE_DIMS) -> tuple:
    """(W, A, H) committed row counts, as ``Shape::new`` builds them."""
    zl = zk_layout(shifts, dims)
    w = zl["w_rows_p3"] if private else zl["w_rows_p1"]
    return (w, zl["a_rows"], zl["h_rows"])


# ---------------------------------------------------------------------------
# Model 1: the closed form of Shape::len (zk_ffn_fresh_wire.rs:39).
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def shape_len(shifts, private: bool, dims=PROFILE_DIMS) -> int:
    rows = rows_triple(shifts, private, dims)
    specs = mask_specs(private, dims)

    def opening(groups, n_rows, hiding):
        return ((groups + 1) * (512 if hiding else 256) * 16
                + CHECKS * (8 + n_rows * 8 + (32 if hiding else 0) + 11 * 32))

    arguments = sum((1 + rounds * (degree + 1) + terms) * 16
                    for (rounds, degree), terms in zip(specs, TERMINALS))
    masks = 2 * 1024 * 16 + CHECKS * (8 + 16 * 8 + 32 + 12 * 32)
    total = (HEADER + 3 * 44 + 32 + arguments + masks
             + opening(2, rows[0], private)
             + opening(5, rows[1], True)
             + opening(5, rows[2], True))
    if total > MAX_WIRE_BYTES:
        raise ValueError("fresh FFN wire: frame exceeds bound")
    return total


# ---------------------------------------------------------------------------
# Model 2: the payload writer, field by field.
# ---------------------------------------------------------------------------
def _sumcheck_bytes(rounds: int, degree: int) -> int:
    """SumcheckProof::write_bytes: rounds[j] has degree+1 Fp2 values."""
    return rounds * (degree + 1) * FP2_BYTES


def _commitment_bytes() -> int:
    """LayerProofZk::to_bytes `com`: root || rows:u64 || log_cols:u32."""
    return DIGEST_BYTES + 8 + 4


def _mask_opening_bytes(n_base: int) -> int:
    """MaskOpening::write_bytes (zk.rs:411)."""
    q = (1 << (MASK_LOG_MSG + 1)) * FP2_BYTES          # 1024 Fp2
    prox = (1 << (MASK_LOG_MSG + 1)) * FP2_BYTES       # 1024 Fp2
    per_col = (8 + n_base * FP_BYTES + DIGEST_BYTES
               + MASK_LOG_DOM * DIGEST_BYTES)
    return q + prox + MASK_Q * per_col


def _opening_bytes(groups, width, n_rows, depth, hiding) -> int:
    """Opening/OpeningZk::write_bytes (pcs.rs:116 / pcs.rs:582)."""
    vectors = (groups + 1) * width * FP2_BYTES         # group_vecs + prox_vec
    per_col = 8 + n_rows * FP_BYTES + (DIGEST_BYTES if hiding else 0) \
        + depth * DIGEST_BYTES
    return vectors + CHECKS * per_col


def writer_terms(shifts, private: bool, dims=PROFILE_DIMS) -> list:
    """The writer's emission, in ``LayerProofZk::to_bytes`` order."""
    w_rows, a_rows, h_rows = rows_triple(shifts, private, dims)
    specs = mask_specs(private, dims)
    n_cols = 1 << LOG_COLS                             # PcsParams::cols()
    pad = MASK_Q                                       # ZkOpts::q_pad
    depth = LOG_COLS + (INV_RATE.bit_length() - 1)     # log2(enc_cols) = 11
    n_base = 2 * len(specs) + 4                        # mask matrix base rows

    terms = [
        ("envelope", HEADER),
        ("w_com", _commitment_bytes()),
        ("a_com", _commitment_bytes()),
        ("mask_root", DIGEST_BYTES),
        ("h_com", _commitment_bytes()),
    ]
    names = ["gu", "d", "zc20", "zc17", "zs", "tab"]
    for name, (rounds, degree), terminals in zip(names, specs, TERMINALS):
        terms.append((f"{name}_claim", FP2_BYTES))
        terms.append((f"{name}_sc", _sumcheck_bytes(rounds, degree)))
        terms.append((f"{name}_term", terminals * FP2_BYTES))
    terms.append(("mask_open", _mask_opening_bytes(n_base)))
    if private:
        terms.append(("w_open", 0))                    # empty under P3
        terms.append(("w_open_zk",
                      _opening_bytes(2, n_cols + pad, w_rows, depth, True)))
    else:
        terms.append(("w_open",
                      _opening_bytes(2, n_cols, w_rows, depth, False)))
        terms.append(("w_open_zk", 0))                 # empty under P1
    terms.append(("a_open",
                  _opening_bytes(5, n_cols + pad, a_rows, depth, True)))
    terms.append(("h_open",
                  _opening_bytes(5, n_cols + pad, h_rows, depth, True)))
    terms.append(("pred", 0))                          # function 1: None
    return terms


@functools.lru_cache(maxsize=None)
def writer_len(shifts, private: bool, dims=PROFILE_DIMS) -> int:
    return sum(n for _, n in writer_terms(shifts, private, dims))


# ---------------------------------------------------------------------------
# Model 3: the decoder's cursor (Proof::from_bytes).
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def reader_len(shifts, private: bool, dims=PROFILE_DIMS) -> int:
    w_rows, a_rows, h_rows = rows_triple(shifts, private, dims)
    specs = mask_specs(private, dims)
    pos = 0

    def take(n):
        nonlocal pos
        pos += n

    def fp(n=1):
        take(n * FP_BYTES)

    def fp2(n=1):
        fp(n), fp(n)

    def fp2_vec(n):
        fp2(n)

    def commitment():
        take(DIGEST_BYTES)   # root
        take(8)              # rows:u64
        take(4)              # log_cols:u32

    def argument(rounds, degree, terms):
        fp2()
        for _ in range(rounds):
            fp2_vec(degree + 1)
        fp2_vec(terms)

    def column(n_rows, depth):
        take(8)              # j:u64, checked < 1 << depth
        fp(n_rows)

    def path(depth):
        take(depth * DIGEST_BYTES)

    def columns(n_rows, depth):
        for _ in range(CHECKS):
            column(n_rows, depth)
            take(DIGEST_BYTES)   # salt
            path(depth)

    def hiding(groups, n_rows):
        for _ in range(groups):
            fp2_vec(512)
        fp2_vec(512)
        columns(n_rows, 11)

    def plain(n_rows):
        for _ in range(2):
            fp2_vec(256)
        fp2_vec(256)
        for _ in range(CHECKS):
            column(n_rows, 11)
            path(11)

    take(8)                  # magic + version
    take(1)                  # weight mode
    take(32)                 # expectation digest
    commitment()             # w_com
    commitment()             # a_com
    take(DIGEST_BYTES)       # mask_root
    commitment()             # h_com
    for (rounds, degree), terms in zip(specs, TERMINALS):
        argument(rounds, degree, terms)
    fp2_vec(1024)            # mask q
    fp2_vec(1024)            # mask prox
    columns(16, 12)          # mask columns
    if private:
        hiding(2, w_rows)
    else:
        plain(w_rows)
    hiding(5, a_rows)
    hiding(5, h_rows)
    return pos


# ---------------------------------------------------------------------------
# Reporting helpers
# ---------------------------------------------------------------------------
def all_models(shifts, private: bool, dims=PROFILE_DIMS) -> dict:
    return {"shape_len": shape_len(shifts, private, dims),
            "writer_len": writer_len(shifts, private, dims),
            "reader_len": reader_len(shifts, private, dims)}


def sweep(dims=PROFILE_DIMS) -> dict:
    """Every allowed shift tuple, both weight modes: do the models agree?

    ``shape_len`` and ``writer_len`` are evaluated on all 25^4 tuples.
    ``reader_len`` is a function of the (W, A, H) row triple and the mode
    alone, so it is evaluated once per DISTINCT row triple -- which covers
    the same tuples exactly, at a fraction of the cost.
    """
    worst = {"P1": 0, "P3": 0}
    checked = 0
    seen = set()
    window = range(SHIFT_MIN, SHIFT_MAX + 1)
    for shifts in itertools.product(window, repeat=4):
        for private in (False, True):
            mode = "P3" if private else "P1"
            shape = shape_len(shifts, private, dims)
            writer = writer_len(shifts, private, dims)
            if shape != writer:
                raise AssertionError(
                    f"shape/writer disagree at {shifts} {mode}: "
                    f"{shape} vs {writer}")
            key = (rows_triple(shifts, private, dims), private)
            if key not in seen:
                seen.add(key)
                reader = reader_len(shifts, private, dims)
                if reader != shape:
                    raise AssertionError(
                        f"reader disagrees at {shifts} {mode}: "
                        f"{reader} vs {shape}")
            worst[mode] = max(worst[mode], shape)
            checked += 1
    return {"tuples_checked": checked, "distinct_row_shapes": len(seen),
            "max_frame": worst}


def report(dims=PROFILE_DIMS) -> dict:
    cases = {}
    for label, shifts in (("profile_7_0_14_6", (7, 0, 14, 6)),
                          ("maximum_16_16_16_16", (16, 16, 16, 16)),
                          ("minimum_m8_m8_m8_m8", (-8, -8, -8, -8))):
        zl = zk_layout(shifts, dims)
        cases[label] = {
            "shifts": list(shifts),
            "a_rows": zl["a_rows"], "h_rows": zl["h_rows"],
            "w_rows_p1": zl["w_rows_p1"], "w_rows_p3": zl["w_rows_p3"],
            "P1": all_models(shifts, False, dims),
            "P3": all_models(shifts, True, dims),
            "P1_terms": dict(writer_terms(shifts, False, dims)),
            "P3_terms": dict(writer_terms(shifts, True, dims)),
        }
    return {"profile": "ffn-v3-mr1-fresh-poc/1", "dims": list(dims),
            "cases": cases}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sweep", action="store_true",
                    help="check all 390625 shift tuples in both modes")
    args = ap.parse_args()
    out = report()
    if args.sweep:
        out["sweep"] = sweep()
    print(json.dumps(out, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
