#!/usr/bin/env python3
"""Co-coordinator (Claude), 2026-11-25: wake the session as soon as another agent appends an entry to the coordination file.

Why this exists beside watch_coordination.py: that watcher holds a status-only entry of the Antigravity coordinator for up to
45 minutes (its constant AGY_BATCH_MIN; its second argument only batches Sol's "ready for cross-review" announcements). On
2026-11-25 an entry "ready for Claude's merge gate" reached me 43 minutes late that way. Use this script whenever another agent
may be waiting on me; use the watcher for long quiet stretches.

usage: wait_entry.py <max_minutes> [names] [from_line]
  names      comma-separated header names to wake on (default Antigravity,Astra,Sol)
  from_line  only text after this 1-based line number counts (default: the file's length when the script starts)

A header is a line that starts (after optional '#' marks or '**') with one of the names; this also takes Astra's
"Astra, November 25." form, which has no ISO time. Polls every 20 s. Prints the clock, the guard's job lines and the first
700 characters of each new entry, then exits 0; exits 3 at the limit with nothing new. Read-only.
"""
import re
import subprocess
import sys
import time

COORD = '/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md'
GUARD = '/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py'
limit = float(sys.argv[1]) * 60
names = (sys.argv[2] if len(sys.argv) > 2 else 'Antigravity,Astra,Sol').split(',')
pat = re.compile(r'^(#+ )?\**(' + '|'.join(re.escape(n) for n in names) + r')\b')


def lines():
    return open(COORD, encoding='utf-8', errors='replace').read().split('\n')


start = int(sys.argv[3]) if len(sys.argv) > 3 else len(lines())
t0 = time.time()
while True:
    L = lines()
    new = [(i + 1, l) for i, l in enumerate(L) if i >= start and pat.match(l)]
    if new or time.time() - t0 > limit:
        st = subprocess.run(['python3', GUARD, 'status'], capture_output=True, text=True).stdout
        jobs = [l.strip() for l in st.split('\n') if l.startswith('  job')]
        print(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'guarded jobs:', jobs or 'none', '| file lines', len(L), '| watched from line', start)
        for n, l in new:
            print('line %d: %s' % (n, l[:700]))
            print()
        sys.exit(0 if new else 3)
    time.sleep(20)
