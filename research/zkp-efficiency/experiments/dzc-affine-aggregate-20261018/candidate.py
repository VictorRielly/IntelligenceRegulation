"""Locally authored affine precombination, proof-local only."""
from reference import *
def prepare(mu,c,ln):
    num,numm,dv,den=c[:4]; neg=lambda a:sub(Z,a)
    terms={8:sub(mu[2],mu[5]),20:sub(mu[3],mu[5]),24:sub(add(mu[4],mu[5]),mu[9]),
           37:add(mu[8],mu[9]),36:sub(mu[10],mu[9]),43:sub(scale(mu[0],dv),scale(mu[1],den)),44:sub(scale(mu[6],dv),scale(mu[7],den))}
    for ix,a in zip(maps(ln),[sub(mu[1],mu[0]),mu[1],sub(mu[7],mu[6]),mu[7]]):
        for k,j in enumerate(ix):terms[j]=a if k==0 else scale(a,pow(256,k,P))
    for j,i in [(9,2),(21,3),(25,4),(38,8),(40,10)]:terms[j]=neg(mu[i]);terms[j+1]=neg(scale(mu[i],256))
    const=add(scale(sm(mu[i] for i in [2,3,4,8,10]),32768),add(mu[1],mu[7]))
    bil=[scale(mu[0],num),neg(scale(mu[0],den)),scale(mu[6],numm),neg(scale(mu[6],den))]
    return terms,const,bil
def linear(v,prep):
    ts,c,_=prep
    return add(c,sm(mul(a,v[j]) for j,a in ts.items()))
def linear_base(v,prep):
    ts,c,_=prep
    if any(v[j][1] for j in ts):raise ValueError('complete base-source contract refused')
    return add(c,sm(scale(a,v[j][0]) for j,a in ts.items()))
def combined(v,l,prep):
    return add(l,sm(mul(a,mul(v[j],v[k])) for a,(j,k) in zip(prep[2],[(3,8),(43,11),(4,24),(44,27)])))
def full_candidate(v,l,prep,p,supp,ln):
    ex,host,g=extras(v,p,supp,ln)
    return add(mul(v[0],add(ex,mul(g,combined(v,l,prep)))),host)
