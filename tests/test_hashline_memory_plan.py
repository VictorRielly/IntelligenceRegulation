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

    def test_warm_pool_still_pays_the_raw_non_poolable_allocations(self):
        """capacity vs request: cold and warm HOLD the same bytes, and warm
        allocates LESS — but not nothing.

        CORRECTED after the round-6 review. This test previously asserted warm
        allocates ZERO, which was wrong: pads, coset powers and the leaf buffer
        are raw allocations (htod_sync_copy / alloc::<u32>), never pooled, so
        they are paid on every call whatever the pool holds. The device
        counters agree — a forced-chunk commitment reports 2 raw allocations."""
        cold = plan.commitment_plan(**self.SHAPE, mode="chunked", pool_state="cold")
        warm = plan.commitment_plan(**self.SHAPE, mode="chunked", pool_state="warm")
        self.assertEqual(cold["subtotal_accounted_bytes"], warm["subtotal_accounted_bytes"])
        self.assertGreater(cold["newly_allocated_capacity_bytes"],
                           warm["newly_allocated_capacity_bytes"])
        self.assertEqual(warm["newly_allocated_capacity_bytes"], warm["raw_non_poolable_bytes"])
        self.assertGreater(warm["newly_allocated_capacity_bytes"], 0,
                           "pads/powers/leaves are never pooled; warm cannot be free")

    def test_chunk_rows_mirror_the_device_plan(self):
        """chunk_rows() clamps to >= 128 and chunk_plan rounds the step down to
        a multiple of 128, so an unrounded count here would undercount."""
        for asked, expect in ((1, 128), (64, 128), (128, 128), (200, 128), (256, 256), (300, 256)):
            r = plan.commitment_plan(**self.SHAPE, mode="chunked", chunk_rows=asked)
            self.assertEqual(r["chunk_rows"], expect, f"chunk_rows={asked}")

    def test_post_return_fields_are_mode_aware(self):
        """A chunked commitment returns NO encoded matrix and retains pads and
        powers instead; the resident-only fields were wrong for it.

        [round-7 review] and its scratch goes back to the POOL: the earlier
        `new_pool_bytes_after_return == 0` for a cold chunked call was WRONG —
        coef, coef2, enc and the blake3 state are Pooled and return on drop.
        Only the raw leaf buffer is freed."""
        res = plan.commitment_plan(**self.SHAPE)
        chu = plan.commitment_plan(**self.SHAPE, mode="chunked")
        self.assertGreater(res["new_pool_bytes_after_return"], 0)
        b = chu["buffers_bytes"]
        scratch = b["chunk_coefficients"] + b["chunk_expanded"] + b["chunk_encoded"] + b["blake3_column_state"]
        self.assertEqual(chu["new_pool_bytes_after_return"], scratch)
        self.assertEqual(chu["pool_bytes_after_return"], scratch)
        self.assertLess(chu["commitment_live_after_return_bytes"],
                        res["commitment_live_after_return_bytes"])
        self.assertEqual(chu["commitment_live_after_return_bytes"],
                         b["systematic_data"] + b["pads"] + b["coset_powers"])
        last = chu["stages"][-1]
        self.assertNotIn("device_leaf_hashes", last["live_buffers"], "the leaf buffer is FREED by the callee")
        self.assertEqual(len(last["pooled_buffers"]), 4)

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


class PoolLifetimes(unittest.TestCase):
    """[ZK60 round-7 review] Ownership across reuse: each buffer counted once by
    capacity; take_min transfers a pooled capacity to its new owner; a warm
    pool is an inventory. Pure arithmetic — and one case is reconciled against
    the device counters the Rust test measured."""

    SMALL = dict(rows=2000, log_cols=14, inv_rate=4, q_pad=256, ntt_max_log=16)

    def sizes(self, rows, log_cols, inv_rate, q_pad, chunk=128, **_):
        n, nn = 1 << log_cols, (1 << log_cols) * inv_rate
        return dict(data=rows * n * 8, pads=rows * q_pad * 8, pows=nn * 8, leaves=nn * 32,
                    res_coef=rows * n * 8, res_enc=rows * nn * 8,
                    coef=chunk * n * 8, enc=chunk * nn * 8,
                    state=((plan.B3_STATE_SLOTS * nn + 1) // 2) * 8)

    def test_fallback_serves_the_retry_from_the_released_pair_by_capacity(self):
        s = self.sizes(**self.SMALL)
        f = plan.commitment_plan(**self.SMALL, mode="fallback")
        loop = next(e for e in f["stages"] if e["stage"] == "chunked retry loop")
        live = {b.split(" [")[0]: b for b in loop["live_buffers"]}
        self.assertIn("reused inverse_coefficients", live["chunk_coefficients"])
        self.assertIn("reused expanded_coefficients", live["chunk_expanded"])
        self.assertIn("[fresh]", live["chunk_encoded"])
        self.assertIn("[fresh]", live["blake3_column_state"])
        self.assertEqual(loop["retained_pool_bytes"], 0, "both released buffers are OWNED again, not pooled")
        # peak = data + pads + pows + rows*n (as coef) + rows*nn (as coef2) + enc + state + leaves
        expect = (s["data"] + s["pads"] + s["pows"] + s["res_coef"] + s["res_enc"]
                  + s["enc"] + s["state"] + s["leaves"] + f["twiddle_bytes"])
        self.assertEqual(f["component_peak_accounted_bytes"], expect)
        # the additive no-reuse count is larger by exactly the two reused takes
        self.assertEqual(f["no_reuse_bound_bytes"] - f["component_peak_accounted_bytes"], s["coef"] + s["enc"])
        sim = f["pool_simulation"]
        self.assertEqual(sim["refused_request_bytes"], s["res_enc"])
        self.assertEqual(sim["reuse_count"], 2)
        self.assertEqual(sim["reuse_capacity_bytes"], s["res_coef"] + s["res_enc"])
        self.assertEqual(sim["reuse_requested_bytes"], s["coef"] + s["enc"])
        self.assertEqual(sim["fresh_pool_bytes"], s["data"] + s["res_coef"] + s["res_enc"] + s["enc"] + s["state"])

    def test_the_refused_take_allocates_nothing(self):
        f = plan.commitment_plan(**self.SMALL, mode="fallback")
        stages = {e["stage"].split(":")[0]: e for e in f["stages"]}
        before = stages["drop(coef)"]
        refused = stages["encoded buffer (rows*nn) REFUSED"]
        self.assertEqual(before["accounted_device_bytes"], refused["accounted_device_bytes"])
        self.assertEqual(refused["fresh_pool_bytes_so_far"], before["fresh_pool_bytes_so_far"])

    def test_warm_is_an_inventory_of_the_previous_calls_shapes(self):
        s = self.sizes(**self.SMALL)
        cold = plan.commitment_plan(**self.SMALL, mode="chunked", pool_state="cold")
        warm = plan.commitment_plan(**self.SMALL, mode="chunked", pool_state="warm")
        self.assertEqual(sorted(warm["pool_simulation"]["inventory"]),
                         sorted(["prior chunk_coefficients:%d" % s["coef"], "prior chunk_expanded:%d" % s["enc"],
                                 "prior chunk_encoded:%d" % s["enc"], "prior blake3_column_state:%d" % s["state"],
                                 "prior systematic_data:%d" % s["data"]]))
        self.assertEqual(warm["pool_simulation"]["fresh_pool_bytes"], 0)
        self.assertEqual(warm["newly_allocated_capacity_bytes"], warm["raw_non_poolable_bytes"])
        self.assertEqual(warm["new_pool_bytes_after_return"], 0, "nothing NEW enters the pool on a warm call")
        self.assertEqual(warm["pool_delta_bytes_after_return"], -s["data"], "the data buffer left the pool for the commitment")
        self.assertEqual(cold["component_peak_accounted_bytes"], warm["component_peak_accounted_bytes"])
        # with reuse disabled the warm inventory is dead weight on top of fresh scratch
        self.assertGreater(warm["no_reuse_bound_bytes"], cold["no_reuse_bound_bytes"])

    def test_a_resident_warmed_pool_serves_chunked_scratch_oversize(self):
        s = self.sizes(**self.SMALL)
        r = plan.commitment_plan(**self.SMALL, mode="chunked", pool_state="warm-resident")
        sim = r["pool_simulation"]
        # data: exact rows*n; coef: the other rows*n; coef2 and enc: the two rows*nn; state: fresh
        self.assertEqual(sim["reuse_count"], 4)
        self.assertEqual(sim["reuse_capacity_bytes"], 2 * s["res_coef"] + 2 * s["res_enc"])
        self.assertEqual(sim["reuse_requested_bytes"], s["data"] + s["coef"] + 2 * s["enc"])
        self.assertEqual(sim["fresh_pool_bytes"], s["state"])
        self.assertEqual(r["new_pool_bytes_after_return"], s["state"], "only the fresh state is NEW pool capacity")
        # capacity is what the card holds: the oversize buffers dominate the peak
        self.assertGreater(r["component_peak_accounted_bytes"],
                           plan.commitment_plan(**self.SMALL, mode="chunked")["component_peak_accounted_bytes"])

    def test_reconciles_with_the_device_counters_at_the_oracle_probe_shape(self):
        """The Rust test `the_chunked_retry_reuses_pooled_capacity...` measured,
        on the RTX 4070 (results in c346236's message), a forced-chunk probe at
        (log_cols 10, rate 4, rows 300, q 16) on a pool warmed by a RESIDENT
        commit of the same shape: fresh 3,162,112 B in 1 allocation, reuse
        capacity 46,694,400 B against 21,331,968 B requested. The probe also
        OPENS the commitment (3 more take_min reuses: rows*n + 2 x rows*nn
        capacity for coef + 2 x enc requested), which this component does not
        model; subtracting that share must land exactly on the planner."""
        s = self.sizes(rows=300, log_cols=10, inv_rate=4, q_pad=16)
        r = plan.commitment_plan(300, 10, 4, 16, mode="chunked", pool_state="warm-resident")
        sim = r["pool_simulation"]
        measured_fresh, measured_capacity, measured_requested = 3_162_112, 46_694_400, 21_331_968
        opening_capacity = s["res_coef"] + 2 * s["res_enc"]
        opening_requested = s["coef"] + 2 * s["enc"]
        self.assertEqual(sim["fresh_pool_bytes"], measured_fresh)
        self.assertEqual(sim["fresh_pool_count"], 1)
        self.assertEqual(sim["reuse_capacity_bytes"], measured_capacity - opening_capacity)
        self.assertEqual(sim["reuse_requested_bytes"], measured_requested - opening_requested)
        # and the raw side: pads + powers + leaves here; the device adds the opening's idx + out
        measured_raw = 240_704
        self.assertEqual(r["raw_non_poolable_bytes"], measured_raw - (16 * 4 + 300 * 16 * 8))

    def test_explicit_inventory_and_its_refusals(self):
        s = self.sizes(**self.SMALL)
        r = plan.commitment_plan(**self.SMALL, mode="chunked", pool_inventory_bytes=[s["state"]])
        sim = r["pool_simulation"]
        # take_min serves the FIRST fitting request from the inventory: the
        # 16 MiB coefficient scratch is served by the 48 MiB state-sized
        # buffer (oversize reuse), so the state itself is then allocated fresh.
        self.assertEqual(sim["reuse_count"], 1)
        self.assertEqual(sim["reuse_capacity_bytes"], s["state"])
        self.assertEqual(sim["reuse_requested_bytes"], s["coef"])
        self.assertEqual(sim["fresh_pool_bytes"], s["data"] + 2 * s["enc"] + s["state"])
        loop = next(e for e in r["stages"] if e["stage"] == "chunk loop")
        self.assertTrue(any(b.startswith("chunk_coefficients [reused inventory") for b in loop["live_buffers"]))
        with self.assertRaises(ValueError):
            plan.commitment_plan(**self.SMALL, mode="resident", pool_inventory_bytes=[1])
        with self.assertRaises(ValueError):
            plan.commitment_plan(**self.SMALL, mode="chunked", pool_inventory_bytes=[])
        with self.assertRaises(ValueError):
            plan.commitment_plan(**self.SMALL, mode="chunked", pool_inventory_bytes=[0])

    def test_cli_accepts_the_inventory_forms(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(plan.main(["--rows", "2000", "--mode", "fallback", "--pool-state", "warm-resident",
                                        "--ntt-max-log", "16"]), 0)
        r = json.loads(out.getvalue())
        self.assertEqual(r["pool_state"], "warm-resident")
        self.assertIn("no_reuse_bound_bytes", r)
        self.assertFalse(r["safe_to_run"])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(plan.main(["--rows", "2000", "--mode", "chunked", "--pool-inventory-bytes", "50593792",
                                        "--ntt-max-log", "16"]), 0)
        self.assertEqual(json.loads(out.getvalue())["pool_simulation"]["inventory"], ["inventory:50593792"])
