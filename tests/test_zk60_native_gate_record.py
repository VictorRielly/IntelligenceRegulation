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


# =====================================================================
#  round 5 (2026-09-20): the PATH pins
# =====================================================================
class ThePathPinsCoverThePath(unittest.TestCase):
    """The security owner's ruling of 22:06: the pin set of step 3's
    instrument covers EVERY Rust file on the toy block profile's path, not
    only the ones a Python port transcribes.

    The list itself is the reading recorded in
    `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md` round 5 and
    `ZK60_NATIVE_D22_REPIN_4751B93.md` §7; it is kept HERE as data so that
    adding a file to the path without pinning it turns the suite red.
    """

    # every Rust source the toy block profile's prover and verifier reach.
    # Test-only modules and the public-fixture path are deliberately absent;
    # the tool's own comment says why, and `FIXTURE_PATH_NOT_PINNED` names
    # the three fixture files.
    PATH = {
        "hashline/src/lib.rs",
        "hashline/src/private_block.rs",
        "hashline/src/private_block/argument.rs",
        "hashline/src/private_block/layout.rs",
        "hashline/src/private_block/protocol.rs",
        "hashline/src/private_block/wire.rs",
        "hashline/src/private_block/witness.rs",
        "hashline/src/private_seam.rs",
        "hashline/src/zk.rs",
        "hashline/src/pcs.rs",
        "hashline/src/merkle.rs",
        "hashline/src/transcript.rs",
        "hashline/src/field.rs",
        "hashline/src/ntt.rs",
        "hashline/src/mle.rs",
        "hashline/src/sumcheck.rs",
        "hashline/src/tables_attn.rs",
        "hashline/src/gpu/mod.rs",
        "hashline/src/native_capture.rs",
        "zkp-core/src/lib.rs",
        "zkp-core/src/field.rs",
        "zkp-core/src/merkle.rs",
        "zkp-core/src/mle.rs",
        "zkp-core/src/ntt.rs",
        "zkp-core/src/pcs.rs",
        "zkp-core/src/pcs/backend.rs",
        "zkp-core/src/rng.rs",
        "zkp-core/src/sumcheck.rs",
        "zkp-core/src/transcript.rs",
    }

    @classmethod
    def setUpClass(cls):
        import zk60_native_mask_commit as mc
        import zk60_native_terminal_polys as tp
        cls.mc, cls.tp = mc, tp
        cls.pinned = {p.path for p in mc.SOURCE_PINS} | {
            p.path for p in mc.PATH_PINS}

    def test_the_pin_table_covers_exactly_the_established_path(self):
        """Neither direction is allowed to drift: a file added to the path
        without a pin fails here, and a pin for a file that is NOT on the
        path fails here too (it would be a pin nobody can justify)."""
        missing = self.PATH - self.pinned
        self.assertEqual(
            missing, set(),
            "these files are on the toy block profile's path and NOTHING "
            "pins them; read each one and add it to PATH_PINS with a line "
            "saying what it is: " + ", ".join(sorted(missing)),
        )
        extra = self.pinned - self.PATH - {
            # the attention profile's argument, pinned by this tool since
            # round 1 because two of the four captures are attention ones
            "hashline/src/private_attention/argument.rs",
        }
        self.assertEqual(
            extra, set(),
            "these paths are pinned but are not on the established list; "
            "either the list is stale or the pin cannot be justified: "
            + ", ".join(sorted(extra)),
        )

    def test_every_pin_is_at_the_bytes_in_this_tree(self):
        """The whole widened table passes on the tree as it stands."""
        got = self.mc.check_source_pins()
        self.assertEqual(len(got), len(self.mc.SOURCE_PINS)
                         + len(self.mc.PATH_PINS))
        on_path = [k for k, v in got.items() if v["pin_kind"] == "on-the-path"]
        self.assertEqual(len(on_path), len(self.mc.PATH_PINS))

    def test_a_changed_byte_in_any_newly_pinned_file_is_refused_by_name(self):
        """One byte flipped in EVERY path-pinned file, one at a time, in a
        throwaway tree: each must raise and each message must name its own
        file.  This is the property the ruling asks for, exercised on every
        file rather than on a representative one."""
        import shutil
        import tempfile
        for pin in self.mc.PATH_PINS:
            with self.subTest(path=pin.path):
                with tempfile.TemporaryDirectory() as tmp:
                    src = os.path.join(ROOT, pin.path)
                    dst = os.path.join(tmp, pin.path)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copyfile(src, dst)
                    # every OTHER pinned file, unchanged, so the failure can
                    # only be this one
                    for other in list(self.mc.SOURCE_PINS) + list(
                            self.mc.PATH_PINS):
                        if other.path == pin.path:
                            continue
                        o = os.path.join(tmp, other.path)
                        os.makedirs(os.path.dirname(o), exist_ok=True)
                        shutil.copyfile(os.path.join(ROOT, other.path), o)
                    with open(dst, "ab") as fh:
                        fh.write(b"\n// one byte more\n")
                    with self.assertRaises(self.mc.SourcePinError) as cm:
                        self.mc.check_source_pins(root=tmp)
                    msg = str(cm.exception)
                    self.assertIn(pin.path, msg)
                    self.assertIn("ON THE TOY BLOCK PROFILE'S PATH", msg)

    def test_an_unchanged_tree_with_the_path_pins_still_passes(self):
        """The control for the test above: the same throwaway tree with
        nothing flipped passes, so the refusals are the perturbation's and
        not the copying's."""
        import shutil
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            for pin in list(self.mc.SOURCE_PINS) + list(self.mc.PATH_PINS):
                o = os.path.join(tmp, pin.path)
                os.makedirs(os.path.dirname(o), exist_ok=True)
                shutil.copyfile(os.path.join(ROOT, pin.path), o)
            got = self.mc.check_source_pins(root=tmp)
            self.assertEqual(len(got), len(self.mc.SOURCE_PINS)
                             + len(self.mc.PATH_PINS))

    def test_the_two_pin_tables_agree_where_they_overlap(self):
        """Four files are pinned by BOTH this tool and
        `zk60_native_terminal_polys` (the joint-view gate's table), so that
        the P10 privacy gate covers them too.  If the two ever name
        different digests for one file, one of them is stale."""
        theirs = {p.path: p.sha256 for p in self.tp.SOURCE_PINS}
        overlap = 0
        for pin in list(self.mc.SOURCE_PINS) + list(self.mc.PATH_PINS):
            if pin.path in theirs:
                overlap += 1
                self.assertEqual(
                    pin.sha256, theirs[pin.path],
                    f"{pin.path}: zk60_native_mask_commit and "
                    "zk60_native_terminal_polys pin different digests",
                )
        self.assertGreaterEqual(overlap, 5)

    def test_the_fixture_path_is_named_and_not_pinned(self):
        """The three files reached only by the public fixtures are recorded
        with a reason and deliberately left out, so 'not pinned' is a
        decision on the page rather than an omission."""
        for path in self.mc.FIXTURE_PATH_NOT_PINNED:
            self.assertNotIn(path, self.pinned)
            self.assertTrue(self.mc.FIXTURE_PATH_NOT_PINNED[path].strip())
        self.assertEqual(len(self.mc.FIXTURE_PATH_NOT_PINNED), 3)


if __name__ == "__main__":
    unittest.main()
