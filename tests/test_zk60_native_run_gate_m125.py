"""ROUND 9 — the RUN gate at the 125M shape.

Four arms, in the order rounds 5 and 8 established:

* a PURE arm that needs nothing on disk: the `/5-run` array store's decoder
  and every one of its refusal paths, the encoder it is proved against, and
  the scaling laws the 125M shape must obey, written out as literals so that
  a later change to a tool cannot quietly move them;
* a RECORDED arm that reads this round's committed evidence and asserts the
  figures of record;
* a LIVE arm behind the two 125M bundles' presence -- they are 281 MB and
  273 MB and live OUTSIDE the repository, so these skip on a machine that
  does not have them;
* a LIVE arm behind the development bundles, for the loader's equivalence.

**A REFUSAL IS NEVER A CRASH.**  Round 5's finding K4-F1 and round 8's
R8-F1 were both a refusal path that raised instead of reporting.  Every
refusal of the new loader is exercised here, and each is asserted to be an
`ArrayRefused` whose message NAMES the member -- not a `KeyError`, not a
`struct.error`, not an `IndexError` off the end of a slice.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPTS = os.path.join(ROOT, "scripts")
if SCRIPTS not in sys.path:
    sys.path.insert(0, SCRIPTS)

import numpy as np  # noqa: E402

from zk60_native_rg_arrays import (  # noqa: E402
    ARRAY_MIN,
    ELEM_WIDTH,
    EXTERNALISABLE,
    P,
    SCHEMA_4,
    SCHEMA_5,
    ArrayRefused,
    ArrayStore,
    Fp2Array,
    FpArray,
    encode_to_5run,
    resolve_document,
)

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_m125")
M125_DENSE = "/home/victor/zk60-artifacts/m125-capture-dense-l2"
M125_ZERO = "/home/victor/zk60-artifacts/m125-capture-zero-l2"
DEV = ("/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920")


def _record(name):
    p = os.path.join(EVIDENCE, name)
    if not os.path.exists(p):
        return None
    with open(p) as fh:
        return json.load(fh)


def _store(tmp, blob: bytes) -> ArrayStore:
    path = os.path.join(tmp, "arrays.bin")
    with open(path, "wb") as fh:
        fh.write(blob)
    return ArrayStore(path)


def _ref(blob: bytes, off: int, n: int, elem: str) -> dict:
    w = ELEM_WIDTH[elem]
    raw = blob[off:off + n * w]
    return {"array": hashlib.sha256(raw).hexdigest(), "elem": elem,
            "len": n, "offset": off, "bytes": n * w}


# =====================================================================
# 1.  PURE -- the decoder and its refusals
# =====================================================================
class TheDecoderReadsWhatTheFormatWrites(unittest.TestCase):
    """`/5-run` 12: an entry is one little-endian u64 (`fp`) or two,
    `c0` then `c1` (`fp2`), and the resolved member must read exactly like
    the JSON list `/4-run` writes in its place."""

    def setUp(self):
        import tempfile
        self.tmp = tempfile.mkdtemp(prefix="zk60-rg-m125-")
        self.fp = [1, 2, 3, P - 1] + list(range(300))
        self.fp2 = [[i, P - 1 - i] for i in range(300)]
        blob = bytearray()
        self.off_fp = 0
        blob += np.asarray(self.fp, dtype="<u8").tobytes()
        self.off_fp2 = len(blob)
        blob += np.asarray([y for x in self.fp2 for y in x],
                           dtype="<u8").tobytes()
        self.blob = bytes(blob)
        self.s = _store(self.tmp, self.blob)

    def tearDown(self):
        self.s.close()

    def test_an_fp_array_reads_as_the_list_of_ints_it_replaces(self):
        a = self.s.resolve(_ref(self.blob, self.off_fp, len(self.fp), "fp"),
                           "x.values")
        self.assertIsInstance(a, FpArray)
        self.assertEqual(len(a), len(self.fp))
        self.assertEqual(list(a), self.fp)
        self.assertEqual(a[3], P - 1)
        self.assertEqual(a[1:4], self.fp[1:4])
        self.assertEqual(a, self.fp)
        self.assertEqual(a.tolist(), self.fp)

    def test_an_fp2_array_reads_as_the_list_of_pairs_it_replaces(self):
        a = self.s.resolve(
            _ref(self.blob, self.off_fp2, len(self.fp2), "fp2"), "x.vector")
        self.assertIsInstance(a, Fp2Array)
        self.assertEqual(len(a), len(self.fp2))
        self.assertEqual(list(a), self.fp2)
        self.assertEqual(a[7], self.fp2[7])
        self.assertEqual(a[2:5], self.fp2[2:5])
        self.assertEqual(a, self.fp2)

    def test_the_digest_of_a_resolved_range_is_recomputed_once_per_range(self):
        r = _ref(self.blob, self.off_fp, len(self.fp), "fp")
        self.s.resolve(r, "a.values")
        self.s.resolve(r, "b.values")
        self.assertEqual(self.s.resolutions, 2)
        self.assertEqual(self.s.distinct_arrays_verified, 1,
                         "the writer's dedup must not be paid for twice")

    def test_the_summary_counts_what_it_says_it_counts(self):
        self.s.resolve(_ref(self.blob, self.off_fp, len(self.fp), "fp"), "a.q")
        s = self.s.summary()
        self.assertEqual(s["references_resolved"], 1)
        self.assertEqual(s["bytes_verified_by_sha256"], len(self.fp) * 8)
        self.assertTrue(s["ok"])


class ARefusalIsNeverACrash(unittest.TestCase):
    """Every way a reference can be wrong, and the named refusal for it.

    Findings K4-F1 (round 5) and R8-F1 (round 8) were both a refusal path
    that raised the WRONG exception.  Each case here asserts `ArrayRefused`
    and asserts the member's name is in the message, so a reader of the
    finding knows which member to look at."""

    def setUp(self):
        import tempfile
        self.tmp = tempfile.mkdtemp(prefix="zk60-rg-m125-ref-")
        self.vals = list(range(ARRAY_MIN))
        self.blob = np.asarray(self.vals, dtype="<u8").tobytes()
        self.s = _store(self.tmp, self.blob)
        self.good = _ref(self.blob, 0, ARRAY_MIN, "fp")

    def tearDown(self):
        self.s.close()

    def _refuses(self, ref, needle, where="stage-00.json.roles[0].values"):
        with self.assertRaises(ArrayRefused) as cm:
            self.s.resolve(ref, where)
        msg = str(cm.exception)
        self.assertIn(where, msg, "a refusal must name the member")
        self.assertIn(needle, msg)
        return msg

    def test_a_missing_member_of_the_reference(self):
        r = dict(self.good)
        del r["elem"]
        self._refuses(r, "missing ['elem']")

    def test_a_member_the_schema_does_not_define(self):
        r = dict(self.good, kind="public")
        self._refuses(r, "does not define")

    def test_an_unknown_element_type(self):
        r = dict(self.good, elem="fp3")
        self._refuses(r, "is not 'fp' or 'fp2'")

    def test_bytes_that_are_not_len_times_the_width(self):
        r = dict(self.good, bytes=self.good["bytes"] - 8)
        self._refuses(r, "!= len")

    def test_a_negative_or_non_integer_field(self):
        self._refuses(dict(self.good, offset=-8), "is not a whole number")
        self._refuses(dict(self.good, len="256"), "is not a whole number")

    def test_a_digest_that_is_not_a_digest(self):
        self._refuses(dict(self.good, array="deadbeef"),
                      "is not a sha256 hex digest")

    def test_a_range_past_the_end_of_the_store(self):
        r = dict(self.good, offset=self.s.bytes - 8)
        r["array"] = hashlib.sha256(b"\0").hexdigest()
        self._refuses(r, "run past the end")

    def test_the_wrong_digest_for_the_right_bytes(self):
        r = dict(self.good, array="0" * 64)
        self._refuses(r, "the sha256 of bytes")

    def test_a_u64_that_is_not_a_reduced_goldilocks_element(self):
        import tempfile
        bad = list(self.vals)
        bad[17] = P + 5
        raw = np.asarray(bad, dtype="<u8").tobytes()
        tmp = tempfile.mkdtemp(prefix="zk60-rg-m125-p-")
        s = _store(tmp, raw)
        try:
            with self.assertRaises(ArrayRefused) as cm:
                s.resolve(_ref(raw, 0, ARRAY_MIN, "fp"), "stage-00.json.mask.q")
            self.assertIn("not a reduced Goldilocks element", str(cm.exception))
            self.assertIn("u64 17", str(cm.exception))
        finally:
            s.close()

    def test_a_store_that_is_not_there(self):
        with self.assertRaises(ArrayRefused) as cm:
            ArrayStore(os.path.join(self.tmp, "absent.bin"))
        self.assertIn("no such file", str(cm.exception))

    def test_a_store_whose_length_is_not_the_manifests(self):
        with self.assertRaises(ArrayRefused) as cm:
            ArrayStore(os.path.join(self.tmp, "arrays.bin"),
                       declared_bytes=self.s.bytes + 1)
        self.assertIn("in the manifest", str(cm.exception))

    def test_a_reference_under_a_member_the_schema_never_externalises(self):
        doc = {"roles": [{"role": "A", "salt": dict(self.good)}]}
        refusals = []
        n = resolve_document(doc, self.s, "stage-00.json", refusals)
        self.assertEqual(n, 0)
        self.assertEqual(len(refusals), 1)
        self.assertIn("salt", refusals[0])
        self.assertIn("does not externalise", refusals[0])

    def test_a_reference_as_a_list_element(self):
        doc = {"roles": [dict(self.good)]}
        refusals = []
        resolve_document(doc, self.s, "stage-00.json", refusals)
        self.assertEqual(len(refusals), 1)
        self.assertIn("as a list element", refusals[0])

    def test_the_walk_collects_refusals_and_keeps_going(self):
        doc = {
            "mask": {"q": dict(self.good, elem="fp7"),
                     "prox": dict(self.good)},
            "roles": [{"proximity_vector": dict(self.good, bytes=1)}],
        }
        refusals = []
        n = resolve_document(doc, self.s, "stage-00.json", refusals)
        self.assertEqual(n, 1, "the one good reference must still resolve")
        self.assertEqual(len(refusals), 2)
        self.assertIsInstance(doc["mask"]["prox"], FpArray)

    def test_every_externalisable_member_the_format_names_is_walked(self):
        self.assertEqual(
            set(EXTERNALISABLE),
            {"values", "vector", "proximity_vector", "proximity_rhos",
             "q", "prox"},
            "format 12 lists exactly these six and says 'Nothing else, ever'",
        )


class TheEncoderIsTheInverseOfTheDecoder(unittest.TestCase):
    def test_a_round_trip_over_the_six_member_names(self):
        import tempfile
        doc = {
            "mask": {"q": [[i, i + 1] for i in range(ARRAY_MIN)],
                     "prox": [[i, 2 * i] for i in range(ARRAY_MIN)],
                     "specs": [[1, 2]] * 23},
            "roles": [{
                "proximity_vector": [[i, i] for i in range(ARRAY_MIN)],
                "proximity_rhos": [[i, 0] for i in range(ARRAY_MIN)],
                "groups": [{"vector": [[3, 4]] * ARRAY_MIN,
                            "lambdas": [[1, 1]] * 4}],
                "columns": [{"values": list(range(ARRAY_MIN)),
                             "salt": list(range(32))}],
            }],
        }
        import copy
        original = copy.deepcopy(doc)
        blob, index = bytearray(), {}
        n = encode_to_5run(doc, blob, index, "stage-00.json")
        self.assertEqual(n, 6, "exactly the six externalisable members")
        tmp = tempfile.mkdtemp(prefix="zk60-rg-m125-rt-")
        s = _store(tmp, bytes(blob))
        try:
            refusals = []
            resolve_document(doc, s, "stage-00.json", refusals)
            self.assertEqual(refusals, [])
            self.assertEqual(doc["mask"]["q"], original["mask"]["q"])
            self.assertEqual(doc["mask"]["prox"], original["mask"]["prox"])
            self.assertEqual(doc["roles"][0]["proximity_vector"],
                             original["roles"][0]["proximity_vector"])
            self.assertEqual(doc["roles"][0]["groups"][0]["vector"],
                             original["roles"][0]["groups"][0]["vector"])
            self.assertEqual(doc["roles"][0]["columns"][0]["values"],
                             original["roles"][0]["columns"][0]["values"])
            # below the threshold, and members the schema never externalises,
            # are untouched
            self.assertEqual(doc["mask"]["specs"], original["mask"]["specs"])
            self.assertEqual(doc["roles"][0]["columns"][0]["salt"],
                             original["roles"][0]["columns"][0]["salt"])
            self.assertEqual(doc["roles"][0]["groups"][0]["lambdas"],
                             original["roles"][0]["groups"][0]["lambdas"])
        finally:
            s.close()

    def test_an_array_shorter_than_the_threshold_stays_inline(self):
        doc = {"mask": {"q": [[1, 2]] * (ARRAY_MIN - 1)}}
        blob, index = bytearray(), {}
        self.assertEqual(encode_to_5run(doc, blob, index, "x"), 0)
        self.assertIsInstance(doc["mask"]["q"], list)

    def test_identical_arrays_are_stored_once(self):
        v = list(range(ARRAY_MIN))
        doc = {"a": {"values": list(v)}, "b": {"values": list(v)}}
        blob, index = bytearray(), {}
        self.assertEqual(encode_to_5run(doc, blob, index, "x"), 2)
        self.assertEqual(len(index), 1)
        self.assertEqual(doc["a"]["values"]["offset"],
                         doc["b"]["values"]["offset"])


# =====================================================================
# 2.  PURE -- the laws the 125M shape must obey
# =====================================================================
class WhatTheGateMustReportAt125M(unittest.TestCase):
    """The prediction, written out as literals.

    These were computed from `run.json["shape"]` and the capture's declared
    geometry BEFORE the gate was run at 125M, and validated by reproducing
    the committed rung-G and rung-K4 records to the unit.  They are here so
    that a later tool change that moves one of them is a test failure with
    a name, rather than a number nobody compares."""

    SHAPE_INDEPENDENT = {
        "a_disclosed": 0, "h_disclosed": 2, "endpoint_disclosed": 0,
        "boundary_disclosed": 0, "m_disclosed": 0,
        "boundary_reserved_rank": 6, "m_rows": 50, "m_functionals": 34,
        "n_slots": 23, "a_groups": 36, "h_groups": 9, "channels": 28,
        "three_role_generators": 154,
    }
    REPLAY = {"positions_checked": 251, "challenges_checked": 27828,
              "sumcheck_rounds_per_stage": 361,
              "definition_draws_per_stage": 446}
    HASH = {"openings": 9, "columns": 2304, "column_bytes": 52867072,
            "largest_column_bytes": 56960, "tree_depth": 16}
    MASK = {"rows": 50, "functionals": 34, "largest_L": 117,
            "largest_L_slot": 17, "mask_msg": 512, "mask_q": 256,
            "ruling_C4_headroom": 139}
    JOINT = {"identified_row_pairs": 128, "sum_of_the_parts": 4,
             "whole_run_joint": 4, "whole_run_generators": 206}
    TERMINALS = {"slot_checks_expected": 46}

    def setUp(self):
        self.p = _record("prediction_m125.json")
        if self.p is None:
            self.skipTest("the prediction record is not in the tree")

    def test_the_prediction_was_validated_on_both_development_shapes(self):
        self.assertTrue(self.p["validation_ok"])
        self.assertEqual(sorted(self.p["validated_on"]),
                         ["run-g-dense-s20", "run-i-dense-k4"])
        for v in self.p["validation"]:
            self.assertEqual(v["mismatches"], [])

    def test_every_predicted_figure_is_the_literal_written_here(self):
        p = self.p["prediction"]
        self.assertEqual(p["shape_independent"], self.SHAPE_INDEPENDENT)
        for k, v in self.REPLAY.items():
            self.assertEqual(p["replay"][k], v, k)
        for k, v in self.HASH.items():
            self.assertEqual(p["hash_layer"][k], v, k)
        for k, v in self.MASK.items():
            self.assertEqual(p["masking"][k], v, k)
        for k, v in self.JOINT.items():
            self.assertEqual(p["joint"][k], v, k)
        for k, v in self.TERMINALS.items():
            self.assertEqual(p["terminals"][k], v, k)

    def test_the_125m_geometry_is_the_one_the_brief_names(self):
        p = self.p["prediction"]
        self.assertEqual(
            (p["tokens"], p["width"], p["hidden"], p["q_heads"],
             p["kv_heads"], p["head_dim"], p["lkv"]),
            (512, 768, 2048, 12, 4, 64, 2))
        self.assertEqual((p["cols"], p["encoded_cols"], p["opened_cols"]),
                         (1 << 14, 1 << 16, 256))
        self.assertEqual(p["blocks"], 2)

    def test_the_non_data_row_count_is_two_per_claim_plus_the_proximity_pair(self):
        """The one law that holds at every commitment of every shape, and
        the reason `A`'s 246 is shape-independent while `H`'s is not."""
        for r in self.p["prediction"]["per_commitment"]:
            self.assertTrue(r["non_data_rows_match"], r["key"])
        by = {r["key"]: r for r in self.p["prediction"]["per_commitment"]}
        self.assertEqual(by["A@0"]["claims"], 122)
        self.assertEqual(by["A@0"]["predicted_non_data_rows"], 246)
        self.assertEqual(by["H@0"]["claims"], 51)
        self.assertEqual(by["H@0"]["predicted_non_data_rows"], 104)

    def test_rulings_C4_headroom_is_positive_or_the_mask_would_not_fit(self):
        m = self.p["prediction"]["masking"]
        self.assertGreater(m["ruling_C4_headroom"], 0)
        self.assertEqual(m["largest_L"] + m["mask_q"] + m["ruling_C4_headroom"],
                         m["mask_msg"])


# =====================================================================
# 3.  RECORDED -- this round's evidence
# =====================================================================
class TheLoaderEquivalence(unittest.TestCase):
    def test_every_member_of_a_development_run_reads_the_same_both_ways(self):
        r = _record("loader_equivalence.json")
        if r is None:
            self.skipTest("the equivalence record is not in the tree")
        self.assertTrue(r["ok"])
        self.assertEqual(r["differences_total"], 0)
        self.assertEqual(r["source_schema"], SCHEMA_4)
        self.assertEqual(r["reencoded_schema"], SCHEMA_5)
        self.assertGreater(r["json_leaves_compared"], 3_000_000)
        self.assertEqual(r["encoder"]["members_externalised"], 1771)
        self.assertEqual(r["encoder"]["distinct_arrays"], 1683)
        self.assertEqual(r["field_elements_behind_the_references"], 1133619)
        self.assertEqual(r["array_store"]["refusals"], [])
        self.assertIn("NOT a test of the Rust encoder", r["what_this_is_not"])

    def test_the_whole_gate_reports_the_same_figures_through_the_new_loader(self):
        d = _record("loader_equivalence_gate.diff.json")
        if d is None:
            self.skipTest("the gate diff is not in the tree")
        self.assertGreater(d["identical_leaves"], 4000)
        allowed = ("bundle", "bundle_dir", "dir", "seconds", "array_store",
                   "schema", "manifest_files_checked", "manifest_total_bytes",
                   "C5_a_stage_file_swapped")
        for c in d["changed"]:
            self.assertTrue(any(a in c["path"] for a in allowed),
                            f"unclassified changed leaf: {c['path']}")
        for p in d["only_in_the_old_record"] + d["only_in_the_new_record"]:
            self.assertIn("array_store", p, f"unclassified leaf: {p}")


class TheRecordOfRecordAt125M(unittest.TestCase):
    BUNDLES = ("m125-dense", "m125-zero")

    def _recs(self):
        out = {}
        for b in self.BUNDLES:
            r = _record(f"{b}.json")
            if r is not None:
                out[b] = r
        if not out:
            self.skipTest("no 125M record is in the tree")
        return out

    def test_the_replay_reproduced_every_challenge(self):
        for name, r in self._recs().items():
            s = r.get("stage2_transcript_replay")
            if s is None:
                continue
            with self.subTest(name):
                self.assertTrue(s["ok"], s.get("failures"))
                self.assertTrue(s["run_binding_reproduced"])
                self.assertEqual(s["positions_checked"], 251)
                self.assertEqual(s["challenges_checked"], 27828)
                self.assertEqual(s["not_rederived"], [])
                self.assertEqual(s["hash_rule"], "blake3-keyed/1")

    def test_every_opened_column_of_every_commitment_authenticated(self):
        for name, r in self._recs().items():
            s = r.get("stage9_hash_layer")
            if s is None:
                continue
            with self.subTest(name):
                self.assertEqual(s["openings"], 9)
                self.assertEqual(s["columns_checked"], 2304)
                self.assertEqual(s["columns_authenticated"], 2304)
                self.assertEqual(s["bytes_hashed"], 52867072)
                self.assertEqual(s["findings"], [])

    def test_the_array_store_resolved_every_reference_without_a_refusal(self):
        for name, r in self._recs().items():
            s = r.get("stage1_integrity")
            if s is None:
                continue
            with self.subTest(name):
                st = s["array_store"]
                self.assertEqual(st["refusals"], [])
                self.assertEqual(st["file"], "arrays.bin")
                self.assertGreater(st["distinct_arrays_verified_by_sha256"],
                                   1000)
                self.assertEqual(s["findings"], [])
                self.assertEqual(s["schema"], SCHEMA_5)

    def test_all_thirty_eight_pins_are_at_a_digest_this_gate_read(self):
        for name, r in self._recs().items():
            p = r.get("run_layer_source_pins")
            if p is None:
                continue
            with self.subTest(name):
                self.assertTrue(p["ok"])
                self.assertEqual(p["pins_that_moved"], [])
                self.assertEqual(p["pins_missing_from_the_bundle"], [])
                sh = p["shared_files"]
                self.assertTrue(sh["pinned"])
                self.assertEqual(sh["files_pinned"], 23)
                self.assertEqual(sh["at_a_digest_this_gate_read"], 23)
                self.assertEqual(len(sh["equal_to_the_bytes_round_8_read"]), 8)
                self.assertEqual(sh["pins_that_moved"], [])

    def test_the_disclosure_figures_are_the_development_shapes(self):
        for name, r in self._recs().items():
            s = r.get("stage3_per_commitment")
            if s is None or s.get("the_stage_raised"):
                continue
            with self.subTest(name):
                for row in s["per_commitment"]:
                    self.assertTrue(row["meets_expectation"], row["role"])
                    self.assertEqual(row["column_identity_failures"], 0)
                    self.assertEqual(row["group_claim_identity_failures"], 0)
                    self.assertTrue(
                        row["distinct_opened_columns_within_pad_count"])
                for m in s["masking_commitments"]:
                    self.assertEqual(m["rows"], 50)
                    self.assertEqual(m["specs"], 23)
                    self.assertEqual(m["disclosed_dimension"], 0)

    def test_the_boundary_is_six_of_six_and_discloses_nothing(self):
        for name, r in self._recs().items():
            s = r.get("stage4_the_boundary")
            if s is None or s.get("the_stage_raised"):
                continue
            with self.subTest(name):
                for b in s["per_boundary"]:
                    res = b["restricted_to_the_reserved_rows"]
                    self.assertEqual(res["disclosed_on_the_reserved_block_fp"], 0)
                    self.assertTrue(res["full_row_rank"])
                    self.assertTrue(res["determinant_nonzero"])
                w = s["whole_run"]
                self.assertEqual(w["joint_fp"], 4)
                self.assertEqual(w["sum_of_parts_fp"], 4)
                self.assertEqual(w["generators"], 206)
                self.assertEqual(w["identified_rows"], 128)
                self.assertIn("ruling_R3", s)

    def test_every_recorded_figure_agrees_with_the_prediction(self):
        for name, r in self._recs().items():
            p = r.get("prediction")
            if p is None:
                continue
            with self.subTest(name):
                self.assertEqual(p["replay"]["positions_checked"], 251)
                self.assertEqual(p["hash_layer"]["columns"], 2304)
                self.assertEqual(p["terminals"]["slot_checks_expected"], 46)

    def test_no_record_claims_a_privacy_property(self):
        for name, r in self._recs().items():
            with self.subTest(name):
                self.assertFalse(r["privacy_property_established"])
                self.assertFalse(r["privacy_acceptance"])
                self.assertTrue(any("NOT a privacy acceptance" in s
                                    for s in r["what_it_does_not_show"]))


# =====================================================================
# 4.  LIVE -- the bundles, when they are on this machine
# =====================================================================
@unittest.skipUnless(os.path.isdir(M125_DENSE),
                     "the 125M bundles live outside the repository")
class TheLiveBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from zk60_native_rg_bundle import RunBundle
        cls.b = RunBundle(M125_DENSE)

    def test_the_bundle_declares_the_new_schema_and_carries_a_store(self):
        self.assertEqual(self.b.schema, SCHEMA_5)
        self.assertIsNotNone(self.b.store)
        self.assertEqual(len(self.b.manifest["source_pins"]), 38)

    def test_a_perturbed_byte_of_the_store_is_refused_by_digest(self):
        """The control, in memory: nothing on disk is written, and the
        refusal names the member rather than raising from numpy."""
        st = self.b.stages[0]
        ref = dict(st.roles[0]["groups"][0]["vector"].ref)
        ref["offset"] = ref["offset"] + 8  # the same length, other bytes
        with self.assertRaises(ArrayRefused) as cm:
            self.b.store.resolve(ref, "stage-00.json.roles[0].groups[0].vector")
        self.assertIn("the sha256 of bytes", str(cm.exception))

    def test_a_public_tables_array_digest_is_its_own_sha256_field(self):
        """Format 12: 'A public table's `array` digest IS its `sha256`',
        because both are taken over the same image.  The one place a reader
        can check the store against a field `/4-run` already carried."""
        seen = 0
        for st in self.b.stages:
            for arg in st.slots:
                for t in arg.get("tables", []):
                    v = t.get("values")
                    if isinstance(v, (FpArray, Fp2Array)):
                        self.assertEqual(v.ref["array"], t["sha256"])
                        self.assertEqual(v.ref["len"], t["len"])
                        seen += 1
        self.assertGreater(seen, 0)

    def test_the_two_bundles_pin_the_same_sources(self):
        if not os.path.isdir(M125_ZERO):
            self.skipTest("the zero bundle is not on this machine")
        from zk60_native_rg_bundle import RunBundle
        z = RunBundle(M125_ZERO)
        self.assertEqual(self.b.manifest["source_pins"],
                         z.manifest["source_pins"])
        self.assertEqual(self.b.manifest["source_commit"],
                         "f4697f9ccad82304c56dee8c53da3bf107d98b1e")


@unittest.skipUnless(os.path.isdir(os.path.join(DEV, "run-g-dense-s20")),
                     "the development bundles are not on this machine")
class TheDecoderAgainstADevelopmentBundle(unittest.TestCase):
    def test_a_4run_bundle_must_not_carry_a_store(self):
        from zk60_native_rg_bundle import RunBundle
        b = RunBundle(os.path.join(DEV, "run-g-dense-s20"))
        self.assertEqual(b.schema, SCHEMA_4)
        self.assertIsNone(b.store)
        self.assertEqual(b.array_refusals, [])


if __name__ == "__main__":
    unittest.main()
