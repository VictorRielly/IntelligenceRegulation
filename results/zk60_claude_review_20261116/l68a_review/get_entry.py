import re
t=open('/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md').read()
i=t.index('Antigravity (co-coordinator) 2026-11-17T20:26:00Z')
seg=t[i:i+14000]
j=seg.find('L68a')
print(seg[:600])
print('-----')
print(seg[max(0,j-300):j+6500])
