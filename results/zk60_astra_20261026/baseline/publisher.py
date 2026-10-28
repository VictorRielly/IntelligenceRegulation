"""Publication of accepted proofs (D39 (2)), shaped to the feasibility report's interface
(`results/zk60_chain_publication_20261021/REPORT.md` §5-§7):

    publish(record: PublicationRecord) -> AnchorRef
    resolve(anchor_ref) -> {"manifest", "statement", ...}
    verify_publication(anchor_ref) -> {"accepted", "reasons", "checks"}

LocalChainPublisher is the LOCAL STUB: no network, wallet, key or transaction.
  * bundle store: content-addressed objects `objects/<aa>/<sha256>` (stands in for Filecoin + R2 for
    the receipt segments and Arweave for the manifest, statement and batch files). URIs are
    `local-cas://sha256/<hex>`;
  * chain: an append-only JSON-lines block file (`chain/blocks.jsonl`), each block hash-chained to
    the previous one and carrying one `anchor(root, count, batch_file_hash)` call (stands in for the
    minimal contract on Base);
  * batcher: leaves wait in `chain/pending.jsonl`; a batch closes every BATCH_SECS (default 600 s,
    the report's 10 minutes) or at 1,000 leaves, as a sorted, domain-separated Merkle tree;
  * ONE publication per (item, chunk, category) proof (labels model D37, chunks D41): each AnchorRef
    is written to `chain/anchors/<post_id>.c<chunk>.<category>.json` ("pending" until its batch closes, then "anchored"
    with the Merkle proof). Identical receipt segments are stored once (content addressing).
Encodings (fixed here, checked by `verify_publication` and `tools/verify_publication.py`):
  leaf = SHA-256("zk60/anchor-leaf/v3" || f(post_id) || f(category) || f(chunk) || f(token_range) ||
                 f(manifest_sha256) || f(statement_hash) || f(verdict) || f(model_id) || f(policy_id) ||
                 f(content_commitment)), chunk as ASCII decimal, token_range as ASCII "start-end";
         f(x) = u16-be(len(bytes)) || bytes; hex fields as raw bytes, the category id and the verdict
         (the category label, "yes" or "no") as ASCII;
  node = SHA-256("zk60/anchor-node/v1" || min(a, b) || max(a, b)) over the SORTED leaves, an odd
         node carried up unchanged; a one-leaf tree's root is the leaf.
Only ACCEPTED proofs are published (after a fresh-process verify accepted), whatever the label.
The endpoint roots are not put in the leaf or the block (privacy hypothesis O-2 / D23; the D23
amendment for anchoring is pending); the content commitment is the app's SALTED commitment.
"""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import shutil
import struct
import time
from abc import ABC, abstractmethod
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import config, records

PUB_SCHEMA = "zk60.publication/1"
MANIFEST_SCHEMA = "zk60.publication-manifest/1"
BATCH_SCHEMA = "zk60.anchor-batch/1"
LEAF_DOMAIN = b"zk60/anchor-leaf/v3"
NODE_DOMAIN = b"zk60/anchor-node/v1"
CONTENT_DOMAIN = b"zk60/proven-media/content/v1"
CHAIN_NAME = "local-chain (stand-in for base-mainnet)"
CONTRACT = "local:ProvenMediaAnchor"
MAX_BATCH = 1000


class PublishError(Exception):
    pass


# ---------------------------------------------------------------- data types (report §7)

@dataclass
class PublicationRecord:
    post_id: str                       # 128-bit random hex, never a user id
    category: str                      # one registered category (one proof per category)
    statement: bytes                   # canonical JSON as the verifier wrote it (statement.json bytes)
    receipt_segments: list             # per-layer segment file paths
    verdict: str                       # the category label, "yes" or "no" (only ACCEPTED proofs are published)
    model_id: str
    policy_id: str
    profile_id: str
    verifier_id: str
    content_commitment: str            # salted (report §5)
    segments_json: bytes | None = None  # the verifier's statement/segments.json (lets a third party rebuild the run)
    chunk: int = 0                     # D41: which chunk of the item this proof covers
    token_range: tuple = (0, 0)        # [start, end) in the item's content tokens
    schema: str = PUB_SCHEMA


@dataclass
class AnchorRef:
    post_id: str
    status: str                        # "pending" | "anchored" | "l1_checkpointed"
    chain: str = CHAIN_NAME
    contract: str = CONTRACT
    tx_hash: str | None = None
    block_number: int | None = None
    batch_id: str | None = None
    merkle_root: str | None = None
    leaf_index: int | None = None
    leaf_hash: str = ""
    merkle_proof: list = field(default_factory=list)
    manifest_sha256: str = ""
    manifest_uri: str = ""
    receipt_uris: list = field(default_factory=list)
    statement_uri: str = ""
    published_at: str = ""
    anchored_at: str | None = None
    category: str = ""
    chunk: int = 0
    token_range: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict) -> "AnchorRef":
        return AnchorRef(**{k: d[k] for k in AnchorRef.__dataclass_fields__ if k in d})


# ---------------------------------------------------------------- encodings

def content_commitment(salt: bytes, content: bytes) -> str:
    """c = SHA-256("zk60/proven-media/content/v1" || salt_32 || u64-be len || content bytes)"""
    if len(salt) != 32:
        raise ValueError("the salt is 32 bytes")
    return hashlib.sha256(CONTENT_DOMAIN + salt + struct.pack(">Q", len(content)) + content).hexdigest()


def _f(b: bytes) -> bytes:
    return struct.pack(">H", len(b)) + b


def leaf_hash(post_id: str, category: str, chunk: int, token_range, manifest_sha256: str, statement_hash: str,
              verdict: str, model_id: str, policy_id: str, content_commitment_hex: str) -> str:
    parts = [bytes.fromhex(post_id), category.encode(), str(int(chunk)).encode(),
             f"{int(token_range[0])}-{int(token_range[1])}".encode(), bytes.fromhex(manifest_sha256),
             bytes.fromhex(statement_hash), verdict.encode(),
             bytes.fromhex(model_id), bytes.fromhex(policy_id), bytes.fromhex(content_commitment_hex)]
    return hashlib.sha256(LEAF_DOMAIN + b"".join(_f(p) for p in parts)).hexdigest()


def _node(a: bytes, b: bytes) -> bytes:
    lo, hi = (a, b) if a <= b else (b, a)
    return hashlib.sha256(NODE_DOMAIN + lo + hi).digest()


def merkle(leaves_hex: list[str]) -> tuple[str, dict[str, list[str]], list[str]]:
    """sorted tree: (root, proof per leaf, sorted leaves)"""
    srt = sorted(set(leaves_hex))
    level = [bytes.fromhex(x) for x in srt]
    pos = {x: i for i, x in enumerate(srt)}
    proofs = {x: [] for x in srt}
    members = [[x] for x in srt]               # which leaves sit under each node of the level
    while len(level) > 1:
        nxt, nmem = [], []
        for i in range(0, len(level), 2):
            if i + 1 == len(level):
                nxt.append(level[i])
                nmem.append(members[i])
                continue
            a, b = level[i], level[i + 1]
            for x in members[i]:
                proofs[x].append(b.hex())
            for x in members[i + 1]:
                proofs[x].append(a.hex())
            nxt.append(_node(a, b))
            nmem.append(members[i] + members[i + 1])
        level, members = nxt, nmem
    del pos
    return level[0].hex(), proofs, srt


def merkle_check(leaf_hex: str, proof: list[str], root_hex: str) -> bool:
    h = bytes.fromhex(leaf_hex)
    for sib in proof:
        h = _node(h, bytes.fromhex(sib))
    return h.hex() == root_hex


def _block_hash(b: dict) -> str:
    return hashlib.sha256(records.canonical({k: v for k, v in b.items() if k != "block_hash"})).hexdigest()


# ---------------------------------------------------------------- interface

class Publisher(ABC):
    name = "abstract"
    description = ""

    @abstractmethod
    def publish(self, record: PublicationRecord) -> AnchorRef:
        ...

    @abstractmethod
    def resolve(self, anchor_ref: AnchorRef) -> dict:
        ...

    @abstractmethod
    def verify_publication(self, anchor_ref: AnchorRef) -> dict:
        ...

    def tick(self, now: float | None = None) -> str | None:
        """close a batch when due; returns the batch id or None"""
        return None


class LocalChainPublisher(Publisher):
    name = "local-chain"
    description = ("LOCAL STUB: a content-addressed bundle store and a hash-chained block file on this machine, "
                   "standing in for Filecoin + R2 (receipts), Arweave (manifests, statements, batch files) and an "
                   "anchor contract on Base. No chain, network, wallet or key.")

    def __init__(self, root: Path | None = None, batch_secs: float | None = None):
        root = Path(root or config.PUBLIC_DIR)
        self.store = root / "bundle-store"
        self.chain_dir = root / "chain"
        self.blocks = self.chain_dir / "blocks.jsonl"
        self.pending = self.chain_dir / "pending.jsonl"
        self.anchors = self.chain_dir / "anchors"
        self.lockf = self.chain_dir / ".lock"
        self.batch_secs = float(batch_secs if batch_secs is not None else os.environ.get("PM_BATCH_SECS", "600"))
        for d in (self.store, self.chain_dir, self.anchors):
            d.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------ store
    def _obj(self, sha: str) -> Path:
        return self.store / "objects" / sha[:2] / sha

    @staticmethod
    def uri(sha: str) -> str:
        return f"local-cas://sha256/{sha}"

    def put_bytes(self, data: bytes) -> str:
        sha = hashlib.sha256(data).hexdigest()
        p = self._obj(sha)
        if not p.exists():
            p.parent.mkdir(parents=True, exist_ok=True)
            tmp = p.with_name(p.name + f".tmp-{os.getpid()}")
            tmp.write_bytes(data)
            os.replace(tmp, p)
        return sha

    def put_file(self, path: Path, expect_sha: str | None = None) -> tuple[str, int]:
        sha = records.sha256_file(path)
        if expect_sha and sha != expect_sha:
            raise PublishError(f"{path.name}: sha256 differs from the verified segments.json")
        p = self._obj(sha)
        if not p.exists():
            p.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(path, p)
            except OSError:
                tmp = p.with_name(p.name + f".tmp-{os.getpid()}")
                shutil.copyfile(path, tmp)
                os.replace(tmp, p)
        return sha, path.stat().st_size

    def get_bytes(self, sha: str) -> bytes:
        data = self._obj(sha).read_bytes()
        if hashlib.sha256(data).hexdigest() != sha:
            raise PublishError(f"object {sha[:16]}: content does not match its address")
        return data

    def delete_object(self, sha: str) -> bool:
        p = self._obj(sha)
        if p.exists():
            p.unlink()
            return True
        return False

    # ------------------------------------------------------------ helpers
    def _lock(self):
        fh = open(self.lockf, "a+")
        fcntl.flock(fh, fcntl.LOCK_EX)
        return fh

    def _read_jsonl(self, p: Path) -> list[dict]:
        if not p.exists():
            return []
        return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]

    def _write_anchor(self, a: AnchorRef) -> None:
        p = self.anchors / f"{a.post_id}.c{a.chunk}.{a.category}.json"
        tmp = p.with_name(p.name + ".tmp")
        tmp.write_text(json.dumps(a.to_dict(), indent=1, sort_keys=True))
        os.replace(tmp, p)

    def anchor_of(self, post_id: str, category: str, chunk: int = 0) -> AnchorRef | None:
        p = self.anchors / f"{post_id}.c{int(chunk)}.{category}.json"
        return AnchorRef.from_dict(json.loads(p.read_text())) if p.exists() else None

    def anchors_of(self, post_id: str) -> dict[str, AnchorRef]:
        """{"c<chunk>.<category>": AnchorRef} for every published proof of the item"""
        out = {}
        for f in sorted(self.anchors.glob(f"{post_id}.c*.json")):
            a = AnchorRef.from_dict(json.loads(f.read_text()))
            out[f"c{a.chunk}.{a.category}"] = a
        return out

    def blocks_list(self) -> list[dict]:
        return self._read_jsonl(self.blocks)

    def pending_list(self) -> list[dict]:
        return self._read_jsonl(self.pending)

    # ------------------------------------------------------------ publish
    def publish(self, record: PublicationRecord) -> AnchorRef:
        if record.verdict not in ("yes", "no"):
            raise PublishError("a published label is 'yes' or 'no' (an unproved category is not published)")
        if self.anchor_of(record.post_id, record.category, record.chunk):
            raise PublishError("this chunk's label for this category is already published (proved once)")
        segs = []
        for path in record.receipt_segments:
            path = Path(path)
            sha, n = self.put_file(path)
            segs.append({"file": path.name, "bytes": n, "sha256": sha})
        statement_hash = self.put_bytes(record.statement)
        segjson_hash = self.put_bytes(record.segments_json) if record.segments_json is not None else None
        manifest = {"schema": MANIFEST_SCHEMA, "publication_schema": record.schema, "post_id": record.post_id,
                    "category": record.category, "chunk": int(record.chunk),
                    "token_range": [int(record.token_range[0]), int(record.token_range[1])],
                    "statement_sha256": statement_hash, "statement_uri": self.uri(statement_hash),
                    "segments_json_sha256": segjson_hash,
                    "segments": segs, "verdict": record.verdict, "model_id": record.model_id,
                    "policy_id": record.policy_id, "profile_id": record.profile_id, "verifier_id": record.verifier_id,
                    "content_commitment": record.content_commitment,
                    "content_commitment_rule": "SHA-256(\"zk60/proven-media/content/v1\" || salt_32 || u64-be len || UTF-8 content)"}
        manifest_sha = self.put_bytes(records.canonical(manifest))
        lh = leaf_hash(record.post_id, record.category, record.chunk, record.token_range, manifest_sha, statement_hash,
                       record.verdict, record.model_id, record.policy_id, record.content_commitment)
        a = AnchorRef(post_id=record.post_id, category=record.category, chunk=int(record.chunk),
                      token_range=[int(record.token_range[0]), int(record.token_range[1])], status="pending", leaf_hash=lh,
                      manifest_sha256=manifest_sha,
                      manifest_uri=self.uri(manifest_sha), receipt_uris=[self.uri(s["sha256"]) for s in segs],
                      statement_uri=self.uri(statement_hash), published_at=records.now_iso())
        with self._lock():
            with open(self.pending, "a") as fh:
                fh.write(json.dumps({"post_id": record.post_id, "category": record.category, "chunk": int(record.chunk),
                                     "leaf_hash": lh,
                                     "queued_at": time.time()}) + "\n")
            self._write_anchor(a)
        return a

    # ------------------------------------------------------------ batcher
    def tick(self, now: float | None = None, force: bool = False) -> str | None:
        now = now or time.time()
        with self._lock():
            pend = self._read_jsonl(self.pending)
            if not pend:
                return None
            due = force or len(pend) >= MAX_BATCH or now - min(p["queued_at"] for p in pend) >= self.batch_secs
            if not due:
                return None
            take = pend[:MAX_BATCH]
            rest = pend[MAX_BATCH:]
            root, proofs, srt = merkle([p["leaf_hash"] for p in take])
            blocks = self._read_jsonl(self.blocks)
            number = len(blocks)
            batch_id = f"batch-{number:06d}"
            batch_file = {"schema": BATCH_SCHEMA, "batch_id": batch_id, "root": root, "count": len(srt),
                          "leaves": srt, "closed_at": records.now_iso(),
                          "tree": "sorted leaves; node = SHA-256('zk60/anchor-node/v1' || min || max); odd node carried up"}
            bf_sha = self.put_bytes(records.canonical(batch_file))
            tx = {"method": "anchor", "contract": CONTRACT,
                  "args": {"root": root, "count": len(srt), "batch_file_hash": bf_sha, "batch_id": batch_id},
                  "from": "local publisher (no key)"}
            tx_hash = hashlib.sha256(records.canonical(tx)).hexdigest()
            block = {"block_number": number, "prev_block_hash": blocks[-1]["block_hash"] if blocks else "0" * 64,
                     "ts": records.now_iso(), "txs": [{**tx, "tx_hash": tx_hash}]}
            block["block_hash"] = _block_hash(block)
            with open(self.blocks, "a") as fh:
                fh.write(json.dumps(block, sort_keys=True) + "\n")
                fh.flush()
                os.fsync(fh.fileno())
            idx = {x: i for i, x in enumerate(srt)}
            for p in take:
                a = self.anchor_of(p["post_id"], p.get("category", ""), p.get("chunk", 0))
                if a is None:
                    continue
                a.status, a.tx_hash, a.block_number, a.batch_id = "anchored", tx_hash, number, batch_id
                a.merkle_root, a.leaf_index, a.merkle_proof = root, idx[p["leaf_hash"]], proofs[p["leaf_hash"]]
                a.anchored_at = block["ts"]
                self._write_anchor(a)
            tmp = self.pending.with_name("pending.jsonl.tmp")
            tmp.write_text("".join(json.dumps(p) + "\n" for p in rest))
            os.replace(tmp, self.pending)
            return batch_id

    def next_batch_in(self, now: float | None = None) -> float | None:
        pend = self.pending_list()
        if not pend:
            return None
        return max(0.0, self.batch_secs - ((now or time.time()) - min(p["queued_at"] for p in pend)))

    # ------------------------------------------------------------ resolve / verify
    def resolve(self, anchor_ref: AnchorRef) -> dict:
        manifest = json.loads(self.get_bytes(anchor_ref.manifest_sha256))
        statement = self.get_bytes(manifest["statement_sha256"])
        return {"manifest": manifest, "statement": json.loads(statement), "anchor": anchor_ref.to_dict()}

    def verify_publication(self, anchor_ref: AnchorRef, rehash_segments: bool = True) -> dict:
        """the publication checks a third party runs (report §7 step 7) minus running the proof verifier
        itself (the app's "Re-verify now" / the CLI's --run-verifier do that)"""
        reasons, checks = [], {}

        def chk(name, ok, why=""):
            checks[name] = bool(ok)
            if not ok:
                reasons.append(f"{name}: {why}" if why else name)

        a = anchor_ref
        try:
            manifest_raw = self.get_bytes(a.manifest_sha256)
            manifest = json.loads(manifest_raw)
            chk("manifest_hash", True)
        except (FileNotFoundError, PublishError) as e:
            chk("manifest_hash", False, str(e))
            return {"accepted": False, "reasons": reasons, "checks": checks}
        chk("manifest_post_id", manifest.get("post_id") == a.post_id and manifest.get("category") == a.category
            and int(manifest.get("chunk", 0)) == int(a.chunk), "the manifest names another post, chunk or category")
        chk("label_value", manifest.get("verdict") in ("yes", "no"), "a published label is 'yes' or 'no'")
        try:
            self.get_bytes(manifest["statement_sha256"])
            chk("statement_hash", True)
        except (FileNotFoundError, PublishError) as e:
            chk("statement_hash", False, str(e))
        lh = leaf_hash(a.post_id, a.category, manifest.get("chunk", 0), manifest.get("token_range", [0, 0]),
                       a.manifest_sha256, manifest["statement_sha256"], manifest["verdict"],
                       manifest["model_id"], manifest["policy_id"], manifest["content_commitment"])
        chk("leaf_hash", lh == a.leaf_hash, "the leaf does not hash the manifest's fields")
        bad = []
        for s in manifest["segments"]:
            p = self._obj(s["sha256"])
            if not p.exists() or p.stat().st_size != s["bytes"]:
                bad.append(s["file"])
            elif rehash_segments and records.sha256_file(p) != s["sha256"]:
                bad.append(s["file"])
        chk("receipt_segments", not bad, f"missing or altered: {', '.join(bad[:4])}")
        if a.status == "pending":
            reasons.append("not anchored yet: waiting for the next batch")
            checks["anchored"] = False
            return {"accepted": False, "pending": True, "reasons": reasons, "checks": checks, "manifest": manifest}
        blocks = self.blocks_list()
        ok_chain = all(b["block_hash"] == _block_hash(b) and
                       b["prev_block_hash"] == (blocks[i - 1]["block_hash"] if i else "0" * 64)
                       for i, b in enumerate(blocks))
        chk("chain_integrity", ok_chain, "a block hash or link does not match")
        blk = blocks[a.block_number] if a.block_number is not None and a.block_number < len(blocks) else None
        tx = next((t for t in (blk or {}).get("txs", []) if t.get("tx_hash") == a.tx_hash), None)
        chk("anchor_tx", tx is not None and tx["args"]["root"] == a.merkle_root, "no anchor transaction with this root")
        chk("merkle_path", merkle_check(a.leaf_hash, a.merkle_proof, a.merkle_root or ""), "the path does not reach the root")
        if tx:
            try:
                bf = json.loads(self.get_bytes(tx["args"]["batch_file_hash"]))
                chk("batch_file", bf["root"] == a.merkle_root and a.leaf_hash in bf["leaves"], "the batch file disagrees")
            except (FileNotFoundError, PublishError) as e:
                chk("batch_file", False, str(e))
        return {"accepted": not reasons, "reasons": reasons, "checks": checks, "manifest": manifest,
                "block": {k: blk[k] for k in ("block_number", "block_hash", "ts")} if blk else None}

    # ------------------------------------------------------------ deletion (crypto-shredding happens in the app)
    def delete_receipt(self, anchor_ref: AnchorRef) -> int:
        """delete the receipt segments from the store (the leaf stays anchored, now unlinkable)"""
        manifest = json.loads(self.get_bytes(anchor_ref.manifest_sha256))
        return sum(self.delete_object(s["sha256"]) for s in manifest["segments"])
