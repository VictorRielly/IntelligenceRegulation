import sys, re, collections
sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107')
import sample_profile as sp
path, root, depth_max = sys.argv[1], sys.argv[2], int(sys.argv[3])
entries = list(sp.parse(path))
names = [sp.short(e[2]) for e in entries]
parent = [None]*len(entries); st = []
for i,(d,n,s) in enumerate(entries):
    while st and entries[st[-1]][0] >= d: st.pop()
    parent[i] = st[-1] if st else None; st.append(i)
# aggregate: for each node whose ancestor chain contains root, path relative to root (collapsed to depth_max)
agg = collections.Counter()
for i in range(len(entries)):
    chain = []; q = i
    while q is not None:
        chain.append(names[q]); q = parent[q]
    chain.reverse()
    if root not in chain: continue
    k = chain.index(root)
    rel = chain[k:k+depth_max+1]
    if len(chain) - k - 1 <= depth_max:
        agg[tuple(rel)] += entries[i][1] - 0
# print inclusive counts for paths of length <= depth_max (count only nodes at exactly that relative depth)
inc = collections.Counter()
for i in range(len(entries)):
    chain = []; q = i
    while q is not None:
        chain.append(names[q]); q = parent[q]
    chain.reverse()
    if root not in chain: continue
    k = chain.index(root)
    rel = tuple(chain[k:])
    if 1 <= len(rel) <= depth_max + 1:
        inc[rel] += entries[i][1]
for rel, c in sorted(inc.items(), key=lambda x: (x[0][:-1], -x[1])):
    if c < int(sys.argv[4]) if len(sys.argv) > 4 else 500: continue
    print(f'{c:8d} ' + '  ' * (len(rel)-1) + rel[-1][:110])
