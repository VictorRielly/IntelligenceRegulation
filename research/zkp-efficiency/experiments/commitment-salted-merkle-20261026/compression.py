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

