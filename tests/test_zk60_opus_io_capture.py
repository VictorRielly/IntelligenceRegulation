#!/usr/bin/env python3
"""O8 tests for the schema-3 IO capture adapter and its joint observation model.

Reviewer: Opus 5, independent reviewer, 2026-09-09 session.  Capture producer pin
1f0ff3680c4cda88f1744343e24eb93cdddfcba4; review worktree branch zk60-fable-review.

Order of business (the dispatch requires the refusals to exist before the analysis):
  1. LayoutRecomputation   -- the IO layout, endpoint geometry, claim mapping, row roles,
     coefficient tags and layout digest are recomputed from the source rules alone
     (no capture file) and cross-checked between two independent derivations.
  2. AdapterRefusals       -- the negative controls the dispatch names: a missing IO group
     or mask row, incorrect endpoint aliases, a changed role order, an altered source or
     profile, narrowed M columns, malformed fields, and more.
  3. LegacyAndDraftRefused -- legacy schema-1 captures and the superseded `/1` draft label
     are refused by the recomputation rather than by their label.
  4. LegacyPositiveControl -- Fable's archived legacy tool still reproduces its numbers.
  5. JointModel            -- the generalised model reproduces the inherited RoleModel on a
     single commitment, agrees with an explicit uncompressed per-column matrix, refuses a
     mask alias, and DETECTS the legacy single-mask leak when the endpoint pair is ablated.
  6. IoCaptures            -- the four real triples parse and give the joint numbers.
  7. ResultsBinding        -- the delivered analysis JSON is bound to these tools and files.

    python3 -m unittest discover -s tests -p 'test_zk60_opus_io_capture.py' -v
"""
import copy
import hashlib
import importlib.util
import json
import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("opus_io_capture", ROOT / "scripts/zk60_opus_io_capture.py")
M = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(M)
C, R, O, IOL = M.C, M.R, M.O, M.IOL
P, ONE, ZERO, U = M.P, M.ONE, M.ZERO, M.U

CAPTURES = "/tmp/zk60-round19/captures"
LEGACY = "/tmp/zk60-round11/final-observations"
MANIFESTS = [ROOT / "results/zk60_round19_validation.json",
             Path("/home/victor/IntelligenceRegulation/results/zk60_round19_validation.json")]
MANIFEST = next((p for p in MANIFESTS if p.exists()), MANIFESTS[0])
RESULTS = ROOT / "results/zk60_opus_io_capture_analysis.json"

# the layout digest of the round-19 `/2` captures, recomputed from the source rules
LAYOUT_DIGEST = "b7d1388565757d503f0f814dacab351f50bf741d82592a9364cb412cacb012db"


def _captures():
    if not os.path.isdir(CAPTURES):
        return []
    return sorted(os.path.join(CAPTURES, f) for f in os.listdir(CAPTURES) if f.endswith(".json"))


def _one(privacy):
    for p in _captures():
        with open(p) as fh:
            head = fh.read(1 << 18)
        if f'"privacy":"{privacy}"' in head:
            return p
    return None


def _raw(path):
    with open(path, "rb") as fh:
        return M.load_capture_json(fh.read())


# ---------------------------------------------------------------------------
# 1. the layout, recomputed from the source rules only
# ---------------------------------------------------------------------------


class LayoutRecomputation(unittest.TestCase):
    def setUp(self):
        self.geo = M.io_layout()

    def test_a_grows_by_exactly_four_mask_rows_at_the_end(self):
        self.assertEqual(self.geo["a_base_rows"], 698)
        self.assertEqual(self.geo["a_rows"], 702)
        self.assertEqual(self.geo["io_heads"], [698, 700])
        self.assertEqual(self.geo["io_mask_rows"], [698, 699, 700, 701])
        # the IO rows may not alias any existing site
        base = set(O.a_mask_rows(self.geo["zl"])) | {self.geo["zl"]["a_prox"], self.geo["zl"]["a_prox"] + 1}
        self.assertFalse(base & set(self.geo["io_mask_rows"]))

    def test_x_and_z16_slices_are_the_real_planes(self):
        self.assertEqual(self.geo["x_slice"], {"offset": 3584, "log_size": 9})
        self.assertEqual(self.geo["z_slice"], {"offset": 4096, "log_size": 9})
        self.assertEqual(self.geo["x_rows"], [14, 15])
        self.assertEqual(self.geo["z_rows"], [16, 17])

    def test_endpoint_geometry(self):
        ep = self.geo["endpoint"]
        self.assertEqual((ep["values"], ep["log_len"], ep["data_rows"], ep["rows"]), (512, 9, 2, 7))
        self.assertEqual(ep["terminal_mask_pair"], [2, 3])
        self.assertEqual(ep["prox_rows"], [4, 5, 6])
        self.assertEqual(ep["reserved_prox_mask_row"], 4)
        self.assertEqual(ep["claim_slice"], {"offset": 0, "log_size": 9})
        self.assertEqual(ep["mask_slices"], [(512, 8), (768, 8)])
        self.assertEqual((ep["cfs_spec"], ep["cfs_coefficients"]), ([10, 2], 22))

    def test_two_independent_derivations_agree(self):
        rm = IOL.a_row_map(M.SHIFTS)
        self.assertEqual((rm["base_rows"], rm["a_rows"], rm["a_io"]), (698, 702, [698, 700]))
        self.assertEqual(IOL.endpoint_plane()["commitment_rows"], 7)
        self.assertEqual(IOL.io_frame_len(private=False), 5029244)
        self.assertEqual(IOL.io_frame_len(private=True), 5066204)

    def test_claim_and_group_shapes(self):
        for privacy, roles in M.ROLE_ORDER.items():
            for role in roles:
                exp = M.expected_role_io(role, self.geo, privacy)
                self.assertEqual(exp["rows"], M.EXPECTED_ROWS[role], role)
                self.assertEqual(exp["group_shape"], M.EXPECTED_GROUP_SHAPE[role], role)
                self.assertEqual(sum(exp["group_shape"]), len(exp["claims"]), role)
        a = M.expected_role_io("A", self.geo, "P1")
        self.assertEqual(len(a["claims"]), 20)
        self.assertEqual(a["io_claims"], [18, 19])
        self.assertEqual([p[:2] for p in a["claims"][18]], [(3584, 9), (698 * 256, 8), (699 * 256, 8)])
        self.assertEqual([p[:2] for p in a["claims"][19]], [(4096, 9), (700 * 256, 8), (701 * 256, 8)])
        self.assertEqual(a["coefficient_tags"][18], ["1-e_io", "e_io", "e_io*u"])

    def test_endpoint_row_roles_and_claim(self):
        e = M.expected_role_io("Input", self.geo, "P1")
        self.assertEqual(e["declared_row_roles"], [
            ("data", "Input.data[0]"), ("data", "Input.data[1]"),
            ("mask", "Input.mask[2]"), ("mask", "Input.mask[3]"),
            ("prox", "Input.prox[4]"), ("prox", "Input.prox[5]"), ("prox", "Input.prox[6]")])
        self.assertEqual([p[:2] for p in e["claims"][0]], [(0, 9), (512, 8), (768, 8)])

    def test_layout_description_and_digest(self):
        d = M.describe_io(self.geo["zl"], self.geo["a_rows"])
        self.assertEqual(hashlib.sha256(d.encode()).hexdigest(), LAYOUT_DIGEST)
        self.assertIn("A rows=702", d)
        self.assertTrue(d.splitlines()[1].endswith("698, 699, 700, 701] prox pair=44..46"))
        # the source's own first line still names the BASE profile: a labelling wrinkle the
        # report records, not a geometry difference
        self.assertTrue(d.startswith("ffn-v3-mr1-fresh-poc/1:"))

    def test_the_base_profile_layout_is_unchanged_by_the_io_rows(self):
        base = O.describe(self.geo["zl"]).splitlines()
        io = M.describe_io(self.geo["zl"], self.geo["a_rows"]).splitlines()
        self.assertEqual(len(base), len(io))
        for i, (b, x) in enumerate(zip(base, io)):
            if i != 1:
                self.assertEqual(b, x, f"line {i} changed")


# ---------------------------------------------------------------------------
# 2. the refusals the dispatch names
# ---------------------------------------------------------------------------


@unittest.skipUnless(_captures(), f"IO captures absent ({CAPTURES})")
class AdapterRefusals(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p1 = _one("P1")
        cls.p3 = _one("P3")
        cls.raw = _raw(cls.p1)
        cls.ai = next(i for i, r in enumerate(cls.raw["roles"]) if r["role"] == "A")
        cls.ii = next(i for i, r in enumerate(cls.raw["roles"]) if r["role"] == "Input")

    def _mutate(self, keys, value, raw=None):
        cand = copy.deepcopy(raw if raw is not None else self.raw)
        cur = cand
        for k in keys[:-1]:
            cur = cur[k]
        cur[keys[-1]] = value
        with self.assertRaises(C.CaptureError):
            M.IoCapture(self.p1, require_digest_name=False, require_siblings=False, raw=cand)

    def test_the_unmutated_captures_are_accepted(self):
        for p in _captures():
            cap = M.IoCapture(p)
            self.assertEqual(cap.layout_digest_declared, cap.layout_digest_recomputed)
            self.assertEqual(cap.layout_digest_recomputed, LAYOUT_DIGEST)

    def test_refuses_an_altered_source_or_profile(self):
        self._mutate(["source_commit"], "0" * 40)
        self._mutate(["source_commit"], "1f0ff36")
        self._mutate(["profile"], M.DRAFT_PROFILE)
        self._mutate(["coverage"], "ffn-v3-mr1-fresh-poc-function-1")
        self._mutate(["transcript_domain"], "hashline-zk-mr1/" + M.DRAFT_PROFILE)
        self._mutate(["schema"], 2)
        self._mutate(["proof_digest_encoding"], "legacy logical payload")

    def test_refuses_a_capture_that_claims_a_privacy_result(self):
        self._mutate(["privacy_review_complete"], True)
        self._mutate(["fully_verified"], False)

    def test_refuses_a_missing_io_group(self):
        self._mutate(["roles", self.ai, "groups"], self.raw["roles"][self.ai]["groups"][:-1])
        self._mutate(["roles", self.ai, "groups"], self.raw["roles"][self.ai]["groups"][:5])

    def test_refuses_a_missing_io_mask_row(self):
        a = self.raw["roles"][self.ai]
        self._mutate(["roles", self.ai, "claims", 18, "parts"], a["claims"][18]["parts"][:2])
        self._mutate(["roles", self.ai, "commitment", "rows"], 700)
        self._mutate(["roles", self.ai, "commitment", "rows"], 698)
        e = self.raw["roles"][self.ii]
        self._mutate(["roles", self.ii, "claims", 0, "parts"], e["claims"][0]["parts"][:2])
        self._mutate(["roles", self.ii, "commitment", "rows"], 6)

    def test_refuses_incorrect_endpoint_aliases(self):
        # A's IO claim must open the real X / z16 plane, and the endpoint its own row 0
        self._mutate(["roles", self.ai, "claims", 18, "parts", 0, "offset"], 4096)
        self._mutate(["roles", self.ai, "claims", 19, "parts", 0, "offset"], 3584)
        self._mutate(["roles", self.ai, "claims", 18, "parts", 0, "offset"], 0)
        self._mutate(["roles", self.ii, "claims", 0, "parts", 0, "offset"], 512)
        self._mutate(["roles", self.ii, "claims", 0, "parts", 0, "log_size"], 8)
        # the two claims must share one evaluation point and one coefficient split
        arg = self.raw["io_arguments"][0]
        self._mutate(["roles", self.ii, "claims", 0, "parts", 0, "point"],
                     self.raw["io_arguments"][1]["rho"][:9])
        self._mutate(["io_arguments", 0, "terminals", 1], arg["terminals"][0])
        self._mutate(["io_arguments", 0, "rho", 9], [0, 0])

    def test_refuses_a_changed_role_order_or_a_missing_endpoint(self):
        self._mutate(["roles"], self.raw["roles"][:-2] + self.raw["roles"][-2:][::-1])
        self._mutate(["roles"], self.raw["roles"][:-1])
        self._mutate(["roles"], self.raw["roles"] + [self.raw["roles"][-1]])
        self._mutate(["opening_order"], ["M", "W", "A", "H", "Output", "Input"])

    def test_refuses_an_endpoint_mask_row_relabelled_as_data(self):
        self._mutate(["roles", self.ii, "row_roles", 3, "kind"], "data")
        self._mutate(["roles", self.ii, "row_roles", 4, "kind"], "mask")
        self._mutate(["roles", self.ii, "row_roles", 0, "site"], "Input.data[9]")

    def test_refuses_narrowed_m_columns_and_a_narrowed_slot_schedule(self):
        m = self.raw["mask"]
        self._mutate(["mask", "columns", 0, "values"], m["columns"][0]["values"][:16])
        self._mutate(["mask", "specs"], m["specs"][:6])
        self._mutate(["mask", "specs"], m["specs"][:7] + [[9, 2]])
        self._mutate(["mask", "functionals"], m["functionals"][:-1])
        self._mutate(["mask", "functionals", 0, "terms", 0, "weights"], [])
        self._mutate(["mask", "columns", 0, "index"], 4096)
        self._mutate(["mask", "proximity_rhos"], m["proximity_rhos"][:-1])

    def test_refuses_malformed_fields(self):
        self._mutate(["roles", self.ai, "columns", 0, "values", 0], P)
        self._mutate(["roles", self.ai, "columns", 0, "values", 0], -1)
        self._mutate(["roles", self.ai, "groups", 0, "vector", 0, 0], True)
        self._mutate(["roles", self.ai, "groups", 0, "vector"],
                     self.raw["roles"][self.ai]["groups"][0]["vector"][:-1])
        self._mutate(["roles", self.ai, "proximity_vector"],
                     self.raw["roles"][self.ai]["proximity_vector"][:-1])
        self._mutate(["expected_policy"], self.raw["expected_policy"][:-1])
        self._mutate(["expected_policy_sha256"], "0" * 64)
        self._mutate(["field_modulus"], P + 1)
        for text in ('{"x":1,"x":2}', '{"x":1.0}', '{"x":NaN}', "[1,2]", "{"):
            with self.assertRaises(C.CaptureError):
                M.load_capture_json(text.encode())

    def test_refuses_broken_transcript_joins_and_group_equations(self):
        self._mutate(["mask", "after", "next"], [0, 0])
        self._mutate(["roles", self.ai, "groups", 5, "vector", 0], [0, 0])
        self._mutate(["io_arguments", 1, "slot"], 6)

    def test_refuses_a_missing_or_wrong_sibling_artifact(self):
        cap = M.IoCapture(self.p1)
        self.assertEqual(cap.siblings["receipt_sha256"], cap.proof_sha256)
        self._mutate(["proof_bytes"], 5029245)
        # a P3 frame length on a P1 capture is refused by the independent wire model
        self._mutate(["proof_bytes"], 5066204)

    def test_the_full_mutation_battery_rejects_everything(self):
        for path in (self.p1, self.p3):
            out = M.mutation_controls(path)
            self.assertTrue(out["all_rejected"], [c for c in out["controls"] if not c["rejected"]])
            self.assertGreaterEqual(out["count"], 30)


# ---------------------------------------------------------------------------
# 3. legacy and superseded-draft captures
# ---------------------------------------------------------------------------


@unittest.skipUnless(os.path.isdir(LEGACY), f"legacy captures absent ({LEGACY})")
class LegacyRefused(unittest.TestCase):
    def test_every_legacy_capture_is_refused_by_this_adapter(self):
        for name in sorted(os.listdir(LEGACY)):
            if not name.endswith(".json"):
                continue
            with self.assertRaises(C.CaptureError):
                M.IoCapture(os.path.join(LEGACY, name), require_digest_name=False,
                            require_siblings=False)

    @unittest.skipUnless(_captures(), "IO captures absent")
    def test_a_fully_relabelled_legacy_capture_is_refused_by_the_recomputation(self):
        name = next(n for n in sorted(os.listdir(LEGACY)) if n.endswith(".json"))
        raw = _raw(os.path.join(LEGACY, name))
        raw.update({"schema": M.SCHEMA, "kind": M.KIND, "coverage": M.COVERAGE,
                    "profile": M.PROFILE, "transcript_domain": M.TRANSCRIPT_DOMAIN,
                    "source_commit": M.SOURCE_COMMIT, "weight_policy": M.WEIGHT_POLICY,
                    "proof_digest_encoding": M.PROOF_DIGEST_ENCODING,
                    "privacy_review_complete": False})
        with self.assertRaises(C.CaptureError):
            M.IoCapture(_one("P1"), require_digest_name=False, require_siblings=False, raw=raw)


@unittest.skipUnless(os.path.isdir(LEGACY), f"legacy captures absent ({LEGACY})")
class LegacyPositiveControl(unittest.TestCase):
    """The archived legacy disclosure must still reproduce: a model that cannot see the
    old leak proves nothing about the new layout."""

    def test_legacy_tool_still_reports_2n_plus_4_and_2n_plus_2_and_h_identity(self):
        out = M.legacy_control(LEGACY, log=lambda *a: None)
        self.assertTrue(out["all_legacy_captures_refused_by_the_adapter"])
        self.assertEqual(out["legacy_tool_reproduces_fa7"], {"A": [516], "H": [2], "W": [514]})
        self.assertTrue(out["reproduced"])
        recovered = [c for c in out["legacy_tool_cases"] if c.get("fully_recovered_planes")]
        self.assertTrue(recovered, "the legacy T32 Wd plane must still be fully recovered")


# ---------------------------------------------------------------------------
# 4. the joint model
# ---------------------------------------------------------------------------


@unittest.skipUnless(_captures(), f"IO captures absent ({CAPTURES})")
class JointModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cap = M.IoCapture(_one("P1"))
        cls.obs = {r.role: r for r in cls.cap.roles}

    def test_reproduces_the_inherited_role_model_on_one_commitment(self):
        for role in ("A", "H", "Input", "Output"):
            out = M.joint_model_matches_role_model(self.obs[role])
            self.assertTrue(out["agree"], out)

    def test_agrees_with_an_explicit_uncompressed_per_column_matrix(self):
        jm = M.JointModel([self.obs["A"], self.obs["Input"], self.obs["Output"]], M.ALIAS_PAIRS)
        a = jm.analyze(planes=False)
        e = jm.explicit_per_column()
        self.assertEqual(e["rank_mask"], a["per_column"]["rank_mask"])
        self.assertEqual(e["rank_joint"], a["per_column"]["rank_joint"])
        self.assertEqual(e["disclosed_per_column"], a["per_column"]["disclosed_per_column"])

    def test_the_alias_merges_exactly_four_rows_and_only_data_rows(self):
        jm = M.JointModel([self.obs["A"], self.obs["Input"], self.obs["Output"]], M.ALIAS_PAIRS)
        self.assertEqual(jm.rows, 702 + 7 + 7 - 4)
        self.assertEqual(jm.merged_of[(0, 14)], jm.merged_of[(1, 0)])
        self.assertEqual(jm.merged_of[(0, 15)], jm.merged_of[(1, 1)])
        self.assertEqual(jm.merged_of[(0, 16)], jm.merged_of[(2, 0)])
        self.assertEqual(jm.merged_of[(0, 17)], jm.merged_of[(2, 1)])
        self.assertNotEqual(jm.merged_of[(0, 698)], jm.merged_of[(1, 2)])
        with self.assertRaises(C.CaptureError):
            M.JointModel([self.obs["A"], self.obs["Input"]], [(("A", 698), ("Input", 2))])

    def test_one_block_coordinate_pair_per_group_and_per_proximity_vector(self):
        jm = M.JointModel([self.obs["A"], self.obs["Input"], self.obs["Output"]], M.ALIAS_PAIRS)
        self.assertEqual(jm.G, 7 + 1 + 1)
        self.assertEqual(jm.nb, 2 * 9 + 2 * 3)
        self.assertEqual(jm.K, 20 + 1 + 1)

    def test_the_ablation_control_detects_the_legacy_single_mask_leak(self):
        for role in ("Input", "Output"):
            out = M.endpoint_ablation_control(self.obs[role])
            self.assertEqual(out["paired_disclosed_total"], 0)
            self.assertEqual(out["single_mask_disclosed_per_column"], 1)
            self.assertEqual(out["single_mask_disclosed_total"], 256)
            self.assertTrue(out["control_detects_the_legacy_leak"])

    def test_the_proximity_mask_rows_span_both_base_dimensions(self):
        for ro in self.cap.roles:
            self.assertEqual(ro.prox_mask_span()["fp_rank_of_their_rhos"], 2, ro.role)

    def test_h_zero_sum_is_carried_into_the_joint_model(self):
        private = list(self.cap.roles)
        jm = M.JointModel(private, M.ALIAS_PAIRS)
        self.assertEqual(len(jm.extras), 1)
        self.assertEqual(jm.extras[0]["name"], "zero_sum(u)")
        self.assertEqual(len(M.JointModel(private, M.ALIAS_PAIRS, zero_sum=False).extras), 0)


# ---------------------------------------------------------------------------
# 5. the real captures
# ---------------------------------------------------------------------------


@unittest.skipUnless(_captures() and MANIFEST.exists(), f"IO captures / manifest absent")
class IoCaptures(unittest.TestCase):
    def test_manifest_binds_four_triples_two_per_mode_at_the_pinned_commit(self):
        man = M.load_manifest(str(MANIFEST))
        self.assertEqual(man["source_commit"], M.SOURCE_COMMIT)
        self.assertEqual(man["capture_source_commit"], M.SOURCE_COMMIT)
        self.assertEqual(man["counts"], {"P1": 2, "P3": 2})
        self.assertEqual(len(man["entries"]), 4)
        self.assertIs(man["full_privacy_review_complete"], False)

    def test_preflight_passes_every_check(self):
        rep = M.preflight(CAPTURES, str(MANIFEST), None, log=lambda *a: None)
        bad = [c for c in rep["checks"] if not c["pass"]]
        self.assertEqual(bad, [])
        self.assertTrue(rep["pass"])
        self.assertGreaterEqual(len(rep["checks"]), 40)

    def test_all_four_parse_with_the_recomputed_layout_and_expected_roles(self):
        modes = {"P1": 0, "P3": 0}
        for p in _captures():
            cap = M.IoCapture(p)
            modes[cap.privacy] += 1
            self.assertEqual([r.role for r in cap.roles], M.ROLE_ORDER[cap.privacy])
            for r in cap.roles:
                self.assertEqual(r.rows, M.EXPECTED_ROWS[r.role])
                self.assertEqual([len(g["members"]) for g in r.groups],
                                 M.EXPECTED_GROUP_SHAPE[r.role])
            self.assertEqual(cap.mask["functionals"], 14)
            self.assertEqual(len(cap.mask["specs"]), 8)
            self.assertEqual(cap.mask["specs"][6:], [[10, 2], [10, 2]])
            self.assertEqual(cap.mask["column_rows"], 20)
            self.assertEqual(cap.mask["openings_per_slot"]["6"], 2)
            self.assertEqual(cap.mask["openings_per_slot"]["7"], 2)
            self.assertEqual(len(cap.io_arguments), 2)
            self.assertEqual(cap.expected_policy["bytes"], 112)
            self.assertEqual(cap.transcript_chain[0], "M")
            self.assertEqual(cap.transcript_chain[-2:], ["Input", "Output"])
        self.assertEqual(modes, {"P1": 2, "P3": 2})

    def test_joint_model_numbers_on_every_capture(self):
        for p in _captures():
            cap = M.IoCapture(p)
            obs = {r.role: r for r in cap.roles}
            for role in ("A", "Input", "Output") + (("W",) if cap.privacy == "P3" else ()):
                a = C.RoleModel(obs[role]).analyze(planes=False)
                self.assertEqual(a["joint"]["disclosed_total"], 0, f"{cap.privacy} {role}")
            h = C.RoleModel(obs["H"]).analyze(planes=False)
            self.assertEqual(h["joint"]["disclosed_total"], 2)
            io = M.JointModel([obs["A"], obs["Input"], obs["Output"]], M.ALIAS_PAIRS).analyze(planes=False)
            self.assertEqual(io["joint"]["disclosed_total"], 0, f"{cap.privacy} A+In+Out")
            self.assertEqual(io["per_column"]["rank_mask"], io["per_column"]["rank_joint"])
            allm = M.JointModel(list(cap.roles), M.ALIAS_PAIRS).analyze(planes=False)
            self.assertEqual(allm["joint"]["disclosed_total"], 2, f"{cap.privacy} all")
            prem = M.round20_premise(io, has_h=False)
            self.assertTrue(prem["projects_onto_every_data_unknown"])
            self.assertEqual(prem["admissible_data_difference_dimension"], prem["data_unknowns"])
            del cap


# ---------------------------------------------------------------------------
# 6. the delivered result
# ---------------------------------------------------------------------------


class ResultsBinding(unittest.TestCase):
    @unittest.skipUnless(RESULTS.exists(), "results/zk60_opus_io_capture_analysis.json absent")
    def test_the_analysis_record_is_bound_to_these_tools_and_captures(self):
        rec = json.loads(RESULTS.read_text())
        self.assertEqual(rec["source_commit"], M.SOURCE_COMMIT)
        self.assertEqual(rec["profile"], M.PROFILE)
        self.assertEqual(rec["schema"], M.SCHEMA)
        self.assertIs(rec["full_privacy_review_complete"], False)
        self.assertIs(rec["u2_closed"], False)
        for name, digest in rec["tool_sha256"].items():
            p = ROOT / "scripts" / name
            self.assertTrue(p.exists(), name)
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), digest, name)
        self.assertEqual(len(rec["captures"]), 4)
        self.assertEqual(rec["refused"], [])
        self.assertTrue(rec["preflight"]["pass"])
        self.assertTrue(rec["verdict"]["controls_all_pass"])
        self.assertEqual(rec["verdict"]["per_commitment_disclosed_total"]["A"], [0])
        self.assertEqual(rec["verdict"]["per_commitment_disclosed_total"]["H"], [2])
        self.assertEqual(rec["verdict"]["joint_disclosed_total"]["io_cluster_aliased"], [0])
        self.assertEqual(rec["verdict"]["joint_disclosed_total"]["all_private_commitments_aliased"], [2])
        ids = {o["id"] for o in rec["cases"][0]["analysis"]["cross_component_obligations"]}
        self.assertIn("OBL-3", ids)
        self.assertIn("OBL-10", ids)
        self.assertIn("round20_opening_lemma", rec)


if __name__ == "__main__":
    unittest.main()
