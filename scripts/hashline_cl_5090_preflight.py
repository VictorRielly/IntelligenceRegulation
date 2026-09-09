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
  source_identity           git HEAD recorded, tracked tree clean; [CL21] the extracted
                            core (zkp-core/: Cargo.toml, src/, the example) present with
                            an empty delta, both crates' tree ids and lockfiles readable
  binary_identity           binary present, GPU-featured, newer than every source (of
                            BOTH crates), digest PRESENT and equal to the run manifest's
                            GPU binary
  shape_supported           export sidecar dims/profile cover the request
  planner_margin            chunked W component + measured reserve <= margin x VRAM
                            (and <= --memory-budget-mib when given)
  verified_artifact         a CL13 run manifest the gates validator accepts, whose
                            HEAD is the current HEAD and whose GPU binary is this one;
                            [CL21] whose recorded crate tree ids (hashline, zkp-core)
                            and Cargo.lock hashes are the tree in hand's — a manifest
                            that records none cannot be bound and refuses
  coverage_eligibility      a target-eligible claim needs RECORDED full coverage and
                            decoded full-relation verification, and no seed; the
                            --coverage flag cannot supply coverage

[ZK60-CL13] Codex's round-9 review reproduced four acceptances of the CL11
version: an absent binary digest, an unrelated binary digest, zero
expected/executed floor cases and flag-only `--coverage full --claim target`
all returned go. `verified_artifact` then read a green substring, a case
count printed by the same script, a marker and an mtime; `binary_identity`
never looked at the digest; `coverage_eligibility` trusted the flag. The
evidence is now the run manifest written by results/cl1_floors.sh through
scripts/hashline_cl_gpu_gates.py (versioned suite, per-case exits/verdicts/
digests, a computed verdict), bound here to the HEAD and binary in hand.
`--floors-log` remains only as a deprecated hint; it can never pass the check.

The runbook's order is enforced, not re-derived: driver first, then NVRTC,
then the cudarc feature (BLACKWELL_5090_RUNBOOK.md §3a). The measurement
ladder it emits (`--emit-plan`) reuses scripts/hashline_benchmark.py for the
>= 20 warm-run p50/p95 collection; it does not define a new clock. The
collector HOLDS /tmp/zk-heavy.lock itself, so its stages are detached
without an outer flock (an outer one deadlocks against it); the raw-binary
stages take the lock outside, the standing way. Every emitted command is
shlex-quoted and carries the requested shape, the thread count and the
memory lever (HL_GPU_CHUNK_ROWS, the chunk height the planner's budget check
was made with); the byte-gate stage runs the suite's FROZEN shape, the
parity stage its one-layer gate shape, both by definition, not by default.
"""

import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)


def _gates():
    """The CL13 suite/manifest module, loaded beside this file (no package)."""
    spec = importlib.util.spec_from_file_location("hashline_cl_gpu_gates", os.path.join(_HERE, "hashline_cl_gpu_gates.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

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
    dirty = [l[3:] for l in status.splitlines() if l.strip()]
    # [CL21] the core's dirty paths named apart: they are build inputs of the binary
    return {"head": head, "branch": branch, "dirty_paths": dirty,
            "core_dirty_paths": [p for p in dirty if p.startswith("zkp-core/")]}


def probe_source_identity(repo):
    """[CL21] both crates' tree ids, deltas, lockfile hashes and the core's
    presence, read by the gates module (the same code that wrote them into
    the manifest). None when the repo cannot be read at all."""
    try:
        return _gates().probe_source_identity(repo)
    except (OSError, ValueError):
        return None


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


SOURCE_ROOTS = {
    # [CL21] both crates: zkp-core is a path dependency of hashline, so its
    # sources and both lockfiles are inputs of the binary being qualified
    "hashline": [("hashline", "src"), ("hashline", "Cargo.toml"), ("hashline", "Cargo.lock"), ("hashline", "build.rs")],
    "zkp_core": [("zkp-core", "src"), ("zkp-core", "Cargo.toml"), ("zkp-core", "Cargo.lock"), ("zkp-core", "examples")],
}


def probe_sources(repo):
    newest, newest_path = 0.0, None
    crates = {}
    for crate, roots in SOURCE_ROOTS.items():
        c_newest, c_path, seen = 0.0, None, 0
        for parts in roots:
            root = os.path.join(repo, *parts)
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
                seen += 1
                if m > c_newest:
                    c_newest, c_path = m, os.path.relpath(p, repo)
        crates[crate] = {"newest_mtime": c_newest, "newest_path": c_path, "files": seen}
        if c_newest > newest:
            newest, newest_path = c_newest, c_path
    core = os.path.join(repo, "zkp-core")
    return {"newest_mtime": newest, "newest_path": newest_path, "crates": crates,
            "zkp_core_present": (os.path.isfile(os.path.join(core, "Cargo.toml")) and os.path.isdir(os.path.join(core, "src"))
                                 and os.path.isfile(os.path.join(core, "examples", "public_sumcheck.rs")))}


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


def probe_run_manifest(path):
    """[ZK60-CL13] The floors run manifest as a fact: loaded, not judged here
    (the evaluation runs the gates validator on it)."""
    if not path or not os.path.isfile(path):
        return {"path": path, "exists": False}
    try:
        manifest = json.loads(_read_text(path))
    except ValueError as error:
        return {"path": path, "exists": True, "error": f"not a JSON document: {error}"}
    return {"path": path, "exists": True, "mtime": os.stat(path).st_mtime, "manifest": manifest}


def gather_facts(args):
    return {"schema": 1, "gathered_at": time.time(), "gpus": probe_gpus(args.device_index),
            "compute_apps": probe_compute_apps(), "nvrtc_version": probe_nvrtc(args.cuda_root),
            "cudarc_feature": probe_cudarc_feature(args.repo), "arch_arms": probe_arch_arms(args.repo),
            "host": probe_host(), "heavy_lock_free": probe_heavy_lock(), "git": probe_git(args.repo),
            "source_identity": probe_source_identity(args.repo),
            "binary": probe_binary(args.binary), "sources": probe_sources(args.repo),
            "export": probe_export(args.export), "floors_log": probe_floors_log(args.floors_log),
            "run_manifest": probe_run_manifest(args.run_manifest)}


# ---------------------------------------------------------------- evaluate

def _check(name, ok, evidence, reason=None):
    return {"check": name, "ok": bool(ok), "evidence": evidence, "reason": None if ok else reason}


def planner_margin(d, f, log_cols, inv_rate, chunk_rows, mode, device_total_mib, reserve_mib, fraction, budget_mib=None):
    """Chunked (or resident) W component from the CL3 planner plus the measured
    non-commit reserve, against a FRACTION of nominal VRAM — and against an
    explicit --memory-budget-mib when one is given (the smaller wins). Nominal
    VRAM is not free memory; the fraction, the reserve and the budget are all
    explicit. The chunk height this check was made with is the memory lever
    every emitted command carries (HL_GPU_CHUNK_ROWS)."""
    spec = importlib.util.spec_from_file_location("hashline_memory_plan", os.path.join(_HERE, "hashline_memory_plan.py"))
    mp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mp)
    w = mp.weight_shape(d, f, log_cols)
    report = mp.commitment_plan(w["rows"], w["log_cols"], inv_rate, 256, None, None, 0, 0, None,
                                mode=mode, chunk_rows=chunk_rows)
    component_mib = report["component_peak_accounted_bytes"] / MIB
    need = component_mib + reserve_mib
    allow = device_total_mib * fraction
    if budget_mib is not None:
        allow = min(allow, budget_mib)
    return {"w_rows": w["rows"], "mode": mode, "chunk_rows": chunk_rows, "w_component_mib": round(component_mib, 1),
            "reserve_mib": reserve_mib, "reserve_basis": "measured whole-layer minus W component at Mistral width, chunk 128, FFN-only (laptop)",
            "need_mib": round(need, 1), "allowed_mib": round(allow, 1), "fraction": fraction, "memory_budget_mib": budget_mib,
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
    # [CL21] the tree in hand is BOTH crates: the core must be present with an
    # empty delta and a tree id, and both lockfiles must be readable, or there
    # is no identity to bind the manifest to.
    si = facts.get("source_identity") if isinstance(facts.get("source_identity"), dict) else None
    si_crates = (si or {}).get("crates") or {}
    si_locks = (si or {}).get("lockfiles") or {}
    core = si_crates.get("zkp_core") or {}
    identity_errors = _gates().source_identity_errors(si) if si is not None else ["source identity unavailable"]
    ident_ok = not identity_errors
    src_ok = bool(git) and bool(git.get("head")) and not git.get("dirty_paths") and ident_ok
    checks.append(_check("source_identity", src_ok,
                         {"git": git, "crates": {n: {"tree": (si_crates.get(n) or {}).get("tree"),
                                                     "dirty_delta_sha256": (si_crates.get(n) or {}).get("dirty_delta_sha256"),
                                                     "present": (si_crates.get(n) or {}).get("present")} for n in ("hashline", "zkp_core")},
                          "lockfiles": {n: (si_locks.get(n) or {}).get("sha256") for n in ("hashline", "zkp_core")},
                          "core_layout": {k: core.get(k) for k in ("manifest", "src", "example")},
                          "identity_readable": si is not None, "errors": identity_errors},
                         "a recorded HEAD on a clean tracked tree is required (commit or stash first), with the extracted core "
                         "(zkp-core/: Cargo.toml, src/, the example) present, both crates' tree ids and Cargo.lock hashes readable "
                         "and both deltas empty: the core is a build input of the binary"))

    b = facts.get("binary") or {}
    s = facts.get("sources") or {}
    # [ZK60-CL13] the manifest is read once here; verified_artifact runs the
    # validator on it, binary_identity binds the digest in hand to its record.
    rm = facts.get("run_manifest") or {}
    manifest = rm.get("manifest") if isinstance(rm.get("manifest"), dict) else None
    manifest_gpu_sha = ((manifest or {}).get("binaries") or {}).get("gpu", {}).get("sha256") if manifest else None
    digest = b.get("sha256")
    digest_ok = isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None
    bin_ok = (b.get("exists") and b.get("mentions_nvrtc") and b.get("mtime") is not None and s.get("newest_mtime") is not None
              and b["mtime"] >= s["newest_mtime"] and digest_ok and manifest_gpu_sha == digest)
    checks.append(_check("binary_identity", bool(bin_ok),
                         {"path": b.get("path"), "exists": b.get("exists"), "sha256": digest, "size": b.get("size"),
                          "gpu_featured": b.get("mentions_nvrtc"), "binary_mtime": b.get("mtime"),
                          "newest_source": s.get("newest_path"), "newest_source_mtime": s.get("newest_mtime"),
                          "digest_present": digest_ok, "manifest_gpu_sha256": manifest_gpu_sha,
                          "digest_matches_manifest": digest_ok and manifest_gpu_sha == digest},
                         "the binary must exist, be the gpu-cuda build, be newer than every source file (stale binary), "
                         "have a recorded sha256, and that sha256 must equal the run manifest's GPU binary digest "
                         "(an absent or unrelated digest is not an identity)"))

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
                                gpu["memory_total_mib"], args.reserve_mib, args.margin_fraction, args.memory_budget_mib)
            checks.append(_check("planner_margin", pm["fits"], pm,
                                 "the chunked W component plus the measured reserve exceeds the allowed fraction of VRAM (or the memory budget)"))
        except ValueError as error:
            checks.append(_check("planner_margin", False, {"error": str(error)}, "the planner refused this shape"))
    else:
        checks.append(_check("planner_margin", False, {"dims": dims, "gpu": gpu}, "no shape or device to plan against"))

    # [ZK60-CL13] verified_artifact = the gates validator accepts the manifest
    # AND its HEAD is the current HEAD AND its GPU binary is the one in hand.
    # The floors log is a deprecated hint: recorded, never sufficient.
    head = (git or {}).get("head") if git else None
    # [CL21] the binding also covers both crates' tree ids and lockfile hashes
    trees = locks = None
    if si is not None:
        trees, locks = _gates().identity_expectations(si)
    if manifest is None:
        verdict = {"ok": False, "reasons": [rm.get("error") or "no run manifest (--run-manifest); results/cl1_floors.sh writes one per run"],
                   "summary": {}}
    elif not head or not digest_ok or si is None:
        missing = [m for m, absent in (("no current HEAD", not head), ("no binary digest", not digest_ok),
                                       ("no source identity (crate trees / lockfiles unreadable)", si is None)) if absent]
        verdict = {"ok": False, "reasons": [" and ".join(missing) + ": the manifest cannot be bound to this box"], "summary": {}}
    else:
        verdict = _gates().validate_manifest(manifest, expect_head=head, expect_gpu_sha256=digest, require_production=True,
                                             expect_source=si)
    fl = facts.get("floors_log") or {}
    checks.append(_check("verified_artifact", verdict["ok"],
                         {"manifest_path": rm.get("path"), "manifest_present": manifest is not None, "validator": verdict,
                          "bound_to": {"head": head, "gpu_binary_sha256": digest, "crate_trees": trees, "lockfiles": locks},
                          "deprecated_floors_log_hint": {"path": fl.get("path"), "exists": fl.get("exists"), "green": fl.get("green"),
                                                         "note": "a floors log is a hint only; it cannot make this check pass"}},
                         "a run manifest the gates validator accepts (complete, every case green, negative controls present) "
                         "whose source HEAD is the current HEAD, whose GPU binary sha256 is this binary's, and whose recorded "
                         "crate tree ids and Cargo.lock hashes (hashline, zkp-core) are this tree's is required; a manifest "
                         "that records no crate identity (pre-CL21) cannot be bound. Run results/cl1_floors.sh on this checkout "
                         "and binary first. --floors-log is a deprecated hint and never sufficient on its own"))

    # [ZK60-CL13] the --coverage flag is a request, not evidence. A target-
    # eligible claim needs the run manifest (or an injected coverage fact) to
    # RECORD full coverage and decoded full-relation verification; the floors
    # suite records FFN-only coverage with the in-memory verifier, so no
    # current runner can satisfy this and the check refuses by construction.
    cov_ev = ((manifest or {}).get("coverage") if manifest else None) or facts.get("coverage_evidence") or {}
    recorded_full = cov_ev.get("coverage") == "full" and cov_ev.get("verification") == "decoded-full-relation"
    cov_ok = args.claim == "diagnostic" or (args.coverage == "full" and args.seed is None and recorded_full)
    checks.append(_check("coverage_eligibility", cov_ok, {"claim": args.claim, "coverage_requested": args.coverage, "seed": args.seed,
                                                          "coverage_recorded": cov_ev.get("coverage"), "verification_recorded": cov_ev.get("verification"),
                                                          "recorded_full_and_decoded": recorded_full,
                                                          "note": "existing FFN-only runs stay labelled diagnostic; a seeded row is ineligible in the collector"},
                         "a target-eligible claim needs RECORDED full coverage and decoded full-relation verification plus fresh "
                         "randomness; the --coverage flag cannot supply coverage, and the FFN-only floors suite records neither"))

    go = all(c["ok"] for c in checks)
    return {"schema": 1, "go": go, "blackwell": blackwell, "device": gpu,
            "request": {"layers": args.layers, "tokens": args.tokens, "privacy": args.privacy, "coverage": args.coverage,
                        "claim": args.claim, "seed": args.seed, "chunk_mode": args.chunk_mode, "chunk_rows": args.chunk_rows,
                        "threads": args.threads, "memory_budget_mib": args.memory_budget_mib},
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
def detached(cmd, stem, lock_outside):
    """[ZK60-CL13] the body is shlex-quoted as ONE `bash -c` argument, so a
    path with a space (already quoted inside `cmd`) survives the nesting; the
    old `bash -c '{cmd}'` template would have broken on the inner quotes."""
    log, done = f"{stem}.log", f"{stem}.done"
    body = (f"flock {HEAVY_LOCK} " if lock_outside else "") + f"{cmd} >> {shlex.quote(log)} 2>&1; echo $? > {shlex.quote(done)}"
    return {"detached": f"setsid nohup bash -c {shlex.quote(body)} >/dev/null 2>&1 &", "done_marker": done,
            "lock": (f"{HEAVY_LOCK} taken by the wrapper (flock)" if lock_outside
                     else f"{HEAVY_LOCK} taken INSIDE by hashline_benchmark.py run; an outer flock would deadlock")}


def campaign_plan(args, facts, report):
    """The ordered ladder. Every heavy stage is a DETACHED job under the shared
    lock with a .done marker; nothing in it starts until the preflight is go.
    [ZK60-CL13] every path is shlex-quoted; the requested --layers/--tokens,
    --threads and the memory lever (HL_GPU_CHUNK_ROWS = the chunk height the
    planner_margin/--memory-budget-mib check was made with) are in EVERY
    command. Two stages have a shape by DEFINITION rather than by request and
    say so: stage 0 runs the floors suite at its frozen fixture shape (the
    byte expectations exist only there), stage 1 the one-layer parity gate."""
    q = shlex.quote
    repo = args.repo
    binary = args.binary or os.path.join(repo, "hashline", "target-gpu", "release", "hashline")
    export = args.export or "<export dir>"
    scratch = args.scratch or os.path.join(repo, "results", "5090_scratch")
    frozen_layers, frozen_tokens = _gates().suite(_gates().DEFAULT_SUITE)["shape"]
    pm = next((c["evidence"] for c in report["checks"] if c["check"] == "planner_margin"), {})
    budget = args.memory_budget_mib if args.memory_budget_mib is not None else pm.get("allowed_mib")
    lever = f"HL_GPU_CHUNK_ROWS={args.chunk_rows}"
    bench = f"{lever} python3 {q(os.path.join(repo, 'scripts', 'hashline_benchmark.py'))}"
    shape = f"--layers {args.layers} --tokens {args.tokens}"
    threads = f"--threads {args.threads}"
    floors = (f"{lever} {q(os.path.join(repo, 'results', 'cl1_floors.sh'))} --repo {q(repo)} --v3-export {q(export)} "
              f"{threads} --build-jobs {args.threads} --rayon-threads {args.threads} --layers {frozen_layers} --tokens {frozen_tokens} "
              f"--device {args.device_index} {q(os.path.join(scratch, 'floors'))}")
    parity = (f"{lever} HL_GPU=1 {q(binary)} pass {args.parity_layers} {args.tokens} {threads} --p3 --seed 1 --profile v3 "
              f"--export {q(export)} --proof-out {q(os.path.join(scratch, 'parity_p3.proof'))}")
    predict = (f"{lever} HL_GPU=1 {q(binary)} pass {args.layers} {args.tokens} {threads} --zk --seed 1 --profile v3 "
               f"--export {q(export)} --proof-out {q(os.path.join(scratch, f'predict_p1_{args.layers}.proof'))}")

    def collector(privacy, out):
        return (f"{bench} run --binary {q(binary)} --export {q(export)} {shape} {threads} --privacy {privacy} --device gpu "
                f"--gpu-index {args.device_index} --warm-runs 20 --out {q(os.path.join(scratch, out))}")

    p1, p3, p1_450 = collector("P1", "p1_warm20"), collector("P3", "p3_warm20"), collector("P1", "p1_warm20_450w")
    common = {"threads": args.threads, "memory_budget_mib": budget, "chunk_rows": args.chunk_rows,
              "memory_lever": lever + " (the only memory knob the binary reads for the W commit; planner_margin checked need <= budget at this chunk height)"}
    stages = [
        {"stage": 0, "name": "byte gates on the new device (BEFORE any timing)", "gate": "12/12 byte gates, full SHA-256, gpu: ON, the manifest green",
         "heavy": True, "command": floors, **detached(floors, os.path.join(scratch, "floors_run"), lock_outside=True), **common,
         "shape": {"layers": frozen_layers, "tokens": frozen_tokens, "why": "the suite's FROZEN fixture shape; the byte expectations exist only there"},
         "why": "a digest that moves on new hardware is a codegen bug, not a hardware finding (runbook §4); the manifest is what the preflight binds to"},
        {"stage": 1, "name": "single-layer CPU/GPU parity ladder at Mistral width", "gate": "P1 and P3 digests equal the laptop's (b5da6c38.., 190e85a1..)",
         "heavy": True, "command": parity, **detached(parity, os.path.join(scratch, "parity_l1"), lock_outside=True), **common,
         "shape": {"layers": args.parity_layers, "tokens": args.tokens, "why": "the one-layer gate (--parity-layers); the laptop digests are one-layer"},
         "why": "CL1 rung 4's byte identity across devices, extended to the 5090"},
        {"stage": 2, "name": f"card-size prediction (runbook §6) at {args.layers}x{args.tokens}", "gate": "later layers no longer slower than layer 0; VRAM peak < total",
         "heavy": True, "command": predict, **detached(predict, os.path.join(scratch, f"predict_{args.layers}"), lock_outside=True), **common,
         "shape": {"layers": args.layers, "tokens": args.tokens},
         "why": "the laptop's 8,585 MB spill is the cheapest thing the card settles; run once, detached"},
        {"stage": 3, "name": f"P1 {args.layers}x{args.tokens} prefill, cold + >= 20 warm", "gate": "measurement_eligible true; p50/p95 nearest-rank; proof_ready clock",
         "heavy": True, "command": p1, **detached(p1, os.path.join(scratch, "p1_warm20"), lock_outside=False), **common,
         "shape": {"layers": args.layers, "tokens": args.tokens},
         "why": "the fast tier, the headline track per the second ruling"},
        {"stage": 4, "name": f"P3 {args.layers}x{args.tokens} prefill, cold + >= 20 warm (SEPARATE job, nvidia-smi idle first)", "gate": "as stage 3; P3 recommits weights every run",
         "heavy": True, "command": p3, **detached(p3, os.path.join(scratch, "p3_warm20"), lock_outside=False), **common,
         "shape": {"layers": args.layers, "tokens": args.tokens},
         "why": "never chain a GPU pass behind another in one script (2026-09-04 standing rule)"},
        {"stage": 5, "name": "comparability row at 450 W", "gate": "same as stage 3 with `nvidia-smi -pl 450` recorded in the manifest",
         "heavy": True, "command": p1_450, "operator": "(operator) nvidia-smi -pl 450 first; restore the stock limit afterwards",
         **detached(p1_450, os.path.join(scratch, "p1_warm20_450w"), lock_outside=False), **common,
         "shape": {"layers": args.layers, "tokens": args.tokens},
         "why": "not for the contract (amended to <= 600 W); for continuity with every row measured before the ruling"},
        {"stage": 6, "name": "one-GPU inference/proving overlap", "gate": "generation, proof-ready and proof-lag clocks reported SEPARATELY",
         "heavy": False, "command": "NOT RUNNABLE IN THIS REPOSITORY: no generation harness exists; tokens are prefill rows. Define per ZK60_CLAUDE_5090.md §4 before running.",
         "why": "60 tok/s is a generation claim; proving alone on an idle card is an upper bound on it"},
    ]
    return {"schema": 2, "preflight_go": report["go"], "ordered_stages": stages,
            "request": {"layers": args.layers, "tokens": args.tokens, "threads": args.threads, "memory_budget_mib": budget,
                        "chunk_rows": args.chunk_rows, "repo": repo, "binary": binary, "export": export, "scratch": scratch},
            "labels": ["[5090-BOX]", "[QUIET]", "[MEASURED]", "diagnostic until coverage is full"],
            "statistic": "p95 nearest-rank over >= 20 warm runs, p50 alongside, cold reported separately (MEASUREMENT_PROTOCOL.md §1)",
            "device": (facts.get("gpus") or [None])[0]}


# --------------------------------------------------------------------- cli

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=_ROOT)
    parser.add_argument("--binary", help="the gpu-cuda hashline binary")
    parser.add_argument("--export", help="v3-widened export directory")
    parser.add_argument("--run-manifest", help="[CL13] the floors run manifest (results/cl1_floors.sh <scratch>/manifest.json)")
    parser.add_argument("--floors-log", help="DEPRECATED hint: a byte-gate log; recorded in the evidence, never sufficient (use --run-manifest)")
    parser.add_argument("--cuda-root", default="/home/victor/cuda-root")
    parser.add_argument("--device-index", type=int, default=0)
    parser.add_argument("--layers", type=int, default=32)
    parser.add_argument("--tokens", type=int, default=512)
    parser.add_argument("--threads", type=int, default=2, help="prover --threads in every emitted command (2: the shared-laptop rule)")
    parser.add_argument("--memory-budget-mib", type=int, help="device memory the plan may use; planner_margin need must fit it (default: margin fraction x VRAM)")
    parser.add_argument("--scratch", help="where emitted stages write (default <repo>/results/5090_scratch)")
    parser.add_argument("--parity-layers", type=int, default=1, help="stage 1's layer count (the laptop parity digests are one-layer)")
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
        if args.threads < 1 or args.parity_layers < 1 or (args.memory_budget_mib is not None and args.memory_budget_mib < 1):
            raise PreflightError("threads, parity layers and the memory budget must be positive")
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
