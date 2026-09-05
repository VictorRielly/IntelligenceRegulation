#!/usr/bin/env python3
"""[ZK60-CL8] Symbolic buffer/lifetime accounting for pending private blocks.

WHAT THIS IS. A counting aid for GPU memory across a *composed* private block
(attention + FFN), where most of the arithmetic is NOT YET IMPLEMENTED. Every
buffer carries an owner, a birth event, a release event and a unit. Dimensions
that do not exist in the source yet stay SYMBOLIC: they are named and reported,
never guessed into a number.

WHAT THIS IS NOT. Not a measurement, not a safety bound, not permission to run
anything. It opens no device, reads no dataset and allocates no tensor. A plan
that fits here can still fail on a real card for everything in `UNACCOUNTED`.

THE ONE MODELLING FACT THAT MATTERS, learned the expensive way in CL1/M1:

    RELEASE IS NOT FREE.

`Pooled::drop` calls `pool_put`, which retains the buffer (up to 64 of them,
with no byte budget), and `pool_take` only reuses on an EXACT length match. So
a released buffer still occupies device memory until a `drain`, and a released
`rows*n` buffer can never satisfy a later `rows*nn` request. CL1's first
allocation table treated release as free and understated the peak by 1,349 MiB
— in the direction that authorises a run it should refuse. This tool therefore
tracks LIVE and POOLED as separate states and reports both.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field

U64 = 8  # bytes per field element on the device


class PlanError(ValueError):
    """Malformed plan: double ownership, bad lifetime, unknown event."""


@dataclass(frozen=True)
class Buffer:
    """One device allocation.

    `count` is a number of ELEMENTS when concrete, or a symbol name (str) when
    the dimension is not implemented yet. `elem_bytes` gives the unit.
    """

    name: str
    owner: str
    count: int | str
    born: str
    released: str | None  # None = never released (returned to the caller)
    elem_bytes: int = U64
    note: str = ""

    @property
    def symbolic(self) -> bool:
        return isinstance(self.count, str)

    @property
    def nbytes(self) -> int:
        if self.symbolic:
            raise PlanError(f"{self.key}: symbolic buffers have no byte count")
        return self.count * self.elem_bytes

    @property
    def key(self) -> str:
        return f"{self.owner}::{self.name}"


@dataclass
class Plan:
    """An ordered schedule of events and the buffers that live across it."""

    schedule: list[str]
    buffers: list[Buffer] = field(default_factory=list)
    drains: set[str] = field(default_factory=set)
    unaccounted: list[str] = field(default_factory=list)

    def validate(self) -> None:
        seen: set[str] = set()
        for b in self.buffers:
            if b.key in seen:
                raise PlanError(
                    f"double ownership: {b.key} is declared twice; two owners "
                    f"counting the same allocation is exactly the overlap error "
                    f"this tool exists to catch"
                )
            seen.add(b.key)
            if b.born not in self.schedule:
                raise PlanError(f"{b.key}: birth event {b.born!r} not in the schedule")
            if b.released is not None:
                if b.released not in self.schedule:
                    raise PlanError(f"{b.key}: release event {b.released!r} not in the schedule")
                if self.schedule.index(b.released) < self.schedule.index(b.born):
                    raise PlanError(
                        f"{b.key}: released at {b.released!r} before it is born at {b.born!r}"
                    )
        for d in self.drains:
            if d not in self.schedule:
                raise PlanError(f"drain event {d!r} not in the schedule")

    def state_at(self, idx: int) -> dict:
        """LIVE / POOLED bytes and the symbolic terms in force after event idx.

        A buffer is LIVE from its birth event through the event before its
        release. From its release it is POOLED — still occupying memory —
        until the next drain at or after that release.
        """
        live = pooled = 0
        live_sym: list[str] = []
        pooled_sym: list[str] = []
        # the most recent drain at or before idx
        last_drain = -1
        for i, ev in enumerate(self.schedule[: idx + 1]):
            if ev in self.drains:
                last_drain = i
        for b in self.buffers:
            bi = self.schedule.index(b.born)
            if bi > idx:
                continue
            ri = self.schedule.index(b.released) if b.released is not None else None
            if ri is None or ri > idx:
                if b.symbolic:
                    live_sym.append(f"{b.key}={b.count}")
                else:
                    live += b.nbytes
            else:
                # released; still pooled unless a drain happened at or after it
                if last_drain >= ri:
                    continue
                if b.symbolic:
                    pooled_sym.append(f"{b.key}={b.count}")
                else:
                    pooled += b.nbytes
        return {
            "event": self.schedule[idx],
            "live_bytes": live,
            "pooled_bytes": pooled,
            "accounted_bytes": live + pooled,
            "live_symbolic": sorted(live_sym),
            "pooled_symbolic": sorted(pooled_sym),
        }

    def report(self) -> dict:
        self.validate()
        stages = [self.state_at(i) for i in range(len(self.schedule))]
        peak = max(stages, key=lambda s: s["accounted_bytes"])
        sym = sorted({b.key for b in self.buffers if b.symbolic})
        complete = not sym
        out = {
            "schema": 1,
            "scope": "symbolic buffer/lifetime count; not measured, not a safety bound",
            "measured": False,
            "safe_to_run": False,
            "release_is_not_free": True,
            "stages": stages,
            "symbolic_buffers": sym,
            "symbolic_count": len(sym),
            "complete": complete,
            "unaccounted": self.unaccounted,
        }
        if complete:
            out["peak_event"] = peak["event"]
            out["peak_accounted_bytes"] = peak["accounted_bytes"]
            out["peak_accounted_mib"] = peak["accounted_bytes"] / 1048576
        else:
            # REFUSE to publish a peak for an incomplete plan. The numeric part
            # of a mostly-symbolic plan is not a small peak, it is NO peak, and
            # "0.0 MiB" is the single most misquotable thing this tool could
            # print. Callers must key off `complete`.
            out["peak_event"] = None
            out["peak_accounted_bytes"] = None
            out["peak_accounted_mib"] = None
            out["peak_refused_because"] = (
                f"{len(sym)} buffer(s) are symbolic; the numeric subtotal excludes them "
                f"and is NOT a peak. Supply the missing dimensions or treat this plan "
                f"as unaccounted."
            )
            out["numeric_subtotal_bytes_excluding_symbolic"] = peak["accounted_bytes"]
        return out


# ---------------------------------------------------------------------------
# Known-good calibration: the CL1 / M1 resident hiding commitment.
# If this stops reproducing 13,492 MiB the model has drifted from the source.
# ---------------------------------------------------------------------------

def resident_hiding_commit(rows: int, log_cols: int, inv_rate: int, q_pad: int,
                           ntt_max_log: int | None = None) -> Plan:
    """`dev_commit_zk_from` on its RESIDENT path, as the code actually runs."""
    n = 1 << log_cols
    nn = n * inv_rate
    ml = ntt_max_log if ntt_max_log is not None else (nn.bit_length() - 1)
    sched = ["upload", "inverse_ntt", "pad_scale", "forward_ntt", "column_hashes", "return"]
    bufs = [
        Buffer("twiddles", "gpu", (1 << ml) - 1, "upload", None, U64 * 2,
               "forward+inverse stage-major tables, uploaded once"),
        Buffer("systematic_data", "commit", rows * n, "upload", None, U64,
               "returned inside DevCommit"),
        Buffer("inverse_coefficients", "commit", rows * n, "inverse_ntt", "forward_ntt", U64,
               "released to the POOL after pad_scale; never reusable for rows*nn"),
        Buffer("pads", "commit", rows * q_pad, "pad_scale", None, U64, ""),
        Buffer("coset_powers", "commit", nn, "pad_scale", None, U64, ""),
        Buffer("expanded_coefficients", "commit", rows * nn, "pad_scale", "column_hashes", U64,
               "released to the POOL after the expand NTT"),
        Buffer("encoded_matrix", "commit", rows * nn, "forward_ntt", None, U64,
               "returned inside DevCommit on the resident path"),
        Buffer("device_leaf_hashes", "commit", nn * 8, "column_hashes", None, 4,
               "u32 slots"),
    ]
    return Plan(schedule=sched, buffers=bufs, drains=set(), unaccounted=[
        "CUDA context, loaded modules, driver allocations and fragmentation",
        "host witness/export tensors, staging buffers and serialized proofs",
        "helper generation, zero-check tables, matmul/sumcheck/opening workspaces",
    ])


def chunked_hiding_commit(rows: int, log_cols: int, inv_rate: int, q_pad: int,
                          chunk: int, ntt_max_log: int | None = None) -> Plan:
    """The CL1 chunked path: no `rows*nn` buffer is ever allocated."""
    n = 1 << log_cols
    nn = n * inv_rate
    ml = ntt_max_log if ntt_max_log is not None else (nn.bit_length() - 1)
    rmax = min(rows, chunk)
    b3_slots = 8 * 24 + 1
    sched = ["upload", "chunk_loop", "leaves", "return"]
    bufs = [
        Buffer("twiddles", "gpu", (1 << ml) - 1, "upload", None, U64 * 2, ""),
        Buffer("systematic_data", "commit", rows * n, "upload", None, U64, "returned"),
        Buffer("pads", "commit", rows * q_pad, "upload", None, U64, "retained for the deferred opening"),
        Buffer("coset_powers", "commit", nn, "upload", None, U64, "retained for the deferred opening"),
        Buffer("chunk_coefficients", "commit", rmax * n, "chunk_loop", "return", U64, ""),
        Buffer("chunk_expanded", "commit", rmax * nn, "chunk_loop", "return", U64, ""),
        Buffer("chunk_encoded", "commit", rmax * nn, "chunk_loop", "return", U64, ""),
        Buffer("blake3_column_state", "commit", b3_slots * nn, "chunk_loop", "return", 4, "u32 slots"),
        Buffer("device_leaf_hashes", "commit", nn * 8, "leaves", None, 4, "u32 slots"),
    ]
    return Plan(schedule=sched, buffers=bufs, drains=set(), unaccounted=[
        "CUDA context, loaded modules, driver allocations and fragmentation",
        "host witness/export tensors, staging buffers and serialized proofs",
        "helper generation, zero-check tables, matmul/sumcheck/opening workspaces",
    ])


# ---------------------------------------------------------------------------
# The pending private block. Most dimensions are SYMBOLIC on purpose.
# ---------------------------------------------------------------------------

def pending_private_block(blocks: int = 1, ffn_rows: dict | None = None) -> Plan:
    """One or two pending private blocks, deferred to a single final opening.

    A03 states that deferring openings retains "encodings, data, pads, salts
    and Merkle trees", and warns that composition can INCREASE overlap. So every
    commitment in every block is modelled as live until the final opening, and
    the attention side — which is not implemented — stays symbolic.
    """
    ffn_rows = ffn_rows or {}
    sched = ["begin"]
    for b in range(blocks):
        sched += [f"b{b}_attn_commit", f"b{b}_ffn_commit", f"b{b}_seam"]
    sched += ["final_open", "drain"]

    bufs: list[Buffer] = []
    for b in range(blocks):
        for role in ("W", "A", "H"):
            # FFN side: concrete when the caller supplies measured row counts
            cnt = ffn_rows.get(role)
            bufs.append(Buffer(
                f"ffn_{role}_retained", f"block{b}",
                cnt if cnt is not None else f"ffn_{role}_rows*nn",
                f"b{b}_ffn_commit", "final_open", U64,
                "data+pads+salts+tree retained until the single final opening",
            ))
            # Attention side: NOT IMPLEMENTED -> symbolic, never guessed
            bufs.append(Buffer(
                f"attn_{role}_retained", f"block{b}",
                f"attn_{role}_rows*nn", f"b{b}_attn_commit", "final_open", U64,
                "A01 schedule is observed only; no source implementation to count",
            ))
        bufs.append(Buffer(
            "seam_xz_boundary", f"block{b}", "4*nb_d*base_rows", f"b{b}_seam", "final_open", U64,
            "A03: two independent paired X/Z boundary sites per d-block",
        ))
        bufs.append(Buffer(
            "challenge_state", f"block{b}", "challenge_derived_elems", f"b{b}_seam", "final_open", U64,
            "functionals/masks derived after the commitments; size follows the reviewed plan",
        ))
    return Plan(schedule=sched, buffers=bufs, drains={"drain"}, unaccounted=[
        "ATTENTION ARITHMETIC IS NOT IMPLEMENTED: every attn_* term is symbolic",
        "the mask/claim plan is not selected yet (A03 acceptance item 1), so "
        "mask, histogram and proximity row counts cannot be fixed",
        "host-side retention of salts, Merkle trees and proof vectors",
        "transfer staging and pinned host buffers",
        "pool retention between blocks unless an explicit drain is scheduled",
        "CUDA context, modules, fragmentation",
    ])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("resident", help="the CL1/M1 resident hiding commitment (calibration)")
    c = sub.add_parser("chunked", help="the CL1 chunked hiding commitment")
    for p in (r, c):
        p.add_argument("--rows", type=int, required=True)
        p.add_argument("--log-cols", type=int, default=14)
        p.add_argument("--inv-rate", type=int, default=4)
        p.add_argument("--q-pad", type=int, default=256)
        p.add_argument("--ntt-max-log", type=int, default=None)
    c.add_argument("--chunk", type=int, default=128)

    b = sub.add_parser("pending", help="one or two pending private blocks (symbolic)")
    b.add_argument("--blocks", type=int, default=1, choices=(1, 2))

    a = ap.parse_args()
    if a.cmd == "resident":
        plan = resident_hiding_commit(a.rows, a.log_cols, a.inv_rate, a.q_pad, a.ntt_max_log)
    elif a.cmd == "chunked":
        plan = chunked_hiding_commit(a.rows, a.log_cols, a.inv_rate, a.q_pad, a.chunk, a.ntt_max_log)
    else:
        plan = pending_private_block(a.blocks)
    print(json.dumps(plan.report(), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
