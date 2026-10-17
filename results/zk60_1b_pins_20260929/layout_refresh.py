#!/usr/bin/env python3
"""Refresh the TinyLlama T32..T512 layout ladder against header-derived geometry.

Inputs (read-only):
  - param_count.json (this directory): geometry and byte counts from the
    pinned safetensors header, via param_count.py.
  - /home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/config.json (heads).
  - results/zk60_1b_model_20260927/layout_probe.log and layout_account.py:
    the Sol model lane's allocation-free Rust probe output and its counter.
  - results/zk60_1b_model_20260927/layout_ladder.json: its stored counts.

Checks that every probe line uses the checkpoint's real geometry, that the
counter's checkpoint constants equal the header's byte counts, and that the
counter reproduces the stored ladder exactly. Then derives per-route host
and device payload floors (computed bytes, not measured RSS/VRAM) and
writes layout_refresh.json / layout_refresh.csv here. Exit 0 only if all
checks pass.
"""
import csv
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MODEL = REPO / "results/zk60_1b_model_20260927"
CONFIG = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/config.json")
HOST_RAM = 16_140_456 * 1024      # /proc/meminfo MemTotal, 2026-09-30T00:10Z
VRAM = 8_188 * 1024 * 1024        # RTX 4070 Laptop, ZK60_1B_CHECKPOINT.md
Q, RATE = 256, 4                  # as in layout_account.py


def load(path, name):
    sys.dont_write_bytecode = True  # never write __pycache__ outside this lane
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    pc = json.loads((HERE / "param_count.json").read_text())
    cfg = json.loads(CONFIG.read_text())
    roles = pc["per_block_roles"]
    d = roles["self_attn.q_proj.weight"]["shape"][0]
    kv_width = roles["self_attn.k_proj.weight"]["shape"][0]
    f = roles["mlp.gate_proj.weight"]["shape"][0]
    heads, kv_heads = cfg["num_attention_heads"], cfg["num_key_value_heads"]
    dh = d // heads
    geometry = {"d": d, "f": f, "Hheads": heads, "KV": kv_heads, "dh": dh}
    checks = {
        "header_q_is_square": roles["self_attn.q_proj.weight"]["shape"] == [d, d],
        "header_o_is_square": roles["self_attn.o_proj.weight"]["shape"] == [d, d],
        "header_kv_width_eq_KV_x_dh": kv_width == kv_heads * dh,
        "header_down_is_d_by_f": roles["mlp.down_proj.weight"]["shape"] == [d, f],
        "header_blocks_eq_config_layers": pc["blocks"] == cfg["num_hidden_layers"],
    }

    acct = load(MODEL / "layout_account.py", "zk60_layout_account")
    checks["counter_checkpoint_payload_eq_header"] = acct.CHECKPOINT_PAYLOAD == pc["payload_bytes"]
    checks["counter_one_layer_bf16_eq_header"] = acct.ONE_LAYER_BF16 == pc["per_block_bf16_bytes"]
    checks["counter_Q_RATE_as_assumed"] = (acct.Q, acct.RATE) == (Q, RATE)
    log_text = (MODEL / "layout_probe.log").read_text()
    cases, domains, refused = acct.parse(log_text)
    probe_geom = {}
    for line in log_text.splitlines():
        if line.startswith("PROBE ") and "REFUSED" not in line:
            _, name, *rest = line.split()
            kv = dict(s.split("=", 1) for s in rest)
            probe_geom[name] = {k: int(kv[k]) for k in geometry}
    checks["every_probe_uses_header_geometry"] = all(g == geometry for g in probe_geom.values())
    stored = json.loads((MODEL / "layout_ladder.json").read_text())
    recount = {name: acct.count(c, domains[name]) for name, c in cases.items()}
    checks["counter_reproduces_stored_ladder"] = recount == stored["cases"]
    checks["refusal_unchanged"] = refused == stored["refused"]

    layer_bf16 = pc["per_block_bf16_bytes"]
    stack_bf16 = pc["proved_stack_bf16_bytes"]
    rows = []
    for name, r in recount.items():
        c = cases[name]
        n, nn = c["cols"], c["cols"] * RATE
        raw_a, raw_h = r["A_raw_bytes"], r["H_raw_bytes"]
        tree_one = nn * 32 + (2 * nn - 1) * 32
        a_committed_host = raw_a + r["A_encoded_bytes"] + c["A"] * Q * 8 + tree_one
        pre_h_work = raw_h + r["witness_A_plane_i64_bytes"] + r["looked_i64_bytes"] + r["exp_delta_and_act_index_i64_bytes"]
        bnd2 = 2 * r["one_internal_boundary_materialized_bytes"]
        # CPU materialized route, H-construction phase: committed A, M, two
        # boundaries, H raw, witness, looked, deltas/indices, one BF16 layer.
        cpu_pre_h = a_committed_host + r["M_encoded_bytes"] + bnd2 + pre_h_work + layer_bf16
        cpu_slots = r["cpu_materialized_A_H_M_two_boundaries_floor_bytes"]
        cpu_host = max(cpu_pre_h, cpu_slots)
        # GPU chunked route: host keeps raw rows, pads, salts, tree; device keeps
        # raw rows, pads, coset powers plus one chunk-128 scratch set.
        gpu_host_pre_h = r["host_pre_H_plus_one_layer_BF16_floor_bytes"]
        gpu_host_retained = r["A_H_host_streamed_bytes"]
        gpu_device = r["gpu_streamed_A_H_plus_full_scratch_floor_bytes"]
        gpu_device_compact = r["gpu_streamed_A_H_plus_compact_scratch_floor_bytes"]
        rows.append({
            "name": name, "T": r["T"], "log_cols": r["log_cols"],
            "A_rows": r["A_rows"], "H_rows": r["H_rows"],
            "receipt_bytes_per_block_counted": r["receipt_bytes_per_block_counted"],
            "receipt_bytes_22_blocks_counted": 22 * r["receipt_bytes_per_block_counted"],
            "cpu_route_host_pre_H_phase_floor_bytes": cpu_pre_h,
            "cpu_route_host_slots_phase_floor_bytes": cpu_slots,
            "cpu_route_host_floor_bytes": cpu_host,
            "gpu_route_host_pre_H_floor_bytes": gpu_host_pre_h,
            "gpu_route_host_retained_A_H_bytes": gpu_host_retained,
            "gpu_route_device_A_H_plus_full_scratch_bytes": gpu_device,
            "gpu_route_device_A_H_plus_compact_scratch_bytes": gpu_device_compact,
            "witness_plus_looked_plus_deltas_bytes": r["witness_A_plane_i64_bytes"] + r["looked_i64_bytes"] + r["exp_delta_and_act_index_i64_bytes"],
            "weights_one_layer_bf16_bytes": layer_bf16,
            "weights_proved_stack_bf16_bytes": stack_bf16,
            "cpu_route_host_exceeds_ram": cpu_host > HOST_RAM,
            "gpu_route_host_exceeds_ram": gpu_host_pre_h > HOST_RAM,
            "gpu_route_device_exceeds_vram": gpu_device > VRAM,
        })

    ok = all(checks.values())
    out = {"geometry_from_header": geometry, "kv_width": kv_width,
           "host_ram_bytes": HOST_RAM, "vram_bytes": VRAM,
           "inputs_sha256": {p: hashlib.sha256((MODEL / p).read_bytes()).hexdigest()
                             for p in ("layout_probe.log", "layout_account.py", "layout_ladder.json")},
           "checks": checks, "all_checks_pass": ok,
           "refused": refused, "rows": rows}
    (HERE / "layout_refresh.json").write_text(json.dumps(out, indent=2) + "\n")
    with (HERE / "layout_refresh.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    gib = lambda b: f"{b / 2**30:.2f}"
    print(json.dumps(checks, indent=2))
    print("T lc | receipt/block MiB | CPU host pre-H / slots GiB | GPU host pre-H / retained GiB | GPU device GiB")
    for x in rows:
        print(x["T"], x["log_cols"], "|", f"{x['receipt_bytes_per_block_counted'] / 2**20:.1f}", "|",
              gib(x["cpu_route_host_pre_H_phase_floor_bytes"]), gib(x["cpu_route_host_slots_phase_floor_bytes"]), "|",
              gib(x["gpu_route_host_pre_H_floor_bytes"]), gib(x["gpu_route_host_retained_A_H_bytes"]), "|",
              gib(x["gpu_route_device_A_H_plus_full_scratch_bytes"]), gib(x["gpu_route_device_A_H_plus_compact_scratch_bytes"]))
    print("refused", refused)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
