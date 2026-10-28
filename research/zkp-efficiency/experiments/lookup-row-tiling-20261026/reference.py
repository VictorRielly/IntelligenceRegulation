"""Independent direct-coordinate oracle, no prefix copying or Fp2 API."""
P = 2**64 - 2**32 + 1

def direct(length, table, beta, gamma):
    # Integer modular projection of i + beta * base(table[i]) + gamma.
    return [((x % 256 + beta[0] * table[x % 256] + gamma[0]) % P,
             (beta[1] * table[x % 256] + gamma[1]) % P)
            for x in range(length)]

def encode(rows):
    return b''.join(a.to_bytes(8, 'little') + b.to_bytes(8, 'little') for a,b in rows)

def direct_mle(rows, point):
    """Original-cube sum, independently expanded Boolean basis weights."""
    assert len(rows) == 1 << len(point)
    s0 = s1 = 0
    for x,(a,b) in enumerate(rows):
        w = 1
        for j,r in enumerate(point):
            w = w * (r if (x >> (len(point)-1-j)) & 1 else 1-r) % P
        s0 = (s0 + a*w) % P
        s1 = (s1 + b*w) % P
    return s0,s1
