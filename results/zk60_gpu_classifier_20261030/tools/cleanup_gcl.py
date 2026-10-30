#!/usr/bin/env python3
"""GPU classifier lane (D46): delete test-only directories after their checks are recorded; record what went.
Refuses any path outside the lane's two scratch roots.
usage: cleanup_gcl.py OUT.json DIR [DIR ...]"""
import json, os, shutil, sys
ROOTS = ('/home/victor/zk60-artifacts/gpu-classifier/', '/home/victor/zk60-owner-private/gpu-classifier/')
out, dirs = sys.argv[1], sys.argv[2:]
removed = []
for d in dirs:
    d = os.path.realpath(d)
    if not any((d + '/').startswith(r) and d + '/' != r for r in ROOTS):
        removed.append({'path': d, 'refused': 'outside the lane scratch roots'})
        continue
    if not os.path.exists(d):
        removed.append({'path': d, 'files': 0, 'bytes': 0, 'note': 'absent'})
        continue
    n = b = 0
    for root, _, files in os.walk(d):
        for f in files:
            p = os.path.join(root, f)
            n += 1
            try:
                b += os.lstat(p).st_size
            except OSError:
                pass
    shutil.rmtree(d)
    removed.append({'path': d, 'files': n, 'bytes': b})
json.dump({'removed': removed}, open(out, 'w'), indent=1)
print(json.dumps({'removed': removed}))
