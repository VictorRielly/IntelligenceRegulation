"""Falsification controls for scripts/zk60_mvp_security_probe.py.

These tests bind the MVP security decision memo to the source at HEAD and to
exact field arithmetic. They are controls, not whole-proof privacy acceptance.
`FullRun` executes the complete probe and, if ZK60_MVP_PROBE_OUT names a new
path, writes the probe's record there (evidence is never overwritten).
"""
import json
import os
import random
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import zk60_mvp_security_probe as probe  # noqa: E402
import zk60_io_cfs_composition as cfs  # noqa: E402

C = probe.C
P, ZERO, ONE = probe.P, probe.ZERO, probe.ONE
CAPTURES = probe.DEFAULT_CAPTURES
RECORD = ROOT / "results/zk60_mvp_security_decision.json"


def captures_readable():
    try:
        paths = sorted(CAPTURES.glob("*.json"))
        return len(paths) == 4 and all(
            p.with_suffix(".receipt").exists() and p.with_suffix(".expected").exists() for p in paths)
    except OSError:
        return False


def rng(seed):
    return random.Random(seed).randrange


class SourceBound(unittest.TestCase):
    def test_pins_match_round22_manifest(self):
        r = probe.check_source_pins()
        self.assertEqual(len(r["pinned"]), 10)
        self.assertTrue(r["all_pinned_match"], [x for x in r["pinned"] if not x["match"]])
        self.assertEqual(r["manifest_source_commit"], "1f0ff3680c4cda88f1744343e24eb93cdddfcba4")

    def test_every_challenge_follows_fresh_a_root(self):
        r = probe.check_schedule_order()
        zk = r["zk_rs"]
        self.assertLess(zk["a_root_absorb_line"], zk["m_root_absorb_line"])
        self.assertLess(zk["m_root_absorb_line"], zk["first_challenge_line"])
        self.assertTrue(all(line > zk["a_root_absorb_line"] for line in zk["challenge_lines"]))
        self.assertFalse(zk["seeded_rng_reachable"])
        self.assertTrue(r["every_challenge_follows_fresh_a_root"])
        self.assertGreater(len(r["zk_ffn_fresh_io_rs"]["finish_challenge_lines"]), 0)

    def test_refusal_inventory_resolves_and_isolates_witness_dependence(self):
        r = probe.check_refusal_inventory()
        self.assertEqual(len(r["rows"]), len(probe.REFUSALS))
        witness = r["witness_dependent_rows"]
        self.assertEqual(sorted(w["path"] for w in witness), ["hashline/src/zk.rs", "zkp-core/src/field.rs"])
        self.assertEqual(sorted(r["classes"]), ["challenge-only", "entropy-failure", "input-validity", "public-policy",
                                                "statement-shape", "static-layout", "witness-and-challenge (negligible)"])

    def test_owner_api_forbids_external_roots(self):
        r = probe.check_owner_api()
        self.assertTrue(all(v is True for k, v in r.items() if k != "conclusion"))

    def test_fn_body_parser_on_synthetic_text(self):
        text = "use x;\n\npub fn alpha(a: u8) {\n    tr.challenge_fp2();\n}\n\nfn beta() {\n    absorb_com(tr, b\"A\", x);\n}\n"
        body, line0 = probe._fn_body(text, "alpha")
        self.assertEqual(line0, 3)
        self.assertIn("challenge_fp2", body)
        self.assertNotIn("absorb_com", body)
        self.assertEqual(probe._lines_with(body, line0, "tr.challenge_"), [4])
        with self.assertRaises(ValueError):
            probe._fn_body(text, "gamma")


class ZeroWitnessAlgebra(unittest.TestCase):
    def test_solver_consistent_and_inconsistent(self):
        rows = [[ONE, ONE, ZERO], [ZERO, ONE, ONE]]
        x, kernel = probe.solve(rows, [(3, 0), (5, 0)])
        self.assertEqual(kernel, 1)
        self.assertEqual([C.f2_dot(r, x) for r in rows], [(3, 0), (5, 0)])
        self.assertIsNone(probe.solve([[ONE, ONE], [ONE, ONE]], [(1, 0), (2, 0)]))
        x, kernel = probe.solve([[ONE, ZERO], [ZERO, ONE]], [(7, 1), (2, 9)])
        self.assertEqual((x, kernel), ([(7, 1), (2, 9)], 0))

    def test_imported_mask_round_arithmetic_is_self_consistent(self):
        r = rng(11)
        coeffs = [probe.random_fp2(r) for _ in range(C.cfs_len(probe.IO_N, probe.IO_D))]
        rho = [probe.random_fp2(r) for _ in range(probe.IO_N)]
        for j in range(probe.IO_N):
            fast = C.cfs_round(coeffs, probe.IO_N, probe.IO_D, j, rho[:j])
            brute = C.cfs_round_brute(coeffs, probe.IO_N, probe.IO_D, j, rho[:j])
            self.assertEqual(fast, brute)
            weights = C.cfs_round_weights(probe.IO_N, probe.IO_D, j, rho[:j])
            self.assertEqual([C.f2_dot(w, coeffs) for w in weights], fast)

    def test_honest_equal_planes_replay_and_zero_witness_preimage(self):
        for seed in (1, 2, 3):
            arg = probe.synthetic_case(rng(seed))
            self.assertIsNotNone(cfs.replay(arg))
            res = probe.io_zero_witness_preimage(arg)
            self.assertTrue(res["preimage_exists"])
            self.assertEqual(res["kernel_dim_fp2"], 1)
            self.assertEqual((res["equations"], res["unknowns"]), (32, 22))
            controls = probe.io_negative_controls(arg)
            self.assertEqual(len(controls), 5)
            self.assertTrue(all(not c["preimage_exists"] for c in controls))

    def test_zero_witness_rebuild_accepts_with_fresh_pair_values(self):
        arg = probe.synthetic_case(rng(4))
        rows, rhs, aux = probe.io_zero_witness_system(arg)
        coeffs, _ = probe.solve(rows, rhs)
        shift = probe.random_fp2(rng(5))
        ext = [C.f2_add(aux["ext"][0], shift), C.f2_add(aux["ext"][1], shift)]
        rebuilt = probe.zero_witness_io_argument(arg, coeffs, ext)
        self.assertIsNotNone(cfs.replay(rebuilt))
        for key in ("gamma", "rounds", "mask_eval", "rho", "tau", "c"):
            self.assertEqual(rebuilt[key], arg[key])
        self.assertNotEqual(rebuilt["terminals"], arg["terminals"])
        # The shifted pair values keep the terminal DIFFERENCE, as the verifier requires.
        e = tuple(arg["rho"][-1])
        for a in (arg, rebuilt):
            diff = C.f2_sub(tuple(a["terminals"][0]), tuple(a["terminals"][1]))
            self.assertEqual(diff, C.f2_mul(e, aux["delta"]))

    def test_zero_planes_match_the_zero_witness_formula_exactly(self):
        r = rng(6)
        tau = [probe.random_fp2(r) for _ in range(probe.IO_N - 1)]
        rho = [probe.random_fp2(r) for _ in range(probe.IO_N)]
        c = probe.random_fp2(r)
        coeffs = [probe.random_fp2(r) for _ in range(C.cfs_len(probe.IO_N, probe.IO_D))]
        ext = [probe.random_fp2(r), probe.random_fp2(r)]
        zeros = [0] * (1 << (probe.IO_N - 1))
        honest = probe.honest_io_argument(tau, c, rho, zeros, zeros, coeffs, ext)
        formula = probe.zero_witness_io_argument(honest, coeffs, ext)
        self.assertEqual(honest, formula)

    def test_unequal_planes_are_refused_and_have_no_zero_witness_preimage(self):
        wrong = probe.synthetic_case(rng(7), equal=False)
        with self.assertRaises(ValueError):
            cfs.replay(wrong)
        rows, rhs, _ = probe.io_zero_witness_system(wrong)
        self.assertIsNone(probe.solve(rows, rhs))


class Captures(unittest.TestCase):
    @unittest.skipUnless(captures_readable(),
                         "round-22 capture triplets not readable from this session: evidence gap, not a pass")
    def test_capture_checks(self):
        r = probe.capture_checks(CAPTURES)
        self.assertEqual(len(r["cases"]), 4)
        self.assertEqual(sorted(c["privacy"] for c in r["cases"]), ["P1", "P1", "P3", "P3"])
        for case in r["cases"]:
            self.assertTrue(case["mask"]["joint_full_rank"])
            self.assertEqual(case["mask"]["functionals"], 14)
            self.assertEqual(case["mask"]["programmed_points_zero_witness_simulator"], 0)
            self.assertEqual([a["slot"] for a in case["io_arguments"]], [6, 7])
            for a in case["io_arguments"]:
                self.assertTrue(a["preimage_exists"])
                self.assertEqual(a["kernel_dim_fp2"], 1)
                self.assertTrue(all(not x["preimage_exists"] for x in a["controls"]))
            self.assertEqual([e["role"] for e in case["endpoints"]], ["Input", "Output"])
            for e in case["endpoints"]:
                self.assertTrue(e["zero_witness_preimage"])
                self.assertEqual(e["message_free_dim"], 256)
                self.assertEqual(e["pad_free_dim"], 3 * (256 - e["distinct_columns"]))


class FullRun(unittest.TestCase):
    """Run the whole probe; optionally write its record to a NEW path named by
    ZK60_MVP_PROBE_OUT. The decision record at results/zk60_mvp_security_decision.json
    is a hand-written decision file, not this probe's output, and is never touched."""

    def test_full_run_and_optional_record(self):
        result = probe.run(CAPTURES if captures_readable() else None)
        self.assertTrue(result["source_pins"]["all_pinned_match"])
        self.assertTrue(result["schedule"]["every_challenge_follows_fresh_a_root"])
        self.assertTrue(result["synthetic"]["honest_equal_planes"]["preimage_exists"])
        self.assertFalse(result["synthetic"]["unequal_planes"]["zero_witness_preimage_exists"])
        self.assertEqual(result["decision"]["oracle_points_programmed"], 0)
        self.assertFalse(result["decision"]["whole_proof_privacy_accepted"])
        out = os.environ.get("ZK60_MVP_PROBE_OUT")
        if out:
            with Path(out).open("x") as stream:
                json.dump(result, stream, indent=2)
                stream.write("\n")
        # Deterministic sections must agree with the decision record's source pins.
        if RECORD.exists():
            record = json.loads(RECORD.read_text())
            pins = record["source_pins_verified_by_sha256sum_in_session"]["head_matches_manifest"]
            head = {row["path"]: row["head"] for row in result["source_pins"]["pinned"]}
            for path, digest in pins.items():
                self.assertEqual(head[path], digest, path)


if __name__ == "__main__":
    unittest.main()
