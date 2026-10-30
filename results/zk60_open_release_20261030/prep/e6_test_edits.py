#!/usr/bin/env python3
"""E6: make the staging Python suite clean for a stranger, without weakening any assertion.

(a) development-only input  -> a skip guard that names the input and how to produce it
(b) older main-tree hashline -> repoint to the shipped round-16b tree (none applicable, see TSV)
(c) private-repo-only test   -> removed from staging (prep/removed_tests.tsv)
Every edit is an exact replacement with an asserted count; whole-file removals are moved to
the scratchpad. Usage: python3 -I e6_test_edits.py <staging root> <removed-files dir>
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
GONE = Path(sys.argv[2])
T = ROOT / "tests"
changed = {}


def text(name):
    return changed.get(name) if name in changed else (T / name).read_text()


def rep(name, old, new, n=1):
    s = text(name)
    c = s.count(old)
    if c != n:
        sys.exit(f"{name}: expected {n} x {old[:70]!r}, found {c}")
    changed[name] = s.replace(old, new)


def cut(name, start, end_marker):
    """remove from the line starting `start` up to (not including) the line starting end_marker"""
    s = text(name)
    a = s.index(start)
    assert s.count(start) == 1, (name, start)
    b = s.index(end_marker, a + len(start))
    changed[name] = s[:a] + s[b:]


# ---------------------------------------------------------------- (a) skip guards
INV = ("needs results/zk60_opus_attention_inventory.json (a development record, not shipped). "
       "Produce it from this tree: python3 scripts/zk60_opus_attention_inventory.py "
       "--out results/zk60_opus_attention_inventory.json (its source pin, hashline/src/attention.rs "
       "sha256 c5ae80dd..., is the shipped file)")
rep("test_zk60_attention_cfs_slots.py", "def setUpModule():\n",
    "def setUpModule():\n"
    "    if not INVENTORY.is_file():\n"
    f"        raise unittest.SkipTest({INV!r})\n")
for cls in ("GroupReconstruction", "Schedule", "Engine", "PositiveVerdicts", "NegativeControls",
            "Determinism", "CLI"):
    rep("test_zk60_attention_pair_schedule.py", f"\nclass {cls}(unittest.TestCase):\n",
        f"\n@unittest.skipUnless(INVENTORY.is_file(), _NO_INVENTORY)\nclass {cls}(unittest.TestCase):\n")
rep("test_zk60_attention_pair_schedule.py",
    'INVENTORY = ROOT / "results" / "zk60_opus_attention_inventory.json"\n',
    'INVENTORY = ROOT / "results" / "zk60_opus_attention_inventory.json"\n'
    f"_NO_INVENTORY = {INV!r}\n")

rep("test_zk60_endpoint_view.py", "    def test_plan_does_not_read_captured_output_values(self):\n",
    '    @unittest.skipUnless(len(list((V.ROOT/"results/zk60_round22_captures").glob("*.json"))) == 4,\n'
    '                         "needs the 4 retained round-22 IO validation captures in results/zk60_round22_captures/ "\n'
    '                         "(development captures, not shipped; made by the round-22 capture run, "\n'
    '                         "docs/zkmatrix-poc/ZK60_ROUND22.md)")\n'
    "    def test_plan_does_not_read_captured_output_values(self):\n")

rep("test_zk60_fable_transcript_sim.py", "    def test_disposition_record_matches_generator(self):\n",
    '    @unittest.skipUnless((ROOT / "results/zk60_fable_fa8_disposition.json").exists(),\n'
    '                         "needs the archived record results/zk60_fable_fa8_disposition.json (not shipped); "\n'
    '                         "write it with: python3 scripts/zk60_fable_transcript_sim.py disposition "\n'
    '                         "-o results/zk60_fable_fa8_disposition.json")\n'
    "    def test_disposition_record_matches_generator(self):\n")

rep("test_zk60_io_review_gate.py", "\nclass ReviewAcceptance(unittest.TestCase):\n",
    '\n@unittest.skipUnless((gate.ROOT / "results/zk60_opus_io_capture_analysis.json").is_file()\n'
    '                     and (gate.ROOT / "results/zk60_round19_validation.json").is_file(),\n'
    '                     "needs results/zk60_opus_io_capture_analysis.json and results/zk60_round19_validation.json "\n'
    '                     "(development records, not shipped). Produce the analysis with "\n'
    '                     "python3 scripts/zk60_opus_io_capture.py analyze --captures-dir <round-19 native captures> "\n'
    '                     "--manifest results/zk60_round19_validation.json -o results/zk60_opus_io_capture_analysis.json")\n'
    "class ReviewAcceptance(unittest.TestCase):\n")

SAVED = ("    @unittest.skipUnless(all((demo.ROOT / 'results/zk60_loop_20260918/token-integration/token_public' / f).is_file()\n"
         "                             for f in ('receipt.bin', 'policy.bin')),\n"
         "                         'needs the retained Groth16 public artifacts results/zk60_loop_20260918/'\n"
         "                         'token-integration/token_public/{receipt.bin,policy.bin} (development evidence, not '\n"
         "                         'shipped; intended as release assets)')\n")
for test in ("test_verifier_crash_is_not_rejection", "test_exit_one_with_success_json_is_not_rejection"):
    rep("test_zk60_techweek_demo.py", f"    def {test}(self):\n", SAVED + f"    def {test}(self):\n")

rep("test_zkmatrix_native_backends.py", "from regression_fixtures import m125_environment\n",
    "from regression_fixtures import FixtureConfigurationError, m125_environment\n")
rep("test_zkmatrix_native_backends.py",
    "        # one gate (the F3 guard): any parameter move must keep this green.\n"
    "        result = subprocess.run(\n"
    "            [str(RING_MATMUL_BINARY), \"freeze-check\"],\n"
    "            check=True,\n"
    "            text=True,\n"
    "            stdout=subprocess.PIPE,\n"
    "            env=m125_environment(ROOT),\n"
    "        )\n",
    "        # one gate (the F3 guard): any parameter move must keep this green.\n"
    "        try:\n"
    "            env = m125_environment(ROOT)\n"
    "        except FixtureConfigurationError as missing:\n"
    "            self.skipTest(\"needs a complete local 125M FFN export (development input, not shipped; \"\n"
    "                          \"set M125_EXPORT_DIR, or build one with scripts/m8b_export_ffn.py --arch frugal \"\n"
    "                          f\"from the frugal-lm 125M checkpoint): {missing}\")\n"
    "        result = subprocess.run(\n"
    "            [str(RING_MATMUL_BINARY), \"freeze-check\"],\n"
    "            check=True,\n"
    "            text=True,\n"
    "            stdout=subprocess.PIPE,\n"
    "            env=env,\n"
    "        )\n")

# ---------------------------------------------------------------- (c) removals inside files
cut("test_hashline_cl_gpu_gates.py", "class FloorsRunner(unittest.TestCase):\n", 'if __name__ == "__main__":')
cut("test_hashline_cl_profile.py", "    def test_the_archived_sample_parses_as_eligible(self):\n",
    "\n\nclass Cache(unittest.TestCase):")
cut("test_zk60_guarded_command.py", "class LegacyLauncherTests(unittest.TestCase):\n", "if __name__ == '__main__':")
for m in ("test_pins_match_round22_manifest", "test_reviewed_source_keeps_the_archived_producer_identity",
          "test_unknown_source_drift_still_refuses_with_a_reviewed_update",
          "test_rewriting_the_capture_pin_cannot_masquerade_as_review"):
    cut("test_zk60_mvp_security_probe.py", f"    def {m}(self):\n", "    def test_")
cut("test_zk60_mvp_security_probe.py", "    def test_diagnostic_does_not_close_security_requirements(self):\n",
    'if __name__ == "__main__":')

for name, s in changed.items():
    (T / name).write_text(s)

# ---------------------------------------------------------------- (c) whole-file removals
GONE.mkdir(parents=True, exist_ok=True)
for name in ("test_zk60_budgeted_endpoint_boundary.py", "test_zk60_mvp_baseline.py",
             "test_zk60_private_block_inventory.py"):
    shutil.move(str(T / name), str(GONE / name))
print("edited:", *sorted(changed), sep="\n  ")
print("removed files:", 3)
