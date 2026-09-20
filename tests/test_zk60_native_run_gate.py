"""Tests for the RUN gate (scripts/zk60_native_run_gate.py).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_run_gate.py"

TWO ARMS, deliberately.

* The RECORDED arm always runs.  The gate's own evidence under
  `results/zk60_native_run_gate/` is tracked, so a green suite always
  asserts the figures the report quotes -- the disclosed dimensions, the
  boundary's reserved-row rank, every control's honest and perturbed
  numbers, the channel counts -- and asserts that the evidence was produced
  by the tools now in the tree (`tool_sha256`).  A tool edited without
  re-running the gate turns the suite red.
* The LIVE arm needs the run-capture bundles, which are ~38 MB each and live
  on the Rust lane's worktree, not in this repository.  It is skipped when
  they are absent, and the recorded arm above is what keeps a skip from
  hiding the gate.  `ZK60_RUN_BUNDLES` overrides the directory.
"""

from __future__ import annotations

import copy
import itertools
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_A = os.path.join(BUNDLES, "run-a-tame")
RUN_B = os.path.join(BUNDLES, "run-b-zero")
HAVE_BUNDLES = os.path.isdir(RUN_A) and os.path.isdir(RUN_B)
TOY_CAPTURES = os.path.join(ROOT, "results", "zk60_native_captures_20260919")

from zk60_native_jv_field import P, det_mod_p  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_bundle import RunBundle, integrity  # noqa: E402
from zk60_native_rg_controls import controls  # noqa: E402
from zk60_native_rg_joint import (  # noqa: E402
    boundary_reserved_figure,
    discover_shared_planes,
    run_wide_figure,
    three_role_figure,
)
from zk60_native_rg_pcs import RunRoleView  # noqa: E402
from zk60_native_rg_preimage import preimages  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402

_STATE = {}


def loaded(which=RUN_A):
    """The bundle, its replay and every commitment's view, built once."""
    if which not in _STATE:
        b = RunBundle(which)
        rp = RunReplay(b).run()
        views = {}
        for st in b.stages:
            for role in st.roles:
                key = st.key(role["role"])
                v = RunRoleView(
                    st, role, rp.stages[st.index]["role_prox_rhos"][key],
                    b.shape, name=key,
                )
                v.run(rp.stages[st.index]["role_lambdas"][key])
                views[key] = v
        _STATE[which] = (b, rp, views, discover_shared_planes(b))
    return _STATE[which]


def leibniz_det(mat):
    """An INDEPENDENT determinant: the permutation expansion, over Fp.

    Deliberately not Gaussian elimination, so that the gate's own
    `det_mod_p` is cross-checked by a different algorithm on the small
    minors the evidence names.
    """
    n = len(mat)
    total = 0
    for perm in itertools.permutations(range(n)):
        sign = 1
        seen = list(perm)
        for i in range(n):
            for j in range(i + 1, n):
                if seen[i] > seen[j]:
                    sign = -sign
        term = sign
        for i in range(n):
            term = term * mat[i][perm[i]] % P
        total = (total + term) % P
    return total % P


# ------------------------------------------------------- the recorded arm
class TestRecordedEvidence(unittest.TestCase):
    """What the report quotes, asserted from the tracked evidence."""

    def records(self):
        out = {}
        for name in ("run-a-tame", "run-b-zero"):
            path = os.path.join(EVIDENCE, f"{name}.json")
            self.assertTrue(os.path.exists(path), f"{path} is missing")
            with open(path) as fh:
                out[name] = json.load(fh)
        return out

    def test_both_bundles_have_a_green_record_that_claims_no_privacy_property(self):
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
                f"{name}: the record was produced by different tool bytes; re-run the "
                "gate and refresh the evidence",
            )

    def test_the_recorded_disclosed_dimensions(self):
        for name, rec in self.records().items():
            for r in rec["stage3_per_commitment"]["per_commitment"]:
                self.assertEqual(
                    r["disclosed_dimension"], r["expected_disclosed_dimension"],
                    f"{name} {r['role']}",
                )
                self.assertTrue(r["certifying_minor"]["determinant_nonzero"])
                self.assertLessEqual(r["distinct_columns"], r["pad_count"])
                self.assertEqual(r["column_identity_failures"], 0)
                self.assertEqual(r["group_claim_identity_failures"], 0)
            for m in rec["stage3_per_commitment"]["masking_commitments"]:
                self.assertEqual(m["disclosed_dimension"], 0)

    def test_the_recorded_boundary_figures(self):
        for name, rec in self.records().items():
            per = rec["stage4_the_boundary"]["per_boundary"]
            self.assertEqual(len(per), 2)
            for b in per:
                rr = b["restricted_to_the_reserved_rows"]
                self.assertEqual(rr["generators"], 6)
                self.assertEqual(rr["rank_on_the_reserved_block"], 6)
                self.assertEqual(rr["disclosed_on_the_reserved_block_fp"], 0)
                th = b["three_roles_of_the_plane"]
                self.assertEqual(len(th["roles"]), 3)
                self.assertEqual(th["joint_fp"], th["sum_of_parts_fp"])
                self.assertTrue(th["non_data_block_is_block_diagonal_by_role"])
            whole = rec["stage4_the_boundary"]["whole_run"]
            self.assertEqual(whole["joint_fp"], whole["sum_of_parts_fp"])
            self.assertEqual(whole["joint_fp"], 6, f"{name}: three H identities")

    def test_the_recorded_controls_all_fire_and_give_the_checkers_numbers(self):
        for name, rec in self.records().items():
            c = rec["stage6_negative_controls"]
            self.assertTrue(c["all_fire"], f"{name}: a control did not fire")
            c1 = c["C1_two_claims_share_one_reserved_pair"]
            self.assertEqual(c1["honest"]["disclosed_fp"], 0)
            self.assertEqual(c1["perturbed"]["rank"], 4)
            self.assertEqual(c1["perturbed"]["disclosed_fp"], 2)
            self.assertTrue(c1["per_claim_figures_unchanged"])
            c2 = c["C2_a_single_proximity_row"]
            self.assertEqual(c2["perturbed"]["rank"], 5)
            self.assertEqual(c2["perturbed"]["disclosed_fp"], 1)
            c3 = c["C3_a_blinding_row_shared_with_an_adjacent_activation_commitment"]
            self.assertTrue(c3["marginals_unchanged"])
            self.assertTrue(c3["joint_greater_than_sum"])

    def test_every_recorded_channel_carries_a_usable_status(self):
        for name, rec in self.records().items():
            ch = rec["stage7_channels"]
            self.assertEqual(ch["grading_failures"], [])
            self.assertGreaterEqual(ch["counts"].get("constructed", 0), 1)
            self.assertGreaterEqual(ch["counts"].get("open", 0), 10)
            self.assertGreaterEqual(len(ch["new_for_a_run"]), 3)
            for c in ch["channels"]:
                self.assertIn(c["status"], ("constructed", "derived", "argued", "open"))
                if c["status"] == "open":
                    self.assertTrue(c.get("reason"))
                if c["status"] == "argued":
                    self.assertTrue(c.get("assumption"))
                if c["status"] == "constructed":
                    self.assertTrue(c.get("preimage_exhibited"))

    def test_the_record_says_what_it_does_not_show(self):
        for name, rec in self.records().items():
            joined = " ".join(rec["what_it_does_not_show"]).lower()
            for phrase in ("125m", "hash layer", "not a privacy acceptance"):
                self.assertIn(phrase, joined, f"{name}: {phrase}")


# ----------------------------------------------------------- the live arm
@unittest.skipUnless(HAVE_BUNDLES, f"the run-capture bundles are not at {BUNDLES}")
class TestLoaderAndIntegrity(unittest.TestCase):
    def test_both_bundles_pass_the_integrity_pass(self):
        for d in (RUN_A, RUN_B):
            r = integrity(RunBundle(d))
            self.assertEqual(r["findings"], [])
            self.assertTrue(r["ok"])
            self.assertEqual(r["blocks"], 3)
            self.assertEqual(r["boundaries"], 2)
            self.assertFalse(r["any_root_opened_twice"])

    def test_a_toy_schema_3_capture_is_refused_by_name(self):
        with self.assertRaises(ValueError) as cm:
            RunBundle(TOY_CAPTURES)
        self.assertIn("run.json", str(cm.exception))

    def test_a_manifest_hash_that_does_not_match_the_bytes_is_refused(self):
        b = RunBundle(RUN_A)
        saved = b.manifest["files"][1]["sha256"]
        b.manifest["files"][1]["sha256"] = "0" * 64
        try:
            r = integrity(b)
        finally:
            b.manifest["files"][1]["sha256"] = saved
        self.assertFalse(r["ok"])
        self.assertTrue(any("sha256 on disk" in f for f in r["findings"]))

    def test_a_boundary_with_one_proximity_row_is_refused_by_the_row_rule(self):
        b = RunBundle(RUN_A)
        bd = b.run["internal_boundaries"][0]
        saved = bd["rows"]
        bd["rows"] = saved - 1
        try:
            r = integrity(b)
        finally:
            bd["rows"] = saved
        self.assertFalse(r["ok"])
        self.assertTrue(any("derived count" in f for f in r["findings"]))

    def test_the_shape_is_data_and_not_a_ported_constant(self):
        b = RunBundle(RUN_A)
        self.assertEqual(b.shape.cols, 1 << b.shape.log_cols)
        self.assertEqual(b.shape.enc_cols, b.shape.cols * b.shape.inv_rate)
        import zk60_native_jv_capture as toy

        self.assertNotEqual(b.shape.log_cols, toy.LOG_COLS)
        self.assertNotEqual(b.shape.cols, toy.N_COLS)


@unittest.skipUnless(HAVE_BUNDLES, f"the run-capture bundles are not at {BUNDLES}")
class TestReplay(unittest.TestCase):
    def test_the_whole_run_transcript_is_re_derived(self):
        for d in (RUN_A, RUN_B):
            _, rp, _, _ = loaded(d)
            s = rp.summary()
            self.assertEqual(s["failures"], [])
            self.assertTrue(s["run_binding_reproduced"])
            self.assertEqual(s["not_rederived"], [])
            self.assertGreater(s["challenges_checked"], 6000)
            self.assertTrue(all(t["start_tag_ok"] and t["end_tag_ok"]
                                for t in s["segment_position_tags"]))

    def test_one_altered_field_breaks_the_replay(self):
        b = RunBundle(RUN_A)
        arg = b.stages[1].doc["arguments"][0]
        saved = arg["rounds"][0][0][0]
        arg["rounds"][0][0][0] = (saved + 1) % P
        try:
            s = RunReplay(b).run().summary()
        finally:
            arg["rounds"][0][0][0] = saved
        self.assertFalse(s["ok"])
        self.assertTrue(s["failures"])


@unittest.skipUnless(HAVE_BUNDLES, f"the run-capture bundles are not at {BUNDLES}")
class TestPerCommitment(unittest.TestCase):
    def test_the_disclosed_dimensions_at_the_run_shape(self):
        b, _, views, _ = loaded()
        for key, v in views.items():
            f = v.facts
            self.assertEqual(f["findings"], [])
            self.assertTrue(all(f["reduction_hypotheses"].values()), key)
            want = 2 if key.startswith("H@") else 0
            self.assertEqual(f["disclosed_dimension"], want, key)
            self.assertEqual(f["k0"], 0, key)
            self.assertLessEqual(f["distinct_columns"], f["pad_count"], key)

    def test_the_certifying_minor_rebuilds_from_the_emitted_indices_alone(self):
        b, _, views, _ = loaded()
        for key in ("B0", "B1", "E-Input", "E-Output"):
            v = views[key]
            m = v.facts["certifying_minor"]
            self.assertTrue(m["full_row_rank"], key)
            got = v.rebuild_minor(m["generator_indices"], m["non_data_row_indices"])
            self.assertEqual(got["determinant"], m["determinant"], key)
            self.assertNotEqual(got["determinant"], 0, key)
            # an INDEPENDENT algorithm on the same submatrix
            self.assertEqual(leibniz_det(got["submatrix"]), m["determinant"], key)

    def test_the_msg_and_pad_halves_have_different_lengths_here(self):
        b, _, views, _ = loaded()
        v = views["B0"]
        self.assertEqual(v.sp.n_cols, 1024)
        self.assertEqual(v.pad_len, 256)
        self.assertEqual(v.facts["column_identity_failures"], 0)
        self.assertGreater(v.facts["column_identity_checked"], 0)


@unittest.skipUnless(HAVE_BUNDLES, f"the run-capture bundles are not at {BUNDLES}")
class TestTheBoundary(unittest.TestCase):
    def test_the_reserved_row_figure_is_six_of_six_and_discloses_nothing(self):
        b, _, views, _ = loaded()
        for k in range(b.boundaries):
            f = boundary_reserved_figure(b, views[f"B{k}"], k)
            self.assertEqual(f["generators"], 6)
            self.assertEqual(f["rank_on_the_reserved_block"], 6)
            self.assertEqual(f["disclosed_on_the_reserved_block_fp"], 0)
            self.assertEqual(len(f["reserved_columns"]), 6)
            self.assertTrue(f["determinant_nonzero"])
            # the same 6 x 6 minor, by the permutation expansion
            bd = b.boundary(k)
            cols = list(bd["site_rows"]) + [bd["prox_row"], bd["prox_row"] + 1]
            gens = views[f"B{k}"]._p1_rows()
            sub = [[gens[r][c] for c in cols] for r in range(6)]
            self.assertEqual(leibniz_det(sub), det_mod_p(sub))
            self.assertNotEqual(leibniz_det(sub), 0)

    def test_a_shared_pair_gives_disclosed_two_and_a_single_prox_row_gives_one(self):
        b, _, views, _ = loaded()
        merged = boundary_reserved_figure(b, views["B0"], 0, merge_pairs=True)
        self.assertEqual(merged["rank_on_the_reserved_block"], 4)
        self.assertEqual(merged["disclosed_on_the_reserved_block_fp"], 2)
        single = boundary_reserved_figure(b, views["B0"], 0, drop_prox_row=True)
        self.assertEqual(single["rank_on_the_reserved_block"], 5)
        self.assertEqual(single["disclosed_on_the_reserved_block_fp"], 1)
        # over ALL rows every case looks the same: the restriction is the point
        self.assertEqual(merged["rank_over_all_rows"], single["rank_over_all_rows"])

    def test_the_three_roles_are_identified_from_claim_sources(self):
        b, _, views, shared = loaded()
        self.assertEqual(shared["findings"], [])
        for k in range(b.boundaries):
            t = three_role_figure(b, views, shared, k)
            self.assertEqual(t["roles"], [f"A@{k}", f"B{k}", f"A@{k+1}"])
            self.assertEqual(t["identified_rows"], 8)
            self.assertEqual(len(t["equality_slots"]), 2)
            self.assertEqual(
                sorted(s["slot"] for s in t["equality_slots"]), [21, 22]
            )
            self.assertEqual(t["joint_fp"], t["sum_of_parts_fp"])
            self.assertTrue(t["non_data_block_is_block_diagonal_by_role"])

    def test_a_shared_blinding_row_raises_the_joint_above_the_sum(self):
        b, _, views, shared = loaded()
        a_row = b.stages[0].role("A")["site_rows"][0]
        t = three_role_figure(
            b, views, shared, 0,
            extra_identifications=[(("A@0", a_row), ("B0", b.boundary(0)["site_rows"][0]))],
        )
        self.assertEqual(t["sum_of_parts_fp"], 0)
        self.assertEqual(t["joint_fp"], b.shape.cols)
        self.assertFalse(t["ok"])

    def test_the_whole_run_is_one_system_and_the_joint_equals_the_sum(self):
        b, _, views, shared = loaded()
        w = run_wide_figure(b, views, shared)
        self.assertEqual(len(w["commitments"]), 13)
        self.assertEqual(w["joint_fp"], w["sum_of_parts_fp"])
        self.assertEqual(w["identified_rows"], 24)
        self.assertGreater(w["coordinate_classes"], 3000)


@unittest.skipUnless(HAVE_BUNDLES, f"the run-capture bundles are not at {BUNDLES}")
class TestPreimageAndControls(unittest.TestCase):
    def test_the_zero_data_message_preimage_is_exhibited_and_verified(self):
        b, _, views, _ = loaded()
        p = preimages(b, views, ["B0", "B1", "E-Input", "E-Output"])
        self.assertTrue(p["ok"])
        for e in p["per_commitment"]:
            self.assertTrue(e["preimage_exhibited"], e["commitment"])
            self.assertEqual(e["positions_without_a_solution"], 0)
            self.assertEqual(e["verification"]["message_entries_differing"], 0)
            self.assertEqual(e["verification"]["claim_values_differing"], 0)
            self.assertTrue(e["full_row_rank"])

    def test_a_commitment_with_multi_member_groups_is_skipped_not_faked(self):
        b, _, views, _ = loaded()
        p = preimages(b, views, ["A@0"])
        self.assertEqual(p["skipped"], ["A@0"])
        self.assertFalse(p["per_commitment"][0]["preimage_exhibited"])

    def test_every_control_fires_on_a_bundle_that_passes_honest(self):
        b, rp, views, shared = loaded()
        other = RunBundle(RUN_B)
        c = controls(b, other, views, rp, shared)
        for n in c["controls"]:
            self.assertTrue(c[n]["fires"], f"{n} did not fire")
        self.assertTrue(c["C1_two_claims_share_one_reserved_pair"][
            "reproduces_the_checkers_disclosed_2"])
        self.assertTrue(c["C2_a_single_proximity_row"][
            "reproduces_the_checkers_disclosed_1"])
        self.assertTrue(c["all_fire"])

    def test_the_controls_restore_everything_they_touched(self):
        b, rp, views, shared = loaded()
        before = json.dumps(b.run["internal_boundaries"], sort_keys=True)
        srcs = copy.deepcopy(b.stages[1].boundary_opening()["claim_sources"])
        controls(b, RunBundle(RUN_B), views, rp, shared)
        self.assertEqual(json.dumps(b.run["internal_boundaries"], sort_keys=True), before)
        self.assertEqual(b.stages[1].boundary_opening()["claim_sources"], srcs)
        self.assertEqual([s.index for s in b.stages], [0, 1, 2])
        self.assertTrue(integrity(b)["ok"])


if __name__ == "__main__":
    unittest.main()
