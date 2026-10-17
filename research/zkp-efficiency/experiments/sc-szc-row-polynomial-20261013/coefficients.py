"""Public-shape polynomial arithmetic; no secret-dependent coefficient pruning.

Charges each coefficient operation including scalar products. The first
contribution to a convolution output initializes it directly. Degree/loop
lengths and first-contribution positions derive solely from the expression.
"""
from field_support import F

class Coeff:
    def __init__(self, values): self.c=tuple(values)
    @staticmethod
    def lift(value): return value if isinstance(value,Coeff) else Coeff([value if isinstance(value,F) else F(value)])
    def combine(self,other,kind,counts):
        other=Coeff.lift(other); out=[]
        for i in range(max(len(self.c),len(other.c))):
            a=self.c[i] if i<len(self.c) else F()
            b=other.c[i] if i<len(other.c) else F()
            counts[kind]+=1; out.append(a+b if kind=='add' else a-b)
        return Coeff(out)
    def multiply(self,other,counts):
        other=Coeff.lift(other); out=[None for _ in range(len(self.c)+len(other.c)-1)]
        for i,a in enumerate(self.c):
            for j,b in enumerate(other.c):
                counts['mul']+=1; product=a*b
                if out[i+j] is None: out[i+j]=product
                else: counts['add']+=1; out[i+j]=out[i+j]+product
        assert all(x is not None for x in out)
        return Coeff(out)
    def scale_base(self,b,counts):
        counts['mul_base']+=len(self.c)
        return Coeff([a*b for a in self.c])
    def evaluate(self,t,counts):
        # t is the public original integer sample coordinate.
        if t==0: return self.c[0]
        value=self.c[-1]
        for c in reversed(self.c[:-1]):
            counts['mul_base']+=1; counts['add']+=1
            value=value*t+c
        return value

class PolynomialValue:
    def __init__(self,value,counts): self.value,self.counts=Coeff.lift(value),counts
    def add(self,rhs):
        rhs=rhs.value if isinstance(rhs,PolynomialValue) else rhs
        return PolynomialValue(self.value.combine(rhs,'add',self.counts),self.counts)
    def sub(self,rhs):
        rhs=rhs.value if isinstance(rhs,PolynomialValue) else rhs
        return PolynomialValue(self.value.combine(rhs,'sub',self.counts),self.counts)
    def mul(self,rhs):
        rhs=rhs.value if isinstance(rhs,PolynomialValue) else rhs
        return PolynomialValue(self.value.multiply(rhs,self.counts),self.counts)
    def mul_base(self,rhs):
        return PolynomialValue(self.value.scale_base(rhs,self.counts),self.counts)

class LiftedPlan:
    def __init__(self,plan): self.plan=plan
    def evaluate(self,j,values,counts):
        offset,ops=self.plan.entries[j]; out=PolynomialValue(offset,counts)
        for i,kind,c in ops:
            self.plan.dispatch[kind]+=2
            if kind=='Unit': out=out.sub(values[i])
            elif kind=='Neg': out=out.add(values[i])
            else: out=out.sub(values[i].mul_base(c))
        return out
