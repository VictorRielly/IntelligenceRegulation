#!/usr/bin/env python3
"""[ZK60-CL10] Proof-artifact component profile, before any redesign.

WHAT THIS DOES. Given a layout that is actually declared (not inferred) and an
OBSERVED artifact byte count, it computes the components it can derive EXACTLY
from the source formulas and reports the rest as a labelled residual. Totals
reconcile to the observed artifact by construction; nothing is estimated.

WHAT IT REFUSES. An unknown layout name, an underspecified layout, or a model
whose derived components EXCEED the observed artifact — that last one means the
model has drifted from the source and every number would be wrong. It refuses
rather than guessing, per CL10's acceptance.

[ZK60-CL10 round-7 CORRECTION, Codex review 2026-09-06 — kept in place so the
mistake stays visible.] The first version of this model gave W the same row
count and the same salted-column framing in BOTH privacy modes. Wrong on two
counts, both plainly in the source:
  * under P1 the W commitment is PLAIN: `LayerProofZk.w_open: Opening`, with
    `LayoutV3.w_len / n` = 10,752 rows at Mistral; under P3 it is HIDING:
    `w_open_zk: OpeningZk`, with `ZkLayoutV3.w_len_p3 / n` = 10,774 rows (the
    10,752 data rows + one mask row per W block (21) + one proximity row);
  * `Opening` writes NO per-column salt; `OpeningZk` writes 32 B per column.
So 53,248 B of the observed 65,632 B P1->P3 delta are COLUMN bytes, and the
old claim that "the whole delta lands in the residual" was false. Three
changes follow. (1) W's row count is derived from a Python MIRROR of the
layout rule (`hashline_memory_plan.weight_shape`, itself tested against
`ZkLayoutV3::new`) and selected per mode; it is no longer a pasted constant.
(2) The framing is selected by the opening TYPE (`hiding`), not assumed.
(3) The group/proximity vectors and the mask opening — whose shapes the
serializers fix — are counted explicitly rather than left inside a residual
that was then mislabelled "arguments". What remains in the residual is named
as unknown, not measured.

SOURCE OF THE FORMULAS (read, not copied blindly):
  `Opening::size_bytes`,   hashline/src/pcs.rs:94-99      (plain: mode P1's W)
      sum over group vectors of len*16 + prox_vec.len()*16
      + sum over opened columns of (8 + rows*8 + path.len()*32)   -- NO salt
      group/prox vectors have n entries (pcs.rs:405-421)
  `OpeningZk::size_bytes`, hashline/src/pcs.rs:543-548  (hiding: A, H, P3's W)
      ... + sum over opened columns of (8 + rows*8 + 32 + path.len()*32)
      group/prox vectors have n + Q entries, n message + Q pads (pcs.rs:957-970)
  `MaskOpening::size_bytes`, hashline/src/zk.rs:501-503
      q.len()*16 + prox.len()*16          -- 2m = 1024 Fp2 each (zk.rs:605-642)
      + MASK_Q columns of (8 + (2*sumchecks + 4)*8 + 32 + MASK_LOG_DOM*32)
  `LayerProofZk::to_bytes`, hashline/src/zk.rs:903-928
      each commitment header = 32 root + 8 rows + 4 log_cols = 44 B, plus a
      32 B mask root; BOTH W openings are written, the unused one empty (0 B)
  `ZkLayoutV3::new`, hashline/src/zk.rs:2093-2145 — the W row rule, mirrored
      by scripts/hashline_memory_plan.py::weight_shape (tested there)
  `mask_specs_v3`, hashline/src/zk.rs:2210-2221 — P3 gives each of the two
      matmul sumchecks ONE extra degree-2 round; `SumcheckProof::size_bytes`
      (sumcheck.rs:23-25) writes degree+1 Fp2 per round, so 3*16 = 48 B each

NOT A SECURITY STATEMENT. Sizes are sizes. Nothing here says a smaller
alternative is compatible, hiding, or sound; those need their own codec and
security gates, and the report's candidates section says so for each one.

BYTES ARE NOT TIME. This tool partitions a byte count. It says nothing about
serialization, transfer or allocation TIME, and a size partition cannot show
that a serializer has no runtime headroom. Time belongs to CL5's collectors.

[ZK60-CL19, 2026-09-07] The residual above is no longer the end of the story.
Codex implemented `LayerProofZk::size_breakdown()` (round 10) and the prover
now prints one `HASHLINE_PROOF_SIZE {json}` row per layer under
`--phase-profile`. The second half of this file is the lane CONSUMER of that
row: `--schema`, `--validate-breakdown`, `--from-log [--reconcile FIXTURE|auto]`
and `--derive`. The layout mirror there also derives the sumcheck arguments
(from `mask_specs_v3` and the v3 verifier's terminal rules), so the four
archived per-layer sizes reproduce with NO residual, and Codex's actual rows
at the frozen 12x512 fixture agree with the derivation leaf by leaf on the
layers the dump describes. Review: ZK60_CLAUDE_ARTIFACTS.md §8.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from dataclasses import dataclass

FP2 = 16          # bytes per Fp2 element
FP = 8            # bytes per field element in an opened column
DIGEST = 32       # bytes per Merkle digest / salt / root
COL_INDEX = 8     # u64 column index written before each opened column
COMMIT_HEADER = 32 + 8 + 4  # root + rows(u64) + log_cols(u32)
MASK_ROOT = 32

# The mask commitment's fixed shape (zk.rs:466-468): 512 message positions per
# a-row, 4096 evaluation positions (Merkle path 12), 256 opened columns.
MASK_LOG_MSG = 9
MASK_LOG_DOM = 12
MASK_Q = 256


class ProfileError(ValueError):
    """Refused: unknown/underspecified layout, or a model that does not fit."""


# ---------------------------------------------------------------------------
# The W row rule, MIRRORED not pasted. `weight_shape` lives in the memory
# planner (same directory), where it is tested against the Rust layout; this
# tool imports it so that the two Python models cannot disagree about W.
# ---------------------------------------------------------------------------

_MEMORY_PLAN = None


def _memory_plan():
    global _MEMORY_PLAN
    if _MEMORY_PLAN is None:
        here = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(here, "hashline_memory_plan.py")
        spec = importlib.util.spec_from_file_location("hashline_memory_plan", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _MEMORY_PLAN = mod
    return _MEMORY_PLAN


def w_shape(d: int, f: int, log_cols: int, hiding: bool) -> dict:
    """W's committed rows for one mode, from the planner's mirror of
    `ZkLayoutV3::new`. Plain (mode P1): `LayoutV3.w_len / n`, the 3*d*f/n data
    rows. Hiding (mode P3): `ZkLayoutV3.w_len_p3 / n`, the data rows + one mask
    row per W block + one proximity row. A and H are NOT mirrored here: their
    rows are declared from the prover's own mask-site dump."""
    s = _memory_plan().weight_shape(d, f, log_cols)
    mask_rows = s["block_mask_rows"] + s["proximity_rows"]
    return {
        "rows": s["rows"] if hiding else s["data_rows"],
        "data_rows": s["data_rows"],
        "mask_rows": mask_rows if hiding else 0,
        "log_cols": s["log_cols"],
        "cols": 1 << s["log_cols"],
    }


def p3_extension_round_bytes(matmul_sumchecks: int = 2, degree: int = 2) -> int:
    """The one P3 cost this tool does NOT model as a component but can predict:
    `mask_specs_v3` adds one extension round to each matmul sumcheck under P3,
    and a round of a degree-d sumcheck is d+1 Fp2. Used by the cross-check as
    the EXPECTED residual delta between the two modes."""
    return matmul_sumchecks * (degree + 1) * FP2


@dataclass(frozen=True)
class CommitmentOpening:
    """One commitment's opened columns and clear vectors.

    `hiding` selects the serializer: True is `OpeningZk` (32 B salt per column,
    vectors of n + Q entries), False is `Opening` (no salt, vectors of n
    entries). `groups` is the number of column-weight groups the claims form
    (one clear vector each) — None means "not declared", and then the vectors
    are NOT counted: they stay in the residual and the profile says so."""

    role: str          # "W" | "A" | "H" | ...
    rows: int          # committed rows == entries per opened column
    columns: int       # opened columns == num_col_checks == Q pads per row
    path_len: int      # Merkle path length == log2(encoded columns)
    hiding: bool       # OpeningZk (salted) vs Opening (plain)
    cols: int          # message width n == 2^log_cols == clear-vector length under Opening
    groups: int | None = None   # column-weight groups (clear vectors); None = unknown
    prox_vectors: int = 1       # one proximity vector per opening

    def salt_bytes(self) -> int:
        """32 B per opened column under `OpeningZk`; nothing under `Opening`."""
        return self.columns * DIGEST if self.hiding else 0

    def framing_bytes(self) -> int:
        """Per-column index + Merkle path, plus the salt where the type has one."""
        return self.columns * (COL_INDEX + self.path_len * DIGEST) + self.salt_bytes()

    def data_only_bytes(self) -> int:
        """Just the field elements — the mathematically irreducible part."""
        return self.columns * self.rows * FP

    def column_bytes(self) -> int:
        """The dominant term: opened column DATA plus its per-column framing."""
        return self.data_only_bytes() + self.framing_bytes()

    def vector_len(self) -> int:
        """n message entries, plus Q pad entries under the hiding opening
        (`q_pad = num_col_checks`, pcs.rs `ZkOpts::standard`)."""
        return self.cols + (self.columns if self.hiding else 0)

    @property
    def vectors_known(self) -> bool:
        return self.groups is not None

    def vector_bytes(self) -> int:
        """The clear group vectors and the proximity vector, Fp2 each entry.
        Zero when the group count is undeclared — then they are in the residual."""
        if self.groups is None:
            return 0
        return (self.groups + self.prox_vectors) * self.vector_len() * FP2


@dataclass(frozen=True)
class MaskOpeningShape:
    """`MaskOpening` (zk.rs:494-513): q' and the proximity combination, 2m Fp2
    each, then MASK_Q salted columns of the (2*sumchecks + 4)-row mask
    commitment on a 2^MASK_LOG_DOM coset. Mode-independent: P3 lengthens two
    masks' coefficient lists, but each still fits its fixed 512-entry row."""

    sumchecks: int     # `mask_specs_v3` entries: 6 under function 1, 7 with a predicate
    checks: int = MASK_Q
    log_msg: int = MASK_LOG_MSG
    log_dom: int = MASK_LOG_DOM

    def rows(self) -> int:
        return 2 * self.sumchecks + 4

    def vector_bytes(self) -> int:
        return 2 * (2 << self.log_msg) * FP2

    def column_bytes(self) -> int:
        return self.checks * (COL_INDEX + self.rows() * FP + DIGEST + self.log_dom * DIGEST)

    def total_bytes(self) -> int:
        return self.vector_bytes() + self.column_bytes()


@dataclass
class Layout:
    name: str
    mode: str
    commitments: tuple[CommitmentOpening, ...]
    commitment_headers: int  # how many 44-byte headers the layer writes
    mask_roots: int = 1
    mask_opening: MaskOpeningShape | None = None  # None = not modelled -> residual

    def residual_contents(self) -> list[str]:
        """What the residual HOLDS, so it is never mistaken for a measurement of
        any one of them. Always the sumcheck rounds, claims and terminals; plus
        whatever this layout left undeclared."""
        parts = ["sumcheck rounds", "claims and gammas", "masked terminals", "any predicate block"]
        unknown_vecs = [c.role for c in self.commitments if not c.vectors_known]
        if unknown_vecs:
            parts.append(f"group/proximity vectors of {'/'.join(unknown_vecs)} (shape undeclared)")
        if self.mask_opening is None:
            parts.append("the mask opening (shape undeclared)")
        return parts

    def derived(self) -> dict:
        data = sum(c.data_only_bytes() for c in self.commitments)
        salts = sum(c.salt_bytes() for c in self.commitments)
        framing = sum(c.framing_bytes() for c in self.commitments)
        cols = sum(c.column_bytes() for c in self.commitments)
        vectors = sum(c.vector_bytes() for c in self.commitments)
        mask = self.mask_opening.total_bytes() if self.mask_opening else 0
        headers = self.commitment_headers * COMMIT_HEADER + self.mask_roots * MASK_ROOT
        return {
            "opened_column_data_bytes": data,
            "opened_column_salt_bytes": salts,            # a subset of framing, shown apart
            "opened_column_framing_bytes": framing,       # index + salt (if any) + path
            "opened_columns_total_bytes": cols,
            "group_and_proximity_vector_bytes": vectors,
            "vectors_counted_for": [c.role for c in self.commitments if c.vectors_known],
            "mask_opening_bytes": mask,
            "mask_opening_counted": self.mask_opening is not None,
            "commitment_header_bytes": headers,
            "derived_total_bytes": cols + vectors + mask + headers,
        }


def profile(layout: Layout, observed_bytes: int) -> dict:
    if observed_bytes <= 0:
        raise ProfileError("observed artifact size must be positive and MEASURED")
    for c in layout.commitments:
        if c.rows <= 0 or c.columns <= 0 or c.path_len <= 0 or c.cols <= 0:
            raise ProfileError(
                f"{layout.name}/{c.role}: rows, columns, path_len and cols must all be declared "
                f"(got rows={c.rows}, columns={c.columns}, path_len={c.path_len}, cols={c.cols}). "
                f"An undeclared dimension is refused, not defaulted."
            )
    d = layout.derived()
    derived = d["derived_total_bytes"]
    if derived > observed_bytes:
        raise ProfileError(
            f"{layout.name}: derived components ({derived} B) EXCEED the observed artifact "
            f"({observed_bytes} B) by {derived - observed_bytes} B. The model has drifted "
            f"from the source; refusing to report a breakdown that cannot be true."
        )
    residual = observed_bytes - derived
    contents = layout.residual_contents()
    out = {
        "schema": 2,
        "layout": layout.name,
        "mode": layout.mode,
        "measured_artifact_bytes": observed_bytes,
        "components": d,
        "residual_bytes": residual,
        "residual_contents": contents,
        "residual_note": (
            "UNKNOWN residual: " + ", ".join(contents) + ". Obtained by subtraction "
            "from the observed artifact so the profile reconciles exactly; it is NOT a "
            "measurement of any one of those parts and its internal split is not claimed."
        ),
        "reconciles_exactly": derived + residual == observed_bytes,
        "shares": {
            "opened_column_data": d["opened_column_data_bytes"] / observed_bytes,
            "opened_column_framing": d["opened_column_framing_bytes"] / observed_bytes,
            "group_and_proximity_vectors": d["group_and_proximity_vector_bytes"] / observed_bytes,
            "mask_opening": d["mask_opening_bytes"] / observed_bytes,
            "commitment_headers": d["commitment_header_bytes"] / observed_bytes,
            "unknown_residual": residual / observed_bytes,
        },
        "bytes_not_time": (
            "a size partition; says nothing about serialization, transfer or "
            "allocation time"
        ),
    }
    return out


def mode_delta(plain: dict, hiding: dict) -> dict:
    """[ZK60-CL10 round 7] The cross-check that CAN fail. Component by
    component, the hiding profile minus the plain one; the two observed sizes
    are subtracted separately so their difference is a MEASUREMENT the
    modelled deltas are compared against. Under the old model (same W rows,
    same salt in both modes) every column delta here is 0 and the whole
    observed delta is pushed into the residual — which is exactly the
    misallocation this function exposes."""
    p, h = plain["components"], hiding["components"]
    keys = ("opened_column_data_bytes", "opened_column_salt_bytes", "opened_column_framing_bytes",
            "opened_columns_total_bytes", "group_and_proximity_vector_bytes", "mask_opening_bytes",
            "commitment_header_bytes", "derived_total_bytes")
    d = {k: h[k] - p[k] for k in keys}
    d["observed_delta_bytes"] = hiding["measured_artifact_bytes"] - plain["measured_artifact_bytes"]
    d["residual_delta_bytes"] = hiding["residual_bytes"] - plain["residual_bytes"]
    d["explained_delta_bytes"] = d["derived_total_bytes"]
    return d


# ---------------------------------------------------------------------------
# Declared layouts. A layout must be DECLARED to be profiled; there is no
# inference from a file, because a wrong inference produces a plausible and
# entirely fictional breakdown.
# ---------------------------------------------------------------------------

# One Mistral FFN layer as lane AM ran it (am_r2_mistral.log): d 4096 / f 14336,
# T=512, `--zk` v3 with log_cols 14, inv_rate 4, 256 column checks; function 1
# (no predicate), so `mask_specs_v3` has six entries.
MISTRAL = {"d": 4096, "f": 14336, "log_cols": 14, "inv_rate": 4, "checks": 256, "sumchecks": 6}

# A and H rows are DECLARED from the prover's mask-site dump ("A 3601 rows =
# 3520 data + 61 masks + 20 table/mask rows; H 3033 rows = ..."), identical
# in both modes (A and H are hiding under P1 and P3 alike). Their group
# counts are the "A/H group vector 0..4" lines of the same dump.
MISTRAL_AH_ROWS = {"A": 3601, "H": 3033}
MISTRAL_AH_GROUPS = {"A": 5, "H": 5}
# W forms two column-weight groups in either mode: every Wg/Wu block claim is
# at the one point p3, every Wd block claim at p6, and `group_claims` /
# `group_zclaims` key on the point's column part (pcs.rs:237-252). The P3 dump
# prints them as "W group vector 0/1"; under P1 the plain opening has the same
# two, n long instead of n+Q.
MISTRAL_W_GROUPS = 2


def mistral_v3_layer(mode: str) -> Layout:
    """One Mistral FFN layer, per privacy mode.

    [round-7 correction] W is PLAIN under P1 (`Opening`, 10,752 rows, no salt)
    and HIDING under P3 (`OpeningZk`, 10,774 rows, 32 B salt per column); the
    rows come from `w_shape`, the planner's mirror of `ZkLayoutV3::new`, and
    are no longer a constant typed here. Encoded columns 65,536 -> path 16.
    """
    if mode not in ("P1", "P3"):
        raise ProfileError(f"unknown mode {mode!r}: declare P1 or P3")
    w_hiding = mode == "P3"
    m = MISTRAL
    ws = w_shape(m["d"], m["f"], m["log_cols"], hiding=w_hiding)
    path_len = ws["log_cols"] + (m["inv_rate"].bit_length() - 1)  # log2(n * inv_rate)
    coms = [CommitmentOpening(role="W", rows=ws["rows"], columns=m["checks"], path_len=path_len,
                              hiding=w_hiding, cols=ws["cols"], groups=MISTRAL_W_GROUPS)]
    for r in ("A", "H"):
        coms.append(CommitmentOpening(role=r, rows=MISTRAL_AH_ROWS[r], columns=m["checks"],
                                      path_len=path_len, hiding=True, cols=ws["cols"],
                                      groups=MISTRAL_AH_GROUPS[r]))
    return Layout(name=f"mistral-v3-layer-{mode}", mode=mode, commitments=tuple(coms),
                  commitment_headers=3, mask_opening=MaskOpeningShape(sumchecks=m["sumchecks"]))


KNOWN_LAYOUTS = {"mistral-v3-layer-P1": lambda: mistral_v3_layer("P1"),
                 "mistral-v3-layer-P3": lambda: mistral_v3_layer("P3")}


def get_layout(name: str) -> Layout:
    if name not in KNOWN_LAYOUTS:
        raise ProfileError(
            f"unknown layout {name!r}. Known: {sorted(KNOWN_LAYOUTS)}. "
            f"Legacy or undocumented layouts are REFUSED rather than guessed — "
            f"profiling one requires reading its serializer and declaring it here."
        )
    return KNOWN_LAYOUTS[name]()



# ===========================================================================
# [ZK60-CL19] The CONSUMER side of Codex's proof-size telemetry.
#
# Codex implemented the producer in round 10 (`ZK60_ROUND10.md`):
# `LayerProofZk::size_breakdown()` in `hashline/src/zk_proof_size.rs` counts
# the serialized length of every field of the proof OBJECT — no second byte
# buffer, no residual, values never read — and `pass --zk --profile v3
# --phase-profile` prints one
#     HASHLINE_PROOF_SIZE {json}
# row per actual layer, after HASHLINE_TIMING and `wcache::report()`. Those
# files were read UNCOMMITTED from the main checkout at 52a13d1's tree on
# 2026-09-07 (12:25 PDT); every key below is copied from
# `ProofSizeBreakdown::to_json()` and the CLI's format string, and a test
# checks the names against that module when it is mounted. This tool does NOT
# re-implement the counter. It (1) prints the schema, (2) validates a row —
# refusing anything that does not partition its own total — (3) extracts the
# rows from a prover log and pins them to the log's own `layer N: ... B` and
# `PROOF sha256 ... (N B)` lines, and (4) DERIVES the same object from the
# CL10 layout mirror (now extended to the sumcheck arguments), so a measured
# row and the derivation are compared leaf by leaf.
#
# The categories are byte CATEGORIES, not wire offsets: inside an opening the
# index, values, salt and path of one column are written before the next
# column's (pcs.rs `write_bytes`), so `salts` is not a contiguous interval. A
# partition test (leaves sum exactly to `total_bytes`, and per Codex's Rust
# tests each category to its own writer's output) replaces an interval cover.
#
# Status: producer implemented by Codex, in validation (round 10, uncommitted);
# lane consumer ready (this file); reconciliation PENDING actual rows at the
# frozen 12x512 zkv3 fixture. No archived log in `results/` carries a row yet
# (they predate the CLI change), and `--from-log` says so rather than guessing.
# ===========================================================================

import re

PROOF_SIZE_TAG = "HASHLINE_PROOF_SIZE"
PROOF_SIZE_ROW = re.compile(r"^HASHLINE_PROOF_SIZE (\{.*\})\s*$")
TIMING_ROW = re.compile(r"^HASHLINE_TIMING (\{.*\})\s*$")
LAYER_LINE = re.compile(r"^\s*layer\s+(\d+): prove \S+ s, (\d+) B\s*$")
PROOF_LINE = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)")

# The row's outer object (hashline.rs, `pass_zk_v3`, after `wcache::report()`;
# only under `--phase-profile`). `privacy` is the CLI's mode (`o.zk.p3()`),
# NOT read from the proof — which is why the validator cross-checks it against
# the row's own W fields. `pass_verified` is `o.verify && ok`.
ROW_KEYS = ("schema", "unit", "coverage", "profile", "privacy", "layer", "serialized", "pass_verified", "sizes")
ROW_FIXED = {"schema": 1, "unit": "bytes", "coverage": "ffn-only", "profile": "v3"}
PRIVACY_MODES = ("P1", "P3")

# `ProofSizeBreakdown::to_json()` — key order as emitted.
SIZES_KEYS = ("total_bytes", "commitment_headers", "mask_root", "arguments", "mask_opening",
              "w_plain", "w_hiding", "a", "h", "predicate")
ARGUMENT_NAMES = ("gu", "d", "zc20", "zc17", "zs", "table")      # `size_breakdown()`, in order
ARGUMENT_KEYS = ("name", "claim_or_challenge", "round_evaluations", "terminals")
OPENING_KEYS = ("group_vectors", "proximity_vector", "columns")   # OpeningBytes::json
MASK_KEYS = ("functional_vector", "proximity_vector", "columns")  # MaskOpeningBytes::json
COLUMN_KEYS = ("indices", "values", "salts", "authentication_paths")  # ColumnBytes::json
PREDICATE_NAME = "predicate"
# Fixed by the serializer, so a row that disagrees is a schema drift, not a measurement.
FIXED_LEAVES = {"commitment_headers": 3 * COMMIT_HEADER, "mask_root": MASK_ROOT}  # 132, 32
CLAIM_BYTES = FP2  # one Fp2 claim or gamma per argument (`ArgumentBytes::count`)

OWNER_PRODUCER = "Codex — hashline/src/zk_proof_size.rs (+ the CLI row in hashline/src/bin/hashline.rs); uncommitted at 52a13d1's tree, read 2026-09-07"
OWNER_CONSUMER = "lane — scripts/hashline_cl_artifact_profile.py (this tool); consumes, never re-implements"


def schema() -> dict:
    """The proposed-then-implemented section list, verbatim from Codex's
    `to_json()`, with what supplies each leaf and where it applies."""
    def col(prefix, struct, salted):
        return [
            {"path": f"{prefix}.columns.indices", "meaning": "one u64 column index per opened column",
             "supplied_by": f"{struct}.columns.len() * 8", "modes": salted_modes(prefix)},
            {"path": f"{prefix}.columns.values", "meaning": "the opened columns' base-field entries (committed rows x 8 B each)",
             "supplied_by": f"sum over {struct}.columns of col.len() * 8", "modes": salted_modes(prefix)},
            {"path": f"{prefix}.columns.salts", "meaning": "32 B leaf salt per opened column — the HIDING construction, present only where the opening type carries one" if salted else "always 0: `Opening` (plain) writes no salt; the leaf exists so the two W variants share one shape",
             "supplied_by": f"{struct}.columns.len() * 32" if salted else "constant 0 (`OpeningBytes::plain`)", "modes": salted_modes(prefix)},
            {"path": f"{prefix}.columns.authentication_paths", "meaning": "Merkle path digests, 32 B each, path.len() = log2(encoded columns)",
             "supplied_by": f"sum over {struct}.columns of path.len() * 32", "modes": salted_modes(prefix)},
        ]

    def salted_modes(prefix):
        return {"w_plain": "P1 only (0 B under P3: `w_open` is empty)",
                "w_hiding": "P3 only (0 B under P1: `w_open_zk` is empty)"}.get(prefix, "P1 and P3")

    def opening(prefix, struct, salted):
        return [
            {"path": f"{prefix}.group_vectors", "meaning": "clear row-combination per column-weight group, Fp2 entries (n under `Opening`, n + Q under `OpeningZk`)",
             "supplied_by": f"sum over {struct}.group_vecs of v.len() * 16", "modes": salted_modes(prefix)},
            {"path": f"{prefix}.proximity_vector", "meaning": "the proximity combination, Fp2 entries",
             "supplied_by": f"{struct}.prox_vec.len() * 16", "modes": salted_modes(prefix)},
        ] + col(prefix, struct, salted)

    leaves = [
        {"path": "commitment_headers", "meaning": "3 x (32 B root + u64 rows + u32 log_cols) for W, A, H", "fixed": 132,
         "supplied_by": "constant 3 * (32 + 8 + 4) — the `com` closure in `LayerProofZk::to_bytes` (zk.rs:905-913)", "modes": "P1 and P3"},
        {"path": "mask_root", "meaning": "the mask commitment's Merkle root", "fixed": 32,
         "supplied_by": "constant 32 (`LayerProofZk.mask_root: Digest`)", "modes": "P1 and P3"},
    ]
    arg_fields = {"gu": ("gu_claim", "gu_sc", "gu_term"), "d": ("d_claim", "d_sc", "d_term"),
                  "zc20": ("gamma20", "zc20_sc", "zc20_term"), "zc17": ("gamma17", "zc17_sc", "zc17_term"),
                  "zs": ("gamma_zs", "zs_sc", "zs_term (one Fp2)"), "table": ("gamma_tab", "tab_sc", "tab_term")}
    for name in ARGUMENT_NAMES:
        c, s, t = arg_fields[name]
        leaves += [
            {"path": f"arguments.{name}.claim_or_challenge", "meaning": f"the argument's claim or gamma: `{c}`, one Fp2", "fixed": 16,
             "supplied_by": "constant 16 (`ArgumentBytes::count`)", "modes": "P1 and P3"},
            {"path": f"arguments.{name}.round_evaluations", "meaning": f"sumcheck round polynomials, degree+1 Fp2 per round (`{s}`); P3 adds ONE round to gu and d (`mask_specs_v3`)",
             "supplied_by": f"sum over {s}.rounds of r.len() * 16", "modes": "P1 and P3 (gu/d round counts differ by one)"},
            {"path": f"arguments.{name}.terminals", "meaning": f"masked terminal values `{t}`, Fp2 each; lengths fixed by the v3 verifier from nb_d/nb_f",
             "supplied_by": f"{t}.len() * 16", "modes": "P1 and P3"},
        ]
    leaves += [
        {"path": "mask_opening.functional_vector", "meaning": "q' — the clear degree<1024 polynomial of the mask functional (NOT a PCS group vector)",
         "supplied_by": "MaskOpening.q.len() * 16", "modes": "P1 and P3"},
        {"path": "mask_opening.proximity_vector", "meaning": "the mask commitment's proximity combination",
         "supplied_by": "MaskOpening.prox.len() * 16", "modes": "P1 and P3"},
    ] + col("mask_opening", "MaskOpening", salted=True)
    leaves += opening("w_plain", "w_open: Opening", salted=False)
    leaves += opening("w_hiding", "w_open_zk: OpeningZk", salted=True)
    leaves += opening("a", "a_open: OpeningZk", salted=True)
    leaves += opening("h", "h_open: OpeningZk", salted=True)
    leaves += [
        {"path": "predicate", "meaning": "function 2 only: `pred: Option<PredProofV3>` as one more argument object named \"predicate\" (gamma, sumcheck rounds, terminals); JSON null under function 1",
         "supplied_by": "ArgumentBytes::count(\"predicate\", &p.sc, p.term.len()) or null", "modes": "function 2 only; null (0 B) under function 1"},
    ]
    return {
        "schema": 1,
        "row": f"{PROOF_SIZE_TAG} " + json.dumps({k: ROW_FIXED.get(k, "<" + k + ">") for k in ROW_KEYS}),
        "row_fields": {
            "schema": "1", "unit": "bytes", "coverage": "ffn-only", "profile": "v3",
            "privacy": "P1|P3 — the CLI's mode (`o.zk.p3()`), not read from the proof; cross-checked here against w_plain/w_hiding",
            "layer": "the statement's layer index (`st.l`); one row per ACTUAL layer, never layer 0 projected",
            "serialized": "true — the counts are the lengths `to_bytes` writes",
            "pass_verified": "`o.verify && ok`; false under --no-verify or REJECT — such a row is retained as a diagnostic and is never rankable",
            "sizes": "`ProofSizeBreakdown::to_json()`: total_bytes plus the leaves below",
        },
        "sizes_total": {"path": "total_bytes", "meaning": "`ProofSizeBreakdown::total_bytes()`; MUST equal the sum of every leaf and `to_bytes().len()`"},
        "leaves": leaves,
        "not_contiguous": "categories are byte categories, not wire offsets: per column the index, values, salt and path interleave",
        "owner_producer": OWNER_PRODUCER,
        "owner_consumer": OWNER_CONSUMER,
        "status": "producer implemented by Codex, in validation (round 10, uncommitted); lane consumer ready; reconciliation pending actual rows",
        "bytes_not_time": "byte counts only; serialization/transfer/allocation time is a separate measurement (serialize_s), not derivable from these",
    }


def schema_paths() -> list[str]:
    return [leaf["path"] for leaf in schema()["leaves"]]


class BreakdownError(ValueError):
    """Refused: the row does not partition its own total, names a category
    twice or one the schema does not have, contradicts its privacy mode, or
    does not describe serialized bytes."""


def _no_duplicate_keys(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise BreakdownError(f"duplicate key {k!r}: a category assigned twice is refused")
        out[k] = v
    return out


def loads_strict(text: str):
    """`json.loads` that REFUSES duplicate keys instead of keeping the last."""
    try:
        return json.loads(text, object_pairs_hook=_no_duplicate_keys)
    except json.JSONDecodeError as e:
        raise BreakdownError(f"not JSON: {e}") from None


def _nonneg_int(x, path):
    if isinstance(x, bool) or not isinstance(x, int) or x < 0:
        raise BreakdownError(f"{path}: expected a non-negative integer byte count, got {x!r}")
    return x


def _exact_keys(obj, want, path, optional=()):
    if not isinstance(obj, dict):
        raise BreakdownError(f"{path}: expected an object, got {type(obj).__name__}")
    unknown = sorted(set(obj) - set(want) - set(optional))
    missing = sorted(set(want) - set(obj))
    if unknown:
        raise BreakdownError(f"{path}: unknown key(s) {unknown} — not in schema 1's to_json(); refused rather than ignored")
    if missing:
        raise BreakdownError(f"{path}: missing key(s) {missing} — an omitted section is refused")


def _optional_total(obj, total, path):
    """Schema 1 carries NO nested totals (only the top-level `total_bytes`);
    this tool derives them. If a later schema emits one it must agree with
    its own leaves."""
    if "total_bytes" in obj and obj["total_bytes"] != total:
        raise BreakdownError(f"{path}.total_bytes={obj['total_bytes']} disagrees with its leaves' sum {total}")


def _columns(obj, path, salted):
    _exact_keys(obj, COLUMN_KEYS, path, optional=("total_bytes",))
    leaves = {k: _nonneg_int(obj[k], f"{path}.{k}") for k in COLUMN_KEYS}
    if leaves["indices"] % COL_INDEX:
        raise BreakdownError(f"{path}.indices={leaves['indices']} is not a multiple of 8 (one u64 per opened column)")
    ncols = leaves["indices"] // COL_INDEX
    want = ncols * DIGEST if salted else 0
    if leaves["salts"] != want:
        how = f"{ncols} opened columns x 32 B" if salted else "a plain `Opening` writes no salt"
        raise BreakdownError(f"{path}.salts={leaves['salts']} but {how} gives {want}")
    total = sum(leaves.values())
    _optional_total(obj, total, path)
    return leaves, total, ncols


def _opening(obj, path, keys, salted):
    _exact_keys(obj, keys, path, optional=("total_bytes",))
    vec = {k: _nonneg_int(obj[k], f"{path}.{k}") for k in keys if k != "columns"}
    cols, col_total, ncols = _columns(obj["columns"], f"{path}.columns", salted)
    total = sum(vec.values()) + col_total
    _optional_total(obj, total, path)
    return {"leaves": {**vec, "columns": cols}, "total_bytes": total, "opened_columns": ncols}


def _argument(obj, path, want_name):
    _exact_keys(obj, ARGUMENT_KEYS, path, optional=("total_bytes",))
    if obj["name"] != want_name:
        raise BreakdownError(f"{path}.name={obj['name']!r}, expected {want_name!r}")
    leaves = {k: _nonneg_int(obj[k], f"{path}.{k}") for k in ARGUMENT_KEYS if k != "name"}
    if leaves["claim_or_challenge"] != CLAIM_BYTES:
        raise BreakdownError(f"{path}.claim_or_challenge={leaves['claim_or_challenge']}: one Fp2 claim/gamma is {CLAIM_BYTES} B, fixed by `ArgumentBytes::count`")
    total = sum(leaves.values())
    _optional_total(obj, total, path)
    return {"name": want_name, "leaves": leaves, "total_bytes": total}


def _arguments(arr, path):
    if not isinstance(arr, list):
        raise BreakdownError(f"{path}: expected a list of {len(ARGUMENT_NAMES)} argument objects")
    names = [a.get("name") if isinstance(a, dict) else None for a in arr]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise BreakdownError(f"{path}: duplicate argument name(s) {dup} — an argument counted twice is refused")
    unknown = sorted(set(names) - set(ARGUMENT_NAMES), key=str)
    if unknown:
        raise BreakdownError(f"{path}: unknown argument name(s) {unknown}; schema 1 has exactly {list(ARGUMENT_NAMES)}")
    missing = [n for n in ARGUMENT_NAMES if n not in names]
    if missing:
        raise BreakdownError(f"{path}: missing argument(s) {missing} — an omitted argument is refused")
    if tuple(names) != ARGUMENT_NAMES:
        raise BreakdownError(f"{path}: arguments out of order {names}; `size_breakdown()` emits {list(ARGUMENT_NAMES)}")
    return [_argument(a, f"{path}[{i}:{n}]", n) for i, (a, n) in enumerate(zip(arr, names))]


def validate_sizes(sizes, privacy: str) -> dict:
    """Validate the `sizes` object against schema 1 and the privacy mode the
    row claims. Returns derived category totals; raises BreakdownError."""
    _exact_keys(sizes, SIZES_KEYS, "sizes")
    total = _nonneg_int(sizes["total_bytes"], "sizes.total_bytes")
    for k, want in FIXED_LEAVES.items():
        got = _nonneg_int(sizes[k], f"sizes.{k}")
        if got != want:
            raise BreakdownError(f"sizes.{k}={got}: the serializer writes exactly {want} B (`LayerProofZk::to_bytes`)")
    args = _arguments(sizes["arguments"], "sizes.arguments")
    mask = _opening(sizes["mask_opening"], "sizes.mask_opening", MASK_KEYS, salted=True)
    w_plain = _opening(sizes["w_plain"], "sizes.w_plain", OPENING_KEYS, salted=False)
    w_hiding = _opening(sizes["w_hiding"], "sizes.w_hiding", OPENING_KEYS, salted=True)
    a = _opening(sizes["a"], "sizes.a", OPENING_KEYS, salted=True)
    h = _opening(sizes["h"], "sizes.h", OPENING_KEYS, salted=True)
    pred = sizes["predicate"]
    pred_total = 0
    if pred is not None:
        pred_total = _argument(pred, "sizes.predicate", PREDICATE_NAME)["total_bytes"]
    # The privacy cross-check: `privacy` is the CLI's mode, the W fields are the proof's.
    if privacy == "P1":
        if w_hiding["total_bytes"]:
            raise BreakdownError(
                f"P1 row carries w_hiding bytes ({w_hiding['total_bytes']} B, {w_hiding['leaves']['columns']['salts']} B of salts): "
                f"under P1 `w_open_zk` is empty and writes 0 B, so a P1 breakdown with hiding-W salts or columns is refused")
        if not w_plain["total_bytes"]:
            raise BreakdownError("P1 row has an empty w_plain: the plain `w_open` carries W's opening under P1")
    else:
        if w_plain["total_bytes"]:
            raise BreakdownError(f"P3 row carries w_plain bytes ({w_plain['total_bytes']} B): under P3 `w_open` is empty and writes 0 B")
        if not w_hiding["total_bytes"] or not w_hiding["leaves"]["columns"]["salts"]:
            raise BreakdownError("P3 row has no salted hiding-W opening: `w_open_zk` carries W's opening under P3, 32 B salt per opened column")
    leaf_sum = (FIXED_LEAVES["commitment_headers"] + FIXED_LEAVES["mask_root"] + sum(x["total_bytes"] for x in args)
                + mask["total_bytes"] + w_plain["total_bytes"] + w_hiding["total_bytes"] + a["total_bytes"] + h["total_bytes"] + pred_total)
    if leaf_sum != total:
        raise BreakdownError(
            f"sizes.total_bytes={total} but the leaves sum to {leaf_sum} ({leaf_sum - total:+d} B): "
            f"the row does not partition its own total; a section is missing, counted twice or mis-sized")
    return {
        "total_bytes": total,
        "leaf_sum_bytes": leaf_sum,
        "category_totals": {
            "commitment_headers": FIXED_LEAVES["commitment_headers"], "mask_root": FIXED_LEAVES["mask_root"],
            "arguments": {**{x["name"]: x["total_bytes"] for x in args}, "all": sum(x["total_bytes"] for x in args)},
            "mask_opening": mask["total_bytes"], "w_plain": w_plain["total_bytes"], "w_hiding": w_hiding["total_bytes"],
            "a": a["total_bytes"], "h": h["total_bytes"], "predicate": pred_total,
        },
        "opened_columns": {k: v["opened_columns"] for k, v in (("mask_opening", mask), ("w_plain", w_plain), ("w_hiding", w_hiding), ("a", a), ("h", h))},
        "salt_bytes": {k: v["leaves"]["columns"]["salts"] for k, v in (("mask_opening", mask), ("w_plain", w_plain), ("w_hiding", w_hiding), ("a", a), ("h", h))},
        "argument_round_evaluations": {x["name"]: x["leaves"]["round_evaluations"] for x in args},
    }


def validate_row(row) -> dict:
    """Validate one HASHLINE_PROOF_SIZE row (the parsed JSON object)."""
    _exact_keys(row, ROW_KEYS, "row")
    for k, want in ROW_FIXED.items():
        if row[k] != want:
            raise BreakdownError(f"row.{k}={row[k]!r}: this consumer reads schema 1 rows with {k}={want!r}")
    privacy = row["privacy"]
    if privacy not in PRIVACY_MODES:
        raise BreakdownError(f"row.privacy={privacy!r}: expected one of {list(PRIVACY_MODES)}")
    layer = _nonneg_int(row["layer"], "row.layer")
    if row["serialized"] is not True:
        raise BreakdownError(f"row.serialized={row['serialized']!r}: only rows describing SERIALIZED bytes are accepted")
    pv = row["pass_verified"]
    if not isinstance(pv, bool):
        raise BreakdownError(f"row.pass_verified={pv!r}: must be an explicit boolean (`o.verify && ok`)")
    s = validate_sizes(row["sizes"], privacy)
    return {
        "schema": 1, "layer": layer, "privacy": privacy, "serialized": True,
        "pass_verified": pv, "rankable": pv,
        "status": "verified: rankable" if pv else "pass_verified=false (--no-verify or REJECT): retained as a diagnostic, never rankable",
        **s,
        "checks": ["exact key sets (no unknown, none missing, no duplicates)", "fixed leaves 132/32/16", "argument names exact and ordered",
                   "salts = opened columns x 32 for every salted opening; 0 for w_plain", f"{privacy} W variant consistency", "leaves sum exactly to total_bytes"],
        "bytes_not_time": "byte counts only; says nothing about serialization, transfer or allocation time",
    }


def flatten_sizes(sizes) -> dict:
    """`sizes` -> {leaf path: bytes}, paths as `schema_paths()` lists them.
    `predicate` flattens to its total (0 for null) under the single path."""
    out = {"commitment_headers": sizes["commitment_headers"], "mask_root": sizes["mask_root"]}
    for a in sizes["arguments"]:
        for k in ARGUMENT_KEYS[1:]:
            out[f"arguments.{a['name']}.{k}"] = a[k]
    for prefix, keys in (("mask_opening", MASK_KEYS), ("w_plain", OPENING_KEYS), ("w_hiding", OPENING_KEYS), ("a", OPENING_KEYS), ("h", OPENING_KEYS)):
        for k in keys:
            if k == "columns":
                for c in COLUMN_KEYS:
                    out[f"{prefix}.columns.{c}"] = sizes[prefix]["columns"][c]
            else:
                out[f"{prefix}.{k}"] = sizes[prefix][k]
    p = sizes["predicate"]
    out["predicate"] = 0 if p is None else sum(p[k] for k in ARGUMENT_KEYS[1:])
    return out


# ---------------------------------------------------------------------------
# The DERIVATION: the CL10 layout mirror, extended to the sumcheck arguments,
# emitting an object shaped exactly like `to_json()`. Rules, each read from
# the source (not pasted numbers):
#   LayoutV3::new    (layer.rs:1284-1290)  log_t = log2 T; log_db = min(tz d, 12);
#                    log_fb = min(tz f, 12); nb_d = d >> log_db; nb_f = f >> log_fb;
#                    log_wb = log_db + log_fb; log_a_min = log_t + min(log_db, log_fb)
#   ZkLayoutV3::new  (zk.rs:2093-2098, 2136-2143)  log_n = min(log_cols, log_a_min);
#                    log_s = max(log_n, 16); log_wn = min(log_cols, log_wb); W rows per mode
#   mask_specs_v3    (zk.rs:2210-2221)  (vars, degree) per sumcheck; P3 adds one
#                    round to gu and d
#   verify_layer_zk_v3 terminal lengths (zk.rs:3549-3669): gu nb_d + 2 nb_d nb_f;
#                    d nb_f + nb_f nb_d; zc20 10 nb_f; zc17 4 nb_d; zs 1; table 2 x slots
#   SumcheckProof::size_bytes (sumcheck.rs:23-25): degree+1 Fp2 per round
# With these, the two archived fixtures reconcile with NO residual (tests).
# ---------------------------------------------------------------------------

def _tz(x: int) -> int:
    return (x & -x).bit_length() - 1


def v3_dims(d: int, f: int, tokens: int, log_cols: int) -> dict:
    if tokens <= 0 or tokens & (tokens - 1):
        raise ProfileError(f"tokens={tokens}: LayoutV3 needs a power of two")
    log_t = _tz(tokens)
    log_db, log_fb = min(_tz(d), 12), min(_tz(f), 12)
    if log_db < 4 or log_fb < 4:
        raise ProfileError(f"d {d} / f {f}: LayoutV3 needs 16 | d, f")
    nb_d, nb_f = d >> log_db, f >> log_fb
    log_a_min = log_t + min(log_db, log_fb)
    log_n = min(log_cols, log_a_min)
    return {"log_t": log_t, "log_db": log_db, "log_fb": log_fb, "nb_d": nb_d, "nb_f": nb_f,
            "log_a_min": log_a_min, "log_n": log_n, "log_s": max(log_n, 16),
            "log_wb": log_db + log_fb, "log_wn": min(log_cols, log_db + log_fb)}


def argument_sizes(dims: dict, p3: bool, table_slots: int = 6, pred: bool = False) -> list[dict]:
    """The six `ArgumentBytes` (plus the predicate) from `mask_specs_v3` and the
    verifier's terminal-length rules, shaped like `ArgumentBytes::json`."""
    x = 1 if p3 else 0
    t, db, fb, n, s = dims["log_t"], dims["log_db"], dims["log_fb"], dims["log_n"], dims["log_s"]
    nb_d, nb_f = dims["nb_d"], dims["nb_f"]
    specs = {"gu": (db + 1 + x, 2), "d": (fb + 1 + x, 2), "zc20": (t + fb + 1, 4),
             "zc17": (t + db + 1, 4), "zs": (n + 1, 2), "table": (s + 1, 3)}
    terms = {"gu": nb_d + 2 * nb_d * nb_f, "d": nb_f + nb_f * nb_d, "zc20": 10 * nb_f,
             "zc17": 4 * nb_d, "zs": 1, "table": 2 * table_slots}
    out = [{"name": name, "claim_or_challenge": CLAIM_BYTES,
            "round_evaluations": specs[name][0] * (specs[name][1] + 1) * FP2,
            "terminals": terms[name] * FP2} for name in ARGUMENT_NAMES]
    if pred:
        # function 2: (log_t + log_db + 1, 3); two masked terminals (output block, bit row)
        out.append({"name": PREDICATE_NAME, "claim_or_challenge": CLAIM_BYTES,
                    "round_evaluations": (t + db + 1) * 4 * FP2, "terminals": 2 * FP2})
    return out


@dataclass(frozen=True)
class FixtureLayer:
    """One v3 FFN layer whose A/H rows and group counts are DECLARED from the
    prover's own mask-site dump (the mirror derives W, the arguments, the mask
    opening and the framing; A/H rows stay handoff inputs, as in CL10)."""

    name: str
    d: int
    f: int
    tokens: int
    log_cols: int
    inv_rate: int
    checks: int
    a_rows: int
    h_rows: int
    w_groups: int
    a_groups: int
    h_groups: int
    archived_layer_bytes: dict   # {"P1": n, "P3": n} — the log's `layer N: ... B` line for THIS layer
    source: str
    table_slots: int = 6         # N_TABLE_SLOTS_V3 (zk.rs:2038)

    def opening(self, role: str, mode: str) -> CommitmentOpening:
        dims = v3_dims(self.d, self.f, self.tokens, self.log_cols)
        log_r = _tz(self.inv_rate)
        if role == "W":
            hiding = mode == "P3"
            ws = w_shape(self.d, self.f, self.log_cols, hiding=hiding)
            return CommitmentOpening(role="W", rows=ws["rows"], columns=self.checks, path_len=dims["log_wn"] + log_r,
                                     hiding=hiding, cols=1 << dims["log_wn"], groups=self.w_groups)
        rows = {"A": self.a_rows, "H": self.h_rows}[role]
        groups = {"A": self.a_groups, "H": self.h_groups}[role]
        return CommitmentOpening(role=role, rows=rows, columns=self.checks, path_len=dims["log_n"] + log_r,
                                 hiding=True, cols=1 << dims["log_n"], groups=groups)


def _opening_json(c: CommitmentOpening | None) -> dict:
    if c is None:
        return {"group_vectors": 0, "proximity_vector": 0, "columns": {k: 0 for k in COLUMN_KEYS}}
    return {"group_vectors": c.groups * c.vector_len() * FP2, "proximity_vector": c.prox_vectors * c.vector_len() * FP2,
            "columns": {"indices": c.columns * COL_INDEX, "values": c.data_only_bytes(), "salts": c.salt_bytes(),
                        "authentication_paths": c.columns * c.path_len * DIGEST}}


def derive_sizes(fx: FixtureLayer, mode: str, pred: bool = False) -> dict:
    """The mirror's `sizes` object for one layer and mode, shaped like `to_json()`."""
    if mode not in PRIVACY_MODES:
        raise ProfileError(f"unknown mode {mode!r}: declare P1 or P3")
    dims = v3_dims(fx.d, fx.f, fx.tokens, fx.log_cols)
    args = argument_sizes(dims, p3=(mode == "P3"), table_slots=fx.table_slots, pred=pred)
    predicate = args.pop() if pred else None
    m = MaskOpeningShape(sumchecks=len(ARGUMENT_NAMES) + (1 if pred else 0))
    w = fx.opening("W", mode)
    sizes = {
        "total_bytes": 0,
        "commitment_headers": FIXED_LEAVES["commitment_headers"],
        "mask_root": FIXED_LEAVES["mask_root"],
        "arguments": args,
        "mask_opening": {"functional_vector": (2 << m.log_msg) * FP2, "proximity_vector": (2 << m.log_msg) * FP2,
                         "columns": {"indices": m.checks * COL_INDEX, "values": m.checks * m.rows() * FP,
                                     "salts": m.checks * DIGEST, "authentication_paths": m.checks * m.log_dom * DIGEST}},
        "w_plain": _opening_json(w if mode == "P1" else None),
        "w_hiding": _opening_json(w if mode == "P3" else None),
        "a": _opening_json(fx.opening("A", mode)),
        "h": _opening_json(fx.opening("H", mode)),
        "predicate": predicate,
    }
    sizes["total_bytes"] = sum(flatten_sizes(sizes).values())
    return sizes


def derive_row(fx: FixtureLayer, mode: str, layer: int = 0, pass_verified: bool = True, pred: bool = False) -> dict:
    """A complete row as the CLI would print it — for tests and for showing a
    consumer what to expect. Its `sizes` are DERIVED, not measured."""
    return {"schema": 1, "unit": "bytes", "coverage": "ffn-only", "profile": "v3", "privacy": mode,
            "layer": layer, "serialized": True, "pass_verified": pass_verified, "sizes": derive_sizes(fx, mode, pred=pred)}


def reconcile(measured_sizes: dict, derived_sizes: dict) -> dict:
    """Leaf by leaf: measured (Codex's row) against derived (this mirror)."""
    m, d = flatten_sizes(measured_sizes), flatten_sizes(derived_sizes)
    leaves = [{"path": p, "derived": d[p], "measured": m[p], "delta_measured_minus_derived": m[p] - d[p]} for p in d]
    off = [x for x in leaves if x["delta_measured_minus_derived"]]
    return {"agrees": not off and measured_sizes["total_bytes"] == derived_sizes["total_bytes"],
            "measured_total_bytes": measured_sizes["total_bytes"], "derived_total_bytes": derived_sizes["total_bytes"],
            "leaves": leaves, "disagreeing_leaves": off,
            "note": ("derived == measured on every leaf" if not off else
                     f"{len(off)} leaf(s) differ: the mirror's declared A/H rows or group counts, or the layer's own table-slot "
                     f"widths, do not match this layer — the measured row is the authority for THIS layer; the mirror covers the "
                     f"layer whose dump it was declared from")}


# Two fixtures with archived per-layer sizes (the `layer N: prove ... s, N B`
# lines print `size_bytes()`, which `to_bytes` asserts against). A/H rows and
# groups from each log's mask-site dump.
FIXTURES = {
    "mistral-v3-layer": FixtureLayer(
        name="mistral-v3-layer", d=4096, f=14336, tokens=512, log_cols=14, inv_rate=4, checks=256,
        a_rows=MISTRAL_AH_ROWS["A"], h_rows=MISTRAL_AH_ROWS["H"], w_groups=MISTRAL_W_GROUPS,
        a_groups=MISTRAL_AH_GROUPS["A"], h_groups=MISTRAL_AH_GROUPS["H"],
        archived_layer_bytes={"P1": 40186228, "P3": 40251860},
        source="am_r2_mistral.log (lane AM rung 2): the run's single layer; dump 'A 3601 rows ... H 3033 rows'"),
    "zkv3-12x512-layer0": FixtureLayer(
        name="zkv3-12x512-layer0", d=768, f=2048, tokens=512, log_cols=14, inv_rate=4, checks=256,
        a_rows=559, h_rows=485, w_groups=2, a_groups=5, h_groups=5,
        archived_layer_bytes={"P1": 7306036, "P3": 7347092},
        source="results/cl5_r7/p1cold.1.log and p3.1.log: 'layer  0: prove ... s, N B'; dump 'A 559 rows = 520 data + 21 masks + 18 "
               "table/mask rows; H 485 rows = 432 data + 17 masks + 36 helper/mask rows'; W 288 plain / 298 hiding"),
}

# The frozen 12x512 zkv3 files: two layer CLASSES (layers 1 and 2 are 12,288 B
# larger in both modes; the dump covers layer 0 only, so the mirror does not
# derive them — a measured row per layer would).
ARCHIVED_FILES = {
    "zkv3-12x512": {
        "P1": {"bytes": 87697008, "sha256": "40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17",
               "layer_bytes": {l: (7318324 if l in (1, 2) else 7306036) for l in range(12)},
               "source": "results/cl5_r7/p1cold.1.log (also p1warm.*, p1nocache.*; the frozen `zkv3` gate digest)"},
        "P3": {"bytes": 88189680, "sha256": "be8d13cc5c2d1b2d515854c30dbc8330c5e4165c0cdc4cb641472ae5744d3bea",
               "layer_bytes": {l: (7359380 if l in (1, 2) else 7347092) for l in range(12)},
               "source": "results/cl5_r7/p3.1.log (p3.2, p3.3 identical)"},
    }
}


def get_fixture(name: str) -> FixtureLayer:
    if name not in FIXTURES:
        raise ProfileError(f"unknown fixture {name!r}. Known: {sorted(FIXTURES)}. Declare a layer from its own dump before reconciling against it.")
    return FIXTURES[name]


# ---------------------------------------------------------------------------
# Rows from a prover log: one per layer, pinned to the log's own size lines.
# ---------------------------------------------------------------------------

def rows_from_text(text: str) -> list[dict]:
    """Accepts a bare JSON object, a JSON list of rows, or any text containing
    `HASHLINE_PROOF_SIZE {json}` lines (a whole prover log)."""
    stripped = text.strip()
    if stripped.startswith("{") or stripped.startswith("["):
        obj = loads_strict(stripped)
        rows = obj if isinstance(obj, list) else [obj]
        if not all(isinstance(r, dict) for r in rows):
            raise BreakdownError("expected a row object or a list of row objects")
        return rows
    rows = []
    for line in text.splitlines():
        m = PROOF_SIZE_ROW.match(line)
        if m:
            rows.append(loads_strict(m.group(1)))
    return rows


def log_context(text: str) -> dict:
    layer_bytes, proof, timing = {}, None, None
    for line in text.splitlines():
        m = LAYER_LINE.match(line)
        if m:
            layer_bytes[int(m.group(1))] = int(m.group(2))
            continue
        m = PROOF_LINE.match(line)
        if m:
            proof = {"sha256": m.group(1), "bytes": int(m.group(2))}
            continue
        m = TIMING_ROW.match(line)
        if m:
            try:
                timing = json.loads(m.group(1))
            except json.JSONDecodeError:
                timing = None
    return {"layer_bytes": layer_bytes, "proof": proof, "timing": timing}


def validate_log(text: str, fixture: FixtureLayer | None = None) -> dict:
    """Validate every row in a prover log and pin the rows to the log: each
    row's total to its `layer N: ... B` line, the rows' sum to the `PROOF
    sha256 ... (N B)` line and to HASHLINE_TIMING.proof_bytes. With a fixture,
    reconcile each row against the mirror leaf by leaf."""
    rows = rows_from_text(text)
    ctx = log_context(text)
    if not rows:
        raise BreakdownError(
            f"no {PROOF_SIZE_TAG} rows: the run predates Codex's round-10 CLI or was not made with "
            f"`--phase-profile` (CPU only). Reconciliation is PENDING actual rows; nothing is inferred from the "
            f"{len(ctx['layer_bytes'])} `layer N: ... B` line(s) this log does have.")
    validated = [validate_row(r) for r in rows]
    layers = [v["layer"] for v in validated]
    dup = sorted({l for l in layers if layers.count(l) > 1})
    if dup:
        raise BreakdownError(f"layer(s) {dup} have more than one row: a layer counted twice is refused")
    privacies = sorted({v["privacy"] for v in validated})
    if len(privacies) > 1:
        raise BreakdownError(f"rows disagree on privacy {privacies}: one run has one mode")
    pins = []
    for v in validated:
        want = ctx["layer_bytes"].get(v["layer"])
        if want is not None and want != v["total_bytes"]:
            raise BreakdownError(
                f"layer {v['layer']}: row total {v['total_bytes']} B but the log's `layer {v['layer']}: ... B` line "
                f"(`size_bytes()`) says {want} B — two counts of one layer disagree")
        pins.append({"layer": v["layer"], "row_total_bytes": v["total_bytes"], "layer_line_bytes": want,
                     "pinned": want is not None})
    missing = sorted(set(ctx["layer_bytes"]) - set(layers))
    if missing:
        raise BreakdownError(f"the log has `layer N` lines for {sorted(ctx['layer_bytes'])} but rows only for {sorted(layers)}: "
                             f"rows missing for layer(s) {missing}")
    total = sum(v["total_bytes"] for v in validated)
    if ctx["proof"] and ctx["proof"]["bytes"] != total:
        raise BreakdownError(f"rows sum to {total} B but the PROOF line says {ctx['proof']['bytes']} B: the rows do not partition the file")
    tp = (ctx["timing"] or {}).get("proof_bytes")
    if tp is not None and tp != total:
        raise BreakdownError(f"rows sum to {total} B but HASHLINE_TIMING.proof_bytes={tp}")
    tpriv = (ctx["timing"] or {}).get("privacy")
    if tpriv is not None and tpriv != privacies[0]:
        raise BreakdownError(f"rows say privacy {privacies[0]} but HASHLINE_TIMING says {tpriv!r}")
    out = {
        "rows": len(validated), "layers": sorted(layers), "privacy": privacies[0],
        "all_pass_verified": all(v["pass_verified"] for v in validated),
        "rankable": all(v["pass_verified"] for v in validated),
        "rows_total_bytes": total, "proof_line": ctx["proof"], "timing_proof_bytes": tp,
        "pinned_to_layer_lines": pins, "per_layer": validated,
        "bytes_not_time": "byte counts only; the log's serialize_s clock is a separate, unrelated measurement",
    }
    if fixture is not None:
        out["reconciliation"] = {
            "fixture": fixture.name, "covers": "the layer the fixture was declared from (its dump); other layers are measured-only",
            "per_layer": [{"layer": r["layer"], **reconcile(r["sizes"], derive_sizes(fixture, r["privacy"], pred=r["sizes"]["predicate"] is not None))}
                          for r in rows],
        }
    return out


# ---------------------------------------------------------------------------
# A fixture DECLARED from a prover log's own dump lines. Not an inference from
# a proof file (CL10 refuses that): these are the prover's printed
# declarations — the header's d/f/tokens/log_cols/inv_rate/checks, the
# `layout:` line's A/H rows and n, and the `X: N claims in G groups` lines.
# The dump covers layer 0 only ("every layer identical in structure up to its
# window sizes"), so the fixture reconciles layer 0; other layers are
# measured-only and the per-leaf comparison shows exactly where they differ.
# ---------------------------------------------------------------------------

HEADER_LINE = re.compile(r"^pass \(v3\) \[ZK.*?\]: (\d+) layers x (\d+) tokens of \d+ .*?\(d (\d+) f (\d+); log_cols (\d+), inv_rate (\d+), col checks (\d+)")
LAYOUT_LINE = re.compile(r"layout: n = 2\^(\d+) columns; .*?; A (\d+) rows = .*?; H (\d+) rows = ")
GROUPS_LINE = re.compile(r"^\s*([WAH]): \d+ claims in (\d+) groups\s*$")
MODE_LINE = re.compile(r"^\s*MODE (P1|P3) ")
# Under P1 the prover prints no W group line (W is not masked), but the count
# is fixed by the claim structure: every Wg/Wu block claim is at p3, every Wd
# claim at p6, and `group_claims` keys on the point's column part
# (pcs.rs:237-252) — two groups (CL10 §7.4). The P3 dump prints the same two.
W_GROUPS_FUNCTION1 = 2


def fixture_from_log(text: str, name: str = "from-log") -> FixtureLayer:
    hdr = lay = mode = None
    groups = {}
    for line in text.splitlines():
        m = HEADER_LINE.match(line)
        if m and hdr is None:
            hdr = tuple(int(x) for x in m.groups())
            continue
        m = LAYOUT_LINE.search(line)
        if m and lay is None:
            lay = tuple(int(x) for x in m.groups())
            continue
        m = MODE_LINE.match(line)
        if m and mode is None:
            mode = m.group(1)
            continue
        m = GROUPS_LINE.match(line)
        if m and m.group(1) not in groups:
            groups[m.group(1)] = int(m.group(2))
    missing = [what for what, have in (("the `pass (v3) [ZK...]: L layers x T tokens ... (d D f F; log_cols, inv_rate, col checks)` header", hdr),
                                        ("the `layout: n = 2^k columns; ...; A R rows = ...; H R rows = ...` dump line", lay),
                                        ("the `A: N claims in G groups` line", groups.get("A")),
                                        ("the `H: N claims in G groups` line", groups.get("H"))) if have is None]
    if missing:
        raise BreakdownError("cannot declare a fixture from this log; missing " + "; ".join(missing) + ". A layout is declared, never guessed.")
    layers, tokens, d, f, log_cols, inv_rate, checks = hdr
    log_n_dump, a_rows, h_rows = lay
    dims = v3_dims(d, f, tokens, log_cols)
    if dims["log_n"] != log_n_dump:
        raise BreakdownError(f"the dump says n = 2^{log_n_dump} but the mirror's rule (min(log_cols, log_t + min(log_db, log_fb))) gives 2^{dims['log_n']}: the mirror has drifted from ZkLayoutV3::new")
    w_groups = groups.get("W", W_GROUPS_FUNCTION1)
    ctx = log_context(text)
    archived = {mode or "P1": ctx["layer_bytes"][0]} if 0 in ctx["layer_bytes"] else {}
    return FixtureLayer(name=name, d=d, f=f, tokens=tokens, log_cols=log_cols, inv_rate=inv_rate, checks=checks,
                        a_rows=a_rows, h_rows=h_rows, w_groups=w_groups, a_groups=groups["A"], h_groups=groups["H"],
                        archived_layer_bytes=archived,
                        source=f"declared from the log's own header, `layout:` and `claims in N groups` lines ({layers} layers x {tokens} tokens; dump = layer 0"
                               + ("; W groups from the P3 dump" if "W" in groups else f"; W groups = {W_GROUPS_FUNCTION1} from the function-1 claim structure, no P1 dump line") + ")")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layout", help=f"[CL10] one of {sorted(KNOWN_LAYOUTS)}")
    ap.add_argument("--observed-bytes", type=int, help="[CL10] MEASURED artifact size; never a modelled one")
    ap.add_argument("--against-layout", help="[CL10] a second layout to difference against (the mode cross-check)")
    ap.add_argument("--against-observed-bytes", type=int, help="[CL10] its MEASURED artifact size")
    ap.add_argument("--schema", action="store_true", help="[CL19] print the HASHLINE_PROOF_SIZE schema-1 section list (verbatim from Codex's to_json())")
    ap.add_argument("--validate-breakdown", metavar="PATH", help="[CL19] validate a row (a JSON object, a list, or a file with HASHLINE_PROOF_SIZE lines)")
    ap.add_argument("--from-log", metavar="PATH", help="[CL19] extract every HASHLINE_PROOF_SIZE row from a prover log, validate each, pin to the log's size lines")
    ap.add_argument("--reconcile", metavar="FIXTURE", help=f"[CL19] compare each validated row leaf by leaf with the mirror; one of {sorted(FIXTURES)}, or `auto` to declare the fixture from the log's own dump lines")
    ap.add_argument("--derive", metavar="FIXTURE", help=f"[CL19] print the mirror-derived row for a fixture; one of {sorted(FIXTURES)}")
    ap.add_argument("--mode", choices=PRIVACY_MODES, help="[CL19] privacy mode for --derive")
    a = ap.parse_args(argv)
    try:
        if a.schema:
            out = schema()
        elif a.derive:
            if not a.mode:
                ap.error("--derive needs --mode P1|P3")
            fx = get_fixture(a.derive)
            out = {"fixture": fx.name, "source": fx.source, "archived_layer_bytes": fx.archived_layer_bytes,
                   "derived_row": derive_row(fx, a.mode),
                   "derived_equals_archived": derive_sizes(fx, a.mode)["total_bytes"] == fx.archived_layer_bytes[a.mode],
                   "derived_not_measured": "every leaf here is DERIVED from the layout mirror; a measured row comes only from the prover"}
        elif a.validate_breakdown or a.from_log:
            path = a.validate_breakdown or a.from_log
            with open(path, errors="replace") as fh:
                text = fh.read()
            if a.reconcile == "auto":
                fx = fixture_from_log(text, name=f"from-log:{os.path.basename(path)}")
            else:
                fx = get_fixture(a.reconcile) if a.reconcile else None
            if a.from_log:
                out = validate_log(text, fx)
            else:
                rows = rows_from_text(text)
                if not rows:
                    raise BreakdownError(f"{path}: no row found (neither a JSON object nor a {PROOF_SIZE_TAG} line)")
                out = {"rows": [validate_row(r) for r in rows]}
                if fx is not None:
                    out["reconciliation"] = [reconcile(r["sizes"], derive_sizes(fx, r["privacy"], pred=r["sizes"]["predicate"] is not None)) for r in rows]
        elif a.layout:
            if a.observed_bytes is None:
                ap.error("--layout needs --observed-bytes")
            out = profile(get_layout(a.layout), a.observed_bytes)
            if a.against_layout or a.against_observed_bytes is not None:
                if not (a.against_layout and a.against_observed_bytes is not None):
                    ap.error("--against-layout and --against-observed-bytes go together")
                other = profile(get_layout(a.against_layout), a.against_observed_bytes)
                out = {"profile": out, "against": other, "delta_against_minus_profile": mode_delta(out, other)}
        else:
            ap.error("give --layout/--observed-bytes (CL10) or one of --schema, --validate-breakdown, --from-log, --derive (CL19)")
    except (ProfileError, BreakdownError) as e:
        print(json.dumps({"refused": str(e)}, indent=2))
        return 2
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
