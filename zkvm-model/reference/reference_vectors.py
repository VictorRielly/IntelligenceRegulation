#!/usr/bin/env python3
"""Independent hashlib reference for the zk60-r0-token-v1 framing.

This is NOT a verifier and makes no cryptographic acceptance claim. It
recomputes the documented byte layouts without sharing code with the Rust
crates:

  vectors                               print the fixed test vectors asserted in
                                        statement/src/lib.rs
  check MODEL REQUEST OUTPUT_U32 POLICY recompute a prepared policy from LOCAL
                                        PRIVATE files (owner side only; prints no
                                        token, salt or endpoint opening)

`check` trusts the claimed output token; it does not run the model.
"""
import hashlib
import struct
import sys

PROFILE = b"zk60-r0-token-v1"
MODEL_DOMAIN = b"zk60-r0-token-model-v1\0"
ENDPOINT_DOMAIN = b"zk60-r0-token-endpoint-v1\0"
MODEL_MAGIC = b"Z60TOK01"
BLOCK_MAGIC = b"Z60MDL01"
BLOCK_BYTES = 8 + 1568 + (128 + 128 + 256) * 8 + 256 * 2
MODEL_BYTES = 8 + 512 * 2 + 2 * BLOCK_BYTES + 16 + 512
REQUEST_BYTES = 16 + 3 * 32 + 32 * 4
JOURNAL_BYTES = 16 + 4 * 32
VOCAB = 32


def model_digest(payload):
    return hashlib.sha256(
        MODEL_DOMAIN + PROFILE + struct.pack("<Q", len(payload)) + payload
    ).digest()


def endpoint(role, context, model, salt, tokens):
    assert len(tokens) == (32, 1)[role]
    assert len(context) == len(model) == len(salt) == 32
    return hashlib.sha256(
        ENDPOINT_DOMAIN + PROFILE + bytes([role]) + context + model + salt
        + struct.pack("<I", len(tokens)) + b"".join(struct.pack("<I", t) for t in tokens)
    ).digest()


def vectors():
    tokens = [(i * 7 + 3) % 32 for i in range(32)]
    print("input ", endpoint(0, b"\x01" * 32, b"\x02" * 32, b"\x03" * 32, tokens).hex())
    print("output", endpoint(1, b"\x01" * 32, b"\x02" * 32, b"\x04" * 32, [0x01020311]).hex())
    print("model ", model_digest(bytes(i % 251 for i in range(1000))).hex())


def check(model_path, request_path, output_path, policy_path):
    model = open(model_path, "rb").read()
    request = open(request_path, "rb").read()
    output = open(output_path, "rb").read()
    policy = open(policy_path, "rb").read()
    assert (BLOCK_BYTES, MODEL_BYTES, REQUEST_BYTES, JOURNAL_BYTES) == (6184, 13928, 240, 144)
    assert len(model) == MODEL_BYTES and model[:8] == MODEL_MAGIC, "model framing"
    for at in (8 + 1024, 8 + 1024 + BLOCK_BYTES):
        assert model[at:at + 8] == BLOCK_MAGIC, "block framing"
    assert len(request) == REQUEST_BYTES and request[:16] == PROFILE, "request framing"
    assert len(output) == 4, "output framing"
    assert len(policy) == JOURNAL_BYTES and policy[:16] == PROFILE, "policy framing"
    context, in_salt, out_salt = request[16:48], request[48:80], request[80:112]
    tokens = list(struct.unpack("<32I", request[112:]))
    (token,) = struct.unpack("<I", output)
    assert all(t < VOCAB for t in tokens) and token < VOCAB, "token range"
    assert in_salt != out_salt, "salts must be independent"
    digest = model_digest(model)
    expected = (PROFILE + context + digest
                + endpoint(0, context, digest, in_salt, tokens)
                + endpoint(1, context, digest, out_salt, [token]))
    assert expected == policy, "policy differs from independent framing"
    print('{"framing_matches_policy":true,"model_executed":false}')


if __name__ == "__main__":
    if sys.argv[1:] == ["vectors"]:
        vectors()
    elif len(sys.argv) == 6 and sys.argv[1] == "check":
        check(*sys.argv[2:])
    else:
        sys.exit(__doc__)
