"""Pass-6 G: which hashline/src files Sol changed (188->363) and which main changed (188->working tree); overlap = merge conflict candidates. (read-only)"""
import os, hashlib
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3/'
S = lambda t: B + f'source-d78-{t}/hashline/src/'
W = R + '/ops/zkp-mvp/gpu-metal/hashline/src/'
def tree(root):
    out = {}
    for dp, _, fs in os.walk(root):
        for f in fs:
            p = os.path.join(dp, f)
            out[os.path.relpath(p, root)] = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    return out
t188, t363, wt = tree(S('188')), tree(S('363')), tree(W)
sol = {k for k in set(t188) | set(t363) if t188.get(k) != t363.get(k)}
main = {k for k in set(t188) | set(wt) if t188.get(k) != wt.get(k)}
print('Sol delta (188->363):', len(sol)); print(sorted(sol))
print('main delta (188->working tree):', len(main))
print('OVERLAP (both changed):', sorted(sol & main))
print('Sol-only', len(sol - main), 'main-only', len(main - sol))
# where does the 363 tree equal the working tree for Sol-changed files?
print('Sol-changed files absent/different in working tree:', sorted(k for k in sol if wt.get(k) != t363.get(k))[:30])
