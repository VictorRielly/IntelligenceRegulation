"""Fast tests for the PV-S2 song-scale provenance spike.

Drives scripts/music_provenance_spike2.py's function API at toy shapes
with a small block count (3 blocks x 1024 cols, r=2) — the committed
test path; the spike's own default run is the song-scale measurement.

The Pi1 tamper legs run under pinned entropy (the test_zk_lattice
precedent): at r=2 the 8-bit Fiat-Shamir challenges leave each tamper a
~2^-14..2^-16 spurious-accept tail under fresh OS randomness, so the
prover's internal draws are made deterministic while exercising exactly
the same code paths. The spike's own data/commitment randomness is
already PRF-derived and deterministic.
"""

import importlib.util
import tempfile
import unittest
from array import array
from pathlib import Path

from test_zk_lattice import pinned_entropy

ROOT = Path(__file__).resolve().parent.parent
_SPEC = importlib.util.spec_from_file_location(
    "music_provenance_spike2", ROOT / "scripts" / "music_provenance_spike2.py"
)
pv2 = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(pv2)


def small_cfg(**kw):
    base = dict(
        n_samples=3000,          # 3 blocks of 1024 with 72 zero-pad cols
        cols_per_block=1024,
        reps=2,
        frame=256,
        seed=987,
        session_id="PV-S2-TEST",
    )
    base.update(kw)
    return pv2.replace_cfg(pv2.SpikeConfig(), **base)


class WavRoundtripTests(unittest.TestCase):
    def test_wav_write_read_exact(self):
        cfg = small_cfg()
        takes = pv2.synth_takes(cfg)
        master, peak = pv2.mix_master(cfg, takes)
        self.assertLess(peak, 32768)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.wav"
            pv2.write_wav(path, takes[0], cfg.sr)
            back, sr = pv2.read_wav(path)
            self.assertEqual(sr, cfg.sr)
            self.assertEqual(back, takes[0])
            pv2.write_wav(path, master, cfg.sr)
            self.assertEqual(pv2.read_wav(path)[0], master)


class SessionEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cfg = small_cfg()
        cls.takes = pv2.synth_takes(cls.cfg)
        cls.device_key = b"K" * 32
        cls.evidence = pv2.build_evidence(cls.cfg, cls.takes, cls.device_key)

    def test_honest_session_verifies_as_one_object(self):
        good, why = pv2.verify_evidence(
            self.cfg, self.evidence, self.takes, self.device_key
        )
        self.assertTrue(good, why)

    def test_flipped_sample_breaks_take_chain(self):
        bad = [array("h", t) for t in self.takes]
        bad[1][777] ^= 1
        good, why = pv2.verify_evidence(
            self.cfg, self.evidence, bad, self.device_key
        )
        self.assertFalse(good)
        self.assertIn("frame chain", why)

    def test_forged_device_key_rejects(self):
        good, why = pv2.verify_evidence(
            self.cfg, self.evidence, self.takes, b"X" * 32
        )
        self.assertFalse(good)
        self.assertIn("device tag", why)

    def test_cross_session_splice_rejects(self):
        other_cfg = pv2.replace_cfg(self.cfg, session_id="PV-S2-TEST-B")
        other = pv2.build_evidence(other_cfg, self.takes, self.device_key)
        spliced = {
            "session": self.evidence["session"],
            "session_digest": self.evidence["session_digest"],
            "takes": [dict(t) for t in self.evidence["takes"]],
        }
        spliced["takes"][2] = other["takes"][2]
        good, why = pv2.verify_evidence(
            self.cfg, spliced, self.takes, self.device_key
        )
        self.assertFalse(good)
        self.assertIn("cross-commitment", why)

    def test_transparency_log_anchor(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "log.jsonl"
            pv2.log_append(log, "session-close",
                           {"session_digest": self.evidence["session_digest"]})
            self.assertTrue(
                pv2.log_anchors(log, self.evidence["session_digest"])
            )
            self.assertFalse(pv2.log_anchors(log, "ff" * 32))


class BlockChainedPi1Tests(unittest.TestCase):
    """Song proof at 3 blocks x 1024 cols, r=2 (padded final block)."""

    @classmethod
    def setUpClass(cls):
        cls.cfg = small_cfg()
        cls.takes = pv2.synth_takes(cls.cfg)
        master, _ = pv2.mix_master(cls.cfg, cls.takes)
        cls.master = master
        cls.session_key = b"S" * 32
        cls.session_digest = b"D" * 32
        cls.params_base = pv2.toy_block_params(cls.cfg)
        with pinned_entropy(0x5EED_0902):
            cls.song = pv2.prove_song(
                cls.cfg, cls.params_base, cls.takes, cls.master,
                cls.session_digest, cls.session_key, retain={0, 1, 2},
            )

    def test_all_blocks_accept_and_open(self):
        self.assertEqual(len(self.song.links), 3)
        self.assertTrue(all(l.accepted for l in self.song.links))
        self.assertTrue(all(l.open_mismatch is None for l in self.song.links))

    def test_chain_is_deterministic_for_fixed_session(self):
        # PRF-derived commitments make the statement chain reproducible.
        with pinned_entropy(0x5EED_0903):
            again = pv2.prove_song(
                self.cfg, self.params_base, self.takes, self.master,
                self.session_digest, self.session_key,
            )
        self.assertEqual(self.song.chain_final, again.chain_final)

    def test_flipped_master_rejects_only_that_block(self):
        q = self.params_base.q
        bad_master = array("h", self.master)
        flip_col = 123
        bad_master[1 * self.cfg.cols_per_block + flip_col] ^= 1
        rec1 = self.song.records[1]
        _, c_bad = pv2.block_columns(self.cfg, self.takes, bad_master, 1, q)
        self.assertEqual(
            pv2.opening_check(rec1.key, c_bad, rec1.tau, rec1.tc), flip_col
        )
        rec0 = self.song.records[0]
        _, c0 = pv2.block_columns(self.cfg, self.takes, bad_master, 0, q)
        self.assertIsNone(
            pv2.opening_check(rec0.key, c0, rec0.tau, rec0.tc)
        )

    def test_false_statement_rejects(self):
        from zk_lattice import commit_columns
        from zk_lattice.protocol import prove_pi1, verify_pi1

        q = self.params_base.q
        a_rows = [[g % q for g in self.cfg.gains]]
        rec = self.song.records[1]
        b_cols, rho = self.song.retained_b[1]
        _, c_cols = pv2.block_columns(self.cfg, self.takes, self.master, 1, q)
        c_false = [list(col) for col in c_cols]
        c_false[5][0] = (c_false[5][0] + 1) % q
        with pinned_entropy(0x5EED_0904):
            tau_false = pv2.derive_randomness(
                self.session_key, "Cbad", 1, len(c_false), rec.params.big_n
            )
            tc_false = commit_columns(rec.key, c_false, tau_false)
            proof = prove_pi1(rec.key, a_rows, b_cols, rho,
                              c_false, tau_false, rec.tb, tc_false)
        self.assertFalse(verify_pi1(rec.key, a_rows, rec.tb, tc_false, proof))

    def test_block_reorder_rejects_via_chain(self):
        # block 2's honest record presented at position 1: the chained CRS
        # seed differs, so Pi1's statement hash mismatches and it rejects.
        self.assertFalse(
            pv2.verify_block_at_position(
                self.cfg, self.params_base, self.song.links[0].chain, 1,
                self.song.records[2],
            )
        )

    def test_wrong_gains_reject(self):
        from zk_lattice.protocol import verify_pi1

        q = self.params_base.q
        rec = self.song.records[0]
        a_wrong = [[(self.cfg.gains[0] + 1) % q]
                   + [g % q for g in self.cfg.gains[1:]]]
        self.assertFalse(
            verify_pi1(rec.key, a_wrong, rec.tb, rec.tc, rec.proof)
        )

    def test_padding_blocks_hold_statement(self):
        # final block covers samples [2048, 3072) but the song ends at
        # 3000: the 72 padded columns commit zeros on both sides.
        q = self.params_base.q
        b_cols, c_cols = pv2.block_columns(
            self.cfg, self.takes, self.master, 2, q
        )
        self.assertEqual(b_cols[-1], [0] * self.cfg.n_takes)
        self.assertEqual(c_cols[-1], [0])
        self.assertNotEqual(b_cols[0], [0] * self.cfg.n_takes)


if __name__ == "__main__":
    unittest.main()
