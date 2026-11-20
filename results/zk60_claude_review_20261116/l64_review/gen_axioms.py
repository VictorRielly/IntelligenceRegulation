import re
B = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunBlkAliveR13.lean'
OUT = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l64_review/l64_axioms.lean'
pat = re.compile(r'^(?:@\[[^\]]*\]\s*)?(?:private\s+|protected\s+)?(?:noncomputable\s+)?(theorem|lemma)\s+([^\s({:\[]+)', re.M)
t = open(B).read().split('\n')
names = []
for i, l in enumerate(t, 1):
    m = pat.match(l)
    if m:
        # namespace: lines >= 2757 are inside RunShapeP
        ns = 'ZK60.ProtocolClassify.RunShapeP' if 2757 <= i <= 3190 else 'ZK60.ProtocolClassify'
        names.append((i, ns + '.' + m.group(2)))
with open(OUT, 'w') as f:
    f.write('import ZK60Formal.RunBlkAliveR13\n\n')
    for i, n in names:
        f.write('#print axioms %s\n' % n)
print(len(names), 'theorems')
