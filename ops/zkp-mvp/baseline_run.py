#!/usr/bin/env python3
"""Retain a full twelve-block SYNTHETIC GPU diagnostic, never an 8B result."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import sys

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import zk60_private_stack_benchmark as bench
SRC = REPO / "ops/zkp-mvp/candidate"
OUT = REPO / "results/zk60_mvp_20260929/baseline-stack-gpu"
TEST = "private_block::run_tests::private_run_125m_twelve_blocks"
ENV = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
ENV.update(CUDA_ROOT="/home/victor/cuda-root", RAYON_NUM_THREADS="2", HL_GPU="1", HL_GPU_REQUIRED="1",
           HL_GPU_CHUNK_ROWS="128", HL_ZK_CHUNK="force", HL_PB_WEIGHTS="dense", HL_PB_TIMING="1",
           MALLOC_MMAP_THRESHOLD_="131072", LD_LIBRARY_PATH="/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib")


def sha(path):
    return bench.sha(path)


def main():
    global OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT)
    OUT = parser.parse_args().output.resolve()
    OUT.mkdir(parents=True, exist_ok=False)
    (OUT / "receipt").mkdir()
    bins = [p for p in (SRC / "hashline/target/release/deps").glob("hashline-*") if p.is_file() and os.access(p, os.X_OK) and not p.name.endswith(".d")]
    if len(bins) != 1:
        raise ValueError(f"ambiguous library executable: {bins}")
    binary = bins[0]
    command = [str(binary), "--ignored", "--exact", TEST, "--nocapture", "--test-threads=1"]
    report = {"state": "preparing-guarded-run", "scope": "synthetic dense 12-block 125M geometry",
              "trained_checkpoint": False, "complete_8b_proof": False, "privacy_accepted": False,
              "tokens_counted_once": 512, "blocks": 12, "command": command,
              "binary_sha256": sha(binary), "fresh_process_verification": False,
              "includes_native_test_oracles": True, "shared_host": True, "samples": 1,
              "steps": [], "runner_process": bench.process_identity(os.getpid()),
              "source_hashes": bench.source_hashes(SRC)}
    report_path = OUT / "report.json"
    def save():
        bench.atomic_write(report_path, json.dumps(report, indent=2) + "\n")
    save()
    sampler = bench.GpuSampler()
    handlers = {sig: signal.signal(sig, bench.interrupt_run)
                for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        ENV["HL_PB_RUN_DIR"] = str(OUT / "receipt")
        sampler.thread.start()
        try:
            row, log = bench.run_step("run", command, output=OUT, source=SRC / "hashline",
                                       env=ENV, timeout=1200, report=report, save=save,
                                       guard_class="gpu")
        finally:
            sampler.stop.set()
            sampler.thread.join(timeout=4)
            bench.atomic_write(OUT / "gpu-samples.json", json.dumps(sampler.samples, indent=2) + "\n")
        code = row["exit_code"]
        body = log.read_text()
        keyed = body.count("[ZK60] keyed gpu zk commit accepted")
        match = re.search(r"RESULT: prove ([0-9.]+) s .*verify by streaming ([0-9.]+) s, receipt (\d+) B", body)
        native_peak = row["guard_result"].get("peak_vram_mib")
        passed = (code == 0 and "1 passed; 0 failed" in body and match is not None
                  and keyed >= 24 and "gpu zk commit declined" not in body and native_peak is not None)
        if sha(binary) != report["binary_sha256"] or bench.source_hashes(SRC) != report["source_hashes"]:
            raise ValueError("native source or binary changed during baseline measurement")
        elapsed = row.get("process_wall_seconds")
        report.update(state="passed" if passed else "failed", current=None,
                      exit_code=code, workload_wall_seconds=elapsed,
                      accepted_keyed_commits=keyed, log_sha256=sha(log),
                      gpu_samples=len(sampler.samples), sampled_vram_peak_mib=native_peak,
                      gpu_samples_scope="enclosing guard call including queue and drain; not workload peak evidence",
                      guard_wall_seconds_including_queue_and_drain=row["guard_wall_seconds_including_queue_and_drain"])
        if passed:
            report.update(prove_run_seconds=float(match[1]), verify_in_process_seconds=float(match[2]),
                          receipt_bytes=int(match[3]), diagnostic_positions_per_workload_second=512 / elapsed,
                          target_ratio=50 * elapsed / 512, target_met=False)
        save()
        bench.atomic_write(OUT / "run.done", "0\n" if passed else "1\n")
    except (Exception, KeyboardInterrupt) as exc:
        report.update(state="interrupted" if isinstance(exc, (bench.InterruptedRun, KeyboardInterrupt)) else "failed",
                      failed_step=report.get("current"), current=None, error=str(exc))
        save()
        bench.atomic_write(OUT / "run.done", "1\n")
        raise
    finally:
        for sig, handler in handlers.items():
            signal.signal(sig, handler)
    print(json.dumps(report, indent=2), flush=True)
    if not passed:
        print(body[-4000:], flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
