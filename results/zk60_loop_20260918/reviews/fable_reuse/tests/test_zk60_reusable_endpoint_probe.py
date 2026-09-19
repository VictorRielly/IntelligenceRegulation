"""Reusable caller-fixed endpoint roots: model checks for scripts/zk60_reusable_endpoint_probe.py.

These are executable checks of an independent linear model pinned to source.
They are NOT a theorem, they execute no native Rust, and they accept no
privacy claim. What they pin down:

* the model is the source encoding (pins, anchors, a cross-check against the
  round-20 translation that was validated on native captures);
* one fixed root opened twice publishes enough to recover every data word
  from two group vectors alone, and one opening does not;
* the defect is a per-use budget: a layout with one terminal pair, one
  proximity pair and `checks` pads per use discloses 0 within its budget and
  discloses beyond it;
* the stateful frontier simulator handles prior authenticated paths AND the
  prior field observations, refuses a spent root, and never gives a public
  node a second observed preimage, while the fresh top-pair control does.
"""
from pathlib import Path
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_reusable_endpoint_probe as rp


class SourceBinding(unittest.TestCase):
    def test_every_modelled_source_file_is_pinned_and_anchored(self):
        for rel, rec in rp.check_source_pins().items():
            self.assertTrue(rec["pinned"], f"{rel} changed: re-derive the model ({rec['sha256']})")
            self.assertEqual(rec["missing_anchors"], [], rel)

    def test_source_layout_is_the_seven_row_endpoint(self):
        s = rp.SOURCE
        self.assertEqual((s.rows, s.n, s.q, s.nn, s.checks, s.depth), (7, 256, 256, 2048, 256, 11))
        self.assertEqual((s.terminal_pair(0), s.prox_pair(0)), ((2, 3), (4, 5)))
        # zk_ffn_fresh_io.rs::ENDPOINT_OPEN_BYTES
        self.assertEqual(s.opening_bytes(), 2 * 512 * 16 + 256 * (8 + 7 * 8 + 32 + 11 * 32))
        with self.assertRaises(ValueError):
            s.terminal_pair(1)

    def test_encoding_is_f_data_plus_vanishing_times_pad_on_the_shifted_coset(self):
        layout, rng = rp.SMALL_SOURCE, random.Random(1)
        msg = [rng.randrange(rp.P) for _ in range(layout.n)]
        pad = [rng.randrange(rp.P) for _ in range(layout.q)]
        enc = rp.encode_row(layout, msg, pad)
        coeffs = rp.intt(msg, rp.two_adic_root(layout.log_n))
        omega = rp.two_adic_root(layout.depth)
        for j in (0, 1, 5, layout.nn - 1):
            x = rp.GENERATOR * pow(omega, j, rp.P) % rp.P
            f_data = sum(c * pow(x, i, rp.P) for i, c in enumerate(coeffs)) % rp.P
            g_pad = sum(c * pow(x, i, rp.P) for i, c in enumerate(pad)) % rp.P
            self.assertEqual(enc[j], (f_data + (pow(x, layout.n, rp.P) - 1) * g_pad) % rp.P)
        # no position is systematic, and the subgroup still carries the message
        self.assertFalse(set(enc) & set(msg))

    def test_encoding_agrees_with_the_capture_validated_round20_translation(self):
        try:
            import zk60_io_opening_translation as T
        except Exception as e:                               # noqa: BLE001
            self.skipTest(f"round-20 translation not importable here: {e}")
        layout, rng = rp.SOURCE, random.Random(2)
        msg = [rng.randrange(rp.P) for _ in range(layout.n)]
        pad = [rng.randrange(rp.P) for _ in range(layout.q)]
        theirs = T.coset_evals(T.pcs_poly([(v, 0) for v in msg], [(v, 0) for v in pad]), layout.nn)
        self.assertEqual([v[0] for v in theirs], rp.encode_row(layout, msg, pad))


class FullGeometryRecovery(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rng = random.Random(20260918)
        cls.data = rp.synthetic_data(rp.SOURCE, cls.rng)
        cls.endpoint = rp.Endpoint(rp.SOURCE, cls.data, cls.rng)
        cls.ops = [rp.open_field(cls.endpoint, rp.draw_challenge(rp.SOURCE, 0, cls.rng)) for _ in range(2)]

    def test_both_openings_pass_the_field_half_of_verify_zk(self):
        for op in self.ops:
            self.assertIsNone(rp.verify_field(rp.SOURCE, op))
            self.assertEqual(len(op.columns), 256)

    def test_a_tampered_vector_or_column_is_rejected(self):
        op = self.ops[0]
        v = list(op.group_vec)
        v[300] = rp.f2_add(v[300], rp.F2_ONE)                 # a pad entry: the claim check cannot see it
        bad = rp.Opening(op.challenge, v, op.prox_vec, op.value, op.columns)
        self.assertIsNotNone(rp.verify_field(rp.SOURCE, bad))
        j, col = op.columns[0]
        cols = [(j, [col[0] ^ 1] + col[1:])] + op.columns[1:]
        bad = rp.Opening(op.challenge, op.group_vec, op.prox_vec, op.value, cols)
        self.assertIn("disagrees", rp.verify_field(rp.SOURCE, bad))

    def test_two_group_vectors_recover_all_512_words_without_columns_or_hashes(self):
        stripped = [rp.Opening(op.challenge, op.group_vec[:rp.SOURCE.n], [], rp.F2_ZERO, []) for op in self.ops]
        self.assertEqual(rp.recover_from_group_vectors(rp.SOURCE, *stripped), self.data)

    def test_three_base_words_and_the_int16_range_pin_a_coordinate_pair(self):
        for k in (0, 17, 255):
            found = rp.recover_pair_from_three_words(rp.SOURCE, self.ops[0], self.ops[1], k)
            self.assertEqual(found, [(self.data[k], self.data[rp.SOURCE.n + k])])

    def test_clear_vectors_disclose_nothing_once_and_everything_twice(self):
        ch = [op.challenge for op in self.ops]
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, ch[:1]), 0)
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, ch), 2)
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, ch, ("group",)), 2)
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, ch, ("prox",)), 0)
        more = ch + [rp.draw_challenge(rp.SOURCE, 0, self.rng) for _ in range(2)]
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, more[:3], ("prox",)), 1)
        self.assertEqual(rp.per_coordinate_disclosure(rp.SOURCE, more, ("prox",)), 2)

    def test_columns_alone_recover_the_data_after_pad_exhaustion(self):
        ops = list(self.ops)
        self.assertIsNone(rp.recover_from_columns(rp.SOURCE, ops))        # fewer than n + Q positions
        while len({j for op in ops for j, _ in op.columns}) < rp.SOURCE.width:
            ops.append(rp.open_field(self.endpoint, rp.draw_challenge(rp.SOURCE, 0, self.rng)))
        self.assertLessEqual(len(ops), 4)
        self.assertEqual(rp.recover_from_columns(rp.SOURCE, ops), self.data)


class BudgetIsTheDefect(unittest.TestCase):
    def test_complete_system_source_layout_is_single_use(self):
        table = rp.budget_table()["source_layout_uses1"]["table"]
        self.assertEqual(table["after_1"]["disclosed"], 0)
        self.assertEqual(table["after_2"]["disclosed"], table["after_2"]["of"])

    def test_complete_system_budget_two_layout_holds_twice_and_then_discloses(self):
        rec = rp.budget_table()["budget_layout_uses2"]
        self.assertEqual((rec["rows"], rec["pads"]), (10, 8))
        self.assertEqual(rec["table"]["after_1"]["disclosed"], 0)
        self.assertEqual(rec["table"]["after_2"]["disclosed"], 0)
        self.assertGreater(rec["table"]["after_3"]["disclosed"], 0)

    def test_sharing_one_terminal_pair_inside_the_budget_layout_still_discloses(self):
        layout, rng = rp.SMALL_BUDGET2, random.Random(3)
        endpoint = rp.Endpoint(layout, rp.synthetic_data(layout, rng), rng)
        ops = [rp.open_field(endpoint, rp.draw_challenge(layout, 0, rng)) for _ in range(2)]
        self.assertGreater(rp.disclosed_dimension(layout, ops), 0)

    def test_costs_grow_linearly_in_the_use_budget(self):
        costs = rp.cost_table()
        self.assertEqual(costs["uses_1"]["opening_bytes_per_use"], rp.SOURCE.opening_bytes())
        self.assertEqual([costs[f"uses_{k}"]["rows"] for k in (1, 2, 3)], [7, 10, 14])
        self.assertEqual([costs[f"uses_{k}"]["rate"] for k in (1, 2, 3)], ["1/4", "3/8", "1/2"])


class FrontierSimulation(unittest.TestCase):
    def setUp(self):
        self.layout = rp.SMALL_BUDGET2
        self.rng = random.Random(11)
        self.oracle = rp.Oracle(11)
        self.data = rp.synthetic_data(self.layout, self.rng)
        self.owner = rp.Owner(self.layout, self.data, self.rng, self.oracle)
        self.first = self.owner.open(rp.draw_challenge(self.layout, 0, self.rng))
        self.dummy = [0] * (2 * self.layout.n)

    def simulator(self, history):
        return rp.FrontierSimulator(self.layout, self.oracle, self.owner.root, history, self.dummy, self.rng)

    def test_honest_owner_is_use_limited(self):
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, self.first))
        second = self.owner.open(rp.draw_challenge(self.layout, 1, self.rng))
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, second))
        self.assertEqual(rp.max_preimages(self.layout, self.oracle, [self.first, second]), 1)
        with self.assertRaises(rp.Refusal):
            self.owner.open(rp.draw_challenge(self.layout, 1, self.rng))

    def test_simulated_second_use_verifies_under_the_fixed_root_after_real_history(self):
        sim = self.simulator([self.first])
        second = sim.open(rp.draw_challenge(self.layout, 1, self.rng))
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, second))
        # no public node ever gets a second observed preimage
        self.assertEqual(rp.max_preimages(self.layout, self.oracle, [self.first, second]), 1)
        # repeated positions are served byte-identically
        old = {j: (col, self.first.salts[j], self.first.paths[j]) for j, col in self.first.columns}
        for j, col in second.columns:
            if j in old:
                self.assertEqual((col, second.salts[j], second.paths[j]), old[j])
        new = {j for j, _ in second.columns} - set(old)
        self.assertTrue(new)
        self.assertLessEqual(len(self.oracle.programmed), len(new))
        self.assertGreaterEqual(len(self.oracle.programmed), 1)

    def test_joint_field_view_is_in_the_support_of_the_real_data(self):
        sim = self.simulator([self.first])
        second = sim.open(rp.draw_challenge(self.layout, 1, self.rng))
        joint = [self.first, second]
        self.assertEqual(rp.disclosed_dimension(self.layout, joint), 0)
        self.assertIsNotNone(rp.sample_owner(self.layout, self.data, joint, self.rng))
        other = rp.synthetic_data(self.layout, self.rng)
        self.assertIsNotNone(rp.sample_owner(self.layout, other, joint, self.rng))

    def test_empty_history_degenerates_to_one_programmed_top_pair(self):
        sim = self.simulator([])
        op = sim.open(rp.draw_challenge(self.layout, 0, self.rng))
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, op))
        self.assertEqual(len(self.oracle.programmed), 1)
        self.assertEqual(self.oracle.table[self.oracle.programmed[0]], self.owner.root)
        op2 = sim.open(rp.draw_challenge(self.layout, 1, self.rng))
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, op2))
        self.assertEqual(len(self.oracle.programmed), 1)       # state, not new programming
        self.assertEqual(rp.max_preimages(self.layout, self.oracle, [op, op2]), 1)

    def test_control_fresh_top_pair_after_history_is_distinguished(self):
        ch = rp.draw_challenge(self.layout, 1, self.rng)
        naive = rp.naive_top_pair_opening(self.layout, self.oracle, self.owner.root, self.dummy, ch, self.rng)
        self.assertIsNone(rp.verify_opening(self.layout, self.oracle, self.owner.root, naive))
        self.assertEqual(rp.max_preimages(self.layout, self.oracle, [self.first, naive]), 2)
        self.assertEqual(rp.max_preimages(self.layout, self.oracle, [naive]), 1)   # invisible without history

    def test_spent_budget_is_refused_like_the_consumed_owner(self):
        sim = self.simulator([self.first])
        sim.open(rp.draw_challenge(self.layout, 1, self.rng))
        with self.assertRaises(rp.Refusal):
            sim.open(rp.draw_challenge(self.layout, 1, self.rng))
        second = self.owner.open(rp.draw_challenge(self.layout, 1, self.rng))
        with self.assertRaises(rp.Refusal):
            self.simulator([self.first, second]).open(rp.draw_challenge(self.layout, 1, self.rng))

    def test_history_that_does_not_verify_is_refused(self):
        j, col = self.first.columns[0]
        self.first.salts[j] = bytes(32)
        with self.assertRaises(rp.Refusal):
            self.simulator([self.first])

    def test_an_answered_programming_input_is_refused_never_overwritten(self):
        oracle = rp.Oracle(5)
        oracle.query(b"x" * 64)
        with self.assertRaises(rp.Refusal):
            oracle.program(b"x" * 64, bytes(32))
        self.assertEqual(oracle.programmed, [])


class SourceProtocolHasNoSecondUseSimulator(unittest.TestCase):
    """Any second ordinary opening produced without the data is caught: the
    recovery map extracts what the simulator used, not what the root holds."""

    def test_second_opening_from_dummy_data_is_not_explained_by_the_real_data(self):
        layout, rng = rp.SMALL_SOURCE, random.Random(21)
        data = rp.synthetic_data(layout, rng)
        real = rp.Endpoint(layout, data, rng)
        first = rp.open_field(real, rp.draw_challenge(layout, 0, rng))
        dummy = [0] * (2 * layout.n)
        virtual = rp.sample_owner(layout, dummy, [first], rng)      # exists: one opening discloses 0
        self.assertIsNotNone(virtual)
        forged = rp.open_field(virtual, rp.draw_challenge(layout, 0, rng))
        self.assertIsNone(rp.verify_field(layout, forged))
        self.assertEqual(rp.recover_from_group_vectors(layout, first, forged), dummy)
        self.assertIsNone(rp.sample_owner(layout, data, [first, forged], rng))
        honest = rp.open_field(real, rp.draw_challenge(layout, 0, rng))
        self.assertEqual(rp.recover_from_group_vectors(layout, first, honest), data)

    def test_frontier_simulator_refuses_a_spent_source_root(self):
        layout, rng, oracle = rp.SMALL_SOURCE, random.Random(22), rp.Oracle(22)
        owner = rp.Owner(layout, rp.synthetic_data(layout, rng), rng, oracle)
        first = owner.open(rp.draw_challenge(layout, 0, rng))
        sim = rp.FrontierSimulator(layout, oracle, owner.root, [first], [0] * (2 * layout.n), rng)
        with self.assertRaises(rp.Refusal):
            sim.open(rp.draw_challenge(layout, 0, rng))
        with self.assertRaises(rp.Refusal):
            owner.open(rp.draw_challenge(layout, 0, rng))


class ExecutionRecord(unittest.TestCase):
    """The seeded record quoted in ZK60_REUSABLE_ENDPOINT_REVIEW_20260918.md section 9.
    Direct script execution was not available to the authoring session, so the
    memo's numbers are pinned here instead of in a results file."""

    def test_record_numbers_quoted_in_the_review(self):
        rec = rp.run()
        self.assertTrue(rec["source_pins_ok"])
        self.assertFalse(rec["privacy_accepted"])
        full = rec["full_geometry"]
        self.assertEqual(full["openings_verify"], [True, True])
        self.assertEqual((full["recovered_words"], full["recovered_all"]), (512, True))
        self.assertEqual((full["three_word_candidates"], full["three_word_unique_and_correct"]), (1, True))
        self.assertEqual(full["column_only"], dict(openings_needed=3, distinct_positions=639, recovered_all=True))
        self.assertEqual(full["per_coordinate_disclosed"],
                         dict(one_opening=0, two_openings=2, two_openings_group_only=2))
        table = {name: [v["table"][f"after_{t}"]["disclosed"] for t in (1, 2, 3)]
                 for name, v in rec["budget"].items()}
        self.assertEqual(table, dict(source_layout_uses1=[0, 8, 8], budget_layout_uses2=[0, 0, 8]))
        sim = rec["simulator"]
        self.assertEqual((sim["simulated_verifies"], sim["programmed_points"], sim["new_positions"],
                          sim["max_observed_preimages"], sim["joint_disclosed"],
                          sim["real_data_explains_joint_view"]), (True, 3, 3, 1, 0, True))
        self.assertEqual(sim["control_top_pair_after_history"], dict(verifies=True, max_observed_preimages=2))
        self.assertIn("no unspent use", sim["third_use"])
        self.assertEqual([rec["costs"][f"uses_{k}"]["opening_bytes_per_use"] for k in (1, 2, 3)],
                         [131072, 145408, 161792])


if __name__ == "__main__":
    unittest.main()
