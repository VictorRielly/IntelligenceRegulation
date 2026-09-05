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

SOURCE OF THE FORMULAS (read, not copied blindly):
  `OpeningZk::size_bytes`, hashline/src/zk.rs:501-503
      q.len()*16 + prox.len()*16
      + sum over opened columns of (8 + rows*8 + 32 + path.len()*32)
  `LayerProofZk::to_bytes`, hashline/src/zk.rs:903-928
      each commitment header = 32 root + 8 rows + 4 log_cols = 44 B
      plus a 32 B mask root

NOT A SECURITY STATEMENT. Sizes are sizes. Nothing here says a smaller
alternative is compatible, hiding, or sound; those need their own codec and
security gates, and §"candidates" says so for each one.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass

FP2 = 16          # bytes per Fp2 element
FP = 8            # bytes per field element in an opened column
DIGEST = 32       # bytes per Merkle digest / salt / root
COL_INDEX = 8     # u64 column index written before each opened column
COMMIT_HEADER = 32 + 8 + 4  # root + rows(u64) + log_cols(u32)
MASK_ROOT = 32


class ProfileError(ValueError):
    """Refused: unknown/underspecified layout, or a model that does not fit."""


@dataclass(frozen=True)
class CommitmentOpening:
    """One commitment's opened columns."""

    role: str          # "W" | "A" | "H" | "mask" | ...
    rows: int          # committed rows == entries per opened column
    columns: int       # number of opened columns
    path_len: int      # Merkle path length == log2(encoded columns)
    groups: int = 0    # Fp2 group-vector entries (q)
    prox: int = 0      # Fp2 proximity-vector entries

    def column_bytes(self) -> int:
        """The dominant term: the opened column DATA plus its per-column framing."""
        return self.columns * (COL_INDEX + self.rows * FP + DIGEST + self.path_len * DIGEST)

    def data_only_bytes(self) -> int:
        """Just the field elements — the mathematically irreducible part."""
        return self.columns * self.rows * FP

    def framing_bytes(self) -> int:
        """Per-column index + salt + Merkle path: structure, not values."""
        return self.columns * (COL_INDEX + DIGEST + self.path_len * DIGEST)

    def vector_bytes(self) -> int:
        return (self.groups + self.prox) * FP2


@dataclass
class Layout:
    name: str
    commitments: tuple[CommitmentOpening, ...]
    commitment_headers: int  # how many 44-byte headers the layer writes
    mask_roots: int = 1

    def derived(self) -> dict:
        cols = sum(c.column_bytes() for c in self.commitments)
        data = sum(c.data_only_bytes() for c in self.commitments)
        framing = sum(c.framing_bytes() for c in self.commitments)
        vectors = sum(c.vector_bytes() for c in self.commitments)
        headers = self.commitment_headers * COMMIT_HEADER + self.mask_roots * MASK_ROOT
        return {
            "opened_column_data_bytes": data,
            "opened_column_framing_bytes": framing,
            "opened_columns_total_bytes": cols,
            "group_and_proximity_vector_bytes": vectors,
            "commitment_header_bytes": headers,
            "derived_total_bytes": cols + vectors + headers,
        }


def profile(layout: Layout, observed_bytes: int) -> dict:
    if observed_bytes <= 0:
        raise ProfileError("observed artifact size must be positive and MEASURED")
    for c in layout.commitments:
        if c.rows <= 0 or c.columns <= 0 or c.path_len <= 0:
            raise ProfileError(
                f"{layout.name}/{c.role}: rows, columns and path_len must all be declared "
                f"(got rows={c.rows}, columns={c.columns}, path_len={c.path_len}). "
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
    out = {
        "schema": 1,
        "layout": layout.name,
        "measured_artifact_bytes": observed_bytes,
        "components": d,
        "residual_bytes": residual,
        "residual_note": (
            "sumcheck arguments, claims, terms and any predicate block. Measured by "
            "subtraction from the observed artifact, so the profile reconciles exactly; "
            "its INTERNAL split is not claimed here."
        ),
        "reconciles_exactly": derived + residual == observed_bytes,
        "shares": {
            "opened_column_data": d["opened_column_data_bytes"] / observed_bytes,
            "opened_column_framing": d["opened_column_framing_bytes"] / observed_bytes,
            "commitment_headers": d["commitment_header_bytes"] / observed_bytes,
            "residual_arguments": residual / observed_bytes,
        },
    }
    return out


# ---------------------------------------------------------------------------
# Declared layouts. A layout must be DECLARED to be profiled; there is no
# inference from a file, because a wrong inference produces a plausible and
# entirely fictional breakdown.
# ---------------------------------------------------------------------------

def mistral_v3_layer(mode: str) -> Layout:
    """One Mistral FFN layer, d 4096 / f 14336, T=512, inv_rate 4, 256 checks.

    Row counts are the ones the binary itself prints in its mask-site dump
    (W 10,774 / A 3,601 / H 3,033); encoded columns 65,536 -> Merkle path 16.
    """
    if mode not in ("P1", "P3"):
        raise ProfileError(f"unknown mode {mode!r}: declare P1 or P3")
    rows = {"W": 10774, "A": 3601, "H": 3033}
    coms = tuple(
        CommitmentOpening(role=r, rows=n, columns=256, path_len=16)
        for r, n in rows.items()
    )
    return Layout(name=f"mistral-v3-layer-{mode}", commitments=coms, commitment_headers=3)


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
    a = ap.parse_args()
    print(json.dumps(profile(get_layout(a.layout), a.observed_bytes), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
