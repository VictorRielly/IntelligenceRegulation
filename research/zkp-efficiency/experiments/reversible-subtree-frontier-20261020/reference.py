"""Independent tuple/polynomial-convolution arithmetic and Boolean-basis MLE.

No candidate field, reader, tiled fold, factor tables or cache imported.
"""
P=0xffffffff00000001
def add(x,y):return ((x[0]+y[0])%P,(x[1]+y[1])%P)
def sub(x,y):return ((x[0]-y[0])%P,(x[1]-y[1])%P)
def mul(x,y):
    z=[0,0,0]
    for i in range(2):
        for j in range(2):z[i+j]+=x[i]*y[j]
    return ((z[0]+7*z[2])%P,z[1]%P)
def power(x,n):
    out=(1,0)
    while n:
        if n&1:out=mul(out,x)
        x=mul(x,x);n>>=1
    return out
def inv(x):
    if x==(0,0):raise ValueError('zero denominator')
    return power(x,P*P-2)
def mix(x,y):return add(mul(x[0],y[1]),mul(x[1],y[0])),mul(x[1],y[1])
def tree(leaves):
    levels=[list(leaves)]
    while len(levels[-1])>1:
        a=levels[-1];levels.append([mix(a[j],a[j+1]) for j in range(0,len(a),2)])
    return levels[::-1]
def mle(v,point):
    out=(0,0)
    for j,x in enumerate(v):
        w=(1,0)
        for bit,r in enumerate(point):w=mul(w,r if j>>bit&1 else sub((1,0),r))
        out=add(out,mul(w,x))
    return out
def direct(child,point,ch,lam):
    m=len(child)//2;k=len(point)
    planes=[[child[2*j+s][c] for j in range(m)] for s,c in [(0,0),(0,1),(1,0),(1,1)]]
    eq=[]
    for j in range(m):
        w=(1,0)
        for t,r in enumerate(point):w=mul(w,r if j>>t&1 else sub((1,0),r))
        eq.append(w)
    def evaluate(pt):
        a,b,c,d=[mle(v,pt) for v in planes]
        return mul(mle(eq,pt),add(add(mul(a,d),mul(c,b)),mul(lam,mul(b,d))))
    rows=[]
    for t in range(k):
        row=[]
        for x in range(4):
            v=(0,0)
            for j in range(1<<(k-t-1)):
                pt=ch[:t]+[(x,0)]+[((j>>z)&1,0) for z in range(k-t-1)]
                v=add(v,evaluate(pt))
            row.append(v)
        rows.append(row)
    return rows,evaluate(ch),tuple(mle(v,ch) for v in planes)
def verify(claim,rows,terminal,ch):
    if len(rows)!=len(ch):return False
    for row,r in zip(rows,ch):
        if len(row)!=4 or add(row[0],row[1])!=claim:return False
        out=(0,0)
        for i,y in enumerate(row):
            weight=(1,0)
            for j in range(4):
                if i!=j:weight=mul(weight,mul(sub(r,(j,0)),(pow((i-j)%P,-1,P),0)))
            out=add(out,mul(y,weight))
        claim=out
    return claim==terminal
