"""Local canonical Goldilocks2 arithmetic; no native/proof execution."""
P = 2**64 - 2**32 + 1
class F:
    __slots__ = ('a', 'b')
    def __init__(self, a=0, b=0): self.a, self.b = a % P, b % P
    def __add__(self, y):
        if not isinstance(y, F): y = F(y)
        return F(self.a+y.a, self.b+y.b)
    __radd__ = __add__
    def __neg__(self): return F(-self.a, -self.b)
    def __sub__(self, y): return self + (-y if isinstance(y, F) else -F(y))
    def __rsub__(self, y): return -self + y
    def __mul__(self, y):
        if not isinstance(y, F): return F(self.a*y, self.b*y)
        return F(self.a*y.a+7*self.b*y.b, self.a*y.b+self.b*y.a)
    __rmul__ = __mul__
    def __truediv__(self, y):
        if not isinstance(y, F): y = F(y)
        d = pow((y.a*y.a-7*y.b*y.b) % P, -1, P)
        return self * F(y.a*d, -y.b*d)
    def __eq__(self, y):
        if not isinstance(y, F): y = F(y)
        return self.a == y.a and self.b == y.b
    def wire(self): return self.a.to_bytes(8,'little')+self.b.to_bytes(8,'little')
def fold(v, r):
    half = len(v)//2
    return [a+r*(b-a) for a,b in zip(v[:half],v[half:])]
def bits(x, n): return [(x >> (n-1-i)) & 1 for i in range(n)]
