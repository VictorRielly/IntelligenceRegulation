"""Independent bottom-up topology, explicit basis sums and phase lifetimes."""
def tree(v,p):
    levels=[list(v)]
    while len(levels[-1])>1:
        prev=levels[-1];nxt=[]
        for j in range(0,len(prev),2):
            x,y=prev[j],prev[j+1]
            nxt.append(((x[0]*y[1]+x[1]*y[0])%p,x[1]*y[1]%p))
        levels.append(nxt)
    return levels[::-1]

def mle(v,point,p):
    total=0
    for j,x in enumerate(v):
        weight=1
        for bit,r in enumerate(point):weight=weight*(r if (j>>bit)&1 else 1-r)%p
        total=(total+x*weight)%p
    return total

def direct_samples(child,point,challenges,lam,p):
    s=len(child)//2;k=s.bit_length()-1
    planes=[[child[2*j+side][coord] for j in range(s)] for side,coord in [(0,0),(0,1),(1,0),(1,1)]]
    eq=[]
    for j in range(s):
        w=1
        for bit,r in enumerate(point):w=w*(r if (j>>bit)&1 else 1-r)%p
        eq.append(w)
    planes.append(eq)
    def value(pt):
        a,b,c,d,e=[mle(v,pt,p) for v in planes]
        return e*(a*d+c*b+lam*b*d)%p
    rows=[]
    for rnd in range(k):
        vals=[]
        for x in range(4):
            vals.append(sum(value(challenges[:rnd]+[x]+[(j>>bit)&1 for bit in range(k-rnd-1)]) for j in range(2**(k-rnd-1)))%p)
        rows.append(vals)
    return rows,value(challenges)

def cost(sizes,b,mode):
    hs=[n.bit_length()-1 for n in sizes];rootbytes=32*(2*len(sizes)-1)
    caches=[32*sum(2**j for j in range(min(b,h)+1)) for h in hs]
    resident=sum(caches) if mode=='forest' else 0
    phases=[rootbytes+resident+32*(max(hs)+1)]
    internal=sum(n-1 for n in sizes)+len(sizes)-1;leaf=sum(sizes)
    for idx,(n,h) in enumerate(zip(sizes,hs)):
        base=rootbytes+(resident if mode=='forest' else caches[idx])
        phases.append(base+32*(h+1))
        if mode=='column':internal+=n-1;leaf+=n
        for d in range(1,h+1):
            width=2**d
            if d>min(b,h):
                phases.extend([base+32*width+32*(h-d+1),base+72*width])
                internal+=sum(2**j for j in range(d,h));leaf+=n
            else:phases.append(base+40*width)
    return max(phases),internal,leaf

def verify_arithmetic(claim,rows,terminal,challenges,p):
    if len(rows)!=len(challenges):return False
    for row,r in zip(rows,challenges):
        if len(row)!=4 or (row[0]+row[1])%p!=claim:return False
        nxt=0
        for i,y in enumerate(row):
            weight=1
            for j in range(4):
                if i!=j:weight=weight*(r-j)*pow((i-j)%p,-1,p)%p
            nxt=(nxt+y*weight)%p
        claim=nxt
    return claim==terminal
