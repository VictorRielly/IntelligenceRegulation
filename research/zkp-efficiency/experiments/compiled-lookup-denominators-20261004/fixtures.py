import random
from field_support import F,P
from source_port import layout
from polynomial_ir import expanded
def constants(cfg,draw):
    names=['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']
    names += ['mu'+str(j) for j in range(6+cfg['helpers'])]
    return {name:draw() for name in names}


def fixture(n,ls,padded,mode,rng,even=False):
    draw=lambda: F(rng.randrange(P),rng.randrange(P)) if mode=='full' else (
        F(rng.randrange(P)) if mode=='base' else F(rng.randrange(2)) if mode=='boolean' else F())
    cfg=layout(ls=ls,padded=padded,lookup_count=(7+2+2*ls-1) if even else None)
    const=constants(cfg,draw)
    # Keep batching weights nonzero; ZERO fixtures exercise data/Eq/challenges.
    for name in ['nu0','nu1','zeta']:
        if const[name]==0: const[name]=F(1)
    ir=expanded(cfg,const); tabs=[]
    short=max(0,n-1)
    for i in range(3):
        tabs.append(dict(kind='Eq',start=0,point=[draw() for _ in range(short if i==1 else n)]))
    for name in cfg['names'][3:]:
        if name in ('sum','mx','ght'):
            leading=[draw() for _ in range(1 << short)]
            words=[leading[i>>int(n>0)] for i in range(1 << n)]
        else: words=[draw() for _ in range(1 << n)]
        if padded and name in ('ght','gs'):
            # Ht is lifted; S additionally excludes j padding.
            words=[F(int((i>>int(n>0)) < max(1,(1<<short)-1)
                         and (name=='ght' or n==0 or i%2==0))) for i in range(1<<n)]
        if name=='mask': words=[F(int(i%2==0)) for i in range(1<<n)]
        tabs.append(dict(kind='Pub',words=words))
    return cfg,const,ir,tabs,[draw() for _ in range(n)]


