#!/usr/bin/env python3
"""Batch 8: read a process's cumulative task counters (page faults, user and system CPU time) with
proc_pidinfo(PROC_PIDTASKINFO), the same numbers `top` shows. Read-only, same user, no entitlement.
The two CPU times are in Mach absolute-time ticks; mach_timebase_info converts them to seconds."""
import ctypes
import ctypes.util
import os
import sys
import time

PROC_PIDTASKINFO = 4


class TaskInfo(ctypes.Structure):
    _fields_ = [
        ("virtual_size", ctypes.c_uint64),
        ("resident_size", ctypes.c_uint64),
        ("total_user", ctypes.c_uint64),
        ("total_system", ctypes.c_uint64),
        ("threads_user", ctypes.c_uint64),
        ("threads_system", ctypes.c_uint64),
        ("policy", ctypes.c_int32),
        ("faults", ctypes.c_int32),
        ("pageins", ctypes.c_int32),
        ("cow_faults", ctypes.c_int32),
        ("messages_sent", ctypes.c_int32),
        ("messages_received", ctypes.c_int32),
        ("syscalls_mach", ctypes.c_int32),
        ("syscalls_unix", ctypes.c_int32),
        ("csw", ctypes.c_int32),
        ("threadnum", ctypes.c_int32),
        ("numrunning", ctypes.c_int32),
        ("priority", ctypes.c_int32),
    ]


class Timebase(ctypes.Structure):
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]


_libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
_libsys = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
_tb = Timebase()
_libsys.mach_timebase_info(ctypes.byref(_tb))
TICK_S = _tb.numer / _tb.denom / 1e9


def read(pid):
    """(t_monotonic, faults, pageins, cow, user_s, sys_s, rss_bytes, threads) or None"""
    ti = TaskInfo()
    t = time.monotonic()
    n = _libproc.proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ctypes.byref(ti), ctypes.sizeof(ti))
    if n != ctypes.sizeof(ti):
        return None
    return (t, ti.faults & 0xFFFFFFFF, ti.pageins, ti.cow_faults, ti.total_user * TICK_S, ti.total_system * TICK_S, ti.resident_size, ti.threadnum)


if __name__ == "__main__":
    pid = int(sys.argv[1]) if len(sys.argv) > 1 else os.getpid()
    print("timebase", _tb.numer, _tb.denom)
    a = read(pid)
    x = bytearray(512 * 1024 * 1024)
    for i in range(0, len(x), 4096):
        x[i] = 1
    b = read(pid)
    print(a)
    print(b)
    print("faults delta", b[1] - a[1], "for 512 MiB touched; page size", os.sysconf("SC_PAGE_SIZE"))
