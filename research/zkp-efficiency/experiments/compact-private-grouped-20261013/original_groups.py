from field import F
from fixture import original_partial
import full_oracle as o
def original_group_rounds(originals,ir,prefix,n,xs):
    out=[[] for _ in ir]
    for x in xs:
        vals=original_partial(originals,prefix+[(x,0)],n)
        for g,terms in enumerate(ir):
            value=o.Z
            for i in range(len(vals[0])):
                value=o.add(value,o.mul(vals[g][i],o.bracket(terms,[a[i] for a in vals])))
            out[g].append(F(*value))
    return out

