"""Synthetic-only coverage for the raw trained-weight inventory boundary."""

import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "scripts/zk60_1b_checkpoint.py"
SPEC = importlib.util.spec_from_file_location("zk60_1b_checkpoint", MODULE)
import sys
ck = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = ck
SPEC.loader.exec_module(ck)


def fixture(directory, *, indexed=False, layers=2):
    config = {"model_type": "llama", "architectures": ["LlamaForCausalLM"],
              "hidden_act": "silu", "hidden_size": 8, "intermediate_size": 12,
              "num_hidden_layers": layers, "num_attention_heads": 2,
              "num_key_value_heads": 1, "vocab_size": 16,
              "rms_norm_eps": 1e-5, "rope_theta": 10000.0,
              "tie_word_embeddings": False}
    (directory / "config.json").write_text(json.dumps(config))
    expected = ck._expected(ck._config(config))
    groups = [dict(), dict()]
    for name, shape in expected.items():
        group = int(name.split(".")[2]) % 2 if name.startswith("model.layers.") and indexed else 0
        groups[group][name] = shape
    weight_map = {}
    total = 0
    for number, group in enumerate(groups if indexed else groups[:1]):
        header, payload = {}, bytearray()
        for name, shape in sorted(group.items()):
            length = 2
            for dim in shape:
                length *= dim
            start = len(payload)
            payload.extend(bytes([number + 1]) * length)
            header[name] = {"dtype": "BF16", "shape": list(shape), "data_offsets": [start, start + length]}
            weight_map[name] = f"model-{number}.safetensors" if indexed else "model.safetensors"
        header_bytes = json.dumps(header).encode()
        (directory / (f"model-{number}.safetensors" if indexed else "model.safetensors")).write_bytes(
            struct.pack("<Q", len(header_bytes)) + header_bytes + payload)
        total += len(payload)
    if indexed:
        (directory / "model.safetensors.index.json").write_text(json.dumps(
            {"metadata": {"total_size": total}, "weight_map": weight_map}))
    return config, weight_map


class ImportTests(unittest.TestCase):
    def test_streamed_tiles_are_bounded_and_finish_with_integrity_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            fixture(path)
            model = ck.Checkpoint(path)
            ref = model.layer(1)["mlp.gate_proj.weight"]
            tiles = list(ref.iter_tiles(14))
            self.assertTrue(all(len(tile) <= 14 for tile in tiles))
            self.assertEqual(b"".join(tiles), ref.read_bytes())
            with self.assertRaisesRegex(ValueError, "tile bound"):
                list(ref.iter_tiles(3))
            with ref.shard.open("r+b") as stream:
                stream.seek(ref.data_start + ref.end - 2)
                stream.write(b"\x00\x00")
            with self.assertRaisesRegex(ValueError, "changed after source pinning"):
                list(ref.iter_tiles(14))

    def test_single_shard_layer_boundary_and_bounded_reads(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            fixture(path)
            model = ck.Checkpoint(path)
            self.assertEqual(model.identity["tensor_count"], 21)
            self.assertIsNone(model.identity["index_sha256"])
            self.assertEqual(len(model.layer(0)), 9)
            self.assertEqual(len(model.layer(1)), 9)
            self.assertEqual(model.layer(0)["self_attn.k_proj.weight"].shape, (4, 8))
            self.assertEqual(model.layer(1)["mlp.down_proj.weight"].shape, (8, 12))
            ref = model.layer(1)["mlp.gate_proj.weight"]
            self.assertEqual(ref.read_bytes(), bytes([1]) * (12 * 8 * 2))
            self.assertEqual(ref.read_tile(16, 8), bytes([1]) * 8)
            with self.assertRaisesRegex(ValueError, "bounded read"):
                ref.read_bytes(10)
            with self.assertRaisesRegex(ValueError, "align"):
                ref.read_tile(1, 8)
            with self.assertRaisesRegex(ValueError, "layer out of range"):
                model.layer(2)

    def test_sharded_index_and_source_pins(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            fixture(path, indexed=True)
            model = ck.Checkpoint(path)
            self.assertEqual(len(model.identity["shard_sha256"]), 2)
            self.assertEqual(len(model.layer(1)), 9)
            self.assertEqual(model.layer(1)["self_attn.q_proj.weight"].read_bytes()[:2], b"\x02\x02")
            with self.assertRaisesRegex(ValueError, "source pin"):
                ck.Checkpoint(path, {"model-0.safetensors": "0" * 64,
                                     "model-1.safetensors": "0" * 64})
            ref = model.layer(1)["self_attn.q_proj.weight"]
            with ref.shard.open("r+b") as stream:
                stream.seek(ref.data_start + ref.start)
                stream.write(b"\x00")
            with self.assertRaisesRegex(ValueError, "changed after source pinning"):
                ref.read_bytes()

    def test_orientation_corruption_and_payload_bounds(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            fixture(path)
            shard = path / "model.safetensors"
            original = shard.read_bytes()
            hlen = struct.unpack("<Q", original[:8])[0]
            header = json.loads(original[8:8 + hlen])
            header["model.layers.1.self_attn.k_proj.weight"]["shape"] = [8, 4]
            changed = json.dumps(header).encode()
            shard.write_bytes(struct.pack("<Q", len(changed)) + changed + original[8 + hlen:])
            with self.assertRaisesRegex(ValueError, "orientation/shape"):
                ck.Checkpoint(path)
            shard.write_bytes(original[:-1])
            with self.assertRaisesRegex(ValueError, "bounds|payload"):
                ck.Checkpoint(path)

    def test_unsupported_architecture_and_unsafe_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            config, weight_map = fixture(path, indexed=True)
            config["model_type"] = "mistral"
            (path / "config.json").write_text(json.dumps(config))
            with self.assertRaisesRegex(ValueError, "unsupported architecture"):
                ck.Checkpoint(path)
            config["model_type"] = "llama"
            (path / "config.json").write_text(json.dumps(config))
            index_path = path / "model.safetensors.index.json"
            index = json.loads(index_path.read_text())
            index["weight_map"]["model.layers.0.self_attn.q_proj.weight"] = "../escape.safetensors"
            index_path.write_text(json.dumps(index))
            with self.assertRaisesRegex(ValueError, "unsafe"):
                ck.Checkpoint(path)

    def test_overlap_and_duplicate_json_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            fixture(path)
            shard = path / "model.safetensors"
            original = shard.read_bytes()
            hlen = struct.unpack("<Q", original[:8])[0]
            header = json.loads(original[8:8 + hlen])
            first = list(header)[0]
            header[first]["data_offsets"][0] += 2
            changed = json.dumps(header).encode()
            shard.write_bytes(struct.pack("<Q", len(changed)) + changed + original[8 + hlen:])
            with self.assertRaisesRegex(ValueError, "gap or overlap|shape/offset"):
                ck.Checkpoint(path)
            (path / "config.json").write_text('{"model_type":"llama","model_type":"llama"}')
            with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                ck.Checkpoint(path)


if __name__ == "__main__":
    unittest.main()
