#!/usr/bin/env python3
"""Lane A26: check the fixed-entropy interposer (fixed_entropy.c) on a child process: under it,
two fresh opens of /dev/urandom both read the fixed file's first bytes; without it they differ.

usage: fixed_entropy_selftest.py <dylib> <entropy file> <python>
"""
import os
import subprocess
import sys

dylib, fixed, py = sys.argv[1:4]
code = "a=open('/dev/urandom','rb').read(16).hex();b=open('/dev/urandom','rb').read(16).hex();print(a,b)"
env = dict(os.environ, DYLD_INSERT_LIBRARIES=dylib, A26_FIXED_ENTROPY_FILE=fixed)
on = subprocess.run([py, '-c', code], env=env, capture_output=True, text=True).stdout.split()
off = subprocess.run([py, '-c', code], capture_output=True, text=True).stdout.split()
want = open(fixed, 'rb').read(16).hex()
ok = on == [want, want] and len(off) == 2 and off[0] != off[1] and want not in off
print('interposed', on == [want, want], '| plain differs', len(off) == 2 and off[0] != off[1], '| OK' if ok else '| FAILED')
sys.exit(0 if ok else 1)
