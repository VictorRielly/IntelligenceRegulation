#!/usr/bin/env python3
"""Bounded tile reads through the checkpoint importer against recorded digests.

Uses the importer's own header parser (`_shard`) and `TensorRef.read_tile`,
with each tensor's SHA-256 taken from the recorded inventory
(`inventory_20260929.json`), not recomputed. `read_tile` streams the whole
tensor through SHA-256 and refuses the tile unless it matches that record.

Positive reads: one row of layer 0 `self_attn.q_proj.weight` and one row of
layer 21 `mlp.down_proj.weight`. Each tile is also compared with a direct
seek/read of the same file bytes and decoded from BF16 for a sanity summary.

Negative controls (each must raise ValueError): wrong recorded digest,
tile past the tensor end, tile above the byte bound, odd (non-element)
offset.

Output: tile_read_check.json next to this script. Exit 0 only if all pass.
"""
import hashlib
import importlib.util
import json
import math
import struct
import sys
from dataclasses import replace
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
IMPORTER = REPO / "results/zk60_1b_checkpoint_20260927/importer_zk60_1b_checkpoint.py"
INVENTORY = REPO / "results/zk60_1b_checkpoint_20260927/inventory_20260929.json"
SHARD = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/model.safetensors")

CASES = [
    # (tensor, row index); the tile is exactly one full row.
    ("model.layers.0.self_attn.q_proj.weight", 1000),
    ("model.layers.21.mlp.down_proj.weight", 2047),
]


def load_importer():
    sys.dont_write_bytecode = True  # never write __pycache__ outside this lane
    spec = importlib.util.spec_from_file_location("importer_zk60_1b_checkpoint", IMPORTER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def bf16_summary(tile: bytes) -> dict:
    words = struct.unpack(f"<{len(tile) // 2}H", tile)
    vals = [struct.unpack("<f", struct.pack("<I", w << 16))[0] for w in words]
    finite = [v for v in vals if math.isfinite(v)]
    return {"elements": len(vals), "finite": len(finite),
            "nonzero": sum(1 for v in finite if v != 0.0),
            "min": min(finite), "max": max(finite),
            "mean_abs": sum(abs(v) for v in finite) / len(finite),
            "first4": vals[:4]}


def expect_refusal(label, fn):
    try:
        fn()
    except ValueError as exc:
        return {"control": label, "refused": True, "message": str(exc)}
    return {"control": label, "refused": False, "message": "no error raised"}


def main():
    imp = load_importer()
    inv = json.loads(INVENTORY.read_text())
    refs, header_sha = imp._shard(SHARD)
    if header_sha != inv["header_sha256"]["model.safetensors"]:
        raise SystemExit("header SHA-256 differs from the inventory record")
    results, controls, ok = [], [], True
    for name, row in CASES:
        ref = replace(refs[name], sha256=inv["tensor_sha256"][name])
        cols = ref.shape[1]
        offset, length = row * cols * 2, cols * 2
        tile = ref.read_tile(offset, length)
        with SHARD.open("rb") as fh:
            fh.seek(ref.data_start + ref.start + offset)
            direct = fh.read(length)
        summary = bf16_summary(tile)
        good = (tile == direct and len(tile) == length
                and summary["finite"] == summary["elements"] and summary["nonzero"] > 0)
        ok &= good
        results.append({
            "tensor": name, "shape": list(ref.shape), "dtype": ref.dtype,
            "tensor_bytes": ref.end - ref.start,
            "file_offset_of_tensor": ref.data_start + ref.start,
            "recorded_tensor_sha256": ref.sha256,
            "tile_row": row, "tile_offset_bytes": offset, "tile_length_bytes": length,
            "tile_sha256": hashlib.sha256(tile).hexdigest(),
            "tile_equals_direct_file_read": tile == direct,
            "bf16": summary, "pass": good})

        bad = replace(ref, sha256=("0" if ref.sha256[0] != "0" else "1") + ref.sha256[1:])
        size = ref.end - ref.start
        for label, fn in (
                ("wrong recorded digest", lambda: bad.read_tile(offset, length)),
                ("tile past tensor end", lambda: ref.read_tile(size - length + 2, length)),
                ("tile above 1 MiB bound", lambda: ref.read_tile(0, 1024 * 1024 + 2)),
                ("odd element offset", lambda: ref.read_tile(1, length))):
            c = expect_refusal(label, fn)
            c["tensor"] = name
            ok &= c["refused"]
            controls.append(c)

    out = {"importer": str(IMPORTER.relative_to(REPO)),
           "importer_sha256": hashlib.sha256(IMPORTER.read_bytes()).hexdigest(),
           "inventory": str(INVENTORY.relative_to(REPO)),
           "inventory_sha256": hashlib.sha256(INVENTORY.read_bytes()).hexdigest(),
           "shard": str(SHARD), "header_sha256": header_sha,
           "reads": results, "negative_controls": controls, "all_pass": ok}
    (HERE / "tile_read_check.json").write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
