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


# =====================================================================
#  round 9f (2026-09-22): the two Cargo manifests
# =====================================================================
class TheCargoManifestsArePinnedAndAsserted(unittest.TestCase):
    """Finding P36-2 of the stage-36 pre-read: after the observers delta the
    two Cargo manifests -- and no Rust source -- decide whether the read-only
    test observers can compile into a release build, and neither was pinned.

    The pins live in `scripts/zk60_native_manifest_pins.py` rather than in
    `zk60_native_mask_commit.PATH_PINS` for one reason, written down in that
    module's header: `mask_commit.py` is named by 122 committed records'
    `tool_sha256` maps (the whole run-gate series over the real 125M
    bundles), each asserted equal to the tool bytes in the tree by its own
    test, so a byte changed there demands a re-take this round has no
    business running.  What THIS class insists on is that the separation
    costs nothing: the two manifests are pinned, the digests are the ones
    main carries at `4751b93`, both gates call the check, and the content
    assertion refuses a manifest that ships the observers BY NAME even at a
    digest somebody re-pinned without reading it.
    """

    # read independently of the tool, from the integrator's main branch at
    # 4751b93 (the commit the whole D22 pin set is read at):
    #   git --no-pager -C <main tree> show 4751b93:<path> | sha256sum
    PINS_OF_RECORD = {
        "zkp-core/Cargo.toml":
            "b9038a52f34e0ee8313aa93eec656ff62ea29571a04b3df7f3db349d623ba842",
        "hashline/Cargo.toml":
            "eaba50ecf1434ad8514feb83c6e610b0d662b8fd6d512f26bacdde69163b860a",
    }

    @classmethod
    def setUpClass(cls):
        import zk60_native_manifest_pins as mp
        import zk60_native_mask_commit as mc
        import zk60_native_terminal_polys as tp
        cls.mp, cls.mc, cls.tp = mp, mc, tp

    # ------------------------------------------------------------ the pins
    def test_both_manifests_are_pinned_at_mains_digests(self):
        pinned = {p.path: p.sha256 for p in self.mp.MANIFEST_PINS}
        self.assertEqual(pinned, self.PINS_OF_RECORD)
        for pin in self.mp.MANIFEST_PINS:
            self.assertIn("P36-2", pin.why,
                          "a pin's reason must say why the file is load-bearing")

    def test_the_pins_are_at_the_bytes_in_this_tree_and_nowhere_else(self):
        """The check passes here, and no OTHER pin table claims these two
        files (if one ever does, the two must agree -- see below)."""
        got = self.mp.check_manifest_pins()
        self.assertEqual(sorted(got), sorted(self.PINS_OF_RECORD))
        for path, rec in got.items():
            self.assertEqual(rec["sha256"], self.PINS_OF_RECORD[path])
            self.assertNotIn("accepted_as", rec,
                             "the tree is at the pin of record, not at a "
                             "second accepted digest")

    def test_no_other_pin_table_names_them_at_a_different_digest(self):
        others = {p.path: p.sha256 for p in
                  list(self.mc.SOURCE_PINS) + list(self.mc.PATH_PINS)
                  + list(self.tp.SOURCE_PINS)}
        for path, sha in self.PINS_OF_RECORD.items():
            if path in others:
                self.assertEqual(
                    others[path], sha,
                    f"{path}: the Rust pin tables and the manifest pins "
                    "disagree; one of them is stale")

    def test_a_changed_byte_in_either_manifest_is_refused_by_name(self):
        import shutil
        import tempfile
        for pin in self.mp.MANIFEST_PINS:
            with self.subTest(path=pin.path):
                with tempfile.TemporaryDirectory() as tmp:
                    for other in self.mp.MANIFEST_PINS:
                        dst = os.path.join(tmp, other.path)
                        os.makedirs(os.path.dirname(dst), exist_ok=True)
                        shutil.copyfile(os.path.join(ROOT, other.path), dst)
                    with open(os.path.join(tmp, pin.path), "a") as fh:
                        fh.write("\n# one comment more\n")
                    with self.assertRaises(self.mp.ManifestPinError) as cm:
                        self.mp.check_manifest_pins(root=tmp)
                    msg = str(cm.exception)
                    self.assertIn(pin.path, msg)
                    self.assertIn("MISMATCH", msg)

    def test_a_missing_manifest_is_refused_by_name(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(self.mp.ManifestPinError) as cm:
                self.mp.check_manifest_pins(root=tmp)
            self.assertIn("zkp-core/Cargo.toml", str(cm.exception))

    # --------------------------------------------- the content assertion
    #  The three cases the round was asked for, each with the digest
    #  FORCE-ACCEPTED, which is what a re-pin done without reading the file
    #  would look like: only the content assertion can refuse then.
    ZKP_CORE_HEAD = (
        '[package]\nname = "zkp-core"\nversion = "0.1.0"\n'
        'edition = "2021"\npublish = false\n\n'
    )
    HASHLINE_HEAD = (
        '[package]\nname = "hashline"\nversion = "0.1.0"\n'
        'edition = "2021"\n\n[dependencies]\n'
        'zkp-core = { path = "../zkp-core" }\nblake3 = "1.8"\n\n'
    )

    def _accepting(self, rel, text):
        """`check_manifest_pins` over a tree holding just these two files,
        with every digest accepted, so the content assertion is what speaks."""
        import hashlib
        import shutil
        import tempfile
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        also = {}
        for pin in self.mp.MANIFEST_PINS:
            dst = os.path.join(tmp, pin.path)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if pin.path == rel:
                with open(dst, "w") as fh:
                    fh.write(text)
                also[rel] = {hashlib.sha256(text.encode()).hexdigest():
                             ("n/a", "force-accepted by this test")}
            else:
                shutil.copyfile(os.path.join(ROOT, pin.path), dst)
        return lambda: self.mp.check_manifest_pins(root=tmp, also=also)

    def test_case_1_the_feature_in_default_is_refused_by_name(self):
        """The one-word edit finding P36-2 names."""
        text = (self.ZKP_CORE_HEAD
                + '[features]\ndefault = ["test-observers"]\n'
                  'test-observers = []\n\n[dependencies]\nblake3 = "1.8"\n')
        with self.assertRaises(self.mp.ManifestPinError) as cm:
            self._accepting("zkp-core/Cargo.toml", text)()
        msg = str(cm.exception)
        self.assertIn("zkp-core/Cargo.toml", msg)
        self.assertIn("BY DEFAULT", msg)
        self.assertIn("default = [\"test-observers\"]", msg)
        self.assertIn("P36-2", msg)

    def test_case_1b_any_other_feature_in_default_is_refused_too(self):
        """`default` must be EMPTY, not merely free of this one name: a
        feature that is on by default is a feature the next reader has to
        re-derive the release graph for."""
        text = (self.ZKP_CORE_HEAD
                + '[features]\ndefault = ["std"]\nstd = []\n'
                  'test-observers = []\n')
        with self.assertRaises(self.mp.ManifestPinError) as cm:
            self._accepting("zkp-core/Cargo.toml", text)()
        self.assertIn("BY DEFAULT", str(cm.exception))

    def test_case_1c_the_feature_in_a_normal_dependency_is_refused(self):
        text = (self.ZKP_CORE_HEAD
                + '[features]\ntest-observers = []\n\n[dependencies]\n'
                  'blake3 = { version = "1.8", features = ["test-observers"] }\n')
        with self.assertRaises(self.mp.ManifestPinError) as cm:
            self._accepting("zkp-core/Cargo.toml", text)()
        self.assertIn("[dependencies]", str(cm.exception))

    def test_case_2_declared_and_enabled_only_from_dev_dependencies(self):
        """The shape the integration will bring: zkp-core DECLARES the
        feature and puts it in no default; hashline enables it from
        `[dev-dependencies]` and nowhere else.  Both accepted."""
        core = (self.ZKP_CORE_HEAD
                + '[features]\ntest-observers = []\n\n[dependencies]\n'
                  'blake3 = "1.8"\n')
        got = self._accepting("zkp-core/Cargo.toml", core)()
        ca = got["zkp-core/Cargo.toml"]["content_assertion"]
        self.assertEqual(ca["features_default"], "absent")
        self.assertIn("[features]", ca["test-observers"])

        hl = (self.HASHLINE_HEAD + '[dev-dependencies]\n'
              'zkp-core = { path = "../zkp-core", features = ["test-observers"] }\n')
        got = self._accepting("hashline/Cargo.toml", hl)()
        ca = got["hashline/Cargo.toml"]["content_assertion"]
        self.assertIn("[dev-dependencies]", ca["test-observers"])

    def test_case_2b_a_target_specific_dev_dependency_is_accepted(self):
        hl = (self.HASHLINE_HEAD
              + '[target."cfg(unix)".dev-dependencies]\n'
                'zkp-core = { path = "../zkp-core", features = ["test-observers"] }\n')
        got = self._accepting("hashline/Cargo.toml", hl)()
        self.assertIn('[target."cfg(unix)".dev-dependencies]',
                      got["hashline/Cargo.toml"]["content_assertion"]
                      ["test-observers"])

    def test_case_3_absent_entirely_as_at_4751b93_is_accepted(self):
        """The tree as it stands: neither manifest mentions the feature."""
        got = self.mp.check_manifest_pins()
        for path, rec in got.items():
            self.assertEqual(rec["content_assertion"]["test-observers"],
                             "absent", path)
            self.assertEqual(rec["content_assertion"]["features_default"],
                             "absent", path)

    def test_the_feature_outside_dev_dependencies_in_hashline_is_refused(self):
        for section, line in (
            ("[dependencies]",
             'zkp-core = { path = "../zkp-core", features = ["test-observers"] }'),
            ("[features]", 'debug-draws = ["zkp-core/test-observers"]'),
            ("[build-dependencies]",
             'zkp-core = { path = "../zkp-core", features = ["test-observers"] }'),
            ('[target."cfg(unix)".dependencies]',
             'zkp-core = { path = "../zkp-core", features = ["test-observers"] }'),
        ):
            with self.subTest(section=section):
                hl = (self.HASHLINE_HEAD + section + "\n" + line + "\n")
                with self.assertRaises(self.mp.ManifestPinError) as cm:
                    self._accepting("hashline/Cargo.toml", hl)()
                msg = str(cm.exception)
                self.assertIn("hashline/Cargo.toml", msg)
                self.assertIn(section.strip("[]"), msg)

    def test_a_manifest_the_scanner_cannot_read_is_refused_not_passed(self):
        text = self.ZKP_CORE_HEAD + '[features\ntest-observers = []\n'
        with self.assertRaises(self.mp.ManifestPinError) as cm:
            self._accepting("zkp-core/Cargo.toml", text)()
        self.assertIn("cannot be read as TOML", str(cm.exception))

    # -------------------------------------------------- the scanner itself
    def test_the_scanner_reads_comments_quotes_and_multi_line_arrays(self):
        target = 'target."cfg(any(unix, windows))".dev-dependencies'
        text = (
            '[package]\n'
            'name = "x"  # a trailing comment\n'
            'description = "a # inside a string is not a comment"\n'
            "[features]\n"
            "default = [\n"
            "  # a comment inside the array\n"
            '  "a",\n'
            '  "b",\n'
            "]\n"
            "[" + target + "]\n"
            'y = { path = "../y", features = ["test-observers"] }\n'
        )
        entries = self.mp.read_manifest(text)
        by_key = {(e.section, e.key): e for e in entries}
        self.assertEqual(by_key[("package", "description")].value,
                         '"a # inside a string is not a comment"')
        self.assertEqual(self.mp._array_items(
            by_key[("features", "default")].value), ["a", "b"])
        self.assertEqual(by_key[(target, "y")].kind, "dev-dependencies")
        self.assertEqual(self.mp.section_kind("dependencies"), "dependencies")
        self.assertEqual(self.mp.section_kind("target.'cfg(unix)'.dependencies"),
                         "dependencies")
        for bad in ('[features\nx = 1\n', 'x = [1,\n', 'nonsense\n',
                    'x = "unterminated\n'):
            with self.subTest(bad=bad):
                with self.assertRaises(ValueError):
                    self.mp.read_manifest(bad)

    # ------------------------------------------------------- the two gates
    def test_both_gates_call_the_check_and_name_the_tool(self):
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            with self.subTest(gate=name):
                self.assertIs(gate.check_manifest_pins,
                              self.mp.check_manifest_pins)
                self.assertIn("zk60_native_manifest_pins.py", gate.TOOLS,
                              "a tool whose bytes decide a refusal must be in "
                              "the record's tool_sha256 map")
                self.assertIn("zk60_native_manifest_pins.py",
                              gate.tool_hashes())

    def test_both_gates_refuse_and_return_3_instead_of_running(self):
        """The callers' half: the refusal comes before anything is read, so
        it costs nothing and writes NO record."""
        import contextlib
        import io
        import shutil
        import tempfile
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10

        def raiser():
            raise self.mp.ManifestPinError(
                "manifest pin MISMATCH for zkp-core/Cargo.toml: (test)")

        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            with self.subTest(gate=name):
                ev = os.path.join(tmp, name)
                os.makedirs(ev)
                keep = gate.check_manifest_pins
                gate.check_manifest_pins = raiser
                err = io.StringIO()
                try:
                    with contextlib.redirect_stderr(err):
                        rc = gate.main(["--captures", tmp, "--evidence", ev])
                finally:
                    gate.check_manifest_pins = keep
                self.assertEqual(rc, 3)
                self.assertIn("REFUSED (Cargo manifest pins)", err.getvalue())
                self.assertIn("zkp-core/Cargo.toml", err.getvalue())
                self.assertEqual(os.listdir(ev), [],
                                 "a refused run must write no record")

    # --------------------------------------- what the integration will bring
    def test_the_post_integration_digests_are_recorded_and_not_accepted(self):
        """The lane's own manifests (`a8e4939`) are written down so the next
        reader does not have to find them, and are NOT in the accepted set:
        the pin moves once, against the integrator's merged tree."""
        after = self.mp.EXPECTED_AFTER_INTEGRATION
        for path in self.PINS_OF_RECORD:
            self.assertIn(path, after)
            self.assertNotEqual(after[path]["sha256"],
                                self.PINS_OF_RECORD[path])
            self.assertNotIn(after[path]["sha256"],
                             self.mp.ALSO_ACCEPTED.get(path, {}))
            self.assertTrue(after[path]["would_the_content_assertion_accept_it"])
        self.assertEqual(self.mp.ALSO_ACCEPTED, {})


# =====================================================================
#  round 9h (2026-09-22): the private-attention profile's three files
# =====================================================================
class TheAttentionProfilesPathIsPinned(unittest.TestCase):
    """Round 9g §R9g.8: three Rust files on the PRIVATE ATTENTION profile's
    proving and verifying path were named by no pin table, while two of the
    four toy captures of record are attention receipts -- so for those two,
    condition 7 of the toy profile's accepted privacy statement ("every file
    on the path") was not met.  The security owner ruled they join the pin
    set; `scripts/zk60_native_profile_pins.py` is that pin.

    The pins live in their own module for round 9f's reason, unchanged:
    `mask_commit.py` is named by 122 committed records' `tool_sha256` maps
    and `terminal_polys.py` by 8, so a byte there stales the run-gate series.
    They are not folded into `zk60_native_manifest_pins.py` either -- that
    module is the two CARGO MANIFESTS and finding P36-2, and a Rust source
    pin filed under a name that says "manifest" would mislead the reader at
    the moment the refusal fires.  What THIS class insists on is that the
    separation costs nothing.
    """

    # read independently of the tool, from the integrator's main branch at
    # 4751b93 (the commit the whole D22 pin set is read at):
    #   git --no-pager -C <main tree> show 4751b93:<path> | sha256sum
    PINS_OF_RECORD = {
        "hashline/src/private_attention.rs":
            "dfc02d91356974b0cf4c6c0c672ec14660aa4b90b808236de81486272f010923",
        "hashline/src/private_attention/wire.rs":
            "a35a468cf19eb672e5428c3286a3ece15f73e96e20291a220cf38dd4104dbdff",
        "hashline/src/private_attention/witness.rs":
            "795cf6292e366bc48d1c1987b9a3173f9a19e266de537f72a9e738bdb5133ee0",
    }

    # the attention profile's OWN six files: the root and its five modules,
    # `tests.rs` excluded because it is `#[cfg(test)]`.  After round 9h every
    # one of them must be pinned by SOME table.
    PROFILE_FILES = {
        "hashline/src/private_attention.rs",
        "hashline/src/private_attention/argument.rs",
        "hashline/src/private_attention/layout.rs",
        "hashline/src/private_attention/protocol.rs",
        "hashline/src/private_attention/wire.rs",
        "hashline/src/private_attention/witness.rs",
    }

    @classmethod
    def setUpClass(cls):
        import zk60_native_manifest_pins as mp
        import zk60_native_mask_commit as mc
        import zk60_native_profile_pins as pp
        import zk60_native_terminal_polys as tp
        cls.mp, cls.mc, cls.pp, cls.tp = mp, mc, pp, tp
        cls.elsewhere = {p.path: p.sha256 for p in
                         list(mc.SOURCE_PINS) + list(mc.PATH_PINS)
                         + list(tp.SOURCE_PINS)}

    # ------------------------------------------------------------ the pins
    def test_the_three_are_pinned_at_mains_digests(self):
        pinned = {p.path: p.sha256 for p in self.pp.PROFILE_PINS}
        self.assertEqual(pinned, self.PINS_OF_RECORD)
        for pin in self.pp.PROFILE_PINS:
            self.assertTrue(pin.why.strip(),
                            "a pin's reason must say what the file is")
            self.assertEqual(len(pin.blob), 40)

    def test_the_pins_are_at_the_bytes_in_this_tree(self):
        got = self.pp.check_profile_pins()
        self.assertEqual(sorted(got), sorted(self.PINS_OF_RECORD))
        for path, rec in got.items():
            self.assertEqual(rec["sha256"], self.PINS_OF_RECORD[path])
            self.assertEqual(rec["pin_kind"], "on-the-attention-path")
            self.assertNotIn("accepted_as", rec,
                             "the tree is at the pin of record, not at a "
                             "second accepted digest")

    def test_no_other_pin_table_names_them_at_a_different_digest(self):
        """The three tables that could disagree: the two Rust ones and round
        9f's manifest pins.  None of them should name these files at all
        today, and if one ever does, the digests must agree."""
        others = dict(self.elsewhere)
        others.update({p.path: p.sha256 for p in self.mp.MANIFEST_PINS})
        for path, sha in self.PINS_OF_RECORD.items():
            if path in others:
                self.assertEqual(
                    others[path], sha,
                    f"{path}: another pin table and the profile pins "
                    "disagree; one of them is stale")

    def test_a_changed_byte_in_each_of_the_three_is_refused_by_name(self):
        """One byte flipped in EVERY newly pinned file, one at a time, in a
        throwaway tree: each must raise and each message must name its own
        file.  The other two are copied unchanged, so the refusal can only be
        this one's."""
        import shutil
        import tempfile
        for pin in self.pp.PROFILE_PINS:
            with self.subTest(path=pin.path):
                with tempfile.TemporaryDirectory() as tmp:
                    for other in self.pp.PROFILE_PINS:
                        dst = os.path.join(tmp, other.path)
                        os.makedirs(os.path.dirname(dst), exist_ok=True)
                        shutil.copyfile(os.path.join(ROOT, other.path), dst)
                    with open(os.path.join(tmp, pin.path), "ab") as fh:
                        fh.write(b"\n// one byte more\n")
                    with self.assertRaises(self.pp.ProfilePinError) as cm:
                        self.pp.check_profile_pins(root=tmp)
                    msg = str(cm.exception)
                    self.assertIn(pin.path, msg)
                    self.assertIn("MISMATCH", msg)
                    self.assertIn("PRIVATE ATTENTION PROFILE'S PATH", msg)

    def test_a_missing_file_is_refused_by_name(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(self.pp.ProfilePinError) as cm:
                self.pp.check_profile_pins(root=tmp)
            self.assertIn("private_attention.rs", str(cm.exception))

    def test_an_unchanged_copy_still_passes(self):
        """The control for the test above: the same throwaway tree with
        nothing flipped passes, so the refusals are the perturbation's and
        not the copying's."""
        import shutil
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            for pin in self.pp.PROFILE_PINS:
                dst = os.path.join(tmp, pin.path)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(os.path.join(ROOT, pin.path), dst)
            self.assertEqual(len(self.pp.check_profile_pins(root=tmp)), 3)

    # ------------------------------------------------- the path is covered
    def test_the_profiles_six_files_are_all_pinned_now(self):
        """The point of the round: no file of the attention profile is left
        uncompared.  The three new ones here, the other three where the
        module says they are -- checked against the tables, not the prose."""
        pinned = set(self.elsewhere) | {p.path for p in self.pp.PROFILE_PINS}
        missing = self.PROFILE_FILES - pinned
        self.assertEqual(
            missing, set(),
            "these files are on the attention profile's path and NOTHING "
            "pins them: " + ", ".join(sorted(missing)))
        for path, where in self.pp.ALREADY_PINNED_ELSEWHERE.items():
            self.assertIn(path, self.elsewhere,
                          f"{path}: the module says it is pinned elsewhere "
                          f"({where}) and it is not")
        self.assertEqual(
            set(self.pp.ALREADY_PINNED_ELSEWHERE) |
            {p.path for p in self.pp.PROFILE_PINS},
            self.PROFILE_FILES,
            "the module's two lists together must be exactly the profile's "
            "six files")

    def test_every_crate_module_the_profile_imports_is_pinned(self):
        """Coverage, derived rather than asserted: every `use crate::<m>` in
        the profile's six files must resolve to a hashline file some table
        pins, or to one of the three the tool NAMES as fixture-only (reached
        from `synthetic_fixture`, which makes the public test data, and so
        off the prover's and the verifier's path by the owner's own words).
        A future attention file that reaches into any other unpinned module
        turns this red instead of widening the hole silently."""
        pinned = set(self.elsewhere) | {p.path for p in self.pp.PROFILE_PINS}
        fixture_only = set(self.mc.FIXTURE_PATH_NOT_PINNED)
        seen = {}
        for rel in sorted(self.PROFILE_FILES):
            with open(os.path.join(ROOT, rel)) as fh:
                text = fh.read()
            for m in re.findall(r"\buse crate::(\w+)", text) + \
                    re.findall(r"\bcrate::(\w+)::", text):
                cand = f"hashline/src/{m}.rs"
                if not os.path.exists(os.path.join(ROOT, cand)):
                    cand = f"hashline/src/{m}/mod.rs"
                seen.setdefault(cand, set()).add(rel)
        self.assertGreaterEqual(len(seen), 8, "the scan found almost nothing; "
                                "the import syntax must have changed")
        for cand, who in sorted(seen.items()):
            with self.subTest(module=cand):
                self.assertIn(
                    cand, pinned | fixture_only,
                    f"{cand} is reached from {sorted(who)} and nothing pins "
                    "it; read it and add it to a pin table")
        # and the fixture-only exception stays the documented one: today
        # exactly `causal_oracle.rs`, from the root's `synthetic_fixture`.
        self.assertEqual(
            sorted(set(seen) - pinned),
            ["hashline/src/causal_oracle.rs"],
            "the only unpinned module the attention profile names must be "
            "the public fixture's, with its reason in "
            "`zk60_native_mask_commit.FIXTURE_PATH_NOT_PINNED`")
        for rel in sorted(set(seen) - pinned):
            self.assertTrue(self.mc.FIXTURE_PATH_NOT_PINNED[rel].strip())

    def test_none_of_the_three_is_a_test_only_module(self):
        """`private_block/{norm_alias,parity,refusals,tamper,tests}.rs` are
        out of the pin set because they are `#[cfg(test)]`.  These three are
        in it because they are not: the root declares `mod wire;` and `mod
        witness;` with no attribute above them, and the line that IS gated
        (`mod tests;`) shows the file distinguishes the two."""
        path = os.path.join(ROOT, "hashline/src/private_attention.rs")
        with open(path) as fh:
            lines = fh.read().splitlines()
        for decl in ("mod wire;", "mod witness;"):
            with self.subTest(decl=decl):
                i = [n for n, ln in enumerate(lines) if ln.strip() == decl]
                self.assertEqual(len(i), 1, f"{decl} not declared exactly once")
                self.assertFalse(
                    lines[i[0] - 1].strip().startswith("#["),
                    f"{decl} has an attribute above it; if it is now "
                    "cfg-gated the pin's justification has changed")
        j = [n for n, ln in enumerate(lines) if ln.strip() == "mod tests;"]
        self.assertEqual(len(j), 1)
        self.assertEqual(lines[j[0] - 1].strip(), "#[cfg(test)]")

    # ------------------------------------------------------- the two gates
    def test_both_gates_call_the_check_and_name_the_tool(self):
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            with self.subTest(gate=name):
                self.assertIs(gate.check_profile_pins,
                              self.pp.check_profile_pins)
                self.assertIn("zk60_native_profile_pins.py", gate.TOOLS,
                              "a tool whose bytes decide a refusal must be in "
                              "the record's tool_sha256 map")
                self.assertIn("zk60_native_profile_pins.py",
                              gate.tool_hashes())

    def test_both_gates_call_it_unconditionally_and_before_any_capture(self):
        """Not gated on the capture's profile, and not after the captures
        have been read: a gate run reads the whole capture directory, which
        holds two block receipts and two attention ones."""
        import inspect
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            with self.subTest(gate=name):
                src = inspect.getsource(gate.main)
                self.assertIn("check_profile_pins()", src,
                              "the call takes no profile argument: it is the "
                              "same rule for every toy run")
                self.assertLess(
                    src.index("check_profile_pins()"), src.index("load_all("),
                    "the check must come before anything is read")

    def test_both_gates_refuse_and_return_3_instead_of_running(self):
        """The callers' half: the refusal comes before anything is read, so
        it costs nothing and writes NO record."""
        import contextlib
        import io
        import shutil
        import tempfile
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10

        def raiser():
            raise self.pp.ProfilePinError(
                "profile pin MISMATCH for "
                "hashline/src/private_attention/wire.rs: (test)")

        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            with self.subTest(gate=name):
                ev = os.path.join(tmp, name)
                os.makedirs(ev)
                keep = gate.check_profile_pins
                gate.check_profile_pins = raiser
                err = io.StringIO()
                try:
                    with contextlib.redirect_stderr(err):
                        rc = gate.main(["--captures", tmp, "--evidence", ev])
                finally:
                    gate.check_profile_pins = keep
                self.assertEqual(rc, 3)
                self.assertIn("REFUSED (attention profile pins)", err.getvalue())
                self.assertIn("private_attention/wire.rs", err.getvalue())
                self.assertEqual(os.listdir(ev), [],
                                 "a refused run must write no record")

    # ------------------------------------- what the integration will bring
    def test_the_lane_carries_the_same_bytes_and_nothing_is_pre_accepted(self):
        """Unlike round 9f's manifests, the block lane (`a8e4939`) has not
        touched these three, so there is no post-integration digest to
        expect.  The module records that as data and the accepted set stays
        empty."""
        lane = self.pp.LANE_DIGESTS
        self.assertTrue(lane["identical_to_main"])
        self.assertEqual(lane["digests"], self.PINS_OF_RECORD)
        self.assertEqual(self.pp.ALSO_ACCEPTED, {})


if __name__ == "__main__":
    unittest.main()
