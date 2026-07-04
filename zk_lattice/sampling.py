"""Sampling and Fiat-Shamir transcript helpers for the lattice protocols.

Conventions from Part II, Section 12 of the report:

* ``H`` is SHAKE-256 used as an extendable-output function; every call takes
  an explicit ASCII domain-separation tag as its first argument.
* Mod-q elements travel in canonical representatives in ``[0, q)``; short
  vectors travel as signed integers. Fixing one representative convention
  is item 6 of the implementation-security checklist.
* Challenge coefficients come from ``S_b = {0, ..., 2^b - 1}`` read as
  b-bit chunks of XOF output (no modulo bias for power-of-two widths).
* The rejection-sampling accept decision (Lemma 6.3) is evaluated in
  ``decimal`` fixed point with >= 128 fractional bits; double precision
  silently biases the output (known implementation trap, Section 12).
"""

from __future__ import annotations

import secrets
from decimal import Decimal, getcontext
from hashlib import shake_256
from typing import Iterable, List, Sequence

# 60 decimal digits is just under 200 bits, above the report's 128-bit floor.
_REJECTION_PRECISION_DIGITS = 60

# Rejection-sampling constants of Lemma 6.3 with alpha = 12:
# M = exp(12/alpha + 1/(2 alpha^2)) = exp(1 + 1/288).
REJECTION_ALPHA = 12


def _absorb_int(value: int, out: bytearray) -> None:
    if value < 0:
        out.extend(b"-")
        value = -value
    data = value.to_bytes(max(1, (value.bit_length() + 7) // 8), "little")
    out.extend(len(data).to_bytes(4, "little"))
    out.extend(data)


def transcript_bytes(*items) -> bytes:
    """Canonical, length-prefixed encoding of transcript items."""

    out = bytearray()
    for item in items:
        if isinstance(item, bytes):
            out.extend(b"Y")
            out.extend(len(item).to_bytes(4, "little"))
            out.extend(item)
        elif isinstance(item, str):
            encoded = item.encode("ascii")
            out.extend(b"S")
            out.extend(len(encoded).to_bytes(4, "little"))
            out.extend(encoded)
        elif isinstance(item, int):
            out.extend(b"I")
            _absorb_int(item, out)
        elif isinstance(item, (list, tuple)):
            out.extend(b"L")
            out.extend(len(item).to_bytes(4, "little"))
            for sub in item:
                out.extend(transcript_bytes(sub))
        else:
            raise TypeError(f"cannot absorb {type(item)!r} into transcript")
    return bytes(out)


def xof(domain: str, *items) -> "shake_256":
    hasher = shake_256()
    hasher.update(transcript_bytes(domain, *items))
    return hasher


def hash_digest(domain: str, *items) -> bytes:
    return xof(domain, *items).digest(32)


def challenge_coefficients(domain: str, count: int, width_bits: int, *items) -> List[int]:
    """Sample ``count`` elements of S_b = {0, ..., 2^b - 1} from the XOF."""

    if width_bits <= 0 or width_bits > 32:
        raise ValueError("challenge width out of range")
    stream = xof(domain, *items).digest(4 * count)
    mask = (1 << width_bits) - 1
    return [
        int.from_bytes(stream[4 * i : 4 * i + 4], "little") & mask
        for i in range(count)
    ]


def challenge_scalar(domain: str, width_bits: int, *items) -> int:
    return challenge_coefficients(domain, 1, width_bits, *items)[0]


def uniform_mod_q_vector(length: int, q: int) -> List[int]:
    """Uniform secret vector over Z_q from the OS entropy source."""

    return [secrets.randbelow(q) for _ in range(length)]


def ternary_vector(length: int) -> List[int]:
    """Uniform vector over {-1, 0, 1} (commitment randomness)."""

    out: List[int] = []
    while len(out) < length:
        byte = secrets.randbits(8)
        for shift in (0, 2, 4, 6):
            trit = (byte >> shift) & 3
            if trit != 3:
                out.append(trit - 1)
                if len(out) == length:
                    break
    return out


def discrete_gaussian_vector(length: int, sigma: int) -> List[int]:
    """Sample D_sigma^length by rejection from a +-12*sigma window.

    Per-coordinate: y uniform in [-12 sigma, 12 sigma], accepted with
    probability exp(-y^2 / (2 sigma^2)). The acceptance test is done in
    fixed-point decimal, matching the exactness requirement of the report.
    Tail cut at 12 sigma changes the distribution by far less than the
    2^-100 accounting of Lemma 6.3.
    """

    getcontext().prec = _REJECTION_PRECISION_DIGITS
    window = 12 * sigma
    two_sigma_sq = Decimal(2) * Decimal(sigma) ** 2
    out: List[int] = []
    while len(out) < length:
        y = secrets.randbelow(2 * window + 1) - window
        threshold = (-(Decimal(y) ** 2) / two_sigma_sq).exp()
        u = Decimal(secrets.randbits(128)) / Decimal(1 << 128)
        if u < threshold:
            out.append(y)
    return out


def rejection_accept(response: Sequence[int], center: Sequence[int], sigma: int) -> bool:
    """Lemma 6.3 accept decision for response = mask + center.

    Accept with probability min(1, (1/M) exp((|c|^2 - 2<z, c>) / (2 sigma^2)))
    where M = exp(1 + 1/288) for alpha = 12. Evaluated in fixed-point
    decimal; the caller restarts with entirely fresh masks on abort.
    """

    if len(response) != len(center):
        raise ValueError("rejection sampling length mismatch")
    getcontext().prec = _REJECTION_PRECISION_DIGITS
    norm_c_sq = sum(c * c for c in center)
    dot = sum(z * c for z, c in zip(response, center))
    exponent = (Decimal(norm_c_sq) - 2 * Decimal(dot)) / (
        Decimal(2) * Decimal(sigma) ** 2
    )
    log_m = Decimal(1) + Decimal(1) / Decimal(2 * REJECTION_ALPHA * REJECTION_ALPHA)
    threshold = (exponent - log_m).exp()
    if threshold >= 1:
        return True
    u = Decimal(secrets.randbits(128)) / Decimal(1 << 128)
    return u < threshold


def norm_squared(values: Iterable[int]) -> int:
    """Exact integer squared Euclidean norm (checklist item 2)."""

    return sum(v * v for v in values)
