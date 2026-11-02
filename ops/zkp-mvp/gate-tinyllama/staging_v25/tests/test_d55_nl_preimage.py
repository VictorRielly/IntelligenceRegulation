#!/usr/bin/env python3
"""[v25 staging, 2026-11-02, NL-1 / PRE lane] Tests of NL-1 S1-S5 on the R13 slots
of every fork of a registered R13 D55 run (`zk60_native_rg_d55nl`) and of the
full zero-data preimage at D55 (`zk60_native_rg_d55preimage`), and of their one
delimited block in the D55 driver.  The port tests run anywhere in this
repository; the bundle tests need a REGISTERED R13 D55 bundle written by
`run_fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles`
(`ZK60_D55_R13_BUNDLE`) and skip without it.  The bundle tests run NL-1 on every
fork of the rung (~25 s) and the preimage on the TAIL's commitments only (the
forks' A / H solve is minutes; the record runs it).  NOTHING HERE IS A PRIVACY
STATEMENT."""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(os.path.dirname(HERE), "scripts")
sys.path.insert(0, SCRIPTS)

import zk60_native_rg_d55nl as NLX  # noqa: E402
import zk60_native_rg_d55preimage as PRX  # noqa: E402

BUNDLE = os.environ.get("ZK60_D55_R13_BUNDLE", "")


def _blake3_present():
    try:
        import blake3  # noqa: F401
        return True
    except ImportError:
        return False


class D55NlPrePort(unittest.TestCase):
    def test_the_frozen_nl_check_is_the_pinned_one(self):
        import zk60_native_rg_tokennl as TN
        NL, NF, d = NLX.load_nl()
        self.assertTrue(d.endswith(os.path.join("results", "zk60_nonlinear_channel_shaped")))
        self.assertEqual({n: NLX._sha(os.path.join(d, n)) for n in TN.NL_PINS}, TN.NL_PINS)
        self.assertEqual(os.path.realpath(NL.__file__), os.path.realpath(os.path.join(d, "nl_check.py")))
        self.assertEqual((NL.MASK_Q, NL.MASK_MSG), (256, 512))

    def test_the_seven_slots_are_round_22s(self):
        self.assertEqual(NLX.SLOTS7, (3, 14, 15, 16, 17, 18, 19))

    def test_the_poly_ops_are_scoped_and_numeric_paths_unchanged(self):
        from zk60_native_jv_field import f2_add, f2_mul, f2_mul_base, f2_sub
        T, R = NLX.T, NLX.R
        before = (T.add, T.sub, T.mul, T.mulb, R.add, R.sub, R.mul, R.mulb)
        a, b = (5, 7), (11, 3)
        with NLX.poly_ops() as po:
            self.assertIs(T.add, NLX.padd)
            self.assertIs(R.mulb, NLX.pmulb)
            self.assertEqual(T.add(a, b), f2_add(a, b))
            self.assertEqual(T.sub(a, b), f2_sub(a, b))
            self.assertEqual(R.mul(a, b), f2_mul(a, b))
            self.assertEqual(R.mulb(a, 9), f2_mul_base(a, 9))
            x = NLX.Poly.var("x")
            self.assertIsInstance(T.mul(x, a), NLX.Poly)
        self.assertTrue(po.restored)
        self.assertEqual(before, (T.add, T.sub, T.mul, T.mulb, R.add, R.sub, R.mul, R.mulb))

    def test_the_preimage_imports_the_d12a_functions_unchanged(self):
        import zk60_native_rg_ahcontrols as AC
        import zk60_native_rg_ahpreimage as AP
        self.assertIs(PRX.full_preimages, AP.full_preimages)
        self.assertIs(PRX.preimage_for_view, AP.preimage_for_view)
        self.assertIs(PRX.WideRolePreimage, AP.WideRolePreimage)
        self.assertIs(PRX.ah_controls, AC.ah_controls)
        self.assertIs(PRX.p1_opened_column_entry, AC.p1_opened_column_entry)

    def test_the_driver_carries_one_delimited_block_naming_both_parts(self):
        with open(os.path.join(SCRIPTS, "zk60_native_rg_d55.py")) as fh:
            src = fh.read()
        begin, end = "# --- [NL-1 / PRE lane, 2026-11-02] begin", "# --- [NL-1 / PRE lane, 2026-11-02] end"
        self.assertEqual(src.count(begin), 1)
        self.assertEqual(src.count(end), 1)
        block = src[src.index(begin): src.index(end)]
        for needle in ("NLX.PART", "PRX.PART", "NLX.NOT_HERE_CLOSED", "PRX.NOT_HERE_CLOSED", 'family == "R13"'):
            self.assertIn(needle, block)
        self.assertTrue(NLX.PART.startswith("NL-1") and PRX.PART.startswith("PRE"))
        # the two not_here strings the block removes are the ones the driver writes for the R13 family
        self.assertIn(f'"{NLX.NOT_HERE_CLOSED}"', src)
        self.assertIn(f'"{PRX.NOT_HERE_CLOSED}"', src)


@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE) and _blake3_present(),
                     "set ZK60_D55_R13_BUNDLE to a registered R13 D55 capture (and install blake3)")
class D55NlPreBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import zk60_native_rg_d55 as D
        import zk60_native_rg_d55r13 as X
        cls.D, cls.X = D, X
        cls.b = D.D55Bundle(BUNDLE)
        cls.facts = D.d55_facts(cls.b)
        cls.rp = D.D55Replay(cls.b).run()
        cls.t3 = X.r13_terminals(cls.b, cls.rp, cls.facts, controls=False)
        cls.gates = NLX.gates_from_r13_3(cls.t3)

    def test_nl1_on_every_fork_and_its_controls(self):
        r = NLX.d55_nl1(self.b, self.rp, self.facts, self.gates, controls=True)
        n = 7 * self.b.blocks
        self.assertTrue(r["ok"], r["summary"])
        self.assertEqual(r["slot_instances"], n)
        self.assertEqual(r["forks_evaluated"], list(range(self.b.blocks)))
        self.assertTrue(r["T0_E0_all"])
        self.assertTrue(all(x["T0_control_one_terminal_plus_1_fires"] for x in r["T0_E0"]))
        for key, pm in r["per_challenge_mode"].items():
            self.assertTrue(NLX.mode_ok(pm, n), key)
        self.assertEqual(r["S3_fact21"]["tight"], r["S3_fact21"]["checks"])
        self.assertTrue(r["all_23_slots_S3_and_budget"]["ok"])
        self.assertTrue(r["S5_controls"]["ok"])
        ctl = r["D55_controls"]
        self.assertTrue(ctl["ok"])
        self.assertEqual(ctl["NL-TAB-GC a doctored group-column entry"]["failing"], [18])
        self.assertEqual(ctl["NL-TAB-ACT a doctored ACT3 table entry"]["failing"], [19])
        self.assertEqual(ctl["NL-G the gate denominator moved"]["failing"], [18])
        self.assertTrue(r["poly_ops_restored_after"] and r["argument_rs_reading"]["removed_after"])

    def test_nl1_refuses_a_fork_without_its_gate_denominator(self):
        gates = dict(self.gates)
        gates[self.b.blocks - 1] = None
        r = NLX.d55_nl1(self.b, self.rp, self.facts, gates, controls=False)
        self.assertFalse(r["ok"])
        self.assertEqual(r["forks_not_evaluated"], [self.b.blocks - 1])

    def test_the_tail_preimage_and_the_d55_controls(self):
        s3, views = self.D.d55_stage3(self.b, self.rp, do_controls=False, return_views=True)
        self.assertTrue(s3["ok"])
        order = PRX.commitment_order(self.b, views)
        self.assertEqual(order[:2], ["A@0", "H@0"])
        self.assertEqual(len(order), 2 * self.b.blocks + self.b.boundaries + 2)
        self.assertEqual(set(order), set(views))
        tail = [self.b.tail.key_at(i) for i in range(len(self.b.tail.roles))]
        rec = PRX.full_preimages(self.b, views, names=tail)
        self.assertTrue(rec["ok"], rec["not_exhibited"])
        self.assertEqual(rec["view_entries_differing"], 0)
        self.assertEqual(rec["salted_leaves_authenticated"], sum(len(views[k].role["columns"]) for k in tail))
        tk = "B0"
        p1 = PRX.p1_opened_column_entry(views[tk], tk)
        self.assertTrue(p1["fires"], p1)
        sw = PRX.pad_msg_swap(views[tk], tk, True)
        self.assertTrue(sw["fires"], sw)
        _r, pre = PRX.preimage_for_view(views[tk], name=tk, verify=False)
        self.assertFalse(pre.fail)
        sl = PRX.salted_leaf_control(pre, views[tk], tk, self.b.hash_rule)
        self.assertTrue(sl["honest_authenticates"] and sl["fires"], sl)
        # a control that is not shown honest first does not fire
        self.assertFalse(PRX.pad_msg_swap(views[tk], tk, False)["fires"])


if __name__ == "__main__":
    unittest.main()
