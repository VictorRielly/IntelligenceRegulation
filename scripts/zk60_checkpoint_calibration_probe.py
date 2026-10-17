#!/usr/bin/env python3
"""Inspect real trained BF16 weights with bounded, pin-checked reads.

Reports quantization candidates and fixed-kernel norm compatibility hypotheses.
It does not export a calibrated model, evaluate hidden activations, or prove it.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import time

import numpy as np

from zk60_1b_checkpoint import Checkpoint

REPO = Path(__file__).resolve().parents[1]


def constants():
    source = REPO / "ops/zkp-mvp/candidate/private-block-kernel-shaped/src/lib.rs"
    data = source.read_text()
    values = {key: int(re.search(rf"pub const {key}: [^=]+ = ([0-9]+);", data)[1])
              for key in ("NORM_TN", "NORM_CN", "NORM_CEPS")}
    values["source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
    return values


def inspect(checkpoint: Checkpoint, kernel: dict) -> dict:
    geometry = checkpoint.config
    # Hypothesis only: a unit-scale normalized output. A real exporter must
    # choose and bind its own scales, epsilon and gamma handling per layer.
    factor = 2 ** kernel["NORM_TN"] / kernel["NORM_CN"] * math.sqrt(geometry["hidden_size"])
    tensors = []
    for name, ref in sorted(checkpoint.refs.items()):
        count, min_value, max_value, max_abs, sum_abs, gain_overflow = 0, math.inf, -math.inf, 0.0, 0.0, 0
        is_gain = name.endswith("layernorm.weight") or name == "model.norm.weight"
        for tile in ref.iter_tiles(1024 * 1024):
            words = np.frombuffer(tile, dtype="<u2").astype(np.uint32)
            values = (words << 16).view(np.float32)
            if not np.isfinite(values).all():
                raise ValueError(f"{name}: nonfinite trained tensor value")
            count += values.size
            min_value = min(min_value, float(values.min()))
            max_value = max(max_value, float(values.max()))
            absolute = np.abs(values)
            max_abs = max(max_abs, float(absolute.max()))
            sum_abs += float(absolute.sum(dtype=np.float64))
            if is_gain:
                candidates = np.rint(values.astype(np.float64) * factor)
                gain_overflow += int(np.count_nonzero((candidates < -128) | (candidates > 127)))
        exponent = math.ceil(math.log2(max_abs / 127)) if max_abs else 0
        row = {"name": name, "shape": ref.shape, "elements": count, "sha256": ref.sha256,
               "min": min_value, "max": max_value, "max_absolute": max_abs,
               "mean_absolute": sum_abs / count,
               "symmetric_int8_weight_candidate_exponent": exponent,
               "candidate_rule": "round(weight / 2^exponent), abs rounded <=127; not a native calibration"}
        if is_gain:
            row.update(unit_scale_direct_native_gain_factor=factor,
                       unit_scale_direct_native_gain_int8_overflows=gain_overflow,
                       norm_gain_result_is_conditional_on_output_scale=True)
        tensors.append(row)
    return {"tensors": tensors, "direct_unit_scale_gain_overflows": sum(row.get("unit_scale_direct_native_gain_int8_overflows", 0) for row in tensors)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkpoint", type=Path)
    parser.add_argument("--source-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    started = time.monotonic()
    source = json.loads(args.source_manifest.read_text())
    if source["state"] != "raw-checkpoint-verified":
        raise ValueError("raw checkpoint must be completely downloaded and source verified")
    pins = {name: row["sha256"] for name, row in source["files"].items() if name.endswith(".safetensors")}
    checkpoint = Checkpoint(args.checkpoint, pins)
    if checkpoint.identity["config_sha256"] != source["files"]["config.json"]["sha256"]:
        raise ValueError("checkpoint config changed since source verification")
    kernel = constants()
    inventory = inspect(checkpoint, kernel)
    geometry = checkpoint.config
    record = {"schema": "zk60-trained-calibration-readiness/1", "model": source["model"],
              "revision": source["revision"], "checkpoint_parameter_count": source["parameter_count"],
              "proved_parameter_count": 0, "proof_ready": False, "proof_produced": False,
              "geometry": geometry, "kernel_constants": kernel,
              "normalized_output_scale_hypothesis": 1,
              "integer_input_scale_that_would_match_epsilon_without_rounding": math.sqrt(kernel["NORM_CEPS"] / (geometry["hidden_size"] * geometry["rms_norm_eps"])),
              "epsilon_result_note": "This real-valued input scale alone does not establish an admitted integer or power-of-two calibration.",
              "remaining": ["per-layer scales and RMS epsilon", "RoPE/softmax/SiLU tables", "held-out range and quality checks",
                            "native integer-kernel parity", "trained model/profile/transcript binding", "trained block and stack proof", "privacy/soundness review"],
              "peak_tensor_tile_bytes": 1024 * 1024, "elapsed_seconds": time.monotonic() - started,
              "source_manifest_sha256": hashlib.sha256(args.source_manifest.read_bytes()).hexdigest(),
              **inventory}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({key: value for key, value in record.items() if key != "tensors"}, indent=2))


if __name__ == "__main__":
    main()
