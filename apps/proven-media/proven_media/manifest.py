"""The ProofManifest (`zk60.manifest/1`): the signed list of an item's classifier proofs, appended to
the item whenever it is served (D37 addendum; content-credentials / C2PA-style).

One entry per registered category: classifier and model id, policy id and digest, threshold, the
label (yes / no, or "unproved" when no accepted proof exists: fail closed), the statement hash, the
bundle reference (the publication manifest's hash and URI), the anchor reference (chain, contract,
leaf hash; resolvable to the Merkle path once its batch closes) and the item's salted content
commitment. The app's publisher key signs the canonical manifest with Ed25519.

THE KEY IS A LOCAL DEVELOPMENT KEY: generated into a 0600 file under the private data root
(config.SIGNING_KEY); its public half is published in every manifest and at /api/publisher-key.
No real keys.

    build_manifest(...) -> dict (signed)        verify_manifest(manifest, publisher) -> {accepted, reasons, checks}
"""
from __future__ import annotations

import base64
import hashlib
import os

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey

from . import config, records

SCHEMA = "zk60.manifest/1"
ISSUER = "Proven Media (local demo publisher, DEV KEY)"


# ---------------------------------------------------------------- the dev key

def _load_or_create() -> Ed25519PrivateKey:
    p = config.SIGNING_KEY
    if not p.exists():
        p.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        raw = Ed25519PrivateKey.generate().private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw,
                                                         serialization.NoEncryption())
        try:
            fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as f:
                f.write(raw)
        except FileExistsError:
            pass
    return Ed25519PrivateKey.from_private_bytes(p.read_bytes())


def public_key_hex() -> str:
    return _load_or_create().public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw).hex()


def key_id(pub_hex: str) -> str:
    return hashlib.sha256(bytes.fromhex(pub_hex)).hexdigest()[:16]


def _body(m: dict) -> bytes:
    return records.canonical({k: v for k, v in m.items() if k != "signature"})


def sign(m: dict) -> dict:
    sk = _load_or_create()
    pub = public_key_hex()
    m = dict(m)
    m["issuer"] = {"name": ISSUER, "key_id": key_id(pub), "public_key": pub, "alg": "Ed25519",
                   "note": "local development key; no real keys"}
    m["signature"] = {"alg": "Ed25519", "key_id": key_id(pub),
                      "value": base64.b64encode(sk.sign(_body(m))).decode()}
    return m


# ---------------------------------------------------------------- build

def build_manifest(post: dict, item: dict, anchors: dict, pubs: dict, content_commitment: str | None,
                   failure: str | None = None) -> dict:
    """the signed manifest once the item's labels are complete (D41: every chunk's proofs done or failed).
    `item`: {labels (aggregated per category), chunks: [{index, start, end, record, error}], content_length,
    proved_at}; `anchors` / `pubs`: "c<chunk>.<category>" -> AnchorRef / PublicationRecord of each
    published proof. One entry per (chunk, category): exactly what was published."""
    th = records.threshold()
    entries = []
    prover = {}
    for ch in item.get("chunks", []):
        rec = ch.get("record") or {}
        prover = prover or rec.get("prover", {})
        eff = records.effective_labels(rec if rec else None)
        for c in config.CATEGORIES:
            key = f"c{ch['index']}.{c['id']}"
            a, pb = anchors.get(key), pubs.get(key)
            accepted = eff[c["id"]] != records.UNPROVED
            pr = rec.get("prover", {})
            entries.append({
                "chunk": ch["index"], "token_range": [ch["start"], ch["end"]],
                "category": c["id"], "category_name": c["name"],
                "classifier": f"{config.CLASSIFIER_NAME} (demo stub: {pr.get('model', 'no proof')})" if pr.get("kind") == "stub-next-token"
                              else config.CLASSIFIER_NAME,
                "model_id": pb.model_id if pb else pr.get("model_digest"),
                "profile_id": pb.profile_id if pb else pr.get("token_profile_digest"),
                "verifier_id": config.STUB_BIN_SHA256 if pr.get("kind") == "stub-next-token" else None,
                "policy_id": c["policy_id"], "policy_sha256": c["sha256"],
                "threshold": {"tau": th["tau"], "c": th["c"]},
                "verdict": eff[c["id"]],
                "proof_status": "accepted" if accepted else "none",
                "error": None if accepted else (ch.get("error") or "no accepted proof"),
                "verdict_bound_by_proof": bool((rec.get("labels") or {}).get(c["id"], {}).get("bound_by_proof")) if accepted else False,
                "statement_sha256": (pb.statement_sha256 if pb else rec.get("statement_sha256")) if accepted else None,
                "bundle": {"manifest_sha256": a.manifest_sha256, "manifest_uri": a.manifest_uri,
                           "receipt_uris": len(a.receipt_uris)} if (a and accepted) else None,
                "anchor": {"chain": a.chain, "contract": a.contract, "leaf_hash": a.leaf_hash,
                           "resolve": f"post {post['id']} chunk {ch['index']} category {c['id']}"} if (a and accepted) else None,
                "content_commitment": content_commitment,
            })
    labels = {c: {"value": v["value"], "proof": v["proof"]} for c, v in (item.get("labels") or {}).items()}
    m = {"schema": SCHEMA, "item": {"post_id": post["id"], "kind": post["kind"], "created_at": post["created_at"],
                                    "content_commitment": content_commitment,
                                    "content_commitment_rule": "SHA-256(\"zk60/proven-media/content/v1\" || salt_32 || u64-be len || UTF-8 content)",
                                    "content_length_tokens": item.get("content_length")},
         "category_set": {"id": config.CATEGORY_SET_ID, "digest": records.category_set_digest()},
         "chunking": item.get("chunking"),
         "labels": labels,
         "label_rule": "per category: yes if any chunk is proved yes; not proved if any chunk lacks an accepted proof (fail closed); else no",
         "proved_once_at_creation": item.get("proved_at"),
         "entries": entries, "issued_at": records.now_iso(),
         "notes": (["DEMO STUB: one next-token proof per chunk stands in for that chunk's three category proofs; labels come "
                    "from a placeholder and are not bound by the proof."] if prover.get("kind") == "stub-next-token" else [])
                  + ([f"{failure}"] if failure else [])}
    return sign(m)


# ---------------------------------------------------------------- verify

def verify_manifest(m: dict, publisher, expected_public_key: str | None = None, rehash_segments: bool = False) -> dict:
    """signature, then each entry against the local ledger (anchor, Merkle path, publication manifest)"""
    reasons, checks = [], {}

    def chk(name, ok, why=""):
        checks[name] = bool(ok)
        if not ok:
            reasons.append(f"{name}: {why}" if why else name)

    chk("schema", m.get("schema") == SCHEMA, "not a zk60.manifest/1")
    iss, sig = m.get("issuer", {}), m.get("signature", {})
    pub = iss.get("public_key", "")
    if expected_public_key:
        chk("issuer_key", pub == expected_public_key, "signed by another key than the publisher's")
    try:
        Ed25519PublicKey.from_public_bytes(bytes.fromhex(pub)).verify(base64.b64decode(sig.get("value", "")), _body(m))
        chk("signature", True)
    except (InvalidSignature, ValueError):
        chk("signature", False, "the Ed25519 signature does not verify over the canonical manifest")
    pid = m.get("item", {}).get("post_id")
    pending = []
    for e in m.get("entries", []):
        c = e.get("category")
        tag = f"c{e.get('chunk', 0)}.{c}"
        if e.get("verdict") == records.UNPROVED:
            chk(f"{tag}.unproved_has_no_anchor", e.get("anchor") is None, "an unproved entry names an anchor")
            continue
        a = publisher.anchor_of(pid, c, e.get("chunk", 0))
        if a is None:
            chk(f"{tag}.anchor", False, "no anchor for this entry in the ledger")
            continue
        chk(f"{tag}.anchor_leaf", a.leaf_hash == (e.get("anchor") or {}).get("leaf_hash"), "the leaf differs from the ledger's")
        r = publisher.verify_publication(a, rehash_segments=rehash_segments)
        man = r.get("manifest") or {}
        same = (man.get("verdict") == e.get("verdict") and man.get("statement_sha256") == e.get("statement_sha256")
                and man.get("policy_id") == e.get("policy_sha256") and man.get("model_id") == e.get("model_id")
                and man.get("content_commitment") == e.get("content_commitment")
                and list(man.get("token_range", [])) == list(e.get("token_range", [])))
        chk(f"{tag}.publication_matches", same, "the published label, statement, policy, model or commitment differs")
        if r.get("pending"):
            pending.append(tag)
            checks[f"{tag}.anchored"] = False
        else:
            chk(f"{tag}.anchored", r.get("accepted"), "; ".join(r.get("reasons", [])))
    return {"accepted": not reasons, "pending_anchor": pending, "reasons": reasons, "checks": checks}
