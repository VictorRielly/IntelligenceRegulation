"""[ZK60-CL8] Tests for the pending-block memory accounting tool.

No GPU, no datasets, no tensors. The calibration tests are the important ones:
if the resident model stops reproducing the independently derived 13,492 MiB,
the model has drifted from the source and every other number it prints is
suspect. [round-7 review] Every concrete builder is now also reconciled
against hashline_memory_plan.commitment_plan (the shared planner) and the
chunk plan against hashline_cl_chunk_sweep, so the three tools cannot drift
from each other silently; and the review's five findings each have a test
that fails on the first version's behaviour.
"""

import contextlib
import importlib.util
import io
import json
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_pending_memory.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_pending_memory", _SRC)
mem = importlib.util.module_from_spec(_spec)
# register before exec: dataclasses resolve annotations through sys.modules, and
# on 3.10 a module loaded by path without this raises inside @dataclass
sys.modules[_spec.name] = mem
_spec.loader.exec_module(mem)
memplan, sweep = mem.memplan, mem.sweep


def sizes(rows, log_cols, inv_rate, q_pad, chunk=None, ntt_max_log=None):
    """Independent arithmetic for the expected byte counts."""
    n, nn = 1 << log_cols, (1 << log_cols) * inv_rate
    ml = ntt_max_log if ntt_max_log is not None else nn.bit_length() - 1
    s = dict(n=n, nn=nn, data=rows * n * 8, pads=rows * q_pad * 8, pows=nn * 8, leaves=nn * 32,
             enc=rows * nn * 8, state=((memplan.B3_STATE_SLOTS * nn + 1) // 2) * 8,
             tw=2 * ((1 << ml) - 1) * 8)
    if chunk is not None:
        rmax = sweep.plan_summary(rows, sweep.effective_chunk_rows(chunk))["rmax"]
        s.update(rmax=rmax, ccoef=rmax * n * 8, cenc=rmax * nn * 8)
    return s


def stage(report, event):
    return next(s for s in report["stages"] if s["event"] == event)


def live_map(stage_row):
    return {b["buffer"]: b for b in stage_row["live_buffers"]}


def pooled_bytes(labels):
    return sum(int(x.rsplit(":", 1)[1]) for x in labels)


class Calibration(unittest.TestCase):
    """Reproduce counts that were derived independently, by other routes."""

    def test_resident_reproduces_the_m1_planner_figure(self):
        # M1's pure planner and CL1's hand derivation both give 13,492.043 MiB
        # for the Mistral W commitment. A third route must agree exactly.
        plan = mem.resident_hiding_commit(rows=10774, log_cols=14, inv_rate=4,
                                          q_pad=256, ntt_max_log=16)
        r = plan.report()
        self.assertTrue(r["complete"])
        self.assertEqual(r["peak_event"], "column_hashes")
        self.assertAlmostEqual(r["peak_accounted_mib"], 13492.042953491211, places=6)

    def test_release_is_not_free(self):
        """The whole point: a released Pooled buffer is still counted until a drain."""
        r = mem.resident_hiding_commit(rows=10774, log_cols=14, inv_rate=4,
                                       q_pad=256, ntt_max_log=16).report()
        # inverse_coefficients is dropped at forward_ntt; it must appear as
        # POOLED there, not vanish.
        self.assertEqual(stage(r, "forward_ntt")["pooled_bytes"], 10774 * (1 << 14) * 8)
        self.assertIn("commit::inverse_coefficients", stage(r, "forward_ntt")["pooled_here"])
        # and by column_hashes BOTH released buffers are pooled
        self.assertEqual(stage(r, "column_hashes")["pooled_bytes"],
                         10774 * (1 << 14) * 8 + 10774 * (1 << 16) * 8)

    def test_a_drain_actually_frees(self):
        plan = mem.resident_hiding_commit(rows=64, log_cols=8, inv_rate=4, q_pad=16)
        plan.schedule = plan.schedule + ["drain"]
        plan.drains = {"drain"}
        r = plan.report()
        self.assertGreater(stage(r, "column_hashes")["pooled_bytes"], 0)
        self.assertEqual(stage(r, "drain")["pooled_bytes"], 0)
        self.assertEqual(stage(r, "drain")["drained_bytes"], stage(r, "return")["pooled_bytes"])
        self.assertEqual(len(r["end_state"]["drained"]), 2)

    def test_chunked_is_far_smaller_and_allocates_no_full_expanded_buffer(self):
        res = mem.resident_hiding_commit(10774, 14, 4, 256, 16).report()
        chu = mem.chunked_hiding_commit(10774, 14, 4, 256, 128, 16).report()
        self.assertTrue(chu["complete"])
        self.assertLess(chu["peak_accounted_mib"], res["peak_accounted_mib"] / 8)
        full = 10774 * (1 << 16)
        for b in mem.chunked_hiding_commit(10774, 14, 4, 256, 128, 16).buffers:
            if not b.symbolic:
                self.assertNotEqual(b.count, full, f"{b.key} is a full rows*nn buffer")

    def test_every_builder_reconciles_with_the_shared_planner(self):
        """[round-7 review] The two counting tools drifted once (finding 1).
        Peak, post-return pool and post-return live set must equal
        hashline_memory_plan's for every path at several shapes."""
        cases = [dict(rows=10774, log_cols=14, inv_rate=4, q_pad=256, ntt_max_log=16, chunk=128),
                 dict(rows=2000, log_cols=14, inv_rate=4, q_pad=256, ntt_max_log=16, chunk=128),
                 dict(rows=300, log_cols=10, inv_rate=4, q_pad=16, ntt_max_log=None, chunk=1),
                 dict(rows=300, log_cols=10, inv_rate=4, q_pad=16, ntt_max_log=None, chunk=300),
                 dict(rows=1000, log_cols=10, inv_rate=2, q_pad=16, ntt_max_log=None, chunk=300),
                 dict(rows=17, log_cols=10, inv_rate=8, q_pad=300, ntt_max_log=None, chunk=64)]
        for c in cases:
            for path in ("resident", "chunked", "fallback"):
                with self.subTest(path=path, **c):
                    args = (c["rows"], c["log_cols"], c["inv_rate"], c["q_pad"])
                    if path == "resident":
                        r = mem.resident_hiding_commit(*args, c["ntt_max_log"]).report()
                    elif path == "chunked":
                        r = mem.chunked_hiding_commit(*args, c["chunk"], c["ntt_max_log"]).report()
                    else:
                        r = mem.fallback_hiding_commit(*args, c["chunk"], c["ntt_max_log"]).report()
                    ref = memplan.commitment_plan(*args, c["q_pad"], c["ntt_max_log"], mode=path, chunk_rows=c["chunk"])
                    self.assertEqual(r["peak_accounted_bytes"], ref["component_peak_accounted_bytes"])
                    if path != "resident":
                        self.assertEqual(r["no_reuse_bound_bytes"], ref["no_reuse_bound_bytes"])
                    self.assertEqual(pooled_bytes(r["end_state"]["pooled"]), ref["pool_bytes_after_return"])
                    last = r["stages"][-1]
                    tw = live_map(last)["gpu::twiddles"]["capacity_bytes"]
                    self.assertEqual(last["live_bytes"] - tw, ref["commitment_live_after_return_bytes"])
                    self.assertEqual(tw, ref["twiddle_bytes"])


class ChunkRounding(unittest.TestCase):
    """[round-7 review, finding 1] The chunk plan mirrors the device: the
    choice is clamped to >= 128 and NOT rounded; rows <= choice is one chunk
    of all rows; otherwise steps of (choice // 128) * 128."""

    def test_the_reviews_case_clamps_to_128_rows(self):
        # The first version reported 8,192 B here (1 row of scratch).
        plan = mem.chunked_hiding_commit(300, 10, 4, 16, 1)
        coef = next(b for b in plan.buffers if b.name == "chunk_coefficients")
        self.assertEqual(coef.nbytes, 1_048_576)
        self.assertEqual(coef.count, 128 * (1 << 10))
        self.assertEqual(plan.meta["shape"]["rmax"], 128)
        self.assertEqual(plan.meta["shape"]["chunk_rows"], 128)
        self.assertEqual(plan.meta["shape"]["chunks"], 3)
        self.assertEqual(plan.meta["shape"]["final_chunk_rows"], 44)

    def test_rows_at_or_below_the_choice_are_one_chunk_of_all_rows(self):
        plan = mem.chunked_hiding_commit(300, 10, 4, 16, 300)
        self.assertEqual(plan.meta["shape"]["rmax"], 300)
        self.assertEqual(plan.meta["shape"]["chunks"], 1)
        coef = next(b for b in plan.buffers if b.name == "chunk_coefficients")
        self.assertEqual(coef.count, 300 * (1 << 10))

    def test_steps_round_down_to_a_multiple_of_128(self):
        plan = mem.chunked_hiding_commit(1000, 10, 4, 16, 300)
        self.assertEqual(plan.meta["shape"]["rmax"], 256)
        self.assertEqual(plan.meta["shape"]["chunks"], 4)
        self.assertEqual(plan.meta["shape"]["final_chunk_rows"], 232)

    def test_chunk_plan_matches_both_shared_mirrors(self):
        # rows 300 at choice 200: rows > choice, so the device steps by
        # (200 // 128) * 128 = 128 — the choice itself is never the chunk size
        # unless every row fits in it.
        for rows, choice, expect in ((300, 1, 128), (300, 64, 128), (300, 128, 128), (300, 200, 128),
                                     (300, 300, 300), (1000, 300, 256), (1000, 1024, 1000),
                                     (10774, 128, 128), (10774, 300, 256)):
            with self.subTest(rows=rows, choice=choice):
                plan = mem.chunked_hiding_commit(rows, 10, 4, 16, choice)
                self.assertEqual(plan.meta["shape"]["rmax"], expect)
                self.assertEqual(sweep.plan_summary(rows, sweep.effective_chunk_rows(choice))["rmax"], expect)
                self.assertEqual(memplan.commitment_plan(rows, 10, 4, 16, mode="chunked", chunk_rows=choice)["chunk_rows"], expect)


class Validation(unittest.TestCase):
    """[round-7 review, finding 2] The tool must DETECT bad plans, not sum them."""

    def plan(self):
        return mem.resident_hiding_commit(64, 8, 4, 16)

    def test_a_negative_count_is_rejected_not_a_negative_peak(self):
        # The first version accepted count=-1 as a "complete" plan with a peak of -8 B.
        plan = self.plan()
        plan.buffers.append(mem.Buffer("neg", "commit", -1, "upload", None))
        with self.assertRaises(mem.PlanError) as cm:
            plan.report()
        self.assertIn("not a positive integer", str(cm.exception))

    def test_nonintegral_counts_are_rejected(self):
        for bad in (0, 1.5, True, "100", "1e3", "", "  "):
            with self.subTest(count=bad):
                plan = self.plan()
                plan.buffers.append(mem.Buffer("bad", "commit", bad, "upload", None))
                with self.assertRaises(mem.PlanError):
                    plan.validate()

    def test_bad_element_sizes_are_rejected(self):
        for bad in (0, -8, 3, 8.0, True, 80):
            with self.subTest(elem_bytes=bad):
                plan = self.plan()
                plan.buffers.append(mem.Buffer("bad", "commit", 10, "upload", None, bad))
                with self.assertRaises(mem.PlanError):
                    plan.validate()

    def test_bad_kinds_and_names_are_rejected(self):
        for b in (mem.Buffer("x", "commit", 10, "upload", None, 8, "freed"),
                  mem.Buffer("", "commit", 10, "upload", None),
                  mem.Buffer("a::b", "commit", 10, "upload", None),
                  mem.Buffer("x", "", 10, "upload", None)):
            with self.subTest(buffer=b):
                plan = self.plan()
                plan.buffers.append(b)
                with self.assertRaises(mem.PlanError):
                    plan.validate()

    def test_empty_and_duplicate_schedules_are_rejected(self):
        plan = self.plan()
        plan.schedule = []
        with self.assertRaises(mem.PlanError):
            plan.validate()
        plan = self.plan()
        plan.schedule = plan.schedule + ["upload"]
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("duplicate", str(cm.exception))

    def test_double_ownership_is_rejected(self):
        plan = self.plan()
        plan.buffers.append(plan.buffers[1])
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("double ownership", str(cm.exception))

    def test_drop_before_or_at_birth_is_rejected(self):
        plan = self.plan()
        plan.buffers.append(mem.Buffer("backwards", "commit", 10, "column_hashes", "upload"))
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("before it is born", str(cm.exception))
        plan = self.plan()
        plan.buffers.append(mem.Buffer("instant", "commit", 10, "upload", "upload"))
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("same event", str(cm.exception))

    def test_unknown_events_and_owners_are_rejected(self):
        plan = self.plan()
        plan.buffers.append(mem.Buffer("ghost", "commit", 10, "no_such_event", None))
        with self.assertRaises(mem.PlanError):
            plan.validate()
        plan = self.plan()
        plan.buffers.append(mem.Buffer("ghost", "commit", 10, "upload", "no_such_event"))
        with self.assertRaises(mem.PlanError):
            plan.validate()
        plan = self.plan()
        plan.drains = {"no_such_event"}
        with self.assertRaises(mem.PlanError):
            plan.validate()
        plan = self.plan()
        plan.buffers.append(mem.Buffer("stray", "nobody", 10, "upload", None))
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("unknown owner", str(cm.exception))

    def test_unsupported_shapes_are_rejected_through_the_shared_planner(self):
        for fn, args in ((mem.resident_hiding_commit, (0, 8, 4, 16)),
                         (mem.resident_hiding_commit, (-1, 8, 4, 16)),
                         (mem.resident_hiding_commit, (True, 8, 4, 16)),
                         (mem.resident_hiding_commit, (64, 25, 4, 16)),
                         (mem.resident_hiding_commit, (64, 8, 3, 16)),
                         (mem.resident_hiding_commit, (64, 8, 4, 257)),   # q_pad > columns
                         (mem.resident_hiding_commit, (64, 8, 4, 0)),
                         (mem.resident_hiding_commit, (64, 8, 4, 16, 9)),  # ntt_max_log < log_nn
                         (mem.chunked_hiding_commit, (64, 8, 4, 16, 0)),
                         (mem.chunked_hiding_commit, (64, 8, 4, 16, 1.5)),
                         (mem.fallback_hiding_commit, (64, 8, 4, 16, -128)),
                         (mem.resident_hiding_commit, (2 ** 31, 8, 4, 16))):
            with self.subTest(fn=fn.__name__, args=args), self.assertRaises(mem.PlanError):
                fn(*args)

    def test_bad_inventories_are_rejected(self):
        for bad in ([0], [-1], [1.5], [True], ["1000"], [(1000, "")], 7):
            with self.subTest(inventory=bad), self.assertRaises(mem.PlanError):
                mem.chunked_hiding_commit(64, 8, 4, 16, 128, None, bad)

    def test_symbolic_buffers_have_no_byte_count(self):
        b = mem.Buffer("x", "o", "some_symbol", "a", None)
        self.assertTrue(b.symbolic)
        with self.assertRaises(mem.PlanError):
            _ = b.nbytes


class Lifetimes(unittest.TestCase):
    """[round-7 review, finding 3] Release versus free, from the source."""

    def test_resident_return_state(self):
        """dev_commit_zk_from's resident result retains data + enc; coef and
        coef2 went to the POOL; pads, powers (raw, no ZkReenc) and the leaf
        buffer (freed inside hash_cols) are FREED before the caller returns."""
        r = mem.resident_hiding_commit(10774, 14, 4, 256, 16).report()
        end = r["end_state"]
        self.assertEqual(set(end["live"]), {"gpu::twiddles", "commit::systematic_data", "commit::encoded_matrix"})
        self.assertEqual({x.rsplit(":", 1)[0] for x in end["pooled"]},
                         {"commit::inverse_coefficients", "commit::expanded_coefficients"})
        self.assertEqual(set(end["freed"]), {"commit::pads", "commit::coset_powers", "commit::device_leaf_hashes"})
        ret = stage(r, "return")
        self.assertEqual(set(ret["freed_here"]), {"commit::pads", "commit::coset_powers", "commit::device_leaf_hashes"})
        s = sizes(10774, 14, 4, 256, ntt_max_log=16)
        self.assertEqual(ret["live_bytes"], s["tw"] + s["data"] + s["enc"])
        self.assertEqual(ret["pooled_bytes"], s["data"] + s["enc"])
        self.assertEqual(ret["freed_bytes_so_far"], s["pads"] + s["pows"] + s["leaves"])
        # the leaves are counted at the hashing peak and nowhere after it
        self.assertIn("commit::device_leaf_hashes", live_map(stage(r, "column_hashes")))
        self.assertNotIn("commit::device_leaf_hashes", live_map(ret))

    def test_chunked_return_state(self):
        """commit_zk_chunked returns its four take_min scratch buffers to the
        POOL and frees its leaf buffer; the commitment retains data + pads +
        powers (ZkReenc) for the deferred re-encode."""
        r = mem.chunked_hiding_commit(10774, 14, 4, 256, 128, 16).report()
        end = r["end_state"]
        self.assertEqual(set(end["live"]), {"gpu::twiddles", "commit::systematic_data", "commit::pads", "commit::coset_powers"})
        self.assertEqual({x.rsplit(":", 1)[0] for x in end["pooled"]},
                         {"commit::chunk_coefficients", "commit::chunk_expanded", "commit::chunk_encoded", "commit::blake3_column_state"})
        self.assertEqual(end["freed"], ["commit::device_leaf_hashes"])
        s = sizes(10774, 14, 4, 256, chunk=128, ntt_max_log=16)
        ret = stage(r, "return")
        self.assertEqual(ret["live_bytes"], s["tw"] + s["data"] + s["pads"] + s["pows"])
        self.assertEqual(ret["pooled_bytes"], s["ccoef"] + 2 * s["cenc"] + s["state"])
        self.assertEqual(ret["freed_bytes_so_far"], s["leaves"])

    def test_raw_buffers_never_enter_the_pool(self):
        raw = {b.key for p in (mem.resident_hiding_commit(64, 8, 4, 16),
                               mem.chunked_hiding_commit(300, 10, 4, 16, 128),
                               mem.fallback_hiding_commit(300, 10, 4, 16, 128))
               for b in p.buffers if b.kind == mem.RAW}
        self.assertIn("commit::pads", raw)
        for p in (mem.resident_hiding_commit(64, 8, 4, 16),
                  mem.chunked_hiding_commit(300, 10, 4, 16, 128),
                  mem.fallback_hiding_commit(300, 10, 4, 16, 128)):
            for st in p.report()["stages"]:
                for label in st["pooled_buffers"]:
                    self.assertNotIn(label.rsplit(":", 1)[0], raw, f"{label} pooled at {st['event']}")

    def test_the_pool_cap_frees_the_65th_dropped_buffer(self):
        """pool_put keeps at most 64 buffers (`if pool.len() < 64`); a drop
        beyond that is a real free. Inherited from the shared _Pool, and it
        must show up as freed here, not vanish."""
        plan = mem.Plan(["a", "b"], [mem.Buffer(f"s{i}", "t", 1, "a", "b") for i in range(65)], set(), [])
        r = plan.report()
        end = stage(r, "b")
        self.assertEqual(end["pooled_bytes"], 64 * 8)
        self.assertEqual(end["freed_bytes_so_far"], 8)
        self.assertEqual(len(end["pooled_here"]), 64)
        self.assertEqual(end["freed_here"], ["t::s64 (pool full)"])
        self.assertEqual(r["peak_accounted_bytes"], 65 * 8, "the peak is BEFORE the drop, with all 65 live")

    def test_a_fallback_the_device_cannot_take_is_refused(self):
        """[round-7 review, Codex on CL3] pool_take serves an exact match
        before any refusal: with two exact rows*nn capacities pooled, coef2
        takes one and the encoded take is served from the other, so the
        resident path completes and there is no fallback to count."""
        s = sizes(300, 10, 4, 16)
        with self.assertRaises(mem.PlanError) as cm:
            mem.fallback_hiding_commit(300, 10, 4, 16, 128, None, [s["enc"], s["enc"]])
        self.assertIn("unreachable", str(cm.exception))
        # one exact rows*nn is consumed by coef2; the refusal IS reachable
        r = mem.fallback_hiding_commit(300, 10, 4, 16, 128, None, [s["enc"]]).report()
        self.assertEqual(r["allocation"]["reuse_count"], 3)
        ref = memplan.commitment_plan(300, 10, 4, 16, mode="fallback", pool_inventory_bytes=[s["enc"]])
        self.assertEqual(ref["outcome"], "fallback")
        self.assertEqual(r["peak_accounted_bytes"], ref["component_peak_accounted_bytes"])

    def test_the_blake3_state_is_counted_in_u64_words(self):
        plan = mem.chunked_hiding_commit(300, 10, 4, 16, 128)
        st = next(b for b in plan.buffers if b.name == "blake3_column_state")
        self.assertEqual(st.elem_bytes, 8)
        self.assertEqual(st.count, (memplan.B3_STATE_SLOTS * 4096 + 1) // 2)
        self.assertEqual(st.nbytes, 3_162_112)  # the device's measured fresh state at this shape


class ReuseIdentity(unittest.TestCase):
    """[round-7 review, finding 5] take_min transfers a larger pooled
    capacity to a smaller request; it is counted once, under the new owner."""

    def test_fallback_serves_the_retry_from_the_released_pair_by_capacity(self):
        s = sizes(2000, 14, 4, 256, chunk=128, ntt_max_log=16)
        r = mem.fallback_hiding_commit(2000, 14, 4, 256, 128, 16).report()
        loop = stage(r, "chunk_loop")
        live = live_map(loop)
        coef, exp = live["commit::chunk_coefficients"], live["commit::chunk_expanded"]
        self.assertEqual(coef["origin"], "reused commit::inverse_coefficients capacity")
        self.assertEqual((coef["capacity_bytes"], coef["requested_bytes"]), (s["data"], s["ccoef"]))
        self.assertEqual(exp["origin"], "reused commit::expanded_coefficients capacity")
        self.assertEqual((exp["capacity_bytes"], exp["requested_bytes"]), (s["enc"], s["cenc"]))
        self.assertEqual(live["commit::chunk_encoded"]["origin"], "fresh")
        self.assertEqual(loop["pooled_bytes"], 0, "both released buffers are OWNED again, not pooled")
        expect = (s["tw"] + s["data"] + s["pads"] + s["pows"] + s["data"] + s["enc"]
                  + s["cenc"] + s["state"] + s["leaves"])
        self.assertEqual(r["peak_accounted_bytes"], expect)
        self.assertEqual(r["peak_event"], "chunk_loop")
        self.assertEqual(r["no_reuse_bound_bytes"] - r["peak_accounted_bytes"], s["ccoef"] + s["cenc"])
        a = r["allocation"]
        self.assertEqual((a["reuse_count"], a["reuse_capacity_bytes"], a["reuse_requested_bytes"]),
                         (2, s["data"] + s["enc"], s["ccoef"] + s["cenc"]))
        # after return the transferred capacities sit in the pool under the NEW owners' names
        self.assertIn(f"commit::chunk_coefficients:{s['data']}", r["end_state"]["pooled"])
        self.assertIn(f"commit::chunk_expanded:{s['enc']}", r["end_state"]["pooled"])

    def test_an_inventory_capacity_is_transferred_and_counted_once(self):
        """A released rows*nn buffer (e.g. from an earlier resident commit)
        serves the smaller chunk_coefficients request; the peak carries the
        full capacity once, not the capacity plus the request."""
        s = sizes(300, 10, 4, 16, chunk=128)
        r = mem.chunked_hiding_commit(300, 10, 4, 16, 128, None, [s["enc"]]).report()
        loop = stage(r, "chunk_loop")
        coef = live_map(loop)["commit::chunk_coefficients"]
        self.assertEqual(coef["origin"], "reused inventory capacity")
        self.assertEqual(coef["capacity_bytes"], s["enc"])
        self.assertEqual(loop["pooled_bytes"], 0)
        expect = s["tw"] + s["data"] + s["pads"] + s["pows"] + s["enc"] + 2 * s["cenc"] + s["state"] + s["leaves"]
        self.assertEqual(r["peak_accounted_bytes"], expect)
        self.assertEqual(r["no_reuse_bound_bytes"], expect + s["ccoef"])
        self.assertEqual(r["allocation"]["reuse_count"], 1)
        self.assertIn(f"commit::chunk_coefficients:{s['enc']}", r["end_state"]["pooled"])
        ref = memplan.commitment_plan(300, 10, 4, 16, mode="chunked", pool_inventory_bytes=[s["enc"]])
        self.assertEqual(r["peak_accounted_bytes"], ref["component_peak_accounted_bytes"])

    def test_pending_reuse_across_roles_counts_capacity_once(self):
        """W resident, then A chunked: A's take_min is served by W's pooled
        coef (rows*n) and coef2 (rows*nn) capacities. The A-commit stage
        holds each capacity exactly once, and the no-reuse bound exceeds the
        reuse count by exactly the two requests that were not allocated."""
        w, a = sizes(300, 10, 4, 16), sizes(200, 10, 4, 16, chunk=128)
        r = mem.pending_private_block(1, {
            "W": {"rows": 300, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "resident"},
            "A": {"rows": 200, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"},
        }, ntt_max_log=12).report()
        st = stage(r, "b0_ffn_A_commit")
        live = live_map(st)
        self.assertEqual(live["block0::ffn_A_chunk_coefficients"]["origin"],
                         "reused block0::ffn_W_inverse_coefficients capacity")
        self.assertEqual(live["block0::ffn_A_chunk_coefficients"]["capacity_bytes"], w["data"])
        self.assertEqual(live["block0::ffn_A_chunk_expanded"]["origin"],
                         "reused block0::ffn_W_expanded_coefficients capacity")
        self.assertEqual(live["block0::ffn_A_chunk_expanded"]["capacity_bytes"], w["enc"])
        self.assertEqual(st["pooled_bytes"], 0)
        tw = 2 * ((1 << 12) - 1) * 8
        expect = (tw + w["data"] + w["enc"] + a["data"] + a["pads"] + a["pows"]
                  + w["data"] + w["enc"] + a["cenc"] + a["state"] + a["leaves"])
        self.assertEqual(st["accounted_bytes"], expect)
        self.assertEqual(r["numeric_subtotal_bytes_excluding_symbolic"], expect)
        self.assertEqual(r["numeric_subtotal_no_reuse_bytes_excluding_symbolic"] - expect, a["ccoef"] + a["cenc"])
        # W's pads, powers and leaves were FREED at that event, not pooled
        self.assertEqual(set(st["freed_here"]),
                         {"block0::ffn_W_pads", "block0::ffn_W_coset_powers", "block0::ffn_W_device_leaf_hashes"})
        self.assertFalse(r["complete"], "H, attention, seam and challenge state are still symbolic")


class PendingBlocks(unittest.TestCase):
    def test_one_block_is_incomplete_and_refuses_a_peak(self):
        r = mem.pending_private_block(1).report()
        self.assertFalse(r["complete"])
        # the single most important behaviour: no quotable peak
        self.assertIsNone(r["peak_accounted_mib"])
        self.assertIsNone(r["peak_event"])
        self.assertIsNone(r["no_reuse_bound_bytes"])
        self.assertIn("peak_refused_because", r)

    def test_attention_terms_stay_symbolic(self):
        r = mem.pending_private_block(1).report()
        attn = [s for s in r["symbolic_buffers"] if "attn_" in s]
        self.assertEqual(len(attn), 3, "W/A/H attention retentions must all be symbolic")

    def test_two_blocks_double_the_symbolic_surface(self):
        one = mem.pending_private_block(1).report()
        two = mem.pending_private_block(2).report()
        # per block: 3 attn + 3 ffn + seam + challenge; the twiddles are process-wide
        self.assertEqual(one["symbolic_count"], 8 + 1)
        self.assertEqual(two["symbolic_count"], 2 * 8 + 1)
        self.assertFalse(two["complete"])

    def test_composition_overlaps_rather_than_reusing(self):
        """A03 warns composition can INCREASE overlap. Every commitment must be
        live simultaneously at the final opening, not released between blocks."""
        plan = mem.pending_private_block(2)
        idx = plan.schedule.index("final_open")
        live = plan.state_at(idx - 1)["live_symbolic"]
        self.assertTrue(any("block0" in x for x in live), "block 0 must still be live")
        self.assertTrue(any("block1" in x for x in live), "block 1 must be live too")

    def test_a_bare_row_count_is_refused_never_800_bytes(self):
        """[round-7 review, finding 4] ffn_rows={"W": 100} once became a
        100-element, 800-byte buffer. A row count with no width or
        representation is refused; an omitted role stays symbolic."""
        with self.assertRaises(mem.PlanError) as cm:
            mem.pending_private_block(1, ffn_rows={"W": 100})
        self.assertIn("800 bytes", str(cm.exception))
        for bad in ({"W": 100}, {"W": {"rows": 100}}, {"W": {"rows": 100, "log_cols": 10}},
                    {"W": {"rows": 100, "log_cols": 10, "inv_rate": 4, "q_pad": 16}},
                    {"W": {"rows": 100, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "gpu"}},
                    {"W": {"rows": 100, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked", "bytes": 800}},
                    {"Q": {"rows": 100, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}},
                    {"W": {"rows": -1, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}},
                    [("W", 100)]):
            with self.subTest(layouts=bad), self.assertRaises(mem.PlanError):
                mem.pending_private_block(1, bad)
        r = mem.pending_private_block(1).report()
        self.assertIn("block0::ffn_W_retained", r["symbolic_buffers"])
        self.assertEqual(r["numeric_subtotal_bytes_excluding_symbolic"], 0)
        self.assertNotIn("800", json.dumps(r["stages"]))

    def test_a_layout_is_counted_with_the_commit_rules_and_the_rest_stays_symbolic(self):
        s = sizes(300, 10, 4, 16, chunk=128)
        r = mem.pending_private_block(1, {"W": {"rows": 300, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}}).report()
        self.assertNotIn("block0::ffn_W_retained", r["symbolic_buffers"])
        self.assertIn("block0::ffn_A_retained", r["symbolic_buffers"])
        self.assertIn("gpu::twiddles", r["symbolic_buffers"], "no ntt_max_log given: the tables stay symbolic")
        self.assertFalse(r["complete"], "attention is still symbolic")
        self.assertIsNone(r["peak_accounted_bytes"])
        # at the commit: retained set + scratch + leaves; at the next event the
        # scratch is pooled and the leaves freed; the retained set lives to final_open
        commit = stage(r, "b0_ffn_W_commit")
        self.assertEqual(commit["accounted_bytes"], s["data"] + s["pads"] + s["pows"] + s["ccoef"] + 2 * s["cenc"] + s["state"] + s["leaves"])
        nxt = stage(r, "b0_ffn_A_commit")
        self.assertEqual(nxt["live_bytes"], s["data"] + s["pads"] + s["pows"])
        self.assertEqual(nxt["pooled_bytes"], s["ccoef"] + 2 * s["cenc"] + s["state"])
        self.assertEqual(nxt["freed_here"], ["block0::ffn_W_device_leaf_hashes"])
        before_open = stage(r, "b0_seam")
        self.assertEqual(set(live_map(before_open)), {"block0::ffn_W_systematic_data", "block0::ffn_W_pads", "block0::ffn_W_coset_powers"})
        opened = stage(r, "final_open")
        self.assertEqual(opened["live_bytes"], 0)
        self.assertEqual(set(opened["freed_here"]), {"block0::ffn_W_pads", "block0::ffn_W_coset_powers"})
        self.assertEqual(stage(r, "drain")["pooled_bytes"], 0)
        self.assertEqual(r["meta"]["ffn_symbolic_roles"], ["A", "H"])

    def test_all_three_layouts_and_tables_are_still_not_a_complete_plan(self):
        lay = {"rows": 300, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}
        r = mem.pending_private_block(2, {"W": lay, "A": lay, "H": lay}, ntt_max_log=12).report()
        self.assertFalse(r["complete"])
        self.assertIsNone(r["peak_accounted_bytes"])
        self.assertEqual(r["symbolic_count"], 2 * (3 + 2), "attention, seam and challenge state per block")
        self.assertFalse(r["safe_to_run"])
        # six identical chunked commits: the first allocates its four scratch
        # buffers fresh, every later one is served from the pool at exact size
        # (no drain between blocks), so 5 x 4 reuses of exactly the requested
        # capacity; the six data buffers are exact takes that nothing matches
        s = sizes(300, 10, 4, 16, chunk=128)
        a = r["allocation"]
        self.assertEqual(a["reuse_count"], 5 * 4)
        self.assertEqual(a["reuse_capacity_bytes"], a["reuse_requested_bytes"])
        self.assertEqual(a["reuse_capacity_bytes"], 5 * (s["ccoef"] + 2 * s["cenc"] + s["state"]))
        self.assertEqual(a["fresh_pool_count"], 6 + 4)
        self.assertEqual(a["fresh_raw_count"], 1 + 6 * 3, "twiddles + (pads, powers, leaves) per commit")
        with self.assertRaises(mem.PlanError):
            mem.pending_private_block(1, {"W": lay}, ntt_max_log=11)  # tables too small for nn = 2^12

    def test_drain_between_blocks_frees_the_pooled_scratch(self):
        lay = {"rows": 300, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}
        held = mem.pending_private_block(2, {"W": lay}, ntt_max_log=12).report()
        drained = mem.pending_private_block(2, {"W": lay}, ntt_max_log=12, drain_between_blocks=True).report()
        self.assertGreater(stage(held, "b0_seam")["pooled_bytes"], 0)
        self.assertEqual(stage(drained, "b0_seam")["pooled_bytes"], 0)
        self.assertGreater(stage(drained, "b0_seam")["drained_bytes"], 0)
        # the retained commitments are NOT drained: they are live, not pooled
        self.assertEqual(stage(drained, "b0_seam")["live_bytes"], stage(held, "b0_seam")["live_bytes"])

    def test_unsupported_block_counts_are_rejected(self):
        for bad in (0, 3, -1, True, 1.0):
            with self.subTest(blocks=bad), self.assertRaises(mem.PlanError):
                mem.pending_private_block(bad)


class Authorization(unittest.TestCase):
    def test_no_plan_ever_authorises_a_run(self):
        lay = {"rows": 300, "log_cols": 10, "inv_rate": 4, "q_pad": 16, "path": "chunked"}
        for r in (mem.resident_hiding_commit(64, 8, 4, 16).report(),
                  mem.chunked_hiding_commit(300, 10, 4, 16, 128).report(),
                  mem.fallback_hiding_commit(300, 10, 4, 16, 128).report(),
                  mem.pending_private_block(1).report(),
                  mem.pending_private_block(2, {"W": lay, "A": lay, "H": lay}, ntt_max_log=12).report()):
            self.assertFalse(r["safe_to_run"])
            self.assertFalse(r["measured"])
            self.assertTrue(r["release_is_not_free"])
            self.assertTrue(r["unaccounted"])
            self.assertIn("cannot authorise", r["authorization"])


class Cli(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = mem.main(argv)
        return code, json.loads(out.getvalue())

    def test_chunked_reports_the_reviews_case(self):
        code, r = self.run_main(["chunked", "--rows", "300", "--log-cols", "10", "--q-pad", "16", "--chunk", "1"])
        self.assertEqual(code, 0)
        self.assertEqual(r["meta"]["shape"]["rmax"], 128)
        coef = live_map(stage(r, "chunk_loop"))["commit::chunk_coefficients"]
        self.assertEqual(coef["requested_bytes"], 1_048_576)
        self.assertFalse(r["safe_to_run"])

    def test_pending_accepts_layouts_and_refuses_bad_ones(self):
        code, r = self.run_main(["pending", "--blocks", "2", "--ffn-layout", "W=300:10:4:16:chunked:128",
                                 "--ffn-layout", "A=200:10:4:16:resident", "--ntt-max-log", "12", "--drain-between-blocks"])
        self.assertEqual(code, 0)
        self.assertFalse(r["complete"])
        self.assertEqual(r["meta"]["ffn_layouts"]["W"]["rmax"], 128)
        self.assertEqual(r["meta"]["ffn_layouts"]["A"]["path"], "resident")
        for argv in (["pending", "--ffn-layout", "W=100"],
                     ["pending", "--ffn-layout", "W=100:10:4:16:gpu"],
                     ["chunked", "--rows", "0"],
                     ["resident", "--rows", "64", "--inventory-bytes", "0"]):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as cm:
                with contextlib.redirect_stderr(io.StringIO()):
                    mem.main(argv)
            self.assertEqual(cm.exception.code, 2)

    def test_fallback_and_inventory_forms(self):
        code, r = self.run_main(["fallback", "--rows", "2000", "--ntt-max-log", "16"])
        self.assertEqual(code, 0)
        self.assertEqual(r["peak_event"], "chunk_loop")
        self.assertEqual(r["allocation"]["reuse_count"], 2)
        code, r = self.run_main(["chunked", "--rows", "300", "--log-cols", "10", "--q-pad", "16", "--inventory-bytes", "9830400"])
        self.assertEqual(r["allocation"]["inventory"], ["inventory:9830400"])
        self.assertEqual(r["allocation"]["reuse_count"], 1)


if __name__ == "__main__":
    unittest.main()
