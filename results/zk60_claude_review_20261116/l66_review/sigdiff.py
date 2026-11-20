import re
B = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'

def sig(path, name):
    t = open(B + path).read()
    i = t.index('theorem ' + name + '\n')
    j = t.index(':=', t.index('ProductionReadyL (classifyModelP', i))
    return t[i + len('theorem ' + name):j]

def split_binders(s):
    out = []; i = 0; n = len(s)
    opens = {'(': ')', '{': '}', '[': ']'}
    while i < n:
        c = s[i]
        if c in opens:
            d = 0; j = i
            while j < n:
                if s[j] in '({[': d += 1
                elif s[j] in ')}]': d -= 1
                if d == 0: break
                j += 1
            out.append(s[i:j + 1]); i = j + 1
        elif c == ':':
            return out, s[i:]
        else:
            i += 1
    return out, ''

def norm(t): return re.sub(r'\s+', ' ', t).strip()
def bnames(b):
    m = re.match(r'[\(\{\[]\s*([^:]+?)\s*:', b)
    return m.group(1).split() if m else [b[:30]]
def btype(b):
    m = re.match(r'[\(\{\[]\s*[^:]+?\s*:(.*)[\)\}\]]$', b, re.S)
    return norm(m.group(1)) if m else norm(b)

def flat(bs):
    # one entry per binder name: name -> (bracket kind, type)
    d = {}; order = []
    for b in bs:
        for nm in bnames(b):
            d[nm] = (b[0], btype(b)); order.append(nm)
    return d, order

old = sig('RunBlkAliveR13.lean', 'sshC_productionReadyL_epP_blkAlive')
new = sig('RunBlkPinsHd.lean', 'sshC_productionReadyL_epP_pinsHd')
ob, oc = split_binders(old); nb, nc = split_binders(new)
od, oo = flat(ob); nd, no = flat(nb)
print('blkAlive binder groups', len(ob), 'names', len(oo), '| pinsHd groups', len(nb), 'names', len(no))
print('CONCLUSION old:', norm(oc)); print('CONCLUSION new:', norm(nc))
print('conclusion text equal:', norm(oc) == norm(nc))
print('\n--- REMOVED (in blkAlive only):', [k for k in oo if k not in nd], len([k for k in oo if k not in nd]))
print('\n--- ADDED (in pinsHd only):')
for k in no:
    if k not in od: print('  ', k, nd[k][0], '::', nd[k][1][:400])
print('\n--- CHANGED (same name, text differs):')
for k in no:
    if k in od and od[k] != nd[k]:
        print('  ', k); print('     old:', od[k][1][:600]); print('     new:', nd[k][1][:600])
print('\n--- KEPT identical:', len([k for k in no if k in od and od[k] == nd[k]]))
print('\nORDER of shared names preserved:', [k for k in oo if k in nd] == [k for k in no if k in od])
print('\nALL pinsHd binders in order:')
for k in no: print('  ', k)
