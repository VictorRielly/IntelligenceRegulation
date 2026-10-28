"""Independent direct-index and dense matrix reference; imports no candidate."""
MODULUS = 18446744069414584321


def direct(source, table):
    seen = set()
    out = []
    histogram = [0 for _ in range(256)]
    pre = []
    for key, address in source:
        if key in seen or type(address) is not int or address < 0 or address > 255:
            raise ValueError('bad source')
        seen.add(key)
        out.append(table[address])
        pre.append(histogram[address])
        histogram[address] += 1
    return out, histogram, pre


def dense(source):
    result = []
    for _, address in source:
        if type(address) is not int or address not in range(256):
            raise ValueError('bad index')
        row = [0 for _ in range(256)]
        row[address] = 1
        result.append(row)
    return result


def expand(factors, d):
    radix = 2**(8//d)
    rows = []
    for _, fs in factors:
        row = []
        for address in range(256):
            product = 1
            rest = address
            for f in fs:
                product *= f[rest % radix]
                rest //= radix
            row.append(product % MODULUS)
        rows.append(row)
    return rows


def matrix_valid(source, matrix, p=MODULUS, require_bool=True, require_order=True, field_guard=True):
    if field_guard and p <= 256:
        return False
    if len(source) != len(matrix):
        return False
    for (_, address), row in zip(source, matrix):
        if len(row) != 256 or any(type(x) is not int or not 0 <= x < p for x in row):
            return False
        if require_bool and any(x not in (0, 1) for x in row):
            return False
        if sum(row) % p != 1:
            return False
        if require_order and sum(j*x for j, x in enumerate(row)) % p != address:
            return False
    return True


def dense_mle(matrix, ap, tp):
    result = 0
    for t in range(len(matrix)):
        wt = 1
        for j in range(len(tp)):
            wt = wt * (tp[j] if (t // 2**j) % 2 else 1-tp[j]) % MODULUS
        partial = 0
        for a in range(256):
            wa = 1
            for k in range(8):
                wa = wa * (ap[k] if (a // 2**k) % 2 else 1-ap[k]) % MODULUS
            partial += matrix[t][a]*wa
        result += wt*partial
    return result % MODULUS
