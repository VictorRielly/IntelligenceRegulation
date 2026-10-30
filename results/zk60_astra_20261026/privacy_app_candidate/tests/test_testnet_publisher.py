"""Real signing/ABI checks against a controlled RPC; no network or testnet spending."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media.base_sepolia import (BaseSepoliaRPC, CHAIN_ID, create_throwaway_key,
    read_throwaway_key, keccak, anchor_data, EVENT_SIGNATURE)
from proven_media.publisher import PublicationRecord, PublishError, make_publisher
from proven_media.testnet_publisher import BaseSepoliaPublisher


class RPC(BaseSepoliaRPC):
    def __init__(self, key):
        account = read_throwaway_key(key)
        self.code = b"test contract runtime"
        super().__init__("https://sepolia.invalid", "0x" + "11" * 20,
                         keccak(self.code).hex(), account.address, key)
        self.chain_id = CHAIN_ID
        self.tx = self.receipt = None
        self.height = 102
        self.block_hash = "0x" + "22" * 32
        self.sends = 0
        self.calls = []
        self.fail_after_send = False
        self.nonce = 0

    def call(self, method, params):
        self.calls.append(method)
        if method == "eth_chainId": return hex(self.chain_id)
        if method == "eth_getCode": return "0x" + self.code.hex()
        if method == "eth_call": return "0x" + "00" * 12 + self.publisher_address[2:]
        if method == "eth_getTransactionCount": return hex(self.nonce)
        if method == "eth_getBlockByNumber": return {"baseFeePerGas": "0x64", "hash": self.block_hash}
        if method == "eth_maxPriorityFeePerGas": return "0xa"
        if method == "eth_estimateGas": return hex(30_000)
        if method == "eth_getTransactionByHash": return self.tx
        if method == "eth_getTransactionReceipt": return self.receipt
        if method == "eth_blockNumber": return hex(self.height)
        if method == "eth_sendRawTransaction":
            from eth_account import Account
            from eth_account.typed_transactions import TypedTransaction
            from hexbytes import HexBytes
            raw = HexBytes(params[0])
            signed = TypedTransaction.from_bytes(raw).as_dict()
            tx_hash = "0x" + keccak(raw).hex()
            self.tx = {"hash": tx_hash, "from": Account.recover_transaction(raw),
                       "to": "0x" + bytes(signed["to"]).hex(), "chainId": hex(signed["chainId"]),
                       "value": hex(signed["value"]), "input": "0x" + bytes(signed["data"]).hex(),
                       "blockHash": self.block_hash}
            self.sends += 1
            self.nonce += 1
            if self.fail_after_send:
                self.fail_after_send = False
                raise PublishError("simulated lost response after successful broadcast")
            return tx_hash
        raise AssertionError((method, params))

    def mine(self):
        data = self.tx["input"][10:]
        root, count, batch_hash = data[:64], data[64:128], data[128:192]
        self.receipt = {"transactionHash": self.tx["hash"], "blockNumber": "0x64", "status": "0x1",
                        "blockHash": self.block_hash, "logs": [{"address": self.contract,
                        "topics": ["0x" + keccak(EVENT_SIGNATURE.encode()).hex(), "0x" + root],
                        "data": "0x" + count + batch_hash, "transactionHash": self.tx["hash"],
                        "blockHash": self.block_hash}]}


class TestBaseSepolia(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.key = self.root / "test.sepolia-key.json"
        create_throwaway_key(self.key)
        self.rpc = RPC(self.key)
        self.pub = BaseSepoliaPublisher(self.rpc, self.root, batch_secs=0)

    def record(self, index=1):
        segment = self.root / f"segment{index}.bin"
        segment.write_bytes(b"synthetic test receipt")
        segments = [{"file": segment.name, "bytes": segment.stat().st_size,
                     "sha256": hashlib.sha256(segment.read_bytes()).hexdigest()}]
        return PublicationRecord(post_id=f"{index:032x}", category="sexual", statement=b'{"test":true}',
            receipt_segments=[segment], verdict="no", model_id="01" * 32, policy_id="02" * 32,
            profile_id="03" * 32, verifier_id="04" * 32, content_commitment="05" * 32,
            segments_json=json.dumps(segments).encode(), token_range=(0, 20),
            proof_verified=True, verdict_bound=True)

    def finish(self):
        record = self.record()
        a = self.pub.publish(record)
        self.assertEqual(a.chain, "base-sepolia")
        self.assertIsNone(self.pub.tick(force=True))
        self.rpc.mine()
        self.assertEqual(self.pub.tick(), "batch-000000")
        return self.pub.anchor_of(record.post_id, record.category)

    def test_roundtrip_signing_batch_and_read_only_verify(self):
        a = self.finish()
        self.rpc.key_path = None
        result = self.pub.verify_publication(a)
        self.assertTrue(result["accepted"], result)
        self.assertEqual(self.rpc.sends, 1)
        self.assertEqual(a.block_number, 100)
        self.assertEqual(self.pub.pending_list(), [])

    def test_lost_broadcast_response_reuses_exact_envelope(self):
        self.pub.publish(self.record())
        self.rpc.fail_after_send = True
        with self.assertRaises(PublishError): self.pub.tick(force=True)
        stored = self.pub.inflight.read_bytes()
        resumed = BaseSepoliaPublisher(self.rpc, self.root)
        self.assertIsNone(resumed.tick())
        self.assertEqual(stored, resumed.inflight.read_bytes())
        self.assertEqual(self.rpc.sends, 1)
        self.rpc.mine()
        self.assertEqual(resumed.tick(), "batch-000000")

    def test_finalization_crash_replays_without_duplicate_block_or_send(self):
        record = self.record()
        self.pub.publish(record)
        self.pub.tick(force=True)
        self.rpc.mine()
        with patch.object(self.pub, "_write_anchor", side_effect=OSError("simulated disk failure")):
            with self.assertRaises(OSError): self.pub.tick()
        self.assertTrue(self.pub.inflight.exists())
        self.assertEqual(self.pub.tick(), "batch-000000")
        self.assertEqual(len(self.pub.blocks_list()), 1)
        self.assertEqual(self.rpc.sends, 1)

    def test_new_pending_publication_survives_inflight_batch(self):
        self.pub.publish(self.record())
        self.pub.tick(force=True)
        self.pub.publish(self.record(2))
        self.rpc.mine()
        self.pub.tick()
        self.assertEqual(len(self.pub.pending_list()), 1)
        self.assertEqual(self.pub.pending_list()[0]["post_id"], f"{2:032x}")

    def test_refuses_placeholder_unverified_or_changed_receipt(self):
        for field in ("proof_verified", "verdict_bound"):
            r = self.record()
            setattr(r, field, False)
            with self.assertRaises(PublishError): self.pub.publish(r)
        r = self.record()
        r.development_only = True
        with self.assertRaises(PublishError): self.pub.publish(r)
        r = self.record()
        Path(r.receipt_segments[0]).write_bytes(b"altered")
        with self.assertRaises(PublishError): self.pub.publish(r)
        self.assertEqual(self.pub.pending_list(), [])

    def test_receipt_snapshot_survives_later_prover_file_edits(self):
        record = self.record(); source = Path(record.receipt_segments[0]); original = source.read_bytes()
        anchor = self.pub.publish(record)
        manifest = self.pub.resolve(anchor)["manifest"]
        digest = manifest["segments"][0]["sha256"]
        source.write_bytes(b"changed after publication")
        self.assertEqual(self.pub.get_bytes(digest), original)
        self.assertNotEqual(source.stat().st_ino, self.pub._obj(digest).stat().st_ino)

    def test_source_change_between_precheck_and_copy_refuses_publication(self):
        record = self.record(); original = self.pub.put_file
        def race(path, expected=None):
            Path(path).write_bytes(b"changed between check and copy")
            return original(path, expected)
        with patch.object(self.pub, "put_file", side_effect=race):
            with self.assertRaises(PublishError): self.pub.publish(record)
        self.assertEqual(self.pub.pending_list(), [])
        self.assertEqual(self.rpc.sends, 0)

    def test_app_inventory_does_not_invent_native_segments_json(self):
        record = self.record(); record.receipt_inventory = json.loads(record.segments_json)
        record.segments_json = None
        anchor = self.pub.publish(record); manifest = self.pub.resolve(anchor)["manifest"]
        self.assertIsNone(manifest["segments_json_sha256"])
        self.assertEqual(manifest["segments"], record.receipt_inventory)

    def test_mainnet_wrong_contract_wrong_key_never_sign(self):
        self.rpc.chain_id = 8453
        with self.assertRaises(PublishError): self.rpc.prepare("11" * 32, 1, "22" * 32)
        self.rpc.chain_id = CHAIN_ID
        self.rpc.code = b"changed"
        with self.assertRaises(PublishError): self.rpc.prepare("11" * 32, 1, "22" * 32)
        self.assertNotIn("eth_sendRawTransaction", self.rpc.calls)

    def test_gas_bound_refuses_before_sign(self):
        self.rpc.gas_limit = 21_000
        with self.assertRaises(PublishError): self.rpc.prepare("11" * 32, 1, "22" * 32)

    def test_confirmations_and_reorg_fail_closed(self):
        a = self.finish()
        self.rpc.height = 100
        self.assertFalse(self.pub.verify_publication(a)["accepted"])
        self.rpc.height = 102
        self.rpc.block_hash = "0x" + "ff" * 32
        self.assertFalse(self.pub.verify_publication(a)["accepted"])

    def test_tampered_transaction_or_event_is_rejected(self):
        a = self.finish()
        tx, receipt = copy.deepcopy(self.rpc.tx), copy.deepcopy(self.rpc.receipt)
        mutations = [("tx", "value", "0x1"), ("tx", "input", "0x00"),
                     ("tx", "chainId", hex(8453)), ("tx", "from", "0x" + "ff" * 20),
                     ("receipt", "status", "0x0"), ("receipt", "logs", [])]
        for target, key, value in mutations:
            with self.subTest(target=target, key=key):
                self.rpc.tx, self.rpc.receipt = copy.deepcopy(tx), copy.deepcopy(receipt)
                getattr(self.rpc, target)[key] = value
                self.assertFalse(self.pub.verify_publication(a)["accepted"])

    def test_batch_and_anchor_tampering_is_rejected(self):
        a = self.finish()
        for field, value in [("chain", "base-mainnet"), ("leaf_index", 99), ("merkle_proof", ["ff" * 32]),
                             ("batch_id", "../../outside"), ("status", "made-up")]:
            b = copy.deepcopy(a)
            setattr(b, field, value)
            self.assertFalse(self.pub.verify_publication(b)["accepted"], field)
        batchfile = self.pub.batches / (a.batch_id + ".json")
        batch = json.loads(batchfile.read_text())
        batch["count"] += 1
        batchfile.write_text(json.dumps(batch))
        self.assertFalse(self.pub.verify_publication(a)["accepted"])

    def test_key_0600_exclusive_and_no_symlink(self):
        self.assertEqual(self.key.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError): create_throwaway_key(self.key)
        self.key.chmod(0o644)
        with self.assertRaises(PublishError): read_throwaway_key(self.key)
        self.key.chmod(0o600)
        link = self.root / "link"
        link.symlink_to(self.key)
        with self.assertRaises(PublishError): read_throwaway_key(link)

    def test_readonly_factory_does_not_need_key_file(self):
        cfg = self.root / "sepolia.json"
        cfg.write_text(json.dumps({"schema": "proven-media/base-sepolia/1", "chain_id": CHAIN_ID,
            "rpc_url": self.rpc.rpc_url, "contract": self.rpc.contract,
            "runtime_code_hash": self.rpc.runtime_code_hash, "publisher_address": self.rpc.publisher_address}))
        p = make_publisher(self.root, mode="base-sepolia", config_path=cfg, read_only=True)
        self.assertIsNone(p.transport.key_path)
        self.assertEqual(p.name, "base-sepolia")

    def test_abi_matches_independent_encoder(self):
        from eth_abi import encode
        expected = keccak(b"anchor(bytes32,uint256,bytes32)")[:4] + encode(
            ["bytes32", "uint256", "bytes32"], [bytes.fromhex("13" * 32), 17, bytes.fromhex("29" * 32)])
        self.assertEqual(anchor_data("13" * 32, 17, "29" * 32), "0x" + expected.hex())


if __name__ == "__main__": unittest.main()
