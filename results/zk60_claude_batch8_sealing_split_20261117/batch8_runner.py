#!/usr/bin/env python3
"""Batch 8 runner: guarded `serve1` leaves of the Batch 7 harness, with (a) an optional /usr/bin/sample
attached to the test process, (b) a 20 ms poll of the process's page-fault / user / system counters,
(c) a timestamped tail of the test's log, (d) the GPU trace compressed outside the repository.

usage: batch8_runner.py <label>:<view 1|0>:<sample 0|1> [more specs ...]

The leaf command, the environment and the guard arguments are those of run_batch7_guarded.py:
  leaf = the test binary --ignored --exact --nocapture private_block::run::fork::tests::a22::a22_stream_ab
  env  = lines 903-915 (HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24
         HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32 HL_A22_AB_PASSES=6 HL_A22_AB=serve1 HL_A27_GPU_TRACE=<prefix>)
  guard = class gpu, --need-gib 36 --cap-gib 48 --max-secs 420 (arms table, line 871), default poll, python3 -B.
Added by this batch only: --wait-secs 21600 (the guard waits for the heavy lock, another agent's build may hold it),
HL_GPU_WITNESS_VIEW=0 in the B arms, the sampler and the counter poll.
"""
from __future__ import annotations

import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import procpoll  # noqa: E402

ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
OUT = Path(__file__).resolve().parent
GUARD = ROOT / "scripts/zk60_resource_guard.py"
DEPS = ROOT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps"
BIN = DEPS / "hashline-a90b6cf7715dc2a7"
BIN_SHA = "aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11"
ART = Path("/Users/victorrielly/zk60-artifacts/batch8_traces_20261117")
SCRATCH = Path(__import__("os").environ.get("TMPDIR", "/tmp")) / "zk60_batch8_scratch"  # was a session-specific scratch path during the runs
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
SAMPLE_INTERVAL_MS = 2
SAMPLE_SECS = 30


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def ds4() -> list[str]:
    cp = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True)
    if cp.returncode != 0:
        return []
    return [l.strip() for l in cp.stdout.splitlines() if l.strip() and "pgrep" not in l and "batch8_runner" not in l]


def find_pid() -> int | None:
    cp = subprocess.run(["ps", "-axo", "pid=,command="], capture_output=True, text=True)
    for line in cp.stdout.splitlines():
        line = line.strip()
        pid_s, _, cmd = line.partition(" ")
        if cmd.startswith(str(BIN) + " ") and TEST in cmd:
            return int(pid_s)
    return None


def run_leaf(label: str, view: bool, sample: bool) -> dict:
    if Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD exists")
    if sha256_file(BIN) != BIN_SHA:
        raise SystemExit("ABORT: binary hash differs")
    log = OUT / f"{label}.log"
    gj = OUT / f"{label}.guard.json"
    done = SCRATCH / f"{label}.done"
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    trace_prefix = SCRATCH / f"trace_{label}"
    for p in SCRATCH.glob(f"trace_{label}.*"):
        p.unlink()
    pre_ds4 = ds4()
    st = subprocess.run([sys.executable, "-B", str(GUARD), "status"], capture_output=True, text=True).stdout
    (OUT / f"{label}.guard_status_pre.txt").write_text(st)
    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(
        {
            "HL_GPU": "1",
            "HL_GPU_REQUIRED": "1",
            "HL_PB_ORACLE": "0",
            "HL_METAL_TIMING": "0",
            "HL_D55_PROFILE": "W16R2_8B_T128_H24",
            "HL_D55_L": "32",
            "HL_D55_WORKERS": "6",
            "HL_A19_BUDGET_GIB": "32",
            "HL_A22_AB_PASSES": "6",
            "HL_A22_AB": "serve1",
            "HL_A27_GPU_TRACE": str(trace_prefix),
        }
    )
    if not view:
        env["HL_GPU_WITNESS_VIEW"] = "0"
    else:
        env.pop("HL_GPU_WITNESS_VIEW", None)
    cmd = [
        sys.executable, "-B", str(GUARD), "run", "--class", "gpu", "--label", label,
        "--need-gib", "36", "--cap-gib", "48", "--max-secs", "420", "--wait-secs", "21600",
        "--log", str(log), "--done", str(done), "--result-json", str(gj), "--",
        str(BIN), "--ignored", "--exact", "--nocapture", TEST,
    ]
    t_launch = time.monotonic()
    t_launch_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    g = subprocess.Popen(cmd, cwd=str(ROOT), env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pid = None
    series: list[tuple] = []
    lines: list[tuple[float, str]] = []  # (t, line)
    pos = 0
    carry = ""
    sampler = None
    sample_file = ART / f"sample_{label}.txt"
    t_sample = None
    last_find = 0.0
    child_first_seen = None
    while g.poll() is None:
        now = time.monotonic()
        if pid is None and now - last_find > 0.5:
            last_find = now
            pid = find_pid()
            if pid is not None:
                child_first_seen = now
        if pid is not None:
            r = procpoll.read(pid)
            if r is not None:
                series.append(r)
        if log.exists():
            sz = log.stat().st_size
            if sz > pos:
                with log.open("rb") as f:
                    f.seek(pos)
                    chunk = f.read(sz - pos)
                pos = sz
                t = time.monotonic()
                carry += chunk.decode("utf-8", "replace")
                *full, carry = carry.split("\n")
                for ln in full:
                    lines.append((t, ln))
                    if sample and sampler is None and pid is not None and re.search(r"\[serve1\] pass 1 request 0:", ln):
                        sample_file.unlink(missing_ok=True)
                        t_sample = time.monotonic()
                        sampler = subprocess.Popen(
                            ["/usr/bin/sample", str(pid), str(SAMPLE_SECS), str(SAMPLE_INTERVAL_MS), "-mayDie", "-file", str(sample_file)],
                            stdin=subprocess.DEVNULL, stdout=open(OUT / f"{label}.sample.out", "w"), stderr=subprocess.STDOUT,
                        )
        time.sleep(0.02)
    t_end = time.monotonic()
    rc = g.returncode
    if sampler is not None:
        try:
            sampler.wait(timeout=120)
        except subprocess.TimeoutExpired:
            pass
    post_ds4 = ds4()
    rec = json.loads(gj.read_text()) if gj.exists() else {}
    # counter series and log timestamps
    with gzip.open(OUT / f"{label}.counters.tsv.gz", "wt") as f:
        f.write("t_mono\tfaults\tpageins\tcow\tuser_s\tsys_s\trss_bytes\tthreads\n")
        for r in series:
            f.write("\t".join(f"{x:.6f}" if isinstance(x, float) else str(x) for x in r) + "\n")
    with (OUT / f"{label}.linetimes.tsv").open("w") as f:
        for t, ln in lines:
            if ln.startswith("A22-AB"):
                f.write(f"{t:.4f}\t{ln[:160]}\n")
    # trace
    tr = sorted(SCRATCH.glob(f"trace_{label}.*.tsv"))
    trace_meta = None
    if tr:
        raw = tr[0]
        gz = ART / f"{label}.trace.tsv.gz"
        with raw.open("rb") as fi, gzip.open(gz, "wb", compresslevel=6) as fo:
            shutil.copyfileobj(fi, fo)
        trace_meta = {"gz": str(gz), "gz_bytes": gz.stat().st_size, "gz_sha256": sha256_file(gz), "raw_bytes": raw.stat().st_size, "raw_sha256": sha256_file(raw)}
    sample_meta = None
    if sample_file.exists():
        sample_meta = {"path": str(sample_file), "bytes": sample_file.stat().st_size, "sha256": sha256_file(sample_file), "interval_ms": SAMPLE_INTERVAL_MS, "duration_s": SAMPLE_SECS, "t_attach_mono": t_sample}
    meta = {
        "label": label,
        "view": view,
        "sampled": sample,
        "launch_utc": t_launch_utc,
        "t_launch_mono": t_launch,
        "t_end_mono": t_end,
        "child_first_seen_mono": child_first_seen,
        "pid": pid,
        "guard_rc": rc,
        "guard_run_id": rec.get("run_id"),
        "guard_waited_s": rec.get("waited_s"),
        "guard_wall_s": rec.get("guard_wall_s"),
        "child_wall_seconds": rec.get("child_wall_seconds"),
        "peak_rss_gib": rec.get("peak_rss_gib"),
        "peak_vram_mib": rec.get("peak_vram_mib"),
        "ds4_bench_pre": pre_ds4,
        "ds4_bench_post": post_ds4,
        "trace": trace_meta,
        "sample": sample_meta,
        "counter_rows": len(series),
    }
    (OUT / f"{label}.meta.json").write_text(json.dumps(meta, indent=1) + "\n")
    print(f"[batch8] {label}: rc={rc} run_id={rec.get('run_id')} waited={rec.get('waited_s')} wall={rec.get('child_wall_seconds')} ds4 pre={bool(pre_ds4)} post={bool(post_ds4)} rows={len(series)}", flush=True)
    return meta


def main() -> None:
    ART.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(sys.argv[1:]):
        label, view, samp = spec.split(":")
        if i:
            time.sleep(12)
        run_leaf(label, view == "1", samp == "1")


if __name__ == "__main__":
    main()
