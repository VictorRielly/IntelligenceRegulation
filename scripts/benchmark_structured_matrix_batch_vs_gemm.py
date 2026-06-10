#!/usr/bin/env python3
"""Compare same-shape structured matrix batch proofs with local SGEMM."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = REPO_ROOT / "scripts"
CRATE = REPO_ROOT / "zkmatrix-rs"
BINARY = CRATE / "target" / "release" / "structured_matrix"

if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from benchmark_zkmatrix_vs_fast_gemm import (  # noqa: E402
    benchmark_python_backends,
    compile_gemm,
    fastest_rows,
    run_gemm,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--batches", type=int, nargs="+", default=[1, 2, 4, 8])
    parser.add_argument("--mode", choices=["core", "zk"], default="zk")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument(
        "--matmul-backends",
        nargs="+",
        default=["accelerate"],
        choices=["accelerate", "numpy", "scipy", "torch", "jax"],
    )
    parser.add_argument(
        "--gemm-binary",
        type=Path,
        default=Path("/private/tmp/zkmatrix_accelerate_sgemm"),
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--append", action="store_true")
    return parser.parse_args()


def build() -> None:
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "structured_matrix"],
        cwd=CRATE,
        check=True,
    )
    subprocess.run([str(BINARY), "self-test"], check=True)


def run_batch(mode: str, size: int, batch: int) -> dict[str, str]:
    result = subprocess.run(
        [str(BINARY), "bench-batch", mode, str(size), str(batch)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    rows = list(csv.DictReader(result.stdout.splitlines()))
    if len(rows) != 1:
        raise RuntimeError(f"expected one batch row, got {len(rows)}")
    return rows[0]


def run_batch_series(mode: str, size: int, batches: list[int]) -> list[dict[str, str]]:
    result = subprocess.run(
        [
            str(BINARY),
            "bench-batch-series",
            mode,
            str(size),
            *[str(batch) for batch in batches],
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    rows = list(csv.DictReader(result.stdout.splitlines()))
    if len(rows) != len(batches):
        raise RuntimeError(f"expected {len(batches)} batch rows, got {len(rows)}")
    return rows


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()

    sizes = [args.size]
    accelerate_rows = {}
    if "accelerate" in args.matmul_backends:
        compile_gemm(args.gemm_binary)
        accelerate_rows = run_gemm(args.gemm_binary, sizes)
    python_rows = benchmark_python_backends(args.matmul_backends, sizes, seed=20240610)
    gemm = fastest_rows(sizes, accelerate_rows, python_rows)[args.size]
    matmul_s = float(gemm["seconds"])

    fieldnames = [
        "mode",
        "n",
        "batch",
        "fastest_float_backend",
        "float_matmul_s",
        "float_batch_matmul_s",
        "setup_s",
        "commit_s",
        "batch_prove_s",
        "prove_per_claim_s",
        "batch_verify_s",
        "verify_per_claim_s",
        "prove_over_float_batch_matmul",
        "prove_per_claim_over_float_matmul",
        "verified",
    ]
    stdout_writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
    stdout_writer.writeheader()
    sys.stdout.flush()

    output_handle = None
    output_writer = None
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        write_header = not args.append or not args.output.exists() or args.output.stat().st_size == 0
        output_handle = args.output.open("a" if args.append else "w", newline="")
        output_writer = csv.DictWriter(output_handle, fieldnames=fieldnames)
        if write_header:
            output_writer.writeheader()
        output_handle.flush()

    try:
        print(
            f"[structured-batch-vs-gemm] running {args.mode} n={args.size} batches={args.batches}",
            file=sys.stderr,
            flush=True,
        )
        for row in run_batch_series(args.mode, args.size, args.batches):
            batch = int(row["batch"])
            batch_prove_s = float(row["batch_prove_s"])
            prove_per_claim_s = float(row["prove_per_claim_s"])
            float_batch_matmul_s = matmul_s * batch
            formatted = {
                "mode": row["mode"],
                "n": row["n"],
                "batch": row["batch"],
                "fastest_float_backend": gemm["backend"],
                "float_matmul_s": f"{matmul_s:.12f}",
                "float_batch_matmul_s": f"{float_batch_matmul_s:.12f}",
                "setup_s": row["setup_s"],
                "commit_s": row["commit_s"],
                "batch_prove_s": row["batch_prove_s"],
                "prove_per_claim_s": row["prove_per_claim_s"],
                "batch_verify_s": row["batch_verify_s"],
                "verify_per_claim_s": row["verify_per_claim_s"],
                "prove_over_float_batch_matmul": f"{batch_prove_s / float_batch_matmul_s:.3f}",
                "prove_per_claim_over_float_matmul": f"{prove_per_claim_s / matmul_s:.3f}",
                "verified": row["verified"],
            }
            stdout_writer.writerow(formatted)
            sys.stdout.flush()
            if output_writer is not None and output_handle is not None:
                output_writer.writerow(formatted)
                output_handle.flush()
    finally:
        if output_handle is not None:
            output_handle.close()


if __name__ == "__main__":
    main()
