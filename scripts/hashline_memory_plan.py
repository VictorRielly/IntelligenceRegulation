#!/usr/bin/env python3
"""Count the current resident GPU hiding-commit buffers, without using a GPU.

Examples:
  python3 scripts/hashline_memory_plan.py --p3-weights 4096 14336
  python3 scripts/hashline_memory_plan.py --rows 3033 --log-cols 14

This is allocation accounting for ONE dev_commit_zk_from call, not a whole
prover bound or permission to run a model. All byte counts are modelled,
not measured. Prior live/pool storage and a component budget are explicit.
No tensors, datasets, drivers or devices are opened or allocated.
"""

import argparse
import json


MIB = 1024 ** 2
SOURCES = {
    "layout": "hashline/src/zk.rs::ZkLayoutV3::new",
    "allocation": "hashline/src/gpu/cuda.rs::dev_commit_zk_from",
    "pool": "hashline/src/gpu/cuda.rs::pool_put / Pooled::drop",
    "twiddles": "hashline/src/gpu/cuda.rs::Gpu::ensure_twiddles",
    "hash": "hashline/src/gpu/cuda.rs::Gpu::hash_cols",
    "host": "hashline/src/pcs.rs::commit_zk_owned / commit_zk_device",
}


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


def commitment_plan(rows, log_cols=14, inv_rate=4, checks=256, q_pad=None,
                    ntt_max_log=None, prior_live_bytes=0, prior_pool_bytes=0,
                    component_budget_bytes=None, mode="resident", chunk_rows=128,
                    pool_state="cold"):
    """[ZK60-CL3] `mode` selects which code path is counted.

    resident  the original path: both full rows*nn buffers. Default, and its
              rows are UNCHANGED from before this extension.
    chunked   CL1's path: no full rows*nn buffer is ever allocated.
    fallback  the resident attempt that gets partway and then retries chunked.
              This is the one the old planner could not express, and it is the
              interesting case: the resident buffers that DID allocate are
              released to the pool, not freed, and take_min then reuses them as
              chunk scratch. So held capacity stays high while newly REQUESTED
              scratch is small — the distinction CL3 asks to be made explicit.

    `pool_state="warm"` says equivalent buffers are already pooled, so the path
    needs no NEW capacity; held bytes are unchanged. Cold vs warm changes what
    is allocated, never what is occupied.
    """
    if mode not in ("resident", "chunked", "fallback"):
        raise ValueError("mode must be resident, chunked or fallback")
    if pool_state not in ("cold", "warm"):
        raise ValueError("pool_state must be cold or warm")
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

    data, encoded, pads, powers = rows * n * 8, rows * nn * 8, rows * q * 8, nn * 8
    leaves = nn * 32
    buffers = {"systematic_data": data, "inverse_coefficients": data,
               "pads": pads, "coset_powers": powers,
               "expanded_coefficients": encoded, "encoded_matrix": encoded,
               "device_leaf_hashes": leaves}
    # ntt_rows writes into the supplied destination and uses no additional
    # device-global scratch. Kernel local/shared memory is NOT counted here.
    phases = [
        ("inverse NTT", ["systematic_data", "inverse_coefficients"], []),
        ("pad and coset scale", ["systematic_data", "inverse_coefficients", "pads", "coset_powers", "expanded_coefficients"], []),
        ("forward NTT", ["systematic_data", "pads", "coset_powers", "expanded_coefficients", "encoded_matrix"], ["inverse_coefficients"]),
        ("column hashes", ["systematic_data", "pads", "coset_powers", "encoded_matrix", "device_leaf_hashes"], ["inverse_coefficients", "expanded_coefficients"]),
        ("return commitment", ["systematic_data", "encoded_matrix"], ["inverse_coefficients", "expanded_coefficients"]),
    ]

    # [ZK60-CL3] the non-resident paths. B3_STATE_SLOTS mirrors gpu/cuda.rs.
    b3_slots = 8 * 24 + 1
    # [ZK60-CL4 review] mirror the DEVICE plan: chunk_rows() clamps to >= 128
    # and chunk_plan uses step = (chunk // 128) * 128, so a too-small or
    # unrounded chunk count here would undercount the scratch.
    _cr = max(128, integer("chunk_rows", chunk_rows, 1))
    _step = max(1, _cr // 128) * 128
    rmax = min(rows, _step)
    chunk_coef, chunk_enc = rmax * n * 8, rmax * nn * 8
    state_bytes = b3_slots * nn * 4
    if mode in ("chunked", "fallback"):
        buffers = dict(buffers)
        buffers.update({"chunk_coefficients": chunk_coef,
                        "chunk_expanded": chunk_enc, "chunk_encoded": chunk_enc,
                        "blake3_column_state": state_bytes})
        chunk_live = ["systematic_data", "pads", "coset_powers", "chunk_coefficients",
                      "chunk_expanded", "chunk_encoded", "blake3_column_state"]
        if mode == "chunked":
            phases = [
                ("upload", ["systematic_data", "pads", "coset_powers"], []),
                ("chunk loop", chunk_live, []),
                ("leaves", chunk_live + ["device_leaf_hashes"], []),
                ("return commitment", ["systematic_data", "pads", "coset_powers", "device_leaf_hashes"], []),
            ]
        else:
            # The resident pair allocated, the third take refused, the pair
            # RELEASED to the pool, then the chunked retry reusing it.
            phases = [
                ("resident attempt: inverse NTT", ["systematic_data", "inverse_coefficients"], []),
                ("resident attempt: pad and coset scale",
                 ["systematic_data", "inverse_coefficients", "pads", "coset_powers", "expanded_coefficients"], []),
                ("encoded buffer REFUSED; release to pool",
                 ["systematic_data", "pads", "coset_powers"], ["inverse_coefficients", "expanded_coefficients"]),
                ("chunked retry loop", chunk_live, ["inverse_coefficients", "expanded_coefficients"]),
                ("leaves", chunk_live + ["device_leaf_hashes"], ["inverse_coefficients", "expanded_coefficients"]),
                ("return commitment", ["systematic_data", "pads", "coset_powers", "device_leaf_hashes"],
                 ["inverse_coefficients", "expanded_coefficients"]),
            ]

    stages = []
    for label, active, pooled in phases:
        live = sum(buffers[key] for key in active)
        pool = sum(buffers[key] for key in pooled)
        stages.append({"stage": label, "live_buffers": active, "pooled_buffers": pooled,
                       "live_bytes": live, "retained_pool_bytes": pool,
                       "accounted_device_bytes": live + pool})
    twiddles = 2 * ((1 << ml) - 1) * 8
    component_peak = max(row["accounted_device_bytes"] for row in stages) + twiddles
    subtotal = component_peak + prior_live_bytes + prior_pool_bytes
    return {
        "schema": 1, "scope": f"one hiding commitment on the {mode} path; code-derived buffer accounting",
        "mode": mode, "pool_state": pool_state,
        "chunk_rows": rmax if mode in ("chunked", "fallback") else None,
        # [ZK60-CL3] held vs newly requested. On a warm pool the path occupies
        # the same bytes but allocates none of them; conflating the two is how
        # a "chunk-only count" gets mistaken for a whole-prover bound.
        # [ZK60-CL4 review] The earlier "warm => 0 new bytes" was WRONG: pads,
        # coset powers and the leaf buffer are RAW allocations
        # (htod_sync_copy / alloc::<u32>), never pooled, so they are paid on
        # every call whatever the pool holds. Only the poolable scratch can be
        # reused. Confirmed against the device counters, which report 2 raw
        # allocations on a forced-chunk commitment.
        "raw_non_poolable_bytes": pads + powers + leaves,
        "newly_allocated_capacity_bytes": (pads + powers + leaves) if pool_state == "warm" else max(
            row["accounted_device_bytes"] for row in stages),
        "measured": False, "safe_to_run": False, "sources": SOURCES,
        "shape": {"rows": rows, "log_cols": log_cols, "columns": n,
                  "encoded_columns": nn, "inv_rate": inv_rate, "checks": checks,
                  "q_pad": q, "ntt_max_log": ml},
        "buffers_bytes": buffers, "stages": stages, "twiddle_bytes": twiddles,
        # [ZK60-CL4 review] these were resident-only. A chunked commitment
        # returns NO encoded matrix (enc is None) and instead RETAINS pads and
        # powers for its deferred opening.
        "commitment_live_after_return_bytes": (data + encoded) if mode == "resident" else (data + pads + powers),
        "new_pool_bytes_after_return": (data + encoded) if mode == "resident" else 0,
        "component_peak_accounted_bytes": component_peak,
        "prior_live_bytes": prior_live_bytes, "prior_pool_bytes": prior_pool_bytes,
        "subtotal_accounted_bytes": subtotal, "subtotal_accounted_mib": subtotal / MIB,
        "component_budget_bytes": component_budget_bytes,
        "exceeds_component_budget": None if component_budget_bytes is None else subtotal > component_budget_bytes,
        "host_retained_payload_bytes": {"systematic_data": data, "pads": pads,
                                        "salts": leaves, "merkle_tree": (2 * nn - 1) * 32},
        "assumptions": [
            f"Mode {mode}: " + {
                "resident": "one successful resident dev_commit_zk_from call, no CPU fallback.",
                "chunked": "one chunked commitment; no rows*nn buffer is allocated and the opening re-encodes from retained data/pads/powers.",
                "fallback": "a resident attempt refused partway, its buffers RELEASED TO THE POOL (not freed), then a chunked retry on top of them.",
            }[mode],
            "Cold empty pool for the component; drop(coef) and drop(coef2) retain allocations because the pool holds up to 64 buffers, not a byte budget.",
            "Twiddles counted once here, assuming cold setup or already matching tables. If different-max tables are replaced, count the old tables separately in prior_live_bytes for the replacement transient.",
            "Prior buffers are additive and assumed not reusable; that can overcount actual reuse.",
            "Component budget is an explicitly assigned total allowance, not a measured free-VRAM reading.",
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
    parser.add_argument("--mode", choices=("resident","chunked","fallback"), default="resident")
    parser.add_argument("--chunk-rows", type=int, default=128)
    parser.add_argument("--pool-state", choices=("cold","warm"), default="cold")
    args = parser.parse_args(argv)
    try:
        weights = weight_shape(*args.p3_weights, args.log_cols) if args.p3_weights else None
        report = commitment_plan(
            weights["rows"] if weights else args.rows,
            weights["log_cols"] if weights else args.log_cols,
            args.inv_rate, args.checks, args.q_pad, args.ntt_max_log,
            args.prior_live_mib * MIB, args.prior_pool_mib * MIB,
            None if args.component_budget_mib is None else args.component_budget_mib * MIB,
            mode=args.mode, chunk_rows=args.chunk_rows, pool_state=args.pool_state)
        report["p3_weight_layout"] = weights
    except ValueError as error:
        parser.exit(2, f"memory plan: {error}\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
