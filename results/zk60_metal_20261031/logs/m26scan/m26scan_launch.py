#!/usr/bin/env python3
"""Detach the m26scan gate chain (the Mac no-hangup recipe): bash runs the chain, its exit code goes
to <mode>.done. Survives the session. Usage: m26scan_launch.py [quick|full]"""
import os, subprocess, sys

MODE = sys.argv[1] if len(sys.argv) > 1 else "full"
L = "/Users/victorrielly/IntelligenceRegulation/results/zk60_metal_20261031/logs/m26scan"
S = "/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/m26scan_gates.sh"
os.makedirs(L, exist_ok=True)
done = f"{L}/chain_{MODE}.done"
if os.path.exists(done):
    os.remove(done)
cmd = f"/bin/bash {S} {MODE} >> {L}/chain_{MODE}.log 2>&1; echo $? > {done}"
p = subprocess.Popen(["/bin/bash", "-c", cmd], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
print("launched pid", p.pid, "mode", MODE)
