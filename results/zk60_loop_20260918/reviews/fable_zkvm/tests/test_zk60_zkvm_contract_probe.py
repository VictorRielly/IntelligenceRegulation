"""Adversarial checks of the proposed zkVM journal/domain contract.

These test a serialization contract. They run no zkVM and establish no
privacy or soundness property of any proof system.
"""
import hashlib
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_zkvm_contract_probe as P

PINNED_JOURNAL_SHA256 = "d0301af975dbe36e773c6f732abe16d195fc213cf4bfd9a1162d4d641bd380b5"
PINNED_INPUT_COMMITMENT = "b6de5c6a6ba1168fa42f2e6ddfb67ab47cf180b29ebf38a2d67887c9a73d86b7"
STATEMENT = ("context", "model", "weights", "calibration", "layer_index",
             "input_commitment", "output_commitment")


def statement(fx, **changes):
    out = {name: fx[name] for name in STATEMENT}
    out.update(changes)
    return out


def flip(data, index=0):
    return data[:index] + bytes([data[index] ^ 1]) + data[index + 1:]


class JournalBinding(unittest.TestCase):
    def setUp(self):
        self.fx = P.fixture()

    def test_layout_is_fixed_and_verifier_rebuilds_it(self):
        journal = self.fx["journal"]
        self.assertEqual(len(journal), P.JOURNAL_LEN)
        self.assertEqual(P.JOURNAL_LEN, 260)
        self.assertEqual(journal, P.fixture()["journal"])
        P.verify_journal(journal, **statement(self.fx))
        fields = P.decode_journal(journal)
        for name in STATEMENT:
            self.assertEqual(fields[name], self.fx[name])

    def test_pinned_vector_for_the_rust_guest(self):
        # Any change here is a new profile version, not an edit.
        self.assertEqual(hashlib.sha256(self.fx["journal"]).hexdigest(), PINNED_JOURNAL_SHA256)
        self.assertEqual(self.fx["input_commitment"].hex(), PINNED_INPUT_COMMITMENT)

    def test_every_statement_field_is_bound(self):
        for name in STATEMENT:
            changed = 1 if name == "layer_index" else flip(self.fx[name], 31)
            with self.subTest(field=name), self.assertRaises(P.ContractError):
                P.verify_journal(self.fx["journal"], **statement(self.fx, **{name: changed}))

    def test_every_journal_byte_is_bound(self):
        for index in range(P.JOURNAL_LEN):
            with self.assertRaises(P.ContractError):
                P.verify_journal(flip(self.fx["journal"], index), **statement(self.fx))

    def test_swapped_endpoints_and_replayed_context_are_rejected(self):
        fx = self.fx
        with self.assertRaises(P.ContractError):
            P.verify_journal(fx["journal"], **statement(
                fx, input_commitment=fx["output_commitment"],
                output_commitment=fx["input_commitment"]))
        other = P.context_digest(b"zk60-zkvm-probe/request/0002")
        with self.assertRaises(P.ContractError):
            P.verify_journal(fx["journal"], **statement(fx, context=other))

    def test_malformed_journals_are_refused(self):
        journal = self.fx["journal"]
        hostile = {
            "truncated": journal[:-1],
            "trailing": journal + b"\0",
            "empty": b"",
            "bytearray": bytearray(journal),
            "tag": flip(journal, 0),
            "profile T=4": journal[:32] + struct.pack("<I", 4) + journal[36:],
            "layer 32": journal[:56] + struct.pack("<I", 32) + journal[60:],
            "mode P0": journal[:60] + struct.pack("<I", 0) + journal[64:],
            "reserved": journal[:64] + struct.pack("<I", 1) + journal[68:],
        }
        for name, candidate in hostile.items():
            with self.subTest(case=name):
                with self.assertRaises(P.ContractError):
                    P.decode_journal(candidate)
                with self.assertRaises(P.ContractError):
                    P.verify_journal(candidate, **statement(self.fx))

    def test_refusals_do_not_echo_supplied_values(self):
        secret = [12345] * (P.T * P.D - 1) + [40000]
        try:
            P.endpoint_commitment(self.fx["context"], self.fx["model"],
                                  self.fx["calibration"], 0, self.fx["salt_in"], secret)
        except P.ContractError as error:
            self.assertNotIn("12345", str(error))
            self.assertNotIn("40000", str(error))
        else:
            self.fail("out-of-class endpoint value accepted")


class EndpointCommitments(unittest.TestCase):
    def setUp(self):
        self.fx = P.fixture()
        fx = self.fx
        self.base = (fx["context"], fx["model"], fx["calibration"])

    def test_preimage_is_fixed_length_with_salt_at_a_fixed_offset(self):
        pre = P.endpoint_preimage(*self.base, 0, self.fx["salt_in"], self.fx["x"])
        self.assertEqual(len(pre), P.ENDPOINT_PREIMAGE_LEN)
        self.assertEqual(P.ENDPOINT_PREIMAGE_LEN, 1200)
        self.assertEqual(pre[144:176], self.fx["salt_in"])
        self.assertEqual(hashlib.sha256(pre).digest(), self.fx["input_commitment"])

    def test_commitment_depends_on_every_component(self):
        fx = self.fx
        reference = fx["input_commitment"]
        variants = [
            (flip(fx["context"]), fx["model"], fx["calibration"], 0, fx["salt_in"], fx["x"]),
            (fx["context"], flip(fx["model"]), fx["calibration"], 0, fx["salt_in"], fx["x"]),
            (fx["context"], fx["model"], flip(fx["calibration"]), 0, fx["salt_in"], fx["x"]),
            (*self.base, 1, fx["salt_in"], fx["x"]),
            (*self.base, 0, flip(fx["salt_in"]), fx["x"]),
            (*self.base, 0, fx["salt_in"], [fx["x"][0] + 1] + fx["x"][1:]),
            (*self.base, 0, fx["salt_in"], fx["x"][1:] + fx["x"][:1]),
        ]
        seen = {reference}
        for args in variants:
            seen.add(P.endpoint_commitment(*args))
        self.assertEqual(len(seen), len(variants) + 1)

    def test_boundary_indexing_lets_one_commitment_chain_two_blocks(self):
        fx = self.fx
        as_output_of_layer_0 = P.endpoint_commitment(*self.base, 1, fx["salt_out"], fx["y"])
        as_input_of_layer_1 = P.endpoint_commitment(*self.base, 1, fx["salt_out"], fx["y"])
        self.assertEqual(as_output_of_layer_0, fx["output_commitment"])
        self.assertEqual(as_input_of_layer_1, fx["output_commitment"])
        # The same activation presented at the wrong boundary is another statement.
        self.assertNotEqual(P.endpoint_commitment(*self.base, 0, fx["salt_out"], fx["y"]),
                            fx["output_commitment"])
        P.endpoint_commitment(*self.base, P.LAYERS, fx["salt_out"], fx["y"])
        with self.assertRaises(P.ContractError):
            P.endpoint_commitment(*self.base, P.LAYERS + 1, fx["salt_out"], fx["y"])

    def test_strict_value_and_salt_types(self):
        fx = self.fx
        hostile_values = [
            fx["x"][:-1], fx["x"] + [0], [True] + fx["x"][1:], [1.0] + fx["x"][1:],
            [32768] + fx["x"][1:], [-32769] + fx["x"][1:], bytes(P.T * P.D), None,
        ]
        for values in hostile_values:
            with self.assertRaises(P.ContractError):
                P.endpoint_commitment(*self.base, 0, fx["salt_in"], values)
        for salt in (b"", fx["salt_in"][:-1], fx["salt_in"] + b"\0",
                     bytearray(fx["salt_in"]), fx["salt_in"].hex(), None):
            with self.assertRaises(P.ContractError):
                P.endpoint_commitment(*self.base, 0, salt, fx["x"])
        for boundary in (-1, True, 0.0, None):
            with self.assertRaises(P.ContractError):
                P.endpoint_commitment(*self.base, boundary, fx["salt_in"], fx["x"])
        # Class endpoints are valid members.
        P.endpoint_commitment(*self.base, 0, fx["salt_in"], [-32768, 32767] * (P.T * P.D // 2))

    def test_domain_tags_are_full_width_and_distinct(self):
        self.assertEqual(len(set(P.ALL_TAGS)), len(P.ALL_TAGS))
        for tag in P.ALL_TAGS:
            self.assertEqual(len(tag), 32)
            self.assertTrue(tag.startswith(b"ZK60/zkvm-p1-block/"))
        # No hashed object of one domain has the length of another's preimage.
        self.assertNotEqual(P.ENDPOINT_PREIMAGE_LEN, P.JOURNAL_LEN)

    def test_unsalted_state_digest_confirms_a_guess_and_a_salted_one_does_not(self):
        """Illustrates why a deterministic digest of private machine state (the
        shape of a composite receipt's intermediate memory roots) is not a
        hiding handle. Not an attack on any RISC Zero artifact."""
        fx = self.fx
        candidates = [fx["x"], [v ^ 1 for v in fx["x"]]]
        unsalted = hashlib.sha256(struct.pack(f"<{P.T * P.D}h", *fx["x"])).digest()
        hits = [hashlib.sha256(struct.pack(f"<{P.T * P.D}h", *c)).digest() == unsalted
                for c in candidates]
        self.assertEqual(hits, [True, False])
        public_guess_salt = bytes(P.SALT_LEN)
        salted_hits = [P.endpoint_commitment(*self.base, 0, public_guess_salt, c)
                       == fx["input_commitment"] for c in candidates]
        self.assertEqual(salted_hits, [False, False])


class PublicDigests(unittest.TestCase):
    def setUp(self):
        self.fx = P.fixture()

    def test_weight_inventory_is_exact(self):
        tensors = self.fx["tensors"]
        self.assertEqual(P.weights_digest(0, tensors), self.fx["weights"])
        self.assertNotEqual(P.weights_digest(1, tensors), self.fx["weights"])
        tid, rows, cols, data = tensors[3]
        hostile = {
            "missing": tensors[:-1],
            "extra": tensors + [tensors[-1]],
            "reordered": [tensors[1], tensors[0]] + tensors[2:],
            "reshaped": tensors[:3] + [(tid, cols * 2, rows // 2, data)] + tensors[4:],
            "short": tensors[:3] + [(tid, rows, cols, data[:-1])] + tensors[4:],
            "bytearray": tensors[:3] + [(tid, rows, cols, bytearray(data))] + tensors[4:],
            "wrong id": tensors[:3] + [(99, rows, cols, data)] + tensors[4:],
        }
        for name, candidate in hostile.items():
            with self.subTest(case=name), self.assertRaises(P.ContractError):
                P.weights_digest(0, candidate)
        changed = tensors[:3] + [(tid, rows, cols, flip(data, 5))] + tensors[4:]
        self.assertNotEqual(P.weights_digest(0, changed), self.fx["weights"])

    def test_framed_digests_bind_length_and_domain(self):
        self.assertNotEqual(P.context_digest(b"a"), P.calibration_digest(b"a"))
        self.assertNotEqual(P.context_digest(b"a"), P.context_digest(b"a\0"))
        with self.assertRaises(P.ContractError):
            P.context_digest(b"x" * (P.MAX_CONTEXT_LEN + 1))
        with self.assertRaises(P.ContractError):
            P.context_digest("text")


class ReceiptEnvelope(unittest.TestCase):
    OK = dict(exit_code=("halted", 0), assumption_count=0, verifier_env={})

    def test_only_groth16_passes_by_default(self):
        P.admit_public_receipt("groth16", **self.OK)
        for kind in ("composite", "succinct", "fake", "Groth16", "", None):
            with self.subTest(kind=kind), self.assertRaises(P.ContractError):
                P.admit_public_receipt(kind, **self.OK)

    def test_succinct_needs_an_explicit_recorded_opt_in(self):
        P.admit_public_receipt("succinct", allow_vendor_zk_succinct=True, **self.OK)
        with self.assertRaises(P.ContractError):
            P.admit_public_receipt("succinct", allow_vendor_zk_succinct=1, **self.OK)
        for kind in ("composite", "fake"):
            with self.assertRaises(P.ContractError):
                P.admit_public_receipt(kind, allow_vendor_zk_succinct=True, **self.OK)

    def test_dev_mode_variable_refuses_whatever_its_value(self):
        for value in ("1", "0", "", "false"):
            with self.assertRaises(P.ContractError):
                P.admit_public_receipt("groth16", exit_code=("halted", 0),
                                       assumption_count=0,
                                       verifier_env={P.DEV_MODE_ENV: value})

    def test_exit_code_and_assumptions(self):
        for exit_code in (("paused", 0), ("halted", 1), ("system_split", 0), None):
            with self.assertRaises(P.ContractError):
                P.admit_public_receipt("groth16", exit_code=exit_code,
                                       assumption_count=0, verifier_env={})
        for count in (1, True, None):
            with self.assertRaises(P.ContractError):
                P.admit_public_receipt("groth16", exit_code=("halted", 0),
                                       assumption_count=count, verifier_env={})


if __name__ == "__main__":
    unittest.main()
