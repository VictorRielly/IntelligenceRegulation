"""Independent exact-integer DFT and Lagrange hiding-row references.

Does not import candidate field arithmetic, twiddle classification or butterflies.
"""
P = 18446744069414584321


def dft(values, inverse=False):
    n = len(values)
    omega = pow(7, (P - 1) // n, P)
    if inverse:
        omega = pow(omega, P - 2, P)
    scale = pow(n, P - 2, P) if inverse else 1
    return [sum(a * pow(omega, i * j, P) for j, a in enumerate(values)) * scale % P for i in range(n)]


def eval_poly(coeffs, x):
    acc = 0
    for v in reversed(coeffs):
        acc = (acc * x + v) % P
    return acc


def hiding_row(msg, pad, nn, coset=7):
    n = len(msg)
    w = pow(7, (P - 1) // n, P)
    nodes = [pow(w, j, P) for j in range(n)]
    wi = pow(7, (P - 1) // nn, P)
    ninv = pow(n, P - 2, P)
    out = []
    for i in range(nn):
        x = coset * pow(wi, i, P) % P
        z = (pow(x, n, P) - 1) % P
        assert all(x != y for y in nodes), 'test coset must be disjoint'
        f = sum(m * y * z * ninv * pow((x - y) % P, P - 2, P) for m, y in zip(msg, nodes)) % P
        out.append((f + z * eval_poly(pad, x)) % P)
    return out
