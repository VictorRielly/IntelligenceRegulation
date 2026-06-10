"""Inner-product proof used by the zkMatrix proof-of-concept.

The relation is expressed in additive notation:

    C = <a, b> U + <a, G> + <b, H>

where C, U, G_i and H_i are group elements, while a_i and b_i are field
scalars. The implementation is a compact Bulletproof-style recursive argument.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Sequence

from .groups import CyclicGroup
from .transcript import challenge_scalar


@dataclass(frozen=True)
class InnerProductProof:
    n: int
    left: List[int]
    right: List[int]
    a_final: int
    b_final: int


def inner_product(values_a: Sequence[int], values_b: Sequence[int], q: int) -> int:
    if len(values_a) != len(values_b):
        raise ValueError("inner product vectors must have the same length")
    return sum((a % q) * (b % q) for a, b in zip(values_a, values_b)) % q


def next_power_of_two(value: int) -> int:
    if value <= 0:
        raise ValueError("vector length must be positive")
    return 1 << (value - 1).bit_length()


def pad_scalars(values: Sequence[int], size: int) -> List[int]:
    if len(values) > size:
        raise ValueError("cannot pad to a smaller size")
    return list(values) + [0] * (size - len(values))


def pad_group_elements(group: CyclicGroup, values: Sequence[int], size: int) -> List[int]:
    if len(values) > size:
        raise ValueError("cannot pad to a smaller size")
    return list(values) + [group.identity] * (size - len(values))


def vector_commitment(group: CyclicGroup, values: Sequence[int], bases: Sequence[int]) -> int:
    if len(values) != len(bases):
        raise ValueError("commitment values and bases must have the same length")
    return group.lincomb(zip(values, bases))


def prove_inner_product(
    group: CyclicGroup,
    commitment: int,
    scalar_base: int,
    left_bases: Sequence[int],
    right_bases: Sequence[int],
    left_values: Sequence[int],
    right_values: Sequence[int],
    transcript_seed: bytes = b"",
) -> InnerProductProof:
    """Create an inner-product proof for the supplied committed vectors."""

    if not (
        len(left_bases)
        == len(right_bases)
        == len(left_values)
        == len(right_values)
    ):
        raise ValueError("all inner-product vectors must have the same length")

    n = next_power_of_two(len(left_values))
    a = pad_scalars([value % group.q for value in left_values], n)
    b = pad_scalars([value % group.q for value in right_values], n)
    g = pad_group_elements(group, left_bases, n)
    h = pad_group_elements(group, right_bases, n)
    current = commitment

    left_messages: List[int] = []
    right_messages: List[int] = []
    round_index = 0

    while len(a) > 1:
        half = len(a) // 2
        a_left, a_right = a[:half], a[half:]
        b_left, b_right = b[:half], b[half:]
        g_left, g_right = g[:half], g[half:]
        h_left, h_right = h[:half], h[half:]

        left_cross = inner_product(a_left, b_right, group.q)
        right_cross = inner_product(a_right, b_left, group.q)
        left_message = group.add(
            group.add(
                vector_commitment(group, a_left, g_right),
                vector_commitment(group, b_right, h_left),
            ),
            group.scale(scalar_base, left_cross),
        )
        right_message = group.add(
            group.add(
                vector_commitment(group, a_right, g_left),
                vector_commitment(group, b_left, h_right),
            ),
            group.scale(scalar_base, right_cross),
        )

        challenge = challenge_scalar(
            group.q,
            "inner-product-round",
            transcript_seed,
            round_index,
            current,
            scalar_base,
            left_message,
            right_message,
        )
        challenge_inv = pow(challenge, -1, group.q)

        a = [
            (left + challenge_inv * right) % group.q
            for left, right in zip(a_left, a_right)
        ]
        b = [
            (left + challenge * right) % group.q
            for left, right in zip(b_left, b_right)
        ]
        g = [
            group.add(left, group.scale(right, challenge))
            for left, right in zip(g_left, g_right)
        ]
        h = [
            group.add(left, group.scale(right, challenge_inv))
            for left, right in zip(h_left, h_right)
        ]
        current = group.add(
            group.add(group.scale(left_message, challenge), current),
            group.scale(right_message, challenge_inv),
        )

        left_messages.append(left_message)
        right_messages.append(right_message)
        round_index += 1

    return InnerProductProof(
        n=n,
        left=left_messages,
        right=right_messages,
        a_final=a[0],
        b_final=b[0],
    )


def verify_inner_product(
    group: CyclicGroup,
    commitment: int,
    scalar_base: int,
    left_bases: Sequence[int],
    right_bases: Sequence[int],
    proof: InnerProductProof,
    transcript_seed: bytes = b"",
) -> bool:
    """Verify an inner-product proof."""

    if proof.n != next_power_of_two(len(left_bases)):
        return False
    if len(left_bases) != len(right_bases):
        return False
    if len(proof.left) != len(proof.right):
        return False
    if len(proof.left) != (proof.n.bit_length() - 1):
        return False

    g = pad_group_elements(group, left_bases, proof.n)
    h = pad_group_elements(group, right_bases, proof.n)
    current = commitment

    for round_index, (left_message, right_message) in enumerate(
        zip(proof.left, proof.right)
    ):
        if len(g) == 1:
            return False
        challenge = challenge_scalar(
            group.q,
            "inner-product-round",
            transcript_seed,
            round_index,
            current,
            scalar_base,
            left_message,
            right_message,
        )
        challenge_inv = pow(challenge, -1, group.q)

        half = len(g) // 2
        g_left, g_right = g[:half], g[half:]
        h_left, h_right = h[:half], h[half:]
        g = [
            group.add(left, group.scale(right, challenge))
            for left, right in zip(g_left, g_right)
        ]
        h = [
            group.add(left, group.scale(right, challenge_inv))
            for left, right in zip(h_left, h_right)
        ]
        current = group.add(
            group.add(group.scale(left_message, challenge), current),
            group.scale(right_message, challenge_inv),
        )

    expected = group.add(
        group.add(
            group.scale(scalar_base, (proof.a_final * proof.b_final) % group.q),
            group.scale(g[0], proof.a_final),
        ),
        group.scale(h[0], proof.b_final),
    )
    return current == expected
