"""R-C0 tests: the classifier variant's reference semantics and forgery cases (no proof).

DESIGN_CLASSIFIER.md v2 §3.1-3.2 (template clause), §3.5 (B-1 split), §3.6 (B-2 control-id
exclusion), §4 (stage OUT-C: the margin identity MRG, the verdict, the range limbs), §4.4 (B-3: the
door re-derives the margin vector, the yes / no ids and c). Parts that wait for Victor's rulings
(n public, the policy list, the binding) are NOT here.

Each forgery is shown ACCEPTED when its one relation is removed and REFUSED with it (the v3 R0
V13-V15 style), so every relation is load-bearing.

Run: python3 -I -B results/zk60_token_io_r1_20261017/classifier/rc0/test_classifier_ref.py
The tokenizer tests import mistral_common read-only from ~/shieldstral-prep/pylib and read
~/models/shieldstral-1.0-3b/tekken.json; they FAIL (never skip) if those are missing.
"""
from __future__ import annotations

import os
import random
import sys
import unittest

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import classifier_ref as R  # noqa: E402

RNG = random.Random(0x5c1a551f)


def rnd():
    return RNG.randrange(1, R.P)


# ----------------------------------------------------------------------------- the margin slot


class Margin(unittest.TestCase):
    def setUp(self):
        self.d = 64
        self.y = [RNG.randint(-127, 127) for _ in range(self.d)]
        self.w = [RNG.randint(-32767, 32767) for _ in range(self.d)]
        self.delta = R.margin(self.y, self.w)

    def honest(self, c):
        b = R.verdict(self.delta, c)
        lam = R.honest_limbs(self.delta, c, b)
        return b, lam

    def test_honest_verdicts_accept_both_bits_tie_and_neighbours(self):
        for c in (self.delta - 1, self.delta, self.delta + 1, 0, -12345, 2**33 - 1):
            b, lam = self.honest(c)
            self.assertEqual(b, int(self.delta > c))
            ok, why = R.check_margin(self.y, self.w, c, b, lam)
            self.assertTrue(ok, (c, why))
        # the tie is NOT flagged (Mistral: flagged ABOVE tau)
        self.assertEqual(R.verdict(self.delta, self.delta), 0)

    def test_extreme_margin_fits_five_limbs(self):
        y = [127] * 3072
        w = [32767] * 3072
        dl = R.margin(y, w)
        self.assertEqual(dl, R.B_DELTA_INT16)
        for c in (-(2**33), 2**33):
            b = R.verdict(dl, c)
            lam = R.honest_limbs(dl, c, b)
            self.assertEqual(len(lam), R.L)
            self.assertTrue(R.check_margin(y, w, c, b, lam)[0])
        self.assertEqual(R.derived_limbs(R.B_DELTA_INT16, 2**33), 5)
        self.assertEqual(R.derived_limbs(R.B_DELTA_TWO_ROW, 2**38), 5)
        self.assertLess(2 ** (8 * R.L) + 2 ** 40, R.P)

    def test_flipped_verdict_is_refused_by_the_byte_lookups_and_accepted_without_them(self):
        c = 0
        b, _ = self.honest(c)
        fb = 1 - b
        # the forger needs delta' = sigma'(Delta - c) - b' which is negative: its field image
        forged = R.field_limbs_of(R.sigma(fb) * (self.delta - c) - fb)
        ok, why = R.check_margin(self.y, self.w, c, fb, forged)
        self.assertFalse(ok)
        self.assertIn("byte", why)
        ok, _ = R.check_margin(self.y, self.w, c, fb, forged, byte_check=False)
        self.assertTrue(ok, "without the byte lookups the flip is accepted: the lookups are load-bearing")

    def test_no_five_byte_value_flips_the_verdict(self):
        # exhaustive over the identity: for the wrong bit, the unique field solution is not 5 bytes
        for c in (self.delta - 1, self.delta, self.delta + 1):
            b = R.verdict(self.delta, c)
            need = (R.sigma(1 - b) * (self.delta - c) - (1 - b)) % R.P
            self.assertGreaterEqual(need, 2 ** (8 * R.L), c)

    def test_nonzero_limb_pad_is_refused_and_accepted_without_the_pad_clause(self):
        c = 7
        b, lam = self.honest(c)
        padded = lam + [0] * (R.MC_LIFT - R.L)
        padded[R.L + 3] = 200
        ok, why = R.check_margin(self.y, self.w, c, b, padded)
        self.assertFalse(ok)
        self.assertIn("pad", why)
        self.assertTrue(R.check_margin(self.y, self.w, c, b, padded, pad_check=False)[0])

    def test_a_proof_for_one_bit_fails_under_the_other(self):
        # MRG's right side is the verifier's own sigma*b + c: the statement's b decides it
        c = 0
        b, lam = self.honest(c)
        self.assertFalse(R.check_margin(self.y, self.w, c, 1 - b, lam)[0])
        # and the transcript seed absorbs b (strong Fiat-Shamir): a different b, a different seed
        self.assertNotEqual(R.transcript_seed(b=0, c=0, w_digest=b"w"), R.transcript_seed(b=1, c=0, w_digest=b"w"))

    def test_two_row_alternative_matches_the_difference_row(self):
        m_yes, m_no = 3000, 4096
        ry = [RNG.randint(-127, 127) for _ in range(self.d)]
        rn = [RNG.randint(-127, 127) for _ in range(self.d)]
        w2 = R.two_row_vector(ry, rn, m_yes, m_no)
        self.assertEqual(R.margin(self.y, w2), m_yes * R.dot(self.y, ry) - m_no * R.dot(self.y, rn))
        self.assertLessEqual(max(abs(v) for v in w2), 2 * 4096 * 127)
        self.assertFalse(R.door_two_row_ratio_ok(100, 4096), "min(m)/max(m) < 2^-4 is refused")


# ----------------------------------------------------------------------------- the door (B-3)


class Door(unittest.TestCase):
    def setUp(self):
        self.export = R.synthetic_export(d=32, vocab=40, yes=13, no=7, seed=5)
        self.profile = R.Profile(yes=13, no=7, c=0)

    def test_honest_statement_passes_the_door(self):
        st = R.statement_from(self.export, self.profile)
        self.assertEqual(R.door(self.export, self.profile, st), (True, "ok"))

    def test_swapped_margin_vector_with_a_self_made_digest_is_refused(self):
        st = R.statement_from(self.export, self.profile)
        w_neg = [-v for v in R.derive_margin_vector(self.export, self.profile)[0]]
        forged = dict(st, w_digest=R.digest_ints(w_neg))
        ok, why = R.door(self.export, self.profile, forged)
        self.assertFalse(ok)
        self.assertIn("margin vector", why)
        # a verifier that TRUSTED the statement's vector would accept the inverted meaning
        self.assertTrue(R.door(self.export, self.profile, forged, trust_statement=True)[0])

    def test_yes_no_ids_and_c_come_from_the_profile(self):
        st = R.statement_from(self.export, self.profile)
        self.assertFalse(R.door(self.export, self.profile, dict(st, yes=7, no=13))[0])
        self.assertFalse(R.door(self.export, self.profile, dict(st, c=5))[0])


# ----------------------------------------------------------------------------- template clause (3.1-3.2)


class TemplateClause(unittest.TestCase):
    def setUp(self):
        self.V, self.T = 48, 16
        self.emb = [[RNG.randint(-300, 300) for _ in range(4)] for _ in range(self.V)]
        self.ctl = [1 if v < 10 else 0 for v in range(self.V)]
        # template: positions 0..4 prefix (BOS = 1 first, control ids allowed), 15 suffix
        self.pi = [1 if (t < 5 or t == self.T - 1) else 0 for t in range(self.T)]
        self.kappa = [0] * self.T
        for t, v in zip((0, 1, 2, 3, 4), (1, 3, 22, 30, 11)):
            self.kappa[t] = v
        self.kappa[self.T - 1] = 4
        self.content = [RNG.randrange(10, self.V) for _ in range(self.T - 6)]
        self.tok = [self.kappa[t] if self.pi[t] else 0 for t in range(self.T)]
        for i, v in enumerate(self.content):
            self.tok[5 + i] = v

    def stage_in(self, tok, mu_shared=False, ctl_column=True, h_zero_at=None):
        return R.check_stage_in(tok, self.emb, self.ctl, self.pi, self.kappa, bos=1,
                                challenges=R.Challenges(RNG, shared_template_coefficient=mu_shared),
                                ctl_column=ctl_column, drop_query_at=h_zero_at)

    def test_honest_template_and_content_accept(self):
        self.assertTrue(self.stage_in(self.tok)[0])

    def test_a_changed_template_id_is_refused(self):
        bad = list(self.tok)
        bad[2] = 23
        ok, why = self.stage_in(bad)
        self.assertFalse(ok)

    def test_shared_coefficient_lets_the_template_clause_cancel_fresh_does_not(self):
        # CHECK2 N-1 style: tok at template position 3 is kappa+1 AND its query is dropped from
        # the LogUp (h_q = 0): the LogUp clause gives -mu_q, the template clause +mu_tmpl
        bad = list(self.tok)
        bad[3] = self.kappa[3] + 1
        ok_shared, _ = self.stage_in(bad, mu_shared=True, h_zero_at=3)
        ok_fresh, why = self.stage_in(bad, mu_shared=False, h_zero_at=3)
        self.assertTrue(ok_shared, "with a shared coefficient the deviation cancels (the attack)")
        self.assertFalse(ok_fresh, "the fresh coefficient refuses it")

    def test_content_control_id_refused_with_ctl_column_accepted_without(self):
        bad = list(self.tok)
        bad[6] = 4  # the [/INST]-like control id inside the content
        ok, why = self.stage_in(bad)
        self.assertFalse(ok)
        self.assertTrue(self.stage_in(bad, ctl_column=False)[0], "without the ctl column a control id passes: load-bearing")

    def test_template_positions_may_hold_control_ids(self):
        self.assertIn(self.kappa[1], range(10))
        self.assertTrue(self.stage_in(self.tok)[0])


# ----------------------------------------------------------------------------- tokenizer (B-1, B-2)


class Tokenizer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tk = R.ShieldstralTokens()  # raises (fails the tests) if mistral_common / tekken are missing

    def test_split_reproduces_the_reference_encoder_on_the_corpus(self):
        bad = [c for c in R.CORPUS if self.tk.split(c) != self.tk.reference(c)]
        self.assertEqual(bad, [], "the B-1 split differs from Mistral's reference encoding")
        self.assertGreaterEqual(len(R.CORPUS), 48)

    def test_prefix_is_84_ids_ending_at_colon_and_suffix_is_inst_close(self):
        self.assertEqual(len(self.tk.prefix), 84)
        # the prefix TEXT ends at the colon of "<Document>:"; tekken's last piece there is ">:"
        self.assertTrue(self.tk.piece(self.tk.prefix[-1]).endswith(":"), self.tk.piece(self.tk.prefix[-1]))
        self.assertEqual(self.tk.suffix, [4])
        self.assertEqual(self.tk.prefix[0], 1)

    def test_content_never_holds_a_control_id_under_the_plain_text_encoder(self):
        for c in R.CORPUS:
            ids = self.tk.content_ids(c)
            self.assertTrue(all(i >= self.tk.num_special for i in ids), c)

    def test_the_lone_space_prefix_is_not_stable(self):
        # C-1: the literal prefix through '<Document>: ' (trailing space as its own id) is NOT a
        # prefix of the reference ids for content starting with a letter
        lit = self.tk.literal_prefix_with_space()
        self.assertEqual(len(lit), 85)
        self.assertNotEqual(self.tk.reference("hello")[:85], lit)

    def test_yes_and_no_are_single_ids(self):
        self.assertEqual(self.tk.encode_plain("yes"), [13059])
        self.assertEqual(self.tk.encode_plain("no"), [2649])


if __name__ == "__main__":
    unittest.main()
