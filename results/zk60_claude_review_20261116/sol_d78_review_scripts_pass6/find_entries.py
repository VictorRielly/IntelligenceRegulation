"""Pass-6: print Sol's two 2026-11-17T19:40:40 entries from RECOVERY_COORDINATION.md (read-only, stdout)."""
import re
p = '/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md'
t = open(p, encoding='utf-8', errors='replace').read()
key = 'Sol 2026-11-17T19:40:40.759087+00:00'
idxs = [m.start() for m in re.finditer(re.escape(key), t)]
print('file chars', len(t), 'matches', idxs)
for i, s in enumerate(idxs):
    nxt = t.find('\n- ', s + 10)
    nxt2 = t.find('\n## ', s + 10)
    ends = [e for e in (nxt, nxt2) if e > 0]
    e = min(ends) if ends else len(t)
    print('=== entry', i, 'start', s, 'len', e - s)
    print(t[s:e])
