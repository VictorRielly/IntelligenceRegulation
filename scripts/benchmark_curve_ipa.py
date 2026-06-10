#!/usr/bin/env python3
"""Build and benchmark the BLS12-381 production-curve IPA primitive."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
CRATE = REPO_ROOT / "zkmatrix-rs"
BINARY = CRATE / "target" / "release" / "curve_ipa"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lengths",
        type=int,
        nargs="+",
        default=[1024, 4096, 16384, 65536],
        help="power-of-two vector lengths to benchmark",
    )
    parser.add_argument(
        "--structured",
        action="store_true",
        help="benchmark the Section 3 structured-SRS/KZG accelerated verifier",
    )
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def build() -> None:
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "curve_ipa"],
        cwd=CRATE,
        check=True,
    )
    subprocess.run([str(BINARY), "self-test"], check=True)


def main() -> None:
    args = parse_args()
    if not args.no_build:
        build()
    subprocess.run(
        [
            str(BINARY),
            "bench-structured" if args.structured else "bench",
            *[str(length) for length in args.lengths],
        ],
        check=True,
    )


if __name__ == "__main__":
    main()
