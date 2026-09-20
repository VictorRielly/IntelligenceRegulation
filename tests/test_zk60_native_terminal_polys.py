"""Tests for the ported terminal polynomials (scripts/zk60_native_terminal_polys.py).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_terminal_polys.py"

The four source-pinned captures are tracked in the repository, so a missing
capture is a FAILURE here, never a silent skip: a green suite must mean the
port actually ran against the real captured views.

What these tests are about: the STRONG form of each slot's final check,
`fin_s == c_s * mask_eval_s + poly_s(vals_s)`, with every `poly_s` recomputed
from the published terminals by the Python port of the Rust closures.  They
establish a consistency property of the verifier's view, NOT a privacy
property; D8 and D11 are untouched.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

CAPTURES = os.path.join(ROOT, "results", "zk60_native_captures_20260919")

from zk60_native_jv_capture import load_all  # noqa: E402
from zk60_native_jv_cfs import terminal_identity  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    P,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_mul,
)
from zk60_native_jv_replay import Replay  # noqa: E402
import zk60_native_joint_view as gate  # noqa: E402
import zk60_native_terminal_polys as tp  # noqa: E402

_CAPS = None
_REPLAYS = None


def caps():
    global _CAPS, _REPLAYS
    if _CAPS is None:
        _CAPS = load_all(CAPTURES)
        _REPLAYS = {c.proof_sha256: Replay(c).run() for c in _CAPS}
    return _CAPS, _REPLAYS


def one(kind):
    cs, rp = caps()
    c = next(c for c in cs if c.kind == kind)
    return c, rp[c.proof_sha256]


class SourcePins(unittest.TestCase):
    """The port is a transcription of Rust that lives elsewhere: drift must be
    loud, so every entry point checks the pins first."""

    def test_every_pinned_source_matches_the_file_in_the_worktree(self):
        pins = tp.check_source_pins(ROOT)
        self.assertEqual(len(pins), len(tp.SOURCE_PINS))
        for pin in tp.SOURCE_PINS:
            self.assertEqual(pins[pin.path]["sha256"], pin.sha256)
            self.assertEqual(pins[pin.path]["git_blob"], pin.blob)

    def test_both_argument_files_are_pinned(self):
        pinned = {p.path for p in tp.SOURCE_PINS}
        self.assertIn("hashline/src/private_block/argument.rs", pinned)
        self.assertIn("hashline/src/private_attention/argument.rs", pinned)
        for port in tp.BLOCK_PORTS + tp.ATTENTION_PORTS:
            self.assertIn(port.source, pinned)

    def test_a_changed_source_is_a_hard_error_naming_the_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            for pin in tp.SOURCE_PINS:
                dst = os.path.join(tmp, pin.path)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(os.path.join(ROOT, pin.path), dst)
            tp.check_source_pins(tmp)  # the copy is byte-identical: passes
            changed = tp.SOURCE_PINS[0].path
            with open(os.path.join(tmp, changed), "ab") as fh:
                fh.write(b"\n// a later edit to the closures\n")
            with self.assertRaises(tp.SourcePinError) as caught:
                tp.check_source_pins(tmp)
            msg = str(caught.exception)
            self.assertIn(changed, msg)
            self.assertIn("MISMATCH", msg)
            self.assertIn("Do NOT re-pin to make this pass", msg)

    def test_the_moved_mle_pin_keeps_both_hashes(self):
        """The captures were taken against the OLD `mle.rs`; the pin moved on
        2026-09-20 after the file was re-read function by function.  Both
        hashes stay in the tool so a later reader can see what moved."""
        rec = next(r for r in tp.REPIN_HISTORY if r.path == "zkp-core/src/mle.rs")
        pin = next(p for p in tp.SOURCE_PINS if p.path == "zkp-core/src/mle.rs")
        self.assertIn("131cf1b49a2f280147ccb1d8f374c139cd7033a8a4ddb02c473b751937409614",
                      rec.captured_against)
        self.assertIn("649a63d3bada92e3ca0c8c327f4591165fa3716f", rec.captured_against)
        self.assertIn(pin.sha256, rec.repinned_at)
        self.assertIn(pin.blob, rec.repinned_at)
        self.assertEqual(rec.date, "2026-09-20")
        reread = dict(rec.functions)
        # every function the Python tools port or rely on, with its verdict
        for name in ("eq_table", "eq_table_msb", "eq_point", "eval_mle_ext",
                     "interpolate_eval"):
            self.assertIn("byte-identical", reread[name])
        self.assertIn("CHANGED", reread["fold_rows_i8"])
        self.assertIn("CHANGED", reread["fold_rows_i32"])
        pins = tp.check_source_pins(ROOT)
        self.assertIn("captured_against", pins["zkp-core/src/mle.rs"])
        self.assertEqual(len(pins["zkp-core/src/mle.rs"]["functions_reread"]),
                         len(rec.functions))

    def test_a_missing_source_is_a_hard_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(tp.SourcePinError) as caught:
                tp.check_source_pins(tmp)
            self.assertIn("is missing", str(caught.exception))


class PortTable(unittest.TestCase):
    """The ordered slot table is the port's contract with the Rust source."""

    def test_the_two_tables_have_the_declared_slot_counts_in_order(self):
        self.assertEqual(len(tp.BLOCK_PORTS), 23)
        self.assertEqual(len(tp.ATTENTION_PORTS), 18)
        for ports in (tp.BLOCK_PORTS, tp.ATTENTION_PORTS):
            self.assertEqual([p.index for p in ports], list(range(len(ports))))
            for p in ports:
                self.assertRegex(p.lines, r"^\d+-\d+$")
                self.assertTrue(p.fn.__doc__, f"slot {p.index} has no ported docstring")

    def test_every_slot_of_every_capture_matches_its_port_entry(self):
        cs, _ = caps()
        for c in cs:
            ports = tp.ports_for(c.profile)
            self.assertEqual(len(ports), len(c.slots))
            for port, arg in zip(ports, c.slots):
                with self.subTest(capture=c.proof_sha256[:12], slot=port.index):
                    self.assertEqual(arg["slot"], port.index)
                    self.assertEqual(arg["name"], port.name)
                    self.assertEqual(len(arg["definition_challenges"]), port.draws)
                    self.assertEqual(tuple(t["kind"] for t in arg["tables"]), port.tables)

    def test_the_table_kind_spec_expands_as_written(self):
        self.assertEqual(tp._kinds("e u p*3"),
                         ("eq", "public", "private", "private", "private"))


class StrongTerminalCheck(unittest.TestCase):
    """fin = c * mask_eval + poly(terminals), per slot, on all four captures."""

    def test_every_slot_of_every_capture_is_checked_and_equal(self):
        cs, rp = caps()
        want = {"block": 23, "attention": 18}
        for c in cs:
            out = tp.check_capture(c, rp[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertEqual(out["findings"], [])
                self.assertEqual(out["not_checkable"], [])
                self.assertEqual(out["slots"], want[c.kind])
                self.assertEqual(out["slots_checked"], out["slots"])
                self.assertEqual(out["slots_equal"], out["slots"])
                self.assertTrue(out["ok"])

    def test_the_recomputed_polynomial_equals_the_stored_one(self):
        """The capture stores `fin - c*mask_eval`; the port recomputes the same
        value from the published terminals.  This is exactly the step report
        section 3.1 had to cite instead of check."""
        cs, rp = caps()
        for c in cs:
            out = tp.check_capture(c, rp[c.proof_sha256])
            self.assertEqual(out["slots_matching_the_stored_terminal_polynomial"],
                             out["slots"])

    def test_each_mask_evaluation_is_the_published_m_functional_value(self):
        cs, rp = caps()
        for c in cs:
            out = tp.check_capture(c, rp[c.proof_sha256])
            self.assertEqual(out["mask_evaluations_published_as_the_slot_functional"],
                             out["slots"])

    def test_the_check_runs_at_the_replayed_challenges(self):
        c, r = one("block")
        self.assertEqual(tp.check_capture(c, r)["challenges_from"], "transcript replay")
        # and, as a cross-check, from the capture's own recorded challenges
        out = tp.check_capture(c, None)
        self.assertEqual(out["challenges_from"], "the capture")
        self.assertTrue(out["ok"])

    def test_the_summary_carries_no_witness_material(self):
        """The record must carry counts, names and equal / not equal only."""
        c, r = one("attention")
        out = tp.summary(c, r)
        self.assertNotIn("per_slot", out)
        self.assertEqual(out["slots_unequal"], [])
        self.assertEqual(sorted(out), sorted([
            "capture", "challenges_from", "findings", "mask_evaluations_published_as_the_slot_functional",
            "not_checkable", "ok", "profile", "slots", "slots_checked", "slots_equal",
            "slots_matching_the_stored_terminal_polynomial", "slots_unequal",
        ]))


class NegativeControls(unittest.TestCase):
    def test_a_changed_terminal_polynomial_fails_at_that_slot_and_only_there(self):
        for kind in ("block", "attention"):
            c, r = one(kind)
            ports = tp.ports_for(c.profile)
            for index in range(len(ports)):
                bad = tp.check_capture(c, r, ports=tp.perturbed_ports(ports, index))
                with self.subTest(kind=kind, slot=index):
                    self.assertEqual(
                        [row["slot"] for row in bad["per_slot"] if not row["equal"]],
                        [index],
                    )
            self.assertTrue(tp.check_capture(c, r)["ok"], "the ports were not restored")

    def test_a_changed_claimed_evaluation_fails_at_that_slot_and_only_there(self):
        """The perturbation the WEAK identity of report section 3.1 cannot see."""
        for kind in ("block", "attention"):
            c, r = one(kind)
            for index in range(len(c.slots)):
                arg = c.slots[index]
                arg["terminals"][0][0] = (arg["terminals"][0][0] + 1) % P
                bad = tp.check_capture(c, r)
                arg["terminals"][0][0] = (arg["terminals"][0][0] - 1) % P
                with self.subTest(kind=kind, slot=index):
                    self.assertEqual(
                        [row["slot"] for row in bad["per_slot"] if not row["equal"]],
                        [index],
                    )
            self.assertTrue(tp.check_capture(c, r)["ok"], "the capture was not restored")

    def test_the_weak_identity_stays_blind_where_the_strong_one_fires(self):
        """Side by side, on one slot: the stored-value identity of stage 3 does
        not move, the ported polynomial does."""
        c, r = one("block")
        index = 14  # 03 D zero-check, the deepest table list of the profile
        arg = c.slots[index]
        arg["terminals"][0][0] = (arg["terminals"][0][0] + 1) % P
        weak = terminal_identity(c, r)
        strong = tp.check_capture(c, r)
        arg["terminals"][0][0] = (arg["terminals"][0][0] - 1) % P
        self.assertEqual(weak["derived_mask_evaluation_identity"], weak["slots"])
        self.assertEqual([row["slot"] for row in strong["per_slot"] if not row["equal"]],
                         [index])
        self.assertTrue(tp.check_capture(c, r)["ok"])

    def test_the_standing_controls_pass_on_all_four_captures(self):
        cs, rp = caps()
        for c in cs:
            out = tp.terminal_poly_controls(c, rp[c.proof_sha256])
            with self.subTest(capture=c.proof_sha256[:12]):
                self.assertEqual(len(out["controls"]),
                                 len(tp.DEFAULT_CONTROL_SLOTS[c.profile]))
                for row in out["controls"]:
                    self.assertEqual(row["changed_terminal_polynomial_fails_at"],
                                     [row["slot"]])
                    self.assertEqual(row["changed_claimed_evaluation_fails_at"],
                                     [row["slot"]])
                self.assertTrue(out["honest_again"])
                self.assertTrue(out["ok"])

    def test_a_slot_whose_table_order_differs_is_not_checkable(self):
        """A drifted capture (or a drifted port) must be REPORTED, not scored."""
        c, r = one("attention")
        arg = c.slots[0]
        saved = arg["tables"]
        arg["tables"] = list(reversed(saved))
        out = tp.check_capture(c, r)
        arg["tables"] = saved
        self.assertEqual([n["slot"] for n in out["not_checkable"]], [0])
        self.assertIn("table push order", out["not_checkable"][0]["reason"])
        self.assertEqual(out["slots_checked"], out["slots"] - 1)
        self.assertFalse(out["ok"])
        self.assertTrue(tp.check_capture(c, r)["ok"])


class PortedPieces(unittest.TestCase):
    """The small ported helpers, on values a reader can check by hand."""

    def test_eq_point_agrees_with_the_eq_table_of_the_tool(self):
        """eq(r, s) = sum_x eq(r, x) eq(s, x): the port's two-point form against
        the table form the rest of the diagnostic already uses."""
        r = [(3, 4), (5, 6), (7, 8)]
        s = [(11, 2), (13, 5), (17, 1)]
        er, es = eq_table_msb(r), eq_table_msb(s)
        want = (0, 0)
        for a, b in zip(er, es):
            want = f2_add(want, f2_mul(a, b))
        self.assertEqual(tp.eq_point(r, s), want)
        # and the boolean corners, where eq is the indicator
        self.assertEqual(tp.eq_point([(0, 0)], [(1, 0)]), (0, 0))
        self.assertEqual(tp.eq_point([(1, 0)], [(1, 0)]), F2_ONE)

    def test_pow256_is_the_limb_base(self):
        self.assertEqual(tp.POW256[1], (256, 0))
        self.assertEqual(tp.POW256[2], (65536, 0))
        self.assertEqual(tp.POW256[3], (1 << 24, 0))

    def test_the_lookup_lists_have_the_declared_lengths(self):
        """layout.rs asserts `lookups(dom).len().div_ceil(2) == helpers(dom).1`
        for every domain; the port must reproduce both sides."""
        for lookups, helpers in ((tp.pb_lookups, tp.PB_HELPERS),
                                 (tp.pa_lookups, tp.PA_HELPERS)):
            for dom, (_first, count) in helpers.items():
                with self.subTest(dom=dom):
                    self.assertEqual(-(-len(lookups(dom)) // 2), count)
        self.assertEqual(len(tp.pb_lookups("D")), 38)
        self.assertEqual(len(tp.pa_lookups("D")), 20)

    def test_the_tag_offsets_are_the_source_constants(self):
        self.assertEqual((tp.TAG_EXP, tp.TAG_U8, tp.TAG_ACT), (129, 133, 134))

    def test_the_context_reads_the_logup_challenges_in_draw_order(self):
        """protocol.rs draws beta, then gamma, then alpha."""
        c, _ = one("block")
        cx = tp.ModuleContext(c)
        beta, gamma, alpha = (f2_from_list(x) for x in c.doc["logup_challenges"])
        self.assertEqual((cx.beta, cx.gamma, cx.alpha), (beta, gamma, alpha))
        self.assertEqual(cx.g_u8, (gamma[0] * 133 % P, gamma[1] * 133 % P))

    def test_lam_z_comes_from_the_slot_that_draws_it(self):
        for kind in ("block", "attention"):
            c, _ = one(kind)
            slot, at = tp.LAM_Z_AT[c.profile]
            self.assertEqual(
                tp.ModuleContext(c).lam_z,
                f2_from_list(c.slots[slot]["definition_challenges"][at]),
            )
            self.assertIn("masked row sums", c.slots[slot]["name"])


class GateStage7(unittest.TestCase):
    def test_the_stage_runs_and_reports_every_capture(self):
        cs, rp = caps()
        out = gate.stage7(cs, rp, controls=False)
        self.assertTrue(out["ok"])
        self.assertFalse(out["privacy_property_established"])
        self.assertEqual(len(out["per_capture"]), 4)
        self.assertEqual(sum(r["slots_equal"] for r in out["per_capture"]), 82)

    def test_the_retained_record_carries_the_stage(self):
        path = os.path.join(ROOT, "results", "zk60_native_joint_view", "joint_view.json")
        self.assertTrue(os.path.exists(path), "run the gate first")
        import json

        with open(path) as fh:
            rec = json.load(fh)
        s7 = rec["stage7_terminal_polynomial_port"]
        self.assertTrue(s7["ok"])
        self.assertFalse(s7["privacy_property_established"])
        self.assertEqual(sum(r["slots_equal"] for r in s7["per_capture"]), 82)
        self.assertEqual(sum(len(r["not_checkable"]) for r in s7["per_capture"]), 0)
        for pin in tp.SOURCE_PINS:
            self.assertEqual(s7["source_pins"][pin.path]["sha256"], pin.sha256)
        self.assertIn("zk60_native_terminal_polys.py", rec["tool_sha256"])

    def test_the_retained_port_evidence_matches_a_fresh_run(self):
        path = os.path.join(ROOT, "results", "zk60_native_terminal_polys",
                            "terminal_polys.json")
        self.assertTrue(os.path.exists(path), "run the port's own command first")
        import hashlib
        import json

        with open(path) as fh:
            rec = json.load(fh)
        self.assertTrue(rec["ok"])
        self.assertFalse(rec["privacy_property_established"])
        with open(os.path.join(ROOT, "scripts", "zk60_native_terminal_polys.py"), "rb") as fh:
            self.assertEqual(rec["port_sha256"], hashlib.sha256(fh.read()).hexdigest())


if __name__ == "__main__":
    unittest.main()
