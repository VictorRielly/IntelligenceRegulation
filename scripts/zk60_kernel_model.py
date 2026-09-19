#!/usr/bin/env python3
"""Convert a public synthetic kernel fixture to the fixed zkVM model encoding.

This utility does not register/approve a model. It refuses malformed or refused
fixtures, and outputs PUBLIC weights/tables only, never fixture activations.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct

LAYOUT = (
    ("wq", 256, "b"), ("wk", 128, "b"), ("wv", 128, "b"),
    ("wo", 256, "b"), ("gamma_a", 16, "b"), ("gamma_m", 16, "b"),
    ("wg_t", 256, "b"), ("wu_t", 256, "b"), ("wd_t", 256, "b"),
    ("rope_cos", 128, "q"), ("rope_sin", 128, "q"),
    ("exp", 256, "q"), ("act", 256, "h"),
)
PROFILE = b"zk60-r0-block-v1"
MODEL_BYTES = 6184
MAX_FIXTURE = 1024 * 1024


def convert(data: bytes) -> bytes:
    if len(data) > MAX_FIXTURE:
        raise ValueError("fixture exceeds size limit")
    lines = data.decode("ascii").splitlines()
    if not lines or lines[0] != "zk60-kernel-fixture v1" or lines[-1] != "end":
        raise ValueError("wrong fixture framing")
    tensors = {}
    seen = set()
    needed = {name: size for name, size, _ in LAYOUT}
    statuses = []
    for line in lines[1:-1]:
        words = line.split()
        if not words:
            raise ValueError("empty fixture record")
        if words[0] == "status":
            statuses.append(words[1:])
        elif words[0] == "tensor":
            if len(words) < 3 or words[1] in seen:
                raise ValueError("malformed or duplicated tensor")
            _, name, count, *values = words
            seen.add(name)
            if int(count) != len(values):
                raise ValueError("tensor count mismatch")
            if name in needed:
                if len(values) != needed[name]:
                    raise ValueError("public tensor shape mismatch")
                tensors[name] = [int(v) for v in values]
        elif words[0] != "meta":
            raise ValueError("unexpected fixture record")
    if statuses != [["ok"]] or set(tensors) != set(needed):
        raise ValueError("requires one successful fixture and all public tensors")
    model = bytearray(b"Z60MDL01")
    try:
        for name, count, kind in LAYOUT:
            model += struct.pack("<" + str(count) + kind, *tensors[name])
    except struct.error as exc:
        raise ValueError("public tensor word outside its encoded range") from exc
    if len(model) != MODEL_BYTES:
        raise ValueError("internal model layout mismatch")
    return bytes(model)


def model_digest(model: bytes) -> str:
    return hashlib.sha256(b"zk60-r0-block-model-v1\0" + PROFILE +
                          struct.pack("<Q", len(model)) + model).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.fixture.open("rb") as source:
        model = convert(source.read(MAX_FIXTURE + 1))
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    with os.fdopen(fd, "wb") as output:
        output.write(model)
        output.flush()
        os.fsync(output.fileno())
    print(json.dumps({"public_synthetic_model": True, "bytes": len(model),
                      "model_digest": model_digest(model), "model_approved": False}))


if __name__ == "__main__":
    main()
