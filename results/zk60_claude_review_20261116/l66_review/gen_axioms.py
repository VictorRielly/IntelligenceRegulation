import re
SRC = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunBlkPinsHd.lean'
OUTDIR = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l66_review/'
pat = re.compile(r'^(@\[[^\]]*\]\s*)?(private\s+|protected\s+)?(noncomputable\s+)?(theorem|lemma|def|abbrev|instance)\s+([^\s({:\[]+)', re.M)
t = open(SRC).read().split('\n')
# namespace: lines >= 2822 and <= 3539 are inside RunShapeP
items = []
for i, l in enumerate(t, 1):
    m = pat.match(l)
    if m:
        ns = 'ZK60.ProtocolClassify.RunShapeP' if 2822 <= i <= 3539 else 'ZK60.ProtocolClassify'
        items.append((i, m.group(4), bool(m.group(2) and 'private' in m.group(2)), ns + '.' + m.group(5)))
thms = [x for x in items if x[1] in ('theorem', 'lemma')]
pub = [x for x in thms if not x[2]]
priv = [x for x in thms if x[2]]
defs = [x for x in items if x[1] not in ('theorem', 'lemma')]
print('theorems', len(thms), 'public', len(pub), 'private', len(priv), 'defs', len(defs))
# elaboration copy: source + #print axioms lines (private ones included; same file so accessible)
body = open(SRC).read()
# insert the prints before the final 'end ZK60.ProtocolClassify' so private names resolve (same file)
idx = body.rindex('end ZK60.ProtocolClassify')
pre = body[:idx]
pr = ['', '-- REVIEW APPENDIX (reviewer-generated; not in the original file)']
for (i, k, p, n) in thms:
    pr.append('#print axioms %s' % n)
for (i, k, p, n) in defs:
    pr.append('#print axioms %s' % n)
open(OUTDIR + 'RunBlkPinsHd_review_copy.lean', 'w').write(pre + '\n'.join(pr) + '\n\n' + body[idx:])
open(OUTDIR + 'public_theorems.txt', 'w').write('\n'.join('%d %s %s%s' % (i, k, 'PRIVATE ' if p else '', n) for (i, k, p, n) in items) + '\n')
