"""Independent bottom-up tree/direct-inverse reference, synthetic F65537."""
def layers(leaves,p):
    levels=[list(leaves)]
    while len(levels[-1])>1:
        v=levels[-1];out=[]
        for j in range(0,len(v),2):
            a,b=v[j];c,d=v[j+1]
            out.append(((a*d+c*b)%p,b*d%p))
        levels.append(out)
    return list(reversed(levels))

def direct(leaves,p):
    if any(d%p==0 for a,d in leaves):raise ValueError('zero denominator, even with zero multiplicity')
    return sum(a*pow(d,-1,p) for a,d in leaves)%p

def enumerate_cost(sizes,b):
    nodes=[];initial=0;redo=0;leaf=0;target_widths=[]
    for n in sizes:
        h=n.bit_length()-1;cut=min(b,h)
        widths=[2**t for t in range(h+1)]
        nodes.extend(widths[:cut+1]); initial+=sum(widths[:-1]);leaf+=n
        for t in range(cut+1,h+1):
            redo+=sum(widths[t:-1]);leaf+=n
            target_widths.append((2**t,h-t+1))
    initial+=len(sizes)-1
    return dict(retained_nodes=sum(nodes)+len(sizes)-1,
      initial_internal_nodes=initial,recomputed_internal_nodes=redo,
      leaf_generations=leaf,
      arithmetic_peak_upper_bytes=32*(sum(nodes)+len(sizes)-1+
        max([w+s for w,s in target_widths]+[max(n.bit_length() for n in sizes)])))
