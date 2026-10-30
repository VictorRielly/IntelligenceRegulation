"""Proof records, per-category LABELS, audiences, and the stub's (unproved) placeholder labels.

Operating model (D37, latest): proofs are CONTENT LABELS used for distribution. At creation each item
is classified once per category of a fixed, pre-registered list (Victor confirmed three: sexual /
explicit, graphic violence, hate / harassment), each a fixed Shieldstral policy text with one
threshold; every label is published with its proof whether the answer is yes or no; the app then
decides who receives the item from its proved labels (explicit content is not sent to minors).
Fail closed per category: a category without an accepted proof counts as the most restrictive label.

PUBLIC in a ProofRecord: the verifier-published statement and its SHA-256; the receipt (segments,
sizes, SHA-256s); per category the label (yes / no), its proof status and whether the proof binds
it (the stub: NO); the model identity; each category's policy text and SHA-256; the threshold; the
content length in tokens (pending Victor); timings, sizes, the security floor.
PRIVATE (never in a record, a bundle, a log line or a command line): the post's token ids, the
hidden activations, the owners' decommitments (D21), the stub's opened next token.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import config

RECORD_SCHEMA = "proven-media-record/2"
UNPROVED = "unproved"


# ---------------------------------------------------------------- the registered categories

class PolicyChanged(RuntimeError):
    pass


def category_policy(cat: dict) -> dict:
    """one category's registered policy; refuses a policy file that differs from its pin"""
    raw = cat["file"].read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    if sha != cat["sha256"]:
        raise PolicyChanged(f"{cat['file']} has sha256 {sha}, the registered {cat['policy_id']} is {cat['sha256']}; "
                            "a new policy is a new registered id, never an edit")
    return {"id": cat["policy_id"], "sha256": sha, "text": raw.decode(), "registered": True}


def categories() -> list[dict]:
    """the fixed category list with each policy verified against its pin (no file paths)"""
    out = []
    for c in config.registered_categories():
        out.append({"id": c["id"], "name": c["name"], "short": c["short"], "policy": category_policy(c)})
    return out


def category_ids() -> list[str]:
    return [c["id"] for c in config.registered_categories()]


def category_set_digest() -> str:
    """digest of the registered set: ids and policy digests, in order"""
    return hashlib.sha256(canonical([[c["id"], c["sha256"]] for c in config.registered_categories()])).hexdigest()


def content_key(text: str) -> str:
    """Legacy key, retained only for migration and old submission metadata."""
    return hashlib.sha256(f"pm-content-key-v2|{config.category_set_id()}|{config.TAU}|{text}".encode()).hexdigest()


def screening_context() -> str:
    """Immutable policy/threshold snapshot for one screening (D45)."""
    th = threshold()
    return canonical({'schema': 'proven-media-screening/1', 'policy_set': config.category_set_id(),
                      'policies': [{'category': c['id'], 'policy_id': c['policy']['id'],
                                    'sha256': c['policy']['sha256']} for c in categories()],
                      'threshold': {'tau': th['tau'], 'c': th['c']}}).decode()


def screening_key(kind: str, identity: str) -> str:
    """Private, keyed item identity independent of policy, threshold and author.

    Its reservation survives deletion; it contains neither the text nor an
    opening of the public content commitment.
    """
    import hmac
    return hmac.new(_app_key(), b'pm-screening-item-v1|' + canonical([kind, identity]), hashlib.sha256).hexdigest()


def threshold() -> dict:
    tau = config.TAU
    c = math.log(tau / (1 - tau))
    return {"tau": tau, "c": c,
            "rule": "label 'yes' iff z_yes - z_no > c, c = ln(tau / (1 - tau)) (z = the classifier's logits of "
                    "'yes' / 'no' at the first answer position, for that category's policy query); 'no' otherwise"}


# ---------------------------------------------------------------- placeholder labels (stub only)

# NOT the classifier and NOT proved. Whole-word matches of a few obvious terms per category, so the
# demo can show labels and audience filtering while the Shieldstral prover is being built.
PLACEHOLDER_TERMS = {
    "sexual": ("porn", "porno", "nude", "nudes", "naked", "xxx", "nsfw", "explicit sex", "sexting"),
    "violence": ("kill", "killed", "murder", "bomb", "shoot", "stab", "behead", "massacre", "gore", "bloodbath",
                 "hurt you", "explosive", "torture"),
    "hate": ("subhuman", "vermin", "i hate you", "worthless loser", "go back to your country", "kill yourself",
             "doxx", "doxxed"),
}
_PH_RE = {k: re.compile(r"\b(" + "|".join(re.escape(t) for t in v) + r")\b", re.IGNORECASE)
          for k, v in PLACEHOLDER_TERMS.items()}


def placeholder_labels(text: str) -> dict:
    return {c: ("yes" if _PH_RE.get(c) and _PH_RE[c].search(text or "") else "no") for c in category_ids()}


PLACEHOLDER_SOURCE = ("stub placeholder: a short keyword list per category in the app (NOT Shieldstral, NOT "
                      "proved); the classifier proofs will make each label the proof's public output")


# ---------------------------------------------------------------- labels -> distribution

def effective_labels(record: dict | None) -> dict:
    """per category: 'yes' / 'no' when an accepted proof exists, else 'unproved' (fail closed)"""
    out = {c: UNPROVED for c in category_ids()}
    for c, lab in ((record or {}).get("labels") or {}).items():
        if c in out and lab.get("proof") == "accepted" and lab.get("value") in ("yes", "no"):
            out[c] = lab["value"]
    return out


def aggregate_labels(chunk_records: list[dict | None], n_chunks: int, plan: list[dict] | None = None) -> dict:
    """D41: an item's label per category from its chunks' proofs: 'yes' if any chunk is proved yes;
    else 'unproved' if any chunk lacks an accepted proof (fail closed); else 'no'. Returns
    {category: {value, proof, bound_by_proof, chunks: [{index, value}]}}."""
    out = {}
    for c in category_ids():
        per = []
        for i in range(n_chunks):
            if plan is not None and plan[i].get('category', c) != c:
                continue
            rec = chunk_records[i] if i < len(chunk_records) else None
            per.append({"index": i, "value": effective_labels(rec)[c],
                        "bound_by_proof": bool(((rec or {}).get("labels") or {}).get(c, {}).get("bound_by_proof"))})
        vals = [x["value"] for x in per]
        v = "yes" if "yes" in vals else (UNPROVED if UNPROVED in vals or not vals else "no")
        out[c] = {"value": v, "proof": "accepted" if UNPROVED not in vals and vals else "none",
                  "bound_by_proof": bool(per) and all(x["bound_by_proof"] for x in per), "chunks": per}
    return out


def audience_of(name: str | None, hide: str | None = None) -> dict:
    """an audience profile: the categories a viewer must not receive unless proved 'no'"""
    a = config.AUDIENCES.get(name or "adult", config.AUDIENCES["adult"])
    restricted = list(a["restricted"])
    if a.get("custom"):
        for c in (hide or "").split(","):
            if c in category_ids() and c not in restricted:
                restricted.append(c)
    return {"id": name if name in config.AUDIENCES else "adult", "name": a["name"], "restricted": restricted}


def visibility(eff: dict, audience: dict) -> tuple[bool, list[dict]]:
    """visible iff every restricted category is proved 'no'; an unproved category counts as 'yes'"""
    names = {c["id"]: c["short"] for c in config.CATEGORIES}
    reasons = []
    for c in audience["restricted"]:
        v = eff.get(c, UNPROVED)
        if v != "no":
            reasons.append({"category": c, "label": names.get(c, c), "value": v,
                            "why": "proved yes" if v == "yes" else "not proved (counts as the most restrictive label)"})
    return (not reasons), reasons


# ---------------------------------------------------------------- records

@dataclass
class Verdict:
    """the result of a (re-)check of a stored proof"""
    value: str
    proof_valid: bool
    bound_by_proof: bool
    source: str
    checked_at: str = ""
    details: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ProofRecord:
    post_id: str
    item_kind: str
    prover: dict
    labels: dict                       # category -> {value, proof, bound_by_proof, source, policy_id, policy_sha256}
    policies: list                     # the registered category policies (id, sha256, text)
    threshold: dict
    content_commitment: dict
    statement: dict | None
    statement_sha256: str | None
    receipt: dict
    timings: dict
    security: dict
    checks: dict
    content_length: dict = field(default_factory=dict)
    chunk: dict = field(default_factory=dict)  # D41: {index, start, end} in content tokens
    proved_at: str = ""                # each item is proved ONCE, at creation (D37)
    created_at: str = ""
    schema: str = RECORD_SCHEMA
    notes: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict) -> "ProofRecord":
        keys = ProofRecord.__dataclass_fields__.keys()
        return ProofRecord(**{k: d[k] for k in keys if k in d})


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def canonical(obj) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blk in iter(lambda: f.read(1 << 22), b""):
            h.update(blk)
    return h.hexdigest()


# ---------------------------------------------------------------- per-post salt (report §5)

def _app_key() -> bytes:
    """32-byte local key (0600, private root) that encrypts the per-post salts at rest"""
    import os
    import secrets

    p = config.PRIVATE_DIR / "app.key"
    if not p.exists():
        p.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        try:
            fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as f:
                f.write(secrets.token_bytes(32))
        except FileExistsError:
            pass
    return p.read_bytes()


def _salt_pad(post_id: str) -> bytes:
    import hmac

    return hmac.new(_app_key(), b"pm-salt-v1|" + post_id.encode(), hashlib.sha256).digest()


def new_salt_enc(post_id: str) -> str:
    """a fresh 256-bit salt for the post's content commitment, encrypted at rest (XOR with a
    per-post HMAC pad under the app key); deleting it crypto-shreds the public commitment"""
    import secrets

    salt = secrets.token_bytes(32)
    return bytes(a ^ b for a, b in zip(salt, _salt_pad(post_id))).hex()


def salt_of(post_id: str, salt_enc_hex: str | None) -> bytes | None:
    if not salt_enc_hex:
        return None
    return bytes(a ^ b for a, b in zip(bytes.fromhex(salt_enc_hex), _salt_pad(post_id)))
