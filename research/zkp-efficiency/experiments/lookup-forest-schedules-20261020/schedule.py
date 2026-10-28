"""Private arithmetic-layer service model. This is not a GKR protocol."""
def plan(sizes, cached_depth):
    assert cached_depth >= 0
    assert sizes and all(n > 0 and n & (n-1) == 0 for n in sizes)
    heights = [n.bit_length()-1 for n in sizes]
    cuts = [min(cached_depth,h) for h in heights]
    # All top caches and the root-join tree stay live, conservatively.
    retained = sum(2**(b+1)-1 for b in cuts) + len(sizes)-1
    targets = [(n,h,b,t) for n,h,b in zip(sizes,heights,cuts) for t in range(b+1,h+1)]
    # DFS block reductions build each requested layer without lower arrays.
    build = sum(n-1 for n in sizes) + len(sizes)-1
    redo = sum(n-2**t for n,h,b,t in targets)
    leaves = sum(sizes) + sum(n for n,h,b,t in targets)
    stack = max(heights)+1
    # Upper bound includes retained cache, a whole service layer, DFS frontier.
    peak = retained + max([2**t + (h-t+1) for n,h,b,t in targets]+[stack])
    return dict(cached_depth=cached_depth,retained_nodes=retained,
      arithmetic_peak_upper_bytes=32*peak,initial_internal_nodes=build,
      recomputed_internal_nodes=redo,total_internal_nodes=build+redo,
      internal_work_ratio=(build+redo)/build if build else None,leaf_generations=leaves,
      initial_leaf_generations=sum(sizes),leaf_generation_ratio=leaves/sum(sizes),
      literal_fp2_products=3*(build+redo),literal_fp2_additions=build+redo,
      requested_recomputed_layer_vectors=len(targets),
      semantic_private_column_root_pairs=len(sizes),
      original_ordered_A_column_links=len(sizes)-1,global_histograms=1,
      unbatched_column_binary_main_rounds=sum(h*(h-1)//2 for h in heights),
      actual_GKR_CFS_PCS_mask_sites=None,
      exclusions='A/model storage, other H/M, GKR folds/sumcheck scratch, commitment encoding/trees, masks/CFS/PCS sites, transfers, allocation and launch costs; no physical fit or net memory claim')

def combine(x,y,p):
    a,b=x;c,d=y
    return ((a*d+c*b)%p,b*d%p)

def reduce_stream(read,start,size,p,counter):
    if size==1:
        counter['leaves']+=1
        return read(start)
    left=reduce_stream(read,start,size//2,p,counter)
    right=reduce_stream(read,start+size//2,size//2,p,counter)
    counter['internal']+=1
    return combine(left,right,p)

def serve(read,n,b,p):
    """Build top cache once; emit lower layers in proof-consumption order."""
    h=n.bit_length()-1;b=min(b,h);counter=dict(leaves=0,internal=0)
    width=2**b
    cut=[reduce_stream(read,j*n//width,n//width,p,counter) for j in range(width)]
    cache={b:cut}
    for t in range(b-1,-1,-1):
        v=cache[t+1]
        cache[t]=[combine(v[j],v[j+1],p) for j in range(0,len(v),2)]
        counter['internal']+=len(cache[t])
    root=cache[0][0]
    outputs=[]
    for t in range(1,h+1):
        if t<=b: v=cache[t]
        else:
            w=2**t
            v=[reduce_stream(read,j*n//w,n//w,p,counter) for j in range(w)]
        # Tiny oracle retains outputs for testing only. The modeled consumer
        # discards each layer before requesting the next; no real proof run.
        outputs.append(v)
    return root,outputs,counter
