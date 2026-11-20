"""Independent pure-Python BLAKE3 reference vs Sol's worker (read-only use)."""
import sys, struct, random
sys.dont_write_bytecode = True
sys.path.insert(0, '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3')
from d78_blake3_primitive184 import Blake3Primitive

M = 0xFFFFFFFF
IV = [0x6A09E667,0xBB67AE85,0x3C6EF372,0xA54FF53A,0x510E527F,0x9B05688C,0x1F83D9AB,0x5BE0CD19]
PERM = [2,6,3,10,7,0,4,13,1,11,12,5,9,14,15,8]
CS, CE, PA, RO, KH, DC, DM = 1, 2, 4, 8, 16, 32, 64

def rotr(x, n): return ((x >> n) | (x << (32 - n))) & M

def g(s, a, b, c, d, mx, my):
    s[a] = (s[a] + s[b] + mx) & M; s[d] = rotr(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & M;      s[b] = rotr(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b] + my) & M; s[d] = rotr(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & M;      s[b] = rotr(s[b] ^ s[c], 7)

def compress(cv, w, counter, blen, flags):
    s = list(cv[:8]) + IV[:4] + [counter & M, (counter >> 32) & M, blen, flags]
    m = list(w)
    for r in range(7):
        g(s,0,4,8,12,m[0],m[1]); g(s,1,5,9,13,m[2],m[3]); g(s,2,6,10,14,m[4],m[5]); g(s,3,7,11,15,m[6],m[7])
        g(s,0,5,10,15,m[8],m[9]); g(s,1,6,11,12,m[10],m[11]); g(s,2,7,8,13,m[12],m[13]); g(s,3,4,9,14,m[14],m[15])
        if r < 6: m = [m[i] for i in PERM]
    for i in range(8):
        s[i] ^= s[i+8]; s[i+8] ^= cv[i]
    return s

def words(b):
    b = b + bytes(64 - len(b))
    return list(struct.unpack('<16I', b))

def chunk_out(kw, chunk, counter, base):
    cv = list(kw)
    blocks = [chunk[i:i+64] for i in range(0, len(chunk), 64)] or [b'']
    for i, blk in enumerate(blocks):
        fl = base | (CS if i == 0 else 0) | (CE if i == len(blocks)-1 else 0)
        if i == len(blocks)-1:
            return (cv, words(blk), counter, len(blk), fl)
        cv = compress(cv, words(blk), counter, 64, fl)[:8]

def cvof(o): return compress(o[0], o[1], o[2], o[3], o[4])[:8]

def node(kw, chunks, start, count, base):
    if count == 1:
        return chunk_out(kw, chunks[start], start, base)
    left = 1
    while left * 2 < count: left *= 2
    l = cvof(node(kw, chunks, start, left, base)); r = cvof(node(kw, chunks, start+left, count-left, base))
    return (list(kw), l + r, 0, 64, base | PA)

def root_bytes(o, n):
    out = b''
    t = 0
    while len(out) < n:
        out += struct.pack('<16I', *compress(o[0], o[1], t, o[3], o[4] | RO)); t += 1
    return out[:n]

def hash_(data, key=None, context=None, n=32):
    if context is not None:
        ck = root_bytes(node(IV, [context.encode()] if len(context.encode()) <= 1024 else None, 0, 1, DC), 32)
        kw, base = list(struct.unpack('<8I', ck)), DM
    elif key is not None:
        kw, base = list(struct.unpack('<8I', key)), KH
    else:
        kw, base = IV, 0
    chunks = [data[i:i+1024] for i in range(0, len(data), 1024)] or [b'']
    return root_bytes(node(kw, chunks, 0, len(chunks), base), n)

assert hash_(b'').hex() == 'af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262'
KEY = b"whats the Elvish word for friend"
CTX = "BLAKE3 2019-12-27 16:29:52 test vectors context"
# official vector prefixes quoted in probe183 (len 0..2 only) as sanity
assert hash_(b'', key=KEY).hex() == '92b2b75604ed3c761f9d6f62392c8a9227ad0ea3f09573e783f1498a4ed60d26'
assert hash_(b'', context=CTX).hex() == '2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d'
print('reference matches 3 official empty-input vectors')

lengths = [0,1,2,3,63,64,65,127,128,129,1023,1024,1025,2047,2048,2049,3072,3073,4096,4097,5120,5121,7168,7169,8192,8193,31744,40000]
random.seed(7)
bad = 0; n = 0
with Blake3Primitive() as p:
    for L in lengths:
        data = bytes(i % 251 for i in range(L))
        for kw in ({}, {'key': KEY}, {'context': CTX}):
            for ln in (32, 131):
                got = p.hash(data, length=ln, **kw)
                want = hash_(data, n=ln, **kw)
                n += 1
                if got != want:
                    bad += 1; print('MISMATCH', L, list(kw), ln)
    # random keys / contexts, random data
    for _ in range(40):
        L = random.choice([0, 5, 64, 1000, 1024, 1500, 2049, 6000, 10000])
        data = bytes(random.getrandbits(8) for _ in range(L))
        key = bytes(random.getrandbits(8) for _ in range(32))
        n += 1
        if p.hash(data, key=key) != hash_(data, key=key): bad += 1; print('MISMATCH rand key', L)
print('worker-vs-reference comparisons', n, 'mismatches', bad)
