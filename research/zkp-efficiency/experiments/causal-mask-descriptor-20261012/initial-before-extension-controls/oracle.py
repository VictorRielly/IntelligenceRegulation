"""Independent original-cube MLE and schoolbook extension convolution.

Does not import candidate fields, recurrence, index reader or folding.
"""
P = 2**64 - 2**32 + 1
O, Z = (1,0), (0,0)
def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b): return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):
    c=[0,0,0]
    for i in range(2):
        for j in range(2): c[i+j]+=a[i]*b[j]
    return ((c[0]+7*c[2])%P,c[1]%P)
def mle(words, point):
    assert len(words)==1<<len(point)
    out=Z
    for index,word in enumerate(words):
        if word==Z: continue
        weight=O
        for i,x in enumerate(point):
            weight=mul(weight,x if (index>>(len(point)-1-i))&1 else sub(O,x))
        out=add(out,mul(word,weight))
    return out
def mask_words(leading,token_bits):
    # Independently decode the concatenated binary axes, not native modulo.
    axes=leading+2*token_bits;words=[]
    for index in range(1<<axes):
        b=[(index>>(axes-1-i))&1 for i in range(axes)]
        t=j=0
        for x in b[leading:leading+token_bits]: t=2*t+x
        for x in b[leading+token_bits:]: j=2*j+x
        words.append(O if j<=t else Z)
    return words
