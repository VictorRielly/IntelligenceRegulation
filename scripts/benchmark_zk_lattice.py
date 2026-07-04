"""Benchmark the lattice (Route Z) matrix-multiplication proofs.

Measures CRS expansion, commitment, prove and verify wall-clock times for
Pi1 and Pi2 at toy dimensions, plus estimated proof sizes, and compares
against the bare modular matrix multiplication. Pure-Python numbers are
upper bounds by orders of magnitude: the report's Section 13 kernel-shape
analysis (GEMM-shaped products against G1/G2) is the path to native speed.

Usage: python3 scripts/benchmark_zk_lattice.py [n ...]
"""

import secrets
import sys
import time
from math import log2
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from zk_lattice import (
    commit_columns,
    expand_crs,
    prove_pi1,
    prove_pi2,
    toy_params,
    verify_pi1,
    verify_pi2,
)
from zk_lattice.protocol import matmul_mod
from zk_lattice.sampling import ternary_vector


def proof_size_bits_pi1(params) -> int:
    # Per repetition: gamma (b bits) + z (n log q) + zeta, xi (2N short ints).
    per_short = int(log2(params.sigma1)) + 4
    return params.r * (
        params.b + params.n * params.q.bit_length() + 2 * params.big_n * per_short
    )


def proof_size_bits_pi2(params) -> int:
    per_short = int(log2(params.sigma2)) + 4
    q_bits = params.q.bit_length()
    return params.r * (
        params.b
        + (2 * params.n + params.k + 1) * q_bits
        + 3 * params.big_n * per_short
    )


def bench(n: int) -> None:
    params = toy_params(n, n, r=4)
    q = params.q

    start = time.perf_counter()
    key = expand_crs(params)
    crs_s = time.perf_counter() - start

    a_rows = [[secrets.randbelow(q) for _ in range(n)] for _ in range(n)]
    b_columns = [[secrets.randbelow(q) for _ in range(n)] for _ in range(n)]

    start = time.perf_counter()
    c_columns = matmul_mod(a_rows, b_columns, q)
    matmul_s = time.perf_counter() - start

    rho_a = [ternary_vector(params.big_n) for _ in range(n)]
    rho_b = [ternary_vector(params.big_n) for _ in range(n)]
    tau_c = [ternary_vector(params.big_n) for _ in range(n)]

    start = time.perf_counter()
    ta = commit_columns(key, a_rows, rho_a)
    tb = commit_columns(key, b_columns, rho_b)
    tc = commit_columns(key, c_columns, tau_c)
    commit_s = time.perf_counter() - start

    start = time.perf_counter()
    proof1 = prove_pi1(key, a_rows, b_columns, rho_b, c_columns, tau_c, tb, tc)
    prove1_s = time.perf_counter() - start
    start = time.perf_counter()
    ok1 = verify_pi1(key, a_rows, tb, tc, proof1)
    verify1_s = time.perf_counter() - start

    start = time.perf_counter()
    proof2 = prove_pi2(
        key, a_rows, rho_a, b_columns, rho_b, c_columns, tau_c, ta, tb, tc
    )
    prove2_s = time.perf_counter() - start
    start = time.perf_counter()
    ok2 = verify_pi2(key, ta, tb, tc, proof2)
    verify2_s = time.perf_counter() - start

    print(
        f"pi1,{n},{params.r},{crs_s:.4f},{matmul_s:.6f},{commit_s:.4f},"
        f"{prove1_s:.4f},{verify1_s:.4f},{proof_size_bits_pi1(params) // 8},{ok1}"
    )
    print(
        f"pi2,{n},{params.r},{crs_s:.4f},{matmul_s:.6f},{commit_s:.4f},"
        f"{prove2_s:.4f},{verify2_s:.4f},{proof_size_bits_pi2(params) // 8},{ok2}"
    )


def main() -> None:
    sizes = [int(arg) for arg in sys.argv[1:]] or [4, 8, 16]
    print(
        "protocol,n,r,crs_s,matmul_s,commit_s,prove_s,verify_s,proof_bytes,verified"
    )
    for n in sizes:
        bench(n)


if __name__ == "__main__":
    main()
