"""O14 -- controls on the refusal inventory.

Reviewer: Claude Opus 5, 2026-09-09 (task O14 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

The inventory is a claim about the Rust sources, so these tests check it against
those sources directly: every message in the table must exist at the line it
cites, and the properties the review leans on must hold.  No capture bytes are
needed, so nothing here skips.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT / "results/zk60_opus_refusal_experiment.json"
HASHLINE = ROOT / "hashline"


def _line(rel, number):
    path = HASHLINE / ("examples/" + rel.split("/", 1)[1]) if rel.startswith("examples/") \
        else HASHLINE / "src" / rel
    return path.read_text().splitlines()[number - 1]


class TableMatchesTheSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads(RECORD.read_text())
        cls.rows = cls.record["observable_error_table"]

    def test_every_cited_line_carries_its_message(self):
        for row in self.rows:
            rel, number = row["site"].rsplit(":", 1)
            with self.subTest(site=row["site"]):
                text = _line(rel, int(number))
                # the table stores the message with {i} placeholders and prefixes
                needle = row.get("message_prefix_in_source") or row["message"]
                needle = needle.split("{")[0].strip().strip(":")
                if needle.count(":") and not needle.startswith("usage"):
                    needle = needle.split(":")[-1].strip()
                self.assertIn(needle[:28], text,
                              f"{row['site']} does not contain {needle[:28]!r}: {text.strip()!r}")

    def test_the_table_covers_thirty_eight_predicates_in_seven_classes(self):
        self.assertEqual(len(self.rows), 38)
        self.assertEqual(set(self.record["classes"]), set("PMCRWIE"))
        self.assertEqual(sum(self.record["counts"].values()), 38)

    def test_exactly_three_predicates_are_witness_dependent(self):
        w = [r for r in self.rows if r["klass"] == "W"]
        self.assertEqual(len(w), 3)
        self.assertEqual(
            sorted(r["site"] for r in w),
            ["hashline/src/private_seam.rs:194".split("/")[-1],
             "hashline/src/private_seam.rs:471".split("/")[-1],
             "zk_ffn_fresh_io.rs:400"])

    def test_no_witness_dependent_predicate_is_claimed_reproducible(self):
        for row in self.rows:
            with self.subTest(site=row["site"]):
                if row["klass"] == "W":
                    self.assertFalse(row["simulator_can_reproduce_from_statement_alone"])
                    self.assertTrue(row["covered_by_relation_wrapper"])
                else:
                    self.assertTrue(row["simulator_can_reproduce_from_statement_alone"])


class SourcePropertiesTheReviewLeansOn(unittest.TestCase):
    def test_finish_documents_that_it_does_not_precheck_equality(self):
        text = (HASHLINE / "src/zk_ffn_fresh_io.rs").read_text()
        self.assertIn("No equality precheck", text)
        self.assertIn("must fail the verifier's polynomial identity", text)

    def test_the_cli_prints_the_error_verbatim_and_exits_nonzero(self):
        text = (HASHLINE / "examples/zk60_bound_ffn.rs").read_text()
        self.assertIn('eprintln!("{e}")', text)
        self.assertIn("std::process::exit(1)", text)

    def test_the_mask_challenge_guard_aborts_without_resampling(self):
        text = (HASHLINE / "src/zk_ffn_fresh_poc.rs").read_text()
        body = text[text.index("fn draw_mask_challenge"):]
        body = body[:body.index("\n}\n") + 3]
        self.assertIn("zero CFS mask challenge; discard attempt", body)
        # exactly one draw on the repaired path, and no loop of any kind
        self.assertEqual(body.count("draw()"), 1)
        self.assertIn("mask_challenge(draw)", body)  # the legacy path forwards the closure
        self.assertNotIn("loop", body)
        self.assertNotIn("while", body)

    def test_endpoints_are_consumed_on_every_path(self):
        text = (HASHLINE / "src/zk_ffn_fresh_io.rs").read_text()
        self.assertIn("Consumes all private owners on success or failure", text)


class GameSpecificationIsExplicit(unittest.TestCase):
    def setUp(self):
        self.record = json.loads(RECORD.read_text())

    def test_the_wrapper_never_hands_the_witness_to_the_simulator(self):
        v = self.record["games"]["V_valid_relation_oracle_with_wrapper"]
        self.assertFalse(v["witness_reaches_simulator"])
        self.assertEqual(v["witness_used_for"], "the admission check only")

    def test_the_application_game_is_not_covered_by_plain_zero_knowledge(self):
        a = self.record["games"]["A_application_exposing_invalid_input_failures"]
        self.assertFalse(a["covered_by_definition_9"])
        self.assertIn("leaky", a["would_need"].lower())

    def test_the_reference_is_pinned_by_version_and_definition_title(self):
        ref = self.record["primary_reference"]
        self.assertEqual(ref["definition_titles"]["8"], "Wrappers for NIZK Simulator")
        self.assertEqual(ref["definition_titles"]["9"], "Zero-Knowledge")
        self.assertEqual(ref["definition_titles"]["10"], "Leaky Zero-Knowledge")
        self.assertEqual(len(ref["pdf_sha256"]), 64)
        self.assertIn("withdrawn", ref["note"])

    def test_the_requirements_are_not_narrowed(self):
        req = self.record["requirements_not_narrowed"]
        self.assertIn("open", req["external_root_obligation"])
        self.assertFalse(self.record["full_privacy_review_complete"])
        self.assertFalse(self.record["u2_closed"])


if __name__ == "__main__":
    unittest.main()
