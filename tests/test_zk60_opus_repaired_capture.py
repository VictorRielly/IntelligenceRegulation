#!/usr/bin/env python3
"""O1/O2 tests for the repaired-profile capture adapter.

Reviewer: Opus 5, independent reviewer, 2026-09-08 session.  Implementation pin
b41d036c4c1eb1ed9272494815d742d0ccf29934; review worktree a8a1bc7.

Order of business (the dispatch requires the refusals to exist before the analysis):
  1. LayoutRecomputation  -- the layout, claim mapping, row roles and coefficient tags
     are recomputed from the source rules alone (no capture file) and pinned.
  2. AdapterRefusals      -- every mutation of a genuine capture that must be refused:
     changed source / coverage / profile / shape / shifts / roles, a missing pair row,
     a broken pair coefficient, altered row roles, tags, pads or columns.
  3. LegacySchema1Refused -- a legacy schema-1 capture wearing a full repaired label is
     still refused, by the layout recomputation rather than by its label.
  4. LegacyPositiveControl-- Fable's archived legacy tool still reproduces its numbers
     (A = 2n + 4, P3 W = 2n + 2, H = 2, T32 Wd fully recovered) on the legacy captures.
  5. RepairedCaptures     -- the four real captures parse, and the joint model gives
     A = 0, W = 0, H = 2 (the public LogUp identity, 0 without the zero-sum constraint).
  6. ResultsBinding       -- the delivered analysis JSON is bound to these tools/files.

    python3 -m unittest discover -s tests -p 'test_zk60_opus_repaired_capture.py' -v
"""
import hashlib
import importlib.util
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("opus_repaired_capture", ROOT / "scripts/zk60_opus_repaired_capture.py")
M = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(M)
C = M.C
R = M.R
P, ONE, ZERO, U = M.P, M.ONE, M.ZERO, M.U

CAPTURES = "/tmp/zk60-round16/captures"
INTERIM_MANIFEST = "/tmp/zk60-round16/summary.json"
# Codex publishes the validation record into the integration checkout; it reaches this
# review worktree only at the next merge, so both locations are accepted.
PUBLISHED_MANIFESTS = [ROOT / "results/zk60_round16_validation.json",
                       Path("/home/victor/IntelligenceRegulation/results/zk60_round16_validation.json")]
PUBLISHED_MANIFEST = next((p for p in PUBLISHED_MANIFESTS if p.exists()), PUBLISHED_MANIFESTS[0])
MANIFEST = str(PUBLISHED_MANIFEST) if PUBLISHED_MANIFEST.exists() else INTERIM_MANIFEST
LEGACY = "/tmp/zk60-round11/final-observations"
RESULTS = ROOT / "results/zk60_opus_repaired_capture_analysis.json"
PREFLIGHT = ROOT / "results/zk60_opus_capture_preflight.json"

# the pinned layout digest of round 16 (docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md O1)
LAYOUT_DIGEST = "e98e3189fe3d2b7eac1639cbf82d1e2aa71c3330ae7ba0e9e9607c8f52e76fa4"


def _captures():
    if not os.path.isdir(CAPTURES):
        return []
    return sorted(os.path.join(CAPTURES, f) for f in os.listdir(CAPTURES) if f.endswith(".json"))


def _one(privacy):
    """The first capture of a privacy mode (the header sits before the first role,
    but after the multi-kilobyte layout_description, so read a generous prefix)."""
    for p in _captures():
        with open(p) as fh:
            head = fh.read(1 << 18)
        if f'"privacy":"{privacy}"' in head:
            return p
    return None


# ---------------------------------------------------------------------------
# 1. the layout, recomputed from the source rules only
# ---------------------------------------------------------------------------


class LayoutRecomputation(unittest.TestCase):
    def setUp(self):
        self.zl = M.zk_layout(32, 16, 16, M.LOG_COLS, M.SHIFTS, mr1=True)

    def test_row_counts_mask_sites_and_prox_pairs(self):
        zl = self.zl
        self.assertEqual((zl["a_rows"], zl["h_rows"], zl["w_rows"]), (698, 1326, 11))
        self.assertEqual((zl["a_n"], zl["w_n"], zl["log_n"], zl["log_s"]), (256, 256, 8, 16))
        # every scalar A/W site and every proximity site is a PAIR of adjacent base rows
        self.assertEqual(zl["a_mf"], [20, 22, 24, 26, 28, 30, 32])
        self.assertEqual(zl["a_md"], [34, 36, 38])
        self.assertEqual((zl["a_mgu"], zl["a_mdd"], zl["a_prox"]), ([40], [42], 44))
        self.assertEqual((zl["h_u"], zl["h_up"], zl["h_prox"]), ((24, 25), (26, 27), 28))
        self.assertEqual((zl["w_mgu"], zl["w_mdd"], zl["w_prox"]), ([3, 5], [7], 9))
        for role, rows in (("A", [44, 45]), ("H", [28, 29]), ("W", [9, 10])):
            exp = M.expected_role(role, zl, "P3")
            self.assertEqual(exp["prox_rows"], rows, role)
            self.assertEqual(len(exp["prox_rows"]), 2, role)

    def test_table_slots_singletons_get_pairs_blocks_keep_block_masks(self):
        tabs = self.zl["tabs"]
        self.assertEqual([(t["tag"], t["size"], t["rows"]) for t in tabs],
                         [(3, 256, 1), (4, 65536, 256), (79, 128, 1), (72, 1, 1), (86, 16384, 64), (78, 64, 1)])
        self.assertEqual([t["a_row"] for t in tabs], [46, 49, 561, 564, 567, 695])
        self.assertEqual([t["a_mask"] for t in tabs], [47, 305, 562, 565, 631, 696])
        exp = M.expected_role("A", self.zl, "P1")
        parts = [len(c) for c in exp["claims"][12:]]
        self.assertEqual(parts, [3, 2, 3, 3, 2, 3], "singleton tables are 3-part pair claims, blocks stay 2-part")

    def test_describe_reproduces_the_round16_layout_digest(self):
        text = M.describe(self.zl)
        self.assertEqual(hashlib.sha256(text.encode("utf-8")).hexdigest(), LAYOUT_DIGEST)
        self.assertIn("prox pair=44..46", text)
        self.assertIn("zero-sum pair=(24, 25)", text)
        self.assertIn("kind=block", text)

    def test_claim_and_group_shapes(self):
        for privacy, roles in (("P1", ["A", "H"]), ("P3", ["W", "A", "H"])):
            for role in roles:
                exp = M.expected_role(role, self.zl, privacy)
                self.assertEqual(exp["rows"], M.EXPECTED_ROWS[role], (privacy, role))
                self.assertEqual(exp["group_shape"], M.EXPECTED_GROUP_SHAPE[role], (privacy, role))
        a = M.expected_role("A", self.zl, "P1")
        self.assertEqual(len(a["claims"]), 18)
        self.assertEqual([len(c) for c in a["claims"]], [3] * 13 + [2, 3, 3, 2, 3])
        h = M.expected_role("H", self.zl, "P1")
        self.assertEqual(len(h["claims"]), 12)
        self.assertEqual([len(c) for c in h["claims"]], [4] * 11 + [22])
        self.assertEqual((h["sum_claim"], h["zero_sum_claim"], h["zero_sum_pair"]), (11, 4, (24, 25)))
        w = M.expected_role("W", self.zl, "P3")
        self.assertEqual([len(c) for c in w["claims"]], [3, 3, 3])
        with self.assertRaises(M.RepairedCaptureError):
            M.expected_role("W", self.zl, "P1")

    def test_row_roles_are_recomputed_with_the_source_site_names(self):
        a = M.expected_role("A", self.zl, "P1")["declared_row_roles"]
        self.assertEqual(a[0], ("data", "A.data[0]"))
        self.assertEqual(a[20], ("mask", "a_mf[0].re"))
        self.assertEqual(a[21], ("mask", "a_mf[0].im"))
        self.assertEqual(a[44], ("prox", "a_prox.re"))
        self.assertEqual(a[45], ("prox", "a_prox.im"))
        self.assertEqual(a[46], ("data", "tab[0].multiplicity[0]"))
        self.assertEqual(a[697], ("mask", "tab[5].a_mask[1]"))
        h = M.expected_role("H", self.zl, "P1")["declared_row_roles"]
        self.assertEqual((h[24], h[26], h[28]), (("mask", "h_u.re"), ("mask", "h_up.re"), ("prox", "h_prox.re")))
        w = M.expected_role("W", self.zl, "P3")["declared_row_roles"]
        self.assertEqual((w[3], w[8], w[10]), (("mask", "w_mgu[0].re"), ("mask", "w_mdd[0].im"), ("prox", "w_prox.im")))

    def test_coefficient_tags_follow_the_source_and_the_privacy_mode(self):
        self.assertEqual([M.coefficient_tag("A", 0, i, False) for i in range(3)], ["1-e_f", "e_f", "(e_f)*u"])
        self.assertEqual(M.coefficient_tag("A", 10, 0, False), "1-e_gu")
        self.assertEqual(M.coefficient_tag("A", 10, 0, True), "(1-e_gu2)*(1-e_gu)")
        self.assertEqual(M.coefficient_tag("A", 12, 1, True), "e_tab*ext_0")
        self.assertEqual(M.coefficient_tag("W", 2, 1, True), "e_d2")
        self.assertEqual([M.coefficient_tag("H", 0, i, False) for i in range(4)],
                         ["(1-e_f)", "(1-e_f)*u", "(e_f)", "(e_f)*u"])
        self.assertEqual(M.coefficient_tag("H", 11, 0, False), "public LogUp sum coefficient")

    def test_the_same_rules_reproduce_the_legacy_allocation(self):
        """A control on the recomputation itself: with the legacy (unpaired) schedule
        the identical code gives the row counts of the round-11 legacy captures."""
        legacy = M.zk_layout(32, 16, 16, M.LOG_COLS, M.SHIFTS, mr1=False)
        self.assertEqual((legacy["a_rows"], legacy["h_rows"], legacy["w_rows"]), (681, 1325, 7))
        # the T2 legacy proofs ran with log_cols already clamped to 5 (their captures
        # record params.log_cols = 5): the same rules then give the 5173/10321/28 rows
        # of the round-11 T2 captures.
        tiny = M.zk_layout(2, 16, 16, 5, M.SHIFTS, mr1=False)
        self.assertEqual((tiny["a_rows"], tiny["h_rows"], tiny["w_rows"]), (5173, 10321, 28))


# ---------------------------------------------------------------------------
# 2. refusals: every mutation of a genuine capture that must not be accepted
# ---------------------------------------------------------------------------


@unittest.skipUnless(_captures(), f"repaired captures absent ({CAPTURES})")
class AdapterRefusals(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p1_path, cls.p3_path = _one("P1"), _one("P3")
        with open(cls.p1_path) as fh:
            cls.p1 = json.load(fh)
        with open(cls.p3_path) as fh:
            cls.p3 = json.load(fh)
        cls.td = tempfile.mkdtemp()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.td, ignore_errors=True)

    def _write(self, cap, name=None):
        path = os.path.join(self.td, name or (cap["proof_sha256"] + ".json"))
        with open(path, "w") as fh:
            json.dump(cap, fh)
        return path

    def _mutate(self, fn, base=None, name=None):
        cap = json.loads(json.dumps(base if base is not None else self.p1))
        fn(cap)
        return self._write(cap, name)

    def _refuses(self, fn, msg, base=None, name=None):
        with self.assertRaisesRegex(M.RepairedCaptureError, msg):
            M.RepairedCapture(self._mutate(fn, base=base, name=name))

    def test_the_unmutated_captures_are_accepted(self):
        for path in (self.p1_path, self.p3_path):
            cap = M.RepairedCapture(path)
            self.assertEqual(cap.layout_digest_declared, LAYOUT_DIGEST)
            self.assertEqual(cap.layout_digest_recomputed, LAYOUT_DIGEST)

    def test_refuses_a_changed_header_label(self):
        for fn, msg in (
            (lambda c: c.update(schema=1), "schema"),
            (lambda c: c.update(kind="other"), "kind"),
            (lambda c: c.update(coverage="ffn-v3-function-1"), "coverage"),
            (lambda c: c.update(coverage="ffn-v3-mr1-function-2"), "coverage"),
            (lambda c: c.update(profile="ffn-v3-mr1"), "profile"),
            (lambda c: c.update(transcript_domain="hashline-zk-mr1/ffn-v3-mr1/1"), "transcript_domain"),
            (lambda c: c.update(weight_policy="registered"), "weight_policy"),
            (lambda c: c.update(proof_digest_encoding="envelope"), "proof_digest_encoding"),
            (lambda c: c.update(fully_verified=False), "fully_verified"),
            (lambda c: c.update(privacy="P2"), "privacy"),
            (lambda c: c.update(field_modulus=P - 1), "modulus"),
            (lambda c: c.update(extension_nonresidue=3), "modulus"),
            (lambda c: c.update(slot=0), "slot"),
            (lambda c: c.update(k=1), "slot"),
        ):
            with self.subTest(msg=msg):
                self._refuses(fn, msg)

    def test_refuses_a_changed_source_commit(self):
        self._refuses(lambda c: c.update(source_commit="0" * 40), "source_commit")
        self._refuses(lambda c: c.update(source_commit="cfa46f6"), "source_commit")

    def test_refuses_a_changed_shape_or_shift_set(self):
        self._refuses(lambda c: c.update(shape={"t": 2, "d": 16, "f": 16}), "shape")
        self._refuses(lambda c: c.update(shape={"t": 32, "d": 32, "f": 16}), "shape")
        self._refuses(lambda c: c.update(shifts=[7, 0, 14, 7]), "shifts")
        self._refuses(lambda c: c.pop("shifts"), "shifts")

    def test_refuses_changed_pcs_parameters(self):
        for key, val in (("log_cols", 7), ("inv_rate", 4), ("num_col_checks", 128)):
            with self.subTest(key=key):
                self._refuses(lambda c, k=key, v=val: c["roles"][0]["params"].update({k: v}), "PCS parameters")

    def test_refuses_a_changed_role_set_or_order(self):
        self._refuses(lambda c: c["roles"].pop(), r"are not \['A', 'H'\]")
        self._refuses(lambda c: c["roles"].append(json.loads(json.dumps(c["roles"][0]))), "appears twice")
        self._refuses(lambda c: c["roles"].reverse(), r"are not \['A', 'H'\]")
        self._refuses(lambda c: c["roles"].reverse(), r"are not \['W', 'A', 'H'\]", base=self.p3)
        self._refuses(lambda c: c["roles"][0]["commitment"].update(rows=697), "697 rows")

    def test_refuses_a_missing_pair_row(self):
        """The repair's whole point: a scalar mask site must carry two independent
        base rows.  A claim that lost its second (im) mask part is the legacy form."""
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"].pop(), "missing pair row")
        self._refuses(lambda c: c["roles"][0]["claims"][10]["parts"].pop(), "missing pair row")
        self._refuses(lambda c: c["roles"][0]["claims"][12]["parts"].pop(), "missing pair row")
        # W under P3: the fresh private weight terminals (Wg and Wd)
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"].pop(), "missing pair row", base=self.p3)
        self._refuses(lambda c: c["roles"][0]["claims"][2]["parts"].pop(), "missing pair row", base=self.p3)
        # H's helper pairs and its zero-sum pair
        self._refuses(lambda c: c["roles"][-1]["claims"][0]["parts"].pop(), "missing pair row", base=self.p1)
        self._refuses(lambda c: c["roles"][-1]["claims"][4]["parts"].pop(), "missing pair row", base=self.p1)

    def test_refuses_a_broken_pair_coefficient_or_slice(self):
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][2].update(coefficient=[1, 0]),
                      r"paired mask part is not \(k, k\*u\)")
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][2].update(offset=99328),
                      "recomputed layout")
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][0].update(log_size=8),
                      "recomputed layout")
        self._refuses(lambda c: c["roles"][-1]["claims"][0]["parts"][1].update(coefficient=[1, 0]),
                      r"\(k, k u\) Fp2 pair form")
        self._refuses(lambda c: c["roles"][-1]["claims"][11]["parts"][0].update(coefficient=[2, 0]),
                      "fixed sum-claim coefficient")

    def test_refuses_altered_or_missing_coefficient_tags(self):
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][0].pop("coefficient_tag"), "coefficient_tag missing")
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][0].update(coefficient_tag=""), "coefficient_tag missing")
        self._refuses(lambda c: c["roles"][0]["claims"][0]["parts"][1].update(coefficient_tag="e_dz"), "coefficient_tag")
        # the P1 A gu/d tags must be the P1 ones, not the P3 pair
        self._refuses(lambda c: c["roles"][0]["claims"][10]["parts"][0].update(coefficient_tag="(1-e_gu2)*(1-e_gu)"),
                      "coefficient_tag")

    def test_refuses_altered_row_roles(self):
        self._refuses(lambda c: c["roles"][0]["row_roles"][44].update(kind="mask"), "is not the recomputed")
        self._refuses(lambda c: c["roles"][0]["row_roles"][20].update(site="a_mf[0].im"), "is not the recomputed")
        self._refuses(lambda c: c["roles"][0]["row_roles"].pop(), "row_roles")
        self._refuses(lambda c: c["roles"][0]["row_roles"].__setitem__(5, dict(c["roles"][0]["row_roles"][6])),
                      "more than one entry")
        self._refuses(lambda c: c["roles"][0].pop("row_roles"), "row_roles")

    def test_refuses_a_missing_or_altered_public_constraint(self):
        self._refuses(lambda c: c["roles"][-1].update(public_linear_constraints=[]), "is not the recomputed")
        self._refuses(lambda c: c["roles"][-1]["public_linear_constraints"][0].update(rows=[26, 27]), "is not the recomputed")
        self._refuses(lambda c: c["roles"][0].update(public_linear_constraints=[{"rows": [0]}]), "must be empty")

    def test_refuses_a_layout_description_that_is_not_the_recomputed_one(self):
        def bend(c):
            c["layout_description"] = c["layout_description"].replace("prox pair=44..46", "prox pair=44..45")
            c["layout_digest"] = hashlib.sha256(c["layout_description"].encode()).hexdigest()
        self._refuses(bend, "does not match the layout recomputed")
        self._refuses(lambda c: c.update(layout_digest="0" * 64), r"is not sha256\(layout_description\)")
        self._refuses(lambda c: c.pop("layout_description"), "layout_description missing")

    def test_refuses_broken_pad_and_column_structure(self):
        self._refuses(lambda c: c["roles"][0]["groups"][0].update(vector=c["roles"][0]["groups"][0]["vector"][:256]),
                      r"expected n \+ Q")
        self._refuses(lambda c: c["roles"][0].update(proximity_vector=c["roles"][0]["proximity_vector"][:256]),
                      r"expected n \+ Q")
        self._refuses(lambda c: c["roles"][0].update(q_pad=0), "q_pad")
        self._refuses(lambda c: c["roles"][0].update(q_pad=128), "q_pad")
        self._refuses(lambda c: c["roles"][0]["columns"].pop(), "columns")
        self._refuses(lambda c: c["roles"][0]["columns"][0].update(path=c["roles"][0]["columns"][0]["path"][:10]),
                      "expected 11")
        self._refuses(lambda c: c["roles"][0]["columns"][0].update(index=2048), "index")
        self._refuses(lambda c: c["roles"][0]["columns"][0].update(values=c["roles"][0]["columns"][0]["values"][:10]),
                      "values")
        self._refuses(lambda c: c["roles"][0].update(proximity_rhos=c["roles"][0]["proximity_rhos"][:10]),
                      "proximity_rhos")

    def test_refuses_a_group_whose_vector_does_not_reproduce_its_terminals(self):
        self._refuses(lambda c: c["roles"][0]["groups"][0]["vector"][0].__setitem__(0, 1),
                      "does not reproduce its members' terminals")
        self._refuses(lambda c: c["roles"][0]["groups"][0]["lambdas"][0].__setitem__(0, 1),
                      "does not reproduce its members' terminals")
        def dup_member(c):
            g = c["roles"][0]["groups"][0]
            g["members"].append(g["members"][0])
            g["lambdas"].append(g["lambdas"][0])
        self._refuses(dup_member, "already a member")

    def test_refuses_a_digest_or_name_mismatch(self):
        self._refuses(lambda c: c.update(proof_sha256="a" * 64), "is not the digest name",
                      name=os.path.basename(self.p1_path))
        cap = json.loads(json.dumps(self.p1))
        path = self._write(cap, name="not-a-digest.json")
        with self.assertRaisesRegex(M.RepairedCaptureError, "is not the digest name"):
            M.RepairedCapture(path)
        with self.assertRaisesRegex(M.RepairedCaptureError, "differs from the manifest"):
            M.RepairedCapture(self.p1_path, expected_capture_sha256="0" * 64)

    def test_refuses_malformed_json_and_non_integer_field_values(self):
        bad = os.path.join(self.td, "trunc.json")
        with open(self.p1_path, "rb") as fh:
            raw = fh.read()
        with open(bad, "wb") as fh:
            fh.write(raw[: len(raw) // 2])
        with self.assertRaisesRegex(M.RepairedCaptureError, "malformed JSON"):
            M.RepairedCapture(bad, require_digest_name=False)
        for value in ("12", 1.5, True, P, -1):
            with self.subTest(value=value):
                self._refuses(lambda c, v=value: c["roles"][0]["claims"][0]["parts"][0]["coefficient"].__setitem__(0, v),
                              "not an integer")


# ---------------------------------------------------------------------------
# 3. a legacy schema-1 capture wearing the repaired label
# ---------------------------------------------------------------------------


@unittest.skipUnless(os.path.isdir(LEGACY) and _captures(), "legacy and/or repaired captures absent")
class LegacySchema1Refused(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.td = tempfile.mkdtemp()
        with open(_one("P3")) as fh:
            good = json.load(fh)
        cls.label = {k: good[k] for k in ("schema", "kind", "coverage", "profile", "transcript_domain",
                                          "source_commit", "layout_digest", "layout_description", "shifts",
                                          "weight_policy", "slot", "k", "proof_digest_encoding")}
        cls.legacy_t32_p3 = None
        for name in sorted(os.listdir(LEGACY)):
            if not name.endswith(".json"):
                continue
            with open(os.path.join(LEGACY, name)) as fh:
                cap = json.load(fh)
            if cap["shape"]["t"] == 32 and cap["privacy"] == "P3":
                cls.legacy_t32_p3 = cap
                break

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.td, ignore_errors=True)

    def _write(self, cap):
        path = os.path.join(self.td, cap["proof_sha256"] + ".json")
        with open(path, "w") as fh:
            json.dump(cap, fh)
        return path

    def test_partial_relabel_is_refused_on_the_profile(self):
        cap = json.loads(json.dumps(self.legacy_t32_p3))
        cap["schema"] = 2
        cap["coverage"] = M.COVERAGE
        with self.assertRaisesRegex(M.RepairedCaptureError, "profile"):
            M.RepairedCapture(self._write(cap))

    def test_full_relabel_is_refused_by_the_layout_recomputation(self):
        """Every header field forged, including the genuine layout_description and its
        digest: the capture is still refused, because the recomputed repaired layout
        has 11 W / 698 A / 1326 H rows and the legacy commitment does not."""
        cap = json.loads(json.dumps(self.legacy_t32_p3))
        cap.update(self.label)
        self.assertEqual(cap["layout_digest"], LAYOUT_DIGEST)
        with self.assertRaisesRegex(M.RepairedCaptureError, r"commitment has 7 rows.*layout has 11"):
            M.RepairedCapture(self._write(cap))

    def test_every_legacy_capture_in_the_round11_set_is_refused(self):
        refused = 0
        for name in sorted(os.listdir(LEGACY)):
            if not name.endswith(".json"):
                continue
            with self.assertRaises(M.RepairedCaptureError):
                M.RepairedCapture(os.path.join(LEGACY, name))
            refused += 1
        self.assertGreaterEqual(refused, 10)


# ---------------------------------------------------------------------------
# 4. the legacy attack, kept as a positive control
# ---------------------------------------------------------------------------


@unittest.skipUnless(os.path.isdir(LEGACY), f"legacy captures absent ({LEGACY})")
class LegacyPositiveControl(unittest.TestCase):
    """Fable's archived tool, untouched, must still reproduce FA7's legacy numbers on
    the legacy captures: A = 2n + 4, P3 W = 2n + 2, H = 2, T32 Wd fully recovered."""

    @classmethod
    def setUpClass(cls):
        cls.path = None
        for name in sorted(os.listdir(LEGACY)):
            if not name.endswith(".json"):
                continue
            p = os.path.join(LEGACY, name)
            with open(p) as fh:
                cap = json.load(fh)
            if cap["shape"]["t"] == 32 and cap["privacy"] == "P3":
                cls.path = p
                break

    def test_legacy_t32_p3_still_gives_2n_plus_4_and_2n_plus_2_and_the_Wd_plane(self):
        cap = C.Capture(self.path)
        self.assertEqual([r.role for r in cap.roles], ["W", "A", "H"])
        got = {}
        for obs in cap.roles:
            model = C.RoleModel(obs)
            a = model.analyze(planes=(obs.role == "W"), plane_columns=())
            got[obs.role] = a["joint"]["disclosed_total"]
            if obs.role == "W":
                self.assertTrue(a["planes"]["Wd[0][0]"]["fully_recovered"], "the legacy T32 Wd plane must recover")
                self.assertEqual(a["planes"]["Wd[0][0]"]["isolated_disclosed_dim"], 256)
        n = 256
        self.assertEqual(got["A"], 2 * n + 4)
        self.assertEqual(got["W"], 2 * n + 2)
        self.assertEqual(got["H"], 2)

    def test_the_legacy_singleton_elimination_still_recovers_a_whole_row(self):
        cap = C.Capture(self.path)
        w = cap.roles[0]
        gi = [i for i, g in enumerate(w.groups) if len(g["members"]) == 1][0]
        rec = C.singleton_functionals(w, gi)
        self.assertEqual(rec["plane"], "Wd[0][0]")
        self.assertEqual(rec["rows_per_functional"], 1)
        self.assertIn("recovered_row_sha256", rec)
        self.assertEqual(rec["recovered_entries"], 256)


# ---------------------------------------------------------------------------
# 5. the four repaired captures
# ---------------------------------------------------------------------------


@unittest.skipUnless(_captures() and os.path.exists(MANIFEST), f"repaired captures / manifest absent ({CAPTURES})")
class RepairedCaptures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.man = M.load_manifest(MANIFEST)

    def test_manifest_binds_four_captures_two_per_mode_at_the_pinned_commit(self):
        self.assertEqual(self.man["capture_source_commit"], M.SOURCE_COMMIT)
        self.assertEqual(len(self.man["entries"]), 4)
        self.assertEqual(sorted(e["privacy"] for e in self.man["entries"].values()), ["P1", "P1", "P3", "P3"])
        self.assertEqual({e["layout_digest"] for e in self.man["entries"].values()}, {LAYOUT_DIGEST})
        for stem, e in self.man["entries"].items():
            path = os.path.join(CAPTURES, stem + ".json")
            self.assertTrue(os.path.exists(path), stem)
            self.assertEqual(M.sha256_file(path), e["sha256"], stem)
            self.assertEqual(os.path.getsize(path), e["bytes"], stem)

    def test_all_four_parse_with_the_recomputed_layout_and_expected_roles(self):
        seen = []
        for path in _captures():
            cap = M.RepairedCapture(path, expected_capture_sha256=self.man["entries"][Path(path).stem]["sha256"])
            seen.append(cap.privacy)
            self.assertEqual([r.role for r in cap.roles], M.ROLE_ORDER[cap.privacy])
            self.assertEqual(cap.layout_digest_recomputed, LAYOUT_DIGEST)
            for ro in cap.roles:
                self.assertEqual(ro.rows, M.EXPECTED_ROWS[ro.role])
                self.assertEqual([len(g["members"]) for g in ro.groups], M.EXPECTED_GROUP_SHAPE[ro.role])
                self.assertEqual(sum(1 for r in range(ro.rows) if ro.row_kind[r] == "prox"), 2)
                self.assertEqual(ro.q_pad, 256)
                for g in ro.groups:
                    self.assertEqual(len(g["vector"]), ro.n + 256)
                self.assertEqual(len(ro.prox_vector), ro.n + 256)
        self.assertEqual(sorted(seen), ["P1", "P1", "P3", "P3"])

    def test_joint_model_A_and_W_disclose_zero_and_H_only_its_public_identity(self):
        for path in _captures():
            cap = M.RepairedCapture(path)
            for ro in cap.roles:
                with self.subTest(proof=cap.proof_sha256[:12], role=ro.role):
                    rec = M.analyze_role(ro, planes=True, plane_columns=())
                    a = rec["analysis"]
                    self.assertEqual(a["per_column"]["disclosed_per_column"], 0)
                    if ro.role == "H":
                        self.assertEqual(a["joint"]["disclosed_total"], 2)
                        self.assertEqual(rec["h_zero_sum"]["disclosed_without_zero_sum_constraint"], 0)
                        self.assertTrue(rec["h_zero_sum"]["residual_equals_public_logup_identity"])
                        for pl in a["planes"].values():
                            self.assertEqual(pl["isolated_disclosed_dim"], 0)
                            self.assertEqual(pl["projected_disclosed_dim"], 2)
                    else:
                        self.assertEqual(a["joint"]["disclosed_total"], 0)
                        for pl in a["planes"].values():
                            self.assertEqual(pl["projected_disclosed_dim"], 0)
                            self.assertEqual(pl["isolated_disclosed_dim"], 0)
                            self.assertFalse(pl["fully_recovered"])

    def test_the_legacy_singleton_elimination_no_longer_applies(self):
        """FA7 section 7 recovered X, h16 and the whole T32 Wd plane from the legacy
        captures through the L_b projection of a singleton group with ONE base mask row.
        Every singleton group of the repaired captures now carries a mask pair (H's
        zero-sum group carries two pairs), so that projection has no mask-free form."""
        cap = M.RepairedCapture(_one("P3"))
        seen = 0
        for ro in cap.roles:
            rec = M.analyze_role(ro, planes=False)
            for entry in rec["legacy_singleton_attack"]:
                seen += 1
                self.assertFalse(entry.get("applicable", True), (ro.role, entry))
                self.assertGreaterEqual(entry["mask_parts"], 2, (ro.role, entry))
                if ro.role in ("A", "W"):
                    self.assertEqual(entry["mask_parts"], 2, (ro.role, entry))
        self.assertEqual(seen, 5, "A's X at p2 and h16 at p5, W's Wd, H's hz group and H's zero-sum group "
                                  "(H's value-0 sum group has no point and is not of this form)")

    @unittest.skipUnless(PUBLISHED_MANIFEST.exists(), "results/zk60_round16_validation.json not published yet")
    def test_published_validation_record_agrees_with_the_interim_one(self):
        """The published record's own source_commit is the head the validation ran at,
        which is later than the implementation the captures came from; the field that
        must equal the pin is capture_source_commit."""
        pub = M.load_manifest(str(PUBLISHED_MANIFEST))
        interim = M.load_manifest(INTERIM_MANIFEST)
        self.assertEqual(pub["capture_source_commit"], M.SOURCE_COMMIT)
        x = M.cross_check_manifests(pub, interim)
        self.assertTrue(x["same_capture_set"], x)
        self.assertTrue(x["same_capture_source_commit"], x)
        self.assertTrue(x["all_entries_agree"], x)
        for stem, e in pub["entries"].items():
            path = os.path.join(CAPTURES, stem + ".json")
            if os.path.exists(path):
                self.assertEqual(M.sha256_file(path), e["sha256"], stem)
                self.assertEqual(os.path.getsize(path), e["bytes"], stem)


# ---------------------------------------------------------------------------
# 6. the delivered results are bound to these tools and these files
# ---------------------------------------------------------------------------


class ResultsBinding(unittest.TestCase):
    @unittest.skipUnless(RESULTS.exists(), "results/zk60_opus_repaired_capture_analysis.json absent")
    def test_analysis_results_are_bound_to_this_tool_and_these_captures(self):
        with open(RESULTS) as fh:
            rep = json.load(fh)
        for name, path in (("zk60_opus_repaired_capture.py", ROOT / "scripts/zk60_opus_repaired_capture.py"),
                           ("zk60_fable_joint_capture.py", ROOT / "scripts/zk60_fable_joint_capture.py"),
                           ("zk60_fable_joint_rank.py", ROOT / "scripts/zk60_fable_joint_rank.py")):
            self.assertEqual(rep["tool_sha256"][name], M.sha256_file(str(path)), name)
        self.assertEqual(rep["source_commit"], M.SOURCE_COMMIT)
        self.assertEqual(rep["coverage"], M.COVERAGE)
        self.assertEqual(rep["refused"], [])
        self.assertEqual(len(rep["captures"]), 4)
        for c in rep["captures"]:
            path = os.path.join(CAPTURES, c["file"])
            if os.path.exists(path):
                self.assertEqual(M.sha256_file(path), c["file_sha256"], c["file"])
            self.assertEqual(c["layout_digest"], LAYOUT_DIGEST)
        for case in rep["cases"]:
            want = 2 if case["role"] == "H" else 0
            self.assertEqual(case["analysis"]["joint"]["disclosed_total"], want, (case["file"], case["role"]))
            self.assertEqual(case["analysis"]["per_column"]["disclosed_per_column"], 0, (case["file"], case["role"]))
        self.assertTrue(rep["target_met"]["all_roles_meet_the_expected_target"])

    @unittest.skipUnless(PREFLIGHT.exists(), "results/zk60_opus_capture_preflight.json absent")
    def test_preflight_results_are_bound_and_all_checks_pass(self):
        with open(PREFLIGHT) as fh:
            rep = json.load(fh)
        self.assertEqual(rep["tool_sha256"]["zk60_opus_repaired_capture.py"],
                         M.sha256_file(str(ROOT / "scripts/zk60_opus_repaired_capture.py")))
        self.assertEqual(rep["recomputed_layout"]["sha256"], LAYOUT_DIGEST)
        self.assertEqual(rep["summary"]["files_parsed"], 4)
        self.assertEqual(rep["summary"]["files_refused"], 0)
        self.assertEqual(rep["summary"]["checks_failed"], 0)
        self.assertTrue(rep["summary"]["all_pass"])


if __name__ == "__main__":
    unittest.main()
