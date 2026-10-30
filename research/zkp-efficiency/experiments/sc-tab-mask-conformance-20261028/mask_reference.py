"""Independent tuple arithmetic, monomial mask and byte-frame replay."""
import itertools
import blake3
from reference import P,Z,O,add,sub,mul

def power(a,e):
    out=O
    for _ in range(e): out=mul(out,a)
    return out

def polynomial(coeffs,point,d=3):
    out=coeffs[0]; product=O
    for x in point: product=mul(product,x)
    out=add(out,mul(coeffs[1],product))
    for j,x in enumerate(point):
        for e in range(1,d+1): out=add(out,mul(coeffs[2+j*d+e-1],power(x,e)))
    return out

def cube(n): return itertools.product((Z,O),repeat=n)

def round_direct(coeffs,n,prefix,d=3):
    out=[]
    for x in range(d+1):
        value=Z
        for tail in cube(n-len(prefix)-1): value=add(value,polynomial(coeffs,[*prefix,(x,0),*tail],d))
        out.append(value)
    return out

def total_direct(coeffs,n,d=3):
    out=Z
    for point in cube(n): out=add(out,polynomial(coeffs,point,d))
    return out

def lagrange(values,r):
    result=Z
    for i,v in enumerate(values):
        numerator=O; denom=1
        for j in range(len(values)):
            if i!=j: numerator=mul(numerator,sub(r,(j,0))); denom=denom*(i-j)%P
        result=add(result,mul(v,mul(numerator,(pow(denom,-1,P),0))))
    return result

class Replay:
    def __init__(self,domain,key=None):
        self.key=key; self.counter=0; self.state=self.hash(b'hashline-v1/'+domain)
    def hash(self,data):
        h=blake3.blake3(max_threads=1,**({} if self.key is None else {'key':self.key}))
        h.update(data); return h.digest()
    def absorb(self,label,payload):
        b=bytearray(self.state)
        for part in (len(label).to_bytes(8,'little'),label,len(payload).to_bytes(8,'little'),payload): b.extend(part)
        self.state=self.hash(b)
    def fp2(self,label,values):
        b=bytearray()
        for a,c in values: b.extend((a%P).to_bytes(8,'little')); b.extend((c%P).to_bytes(8,'little'))
        self.absorb(label,b)
    def u64(self,label,n): self.absorb(label,n.to_bytes(8,'little'))
    def challenge(self):
        block=self.hash(self.state+b'squeeze'+self.counter.to_bytes(8,'little'))
        self.counter+=1; self.state=block
        return (int.from_bytes(block[:16],'little')%P,int.from_bytes(block[16:],'little')%P)
