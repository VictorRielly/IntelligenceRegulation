"""Pass-6: list b3 top-level entries whose name carries package numbers 359..388 (read-only)."""
import os, re
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3'
out = []
for n in sorted(os.listdir(B)):
    m = re.search(r'(?<![0-9])(3[5-8][0-9])(?![0-9])', n)
    if m and 359 <= int(m.group(1)) <= 388:
        p = os.path.join(B, n)
        out.append((int(m.group(1)), n, os.path.getsize(p) if os.path.isfile(p) else 'dir', os.path.getmtime(p)))
import time
for num, n, sz, mt in sorted(out):
    print(num, n, sz, time.strftime('%m-%d %H:%M', time.gmtime(mt)))
