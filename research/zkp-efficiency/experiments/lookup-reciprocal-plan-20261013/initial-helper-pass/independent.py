"""Direct coefficient solve; neither native denominator nor inverse is called."""
MOD = 18446744069414584321
ERROR = 'zero LogUp denominator; discard attempt'

def solve(pairs, alpha, beta, tag):
    out = []
    for index, value in pairs:
        real = (alpha[0]-index-beta[0]*value-tag[0]) % MOD
        imag = (alpha[1]-beta[1]*value-tag[1]) % MOD
        if real == 0 and imag == 0:
            raise ZeroDivisionError(ERROR)
        norm = (real**2-7*imag**2) % MOD
        # Euclidean inverse, unlike native-model Fermat exponentiation.
        invnorm = pow(norm, -1, MOD)
        x, y = real*invnorm % MOD, -imag*invnorm % MOD
        assert (real*x+7*imag*y) % MOD == 1
        assert (real*y+imag*x) % MOD == 0
        out.append((x, y))
    return out

def table_helpers(table, pairs, alpha, beta, tag, length):
    # Independent histogram: off-table pairs route to bin0 in existing code.
    if length < len(table):
        raise ValueError('invalid table length')
    hist = [0]*len(table)
    for i, v in pairs:
        target = i if i in range(len(table)) and table[i] == v else 0
        hist[target] += 1
    values = [(i % len(table), table[i % len(table)]) for i in range(length)]
    inverses = solve(values, alpha, beta, tag)
    return [(a*(hist[j] if j < len(table) else 0) % MOD,
             b*(hist[j] if j < len(table) else 0) % MOD)
            for j, (a, b) in enumerate(inverses)]
