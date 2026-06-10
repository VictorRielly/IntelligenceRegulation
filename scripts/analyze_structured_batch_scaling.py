#!/usr/bin/env python3
"""Fit current batched zkMatrix timings to a fixed + marginal cost model."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", type=Path)
    parser.add_argument("--project-batch", type=int, default=1024)
    parser.add_argument("--output", type=Path, default=None)
    return parser.parse_args()


def fit_line(xs: list[float], ys: list[float]) -> tuple[float, float]:
    n = len(xs)
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    denom = sum((x - mean_x) ** 2 for x in xs)
    if denom == 0.0:
        raise ValueError("need at least two distinct batch sizes")
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / denom
    intercept = mean_y - slope * mean_x
    return intercept, slope


def main() -> None:
    args = parse_args()
    rows = list(csv.DictReader(args.csv_path.open()))
    if len(rows) < 2:
        raise SystemExit("need at least two rows to fit scaling")

    batches = [float(row["batch"]) for row in rows]
    prove_times = [float(row["batch_prove_s"]) for row in rows]
    verify_times = [float(row["batch_verify_s"]) for row in rows]
    float_matmul_s = float(rows[0]["float_matmul_s"])

    prove_fixed, prove_marginal = fit_line(batches, prove_times)
    verify_fixed, verify_marginal = fit_line(batches, verify_times)
    projected_prove = prove_fixed + prove_marginal * args.project_batch
    projected_verify = verify_fixed + verify_marginal * args.project_batch
    projected_float = float_matmul_s * args.project_batch
    crossover_batch = None
    denom = prove_marginal - float_matmul_s
    if denom < 0.0:
        crossover_batch = prove_fixed / -denom

    lines = [
        f"source_csv,{args.csv_path}",
        f"rows,{len(rows)}",
        f"float_matmul_s,{float_matmul_s:.12f}",
        f"prove_fixed_s,{prove_fixed:.9f}",
        f"prove_marginal_s_per_claim,{prove_marginal:.9f}",
        f"verify_fixed_s,{verify_fixed:.9f}",
        f"verify_marginal_s_per_claim,{verify_marginal:.9f}",
        f"project_batch,{args.project_batch}",
        f"projected_prove_s,{projected_prove:.9f}",
        f"projected_prove_per_claim_s,{projected_prove / args.project_batch:.9f}",
        f"projected_verify_s,{projected_verify:.9f}",
        f"projected_float_batch_s,{projected_float:.9f}",
        f"projected_prove_over_float_batch,{projected_prove / projected_float:.3f}",
    ]
    if crossover_batch is None:
        lines.append("crossover_batch,none_with_positive_marginal_gap")
    else:
        lines.append(f"crossover_batch,{crossover_batch:.3f}")

    text = "\n".join(lines) + "\n"
    sys.stdout.write(text)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)


if __name__ == "__main__":
    main()
