"""Independent bigint reference: no candidate word arithmetic or NTT calls."""
PRIME = 18446744069414584321


def product(a, b):
    return a * b % PRIME


def dft(values, root, inverse=False):
    if inverse:
        root = pow(root, -1, PRIME)
    n = len(values)
    out = [sum(x * pow(root, i * j, PRIME) for j, x in enumerate(values)) % PRIME
           for i in range(n)]
    if inverse:
        out = [x * pow(n, -1, PRIME) % PRIME for x in out]
    return out


def dot(a, b):
    return sum(x * y for x, y in zip(a, b)) % PRIME


def butterfly(a, b, k):
    return (a + b) % PRIME, (a - b) * k % PRIME
