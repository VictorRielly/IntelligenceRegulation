"""Tests for the PLANE INDEX TABLE and the per-slot terminal identity.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_planeindex.py"

TWO ARMS, the same discipline as `test_zk60_native_run_gate.py`.

* The RECORDED arm always runs.  The gate's own evidence under
  `results/zk60_native_run_gate_planeindex/` is tracked, so a green suite
  asserts the figures the report quotes -- 83 / 52 planes, 377 / 470 rows,
  36 of 36 slot checks, the eleven OPEN slots and why, the five controls,
  the 24-channel table with 15 open -- and asserts that the evidence was
  produced by the tools now in the tree.
* The LIVE arm needs the two NEW bundles (~38.5 MB each, on the Rust lane's
  worktree) and is skipped when they are absent.  The recorded arm is what
  keeps a skip from hiding the work.  The whole live arm is well under a
  minute: the terminal identity is 0.3 s per bundle and the controls 1.5 s.

Nothing here asserts a privacy property.  The terminal identity is the
VERIFIER'S OWN final check, recomputed; passing it says the receipt is
self-consistent at its real challenges, and says nothing about disclosure.
"""

from __future__ import annotations

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_planeindex")
OLD_EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_C = os.path.join(BUNDLES, "run-c-tame")
RUN_D = os.path.join(BUNDLES, "run-d-zero")
RUN_A = os.path.join(BUNDLES, "run-a-tame")
HAVE_NEW = os.path.isdir(RUN_C) and os.path.isdir(RUN_D)
HAVE_OLD = os.path.isdir(RUN_A)

from zk60_native_jv_field import f2_add, f2_from_list, F2_ONE  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_planes import (  # noqa: E402
    NO_TABLE,
    PlaneIndex,
    PlaneIndexError,
    plane_index_of,
)
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_tcontrols import terminal_controls  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    COVERED,
    COVERED_WITH_TABLES,
    COVERED_WITHOUT_TABLES,
    PORTS,
    PUBLIC_SPEC,
    covered_at,
    PadGeometry,
    check_source_pins,
    check_terminals,
    lookups_at,
    table_digest,
)

_STATE = {}


def loaded(which=RUN_C):
    """The bundle, its plane index and its replay, built once."""
    if which not in _STATE:
        b = RunBundle(which)
        index, reason = plane_index_of(b)
        rp = RunReplay(b).run()
        _STATE[which] = (b, index, reason, rp)
    return _STATE[which]


# ------------------------------------------------------- the recorded arm
class TestRecordedEvidence(unittest.TestCase):
    """What the report's section 6 quotes, asserted from the evidence."""

    def records(self):
        out = {}
        for name in ("run-c-tame", "run-d-zero"):
            path = os.path.join(EVIDENCE, f"{name}.json")
            self.assertTrue(os.path.exists(path), f"{path} is missing")
            with open(path) as fh:
                out[name] = json.load(fh)
        return out

    def test_both_new_bundles_have_a_green_record_claiming_no_privacy_property(self):
        for name, rec in self.records().items():
            self.assertTrue(rec["ok"], f"{name}: the gate's record is not ok")
            self.assertFalse(rec["privacy_property_established"])
            self.assertFalse(rec["privacy_acceptance"])
            self.assertFalse(rec["privacy_review_complete"])
            for k in [k for k in rec if k.startswith("stage")]:
                self.assertTrue(rec[k]["ok"], f"{name}: {k} is not ok")

    def test_the_evidence_was_produced_by_the_tools_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in self.records().items():
            self.assertEqual(
                rec["tool_sha256"], want,
                f"{name}: the record was produced by different tool bytes; re-run "
                "the gate and refresh the evidence",
            )

    def test_the_recorded_plane_index_figures(self):
        for name, rec in self.records().items():
            pi = rec["stage8_plane_index_and_terminals"]["plane_index"]
            self.assertTrue(pi["present"], name)
            self.assertEqual(pi["a_planes"], 83, name)
            self.assertEqual(pi["h_planes"], 52, name)
            self.assertEqual(pi["a_data_rows"], 377, name)
            self.assertEqual(pi["h_data_rows"], 470, name)
            self.assertTrue(pi["a_planes_tile_exactly"], name)
            self.assertTrue(pi["h_plane_halves_tile_exactly"], name)
            self.assertTrue(pi["every_plane_is_read_by_a_slot"], name)
            self.assertEqual(pi["findings"], [], name)
            for st in pi["per_stage"]:
                self.assertEqual(st["slots"], 23, name)
                self.assertEqual(st["terminals"], st["private_tables"], name)
                self.assertEqual(
                    st["slice_offsets_inside_the_plane"],
                    st["slice_offsets_checked"], name,
                )

    def test_the_recorded_terminal_identity_is_twelve_slots_of_twenty_three(self):
        for name, rec in self.records().items():
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertTrue(t["checked"], name)
            self.assertEqual(len(t["covered_slots"]), 12, name)
            self.assertEqual(len(t["open_slots"]), 11, name)
            self.assertEqual(t["slot_checks_expected"], 36, name)
            self.assertEqual(t["slot_checks_attempted"], 36, name)
            self.assertEqual(t["slot_checks_equal"], 36, name)
            self.assertEqual(
                t["slot_checks_matching_the_stored_terminal_polynomial"], 36, name
            )
            self.assertEqual(t["public_table_digest_failures"], [], name)
            self.assertEqual(t["findings"], [], name)
            self.assertTrue(t["source_pins"]["ok"], name)

    def test_every_open_slot_names_a_reason_and_none_is_the_plane_index(self):
        for name, rec in self.records().items():
            for row in rec["stage8_plane_index_and_terminals"][
                "terminal_identity"
            ]["open_slots"]:
                self.assertTrue(row["reason"], f"{name}: slot {row['slot']}")
                self.assertNotIn(
                    "plane index", row["reason"],
                    f"{name}: slot {row['slot']} blames the plane index table, "
                    "which this bundle carries",
                )

    def test_the_rebuilt_public_tables_are_named_and_their_digests_matched(self):
        for name, rec in self.records().items():
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertEqual(t["public_tables_rebuilt_and_digest_matched"], 11, name)
            for what in ("supp(T)", "supp(Ht)", "supp(L)", "supp(D)", "supp(S)",
                         "supp(F)", "causal_mask_at",
                         "the all-ones Dom::Tab vector"):
                self.assertIn(what, t["rebuilt_public_tables"], name)

    def test_the_recorded_controls_all_fire(self):
        for name, rec in self.records().items():
            ctl = rec["stage8_plane_index_and_terminals"]["controls"]
            self.assertTrue(ctl["ok"], f"{name}: {ctl.get('controls_that_did_not_fire')}")
            self.assertEqual(ctl["controls_that_did_not_fire"], [], name)
            got = {c["control"]: c for c in ctl["controls"]}
            self.assertEqual(sorted(got), ["CT-1", "CT-2", "CT-3", "CT-4", "CT-5"])
            self.assertTrue(got["CT-1"]["fails_at_exactly_the_perturbed_slot"], name)
            self.assertTrue(
                got["CT-1"]["the_transcript_replay_refuses_the_same_bundle"], name)
            self.assertTrue(got["CT-2"]["the_port_refuses_the_push_order"], name)
            self.assertTrue(
                got["CT-2"]["the_identity_fails_at_the_swapped_slot_in_every_stage"],
                name)
            self.assertTrue(got["CT-2"]["the_plane_index_loader_refuses"], name)
            self.assertTrue(got["CT-3"]["the_two_planes_really_are_the_same_size"], name)
            self.assertTrue(got["CT-3"]["the_plane_index_loader_refuses"], name)
            self.assertIn("slice offset", got["CT-3"]["loader_slice_offset_refusal"],
                          name)
            self.assertFalse(got["CT-4"]["table_present"], name)
            self.assertTrue(got["CT-4"]["reason_is_the_one_the_gate_had_before"], name)
            self.assertTrue(got["CT-5"]["the_flipped_table_does_not"], name)

    def test_the_channel_table_is_twenty_five_with_fifteen_open(self):
        """Round 2 recorded 24 channels with 15 open for these two bundles.
        Round 3 adds ONE entry -- the hash RULE of the run (decision D19) --
        which is DERIVED here as everywhere, so the table is 25 with the
        SAME 15 open: nothing these two bundles leave open closed, and
        nothing that was closed opened."""
        for name, rec in self.records().items():
            ch = rec["stage7_channels"]
            self.assertEqual(ch["total"], 25, name)
            self.assertEqual(len(ch["channels"]), 25, name)
            self.assertEqual(
                ch["counts"],
                {"constructed": 2, "derived": 4, "argued": 4, "open": 15},
                name,
            )
            self.assertEqual(ch["grading_failures"], [], name)

    def test_the_old_bundles_record_keeps_every_figure_it_had(self):
        """The two OLD bundles were re-run with the extended gate.  Their
        channel table grows by the split entry and nothing they MEASURE
        moves; the comparison is a tracked file, not a claim."""
        path = os.path.join(EVIDENCE, "old_bundles_unchanged.json")
        self.assertTrue(os.path.exists(path), f"{path} is missing")
        with open(path) as fh:
            cmp_ = json.load(fh)
        for name, row in cmp_["per_bundle"].items():
            self.assertEqual(row["channels_before"], 23, name)
            self.assertEqual(row["channels_after"], 24, name)
            self.assertEqual(row["identical_channel_entries"], 21, name)
            self.assertEqual(row["counts_before"]["open"], 15, name)
            self.assertEqual(row["counts_after"]["open"], 16, name)
            self.assertEqual(row["counts_after"]["derived"], 2, name)
        for name in ("run-a-tame", "run-b-zero"):
            with open(os.path.join(OLD_EVIDENCE, f"{name}.json")) as fh:
                rec = json.load(fh)
            s8 = rec["stage8_plane_index_and_terminals"]
            self.assertFalse(s8["plane_index"]["present"], name)
            self.assertEqual(s8["channel_status"], "open", name)
            self.assertEqual(s8["terminal_identity"]["slots_checked"], 0, name)
            self.assertTrue(s8["ok"], name)
            self.assertTrue(rec["ok"], name)

    def test_the_record_still_says_what_it_does_not_show(self):
        for name, rec in self.records().items():
            text = " ".join(rec["what_it_does_not_show"])
            self.assertIn("NOT a privacy acceptance", text, name)
            self.assertIn("125M", text, name)
            self.assertIn("12 of 23", text, name)


# --------------------------------------------- the port, with no bundle
class TestThePortItself(unittest.TestCase):
    """What can be asserted about the port without reading 38 MB."""

    def test_twelve_slots_are_covered_and_eleven_need_a_carried_table(self):
        """Round 2's statement, in round 3's shape.  Every one of the 23
        slots now HAS a port; eleven of them can only be evaluated on a
        bundle that carries its public tables' values, and on a bundle
        without them those eleven are exactly the OPEN set round 2 had,
        each with its reason."""
        self.assertEqual(len(PORTS), 23)
        self.assertEqual(len(COVERED), 23)
        self.assertEqual(len(COVERED_WITHOUT_TABLES), 12)
        self.assertEqual(list(COVERED_WITH_TABLES),
                         [5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 19])
        for s, name, fn, reason in PORTS:
            self.assertIsNotNone(fn, f"slot {s} [{name}] has no port")
            self.assertIn(s, PUBLIC_SPEC, f"slot {s} declares no public-table spec")
            if s in COVERED_WITH_TABLES:
                self.assertTrue(reason, f"slot {s} [{name}] can be open with no reason")
            else:
                self.assertIsNone(reason, f"slot {s} [{name}] needs no carried table")
        # and on THIS bundle -- no carried values -- the covered set is the twelve
        b, _index, _reason, _rp = loaded()
        self.assertFalse(b.public_tables_included)
        self.assertEqual(covered_at(b), COVERED_WITHOUT_TABLES)

    def test_the_lookup_lists_have_the_lengths_the_rung_shape_forces(self):
        """`layout.rs::lookups_at`: the counts move with `ln` / `ls` / `lp`
        and with nothing else."""
        rung = {"norm_wrho": 31, "wrho_s": 17}
        counts = {"ln": 4, "ls": 3, "lp": 2}
        self.assertEqual(len(lookups_at("L", counts, rung)), 2)
        self.assertEqual(len(lookups_at("S", counts, rung)), 15)
        self.assertEqual(len(lookups_at("F", counts, rung)), 9)
        # at a shape whose top limb is exactly full (correction C-6) the four
        # `scaled` norm lookups are dropped
        full = {"norm_wrho": 32, "wrho_s": 17}
        self.assertEqual(
            len(lookups_at("D", counts, full)) + 4,
            len(lookups_at("D", counts, rung)),
        )

    def test_the_sigma_scale_is_the_slack_the_window_leaves(self):
        """Three limbs holding 17 bits leave 7 slack bits, so the pinning
        lookup is `scaled(top, 128)` -- the figure layout.rs:662 names."""
        lks = lookups_at("S", {"ln": 4, "ls": 3, "lp": 2},
                         {"norm_wrho": 31, "wrho_s": 17})
        scaled = {nm: c for terms, _cst in lks for (nm, c) in terms if c not in (1, -1)}
        self.assertEqual(scaled.get("A_SR2"), 128)
        self.assertEqual(scaled.get("A_SG2"), 128)
        self.assertEqual(scaled.get("A_PL1"), 64)

    def test_a_public_table_digest_is_the_captures_own_encoding(self):
        """`Fp2::to_bytes` is c0 then c1, little-endian u64
        (`field.rs:193`), and the capture hashes the concatenation."""
        import hashlib
        want = hashlib.sha256(
            (1).to_bytes(8, "little") + bytes(8)
            + (0).to_bytes(8, "little") + bytes(8)
        ).hexdigest()
        self.assertEqual(table_digest([1, 0]), want)


# ------------------------------------------------------------ the live arm
@unittest.skipUnless(HAVE_NEW, f"the new run-capture bundles are not at {BUNDLES}")
class TestThePlaneIndexLoader(unittest.TestCase):

    def test_the_table_loads_and_tiles_on_both_new_bundles(self):
        for which in (RUN_C, RUN_D):
            b, index, reason, _rp = loaded(which)
            self.assertIsNone(reason, which)
            s = index.summary()
            self.assertTrue(s["ok"], s["findings"])
            self.assertEqual((s["a_planes"], s["h_planes"]), (83, 52))
            self.assertEqual((s["a_data_rows"], s["h_data_rows"]), (377, 470))

    def test_the_domain_logs_are_read_from_the_table_not_ported(self):
        _b, index, _r, _rp = loaded()
        self.assertEqual(
            index.domain_log,
            {"T": 5, "Ht": 8, "L": 10, "D": 12, "Q": 12, "Kv": 10,
             "S": 13, "F": 13, "Tab": 10},
        )

    def test_the_table_is_the_same_in_the_two_independent_bundles(self):
        """It is a function of the public shape, so two DIFFERENT runs carry
        the same table -- the Rust test of the same name, from this side."""
        bc, _i, _r, _rp = loaded(RUN_C)
        bd, _i2, _r2, _rp2 = loaded(RUN_D)
        self.assertEqual(bc.run["plane_index"], bd.run["plane_index"])
        self.assertNotEqual(bc.run["run_binding"], bd.run["run_binding"])

    def test_a_gap_in_the_A_tiling_is_refused(self):
        b, _i, _r, _rp = loaded()
        table = copy.deepcopy(b.run["plane_index"])
        table["a_planes"][5]["rows"] += 1
        keep = b.run["plane_index"]
        b.run["plane_index"] = table
        try:
            bad = PlaneIndex(b)
        finally:
            b.run["plane_index"] = keep
        self.assertTrue(any("gap" in f or "overlap" in f for f in bad.findings),
                        bad.findings[:3])
        self.assertIs(b.run["plane_index"], keep)

    def test_an_H_half_that_does_not_tile_is_refused(self):
        b, _i, _r, _rp = loaded()
        table = copy.deepcopy(b.run["plane_index"])
        table["h_planes"][3]["im_first_row"] += 1
        table["h_planes"][3]["im_offset"] += b.shape.cols
        keep = b.run["plane_index"]
        b.run["plane_index"] = table
        try:
            bad = PlaneIndex(b)
        finally:
            b.run["plane_index"] = keep
        self.assertTrue(bad.findings)
        self.assertFalse(bad.h_tiles)

    def test_an_offset_that_is_not_first_row_times_cols_is_refused(self):
        b, _i, _r, _rp = loaded()
        table = copy.deepcopy(b.run["plane_index"])
        table["a_planes"][9]["offset"] += 1
        keep = b.run["plane_index"]
        b.run["plane_index"] = table
        try:
            bad = PlaneIndex(b)
        finally:
            b.run["plane_index"] = keep
        self.assertTrue(any("is not first_row" in f for f in bad.findings),
                        bad.findings[:3])

    def test_a_slot_naming_a_plane_that_does_not_exist_is_refused(self):
        b, _i, _r, _rp = loaded()
        table = copy.deepcopy(b.run["plane_index"])
        table["slot_planes"][0]["planes"][0]["id"] = 9999
        keep = b.run["plane_index"]
        b.run["plane_index"] = table
        try:
            bad = PlaneIndex(b)
        finally:
            b.run["plane_index"] = keep
        self.assertTrue(any("is not a plane" in f for f in bad.findings),
                        bad.findings[:3])


@unittest.skipUnless(HAVE_OLD, f"the old run-capture bundles are not at {BUNDLES}")
class TestAnOldBundleStillLoads(unittest.TestCase):

    def test_an_old_bundle_loads_and_leaves_the_channel_open(self):
        b = RunBundle(RUN_A)
        index, reason = plane_index_of(b)
        self.assertIsNone(index)
        self.assertEqual(reason, NO_TABLE)
        self.assertIn("predates stage 15", reason)

    def test_the_loader_raises_only_when_asked_for_a_table_that_is_absent(self):
        b = RunBundle(RUN_A)
        with self.assertRaises(PlaneIndexError):
            PlaneIndex(b)

    def test_the_old_bundle_still_passes_every_other_stage(self):
        """A missing table is a missing INPUT, not a broken gate: nothing
        else about an old bundle changes."""
        b = RunBundle(RUN_A)
        rp = RunReplay(b).run()
        self.assertEqual(rp.failures, [])
        s8, index = gate.stage8(b, rp, old=None, do_controls=False)
        self.assertIsNone(index)
        self.assertTrue(s8["ok"])
        self.assertEqual(s8["channel_status"], "open")
        self.assertFalse(s8["plane_index"]["present"])
        self.assertEqual(s8["terminal_identity"]["reason"], NO_TABLE)


@unittest.skipUnless(HAVE_NEW, f"the new run-capture bundles are not at {BUNDLES}")
class TestTheTerminalIdentity(unittest.TestCase):

    def test_the_identity_holds_for_every_covered_slot_of_every_stage(self):
        for which in (RUN_C, RUN_D):
            b, index, _r, rp = loaded(which)
            got = check_terminals(b, index, replay=rp)
            self.assertTrue(got["ok"], got["findings"][:3])
            self.assertEqual(got["slot_checks_equal"], 12 * b.blocks, which)
            self.assertEqual(
                got["slot_checks_matching_the_stored_terminal_polynomial"],
                12 * b.blocks, which,
            )

    def test_the_bundles_source_pins_are_the_ones_the_port_was_read_at(self):
        b, _i, _r, _rp = loaded()
        pins = check_source_pins(b)
        self.assertTrue(pins["ok"], pins)
        self.assertEqual(pins["pins_that_moved"], [])
        self.assertEqual(pins["pins_missing_from_the_bundle"], [])

    def test_a_moved_source_pin_makes_every_slot_not_checked(self):
        b, index, _r, rp = loaded()
        keep = b.manifest["source_pins"]
        moved = copy.deepcopy(keep)
        for p in moved:
            if p["file"].endswith("argument.rs"):
                p["sha256"] = "0" * 64
        b.manifest["source_pins"] = moved
        try:
            got = check_terminals(b, index, replay=rp)
        finally:
            b.manifest["source_pins"] = keep
        self.assertFalse(got["ok"])
        self.assertEqual(got["slot_checks_attempted"], 0)
        self.assertTrue(any("source pins" in f for f in got["findings"]))

    def test_every_rebuilt_public_table_matches_the_captures_own_digest(self):
        """The decisive check of the pad-rule port: the capture carries the
        SHA-256 of the REAL table, and the rebuilt one must equal it."""
        b, index, _r, rp = loaded()
        got = check_terminals(b, index, replay=rp)
        self.assertEqual(got["public_table_digest_failures"], [])
        self.assertEqual(got["public_tables_rebuilt_and_digest_matched"], 11)

    def test_the_pad_indicators_agree_with_the_support_oracle(self):
        """`closed_form_indicator` is an OPTIMISATION of `support_indicator`
        (pad.rs:330): where a closed form exists the two must agree entry for
        entry, and `Dom::L` has none, exactly as the memo says."""
        b, index, _r, _rp = loaded()
        geom = PadGeometry(b.run["shape"], index.domain_log)
        for dom in ("T", "Ht", "D", "Q", "Kv", "S", "F", "Tab"):
            closed = geom.closed_form_indicator(dom)
            self.assertIsNotNone(closed, dom)
            self.assertEqual(closed, geom.support_indicator(dom), dom)
        self.assertIsNone(geom.closed_form_indicator("L"))

    def test_every_domain_pads_at_the_rung_so_every_gate_is_a_real_table(self):
        b, index, _r, _rp = loaded()
        geom = PadGeometry(b.run["shape"], index.domain_log)
        for dom in index.domain_log:
            self.assertTrue(geom.pads(dom), dom)

    def test_the_two_boundary_claim_sites_are_among_the_covered_slots(self):
        """Slots 21 and 22 are the run's two boundary claim sites: in every
        stage but the first / last the IO table is an internal BOUNDARY, and
        the identity is checked there too."""
        self.assertIn(21, COVERED)
        self.assertIn(22, COVERED)
        b, index, _r, rp = loaded()
        got = check_terminals(b, index, replay=rp)
        for row in got["per_stage"]:
            self.assertIn(21, row["equal"], row["stage"])
            self.assertIn(22, row["equal"], row["stage"])
        kinds = set()
        for st in b.stages:
            for role in st.roles:
                if role["role"] in ("Input", "Output"):
                    kinds.add(role["commitment_kind"])
        self.assertEqual(kinds, {"external-endpoint", "internal-boundary"})


@unittest.skipUnless(HAVE_NEW and HAVE_OLD,
                     f"the four run-capture bundles are not at {BUNDLES}")
class TestTheControls(unittest.TestCase):

    def controls(self):
        if "ctl" not in _STATE:
            b, index, _r, rp = loaded(RUN_C)
            _STATE["ctl"] = terminal_controls(
                b, index, replay=rp, old_bundle=RunBundle(RUN_A)
            )
        return _STATE["ctl"]

    def test_all_five_fire_on_a_bundle_that_passes_honest(self):
        ctl = self.controls()
        self.assertTrue(ctl["honest"]["ok"])
        self.assertTrue(ctl["ok"], ctl["controls_that_did_not_fire"])

    def test_a_perturbed_terminal_fails_at_exactly_that_slot(self):
        c = next(x for x in self.controls()["controls"] if x["control"] == "CT-1")
        self.assertEqual(c["slots_that_failed"], [[1, 17]])
        self.assertEqual(c["slot_checks_equal"], c["of"] - 1)
        self.assertTrue(c["the_transcript_replay_refuses_the_same_bundle"])
        self.assertTrue(c["restored"])

    def test_a_swapped_plane_pair_is_caught_three_ways(self):
        c = next(x for x in self.controls()["controls"] if x["control"] == "CT-2")
        self.assertTrue(c["the_port_refuses_the_push_order"])
        self.assertTrue(c["the_identity_fails_at_the_swapped_slot_in_every_stage"])
        self.assertTrue(c["the_plane_index_loader_refuses"])
        self.assertTrue(c["bundle_table_restored"])

    def test_a_replane_of_the_same_size_is_caught_by_the_slice_offset(self):
        c = next(x for x in self.controls()["controls"] if x["control"] == "CT-3")
        self.assertTrue(c["the_two_planes_really_are_the_same_size"])
        self.assertIn("slice offset", c["loader_slice_offset_refusal"])
        self.assertTrue(
            c["id_only_form_is_caught_by_the_name_against_id_cross_check"])

    def test_an_old_bundle_is_open_and_not_passed(self):
        c = next(x for x in self.controls()["controls"] if x["control"] == "CT-4")
        self.assertFalse(c["table_present"])
        self.assertTrue(c["no_slot_is_reported_checked"])
        self.assertTrue(c["reason_is_the_one_the_gate_had_before"])

    def test_a_flipped_public_table_entry_is_caught_by_the_digest(self):
        c = next(x for x in self.controls()["controls"] if x["control"] == "CT-5")
        self.assertTrue(c["the_honest_table_matches_the_capture"])
        self.assertTrue(c["the_flipped_table_does_not"])

    def test_the_controls_restore_the_bundle_they_touched(self):
        self.controls()
        b, index, _r, rp = loaded(RUN_C)
        again = check_terminals(b, index, replay=rp)
        self.assertTrue(again["ok"], again["findings"][:3])
        self.assertEqual(again["slot_checks_equal"], 36)


@unittest.skipUnless(HAVE_NEW, f"the new run-capture bundles are not at {BUNDLES}")
class TestOneMoreIndependentPerturbation(unittest.TestCase):
    """A control the gate does not run: a terminal of a slot the gate does
    NOT cover must leave every covered slot's identity alone -- the port must
    not silently claim a slot it never evaluated."""

    def test_perturbing_an_uncovered_slot_changes_nothing_the_gate_reports(self):
        b, index, _r, rp = loaded()
        docs = [st.doc for st in b.stages]
        doc = dict(docs[0])
        args = list(doc["arguments"])
        arg = dict(args[15])                      # SC_QZC, an OPEN slot
        terms = list(arg["terminals"])
        old = f2_from_list(terms[0])
        new = f2_add(old, F2_ONE)
        terms[0] = [new[0], new[1]]
        arg["terminals"] = terms
        args[15] = arg
        doc["arguments"] = args
        docs = list(docs)
        docs[0] = doc
        got = check_terminals(b, index, replay=rp, stage_docs=docs)
        self.assertTrue(got["ok"], got["findings"][:3])
        self.assertEqual(got["slot_checks_equal"], 36)
        self.assertNotIn(15, [s for row in got["per_stage"] for s in row["checked"]])


if __name__ == "__main__":
    unittest.main()
