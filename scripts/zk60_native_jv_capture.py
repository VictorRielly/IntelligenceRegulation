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


class ManifestRefusal(Exception):
    """The manifest cross-check could not be made, and says so BY NAME.

    [ROUND 9e, 2026-09-22]  Until this date `manifest_check` returned
    `{"validation_json": "absent"}` whenever the file it looked for was not
    at the one name it knew, and both gates then ran to the end and passed
    with their manifest cross-check SKIPPED and nothing saying so (round 9d
    found it on a delivered bundle: `ZK60_NATIVE_D22_REPIN_4751B93.md` §8.5
    observation 1).  The other three ways of failing were no better: a
    single `accepted` record, an unparsable file and an `accepted` that is
    neither raised `TypeError`/`JSONDecodeError` from inside a dict literal,
    naming neither the directory nor the file.

    A cross-check that cannot be made is now a refusal that names the
    directory, the file and the reason.  The ONE way to proceed without a
    manifest is for the caller to say so explicitly
    (`no_validation_file=True`), which is recorded in the record.
    """


# The names a capture directory's manifest is accepted under.  `validation.json`
# is this lane's own name (`results/zk60_native_captures_20260919/`);
# `capture-validation.json` is the name the integrator's capture runner writes,
# the one round 9d had to shim around.  A directory carrying both is read at the
# first name in this order.
MANIFEST_NAMES = ("validation.json", "capture-validation.json")


def _accepted_records(path: str, man):
    """The manifest's `accepted` as a list of records, in EITHER shape.

    A list (this lane's writer, one entry per capture) or a single record
    (the integrator's runner, which stores what one `check_bundle` call
    returns).  Anything else is a refusal.
    """
    acc = man.get("accepted")
    if isinstance(acc, list):
        records = acc
    elif isinstance(acc, dict):
        records = [acc]
    else:
        raise ManifestRefusal(
            f"{path}: `accepted` is {type(acc).__name__}, which is neither a "
            "list of per-capture records nor a single record; the manifest "
            "cross-check cannot be made and this gate will not pass without it"
        )
    for i, rec in enumerate(records):
        if not isinstance(rec, dict) or "proof_sha256" not in rec:
            raise ManifestRefusal(
                f"{path}: `accepted`[{i}] is not a record carrying "
                "`proof_sha256`; the manifest cross-check cannot be made"
            )
    return records


def manifest_check(directory: str, caps, *, no_validation_file: bool = False):
    """Cross-check the retained manifest's artifact hashes for the JSON bundles.

    Refuses by name (`ManifestRefusal`) when the manifest is absent, cannot be
    read, carries no usable `accepted`, or disagrees with the bundle on disk.
    `no_validation_file=True` is the caller declaring, on the record, that this
    directory has no manifest at all; then and only then the check is skipped,
    and the record says who declared it.
    """
    path = None
    for name in MANIFEST_NAMES:
        candidate = os.path.join(directory, name)
        if os.path.exists(candidate):
            path = candidate
            break
    if path is None:
        if no_validation_file:
            return {
                "validation_json": "absent",
                "declared_absent_by_the_caller": True,
                "names_looked_for": list(MANIFEST_NAMES),
            }
        raise ManifestRefusal(
            f"{directory}: no validation file "
            f"({', '.join(MANIFEST_NAMES)}); the manifest cross-check cannot "
            "be made.  Deliver the manifest, or declare its absence "
            "explicitly (`--no-validation-file`), which is recorded"
        )
    if no_validation_file:
        raise ManifestRefusal(
            f"{path}: the caller declared this directory has no validation "
            "file, and it has one; withdraw the declaration or name the "
            "directory that has none"
        )
    try:
        with open(path) as fh:
            man = json.load(fh)
    except (OSError, ValueError) as exc:
        raise ManifestRefusal(
            f"{path}: the validation file cannot be read "
            f"({type(exc).__name__}: {exc}); the manifest cross-check cannot "
            "be made and this gate will not pass without it"
        ) from exc
    if not isinstance(man, dict):
        raise ManifestRefusal(
            f"{path}: the validation file is {type(man).__name__}, not an "
            "object; the manifest cross-check cannot be made"
        )
    out = {"validation_json": "present", "checked": 0, "mismatch": []}
    for cap in caps:
        key = "captures/" + os.path.basename(cap.path)
        rec = man.get("artifacts", {}).get(key)
        if not isinstance(rec, dict):
            out["mismatch"].append(f"{key}: not in the manifest")
            continue
        out["checked"] += 1
        if rec.get("sha256") != cap.sha256 or rec.get("bytes") != cap.bytes:
            out["mismatch"].append(f"{key}: manifest hash/size differs from the file on disk")
    accepted = {a["proof_sha256"]: a for a in _accepted_records(path, man)}
    for cap in caps:
        a = accepted.get(cap.proof_sha256)
        if a is None:
            out["mismatch"].append(f"{cap.proof_sha256[:16]}: not in the accepted list")
        elif not (a.get("canonical_capture_reproduced") and a.get("native_reverified")):
            out["mismatch"].append(f"{cap.proof_sha256[:16]}: not reproduced/re-verified")
    if out["mismatch"]:
        raise ManifestRefusal(
            f"{path}: the manifest disagrees with the bundle on disk: "
            + "; ".join(out["mismatch"])
        )
    out["privacy_review_complete"] = man.get("privacy_review_complete")
    out["source_commit"] = man.get("source_commit")
    out["verifier_binary_sha256"] = man.get("verifier_binary_sha256")
    return out
