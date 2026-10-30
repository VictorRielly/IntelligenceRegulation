"""Locally authored canonical Goldilocks model; no external implementation."""
P = 0xffffffff00000001
W = (1 << 64) - 1
E = (1 << 32) - 1

def add(a, b):
    s = a + b
    r = s & W
    if s >> 64: r = (r + E) & W
    return r - P if r >= P else r

def sub(a, b):
    return (((a-b) & W) - E) & W if a < b else a-b

def reduce(x):
    lo, hi = x & W, x >> 64
    hihi, hilo = hi >> 32, hi & E
    t = (lo - hihi) & W
    if lo < hihi: t = (t - E) & W
    s = t + hilo*E
    r = s & W
    if s >> 64: r = (r + E) & W
    return r - P if r >= P else r

def mul(a, b): return reduce(a*b)
def fadd(a, b): return (add(a[0], b[0]), add(a[1], b[1]))
def fmul(a, b):
    return (add(mul(a[0],b[0]),mul(7,mul(a[1],b[1]))),
            add(mul(a[0],b[1]),mul(a[1],b[0])))

def eq_msb(point):
    out = [(1,0)]
    # Native eq_table_msb reverses the point before the LSB constructor.
    for r in reversed(point):
        s = (sub(1,r[0]),sub(0,r[1]))
        out = [fmul(x,s) for x in out] + [fmul(x,r) for x in out]
    return out

def baseline(eq, xs, ys):
    a = b = c = d = 0
    for (er,ei), x in zip(eq,xs):
        a,b = add(a,mul(er,x)),add(b,mul(ei,x))
    for (er,ei), y in zip(eq,ys):
        c,d = add(c,mul(er,y)),add(d,mul(ei,y))
    return add(a,mul(7,d)), add(b,c)

def paired(eq, xs, ys, mode='three'):
    a=b=c=d=0
    for (er,ei),x,y in zip(eq,xs,ys):
        a=add(a,mul(er,x))
        b=add(b,mul(ei,y))
        if mode=='four':
            c=add(c,mul(ei,x)); d=add(d,mul(er,y))
        else:
            c=add(c,mul(add(er,ei),add(x,y)))
    return (add(a,mul(7,b)),add(c,d) if mode=='four' else sub(sub(c,a),b))

def geometry(row_log, private_log, offset, point):
    n=1<<row_log; logm=min(row_log,private_log)
    c0=offset%n if private_log<row_log else 0
    return n,c0,point[private_log-logm:]

def evaluate(data,row_log,private_log,offset,mask_row,point,mode='three'):
    n,c0,tail=geometry(row_log,private_log,offset,point)
    eq=eq_msb(tail); length=len(eq)
    xs=data[mask_row*n+c0:mask_row*n+c0+length]
    ys=data[(mask_row+1)*n+c0:(mask_row+1)*n+c0+length]
    assert len(xs)==len(ys)==length
    return (baseline if mode=='baseline' else lambda e,x,y:paired(e,x,y,mode))(eq,xs,ys)

def counts(n):
    # Algebraic lowering of U*row: account for a single remaining *7, not
    # literal zero/one products which an optimizing compiler can remove.
    return {'length':n,'baseline':{'variable_mul':4*n,'constant7_mul':1,'add':4*n+2,'sub':0,
                                 'private_word_reads':2*n,'eq_word_reads':4*n},
            'three':{'variable_mul':3*n,'constant7_mul':1,'add':5*n+1,'sub':2,
                     'private_word_reads':2*n,'eq_word_reads':2*n},
            'four':{'variable_mul':4*n,'constant7_mul':1,'add':4*n+2,'sub':0,
                    'private_word_reads':2*n,'eq_word_reads':2*n},
            'persistent_extra_bytes':0,'eq_constructor_unchanged':True}
