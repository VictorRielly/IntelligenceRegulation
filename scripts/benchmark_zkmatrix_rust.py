#!/usr/bin/env python3
"""Build and benchmark the Rust zkMatrix backend."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
CRATE = REPO_ROOT / "zkmatrix-rs"
BINARY = CRATE / "target" / "release" / "zkmatrix-rs"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["core", "zk", "both"], default="zk")
    parser.add_argument("--sizes", type=int, nargs="+", default=[64, 128, 256, 512, 1024])
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def build() -> None:
    subprocess.run(["cargo", "build", "--release"], cwd=CRATE, check=True)
    subprocess.run([str(BINARY), "self-test"], check=True)


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()
    modes = ["core", "zk"] if args.mode == "both" else [args.mode]
    for mode in modes:
        subprocess.run(
            [str(BINARY), "bench", mode, *[str(size) for size in args.sizes]],
            check=True,
        )


if __name__ == "__main__":
    main()
