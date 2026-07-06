"""Parameter selection for the lattice matrix-multiplication proofs.

Implements the symbolic constraint system of Part II, Section 11 of the
companion report. All norm bounds are computed as exact integers (squared
where a square root would appear) so that verifier norm checks never touch
floating point.

Derived quantities (B0 = sqrt(N) for ternary statement randomness, tail
factor 1.2, rejection ratio alpha = 12):

    B_rho   = m 2^b B0                (Pi1 combined randomness norm)
    B_rho_s = n 2^b B0,  B_rho_v = m 2^b B0        (Pi2)
    T1      = sqrt(2) 2^b B_rho                     (Pi1 rejection center)
    T2      = sqrt(2^{2b} (B_rho_s^2 + B_rho_v^2)
              + (2^b sqrt(N) + 2^{2b} B_rho_v)^2)   (Pi2 rejection center)
    sigma_i = 12 T_i,  B1 = 1.2 sigma_1 sqrt(2N),  B2 = 1.2 sigma_2 sqrt(3N)
    beta_1  = 2 B1 + 2^b B_rho
    beta_2  = max(2 B2 + 2^b B_rho_s, 3 * 2^b B2 + 2^{3b} B_rho_v)

Constraints (named after the report):

    C0  q prime and q > 2^{3b}
    C1  r (b-1) >= 256 for Pi1, r (b-2) >= 256 for Pi2 (Fiat-Shamir budget)
    C2  q > 8 beta
    C3  2 sqrt(k log2 q log2 delta0) >= log2 beta with delta0 = 1.0037
    C4  N - (k + n) >= 768 log2(q) / 11.7  (computational hiding, first cut)

C3 and C4 are back-of-envelope design models, not a security review: any
deployment candidate must be validated with the Albrecht-Player-Scott
lattice estimator (github.com/malb/lattice-estimator).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from math import isqrt, log2
from typing import Dict


def _is_probable_prime(value: int) -> bool:
    if value < 2:
        return False
    small_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
    for p in small_primes:
        if value % p == 0:
            return value == p
    d = value - 1
    s = 0
    while d % 2 == 0:
        d //= 2
        s += 1
    # Deterministic for value < 3.3 * 10^24 with these witnesses.
    for a in small_primes:
        x = pow(a, d, value)
        if x in (1, value - 1):
            continue
        for _ in range(s - 1):
            x = (x * x) % value
            if x == value - 1:
                break
        else:
            return False
    return True


def _isqrt_ceil(value: int) -> int:
    root = isqrt(value)
    return root if root * root == value else root + 1


@dataclass(frozen=True)
class LatticeParams:
    """One full parameter set for Pi1 and Pi2 at a fixed matrix shape."""

    n: int  # message dimension (rows of G2); covers the longest column/row
    m: int  # columns of B and C (v-combination count)
    q: int  # word-sized odd prime modulus
    b: int  # coefficient/challenge width: S_b = {0, ..., 2^b - 1}
    r: int  # parallel repetitions
    big_n: int  # randomness dimension N
    k: int  # binding rows of G1
    seed: bytes = b"zk-lattice-crs-v1"
    # True when the set is a scaled-down toy for tests; check_constraints
    # then only enforces the completeness-relevant constraints.
    toy: bool = False
    # Rectangular claim shape: A is rows x inner, B is inner x m,
    # C is rows x m. Zero defaults mean the square case rows = inner = n.
    # Committed columns/rows shorter than n are zero-padded into the
    # shared message space (an ordinary commitment to the padded vector).
    rows: int = 0
    inner: int = 0

    # Derived integer norm data, filled in __post_init__.
    sigma_open: int = field(init=False)
    bound_open_sq: int = field(init=False)
    sigma1: int = field(init=False)
    bound1_sq: int = field(init=False)
    beta1: int = field(init=False)
    sigma2: int = field(init=False)
    bound2_sq: int = field(init=False)
    beta2: int = field(init=False)

    def __post_init__(self) -> None:
        if self.n <= 0 or self.m <= 0:
            raise ValueError("matrix dimensions must be positive")
        if self.rows == 0:
            object.__setattr__(self, "rows", self.n)
        if self.inner == 0:
            object.__setattr__(self, "inner", self.n)
        if self.rows <= 0 or self.inner <= 0:
            raise ValueError("matrix dimensions must be positive")
        if max(self.rows, self.inner) > self.n:
            raise ValueError("message dimension must cover rows and inner")
        if self.b < 3 or self.b > 40:
            raise ValueError("challenge width b out of supported range")
        if self.big_n <= self.k + self.n:
            raise ValueError("randomness dimension must exceed k + n (kLWE)")
        two_b = 1 << self.b
        sqrt_n_ceil = _isqrt_ceil(self.big_n)
        # Combination counts: v combines m columns, s combines `rows` row
        # commitments (equal to n in the square case).
        b_rho = self.m * two_b * sqrt_n_ceil
        b_rho_s = self.rows * two_b * sqrt_n_ceil
        b_rho_v = b_rho

        # Opening proof (well-formedness): center gamma * rho, |gamma| < 2^b.
        t_open = two_b * sqrt_n_ceil
        object.__setattr__(self, "sigma_open", 12 * t_open)
        object.__setattr__(
            self,
            "bound_open_sq",
            (36 * self.sigma_open**2 * self.big_n) // 25,
        )

        # Pi1: center (gamma rho_v, gamma tau_v), dimension 2N.
        t1 = _isqrt_ceil(2 * (two_b * b_rho) ** 2)
        sigma1 = 12 * t1
        object.__setattr__(self, "sigma1", sigma1)
        object.__setattr__(
            self, "bound1_sq", (36 * sigma1**2 * 2 * self.big_n) // 25
        )
        bound1 = _isqrt_ceil(self.bound1_sq)
        object.__setattr__(self, "beta1", 2 * bound1 + two_b * b_rho)

        # Pi2: center (gamma rho_s, gamma rho_v, gamma eta1 + gamma^2 tau_v),
        # dimension 3N.
        t2_sq = (two_b**2) * (b_rho_s**2 + b_rho_v**2) + (
            two_b * sqrt_n_ceil + two_b**2 * b_rho_v
        ) ** 2
        sigma2 = 12 * _isqrt_ceil(t2_sq)
        object.__setattr__(self, "sigma2", sigma2)
        object.__setattr__(
            self, "bound2_sq", (36 * sigma2**2 * 3 * self.big_n) // 25
        )
        bound2 = _isqrt_ceil(self.bound2_sq)
        object.__setattr__(
            self,
            "beta2",
            max(
                2 * bound2 + two_b * b_rho_s,
                3 * two_b * bound2 + two_b**3 * b_rho_v,
            ),
        )

    @property
    def challenge_set_size(self) -> int:
        return 1 << self.b

    def check_constraints(self) -> Dict[str, bool]:
        """Evaluate the report's constraint system.

        The returned booleans follow Section 11.1. For toy parameter sets
        only C0/C2 (completeness and meaningful extraction) are required;
        C1/C3/C4 report the honest security status of the toy set (False).
        """

        log2_q = log2(self.q)
        log2_delta0 = log2(1.0037)
        results = {
            "c0_prime": _is_probable_prime(self.q),
            "c0_slack": self.q > (1 << (3 * self.b)),
            "c1_pi1": self.r * (self.b - 1) >= 256,
            "c1_pi2": self.r * (self.b - 2) >= 256,
            "c2_pi1": self.q > 8 * self.beta1,
            "c2_pi2": self.q > 8 * self.beta2,
            "c3_pi1": 2 * (self.k * log2_q * log2_delta0) ** 0.5
            >= log2(self.beta1),
            "c3_pi2": 2 * (self.k * log2_q * log2_delta0) ** 0.5
            >= log2(self.beta2),
            "c4_hiding": self.big_n - (self.k + self.n)
            >= 768.0 * log2_q / 11.7,
        }
        return results

    def require_completeness(self) -> None:
        """Raise unless honest proofs can verify (C0 primality + C2)."""

        checks = self.check_constraints()
        required = ["c0_prime", "c0_slack", "c2_pi1", "c2_pi2"]
        failed = [name for name in required if not checks[name]]
        if failed:
            raise ValueError(f"parameter set violates {failed}")


def toy_params_rect(
    rows: int,
    inner: int,
    cols: int,
    *,
    r: int = 4,
) -> LatticeParams:
    """Toy parameter set for a rectangular claim A: rows x inner,
    B: inner x cols, C: rows x cols. Message dimension is the longest
    committed column/row; see ``toy_params`` for the security caveats."""

    n = max(rows, inner)
    params = LatticeParams(
        n=n,
        m=cols,
        q=(1 << 61) - 1,
        b=8,
        r=r,
        big_n=max(64, ((16 + n + 63) // 64) * 64),
        k=16,
        toy=True,
        rows=rows,
        inner=inner,
    )
    params.require_completeness()
    return params


def toy_params(n: int = 8, m: int = 8, *, r: int = 4) -> LatticeParams:
    """Small parameter set for tests and protocol experiments.

    Soundness is only ~2^-(r*(b-1)) and the lattice dimensions carry no
    concrete hardness; use ``reference_params`` shapes plus estimator
    validation for anything security-relevant.
    """

    params = LatticeParams(
        n=n,
        m=m,
        q=(1 << 61) - 1,  # Mersenne prime 2^61 - 1
        b=8,
        r=r,
        big_n=64,
        k=16,
        toy=True,
    )
    params.require_completeness()
    return params


def reference_params_pi1(n: int = 1024, m: int = 1024) -> LatticeParams:
    """Worked illustrative set B of the report (Pi1, single-limb q).

    b=8, r=37, log2(q)=54, N=6656, k=1728. The report's status note
    applies verbatim: C3/C4 are design models, and the concrete set must
    be validated with the lattice estimator before deployment.
    """

    q = (1 << 54) - 33  # prime just below 2^54, single 54-bit limb
    return LatticeParams(n=n, m=m, q=q, b=8, r=37, big_n=6656, k=1728)


def reference_params_pi2(n: int = 1024, m: int = 1024) -> LatticeParams:
    """Worked illustrative Pi2 set of the report (two-limb q).

    b=12, r=26, ceil(log2 q)=89, N=10240, k=3200. The 2^{3b} slack of
    Theorem 8.3 is why b drops and q grows relative to the Pi1 sets.
    """

    q = (1 << 89) - 1  # Mersenne prime 2^89 - 1
    return LatticeParams(n=n, m=m, q=q, b=12, r=26, big_n=10240, k=3200)


# Backwards-friendly alias: the Pi1 engineering set is the default.
reference_params = reference_params_pi1
