#!/usr/bin/env python3
"""[v25 staging, 2026-11-02, D60 / review F3] Tests of the D55 gate's R13 port
(`zk60_native_rg_d55r13`), the run-level joint rank at D55
(`zk60_native_rg_d55joint`) and the joined-claim derivation
(`zk60_native_rg_d55.io_claims_from_terminals`).  The port tests run
anywhere; the bundle tests need a REGISTERED R13 D55 bundle written by
`run_fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles`
(`ZK60_D55_R13_BUNDLE`, and `ZK60_D55_R13_OTHER` for its pair) and skip
without it.  NOTHING HERE IS A PRIVACY STATEMENT."""

import copy
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))

import zk60_native_rg_d55r13 as X  # noqa: E402

BUNDLE = os.environ.get("ZK60_D55_R13_BUNDLE", "")
OTHER = os.environ.get("ZK60_D55_R13_OTHER", "")


def _blake3_present():
    try:
        import blake3  # noqa: F401
        return True
    except ImportError:
        return False


class D55R13Port(unittest.TestCase):
    def test_the_registry_is_the_marker_and_its_base(self):
        self.assertEqual(len(X.R13_RUN_PROFILES), 12)
        self.assertEqual(len(X.D55_RUN_PROFILES), 12)
        for d55, base in X.D55_RUN_PROFILES.items():
            self.assertTrue(d55.startswith("hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-"))
            self.assertEqual(d55, "hashline-zk-mr1/" + X.D55_REGISTERED_MARKER + base[len("hashline-zk-mr1/"):])
            self.assertIn(X.R13_RUN_PROFILES[base], X.R.ACCURACY_PROFILES)
        self.assertEqual(len(X.D55_REGISTERED_MARKER), 50)       # run.rs: the 50-byte marker
        self.assertEqual(X.base_of("hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1"),
                         "hashline-zk-mr1/private-run-rung-lh-t32-dev/1")
        self.assertIsNone(X.base_of("d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/hashline-zk-mr1/private-run-rung-lh-t32-dev/1"))

    def test_the_registered_schedule_lines(self):
        run = {"blocks": 3, "parameter_line": "P", "layout_description": ["a", "b"], "stage_lines": ["s0", "s1", "s2"],
               "schedule_digest": [0] * 32}
        lines = X.registered_schedule_lines(run)
        self.assertEqual(len(lines), 1 + 2 + 1 + 3 + 1)
        self.assertTrue(lines[3].startswith("phase 1 (commit): the 2 internal boundaries (boundary k after block k)"))
        self.assertEqual(lines[5], "fork 01 of 3: S0, then pb-run-fork 1 and pb-run-fork-block; the stage body and IO geometry of "
                                   "D12a's [s1]; its IO claims are opened in phase 3, not in the fork")
        self.assertTrue(lines[-1].endswith("then the external output endpoint (block 2's slot 22)"))
        if _blake3_present():
            self.assertFalse(X.registered_schedule_digest(run)["equal"])

    def test_the_joint_module_imports_v24s_rank_functions_unchanged(self):
        import zk60_native_rg_d55joint as J
        import zk60_native_rg_joint as RJ
        self.assertIs(J.boundary_reserved_figure, RJ.boundary_reserved_figure)
        self.assertIs(J.three_role_figure, RJ.three_role_figure)
        self.assertIs(J.RunJointSystem, RJ.RunJointSystem)


@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE) and _blake3_present(),
                     "set ZK60_D55_R13_BUNDLE to a registered R13 D55 capture (and install blake3)")
class D55R13Bundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import zk60_native_rg_d55 as D
        cls.D = D
        cls.b = D.D55Bundle(BUNDLE)
        cls.facts = D.d55_facts(cls.b)
        cls.rp = D.D55Replay(cls.b).run()

    def test_integrity_facts_replay_and_the_registered_header(self):
        i = self.D.d55_integrity(self.b)
        self.assertTrue(i["ok"], i["findings"])
        self.assertEqual(self.facts["family"], "R13")
        self.assertTrue(self.facts["run_profile_is_registered"])
        self.assertTrue(self.facts["d55_schedule_digest"]["equal"])
        s = self.rp.summary()
        self.assertTrue(s["ok"], s["failures"][:3])
        h = X.registered_header(self.b, self.facts, self.rp.run_binding_ok)
        self.assertTrue(h["parameter_line_recomputed"], h["findings"])
        self.assertTrue(h["ok"], h)
        self.assertTrue(all(v["fires"] for v in h["controls"].values() if isinstance(v, dict)))

    def test_a_test_only_or_dd_identity_is_refused_by_name(self):
        b = copy.copy(self.b)
        b.profile = self.D.D55_PREFIX + self.facts["d55_base_run_profile"]
        with self.assertRaises(ValueError):
            X.r13_facts(b)
        b = copy.copy(self.b)
        b.run = copy.deepcopy(self.b.run)
        b.run["shape"]["dd_cap"] = 4
        with self.assertRaises(ValueError):
            X.r13_facts(b)
        b = copy.copy(self.b)
        b.run = dict(self.b.run, parameter_line=self.b.run["parameter_line"].replace(X.REG_LINE_TAIL, self.D.D55_LINE_TAIL))
        with self.assertRaises(ValueError):
            X.r13_facts(b)

    def test_the_layout_and_one_forks_terminals(self):
        self.assertTrue(X.r13_layout(self.b)["ok"])
        t = X.r13_terminals(self.b, self.rp, self.facts, controls=False, forks=[0])
        p = t["per_fork"][0]
        self.assertTrue(p["ok"], p)
        self.assertEqual(p["slot_checks_equal"], 23)
        self.assertEqual(len(p["gate_values_closing_sc_fzc"]), 1)
        self.assertEqual(t["forks_not_evaluated"], list(range(1, self.b.blocks)))
        self.assertFalse(t["ok"])                      # a bounded run is never a pass
        self.assertTrue(t["argument_rs_reading"]["removed_after"])

    def test_the_joined_claims_and_their_control(self):
        io = self.D.io_claims_from_terminals(self.b)
        self.assertTrue(io["ok"], io["findings"])
        self.assertEqual(io["claims_derived"], 2 * self.b.blocks)
        self.assertFalse(self.D.io_claims_from_terminals(self.b, doctor=(0, 22))["ok"])

    def test_the_run_level_joint_rank_and_its_controls(self):
        import zk60_native_rg_d55joint as J
        s3, views = self.D.d55_stage3(self.b, self.rp, do_controls=False, return_views=True)
        self.assertTrue(s3["ok"])
        other = self.D.D55Bundle(OTHER) if OTHER and os.path.isdir(OTHER) else None
        j = J.d55_joint(self.b, views, do_controls=True, other=other, rp=self.rp)
        self.assertTrue(j["ok"], {k: v for k, v in j.items() if k in ("shared_planes",)})
        for p in j["per_boundary"]:
            self.assertEqual(p["restricted_to_the_reserved_rows"]["disclosed_on_the_reserved_block_fp"], 0)
            self.assertEqual(p["three_roles_of_the_plane"]["joint_fp"], 0)
        c3 = j["controls"]["J-C3 a blinding row shared between A_0 and B_0"]
        self.assertTrue(c3["fires"] and c3["perturbed"]["joint_fp"] > 0 and c3["marginals_unchanged"])
        self.assertTrue(j["controls"]["ok"])


if __name__ == "__main__":
    unittest.main()
