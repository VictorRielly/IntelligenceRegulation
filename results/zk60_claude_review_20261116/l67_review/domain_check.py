import re
t=open('/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunShieldInstP.lean').read()
i=t.index('def shdP_runDomain')
seg=t[i:t.index('theorem shdP_runDomain_start_none')]
nums=[int(x) for x in re.findall(r'\b\d+\b',seg.split(':=',1)[1])]
s=bytes(nums).decode()
print(len(nums),repr(s))
r=open('/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/src/private_block/run.rs').read()
m=re.search(r'RUN_PROFILE_CLASSIFY_R13_SHIELD_T128: &str = "([^"]+)"',r)
print(m.group(1)==s, len(m.group(1)))
