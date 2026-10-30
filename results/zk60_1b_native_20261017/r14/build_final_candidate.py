"""Final-source Rust suite, byte goldens, binaries and retained legacy gates.

This creates an author validation checkpoint. It does not freeze or register
R14, and its new full26 capture test is executed only after a real receipt exists.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from validate_suite_census import validate

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / "final-working-tree"
OUT = HERE / "final-validation-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
BUILD = "sol-r14-final-build-1"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1 << 20), b""):
            h.update(data)
    return h.hexdigest()

def main():
    assert not OUT.exists()
    OUT.mkdir()
    pin = json.loads((HERE / (BUILD + ".source.json")).read_text())
    records = []
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        for name, want in pin["files"].items():
            assert sha(TREE / name) == want, name
    def run(name, leaf, cls, need, cap, expected_tests=None):
        check()
        while (HERE / "HOLD").exists() or (HERE.parent / "HOLD").exists():
            print(datetime.now(timezone.utc).isoformat(), name, "waiting for hold", flush=True)
            time.sleep(10)
            check()
        label = "sol-r14-final-" + name + "-1"
        command = [sys.executable, str(GUARD), "run", "--class", cls, "--label", label,
                   "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "21600", "--max-secs", "1800",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", *leaf]
        path = OUT / (name + ".command.json")
        assert not path.exists()
        path.write_text(json.dumps({"command": command, "source": pin["tree_sha256"],
                                    "runner_sha256": sha(Path(__file__))}, indent=2) + "\n")
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (OUT / (name + ".log")).read_text()
        if expected_tests is not None:
            assert f"{expected_tests} passed; 0 failed" in log
        row = {"name": name, "guard": json.loads((OUT / (name + ".guard.json")).read_text()),
               "log_sha256": sha(OUT / (name + ".log"))}
        records.append(row)
        (OUT / (name + ".validated.done")).write_text("0\n")
        (OUT / "PROGRESS.json").write_text(json.dumps(records, indent=2) + "\n")
        return log, row
    target = HERE / "cli-working-tree/hashline/target"
    env = ["/usr/bin/env", "CARGO_TARGET_DIR=" + str(target), "RAYON_NUM_THREADS=2", "OPENBLAS_NUM_THREADS=1",
           "ZK60_NATIVE_TINY_EXPORT_DIR=" + str(OUT / "generated-tiny-exports"),
           "ZK60_R12_EVIDENCE_DIR=" + str(OUT / "generated-r12-receipts")]
    cargo = "/home/victor/.cargo/bin/cargo"
    manifest = ["--release", "--offline", "--locked", "-j2", "--manifest-path", str(TREE / "hashline/Cargo.toml")]
    log, row = run("suite", [*env, cargo, "test", *manifest, "--no-fail-fast", "--", "--test-threads=2"], "cpu", 4.2, 8)
    census = validate(OUT / "suite.log", HERE.parent / "r13/release-2-suite.log")
    row["census"] = census
    (OUT / "SUITE_CENSUS.json").write_text(json.dumps(census, indent=2) + "\n")
    checkpoint = HERE / "checkpoints/final-build-1"
    assert not checkpoint.exists()
    for name in pin["files"]:
        out = checkpoint / "tree" / name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(TREE / name, out)
    match = re.search(r"Running unittests src/lib\.rs \(([^\n]+)\)", log)
    assert match
    compiled = Path(match.group(1))
    if not compiled.is_absolute():
        compiled = ROOT / compiled
    binary = checkpoint / "hashline.test.bin"
    shutil.copy2(compiled, binary)
    run("goldens", ["/usr/bin/env", "RAYON_NUM_THREADS=2", str(binary), "r12_golden_tests", "--ignored", "--test-threads=1", "--nocapture"], "cpu", 8, 10.5, 5)
    for example in ["zk60_split_stack", "zk60_trained_block"]:
        run("build-" + example, [*env, cargo, "build", *manifest, "--example", example], "build", 2.6, 5)
        shutil.copy2(target / "release/examples" / example, checkpoint / (example + ".bin"))
    legacy = checkpoint / "zk60_trained_block.bin"
    names = ["compat-tl", "compat-tl-dd", "compat-8b", "compat-8b-dd"]
    names += [f"cli-verify-{fixture}-{mode}" for fixture in ["r13-low-dense", "r13-h24-wide"] for mode in ["plain", "dd"]]
    for name in names:
        original = HERE.parent / "r13" / ("release-2-" + name + ".command.json")
        old = json.loads(original.read_text())
        ix = next(i for i, value in enumerate(old) if Path(value).name == "zk60_trained_block")
        args = old[ix + 1:]
        assert args[0] in ["verify", "stack-verify"]
        expected = args[args.index("--expect-statement") + 1]
        log, row = run(name, ["/usr/bin/env", "RAYON_NUM_THREADS=2", str(legacy), *args], "cpu", 2.5, 5)
        events = [json.loads(line) for line in log.splitlines() if line.startswith("{")]
        verified = [event for event in events if event.get("event") == "verified"]
        assert len(verified) == 1 and verified[0]["statement_identity"] == expected
        row["verified"] = verified[0]
        row["prior_command_sha256"] = sha(original)
    log, row = run("retained-r12", ["/usr/bin/env", "RAYON_NUM_THREADS=2",
        "ZK60_R12_EVIDENCE_DIR=" + str(HERE.parent / "r12b/dense-receipts"), str(binary), "f2_saved_shieldstral",
        "--ignored", "--test-threads=1", "--nocapture"], "light", 1, 2, 2)
    assert log.count("bytes verified; modified segment rejected") == 2
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"], "files": pin["count"],
              "test_binary_sha256": sha(binary), "cli_sha256": sha(checkpoint / "zk60_split_stack.bin"),
              "legacy_cli_sha256": sha(legacy), "suite": census, "cases": records,
              "scope": "Final-source author build: complete Rust suite preserving every baseline outcome, frozen byte/identity goldens, eight retained legacy CLI receipts and both R12 variants. Full26 native proof/captures, final source relation gates, soundness, independent reviews and privacy acceptance remain separate."}
    (OUT / "ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (OUT / "ACCEPTANCE.done").write_text("0\n")
    (HERE / (BUILD + ".validated.done")).write_text("0\n")
    print("Final-source build/suite/goldens/legacy gates PASS", flush=True)

if __name__ == "__main__":
    main()
