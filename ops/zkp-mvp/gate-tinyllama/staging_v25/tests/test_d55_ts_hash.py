#!/usr/bin/env python3
"""[v25 staging, 2026-11-02, TS / CENSUS lane] Tests of TS-1 and the claim
census (`zk60_native_rg_d55ts`) and of the hash layer and the hash census
(`zk60_native_rg_d55hash`) on a D55 fork-run capture, and of the driver block
that adds them (`zk60_native_rg_d55`).

The port tests run anywhere the repository's frozen review scripts are.  The
bundle tests need a REGISTERED R13 D55 bundle (`ZK60_D55_R13_BUNDLE`, as in
`test_d55_r13_gate`) and skip without it; they run the cheap parts only (the
tail's roles, the census on every role, the hash layer and census).  Set
`ZK60_D55TS_FULL=1` for the whole TS part (minutes at the rung).
`ZK60_D55_BASE_BUNDLES` (comma-separated) names further registered bundles,
e.g. the TinyLlama / Shieldstral bases, for the base tests.
NOTHING HERE IS A PRIVACY STATEMENT."""

import collections
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(os.path.dirname(HERE), "scripts")
sys.path.insert(0, SCRIPTS)

import zk60_native_rg_d55hash as H  # noqa: E402
import zk60_native_rg_d55ts as S  # noqa: E402

BUNDLE = os.environ.get("ZK60_D55_R13_BUNDLE", "")
BASES = [p for p in os.environ.get("ZK60_D55_BASE_BUNDLES", "").split(",") if p.strip()]
FULL = os.environ.get("ZK60_D55TS_FULL", "") == "1"


def _blake3_present():
    try:
        import blake3  # noqa: F401
        return True
    except ImportError:
        return False


def _ts_present():
    try:
        S._repo_file(S.TS_TRAINED_REL)
        S._repo_file(S.TS_REVIEW_REL)
        return True
    except FileNotFoundError:
        return False


@unittest.skipUnless(_ts_present(), "the frozen ts_trained.py / review scripts are not in this checkout")
class RelocatedTool(unittest.TestCase):
    def test_the_frozen_tool_loads_at_its_pin_with_one_line_relocated(self):
        TT, rec = S.load_ts()
        self.assertEqual(rec["ts_trained_sha256"], S.TSW.TS_TRAINED_PIN)
        self.assertTrue(rec["review_pins_equal"])
        self.assertEqual(rec["review_scripts_sha256"], dict(TT.PINS))
        self.assertEqual(rec["relocation"]["replaced_line"], S.LAPTOP_TS_LINE)
        with open(rec["ts_trained"], encoding="utf-8") as fh:
            self.assertEqual(fh.read().count(S.LAPTOP_TS_LINE), 1)
        self.assertTrue(TT.T.stage0_selftest()["ok"])

    def test_the_review_prediction_names_every_control_ts_trained_runs(self):
        TT, rec = S.load_ts()
        with open(rec["ts_trained"], encoding="utf-8") as fh:
            src = fh.read()
        body = src[src.index("def controls(role):"): src.index("def fidelity(")]
        names = re.findall(r'rec\("([^"]+)"', body)
        self.assertEqual(sorted(names), sorted(S.REVIEW_PREDICTION))
        fires = {n for n, v in S.REVIEW_PREDICTION.items() if v}
        self.assertEqual(fires, {"C1 shared reserved pair", "C2 cm = 0 (pair removed)",
                                 "G7-D3 control: a copy sharing the pair whose DATA weights differ in one row"})


class HashCensusRules(unittest.TestCase):
    def test_the_declared_pairs_are_s25s_and_the_81_byte_row_is_one_byte_labels_only(self):
        self.assertEqual(len(H.DECLARED), 10)
        a = "the transcript absorb of `A` with 32 bytes of data"
        b = "the transcript absorb of `M` with 32 bytes of data"
        self.assertIsNotNone(H.declared(81, a, b))
        c = "the transcript absorb of `ab` with 31 bytes of data"
        self.assertIsNone(H.declared(81, a, c))
        self.assertIsNotNone(H.declared(66, "the transcript absorb of `pb-fork-s0` with 8 bytes of data",
                                        "the transcript absorb of `pb-fork-s1` with 8 bytes of data"))
        self.assertIsNone(H.declared(73, "the transcript absorb of `pb-scalar` with 16 bytes of data",
                                     "the transcript absorb of `zz` with 23 bytes of data"))

    @unittest.skipUnless(_blake3_present(), "blake3 is not installed")
    def test_the_recorder_restores_everything_and_the_conditions_fire(self):
        import blake3
        import zk60_native_jv_field as F
        import zk60_native_rg_hashrule as HR
        rule = HR.HashRule.for_profile("hashline-zk-mr1/private-block-rung-lh-t32-dev/1")
        before = (blake3.blake3, F.Transcript.absorb, HR.KeyedTranscript.absorb, HR.KeyedTranscript._squeeze)
        r = H.Recorder(rule)
        with r:
            tr = rule.transcript(b"d" * 60)
            tr.absorb(b"pb-slot", b"\0" * 8)
            tr.challenge_fp2()
            rule.node(b"\0" * 32, b"\1" * 32)
        self.assertEqual(before, (blake3.blake3, F.Transcript.absorb, HR.KeyedTranscript.absorb, HR.KeyedTranscript._squeeze))
        e = H.evaluate(r)
        self.assertTrue(e["C-R1_no_40_byte_F_U_input"] and e["C-R2_constructor_not_47"])
        self.assertTrue(e["ACC_every_call_attributed"], e["findings"])
        self.assertEqual(e["constructor_lengths"], [72])
        self.assertEqual(e["functions"]["F_N"], {"64": 1})
        r2 = H.Recorder(rule)
        with r2:
            rule.transcript(b"x" * 35)
            blake3.blake3(b"\0" * 40).digest()
        e2 = H.evaluate(r.merged(r2))
        self.assertFalse(e2["C-R2_constructor_not_47"])
        self.assertFalse(e2["C-R1_no_40_byte_F_U_input"])
        self.assertFalse(e2["ok"])


class DriverBlock(unittest.TestCase):
    def test_the_lane_block_is_delimited_once_and_names_its_parts(self):
        with open(os.path.join(SCRIPTS, "zk60_native_rg_d55.py"), encoding="utf-8") as fh:
            src = fh.read()
        self.assertEqual(src.count("# --- [TS / CENSUS lane, 2026-11-02] begin"), 1)
        self.assertEqual(src.count("# --- [TS / CENSUS lane, 2026-11-02] end"), 1)
        block = src[src.index("# --- [TS / CENSUS lane, 2026-11-02] begin"): src.index("# --- [TS / CENSUS lane, 2026-11-02] end")]
        for p in ("TS-1 terminal surjection", "CENSUS claim census", "HASH-1 hash layer", "HASH-2 hash census"):
            self.assertIn(p, block)


@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE) and _blake3_present() and _ts_present(),
                     "set ZK60_D55_R13_BUNDLE to a registered R13 D55 capture (and install blake3)")
class OnABundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import zk60_native_rg_d55 as D
        cls.D = D
        cls.b = D.D55Bundle(BUNDLE)
        cls.TT, _ = S.load_ts()
        cls.runj, cls.keys = S.role_keys(BUNDLE)

    def test_every_role_is_read_and_the_census_is_empty(self):
        self.assertEqual([k for k, _f, _i in self.keys][:2], ["fork00:A", "fork00:H"])
        tails = [k for k, _f, _i in self.keys if k.startswith("tail:")]
        self.assertEqual(tails, [f"tail:B{k}" for k in range(self.b.boundaries)] + ["tail:E-Input", "tail:E-Output"])
        for key, fn, idx in self.keys:
            e = S.load_role(self.TT, BUNDLE, key, fn, idx, self.runj)
            c = self.TT.pcs_census(e["role"])
            self.assertEqual((c["identical_claims"], c["equal_published_values"], c["same_data_weights_same_group"]), ([], [], []), key)
        a0 = S.load_role(self.TT, BUNDLE, *self.keys[0], self.runj)
        ctl = S.census_controls(self.TT, a0)
        self.assertTrue(ctl["ok"], ctl)

    def test_the_tail_roles_are_onto_and_ts1_fires_on_each(self):
        for key, fn, idx in self.keys:
            if not key.startswith("tail:"):
                continue
            e = S.load_role(self.TT, BUNDLE, key, fn, idx, self.runj)
            role = e["role"]
            for gi in range(len(role.groups)):
                _t, g = S.run_task(("group", BUNDLE, key, fn, idx, gi))
                self.assertTrue(g["surjective_onto_consistency_subspace"], (key, gi))
                self.assertEqual(g["disclosed_Fp"], 0, (key, gi))
            gi = S.ts1_group(role)
            self.assertIsNotNone(gi, key)
            _t, row = S.run_task(("ts1", BUNDLE, key, fn, idx, gi))
            self.assertTrue(row["fires"], row)
            n = 1 << e["log_cols"]
            self.assertLessEqual(row["pair_removed_disclosed_Fp"], 2 * (n + 1))
            if row["data_rows"] == 1:
                self.assertEqual(row["pair_removed_disclosed_Fp"], n)

    def test_the_hash_layer_and_census_and_every_control(self):
        hl, hc = H.d55_hash(self.b, controls=True)
        self.assertTrue(hl["ok"], hl.get("findings"))
        self.assertEqual(hl["columns_authenticated"], hl["columns_checked"])
        self.assertTrue(all(v["fires"] for v in hl["controls"].values() if isinstance(v, dict)))
        self.assertTrue(hc["ok"], hc["findings"])
        self.assertTrue(hc["W-2_holds"] and hc["W-2g_holds"] and hc["ACC_every_call_attributed"])
        self.assertTrue(all(v["fires"] for v in hc["controls"].values() if isinstance(v, dict)))
        self.assertEqual(hc["constructor_lengths"], [12 + len(self.b.profile)])

    @unittest.skipUnless(FULL, "set ZK60_D55TS_FULL=1 for the whole TS part")
    def test_the_whole_ts_part(self):
        ts, cen = S.d55_ts_census(BUNDLE, controls=True)
        self.assertTrue(ts["ok"], ts["expectation"])
        self.assertTrue(cen["ok"])


@unittest.skipUnless(BASES and _blake3_present() and _ts_present(), "set ZK60_D55_BASE_BUNDLES to registered R13 D55 bundles")
class TheRegisteredBases(unittest.TestCase):
    def test_each_base_is_a_registered_r13_run_and_its_hash_layer_holds(self):
        import zk60_native_rg_d55 as D
        import zk60_native_rg_d55r13 as X
        seen = collections.Counter()
        for p in BASES:
            b = D.D55Bundle(p)
            self.assertTrue(D.d55_integrity(b)["ok"], p)
            facts = D.d55_facts(b)
            self.assertEqual(facts["family"], "R13")
            self.assertIs(b.manifest.get("proved_on_gpu"), False, p)
            seen[facts["block_profile"]] += 1
            cals = X.fork_calibrations(b, facts)
            self.assertEqual(len(cals), b.blocks)
            hl = H.d55_hash_layer(b, probe=True)
            self.assertTrue(hl["ok"], (p, hl["findings"][:2]))
        self.assertTrue(all(n >= 1 for n in seen.values()))


if __name__ == "__main__":
    unittest.main()
