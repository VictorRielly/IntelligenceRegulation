"""Separate schedule oracle reads native claim_sites expressions.

Deliberately imports no catalog/candidate. Supports the inspected expression
subset only, and refuses unknown syntax rather than evaluating arbitrary code.
"""
import ast,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
def arith(text):
    node=ast.parse(text,mode='eval').body
    def run(n):
        if isinstance(n,ast.Constant) and type(n.value)==int:return n.value
        if isinstance(n,ast.BinOp) and isinstance(n.op,(ast.Add,ast.Sub,ast.Mult)):
            a,b=run(n.left),run(n.right)
            return a+b if isinstance(n.op,ast.Add) else a-b if isinstance(n.op,ast.Sub) else a*b
        raise ValueError('unsupported source arithmetic')
    return run(node)

def sites(g, source=None):
    source=(HERE/'native/hashline__src__private_block__shape.rs').read_text() if source is None else source
    body=source.split('pub(crate) fn claim_sites(&self)',1)[1].split('/// private terminals',1)[0]
    # An independent domain count, taken from the source's plane declarations.
    planes={'L':2,'D':4+2*g.ln+8+2*g.ln+7,'Q':7,'Kv':6,'S':5 if g.dd else 5+g.lp+2*g.ls,'F':11,'Dd':2+g.lp+2*g.ls}
    per_norm=2+2*(g.ln+(not g.full_norm))
    look={'L':2,'D':2+per_norm+6+per_norm+2+4,'Q':13,'Kv':12,'F':9,
          'S':4 if g.dd else 2+2+(g.lp+1)+2*(g.ls+1),'Dd':(g.lp+1)+2*(g.ls+1)}
    answer={}
    for cm,name,expr in re.findall(r'([ah])\[SC_(\w+)\] = ([^;]+);',body):
        if name=='DD' and not g.dd:continue
        expr=re.sub(r'self.a_planes_on\(Dom::(\w+)\)',lambda m:str(planes[m[1]]),expr)
        expr=re.sub(r'self.helpers\(Dom::(\w+)\)',lambda m:str((look[m[1]]+1)//2),expr)
        expr=expr.replace('usize::from(self.dd_cap > 0)',str(int(bool(g.dd)))).replace('LIMBS_ISQRT','3')
        answer[(cm.upper(),name)]=arith(expr)
    loop=re.search(r'for s in \[([^]]+)\] \{\s*a\[s\] = (\d+);',body)
    assert loop
    for name in re.findall(r'SC_(\w+)',loop[1]):answer[('A',name)]=int(loop[2])
    return answer

P=18446744069414584321
def plus(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def times(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def comp(a):return ((1-a[0])%P,-a[1]%P)
def cube(data,point):
    acc=(0,0)
    for x,v in enumerate(data):
        weight=(1,0)
        for i,r in enumerate(point):weight=times(weight,r if x>>(len(point)-1-i)&1 else comp(r))
        acc=plus(acc,times(weight,v))
    return acc
def fold(data,point):
    out=list(data)
    for r in point:
        n=len(out)//2
        out=[plus(times(comp(r),out[j]),times(r,out[j+n])) for j in range(n)]
    assert len(out)==1
    return out[0]
def point(site,rho,fixed):
    out=[]
    for k,v in site.coords:
        if k=='rho':out.append(rho[v])
        elif k=='flip':out.append(comp(rho[v]))
        elif k=='fixed':out.append(fixed[v])
        else:raise ValueError(k)
    m=min(site.log,site.row)
    return out[site.log-m:]
