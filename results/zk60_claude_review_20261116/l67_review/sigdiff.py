import re
def load(f):
    names = []; types = {}; concl = None; binfo = {}
    for l in open(f).read().split('\n'):
        m = re.match(r'BINDER (\S+) \[(.*?)\] :: (.*)$', l)
        if m: names.append(m.group(1)); types[m.group(1)] = m.group(3); binfo[m.group(1)] = m.group(2)
        elif l.startswith('CONCLUSION :: '): concl = l[len('CONCLUSION :: '):]
    return names, types, binfo, concl
on, ot, ob, oc = load('sig_pinsHd.txt'); nn, nt, nb, nc = load('sig_shieldInst.txt')
isinst = lambda k: k.startswith('inst')
ex = lambda b, k: 'default' in b[k]
print('binder counts all: pinsHd', len(on), 'shieldInst', len(nn))
print('explicit: pinsHd', sum(ex(ob, k) for k in on), 'shieldInst', sum(ex(nb, k) for k in nn))
print('conclusion identical (text):', oc == nc)
print('pinsHd concl:', oc[:400]); print('shieldInst concl:', nc[:400])
rem = [k for k in on if k not in nt]
add = [k for k in nn if k not in ot]
print('REMOVED by name', len(rem), 'explicit', sum(ex(ob, k) for k in rem)); print(rem)
print('ADDED by name', len(add), 'explicit', sum(ex(nb, k) for k in add)); print([(k, nb[k][:90]) for k in add])
print('kept by name', len([k for k in nn if k in ot]), 'text identical', len([k for k in nn if k in ot and ot[k] == nt[k]]))
print('CHANGED text:', [k for k in nn if k in ot and ot[k] != nt[k]])
