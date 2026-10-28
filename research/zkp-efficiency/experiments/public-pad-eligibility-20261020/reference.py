"""Independent public algebra/reference predicates, with no model imports."""
P = 18446744069414584321

class F:
    def __init__(self, x=0, y=0): self.a, self.b = x % P, y % P
    def __add__(self, other): return F(self.a+other.a, self.b+other.b)
    def __mul__(self, other):
        # Polynomial schoolbook convolution, reduced modulo X^2-7.
        c = [0, 0, 0]
        for i, a in enumerate((self.a, self.b)):
            for j, b in enumerate((other.a, other.b)): c[i+j] += a*b
        return F(c[0]+7*c[2], c[1])
    def __pow__(self, k):
        a, out = self, F(1)
        while k:
            if k & 1: out = out*a
            a = a*a
            k //= 2
        return out
    @property
    def v(self): return (self.a, self.b)

def descriptor(padded, frozen_toy, zeta):
    if not padded or frozen_toy: return []
    if zeta == (0,0): raise ValueError('refused')
    # Independent exponentiation from definition, no recurrence state.
    return [(3+j, (F(*zeta)**j).v) for j in range(11)]

def pad_value(zeta, mu, vals):
    return (F(*mu)*sum_field((F(*zeta)**j)*F(*v) for j,v in enumerate(vals))).v

def sum_field(xs):
    out = F()
    for x in xs: out = out+x
    return out

def gates(srcs, *, supp, split, fused, raw_switch, n, tail_log, next_round):
    bs = set(range(3,14)) | ({20} if supp else set())
    bs_ok = all(srcs[t][0] == 'Base' or
                srcs[t][0] in {'Host','Public'} and srcs[t][2] for t in bs)
    resident = all(srcs[t][0] in {'Base','Pair'} and srcs[t][1]
                   for t in range(3,20))
    raw = bool(split and fused and raw_switch and n > max(2,tail_log+1)
               and resident)
    base = bool(split and bs_ok)
    return dict(base=base, raw=raw, adapter=base and raw and next_round==0)

def geometry(tokens, hidden, log_cols):
    import math
    # Domain width from independent ceiling logs and P-3 lift.
    n = max(math.ceil(math.log2(tokens)) + math.ceil(math.log2(hidden)), log_cols)
    count = 2**n
    return count, count != tokens*hidden
