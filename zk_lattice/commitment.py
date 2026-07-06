"""Ajtai/BDLOP-style lattice commitments (Construction 5.3 of the report).

    com(x; rho) = (G1 rho, G2 rho + x) in Z_q^k x Z_q^n

with uniform G1, G2 expanded from a public seed and ternary randomness rho.
Binding of the first slot reduces to SIS for G1 (Lemma 5.5, in the relaxed
slack-scaled form); hiding is statistical (leftover hash lemma) or
computational (knapsack-LWE) depending on the parameter regime. The scheme
is additively homomorphic in both slots.

Also implements the well-formedness opening proof of Section 5.5 / Alg. 1:
a one-time Sigma-protocol per commitment proving knowledge of short rho
with G1 rho = t1.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Sequence, Tuple

from .params import LatticeParams
from .sampling import (
    challenge_scalar,
    discrete_gaussian_vector,
    hash_digest,
    norm_squared,
    rejection_accept,
    xof,
)

Vector = List[int]
Matrix = List[List[int]]
Commitment = Tuple[Vector, Vector]  # (t1, t2)


@dataclass(frozen=True)
class CommitmentKey:
    params: LatticeParams
    g1: Matrix  # k x N
    g2: Matrix  # n x N
    crs_hash: bytes


def _expand_row(seed: bytes, label: str, row: int, width: int, q: int) -> Vector:
    """One uniform row over Z_q, rejection-sampled from XOF output."""

    q_bits = q.bit_length()
    q_bytes = (q_bits + 7) // 8
    mask = (1 << q_bits) - 1
    out: Vector = []
    block = 0
    while len(out) < width:
        stream = xof("crs-row", seed, label, row, block).digest(
            q_bytes * (2 * width + 8)
        )
        for i in range(0, len(stream) - q_bytes + 1, q_bytes):
            candidate = int.from_bytes(stream[i : i + q_bytes], "little") & mask
            if candidate < q:
                out.append(candidate)
                if len(out) == width:
                    break
        block += 1
    return out


def expand_crs(params: LatticeParams) -> CommitmentKey:
    """Expand G1, G2 from the public seed (Alg. 1, ExpandCRS)."""

    g1 = [
        _expand_row(params.seed, "G1", i, params.big_n, params.q)
        for i in range(params.k)
    ]
    g2 = [
        _expand_row(params.seed, "G2", i, params.big_n, params.q)
        for i in range(params.n)
    ]
    crs_hash = hash_digest(
        "crs",
        params.seed,
        params.q,
        params.n,
        params.m,
        params.k,
        params.big_n,
        params.b,
        params.r,
        params.rows,
        params.inner,
    )
    return CommitmentKey(params=params, g1=g1, g2=g2, crs_hash=crs_hash)


def matvec_mod(matrix: Matrix, vector: Sequence[int], q: int) -> Vector:
    return [sum(row[j] * vector[j] for j in range(len(vector))) % q for row in matrix]


def vec_add_mod(left: Sequence[int], right: Sequence[int], q: int) -> Vector:
    return [(a + b) % q for a, b in zip(left, right)]


def vec_sub_mod(left: Sequence[int], right: Sequence[int], q: int) -> Vector:
    return [(a - b) % q for a, b in zip(left, right)]


def vec_scale_mod(values: Sequence[int], scalar: int, q: int) -> Vector:
    return [(scalar * v) % q for v in values]


def commit(key: CommitmentKey, message: Sequence[int], randomness: Sequence[int]) -> Commitment:
    """com(x; rho) = (G1 rho, G2 rho + pad(x)).

    Messages shorter than the shared message dimension are zero-padded:
    the result is an ordinary commitment to the padded vector.
    """

    q = key.params.q
    if len(message) > key.params.n:
        raise ValueError("message length must not exceed n")
    if len(randomness) != key.params.big_n:
        raise ValueError("randomness length must equal N")
    padded = [v % q for v in message] + [0] * (key.params.n - len(message))
    t1 = matvec_mod(key.g1, randomness, q)
    t2 = vec_add_mod(matvec_mod(key.g2, randomness, q), padded, q)
    return (t1, t2)


def commit_columns(key: CommitmentKey, matrix_columns: Sequence[Sequence[int]], randomnesses: Sequence[Sequence[int]]) -> List[Commitment]:
    """Per-column commitments (CommitMatrix of Alg. 1)."""

    if len(matrix_columns) != len(randomnesses):
        raise ValueError("one randomness vector per column required")
    return [
        commit(key, column, rho)
        for column, rho in zip(matrix_columns, randomnesses)
    ]


def combine_commitments(commitments: Sequence[Commitment], coefficients: Sequence[int], q: int) -> Commitment:
    """Homomorphic combination sum_j coeff_j * T^(j) (small coefficients)."""

    if len(commitments) != len(coefficients):
        raise ValueError("coefficient count mismatch")
    k = len(commitments[0][0])
    n = len(commitments[0][1])
    t1 = [0] * k
    t2 = [0] * n
    for (c1, c2), coeff in zip(commitments, coefficients):
        for i in range(k):
            t1[i] = (t1[i] + coeff * c1[i]) % q
        for i in range(n):
            t2[i] = (t2[i] + coeff * c2[i]) % q
    return (t1, t2)


def combine_randomness(randomnesses: Sequence[Sequence[int]], coefficients: Sequence[int]) -> Vector:
    """The matching combination over Z of the opening randomness."""

    length = len(randomnesses[0])
    out = [0] * length
    for rho, coeff in zip(randomnesses, coefficients):
        for i in range(length):
            out[i] += coeff * rho[i]
    return out


def scalar_key(key: CommitmentKey, s: Sequence[int]) -> Vector:
    """Derived scalar key g_s^T = s^T G2 for com_s (Section 8.2)."""

    q = key.params.q
    return [
        sum(s[i] * key.g2[i][j] for i in range(len(s))) % q
        for j in range(key.params.big_n)
    ]


def commit_scalar(key: CommitmentKey, g_s: Sequence[int], value: int, randomness: Sequence[int]) -> Tuple[Vector, int]:
    """com_s(x; rho) = (G1 rho, g_s^T rho + x)."""

    q = key.params.q
    t1 = matvec_mod(key.g1, randomness, q)
    t2 = (sum(g_s[j] * randomness[j] for j in range(len(randomness))) + value) % q
    return (t1, t2)


def prove_opening(key: CommitmentKey, commitment: Commitment, randomness: Sequence[int]) -> Tuple[int, Vector]:
    """Well-formedness proof of Section 5.5 (compressed transcript)."""

    params = key.params
    while True:
        y = discrete_gaussian_vector(params.big_n, params.sigma_open)
        w = matvec_mod(key.g1, y, params.q)
        gamma = challenge_scalar(
            "open", params.b, key.crs_hash, commitment[0], commitment[1], w
        )
        zeta = [y[i] + gamma * randomness[i] for i in range(params.big_n)]
        center = [gamma * randomness[i] for i in range(params.big_n)]
        if rejection_accept(zeta, center, params.sigma_open):
            return (gamma, zeta)


def verify_opening(key: CommitmentKey, commitment: Commitment, proof: Tuple[int, Vector]) -> bool:
    params = key.params
    gamma, zeta = proof
    if not (0 <= gamma < params.challenge_set_size):
        return False
    if len(zeta) != params.big_n:
        return False
    if norm_squared(zeta) > params.bound_open_sq:
        return False
    w = vec_sub_mod(
        matvec_mod(key.g1, zeta, params.q),
        vec_scale_mod(commitment[0], gamma, params.q),
        params.q,
    )
    expected = challenge_scalar(
        "open", params.b, key.crs_hash, commitment[0], commitment[1], w
    )
    return gamma == expected
