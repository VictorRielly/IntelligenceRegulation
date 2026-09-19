"""Reader for the schema-3 native verifier-observation captures.

Format: docs/zkmatrix-poc/ZK60_NATIVE_CAPTURE.md, writer
hashline/src/native_capture.rs (kind `zk60-verifier-observations`,
coverage `native-all-slots-v1`).  Nothing here re-derives a witness or a
receipt; it only reads the JSON the pinned verifier published.

The capture files contain private material of SYNTHETIC public fixtures
(salts, pads, sampled columns).  Nothing in this module prints their
contents; callers report digests, sizes, ranks and counts only.
"""

from __future__ import annotations

import hashlib
import json
import os

PROFILE_BLOCK = "hashline-zk-mr1/private-block-t32-poc/1"
PROFILE_ATTENTION = "hashline-zk-mr1/private-attention-t32-poc/1"

# protocol.rs / private_attention/protocol.rs, absorbed under b"parameters"
PARAMETERS = {
    PROFILE_BLOCK: (
        b"T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/"
        b"sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript"
    ),
    PROFILE_ATTENTION: b"T32/d16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/two-private-endpoints",
}
# private_block.rs::calibration_identity(); the attention profile absorbs no calibration
CALIBRATION_PREIMAGE = {PROFILE_BLOCK: b"B3 public fixed calibration v1", PROFILE_ATTENTION: None}
# private_block.rs / private_attention.rs slot labels
LABELS = {
    PROFILE_BLOCK: (b"pb-slot", b"pb-scalar", b"pb-term"),
    PROFILE_ATTENTION: (b"pa-slot", b"pa-scalar", b"pa-term"),
}
ROLE_ORDER = ["A", "H", "Input", "Output"]
LOG_COLS = 8
N_COLS = 1 << LOG_COLS
INV_RATE = 8
ENC_COLS = N_COLS * INV_RATE  # 2048
NUM_COL_CHECKS = 256
Q_PAD = 256
MASK_LOG_MSG = 9  # 512 message positions per a-row
MASK_LOG_DOM = 12  # 4096 evaluation positions
MASK_Q = 256  # opened columns == pads per a-row


class Capture:
    def __init__(self, path: str):
        self.path = path
        with open(path, "rb") as fh:
            raw = fh.read()
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.bytes = len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != 3 or d.get("kind") != "zk60-verifier-observations":
            raise ValueError(f"{path}: not a schema-3 verifier-observation capture")
        if d.get("coverage") != "native-all-slots-v1":
            raise ValueError(f"{path}: unexpected coverage {d.get('coverage')!r}")
        self.profile = d["profile"]
        if self.profile not in PARAMETERS:
            raise ValueError(f"{path}: unknown profile {self.profile!r}")
        if d["profile"] != d["transcript_domain"]:
            raise ValueError(f"{path}: transcript domain differs from the profile")

    # ------------------------------------------------------------ accessors
    @property
    def name(self) -> str:
        return os.path.basename(self.path)[:16]

    @property
    def kind(self) -> str:
        return "block" if self.profile == PROFILE_BLOCK else "attention"

    @property
    def proof_sha256(self) -> str:
        return self.doc["proof_sha256"]

    @property
    def slots(self):
        return self.doc["arguments"]

    @property
    def mask(self):
        return self.doc["mask"]

    def role(self, name: str):
        for r in self.doc["roles"]:
            if r["role"] == name:
                return r
        raise KeyError(name)

    @property
    def roles(self):
        return self.doc["roles"]

    def a_root(self):
        return bytes(self.role("A")["commitment"]["root"])

    def h_root(self):
        return bytes(self.role("H")["commitment"]["root"])

    def endpoint_root(self, which: str):
        return bytes(self.role(which)["commitment"]["root"])


def load_all(directory: str):
    """Every capture bundle in a capture directory, block profiles first."""
    caps = []
    capdir = os.path.join(directory, "captures")
    if not os.path.isdir(capdir):
        capdir = directory
    for fn in sorted(os.listdir(capdir)):
        if fn.endswith(".json"):
            caps.append(Capture(os.path.join(capdir, fn)))
    caps.sort(key=lambda c: (c.kind != "block", c.proof_sha256))
    return caps


def manifest_check(directory: str, caps):
    """Cross-check the retained manifest's artifact hashes for the JSON bundles."""
    path = os.path.join(directory, "validation.json")
    if not os.path.exists(path):
        return {"validation_json": "absent"}
    with open(path) as fh:
        man = json.load(fh)
    out = {"validation_json": "present", "checked": 0, "mismatch": []}
    for cap in caps:
        key = "captures/" + os.path.basename(cap.path)
        rec = man.get("artifacts", {}).get(key)
        if rec is None:
            out["mismatch"].append(f"{key}: not in the manifest")
            continue
        out["checked"] += 1
        if rec["sha256"] != cap.sha256 or rec["bytes"] != cap.bytes:
            out["mismatch"].append(f"{key}: manifest hash/size differs from the file on disk")
    accepted = {a["proof_sha256"]: a for a in man.get("accepted", [])}
    for cap in caps:
        a = accepted.get(cap.proof_sha256)
        if a is None:
            out["mismatch"].append(f"{cap.proof_sha256[:16]}: not in the accepted list")
        elif not (a["canonical_capture_reproduced"] and a["native_reverified"]):
            out["mismatch"].append(f"{cap.proof_sha256[:16]}: not reproduced/re-verified")
    out["privacy_review_complete"] = man.get("privacy_review_complete")
    out["source_commit"] = man.get("source_commit")
    out["verifier_binary_sha256"] = man.get("verifier_binary_sha256")
    return out
