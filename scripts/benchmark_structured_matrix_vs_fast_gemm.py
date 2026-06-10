#!/usr/bin/env python3
"""Compare the BLS12-381 structured matrix proof with the fastest local SGEMM."""

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
    parser.add_argument("--sizes", type=int, nargs="+", default=[32, 64, 128, 256])
    parser.add_argument("--mode", choices=["core", "zk", "both"], default="zk")
    parser.add_argument("--no-build", action="store_true")
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
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="optional CSV file to write benchmark results",
    )
    return parser.parse_args()


def build() -> None:
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "structured_matrix"],
        cwd=CRATE,
        check=True,
    )
    subprocess.run([str(BINARY), "self-test"], check=True)


def run_structured(mode: str, sizes: list[int]) -> list[dict[str, str]]:
    result = subprocess.run(
        [str(BINARY), "bench", mode, *[str(size) for size in sizes]],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return list(csv.DictReader(result.stdout.splitlines()))


def format_row(row: dict[str, str], gemm_rows: dict[int, dict[str, object]]) -> dict[str, object]:
    n = int(row["n"])
    gemm = gemm_rows[n]
    prove_s = float(row["prove_s"])
    matmul_s = float(gemm["seconds"])
    return {
        "mode": row["mode"],
        "n": n,
        "fastest_float_backend": gemm["backend"],
        "float_matmul_s": f"{matmul_s:.12f}",
        "float_gflops": f"{float(gemm['gflops']):.3f}",
        "setup_s": f"{float(row['setup_s']):.9f}",
        "commit_s": f"{float(row['commit_s']):.9f}",
        "prove_s": f"{prove_s:.9f}",
        "verify_s": f"{float(row['verify_s']):.9f}",
        "proof_over_float_matmul": f"{prove_s / matmul_s:.3f}",
        "verified": row["verified"],
    }


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()

    accelerate_rows = {}
    if "accelerate" in args.matmul_backends:
        compile_gemm(args.gemm_binary)
        accelerate_rows = run_gemm(args.gemm_binary, args.sizes)
    python_rows = benchmark_python_backends(
        args.matmul_backends, args.sizes, seed=20240610
    )
    gemm_rows = fastest_rows(args.sizes, accelerate_rows, python_rows)

    fieldnames = [
        "mode",
        "n",
        "fastest_float_backend",
        "float_matmul_s",
        "float_gflops",
        "setup_s",
        "commit_s",
        "prove_s",
        "verify_s",
        "proof_over_float_matmul",
        "verified",
    ]

    stdout_writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
    stdout_writer.writeheader()
    sys.stdout.flush()
    output_handle = None
    output_writer = None
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        output_handle = args.output.open("w", newline="")
        output_writer = csv.DictWriter(output_handle, fieldnames=fieldnames)
        output_writer.writeheader()
        output_handle.flush()

    try:
        for size in args.sizes:
            print(
                f"[structured-vs-gemm] running {args.mode} proof for n={size}",
                file=sys.stderr,
                flush=True,
            )
            proof_rows = run_structured(args.mode, [size])
            for row in proof_rows:
                formatted = format_row(row, gemm_rows)
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
