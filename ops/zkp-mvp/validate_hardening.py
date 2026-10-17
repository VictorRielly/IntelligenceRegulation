#!/usr/bin/env python3
"""Resume Sonnet CLI validation with one guarded native command at a time."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import sys
import time

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import zk60_private_stack_benchmark as bench

SOURCE = REPO / "ops/zkp-mvp/sonnet-hardening"
TOOLCHAIN = Path("/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("HL_", "RISC0_", "BONSAI_"))}
    env.update(RUSTC=str(TOOLCHAIN / "rustc"), CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2",
               HL_GPU="0", HL_GPU_REQUIRED="0", MALLOC_MMAP_THRESHOLD_="131072")
    before = bench.source_hashes(SOURCE)
    report = {"state": "starting", "steps": [], "source_hashes": before,
              "scope": "synthetic p2 CLI hardening validation; not a trained-model proof",
              "runner_process": bench.process_identity(os.getpid()), "started_at_unix": time.time()}
    def save():
        bench.atomic_write(output / "report.json", json.dumps(report, indent=2) + "\n")
    def run(name, command, build=False):
        row, log = bench.run_step(name, command, output=output, source=SOURCE, env=env,
                                  timeout=600 if build else 120, report=report, save=save,
                                  guard_class="build" if build else "cpu", small_shape=not build)
        if row["exit_code"]:
            raise ValueError(f"{name} failed with exit {row['exit_code']}")
        return log
    handlers = {sig: signal.signal(sig, bench.interrupt_run) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        cargo = str(TOOLCHAIN / "cargo")
        flags = ["--release", "--offline", "--locked", "-j", "2", "--manifest-path", str(SOURCE / "hashline/Cargo.toml")]
        run("build-example", [cargo, "build", "--example", "zk60_private_stack", *flags], True)
        run("build-tests", [cargo, "test", "--lib", "--no-run", *flags], True)
        binaries = [p for p in (SOURCE / "hashline/target/release/deps").glob("hashline-*")
                    if p.is_file() and os.access(p, os.X_OK) and not p.name.endswith(".d")]
        if len(binaries) != 1:
            raise ValueError(f"expected one native test binary, found {len(binaries)}")
        test_binary = binaries[0]
        cli = SOURCE / "hashline/target/release/examples/zk60_private_stack"
        # Later GPU builds can replace target/release artifacts. Retain the
        # actual CPU executables used by these acceptance checks.
        (output / "bin").mkdir()
        for executable in (cli, test_binary):
            shutil.copy2(executable, output / "bin" / executable.name)
        cli = output / "bin" / cli.name
        test_binary = output / "bin" / test_binary.name
        report["binary_hashes"] = {str(p): bench.sha(p) for p in (cli, test_binary)}
        log = run("driver-tests", [str(test_binary), "private_block::mvp_driver::tests", "--test-threads=1"])
        if "13 passed; 0 failed" not in log.read_text():
            raise ValueError("did not run all thirteen native CLI tests")
        log = run("segment-reader-tests", [str(test_binary), "private_block::run::bounded_segment_tests", "--test-threads=1"])
        if "2 passed; 0 failed" not in log.read_text():
            raise ValueError("did not run both bounded segment reader tests")
        artifact = output / "receipt 雪 with space"
        policy = output / "trusted policy 雪.txt"
        log = run("prove-p2-two-block", [str(cli), "prove", "--shape", "p2", "--blocks", "2",
                                        "--out", str(artifact), "--policy-out", str(policy)])
        event = bench.one_event(log, "prove_result")
        generated = event["independent_verification"]
        argv = generated["argv"]
        if shlex.split(generated["command"]) != argv:
            raise ValueError("generated shell command differs from machine-readable argv")
        if argv[0] != "zk60_private_stack" or argv[1] != "verify":
            raise ValueError("unexpected generated verifier command")
        if argv[argv.index("--policy-sha256") + 1] != bench.sha(policy):
            raise ValueError("generated verifier policy pin differs from saved policy")
        verify_log = run("replay-generated-argv", [str(cli), *argv[1:]])
        bench.validate_result(event, bench.one_event(verify_log, "verify_result"),
                              "cpu", 0, False, "p2", 2)
        review = REPO / "results/zk60_sonnet_hardening_20260930/sol-review/review_verify.py"
        run("independent-adversarial-review", [sys.executable, str(review), "--binary", str(cli),
                                              "--artifact", str(artifact), "--policy", str(policy),
                                              "--out", str(output / "adversarial")])
        if before != bench.source_hashes(SOURCE):
            raise ValueError("native source changed during validation")
        if any(bench.sha(Path(p)) != h for p, h in report["binary_hashes"].items()):
            raise ValueError("native binary changed during validation")
        report.update(state="passed", current=None, generated_verifier_argv_replayed=True,
                      adversarial_result=json.loads((output / "adversarial/report.json").read_text()))
        save()
        bench.atomic_write(output / "run.done", "0\n")
        print(json.dumps({"state": "passed", "output": str(output), "steps": len(report["steps"])}))
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        report.update(state="failed", failed_step=report.get("current"), error=str(exc))
        save()
        bench.atomic_write(output / "run.done", "1\n")
        raise
    finally:
        for sig, handler in handlers.items():
            signal.signal(sig, handler)


if __name__ == "__main__":
    raise SystemExit(main())
