"""Independent Python big-integer oracle: no candidate imports/limb code."""
MODULUS = 18446744069414584321


def warp_sum(values, membermask):
    return sum(x for i, x in enumerate(values) if membermask & (1 << i)) % MODULUS


def component_sums(rows):
    return [tuple(sum(row[d][c] for row in rows) % MODULUS for c in (0, 1))
            for d in range(len(rows[0]))]


def polynomial_values(tables, degree):
    """Explicit node multiplication; unrelated to incremental CUDA evaluation.

    Every table has two halves and represents a multilinear polynomial.
    At each node d evaluate product of the degree input tables, including
    nonzero imaginary limbs. Then sum the original rows in unbounded ints.
    """
    half = len(tables[0]) // 2
    result = []
    for d in range(degree + 1):
        real, imag = 0, 0
        for i in range(half):
            a, b = 1, 0
            for table in tables:
                c = ((1 - d) * table[i][0] + d * table[i + half][0]) % MODULUS
                e = ((1 - d) * table[i][1] + d * table[i + half][1]) % MODULUS
                a, b = (a * c + 7 * b * e) % MODULUS, (a * e + b * c) % MODULUS
            real += a
            imag += b
        result.append((real % MODULUS, imag % MODULUS))
    return result
