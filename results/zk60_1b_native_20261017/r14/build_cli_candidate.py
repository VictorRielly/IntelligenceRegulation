"""Guarded build and component/source-audit checks of the separate CLI candidate."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / "cli-candidate-working-tree"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
BUILD = "sol-r14-cli-build-1"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    pin = json.loads((HERE / (BUILD + ".source.json")).read_text())
    records = []
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        for name, want in pin["files"].items():
            assert sha(TREE / name) == want, name
    def run(label, leaf, cls="build", need=2.6, cap=5):
        check()
        while (HERE / "HOLD").exists() or (HERE.parent / "HOLD").exists():
            print(datetime.now(timezone.utc).isoformat(), label, "waiting for hold", flush=True)
            time.sleep(10)
        command = [sys.executable, str(GUARD), "run", "--class", cls, "--label", label,
                   "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "21600", "--max-secs", "1800",
                   "--log", str(HERE / (label + ".log")), "--done", str(HERE / (label + ".done")),
                   "--result-json", str(HERE / (label + ".guard.json")), "--", *leaf]
        path = HERE / (label + ".command.json")
        assert not path.exists()
        path.write_text(json.dumps({"command": command, "source": pin["tree_sha256"],
                                    "runner_sha256": sha(Path(__file__))}, indent=2) + "\n")
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (HERE / (label + ".log")).read_text()
        records.append({"label": label, "guard": json.loads((HERE / (label + ".guard.json")).read_text()),
                        "log_sha256": sha(HERE / (label + ".log"))})
        return log
    target = HERE / "cli-working-tree/hashline/target"
    env = ["/usr/bin/env", "CARGO_TARGET_DIR=" + str(target), "RAYON_NUM_THREADS=8", "OPENBLAS_NUM_THREADS=1"]
    cargo = "/home/victor/.cargo/bin/cargo"
    manifest = ["--release", "--offline", "--locked", "-j2", "--manifest-path", str(TREE / "hashline/Cargo.toml")]
    log = run(BUILD, [*env, cargo, "test", *manifest, "--lib", "split_", "--", "--test-threads=1", "--nocapture"])
    assert "22 passed; 0 failed" in log
    checkpoint = HERE / "checkpoints/cli-build-1"
    assert not checkpoint.exists()
    for name in pin["files"]:
        out = checkpoint / "tree" / name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(TREE / name, out)
    match = re.search(r'Running unittests src/lib\.rs \(([^\n]+)\)', log)
    assert match
    compiled = Path(match.group(1))
    if not compiled.is_absolute():
        compiled = ROOT / compiled
    binary = checkpoint / "hashline.test.bin"
    shutil.copy2(compiled, binary)
    for i, test in enumerate([
        "private_block::source_audit::",
        "private_block::s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on",
        "private_block::s25_tests::every_hash_call_site_in_the_lanes_own_sources_is_classified",
        "private_block::s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system",
    ]):
        log = run(f"sol-r14-cli-source-audit-{i+1}", [str(binary), test, "--test-threads=1", "--nocapture"], "light", 0.4, 1)
        assert "1 passed; 0 failed" in log
    run("sol-r14-cli-example-build-1", [*env, cargo, "build", *manifest, "--example", "zk60_split_stack"])
    cli = checkpoint / "zk60_split_stack.bin"
    shutil.copy2(target / "release/examples/zk60_split_stack", cli)
    check()
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"], "files": pin["count"],
              "test_binary_sha256": sha(binary), "cli_sha256": sha(cli), "cases": records,
              "scope": "Experimental R14 CLI build, 22 split components and four expanded source audits. Native CLI, publication-race, full26 and privacy gates remain separate."}
    (HERE / "CLI_BUILD_ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (HERE / "CLI_BUILD_ACCEPTANCE.done").write_text("0\n")
    (HERE / (BUILD + ".validated.done")).write_text("0\n")
    print("Experimental R14 CLI candidate build/components/source audits PASS", flush=True)

if __name__ == "__main__":
    main()
