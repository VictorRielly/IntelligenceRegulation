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
VOC0 = "/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32"
DG = "/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_dg_rot1_voc0_T128"
SCAN_DG = ("/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/runs/llama3-8b/"
           "vocab0_llama3_8b_dg_rot1_voc0_T128.json")
B7VOC0_T128 = "/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T128"
SCAN_VOC0 = ("/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/runs/llama3-8b/"
             "vocab0_llama3_8b_pg_rot1_b7voc0_T32.json")


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
            # review TR5-2: "clear" prints what it covers and what it does not
            self.assertIn("norm_a / Q / K / V / RoPE", ev[-1]["scope"])
            self.assertIn("attention scores", ev[-1]["not_covered"])
            self.assertIn("later layers", ev[-1]["not_covered"])

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

    def test_rope_tables_beyond_the_scanned_positions_are_not_covered(self):
        # review TR5-2 (b): `check` itself requires the export's RoPE tables to be
        # a byte prefix of the scanned export's (positions a subset of the scanned)
        with tempfile.TemporaryDirectory() as td:
            for case in ("flipped", "longer"):
                fake = os.path.join(td, case)
                os.makedirs(os.path.join(fake, "layer_00"))
                src = T128 if case == "longer" else T32
                for n in ("manifest.json", "gamma_a.bin", "wq.bin", "wk.bin", "wv.bin", "rope_cos.bin", "rope_sin.bin"):
                    shutil.copyfile(os.path.join(src, "layer_00", n), os.path.join(fake, "layer_00", n))
                os.symlink(os.path.join(T32, "token_io"), os.path.join(fake, "token_io"))
                with open(os.path.join(fake, "layer_00", "rope_cos.bin"), "r+b") as f:
                    if case == "flipped":
                        b = f.read(1)
                        f.seek(0)
                        f.write(bytes([b[0] ^ 1]))
                    else:
                        f.seek(0, 2)
                        f.write(b"\0" * 512)
                rc, ev, _ = run("check", "--export", fake, "--prompt", "128000,662")
                self.assertEqual(rc, 0, case)
                self.assertEqual(ev[-1]["status"], "not-covered", case)
                self.assertIn("RoPE", ev[-1]["note"], case)

    def test_the_recalibrated_export_has_no_layer0_refusal(self):
        # round 7: the fidelity lane's b7voc0 export (layer-0 vocabulary
        # recalibration) has its own scan, with no refusing token
        p = ho00()
        p[1], p[3] = 662, 16309
        for prompt in (None, ",".join(map(str, p))):
            args = ("check", "--export", VOC0) + (("--seq", "ho00") if prompt is None else ("--prompt", prompt))
            rc, ev, _ = run(*args)
            self.assertEqual(rc, 0)
            self.assertEqual(ev[-1]["status"], "clear")
            self.assertEqual(ev[-1]["known_refusing"], [])
            self.assertEqual(ev[-1]["scan"], SCAN_VOC0)

    def test_the_t128_exports(self):
        # round 8: dg_rot1_voc0_T128 is covered by its own scan (clear, nothing
        # refusing); b7voc0_T128's layer 0 matches a scanned variant's but its
        # RoPE tables are not a prefix of that variant's, so it is NOT covered
        rc, ev, _ = run("check", "--export", DG, "--seq", "ho00")
        self.assertEqual((rc, ev[-1]["status"], ev[-1]["known_refusing"]), (0, "clear", []))
        rc, ev, _ = run("check", "--export", B7VOC0_T128, "--seq", "ho00")
        self.assertEqual((rc, ev[-1]["status"]), (0, "not-covered"))

    def test_the_prompt_comes_from_a_0600_file_never_the_command_line_round9(self):
        # round 9 (privacy review round 4, PR4-17): the demo hands the
        # pre-check the prompt as a file only its owner can read; a file
        # readable by group or others is refused, naming the mode
        p = ho00()
        p[1], p[3] = 662, 16309
        d = tempfile.mkdtemp(prefix="l0pf-")
        try:
            f = os.path.join(d, "prompt")
            fd = os.open(f, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.write(fd, (",".join(map(str, p)) + "\n").encode())
            os.close(fd)
            rc, ev, err = run("check", "--export", T32, "--prompt-file", f)
            self.assertEqual(rc, 2, err)
            self.assertIn('prompt token 662 " ."', err)
            rc, ev, _ = run("check", "--export", VOC0, "--prompt-file", f)
            self.assertEqual((rc, ev[-1]["status"], ev[-1]["prompt_tokens"]), (0, "clear", 32))
            os.chmod(f, 0o640)
            rc, ev, err = run("check", "--export", VOC0, "--prompt-file", f)
            self.assertEqual(rc, 1)
            self.assertIn("0600", err)
            self.assertEqual(ev, [])
        finally:
            shutil.rmtree(d)

    def test_recorded_list_points_at_the_scan(self):
        with open(LIST) as f:
            lst = json.load(f)
        self.assertEqual([x["scan"] for x in lst["entries"]], [SCAN, SCAN_VOC0, SCAN_DG])
        # round 8: the 8B dg_rot1_voc0_T128 export's own scan, no refusing token
        self.assertEqual(lst["entries"][2]["refusing"], [])
        self.assertEqual(lst["entries"][2]["exports_matched_at_record"], [DG])
        e = lst["entries"][0]
        self.assertEqual([r["token"] for r in lst["entries"][1]["refusing"]], [])
        self.assertEqual(lst["entries"][1]["exports_matched_at_record"], [VOC0])
        self.assertEqual(e["scan"], SCAN)
        self.assertEqual([r["token"] for r in e["refusing"]], [662, 16309])
        self.assertEqual(e["exports_matched_at_record"], [T128, T32])
        for a in ("rope_cos", "rope_sin"):
            self.assertEqual(len(e["rope_prefix_sha256"][a]), 128)


if __name__ == "__main__":
    unittest.main()
