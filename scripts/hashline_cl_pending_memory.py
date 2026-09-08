#!/usr/bin/env python3
"""[ZK60-CL8] Buffer/lifetime accounting for pending private blocks.

WHAT THIS IS. A counting aid for GPU memory across a *composed* private block
(attention + FFN), where most of the arithmetic is NOT YET IMPLEMENTED. Every
buffer carries an owner, a birth event, a drop event, a unit and a KIND (raw
allocation or pooled). Dimensions that do not exist in the source yet stay
SYMBOLIC: they are named and reported, never guessed into a number.

WHAT THIS IS NOT. Not a measurement, not a safety bound, not permission to run
anything. It opens no device, reads no dataset and allocates no tensor. A plan
that fits here can still fail on a real card for everything in `unaccounted`,
and a numeric subtotal — however exact — cannot authorise a pending private
block whose mask plan, attention relations and workspaces are not implemented.

THE ONE MODELLING FACT THAT MATTERS, learned the expensive way in CL1/M1:

    RELEASE IS NOT FREE.

`Pooled::drop` calls `pool_put`, which retains the buffer (up to 64 of them,
with no byte budget), and `pool_take` only reuses on an EXACT length match. So
a released `Pooled` buffer still occupies device memory until a `drain`, and a
released `rows*n` buffer can never satisfy a later `rows*nn` request. CL1's
first allocation table treated release as free and understated the peak by
1,349 MiB — in the direction that authorises a run it should refuse.

[round-7 review, 2026-09-06] Codex's review of the first version found five
counting errors. All five corrections are recorded here rather than erased,
because each mistake is the reason for a rule:

  1. CHUNK ROUNDING. `chunked_hiding_commit(300, 10, 4, 16, 1)` reported
     8,192 B of coefficient scratch. The device clamps the choice to >= 128
     rows and takes 1,048,576 B. This tool had its own `min(rows, chunk)`;
     the correction made in hashline_memory_plan never reached it. The chunk
     plan is now taken from the SHARED mirrors (hashline_cl_chunk_sweep's
     `plan_summary`, cross-checked against hashline_memory_plan's
     `chunk_rows`) and this tool refuses to count if the two disagree.
  2. VALIDATION. A buffer with `count=-1` produced a "complete" plan with a
     peak of -8 bytes. Counts, units, kinds, schedules, owners, inventories
     and shapes are now checked, and commitment shapes go through
     hashline_memory_plan's validator so the rules cannot drift.
  3. RELEASE vs FREE. Every dropped buffer was treated as pooled, and the
     resident plan kept pads, powers and leaves alive through return. On
     the device only `Pooled` buffers go back to the pool; raw allocations
     (pads and coset powers from `htod_sync_copy`, the u32 leaf buffer from
     `alloc`) are FREED on drop. Each buffer now carries a `kind`, and its
     fate at `dropped` follows the source: the resident commit returns
     data + encoded matrix with coef/coef2 POOLED and pads/powers/leaves
     FREED (the leaves inside `hash_cols`, before the caller returns); the
     chunked commit returns data + pads + powers with its four `take_min`
     scratch buffers POOLED and its leaves FREED by `commit_zk_chunked`.
  4. UNITS. `ffn_rows={"W": 100}` became a buffer of 100 elements, 800
     bytes. A row count with no column width or element representation is
     not a byte count. The pending block now takes `ffn_layouts` (rows,
     log_cols, inv_rate, q_pad, path) and derives the retained device set
     with the SAME buffers and lifetimes as the commit builders; a role
     without a layout stays SYMBOLIC, and `ffn_rows` is refused.
  5. REUSE IDENTITY. A matching peak did not show that reuse was modelled
     at all. The pool is now SIMULATED with hashline_memory_plan._Pool:
     `pool` takes are exact-match, `pool_min` takes are smallest-fitting,
     and an oversize `take_min` TRANSFERS the pooled capacity to the new
     owner — counted once, under the new owner's name. The additive count
     with reuse switched off is reported alongside as `no_reuse_bound`.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from dataclasses import dataclass, field

U64 = 8   # bytes per field element / u64 word on the device
U32 = 4   # bytes per u32 slot (leaf hashes)
MIB = 1024 ** 2

# Buffer kinds, named after what the source does at drop time.
RAW = "raw"            # dev.alloc / htod_sync_copy: FREED on drop, never pooled
POOL = "pool"          # Pooled::take: exact-match reuse; back to the POOL on drop
POOL_MIN = "pool_min"  # Pooled::take_min: smallest-fitting reuse; back to the POOL on drop
KINDS = (RAW, POOL, POOL_MIN)
UNITS = (1, 2, 4, 8, 16, 32)  # element sizes that exist on this device path

ROLES = ("W", "A", "H")
PATHS = ("chunked", "resident")
DEFAULT_CHUNK = 128  # cuda.rs chunk_rows() default and floor


def _sibling(module_name: str, filename: str):
    """Load a sibling script by path (the scripts directory is not a package).
    Registered in sys.modules first because dataclasses resolve annotations
    through it. [round-7 review] This is how the shared rules are reused
    instead of copied — the copy is what drifted."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
    spec = importlib.util.spec_from_file_location(module_name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = mod
    spec.loader.exec_module(mod)
    return mod


memplan = _sibling("hashline_memory_plan", "hashline_memory_plan.py")
sweep = _sibling("hashline_cl_chunk_sweep", "hashline_cl_chunk_sweep.py")
B3_STATE_SLOTS = memplan.B3_STATE_SLOTS


class PlanError(ValueError):
    """Malformed plan: bad count/unit/kind, bad lifetime, unknown event or
    owner, duplicate ownership, unsupported shape."""


def _looks_numeric(text: str) -> bool:
    try:
        float(text)
    except ValueError:
        return False
    return True


@dataclass(frozen=True)
class Buffer:
    """One device allocation.

    `count` is a number of ELEMENTS when concrete, or a symbol name (str) when
    the dimension is not implemented yet. `elem_bytes` gives the unit. `kind`
    says what happens at `dropped`: a RAW buffer is freed, a POOL/POOL_MIN
    buffer goes back to the pool and stays on the card until a drain.
    `dropped=None` means the owner keeps it past the end of the schedule
    (returned to the caller).
    """

    name: str
    owner: str
    count: int | str
    born: str
    dropped: str | None
    elem_bytes: int = U64
    kind: str = POOL
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

    def check(self) -> None:
        """[round-7 review] A buffer with count=-1 once produced a 'complete'
        plan with a peak of -8 bytes. Nothing malformed gets counted."""
        for label, value in (("name", self.name), ("owner", self.owner), ("born", self.born)):
            if not isinstance(value, str) or not value.strip():
                raise PlanError(f"buffer {self.name!r}: {label} must be a non-empty string, got {value!r}")
        if "::" in self.name or "::" in self.owner:
            raise PlanError(f"{self.key}: '::' separates owner from name and may not appear in either")
        if self.dropped is not None and (not isinstance(self.dropped, str) or not self.dropped.strip()):
            raise PlanError(f"{self.key}: drop event must be a non-empty string or None, got {self.dropped!r}")
        if self.kind not in KINDS:
            raise PlanError(f"{self.key}: kind {self.kind!r} is not one of {KINDS}")
        if type(self.elem_bytes) is not int or self.elem_bytes not in UNITS:
            raise PlanError(f"{self.key}: element size {self.elem_bytes!r} is not one of {UNITS} bytes")
        if isinstance(self.count, str):
            if not self.count.strip():
                raise PlanError(f"{self.key}: an empty string is not a symbol")
            if _looks_numeric(self.count):
                raise PlanError(
                    f"{self.key}: {self.count!r} is a number in a string, not a symbol; "
                    f"pass an int to count it or a name to keep it symbolic"
                )
        elif type(self.count) is not int or self.count < 1:
            raise PlanError(
                f"{self.key}: count {self.count!r} is not a positive integer "
                f"(a count of -1 once produced a 'complete' plan with a peak of -8 bytes)"
            )


class _DevicePool(memplan._Pool):
    """The shared pool simulation (exact `take`, smallest-fitting `take_min`,
    `put` on drop, capacities counted once) plus the one operation a single
    commitment never does but a composed block must schedule explicitly: a
    DRAIN, which frees every pooled buffer."""

    def drain(self) -> tuple[int, list[str]]:
        freed, labels = self.total(), self.labels()
        self.pool.clear()
        return freed, labels


def _inventory(spec) -> list[tuple[int, str]]:
    """A warm pool is an INVENTORY of capacities, never a flag: a list of
    byte counts, or of (bytes, label) pairs."""
    if spec is None:
        return []
    if not isinstance(spec, (list, tuple)):
        raise PlanError("inventory must be a list of pooled capacities in bytes (or (bytes, label) pairs)")
    out = []
    for item in spec:
        cap, label = (item, "inventory") if not isinstance(item, (list, tuple)) else (item[0], item[1])
        if type(cap) is not int or cap < 1:
            raise PlanError(f"inventory entry {item!r}: capacity must be a positive integer number of bytes")
        if not isinstance(label, str) or not label.strip():
            raise PlanError(f"inventory entry {item!r}: label must be a non-empty string")
        out.append((cap, label))
    return out


@dataclass
class Plan:
    """An ordered schedule of events and the buffers that live across it.

    `inventory` is what the pool already holds when the schedule starts.
    `owners`, when given, is the closed set of owners a buffer may name.
    `meta` is echoed into the report (shape, chunk plan, layouts).
    """

    schedule: list[str]
    buffers: list[Buffer] = field(default_factory=list)
    drains: set[str] = field(default_factory=set)
    unaccounted: list[str] = field(default_factory=list)
    inventory: list[tuple[int, str]] = field(default_factory=list)
    owners: set[str] | None = None
    meta: dict = field(default_factory=dict)

    def validate(self) -> None:
        if not isinstance(self.schedule, list) or not self.schedule:
            raise PlanError("the schedule is empty; a plan with no events has no peak")
        seen_ev: set[str] = set()
        for ev in self.schedule:
            if not isinstance(ev, str) or not ev.strip():
                raise PlanError(f"schedule event {ev!r} is not a non-empty string")
            if ev in seen_ev:
                raise PlanError(
                    f"duplicate schedule event {ev!r}; lifetimes are looked up by event name "
                    f"and a repeated name makes every birth/drop at it ambiguous"
                )
            seen_ev.add(ev)
        idx = {ev: i for i, ev in enumerate(self.schedule)}
        seen: set[str] = set()
        for b in self.buffers:
            if not isinstance(b, Buffer):
                raise PlanError(f"{b!r} is not a Buffer")
            b.check()
            if b.key in seen:
                raise PlanError(
                    f"double ownership: {b.key} is declared twice; two owners "
                    f"counting the same allocation is exactly the overlap error "
                    f"this tool exists to catch"
                )
            seen.add(b.key)
            if self.owners is not None and b.owner not in self.owners:
                raise PlanError(f"{b.key}: unknown owner {b.owner!r}; this plan's owners are {sorted(self.owners)}")
            if b.born not in idx:
                raise PlanError(f"{b.key}: birth event {b.born!r} not in the schedule")
            if b.dropped is not None:
                if b.dropped not in idx:
                    raise PlanError(f"{b.key}: drop event {b.dropped!r} not in the schedule")
                if idx[b.dropped] < idx[b.born]:
                    raise PlanError(f"{b.key}: dropped at {b.dropped!r} before it is born at {b.born!r}")
                if idx[b.dropped] == idx[b.born]:
                    raise PlanError(
                        f"{b.key}: born and dropped in the same event {b.born!r}; a buffer that "
                        f"exists only inside one event is never counted, so give it a later drop event"
                    )
        for d in self.drains:
            if d not in idx:
                raise PlanError(f"drain event {d!r} not in the schedule")
        self.inventory = _inventory(self.inventory)

    def simulate(self, reuse: bool = True) -> dict:
        """Walk the schedule IN ORDER against a simulated pool. At each event:
        drops first (a RAW buffer is FREED; a POOL/POOL_MIN buffer goes to the
        pool with its CAPACITY), then a drain if scheduled, then births (an
        exact or smallest-fitting take, which may be served by a pooled
        capacity — that capacity then moves to the new owner and is counted
        ONCE, there). Symbolic buffers are tracked by name in the same
        states; they never enter the numeric pool.

        `reuse=False` is the additive negative control: every take is fresh
        and the inventory is dead weight (the same control the Rust test
        `the_chunked_retry_reuses_pooled_capacity...` runs on the device)."""
        self.validate()
        pool = _DevicePool(self.inventory, reuse)
        live: dict[str, dict] = {}
        live_sym: dict[str, str] = {}
        pooled_sym: dict[str, str] = {}
        freed_keys: list[str] = []
        drained_labels: list[str] = []
        freed_total = raw_fresh_bytes = raw_fresh_count = 0
        stages: list[dict] = []
        for ev in self.schedule:
            freed_here: list[str] = []
            pooled_here: list[str] = []
            for b in self.buffers:
                if b.dropped != ev:
                    continue
                if b.symbolic:
                    live_sym.pop(b.key)
                    if b.kind == RAW:
                        freed_here.append(b.key)
                    else:
                        pooled_sym[b.key] = b.count
                        pooled_here.append(b.key)
                    continue
                rec = live.pop(b.key)
                if b.kind == RAW:
                    freed_total += rec["capacity_bytes"]
                    freed_here.append(b.key)
                else:
                    # pool_put keeps at most 64 buffers and FREES the rest;
                    # the shared _Pool models that cap and reports the bytes
                    # it turned away, so they are freed here, not lost.
                    before = getattr(pool, "freed_at_cap_bytes", 0)
                    pool.put(rec["capacity_bytes"], b.key, rec["fresh"])
                    turned_away = getattr(pool, "freed_at_cap_bytes", 0) - before
                    if turned_away:
                        freed_total += turned_away
                        freed_here.append(f"{b.key} (pool full)")
                    else:
                        pooled_here.append(b.key)
            drained_bytes, drained_here = None, []
            if ev in self.drains:
                drained_bytes, drained_here = pool.drain()
                freed_total += drained_bytes
                drained_here += [f"{k}={v}" for k, v in sorted(pooled_sym.items())]
                pooled_sym.clear()
            for b in self.buffers:
                if b.born != ev:
                    continue
                if b.symbolic:
                    live_sym[b.key] = b.count
                    continue
                want = b.nbytes
                if b.kind == RAW:
                    cap, origin, fresh = want, "fresh raw", True
                    raw_fresh_bytes += want
                    raw_fresh_count += 1
                elif b.kind == POOL:
                    cap, origin, fresh = pool.take(want)
                else:
                    cap, origin, fresh = pool.take_min(want)
                live[b.key] = {"buffer": b.key, "kind": b.kind, "capacity_bytes": cap,
                               "requested_bytes": want, "origin": origin, "fresh": fresh}
            freed_keys += freed_here
            drained_labels += drained_here
            live_b = sum(r["capacity_bytes"] for r in live.values())
            stages.append({
                "event": ev,
                "live_bytes": live_b,
                "pooled_bytes": pool.total(),
                "accounted_bytes": live_b + pool.total(),
                "freed_bytes_so_far": freed_total,
                "live_buffers": [dict(r) for r in live.values()],
                "pooled_buffers": pool.labels(),
                "live_symbolic": sorted(f"{k}={v}" for k, v in live_sym.items()),
                "pooled_symbolic": sorted(f"{k}={v}" for k, v in pooled_sym.items()),
                "pooled_here": pooled_here,
                "freed_here": freed_here,
                "drained_bytes": drained_bytes,
                "drained_here": drained_here,
            })
        end_state = {
            "live": sorted(live),
            "pooled": pool.labels(),
            "freed": freed_keys,
            "drained": drained_labels,
            "live_symbolic": sorted(live_sym),
            "pooled_symbolic": sorted(pooled_sym),
        }
        allocation = {
            "reuse_enabled": reuse,
            "inventory": [f"{label}:{cap}" for cap, label in self.inventory],
            "inventory_bytes": sum(cap for cap, _ in self.inventory),
            "fresh_pool_bytes": pool.fresh_bytes, "fresh_pool_count": pool.fresh_count,
            "fresh_raw_bytes": raw_fresh_bytes, "fresh_raw_count": raw_fresh_count,
            "reuse_count": pool.reuse_count, "reuse_capacity_bytes": pool.reuse_capacity,
            "reuse_requested_bytes": pool.reuse_requested,
        }
        return {"stages": stages, "end_state": end_state, "allocation": allocation}

    def state_at(self, idx: int) -> dict:
        """The snapshot after event `idx`. A pool has history, so a stage
        cannot be computed on its own: this runs the whole simulation."""
        return self.simulate()["stages"][idx]

    def report(self) -> dict:
        sim = self.simulate(reuse=True)
        no_reuse = self.simulate(reuse=False)
        stages = sim["stages"]
        peak = max(stages, key=lambda s: s["accounted_bytes"])
        no_reuse_peak = max(s["accounted_bytes"] for s in no_reuse["stages"])
        sym = sorted({b.key for b in self.buffers if b.symbolic})
        complete = not sym
        out = {
            "schema": 2,
            "scope": ("buffer/lifetime count against a simulated device pool; not measured, "
                      "not a safety bound, and no authority to run anything"),
            "measured": False,
            "safe_to_run": False,
            "release_is_not_free": True,
            "ownership_model": (
                "each device buffer is ONE capacity counted ONCE, live or pooled; a RAW buffer "
                "is freed at its drop event, a POOL/POOL_MIN buffer goes back to the pool until "
                "a drain; an oversize take_min reuse transfers the pooled capacity to the new "
                "owner; no_reuse_bound is the additive count with reuse disabled"
            ),
            "meta": self.meta,
            "stages": stages,
            "end_state": sim["end_state"],
            "allocation": sim["allocation"],
            "symbolic_buffers": sym,
            "symbolic_count": len(sym),
            "complete": complete,
            "unaccounted": self.unaccounted,
            "authorization": (
                "none. safe_to_run is false by construction: a numeric subtotal, even an exact "
                "one, cannot authorise a pending private block whose mask plan, attention "
                "relations and workspaces are not implemented"
            ),
        }
        if complete:
            out["peak_event"] = peak["event"]
            out["peak_accounted_bytes"] = peak["accounted_bytes"]
            out["peak_accounted_mib"] = peak["accounted_bytes"] / MIB
            out["no_reuse_bound_bytes"] = no_reuse_peak
        else:
            # REFUSE to publish a peak for an incomplete plan. The numeric part
            # of a mostly-symbolic plan is not a small peak, it is NO peak, and
            # "0.0 MiB" is the single most misquotable thing this tool could
            # print. Callers must key off `complete`.
            out["peak_event"] = None
            out["peak_accounted_bytes"] = None
            out["peak_accounted_mib"] = None
            out["no_reuse_bound_bytes"] = None
            out["peak_refused_because"] = (
                f"{len(sym)} buffer(s) are symbolic; the numeric subtotal excludes them "
                f"and is NOT a peak. Supply the missing dimensions or treat this plan "
                f"as unaccounted."
            )
            out["numeric_subtotal_bytes_excluding_symbolic"] = peak["accounted_bytes"]
            out["numeric_subtotal_event"] = peak["event"]
            out["numeric_subtotal_no_reuse_bytes_excluding_symbolic"] = no_reuse_peak
        return out


# ---------------------------------------------------------------------------
# Commitment shapes and buffers: ONE set of rules, shared with the planner.
# ---------------------------------------------------------------------------

RESIDENT_SCHEDULE = ["upload", "inverse_ntt", "pad_scale", "forward_ntt", "column_hashes", "return"]
CHUNKED_SCHEDULE = ["upload", "chunk_loop", "return"]
FALLBACK_SCHEDULE = ["upload", "inverse_ntt", "pad_scale", "refused", "chunk_loop", "return"]
STAGES = tuple(dict.fromkeys(RESIDENT_SCHEDULE + CHUNKED_SCHEDULE + FALLBACK_SCHEDULE))
RETAINED = "retained"  # sentinel: dropped only when the returned commitment is

COMMIT_UNACCOUNTED = [
    "CUDA context, loaded modules, driver allocations and fragmentation",
    "host witness/export tensors, staging buffers and serialized proofs",
    "helper generation, zero-check tables, matmul/sumcheck/opening workspaces",
    "the OPENING (dev_columns / columns_chunked_zk): the same chunk scratch again by "
    "take_min plus raw index and gather-output buffers",
]


def _shape(rows, log_cols, inv_rate, q_pad, ntt_max_log=None, chunk=None, mode="resident") -> dict:
    """Validate a commitment shape through hashline_memory_plan (index widths,
    rates, pad ranges, NTT limits — its rules, not a copy of them) and mirror
    the device chunk plan through hashline_cl_chunk_sweep, refusing if the two
    mirrors disagree. [round-7 review] this is the fix for finding 1."""
    try:
        ref = memplan.commitment_plan(rows, log_cols, inv_rate, q_pad, q_pad, ntt_max_log,
                                      mode=mode, chunk_rows=DEFAULT_CHUNK if chunk is None else chunk)
    except ValueError as e:
        raise PlanError(f"unsupported commitment shape (hashline_memory_plan refused it): {e}") from None
    n, nn = 1 << log_cols, (1 << log_cols) * inv_rate
    sh = {"rows": rows, "log_cols": log_cols, "inv_rate": inv_rate, "q_pad": q_pad,
          "columns": n, "encoded_columns": nn, "ntt_max_log": ref["shape"]["ntt_max_log"],
          "n": n, "nn": nn, "ml": ref["shape"]["ntt_max_log"]}
    if chunk is not None:
        try:
            chunk_rows = sweep.effective_chunk_rows(chunk)
            ps = sweep.plan_summary(rows, chunk_rows)
        except ValueError as e:
            raise PlanError(f"chunk plan refused: {e}") from None
        if ps["rmax"] != ref["chunk_rows"]:
            raise PlanError(
                f"the two chunk-plan mirrors disagree at rows {rows}, choice {chunk}: "
                f"chunk_sweep says {ps['rmax']}, memory_plan says {ref['chunk_rows']}; "
                f"refusing to count on a mismatched plan"
            )
        sh.update({"chunk_choice": chunk, "chunk_rows": chunk_rows, "rmax": ps["rmax"],
                   "chunks": ps["chunks"], "final_chunk_rows": ps["final"]})
    return sh


def _public_shape(sh: dict) -> dict:
    keys = ("rows", "log_cols", "inv_rate", "q_pad", "columns", "encoded_columns", "ntt_max_log",
            "chunk_choice", "chunk_rows", "rmax", "chunks", "final_chunk_rows", "path")
    return {k: sh[k] for k in keys if k in sh}


def _twiddles(ml: int, born: str) -> Buffer:
    return Buffer("twiddles", "gpu", (1 << ml) - 1, born, None, U64 * 2, RAW,
                  "forward+inverse stage-major tables; uploaded once per process and kept")


def _commit_buffers(owner: str, prefix: str, sh: dict, path: str,
                    born_at: dict, dropped_at: dict, retain_until: str | None = None) -> list[Buffer]:
    """The device buffers of ONE hiding commitment with the lifetimes the
    source gives them (dev_commit_zk_from, commit_zk_chunked, hash_cols).
    `born_at`/`dropped_at` map the commit's internal stages onto schedule
    events (identity for the standalone builders; collapsed onto one commit
    event and the next for a composed block). `retain_until` is where the
    RETURNED commitment itself is dropped (None = kept past the schedule)."""
    rows, n, nn, q = sh["rows"], sh["n"], sh["nn"], sh["q_pad"]

    def buf(name, count, born, dropped, elem=U64, kind=POOL, note=""):
        end = retain_until if dropped is RETAINED else dropped_at[dropped]
        return Buffer(prefix + name, owner, count, born_at[born], end, elem, kind, note)

    if path == "resident":
        return [
            buf("systematic_data", rows * n, "upload", RETAINED,
                note="Pooled::take (exact); returned inside DevCommit.data"),
            buf("pads", rows * q, "upload", "return", kind=RAW,
                note="htod_sync_copy (RAW). The resident result carries no ZkReenc, so pads "
                     "are FREED when dev_commit_zk_from returns — not pooled, not retained"),
            buf("coset_powers", nn, "upload", "return", kind=RAW, note="as pads"),
            buf("inverse_coefficients", rows * n, "inverse_ntt", "forward_ntt",
                note="drop(d_coef) after pad_scale: to the POOL, never freed; can never serve a rows*nn take"),
            buf("expanded_coefficients", rows * nn, "pad_scale", "column_hashes",
                note="drop(d_coef2) after the forward NTT: to the POOL"),
            buf("encoded_matrix", rows * nn, "forward_ntt", RETAINED,
                note="Pooled::take (exact); returned inside DevCommit.enc"),
            buf("device_leaf_hashes", nn * 8, "column_hashes", "return", elem=U32, kind=RAW,
                note="alloc::<u32>(nn*8) inside hash_cols; FREED when hash_cols returns, "
                     "which is before the caller returns"),
        ]
    rmax = sh["rmax"]
    scratch_note = "Pooled::take_min (smallest fitting; an oversize pooled buffer transfers its capacity here)"
    out = [
        buf("systematic_data", rows * n, "upload", RETAINED,
            note="Pooled::take (exact); returned inside DevCommit.data"),
        buf("pads", rows * q, "upload", RETAINED, kind=RAW,
            note="htod_sync_copy (RAW) and RETAINED in ZkReenc so the deferred opening can re-encode"),
        buf("coset_powers", nn, "upload", RETAINED, kind=RAW, note="as pads"),
    ]
    if path == "fallback":
        out += [
            buf("inverse_coefficients", rows * n, "inverse_ntt", "refused",
                note="the resident attempt's coef: dropped after pad_scale, to the POOL"),
            buf("expanded_coefficients", rows * nn, "pad_scale", "chunk_loop",
                note="the resident attempt's coef2: dropped when the rows*nn take is refused, to the POOL; "
                     "take_min then serves the chunk scratch from it"),
        ]
    out += [
        buf("chunk_coefficients", rmax * n, "chunk_loop", "return", kind=POOL_MIN, note=scratch_note),
        buf("chunk_expanded", rmax * nn, "chunk_loop", "return", kind=POOL_MIN, note=scratch_note),
        buf("chunk_encoded", rmax * nn, "chunk_loop", "return", kind=POOL_MIN, note=scratch_note),
        buf("blake3_column_state", (B3_STATE_SLOTS * nn + 1) // 2, "chunk_loop", "return", kind=POOL_MIN,
            note="u64 words: Pooled::take_min((B3_STATE_SLOTS*nn + 1) / 2)"),
        buf("device_leaf_hashes", nn * 8, "chunk_loop", "return", elem=U32, kind=RAW,
            note="alloc::<u32>(nn*8) in commit_zk_chunked; FREED before it returns"),
    ]
    return out


# ---------------------------------------------------------------------------
# Known-good calibration: the CL1 / M1 resident hiding commitment.
# If this stops reproducing 13,492 MiB the model has drifted from the source.
# ---------------------------------------------------------------------------

def resident_hiding_commit(rows: int, log_cols: int, inv_rate: int, q_pad: int,
                           ntt_max_log: int | None = None, inventory=None) -> Plan:
    """`dev_commit_zk_from` on its RESIDENT path, as the code actually runs."""
    sh = _shape(rows, log_cols, inv_rate, q_pad, ntt_max_log, mode="resident")
    ident = {s: s for s in RESIDENT_SCHEDULE}
    bufs = [_twiddles(sh["ml"], "upload")] + _commit_buffers("commit", "", sh, "resident", ident, ident)
    return Plan(RESIDENT_SCHEDULE[:], bufs, set(), COMMIT_UNACCOUNTED[:], _inventory(inventory),
                {"gpu", "commit"}, {"path": "resident", "shape": _public_shape(sh)})


def chunked_hiding_commit(rows: int, log_cols: int, inv_rate: int, q_pad: int,
                          chunk: int, ntt_max_log: int | None = None, inventory=None) -> Plan:
    """The CL1 chunked path: no `rows*nn` buffer is ever allocated. The chunk
    plan mirrors the device exactly (clamp >= 128; all rows as one chunk when
    rows <= choice; else steps of (choice // 128) * 128)."""
    sh = _shape(rows, log_cols, inv_rate, q_pad, ntt_max_log, chunk, mode="chunked")
    ident = {s: s for s in CHUNKED_SCHEDULE}
    bufs = [_twiddles(sh["ml"], "upload")] + _commit_buffers("commit", "", sh, "chunked", ident, ident)
    return Plan(CHUNKED_SCHEDULE[:], bufs, set(), COMMIT_UNACCOUNTED[:], _inventory(inventory),
                {"gpu", "commit"}, {"path": "chunked", "shape": _public_shape(sh)})


def fallback_hiding_commit(rows: int, log_cols: int, inv_rate: int, q_pad: int,
                           chunk: int = DEFAULT_CHUNK, ntt_max_log: int | None = None, inventory=None) -> Plan:
    """The CL3 fallback: the resident attempt allocates coef and coef2, the
    rows*nn encoded take is REFUSED, both are dropped to the POOL (not freed),
    and the chunked retry's take_min is served from them by capacity."""
    sh = _shape(rows, log_cols, inv_rate, q_pad, ntt_max_log, chunk, mode="fallback")
    inv = _inventory(inventory)
    # [round-7 review, Codex on CL3] `pool_take` returns an EXACT pooled match
    # before any fresh allocation can be refused. coef2's take consumes one
    # pooled rows*nn capacity; if the inventory holds another, the encoded
    # take is served from it and the refusal is UNREACHABLE — the call simply
    # completes resident. Refuse to count a fallback the device cannot take.
    if sum(1 for cap, _ in inv if cap == rows * sh["nn"] * U64) >= 2:
        raise PlanError(
            f"fallback unreachable: the inventory holds two exact rows*nn ({rows * sh['nn'] * U64} B) "
            f"capacities, so after coef2 takes one the encoded take is served from the other and "
            f"the resident path completes; count it with resident_hiding_commit(..., inventory=...)"
        )
    ident = {s: s for s in FALLBACK_SCHEDULE}
    bufs = [_twiddles(sh["ml"], "upload")] + _commit_buffers("commit", "", sh, "fallback", ident, ident)
    return Plan(FALLBACK_SCHEDULE[:], bufs, set(), COMMIT_UNACCOUNTED[:], _inventory(inventory),
                {"gpu", "commit"}, {"path": "fallback", "shape": _public_shape(sh)})


# ---------------------------------------------------------------------------
# The pending private block. Most dimensions are SYMBOLIC on purpose.
# ---------------------------------------------------------------------------

LAYOUT_REQUIRED = ("rows", "log_cols", "inv_rate", "q_pad", "path")
LAYOUT_OPTIONAL = ("chunk",)

PENDING_UNACCOUNTED = [
    "ATTENTION ARITHMETIC IS NOT IMPLEMENTED: every attn_* term is symbolic",
    "the mask/claim plan is not selected yet (A03 acceptance item 1), so mask, histogram and "
    "proximity row counts cannot be fixed; a supplied FFN layout is the caller's declaration, "
    "not the final profile",
    "host-side retention of salts, Merkle trees and proof vectors (A03's 'salts and Merkle "
    "trees' are host memory, not device buffers)",
    "transfer staging and pinned host buffers",
    "the final opening's own re-encode scratch, index lists and gather outputs",
    "CUDA context, modules, fragmentation",
]


def _ffn_layouts(spec) -> dict[str, dict]:
    """[round-7 review] A layout is rows x columns x representation x path.
    A bare number is refused: `ffn_rows={"W": 100}` once became 800 bytes."""
    if spec is None:
        return {}
    if not isinstance(spec, dict):
        raise PlanError("ffn_layouts must be a dict of role -> layout")
    out = {}
    for role, lay in spec.items():
        if role not in ROLES:
            raise PlanError(f"unknown FFN role {role!r}; the roles are {ROLES}")
        if not isinstance(lay, dict):
            raise PlanError(
                f"ffn_layouts[{role!r}] = {lay!r} is not a layout. A row count with no column width "
                f"and no element representation is not a byte count (this tool once turned 100 'rows' "
                f"into 800 bytes). Give {{rows, log_cols, inv_rate, q_pad, path}} or leave the role out "
                f"to keep it symbolic"
            )
        missing = [k for k in LAYOUT_REQUIRED if k not in lay]
        extra = sorted(set(lay) - set(LAYOUT_REQUIRED) - set(LAYOUT_OPTIONAL))
        if missing or extra:
            raise PlanError(
                f"ffn_layouts[{role!r}]: missing {missing}, unknown {extra}; a layout needs exactly "
                f"{LAYOUT_REQUIRED} (+ optional {LAYOUT_OPTIONAL}); leave the role out to keep it symbolic"
            )
        if lay["path"] not in PATHS:
            raise PlanError(f"ffn_layouts[{role!r}]: path {lay['path']!r} is not one of {PATHS}")
        chunk = lay.get("chunk", DEFAULT_CHUNK) if lay["path"] == "chunked" else None
        sh = _shape(lay["rows"], lay["log_cols"], lay["inv_rate"], lay["q_pad"], None, chunk, mode=lay["path"])
        sh["path"] = lay["path"]
        out[role] = sh
    return out


def pending_private_block(blocks: int = 1, ffn_layouts: dict | None = None,
                          ntt_max_log: int | None = None, drain_between_blocks: bool = False,
                          ffn_rows=None) -> Plan:
    """One or two pending private blocks, deferred to a single final opening.

    A03 states that deferring openings retains "encodings, data, pads, salts
    and Merkle trees", and warns that composition can INCREASE overlap. So
    every commitment in every block is modelled as live until the final
    opening, and the attention side — which is not implemented — stays
    symbolic.

    `ffn_layouts` maps a role (W/A/H) to {rows, log_cols, inv_rate, q_pad,
    path[, chunk]}. A supplied role is counted with the SAME buffers and
    lifetimes as the standalone commit builders: its retained set (data +
    pads + powers on the chunked path; data + encoded matrix on the resident
    path) lives until `final_open`, its scratch is pooled and its leaves
    freed at the next event — where the next commit's take_min may reuse the
    pooled capacity. A role left out stays symbolic. The modelled order is
    W, A, H; reuse (and only reuse) is order-sensitive, which is why the
    no-reuse bound is reported as well.

    `ntt_max_log` sizes the process-wide NTT tables. Left out, the tables
    stay symbolic: they follow the LARGEST encoded width of any commitment
    in the block, attention included, and that width is not known.
    """
    if ffn_rows is not None:
        raise PlanError(
            "[round-7 review] `ffn_rows` is gone: a bare row count has no column width or element "
            "representation, and the tool once turned {'W': 100} into 800 bytes. Pass "
            "ffn_layouts={'W': {'rows': .., 'log_cols': .., 'inv_rate': .., 'q_pad': .., 'path': "
            "'chunked'|'resident'}} instead; roles left out stay symbolic"
        )
    if type(blocks) is not int or blocks not in (1, 2):
        raise PlanError("blocks must be 1 or 2 (CL8's scope: one or two pending blocks deferred to a single final opening)")
    if not isinstance(drain_between_blocks, bool):
        raise PlanError("drain_between_blocks must be a bool")
    layouts = _ffn_layouts(ffn_layouts)
    if ntt_max_log is not None:
        if type(ntt_max_log) is not int or not 1 <= ntt_max_log <= 24:
            raise PlanError("ntt_max_log must be an integer in 1..24")
        for role, sh in layouts.items():
            if sh["nn"].bit_length() - 1 > ntt_max_log:
                raise PlanError(
                    f"ntt_max_log {ntt_max_log} is below the encoded-column log "
                    f"{sh['nn'].bit_length() - 1} of the {role} layout; the tables would be too "
                    f"small for it (CL2's monotonic-cache invariant)"
                )

    sched = ["begin"]
    for b in range(blocks):
        sched.append(f"b{b}_attn_commit")
        sched += [f"b{b}_ffn_{role}_commit" for role in ROLES]
        sched.append(f"b{b}_seam")
    sched += ["final_open", "drain"]
    owners = {"gpu"} | {f"block{b}" for b in range(blocks)}

    bufs: list[Buffer] = []
    if ntt_max_log is None:
        bufs.append(Buffer("twiddles", "gpu", "2^ntt_max_log-1", "begin", None, U64 * 2, RAW,
                           "sized by the LARGEST encoded width of any commitment in the block, attention "
                           "included; pass ntt_max_log to count it"))
    else:
        bufs.append(_twiddles(ntt_max_log, "begin"))
    for b in range(blocks):
        owner = f"block{b}"
        for role in ROLES:
            # Attention side: NOT IMPLEMENTED -> symbolic, never guessed. Modelled
            # as pooled at final_open (the conservative fate) until the drain.
            bufs.append(Buffer(
                f"attn_{role}_retained", owner, f"attn_{role}_retained_device_bytes",
                f"b{b}_attn_commit", "final_open", U64, POOL,
                "A01 schedule is observed only; no source implementation to count",
            ))
        for role in ROLES:
            ev = f"b{b}_ffn_{role}_commit"
            nxt = sched[sched.index(ev) + 1]
            sh = layouts.get(role)
            if sh is None:
                bufs.append(Buffer(
                    f"ffn_{role}_retained", owner, f"ffn_{role}_retained_device_bytes",
                    ev, "final_open", U64, POOL,
                    "no layout supplied (rows x columns x representation x path unknown); stays symbolic",
                ))
            else:
                bufs += _commit_buffers(owner, f"ffn_{role}_", sh, sh["path"],
                                        dict.fromkeys(STAGES, ev), dict.fromkeys(STAGES, nxt),
                                        retain_until="final_open")
        bufs.append(Buffer(
            "seam_xz_boundary", owner, "4*nb_d*base_rows", f"b{b}_seam", "final_open", U64, POOL,
            "A03: two independent paired X/Z boundary sites per d-block",
        ))
        bufs.append(Buffer(
            "challenge_state", owner, "challenge_derived_elems", f"b{b}_seam", "final_open", U64, POOL,
            "functionals/masks derived after the commitments; size follows the reviewed plan",
        ))
    drains = {"drain"}
    if drain_between_blocks:
        drains |= {f"b{b}_seam" for b in range(blocks)}
    meta = {
        "blocks": blocks,
        "ffn_layouts": {role: _public_shape(sh) for role, sh in layouts.items()},
        "ffn_symbolic_roles": [r for r in ROLES if r not in layouts],
        "ntt_max_log": ntt_max_log,
        "drain_between_blocks": drain_between_blocks,
        "modelled_commit_order": list(ROLES),
    }
    return Plan(sched, bufs, drains, PENDING_UNACCOUNTED[:], [], owners, meta)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_layout(text: str) -> tuple[str, dict]:
    """ROLE=rows:log_cols:inv_rate:q_pad[:path[:chunk]]"""
    if "=" not in text:
        raise PlanError(f"--ffn-layout wants ROLE=rows:log_cols:inv_rate:q_pad[:path[:chunk]], got {text!r}")
    role, rest = text.split("=", 1)
    parts = rest.split(":")
    if not 4 <= len(parts) <= 6:
        raise PlanError(f"--ffn-layout {text!r}: expected 4 to 6 colon-separated fields")
    try:
        lay = {"rows": int(parts[0]), "log_cols": int(parts[1]), "inv_rate": int(parts[2]), "q_pad": int(parts[3])}
        lay["path"] = parts[4] if len(parts) > 4 else "chunked"
        if len(parts) > 5:
            lay["chunk"] = int(parts[5])
    except ValueError:
        raise PlanError(f"--ffn-layout {text!r}: rows, log_cols, inv_rate, q_pad and chunk must be integers") from None
    return role, lay


def _parse_inventory(text: str | None):
    if not text:
        return None
    try:
        return [int(x) for x in text.split(",") if x.strip()]
    except ValueError:
        raise PlanError("--inventory-bytes wants comma-separated integers") from None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("resident", help="the CL1/M1 resident hiding commitment (calibration)")
    c = sub.add_parser("chunked", help="the CL1 chunked hiding commitment")
    f = sub.add_parser("fallback", help="the CL3 fallback: resident attempt refused, chunked retry from the pool")
    for p in (r, c, f):
        p.add_argument("--rows", type=int, required=True)
        p.add_argument("--log-cols", type=int, default=14)
        p.add_argument("--inv-rate", type=int, default=4)
        p.add_argument("--q-pad", type=int, default=256)
        p.add_argument("--ntt-max-log", type=int, default=None)
        p.add_argument("--inventory-bytes", default=None,
                       help="comma-separated capacities already in the pool (a warm pool is an inventory, not a flag)")
    for p in (c, f):
        p.add_argument("--chunk", type=int, default=DEFAULT_CHUNK, help="HL_GPU_CHUNK_ROWS choice; the device clamps it to >= 128")

    b = sub.add_parser("pending", help="one or two pending private blocks (symbolic unless layouts are given)")
    b.add_argument("--blocks", type=int, default=1, choices=(1, 2))
    b.add_argument("--ffn-layout", action="append", default=[], metavar="ROLE=rows:log_cols:inv_rate:q_pad[:path[:chunk]]",
                   help="count an FFN role concretely; roles not given stay symbolic")
    b.add_argument("--ntt-max-log", type=int, default=None, help="size the NTT tables; left out they stay symbolic")
    b.add_argument("--drain-between-blocks", action="store_true", help="schedule a drain at each block's seam")

    a = ap.parse_args(argv)
    try:
        if a.cmd == "resident":
            plan = resident_hiding_commit(a.rows, a.log_cols, a.inv_rate, a.q_pad, a.ntt_max_log,
                                          _parse_inventory(a.inventory_bytes))
        elif a.cmd == "chunked":
            plan = chunked_hiding_commit(a.rows, a.log_cols, a.inv_rate, a.q_pad, a.chunk, a.ntt_max_log,
                                         _parse_inventory(a.inventory_bytes))
        elif a.cmd == "fallback":
            plan = fallback_hiding_commit(a.rows, a.log_cols, a.inv_rate, a.q_pad, a.chunk, a.ntt_max_log,
                                          _parse_inventory(a.inventory_bytes))
        else:
            layouts = dict(_parse_layout(t) for t in a.ffn_layout)
            plan = pending_private_block(a.blocks, layouts or None, a.ntt_max_log, a.drain_between_blocks)
        report = plan.report()
    except PlanError as e:
        ap.exit(2, f"pending memory: {e}\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
