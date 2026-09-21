"""Tests for the KEYED HASH RULE (decision D19) and the eleven slots the
carried public tables close.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_tagged.py"

THREE ARMS.

* A PURE arm that needs nothing at all: the four keys of each tagged
  profile re-derived here and compared with the hex literals the Rust pins,
  a keyed transcript against an unkeyed one on the same absorbs, and the
  three non-transcript roles against each other and against the legacy
  call -- including the one equality the legacy rule has and the tag does
  not, a salted leaf and an inner node being the SAME function of 64 bytes.
* The RECORDED arm, which always runs: the gate's own evidence under
  `results/zk60_native_run_gate_tagged/` is tracked, so a green suite
  asserts every figure the report quotes and asserts that the evidence was
  produced by the tool bytes now in the tree.
* The LIVE arm, skipped when the two ~41 MB tagged bundles are absent. It
  perturbs a bundle IN MEMORY only -- a key, a context, a profile, the rule
  name, the whole member, one public table value -- and asserts each is
  refused by name and that the bundle's own dictionary is put back.

Nothing here asserts a privacy property. Which hash function made a
receipt, and whether the receipt is self-consistent at its real challenges,
are not statements about what it discloses.
"""

from __future__ import annotations

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_tagged")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
RUN_E = os.path.join(BUNDLES, "run-e-tame-tagged")
RUN_F = os.path.join(BUNDLES, "run-f-zero-tagged")
RUN_A = os.path.join(BUNDLES, "run-a-tame")
HAVE_TAGGED = os.path.isdir(RUN_E) and os.path.isdir(RUN_F)
HAVE_OLD = os.path.isdir(RUN_A)

import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_jv_field import Transcript  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_hashlayer import (  # noqa: E402
    check_hash_layer,
    column_bytes,
)
from zk60_native_rg_hashrule import (  # noqa: E402
    CONTEXTS,
    KEYED_RULE_NAME,
    LEGACY_PROFILES,
    LEGACY_RULE_NAME,
    PINNED_KEYS_HEX,
    ROLES,
    HashRule,
    KeyedTranscript,
    derive_key,
    rule_for_bundle,
)
from zk60_native_rg_hcontrols import hash_rule_controls  # noqa: E402
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_tcontrols import terminal_controls  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    COVERED,
    COVERED_WITH_TABLES,
    check_terminals,
    covered_at,
    verify_captured_public_tables,
)

RUNG_G = "hashline-zk-mr1/private-block-rung-g-t24-dev/1"
M125 = "hashline-zk-mr1/private-block-m125/1"

_STATE = {}


def loaded(which=RUN_E):
    if which not in _STATE:
        b = RunBundle(which)
        index, _reason = plane_index_of(b)
        rp = RunReplay(b).run()
        _STATE[which] = (b, index, rp)
    return _STATE[which]


# =====================================================================
#  the pure arm: the rule itself, with no bundle
# =====================================================================
class TestTheRule(unittest.TestCase):
    def test_the_four_keys_of_each_tagged_profile_are_the_pinned_ones(self):
        """The same eight hex literals `zkp-core/src/hashtag.rs`'s own test
        pins. They are DERIVED here from the context strings and the profile
        string; the literals are only the comparison."""
        for profile, want in PINNED_KEYS_HEX.items():
            rule = HashRule.for_profile(profile)
            self.assertEqual(rule.name, KEYED_RULE_NAME, profile)
            got = rule.keys_hex()
            self.assertEqual(sorted(got), sorted(ROLES), profile)
            for role in ROLES:
                self.assertEqual(got[role], want[role], f"{profile} / {role}")
                self.assertEqual(
                    derive_key(CONTEXTS[role], profile).hex(), want[role]
                )
        self.assertEqual(
            HashRule.for_profile(RUNG_G).keys_hex()["transcript"][:8], "51b7d0b0"
        )
        self.assertEqual(
            HashRule.for_profile(M125).keys_hex()["node"][:8], "798eb64f"
        )

    def test_all_eight_keys_are_pairwise_distinct(self):
        keys = [HashRule.for_profile(p).keys[r]
                for p in (RUNG_G, M125) for r in ROLES]
        self.assertEqual(len(keys), 8)
        self.assertEqual(len(set(keys)), 8)

    def test_the_two_named_profiles_are_legacy_and_everything_else_is_tagged(self):
        """`Shape::hashes_under_the_legacy_rule`: a denylist of two, so a
        profile this tool has never heard of is TAGGED -- the fail-safe
        direction."""
        for p in LEGACY_PROFILES:
            self.assertTrue(HashRule.for_profile(p).is_legacy, p)
            self.assertEqual(HashRule.for_profile(p).name, LEGACY_RULE_NAME)
        self.assertFalse(HashRule.for_profile("a profile nobody has declared").is_legacy)

    def test_a_keyed_transcript_differs_from_an_unkeyed_one_on_the_same_absorbs(self):
        rule = HashRule.for_profile(RUNG_G)
        plain, keyed = Transcript(domain=b"d"), rule.transcript(b"d")
        self.assertIsInstance(keyed, KeyedTranscript)
        self.assertNotEqual(plain.state, keyed.state, "the constructors agree")
        for i in range(3):
            plain.absorb(b"label", bytes([i]) * 40)
            keyed.absorb(b"label", bytes([i]) * 40)
            self.assertNotEqual(plain.state, keyed.state, f"absorb {i}")
        self.assertNotEqual(plain.challenge_fp2(), keyed.challenge_fp2())
        # the same absorbs under the LEGACY rule are the unkeyed transcript
        legacy = HashRule.legacy().transcript(b"d")
        self.assertNotIsInstance(legacy, KeyedTranscript)
        self.assertEqual(legacy.state, Transcript(domain=b"d").state)

    def test_a_clone_of_a_keyed_transcript_carries_the_key(self):
        """`Transcript::clone_state` (transcript.rs:156): the MODE travels
        with the clone, which is what the run's segment position tags are
        squeezed from."""
        keyed = HashRule.for_profile(RUNG_G).transcript(b"d")
        keyed.absorb(b"x", b"y")
        clone = keyed.clone()
        self.assertIsInstance(clone, KeyedTranscript)
        self.assertEqual(clone.key, keyed.key)
        self.assertEqual(clone.challenge_fp2(), keyed.clone().challenge_fp2())
        lost = Transcript(state=keyed.state, counter=keyed.counter)
        self.assertNotEqual(lost.challenge_fp2(), keyed.clone().challenge_fp2())

    def test_the_three_hash_roles_separate_under_the_tag_and_not_under_legacy(self):
        """The one thing decision D19 is FOR: under the legacy rule a salted
        leaf and an inner node are the same 64-byte BLAKE3 call, and under a
        tag they are two different functions."""
        rule, legacy = HashRule.for_profile(RUNG_G), HashRule.legacy()
        a, b = bytes(range(32)), bytes(range(32, 64))
        self.assertEqual(legacy.salt_leaf(a, b), legacy.node(a, b),
                         "the legacy leaf/node ambiguity is not there")
        self.assertNotEqual(rule.salt_leaf(a, b), rule.node(a, b))
        self.assertNotEqual(rule.column_digest(a + b), rule.node(a, b))
        self.assertNotEqual(rule.column_digest(a + b), legacy.column_digest(a + b))
        self.assertEqual(len({rule.salt_leaf(a, b), rule.node(a, b),
                              rule.column_digest(a + b), legacy.node(a, b)}), 4)

    def test_a_merkle_path_folds_only_under_the_key_that_built_it(self):
        rule, legacy = HashRule.for_profile(RUNG_G), HashRule.legacy()
        leaves = [rule.column_digest(bytes([i]) * 8) for i in range(8)]
        level = list(leaves)
        levels = [level]
        while len(level) > 1:
            level = [rule.node(level[i], level[i + 1])
                     for i in range(0, len(level), 2)]
            levels.append(level)
        root, idx = level[0], 5
        path, i = [], idx
        for lvl in levels[:-1]:
            path.append(lvl[i ^ 1])
            i >>= 1
        self.assertTrue(rule.verify_path(root, idx, leaves[idx], path))
        self.assertFalse(legacy.verify_path(root, idx, leaves[idx], path))
        self.assertFalse(rule.verify_path(root, idx ^ 1, leaves[idx], path))


# =====================================================================
#  the recorded arm
# =====================================================================
class TestRecordedEvidence(unittest.TestCase):
    def records(self):
        out = {}
        for name in ("run-e-tame-tagged", "run-f-zero-tagged"):
            path = os.path.join(EVIDENCE, f"{name}.json")
            self.assertTrue(os.path.exists(path), f"{path} is missing")
            with open(path) as fh:
                out[name] = json.load(fh)
        return out

    def test_the_evidence_was_produced_by_the_tools_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in self.records().items():
            self.assertEqual(rec["tool_sha256"], want, name)

    def test_both_records_pass_and_claim_no_privacy_property(self):
        for name, rec in self.records().items():
            self.assertTrue(rec["ok"], name)
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["privacy_acceptance"], name)
            self.assertFalse(rec["privacy_review_complete"], name)

    def test_the_hash_rule_was_derived_and_compared_member_by_member(self):
        for name, rec in self.records().items():
            hr = rec["hash_rule"]
            self.assertEqual(hr["derived_rule"], KEYED_RULE_NAME, name)
            self.assertEqual(hr["keys_compared"], 4, name)
            self.assertEqual(hr["contexts_compared"], 4, name)
            self.assertEqual(hr["refusals"], [], name)
            self.assertEqual(hr["findings"], [], name)
            self.assertEqual(hr["era"], "tagged-schema", name)
            self.assertFalse(hr["superseded"], name)
            self.assertEqual(hr["block_profile"], RUNG_G, name)
            self.assertEqual(hr["run_profile"],
                             "hashline-zk-mr1/private-run-rung-g-t24-dev/1", name)
            self.assertEqual(hr["contexts_pinned_in_this_tool"], dict(CONTEXTS), name)
            self.assertEqual(hr["derived_keys_hex"], PINNED_KEYS_HEX[RUNG_G], name)

    def test_the_replay_under_the_tag_reproduces_everything_round_one_did(self):
        """The counts are round 1's exactly, under another hash function:
        375 positions, 6,086 challenges, counter 6,918, the run binding and
        the segment position tags."""
        for name, rec in self.records().items():
            s2 = rec["stage2_transcript_replay"]
            self.assertEqual(s2["hash_rule"], KEYED_RULE_NAME, name)
            self.assertEqual(s2["positions_checked"], 375, name)
            self.assertEqual(s2["challenges_checked"], 6086, name)
            self.assertEqual(s2["final_counter"], 6918, name)
            self.assertTrue(s2["run_binding_reproduced"], name)
            self.assertEqual(s2["not_rederived"], [], name)
            self.assertEqual(s2["failures"], [], name)
            self.assertEqual(len(s2["segment_position_tags"]), 3, name)

    def test_the_hash_layer_authenticates_every_opened_column(self):
        for name, rec in self.records().items():
            s9 = rec["stage9_hash_layer"]
            self.assertEqual(s9["hash_rule"], KEYED_RULE_NAME, name)
            self.assertEqual(s9["openings"], 13, name)
            self.assertEqual(s9["columns_checked"], 3328, name)
            self.assertEqual(s9["columns_authenticated"], 3328, name)
            self.assertEqual(s9["path_depth_checked"], 3328, name)
            self.assertEqual(s9["findings"], [], name)
            probe = s9["cross_rule_probe"]
            self.assertTrue(probe["honest"], name)
            self.assertEqual(probe["wrong_rules_tried"], 4, name)
            self.assertEqual(probe["wrong_rules_that_reached_the_root"], [], name)

    def test_the_six_hash_rule_controls_all_fire(self):
        for name, rec in self.records().items():
            ctl = rec["stage9_hash_layer"]["controls"]
            self.assertTrue(ctl["ok"], name)
            got = {c["control"]: c for c in ctl["controls"]}
            # [ROUND 5, 2026-09-20] CH-7 joins the set, and the assertion is
            # updated deliberately: each bundle's real captured columns
            # re-hashed under the OTHER tagged profile's derived key set.
            # Nothing is perturbed -- both key sets are complete and
            # internally consistent, and only the profile is wrong -- so it
            # says the separation of D19 is in the BYTES and not only in the
            # bookkeeping.  It could not be run before round 5, because
            # until the rung-K4 bundles there was one tagged profile.
            self.assertEqual(sorted(got), ["CH-1", "CH-2", "CH-3", "CH-4",
                                           "CH-5", "CH-6", "CH-7"], name)
            for k, c in got.items():
                self.assertTrue(c["fires"], f"{name} {k}")
            self.assertEqual(got["CH-7"]["a_under_bs_keys"], 0, name)
            self.assertEqual(got["CH-7"]["b_under_as_keys"], 0, name)
            self.assertEqual(got["CH-7"]["a_under_its_own_keys"],
                             got["CH-7"]["of_columns_a"], name)
            self.assertTrue(
                all(got["CH-7"]["the_two_key_sets_differ_in_every_role"]
                    .values()), name)
            self.assertFalse(got["CH-4"]["under_the_legacy_rule_the_run_binding"
                                         "_reproduces"], name)
            self.assertEqual(
                got["CH-4"]["columns_authenticated_under_the_legacy_rule"], 0, name)
            self.assertGreater(
                got["CH-4"]["replay_failures_under_the_legacy_rule"], 6000, name)
            self.assertEqual(got["CH-6"]["authenticated_under_the_tag"], 0, name)
            self.assertEqual(got["CH-6"]["authenticated_under_the_legacy_rule"],
                             got["CH-6"]["of_columns"], name)

    def test_all_twenty_three_slots_are_checked_in_every_stage(self):
        for name, rec in self.records().items():
            t = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
            self.assertTrue(t["checked"], name)
            self.assertEqual(len(t["covered_slots"]), 23, name)
            self.assertEqual(t["open_slots"], [], name)
            self.assertEqual(t["slot_checks_attempted"], 69, name)
            self.assertEqual(t["slot_checks_equal"], 69, name)
            self.assertEqual(
                t["slot_checks_matching_the_stored_terminal_polynomial"], 69, name)
            self.assertEqual(t["slot_checks_expected"], 69, name)
            self.assertEqual(t["findings"], [], name)
            self.assertEqual(t["public_table_digest_failures"], [], name)
            self.assertEqual(t["public_table_structure_failures"], [], name)
            self.assertEqual(t["public_tables_rebuilt_and_digest_matched"], 16, name)
            self.assertEqual(t["public_tables_taken_from_the_capture"], 15, name)
            self.assertEqual(t["public_table_structure_checks"], 45, name)
            self.assertTrue(t["source_pins"]["ok"], name)
            self.assertEqual(len(t["source_pins"]["pins_at_an_accepted_second_digest"]),
                             3, name)

    def test_every_carried_public_table_matches_its_own_length_and_digest(self):
        for name, rec in self.records().items():
            pt = rec["stage8_plane_index_and_terminals"]["carried_public_tables"]
            self.assertTrue(pt["public_tables_included"], name)
            self.assertEqual(pt["public_tables"], 93, name)
            self.assertEqual(pt["with_values"], 93, name)
            self.assertEqual(pt["length_checked"], 93, name)
            self.assertEqual(pt["digest_checked"], 93, name)
            self.assertEqual(pt["findings"], [], name)

    def test_the_eight_terminal_controls_all_fire(self):
        for name, rec in self.records().items():
            ctl = rec["stage8_plane_index_and_terminals"]["controls"]
            self.assertTrue(ctl["ok"], name)
            got = {c["control"]: c for c in ctl["controls"]}
            self.assertEqual(len(got), 8, name)
            for k, c in got.items():
                self.assertTrue(c["fires"], f"{name} {k}")
            self.assertTrue(got["CT-6"]["the_slot_is_not_reported_checked"], name)
            self.assertEqual(got["CT-6"]["digest_failures"], 1, name)
            self.assertTrue(
                got["CT-7"]["fails_at_exactly_the_slot_that_reads_that_table"], name)
            self.assertEqual(got["CT-7"]["slots_that_failed"], [[0, 5]], name)
            self.assertTrue(got["CT-8"]["fails_at_exactly_the_perturbed_slot"], name)
            self.assertEqual(got["CT-8"]["slots_that_failed"], [[2, 14]], name)

    def test_every_disclosure_and_rank_figure_is_the_one_rounds_one_and_two_had(self):
        """The tag moved every proof byte and not one figure of the
        disclosure model."""
        want = {"A@0": 0, "A@1": 0, "A@2": 0, "H@0": 2, "H@1": 2, "H@2": 2,
                "B0": 0, "B1": 0, "E-Input": 0, "E-Output": 0}
        for name, rec in self.records().items():
            got = {c["role"]: c["disclosed_dimension"]
                   for c in rec["stage3_per_commitment"]["per_commitment"]}
            self.assertEqual(got, want, name)
            for b in rec["stage4_the_boundary"]["per_boundary"]:
                rr = b["restricted_to_the_reserved_rows"]
                self.assertEqual(rr["rank_on_the_reserved_block"], 6, name)
                self.assertEqual(rr["generators"], 6, name)
                self.assertEqual(rr["disclosed_on_the_reserved_block_fp"], 0, name)
                self.assertTrue(rr["determinant_nonzero"], name)
                tr = b["three_roles_of_the_plane"]
                self.assertEqual(tr["joint_fp"], 0, name)
                self.assertEqual(tr["sum_of_parts_fp"], 0, name)
                self.assertEqual(tr["identified_rows"], 8, name)
                self.assertEqual(tr["coordinate_classes"], 1248, name)
            w = rec["stage4_the_boundary"]["whole_run"]
            self.assertEqual(w["matrix"], "308 x 3761", name)
            self.assertEqual(w["joint_fp"], 6, name)
            self.assertEqual(w["sum_of_parts_fp"], 6, name)
            for p in rec["stage4_the_boundary"]["adjacent_stage_pairs"]:
                self.assertEqual(p["matrix"], "202 x 2505", name)
                self.assertEqual(p["joint_fp"], 4, name)
                self.assertEqual(p["sum_of_parts_fp"], 4, name)
            self.assertTrue(rec["stage6_negative_controls"]["ok"], name)

    def test_the_channel_table_is_twenty_five_with_fourteen_open(self):
        """Round 2 counted 24 with 15 open. Round 3 adds ONE entry (the hash
        rule, DERIVED) and closes ONE (the eleven table-bearing slots), so
        25 with 14 open -- counted from the tool's own array."""
        for name, rec in self.records().items():
            ch = rec["stage7_channels"]
            self.assertEqual(ch["total"], 25, name)
            self.assertEqual(len(ch["channels"]), 25, name)
            self.assertEqual(
                ch["counts"],
                {"constructed": 2, "derived": 5, "argued": 4, "open": 14},
                name,
            )
            self.assertEqual(ch["grading_failures"], [], name)
            rule_entry = [c for c in ch["channels"] if c["channel"].startswith(
                "the hash RULE of the run")]
            self.assertEqual(len(rule_entry), 1, name)
            self.assertEqual(rule_entry[0]["status"], "derived", name)
            self.assertEqual(rule_entry[0]["columns_authenticated"], 3328, name)
            # the three hash channels stay ARGUED: stage 9 is about soundness,
            # not about what an unopened leaf hides
            for key in ("the Merkle roots", "leaf salts", "authentication paths"):
                e = [c for c in ch["channels"] if c["channel"].startswith(key)]
                self.assertEqual(len(e), 1, f"{name} {key}")
                self.assertEqual(e[0]["status"], "argued", f"{name} {key}")

    def test_nothing_measured_about_the_four_older_bundles_moved(self):
        path = os.path.join(EVIDENCE, "old", "old_bundles_unchanged.json")
        self.assertTrue(os.path.exists(path), f"{path} is missing")
        with open(path) as fh:
            s = json.load(fh)
        self.assertEqual(s["unclassified"], [])
        self.assertTrue(s["no_measured_figure_moved"])
        self.assertEqual(len(s["per_bundle"]), 4)
        for row in s["per_bundle"]:
            self.assertGreater(row["identical_leaves"], 2000, row["bundle"])

    def test_the_four_older_bundles_are_recorded_as_superseded(self):
        for b in ("run-a-tame", "run-b-zero", "run-c-tame", "run-d-zero"):
            path = os.path.join(EVIDENCE, "old", f"{b}.json")
            self.assertTrue(os.path.exists(path), f"{path} is missing")
            with open(path) as fh:
                rec = json.load(fh)
            self.assertTrue(rec["ok"], b)
            hr = rec["hash_rule"]
            self.assertEqual(hr["era"], "pre-tag", b)
            self.assertTrue(hr["superseded"], b)
            self.assertEqual(hr["derived_rule"], KEYED_RULE_NAME, b)
            self.assertEqual(hr["refusals"], [], b)
            self.assertTrue(any("SUPERSEDED" in f for f in hr["findings"]), b)
            # and their bytes really are the legacy rule's
            self.assertEqual(rec["stage2_transcript_replay"]["hash_rule"],
                             LEGACY_RULE_NAME, b)
            self.assertEqual(rec["stage9_hash_layer"]["columns_authenticated"],
                             rec["stage9_hash_layer"]["columns_checked"], b)


# =====================================================================
#  the live arm
# =====================================================================
@unittest.skipUnless(HAVE_TAGGED, "the tagged run bundles are not on this box")
class TestLive(unittest.TestCase):
    def test_the_loader_derives_the_rule_and_compares_it(self):
        b, _i, _rp = loaded()
        rec = b.hash_rule_record
        self.assertEqual(rec["derived_rule"], KEYED_RULE_NAME)
        self.assertEqual(rec["refusals"], [])
        self.assertEqual(rec["keys_compared"], 4)
        self.assertEqual(rec["contexts_compared"], 4)
        self.assertFalse(b.hash_rule.is_legacy)
        self.assertTrue(b.public_tables_included)

    def test_a_perturbed_key_context_profile_or_rule_is_refused_by_name(self):
        """Each is done IN MEMORY and put back; nothing on disk is written."""
        b, _i, _rp = loaded()
        original = copy.deepcopy(b.run["hash_tag"])
        cases = {
            "keys_hex": (lambda t: t["keys_hex"].__setitem__("leaf", "11" * 32),
                         "leaf key"),
            "contexts": (lambda t: t["contexts"].__setitem__(
                "transcript", "hashline-zk-mr1 2026-09-20 fiat shamir transcript"),
                "context"),
            "profile": (lambda t: t.__setitem__("profile", M125), "profile"),
            "rule": (lambda t: t.__setitem__("rule", LEGACY_RULE_NAME), "rule"),
        }
        for what, (mutate, needle) in cases.items():
            tag = copy.deepcopy(original)
            mutate(tag)
            b.run["hash_tag"] = tag
            try:
                rec = rule_for_bundle(b)
            finally:
                b.run["hash_tag"] = copy.deepcopy(original)
            self.assertIsNone(rec["rule"], what)
            self.assertTrue(rec["refusals"], what)
            self.assertTrue(any(needle in r for r in rec["refusals"]),
                            f"{what}: {rec['refusals']}")
        self.assertEqual(b.run["hash_tag"], original, "the member was not put back")

    def test_a_bundle_claiming_legacy_but_captured_under_the_tag_fails_replay(self):
        """The refusal is the first line. The second is the bytes: forced to
        the legacy rule, the replay does not even reproduce the run binding
        and not one opened column authenticates."""
        b, _i, _rp = loaded()
        original = copy.deepcopy(b.run["hash_tag"])
        b.run["hash_tag"] = {"rule": LEGACY_RULE_NAME}
        try:
            rec = rule_for_bundle(b)
        finally:
            b.run["hash_tag"] = original
        self.assertIsNone(rec["rule"])
        keep = b.hash_rule
        b.hash_rule = HashRule.legacy()
        try:
            s = RunReplay(b).run().summary()
            hl = check_hash_layer(b, rule=HashRule.legacy(), probe=False)
        finally:
            b.hash_rule = keep
        self.assertFalse(s["run_binding_reproduced"])
        self.assertGreater(len(s["failures"]), 6000)
        self.assertEqual(hl["columns_authenticated"], 0)
        self.assertEqual(hl["columns_checked"], 3328)
        # and the bundle is unharmed
        self.assertFalse(b.hash_rule.is_legacy)
        self.assertTrue(RunReplay(b).run().summary()["ok"])

    def test_the_replay_and_the_hash_layer_live(self):
        b, _i, rp = loaded()
        s = rp.summary()
        self.assertTrue(s["ok"])
        self.assertEqual(s["challenges_checked"], 6086)
        self.assertEqual(s["positions_checked"], 375)
        hl = check_hash_layer(b)
        self.assertTrue(hl["ok"])
        self.assertEqual(hl["columns_authenticated"], 3328)
        self.assertEqual(hl["bytes_hashed"], 7751680)

    def test_every_slot_is_evaluated_live_and_the_tables_are_checked(self):
        b, index, rp = loaded()
        self.assertEqual(covered_at(b), COVERED)
        pt = verify_captured_public_tables(b)
        self.assertTrue(pt["ok"])
        self.assertEqual(pt["digest_checked"], 93)
        r = check_terminals(b, index, replay=rp)
        self.assertTrue(r["ok"], r["findings"][:3])
        self.assertEqual(r["slot_checks_equal"], 69)
        self.assertEqual(sorted(COVERED_WITH_TABLES),
                         [5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 19])

    def test_a_perturbed_public_table_value_is_caught_by_the_capture_digest(self):
        """CT-6 and CT-7's mechanism, asserted directly: the digest refuses
        the value, and with the digest check dropped the ARITHMETIC refuses
        it at exactly the slot that reads the table."""
        b, index, rp = loaded()
        doc = b.stages[0].doc
        arg = doc["arguments"][5]
        i = next(j for j, t in enumerate(arg["tables"]) if t["kind"] == "public")
        docs = [st.doc for st in b.stages]
        d0 = dict(doc)
        args = list(d0["arguments"])
        a5 = dict(args[5])
        tabs = list(a5["tables"])
        t5 = dict(tabs[i])
        vals = list(t5["values"])
        vals[0] = [(vals[0][0] + 1) % (2 ** 64 - 2 ** 32 + 1), vals[0][1]]
        t5["values"] = vals
        tabs[i] = t5
        a5["tables"] = tabs
        args[5] = a5
        d0["arguments"] = args
        docs = list(docs)
        docs[0] = d0
        caught = check_terminals(b, index, replay=rp, stage_docs=docs)
        self.assertEqual(len(caught["public_table_digest_failures"]), 1)
        self.assertEqual(caught["slot_checks_equal"], 68)
        loose = check_terminals(b, index, replay=rp, stage_docs=docs,
                                check_digests=False)
        failed = sorted({(r["stage"], s) for r in loose["per_stage"]
                         for s in r["checked"] if s not in r["equal"]})
        self.assertEqual(failed, [(0, 5)])
        # the bundle's own documents are untouched
        self.assertIsNot(b.stages[0].doc, d0)
        self.assertTrue(check_terminals(b, index, replay=rp)["ok"])

    def test_the_captured_tables_have_the_structure_their_builders_give_them(self):
        """The weight folds vanish off their own input support, and the
        support is not always the width: the output projection's is the
        PADDED HEAD SLOTS, and a dead head slot is not an index above the
        width."""
        b, index, rp = loaded()
        r = check_terminals(b, index, replay=rp)
        det = r["public_table_structure_detail"]
        self.assertEqual(det["fold(w_q)"][0]["runs"], [(0, 95)])
        self.assertEqual(det["fold(w_o)"][0]["runs"], [(0, 47), (64, 111)])
        self.assertEqual(det["fold(w_o)"][0]["support"], "heads")
        self.assertEqual(det["fold(w_q)"][0]["live_positions"], 96)
        self.assertEqual(det["fold(w_o)"][0]["live_positions"], 96)
        for label in ("rope_cos", "rope_sin"):
            self.assertGreater(det[label][0]["partner_pairs"], 0, label)
            self.assertGreater(det[label][0]["dead_positions"], 0, label)
        for label in ("exp_values", "act_values"):
            self.assertEqual(det[label][0]["recovered_entries"], 256, label)

    @unittest.skipUnless(HAVE_OLD, "the pre-tag bundles are not on this box")
    def test_a_pre_tag_bundle_is_legacy_and_marked_superseded(self):
        b = RunBundle(RUN_A)
        rec = b.hash_rule_record
        self.assertEqual(rec["era"], "pre-tag")
        self.assertTrue(rec["superseded"])
        self.assertTrue(b.hash_rule.is_legacy)
        self.assertEqual(rec["refusals"], [])
        self.assertTrue(RunReplay(b).run().summary()["ok"])
        self.assertTrue(check_hash_layer(b)["ok"])
        ctl = hash_rule_controls(b, legacy_bundle=b)
        self.assertTrue(ctl["ok"])
        # [round 5] CH-7 needs a bundle of a SECOND tagged profile; none is
        # supplied here, so it is NAMED AND SKIPPED beside CH-1..CH-5, which
        # a pre-tag bundle cannot have either.  A skipped control is named,
        # never counted as passed.
        self.assertEqual([c["control"] for c in ctl["controls_skipped"]],
                         ["CH-1..CH-5", "CH-7"])

    def test_the_two_tagged_bundles_are_two_different_runs(self):
        e, _i, _r = loaded(RUN_E)
        f, _i2, _r2 = loaded(RUN_F)
        self.assertNotEqual(e.run["run_binding"], f.run["run_binding"])
        self.assertEqual(e.run["hash_tag"], f.run["hash_tag"],
                         "the tag is a function of the profile, not of the run")
        self.assertEqual(e.run["plane_index"], f.run["plane_index"])
        for k in range(e.blocks):
            self.assertNotEqual(e.stages[k].doc["segment_sha256"],
                                f.stages[k].doc["segment_sha256"])
            self.assertEqual(e.stages[k].doc["segment_bytes"],
                             f.stages[k].doc["segment_bytes"])


if __name__ == "__main__":
    unittest.main()
