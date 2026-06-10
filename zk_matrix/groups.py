"""Cyclic group backends used by the zkMatrix proof-of-concept.

The protocol code is written in additive notation, but the non-toy backend uses
a multiplicative subgroup modulo a safe prime. Group elements and scalars are
plain Python integers so the benchmark can run without external dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from typing import Iterable, Protocol, Tuple


SMALL_SAFE_PRIME_Q = 2_305_843_009_213_688_669
SMALL_SAFE_PRIME_P = 4_611_686_018_427_377_339

# RFC 3526 group 14, a 2048-bit safe-prime MODP group. The subgroup of
# quadratic residues has prime order (p - 1) / 2.
RFC3526_GROUP14_P = int(
    """
FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1
29024E088A67CC74020BBEA63B139B22514A08798E3404DD
EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245
E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED
EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D
C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F
83655D23DCA3AD961C62F356208552BB9ED529077096966D
670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B
E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9
DE2BCBF6955817183995497CEA956AE515D2261898FA0510
15728E5A8AACAA68FFFFFFFFFFFFFFFF
""".replace(
        "\n", ""
    ),
    16,
)
RFC3526_GROUP14_Q = (RFC3526_GROUP14_P - 1) // 2


class CyclicGroup(Protocol):
    """Minimal prime-order cyclic group interface."""

    name: str
    q: int
    identity: int

    def add(self, left: int, right: int) -> int:
        """Group operation in additive notation."""

    def scale(self, element: int, scalar: int) -> int:
        """Scalar multiplication in additive notation."""

    def lincomb(self, pairs: Iterable[Tuple[int, int]]) -> int:
        """Return the linear combination of ``(scalar, element)`` pairs."""

    def hash_to_group(self, label: bytes) -> int:
        """Hash a domain-separated label to a group element."""


def _hash_to_int(label: bytes) -> int:
    digest = sha256(label).digest()
    return int.from_bytes(digest, "big")


@dataclass(frozen=True)
class ToyAdditiveGroup:
    """Fast additive group over a prime field.

    This is useful for scaling experiments because it avoids modular
    exponentiation. It is not a cryptographically binding commitment group.
    """

    q: int = SMALL_SAFE_PRIME_Q
    name: str = "toy-additive"
    identity: int = 0

    def add(self, left: int, right: int) -> int:
        return (left + right) % self.q

    def scale(self, element: int, scalar: int) -> int:
        return (element * (scalar % self.q)) % self.q

    def lincomb(self, pairs: Iterable[Tuple[int, int]]) -> int:
        acc = 0
        for scalar, element in pairs:
            acc = (acc + (scalar % self.q) * element) % self.q
        return acc

    def hash_to_group(self, label: bytes) -> int:
        value = _hash_to_int(b"toy-group:" + label) % self.q
        return value or 1


@dataclass(frozen=True)
class MultiplicativeSubgroup:
    """Prime-order subgroup of quadratic residues modulo a safe prime."""

    p: int = SMALL_SAFE_PRIME_P
    q: int = SMALL_SAFE_PRIME_Q
    name: str = "small-subgroup"
    identity: int = 1

    def add(self, left: int, right: int) -> int:
        return (left * right) % self.p

    def scale(self, element: int, scalar: int) -> int:
        return pow(element, scalar % self.q, self.p)

    def lincomb(self, pairs: Iterable[Tuple[int, int]]) -> int:
        acc = 1
        for scalar, element in pairs:
            acc = (acc * pow(element, scalar % self.q, self.p)) % self.p
        return acc

    def hash_to_group(self, label: bytes) -> int:
        counter = 0
        while True:
            seed = b"subgroup:" + label + counter.to_bytes(4, "big")
            candidate = _hash_to_int(seed) % self.p
            if candidate not in (0, 1, self.p - 1):
                element = pow(candidate, 2, self.p)
                if element != 1:
                    return element
            counter += 1


def make_group(name: str) -> CyclicGroup:
    """Construct a supported group backend by name."""

    normalized = name.strip().lower()
    if normalized in {"toy", "toy-additive", "additive"}:
        return ToyAdditiveGroup()
    if normalized in {"small", "small-subgroup", "subgroup"}:
        return MultiplicativeSubgroup()
    if normalized in {"rfc3526", "rfc3526-2048", "modp-2048"}:
        return MultiplicativeSubgroup(
            p=RFC3526_GROUP14_P,
            q=RFC3526_GROUP14_Q,
            name="rfc3526-2048",
        )
    raise ValueError(f"unknown group backend: {name}")
