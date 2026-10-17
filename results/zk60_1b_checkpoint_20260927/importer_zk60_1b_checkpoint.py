#!/usr/bin/env python3
"""Strict, bounded Llama safetensors inventory for native block calibration.

This reads headers and hashes shards in chunks. Tensor payloads are only read
through TensorRef.read_bytes, one tensor at a time. It does not quantize or
construct a BlockPublic statement.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from dataclasses import dataclass, replace
from pathlib import Path

SCHEMA = "zk60-llama-layer-inventory/1"
MAX_HEADER = 16 * 1024 * 1024
MAX_TENSOR_READ = 256 * 1024 * 1024
SHARD_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\.safetensors\Z")


def _object_pairs(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def _json(data: bytes, source: str):
    try:
        return json.loads(data, object_pairs_hook=_object_pairs,
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"nonfinite JSON value: {value}")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON in {source}: {exc}") from exc


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _positive_int(value, name: str) -> int:
    if type(value) is not int or value <= 0:
        raise ValueError(f"{name} must be a positive integer")
    return value


@dataclass(frozen=True)
class TensorRef:
    name: str
    shard: Path
    dtype: str
    shape: tuple[int, ...]
    start: int
    end: int
    data_start: int
    sha256: str = ""

    def read_bytes(self, max_bytes: int = MAX_TENSOR_READ) -> bytes:
        length = self.end - self.start
        return self.read_tile(0, length, max_bytes=max_bytes)

    def read_tile(self, offset: int, length: int, max_bytes: int = 1024 * 1024) -> bytes:
        """Return a bounded tile while rechecking the entire tensor's pin."""
        size = self.end - self.start
        if type(offset) is not int or type(length) is not int or offset < 0 or length < 0 or length > max_bytes or offset + length > size:
            raise ValueError(f"{self.name}: tile exceeds bounded read limit")
        if offset % 2 or length % 2:
            raise ValueError(f"{self.name}: BF16 tile must align to elements")
        digest = hashlib.sha256()
        tile = bytearray()
        with self.shard.open("rb") as stream:
            stream.seek(self.data_start + self.start)
            position = 0
            while position < size:
                chunk = stream.read(min(size - position, 1024 * 1024))
                if not chunk:
                    raise ValueError(f"{self.name}: tensor truncated after inventory")
                digest.update(chunk)
                lo, hi = max(offset, position), min(offset + length, position + len(chunk))
                if hi > lo:
                    tile.extend(chunk[lo - position:hi - position])
                position += len(chunk)
        if digest.hexdigest() != self.sha256:
            raise ValueError(f"{self.name}: tensor changed after source pinning")
        return bytes(tile)


def _config(raw: dict) -> dict:
    if not isinstance(raw, dict):
        raise ValueError("config must be an object")
    if raw.get("model_type") != "llama" or raw.get("architectures") != ["LlamaForCausalLM"]:
        raise ValueError("unsupported architecture: require LlamaForCausalLM")
    if raw.get("hidden_act") != "silu" or raw.get("tie_word_embeddings", False) is not False:
        raise ValueError("unsupported activation or tied embeddings")
    if raw.get("attention_bias", False) is not False or raw.get("mlp_bias", False) is not False:
        raise ValueError("bias-bearing Llama is unsupported")
    d = _positive_int(raw.get("hidden_size"), "hidden_size")
    f = _positive_int(raw.get("intermediate_size"), "intermediate_size")
    layers = _positive_int(raw.get("num_hidden_layers"), "num_hidden_layers")
    heads = _positive_int(raw.get("num_attention_heads"), "num_attention_heads")
    kv_heads = _positive_int(raw.get("num_key_value_heads", heads), "num_key_value_heads")
    vocab = _positive_int(raw.get("vocab_size"), "vocab_size")
    if d > 16384 or f > 65536 or layers > 256 or heads > 256 or vocab > 1000000:
        raise ValueError("configuration exceeds bounded importer limits")
    if d % heads or heads % kv_heads:
        raise ValueError("invalid grouped-query head geometry")
    dh = d // heads
    if dh % 2 or raw.get("head_dim", dh) != dh:
        raise ValueError("unsupported head dimension")
    if raw.get("rope_scaling") not in (None, {}) or raw.get("rope_interleaved", False) is not False or raw.get("partial_rotary_factor", 1.0) != 1.0:
        raise ValueError("RoPE scaling requires a separate calibrated profile")
    if raw.get("sliding_window") is not None:
        raise ValueError("sliding-window attention requires a different relation")
    if any(type(raw.get(key)) not in (int, float) or not math.isfinite(raw[key]) or raw[key] <= 0 for key in ("rms_norm_eps", "rope_theta")):
        raise ValueError("RMSNorm epsilon and RoPE theta must be explicit, finite and positive")
    return {"hidden_size": d, "intermediate_size": f, "layers": layers,
            "heads": heads, "kv_heads": kv_heads, "head_dim": dh, "vocab": vocab,
            "rms_norm_eps": raw["rms_norm_eps"], "rope_theta": raw["rope_theta"]}


def _expected(c: dict) -> dict[str, tuple[int, ...]]:
    d, f, kv = c["hidden_size"], c["intermediate_size"], c["kv_heads"] * c["head_dim"]
    expected = {"model.embed_tokens.weight": (c["vocab"], d),
                "model.norm.weight": (d,), "lm_head.weight": (c["vocab"], d)}
    for layer in range(c["layers"]):
        prefix = f"model.layers.{layer}."
        expected.update({prefix + key: shape for key, shape in {
            "input_layernorm.weight": (d,), "post_attention_layernorm.weight": (d,),
            "self_attn.q_proj.weight": (d, d), "self_attn.k_proj.weight": (kv, d),
            "self_attn.v_proj.weight": (kv, d), "self_attn.o_proj.weight": (d, d),
            "mlp.gate_proj.weight": (f, d), "mlp.up_proj.weight": (f, d),
            "mlp.down_proj.weight": (d, f)}.items()})
    return expected


def _shard(path: Path) -> tuple[dict, str]:
    size = path.stat().st_size
    with path.open("rb") as stream:
        prefix = stream.read(8)
        if len(prefix) != 8:
            raise ValueError(f"{path.name}: missing safetensors header length")
        hlen = struct.unpack("<Q", prefix)[0]
        if not 0 < hlen <= MAX_HEADER or hlen + 8 > size:
            raise ValueError(f"{path.name}: invalid safetensors header length")
        header_bytes = stream.read(hlen)
    header = _json(header_bytes, path.name)
    if not isinstance(header, dict) or not header:
        raise ValueError(f"{path.name}: empty/invalid safetensors header")
    data_length = size - 8 - hlen
    refs = {}
    spans = []
    for name, entry in header.items():
        if name == "__metadata__":
            if not isinstance(entry, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in entry.items()):
                raise ValueError(f"{path.name}: invalid metadata")
            continue
        if not isinstance(entry, dict) or set(entry) != {"dtype", "shape", "data_offsets"}:
            raise ValueError(f"{name}: malformed tensor descriptor")
        shape, offsets = entry["shape"], entry["data_offsets"]
        if entry["dtype"] != "BF16" or not isinstance(shape, list) or not shape or any(type(x) is not int or x <= 0 for x in shape):
            raise ValueError(f"{name}: expected nonempty BF16 tensor shape")
        if not isinstance(offsets, list) or len(offsets) != 2 or any(type(x) is not int for x in offsets):
            raise ValueError(f"{name}: invalid offsets")
        start, end = offsets
        elements = 1
        for dim in shape:
            elements *= dim
        if start < 0 or end < start or end > data_length or end - start != elements * 2:
            raise ValueError(f"{name}: shape/offset/payload bounds mismatch")
        spans.append((start, end, name))
        refs[name] = TensorRef(name, path, "BF16", tuple(shape), start, end, 8 + hlen)
    spans.sort()
    cursor = 0
    for start, end, name in spans:
        if start != cursor:
            raise ValueError(f"{path.name}: gap or overlap before {name}")
        cursor = end
    if cursor != data_length:
        raise ValueError(f"{path.name}: unaccounted payload bytes")
    return refs, _sha(header_bytes)


def _pin_shard(path: Path, refs: dict[str, TensorRef], header_sha256: str) -> tuple[str, dict[str, TensorRef]]:
    """One sequential, chunked pass pins the complete file and every tensor."""
    full = hashlib.sha256()
    ordered = sorted(refs.values(), key=lambda ref: ref.start)
    if not ordered:
        raise ValueError(f"{path.name}: no tensors")
    with path.open("rb") as stream:
        header = stream.read(ordered[0].data_start)
        if _sha(header[8:]) != header_sha256:
            raise ValueError(f"{path.name}: header changed while pinning")
        full.update(header)
        pinned = {}
        for ref in ordered:
            tensor = hashlib.sha256()
            remaining = ref.end - ref.start
            while remaining:
                chunk = stream.read(min(remaining, 1024 * 1024))
                if not chunk:
                    raise ValueError(f"{ref.name}: payload truncated while pinning")
                full.update(chunk)
                tensor.update(chunk)
                remaining -= len(chunk)
            pinned[ref.name] = replace(ref, sha256=tensor.hexdigest())
        if stream.read(1):
            raise ValueError(f"{path.name}: trailing bytes while pinning")
    return full.hexdigest(), pinned


class Checkpoint:
    def __init__(self, directory: Path, expected_shards: dict[str, str] | None = None):
        self.directory = directory
        config_path = directory / "config.json"
        index_path = directory / "model.safetensors.index.json"
        config_bytes = config_path.read_bytes()
        self.config = _config(_json(config_bytes, "config.json"))
        expected = _expected(self.config)
        if index_path.exists():
            index_bytes = index_path.read_bytes()
            index = _json(index_bytes, index_path.name)
            if not isinstance(index, dict) or set(index) != {"metadata", "weight_map"} or not isinstance(index["metadata"], dict) or not isinstance(index["weight_map"], dict):
                raise ValueError("invalid safetensors index")
            weight_map = index["weight_map"]
            if set(weight_map) != set(expected):
                raise ValueError(f"checkpoint tensor inventory differs: missing={sorted(set(expected)-set(weight_map))[:3]}, extra={sorted(set(weight_map)-set(expected))[:3]}")
            names = set(weight_map.values())
        else:
            index_bytes, index, weight_map = None, None, None
            names = {"model.safetensors"}
        if any(not isinstance(name, str) or not SHARD_NAME.fullmatch(name) for name in names):
            raise ValueError("unsafe or invalid shard name")
        refs, headers, hashes = {}, {}, {}
        for name in sorted(names):
            path = directory / name
            if path.is_symlink() or not path.is_file():
                raise ValueError(f"missing or symlinked shard: {name}")
            part, headers[name] = _shard(path)
            if set(part) & set(refs):
                raise ValueError("duplicate tensor across shards")
            hashes[name], part = _pin_shard(path, part, headers[name])
            refs.update(part)
        if expected_shards is not None and hashes != expected_shards:
            raise ValueError("checkpoint shard SHA-256 differs from expected source pin")
        if set(refs) != set(expected):
            raise ValueError(f"checkpoint tensor inventory differs: missing={sorted(set(expected)-set(refs))[:3]}, extra={sorted(set(refs)-set(expected))[:3]}")
        if weight_map is not None and set(refs) != set(weight_map):
            raise ValueError("index/header tensor sets differ")
        for key, ref in refs.items():
            if (weight_map is not None and ref.shard.name != weight_map[key]) or ref.shape != expected[key]:
                raise ValueError(f"{key}: shard mapping or orientation/shape mismatch")
        payload_size = sum(ref.end - ref.start for ref in refs.values())
        if index is not None and index["metadata"].get("total_size") != payload_size:
            raise ValueError("index total_size differs from header payload")
        self.refs = refs
        self.identity = {"schema": SCHEMA, "config_sha256": _sha(config_bytes),
                         "index_sha256": _sha(index_bytes) if index_bytes is not None else None, "shard_sha256": hashes,
                         "header_sha256": headers, "tensor_count": len(refs),
                         "payload_bytes": payload_size, "geometry": self.config,
                         "tensor_sha256": {key: ref.sha256 for key, ref in sorted(refs.items())}}

    def layer(self, number: int):
        if type(number) is not int or not 0 <= number < self.config["layers"]:
            raise ValueError("layer out of range")
        prefix = f"model.layers.{number}."
        # Descriptors only. Caller may read exactly one bounded tensor at a time.
        return {name.removeprefix(prefix): ref for name, ref in self.refs.items() if name.startswith(prefix)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkpoint", type=Path)
    parser.add_argument("--expected-sha256", help="expected SHA-256 for a single model.safetensors")
    args = parser.parse_args()
    expected = {"model.safetensors": args.expected_sha256} if args.expected_sha256 else None
    checkpoint = Checkpoint(args.checkpoint, expected_shards=expected)
    print(json.dumps(checkpoint.identity, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
