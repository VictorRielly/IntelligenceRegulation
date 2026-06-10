#!/usr/bin/env python3
"""Build and benchmark the BLS12-381 structured matrix proof prototype."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
CRATE = REPO_ROOT / "zkmatrix-rs"
BINARY = CRATE / "target" / "release" / "structured_matrix"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sizes", type=int, nargs="+", default=[8, 16, 32])
    parser.add_argument(
        "--mode",
        choices=["core", "zk", "both"],
        default="zk",
        help="proof mode to benchmark",
    )
    parser.add_argument(
        "--batch",
        type=int,
        default=None,
        help="run same-shape batch benchmark for one matrix size",
    )
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def build() -> None:
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "structured_matrix"],
        cwd=CRATE,
        check=True,
    )
    subprocess.run([str(BINARY), "self-test"], check=True)


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()
    if args.batch is None:
        subprocess.run(
            [str(BINARY), "bench", args.mode, *[str(size) for size in args.sizes]],
            check=True,
        )
        return
    if len(args.sizes) != 1:
        raise SystemExit("--batch expects exactly one --sizes value")
    subprocess.run(
        [str(BINARY), "bench-batch", args.mode, str(args.sizes[0]), str(args.batch)],
        check=True,
    )


if __name__ == "__main__":
    main()
