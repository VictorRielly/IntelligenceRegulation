#!/usr/bin/env python3
"""ZK60 zkVM contract probe: the fixed public journal and its domain binding.

Executable companion to docs/zkmatrix-poc/ZK60_ZKVM_CONSTRUCTION_REVIEW.md.
It fixes, byte for byte, the PROPOSED public statement of a private
T32/d16/f16 block proven by exact re-execution in a general-purpose zkVM:

  * the 260-byte journal (the only application data a verifier sees),
  * the salted endpoint commitments carried by that journal,
  * the public weight / calibration / context digests, and
  * the verifier's receipt-envelope admission rule.

This is a serialization and domain-separation contract with test vectors for a
Rust guest to reproduce. It proves nothing: it runs no zkVM, verifies no
receipt and asserts no cryptographic theorem. The profile is NEW and is not
compatible with the hashline PCS endpoint roots or PCS weight roots.
Standard library only.
"""
import hashlib
import hmac
import json
import struct
import sys

# Fixed profile (ZK60_BLOCK_CONTRACT.md "Deliberately narrow supported profile").
T, D, F, HEADS, KV_HEADS, HEAD_DIM = 32, 16, 16, 2, 1, 8
LAYERS = 32
MODE_P1 = 1
ENDPOINT_BITS = 16
DIGEST_LEN = 32
SALT_LEN = 32
MAX_CONTEXT_LEN = 4096
MAX_CALIBRATION_LEN = 1 << 20


def _tag(text):
    raw = text.encode("ascii")
    if not 0 < len(raw) <= 32:
        raise ValueError("domain tag must be 1..=32 ASCII bytes")
    return raw.ljust(32, b"\0")


JOURNAL_TAG = _tag("ZK60/zkvm-p1-block/journal/v1")
ENDPOINT_TAG = _tag("ZK60/zkvm-p1-block/endpoint/v1")
WEIGHTS_TAG = _tag("ZK60/zkvm-p1-block/weights/v1")
CALIBRATION_TAG = _tag("ZK60/zkvm-p1-block/calib/v1")
CONTEXT_TAG = _tag("ZK60/zkvm-p1-block/context/v1")
ALL_TAGS = (JOURNAL_TAG, ENDPOINT_TAG, WEIGHTS_TAG, CALIBRATION_TAG, CONTEXT_TAG)

JOURNAL_LEN = 32 + 6 * 4 + 3 * 4 + 6 * DIGEST_LEN  # 260
ENDPOINT_PREIMAGE_LEN = 32 + 3 * DIGEST_LEN + 4 * 4 + SALT_LEN + 2 * T * D  # 1200

# Public weight inventory: (tensor id, name, rows, cols); every word is int8
# (private_block_contract.rs: "all committed weight and gamma words are int8").
# Row-major, rows = input width, cols = output width; the kernel lane maps its
# own layout to this order and must not reorder or merge tensors.
WEIGHT_INVENTORY = (
    (1, "attn_wq", D, HEADS * HEAD_DIM),
    (2, "attn_wk", D, KV_HEADS * HEAD_DIM),
    (3, "attn_wv", D, KV_HEADS * HEAD_DIM),
    (4, "attn_wo", HEADS * HEAD_DIM, D),
    (5, "attn_norm_gamma", 1, D),
    (6, "ffn_norm_gamma", 1, D),
    (7, "ffn_wg", D, F),
    (8, "ffn_wu", D, F),
    (9, "ffn_wd", F, D),
)

# Receipt kinds a verifier may meet. Only a kind listed as admissible may be a
# PUBLIC artifact; see the review for why composite is excluded.
RECEIPT_KINDS = ("composite", "succinct", "groth16", "fake")
DEV_MODE_ENV = "RISC0_DEV_MODE"


class ContractError(ValueError):
    """A refusal. Messages name a field category, never a supplied value."""


def _digest(value, what):
    if type(value) is not bytes or len(value) != DIGEST_LEN:
        raise ContractError(f"{what}: expected {DIGEST_LEN} bytes")
    return value


def _u32(value, what, upper):
    if type(value) is not int or not 0 <= value <= upper:
        raise ContractError(f"{what}: out of range")
    return struct.pack("<I", value)


def _framed(tag, blob, what, limit):
    if type(blob) is not bytes or len(blob) > limit:
        raise ContractError(f"{what}: expected at most {limit} bytes")
    return hashlib.sha256(tag + struct.pack("<I", len(blob)) + blob).digest()


def context_digest(caller_context):
    return _framed(CONTEXT_TAG, caller_context, "context", MAX_CONTEXT_LEN)


def calibration_digest(calibration_blob):
    """Digest of the kernel lane's canonical fixed calibration/table bytes."""
    return _framed(CALIBRATION_TAG, calibration_blob, "calibration", MAX_CALIBRATION_LEN)


def weights_digest(layer_index, tensors):
    """tensors: exact WEIGHT_INVENTORY order, each (tensor_id, rows, cols, bytes)."""
    if type(tensors) not in (list, tuple) or len(tensors) != len(WEIGHT_INVENTORY):
        raise ContractError("weights: tensor count")
    h = hashlib.sha256(WEIGHTS_TAG)
    h.update(_u32(layer_index, "layer", LAYERS - 1))
    for supplied, (tensor_id, _name, rows, cols) in zip(tensors, WEIGHT_INVENTORY):
        if type(supplied) not in (list, tuple) or len(supplied) != 4:
            raise ContractError("weights: tensor entry")
        got_id, got_rows, got_cols, data = supplied
        if (got_id, got_rows, got_cols) != (tensor_id, rows, cols):
            raise ContractError("weights: tensor identity or shape")
        if type(data) is not bytes or len(data) != rows * cols:
            raise ContractError("weights: tensor bytes")
        h.update(struct.pack("<III", tensor_id, rows, cols))
        h.update(data)
    return h.digest()


def endpoint_preimage(context, model, calibration, boundary_index, salt, values):
    """The exact bytes hashed for one endpoint; boundary l is the input of layer l
    and the output of layer l - 1, so one commitment can serve both blocks."""
    if type(salt) is not bytes or len(salt) != SALT_LEN:
        raise ContractError(f"salt: expected {SALT_LEN} bytes")
    if type(values) not in (list, tuple) or len(values) != T * D:
        raise ContractError("endpoint: value count")
    for value in values:
        if type(value) is not int or not -32768 <= value <= 32767:
            raise ContractError("endpoint: value class")
    out = b"".join((
        ENDPOINT_TAG,
        _digest(context, "context"),
        _digest(model, "model"),
        _digest(calibration, "calibration"),
        _u32(boundary_index, "boundary", LAYERS),
        struct.pack("<III", T, D, ENDPOINT_BITS),
        salt,
        struct.pack(f"<{T * D}h", *values),
    ))
    assert len(out) == ENDPOINT_PREIMAGE_LEN
    return out


def endpoint_commitment(context, model, calibration, boundary_index, salt, values):
    return hashlib.sha256(
        endpoint_preimage(context, model, calibration, boundary_index, salt, values)
    ).digest()


def encode_journal(context, model, weights, calibration, layer_index,
                   input_commitment, output_commitment):
    out = b"".join((
        JOURNAL_TAG,
        struct.pack("<6I", T, D, F, HEADS, KV_HEADS, HEAD_DIM),
        _u32(layer_index, "layer", LAYERS - 1),
        struct.pack("<II", MODE_P1, 0),
        _digest(context, "context"),
        _digest(model, "model"),
        _digest(weights, "weights"),
        _digest(calibration, "calibration"),
        _digest(input_commitment, "input commitment"),
        _digest(output_commitment, "output commitment"),
    ))
    assert len(out) == JOURNAL_LEN
    return out


def decode_journal(journal):
    """Strict diagnostic parser. Acceptance uses verify_journal, not this."""
    if type(journal) is not bytes or len(journal) != JOURNAL_LEN:
        raise ContractError("journal: length")
    if journal[:32] != JOURNAL_TAG:
        raise ContractError("journal: tag")
    words = struct.unpack_from("<9I", journal, 32)
    if words[:6] != (T, D, F, HEADS, KV_HEADS, HEAD_DIM):
        raise ContractError("journal: profile")
    if words[6] >= LAYERS:
        raise ContractError("journal: layer")
    if words[7] != MODE_P1:
        raise ContractError("journal: privacy mode")
    if words[8] != 0:
        raise ContractError("journal: reserved word")
    names = ("context", "model", "weights", "calibration",
             "input_commitment", "output_commitment")
    fields = {name: journal[68 + 32 * i:100 + 32 * i] for i, name in enumerate(names)}
    fields["layer_index"] = words[6]
    return fields


def verify_journal(journal, *, context, model, weights, calibration, layer_index,
                   input_commitment, output_commitment):
    """Rebuild the whole journal from the verifier's OWN values and compare bytes.

    Nothing is copied out of the candidate: every argument must come from the
    verifier's approved registry or from the caller's independently fixed
    endpoints. Raises ContractError on any difference.
    """
    expected = encode_journal(context, model, weights, calibration, layer_index,
                              input_commitment, output_commitment)
    if type(journal) is not bytes or not hmac.compare_digest(journal, expected):
        raise ContractError("journal: does not equal the expected statement")


def admit_public_receipt(kind, *, exit_code, assumption_count, verifier_env,
                         allow_vendor_zk_succinct=False):
    """Envelope rule applied BEFORE cryptographic verification.

    Groth16 is the only kind admitted by default. Succinct needs an explicit
    opt-in that records reliance on the vendor's unreviewed STARK-level hiding.
    Composite (per-segment machine state) and fake (dev mode) never pass.
    """
    if kind not in RECEIPT_KINDS:
        raise ContractError("receipt: unknown kind")
    if DEV_MODE_ENV in verifier_env:
        raise ContractError("receipt: dev-mode variable present in verifier environment")
    if kind == "fake" or kind == "composite":
        raise ContractError("receipt: kind is not a public artifact")
    if kind == "succinct" and allow_vendor_zk_succinct is not True:
        raise ContractError("receipt: succinct needs the explicit vendor-ZK opt-in")
    if exit_code != ("halted", 0):
        raise ContractError("receipt: exit code")
    if type(assumption_count) is not int or assumption_count != 0:
        raise ContractError("receipt: unresolved assumptions")


def fixture():
    """Deterministic SERIALIZATION vector. The 'output' is not a block result,
    and these public salts must never be used for a real endpoint."""
    context = context_digest(b"zk60-zkvm-probe/request/0001")
    model = hashlib.sha256(b"zk60-zkvm-probe/model-artifact").digest()
    calibration = calibration_digest(b"zk60-zkvm-probe/calibration-blob")
    tensors = [(tid, rows, cols, bytes((tid * 7 + i) % 256 for i in range(rows * cols)))
               for tid, _name, rows, cols in WEIGHT_INVENTORY]
    layer = 0
    weights = weights_digest(layer, tensors)
    x = [(i * 37) % 201 - 100 for i in range(T * D)]
    y = [(i * 53) % 151 - 75 for i in range(T * D)]
    salt_in = hashlib.sha256(b"zk60-zkvm-probe/PUBLIC-TEST-salt-in").digest()
    salt_out = hashlib.sha256(b"zk60-zkvm-probe/PUBLIC-TEST-salt-out").digest()
    c_in = endpoint_commitment(context, model, calibration, layer, salt_in, x)
    c_out = endpoint_commitment(context, model, calibration, layer + 1, salt_out, y)
    journal = encode_journal(context, model, weights, calibration, layer, c_in, c_out)
    return {
        "context": context, "model": model, "calibration": calibration,
        "weights": weights, "layer_index": layer, "tensors": tensors,
        "x": x, "y": y, "salt_in": salt_in, "salt_out": salt_out,
        "input_commitment": c_in, "output_commitment": c_out, "journal": journal,
    }


def main():
    fx = fixture()
    verify_journal(fx["journal"], **{k: fx[k] for k in (
        "context", "model", "weights", "calibration", "layer_index",
        "input_commitment", "output_commitment")})
    report = {
        "profile": "ZK60/zkvm-p1-block/v1 (proposed; not PCS-root compatible)",
        "journal_len": len(fx["journal"]),
        "endpoint_preimage_len": ENDPOINT_PREIMAGE_LEN,
        "journal_sha256": hashlib.sha256(fx["journal"]).hexdigest(),
        "journal_hex": fx["journal"].hex(),
        "weights_digest": fx["weights"].hex(),
        "input_commitment": fx["input_commitment"].hex(),
        "output_commitment": fx["output_commitment"].hex(),
        "claims": "serialization vector only; no zkVM run, no receipt verified",
    }
    json.dump(report, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
