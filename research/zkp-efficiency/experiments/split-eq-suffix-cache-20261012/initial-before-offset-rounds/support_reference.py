"""Independent source port: enumerate logical heads, then flat support indices.

No imports of candidate field, axis specification, threshold or fold machinery.
Original-cube MLE uses oracle.py schoolbook Fp2 convolution and bit products.
"""
def pad(x): return 1 << (x-1).bit_length()
def source_cube(g,dom,cube_log=None):
    t,hq,hkv,dh,f=[g[x] for x in ('tokens','q_heads','kv_heads','head_dim','hidden')]
    tp,hp,dp,fp=pad(t),pad(hq),pad(hq*dh),pad(f)
    group=hq//hkv;per=hp//hkv
    slot=lambda h:(h//group)*per+h%group
    natural={'T':tp,'Ht':hp*tp,'S':hp*tp*tp,'D':tp*dp,'Q':tp*dp,
             'Kv':tp*hkv*dh,'F':tp*fp,'L':16*tp,'Tab':256}[dom]
    own=natural if dom in ('T','Ht') else max(natural,1<<g['row_log'])
    if dom in ('S','Q','Kv') and own!=natural: raise ValueError('native lifted bilinear domain')
    indices=[]
    if dom=='T': indices=list(range(t))
    if dom=='Ht': indices=[slot(h)*tp+z for h in range(hq) for z in range(t)]
    if dom=='S': indices=[(slot(h)*tp+z)*tp+j for h in range(hq) for z in range(t) for j in range(t)]
    if dom=='D': indices=[z*dp+i for z in range(t) for i in range(hq*dh)]
    if dom=='Q': indices=[z*dp+slot(h)*dh+i for z in range(t) for h in range(hq) for i in range(dh)]
    if dom=='Kv': indices=list(range(t*hkv*dh))
    if dom=='F': indices=[z*fp+i for z in range(t) for i in range(f)]
    if dom=='L': indices=[k*tp+z for k in range(9) for z in range(t)]
    if dom=='Tab': indices=list(range(256))
    base=[(0,0)]*own
    for i in indices: base[i]=(1,0)
    cube=own if cube_log is None else 1<<cube_log
    if cube<own or cube%own:raise ValueError('non tiling')
    rep=cube//own
    # Exact native B::supp repeat: coarse coordinate occupies LEADING bits.
    return [base[x//rep] for x in range(cube)]
