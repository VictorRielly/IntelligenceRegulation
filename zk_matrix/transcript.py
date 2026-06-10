"""Fiat-Shamir transcript helpers."""

from __future__ import annotations

from dataclasses import is_dataclass, fields
from hashlib import sha256
from typing import Any


def _absorb(value: Any, out: bytearray) -> None:
    if value is None:
        out.extend(b"N;")
    elif isinstance(value, bool):
        out.extend(b"B1;" if value else b"B0;")
    elif isinstance(value, int):
        data = value.to_bytes(max(1, (value.bit_length() + 7) // 8), "big")
        out.extend(b"I")
        out.extend(len(data).to_bytes(4, "big"))
        out.extend(data)
    elif isinstance(value, bytes):
        out.extend(b"Y")
        out.extend(len(value).to_bytes(4, "big"))
        out.extend(value)
    elif isinstance(value, str):
        encoded = value.encode("utf-8")
        out.extend(b"S")
        out.extend(len(encoded).to_bytes(4, "big"))
        out.extend(encoded)
    elif is_dataclass(value):
        out.extend(b"D")
        out.extend(type(value).__name__.encode("utf-8"))
        out.extend(b"{")
        for item in fields(value):
            _absorb(item.name, out)
            _absorb(getattr(value, item.name), out)
        out.extend(b"}")
    elif isinstance(value, (list, tuple)):
        out.extend(b"L")
        out.extend(len(value).to_bytes(4, "big"))
        for item in value:
            _absorb(item, out)
    else:
        raise TypeError(f"cannot absorb {type(value)!r} into transcript")


def transcript_bytes(*items: Any) -> bytes:
    out = bytearray()
    for item in items:
        _absorb(item, out)
    return bytes(out)


def challenge_scalar(q: int, domain: str, *items: Any) -> int:
    """Hash transcript items to a non-zero scalar modulo ``q``."""

    payload = transcript_bytes(domain, *items)
    counter = 0
    while True:
        digest = sha256(payload + counter.to_bytes(4, "big")).digest()
        value = int.from_bytes(digest, "big") % q
        if value:
            return value
        counter += 1
