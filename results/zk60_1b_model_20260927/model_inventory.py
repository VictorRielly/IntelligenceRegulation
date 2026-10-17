#!/usr/bin/env python3
"""Strict Llama/GQA config and safetensors-header inventory; never reads tensor data."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

DTYPE_BYTES = {"BF16": 2, "F32": 4}
CONFIG_DTYPE = {"bfloat16": "BF16", "float32": "F32"}
MAX_HEADER = 16 * 1024 * 1024


def expected_tensors(c: dict) -> dict[str, tuple[int, ...]]:
    d, f, h, kv, layers, vocab = (c[k] for k in (
        "hidden_size", "intermediate_size", "num_attention_heads",
        "num_key_value_heads", "num_hidden_layers", "vocab_size"))
    if c.get("model_type") != "llama" or c.get("architectures") != ["LlamaForCausalLM"]:
        raise ValueError("only LlamaForCausalLM config is supported")
    if any(not isinstance(v, int) or isinstance(v, bool) or v <= 0
           for v in (d, f, h, kv, layers, vocab)):
        raise ValueError("all model axes must be positive integers")
    if d % h or h % kv or (d // h) % 2:
        raise ValueError("invalid head dimension or GQA grouping")
    if c.get("hidden_act") != "silu" or c.get("tie_word_embeddings") is not False:
        raise ValueError("expected SwiGLU/SiLU and untied embedding/head")
    if c.get("rope_scaling") is not None or c.get("attention_bias", False):
        raise ValueError("scaled RoPE or attention bias needs a different importer")
    if c.get("rms_norm_eps") not in (1e-5, 0.00001):
        raise ValueError("unexpected RMS epsilon; new calibration required")
    if c.get("max_position_embeddings", 0) < 512:
        raise ValueError("context below the intended ladder")
    if c.get("torch_dtype") not in CONFIG_DTYPE:
        raise ValueError("unsupported checkpoint dtype")
    if c.get("rope_theta", 10000.0) != 10000.0:
        raise ValueError("nonstandard RoPE theta")
    kvw = kv * (d // h)
    out = {"model.embed_tokens.weight": (vocab, d),
           "model.norm.weight": (d,), "lm_head.weight": (vocab, d)}
    for layer in range(layers):
        p = f"model.layers.{layer}."
        out.update({
            p + "input_layernorm.weight": (d,),
            p + "post_attention_layernorm.weight": (d,),
            p + "self_attn.q_proj.weight": (d, d),
            p + "self_attn.k_proj.weight": (kvw, d),
            p + "self_attn.v_proj.weight": (kvw, d),
            p + "self_attn.o_proj.weight": (d, d),
            p + "mlp.gate_proj.weight": (f, d),
            p + "mlp.up_proj.weight": (f, d),
            p + "mlp.down_proj.weight": (d, f),
        })
    return out


def header_inventory(path: Path, expected: dict, dtype: str) -> dict:
    """Read only 8-byte header length and bounded JSON header; stat payload."""
    file_bytes = path.stat().st_size
    with path.open("rb") as fh:
        size_buf = fh.read(8)
        if len(size_buf) != 8:
            raise ValueError("truncated safetensors length")
        header_len = struct.unpack("<Q", size_buf)[0]
        if header_len < 2 or header_len > MAX_HEADER or 8 + header_len > file_bytes:
            raise ValueError("invalid or excessive safetensors header length")
        header_bytes = fh.read(header_len)
        if len(header_bytes) != header_len:
            raise ValueError("truncated safetensors header")
    raw = json.loads(header_bytes)
    if not isinstance(raw, dict):
        raise ValueError("safetensors header must be an object")
    tensors = {k: v for k, v in raw.items() if k != "__metadata__"}
    if set(tensors) != set(expected):
        raise ValueError(f"tensor set mismatch: missing={sorted(set(expected)-set(tensors))[:5]} "
                         f"extra={sorted(set(tensors)-set(expected))[:5]}")
    ranges = []
    for name, shape in expected.items():
        item = tensors[name]
        if not isinstance(item, dict) or item.get("dtype") != dtype or item.get("shape") != list(shape):
            raise ValueError(f"dtype/shape mismatch: {name}")
        off = item.get("data_offsets")
        if (not isinstance(off, list) or len(off) != 2 or
            any(not isinstance(v, int) or isinstance(v, bool) for v in off) or
            off[0] < 0 or off[1] < off[0]):
            raise ValueError(f"invalid data offsets: {name}")
        words = 1
        for axis in shape:
            words *= axis
        if off[1] - off[0] != words * DTYPE_BYTES[dtype]:
            raise ValueError(f"byte span mismatch: {name}")
        ranges.append((off[0], off[1], name))
    ranges.sort()
    end = 0
    for lo, hi, name in ranges:
        if lo != end:
            raise ValueError(f"gap or overlap before {name}: {lo} != {end}")
        end = hi
    if 8 + header_len + end != file_bytes:
        raise ValueError("header spans do not match actual file length")
    return {"tensor_count": len(tensors), "payload_bytes": end,
            "header_bytes": 8 + header_len,
            "header_sha256": hashlib.sha256(size_buf + header_bytes).hexdigest(),
            "file_bytes_from_stat": file_bytes, "payload_read_bytes": 0}


def inspect(config: dict, header: Path | None = None) -> dict:
    expected = expected_tensors(config)
    params = sum(__import__("math").prod(shape) for shape in expected.values())
    dtype = CONFIG_DTYPE[config["torch_dtype"]]
    d, f = config["hidden_size"], config["intermediate_size"]
    h, kv = config["num_attention_heads"], config["num_key_value_heads"]
    report = {
        "status": "config_geometry_only" if header is None else "header_verified_not_calibrated",
        "architecture": "LlamaForCausalLM/RMSNorm/RoPE/GQA/SwiGLU",
        "geometry": {"layers": config["num_hidden_layers"], "d": d, "f": f,
                     "query_heads": h, "kv_heads": kv, "head_dim": d // h,
                     "kv_width": kv * d // h, "vocab": config["vocab_size"],
                     "max_positions": config["max_position_embeddings"]},
        "checkpoint_dtype": dtype, "tensor_count": len(expected),
        "parameter_count": params, "checkpoint_payload_bytes": params * DTYPE_BYTES[dtype],
        "per_layer_parameter_count": 2 * d * d + 2 * d * (kv * d // h) + 3 * d * f + 2 * d,
    }
    if header is not None:
        report["header"] = header_inventory(header, expected, dtype)
        if report["header"]["payload_bytes"] != report["checkpoint_payload_bytes"]:
            raise ValueError("checkpoint payload differs from config-derived count")
    report["integer_calibration_ready"] = False
    report["private_block_profile_admitted"] = False
    return report


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, required=True)
    ap.add_argument("--safetensors", type=Path)
    args = ap.parse_args()
    result = inspect(json.loads(args.config.read_text()), args.safetensors)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
