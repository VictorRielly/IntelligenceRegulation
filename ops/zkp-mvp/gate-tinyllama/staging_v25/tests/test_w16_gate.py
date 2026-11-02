#!/usr/bin/env python3
"""[v25 staging, 2026-11-01] Tests of `zk60_native_rg_w16` (the first W16
items).  The port tests are synthetic and run anywhere; the bundle tests need
a W16 rung capture (`w16_privacy_gate_write_the_w16_bundles`) named by
`ZK60_W16_RUNG_BUNDLE` and skip without it.  NOTHING HERE IS A PRIVACY
STATEMENT."""

import copy
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))

import zk60_native_rg_w16 as W  # noqa: E402

# the W16 rung's precision at its tested calibration (the capture's
# calibration line: base tn=10 qkv=8 score=6 o=9 ao=7 gate=8 product=14
# down=6, LowH24, gate-common 19, wrho_s 17, log_cols 14)
RUNG_PREC = {"norm_tn": 2, "q": 15, "k": 15, "v": 16, "score": 18, "pv": 12, "ao": 21, "gate": 18, "up": 12,
             "product": 6, "down": 20, "f_p": 12, "norm_bits": 16, "attention_bits": 16, "gate_bits": 12,
             "product_bits": 24}
RUNG = ("LowH24", RUNG_PREC, 19, 17, 14)
BUNDLE = os.environ.get("ZK60_W16_RUNG_BUNDLE", "")


def _blake3_present():
    try:
        import blake3  # noqa: F401
        return True
    except ImportError:
        return False


class W16Port(unittest.TestCase):
    def test_widths_families_and_sub_planes_at_the_rung(self):
        st, p, g, ws, lc = RUNG
        self.assertEqual(W.widths(st, p, g, ws), [1, 2, 3, 4, 5, 7, 12, 13, 15, 16])
        fams = W.families(W.widths(st, p, g, ws), lc)
        self.assertEqual([n for (_w, n) in fams], [1] * 8 + [2, 4])
        self.assertEqual(len(W.sub_planes(fams)), 14)
        self.assertEqual([w for (w, _n) in fams if not W.is_full(w, lc)], [1, 2, 3, 4, 5, 7, 12, 13])

    def test_the_gate_shift_moves_one_family(self):
        st, p, _g, ws, _lc = RUNG
        self.assertIn(3, W.widths(st, p, 19, ws))
        self.assertNotIn(3, W.widths(st, p, 20, ws))   # G = 20: the gate top is a 4-bit limb, already present

    def test_plane_list_counts_per_domain(self):
        planes = W.w16_plane_list(*RUNG[:1], False, *RUNG[1:])
        count = {}
        for _n, d in planes:
            count[d] = count.get(d, 0) + 1
        self.assertEqual(count, {"T": 4, "Ht": 2, "L": 2, "D": 19, "Q": 6, "Kv": 6, "S": 10, "F": 9, "Tab": 17})
        names = [n for n, _d in planes]
        self.assertEqual(len(names), len(set(names)))
        # R13's word-limb groups and PL are gone; the 24-bit product keeps one signed top
        for gone in ("A_XL0", "A_YL0", "A_QL0", "A_UL0", "A_PL0", "A_HL0"):
            self.assertNotIn(gone, names)
        self.assertIn("A_HT", names)
        self.assertEqual(names[-14:], ["A_R1_0", "A_R2_0", "A_R3_0", "A_R4_0", "A_R5_0", "A_R7_0", "A_R12_0", "A_R13_0",
                                       "A_R15_0", "A_R15_1", "A_R16_0", "A_R16_1", "A_R16_2", "A_R16_3"])

    def test_lookups_and_helper_counts(self):
        st, p, g, ws, lc = RUNG
        hc = W.helper_counts(st, p, g, ws)
        self.assertEqual(hc, {"L": 1, "D": 10, "Q": 3, "Kv": 3, "S": 5, "F": 4})
        h = W.w16_h_list(st, p, g, ws, lc)
        self.assertEqual(len(h), 46)
        self.assertEqual(h[-1], ("H_U", "Tab"))
        # every lookup width is a family width or the byte width
        fams = set(W.widths(st, p, g, ws)) | {8}
        for d in W.LOOKUP_DOMS:
            for terms, _cst, width in W.w16_lookups(d, st, p, g, ws):
                self.assertIn(width, fams, (d, terms, width))
        # the 24-bit product word: a low expression and a signed top byte at the 2^23 bias
        f = W.w16_lookups("F", st, p, g, ws)
        self.assertIn(([("A_H", 1), ("A_HT", -(1 << 16))], 0, 16), f)
        self.assertIn(([("A_HT", 1)], 128, 8), f)

    def test_the_range_and_support_columns(self):
        gamma = (5, 7)
        col = W.range_column(1, 0, 2, gamma)        # a 1-bit family laid over 4 entries: 0 1 0 1
        g = W.g_range(gamma, 1)
        self.assertEqual(g, (5 * 201, 7 * 201))
        self.assertEqual(col, [W.T.add(W.T.k(v), g) for v in (0, 1, 0, 1)])
        self.assertEqual(W.support_column(1, 2), [W.T.ONE, W.T.ONE, W.T.ZERO, W.T.ZERO])
        col16 = W.range_column(16, 3, 14, gamma)     # sub-plane 3 of the 16-bit family
        self.assertEqual(col16[0], W.T.add(W.T.k(3 << 14), W.g_range(gamma, 16)))
        self.assertTrue(W.is_full(16, 14) and not W.is_full(13, 14))

    def test_refusals_by_name(self):
        with self.assertRaises(ValueError):
            W.w16_plane_list("LowH24", True, *RUNG[1:])          # DD: not ported
        with self.assertRaises(ValueError):
            W.w16_plane_list("LowH24", False, RUNG_PREC, 25, 17, 14)
        with self.assertRaises(ValueError):
            W.limbs_of(25)
        self.assertFalse(W.is_w16_block_profile("hashline-zk-mr1/private-block-rung-lh-t32-dev/1"))   # R13's rung

    def test_no_v24_module_is_changed_by_this_one(self):
        # the module only ADDS names; the v24 tables it reads are untouched
        import zk60_native_rg_r13slots as R
        self.assertNotIn("hashline-zk-mr1/private-block-rung-lh-t32-w16-dev/1", R.ACCURACY_PROFILES)
        self.assertEqual(len(R.ACCURACY_PROFILES), 12)


@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE) and _blake3_present(),
                     "set ZK60_W16_RUNG_BUNDLE to a W16 rung capture (and install blake3)")
class W16RungBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from zk60_native_rg_block import load_bundle
        cls.b = load_bundle(BUNDLE)
        cls.facts = W.w16_facts(cls.b)

    def test_facts(self):
        self.assertEqual(self.facts["name"], "W16_RUNG_H24")
        self.assertEqual((self.facts["gate_shift"], self.facts["wrho_s"], self.facts["log_cols"]), (19, 17, 14))
        self.assertEqual({k: self.facts["precision"][k] for k in RUNG_PREC}, RUNG_PREC)

    def test_layout_and_its_controls(self):
        self.assertTrue(W.check_layout(self.b, self.facts)["ok"])
        b = copy.copy(self.b)
        b.run = copy.deepcopy(self.b.run)
        b.run["plane_index"]["a_planes"][-1]["name"] = "A_R16_9"          # a renamed histogram
        self.assertFalse(W.check_layout(b, self.facts)["ok"])
        b.run = copy.deepcopy(self.b.run)
        sp = b.run["plane_index"]["slot_planes"]
        sp[18]["planes"].append({"role": "A", "id": 61, "name": "A_R1_0"})   # a histogram read by SC_FZC too
        self.assertFalse(W.check_layout(b, self.facts)["ok"])

    def test_tab_tables_and_their_controls(self):
        r = W.check_tab_tables(self.b, self.facts)
        self.assertTrue(r["ok"], r["findings"])
        self.assertEqual(r["rebuilt_and_equal"], 23)
        self.assertTrue(W.tab_control(self.b, self.facts)["fires"])
        st = copy.copy(self.b.stages[0])
        st.doc = copy.deepcopy(self.b.stages[0].doc)
        pub = [t for t in st.doc["arguments"][19]["tables"] if t["kind"] == "public"]
        pub[5]["sha256"] = pub[6]["sha256"]                              # two range columns swapped in effect
        b = copy.copy(self.b)
        b.stages = [st]
        self.assertFalse(W.check_tab_tables(b, self.facts)["ok"])

    def test_a_non_w16_run_profile_is_refused(self):
        b = copy.copy(self.b)
        b.profile = "hashline-zk-mr1/private-run-rung-lh-t32-dev/1"
        with self.assertRaises(ValueError):
            W.w16_facts(b)

    def test_pins_are_classified_and_range16_is_not_pinned(self):
        p = W.classify_pins(self.b, W.default_r19b_manifest())
        self.assertTrue(p["r19b_manifest_found"])
        self.assertEqual(p["pins"], p["at_r19b"] + len(p["read_here"]) + len(p["unread"]))
        self.assertFalse(p["range16_rs_pinned"])


if __name__ == "__main__":
    unittest.main()
