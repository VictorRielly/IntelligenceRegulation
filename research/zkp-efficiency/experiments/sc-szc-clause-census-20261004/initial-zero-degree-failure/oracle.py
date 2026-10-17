"""Independent tuple Fp2 and direct original-cube oracle. No folding/cache code."""
P = 2**64 - 2**32 + 1
Z, O = (0, 0), (1, 0)

def add(a, b): return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)
def neg(a): return (-a[0] % P, -a[1] % P)
def sub(a, b): return add(a, neg(b))
def mul(a, b):
    # schoolbook polynomial multiplication followed by u^2=7 reduction
    c = [0, 0, 0]
    for i in range(2):
        for j in range(2): c[i+j] += a[i]*b[j]
    return ((c[0]+7*c[2]) % P, c[1] % P)
def tup(x): return (x.a, x.b)
def bits(i, n): return [(i >> (n-1-k)) & 1 for k in range(n)]
def eq(w, x):
    out = O
    assert len(w) == len(x)
    for a, b in zip(w, x): out = mul(out, add(mul(a,b), mul(sub(O,a),sub(O,b))))
    return out
def mle(words, point):
    assert len(words) == 1 << len(point)
    acc = Z
    for i, word in enumerate(words):
        weight = O
        for b, q in zip(bits(i,len(point)), point): weight = mul(weight, q if b else sub(O,q))
        acc = add(acc, mul(word,weight))
    return acc
def table(tab, n):
    if tab['kind'] == 'Eq':
        w = list(map(tup,tab['point'])); s=tab['start']
        return [eq(w,[(b,0) for b in bits(i,n)[s:s+len(w)]]) for i in range(1<<n)]
    if tab['kind'] == 'Pub': return list(map(tup,tab['words']))
    arrays=tab['source']; coords=tab['coords']; out=[]
    for i in range(1<<n):
        xb=bits(i,n); point=[]
        for role,k in coords:
            point.append(tup(k) if role=='Fixed' else ((xb[k] if role=='Rho' else 1-xb[k]),0))
        values=[tup(v) for v in arrays]; joined=[Z for _ in range(1<<len(coords))]
        for off, coef in tab['slices']:
            for j in range(len(joined)): joined[j]=add(joined[j],mul(tup(coef),values[off+j]))
        out.append(mle(joined,point))
    return out
def bracket(terms, values):
    result=Z
    for coef, indices in terms:
        term=tup(coef)
        for i in indices: term=mul(term,values[i])
        result=add(result,term)
    return result
def poly(groups, values):
    result=Z
    for eq_index,terms in groups: result=add(result,mul(values[eq_index],bracket(terms,values)))
    return result
def round_direct(tables, groups, prefix, t, n):
    result=Z
    for tail in range(1<<(n-len(prefix)-1)):
        point=prefix+[(t,0)]+[(b,0) for b in bits(tail,n-len(prefix)-1)]
        result=add(result,poly(groups,[mle(a,point) for a in tables]))
    return result
