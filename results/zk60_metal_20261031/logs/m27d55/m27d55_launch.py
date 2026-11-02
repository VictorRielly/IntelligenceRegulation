#!/usr/bin/env python3
"""Detach the m27d55 gate chain (the Mac no-hangup recipe): bash runs the chain, its exit code goes
to chain_<mode>.done. Survives the session. Usage: m27d55_launch.py [quick|full]"""
import os, subprocess, sys

MODE = sys.argv[1] if len(sys.argv) > 1 else "full"
L = "/Users/victorrielly/IntelligenceRegulation/results/zk60_metal_20261031/logs/m27d55"
S = f"{L}/m27d55_gates.sh"
os.makedirs(L, exist_ok=True)
done = f"{L}/chain_{MODE}.done"
if os.path.exists(done):
    os.remove(done)
cmd = f"/bin/bash {S} {MODE} >> {L}/chain_{MODE}.log 2>&1; echo $? > {done}"
p = subprocess.Popen(["/bin/bash", "-c", cmd], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
print("launched pid", p.pid, "mode", MODE)
