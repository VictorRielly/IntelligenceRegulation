"""Public table-use interpolation plan. Locally authored arithmetic projection."""
from collections import Counter
from field_support import F,lagrange,bits,eq,fold
from source_port import bracket

def dependencies(cfg):
    ix=cfg['index']
    groups=[set(range(3,len(cfg['names']))),{ix['sum']},{ix['s8'],ix['rsl']}]
    if cfg['padded']:
        groups[1].add(ix['ght']);groups[2].add(ix['gs'])
    return groups

def plan(k,degrees,deps):
    assert len(degrees)==len(deps) and k>0
    last=[-1]*k
    for d,indices in zip(degrees,deps):
        assert isinstance(d,int) and d>=1
        for i in indices:
            assert isinstance(i,int) and 0<=i<k
            last[i]=max(last[i],d)
    return last

class Rounds:
    def __init__(self,tables,points,cfg,const,sliced=False,debug=False,override=None,bracket_eval=bracket):
        assert tables and len(tables[0])>0 and len(tables[0])&(len(tables[0])-1)==0
        assert all(len(t)==len(tables[0]) for t in tables)
        self.tables=[list(t) for t in tables];self.points=points;self.cfg=cfg;self.const=const
        self.n=(len(tables[0])).bit_length()-1
        assert len(points)==3 and all(len(p)<=self.n for p in points)
        self.degrees=[4,2,2] if cfg['padded'] else [3,1,1]
        self.D=max(self.degrees)+1;self.prefix=[F(1)]*3;self.claims=[None]*3
        self.last=plan(len(tables),self.degrees,dependencies(cfg)) if override is None else override
        self.sliced=sliced;self.debug=debug;self.j=0;self.pending=None
        self.bracket_eval=bracket_eval
        self.counts=Counter();self.records=[]
    def round(self,j):
        assert j==self.j and j<self.n and self.pending is None
        m=len(self.tables[0])//2;k=len(self.tables);dmax=max(self.degrees)
        factors=[];weights=[];recover=[]
        for g,p in enumerate(self.points):
            active=j<len(p)
            factors.append([self.prefix[g]*(eq([p[j]],[F(t)]) if active else F(1)) for t in range(self.D+1)])
            rem=p[min(j+1,len(p)):];trailing=self.n-len(p) if rem else 0
            weights.append([eq(rem,[F(b) for b in bits(i>>trailing,len(rem))]) for i in range(m)])
            recover.append(self.claims[g] is not None and factors[g][1]!=0)
        hs=[[F() for _ in range(d+1)] for d in self.degrees]
        calls=[0]*3;cc=Counter();active=[i for i in range(k) if not self.sliced or self.last[i]>=0]
        for i in range(m):
            cur=[F() for _ in range(k)];dif=[F() for _ in range(k)]
            for q in active:
                cur[q]=self.tables[q][i];dif[q]=self.tables[q][i+m]-cur[q]
                cc['distinct_endpoint_reads']+=2;cc['difference_sub']+=1
            for t in range(dmax+1):
                for g,d in enumerate(self.degrees):
                    if t<=d and (t!=1 or not recover[g] or self.debug):
                        value,bc=self.bracket_eval(g,cur,self.cfg,self.const)
                        cc.update({'bracket_'+op:v for op,v in bc.items()})
                        hs[g][t]+=weights[g][i]*value;calls[g]+=1
                if t!=dmax:
                    for q in active:
                        if not self.sliced or t<self.last[q]:
                            cur[q]+=dif[q];cc['interpolation_add']+=1
        values=[]
        for g in range(3):
            if recover[g]:
                h1=(self.claims[g]-factors[g][0]*hs[g][0])/factors[g][1]
                if self.debug: assert h1==hs[g][1]
                hs[g][1]=h1;cc['recovered_groups']+=1
            elif self.claims[g] is not None: cc['zero_factor_fallbacks']+=1
            values.append([factors[g][t]*(hs[g][t] if t<len(hs[g]) else lagrange(hs[g],F(t))) for t in range(self.D+1)])
        self.pending=values;self.counts.update(cc)
        self.records.append(dict(j=j,pairs=m,k=k,active=len(active),last=list(self.last),calls=calls,counts=dict(cc)))
        return [sum((v[t] for v in values),F()) for t in range(self.D+1)]
    def fold(self,r):
        assert self.pending is not None
        for g,p in enumerate(self.points):
            self.claims[g]=lagrange(self.pending[g],r)
            if self.j<len(p):self.prefix[g]*=eq([p[self.j]],[r])
        self.tables=[fold(t,r) for t in self.tables];self.pending=None;self.j+=1
    def finals(self):
        assert self.j==self.n and self.pending is None
        return [t[0] for t in self.tables]
