"""Synthetic complete-layer consumer and allocation ledger; not a ZK protocol.

Contract: immutable child pairs, four independent in-place mutable fold planes,
and one mutable equality plane; all capacities retained to end of layer service.
Native byte model is Fp2=16, fraction pair=32. Python RSS is separate.
"""
def mix(a,b,p):
    return ((a[0]*b[1]+b[0]*a[1])%p,a[1]*b[1]%p)

def reduce_at(read,start,n,p,count):
    if n==1:
        count['leaves']+=1
        v=read(start)
        if v[1]%p==0: raise ValueError('zero denominator even at zero multiplicity')
        return v
    l=reduce_at(read,start,n//2,p,count)
    r=reduce_at(read,start+n//2,n//2,p,count)
    count['internal']+=1
    return mix(l,r,p)

def eq_weights(point,p):
    v=[1]
    for r in reversed(point):
        v=[z for x in v for z in (x*(1-r)%p,x*r%p)]
    return v

def fold_inplace(v,n,r,p):
    for j in range(n//2):v[j]=(v[2*j]+r*(v[2*j+1]-v[2*j]))%p

def consume(child,point,challenges,lam,p):
    """Unmasked cubic sumcheck arithmetic oracle, no FS/transcript/privacy claim."""
    n=len(child)//2
    planes=[[child[2*j+side][coord] for j in range(n)] for side,coord in [(0,0),(0,1),(1,0),(1,1)]]
    planes.append(eq_weights(point,p))
    def term(v):
        a,b,c,d,e=v
        return e*(a*d+c*b+lam*b*d)%p
    claim=sum(term([v[j] for v in planes]) for j in range(n))%p
    samples=[];active=n
    for r in challenges:
        row=[]
        for x in range(4):
            row.append(sum(term([(v[2*j]+x*(v[2*j+1]-v[2*j]))%p for v in planes]) for j in range(active//2))%p)
        samples.append(row)
        for v in planes:fold_inplace(v,active,r,p)
        active//=2
    assert active==1
    return claim,samples,term([v[0] for v in planes]),planes

def serve(read,n,b,p):
    h=n.bit_length()-1;b=min(b,h);count={'leaves':0,'internal':0}
    width=2**b
    cache={b:[reduce_at(read,j*n//width,n//width,p,count) for j in range(width)]}
    for d in range(b-1,-1,-1):
        c=cache[d+1];cache[d]=[mix(c[j],c[j+1],p) for j in range(0,len(c),2)]
        count['internal']+=len(cache[d])
    for d in range(1,h+1):
        w=2**d
        child=cache[d] if d<=b else [reduce_at(read,j*n//w,n//w,p,count) for j in range(w)]
        yield d,child,cache[0][0],count

class Arena:
    def __init__(self):self.live={};self.peak=0;self.events=[]
    def add(self,key,size):
        assert key not in self.live
        self.live[key]=size;self.peak=max(self.peak,sum(self.live.values()))
        self.events.append(('alloc',key,size,sum(self.live.values())))
    def drop(self,key):
        size=self.live.pop(key);self.events.append(('drop',key,size,sum(self.live.values())))

def allocation_trace(sizes,b,mode):
    """Public symbolic sizes only, never allocate modeled large arrays."""
    assert mode in ('forest','column') and b>=0
    assert sizes and all(n>0 and n&(n-1)==0 for n in sizes)
    a=Arena();k=len(sizes);heights=[n.bit_length()-1 for n in sizes]
    # Global private roots + binary joins, conservative persistence.
    a.add('roots',32*(2*k-1))
    if mode=='forest':
        for i,h in enumerate(heights):a.add('cache'+str(i),32*(2**(min(b,h)+1)-1))
    a.add('initial_dfs_allowance',32*(max(heights)+1));a.drop('initial_dfs_allowance')
    work=sum(n-1 for n in sizes)+k-1;leaves=sum(sizes)
    for i,(n,h) in enumerate(zip(sizes,heights)):
        cut=min(b,h)
        if mode=='column':
            a.add('cache'+str(i),32*(2**(cut+1)-1))
            a.add('checkpoint_dfs_allowance',32*(h+1));a.drop('checkpoint_dfs_allowance')
            work+=n-1;leaves+=n
        for d in range(1,h+1):
            w=2**d
            if d>cut:
                a.add('child',32*w)
                a.add('layer_dfs_allowance',32*(h-d+1));a.drop('layer_dfs_allowance')
                work+=n-w;leaves+=n
            # Four Fp2 planes of width w/2, plus equality of width w/2.
            for j in range(5):a.add('fold'+str(j),16*(w//2))
            for j in range(5):a.drop('fold'+str(j))
            if d>cut:a.drop('child')
        if mode=='column':a.drop('cache'+str(i))
    baseline=sum(sizes)-1
    return {'mode':mode,'cached_depth':b,'modeled_peak_bytes':a.peak,
      'tree_internal_nodes':work,'tree_work_ratio':work/baseline if baseline else None,
      'leaf_generations':leaves,'leaf_ratio':leaves/sum(sizes),'events':a.events,
      'fold_scalar_updates':sum(5*max(n-1-h,0) for n,h in zip(sizes,heights)),
      'new_mask_claim_PCS_sites':None}
