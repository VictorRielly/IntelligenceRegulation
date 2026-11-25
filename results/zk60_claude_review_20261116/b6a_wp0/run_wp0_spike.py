"""Run the fixed D82 per-block measurements on a disposable source snapshot."""

import argparse
from hashlib import sha256
import json
import math
import os
from pathlib import Path
import re
import shutil
from statistics import median
import subprocess
import sys
from tempfile import TemporaryDirectory


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOL = ROOT / "results/zk60_sol_20261105_w16r3/b6a"
BASE = SOL / "profile-9fbc85292"
ADDITIONS = SOL / "source-wp0/complete"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
TEST = "zk60_b6a_spike::b6a_w_commit_and_baseline_absorbs"
RATES = (8, 4, 2)
WARM = 2
MEASURED = 7
FEATURES = "gpu-metal,zkp-core/b6a-spike"
EXPERIMENT_ENV = {
    "HL_GPU": "1",
    "HL_GPU_REQUIRED": "1",
    "HL_METAL_FUSED_RS": "1",
    "HL_METAL_SPARSE_FOLD": "1",
    "HL_METAL_SC_CHAIN_FAST": "1",
    "HL_HOST_FAST": "1",
    "HL_CLASSIFY_HOST_FAST": "1",
    "HL_TRANSCRIPT_PAR": "0",
    "RAYON_NUM_THREADS": "5",
}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def pins(tree):
    files = {}
    for path in sorted(tree.rglob("*")):
        if path.is_symlink():
            raise RuntimeError(f"snapshot contains a symlink: {path}")
        if path.is_file():
            files[path.relative_to(tree).as_posix()] = digest(path)
    return files


def json_file(path, data):
    with path.open("w") as output:
        json.dump(data, output, indent=2, allow_nan=False)
        output.write("\n")


def append(path, text):
    with path.open("a") as output:
        output.write(text)


def stage(destination):
    base_pins = pins(BASE)
    shutil.copytree(BASE, destination)
    if pins(destination) != base_pins:
        raise RuntimeError("base changed while preparing the source snapshot")
    core = destination / "zkp-core"
    crate = destination / "hashline"
    shutil.copyfile(ADDITIONS / "b6a_spike_host.rs", core / "src/pcs/b6a_spike_host.rs")
    shutil.copyfile(ADDITIONS / "zk60_b6a_spike.rs", crate / "src/zk60_b6a_spike.rs")
    append(core / "Cargo.toml", '\n[features]\nb6a-spike = []\n')
    append(core / "src/pcs/switched.rs",
           '\n#[cfg(feature = "b6a-spike")]\n#[path = "b6a_spike_host.rs"]\npub mod spike;\n')
    append(core / "src/pcs.rs",
           '\n#[cfg(feature = "b6a-spike")]\npub use switched::spike::SpikeFixture;\n')
    append(core / "src/tower.rs", """
#[cfg(feature = "b6a-spike")]
impl PreparedW {
    pub(crate) fn encoded_for_spike(&self) -> &[Fp] {
        &self.commitment.encoded
    }
}
""")
    switch = core / "src/pcs/switch.rs"
    source = switch.read_text()
    declaration = "#[cfg(test)]\npub(crate) fn evaluation_claim_dense"
    if source.count(declaration) != 1:
        raise RuntimeError("cannot locate the dense generator oracle")
    switch.write_text(source.replace(declaration,
                                      '#[cfg(any(test, feature = "b6a-spike"))]\npub(crate) fn evaluation_claim_dense'))
    append(crate / "src/lib.rs", "\n#[cfg(test)]\nmod zk60_b6a_spike;\n")
    return base_pins


def summary(log):
    records = {}
    for kind in ("M1-CPU", "M1-METAL", "M1-NOT-TIMED", "M2", "M34"):
        pattern = rf"B6A-{kind} ([^\r\n]+)"
        rows = []
        for match in re.finditer(pattern, log):
            fields, _, reason = match.group(1).partition(" reason=")
            row = dict(field.split("=", 1) for field in fields.split())
            if reason:
                row["reason"] = reason
            rows.append(row)
        records[kind] = rows

    def for_rate(kind, rate):
        return [row for row in records[kind] if row["rate"] == f"1/{rate}"]

    def trials(rows):
        expected = [(i, i < WARM) for i in range(WARM + MEASURED)]
        observed = [(int(row["iteration"]), row["warm"] == "true") for row in rows]
        if observed != expected:
            raise ValueError(f"observed {observed} instead of {expected}")
        return rows[WARM:]

    def reading(row, key):
        value = float(row[key])
        if not math.isfinite(value) or value < 0:
            raise ValueError(f"invalid reading {row!r}")
        return value

    baseline = [reading(row, "absorb_host_ms") for row in trials(records["M2"])]
    details = {}
    passing = []
    for rate in RATES:
        name = f"1/{rate}"
        by_rate = details[name] = {}
        [cpu] = for_rate("M1-CPU", rate)
        by_rate["cpu_w_ms"] = reading(cpu, "elapsed_ms")
        device = for_rate("M1-METAL", rate)
        host = for_rate("M34", rate)
        unavailable = for_rate("M1-NOT-TIMED", rate)
        if unavailable:
            [item] = unavailable
            if item["iteration"] != "0" or device or host:
                raise ValueError(f"contradictory unsupported-rate readings at {name}")
            by_rate.update(device_route="not timed", reason=item["reason"])
            continue
        device, host = trials(device), trials(host)
        gpu = [reading(row, "gpu_ms") for row in device]
        added = []
        for dev, cpu_host, removed in zip(device, host, baseline, strict=True):
            remaining_wall = max(0.0, reading(dev, "encode_wall_ms") - reading(dev, "gpu_ms"))
            bridge = reading(dev, "prep_host_ms") + reading(dev, "salt_tree_host_ms")
            protocol = reading(cpu_host, "prove_bat_ms") + reading(cpu_host, "prove_tower_ms")
            added.append(bridge + protocol + remaining_wall - removed)
        g, h = median(gpu), median(added)
        kill = g > 6 or h > 15
        passes = g <= 3 and h <= 5
        by_rate.update(
            device_route="qualified",
            gpu_ms=g,
            host_added_ms=h,
            total_added_ms=g + h,
            verdict="kill" if kill else "pass" if passes else "between",
            median_phases_ms={key: median(reading(row, key) for row in host) for key in (
                "dense_a_ms", "dense_h_ms", "rational_a_ms", "rational_h_ms",
                "prove_bat_ms", "prove_tower_ms", "verify_bat_ms", "verify_tower_ms",
            )},
        )
        if passes:
            passing.append((g + h, rate))
    candidate = None
    if passing:
        fastest = min(total for total, _ in passing)
        candidate = f"1/{max(rate for total, rate in passing if total - fastest <= 0.3)}"
    return {"baseline_absorb_ms": median(baseline), "rates": details,
            "candidate": candidate, "raw_counts": {name: len(rows) for name, rows in records.items()}}


def run_snapshot(snapshot, record):
    crate = snapshot / "source/hashline"
    target = snapshot / "target"
    env = {key: value for key, value in os.environ.items()
           if not key.startswith("HL_") and key not in ("RUSTFLAGS", "CARGO_ENCODED_RUSTFLAGS")}
    env.update(EXPERIMENT_ENV)
    command = ["cargo", "test", "--release", "--offline", "--locked", "-j", "2",
               "--target-dir", str(target), "--features", FEATURES,
               "--lib", "--no-run", "--message-format=json"]
    print("RUN isolated release build", flush=True)
    build = record / "build.jsonl"
    with build.open("w") as output, (record / "build.stderr").open("w") as error:
        run = subprocess.run(command, cwd=crate, env=env, stdout=output, stderr=error)
    if run.returncode:
        return run.returncode
    artifacts = (json.loads(line) for line in build.read_text().splitlines())
    [binary] = {Path(row["executable"]).resolve()
                for row in artifacts if row["reason"] == "compiler-artifact" and row.get("executable")
                and row["target"]["name"] == "hashline" and row["profile"]["test"]}
    if not binary.is_file() or not binary.is_relative_to(target):
        raise RuntimeError("test binary is outside the isolated Cargo target")
    json_file(record / "test.json", {"executable_sha256": digest(binary), "env": EXPERIMENT_ENV})
    print("RUN fixed M1-M4 test", flush=True)
    with (record / "measure.log").open("w") as output:
        return subprocess.run([str(binary), TEST, "--ignored", "--exact", "--nocapture", "--test-threads=1"],
                              cwd=crate, env=env, stdout=output, stderr=subprocess.STDOUT).returncode


def measure():
    root = HERE / "qualification-wp0"
    root.mkdir(exist_ok=True)
    for i in range(100):
        record = root / f"attempt-{i:02d}"
        try:
            record.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise RuntimeError("measurement archive is full")
    with TemporaryDirectory(prefix="claude-b6a-wp0-", dir="/private/tmp") as tmp:
        snapshot = Path(tmp).resolve()
        source = snapshot / "source"
        base_pins = stage(source)
        source_pins = pins(source)
        launcher = snapshot / Path(__file__).name
        shutil.copyfile(__file__, launcher)
        json_file(record / "launch.json", {
            "base_source_pins": base_pins, "source_pins": source_pins,
            "guard_sha256": digest(GUARD), "runner_sha256": digest(launcher), "test": TEST,
            "rustc": subprocess.check_output(["rustc", "--version"], text=True).strip(),
            "gpu_lines_ms": {"pass": 3, "kill_above": 6},
            "host_lines_ms": {"pass": 5, "kill_above": 15},
        })
        guard = record / "guard.json"
        done = record / "gate.done"
        cmd = [sys.executable, "-B", str(GUARD), "run", "--class", "gpu",
               "--label", "claude-b6a-wp0-spike", "--need-gib", "7", "--cap-gib", "9",
               "--max-secs", "1200", "--wait-secs", "0", "--log", str(record / "gate.log"),
               "--done", str(done), "--result-json", str(guard), "--",
               sys.executable, "-B", str(launcher), "--snapshot", str(snapshot), str(record)]
        run = subprocess.run(cmd, cwd=ROOT)
        g = json.loads(guard.read_text()) if guard.is_file() else {}
        log = record / "measure.log"
        output = log.read_text() if log.is_file() else ""
        complete = (run.returncode == g.get("exit") == g.get("child_rc") == 0
                    and not g.get("guard_killed") and done.is_file() and done.read_text().strip() == "0"
                    and "test result: ok. 1 passed; 0 failed" in output and pins(source) == source_pins)
        try:
            verdict = summary(output) if complete else {}
        except (ValueError, KeyError) as error:
            verdict = {"measurement_error": str(error)}
            complete = False
        json_file(record / "result.json", {"complete": complete, "guard": g.get("run_id"), **verdict})
        print(f"{'MEASURED' if complete else 'INCOMPLETE'} {record.relative_to(ROOT)}", flush=True)
        return 0 if complete else (run.returncode or 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--measure", action="store_true")
    mode.add_argument("--stage", type=Path)
    mode.add_argument("--snapshot", nargs=2, type=Path)
    args = parser.parse_args()
    if args.measure:
        sys.exit(measure())
    if args.snapshot:
        sys.exit(run_snapshot(*args.snapshot))
    stage(args.stage)
    print(args.stage)
