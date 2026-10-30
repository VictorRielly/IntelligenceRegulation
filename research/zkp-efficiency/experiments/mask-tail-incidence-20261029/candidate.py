"""Exact current-call public-tail memoization. No private result stored."""
P=2**64-2**32+1
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):
    ac,bd=a[0]*b[0],a[1]*b[1]
    return ((ac+7*bd)%P,((a[0]+a[1])*(b[0]+b[1])-ac-bd)%P)
def weights(point):
    out=[(1,0)]
    for r in reversed(point):out=[mul(x,sub((1,0),r)) for x in out]+[mul(x,r) for x in out]
    return out
def tail(site,rho,fixed):
    full=tuple(rho[v] if k=='rho' else sub((1,0),rho[v]) if k=='flip' else fixed[v] for k,v in site.coords)
    return full[site.log-min(site.log,site.row):]
class Cache:
    def __init__(self,capacity=1,mutation=None):
        self.capacity=capacity;self.items=[];self.builds=0;self.hits=0
        self.reads=0;self.peak_words=0;self.mutation=mutation
    def get(self,p):
        key=len(p) if self.mutation=='length-only' else tuple(p)
        for j,(k,e) in enumerate(self.items):
            if k==key:
                self.hits+=1;self.items.append(self.items.pop(j));return e
        if len(self.items)==self.capacity:self.items.pop(0)
        e=weights(p);self.items.append((key,e));self.builds+=1
        self.peak_words=max(self.peak_words,sum(len(v) for _,v in self.items))
        return e
def evaluate(site,rho,fixed,rows,cache):
    eq=cache.get(tail(site,rho,fixed));a=b=(0,0)
    # Caller supplies distinct fresh base rows. c0 remains a per-site read.
    for j,(u,v) in enumerate(eq):
        x,y=rows[0][site.c0+j],rows[1][site.c0+j];cache.reads+=2
        a=add(a,(u*x%P,v*x%P));b=add(b,(u*y%P,v*y%P))
    return add(a,(7*b[1]%P,b[0]))
