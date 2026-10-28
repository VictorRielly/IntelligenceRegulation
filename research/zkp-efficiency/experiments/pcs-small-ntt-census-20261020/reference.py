"""Independent integer geometry and bit-string/byte-sector reference."""
def pow2(log):
    n = 1
    for _ in range(log):
        n *= 2
    return n

def geometry(log_cols, rate, checks, pads, token_count, width):
    n = pow2(log_cols)
    nn = n * rate
    if rate < 2 or rate & (rate - 1):
        raise ValueError('row geometry')
    if pads < checks:
        raise ValueError('pad budget')
    if n + pads > nn:
        raise ValueError('pad capacity')
    k = 0
    while pow2(k) < nn:
        k += 1
    return dict(n=n, nn=nn, log_nn=k, q_pad=pads,
                compact_stride=n+pads,
                endpoint_rows=(token_count * width + n - 1)//n + 5)

def requests(logn, stride, row, rotate, base=0):
    """Every P1 tile in a complete row, independent of native brev32 code.

    Scalar 8-byte alignment is required. These are summed warp requests;
    neither cache misses nor physical DRAM traffic is computed.
    """
    N = pow2(logn)
    bs = min(N,4096)
    requests = 0
    active = 0
    coverage = set()
    for block in range(N//bs):
        for start in range(0,bs,32):
            sectors=set()
            for j in range(start,start+32):
                q = j if not rotate else (j//2 + (j%2)*(bs//2))
                x = block*bs+q
                r = int(format(x, '0%db'%logn)[::-1],2)
                coverage.add((block,q))
                if r < stride:
                    address = base+8*(row*stride+r)
                    for byte in range(address,address+8):
                        sectors.add(byte//32)
                    active += 1
            requests += len(sectors)
    assert len(coverage)==N
    return requests,active

def eligible(logn, backend):
    return backend=='k_ntt_p1' and pow2(8)<=pow2(logn)<=pow2(13)
