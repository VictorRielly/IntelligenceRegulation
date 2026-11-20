import re
D = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l68a_review/'
def load(f):
    names = []; types = {}; prop = {}; binfo = {}
    for l in open(D + f).read().split('\n'):
        m = re.match(r'BINDER (\S+) \[(.*?)\] prop=(\w+) :: (.*)$', l)
        if m:
            names.append(m.group(1)); types[m.group(1)] = m.group(4); binfo[m.group(1)] = m.group(2); prop[m.group(1)] = m.group(3) == 'true'
    return names, types, prop, binfo
on, ot, op, ob = load('sigp_shieldLu.txt'); nn, nt, np_, nb = load('sigp_blkLu.txt')
inst = lambda k: k.startswith('inst.')
print('shieldLu: total', len(on), 'inst', sum(map(inst, on)), 'non-inst', sum(not inst(k) for k in on),
      'Prop', sum(op[k] for k in on if not inst(k)), 'data/type', sum((not op[k]) and not inst(k) for k in on),
      'explicit', sum(1 for k in on if 'default' in ob[k]))
print('blkLu:    total', len(nn), 'inst', sum(map(inst, nn)), 'non-inst', sum(not inst(k) for k in nn),
      'Prop', sum(np_[k] for k in nn if not inst(k)), 'data/type', sum((not np_[k]) and not inst(k) for k in nn),
      'explicit', sum(1 for k in nn if 'default' in nb[k]))
rem = [k for k in on if k not in nt and not inst(k)]
add = [k for k in nn if k not in ot and not inst(k)]
kept = [k for k in nn if k in ot and not inst(k)]
print('REMOVED by name (non-inst):', len(rem), 'Prop', sum(op[k] for k in rem), 'data', sum(not op[k] for k in rem))
print('  removed Prop:', [k for k in rem if op[k]])
print('  removed data:', [k for k in rem if not op[k]])
print('ADDED (non-inst):', len(add), 'Prop', [k for k in add if np_[k]], 'data', [k for k in add if not np_[k]])
print('KEPT by name:', len(kept), 'text identical', sum(ot[k] == nt[k] for k in kept))
print('  kept with changed text:', [k for k in kept if ot[k] != nt[k]])
print('  kept identical text:', [k for k in kept if ot[k] == nt[k]])
print('kept Prop:', [k for k in kept if np_[k]])
print('kept data:', [k for k in kept if not np_[k]])
# the blkLu theorem has 41 binders; the explicit ones, by name
print('blkLu explicit:', [k for k in nn if 'default' in nb[k]])
print('blkLu implicit/inst:', [(k if not inst(k) else 'inst') for k in nn if 'default' not in nb[k]])
# text of a few kept ones
for k in ('O', 'hLI_stg'):
    print('---', k, 'old len', len(ot[k]), 'new len', len(nt[k]))
