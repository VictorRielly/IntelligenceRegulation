"""Cheap configuration tests: synthetic sparse files, never native proving."""

import importlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from regression_fixtures import (
    FixtureConfigurationError, m125_environment, select_m125_fixture,
    validate_m125_fixture,
)


SHAPES = {"X": [512, 768], "WgT": [768, 2048], "WuT": [768, 2048], "WdT": [2048, 768]}


def fixture(path):
    """Sparse shape placeholders, NOT authentic tensors or a proof fixture."""
    path.mkdir(parents=True)
    layers, sidecar = [], []
    for i in range(12):
        files, digests = {}, {}
        for name in (*SHAPES, "z"):
            digests[name] = f"{i + 1:064x}"
            sidecar.append(f"{i:02} {name} {digests[name]}\n")
            if name in SHAPES:
                filename = f"layer{i:02}_{name}.bin"
                files[name] = filename
                shape = SHAPES[name]
                with (path / filename).open("wb") as stream:
                    stream.truncate(shape[0] * shape[1])
        sidecar.append(f"{i:02} shifts 9 9 6 10\n")
        layers.append({"layer": i, "eW": -9, "files": files, "digests": digests,
                       "shifts": dict(zip(("g", "u", "h", "z"), (9, 9, 6, 10)))})
    manifest = {"shapes": SHAPES, "layers": layers, "range_violations": 0}
    (path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (path / "digests.txt").write_text("".join(sidecar), encoding="utf-8")
    return path


class RegressionFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zk60-fixture-config-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_complete_default_prefers_original_export(self):
        original = fixture(self.root / "results" / "m125_ffn_export")
        fixture(self.root / "results" / "m125_ffn_export_wsl")
        self.assertEqual(select_m125_fixture(self.root, {}), original)

    def test_weights_only_original_falls_back_to_complete_wsl(self):
        original = fixture(self.root / "results" / "m125_ffn_export")
        (original / "layer00_X.bin").unlink()
        wsl = fixture(self.root / "results" / "m125_ffn_export_wsl")
        self.assertEqual(select_m125_fixture(self.root, {}), wsl)

    def test_all_layers_required_not_only_layer00_sentinel(self):
        original = fixture(self.root / "results" / "m125_ffn_export")
        (original / "layer11_WdT.bin").unlink()
        with self.assertRaisesRegex(FixtureConfigurationError, "layer11_WdT"):
            select_m125_fixture(self.root, {})

    def test_explicit_complete_override_wins_and_is_not_mutated(self):
        fixture(self.root / "results" / "m125_ffn_export")
        selected = fixture(self.root / "chosen export")
        env = {"M125_EXPORT_DIR": "chosen export", "UNCHANGED": "value"}
        child = m125_environment(self.root, env)
        self.assertEqual(child, {"M125_EXPORT_DIR": str(selected), "UNCHANGED": "value"})
        self.assertEqual(env["M125_EXPORT_DIR"], "chosen export")

    def test_absolute_explicit_override(self):
        selected = fixture(self.root / "outside-default-search")
        self.assertEqual(select_m125_fixture(self.root, {"M125_EXPORT_DIR": str(selected)}), selected)

    def test_invalid_explicit_override_never_falls_back(self):
        fixture(self.root / "results" / "m125_ffn_export_wsl")
        for value in ("missing", "", "  ", None):
            with self.subTest(value=value), self.assertRaises(FixtureConfigurationError):
                select_m125_fixture(self.root, {"M125_EXPORT_DIR": value})

    def test_incomplete_explicit_override_never_falls_back(self):
        selected = fixture(self.root / "explicit")
        (selected / "layer11_X.bin").unlink()
        fixture(self.root / "results" / "m125_ffn_export_wsl")
        with self.assertRaisesRegex(FixtureConfigurationError, "layer11_X"):
            select_m125_fixture(self.root, {"M125_EXPORT_DIR": str(selected)})

    def test_higher_precedence_native_model_override_is_refused(self):
        selected = fixture(self.root / "explicit")
        for value in ("", str(selected), "another-model"):
            with self.subTest(value=value), self.assertRaisesRegex(FixtureConfigurationError, "ZK_MODEL_EXPORT_DIR"):
                select_m125_fixture(self.root, {"M125_EXPORT_DIR": str(selected), "ZK_MODEL_EXPORT_DIR": value})

    def test_missing_fixture_is_a_configuration_failure_not_a_skip(self):
        with self.assertRaisesRegex(FixtureConfigurationError, "no complete local"):
            select_m125_fixture(self.root, {})

    def test_wrong_size_and_directory_tensor_refuse(self):
        selected = fixture(self.root / "explicit")
        tensor = selected / "layer11_X.bin"
        with tensor.open("wb") as stream:
            stream.truncate(1)
        with self.assertRaisesRegex(FixtureConfigurationError, "wrong-size"):
            validate_m125_fixture(selected)
        tensor.unlink()
        tensor.mkdir()
        with self.assertRaisesRegex(FixtureConfigurationError, "wrong-size"):
            validate_m125_fixture(selected)

    def test_malformed_metadata_and_unsupported_shape_refuse(self):
        selected = fixture(self.root / "explicit")
        metadata = selected / "manifest.json"
        original = metadata.read_text()
        for text in ("{", "[]", '{"shapes":{}}', original.replace('[512, 768]', '[512.0, 768]'), original.replace('"range_violations": 0', '"range_violations": 1')):
            metadata.write_text(text)
            with self.subTest(text=text[:25]), self.assertRaises(FixtureConfigurationError):
                validate_m125_fixture(selected)

    def test_oversized_metadata_refuses_before_read(self):
        selected = fixture(self.root / "explicit")
        for name in ("manifest.json", "digests.txt"):
            metadata = selected / name
            original = metadata.read_bytes()
            with metadata.open("wb") as stream:
                stream.truncate(131073)
            with self.subTest(name=name), self.assertRaisesRegex(FixtureConfigurationError, "oversized"):
                validate_m125_fixture(selected)
            metadata.write_bytes(original)

    def test_sidecar_missing_duplicate_or_inconsistent_entries_refuse(self):
        selected = fixture(self.root / "explicit")
        sidecar = selected / "digests.txt"
        original = sidecar.read_text()
        lines = original.splitlines(keepends=True)
        for text in ("".join(lines[:-1]), original + lines[0], original.replace("shifts 9 9 6 10", "shifts 8 9 6 10", 1), original.replace("0000000000000001", "0000000000000002", 1)):
            sidecar.write_text(text)
            with self.subTest(text=text[:25]), self.assertRaises(FixtureConfigurationError):
                validate_m125_fixture(selected)

    def test_no_tensor_reads_and_no_process_or_global_environment_mutation(self):
        selected = fixture(self.root / "results" / "m125_ffn_export_wsl")
        before = dict(os.environ)
        original_open = Path.open

        def metadata_only(path, *args, **kwargs):
            if path.suffix == ".bin":
                raise AssertionError("configuration must not read tensor contents")
            return original_open(path, *args, **kwargs)

        with patch.object(Path, "open", metadata_only), patch.object(subprocess, "run", side_effect=AssertionError("native execution")):
            self.assertEqual(m125_environment(self.root, {})["M125_EXPORT_DIR"], str(selected))
        self.assertEqual(dict(os.environ), before)

    def test_every_fixture_dependent_native_test_receives_selected_environment(self):
        cases = [
            ("test_uagb1_pass", "UagB1PassTests", "test_freeze_rows_uagb1_bf", "freeze-check passed " + " ".join(f"UAGB1-BF-{v}" for v in ("1a", "1b", "1c", "1d", "2a", "2b", "2c"))),
            ("test_uagb1_pass", "UagB1PassTests", "test_pass_smoke_real_data", "honest layer 0 ACCEPT; pass smoke passed"),
            ("test_uagb1_pass_agg", "PassAggComposition", "test_composed_smoke_real_data", "accept true"),
            ("test_uagb1_tblind", "TBlindCertificate", "test_freeze_rows", "UAGB1-BL-1a UAGB1-BL-1b UAGB1-BL-1c freeze-check passed"),
            ("test_uagb1_tblind", "TBlindCertificate", "test_composed_p2_blind_smoke", "accept true T_blind"),
            ("test_zkmatrix_native_backends", "NativeBackendTests", "test_ring_freeze_check", "freeze-check passed"),
        ]
        for module_name, class_name, method_name, output in cases:
            module = importlib.import_module(module_name)
            case = getattr(module, class_name)(method_name)
            method = getattr(case, method_name)
            self.assertFalse(getattr(method, "__unittest_skip__", False), "fixture gate must not silently skip")
            result = subprocess.CompletedProcess([], 0, output, "")
            env = {"M125_EXPORT_DIR": "/independently/validated/export"}
            with self.subTest(method=method_name), patch.object(module, "m125_environment", return_value=env) as select, patch.object(module.subprocess, "run", return_value=result) as run:
                method()  # Mocked direct call; no setUpClass build or native subprocess.
                select.assert_called_once()
                self.assertEqual(run.call_args.kwargs["env"], env)


if __name__ == "__main__":
    unittest.main()
