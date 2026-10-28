"""Exact big-integer F_p[u]/(u²-7); candidate, not native implementation."""
P = 2**64-2**32+1

class E:
    __slots__ = ('a', 'b')
    def __init__(self, a=0, b=0):
        self.a, self.b = a % P, b % P
    @staticmethod
    def coerce(x):
        return x if isinstance(x, E) else E(x)
    def __add__(self, y):
        y=E.coerce(y); return E(self.a+y.a, self.b+y.b)
    __radd__=__add__
    def __sub__(self, y):
        y=E.coerce(y); return E(self.a-y.a, self.b-y.b)
    def __rsub__(self, x): return E.coerce(x)-self
    def __neg__(self): return E(-self.a,-self.b)
    def __mul__(self, y):
        y=E.coerce(y)
        return E(self.a*y.a+7*self.b*y.b,self.a*y.b+self.b*y.a)
    __rmul__=__mul__
    def __mod__(self, p):
        assert p == P
        return self
    def __eq__(self, y):
        y=E.coerce(y); return self.a==y.a and self.b==y.b
    def inv(self):
        if self==0: raise ValueError('zero LogUp denominator; discard attempt')
        z=pow((self.a*self.a-7*self.b*self.b)%P,-1,P)
        return E(self.a*z,-self.b*z)
    def __repr__(self): return 'E(%d,%d)'%(self.a,self.b)
    def pair(self): return [self.a,self.b]

def batch_inverse_nonzero(v):
    prefix=[];acc=E(1)
    for x in v:
        if x==0: raise ValueError('zero LogUp denominator; discard attempt')
        prefix.append(acc);acc=acc*x
    if not v:return []
    out=[E()]*len(v);inv=acc.inv()
    for j in range(len(v)-1,-1,-1):
        out[j]=inv*prefix[j];inv=inv*v[j]
    return out

class Attempt:
    """Challenge-local cache; no artifact cache or cross-attempt sharing."""
    def __init__(self,alpha,g):
        self.alpha,self.g=alpha,g
        delta=alpha-g
        den=[delta-v for v in range(256)]
        self.den=tuple(den)
        inv=iter(batch_inverse_nonzero([x for x in den if x!=0]))
        self.cache=tuple(None if x==0 else next(inv) for x in den)
    def denominator(self,v):
        return self.den[v] if 0<=v<256 else self.alpha-(E(v)+self.g)
    def helper(self,v):
        if not -(1<<63)<=v<(1<<63):raise ValueError('not i64')
        if 0<=v<256:
            x=self.cache[v]
            if x is None:raise ValueError('zero LogUp denominator; discard attempt')
            return x
        return self.denominator(v).inv()
    def table_helper(self,multiplicity):
        if len(multiplicity)!=256:raise ValueError('table shape')
        # All table denominators checked BEFORE multiplication, including m=0.
        if any(x is None for x in self.cache):
            raise ValueError('zero LogUp denominator; discard attempt')
        return [x*m for x,m in zip(self.cache,multiplicity)]
    def leaf(self,v,m=1):
        d=self.denominator(v)
        if d==0:raise ValueError('zero LogUp denominator; discard attempt')
        return E(m),d

def wrap64(v):return ((v+(1<<63))%(1<<64))-(1<<63)

class OrderedLookup:
    """Immutable synthetic A planes and public Lk; native wrapping-i64 rule.

    This does not admit out-of-range witnesses. Full sumcheck A/range binding
    is still owed by any native protocol consumer.
    """
    def __init__(self,attempt,planes,terms,cst=0):
        self.attempt=attempt;self.planes=tuple(tuple(v) for v in planes)
        self.terms=tuple(terms);self.cst=cst
        if not self.planes or len({len(v) for v in self.planes})!=1:raise ValueError('shape')
        if any(not -(1<<63)<=x<(1<<63) for v in self.planes for x in v):raise ValueError('not i64')
    def value(self,index):
        acc=self.cst
        for plane,coef in self.terms:acc=wrap64(acc+wrap64(coef*self.planes[plane][index]))
        return acc
    def read(self,index):return self.attempt.leaf(self.value(index))
