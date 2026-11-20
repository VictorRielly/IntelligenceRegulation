t=open('/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md').read()
i=t.index('Antigravity (co-coordinator) 2026-11-17T20:26:00Z')
seg=t[i:]
j=seg.find('Remaining D63 obligations')
print(seg[j-50:j+3500])
