#!/usr/bin/env python3
"""Collect bounded hashline v3 FFN runs or analyze one-pass archived logs.

Examples (run never builds binaries, downloads data, or changes GPU settings):
  python3 scripts/hashline_benchmark.py analyze --privacy P3 --coverage ffn-only \
      --device cpu --cold results/am_r3_8b_p3_cpu.log --out /tmp/p3-history
  python3 scripts/hashline_benchmark.py run --binary hashline/target-gpu/release/hashline \
      --export results/m8b_mistral_v3_export --layers 32 --tokens 512 \
      --privacy P1 --device gpu --warm-runs 20 --out /tmp/p1-baseline

Output directories must be new. Cold means the first fresh process with an empty
weight cache; no OS page-cache flush is attempted. Warm samples are subsequent
fresh processes with the same cache (P3 always recommits weights). The last proof
is retained; every run's raw log and metadata remain. Current coverage cannot
establish the complete private-LLM 60 generated-tokens/s goal.
Measurement eligibility requires exactly one cold sample and at least 20 warm
samples. A GPU initialization report of ON does not prove every phase stayed on
the GPU; the collector rejects reported fallbacks but cannot detect silent ones.
The runner holds /tmp/zk-heavy.lock throughout collection, including preflight.
Detached wrappers must invoke it directly without holding the same lock outside.
"""

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import time


DECIMAL = r"\d+(?:\.\d+)?"
SUMMARY = re.compile(
    r"^PASS(?:-V3)? (ACCEPT|REJECT)(?: \[ZK\])?: (\d+) x (\d+)"
    rf"(?: \(d (\d+) f (\d+)\))?: witness load\+chain ({DECIMAL}) s"
    rf" \| PROVE ({DECIMAL}) s \| VERIFY ({DECIMAL}) s \| proof (\d+) B"
    rf"[^\n]*?\| wall ({DECIMAL}) s$", re.MULTILINE)
HEADER = re.compile(r"^pass(?: \(v3\))?(?: \[[^\n]*?\])?: (\d+) layers x (\d+) tokens[^\n]*", re.MULTILINE)
PROOF = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)", re.MULTILINE)
FIELDS = ("witness_s", "prove_s", "serialize_s", "proof_ready_s", "verify_s")
SCOPE = ("proof_ready_s measures exported input loading/witness computation through "
         "serialized proof readiness, before in-memory verification. Tokens are "
         "prefill rows, not autoregressively generated tokens. Process wall includes "
         "startup, verification and teardown and is reported separately.")


def finite_number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def json_records(log, prefix):
    def reject_constant(value):
        raise ValueError(f"nonfinite JSON number: {value}")
    def number(text, convert):
        value = convert(text)
        return value if finite_number(value) else reject_constant(text)
    return [json.loads(line[len(prefix):], parse_constant=reject_constant,
                       parse_float=lambda text: number(text, float),
                       parse_int=lambda text: number(text, int))
            for line in log.splitlines() if line.startswith(prefix)]


def parse_log(log, *, privacy, coverage, device, exit_code=None, process_wall_s=None):
    """Reject ambiguous/failing logs; never infer an end-to-end clock from PROVE."""
    errors = []
    row = {"privacy": privacy, "coverage": coverage, "device": device,
           "errors": errors, "timing": None, "process_wall_s": process_wall_s}
    try:
        records = json_records(log, "HASHLINE_TIMING ")
        harness = json_records(log, "HASHLINE_BENCHMARK_RUN ")
    except (ValueError, TypeError):
        errors.append("malformed timing or harness JSON")
        records, harness = [], []
    if len(harness) > 1:
        errors.append("multiple harness records")
    elif harness:
        if not isinstance(harness[0], dict):
            errors.append("harness record must be an object")
        else:
            row["gpu_before"] = harness[0].get("gpu_before")
            if exit_code is None:
                exit_code = harness[0].get("exit_code")
            if process_wall_s is None:
                row["process_wall_s"] = harness[0].get("process_wall_s")
    exit_markers = [int(x) for x in re.findall(r"(?:Exit status:|--- exit:)\s*(-?\d+)", log)]
    if exit_code is not None:
        exit_markers.append(exit_code)
    row["exit_code"] = exit_markers[-1] if exit_markers else None
    if any(code != 0 for code in exit_markers):
        errors.append("nonzero process exit")
    if not exit_markers:
        errors.append("process exit status unavailable")
    if any(type(code) is not int for code in exit_markers):
        errors.append("invalid process exit status")
    if row["process_wall_s"] is None:
        elapsed = re.findall(r"Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): ([\d:.]+)", log)
        if len(elapsed) == 1:
            components = elapsed[0].split(":")
            if len(components) in (2, 3):
                try:
                    row["process_wall_s"] = sum(float(value) * 60 ** i for i, value in enumerate(reversed(components)))
                except ValueError:
                    errors.append("invalid external elapsed clock")
    if row["process_wall_s"] is not None and (not finite_number(row["process_wall_s"]) or row["process_wall_s"] <= 0):
        errors.append("invalid process wall clock")
        row["process_wall_s"] = None
    if re.search(r"(?im)^\s*(?:REFUSED:|error:|fatal:|killed\b)|panicked at|ACCEPTED \(BUG\)|^\s*layer\s+\d+:\s*REJECT", log):
        errors.append("failure diagnostic present")
    if "--no-verify" in log:
        errors.append("verification disabled")
    summaries = list(SUMMARY.finditer(log))
    headers = list(HEADER.finditer(log))
    if len(summaries) != 1 or len(headers) != 1:
        errors.append("expected exactly one pass header and one pass summary")
    if len(summaries) == 1:
        status, layers, tokens, d, f, witness, prove, verify, size, wall = summaries[0].groups()
        row.update(layers=int(layers), tokens=int(tokens), d=int(d) if d else None,
                   f=int(f) if f else None, witness_s=float(witness), prove_s=float(prove),
                   verify_s=float(verify), proof_bytes=int(size), legacy_pass_wall_s=float(wall))
        if float(prove) > 0:
            row["prefill_rows_per_prove_second"] = int(tokens) / float(prove)
        if status != "ACCEPT":
            errors.append("pass rejected")
        if float(verify) <= 0:
            # Two decimal rounding may hide a tiny genuine verification; the new
            # high-resolution timing record can establish that case below.
            row["legacy_verification_unmeasured"] = True
        if len(headers) == 1 and tuple(map(int, headers[0].groups())) != (int(layers), int(tokens)):
            errors.append("header and summary shapes disagree")
        dims = set(re.findall(r"\(d (\d+) f (\d+)[;)]", log))
        if len(dims) > 1:
            errors.append("mixed dimension declarations")
        if dims and d is None:
            row["d"], row["f"] = map(int, next(iter(dims)))
    for key in ("layers", "tokens", "d", "f"):
        if type(row.get(key)) is not int or row[key] <= 0:
            errors.append(f"positive {key} required")
    if row.get("tokens", 0) > 0 and row["tokens"] & (row["tokens"] - 1):
        errors.append("token rows must be a power of two")
    for key in ("witness_s", "prove_s", "verify_s", "legacy_pass_wall_s", "prefill_rows_per_prove_second"):
        if key in row and not finite_number(row[key]):
            row[key] = None
            errors.append(f"invalid summary {key}")
    params = set(re.findall(r"log_cols (\d+), inv_rate (\d+), col checks (\d+), threads (\d+)", log))
    row["parameters"] = list(next(iter(params))) if len(params) == 1 else None
    if len(params) != 1:
        errors.append("missing or mixed proof parameters")
    explicit_modes = set(re.findall(r"\b(?:mode|MODE) (P[013])\b", log))
    observed_privacy = next(iter(explicit_modes)) if len(explicit_modes) == 1 else ("P1" if "[ZK" in log else "P0")
    if len(explicit_modes) > 1 or observed_privacy != privacy:
        errors.append("privacy declaration mismatch")
    gpu_labels = re.findall(r"^\s*(gpu: (?:ON|off)[^\n]*)", log, re.MULTILINE)
    row["gpu_label"] = gpu_labels[0] if len(gpu_labels) == 1 else None
    gpu_on = len(gpu_labels) == 1 and gpu_labels[0].startswith("gpu: ON")
    if len(gpu_labels) != 1 or gpu_on != (device == "gpu"):
        errors.append("GPU execution declaration mismatch")
    if device == "gpu" and re.search(r"fallback|falling back|declin(?:ed|ing)|gpu: off", log, re.IGNORECASE):
        errors.append("GPU fallback/off/declined diagnostic present")
    proofs = list(PROOF.finditer(log))
    if len(proofs) != 1 or int(proofs[0][2]) <= 0:
        errors.append("missing or ambiguous serialized proof digest")
    else:
        row["proof_sha256"] = proofs[0][1]
        if row.get("proof_bytes") != int(proofs[0][2]):
            errors.append("serialized proof length mismatch")
    if len(records) != 1:
        errors.append("one HASHLINE_TIMING record required for measured proof readiness")
    elif not isinstance(records[0], dict):
        errors.append("timing record must be an object")
    else:
        timing = records[0]
        row["timing"] = timing
        expected = {"schema": 1, "privacy": privacy, "coverage": coverage,
                    "layers": row.get("layers"), "tokens": row.get("tokens"),
                    "d": row.get("d"), "f": row.get("f"), "verified": True,
                    "serialized": True, "proof_bytes": row.get("proof_bytes"),
                    "gpu_requested": device == "gpu", "gpu_enabled": device == "gpu"}
        for key, value in expected.items():
            if timing.get(key) != value or type(timing.get(key)) is not type(value):
                errors.append(f"timing {key} mismatch")
        for key in FIELDS:
            value = timing.get(key)
            if not finite_number(value) or value < 0:
                errors.append(f"invalid timing {key}")
        if not any(e.startswith("invalid timing") for e in errors):
            if timing["prove_s"] <= 0 or timing["verify_s"] <= 0 or timing["proof_ready_s"] <= 0:
                errors.append("positive prove/verification/proof-ready timings required")
            if timing["proof_ready_s"] + 0.001 < sum(timing[k] for k in ("witness_s", "prove_s", "serialize_s")):
                errors.append("proof-ready clock excludes required phases")
            for key in ("witness_s", "prove_s", "verify_s"):
                if finite_number(row.get(key)) and abs(row[key] - timing[key]) > 0.011:
                    errors.append(f"timing {key} disagrees with summary")
            row["prefill_rows_per_proof_ready_second"] = row.get("tokens", 0) / timing["proof_ready_s"] if timing["proof_ready_s"] > 0 else None
            if not finite_number(row["prefill_rows_per_proof_ready_second"]):
                row["prefill_rows_per_proof_ready_second"] = None
                errors.append("invalid throughput")
        if timing.get("randomness") != ("none" if privacy == "P0" else "os"):
            errors.append("production randomness unavailable (deterministic seeds are fixtures)")
    row["measurement_eligible"] = not errors
    row["goal_met"] = False
    row["verification_scope"] = "in-memory verifier; standalone proof decoding/verification not measured"
    return row


def percentile(values, fraction):
    """Nearest-rank percentile: ceil(p*N), using one-based ranks."""
    values = sorted(values)
    return values[max(0, math.ceil(fraction * len(values)) - 1)] if values else None


def summarize(rows, privacy, coverage, device):
    warm = [row for row in rows if row["sample_kind"] == "warm"]
    cold = [row for row in rows if row["sample_kind"] == "cold"]
    signatures = {json.dumps({k: row.get(k) for k in ("privacy", "coverage", "device", "layers", "tokens", "d", "f", "parameters", "gpu_label")}, sort_keys=True) for row in rows}
    reasons = []
    if len(signatures) > 1:
        reasons.append("mixed workload, parameters, privacy, or GPU across samples")
    if len(warm) < 20:
        reasons.append("at least 20 warm runs required")
    if len(cold) != 1:
        reasons.append("exactly one separate cold sample required")
    if len(warm) + len(cold) != len(rows):
        reasons.append("unknown sample kind")
    if not rows or any(not row["measurement_eligible"] for row in rows):
        reasons.append("one or more samples failed validation; inspect sample errors")
    metrics = {}
    for key in (*FIELDS, "proof_bytes", "process_wall_s", "legacy_pass_wall_s"):
        values = [(row.get("timing") or {}).get(key, row.get(key)) for row in warm]
        values = [v for v in values if finite_number(v) and v >= 0]
        metrics[key] = {"count": len(values), "p50": percentile(values, .5), "p95": percentile(values, .95)}
    ready95 = metrics["proof_ready_s"]["p95"]
    return {"schema": 1, "privacy": privacy, "coverage": coverage, "device": device,
            "timing_scope": SCOPE, "warm_definition": "subsequent fresh processes; weight cache reused for P0/P1, fresh commitments for P3; OS page cache not flushed",
            "warm_count": len(warm), "cold_count": len(cold),
            "percentile_method": "nearest-rank ceil(p*N)", "warm_metrics": metrics,
            "measurement_eligible": not reasons, "ineligible_reasons": reasons,
            "measured_scope_reaches_60_rows_s_at_p95": bool(not reasons and ready95 and rows[0]["tokens"] / ready95 >= 60),
            "goal_met": False, "goal_limitation": "Current coverage omits complete private LLM generation; 60 prefill rows/s is not 60 generated tokens/s.",
            "samples": rows}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def validate_gpu(info, d, privacy):
    if not 0 <= info["free_mib"] <= info["total_mib"] or info["total_mib"] <= 0:
        raise ValueError("invalid GPU capacity/free-memory reading")
    if d >= 4096 and privacy != "P0":
        if info["total_mib"] < 16384:
            raise ValueError("private d>=4096 GPU runs require at least 16 GiB total VRAM; refusing this device")
        used = info["total_mib"] - info["free_mib"]
        if used > 1024:
            raise ValueError(f"GPU busy: {used} MiB already used, {info['free_mib']} MiB free; private d>=4096 runs allow at most 1024 MiB display usage")


def gpu_preflight(index, d, privacy, *, enforce=True):
    """Read-only guard against rerunning the private 8B workload on 8 GiB."""
    result = subprocess.run(["nvidia-smi", "-i", str(index),
                             "--query-gpu=name,uuid,memory.total,memory.free,driver_version",
                             "--format=csv,noheader,nounits"], check=True, capture_output=True, text=True)
    lines = result.stdout.strip().splitlines()
    if len(lines) != 1:
        raise ValueError("exactly one selected GPU is required")
    fields = [field.strip() for field in lines[0].split(",")]
    if len(fields) != 5:
        raise ValueError("cannot read selected GPU memory and identity")
    name, uuid, total, free, driver = fields
    info = {"name": name, "uuid": uuid, "total_mib": int(total), "free_mib": int(free), "driver": driver}
    if enforce:
        validate_gpu(info, d, privacy)
    return info


@contextmanager
def heavy_lock():
    # Keep the shared inode: never unlink the lock, including after failures.
    print("Waiting for /tmp/zk-heavy.lock", flush=True)
    with open("/tmp/zk-heavy.lock", "a") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def system_metadata(threads):
    cpu = "unavailable"
    try:
        match = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
        if match:
            cpu = match[1]
    except OSError:
        pass
    return {"platform": f"{platform.system()} {platform.release()}", "machine": platform.machine(), "cpu": cpu,
            "logical_cpus": os.cpu_count(), "prover_threads": threads, "python": platform.python_version()}


def run_samples(args):
    with heavy_lock():
        return run_samples_locked(args)


def run_samples_locked(args):
    binary = args.binary.resolve(strict=True)
    export = args.export.resolve(strict=True)
    sidecar = (export / "digests.txt").read_text()
    dims = re.findall(r"^0+ dims (\d+) (\d+) (\d+) (\d+)\s*$", sidecar, re.MULTILINE)
    if len(dims) != 1 or not re.search(r"^0+ profile v3-widened\s*$", sidecar, re.MULTILINE):
        raise ValueError("run requires a v3-widened export with one 00 dims row")
    available_tokens, d, f, available_layers = map(int, dims[0])
    if min(available_tokens, d, f, available_layers) <= 0:
        raise ValueError("all export dimensions must be positive")
    if not 1 <= args.layers <= available_layers or not 1 <= args.tokens <= available_tokens:
        raise ValueError("requested shape exceeds export or has zero rows/layers")
    if args.tokens & (args.tokens - 1):
        raise ValueError("tokens must be a power of two")
    if args.seed is not None and not 0 <= args.seed < 2 ** 64:
        raise ValueError("seed must be in 0..2^64-1")
    if args.warm_runs < 0 or args.threads < 1:
        raise ValueError("warm-runs must be nonnegative and threads must be positive")
    hardware = gpu_preflight(args.gpu_index, d, args.privacy) if args.device == "gpu" else None
    args.out.mkdir(parents=True, exist_ok=False)
    output = args.out.resolve()
    proof = output / "last.proof"
    command = [str(binary), "pass", str(args.layers), str(args.tokens), "--profile", "v3",
               "--export", str(export), "--threads", str(args.threads), "--proof-out", str(proof)]
    if args.privacy != "P0":
        command.append("--p3" if args.privacy == "P3" else "--zk")
    if args.seed is not None:
        command.extend(["--seed", str(args.seed)])
    if args.privacy != "P3":
        command.extend(["--wcache", str(output / "wcache")])
    environment = os.environ.copy()
    # These are the authoritative switches for this runner; inherited settings
    # cannot silently turn a CPU row into GPU work or select several devices.
    environment.pop("HL_GPU", None)
    if args.device == "gpu":
        environment["HL_GPU"] = "1"
        environment["CUDA_VISIBLE_DEVICES"] = hardware["uuid"]
    manifest = {"command": command, "binary_sha256": digest(binary),
                "export_sidecar_sha256": digest(export / "digests.txt"), "hardware": hardware,
                "system": system_metadata(args.threads), "lock": "/tmp/zk-heavy.lock",
                "requested_warm_runs": args.warm_runs,
                "shape": {"layers": args.layers, "tokens": args.tokens, "d": d, "f": f},
                "environment": {k: v for k, v in environment.items() if k.startswith("HL_") or k in ("CUDA_VISIBLE_DEVICES", "RAYON_NUM_THREADS")}}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    rows = []
    for number in range(args.warm_runs + 1):
        kind = "cold" if number == 0 else "warm"
        logfile = output / f"{kind}-{number:03d}.log"
        print(f"{kind} sample {number}/{args.warm_runs}: {logfile}", flush=True)
        sample_hardware, wall, returncode = None, None, 2
        with logfile.open("w") as destination:
            try:
                if args.device == "gpu":
                    sample_hardware = gpu_preflight(args.gpu_index, d, args.privacy, enforce=False)
                    validate_gpu(sample_hardware, d, args.privacy)
                    if sample_hardware["uuid"] != hardware["uuid"]:
                        raise ValueError("selected GPU identity changed during collection")
                start = time.perf_counter()
                result = subprocess.run(command, env=environment, stdout=destination, stderr=subprocess.STDOUT, check=False)
                wall = time.perf_counter() - start
                returncode = result.returncode
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                destination.write(f"REFUSED: {error}\n")
            destination.write("\nHASHLINE_BENCHMARK_RUN " + json.dumps({"exit_code": returncode, "process_wall_s": wall, "gpu_before": sample_hardware}) + "\n")
        row = parse_log(logfile.read_text(errors="replace"), privacy=args.privacy,
                        coverage=args.coverage, device=args.device, exit_code=returncode,
                        process_wall_s=wall)
        row.update(sample_kind=kind, log=logfile.name)
        for key, value in manifest["shape"].items():
            if row.get(key) != value:
                row["errors"].append(f"observed {key} differs from requested manifest")
                row["measurement_eligible"] = False
        if not proof.is_file() or proof.stat().st_size != row.get("proof_bytes"):
            row["errors"].append("written proof missing or length mismatch")
            row["measurement_eligible"] = False
        elif digest(proof) != row.get("proof_sha256"):
            row["errors"].append("written proof digest mismatch")
            row["measurement_eligible"] = False
        rows.append(row)
        (output / "summary.json").write_text(json.dumps(summarize(rows, args.privacy, args.coverage, args.device), indent=2, allow_nan=False) + "\n")
        # Avoid repeating an expensive workload when the first run cannot support
        # the requested benchmark. Deterministic fixtures are intentionally single.
        if row["errors"]:
            print("Stopping after ineligible sample: " + "; ".join(row["errors"]), flush=True)
            break
    return summarize(rows, args.privacy, args.coverage, args.device)


def analyze_samples(args):
    if not args.warm and not args.cold:
        raise ValueError("provide --warm and/or --cold logs")
    sources = [(kind, path.resolve(strict=True)) for kind in ("cold", "warm") for path in getattr(args, kind)]
    if len({path for _, path in sources}) != len(sources):
        raise ValueError("the same log cannot count as multiple samples")
    if len({digest(path) for _, path in sources}) != len(sources):
        raise ValueError("duplicate log contents cannot count as independent samples")
    args.out.mkdir(parents=True, exist_ok=False)
    rows = []
    for number, (kind, path) in enumerate(sources):
        raw = path.read_bytes()
        name = f"{kind}-{number:03d}.log"
        (args.out / name).write_bytes(raw)
        row = parse_log(raw.decode(errors="replace"), privacy=args.privacy, coverage=args.coverage, device=args.device)
        row.update(sample_kind=kind, log=name, source=str(path))
        rows.append(row)
    return summarize(rows, args.privacy, args.coverage, args.device)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    for action in ("run", "analyze"):
        p = sub.add_parser(action)
        p.add_argument("--privacy", choices=("P0", "P1", "P3"), required=True)
        p.add_argument("--coverage", choices=("ffn-only",), default="ffn-only")
        p.add_argument("--device", choices=("cpu", "gpu"), required=True)
        p.add_argument("--out", type=Path, required=True, help="new directory for raw logs and JSON")
        if action == "analyze":
            p.add_argument("--warm", type=Path, nargs="*", default=[])
            p.add_argument("--cold", type=Path, nargs="*", default=[])
        else:
            p.add_argument("--binary", type=Path, required=True)
            p.add_argument("--export", type=Path, required=True)
            p.add_argument("--layers", type=int, default=32)
            p.add_argument("--tokens", type=int, default=512)
            p.add_argument("--threads", type=int, default=8)
            p.add_argument("--warm-runs", type=int, default=20)
            p.add_argument("--gpu-index", type=int, default=0)
            p.add_argument("--seed", type=int, help="deterministic test fixture only; makes row ineligible")
    args = parser.parse_args(argv)
    try:
        report = run_samples(args) if args.action == "run" else analyze_samples(args)
        (args.out / "summary.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"hashline benchmark: {error}\n")
    print(json.dumps({"summary": str(args.out / "summary.json"), "measurement_eligible": report["measurement_eligible"], "goal_met": report["goal_met"]}))
    return int(args.action == "run" and any(row["errors"] for row in report["samples"]))


if __name__ == "__main__":
    raise SystemExit(main())
