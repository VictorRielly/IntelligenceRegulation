"""Independent original-cube and recursive-fold oracle. No candidate imports."""
MODULUS = 18446744069414584321

def plus(a, b): return ((a[0]+b[0]) % MODULUS, (a[1]+b[1]) % MODULUS)
def times(a, b):
    # Schoolbook extension multiplication, independent of candidate Karatsuba.
    return ((a[0]*b[0]+7*a[1]*b[1]) % MODULUS,
            (a[0]*b[1]+a[1]*b[0]) % MODULUS)
def minus_one(a): return ((1-a[0]) % MODULUS, -a[1] % MODULUS)

def mapped_point(site, challenges):
    out = []
    for tag, arg in site.coords:
        if tag == 'fixed': out.append(arg)
        elif tag == 'rho': out.append(challenges[arg])
        elif tag == 'flip': out.append(minus_one(challenges[arg]))
        else: raise ValueError(tag)
    return out

def cube(values, point):
    assert len(values) == 2**len(point)
    result = (0, 0)
    for index, value in enumerate(values):
        selector = (1, 0)
        for axis, r in enumerate(point):
            bit = index >> (len(point)-axis-1) & 1
            selector = times(selector, r if bit else minus_one(r))
        result = plus(result, times(selector, value))
    return result

def folded(values, point):
    v = list(values)
    for r in point:
        half = len(v)//2
        v = [plus(times(minus_one(r), v[j]), times(r, v[j+half])) for j in range(half)]
    assert len(v) == 1
    return v[0]

def mask_value(site, challenges, data, large=False):
    p = mapped_point(site, challenges)
    width = 2**site.row_log
    count = 2**min(site.log, site.row_log)
    tail = p[-min(site.log, site.row_log):] if min(site.log, site.row_log) else []
    start = site.source_offset % width if site.log < site.row_log else 0
    # Combine the two original base rows as coefficients before evaluation.
    coeffs = [(data[site.mask_row*width+start+j], data[(site.mask_row+1)*width+start+j])
              for j in range(count)]
    return (folded if large else cube)(coeffs, tail)

def extension_terms(sites, challenges, data, initial, es, large=False):
    vals = list(initial)
    for m, e in enumerate(es):
        for k, site in enumerate(sites):
            target = mask_value(site, challenges, data[site.cm], large) if site.ext_round == m else (0, 0)
            vals[k] = plus(times(minus_one(e), vals[k]), times(e, target))
    return vals
