"""Native-style public address model; no CUDA, cryptographic proof or timing."""

def brev32(x):
    x = ((x & 0x55555555) << 1) | ((x >> 1) & 0x55555555)
    x = ((x & 0x33333333) << 2) | ((x >> 2) & 0x33333333)
    x = ((x & 0x0f0f0f0f) << 4) | ((x >> 4) & 0x0f0f0f0f)
    x = ((x & 0x00ff00ff) << 8) | ((x >> 8) & 0x00ff00ff)
    return ((x << 16) | (x >> 16)) & 0xffffffff

def owner(j, lb, mode):
    if mode == 'literal':
        return j
    if mode == 'reverse':
        return brev32(j) >> (32 - lb)
    h = int(mode[-1])
    return ((j & ((1 << h)-1)) << (lb-h)) | (j >> h)

def p1(logn, nsrc, row, blk, threads, base=0, mode='literal'):
    lb = min(logn, 12)
    bs = 1 << lb
    out=[]
    for it in range((bs+threads-1)//threads):
        for warp in range((threads+31)//32):
            lanes=[]
            for lane in range(32):
                tid=warp*32+lane
                j=tid+it*threads
                if tid >= threads or j >= bs:
                    continue
                q=owner(j,lb,mode)
                r=brev32(blk*bs+q) >> (32-logn)
                addr=base+8*(row*nsrc+r) if r<nsrc else None
                lanes.append((q,r,addr))
            if lanes: out.append(lanes)
    return out

def sectors(warps):
    return sum(len({a//32 for _,_,a in w if a is not None}) for w in warps)

def bank_demand(warps, group=32):
    # Unique 32-bit words per bank for ALL shared writes, including zero tail.
    # This is address pressure, not actual SASS instruction/wavefront timing.
    peak=0
    for warp in warps:
        for start in range(0,len(warp),group):
            banks=[set() for _ in range(32)]
            for q,_,_ in warp[start:start+group]:
                for part in (0,1):
                    word=2*q+part
                    banks[word%32].add(word)
            peak=max(peak,max(map(len,banks),default=0))
    return peak

def dif_pa(logn,row,tile,threads):
    lt=logn-12
    J=4096 >> lt
    assert 0<=lt<=12 and J>0
    out=[]
    for it in range((4096+threads-1)//threads):
        for warp in range((threads+31)//32):
            w=[]
            for lane in range(32):
                q=it*threads+warp*32+lane
                if q>=4096:continue
                t=q//J; jj=q-t*J
                idx=t*4096+tile*J+jj
                w.append((q,idx,8*(row*(1<<logn)+idx)))
            if w:out.append(w)
    return out

def dif_pb(logn,row,blk,threads):
    bs=1<<min(logn,12)
    return [[(q,blk*bs+q,8*(row*(1<<logn)+blk*bs+q))
             for q in range(start,min(start+32,bs))]
            for start in range(0,bs,32)]

def dit_pad(logn,row,blk,rb,skip):
    bs=1<<min(logn,12); nsrc=1<<(logn-rb)
    return [[(q,(blk*bs+q)>>rb,
               8*(row*nsrc+((blk*bs+q)>>rb))
               if skip or ((blk*bs+q)&((1<<rb)-1))==0 else None)
             for q in range(start,min(start+32,bs))]
            for start in range(0,bs,32)]
