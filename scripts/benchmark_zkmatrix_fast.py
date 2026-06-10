#!/usr/bin/env python3
"""Build and run the optimized C zkMatrix backend."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE = REPO_ROOT / "zk_matrix_fast" / "zk_matrix_fast.c"
DEFAULT_BINARY = Path("/private/tmp/zkmatrix_fast")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["core", "zk", "both"], default="zk")
    parser.add_argument("--sizes", type=int, nargs="+", default=[64, 128, 256, 512, 1024])
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def build(binary: Path) -> None:
    cmd = [
        "clang",
        "-O3",
        "-mcpu=apple-m1",
        "-std=c11",
        str(SOURCE),
        "-o",
        str(binary),
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError:
        fallback = ["clang", "-O3", "-std=c11", str(SOURCE), "-o", str(binary)]
        subprocess.run(fallback, check=True)


def run(binary: Path, mode: str, sizes: list[int]) -> None:
    cmd = [str(binary), "bench", mode, *[str(size) for size in sizes]]
    subprocess.run(cmd, check=True)


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build(args.binary)
        subprocess.run([str(args.binary), "self-test"], check=True)
    modes = ["core", "zk"] if args.mode == "both" else [args.mode]
    for mode in modes:
        run(args.binary, mode, args.sizes)


if __name__ == "__main__":
    main()
