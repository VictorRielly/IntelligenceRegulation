#!/usr/bin/env python3
"""Private CPU phase diagnostics for hashline v3 FFN passes.

run: one real 125M layer, rows 16/32/64, two threads, no weight cache, GPU
disabled, under /tmp/zk-heavy.lock (do not add an outer flock).
analyze: consume runner logs with HASHLINE_PROFILE_RUN completion metadata.
Rank exclusive host wall costs and explicit residuals; never claim the goal.
Output directories are new and owner-only because timing can leak properties
of private data. Profile records contain no tensor values or tensor digests.
"""

import argparse
from collections import defaultdict
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time


WITNESS_PHASES = frozenset((
    "allocation.matmul_output", "read.export_including_buffer_allocation",
    "hash.sha256", "copy.decode_export", "copy.digest_encoding", "copy.narrow_planes",
    "copy.widen_accumulators", "copy.clone_witness", "export_structure_and_checks",
    "activation.public_table", "activation.lookup", "activation.hadamard",
    "matmul.gate", "matmul.up", "matmul.down", "requant.gate", "requant.up",
    "requant.hadamard", "requant.down", "check.ranges", "check.export_planes",
    "deallocation.temporary", "derive_unattributed", "witness_unattributed"))
PROVER_PHASES = frozenset((
    "commit W", "commit A", "helpers + commit H", "matmul g/u", "matmul d",
    "zero-check F", "zero-check D", "pcs openings", "commit A (zk)", "mask commit",
    "helpers + commit H (zk)", "matmul g/u (zk)", "matmul d (zk)",
    "zero-check F (zk)", "zero-check D (zk)", "table zero-check (zk)",
    "zsum + mask open", "pcs openings (zk)"))
PROFILE_KEYS = {"schema", "coverage", "privacy", "layer", "tokens", "d", "f",
                "witness_s", "prove_s", "witness_exclusive", "prover_sequential",
                "device_counters_included", "private_timing_diagnostics"}
CLOCKS = ("witness_s", "prove_s", "serialize_s", "proof_ready_s", "verify_s")
LIMITS = ("CPU FFN-only private timing diagnostics; exported prefill rows, not generation. "
          "Exclusive wall intervals include blocking Rayon work, not summed worker CPU time. "
          "Device counters are excluded. Allocations internal to reads/requantization remain "
          "inside those phases; lazy page faults can occur in later computation. Setup before "
          "the existing proof-ready clock and teardown after verification are outside that clock. "
          "The runner uses no weight cache and the witness loader reads/checks full exported "
          "reference planes even when fewer rows are proved. OS page-cache state is uncontrolled. "
          "Verification uses in-memory proof objects; no standalone decoder is timed. "
          "Single diagnostic runs do not establish p95, establish privacy/security, predict GPU "
          "performance, or guarantee mapping to other proof-parameter/cache profiles.")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def seconds(value):
    try:
        require(type(value) in (int, float) and math.isfinite(value) and value >= 0,
                "invalid or missing nonnegative duration")
    except OverflowError:
        raise ValueError("duration outside finite range") from None
    return value


def records(log, prefix):
    def invalid(_):
        raise ValueError("nonfinite JSON constant")
    try:
        return [json.loads(line[len(prefix):], parse_constant=invalid)
                for line in log.splitlines() if line.startswith(prefix)]
    except (ValueError, TypeError):
        raise ValueError("malformed diagnostic JSON") from None


def residual(enclosing, measured):
    value = enclosing - measured
    require(value >= -0.000001, "phase sum exceeds enclosing clock; overlapping or inconsistent data")
    return max(0.0, value)


def analyze_log(log):
    timings, profiles, runs = (records(log, prefix) for prefix in
                              ("HASHLINE_TIMING ", "HASHLINE_PROFILE ", "HASHLINE_PROFILE_RUN "))
    require(len(timings) == len(runs) == 1, "exactly one timing and runner completion record required")
    timing, run = timings[0], runs[0]
    require(isinstance(timing, dict) and isinstance(run, dict), "diagnostic records must be objects")
    require(type(run.get("exit_code")) is int and run["exit_code"] == 0, "process failed or exit status missing")
    require(timing.get("schema") == 1 and type(timing.get("schema")) is int, "unsupported timing schema")
    require(timing.get("coverage") == "ffn-only", "only FFN coverage is supported")
    require(timing.get("privacy") in ("P0", "P1", "P3"), "unknown privacy mode")
    for key in ("layers", "tokens", "d", "f", "proof_bytes"):
        require(type(timing.get(key)) is int and timing[key] > 0, "invalid shape or proof length")
    require(timing.get("verified") is True and timing.get("serialized") is True,
            "verified serialized proof required")
    require(timing.get("gpu_requested") is False and timing.get("gpu_enabled") is False,
            "CPU profiling only; GPU counters cannot be added to host wall")
    require("--no-verify" not in log and len(re.findall(r"^PASS-V3 ACCEPT", log, re.MULTILINE)) == 1,
            "exactly one verified accepted pass required")
    require(not re.search(r"(?im)^\s*(?:REFUSED:|error:)|panicked at|^PASS-V3 REJECT", log), "failure diagnostic present")
    for key in CLOCKS:
        seconds(timing.get(key))
    require(timing["proof_ready_s"] > 0 and timing["prove_s"] > 0 and timing["verify_s"] > 0,
            "positive measured clocks required")
    require(len(profiles) == timing["layers"], "missing or extra layer profiles")
    phase_cost = defaultdict(float)
    seen, witness_total, prove_total = set(), 0.0, 0.0
    for profile in profiles:
        require(isinstance(profile, dict) and set(profile) == PROFILE_KEYS, "unknown or missing profiling fields")
        require(type(profile["schema"]) is int and profile["schema"] == 1, "unsupported profiling schema")
        for key in ("coverage", "privacy", "tokens", "d", "f"):
            require(type(profile[key]) is type(timing[key]) and profile[key] == timing[key], "mixed shape, coverage or privacy")
        layer = profile["layer"]
        require(type(layer) is int and 0 <= layer < timing["layers"] and layer not in seen, "duplicate or invalid layer number")
        seen.add(layer)
        require(profile["device_counters_included"] is False and profile["private_timing_diagnostics"] is True,
                "exclusive private host timing declaration required")
        witness_total += seconds(profile["witness_s"])
        prove_total += seconds(profile["prove_s"])
        for list_key, allowed, prefix, wall_key in (("witness_exclusive", WITNESS_PHASES, "witness", "witness_s"),
                                                   ("prover_sequential", PROVER_PHASES, "prover", "prove_s")):
            entries = profile[list_key]
            require(isinstance(entries, list) and entries, "missing phase breakdown")
            names, subtotal = set(), 0.0
            for entry in entries:
                keys = {"phase", "seconds", "calls"} if prefix == "witness" else {"phase", "seconds"}
                require(isinstance(entry, dict) and set(entry) == keys, "invalid phase entry")
                name = entry["phase"]
                require(isinstance(name, str) and name in allowed and name not in names, "unknown or duplicate fixed phase label")
                names.add(name)
                if prefix == "witness":
                    require(type(entry["calls"]) is int and entry["calls"] > 0, "invalid phase call count")
                value = seconds(entry["seconds"])
                phase_cost[f"{prefix}.{name}"] += value
                subtotal += value
            phase_cost[f"unattributed.{prefix}"] += residual(profile[wall_key], subtotal)
    require(abs(witness_total - timing["witness_s"]) <= 0.000001 and abs(prove_total - timing["prove_s"]) <= 0.000001,
            "layer totals disagree with pass clocks")
    phase_cost["serialization_hash_and_optional_write"] = timing["serialize_s"]
    phase_cost["unattributed.proof_ready"] = residual(timing["proof_ready_s"], witness_total + prove_total + timing["serialize_s"])
    process_s = seconds(run.get("process_wall_s"))
    outside_s = residual(process_s, timing["proof_ready_s"] + timing["verify_s"])
    unknown_s = sum(value for name, value in phase_cost.items() if "unattributed" in name)
    return {"valid": True, "privacy": timing["privacy"],
            "shape": {key: timing[key] for key in ("layers", "tokens", "d", "f")},
            "randomness": timing.get("randomness", "unknown"), "proof_bytes": timing["proof_bytes"],
            "clock_s": {key: timing[key] for key in CLOCKS}, "process_wall_s": process_s,
            "outside_proof_ready_and_verify_s": outside_s,
            "unknown_within_proof_ready_s": unknown_s,
            "exclusive_ranked": [{"phase": name, "seconds": value, "fraction_of_proof_ready": value / timing["proof_ready_s"]}
                                 for name, value in sorted(phase_cost.items(), key=lambda pair: (-pair[1], pair[0]))],
            "goal_met": False}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def metadata(args):
    tree, binary = args.source_tree.resolve(strict=True), args.binary.resolve(strict=True)
    source_files = sorted((tree / "hashline/src").rglob("*.rs")) + [tree / "hashline/Cargo.toml", tree / "hashline/Cargo.lock", tree / "scripts/hashline_profile.py"]
    require(source_files and all(path.is_file() for path in source_files), "source tree is incomplete")
    entries = {str(path.relative_to(tree)): digest(path) for path in source_files}
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tree, capture_output=True, text=True, check=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=tree, capture_output=True, text=True, check=True).stdout != ""
    cpu = Path("/proc/cpuinfo").read_text()
    model = re.search(r"^model name\s*:\s*(.*)$", cpu, re.MULTILINE)
    return {"recorded_utc": datetime.now(timezone.utc).isoformat(), "source_tree": str(tree),
            "git_head": revision, "git_dirty": dirty, "source_files_sha256": entries,
            "binary": str(binary), "binary_sha256": digest(binary),
            "source_binding_limit": "supplied source snapshot; binary/source correspondence is not attested",
            "cpu": model[1] if model else "unknown", "logical_cpus": os.cpu_count(),
            "platform": f"{os.uname().sysname} {os.uname().release} {os.uname().machine}",
            "prover_threads": 2, "rustflags_environment": os.environ.get("RUSTFLAGS")}


@contextmanager
def heavy_lock():
    print("Waiting for /tmp/zk-heavy.lock", flush=True)
    with open("/tmp/zk-heavy.lock", "a") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")


def collect(args):
    export = args.export.resolve(strict=True)
    dims = re.findall(r"^00 dims (\d+) (\d+) (\d+) (\d+)$", (export / "digests.txt").read_text(), re.MULTILINE)
    require(len(dims) == 1 and tuple(map(int, dims[0][1:3])) == (768, 2048), "runner supports existing 125M dimensions 768/2048 only")
    require(len(args.rows) == len(set(args.rows)) and max(args.rows) <= int(dims[0][0]), "duplicate or unavailable rows")
    require(args.seed is None or 0 <= args.seed < 2**64, "seed must fit u64")
    require(not args.compare_unprofiled or args.privacy == "P0" or args.seed is not None,
            "private on/off byte comparison requires an explicit INSECURE fixture seed")
    write_json(args.out / "workload.json", {
        "export": str(export),
        "export_shape": dict(zip(("tokens", "d", "f", "layers"), map(int, dims[0]))),
        "proved_layers": 1, "proved_rows": args.rows, "privacy": args.privacy,
        "prover_threads": 2, "weight_cache": False, "gpu": False,
        "os_page_cache": "uncontrolled", "full_export_reference_planes_read": True,
        "randomness": "none" if args.privacy == "P0" else "os" if args.seed is None else "deterministic-test",
        "compare_unprofiled": args.compare_unprofiled, "subprocess_timeout_s": 120,
        "proof_parameters": "binary defaults: no proof parameter flags supplied; see source snapshot and raw pass header",
    })
    logs = []
    environment = os.environ.copy()
    environment.pop("HL_GPU", None)
    environment["RAYON_NUM_THREADS"] = "2"
    for rows in args.rows:
        proof = args.out / f"rows-{rows}.proof"
        command = [str(args.binary.resolve()), "pass", "1", str(rows), "--profile", "v3", "--export", str(export),
                   "--threads", "2", "--proof-out", str(proof)]
        if args.privacy != "P0":
            command.append("--p3" if args.privacy == "P3" else "--zk")
        if args.seed is not None:
            command += ["--seed", str(args.seed)]
        logfile = args.out / f"rows-{rows}.log"
        command_record = {"profiled_command": command + ["--phase-profile"], "export": str(export),
                          "environment_enforced": {"HL_GPU": "unset", "RAYON_NUM_THREADS": "2"},
                          "weight_cache": False, "subprocess_timeout_s": 120,
                          "proof_parameters": "binary defaults; no proof parameter overrides"}
        command_path = args.out / f"rows-{rows}-command.json"
        write_json(command_path, command_record)
        print(f"Private diagnostic: {args.privacy}, one 125M layer, {rows} rows", flush=True)
        start = time.perf_counter()
        with logfile.open("w") as destination:
            try:
                result = subprocess.run(command + ["--phase-profile"], env=environment, stdout=destination, stderr=subprocess.STDOUT, check=False, timeout=120)
            except subprocess.TimeoutExpired:
                destination.write("\nHASHLINE_PROFILE_RUN " + json.dumps({"exit_code": "timeout", "process_wall_s": time.perf_counter() - start}) + "\n")
                raise ValueError("one-layer diagnostic exceeded 120 seconds; process terminated") from None
            process_s = time.perf_counter() - start
            destination.write("\nHASHLINE_PROFILE_RUN " + json.dumps({"exit_code": result.returncode, "process_wall_s": process_s}) + "\n")
        row = analyze_log(logfile.read_text())
        require(row["privacy"] == args.privacy and row["shape"] == {"layers": 1, "tokens": rows, "d": 768, "f": 2048}, "binary did not run requested shape/privacy")
        require(proof.is_file() and proof.stat().st_size == row["proof_bytes"], "written proof missing or wrong length")
        command_record["written_proof_sha256"] = digest(proof)
        command_record["written_proof_bytes"] = proof.stat().st_size
        write_json(command_path, command_record)
        if args.compare_unprofiled:
            reference = args.out / f"rows-{rows}-unprofiled.proof"
            reference_command = list(command)
            reference_command[reference_command.index("--proof-out") + 1] = str(reference)
            reference_log = args.out / f"rows-{rows}-unprofiled.log"
            with reference_log.open("w") as destination:
                result = subprocess.run(reference_command, env=environment, stdout=destination, stderr=subprocess.STDOUT, check=False, timeout=120)
            require(result.returncode == 0 and reference.is_file(), "unprofiled reference failed")
            reference_text = reference_log.read_text()
            require(not records(reference_text, "HASHLINE_PROFILE "), "profiling unexpectedly enabled by default")
            reference_timings = records(reference_text, "HASHLINE_TIMING ")
            require(len(reference_timings) == 1 and isinstance(reference_timings[0], dict), "unprofiled reference timing missing or ambiguous")
            reference_timing = reference_timings[0]
            require(reference_timing.get("verified") is True and reference_timing.get("serialized") is True
                    and reference_timing.get("privacy") == row["privacy"]
                    and all(reference_timing.get(key) == value for key, value in row["shape"].items())
                    and reference_timing.get("proof_bytes") == row["proof_bytes"], "unprofiled reference verification/shape mismatch")
            require(digest(reference) == digest(proof), "profiling changed serialized proof bytes")
            command_record["unprofiled_command"] = reference_command
            command_record["unprofiled_proof_sha256"] = digest(reference)
            write_json(command_path, command_record)
            row["profile_on_off_byte_identical"] = True
        row["log"] = logfile.name
        logs.append(row)
        write_json(args.out / "partial.json", logs)
    return logs


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    for action in ("run", "analyze"):
        p = sub.add_parser(action)
        p.add_argument("--source-tree", type=Path, required=True)
        p.add_argument("--binary", type=Path, required=True)
        p.add_argument("--out", type=Path, required=True, help="new private artifact directory")
        if action == "run":
            p.add_argument("--export", type=Path, required=True)
            p.add_argument("--privacy", choices=("P0", "P1", "P3"), required=True)
            p.add_argument("--rows", type=int, nargs="+", choices=(16, 32, 64), default=[16, 32, 64])
            p.add_argument("--seed", type=int, help="INSECURE deterministic correctness fixture only")
            p.add_argument("--compare-unprofiled", action="store_true")
        else:
            p.add_argument("--logs", type=Path, nargs="+", required=True)
    args = parser.parse_args(argv)
    try:
        args.out.mkdir(parents=True, mode=0o700, exist_ok=False)
        manifest = metadata(args)
        write_json(args.out / "manifest.json", manifest)
        if args.action == "run":
            with heavy_lock():
                samples = collect(args)
        else:
            require(len({digest(path) for path in args.logs}) == len(args.logs), "duplicate log contents")
            samples = []
            for number, path in enumerate(args.logs):
                raw = path.read_bytes()
                (args.out / f"source-{number}.log").write_bytes(raw)
                samples.append(dict(analyze_log(raw.decode()), log=f"source-{number}.log"))
        # Never pool privacy modes or shapes into an unlabeled average.
        groups = defaultdict(list)
        for sample in samples:
            shape = sample["shape"]
            key = f"{sample['privacy']}/{shape['layers']}x{shape['tokens']}/d{shape['d']}/f{shape['f']}"
            groups[key].append(sample)
        report = {"schema": 1, "diagnostics_private": True, "clock_limitations": LIMITS,
                  "groups": dict(groups), "goal_met": False}
        write_json(args.out / "summary.json", report)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"hashline profile: {error}\n")
    print(json.dumps({"summary": str(args.out / "summary.json"), "samples": len(samples), "goal_met": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
