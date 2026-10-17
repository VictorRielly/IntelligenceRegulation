#!/usr/bin/env python3
"""Exact parameter counts from the pinned TinyLlama safetensors header.

Reads only the 8-byte length prefix and the JSON header (no tensor payload).
Checks the header bytes against the SHA-256 recorded by the importer
inventory, then counts every tensor's elements from its declared shape and
cross-checks shape x 2 bytes (BF16) against the declared data offsets.

Output: param_count.json next to this script.
"""
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
CKPT = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1")
INVENTORY = REPO / "results/zk60_1b_checkpoint_20260927/inventory_20260929.json"
PROVIDER = REPO / "results/zk60_1b_checkpoint_20260927/provider_metadata.json"
LAYER = re.compile(r"model\.layers\.(\d+)\.(.+)\Z")


def main():
    inv = json.loads(INVENTORY.read_text())
    provider = json.loads(PROVIDER.read_text())
    path = CKPT / "model.safetensors"
    size = path.stat().st_size
    with path.open("rb") as fh:
        hlen = struct.unpack("<Q", fh.read(8))[0]
        header_bytes = fh.read(hlen)
    header_sha = hashlib.sha256(header_bytes).hexdigest()
    if header_sha != inv["header_sha256"]["model.safetensors"]:
        raise SystemExit(f"header sha256 {header_sha} differs from inventory pin")
    header = json.loads(header_bytes)
    header.pop("__metadata__", None)

    total = 0
    payload = 0
    dtypes = set()
    per_layer = {}
    per_role = {}
    outside = {}
    for name, entry in header.items():
        n = 1
        for dim in entry["shape"]:
            n *= dim
        start, end = entry["data_offsets"]
        if entry["dtype"] != "BF16" or end - start != 2 * n:
            raise SystemExit(f"{name}: dtype/offset mismatch")
        dtypes.add(entry["dtype"])
        total += n
        payload += end - start
        m = LAYER.fullmatch(name)
        if m:
            layer, role = int(m.group(1)), m.group(2)
            per_layer[layer] = per_layer.get(layer, 0) + n
            per_role.setdefault(role, {"shape": entry["shape"], "params_per_layer": n, "layers": 0})
            if per_role[role]["shape"] != entry["shape"]:
                raise SystemExit(f"{name}: shape differs across layers")
            per_role[role]["layers"] += 1
        else:
            outside[name] = {"shape": entry["shape"], "params": n}

    layers = sorted(per_layer)
    if layers != list(range(22)) or len(set(per_layer.values())) != 1:
        raise SystemExit("expected 22 identical blocks")
    stack = sum(per_layer.values())
    norm_roles = [r for r in per_role if r.endswith("layernorm.weight")]
    stack_norms = sum(per_role[r]["params_per_layer"] * per_role[r]["layers"] for r in norm_roles)
    out = {
        "source": str(path),
        "file_bytes": size,
        "header_length_bytes": hlen,
        "header_sha256": header_sha,
        "header_sha256_matches_inventory": True,
        "tensor_count": len(header),
        "dtypes": sorted(dtypes),
        "total_parameters": total,
        "payload_bytes": payload,
        "payload_bytes_matches_inventory": payload == inv["payload_bytes"],
        "file_bytes_check": size == 8 + hlen + payload,
        "provider_safetensors_total": provider["safetensors"]["total"],
        "provider_matches": total == provider["safetensors"]["total"],
        "outside_stack": outside,
        "outside_stack_parameters": sum(v["params"] for v in outside.values()),
        "blocks": len(layers),
        "tensors_per_block": len(per_role),
        "per_block_parameters": per_layer[0],
        "per_block_bf16_bytes": 2 * per_layer[0],
        "per_block_roles": per_role,
        "proved_stack_parameters": stack,
        "proved_stack_bf16_bytes": 2 * stack,
        "proved_stack_norm_weight_parameters": stack_norms,
        "proved_stack_matrix_parameters": stack - stack_norms,
        "proved_stack_fraction_of_total": stack / total,
    }
    (HERE / "param_count.json").write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: out[k] for k in (
        "tensor_count", "total_parameters", "payload_bytes", "provider_matches",
        "payload_bytes_matches_inventory", "file_bytes_check", "outside_stack_parameters",
        "per_block_parameters", "proved_stack_parameters", "proved_stack_matrix_parameters",
        "proved_stack_norm_weight_parameters", "proved_stack_fraction_of_total")}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
