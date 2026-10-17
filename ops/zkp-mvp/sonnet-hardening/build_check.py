#!/usr/bin/env python3
"""Offline isolated CPU builds; preserve each command, log, pin and exit code."""
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
sys.path.insert(0, str(REPO))
from scripts import zk60_guarded_command as guarded
EVIDENCE = ROOT.parents[2] / "results/zk60_sonnet_hardening_20260930"
TOOLCHAIN = Path("/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin")


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    run = EVIDENCE / ("build-" + str(time.time_ns()))
    run.mkdir()
    print("Build evidence: " + str(run), flush=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env.update(RUSTC=str(TOOLCHAIN / "rustc"), CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2")
    record = {"state": "waiting-for-guard", "source": str(ROOT), "steps": []}
    def save():
        guarded.atomic_json(run / "report.json", record)
    save()
    try:
        for name, args in [
            ("example", ["build", "--example", "zk60_private_stack"]),
            ("tests", ["test", "--lib", "--no-run"]),
        ]:
            command = [str(TOOLCHAIN / "cargo"), *args, "--release", "--offline", "--locked", "-j", "2",
                       "--manifest-path", str(ROOT / "hashline/Cargo.toml")]
            record["state"] = "building-" + name
            save()
            step = guarded.run(command, cwd=ROOT, env=env, output=run, label=name)
            step["name"] = name
            code = step["exit_code"]
            record["steps"].append(step)
            save()
            print(json.dumps(step), flush=True)
            if code:
                record["state"] = "failed"
                save()
                (run / "run.done").write_text(str(code) + "\n")
                print(guarded.log_tail(run / (name + ".log")), flush=True)
                return code
    except (OSError, ValueError, RuntimeError, KeyboardInterrupt) as exc:
        record.update(state="interrupted" if isinstance(exc, (guarded.GuardInterrupted, KeyboardInterrupt)) else "failed",
                      error=str(exc), exit_code=1)
        save()
        (run / "run.done").write_text("1\n")
        print(json.dumps(record), flush=True)
        return 1
    record["state"] = "passed"
    save()
    (run / "run.done").write_text("0\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
