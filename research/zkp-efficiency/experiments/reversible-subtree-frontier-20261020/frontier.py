"""Research-only online factory: immutable top frontier + disposable tiles.

No transcript, private proof, mask, commitment, or verifier is implemented.
Direct and reversible services see identical original ordered leaf sources.
"""
from fp2 import E,P
from reversible import Tree
from tiled_fp2 import consumer

def mix(x,y):return x[0]*y[1]+y[0]*x[1],x[1]*y[1]

class Frontier:
    def __init__(self,read,n,f,mode='direct',leaf_inverse=None):
        h=n.bit_length()-1
        if n<2 or n!=1<<h or not 0<=f<=h or mode not in ('direct','batch','cached'):
            raise ValueError('shape/mode')
        if mode=='cached' and leaf_inverse is None:raise ValueError('cache reader required')
        self.n,self.h,self.f,self.B=n,h,f,n>>f
        self.read,self.mode,self.leaf_inverse=read,mode,leaf_inverse
        self.count=dict(source_reads=0,cache_key_reads=0,build_muls=0,build_adds=0,
                        restore_muls=0,restore_subs=0,inversions=0,scans=0,
                        tile_builds=0,prefix_peak_E=0,tile_peak_pairs=0)
        bottom=[]
        for base in range(0,n,self.B):
            bottom.append(self._reduce(base,self.B))
        levels=[bottom]
        while len(levels[-1])>1:
            v=levels[-1];levels.append([self._mix(v[j],v[j+1]) for j in range(0,len(v),2)])
        self.levels=tuple(tuple(v) for v in reversed(levels))
        self.frontier_E=2*sum(len(v) for v in self.levels)

    def _read(self,i):
        self.count['source_reads']+=1
        a,b=self.read(i)
        if b==0:raise ValueError('zero denominator even at zero numerator')
        return a,b

    def _mix(self,x,y):
        self.count['build_muls']+=3;self.count['build_adds']+=1
        return mix(x,y)

    def _reduce(self,start,width):
        if width==1:return self._read(start)
        return self._mix(self._reduce(start,width//2),self._reduce(start+width//2,width//2))

    def layer(self,d):
        if not 0<=d<=self.h:raise ValueError('depth')
        self.count['scans']+=1
        if d<=self.f:
            yield from self.levels[d];return
        width=1<<d
        if self.mode=='direct':
            for j in range(width):yield self._reduce(j*self.n//width,self.n//width)
            return
        ell=d-self.f
        for base in range(0,self.n,self.B):
            tree=Tree(lambda i:self._read(base+i),self.B)
            tree.build();self.count['tile_builds']+=1
            self.count['tile_peak_pairs']=max(self.count['tile_peak_pairs'],self.B)
            for t in range(ell):
                if self.mode=='cached' and t==self.B.bit_length()-2:
                    # Final restored children are original leaves. Charge one
                    # original-A/index evaluation for each right leaf key.
                    m=1<<tree.active_depth
                    for k in range(m):
                        i=2*k;j=i+1
                        self.count['cache_key_reads']+=1
                        inv=self.leaf_inverse(base+j,tree.data[j][1])
                        tree._restore(i,j,inv)
                    tree.active_depth+=1
                else:tree.expand('batch')
            for k in ['build_mul','build_add','recover_mul','recover_sub','inversions']:
                dest={'build_mul':'build_muls','build_add':'build_adds','recover_mul':'restore_muls','recover_sub':'restore_subs','inversions':'inversions'}[k]
                self.count[dest]+=tree.count[k]
            self.count['prefix_peak_E']=max(self.count['prefix_peak_E'],tree.count['prefix_peak_E'])
            yield from tree.layer()
            del tree

    def consume(self,d,point,challenges,q,lam):
        stats=dict(scans=0,leaves=0,internal=0,fold_scalar_updates=0,stream_eq_products=0)
        g=consumer(lambda:self.layer(d),1<<(d-1),point,q,lam,P,stats)
        rows=[]
        try:
            row=next(g)
            for r in challenges:
                rows.append(row);row=g.send(r)
        except StopIteration as end:
            if len(rows)!=len(challenges):raise ValueError('challenge count')
            return rows,end.value[0],end.value[1],stats
        raise ValueError('missing challenge')

def schedule(n,f,qmax=4,cap_bytes=32*2**20):
    h=n.bit_length()-1
    out=[]
    for d in range(1,h+1):
        k=d-1;q=0
        if d>f:
            while 64*((1<<k)>>q)>cap_bytes and q<min(qmax,k):q+=1
        out.append((d,q))
    return out

def model(n,f,mode,columns=1,qmax=4,cap_bytes=32*2**20):
    """Conservative native payload upper bound, not measured VRAM/RSS.

    Includes resident inactive tails, source tile, batch prefix, consumer tile,
    immutable frontier, root forest and same scalar allowance as cycle0107.
    Original A, histogram/cache, masks/CFS/PCS, allocator and driver excluded.
    Cache-key reads charged separately; never counted as free leaf inverses.
    """
    h=n.bit_length()-1;B=n>>f;m=1<<f
    base_E=(4*m-2)+2*(2*columns-1)
    counts=dict(source_reads=n,cache_key_reads=0,build_muls=3*(n-1),
                build_adds=n-1,restore_muls=0,restore_subs=0,inversions=0)
    events=[dict(phase='frontier-build',alloc_E={'frontier+roots':base_E,'dfs':2*(h+1)})]
    def factors(k):return 0 if k<0 else (1<<(k//2))+(1<<(k-k//2))
    for d,q in schedule(n,f,qmax,cap_bytes):
        k=d-1;rows=1<<k;scans=q+1;ell=max(0,d-f)
        scratch=16+4*(k+1)
        service={}
        if d>f:
            counts['source_reads']+=scans*n
            if mode=='direct':
                counts['build_muls']+=scans*3*(n-(1<<d));counts['build_adds']+=scans*(n-(1<<d))
                service={'source-dfs':2*(h-d+1)}
            else:
                builds=scans*m
                counts['build_muls']+=builds*3*(B-1);counts['build_adds']+=builds*(B-1)
                nodes=(1<<ell)-1
                counts['restore_subs']+=builds*nodes
                counts['restore_muls']+=builds*(6*nodes-3*ell)
                counts['inversions']+=builds*ell
                prefix=1<<(ell-1)
                if mode=='cached' and d==h:
                    last=B//2
                    counts['restore_muls']-=builds*(3*last-3)
                    counts['inversions']-=builds
                    counts['cache_key_reads']+=builds*last
                    prefix=0 if ell==1 else 1<<(ell-2)
                service={'reversible-tile':2*B,'batch-prefix':prefix}
        for t in range(q):
            events.append(dict(phase=f'd{d}/prefix{t}',alloc_E={'frontier+roots':base_E,'consumer-tile':4*(1<<(t+1)),'eq':factors(k-t-1),'scalars':scratch,**service}))
        events.append(dict(phase=f'd{d}/materialize',alloc_E={'frontier+roots':base_E,'resident-full-capacity':4*(rows>>q),'consumer-tile':4*(1<<q),'scalars':scratch,**service}))
        events.append(dict(phase=f'd{d}/resident',alloc_E={'frontier+roots':base_E,'resident-full-capacity':4*(rows>>q),'eq':factors(k-q-1),'scalars':scratch}))
    for e in events:e['bytes']=16*sum(e['alloc_E'].values())
    peak=max(events,key=lambda x:x['bytes'])
    return dict(n=n,f=f,B=B,mode=mode,columns=columns,counts=counts,peak_bytes=peak['bytes'],peak_phase=peak['phase'],events=events)
