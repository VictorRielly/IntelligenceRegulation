import re, sys
B = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'

def sig(path, name):
    t = open(B + path).read()
    i = t.index('theorem ' + name + '\n')
    j = t.index(':=', t.index('ProductionReadyL (classifyModelP', i))
    return t[i + len('theorem ' + name):j]

def split_binders(s):
    """split into top-level binder groups (...), {...}, [...]; return (list of text, conclusion text)"""
    out = []
    i = 0
    n = len(s)
    opens = {'(': ')', '{': '}', '[': ']'}
    while i < n:
        c = s[i]
        if c in opens:
            d = 0
            j = i
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

def norm(t):
    return re.sub(r'\s+', ' ', t).strip()

def bname(b):
    m = re.match(r'[\(\{\[]\s*([^:]+?)\s*:', b)
    return m.group(1) if m else b[:30]

old = sig('RunStgShieldCTopDg.lean', 'sshC_productionReadyL_epP_dg')
new = sig('RunBlkAliveR13.lean', 'sshC_productionReadyL_epP_blkAlive')
ob, oc = split_binders(old)
nb, nc = split_binders(new)
# dg is stated over a section variable S : BlockShape; blkAlive over shieldS0
def sub(t):
    t = re.sub(r'(?<![\.\w])S(?![\w])', 'shieldS0', t)
    t = t.replace('CinR', 'CinS')
    return t
od = {}
for b in ob:
    od.setdefault(bname(b), []).append(norm(sub(b)))
nd = {}
for b in nb:
    nd.setdefault(bname(b), []).append(norm(b))
print('dg binders', len(ob), 'blkAlive binders', len(nb))
print('CONCLUSION equal (after S->shieldS0):', norm(sub(oc)) == norm(nc))
print('--- binders only in dg (removed):')
for k in od:
    if k not in nd: print('  ', k, '::', od[k][0][:200])
print('--- binders only in blkAlive (added):')
for k in nd:
    if k not in od: print('  ', k, '::', nd[k][0][:300])
print('--- binders in both, text differs:')
for k in nd:
    if k in od and od[k] != nd[k]:
        print('  ', k)
        print('     dg :', od[k][0][:300])
        print('     new:', nd[k][0][:300])
print('--- binders in both, identical:', sum(1 for k in nd if k in od and od[k] == nd[k]))
# order check
print('order of shared names preserved:', [k for k in od if k in nd] == [k for k in nd if k in od])
print('names in dg:', list(od.keys()))
