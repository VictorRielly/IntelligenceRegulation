#!/usr/bin/env python3
"""Reload an idle explorer's explicit model choice; retain its hourly due time."""
import importlib.util
import json
from pathlib import Path
import shutil
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("zk60_explorer", ROOT / "scripts/zk60_explorer.py")
explorer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(explorer)


def main():
    before = explorer.health()
    if not before["worker_host_pid"] or before["paused"]:
        raise RuntimeError("Expected a live, unpaused host supervisor; no action taken")
    if before["status"].get("state") in {"running", "starting"}:
        raise RuntimeError("A research cycle is active; defer reload until idle")
    due = before["status"].get("next_due_unix", 0)
    if due <= time.time() + 30:
        raise RuntimeError("A cycle is due shortly; defer reload until it finishes")
    codex = shutil.which("codex")
    if not codex:
        raise RuntimeError("Codex unavailable; no action taken")
    explorer.pause()
    deadline = time.monotonic() + 10
    while explorer.worker_host_pid() and time.monotonic() < deadline:
        time.sleep(.2)
    if explorer.worker_host_pid():
        (explorer.WORK / "runtime/paused").unlink(missing_ok=True)
        raise RuntimeError("Existing supervisor has not exited; no duplicate launched")
    (explorer.WORK / "runtime/paused").unlink(missing_ok=True)
    explorer.ensure(codex)
    after = explorer.health()
    if not after["worker_host_pid"] or after["paused"]:
        raise RuntimeError("Replacement supervisor did not pass host health")
    if after["status"].get("next_due_unix") != due:
        raise RuntimeError("Research schedule changed unexpectedly")
    evidence = {"before": before, "after": after,
                "requested_model": explorer.AGENT_MODEL, "schedule_preserved": True}
    out = ROOT / "results/zk60_techweek_20260929/research-model-reload.json"
    out.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
