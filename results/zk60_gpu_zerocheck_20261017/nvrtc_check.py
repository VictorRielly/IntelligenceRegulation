#!/usr/bin/env python3
"""GPU ZERO-CHECK lane: compile hashline's kernels.cu with NVRTC (the same
library the prover JITs with) WITHOUT a device, to catch CUDA source errors
before a guarded GPU slot is spent. Prints the NVRTC log and, with --regs,
nothing else (register counts need the driver). Usage:
    python3 -I nvrtc_check.py <kernels.cu> [arch, default compute_89] [ptx out]
"""
import ctypes
import sys

LIB = "/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib/libnvrtc.so.12"


def main() -> int:
    src_path = sys.argv[1]
    arch = sys.argv[2] if len(sys.argv) > 2 else "compute_89"
    nv = ctypes.CDLL(LIB)
    src = open(src_path, "rb").read()
    prog = ctypes.c_void_p()
    rc = nv.nvrtcCreateProgram(ctypes.byref(prog), ctypes.c_char_p(src), ctypes.c_char_p(b"kernels.cu"), 0, None, None)
    if rc != 0:
        print(f"nvrtcCreateProgram rc={rc}")
        return 2
    opts = [f"--gpu-architecture={arch}".encode()]
    arr = (ctypes.c_char_p * len(opts))(*opts)
    rc = nv.nvrtcCompileProgram(prog, len(opts), arr)
    size = ctypes.c_size_t()
    nv.nvrtcGetProgramLogSize(prog, ctypes.byref(size))
    log = ctypes.create_string_buffer(size.value)
    nv.nvrtcGetProgramLog(prog, log)
    text = log.value.decode(errors="replace").strip()
    if text:
        print(text)
    if rc == 0:
        psize = ctypes.c_size_t()
        nv.nvrtcGetPTXSize(prog, ctypes.byref(psize))
        print(f"NVRTC OK ({arch}), PTX {psize.value} bytes")
        if len(sys.argv) > 3:
            buf = ctypes.create_string_buffer(psize.value)
            nv.nvrtcGetPTX(prog, buf)
            open(sys.argv[3], "wb").write(buf.value)
    else:
        print(f"NVRTC FAILED rc={rc}")
    return 0 if rc == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
