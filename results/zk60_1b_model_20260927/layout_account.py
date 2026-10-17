#!/usr/bin/env python3
"""Count source-derived per-block payloads from allocation-free Rust probe lines."""
import csv
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
Q = 256
RATE = 4
CHUNK_ROWS = 128
CHECKPOINT_PAYLOAD = 2_200_096_768
ONE_LAYER_BF16 = 44_044_288 * 2


def parse(text):
    cases, domains, refused = {}, {}, {}
    for line in text.splitlines():
        if line.startswith("PROBE "):
            _, name, *rest = line.split()
            if rest[0] in ("REFUSED", "LAYOUT_REFUSED"):
                refused[name] = " ".join(rest)
            else:
                cases[name] = {k: int(v) for k, v in (s.split("=", 1) for s in rest)}
        elif line.startswith("DOMAIN "):
            _, name, dom, *rest = line.split()
            domains.setdefault(name, {})[dom] = {
                k: int(v) for k, v in (s.split("=", 1) for s in rest)}
    if len(cases) != 14 or len(refused) != 1:
        raise ValueError(f"expected 14 layouts and one refusal; got {len(cases)}, {len(refused)}")
    if "tinyllama_t32_lc14_probe" not in refused:
        raise ValueError("expected T32/logcols14 grouped-KV lift refusal")
    return cases, domains, refused


def count(c, dom):
    n, nn, rows_a, rows_h = c["cols"], c["cols"] * RATE, c["A"], c["Hrows"]
    raw_a, raw_h = rows_a * n * 8, rows_h * n * 8
    enc_a, enc_h = raw_a * RATE, raw_h * RATE
    pads_a, pads_h = rows_a * Q * 8, rows_h * Q * 8
    salts_tree = 2 * (nn * 32 + (2 * nn - 1) * 32)
    raw_ah = raw_a + raw_h
    pads_ah = pads_a + pads_h
    host_ah_compact = raw_ah + pads_ah + salts_tree
    device_ah_compact = raw_ah + pads_ah + 2 * nn * 8  # each stores its own coset powers
    witness = sum(v["size"] * v["Aplanes"] for d, v in dom.items() if d != "Tab") * 8
    looked = c["u8_lookups"] * 8
    deltas_indices = (dom["S"]["size"] + dom["F"]["size"]) * 8
    boundary_rows = c["endpoint_rows"] + 1
    boundary_raw = boundary_rows * n * 8
    boundary_materialized = boundary_raw + boundary_raw * RATE + boundary_rows * Q * 8 + nn * 32 + (2 * nn - 1) * 32
    mask_enc = c["M"] * 4096 * 8
    chunk = min(CHUNK_ROWS, rows_h)
    state = 193 * nn * 4
    scratch_full = chunk * (n + 2 * nn) * 8 + state + nn * 32
    scratch_compact = chunk * (n + n + Q + nn) * 8 + state + nn * 32
    return {
        "T": c["T"], "log_cols": n.bit_length()-1, "cols": n, "enc_cols": nn,
        "A_rows": rows_a, "H_rows": rows_h, "endpoint_rows": c["endpoint_rows"],
        "receipt_bytes_per_block_counted": c["receipt"],
        "A_raw_bytes": raw_a, "H_raw_bytes": raw_h,
        "A_encoded_bytes": enc_a, "H_encoded_bytes": enc_h,
        "A_H_host_materialized_bytes": host_ah_compact + enc_a + enc_h,
        "A_H_host_streamed_bytes": host_ah_compact,
        "A_H_device_streamed_bytes": device_ah_compact,
        "M_encoded_bytes": mask_enc,
        "one_internal_boundary_materialized_bytes": boundary_materialized,
        "cpu_materialized_A_H_M_two_boundaries_floor_bytes": host_ah_compact + enc_a + enc_h + mask_enc + 2 * boundary_materialized,
        "host_streamed_A_H_M_two_materialized_boundaries_floor_bytes": host_ah_compact + mask_enc + 2 * boundary_materialized,
        "host_pre_H_raw_witness_looked_delta_index_floor_bytes": raw_ah + witness + looked + deltas_indices,
        "host_pre_H_plus_full_BF16_checkpoint_floor_bytes": raw_ah + witness + looked + deltas_indices + CHECKPOINT_PAYLOAD,
        "host_pre_H_plus_one_layer_BF16_floor_bytes": raw_ah + witness + looked + deltas_indices + ONE_LAYER_BF16,
        "witness_A_plane_i64_bytes": witness, "looked_i64_bytes": looked,
        "exp_delta_and_act_index_i64_bytes": deltas_indices,
        "gpu_chunk128_commit_scratch_full_pad_bytes": scratch_full,
        "gpu_chunk128_commit_scratch_compact_pad_bytes": scratch_compact,
        "gpu_streamed_A_H_plus_full_scratch_floor_bytes": device_ah_compact + scratch_full,
        "gpu_streamed_A_H_plus_compact_scratch_floor_bytes": device_ah_compact + scratch_compact,
        "checkpoint_BF16_full_payload_bytes": CHECKPOINT_PAYLOAD,
        "checkpoint_BF16_one_layer_payload_bytes": ONE_LAYER_BF16,
    }


def main():
    cases, domains, refused = parse((HERE / "layout_probe.log").read_text())
    out = {name: count(c, domains[name]) for name, c in cases.items()}
    (HERE / "layout_ladder.json").write_text(json.dumps({"cases": out, "refused": refused}, indent=2) + "\n")
    cols = list(next(iter(out.values())))
    with (HERE / "layout_ladder.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["name"] + cols)
        w.writeheader()
        for name, row in out.items():
            w.writerow({"name": name, **row})
    for name, row in out.items():
        gib = lambda key: round(row[key] / 2**30, 3)
        print(name, "cpu_mat", gib("cpu_materialized_A_H_M_two_boundaries_floor_bytes"),
              "host_streamed", gib("A_H_host_streamed_bytes"),
              "gpu_streamed+scratch", gib("gpu_streamed_A_H_plus_full_scratch_floor_bytes"),
              "host_preH+one_layer", gib("host_pre_H_plus_one_layer_BF16_floor_bytes"))
    print("refused", refused)


if __name__ == "__main__":
    main()
