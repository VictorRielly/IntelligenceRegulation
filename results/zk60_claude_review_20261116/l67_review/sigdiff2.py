import re
def load(f):
    names = []; types = {}; prop = {}; binfo = {}
    for l in open(f).read().split('\n'):
        m = re.match(r'BINDER (\S+) \[(.*?)\] prop=(\w+) :: (.*)$', l)
        if m: names.append(m.group(1)); types[m.group(1)] = m.group(4); binfo[m.group(1)] = m.group(2); prop[m.group(1)] = m.group(3) == 'true'
    return names, types, prop, binfo
on, ot, op, ob = load('sigp_pinsHd.txt'); nn, nt, np_, nb = load('sigp_shieldInst.txt')
inst = lambda k: k.startswith('inst.')
print('pinsHd: total', len(on), 'inst', sum(map(inst, on)), 'non-inst', sum(not inst(k) for k in on), 'Prop binders', sum(op[k] for k in on), 'data/type binders', sum((not op[k]) and not inst(k) for k in on))
print('shieldInst: total', len(nn), 'inst', sum(map(inst, nn)), 'non-inst', sum(not inst(k) for k in nn), 'Prop binders', sum(np_[k] for k in nn), 'data/type binders', sum((not np_[k]) and not inst(k) for k in nn))
rem = [k for k in on if k not in nt and not inst(k)]
add = [k for k in nn if k not in ot and not inst(k)]
print('removed non-inst by name:', len(rem), ' Prop:', sum(op[k] for k in rem), ' data:', sum(not op[k] for k in rem))
print(' removed Prop:', [k for k in rem if op[k]])
print(' removed data:', [k for k in rem if not op[k]])
print('added non-inst:', len(add), ' Prop:', [k for k in add if np_[k]], ' data:', [k for k in add if not np_[k]])
kept = [k for k in nn if k in ot and not inst(k)]
print('kept by name (non-inst):', len(kept), 'text identical', sum(ot[k] == nt[k] for k in kept))
print('kept Prop binders:', [k for k in kept if np_[k]])
print('kept data binders:', [k for k in kept if not np_[k]])
print('shieldInst Prop binders (all):', [k for k in nn if np_[k]])
print('shieldInst data binders (all non-inst):', [k for k in nn if (not np_[k]) and not inst(k)])
