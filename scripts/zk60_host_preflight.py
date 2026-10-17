#!/usr/bin/env python3
"""Read-only Linux/macOS setup inventory. No installs, network or model loading."""
import argparse
import csv
import ctypes
import ctypes.util
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


def command(args):
    try:
        # A rustup proxy can otherwise install a missing directory-selected
        # toolchain even for --version. This inventory must stay read-only.
        env = dict(os.environ, RUSTUP_AUTO_INSTALL="0")
        result = subprocess.run(args, capture_output=True, text=True, timeout=15, env=env)
        output = result.stdout if result.returncode == 0 else "\n".join(
            part.strip() for part in (result.stderr, result.stdout) if part.strip())
        return {"ok": result.returncode == 0,
                "output": output.strip()[:4096]}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "output": str(exc)[:200]}


def nvidia_inventory():
    fields = "name,memory.total,driver_version,compute_cap"
    result = command(["nvidia-smi", "--query-gpu=" + fields, "--format=csv,noheader,nounits"])
    if not result["ok"]:
        return {"available": False, "diagnostic": result["output"]}
    devices = []
    for row in csv.reader(io.StringIO(result["output"]), skipinitialspace=True):
        if len(row) != 4:
            return {"available": False, "diagnostic": "Unexpected nvidia-smi column count"}
        try:
            memory = int(row[1])
            major, minor = (int(part) for part in row[3].strip().split("."))
        except ValueError:
            return {"available": False, "diagnostic": "GPU memory/capability could not be parsed"}
        devices.append({"name": row[0].strip(), "memory_mib": memory,
                        "driver": row[2].strip(), "compute_capability": [major, minor]})
    return {"available": bool(devices), "devices": devices}


def nvrtc_inventory():
    # Query the library itself: nvcc's version does not establish which NVRTC
    # the runtime loader will use. These APIs compile/launch no CUDA kernels.
    names = [ctypes.util.find_library("nvrtc"), "libnvrtc.so"]
    cuda_root = os.environ.get("CUDA_ROOT")
    if cuda_root:
        names += [str(Path(cuda_root) / "lib64/libnvrtc.so")]
    errors = []
    for name in dict.fromkeys(n for n in names if n):
        try:
            lib = ctypes.CDLL(name)
            major, minor, count = ctypes.c_int(), ctypes.c_int(), ctypes.c_int()
            for fn in (lib.nvrtcVersion, lib.nvrtcGetNumSupportedArchs, lib.nvrtcGetSupportedArchs):
                fn.restype = ctypes.c_int
            lib.nvrtcVersion.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
            lib.nvrtcGetNumSupportedArchs.argtypes = [ctypes.POINTER(ctypes.c_int)]
            lib.nvrtcGetSupportedArchs.argtypes = [ctypes.POINTER(ctypes.c_int)]
            if lib.nvrtcVersion(ctypes.byref(major), ctypes.byref(minor)) != 0:
                raise RuntimeError("nvrtcVersion failed")
            if lib.nvrtcGetNumSupportedArchs(ctypes.byref(count)) != 0 or not 0 < count.value <= 256:
                raise RuntimeError("invalid NVRTC architecture count")
            arches = (ctypes.c_int * count.value)()
            if lib.nvrtcGetSupportedArchs(arches) != 0:
                raise RuntimeError("nvrtcGetSupportedArchs failed")
            return {"available": True, "library": name, "version": [major.value, minor.value],
                    "supported_architectures": list(arches),
                    "supports_compute_120": 120 in arches}
        except (OSError, AttributeError, RuntimeError) as exc:
            errors.append(type(exc).__name__)
    return {"available": False, "diagnostic": "NVRTC could not be queried", "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu-only", action="store_true", help="Skip NVIDIA/NVRTC queries")
    args = parser.parse_args()
    system = platform.system()
    memory = None
    if system == "Darwin":
        found = command(["sysctl", "-n", "hw.memsize"])
        if found["ok"] and found["output"].isdigit():
            memory = int(found["output"])
        os_name = command(["sw_vers", "-productVersion"])
        chip = command(["sysctl", "-n", "machdep.cpu.brand_string"])
    else:
        try:
            memory = os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE")
        except (ValueError, OSError):
            pass
        try:
            os_name = platform.freedesktop_os_release().get("PRETTY_NAME", system)
        except (AttributeError, OSError):
            os_name = system
        chip = platform.machine()
    report = {
        "kind": "read-only host inventory, not proof or benchmark readiness",
        "os": system, "os_version": os_name, "architecture": platform.machine(),
        "chip": chip, "logical_cpus": os.cpu_count(), "memory_bytes": memory,
        "free_disk_bytes_in_working_filesystem": shutil.disk_usage(Path.cwd()).free,
        "tools": {tool: command([tool, "--version"]) for tool in ("rustc", "cargo", "cc", "cmake")},
        "python": platform.python_version(), "next_steps": [],
    }
    if system == "Darwin":
        report["next_steps"].append("Build and validate the CPU reference first; this repository has no Metal proof backend.")
    elif not args.cpu_only:
        report["nvidia"] = nvidia_inventory()
        report["nvrtc"] = nvrtc_inventory()
        if not report["nvidia"]["available"]:
            report["next_steps"].append("Resolve NVIDIA device/driver access before device tests.")
        if not report["nvrtc"]["available"]:
            report["next_steps"].append("Configure the CUDA toolkit runtime library path, then rerun this check.")
        for device in report["nvidia"].get("devices", []):
            cc = device["compute_capability"]
            code = cc[0] * 10 + cc[1]
            if code not in report["nvrtc"].get("supported_architectures", []):
                report["next_steps"].append("NVRTC does not report compute_%d support; native device validation remains pending." % code)
    report["next_steps"].append("Use the reviewed source snapshot; pass CPU/device parity and complete proof checks before timing.")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
