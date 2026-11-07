import sys, collections
sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107')
import sample_profile as sp
path, target, k = sys.argv[1], sys.argv[2], int(sys.argv[3])
entries = list(sp.parse(path))
names = [sp.short(e[2]) for e in entries]
parent = [None]*len(entries); st = []
for i,(d,n,s) in enumerate(entries):
    while st and entries[st[-1]][0] >= d: st.pop()
    parent[i] = st[-1] if st else None; st.append(i)
boring = ('rayon', 'core::', 'std::', 'crossbeam', 'alloc::', 'closure', 'call_mut', 'call_once', 'FnOnce', 'thread_start', '_pthread', 'Iterator', 'from_iter', 'Vec', 'objc::rc', 'autoreleasepool', 'run_tagged', 'wait_done')
agg = collections.Counter()
for i in range(len(entries)):
    if names[i] != target: continue
    # outermost occurrence only
    q = parent[i]; dup=False
    while q is not None:
        if names[q] == target: dup=True; break
        q = parent[q]
    if dup: continue
    chain=[]; q=parent[i]
    while q is not None and len(chain) < k:
        if not any(b in names[q] for b in boring): chain.append(names[q].split('::')[-1] if '::' in names[q] else names[q])
        q=parent[q]
    agg[' <- '.join(chain)] += entries[i][1]
for c,v in agg.most_common(25): print(f'{v:8d}  {c[:200]}')
