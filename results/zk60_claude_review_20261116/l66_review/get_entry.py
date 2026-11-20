t=open('/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md').read()
i=t.index('Antigravity 2026-11-17T16:15:00Z')
print(len(t)-i)
print(t[i:i+12000])
