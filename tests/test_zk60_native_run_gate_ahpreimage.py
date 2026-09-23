"""Tests for round 7: the PREIMAGE construction for `A` and `H` at the
development shapes -- the step rounds 1-6 recorded as "skipped, not faked".

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_ahpreimage.py"

FOUR ARMS.

* A PURE arm that needs nothing: every arithmetic primitive of the new
  module really IS the toy gate's object (identity, not a copy), and
  `DERIVED_FROM` names every re-derived method.
* An EQUIVALENCE arm on the TOY captures, which are tracked in this
  repository: the new wide classes, run at `msg_width == pad_width == 256`,
  must reproduce `zk60_native_pg_pcs`'s own result to the byte -- the same
  matrix digest, the same step records, the same exhibited-randomness
  digest, the same fibre dimension and the same verification counts.  This
  is the evidence that round 7 is not a silent fork of a hash-pinned record.
* The RECORDED arm, skipped when round 7's evidence is absent: every figure
  the report quotes, asserted from `results/zk60_native_run_gate_preimage/`.
* The LIVE arm, skipped when the ~41 MB bundles are absent: a commitment
  solved and verified from scratch, the system's dimensions, and each of
  the six controls.

Nothing here asserts a privacy property.  A constructed preimage says the
captured view is reproducible from the ALL-ZERO hidden input with suitable
blinding; it says nothing about the LAW of that blinding.
"""

from __future__ import annotations

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_preimage")
TOY = os.path.join(ROOT, "results", "zk60_native_captures_20260919", "captures")
TOY_BLOCK = os.path.join(
    TOY, "40083e7ac8f3f6c749f12de31ddd9c0e779a016c33fb50180003c60d7cf0716b.json")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_G = os.path.join(BUNDLES, "run-g-dense-s20")
RUN_H = os.path.join(BUNDLES, "run-h-zero-s20")
HAVE_BUNDLES = os.path.isdir(RUN_G) and os.path.isdir(RUN_H)
HAVE_TOY = os.path.isfile(TOY_BLOCK)
RECORDS = sorted(
    f for f in (os.listdir(EVIDENCE) if os.path.isdir(EVIDENCE) else [])
    if f.endswith(".json") and f.startswith("run-")
)
HAVE_RECORDS = bool(RECORDS)

import zk60_native_pg_pcs as pg  # noqa: E402
import zk60_native_rg_ahpreimage as ahp  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_ahcontrols import (  # noqa: E402
    p1_opened_column_entry,
    p2_group_vector_message_entry,
    p3_group_vector_pad_entry,
    p4_one_pad_fewer,
    p5_shared_blinding_row,
    p6_off_the_disclosed_identity,
)
from zk60_native_rg_ahpreimage import (  # noqa: E402
    DERIVED_FROM,
    IMPORTED_PRIMITIVES,
    WideRoleLayout,
    WideRolePreimage,
    layout_for_view,
    preimage_for_view,
)

_STATE = {}


def run_views(which=RUN_G, stages=None):
    """The bundle's commitments, built once per process."""
    key = (which, stages)
    if key not in _STATE:
        from zk60_native_rg_bundle import RunBundle
        from zk60_native_rg_pcs import RunRoleView
        from zk60_native_rg_replay import RunReplay

        b = RunBundle(which)
        rp = RunReplay(b).run()
        views = {}
        for st in b.stages:
            if stages is not None and st.index not in stages:
                continue
            for role in st.roles:
                k = st.key(role["role"])
                v = RunRoleView(st, role, rp.stages[st.index]["role_prox_rhos"][k],
                                b.shape, name=k)
                v.run(rp.stages[st.index]["role_lambdas"][k])
                views[k] = v
        _STATE[key] = (b, views)
    return _STATE[key]


def toy_views(names):
    if "toy" not in _STATE:
        from zk60_native_jv_capture import Capture
        from zk60_native_jv_pcs import RoleView
        from zk60_native_jv_replay import Replay

        cap = Capture(TOY_BLOCK)
        rep = Replay(cap).run()
        out = {}
        for role in cap.roles:
            nm = role["role"]
            v = RoleView(cap, role, rep.role_prox_rhos[nm])
            v.run(rep.role_lambdas[nm])
            out[nm] = v
        _STATE["toy"] = (cap, out)
    cap, out = _STATE["toy"]
    return cap, {n: out[n] for n in names}


# =====================================================================
#  the pure arm
# =====================================================================
class TestTheModuleIsNotAFork(unittest.TestCase):
    """Every primitive is the toy gate's OBJECT, not a copy of its text."""

    def test_every_primitive_is_the_toy_gate_s_own_object(self):
        for name in IMPORTED_PRIMITIVES:
            self.assertIs(getattr(ahp, name), getattr(pg, name), name)

    def test_the_module_defines_no_primitive_of_its_own(self):
        """A re-implementation would show up as a function defined HERE."""
        import inspect

        src = inspect.getsource(ahp)
        for name in IMPORTED_PRIMITIVES:
            self.assertNotIn(f"def {name}(", src, name)
            self.assertNotIn(f"class {name}:", src, name)

    def test_derived_from_names_every_re_derived_method(self):
        methods = set()
        for cls in (WideRoleLayout, WideRolePreimage):
            for nm, obj in vars(cls).items():
                if callable(obj) and not nm.startswith("__"):
                    methods.add(f"{cls.__name__}.{nm}")
        methods.add("WideRoleLayout.__init__")
        methods.add("WideRolePreimage.__init__")
        documented = set(DERIVED_FROM)
        # every documented method exists, and every method that has a toy
        # counterpart is documented
        for nm in documented:
            cls, meth = nm.split(".")
            self.assertTrue(hasattr({"WideRoleLayout": WideRoleLayout,
                                     "WideRolePreimage": WideRolePreimage}[cls], meth), nm)
        toy_methods = {
            f"WideRoleLayout.{m}" for m in vars(pg.RoleLayout) if not m.startswith("__")
        } | {
            f"WideRolePreimage.{m}" for m in vars(pg.RolePreimage)
            if not m.startswith("__")
        }
        missing = (toy_methods & methods) - documented
        self.assertEqual(missing, set(), f"undocumented re-derivations: {missing}")
        # and the map is COMPLETE: every method is either a re-derivation or
        # named as new here
        unaccounted = methods - documented - set(ahp.NEW_HERE) - {
            "WideRoleLayout.__init__", "WideRolePreimage.__init__"}
        self.assertEqual(unaccounted, set(),
                         f"methods in neither map: {unaccounted}")

    def test_the_module_says_it_establishes_no_privacy_property(self):
        self.assertIn("NOTHING HERE ESTABLISHES A PRIVACY PROPERTY", ahp.__doc__)

    def test_the_stage_is_off_by_default_and_says_why(self):
        off = gate.FULL_PREIMAGE_OFF
        self.assertFalse(off["requested"])
        self.assertTrue(off["ok"])
        self.assertIn("opt-in", off["why_off"])
        self.assertIn("stay OPEN", off["consequence"])


# =====================================================================
#  the equivalence arm -- the real evidence that this is the same solve
# =====================================================================
@unittest.skipUnless(HAVE_TOY, "the tracked toy captures are absent")
class TestEquivalenceWithTheToyGate(unittest.TestCase):
    """At `msg_width == pad_width == 256` the wide classes must reproduce
    `zk60_native_pg_pcs` to the byte, on a real toy capture."""

    ROLES = ("H", "Input")

    def test_the_two_solves_agree_to_the_byte(self):
        from zk60_native_jv_pcs import column_functional_parts, zkey_weights

        cap, views = toy_views(self.ROLES)
        for nm in self.ROLES:
            v = views[nm]
            l1 = pg.RoleLayout(cap, v)
            p1 = pg.RolePreimage(l1, {}).build()
            v1 = p1.verify()

            l2 = WideRoleLayout(v, msg_width=256, pad_width=256,
                                zkey=zkey_weights,
                                colfun=lambda j, q: column_functional_parts(j))
            p2 = WideRolePreimage(l2).build()
            v2 = p2.verify()

            self.assertEqual(l1.matrix_digest(), l2.matrix_digest(), nm)
            self.assertEqual(l1.order, l2.order, nm)
            self.assertEqual(l1.anchor, l2.anchor, nm)
            self.assertEqual(l1.d, l2.d, nm)
            self.assertEqual(p1.steps, p2.steps, nm)
            self.assertEqual(p1.fail, p2.fail, nm)
            self.assertEqual(p1.X, p2.X, nm)
            self.assertEqual(p1.blinding_digest(), p2.blinding_digest(), nm)
            self.assertEqual(p1.fibre_dimension(), p2.fibre_dimension(), nm)
            for k in v1:
                if k in v2:
                    self.assertEqual(v1[k], v2[k], f"{nm}/{k}")
            self.assertTrue(v2["all_entries_equal"], nm)

    def test_the_wide_verify_adds_a_hash_arm_the_toy_has_not(self):
        """The one difference in `verify`, stated and asserted: with no rule
        supplied it says so rather than pretending to have checked."""
        from zk60_native_jv_pcs import column_functional_parts, zkey_weights

        _cap, views = toy_views(("Input",))
        l2 = WideRoleLayout(views["Input"], msg_width=256, pad_width=256,
                            zkey=zkey_weights,
                            colfun=lambda j, q: column_functional_parts(j))
        out = WideRolePreimage(l2).build().verify()
        self.assertFalse(out["hash_layer"]["checked"])
        self.assertIn("no hash rule", out["hash_layer"]["why"])


# =====================================================================
#  the recorded arm
# =====================================================================
@unittest.skipUnless(HAVE_RECORDS, "round 7's evidence is absent")
class TestTheRecord(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recs = {}
        for f in RECORDS:
            with open(os.path.join(EVIDENCE, f)) as fh:
                cls.recs[f[:-5]] = json.load(fh)

    def test_the_four_bundles_are_the_ones_the_round_names(self):
        self.assertEqual(
            set(self.recs),
            {"run-g-dense-s20", "run-h-zero-s20", "run-i-dense-k4", "run-j-zero-k4"},
        )

    def test_every_pcs_commitment_has_an_exhibited_preimage(self):
        for name, rec in self.recs.items():
            s = rec["stage11_full_preimage"]
            self.assertTrue(s["requested"], name)
            self.assertEqual(s["not_exhibited"], [], name)
            self.assertEqual(len(s["exhibited"]), 10, name)
            self.assertEqual(s["view_entries_differing"], 0, name)
            self.assertTrue(s["ok"], name)

    def test_the_entry_counts_are_the_shapes_own_arithmetic(self):
        """Not a constant: each count is re-derived from the commitment's own
        dimensions, so a changed shape changes the assertion with it."""
        for name, rec in self.recs.items():
            s = rec["stage11_full_preimage"]
            total = 0
            for p in s["per_commitment"]:
                dim, ver = p["system"], p["verification"]
                m, q = dim["message_positions_n"], dim["pad_symbols_Q"]
                self.assertEqual(ver["group_vector_entries"],
                                 dim["groups"] * (m + q), (name, p["commitment"]))
                self.assertEqual(ver["proximity_entries"], m + q,
                                 (name, p["commitment"]))
                self.assertEqual(ver["claim_values"], dim["claims"],
                                 (name, p["commitment"]))
                self.assertEqual(
                    ver["column_entries"],
                    dim["distinct_opened_columns_d"] * dim["rows"],
                    (name, p["commitment"]))
                self.assertEqual(ver["entries_compared"],
                                 ver["group_vector_entries"] + ver["proximity_entries"]
                                 + ver["claim_values"] + ver["column_entries"])
                total += ver["entries_compared"]
            self.assertEqual(total, s["view_entries_compared"], name)

    def test_nothing_differs_anywhere(self):
        for name, rec in self.recs.items():
            for p in rec["stage11_full_preimage"]["per_commitment"]:
                v = p["verification"]
                self.assertEqual(v["group_vector_mismatches"], 0, (name, p["commitment"]))
                self.assertEqual(v["proximity_mismatches"], 0, (name, p["commitment"]))
                self.assertEqual(v["claim_value_mismatches"], 0, (name, p["commitment"]))
                self.assertEqual(v["column_mismatches"], 0, (name, p["commitment"]))
                self.assertIsNone(v["first_mismatch"], (name, p["commitment"]))

    def test_every_opened_column_re_authenticates(self):
        for name, rec in self.recs.items():
            s = rec["stage11_full_preimage"]
            per = s["per_commitment"]
            self.assertEqual(s["salted_leaves_authenticated"], 256 * len(per), name)
            for p in per:
                h = p["verification"]["hash_layer"]
                self.assertTrue(h["checked"], (name, p["commitment"]))
                self.assertEqual(h["columns_rehashed"], 256)
                self.assertEqual(h["leaf_digests_equal_to_the_capture_s"], 256)
                self.assertEqual(h["salted_leaves_authenticated"], 256)
                self.assertEqual(h["failures"], [])
                self.assertIn("NOT reproducible", h["unopened_leaves"])

    def test_the_two_shapes_are_the_ones_the_report_quotes(self):
        want = {
            "run-g-dense-s20": {"A": (623, 377, 36, 122), "H": (576, 468, 9, 53)},
            "run-h-zero-s20": {"A": (623, 377, 36, 122), "H": (576, 468, 9, 53)},
            "run-i-dense-k4": {"A": (727, 481, 36, 122), "H": (720, 612, 9, 53)},
            "run-j-zero-k4": {"A": (727, 481, 36, 122), "H": (720, 612, 9, 53)},
        }
        for name, rec in self.recs.items():
            for p in rec["stage11_full_preimage"]["per_commitment"]:
                kind = p["commitment"][0]
                if kind not in ("A", "H"):
                    continue
                d = p["system"]
                self.assertEqual(
                    (d["rows"], d["data_rows"], d["groups"], d["claims"]),
                    want[name][kind], (name, p["commitment"]))
                self.assertEqual(d["message_positions_n"], 1024)
                self.assertEqual(d["pad_symbols_Q"], 256)

    def test_the_controls_all_fire(self):
        for name, rec in self.recs.items():
            c = rec["stage11_full_preimage"]["controls"]
            self.assertTrue(c["ok"], name)
            self.assertEqual(c["controls_total"], 6, name)
            self.assertEqual(c["controls_that_fire"], c["controls_applicable"], name)
            named = {x["control"] for x in c["controls"]}
            self.assertEqual(named, {"P-1", "P-2", "P-3", "P-4", "P-5", "P-6"}, name)

    def test_the_channel_table_moved_three_channels_and_no_more(self):
        for name, rec in self.recs.items():
            ch = rec["stage7_channels"]
            # [ROUND 8] round 7's evidence was re-taken under round 8's
            # gate, which grades M's q, M's proximity vector and M's own
            # opened columns as three separate channels: 25 -> 28, and all
            # three are OPEN here because `--mask-cfs` is off in this
            # directory on purpose.  Round 7's own five stay CONSTRUCTED and
            # no stage-11 figure moved.
            self.assertEqual(ch["total"], 28, name)
            # [ROUND 9j, DELIBERATE] status page row 26: the boundary scale
            # channel OPEN -> ARGUED on D12b(3) / ruling R-5 (built, lane stage
            # 21), so argued +1 and open -1; no figure moved
            self.assertEqual(ch["counts"],
                             {"constructed": 5, "derived": 5, "argued": 5, "open": 13},
                             name)
            self.assertEqual(ch["grading_failures"], [], name)
            moved = [c["channel"] for c in ch["channels"]
                     if c["status"] == "constructed"]
            self.assertIn("opening-group and proximity vectors of A and H", moved)
            self.assertIn("the pad half of every published vector", moved)
            self.assertIn("opened column values", moved)

    def test_a_run_preimage_is_still_open_and_says_why(self):
        for name, rec in self.recs.items():
            ch = [c for c in rec["stage7_channels"]["channels"]
                  if c["channel"].startswith("the preimage construction for a RUN")][0]
            self.assertEqual(ch["status"], "open", name)
            self.assertIn("JOINT object", ch["reason"])
            self.assertTrue(ch["per_commitment_not_joint"])

    def test_the_record_denies_a_privacy_property(self):
        for name, rec in self.recs.items():
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["privacy_acceptance"], name)
            s = rec["stage11_full_preimage"]
            self.assertTrue(s["this_is_not_a_privacy_result"], name)
            joined = " ".join(s["what_it_does_not_show"])
            self.assertIn("LAW of the blinding", joined)
            self.assertIn("UNOPENED Merkle leaf", joined)
            self.assertIn("125M", joined)

    def test_the_evidence_came_from_the_tool_bytes_now_in_the_tree(self):
        import hashlib

        for name, rec in self.recs.items():
            for tool, want in rec["tool_sha256"].items():
                path = os.path.join(ROOT, "scripts", tool)
                with open(path, "rb") as fh:
                    got = hashlib.sha256(fh.read()).hexdigest()
                self.assertEqual(got, want, f"{name}: {tool} moved since the run")

    def test_the_zero_witness_bundles_are_the_sanity_anchor(self):
        """On a bundle the prover made from the ALL-ZERO hidden input the
        constructed preimage is a preimage of the SAME input the prover used,
        so it must succeed exactly as on the dense ones -- and it does."""
        for name in ("run-h-zero-s20", "run-j-zero-k4"):
            s = self.recs[name]["stage11_full_preimage"]
            self.assertEqual(s["not_exhibited"], [], name)
            self.assertEqual(s["view_entries_differing"], 0, name)


# =====================================================================
#  the live arm
# =====================================================================
@unittest.skipUnless(HAVE_BUNDLES, "the run bundles are absent")
class TestLive(unittest.TestCase):
    def test_a_boundary_solves_and_verifies_from_scratch(self):
        b, views = run_views(RUN_G)
        v = views["B0"]
        rec, _pre = preimage_for_view(v, name="B0", hash_rule=b.hash_rule,
                                      root=v.role["commitment"]["root"])
        self.assertTrue(rec["preimage_exhibited"])
        ver = rec["verification"]
        self.assertTrue(ver["all_entries_equal"])
        self.assertEqual(ver["column_mismatches"], 0)
        self.assertEqual(ver["hash_layer"]["salted_leaves_authenticated"], 256)

    def test_the_message_half_agrees_with_round_1_s_own_construction(self):
        """Round 1's singleton-group solve and round 7's general one are two
        different routes to the same object, so on a boundary they must agree
        on every message entry."""
        from zk60_native_rg_preimage import MsgPreimage

        b, views = run_views(RUN_G)
        v = views["B0"]
        old = MsgPreimage(v, b.shape)
        old.build()
        new = WideRolePreimage(layout_for_view(v, name="B0")).build()
        self.assertEqual(new.fail, [])
        n = b.shape.cols
        for i in range(v.rows):
            self.assertEqual(old.x[i][:n], new.X[i][:n], i)

    def test_the_systems_dimensions_are_read_from_the_shape(self):
        _b, views = run_views(RUN_G, stages=(0,))
        d = layout_for_view(views["A@0"]).dimensions()
        self.assertEqual(d["rows"], 623)
        self.assertEqual(d["data_rows"], 377)
        self.assertEqual(d["non_data_rows"], 246)
        self.assertEqual(d["message_positions_n"], 1024)
        self.assertEqual(d["pad_symbols_Q"], 256)
        self.assertEqual(d["groups"], 36)
        self.assertEqual(d["claims"], 122)
        self.assertEqual(d["generators_2_G_plus_1"], 74)
        self.assertEqual(d["reserved_pairs"], 122)
        self.assertEqual(d["u_rows"], [])
        # 244 reserved mask rows + a proximity pair is every non-data row
        self.assertEqual(2 * d["reserved_pairs"] + len(d["proximity_rows"]),
                         d["non_data_rows"])
        self.assertEqual(d["findings"], [])
        h = layout_for_view(views["H@0"]).dimensions()
        self.assertEqual(h["u_rows"], [468, 469])
        self.assertEqual((h["rows"], h["data_rows"], h["non_data_rows"]),
                         (576, 468, 108))
        self.assertEqual(h["claims"], 53)
        self.assertEqual(h["reserved_pairs"], 53)
        # 53 distinct reserved pairs and a proximity pair are every non-data
        # row -- and one of the 53 IS the zero-sum pair, which is why the
        # capture declares only 104 reserved MASK rows for 53 claims
        self.assertEqual(2 * h["reserved_pairs"] + len(h["proximity_rows"]),
                         h["non_data_rows"])
        self.assertIn(tuple(h["u_rows"]),
                      {p for p in layout_for_view(views["H@0"]).claim_pair.values()})
        # the zsum slot of group 7 READS the u pair group 8 owns
        self.assertEqual(h["groups_reading_another_groups_rows"], {7: [8]})

    def test_the_solve_order_puts_the_zsum_group_after_the_one_it_reads(self):
        _b, views = run_views(RUN_G, stages=(0,))
        layout = layout_for_view(views["H@0"])
        for gi, dep in layout.cross_group_reads.items():
            for g in dep:
                self.assertLess(layout.order.index(g), layout.order.index(gi))

    # ---- the controls
    def test_p1_one_opened_column_entry(self):
        _b, views = run_views(RUN_G, stages=(0,))
        out = p1_opened_column_entry(views["H@0"], "H@0")
        self.assertTrue(out["fires"])
        self.assertIn("not reachable from the opened columns", out["refusal"])

    def test_p2_one_group_vector_entry_message_half(self):
        _b, views = run_views(RUN_G, stages=(0,))
        out = p2_group_vector_message_entry(views["A@0"], "A@0")
        self.assertTrue(out["fires"])
        self.assertIn("cannot be met inside the kernel", out["refusal"])

    def test_p3_one_group_vector_entry_pad_half(self):
        _b, views = run_views(RUN_G, stages=(0,))
        out = p3_group_vector_pad_entry(views["H@0"], "H@0")
        self.assertTrue(out["fires"])

    def test_p4_one_pad_fewer_than_the_distinct_opened_columns(self):
        _b, views = run_views(RUN_G, stages=(0,))
        out = p4_one_pad_fewer(views["H@0"], "H@0")
        self.assertTrue(out["fires"])
        self.assertIn("cannot meet", out["refusal"])

    def test_p5_a_blinding_row_shared_between_A_and_H(self):
        _b, views = run_views(RUN_G, stages=(0,))
        out = p5_shared_blinding_row(views["A@0"], views["H@0"], "A@0", "H@0")
        self.assertTrue(out["fires"])
        self.assertFalse(out["joint_preimage_exists"])
        self.assertEqual(out["positions_where_the_two_forced_values_differ"], 1024)

    def test_p6_a_fixed_input_off_H_s_disclosed_identity(self):
        b, views = run_views(RUN_G, stages=(0,))
        out = p6_off_the_disclosed_identity(views["H@0"], "H@0",
                                            b.run["shape"]["profile"])
        self.assertTrue(out["fires"])
        self.assertFalse(out["before_projection"]["solved"])
        self.assertTrue(out["after_projection"]["all_entries_equal"])

    def test_no_capture_file_was_written(self):
        """Every perturbation is in memory: the bundle's bytes must be what
        they were before the controls ran."""
        import hashlib

        def digest():
            h = hashlib.sha256()
            for f in sorted(os.listdir(RUN_G)):
                with open(os.path.join(RUN_G, f), "rb") as fh:
                    h.update(fh.read())
            return h.hexdigest()

        before = digest()
        _b, views = run_views(RUN_G, stages=(0,))
        p4_one_pad_fewer(views["H@0"], "H@0")
        self.assertEqual(digest(), before)


if __name__ == "__main__":
    unittest.main()
