"""Independent dense Hadamard/Fraction oracle for finite, small synthetic BF16."""
import hashlib,json,math,struct
from fractions import Fraction as Q

def reference(profile_bytes,sign_bytes,checkpoint):
    p=json.loads(profile_bytes);n=int.from_bytes(checkpoint[:8],'little');h=json.loads(checkpoint[8:8+n]);data=checkpoint[8+n:]
    def tensor(name):
        t=h[name];lo,hi=t['data_offsets'];out=[]
        for i in range(lo,hi,2):
            u=int.from_bytes(data[i:i+2],'little');sgn=-1 if u>>15 else 1;e=(u>>7)&255;frac=u&127
            if e==255:raise ValueError('nonfinite')
            out.append(sgn*Q(128+frac if e else frac,128)*Q(2)**(e-127 if e else -126))
        return out
    v,w,b=p['vocab'],p['width'],p['block'];rows=tensor('embedding');norm=tensor('norm');signs=[Q(x) for x in struct.unpack('<'+'d'*w,sign_bytes)]
    div=math.isqrt(b)
    if div*div!=b:raise ValueError('reference exact normalization domain')
    def dense(row):
        return [sum(row[start+j]*signs[start+j]*(-1 if (i&j).bit_count()%2 else 1) for j in range(b))/div for start in range(0,w,b) for i in range(b)]
    # Independent rounding formula, no candidate helper calls.
    def q(x,s):
        y=x/s+Q(1,2);return y.numerator//y.denominator
    emb=[];head=[];scales=[];raw=[]
    for r in range(v):
        row=rows[r*w:(r+1)*w];raw.append(row)
        e=dense(row)
        e=[Q(struct.unpack('<f',struct.pack('<f',float(x)))[0]) for x in e]
        emb.extend(q(x,Q(p['residual_scale'])) for x in e)
        f=dense([x*g for x,g in zip(row,norm)])
        s=max(map(abs,f))/127;scales.append(s)
        head.extend(q(x,s if s else Q(1)) for x in f)
    maximum=max(scales);mult=[max(1,q(s/maximum,Q(1,4096))) for s in scales]
    m=p['margin'];delta=dense([(a-c)*g for a,c,g in zip(raw[m['yes']],raw[m['no']],norm)])
    margin=tuple(q(x,Q(m['scale'])) for x in delta)
    tables=(struct.pack('<'+'h'*len(emb),*emb),bytes(x%256 for x in head),struct.pack('<'+'q'*len(mult),*mult))
    return tuple(hashlib.sha256(x).hexdigest() for x in tables),margin,tables
