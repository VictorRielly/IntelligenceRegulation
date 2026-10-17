"""Local symbolic equality, with exact generic reads and ordered terminals.

Row elision needs an internally derived bracket dependency contract. A caller
asserting that an opaque closure never reads a slot is not sufficient.
"""
from dataclasses import dataclass
from collections import Counter
from field import F

class Dead:
    def fail(self,*args): raise ValueError('unused equality row consumed')
    __add__=__radd__=__sub__=__rsub__=__mul__=__rmul__=__truediv__=__eq__=__mod__=__rmod__=__neg__=__bool__=fail
DEAD=Dead()

class Equality:
    def __init__(self,n,point,start=0):
        if type(n) is not int or n<0 or type(start) is not int or start<0 or start+len(point)>n:
            raise ValueError('equality span')
        self.n,self.point,self.start=n,tuple(point),start
        self.bound=0;self.scale=F(1);self.counts=Counter();self.lerps=0
    def at(self,index):
        tail=self.n-self.bound
        if type(index) is not int or not 0<=index<1<<tail:raise ValueError('equality index')
        value=self.scale;self.counts['generic_reads']+=1
        for k,w in enumerate(self.point):
            axis=self.start+k
            if axis>=self.bound:
                value*=w if (index>>(self.n-1-axis))&1 else 1-w
                self.counts['generic_weight_muls']+=1
        return value
    def bind(self,r):
        if self.bound==self.n:raise ValueError('equality overbind')
        if self.start<=self.bound<self.start+len(self.point):
            w=self.point[self.bound-self.start]
            self.scale*=(1-w)*(1-r)+w*r
            self.counts['active_scalar_binds']+=1
        else:self.counts['inactive_binds']+=1
        self.bound+=1
    def terminal(self):
        if self.bound!=self.n:raise ValueError('equality premature terminal')
        return self.scale

@dataclass(frozen=True)
class Dependencies:
    unused: tuple
    source_pin: str

def derive(entries,terms,source_pin):
    """Only a SOURCE-DERIVED immutable IR can justify dead bracket rows.

    For this experiment terms come from the separately audited native SC_SZC
    port. The production closure needs typed metadata or a sealed constructor;
    runtime probing alone cannot establish its dependency invariant.
    """
    if not source_pin:raise ValueError('dependency provenance')
    used={i for group in terms for coefficient,indices in group for i in indices}
    eq=tuple(i for i,(name,private,tab) in enumerate(entries)
             if isinstance(tab,Equality) and not private)
    return Dependencies(tuple(i for i in eq if i not in used),source_pin)

def scan_row(tables,index,dependencies):
    # Generic total/census continues to use Tables.row and exact Equality.at.
    unused=set(dependencies.unused) if dependencies else set()
    if any(i<0 or i>=len(tables.entries) or
           tables.entries[i][1] or not isinstance(tables.entries[i][2],Equality) for i in unused):
        raise ValueError('unused row role')
    return [DEAD if i in unused else t.at(index)
            for i,(_,_,t) in enumerate(tables.entries)]
