#!/usr/bin/env python3
"""Runs every analysis script in this directory and stores its printed tables next to it as <script>.out.txt.  python3 -I run_all.py
Read-only on the traces and logs; writes only the .out.txt files here.  No GPU, no build."""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
for name in ("anchor", "busy_split", "labels", "saturation", "gaps", "gap_timeline", "phases_of_call", "natural_experiment", "witness_gpu", "floors", "batch8_check"):
    r = subprocess.run([sys.executable, "-I", str(HERE / (name + ".py"))], capture_output=True, text=True)
    (HERE / (name + ".out.txt")).write_text(r.stdout + (("\nSTDERR\n" + r.stderr) if r.returncode else ""))
    print(name, "exit", r.returncode, "lines", len(r.stdout.splitlines()))
