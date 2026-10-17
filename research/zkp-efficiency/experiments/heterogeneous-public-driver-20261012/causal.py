"""MSB half-split public comparator; leading axes are intentionally ignored.

During t binding retain two values for each bound j prefix: strict prefix
greater (lo), and prefix greater-or-equal (hi). Boolean suffix decides which
one to read. After t binding keep hi and fold the j axis normally.
"""
from field import F, fold
class CausalMask:
    def __init__(self, leading, token_bits):
        if type(leading)!=int or type(token_bits)!=int or min(leading,token_bits)<0:
            raise ValueError('invalid public dimensions')
        self.leading=leading;self.lt=token_bits;self.n=leading+2*token_bits
        self.bound=0;self.lo=[F(0)];self.hi=[F(1)]
        self.interpolations=0;self.reads=0;self.predicates=0
        self.peak_words=2
    def remaining(self): return self.n-self.bound
    def at(self,index):
        if type(index)!=int or index<0 or index>=1<<self.remaining():
            raise ValueError('residual index out of range')
        self.reads+=1
        k=max(0,min(self.lt,self.bound-self.leading))
        if self.bound>=self.leading+self.lt:
            return self.hi[index]
        tpad=1<<self.lt;j=index%tpad;t=(index//tpad)%(1<<(self.lt-k))
        jp=j>>(self.lt-k);js=j&((1<<(self.lt-k))-1)
        self.predicates+=1
        return self.hi[jp] if js<=t else self.lo[jp]
    def bind(self,r):
        if self.bound==self.n: raise ValueError('already terminal')
        if self.bound<self.leading: pass
        elif self.bound<self.leading+self.lt:
            lo=[];hi=[]
            for a,b in zip(self.lo,self.hi):
                middle=a+r*(b-a);self.interpolations+=1
                lo.extend([middle,a]);hi.extend([b,middle])
            # Old and new vectors coexist during preparation. At the last t
            # bit hi suffices; lo is discarded immediately afterwards.
            self.peak_words=max(self.peak_words,len(self.lo)+len(self.hi)+len(lo)+len(hi))
            self.lo,self.hi=lo,hi
            if self.bound+1==self.leading+self.lt: self.lo=[]
        else:
            new=fold(self.hi,r);self.interpolations+=len(new)
            self.peak_words=max(self.peak_words,len(self.hi)+len(new))
            self.hi=new
        self.bound+=1
    def terminal(self):
        if self.bound!=self.n: raise ValueError('not terminal')
        return self.at(0)
def eval_formula(leading,lt,point):
    if len(point)!=leading+2*lt: raise ValueError('point arity')
    out=F(1)
    # Comparator recurrence includes equality via the constant terminal 1.
    for t,j in reversed(list(zip(point[leading:leading+lt],point[leading+lt:]))):
        out=t*(1-j)+((1-t)*(1-j)+t*j)*out
    return out
