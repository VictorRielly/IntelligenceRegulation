#!/usr/bin/env python3
"""A11: write the small derived analyses of stage 1's two `sample` call graphs (the raw files,
68 MB and 119 MB, are not committed). Run from anywhere: python3 derive_s1.py"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def run(out, script, *args):
    with open(os.path.join(HERE, out), "w") as f:
        subprocess.run([sys.executable, os.path.join(HERE, script), *args], stdout=f, stderr=subprocess.STDOUT, check=False)


n1, n6 = os.path.join(HERE, "s1_sample_N1.txt"), os.path.join(HERE, "s1_sample_N6.txt")
run("s1_nesting_N1.txt", "sample_nesting.py", n1)
run("s1_nesting_N6.txt", "sample_nesting.py", n6)
run("s1_chains_N6_rayon_locks.txt", "sample_chains.py", n6, r"__psynch_mutexwait|__ulock_wait2", "--role", "rayon", "--depth", "7", "--top", "12")
run("s1_chains_N6_fork_alloc.txt", "sample_chains.py", n6, r"from_elem|__bzero|mach_vm_deallocate|madvise", "--role", "fork", "--depth", "5", "--top", "12")
run("s1_chains_N1_fork_alloc.txt", "sample_chains.py", n1, r"from_elem|__bzero|mach_vm_deallocate|madvise", "--role", "fork", "--depth", "5", "--top", "12")
run("s1_chains_N6_fork_poolwait.txt", "sample_chains.py", n6, ".", "--role", "fork", "--under", "in_worker_cold", "--depth", "14", "--top", "20")
run("s1_chains_N6_u128.txt", "sample_chains.py", n6, r"u128_div_rem|__umodti3", "--role", "any", "--depth", "4", "--top", "8")
for f in sorted(os.listdir(HERE)):
    if f.startswith("s1_") and (f.endswith(".txt") and ("nesting" in f or "chains" in f)):
        print(os.path.getsize(os.path.join(HERE, f)), f)
