"""Pure allocation arithmetic: no GPU, datasets or large arrays."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("memory_plan", Path(__file__).resolve().parents[1] / "scripts/hashline_memory_plan.py")
plan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plan)


class MemoryPlanTests(unittest.TestCase):
    def test_mistral_p3_weight_layout_includes_every_block_mask(self):
        layout = plan.weight_shape(4096, 14336, 14)
        self.assertEqual(layout, {"d": 4096, "f": 14336, "data_rows": 10752,
                                  "block_mask_rows": 21, "proximity_rows": 1,
                                  "rows": 10774, "log_cols": 14})

    def test_small_weight_layout_matches_effective_width(self):
        layout = plan.weight_shape(16, 16, 14)
        self.assertEqual(layout["log_cols"], 8)
        self.assertEqual(layout["rows"], 7)
        layout = plan.weight_shape(768, 2048, 14)
        self.assertEqual(layout["data_rows"], 288)
        self.assertEqual(layout["block_mask_rows"], 9)
        self.assertEqual(layout["rows"], 298)

    def test_drop_does_not_reduce_accounted_memory(self):
        result = plan.commitment_plan(3, 4, 4, 12)
        data, encoded = 3 * 16 * 8, 3 * 64 * 8
        stages = {row["stage"]: row for row in result["stages"]}
        self.assertEqual(stages["forward NTT"]["retained_pool_bytes"], data)
        self.assertEqual(stages["column hashes"]["retained_pool_bytes"], data + encoded)
        self.assertEqual(result["new_pool_bytes_after_return"], data + encoded)
        self.assertEqual(result["commitment_live_after_return_bytes"], data + encoded)
        self.assertEqual(result["component_peak_accounted_bytes"],
                         2 * data + 2 * encoded + 3 * 12 * 8 + 64 * 8 + 64 * 32 + 2 * 63 * 8)

    def test_budgets_cannot_authorize_a_prover_run(self):
        small = plan.commitment_plan(3, 4, 4, 12, component_budget_bytes=1)
        roomy = plan.commitment_plan(3, 4, 4, 12, component_budget_bytes=10 ** 12)
        self.assertTrue(small["exceeds_component_budget"])
        self.assertFalse(roomy["exceeds_component_budget"])
        for result in [small, roomy]:
            self.assertFalse(result["safe_to_run"])
            self.assertFalse(result["measured"])
            self.assertTrue(result["unaccounted"])

    def test_prior_storage_and_twiddle_tables_counted_explicitly(self):
        base = plan.commitment_plan(3, 4, 4, 12)
        extra = plan.commitment_plan(3, 4, 4, 12, prior_live_bytes=101, prior_pool_bytes=202, ntt_max_log=8)
        self.assertEqual(extra["subtotal_accounted_bytes"] - base["subtotal_accounted_bytes"], 303 + 2 * (255 - 63) * 8)

    def test_rates_and_padding(self):
        for rate in [2, 4, 8]:
            result = plan.commitment_plan(17, 10, rate, 256, q_pad=300)
            self.assertEqual(result["shape"]["encoded_columns"], 1024 * rate)
            self.assertEqual(result["buffers_bytes"]["pads"], 17 * 300 * 8)

    def test_invalid_inputs(self):
        for kwargs in [{"rows": 0}, {"rows": -1}, {"rows": True}, {"rows": 1, "log_cols": -1}, {"rows": 1, "log_cols": 0},
                       {"rows": 1, "log_cols": 25}, {"rows": 1, "inv_rate": 3},
                       {"rows": 1, "inv_rate": 1}, {"rows": 1, "q_pad": 255},
                       {"rows": 1, "ntt_max_log": 15}, {"rows": 1, "prior_pool_bytes": -1},
                       {"rows": 2 ** 31}, {"rows": 65536}, {"rows": 1, "component_budget_bytes": 0}]:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                plan.commitment_plan(**kwargs)
        for dims in [(0, 16), (16, 17), (True, 16)]:
            with self.subTest(dims=dims), self.assertRaises(ValueError):
                plan.weight_shape(*dims, 14)

    def test_uncovered_padding_and_hash_length_overflow_rejected(self):
        # n+Q fits the expanded row, but this overlapping-pad regime is not
        # covered by the existing CPU/GPU hiding encoder agreement.
        with self.assertRaisesRegex(ValueError, "q_pad <= columns"):
            plan.commitment_plan(3, 4, 4, 12, q_pad=17)
        # Launch element count fits u32, but hash byte length plus rounding
        # does not; no model-sized tensor is actually allocated by this test.
        with self.assertRaisesRegex(ValueError, "column-hash"):
            plan.commitment_plan(600_000_000, 1, 2, 1)

    def test_cli_produces_serializable_non_authorizing_report(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(plan.main(["--p3-weights", "4096", "14336", "--component-budget-mib", "8188"]), 0)
        result = json.loads(out.getvalue())
        self.assertTrue(result["exceeds_component_budget"])
        self.assertFalse(result["safe_to_run"])
        self.assertGreater(result["component_peak_accounted_bytes"], 13 * 1024 ** 3)


if __name__ == "__main__":
    unittest.main()


class Cl3Modes(unittest.TestCase):
    """[ZK60-CL3] resident / chunked / fallback and cold vs warm pool."""

    SHAPE = dict(rows=10774, log_cols=14, inv_rate=4, q_pad=256, ntt_max_log=16)

    def test_resident_rows_are_unchanged_by_the_extension(self):
        """The extension must not move the number three routes already agree on."""
        r = plan.commitment_plan(**self.SHAPE)
        self.assertAlmostEqual(r["subtotal_accounted_mib"], 13492.042953491211, places=6)
        self.assertEqual(r["mode"], "resident")

    def test_chunked_allocates_no_full_expanded_buffer(self):
        r = plan.commitment_plan(**self.SHAPE, mode="chunked")
        full = self.SHAPE["rows"] * (1 << 16) * 8
        for stage in r["stages"]:
            self.assertNotIn("expanded_coefficients", stage["live_buffers"])
            self.assertNotIn("encoded_matrix", stage["live_buffers"])
        self.assertLess(r["subtotal_accounted_bytes"], full)

    def test_fallback_holds_the_released_resident_pair_as_well(self):
        """THE POINT OF CL3: a chunk-only count is not a fallback bound. The
        refused resident attempt released its buffers to the POOL, not to the
        driver, so the chunked retry runs on top of them."""
        chunked = plan.commitment_plan(**self.SHAPE, mode="chunked")
        fallback = plan.commitment_plan(**self.SHAPE, mode="fallback")
        self.assertGreater(fallback["subtotal_accounted_bytes"],
                           3 * chunked["subtotal_accounted_bytes"])
        # and the released pair must be visible as POOLED, not gone
        retained = [s for s in fallback["stages"] if s["retained_pool_bytes"] > 0]
        self.assertTrue(retained, "the released resident pair must show as pooled")

    def test_fallback_is_only_reachable_below_the_chunk_size_threshold(self):
        """Honest scoping: at Mistral width the commitment chunks BY SIZE, so
        the resident attempt never happens and the fallback figure there is
        hypothetical. Where it is genuinely reachable the ratio is ~3-4x."""
        chunk_bytes = 1 << 30  # HL_GPU_CHUNK_BYTES default
        rows = 2000
        self.assertLessEqual(rows * (1 << 16) * 8, chunk_bytes, "shape must be reachable")
        c = plan.commitment_plan(rows=rows, log_cols=14, inv_rate=4, q_pad=256,
                                 ntt_max_log=16, mode="chunked")
        f = plan.commitment_plan(rows=rows, log_cols=14, inv_rate=4, q_pad=256,
                                 ntt_max_log=16, mode="fallback")
        ratio = f["subtotal_accounted_bytes"] / c["subtotal_accounted_bytes"]
        self.assertGreater(ratio, 2.5)
        self.assertLess(ratio, 5.0)
        # the Mistral-width shape is NOT reachable on this path
        self.assertGreater(self.SHAPE["rows"] * (1 << 16) * 8, chunk_bytes)

    def test_warm_pool_occupies_the_same_bytes_but_allocates_none(self):
        """capacity vs request: cold and warm HOLD the same bytes; only the
        newly allocated capacity differs."""
        cold = plan.commitment_plan(**self.SHAPE, mode="chunked", pool_state="cold")
        warm = plan.commitment_plan(**self.SHAPE, mode="chunked", pool_state="warm")
        self.assertEqual(cold["subtotal_accounted_bytes"], warm["subtotal_accounted_bytes"])
        self.assertGreater(cold["newly_allocated_capacity_bytes"], 0)
        self.assertEqual(warm["newly_allocated_capacity_bytes"], 0)

    def test_bad_mode_and_pool_state_are_rejected(self):
        with self.assertRaises(ValueError):
            plan.commitment_plan(**self.SHAPE, mode="magic")
        with self.assertRaises(ValueError):
            plan.commitment_plan(**self.SHAPE, pool_state="lukewarm")

    def test_the_stale_chunking_note_is_gone(self):
        r = plan.commitment_plan(**self.SHAPE)
        joined = " ".join(r["unaccounted"])
        self.assertNotIn("still allocates both full expanded buffers", joined)
        self.assertIn("NOT a whole-prover bound", joined)
