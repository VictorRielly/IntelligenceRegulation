"""Independent algorithm: solve a Vandermonde system, then monomial Horner.

No import of the candidate, finite differences, factorials or Lagrange formula.
Reference and candidate are both locally authored; no third-party proof oracle.
"""
MODULUS = 2**64 - 2**32 + 1


def add(x, y):
    return ((x[0] + y[0]) % MODULUS, (x[1] + y[1]) % MODULUS)


def mul(x, y):
    return ((x[0]*y[0] + 7*x[1]*y[1]) % MODULUS,
            (x[0]*y[1] + x[1]*y[0]) % MODULUS)


def coefficients(values):
    n = len(values)
    rows = [[pow(i, k, MODULUS) for k in range(n)] + list(values[i])
            for i in range(n)]
    for col in range(n):
        pivot = next(i for i in range(col, n) if rows[i][col])
        rows[col], rows[pivot] = rows[pivot], rows[col]
        scale = pow(rows[col][col], -1, MODULUS)
        rows[col] = [v * scale % MODULUS for v in rows[col]]
        for i in range(n):
            if i == col:
                continue
            scale = rows[i][col]
            rows[i] = [(a - scale*b) % MODULUS for a,b in zip(rows[i], rows[col])]
    return [tuple(row[n:]) for row in rows]


def evaluate(coeffs, point):
    acc = (0, 0)
    for c in reversed(coeffs):
        acc = add(mul(acc, point), c)
    return acc


def direct_mle(values, point):
    """MSB index convention, direct products rather than pairwise folding."""
    assert len(values) == 1 << len(point)
    result = (0, 0)
    for index, v in enumerate(values):
        weight = (1, 0)
        for j, r in enumerate(point):
            factor = r if (index >> (len(point)-1-j)) & 1 else ((1-r[0]) % MODULUS, -r[1] % MODULUS)
            weight = mul(weight, factor)
        result = add(result, mul(v, weight))
    return result


def masked_polynomial(tables, point, coeff, degree):
    result = (1, 0)
    for t in tables:
        result = mul(result, direct_mle(t, point))
    # CFS algebra: a0 + a' * product(x_i) + sum(a_i,e * x_i^e).
    g = coeff[0]
    product = (1, 0)
    for r in point:
        product = mul(product, r)
    g = add(g, mul(coeff[1], product))
    for j,r in enumerate(point):
        power = (1, 0)
        for k in range(degree):
            power = mul(power, r)
            g = add(g, mul(coeff[2+j*degree+k], power))
    return add(result, g)
