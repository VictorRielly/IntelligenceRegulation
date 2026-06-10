#!/usr/bin/env python3
"""Build and benchmark the Rust Section 3 KZG verifier primitive."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
CRATE = REPO_ROOT / "zkmatrix-rs"
BINARY = CRATE / "target" / "release" / "section3_kzg"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--degrees",
        type=int,
        nargs="+",
        default=[1024, 4096, 16384, 65536, 262144],
        help="polynomial degrees / coefficient-vector sizes to benchmark",
    )
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def build() -> None:
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "section3_kzg"],
        cwd=CRATE,
        check=True,
    )
    subprocess.run([str(BINARY), "self-test"], check=True)


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()
    subprocess.run(
        [str(BINARY), "bench", *[str(degree) for degree in args.degrees]],
        check=True,
    )


if __name__ == "__main__":
    main()
