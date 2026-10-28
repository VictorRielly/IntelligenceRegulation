#!/usr/bin/env python3
"""Measure and independently verify the registered SYNTHETIC native stack.

This deliberately cannot produce a trained-8B throughput claim. Verification
and GPU dispatch are mandatory gates before any diagnostic rate is published.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time

REPO = Path(__file__).resolve().parents[1]
DEFAULT_SRC = REPO / "ops/zkp-mvp/candidate"
LD = "/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib"
GUARD = REPO / "scripts/zk60_resource_guard.py"


def atomic_write(path: Path, body: str) -> None:
    """Keep the preceding complete record if interrupted during an update."""
    fd, name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(body)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def process_identity(pid: int) -> dict:
    """PID alone can be reused and is not meaningful across reboot/namespaces."""
    return {"pid": pid,
            "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
            "pid_namespace": os.readlink("/proc/self/ns/pid"),
            "start_ticks": int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19])}


class InterruptedRun(Exception):
    pass


def interrupt_run(signum, _frame):
    raise InterruptedRun(f"received signal {signum}")


def run_step(name: str, command: list[str], *, output: Path, source: Path,
             env: dict, timeout: float, report: dict, save,
             guard_class: str | None = None, small_shape: bool = False) -> tuple[dict, Path]:
    """Reap the owned process group before releasing the caller's heavy lock."""
    log = output / (name + ".log")
    row = {"name": name, "command": command, "state": "starting"}
    argv = command
    guard_result = output / (name + ".guard.json")
    if guard_class is not None:
        guard_pin = sha(GUARD)
        if report.setdefault("guard_sha256", guard_pin) != guard_pin:
            raise ValueError("guard source changed between commands; review the new release before continuing")
        argv = [sys.executable, str(GUARD), "run", "--class", guard_class,
                "--label", "stack-" + name, "--wait-secs", "60", "--max-secs", str(timeout),
                "--result-json", str(guard_result)]
        if small_shape:
            argv += ["--need-gib", "1", "--cap-gib", "2"]
        argv += ["--", *command]
        row["guard_command"] = argv
        row["guard_sha256"] = guard_pin
    report["steps"].append(row)
    report.update(state="running", current=name)
    save()
    started = time.monotonic()
    child = None
    try:
        with log.open("w") as stream:
            child = subprocess.Popen(argv, cwd=source, env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, start_new_session=True)
            row.update(state="running", process=process_identity(child.pid))
            save()
            # The guard owns the native timeout and cleanup. An outer hard
            # timeout could kill only the monitor and leave its child alive.
            row["exit_code"] = child.wait(timeout=None if guard_class else timeout)
            row["state"] = "passed" if row["exit_code"] == 0 else "failed"
            if guard_class is not None:
                verdict = json.loads(guard_result.read_text())
                row["guard_result"] = verdict
                if verdict.get("exit") != row["exit_code"]:
                    raise ValueError("guard terminal record differs from its process exit")
                if row["guard_sha256"] != sha(GUARD):
                    raise ValueError("guard source changed during this command")
                if row["exit_code"] in (0, 1) and (verdict.get("child_rc") != row["exit_code"]
                                                   or verdict.get("guard_killed") is not None):
                    raise ValueError("native success/refusal is not established by the guard record")
                wall = verdict.get("child_wall_seconds")
                if row["exit_code"] == 0 and (not isinstance(wall, (float, int))
                                              or isinstance(wall, bool) or not math.isfinite(wall) or wall <= 0):
                    raise ValueError("successful guard result is missing measured child wall time")
                if row["exit_code"] == 0:
                    row["process_wall_seconds"] = wall
    except BaseException as exc:
        state = ("timed_out" if isinstance(exc, subprocess.TimeoutExpired) else
                 "interrupted" if isinstance(exc, (InterruptedRun, KeyboardInterrupt)) else "failed")
        row.update(state=state,
                   error=str(exc))
        if child is not None:
            # Only this Popen-created session is ours to terminate. Kill the
            # whole group even if its leader exited but left a child behind.
            if guard_class:
                # SIGTERM is the guard's cleanup request. Wait for its native
                # child to be reaped and VRAM drained; do not bypass it.
                if child.poll() is None:
                    child.terminate()
            else:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            row["exit_code"] = child.wait()
        raise
    finally:
        enclosing_wall = time.monotonic() - started
        if guard_class is None:
            row["process_wall_seconds"] = enclosing_wall
        else:
            row["guard_wall_seconds_including_queue_and_drain"] = enclosing_wall
        row["log_sha256"] = sha(log) if log.exists() else None
        save()
    print(f"{name}: exit {row['exit_code']}, native wall {row.get('process_wall_seconds')}s", flush=True)
    return row, log


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_hashes(source: Path) -> dict[str, str]:
    return {str(path.relative_to(source)): sha(path)
            for crate in ("hashline", "zkp-core", "private-block-kernel", "private-block-kernel-shaped")
            for path in sorted((source / crate).rglob("*"))
            if path.is_file() and not any(part.startswith("target") for part in path.relative_to(source).parts)
            and path.suffix in (".rs", ".cu", ".toml", ".lock")}


def events(log: Path) -> list[dict]:
    found = []
    for line in log.read_text().splitlines():
        if line.startswith("{"):
            item = json.loads(line)
            if not isinstance(item, dict):
                raise ValueError("driver event is not an object")
            found.append(item)
    return found


def one_event(log: Path, name: str) -> dict:
    rows = [row for row in events(log) if row.get("event") == name]
    if len(rows) != 1:
        raise ValueError(f"expected one {name} event, got {len(rows)}")
    return rows[0]


def validate_result(prove: dict, verify: dict, backend: str, accepted_keyed: int,
                    declined: bool, shape: str, blocks: int) -> int:
    expected_tokens = {"p2": 32, "m125": 512}[shape]
    expected_shape = {"p2": "rung-p2", "m125": "m125"}[shape]
    if prove.get("status") != "accepted_in_process_and_published" or verify.get("status") != "accepted":
        raise ValueError("proof or independent verification was not accepted")
    if prove.get("one_transcript") is not True or prove.get("layers") != blocks or prove.get("shape") != expected_shape:
        raise ValueError("proof does not cover the requested complete stack")
    if prove.get("tokens_counted_once") != expected_tokens or prove.get("tokens") != expected_tokens:
        raise ValueError("proved position count differs from the registered shape")
    if verify.get("tokens") != expected_tokens or verify.get("layers") != blocks:
        raise ValueError("independent verifier coverage differs")
    if prove.get("synthetic") is not True or prove.get("trained_8b_proof") is not False or verify.get("trained_8b_proof") is not False:
        raise ValueError("unexpected trained-model scope from a synthetic runner")
    if prove.get("receipt_bytes") != verify.get("receipt_bytes") or prove.get("policy_sha256") != verify.get("policy_sha256"):
        raise ValueError("verifier artifact/policy identity differs")
    if backend == "gpu" and (declined or accepted_keyed < 2 * blocks + 2):
        raise ValueError("required keyed GPU path declined or did not dispatch for every block")
    if backend == "cpu" and accepted_keyed:
        raise ValueError("CPU comparison dispatched keyed GPU work")
    return expected_tokens


class GpuSampler:
    def __init__(self):
        self.samples = []
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.sample, daemon=True)

    def sample(self):
        start = time.monotonic()
        while not self.stop.is_set():
            try:
                result = subprocess.run(["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu,power.draw", "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3)
                if result.returncode == 0:
                    parts = [part.strip() for part in result.stdout.strip().split(",")]
                    self.samples.append({"elapsed_s": time.monotonic() - start, "name": parts[0],
                                         "used_mib": float(parts[1]), "total_mib": float(parts[2]),
                                         "util_percent": float(parts[3]), "power_w": float(parts[4])})
            except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
                pass
            self.stop.wait(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shape", choices=("p2", "m125"), default="p2")
    parser.add_argument("--blocks", type=int, default=3)
    parser.add_argument("--backend", choices=("gpu", "cpu"), default="gpu")
    parser.add_argument("--controls", action="store_true")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    if not 1 <= args.blocks <= 64 or args.timeout <= 0:
        parser.error("--blocks must be 1..64 and --timeout must be positive")
    output = args.output.resolve()
    source = args.source.resolve()
    binary = source / "hashline/target/release/examples/zk60_private_stack"
    if not binary.is_file():
        parser.error(f"build the stack CLI first: {binary}")
    output.mkdir(parents=True, exist_ok=False)
    before = source_hashes(source)
    report = {"state": "preparing-guarded-run", "scope": "synthetic dense registered transformer stack",
              "backend": args.backend, "blocks": args.blocks, "shape": args.shape,
              "complete_trained_8b_proof": False, "trained_8b_tokens_per_second": None,
              "goal_completed": False, "privacy_accepted": False, "steady_state_tokens_per_second": None,
              "samples": 1, "cold_process": True, "shared_host": True,
              "gpu_scope": "GPU-assisted commitments/openings; witness, sumcheck and verifier retain CPU work",
              "binary_sha256": sha(binary), "source_hashes": before, "steps": [], "controls": [],
              "runner_process": process_identity(os.getpid()), "started_at_unix": time.time()}
    def save():
        report["updated_at_unix"] = time.time()
        atomic_write(output / "report.json", json.dumps(report, indent=2) + "\n")
    save()
    env = {key: value for key, value in os.environ.items() if not key.startswith("HL_")}
    env.update(CUDA_ROOT="/home/victor/cuda-root", LD_LIBRARY_PATH=LD, RAYON_NUM_THREADS="2",
               MALLOC_MMAP_THRESHOLD_="131072", HL_ZK_CHUNK="force", HL_GPU_CHUNK_ROWS="128")
    env.update(HL_GPU="1" if args.backend == "gpu" else "0", HL_GPU_REQUIRED="1" if args.backend == "gpu" else "0")

    def run(name, command, run_env):
        return run_step(name, command, output=output, source=source, env=run_env,
                        timeout=args.timeout, report=report, save=save,
                        guard_class="gpu" if name == "prove" and args.backend == "gpu" else "cpu",
                        small_shape=args.shape == "p2")

    handlers = {sig: signal.signal(sig, interrupt_run) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        artifact = output / "receipt"
        policy = output / "trusted-policy.txt"
        sampler = GpuSampler()
        if args.backend == "gpu":
            sampler.thread.start()
        try:
            prove_row, prove_log = run("prove", [str(binary), "prove", "--shape", args.shape, "--blocks", str(args.blocks),
                                                "--out", str(artifact), "--policy-out", str(policy)], env)
        finally:
            sampler.stop.set()
            if sampler.thread.ident is not None:
                sampler.thread.join(timeout=4)
            atomic_write(output / "gpu-samples.json", json.dumps(sampler.samples, indent=2) + "\n")
        if prove_row["exit_code"]:
            raise ValueError("prover failed; no proved throughput is reported")
        prove = one_event(prove_log, "prove_result")
        policy_digest = sha(policy)
        if policy_digest != prove["policy_sha256"]:
            raise ValueError("saved trusted policy does not match prover identity")
        verify_command = [str(binary), "verify", "--artifact", str(artifact), "--policy", str(policy),
                          "--policy-sha256", policy_digest, "--expect-blocks", str(args.blocks), "--expect-shape", prove["shape"]]
        verify_env = dict(env, HL_GPU="0", HL_GPU_REQUIRED="0")
        verify_row, verify_log = run("fresh-verify", verify_command, verify_env)
        if verify_row["exit_code"]:
            raise ValueError("independent verifier failed; no proved throughput is reported")
        verify = one_event(verify_log, "verify_result")
        body = prove_log.read_text()
        accepted = body.count("[ZK60] keyed gpu zk commit accepted")
        tokens = validate_result(prove, verify, args.backend, accepted,
                                 "gpu zk commit declined" in body or "gpu commit declined" in body,
                                 args.shape, args.blocks)
        native_vram_peak = prove_row["guard_result"].get("peak_vram_mib")
        if args.backend == "gpu" and native_vram_peak is None:
            raise ValueError("GPU telemetry during the native workload is unavailable")
        # All rates are withheld until the actual saved receipt verifies.
        report.update(prove_result=prove, independent_verify_result=verify,
                      independent_verification_passed=True, accepted_keyed_commits=accepted,
                      tokens_counted_once=tokens, workload_wall_seconds=prove_row["process_wall_seconds"],
                      independent_verification_wall_seconds=verify_row["process_wall_seconds"],
                      amortized_diagnostic_positions_per_second=tokens / prove_row["process_wall_seconds"],
                      diagnostic_positions_per_second_including_fresh_verification=tokens / (prove_row["process_wall_seconds"] + verify_row["process_wall_seconds"]),
                      sampled_vram_peak_mib=native_vram_peak,
                      vram_peak_scope="guard device samples during the native child; not an exact allocation peak",
                      gpu_samples_scope="enclosing guard call including admission wait and drain; not workload peak evidence",
                      guard_wall_seconds_including_queue_and_drain=prove_row["guard_wall_seconds_including_queue_and_drain"],
                      rate_clock_includes_inprocess_verification=True,
                      rate_clock_excludes_separate_fresh_verification=True,
                      comparison_target_positions_per_second=50,
                      diagnostic_gap_factor=50 * prove_row["process_wall_seconds"] / tokens)
        save()
        if args.controls:
            controls = [("wrong-policy-pin", verify_command[:6] + ["--policy-sha256", "0" * 64]),
                        ("wrong-layer-count", verify_command[:-4] + ["--expect-blocks", str(args.blocks + 1)]),
                        ("wrong-endpoint-root", verify_command + ["--expect-input-root", "0" * 64])]
            for name, command in controls:
                row, _ = run(name, command, verify_env)
                report["controls"].append({"name": name, "refused": row["exit_code"] == 1})
                if row["exit_code"] != 1:
                    raise ValueError(f"negative control did not refuse: {name}")
            segment = artifact / "segment-000.bin"
            with segment.open("r+b") as stream:
                original = stream.read(1)
                stream.seek(0)
                stream.write(bytes([original[0] ^ 1]))
            try:
                row, _ = run("changed-segment", verify_command, verify_env)
                report["controls"].append({"name": "changed-segment", "refused": row["exit_code"] == 1})
                if row["exit_code"] != 1:
                    raise ValueError("changed-segment control did not refuse")
            finally:
                with segment.open("r+b") as stream:
                    stream.write(original)
            row, _ = run("restored-fresh-verify", verify_command, verify_env)
            if row["exit_code"]:
                raise ValueError("restored receipt no longer verifies")
        if before != source_hashes(source) or report["binary_sha256"] != sha(binary):
            raise ValueError("source or binary changed during the measurement")
        report.update(state="passed", current=None)
        save()
        atomic_write(output / "run.done", "0\n")
        print(json.dumps({key: report[key] for key in ("state", "scope", "tokens_counted_once", "workload_wall_seconds",
                         "independent_verification_wall_seconds", "amortized_diagnostic_positions_per_second",
                         "diagnostic_gap_factor", "complete_trained_8b_proof")}, indent=2))
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        report.update(state="interrupted" if isinstance(exc, (InterruptedRun, KeyboardInterrupt)) else "failed",
                      failed_step=report.get("current"), current=None, error=str(exc))
        save()
        atomic_write(output / "run.done", "1\n")
        raise
    finally:
        for sig, handler in handlers.items():
            signal.signal(sig, handler)


if __name__ == "__main__":
    raise SystemExit(main())
