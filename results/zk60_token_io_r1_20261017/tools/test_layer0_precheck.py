"""Tests for tools/layer0_precheck.py on the real 8B b7 exports (no skips: a missing export fails)."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "layer0_precheck.py")
LIST = os.path.join(HERE, "layer0_refusals.json")
X = "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/"
T32 = X + "llama3_8b_pg_rot1_b7_T32"
T128 = X + "llama3_8b_pg_rot1_b7_T128"
VCOPY = os.path.join(os.path.dirname(HERE), "cli", "verifier-export-llama3_8b_pg_rot1_b7_T32")
SCAN = ("/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/runs/llama3-8b/"
        "vocab0_llama3_8b_pg_rot1_b7_T128.json")


def run(*a):
    p = subprocess.run([sys.executable, TOOL, *a], capture_output=True, text=True)
    return p.returncode, [json.loads(x) for x in p.stdout.splitlines() if x.startswith("{")], p.stderr


def ho00():
    with open(os.path.join(T32, "seq_ho00", "manifest.json")) as f:
        return json.load(f)["token_ids"]


class Layer0Precheck(unittest.TestCase):
    def test_demo_prompts_are_clear(self):
        for seq in ("ho00", "ho09"):
            rc, ev, _ = run("check", "--export", T32, "--seq", seq)
            self.assertEqual(rc, 0)
            self.assertEqual(ev[-1]["status"], "clear")
            self.assertEqual(ev[-1]["known_refusing"], [662, 16309])
            self.assertEqual(ev[-1]["prompt_tokens"], 32)

    def test_listed_tokens_refused_by_name_before_proving(self):
        p = ho00()
        p[1], p[3], p[7] = 662, 16309, 662
        for ex in (T32, T128, VCOPY):
            rc, ev, err = run("check", "--export", ex, "--prompt", ",".join(map(str, p)))
            self.assertEqual(rc, 2, ex)
            self.assertEqual([(e["token"], e["text"], e["positions"], e["sites"]) for e in ev],
                             [(662, " .", [1, 7], ["V"]), (16309, "Tags", [3], ["V"])])
            self.assertIn('prompt token 662 " ."', err)
            self.assertIn('prompt token 16309 "Tags"', err)
            self.assertIn("layer-0 recalibrated export", err)

    def test_other_layer0_not_covered_and_record_refuses_it(self):
        with tempfile.TemporaryDirectory() as td:
            fake = os.path.join(td, "export")
            os.makedirs(os.path.join(fake, "layer_00"))
            for n in ("manifest.json", "gamma_a.bin", "wq.bin", "wk.bin", "wv.bin", "rope_cos.bin", "rope_sin.bin"):
                shutil.copyfile(os.path.join(T32, "layer_00", n), os.path.join(fake, "layer_00", n))
            os.symlink(os.path.join(T32, "token_io"), os.path.join(fake, "token_io"))
            with open(os.path.join(fake, "layer_00", "wv.bin"), "r+b") as f:
                b = f.read(1)
                f.seek(0)
                f.write(bytes([b[0] ^ 1]))
            rc, ev, _ = run("check", "--export", fake, "--prompt", "128000,662,16309")
            self.assertEqual(rc, 0)
            self.assertEqual(ev[-1]["status"], "not-covered")
            out = os.path.join(td, "list.json")
            rc, _, err = run("record", "--scan", SCAN, "--also-export", fake, "--out", out)
            self.assertEqual(rc, 1)
            self.assertIn("matches no scanned export", err)
            self.assertFalse(os.path.exists(out))

    def test_recorded_list_points_at_the_scan(self):
        with open(LIST) as f:
            lst = json.load(f)
        (e,) = lst["entries"]
        self.assertEqual(e["scan"], SCAN)
        self.assertEqual([r["token"] for r in e["refusing"]], [662, 16309])
        self.assertEqual(e["exports_matched_at_record"], [T128, T32])


if __name__ == "__main__":
    unittest.main()
