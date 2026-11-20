#!/usr/bin/env python3
"""L62 pre-review: premise diff of bw_productionReadyL_epP_shield (RunBlkWireTop.lean, L61) against
RunShapeP.bw_productionReadyL_epP_shield_r13 (RunBlkShieldInst.lean, L62). Read-only; reuses ../binders.py.
The two files name the same commitment notation differently (CinR / CinS); it is normalised before comparing.
Also prints the CHANGED binders token by token and the conclusion check.
"""
import difflib
import re
import sys
sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116')
from binders import parse  # noqa: E402

F = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
OLD = (F + 'RunBlkWireTop.lean', 'bw_productionReadyL_epP_shield')
NEW = (sys.argv[1] if len(sys.argv) > 1 else F + 'RunBlkShieldInst.lean', 'bw_productionReadyL_epP_shield_r13')
TOK = re.compile(r'\s+|[()\[\]{},]|[^\s()\[\]{},]+')


def load_norm(path, name, sub):
    text = open(path, encoding='utf-8').read()
    for a, b in sub:
        text = text.replace(a, b)
    return parse(text, name)


def toks(s):
    return [t for t in TOK.findall(s) if not t.isspace()]


a = load_norm(OLD[0], OLD[1], [])
# the L62 file's section fixes S := shieldS0 and calls the notation CinS
b = load_norm(NEW[0], NEW[1], [('CinS', 'CinR')])
da = {x['name']: x['type'] for x in a['binders']}
db = {x['name']: x['type'] for x in b['binders']}
print('# OLD %s:%d (%d binders)  NEW %s:%d (%d binders); section variables not included' % (
    OLD[1], a['line'], len(da), NEW[1], b['line'], len(db)))
print('REMOVED:', ' '.join(k for k in da if k not in db))
print('ADDED:  ', ' '.join(k for k in db if k not in da))
for k in db:
    if k not in da:
        t = db[k]
        print('  + %s : %s' % (k, t if len(t) <= 400 else t[:400] + ' ...[+%d]' % (len(t) - 400)))
changed = [k for k in da if k in db and da[k] != db[k]]
print('CHANGED (%d):' % len(changed), ' '.join(changed))
for k in changed:
    ta, tb = toks(da[k]), toks(db[k])
    sm = difflib.SequenceMatcher(a=ta, b=tb, autojunk=False)
    print('  ==', k)
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op != 'equal':
            print('    %s OLD[%s] NEW[%s]' % (op, ' '.join(ta[i1:i2])[:400], ' '.join(tb[j1:j2])[:400]))
kept = [k for k in da if k in db and da[k] == db[k]]
print('KEPT (%d)' % len(kept))
print('CONCL same (after CinS->CinR):', a['concl'] == b['concl'])
if a['concl'] != b['concl']:
    print('  old:', a['concl'][:600])
    print('  new:', b['concl'][:600])
