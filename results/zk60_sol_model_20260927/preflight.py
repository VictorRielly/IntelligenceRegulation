#!/usr/bin/env python3
"""Metadata-only trained-model handoff preflight; never reads tensor payloads.

Checks the Mistral v3 FFN export against its config, sidecar, checkpoint index,
and stat sizes. This is an inventory gate, not a proof or a calibration verdict.
"""
import argparse
import json
from pathlib import Path

DTYPE_BYTES = {"int8": 1, "<i2": 2}
FFN_KEYS = ("X", "WgT", "WuT", "WdT", "a16", "u16", "h16", "z16")


def inspect(config: dict, manifest: dict, sidecar: str, export_dir: Path,
            checkpoint_index: dict) -> dict:
    dims = manifest["dims"]
    t, d, f, layers = (dims[k] for k in ("t", "d", "f", "layers"))
    shape = manifest["shapes"]
    expected_shapes = {"X": [t, d], "WgT": [d, f], "WuT": [d, f],
                       "WdT": [f, d], "a16": [t, f], "u16": [t, f],
                       "h16": [t, f], "z16": [t, d]}
    errors = []
    if manifest.get("profile") != "v3-widened" or manifest.get("requant") != "round":
        errors.append("requires v3-widened round-requant export")
    if (d, f, layers) != (config["hidden_size"], config["intermediate_size"],
                          config["num_hidden_layers"]):
        errors.append("export dimensions disagree with checkpoint config")
    if shape != expected_shapes:
        errors.append("export tensor shapes disagree with declared dimensions")
    if len(manifest["layers"]) != layers:
        errors.append("export layer count disagrees with dimensions")
    if checkpoint_index.get("metadata", {}).get("total_size", 0) <= 0:
        errors.append("checkpoint index has no total_size")
    if set(manifest.get("checkpoint_sha256", {})) != set(checkpoint_index.get("weight_map", {}).values()):
        errors.append("checkpoint shard identities disagree with index")
    lines = set(sidecar.splitlines())
    if f"00 dims {t} {d} {f} {layers}" not in lines or "00 profile v3-widened" not in lines:
        errors.append("sidecar dimensions or profile disagree with manifest")
    files_checked = missing = bad_size = 0
    bytes_per_layer = sum(expected_shapes[k][0] * expected_shapes[k][1] *
                          DTYPE_BYTES[manifest["dtypes"][k]] for k in FFN_KEYS)
    seen = set()
    for i, layer in enumerate(manifest["layers"]):
        if layer.get("layer") != i:
            errors.append(f"layer index mismatch at {i}")
        for key in FFN_KEYS:
            rel = layer.get("files", {}).get(key)
            digest = layer.get("digests", {}).get(key)
            if not rel or Path(rel).name != rel or rel in seen:
                errors.append(f"unsafe, absent or duplicate filename: layer {i} {key}")
                continue
            seen.add(rel)
            if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
                errors.append(f"invalid digest syntax: layer {i} {key}")
            if f"{i:02d} {key} {digest}" not in lines:
                errors.append(f"sidecar digest mismatch: layer {i} {key}")
            path = export_dir / rel
            files_checked += 1
            if not path.is_file():
                missing += 1
            elif path.stat().st_size != expected_shapes[key][0] * expected_shapes[key][1] * DTYPE_BYTES[manifest["dtypes"][key]]:
                bad_size += 1
    if missing:
        errors.append(f"{missing} export tensor files missing")
    if bad_size:
        errors.append(f"{bad_size} export tensor files have wrong byte length")
    if manifest.get("range_violations") != 0 or manifest.get("a16_clamp_hits") != 0:
        errors.append("export records violations or clamps")
    return {"ready_for_ffn_tensor_loading": not errors, "errors": errors,
            "dims": dims, "files_checked": files_checked, "files_missing": missing,
            "files_wrong_size": bad_size, "ffn_bytes_per_layer": bytes_per_layer,
            "ffn_bytes_all_layers": bytes_per_layer * layers,
            "checkpoint_index_total_bytes": checkpoint_index["metadata"]["total_size"]}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--sidecar", type=Path, required=True)
    ap.add_argument("--checkpoint-index", type=Path, required=True)
    args = ap.parse_args()
    result = inspect(json.loads(args.config.read_text()), json.loads(args.manifest.read_text()),
                     args.sidecar.read_text(), args.manifest.parent,
                     json.loads(args.checkpoint_index.read_text()))
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["ready_for_ffn_tensor_loading"] else 2)


if __name__ == "__main__":
    main()
