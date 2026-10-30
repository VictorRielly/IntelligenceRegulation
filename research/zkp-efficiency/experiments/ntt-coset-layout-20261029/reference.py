"""Independent original-input modular interpolation + Horner oracle.

No candidate transform, pad folding or output mapping is imported here.
"""
MODULUS = 18446744069414584321


def interpolate(samples):
    n = len(samples)
    w = pow(7, (MODULUS-1)//n, MODULUS)
    return [sum(y*pow(w, (-i*j) % n, MODULUS)
                for i,y in enumerate(samples))*pow(n,-1,MODULUS) % MODULUS
            for j in range(n)]


def horner(coeffs, x):
    a = 0
    for v in reversed(coeffs):
        a = (a*x+v) % MODULUS
    return a


def original(msg, pad, nn, h):
    coeffs = interpolate(msg)
    n = len(msg)
    omega = pow(7, (MODULUS-1)//nn, MODULUS)
    ans = []
    for k in range(nn):
        x = h*pow(omega,k,MODULUS) % MODULUS
        ans.append((horner(coeffs,x)+(pow(x,n,MODULUS)-1)*horner(pad,x)) % MODULUS)
    return ans


def lagrange_at(msg, x):
    p = MODULUS
    n = len(msg)
    w = pow(7,(p-1)//n,p)
    if pow(x,n,p) == 1:
        return next(v for i,v in enumerate(msg) if pow(w,i,p) == x)
    # L_i(x) = (x^n-1) * w^i / (n*(x-w^i)).
    return sum(v*pow(w,i,p)*pow((n*(x-pow(w,i,p)))%p,-1,p)
               for i,v in enumerate(msg))*(pow(x,n,p)-1) % p


def byte_columns(rows, indices):
    result=[]
    for k in indices:
        buf=bytearray()
        for r in range(len(rows)):
            value=rows[r][k]
            for i in range(8):
                buf.append((value >> (8*i)) & 255)
        result.append(bytes(buf))
    return result
