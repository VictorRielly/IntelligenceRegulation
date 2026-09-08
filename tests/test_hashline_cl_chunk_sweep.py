"""[ZK60-CL6] Tests for the chunk-row sweep and selector.

Pure arithmetic and log parsing: no GPU, no nvidia-smi, no subprocess. The
device rules being mirrored are quoted from hashline/src/gpu/cuda.rs in the
module under test; the tests pin the mirror against those rules, including
the corner where the choice is not a multiple of 128.

[ZK60-CL14] The `measure` contract: every row is gated (CL5 contract + exit
channels + CL6_RUN identity + label-vs-chunk-plan) before any digest
comparison or ranking. The fixture below is shaped like the archived
results/cl6_sweep_p3_c*_r*.log files: CL1 chunk lines, the CL5 phases
block, the device-side counters, PROOF, PASS-V3, HASHLINE_TIMING and an
exit channel (`exit N` by default, the CL5 runner's convention).
"""

import contextlib
import importlib.util
import io
import json
import math
import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_chunk_sweep.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_chunk_sweep", _SRC)
sweep = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = sweep
_spec.loader.exec_module(sweep)

MIB = 1024 ** 2
MISTRAL_ROWS = 10774   # d 4096 / f 14336 at log_cols 14: 10752 data + 21 masks + 1 prox
DROP = object()        # `timing={"k": DROP}` removes k from the HASHLINE_TIMING line
DEVICE = "NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)"


def log_text(sha, nbytes, prove=4.0, gpu_on=True, verified=True, commits=(), reencs=(), vram=5182, privacy="P3",
             verdict="ACCEPT", pass_line=True, phases=True, exit_line=0, cl6_run=None, serialized=True,
             gpu_requested=True, coverage="ffn-only", randomness="deterministic-test", device=DEVICE, timing=None,
             extra=""):
    """One synthetic prover log. `exit_line=None` drops the `exit N` channel;
    `cl6_run=(choice, rep, exit)` adds the sweep runner's CL6_RUN line with
    this log's own digest; `timing` overrides (or DROPs) TIMING fields;
    `extra` is spliced in before the PROOF line."""
    head = f"  gpu: ON — {device}\n" if gpu_on else "  gpu: off (HL_GPU unset)\n"
    body = ""
    for rows, chunks, rmax, secs in commits:
        body += f"[ZK60-CL1]   zk commit rows {rows} 2^14 -> 2^16 (q 256, 5649 MB resident): CHUNKED (by size)\n"
        body += f"[ZK60-CL1]   chunked ZK commit rows {rows} 2^14 -> 2^16 (q 256) in {chunks} chunks of <= {rmax}: {secs:.4f} s\n"
    for rows, chunks, secs in reencs:
        body += f"[ZK60-CL1]   chunked ZK re-encode + gather rows {rows} ({chunks} chunks): {secs:.4f} s\n"
    body += f"  layer  0: prove {prove:.3f} s, {nbytes} B\n"
    if phases:
        body += "prover phases (summed over layers):\n"
        body += "      commit W                      1.200 s\n"
        body += "      pcs openings (zk)             0.800 s\n"
    body += f"  gpu device-side (summed): h2d 0.3 s (674 MB) | ntt 0.6 s | hash 0.2 s | sumcheck 0.2 s | fold 0.1 s | helpers 0.1 s | d2h 0.000 s (46 MB) | vram peak {vram} MB\n"
    body += extra
    body += f"PROOF sha256 {sha} ({nbytes} B) [ZK v3 randomness {randomness}]\n"
    if pass_line:
        body += (f"PASS-V3 {verdict} [ZK]: 1 x 512 (d 4096 f 14336): witness load+chain 3.30 s | PROVE {prove:.2f} s | "
                 f"VERIFY 0.06 s | proof {nbytes} B ({nbytes / 1e6:.1f} MB) | 9.019e10 MACs | 2.2e10 proven MAC/s (prove wall) | wall 7.5 s\n")
    t = {"schema": 1, "coverage": coverage, "privacy": privacy, "layers": 1, "tokens": 512, "d": 4096, "f": 14336,
         "witness_s": 3.3, "prove_s": prove, "serialize_s": 0.05, "proof_ready_s": prove + 3.35, "verify_s": 0.06,
         "verified": verified, "proof_bytes": nbytes, "serialized": serialized, "gpu_requested": gpu_requested,
         "gpu_enabled": gpu_on, "randomness": randomness}
    if timing:
        t.update(timing)
        t = {k: v for k, v in t.items() if v is not DROP}
    body += "HASHLINE_TIMING " + json.dumps(t) + "\n"
    if cl6_run is not None:
        c, r, x = cl6_run
        body += f"CL6_RUN chunk_rows={c} rep={r} exit={x} sha256={sha} bytes={nbytes}\n"
    if exit_line is not None:
        body += f"exit {exit_line}\n"
    return head + body


def sweep_log_text(runs, sha, nbytes, green=True):
    """The sweep runner's log: provenance header, half-1 gates, one CL6_RUN per (choice, rep, exit)."""
    out = "=== identity ===\nHEAD    9b249755e4bc14447578111e28df080ed5f0785b\ndirty   1 tracked file(s) modified\n"
    out += "binary  0040cd848b29622278653972eaa890a6c9d1a3a9aea103bb010dd32b302555b2  5318584 B\n"
    out += f"GATE OK   zkv3 forced-chunk rows=128  {'4' * 64}  87697008 B\n"
    for c, r, x in runs:
        out += f"--- choice {c} rep {r} (09:46:15)\nCL6_RUN chunk_rows={c} rep={r} exit={x} sha256={sha} bytes={nbytes}\n"
    out += "=== VERDICT ===\n" + ("CL6 SWEEP GREEN (frozen fixture byte-identical at every choice; Mistral runs recorded)\n"
                                  if green else "FAILURE: CL6 sweep RED — see above\n")
    return out


def reasons_of(text, label, **kw):
    return sweep.parse_measured_log(text, label, strict=False, **kw)["gate"]["reasons"]


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


# ------------------------------------------------------------------ [ZK60-CL14]

class ReviewFixture(unittest.TestCase):
    """Codex round 9: `log_text(SHA_A, 40251860, prove=-1.0) + 'exit 1\\n'`
    parsed under the label 'bad' and reconciled came out as prove_s=-1 and
    byte_identical_across_choices=true."""

    def test_negative_prove_followed_by_exit_1_is_refused(self):
        # the review's fixture, with the fixture's own exit channel removed so
        # the trailing `exit 1` is the sole exit evidence
        bad = log_text(SHA_A, 40251860, prove=-1.0, exit_line=None) + "exit 1\n"
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([sweep.parse_measured_log(bad, "bad")])
        msg = str(cm.exception)
        self.assertIn("clock prove_s is negative (-1.0)", msg)
        self.assertIn("exit code 1 != 0", msg)
        self.assertNotIn("byte_identical", msg)
        row = sweep.parse_measured_log(bad, "bad", strict=False)
        self.assertEqual(row["gate"]["classification"], "refused")
        self.assertFalse(row["gate"]["eligible"])
        self.assertEqual(row["exit_evidence"]["resolved"], 1)
        self.assertEqual(row["exit_evidence"]["resolved_source"], "exit line")
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([row])
        self.assertIn("not evidence", str(cm.exception))

    def test_the_literal_review_expression_is_refused_too(self):
        # verbatim: the (now exit-carrying) fixture followed by `exit 1` — two
        # exit lines that disagree, a negative clock; nothing is tabulated
        bad = log_text(SHA_A, 40251860, prove=-1.0) + "exit 1\n"
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([sweep.parse_measured_log(bad, "bad")])
        msg = str(cm.exception)
        self.assertIn("clock prove_s is negative (-1.0)", msg)
        self.assertIn("2 `exit N` lines", msg)
        self.assertIn("exit evidence conflicts", msg)


class Clocks(unittest.TestCase):
    def test_each_clock_has_a_named_outcome_for_zero_negative_nan_and_infinite(self):
        for clock in sweep.CLOCKS:
            for value, phrase in ((0, "is zero"), (-0.5, "is negative"), (float("nan"), "is NaN"),
                                  (float("inf"), "is infinite"), (float("-inf"), "is infinite"), ("4.0", "is not a number")):
                text = log_text(SHA_A, 40251860, timing={clock: value})
                row = sweep.parse_measured_log(text, "128", strict=False)
                self.assertEqual(row["gate"]["classification"], "refused", (clock, value))
                self.assertTrue(any(r.startswith(f"clock {clock} ") and phrase in r for r in row["gate"]["reasons"]),
                                (clock, value, row["gate"]["reasons"]))
                with self.assertRaises(sweep.ChunkSweepError):
                    sweep.parse_measured_log(text, "128")
        # the JSON record never carries a bare NaN/inf number
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, timing={"prove_s": float("nan")}), "128", strict=False)
        json.dumps(row, allow_nan=False)
        self.assertEqual(row["clocks"]["prove_s"], "nan")
        self.assertIsNone(row["prove_s"])

    def test_a_missing_clock_is_missing_evidence(self):
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, timing={"verify_s": DROP}), "128", strict=False)
        self.assertEqual(row["gate"]["classification"], "missing-evidence")
        self.assertIn("clock verify_s absent from HASHLINE_TIMING", row["gate"]["missing_items"])

    def test_contradictory_clocks_are_refused(self):
        # proof_ready_s smaller than the prove_s it contains
        reasons = reasons_of(log_text(SHA_A, 40251860, prove=4.0, timing={"proof_ready_s": 1.0}), "128")
        self.assertTrue(any(r.startswith("contradictory clocks: prove_s (4.0) exceeds proof_ready_s (1.0)") for r in reasons), reasons)
        # witness + prove + serialize exceed proof_ready_s beyond the tolerance (the CL5 rule)
        reasons = reasons_of(log_text(SHA_A, 40251860, prove=4.0, timing={"proof_ready_s": 7.0}), "128")
        self.assertTrue(any("witness+prove+serialize exceed proof_ready_s" in r for r in reasons), reasons)
        # the same three clocks summing to proof_ready_s exactly is fine
        sweep.parse_measured_log(log_text(SHA_A, 40251860, prove=4.0), "128")

    def test_prove_vs_fastest_never_divides_by_zero_or_a_negative(self):
        good = sweep.parse_measured_log(log_text(SHA_A, 40251860, 4.0), "128")
        for bad_prove in (0, -1.0):
            bad = sweep.parse_measured_log(log_text(SHA_A, 40251860, bad_prove), "256", strict=False)
            with self.assertRaises(sweep.ChunkSweepError):
                sweep.reconcile([good, bad])
        # a forged gate does not get past the ranking guard either
        forged = dict(good, label="256", prove_s=0.0)
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([good, forged])
        self.assertIn("not a finite positive number", str(cm.exception))
        # and a row that was never gated is refused, not ranked
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([good, {"label": "512", "sha256": SHA_A, "proof_bytes": 40251860, "prove_s": 4.0}])
        self.assertIn("never gated", str(cm.exception))


class ExitChannels(unittest.TestCase):
    def test_each_channel_reaches_the_parser(self):
        base = log_text(SHA_A, 40251860, exit_line=None)
        # (a) the argument
        row = sweep.parse_measured_log(base, "128", exit_code=0)
        self.assertEqual((row["exit_evidence"]["resolved"], row["exit_evidence"]["resolved_source"]), (0, "argument"))
        # (b) the `exit N` line
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, exit_line=0), "128")
        self.assertEqual((row["exit_evidence"]["resolved"], row["exit_evidence"]["resolved_source"]), (0, "exit line"))
        # (c) the CL6_RUN line in the per-run log
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 1, 0)), "128")
        self.assertEqual((row["exit_evidence"]["resolved"], row["exit_evidence"]["resolved_source"]), (0, "CL6_RUN (per-run log)"))
        self.assertEqual((row["choice"], row["rep"]), (128, 1))
        # (c) the CL6_RUN line in the sweep log, bound by chunk_rows/rep
        runs = sweep.parse_sweep_log(sweep_log_text([(128, 1, 0)], SHA_A, 40251860))
        row = sweep.parse_measured_log(base, "128:1", sweep_runs=runs)
        self.assertEqual((row["exit_evidence"]["resolved"], row["exit_evidence"]["resolved_source"]), (0, "CL6_RUN (sweep log)"))
        self.assertEqual(row["sweep_run"]["line"], 7)   # 5 header lines, the `--- choice` line, then CL6_RUN
        # the CL5 gate saw a KNOWN exit in every case
        self.assertTrue(row["cl5_gate"]["eligible"])

    def test_absent_exit_is_missing_evidence_not_success(self):
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, exit_line=None), "128", strict=False)
        self.assertEqual(row["gate"]["classification"], "missing-evidence")
        self.assertFalse(row["gate"]["eligible"])
        self.assertIsNone(row["exit_evidence"]["resolved"])
        self.assertTrue(any(m.startswith("exit status:") for m in row["gate"]["missing_items"]), row["gate"]["missing_items"])
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([row])
        self.assertIn("missing-evidence", str(cm.exception))

    def test_nonzero_exits_are_refused_on_every_channel(self):
        base = log_text(SHA_A, 40251860, exit_line=None)
        for text, kw in ((base, {"exit_code": 1}),
                         (log_text(SHA_A, 40251860, exit_line=137), {}),
                         (log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 1, 1)), {}),
                         (base, {"sweep_runs": sweep.parse_sweep_log(sweep_log_text([(128, 1, 2)], SHA_A, 40251860))})):
            row = sweep.parse_measured_log(text, "128:1", strict=False, **kw)
            self.assertEqual(row["gate"]["classification"], "refused", row["gate"]["reasons"])
            self.assertTrue(any(r.startswith("exit code ") and "!= 0" in r for r in row["gate"]["reasons"]), row["gate"]["reasons"])

    def test_conflicting_exits_between_channels_are_refused(self):
        # argument 0 vs `exit 1` line
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=1), "128", exit_code=0)
        self.assertTrue(any(r.startswith("exit evidence conflicts: argument=0, exit line=1") for r in reasons), reasons)
        # `exit 0` line vs CL6_RUN exit=1 in the same log
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=0, cl6_run=(128, 1, 1)), "128")
        self.assertTrue(any("exit evidence conflicts" in r for r in reasons), reasons)
        # per-run CL6_RUN exit=0 vs sweep-log CL6_RUN exit=1 for the same run
        runs = sweep.parse_sweep_log(sweep_log_text([(128, 1, 1)], SHA_A, 40251860))
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 1, 0)), "128:1", sweep_runs=runs)
        self.assertTrue(any("exit evidence conflicts" in r for r in reasons), reasons)
        self.assertTrue(any("disagree" in r for r in reasons), reasons)
        # two `exit` lines (the CL5 parser alone would take the first and pass)
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=0) + "exit 0\n", "128")
        self.assertTrue(any("2 `exit N` lines" in r for r in reasons), reasons)


class SweepLog(unittest.TestCase):
    def test_binding_is_by_chunk_rows_and_rep(self):
        runs = sweep.parse_sweep_log(sweep_log_text([(128, 1, 0), (128, 2, 0), (256, 1, 0)], SHA_A, 40251860), "sweep.log")
        self.assertEqual(len(runs["runs"]), 3)
        self.assertTrue(runs["green"])
        self.assertEqual(runs["identity"]["head"], "9b249755e4bc14447578111e28df080ed5f0785b")
        self.assertEqual(runs["frozen_fixture_gates"][0]["chunk_rows"], 128)
        base = log_text(SHA_A, 40251860, exit_line=None)
        # a label without a rep is ambiguous when the sweep has two reps at that choice
        reasons = reasons_of(base, "128", sweep_runs=runs)
        self.assertTrue(any("binds to 2 sweep-log runs" in r for r in reasons), reasons)
        # with the rep named it binds; a choice with one rep binds without it
        self.assertEqual(sweep.parse_measured_log(base, "128:2", sweep_runs=runs)["sweep_run"]["rep"], 2)
        self.assertEqual(sweep.parse_measured_log(base, "256", sweep_runs=runs)["rep"], 1)
        # a free label cannot bind
        reasons = reasons_of(base, "bad", sweep_runs=runs)
        self.assertTrue(any(r.startswith("cannot bind label 'bad'") for r in reasons), reasons)
        # a rep the sweep never ran is missing evidence
        row = sweep.parse_measured_log(base, "256:2", sweep_runs=runs, strict=False)
        self.assertEqual(row["gate"]["classification"], "missing-evidence")
        self.assertTrue(any("no CL6_RUN line for chunk_rows=256 rep=2" in m for m in row["gate"]["missing_items"]))
        # the per-run log's own CL6_RUN line supplies the rep for binding
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 2, 0)), "128", sweep_runs=runs)
        self.assertEqual(row["sweep_run"]["rep"], 2)

    def test_sweep_digests_are_cross_checked_against_the_proof_line(self):
        runs = sweep.parse_sweep_log(sweep_log_text([(128, 1, 0)], SHA_B, 40251860))
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=None), "128:1", sweep_runs=runs)
        self.assertTrue(any("the sweep log's CL6_RUN line says sha256 2222222222222222../40251860 B but the PROOF line says 1111111111111111../40251860 B" in r
                            for r in reasons), reasons)
        runs = sweep.parse_sweep_log(sweep_log_text([(128, 1, 0)], SHA_A, 40251861))
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=None), "128:1", sweep_runs=runs)
        self.assertTrue(any("but the PROOF line says" in r for r in reasons), reasons)
        # a CL6_RUN line with no proof file recorded is a refusal even at exit 0
        text = sweep_log_text([(128, 1, 0)], SHA_A, 40251860).replace(f"sha256={SHA_A} bytes=40251860", "sha256= bytes=")
        runs = sweep.parse_sweep_log(text)
        reasons = reasons_of(log_text(SHA_A, 40251860, exit_line=None), "128:1", sweep_runs=runs)
        self.assertTrue(any("recorded no proof file" in r for r in reasons), reasons)
        # the per-run log's own CL6_RUN line is held to the same identity
        text = log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 1, 0)).replace(f"sha256={SHA_A} bytes", f"sha256={SHA_B} bytes")
        reasons = reasons_of(text, "128")
        self.assertTrue(any(r.startswith("the log's CL6_RUN line says sha256") for r in reasons), reasons)

    def test_a_sweep_log_with_duplicate_or_no_runs_is_refused(self):
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.parse_sweep_log(sweep_log_text([(128, 1, 0), (128, 1, 0)], SHA_A, 40251860))
        self.assertIn("two CL6_RUN lines for chunk_rows=128 rep=1", str(cm.exception))
        with self.assertRaises(sweep.ChunkSweepError):
            sweep.parse_sweep_log("=== identity ===\nCL6 SWEEP GREEN\n")

    def test_the_label_must_match_the_logs_own_chunk_plan_and_cl6_line(self):
        # commits in 85 chunks of <= 128 are not a 256-row run
        reasons = reasons_of(log_text(SHA_A, 40251860, commits=((10774, 85, 128, 0.9),)), "256")
        self.assertTrue(any("the device plan for 256 is 43 chunks of <= 256" in r for r in reasons), reasons)
        reasons = reasons_of(log_text(SHA_A, 40251860, reencs=((10774, 85, 0.3),)), "256")
        self.assertTrue(any("re-encoded 10774 rows in 85 chunks" in r for r in reasons), reasons)
        # the log's CL6_RUN line names a different choice than the label
        reasons = reasons_of(log_text(SHA_A, 40251860, cl6_run=(256, 1, 0)), "128")
        self.assertTrue(any("says chunk_rows=256 but the label says 128" in r for r in reasons), reasons)
        reasons = reasons_of(log_text(SHA_A, 40251860, cl6_run=(128, 2, 0)), "128:1")
        self.assertTrue(any("says rep=2 but the label says 1" in r for r in reasons), reasons)
        # a choice that is not a multiple of 128 is checked against the ROUNDED device plan
        sweep.parse_measured_log(log_text(SHA_A, 40251860, commits=((10774, 43, 256, 0.8),)), "300")


class Metadata(unittest.TestCase):
    def test_conflicting_verdicts_and_missing_items_are_classified(self):
        row = sweep.parse_measured_log(log_text(SHA_A, 40251860, verdict="REJECT"), "128", strict=False)
        self.assertEqual(row["gate"]["classification"], "refused")
        self.assertIn("verifier verdict is REJECT, not ACCEPT", row["gate"]["reasons"])
        for kw, item in (({"pass_line": False}, "PASS ACCEPT/REJECT verdict line"),
                         ({"phases": False}, "`prover phases (summed over layers)` block")):
            row = sweep.parse_measured_log(log_text(SHA_A, 40251860, **kw), "128", strict=False)
            self.assertEqual(row["gate"]["classification"], "missing-evidence", row["gate"]["reasons"])
            self.assertIn(item, row["gate"]["missing_items"])
        # no TIMING line at all: missing evidence, no crash, no NaN
        text = log_text(SHA_A, 40251860)
        text = "\n".join(line for line in text.splitlines() if not line.startswith("HASHLINE_TIMING")) + "\n"
        row = sweep.parse_measured_log(text, "128", strict=False)
        self.assertEqual(row["gate"]["classification"], "missing-evidence")
        self.assertIn("HASHLINE_TIMING line", row["gate"]["missing_items"])
        json.dumps(row, allow_nan=False)
        # serialized false, gpu requested/enabled inconsistent: the CL5 rules, refused here
        self.assertIn("HASHLINE_TIMING serialized is False, not true", reasons_of(log_text(SHA_A, 40251860, serialized=False), "128"))
        self.assertTrue(any("gpu_requested" in r for r in reasons_of(log_text(SHA_A, 40251860, gpu_requested=False), "128")))

    def test_conflicting_metadata_across_the_set_is_refused_naming_labels(self):
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860), "128")
        cases = (("coverage", log_text(SHA_A, 40251860, coverage="full")),
                 ("device", log_text(SHA_A, 40251860, device="NVIDIA GeForce RTX 5090 (sm_120, 170 SMs, 32 GB)")),
                 ("randomness", log_text(SHA_A, 40251860, randomness="os")),
                 ("cache_state", log_text(SHA_A, 40251860, extra="[UPERF3-AC] wcache HIT /c/w0 (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)\n")))
        for field, text in cases:
            b = sweep.parse_measured_log(text, "256")
            with self.assertRaises(sweep.ChunkSweepError) as cm:
                sweep.reconcile([a, b])
            self.assertIn(f"{field} differs across the set", str(cm.exception))
            self.assertIn("128", str(cm.exception))
            self.assertIn("256", str(cm.exception))

    def test_duplicate_labels_or_runs_are_refused(self):
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860), "128")
        b = sweep.parse_measured_log(log_text(SHA_A, 40251860, 4.2), "128")
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([a, b])
        self.assertIn("appear more than once", str(cm.exception))
        a = sweep.parse_measured_log(log_text(SHA_A, 40251860, exit_line=None, cl6_run=(128, 1, 0)), "128:1")
        b = sweep.parse_measured_log(log_text(SHA_A, 40251860, 4.2, exit_line=None, cl6_run=(128, 1, 0)), "128")
        with self.assertRaises(sweep.ChunkSweepError) as cm:
            sweep.reconcile([a, b])
        self.assertIn("claim the same run", str(cm.exception))


class MeasureEndToEnd(unittest.TestCase):
    def _write(self, d, name, text):
        path = os.path.join(d, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return path

    def test_a_valid_comparison_with_complete_evidence_tabulates(self):
        with tempfile.TemporaryDirectory() as d:
            runs = [(128, 1, 0), (256, 1, 0), (128, 2, 0), (256, 2, 0)]
            proves = {(128, 1): 4.11, (256, 1): 4.17, (128, 2): 4.05, (256, 2): 4.01}
            logs = []
            for c, r, _ in runs:
                text = log_text(SHA_A, 40251860, proves[(c, r)], exit_line=None, cl6_run=(c, r, 0),
                                commits=((10774, 85 if c == 128 else 43, c, 0.38),), reencs=((10774, 85 if c == 128 else 43, 0.36),),
                                vram=5182 if c == 128 else 5349)
                logs.append(f"{c}:{r}=" + self._write(d, f"c{c}_r{r}.log", text))
            sweep_path = self._write(d, "sweep.log", sweep_log_text(runs, SHA_A, 40251860))
            report = sweep.measure(logs, [], sweep_path, ["measure"])
            self.assertIsNone(report["refusal"], report["refusal"])
            self.assertEqual(report["row_classes"], {"eligible": 4, "refused": 0, "missing-evidence": 0})
            self.assertEqual(report["sweep_log"]["unbound_runs"], [])
            rec = report["reconcile"]
            self.assertTrue(rec["byte_identical_across_choices"])
            self.assertFalse(rec["selector_promoted"])
            self.assertEqual(rec["fastest_label"], "256:2")
            self.assertEqual({k: v["source"] for k, v in rec["exit_evidence"].items()},
                             {lbl: "CL6_RUN (per-run log)" for lbl in ("128:1", "256:1", "128:2", "256:2")})
            self.assertAlmostEqual(rec["rows"][1]["prove_vs_fastest"], 4.17 / 4.01)
            self.assertTrue(all(r["log"]["sha256"] for r in report["rows"]))
            md = sweep.markdown(rec)
            self.assertIn("| 128:1 |", md)
            self.assertIn("| 0 (CL6_RUN (per-run log)) |", md)
            json.dumps(report, allow_nan=False)
            # the CLI, both outputs
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = sweep.main(["measure", *sum((["--log", item] for item in logs), []), "--sweep-log", sweep_path])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(out.getvalue())["row_classes"]["eligible"], 4)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = sweep.main(["measure", *sum((["--log", item] for item in logs), []), "--sweep-log", sweep_path, "--markdown"])
            self.assertEqual(rc, 0)
            self.assertIn("| 256:2 |", out.getvalue())

    def test_a_refused_sweep_leaves_a_record_and_exits_2(self):
        with tempfile.TemporaryDirectory() as d:
            good = self._write(d, "good.log", log_text(SHA_A, 40251860, exit_line=None))
            bad = self._write(d, "bad.log", log_text(SHA_A, 40251860, prove=-1.0, exit_line=None) + "exit 1\n")
            out, err = io.StringIO(), io.StringIO()
            with self.assertRaises(SystemExit) as cm:
                with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                    sweep.main(["measure", "--log", f"128={good}", "--log", f"256={bad}", "--exit", "128=0"])
            self.assertEqual(cm.exception.code, 2)
            report = json.loads(out.getvalue())
            self.assertIn("not evidence", report["refusal"])
            self.assertEqual(report["row_classes"], {"eligible": 1, "refused": 1, "missing-evidence": 0})
            self.assertIsNone(report["reconcile"])
            self.assertEqual(report["rows"][1]["gate"]["classification"], "refused")
            self.assertEqual(report["command"]["argv"][0], "measure")
            self.assertIn("chunk sweep:", err.getvalue())
            # usage errors: duplicate labels, an --exit naming no log
            for argv in (["measure", "--log", f"128={good}", "--log", f"128={bad}"],
                         ["measure", "--log", f"128={good}", "--exit", "512=0"],
                         ["measure", "--log", f"128={good}", "--exit", "128=zero"]):
                with self.assertRaises(SystemExit) as cm:
                    with contextlib.redirect_stderr(io.StringIO()):
                        sweep.main(argv)
                self.assertEqual(cm.exception.code, 2)

    def test_a_row_without_any_exit_channel_is_recorded_as_missing_evidence(self):
        with tempfile.TemporaryDirectory() as d:
            path = self._write(d, "legacy.log", log_text(SHA_A, 40251860, exit_line=None))
            report = sweep.measure([f"128={path}"], [], None, ["measure"])
            self.assertEqual(report["row_classes"]["missing-evidence"], 1)
            self.assertIn("missing-evidence", report["refusal"])
            self.assertIsNone(report["reconcile"])


if __name__ == "__main__":
    unittest.main()
