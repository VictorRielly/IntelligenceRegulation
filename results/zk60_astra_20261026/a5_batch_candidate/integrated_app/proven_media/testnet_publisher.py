"""Base Sepolia Publisher with durable batches and explicit local proof storage.

Only batch digests go on the testnet; proof objects remain in the app's local
content-addressed store. This does not claim permanent/network proof storage.
"""
from __future__ import annotations

from .quarantine_paths import require_public_receipt_path

import json
import os
from pathlib import Path
import time
from dataclasses import replace

from . import records
from .base_sepolia import BaseSepoliaRPC, CHAIN_NAME, anchor_data
from .publisher import (AnchorRef, BATCH_SCHEMA, LocalChainPublisher, MAX_BATCH,
                        PublishError, merkle, merkle_check)


def atomic_json(path: Path, data):
    temp = path.with_name(path.name + ".tmp")
    with temp.open("wb") as out:
        out.write(records.canonical(data))
        out.flush()
        os.fsync(out.fileno())
    os.replace(temp, path)
    fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


class BaseSepoliaPublisher(LocalChainPublisher):
    name = CHAIN_NAME
    chain_name = CHAIN_NAME
    description = ("Base Sepolia TESTNET batch anchors; receipts remain in this machine's "
                   "content-addressed store. Test ETH only. Anchoring is not proof verification "
                   "or permanent proof storage.")

    def __init__(self, transport: BaseSepoliaRPC, root: Path | None = None, batch_secs=None):
        self.transport = transport
        self.contract = transport.contract
        # Separate namespace prevents existing local-stub anchors being read as testnet data.
        from . import config
        super().__init__(Path(root or config.PUBLIC_DIR) / "base-sepolia", batch_secs)
        self.inflight = self.chain_dir / "inflight.json"
        self.batches = self.chain_dir / "batches"
        self.batches.mkdir(exist_ok=True)

    def _write_anchor(self, a: AnchorRef):
        atomic_json(self.anchors / f"{a.post_id}.c{a.chunk}.{a.category}.json", a.to_dict())

    def _load_batch(self, batch_id: str):
        if not isinstance(batch_id, str) or not batch_id.startswith("batch-") or not batch_id[6:].isdigit():
            raise PublishError("invalid batch id")
        return json.loads((self.batches / (batch_id + ".json")).read_text())

    def publish(self, record):
        for path in record.receipt_segments:
            require_public_receipt_path(path)
        if record.development_only is not False:
            raise PublishError("development classifier fixtures cannot be published as media labels")
        if record.proof_verified is not True or record.verdict_bound is not True:
            raise PublishError("testnet publication requires a verified proof with a bound verdict")
        if not record.receipt_segments or (record.receipt_inventory is None and record.segments_json is None):
            raise PublishError("testnet publication requires receipt segments and their verified inventory")
        expected = record.receipt_inventory if record.receipt_inventory is not None else json.loads(record.segments_json)
        # Native manifests have a list of segments, or a named segments list.
        expected = expected.get("segments", []) if isinstance(expected, dict) else expected
        if not isinstance(expected, list) or len(expected) != len(record.receipt_segments):
            raise PublishError("verified segment manifest count mismatch")
        for path, row in zip(record.receipt_segments, expected):
            path = Path(path)
            if (row["file"] != path.name or row["bytes"] != path.stat().st_size
                    or row["sha256"] != records.sha256_file(path)):
                raise PublishError("receipt differs from verified segment manifest")
        # Preserve the expected digests through the actual snapshot operation;
        # changing a source after this pre-check cannot publish different bytes.
        return super().publish(replace(record, receipt_inventory=expected))

    def tick(self, now: float | None = None, force: bool = False) -> str | None:
        now = time.time() if now is None else now
        with self._lock():
            if self.inflight.exists():
                batch = json.loads(self.inflight.read_text())
            else:
                pending = self.pending_list()
                if not pending or not (force or len(pending) >= MAX_BATCH or
                        now - min(p["queued_at"] for p in pending) >= self.batch_secs):
                    return None
                take = pending[:MAX_BATCH]
                root, proofs, leaves = merkle([p["leaf_hash"] for p in take])
                if len(leaves) != len(take):
                    raise PublishError("duplicate pending leaf")
                batch_id = f"batch-{len(self.blocks_list()):06d}"
                batch_file = {"schema": BATCH_SCHEMA, "batch_id": batch_id, "root": root,
                              "count": len(leaves), "leaves": leaves, "closed_at": records.now_iso(),
                              "tree": "sorted leaves; SHA-256 domain-separated sorted nodes; odd node carried"}
                file_hash = self.put_bytes(records.canonical(batch_file))
                batch = {"batch_id": batch_id, "root": root, "count": len(leaves), "leaves": leaves,
                         "proofs": proofs, "take": take, "batch_file_hash": file_hash,
                         "envelope": self.transport.prepare(root, len(leaves), file_hash)}
                atomic_json(self.inflight, batch)  # signed envelope durable BEFORE first send
            self._validate_batch(batch)
            envelope = batch["envelope"]
            # Check before rebroadcast: a previous process may have submitted successfully.
            confirmed = self.transport.confirmed(envelope["tx_hash"], batch["root"], batch["count"],
                                                 batch["batch_file_hash"])
            if confirmed is None:
                self.transport.broadcast(envelope)
                return None  # confirmation polling is nonblocking; next worker tick continues
            batch["confirmation"] = confirmed
            atomic_json(self.batches / (batch["batch_id"] + ".json"), batch)
            blocks = self.blocks_list()
            if not any(b["batch_id"] == batch["batch_id"] for b in blocks):
                block = {"batch_id": batch["batch_id"], "block_number": confirmed["block_number"],
                         "block_hash": confirmed["block_hash"], "ts": records.now_iso(),
                         "txs": [{"method": "anchor", "contract": self.contract,
                                  "tx_hash": envelope["tx_hash"],
                                  "args": {k: batch[k] for k in ("root", "count", "batch_file_hash", "batch_id")}}]}
                with self.blocks.open("a") as out:
                    out.write(json.dumps(block) + "\n")
                    out.flush()
                    os.fsync(out.fileno())
            for p in batch["take"]:
                a = self.anchor_of(p["post_id"], p["category"], p["chunk"])
                if a is None or a.leaf_hash != p["leaf_hash"]:
                    raise PublishError("pending anchor disappeared or changed")
                a.status, a.batch_id = "anchored", batch["batch_id"]
                a.chain, a.contract = self.chain_name, self.contract
                a.tx_hash, a.block_number = envelope["tx_hash"], confirmed["block_number"]
                a.merkle_root, a.leaf_index = batch["root"], batch["leaves"].index(a.leaf_hash)
                a.merkle_proof = batch["proofs"][a.leaf_hash]
                a.anchored_at = records.now_iso()
                self._write_anchor(a)
            taken = {p["leaf_hash"] for p in batch["take"]}
            remaining = [p for p in self.pending_list() if p["leaf_hash"] not in taken]
            temp = self.pending.with_name("pending.jsonl.tmp")
            with temp.open("w") as out:
                out.write("".join(json.dumps(p) + "\n" for p in remaining))
                out.flush()
                os.fsync(out.fileno())
            os.replace(temp, self.pending)
            fd = os.open(self.chain_dir, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)  # pending removal must survive before clearing the recovery journal
            finally:
                os.close(fd)
            self.inflight.unlink()  # replay before this point safely repeats finalization
            fd = os.open(self.chain_dir, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
            return batch["batch_id"]

    def _validate_batch(self, batch):
        bf = json.loads(self.get_bytes(batch["batch_file_hash"]))
        root, proofs, leaves = merkle([p["leaf_hash"] for p in batch["take"]])
        if (root != batch["root"] or leaves != batch["leaves"] or proofs != batch["proofs"]
                or len(leaves) != batch["count"] or len(leaves) != len(batch["take"])
                or bf["leaves"] != leaves or bf["root"] != root or bf["count"] != len(leaves)
                or bf["batch_id"] != batch["batch_id"]
                or batch["envelope"]["transaction"]["data"] != anchor_data(root, len(leaves), batch["batch_file_hash"])):
            raise PublishError("batch plan or transaction differs from content-addressed batch file")

    def _verify_anchor(self, a: AnchorRef, chk):
        chk("anchored", a.status == "anchored", "not an anchored testnet publication")
        chk("chain", a.chain == self.chain_name and a.contract.lower() == self.contract,
            "wrong chain or contract")
        batch = self._load_batch(a.batch_id)
        self._validate_batch(batch)
        chk("batch_identity", a.tx_hash == batch["envelope"]["tx_hash"] and a.merkle_root == batch["root"])
        chk("batch_membership", type(a.leaf_index) is int and 0 <= a.leaf_index < batch["count"]
            and batch["leaves"][a.leaf_index] == a.leaf_hash)
        chk("merkle_path", merkle_check(a.leaf_hash, a.merkle_proof, batch["root"]))
        confirmed = self.transport.confirmed(a.tx_hash, batch["root"], batch["count"], batch["batch_file_hash"])
        chk("anchor_tx", confirmed is not None and confirmed["block_number"] == a.block_number,
            "transaction lacks a canonical confirmed Anchored event")
        return confirmed

    def verify_publication(self, anchor_ref, rehash_segments=True):
        try:
            return super().verify_publication(anchor_ref, rehash_segments)
        except (PublishError, OSError, ValueError, KeyError, TypeError, IndexError) as e:
            return {"accepted": False, "reasons": [f"testnet publication check failed: {type(e).__name__}"],
                    "checks": {"testnet_publication": False}}
