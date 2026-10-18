#!/usr/bin/env python3
"""GPU ZERO-CHECK lane: registers, spills and shared memory of the slot-18
round kernels, WITHOUT a device. Assembles each variant's source exactly as
`hashline/src/gpu/cuda.rs::fzc_module` does (the FZ_* defines, kernels.cu up
to "// The probe: mul", then fzc_kernels.cu) and compiles it with NVRTC for
the real architecture sm_89 with `--ptxas-options=-v`, whose log reports
per-kernel registers, spill stores/loads and stack frame. (The prover JITs
compute_89 PTX through the driver; same ptxas back end family, so these are
the numbers to expect, not a measurement of the driver's JIT.)

usage: python3 -I fzc_regs.py <hashline/src/gpu dir> [variant ...]
variants: v2 (direct, D5, gate) lean (D5, gate) v2d4 leand4 split (v4, D5, gate) splitd4
"""
import ctypes
import re
import sys

LIB = "/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib/libnvrtc.so.12"
VARIANTS = {"v2": (5, 1, 0, 0), "lean": (5, 1, 1, 0), "v2d4": (4, 0, 0, 0), "leand4": (4, 0, 1, 0), "split": (5, 1, 0, 1), "splitd4": (4, 0, 0, 1)}


def compile_one(src: bytes, extra: list) -> tuple:
    nv = ctypes.CDLL(LIB)
    prog = ctypes.c_void_p()
    rc = nv.nvrtcCreateProgram(ctypes.byref(prog), ctypes.c_char_p(src), ctypes.c_char_p(b"fzc.cu"), 0, None, None)
    if rc != 0:
        return rc, f"nvrtcCreateProgram rc={rc}"
    opts = [b"--gpu-architecture=sm_89", b"--ptxas-options=-v"] + extra
    arr = (ctypes.c_char_p * len(opts))(*opts)
    rc = nv.nvrtcCompileProgram(prog, len(opts), arr)
    size = ctypes.c_size_t()
    nv.nvrtcGetProgramLogSize(prog, ctypes.byref(size))
    log = ctypes.create_string_buffer(size.value)
    nv.nvrtcGetProgramLog(prog, log)
    return rc, log.value.decode(errors="replace")


def main() -> int:
    gdir = sys.argv[1]
    names = sys.argv[2:] or list(VARIANTS)
    ksrc = open(f"{gdir}/kernels.cu").read()
    cut = ksrc.find("// The probe: mul")
    if cut < 0:
        print("the primitive section of kernels.cu moved")
        return 2
    fsrc = open(f"{gdir}/fzc_kernels.cu").read()
    for name in names:
        d, supp, lean, split = VARIANTS[name]
        src = f"#define FZ_D {d}\n#define FZ_SUPP {supp}\n#define FZ_LEAN {lean}\n#define FZ_SPLIT {split}\n{ksrc[:cut]}{fsrc}".encode()
        rc, log = compile_one(src, [])
        print(f"== variant {name} (D {d}, gate {supp}, lean {lean}, split {split}): NVRTC rc {rc}")
        cur = None
        for line in log.splitlines():
            m = re.search(r"Compiling entry function '(\w+)'", line)
            if m:
                cur = m.group(1)
                continue
            if cur and ("registers" in line or "spill" in line or "stack frame" in line):
                print(f"   {cur}: {line.strip().split('info    : ')[-1]}")
        if rc != 0:
            print(log)
    return 0


if __name__ == "__main__":
    sys.exit(main())
