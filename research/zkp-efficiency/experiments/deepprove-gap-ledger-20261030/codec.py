"""Synthetic root-scoped path transport; no native verifier or hash change.

The trusted geometry and existing ordered column indices determine every
dictionary coordinate. Only first-occurrence digests are transported. The
decoder restores every old path before an unchanged native decoder/verifier.
No dictionary persists beyond one opening. No private payload is consulted.
"""
DIGEST = 32
MAX_CHECKS = 256
MAX_DEPTH = 24


def validate_geometry(indices, checks, depth):
    if not 0 <= depth <= MAX_DEPTH or not 1 <= checks <= MAX_CHECKS:
        raise ValueError('untrusted or unsupported geometry')
    if len(indices) != checks:
        raise ValueError('query multiplicity changed')
    if any(type(j) is not int or not 0 <= j < 1 << depth for j in indices):
        raise ValueError('column index out of bounds')


def encode(indices, paths, checks, depth):
    validate_geometry(indices, checks, depth)
    if len(paths) != checks or any(len(p) != depth for p in paths):
        raise ValueError('wrong path count/depth')
    seen, chunks = {}, []
    for j, path in zip(indices, paths):
        for level, node in enumerate(path):
            if type(node) is not bytes or len(node) != DIGEST:
                raise ValueError('wrong digest width')
            coordinate = (level, (j >> level) ^ 1)
            if coordinate in seen:
                if seen[coordinate] != node:
                    raise ValueError('inconsistent repeated node')
            else:
                seen[coordinate] = node
                chunks.append(node)
    return b''.join(chunks)


def decode(indices, compressed, checks, depth):
    validate_geometry(indices, checks, depth)
    if len(compressed) > checks * depth * DIGEST:
        raise ValueError('transport exceeds geometry bound')
    seen, paths, pos = {}, [], 0
    for j in indices:
        path = []
        for level in range(depth):
            coordinate = (level, (j >> level) ^ 1)
            if coordinate not in seen:
                if pos + DIGEST > len(compressed):
                    raise ValueError('truncated dictionary')
                seen[coordinate] = compressed[pos:pos + DIGEST]
                pos += DIGEST
            path.append(seen[coordinate])
        paths.append(path)
    if pos != len(compressed):
        raise ValueError('trailing dictionary bytes')
    return paths
