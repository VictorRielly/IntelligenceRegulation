"""Independent symbolic lookup-list and explicit plane reference; no Rust execution."""
def byte(x): return [x]
def sym(x): return [x+'lo',x+'hi']
def top(x): return [x+'scaled']
def lists(ln,ls,lp,full,dd):
    norm=lambda x: sym(x)+[x+'r'+str(i) for i in range(ln)]+([] if full else top(x+'r'))+[x+'s'+str(i) for i in range(ln)]+([] if full else top(x+'s'))
    div=[f'p{i}' for i in range(lp)]+top('p')+[f'r{i}' for i in range(ls)]+top('r')+[f's{i}' for i in range(ls)]+top('s')
    return dict(L=byte('a')+byte('am'),
      D=byte('xl0')+byte('xl1')+norm('na')+['al0','al1','ral','ralscaled','x1l0','x1l1']+norm('nm')+['x2l0','x2l1','zl0','zl1','rdl','rdlscaled'],
      Q=sym('q')+['rq','rqscaled']+sym('qr')+['rqr','rqrscaled']+sym('o')+['ro0','ro1','ro1scaled'],
      Kv=sym('k')+['rk','rkscaled']+sym('v')+['rv','rvscaled']+sym('kr')+['rkr','rkrscaled'],
      F=['rg','rgscaled','ul0','ul1','hl0','hl1','rh0','rh1','rh1scaled'],
      S=sym('s8')+['rsl','rslscaled']+([] if dd else div), Dd=div if dd else [])

def census(T,d,hd,kv,fp,lc,w,fe,dd):
    ln=(w+7)//8; ls=((T-1).bit_length()+fe+7)//8
    l=lists(ln,ls,2,w%8==0,dd)
    n=2**lc
    ext=dict(T=T,Ht=32*T,L=16*T,D=T*d,Q=T*32*hd,Kv=T*kv*hd,S=32*T*T,F=T*fp,Tab=256,Dd=32*T*32)
    sizes={k:max(n,1<<(v-1).bit_length()) if k not in ('T','Ht') else 1<<(v-1).bit_length() for k,v in ext.items()}
    hs=[]
    for dom in ['L','D','Q','Kv','S','F']+(['Dd'] if dd else []):
        for i in range(0,len(l[dom]),2): hs.append((dom,'U8',tuple(l[dom][i:i+2])))
        if dom=='S':
            hs.append((dom,'exp',()))
            if dd: hs.append((dom,'dd_query',()))
        if dom=='F': hs.append((dom,'act',()))
        if dom=='Dd': hs.append((dom,'dd_table',()))
    hs.extend([('Tab',x,()) for x in ('u8_table','exp_table','act_table','zero_sum')])
    a={'T':4,'Ht':2,'L':2,'D':19+4*ln,'Q':7,'Kv':6,'S':5 if dd else 7+2*ls,'F':11,'Tab':3}
    if dd: a['Dd']=4+2*ls
    sites=1+1+22+2+2+7+2+2+(a['D']+2)+(a['Q']+1)+(a['Kv']+1)+(a['S']+2)+a['F']+3+2
    if dd: sites+=a['Dd']+1
    ar=sum(count*max(1,sizes[dom]//n) for dom,count in a.items())+2*sites+2
    hr=sum(2*sizes[dom]//n for dom,_,_ in hs)+2*len(hs)+2
    return sizes,l,hs,ar,hr

def rational_tree(leaves,p):
    current=list(leaves)
    while len(current)>1:
        current=[((a*d+c*b)%p,b*d%p) for (a,b),(c,d) in zip(current[::2],current[1::2])]
    return current[0]
