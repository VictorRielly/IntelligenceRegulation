import re
def load(f):
    names=[];types={};concl=None;binfo={}
    for l in open(f).read().split('\n'):
        m=re.match(r'BINDER (\S+) \[(.*?)\] :: (.*)$',l)
        if m: names.append(m.group(1)); types[m.group(1)]=m.group(3); binfo[m.group(1)]=m.group(2)
        elif l.startswith('CONCLUSION :: '): concl=l[len('CONCLUSION :: '):]
    return names,types,binfo,concl
on,ot,ob,oc=load('sig_blkAlive.txt'); nn,nt,nb,nc=load('sig_pinsHd.txt')
print('kernel binder counts (all, explicit+implicit+inst): blkAlive',len(on),'pinsHd',len(nn))
print('explicit-only: blkAlive',sum(1 for k in on if 'default' in ob[k]),'pinsHd',sum(1 for k in nn if 'default' in nb[k]))
print('conclusion identical:',oc==nc)
print('removed:',[k for k in on if k not in nt])
print('added:',[(k,nb[k]) for k in nn if k not in ot])
chg=[k for k in nn if k in ot and ot[k]!=nt[k]]
print('changed type text:',chg)
print('kept identical:',sum(1 for k in nn if k in ot and ot[k]==nt[k]))
print('duplicate-named binders old/new:',len(on)-len(set(on)),len(nn)-len(set(nn)))
print('ORDER (shared) preserved:',[k for k in on if k in nt]==[k for k in nn if k in ot])
print('implicit/inst new or removed:', [k for k in nn if k not in ot and 'default' not in nb[k]], [k for k in on if k not in nt and 'default' not in ob[k]])
print('--- refined (instance binders matched by hygiene-free name)')
isinst=lambda k:k.startswith('inst.')
print('removed non-inst:',[k for k in on if k not in nt and not isinst(k)],len([k for k in on if k not in nt and not isinst(k)]))
print('added non-inst:',[(k,nb[k]) for k in nn if k not in ot and not isinst(k)])
print('inst binders old/new:',sum(isinst(k) for k in on),sum(isinst(k) for k in nn))
i=nn.index('dPos0'); print('dPos0 position',i,'neighbors',nn[i-2:i+3])
print('explicit binder count old/new', sum(1 for k in on if 'default' in ob[k]), sum(1 for k in nn if 'default' in nb[k]))
