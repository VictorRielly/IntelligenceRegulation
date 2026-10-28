"""Research-only leaf-salt/first-parent fusion. No native code is run.

The candidate retains every salted leaf and every parent. No root-only
shortcut is allowed. All hashes are ordinary 64-byte BLAKE3 messages under
the correct role key, NOT BLAKE3's internal PARENT compression mode.
"""
import struct
from compression import IV, compress


def hash64(message, key, mutation=None):
    if len(message) != 64 or (key is not None and len(key) != 32):
        raise ValueError('model requires 64-byte message and optional 32-byte key')
    cv = IV if key is None else struct.unpack('<8I', key)
    flags = 1 | 2 | 8 | (16 if key is not None else 0)
    if mutation == 'parent_flag': flags = 4 | 8 | (16 if key is not None else 0)
    if mutation == 'no_root': flags &= ~8
    if mutation == 'no_key_flag': flags &= ~16
    words = struct.unpack('>16I' if mutation == 'big_endian' else '<16I', message)
    return struct.pack('<8I', *compress(cv, words, 0, 64, flags))


def fused_tree(leaves, salts, leaf_key, node_key, mutation=None):
    n = len(leaves)
    if n < 1 or n & (n-1) or len(salts) != n:
        raise ValueError('model shape precondition')
    if any(len(x) != 32 for x in leaves + salts):
        raise ValueError('model digest/salt precondition')
    reads = writes = salt_calls = node_calls = 0
    salted = [None] * n
    first = [None] * (n//2)
    def salt(j):
        nonlocal reads, writes, salt_calls
        reads += 64; writes += 32; salt_calls += 1
        k = node_key if mutation == 'leaf_uses_node_key' else leaf_key
        msg = salts[j]+leaves[j] if mutation == 'salt_first' else leaves[j]+salts[j]
        out = hash64(msg, k, mutation)
        salted[j] = out
        return out
    def parent(a,b):
        nonlocal node_calls, writes
        node_calls += 1; writes += 32
        k = leaf_key if mutation == 'node_uses_leaf_key' else node_key
        return hash64(b+a if mutation == 'reverse_children' else a+b, k, mutation)
    if n == 1:
        salt(0)
        levels = [salted]
    else:
        for j in range(0,n,2):
            a, b = salt(j), salt(j+1)
            # The two digest values are local, rather than reloaded from L0.
            first[j//2] = parent(a,b)
        levels = [salted, first]
        while len(levels[-1]) > 1:
            previous = levels[-1]
            reads += len(previous)*32
            levels.append([parent(previous[j],previous[j+1]) for j in range(0,len(previous),2)])
    if mutation == 'drop_leaf_level': levels = levels[1:]
    return levels, dict(read_bytes=reads,write_bytes=writes,salt_calls=salt_calls,node_calls=node_calls)


def path(levels, index):
    return [level[(index >> depth)^1] for depth,level in enumerate(levels[:-1])]
