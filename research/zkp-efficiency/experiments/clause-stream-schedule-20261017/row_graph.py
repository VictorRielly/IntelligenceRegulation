"""Public expression identities only; no actual field values enter compilation.

SSA interpretation validates arithmetic/counts, not native performance. Literal
constants may intern; public challenges, prepared denominators and padding weights
are distinct symbolic input slots. No private equality or degree pruning.
"""
from collections import Counter
import hashlib,json
from types import SimpleNamespace
from field_support import F
from coefficients import Coeff,LiftedPlan
from static_plan import StaticRowPlan,compile_mul
from polynomial_clause import bracket


class Symbol(F):
    __slots__=('graph','index')
    def __init__(self,graph,index): self.graph,self.index=graph,index
    def __add__(self,x): return self.graph.op('add',self,x)
    __radd__=__add__
    def __sub__(self,x): return self.graph.op('sub',self,x)
    def __rsub__(self,x): return self.graph.op('sub',x,self)
    def __mul__(self,x): return self.graph.op('mul_base' if isinstance(x,int) else 'mul',self,x)
    def __rmul__(self,x): return self.__mul__(x)
    def __neg__(self): return self.graph.op('sub',F(),self)
    def __eq__(self,x): raise AssertionError('No symbolic/private value comparisons')


class Graph:
    def __init__(self,cse,squares):
        self.cse,self.squares=cse,squares
        self.nodes=[];self.memo={};self.counts=Counter();self.setup=Counter()
    def new(self,node):
        idx=len(self.nodes);self.nodes.append(node);return Symbol(self,idx)
    def input(self,label): return self.new(('input',label))
    def lift(self,x):
        if isinstance(x,Symbol):
            assert x.graph is self
            return x
        if not isinstance(x,F): x=F(x)
        key=('literal',x.a,x.b)
        if key not in self.memo:self.memo[key]=self.new(key)
        return self.memo[key]
    def op(self,kind,a,b):
        self.setup['operator_visits']+=1
        a,b=self.lift(a),self.lift(b)
        i,j=a.index,b.index
        if kind in ('add','mul') and i>j:i,j=j,i
        key=(kind,i,j)
        if self.cse and key in self.memo:
            self.setup['cse_hits']+=1
            return self.memo[key]
        r=self.new(key);self.counts[kind]+=1
        if self.cse:self.memo[key]=r
        return r
    def multiply(self,a,b,counts):
        self.setup['coefficient_products']+=1
        b=Coeff.lift(b)
        ai=tuple(self.lift(x).index for x in a.c)
        bi=tuple(self.lift(x).index for x in b.c)
        if self.squares and len(ai)==2 and ai==bi:
            self.setup['structural_square_sites']+=1
            x,y=map(self.lift,a.c)
            cross=x*y
            counts.update(mul=3,add=1)
            return Coeff([x*x,cross+cross,y*y])
        return compile_mul(len(ai),len(bi)).execute(list(map(self.lift,a.c)),list(map(self.lift,b.c)),counts)
    def run(self,inputs,mutation=None):
        values=[];counts=Counter();changed=False
        for node in self.nodes:
            kind=node[0]
            if kind=='input':v=inputs[node[1]]
            elif kind=='literal':v=F(node[1],node[2])
            else:
                x,y=values[node[1]],values[node[2]]
                if mutation=='sub_sign' and kind=='sub' and not changed:kind='add';changed=True
                counts[kind]+=1
                v=x+y if kind=='add' else x-y if kind=='sub' else x*y.a if kind=='mul_base' else x*y
            values.append(v)
        assert counts==self.counts or mutation
        out=[values[i] for i in self.outputs]
        if mutation=='drop_tail':out[-1]=F()
        return Coeff(out),counts
    def record(self):
        uses=Counter(i for n in self.nodes if n[0] not in ('input','literal') for i in n[1:])
        uses.update(self.outputs);live=set();peak=0
        for i,n in enumerate(self.nodes):
            # Includes input/literal words when first materialized, all outputs.
            if uses[i]:live.add(i)
            peak=max(peak,len(live))
            if n[0] not in ('input','literal'):
                for x in n[1:]:
                    uses[x]-=1
                    if not uses[x]:live.discard(x)
        raw=json.dumps([self.nodes,self.outputs],separators=(',',':')).encode()
        return dict(counts=dict(self.counts),setup=dict(self.setup),nodes=len(self.nodes),
            serialized_graph_json_bytes=len(raw),schema_sha256=hashlib.sha256(raw).hexdigest(),
            model_peak_live_words=peak,interpreter_retained_words=len(self.nodes))


def compile_row(cfg,public_pattern,const_names,entries,cse=True,squares=True):
    g=Graph(cse,squares)
    vv=[]
    for i in range(len(cfg['names'])):
        v=g.input(('v',i));d=g.input(('d',i))
        vv.append(Coeff([v] if i in public_pattern and not public_pattern[i] else [v,d]))
    con={k:g.input(('c',k)) for k in const_names}
    offsets=[(g.input(('offset',j)),ops) for j,(_,ops) in enumerate(entries)]
    plan=LiftedPlan(SimpleNamespace(entries=offsets,dispatch=Counter()))
    weights=[g.input(('pad',j)) for j in range((2 if cfg['supports'][0] else 0)+(len(cfg['splanes']) if cfg['supports'][1] else 0))]
    original=Coeff.multiply
    Coeff.multiply=lambda self,other,counts:g.multiply(self,other,counts)
    try:poly,counts=bracket(0,vv,cfg,con,den_eval=plan.evaluate,pad_weights=weights)
    finally:Coeff.multiply=original
    width=5 if cfg['padded'] else 4
    g.zero_pads=width-len(poly.c)
    g.outputs=tuple(g.lift(x).index for x in list(poly.c)+[F()]*(width-len(poly.c)))
    g.source_counter=dict(counts)
    return g


class CSERowPlan(StaticRowPlan):
    def __init__(self,*a,cse=True,squares=True,**kw):
        super().__init__(*a,**kw);self.graphs={};self.cse=cse;self.squares=squares
    def begin(self,values,differences):
        assert self.pending is None and self.round_index is not None
        if 0 not in self.coefficient_groups:
            return super().begin(values,differences)
        key=self.key();self.k_work['public_pattern_lookups']+=1
        if key not in self.graphs:
            self.graphs[key]=compile_row(self.cfg,dict(key),sorted(self.const),self.plan.plan.entries,self.cse,self.squares)
        g=self.graphs[key]
        inputs={('v',i):x for i,x in enumerate(values)}
        inputs.update({('d',i):x for i,x in enumerate(differences)})
        inputs.update({('c',k):v for k,v in self.const.items()})
        inputs.update({('offset',j):off for j,(off,_) in enumerate(self.plan.plan.entries)})
        weight=F(1)
        # Native PadTerm::add computes weights at definition construction.
        # Cache proof-local weights in this same definition, charge separately.
        if not hasattr(self,'weights'):
            self.weights=[]
            for _ in range((2 if self.cfg['supports'][0] else 0)+(len(self.cfg['splanes']) if self.cfg['supports'][1] else 0)):
                self.weights.append(weight);weight=weight*self.const['zeta'];self.setup['pad_weight_mul']+=1
        inputs.update({('pad',j):x for j,x in enumerate(self.weights)})
        poly,counts=g.run(inputs,self.mutation)
        self.pending=[poly,None,None];self.counts.update(counts)
        self.k_work['interpreter_opcode_steps']+=sum(counts.values())
        self.axis_work['public_axis_tests']+=len(self.dependencies)
        inactive=sum(not active for _,active in key)
        self.axis_work['removed_public_slope_carriers']+=inactive
        self.axis_work['zero_output_assignments']+=g.zero_pads
        width=5 if self.cfg['padded'] else 4
        self.max_coefficient_words=max(self.max_coefficient_words,width)
        self.rows+=1;self.t=0

