#!/usr/bin/env python3
"""Is the "one thread" verifier time of the D55 A/B test a one-thread time? One process per arm, on the lib test binary.

usage: run_vt.py [--detached] <label> <blocks> <arms, comma separated, in run order> [max secs per arm, default 900]
       e.g. run_vt.py smoke 2 p,t1
            run_vt.py set1 32 p,d,t1,t1d,t1d,t1,d,p

Arms (environment of the whole test process):
  p    nothing set: the global thread pool at its default size, the sparse column loop on (the code's default)
  d    HL_A26_PCS_SPARSE=0: the dense column loop, default pool
  t1   RAYON_NUM_THREADS=1: a global pool of one thread, sparse loop on
  t1d  both

Each arm is one guarded GPU job running the ignored test d55_ab_one_request_serial_against_forks with
HL_D55_PROFILE=W16R2_8B_T128_H24, HL_D55_L=<blocks>, HL_D55_WORKERS=6, HL_D55_PASSES=1. Every HL_ and RAYON_ variable
of the caller's shell is removed first. Read from each log: the line "serial: verified (D12a verifier, one thread)
in X s" and the line "forks N6: verified (D55 verifier, 6 threads) in Y s".
With "--detached" first, the runner re-starts itself in a new session and waits for it.
Writes raw/<label>_<k>_<arm>.log, .guard.json, .done, raw/<label>.status_pre.txt and raw/<label>.results.json.
No source file changes.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = str(ROOT / "scripts/zk60_resource_guard.py")
BIN = ROOT / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
PIN = HERE / "binary.sha256"
TEST = "private_block::run::fork::tests::d55_ab_one_request_serial_against_forks"
ENV = {
    "HL_GPU": "1", "HL_GPU_REQUIRED": "1", "HL_PB_ORACLE": "0", "HL_METAL_TIMING": "0",
    "HL_D55_PROFILE": "W16R2_8B_T128_H24", "HL_D55_WORKERS": "6", "HL_D55_PASSES": "1", "HL_A19_BUDGET_GIB": "32",
}
ARMS = {
    "p": {},
    "d": {"HL_A26_PCS_SPARSE": "0"},
    "t1": {"RAYON_NUM_THREADS": "1"},
    "t1d": {"RAYON_NUM_THREADS": "1", "HL_A26_PCS_SPARSE": "0"},
}
NEED_GIB, CAP_GIB = "80", "110"
RX = {
    "serial_verify_s": re.compile(r"serial: verified \(D12a verifier, one thread\) in ([0-9.]+) s"),
    "forks6_verify_s": re.compile(r"forks N6: verified \(D55 verifier, 6 threads\) in ([0-9.]+) s"),
    "serial_cold_wall_s": re.compile(r"serial cold \(kernel compiles\): wall ([0-9.]+) s"),
    "receipt_bytes": re.compile(r"serial pass 0 \(serial first\): wall [0-9.]+ s = [0-9.]+ proved tok/s; receipt ([0-9]+) B"),
}


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def out(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> int:
    argv = sys.argv[1:]
    RAW.mkdir(exist_ok=True)
    if argv and argv[0] == "--detached":
        label = argv[1]
        with (RAW / f"{label}.runner.txt").open("w") as f:
            p = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), *argv[1:]], stdin=subprocess.DEVNULL,
                                 stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        rc = p.wait()
        print(f"{label}: runner exit {rc}")
        rj = RAW / f"{label}.results.json"
        if rj.exists():
            for r in json.loads(rj.read_text())["runs"]:
                print({k: r.get(k) for k in ("k", "arm", "guard_exit", "serial_verify_s", "forks6_verify_s", "wall_s")})
        return rc
    label, blocks, order = argv[0], argv[1], argv[2].split(",")
    max_secs = argv[3] if len(argv) > 3 else "900"
    assert all(a in ARMS for a in order), order
    if Path("/tmp/HOLD").exists():
        print("ABORT: /tmp/HOLD exists")
        return 99
    got = sha(BIN)
    if PIN.exists() and PIN.read_text().split()[0] != got:
        print(f"ABORT: the binary's hash differs from binary.sha256: {got}")
        return 98
    rj = RAW / f"{label}.results.json"
    if rj.exists():
        print(f"ABORT: label {label} was used before")
        return 97
    base = {k: v for k, v in os.environ.items() if not (k.startswith("HL_") or k.startswith("RAYON_") or k == "ZK60_GUARD_POLL_SECS")}
    base["PYTHONDONTWRITEBYTECODE"] = "1"
    (RAW / f"{label}.status_pre.txt").write_text(
        f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nbinary {BIN} sha256 {got}\nblocks {blocks}\norder {order}\n"
        f"env {ENV}\narms {ARMS}\n--- guard status ---\n{out([sys.executable, '-B', GUARD, 'status'])}"
        f"--- sysctl -n vm.loadavg ---\n{out(['sysctl', '-n', 'vm.loadavg'])}"
        f"--- sysctl -n hw.ncpu ---\n{out(['sysctl', '-n', 'hw.ncpu'])}"
        f"--- pgrep -fl ds4-bench ---\n{out(['pgrep', '-fl', 'ds4-bench']) or '(none)'}\n")
    runs = []
    rc_all = 0
    for k, arm in enumerate(order, 1):
        env = dict(base)
        env.update(ENV)
        env["HL_D55_L"] = blocks
        env.update(ARMS[arm])
        stem = RAW / f"{label}_{k}_{arm}"
        log, gj, done = Path(f"{stem}.log"), Path(f"{stem}.guard.json"), Path(f"{stem}.done")
        cmd = [sys.executable, "-B", GUARD, "run", "--class", "gpu", "--label", f"claude-vt-{label}-{k}-{arm}", "--need-gib", NEED_GIB,
               "--cap-gib", CAP_GIB, "--max-secs", max_secs, "--wait-secs", "3600", "--log", str(log), "--done", str(done),
               "--result-json", str(gj), "--", str(BIN), "--ignored", "--exact", "--nocapture", TEST]
        t0 = time.time()
        print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {label} run {k} arm {arm}", flush=True)
        cp = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL)
        rec = {"k": k, "arm": arm, "guard_exit": cp.returncode, "wall_s": round(time.time() - t0, 1),
               "started_utc": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(t0)), "loadavg_after": out(['sysctl', '-n', 'vm.loadavg']).strip()}
        text = log.read_text(errors="replace") if log.exists() else ""
        for name, rx in RX.items():
            m = rx.findall(text)
            rec[name] = (float(m[0]) if name != "receipt_bytes" else int(m[0])) if len(m) == 1 else (None if not m else m)
        rec["test_ok"] = "test result: ok. 1 passed" in text
        runs.append(rec)
        print(f"    guard exit {cp.returncode}; serial verify {rec['serial_verify_s']} s; forks verify {rec['forks6_verify_s']} s; "
              f"test ok {rec['test_ok']}", flush=True)
        rj.write_text(json.dumps({"label": label, "blocks": int(blocks), "binary_sha256": got, "order": order, "runs": runs}, indent=1))
        if cp.returncode != 0 or not rec["test_ok"]:
            rc_all = cp.returncode or 1
            print("    stopping: a run failed; the set is void", flush=True)
            break
    return rc_all


if __name__ == "__main__":
    sys.exit(main())
