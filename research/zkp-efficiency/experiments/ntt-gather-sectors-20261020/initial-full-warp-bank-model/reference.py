"""Independent scalar bit-string/index and byte-interval oracle."""
from collections import defaultdict

def reverse(x, bits):
    return int(format(x, '0%db' % bits)[::-1],2)

def tile(logn,nsrc,row,blk,base):
    size=min(4096,2**logn)
    return [(reverse(blk*size+q,logn),
             base+8*(row*nsrc+reverse(blk*size+q,logn))
             if reverse(blk*size+q,logn)<nsrc else None)
            for q in range(size)]

def sectors(warps):
    total=0
    for warp in warps:
        byte_sectors=set()
        for _,_,address in warp:
            if address is not None:
                byte_sectors.update(b//32 for b in range(address,address+8))
        total+=len(byte_sectors)
    return total

def banks(warps):
    peaks=[]
    for warp in warps:
        touched=defaultdict(set)
        for q,_,_ in warp:
            for b in range(q*8,q*8+8):
                touched[(b//4)%32].add(b//4)
        peaks.append(max(map(len,touched.values()),default=0))
    return max(peaks,default=0)

def coefficient(row,col,seed):
    return (seed + 0x9e3779b9*(row+1) + 0x100000001b3*(col+1)) % 0xffffffff00000001

def read(address,base,physical_stride,logical_width,seed):
    row,col=divmod((address-base)//8,physical_stride)
    return coefficient(row,col,seed) if col<logical_width else 0

def expected_values(logn,row,blk,logical_width,seed):
    size=min(4096,2**logn)
    return [coefficient(row,r,seed) if r<logical_width else 0
            for r in [reverse(blk*size+q,logn) for q in range(size)]]
