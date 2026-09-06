#!/usr/bin/env python3
"""[ZK60-CL11] Fail-closed operator preflight for the RTX 5090 campaign.

Every check must PASS for `go`; a missing fact fails the check that needs it.
Nothing here builds, installs, changes a driver, power-caps a card, launches a
proof or rents anything. With `--facts-json` no probe runs at all (the tests
and dry runs use that); otherwise the read-only probes below are taken once.

Checks (each carries its evidence and, when it fails, the reason):
  device_present            exactly one selected GPU, named
  compute_capability        in the supported table AND has an `arch_str` arm
  driver_version            >= 570 for Blackwell (compute >= 10.0); recorded otherwise
  nvrtc_toolkit             >= 12.8 for Blackwell (sm_100/sm_120 codegen); recorded otherwise
  cudarc_feature            cuda-12080 for Blackwell (the driver-API binding)
  device_idle               <= 1024 MiB used, no compute processes (the collector's rule)
  host_memory               MemAvailable >= the shape's requirement (64 GiB for full coverage)
  host_idle                 heavy lock free, load average below half the CPUs
  source_identity           git HEAD recorded, tracked tree clean
  binary_identity           binary present, GPU-featured, newer than every source
  shape_supported           export sidecar dims/profile cover the request
  planner_margin            chunked W component + measured reserve <= margin x VRAM
  verified_artifact         a green byte-gate log newer than the binary
  coverage_eligibility      a target-eligible claim needs full coverage and no seed

The runbook's order is enforced, not re-derived: driver first, then NVRTC,
then the cudarc feature (BLACKWELL_5090_RUNBOOK.md §3a). The measurement
ladder it emits (`--emit-plan`) reuses scripts/hashline_benchmark.py for the
>= 20 warm-run p50/p95 collection; it does not define a new clock. The
collector HOLDS /tmp/zk-heavy.lock itself, so its stages are detached
without an outer flock (an outer one deadlocks against it); the raw-binary
stages take the lock outside, the standing way.
"""

import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)

MIB = 1024 ** 2
GIB = 1024 ** 3

SUPPORTED_CC = {"8.9": "Ada (RTX 40 laptop, every measurement to date)",
                "9.0": "Hopper (H100)",
                "10.0": "datacenter Blackwell (B100/B200)",
                "12.0": "consumer Blackwell (RTX 50-series)"}
# Both Blackwell families (sm_100 datacenter, sm_120 consumer) get their codegen
# in CUDA 12.8 and need the R570 driver branch; binding the gates at 12.0 only
# would leave a B100/B200 row fail-open.
BLACKWELL_MIN_CC = (10, 0)
BLACKWELL_MIN_DRIVER = (570,)
BLACKWELL_MIN_NVRTC = (12, 8)
BLACKWELL_CUDARC = "cuda-12080"
IDLE_DEVICE_USED_MIB = 1024          # scripts/hashline_benchmark.py validate_gpu
# Host memory by what the statement covers (runbook §3): the 8B FFN-only P3
# pass peaked at 13.97 GB RSS on the laptop; the full-layer statement wants
# >= 64 GB; narrow shapes (the 125M ladder) fit in a few GiB.
HOST_MIN_GIB = {"narrow": 4, "ffn-only": 16, "full": 64}
DEFAULT_MARGIN_FRACTION = 0.8
# [MEASURED, WSL-BOX, RTX 4070, one Mistral layer P3, HL_GPU_CHUNK_ROWS=128,
# FFN-only] whole-layer VRAM peak 5,182 MB against a chunked W component of
# 1,562.5 MiB (ZK60_CLAUDE_GPU.md rung 5): the non-commit residency is the
# difference. It is a laptop-measured constant, not a model of the 5090.
DEFAULT_RESERVE_MIB = 5182 - 1563
FLOORS_GREEN = "ALL CL1 FLOORS GREEN"
FLOORS_CASES = re.compile(r"^executed byte-gate cases: (\d+) \(expect (\d+)\)$", re.MULTILINE)


class PreflightError(ValueError):
    pass


# ----------------------------------------------------------------- versions

def version_tuple(text):
    parts = re.findall(r"\d+", str(text or ""))
    return tuple(int(p) for p in parts[:3]) if parts else ()


def cc_tuple(text):
    t = version_tuple(text)
    return t if len(t) == 2 else ()


def at_least(found, minimum):
    """Version comparison with the found tuple zero-padded to the minimum's
    length: Python orders (570,) BELOW (570, 0), so a bare "570" driver string
    would otherwise fail a (570, 0) floor it clearly meets. Empty = unknown = no."""
    if not found:
        return False
    head = tuple(found[:len(minimum)])
    return head + (0,) * (len(minimum) - len(head)) >= tuple(minimum)


# ------------------------------------------------------------------- probes

def _run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=60).stdout


def _read_text(path, errors="strict"):
    # every probe reads through here so no file handle outlives its probe
    # (unittest surfaces unclosed handles as ResourceWarnings)
    with open(path, encoding="utf-8", errors=errors) as fh:
        return fh.read()


def probe_gpus(index):
    rows = []
    try:
        out = _run(["nvidia-smi", "--query-gpu=index,name,uuid,driver_version,compute_cap,memory.total,memory.used",
                    "--format=csv,noheader,nounits"])
    except (OSError, subprocess.SubprocessError):
        return rows
    for line in out.strip().splitlines():
        f = [x.strip() for x in line.split(",")]
        if len(f) != 7:
            continue
        rows.append({"index": int(f[0]), "name": f[1], "uuid": f[2], "driver": f[3], "compute_cap": f[4],
                     "memory_total_mib": int(f[5]), "memory_used_mib": int(f[6])})
    return [r for r in rows if r["index"] == index]


def probe_compute_apps():
    try:
        out = _run(["nvidia-smi", "--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"])
    except (OSError, subprocess.SubprocessError):
        return None
    apps = []
    for line in out.strip().splitlines():
        f = [x.strip() for x in line.split(",")]
        if len(f) == 2 and f[0].isdigit():
            apps.append({"pid": int(f[0]), "used_mib": int(f[1]) if f[1].isdigit() else None})
    return apps


def probe_nvrtc(cuda_root):
    lib = os.path.join(cuda_root, "lib64")
    versions = []
    try:
        for name in os.listdir(lib):
            m = re.match(r"libnvrtc-builtins\.so\.(\d+\.\d+)$", name)
            if m:
                versions.append(m.group(1))
    except OSError:
        return None
    return max(versions, key=version_tuple) if versions else None


def probe_cudarc_feature(repo):
    try:
        text = _read_text(os.path.join(repo, "hashline", "Cargo.toml"))
    except OSError:
        return None
    m = re.search(r'"(cuda-\d{5})"', text)
    return m.group(1) if m else None


def probe_arch_arms(repo):
    try:
        text = _read_text(os.path.join(repo, "hashline", "src", "gpu", "cuda.rs"))
    except OSError:
        return {}
    return {f"{a}.{b}": arch for a, b, arch in re.findall(r'\((\d+),\s*(\d+)\)\s*=>\s*"(compute_\d+)"', text)}


def probe_host():
    info = {"mem_total_kib": None, "mem_available_kib": None, "loadavg1": None, "logical_cpus": os.cpu_count()}
    try:
        for line in _read_text("/proc/meminfo").splitlines():
            if line.startswith("MemTotal:"):
                info["mem_total_kib"] = int(line.split()[1])
            elif line.startswith("MemAvailable:"):
                info["mem_available_kib"] = int(line.split()[1])
        info["loadavg1"] = float(_read_text("/proc/loadavg").split()[0])
    except (OSError, ValueError, IndexError):
        pass
    return info


def probe_heavy_lock(path="/tmp/zk-heavy.lock"):
    """True if the lock is FREE. Non-blocking, released immediately, never unlinked."""
    try:
        with open(path, "a") as fh:
            try:
                fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                return False
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
            return True
    except OSError:
        return None


def probe_git(repo):
    try:
        head = _run(["git", "--no-pager", "-C", repo, "rev-parse", "HEAD"]).strip()
        branch = _run(["git", "--no-pager", "-C", repo, "rev-parse", "--abbrev-ref", "HEAD"]).strip()
        status = _run(["git", "--no-pager", "-C", repo, "status", "--porcelain", "--untracked-files=no"])
    except (OSError, subprocess.SubprocessError):
        return None
    return {"head": head, "branch": branch, "dirty_paths": [l[3:] for l in status.splitlines() if l.strip()]}


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def probe_binary(path):
    if not path or not os.path.isfile(path):
        return {"path": path, "exists": False}
    st = os.stat(path)
    with open(path, "rb") as fh:
        blob = fh.read()
    return {"path": path, "exists": True, "size": st.st_size, "mtime": st.st_mtime, "sha256": hashlib.sha256(blob).hexdigest(),
            "mentions_nvrtc": b"nvrtc" in blob, "mentions_cu_module_load": b"cuModuleLoadData" in blob}


def probe_sources(repo):
    newest, newest_path = 0.0, None
    roots = [os.path.join(repo, "hashline", "src"), os.path.join(repo, "hashline", "Cargo.toml"),
             os.path.join(repo, "hashline", "build.rs")]
    for root in roots:
        if os.path.isfile(root):
            candidates = [root]
        elif os.path.isdir(root):
            candidates = [os.path.join(d, f) for d, _, files in os.walk(root) for f in files]
        else:
            continue
        for p in candidates:
            try:
                m = os.stat(p).st_mtime
            except OSError:
                continue
            if m > newest:
                newest, newest_path = m, os.path.relpath(p, repo)
    return {"newest_mtime": newest, "newest_path": newest_path}


def probe_export(path):
    side = os.path.join(path or "", "digests.txt")
    if not path or not os.path.isfile(side):
        return {"path": path, "exists": False}
    text = _read_text(side, errors="replace")
    dims = re.findall(r"^0+ dims (\d+) (\d+) (\d+) (\d+)\s*$", text, re.MULTILINE)
    profile = re.search(r"^0+ profile (\S+)\s*$", text, re.MULTILINE)
    model = re.search(r"^0+ model (\S+)\s*$", text, re.MULTILINE)
    return {"path": path, "exists": True, "sidecar_sha256": sha256_file(side),
            "dims": [int(x) for x in dims[0]] if len(dims) == 1 else None,
            "profile": profile.group(1) if profile else None, "model": model.group(1) if model else None}


def probe_floors_log(path):
    if not path or not os.path.isfile(path):
        return {"path": path, "exists": False}
    text = _read_text(path, errors="replace")
    m = FLOORS_CASES.search(text)
    done = path[:-4] + ".done" if path.endswith(".log") else None
    marker = None
    if done and os.path.isfile(done):
        try:
            marker = int(_read_text(done).strip())
        except (OSError, ValueError):
            marker = None
    return {"path": path, "exists": True, "mtime": os.stat(path).st_mtime, "green": FLOORS_GREEN in text,
            "cases": int(m.group(1)) if m else None, "cases_expected": int(m.group(2)) if m else None,
            "done_marker_exit": marker}


def gather_facts(args):
    return {"schema": 1, "gathered_at": time.time(), "gpus": probe_gpus(args.device_index),
            "compute_apps": probe_compute_apps(), "nvrtc_version": probe_nvrtc(args.cuda_root),
            "cudarc_feature": probe_cudarc_feature(args.repo), "arch_arms": probe_arch_arms(args.repo),
            "host": probe_host(), "heavy_lock_free": probe_heavy_lock(), "git": probe_git(args.repo),
            "binary": probe_binary(args.binary), "sources": probe_sources(args.repo),
            "export": probe_export(args.export), "floors_log": probe_floors_log(args.floors_log)}


# ---------------------------------------------------------------- evaluate

def _check(name, ok, evidence, reason=None):
    return {"check": name, "ok": bool(ok), "evidence": evidence, "reason": None if ok else reason}


def planner_margin(d, f, log_cols, inv_rate, chunk_rows, mode, device_total_mib, reserve_mib, fraction):
    """Chunked (or resident) W component from the CL3 planner plus the measured
    non-commit reserve, against a FRACTION of nominal VRAM. Nominal VRAM is not
    free memory; the fraction and the reserve are both explicit."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("hashline_memory_plan", os.path.join(_HERE, "hashline_memory_plan.py"))
    mp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mp)
    w = mp.weight_shape(d, f, log_cols)
    report = mp.commitment_plan(w["rows"], w["log_cols"], inv_rate, 256, None, None, 0, 0, None,
                                mode=mode, chunk_rows=chunk_rows)
    component_mib = report["component_peak_accounted_bytes"] / MIB
    need = component_mib + reserve_mib
    allow = device_total_mib * fraction
    return {"w_rows": w["rows"], "mode": mode, "chunk_rows": chunk_rows, "w_component_mib": round(component_mib, 1),
            "reserve_mib": reserve_mib, "reserve_basis": "measured whole-layer minus W component at Mistral width, chunk 128, FFN-only (laptop)",
            "need_mib": round(need, 1), "allowed_mib": round(allow, 1), "fraction": fraction,
            "device_total_mib": device_total_mib, "fits": need <= allow,
            "not_covered": ["pending attention/FFN state (not implemented; see ZK60_CLAUDE_PENDING_GPU.md)",
                            "inference engine residency when proving overlaps generation on the same card"]}


def evaluate(facts, args):
    checks = []
    gpus = facts.get("gpus") or []
    gpu = gpus[0] if len(gpus) == 1 else None
    checks.append(_check("device_present", gpu is not None and bool(gpu.get("name")),
                         {"selected": gpus}, "exactly one selected, named GPU is required"))

    cc = cc_tuple(gpu.get("compute_cap")) if gpu else ()
    cc_text = f"{cc[0]}.{cc[1]}" if cc else None
    arms = facts.get("arch_arms") or {}
    blackwell = bool(cc) and cc >= BLACKWELL_MIN_CC
    want_cc = cc_tuple(args.require_cc) if args.require_cc else ()
    cc_ok = bool(cc) and cc_text in SUPPORTED_CC and cc_text in arms and (not want_cc or cc == want_cc)
    checks.append(_check("compute_capability", cc_ok,
                         {"compute_cap": cc_text, "supported": SUPPORTED_CC.get(cc_text), "arch_arm": arms.get(cc_text),
                          "required": args.require_cc},
                         "compute capability must be in the supported table, have an arch_str arm in gpu/cuda.rs, "
                         "and match --require-cc when given"))

    drv = version_tuple(gpu.get("driver")) if gpu else ()
    drv_ok = bool(drv) and (not blackwell or at_least(drv, BLACKWELL_MIN_DRIVER))
    checks.append(_check("driver_version", drv_ok, {"driver": gpu.get("driver") if gpu else None,
                                                    "minimum_for_blackwell": ".".join(map(str, BLACKWELL_MIN_DRIVER))},
                         "Blackwell needs a host driver >= 570 (installed Windows-side; not doable from WSL)"))

    nv = version_tuple(facts.get("nvrtc_version"))
    nv_ok = bool(nv) and (not blackwell or at_least(nv, BLACKWELL_MIN_NVRTC))
    checks.append(_check("nvrtc_toolkit", nv_ok, {"nvrtc": facts.get("nvrtc_version"), "minimum_for_blackwell": "12.8",
                                                  "order": "driver FIRST, then NVRTC (runbook §3a): NVRTC 12.8 PTX does not load on driver 566"},
                         "Blackwell needs NVRTC >= 12.8 for sm_120 codegen, installed AFTER the driver"))

    feat = facts.get("cudarc_feature")
    feat_ok = bool(feat) and (not blackwell or feat == BLACKWELL_CUDARC)
    checks.append(_check("cudarc_feature", feat_ok, {"cudarc_feature": feat, "required_for_blackwell": BLACKWELL_CUDARC},
                         "hashline/Cargo.toml must select the cudarc binding matching the installed toolkit (cuda-12080 for Blackwell)"))

    apps = facts.get("compute_apps")
    used = gpu.get("memory_used_mib") if gpu else None
    idle_ok = gpu is not None and used is not None and used <= IDLE_DEVICE_USED_MIB and apps is not None and len(apps) == 0
    checks.append(_check("device_idle", idle_ok, {"memory_used_mib": used, "limit_mib": IDLE_DEVICE_USED_MIB, "compute_apps": apps},
                         "the device must be idle: <= 1024 MiB used and no compute processes; WSL does not return VRAM promptly"))

    host = facts.get("host") or {}
    avail = host.get("mem_available_kib")
    # `facts["export"]` may be null when the probe found nothing; a missing
    # fact fails its own check, it must not crash the evaluation.
    d_req = args.d_hint or ((facts.get("export") or {}).get("dims") or [0, 0, 0, 0])[1]
    host_band = "narrow" if d_req < 4096 else args.coverage
    host_min_gib = args.host_min_gib if args.host_min_gib is not None else HOST_MIN_GIB[host_band]
    host_ok = avail is not None and avail * 1024 >= host_min_gib * GIB
    checks.append(_check("host_memory", host_ok, {"mem_available_gib": None if avail is None else round(avail / 1024 / 1024, 2),
                                                  "required_gib": host_min_gib, "band": host_band,
                                                  "basis": "8B FFN-only P3 pass peaked at 13.97 GB RSS on the laptop; the full-layer statement wants >= 64 GB (runbook §3)"},
                         "not enough available host memory for this shape and coverage"))

    load = host.get("loadavg1")
    cpus = host.get("logical_cpus") or 0
    lock_free = facts.get("heavy_lock_free")
    host_idle_ok = lock_free is True and load is not None and cpus > 0 and load <= cpus / 2
    checks.append(_check("host_idle", host_idle_ok, {"heavy_lock_free": lock_free, "loadavg1": load, "logical_cpus": cpus},
                         "the heavy lock must be free and the 1-minute load average at most half the CPUs"))

    git = facts.get("git")
    src_ok = bool(git) and bool(git.get("head")) and not git.get("dirty_paths")
    checks.append(_check("source_identity", src_ok, git, "a recorded HEAD on a clean tracked tree is required; commit or stash first"))

    b = facts.get("binary") or {}
    s = facts.get("sources") or {}
    bin_ok = (b.get("exists") and b.get("mentions_nvrtc") and b.get("mtime") is not None and s.get("newest_mtime") is not None
              and b["mtime"] >= s["newest_mtime"])
    checks.append(_check("binary_identity", bool(bin_ok),
                         {"path": b.get("path"), "exists": b.get("exists"), "sha256": b.get("sha256"), "size": b.get("size"),
                          "gpu_featured": b.get("mentions_nvrtc"), "binary_mtime": b.get("mtime"),
                          "newest_source": s.get("newest_path"), "newest_source_mtime": s.get("newest_mtime")},
                         "the binary must exist, be the gpu-cuda build, and be newer than every source file (stale binary)"))

    ex = facts.get("export") or {}
    dims = ex.get("dims")
    shape_ok = (bool(dims) and ex.get("profile") == "v3-widened" and 1 <= args.layers <= dims[3]
                and 1 <= args.tokens <= dims[0] and args.tokens & (args.tokens - 1) == 0)
    checks.append(_check("shape_supported", shape_ok, {"export": ex.get("path"), "dims_tokens_d_f_layers": dims,
                                                       "profile": ex.get("profile"), "model": ex.get("model"),
                                                       "requested": {"layers": args.layers, "tokens": args.tokens}},
                         "the export must be a v3-widened sidecar covering the requested layers and power-of-two tokens"))

    if dims and gpu and gpu.get("memory_total_mib"):
        try:
            pm = planner_margin(dims[1], dims[2], args.log_cols, args.inv_rate, args.chunk_rows, args.chunk_mode,
                                gpu["memory_total_mib"], args.reserve_mib, args.margin_fraction)
            checks.append(_check("planner_margin", pm["fits"], pm,
                                 "the chunked W component plus the measured reserve exceeds the allowed fraction of VRAM"))
        except ValueError as error:
            checks.append(_check("planner_margin", False, {"error": str(error)}, "the planner refused this shape"))
    else:
        checks.append(_check("planner_margin", False, {"dims": dims, "gpu": gpu}, "no shape or device to plan against"))

    fl = facts.get("floors_log") or {}
    fl_ok = (fl.get("exists") and fl.get("green") and fl.get("cases") is not None and fl["cases"] == fl.get("cases_expected")
             and fl.get("done_marker_exit") == 0 and b.get("mtime") is not None and fl.get("mtime", 0) >= b["mtime"])
    checks.append(_check("verified_artifact", bool(fl_ok), fl,
                         "a green byte-gate floors log (all cases, exit marker 0) NEWER than the binary is required; run the gates on this binary first"))

    cov_ok = args.claim == "diagnostic" or (args.coverage == "full" and args.seed is None)
    checks.append(_check("coverage_eligibility", cov_ok, {"claim": args.claim, "coverage": args.coverage, "seed": args.seed,
                                                          "note": "existing FFN-only runs stay labelled diagnostic; a seeded row is ineligible in the collector"},
                         "a target-eligible claim needs full coverage and fresh randomness; FFN-only coverage cannot support it"))

    go = all(c["ok"] for c in checks)
    return {"schema": 1, "go": go, "blackwell": blackwell, "device": gpu,
            "request": {"layers": args.layers, "tokens": args.tokens, "privacy": args.privacy, "coverage": args.coverage,
                        "claim": args.claim, "seed": args.seed, "chunk_mode": args.chunk_mode, "chunk_rows": args.chunk_rows},
            "checks": checks, "failed": [c["check"] for c in checks if not c["ok"]],
            "does_not_authorize": ["renting or buying hardware", "installing a driver or toolkit", "a power cap",
                                   "any run while another job holds the heavy lock", "a target-eligible claim from FFN-only coverage"]}


# -------------------------------------------------------------------- plan

HEAVY_LOCK = "/tmp/zk-heavy.lock"
# The no-hangup wrapper (CLAUDE.md): setsid+nohup survives the session, the
# .done marker carries the exit code for whoever resumes. Two forms:
#   OUTER  flock taken by the wrapper — raw hashline runs and the floors script.
#   INNER  no flock in the wrapper — hashline_benchmark.py `run` holds the same
#          lock itself (its heavy_lock, "detached wrappers must invoke it
#          directly without holding the same lock outside"); a second flock on
#          the same file from the parent would block the child forever.
_WRAP_OUTER = "setsid nohup bash -c 'flock " + HEAVY_LOCK + " {cmd} >> {log} 2>&1; echo $? > {stem}.done' >/dev/null 2>&1 &"
_WRAP_INNER = "setsid nohup bash -c '{cmd} >> {log} 2>&1; echo $? > {stem}.done' >/dev/null 2>&1 &"


def detached(cmd, stem, lock_outside):
    wrap = _WRAP_OUTER if lock_outside else _WRAP_INNER
    return {"detached": wrap.format(cmd=cmd, log=f"{stem}.log", stem=stem), "done_marker": f"{stem}.done",
            "lock": (f"{HEAVY_LOCK} taken by the wrapper (flock)" if lock_outside
                     else f"{HEAVY_LOCK} taken INSIDE by hashline_benchmark.py run; an outer flock would deadlock")}


def campaign_plan(args, facts, report):
    """The ordered ladder. Every heavy stage is a DETACHED job under the shared
    lock with a .done marker; nothing in it starts until the preflight is go."""
    repo = args.repo
    binary = args.binary or f"{repo}/hashline/target-gpu/release/hashline"
    export = args.export or "<export dir>"
    bench = f"python3 {repo}/scripts/hashline_benchmark.py"
    shape = f"--layers {args.layers} --tokens {args.tokens}"
    floors = f"{repo}/results/cl1_floors.sh <scratch>"
    parity = f"HL_GPU=1 {binary} pass 1 512 --threads 8 --p3 --seed 1 --profile v3 --export {export} --proof-out <scratch>/p3.proof"
    predict = f"HL_GPU=1 {binary} pass 32 512 --zk --seed 1 --profile v3 --export {export} --proof-out <scratch>/p1-32.proof"
    p1 = f"{bench} run --binary {binary} --export {export} {shape} --privacy P1 --device gpu --gpu-index {args.device_index} --warm-runs 20 --out <new dir>"
    p3 = f"{bench} run --binary {binary} --export {export} {shape} --privacy P3 --device gpu --gpu-index {args.device_index} --warm-runs 20 --out <new dir>"
    stages = [
        {"stage": 0, "name": "byte gates on the new device (BEFORE any timing)", "gate": "12/12 byte gates, full SHA-256, gpu: ON",
         "heavy": True, "command": floors, **detached(floors, f"{repo}/results/5090_floors", lock_outside=True),
         "why": "a digest that moves on new hardware is a codegen bug, not a hardware finding (runbook §4)"},
        {"stage": 1, "name": "single-layer CPU/GPU parity ladder at Mistral width", "gate": "P1 and P3 digests equal the laptop's (b5da6c38.., 190e85a1..)",
         "heavy": True, "command": parity, **detached(parity, f"{repo}/results/5090_parity_l1", lock_outside=True),
         "why": "CL1 rung 4's byte identity across devices, extended to the 5090"},
        {"stage": 2, "name": "card-size prediction (runbook §6)", "gate": "layers 1-31 no longer slower than layer 0; VRAM peak < total",
         "heavy": True, "command": predict, **detached(predict, f"{repo}/results/5090_predict_32", lock_outside=True),
         "why": "the laptop's 8,585 MB spill is the cheapest thing the card settles; run once, detached"},
        {"stage": 3, "name": f"P1 {args.layers}x{args.tokens} prefill, cold + >= 20 warm", "gate": "measurement_eligible true; p50/p95 nearest-rank; proof_ready clock",
         "heavy": True, "command": p1, **detached(p1, f"{repo}/results/5090_p1_warm20", lock_outside=False),
         "why": "the fast tier, the headline track per the second ruling"},
        {"stage": 4, "name": f"P3 {args.layers}x{args.tokens} prefill, cold + >= 20 warm (SEPARATE job, nvidia-smi idle first)", "gate": "as stage 3; P3 recommits weights every run",
         "heavy": True, "command": p3, **detached(p3, f"{repo}/results/5090_p3_warm20", lock_outside=False),
         "why": "never chain a GPU pass behind another in one script (2026-09-04 standing rule)"},
        {"stage": 5, "name": "comparability row at 450 W", "gate": "same as stage 3 with `nvidia-smi -pl 450` recorded in the manifest",
         "heavy": True, "command": "(operator) nvidia-smi -pl 450; then stage 3 again into a new out dir; then restore the stock limit",
         **detached(p1.replace("<new dir>", "<new dir, 450 W>"), f"{repo}/results/5090_p1_warm20_450w", lock_outside=False),
         "why": "not for the contract (amended to <= 600 W); for continuity with every row measured before the ruling"},
        {"stage": 6, "name": "one-GPU inference/proving overlap", "gate": "generation, proof-ready and proof-lag clocks reported SEPARATELY",
         "heavy": False, "command": "NOT RUNNABLE IN THIS REPOSITORY: no generation harness exists; tokens are prefill rows. Define per ZK60_CLAUDE_5090.md §4 before running.",
         "why": "60 tok/s is a generation claim; proving alone on an idle card is an upper bound on it"},
    ]
    return {"schema": 1, "preflight_go": report["go"], "ordered_stages": stages,
            "labels": ["[5090-BOX]", "[QUIET]", "[MEASURED]", "diagnostic until coverage is full"],
            "statistic": "p95 nearest-rank over >= 20 warm runs, p50 alongside, cold reported separately (MEASUREMENT_PROTOCOL.md §1)",
            "device": (facts.get("gpus") or [None])[0]}


# --------------------------------------------------------------------- cli

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=_ROOT)
    parser.add_argument("--binary", help="the gpu-cuda hashline binary")
    parser.add_argument("--export", help="v3-widened export directory")
    parser.add_argument("--floors-log", help="the byte-gate log to accept as artifact verification")
    parser.add_argument("--cuda-root", default="/home/victor/cuda-root")
    parser.add_argument("--device-index", type=int, default=0)
    parser.add_argument("--layers", type=int, default=32)
    parser.add_argument("--tokens", type=int, default=512)
    parser.add_argument("--privacy", choices=("P0", "P1", "P3"), default="P1")
    parser.add_argument("--coverage", choices=("ffn-only", "full"), default="ffn-only")
    parser.add_argument("--claim", choices=("diagnostic", "target"), default="diagnostic")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--require-cc", help="e.g. 12.0 to insist on a Blackwell part")
    parser.add_argument("--host-min-gib", type=int)
    parser.add_argument("--d-hint", type=int, help="model width when no export is given (host-memory rule)")
    parser.add_argument("--log-cols", type=int, default=14)
    parser.add_argument("--inv-rate", type=int, default=4)
    parser.add_argument("--chunk-mode", choices=("chunked", "resident"), default="chunked")
    parser.add_argument("--chunk-rows", type=int, default=128)
    parser.add_argument("--reserve-mib", type=int, default=DEFAULT_RESERVE_MIB)
    parser.add_argument("--margin-fraction", type=float, default=DEFAULT_MARGIN_FRACTION)
    parser.add_argument("--facts-json", help="use these facts instead of probing (dry run / tests)")
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--out", help="write the report JSON here (a new file)")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if not 0 < args.margin_fraction <= 1:
            raise PreflightError("margin fraction must be in (0, 1]")
        if args.reserve_mib < 0 or args.chunk_rows < 1:
            raise PreflightError("reserve and chunk rows must be nonnegative / positive")
        # Refuse an existing --out BEFORE probing: a refused write should not
        # cost a probe pass, and the report must never land on top of an old one.
        if args.out and os.path.exists(args.out):
            raise PreflightError(f"refusing to overwrite {args.out}")
        if args.facts_json:
            with open(args.facts_json, encoding="utf-8") as fh:
                facts = json.load(fh)
            facts["source"] = "injected"
        else:
            facts = gather_facts(args)
            facts["source"] = "probed"
        report = evaluate(facts, args)
        report["facts"] = facts
        if args.emit_plan:
            report["campaign_plan"] = campaign_plan(args, facts, report)
        text = json.dumps(report, indent=2, allow_nan=False)
        if args.out:
            # "x" keeps the no-overwrite promise even against a file that
            # appeared between the early check and this write.
            with open(args.out, "x", encoding="utf-8") as fh:
                fh.write(text + "\n")
        print(text)
    except (PreflightError, OSError, ValueError) as error:
        parser.exit(2, f"5090 preflight: {error}\n")
    return 0 if report["go"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
