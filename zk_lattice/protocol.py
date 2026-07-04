"""Protocols Pi1 and Pi2: lattice ZK proofs of matrix multiplication.

Non-interactive (Fiat-Shamir) Route-Z transcription of Sections 7, 8 and 12
of the companion report:

* ``Pi1``: public ``A``; hidden ``B``, ``C`` behind per-column commitments.
  Freivalds vector ``v`` compresses ``C = AB`` to ``A(Bv) = Cv``; a masked
  Sigma-protocol proves the compressed claim against the homomorphically
  combined commitments. 2-special sound per repetition.
* ``Pi2``: all three matrices hidden (``A`` committed by rows). Double
  compression reduces the claim to one scalar inner product
  ``<A^T s, B v> = s^T C v``, proven with the quadratic garbage-term
  product Sigma-protocol (commitments ``t0``, ``t1`` to the two low
  coefficients). 3-special sound per repetition.

Transcript compression (Remark 7.6): first messages are not transmitted;
the verifier recomputes them from the responses and checks the challenge
hash. Every challenge binds ``crs_hash``, the full statement hash and the
repetition index (implementation-security checklist, item 3).

Matrix conventions: ``A`` is given as a list of ``n`` rows; ``B`` and ``C``
as lists of ``m`` columns (the commitment orientation). All mod-q values
are canonical representatives in ``[0, q)``; masks and randomness responses
are signed integers.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Sequence, Tuple

from .commitment import (
    Commitment,
    CommitmentKey,
    combine_commitments,
    combine_randomness,
    commit,
    commit_scalar,
    matvec_mod,
    scalar_key,
    vec_add_mod,
    vec_scale_mod,
    vec_sub_mod,
)
from .sampling import (
    challenge_coefficients,
    challenge_scalar,
    discrete_gaussian_vector,
    hash_digest,
    norm_squared,
    rejection_accept,
    ternary_vector,
    uniform_mod_q_vector,
)

Vector = List[int]
Matrix = List[List[int]]


@dataclass(frozen=True)
class Pi1Repetition:
    gamma: int
    z: Vector  # length n, mod q
    zeta: Vector  # length N, signed
    xi: Vector  # length N, signed


@dataclass(frozen=True)
class Pi1Proof:
    repetitions: List[Pi1Repetition]


@dataclass(frozen=True)
class Pi2Repetition:
    gamma: int
    t1: Tuple[Vector, int]  # transmitted garbage commitment (Theorem 8.5)
    z_a: Vector
    z_b: Vector
    zeta_a: Vector
    zeta_b: Vector
    zeta_q: Vector


@dataclass(frozen=True)
class Pi2Proof:
    repetitions: List[Pi2Repetition]


def matmul_mod(a_rows: Matrix, b_columns: Matrix, q: int) -> Matrix:
    """C = A B, returned as columns to match the commitment orientation."""

    n = len(a_rows)
    return [
        [sum(a_rows[i][t] * column[t] for t in range(n)) % q for i in range(n)]
        for column in b_columns
    ]


def _column_combination(columns: Matrix, coefficients: Sequence[int], q: int) -> Vector:
    """sum_j coeff_j * column_j mod q (e.g. b = B v)."""

    n = len(columns[0])
    out = [0] * n
    for column, coeff in zip(columns, coefficients):
        for i in range(n):
            out[i] = (out[i] + coeff * column[i]) % q
    return out


def _row_combination(rows: Matrix, coefficients: Sequence[int], q: int) -> Vector:
    """a = A^T s = sum_i s_i * row_i mod q."""

    n = len(rows[0])
    out = [0] * n
    for row, coeff in zip(rows, coefficients):
        for i in range(n):
            out[i] = (out[i] + coeff * row[i]) % q
    return out


def _statement_hash_pi1(
    key: CommitmentKey,
    a_rows: Matrix,
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
) -> bytes:
    return hash_digest("stmt", key.crs_hash, a_rows, list(tb), list(tc))


def _statement_hash_pi2(
    key: CommitmentKey,
    ta: Sequence[Commitment],
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
) -> bytes:
    return hash_digest("stmt2", key.crs_hash, list(ta), list(tb), list(tc))


def prove_pi1(
    key: CommitmentKey,
    a_rows: Matrix,
    b_columns: Matrix,
    rho_b: Sequence[Sequence[int]],
    c_columns: Matrix,
    tau_c: Sequence[Sequence[int]],
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
) -> Pi1Proof:
    """Algorithm 3: Pi1 non-interactive prover (r repetitions)."""

    params = key.params
    q = params.q
    h0 = _statement_hash_pi1(key, a_rows, tb, tc)
    repetitions = []
    for ell in range(params.r):
        v = challenge_coefficients("v", params.m, params.b, h0, ell)
        b_vec = _column_combination(b_columns, v, q)
        rho_v = combine_randomness(rho_b, v)
        tau_v = combine_randomness(tau_c, v)
        while True:
            epsilon = uniform_mod_q_vector(params.n, q)
            noise = discrete_gaussian_vector(2 * params.big_n, params.sigma1)
            eta, mu = noise[: params.big_n], noise[params.big_n :]
            w = commit(key, epsilon, eta)
            u = commit(key, matvec_mod(a_rows, epsilon, q), mu)
            gamma = challenge_scalar("gamma", params.b, h0, ell, w, u)
            z = vec_add_mod(epsilon, vec_scale_mod(b_vec, gamma, q), q)
            zeta = [eta[i] + gamma * rho_v[i] for i in range(params.big_n)]
            xi = [mu[i] + gamma * tau_v[i] for i in range(params.big_n)]
            center = [gamma * value for value in rho_v] + [
                gamma * value for value in tau_v
            ]
            if rejection_accept(zeta + xi, center, params.sigma1):
                break
        repetitions.append(Pi1Repetition(gamma=gamma, z=z, zeta=zeta, xi=xi))
    return Pi1Proof(repetitions=repetitions)


def verify_pi1(
    key: CommitmentKey,
    a_rows: Matrix,
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
    proof: Pi1Proof,
) -> bool:
    """Algorithm 4: Pi1 verifier (compressed transcripts)."""

    params = key.params
    q = params.q
    if len(proof.repetitions) != params.r:
        return False
    h0 = _statement_hash_pi1(key, a_rows, tb, tc)
    for ell, rep in enumerate(proof.repetitions):
        if not (0 <= rep.gamma < params.challenge_set_size):
            return False
        if len(rep.z) != params.n or any(not 0 <= value < q for value in rep.z):
            return False
        if len(rep.zeta) != params.big_n or len(rep.xi) != params.big_n:
            return False
        if norm_squared(rep.zeta + rep.xi) > params.bound1_sq:
            return False
        v = challenge_coefficients("v", params.m, params.b, h0, ell)
        t_b = combine_commitments(tb, v, q)
        t_c = combine_commitments(tc, v, q)
        # w = (G1 zeta, G2 zeta + z) - gamma T_b
        w = (
            vec_sub_mod(
                matvec_mod(key.g1, rep.zeta, q),
                vec_scale_mod(t_b[0], rep.gamma, q),
                q,
            ),
            vec_sub_mod(
                vec_add_mod(matvec_mod(key.g2, rep.zeta, q), rep.z, q),
                vec_scale_mod(t_b[1], rep.gamma, q),
                q,
            ),
        )
        # u = (G1 xi, G2 xi + A z) - gamma T_c
        u = (
            vec_sub_mod(
                matvec_mod(key.g1, rep.xi, q),
                vec_scale_mod(t_c[0], rep.gamma, q),
                q,
            ),
            vec_sub_mod(
                vec_add_mod(
                    matvec_mod(key.g2, rep.xi, q),
                    matvec_mod(a_rows, rep.z, q),
                    q,
                ),
                vec_scale_mod(t_c[1], rep.gamma, q),
                q,
            ),
        )
        if rep.gamma != challenge_scalar("gamma", params.b, h0, ell, w, u):
            return False
    return True


def prove_pi2(
    key: CommitmentKey,
    a_rows: Matrix,
    rho_a: Sequence[Sequence[int]],
    b_columns: Matrix,
    rho_b: Sequence[Sequence[int]],
    c_columns: Matrix,
    tau_c: Sequence[Sequence[int]],
    ta: Sequence[Commitment],
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
) -> Pi2Proof:
    """Algorithm 5: Pi2 non-interactive prover."""

    params = key.params
    q = params.q
    h0 = _statement_hash_pi2(key, ta, tb, tc)
    repetitions = []
    for ell in range(params.r):
        sv = challenge_coefficients("sv", params.n + params.m, params.b, h0, ell)
        s, v = sv[: params.n], sv[params.n :]
        a_vec = _row_combination(a_rows, s, q)
        b_vec = _column_combination(b_columns, v, q)
        rho_s = combine_randomness(rho_a, s)
        rho_v = combine_randomness(rho_b, v)
        tau_v = combine_randomness(tau_c, v)
        g_s = scalar_key(key, s)
        while True:
            eps_a = uniform_mod_q_vector(params.n, q)
            eps_b = uniform_mod_q_vector(params.n, q)
            eta1 = ternary_vector(params.big_n)
            noise = discrete_gaussian_vector(3 * params.big_n, params.sigma2)
            eta_a = noise[: params.big_n]
            eta_b = noise[params.big_n : 2 * params.big_n]
            eta0 = noise[2 * params.big_n :]
            g0 = sum(x * y for x, y in zip(eps_a, eps_b)) % q
            g1 = (
                sum(x * y for x, y in zip(eps_a, b_vec))
                + sum(x * y for x, y in zip(a_vec, eps_b))
            ) % q
            w_a = commit(key, eps_a, eta_a)
            w_b = commit(key, eps_b, eta_b)
            t0 = commit_scalar(key, g_s, g0, eta0)
            t1 = commit_scalar(key, g_s, g1, eta1)
            gamma = challenge_scalar("gamma2", params.b, h0, ell, w_a, w_b, t0, t1)
            z_a = vec_add_mod(eps_a, vec_scale_mod(a_vec, gamma, q), q)
            z_b = vec_add_mod(eps_b, vec_scale_mod(b_vec, gamma, q), q)
            gamma_sq = gamma * gamma
            zeta_a = [eta_a[i] + gamma * rho_s[i] for i in range(params.big_n)]
            zeta_b = [eta_b[i] + gamma * rho_v[i] for i in range(params.big_n)]
            zeta_q = [
                eta0[i] + gamma * eta1[i] + gamma_sq * tau_v[i]
                for i in range(params.big_n)
            ]
            center = (
                [gamma * value for value in rho_s]
                + [gamma * value for value in rho_v]
                + [
                    gamma * eta1[i] + gamma_sq * tau_v[i]
                    for i in range(params.big_n)
                ]
            )
            if rejection_accept(zeta_a + zeta_b + zeta_q, center, params.sigma2):
                break
        repetitions.append(
            Pi2Repetition(
                gamma=gamma,
                t1=t1,
                z_a=z_a,
                z_b=z_b,
                zeta_a=zeta_a,
                zeta_b=zeta_b,
                zeta_q=zeta_q,
            )
        )
    return Pi2Proof(repetitions=repetitions)


def verify_pi2(
    key: CommitmentKey,
    ta: Sequence[Commitment],
    tb: Sequence[Commitment],
    tc: Sequence[Commitment],
    proof: Pi2Proof,
) -> bool:
    """Pi2 verifier (Section 12): recompute w_a, w_b, t0, check the hash."""

    params = key.params
    q = params.q
    if len(proof.repetitions) != params.r:
        return False
    h0 = _statement_hash_pi2(key, ta, tb, tc)
    for ell, rep in enumerate(proof.repetitions):
        if not (0 <= rep.gamma < params.challenge_set_size):
            return False
        for vec in (rep.z_a, rep.z_b):
            if len(vec) != params.n or any(not 0 <= value < q for value in vec):
                return False
        for vec in (rep.zeta_a, rep.zeta_b, rep.zeta_q):
            if len(vec) != params.big_n:
                return False
        if (
            norm_squared(rep.zeta_a + rep.zeta_b + rep.zeta_q)
            > params.bound2_sq
        ):
            return False
        sv = challenge_coefficients("sv", params.n + params.m, params.b, h0, ell)
        s, v = sv[: params.n], sv[params.n :]
        t_a = combine_commitments(ta, s, q)
        t_b = combine_commitments(tb, v, q)
        t_c = combine_commitments(tc, v, q)
        g_s = scalar_key(key, s)
        # T_t = (T_c1, s^T T_c2): scalar commitment under the derived key.
        t_t = (t_c[0], sum(s[i] * t_c[1][i] for i in range(params.n)) % q)
        gamma = rep.gamma
        gamma_sq = gamma * gamma
        w_a = (
            vec_sub_mod(
                matvec_mod(key.g1, rep.zeta_a, q),
                vec_scale_mod(t_a[0], gamma, q),
                q,
            ),
            vec_sub_mod(
                vec_add_mod(matvec_mod(key.g2, rep.zeta_a, q), rep.z_a, q),
                vec_scale_mod(t_a[1], gamma, q),
                q,
            ),
        )
        w_b = (
            vec_sub_mod(
                matvec_mod(key.g1, rep.zeta_b, q),
                vec_scale_mod(t_b[0], gamma, q),
                q,
            ),
            vec_sub_mod(
                vec_add_mod(matvec_mod(key.g2, rep.zeta_b, q), rep.z_b, q),
                vec_scale_mod(t_b[1], gamma, q),
                q,
            ),
        )
        inner_z = sum(x * y for x, y in zip(rep.z_a, rep.z_b)) % q
        t1_first, t1_second = rep.t1
        if len(t1_first) != params.k or not 0 <= t1_second < q:
            return False
        g1_zeta_q = matvec_mod(key.g1, rep.zeta_q, q)
        t0 = (
            [
                (g1_zeta_q[i] - gamma * t1_first[i] - gamma_sq * t_t[0][i]) % q
                for i in range(params.k)
            ],
            (
                sum(g_s[j] * rep.zeta_q[j] for j in range(params.big_n))
                + inner_z
                - gamma * t1_second
                - gamma_sq * t_t[1]
            )
            % q,
        )
        expected = challenge_scalar(
            "gamma2", params.b, h0, ell, w_a, w_b, t0, (list(t1_first), t1_second)
        )
        if gamma != expected:
            return False
    return True
