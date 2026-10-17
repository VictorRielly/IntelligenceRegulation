#!/usr/bin/env python3
"""Durable, single-worker exploratory Codex loop; never changes the main prover."""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import shutil
import shlex
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "research/zkp-efficiency"
PROMPT = ROOT / "ops/zkp-explorer/PROMPT.md"
AGENT_MODEL = "gpt-6.1-sol"  # Victor's updated explicit model choice, 2026-09-29.
UNIT = "zk60-efficiency-explorer.service"
CRON_BEGIN = "# BEGIN zk60-efficiency-explorer (managed by scripts/zk60_explorer.py)"
CRON_END = "# END zk60-efficiency-explorer"


def utc() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".new")
    tmp.write_text(json.dumps(value, indent=2) + "\n")
    tmp.replace(path)


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text())


@contextlib.contextmanager
def exclusive(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
        else:
            try:
                yield True
            finally:
                fcntl.flock(handle, fcntl.LOCK_UN)


def command(codex: str, work: Path, output: Path) -> list[str]:
    # "never" denies requests needing escalation; it does NOT approve them.
    # Keep the account, live native search and sandbox; pin the requested model.
    return [codex, "--search", "--ask-for-approval", "never", "exec",
            "--model", AGENT_MODEL, "--sandbox", "workspace-write", "--cd", str(work),
            "--skip-git-repo-check", "--json", "--output-last-message",
            str(output), "-"]


def isolated_command(root: Path, codex: str, account_home: Path) -> list[str]:
    work = root / "research/zkp-efficiency"
    return ["/usr/bin/bwrap", "--unshare-user", "--unshare-pid", "--unshare-ipc",
            "--unshare-uts", "--new-session", "--cap-drop", "ALL",
            "--ro-bind", "/", "/", "--bind", str(work), str(work),
            "--bind", str(account_home / ".codex"), str(account_home / ".codex"),
            "--bind", "/tmp", "/tmp", "--proc", "/proc", "--dev", "/dev",
            "--chdir", str(work), "/usr/bin/nice", "-n", "15",
            "/usr/bin/python3", str(root / "scripts/zk60_explorer.py"),
            "serve", "--codex", codex]


def cron_text(previous: str, root: Path, codex: str) -> str:
    if previous.count(CRON_BEGIN) != previous.count(CRON_END) or previous.count(CRON_BEGIN) > 1:
        raise ValueError("Malformed/duplicate explorer crontab block; refusing to edit")
    if CRON_BEGIN in previous:
        start = previous.index(CRON_BEGIN)
        stop = previous.index(CRON_END) + len(CRON_END)
        if stop < start:
            raise ValueError("Reversed explorer crontab markers")
        previous = previous[:start] + previous[stop:].lstrip("\n")
    parts = ["/usr/bin/python3", str(root / "scripts/zk60_explorer.py"),
             "ensure", "--codex", codex]
    line = shlex.join(parts) + " >> " + shlex.quote(str(root / "research/zkp-efficiency/runtime/supervisor.log")) + " 2>&1"
    if any(c in line for c in "\n\r%"):
        raise ValueError("Unsupported crontab path")
    return (previous.rstrip("\n") + "\n" if previous else "") + CRON_BEGIN + "\n@reboot " + line + "\n*/5 * * * * " + line + "\n" + CRON_END + "\n"


def process_identity(pid: int) -> str | None:
    try:
        # Fields after the final ')' begin with state (field 3); starttime=22.
        return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return None


def descendants(pid: int) -> list[int]:
    found, pending = [], [pid]
    while pending:
        current = pending.pop()
        try:
            children = [int(x) for x in Path(f"/proc/{current}/task/{current}/children").read_text().split()]
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
        for child in children:
            if child not in found:
                found.append(child)
                pending.append(child)
    return found


def worker_host_pid() -> int | None:
    launcher = read_json(WORK / "runtime/launcher.json")
    pid = launcher.get("host_pid")
    if not pid or process_identity(pid) != launcher.get("host_starttime"):
        return None
    for child in descendants(pid):
        try:
            args = Path(f"/proc/{child}/cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
        if args[:3] == [b"/usr/bin/python3", str(ROOT / "scripts/zk60_explorer.py").encode(), b"serve"]:
            return child
    return None


def pause() -> None:
    runtime = WORK / "runtime"
    runtime.mkdir(parents=True, exist_ok=True)
    # Watchdog reads the flag before launching. Hold its lock while identifying
    # and signalling OUR exact supervisor, not a possibly reused recorded PID.
    with exclusive(runtime / "launcher.lock") as acquired:
        if not acquired:
            raise RuntimeError("Launcher busy; retry pause shortly")
        (runtime / "paused").write_text(utc() + "\n")
        pid = worker_host_pid()
        if pid:
            descriptor = os.pidfd_open(pid)
            try:
                if worker_host_pid() == pid:
                    signal.pidfd_send_signal(descriptor, signal.SIGTERM)
            finally:
                os.close(descriptor)
        print(json.dumps({"paused": True, "signalled_supervisor": pid}))


def health() -> dict:
    launcher = read_json(WORK / "runtime/launcher.json")
    pid = launcher.get("host_pid")
    live = bool(pid and process_identity(pid) == launcher.get("host_starttime"))
    worker = worker_host_pid() if live else None
    return {"checked_at": utc(), "launcher_identity_matches": live,
            "worker_host_pid": worker, "paused": (WORK / "runtime/paused").exists(),
            "status": read_json(WORK / "runtime/status.json")}


def ensure(codex: str) -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    runtime = WORK / "runtime"
    with exclusive(runtime / "launcher.lock") as launch_lock:
        if not launch_lock:
            print("Another launcher is checking the explorer.")
            return
        if (runtime / "paused").exists():
            print("Explorer is paused; watchdog will not start it.")
            return
        with exclusive(runtime / "worker.lock") as worker_lock:
            if not worker_lock:
                print("Explorer worker lock is held; no second worker launched.")
                return
        # The mount namespace is independent of this chat and keeps all of the
        # production tree read-only; no permissions/sandbox bypass is used.
        env = os.environ.copy()
        env["PATH"] = str(Path(codex).parent) + ":/usr/local/bin:/usr/bin:/bin"
        with (runtime / "supervisor.log").open("a") as log:
            proc = subprocess.Popen(isolated_command(ROOT, codex, Path.home()), env=env,
                                    stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                    start_new_session=True, cwd=WORK)
        identity = process_identity(proc.pid)
        time.sleep(0.5)
        if proc.poll() is not None:
            raise RuntimeError("Isolated explorer launch failed; see runtime/supervisor.log")
        record = {"launched_at": utc(), "host_pid": proc.pid, "host_starttime": identity,
                  "command": isolated_command(ROOT, codex, Path.home()), "backend": "cron+bwrap"}
        atomic_json(runtime / "launcher.json", record)
        print(json.dumps(record))


def install_cron(codex: str) -> None:
    # Explicit fallback for this host's missing user bus. Requires the same
    # scoped host approval as installation of a systemd user service.
    if not Path("/usr/bin/bwrap").is_file():
        raise RuntimeError("bubblewrap is required; refusing an unsandboxed fallback")
    daemon = subprocess.run(["pgrep", "-x", "cron"], capture_output=True, text=True)
    if daemon.returncode != 0:
        raise RuntimeError("No live cron daemon; nothing installed")
    existing = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
    if existing.returncode and "no crontab for" not in existing.stderr.lower():
        raise RuntimeError("Unable to read crontab; refusing to replace it")
    previous = existing.stdout if not existing.returncode else ""
    prepared = cron_text(previous, ROOT, codex)
    runtime = WORK / "runtime"
    runtime.mkdir(parents=True, exist_ok=True)
    # Retain the exact prior table before installing only our marked block.
    backup = runtime / ("crontab-before-" + uuid.uuid4().hex + ".txt")
    backup.write_text(previous)
    ensure(codex)
    subprocess.run(["crontab", "-"], input=prepared, text=True, check=True)
    check = subprocess.run(["crontab", "-l"], capture_output=True, text=True, check=True)
    if check.stdout != prepared:
        raise RuntimeError("Crontab readback mismatch; review required")
    atomic_json(runtime / "installation.json", {"installed_at": utc(), "backend": "cron+bwrap",
                "watchdog_minutes": 5, "restart_at_boot": True, "cron_pids": daemon.stdout.split(),
                "previous_crontab": str(backup), "managed_block": prepared[prepared.index(CRON_BEGIN):]})
    print("Installed and read back the cron watchdog; isolated worker launched.")


def terminate_group(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=10)


def event_summary(path: Path) -> dict:
    result = {"turn_completed": False, "turn_failed": False,
              "web_search_events": 0, "thread_id": None, "usage": None}
    for line in path.read_text().splitlines():
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = item.get("type")
        if kind == "thread.started":
            result["thread_id"] = item.get("thread_id")
        if kind == "turn.completed":
            result["turn_completed"] = True
            result["usage"] = item.get("usage")
        if kind in {"turn.failed", "error"}:
            result["turn_failed"] = True
        if (item.get("item") or {}).get("type") == "web_search":
            result["web_search_events"] += 1
    return result


class Worker:
    def __init__(self, work: Path, codex: str, prompt: str,
                 interval: float = 3600, timeout: float = 1200,
                 prompt_path: Path | None = None):
        self.work, self.codex, self.prompt = work, codex, prompt
        self.prompt_path = prompt_path
        self.runtime = work / "runtime"
        self.interval, self.timeout = interval, timeout
        self.stopping = False

    def stop(self, *_):
        self.stopping = True

    def cycle(self, argv: list[str] | None = None) -> dict:
        self.runtime.mkdir(parents=True, exist_ok=True)
        run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        run = self.runtime / "runs" / run_id
        run.mkdir(parents=True)
        previous = read_json(self.runtime / "status.json")
        started = time.time()
        status = {"state": "starting", "pid": os.getpid(), "run_id": run_id,
                  "requested_model": AGENT_MODEL,
                  "started_at": utc(), "heartbeat": utc(),
                  "last_completed_run": previous.get("last_completed_run"),
                  "interval_seconds": self.interval, "timeout_seconds": self.timeout}
        atomic_json(self.runtime / "status.json", status)
        current_prompt = self.prompt_path.read_text() if self.prompt_path else self.prompt
        prompt = (current_prompt + "\n\nRun identity: " + run_id
                  + "\nCurrent UTC: " + utc()
                  + "\nProject root (read only): " + str(ROOT)
                  + "\nYour writable research directory: " + str(self.work)
                  + "\nFinish and checkpoint within " + str(int(self.timeout / 60)) + " minutes.\n")
        (run / "prompt.md").write_text(prompt)
        args = argv or command(self.codex, self.work, run / "final.md")
        env = os.environ.copy()
        env.update({"CARGO_BUILD_JOBS": "1", "RAYON_NUM_THREADS": "1",
                    "OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1"})
        outcome, returncode = "failed", None
        with (run / "events.jsonl").open("w") as out, (run / "stderr.log").open("w") as err:
            try:
                process = subprocess.Popen(args, cwd=self.work, env=env, stdin=subprocess.PIPE,
                                           stdout=out, stderr=err, text=True, start_new_session=True)
                try:
                    process.stdin.write(prompt)
                    process.stdin.close()
                    status.update(state="running", child_pid=process.pid)
                    while process.poll() is None:
                        status["heartbeat"] = utc()
                        atomic_json(self.runtime / "status.json", status)
                        if self.stopping:
                            outcome = "interrupted"
                            break
                        if time.time() - started >= self.timeout:
                            outcome = "timeout"
                            break
                        if sum(p.stat().st_size for p in (run / "events.jsonl", run / "stderr.log")) > 32 * 1024 * 1024:
                            outcome = "log-limit"
                            break
                        time.sleep(0.25)
                    if process.poll() is None:
                        terminate_group(process)
                    returncode = process.wait()
                finally:
                    terminate_group(process)
            except (OSError, BrokenPipeError) as exc:
                err.write(type(exc).__name__ + ": " + str(exc) + "\n")
        summary = event_summary(run / "events.jsonl")
        if outcome == "failed" and returncode == 0 and summary["turn_completed"] and not summary["turn_failed"]:
            outcome = "completed"
        record = {**status, **summary, "state": outcome, "returncode": returncode,
                  "finished_at": utc(), "elapsed_seconds": round(time.time() - started, 3)}
        atomic_json(run / "result.json", record)
        (run / "run.done").write_text(outcome + "\n")
        if outcome == "completed":
            status["last_completed_run"] = run_id
        status.update(state="stopped" if self.stopping else "idle", heartbeat=utc(),
                      last_outcome=outcome, next_due_unix=max(started + self.interval, time.time() + 60))
        status.pop("child_pid", None)
        atomic_json(self.runtime / "status.json", status)
        return record

    def serve(self, once: bool = False) -> int:
        self.work.mkdir(parents=True, exist_ok=True)
        with exclusive(self.runtime / "worker.lock") as acquired:
            if not acquired:
                print("A worker already holds the singleton lock.", flush=True)
                return 0
            prior = read_json(self.runtime / "status.json")
            # A killed/failed cycle waits until its recorded next due time; do
            # not create a billable tight restart loop after a host crash.
            if prior.get("state") in {"starting", "running"}:
                prior.update(state="interrupted", next_due_unix=time.time() + self.interval,
                             heartbeat=utc())
                atomic_json(self.runtime / "status.json", prior)
            while not self.stopping:
                state = read_json(self.runtime / "status.json")
                if once or time.time() >= state.get("next_due_unix", 0):
                    record = self.cycle()
                    print(json.dumps({"run_id": record["run_id"], "outcome": record["state"]}), flush=True)
                    if once:
                        return 0 if record["state"] == "completed" else 1
                else:
                    # A restarted supervisor is alive and waiting, not an
                    # active copy of the interrupted child from the old host.
                    state.pop("child_pid", None)
                    state.update(state="idle", requested_model=AGENT_MODEL,
                                 pid=os.getpid(), heartbeat=utc())
                    atomic_json(self.runtime / "status.json", state)
                    time.sleep(min(1, max(0.01, state["next_due_unix"] - time.time())))
            state = read_json(self.runtime / "status.json")
            state.update(state="stopped", heartbeat=utc())
            atomic_json(self.runtime / "status.json", state)
        return 0

def unit_text(root: Path, codex: str) -> str:
    # systemd additionally makes the project read-only outside the research lane.
    # No PrivateTmp: experiments must see the project's shared heavy/build locks.
    for path in (str(root), codex, str(Path.home())):
        if any(c in path for c in '\n\r"% \\'):
            raise ValueError("Unsupported character in service path")
    return f'''[Unit]
Description=Persistent ZKP efficiency literature and PoC explorer
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=3

[Service]
Type=simple
WorkingDirectory={root}/research/zkp-efficiency
ExecStart=/usr/bin/python3 {root}/scripts/zk60_explorer.py serve --codex {codex}
Restart=on-failure
RestartSec=60
KillMode=control-group
TimeoutStopSec=30
Nice=15
CPUWeight=10
CPUQuota=100%
MemoryHigh=2G
MemoryMax=3G
TasksMax=128
UMask=0077
Environment=PATH={Path(codex).parent}:/usr/local/bin:/usr/bin:/bin
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths={root}/research/zkp-efficiency {Path.home()}/.codex /tmp
NoNewPrivileges=yes

[Install]
WantedBy=default.target
'''


def install(codex: str) -> None:
    # This is the ONLY operation writing outside the project, explicitly approved
    # through the host's escalation UI. It never silently falls back to nohup/cron.
    subprocess.run(["systemctl", "--user", "show-environment"], check=True, stdout=subprocess.DEVNULL)
    destination = Path.home() / ".config/systemd/user" / UNIT
    text = unit_text(ROOT, codex)
    if destination.exists() and destination.read_text() != text:
        raise RuntimeError("An existing different explorer unit needs review; refusing to overwrite")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text)
    subprocess.run(["systemctl", "--user", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "--user", "enable", "--now", UNIT], check=True)
    subprocess.run(["systemctl", "--user", "show", UNIT, "--property=ActiveState,SubState,MainPID,UnitFileState"], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["serve", "once", "status", "health", "pause", "resume", "render-unit", "install", "ensure", "install-cron"])
    parser.add_argument("--codex", default=shutil.which("codex"))
    args = parser.parse_args()
    if args.action == "status":
        print(json.dumps(read_json(WORK / "runtime/status.json"), indent=2))
        print("A heartbeat is recorded state, not independent proof of process liveness.")
        return 0
    if args.action == "health":
        result = health()
        print(json.dumps(result, indent=2))
        return 0 if result["worker_host_pid"] else 1
    if args.action == "pause":
        pause()
        return 0
    if not args.codex or not Path(args.codex).is_file():
        parser.error("An installed Codex executable is required")
    if args.action == "render-unit":
        print(unit_text(ROOT, args.codex))
        return 0
    if args.action == "install":
        install(args.codex)
        return 0
    if args.action == "install-cron":
        install_cron(args.codex)
        return 0
    if args.action == "ensure":
        ensure(args.codex)
        return 0
    if args.action == "resume":
        (WORK / "runtime/paused").unlink(missing_ok=True)
        ensure(args.codex)
        return 0
    worker = Worker(WORK, args.codex, PROMPT.read_text(), prompt_path=PROMPT)
    signal.signal(signal.SIGTERM, worker.stop)
    signal.signal(signal.SIGINT, worker.stop)
    return worker.serve(once=args.action == "once")


if __name__ == "__main__":
    sys.exit(main())
