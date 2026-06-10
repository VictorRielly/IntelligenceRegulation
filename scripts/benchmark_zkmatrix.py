#!/usr/bin/env python3
"""Benchmark finite-field multiplication against zkMatrix proof generation."""

from __future__ import annotations

import argparse
from pathlib import Path
import random
import sys
import time

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from zk_matrix import (
    commit_matmul,
    make_bases,
    make_group,
    matrix_multiply,
    prove_naive_zk_matmul,
    prove_core_matmul,
    prove_zk_matmul,
    random_matrix,
    verify_naive_zk_matmul,
    verify_core_matmul,
    verify_zk_matmul,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backend",
        choices=["toy", "small-subgroup", "rfc3526-2048"],
        default="small-subgroup",
        help="group backend; toy is fastest, rfc3526-2048 is closest to a real DLOG group",
    )
    parser.add_argument(
        "--mode",
        choices=["core", "zk", "naive-zk", "both"],
        default="both",
        help="core is Algorithm 4; zk is paper-optimized masking; naive-zk is direct Algorithm 5",
    )
    parser.add_argument(
        "--sizes",
        type=int,
        nargs="+",
        default=[2, 4, 8],
        help="square matrix sizes to benchmark",
    )
    parser.add_argument("--seed", type=int, default=20240610)
    parser.add_argument(
        "--max-entry",
        type=int,
        default=1000,
        help="upper bound for random matrix entries",
    )
    return parser.parse_args()


def timed(callable_obj):
    start = time.perf_counter()
    value = callable_obj()
    return value, time.perf_counter() - start


def benchmark_one(group, mode: str, size: int, seed: int, max_entry: int):
    rng = random.Random(seed + size * 10_000 + (0 if mode == "core" else 1))
    bases = make_bases(group, size, size, size, f"bench-{mode}-{size}".encode("ascii"))
    a = random_matrix(size, size, group.q, rng=rng, max_entry=max_entry)
    b = random_matrix(size, size, group.q, rng=rng, max_entry=max_entry)

    c, matmul_s = timed(lambda: matrix_multiply(a, b, group.q))
    statement, witness = None, None
    blinded = mode in {"zk", "naive-zk"}
    (statement, witness), commit_s = timed(
        lambda: commit_matmul(group, bases, a, b, c, blinded=blinded, rng=rng)
    )

    if mode == "core":
        proof, prove_s = timed(lambda: prove_core_matmul(group, bases, statement, witness))
        verified, verify_s = timed(
            lambda: verify_core_matmul(group, bases, statement, proof)
        )
    elif mode == "zk":
        proof, prove_s = timed(lambda: prove_zk_matmul(group, bases, statement, witness, rng=rng))
        verified, verify_s = timed(lambda: verify_zk_matmul(group, bases, statement, proof))
    else:
        proof, prove_s = timed(
            lambda: prove_naive_zk_matmul(group, bases, statement, witness, rng=rng)
        )
        verified, verify_s = timed(
            lambda: verify_naive_zk_matmul(group, bases, statement, proof)
        )

    ratio = prove_s / matmul_s if matmul_s else float("inf")
    return {
        "backend": group.name,
        "mode": mode,
        "n": size,
        "matmul_s": matmul_s,
        "commit_s": commit_s,
        "prove_s": prove_s,
        "verify_s": verify_s,
        "proof_over_matmul": ratio,
        "verified": verified,
    }


def main() -> None:
    args = parse_args()
    group = make_group(args.backend)
    modes = ["core", "zk"] if args.mode == "both" else [args.mode]

    print(
        "# Pure-Python prototype. core=Algorithm 4 reduction; "
        "zk=paper-optimized subprotocol masking; naive-zk=direct Algorithm 5."
    )
    print(
        "backend,mode,n,matmul_s,commit_s,prove_s,verify_s,proof_over_matmul,verified"
    )
    for size in args.sizes:
        for mode in modes:
            row = benchmark_one(group, mode, size, args.seed, args.max_entry)
            print(
                "{backend},{mode},{n},{matmul_s:.9f},{commit_s:.9f},"
                "{prove_s:.9f},{verify_s:.9f},{proof_over_matmul:.3f},{verified}".format(
                    **row
                )
            )


if __name__ == "__main__":
    main()
