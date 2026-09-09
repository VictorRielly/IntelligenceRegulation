"""Round 15: cached clean facts must not authorize a changed checkout."""
import copy
from contextlib import redirect_stderr, redirect_stdout
import io
import os
from pathlib import Path
import tempfile
import unittest

from test_hashline_cl_gpu_gates import gg, make_checkout, git, record_of
from test_hashline_cl_5090_preflight import ready_facts, evaluate, check


class LiveCheckout(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(make_checkout(os.path.join(self.tmp.name, "repo")))
        self.initial = gg.probe_source_identity(str(self.repo))

    def cli(self, *argv):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            rc = gg.main(list(argv))
        return rc, output.getvalue()

    def check_binding(self, expected, reason=""):
        for version in (4, 5):
            for command in ("validate", "finalize"):
                with self.subTest(version=version, command=command):
                    manifest = gg.synthetic_manifest(suite_version=version, head=self.initial["head"],
                                                     source_identity=self.initial)
                    path = os.path.join(self.tmp.name, "manifest.json")
                    gg.save_manifest(manifest, path)
                    argv = [command] + (["--manifest"] if command == "finalize" else [])
                    rc, output = self.cli(*argv, path, "--repo", str(self.repo))
                    self.assertEqual(rc, 0 if expected else 1, output)
                    if reason:
                        self.assertIn(reason, output)
                    if command == "finalize":
                        self.assertEqual(gg.load_manifest(path)["verdict"]["green"], expected)

    def test_clean_checkout_binds(self):
        self.check_binding(True)

    def test_core_edit_after_initialization_refuses(self):
        (self.repo / "zkp-core/src/lib.rs").write_text("pub fn changed() {}\n")
        # This edit changes neither HEAD's tree IDs nor either lockfile.
        self.assertEqual(gg.identity_expectations(self.initial),
                         gg.identity_expectations(gg.probe_source_identity(str(self.repo))))
        self.check_binding(False, "live checkout: uncommitted changes under zkp-core/")

    def test_hashline_edit_after_initialization_refuses(self):
        (self.repo / "hashline/src/main.rs").write_text("fn main() { panic!(); }\n")
        self.check_binding(False, "live checkout: uncommitted changes under hashline/")

    def test_deleted_core_example_refuses(self):
        (self.repo / "zkp-core/examples/public_sumcheck.rs").unlink()
        self.check_binding(False, "live checkout: crate zkp-core/ is missing")

    def test_new_automatic_core_build_script_refuses(self):
        (self.repo / "zkp-core/build.rs").write_text("fn main() {}\n")
        self.check_binding(False, "untracked build inputs under zkp-core/")

    def test_new_automatic_hashline_build_script_refuses(self):
        (self.repo / "hashline/build.rs").write_text("fn main() {}\n")
        self.check_binding(False, "untracked build inputs under hashline/")

    def test_moved_head_with_identical_crates_refuses(self):
        git(str(self.repo), "commit", "--allow-empty", "-m", "new source pin")
        self.assertEqual(gg.identity_expectations(self.initial),
                         gg.identity_expectations(gg.probe_source_identity(str(self.repo))))
        self.check_binding(False, "live checkout HEAD")

    def test_missing_live_untracked_probe_refuses(self):
        live = copy.deepcopy(self.initial)
        del live["crates"]["zkp_core"]["untracked_paths"]
        m = gg.synthetic_manifest(suite_version=5, head=self.initial["head"], source_identity=self.initial)
        result = gg.validate_manifest(m, expect_source=live)
        self.assertFalse(result["ok"])
        self.assertTrue(any("untracked build inputs" in r for r in result["reasons"]))


class SuiteFive(unittest.TestCase):
    def test_v5_adds_current_counts_and_preserves_v4(self):
        self.assertEqual(gg.case_definition(4, "core_tests")["expect"]["passed"], 19)
        self.assertEqual(gg.case_definition(5, "core_tests")["expect"]["passed"], 22)
        self.assertEqual(gg.case_definition(5, "storage_tests")["expect"]["passed"], 210)
        self.assertEqual(len(gg.expected_cases(4)), 23)
        self.assertEqual(len(gg.expected_cases(5)), 24)
        self.assertTrue(gg.validate_manifest(gg.synthetic_manifest(suite_version=5))["ok"])

    def test_missing_storage_case_refuses(self):
        m = gg.synthetic_manifest(suite_version=5)
        m["cases"].remove(record_of(m, "storage_tests"))
        self.assertFalse(gg.validate_manifest(m)["ok"])

    def test_storage_count_is_recomputed(self):
        m = gg.synthetic_manifest(suite_version=5)
        record_of(m, "storage_tests")["test_results"][0]["passed"] -= 1
        self.assertFalse(gg.validate_manifest(m)["ok"])

    def test_storage_feature_and_lock_flags_are_recomputed(self):
        for flag in ("--features", "--locked", "--offline", "--manifest-path"):
            m = gg.synthetic_manifest(suite_version=5)
            record_of(m, "storage_tests")["argv"].remove(flag)
            with self.subTest(flag=flag):
                self.assertFalse(gg.validate_manifest(m)["ok"])

    def test_legacy_record_without_untracked_probe_remains_readable(self):
        identity = copy.deepcopy(gg.SYNTHETIC_SOURCE)
        for c in identity["crates"].values():
            del c["untracked_paths"]
        self.assertTrue(gg.validate_manifest(gg.synthetic_manifest(suite_version=4, source_identity=identity))["ok"])
        self.assertFalse(gg.validate_manifest(gg.synthetic_manifest(suite_version=5, source_identity=identity))["ok"])

    def test_preflight_dirty_or_untracked_core_refuses_artifact(self):
        for change in ({"dirty_delta_sha256": "a" * 64}, {"untracked_paths": ["zkp-core/build.rs"]}):
            facts = ready_facts()
            facts["source_identity"]["crates"]["zkp_core"].update(change)
            report = evaluate(facts)
            self.assertFalse(check(report, "source_identity")["ok"])
            self.assertFalse(check(report, "verified_artifact")["ok"])
