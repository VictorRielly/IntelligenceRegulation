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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layout", required=True, help=f"one of {sorted(KNOWN_LAYOUTS)}")
    ap.add_argument("--observed-bytes", type=int, required=True,
                    help="MEASURED artifact size; never a modelled one")
    ap.add_argument("--against-layout", help="a second layout to difference against (the mode cross-check)")
    ap.add_argument("--against-observed-bytes", type=int, help="its MEASURED artifact size")
    a = ap.parse_args()
    out = profile(get_layout(a.layout), a.observed_bytes)
    if a.against_layout or a.against_observed_bytes is not None:
        if not (a.against_layout and a.against_observed_bytes is not None):
            ap.error("--against-layout and --against-observed-bytes go together")
        other = profile(get_layout(a.against_layout), a.against_observed_bytes)
        out = {"profile": out, "against": other, "delta_against_minus_profile": mode_delta(out, other)}
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
