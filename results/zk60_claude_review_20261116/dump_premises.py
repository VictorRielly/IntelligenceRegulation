#!/usr/bin/env python3
"""Write one file per top theorem listing every binder (kind, name, type truncated to 300 chars),
plus the predecessor theorems, into premises/. Read-only on the Lean sources."""
import os
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from binders import load  # noqa: E402

F = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
OUT = __file__.rsplit('/', 1)[0] + '/premises'
os.makedirs(OUT, exist_ok=True)
for f, n in [
    ('RunEpXTopH.lean', 'ex_productionReadyL_epP_codeH'),
    ('RunStgAlgTopR.lean', 'stgAlg_productionReadyL_epP_exec_real'),
    ('RunStgJoinChain.lean', 'sj_productionReadyL_epP_wireT'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_join'),
    ('RunStgJoinTop.lean', 'sj_productionReadyL_epP_join_shield'),
    ('RunBlkWireTop.lean', 'bw_productionReadyL_epP_wire'),
    ('RunBlkWireTop.lean', 'bw_productionReadyL_epP_shield'),
]:
    d = load(F + f, n)
    with open('%s/%s.txt' % (OUT, n), 'w') as o:
        o.write('# %s:%d  (%d binders, section variables not included)\n' % (f, d['line'], len(d['binders'])))
        for b in d['binders']:
            t = b['type']
            o.write('%s%s : %s\n' % (b['kind'], b['name'], t if len(t) <= 300 else t[:300] + ' ...[+%d]' % (len(t) - 300)))
        o.write('CONCL: %s\n' % d['concl'])
    print(n, len(d['binders']))
