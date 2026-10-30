"""Independent complete-tree oracle. SHA256 is SYNTHETIC, not native BLAKE3.

Hash choice does not affect coordinate interning/byte identity. Native keyed
leaf/salt/node validation is explicitly not reproduced by this oracle.
"""
import hashlib
import struct


def h(data):
    return hashlib.sha256(data).digest()


def make_tree(depth, role):
    leaves = [h(b'synthetic-leaf/' + role + i.to_bytes(8, 'little'))
              for i in range(1 << depth)]
    tree = [leaves]
    while len(tree[-1]) > 1:
        old = tree[-1]
        tree.append([h(b'synthetic-node/' + role + old[i] + old[i + 1])
                     for i in range(0, len(old), 2)])
    return tree


def paths_for(tree, indices):
    result = []
    for i in indices:
        path = []
        for layer in tree[:-1]:
            sibling = i - 1 if i % 2 else i + 1
            path.append(layer[sibling])
            i //= 2
        result.append(path)
    return result


def verify(tree, j, path, role):
    if len(path) != len(tree) - 1 or not 0 <= j < len(tree[0]):
        return False
    cur = tree[0][j]
    for sibling in path:
        data = sibling + cur if j % 2 else cur + sibling
        cur = h(b'synthetic-node/' + role + data)
        j //= 2
    return cur == tree[-1][0]


def record_bytes(indices, paths, role):
    # Native tuple order: u64 index, column field bytes, salt, path bytes.
    # Three opaque synthetic field words replace any real witness material.
    out = bytearray(b'synthetic-unchanged-vectors/' + h(role))
    for j, path in zip(indices, paths):
        out += struct.pack('<Q', j)
        out += h(b'column/' + role + struct.pack('<Q', j))[:24]
        out += h(b'salt/' + role + struct.pack('<Q', j))
        for value in path:
            out += value
    return bytes(out)


def unique_coordinates_reference(indices, depth):
    # Heap numbering is independent of codec's (level, sibling) tuples.
    siblings = set()
    for j in indices:
        heap = (1 << depth) + j
        while heap > 1:
            siblings.add(heap - 1 if heap % 2 else heap + 1)
            heap //= 2
    return len(siblings)
