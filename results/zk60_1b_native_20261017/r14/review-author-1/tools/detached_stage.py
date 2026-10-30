"""Retained nohup/setsid worker and exact completion-file observer.

Only the two prepared full26 stages are selectable. Existing stages are never
restarted. A monitor timeout does not terminate or retry the detached worker.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
STAGES = {"native": "full26_native_checks_v3.py", "capture": "full26_capture_checks.py"}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=STAGES)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--observe", action="store_true")
    args = parser.parse_args()
    out = HERE / ("detached-full26-" + args.stage + "-1")
    script = HERE / STAGES[args.stage]
    contract_path = out / "CONTRACT.json"
    if args.worker:
        contract = json.loads(contract_path.read_text())
        assert sha(script) == contract["script_sha256"] and sha(Path(__file__)) == contract["supervisor_sha256"]
        save(out / "PROCESS.json", {"utc": datetime.now(timezone.utc).isoformat(), "pid": os.getpid(),
             "pid_namespace": os.readlink("/proc/self/ns/pid"), "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
             "starttime_ticks": Path("/proc/self/stat").read_text().rsplit(")", 1)[1].split()[19]})
        result = subprocess.run([sys.executable, str(script)], cwd=ROOT)
        save(out / "RESULT.json", {"utc": datetime.now(timezone.utc).isoformat(), "exit": result.returncode,
             "script_unchanged": sha(script) == contract["script_sha256"],
             "supervisor_unchanged": sha(Path(__file__)) == contract["supervisor_sha256"]})
        (out / "WORKER.done").write_text(str(result.returncode) + "\n")
        sys.exit(result.returncode)
    if not args.observe:
        assert not out.exists(), "inspect original stage; do not retry a recorded launch"
        out.mkdir()
        save(contract_path, {"utc": datetime.now(timezone.utc).isoformat(), "script": str(script),
             "script_sha256": sha(script), "supervisor_sha256": sha(Path(__file__)),
             "lifecycle": "nohup with start_new_session (setsid); completion file, never process-name polling"})
        with (out / "worker.log").open("wb") as log:
            worker = subprocess.Popen(["nohup", sys.executable, str(Path(__file__)), args.stage, "--worker"],
                                      cwd=ROOT, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                      start_new_session=True)
        save(out / "LAUNCH.json", {"utc": datetime.now(timezone.utc).isoformat(), "launcher_pid": os.getpid(), "child_pid_in_launcher_namespace": worker.pid})
    offset = 0
    deadline = time.monotonic() + 21600
    while True:
        log = out / "worker.log"
        if log.exists():
            with log.open("r") as stream:
                stream.seek(offset)
                chunk = stream.read()
                offset = stream.tell()
            if chunk:
                print(chunk, end="", flush=True)
        if (out / "WORKER.done").exists():
            result = json.loads((out / "RESULT.json").read_text())
            assert result["script_unchanged"] and result["supervisor_unchanged"]
            sys.exit(int((out / "WORKER.done").read_text()))
        if time.monotonic() >= deadline:
            print("Observation timeout: worker may still be live; keep original contract/process and inspect completion. No retry.", flush=True)
            sys.exit(75)
        time.sleep(5)

if __name__ == "__main__":
    main()
