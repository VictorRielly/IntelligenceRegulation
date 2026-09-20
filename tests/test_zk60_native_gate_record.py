"""The committed P10 records must stay in step with the tool and the report.

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_gate_record.py"

WHY THIS FILE EXISTS.  On 2026-09-20 commit d360466 closed the masking
commitment M's three OPEN channels inside `scripts/zk60_native_privacy_gate.py`
-- 8 / 2 / 8 / 10 became 11 / 2 / 8 / 7 -- and wrote the new record into only
ONE of the two committed evidence directories.  The older record,
`results/zk60_native_privacy_gate/privacy_gate.json`, kept the pre-port labels
and the pre-port tool hashes, and the suite stayed green: nothing compared the
record on disk with the tool that is supposed to have produced it.  No number
in any report was wrong; the record was simply behind.  This file makes the
same drift loud:

  * the channel-label COUNTS are re-derived from each committed record's own
    `channels` array and compared with the record's own `grade.by_status`,
    with the counts of record kept in one small JSON
    (`results/zk60_native_gate_record_refresh/channel_counts_of_record.json`)
    that the report and this test both cite, and with the `after` row of the
    channel table in section 14.1 of
    `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`, parsed narrowly;
  * each record's `tool_sha256` is compared with the hashes of the tools now
    in the tree, the convention `tests/test_zk60_native_run_gate.py` already
    follows -- a tool edited without re-running the gate turns the suite red.

Nothing here asserts a privacy property: counting labels is bookkeeping, and
the labels themselves are what the gate's own tests check.
"""

from __future__ import annotations

import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

import zk60_native_privacy_gate as gate  # noqa: E402

RECORDS = {
    "results/zk60_native_privacy_gate": os.path.join(
        ROOT, "results", "zk60_native_privacy_gate", "privacy_gate.json"
    ),
    "results/zk60_native_privacy_gate_channels": os.path.join(
        ROOT, "results", "zk60_native_privacy_gate_channels", "privacy_gate.json"
    ),
}
PIN = os.path.join(
    ROOT, "results", "zk60_native_gate_record_refresh",
    "channel_counts_of_record.json",
)
REPORT = os.path.join(
    ROOT, "docs", "zkmatrix-poc", "ZK60_NATIVE_JOINT_VIEW.md"
)
STATUSES = ("constructed", "derived", "argued", "open")


def _cells(line):
    """The cells of a markdown table row, outer pipes dropped."""
    parts = line.strip().split("|")
    if parts and parts[0].strip() == "":
        parts = parts[1:]
    if parts and parts[-1].strip() == "":
        parts = parts[:-1]
    return [c.strip() for c in parts]


def report_after_row():
    """The counts in the `after` row of the channel table of section 14.1.

    Narrow on purpose: the section is found by its own heading, the status
    order is read from the table's header row rather than assumed, and the
    row is the one whose first cell says `after`.  A moved table fails here
    loudly instead of silently comparing nothing.
    """
    with open(REPORT) as fh:
        lines = fh.read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("### 14.1"):
            start = i
            break
    if start is None:
        raise AssertionError("section 14.1 not found in " + REPORT)
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("### ") or lines[i].startswith("## "):
            end = i
            break
    order, row = None, None
    for line in lines[start:end]:
        if not line.startswith("|"):
            continue
        cells = _cells(line)
        heads = [c.strip("* ").lower() for c in cells[1:]]
        if order is None and sorted(heads) == sorted(STATUSES):
            order = heads
            continue
        if order is not None and "after" in cells[0].lower():
            row = cells[1:]
            break
    if order is None or row is None:
        raise AssertionError("the channel table's `after` row not found in 14.1")
    return {k: int(v.strip("* ")) for k, v in zip(order, row)}


class GateRecordOfRecord(unittest.TestCase):
    """The two committed P10 records, the pin, the report and the tools."""

    @classmethod
    def setUpClass(cls):
        cls.pin = json.load(open(PIN))
        cls.records = {}
        for name, path in RECORDS.items():
            cls.records[name] = json.load(open(path))

    def test_the_pin_is_the_reports_channel_table(self):
        want = {k: self.pin["by_status"][k] for k in STATUSES}
        self.assertEqual(
            report_after_row(), want,
            "the counts in section 14.1's `after` row and the pin disagree; "
            "whichever moved, move the other",
        )
        self.assertEqual(sum(want.values()), self.pin["channels"])

    def test_every_record_carries_the_counts_of_record(self):
        want = {k: self.pin["by_status"][k] for k in STATUSES}
        for name, rec in self.records.items():
            for cap in rec["per_capture"]:
                got = {k: 0 for k in STATUSES}
                for ch in cap["channels"]:
                    self.assertIn(ch["status"], got, f"{name}: unknown status")
                    got[ch["status"]] += 1
                self.assertEqual(
                    got, want,
                    f"{name}, capture {cap['capture'][:16]}: the channel labels "
                    "on disk are not the counts of record; re-run the gate into "
                    "this evidence directory (the command is in its README)",
                )
                self.assertEqual(len(cap["channels"]), self.pin["channels"])

    def test_every_record_agrees_with_its_own_grade(self):
        for name, rec in self.records.items():
            for cap in rec["per_capture"]:
                got = {k: 0 for k in STATUSES}
                for ch in cap["channels"]:
                    got[ch["status"]] += 1
                by_status = dict(cap["grade"]["by_status"])
                self.assertEqual(
                    {k: by_status.get(k, 0) for k in STATUSES}, got,
                    f"{name}: `grade.by_status` and the `channels` array disagree",
                )
                self.assertEqual(cap["grade"]["channels"], len(cap["channels"]))
                self.assertEqual(cap["grade"]["failures"], [])

    def test_every_record_was_produced_by_the_tools_now_in_the_tree(self):
        want = gate.tool_hashes()
        for name, rec in self.records.items():
            self.assertEqual(
                rec["tool_sha256"], want,
                f"{name}: the record was produced by different tool bytes; "
                "re-run the gate and refresh the evidence (the command is in "
                "that directory's README)",
            )

    def test_the_records_are_ok_and_claim_no_privacy_property(self):
        for name, rec in self.records.items():
            self.assertTrue(rec["ok"], f"{name}: the record is not ok")
            self.assertFalse(rec["privacy_property_established"], name)
            self.assertFalse(rec["is_a_privacy_acceptance"], name)
            self.assertFalse(rec["privacy_review_complete"], name)

    def test_the_pin_names_the_records_it_pins(self):
        for name in RECORDS:
            self.assertIn(
                name + "/privacy_gate.json", self.pin["records"],
                "the pin must name every record it governs",
            )


if __name__ == "__main__":
    unittest.main()
