import tempfile
import unittest
from pathlib import Path

from preflight import inspect


class PreflightTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = {"hidden_size": 2, "intermediate_size": 4, "num_hidden_layers": 1}
        self.shapes = {"X": [3, 2], "WgT": [2, 4], "WuT": [2, 4],
                       "WdT": [4, 2], "a16": [3, 4], "u16": [3, 4],
                       "h16": [3, 4], "z16": [3, 2]}
        dtypes = {k: "int8" for k in ("X", "WgT", "WuT", "WdT")}
        dtypes.update({k: "<i2" for k in ("a16", "u16", "h16", "z16")})
        files = {k: f"layer00_{k}.bin" for k in self.shapes}
        digests = {k: "0" * 64 for k in self.shapes}
        self.manifest = {"dims": {"t": 3, "d": 2, "f": 4, "layers": 1},
                         "profile": "v3-widened", "requant": "round",
                         "shapes": self.shapes, "dtypes": dtypes,
                         "layers": [{"layer": 0, "files": files, "digests": digests}],
                         "checkpoint_sha256": {"shard.safetensors": "0" * 64},
                         "range_violations": 0, "a16_clamp_hits": 0}
        self.sidecar = "00 dims 3 2 4 1\n00 profile v3-widened\n" + "".join(
            f"00 {k} {'0' * 64}\n" for k in self.shapes)
        self.index = {"metadata": {"total_size": 10},
                      "weight_map": {"model.layers.0.weight": "shard.safetensors"}}
        for k, name in files.items():
            rows, cols = self.shapes[k]
            (self.root / name).write_bytes(bytes(rows * cols * (2 if k in ("a16", "u16", "h16", "z16") else 1)))

    def check(self):
        return inspect(self.config, self.manifest, self.sidecar, self.root, self.index)

    def test_complete_metadata_and_files(self):
        self.assertTrue(self.check()["ready_for_ffn_tensor_loading"])

    def test_missing_and_wrong_size_refused(self):
        (self.root / "layer00_X.bin").unlink()
        (self.root / "layer00_WgT.bin").write_bytes(b"x")
        got = self.check()
        self.assertFalse(got["ready_for_ffn_tensor_loading"])
        self.assertEqual((got["files_missing"], got["files_wrong_size"]), (1, 1))

    def test_identity_and_digest_refused(self):
        self.manifest["checkpoint_sha256"] = {"other.safetensors": "0" * 64}
        self.sidecar = self.sidecar.replace("00 X " + "0" * 64, "00 X " + "1" * 64)
        got = self.check()
        self.assertFalse(got["ready_for_ffn_tensor_loading"])
        self.assertTrue(any("shard identities" in x for x in got["errors"]))
        self.assertTrue(any("sidecar digest" in x for x in got["errors"]))


if __name__ == "__main__":
    unittest.main()
