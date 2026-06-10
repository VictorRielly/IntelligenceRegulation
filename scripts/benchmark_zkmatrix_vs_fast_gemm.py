#!/usr/bin/env python3
"""Compare zkMatrix proof time with the fastest local GEMM backend available.

The script tests Python numerical backends if installed and also compiles a
direct Apple Accelerate SGEMM benchmark on macOS. The proof benchmark uses
general dense random integer matrices and computes ``C = A B`` with a full
NumPy ``int64`` matmul. Entries are kept small enough that this product is exact
over the integers and therefore also valid in the proof field.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import random
import subprocess
import sys
import time
from typing import Callable

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from zk_matrix import (
    commit_matmul,
    make_bases,
    make_group,
    prove_core_matmul,
    prove_zk_matmul,
    verify_core_matmul,
    verify_zk_matmul,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sizes", type=int, nargs="+", default=[64, 128, 256, 512])
    parser.add_argument("--mode", choices=["core", "zk", "both"], default="zk")
    parser.add_argument("--seed", type=int, default=20240610)
    parser.add_argument(
        "--witness-max-entry",
        type=int,
        default=64,
        help="exclusive upper bound for dense integer witness entries",
    )
    parser.add_argument(
        "--matmul-backends",
        nargs="+",
        default=["accelerate", "numpy", "scipy", "torch", "jax"],
        choices=["accelerate", "numpy", "scipy", "torch", "jax"],
    )
    parser.add_argument(
        "--gemm-binary",
        type=Path,
        default=Path("/private/tmp/zkmatrix_accelerate_sgemm"),
    )
    return parser.parse_args()


def timed(callable_obj):
    start = time.perf_counter()
    value = callable_obj()
    return value, time.perf_counter() - start


def compile_gemm(binary: Path) -> None:
    source = REPO_ROOT / "scripts" / "accelerate_sgemm_benchmark.c"
    command = [
        "clang",
        "-O3",
        "-DACCELERATE_NEW_LAPACK",
        "-DACCELERATE_LAPACK_ILP64",
        str(source),
        "-framework",
        "Accelerate",
        "-o",
        str(binary),
    ]
    subprocess.run(command, check=True)


def run_gemm(binary: Path, sizes: list[int]) -> dict[int, dict[str, float]]:
    result = subprocess.run(
        [str(binary), *[str(size) for size in sizes]],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    rows: dict[int, dict[str, float]] = {}
    for row in csv.DictReader(result.stdout.splitlines()):
        rows[int(row["n"])] = {
            "sgemm_s": float(row["sgemm_s"]),
            "gflops": float(row["gflops"]),
            "reps": float(row["reps"]),
        }
    return rows


def _best_time(callable_obj: Callable[[], object], min_seconds: float = 0.05) -> tuple[float, int]:
    callable_obj()
    reps = 1
    best = float("inf")
    best_reps = 1
    for _ in range(5):
        while True:
            start = time.perf_counter()
            value = None
            for _ in range(reps):
                value = callable_obj()
            if hasattr(value, "block_until_ready"):
                value.block_until_ready()
            elapsed = time.perf_counter() - start
            if elapsed >= min_seconds or reps >= 1_000_000:
                break
            reps = max(1, int(reps * min_seconds / max(elapsed, 1e-12) * 1.1))
        average = elapsed / reps
        if average < best:
            best = average
            best_reps = reps
    return best, best_reps


def benchmark_numpy(size: int, seed: int) -> tuple[float, int]:
    import numpy as np

    rng = np.random.default_rng(seed)
    a = rng.random((size, size), dtype=np.float32)
    b = rng.random((size, size), dtype=np.float32)
    return _best_time(lambda: a @ b)


def benchmark_scipy(size: int, seed: int) -> tuple[float, int]:
    import numpy as np
    from scipy.linalg.blas import sgemm

    rng = np.random.default_rng(seed)
    a = rng.random((size, size), dtype=np.float32)
    b = rng.random((size, size), dtype=np.float32)
    return _best_time(lambda: sgemm(1.0, a, b))


def benchmark_torch(size: int, seed: int) -> tuple[float, int]:
    import torch

    torch.manual_seed(seed)
    a = torch.rand((size, size), dtype=torch.float32)
    b = torch.rand((size, size), dtype=torch.float32)
    return _best_time(lambda: torch.matmul(a, b))


def benchmark_jax(size: int, seed: int) -> tuple[float, int]:
    import jax
    import jax.numpy as jnp

    key_a, key_b = jax.random.split(jax.random.PRNGKey(seed))
    a = jax.random.uniform(key_a, (size, size), dtype=jnp.float32)
    b = jax.random.uniform(key_b, (size, size), dtype=jnp.float32)
    matmul = jax.jit(lambda left, right: left @ right)
    matmul(a, b).block_until_ready()
    return _best_time(lambda: matmul(a, b))


def benchmark_python_backends(
    backends: list[str],
    sizes: list[int],
    seed: int,
) -> dict[int, dict[str, object]]:
    functions = {
        "numpy": benchmark_numpy,
        "scipy": benchmark_scipy,
        "torch": benchmark_torch,
        "jax": benchmark_jax,
    }
    results: dict[int, dict[str, object]] = {}
    for size in sizes:
        for backend in backends:
            if backend not in functions:
                continue
            try:
                seconds, reps = functions[backend](size, seed + size)
            except Exception as exc:
                results.setdefault(size, {})[backend] = f"error:{type(exc).__name__}:{exc}"
                continue
            results.setdefault(size, {})[backend] = {
                "seconds": seconds,
                "gflops": (2.0 * size * size * size) / seconds / 1e9,
                "reps": reps,
            }
    return results


def fastest_rows(
    sizes: list[int],
    accelerate_rows: dict[int, dict[str, float]],
    python_rows: dict[int, dict[str, object]],
) -> dict[int, dict[str, object]]:
    fastest: dict[int, dict[str, object]] = {}
    for size in sizes:
        candidates: list[dict[str, object]] = []
        if size in accelerate_rows:
            row = accelerate_rows[size]
            candidates.append(
                {
                    "backend": "accelerate-c",
                    "seconds": row["sgemm_s"],
                    "gflops": row["gflops"],
                    "reps": row["reps"],
                }
            )
        for backend, raw in python_rows.get(size, {}).items():
            if isinstance(raw, dict):
                candidates.append(
                    {
                        "backend": backend,
                        "seconds": raw["seconds"],
                        "gflops": raw["gflops"],
                        "reps": raw["reps"],
                    }
                )
        if not candidates:
            raise RuntimeError(f"no usable GEMM backend for n={size}")
        fastest[size] = min(candidates, key=lambda row: float(row["seconds"]))
    return fastest


def dense_witness(n: int, q: int, seed: int, max_entry: int):
    import numpy as np

    if max_entry <= 1:
        raise ValueError("--witness-max-entry must be greater than 1")
    max_product = n * (max_entry - 1) * (max_entry - 1)
    if max_product >= q:
        raise ValueError("witness entries can overflow the proof field")
    if max_product >= (1 << 62):
        raise ValueError("witness entries can overflow signed int64 matmul")

    rng = np.random.default_rng(seed)
    a_np = rng.integers(0, max_entry, size=(n, n), dtype=np.int64)
    b_np = rng.integers(0, max_entry, size=(n, n), dtype=np.int64)
    c_np = a_np @ b_np
    witness_matmul_s, _reps = _best_time(lambda: a_np @ b_np)
    return a_np.tolist(), b_np.tolist(), c_np.tolist(), witness_matmul_s


def benchmark_proof(size: int, mode: str, seed: int, witness_max_entry: int):
    group = make_group("toy")
    rng = random.Random(seed + size * 1000 + (0 if mode == "core" else 1))
    bases = make_bases(group, size, size, size, f"fast-gemm-{mode}-{size}".encode())
    a, b, c, witness_matmul_s = dense_witness(
        size, group.q, seed + size * 1000, witness_max_entry
    )
    statement, witness = commit_matmul(
        group, bases, a, b, c, blinded=(mode == "zk"), rng=rng
    )

    if mode == "core":
        proof, prove_s = timed(lambda: prove_core_matmul(group, bases, statement, witness))
        verified, verify_s = timed(lambda: verify_core_matmul(group, bases, statement, proof))
    else:
        proof, prove_s = timed(lambda: prove_zk_matmul(group, bases, statement, witness, rng=rng))
        verified, verify_s = timed(lambda: verify_zk_matmul(group, bases, statement, proof))

    return prove_s, verify_s, verified, witness_matmul_s


def main() -> None:
    args = parse_args()
    accelerate_rows: dict[int, dict[str, float]] = {}
    if "accelerate" in args.matmul_backends:
        compile_gemm(args.gemm_binary)
        accelerate_rows = run_gemm(args.gemm_binary, args.sizes)
    python_rows = benchmark_python_backends(
        args.matmul_backends, args.sizes, args.seed
    )
    gemm_rows = fastest_rows(args.sizes, accelerate_rows, python_rows)
    modes = ["core", "zk"] if args.mode == "both" else [args.mode]

    print(
        "mode,n,fastest_float_backend,float_matmul_s,float_gflops,"
        "exact_int64_matmul_s,proof_s,verify_s,"
        "proof_over_float_matmul,proof_over_exact_int64_matmul,verified"
    )
    for size in args.sizes:
        for mode in modes:
            proof_s, verify_s, verified, witness_matmul_s = benchmark_proof(
                size, mode, args.seed, args.witness_max_entry
            )
            matmul_s = float(gemm_rows[size]["seconds"])
            float_ratio = proof_s / matmul_s
            exact_ratio = proof_s / witness_matmul_s
            print(
                f"{mode},{size},{gemm_rows[size]['backend']},{matmul_s:.12f},"
                f"{float(gemm_rows[size]['gflops']):.3f},"
                f"{witness_matmul_s:.9f},{proof_s:.9f},{verify_s:.9f},"
                f"{float_ratio:.1f},{exact_ratio:.1f},{verified}"
            )


if __name__ == "__main__":
    main()
