"""Download integrity and resume controls; no live network or model allocation."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.parse

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/zk60_checkpoint_fetch.py"
spec = importlib.util.spec_from_file_location("checkpoint_fetch", SCRIPT)
fetcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetcher)

inventory_spec = importlib.util.spec_from_file_location(
    "zk60_1b_checkpoint", SCRIPT.with_name("zk60_1b_checkpoint.py"))
inventory = importlib.util.module_from_spec(inventory_spec)
sys.modules[inventory_spec.name] = inventory
inventory_spec.loader.exec_module(inventory)


REVISION = "a" * 40


def checkpoint_files(*, indexed=True, extra=True):
    """A complete tiny Llama checkpoint, independent of importer helpers."""
    config = {"model_type": "llama", "architectures": ["LlamaForCausalLM"],
              "hidden_act": "silu", "hidden_size": 4, "intermediate_size": 6,
              "num_hidden_layers": 1, "num_attention_heads": 2,
              "num_key_value_heads": 1, "vocab_size": 8,
              "rms_norm_eps": 1e-5, "rope_theta": 10000.0}
    shapes = {"model.embed_tokens.weight": [8, 4], "model.norm.weight": [4],
              "lm_head.weight": [8, 4]}
    shapes.update({"model.layers.0." + name: shape for name, shape in {
        "input_layernorm.weight": [4], "post_attention_layernorm.weight": [4],
        "self_attn.q_proj.weight": [4, 4], "self_attn.k_proj.weight": [2, 4],
        "self_attn.v_proj.weight": [2, 4], "self_attn.o_proj.weight": [4, 4],
        "mlp.gate_proj.weight": [6, 4], "mlp.up_proj.weight": [6, 4],
        "mlp.down_proj.weight": [4, 6]}.items()})
    groups = [{}, {}] if indexed else [{}]
    for number, (name, shape) in enumerate(sorted(shapes.items())):
        groups[number % len(groups)][name] = shape
    files = {"config.json": json.dumps(config).encode()}
    weight_map, total = {}, 0
    for number, group in enumerate(groups):
        shard = f"model-{number}.safetensors" if indexed else "model.safetensors"
        header, payload = {}, bytearray()
        for name, shape in group.items():
            size = 2
            for dim in shape:
                size *= dim
            start = len(payload)
            payload.extend(b"\x00" * size)
            header[name] = {"dtype": "BF16", "shape": shape,
                            "data_offsets": [start, start + size]}
            weight_map[name] = shard
        encoded = json.dumps(header).encode()
        encoded += b" " * (-len(encoded) % 8)
        files[shard] = struct.pack("<Q", len(encoded)) + encoded + payload
        total += len(payload)
    if indexed:
        files["model.safetensors.index.json"] = json.dumps(
            {"metadata": {"total_size": total}, "weight_map": weight_map}).encode()
    if extra:
        files["unreferenced.safetensors"] = b"auxiliary weights, not a checkpoint shard"
    return files


def provider_metadata(files, *, lfs=True):
    siblings = []
    for name, data in files.items():
        item = {"rfilename": name, "size": len(data),
                "blobId": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}
        if lfs and name.endswith(".safetensors"):
            item["lfs"] = {"sha256": hashlib.sha256(data).hexdigest(), "size": len(data)}
        siblings.append(item)
    return {"sha": REVISION, "siblings": siblings}


class Response(io.BytesIO):
    def __init__(self, data, status=200, headers=None):
        super().__init__(data)
        self.status = status
        self.headers = headers or {}


class FetchTests(unittest.TestCase):
    def lfs_item(self, data):
        return {"size": len(data), "lfs": {"sha256": hashlib.sha256(data).hexdigest()}}

    def test_verified_download_and_cached_file(self):
        data = b"checkpoint tensor payload"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)) as network:
                actual = fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(actual, hashlib.sha256(data).hexdigest())
                self.assertEqual(target.read_bytes(), data)
                cached = fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(actual, cached)
                self.assertEqual(network.call_count, 1)

    def test_resumed_payload_must_match_range_and_final_digest(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            partial = target.with_name(target.name + ".partial")
            partial.write_bytes(data[:5])
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data[5:], 206, {"Content-Range": "bytes 5-14/15"})) as network:
                fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(network.call_args.args[0].get_header("Range"), "bytes=5-")
            self.assertEqual(target.read_bytes(), data)

    def test_resume_refuses_full_body_without_correct_range(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            partial = target.with_name(target.name + ".partial")
            partial.write_bytes(data[:5])
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                with self.assertRaisesRegex(ValueError, "resume offset"):
                    fetcher.download("https://example.test/weights", target, self.lfs_item(data))
            self.assertEqual(partial.read_bytes(), data[:5])
            self.assertFalse(target.exists())

    def test_digest_mismatch_is_never_published(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(b"x" * len(data))):
                with self.assertRaisesRegex(ValueError, "hash/length differs"):
                    fetcher.download("https://example.test/weights", target, self.lfs_item(data))
            self.assertFalse(target.exists())
            self.assertTrue(target.with_name(target.name + ".partial").exists())

    def test_small_file_checks_provider_git_blob(self):
        data = b'{"config": 1}'
        digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "config.json"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                actual = fetcher.download("https://example.test/config", target, {"size": len(data), "blobId": digest})
            self.assertEqual(actual, hashlib.sha256(data).hexdigest())
            self.assertEqual(target.read_bytes(), data)
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                with self.assertRaisesRegex(ValueError, "blob pin differs"):
                    fetcher.download("https://example.test/config", target, {"size": len(data), "blobId": "0" * 40})


class CheckpointFetchTests(unittest.TestCase):
    def run_fetch(self, root, files, *, metadata_only=False, lfs=True, metadata=None):
        metadata = metadata if metadata is not None else provider_metadata(files, lfs=lfs)
        requested = []

        def response(request, **_kwargs):
            url = request.full_url if hasattr(request, "full_url") else request
            name = urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit("/", 1)[-1])
            self.assertIn(f"/example/llama/resolve/{REVISION}/", url)
            requested.append(name)
            return Response(files[name])

        self.requested = requested
        with patch.object(fetcher, "json_url", return_value=(metadata, json.dumps(metadata).encode())), \
                patch.object(fetcher.urllib.request, "urlopen", side_effect=response), \
                patch.dict(sys.modules, {"zk60_1b_checkpoint": inventory}):
            record = fetcher.fetch("example/llama", REVISION, root / "output", root / "evidence", metadata_only)
        self.assertEqual(record, json.loads((root / "evidence/source.json").read_text()))
        return record

    def test_index_selects_only_referenced_shards_through_actual_importer(self):
        files = checkpoint_files()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            record = self.run_fetch(root, files)
            self.assertEqual(record["state"], "raw-checkpoint-verified")
            self.assertEqual(record["tensor_count"], 12)
            self.assertNotIn("unreferenced.safetensors", record["files"])
            self.assertNotIn("unreferenced.safetensors", self.requested)
            self.assertEqual(set(record["files"]), set(files) - {"unreferenced.safetensors"})
            self.assertFalse(record["proof_ready"])
            self.assertFalse(record["proof_produced"])

    def test_git_stored_weights_have_sha256_pins_for_actual_importer(self):
        files = checkpoint_files(extra=False)
        with tempfile.TemporaryDirectory() as temp:
            record = self.run_fetch(Path(temp), files, lfs=False)
            self.assertEqual(record["state"], "raw-checkpoint-verified")
            for name, entry in record["files"].items():
                self.assertEqual(entry["sha256"], hashlib.sha256(files[name]).hexdigest())
                self.assertTrue(entry["local_verified"])

    def test_unindexed_checkpoint_uses_canonical_single_shard(self):
        files = checkpoint_files(indexed=False)
        with tempfile.TemporaryDirectory() as temp:
            record = self.run_fetch(Path(temp), files)
            self.assertEqual(record["state"], "raw-checkpoint-verified")
            self.assertEqual(set(record["files"]), {"config.json", "model.safetensors"})
            self.assertNotIn("unreferenced.safetensors", self.requested)

    def test_metadata_only_selects_shards_without_fetching_weight_payloads(self):
        files = checkpoint_files()
        with tempfile.TemporaryDirectory() as temp:
            record = self.run_fetch(Path(temp), files, metadata_only=True)
            self.assertEqual(record["state"], "metadata-pinned")
            self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])
            self.assertNotIn("unreferenced.safetensors", record["files"])
            for name in ("model-0.safetensors", "model-1.safetensors"):
                self.assertNotIn("local_verified", record["files"][name])

    def test_metadata_only_git_shards_keep_source_pin_without_local_verification(self):
        files = checkpoint_files()
        with tempfile.TemporaryDirectory() as temp:
            record = self.run_fetch(Path(temp), files, metadata_only=True, lfs=False)
            for name in ("model-0.safetensors", "model-1.safetensors"):
                self.assertIsNone(record["files"][name]["sha256"])
                self.assertEqual(len(record["files"][name]["git_blob"]), 40)
                self.assertNotIn("local_verified", record["files"][name])

    def test_fetch_can_be_repeated_with_verified_cached_shards(self):
        files = checkpoint_files()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            first = self.run_fetch(root, files)
            second = self.run_fetch(root, files)
            self.assertEqual(first, second)
            self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])
            self.assertFalse(list((root / "evidence").glob("*.tmp")))
            identity = json.loads((root / "evidence/inventory.json").read_text())
            self.assertEqual(set(identity["shard_sha256"]), {"model-0.safetensors", "model-1.safetensors"})
            self.assertEqual(second["inventory_sha256"], fetcher.sha_file(root / "evidence/inventory.json"))

    def test_missing_referenced_shard_is_rejected_before_any_weight_request(self):
        files = checkpoint_files()
        del files["model-1.safetensors"]
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "missing from provider metadata"):
                self.run_fetch(Path(temp), files)
            self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])

    def test_shards_without_index_are_not_guessed(self):
        files = checkpoint_files()
        del files["model.safetensors.index.json"]
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "missing from provider metadata: model.safetensors"):
                self.run_fetch(Path(temp), files)
            self.assertEqual(self.requested, ["config.json"])

    def test_unselected_auxiliary_file_does_not_require_valid_pins(self):
        files = checkpoint_files()
        metadata = provider_metadata(files)
        metadata["siblings"][-1].update(size=False, blobId="not-a-pin", lfs={})
        with tempfile.TemporaryDirectory() as temp:
            record = self.run_fetch(Path(temp), files, metadata=metadata)
            self.assertEqual(record["state"], "raw-checkpoint-verified")
            self.assertNotIn("unreferenced.safetensors", record["files"])

    def test_invalid_index_is_rejected_before_any_weight_request(self):
        bad_indexes = [b"not JSON", b"[]", b"null", b"{}",
                       b'{"metadata": {}, "weight_map": {}}',
                       b'{"metadata":{"total_size":true},"weight_map":{"t":"model-0.safetensors"}}',
                       b'{"metadata":{"total_size":-1},"weight_map":{"t":"model-0.safetensors"}}',
                       b'{"metadata":{"total_size":1},"weight_map":{"t":"model-0.safetensors","t":"model-1.safetensors"}}']
        for encoded in bad_indexes:
            with self.subTest(index=encoded), tempfile.TemporaryDirectory() as temp:
                files = checkpoint_files()
                files["model.safetensors.index.json"] = encoded
                with self.assertRaises(ValueError):
                    self.run_fetch(Path(temp), files)
                self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])

    def test_index_requires_safe_root_shard_names(self):
        for name in ("../model.safetensors", "/model.safetensors", "sub/model.safetensors",
                     "sub\\model.safetensors", "model.bin", "", None, 7, ["model.safetensors"]):
            with self.subTest(shard=name), tempfile.TemporaryDirectory() as temp:
                files = checkpoint_files()
                files["model.safetensors.index.json"] = json.dumps(
                    {"metadata": {"total_size": 1}, "weight_map": {"tensor": name}}).encode()
                with self.assertRaisesRegex(ValueError, "unsafe or invalid shard name"):
                    self.run_fetch(Path(temp), files)
                self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])

    def test_selected_shards_need_well_formed_provider_pins(self):
        invalid = [{"size": True}, {"size": -1}, {"size": "792"},
                   {"blobId": "bad"}, {"blobId": None},
                   {"lfs": {}}, {"lfs": []}, {"lfs": {"sha256": "bad"}},
                   {"lfs": {"sha256": "a" * 64, "size": 1}},
                   {"lfs": {"sha256": "a" * 64, "size": False}}]
        for replacement in invalid:
            with self.subTest(replacement=replacement), tempfile.TemporaryDirectory() as temp:
                files = checkpoint_files()
                metadata = provider_metadata(files)
                next(item for item in metadata["siblings"] if item["rfilename"] == "model-0.safetensors").update(replacement)
                with self.assertRaisesRegex(ValueError, "invalid provider"):
                    self.run_fetch(Path(temp), files, metadata=metadata)
                self.assertEqual(self.requested, ["config.json", "model.safetensors.index.json"])

    def test_duplicate_and_malformed_provider_entries_are_rejected(self):
        files = checkpoint_files()
        siblings = provider_metadata(files)["siblings"]
        for bad in (None, {}, [None], [{}], [{"rfilename": 1}], siblings + [siblings[0]]):
            with self.subTest(siblings=bad), tempfile.TemporaryDirectory() as temp:
                metadata = {"sha": REVISION, "siblings": bad}
                with self.assertRaises(ValueError):
                    self.run_fetch(Path(temp), files, metadata=metadata)
                self.assertEqual(self.requested, [])

    def test_missing_config_is_rejected_before_creating_evidence(self):
        files = checkpoint_files()
        del files["config.json"]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaisesRegex(ValueError, "missing from provider metadata: config.json"):
                self.run_fetch(root, files)
            self.assertEqual(self.requested, [])
            self.assertFalse((root / "evidence").exists())

    def test_unavailable_or_changed_provider_revision_is_rejected(self):
        for change in ({"sha": "b" * 40}, {"gated": "manual"}, {"private": True}, {"disabled": True}):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temp:
                files = checkpoint_files()
                metadata = provider_metadata(files)
                metadata.update(change)
                with self.assertRaisesRegex(ValueError, "not public/ungated/available"):
                    self.run_fetch(Path(temp), files, metadata=metadata)
                self.assertEqual(self.requested, [])

    def test_corrupted_config_or_weight_is_not_recorded_as_verified(self):
        for name in ("config.json", "model.safetensors.index.json", "model-0.safetensors"):
            with self.subTest(file=name), tempfile.TemporaryDirectory() as temp:
                files = checkpoint_files()
                metadata = provider_metadata(files)
                files[name] = b"x" * len(files[name])
                root = Path(temp)
                with self.assertRaisesRegex(ValueError, "pin differs|hash/length differs"):
                    self.run_fetch(root, files, metadata=metadata)
                record = json.loads((root / "evidence/source.json").read_text())
                self.assertEqual(record["state"], "metadata-pinned")
                self.assertNotIn("local_verified", record["files"][name])
                self.assertFalse((root / "output" / name).exists())

    def test_importer_failure_does_not_promote_evidence_state(self):
        files = checkpoint_files()
        index = json.loads(files["model.safetensors.index.json"])
        index["metadata"]["total_size"] += 1
        files["model.safetensors.index.json"] = json.dumps(index).encode()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaisesRegex(ValueError, "total_size differs"):
                self.run_fetch(root, files)
            record = json.loads((root / "evidence/source.json").read_text())
            self.assertEqual(record["state"], "metadata-pinned")
            self.assertFalse(record["proof_ready"])
            self.assertFalse((root / "evidence/inventory.json").exists())


class EvidenceWriteTests(unittest.TestCase):
    def test_interrupted_replace_keeps_prior_complete_record_and_cleans_temporary(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "source.json"
            fetcher.write_json(path, {"state": "previous"})
            with patch.object(fetcher.os, "replace", side_effect=OSError("interrupted")):
                with self.assertRaisesRegex(OSError, "interrupted"):
                    fetcher.write_json(path, {"state": "next"})
            self.assertEqual(json.loads(path.read_text()), {"state": "previous"})
            self.assertEqual([item.name for item in path.parent.iterdir()], ["source.json"])

    def test_invalid_revision_or_model_is_rejected_without_network(self):
        for model, revision in (("example/llama", "main"), ("example/llama", "A" * 40),
                                ("../llama", REVISION), ("example/llama/extra", REVISION)):
            with self.subTest(model=model, revision=revision), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                with patch.object(fetcher, "json_url") as network:
                    with self.assertRaises(ValueError):
                        fetcher.fetch(model, revision, root / "output", root / "evidence", True)
                    network.assert_not_called()

    def test_provider_metadata_with_duplicate_json_keys_is_rejected(self):
        with patch.object(fetcher.urllib.request, "urlopen",
                          return_value=Response(b'{"sha":"one","sha":"two"}')):
            with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                fetcher.json_url("https://example.test/metadata")


if __name__ == "__main__":
    unittest.main()
