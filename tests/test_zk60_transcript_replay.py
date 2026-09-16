#!/usr/bin/env python3
"""Tests of scripts/zk60_transcript_replay.py against the round-22 captures.

Run:  python3 -m unittest discover -s tests -p 'test_zk60_transcript_replay.py' -v

The four capture triplets live in the main tree at
results/zk60_round22_captures/ (read-only inputs; the tests skip if they are
absent). Each capture's JSON is parsed once per process and cached.
"""
import copy
import json
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPTS = os.path.join(ROOT, "scripts")
if SCRIPTS not in sys.path:
    sys.path.insert(0, SCRIPTS)

import zk60_transcript_replay as replay  # noqa: E402
from zk60_blake3_pure import blake3_hash  # noqa: E402

CAPTURES_DIR = "/home/victor/IntelligenceRegulation/results/zk60_round22_captures"
MANIFEST = "/home/victor/IntelligenceRegulation/results/zk60_round22_captures.json"

try:
    import blake3 as _wheel
    WHEEL = lambda b: _wheel.blake3(b).digest()  # noqa: E731
except ImportError:  # pragma: no cover - the wheel is installed on this box
    WHEEL = None

HAVE_CAPTURES = os.path.exists(MANIFEST) and os.path.isdir(CAPTURES_DIR)

_CACHE = {}


def _manifest():
    if "manifest" not in _CACHE:
        with open(MANIFEST, "r") as f:
            _CACHE["manifest"] = json.load(f)
    return _CACHE["manifest"]


def _cases():
    m = _manifest()
    return [(os.path.basename(c["path"])[:-5], c) for c in m["captures"]["cases"]]


def _capture(sha):
    if sha not in _CACHE:
        _CACHE[sha] = replay.load_capture(CAPTURES_DIR, sha)
    return _CACHE[sha]


def _hasher():
    return WHEEL if WHEEL is not None else blake3_hash


def _replay(sha, tamper=None, hasher=None):
    cap = _capture(sha)
    case = dict(_cases())[sha]
    return replay.replay_capture(cap, hasher or _hasher(), tamper=tamper, manifest_case=case, want_history=False)


def _first_failed_transcript_checkpoint(res):
    for c in res["checkpoints"]:
        if c["kind"] == "transcript" and not c["ok"]:
            return c["name"]
    return None


def _flip_low_bit(v):
    c0, c1 = v
    c0 ^= 1
    if c0 >= replay.P:
        c0 ^= 3
    return (c0, c1)


class TestPureBlake3(unittest.TestCase):
    def test_matches_known_empty_digest(self):
        self.assertEqual(blake3_hash(b"").hex(), "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262")

    @unittest.skipIf(WHEEL is None, "blake3 wheel not importable")
    def test_matches_wheel_on_random_inputs(self):
        rng = random.Random(20260915)
        lengths = [0, 1, 63, 64, 65, 1023, 1024, 1025, 2047, 2048, 2049, 4096, 5000]
        lengths += [rng.randint(0, 5000) for _ in range(40)]
        for n in lengths:
            data = bytes(rng.getrandbits(8) for _ in range(n))
            self.assertEqual(blake3_hash(data), WHEEL(data), "length %d" % n)


class TestTranscriptPrimitives(unittest.TestCase):
    def test_init_state_is_blake3_of_prefixed_domain(self):
        for domain in (replay.PROFILE, b"t", b"", b"x" * 100):
            for h in [blake3_hash] + ([WHEEL] if WHEEL else []):
                tr = replay.Transcript(domain, h)
                self.assertEqual(tr.state, h(b"hashline-v1/" + domain))
                self.assertEqual(tr.counter, 0)

    def test_absorb_and_squeeze_layout(self):
        h = _hasher()
        tr = replay.Transcript(b"t", h)
        tr.absorb(b"x", b"\x01\x02\x03")
        want = h(h(b"hashline-v1/t") + (1).to_bytes(8, "little") + b"x" + (3).to_bytes(8, "little") + b"\x01\x02\x03")
        self.assertEqual(tr.state, want)
        out = tr.squeeze("s")
        self.assertEqual(out, h(want + b"squeeze" + (0).to_bytes(8, "little")))
        self.assertEqual(tr.state, out)
        self.assertEqual(tr.counter, 1)
        idx = replay.Transcript(b"t", h).challenge_indices(100, 1024, "i")
        self.assertEqual(len(idx), 100)
        self.assertTrue(all(0 <= i < 1024 for i in idx))

    def test_pure_and_wheel_transcripts_agree(self):
        if WHEEL is None:
            self.skipTest("blake3 wheel not importable")
        a = replay.Transcript(replay.PROFILE, blake3_hash)
        b = replay.Transcript(replay.PROFILE, WHEEL)
        for tr in (a, b):
            tr.absorb(b"expected-IO", bytes(range(112)))
            tr.absorb_fp2(b"sc-round", [(1, 2), (3, 4), (5, 6)])
        self.assertEqual(a.challenge_fp2("c"), b.challenge_fp2("c"))
        self.assertEqual(a.challenge_indices(9, 4096, "i"), b.challenge_indices(9, 4096, "i"))
        self.assertEqual(a.state, b.state)

    def test_table_regenerates_to_the_frozen_pin(self):
        table = replay.silu_int16out_generate(-3, -11)
        self.assertEqual(min(table), -570)
        self.assertEqual(max(table), 32512)
        self.assertEqual(replay.silu_table_spec_digest(-3, -11, table), replay.FROZEN_SILU_DIGEST_M3_M11)

    def test_interpolate_eval_matches_lagrange_on_nodes(self):
        vals = [(5, 7), (11, 13), (17, 19), (23, 29), (31, 37)]
        for j, v in enumerate(vals):
            self.assertEqual(replay.interpolate_eval(vals, (j, 0)), v)


@unittest.skipUnless(HAVE_CAPTURES, "round-22 captures not present")
class TestManifest(unittest.TestCase):
    def test_manifest_hashes(self):
        checks, shas, _ = replay.check_manifest(_manifest(), CAPTURES_DIR, ROOT)
        self.assertEqual(len(shas), 4)
        bad = [c for c in checks if not c["ok"]]
        self.assertEqual(bad, [])
        self.assertTrue(any(c["name"].startswith("source.") for c in checks))


@unittest.skipUnless(HAVE_CAPTURES, "round-22 captures not present")
class TestBinding(unittest.TestCase):
    def test_binding_matches_receipt_bytes_8_40_on_all_captures(self):
        for sha, _ in _cases():
            cap = _capture(sha)
            js = cap["json"]
            st, _ = replay.reconstruct_statement(js)
            lay = replay.layout_numbers(st)
            rec = replay.parse_receipt(cap["receipt"], js["privacy"], lay)
            for h in [blake3_hash] + ([WHEEL] if WHEEL else []):
                got = replay.binding_state(h, cap["expected"], st, js["privacy"], rec["w_com"]["root"])
                self.assertEqual(got, cap["receipt"][8:40], "%s %s" % (sha[:8], js["privacy"]))


@unittest.skipUnless(HAVE_CAPTURES, "round-22 captures not present")
class TestFullReplay(unittest.TestCase):
    def test_every_checkpoint_passes_on_all_captures(self):
        seen = {"P1": 0, "P3": 0}
        for sha, _ in _cases():
            res = _replay(sha)
            bad = [c["name"] for c in res["checkpoints"] if not c["ok"]]
            self.assertEqual(bad, [], "%s: %s" % (sha[:8], bad))
            self.assertTrue(res["ok"])
            names = [c["name"] for c in res["checkpoints"] if c["kind"] == "transcript"]
            want = ["binding.receipt[8:40]", "io[0].before", "io[0].after", "io[1].before", "io[1].after",
                    "M.before", "M.after"]
            if res["privacy"] == "P3":
                want += ["W.before", "W.after"]
            else:
                want += ["W(public).before", "W(public).after"]
            want += ["A.before", "A.after", "H.before", "H.after", "Input.before", "Input.after",
                     "Output.before", "Output.after"]
            self.assertEqual(names, want)
            self.assertEqual([s["name"] for s in res["ffn_slots"]], ["gu", "d", "zc20", "zc17", "tab", "zs"])
            ext = 2 if res["privacy"] == "P3" else 1
            self.assertEqual([len(s["rho"]) for s in res["ffn_slots"]], [4 + ext, 4 + ext, 10, 10, 17, 9])
            self.assertEqual([len(s["rho"]) for s in res["io_slots"]], [10, 10])
            for s in res["ffn_slots"] + res["io_slots"]:
                self.assertNotEqual(s["c"], [0, 0])
            seen[res["privacy"]] += 1
        self.assertEqual(seen, {"P1": 2, "P3": 2})

    def test_pure_backend_replays_one_capture(self):
        sha = _cases()[1][0]  # a P1 capture (public W opening included)
        res = _replay(sha, hasher=blake3_hash)
        self.assertTrue(res["ok"], [c["name"] for c in res["checkpoints"] if not c["ok"]])


@unittest.skipUnless(HAVE_CAPTURES, "round-22 captures not present")
class TestNegativeControls(unittest.TestCase):
    def test_flipping_one_ffn_round_bit_fails_the_next_checkpoint(self):
        for sha, _ in _cases()[:2]:
            def tamper(rec):
                r = rec["ffn"]["gu"]["rounds"][0]
                r[0] = _flip_low_bit(r[0])
            res = _replay(sha, tamper=tamper)
            self.assertFalse(res["ok"])
            by_name = {c["name"]: c for c in res["checkpoints"]}
            self.assertTrue(by_name["binding.receipt[8:40]"]["ok"])
            self.assertEqual(_first_failed_transcript_checkpoint(res), "io[0].before")
            self.assertFalse(by_name["gu.sumcheck-chain(s0+s1==claim, %d rounds)" % (5 if res["privacy"] == "P1" else 6)]["ok"])
            self.assertFalse(by_name["json.ffn_arguments.gu.rounds==receipt"]["ok"])

    def test_flipping_one_io_round_bit_fails_the_argument_checkpoint(self):
        sha = _cases()[0][0]

        def tamper(rec):
            r = rec["arguments"][0]["rounds"][3]
            r[1] = _flip_low_bit(r[1])
        res = _replay(sha, tamper=tamper)
        self.assertFalse(res["ok"])
        by_name = {c["name"]: c for c in res["checkpoints"]}
        self.assertTrue(by_name["io[0].before"]["ok"])
        self.assertEqual(_first_failed_transcript_checkpoint(res), "io[0].after")
        self.assertFalse(by_name["io[0].rho==json"]["ok"])
        self.assertFalse(by_name["io[0].sumcheck-chain(s0+s1==claim, 10 rounds)"]["ok"])

    def test_counter_off_by_one_breaks_next(self):
        sha = _cases()[0][0]
        res = _replay(sha)
        cap = _capture(sha)
        h = _hasher()
        checked = 0
        for c in res["checkpoints"]:
            if c["kind"] != "transcript" or c["name"] == "binding.receipt[8:40]":
                continue
            state = bytes.fromhex(c["want_state"])
            want_next = tuple(c["want_next"])
            right = replay.Transcript(hasher=h, state=state, counter=c["counter"])
            self.assertEqual(right.next_challenge(), want_next, c["name"])
            for delta in (1, -1):
                wrong = replay.Transcript(hasher=h, state=state, counter=c["counter"] + delta)
                self.assertNotEqual(wrong.next_challenge(), want_next, c["name"])
            checked += 1
        self.assertGreaterEqual(checked, 16)
        del cap

    def test_wrong_statement_field_breaks_the_binding_only(self):
        sha = _cases()[1][0]
        cap = _capture(sha)
        js = cap["json"]
        st, _ = replay.reconstruct_statement(js)
        lay = replay.layout_numbers(st)
        rec = replay.parse_receipt(cap["receipt"], js["privacy"], lay)
        good = replay.binding_state(_hasher(), cap["expected"], st, js["privacy"], rec["w_com"]["root"])
        self.assertEqual(good, cap["receipt"][8:40])
        for field, bad_value in (("l", 1), ("shifts", (7, 0, 14, 5)), ("table_digest", "0" * 64)):
            st2 = dict(st)
            st2[field] = bad_value
            self.assertNotEqual(replay.binding_state(_hasher(), cap["expected"], st2, js["privacy"], rec["w_com"]["root"]),
                                cap["receipt"][8:40], field)
        st3 = dict(st)
        st3["table"] = list(st["table"])
        st3["table"][0] ^= 1
        self.assertNotEqual(replay.binding_state(_hasher(), cap["expected"], st3, js["privacy"], rec["w_com"]["root"]),
                            cap["receipt"][8:40])

    def test_refusal_on_unreconstructable_statement(self):
        sha = _cases()[0][0]
        js = copy.copy(_capture(sha)["json"])
        js["shape"] = {"t": 32, "d": 16}
        with self.assertRaises(replay.Refusal) as cm:
            replay.reconstruct_statement(js)
        self.assertIn("shape.f", str(cm.exception))
        js["shape"] = {"t": 32, "d": 16, "f": 16}
        js["shifts"] = [7, 0, 14]
        with self.assertRaises(replay.Refusal) as cm:
            replay.reconstruct_statement(js)
        self.assertIn("shifts", str(cm.exception))

    def test_truncated_receipt_is_refused(self):
        sha = _cases()[0][0]
        cap = _capture(sha)
        st, _ = replay.reconstruct_statement(cap["json"])
        lay = replay.layout_numbers(st)
        with self.assertRaises(replay.Refusal):
            replay.parse_receipt(cap["receipt"][:-1], cap["json"]["privacy"], lay)
        with self.assertRaises(replay.Refusal):
            replay.parse_receipt(cap["receipt"] + b"\0", cap["json"]["privacy"], lay)


if __name__ == "__main__":
    unittest.main()
