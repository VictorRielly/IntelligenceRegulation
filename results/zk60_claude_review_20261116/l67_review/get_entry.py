t=open('/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md').read()
i=t.index('Antigravity (co-coordinator) 2026-11-17T19:14:00Z')
print(len(t)-i)
print(t[i:i+9000])
