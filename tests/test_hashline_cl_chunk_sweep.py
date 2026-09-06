"""[ZK60-CL6] Tests for the chunk-row sweep and selector.

Pure arithmetic and log parsing: no GPU, no nvidia-smi, no subprocess. The
device rules being mirrored are quoted from hashline/src/gpu/cuda.rs in the
module under test; the tests pin the mirror against those rules, including
the corner where the choice is not a multiple of 128.
"""

import importlib.util
import json
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_chunk_sweep.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_chunk_sweep", _SRC)
sweep = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = sweep
_spec.loader.exec_module(sweep)

MIB = 1024 ** 2
MISTRAL_ROWS = 10774   # d 4096 / f 14336 at log_cols 14: 10752 data + 21 masks + 1 prox


def log_text(sha, nbytes, prove=4.0, gpu_on=True, verified=True, commits=(), reencs=(), vram=5182, privacy="P3"):
    head = "  gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)\n" if gpu_on else "  gpu: off (HL_GPU unset)\n"
    body = ""
    for rows, chunks, rmax, secs in commits:
        body += f"[ZK60-CL1]   zk commit rows {rows} 2^14 -> 2^16 (q 256, 5649 MB resident): CHUNKED (by size)\n"
        body += f"[ZK60-CL1]   chunked ZK commit rows {rows} 2^14 -> 2^16 (q 256) in {chunks} chunks of <= {rmax}: {secs:.4f} s\n"
    for rows, chunks, secs in reencs:
        body += f"[ZK60-CL1]   chunked ZK re-encode + gather rows {rows} ({chunks} chunks): {secs:.4f} s\n"
    body += f"  layer  0: prove {prove:.3f} s, {nbytes} B\n"
    body += f"  gpu device-side (summed): h2d 0.3 s (674 MB) | ntt 0.6 s | hash 0.2 s | sumcheck 0.2 s | fold 0.1 s | helpers 0.1 s | d2h 0.000 s (46 MB) | vram peak {vram} MB\n"
    body += f"PROOF sha256 {sha} ({nbytes} B) [ZK v3 randomness deterministic-test]\n"
    timing = {"schema": 1, "coverage": "ffn-only", "privacy": privacy, "layers": 1, "tokens": 512, "d": 4096, "f": 14336,
              "witness_s": 3.3, "prove_s": prove, "serialize_s": 0.05, "proof_ready_s": prove + 3.35, "verify_s": 0.06,
              "verified": verified, "proof_bytes": nbytes, "serialized": True, "gpu_requested": True, "gpu_enabled": gpu_on}
    body += "HASHLINE_TIMING " + json.dumps(timing) + "\n"
    return head + body


SHA_A = "1" * 64
SHA_B = "2" * 64


class DeviceMirror(unittest.TestCase):
    def test_choice_is_clamped_to_128_not_rounded(self):
        self.assertEqual(sweep.effective_chunk_rows(1), 128)
        self.assertEqual(sweep.effective_chunk_rows(100), 128)
        self.assertEqual(sweep.effective_chunk_rows(300), 300)   # chunk_rows() does not round
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.effective_chunk_rows(0)
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.effective_chunk_rows(2.5)

    def test_plan_steps_by_the_rounded_count_with_a_ragged_tail(self):
        self.assertEqual(sweep.chunk_plan(700, 256), [(0, 256), (256, 256), (512, 188)])
        self.assertEqual(sweep.chunk_plan(700, 300), [(0, 256), (256, 256), (512, 188)])  # 300 -> step 256
        self.assertEqual(sweep.chunk_plan(256, 128), [(0, 128), (128, 128)])

    def test_rows_at_or_under_the_choice_are_one_chunk_of_all_rows(self):
        # THE corner: rows <= the UNROUNDED choice -> the device allocates
        # scratch for every row, not for the rounded step.
        self.assertEqual(sweep.chunk_plan(300, 300), [(0, 300)])
        self.assertEqual(sweep.rmax_for(300, 300), 300)
        self.assertEqual(sweep.rmax_for(100, 128), 100)
        self.assertEqual(sweep.rmax_for(1000, 300), 256)

    def test_the_cl3_planner_now_agrees_with_the_device_in_that_corner(self):
        report = sweep.memplan.commitment_plan(300, 10, 4, 16, mode="chunked", chunk_rows=300)
        self.assertEqual(report["chunk_rows"], 300)
        report = sweep.memplan.commitment_plan(1000, 10, 4, 16, mode="chunked", chunk_rows=300)
        self.assertEqual(report["chunk_rows"], 256)
        # and the unchanged cases stay unchanged
        report = sweep.memplan.commitment_plan(300, 10, 4, 16, mode="chunked", chunk_rows=128)
        self.assertEqual(report["chunk_rows"], 128)

    def test_commit_scratch_matches_the_take_min_sizes(self):
        s = sweep.commit_scratch_bytes(MISTRAL_ROWS, 14, 4, 128)
        n, nn = 1 << 14, 1 << 16
        self.assertEqual(s["rmax"], 128)
        self.assertEqual(s["coef"], 128 * n * 8)
        self.assertEqual(s["coef2"], 128 * nn * 8)
        self.assertEqual(s["enc"], 128 * nn * 8)
        self.assertEqual(s["blake3_state"], (8 * 24 + 1) * nn * 4)
        self.assertEqual(s["total"], s["coef"] + s["coef2"] + s["enc"] + s["blake3_state"])
        self.assertAlmostEqual(s["total"] / MIB, 16 + 64 + 64 + 48.25, places=2)


class Sweep(unittest.TestCase):
    def test_rows_carry_plan_and_component_peak_per_choice(self):
        rows = sweep.sweep(MISTRAL_ROWS, 14, 4, 256, choices=(128, 256, 512, 1024))
        self.assertEqual([r["chunks"] for r in rows], [85, 43, 22, 11])
        self.assertEqual([r["rmax"] for r in rows], [128, 256, 512, 1024])
        self.assertTrue(all(r["ragged"] for r in rows))
        peaks = [r["component_peak_mib"] for r in rows]
        self.assertEqual(peaks, sorted(peaks))
        # component peak grows by exactly the scratch growth between choices
        for a, b in zip(rows, rows[1:]):
            self.assertEqual(b["component_peak_bytes"] - a["component_peak_bytes"],
                             b["commit_scratch_bytes"] - a["commit_scratch_bytes"])

    def test_duplicate_effective_choices_are_flagged_not_hidden(self):
        rows = sweep.sweep(700, 10, 4, 16, choices=(256, 300), checks=16)
        self.assertFalse(rows[0]["duplicate_of_smaller_choice"])
        self.assertTrue(rows[1]["duplicate_of_smaller_choice"])   # 300 rounds to the same 256-row plan

    def test_a_shape_the_device_cannot_index_is_refused_by_the_planner(self):
        with self.assertRaises(ValueError):
            sweep.sweep(2 ** 31, 14, 4, 256, choices=(128,))


class Selector(unittest.TestCase):
    def test_selection_is_deterministic_and_monotone_in_the_budget(self):
        a = sweep.select(MISTRAL_ROWS, 14, 4, 256, (128, 256, 512, 1024), 300 * MIB)
        b = sweep.select(MISTRAL_ROWS, 14, 4, 256, (128, 256, 512, 1024), 300 * MIB)
        self.assertEqual(a["selected_choice"], b["selected_choice"])
        # 256 rows: coef 32 + coef2 128 + enc 128 + state 48.25 = 336.25 MiB does NOT fit 300;
        # 128 rows: 16 + 64 + 64 + 48.25 = 192.25 MiB does.
        self.assertEqual(a["selected_choice"], 128)

    def test_the_arithmetic_plan_summary_agrees_with_the_enumerated_plan(self):
        for rows, chunk in ((700, 256), (700, 300), (300, 300), (100, 128), (1000, 300), (10774, 128), (256, 128)):
            plan = sweep.chunk_plan(rows, chunk)
            s = sweep.plan_summary(rows, chunk)
            self.assertEqual(s["chunks"], len(plan), (rows, chunk))
            self.assertEqual(s["rmax"], max(rc for _, rc in plan), (rows, chunk))
            self.assertEqual(s["final"], plan[-1][1], (rows, chunk))

    def test_larger_budget_never_selects_fewer_rows(self):
        last = 0
        for budget_mib in (200, 400, 700, 1300, 2600):
            r = sweep.select(MISTRAL_ROWS, 14, 4, 256, (128, 256, 512, 1024), budget_mib * MIB)
            self.assertGreaterEqual(r["selected_rmax"], last)
            last = r["selected_rmax"]
        self.assertEqual(last, 1024)

    def test_selected_rows_fit_and_unfit_rows_are_marked(self):
        r = sweep.select(MISTRAL_ROWS, 14, 4, 256, (128, 256, 512, 1024), 700 * MIB)
        self.assertEqual(r["selected_choice"], 512)
        fits = {c["choice"]: c["fits_budget"] for c in r["candidates"]}
        self.assertEqual(fits, {128: True, 256: True, 512: True, 1024: False})

    def test_unsupported_budgets_are_refused(self):
        for bad in (0, -1, 2.5, "768", None):
            with self.assertRaises(sweep.ChunkSweepError):
                sweep.select(MISTRAL_ROWS, 14, 4, 256, (128,), bad)

    def test_a_budget_not_below_nominal_vram_is_refused(self):
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.select(MISTRAL_ROWS, 14, 4, 256, (128,), 8188 * MIB, device_total_bytes=8188 * MIB)
        self.assertIn("nominal VRAM is not free memory", str(cm.exception))
        # strictly below is allowed
        sweep.select(MISTRAL_ROWS, 14, 4, 256, (128,), 8187 * MIB, device_total_bytes=8188 * MIB)

    def test_an_overflowing_shape_is_refused_rather_than_rounded_down(self):
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.select(MISTRAL_ROWS, 14, 4, 256, (128, 256), 100 * MIB)
        self.assertIn("no candidate fits", str(cm.exception))

    def test_the_module_never_reads_the_device(self):
        with open(_SRC, encoding="utf-8") as fh:
            source = fh.read()
        for forbidden in ("subprocess", "nvidia-smi", "cudarc", "mem_info"):
            self.assertNotIn(forbidden, source)


class Measure(unittest.TestCase):
    def test_identical_proofs_are_tabulated(self):
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860, 4.1, commits=((10774, 85, 128, 0.9),), reencs=((10774, 85, 0.3),)), "128")
        b = sweep.parse_measured_log(log_text(SHA_A, 40251860, 3.9, commits=((10774, 43, 256, 0.8),), reencs=((10774, 43, 0.25),)), "256")
        r = sweep.reconcile([a, b])
        self.assertTrue(r["byte_identical_across_choices"])
        self.assertEqual(r["proof_sha256"], SHA_A)
        self.assertEqual([x["observed_rmax"] for x in r["rows"]], [[128], [256]])
        self.assertAlmostEqual(r["rows"][0]["prove_vs_fastest"], 4.1 / 3.9)
        self.assertEqual(r["rows"][0]["chunked_commit_secs"], 0.9)
        self.assertEqual(r["rows"][1]["chunked_reencode_secs"], 0.25)
        self.assertEqual(r["rows"][0]["vram_peak_mb"], 5182)
        self.assertIn("| 128 |", sweep.markdown(r))

    def test_a_moved_proof_is_refused(self):
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860), "128")
        b = sweep.parse_measured_log(log_text(SHA_B, 40251860), "256")
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([a, b])
        self.assertIn("MOVED THE PROOF", str(cm.exception))
        c = sweep.parse_measured_log(log_text(SHA_A, 40251861), "512")
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.reconcile([a, c])

    def test_a_log_without_the_device_is_refused(self):
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.parse_measured_log(log_text(SHA_A, 1, gpu_on=False), "128")
        self.assertIn("gpu: ON", str(cm.exception))

    def test_an_unverified_or_inconsistent_log_is_refused(self):
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.parse_measured_log(log_text(SHA_A, 1, verified=False), "128")
        text = log_text(SHA_A, 40251860).replace("(40251860 B)", "(40251861 B)")
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.parse_measured_log(text, "128")

    def test_mixed_shapes_are_refused(self):
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860, privacy="P3"), "128")
        b = sweep.parse_measured_log(log_text(SHA_A, 40251860, privacy="P1"), "256")
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.reconcile([a, b])

    def test_the_fused_reencode_line_is_also_parsed(self):
        text = log_text(SHA_A, 40251860).replace("[ZK60-CL1]   zk", "[ZK60-CL1]   zk")
        text += "[ZK60-CL1]   chunked ZK re-encode + gather rows 10774 (85 chunks, fused, pruned 244/4096): 0.2000 s\n"
        p = sweep.parse_measured_log(text, "128")
        self.assertEqual(p["chunked_reencode_secs"], 0.2)


class Cli(unittest.TestCase):
    def test_plan_without_a_budget_only_sweeps(self):
        import contextlib
        import io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = sweep.main(["plan", "--p3-weights", "4096", "14336", "--choices", "128,512"])
        self.assertEqual(rc, 0)
        report = json.loads(out.getvalue())
        self.assertNotIn("selected_choice", report)
        self.assertEqual(report["shape"]["rows"], MISTRAL_ROWS)
        self.assertEqual(report["p3_weight_layout"]["rows"], MISTRAL_ROWS)
        self.assertFalse(report["safe_to_run"])

    def test_plan_with_a_budget_selects_and_a_bad_budget_exits_2(self):
        import contextlib
        import io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = sweep.main(["plan", "--rows", "10774", "--choices", "128,256,512,1024", "--scratch-budget-mib", "700",
                             "--device-total-mib", "8188"])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out.getvalue())["selected_choice"], 512)
        with self.assertRaises(SystemExit) as cm:
            with contextlib.redirect_stderr(io.StringIO()):
                sweep.main(["plan", "--rows", "10774", "--choices", "128", "--scratch-budget-mib", "9000",
                            "--device-total-mib", "8188"])
        self.assertEqual(cm.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
