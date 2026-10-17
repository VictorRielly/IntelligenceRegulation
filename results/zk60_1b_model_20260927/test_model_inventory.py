import json
from pathlib import Path
import struct
import tempfile
import unittest

from model_inventory import expected_tensors, header_inventory, inspect


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.c = dict(model_type="llama", architectures=["LlamaForCausalLM"],
                      hidden_size=8, intermediate_size=16, num_attention_heads=2,
                      num_key_value_heads=1, num_hidden_layers=2, vocab_size=16,
                      hidden_act="silu", tie_word_embeddings=False,
                      rope_scaling=None, rms_norm_eps=1e-5,
                      max_position_embeddings=512, torch_dtype="bfloat16")

    def make_file(self, path: Path, corrupt=None):
        offset = 0
        entries = {}
        for name, shape in expected_tensors(self.c).items():
            span = 2
            for axis in shape:
                span *= axis
            entries[name] = dict(dtype="BF16", shape=list(shape),
                                 data_offsets=[offset, offset + span])
            offset += span
        if corrupt:
            corrupt(entries)
        header = json.dumps(entries, separators=(",", ":")).encode()
        path.write_bytes(struct.pack("<Q", len(header)) + header + bytes(offset))
        return offset

    def test_header_and_count_without_tensor_values(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "model.safetensors"
            payload = self.make_file(p)
            r = inspect(self.c, p)
            self.assertEqual(r["status"], "header_verified_not_calibrated")
            self.assertEqual(r["header"]["payload_bytes"], payload)
            self.assertEqual(r["header"]["payload_read_bytes"], 0)
            self.assertEqual(r["tensor_count"], 21)
            self.assertFalse(r["integer_calibration_ready"])

    def test_missing_tensor_and_wrong_geometry_refuse(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "model.safetensors"
            self.make_file(p, lambda x: x.pop("model.layers.1.self_attn.k_proj.weight"))
            with self.assertRaisesRegex(ValueError, "tensor set mismatch"):
                header_inventory(p, expected_tensors(self.c), "BF16")
        bad = dict(self.c, num_key_value_heads=3)
        with self.assertRaisesRegex(ValueError, "head dimension or GQA"):
            inspect(bad)

    def test_wrong_span_truncation_and_new_relation_refuse(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "model.safetensors"
            self.make_file(p, lambda x: x["model.norm.weight"]["data_offsets"].__setitem__(1, 0))
            with self.assertRaisesRegex(ValueError, "invalid data offsets|byte span mismatch"):
                header_inventory(p, expected_tensors(self.c), "BF16")
            p.write_bytes(struct.pack("<Q", 2**30))
            with self.assertRaisesRegex(ValueError, "header length"):
                header_inventory(p, expected_tensors(self.c), "BF16")
        with self.assertRaisesRegex(ValueError, "scaled RoPE"):
            inspect(dict(self.c, rope_scaling={"type": "linear", "factor": 2}))


if __name__ == "__main__":
    unittest.main()
