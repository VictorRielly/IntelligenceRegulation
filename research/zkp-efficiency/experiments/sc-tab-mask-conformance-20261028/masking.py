"""Source-derived CFS and BLAKE3 transcript model. No native prover/PCS."""
import blake3
from field import F, P

def digest(data, key=None):
    return blake3.blake3(data, max_threads=1, **({} if key is None else {'key':key})).digest()

class Transcript:
    def __init__(self, domain, key=None):
        self.key=key; self.state=digest(b'hashline-v1/'+domain,key); self.counter=0
    def absorb(self,label,data):
        self.state=digest(self.state+len(label).to_bytes(8,'little')+label+len(data).to_bytes(8,'little')+data,self.key)
    def fp2(self,label,values): self.absorb(label,b''.join(v.wire() for v in values))
    def u64(self,label,n): self.absorb(label,n.to_bytes(8,'little'))
    def challenge(self):
        self.state=digest(self.state+b'squeeze'+self.counter.to_bytes(8,'little'),self.key); self.counter+=1
        return F(int.from_bytes(self.state[:16],'little'),int.from_bytes(self.state[16:],'little'))

class Mask:
    def __init__(self,n,d,coeffs):
        if n<1 or d<1 or len(coeffs)!=n*d+2: raise ValueError('mask shape')
        self.n,self.d,self.coeffs=n,d,list(coeffs)
    def u(self,j,x):
        out=F(); xp=F(1)
        for e in range(self.d):
            xp*=x; out+=self.coeffs[2+j*self.d+e]*xp
        return out
    def total(self):
        return self.coeffs[0]*(1<<self.n)+self.coeffs[1]+sum(self.coeffs[2:],F())*(1<<(self.n-1))
    def weights(self,point):
        if len(point)!=self.n: raise ValueError('mask point')
        prod=F(1)
        for x in point: prod*=x
        out=[F(1),prod]
        for x in point:
            xp=F(1)
            for _ in range(self.d): xp*=x; out.append(xp)
        return out
    def evaluate(self,point): return sum((a*b for a,b in zip(self.coeffs,self.weights(point))),F())
    def round(self,j,prev):
        if len(prev)!=j or not 0<=j<self.n: raise ValueError('mask round')
        base=self.coeffs[0]+sum((self.u(i,r) for i,r in enumerate(prev)),F())
        base+=sum((self.u(i,F(1))/2 for i in range(j+1,self.n)),F())
        prod=F(1)
        for r in prev: prod*=r
        return [(base+self.u(j,F(x)))*(1<<(self.n-1-j))+self.coeffs[1]*prod*x for x in range(self.d+1)]

def refuse_c(c):
    if c==F(): raise ValueError('zero CFS mask challenge; discard attempt')
def refuse_terminal(es):
    if any(e in (F(),F(1)) for e in es): raise ValueError('degenerate terminal mask challenge; discard attempt')
