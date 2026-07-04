"""Head-to-head runtime comparison: pairing track vs lattice track.

Runs both proof systems' native Rust backends on the same machine, same
crate, same rayon thread pool, and streams every result line as it is
produced (stdout is line-buffered and each CSV row is printed the moment
the underlying benchmark emits it).

Experiments:

  A. Dimension scaling, single claim (n x n matrices):
     - lattice pi1 / pi2  (128-bit-target params, q = 2^61 - 1)
     - structured core / zk  (BLS12-381, KZG fast verifier)
     - toy zk  (u64 mock group; protocol-algebra scaling reference only)
  B. Batch scaling at fixed n (t same-shape claims):
     - structured zk  (Algorithm 6 batching: amortizes projections)
     - lattice pi2    (no cross-claim batching in Route Z: linear in t)

Results append to docs/zkmatrix-poc/results/track_comparison/*.csv with
machine metadata alongside. Sequential execution (no concurrent runs) so
the timings do not contaminate each other.

Usage:
  python3 scripts/benchmark_track_comparison.py run [--quick] [--skip-structured-2048]
  python3 scripts/benchmark_track_comparison.py plot
"""

import argparse
import datetime
import os
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CRATE = ROOT / "zkmatrix-rs"
BIN = CRATE / "target" / "release"
OUT = ROOT / "docs" / "zkmatrix-poc" / "results" / "track_comparison"

CARGO_PATH = os.path.expanduser(
    "~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin"
)


def log(message: str) -> None:
    print(message, flush=True)


def build_binaries() -> None:
    env = dict(os.environ)
    env["PATH"] = f"{CARGO_PATH}:{env['PATH']}"
    log("# building release binaries ...")
    subprocess.run(
        ["cargo", "build", "--release"],
        cwd=CRATE,
        env=env,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    log("# build done")


def write_metadata() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cpu = ""
    try:
        for line in open("/proc/cpuinfo"):
            if line.startswith("model name"):
                cpu = line.split(":", 1)[1].strip()
                break
    except OSError:
        cpu = platform.processor()
    commit = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    ).stdout.strip()
    meta = OUT / "metadata.txt"
    with open(meta, "w") as fh:
        fh.write(f"date: {datetime.datetime.now().isoformat()}\n")
        fh.write(f"cpu: {cpu}\n")
        fh.write(f"threads: {os.cpu_count()}\n")
        fh.write(f"platform: {platform.platform()}\n")
        fh.write(f"git commit: {commit}\n")
        fh.write("execution: sequential, one benchmark process at a time\n")
    log(f"# metadata -> {meta}")


def stream_run(tag: str, cmd: list, csv_path: Path) -> None:
    """Run one benchmark binary, echoing every line as it arrives and
    appending data rows (with the header once) to csv_path."""

    log(f"## [{tag}] {' '.join(str(c) for c in cmd)}")
    write_header = not csv_path.exists()
    with open(csv_path, "a") as fh:
        with subprocess.Popen(
            [str(c) for c in cmd],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        ) as proc:
            first_line = True
            for line in proc.stdout:
                line = line.rstrip("\n")
                if not line:
                    continue
                log(f"[{tag}] {line}")
                is_header = first_line and ("," in line and "_s" in line)
                if is_header:
                    if write_header:
                        fh.write(line + "\n")
                        fh.flush()
                        write_header = False
                else:
                    fh.write(line + "\n")
                    fh.flush()
                first_line = False
        if proc.returncode != 0:
            log(f"## [{tag}] exited with {proc.returncode} (continuing)")


def run_all(quick: bool, skip_structured_2048: bool) -> None:
    build_binaries()
    write_metadata()

    lattice_sizes = [64, 128, 256, 512, 1024, 2048]
    structured_sizes = [64, 128, 256, 512, 1024]
    toy_sizes = [64, 128, 256, 512, 1024, 2048, 4096]
    batch_256 = [1, 2, 4, 8, 16, 32]
    batch_1024 = [1, 2, 4, 8]
    if quick:
        lattice_sizes = [64, 128, 256]
        structured_sizes = [64, 128, 256]
        toy_sizes = [64, 256, 1024]
        batch_256 = [1, 2, 4]
        batch_1024 = []

    # --- A: dimension scaling, cheap tracks first so results stream early.
    stream_run(
        "toy-zk",
        [BIN / "zkmatrix-rs", "bench", "zk", *toy_sizes],
        OUT / "toy_scaling.csv",
    )
    stream_run(
        "lattice-pi1",
        [BIN / "lattice_matmul", "bench", "pi1", *lattice_sizes],
        OUT / "lattice_scaling.csv",
    )
    stream_run(
        "lattice-pi2",
        [BIN / "lattice_matmul", "bench", "pi2", *lattice_sizes],
        OUT / "lattice_scaling.csv",
    )

    # --- B: batch scaling (lattice side is fast; run before the long
    # structured jobs so the comparison data streams in early).
    stream_run(
        "lattice-pi2-batch-n256",
        [BIN / "lattice_matmul", "bench-batch", "pi2", 256, *batch_256],
        OUT / "lattice_batch_n256.csv",
    )
    if batch_1024:
        stream_run(
            "lattice-pi2-batch-n1024",
            [BIN / "lattice_matmul", "bench-batch", "pi2", 1024, *batch_1024],
            OUT / "lattice_batch_n1024.csv",
        )

    # --- structured (BLS12-381): per-n SRS setup dominates wall time.
    stream_run(
        "structured",
        [BIN / "structured_matrix", "bench", "both", *structured_sizes],
        OUT / "structured_scaling.csv",
    )
    stream_run(
        "structured-zk-batch-n256",
        [BIN / "structured_matrix", "bench-batch-series", "zk", 256, *batch_256],
        OUT / "structured_batch_n256.csv",
    )
    if batch_1024:
        stream_run(
            "structured-zk-batch-n1024",
            [
                BIN / "structured_matrix",
                "bench-batch-series",
                "zk",
                1024,
                *batch_1024,
            ],
            OUT / "structured_batch_n1024.csv",
        )
    if not skip_structured_2048 and not quick:
        stream_run(
            "structured-n2048",
            [BIN / "structured_matrix", "bench", "both", 2048],
            OUT / "structured_scaling.csv",
        )

    log("# all runs complete")


# ---------------------------------------------------------------------------
# Proof-size accounting for the structured backend (not emitted by the
# binary): compressed G1 = 48 B, scalar = 32 B.


def structured_zk_proof_bytes(n: int) -> int:
    g1, sc = 48, 32

    def ip(length: int) -> int:
        rounds = length.bit_length() - 1
        return 2 * rounds * g1 + 2 * sc + g1  # left/right, finals, KZG witness

    projection = 2 * g1 + 2 * sc + ip(n * n)  # mask commits, blinds, IPA
    product = 4 * g1 + 3 * sc + ip(n)
    return 3 * g1 + 3 * projection + product  # d/ay/by commits + subproofs


def plot_all() -> None:
    import csv as csv_mod

    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    def read_csv(path: Path):
        if not path.exists():
            return []
        with open(path) as fh:
            return list(csv_mod.DictReader(fh))

    lattice = read_csv(OUT / "lattice_scaling.csv")
    structured = read_csv(OUT / "structured_scaling.csv")
    toy = read_csv(OUT / "toy_scaling.csv")

    # Validated 6-slot categorical palette (dataviz reference order; worst
    # adjacent CVD dE 24.2, light surface). Aqua/yellow sit below 3:1
    # contrast: relief comes from the data tables in the write-up.
    palette = {
        "structured-core": "#2a78d6",
        "structured-zk": "#1baf7a",
        "lattice-pi1": "#eda100",
        "lattice-pi2": "#008300",
        "toy-zk": "#4a3aa7",
        "matmul": "#e34948",
    }

    def series(rows, key, xkey="n", filt=None):
        out = {}
        for row in rows:
            if filt and not filt(row):
                continue
            try:
                out[int(row[xkey])] = float(row[key])
            except (KeyError, ValueError):
                continue
        xs = sorted(out)
        return xs, [out[x] for x in xs]

    def style(ax, title, xlabel, ylabel):
        ax.set_title(title, fontsize=11, loc="left")
        ax.set_xlabel(xlabel, fontsize=9)
        ax.set_ylabel(ylabel, fontsize=9)
        ax.grid(True, which="major", linewidth=0.4, alpha=0.4)
        ax.tick_params(labelsize=8)
        for spine in ("top", "right"):
            ax.spines[spine].set_visible(False)

    # --- Plot 1: prover time vs n.
    fig, ax = plt.subplots(figsize=(7.2, 4.6), dpi=150)
    for label, rows, key, filt in [
        ("structured-core", structured, "prove_s", lambda r: r["mode"] == "core"),
        ("structured-zk", structured, "prove_s", lambda r: r["mode"] == "zk"),
        ("lattice-pi1", lattice, "prove_s", lambda r: r["proto"] == "pi1"),
        ("lattice-pi2", lattice, "prove_s", lambda r: r["proto"] == "pi2"),
        ("toy-zk", toy, "prove_s", None),
        ("matmul", lattice, "matmul_s", lambda r: r["proto"] == "pi1"),
    ]:
        xs, ys = series(rows, key, filt=filt)
        if xs:
            ax.plot(
                xs,
                ys,
                marker="o",
                markersize=5,
                linewidth=1.8,
                label=label if label != "matmul" else "mod-q matmul (baseline)",
                color=palette[label],
                linestyle="--" if label in ("toy-zk", "matmul") else "-",
            )
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    style(ax, "Prover time vs matrix dimension (single claim)", "n", "seconds")
    ax.legend(fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "prove_vs_n.png")
    plt.close(fig)

    # --- Plot 2: verifier time vs n.
    fig, ax = plt.subplots(figsize=(7.2, 4.6), dpi=150)
    for label, rows, filt in [
        ("structured-core", structured, lambda r: r["mode"] == "core"),
        ("structured-zk", structured, lambda r: r["mode"] == "zk"),
        ("lattice-pi1", lattice, lambda r: r["proto"] == "pi1"),
        ("lattice-pi2", lattice, lambda r: r["proto"] == "pi2"),
    ]:
        xs, ys = series(rows, "verify_s", filt=filt)
        if xs:
            ax.plot(
                xs,
                ys,
                marker="o",
                markersize=5,
                linewidth=1.8,
                label=label,
                color=palette[label],
            )
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    style(ax, "Verifier time vs matrix dimension (single claim)", "n", "seconds")
    ax.legend(fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "verify_vs_n.png")
    plt.close(fig)

    # --- Plot 3: per-claim prover time vs batch size.
    batch_sizes = [
        size
        for size in (256, 1024, 2048)
        if (OUT / f"structured_batch_n{size}.csv").exists()
        or (OUT / f"lattice_batch_n{size}.csv").exists()
    ]
    fig, axes = plt.subplots(
        1, len(batch_sizes), figsize=(4.8 * len(batch_sizes), 4.2), dpi=150
    )
    if len(batch_sizes) == 1:
        axes = [axes]
    for ax, size in zip(axes, batch_sizes):
        s_rows = read_csv(OUT / f"structured_batch_n{size}.csv")
        l_rows = read_csv(OUT / f"lattice_batch_n{size}.csv")
        xs, ys = series(s_rows, "prove_per_claim_s", xkey="batch")
        if xs:
            ax.plot(
                xs,
                ys,
                marker="o",
                markersize=5,
                linewidth=1.8,
                label="structured-zk (Alg. 6 batch)",
                color=palette["structured-zk"],
            )
        xs, ys = series(l_rows, "prove_per_claim_s", xkey="batch")
        if xs:
            ax.plot(
                xs,
                ys,
                marker="s",
                markersize=5,
                linewidth=1.8,
                label="lattice-pi2 (independent proofs)",
                color=palette["lattice-pi2"],
            )
        ax.set_xscale("log", base=2)
        ax.set_yscale("log")
        style(
            ax,
            f"Per-claim prover time vs batch size (n = {size})",
            "batch size t",
            "seconds per claim",
        )
        ax.legend(fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "batch_amortization.png")
    plt.close(fig)

    # --- Plot 4: proof size vs n (lattice measured, structured analytic).
    fig, ax = plt.subplots(figsize=(7.2, 4.6), dpi=150)
    for proto, color in (("pi1", palette["lattice-pi1"]), ("pi2", palette["lattice-pi2"])):
        xs, ys = series(
            lattice, "proof_bytes", filt=lambda r, p=proto: r["proto"] == p
        )
        if xs:
            ax.plot(
                xs,
                [y / 1e6 for y in ys],
                marker="o",
                markersize=5,
                linewidth=1.8,
                label=f"lattice-{proto} (measured accounting)",
                color=color,
            )
    xs = sorted({int(r["n"]) for r in structured})
    if xs:
        ax.plot(
            xs,
            [structured_zk_proof_bytes(n) / 1e6 for n in xs],
            marker="o",
            markersize=5,
            linewidth=1.8,
            label="structured-zk (analytic, 48B G1)",
            color=palette["structured-zk"],
        )
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    style(ax, "Proof size vs matrix dimension", "n", "megabytes")
    ax.legend(fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "proof_size_vs_n.png")
    plt.close(fig)

    log(f"# plots written to {OUT}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["run", "plot"])
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--skip-structured-2048", action="store_true")
    args = parser.parse_args()
    if args.mode == "run":
        run_all(args.quick, args.skip_structured_2048)
    else:
        plot_all()


if __name__ == "__main__":
    main()
