#!/usr/bin/env python3
"""A15: regenerate the pairs tables from the committed logs of this directory (light Python, no build).

usage: tables.py
"""
import os
import subprocess
import sys

O = os.path.dirname(os.path.abspath(__file__))
A = os.path.dirname(O)


def run(script, args, out):
    with open(os.path.join(O, out), "w") as f:
        subprocess.run([sys.executable, script, *args], stdout=f, stderr=subprocess.STDOUT, check=True)


run(os.path.join(O, "alone_table.py"), [os.path.join(O, "s1_alone.log"), "--base", "sp0"], "s1_alone_table.md")
s2 = os.path.join(O, "s2_d55_ab.log")
for t in ["spg", "sp4", "sp6", "sp8", "sp12", "sp16"]:
    run(os.path.join(A, "a11", "pairs.py"), [s2, "sp0", t, "--alternate", "--n", "6"], f"s2_pairs_{t}.md")
    run(os.path.join(A, "a13", "seal_pairs.py"), [s2, "sp0", t, "--n", "6"], f"s2_seal13_{t}.md")
    run(os.path.join(O, "seal_pairs.py"), [s2, "sp0", t, "--n", "6"], f"s2_seal_{t}.md")
for t in ["sp4", "sp6", "sp8", "sp12", "sp16"]:
    run(os.path.join(A, "a11", "pairs.py"), [s2, "spg", t, "--alternate", "--n", "6"], f"s2_pairs_spg_{t}.md")
for tag, base, test in [("default", "sp0", "spauto"), ("lazy", "spauto", "spauto+lazy0")]:
    log = os.path.join(O, f"s3_{tag}_d55_ab.log")
    if not os.path.exists(log):
        continue
    run(os.path.join(A, "a11", "pairs.py"), [log, base, test, "--alternate", "--n", "6"], f"s3_pairs_{tag}.md")
    run(os.path.join(A, "a13", "seal_pairs.py"), [log, base, test, "--n", "6"], f"s3_seal13_{tag}.md")
    run(os.path.join(O, "seal_pairs.py"), [log, base, test, "--n", "6"], f"s3_seal_{tag}.md")
print("tables written")
