#!/usr/bin/env python3
"""Detach one bash command (the Mac no-hangup recipe): bash runs it, its exit code goes to
<stem>.done. Survives the session. Usage: detach.py <stem> <bash command...>"""
import os, subprocess, sys

stem = sys.argv[1]
cmd = " ".join(sys.argv[2:])
os.makedirs(os.path.dirname(stem), exist_ok=True)
done = stem + ".done"
if os.path.exists(done):
    os.remove(done)
full = f"{cmd} >> {stem}.out 2>&1; echo $? > {done}"
p = subprocess.Popen(["/bin/bash", "-c", full], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
print("launched pid", p.pid, "->", done)
