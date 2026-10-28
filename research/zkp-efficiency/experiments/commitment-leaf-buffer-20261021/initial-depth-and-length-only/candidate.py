"""Authored CPU model of the native streaming BLAKE3 column kernel.

Not a GPU implementation. The independent oracle is the already-installed
blake3 package (max_threads=1). Input is synthetic; no pads/salts are reused.
"""
import struct

IV = (0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
      0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19)
PERM = (2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8)
MASK = (1 << 32) - 1


def compress(cv, block, counter, length, flags):
    s = list(cv) + list(IV[:4]) + [counter & MASK, counter >> 32, length, flags]
    m = list(block)
    def rotate(x, n):
        return ((x >> n) | (x << (32 - n))) & MASK
    def g(a, b, c, d, x, y):
        s[a] = (s[a] + s[b] + x) & MASK
        s[d] = rotate(s[d] ^ s[a], 16)
        s[c] = (s[c] + s[d]) & MASK
        s[b] = rotate(s[b] ^ s[c], 12)
        s[a] = (s[a] + s[b] + y) & MASK
        s[d] = rotate(s[d] ^ s[a], 8)
        s[c] = (s[c] + s[d]) & MASK
        s[b] = rotate(s[b] ^ s[c], 7)
    for _ in range(7):
        for a,b,c,d,x,y in ((0,4,8,12,0,1),(1,5,9,13,2,3),(2,6,10,14,4,5),(3,7,11,15,6,7),
                           (0,5,10,15,8,9),(1,6,11,12,10,11),(2,7,8,13,12,13),(3,4,9,14,14,15)):
            g(a,b,c,d,m[x],m[y])
        m = [m[i] for i in PERM]
    return tuple(s[i] ^ s[i+8] for i in range(8))


def depth_for_rows(rows):
    # Only model the existing positive, u32-length-safe kernel arithmetic.
    # This is an adapter eligibility condition, not a new native refusal rule.
    if not 1 <= rows <= ((1 << 32) - 1 - 1023)//8:
        raise ValueError('outside modelled native arithmetic')
    return (((rows + 127)//128) - 1).bit_length()


def chunk_plan(rows, chunk):
    if rows <= chunk:
        return [(0, rows)]
    step = max(1, chunk//128)*128
    return [(r, min(step, rows-r)) for r in range(0, rows, step)]


class State:
    def __init__(self, depth, columns, full_zero=False):
        self.depth, self.nn = depth, columns
        self.words = [0xA5A5A5A5] * ((8*depth+1)*columns)
        self.written = set()
        self.full_zero = full_zero
        self.reset()

    def reset(self):
        # CV bytes are deliberately poisoned/stale. Track writes per proof.
        self.written.clear()
        if self.full_zero:
            self.words[:] = [0]*len(self.words)
        else:
            for j in range(self.nn):
                self.words[8*self.depth*self.nn+j] = 0
        self.reads = self.writes = self.peak = 0

    def get(self, slot, column):
        if not 0 <= slot < self.depth:
            raise ValueError('stack read outside capacity')
        self.reads += 8
        result=[]
        for i in range(8):
            at=(8*slot+i)*self.nn+column
            if at not in self.written:
                raise ValueError('read stale/uninitialized CV')
            result.append(self.words[at])
        return tuple(result)

    def put(self, slot, column, cv):
        if not 0 <= slot < self.depth:
            raise ValueError('stack write outside capacity')
        self.writes += 8
        self.peak=max(self.peak,slot+1)
        for i,v in enumerate(cv):
            at=(8*slot+i)*self.nn+column
            self.words[at]=v
            self.written.add(at)


def hash_columns(data, rows, nn, chunk=128, depth=None, full_zero=False,
                 state=None, mutation=None):
    needed=depth_for_rows(rows)
    if len(data)!=rows*nn:
        raise ValueError('data shape')
    depth=needed if depth is None else depth
    if depth<needed:
        raise ValueError('public capacity too short')
    state=State(depth,nn,full_zero) if state is None else state
    if state.depth<needed or state.nn!=nn:
        raise ValueError('state shape')
    leaves=[None]*nn
    trace=[]
    calls=0
    def run(cv,block,counter,length,flags):
        nonlocal calls
        calls+=1
        trace.append((counter,length,flags,tuple(cv),tuple(block)))
        return compress(cv,block,counter,length,flags)
    nchunks=(rows+127)//128
    for row0,rc in chunk_plan(rows,chunk):
        for j in range(nn):
            sl=state.words[8*state.depth*nn+j]
            for c in range(row0//128,(row0+rc+127)//128):
                last=c+1==nchunks
                want=c.bit_count()
                while sl>want:
                    pb=state.get(sl-2,j)+state.get(sl-1,j)
                    cv=run(IV,pb,0,64,4)
                    state.put(sl-2,j,cv)
                    sl-=1
                cv=IV
                clen=min(1024,rows*8-c*1024)
                for b in range((clen+63)//64):
                    blen=min(64,clen-b*64)
                    flags=(1 if b==0 else 0)|(2 if b*64+blen==clen else 0)
                    if last and sl==0 and b*64+blen==clen:
                        flags|=8
                    block=[]
                    for e in range(c*128+b*8,c*128+b*8+8):
                        v=data[e*nn+j] if e<rows else 0
                        if mutation=='endian':
                            v=int.from_bytes(v.to_bytes(8,'little'),'big')
                        block.extend((v&MASK,v>>32))
                    if mutation=='no_root':
                        flags&=~8
                    cv=run(cv,block,0 if mutation=='counter_zero' else c,blen,flags)
                if last:
                    for s in range(sl-1,-1,-1):
                        pb=state.get(s,j)+cv
                        flags=4|(8 if s==0 else 0)
                        if mutation=='no_root':
                            flags&=~8
                        cv=run(IV,pb,0,64,flags)
                    leaves[j]=struct.pack('<8I',*cv)
                    break
                state.put(sl,j,cv)
                sl+=1
            if leaves[j] is None:
                state.words[8*state.depth*nn+j]=sl
    assert all(x is not None for x in leaves)
    return leaves, state, trace, calls
