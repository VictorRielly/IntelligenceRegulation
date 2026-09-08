#!/usr/bin/env python3
"""Count the GPU hiding-commit buffers of ONE dev_commit_zk_from call, without a GPU.

Examples:
  python3 scripts/hashline_memory_plan.py --p3-weights 4096 14336
  python3 scripts/hashline_memory_plan.py --rows 3033 --log-cols 14
  python3 scripts/hashline_memory_plan.py --rows 2000 --mode fallback --pool-state warm-resident

This is allocation accounting for ONE dev_commit_zk_from call, not a whole
prover bound or permission to run a model. All byte counts are modelled,
not measured. Prior live/pool storage and a component budget are explicit.
No tensors, datasets, drivers or devices are opened or allocated.

Modes:
  resident  the original path: both full rows*nn buffers. Its rows are
            UNCHANGED from the first planner (three routes agree on them).
  chunked   CL1's path: no full rows*nn buffer is ever allocated.
  fallback  the resident attempt refused partway, then the chunked retry.

[ZK60 round-7 review] The chunked and fallback modes are now a SIMULATION of
the device pool rather than a sum of named buffers: `take` is exact-match
reuse (pool_take), `take_min` is smallest-fitting reuse (pool_take_min),
`put` is Pooled::drop. Every device buffer is ONE capacity counted ONCE,
wherever it is (live or pooled); an oversize take_min reuse TRANSFERS the
pooled capacity to the new owner instead of adding a second copy. The old
additive count is still reported, labelled, as `no_reuse_bound_bytes`.
Return lifetimes follow the source: the callee's scratch goes back to the
POOL (it is not freed), the raw leaf buffer is FREED before return, and the
commitment retains data + pads + powers. A warm pool is an explicit
INVENTORY of capacities, never a flag.

[ZK60-CL16, round-9 review] ... and that retention is the CHUNKED
commitment's (`zk: Some(ZkReenc)`). A fallback that completes RESIDENT
(the exact rows*nn buffer was already pooled) returns `enc: Some, zk: None`
and its raw pads and coset powers are FREED at the return, so its last
snapshot is data + encoded matrix, the same figure the report declares as
`commitment_live_after_return_bytes`. The peak is unchanged: pads and
powers are still counted for as long as the source holds them.
"""

import argparse
import json


MIB = 1024 ** 2
SOURCES = {
    "layout": "hashline/src/zk.rs::ZkLayoutV3::new",
    "allocation": "hashline/src/gpu/cuda.rs::dev_commit_zk_from",
    "chunked": "hashline/src/gpu/cuda.rs::Gpu::commit_zk_chunked",
    "pool": "hashline/src/gpu/cuda.rs::pool_take / pool_take_min / pool_put / Pooled::drop",
    "twiddles": "hashline/src/gpu/cuda.rs::Gpu::ensure_twiddles",
    "hash": "hashline/src/gpu/cuda.rs::Gpu::hash_cols",
    "host": "hashline/src/pcs.rs::commit_zk_owned / commit_zk_device",
}
B3_STATE_SLOTS = 8 * 24 + 1   # mirrors gpu/cuda.rs
POOL_CAP = 64                 # gpu/cuda.rs pool_put: `if pool.len() < 64`
POOL_STATES = ("cold", "warm", "warm-resident")


def integer(name, value, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")
    return value


def power_two(name, value):
    integer(name, value, 1)
    if value & (value - 1):
        raise ValueError(f"{name} must be a power of two")
    return value


def weight_shape(d, f, log_cols):
    """Only W dimensions: exactly LayoutV3 + its per-block P3 masks."""
    integer("d", d, 16)
    integer("f", f, 16)
    integer("log_cols", log_cols, 1)
    if d % 16 or f % 16:
        raise ValueError("d and f must both be divisible by 16")
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    effective_log = min(log_cols, log_db + log_fb)
    n = 1 << effective_log
    blocks = 3 * (d // (1 << log_db)) * (f // (1 << log_fb))
    data_rows = 3 * d * f // n
    return {"d": d, "f": f, "data_rows": data_rows,
            "block_mask_rows": blocks, "proximity_rows": 1,
            "rows": data_rows + blocks + 1, "log_cols": effective_log}


class _Pool:
    """The device pool, simulated. Capacities in bytes with a label naming
    the buffer that last owned them. Reuse can be switched off to produce
    the conservative no-reuse bound (the same negative control the Rust
    test `the_chunked_retry_reuses_pooled_capacity...` runs on the device)."""

    def __init__(self, inventory, reuse=True):
        # (capacity, label, allocated_fresh_during_this_call)
        self.pool = [(int(cap), str(label), False) for cap, label in inventory]
        self.reuse = reuse
        self.fresh_bytes = self.fresh_count = 0
        self.reuse_count = self.reuse_capacity = self.reuse_requested = 0
        self.freed_at_cap_bytes, self.freed_at_cap = 0, []

    def take(self, want):
        """pool_take: EXACT length match only. Returns (capacity, origin, fresh)."""
        if self.reuse:
            for i, (cap, label, fresh) in enumerate(self.pool):
                if cap == want:
                    self.pool.pop(i)
                    return self._reused(cap, want, label, fresh)
        return self._fresh(want)

    def take_min(self, want):
        """pool_take_min: the SMALLEST pooled buffer of at least `want`."""
        if self.reuse:
            fits = [(cap, i) for i, (cap, _, _) in enumerate(self.pool) if cap >= want]
            if fits:
                cap, i = min(fits)
                _, label, fresh = self.pool.pop(i)
                return self._reused(cap, want, label, fresh)
        return self._fresh(want)

    def put(self, cap, label, fresh):
        """Pooled::drop -> pool_put, which RETAINS up to POOL_CAP buffers and
        FREES the rest (`if pool.len() < 64 { pool.push(buf) }`)."""
        if len(self.pool) >= POOL_CAP:
            self.freed_at_cap_bytes += cap
            self.freed_at_cap.append(f"{label}:{cap}")
            return
        self.pool.append((cap, label, fresh))

    def has_exact(self, want):
        return self.reuse and any(cap == want for cap, _, _ in self.pool)

    def total(self):
        return sum(cap for cap, _, _ in self.pool)

    def fresh_in_pool(self):
        """Capacity now pooled that this call allocated fresh."""
        return sum(cap for cap, _, fresh in self.pool if fresh)

    def labels(self):
        return [f"{label}:{cap}" for cap, label, _ in self.pool]

    def _fresh(self, want):
        self.fresh_bytes += want
        self.fresh_count += 1
        return want, "fresh", True

    def _reused(self, cap, want, label, fresh):
        self.reuse_count += 1
        self.reuse_capacity += cap
        self.reuse_requested += want
        return cap, f"reused {label} capacity", fresh


def _simulate(mode, size, inventory, reuse=True):
    """Walk dev_commit_zk_from in SOURCE ORDER for the chunked or fallback
    path. `size` names bytes: data, pads, pows, leaves, res_coef (rows*n),
    res_enc (rows*nn), chunk_coef, chunk_enc, state."""
    pool = _Pool(inventory, reuse)
    live, raw, events = {}, {}, []

    def snap(stage, note=None):
        live_b = sum(cap for cap, _, _, _ in live.values()) + sum(raw.values())
        row = {"stage": stage,
               "live_buffers": [f"{name} [{origin}]" for name, (_, origin, _, _) in live.items()] + list(raw),
               "pooled_buffers": pool.labels(), "live_bytes": live_b,
               "retained_pool_bytes": pool.total(), "accounted_device_bytes": live_b + pool.total(),
               "fresh_pool_bytes_so_far": pool.fresh_bytes}
        if note:
            row["note"] = note
        events.append(row)

    def take(name, want, exact):
        cap, origin, fresh = pool.take(want) if exact else pool.take_min(want)
        live[name] = (cap, origin, want, fresh)

    def release(name):
        cap, _, _, fresh = live.pop(name)
        pool.put(cap, name, fresh)

    take("systematic_data", size["data"], exact=True)
    raw["pads"], raw["coset_powers"] = size["pads"], size["pows"]
    snap("upload: data (caller's exact take), pads and coset powers (raw)")
    refused = None
    outcome = mode
    if mode == "fallback":
        take("inverse_coefficients", size["res_coef"], exact=True)
        snap("resident attempt: inverse NTT")
        take("expanded_coefficients", size["res_enc"], exact=True)
        snap("resident attempt: pad and coset scale")
        release("inverse_coefficients")
        snap("drop(coef): released to the POOL, not freed")
        # [round-7 review, Codex] `pool_take` returns an EXACT pooled match
        # BEFORE any fresh allocation can be refused. If the pool holds a
        # rows*nn buffer at this point, the late refusal is unreachable and
        # the resident path simply completes; inventing the failure here
        # would count a fallback the device cannot take.
        if pool.has_exact(size["res_enc"]):
            outcome = "resident (fallback unreachable: the exact encoded buffer was already pooled)"
            take("encoded_matrix", size["res_enc"], exact=True)
            snap("resident: forward NTT — the encoded buffer was served from the POOL, no refusal is reachable",
                 note="requested mode fallback; simulated outcome resident")
            release("expanded_coefficients")
            raw["device_leaf_hashes"] = size["leaves"]
            snap("resident: column hashes")
            del raw["device_leaf_hashes"]
            # [ZK60-CL16, round-9 review] A RESIDENT completion returns
            # WITHOUT ZkReenc, so the raw pads and coset powers END here — the
            # source (hashline/src/gpu/cuda.rs::dev_commit_zk_from) returns
            #   `Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None }, leaves))`
            # and `d_pads` / `d_pows` (locals from `dev.htod_sync_copy`, two
            # raw device allocations) drop at that return; only the two
            # CHUNKED returns move them into `ZkReenc { pads: d_pads, pows:
            # d_pows, q }`. This branch used to keep both in `raw` through the
            # return snapshot, so the last event reported data + enc + pads +
            # powers (12,359,168 B at rows 300 / log_cols 10 / rate 4 / q 16)
            # while `live_after_return_bytes` below said data + enc
            # (12,288,000 B): a 71,168 B overcount of the RETURN state only.
            # The peak is untouched — pads and powers were live through the
            # pad/scale, forward NTT and column-hash snapshots above, exactly
            # as long as the source holds them. This corrects an overcount;
            # it is not evidence of unsafe peak underestimation, and component
            # accounting alone does not authorize any whole-block run.
            del raw["pads"], raw["coset_powers"]
            snap("resident: pads and coset powers FREED (raw) — a resident commitment returns without ZkReenc; "
                 "the leaf buffer was FREED inside hash_cols")
            snap("return commitment: data + encoded matrix retained (RESIDENT outcome)")
            peak = max(row["accounted_device_bytes"] for row in events)
            return {"events": events, "peak_bytes": peak, "pool_after_bytes": pool.total(),
                    "fresh_pooled_after_bytes": pool.fresh_in_pool(),
                    "pool_after": pool.labels(), "fresh_pool_bytes": pool.fresh_bytes,
                    "fresh_pool_count": pool.fresh_count, "reuse_count": pool.reuse_count,
                    "reuse_capacity_bytes": pool.reuse_capacity, "reuse_requested_bytes": pool.reuse_requested,
                    "refused_request_bytes": None, "outcome": outcome, "fallback_reachable": False,
                    "freed_at_pool_cap_bytes": pool.freed_at_cap_bytes, "freed_at_pool_cap": pool.freed_at_cap,
                    "live_after_return_bytes": size["data"] + size["res_enc"]}
        refused = size["res_enc"]
        snap("encoded buffer (rows*nn) REFUSED: no allocation happened",
             note=f"exact take of {refused} B refused; nothing pooled matches exactly")
        release("expanded_coefficients")
        snap("drop(coef2): released to the POOL; chunked retry begins")
    take("chunk_coefficients", size["chunk_coef"], exact=False)
    take("chunk_expanded", size["chunk_enc"], exact=False)
    take("chunk_encoded", size["chunk_enc"], exact=False)
    take("blake3_column_state", size["state"], exact=False)
    raw["device_leaf_hashes"] = size["leaves"]
    snap("chunk loop" if mode == "chunked" else "chunked retry loop")
    for name in ("chunk_coefficients", "chunk_expanded", "chunk_encoded", "blake3_column_state"):
        release(name)
    del raw["device_leaf_hashes"]
    snap("callee returns: scratch to the POOL, leaf buffer FREED")
    snap("return commitment: data + pads + coset powers retained")
    peak = max(row["accounted_device_bytes"] for row in events)
    return {"events": events, "peak_bytes": peak, "pool_after_bytes": pool.total(),
            "fresh_pooled_after_bytes": pool.fresh_in_pool(),
            "pool_after": pool.labels(), "fresh_pool_bytes": pool.fresh_bytes,
            "fresh_pool_count": pool.fresh_count, "reuse_count": pool.reuse_count,
            "reuse_capacity_bytes": pool.reuse_capacity, "reuse_requested_bytes": pool.reuse_requested,
            "refused_request_bytes": refused, "outcome": outcome, "fallback_reachable": mode == "fallback",
            "freed_at_pool_cap_bytes": pool.freed_at_cap_bytes, "freed_at_pool_cap": pool.freed_at_cap,
            "live_after_return_bytes": size["data"] + size["pads"] + size["pows"]}


def commitment_plan(rows, log_cols=14, inv_rate=4, checks=256, q_pad=None,
                    ntt_max_log=None, prior_live_bytes=0, prior_pool_bytes=0,
                    component_budget_bytes=None, mode="resident", chunk_rows=128,
                    pool_state="cold", pool_inventory_bytes=None):
    """[ZK60-CL3] `mode` selects which code path is counted.

    resident  the original path: both full rows*nn buffers. Default, and its
              rows are UNCHANGED from before this extension.
    chunked   CL1's path: no full rows*nn buffer is ever allocated.
    fallback  the resident attempt that gets partway and then retries chunked.
              The resident buffers that DID allocate are released to the pool,
              not freed, and take_min then reuses them as chunk scratch — by
              CAPACITY, each buffer once (round-7 review).

    `pool_state` is an INVENTORY, not a flag:
      cold           empty pool.
      warm           what one previous identical call of this mode leaves
                     behind (its scratch back in the pool plus its data
                     buffer once the commitment drops).
      warm-resident  what a previous RESIDENT call of this shape leaves:
                     rows*n (coef), rows*nn (coef2), rows*n (data), rows*nn
                     (enc). The chunked modes then serve their scratch from
                     it by oversize take_min.
    `pool_inventory_bytes` (a list) overrides both with explicit capacities.
    Cold vs warm changes what is ALLOCATED, never what is OCCUPIED.
    """
    if mode not in ("resident", "chunked", "fallback"):
        raise ValueError("mode must be resident, chunked or fallback")
    if pool_state not in POOL_STATES:
        raise ValueError("pool_state must be cold, warm or warm-resident")
    integer("rows", rows, 1)
    integer("log_cols", log_cols, 1)
    if log_cols > 24:
        raise ValueError("log_cols exceeds this GPU NTT implementation's limit")
    power_two("inv_rate", inv_rate)
    integer("checks", checks, 1)
    q = checks if q_pad is None else integer("q_pad", q_pad, 1)
    n, nn = 1 << log_cols, (1 << log_cols) * inv_rate
    if q < checks or q > n or n + q > nn:
        raise ValueError("require checks <= q_pad <= columns and n + q_pad <= encoded columns")
    log_nn = nn.bit_length() - 1
    ml = log_nn if ntt_max_log is None else integer("ntt_max_log", ntt_max_log)
    if not log_nn <= ml <= 24:
        raise ValueError("require encoded-column log <= ntt_max_log <= 24")
    if rows > 2 ** 31 - 1 or nn > 2 ** 31 - 1 or rows * nn > 2 ** 32 - 1:
        raise ValueError("shape exceeds the current GPU launch/index integer widths")
    if rows * 8 + 1023 > 2 ** 32 - 1:
        raise ValueError("shape exceeds the column-hash byte-length integer width")
    integer("prior_live_bytes", prior_live_bytes)
    integer("prior_pool_bytes", prior_pool_bytes)
    if component_budget_bytes is not None:
        integer("component_budget_bytes", component_budget_bytes, 1)
    if pool_inventory_bytes is not None:
        if mode == "resident":
            raise ValueError("an explicit pool inventory is modelled for the chunked and fallback modes only")
        if not isinstance(pool_inventory_bytes, (list, tuple)) or not pool_inventory_bytes:
            raise ValueError("pool_inventory_bytes must be a non-empty list of byte capacities")
        if len(pool_inventory_bytes) > POOL_CAP:
            raise ValueError(f"pool inventory of {len(pool_inventory_bytes)} buffers exceeds the device pool's {POOL_CAP}-buffer cap; pool_put frees beyond it")
        for b in pool_inventory_bytes:
            integer("pool inventory entry", b, 1)

    data, encoded, pads, powers = rows * n * 8, rows * nn * 8, rows * q * 8, nn * 8
    leaves = nn * 32
    buffers = {"systematic_data": data, "inverse_coefficients": data,
               "pads": pads, "coset_powers": powers,
               "expanded_coefficients": encoded, "encoded_matrix": encoded,
               "device_leaf_hashes": leaves}
    twiddles = 2 * ((1 << ml) - 1) * 8

    # [ZK60-CL4 review] mirror the DEVICE plan: chunk_rows() clamps to >= 128
    # and chunk_plan uses step = (chunk // 128) * 128, so a too-small or
    # unrounded chunk count here would undercount the scratch.
    _cr = max(128, integer("chunk_rows", chunk_rows, 1))
    _step = max(1, _cr // 128) * 128
    # [ZK60-CL6] EXACT mirror of chunk_plan: when rows <= the (unrounded)
    # choice the device takes ALL rows as one chunk; only when it must split
    # does it step by the rounded count. `min(rows, _step)` undercounted the
    # single-chunk case for a choice that is not a multiple of 128 (rows 300,
    # choice 300: device allocates 300 rows of scratch, the old count said 256).
    rmax = rows if rows <= _cr else _step
    chunk_coef, chunk_enc = rmax * n * 8, rmax * nn * 8
    # the blake3 state is carried as a u64 pool buffer of ceil(slots*nn/2) words
    state_bytes = ((B3_STATE_SLOTS * nn + 1) // 2) * 8

    if mode == "resident":
        # ntt_rows writes into the supplied destination and uses no additional
        # device-global scratch. Kernel local/shared memory is NOT counted here.
        phases = [
            ("inverse NTT", ["systematic_data", "inverse_coefficients"], []),
            ("pad and coset scale", ["systematic_data", "inverse_coefficients", "pads", "coset_powers", "expanded_coefficients"], []),
            ("forward NTT", ["systematic_data", "pads", "coset_powers", "expanded_coefficients", "encoded_matrix"], ["inverse_coefficients"]),
            ("column hashes", ["systematic_data", "pads", "coset_powers", "encoded_matrix", "device_leaf_hashes"], ["inverse_coefficients", "expanded_coefficients"]),
            # [ZK60-CL16] the return row already EXCLUDES pads and coset
            # powers: `dev_commit_zk_from` returns `enc: Some(d_enc), zk: None`
            # and drops the two raw uploads. The fallback simulator's resident
            # outcome now ends their lifetimes at the same point (see
            # _simulate), so the two resident return snapshots agree.
            ("return commitment", ["systematic_data", "encoded_matrix"], ["inverse_coefficients", "expanded_coefficients"]),
        ]
        stages = []
        for label, active, pooled in phases:
            live = sum(buffers[key] for key in active)
            pool = sum(buffers[key] for key in pooled)
            stages.append({"stage": label, "live_buffers": active, "pooled_buffers": pooled,
                           "live_bytes": live, "retained_pool_bytes": pool,
                           "accounted_device_bytes": live + pool})
        component_peak = max(row["accounted_device_bytes"] for row in stages) + twiddles
        warm = pool_state != "cold"
        inventory_desc = ("cold: empty pool" if not warm else
                          "warm: rows*n x2 and rows*nn x2 already pooled (a prior resident call of this shape)")
        sim = None
        newly = (pads + powers + leaves) if warm else max(row["accounted_device_bytes"] for row in stages)
        live_after, new_pool_after, pool_after = data + encoded, data + encoded, (data + encoded)
        pool_delta_after = data + encoded
        no_reuse_bound = None
        outcome = "resident"
    else:
        buffers = dict(buffers)
        buffers.update({"chunk_coefficients": chunk_coef, "chunk_expanded": chunk_enc,
                        "chunk_encoded": chunk_enc, "blake3_column_state": state_bytes})
        size = {"data": data, "pads": pads, "pows": powers, "leaves": leaves, "res_coef": data,
                "res_enc": encoded, "chunk_coef": chunk_coef, "chunk_enc": chunk_enc, "state": state_bytes}
        if pool_inventory_bytes is not None:
            inventory = [(b, "inventory") for b in pool_inventory_bytes]
            inventory_desc = "explicit inventory"
        elif pool_state == "cold":
            inventory, inventory_desc = [], "cold: empty pool"
        elif pool_state == "warm":
            prior = _simulate(mode, size, [], reuse=True)
            inventory = [(int(item.rsplit(":", 1)[1]), "prior " + item.rsplit(":", 1)[0]) for item in prior["pool_after"]]
            inventory.append((data, "prior systematic_data"))
            inventory_desc = f"warm: what one previous {mode} call of this shape leaves pooled, plus its data buffer once the commitment drops"
        else:
            inventory = [(data, "prior inverse_coefficients"), (encoded, "prior expanded_coefficients"),
                         (data, "prior systematic_data"), (encoded, "prior encoded_matrix")]
            inventory_desc = "warm-resident: what a previous RESIDENT call of this shape leaves pooled"
        inventory_total = sum(cap for cap, _ in inventory)
        sim = _simulate(mode, size, inventory, reuse=True)
        no_reuse = _simulate(mode, size, inventory, reuse=False)
        stages = sim["events"]
        component_peak = sim["peak_bytes"] + twiddles
        no_reuse_bound = no_reuse["peak_bytes"] + twiddles
        newly = sim["fresh_pool_bytes"] + pads + powers + leaves
        live_after = sim["live_after_return_bytes"]
        pool_after = sim["pool_after_bytes"]
        outcome = sim["outcome"]
        # capacity in the pool after return that THIS call allocated fresh
        # (a warm pool's own buffers coming back are not new); the signed
        # pool delta is reported separately, since a warm inventory's data
        # buffer leaves the pool for the commitment.
        new_pool_after = sim["fresh_pooled_after_bytes"]
        pool_delta_after = pool_after - inventory_total

    subtotal = component_peak + prior_live_bytes + prior_pool_bytes
    report = {
        "schema": 2, "scope": f"one hiding commitment on the {mode} path; code-derived buffer accounting",
        "mode": mode, "outcome": outcome, "pool_state": pool_state, "pool_inventory": inventory_desc,
        "chunk_rows": rmax if mode in ("chunked", "fallback") else None,
        # [ZK60-CL3] held vs newly requested. On a warm pool the path occupies
        # the same bytes but allocates fewer of them; conflating the two is how
        # a "chunk-only count" gets mistaken for a whole-prover bound.
        # [ZK60-CL4 review] pads, coset powers and the leaf buffer are RAW
        # allocations (htod_sync_copy / alloc::<u32>), never pooled, so they
        # are paid on every call whatever the pool holds.
        "raw_non_poolable_bytes": pads + powers + leaves,
        "newly_allocated_capacity_bytes": newly,
        "measured": False, "safe_to_run": False, "sources": SOURCES,
        "shape": {"rows": rows, "log_cols": log_cols, "columns": n,
                  "encoded_columns": nn, "inv_rate": inv_rate, "checks": checks,
                  "q_pad": q, "ntt_max_log": ml},
        "buffers_bytes": buffers, "stages": stages, "twiddle_bytes": twiddles,
        # [round-7 review] return lifetimes from the source: a chunked
        # commitment returns NO encoded matrix; it retains data + pads +
        # powers; its scratch goes back to the POOL; the leaf buffer is freed.
        # [ZK60-CL16] and a RESIDENT outcome — the resident mode's table, or
        # a fallback whose exact rows*nn take was served from the pool —
        # retains data + encoded matrix ONLY: pads and powers are raw locals
        # freed at the return (no ZkReenc). The last entry of `stages` now
        # carries the same figure as this field on every mode and pool state.
        "commitment_live_after_return_bytes": live_after,
        "pool_bytes_after_return": pool_after,
        "new_pool_bytes_after_return": new_pool_after,
        "pool_delta_bytes_after_return": pool_delta_after,
        "component_peak_accounted_bytes": component_peak,
        "no_reuse_bound_bytes": no_reuse_bound,
        "prior_live_bytes": prior_live_bytes, "prior_pool_bytes": prior_pool_bytes,
        "subtotal_accounted_bytes": subtotal, "subtotal_accounted_mib": subtotal / MIB,
        "component_budget_bytes": component_budget_bytes,
        "exceeds_component_budget": None if component_budget_bytes is None else subtotal > component_budget_bytes,
        "host_retained_payload_bytes": {"systematic_data": data, "pads": pads,
                                        "salts": leaves, "merkle_tree": (2 * nn - 1) * 32},
        "ownership_model": ("resident: named buffers summed per phase (unchanged first-planner rows)" if mode == "resident" else
                            "each device buffer is ONE capacity counted ONCE, live or pooled; an oversize take_min reuse transfers the pooled capacity to the new owner; no_reuse_bound_bytes is the additive count with reuse disabled"),
        "assumptions": [
            f"Mode {mode}: " + {
                "resident": "one successful resident dev_commit_zk_from call, no CPU fallback.",
                "chunked": "one chunked commitment; no rows*nn buffer is allocated and the opening re-encodes from retained data/pads/powers.",
                "fallback": "a resident attempt refused at the encoded (rows*nn) take, its buffers RELEASED TO THE POOL (not freed), then a chunked retry served from them by take_min.",
            }[mode],
            "drop(coef) and drop(coef2) retain allocations because the pool holds up to 64 buffers, not a byte budget.",
            "Twiddles counted once here, assuming cold setup or already matching tables. If different-max tables are replaced, count the old tables separately in prior_live_bytes for the replacement transient.",
            "Prior buffers are additive and assumed not reusable; that can overcount actual reuse.",
            "Component budget is an explicitly assigned total allowance, not a measured free-VRAM reading.",
            "The OPENING (columns_chunked_zk) is not in this component: it takes the same coef/coef2/enc scratch again via take_min plus raw index and gather-output buffers.",
        ],
        "unaccounted": [
            "Other simultaneous W/A/H commitments unless explicitly supplied as prior_live_bytes.",
            "Helper generation, reserved zero-check tables, matmul/sumcheck/opening workspaces.",
            "CUDA context, loaded kernels, driver allocations, local-memory spills, fragmentation and display usage.",
            "Host witness/export tensors, staging buffers, temporary encodings, serialized proofs and allocator overhead.",
            "Helper/zero-check overlap and any pending attention/FFN state are counted SEPARATELY and are not in this component; see ZK60_CLAUDE_PENDING_GPU.md.",
            "A chunk-only count is NOT a fallback bound and NOT a whole-prover bound: the fallback mode holds the released resident pair as well.",
        ],
    }
    if sim is not None:
        report["pool_simulation"] = {k: v for k, v in sim.items() if k != "events"}
        report["pool_simulation"]["inventory"] = [f"{label}:{cap}" for cap, label in inventory]
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    shape = parser.add_mutually_exclusive_group(required=True)
    shape.add_argument("--rows", type=int)
    shape.add_argument("--p3-weights", type=int, nargs=2, metavar=("D", "F"))
    parser.add_argument("--log-cols", type=int, default=14)
    parser.add_argument("--inv-rate", type=int, default=4)
    parser.add_argument("--checks", type=int, default=256)
    parser.add_argument("--q-pad", type=int)
    parser.add_argument("--ntt-max-log", type=int)
    parser.add_argument("--prior-live-mib", type=int, default=0)
    parser.add_argument("--prior-pool-mib", type=int, default=0)
    parser.add_argument("--component-budget-mib", type=int)
    parser.add_argument("--mode", choices=("resident", "chunked", "fallback"), default="resident")
    parser.add_argument("--chunk-rows", type=int, default=128)
    parser.add_argument("--pool-state", choices=POOL_STATES, default="cold")
    parser.add_argument("--pool-inventory-bytes", help="comma-separated explicit pooled capacities in bytes (chunked/fallback)")
    args = parser.parse_args(argv)
    try:
        weights = weight_shape(*args.p3_weights, args.log_cols) if args.p3_weights else None
        inventory = None
        if args.pool_inventory_bytes:
            inventory = [int(x) for x in args.pool_inventory_bytes.split(",") if x.strip()]
        report = commitment_plan(
            weights["rows"] if weights else args.rows,
            weights["log_cols"] if weights else args.log_cols,
            args.inv_rate, args.checks, args.q_pad, args.ntt_max_log,
            args.prior_live_mib * MIB, args.prior_pool_mib * MIB,
            None if args.component_budget_mib is None else args.component_budget_mib * MIB,
            mode=args.mode, chunk_rows=args.chunk_rows, pool_state=args.pool_state,
            pool_inventory_bytes=inventory)
        report["p3_weight_layout"] = weights
    except ValueError as error:
        parser.exit(2, f"memory plan: {error}\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
