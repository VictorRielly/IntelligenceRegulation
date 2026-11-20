#!/usr/bin/env python3
"""Successive binder diffs along the L60/L61 chain, written to chain_diff.txt (names only + short types)."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from binders import load  # noqa: E402

F = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
chain = [
    ('RunEpBChain.lean', 'eb_productionReadyL_epP_exec_stage'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_exec_blk'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_exec_alive'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_code'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_codeT'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_wireT'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_wireW'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_wireX'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_wireF'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_wireG'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_join'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_join_shield'),
    ('RunBlkWireTop.lean', 'bw_productionReadyL_epP_wire'),
    ('RunBlkWireTop.lean', 'bw_productionReadyL_epP_shield'),
]
W = int(sys.argv[1]) if len(sys.argv) > 1 else 140
out = []
prev = None
for f, n in chain:
    d = load(F + f, n)
    cur = {b['name']: b['type'] for b in d['binders']}
    if prev is not None:
        pn, pd, pc = prev
        out.append('### %s -> %s  (%d -> %d binders)  concl_same=%s' % (pn, n, len(pd), len(cur), pc == d['concl']))
        for k in pd:
            if k not in cur:
                out.append('  - REMOVED %s : %s' % (k, pd[k][:W]))
        for k in cur:
            if k not in pd:
                out.append('  + ADDED   %s : %s' % (k, cur[k][:W]))
        for k in pd:
            if k in cur and pd[k] != cur[k]:
                out.append('  ~ CHANGED %s' % k)
    prev = (n, cur, d['concl'])
open(__file__.rsplit('/', 1)[0] + '/chain_diff.txt', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
