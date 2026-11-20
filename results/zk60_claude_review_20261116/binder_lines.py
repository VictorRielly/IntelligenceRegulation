#!/usr/bin/env python3
"""Print the source line where each named binder of a theorem starts.
Usage: binder_lines.py FILE THEOREM name1 name2 ..."""
import re
import sys

path, thm = sys.argv[1], sys.argv[2]
names = sys.argv[3:]
lines = open(path, encoding='utf-8').read().split('\n')
start = next(i for i, l in enumerate(lines) if re.match(r'^theorem %s\b' % re.escape(thm), l))
end = next((i for i in range(start + 1, len(lines)) if ':= by' in lines[i] or 'ProductionReadyL (classifyModelP' in lines[i]),
           len(lines) - 1)
print('theorem %s at line %d; header ends near line %d' % (thm, start + 1, end + 1))
for n in names:
    pat = re.compile(r'[({\[]%s\s*:' % re.escape(n))
    hits = [i + 1 for i in range(start, end + 1) if pat.search(lines[i])]
    print('  %s: %s' % (n, hits))
